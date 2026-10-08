"""Installer integration tests use synthetic data; no ROM/BIOS is needed."""
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import install as setup


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sd = self.root / 'card'
        (self.sd / 'App').mkdir(parents=True)
        for name in ['RetroArch/.retroarch/cores/gpsp_libretro.so', '.tmp_update/bin/infoPanel', '.tmp_update/lib/parasyte/libatomic.so.1']:
            path = self.sd / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'test placeholder')
        self.payload = self.root / 'payload'
        self.payload.mkdir()
        payload_files = {'ironmon': b'test binary', 'launch.sh': b'#!/bin/sh\n', 'seed-cache.sh': b'#!/bin/sh\n',
                         'settings.ini': b'player=RED\nrival=BLUE\ngender=0\nfast_forward=hold\n'}
        for name, data in payload_files.items():
            (self.payload / name).write_bytes(data)
        (self.payload / 'manifest.json').write_text(json.dumps({'version': setup.VERSION,
            'files': {name: hashlib.sha256(data).hexdigest() for name, data in payload_files.items()}}))
        # Zeroed synthetic bytes with only the known patcher hook; no game content.
        rom = bytearray(16777216)
        rom[0x860d5:0x860d7] = b'\x60\x00'
        self.rom = self.root / 'synthetic.gba'
        self.rom.write_bytes(rom)
        self.bios = self.root / 'synthetic-bios.bin'
        self.bios.write_bytes(b'TEST' * 4096)
        self.cache = self.root / 'cache'
        self.cache.mkdir()
        self.specs = {}
        self.zip_asset('tracker', {'Ironmon-Tracker/Ironmon-Tracker.lua': b'test tracker', 'Ironmon-Tracker/LICENSE.txt': b'test notice'})
        self.zip_asset('randomizer', {'PokeRandoZX.jar': b'test jar', 'README.txt': b'test readme'})
        self.zip_asset('font', {'dejavu-sans-ttf-2.37/ttf/DejaVuSans.ttf': b'test font',
            'dejavu-sans-ttf-2.37/LICENSE': b'test font notice', 'dejavu-sans-ttf-2.37/AUTHORS': b'test authors'})
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w:gz') as tar:
            for name, data in {'java/bin/java': b'test executable', 'java/LICENSE': b'test java license'}.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                member.mode = 0o755 if name.endswith('/java') else 0o644
                tar.addfile(member, io.BytesIO(data))
        self.asset('java', archive.getvalue(), '.tar.gz')
        self.asset('randomizer_license', b'test GPL notice', '.txt')
        self.asset('patch', b'PATCHEOF', '.ips')
        (self.root / 'dependencies.json').write_text(json.dumps(self.specs))
        for name, value in [('HERE', self.root), ('BASE_SHA1', hashlib.sha1(rom).hexdigest()),
                            ('BIOS_SHA1', hashlib.sha1(self.bios.read_bytes()).hexdigest())]:
            context = patch.object(setup, name, value)
            context.start()
            self.addCleanup(context.stop)

    def asset(self, key, data, extension):
        path = self.cache / (key + extension)
        path.write_bytes(data)
        self.specs[key] = {'file': path.name, 'sha256': hashlib.sha256(data).hexdigest(), 'url': 'https://example.invalid/' + path.name}

    def zip_asset(self, key, files):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            for name, content in files.items():
                archive.writestr(name, content)
        self.asset(key, data.getvalue(), '.zip')

    def run_setup(self):
        return setup.install(self.sd, self.rom, self.bios, payload=self.payload,
                             cache=self.cache, offline=True, log=lambda _: None)

    def no_staging(self):
        self.assertEqual(list((self.sd / 'App').glob('.IronMON-install-*')), [])

    def test_fresh_install_and_update_preserve_current_run_settings_notes_and_backup(self):
        result = self.run_setup()
        app = Path(result['target'])
        self.assertIsNone(result['backup'])
        self.assertEqual((self.sd / 'BIOS/gba_bios.bin').read_bytes(), self.bios.read_bytes())
        self.assertEqual(setup.sha256(app / 'source-qol.gba'), result['prepared_sha256'])
        (app / 'data/current.state').write_bytes(b'irreplaceable run state')
        (app / 'data/current.gba').write_bytes(b'current randomized run')
        (app / 'data/current.rules').write_text('routes=140\nended=0\n')
        (app / 'tracker/TrackerSettings.ini').write_text('custom theme and notes')
        (app / 'data/cache').mkdir()
        (app / 'data/cache/reserve').write_bytes(b'reserve checkpoint')
        settings = (app / 'settings.ini').read_bytes() + b'backup_count=6\n'
        (app / 'settings.ini').write_bytes(settings)
        result = self.run_setup()
        backup = Path(result['backup'])
        for folder in [app, backup]:
            self.assertEqual((folder / 'data/current.state').read_bytes(), b'irreplaceable run state')
            self.assertEqual((folder / 'data/current.gba').read_bytes(), b'current randomized run')
            self.assertEqual((folder / 'settings.ini').read_bytes(), settings)
            self.assertEqual((folder / 'tracker/TrackerSettings.ini').read_text(), 'custom theme and notes')
        self.assertTrue((app / 'data/cache/reserve').exists(), 'matching reserve cache was lost')
        self.no_staging()

    def test_changed_prepared_base_invalidates_reserves_but_preserves_run_and_backup(self):
        app = Path(self.run_setup()['target'])
        (app / 'data/current.state').write_bytes(b'current run')
        (app / 'data/cache').mkdir()
        (app / 'data/cache/reserve').write_bytes(b'old seed')
        (app / 'settings.ini').write_text('player=GREEN\nrival=BLUE\ngender=1\n')
        result = self.run_setup()
        self.assertFalse((app / 'data/cache').exists())
        self.assertTrue((Path(result['backup']) / 'data/cache/reserve').exists())
        self.assertEqual((app / 'data/current.state').read_bytes(), b'current run')

    def test_failed_final_swap_rolls_back_previous_app(self):
        app = Path(self.run_setup()['target'])
        (app / 'data/current.state').write_bytes(b'keep this run')
        rename = Path.rename
        def fail_stage(source, destination):
            if source.name.startswith('.IronMON-install-'):
                raise OSError('simulated final swap failure')
            return rename(source, destination)
        with patch.object(Path, 'rename', fail_stage), self.assertRaisesRegex(OSError, 'swap failure'):
            self.run_setup()
        self.assertEqual((app / 'data/current.state').read_bytes(), b'keep this run')
        self.no_staging()

    def test_bad_upstream_structure_cleans_stage_without_touching_old_app(self):
        app = Path(self.run_setup()['target'])
        (app / 'data/current.state').write_bytes(b'keep this run')
        self.zip_asset('tracker', {'different-root/file': b'unexpected'})
        (self.root / 'dependencies.json').write_text(json.dumps(self.specs))
        with self.assertRaises(FileNotFoundError):
            self.run_setup()
        self.assertEqual((app / 'data/current.state').read_bytes(), b'keep this run')
        self.no_staging()

    def test_wrong_rom_and_corrupt_payload_make_no_card_changes(self):
        self.rom.write_bytes(b'wrong revision')
        with self.assertRaises(ValueError):
            self.run_setup()
        self.assertFalse((self.sd / 'App/IronMON').exists())
        (self.payload / 'ironmon').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'payload'):
            self.run_setup()
        self.no_staging()

    def test_bios_conflict_preserves_existing_bios(self):
        (self.sd / 'BIOS').mkdir()
        (self.sd / 'BIOS/gba_bios.bin').write_bytes(b'old incompatible file')
        with self.assertRaisesRegex(ValueError, 'incompatible BIOS'):
            self.run_setup()
        self.assertEqual((self.sd / 'BIOS/gba_bios.bin').read_bytes(), b'old incompatible file')
        self.no_staging()

    def test_rom_zip_selects_matching_revision(self):
        archive = self.root / 'multi.zip'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr('wrong.gba', bytes(16777216))
            z.write(self.rom, 'correct.gba')
        self.assertEqual(setup.read_rom(archive), self.rom.read_bytes())

    def test_corrupt_cache_and_bad_download_are_rejected(self):
        spec = self.specs['patch']
        path = self.cache / spec['file']
        path.write_bytes(b'corrupt cached file')
        with self.assertRaisesRegex(ValueError, 'corrupt cached'):
            self.run_setup()
        with patch.object(setup.urllib.request, 'urlopen', return_value=io.BytesIO(b'bad download')):
            with self.assertRaisesRegex(ValueError, 'Checksum mismatch'):
                setup.fetch(spec, self.cache, log=lambda _: None)
        self.assertEqual(path.read_bytes(), b'corrupt cached file')
        self.assertEqual(list(self.cache.glob('*.part-*')), [])
        self.no_staging()

    def test_archive_traversal_and_external_links_are_rejected(self):
        for name in ['../escape', '/absolute', 'C:/drive', 'folder\\escape']:
            with self.assertRaises(ValueError):
                setup.safe_member(self.root / 'unpack', name)
        archive = self.root / 'bad.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('../escape', b'no')
        with self.assertRaises(ValueError):
            setup.extract_zip(archive, self.root / 'unpack')
        archive = self.root / 'bad.tar'
        with tarfile.open(archive, 'w') as tar:
            member = tarfile.TarInfo('runtime/link')
            member.type = tarfile.SYMTYPE
            member.linkname = '../../../escape'
            tar.addfile(member)
        with self.assertRaises(ValueError):
            setup.extract_tar(archive, self.root / 'unpack')
        self.assertFalse((self.root / 'escape').exists())

    def test_internal_java_links_become_fat32_compatible_copies(self):
        archive = self.root / 'links.tar'
        with tarfile.open(archive, 'w') as tar:
            member = tarfile.TarInfo('runtime/lib/file')
            member.size = 3
            tar.addfile(member, io.BytesIO(b'yes'))
            member = tarfile.TarInfo('runtime/bin/link')
            member.type = tarfile.SYMTYPE
            member.linkname = '../lib/file'
            tar.addfile(member)
        setup.extract_tar(archive, self.root / 'unpack')
        link = self.root / 'unpack/runtime/bin/link'
        self.assertFalse(link.is_symlink())
        self.assertEqual(link.read_bytes(), b'yes')


if __name__ == '__main__':
    unittest.main()
