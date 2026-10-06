# Quellen und verwendete Versionen

Stand der Entwicklung: 6. Oktober 2026. Die folgenden Quellen wurden für
Implementierung, Kompatibilität, Regeln und Recherche verwendet.

| Quelle | Verwendung / Version |
| --- | --- |
| [Ironmon-Tracker von besteon](https://github.com/besteon/Ironmon-Tracker) · [9.4.0](https://github.com/besteon/Ironmon-Tracker/releases/tag/v9.4.0) | Originaler Tracker, TrackerAPI, bekannte Speicheradressen und Datenstrukturen. MIT; separat installiert. |
| [Standard-IronMON-Regeln](https://gist.github.com/valiant-code/adb18d248fa0fae7da6b639e2ee8f9c1#standard-ironmon-ruleset) · [ironmon.gg](https://ironmon.gg/) | Route: Fang ODER KO, permanenter Tod samt getragenem Item, Teamverlust, Shops, Starter/Favoriten, Legendäre, Items, Diebstahl, keine Wiederholungen, Shiny- und Verwerf-Ausnahme, Mom. |
| [Standard-Einstellungen von UTDZac](https://gist.github.com/UTDZac/a147c497424dfbd537d8c4b0c22b5621) | Grundlage von `standard.rnqs`; die alte Versionskennung wird von UPR ZX beim Einlesen aktualisiert. |
| [Universal Pokémon Randomizer ZX](https://github.com/Ajarmar/universal-pokemon-randomizer-zx) · [4.6.1](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/releases/tag/v4.6.1) | On-device Randomizer. [Gen3RomHandler](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/romhandlers/Gen3RomHandler.java), [Gen3Constants](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/constants/Gen3Constants.java), [gen3_offsets.ini](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/v4.6.1/src/com/dabomstew/pkrandom/config/gen3_offsets.ini): Starter-Reihenfolge, Script- und Shop-Adressen. GPL-3.0-or-later. |
| [Faster FireRed von DrMaple](https://github.com/DrMaple/Faster-FireRed) · [1.3.2](https://github.com/DrMaple/Faster-FireRed/releases/tag/1.3.2) | Separat heruntergeladener QoL-Patch: Mom/Labor, verkürzte Paket-Quest, Repel-Nachfrage, Heilung, TM- und Item-Markierungen, Umbenennen, Bodenitems. Patch wird nicht mit diesem Projekt verteilt. |
| [IronMON Patch Editor von DrMaple](https://github.com/DrMaple/IronMONPatchEditor) · [MainWindow.cs](https://github.com/DrMaple/IronMONPatchEditor/blob/457484f8d26c9aaaadb31a2aa7420c14918f4b2c/IronMONPatchEditor/MainWindow.cs) | Angepasste Speech-Skip-Routine und Namen-Encoding in `prepare_rom.py`. Commit `457484f8d26c9aaaadb31a2aa7420c14918f4b2c`; GPL-3.0. |
| [pret/pokefirered](https://github.com/pret/pokefirered/tree/037335f4c725d7c9aecdac87066f2002b4bd7e14) | Primärreferenz zu Gen-3-Strukturen und Spielablauf: [load_save.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/load_save.c), [pokemon.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/pokemon.h), [pokemon_storage_system.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/pokemon_storage_system.h), [global.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/global.h), [global.fieldmap.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/global.fieldmap.h), [flags.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/flags.h), [items.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/items.h), [species.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/species.h), [shop.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/shop.c), [battle_controller_player.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_controller_player.c), [overworld.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/overworld.c), [Lab-Scripts](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps/PalletTown_ProfessorOaksLab/scripts.inc), [Maps](https://github.com/pret/pokefirered/tree/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps). Referenz; keine Spielinhalte im Repository. |
| [gpSP libretro](https://github.com/libretro/gpsp) | Vorhandener Onion-GBA-Core. Nicht im Paket enthalten. |
| [libretro-common](https://github.com/libretro/libretro-common) | `libretro.h`; Lizenz im Header. |
| [SDL 1.2](https://www.libsdl.org/release/SDL-1.2.15/docs.html) · [SDL_ttf](https://github.com/libsdl-org/SDL_ttf) · [SDL_image](https://github.com/libsdl-org/SDL_image) | Vorhandene Gerätebibliotheken für Ausgabe, Text und Bilder. |
| [stb von Sean Barrett](https://github.com/nothings/stb) | GIF-Decoder in `stb_image.h`; Wahl MIT/Public Domain. |
| [Lua 5.4.8](https://www.lua.org/ftp/lua-5.4.8.tar.gz) · [Lizenz](https://www.lua.org/license.html) | Statisch eingebetteter Lua-Interpreter; MIT. |
| [Miyoo-Toolchain von Shaun Inman](https://github.com/shauninman/miyoomini-toolchain-buildroot/releases/tag/v0.0.3) | ARM-Crosscompiler/SDK, v0.0.3. Separater Build-Download. |
| [Eclipse Temurin 8u504 ARM-JRE](https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u504-b01) | Java-Runtime für den Randomizer; GPLv2 mit Classpath-Ausnahme und enthaltenen Drittanbieterhinweisen. Separat installiert. |
| [Onion OS](https://github.com/OnionUI/Onion) | Geräte-App-Integration, vorhandene Bibliotheken, Audio-Preload und Core. Getestet auf v4.4.0-beta-20260120-07505ea5. |
| [BizHawk](https://github.com/TASEmulators/BizHawk) · [Lua API](https://tasvideos.org/Bizhawk/LuaFunctions) | Referenz für die explizit nachgebildete Tracker-API. Dieses Frontend ist ein eigenständiges Programm. |

Weitere Machbarkeitsrecherche: [mGBA](https://mgba.io/),
[RetroArch Lua-PR](https://github.com/libretro/RetroArch/pull/18789),
[Lua-Scripting-Guide](https://github.com/eadmaster/RetroArch/wiki/Lua-Scripting-Guide),
[Kaizo IronRed](https://github.com/U-K-L/Pokemon-Kaizo-IronRed),
[Faster FireRed Super Kaizo](https://github.com/DrMaple/Faster-FireRed-Super-Kaizo).
Das installierte Regelprofil bleibt Standard.
Die neu angeordneten Panels und ihre Interaktionen stammen aus dem separat
installierten Original: [TrackerScreen.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/screens/TrackerScreen.lua),
[Input.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Input.lua),
[Battle.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Battle.lua),
[Theme.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/Theme.lua)
und [ExternalUI.lua](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/ExternalUI.lua).
Zusätzlich recherchiert: [pokeldn FRLG-Notizen](https://github.com/Decryptu/pokeldn/blob/main/docs/frlg_rom.md)
zum Overworld-Callback. Die verwendete englische Rev-1-Adresse wurde unabhängig
auf dem gpSP-Core beobachtet und mit `pret/pokefirered/src/overworld.c` sowie
dem Code des eigenen ROM-Dumps abgeglichen.

Die Ausnahme für Vertanias Fangdemo basiert auf `BATTLE_TYPE_OLD_MAN_TUTORIAL`
in [battle.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/battle.h),
[StartOldManTutorialBattle in battle_setup.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_setup.c)
und der besonderen Fangbehandlung in
[battle_script_commands.c](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/src/battle_script_commands.c).
Die Speicheradresse stammt aus der originalen
[FireRed-v1.1-Adressdatei](https://github.com/besteon/Ironmon-Tracker/blob/v9.4.0/ironmon_tracker/GameAddresses/Pokemon%20FireRed%20v1.1.json).
Der vollständige Gerätetest nutzt ausschließlich in einer isolierten Kopie
`VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN` aus
[vars.h](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/include/constants/vars.h)
und die normalen Eingaben für das originale
[ViridianCity-Script](https://github.com/pret/pokefirered/blob/037335f4c725d7c9aecdac87066f2002b4bd7e14/data/maps/ViridianCity/scripts.inc).

## Prüfsummen

- Benötigte eigene Basis-ROM, SHA-1: `dd5945db9b930750cb39d00c84da8571feebf417`.
- Faster FireRed 1.3.2 IPS, SHA-256: `44bd14d40c255527110cb8c16281ef84cac1f42ef3fd6ceab1d9215a075d1218`.
- Lokale vorbereitete Basis mit RED/BLUE, Speech Skip und Shopfilter, SHA-256:
  `3ab878d6918d062533df1e5e3771ea7e010c5ef214574dff270b564995e90f29`.
