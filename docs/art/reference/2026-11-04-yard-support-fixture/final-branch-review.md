# Final whole-branch review — targeted yard preview

Reviewed range: `d7cfb52f308dc5dfe4ef114ca9917d280ab016a2..6de56bed76a5d78a45bec49ace72bdb79a9d3c4a` (11 commits).
Package: `review-d7cfb52f..6de56bed.diff`, SHA256 `ffd82495e8c6291f58eb1f28ae5487c27923de390aefcd5f7f42a28f3a1571ac`.

Read-only review of the supplied package, production sources, tests/tooling, design/plan, ledger, Task 2b report/review, project vision/latest relevant roadmap, and selected actual receipts/logs. No engine, repeated test run, source edit, commit, broad status scan, or subagent. This requested scratch report is the only write. The independently prepared later native evidence packet is outside the reviewed commit range.

## Findings

No new Critical/P1 or Important/P2 correctness finding. No production change requested. The branch is suitable to retain as a qualified, default-off local prototype. This is not approval to activate it by default, claim actual-game visual acceptance, publish a trailer, or call the branch fully production/merge validated.

Specific strengths checked:

- The helper bounds allocation/geometry work, rejects malformed shapes/access metadata, chooses one exposed convex corner, and independently clips every output cell against footprint, garden and signed doorway access. Integer hashing does not use gameplay RNG.
- The Map has independent fixed-size storage, precise semantic-6/zero-care clipping, bounded wrap/clear behavior, stale clearing before malformed valid-chunk replacement, and independent snapshots. Literal-coordinate tests exercise negative, nondivisor and extreme wrapping.
- Renderer integration is additive and opt-in. Only one explicit coordinate/seed with one unambiguous household is selected; the Manager bridge follows existing domestic care. The original maps, slots and original shader source/resource remain authoritative. The preview mask/texture/shader are lazy.
- Shared shader parameters are copied across enable/disable; original shader code is not edited. CPU floor/care clears and shader positive-centre/care vetoes jointly prevent stale or filtered-neighbour preview leakage. Independent mask uploads occur even when the original maps are clean.
- Shader hooks are uniquely validated against the supported current source. The preview reuses the existing S7 material path. Default mode retains the original GPU program.
- Tests are nonvacuous: useful positive support, four literal access regions with no-door positive controls and the preserved access-veto mutation, actual fractional care overlap, distinct native semantic/care controls, remaining uncontrolled positive cells, and an original-renderer/original-shader comparison at identical world coordinates. Native evidence uses the actual 14-layer cache/imported textures, with only two explicit asset-loader leaf doubles.
- Launcher gates reject missing positive summaries, diagnostics, native failure and sampled guard stops. The final renderer launcher verifies its executing bytes against its pinned snapshot and nests receipt cleanup. Evidence distinguishes old revisions, failed/refused attempts, synthetic controls, retained test subsets and native fixture scope rather than aggregating them into a false full-project pass.

## Deferred-minor triage

These are already recorded, unchanged P3 resilience issues, not new blocking findings:

1. `tools/tests/run_yard_support_data_tests.ps1:111`: a missing/unreadable output log can bypass the per-suite receipt and leave its initial `not_launched` text despite the root launched flag/exception. The root remains failed; no false pass. Keep deferred for this local prototype. A future hardening change can place per-suite failure/receipt writing in a suite-level finally block.
2. `tools/tests/run_yard_support_data_tests.ps1:135`: failure writing the root receipt can bypass explicit mutex/reservation disposal. Owned-engine cleanup has already happened, and process exit closes handles; an interactive caller may need restart. Keep deferred for this local prototype. A future hardening change can nest the root receipt write in try/finally, as the newer renderer runner already does.

Neither minor invalidates the saved successful runs or warrants a new engine cycle during this review. They should remain visible in the handoff; they are not silently closed.

## Evidence independently cross-checked

All 24 `task2b-final-data/source-pins.json` artifacts and all 36 `task2b-native-final/source-pins.json` artifacts match their pins. Every pin labelled unchanged repository source also matches its current working file. Final raw stdout summaries and empty stderr agree with the per-suite receipts:

