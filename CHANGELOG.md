# Changelog

## 0.1.2 - 2026-10-09

- Fix destructive bag comparisons during menu/save encryption transitions, reported after opening the Safari Zone menu.
- Validate every occupied and empty bag slot, money and coins before applying guards; retain the last complete observation through partial frames.
- Reset spending evidence when a save-block pointer or encryption key changes, so pre-owned items cannot become new purchases across that boundary.
- Add regression coverage for owned items, key items, TMs, berries, partial slot writes and exact purchase reversal, plus an isolated real-core Safari menu test.

## 0.1.1 - 2026-10-08

- Correct the encoding of punctuation, arrows and accented text in the English README and changelog.
- Repackage the guided installers with the corrected documentation; app behavior is unchanged.

## 0.1.0 — 2026-10-08

First public release after private development and real Miyoo playtesting.

- Native ARM frontend for FireRed Standard IronMON, Onion gpSP and original Tracker 9.4.0.
- Original panels beside/below the game, four layouts, cursor controls, stat markings, own/enemy switching, suspected abilities and notes.
- On-device randomization, Faster FireRed 1.3.2, intro skip, protected resets and two reserve lab checkpoints.
- Standard route, catch, item, shop, death and team-wipe guards; autosave, history and backups.
- Old Man catching-demo and mandatory Tower ghost exceptions and party-integrity guards, including safe transfers after a faint with a living teammate.
- Fully English release, actual device screenshots, source credits and explicit AI-use disclosure.
- Guided Windows SD-card installer and Python alternative, with pinned downloads and update backups.

Tested: Miyoo Mini Plus / Onion v4.4.0-beta-20260120-07505ea5; Windows installer host.
See [AI_USAGE.md](AI_USAGE.md) and [BUILD.md](BUILD.md) for validation scope.
Not every story event has been tested.
