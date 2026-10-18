# Relay, Vigil and Wager candidate artwork — 18 October 2026

Generated with the built-in `image_gen` tool, exactly one generation call per asset. These are **candidate source sprites**, pending import and actual Game visual acceptance by the coordinator. No v1 file was replaced.

All three generated PNGs were copied byte-identically into the project, preserving their original alpha. Pillow was used only to read dimensions, alpha statistics/bounds and hashes; it did not edit, resize, crop, composite, clean or save images. No engine, helper/code or Git mutation was performed for this asset task.

## Reference inspection and direction

Inspected before generation:

- `docs/art/reference/2026-10-18-objective-rework-prototype/breach-context-normal.png` (the current actual Game context capture).
- `assets/world/objectives/painted/breach_open_v2.png` and `breach_sealed_v2.png`.
- `relay_v1.png`, `vigil_v1.png`, `wager_v1.png`.

The previous forms supplied identity references only. The new prompts explicitly replace ornament with broad civic machinery, muted grey-olive stone, dull umber iron, very limited brass and small identity cores. **Lighting is top right, shading southwest**, matching `WorldDepthStyle.gd`; the earlier breach provenance's upper-left-light wording was not copied. Generation was new-image mode, so no edit target or image reference paths were submitted to the tool.

The project copies were individually reopened and visually inspected. Relay has two chunky receiver prongs and parked shutter plates; Vigil is a flat plate with four broad inward braces; Wager retains two broad pans on solid stirrups, a level beam and a simple workbench. No image contains text, an interaction ring or a floor patch. Source inspection does not establish final contact, depth, state readability or player occlusion in the Game.

## Measured metadata

Bounds are `[x0,y0,x1,y1]`, right/bottom exclusive. Alpha thresholds separate the material silhouette from nearly invisible generated edge noise; they do not define a physical anchor.

| Asset | Canvas / mode | Alpha range | Alpha >= 1 bounds | Alpha >= 16 bounds | Alpha >= 128 bounds |
| --- | --- | --- | --- | --- | --- |
| Relay v2 | 1536 × 1024 / RGBA | 0–254 | [0,23,1506,983] | [312,194,1224,825] | [313,194,1224,824] |
| Vigil v2 | 1536 × 1024 / RGBA | 0–254 | [262,9,1432,1008] | [264,105,1272,918] | [265,106,1271,918] |
| Wager v2 | 1402 × 1122 / RGBA | 0–255 | [37,22,1376,1122] | [86,84,1316,1034] | [87,85,1315,1033] |

All four corner pixels of every image have alpha 0. Relay has 1,160,055 fully transparent pixels; Vigil 970,769; Wager 880,116. Relay and Vigil have no alpha-255 pixels (their maximum is 254), which is a property of the unmodified generated files. Wager has 1,484 alpha-255 pixels. Main material silhouettes remain fully inside margins; very faint alpha < 16 traces reach Relay's left edge and Wager's bottom row. Those traces were preserved rather than removed through image editing. Check for any faint edge halo on moss and pale paving during the native integration.

### Proposed placement — visual estimates, not automatic alpha pivots

These are starting points for coordinator-owned placement metadata. They require actual Game contact/overlap checks.

| Asset | Proposed source contact point | Normalized contact anchor | Alpha >= 128 occupied extent (normalized) | Reason |
| --- | --- | --- | --- | --- |
| Relay v2 | (768,764) | (0.500000,0.746094) | (0.593099,0.615234) | The center/front contact of the broad civic base, below the lens and parked shutter track; do not anchor to the top prongs or automatically to y=824. Treat as a low upright receiver. |
| Vigil v2 | (768,512) | (0.500000,0.500000) | (0.654948,0.792969) | Center of the embedded plate's actual ground footprint. The lens is slightly above that point; an opaque-bottom pivot would falsely shift the low plate north. Keep on the ground layer. |
| Wager v2 | (701,1000) | (0.500000,0.891266) | (0.875892,0.844920) | Central workbench contact between the two practical feet, rather than the beam, pans or lowest isolated alpha. Upright base contact is appropriate. |

