# Real yard candidates: historical inputs and current-source replay

Source baseline: `d025b6d5`. **Actual Godot helper replay passed 14/0**, native exit 0, with no diagnostics or guard stop. This establishes three source-derived IDs/variants and two unchanged-carver geometry replays on recovered historical generated lots. It does not regenerate the district, recover a complete care spec, select an accepted live target or establish native Game fit. The yard trial remains off.

The [closed feasibility investigation](evidence/2026-11-04-real-yard-candidates/reports/real-household-feasibility.md), [closed actual verification report](evidence/2026-11-04-real-yard-candidates/reports/real-candidate-verify-fix1-report.md) and [closed independent review](evidence/2026-11-04-real-yard-candidates/reports/real-candidate-review.md) are preserved without rewriting their historical status. Review found no actionable issue within the bounded helper-replay scope. No engine, source/tool edit, staging or commit was performed while preparing this archive.

## Recovered, derived and unknown

**Recovered historical observations:** the [original part08 sample](evidence/2026-11-04-real-yard-candidates/fix1/source-payloads/00-json), [raw source/run binding](evidence/2026-11-04-real-yard-candidates/fix1/source-payloads/01-json) and [original compressed run receipt](evidence/2026-11-04-real-yard-candidates/fix1/source-payloads/02-gz) bind actual generated headless test records at historical Git `b298202447a5b3a0cf2b0e8c55c46bf507a7f1c9`. They record `canal_services`, segment 7, attempt seed `16102028`, plan seed **1208827904**, generation attempt 1, chunk **(-8,-4)**, role `dangerous_alley`. The selected buildings are original rectangular noncivic `row_house` records, not hand-authored parcels or saved ground-care specs. The [observed-input JSON](evidence/2026-11-04-real-yard-candidates/fix1/fixture/observed-inputs.json) preserves the selected sample and all three chosen records.

**Actually derived by GDScript now:** the verbatim extracted `_mix_seed` method and unchanged actual `RectFacilityCarver`/`DonjonCarver` ran against those historical inputs. The ID expression uses **plan seed**, global interior top-left `coord*32 + rect.grow(-1).position`, salt 77 and the positive 31-bit result; it is not a new observation of a generated district. Literal host expectations are separate from the executed signed64 results.

| Historical rect, local cells | Saved door x,y,dx,dy | GDScript-derived ID / variant | Actual replayed carve |
| --- | --- | --- | --- |
| `(21,7,8,7)` | `(25,13,0,1)` | **1910440753 / 1** | 24 perimeter wall cells; open doors `(25,13),(26,13)`; no partitions |
| `(3,6,8,8)` | `(7,13,0,1)` | **2052381668 / 0** | 26 perimeter wall cells; open doors `(7,13),(8,13)`; no partitions |
| `(21,20,8,8)` | `(25,20,0,-1)` | **1928485795 / 3** | Not carved; variant 3 fails the ID-only care condition |

The first two pass only the **ID-based** eligibility condition, not complete care eligibility. The 14 assertions comprise **six ID/variant checks and eight geometry checks** across the two carves: two doors, open door cells, bounded walls and perimeter except doors. Full returned wall/window/stamp/half-cover arrays, signed seeds/final RNG states and parameters remain in the [actual derived-results JSON](evidence/2026-11-04-real-yard-candidates/fix1/fixture/derived-results.json). Duplicate half-cover entries are retained.

Door width **2 is derived from source defaults, not recorded by the historical recorder**. The [input derivation](evidence/2026-11-04-real-yard-candidates/fix1/input-derivation.json) and [exact historical manager snapshot](evidence/2026-11-04-real-yard-candidates/failed-original/historical-manager.gd.txt) support width/window and other normal row-house parameters. Arithmetic footprint coordinates are **before roof inset**, not the final roof/kit footprint or an actual final care spec. Their exact values are recorded in the derived JSON.

**Still unknown/current-runtime pending:** garden contact, party edges/extra reach, actual current care and semantic bytes, final roof/kit geometry, neighbouring context, physical doorway clearance, traversal, reload, native appearance and cost. The familiar camera `(-1632,1304)` at seed `16102028` shows a **passage**, not an eligible household; its `building_id:0` cannot supply a target. The feasibility report documents this distinction and the incomplete actual-kit dependency inventory. It establishes no fit qualification for that larger visual closure. A possible one-house fixture plan is separate and supplies no new engine proof here.

## Actual run and separate failures

