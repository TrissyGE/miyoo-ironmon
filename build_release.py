"""Package the prebuilt ARM app and guided installers. GPL-3.0-only.

Run build.py first. Use --windows on Windows with PyInstaller 6.22.0 installed.
No game files or downloaded runtime archives are included in these packages.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile

from install import VERSION, sha256, verify_payload

ROOT = Path(__file__).resolve().parent
APP_FILES = [
    'ironmon', 'bootstrap.lua', 'forms.lua', 'qol.lua', 'tracker_layout.lua',
    'rules.lua', 'rule_policy.lua', 'prepare.lua', 'launch.sh', 'seed-cache.sh',
    'settings.ini', 'standard.rnqs', 'config.json', 'LICENSE', 'LUA-LICENSE.txt',
    'THIRD_PARTY_NOTICES.md', 'SOURCES.md', 'AI_USAGE.md', 'INSTALL.md',
]
DOCS = ['INSTALL.md', 'AI_USAGE.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'SOURCES.md', 'CHANGELOG.md']


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def payload():
    binary = (ROOT / 'ironmon').read_bytes()
    if binary[:4] != b'\x7fELF' or int.from_bytes(binary[18:20], 'little') != 40:
        raise ValueError('Build the ARM frontend with build.py before packaging.')
    destination = ROOT / 'payload'
    destination.mkdir(exist_ok=True)
    hashes = {}
    for name in APP_FILES:
        target = destination / name
        if name in ['ironmon', 'standard.rnqs']:
            shutil.copy2(ROOT / name, target)
        else:
            target.write_bytes((ROOT / name).read_bytes().replace(b'\r\n', b'\n'))
        if name in ['ironmon', 'launch.sh', 'seed-cache.sh']:
            target.chmod(0o755)
        hashes[name] = sha256(target)
    revision = git('rev-parse', 'HEAD')
    dirty = bool(git('status', '--porcelain'))
    text = (f'Miyoo IronMON {VERSION}\nSource: https://github.com/TrissyGE/miyoo-ironmon\n'
            f'Revision: {revision}{" (development working tree)" if dirty else ""}\n'
            f'Release source: https://github.com/TrissyGE/miyoo-ironmon/tree/v{VERSION}\n'
            'Custom port: GPL-3.0-only. Lua: MIT (LUA-LICENSE.txt).\n'
            'See THIRD_PARTY_NOTICES.md and AI_USAGE.md.\n')
    (destination / 'SOURCE.txt').write_text(text, encoding='utf-8', newline='\n')
    hashes['SOURCE.txt'] = sha256(destination / 'SOURCE.txt')
    manifest = {'version': VERSION, 'source_revision': revision, 'development': dirty, 'files': hashes}
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    verify_payload(destination)
    return destination, manifest


def zip_files(path, files):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source, name in files:
            if Path(source).suffix.lower() in ['.gba', '.srm', '.state', '.tdat', '.ips', '.log']:
                raise ValueError('Game data cannot be packaged: ' + str(source))
            archive.write(source, name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'release')
    parser.add_argument('--payload-only', action='store_true')
    parser.add_argument('--windows', action='store_true')
    args = parser.parse_args()
    app, manifest = payload()
    if args.payload_only:
        print('Verified ARM payload:', app)
        return
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    docs = [(ROOT / name, name) for name in DOCS]
    python_files = [(ROOT / name, name) for name in ['install.py', 'prepare_rom.py', 'dependencies.json']]
    python_files += [(app / name, 'payload/' + name) for name in [*manifest['files'], 'manifest.json']]
    zip_files(out / 'IronMON-Setup-Python.zip', python_files + docs)
    sources = git('ls-files', '--cached', '--others', '--exclude-standard').splitlines()
    source_files = [(ROOT / name, name) for name in sources if (ROOT / name).is_file()]
    lua = ROOT / 'lua.tar.gz'
    if not lua.exists():
        raise ValueError('Provide the Lua 5.4.8 source archive at lua.tar.gz for the complete source release.')
    source_files.append((lua, 'third-party/lua-5.4.8.tar.gz'))
    zip_files(out / 'IronMON-Source.zip', source_files)
    if args.windows:
        if sys.platform != 'win32':
            raise ValueError('The Windows EXE must be built on Windows.')
        import PyInstaller
        if PyInstaller.__version__ != '6.22.0':
            raise ValueError('This release build uses PyInstaller 6.22.0.')
        notices = ROOT / 'docs/installer-licenses'
        if not (notices / 'CPython-LICENSE.txt').exists():
            raise ValueError('Windows runtime notices are missing.')
        work = ROOT / 'build/release-installer'
        work.mkdir(parents=True, exist_ok=True)
        command = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onefile', '--windowed',
                   '--name', 'IronMON-Setup', '--distpath', str(out), '--workpath', str(work), '--specpath', str(work),
                   '--add-data', str(app) + ':payload', '--add-data', str(ROOT / 'dependencies.json') + ':.',
                   '--add-data', str(notices) + ':installer-licenses', str(ROOT / 'install.py')]
        subprocess.run(command, cwd=ROOT, check=True)
        runtime_notices = [(path, 'installer-licenses/' + path.name) for path in sorted(notices.iterdir()) if path.is_file()]
        zip_files(out / 'IronMON-Setup-Windows.zip', [(out / 'IronMON-Setup.exe', 'IronMON-Setup.exe')] + docs + runtime_notices)
    assets = sorted(out.glob('*.zip'))
    if args.windows:
        assets.append(out / 'IronMON-Setup.exe')
    (out / 'SHA256SUMS.txt').write_text(''.join(sha256(p) + '  ' + p.name + '\n' for p in assets), encoding='ascii', newline='\n')
    print('Release packages:', out)
    print('Source revision:', manifest['source_revision'], 'development:', manifest['development'])


if __name__ == '__main__':
    main()
