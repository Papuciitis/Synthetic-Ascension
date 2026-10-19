# Streetscape asset expansion

The human explicitly authorized generating additional art and expanding toward the approved Mediterranean/medieval/municipal-industrial concept. This is a small reusable set, selected for actual integration into the existing block rather than a new whole-scene concept.

All five selected images were created with the built-in `image_gen.imagegen` tool. No external API/CLI, stock/downloaded art or local raster repaint was used. Source PNG bytes were copied unchanged. The implementation chat owns runtime scaling, tint, placement, cover behavior and gameplay checks.

## Selected runtime names

| File | Source size | Role and starting placement |
| --- | --- | --- |
| [temperate_tree.png](temperate_tree.png) | 1254×1254 RGBA | Broad leafy corner tree. Root anchor `(650,1170)` in the actual 1254-square source. Start around 280 world pixels wide; place its small root footprint on an eligible blocked civic corner and keep actors/doors clear. |
| [planted_corner.png](planted_corner.png) | 1536×1024 RGBA | Cleaned v2 limestone trough with ivy/shrub. Stone-ground anchor about `(800,870)`, not the lowest trailing ivy pixel. Start at up to 160 world pixels wide, clamped to the valid wall/corner span. |
| [domestic_awning.png](domestic_awning.png) | 1536×1024 RGBA | Linen/sage window awning with timber/iron mount. Approximate back-rail anchor `(720,160)`. Fit one valid domestic window span, initially 140–180 world pixels wide, retaining a shallow projected depth compatible with the frontage. |
| [wall_lantern.png](wall_lantern.png) | 1086×1448 RGBA | Shielded iron/amber civic fixture. Wall-plate anchor approximately `(200,440)`; glass/light center is a separate point. Start around 48 world pixels total source height, replacing the primitive sconce. |
| [worn_setts.png](worn_setts.png) | 1254×1254 RGB | Angular worn street material. Apply through the existing world-coordinate road mask and restrained value/contrast treatment; keep the accepted irregular road outline. |

These anchors are art starting points, not collision shapes. Exact source dimensions, source filenames, hashes and normalized anchors are in [streetscape_assets_manifest.json](streetscape_assets_manifest.json). The tree and selected planter were copied/integrated by the implementation chat; the other three were delivered by both chats with byte-equivalence verified. Their canonical names above are the consuming names agreed with implementation.

## Variants and provenance

- `planted_stone_trough.png` is the original planter generation, retained as an alternate. The selected `planted_corner.png` is the subsequent built-in cleanup edit. Do not load both as duplicate corner objects.
- `street_setts.png` is an exact-byte alias of selected `worn_setts.png`, retained from the simultaneous handoff. It is not another material or an additional generated asset.
- [STREETSCAPE_GENERATION_PROMPTS.json](STREETSCAPE_GENERATION_PROMPTS.json) records the exact five generation prompts and the planter cleanup prompt. Originals remain under `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f56-352f-79b2-b401-d8c10d6ba199/` with filenames registered in the manifest.

The isolated art uses warm upper-right daylight and cool shaded planes. It has more material detail at source resolution than should be visible at gameplay size; judge native 960×540 integration before sharpening or adding outlines.

## Alpha, ground contact and cover

The previews can show colored RGB in fully transparent areas. Read-only RGBA sampling confirmed that the broad apparent green/brown backdrop around both planter versions has alpha zero in the sampled regions. Selected tree/planter compositing in actual `ground-review-08` images also has no broad baked green halo. Preserve generated alpha and normal filtering; do not treat hidden RGB as a new ground effect. Natural antialias pixels retain partial alpha.

Keep the tree/root, planter stone base and awning wall supports anchored to eligible generated geometry. A large canopy is visual coverage, not a new obstacle footprint. Optional awnings/fixtures should be skipped where a suitable window/wall span is absent. Do not dress only the captured coordinates. Preserve normal characters and actual roof cutaways; tie wall-mounted awning/lantern cover to the same real frontage ownership. Foliage needs its own sensible static/occlusion behavior rather than vanishing merely because a neighboring roof cuts away.

Use the lantern's physical glass as the light source and keep any runtime pool local and subordinate in daylight. Generate foliage cast shape from actual alpha using correct full-texture/atlas UV interpretation, with scene-consistent direction and appropriate interior clipping.

## Road material limit

Seamless repetition was requested in the prompt; that alone is not certification. Source edge mean absolute differences are approximately 17–19 RGB levels. Inspect an actual repeated region and a shared road/chunk join after integration; keep the former material as a fallback if needed. Compress fine contrast instead of letting source mottling and every sett joint dominate actors. A square discontinuity around x428 in the small `ground-review-08` road edge was flagged separately as a possible surface-piece join; it should not be explained as intentional old-city irregularity.

## Review state

The lead personally inspected all five selected generated images, original/cleaned planter and three native small `ground-review-08` views. The tree/planter make that intermediate scene substantially more temperate and inhabited, and the new wall outlet/flush drain removes the rejected floor L. Awning, lantern and setts require the next integrated native view before scene-level art approval. No engine run or runtime-code edit was made in the designer chat.

Use the complete next scene, relevant cutaway/overlap and a populated sample to assess the combined result. Stop further catalogue expansion this round until these five pieces have been judged together in the actual game.
