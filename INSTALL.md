# Install Miyoo IronMON

## What you need

- A Miyoo Mini Plus with Onion OS and gpSP. Tested with **v4.4.0-beta-20260120-07505ea5**. Other versions/devices are unverified; setup checks required paths, including Onion's `parasyte/libatomic.so.1` used by ARM Java.
- A computer, SD-card reader, about **54 MiB of downloads**, and at least **350 MiB free** on the card. Updates also need enough space to copy the existing app.
- Your own **unmodified FireRed USA Rev 1 / v1.1** dump, `.gba` or `.zip`. Required SHA-1: `dd5945db9b930750cb39d00c84da8571feebf417`. Other revisions, translations and patched/randomized ROMs are rejected.
- Your own **GBA BIOS**, 16 KiB, SHA-1 `300c20df6731a33952ded8c436f7f186d25d3492`. If `BIOS/gba_bios.bin` already contains it, leave the BIOS selector blank.

## Windows: guided installation

1. Download **IronMON-Setup-Windows.zip** from the [latest release](https://github.com/TrissyGE/miyoo-ironmon/releases/latest). Extract it and open **IronMON-Setup.exe**. No administrator access or additional runtime is needed.
2. Shut down the Miyoo, remove its SD card and connect it to your computer.
3. Select the **SD card root**, for example `E:\`, where `App`, `BIOS` and `RetroArch` live. Select your ROM and, if necessary, BIOS.
4. Click **Install IronMON**. Keep the card connected until setup reports success. Downloads are checked against pinned SHA-256 hashes; your ROM is patched locally. Game files are never uploaded.
5. Safely eject the card, put it back in the Miyoo and launch **Apps → IronMON**. Return to Onion's main menu first if the app list needs refreshing.

First launch shows a preparation screen while Java randomizes a seed and the
emulator creates a matching lab checkpoint. Allow roughly **1–2 minutes**, keep
the device powered on, and watch for Oak's lab. Two reserve seeds then prepare
in the background. Prepared resets are quick; consecutive resets can exhaust
the cache and require another wait.

Windows executables are unsigned. If your security software prevents running
the EXE, use the Python package below or inspect/build the source. This guide
does not require changing security settings.

## Updates and backups

Exit with **MENU**, then shut down before removing the card. Run the new installer
with the same SD card, your original ROM and BIOS.

Setup preserves `data/`, `settings.ini` and existing Tracker user files. It builds
a separate staging directory, keeps the previous complete app under
`IronMON-backups/IronMON-<timestamp>-<id>/` on the SD card, then replaces the app.
It does not patch the current randomized run. A failed final directory swap
restores the previous app.

To restore, shut down and connect the card, move the current `App/IronMON` folder
to a safe location, then copy the chosen backup to `App/IronMON`. Remove old
backups yourself when no longer needed. Do not restore completed runs to continue
an IronMON challenge.

## Mixtape / install on the handheld

In [Mixtape](https://github.com/snyderman3000/mixtape), add this catalog URL to
the `sources` array in `App/Mixtape/data/config.json` and restart Mixtape:

```text
https://raw.githubusercontent.com/TrissyGE/miyoo-ironmon/main/mixtape.json
```

Keep the existing settings and catalog entries in that file. Then find
**Miyoo IronMON** in Mixtape's Apps tab and install it. You can also download
**IronMON-vX.Y.Z-OnionOS.zip** from [Releases](https://github.com/TrissyGE/miyoo-ironmon/releases/latest)
and extract it at the SD-card root.

1. Put your unmodified FireRed USA Rev 1 `.gba` at `App/IronMON-Mixtape/source.gba`.
2. Put your GBA BIOS at `BIOS/gba_bios.bin` if it is not already there. Both files
   must match the hashes in [What you need](#what-you-need).
3. Turn on Wi-Fi and open **Apps → IronMON (Mixtape)**. The first launch verifies
   about 52 MiB of dependency downloads and prepares the ROM on the handheld.
   Keep it powered on through setup and the first seed. After that, play and
   reset offline.

This edition uses `App/IronMON-Mixtape/` and can coexist with a PC-installed
`App/IronMON/`. Store updates preserve your ROM, run, notes and settings.
Mixtape's Erase removes packaged files; the player files and first-run downloads
stay in the app folder. Copy them somewhere safe if you want to free that space.
Setup errors appear on the handheld, with details in `data/store-setup.log`
inside the Mixtape app folder.

The tested device and Onion version are the same as above. The store edition
also needs Onion's `curl` and `unzip` for its first setup.

## Python / Linux / macOS

Download **IronMON-Setup-Python.zip**, extract it and use Python **3.11 or newer**:

```sh
python install.py
```

This opens the same UI if Tkinter is available. Linux often provides Tkinter as
`python3-tk`. A terminal-only installation is available:

```sh
python install.py --sd /media/you/ONION --rom /path/to/your-firered.gba --bios /path/to/your-gba-bios.bin
```

Omit `--bios` to use the BIOS on the card. No third-party Python modules are needed.
`--cache /path/to/downloads` and `--offline` support a previously populated,
verified cache. The Python release includes the prebuilt ARM payload; a source
checkout requires building it with `build_release.py` first. Windows is the tested
host; other hosts use the same portable code but are not tested end to end.

## Troubleshooting

| Message / symptom | What to check |
| --- | --- |
| SD card not recognized | Choose the root, not `App`. Check gpSP, `.tmp_update/bin/infoPanel` and `.tmp_update/lib/parasyte/libatomic.so.1`. The tested Onion version includes these. |
| Wrong ROM version | Use the exact unmodified USA Rev 1 dump above. ZIP selection searches for the matching `.gba`. |
| Missing / incompatible BIOS | Use the BIOS above or select your own file. Setup will not overwrite a different existing BIOS. |
| Download / checksum failure | Retry online. A corrupt cache file is downloaded again. SD staging begins only after all downloads pass. |
| Long preparation | Check `data/cache-worker.log` and `data/cache/randomizer.log` under `App/IronMON`. Initial generation takes longer than cached resets. |
| App stops | Check `data/frontend.log`. Include the error, location/action and versions in a report. |
| Technical data pause | Persistently invalid party data caused a pause without a run loss. Save/exit or use L2; report the preceding action. |

See [controls](README.md#controls), [sources](SOURCES.md),
[licensing](THIRD_PARTY_NOTICES.md) and [AI disclosure](AI_USAGE.md).
