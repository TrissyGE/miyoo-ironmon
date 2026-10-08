# Sources and pinned versions

Development references, checked for this release on **8 October 2026**.
Upstream work is credited to its authors. [Third-party notices](THIRD_PARTY_NOTICES.md)
explain what is included, downloaded or supplied by the user/device.

| Source | Use / version |
| --- | --- |
| [Ironmon Tracker by besteon](https://github.com/besteon/Ironmon-Tracker) · [9.4.0](https://github.com/besteon/Ironmon-Tracker/releases/tag/v9.4.0) | Original Tracker, TrackerAPI, memory addresses and data structures. MIT; downloaded separately. |
| [Standard IronMON rules](https://gist.github.com/valiant-code/adb18d248fa0fae7da6b639e2ee8f9c1#standard-ironmon-ruleset) · [ironmon.gg](https://ironmon.gg/) | Catch OR KO per location, permanent death and lost held items, team wipe, shops, starters/favourites, legendary restrictions, theft, repeat prevention, shiny/discard exceptions and Mom. |
| [Standard settings by UTDZac](https://gist.github.com/UTDZac/a147c497424dfbd537d8c4b0c22b5621) | Basis of standard.rnqs; UPR ZX upgrades the old settings-format version when reading it. |
| [Universal Pokémon Randomizer ZX](https://github.com/Ajarmar/universal-pokemon-randomizer-zx) · [4.6.1](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/releases/tag/v4.6.1) | On-device randomizer. [Gen3RomHandler](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/romhandlers/Gen3RomHandler.java), [Gen3Constants](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/constants/Gen3Constants.java), [gen3_offsets.ini](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/config/gen3_offsets.ini): starter order, script and shop addresses. GPL-3.0-or-later. |
| [Faster FireRed by DrMaple](https://github.com/DrMaple/Faster-FireRed) · [1.3.2](https://github.com/DrMaple/Faster-FireRed/releases/tag/1.3.2) | Separately downloaded QoL patch: Mom/lab, shorter parcel quest, Repel prompts, healing, TM/item markers, renaming and field items. Not bundled in releases. |
| [IronMON Patch Editor by DrMaple](https://github.com/DrMaple/IronMONPatchEditor) · [MainWindow.cs](https://github.com/DrMaple/IronMONPatchEditor/blob/457484f8d26c9aaaadb31a2aa7420c14918f4b2c/IronMONPatchEditor/MainWindow.cs) | Adapted speech-skip routine and name encoding in prepare_rom.py; commit 457484f8d26c9aaaadb31a2aa7420c14918f4b2c. GPL-3.0. |
| [pret/pokefirered](https://github.com/pret/pokefirered/tree/037335f4c725d7c9aecdac87066f2002b4bd7e14) | Primary reference for Gen 3 structures and game flow: [load_save.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/load_save.c), [pokemon.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/pokemon.h), [pokemon_storage_system.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/pokemon_storage_system.h), [global.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/global.h), [global.fieldmap.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/global.fieldmap.h), [flags.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/flags.h), [items.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/items.h), [species.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/species.h), [shop.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/shop.c), [battle_controller_player.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_controller_player.c), [overworld.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/overworld.c), [Lab scripts](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps/PalletTown_ProfessorOaksLab/scripts.inc), [Maps](https://github.com/pret/pokefirered/tree/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps). Reference only; no game content is distributed. |
| [gpSP libretro](https://github.com/libretro/gpsp) | Existing Onion GBA core. Not bundled. |
| [libretro-common](https://github.com/libretro/libretro-common) | libretro.h; license retained in the header. |
| [SDL 1.2](https://www.libsdl.org/release/SDL-1.2.15/docs.html) · [SDL_ttf](https://github.com/libsdl-org/SDL_ttf) · [SDL_image](https://github.com/libsdl-org/SDL_image) | Existing device libraries for display, text and images. |
| [stb by Sean Barrett](https://github.com/nothings/stb) | GIF decoder in stb_image.h; MIT / public-domain option. |
| [Lua 5.4.8](https://www.lua.org/ftp/lua-5.4.8.tar.gz) · [License](https://www.lua.org/license.html) | Statically embedded Lua interpreter; MIT. |
| [Miyoo toolchain by Shaun Inman](https://github.com/shauninman/miyoomini-toolchain-buildroot/releases/tag/v0.0.3) | ARM cross-compiler / SDK v0.0.3; separate build download. |
| [Eclipse Temurin 8u504 ARM JRE](https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u504-b01) | Java runtime for the randomizer; GPLv2 with Classpath exception and included notices. Downloaded separately. |
| [Onion OS](https://github.com/OnionUI/Onion) | App integration, device libraries, audio preload and core. Tested on v4.4.0-beta-20260120-07505ea5. |
| [BizHawk](https://github.com/TASEmulators/BizHawk) · [Lua API](https://tasvideos.org/Bizhawk/LuaFunctions) | Reference for the explicitly adapted Tracker emulator API. This frontend is a separate program. |
| [DejaVu Fonts 2.37](https://github.com/dejavu-fonts/dejavu-fonts/releases/tag/version_2_37) · [Download checksums](https://dejavu-fonts.github.io/Download.html) · [License](https://dejavu-fonts.github.io/License.html) | Freely redistributable DejaVu Sans for native labels. Font and notices downloaded together. |
| [CPython 3.11.15](https://github.com/python/cpython/tree/v3.11.15) · [Tkinter](https://docs.python.org/3.11/library/tkinter.html) | Standard-library guided installer, downloads, archive handling and host tests. Windows EXE embeds CPython/Tcl/Tk. |
| [PyInstaller 6.22.0](https://github.com/pyinstaller/pyinstaller/tree/v6.22.0) · [Packaging documentation](https://pyinstaller.org/en/stable/usage.html) · [License exception](https://pyinstaller.org/en/stable/license.html) | Windows EXE packaging; unmodified upstream tool. |
| [Python Build Standalone 20260510](https://github.com/astral-sh/python-build-standalone/tree/20260510) | Host CPython distribution used for the Windows build. [Runtime notices and component sources](docs/installer-licenses/README.md) retained in the release. |
| [OpenSSL 3.5.6](https://github.com/openssl/openssl/tree/openssl-3.5.6) · [Tcl](https://github.com/tcltk/tcl) · [Tk](https://github.com/tcltk/tk) · [zlib](https://github.com/madler/zlib) · [XZ / liblzma](https://github.com/tukaani-project/xz) · [libffi](https://github.com/libffi/libffi) | Libraries shipped with the Windows Python runtime. Included license notices cover the actual packaged components. |
| [GitHub checkout 7.0.1](https://github.com/actions/checkout/tree/v7.0.1) · [setup-python 7.0.0](https://github.com/actions/setup-python/tree/v7.0.0) | Commit-pinned Actions for the Windows/Linux host test workflow. |

## Tracker panels and emulator compatibility

The rearranged panels retain the original rendering and handlers from
[TrackerScreen.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/screens/TrackerScreen.lua),
[Input.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Input.lua),
[Battle.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Battle.lua),
[Theme.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Theme.lua)
and [ExternalUI.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/ExternalUI.lua).

Additional feasibility research: [mGBA](https://mgba.io/),
[RetroArch Lua PR](https://github.com/libretro/RetroArch/pull/18789),
[Lua scripting guide](https://github.com/eadmaster/RetroArch/wiki/Lua-Scripting-Guide),
[Kaizo IronRed](https://github.com/U-K-L/Pokemon-Kaizo-IronRed),
[Faster FireRed Super Kaizo](https://github.com/DrMaple/Faster-FireRed-Super-Kaizo).
The implemented ruleset remains Standard.
[pokeldn FRLG notes](https://github.com/Decryptu/pokeldn/blob/main/docs/frlg_rom.md)
were consulted for the overworld callback. The actual English Rev 1 address was
independently observed on gpSP and compared with pret's overworld.c and the local ROM.

## Data integrity and story exceptions

FireRed references below use pret commit `037335f4c725d7c9aecdac87066f2002b4bd7e14`.
Memory addresses come from the Tracker's
[FireRed v1.1 address file](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/GameAddresses/Pokemon%20FireRed%20v1.1.json).

- **Old Man demo:** BATTLE_TYPE_OLD_MAN_TUTORIAL in [battle.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/battle.h), StartOldManTutorialBattle in [battle_setup.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_setup.c), special capture handling in [battle_script_commands.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_script_commands.c). The isolated device replay uses VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN from [vars.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/vars.h) and real inputs for the [Viridian City script](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps/ViridianCity/scripts.inc).
- **Mandatory Tower ghost:** StartMarowakBattle / CB2_EndMarowakBattle in battle_setup.c and the [Tower 6F script](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps/PokemonTower_6F/scripts.inc). Only GHOST **and** GHOST_UNVEILED together exempt a story KO; the latter alone is also the legendary bit. Actual failed-checkpoint flags were 0xa004 with a won outcome. The isolated resume test checks natural scene variable 0x4059, unchanged encounters and return to the overworld. Tests also cover normal encounters and actual deaths.
- **Encrypted Pokémon edits:** DecryptBoxMon, EncryptBoxMon, CalculateBoxMonChecksum, GetBoxMonData3 and SetBoxMonData in [pokemon.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/pokemon.c), plus the structures in pokemon.h. All 24 substructure permutations are compared with [Tracker MiscData.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/data/MiscData.lua). An archived device snapshot showed a temporarily decrypted teammate and an inconsistent party count. Tests model both; a real gpSP battle checks fainting, switching, winning and graveyard transfer.

QA ROMs and saves remain local and are never distributed.

## Input and dependency checksums

- User's unmodified FireRed USA Rev 1, SHA-1: `dd5945db9b930750cb39d00c84da8571feebf417`.
- User's GBA BIOS, SHA-1: `300c20df6731a33952ded8c436f7f186d25d3492`.
- Faster FireRed 1.3.2 IPS, SHA-256: `44bd14d40c255527110cb8c16281ef84cac1f42ef3fd6ceab1d9215a075d1218`.
- Prepared base with RED/BLUE, intro skip and shop filtering, SHA-256: `3ab878d6918d062533df1e5e3771ea7e010c5ef214574dff270b564995e90f29`.

All exact download URLs and SHA-256 hashes are in [dependencies.json](dependencies.json).
Release asset hashes are supplied as SHA256SUMS.txt alongside the installer.
