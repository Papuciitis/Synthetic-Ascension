# Boss proportions, arena and effect identity implementation plan

> For agentic workers: execute disjoint tasks with subagent-driven development; root serializes engine verification and owns staging, commits and pushes.

**Goal:** Complete authorized boss overhaul delivery step 2 and the user's accompanying visual corrections, with four believable boss proportion studies, guaranteed fighting space and distinct raster attack cues.

**Spec:** `docs/design/2026-10-16-boss-overhaul-proposal.md`, especially proportions, arena and delivery order. User authorization on 2026-10-16 explicitly continues step 2, requests actual sprites and periodic commits/pushes, rejects the beam's hard black border, calls out Pulse/Bomber fidelity, asks for different slam/shock/mine cues and visible windups. Subsequent audio feedback rejects the current clips' 8-bit character; source fuller replacement candidates for audition.

**Architecture:** Separate boss body presentation from walking/contact geometry; select an explicit S5/S10 body for each role without multiplying the root. Reserve a shared spatial contract before procedural blocker/decor placement and align event roots to it. Raster effects consume existing committed attack geometry and gameplay clocks; artwork never defines collision. Existing random boss selection remains.

**Tech stack:** Godot 4.7.1, GDScript, built-in ImageGen for new/editable transparent PNG sprites, existing SFX bus. Existing linked enemy-world worktree is reused; unrelated dirty edits are preserved.

## Constraints and review focus

- Human occupied down-facing reference is 77 world px including hair, not the padded texture rectangle. All four playable races must appear on the scale board.
- Target anatomy: Bulldozer 88 world px in both tiers, Arcanist 82 in S5 and 86 in S10. Equipment silhouettes distinguish S10. These are rough proportion studies for review, not finished animation or final art approval.
- Preserve existing physical circles explicitly: S5 Bulldozer39.015/Arcanist36.72; S10 Bulldozer44.795/Arcanist42.16 world px. Preserve existing square hitbox extents. No shared EnemySpec/Shape mutation.
- Source alpha, anatomy and foot anchors are measured separately from gear. Keep the established mid-body combat origin: feet sit42px below it, matching the player. Sprite position must work through the production proxy renderer; do not depend on unsupported offset/centered behavior.
- Courts are centered S5 20×20 cells (1280 px), S10 28×28 cells (1792 px). Protect paving, lanes, blocker clearance, perimeter and entry/exit access; retain open disengagement and current reset rules.
- All world combat effects use actual raster textures. No particles, Line2D or replacement procedural shapes. Dev-only measurement guides may be simple geometry.
- Distinguish grounded physical slam fractures, advancing shock crackles and planted arcane mines through shape and motion as well as color. Terrain damage is cosmetic; it does not change navigation or add damaging ground beyond existing payloads.
- Windup cues remain visible through anticipation and cancel on pause/death/stun/disengage under the existing foundation contract. Reduced Motion and flash settings preserve essential bounds.
- Existing Pulse pooling/setup/duration and Bomber blast radius105/fuse0.35/damage remain compatible. Bomber's perimeter must not pretend its blast radius shrinks.
- Do not add the S5 teaching moveset or S10 phase/moveset redesign in this step. Do not scale health against player DPS or force a minimum fight duration.

## Task 1 — Shared arena space

Files: new `core/systems/world/proc/BossArenaSpace.gd`; narrow updates to `ChunkGenDistrict.gd`, `ChunkManager.gd`, `SegmentProcBuilder.gd`; new `BossArenaSpaceTest.gd/.tscn`.

- [x] Write real-generator regressions for S5/S10 across 40 spread seeds, deterministic event anchors, all court cells, body-safe lanes/perimeter, sockets and dressing.
- [x] Root observes valid failing tests, separating fixture errors from production defects.
- [x] Implement fixed center anchors and the 20/28-cell clear court before blockers, props, walls, foliage and center landmarks are placed.
- [x] Verify focused and existing procedural reachability suites; capture both roles in actual Game at 960×540.
- [x] Review, commit and push a coherent checkpoint.

