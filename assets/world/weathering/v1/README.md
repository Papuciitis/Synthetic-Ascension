# Weathering masks v1: runtime rasters

These are the runtime rasters of the art lead's four grayscale data masks. The masters stay in
[`../../material_support/v1/masks`](../../material_support/v1/masks) (SVG; see that pack's README and `manifest.json`).
Rasterised on 22 October 2026 by the Linux lane:

```
inkscape <master>.svg --export-type=png -w <W> -h <H>   # then flattened on black, saved as 8-bit grayscale (Pillow)
```

| File | Size | Use (CityWeathering) | Sampling |
| --- | --- | --- | --- |
| `wall_base_damp.png` | 1024×256 | Capillary damp at a real wall foot. Wall field and plinth shaders, through the `sa_weather_damp_mask` shader global | Repeat X; Y clamped to the foot; full height = 64 world px |
| `runoff_streaks.png` | 256×512 | Rain or mineral runoff below a real window sill (stain quad starts at the sill, at the mask's leak source y = 32) | Clamp |
| `vent_soot.png` | 512×512 | Reserved: soot above a real operating flue or vent outlet (outlet at y = 420). No current facade or roof piece is such an outlet. The `service` cabinet is a closed gauge box, so the mask is unused until an outlet owner exists | Clamp |
| `roof_lichen.png` | 512×512 | Lichen near the south eave of a roof plane. `roof.gdshader`, through `sa_weather_lichen_mask` | Repeat X along the eave; Y clamped |

The red channel is linear coverage: black = clean, white = full deposit. These are data, never visible sprites.
Imports keep lossless compression with mipmaps, because the masks are always sampled minified.
