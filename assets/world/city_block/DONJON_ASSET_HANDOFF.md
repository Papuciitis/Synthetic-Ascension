# DonJon modular source art — 2026-10-19

These three original transparent parts support the approved DonJon implementation. The building's actual wall geometry, entrances, roofs and indoor volumes remain authoritative. The source PNGs are not proof of runtime integration.

## Gate arch

- Source: `donjon_gate_arch.png`, 1536 × 1024 RGBA.
- Camera: steep overhead, a straight screen-horizontal front-facing arch. Do not rotate a complete frontal sprite into east/west elevations.
- Visible bounds at alpha ≥ 128: (165,112) through (1371,912), right/bottom exclusive.
- Suggested ground anchor: (768,912), the midpoint between the two foot baselines.
- At 280 world units visible width, uniform scale is 280/1206 ≈ 0.2322; full canvas is about 357 × 238 world units. Place texture origin at threshold anchor minus scaled source anchor.
- Lower central passage is transparent: approximate aperture x522–1013 at y819. This scale yields ~114 world units clear passage. Adapt to the actual opening; do not stretch across arbitrary widths or imply a blocked path.
- Match the front projection to actual facade ownership. For a north entrance whose outside face is obscured by the camera, use cardinal architectural geometry and reserve this sprite for a matching visible face.
- No gate leaf, floor, stairs or opaque tunnel painting is present.

## Iron cell grille

- Source: `donjon_cell_grille.png`, 1774 × 887 RGBA.
- Visible bounds at alpha ≥ 128: (181,133) through (1594,753), right/bottom exclusive.
- Suggested baseline anchor: (887,753).
- Use 128–160 world units visible width; preserve the original aspect ratio. At visible width128, uniform scale is 128/1413 ≈ 0.0906 and full canvas is about161 × 80 world units.
- This is one blocked partition bay. Place on real wall/blocked partition geometry; do not overlay an intended walkable connector. Never imply a closed cell without a reachable actual doorway.
- Clear alpha is present between each bar.

## Masonry wall bay

- Source: `donjon_masonry_bay.png`, 2149 × 732 RGBA, added after native v2 revealed that the prior face shader flattened the wall material.
- One straight, low, camera-facing limestone wall part, with its own thick coping and three broad courses. No doors, end piers, floor or ground shadow.
- Visible bounds at alpha ≥ 128: (64,128) through (2084,542); alpha ≥ 8 bounds: (63,127) through (2084,542), right/bottom exclusive.
- Suggested baseline anchor: (1074,542).
- At 96 world units visible height, uniform scale96/414 ≈ 0.23188 gives visible width468.4 world units and full canvas498.3 × 169.7. Match actual wall contact and desired height; preserve source aspect.
- Tile the same scale across an authoritative complete wall run. Crop terminal partial spans and chunk slices; do not stretch each wall run or re-anchor the pattern per chunk.
- The source already contains a coping and light/shadow groups. Avoid burying it under broad flat caps or a material-flattening shader. Selective real structural piers remain appropriate.
- This frontal bay is for matching horizontal faces. Keep perpendicular wall rendering coherent rather than rotating the entire elevation into another direction.

## Inspection and limits

All three original PNGs were personally inspected. Their broad stone/iron material groups are useful at gameplay size; retain quiet adjacent wall planes rather than multiplying equally strong decorative modules.

A raw viewer may display dark/gold hidden RGB outside the gate. Actual alpha at exterior and central passage samples is zero. Gate alpha≥8 bounds are (164,111)-(1373,913); grille alpha≥8 bounds are (180,131)-(1594,754). Tiny alpha1 values occur at image edges; no halo above alpha8 extends across the backdrop. Do not key colors or raster-process the originals.

Use existing slate/clay roof textures, walls, lantern, pressure plant, crates and tables for other first-pass needs. No complete scene painting belongs over the generated playfield.

Exact prompts, references, original paths and SHA256 values are in `donjon_assets_manifest.json`. Built-in image generation was used; no CLI/API fallback or raster edits.
