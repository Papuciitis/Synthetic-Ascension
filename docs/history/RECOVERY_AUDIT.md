# Synthetic Ascension — Recovery Audit (0.21)

## 0.23.0 audit addendum — 2026-07-22

The uploaded 0.22.6 ZIP still contained both the actual project scripts and a nested patch source tree. The nested tree and generated `.godot` cache were moved out of the distributable project before development. The resulting build has one `project.godot`, one `FenceBlock.gd`, and no duplicate global `class_name` declarations.

The playable opening is additive and reuses the recovered Segment 1 milestones, Resonance awards and `Segment1SpawnProfile`. It does not replace the handcrafted route or recovery history. New save fields use exported defaults; active older saves beyond synthesis migrate to completed legacy opening state. Static audit and archive results are recorded during final packaging. No Godot binary is present, so typed load, migration, pacing, input, physics, audio, rendering and transitions are pending `TESTING_CHECKLIST_0.23.0.md`.

Final 0.23.0 static results: 247 GDScript files accepted by the independent grammar parser; 0 missing literal resource paths; 0 duplicate global classes; 1 project file; 1 `FenceBlock` source; 0 generated cache/nested project directories; and both the 30-file patch and 989-file full archive passed ZIP integrity inspection. This remains structural evidence only, not engine certification.

Audit date: 2026-07-21

## Verdict

This remains a substantial, coherent recovered Godot project, not placeholder scaffolding. The exact attached 0.20 baseline hash was verified before this patch. The new work is structurally clean and independently parseable, but it is **not runtime-certified** because Godot 4.6 was unavailable.

Project target: Godot 4.6, GL Compatibility, 1920×1080 viewport.

## Baseline and recovery state

- Input baseline SHA-256: `59fd8d10a3ce83910cc8284af362041279cd9a9b2d2f178a12d24667a188bfa8`.
- Input ZIP CRC: passed.
- The earlier invalid manually invented scene UIDs are absent.
- Loose recovery `.tmp` scenes are absent; historical bytes remain in the existing quarantine ZIP.
- The recovered main menu, saves, Base, Game, Hub, Segments 1–10, bosses, inventory/sets/augments, procedural generation, audio and fog/LoS code remain present.

## 0.21 changes audited

- Dedicated milestone-driven Segment 1 spawn stages replace early normal-table pressure.
- Blocking synthesis/Follower/dossier/reconstruction UI pauses safely and resets spawn timing.
- Contact Area/body events deduplicate by enemy and use documented capped swarm damage.
- Enemy dossier metadata is centralized and discovery persists per profile.
- `InventoryBar` generates equipment controls from shared slot definitions.
- A dense-array projectile manager, swept collision, MultiMesh renderer and `HitLedger` contract were added.
- Ordinary player ranged and ordinary `EnemyShooter` generic bullets were migrated; exotic and boss-owned attacks remain compatible nodes.
- Firestone has an explicit managed hit-profile path.
- Follower mutations are clamped, reasoned transactions with aggregate/contextual UI.
- Hub text frames costs as supplies, labour, contacts and risk rather than people as coins.
- Death/reconstruction and advance cost visibility are explicit.

## Static validation

- Project files audited: 937.
- GDScript files parsed by `gdtoolkit 4.5.0`: 234; syntax failures: 0.
- Scene files structurally audited: 131.
- Missing/case-mismatched `res://` paths: 0.
- Missing, invalid, mismatched or duplicate UIDs: 0.
- Malformed resources and missing/duplicate resource IDs: 0.
- Duplicate class names/top-level functions: 0.
- Missing imported-source assets: 0.
- Loose `.tmp` files: 0.
- Independent audit fatal/suspicious count: 0.

These checks establish syntax/reference integrity only. They do not execute typed GDScript, physics, rendering, navigation, imported resources, save migrations or performance.

## Known incomplete/divergent work

- The between-segment screen is still **Interlude**; the accepted full **Respite** redesign, Chronicle, flavor/event cadence and broader Hub presentation remain absent and out of this patch's scope.
- Area 2 and later narrative chapters were not added.
- The opening still uses the existing title-card format. This patch improves synthesis/containment/dossier/Follower pacing; it does not add a new cinematic intro.
- Procedural districts remain broad Explore/Escape blends rather than a complete named campaign presentation layer.
- Full indoor fog/LoS remains disabled by the lightweight-vignette default.
- Dossier art falls back to existing in-game/placeholder enemy textures where bespoke portraits do not exist.

## First Godot 4.6 run

Use a fresh extraction and allow imports to finish. Preserve exact debugger text, paths and line numbers for any failure.

1. Confirm all autoloads initialize, especially `ProjectileManager` and `FollowerFeedbackUI`.
2. Run a new Segment 1 and execute the full checklist in `SEGMENT1_REBUILD.md`.
3. Exercise a Continue save from 0.20 and a fresh profile; confirm missing dossier data defaults safely.
4. Inspect generated equipment slots at 1920×1080 and at least one smaller window.
5. Test ordinary ranged/Firestone and ordinary enemy bullets against world cover; then test every deliberately unmigrated projectile family.
6. Run the projectile stress test with the Godot profiler. Treat the counters as instrumentation, not a pass/fail claim by themselves.
7. Test follower transactions, Hub commitments and all reconstruction outcomes.
8. Developer-start Segments 1, 2, 5 and 10 and complete representative boss/gate flows.

The project is suitable for a friend to import and playtest, with the explicit expectation that the first engine run may reveal API/type, layout, balance or collision issues that static tools cannot prove.

## 0.22 audit addendum — 2026-07-21

Input baseline is the uploaded 0.21b archive, SHA-256 `66062fd0a52cc0048b344e816c66eb8c3b2fd372483d0b47881ec35b5811446e`.

The 0.22 work changes projectile-to-world collision and equipment-set presentation without changing save schema. The narrow-phase source uses thin 24×32 wall half-arms, 14×32 fence half-arms, 24/18 px isolated posts, a 16 px half-cover circle, a 64 px conservative fallback cell and explicit projectile-transparent windows. Projectile radius expands each primitive, and swept intersection prevents tunnelling.

Set resource inspection confirms the live mechanics presented in UI:

- Conduit: 2-piece movement/haste; 4-piece chained arc; 6-piece kill Overclock + one primed style discharge, with Circuit Feedback as the independent R active.
- Gravemarch Protocol: 2-piece durability/speed trade; 4-piece Sunderstep; 6-piece damage bank, automatic Mass Arrest and a 60%-threshold Verdict active.
- Lattice Index: 2-piece movement/power; 4-piece periodic delayed Afterstrike; 6-piece three-live-mark triangle and temporary mirrored-mark Index Commit.

0.22 static validation before packaging:

- 944 project files are present, including 239 GDScript files and 131 scenes.
- All 239 GDScript files parse with `gdtoolkit 4.5.0`; this is a syntax check, not a Godot typed-compilation or runtime check.
- 204 `.tscn`/`.tres` files have no undefined/duplicate ExtResource or SubResource IDs.
- 448 unique literal `res://` references resolve with exact filesystem casing.
- Duplicate `class_name` declarations, loose `.tmp` files and manually invented underscore UIDs found: zero.
- Eight independent swept-geometry mathematics cases cover visible wall arms, open corner/end space, high-speed travel, diagonal travel and blocking/passable half-cover paths.

No engine binary was available in this workspace. Resource-path checks, archive checks, text review and independent geometry mathematics can detect structural mistakes but cannot certify Godot parser compatibility, scene import, collision feel, UI fit, navigation interaction, save behavior or performance. Run `TESTING_CHECKLIST_0.22.md` before calling this build runtime-verified.
