# Modular facade kit v1 — 21 October 2026

Original raster modules generated with Codex's built-in `image_gen` (one call
per module, `house_front.png` and a matching window-bay test image attached as
style references). No stock or downloaded artwork. Exact briefs are kept beside
each file as `<name>.prompt.txt`.

Post-processing (`defringe.py` in the local production lane): faint alpha speckle
dropped, the red/yellow edge fringe the generator leaves on alpha borders
replaced with interior colour and eroded by 1 px, cropped to content (+8 px pad),
Lanczos-resized to a runtime size. Material tiles are opaque, resized only.
Door modules are split into `*_frame.png` (stone surround, opening transparent)
and `*_inside.png` (opening with the leaves swung inward) so the frame occludes
actors behind the wall while the walkable opening stays uncovered.

| Module | Runtime use (`CityFacadeComposer.gd`) |
| --- | --- |
| facade_plaster_warm / facade_plaster_pale | Seamless wall tiles; clay-roofed houses get warm lime plaster, slate-roofed houses pale ashlar: one masonry vocabulary in two local stones |
| facade_plinth | Horizontally tiling foundation course |
| quoin_strip | Corner quoins (mirrored for right corners) |
| window_closed_shutters / window_open_flowers / window_small_barred / window_arched | Window bays, aspect preserved |
| door_double_inward / door_arched_inward (+ _frame/_inside) | Doorways fitted so the opening equals the carver's physical gap |
| shopfront_open, wall_service_box, ivy_climber, balcony_timber | Use-specific fittings |

Measured openings (texels in the processed PNG): double door opening
x150-618, y110-612; arched opening x180-596, arch crown y128, threshold y690.
