# Native Miyoo port

This personal port uses the unmodified upstream Ironmon Tracker 9.4.0 release. `bootstrap.lua` adapts emulator APIs and lifecycle behavior. `forms.lua` renders popup controls and a mouse-operated keyboard on the handheld. `ironmon` is an ARMv7 hard-float executable; `ironmon.c` is its source.

The installed directory is `/mnt/SDCARD/App/IronMON`. The source archive only contains this port's program/configuration files, headers and build scripts. It is not a complete standalone installer. Back up the whole installed directory for restoration.

Build requirements:

1. Extract [Miyoo toolchain v0.0.3](https://github.com/shauninman/miyoomini-toolchain-buildroot/releases/download/v0.0.3/miyoomini-toolchain.tar.xz) and [Lua 5.4.8](https://www.lua.org/ftp/lua-5.4.8.tar.gz) into `build/`, preserving their top-level directories. Run the SDK relocation script from its directory.
2. Put the Miyoo device's SDL, SDL_ttf and SDL_image shared libraries and their link dependencies in `device-libs/`, with the linker names `libSDL.so`, `libSDL_ttf.so` and `libSDL_image.so`.
3. Run `python3 build.py` in Linux. The build uses the toolchain sysroot, statically links Lua, and dynamically uses the existing device libraries.
4. Copy `ironmon`, `bootstrap.lua`, `forms.lua`, `rules.lua`, `rule_policy.lua`, `qol.lua`, `tracker_layout.lua`, `prepare.lua`, `launch.sh`, `seed-cache.sh`, `settings.ini`, `standard.rnqs` and `config.json` to the installed app directory. Shell files must have LF line endings and the program and launchers must be executable.

Existing runtime dependencies are deliberately used instead of replacing firmware libraries. The launcher includes Onion's `parasyte` library directory because ARM Java requires its `libatomic.so.1`. Audio uses the existing Onion `libpadsp.so` and converts the core sample stream to 48 kHz.

The physical SDL framebuffer is opened at 32 bits per pixel. Separate RGB565 software surfaces handle compositing, scaling and a final 180-degree rotation for this Mini Plus LCD, then SDL converts the result when presenting. Opening the firmware framebuffer at 16 bits produced diagonal artifacts on the actual LCD despite correct screenshots from framebuffer memory.

Upstream components: [Tracker](https://github.com/besteon/Ironmon-Tracker), [UPR ZX](https://github.com/Ajarmar/universal-pokemon-randomizer-zx), [Temurin ARM Java](https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u504-b01), [libretro API](https://github.com/libretro/libretro-common), [stb](https://github.com/nothings/stb).

The bundled executable embeds Lua. Its license notice is included as `LUA-LICENSE.txt`. Headers retain their original license notices. The gpSP core, SDL libraries, original Tracker, randomizer and Java runtime are separate dependencies and retain their upstream licenses.

Prepare the user's own USA FireRed Rev 1 dump with Python:

```
python3 prepare_rom.py own-firered.gba source-qol.gba --patch Faster.FireRed.1.3.2.ips --download --player RED --rival BLUE
```

This verifies the base SHA-1, obtains the patch from its author, applies speech
skip and filters known shop tables. Keep `source.gba` unchanged. The runtime
uses `source-qol.gba` only for new seeds. Dependencies and sources are listed in
[SOURCES.md](SOURCES.md); license details in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The installed app also needs the original Tracker 9.4.0 in `tracker/`,
UPR ZX 4.6.1 as `PokeRandoZX.jar`, ARM Temurin 8u504 JRE in `runtime/`, and a
locally licensed font as `font.ttf`. The core and BIOS use Onion's normal paths.
These dependencies are deliberately excluded from the repository and source ZIP.

## Tests

Run `python3 -m unittest discover -s tests -p 'test_*.py'` on the host. Build with
`python3 build.py --lua` to obtain `lua-test`. Copy it and `tests/` into a separate
device installation, and run `../lua-test ../tests/rules_integration.lua` from
that installation's `tracker/` directory. This suite substitutes fake memory and
file IO and checks encrypted Pokemon records, all 24 substructure permutations,
dead-item removal, party compaction, resurrection, exact purchase reversal and
Standard route/shiny/capture policy. Never run real emulation QA against user saves.

The rule suite also checks Old Man tutorial entry/exit flag races, field guards
after a persistent tutorial flag, actual capture confirmation and second-KO
enforcement. `tests/tutorial_resume.lua` checks an isolated repaired checkpoint;
`tests/tutorial_demo.lua` resets only that copy's Old Man scene variable and
replays the full game-engine demonstration with actual inputs. Both require
`IRONMON_TUTORIAL_QA=1` and a `data/.qa-allow` marker. Their bootstrap wrappers
must never be used in the live app.

`launch.sh --prepare-cache` creates two distinct randomized ROMs, each with its
own emulated lab state after Mom's event. The launcher verifies the ROM hash
before loading a prepared state. Preparation uses SDL dummy drivers and real
controller inputs; the display's hardware presentation path is preserved.

The layout reuses the original 9.4.0 framebuffer panels and their original click
handlers. `panel_layout.h` maps the physical cursor back into those logical areas;
later overlays take priority. `tracker_layout.lua` splits/repositions the panels
with uniform scaling, and uses complete panels for detail pages, forms and overlays.
The default game size is 512x342, with a separate exact 2x 480x320 mode.

`python3 build.py --tests` builds `build/panel-test` for ARM. Run it on the isolated
device installation to verify mapping boundaries, stat buttons and popup priority.
`tests/layout_geometry.lua` checks LCD bounds, aspect ratios and retained controls
for both layouts. The optional `tests/tracker_ui.lua` test requires an active battle,
`IRONMON_UI_QA=1`, and a `data/.qa-allow` marker in the isolated app directory.
It intentionally modifies test notes and checks actual cursor clicks, L/R marks,
Start switching, dropdown paging, guessed ability saving, keyboard input, move
details and B navigation. Never create its marker in the user's live installation.
