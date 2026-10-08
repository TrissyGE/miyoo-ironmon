# Use of AI

This project was **substantially developed with OpenAI Codex**. This is a direct
disclosure, not a claim that AI was used only for autocomplete or occasional advice.

## What AI contributed

Codex wrote and iterated on much of the custom C frontend, Lua emulator-API adapter,
handheld UI/layout code, Standard rule guards, ROM-preparation tooling, installer,
automated tests and English documentation. It also helped investigate bugs using
upstream source, logs, memory snapshots and isolated real-core runs on the Miyoo.

Release screenshots are actual emulator output from an isolated device installation,
not AI-generated artwork or mockups.

## What the human owner contributed

The owner chose goals and priorities, authorized changes, played on the physical
Miyoo, reported display/control/rule bugs, evaluated the experience and requested
this public release. Those real-world reports guided several fixes.

This was a human-directed process with substantial AI authorship. It should not
be described as entirely hand-written or independently audited.

## What belongs to other projects

Ironmon Tracker, gpSP, Universal Pokémon Randomizer ZX, Faster FireRed, Onion,
Lua, SDL, Temurin and other upstream components were built by their respective
authors. Their work is not represented as this project's or Codex's creation.
References and licenses are in [SOURCES.md](SOURCES.md) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Validation and limits

Validation combines automated host tests, simulated-memory rule tests, actual
gpSP/device integration tests and the owner's play sessions. It has covered
layouts and Tracker interactions, ROM preparation, catch/tutorial guards,
encrypted party-record integrity, fainting with a surviving teammate, switching,
winning and graveyard transfers. Release work also tests SD-card setup, updates,
backup/rollback behavior and dependency checks.

A full story playthrough and every script/rule edge case have **not** been
regression-tested. Automated checks were also largely written with AI assistance;
passing them is evidence about those scenarios, not an independent guarantee
that the code is correct. This is an early community release. Bug reports and
human review are welcome, especially around save integrity and rule enforcement.