Suggested initial occupied sizes for native inspection: Relay 83 world px high (about 120 px wide); Vigil about 160 world px wide; Wager about 110 world px high (about 143 px wide). These are presentation proposals only; all gameplay origins and exact radii stay unchanged. In particular, inspect the existing code-native Relay shutter, Vigil brace and Wager spent-tray details against these new base contacts rather than moving mechanic origins.

## Relay v2

Project: `assets/world/objectives/painted/relay_v2.png`

Generated source: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f9d-9c5f-7671-8c65-41f5de45162e/exec-333b7fab-a04f-4aed-a6b9-7a6110b18a34.png`

SHA-256: `61dc31d9b615445fe6af26be021cb87926fbae7257fd573f2585e67e912c5cc8`

Exact generation prompt (`transparent_background=true`):

```text
Use case: stylized-concept.
Asset type: ONE transparent 2D world-object game sprite, district RELAY RECEIVER v2, for Synthetic Ascension, a muted overhead urban occult horde game.
Subject: a compact broad municipal receiver station on a LOW practical chipped civic-stone base. Exactly TWO short CHUNKY iron receiver prongs curve inward on either side of one small recessed dull purple glass lens. Prongs are broad solid practical supports with a simple chunky silhouette, NOT thin antennas, swords or jewelry. Show a clear wide horizontal shutter track with its two sturdy shutter plates parked apart, ready to slide across the lens. Few large bolts. The lens is a small identity accent, NOT a large magic orb. A single receiver only.
Camera: steep overhead orthographic game view, visible top planes, little front wall. This object is a low street machine, not a standing shrine. Upright receiver structure remains readable at only 80–100 pixels occupied height. Broad stable base contact approximately at the lower central portion of the sprite. Entire isolated silhouette is inside generous transparent margins.
Style: coarse restrained hand-painted 2D game sprite; broad simple painted shape clusters, bold dark edge separation, limited weathering texture. Match old grey-olive street paving and compact strongly outlined player sprites. NOT a photorealistic object, 3D render, collectible statue, ornate reliquary or fantasy altar.
Palette/materials: muted grey-olive stone #626050, charcoal #211f20, dull umber iron, a tiny amount of worn dull brass at fasteners, a SMALL dim desaturated purple lens. Matte low-contrast broad material surfaces, no bright gold trim.
Lighting: consistent light from the TOP RIGHT, compact shading toward the LOWER LEFT / southwest, contained within the object. No large cast-shadow patch or halo.
Actual fully transparent background outside the object and through genuine negative gaps. No floor, circular paving patch, environmental ground, scenery, backdrop, bloom, emission glow, smoke, cloth, hands, chains, fine wires, filigree, radial ornament, runes, lettering, text, watermark, UI, progress ring, interaction boundary, checkmark, other props or characters. No top-left key light.
```

## Vigil v2

Project: `assets/world/objectives/painted/vigil_v2.png`

Generated source: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f9d-9c5f-7671-8c65-41f5de45162e/exec-11a80a98-1b86-4511-b53c-4cf464f62a89.png`

SHA-256: `aa6eca67b97819bf41fcf885064ccceb35b217278bc98dbd8d74dddc262864a8`

Exact generation prompt (`transparent_background=true`):

