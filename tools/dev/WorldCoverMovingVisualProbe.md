Run only through the existing serial Linux native monitor with isolated XDG data,
memory and temperature guards, and an empty output directory. Example engine
arguments (substitute the installed Godot binary in the monitor):

```bash
godot --path /tmp/sa-wp2-cover --rendering-method gl_compatibility res://tools/dev/WorldCoverMovingVisualProbe.tscn -- --world-seed=16102026 --target-building-id=944996572 --target-chunk=0,3 --review=small --runtime-fps=30 --out=/var/tmp/sa-phase2/cover-moving-visual
```

The inherited actual Game route retains live ambient spawning, enemy scheduling,
collisions, ordinary delayed pickup collection, physical doorway cutaway/exit,
player movement around a generated tree and a streaming boundary. Its controls
and assertions remain in `capture-info.json`. This probe adds
`visual-cover-info.json` with actual published enemy batch transforms, atlas
regions, opaque fragment positions and cover strengths alongside matching frame
names. It records three native home plates, one live Brute and genuine
equipment/health pickups with a disclosed 120-second pickup lock. Scripted player
fire pauses during that home demonstration. No enemy freeze, roof/counter edit,
shader replacement or pickup monitoring override is used.

Optional `--runtime-fps=15|20|30|60` sets only `Engine.max_fps`; the default is 60.
Other numeric values fail explicitly.
Physics ticks, AI, scheduling and streaming remain live. The manifest records
the actual `engine_max_fps` and `physics_ticks_per_second`. This render cap
bounds capture work and supplies no performance proof.

Expected result: exit 0, zero diagnostics/failures/save writes, at least one same
enemy body moving 12 world pixels while having both covered and exposed opaque
fragments, all sampled consumers using enabled shared cover, three home plates
showing the original opaque roof, physical indoor cutaway, and restored roof.
The before/inside/restored frames must be viewed to judge the quiet readable
silhouette against the real player; fragment counts alone do not prove pixels.

Use the existing native `EnemyCoverRenderTest`, `PickupCoverTest`, and
`WorldCueCoverRenderTest` separately to assert isolated shader compositing,
atlas transparency, exposed/front-depth pixels, partial alpha and restoration.
Framebuffer RGB here includes scenery/overlap and is deliberately not treated
as a raw shader-output oracle. This probe is visual/gameplay instrumentation,
not a performance benchmark or full human-play acceptance.


Explicit short phases preserve `--phase=full` as the default inherited route.
Run `--phase=home --runtime-fps=20` and `--phase=tree --runtime-fps=20` into
separate fresh output directories after the scoped parser. Each phase uses the
actual generated Game with ambient spawning, procedural director, enemy
scheduler/AI, collisions and 60 Hz physics live. Only initial player/actor/item
placement, god mode and input are staged. Scripted player fire pauses during
these demonstrations so the same live ordinary bodies can remain in view.

The home phase begins near the actual doorway and walks physically inside and
outside. Its three home plates still assert opaque roof / real indoor cutaway /
restored roof. The tree phase begins at a verified reachable front waypoint,
walks front/behind/front around an original generated tree, and records three
matching plates. It stages a live Brute, ordinary Spitters and real locked
covered/front equipment and health pickups. Tree player depth, covered/exposed
live windups and projectiles, and same-enemy tree-specific opaque fragment
observations with at least 12 world pixels of displacement are required.

Each short phase has a hard 30-second simulation deadline, at most 12 route
images at roughly one per second (first foreground crossings may trigger an
earlier sample), plus three named phase plates. Post-route PNG encoding yields
80 ms between images. A deadline is a hard failure and still writes the final
`visual-cover-info.json`, including per-phase route, staging, live-producer and
scheduler checks, elapsed time, frame names, materials and save status. A thermal
termination can prevent final metadata and remains incomplete evidence.

These independent phase manifests explicitly omit ordinary item collection /
inventory, mandatory streaming-boundary arrival and player fire/hit proof. They
do not claim those omitted gates passed and do not replace the full route's
assertions. Normal physics/AI and material/depth behavior are never frozen or
substituted. No clean or passing result is inferred from the interrupted original
full route, whose source bytes remain preserved in the evidence packet.


Tree fixture discovery now considers at most eight existing registered trees,
in distance order from the explicit home. It keeps the original 0.99 opaque
pickup-foot threshold, searches eight-pixel steps inside distinct reachable
walkable cells, and tests the actual player capsule from each cell center to
its candidate point. At least two different cells and the existing real-player
front/behind route plus a covered ordinary-shooter cell must qualify. Selected
pickup points are retained exactly rather than snapped back to cell centers.
The final manifest records each attempted tree path/texture, footprint points,
actual cells, alpha, walkability/reachability and capsule result.

