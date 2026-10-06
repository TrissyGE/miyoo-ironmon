"""Prepare a user's own FireRed Rev 1. No ROM is distributed or downloaded.

Intro routine adapted from DrMaple/IronMONPatchEditor (GPL-3.0), commit
457484f8d26c9aaaadb31a2aa7420c14918f4b2c, MainWindow.cs.
See SOURCES.md. Faster FireRed is downloaded from its author's release.
"""
from pathlib import Path
import argparse
import hashlib
import urllib.request

BASE_SHA1 = 'dd5945db9b930750cb39d00c84da8571feebf417'
PATCH_URL = 'https://github.com/DrMaple/Faster-FireRed/releases/download/1.3.2/Faster.FireRed.1.3.2.ips'

def apply_ips(rom, patch):
    if not patch.startswith(b'PATCH'):
        raise ValueError('Invalid IPS header')
    rom = bytearray(rom)
    pos = 5
    while patch[pos:pos+3] != b'EOF':
        if pos+5 > len(patch): raise ValueError('Truncated IPS')
        offset = int.from_bytes(patch[pos:pos+3], 'big')
        size = int.from_bytes(patch[pos+3:pos+5], 'big'); pos += 5
        if size:
            data = patch[pos:pos+size]; pos += size
            if len(data) != size: raise ValueError('Truncated record')
        else:
            if pos+3 > len(patch): raise ValueError('Truncated RLE')
            count = int.from_bytes(patch[pos:pos+2], 'big')
            data = patch[pos+2:pos+3]*count; pos += 3
        if offset+len(data)>len(rom): rom.extend(b'\xff'*(offset+len(data)-len(rom)))
        rom[offset:offset+len(data)] = data
    pos += 3
    if len(patch)-pos == 3: rom = rom[:int.from_bytes(patch[pos:], 'big')]
    return rom

def encode_name(name):
    chars = {' ':0, '!':0xab, '?':0xac, '.':0xad, '-':0xae, ',':0xb8, '/':0xba}
    chars.update({chr(65+i):0xbb+i for i in range(26)})
    chars.update({chr(97+i):0xd5+i for i in range(26)})
    chars.update({str(i):0xa1+i for i in range(10)})
    if not 1<=len(name)<=7: raise ValueError('Names must contain 1 to 7 characters')
    return bytes(chars[c] for c in name).ljust(8,b'\xff')

def speech_skip(rom, player='RED', rival='BLUE', gender=0):
    # Check the Faster FireRed hook rather than applying offsets to another game.
    if rom[0x860d5:0x860d7] != b'\x60\x00':
        raise ValueError('Unsupported Faster FireRed hook')
    routine = bytes.fromhex('FE B4 09 4A 12 68 09 48 09 49 13 18 54 1A 09 48 20 60 09 48 60 60 09 48 18 60 09 48 58 60 09 48 20 72 FE BC 08 48 00 47 08 50 00 03 4C 3A 00 00 A4 0F 00 00')
    rom[0x780000:0x780034] = routine
    rom[0x780034:0x78003c] = encode_name(player)
    rom[0x78003c:0x780044] = encode_name(rival)
    rom[0x780044] = gender
    rom[0x780045:0x78004c] = bytes.fromhex('00 00 00 59 66 05 08')
    rom[0x12ef04:0x12ef07] = bytes.fromhex('01 00 78')
    rom[0x54968:0x54980] = bytes.fromhex('04 4B 1A 68 00 21 D1 74 02 21 11 75 02 21 51 75 70 47 00 00 0C 50 00 03')
    return rom

def restrict_shops(rom):
    # Universal Pokemon Randomizer ZX 4.6.1 config/gen3_offsets.ini, BPRE Rev 1.
    offsets=(0x164a30,0x16775c,0x167774,0x167790,0x1677b0,0x16a310,0x16a780,0x16ad50,0x16b408,0x16b704,0x16bbb0,0x16bbec,0x16bca8,0x16bcfc,0x16bd34,0x16d590,0x16eac0,0x16eb6c,0x16f054,0x170bd0,0x17192c,0x171d4c,0x171f04)
    for offset in offsets:
        items=[];pos=offset
        while True:
            item=int.from_bytes(rom[pos:pos+2],'little');pos+=2
            if item==0: break
            if not 1<=item<=374 or len(items)>60: raise ValueError(f'Invalid shop table at {offset:x}')
            items.append(item)
        kept=[i for i in items if 1<=i<=12 or i in (83,84,86)]
        data=b''.join(i.to_bytes(2,'little') for i in kept)+b'\x00\x00'
        rom[offset:pos]=data.ljust(pos-offset,b'\x00')
    return rom

def main():
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path)
    p.add_argument('--patch',type=Path,required=True);p.add_argument('--download',action='store_true')
    p.add_argument('--player',default='RED');p.add_argument('--rival',default='BLUE');p.add_argument('--gender',type=int,choices=(0,1),default=0)
    a=p.parse_args();base=a.source.read_bytes()
    if hashlib.sha1(base).hexdigest()!=BASE_SHA1: raise SystemExit('Expected unmodified FireRed USA Rev 1')
    if a.download and not a.patch.exists():
        a.patch.parent.mkdir(parents=True,exist_ok=True)
        urllib.request.urlretrieve(PATCH_URL,a.patch)
    patch=a.patch.read_bytes();result=restrict_shops(speech_skip(apply_ips(base,patch),a.player,a.rival,a.gender))
    a.output.write_bytes(result)
    print('Faster FireRed 1.3.2 + speech skip; IPS SHA256:',hashlib.sha256(patch).hexdigest())
    print('Prepared base SHA256:',hashlib.sha256(result).hexdigest())
if __name__=='__main__': main()
