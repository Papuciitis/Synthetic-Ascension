# S3 guard-office/loggia prototype

19 October 2026. **Implemented; independent review addressed and coordinating review accepts the bounded first prototype.** Native observations are sampled prototype evidence; final human aesthetic acceptance is not asserted; the coordinating designer keeps this as the first prototype with refinements pending.

## Result and baseline

Selected S3 civic parcels now use deep masonry arch bays, closed iron inspection bays and a compact supported watch roof. Real openings, irregular outlines and existing ownership remain intact. Ordinary houses and other families retain the common foundation. This is one new architectural family, not the entire painted checkpoint scene.

The coordinating designer explicitly transferred the sole production/engine/Git lane against `a798043d529acda31994a1b3bdbb526ba7fde41b`. No new push is authorised or performed. Local implementation commits: `2e01d9f1` family routing, `7dbc1b1e` pure fitting, `45f35d99` rendering/assets; final capture/test/documentation work follows those commits.

The selected [S3 plate 03](../art/concepts/2026-10-19-segment-directions/03-s3-checkpoint-lanes.png) has SHA256 `3CC022A165A5D2611D1DEEACDFCECA35F509CF42F16EE82F3CD5640B4822F71B`. The [design packet](../design/2026-10-19-district-generation/README.md) maps all fourteen themes and distinguishes implementation from later proposals. Original open/closed PNG masters, exact prompts, returned paths, measured alpha/support anchors and hashes are in the [asset record](../../assets/world/districts/checkpoint_lanes/README.md). Originals were copied unchanged; no scripted raster edits were made.

## Implementation

The already selected family travels through instance manager/generator context to both real parcel paths. It is not rerolled from mixed/retry seeds. Fresh resolved dictionaries preserve per-building visual IDs; only `checkpoint_lanes` civic parcels select `checkpoint_guard_loggia`. An instance-local common-base comparison retains theme, terrain, layout and physical records.

The pure planner fits exposed wall spans around existing normalized openings and selects an entirely supported watch footprint or explicit safe omission. The renderer uses existing kit/roof ownership, shared fading and actor occlusion; it adds no physical floor area, collision or IndoorVolume. It replaces corresponding generic forms. Master textures use the existing cache, with repeated-load identity checks.

The measured open master needs roughly 72 px masonry returns beside a 128 px opening. Reserving 80 px fixed a demonstrated adjacent-bay overlap. A 32 px pitched cap above the 96 px watch body fixed the flat first native silhouette. Both adjustments have failing-then-passing regressions preserved under the evidence tests folder.

## Verification

All 22 final Godot scene/script runs exit 0 with zero failures and diagnostics. Full outputs and per-suite result files are in [tests](../art/reference/2026-10-19-s3-guard-loggia-v1/tests/summary.json).

| Check | Final observed result |
| --- | --- |
| Family routing, physical snapshots, caller RNG | 133 / 0 |
| Fitted guard geometry | 150 / 0 |
| Guard rendering, full cap/faces, cache, fading/occlusion | 349 / 0 after review; original 180 / 0 |
| Natural production comparisons | 395 / 0; 79 real chunks; 5 native candidates |
| Existing city kit / procedural parcels | 1,298 / 0; 5,430 / 0 across 76 parcels and 4 directions |
| Existing planned / material / all-theme coverage | 20 chunks, 60 buildings, 0 failures; material 0 failures; 150 / 0 |
| Reachability | 3,840 chunks, 2,538 doors, 1,728 rewards, 0 failures |
| Seed sweep / terrain / ground / player roof | 8 / 0; 8 / 0; 21 / 0; 11 / 0 |
| Boss clear courts | 728 / 0 across 88 arena chunks and 40 seeds |
| Chunk data / rendering / physics | 102 / 0; 12 / 0; 12 / 0 |
| Authored S1 tile / progression; Hub | 8 / 0; 42 / 0; 54 / 0 |
| Final script parse audit | 548 / 0 across 8 roots, last among behavior/parse scenes |
| Strict reported warnings | 14 target scripts, 7 reported categories, 0 failures/diagnostics; working settings unchanged |
| Capture-process predicate | 7 / 0; exact editor flag distinguished from game `--editor-pid` |
| Managed chunk-cost probe | 30 / 0 over 15 paired activations; physical snapshots equal |

Natural collection uses actual `main_street`, secondary, service, reward and fill role keys. A naturally absent checkpoint occurs at attempt seed 8. The old collector's `main_route` typo produced a larger incomplete sweep, archived as `production-samples-before-main-street-correction.json`; it does not support main-road claims.

## Native proof and visual review

The [evidence index](../art/reference/2026-10-19-s3-guard-loggia-v1/README.md) links two full native runs, three ambient entry runs and four paired architecture stills. All nine pass with **0 failures, 0 diagnostics and 0 save writes**. All **459 runtime source/asset hash comparisons match** the final candidate. Four packaged videos decode cleanly, retaining recorded timing and native dimensions.

