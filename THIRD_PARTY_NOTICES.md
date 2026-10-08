# Third-party notices

The custom port and installer are **GPL-3.0-only**; see [LICENSE](LICENSE).
The intro routine in `prepare_rom.py` is adapted from DrMaple's GPL-3.0 Patch
Editor. UPR ZX configuration addresses derive from GPL-3.0-or-later code.
Exact references/versions are in [SOURCES.md](SOURCES.md).

## Included in the source / app payload

- `libretro.h`: MIT notice retained in the header.
- `stb_image.h`: MIT / public-domain notice retained in the header.
- Lua 5.4.8: statically linked into the ARM frontend; MIT notice in [LUA-LICENSE.txt](LUA-LICENSE.txt).
- Custom program, adapter, guards, installer and documentation: GPL-3.0-only. Corresponding source is in this repository and the matching release tag.

## Downloaded by the installer

- Original Ironmon Tracker 9.4.0: MIT; `tracker/LICENSE.txt` and the original release files are retained.
- UPR ZX 4.6.1: GPL-3.0-or-later; installs `licenses/UPR-ZX-LICENSE.txt` and the upstream README. [Source tag](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/tree/v4.6.1).
- Temurin 8u504 ARM JRE: GPLv2 with Classpath exception and third-party notices. Complete `LICENSE`, `NOTICE`, `ASSEMBLY_EXCEPTION`, `THIRD_PARTY_README` and archive contents are retained. [Upstream release/source links](https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u504-b01).
- DejaVu Sans 2.37: Bitstream Vera license; DejaVu additions are public domain. Installs `font.ttf`, `licenses/DejaVu-LICENSE.txt` and `licenses/DejaVu-AUTHORS.txt`.
- Faster FireRed 1.3.2 IPS: downloaded from DrMaple and applied locally to the user's ROM. No general redistribution license was found. The patch is **not bundled** in this repository or release packages.

## Windows installer runtime

The EXE is packaged with PyInstaller and includes CPython, Tcl/Tk, OpenSSL and
runtime dependencies. Applicable notices are in the release ZIP's
`installer-licenses/` and embedded in the EXE. PyInstaller's GPL exception allows
bundled applications to retain their own licenses. Packaging sources/references
are in [SOURCES.md](SOURCES.md).

## Supplied by the device / user

Onion's gpSP core, SDL libraries, firmware libraries, the user's ROM and GBA BIOS
are not distributed here. Releases contain no ROMs, BIOS or saves. Setup retains
upstream notices and never downloads a ROM or BIOS.

Pokémon and its game content/trademarks belong to their rights holders. This
project is unaffiliated with Nintendo, Game Freak, The Pokémon Company, IronMON,
the Tracker project or Onion.
