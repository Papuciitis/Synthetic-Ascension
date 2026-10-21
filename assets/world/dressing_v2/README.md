# Street dressing props v2 — 21 October 2026

Original high three-quarter view props generated with Codex's built-in
`image_gen`, `planted_stone_trough.png` and `temperate_tree.png` attached as
style references (one call per prop; briefs in `<name>.prompt.txt`). No stock
or downloaded artwork. Post-processed like the facade kit (fringe removal, crop,
max side 512 px). They are presentation-only frontage, garden and yard
dressing: none adds collision unless its placing code says so.

barrels_group, bench_stone, bollard_pair, crates_stack, cypress_tree,
garden_bed, handcart, lamp_post, market_stall, pots_cluster, rubble_pile,
sacks_pile, scaffold_crates, table_benches, tree_planter, water_trough,
wattle_fence, well_stone.

## In-game use (CityFrontageDressing, 21 October 2026)

`scenes/world/buildings/CityFrontageDressing.gd` places these props at the foot
of every ordinary city building's visible south wall in every segment (S2..S10
and the S11+ fallback; never the S3 guard loggia). Vocabulary follows building
use (homes, shops, workshops, passages, civic halls) and district family
(ruined, military/rail, canal/underpass, ...). `market_stall` and `well_stone`
are not placed yet.

Placement contract, in world pixels (one cell = 64, actors about 40 x 60):

- Each prop is scaled uniformly from its measured opaque rect (alpha > 0.5,
  table below); its front ground contact is that rect's bottom-centre.
- Contacts stand on the building's own blocked wall strip
  (`ground_y - 16 .. ground_y`), so no actor can ever stand inside a prop.
- Doorways keep their frame plus 40 px either side clear; props do not hide
  windows and stay below shopfront sills.
- Props are never mirrored (the painted light comes from the upper right).
- Tall props (cypress, lamp post, tree planter) register as foreground cover;
  every prop casts a projected `city_sun_shadow` like the kit trees.

| Prop | Opaque rect (x, y, w, h) | World size |
| --- | --- | --- |
| barrels_group | 4, 4, 503, 490 | 56 wide |
| bench_stone | 3, 2, 506, 122 | 90 wide |
| bollard_pair | 4, 4, 503, 298 | 52 wide |
| crates_stack | 4, 4, 503, 394 | 70 wide |
| cypress_tree | 3, 4, 176, 504 | 150 tall |
| garden_bed | 2, 4, 507, 156 | 88..150 wide |
| handcart | 3, 3, 504, 326 | 82 wide |
| lamp_post | 3, 3, 91, 505 | 110 tall |
| pots_cluster | 4, 3, 504, 325 | 64 wide |
| rubble_pile | 3, 5, 503, 175 | 84 wide |
| sacks_pile | 4, 3, 503, 334 | 60 wide |
| scaffold_crates | 3, 3, 505, 248 | 92 wide |
| table_benches | 4, 4, 504, 296 | 88 wide |
| tree_planter | 4, 4, 362, 503 | 130 tall |
| water_trough | 3, 3, 505, 177 | 92 wide |
| wattle_fence | 2, 2, 507, 99 | 84..96 wide per panel |

`crates_stack` and `handcart` are painted on a slight diagonal; they read as
goods set against a wall, but a strictly frontal redraw would sit better.
