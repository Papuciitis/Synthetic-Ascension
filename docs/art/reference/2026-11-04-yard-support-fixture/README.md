# Yard support: isolated real-material fixture, 4 November 2026

This packet preserves an **identical-coordinate 512×512 REAL MATERIAL FIXTURE**, using the original fourteen-layer ground material and imported city mipmaps. It is a controlled synthetic layout at chunk `(-2,3)`, seed `944996572`, not the actual generated Game S7 layout. It establishes neither normal/small Game appearance, doorway traversal, streamed reload, production cost nor trailer aesthetic acceptance. Default preview activation remains off.

The qualified prototype source is committed at `6de56bed`, with original comparison source at `d7cfb52f`. The copied [closed worker report](task-2b-report.md) and [closed scoped review](task-2b-review.md) record SPEC PASS / QUALITY PASS for the bounded implementation and fixture scope. The [closed whole-branch review](final-branch-review.md) covers `d7cfb52f..6de56bed` with no new blocker; two deferred P3 data-launcher resilience issues (missing-log receipt and receipt-write cleanup) and unpassed Game gates remain. The reports are historical snapshots: their scratch paths and earlier pending/refusal records are not rewritten into later successes. Packet preservation bytes are outside that source-review range and separately verified below.

## Final observed results

| Run | Actual outcome | Raw records |
| --- | --- | --- |
| Renderer state/data | **75 passed / 0 failed**, native exit 0, no diagnostics/stop | [stdout](final-data/renderer-stdout.log), [stderr](final-data/renderer-stderr.log), [receipt](final-data/renderer-result.json) |
| Yard support helper | **82/0**, native exit 0, no diagnostics/stop | [stdout](final-data/support-stdout.log), [stderr](final-data/support-stderr.log), [receipt](final-data/support-result.json) |
| Wrapped mask owner | **69/0**, native exit 0, no diagnostics/stop | [stdout](final-data/map-stdout.log), [stderr](final-data/map-stderr.log), [receipt](final-data/map-result.json) |
| Retained ground data subset | **60/0**, native exit 0, no diagnostics/stop | [stdout](final-data/subset-stdout.log), [stderr](final-data/subset-stderr.log), [receipt](final-data/subset-result.json) |
| Native material fixture | **46/0**, native exit 0, no diagnostics/stop | [stdout](native-final/native-stdout.log), [stderr](native-final/native-stderr.log), [receipt](native-final/native-result.json), [pixel measurements](native-final/native-pixels.json) |

These are separate suites, not one combined assertion count. The retained subset executes 13 old data cases, omits exactly three manager integration assertions, and adds a cleanup frame between cases. It proves neither the complete original suite nor its original scheduling/performance.

Final pixels: **3299 positive-yard pixels changed**. Default-off, enabled-empty, disable, reset, zero-mask, alpha, later-care, later-floor and each road/lane/footway/courtyard/indoor/care control comparison changed **0** pixels. The planner produced **10 potential cells above 60**, used **6 unique control cells**, and retained **4 uncontrolled positive cells**. These nonvacuity checks and the actual selected controls are in the pixel JSON and native stdout.

All twelve final saved PNGs below are original bytes, without resizing, cropping or recompression:

| Purpose | Final originals |
| --- | --- |
| Matched base and preview | [original-before](native-final/originals/original-before.png), [preview-after](native-final/originals/preview-after.png) |
| Mask inspection | [mask-debug3](native-final/originals/mask-debug3.png) |
| Default-off / enabled-empty | [default-off](native-final/originals/default-off.png), [enabled-empty](native-final/originals/enabled-empty.png) |
| Disable / reset | [disabled-restored](native-final/originals/disabled-restored.png), [enabled-reset](native-final/originals/enabled-reset.png), [original-reset](native-final/originals/original-reset.png) |
| Later actual care | [original-late-care](native-final/originals/original-late-care.png), [preview-late-care](native-final/originals/preview-late-care.png) |
| Later replacement floor | [original-late-floor](native-final/originals/original-late-floor.png), [preview-late-floor](native-final/originals/preview-late-floor.png) |

## Provenance and reproduction