Front pickup controls and the exposed ordinary Spitter are selected from
visible reachable ground with actual shared cover at most 0.01 over a small
neighborhood. The covered Spitter retains the existing at-least-0.65 tree muzzle
requirement. Actual resolved muzzle strengths are recorded and asserted; AI,
health, cooldowns, physics and all production cover materials are unchanged.
The four existing covered/exposed live effect/icon checks remain required.
The accepted home-r3 capture is bound to its preserved earlier source, while
the full and home route behavior is retained by these tree-only changes.


R6 tree setup correction (source-only until its fresh native run): r5 completed
without a thermal interruption but failed the exposed controls and emitted
`body->get_space()` diagnostics. Its first camera property was already at the
front waypoint, while smoothing left the effective canvas more than800px above
the candidates. The old on-screen filter rejected all81 candidate centres for
each exposed control. The r5 source/raw/PNGs remain preserved as failed evidence.

Tree-only setup now sets the normal follow-camera offset, resets smoothing,
forces the scroll, lets ordinary physics/process frames and a draw settle, then
refreshes shared cover before staging controls. It records before/after actual
canvas/world bounds and per-filter candidate rejection counts. The actual
player capsule is queried in World2D directly (start/target overlap and swept
motion,2px margin, static mask with live enemy layer excluded) rather than
calling body test_move while the initial player process hold removes its body
from the physics space. The existing8px subcell points and opaque thresholds
remain unchanged.

Exposed equipment/health are real ready pickups. Selection uses their actual
source-opaque Icon grid samples, including normal health bob limits; distinct
front positions are reserved before selecting the next control. The ordinary
Spitter remains live: its configured frame/region source samples are used for
initial placement, with its14px muzzle tested at the muzzle's own depth. These
source probes are staging checks. Enemy visual acceptance still reads the
actual published batch transform/atlas and all existing final body/icon/effect
material/depth assertions. No AI, collision, cooldown, fade, shader, pickup
monitoring or functional assertion is changed. Full/home execution retains its
original branch, and accepted home-r3 stays bound to its preserved older source.


R7 appends a same-owner ordinary-equipment comparison after the original tree
route and locked observations. The original tree front/behind/front plates and
locked icon/body/effect/material gates remain required. Tree now adds a fourth
`tree-normal-equipment.png`, stored separately as `normal_equipment_comparison`
in final metadata; home/full behavior keeps its original branch.

Tree-only return-camera reset/force-scroll plus ordinary physics/process settle
precedes the third locked plate. The fourth must retain the same actual camera
and effective canvas (position tolerance0.001worldpx, canvas origin0.01worldpx),
world positions and pickup instances. No actor or ambient producer is frozen.
At least0.35seconds of live physics/processing separates ordinary eligibility
from capture. Camera/view records and actual source-fragment RGB accompany
both plates; moving actors, weather and UI preclude a whole-image identity claim.

Both existing equipment owners must still be locked, unpicked, at their third
plate positions and farther than ItemPickup.MAGNET_RADIUS+16 (126px) from the
player. Only their exported pickup_delay is changed to0, then the normal
ItemPickup._enable_pickup_later owner path enables monitoring/readiness and
restores its own Vfx modulation. No flags, modulation, material, pickup collision
or collection method is written by the probe. Health stays locked at120s.
The equipment remains the same explicitly staged persistent world drops; safe
distance and unchanged positions are checked again after the live wait.

Only new automatic readbacks pause and an already queued locked readback drains
before eligibility changes. Live physics, AI, scheduler, ambient spawning and
streaming continue. The fourth manual plate uses the same original source-alpha
and material observations, then restores the previous locked counters/tracks so
it cannot satisfy the original three-plate gates. Its separate new hard gate
requires two normal-ready, monitoring, unpicked owners, restored Vfx modulation,
same material/texture/world points/view, still-locked health, and actual covered
and uncovered source-opaque native fragments. Actual readability still requires
image review; no covered alpha, outline or runtime product feature is changed.

The accepted/clean functional R6 source00f7eba6, raw manifest and three native
originals remain separately bound. R6's small locked-ring legibility was unresolved;
R7 is a controlled ordinary-versus-locked comparison, not a retroactive R6 visual
acceptance or a relaxation of its coverage gates.

### R8 source proposal

The tree comparison now holds only the camera target and initial camera offset from the restored third
plate through the ordinary-equipment fourth plate. The player can still move
or receive knockback; enemy AI, physics, scheduler and streaming remain live.
Camera impact offset is temporarily held; HitFeel settings and producers remain unchanged.
The same effective-view, owner, world-position, safe-distance, material,
source-opaque, locked-control and live-effect assertions remain required.

The separate scratch shader proposal raises only pickup covered alpha density
from `0.56` to `0.85`, multiplied by the complete native authored alpha. It keeps
the shared RGB tint, texture holes, exposed alpha, lock/fade factors and health
glow proportions. The shared player/enemy compositor is unchanged. Root must
review and apply the candidate before the fresh parser, unchanged 33 native
PickupCoverTest predicates, and actual moving Game run. Source preparation is
not native execution or readable-contrast acceptance. R7 remains a failed
same-view comparison, with its exact source and four original plates retained.
