# Elite modifiers — second visual pass

ImageGen produced five transparent neutral sprites. Runtime tinting gives
Armoured steel plates, Vampiric a red fang ring, Shielded a cyan ward,
Splitting a lime fissure, and Fast a pale-yellow wind ribbon. The first
modifier owns the body's edge/glint colour; other modifiers retain their
own coloured tells. Plain elites retain gold. Reduced motion keeps static
marks and disables the moving glint, body pulse and velocity trail.

The source art and exact generation prompts are in
`assets/textures/vfx/elites/`. Original PNG pixels/alpha are preserved;
Godot import limits reduce runtime texture sizes. Dedicated art routing
leaves the generic VFX kit available as a fallback.

## Rendered previews

- `elite-modifier-preview.gif`: 72 real rendered frames, 1.8× actor detail.
- `elite-modifier-preview.png`: the corresponding enlarged still.
- `elite-modifier-native.png`: real 1.0× actor scale.
- `capture-info.json`, `native-capture-info.json`: capture diagnostics.
- `verification.json`: focused test results and review limits.

These use actual promoted EnemyActors and the production batched renderer
at z=10, with animation captured live. Position is frozen for comparison;
FAST has a rightward test velocity for its trail. The cyan ward retains
its real 180px world radius at both actor scales. No game save writes occur.
The GIF retains sampled frame timing (about 5.16 seconds), rather than
speeding the capture up to its requested 24fps. Dense combat readability
still needs a human playtest; the native splitting seam and mixed red ring
are deliberately finer than the shield boundary and FAST ribbon.

Reproduce with Godot 4.7.1, a real renderer and the Dummy audio driver:

```text
--path . --audio-driver Dummy --rendering-method gl_compatibility res://tools/dev/EliteModifierPreview.tscn -- --out=<absolute-output-folder>
```

Add `--native --still-only` for the native still, or `--interactive` to
inspect the fixture in a window. Headless mode cannot produce these pixels.

The user approved both preview sizes on 2026-10-16 and requested this pass
be committed and pushed separately from the first gold/ivory pass.
