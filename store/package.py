"""Build the ROM-free Mixtape package from the regular release payload."""
from pathlib import Path, PurePosixPath
import json
import posixpath
import tarfile
import zipfile

from install import VERSION, fetch, sha256
from prepare_rom import INTRO_WRITES, SHOP_OFFSETS

ROOT = Path(__file__).resolve().parents[1]
APP = 'App/IronMON-Mixtape'
REPO = 'https://github.com/TrissyGE/miyoo-ironmon'
MIXTAPE_SOURCE = 'https://raw.githubusercontent.com/snyderman3000/mixtape/ffb88ad1c9efa5f74b7e88345c1ff94fa5cbf00b/'
CERT = {'file': 'store-mozilla-cacert.pem', 'url': MIXTAPE_SOURCE+'assets/cacert.pem',
        'sha256': '3ff344e30b9b1ed2971044eabb438a08f2e2245ddb5f8ab1a3ad8b63ab4eaf91'}
CERT_LICENSE = {'file': 'store-MPL-2.0-cacert.txt', 'url': MIXTAPE_SOURCE+'package/Mixtape/licenses/MPL-2.0-cacert.txt',
                'sha256': '66a3107d5ad6a058aab753eaac2047ccb2ed0e39465dd0fe5844da3e300d5172'}


def java_layout(archive):
    with tarfile.open(archive, 'r:gz') as source:
        members = source.getmembers()
        paths = {m.name for m in members}
        roots = {PurePosixPath(name).parts[0] for name in paths}
        if len(roots) != 1 or any(PurePosixPath(n).is_absolute() or '..' in PurePosixPath(n).parts for n in paths):
            raise ValueError('Unexpected Java archive root.')
        root = roots.pop()
        links = {}
        for m in members:
            if m.issym() or m.islnk():
                target = posixpath.normpath(posixpath.join(posixpath.dirname(m.name), m.linkname) if m.issym() else m.linkname)
                if not target.startswith(root+'/') or target not in paths:
                    raise ValueError('Java link leaves its archive.')
                links[m.name] = target
            elif not (m.isfile() or m.isdir()):
                raise ValueError('Unsupported Java archive entry.')
        if any(target in links for target in links.values()) or any(c.isspace() for name in [root,*links,*links.values()] for c in name):
            raise ValueError('Unsupported Java link layout.')
    return root, links


def build_store(out, app, manifest):
    cli = (ROOT/'lua-test').read_bytes()
    if cli[:4] != b'\x7fELF' or int.from_bytes(cli[18:20], 'little') != 40:
        raise ValueError('Build the ARM Lua CLI with build.py --lua.')
    deps = json.loads((ROOT/'dependencies.json').read_text(encoding='utf-8'))
    cache = ROOT/'release-cache'
    java_root, links = java_layout(fetch(deps['java'], cache))
    entries = {name: (app/name).read_bytes() for name in manifest['files'] if name not in ('settings.ini', 'config.json')}
    def txt(name, value): entries[name] = value.encode('utf-8')
    txt('config.json', json.dumps({'label':'IronMON (Mixtape)', 'icon':'/mnt/SDCARD/Icons/Default/gba.png',
        'launch':'mixtape-launch.sh', 'description':'FireRed Standard IronMON with Tracker'}, indent=2)+'\n')
    entries['mixtape-launch.sh'] = (ROOT/'store/launch.sh').read_bytes().replace(b'\r\n', b'\n')
    for name in ['setup.sh','prepare.lua']:
        entries['store/'+name] = (ROOT/'store'/name).read_bytes().replace(b'\r\n', b'\n')
    entries['store/settings.default.ini'] = (app/'settings.ini').read_bytes()
    entries['store/ironmon-setup-lua'] = cli
    entries['store/cacert.pem'] = fetch(CERT, cache).read_bytes()
    entries['store/MPL-2.0-cacert.txt'] = fetch(CERT_LICENSE, cache).read_bytes()
    txt('store/dependencies.tsv', ''.join(f"{k} {v['file']} {v['sha256']} {v['url']}\n" for k,v in deps.items()))
    txt('store/java-root.txt', java_root+'\n')
    txt('store/java-excludes.txt', ''.join(name+'\n' for name in links))
    txt('store/java-links.tsv', ''.join(f'{name} {target}\n' for name,target in links.items()))
    writes = ',\n'.join('    {'+str(offset)+',"'+''.join(f'\\x{b:02x}' for b in data)+'"}' for offset,data in INTRO_WRITES)
    txt('store/rom-spec.lua', '-- Generated from prepare_rom.py.\nreturn {writes={\n'+writes+'\n},shops={'+','.join(map(str,SHOP_OFFSETS))+'}}\n')
    filename = f'IronMON-v{VERSION}-OnionOS.zip'
    result = out/filename
    with zipfile.ZipFile(result, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            if Path(name).suffix.lower() in {'.gba','.bios','.srm','.state','.tdat','.ips','.log','.bin'} or name.startswith('data/'):
                raise ValueError(f'Game or mutable data cannot be packaged: {name}')
            info = zipfile.ZipInfo(f'{APP}/{name}')
            executable = name.endswith('.sh') or name in ('ironmon','store/ironmon-setup-lua')
            info.create_system = 3
            info.external_attr = (0o100755 if executable else 0o100644) << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    catalog = {'name':'Miyoo IronMON', 'homepage':REPO, 'ports':[{
        'name':'Miyoo IronMON', 'version':VERSION, 'url':f'{REPO}/releases/download/v{VERSION}/{filename}',
        'sha256':sha256(result), 'size':result.stat().st_size, 'categories':['app'], 'status':'playable',
        'assets':'owned', 'porter':['TrissyGE'], 'upstream':REPO,
        'image':'https://raw.githubusercontent.com/TrissyGE/miyoo-ironmon/9570265852b4b171e936ad55864d3cdaeaf9ca50/docs/images/battle-own.png',
        'notes':'Miyoo Mini Plus, tested on Onion 4.4 beta. Put FireRed USA Rev 1 at App/IronMON-Mixtape/source.gba and your GBA BIOS at BIOS/gba_bios.bin. Wi-Fi for first setup only. Start IronMON (Mixtape) in Apps.',
    }]}
    (out/'mixtape.json').write_text(json.dumps(catalog, indent=2)+'\n', encoding='utf-8', newline='\n')
    print('Mixtape package:', result, 'SHA-256:', catalog['ports'][0]['sha256'])
