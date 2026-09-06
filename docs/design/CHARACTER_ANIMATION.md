# Character animation: player races and sheet-driven enemies

Added 2026-09-06 with the first character art drop (`character_sprites.zip`).
This is the map of how the art gets from the supplied PNGs onto the screen,
what the sheets actually contain, and what is known to be missing.

## Pipeline

1. **Source sheets** live untouched under `assets/textures/characters/`
   (`player/<race>/<race>_{idle,run,head}.png`, `enemy/{grunt,spitter}_test.png`).
   They are never drawn at runtime.
2. **Definitions** in `data/visuals/` say what each sheet holds:
   `RaceVisualDefinition` (`races/*.tres`) and `EnemyVisualDefinition`
   (`enemies/*.tres`). Cells are `Vector2i(row, column)`; rows are detected
   from the art as alpha bands, so uneven spacing does not matter. The same
   resource carries the on-screen sizes and the runtime nudges (`head_offsets`).
3. **Bake** — `tools/bake_character_atlases.gd` cuts every named cell around
   its own neck hole (the dark collar opening every body sheet has), scales it
   to screen size with a premultiplied Lanczos, composites enemy helmets onto
   their headless bodies, packs one atlas per character and writes a
   `CharacterFrameSet` (`assets/textures/characters/baked/<id>_frames.tres`
   + `<id>_atlas.png`): a `SpriteFrames` plus, per frame, the pixel that sits
   on the origin and the collar position.

       ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/bake_character_atlases.gd
       ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import

   Re-run both after editing a definition or replacing a sheet. The baked
   files are committed, so a checkout plays without baking.
4. **Runtime**
   - Player: `core/actors/player/PlayerVisualController.gd` on `Player/Visual`
     (`Body` and `HeadAnchor/Head` are `AnimatedSprite2D`s, `AnimationPlayer`
     holds the `breathe` loop). It reads the body's `velocity`, picks
     `body_<state>_<facing>` / `head_<state>_<facing>` with fallbacks to idle,
     hangs each frame from its baked anchor (feet on the origin) and moves the
     head anchor to the current frame's collar plus the race's `head_offsets`.
     It cancels the parent's rotation every frame: `player.gd` still rotates
     the `CharacterBody2D` for the dash and slash logic, and nothing there
     changed.
   - Enemies: `EnemySpec.visual_frames` + `animation_fps`. `EnemyInit` gives the
     actor an `EnemyAnimator` (`core/actors/enemy/modules/`) that swaps the
     single `Sprite2D`'s `region_rect` once per simulation step, frame index
     from the shared clock with a per-instance phase, facing from the sign of
     the vertical velocity. The batched proxy renderer now writes each
     instance's region as MultiMesh custom data (`EnemyProxyRegion.gdshader`),
     so materialized and data-only enemies draw the same frame in the same
     batch as before; data-only proxies show the standing frame.

`tools/dev/CharacterAnimationTest.tscn` is the inspection scene (1–4 race,
Tab holds a facing, Space toggles run, P releases, F5 screenshots; pass
`-- --shots=/dir` to capture every race × state × facing and quit).
`tools/tests/CharacterAnimationTest.tscn` is the headless suite.

## Facing and state

Four visual facings from smooth movement: the dominant axis wins, and a new
axis only takes over when it exceeds the old one by 25 % (`AXIS_BIAS`), so a
near-diagonal does not flicker. `velocity == 0` → `idle_<last facing>`;
otherwise `run_<facing>`. States are `IDLE`/`RUN` today; a new one is an enum
value, a name in `STATE_NAMES` and baked frames.

Idle: the two idle poses of a facing alternate over a 2.4 s cycle while the
head lifts one pixel for 1.2 s of it (`breathe`, discrete keys so nothing
shimmers). The body never moves off the ground line.

## What the sheets actually contain

All four head sheets and both enemy sheets differ from the "8 × 4" ideal in
the same ways; the definitions encode the truth.

| Sheet | Layout | Row order (top → bottom) |
|---|---|---|
| human idle | 4 rows × 2 poses | down, **left**, up, **right** |
| elf idle | 4 rows × 2 | down, side (col 0 left / col 1 right), up (cols are mirrored duplicates: one used), side again (col 0 left / col 1 right) |
| dragonborn idle | 4 rows × 2 | down, side (L / R), up, side (**R / L**) |
| warforged idle | 4 rows × 2 | down, side (L / R), up, side (**R / L**) |
| human run | 4 rows × 8 | up, left, down, right |
| elf run | 4 × 8 | down, left, up, right |
| dragonborn run | 4 × 8 | up, **right**, down, **left** |
| warforged run | 4 × 8 | down, left, up, right |
| every head | 4 rows × 2 | back (up), left profile, front (down), front looking down |
| grunt / spitter | 2 body rows × 8 + 4 helmet rows × 8 | body: front, back; helmets: back, side, front, front looking down (8 near-identical copies each) |

Per-sheet pixel densities differ (a human idle body is 284 px tall, its run
body 172 px), so each sheet gets its own scale; the run sheet is scaled so its
collar is the idle collar's width, then pinned at 49 px against the 48 px idle.

## Art problems found (not fixable in code)

- **No right-facing head on any race.** `head_idle_right` is the left profile
  flipped; hair partings and the human's fringe mirror with it. The frame set
  records this in `mirrored`.
- **Enemy sheets have no side views and no idle.** Enemies face down or up by
  the vertical velocity sign; the standing frame is the narrowest stride frame.
- **Bodies are headless and helmets are drawn apart** (enemy sheets): the bake
  composites them; `head_seat` in the enemy definition tunes where the helmet
  sits in the neck hole.
- The head sheets' scarves are bulkier than the reference GIF's, so the heads
  are baked at 90 % of the width match and lowered 3–4 px so the coat lapels
  show; if a race's scarf ever looks detached, `head_offsets` is the knob.
- Elf idle "up" columns are mirrored duplicates, not two poses; only column 0
  is used, so the elf does not alternate poses when idle facing up.
- Several run rows drift a few source pixels between frames (dragonborn
  tails, human side strides): the collar anchoring hides it, but a foot may
  slide by a pixel at 10 fps.