## Task 2 — Boss anatomy and tier presentation

Files: new `scenes/world/bosses/BossAppearance.gd`, four PNGs and provenance in `scenes/world/bosses/art/forms/`; narrow boss scene/EnemyInit/arena tier hooks; new `BossProportionTest.gd/.tscn` and `BossProportionPreview.gd/.tscn`.

Interface: `BossAppearance.apply(actor: EnemyActor, tier: int)` sets tier art, unit root, sprite feet42px below combat center and independent physical shapes. Standalone boss scenes use S5; arenas explicitly apply S5/S10 after readiness. A narrow `EnemyWorld.set_collision_radius(handle, value)` keeps authoritative padding synchronized when the tier changes, with largest-radius cache invalidation on shrink.

- [x] Write regressions for four distinct tier textures, unit roots, anatomy target ranges, unchanged world collision, foot anchors, reconfiguration and no shared-resource mutation; root observes RED.
- [x] Generate four human-proportioned rough forms using built-in ImageGen. Inspect original alpha and anatomy; retain source pixels and exact prompts/hashes.
- [x] Implement presentation after normal EnemyInit visuals, plus explicit arena tier application.
- [x] Render four races, Brute/Herald and four bosses on one baseline at actual gameplay zoom in normal/small windows, with art, silhouette and footprint views. Include rough bracing/casting poses without authoring final animation sheets.
- [x] Review, commit and push the proportion studies and implementation.

## Task 3 — Boss warning and impact identity

Files: `BossGroundWarning.gd`, boss brains/Mine, narrow `DamageCircle.gd` style propagation; new `BossImpactSprites.gd` and `BossWindupSprites.gd` as needed; new PNGs in boss art/VFX; focused identity/windup regressions and actual Game capture extension.

- [x] Reproduce absent/insufficient windup and missing style propagation with real casts; root observes RED before behavioral implementation.
- [x] Edit beam art to remove the opaque dark strip and create distinct slam fracture, shock crackle, mine and windup sprite art; measure painted content before fitting to geometry.
- [x] Propagate attack style through warnings and active footprints. Keep anticipation bounds fixed; release terrain fractures/energy bursts and finite cosmetic dissipation only.
- [x] Show actual charge/cast windup and release samples at normal scale; verify finite impact dissipation, cancellation, pause, source cleanup and accessibility. Final character recovery animation remains pending art approval.
- [x] Review, commit and push the visual-cue checkpoint.

## Task 4 — Pulse, Bomber and sound audition

Files: `VFX_PulseRing.gd/.tscn`, `VFX_BomberHazardRing.gd`, narrow `EnemyBomber.gd` if adding a finite blast; new PNGs in `assets/textures/vfx/encounters/`; new `WorldPulseBomberSpriteTest.gd/.tscn`; audition recordings/credits if suitable candidates are found.

- [x] Write raster-presence, actual-radius, pool reset/expiry, fuse build, pause and live accessibility regressions; root observes RED.
- [x] Supply a detailed force ripple, explosive perimeter and finite ember/smoke burst; preserve gameplay APIs and numerical payloads.
- [x] Verify SetVfxPoolTest, HostileReadabilityTest and focused rendered examples.
- [x] Source licensed non-chiptune replacement sound candidates, provide effect-to-clip audition mapping, record provenance and technical validation, and incorporate user listening feedback without claiming unauditioned fit.
- [x] Review, commit and push.

## Final verification

- [x] Independent scoped review of production code, measured art fit and procedural reachability.
- [x] Focused regressions plus affected compatibility suites; final ScriptParseAuditTest last.
- [x] Actual Game captures at1280×720/960×540, zero profile writes, clean shutdown. Distinguish frozen visual evidence from live fight playtesting.
- [x] Update design/audit/status with evidence, remaining human art approval, animation, balance and audio-listening limits. Verify remote branch contains each checkpoint.

Verified checkpoints: `3c72f7a` (courts), `201a27e` (proportions); raster VFX/audio checkpoint follows in this delivery. Human final-art approval, character animation and full fight/mix playtesting remain as recorded in the audit.
