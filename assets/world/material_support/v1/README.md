# Segment material support v1

21 October 2026. Code-authored source assets for the
[segment art brief](../../../../docs/art/2026-10-21-segment-material-atmosphere-direction/README.md).
No runtime references, shader changes or native-fit approval are supplied.

- `segment_profiles.json`: fourteen exact procedural theme IDs, proposed material
  swatches, weathering intent and restrained trial atmosphere values. S1/Hub are
  protected authored references; S11+ is explicitly unresolved beyond its current
  Service Courtyards fallback. This is an art interchange format, not an engine API.
- `segment_palettes.gpl`: GIMP-compatible sRGB palette, with role/theme names.
  These are authored midtone targets, not extracted concept pixels. The palette
  does not encode shadow, roughness, emission or shader multiplication.
- `masks/*.svg`: four opaque grayscale data masks, black=0 and white=1. Sample
  the red channel as linear mask data (do not use a colour-space `source_color`
  hint). They are inputs for surface treatment, never visible sprites with a
  black background. Each has an explicit physical owner in `manifest.json`.
- `qa/`: palette board, decoded mask previews and honest validation scope.

## Fitting the masks

| File | Source size / anchor | Intended use | Sampling |
| --- | --- | --- | --- |
| `wall_base_damp.svg` |1024×256; bottom edge is the wall foot | Small capillary damp band on an actual vertical wall; intended world height 12–44px | Repeat X only; clamp Y. X edge values match. Keep bottom aligned to the wall foot |
| `runoff_streaks.svg` |256×512; source at(128,32), gravity down +Y | Rain/mineral/rust flow below a real gutter, ledge or metal fixing; recolour in the receiving material | Clamp both axes. Keep source at the leak; vary strength by cause, not by arbitrary per-tile noise |
| `vent_soot.svg` |512×512; outlet at(256,420), deposit rises toward -Y | Bounded soot above a real operating vent/chimney on vertical masonry | Clamp both axes. Rotate only with the actual surface; never invert gravity on a facade |
| `roof_lichen.svg` |512×512; eave strip at bottom | Sparse low-contrast growth on shaded roof eave/valley surfaces | Clamp both axes; fit in roof-plane UVs. No frontal masonry projection or baked cast |

All four retain an opaque black background and grayscale RGB. Their appearance
includes soft coverage through SVG gradients, not painted wall colour, physical
material, lighting, collision or particles. Rasterize to a chosen working size
if an atlas baker needs PNG; preserve the SVG masters. Keep mask filtering linear;
choose mipmaps for the eventual surface scale and inspect thin streak loss.

Prefer an offline material/atlas bake. A local shader trial must select only the
needed mask for that owner; do not sample all four across the scene. Do not reuse
reserved care/openness channels for packing. Most walls should remain mostly clean.
Do not stretch a complete stamp across every tile or make seams repeat at every
door. A darkening trial of 10–25% at the strongest stain is a starting art range,
not validated final tuning. Metal rust and stone mineral deposits need different
colour responses even when they share the runoff mask.

These fill specific support gaps. Reuse the existing terrain masters, floor
decals, fog/dust sources and incoming object packs listed in the curation. A low
wet-bank sedge set or a rope/mooring utility is a possible later source request
only after a native footprint exposes the need; neither is delivered here.
