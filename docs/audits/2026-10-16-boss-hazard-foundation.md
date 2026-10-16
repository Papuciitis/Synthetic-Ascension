# Boss hazard foundation

Date: 2026-10-16. Scope: delivery step 1 of the [boss overhaul proposal](../design/2026-10-16-boss-overhaul-proposal.md), authorized by the user. The random S5/S10 selection, existing phase thresholds, attack damage payloads, boss bodies and rewards remain in place.

## Behavior changes

- Every circle and beam owns its collision shape. Configuration reaches geometry and timing before activation; legacy add-then-setup callers refresh correctly. Circle overlap uses the actual player Hurtbox rather than a fabricated 32 px allowance or a check at world origin.
- Slam and the three shock impacts retain the origin and direction they advertised. Major casts hold ordinary movement and charge starts. The shock sequence now previews its three positions before the first release.
- Mine footprints last through the actual fuse. The beam has a persistent starting warning and a visible active rectangle throughout its sweep. Fan warnings retain their visible cone until release. Active boss circles display their footprint, including charge crumbs.
- Casts use gameplay progression rather than timers that advance through pause. Stun cancels pending casts and sustained beam channels. Autonomous projectiles and planted mines already released survive a brief stun. Death, disengage and scene teardown clear the boss's owned pressure.
- A weak owner/generation scope follows mines, circles, beams, Runners, pylons and their projectiles. Cleanup reaches pylon-fired shots and releases population/index responsibility without granting kill rewards. Stunning a summoned Runner cannot interrupt the boss.
- Interrupted charges cannot resume later or produce a normal end burst. Normal charge trail/end damage is retained in this foundation pass; the proposal to make it cosmetic belongs to the later S5 moveset work.
- Pylons have a visible pixel-art body, aimed 0.3 s firing preparation, hit/destruction feedback and correct registration at their configured location. The brain admits at most two live pylons; each expires after 12 s. Ordinary player destruction retains its once-only combat events, while expiry and encounter cancellation grant no kill rewards.

These repairs change practical difficulty despite retaining damage numbers. In particular, a correctly sized 135 px slam covers about 4.45 times the area of the broken 64 px circle. Correctly sized charge crumbs cover less area. Health, cadence and damage balancing remain a later playtest task.

## Art and audio

The pylon was generated with the built-in image generator, with transparent alpha and no Canva. The exact prompt, reference reasoning, original output path and SHA-256 are in [the art provenance record](../../scenes/world/bosses/art/PYLON_PROVENANCE.md). The unchanged source is [pylon_v1.png](../../scenes/world/bosses/art/pylon_v1.png); the scene displays it at a small gameplay scale with nearest filtering.

At the foundation checkpoint, persistent bounds reuse the existing ring/disc/streak VFX kit. Boss shots, charge trails and pylon feedback also use actual PNG sprites; pylon health strips remain UI drawing. These indicators share the actual attack geometry rather than using a decorative image as collision authority.

The [actual Game comparison](../art/reference/2026-10-16-boss-vfx-game/capture-info.json) uses the original 1920 × 1080 viewport, camera zoom 1 and normal canvas scaling in 1280 × 720 and 960 × 540 windows. It confirms that large warning rings look coarse beside shaded characters and terrain, and the beam reads as a stretched flat stripe. Improved sprite artwork and a second in-game comparison follow as a separate checkpoint. These staged captures freeze production components; they are not a full-fight playtest.

Four Kenney CC0 recordings are registered for accepted warnings, mine detonation, beam release and pylon shots. Bursts and shots are rate limited; all use the existing SFX volume/mute bus. The existing procedural impact cue supplies physical impact feedback at reduced gain. A fifth charge recording is retained as an unregistered candidate because its duration does not fit the current fan warning.

[Audio credits](../../assets/audio/sfx/bosses/CREDITS.md), [license and source/hash/technical records](../../assets/audio/sfx/bosses/sources.json). Recordings were checked for decoding, duration, channels, sample peaks and clipping. They have not been auditioned; aesthetic fit and in-game mix need a human listen.

## Verification

The initial executable regressions were observed failing before the relevant fixes: hazard geometry 10 passed/16 failed, pylon lifecycle 10/14, and cast lifecycle 2/6. Expanded regressions separately caught member-stun ownership and resumed charges (11/2), while the audio suite caught missing definitions and actual boundary requests (7/12).

Latest clean boss regressions: hazard geometry 31/0, pylon lifecycle 36/0, cast lifecycle 16/0, encounter ownership 35/0, attack audio 35/0 and raster sprite effects 5/0: **158 passing checks**. Related suites add **187 passing checks**: legacy enemy combat compatibility 17, projectile time base 4, combat lifecycle 20, combat service 38, enemy index 23, ritual interference 35, exit encounter 21 and kill audio 29. The final script parse audit loaded **514 scripts, zero failures**. Final reruns reported no engine or script errors. [Final batch records](evidence/2026-10-16-boss-hazards/final-results.json) and [earlier related records](evidence/2026-10-16-boss-hazards/related-results.json) link the logs.

Independent review caught a mine-impact visual transform mismatch under a translated scene (observed RED 30/1, corrected GREEN 31/0) and a canceled beam's possible stale release sound/visual (RED 33/2, corrected GREEN 35/0). The actual Game capture exposed a detached pylon's late absolute index lookup during shutdown (RED 35/1, corrected GREEN 36/0). These fixes and regressions are included. Review of the new trail, projectile sprites and pylon sprite feedback found no additional issues.

The regression fixtures isolate save and recorder destinations and disable autosave. Actual Game captures recorded zero profile writes. The baseline preview log retains the shutdown error that led to the pylon regression; the corrected lifecycle suite is clean. The next artwork capture will also recheck shutdown in the actual Game.

## Remaining design work

S5/S10 anatomy and boss forms, new main-boss attacks, three-phase redesign, economy and durable boss-reward settlement remain in the proposal. This pass supplies the reliable hazards and lifecycle those later changes need.
