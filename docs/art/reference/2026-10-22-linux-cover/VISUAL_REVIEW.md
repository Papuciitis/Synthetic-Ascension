# Finite cover image review

The original `city22-cover-moving-visual-1` ended with actual exit -15 and
`stop_reason=interrupted`. Its outer wrapper reports `thermal_limit` at 94 C.
The completed run record includes the diagnostic `Mandatory westbound
owning-chunk boundary arrival was not reached`. It supplied three home PNGs
and seven opening route frames, but no final `visual-cover-info.json` or
`capture-info.json`. This is partial evidence, never a completed visual gate.

## Actual pixel observations

- `home-covered-before-entry.png`: a broad dark humanoid shape and small muted
  shapes are visible over the opaque slate roof. They are subdued and readable
  against the roof; they do not look like the bright native exposed art.
- `home-inside-real-cutaway.png`: the slate roof is absent, the actual furnished
  interior is visible, and an ordinary Brute-shaped body, pink bottle and brown
  equipment icon are plainly colored. The player stands physically inside.
- `home-outside-roof-restored.png`: the slate roof and frontage are restored
  after the player is outside. Different camera/actor positions prevent a
  same-pixel before/after color measurement.
- Opening frames 0000, 0003 and 0006 show an actual tree, unobscured player and
  moving enemies around the street. The player remains south/east of the
  canopy; these selected saved frames do not show an actor crossing behind it.
  This review does not infer what the unsaved in-memory frames contained.

The 95/0 controlled player fixture includes opaque-roof, real ordinary/fruit
foliage, atlas/leaf-gap, partial-alpha and restored-front comparisons. Its
`small-roof-opaque.png` shows a very subdued dark covered shape;
`small-ordinary-behind.png` retains bright authored test pixels through leaf
gaps; `small-ordinary-front.png` restores their full front color. The partial
actual-Game roof images have the same subdued covered-shape character. These
fixture images use controlled body art and are not a live-player-pose capture.

## What telemetry can establish

The new probe decodes the actual published batch transform/atlas rectangle,
samples source-opaque fragments and records shared cover strength/material
state beside native frame coordinates. Such records establish which actual
published fragments are geometrically covered. Framebuffer RGB also includes
scenery, alpha blending and overlap, so it is not an isolated shader oracle.
No final fragment manifest exists for this interrupted run; its PNGs alone do
not bind actor IDs or prove a 12-pixel same-actor transition. The isolated native
enemy/pickup/cue/player suites separately passed 38/33/67/95 assertions with
zero failures/diagnostics. Their success does not complete the moving gate.

Independent short `home` and `tree` modes are prepared for source-bound reruns.
They retain ordinary AI, physics, scheduling, spawning and materials; they use
initial staged placement and explicit phase scope. Each must finish with its
own final metadata and image review. No actual moving tree/item/effect or
completed full-route acceptance is claimed here.


## First short home attempt: complete route, diagnostic no-pass

The first explicit home run wrote final metadata but its wrapper found a
GDScript diagnostic in the inherited depth sampler. The new home branch had
not initialized the selected real-tree descriptor. Manifest `failures=0` and
engine exit 0 do not override that diagnostic; this run is not accepted. Its
exact source 8255a571fccc3665931fe8f593cd2e82e7022c84c2d7a9518a3bce37704d1d2e
is preserved. The minimal correction moves the existing real-tree initialization
outside the tree-only branch; no base/runtime file or assertion changed.

The final first-home manifest binds the plates to the same staged ordinary
Brute: 19 source-opaque fragments are covered before entry and 19 are exposed
inside. Its maximum displacement is 192.91 world pixels. Equipment 19 and health 5
opaque fragments follow covered→exposed→covered. Material IDs and enabled shared
shaders remain consistent. These are geometric/source-opaque observations;
the RGB also includes real scenery and blending.

Actual plate inspection shows a quiet dark Brute silhouette and muted icons on
the opaque slate roof, native brown/gold Brute art and a bright pink bottle in
the furnished open interior, then a restored roof with muted icons. The Brute
has physically walked out by the final plate and is normally colored at the
front doorway/street. Roof alpha/inside counts are 1/0, 0/1, 1/0. The route reports
5.23 simulation seconds, 9.19 wall seconds, all physical destinations reached,
live producers/scheduler, 15 ambient spawns, zero save writes, 20 FPS render cap
and 60 Hz physics. The sampled inherited harness error still requires a clean
fresh run before accepting this phase.


## Fresh home-r3 accepted for bounded home scope

`city22-cover-moving-home-r3-1` completes with engine/outer exit 0, zero diagnostics,
zero manifest failures, three home plates and eight route frames. Its exact
b1f7b9f source is preserved separately from the tree-r4 correction. At native
960×540, camera zoom 1 and 1920×1080 logical viewport, before/inside/restored show
subdued dark body/icons on the slate roof, ordinary Brute art and pink health
art in the actual furnished interior, then the restored roof with subdued icons.
The live Brute walks out by the last plate and is normally colored in front.
The retained source/atlas records identify the same 185.55-pixel moving body,
all enabled materials, zero saves, 5.27 simulation/9.11 wall seconds, 12 ordinary
ambient spawns, 20 FPS rendering and 60 Hz physics. Home is accepted only within
this disclosed staged, live-simulation scope; omitted collection/stream/full-run
gates remain omitted. The outer peak 87 C is compatible with a clean guard run:
it did not accumulate the sustained-stop condition.

The golden rooftop object around (595,171) is outside the staged icon coordinates
and is neighboring roof scenery, not the staged equipment. Exact staged ring
opaque observations in the before image occupy x343–353/y207–218; health occupies
x408–416/y209–217. Their sampled RGB maxima are (.161,.184,.208) and
(.157,.184,.208), respectively, and they visibly read as dark blue-gray shapes.
Inside, those same IDs become normal art; outside, they return dark. These
coordinates avoid confusing baked/attached roof ornaments with pickup consumers.

## Tree-r3 completed observations and actual failures

Tree-r3 writes final metadata and all three plates, then ends engine -15 /
outer 241 after sustained 85 C samples 88,87,87 (peak 89 C). It is not a clean pass.
Its stdout/manifest also contain four real probe failures, separate from heat:
insufficient opaque covered pickup cells, missing both-state live effect proof,
and no covered equipment/health fragment observations. Specifically projectile
covered/exposed counts are 28/57, windup counts 30/0, and only exposed pickups
were staged. A lower frame cap alone cannot repair those staging failures.

The same actual tree player is normal in front, a quiet dark hint under the
canopy around native pixels 404–414/350–370 behind, then normal in front again.
Leaf colors/gaps remain visible; the nearby dark body on the left facade is
another enemy. Opaque player fragments are tree-covered 0/64,62/65,0/65 for the
three plates. Two moving enemies have tree-covered/exposed opaque fragments
and 148/327-pixel displacement; this includes partial-body coverage, not isolated
whole-body RGB changes. Live producers/scheduler, 32 ambient spawns, zero saves
and no deadline failure are recorded over 11.72 simulation/19.43 route wall
seconds. These finite observations remain useful but do not accept tree item /
all-effect parity or the thermally interrupted run.

The tree-r4 source-only correction retains all final assertions, searches a
bounded set of actual canopies and subcell opaque footpoints, preserves their
exact drop positions and verifies actual exposed shooter/control geometry.
Root scoped parsing/native retry/image review remains pending. Packet payload
compression/rebuild is deliberately deferred until root releases the CPU hold.