| Native case | Actual sample and result |
| --- | --- |
| South, 1280×720 normal | Seed 1, plan 1721464603, `(2,-5)`, reward building 1517657286; 142 frames, 64 fires, 62 hits, 29 deaths |
| North, 960×540 Reduced Motion / Flashes Off | Seed 211, plan 1173896510, `(2,2)`, reward building 93140343; 164 frames, 63 fires, 56 hits, 29 deaths |
| East, 1280×720 | Seed 16102026, `(-3,4)`, fill building 1272508659; real entry/exit alpha 0/1, identical reload |
| West, 960×540 | Same seed/chunk, fill building 974809560; real entry/exit alpha 0/1, identical reload |
| Irregular, 960×540 | Seed 211, `(4,-5)`, service building 265571229; real east entry, recessed outline preserved, alpha 0/1, identical reload |

Full runs preserve perimeter travel, production-triggered security clearance, roof cutaway/restoration, complete streamed unload/reload and controlled outside combat: **306 frames, 127 fires, 118 hits and 58 deaths** combined. Ambient directional samples honestly have no security encounter; the harness does not invent one to satisfy reward-building assertions.

At unchanged north-up camera/zoom, the small/normal pairs show fitted arches, a closed grille bay and raised watch silhouette with separable details hidden. The closed bay has opaque iron/backing and a sill; the actual open arch remains the entrance. The author inspected paired forms, directional/irregular exterior/interior samples and full-run cutaway/combat frames. This is sampled author inspection. Broad blank panels, inherited dark terrain/light context, foliage/HUD overlap and whole-concept fidelity remain subjects for coordinating visual review, not accepted because tests pass. Baked cloth/detail in the base texture cannot be hidden independently.

## Cost and contract limits

The [cost probe](../art/reference/2026-10-19-s3-guard-loggia-v1/chunk-cost-probe.json) runs three paired managed creations for five real chunks after one guard-only warmup, always measuring common first. Mean content time is 11.608 ms common / 5.737 ms guard; blockers 2.661 / 2.573 ms. The 79-chunk fixture averages 156.861 / 154.709 nodes. These noisy headless fixtures disable ground drawing, ambient decorations and sites and have asymmetric cold/order effects (first common south/east about 42.65/53.96 ms). Their means cannot isolate family costs; see the [interpretation correction](../art/reference/2026-10-19-s3-guard-loggia-v1/cost-probe-interpretation.json). They do not establish faster gameplay, GPU/draw-call costs, historical routing overhead or a loading budget. Reload checks verify removal/restoration and identical forms; cache checks verify shared textures. The existing 250 ms warmup concern remains unresolved, with no threshold/scheduler edit.

Common/guard comparisons cover blocker kind/mask/variant, floor stamps/alpha, room/door/footprint records, access/clear masks, IDs, security/rewards and later RNG outcomes. No road graph, terrain/ground policy, checkpoint topology or enemy rules change. S1, Hub, DonJons, legacy roofless structures, gates/gantries/canals/rail and other bespoke families remain separate.

All native presentation evidence uses **64 px cells**. The pure planner implements scale math; alternate scales remain unverified; arbitrary whole-game scales remain unaudited because base renderers use fixed heights. The actor shader retains its **32-triangle** cap; the final test compares dense interior/near-edge samples in both stream orders with an independent union of individually uncapped roofs. Conservative projected overlap uses real guard compositions and 29–36 reference triangles, reaching the fixed 32 capacity where applicable. This stress fixture is not a natural-density claim and does not rewrite the algorithm. Scripted input, god mode, inactive ambient spawner and controlled crowds are labelled. Strict warnings cover the reported categories/14 scripts, not the complete editor warning panel. Original frames and earlier exploratory captures remain local; committed stills, videos, metadata and logs provide the packet.

## Rulings made during implementation

Every ledger ruling is preserved in order, with the cost if wrong.

