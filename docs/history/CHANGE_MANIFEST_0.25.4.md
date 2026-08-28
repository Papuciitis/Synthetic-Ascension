# Change Manifest — 0.25.4 Exchange and Cleanup QoL

## Exchange screen and safe barter

- Reworked the HUB trader into a warmer ink/bronze exchange screen with a centered banner, ornamental line work and the project’s existing orange/cyan visual language.
- Rebalanced the five-column layout so the trade area no longer crushes the report, equipment, backpack or vendor columns.
- Added a dedicated exchange-status line instead of writing transaction failures into the item-hover area.
- The confirm button is disabled when the cart is empty, the player lacks Followers or the backpack cannot receive the requested item stacks.
- The same conditions are checked again after the confirmation popup, preventing stale-cart or delayed-confirmation exploits.
- Backpack capacity now accounts for slots freed by items already included in the offer.
- Added an **Affordable** vendor toggle. It filters against current Followers plus the value of the player’s current offer; final multi-item carts still use full validation.
- Inventory reorganisation is blocked while trade items are reserved, with a clear status message.

## Ambient enemy maintenance

- Ambient culling now begins before the hard population cap, runs more frequently and removes larger far-away batches.
- Added a proactive maintenance pass so far ambient enemies can be retired even when the cap has not yet completely stalled spawning.
- Added stale-enemy cleanup for distant, non-elite ambient enemies that remain effectively stationary for an extended period.
- Bosses, minibosses, elite stale candidates, objective/special spawns and `never_cull` enemies remain protected.
- Added `EnemyIndex.prune_invalid()` to remove freed, queued or duplicate registry entries and rebuild its compact indexes when needed.

## Style sustain

- Replaced melee-only lifesteal with style-based lifesteal:
  - Melee: 2.0% damage, capped at 6.0% maximum HP healed per second.
  - Ranged: 0.8% damage, capped at 3.0% maximum HP healed per second.
  - Magic: 0.6% damage, capped at 2.5% maximum HP healed per second.
- Melee retains its separate passive regeneration identity.
- Lifesteal listens to the existing authoritative damage-dealt event and only heals damage attributed to the player.

## Objective clarity

- After the district relay is completed, the primary HUD becomes an explicit Exit Rite checklist covering resonance and any required miniboss/boss conditions.
- The checklist state changes between **LOCKED**, **LOCATED** and **READY** and includes the current next action.
- Boss and miniboss completion immediately refresh the checklist.
- Secondary objectives now show a dedicated completion card, type-specific completion text, a short HUD pulse and a brief tutorial-tip confirmation before clearing.
- Expanded the primary and secondary objective panel space to prevent the new checklist from clipping.

## Main modified files

- `ui/screens/HubShop.gd`
- `ui/screens/HubShop.tscn`
- `ui/screens/HubShopBackdrop.gd` (new)
- `core/systems/spawner/spawner.gd`
- `autoload/EnemyIndex.gd`
- `core/actors/player/player.gd`
- `core/systems/world/SegmentProcBuilder.gd`
- `ui/controllers/HudObjectiveController.gd`
- `ui/overlays/GateOverlay.tscn`

## Scope and validation boundary

- This patch intentionally does not change district planning, chunk grammar, route generation or building placement.
- Modified-script delimiter/string scans, duplicate-function checks, project-wide duplicate `class_name` checks, literal resource-path checks, HUB node-path checks and scene hierarchy checks passed.
- The official Godot 4.7.1 Linux build was located, but archive execution was unavailable in the patching runtime. In-engine import, typed compilation and gameplay smoke testing remain required using `TESTING_CHECKLIST_0.25.4.md`.
