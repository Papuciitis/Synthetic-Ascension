# Entity coverage implementation

User direction: apply the player's quiet shadowy through-cover language to
rendered enemies and pickup icons inside/behind buildings and behind scenery
such as city trees. The attached street screenshot is a failing acceptance case:
the enemy over the window must no longer paint fully coloured on that opaque face.
The existing staged brief is
`docs/design/2026-10-19-district-generation/09-foreground-and-entity-visibility-packet.md`.
Original base ce5671e6; fetched/fast-forward merged incoming art review faf0e7f4
while preserving this working implementation. The human's prior L2 push is confirmed.

## Contract

- Actual covering pixels and entity ground depth determine the effect. Exposed
  portions, transparent leaf gaps, front-facing entities and real roof cutaways
  retain current art/alpha; indoor membership is not a whole-body dimmer.
- Preserve hurt flashes, elite surfaces, atlas frames/flip, pickup tint/lock,
  VFX ownership, hide/reveal/collection rules and existing rendering eligibility.
- Do not change simulation, collision, AI/spawns, rewards, RNG, saves or scenery Z.
- Include original city and domestic fruit trees with their measured parent-local
  ground contacts. Keep actual source pixels, aspect and scale.

## Implementation slices and ownership

1. Shared per-viewport cover provider: real roof triangles and per-span south
   depth; weak live registered sprite descriptors; spatial GPU candidate lists
   and data textures. Grow lists without the old actor-local32-triangle cutoff.
   Cache immutable original foreground pixels once, preserve linear non-mip alpha,
   keep stable source layers and record native cost. Root owns this and player wiring.
2. Native same-batch coordinate probe, then ordinary/elite enemy batches:
   MODEL_MATRIX world fragments and flat lower-frame feet retain INSTANCE_CUSTOM
   atlas/flash packing. Materialized bodies use the same production renderer.
3. Equipment/health icon adapter: persistent materials compose with authored
   sprite sampling and tint/lock alpha; health's duplicate glow receives coverage.
4. Real screenshot correction: register actual irregular wall-bay Sprite2Ds and
   known upright opaque masonry faces with their real front depth. Convert
   rectangular façade texture draw regions to equivalent persistent registered
   sprites while preserving source/target rectangles, depth/order and fading.
   Never substitute a filled building rectangle or obstruct an actual doorway.

## Evidence and completion

Observe valid REDs before each implementation slice, then focused descriptor,
shared coverage, player native, same-batch coordinates, enemy native and pickup
native checks. Include roof opacity/ancestor visibility, source-alpha gaps,
transforms/atlas, front depth, capacity beyond32, pool/promotion, actual unload
and authoritative-state preservation. Keep failed diagnostic attempts distinct.

Return actual Game small/normal street views with enemies/items behind roofs,
faces and ordinary/fruit canopies, plus cutaway restoration. Stage controls and
save isolation must be disclosed. Recheck the failing street crop and one short
occupied sample; tests alone do not close V1 art findings. Preserve essential
attack tells; projectile/tell depth remains explicitly assessed separately.

Run appropriate existing roof/city/enemy/elite/pickup/loot checks and parse audit
last. Independent review, exact source/evidence hashes, scoped commits and normal
own-branch publication. Never blanket-stage unrelated local assets or push the
integration branch. Root owns all Git and the single monitored Godot lane.

After this visibility packet, user authorized continuing the queued L2 correction
(lawn core/readability, seam, wet-earth sampling/one supplied alternative and dry
control) and L3 domestic purpose/masonry. Keep separate checked commits and carry
Windows keep/rework conditions forward; no new district or balance expansion.
