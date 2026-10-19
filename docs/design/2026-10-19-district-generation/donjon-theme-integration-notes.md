# DonJon integration with the full district catalogue

2026-10-19. Read-only supporting review. This is design guidance for the common
base and later district-family work, not implemented theme coverage or new engine
verification. No production edits, Godot runs or Git mutations were made for these
notes. The base-building chat retains the production/engine/Git lane.

## Recommendation

Share material quality, projected depth, source scale and restrained lighting
across the city. Keep a dungeon's enclosing plan, functional rooms, reward owner
and roof ownership distinct. Theme identity should modify a recognised dungeon
family; it should neither make every ordinary building a dungeon nor copy the
same three-wing compound into every district.

Use the [district contract proposal](02-generation-contracts.md),
[complete matrix](01-district-matrix.md), [theme inventory](../2026-10-19-segment-visual-style-inventory.md)
and [current concept brief](../../art/concepts/2026-10-19-segment-directions/COMMON_BRIEF.md).
The accepted dungeon implementation is a bounded first prototype; long roof bands,
sparse courts and room dressing remain refinement. New theme plates still require
their own visual inspection; reading their job descriptions is not art acceptance.

## Current integration seams

| Observed source | Consequence for future work |
| --- | --- |
| `SegmentProcBuilder` selects `_theme` from the original attempt seed; `DistrictPlan` stores `theme_id`. `SegmentThemeData.apply_to_chunk_manager` copies terrain/tint/budgets but not its `district_family` identity. | Forward the already selected identity through instance context before streaming. Do not reroll a theme using the manager's mixed/retry world seed: S4/6/7/8/9 alternatives can change. |
| `DungeonLayout.build` returns authoritative walls, doors, rooms, court and roof metadata. It takes no material profile. | Keep topology independent of presentation. Resolve any seeded visual choices once in complete-site coordinates; do not consume the carver RNG or reroll per slice. |
| `DungeonBuilding.attach` has no theme/profile argument. It uses the shared `CityBlockKit` texture cache, original dungeon masonry/gate/grille art, slate wings, a clay service cap and fixed lamps/planting. | The ordinary kit's eligibility gate does not control dungeon coverage. A future optional profile should adapt this existing presenter, not attach a second ordinary-house kit over it. |
| `DungeonRoof.configure_slice` supplies fixed slate/clay material settings and owns clipped planes, raised returns, occupancy and fade. | Pass material choices to that owner. Replacing it with an ordinary rectangular roof loses the tested court, doorway and streamed-slice contracts. |
| Dungeon blockers carry intact-envelope and city-stone bits; `ChunkBlockRenderer` batches the city-stone shader separately. | A future palette must keep rendered structural walls and original textured frontage compatible. Avoid a pale facade over differently tinted blocker caps. Do not reintroduce ruin holes on occupied envelopes. |
| Compact halls have a local quiet interior floor; compound paving reserves ambient-deco-clear cells. | Preserve this boundary in wet, mossy and damaged themes. Exterior terrain, street materials and their organic edges retain their district ownership. |

The proposed shared `DistrictVisualProfiles` catalogue can serve ordinary and
dungeon presenters with a dungeon-role restriction. It is still a proposal, not
an existing API. Prefer one explicit profile passed from the selected theme over
new `segment == N` checks inside roof, wall and light helpers. An unknown family
can use neutral common materials without replacing its terrain or pretending it
is Service Courtyards. The currently observed base-owner gate is already S2+;
that source change is not native rollout approval from this review.

## Reusable modules and dungeon-specific ownership

| Reuse across institutional, gate and industrial families | Keep dungeon-specific |
| --- | --- |
| Limestone wall bays, coping, supported piers and broad contact/eave shadows, uniformly scaled and cropped at actual wall ends. | Complete dungeon enclosure and hall/chamber/court topology; compact hall versus large compound selection. |
| A framed empty gate passage on a matching camera-facing opening; side entrances retain cardinal geometry. | Dungeon site/region identity, placement eligibility and reward rules. A painted gate is not a new gate mechanic. |
| Slate/clay surfaces, selected cross-gables and attached service caps. | Complete-site roof zones, open-air courts, wing indoor volumes and initial occupancy after reload. |
| Wall lamps, pressure equipment, grouped storage and sparse iron/copper fittings on real supports. | Cell grilles on actual blocked partitions, cell/storage/service sequences and fortified dungeon hierarchy. Ordinary domestic frontage need not acquire bars. |
| Seeded, reserved planting or a service group appropriate to the district. | One canonical large-site reward ID/total-area classification; compact CA volumes keep exploration loot off and the original independent dungeon spawner. |

