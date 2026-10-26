# Screenshot provenance

## Interface fixtures

These 640×480 frames were captured from the English release frontend running on
a Miyoo Mini Plus with Onion's real gpSP core. `tests/screenshots.lua` selects
views in an isolated battle fixture and enters a sample player note and suspected
ability through the original Tracker API. It does not reveal hidden enemy stats.
`preparing.png` is the native first-seed status screen.

The frontend saves its logical display surface as BMP; the files here are PNG
conversions of those frames. They are actual rendered output, without painted
UI elements, composited mockups or AI-generated artwork. The user's live app and
run are separate from this fixture. ROMs, BIOS and fixture saves are not included.

## Completed Run 31

`run31-credits.png` is actual ending-credits output from the owner's completed
main-story checkpoint, captured on 26 October 2026. A copy of the checkpoint was
resumed with the English release frontend and the real gpSP core in the separate
QA app on the Miyoo. The game ran normally for 80 frames, then paused for capture;
the completion flag, party and save records were not modified. The live German
app and its run files were untouched. The frontend's BMP was converted to PNG
without cropping, annotation or compositing.

The checkpoint was saved on 10 October 2026. Its completion records, full team,
development-run repairs and testing limits are documented in
[the validation record](../VALIDATION.md). This image is distinct from the
isolated battle fixtures described above.
