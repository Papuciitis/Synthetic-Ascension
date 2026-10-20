# Domestic gardens v1

20 October 2026. Two logical garden assets, with one requested tree revision: three preserved PNG source files. Two initial built-in image_gen generations plus ONE targeted built-in projection edit. No further variations were generated. All selected/source-history PNG bytes match the tool outputs unchanged.

The lead provisionally kept both the low flower/herb bed and compact crown/short-trunk tree v2 as sources suitable to try at native scale. V2 is the selected tree candidate; the first tree remains intact as history. No native fit, gameplay, occlusion or final aesthetic approval is claimed. No further tree generation is authorized before in-game review.

Exact prompts/arguments/tool output paths: [prompts.json](prompts.json). SHA256, alpha, anchors, source history and sizing: [manifest.json](manifest.json).

| Source | Actual size | Ground anchor | Meaningful bounds at alpha >=128 |
| --- | --- | --- | --- |
| [fruit_tree_overhead_v2.png](fruit_tree_overhead_v2.png), selected candidate | 1254 x 1254 | (660,1060), root flare | [45,70,1212,1140), 1167 x 1070 |
| [flower_herb_bed.png](flower_herb_bed.png), provisionally kept | 1909 x 824 | (955,485), footprint center | [74,174,1835,669), 1761 x 495 |
| [fruit_tree.png](fruit_tree.png), preserved original | 1254 x 1254 | (674,1123), root flare | [65,9,1216,1181), 1151 x 1172 |

Coordinates are original-image pixels, origin upper-left, x right/y down. Bounds are left/top inclusive and right/bottom exclusive. Anchors were manually selected on the actual outputs, then checked by sampling their pixel alpha. Estimated uncertainty: about 16 source pixels for each tree root anchor and 25 for the bed center. They are ground placement pivots, not collider definitions.

## Tree revision and fitting

Lead review found the first tree's tall crown tiers and exposed trunk too frontal. The single edit used it as the edit target and the accepted temperate_tree source as material/style support, asking for a higher overhead compact crown and short partly hidden trunk/root. It changes the painted view; neither version was squashed or otherwise post-processed.

V2 has less exposed trunk, more canopy coverage, and a visible compact root flare. It still has a high/triangular lobe and an oblique tall silhouette rather than a strict plan-view crown. That remaining limitation is explicit; no further edit was attempted.

The lead's interface-source starting point is approximately 164 world pixels visible width. For v2, use uniform scale 164/1167 = 0.140531: visible extent about 164 x 150.37 world pixels; full image about 176.23 x 176.23. Draw its upper-left at ground_position minus scale times (660,1060). Original brief range was 100–170 visible world pixels; one floor cell is 64px. Root spread is visually estimated around [550,985,790,1140), not an authored physical footprint.

## Bed fitting

The low bed combines useful sage/thyme-like groups, a few muted violet/cream flowers, root earth and uneven low worn stones. There is no surrounding lawn, floor, formal rectangular planter or building.

Actual visible source aspect is 1761/495 = 3.558:1. At 80–128 world pixels visible width, its total projected visible height is about 22.49–35.98px, and estimated ground depth about 16.76–26.82px. The existing interface's 48–72px depth is a PLACEHOLDER, not a distortion requirement. Production should fit its geometry/placement to the unchanged source. A 115px width gives about 32.33px visible height and about 24.10px estimated ground depth.

Draw its upper-left at ground_position minus scale times (955,485), using scale = desired_visible_width/1761. A secondary front contact is (1150,659). Approximate ground/root-earth footprint is [80,300,1835,669); foliage hides the rear boundary, so this is not calibrated geometry.

## Ownership and visibility

Both are outdoor domestic planting for modest tended greenspace beside irregular medieval homes. Lawn and procedural wilderness remain separate. Fit to real parcel/entry data, preserve door approaches and combat routes, and keep the source aspect ratio.

The tree canopy is visual occlusion, not a prescribed new collider. Production owns root-based sorting, shadows and actor visibility. The bed is low ground dressing, not a wall-mounted facade panel or interior furnishing. Neither is automatically owned by an indoor roof cutaway. Actual wall/entry overlaps require production's real geometry/mask handling.

## Source checks and limits

All three files were personally viewed. Governing references were also personally viewed: accepted city concept08, existing temperate_tree/planted_corner sources, and fresh actual service-lane960x540 frozen environment plate. V2 and the old tree/reference were viewed again for the edit.

All have real alpha0 transparency, with no visible baked landscape, checkerboard, pedestal or large ground-shadow rectangle. Painted interiors are mostly alpha250–253. Low-alpha residue remains outside the silhouettes:
- V2 raw alpha>0 bounds [0,23,1251,1243); alpha>=8 bounds [44,68,1213,1141).
- Original tree raw bounds cover the whole1254 x1254; alpha>=8 bounds [64,8,1217,1182).
- Bed raw bounds [43,0,1895,824); alpha>=8 bounds [73,173,1836,670).

These alpha thresholds describe source measurements only. No alpha cleanup was applied. Do not derive collision, placement footprint or tight bounds from raw alpha>0. Warm fine leaf fringes remain, and tiny leaf/flower details will merge at game size. Real camera fit and actor/facade/roof overlap still require review.

## Provenance and scope

Original tool files remain under C:/Users/NaurisKrišjānis/.codex/generated_images/01a1586b-b69a-7d30-a6ac-49d746d881c9/:
- Selected tree v2: exec-e916cf68-9a2b-4335-a7c3-001ec6bc96a0.png; SHA256 9ef6f26a024704bbb9eafe8739568a9280a7efe5e243fab7b62a43f52f52ab60.
- Preserved first tree: exec-d4e9f21e-7d75-4e93-bb97-6f4e592581e8.png; SHA256 29c9d90afbb24efdde35c12f9f6604ecb014545b325bd4a83f603cfd385d2d48.
- Bed: exec-e28d81c4-af5e-47b6-ba0e-0646c93e2adb.png; SHA256 3edf26c408f71668d0977151118a2f978c7d1cfa7bd1b39e19e22e7f1a40f2f7.

No stock/downloaded art, CLI/API fallback, bitmap repainting, trimming, resizing, recoloring, compositing, alpha cleanup or PNG re-encoding. No engine/import/test/capture, native renderer, product-code or Git actions. The separate household-interior prop packet is outside this garden folder.
