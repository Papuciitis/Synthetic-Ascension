R8 is source preparation. The pickup shader candidate is still scratch-only;
the product shader remains baseline `3ede2225`. Root reviews/applies it, then
runs the driver. The driver never applies a shader itself.

Review `cover-tree-r8-tool.diff`, `cover-tree-r8-shader.diff`, and
`cover-tree-r8-source.json`. `cover-tree-r8-basis/snapshots.json` binds the exact
failed R7 source, final metadata and all four untouched original plates.

Dry plan (no engine):

```sh
python3 .superpowers/continuation-20261022/cover-tree-r8-queue.py --dry-run
```

After root's shader review, the exact proposed application is:

```sh
cp .superpowers/continuation-20261022/pickup-cover-density-r8.gdshader /tmp/sa-wp2-cover/core/systems/world/visibility/pickup_cover.gdshader
python3 .superpowers/continuation-20261022/cover-tree-r8-queue.py
```

Fresh serial cases are `city22-cover-tree-r8-parse` (three scoped scripts),
`city22-cover-pickup-r8-native` (all original33 native predicates), and
`city22-cover-moving-tree-r8`. Each starts at65C with900s maximum queue wait and
25% setup duty; runtime90C/85C sustained3 remains unchanged. Parser/fixture have
300s timeouts; moving has600s. The fixture wrapper sets actual15 renderFPS
after SettingsManager startup and calls the unchanged test's ready method.
Moving uses its actual15FPS override and releases setup duty only on
`[Game] ready`. Physics stays60Hz. No test predicates, pickup owner behavior,
player controls, enemy AI, scheduler or streaming are frozen/overridden.

The fixed camera target/initial offset starts immediately before the restored third plate and ends
after the normal-equipment fourth plate. Player knockback remains live.
Camera impact offset is temporarily held; HitFeel settings/producers are unchanged.
Exact camera/canvas, owner/position/material/texture, distance>126px, normal-ready
state, locked health and original controls remain asserted. The candidate
only changes covered pickup alpha density, preserving authored texture holes,
lock/fade modulation and glow ratios; shared RGB/player/enemy shaders remain
unchanged. Existing native33 gates test those practical contracts.

Outputs use fresh `moving-tree-r8` names; existing output/thermal/run folders
are refused. Before/after imports remain a finite selected-resource sample,
with the actual shader and current launcher files explicitly sampled. No
full Game/import closure, performance, or matched-frame pixel identity claim
is made. A clean run still needs actual native image review for readability.
