# Change Manifest — 0.25.2 Urban Objective Vertical Slice

## Added

- `core/systems/world/objectives/DistrictRelayObjective.gd`
- `scenes/world/objectives/DistrictRelayObjective.tscn`
- `tools/ProcPlanSmokeTest.gd`
- `PROCEDURAL_GENERATION_0.25.2.md`
- `TESTING_CHECKLIST_0.25.2.md`
- Three semantically mapped 1024×1024 ground materials under `assets/world/ground/`.

## Major modified systems

- `core/systems/world/SegmentProcBuilder.gd` — mission state, relay integration, hidden/revealed exit, resonance tuning and phase HUD.
- `core/systems/world/proc/DistrictPlan.gd` — longer objective graph, secondary templates and deterministic retry validation.
- `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd` — exact connector arms, route hierarchy, semantic materials and spawn sockets.
- `core/systems/world/proc/SiteParcelsImpl.gd` — junction/dead-end frontages, door sockets and reward-building encounter configuration.
- `core/systems/spawner/spawner.gd` — street/door/objective socket selection, interior rejection and local encounters.
- `scenes/world/volumes/IndoorVolume.gd` — delayed local encounter activation and reward-on-clear.
- `autoload/ThreatDirector.gd` — Recon/Disturbance/Ascension/Collapse modifiers.
- `core/systems/world/ExitRite.gd` — separate generated, revealed and unlocked state.
- `ui/controllers/HudGateOverlayController.gd`, `autoload/global.gd`, `autoload/RunEvents.gd` — objective-to-exit navigation handoff.
- `core/systems/world/WorldArt.gd` — new semantic ground texture registry entries.

## Intentionally unchanged

- Player, weapons, augments, inventory, stash, item definitions, set systems, save data and segment-transition architecture.
- Segment 1 remains handcrafted.
- Segment 5 miniboss and Segment 10 boss gates remain mandatory in addition to relay completion and resonance.
