# Wardstone and Exit Rite v2 provenance — 18 October 2026

Generated as original raster artwork with the built-in `image_gen` tool, one generation call per asset, `transparent_background=true`. Both first-pass outputs were retained for actual-Game integration. No image edits, resizing, cropping, alpha cleanup, downloaded artwork, engine import or shared code changes were performed for this asset handoff. Project PNGs are byte-identical copies of their generated source files.

These are source-art candidates pending the coordinator's actual-Game scale, terrain and actor-overlap review; source inspection alone does not establish visual acceptance.

## References inspected before generation

- `docs/art/reference/2026-10-18-objective-rework-prototype/breach-context-normal.png`
- `assets/world/objectives/painted/breach_open_v2.png`
- `assets/world/objectives/painted/breach_sealed_v2.png`
- `assets/world/objectives/painted/wardstone_v1.png` and `exit_rite_v1.png` for identity continuity.

These were visual references only, not edit targets or image inputs to generation. The grey-olive paving, coarse clusters and dark edges informed the prompts. The new prompts explicitly specify **top-right illumination and southwest internal shading**, correcting the old breach prompt's upper-left instruction.

## Wardstone

Project: `assets/world/objectives/painted/wardstone_v2.png`

Source: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f9d-d1e6-7722-8970-b728179a477b/exec-5e0e12d9-9628-456e-a0b7-63d903c56420.png`

SHA-256, source and project copy: `76B64C408AE7EC0F4B6C61B0082FBFFE56345B9FC0D61654D8CBEDF781A23BB5`.

- Dimensions: **1024 × 1536**, RGBA.
- Raw alpha > 0 bounds: **[153, 85, 1008, 1512)**.
- Alpha ≥ 16 bounds: **[169, 121, 857, 1387)**.
- Alpha ≥ 128 occupied bounds: **[170, 122, 856, 1386)**; occupied fraction **(0.669922, 0.822917)**.
- Fully transparent pixels: **1,039,547**. Partially transparent pixels: **533,317**. The generated output has no alpha-255 pixels; most solid artwork is near opaque. This alpha is preserved exactly.
- Proposed contact anchor from the visible front base vertex: source pixel **(512, 1382)**, normalized **(0.500000, 0.899740)**. The pixel alpha there is 249; the next lower antialiased outline falls to alpha 10 at y=1384. This is an upright base-foot anchor, not the full-canvas or alpha-bounds center.
- The split obelisk, incomplete iron halo and two coarse seated braces remain recognizable. The halo has transparent negative space and the narrow teal seam supplies the only strong hue accent.
- Visible silhouette has clear margins. Very low-alpha residual pixels extend beyond the visible object; the raw alpha bounds must not be mistaken for the occupied silhouette.

Exact generation prompt:

Use case: stylized-concept. Asset type: one original transparent 2D world-object sprite, WARDSTONE VERSION 2, for Synthetic Ascension, a hand-painted top-down urban occult horde game. Create a compact civic checkpoint marker: one modest upright SPLIT OBELISK made from two broad grey-olive stone slabs, a very narrow restrained teal seam between them, and one simple incomplete dull-iron halo behind the upper split. Retain this split-obelisk/halo checkpoint identity, but simplify it into a few bold shapes. Two broad practical iron braces seat the stone into a low, shallow, slightly irregular polygonal stone footing. The base has obvious broad contact surfaces, not a tall decorative pedestal. No miniature jeweled fasteners. Camera: steep overhead orthographic game view from above; clearly show the tops of the stone, halo and base, with compressed vertical depth, rather than a frontal product elevation. Style: broad hand-painted 2D shapes with coarse stone clusters and deliberate charcoal edge separation, matching muted grey-olive city paving and small strongly outlined human game sprites. Not a realistic 3D render. Readable at only 80–110 pixels occupied height. Palette: dusty grey-olive stone #626050, deep charcoal #211f20, dull umber iron, tiny muted teal core accent; little or no brass, no bright gold. Lighting is fixed from TOP RIGHT; internal contact shading falls southwest. No cast shadow detached from the object, no floor or terrain patch. Composition: complete centered sprite on a portrait transparent canvas with generous clear margins on every side; base front contact foot near canvas normalized x=0.50,y=0.89, tips safely inside the top margin. All object pieces attached and all silhouette edges complete. Actual transparent alpha outside the sprite and through the halo negative space. No scenery, ground plane, halo glow, bloom, particles, smoke, magic circle, UI, progress arc, text, symbols, checkmark, banners, cloth, jewelry, fantasy filigree, cathedral ornament or watermarks. This is weathered practical stone-and-iron city infrastructure, with only the tiny split as its occult accent.

## Exit Rite

Project: `assets/world/objectives/painted/exit_rite_v2.png`

Source: `C:/Users/NaurisKrišjānis/.codex/generated_images/01a14f9d-d1e6-7722-8970-b728179a477b/exec-e74bab6d-7f1c-4800-9e5b-ec80b81e5fb6.png`

SHA-256, source and project copy: `85869E467E0D4A65750E9767814EE53001BDCDAB430F84AED2DE024D0A8A3FB2`.

- Dimensions: **1536 × 1024**, RGBA.
- Raw alpha > 0 bounds: **[0, 0, 1498, 987)**.
- Alpha ≥ 16 bounds: **[137, 169, 1398, 829)**.
- Alpha ≥ 128 occupied bounds: **[137, 170, 1398, 828)**; occupied fraction **(0.820964, 0.642578)**.
- Fully transparent pixels: **1,105,736**. Partially transparent pixels: **467,128**. The generated output has no alpha-255 pixels; the alpha is preserved exactly.
- Proposed ground-footprint center from the low frame's visible footprint: source pixel **(768, 500)**, normalized **(0.500000, 0.488281)**. This intentional virtual ground point lies in the hollow opening between the two feet, rather than at the bottom edge of the sprite.
- Center aperture at **(768, 512)** and near-side mouth at **(768, 800)** both have **alpha 0**. The terrain can show through; there is no painted black fill, large floor patch, circular channel zone or UI ring.
- The broad low U-shaped frame retains a threshold identity while showing predominantly top surfaces and short projected front faces. It is intended to remain below actor silhouettes. The full circular channel area comes from native drawing, not this artwork.
- Visible object margins remain clear. Isolated alpha-1 residual pixels make the raw bounds touch the canvas edge; use the visually occupied alpha ≥ 128 extent for placement metadata. No alpha was removed or altered.

Exact generation prompt:

Use case: stylized-concept. Asset type: one original transparent 2D world-object sprite, EXIT RITE THRESHOLD VERSION 2, for Synthetic Ascension, a hand-painted top-down urban occult horde game. Create a genuinely overhead low civic containment threshold with a hollow opening: two broad short grey-olive stone footings connected across the back by a stout low curved stone-and-dull-iron lintel/arch, so from above its footprint reads as an open U-shaped threshold. The large center and near-side mouth are EMPTY TRANSPARENT NEGATIVE SPACE where the game's own terrain will show through. The far connector is low, the sides are short, and all broad top surfaces dominate; show only tiny projected front faces. This must feel like a compact ground fixture or recessed exit frame seen steeply from above, not a tall frontal doorway, miniature cathedral façade, monument, shrine or standing horseshoe product render. Retain a recognizable threshold/arch family through the two feet and broad connector, but no high spire or decoration. Its actual channel-zone paving will be drawn by the game around this sprite: do NOT paint a huge floor, circular pad, ring or terrain patch. A few coarse interlocked blocks and broad iron bands, at most two tiny restrained amber/teal insets; practical city containment hardware. Camera: steep overhead orthographic game view, roughly 70 degrees down toward the ground, rear at image top and open mouth at image bottom; compact broad footprint centered at normalized x=0.50,y=0.50. Style: restrained hand-painted 2D game sprite, broad simple shape clusters, coarse chipped stone and strong charcoal edge separation matching muted grey-olive street tiles and small outlined game characters. NOT a realistic 3D render. Readable at 80–110 pixels wide. Palette grey-olive stone #626050, charcoal #211f20, dull umber iron, almost no brass, no bright gold. Fixed light from TOP RIGHT; compact internal/contact shading toward SOUTHWEST, no external shadow or ground plane. Entire silhouette and footing complete within generous transparent margins. True alpha transparency outside the object and through the hollow center/open mouth; never fill the aperture with black, white, checkerboard or glow. No environment, huge painted floor, circular boundary, UI, progress arc, text, checkmarks, bloom, smoke, flames, banners, cloth, jewelry, ornamental glyphs, fantasy filigree or watermark.

## Inspection and handoff

Both actual source PNGs were loaded with `view_image` after generation. Dimensions, RGBA mode, alpha histograms and threshold bounds were inspected read-only; source and project hashes were checked after copying. Bounds use left/top-inclusive, right/bottom-exclusive pixel coordinates. Proposed anchors are visual placement proposals, to be tested on moss, paving and front/back actor overlap in the actual Game.

No variants were rejected or edited in this handoff. No `.import` settings existed for these new names when selected; the coordinator owns their import limits, mipmaps, art preloads, placement metadata, state integration and native acceptance.
