# Exact derived ground array

`ground_materials.res` contains the fourteen RGB8 512×512 layers and mipmaps
produced by WorldArt's existing ground preprocessing. It avoids reading the
full imported textures back from the GPU during a player's first level entry.
It is a derived resource; the source PNGs, import settings and appearance are
unchanged by baking. Layer12 uses the selected city-care damp moss/soil;
layer13 is the selected short lawn, sampled only for local household care.
Existing rough grass/meadow/scrub and the seven semantic terrain mappings remain.
Lawn never occupies a semantic coverage slot.

In source checkouts, missing, malformed or stale provenance, changed ordered
PNG/import hashes, or changed derived bytes reject the cache and fall back to
the builder. Exported builds keep geometry/format checks without requiring raw
source PNGs, import sidecars or provenance JSON to be packaged.

After editing a listed source PNG, its import settings or the ordered source
list, import in a fresh process and regenerate through the sole monitored
engine lane. From the project root on Linux, use new run directories:

```bash
python3 tools/capture/run_city_linux.py --godot "$SA_GODOT" \
  --run-root .superpowers/handoff-linux/ground-import --timeout-seconds 300 -- \
  --headless --import

python3 tools/capture/run_city_linux.py --godot "$SA_GODOT" \
  --run-root .superpowers/handoff-linux/ground-bake --timeout-seconds 300 -- \
  --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tools/dev/BakeGroundMaterials.gd
```

The monitor isolates the process profile and enforces the shared engine lane
and memory guard. The bake itself needs a real renderer; headless Dummy cannot
provide the original texture pixels. The tool rejects missing/stale imported
data and unreadable imported pixels instead of recording gray fallback art.
Input hashes are captured before preparation and checked before saving. Commit
the `.res` and its JSON provenance together. If preprocessing changes, bump
`WorldArt.GROUND_ARRAY_CACHE_REVISION` and regenerate as well.

`GroundMaterialCacheTest.tscn` checks every ordered PNG/import hash and the
derived resource hash. Run `TransitionResourceWarmupTest.tscn` with the native
renderer to compare every cached layer, including mipmaps, with a fresh build
through the original algorithm. Its headless route checks frame staging only.

Cethiel source textures retain the CC0 terms in ../LICENSE_cethiel_cc0.txt.
The two city-care originals have separate source/generation provenance in
../city_care/v1/README.md and its manifest.
