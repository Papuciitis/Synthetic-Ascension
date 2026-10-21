# Existing segment assets and placement

Inventory pinned to integrated base `245e2385` and incoming Linux
`3d1be8b0039ce96e65959958b0da10a799f8fcfb`. This is curation for the
[material/atmosphere direction](README.md), not approval of every source's fit.

The incoming eight packs contain 130 PNGs including 42 derived plaza-kit PNGs.
**None of those eight packs is in the integrated base.** Paths below are repository
paths at the pinned Linux commit, not claims that the files exist in this checkout.
They are already on the production branch; do not regenerate or copy all of them
to the art lane simply to make these links local. Incoming consumers also remain
held pending integration review. Parked branches may contain newer code, which
needs its own review.

Status: **R** = referenced by incoming runtime; **A** = source baked into incoming
plaza atlas/kit; **S** = source candidate with no incoming runtime consumer;
**K** = earlier bounded native KEEP, already integrated. R/A mean adoption,
not aesthetic acceptance. K applies only to the recorded sampled use.

## Packs and exact prefixes

All abbreviations below expand under `assets/world/`; each listed item ends in `.png`.

| Prefix | Directory | Availability / adoption |
| --- | --- | --- |
| F | `facades/v1/` | R except `balcony_timber`, unsplit `door_arched_inward` and `door_double_inward` originals (S). Runtime uses their `_frame` and `_inside` splits |
| D | `dressing_v2/` | 16 frontage sources R; `well_stone` A; `market_stall` S |
| X | `districts_v2/` | `wall_fountain` A; 18 other structures S |
| Rf | `rooftops_v1/` | Six sources R through roof-form composer |
| P | `plazas_v1/` | Six sources A, plus derived kit. Its old source-only README is stale |
| I | `industrial_v1/` | All five S |
| U | `ruins_v1/` | All six S |
| N | `interiors_v1/` | All ten S |

The facade README overstates balcony adoption. The dressing stall is not the
incoming plaza stall: plazas use `P/market_awning_stall`. These differences matter
when checking whether a replacement is needed.

## Selections by theme

Use a small purposeful group at a believable owner, with open traffic space.
This table proposes where sources belong; it does not assert that S assets are
placed or physically implemented.

| Theme | Useful selections | Placement / exclusion |
| --- | --- | --- |
| S2 | Integrated herb bed, overhead fruit tree and cared lawn K; F/`window_open_flowers` R; D/`pots_cluster` R; N/`loom_spinning` S | Bed against a cared home, tree in one useful plot, pots at a doorstep. Loom establishes work in a home; leave doorway and movement space |
| S3 | F/`window_small_barred`, D/`bollard_pair`, D/`sacks_pile` R; P/`notice_board` A; N/`shelves_goods` S | Inspection/supply grouping at an actual checkpoint. Preserve the separately owned guard loggia and inspection route |
| S4A | U/`ruined_wall_face`, `broken_roof_flat`, `shoring_timbers` S; D/`rubble_pile` R; existing dry grass | Rubble follows broken structure, shoring supports a damaged face, roof fragment belongs to roof fade. No random tall debris across required lanes |
| S4B | F/`window_open_flowers`, D/`table_benches` R; P/`market_awning_stall`, `olive_planter`, X/`wall_fountain` A; N/`shop_counter` S | Small household/trade fronts and one shared water source. A planter belongs to an intentionally maintained place, not every empty lot |
| S5 | X/`gate_arch_face`, `city_wall_face`, `wall_walk`, `gatehouse_dome` S; D/`bollard_pair` R | Gate structure needs correct opening/cast/roof/physical owners; pillars mark usable passage, not an invisible blocked arch |
| S6A | I/`brick_wall`, `wall_pipes`, `boiler_tank` S; Rf/`chimney_brick`, D/`handcart` R; N/`anvil_forge` S | Connect pipes to a useful service. Soot/smoke belongs to a working source. Group cart, stores and work surface beside loading access |
| S6B | U/`ruined_wall_face`, `broken_roof_flat`, `shoring_timbers`, I/`wall_pipes` S; D/`scaffold_crates` R; N/`workbench_tools` S | Abandoned equipment, leaks and repair staging; avoid active-stack smoke. Keep ruined passage silhouette physically honest |
| S7A | X/`viaduct_arch`, I/`wall_pipes` S; D/`barrels_group` R; P/`drain_grate` A; integrated subdued moss K | Arch shelter and drain location cause dampness. Do not substitute a blue ground wash for actual pier/bank materials |
| S7B | X/`canal_water`, `canal_quay_edge`, `canal_coping`, `lock_gates`, `stone_bridge` S; integrated moss/soil/wet earth K | Align waterline, coping and bank. Bridge needs walkable deck and blocked sides, real bank joins and matching orientation |
| S8A | X/`rail_track`, `rail_wagon`, `coal_bunker`, `yard_crane` S; D/`crates_stack` R; N/`sacks_storeroom` S | Track continues coherently. Crane/storage establish one loading purpose; coal and wear follow that purpose. Leave fighting/movement room |
| S8B | X/`army_tent` S; D/`sacks_pile`, `crates_stack`, `handcart` R; N/`floor_flags` S | Group stores by an actual tent/barracks entry. Tent footprint, entry and tall cover require implementation, not a nonblocking scattered sprite |
| S9A | X/`city_wall_face`, `wall_walk`, `wall_tower_face`, `wall_stair` S; D/`water_trough` R | Continuous defended structure and real approach; wild irregular margins. Stairs and openings need matching traversal or explicit blocking |
| S9B | X/`yard_crane`, `coal_bunker` S; D/`scaffold_crates` R; U/`shoring_timbers`, `rubble_heap_large` S | Working repair/logistics site. Keep natural service corridors; stone piles need a plausible wall/handling relationship |
| S10 | X/`gate_arch_face`, `gatehouse_dome`, `tower_top`, `wall_stair` S; P/`notice_board` A | Landmark composition around a readable final passage, with clear boss court and objective keepouts |

