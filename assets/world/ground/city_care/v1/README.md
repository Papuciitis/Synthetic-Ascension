# City-care ground materials v1

20 October 2026. Exactly two original opaque material masters, each generated with one built-in image_gen call. Their PNG bytes are preserved unchanged. No new recolours, variants, source editing or integration.

Lead decision: KEEP both provisionally for native integration; no regeneration needed before native review. The lead viewed both originals and320px repeats, reports independent160px/wrap review, independently verified source hashes, and handed exact paths to production. Retain the slight dry olive lawn character, broad repeated mottling and moss grit visible at320px as review limits. This is source acceptance only, without runtime/aesthetic acceptance or seamless certification. This bounded asset packet is closed; no extra grounds or furniture were added.

| Source | Actual size / format | SHA256 |
| --- | --- | --- |
| [cared_lawn.png](cared_lawn.png) | 1254 x 1254 RGB, opaque | f255b16e580b7b0c88800fd392983af7882ff2ae2c77250f9856fa8954812082 |
| [damp_moss_soil.png](damp_moss_soil.png) | 1254 x 1254 RGB, opaque | f18b25c81ba1e859be95195d857ce495c6433f66d72e3a1d2d3016b7eae562fd |

Both decode as RGB with no alpha channel or transparency entry. The entire square is continuous material; neither encodes a lawn island, perimeter, border, room, prop or scenery.

Exact prompts/tool arguments/source paths: [prompts.json](prompts.json). Measurements, review limits and QA hashes: [manifest.json](manifest.json).

## Intended use

Cared lawn is short fine irregular olive-green growth with modest straw/worn thinning. It is intended for tended household greenspace, not grass02-style neglected undergrowth or uniformly manicured modern turf.

Damp moss/soil is fine low olive/brown-green moss interwoven with neutral damp earth and small grit. It replaces the rejected blue/cyan/purple broad-leaf language, without introducing a water scene or large plant rosettes. Existing grass01, dirt and mud remain reuse candidates; these sources do not direct their global replacement.

Both were personally viewed against accepted concept08, grass01/02/dry, dirt01, mud_wet01, rejected moss01 and the existing native S7 exterior. Exact paths/roles are in the manifest. These were support/negative references, not edit targets.

The two masters share fine surface scale and subdued earthy value. Ungraded mean RGB is about(82.17,86.02,42.68) for lawn and(79.02,74.06,41.69) for moss. Mean Pillow luma is79.93 and71.85 respectively: moss is about8 levels darker and somewhat grittier. These source measurements do not predict graded native appearance or establish actor contrast.

## Repeating QA

Six separate derivative previews are in [qa/](qa/README.md), excluded from engine import by qa/.gdignore. They are QA only; the two top-level PNGs are the material masters.

For each source:
- Native wrap: 768 x768, composed from four unscaled384px source corners. Joins meet at the image center, so source-pixel edge transitions can be inspected without rescaling.
- Repeat320: 3 x3 tiles, each reduced to320px, giving960 x960. The current read-only WorldArt vegetation guide repeats at320 world pixels, five64px cells.
- Repeat160: the same3 x3 layout with160px tiles, giving480 x480, representing a0.5 screen/world scale assumption.

The previews use direct periodic repeats with Pillow LANCZOS reduction only where stated. No seam blending, rotation, tint, source repair, grading, game shader or material-array preprocessing was used. This is a source QA approximation, not a native scene render or confirmed current camera zoom.

All six previews and both masters were personally inspected. No strong rectangular tile boundary dominates the sampled320/160 repeat views. That observation does NOT certify seamlessness:
- Lawn retains recurring wispy diagonal blade flow and a faint low-frequency wear cadence in the3 x3 field. The source is fine and wiry; cared-lawn character and warmth still need lead/native judgment.
- Moss retains small source-pixel edge-structure discontinuities, especially across the native horizontal wrap. Repeated mottled soil/grit clusters remain identifiable; variation is somewhat stronger than lawn.

Edge metrics are descriptive only. Native left-right/top-bottom wrap RGB mean differences are16.59/14.50 for lawn,18.36/18.41 for moss. At320px tiles they are11.78/10.71 and14.03/15.84; these are close to ordinary local texture variation but are not a mathematical seam match or acceptance threshold. Full measurements are in qa/measurements.json.

## Production ownership and limits

Production owns irregular patch boundaries, world UV placement, material slot mapping, blending, shadows/lighting, tint, preprocessing/cache and actual S2/S7 review. Do not stamp these squares as lawn islands, infer collision from the image boundary, or load QA images as materials. A full-surface texture has no object contact pivot; source footprint is[0,0,1254,1254), UV origin(0,0).

The existing WorldArt.gd was read only to identify its320-world-pixel vegetation repeat. No game code, WorldArt entry, original ground file, material array, import settings or cache was edited. No Godot, engine import/test/capture, native renderer or Git actions were performed. A correct opaque PNG and these QA observations do not confer aesthetic/runtime acceptance.

## Original tool sources

Original files remain under C:/Users/NaurisKrišjānis/.codex/generated_images/01a1586b-b69a-7d30-a6ac-49d746d881c9/:
- Lawn: exec-3d447716-4b3b-465e-b617-23e155e16274.png.
- Moss/soil: exec-516ca1e9-d178-4e88-8891-b8e3cf81cf9d.png.

No stock/downloaded art or CLI/API fallback. The originals were copied byte-for-byte, not resized, retouched, recoloured, repaired or re-encoded. Only separately named QA derivatives were assembled/scaled as requested.
