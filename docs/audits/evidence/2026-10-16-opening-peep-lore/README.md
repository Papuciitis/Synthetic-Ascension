# Opening, PeeP and optional city papers — evidence

Godot 4.7.1 (`a13da4feb`) ran these checks serially in the shared worktree. New UI fixtures use isolated/no human profiles. Logs preserve expected RED assertions separately from final GREEN results; expected failures are not successful tests. JSON records preserve individual process exits. A missing summary is never treated as a passing suite.

| Final focused suite | Passed / failed | Exit |
|---|---:|---:|
| OpeningIllustrationTest | 22 / 0 | 0 |
| PeePContinuationUiTest | 47 / 0 | 0 |
| CityLoreDiscoveryTest | 108 / 0 | 0 |
| HubWorldTest | 54 / 0 | 0 |
| StoryDirectorTest | 166 / 0 | 0 |
| HubLibraryDataTest | 1885 / 0 | 0 |
| HubLibraryTest | 230 / 0 | 0 |
| PeeP quit submode | 7 / 0 | 0 |
| ReliquaryCoreTest, corrected optional-record expectation | 87 / 0 | 0 |

Earlier related opening suites are recorded in `results.json`: Typewriter17, Guidance21, Segment1Progression40, PhysicsSafety5, StoryDirector166, SaveMigration34 and PauseMenu38, all with zero failures and exit0. SaveMigration deliberately emits one newer-version best-effort warning; other listed final focused runs had no script/runtime diagnostics.

The closing Reliquary integration run exposed one stale expectation: 42 mechanical entries plus only the19 original story records. Its actual69 entries correctly include the8 optional papers. The observed RED was86/1, exit1; the fixture now counts both authored record sources, leaving production unchanged. The coordinated rerun passed87/0, exit0; both logs are preserved here.

The three actual UI preview scenes completed with exit0: Opening9 PNGs/0 failures, PeeP10 PNGs/no errors, Papers11 PNGs/0 failures/zero profile writes. All30 images were visually inspected, including 640×480 and Reduced Motion. Their respective `docs/art/reference/2026-10-16-*` directories preserve the pixels and capture notes. Static evidence does not establish human pacing, live motion quality or final sound.

The final shared headless import completed with exit0 in 89.7 seconds and no errors or warnings. `closing-import-SharedImport.log` and `closing-import-results.json` preserve the result. It imports the new scripts/assets and supplies their UID/import sidecars; it changes no gameplay source.

Reproduce a scene suite with `Godot --headless --path <project> res://tools/tests/<Suite>.tscn --quit-after 3000`. The three script-based opening suites use `--script res://tools/tests/<Suite>.gd` instead. PeeP's actual quit fixture adds `-- --peep-quit-check`. Render previews through `res://tools/dev/OpeningIllustrationPreview.tscn`, `PeePContinuationPreview.tscn` and `CityLorePapersPreview.tscn`, using `--rendering-method gl_compatibility` and an actual rendering driver rather than headless mode.

One shared final `ScriptParseAuditTest` passed **530/0**, exit0, across all eight gameplay roots; `AscensionRuntimeSafetyTest` passed **21/0**, exit0. Both logs and structured results are preserved in `docs/audits/evidence/2026-10-16-city-development/`. Its `gameplay-source-hashes.json` records all530 scripts unchanged before/after the audit. This directory's `verified-source-hashes.json` records the eleven narrative production sources; each was compared successfully with both the current file and the shared manifest after all corrections. The shared audit was reused to avoid duplicate broad runs. These eleven narrative sources remained unchanged after the audit. Later work in other delivery slices must establish its own source identity and verification.

The reviewed document prose remains exact. Comparing `CityLoreDocuments.gd` with hint metadata lines removed and remaining lines joined with LF produced SHA256 `6064EA070238219EDCE4256EF7583DAFE8E59A46829AD823AAF3B06F9B2ACB16` before and after the guidance correction. Only the discovery guidance changed to identify the implemented Papers tray; five physical field placements remain deferred as recorded in the city-lore audit.
