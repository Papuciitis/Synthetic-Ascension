# Foreground and entity visibility — staged follow-up

19 October 2026. Direct human steering relayed by the designer: show a subtle silhouette when walking behind tree/foreground artwork; later extend the behavior to eligible enemies and pickup icons covered by buildings. **Prepared scope, not implemented by the current S3 closure.** Keep this alongside the [street-material follow-up](08-street-material-coverage-follow-up.md), with the same sole production owner.

## Observable contract

Coverage is per pixel and depends on actual foreground opacity and depth. A leaf gap or an uncovered actor pixel retains its authored color/alpha. A faded/cutaway roof returns the entity's normal existing presentation. Indoor membership alone never tints a whole actor or pickup. The effect is the existing quiet through-cover silhouette language, not a new glow, reveal mechanic or rectangular dimmer.

Keep current spawn/reveal/distance/culling rules: only entities already eligible to render can gain this presentation. Do not expose hidden loot, change pickup eligibility, enemy simulation, collision, navigation, rewards, save data or RNG. Normal presentation includes existing hurt flashes, elite styling, lock dimming and accessibility settings; clearing coverage must restore those, not reset everything to white/opaque.

## Source-backed integration boundaries

- `PlayerVisualController` owns `PlayerRoofOcclusion`, which applies one shared body/head material. The current shader queries up to32 roof triangles in world coordinates and mixes covered pixels toward a cool dark silhouette with retained alpha. Its geometry/cutaway behavior must remain intact.
- `CityBlockKit._add_planting` creates `CityTemperateTree` with original `temperate_tree.png`, measured ground contact `(650,1170)` in its1254-square source and `city_ground_contact` metadata. It currently has no alpha/depth occluder registration; parent/child Z values draw it behind actors. Canvas bounds or source bottom-center are not its actual root anchor.
- `EnemyProxyRenderer` and `EnemyProxyRegion.gdshader` draw most enemies through texture/atlas batches. `INSTANCE_CUSTOM` already carries frame region and a sign used for hit flash. The shader also preserves elite tint/rim, animation-region clamping and reduced-flash/motion settings. Replacing an enemy Sprite2D material misses the batched path and can break those effects.
- `ItemPickup` binds its icon texture; `PickupVfx` owns lock/exploration presentation and base modulation. Coverage must compose with those owners and handle atlas icons rather than replace VFX state.

## Stage 1 — player behind the existing city tree

**Deliverable:** one registered foreground sprite class (`CityTemperateTree`) and player body/head integration. Reuse the original tree asset; no new bitmap is required. Do not expand to every shrub, tree type or consumer in this first packet.

1. Register/unregister live sprite descriptors with weak owner lifetime, texture/atlas region, centered/offset/flip/global transform, measured ground anchor/depth and effective visibility/alpha. Cache resource data; perform no image decoding or CPU pixel sampling per frame. Tree streaming must remove stale coverage.
2. Extend the player's existing world-coordinate coverage query with actual sampled tree texture alpha after inverse transform/region clipping. Bounds are broad-phase selection only. For this initial class, many trees share one original texture; bounded nearby transform/depth descriptors can share that sampler. Do not allocate a new material or image for every tree/actor frame.
3. Select only sprites that truly cover the actor at the relevant ground depth; actor-in-front pixels stay normal. Reconcile the tree's actual draw/depth presentation with the through-cover composite so it reads as foreground foliage, rather than darkening a player standing in front. Do not globally raise every tree above every entity.
4. Combine roof and foreground strength conservatively through the same player material while preserving authored alpha/hurt presentation. New foliage alpha is not replaced with its bounding rectangle or an opaque silhouette polygon. Any descriptor capacity needs an overflow test; silently losing a covering tree is not acceptance.

**Tests/evidence:** tiny controlled RGBA/atlas fixtures prove leaf holes, partial alpha, scale/offset/flip, actor front/behind, fade0/partial/full and unload/reload. Existing roof tests stay green. Native normal/small/reduced samples walk the real player across canopy, transparent gaps and trunk/root depth, then enter/leave a nearby building and stream the tree away/back. Inspect actual city-tree art as well as the deterministic fixture. Report bounded mask/material cost and preserve the unresolved older warmup budget.

## Stage 2 — enemy consumers, including real batches

After Stage1 native review, implement a separate bounded adapter for both materialized and proxy/batched enemies. The consumer-facing query takes fragment world position, entity ground/feet depth and live cover strength; it never substitutes indoor membership for coverage.

First make a native batch probe prove correct per-instance world/feet coordinates and unchanged atlas/frame selection. Do not assume the player's actor-local32-triangle array covers every enemy in a batch spread across the world. Build a spatially bounded shared coverage snapshot/transport for the relevant view/batch and verify its capacity before integration; choosing that transport is an implementation investigation, not a missing human design decision. Preserve `INSTANCE_CUSTOM` region/flash packing, batching, materialized/proxy promotion, elite presentation and accessibility. A Sprite2D-only patch cannot close this stage.

Require ordinary and elite batched/materialized cases, damage flashes full/reduced/off, different atlas frames, front/behind and indoor/outdoor points, roof alpha/cutaway, promotion/pooling and streamed removal. Compare enemy-world counts/state and a controlled busy native fight. Coverage must not change AI/spawn visibility, collision or authoritative enemy state.

## Stage 3 — eligible pickup icons

Add an icon-level coverage adapter that composes with `ItemPickup`/`PickupVfx` modulation, atlas regions and lock/exploration effects. A roof-covered icon may receive the subtle silhouette; uncovered pixels, cutaway roofs and preexisting lock alpha remain normal. Keep rings/interaction indicators under their existing gameplay owners and preserve collection/reveal rules. Do not turn a hidden/unspawned pickup into a visible hint.

Verify locked/unlocked and exploration/ordinary icons, atlas offsets, region boundaries, temporary scale/pulse, roof fade, pickup removal/pooling and adjacent indoor/outdoor ownership. Return real normal/small gameplay evidence and state which effects are covered versus deliberately unchanged.

## Order and acceptance

The [S3 refinement](../../audits/2026-10-19-s3-visual-refinement-v2.md) is now complete, including all three visual findings and final native checks. This packet remains prepared follow-up scope, with no visibility code added by S3. Stage1 player/tree coverage is the first visibility slice; street-material presentation remains a separate selected follow-up. Enemy and pickup consumers start only after the corresponding prior review/probe. The selected S4A ruin family remains another bounded building packet. No parallel product branch, whole-world shader replacement or automatic all-district rollout is implied.
