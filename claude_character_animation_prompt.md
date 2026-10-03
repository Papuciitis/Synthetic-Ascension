# Claude Task — Character Animation Integration for Synthetic Ascension

You are working on my **Synthetic Ascension** Godot project.

I am giving you:

- the current game repository/worktree
- `character_sprites.zip`
- an example idle GIF

Your task is to **properly integrate these character sprites into the existing game and create a playable directional idle + movement animation system**.

The GIF is **only a motion reference for the feeling of the idle animation**. Do not use the GIF itself as a game asset and do not try to reproduce it pixel-for-pixel.

---

## 1. Inspect the Existing Project First

Before modifying anything, inspect:

- the current Player scene
- player movement/controller code
- race selection / race data
- current Sprite2D / AnimatedSprite2D / AnimationPlayer setup
- player collision and gameplay nodes
- enemy visual setup
- enemy movement
- any existing animation-related code/resources

Do **not** rewrite the player controller or enemy architecture just to make the sprites work.

Integrate this with the smallest sensible architectural change.

Do not break:

- movement
- aiming
- attacks
- collisions
- stats
- equipment
- race selection
- camera
- enemy AI
- spawning
- performance systems

---

## 2. Supplied Assets

The player sprites are organized roughly as:

```text
character_sprites/
    player/
        human/
            human_head.png
            human_idle.png
            human_run.png
        elf/
        dragonborn/
        warforged/

    enemy/
        grunt_test.png
        spitter_test.png
```

There are four playable races:

- Human
- Elf
- Dragonborn
- Warforged

### Player sprites are layered

For players, **BODY and HEAD are separate**.

This is intentional because later I may want:

- different head movement from body movement
- equipment / helmets
- status effects
- aiming/look direction
- attack animation layers
- race-specific animation differences

Do not flatten the player into one sprite.

A sensible hierarchy would be approximately:

```text
Player
└── VisualRoot
    ├── Body
    ├── HeadAnchor
    │   └── Head
    └── AnimationPlayer
```

Use the existing project structure if it already has a better equivalent.

---

## 3. Do Not Assume Perfect Sprite Sheets

Inspect every PNG.

The supplied artwork is not guaranteed to have:

- identical dimensions
- identical frame spacing
- identical row order
- perfectly divisible cells
- identical direction order between idle/run/head sheets

The run artwork appears to contain roughly:

```text
8 frames × 4 directions
```

while idle uses fewer body poses.

Do **not** blindly set:

```gdscript
hframes = 8
vframes = 4
```

for everything.

If necessary, use:

- AtlasTexture regions
- SpriteFrames atlas entries
- explicit Rect2 regions
- generated frame resources
- a small import/editor utility

Keep the original PNGs intact.

---

## 4. Make Animation Mapping Data-Driven

Do not scatter race-specific frame numbers through player code.

Create one clean source of truth for animation definitions.

Conceptually:

```text
RaceVisualDefinition
    human
        idle
            down
            left
            right
            up
        run
            down
            left
            right
            up
        head
            down
            left
            right
            up
```

The implementation can be a Resource, dictionary, SpriteFrames setup, or another Godot-native solution.

Important: **do not assume direction row order is identical between every sheet.**

Inspect visually and map correctly.

---

## 5. Idle Animation

The attached GIF demonstrates the idle feeling I want:

- subtle
- slow
- breathing-like
- slightly alive
- not exaggerated
- not cartoony
- not constantly bouncing

Aim for roughly a **2–2.5 second breathing cycle**.

Because the player head and body are separate, use that advantage.

Example:

```text
BODY
- slight vertical breathing/bob
- tiny posture change

HEAD
- slightly delayed or counter-moving motion
- small vertical offset
- optional extremely small tilt if it looks good
```

The head should feel attached to the body rather than floating.

The existing idle artwork can provide pose variation while AnimationPlayer/transform animation provides breathing motion.

### Important

Keep the feet/ground position visually stable.

Do **not** animate the gameplay Player position.

Only animate visual child nodes.

---

## 6. Head Animation

The head sheets contain directional head poses.

Inspect them manually.

Do not cycle through obviously different viewing directions just because they are adjacent frames.

For the first implementation:

- choose the best head pose for each direction
- synchronize it with body direction
- use transform motion for breathing
- animate between head frames only if they are genuinely animation frames

It is fine for a direction to use a single head image while motion comes from `HeadAnchor`.

That is preferable to weird frame flicker.

---

## 7. Run / Movement Animation

Create proper looping movement animations from the run sheets.

Target roughly:

```text
8–12 FPS
```

but choose whatever looks best.

Movement animation should:

- loop smoothly
- not restart every physics frame
- react correctly to direction changes
- return to idle when movement stops
- retain the last facing direction when idle

Example state logic:

```text
velocity == 0
    -> idle_<last_direction>

velocity != 0
    -> run_<direction>
```

---

## 8. Four-Direction Art + Diagonal Gameplay Movement

The game can keep smooth/diagonal movement.

The character art only needs four visual directions:

```text
UP
DOWN
LEFT
RIGHT
```

Do not restrict gameplay movement to four directions.

Determine facing from the movement vector using a dominant-axis system.

Example:

```gdscript
if abs(input.x) > abs(input.y):
    facing = LEFT/RIGHT
else:
    facing = UP/DOWN
```

Avoid rapid direction flickering near diagonals. Add a small bias/hysteresis if useful.

---

## 9. Do Not Mirror Art Unless Necessary

The artwork contains left/right poses.

Prefer those.

Do not automatically use `flip_h = true` if proper left/right art exists.

Mirroring should only be a fallback.

---

## 10. Alignment Matters

Because HEAD and BODY are separate sheets, they may need per-race and per-direction offsets.

Create proper offsets rather than one global hack.

Check:

- head sits correctly above/in the collar
- no floating head
- no head sinking into torso
- no major jump idle → run
- no major jump when turning
- feet remain aligned with gameplay origin
- races remain consistent in world scale

---

## 11. Pixel Art / Texture Quality

Preserve the visual style.

Check the existing project's texture filtering settings.

Avoid blurry filtering.

If the project uses nearest-neighbour rendering, preserve it.

Avoid fractional visual motion if it causes ugly pixel shimmering.

---

## 12. Player Visual State

Create one clear visual state controller:

```text
IDLE
RUN
```

with:

```text
UP
DOWN
LEFT
RIGHT
```

giving:

```text
idle_up
idle_down
idle_left
idle_right

run_up
run_down
run_left
run_right
```

for all four races.

Design it so later I can add:

```text
attack
cast
shoot
hit
death
dash
interact
```

without rewriting the system.

Do not implement all of those now unless already required.

---

## 13. Race Switching

All four races must use the same animation API.

Changing race should swap the visual definition rather than require separate player code.

Conceptually:

```gdscript
set_race(PlayerRace.HUMAN)
set_race(PlayerRace.ELF)
set_race(PlayerRace.DRAGONBORN)
set_race(PlayerRace.WARFORGED)
```

After changing race:

- correct body appears
- correct head appears
- idle works
- running works
- direction works
- offsets work

---

## 14. Enemies Are Different

Do **not** force the player head/body architecture onto enemies.

Enemy files include:

```text
grunt_test.png
spitter_test.png
```

Their relevant art is contained in one PNG per enemy.

Inspect them and create whatever atlas/frame mapping makes sense.

Reuse the same high-level ideas where useful:

```text
idle
move
direction
```

but enemy visuals do not need separate body/head nodes.

Do not destructively split or overwrite the source images.

---

## 15. Enemy Performance

Synthetic Ascension can have very large enemy counts.

Do **not** add a heavy AnimationPlayer setup or expensive per-frame animation logic to every enemy without checking the existing enemy rendering/performance architecture.

Inspect the current enemy system first.

Player animation can be richer because there is only one player.

Enemy animation should remain cheap and compatible with existing batching, culling, materialization, and performance work.

---

## 16. Make It Playable

Do not stop after importing textures or creating resources.

Hook the system into the real game.

I should be able to:

1. choose/use a race
2. spawn as that race
3. stand still and see a convincing idle
4. move up/down/left/right/diagonally
5. see the correct directional run animation
6. stop moving
7. return to idle facing the previous direction
8. continue playing normally without animation affecting gameplay/collision logic

Test all four races.

---

## 17. Optional Dev Test Scene

If useful, create something like:

```text
dev/CharacterAnimationTest.tscn
```

for:

- switching races
- walking around
- displaying current animation
- displaying current facing
- checking alignment

This is a dev tool only.

The real player scene must still use the final animation system.

---

## 18. Idle Quality Bar

The idle should feel like:

> standing still, alert, breathing, waiting for the next fight

Not:

> bouncing because something always has to move

Think:

- breathing
- weight settling
- clothing slightly following the torso
- head reacting slightly differently from the body

The GIF is a **vibe reference**, not a specification.

---

## 19. Do Not Regenerate the Art

This task is integration and animation.

Do not:

- redraw characters
- generate replacement sprites
- repaint them
- radically alter the supplied artwork

If source art has inconsistencies, document them.

Use the best available frames.

---

## 20. Verify Before Finishing

Run the project and check for:

- GDScript parse errors
- missing resources
- import errors
- bad AtlasTexture regions
- frame clipping
- head/body alignment problems
- animations restarting constantly
- wrong direction mappings
- race switching bugs
- blurry textures
- animation affecting collision/gameplay position
- enemy performance regressions

Run relevant automated tests if the repository has them.

---

## 21. Final Report

When finished, report:

### What you changed
Short overview.

### Files changed
Important scenes/scripts/resources.

### Animation architecture
How player animation works.

### Race mapping
How all four races are handled.

### Idle
What breathing cycle/timing you chose.

### Enemies
What you changed or deliberately left alone.

### Asset problems found
Especially inconsistent layout/directions/frames.

### Testing
Exactly what you tested.

### Remaining limitations
Separate:
- CODE problems
- ART problems

---

## Most Important Rule

**Do not make the code conform to an imaginary perfect sprite-sheet layout. Make the animation system conform to the actual supplied artwork.**

Inspect the sprites visually, map them correctly, and make the result feel good in-game.

Also:

- work directly in the current branch/worktree
- do not touch unrelated systems
- make a checkpoint commit before starting
- make another commit when the character animation integration is working
