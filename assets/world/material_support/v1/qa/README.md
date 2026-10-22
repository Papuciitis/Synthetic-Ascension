# Source validation and visual inspection

21 October 2026. These checks establish source-file readiness only. They do not
validate a game shader, surface mapping, streaming, collision, frame cost or
native aesthetic fit.

The fourteen profile IDs were matched to the current theme catalogue, palettes
validated as authored sRGB hex values, and proposed atmosphere values checked
against the brief's restrained ranges. Manifest hashes/lengths identify each
delivered master. Incoming object paths/counts were checked against Git commit
`3d1be8b0039ce96e65959958b0da10a799f8fcfb`; they were not silently copied into
the integration branch.

Godot 4.7.1's actual SVG decoder loaded all four mask masters in a tiny isolated
project under ignored `.superpowers/art-support-svg-20261021/`, with no Game
autoloads, source imports or project settings. The process used the existing
resource guard, had no competing Godot process and exited 0. See `svg_decode.json`
for the final dimensions and pixel statistics. All pixels are opaque, RGB
channels match, black outside the effect is present, and the damp mask's X edge
values match. SVG masters use gradients/paths rather than SVG filters. Gradients
and lowered path opacity are flattened over the opaque black background.

The four PNG mask files here are actual Godot decoder outputs for inspection;
the SVG files remain the masters. `palette_board.png` is a labelled reference
graphic drawn directly from profile data with Pillow and system Arial fonts.
The companion SVG also carries text for ordinary SVG viewers. Godot's SVG image
decoder omits its text, so that decoder output is not used as the labelled board.
The board depicts material swatches, not a simulated in-game scene.

The lead personally inspected the board and all four decoded masks. The first
damp crown and runoff had hard edges; they were softened and decoded again.
Keep these as bounded source candidates: base damp stays at wall feet, runoff
under a leak, soot above a working outlet and lichen on roof-plane eaves. A local
material/atlas trial is still required. Avoid stamp repetition and preserve
quiet large planes and actor contrast in the native return packet.
