# Reported Godot script warnings

2026-10-19. Scoped cleanup of the human's 29 reported diagnostics in 14 scripts.
The final complete-context audit reports **zero** of those warnings, with all
seven relevant warning categories promoted to compiler errors at engine startup.
No working-project warning setting or suppression annotation was changed.
Ordinary building style rollout remains on hold: `CityBlockKit.enabled_for`
still requires segment 2.

| Reported category | Before | Final |
| --- | ---: | ---: |
| Shadowed base-class member | 14 | 0 |
| Unused private member | 1 | 0 |
| Unused parameter | 2 | 0 |
| Built-in function name shadowing | 2 | 0 |
| Confusable local declaration | 5 | 0 |
| Implicit integer division | 3 | 0 |
| Redundant await | 2 | 0 |
| Total | 29 | 0 |

Most edits rename local variables. The unused-looking `_street_area` has dynamic
writers and a test reader; its paving-owner state is retained as public
`composed_street_area`, with all string-based accesses updated. The role and
duration parameters remain positional contracts and now have underscore names.

Pagination's binary-search bounds are nonnegative, and image dimensions are
positive at the cover-snapshot check. Explicit `floori(... / 2.0)` preserves the
previous truncated midpoint, including odd-sized images. It does not change
page grouping or introduce rounding upward. Only the redundant awaits before
synchronous `_build_ground_stamps` and `_spawn_planned_geometry` were removed;
the adjacent initialization-frame awaits and cancellation guards remain.

## Verification method

The [evidence packet](../art/reference/2026-10-19-reported-warning-cleanup/checks.json)
contains raw diagnostics, source hashes and test reports. The final
[compiler report](../art/reference/2026-10-19-reported-warning-cleanup/after-final/audit.json)
loads and reloads all 14 scripts with real autoload registration in a separate
source/resource snapshot. Its engine exits 0 with zero diagnostics. All 14
audited source hashes match the candidate. A separate comparison matches 1,536
runtime source/resource files across assets, autoload, core, scenes, data, UI,
effects and spells; generated `.uid` and `.import` sidecars are excluded.

The [runner](../../tools/capture/check_reported_godot_warnings.ps1) configures
warning severity before starting the isolated engine; it never saves the
working project's settings. Its optional snapshot-reuse mode requires unchanged
dependencies; the recorded full comparison establishes that condition for this
run. The imported resource cache is shared for reads. The final working
`project.godot` hash remains unchanged.

Before and intermediate direct-file compiler checks are retained as diagnostic
runs. They reproduce the 29 reported locations, but also contain missing
singleton/dependency errors and initially omitted effects/spells roots. They
are not acceptance runs or evidence of production runtime failures. The final
complete-context run replaces that incomplete harness. Initial attempts to
change severity after startup were rejected as verification, since they did
not reliably trigger the expected diagnostic.

This checks the selected [Godot warning categories](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)
in the reported scripts. It does not claim that the entire human editor warning
panel has been inventoried or refreshed.

## Behavior checks and limits

Native library tests include real 1×1, 5×7 and 6×8 textures, transparent-center
fallback, opaque-center capture and rejection of an opaque rounded-up neighbor.
The split-roof fixture creates two actual clipped pieces and checks that the
continuation retains the shared shader and complete-wing bounds. Pagination
checks retain empty/short cases, every visible character in source order,
formatting, links and Unicode across page boundaries.

Detailed suite outcomes and the resource-warmup comparison are recorded in the
packet. The unchanged `AuthoredCoverDepthTest` fixture passes 114 assertions
while constructing a manager without a player-group node; its established
missing-player warning is recorded separately. No production behavior was
changed to silence that fixture diagnostic.

The first current-code native resource-warmup run failed its 250 ms timing gate
at 465 ms. A pre-cleanup snapshot, with all 14 original source hashes verified,
passed at 212.775 ms. Both use Godot 4.7.1, OpenGL Compatibility, isolated profiles
and the same imported-resource cache; OS/GPU cache state and timing are not
controlled. The preparation function is exactly equal to its pre-cleanup source
after normalizing only the three renamed timer locals and line endings. Both
failed current-code runs are retained: the single retry also missed the gate
at 279.9 ms. Timing remains unresolved for this tree; matching preparation
source does not establish stable performance. No scheduling or test-threshold
change was made, and this task grants no performance or human continuous-play
approval. Fourteen other affected-flow suites pass, including all 546 script
parses; the player-less fixture diagnostic remains separately qualified.

The provisional `CitySegmentCoverageTest` files, the independently owned style
inventory, generated editor sidecars, local caches and unrelated artifacts are
outside this cleanup and are excluded from its commit.
