from pathlib import Path
import subprocess

src=Path(__file__).resolve().parent
base=src/'build'
sdk=base/'miyoomini-toolchain'
cc=sdk/'bin/arm-linux-gnueabihf-gcc'
sysroot=sdk/'arm-linux-gnueabihf/libc'
lua=base/'lua-5.4.8/src'
flags=['--sysroot='+str(sysroot),'-O2','-std=gnu99','-D_GNU_SOURCE',
       '-DLUA_USE_LINUX','-I'+str(lua),'-I'+str(src),'-I'+str(sysroot/'usr/include')]
liblua=base/'liblua.a'
if not liblua.exists():
    objects=base/'lua-objects';objects.mkdir(exist_ok=True)
    sources=[str(p) for p in lua.glob('*.c') if p.name not in ('lua.c','luac.c')]
    subprocess.run([str(cc),*flags,'-c',*sources],cwd=objects,check=True)
    subprocess.run([str(sdk/'bin/arm-linux-gnueabihf-ar'),'rcs',str(liblua),*[str(x) for x in objects.glob('*.o')]],check=True)
cmd=[str(cc),*flags,str(src/'ironmon.c'),str(liblua),'-L'+str(src/'device-libs'),
     '-Wl,--unresolved-symbols=ignore-in-shared-libs','-lSDL','-lSDL_ttf','-lSDL_image',
     '-ldl','-lm','-lpthread','-o',str(src/'ironmon')]
print('Building native ARM frontend',flush=True)
subprocess.run(cmd,check=True)
subprocess.run([str(sdk/'bin/arm-linux-gnueabihf-strip'),str(src/'ironmon')],check=True)
print('Build complete',flush=True)
if '--lua' in __import__('sys').argv:
    subprocess.run([str(cc),*flags,str(lua/'lua.c'),str(liblua),'-ldl','-lm','-o',str(src/'lua-test')],check=True)
if '--tests' in __import__('sys').argv:
    subprocess.run([str(cc),*flags,str(src/'tests/test_panel_mapping.c'),'-o',str(base/'panel-test')],check=True)
