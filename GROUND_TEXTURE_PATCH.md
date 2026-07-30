# Cethiel ground integration and loader repair

This revision replaces the failed flat-gray ground experiment with processed CC0 tileable textures supplied from Cethiel's OpenGameArt packs.

## Active material map

- `ground_city_base_01.png`: muted mossy city blocks derived from `Ground_03`.
- `ground_dirt_path_01.png`: rectangular street paving derived from `Ground_02`; the filename is retained because procedural code already uses texture index 4 for roads and door aprons.
- `ground_cobble_01.png`: irregular stone derived from `Ground_01` for sidewalks and ordinary plazas.
- `ground_stone_tiles_01.png`: restrained square tiles derived from `Brick_03` for interiors and gate plazas.
- Dirt, mud and grass use processed `Dirt_01`, `Dirt_03` and `Grass_01`.

All active files are 1024×1024. They repeat over 1024 world pixels and align in world space across chunk and stamp boundaries. Per-chunk brightness variation remains disabled.

## Godot 4.7.1 repair

`WorldArt.gd` no longer exposes texture arrays through a global `class_name`. `ChunkManager.gd` and `ChunkGenStamp.gd` explicitly preload it and use typed static getter functions. This removes the failing `WorldArt.GROUND_TEX` external-member lookup and avoids dependence on a stale generated global-class cache.

## Preserved material

- `_legacy_023_noisy/`: original detailed 0.23 textures.
- `_legacy_failed_gray_0241/`: the rejected gray ground rework.
- `_source_cethiel_cc0_selected/`: untouched selected Cethiel diffuse and normal maps plus provenance notes.

## 0.25.0 outdoor correction

The 0.24.2 city-base material was still visible in open areas because procedural chunks used one universal substrate. The 0.25.0 generator now assigns terrain per planned chunk and a natural fallback to unplanned streamed chunks.

Active outdoor grass: `ground_grass_01.png`, processed from the supplied Cethiel `Grass_04` diffuse source. The previous dense active grass is preserved in `_legacy_dense_foliage_0242/`. Main streets, secondary paths, plazas and interiors remain separate overlays, so the grass is not intended to replace authored paving.
