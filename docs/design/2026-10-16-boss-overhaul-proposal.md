# Segment 5 and Segment 10 boss overhaul proposal

Date: 2026-10-16. Status: approved execution has delivered step 1 [hazard foundations](../audits/2026-10-16-boss-hazard-foundation.md), step 2 body/arena/sprite presentation, and step 3 [Segment 5 teaching fights](../audits/2026-10-16-s5-teaching-fights.md). The current-behavior inventory below is the original pre-overhaul baseline. New Segment 10 phase/controller work and the later encounter presentation remain proposed.

Keep the seeded random choice between **Bulldozer and Arcanist**. Give both a substantially upgraded Segment 10 form. Segment 5 should introduce a compact, readable version of each role; Segment 10 should test that understanding through new attacks, controlled combinations and distinct phase changes.

The bosses should become more imposing through equipment, acting, sound and control of the arena. Their humanoid anatomy should become more believable. A main boss does not need to be a uniformly enlarged ordinary enemy.

The current-behavior sections below come from source and existing art inspection. They establish implemented behavior and defects, not a verdict from playing these fights. New moves, timings, proportions and pacing targets are design bets to validate in play.

## Direction and constraints

The user has chosen to retain random selection and substantially upgrade both S10 variants. The rest of this proposal remains open to review.

- S5 teaches momentum and impacts for Bulldozer, spacing and patterns for Arcanist.
- S10 is the main boss of Area I and a memorable build test. The run continues after escaping the city.
- Each S10 variant gets one health bar, three behavioral phases and its own upgraded visual form. Thresholds change the encounter rather than merely shortening timers.
- Earned build strength remains effective. Exceptional builds may skip attacks or phases by killing quickly. Do not enforce a minimum fight length, adapt health to measured player damage or refill health at transitions.
- Preserve the existing primary-objective and Exit Rite flow. Boss victory should clear its threats, settle rewards and create a short release before the Rite.
- Make the two random outcomes comparable in threat, reward and build access. Randomness should change the problem, rather than decide whether a particular build can function.

S5 and S10 can select different roles. S10's opening phase must therefore teach its own base vocabulary clearly; seeing the same role at S5 is helpful practice, never a prerequisite. Include both matching and mixed S5-to-S10 routes in playtesting.

These constraints follow the [game vision](../SYNTHETIC_ASCENSION_VISION.md) and the current city-continuity status in the [roadmap](../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md): different builds should play differently, and a strong build should be allowed to leave Area I.

## What the encounters currently do

Both milestones select one of the same two boss scenes with a seeded 50/50 choice. S5 places it near the Inner District Gate in the penultimate main-route chunk. S10 places it in the Gate District exit chunk. Neither currently constructs a sealed, authored boss arena.

| Rule | Segment 5 | Segment 10 |
|---|---|---|
| Activation | Player within 260 px; boss appears 80 px above the arena origin | Within 320 px; boss appears 90 px above |
| Bulldozer / Arcanist health before Threat and debug modifiers | 3,060 / 2,550 | 12,060 / 10,050 |
| Incoming damage | Takes 65%; intended per-hit ceiling 12% of maximum HP | Takes 55%; intended ceiling 8% |
| Knockback | 28% of normal; faster decay | 22% of normal; faster decay |
| Leash and player disengage distance | 750 / 1,050 px | 900 / 1,200 px |
| Return healing | 1% maximum HP per second | 1.5% per second |
| Distinct boss-tier attacks | Baseline role attacks | Bulldozer adds none; Arcanist adds sweep and pylons |
| Art | Enlarged Brute or Herald image | The same image, approximately 15% larger than S5 |

Ordinary movement starts at 72 px/s for Bulldozer and 84 for Arcanist, multiplied by spawn-time Threat and temporary effects. The arenas request additional multipliers of 0.92 and 0.95, but those currently miss the movement baseline cached during initialization. Charge speed is separately 780 px/s. This corrects the earlier interpretation that the arena slowdown was already effective.

Ambient spawns are reduced around a live boss rather than completely disabled. Nearby Heralds and Chanters can still influence the boss through buffs, healing and wards. That interaction needs an explicit encounter policy.

## Complete current attack inventory

