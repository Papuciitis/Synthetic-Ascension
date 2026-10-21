# District identity sources v2 — 21 October 2026

Original modules generated through Codex's built-in `image_gen` (one call per
asset; briefs beside each file as `<name>.prompt.txt`), with existing project
art attached as style references: `house_front.png` + the v1 arched doorway for
frontal elevations, `planted_stone_trough.png` + `dressing_v2/well_stone.png`
for high three-quarter props, `paving.png` for materials. No stock or
downloaded artwork. Cleaned like the facade kit (fringe removal, crop,
max side 768 px; materials and the wall face stay opaque, max side 1024 px).

| Asset | Intended use |
| --- | --- |
| city_wall_face, wall_walk, wall_tower_face, gate_arch_face | Outer wall / gate districts (S5, S9, S10): wall south face, wall-walk top, towers, gate passage |
| canal_water, canal_quay_edge, stone_bridge, lock_gates | Canal service routes (S7B) |
| rail_track, rail_wagon, yard_crane, coal_bunker | Rail yard (S8A) and industrial yards (S6) |
| army_tent | Military staging ground (S8B) |
| wall_fountain | Civilian cut-through squares (S4B) and courts |

Source only: runtime placement, scale, collision and anchors are decided by the
code that adopts each asset.
