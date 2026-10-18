# Exact derived ground array

`ground_materials.res` contains the thirteen RGB8 512×512 layers and mipmaps
produced by WorldArt's existing ground preprocessing. It avoids reading the
full imported textures back from the GPU during a player's first level entry.
It is a derived resource; the source PNGs, import settings and appearance are
unchanged. Missing or incompatible resource geometry falls back to the builder.

After editing a listed source PNG or its import settings, regenerate with the
native Godot executable from the project root:

```powershell
& $godot --path . --script res://tools/dev/BakeGroundMaterials.gd
```

Use a real renderer and isolated process-local APPDATA/LOCALAPPDATA. The
headless Dummy renderer cannot provide the original texture pixels. Commit
the `.res` and its JSON provenance together. If preprocessing changes, bump
`WorldArt.GROUND_ARRAY_CACHE_REVISION` and regenerate as well.

`GroundMaterialCacheTest.tscn` checks every ordered PNG/import hash and the
derived resource hash. Run `TransitionResourceWarmupTest.tscn` with the native
renderer to compare every cached layer, including mipmaps, with a fresh build
through the original algorithm. Its headless route checks frame staging only.

Source textures retain the Cethiel CC0 terms in ../LICENSE_cethiel_cc0.txt.
