# Synthetic Ascension — Recovery Audit (0.21)

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