Damage numbers here are authored raw values, before the player's defenses. Unlike ordinary contact damage, these custom attack payloads do not currently inherit Threat damage scaling. Cooldowns are nominal values; availability, independent timers and phase changes affect actual sequencing.

### Bulldozer

The same complete kit runs in S5 and S10.

| Current action | What it does | What is useful | What needs improvement |
|---|---|---|---|
| Pursuit and body contact | Chases the player. Shared contact starts at 10 damage multiplied by Threat, at a 0.5 s cadence with overlap rules. | Creates close-range pressure. | Make physical contact readable and verify it cannot stack unfairly with a charge impact. Revisit the physical footprint with the new art. |
| Charge anticipation | Within 320 px, locks direction and stops for 0.55 s. Cooldown 2.2 s starts on commitment. Directional warning exists. | Recognizable intention and committed direction. | A consistent pose, visible lane and recovery. No steering after commitment. |
| Charge movement | 780 px/s for 0.36 s, about 281 px unobstructed. Uses the shared movement/collision path. | Strong role identity; baiting and sidestepping can matter. | Validate walls, endpoints and contact damage. There is no separate authored charge-hit damage payload. |
| Charge trail | Deposits 5-damage circles about every 42 px. Intended radius 26 px and lifetime 0.18 s. | A visible trail can communicate speed. | Current collider is effectively radius 64 and lifetime 0.20 s. Recommend making the baseline trail decorative, with deliberate marked debris reserved for S10. |
| Charge end burst | Visual shockwave plus 11.7 damage; intended radius 74.25 px and lifetime 0.12 s. | Can sell weight at the endpoint. | Same default circle problem. Currently triggers when charge state ends; distinguish normal completion, wall collision and interruption. Avoid an unexplained bonus hit after a canceled rush. |
| Slam | Within 220 px; initial 1.5 s cooldown, then nominal 3.6 s. Waits 0.65 s and deals 18 damage in an intended 135 px circle. | Clear close-range area attack concept. | Warning is placed before the delay, but impact follows the moving boss. Warning fades early; actual circle stays radius 64. Plant the cast and keep the full footprint visible. |
| Ground shock sequence | Initial 2 s, then 5.2 s; within 520 px. Three intended 85 px circles, 140/280/420 px forward, 10 damage each. Arrive approximately at 0 / 0.12 / 0.36 s. | A directional ground attack adds a different dodge problem. | First hit lacks adequate anticipation; origin follows boss movement; circles use default geometry. Show the full path and the advancing impact order. |
| Runner reinforcements | Below 50% HP, requests three Runners around the boss. Repeats at 7.875 s, then 6.75 s in the final phase; shared boss-add cap 24. | Provides targets for crowd and kill-trigger builds. | Repeating requests can become background clutter. Use finite, warned arrivals with encounter ownership and a much smaller encounter pressure budget. |
| Phase modifiers | Thresholds 50% and 20%; slam/shock cooldown resets multiply by 0.78 / 0.62. | Some escalation already exists. | Faster repetition does not create a new main-boss act. Charge itself does not gain a new phase pattern. |

### Arcanist