```text
Use case: stylized-concept.
Asset type: ONE transparent 2D ground-object game sprite, WARD VIGIL ENGINE v2, for Synthetic Ascension, a muted overhead urban occult horde game.
Subject: a LOW FLAT embedded municipal ward-machine plate. A compact roughly octagonal grey-olive civic-stone frame encloses a shallow quiet charcoal central plate with a SMALL dim desaturated blue central lens. Four broad short practical iron braces point inward across the plate; they are flat mechanical pieces, not tall horns. A few large edge clamps and bolts. Mostly broad simple stone and dark iron masses. The device is a practical flat hold-engine built flush with the street, not an ornate bowl, pedestal, standing obelisk, shrine or altar. Show no surrounding paving: the plate's own contact footprint alone.
Camera: steep near-overhead orthographic game view; clear top planes, extremely shallow sides, almost no front wall. Wide compact horizontal footprint, about 1.5 times wider than its projected depth. The contact-footprint CENTER is the image center. Silhouette must remain clear at 100–110 pixels occupied width. Entire object inside generous transparent margins.
Style: coarse restrained hand-painted 2D game sprite with broad simple painted shape clusters, bold dark edge separation and sparse large chips. Match grey-olive weathered street tiles and compact strongly outlined player sprites. Not realistic product photography or a realistic 3D render. Low detail density.
Palette/materials: muted grey-olive stone #626050, charcoal #211f20, dull umber iron, VERY LIMITED worn dull brass fasteners, tiny cool blue identity accent in the shallow lens. No bright gold trim, no powered blue pool or magical basin.
Lighting: TOP RIGHT key light, compact material shading toward LOWER LEFT / southwest, within the object. No external shadow patch, bloom, aura or glow.
Actual fully transparent background outside the compact engine footprint. No floor patch, ground plane, scenery, background, tall prongs, horns, standing pillars, cloth, hands, chains, fine filigree, circular ritual ornament, letters, runes, text, watermark, UI, interaction ring, progress arc, boundary, checkmark or other props. No top-left key light.
```

## Wager v2

Project: `assets/world/objectives/painted/wager_v2.png`

Generated source: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f9d-9c5f-7671-8c65-41f5de45162e/exec-252a0918-dcbb-4b5d-bba3-d9941fc75746.png`

SHA-256: `e4ee73ac9bc5cf2c7eabe2aa805c001f8a79f0b18b8e52d5eae289e08cbc613a`

Exact generation prompt (`transparent_background=true`):

```text
Use case: stylized-concept.
Asset type: ONE transparent 2D world-object game sprite, WAGER BALANCE v2, for Synthetic Ascension, a muted overhead urban occult horde game.
Subject: an immediately recognizable TWO-PAN BALANCE mounted on a COMPACT PRACTICAL STONE WORKBENCH. One sturdy short upright post supports a simple LEVEL horizontal beam with two THICK straight arms. Two broad EMPTY shallow weighing pans, one on each side, hang from simple chunky solid stirrup supports; NO fine chains or wires. Keep open negative-space gaps around the upright, beam and pans so the scales silhouette is unmistakable when small. No hand holds an orb: this is practical civic machinery. The workbench is one broad chipped low rectangular stone slab on short solid feet, not an ornate plinth, shrine or fantasy altar. Show a simple closed collection drawer built into its front, no coins or reward items.
Camera: steep overhead orthographic game view, top planes visible, little front wall, consistent with top-down grey-olive street paving. Upright scales rise modestly above the workbench, with base-contact point at the central foot of the low workbench, toward the bottom of the sprite. Entire object inside generous transparent margins. Readable at only 100–110 pixels occupied height.
Style: coarse restrained hand-painted 2D game sprite, broad painted masses and deliberate dark outlines, a few large worn edges, low tiny-detail density. Match compact strongly outlined player sprites and weathered city infrastructure. NOT a realistic 3D render, product photo, jewelry showcase, statue or fantasy collectible.
Palette/materials: muted grey-olive stone #626050, charcoal #211f20, dull umber iron; a broad quiet worn ivory inlay on the center post or beam provides one clear identity accent, plus a TINY dim amber lens. Very limited dull brass at practical fasteners. Matte paint and restrained contrast, no bright gold.
Lighting: TOP RIGHT key light; compact shade toward LOWER LEFT / southwest, contained on the object. No broad cast-shadow floor patch, halo, bloom or emission.
Actual fully transparent background outside the silhouette and inside open negative-space gaps. No surrounding floor, ground patch, backdrop, scenery, hands, figures, cloth, fine chains, wires, horns, sunbursts, filigree, ornate symbols, lettering, text, watermark, UI, ring, boundary, progress arc, checkmark, floating coins or extra objects. No top-left key light.
```

## Acceptance limits

Only the source sprites, original copy integrity, actual alpha and proposed contact points were inspected here. No native capture, final material approval, frozen/grayscale state acceptance or 80–110 px Game readability claim is made. Existing code supplies state hardware; complete/spent readability must be judged with that production hardware and the real player/terrain. The coordinator owns any additional state variants, shared helper integration and final native verification.
