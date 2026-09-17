# Procedural Generation 0.25.2

## Runtime loop

Every procedural segment now owns this state:

`START → PRIMARY RELAY → REVEALED EXIT`

The Exit Rite exists in generated data from the beginning but is invisible, non-monitoring and absent from HUD navigation until the relay is completed. Opening it still requires full resonance plus existing Segment 5 miniboss or Segment 10 boss conditions.

Pressure moves through four states:

1. `recon` — marked relay, hidden exit, restrained ambient pressure.
2. `disturbance` — triggered near the relay; faster waves and objective flanks.
3. `ascension` — relay complete; exit revealed and enemy density rises while the build has room to dominate.
4. `collapse` — full resonance; existing overtime escalation joins the phase pressure without an instant-death timer.

## Route and building contract

- Connector bits are rendered exactly. A north/east mask draws a north-to-east turn rather than a complete cross.
- Main street: 6–8 cells.
- Secondary street: 5 cells.
- Service or reward-building route: 3 cells.
- Dangerous alley/cache: 2 cells.
- Sidewalk/verge: 1 cell.
- Parcels can occupy straight roads, corners, junctions and dead ends. Their longitudinal band is clipped to the actual road arm, so the door apron cannot target an invented half-road.
- Independent random corner buildings were removed. Buildings now come from streetfront parcels or connected Donjon carving.

## Optional objectives

The planner stores secondary objectives as dictionaries with `type`, `chunk` and `world` fields. Segment 2 requests two; later segments deterministically request zero to three.

- `dangerous_alley_cache`: a narrow reward detour with guaranteed 1–2 item loot.
- `searchable_reward_building`: a forced enterable parcel with five to eight locally activated enemies and reward release after clear.

This is the extension point for later Luck, district-pool and objective-template weighting.

## Spawn categories

- Street sockets are created at real connector mouths.
- Door sockets are created one cell outside real parcel entrances.
- Objective sockets surround the relay courtyard.
- Interior encounter positions are selected inside the activated `IndoorVolume` and marked `special_spawn_kind = interior`.
- Ambient socket/fallback positions are rejected if they are blocked, inside a Wardstone field or inside any registered interior.

## Integrated materials

- `ground_civic_brick_01.png` — main civic streets and ordinary plazas.
- `ground_mossy_brick_01.png` — old secondary lanes and dangerous alleys.
- `ground_round_cobble_01.png` — relay landmark courtyard.

Natural grass/dirt/mud remains the outdoor substrate; these are local route overlays rather than giant urban chunk bases.

## Deliberate limits

- This is a stable street-frontage intermediate, not polygonal block extraction or arbitrary lot subdivision.
- The relay is the only primary template in this version.
- Secondary opportunities are encoded in the plan and world geometry but do not yet have a dedicated multi-objective HUD list.
- Runtime navigation/feel must be verified in Godot 4.7.1 using `TESTING_CHECKLIST_0.25.2.md`.