| Revision/attempt | Raw outcome |
| --- | --- |
| Original worker startup | [Refused before launch](evidence/2026-11-04-real-yard-candidates/failed-original/first-run-result.json): 402 MB RAM / 3866 MB commit below the 512/1536 startup gate; no engine stdout/stderr exists for that refusal |
| Original parent attempt | [Receipt](evidence/2026-11-04-real-yard-candidates/failed-original/parent-recovery-run-result.json), [stdout](evidence/2026-11-04-real-yard-candidates/failed-original/parent-recovery-stdout.log), [stderr](evidence/2026-11-04-real-yard-candidates/failed-original/parent-recovery-stderr.log): mixed-indentation parse failure, native exit 1; **zero IDs/geometry verified** |
| Fix1 worker startup | [Refused before launch](evidence/2026-11-04-real-yard-candidates/fix1/first-run-result.json): 470 MB RAM / 3954 MB commit; no engine logs or derived results from that attempt |
| Fix1 parent recovery | [Receipt](evidence/2026-11-04-real-yard-candidates/fix1/parent-recovery-run-result.json), [stdout](evidence/2026-11-04-real-yard-candidates/fix1/parent-recovery-stdout.log), [stderr](evidence/2026-11-04-real-yard-candidates/fix1/parent-recovery-stderr.log): **14 passed, 0 failed**, native exit 0; no diagnostics/stop; 0.58 seconds elapsed / 0.359 seconds CPU |

The original [failed harness](evidence/2026-11-04-real-yard-candidates/failed-original/fixture/verify.gd) mixed authored spaces with the tab-indented extracted method. Fix1 changes only authored indentation to tabs; the [successful harness](evidence/2026-11-04-real-yard-candidates/fix1/fixture/verify.gd) retains the [verbatim extracted method](evidence/2026-11-04-real-yard-candidates/fix1/source-payloads/extracted_mix_seed.gd.txt), SHA256 `7a508e56eca823288cba76cec91934acefd931191e0bd72bbb2299dc5448c81f`. Original and fix1 runner revisions/pins are preserved separately. Failure/refusal evidence never counts as a pass.

The successful receipt's `peak_private_mb:0` means **UNSAMPLED**, not zero allocation or a measured peak. The process finished before the guard's private-memory polling sample; an unsampled transient peak cannot be ruled out. Startup recorded 879.57 MB RAM / 3863.30 MB commit. Limits remained **512/1536 MB startup, 64 MB private, 30 seconds; running RAM/commit stops 384/768 MB**. This is an asset-free helper tier, not permission to run Game below its unchanged **1536/3072 MB full-project startup gate**, nor qualification for the actual Kit/native visual closure.

## Exact provenance and preservation

The [24 fix1 source pins](evidence/2026-11-04-real-yard-candidates/fix1/source-pins.json) and all their exact payloads are archived, including historical raw bindings, extracted method, carvers, harness and minimal project. Thirteen historical-launch hashes in the pins match the raw historical receipt; 12 corresponding current source copies match, while ChunkManager differs and is disclosed. [Original pins](evidence/2026-11-04-real-yard-candidates/failed-original/source-pins.json) remain untouched. The [pinned-path index](evidence/2026-11-04-real-yard-candidates/pinned-path-index.json) maps both revisions' 24 entries to exact archived bytes, sharing unchanged original payloads with fix1 rather than duplicating them.

The [fix1 runner snapshot](evidence/2026-11-04-real-yard-candidates/runners/real-candidate-verify-fix1-run.ps1) matches its [self-pin](evidence/2026-11-04-real-yard-candidates/fix1/runner-pin.json) and successful receipt. The [guard](evidence/2026-11-04-real-yard-candidates/fix1/guard.ps1), [engine pin](evidence/2026-11-04-real-yard-candidates/fix1/engine-pin.json), original runner and both preparation scripts are preserved; no executable, profile/cache tree or reservation file is copied. The original verification report is retained with its earlier refusal/planned-check status, superseded by the fix1 actual run. Snapshots retain their historical relative-root assumptions and are documentary; executing them inside the archive is not a fresh reproduction.

Exact successful historical command, from the worktree root:

```powershell
& ./.superpowers/sdd/2026-11-04-trailer-yard-preview/real-candidate-verify-fix1-run.ps1 -EvidenceName parent-recovery
```

The packet received an empty `.gdignore` **first**, excluding archived scripts/project metadata from the main resource scan. Local `* -text -whitespace` preserves historical bytes and scopes whitespace-style exclusions to this evidence. [Copied-file provenance](evidence/2026-11-04-real-yard-candidates/copied-files.json) records original locations, hashes and sizes; [the manifest](evidence/2026-11-04-real-yard-candidates/manifest.tsv) covers every packaged file except itself. No accepted live target, new care spec, complete district regeneration or Game/trailer aesthetic acceptance follows from this archive.
