# Segment 5 teaching fights

Implements delivery step3 from the approved boss overhaul. Random Bulldozer/Arcanist choice, existing rewards/health and the step2 body/arena contracts remain. S10 phase redesign is later work. Implementation is in progress; verification results below are added as each checkpoint passes.

## Bulldozer

The teaching kit consists of a fixed-direction rush, a planted slam, a fully previewed three-impact Fault Line and one below-half-health Runner call. Rush trail/end effects become harmless, and an explicit physical rush hit replaces stacked ordinary contact during that commitment. Recovery holds movement and new attacks while leaving the boss damageable.

Starting timings are0.85s rush anticipation,1.3s slam anticipation,1.35s first Fault Line tell with0.32s between nodes, and0.9s recovery. The Runner call advertises three arrival positions for1.0s, consumes its single attempt on commitment, and expires unclaimed Runners after15 gameplay seconds without kill rewards. Existing population limits and source cleanup remain in force.

## Arcanist

The compact S5 kit uses a locked five-bolt fan, an announced body-validated blink and a deterministic three-mine constellation. Fan preview and bolts share46-degree geometry and520px range. Mines retain their glyphs through a1.4s fuse and preserve a checked walking corridor. Major patterns do not overlap, and neutral retreat is bounded so melee can catch the caster.

Starting tells are0.95s fan,0.8s blink and0.6s mine planting. Fan recovery is0.9s; blink arrival grants1.2s and cannot repeat for at least6.5s. Landing candidates remain approximately180–210px from the player and are revalidated at release without silently changing the advertised destination. S5 cannot select beam/pylon pressure. Normal ambient enemies remain available; Arcanist is not given a new reinforcement move.

## Why the tells are longer

The production human melee character moves100worldpx/s, with a radius25/height58 walking capsule and70×70 damage Hurtbox. The player script's300 export is not the effective run speed. Starting at legal physical body contact, leaving the135px slam requires a player center beyond170px. With a150ms reaction allowance, a1.15s tell is too short. Full square-corner geometry also leaves almost no frame margin for a1.25s Fault Line tell. The chosen1.3/1.35s tells provide conservative room; actual physics controls must verify them.

These are baseline movement checks, not guarantees for every slow/immobilized build or a substitute for human difficulty testing. No minimum fight duration or adaptive health is added.

## Raster assets

Two dedicated built-in ImageGen PNGs distinguish cyan/ivory blink destinations from warm Runner arrival marks. Their source pixels are copied unchanged. Original canvases are1254×1254, with painted radii582.7061867/588.2401720 measured at alpha>.2 for runtime fitting. Blink has one negligible alpha1 corner pixel; the center and background are transparent. No external crop, repaint or alpha removal is applied.

[Exact prompts](../art/2026-10-16-s5-arrival-prompts.json) and [source/alpha measurements](evidence/2026-10-16-s5-teaching-fights/arrival-art-measurements.json) retain provenance. Arrival cues are finite non-damaging Sprite2D components bound to their boss's AttackScope. Existing fracture, crackle, mine, charge and pulse sprites remain the visual vocabulary. Final character animation and human timing/mix approval remain distinct from these mechanics and sprite cues.

## Verification status

Valid pre-implementation regressions: Bulldozer9passed/28failed, Arcanist3/27 and arrival component0/1. These expose missing teaching behavior rather than being counted as successful final checks. Final green runs, actual Game controls and rendered motion evidence are pending.

The standalone arrival component now passes20/0, including world anchoring, distinct raster sources, pause, cancellation, essential accessibility visibility and gameplay-clock expiry. Its render-only callback regression failed19/1 before moving autonomous lifetime onto physics. A natural low-FPS control also passes; that control alone did not reproduce the callback discrepancy because of engine frame-delta clamping. Brains can disable autonomous callbacks and drive these cues from their own committed clocks.

Independent source review of both teaching kits is complete. It identified committed rush final-step overshoot (286px at60Hz and312px with0.1s scheduling versus the280.8px preview), early render-clock arrival expiry and shortened recovery after a brief stun. Focused regressions reproduce these issues before correction. Final engine verification is serialized with the other game chats under the human's explicit coordination authorization, to avoid simultaneous memory-heavy runs.
