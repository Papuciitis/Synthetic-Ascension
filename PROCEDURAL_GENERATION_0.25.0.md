# Procedural Generation 0.25.0

## What the generator now builds

The map has three overlapping layers rather than one prescribed path:

1. **Main route** — a readable escape spine from entry to gate.
2. **Secondary routes** — longer alternatives and optional interiors that can reconnect to the spine.
3. **Exploration web** — service lanes, rewarded pockets and short loops that push farther sideways.

The planned web is not a world boundary. `ChunkManager` continues streaming ordinary procedural chunks outside it, so the player can walk away from the intended streets and explore the surrounding district.

## Semantic chunk roles

- `entry_court`
- `main_street`
- `secondary_route`
- `service_lane`
- `optional_interior`
- `exploration_reward`
- `landmark_plaza`
- `checkpoint`
- `wardstone_court`
- `exit_approach`
- `gate`
- `miniboss_arena`
- `boss_arena`
- `district_fill`
- `unplanned`

Roles currently control road width/material, plaza creation, parcel preference, checkpoint barricades, landmarks, vegetation and rewards. They are intended to become the stable API for later authored modules.

Procedural loot spawners used by reward endpoints, parcels and large sites are configured before they enter the scene tree. Their visual placement marker is off by default, avoiding debug rings in ordinary play.

## Area 1 progression

- Segment 2: Service Courtyards
- Segment 3: Checkpoint Lanes
- Segment 4: Collapsed Ward / Civilian Cut-through
- Segment 5: Inner District Gate
- Segment 6: Industrial Cut-through / Ruined Services
- Segment 7: Underpass Veins / Canal Services
- Segment 8: Rail Yard / Military Staging
- Segment 9: Outer Wall / Siege Services
- Segment 10: Gate District

## Terrain rules

- Outdoor/open chunks: grass, dirt or mud chosen by theme.
- Main streets: masonry overlay.
- Secondary/service routes: dirt-path overlay.
- Checkpoints/gates/interiors: stronger stone-tile overlay.
- Unplanned chunks: theme fallback terrain, with sparse deterministic dirt variation on grass themes.

## Deliberate limitations

This version establishes route logic and semantic roles. It does not yet provide a complete handcrafted module catalogue. A later pass should replace generic district geometry with role-specific authored architecture and add validation/regeneration scoring for visual repetition, landmark overlap and encounter-space quality.