Keep the shared top-right sunlight / southwest shadow direction. Vary ambient
coolness, modest weathering and practical-light emphasis without turning S7 into
an unreadable black interior or washing all later districts into S2 paving.

## Theme application across the catalogue

These are presentation recommendations on valid existing dungeon footprints.
They do not establish new lore, infrastructure, enemy or reward rules.

| Existing theme(s) | Appropriate dungeon interpretation |
| --- | --- |
| S2 Service Courtyards; S4 Civilian Cut-through | Reused civic enclosure beside inhabited streets. Court planting and a restrained service wing fit; domestic awnings should not replace the dungeon entrance hierarchy. |
| S3 Checkpoint Lanes; S8 Military Staging Ground | Guard/detention or secured-store character: strong real entrance, selective grilles, inspection lamps and disciplined wall-bound equipment. Leave inspection/muster routes clear. |
| S4 Collapsed Ward; S6 Ruined Service District | Localised structural damage, corrosion and reclaiming edges. An occupied dungeon still needs a continuous intended envelope. A true breach or roof collapse belongs to a separately planned ruin footprint, not random missing wall art. |
| S5 Inner District Gate; S10 Gate District | Reuse gatehouse masonry and iron-service modules, but keep the dungeon subordinate to the actual district gate and protected miniboss/boss court. Do not duplicate a monumental exit gate at every dungeon. |
| S6 Industrial Cut-through; S9 Siege Service District | Workshop/store/service emphasis: one coherent equipment zone, supported roof vents or lifting fittings and restrained soot/repair material. No floating machinery or ground clutter across doors. |
| S7 Underpass Veins; S7 Canal Service Routes | Cool shaded stone, supported undercroft mass or raised quay-side foundations. Interior floors stay dry/readable; moss stays at exterior contact edges. Tunnels, water and crossings require district layout/physics ownership, not a dungeon palette. |
| S8 Rail Yard Expanse; S9 Outer Wall Approaches | Yard-side secured stores or sparse guard/service lodges. Preserve broad loading/approach ground. Rails, wagons and the outer wall are separately planned district features; the dungeon is an attached or subordinate building. |

Authored S1 Institution can share institutional masonry, portal and laboratory
service modules through its authored builder. The hub retains its refuge/market
function and its own authored ownership. Neither should receive automatic
procedural dungeon placement. Beyond-the-Wall/S11+ remains an exploratory direction
with a documented current fallback, not a newly approved dungeon biome.

## Non-negotiable carry-over and review

- Complete-plan wall cells/masks and actual doorway width remain authoritative.
  Keep protected roads, encounter courts and entrance approaches clear.
- Outdoor courts stay outdoors; compact covered halls retain continuous indoor
  floors. Palette changes must not enlarge indoor/reward ownership.
- Roof planes, continuations and raised returns keep identical door-hole and owner
  chunk clipping. New overhead modules inherit fade and actor coverage; facade or
  equipment alpha must not outlive its roof owner accidentally.
- Preserve initial occupancy on reload and ordinary-house behavior. The actor
  shader's 32-triangle cap is a coverage limit, not proof that adding more roof
  modules is free.
- For a visual-only profile, expect unchanged walls, masks, floor ownership,
  protected cells, IDs and carve RNG. Check actual alternate theme IDs, cardinal
  entrances, negative-coordinate seams, inside reload and normal/small views.
  Reuse the existing dungeon/house regression and native tools; old capture hashes
  do not certify changed sources or unviewed themes.

The preexisting mixed planned/default multi-chunk anchor completeness risk and
generic duplicate IndoorVolume issue remain separate from theme styling. The
[dungeon audit](../../audits/2026-10-19-dungeon-architecture.md) and
[accepted review](../../art/reviews/2026-10-19-donjon-architecture-designer-review.md)
record those limits. This review does not expand the base owner's current scope
or request another engine run.
