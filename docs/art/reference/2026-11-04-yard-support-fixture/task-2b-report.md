# Task 2b — bounded opt-in renderer preview

Qualified opt-in prototype report; parent owns final review/commits. No engine is
running, and further heavy Game checks are held for external headroom change.
All production/tool/test source is frozen; independent native-test review clean.
No default enablement,
Game fit, traversal/cost or trailer-readiness claim.

## Scope and behavior

Only these production files changed:

- `core/systems/world/ground/GroundSplatRenderer.gd`
- `core/systems/world/ChunkManager.gd`
- new `core/systems/world/ground/YardSupportPreviewShader.gd`

`ground_splat.gdshader` remains byte-identical to original `d7cfb52f` (SHA256
`64c8d2fa214bc30e1d58d3dfea5ea0719113f6ae09689f6ebe1b3d403f1314b9`).
No art, terrain/generation, gameplay data, navigation, RNG or other gameplay path
was edited. Renderer/default runs retain the original Shader resource/program.

An explicit request requires `SA_YARD_SUPPORT_PREVIEW=1` and canonical
`SA_YARD_SUPPORT_TARGET=chunk_x,chunk_y,visual_seed`. Manager reads these once per
splat instance. Missing/malformed/overflow targets never select all households.
The request waits for enabled `underpass_veins`/`canal_services` policy. Only one
unambiguous matching household seed at that exact chunk is selected; duplicate
matches clear the candidate. Renderer proposals are max-composited before the
Map replaces its wrapped bytes. Existing semantic IDs and exact care bytes clip
the output. Map alone owns the new wrapped buffer.

The new L8 texture and separate Shader are lazy. The factory validates six
unique hooks in the original shader and fails closed if unsupported. It adds a
bounded amount to the existing S7 patch, reusing its material/sample/repeat/grade.
The amount samples unwarped light-map cell coordinates and vetoes zero-centre
mask cells and positive care. The existing care-rendering block is unchanged.
Preview-only debug view3 displays the amount. Disabling restores the exact base
shader object and every shared shader parameter. Ground replacement, later care,
wrapped reuse and world clear erase mask cells; uploads have an independent
dirty flag.

## Verification actually observed

All paths below are relative to this report's directory. The command working
directory was the `enemy-world` worktree. Python executable:
`C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`.
Engine executable:
`C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe`.
Engine SHA256: `323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`.

| Evidence | Actual result | Scope/limits |
| --- | --- | --- |
| `task2b-red-1` | Renderer **0 passed / 1 failed**, native exit1, exact absent-API assertion; no parse failure or guard stop; sampled41MB private, minimum519MB free RAM | Actual old renderer. RED uses `has_method`, not an unresolved method parse error. |
| `task2b-green-1` | Test parse failure: calling nonstatic `call()` directly on a script class plus inferred Variant. Guard timeout; native exit-1; sampled45MB private, configured30s, observed75s elapsed | Corrected test to instance `call` plus explicit Dictionary. Raw diagnostics retained. Guard is sampled and does not guarantee a hard elapsed deadline. |
| `task2b-green-2` | **Not launched:**435MB free RAM /3191MB commit versus512/1536 gate | First data startup refusal; parent made one temporary current-chat resident-page recovery. No user app was closed/trimmed by implementer. |
| `task2b-green-3` | Actual renderer **72 passed /0 failed**, native exit0, empty stderr/no diagnostics/no stop; sampled55MB private, minimum525MB RAM/3037MB commit,2.5s | Production source frozen at hashes below. Tests cover target/parser/policy, independent bytes/RNG, reset/wrap, late planting/floor, dirty upload, resource/parameter restoration and source hooks. |
| `task2b-green-3/subset` | **Incomplete:** sampled65MB >64MB cap; stopped after21 assertions, native exit-1, no diagnostics | Original retained data test queued all renderers for deletion until batch end; no60/0 claim. |
| `task2b-regression-1/subset` | **Incomplete:** timeout30.63s, sampled56MB private, minimum474MB RAM/2834MB commit, no diagnostics | New subclass invokes the same13 retained existing methods with a cleanup frame between cases. Last completed method `_test_district_policy_presentation`; next `_test_district_care_eligibility` scans1024 cells and street neighbours before first check. No claim that paging is the proven cause. |
| Python source/build contracts, original run | **5 tests passed**,9.576s, exit0 | Original shader equality; manager explicit once/after-care binding; factory supported hooks; data fixture pins/metadata/no-overwrite; original native renderer+shader transformation and actual14-layer/mip asset binding. Original outputs `task2b-builder-contract-data` and `task2b-builder-contract-native`. New source test CLI uses fresh `--evidence` root for repeatability. |
| `task2b-native-1` | **Not launched:**565MB RAM/3135MB commit vs704/1536 native startup gate | Native fixture built with actual original art/cache; no native pixels yet. Engine handed to parent for immediate guarded native attempt. |
| Parent `task2b-native-parent1` | **Not launched:**549MB RAM/3071MB commit vs704/1536 gate | Parent retained raw failure; then preloaded exact guard before final temporary resident-page recovery and immediate launch. No tier changes. |
| Parent `task2b-native-parent2` | **43 passed /1 failed**, native exit1; no guard stop; sampled242MB private, minimum442MB RAM/2602MB commit,8.99s | Actual native pixels produced. Failure was arbitrary planner count>12 assertion. Two additional native diagnostics came from assigning viewport canvas_transform before tree registration (SETUP, not teardown). Raw failed result/images preserved. |
| Parent `task2b-native-final` | **46 passed /0 failed**, native exit0, zero diagnostics/no stop; sampled241MB private, minimum470MB RAM/2589MB commit,8.5s; CPU5.688s | Corrected viewport registration and explicit unique controls. Actual native material originals and pixel JSON saved. Parent used unchanged704/256 profile with guard preloaded before final temporary resident-page recovery. |
| Parent `task2b-state-parent1` | **Not launched:**471MB RAM/2626MB commit vs512/1536 data gate | No engine; final75-check state and retained subset/helper/Map continuation pending with parent ownership. |
| Parent `task2b-final-data/renderer` | **75 passed /0 failed**, native exit0, no diagnostics/guard stop | Current frozen renderer/test source, including actual later domestic care/fractional-byte overlap checks. |
| Parent `task2b-final-data/support` | **82 passed /0 failed**, native exit0, no diagnostics/guard stop | Unchanged helper suite, fresh pinned fixture. |
| Parent `task2b-final-data/map` | **69 passed /0 failed**, native exit0, no diagnostics/guard stop | Unchanged Map suite, fresh pinned fixture. |
| Parent `task2b-final-data/subset` | **60 passed /0 failed**, native exit0, no diagnostics/guard stop | All13 retained old data cases, same assertions; explicit per-case cleanup frame. Exactly three manager integration assertions omitted. |
| Parent `task2b-project-parse` | **Not launched:**324MB RAM/2126MB commit vs unchanged1536/3072 full-project gate | `result.json` records no engine, pins and exact executed wrapper. No whole-Game parse or Game image/traversal/cost result. |

