# Playtest feedback delivery — 18 October 2026

The requested menu, loading, hub, cursor, boss-impact and ability/objective changes are implemented. Performance and balance reports were read and their confirmed source defects corrected. Functional verification and the final script audit pass. Native frame-time diagnostics still expose occasional 440–500 ms stalls; their exact backend cause remains unresolved and the failing results are preserved.

**Objective art needs rework.** After viewing the Breach capture, the user
identified poor centering and a mismatch with the terrain. A separate visual
designer inspected 29 current screenshots and six source images and confirmed
problems with anchors, perspective, material detail, state shapes and dominant
progress rings. The six painted forms are implemented, but none is visually
approved. Vaults and exploration objectives also lack the earlier claimed
coverage. See the [independent review and prioritized changes](../art/reviews/2026-10-18-objective-visual-design-review.md).
This review changes no game code or artwork; the proposed breach prototype
and subsequent visual rework remain pending.

## What changed

- Development now selects the latest readable profile after restart, or offers profile selection/creation. Opening it does not resume an attempt. The button previously depended on a profile that had not yet been selected.
- Loading uses threaded resource requests and staged Game/HUD/world setup. The spinner advances through real work, input remains frozen until readiness, and superseded, failed and terminal routes preserve pause and save ownership. Reduced Motion retains a static mark. [Loading audit and timing limits](2026-10-18-development-and-loading.md).
- Deadshot and Judgment have preparation, honest lanes, painted release and aftermath. Six generated world forms distinguish Wardstones, Exit Rites, Relay, Vigil, Breach and Wager states. Effects remain bounded and respect motion/flash preferences. [Visual audit and previews](2026-10-18-abilities-and-objectives.md).
- Hub camera buttons are removed. Explicit interactions focus the person and restore the previous view; wheel zoom remains available. Outlined native arrow, hand and crosshair cursors improve contrast. [Hub and cursor audit](2026-10-18-hub-camera-and-cursor.md).
- S5 now starts its boss score. Compensated music gains, reserved major-cue voices, accepted volley/rush release sounds, body anticipation/recovery and finite defeat dissipation strengthen both boss tiers. The measured opening mix is about 19 dB louder at the same user volume, with no clipped samples in the recorded controls. [Boss audio/weight audit and recordings](2026-10-18-boss-playtest-audio-and-weight.md).
- Boss entrances initialize their final form once. The ground material array is baked from the exact original pixels, avoiding first-entry layer readbacks. [Report investigation](2026-10-18-performance-feedback.md), [derived ground cache](2026-10-18-ground-material-cache.md).
- Recorder revision 3 separates actual segment jumps without inventing clears, retains outgoing counters, counts incoming actors once, distinguishes loading from player pause and preserves enemy-projectile ancestry after the shooter despawns. Mixed batches retain honest bounded member identities. Damage, defenses and batching are unchanged. [Balance evidence and correction](2026-10-18-balance-feedback.md).

The existing four boss portraits already match the established world forms from the preceding delivery. This pass preserves those icons.

## Verification

| Area | Passing checks |
| --- | ---: |
| Boss audio, presentation, geometry and native defeat controls | 273 |
| Hub interaction/camera/cursor integration | 326 |
| Boss entrance and compatibility | 171 |
| Ability/objective presentation and gameplay compatibility | 491 |
| Frontend and route lifecycle | 316 |
| Final actual headless S1/S2 routes | 14 |
| Route recorder, health, revision and ledger | 115 |
| Projectile ancestry and compatibility | 185 |
| Ground cache source/import/resource contract | 4 |
| Final gameplay script audit | 539 |

Shared compatibility suites overlap between areas, so these rows are not summed into a unique total. The final import and 539-script audit returned native exit 0 without script errors. Independent reviews identified and verified fixes for failure identity, late outgoing recorder binding, failure-event ordering and direct-scene startup.

Native captures include normal/small windows, Reduced Motion and flashes off. Boss recordings are actual native Master-bus PCM. Visual ability samples are frozen staged controls in the real Game terrain/HUD, not human fights. Source hashes, expected failing regressions and final logs accompany the individual audits.

## Remaining limits

All native routes reached readiness with the six functional assertions passing. The unchanged strict timing check still fails in the final S1 cold and S2 warm cases (500.515 / 440.374 ms), despite much smaller measured script callbacks. The separate native warmup also records 259.592 ms against its 250 ms ceiling. These are unresolved frame-time findings, not clean passes or proof of a whole-game FPS improvement. Ground layers and mipmaps compare exactly against the original builder.

Human evaluation remains: busy-fight readability, subjective impact and audible mix, full-run pacing and cross-build balance. The single prepared-build capture supports no broad HP/damage/regen nerf. Original playtest artifacts remain unchanged; six synthetic native reports initially written beside them were moved to isolated task evidence, and the harness now writes to user storage. Existing workspace edits and live saves/settings were preserved. The editor remains available and no game is left running.

## Design references

[Furi's warning/response/punish rhythm](https://www.thegamebakers.com/try-again/) informed boss anticipation and recovery. [Riot's clarity principles](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) informed accurate footprints, distinct sources and visual hierarchy. No external game artwork was imported; generated assets follow the project's charcoal, brass and ivory palette.
