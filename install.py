"""Miyoo IronMON SD-card installer. GPL-3.0-only; see LICENSE and AI_USAGE.md.

No SSH, host Java, ROM download or system installation is needed. Dependencies
come from pinned upstream URLs and are verified before the SD card is changed.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import queue
import shutil
import stat
import sys
import tarfile
import tempfile
import threading
import urllib.request
import uuid
import zipfile

from prepare_rom import BASE_SHA1, apply_ips, restrict_shops, speech_skip

VERSION = '0.1.1'
HERE = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent))
BIOS_SHA1 = '300c20df6731a33952ded8c436f7f186d25d3492'
MAX_EXPANDED = 512 * 1024 * 1024
MAX_DOWNLOAD = 100 * 1024 * 1024


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def safe_member(root, name):
    # Reject Windows drive letters, alternate streams and archive path traversal.
    if '\\' in name or ':' in name:
        raise ValueError(f'Unsafe archive path: {name}')
    relative = PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError(f'Unsafe archive path: {name}')
    target = Path(root).joinpath(*relative.parts).resolve()
    if not target.is_relative_to(Path(root).resolve()):
        raise ValueError(f'Archive path leaves its destination: {name}')
    return target


def extract_zip(source, destination):
    with zipfile.ZipFile(source) as archive:
        if sum(m.file_size for m in archive.infolist()) > MAX_EXPANDED:
            raise ValueError('Archive expands beyond the installation limit.')
        for member in archive.infolist():
            target = safe_member(destination, member.filename)
            if stat.S_ISLNK(member.external_attr >> 16):
                raise ValueError('ZIP symbolic links are not supported.')
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as src, target.open('wb') as dst:
                    shutil.copyfileobj(src, dst)


def extract_tar(source, destination):
    # Materialize Java's two internal links as copies for FAT32 and Windows.
    with tarfile.open(source, 'r:*') as archive:
        members = archive.getmembers()
        if sum(m.size for m in members) > MAX_EXPANDED:
            raise ValueError('Archive expands beyond the installation limit.')
        links = []
        for member in members:
            target = safe_member(destination, member.name)
            if member.issym() or member.islnk():
                if PurePosixPath(member.linkname).is_absolute() or ':' in member.linkname or '\\' in member.linkname:
                    raise ValueError('Unsafe archive link.')
                link = (target.parent / member.linkname).resolve() if member.issym() else safe_member(destination, member.linkname)
                if not link.is_relative_to(Path(destination).resolve()):
                    raise ValueError('Archive link leaves its destination.')
                links.append((target, link))
            elif member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as src, target.open('wb') as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(member.mode & 0o777)
            else:
                raise ValueError('Unsupported archive entry.')
        for target, link in links:
            target.parent.mkdir(parents=True, exist_ok=True)
            if link.is_dir():
                shutil.copytree(link, target)
            elif link.is_file():
                shutil.copy2(link, target)
            else:
                raise ValueError('Archive link target is missing.')


def fetch(spec, cache, log=print, offline=False):
    cache = Path(cache)
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / spec['file']
    if target.is_file() and sha256(target) == spec['sha256']:
        log(f"Verified cached {spec['file']}")
        return target
    if offline:
        raise ValueError(f"Missing or corrupt cached download: {spec['file']}")
    log(f"Downloading {spec['file']}...")
    temporary = target.with_suffix(target.suffix + '.part-' + uuid.uuid4().hex)
    try:
        request = urllib.request.Request(spec['url'], headers={'User-Agent': f'Miyoo-IronMON-Installer/{VERSION}'})
        with urllib.request.urlopen(request, timeout=60) as response, temporary.open('wb') as dst:
            size = 0
            for chunk in iter(lambda: response.read(1024 * 1024), b''):
                size += len(chunk)
                if size > MAX_DOWNLOAD:
                    raise ValueError('Download exceeds the installation limit.')
                dst.write(chunk)
        if sha256(temporary) != spec['sha256']:
            raise ValueError(f"Checksum mismatch: {spec['file']}. Nothing has been installed.")
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    log(f"Verified {spec['file']}")
    return target


def read_rom(source):
    path = Path(source)
    if path.suffix.lower() == '.zip':
        with zipfile.ZipFile(path) as archive:
            candidates = [m for m in archive.infolist() if m.filename.lower().endswith('.gba') and m.file_size == 16777216]
            for member in candidates:
                data = archive.read(member)
                if hashlib.sha1(data).hexdigest() == BASE_SHA1:
                    return data
        raise ValueError('The ZIP does not contain an unmodified FireRed USA Rev 1 ROM.')
    if not path.is_file() or path.stat().st_size != 16777216:
        raise ValueError('Select your unmodified 16 MiB FireRed USA Rev 1 .gba or .zip.')
    data = path.read_bytes()
    if hashlib.sha1(data).hexdigest() != BASE_SHA1:
        raise ValueError('Wrong ROM version. Required: unmodified FireRed USA Rev 1 (v1.1). See INSTALL.md.')
    return data


def validate_sd(path):
    sd = Path(path).resolve()
    required = ['App', 'RetroArch/.retroarch/cores/gpsp_libretro.so', '.tmp_update/bin/infoPanel', '.tmp_update/lib/parasyte/libatomic.so.1']
    if not sd.is_dir() or any(not (sd / item).exists() for item in required):
        raise ValueError('Select the root of an Onion SD card with gpSP and the parasyte Java libraries installed. See INSTALL.md.')
    for item in ['App', 'App/IronMON', 'BIOS', 'IronMON-backups']:
        candidate = sd / item
        if candidate.is_symlink() or not candidate.resolve().is_relative_to(sd):
            raise ValueError('The installation destination must stay on the selected SD card.')
    return sd


def read_bios(sd, source=None):
    path = Path(source) if source else sd / 'BIOS/gba_bios.bin'
    if not path.is_file() or path.stat().st_size != 16384:
        raise ValueError('Select your own 16 KiB GBA BIOS, or place it at BIOS/gba_bios.bin on the SD card.')
    data = path.read_bytes()
    if hashlib.sha1(data).hexdigest() != BIOS_SHA1:
        raise ValueError('This file does not match the standard GBA BIOS. See INSTALL.md.')
    existing = sd / 'BIOS/gba_bios.bin'
    if existing.exists() and existing.read_bytes() != data:
        raise ValueError('An incompatible BIOS already exists on the SD card. Back it up and correct it before installing.')
    return data


def verify_payload(payload):
    payload = Path(payload)
    manifest = json.loads((payload / 'manifest.json').read_text(encoding='utf-8'))
    if manifest['version'] != VERSION:
        raise ValueError('Installer and app payload versions differ.')
    for name, digest in manifest['files'].items():
        path = safe_member(payload, name)
        if not path.is_file() or sha256(path) != digest:
            raise ValueError(f'App payload is missing or corrupt: {name}')
    return manifest


def install(sd_path, rom_path, bios_path=None, *, cache=None, payload=None, log=print, offline=False):
    sd = validate_sd(sd_path)
    payload = Path(payload) if payload else HERE / 'payload'
    manifest = verify_payload(payload)
    rom = read_rom(rom_path)
    bios = read_bios(sd, bios_path)
    target = sd / 'App/IronMON'
    if target.exists() and not target.is_dir():
        raise ValueError('App/IronMON is not a directory.')
    if target.is_dir():
        for path in target.rglob('*'):
            if path.is_symlink() or not path.resolve().is_relative_to(target.resolve()):
                raise ValueError('Existing installation contains an external link.')
    existing_size = sum(p.stat().st_size for p in target.rglob('*') if p.is_file()) if target.exists() else 0
    if shutil.disk_usage(sd).free < existing_size + 350 * 1024 * 1024:
        raise ValueError('Not enough free SD space. Allow 350 MiB plus the size of the existing app for a safe update.')
    if cache is None:
        cache = Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.cache'))) / 'MiyooIronMON/downloads'
    specs = json.loads((HERE / 'dependencies.json').read_text(encoding='utf-8'))
    downloads = {key: fetch(value, cache, log, offline) for key, value in specs.items()}
    # All input and download checks finish before creating an SD staging directory.
    stage = sd / 'App' / ('.IronMON-install-' + uuid.uuid4().hex)
    backup = None
    bios_created = False
    try:
        log('Building the app on the SD card. Please leave the card connected...')
        if target.exists():
            shutil.copytree(target, stage)
        else:
            stage.mkdir()
        for name in manifest['files']:
            if name == 'settings.ini' and (stage / name).exists():
                continue
            destination = safe_member(stage, name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(payload / name, destination)
        with tempfile.TemporaryDirectory(prefix='ironmon-dependencies-') as tmp:
            tmp = Path(tmp)
            extract_zip(downloads['tracker'], tmp / 'tracker')
            shutil.copytree(tmp / 'tracker/Ironmon-Tracker', stage / 'tracker', dirs_exist_ok=True)
            extract_zip(downloads['randomizer'], tmp / 'randomizer')
            shutil.copy2(tmp / 'randomizer/PokeRandoZX.jar', stage / 'PokeRandoZX.jar')
            (stage / 'licenses').mkdir(exist_ok=True)
            shutil.copy2(downloads['randomizer_license'], stage / 'licenses/UPR-ZX-LICENSE.txt')
            shutil.copy2(tmp / 'randomizer/README.txt', stage / 'licenses/UPR-ZX-README.txt')
            extract_tar(downloads['java'], tmp / 'java')
            runtime = next((tmp / 'java').iterdir())
            shutil.copytree(runtime, stage / 'runtime', dirs_exist_ok=True)
            extract_zip(downloads['font'], tmp / 'font')
            font_root = tmp / 'font/dejavu-sans-ttf-2.37'
            shutil.copy2(font_root / 'ttf/DejaVuSans.ttf', stage / 'font.ttf')
            shutil.copy2(font_root / 'LICENSE', stage / 'licenses/DejaVu-LICENSE.txt')
            shutil.copy2(font_root / 'AUTHORS', stage / 'licenses/DejaVu-AUTHORS.txt')
        settings = {}
        for line in (stage / 'settings.ini').read_text(encoding='utf-8').splitlines():
            if '=' in line and not line.startswith('#'):
                key, value = line.split('=', 1)
                settings[key] = value
        log('Preparing your ROM locally: Faster FireRed, intro skip and shop rules...')
        prepared = restrict_shops(speech_skip(apply_ips(rom, downloads['patch'].read_bytes()),
            settings.get('player', 'RED'), settings.get('rival', 'BLUE'), int(settings.get('gender', '0'))))
        old_base = stage / 'source-qol.gba'
        if old_base.exists() and sha256(old_base) != hashlib.sha256(prepared).hexdigest():
            # A different prepared base must never reuse old reserve seeds.
            seed_cache = stage / 'data/cache'
            if seed_cache.exists():
                if not seed_cache.resolve().is_relative_to(stage.resolve()):
                    raise ValueError('Seed cache leaves the staging directory.')
                shutil.rmtree(seed_cache)
            log('Prepared base changed; reserve seeds will regenerate. Current run preserved.')
        (stage / 'source.gba').write_bytes(rom)
        (stage / 'source-qol.gba').write_bytes(prepared)
        (stage / 'data').mkdir(exist_ok=True)
        (stage / 'version.txt').write_text(VERSION + '\n', encoding='ascii')
        for name in ['ironmon', 'launch.sh', 'seed-cache.sh', 'runtime/bin/java']:
            (stage / name).chmod(0o755)
        required = ['tracker/Ironmon-Tracker.lua', 'tracker/LICENSE.txt', 'PokeRandoZX.jar', 'runtime/bin/java', 'runtime/LICENSE', 'font.ttf']
        if any(not (stage / name).is_file() for name in required):
            raise ValueError('An upstream archive has an unexpected structure.')
        bios_target = sd / 'BIOS/gba_bios.bin'
        bios_target.parent.mkdir(exist_ok=True)
        if not bios_target.exists():
            with bios_target.open('xb') as stream:
                bios_created = True
                stream.write(bios)
        if target.exists():
            backups = sd / 'IronMON-backups'
            backups.mkdir(exist_ok=True)
            backup = backups / ('IronMON-' + datetime.now().strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:8])
            if not backup.resolve().is_relative_to(sd) or not target.resolve().is_relative_to(sd):
                raise ValueError('Backup leaves the selected SD card.')
            target.rename(backup)
        try:
            stage.rename(target)
        except Exception:
            if backup:
                backup.rename(target)
            raise
    except Exception:
        if stage.exists():
            if not stage.resolve().is_relative_to(sd):
                raise ValueError('Staging cleanup leaves the selected SD card.')
            shutil.rmtree(stage)
        if bios_created:
            (sd / 'BIOS/gba_bios.bin').unlink(missing_ok=True)
        raise
    log('Installed! Safely eject the SD card, then open Apps > IronMON.')
    log('The first launch prepares a seed on the Miyoo. Allow about 1-2 minutes.')
    if backup:
        log(f'Previous app backed up at {backup}. Current run, notes and settings preserved.')
    return {'version': VERSION, 'target': str(target), 'backup': str(backup) if backup else None,
            'prepared_sha256': hashlib.sha256(prepared).hexdigest()}


def create_gui():
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
    root = tk.Tk()
    root.title(f'Miyoo IronMON {VERSION} - SD card installer')
    root.geometry('760x610')
    root.minsize(720, 570)
    style = ttk.Style(root)
    if 'vista' in style.theme_names():
        style.theme_use('vista')
    page = ttk.Frame(root, padding=24)
    page.pack(fill='both', expand=True)
    page.columnconfigure(1, weight=1)
    ttk.Label(page, text='IronMON. On your Miyoo.', font=('Segoe UI', 23, 'bold')).grid(row=0, column=0, columnspan=3, sticky='w')
    ttk.Label(page, text='FireRed Standard + original Tracker + on-device resets', font=('Segoe UI', 11)).grid(row=1, column=0, columnspan=3, sticky='w', pady=(4, 18))
    ttk.Label(page, text='1. Shut down your Miyoo and connect its Onion SD card to this computer.\n2. Select the card and your own ROM / BIOS.\n3. Install, safely eject the card, and launch Apps > IronMON.', justify='left').grid(row=2, column=0, columnspan=3, sticky='w', pady=(0, 18))
    values = {key: tk.StringVar() for key in ['sd', 'rom', 'bios']}
    controls = []
    for row, key, label in [(3, 'sd', 'Onion SD card root'), (4, 'rom', 'FireRed USA Rev 1'), (5, 'bios', 'GBA BIOS (optional)')]:
        ttk.Label(page, text=label).grid(row=row, column=0, sticky='w', padx=(0, 14), pady=5)
        entry = ttk.Entry(page, textvariable=values[key])
        entry.grid(row=row, column=1, sticky='ew', pady=5)
        def browse(field=key):
            if field == 'sd':
                selected = filedialog.askdirectory(title='Select the Onion SD card root (e.g. E:\\)', parent=root)
            else:
                types = [('FireRed ROM', '*.gba *.zip'), ('All files', '*')] if field == 'rom' else [('GBA BIOS', '*.bin'), ('All files', '*')]
                selected = filedialog.askopenfilename(title='Select your own ' + ('FireRed ROM' if field == 'rom' else 'GBA BIOS'), filetypes=types, parent=root)
            if selected:
                values[field].set(selected)
        button = ttk.Button(page, text='Browse...', command=browse)
        button.grid(row=row, column=2, padx=(8, 0))
        controls.extend([entry, button])
    ttk.Label(page, text='Leave BIOS blank to use BIOS/gba_bios.bin already on the card.\nSetup downloads ~54 MiB from the original projects and verifies every checksum.\nExisting runs, notes and settings are preserved; updates also keep a full app backup.', justify='left').grid(row=6, column=0, columnspan=3, sticky='w', pady=(10, 14))
    status = tk.StringVar(value='Ready. No administrator access, Python, Java or SSH setup required.')
    ttk.Label(page, textvariable=status, wraplength=680).grid(row=7, column=0, columnspan=3, sticky='w')
    progress = ttk.Progressbar(page, mode='indeterminate')
    progress.grid(row=8, column=0, columnspan=3, sticky='ew', pady=(8, 8))
    output = tk.Text(page, height=8, font=('Consolas', 9), state='disabled', wrap='word')
    output.grid(row=9, column=0, columnspan=3, sticky='nsew')
    page.rowconfigure(9, weight=1)
    events = queue.Queue()
    busy = False
    def append(text):
        output.configure(state='normal')
        output.insert('end', text + '\n')
        output.see('end')
        output.configure(state='disabled')
    def start():
        nonlocal busy
        sd, rom, bios = (values[x].get().strip() for x in ['sd', 'rom', 'bios'])
        if not sd or not rom:
            messagebox.showerror('Select your files', 'Select the Onion SD card root and your FireRed USA Rev 1 ROM.', parent=root)
            return
        busy = True
        for control in controls:
            control.configure(state='disabled')
        install_button.configure(state='disabled')
        status.set('Installing. Keep the SD card connected until setup finishes.')
        progress.start(12)
        def worker():
            try:
                result = install(sd, rom, bios or None, log=lambda s: events.put(('log', s)))
                events.put(('done', result))
            except Exception as error:
                events.put(('error', str(error)))
        threading.Thread(target=worker, daemon=True).start()
    install_button = ttk.Button(page, text='Install IronMON', command=start)
    install_button.grid(row=10, column=2, sticky='e', pady=(14, 0))
    ttk.Label(page, text='GPL-3.0 | Substantially developed with OpenAI Codex. See AI_USAGE.md.', font=('Segoe UI', 9)).grid(row=10, column=0, columnspan=2, sticky='w', pady=(14, 0))
    def poll():
        nonlocal busy
        while not events.empty():
            kind, content = events.get_nowait()
            if kind == 'log':
                append(content)
            else:
                busy = False
                progress.stop()
                for control in controls:
                    control.configure(state='normal')
                install_button.configure(state='normal')
                if kind == 'done':
                    status.set('Done! Safely eject the card, then open Apps > IronMON on your Miyoo.')
                    messagebox.showinfo('IronMON installed', 'Safely eject the SD card and put it back in your Miyoo.\nOpen Apps > IronMON. First launch may take 1-2 minutes.', parent=root)
                else:
                    append('ERROR: ' + content)
                    status.set('Installation stopped. Check the message below and try again.')
                    messagebox.showerror('Installation stopped', content, parent=root)
        root.after(150, poll)
    def close():
        if busy:
            messagebox.showinfo('Installation in progress', 'Leave setup open and the SD card connected until the installation finishes.', parent=root)
        else:
            root.destroy()
    root.protocol('WM_DELETE_WINDOW', close)
    root.after(150, poll)
    return root


def main():
    parser = argparse.ArgumentParser(description='Install Miyoo IronMON on an Onion SD card. Launch without arguments for the guided installer.')
    parser.add_argument('--sd', type=Path)
    parser.add_argument('--rom', type=Path)
    parser.add_argument('--bios', type=Path)
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--report', type=Path, help='Write a machine-readable result for automated installation checks.')
    parser.add_argument('--self-test', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.self_test:
            verify_payload(HERE / 'payload')
            root = create_gui()
            root.update()
            root.destroy()
            result = {'self_test': 'PASS', 'version': VERSION}
        elif args.sd and args.rom:
            result = install(args.sd, args.rom, args.bios, cache=args.cache, offline=args.offline)
        elif args.sd or args.rom or args.offline:
            parser.error('--sd and --rom must be supplied together.')
        else:
            create_gui().mainloop()
            return
        if args.report:
            args.report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    except Exception as error:
        if args.report:
            args.report.write_text(json.dumps({'error': str(error)}) + '\n', encoding='utf-8')
        if sys.stdout:
            print(f'Installation stopped: {error}', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
