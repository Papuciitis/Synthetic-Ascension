# Unified Developer Console Design

## Goal

Keep developer run setup on the main menu while consolidating all runtime debugging controls into one polished, tabbed F8 console.

## Main-menu launcher

Developer Mode remains opt-in. Its compact launcher contains segment, race, style, loadout, rarity, seed, forced-choice options, and Start Dev Run / Start Dev Hub actions. Starting either route marks the session as a developer session. Runtime stress, performance, enemy isolation, opening-sequence, set, and collision controls no longer expand the main menu.

## Runtime console

The existing Performance Overlay becomes the Developer Console and is available only during a developer session. The backtick/tilde key toggles it, matching the standard in-game console convention without colliding with Godot editor shortcuts. Escape closes it before any other escape behavior.

The console uses tabs:

- Overview: compact live FPS, timing, population, projectile, node, chunk, and navigation information.
- Enemies: spawning master switch, protected filtering, cap mode, total cap, per-enemy toggles, and enable/disable actions.
- Performance: flight-recorder settings/actions and the projectile stress toggle, clearly marked as an artificial load generator.
- Tests: existing set, combat-state, collision-fixture, opening-sequence, response, migration, and segment-jump controls.

The footer provides Close, Main Menu, and Exit Game. Main Menu and Exit Game require a second click within a short confirmation window. Leaving for the menu saves the profile and unpauses the tree.

## Transparency and resizing

The console panel uses a 72% opaque dark background so gameplay remains visible while text retains contrast. The header can still move the panel. Every outer edge and corner provides an eight-direction resize target with the matching mouse cursor. Resizing clamps the panel to a 720×480 minimum and the current viewport. Tab content expands with the panel and uses scroll containers when it cannot fit.

## Ownership

`PerformanceOverlay` owns presentation, hotkeys, confirmation state, and routing. `DevSetCollisionTools` remains the implementation service for set/collision/opening actions but no longer creates a second panel. `Global.debug_dev_mode` records whether the current session may expose runtime tools.

## Validation

Headless tests verify tab structure, F8/Escape behavior, developer-session gating, stress defaults, navigation controls, and continued performance snapshot formatting. Existing performance and lifecycle tests remain green.