Generated shader observed by the72/0 data test:
`task2b-green-3/generated-yard-support.gdshader`, SHA256
`98c0b162c874ea50a7fb3f0b60127e97cc82a1fade8b9833c7dcd7d89f211702`.
It is pinned in the renderer result receipt alongside base/factory source pins.

Latest75/0 renderer test includes three real later-household-care overlap/
fractional-byte assertions beyond the earlier72/0 version.

Native-parent2 actual RGBA counts: positive yard3299 changed; default-off,
enabled-empty, zero-mask cells, alpha, each of road/lane/footway/courtyard/indoor/
care controls, later-care cell, later-floor cell, disabled and reset comparisons
all0 changed. Original before/after/mask and reset/control PNGs exist in that
failed run. This is useful native material behavior evidence, **not a clean
fixture pass** due to the assertion/diagnostics above.

Test-only corrections passed in the parent's clean native run: attach each
viewport before assigning canvas_transform; replace arbitrary>12 threshold with
six explicitly unique semantic/care control cells plus at least one remaining
uncontrolled positive yard cell. The planned>60-cell count is now printed and
saved, not assumed. An explicit `late_found` assertion proves a real>100 support
cell was selected for later care; it was present and passed in native-parent2.
Clean native-final measured **10 planned cells>60**, six unique control cells,
and **four uncontrolled positive cells**. The earlier arbitrary>12 failure was
therefore a fixture requirement error, not missing semantic control coverage.

Final per-suite sampled metrics (not peaks/hardware guarantees):

| Current frozen suite | Private MB | Minimum free RAM/commit MB | Wall/CPU seconds |
| --- | --- | --- | --- |
| Renderer75/0 | 53 | 665/3170 | 1.26/0.672 |
| Planner82/0 | 43 | 631/3155 | 1.36/0.359 |
| Map69/0 | 43 | 804/3202 | 1.33/0.359 |
| Retained old data60/0 | 52 | 882/3113 | 2.83/0.938 |
| Native46/0 | 241 | 470/2589 | 8.5/5.688 |

The final old-data run's case timestamps and low CPU/wall time contrast with the
earlier30.63s stopped attempt. No renderer logic or old assertions changed
between these runs; parent corrected startup orchestration to preload the guard
before resident recovery. This does not establish a general production cost.

## Exact commands executed

Each fixture was built fresh using this pattern (separate old outputs preserved):

```powershell
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-red-1
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-red-1
```

Same exact two commands with output names `task2b-green-1`, `task2b-green-2`,
`task2b-green-3`, then:

```powershell
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-green-3 -Suite subset
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/test_yard_support_renderer_fixture.py
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-regression-1
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-regression-1 -Suite subset
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-native-1 --native
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-native-1 -Suite native
```

