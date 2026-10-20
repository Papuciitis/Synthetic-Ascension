# Medieval gardens and domestic interiors

20 October 2026. Direct human steering to the lead designer, extending the current street benchmark. This governs the production and asset briefs below; the human did not request a uniform square-block city or a universal garden makeover.

## Uneven city development

Keep the uneven medieval city: bent routes, asymmetric plots, different setbacks, patched additions, small leftover corners and varied gaps. A coherent street has believable relationships among entrances, walls, useful ground and neighbors; it need not have straight parallel frontages. Preserve procedural variation and clear horde-combat routes. Do not flatten every shape into a formal plaza, duplicate a perfect block, or pave every patch of grass.

## Tended domestic green space and outer wilderness

Residents should visibly care for suitable green space beside a home. Use a restrained mix chosen for the actual plot and access: a little maintained lawn, a low flower/herb bed, a modest fruit tree, a worn path from the door, and occasional useful household objects. Not every house needs every element, and some plots should remain rough or untended. Let irregular soil and grass edges meet the existing ground naturally.

Tended ground follows real domestic usage and available space. A noncivic flag alone does not identify a dwelling: workshops, passages and small shops can share that presentation branch. Forward meaningful parcel/template use where needed. Retail/service planting may be plausible, but do not turn every noncivic annex into an identical home orchard.

Outside inhabited plots, retain the procedural wilderness: less regular growth, rough grass/scrub, wild shrubs and trees, and terrain-dependent variation. The change from tended to wild should follow occupation and proximity, not a rectangular green stamp or a whole-map grass replacement. Lawn and worn paths belong in the ground presentation; do not bake a complete garden scene into a sprite.

The human subsequently requested distinct lawn/open-wild/neglected backgrounds and flagged S7's blue greenery. The [ground material direction and S7 rework](2026-10-20-ground-material-direction.md) defines the minimal source set and rejects the blue broadleaf carpet. Material appearance and placement must both pass native review.

### Immediate asset support

The asset-only chat **Create tended garden assets for medieval homes**, `01a1586b-b69a-7d30-a6ac-49d746d881c9`, owns two new original sprites and their provenance under `assets/world/domestic_gardens/v1/`:

- A small pruned temperate fruit tree with actual root contact and no surrounding lawn/fence/scene.
- A low irregular flower/herb bed with restrained worn edging, suitable for different house plots.

These fill gaps in the existing inventory, which already has a mature nonfruit tree, ivy/shrub planter, wild shrubs/ferns, tables and crates. Exact anchors, source dimensions, alpha, hashes and fitting ranges must accompany the new assets. The production owner integrates them after lead inspection. No asset approval, runtime fit or completed garden is implied by starting generation.

The asset chat has no engine, gameplay-code or Git lane. Production alone owns game edits and monitored engine runs, including the ongoing recovery after reported hard freezes.

## Ordinary houses must read as homes

The human dislikes empty-cell interiors and the new pale white-grey brick treatment, and prefers the older harsher masonry's character. Treat this as an unfinished domestic-art requirement, not a request to undo doorway/wall-continuity fixes or restore redundant inner shells.

Root personally inspected the genuine irregular clay-roof domestic cutaway in [house repair v1](reference/2026-10-19-house-wall-repair-v1/seed-16102026/frontage-irregular-entered-960x540.png). It has a broad empty floor and uniformly pale perimeter. The earlier [portal-v3 view](reference/2026-10-19-city-irregular-portal-v3/seed-16102026/frontage-irregular-entered-960x540.png) also shows the emptiness, but its detached wall geometry is superseded and must not be restored.

The old [searchable-building interior](concepts/2026-10-18-city-directions/current-game-captures/searchable-building-interior-960x540.png) demonstrates stronger stone/mortar character. It is a civic/security building, not proof of an older furnished dwelling. Likewise, the historically named `house-wall-repair-v2/moving-reduced-211` sample has a slate civic arcade exterior; do not use that label as a household classifier.

### Masonry direction

The original stone sources still exist. The actual [horizontal wall-kit source wall34_10](../../assets/world/walls/kit/wall34_10.png), vertical `wall34_05` and companion kit pieces retain rough face variation, substantial mortar, worn edges and a much darker lower face. They remain loaded by the [visual catalog](../../core/systems/world/chunks/ChunkBlockVisualCatalog.gd:41). The current [city stone shader](../../scenes/world/buildings/city_stone.gdshader:8) remaps source luminance into a narrow pale cool range, suppressing much of that character. The [renderer](../../core/systems/world/chunks/ChunkBlockRenderer.gd:40) shares this material for city-stone batches. This is a material-presentation issue as well as missing furnishings; generating another pale wall bitmap is not the first remedy.

For the domestic packet, preserve or reinterpret the original roughness, stronger joints, earth/cool-grey variation and contact depth. Allow modest patch plaster and timber accents where useful, rather than making every wall a bright clean strip. Keep floors quieter than walls and actors. Do not globally revert all reviewed civic/S3 architecture or change physical wall cells merely to change the material. Scope the presentation to real building use/coverage, including actual interior partitions when present.

The existing under-roof variant identifies internal partitions rather than every perimeter wall visible in a cutaway. Using it alone would miss the domestic envelope the human is seeing. Keep real envelope geometry and scope the material to the dwelling's underlying wall surfaces or an equivalent explicit interior-face adapter; its painted outside frontage can retain its own presentation.

### First domestic interior packet

After the current exterior checkpoint, complete one real ordinary dwelling at the existing camera before expanding to another district family. Establish a former household purpose through a few fitted groups: a hearth/cooking edge, table or work corner, sleeping/storage side. A tiny one-room home can remain one room; it still needs recognizable use. Larger existing room layouts should retain their partitions and give different rooms a reason to exist.

Use existing tables/crates where they meet the quality target; identify a precise missing hearth, bed or cupboard module before requesting further images. Do not replace the empty cell with random clutter or identical furniture in every house. Derive seeded arrangements from actual usable floor, doors and wall spans. Keep entries, through-routes, combat space and floor loot readable. Visible solid furniture must agree with its existing gameplay/collision/cover contract; do not invent false doors or interaction/loot promises.

The inventory confirms two specific missing purpose cues: a human bed and a household cooking hearth. The Hub's named bed is a pet cushion and its forge is an exterior building. After closing the garden handoff, the same asset-only chat is assigned a simple timber cot and low stone cooking hearth, separately under `assets/world/domestic_interiors/v1/`. These two props complement existing table/storage pieces; they are not authorization for a large generic furnishing catalogue. Originals, contact/footprint measurements and provenance must be inspected before integration, and runtime behavior remains the production owner's responsibility.

Respect the difference between a dwelling, shop/workshop, civic security hall and DonJon. Household dressing is not a global treatment of every roofed volume.

## Review requirements

The next outdoor review must retain uneven streets and show tended near-home ground plus nearby genuinely wild ground, with natural actor/foliage context. Judge the new fruit tree and bed at native small size, their real contact/overlap and a second natural fitting case. A garden asset alone does not establish correct planting or actor visibility.

The domestic review must show the same genuine dwelling before/after at960 and1280, the whole cutaway, actual entry/exit, roof restoration, reachable clear routes and deterministic reload. State its template/building identity and distinguish visual dressing from physical changes. Preserve existing wall/roof fixes. Keep the already requested staged tree/enemy/pickup visibility and later district work explicit; these have not been silently completed by this direction update.
