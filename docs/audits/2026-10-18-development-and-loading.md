# Frontend routing and responsive transition investigation

## Reproduced causes

Development depended on `SaveManager.current_save`, which is deliberately null after restarting the application. Continue resolved the latest readable slot, but Development neither selected that profile nor offered profile creation. The existing UI fixture always preselected a save, hiding the restart case.

The loading cue already rotated in `_process`. `Global.goto_scene` displayed it for two frames, then synchronously loaded and entered Game. The real cold regression recorded one spinner advance and a 7396 ms gap. A diagnostic separated approximately 7.3 seconds of resource loading and 1.44 seconds of same-frame world/HUD construction; adding another label or delaying the fade could not resolve either block.

## Resulting behavior

Development resolves the same latest readable profile policy as Continue without resuming the attempt. With no readable profile, Archives opens in development intent; creating/selecting a profile opens the existing development panel. Continue, backup handling, and terminal continuation semantics remain covered by their existing assertions.

Scene resources now load through Godot's threaded request/poll/get API. The outgoing world pauses during resource work. Race frame resources and ground preparation complete before Game instantiation. Latest request wins, terminal outcomes supersede an in-flight normal-world route, and failure restores the outgoing state while emitting one latest-request failure event.

An explicit one-use Global entry token selects progressive startup only for the routed root Game instance. A still-visible old loading card cannot change a nested/direct Game fixture's synchronous behavior. CityContinuation initially exposed this regression with five native lethal-area failures; the unchanged 107 assertions pass after the token fix.

Normal routed Game entry builds its independent HUD subtrees, developer-console pages, authored phases, and procedural-world phases across actual rendered frames. Input and world simulation stay frozen until `is_transition_ready()`. Direct scene startup retains synchronous behavior. Cancellation guards stop coroutines after their node leaves the tree. A per-instance pending recorder binding waits for readiness and for any newer route to settle; failed replacement can then bind the completed outgoing world.

Ground first-touch preparation also awaits renderer submission before the next texture/layer. Native warmup improved from 411.662 ms to 182.663 ms maximum frame gap; prepared and original ground-array layer hashes match exactly.

## Verification and limits

Final source verification after the derived ground array was added:

| Actual route | Checks | Maximum frame gap | Total route time | Loading + setup cue advances |
| --- | --- | ---: | ---: | ---: |
| Headless Segment 1 | 7 passed | 133.435 ms | 7.746 s | 910 + 80 |
| Headless Segment 2 | 7 passed | 164.822 ms | 10.388 s | 1311 + 39 |
| Native Segment 1, cold | 6 passed, strict timing failed | 500.515 ms | 12.484 s | 199 + 89 |
| Native Segment 1, same-process warm | 7 passed | 202.157 ms | 4.391 s | 11 + 89 |
| Native Segment 2, cold | 7 passed | 215.602 ms | 9.431 s | 213 + 40 |
| Native Segment 2, same-process warm | 6 passed, strict timing failed | 440.374 ms | 2.373 s | 12 + 40 |

Raw final logs are `loading-headless-final-s1-baked.log`, `loading-headless-final-s2-baked.log`, `loading-native-final-baked-s1.log`, and `loading-native-final-baked-s2.log`. Both headless runs exit 0. Both native processes exit 1 because each preserves one strict timing failure across its two cases; all six functional assertions pass in every native case. The strict 300 ms assertion was never relaxed. No screenshots occur during these timing runs.

The final derived ground-array loads take 39.826 ms (native Segment 1) and 52.965 ms (native Segment 2), replacing the thirteen runtime image readbacks. The remaining native Segment 1 500.515 ms frame follows a measured 20.645 ms tile-construction stage. The remaining warm Segment 2 440.374 ms frame follows a 0.134 ms DangerOverlay addition. This establishes that initialization callback time alone does not explain those full native frame stalls; exact backend attribution remains unresolved. A universal native frame ceiling is not claimed.

Parent's independent native prepared-array test also confirms exact original layer/mipmap pixels, with 17 preparation frames; its 259.592 ms maximum narrowly fails that separate test's stricter 250 ms diagnostic. This is recorded as 2/1, not a complete pass.

`audit.json` records actual source-file SHA256 hashes, normalized method-source hashes, and raw log/capture hashes. `WriteFrontendAudit.ps1` reproduces the manifest. The latest focused frontend/lifecycle compatibility set remains 316 passing assertions; the two final headless full-route checks add another 14 passing assertions.