| Current action | What it does | What is useful | What needs improvement |
|---|---|---|---|
| Kite, strafe and body contact | Prefers 340 ±90 px range and weaves. Uses shared contact rules if touched. | Contrasts with Bulldozer's pursuit. | Bound retreat so melee can earn openings. Align the navigation footprint with the new body. |
| Blink | Inside 160 px, after initial 0.8 s availability; nominal repeat 4 s. Tries ten points 320 px from the player. Departure/arrival bursts exist. | Repositioning fits the caster. | Tests a point rather than the full body. Announce landing, validate reachable space and give a post-arrival opening. Prevent a blink from moving another attack away from its warning. |
| Fan volley | Initial 1.2 s, then 2.8 s; within 720 px. A 0.22 s tell precedes nine bolts over 46 degrees, speed 420 px/s, lifetime 2.6 s. Damage 7 / 8.75 / 10.5 by phase. | Legible projectile vocabulary and locked aim. | Warning direction is captured earlier than the moving launch origin. Longer introductory anticipation, distinct casting pose and consistent origin are needed. |
| Mines | Initial 2 s, then 4.8 s. Places 3 / 4 / 5 mines at random angles 90–210 px around the player. Intended fuse 1.05 s, radius 95 px, damage 15 / 18 / 21. | Forces movement and controls space. | Actual timer starts at default 1.10 s, marker disappears after 0.25 s and collider remains radius 64. No deliberate escape layout or own live cap. |
| Sweep beam, S10 only | Initial 4.5 s, then 7.2 s. Telegraph 0.55 s, then a 1.15 s sweep across 110 degrees; length 680 px, width 34. Damage 16 / 20 / 24 every 0.20 s while touching. | A strong candidate for its signature attack. | Warning initializes before its actual angles and transform; visible effect ends at about 0.38 s. No active sweep renderer. Fix visibility and direction before evaluating difficulty. |
| Pylons, S10 only | Below 50% HP; initial timer 5 s, then 9 s modified by phase. Two opposite points about 240 px from the player. Each has 40 HP and fires 7-damage bullets every 1.25 s, speed 360, lifetime 2.5 s. | Destructible emitters could offer target priority. | No visible body, own cap, expiry or boss-death cleanup. Registration occurs before positioning, leaving a targeting-index risk at world origin. They currently provide no boss shield or ward mechanic. |
| Phase modifiers | Thresholds 50% / 25%; recurring cooldown resets multiply by 0.78 / 0.62. Fan, mine and beam damage rise. | More pressure is implemented. | No authored transition. Blink, mines, fan, beam and pylons can overlap through separate timers and awaited casts. |

## Repairs needed before balancing

These defects affect both fairness and the validity of any difficulty comparison.

| Priority | Problem | Required outcome |
|---|---|---|
| P0 | Hazard setup happens after entry into the live scene. Circle collision, lifetime and first overlap check use defaults. Mine and beam startup also capture defaults. | Configure position, owner, geometry, timing and visuals before activation, or refresh all dependent state atomically. Test away from world origin. |
| P0 | Warning and attack disagree in position, duration or direction. | Warning and damage share one committed geometry. Markers last through anticipation; active hazards remain visible for their entire damaging life. |
| P0 | Pending casts and scene-parented hazards survive encounter state changes. | One encounter owns its hazards, projectiles, adds and timers. Death clears damaging remnants immediately, with cosmetic dissipation allowed. Disengage/reset cancels pending casts and removes temporary pressure. |
| P0 | Awaited timers advance through pause while normal actors and effects stop. | Anticipation, active damage and recovery freeze and resume on the same gameplay clock. No released attack on an invisible elapsed timer. |
| P0 | Pylons are invisible and register before their final position. | Visible, targetable planted objects; correct EnemyWorld position and one combat identity; bounded count and deterministic cleanup. |
| P0 | Independent timers produce unplanned simultaneous attacks. | A shared attack controller selects valid attacks and authored combinations, with explicit anticipation, commitment, recovery and cancellation. |
| P0 | Boss defeat and reward settlement lack a shared durable record before the Rite; saved gear/wallet can outlive a reset encounter. | Defeat, wallet grants and generated reward identities settle once. Unclaimed items recover after Continue. Preserve the existing durable Rite-completion flow. |
| P1 | Per-hit damage caps behave differently when damage is batched. | The same hit sequence produces equivalent results when delivered separately or through the ledger. Review the cap policy after correctness is established. |
| P1 | Arena speed changes miss the cached movement baseline. | Authored movement values actually reach the movement system and remain compatible with buffs/slows. |
| P1 | Custom damage scaling, nearby support enemies and interruption behavior are inconsistent or implicit. | Explicit rules per tier for outgoing damage, support influence, stun/stagger, charge interruption and return healing. Do not silently negate player status builds. |

The initialization fix is a balance change in practice: a corrected 135 px slam covers about 4.45 times the area of the current 64 px collider, while corrected charge crumbs become much smaller. Restore geometry first, then retune damage and cadence in a separate pass.

For damage caps, the current batch budget is pooled: with an 800 cap, two post-mitigation contributions of 5,500 and 55 can become 1,600 together, versus 855 separately. First resolve this discrepancy. My preferred subsequent design is to test health and ordinary mitigation without percentage-per-hit caps, because the caps disproportionately suppress large-hit builds. Keep a cap only if matched build tests demonstrate its purpose and fairness.

