# Plain household rush mat — source candidate

20 October 2026. A quiet sleeping-corner floor furnishing for the existing real
S2 homes. **Source-only KEEP for native trial; runtime appearance is unaccepted.**
Use it to group the existing cot into a believable sleeping place. The next
household pass should compose the existing hearth, table and storage as well;
one mat cannot resolve the whole room.

The built-in image_gen tool produced one original transparent PNG in generation
mode, with no edits or fallback. [Exact prompt and settings](prompts.json) and
[measured manifest](manifest.json) are retained. The production
[rush_mat.png](rush_mat.png) is the tool's original bytes, copied unchanged.
SHA-256: `303ba9215cdf470face851a973418f019dab3aa740b844848c93b9b0a052b2dc`.

## Fit and use

- North-up, straight overhead flat floor décor; long axis vertical.
- Source: 1024×1536 RGBA. Alpha ≥128 bounds are (53,50)–(985,1481),
  with the upper bounds exclusive: visible extent 932×1431 source pixels.
- Ground anchor: source pixel **(519,765.5)**, the visible bounds' center.
  Offset the sprite so this point lands on the intended floor position.
- Initial trial: visible width **96 world pixels**, uniform scale
  **0.10300429**, giving visible extent about **96×147.4 world pixels**.
  Preserve aspect. This is a proposed fit, not a measured native placement.
- Place beside or partly beneath the cot, within the sleeping zone. Keep the
  doorway, central fighting route and existing prop-contact routes clear.
  This flat furnishing adds **no collider, cover cell or foreground occlusion**.
- Judge at 960×540 and the existing normal size with the player present.
  If it dominates the stone/cot, adjust restrained runtime presentation or
  report a precise source correction; do not stretch or repaint the original.

The source has actual transparency: 322,623 pixels have alpha 0 (20.51%).
Alpha ranges 0–254; the interior is near-opaque rather than exactly 255.
No alpha normalization, trimming, recoloring or baked floor/shadow was applied.
Fine weave may disappear at game size, which is preferable to a noisy floor.

The [QA previews](qa/README.md) composite the source at small display widths
for inspection only. They are not production textures. No engine/import/bake,
runtime placement or native capture ran on Windows.

See the [lead review and bounded return request](../../../../docs/art/reviews/2026-10-20-linux-city-continuation-review/README.md).
