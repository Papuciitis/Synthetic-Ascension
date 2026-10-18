# Current objective forms omitted from the six painted-prop previews

Captured 18 October 2026 in the actual Segment 2 Game scene, world seed
16102026, at 1280x720 and 960x540. These are frozen controlled states with
an immortal player, not a played encounter or a visual approval.

## Captures

- `searchable-building-exterior-*`: actual planned secondary parcel, roof and doorway.
- `searchable-building-interior-*`: the same parcel; the production IndoorVolume body-entered signal starts five local enemies and fades its roof. Enemies are then frozen for inspection.
- `searchable-building-reward-*`: production lethal damage stages clearance; the room completes and the production item reward is visible on the floor. This is not human-earned victory evidence.
- `cursed-vault-states-*`: three production CursedVault instances, closed, channeling at 53%, and opened/spent. The opened state is latched for this art sample; no reward or replacement chest is invented. Current production art is a purple circle and progress arc.
- `exit-rite-last-chance-*`: an actual ExitRite staged at 85%, with two durable seals and three safeguards. Its production `_spawn_last_chance_vault` method creates the vault at radius + 32, opposite the player. It costs all safeguards and locks healing for 45 seconds.
- `ritual-interference-hazard-*`: current default RitualInterference sigil, radius 420. This is an adjacent encounter hazard, explicitly not a completed objective.
- `dangerous-alley-cache-endpoint-*`: actual planned cache chunk (1, 9), role `secondary_alley_cache`, objective id 1736497563. No tagged reward pickups were present after world streaming and an additional settle period. The empty current location is shown honestly; no chest or replacement pickup was staged.

## Evidence and limits

All 14 final PNGs were inspected. The building interior roof is correctly
faded in the final images; an earlier staging pass called only the volume
method and skipped the roof's entry signal, and those pictures were replaced.

The final full pass's actual native process exit code is **1**, solely for
the missing expected cache pickups; its manifest records 12 screenshots,
one failure and zero save writes. A subsequent cache-only pass captured the
actual empty endpoint at both sizes and also returned actual native exit 1
for the same unresolved condition. The cache absence is a capture finding,
not proof of its production root cause. There were no additional script or
render errors in either final log.

The isolated scratch preview, logs and actual process exit files are under
`.superpowers/sdd/2026-10-18-objective-visual-review/`. APPDATA and LOCALAPPDATA
were isolated for every run, recorder outputs were redirected to user://,
and zero save writes were checked in both manifests. Only the pre-existing
Godot editor process (PID 29136) remained afterward.

The scope is world objective forms. Segment 1 guided milestone text,
opening illustrations and NPC conversations are excluded. Its Loading
Office, Service Warehouse and Maintenance Kiosk are authored building
variants using IndoorVolume, rather than new kinds of standalone objective
prop. The production source and existing previews were not modified.

See `manifest.json` and `cache-manifest.json` for individual files, staged
state notes, world/player positions, seed and scope.