## Boss proportions and visual identity

Separate three things: **anatomical size**, **equipment silhouette**, and **dangerous footprint**. A long weapon or magical halo can create presence without increasing the walking collider or implying constant contact damage.

Current boss art is a scaled, globally tinted Brute/Herald image, with no assigned boss animation frames. Approximate texture bounds including transparent padding are 158×156 / 125×147 px in S5 and 182×179 / 143×169 in S10. These are not occupied-body measurements and should not become art targets.

Use measured head-to-foot occupied height of the human player as the initial reference, excluding padding, glow, weapons and ornamental headgear. Human body/head source sizes overlap; adding their resource heights is not a valid full-character measurement. Compare the result beside every playable race, including the larger Warforged and Dragonborn.

| Form | Provisional anatomical target | What gives it presence |
|---|---|---|
| S5 Bulldozer | Start around 1.1–1.2 times human height; test up to 1.3 only with convincing anatomy | Broad armored stance, leading plough/shield plate, heavy impact weapon, grounded boots |
| S10 Bulldozer | Can retain S5 body height | Distinct bracing armor and enlarged equipment, stronger poses, moving mechanical details, deliberate impact acting |
| S5 Arcanist | Roughly 1.0–1.15 times human height | Narrow upright silhouette, identifiable casting hand and staff, readable robe shapes |
| S10 Arcanist | Roughly 1.0–1.2 times human height; no compulsory body growth | Distinct staff/array, taller posture or readable hover, controlled apparatus and visible channeling |

These are starting comparisons, not final scale settings. A larger exosuit or nonhuman construct could justify a larger solid body, but that would be a separate identity/lore decision. This proposal does not establish either boss's origin.

Create a scale board with the player races, an ordinary Brute, Herald and all four boss forms on one ground baseline at actual camera zoom. Record anatomy, equipment envelope and physical footprint separately. Approve this before finished animation. S10 must read as a different form even in silhouette, without a larger root scale.

Animation scope: idle/move; attack-specific anticipation, release and recovery; stagger; phase change; death. Use enough facings to communicate threat direction. Bulldozer lowers its shoulder and braces before movement; Arcanist uses different staff/hand poses for fan, mine placement and sustained beam. Anchor feet and hover shadows consistently. Author material values rather than tinting the whole image orange or purple.

## Proposed complete movesets

Names below are working labels. S5 keeps a compact teaching kit. S10 inherits it and adds a small number of distinctive attacks and combinations. Avoid expanding either into an unlearnable catalogue.

### Bulldozer attacks and responses

| Move | S5 form | Upgraded S10 form | Tell and player response | Opening or limit |
|---|---|---|---|
| Body pressure | Deliberate pursuit with readable contact | Same role, stronger acting | Face/stance and physical body communicate proximity; circle or create distance | No passive damage from decorative weapon tips or glow |
| Committed Rush | One locked-direction charge | Heavier braced rush; selected impacts can leave a short marked debris lane | Shoulder loads, ground lane appears, aim locks; sidestep and flank | Visible endpoint recovery; decorative baseline trail and endpoint wave; no steering |
| Planted Impact | One circular slam at a fixed point | Wider-looking equipment animation with separately tuned actual footprint | Raised weapon, persistent ground boundary; leave the circle or use a valid defense | Boss stays planted through commitment and recovery |
| Fault Line | Three clearly sequenced ground impacts in one lane | A chosen offset or cross-lane follow-up later in the fight | Entire pattern previews before first impact; order advances visibly; move out of the lane | Never fills every escape route; boss does not drift the pattern |
| Reinforcement call | One small, finite warned Runner arrival below half health | One finite arrival in phase two, with a second only if testing shows it useful | Visible arrival positions; kill for room or exploit on-kill effects | Prototype 3 per arrival, at most 6 live boss Runners; no continuous replacement |
| Sweeping Cleave | Absent | **New:** broad frontal weapon arc | Distinct sideways weapon load and sector boundary; dodge behind or out | Creates a close-range opening; cannot be immediately canceled into a rush |
| Breach Sequence | Absent | **New composition:** rush, explicit reset beat, then a planted impact or advertised second rush | Follow-up is announced before first commitment; player reads the sequence rather than guesses | Longest recovery; never added to an unrelated attack already resolving |