Parent's final data sequence executes the preserved
`run-final-data-parent.ps1` orchestration (guard preloaded, one final temporary
resident-page recovery immediately before launching, four engines strictly
sequentially). Exact source, pins, arguments, native exits, unfiltered logs and
per-suite receipts are retained at `task2b-final-data/`; its
`parent-sequence-result` and pins bind the outer orchestration as well as the
fixture builder/runner/guard. Parent retains sole engine ownership.

Final data orchestration invocation:

```powershell
& .superpowers/sdd/2026-11-04-trailer-yard-preview/run-final-data-parent.ps1
```

Final native builder/fixture commands (parent preloaded the pinned guard before
the final temporary resident recovery and immediate runner launch):

```powershell
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-native-final --native
& tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory .superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-native-final -Suite native
```

Full-project attempted engine arguments, **not launched** after gate refusal:

```text
--headless --flush-output --path "C:\Users\NaurisKrišjānis\Desktop\code_project\SA_proj\.worktrees\enemy-world" --audio-driver Dummy res://tools/tests/ScriptParseAuditTest.tscn
```

The exact executed parse-wrapper source is
`task2b-project-parse/executed-wrapper.ps1`; SHA256
`c1eb9fd581c7711c89f342b4a221b229c62186757068c6e3b24f72d0299f5db3`.
Unchanged guard SHA256:
`dfe25730c5e24ac0e4ed6031af387c5fa2038ef30c37c1c7ac087856c19e7382`.
Final data/native runner SHA256:
`2c047b78e36e1fbc27f30df641f37723ccc56fb771c5b57402a47cf27d205058`.

## Fixture/provenance contract

`tools/tests/build_yard_support_renderer_fixture.py` uses only Python stdlib. It
creates an empty `.gdignore` FIRST and refuses existing output roots. It copies
actual renderer/shader/policy/care/planner/Map/ChunkBuildData/WorldBlockerGeometry.
Normal GDScript metadata names only ChunkBuildData/WorldBlockerGeometry and
GroundSplatRenderer; new Map/factory/planner use explicit preloads. There is no
Game/autoload or broad import. Only WorldArt and CityBlockKit asset-loader leaves
are doubled. Tiny-color data leaves are explicitly NOT art evidence.

Native fixture uses `ground_materials.res`10134012bytes, SHA256
`14a57921e0351de7a7ddbe343e783d7341cda75b6a8e774079e866dcb960d8b7`, original
worn_setts/paving PNGs, their `.import` files with mip generation enabled and
referenced actual `.ctex` files. No asset rebuilding. Baseline comes from
`d7cfb52f` renderer AND original shader. Exactly two validated renderer
transformations: remove its sole `class_name`, and redirect its sole shader
preload to the unchanged original shader copy. Separate512² viewports use
identical world coordinates (`-2,3` chunk), identical leaves/assets/transforms.

The existing data subset drops ONLY the three ChunkManager integration
assertions, retaining all other test method bodies and teardown frames with a
distinct `WorldGroundSplatDataSubset` summary. The bounded subclass adds one
cleanup frame per case. This changes test scheduling/lifetime and does not prove
the original batch's peak or whole-game performance.

The guarded Windows runner validates every copied source/asset/stub/launcher/
guard pin, verifies its **executing** launcher hash equals the pinned snapshot,
checks single-engine exclusion, uses a captured Start-Process handle, hidden
launch and isolated APPDATA/LOCALAPPDATA, keeps unfiltered logs/native exits and
rejects diagnostics or absent/zero assertions. The guard is copied exactly and
executed from that snapshot. All receipts retain configured limits and observed
sampled values; these are sampled safeguards, not peak/hardware guarantees.

Data profile:512MB free/1536MB commit startup;64MB private/30s sampled stops.
Native profile:704/1536MB startup;256MB private/120s. Both keep384MB free/768MB
commit running stops. Full project retains1536/3072MB startup and1200MB private.

## Frozen production hashes

| File | SHA256 |
| --- | --- |
| GroundSplatRenderer.gd | f74134fd9f5cf0a4b0b0ff87ab39faaebb38e7328aa5570d8c180328c3bd591b |
| ChunkManager.gd | d753fc81d2e41697fd85e196b12b8fbf151802086d08c3862e7a83ade296aabc |
| YardSupportPreviewShader.gd | f535a599ff996283002f25efc6308184ae1d4bfdb3b21b074eaa1019af189423 |

## Remaining gates

No whole-Game parse, actual generated S7 normal/small view,
doorway/passage traversal/streamed reload or production cost measurement is
claimed here. The46/0 native fixture pixels establish fixture behavior
only; actual Game aesthetic/route/cost acceptance remains separate. Independent
scoped source/native-test review is clean. Parent owns explicit-path local
commits and the final branch review. No commits or subagents were created by
this implementer. Default remains off.
