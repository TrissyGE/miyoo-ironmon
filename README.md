# Miyoo IronMON

Eigenständiges ARM-Frontend für **FireRed Standard IronMON auf Miyoo Mini Plus**.
Es verbindet den vorhandenen gpSP-Core mit dem originalen Ironmon-Tracker 9.4.0,
Lua 5.4 und einer expliziten Tracker-API-Anpassung. Spielen, Tracken und
Randomisieren funktionieren auf dem Gerät ohne PC oder Netzwerk.

## Funktionen

- Neue Seeds mit Faster FireRed 1.3.2, übersprungenem Oak-Intro und festen Namen.
- Zwei vorbereitete Seeds: jeder mit eigenem, geprüftem Laborzustand nach Mom.
- Adaptive Anzeige: großes Spiel außerhalb von Kämpfen; im Kampf 480×320 bei
  exakt 2× Skalierung, daneben bekannte Gegnerdaten und darunter Team/Route.
- Originaler Tracker samt Notizen weiterhin verfügbar; native Menüs per D-Pad.
- R2-Tempo wahlweise halten oder umschalten. HP-/Giftwarnung und geschützter Reset.
- Auto-Save/Resume, Run-Verlauf und standardmäßig acht abgeschlossene Run-Backups.
- Permanente Todesliste mit Einlagerung nach dem Kampf und Vernichtung des
  getragenen Items; Zurückholen/Heilen reaktiviert tote Pokémon nicht.
  Transfers warten auf die Spielwelt, damit offene PC-/Team-Menüs gültig bleiben.
- Standard-Game-Over bei Verlust des ganzen Teams. Retry und Time Machine gesperrt.
- Ein Fang ODER Wild-KO pro Ort über alle Etagen/Methoden hinweg; Shiny-KO zusätzlich.
- Neuer Fang kann ungesehen verworfen werden. Scouts dürfen weiterhin Bälle werfen.
- Shops bieten nur Bälle und Repels; Automaten/Barter haben zusätzliche Inventarprüfungen.
- Lucky Egg/Sacred Ash und VS Seeker gesperrt; gehaltene Bans im Labor erlaubt.
- Zufallsstarter wird vor der Wahl ausgelost; Favoriten können konfiguriert werden.
- Trainer-Revanchen und wiederholt eingesammelte versteckte Items werden gesperrt.
- Der optionale Viridian-Freundschaftsbonus des Faster-Patches wird zurückgenommen.

**Regelsperren:** Ein zweiter unerlaubter Wild-KO oder eine unerlaubte Starterwahl
beendet den Run mit Begründung. Das Spiel wird nicht unbemerkt zurückgespult.
Legale Fänge auf bereits verbrauchten Routen werden ungesehen verworfen.
Gegnerdaten zeigen nur das, was der originale Tracker bereits kennt.

## Tasten

| Taste | Funktion |
| --- | --- |
| A / B / D-Pad / Start / Select | Spiel |
| X | Original-Tracker / Cursor; A klickt |
| Y | Automatisch → kompakt → großes Spiel → Originalansicht |
| L2 | Miyoo-Menü; D-Pad wählt, A bestätigt, B schließt |
| R2 | Tempo halten oder umschalten; Einstellung im L2-Menü |
| MENU | Speichern und schließen |
| A+B+Start, zwei Sekunden halten | Neuer Run; erst nach dem ersten Kampf |

Die GBA-Tasten L/R und die bisherigen Tracker-Kürzel bleiben verfügbar.

## Daten und Voraussetzungen

Für den Aufbau: eigener unmodifizierter USA-FireRed-Rev-1-Dump, GBA-BIOS,
Onion/gpSP, Tracker 9.4.0, UPR ZX 4.6.1, Temurin ARM-JRE 8u504, ein lokal
lizenziertes TTF und die Gerätebibliotheken. Dieses Repository enthält keine ROM.
[BUILD.md](BUILD.md) beschreibt den Build; [SOURCES.md](SOURCES.md) verlinkt
alle verwendeten Quellen. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
enthält die Lizenzhinweise.

`data/current.*` ist der laufende Run, `data/current.rules` die unabhängige
Regeldatei. `data/history.tsv` ist der Verlauf, `data/runs/` enthält vergangene
Runs. Die Backups sind zur Datenrettung gedacht. Die Oberfläche bietet im
Standard-Modus keinen Rücksprung in einen abgeschlossenen Run.

`settings.ini`: Namen/Geschlecht für die Basis-Erstellung, interne Gen-3-IDs der
Favoriten, Tempo-Modus und Anzahl der Backups. Namen ändern erfordert eine neue
QoL-Basis und neu vorbereitete Seeds. Eine bereits laufende ROM wird beim Update
nicht gepatcht. Vollständig protokollierte Regeln beginnen mit dem nächsten Seed.

Der Seed-Cache läuft mit niedriger CPU-Priorität. Sind beide Reserven aufgebraucht,
muss der nächste Reset auf die Vorbereitung warten. Ein unerwarteter Stromausfall
kann seit dem letzten Auto-Save Spielzeit kosten; normal mit MENU schließen.

Dies ist ein getesteter erster QoL-Stand. Die normalen Shoplisten sind in der
ROM gefiltert; Sonderkäufe werden zusätzlich über Inventar-/Geldänderungen erkannt.
Nicht jeder Story-Sonderfall ist in einem vollständigen Durchlauf geprüft.
Fehler mit Ort, Aktion und `data/frontend.log` melden. Bei älteren Runs kennt das
neue Routenprotokoll frühere Wild-KOs/Fänge noch nicht.
