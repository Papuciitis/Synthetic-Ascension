# S3 refinement code review

19 October 2026. Production owner transcribed the completed read-only review from `/root/s3_v2_final_code_review` of `b42dae72..5a3b1068`. The reviewer ran no engine, edited no files and made no Git changes. The pre-reset review attempt delivered no report and is not counted as a completed review.

**Verdict at review: With fixes. Critical: none. Important: none. Minor: one.**

The reviewer confirmed shared texture-cache use, a transient texture-bearing roof-profile copy, existing roof-fade ownership, cardinal landings derived from actual doors, and no changes to physical generation, navigation, rewards/security, identity or RNG. It checked all424 source hashes in eight revision2 manifests against the workspace at that time and viewed small guard exterior plus west exterior/interior. Visual acceptance remains designer-owned.

## Minor1 — side corner exposed by a notched cap

The hand-written lower-body proxy assumed the upper side triangle stayed hidden by the watch cap. A valid L parcel disproved that after cap door-notching: outline `[(128,128),(640,128),(640,832),(320,832),(320,512),(128,512)]`, east door `{pos:(9,8),dir:RIGHT,width:2}`, visual seed3. The fitted support clears the opening, but the raised opaque side includes local point `(613,574)` while the notched cap and proxy exclude it. Approximately21 world-pixel² were omitted.

**Ruling: accept and fix.** The owner reproduced the report: refinement suite167pass/1fail. Coverage now merges actual front/side polygons and subtracts the final notched cap, retaining each uncovered fragment. Rendered faces, physical layout, the overall envelope and the global32-triangle shader limit remain unchanged. The final regression also samples the real production actor mask at alpha1/0.4/0 and an adjacent uncovered gap, using each polygon's global transform. Its initial local-coordinate test mistake was corrected before acceptance. Fresh final result:174pass/0fail, exit0, no diagnostics. The independent union grid and shared-budget stress remain required separately.

## Review boundaries

The reviewer declined to judge final aesthetics, continuous play/balance, comparative performance/warmup timing, alternate cell scales, wider daylight/ground/foliage, future streets/tree/enemy/pickup visibility, S4A/other families, or previously disclosed before-mode/indoor-volume/mixed-site limits. These are appropriate scope boundaries, not completed requirements. No new finding in those areas was invented or treated as closed.

Final native captures and regression records are subsequent owner evidence linked from the packet README. The eight revision2 manifests accurately identify the reviewed visual candidate; they predate the mask-only correction and are not final-current-source verification.
