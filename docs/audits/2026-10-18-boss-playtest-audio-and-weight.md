# Boss listening feedback: routing, mix and body response

The playtest reported an initially silent boss and fights that still felt like ordinary enemies with more health. This follow-up changes audio and presentation; enemy health, damage, attack clocks, escape checks, rewards and collision geometry are unchanged.

## Causes verified

- `AudioManager` deliberately ignored tier 0. The first S5 fight had its entrance sound but continued ordinary music, with no boss score identity. The previous lifecycle test explicitly required this behavior.
- The S10 opening recording measures −23.903 dBFS RMS. A −10 dB music voice, another −5 dB boss gain and the default .32 Music bus (−9.897 dB) left it near −48.8 dBFS, before a further 7 dB warning duck. This was gain staging rather than a missing file or muted Music bus.
- Every positional sound shared 24 voices. Once occupied, the next ordinary combat sound always stole voice zero; a live boss warning could be cut off by weapon/death playback.
- Arcanist focused/split volleys had no sound at their real projectile release. Bulldozer's committed rush had a warning and endpoint impact but no launch sound. The focused release, split release and accepted launch now have separate regression controls.
- S5 forms explicitly had no `BossActing` follower. S10 anticipation and release used approximately 2°/2.6° body rotation with small scale changes; the first fight had neither.

The live settings were read only to distinguish these causes from user preference. Music and SFX were unmuted. The user's disabled screen shake and hit feel remain disabled; production changes do not write settings or alter user bus gains/mutes.

## Resulting behavior

Both tiers start the first score arrangement. Only S10 advances through the second and third arrangements. Both tiers receive the finite musical defeat/release. Unsupported tier events cannot claim the score, and S5 cannot acquire main-boss phases.

The three unchanged recordings receive +14/+12/+11 dB relative to the ordinary −10 dB voice, compensating their different RMS levels while retaining escalation. The unchanged release receives +8 dB. Major warnings briefly duck Music by 3 dB for 0.48 seconds. All of this remains upstream of the user's Music volume and mute.

Eight bounded positional boss voices are separate from ordinary combat. Their SFX bus still follows user volume/mute; warnings, entrance and phase punctuation take priority over pylon shots within that pool.

Focused and split volleys now issue one electrical release for the whole bolt batch; the tank issues one lower physical launch cue when a committed rush actually starts. They reuse the unchanged licensed recordings, with stable role pitch. Beam release receives 4 dB more gain to retain its stronger channel identity above the softer volley and corrected music. Pause, canceled warnings and invalid sources cannot produce stale release cues. The only brain changes are these three audio requests, after the accepted release/launch.

Both tiers now have feet-anchored anticipation, follow-through and exposed recovery poses. Brace depth follows the accepted attack's real progress. A substantial accumulation of actual HP loss can earn a short visual recoil in idle/recovery, capped to avoid per-pellet vibration; it cannot cancel, delay or visually replace a committed tell. Reduced Motion keeps the exact authored pose.

Canonical enemy death creates one 0.75-second snapshot of the existing boss raster, with a restrained ink-grain erosion and fade. Reduced Motion uses only a fade at the exact snapshot transform. There is no collision, damage, payout, projectile or new gameplay ownership. A dedicated one-shot reuses the existing licensed weighted thud, with a lower tank pitch; the source recording is unchanged.

## Actual mixed audio evidence

`BossMixRender.tscn` recorded the actual Master bus through the native Windows renderer and WASAPI driver, at 48 kHz stereo. These are rendered PCM recordings after the default −9.897 dB Music bus, rather than Dummy-driver playback-state assertions. The old-gain comparison reenacts the previous −15 dB internal voice with the same recording, bus and output path. It does not claim a historical system-loopback recording.

| Recording | RMS dBFS | Peak dBFS | Clipped samples |
| --- | ---: | ---: | ---: |
| Previous phase-one internal gain reenactment | −48.744 | −31.896 | 0 |
| Fixed S5 / first arrangement | −29.806 | −12.896 | 0 |
| Fixed S10 second arrangement | −28.867 | −13.898 | 0 |
| Fixed S10 third arrangement | −27.931 | −13.894 | 0 |
| Dense weapons/deaths with boss warnings and impacts | −24.798 | −8.910 | 0 |
| Dense weapons/deaths with fan, rush and stronger beam releases | −24.599 | −9.025 | 0 |
| Finite defeat/release | −30.970 | −19.621 | 0 |

The first arrangement is approximately 18.94 dB louder through the same default bus. Every recording contains nonzero PCM. The second dense recording uses the final fan/rush mappings and stronger beam level. This establishes real mixed output and numerical headroom for the measured default mix; final artistic balance and dense human warning intelligibility still need listening.

Committed [evidence and checksums](evidence/2026-10-18-boss-feedback/files.json) include the final focused logs, native render captures, [mix measurements](evidence/2026-10-18-boss-feedback/mix-measurements.json), the [opening arrangement](evidence/2026-10-18-boss-feedback/s5-phase1-fixed.wav) and [dense release sample](evidence/2026-10-18-boss-feedback/dense-energy-and-rush-releases.wav). Expected failing regressions and remaining full recordings are retained in the local task evidence. Each engine process used isolated APPDATA/LOCALAPPDATA; no live profile was selected for execution.

## Verification

The focused regression exercises a real score voice, saturated ordinary voices, the actual S5 follower, actual damage through `EnemyCombat` and canonical death/finite cleanup. The lifecycle suite also checks pause, disengage, player death, phase monotonicity, duplicate events, release completion, menu/stop restoration and user bus ownership. The existing presentation and attack suites retain collision, accepted-release and cancellation checks.

The native mixed-audio captures completed with exit 0; the initial regression had seven expected failures before the routing/pool/S5-acting changes. Native `BossDefeatRenderTest` produced eight representative PNGs and 21 passing checks, including rendered dissipation, selected motion treatment and cleanup for both roles. These are isolated production-form renders rather than actual Game screenshots. Final suite counts are recorded in the task's evidence logs.

| Focused suite | Passed | Failed |
| --- | ---: | ---: |
| BossMixAndWeightTest | 16 | 0 |
| BossMusicLifecycleTest | 40 | 0 |
| BossAttackAudioTest | 85 | 0 |
| BossPresentationTest | 35 | 0 |
| BossSpriteVfxTest | 5 | 0 |
| BossHazardGeometryTest | 31 | 0 |
| KillAudioTest | 29 | 0 |
| PositionalLoopAudioTest | 11 | 0 |
| BossDefeatRenderTest (native) | 21 | 0 |
| **Total** | **273** | **0** |

Each listed execution returned native exit 0. The final attack run groups the focused-fan fixture as the real S5 miniboss and the split fixture as the real S10 boss, so both advance through their production physics controller. The final new regression also saturates the reserved boss voices and verifies that a pylon cannot displace any major warning.
