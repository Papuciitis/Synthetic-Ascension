# Playtest feedback implementation plan

**Goal:** repair the reported menu/loading problems and make combat, objectives, hub interactions and the cursor readable and satisfying, while correcting issues supported by the latest performance/balance captures.

**Source:** the user's 18 October playtest feedback, current vision/roadmap and observed reports from build `c9d5a317`. The user explicitly authorized autonomous work, subagents, generated artwork in the game style, external game research and periodic commits/pushes while away. Game stopped; editor may remain open.

## Constraints

- Preserve existing saves, user audio/accessibility preferences and all pre-existing workspace changes.
- Isolate every engine run using process-local APPDATA/LOCALAPPDATA. Never run beside a human playtest; current authorization confirms it is stopped.
- Existing enemy attacks retain honest warnings, footprint and recovery. Weight is not an HP/damage increase.
- New illustrated raster art uses built-in ImageGen with existing game artwork as reference. Code-native cursors use the established UI palette and explicit hotspots.
- Changes must avoid adding a per-hit/per-frame node or drawing cost that grows without bound.
- Root integrates validated milestones and pushes `HEAD:feat/authoritative-enemy-world` without force. Final script audit runs after all code edits.

## Work and ownership

1. **Development and loading** — frontend agent owns MainMenu/SaveSelect, Global route and LoadingScrim. Reproduce cold-profile Development failure and measure real scene-load frame gaps. Resolve readable-profile selection without resuming a run; thread resource loading, cover errors/overlapping requests and wait for destination readiness. Root owns progressive Game/ChunkManager preparation.
2. **Hub and cursor** — hub agent owns HubWorld/HubCrowd as needed, cursor controller/assets and one new autoload line. Remove View Beka and camera buttons. Focus explicit interactions, restore on closure/interruption, retain bounded wheel zoom and Reduced Motion. Native cursor has strong dark/light contrast and accurate hotspots without capturing UI input.
3. **Boss audio and weight** — boss agent owns AudioManager/SfxManager, BossAppearance/Acting/impact presentation. Reproduce first-tier silence and cumulative gain attenuation; compensate arrangement loudness without overwriting settings, protect major cues under voice pressure, add visible anticipation/recoil/recovery and a bounded defeat response even when optional shake is off.
4. **Performance and balance** — root reads the latest reports, separates observed defects from tuning hypotheses, reproduces actionable hotspots and fixes the responsible systems. Compare controlled before/after measurements; report sample coverage and avoid inferring all-build balance from one run.
5. **Abilities and objectives** — root upgrades Deadshot/Judgment buildup, aim, release and aftermath, then Wardstones, Exit Rites and primary objective identities. Use a coherent brass/charcoal occult vocabulary, distinct silhouettes/states and finite VFX. Extend shared special-ability treatment only where it improves clarity without hiding enemy tells.
6. **Integration** — independent reviews, appropriate behavior/performance checks, normal/small-window and accessibility captures, audio signal measurements, final parse audit, updated status/evidence and periodic commits/pushes.

## Verification focus

- Cold boot with saved profiles, no profiles, corrupt latest slot, paused UI and Development return.
- Real transition animation during threaded loading and staged world preparation; failed or superseded routes do not strand input or reveal unfinished terrain.
- Interaction focus interrupted by movement, wheel, panel dismissal, pause or scene exit.
- High-contrast cursor on light/dark/busy backgrounds; aim hotspot remains exact.
- Audible boss music at the user's existing Music=.32 setting; protected warnings survive ordinary SFX pressure; explicit mute/Reduced Motion/hit-feel choices remain effective.
- New cosmetic effects preserve damage clocks/positions, pause and cleanup, and keep node/draw work bounded in dense builds.

## External inspiration

- [The Game Bakers on Furi](https://www.thegamebakers.com/try-again/): responsive controls and distinct warning, response and punish opportunities. Apply the presentation rhythm; do not copy duel lengths or require perfect timing.
- [Riot on clarity](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/): visual hierarchy, recognizable sources and effects consistent with gameplay. Reserve strongest contrast for major actions and the cursor; preserve empty space and accurate boundaries.

These are design principles, not imported artwork or a claim that this game should become either reference game.