| Scope | Result | Native exit / diagnostics / stop |
| --- | --- | --- |
| Actual renderer API fixture | 75 passed, 0 failed | 0 / none / none |
| Pure helper | 82 passed, 0 failed | 0 / none / none |
| Independent Map | 69 passed, 0 failed | 0 / none / none |
| Retained old data subset | 60 passed, 0 failed | 0 / none / none |
| Tiny native material fixture | 46 passed, 0 failed | 0 / none / none |

The retained subset changes cleanup scheduling and excludes three Manager integration assertions. It is not the full old suite or a production performance result.

`native-pixels.json` records 10 planned cells above 60, six distinct controls and four uncontrolled positive cells. It records 3299 changed positive-yard pixels; default-off, enabled-empty, disable, reset, zero-centre, alpha, late-care, late-floor and all six road/lane/footway/courtyard/indoor/care controls record zero changes. This establishes the synthetic fixture behavior, not actual generated S7 composition.

`task2b-project-parse/result.json` explicitly has `launched:false`, `success:false`, native exit null, and refusal at 324 MB available RAM / 2126 MB commit in its failure message, below the unchanged 1536/3072 MB full-project startup gates. The separate sampled startup fields are 328/2125 MB; they are separate observations, not a contradiction or a pass.

## Reviewed production SHA256 pins

| File | SHA256 |
| --- | --- |
| core/systems/world/ChunkManager.gd | d753fc81d2e41697fd85e196b12b8fbf151802086d08c3862e7a83ade296aabc |
| core/systems/world/ground/CityYardSupport.gd | 041bc99da8a6e9a7f3d29cf96748cd3f7bd7b1130cc3c06108d8f6cc352c5645 |
| core/systems/world/ground/CityYardSupportMap.gd | 82940452760fda0995c30712c1d71e5706f6f48feb4b9d8af2fa1311d7f29dcf |
| core/systems/world/ground/GroundSplatRenderer.gd | f74134fd9f5cf0a4b0b0ff87ab39faaebb38e7328aa5570d8c180328c3bd591b |
| core/systems/world/ground/YardSupportPreviewShader.gd | f535a599ff996283002f25efc6308184ae1d4bfdb3b21b074eaa1019af189423 |
| core/systems/world/ground/ground_splat.gdshader | 64c8d2fa214bc30e1d58d3dfea5ea0719113f6ae09689f6ebe1b3d403f1314b9 |

Final fixture runner SHA256: `2c047b78e36e1fbc27f30df641f37723ccc56fb771c5b57402a47cf27d205058`.
Full-project attempted wrapper SHA256: `c1eb9fd581c7711c89f342b4a221b229c62186757068c6e3b24f72d0299f5db3`.
Unchanged resource guard SHA256: `dfe25730c5e24ac0e4ed6031af387c5fa2038ef30c37c1c7ac087856c19e7382`.

## Declined to judge / remaining acceptance gates

- Whole-project parse/integration: required project check was refused before launch; the isolated fixture does not close it.
- Actual generated S7 at normal/small output, household fit, doorway/passage traversal and streamed reload: no actual-Game evidence is present, and the native fixture deliberately omits buildings/routes.
- Production CPU/GPU cost, Intel GPU register headroom and live trailer motion/audio/readability: not established by sampled tiny-fixture timings or synthetic pixels.
- New aesthetic approval of the chosen yard outline and first-trailer readiness: requires native actual-game review; proposed shot plans/source audits explicitly do not claim it.
- OS resident-page recovery and repository-local Git resource/longpath settings: documented host orchestration decisions, not product changes in the reviewed diff; no new operation or general host-performance approval was inferred.
- Later durable native packet packaging: independently in progress outside `6de56bed`; its final bytes/links require its own packaging verification and cannot be inferred from this report.

## Assessment

Clean scoped whole-branch source review for the bounded default-off prototype, with the two existing P3 launcher issues deliberately deferred. No fix wave requested. Full production/merge/trailer acceptance remains unpassed for the explicit gates above; retain the source/evidence qualifications in the final handoff.