Remove the current automatic damaging charge-end circle in both tiers: the endpoint shockwave becomes cosmetic. A damaging follow-up is the separately advertised Planted Impact or Breach Sequence. Rush damage requires visible physical intersection and uses one explicit rush-contact rule, without an ordinary contact tick stacked on the same hit; its payload is tuned later.

Debris is a bounded S10 modifier of the rush, not a new invisible trail attack. Prototype one active lane, a short visible lifetime and a clear free side. Start with harmless visual debris; add damage or obstruction only if it creates a useful decision. Ordinary walls and procedural clutter must not make the advertised dodge impossible.

### Arcanist attacks and responses

| Move | S5 form | Upgraded S10 form | Tell and player response | Opening or limit |
|---|---|---|---|---|
| Kite, strafe and body contact | Controlled repositioning; retain readable body-only contact damage | Same identity with larger casting commitments | Facing and body motion show retreat; only the physical body causes contact damage | Leash-bounded movement; cannot endlessly evade melee; robe effects and staff decoration add no passive damage |
| Announced Blink | Departure cue and visible landing cue | More distinctive relocation acting; sets up the next advertised pattern | Full-body validated destination, outside immediate unavoidable damage | Brief post-arrival opening; no blink during another committed cast |
| Focused Fan | One locked cone with a more readable first tell | Baseline fan remains recognizable | Staff forward, cone and bolt origins agree; leave cone or use a valid gap | Casting and recovery create pursuit opportunity |
| Mine Constellation | Three persistent marked mines with an escape corridor | Deliberate 4–5 node arcs or staggered patterns, replacing random carpet placement | Markers remain through the fuse; final pulse announces detonation; move through a proven route | Prototype 1.25–1.5 s fuse, at most 5 unresolved mines; no spawn already beneath an unavoidable landing |
| Arc Sweep | Absent | **Rebuilt signature:** fully visible beam with announced rotation | Staff channels; starting lane and sweep direction are clear; cross behind or move through the safe side | Rooted channel and recovery; no simultaneous large mine detonation |
| Pylon Pair | Absent | **Rebuilt:** visible destructible emitters with coordinated shots | Planted bodies and aiming cues; choose to destroy them or keep damaging the boss | At most 2 live; one pair per threshold, no replacements in that phase; expire on phase change/death/reset |
| Split Fan | Absent | **New:** two advertised lobes with a deliberate broad gap; later an explicitly indicated rotated follow-up | Distinct staff spread, visible safe gap; reposition rather than out-stat a dense wall | Spacing supports ordinary movement, not mandatory perfect dash timing |
| Convergence Sequence | Absent | **New composition:** split fan resolves, then a sweep starts from an advertised side | Read the two beats and move into the upcoming safe wedge | Clear expired patterns first; substantial recovery; no uncontrolled mine/pylon overlay |

Pylons remain optional tactical targets. Destroying one removes its pressure and can give a short opening; they do not make the boss invulnerable. Their combined shots consume the encounter's attack budget. During a major pattern they hold fire unless their contribution is explicitly included in the previewed sequence.

## Segment 10 phase structure

Use one health bar with provisional transitions near **65% and 30%**. The boss remains damageable during short visual transitions; crossing multiple thresholds rapidly must not queue several delayed invulnerability scenes or extra add waves.

| Phase | Bulldozer | Arcanist |
|---|---|---|
| 100–65%, establish | Committed Rush, Planted Impact, Fault Line. Teach the upgraded timing and readable recovery. | Focused Fan, Announced Blink, Mine Constellation. Establish its casting tells and landing opening. |
| 65–30%, change the problem | Introduce Sweeping Cleave, a bounded debris-lane variant and one finite Runner call. | Introduce Arc Sweep, one Pylon Pair and Split Fan. Alternate major patterns. |
| Below 30%, combine and expose | Breach Sequence and a deliberate Fault Line variation. Shorten selected neutral waits, preserve tells and post-combo opening. | Convergence Sequence, deliberate mine pattern and a possible fresh bounded Pylon Pair. Preserve clear space between patterns. |

