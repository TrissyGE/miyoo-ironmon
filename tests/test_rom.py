import importlib.util
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('patcher',Path(__file__).resolve().parents[1]/'prepare_rom.py')
patcher=importlib.util.module_from_spec(spec);spec.loader.exec_module(patcher)

class PatcherTests(unittest.TestCase):
    def test_ips_literal_rle_and_extension(self):
        patch=b'PATCH'+bytes.fromhex('0000010002')+b'XY'+bytes.fromhex('000008000000035a')+b'EOF'
        result=patcher.apply_ips(b'abcde',patch)
        self.assertEqual(result,b'aXYde\xff\xff\xffZZZ')

    def test_truncated_record_is_rejected(self):
        with self.assertRaises(ValueError): patcher.apply_ips(b'ab',b'PATCH'+bytes.fromhex('0000010006')+b'XY')

    def test_wrong_patch_header_rejected(self):
        with self.assertRaises(ValueError): patcher.apply_ips(b'ab',b'wrong')

    def test_intro_preserves_rom_size_and_terminates_names(self):
        rom=bytearray(0x800000);rom[0x860d5:0x860d7]=b'\x60\x00'
        result=patcher.speech_skip(rom,'RED','BLUE',1)
        self.assertEqual(len(result),0x800000)
        self.assertEqual(result[0x780037:0x78003c],b'\xff'*5)
        self.assertEqual(result[0x780040:0x780044],b'\xff'*4)
        self.assertEqual(result[0x780044],1)

    def test_unknown_intro_hook_rejected(self):
        with self.assertRaises(ValueError): patcher.speech_skip(bytearray(0x800000))

    def test_name_validation(self):
        with self.assertRaises(ValueError): patcher.encode_name('TOO-LONG')
        with self.assertRaises(KeyError): patcher.encode_name('☃')

if __name__=='__main__': unittest.main()