[Native source pins](native-final/source-pins.json), [data source pins](final-data/source-pins.json), native/data fixture configuration and generated shaders are preserved. [The snapshot index](source-snapshot-index.json) maps both sets of original pins to deduplicated exact source/test/stub/launcher snapshots. Matching bytes share a packaged snapshot; the data-only asset-loader stubs are separately retained and are not art evidence. Baseline renderer transformations are explicit: remove its sole `class_name`, redirect its sole shader preload to the unchanged original shader. The current renderer, original shader and generated preview shader remain distinct records.

Only the `WorldArt` and `CityBlockKit` asset-loading leaves are doubled. The native leaves bind real original materials; data leaves use tiny test colors. Original asset/cache paths and hashes remain in the untouched pins, but texture binaries, executable, complete fixture trees, profiles and caches are deliberately absent. The builder snapshot defines the minimal class metadata; it is not a whole-project import. This packet is an evidence archive, not a standalone runnable replacement for the repository and original assets.

The actual [four-suite orchestration](final-data/run-final-data-parent.ps1) is copied exactly; its SHA256 matches [parent-sequence pins](final-data/parent-sequence-pins.json). [Parent sequence results](final-data/parent-sequence-result.json) and all outer stdout/stderr are also retained. The wrapper preloaded the pinned guard, recovered current-chat resident pages once, and ran four engines strictly sequentially; no applications were closed or operating-system working-set limits changed. The wrapper is preserved for provenance, not executed during packaging.

Historical outer data command, from the worktree root:

```powershell
& ./.superpowers/sdd/2026-11-04-trailer-yard-preview/run-final-data-parent.ps1
```

Fixture build/run recipe (requires a fresh output directory and the original repository/assets; exact engine arguments and launcher hash are in the native receipt):

```powershell
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out output/yard-support-fixture-new --native
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory output/yard-support-fixture-new -Suite native
```

The guarded launcher validates its executing bytes against the pinned snapshot, retains native exits/unfiltered diagnostics, checks one-engine exclusion and isolates app data. Data startup RAM/commit is 512/1536 MB with 64 MB private / 30-second sampled limits. Native startup is 704/1536 MB with 256 MB private / 120 seconds. Both retain running free RAM/commit stops of 384/768 MB. These are sampled safeguards, not hard peak-memory or elapsed-time guarantees. Parent separately observed current Python source/build contracts **5/5 in 10.865 seconds**; no raw log was saved for that observation and none is invented here.

## Failures and remaining gates

The explicitly [failed native-parent2 receipt](failed-native-parent2/native-result.json), [stdout](failed-native-parent2/native-stdout.log), [stderr](failed-native-parent2/native-stderr.log), [pixel JSON](failed-native-parent2/native-pixels.json), original source pins and three failed-run PNGs remain in their own folder. That run was **43/1**, exit 1, with two viewport setup diagnostics. Its useful pixel counts do not make it a clean pass. The final test registered viewports before assigning canvas transforms and replaced an arbitrary planner-count threshold with six unique controls plus remaining positive support; production source did not change for those fixture fixes. The failed test source is retained for comparison. Failed images never replace the final originals.

The [whole-project parse receipt](project-parse-refused/result.json) records **not launched**: the 1536 MB RAM / 3072 MB commit startup gate refused **324 MB RAM / 2126 MB commit**. Its earlier metadata read was 328/2125 MB; both readings are historical samples. The exact executed wrapper, guard and selected source pins are retained beside it. This is a refusal, not whole-project parse success. Earlier compact startup refusals also remain in `startup-refusals/`.

Actual Game S7 matched 1280×720 / 960×540 views, a real doorway/passage traversal, streamed reload, full-project parse and production cost remain unpassed gates. No engine, compiler or executor was launched while preserving this packet.

## Byte preservation

An empty root `.gdignore` was created **before** any payload, excluding copied scripts and nested project metadata from the main Game resource scan. It does not change the originals or claim another engine run. Local `.gitattributes` uses `* -text -whitespace` to retain historical Windows bytes and exclude only this evidence packet from whitespace style checks; production checks are unchanged.

[Copied-file provenance](copied-files.json) records original paths, SHA256 and sizes. [The manifest](manifest.tsv) covers every packaged file except itself. Absolute paths in raw receipts/pins are preserved historical facts. The [earlier data verification audit](../../../audits/2026-11-04-trailer-yard-data-verification.md) preserves helper/access-mutant/absent-owner and launcher-control evidence separately.