Phase visuals should communicate equipment or casting-state change. A short stagger, sound motif and health-bar marker can do this while play continues. Settle an already committed attack or cancel it visibly; do not silently move its geometry during transition.

For initial prototypes, try 0.65–0.9 s tells on ordinary major attacks, 0.9–1.2 s for a new signature, and approximately 0.7–1.2 s recovery after major releases. A 0.3–0.45 s follow-up is acceptable only when the full sequence has already been advertised. These values are tuning hypotheses, not universal reaction-time standards.

The controller may choose among valid sequences with weights and repetition limits. It should retain variation without permitting arbitrary overlaps. One major spatial demand at a time is the default; any exception must have an explicitly tested movement route at baseline movement speed. Validate the narrowest gap with the player's collision footprint, not just its center point.

## Arena and encounter presentation

Reserve a reliable fighting footprint inside the procedural district. Generation must guarantee navigable space, usable perimeter, entry/exit access and valid lines for each selected boss. Verify it across seeds and the smallest supported camera view before committing attack ranges. Keeping the player and a warned attack readable is a spatial requirement, not a reason to shrink the art arbitrarily.

Start with a legible open arena and visible disengage boundary. Do not add sealed doors or trap the player as a default. If the player retreats, cancel outstanding boss pressure and show the boss returning and healing. Retain the same reset rules on Continue: a live fight restarts cleanly at its spawn state; a defeated boss stays defeated. Do not serialize half-finished attacks.

Ambient enemies should not accidentally determine boss difficulty. Prototype pausing new ambient arrivals inside the active footprint while retaining finite boss-owned adds for kill-trigger builds. Resolve existing outsiders at activation through an explicit retreat or bounded-admission rule, rather than abruptly deleting valid player targets. External healing/buff sources should not remain unlimited offscreen. Test this policy against the game's horde identity before finalizing it.

Presentation needs:

- A brief role-specific entrance and readable name, without a long loss-of-control cinematic.
- Four distinct world forms, with S10 equipment and phase acting. Shared underlying body work is possible.
- Persistent mine markers, a visible sweep, physical pylons, and accurate ground footprints. Use shape, motion and timing alongside color.
- Separate charge, impact, mine, beam, pylon, phase and defeat audio cues. Source and license audio before integration, then mix with an actual listen under a busy build. Major attack warnings take priority over incidental sound.
- A main-boss music treatment that can intensify across phases, plus a defeat/release cue. Keep warning sounds intelligible over it.
- Phase ticks and an identifiable portrait in the existing boss bar. Current meme portraits are a tone choice: keep that humor unless the user chooses a change, but distinguish the two S10 roles and align the identity with their world presentation.

The death beat should stop boss-owned danger, mark the gate state, deliver a clear reward moment and hand back to the existing Exit Rite. Avoid adding another mandatory pre-Rite charging objective.

## Rewards and Continue

Currently S5 adds 18 percentage points of Resonance and 8 flat Followers, plus ordinary kill rewards; its configured item request is 2–3 items at base rarity 3–4. S10 fills Resonance, adds 25 flat Followers plus the kill reward and requests 5–7 items at base rarity 7–9. Item generation still passes through generic Luck/Resonance probability, so these request counts are not a guaranteed payout promise.

Define a guaranteed boss reward floor, then let Luck improve explicitly stated quality or extras. Choose its exact size against current economy data, rather than promising a new rarity table here. Both random bosses get equivalent reward value.

Persist an encounter identity tied to the attempt, segment and seeded event. Store defeat and a reward settlement containing rolled item identities, granted wallet amounts and pending unclaimed items. Claiming an item must update that settlement once. Continue must recover unclaimed loot even if it cannot reconstruct the old ground scene or the bag is full. Saving only a defeat flag would risk losing the reward; rerolling on load would permit duplication or farming.

Boss-clear, primary-objective and Resonance progress need a deliberate segment persistence contract before the Rite. Preserve the existing completed-Rite transaction and its Hub/reward recovery. A boss reward record and a Rite-completion record represent different events.

## What other games contribute