S1 and Hub keep their existing authored selections. DonJon reuses masonry and
purposeful interior groups by room; it is not a new segment pack.

## Integrated sources to keep using

Exact paths, with qualified earlier native fit/material decisions:

- `assets/world/ground/city_care/v1/cared_lawn.png`
- `assets/world/ground/city_care/v1/damp_moss_soil.png`
- `assets/world/ground/city_care/wet_earth_v1/wet_earth.png`
- `assets/world/domestic_gardens/v1/flower_herb_bed.png`
- `assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png`
- `assets/world/domestic_interiors/v1/timber_cot.png`
- `assets/world/domestic_interiors/v1/cooking_hearth.png`
- `assets/world/domestic_interiors/rush_mat_v1/rush_mat.png`

The incoming kitchen bed uses D/`garden_bed`, while the earlier kept herb bed is
no longer referenced there. Do not silently transfer its fit approval to a
different source. Preserve the checked cot/hearth/mat and useful work/storage
composition; N adds workshop/shop vocabulary rather than replacing that work.

Keep `assets/world/ground/ground_grass_01.png`, `ground_grass_02.png`,
`ground_grass_dry_01.png`, `ground_dirt_01.png` and selected masonry by role.
`ground_dirt_path_01.png` is paving, despite its name. Old `ground_moss_01.png`
and `ground_mud_wet_01.png` remain sources but are not the current material-array
inputs. The incoming city-wide paving policy still needs ecological correction.

`assets/world/city_block/temperate_tree.png` and fruit-tree v2 suit ordinary
canopy. D/`cypress_tree` has a conspicuously tall frontal projection; reserve it
for occasional civic/planter accents after a root/sorting/cover trial. It is not
a broad replacement for overhead foliage. The bridge is a tapered painted
complete structure with railings, not a universally rotatable ground tile.

## Existing weather/VFX sources

Reuse `assets/world/decals/floor/floor_cracks_01.png`, `floor_scuff_01.png`,
`floor_scorch_01.png`, `floor_rubble_01.png`, `floor_grime_01.png` and
`floor_spill_01.png` where their actual appearance and role fit. Grime is almost
flat black, and the spill has a conspicuous cyan ring; neither is a universal
wall-weathering mask. Do not import the cyan ring into ordinary canal mud.

Existing `assets/textures/backgrounds/fog_soft_01.png`,
`assets/textures/vfx/motes/mote_dust.png`, `mote_ember.png`,
`assets/vfx/particles/kenney/smoke_04.png`, `smoke_07.png`, and incoming
I/`smoke_puff.png` already cover general air-source vocabulary. Ember needs a
real hot source. A texture does not supply an emitter, indoor exclusion or budget.

## New and deferred support

The [new support pack](../../../assets/world/material_support/v1/README.md)
delivers wall-base damp, directional rain/rust runoff, attached vent soot and
sparse roof lichen masks, plus palette/profile files. These fill actual gaps in
the existing catalogue without another large facade/prop pack.

Defer a ground transition/wear atlas until the existing material hierarchy and
shader cost are corrected. Defer low wet-bank sedge/rush clumps and a small
high-overhead rope coil/mooring ring until a native canal crop supplies required
world footprint, source anchor and camera scale. These are identified needs,
not claimed delivered assets. All source candidates preserve aspect, painted
light and clearances; a closed loading-door image cannot dress an open entry.