1. Reuse the supplied linked checkout/branch: another checkout would split the accepted ownership/evidence lane.
2. Run focused city/chunk/S1/Hub suites plus parse/strict rather than every unrelated scene: no canonical aggregate exists; unrelated regressions could remain undiscovered.
3. Use proven natural fixture seeds S3=1, S7=4, S11=3: seed 1 lacks both S11 roles; incorrect fixtures would falsely imply coverage without changing production.
4. Ledger freshly read results without bookkeeping-only repeats: redundant tests add no evidence; saved results/commit ranges bound bookkeeping drift.
5. Reserve 80 px beside portals from measured 72 px returns; ordinary piers stay 24 px: narrow parcels fit fewer bays but preserve real openings.
6. Use dedicated guard render tests plus the legacy mask suite: a missed integration case remains possible, bounded by both suites and native proof.
7. Bring still/comparison flags into Task 3 for native proportion review: capture-only changes precede final metadata verification.
8. Add a 32 px pitched cap above the 96 px body: the taller envelope requires the tested/native occlusion coverage.
9. Hide separable details/foliage identically in paired captures only: gameplay RNG/planting remain; baked base texture detail is still visible.
10. Bound presenter acceptance to 64 px cells: noncanonical whole-game presentation can be wrong until separately audited.
11. Use exact natural IDs/chunks and ambient entry-only cases, with two full security/combat reward runs: security is inapplicable to ambient parcels, and reward-harness assumptions would misrepresent them.
12. Allow 600 seconds for full serialization; wrapper default remains 240: game thresholds are unchanged, but failed output may take longer before own-process timeout.
13. Distinguish exact editor flags from game `--editor-pid`: missing command information blocks conservatively and may delay capture.
14. Correct `main_route` collector spelling to actual `main_street`, archive old data and rerun: historical results cannot support main-road coverage.
15. Make the concrete packet available for coordinating review without claiming aesthetics accepted: a later rejection can require a bounded visual revision.

## Final review

The one fresh read-only reviewer inspected baseline `a798043d` through `e7488e36`, source/spec/rulings and actual pixels. No Critical or demonstrated gameplay failure was found. The Important gap was the old neighbouring-roof fixture, which never demonstrated pressure and checked only a centroid. A new pressure assertion failed seven old fixtures; stronger geometry-union/order/edge tests then pass, with the complete final suite/parse/strict evidence recorded under `post-review-tests` and `post-review-strict-warnings`. One trial helper used an incorrect existing material signature; its parser failure is preserved and not counted as a passing run. Only test/evidence/docs change in this fix pass; all captured runtime hashes remain valid. No second reviewer is dispatched. See [fresh review](../art/reference/2026-10-19-s3-guard-loggia-v1/fresh-review.md).

The [coordinating visual review](../art/reference/2026-10-19-s3-guard-loggia-v1/coordinating-visual-review.md) accepts keeping this first prototype, with three pending refinements: quieter material/depth on pale panels, a more distinct watch body/eave silhouette, and clearer real side-threshold cues. Closed/open arch readings, recessed outline and sampled combat actor distinction are supported. Inherited lighting and foliage/HUD composition remain separate limits. No final human art sign-off is claimed.

### Deferred minors

- Balanced warmup/alternating-order cost methodology; historical diagnostics are explicitly corrected, with no speed claim.
- Alternate-scale planner fixtures; scale math exists, but only canonical scale is verified.
- Flat infill/watch-panel material and corner/base depth refinement.
- Stronger compact watch body/side/eave silhouette.
- Clearer actual side-entry surrounds/ground cues.
- Capture-tool compatibility: by source inspection, S3 plus the older original-material `before` mode conflicts with the new guard-profile assertion. That combination was not executed or accepted; use the verified instance-local common-base comparison. Default S2 `before` remains separate. A compatibility fix is deferred.

### Additional review rulings

16. Final art/daylight/blank panels/HUD foliage are not code acceptance: coordinating review keeps the prototype but requires a later visual pass; cost is further refinement before human sign-off.
17. Whole district concepts, gates/gantries and other families remain outside this selected family: later district work is still necessary.
18. Arbitrary whole-game scales remain unaccepted at a 64 px native boundary: noncanonical configurations can render incorrectly.
19. GPU/loading budgets and historical routing overhead are unproven by this asymmetric CPU probe: performance issues outside it remain possible; the old 250 ms concern stays open.
20. Human continuous play/balance is not established by scripted god-mode captures: human-play defects can remain undiscovered.
21. The reviewer ran no engine under the read-only single-lane instruction: execution confidence rests on the executor's fresh logged runs.
22. Passage exits and narrow no-watch support have pure geometry fixtures; a no-watch irregular case exercises render integration, but neither has a native walkthrough. The natural irregular sample has a watch: native aesthetics for these variants can still require refinement.
23. The pressure test uses conservative overlapping projections of real rendered forms and independent per-roof reference unions: it deliberately pressures 29–36 triangles rather than claiming those overlapping footprints occur naturally; arbitrary future configurations beyond the sampled coverage remain unaudited.
24. Preserve the existing shared branch/worktree and make no merge/push/PR: the user's existing no-push ownership instruction already chooses keep-as-is; no integration menu or new permission request is needed.
25. Preserve raw failed-run logs byte-for-byte despite their trailing blank line: final whitespace validation excludes `.log` evidence while checking every code/document change; formatting defects inside raw logs are intentionally retained as provenance.

No merge, PR, push or unrelated cleanup is part of this task. The exhaustive execution ledger is preserved in the evidence packet before deleting only this plan's scratch workspace.