These are adaptations of developer accounts, not claims that Synthetic Ascension should copy another game's complete encounter rules.

| Game or discipline | Primary evidence | Application here |
|---|---|---|
| Hades | Boss designer Eduardo Gorinstein describes building Theseus and the Hydra around character identity, then carrying attack intent through art and animation. [DigiPen interview](https://www.digipen.edu/showcase/news/eduardo-gorinstein-delivers-challenge-and-fun-hades) | Bulldozer's momentum and Arcanist's casting apparatus should explain their attacks. S10 changes their behavior and presentation together. |
| Furi | Creative director Emeric Thoa describes warning, response and punishment, and distinct guardians. The official Burst demonstration shows the confrontation changing through several situations. [Design account](https://www.thegamebakers.com/try-again/), [complete encounter](https://www.thegamebakers.com/unedited-game-play-video/) | Give each phase a different problem and a visible opening. Do not import Furi's long duel lengths into a build-driven horde game. |
| Dead Cells | Official update 35.4 prevents one modified Concierge from jumping while its counterpart jumps or throws a fire wave. [Patch notes](https://deadcells.com/patchnotes) | Explicitly coordinate individually valid attacks; independent cooldowns are insufficient for a fair combined encounter. |
| Risk of Rain 2 | Hopoo's Paul Morse describes the Moon changes as adding interactions and decisions, rather than merely increasing difficulty. [Developer interview](https://primagames.com/gaming/risk-of-rain-2-interview-paul-morse) | Use a purposeful boss footprint and optional destructible emitters. Avoid adding another mandatory objective only to lengthen the finale. |
| Hyper Light Drifter | Lead designer Alx Preston discusses silhouette/windup communication and how additional enemies multiply complexity. [Developer interview](https://www.gamedeveloper.com/design/how-i-hyper-light-drifter-i-balances-difficulty-with-fairness) | Teach through visible poses; keep reinforcement pressure finite and authored. |
| Riot visual design | Riot explains role, power-source and facing recognition through silhouette, accurate ability hitboxes, visual hierarchy and minimal noise. [Clarity article](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) | Equipment carries identity; ground markers match actual danger; imminent boss attacks outrank decorative build effects. |

## Stage bosses beyond these two

Treat S5 and S10 as the first two encounter tiers: familiar vocabulary, then an upgraded climax. This delivers the requested stage progression without requiring a mandatory boss on every segment.

After these fights work, optional district captains or elite patrol encounters could introduce one mechanic between milestones. A later area can introduce new bosses using the same encounter infrastructure. A boss-rush or duo mode could reuse the finished kits later. None should delay finishing the Area I pair, and a mandatory duo is outside the selected S10 direction.

## Delivery order after design approval

| Step | Work | Completion evidence |
|---|---|---|
| 1. Correct shared behavior | Hazard activation, pause, cancellation, visibility, index position, damage batching and durable reward contracts | Focused regressions plus rendered examples of every corrected warning/impact; no difficulty claims yet |
| 2. Approve proportions and arena | Scale board, rough poses, footprint and procedural clear-space validation | All four forms beside all player races at gameplay zoom; both bosses have valid lanes across representative seeds |
| 3. Finish S5 teaching fights | Compact kits, persistent warnings, committed geometry, openings and finite adds | Each attack can be learned and avoided; melee and kill-trigger builds function; deaths explain themselves |
| 4. Build S10 Bulldozer | Unique form, Cleave, bounded lane variant and Breach Sequence with three-phase controller | S10 changes the movement problem; phase transitions and interruptions are coherent |
| 5. Build S10 Arcanist to equal quality | Unique form, sweep, pylons, Split Fan and Convergence | Every emitter and damaging beam is visible and targetable as intended; no unplanned carpet of hazards |
| 6. Complete the main-boss experience | Sound/music, entrance, HUD, defeat, rewards, Continue and Rite handoff; balance both choices | Matched build/seed comparison, recovery checks and a human full-run playtest |

Art blockout can proceed beside foundation repairs once the geometry contracts are agreed. Final animation waits for in-game pose and scale approval. Complete one rough S10 variant before polishing both; use the second to verify that shared systems are reusable rather than copies of today's defects.

Do not estimate final health or increase damage before the corrected kits are playable. As a pacing experiment, sample roughly 30–60 s S5 and 75–150 s S10 fights for ordinary viable milestone builds, while allowing strong S10 builds to win in 20–45 s or faster. These are observation bands, not timers, guarantees or damage gates. Weak builds may take longer. Compare ordinary and unusually stocked attempts separately.

## Acceptance checks

1. **Attack honesty:** every release matches its warning in origin, angle, footprint and timing, including at nonzero world coordinates. Active damage never becomes invisible. Test walls, low frame rates and all relevant facings.
2. **Interruption:** death, stun/stagger policy, phase change, disengage, scene unload and pause/resume cannot release a stale cast. Verify each attack at anticipation, release and recovery.
3. **Bounded pressure:** adds, mines, pylons, debris and projectiles have owners, caps and cleanup. Multiple HP thresholds crossed at once cannot enqueue extra waves. Every composed pattern has a reachable route at ordinary movement speed.
4. **Build access:** test large single hits, rapid/proc attacks, damage over time/curses, close-range sustain, summons and kill-trigger engines. Both random bosses should offer workable decisions. Pylons use correct target positions; visual limbs do not multiply hits, health pools, kills or rewards.
5. **Damage consistency:** separately and batched delivered hits agree under any retained cap. Document outgoing boss scaling and verify it independently from HP/defense scaling.
6. **Visual scale:** compare anatomy, gear and collision footprint beside all player races; inspect normal/small window, grayscale, reduced-motion settings where available, and a busy late-run build. Ground boundaries and tells remain readable.
7. **Persistence:** save/quit before activation, mid-fight, just after death, during reward settlement, with unclaimed loot, with full inventory and before/during/after Rite completion. Live encounters restart cleanly; defeated ones and rewards settle once. Check ordinary Continue and terminal-death precedence.
8. **Encounter parity:** use matched milestone builds over at least three representative district seeds and both boss selections, including mixed S5-to-S10 roles. Record time, damage received, unavoidable-overlap incidents, useful openings, reward outcomes and player explanation of each death. Run one complete city escape to judge pacing with the Rite.

Automated checks should establish lifecycle and combat correctness; rendered captures establish geometry and visual presence; human play determines readability, weight, difficulty and satisfaction. None substitutes for the others.

## Source map for implementation planning

- Arena routing, tiers, leash and rewards: [MiniBossArena.gd](../../scenes/world/events/MiniBossArena.gd), [BossArena.gd](../../scenes/world/events/BossArena.gd), [SegmentProcBuilder.gd](../../core/systems/world/SegmentProcBuilder.gd).
- Attack selection and casts: [BossBulldozerBrain.gd](../../scenes/world/bosses/BossBulldozerBrain.gd), [BossArcanistBrain.gd](../../scenes/world/bosses/BossArcanistBrain.gd), [EnemyCharge.gd](../../core/actors/enemy/modules/EnemyCharge.gd).
- Shared hazards: [DamageCircle.gd](../../core/combat/hazards/DamageCircle.gd), [BossMine.gd](../../scenes/world/bosses/BossMine.gd), [BossBeamSweep.gd](../../scenes/world/bosses/BossBeamSweep.gd), [BossPylon.gd](../../scenes/world/bosses/BossPylon.gd).
- Body setup and movement: [EnemyInit.gd](../../core/actors/enemy/modules/EnemyInit.gd), [enemy.gd](../../core/actors/enemy/enemy.gd), boss scenes/spec resources and [character animation dimensions](CHARACTER_ANIMATION.md).
- Damage ledger: [EnemyCombatService.gd](../../core/systems/enemy_world/EnemyCombatService.gd).
- Continue and Rite settlement: [global.gd](../../autoload/global.gd), [SaveManager.gd](../../autoload/SaveManager.gd), current Game Rite flow.
- HUD: [BossBarHUD.gd](../../ui/widgets/BossBarHUD.gd), [HudBossController.gd](../../ui/controllers/HudBossController.gd).
- Timer default underlying the pause issue: [Godot SceneTree.create_timer reference](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-create-timer).

Implementation begins only after the design is accepted. No gameplay code, engine runs, asset imports or balance changes are part of this proposal.