- `development-red-clean.log`: fresh-restart/profile-less cases fail against the original implementation.
- `development-green-clean.log`: FrontEndFlow 43/0.
- `loading-widget-green.log`: LoadingScrim 16/0.
- `development-ui-green.log`: CityDevelopmentUi 86/0.
- `continuation-async-red.log`: CityContinuation 107/0 (filename predates its successful result).
- `late-recorder-binding-red.log`: actual late Game completion 17/2; menu capture reopening and binding during pending replacement are reproduced.
- `late-recorder-binding-green.log`: 19/0 with the Game-side fix, before the later central recorder guard. Deliberately missing supplemental race-atlas errors are expected controls; no tree/coroutine cleanup errors remain.
- `failure-history-order-red.log`: 20/1; releasing the ready outgoing Game before emitting failure lost the requested destination from recorder history.
- `failure-history-order-green.log`: final interruption suite 21/0, native exit 0, including actual supplemental-asset failure, partial Game reload, terminal cancellation, late Menu routing, failure recovery, and preserved failure-event target. The three deliberate missing-atlas controls are the only expected errors.
- `continuation-explicit-entry-green.log`: unchanged CityContinuation 107/0 after restricting async startup to routed root instances.
- `pause-explicit-entry-final.log`: PauseMenuFlow 43/0, native exit 0. Real Game/Hub pause and Settings input, conflicting keyboard/controller bindings, saved checkpoint/wardstone, terminal account semantics, and frozen outgoing world remain intact. With parent's latest FrontEndFlow 43/0, LoadingScrim 16/0, CityDevelopmentUi 86/0 and the final 21 interruption assertions, focused frontend/lifecycle checks total 316 passing assertions.
- `warmup-native-postdraw.log`: native warmup 3/0, maximum182.663 ms, exact pixel equivalence.
- `loading-native-worker-diagnostic-s1.log`: actual cold native Segment1 reaches ready in11.428 seconds with207 loading-spinner advances and61 setup advances. Six functional assertions pass; the unchanged strict300 ms diagnostic fails. That trace identified the remaining first-region decal work, subsequently budgeted across real frames.
- `loading-native-cold-warm-s2.log`: actual cold native Segment2 has353 loading and40 setup advances, maximum473.962 ms, 6/1; the second route in the same process is7/0 with maximum109.291 ms and completes in2.230 seconds. No screenshots are captured in this timing run.
- `loading-native-final-decal-s1.log`: cold and warm native Segment 1 both reach ready with all six functional assertions. Real floor-detail work now runs in measured 12–23 ms batches; seven authored decal first-touches take approximately 6–15 ms each. The unchanged strict timing diagnostic still fails on isolated rendering/readback frames (cold 600.140 ms, warm 451.364 ms). An earlier ground layer readback reached 609.845 ms and parent is investigating a derived ground-array resource separately.

Cold Intel UHD/OpenGL native runs can still contain isolated long rendering/readback frames. For example, a468.294 ms frame follows an exit-stage CPU call of0.453 ms. These are retained as failed strict diagnostic results, not hidden by a relaxed threshold. The same-profile restart comparison instead reproduces the existing GLES shader-cache initialization crash (native exit-1073741819); same-process warm comparison avoids loading that broken disk cache.

An earlier diagnostic eagerly loaded the ChunkManager script before requesting Game and observed one120-second resource timeout. Removing that observer restored successful bounded native S1/S2 routes; the verbose successful run records loader progress and cached dependency state. This is correlation with changed dependency ordering, not a proven engine-level deadlock diagnosis. No blanket dependency prefetch was added.

## Harness provenance

All engine processes use task-specific process-local APPDATA/LOCALAPPDATA and the native executable, hidden, with the real exit code. The editor was not stopped. Visual captures in `native-s1-captures` and `native-s2-captures` are separate from final timing runs. Reading viewport pixels during a timed run can itself stall the GPU, so those earlier diagnostic captures are not used as clean timing evidence.

The first same-profile comparison accidentally reused its output name, overwriting one detailed cold log. `native-cold-s2-observed-excerpt.md` explicitly identifies the exact previously tool-read excerpts; it is not presented as the complete raw log. Later comparisons use separate output/profile naming.

Historical probe exclusions: `development-green.log` raced the earlier coordinated cursor import and is superseded by `development-green-clean.log`; `loading-native-timed-s2.log` and `interruption-staged-final.log` contain test-harness compile errors and are not passing evidence. `loading-real-red.log` retains the valid one-advance/7396 ms observation, but its separate Game-arrival assertion used a wrong-case path and is not evidence of a production routing failure. Early fixed-frame waiting failures are superseded by bounded destination/readiness waits with their original behavioral assertions preserved. Raw logs are retained rather than relabeled as clean passes.

The native recorder initially used its editor default `res://balance_captures` despite isolated APPDATA. The harness now sets `user://frontend_transition_captures`; interruption fixtures already used a user directory. Parent relocated only verified synthetic seed 732113 reports into `synthetic-native-reports`, preserving the user's original report.

## Published evidence

[Focused logs and the source/method manifest](evidence/2026-10-18-development-and-loading/) preserve the final results above, including the failed strict timing diagnostics. Separate [loading frame 12](../art/reference/2026-10-18-responsive-loading/spinner-frame-12.png) and [frame 30](../art/reference/2026-10-18-responsive-loading/spinner-frame-30.png) show the unchanged card with different spinner orientations. Those early visual captures are excluded from timed measurements. Unpublished historical probes remain in the local task evidence named above.

Manifest source-file hashes identify the measured working-file bytes; method hashes normalize LF for portable source comparison. Captured evidence bytes are preserved by the evidence folder's attributes rather than normalized during checkout.
