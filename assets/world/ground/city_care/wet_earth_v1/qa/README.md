# Inspection previews only

The production source is the unchanged PNG one folder above. These previews
were derived with Pillow only to inspect material repetition and scale; they
are excluded from Godot import and must not be used as runtime materials.

- `repeat_192.png`: 3×3 repeats, each tile shown at 192px.
- `repeat_384.png`: 2×2 repeats, each tile shown at 384px.
- `native_wrap.png`: native-resolution half-width/half-height offset so opposite
  edges meet through the center. No texture repair was applied.
- `source_comparison.png`: old dry earth, old wet mud and new candidate, each
  shown as a 384px tile under the same unmodified exposure.

Screen-pixel previews are not a shader/filtering or native lighting simulation.
Measured source/join statistics are in `../manifest.json`; edge differences
alone cannot certify seamlessness. The lead keeps this for one native trial.
