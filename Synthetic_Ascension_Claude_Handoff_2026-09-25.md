# Synthetic Ascension — full development handoff for Claude

**Prepared:** 2026-09-25  
**Revised:** 2026-09-25, after the user expanded the scope and approved Beka's prototype.  
**Purpose:** Give Claude the complete ordered implementation brief, prior code findings, asset workflow and context needed to continue while the user is away.  
**Scope:** Ranged V5 mechanics → all Ranged visuals → 2D environments with shallow depth → items and missing item textures, Beka first → walkable between-segment hub.  
**Status:** The user has requested this work be handed to Claude for implementation. Prototype values are not claims of validated balance. The original Ranged proposal is included unchanged in Appendix A; the newer instructions in this brief resolve its scope and known gaps.

## 0. Work order and authority

| Phase | Required outcome | Where to read |
|---|---|---|
| 1 | Complete the Ranged V5 gameplay rework, including ordinary local ranks and affected hybrids, with V4 retained as a control. | Sections 2–7, 10–11 and Appendix A |
| 2 | Deliver readable, integrated visuals for Precision, Barrage and Ordnance. | Section 8 and the asset workflow in section 13 |
| 3 | Improve road/building shapes and create the shallow “3D-ish” appearance while keeping the game fully 2D. | Section 9 |
| 4 | Implement Beka first, then the remaining item ideas in coherent batches; finish missing textures for existing items as well as new ones. | Sections 13–14 and Appendix B |
| 5 | Build a real, walkable hub used between segments. | Section 15 |

The hub goes last in this handoff. Beka is the highest-priority item; do not bury her behind the other joke items. Basic combat feedback belongs in Phase 1 so mechanics can be tested, while the complete visual pass follows in Phase 2. Audit assets early and source them when needed; do not postpone a required asset merely because the final item-art audit is Phase 4.

Keep these phases independently reviewable. Move to the next authorized phase when its dependencies are satisfied; do not stop merely because the first milestone works. If a real blocker prevents one part, document it and continue independent work without reporting that blocked part as finished.

### Decisions explicitly settled in the latest conversation

- The user wants to send the entire sequence above to Claude, with a ready-to-use launch prompt.
- Claude may consult the user's signed-in browser ChatGPT for game context, asset research and asset generation.
- This game's local project is **not available as a ChatGPT browser project**. Recover previous discussion from chat history; never assume a browser project or shared local folder exists.
- When a browser ChatGPT conversation repeats itself or fails to perform the requested task, start a new chat with a compact, explicit context packet. The recovery procedure is in section 13.
- Missing item textures include **already-existing items**, not just new content.
- Beka's shield-and-pickup design is approved as a prototype. The user also approved adapting the pulse to **pull health pickups and highlight nearby equipment**, because current enemy kills award Followers directly rather than dropping currency objects.
- The hub must be a space the player walks through between segments. A painted background behind the existing shop screen is insufficient.

## 1. Request to Claude

Read this entire brief and the complete original Ranged V5 specification in Appendix A before starting Phase 1. Read Appendix B as the item concept/history source before Phase 4. Inspect the current repository before editing; the audit findings describe a snapshot and may have changed.

Implement the ordered scope in section 0, starting with the shared rank/data foundation and an enjoyable Barrage build that does not require Heat. Use focused tests and clear progress reports. Resolve routine implementation choices yourself. Call out a material design conflict with evidence and a concrete recommendation; do not silently invent different mechanics, prices or prerequisites.

Keep the existing V4 baseline available for comparison and use an explicit V5 prototype data/save path. Do not automatically convert existing saved runs. The full Ranged scope includes Precision, Barrage, Ordnance and their affected hybrid interactions; finishing the first playable milestone is progress, not completion of the whole proposal.

Treat the environment and polished VFX work as separate work packages. Give combat prototypes enough feedback to judge them immediately, then develop the complete art treatment. Do not attempt a simultaneous rewrite of combat, world generation and rendering.

Use the user's past reasoning to guide decisions while they are away. The browser consultation process in section 13 is part of the requested workflow, not a substitute for implementation. Keep short progress, decision and asset records in the repository so a restarted Claude session can resume without redoing the investigation. If the session/tool budget ends, leave a precise checkpoint and the next actionable task; do not imply that work continues after execution has actually stopped.

### Source precedence

1. The user's current instructions and existing project instructions govern the work.
2. The latest explicit decisions in section 0 and the approved Beka prototype in section 14 supersede older brainstorming where they differ.
3. The original V5 specification in Appendix A supplies detailed proposed mechanics, values and acceptance cases. Reconcile the verified contradictions in section 4 before implementing it literally.
4. Recover earlier user decisions from relevant history. Clearly separate the user's statements, a friend's suggestions and an assistant's proposed mechanics; model agreement alone is not user approval.
5. The current code determines what is implemented. Earlier chat explanations and this audit are not substitutes for inspecting it. Label recommendations and reasonable implementation assumptions as such.

If Claude is running without repository access, produce a review and concrete patch plan, and state that limitation. Do not claim to have inspected files, changed the game or passed tests.

## 2. Project and player intent

Synthetic Ascension is a Godot 4.7 / GDScript horde-survivor action roguelite. The player should assemble strange, emergent builds under pressure. The goal is an enjoyable, readable combat loop with visible upgrade payoffs.

The visual setting is fantasy and synthetic magic. Avoid drifting into a sci-fi gun game, ornate purple spell effects or decorative detail added merely to make an image look expensive. Preserve the player character's established appearance.

The player observations motivating Ranged V5 are:

- Precision currently feels naturally rewarding through aim, distance, pierce and returns.
- Barrage's Heat penalties are more noticeable than its attack-speed and projectile rewards. The basic machine-gun fantasy should work without buying Heat.
- Ordnance's dash-to-place and shoot-the-Mine interactions feel like chores when they are required for the basic explosive build.
- Reinvesting in an enjoyable effect should visibly strengthen that effect. A fragment upgrade from two seeking rounds toward five is a meaningful example.
- Visual readability affects perceived strength. An upgrade cannot be judged fairly if its attacks or triggers are invisible.

### What feasibility review established

The proposed direction fits the existing 2D game. No conversion to 3D is needed. Precision mostly extends current systems; Barrage and Ordnance require substantial behavioural changes. Local ranks reach beyond JSON into purchases, refunds, UI and saved state. Higher-looking walls require deliberate overlap handling because several renderers batch many objects together.

There is no measured time estimate or validated performance guarantee in this handoff.

## 3. Repository snapshot and working rules

Local checkout reviewed:

```text
C:\Users\NaurisKrišjānis\Desktop\code_project\SA_proj\.worktrees\enemy-world
```

HEAD when this handoff was prepared:

```text
167c1ba52c66684efd65ce4e6e3653515e97f116
```

The baseline `data/ascension/tree_v4.json` matched the tree supplied with the original discussion. Its SHA-256 was:

```text
73926E2FE72321EF8D951E4F25E60D10D3E4B5323E914F402AB96F854B574C43
```

Paths below are repository-relative so this handoff remains usable in another checkout. Locate symbols by name; line numbers drift.

- Read `README.md`, `docs/SYNTHETIC_ASCENSION_VISION.md`, `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` and any applicable current agent instructions.
- Inspect the working tree and preserve changes made by the user or another worker. Changes occurred during the audit; do not assume the whole working tree belongs to this task.
- Follow the README rule: **Never run the engine, even headless, while a human playtest is in progress.** Do not terminate the user's running game to make tests convenient. Complete independent static work if engine testing is temporarily unavailable.
- Avoid launching extra background game instances. Use the repository's existing test and performance tooling.
- Keep V4 data, V5 experimental data and save identities explicit. Isolated source code alone does not isolate user save files.
- Do not enable parked Magic/Melee changes, new Evolutions or a replacement tree-map layout as incidental additions.

## 4. Verified issues to resolve

### A. Firing-speed stacking and the existing cap

**Observed:** `core/actors/player/player.gd` defines `SHOT_HASTE_CAP = 2.5` and clamps the final firing multiplier. `BarrageEngine.gd` supplies a haste multiplier, including Burst. The engine already combines several sources multiplicatively.

**Conflict:** V5 rank-three Spin Up can supply +80%, and Burst then applies ×2. With no other modifiers, that requests 1.8 × 2 = **3.6×** base frequency. The present final cap would clip that request to 2.5×. V5 also describes additive ordinary firing-rate bonuses, while allowing an explicitly documented alternative engine ordering.

**Required resolution:** Specify the V5 stacking order, where any cap applies, what the HUD reports and what the attack scheduler actually delivers. Preserve V4 behaviour in the control configuration. Do not merely raise a global cap affecting all builds without reviewing the consequences. No replacement numerical cap is approved by this handoff.

**Acceptance:** Measure actual native input counts over a fixed interval with Spin Up alone, Burst alone, both together and an equipment speed modifier. Verify Burst applies once and the displayed state agrees with the delivered rate. Consider scheduler/tick quantization rather than checking only the returned multiplier.

### B. Big One can be bought without a Shell producer

**Observed:** The retained graph and V5 prerequisites allow this route:

```text
OR02 Grenadier
  -> OR05 Sticky Follow-up
  -> OR10 Bandolier
  -> OR09 Running Barrage
  -> OR12 Big One
```

This route costs 2,800 Followers with OR02 as the free starter. V5 changes Running Barrage to grenades. Big One still upgrades only qualifying Shells. The baseline OR12 requirement is `OR01 OR OR09 OR ORQ`, so OR09 incorrectly satisfies it after the redesign.

**Required correction:** Make OR12 require a genuine Shell-producing ability. Audit the proposed Shell sources—Impact Fuse, Secondary Blast, Designate and Saturation Scan—and their own prerequisites before choosing the exact expression. Do not solve this by allowing all grenades to count as Shells; that changes Big One's stated identity.

**Acceptance:** The grenade-only route cannot purchase a nonfunctional Big One. Genuine supported Shell routes remain reachable, OR12 counts each qualifying Shell once, and RM9 creates only one Meteor from a qualifying Big One. Revalidate catastrophe, Revelation and Evolution recipes after the prerequisite change.

### C. Ordinary local ranks and partial refunds are new infrastructure

**Observed:** `AscensionLedger.can_buy()` rejects already-owned non-sink nodes. Existing ownership values can hold ranks, but payment history is aggregated per node. The refund preview removes whole nodes and cascades dependent node removal. Existing respec rules discount returned currency.

**Conflict:** V5 needs selected ordinary locals to have multiple purchasable ranks, exact per-rank recorded payments, partial downgrade, unique-local requirements and cascading removal of ranks that become illegal. Its `RANK-06` case expects exact repayment of the removed higher-rank payments.

**Required resolution:** Implement explicit per-rank receipts and a versioned V5 ledger representation. Keep unique node ownership separate from investment depth. Make purchase, undo, save/load, downgrade and dependent-rank invalidation agree.

**Recommended prototype interpretation, requiring explicit documentation:** Follow `RANK-06` for higher-rank downgrade receipts; retain the existing V4 respec policy for the V4 control. Decide and document the V5 rank-one/full-node refund treatment rather than letting it inherit an accidental mixture of policies. Show the actual refund in the UI.

**Acceptance:** A free starter records zero paid at rank one and pays normally for later ranks. Rank four counts as one local. Downgrades, dependency cascades and undo cannot duplicate receipts or create Followers. A blocked purchase changes neither ownership nor currency. Old saved ledgers are not silently converted.

### D. Burn identity and strongest-rate refresh are not supplied by the current status API

**Observed:** `EnemyStatusService` groups records by generic status kind. Reapplication replaces the stored damage value with the new value, rather than preserving the strongest active damage rate. `EnemyCombatService` attributes status damage through generic status information.

**Conflict:** V5 needs named Hot Rounds Burn and radiant Heat consumers, strongest-rate refresh within a named effect, and correct death attribution. Wildfire is specifically dependent on Hot Rounds Burn, not any damage that happens to be thermal.

**Required resolution:** Preserve the named ability source, original cast/root identity and relevant victim history through status ticks and deaths. Define strongest-rate comparison consistently with tick interval. Prevent pellets from creating unlimited independent stacks of the same named burn.

**Acceptance:** A weaker refresh does not weaken an active stronger burn. Refreshing duration does not multiply stacks. Hot Rounds and radiant damage remain distinguishable. Tick Proc Power stays zero. A real death can trigger each allowed on-kill family once, and an ineligible source cannot masquerade as a Hot Rounds kill.

### E. The current projectile capacity can discard valid attacks

**Observed:** `ProjectileSimulationManager` has a default capacity of 4,096. At capacity, spawn fails and records a dropped-projectile counter. Barrage also has separate fragment handling; do not assume every generated attack uses this pool.

**Conflict:** The proposal explicitly rejects silently deleting valid damage because a projectile or visual limit was reached. This is a real architectural requirement, not a request to hide the counter.

**Required resolution:** Instrument all affected attack paths and define an overflow strategy that retains gameplay attacks and their source information. Pool growth, a logical simulation fallback or controlled queued emission may be candidates, but delayed emission changes timing and must be assessed. Simply removing every limit is not a demonstrated performance solution.

**Acceptance:** Force capacity pressure in a test and account for requested, simulated and resolved attacks. Verify damage, targets, timing and ancestry, not only the number of visible sprites. Reduced visual detail must not silently erase damage. If practical limits require a gameplay tradeoff, report measurements and the proposed tradeoff explicitly.

### F. Integration points that a JSON-only patch will miss

| Area | Existing behaviour / concern | Required investigation |
|---|---|---|
| Ordnance Q | `AscensionRunner._activate()` checks shared cooldown before routing the ability. | Coordinate placement during firing cooldown needs changes in shared input/routing, not only Ordnance logic. Tap must not fire before a hold is classified. |
| Foreign Spin Up | The Runner emits a Witness strike before calling engine `on_witness_strike()` hooks. | The V5 bonus must modify the actual qualifying shot before its damage is fixed; a later callback cannot retroactively repair it. |
| Precision boss trigger | The proposed alternate catastrophe trigger needs at least three physical hits from one projectile root, plus its damage threshold. | Demonstrate a legal build/trajectory that can do this. An ordinary outgoing hit plus return gives only two events. Do not claim the trigger works from counters alone. |
| Renamed nodes | V5 retains IDs but replaces several meanings. | Replace the old behaviour at those IDs. Do not run both Heat and Spin Up, or both Caltrops and Grenadier, from one purchase. |
| Starter validation | `RANK-08` says “three legal free starters per Core”; the reviewed Ranged baseline has PR01/02, BR01/02 and OR01/02. | Validate the actual authored starter set rather than hard-coding that prose count. Do not remove starter choices to make the test wording pass. |

## 5. Combat invariants to preserve throughout implementation

- One real native attack activation is different from its pellets, later hit events, a Witness strike and generated attacks.
- Generated projectiles never manufacture native inputs to recharge their own generators.
- Proc Power belongs to the payload that carries it; do not repeatedly multiply it down ancestry.
- Burn/ambient damage ticks have Proc Power zero, while a legitimate death may still trigger an expressly allowed on-kill family once for that victim.
- Preserve root IDs and visited victims across generated attacks, returns, status deaths and named conversions.
- Multiple legal descendants can exist. Prevent duplicate rewards for the same event without suppressing the intended chain through fresh victims.
- Rank investment does not create extra owned nodes, unlock a foreign Core or satisfy additional Fusion parents.
- A travelling grenade, attached grenade, grounded grenade, Mine and artillery Shell are distinct states/types with different eligibility rules.
- Detonation removes/marks an explosive before resolving the resulting effects. Same-frame fuse expiry, sticky follow-up and chain triggers produce one detonation.
- Converting a grenade at a Sigil transfers one logical explosive; it does not leave both a grenade and a Mine alive.
- Heat is optional. A build without BR03 must not acquire a Heat bar, thermal aura, Jam or compulsory cooling loop.
- Normal Meltdown does not stop firing. Overclock's special rules must not leak into baseline Barrage.
- Effect names, tooltips, previews, data and actual runtime behaviour must agree.

## 6. Code map

| Responsibility | Start here |
|---|---|
| Tree data, requirements, ledger | `data/ascension/tree_v4.json`; `core/systems/ascension/AscensionTreeDB.gd`; `core/systems/ascension/AscensionLedger.gd` |
| Combat event routing, Witness, Q and generic effects | `core/systems/ascension/AscensionRunner.gd`; `core/systems/ascension/AscensionEngine.gd`; `core/systems/ascension/AscensionTags.gd` |
| Discipline mechanics | `core/systems/ascension/engines/PrecisionEngine.gd`; `BarrageEngine.gd`; `OrdnanceEngine.gd` in that same directory |
| Actual firing cadence | `core/actors/player/player.gd`, especially `SHOT_HASTE_CAP`, `_fire_weapon()` and final haste composition |
| Status and death attribution | `core/systems/enemy_world/EnemyStatusService.gd`; `core/systems/enemy_world/EnemyCombatService.gd` |
| Projectile simulation and impacts | `core/combat/projectile/ProjectileSimulationManager.gd`; `core/combat/projectile/ImpactBurstRenderer.gd` |
| Tree purchase and rank UI | `ui/screens/AscensionScreen.gd`; `ui/screens/AscensionTreeView.gd`; `core/systems/ascension/AscensionSlotHud.gd` |
| Segment selection | `scenes/game.gd`; `core/systems/world/Level1Builder.gd` |
| Procedural routes and footprints | `core/systems/world/proc/DistrictPlan.gd`; `core/systems/world/proc/SiteParcelsImpl.gd`; `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd` |
| Wall collision and rendering | `core/systems/world/WorldBlockerGeometry.gd`; `core/systems/world/chunks/ChunkBlockRenderer.gd` |
| Interiors, roofs and actor batches | `scenes/world/volumes/IndoorVolume.gd`; `scenes/world/buildings/RoofOverlay.gd`; `core/systems/enemy_world/EnemyProxyRenderer.gd` |

Use existing abstractions where they fit. Split responsibilities where necessary, but do not make unrelated architectural cleanup a prerequisite for this work.

## 7. Phase 1 — Ranged implementation checkpoints

This is an execution brief, not a substitute for designing the exact current-code patch. Derive small, reviewable implementation tasks from each checkpoint and the detailed cases in Appendix A. Add behaviour-focused regressions for the changed rules, reproduce the failure, implement, then rerun the affected suites. Keep the public tree/save format and shared event semantics explicit before dependent features are built.

### Checkpoint 1 — V5 data and rank foundation

- [ ] Recheck the findings against the current checkout and record any that are already fixed.
- [ ] Keep an immutable V4 reference; introduce explicitly selected V5 data and separate experimental saved state.
- [ ] Produce a proposed JSON diff and validate IDs, prerequisites, conflicts, links, edges and affected recipes, including the Big One correction.
- [ ] Implement ordinary local ranks, receipts, access requirements, unique-local counting, undo and cascading downgrade.
- [ ] Add UI for current rank, exact next effect, next cost, total paid and actual refund.
- [ ] Exercise `RANK-01` through `RANK-08`, with the starter-count wording corrected to the actual authored set.

**Demonstration:** Buy and downgrade ranks through the real UI; reload the V5 ledger; confirm that V4 remains selectable and its saved state is untouched.

### Checkpoint 2 — Precision ranks and no-Heat Barrage

- [ ] Implement the selective Precision ranks and expose their measurable effects. Keep an unchanged V4 Precision build available as the balance control.
- [ ] Resolve the firing-rate composition/cap issue, then implement Spin Up and the no-Heat projectile/reserve rules.
- [ ] Implement Burst with correct native-input accounting, generated side rounds, completion fan and cancellation behaviour.
- [ ] Audit the full spec for every Barrage ability that must operate without BR03, including Kill Throttle, Vent Volley, Reserve Feed and the non-thermal catastrophe route.
- [ ] Give Spin Up stages and increased projectile counts readable visual/audio feedback immediately.
- [ ] Check the relevant PR/BR cases and the achievable physical-hit path for Precision's proposed boss trigger.

**Demonstration:** Play the spec's B1 build with no BR03. Show stage progression, visible extra rounds, the delivered Burst firing rate and the absence of Heat/Jam. This is the first major feel checkpoint; do not try to repair a dull basic gun solely by adding Heat.

### Checkpoint 3 — Grenadier and Ordnance controls

- [ ] Implement grenade flight, attachment, grounded state, fuse, target-loss behaviour and one-time detonation exactly as the spec defines.
- [ ] Add Sticky Follow-up, Chain Reaction, Running Barrage and Bandolier using actual eligible activation/movement credit.
- [ ] Retain Mines for their legitimate remaining hybrid and Q-trap uses.
- [ ] Separate tap-Q firing from hold-Q placement and their cooldowns through the shared input path.
- [ ] Correct Shell-only Big One eligibility and validate each Shell-producing route.
- [ ] Check `OR-01` through `OR-13`, including overlapping detonation causes and catastrophe trigger deduplication.

**Demonstration:** Play an automatic Grenadier build that needs no mandatory ground-object management. Show different silhouettes/telegraphs for grenades, Mines and Shells.

### Checkpoint 4 — Optional Heat, source attribution and hybrid completion

- [ ] Implement named burn attribution and strongest-rate refresh before relying on Wildfire behaviour.
- [ ] Add Hot Core tiers, accurate world-space aura, ordinary Meltdown and the separately specified Overclock rules.
- [ ] Adapt all affected Q mutations, forks, keystones, revelations, Axioms, sinks, enabled Evolutions and catastrophe routes.
- [ ] Implement foreign Witness adapters without accelerating the wrong native weapon or adding the bonus after the strike has already been emitted.
- [ ] Complete the full cross-Core compatibility matrix in Appendix A, including Rune Bomb conversion and surviving genuine Mine producers.
- [ ] Check every remaining spec acceptance case; report any intentionally deferred proposal separately from implemented behaviour.

**Demonstration:** Compare B1 and B2 and exercise at least one relevant foreign-Core build. An early native Ranged success does not establish hybrid correctness.

### Checkpoint 5 — Capacity, balance and presentation evidence

- [ ] Implement and stress the projectile overflow policy; retain gameplay/source accounting under reduced visual detail.
- [ ] Run matched V4/V5 comparisons using the spec's P1, B1, B2, O1 and O2 builds and at least three matched seeds, plus a free-choice run.
- [ ] Include both dense enemies and durable targets. Track native firing rate, damage/kill sources, rank timing, trigger counts, deaths and frame-time costs.
- [ ] Capture evidence of whether the player can notice the mechanic and identify what changed after a rank purchase.
- [ ] Record exact test commands, pass/fail results, skipped checks and benchmark conditions. Treat small samples as diagnostic, not proof of final balance.
- [ ] Capture enough functional feedback to judge the mechanics, then carry the production VFX asset list into Phase 2. Report current asset coverage honestly.

**Completion:** The full Ranged scope is accounted for, the prototype is playable, affected regressions pass when runnable, and remaining balance/performance limitations are stated with evidence. A clean parse or a screenshot alone does not establish completion.

## 8. Phase 2 — Ranged presentation brief

This phase covers **all three Ranged disciplines**, not only Precision. Preserve the existing character art and use a consistent fantasy/synthetic-magic style. Complete the asset workflow in section 13 for every missing sprite, texture and animation component.

| Discipline | Required visual feedback |
|---|---|
| Precision | Primary shots, pierce/return/split distinctions, Weak Point exposure and consumption, aim preparation, Deadshot charge/fire/impact, Judgement placement/activation/sweep. |
| Barrage | Clearly different Spin Up stages; real density increases for additional volleys/fragments/edge shots; seeking trajectories; distinct Burst start, sustained fire and completion fan; optional Heat 50/75/100 cues, true damaging aura radius, 2-second Meltdown feedback, Overclock distinction. |
| Ordnance | Visible grenade travel, attachment and grounded fuse; one detonation per explosive; differentiated Mines and Shell telegraphs; Big One warning; chain connections that remain readable; tap-Q volley versus placed Coordinates; catastrophe bombardment. |

One physical attack must not accidentally become multiple damage events because its animation has multiple frames. An effect may be visually simplified under load while its gameplay remains correct. Inspect dense combat at actual gameplay zoom, not just isolated close-ups.

### Precision's visual language

- Near-white core, pale warm gold secondary colour, very small muted violet accent.
- Straight, sharp, directional forms; needles, restrained diamonds, alignment brackets and simple crossing geometry.
- Negative space and a clear firing axis. Geometry should communicate aim, compression, alignment, penetration or impact.
- Avoid ornamental rune circles, repeated sparkles, filigree, large purple halos and unrelated floating shards.
- Keep player character art consistent with the existing game.

### Precision asset and integration expectations

Develop one effect family at a time: primary projectile/trail, Weak Point/consumption, Deadshot charge/fire/impact, then Judgement placement/activation/sweep. The actual order can follow which mechanic is being tested.

Generated images are source material until cleaned and prepared for runtime. Final sprites need transparent backgrounds, consistent scale, pivots, frame bounds and timing. A sheet of unrelated differently sized illustrations is not a ready-to-use animation atlas.

For beams, a start cap, stretchable or tiled middle and end/impact piece are a practical construction. Show charge, firing and decay as distinct phases. Keep visual lifetime separate from damage sampling so a sustained beam does not flicker between damage ticks or accidentally deal damage every rendered frame. Handle offscreen beam endpoints deliberately.

`PrecisionEngine._line()` currently performs the hit query and calls `AscensionRunner.note_line_fx()`. The generic effect hook lacks a specific ability identity. Add the context needed to distinguish Deadshot, Judgement and other lines without changing their damage timing. Verify that Weak Point state has an actual readable target marker rather than assuming that stored combat state is visible.

Preserve efficient projectile rendering. Do not replace every batched projectile with an expensive scene merely to improve its appearance. Conversely, do not ban `Line2D`: Godot supports tiled and stretched textures, so it can display authored beam art when suitable. See [Godot's Line2D documentation](https://docs.godotengine.org/en/stable/classes/class_line2d.html).

**Acceptance:** The player can distinguish an ordinary shot, generated fragment, Weak Point, Deadshot and Judgement during combat, and can read the Barrage/Ordnance states listed above. Effects remain legible over both light roads and dark interiors, and dense firing does not hide danger cues. Avoid applying Precision's specific palette to all disciplines if their existing/approved visual identities differ.

## 9. Phase 3 — 2D environment shapes and shallow depth

### Correct starting point

The current generator already has routes, frontage, parcels and courtyard logic. Do not begin by replacing it under the assumption that it only places random rectangles. Much of the visible regularity comes from the rectangular realization of those structures.

Segment one uses `Level1Builder`; later segments use procedural builders. Test and scope both explicitly. A procedural-only patch will not automatically improve the opening area.

### Desired result

Keep the gameplay plane, navigation and combat in 2D. Make the city less visibly governed by repeated rectangular outlines using:

- L/U/stepped footprints and recessed entrances where the existing grid supports them.
- Staggered façades, varied street widths and purposeful small openings/plazas.
- Broken edges, rubble, vegetation and dirt transitions with readable walkable space.
- Shallow wall faces, visible caps and consistent restrained shadows.

Keep encounter room and navigation legible. Irregularity should create a place, not obstruct every movement lane. The existing cardinal wall/collision kit supports orthogonal irregularity more directly than genuine 45-degree architecture; diagonal walls require additional art and geometry support.

### Geometry and occlusion constraints

`SiteParcelsImpl._spawn_building_rect()` coordinates rectangular building construction. `IndoorVolume` and `RoofOverlay` also encode rectangular assumptions. A new footprint must drive floor coverage, walls, door access, collision, indoor detection and roof coverage consistently. An L-shaped wall with a rectangular interior trigger/roof is an incomplete change.

`ChunkBlockRenderer` batches wall elements and `EnemyProxyRenderer` batches enemies. Turning on Y-sort does not independently sort objects that are still inside one batch. Roof fading exists, but it does not establish correct tall-wall overlap for every actor.

Prove shallow wall depth in a small scene first. Evaluate row-based grouping, selective foreground pieces or cutaway/fade rules against existing batching rather than prescribing a universal renderer replacement. Extend height only after actors and important attacks remain readable on either side of the wall.

### First environment demonstration

Create one small, representative encounter area with an irregular building, recessed entrance, street-width transition and shallow wall depth. Test player/enemy movement, doorway access, projectiles, roof transitions and foreground overlap. If used with procedural chunks, test boundary seams and repeatability for a fixed seed. Then expand the proven footprint/rendering approach into the two relevant level-building paths.

**Acceptance:** Walkability, visible building boundaries and indoor/roof state agree. The player stays readable near foreground walls. Improvements are visible at normal gameplay zoom, with no requirement for a 3D camera or simulation.

## 10. Existing validation entry points

Read the current suite scripts before choosing what to extend. Useful existing suites include:

```text
tools/tests/AscensionLedgerTest.tscn
tools/tests/AscensionScreenTest.tscn
tools/tests/AscensionRunnerTest.tscn
tools/tests/AscensionSharedRulesTest.tscn
tools/tests/AscensionPrecisionTest.tscn
tools/tests/AscensionBarrageTest.tscn
tools/tests/AscensionOrdnanceTest.tscn
tools/tests/AscensionHybridTest.tscn
tools/tests/AscensionFusionTest.tscn
tools/tests/AscensionRuntimeSafetyTest.tscn
tools/tests/EnemyStatusServiceTest.tscn
tools/tests/EnemyCombatServiceTest.tscn
tools/tests/ProjectileHandleCombatTest.tscn
tools/tests/ProjectileSlotReuseTest.tscn
tools/tests/AscensionBarrageDenseBenchmark.tscn
tools/tests/AscensionChainBurstBenchmark.tscn
tools/tests/ChunkBlockRendererTest.tscn
tools/tests/EnemyProxyRendererTest.tscn
tools/tests/EnemyProxyRendererVisualTest.tscn
tools/tests/ScriptParseAuditTest.tscn
```

A suite appearing here is not evidence that it already tests V5. Extend the relevant behaviours and add focused suites where necessary. Existing V4 expectations must continue to run against the V4 control rather than being silently rewritten to describe V5.

The README documents importing a fresh checkout and running suite scenes with `--headless --path . res://tools/tests/<Suite>.tscn --quit-after 3000`. Resolve the available Godot 4.7 executable for the current host. Import again after adding scripts and run `ScriptParseAuditTest.tscn` last after gameplay changes. Observe the active-human-playtest restriction above before any engine invocation.

## 11. What the prior audit actually checked

- Read the local original V5 specification and inspected relevant combat, ledger, UI, projectile, status and world code.
- Confirmed that the original supplied tree and repository V4 tree matched by hash.
- Statically checked adjacency/prerequisites and proposed costs for P1 (**2,500**), B1 (**2,850**), B2 (**3,400**) and O1 (**2,150**). This did not execute the game or exhaustively validate all routes.
- Found the valid but nonfunctional grenade-only Big One route described above.
- Inspected the earlier world screenshots and Precision concept imagery. Those images are not embedded here; the written visual direction is included so the brief is usable without the old chats. Do not pretend to have the images if they are unavailable in the new session.
- Did not run Godot, gameplay tests, balance simulations or performance benchmarks for this audit. No gameplay code was changed by the auditor.

Useful source context, if the new session can access it:

- ChatGPT conversation “JSON lasīšana”: `6ab43789-d6b4-83ed-8701-e8def9dd570c`.
- ChatGPT conversation “Game Shape Improvement”: `6ab586a0-9dbc-83eb-84ef-ced27ffa3cab`.
- Original local spec: `C:\Users\NaurisKrišjānis\Downloads\Synthetic_Ascension_Ranged_V5_Design_Spec.md`.

## 12. Expected handback from Claude

Report progress against all five phases: implemented scope, relevant files/data changes, decisions made to resolve conflicts, tests actually run and their results, assets sourced/generated, and remaining work. Include a short playable build/reproduction recipe so the user can judge each result.

Keep a requirement-to-implementation/test record for the complete V5 spec. Do not announce all of V5 complete when only the basic Barrage or Grenadier slice works. Do not declare the visual target achieved from a concept image or final balance achieved from a few fixed-seed runs.

For the whole handoff, Phase 1 completion does not mean Phases 2–5 are complete. Track partially implemented item ideas and temporary art explicitly. Give the user the location of the decision log, asset manifest and remaining blockers when handing back.

---

## 13. Working with browser ChatGPT and producing real assets

### 13.1 Access and context come from history, not a browser project

The user explicitly authorizes Claude to consult their signed-in ChatGPT browser session for this game's context, specific design questions, asset research and generation. Use browser tools actually available in Claude. Do not assume the tools available to Codex also exist in Claude, or that controlling Chrome also controls the desktop app.

Claude Code's browser integration supports interacting with authenticated websites and uploading local files. Setup and site permissions remain prerequisites; a sentence in this handoff cannot grant missing tool access. See [Claude Code with Chrome](https://code.claude.com/docs/en/chrome). Do not claim this user's end-to-end setup has already been tested.

**There is no Synthetic Ascension project folder available to browser ChatGPT.** Its historical context must come from conversations. Claude can still read the local repository directly; browser ChatGPT needs relevant excerpts, screenshots or intentionally uploaded files. A local path pasted into the browser is not the file itself.

Start with these known conversations:

- [JSON lasīšana](https://chatgpt.com/c/6ab43789-d6b4-83ed-8701-e8def9dd570c): Ranged rework and Precision visual discussion. The original detailed MD is already preserved in Appendix A even if old replies/files cannot be retrieved.
- [Game Shape Improvement](https://chatgpt.com/c/6ab586a0-9dbc-83eb-84ef-ced27ffa3cab): world blockiness and shallow painted depth.
- Search the user's game-related chat history for “Synthetic Ascension”, “hub”, “between segments”, “Beka”, “Varis”, “ranged”, “Precision” and relevant exact item names as needed. A conversation can have an unrelated title; search content as well as titles.

Claude may also use relevant prior context already available in its own session. Reconcile it with this newer handoff. Do not assume that ChatGPT can retrieve a Claude conversation or local Codex task that is absent from its browser history. This document carries the Beka decisions even if this current conversation is not available on the web.

### 13.2 Consultation procedure

1. Inspect the relevant code and this brief first. Identify the exact question that remains.
2. Open the relevant historical chat, or create a focused new chat after collecting the needed excerpts. Do not append hundreds of unrelated implementation questions to an old image-generation conversation.
3. Supply a short context packet: current objective, actual code behaviour, established user preferences, relevant original messages/reference images, options, your recommendation and the exact output required.
4. Ask ChatGPT to distinguish **established user decisions**, **its own suggestions** and **unknowns**. When it says the user previously wanted something, request the original message/context and verify it where accessible.
5. Check the response against the repository and the user's latest instructions. Record the useful decision and its reason, then implement. Do not repeatedly ask another model to authorize routine work already covered by the user.

Suggested question:

> I am implementing Synthetic Ascension. Here is the current task, relevant code behaviour and the user's original statements. Which option best matches those statements? Separate established decisions from inference, identify conflicts with the current spec, and give one concrete recommendation. Do not invent remembered preferences or claim repository access you do not have.

The objective is to consult the user's recorded reasoning while they are away. Another model's newly proposed idea does not automatically become the user's requirement. For an unsettled, reversible detail, choose a reasonable default, label the assumption and continue. Record genuinely consequential unresolved decisions and progress independent work.

### 13.3 Recover when browser ChatGPT gets stuck

Treat a conversation as failing its task when it repeatedly restates a plan, gives prose instead of the requested image/file, returns the same rejected result, forgets the stated constraints, or says a file exists without providing an actual artifact. An image that is visibly still generating is not a failure merely because it takes time.

Use this bounded recovery process:

1. Allow the active response/generation to finish. Inspect the actual output rather than accepting a completion claim.
2. Give **one specific corrective message** identifying what failed and the exact requested deliverable. For an image, explicitly request generation of the image now, not another description of how it could be generated.
3. If that response repeats the failure, **open a new ChatGPT chat**. Bring a compact context packet and the actual reference files/images. State what failed and what must differ. Do not rely on the new chat remembering the previous one.
4. Try the focused request there. After two fresh-chat restarts for the same blocked deliverable, stop that loop and change approach: a suitable licensed asset, a smaller asset request, or independent implementation work. Record the blocker and exact ready-to-send request.

Preserve old chats and useful artifacts; starting fresh does not require deleting history. A new chat is for recovering lost context or a failed interaction, not bypassing login requirements, account limits, service errors or tool restrictions. Report those actual access problems and continue other work. Do not manufacture a placeholder while reporting that the requested final asset was delivered.

### 13.4 Asset audit applies to existing items too

Before the art pass, enumerate the active item catalog and runtime references. Record which assets are genuinely missing, null, broken, generic temporary fallbacks, incorrectly assigned or visually inconsistent. An intentionally shared icon for variants is not automatically an error. Inspect what the player actually sees in inventory, shop, tooltips and ground loot.

Maintain an asset manifest, using an existing suitable file or creating `docs/art/asset-manifest.md`. Each entry should include:

| Field | Required content |
|---|---|
| Identity | Item/ability ID, display name and role: UI icon, world sprite, VFX component or animation. |
| Need | Current path/status and the actual missing or unsuitable part. |
| Brief | Reference art, palette, camera, intended display size, source dimensions, transparency and any frame/pivot requirements. |
| Provenance | Original asset page and applicable license/attribution, or generation chat URL/date and prompt summary. |
| Files | Downloaded original, cleaned runtime file(s), atlas/frame information and resource binding. |
| Verification | Actual dimensions/alpha, visual review at gameplay scale, Godot import result and surfaces checked. |
| Status | Needed, sourced, generated, prepared, integrated, verified, or blocked with a precise reason. |

Resolve an asset by checking the repository first, then finding appropriately licensed reusable art or asking browser ChatGPT to generate it. Use the approach that produces a coherent result. Do not purchase stock or assume search thumbnails grant reuse rights. Existing licensed packs can be a better fit than introducing a new generated style for every icon.

The user explicitly permits ChatGPT asset generation. Ask it to make the actual bitmap, using uploaded references and a concrete brief. [OpenAI's image-generation guidance](https://learn.chatgpt.com/docs/image-generation) supports reference-based generation/editing and focused revisions; that capability does not guarantee correctly aligned game animation frames.

### 13.5 Asset request and acceptance

Each request should specify the asset name/ID, exact purpose, camera and orientation, source canvas and intended on-screen size, palette/style, required transparent background, padding/pivot, animation needs and exclusions. Request one asset or tightly related family at a time. Supply the existing player/world/item art as style references when available.

Example structure:

> Generate the actual transparent PNG asset for [specific in-game purpose]. The attached images define the existing game's style and the accepted visual direction. Target [source size] for display at [in-game size], viewed from [camera/orientation]. Preserve [silhouette/palette constraints]. Include [only required components]. Exclude text, baked checkerboards, ornamental detail and unrelated props. Return the image file; do not return only a prompt or concept description.

Claude fills every bracket with the measured requirements of the actual task before sending it. For animation, specify frame count/order and verify the result; split the request or prepare frames separately if generation cannot maintain alignment.

After generation or sourcing:

- Download the original file through the available normal download workflow. A screenshot of an image preview is not the original asset.
- Inspect actual alpha; a painted checkerboard is not transparency. Check dimensions, clipping, edge halos, padding, frame consistency and legibility at the target size.
- Prepare the runtime texture/atlas and set Godot import/filtering settings to match adjacent assets. Keep intentional low-resolution art crisp; do not apply one filter policy blindly to painted VFX and pixel art alike.
- Bind it to the real item/ability resource and verify inventory, shop, tooltip and world views as applicable. An unused image sitting in a folder is not integrated art.
- Keep the original and provenance. Do not overwrite unrelated existing art or replace good textures just to make the manifest look uniform.
- For generated effect sheets, verify each actual frame and anchor. A collection of attractive concepts does not satisfy an animation requirement.

### 13.6 Keeping work moving

Keep a concise decision log with the decision, reason, evidence and whether it was explicit user direction or an implementation assumption. Maintain a phase checklist and current next task. Record asset attempts/results so a new Claude session does not repeat failed prompts or lose downloaded files.

Do not ask ChatGPT about every obvious code edit. Consult it when recovering user intent, comparing a material design choice, finding an asset or producing a missing deliverable. The target is a working game; an extended conversation between two models is not progress by itself.

## 14. Phase 4 — Beka, other items and existing-item art

### 14.1 Current equipment facts

The present game already has six core equipment slots plus **Offhand** and **Ring**. `Inventory.get_set_counts()` counts only the six core slots. `ItemData` supports custom effect scenes and polarity variants; `ItemEffectRunner` watches all eight equipment slots.

Consequently, an unusual item in a core slot can compete with a set piece, while an Offhand item competes with another accessory. Do not apply the February “losing the full set” justification indiscriminately to Offhands. Reuse the current item/rarity/drop/economy system rather than creating a separate inventory for joke items.

Start with `data/items/ItemData.gd`, `data/items/ItemInstance.gd`, `data/items/Inventory.gd`, `core/systems/items/ItemEffectRunner.gd`, `core/systems/items/ItemScaling.gd`, `core/systems/items/ItemGenerator.gd` and existing effect/resource conventions.

### 14.2 Beka is the first item deliverable

**Confirmed personal context:** Beka was Varis's cat and recently died. The user wants a wholesome memorial item. She was talkative, liked sleeping in bed and climbing, was calm/non-aggressive and somewhat timid, and had been rescued when little. She was drawn to junk food and had health problems/operations. Preserve the affectionate personality; her illness is not a requested combat mechanic or joke.

**Approved prototype:** A rare Offhand companion named **Beka**, with the protective shield and pickup pulse described below. The user explicitly selected this prototype and then approved the health-pull/equipment-highlight adaptation. This is stronger authority than the earlier unsettled brainstorming.

#### Comfortable Company — numerical baseline

| Parameter | Prototype value |
|---|---:|
| Delay after last damaging hit before shield regeneration | 4.0 seconds |
| Regeneration rate | 4% of current maximum HP per second |
| Baseline capacity | 20% of current maximum HP |
| Maximum capacity after item-strength scaling | 30% of current maximum HP |
| Damage from Beka | 0 |
| Number of active Beka shields/companions per player | 1 |

At 200 maximum HP, the baseline regenerates 8 shield per second up to 40. Starting empty immediately after a hit, full recovery takes 4 seconds of delay plus 5 seconds of charging. Interrupting regeneration preserves the shield that remains.

Every real positive hit absorbed by Beka's shield, or applied to HP, restarts the delay. Evaded/cancelled attacks do not count as damage. Do not use voluntary health payments to farm hit reactions or silently absorb them. Unequipping clears Beka's shield and regeneration progress; re-equipping begins empty with the full delay. Multiple effect instances must not create multiple shields or stack regeneration.

Integrate this as an actual amount of absorbable damage, not an armour multiplier named “shield”. Existing `OakheartShieldEffect` supplies damage reduction and an aura; its name does not prove that a reusable numerical barrier already exists. Inspect `Player._take_damage()` and preserve the current ordering of avoidance, reductions, lethal prevention and damage attribution. Proposed ordering: consume Beka's shield from the remaining mitigated hit before testing HP lethality, so a shielded nonlethal hit does not spend a last-chance effect. Distinguish absorbed damage from HP lost in telemetry and downstream triggers.

Use an existing item-strength curve for a Beka profile with baseline factor `S = 1`: shield capacity fraction is `min(0.30, 0.20 × S)`. Keep regeneration at 0.04 × maximum HP per second and the delay at 4.0 seconds for this prototype. Clamp the stored amount if maximum HP falls; increasing maximum HP increases capacity without instantly filling the new space. Do not create an unbounded cooldown reduction loop through rarity.

**Prototype defaults for Claude to document and test:** no additional flat stats initially; rare drop weight 0.20 relative to the ordinary catalog weight 1.0; normal existing rarity merging. Keep Beka's supportive scripted behaviour beneficial under either item polarity rather than inventing a hostile memorial variant. Preserve the existing polarity/merge accounting. These distribution details are implementation starting points, not a claim that balance has already been tested.

#### What Have You Got There? — approved collection adaptation

Enemy kills currently call `Global.transaction_followers()` directly in `EnemyCombatService`; the inspected ground pickup scenes are `HealthPickup` and `ItemPickup`. There is no basis for claiming a coin-vacuum effect works on that kill currency. The user explicitly approved:

- **Every 12.0 seconds**, pulse in a **320-world-unit radius** around the player.
- Pull eligible nearby **health pickups** toward a wounded player through the normal collection path; preserve healing rules, ownership, pickup delay and one-time collection.
- **Highlight nearby equipment**, keeping it available for the player to choose. The pulse does not auto-equip, sell, consume, duplicate or choose between reward alternatives.
- Leave Followers rewards and other currency accounting unchanged.

**Concrete prototype defaults:** the pulse selects pickups once, grants selected health pickups up to 2.0 seconds of attraction at up to 420 world units/second (the existing maximum magnet speed), and highlights equipment for 3.0 seconds. Skip health attraction at full HP; if HP becomes full, stop pulling remaining health pickups. Use line of sight at selection and avoid pulling through solid walls; test corners. Pickups must still pass their normal collection/lifetime checks. Timer starts at 12.0 seconds when newly equipped, does not bank multiple pulses, and pauses with game pause. These detailed timing/obstruction choices are proposed implementation defaults around the user-approved 12-second/320-unit mechanic.

The current health magnet radius is 110 units, so this extends the collection opportunity without inventing an extra reward economy. Highlighting does not alter ordinary close-range equipment pickup behaviour.

#### Beka presentation and completion criteria

The companion is safe, non-aggressive and does not obstruct navigation, draw enemy attacks or require protection. Sleeping/purring communicates shield regeneration; a meow and restrained pulse communicate the collection event. She can ride near the player or settle on a comfortable perch, using animation that fits the game's scale. Do not let constant meowing drown out danger cues; an empty utility pulse need not produce a loud repeated sound.

Use actual markings/reference photos and her real meow only if available from the user or accessible game history. Her appearance has not been described in the supplied conversation, and no photo/audio is attached to this document. Search the relevant history before inventing it. A temporary cat sprite can unblock mechanics but must be labelled provisional; do not report an invented likeness as an accurate memorial asset. Keep this art limitation separate from progress on the rest of the game.

Suggested icon: Beka resting on a folded blanket. This is an art suggestion, not an instruction to fabricate her colouring. Hub resting behaviour is an optional connection in Phase 5; Beka must already function before the hub exists.

Required checks:

- [ ] At 200 HP: no charging before 4 seconds, then 8 shield/second to 40 at baseline; capacity stays at or below 60 under scaling.
- [ ] Hits fully absorbed by the shield restart the delay without falsely reporting HP loss. Overflow reaches HP once; lethal protection triggers only when the post-shield result is lethal.
- [ ] Evaded hits, scripted health costs and ordinary damage retain their intended distinction. Max-HP changes, remove/re-equip, death/reconstruction and save/resume do not grant free duplicate shields.
- [ ] Pulse occurs at the stated cadence/range; health is collected once, equipment is only highlighted by the pulse, full HP does not waste health, and sealed walls/reward-choice rules are respected.
- [ ] The icon, world companion, shield feedback, pulse, tooltip and numeric preview are present in actual play. The cat remains visible without covering the aim point or enemy telegraphs.
- [ ] Compare Beka against existing Offhands using absorbed damage, deaths, pickups recovered and build opportunity cost. Record prototype tuning changes rather than silently changing the approved baseline.

Useful existing suites: `tools/tests/ItemEffectRunnerTest.tscn`, `tools/tests/ItemScalingV2Test.tscn`, `tools/tests/ItemEconomyV2Test.tscn`, `tools/tests/InventoryRouterTest.tscn`, `tools/tests/ChoicePickupTest.tscn` and `tools/tests/SaveIntegrityTest.tscn`. Add focused Beka regressions instead of assuming those suites already cover a new shield/pulse.

### 14.3 Remaining item ideas

After Beka, develop the rest in small coherent batches. Preserve the full February list in Appendix B and the later brainstorming below. These are **concept seeds**, not previously approved numerical specifications. For each implemented item, define slot, acquisition, exact trigger, numbers, cooldown/cap, scaling, drawbacks, interaction rules, visuals and tooltip. Check that it fits the current build economy. Use history/GPT to resolve personal references instead of pretending to know what an inside joke means.

| Working name | Existing direction to develop; authority |
|---|---|
| The Missing Pālis | Varis proposed bounded screen wobble. Later assistant idea: incoming damage delayed briefly, cancelled by killing its attacker before the debt lands. That damage mechanic remains a proposal; prevent deferred-damage duplication and keep the visual distortion bounded independently of item stacking. |
| Brutal Assault Gauntlets | Name from Varis; no settled mechanic. Develop an actual melee/impact identity before implementing stats. |
| Just Molly | Name from Varis; no settled mechanic or visual reference. |
| Plot Armor | Assistant idea: survive a lethal hit and mark its source as a rival; protection rearms only after the rival dies, with safeguards against permanent invulnerability and invalid/missing targets. |
| Duck Corkscrew | Name from Varis; no settled mechanic or reference. |
| Beer | The user suggested combining Power and Luck and noted that infinite stacking already existed. Reuse diminishing progression; the “one million” count is not authorization for unbounded effective power. |
| Grandma's Bazooka | Original name “Gradmas bazooka”; assistant idea: delayed homing retaliation against the enemy that hurt the player. Define actual damage, cadence, target loss and proc identity. |
| 7-Mile Boots (Hand-Me-Downs) | Assistant idea: longer dash with a brief return-to-start opportunity, visually represented by a left-behind boot. Validate terrain, exit/room boundaries and input behaviour. |
| Degree → Worthless Degree | Original upgrade joke; assistant idea: learning from different enemy types, then converting accumulated progress into an indirect economy/Luck benefit. Exact progression and reward unresolved. |
| Eldritch Crystal | Original “Eldrich cristal”, head/time-loop reference; precise referenced object is unknown. Recover context before selecting a rewind mechanic and its save/HP/loot semantics. |
| Bazinga | Original laugh-track idea; assistant proposal: near-miss creates a sound decoy at the old position. Bound audio repetition and define which enemy targeting it can affect. |
| Dad's Penis | Original name only. No previously agreed mechanic; do not infer a whole system from the joke. |
| Druid Tuning Staff | Original suggestion: spawn trees. Define whether those trees are decorative, blocking, damaging or supportive, their lifetime and navigation impact. |
| Dignity | Assistant idea: protection/power while intact; a strong hit drops a recoverable dignity object. Define accessible placement and recovery so the item cannot softlock itself. |
| Trauma | Assistant idea: defensive adaptation to the most recent major damage source, replaced by a different source. Define the source categories and cap rather than granting blanket immunity. |
| Along-the-Way Friendmaker | The user explicitly liked follower-making. Assistant proposal: occasionally recruit a would-be victim as a temporary ally, then grant Followers. Avoid duplicate death rewards, recursive recruitment and runaway ally counts. |
| Metaknowledge | The user explicitly liked a minimap idea. Assistant proposal: reveal unusually useful map information such as loot, rooms or upcoming threats. Determine the current navigation baseline before hiding existing essential UI behind the item. |
| Godot Engine, the item | Assistant proposal: temporarily turn an enemy into useful collision geometry while the player can pass it. This is a substantial collision/navigation mechanic, not merely a funny texture. |
| The List | Assistant proposal: an ordered set of target marks that grants a reward on completion. Handle despawns, inaccessible targets and segment transitions. |
| Second Breakfast | Assistant proposal: a healing pickup grants a delayed second portion. Define the amount/delay and route it through real healing attribution; prevent recursion. |
| IDFK | Assistant proposal: an initially uncertain effect with observable clues; discovery changes its description to “Oh.” Define a learnable rule rather than uncontrolled randomness. |
| Supa Manki | Original name only; recover the intended reference or clearly label a newly proposed interpretation. |
| The Soul of Coul | Original reference: a purple AI bird head from a clip, with a shopkeeper seduction-minigame joke. The exact reference is absent. Treat a complete relationship/minigame system as an unresolved scope addition, not an automatic consequence of adding an item. |

The 2/4/6 Conduit examples in February are historical descriptions, not confirmation of current set rules. Do not recreate old behaviour if the current game/spec has superseded it. Preserve irreverent working names where intended without letting them override the game's visual readability.

For all new items and the existing-item backlog, finish source/generation, real texture binding and in-game checks from section 13. Keep missing context or deliberately deferred mechanics explicit; “all items complete” requires the actual listed scope to be accounted for.

---

## 15. Phase 5 — actual walkable hub between segments

### 15.1 Required outcome and existing hub conversations

The user wants to finish a segment, enter a safe physical place, walk to services/NPCs, make purchases and build decisions, and leave for the next segment. This is an **in-run, between-segment** hub. It must not accidentally become only a title-screen lobby, a between-deaths reset area, or the old full-screen shop with scenery painted behind it.

Claude may already have earlier hub context. Search the relevant game history and existing session first; retain explicit prior user decisions that are compatible with the current request. The spatial proposal below is a researched starting direction, not a claim that the user previously specified these exact rooms, dimensions or service names.

### 15.2 Reference examples and what to borrow

| Reference | What the source establishes | Application to Synthetic Ascension |
|---|---|---|
| **Dead Cells — Passages** | Transition areas between biomes contain upgrade NPCs and recovery services. [Official community wiki: Passage](https://deadcells.wiki.gg/wiki/Passage) | The closest structural model: a short, physical pause between combat segments, with useful stops on the route forward. Do not copy its side-view camera, currencies or permanent-progression rules. |
| **Enter the Gungeon — The Breach** | A hub between runs provides NPC interactions and unlocks. [Game description / press kit](https://www.igdb.com/games/11182/presskit), [official community wiki: The Breach](https://enterthegungeon.wiki.gg/wiki/Breach) | A reference for a readable 2D place with recognisable service locations and residents. Borrow spatial clarity; keep SA's hub between segments of the same ongoing run. |
| **Hades — House of Hades** | Supergiant documents household cosmetic additions, a Music Stand, contextual characters and renovations. [Superstar Update, developer notes](https://www.supergiantgames.com/blog/hades-superstar-update-patch-notes/) | Borrow the feeling of a lived-in place through NPC idles, small changes and audio. This does not require a large dialogue/relationship system, its perspective, or copying its economy. |

These comparisons are design inferences from the cited examples, not descriptions of a finished SA hub. The wiki pages were available through indexed page content during research but direct retrieval returned 403; their links remain references for Claude/user browsing. The press-kit description and Supergiant developer notes were opened directly. Game screenshots/video are visual references, not reusable art licenses.

### 15.3 Recommended first layout

Build a compact **sheltered courtyard or passage through a reclaimed building**, using the Phase 3 shallow wall-depth treatment. Keep a direct arrival-to-exit route and put services in visible side alcoves. Avoid requiring long empty walks between menus.

Proposed target: roughly 1.5–2 gameplay screens across the whole useful space. At normal movement speed, the direct arrival-to-exit route should take about 5–8 seconds; the primary service loop should take about 15–25 seconds excluding time spent reading/interacting. Measure those times in the actual game and adjust the footprint. These are layout targets, not fixed tile dimensions.

```text
                       NEXT SEGMENT GATE
                    destination + readiness cue
                              |
       ASCENSION /             |              MERCHANT
       REQUIRED CHOICES    open courtyard     counter and stock
              \                |                 /
               \________ clear walk loop _______/
                              |
       QUIET ALCOVE            |              GEAR / STASH
       bench, Beka's bed       |              existing functions only
                              |
                       ARRIVAL THRESHOLD
```

The diagram describes adjacency and player flow, not a rectangular tile prescription. Offset façades, use one recessed service bay, show restrained wall faces and add a recognisable central landmark without obstructing the straight route.

The core stations are:

- **Merchant:** opens the existing buy/sell/barter functionality from a world interaction. Preserve vendor stock, refresh price, trade preview, undo and item identity.
- **Ascension/choice station:** exposes ranks/respec and any pending mandatory choice using existing eligibility and currency rules. Show an in-world cue when a required choice blocks departure.
- **Gear/stash station:** presents existing inventory/storage capabilities. Do not invent free cross-run storage or new transfer permissions merely because a chest is drawn here.
- **Exit gate:** explicit interact to continue the same attempt into the next segment. It can be reached directly when nothing mandatory is pending.
- **Quiet alcove:** a small optional place to pause, with Beka's resting behaviour when appropriate. It is not a new passive reward/healing farm.

Use NPCs/objects as entry points into focused transaction panels. Clear UI remains appropriate while shopping; normal hub movement and the world return when the panel closes. The arrival state itself must be a controllable character in the world, with collision, interact prompts and a camera.

For initial presentation, reuse established material colours and the existing character scale. Source/generate the actual service props, NPC art, ground transitions and furniture using section 13. Keep the environment readable at normal zoom. Do not add a city-building resource layer or relationship minigame as a prerequisite to a functional hub.

### 15.4 Existing code and the transition trap

The current `ui/screens/HubShop.gd` extends `Control` and is a screen, not a walkable world. Its `_ready()` binds inventory, restores/creates vendor stock and writes the hub resume target. Much of the useful economy logic is already there.

The current transition flow is:

```text
scenes/game.gd: complete_segment(completed_segment)
  -> Global.on_segment_completed(completed_segment)
       grants existing milestones/claims
       sets attempt_segment = completed_segment + 1
       resets the per-segment vendor snapshot and other segment state
       saves with the hub resume target
  -> Global.goto_hub_shop()

ui/screens/HubShop.gd: _start_next_segment()
  -> checks pending mandatory choice
  -> invalidates trade undo / resets UI memory
  -> saves with the game resume target
  -> Global.goto_game()
```

**The segment counter has already advanced before the hub is entered.** Do not increment it a second time at the new exit gate. Do not call the completion/reward path every time a shop panel is reopened.

Files to inspect:

- `scenes/game.gd`: completion guard and existing transition.
- `autoload/global.gd`: `PATH_HUB_SHOP`, `goto_hub_shop()`, `goto_resume()`, `on_segment_completed()`, vendor state and progression.
- `ui/screens/HubShop.gd` and `ui/screens/HubShop.tscn`: trade UI, pending choices, `_init_or_reuse_vendor()` and `_start_next_segment()`.
- `autoload/SaveManager.gd` and `autoload/SaveData.gd`: resume routing, scene validation and persisted run state.
- Existing player/interactable/world systems: reuse movement and input bindings without spawning a combat encounter.

Add a proper hub world scene/controller and service interaction points. Extract reusable shop/transaction responsibilities only as needed to prevent scene-level side effects when a panel opens. Give the hub controller ownership of arrival, pending-choice presentation and departure. A shop-panel instance should not independently unpause the game, reroll stock, duplicate listeners or rewrite the entire scene lifecycle every time it appears.

### 15.5 Run state and interaction rules

- Same run, same inventory, Followers, Ascension ledger, augments, choices and appropriate persistent item state. Finishing a segment remains a single transaction.
- Preserve the current health/recovery and progression policy. A bench or bed does not silently grant a full heal or advance time-dependent reward systems.
- No horde spawning or combat threat escalation while browsing the hub. Isolate the hub from combat scheduling while retaining working player movement, animation, UI and optional companion idles.
- Ordinary service visits cannot farm kills, procs, currency, reserve ammunition, Heat, Spin Up or catastrophe charge. If a training area is added later, isolate its results from real run rewards and charge accounting.
- Vendor stock and paid refresh count stay stable for that segment across reopening, walking away, closing the app and reloading. A scene change must not become a free reroll.
- Pending mandatory choices must be clear and resolvable. Departure preserves the actual existing blockers; do not turn an optional service into a new mandatory chore.
- Opening a service captures the appropriate input; closing it returns control without a stuck pause, accidental shot, stuck aim or duplicate interaction.
- Prevent multiple exit interactions from loading the next segment twice. Keep the resume target valid before/after transitions.
- Old saves targeting the previous hub scene need a compatible route or explicit migration. Resuming a hub save must not replay completion rewards, lose stock or skip a segment.

### 15.6 Hub checks and demonstration

- [ ] Complete segment N and arrive physically in the hub with the correct next segment N+1. Walk from arrival to merchant, choice station and exit using the normal controls.
- [ ] Buy, sell, refresh, manage equipment and close/reopen panels. Verify currency, item identity, vendor contents and undo rules against the existing implementation.
- [ ] Save/reload in the hub, including with a pending required choice. Resume in the hub with the same stock and state; no repeated rewards.
- [ ] Resolve a mandatory choice and leave. Trigger the exit repeatedly during the transition; load the next segment once.
- [ ] Repeat several segment/hub cycles and confirm no accumulating companion/UI instances, duplicate callbacks, lingering combat threats or incorrect audio/input state.
- [ ] Resume an older valid hub save through the compatibility path. Preserve the pending progression and transaction state.
- [ ] Verify legibility at gameplay zoom, normal keyboard/controller navigation where supported, camera bounds, wall overlap, interaction range and service-loop travel time.
- [ ] Capture a short walkthrough that shows actual character movement and interactions. A still image of a proposed courtyard does not establish a working hub.

Use the current save/economy/progression suites where relevant; add focused hub scene/transition cases for the new behaviour. A dedicated new hub scene does not justify an unrelated rewrite of all run state.

## 16. Whole-handoff completion checklist

- [ ] Ranged V5 data, ranks, mechanics, Q variants and affected hybrids implemented and traced to the detailed spec; V4 remains a usable comparison.
- [ ] Full Ranged visual pass integrated, with actual effect assets and readable gameplay feedback across all three disciplines.
- [ ] World shape/depth changes work in the relevant handcrafted and procedural paths, with collision/interiors/roofs/actor overlap in agreement.
- [ ] Beka's approved numerical prototype works, has UI/world feedback, and its memorial art status is honestly reported.
- [ ] Remaining item concepts have explicit implementation/decision status; implemented items have complete mechanics, scaling, tooltips and assets.
- [ ] Existing-item missing/broken/placeholder texture inventory has been processed; every remaining gap has a concrete reason and reference, not a generic “art later” note.
- [ ] Browser ChatGPT consultation and asset provenance are recorded; fresh-chat recovery carries real context and does not loop indefinitely.
- [ ] Walkable between-segment hub works end to end, with preserved shop economy, required choices, save/resume and single advancement.
- [ ] Relevant tests and performance checks are recorded with actual results; skipped tests and unavailable art references remain visible.
- [ ] A concise progress/decision log and next-task checkpoint let work resume after context/session interruption.

---

## Appendix A — Complete original Ranged V5 specification

The original document follows verbatim as source material. It retains its own numbering and proposal status. Apply the verified corrections and unresolved decisions identified in the brief above; the appendix has deliberately not been silently rewritten.

<!-- BEGIN ORIGINAL RANGED V5 SPEC -->
# SYNTHETIC ASCENSION — RANGED V5 GAMEPLAY REDESIGN

**Status:** Detailed design proposal for collaborator review and isolated prototype. **Not** an approved balance patch, not implemented code, and not gameplay-validated.  
**Baseline:** `tree_v4.json` (`4.0-prototype`, dated 2026-09-12). Preserve that file as an immutable V4 reference.  
**Scope:** All three Ranged disciplines (Precision `PR`, Barrage `BR`, Ordnance `OR`), rank purchases, their Q/fork/keystone/catastrophe/revelation dependencies, relevant cross-Core compatibility, implementation and playtesting requirements.  
**Out of scope:** A full redesign of Melee/Magic; new Evolutions; a new tree-map art layout; final economy balance. Minor notes on Momentum Afterimages and a proposed early Invocation Sigil link are included at the end for the next design pass.  
**Terminology:** `UNCHANGED` means retain the complete V4 mechanics and purchase rules unless an explicit global rule in this document applies. `REPLACE` means the V4 behavior at the **same ID** must be removed; do not accidentally run both behaviors. `ADD RANKS` means V4's first-rank behavior is retained unless stated otherwise. A **proposal value** is a concrete prototype setting, not a claim that playtests have verified it.

---

## 0. WHY THIS REVISION EXISTS

The author's actual playtests suggest:

- Ranged play gravitates to long-range Precision. It pays off naturally through shooting, positioning, piercing, and returns.
- Barrage's original Heat penalties were much more noticeable than the +attack-speed and side-round rewards; the intended projectile storm did not feel present.
- Ordnance's dash-to-drop-Mine and shoot-the-Mine-to-move-it loop felt like extra work. Explosives should happen naturally during combat; optional trap specialists can still exist.
- Enjoyable basic effects need **direct reinvestment**: e.g., a kill that spawns two seeking rounds should be rankable to three, four, then five. The player should not need a late Evolution to feel that growth.
- Momentum Afterimage felt good but lacked visible ownership of its duplicated attack. This is a visual/feedback follow-up rather than a mandatory redesign.
- Invocation could get a low-tier visible Sigil-to-Sigil damage link (the reference was Rell's original tether idea). Do not conflate this small Magic note with the Ranged implementation scope.

### Intended Ranged identities

| Discipline | Core player promise | What not to force on every build |
|---|---|---|
| Precision | A highly engineered shot: distance, Weak Points, pierce, bank shots, returns and intersecting trajectories. | Massive automatic bullet spam or mandatory Heat. |
| Barrage | **Ra-ta-ta-ta:** rapid firing, additional bullets, multiplying firing points and seeking fragments. Heat is an optional branch that adds burns, radiant close-range damage and a spectacular Meltdown. | Owning a self-disabling resource merely to access projectile nodes. |
| Ordnance | **Grenadier / portable artillery:** automatic launched explosives, detonations that create more detonations and large-area bombardment. | Mandatory Mine placement, shooting ground objects and managing Coordinates before explosives become useful. |

### Design constraints carried from V4

- `D` = one equipped native primary hit before mitigation, including item Power but excluding proc-derived damage bonuses.
- `L` = one baseline dash length (240 prototype world units). `R` = `L / 3` (80 prototype units).
- A payload uses **its own** stated Proc Power. Coefficients do **not** multiply down ancestry. Foreign/automation multipliers apply once where explicitly authorized.
- Native Core inputs, actual Core-hit events, generated payloads, Q activations and Witness strikes are **not interchangeable**. Use the event definitions in §1; otherwise rapid-fire upgrades will duplicate counters or recursively trigger themselves.
- Do not put a cap on lifetime or run-total Followers. Rank prices rise instead.
- Do not silently alter native-Core selection, Gate access, Witness cadence, hybrid-parent checks, fork conflicts, Evolution reward availability, existing saved ledgers or named hit-provenance requirements.
- Treat the baseline's existing edges and links as authoritative until an explicit rewrite in §8.

---

## 1. SHARED RANK-PURCHASE SYSTEM

### 1.1 Represent ranks on the existing node, not as twenty new map nodes

For selected local nodes, store `rank` on the **same node ID**. The tree displays a compact `I / II / III / IV` indicator, the current effect, the exact next-rank delta and the actual next Follower price. Unranked nodes have maximum rank 1. Initial ownership is rank 1; rank 0 means unowned. A free starter is still owned rank 1 with `actual_paid = 0`.

Recommended data shape (illustrative; adapt to the existing ledger schema):

```json
{
  "id": "BR05",
  "max_rank": 4,
  "rank": 2,
  "rank_purchase_costs": [400, 700, 1300, 2300],
  "rank_requirements": {
    "2": {"owned": "BR05"},
    "3": {"owned": "BR05", "other_unique_local_nodes_same_discipline": 2},
    "4": {"owned": "BR05", "other_unique_local_nodes_same_discipline": 4}
  }
}
```

Do not conflate the proposed local ranks with existing infinite late sinks (`PRS1/2`, `BRS1/2`, `ORS1/2`). Both systems can coexist. Do not store rank as an extra purchased node in the graph: it is an investment in one node.

### 1.2 Exact proposed prototype prices

| V4 rank-1 base price | Rank 1 | Rank 2 | Rank 3 | Rank 4 |
|---:|---:|---:|---:|---:|
| Starter/local normally **200** | 200, or **0 if selected free starter** | 350 | 750 | 1,500 |
| Local normally **400** | 400 | 700 | 1,300 | 2,300 |
| Local normally **800** | 800 | 1,300 | 2,300 | 3,900 |

Only buy ranks through a node's upgrade control after that node is already owned; upgrading does **not** traverse another edge. Rank 2 needs no other unique local. Rank 3 requires **2 other** owned unique local nodes from that discipline; rank 4 requires **4 other** owned unique locals from that discipline. Ranks, sinks, Q mutations, forks, keystones, revelations and free Core anchors do not count as those other locals.

A rank-2 or higher purchase is legal only while the node's discipline is accessible through the native Core or an opened Gate. Ownership of a neighboring node is relevant to **initial purchase only**, because rank upgrades are on the already-owned node. Preserve ordinary core-access, original adjacency, original specific `requires` and conflict checks for rank 1.

- All rank values and prices in §2–§4 supersede the generic table when explicitly specified. If a node has max rank 2 or 3, ignore non-existent higher columns.
- A free starter's **first** rank is free; ranks 2+ cost the same as the appropriate 200-Follower row. Do not give subsequent ranks for free.
- Count a rank-4 `BR05` as **one** unique Barrage local for `BRQ`, `BRF`, `BRC`, `BRV`, `G1`, and other count predicates; not four.
- On respec, refund **actual recorded purchases**, in reverse rank order, not the node's current displayed price. Refund dependent ranks/nodes via the ledger's existing cascading-refund mechanism. Rank 3/4 automatically refund if removing other nodes invalidates their unique-local counts. Avoid cycling purchases/respec/undo for additional Followers.
- Bought ranks never change the underlying node's links or Core affinity, never independently fulfill Evolution recipes, and never bypass mutually exclusive nodes.
- Upgrade prices should show **total price paid so far**, current incremental price and the next stat change. No forced auto-buy of affordable ranks.

### 1.3 Damage, trigger and ancestry invariants

1. `native_ranged_input`: one actual player Ranged attack activation. Independent of pellets or targets hit. Its firing interval is affected by attack speed.
2. `ranged_core_strike`: an eligible Ranged Core hit/strike event; includes a properly tagged Witness: Shot and appropriately tagged Q rounds where the V4 behavior says so. Weighted strike/hit counters advance using that source event's coefficient, **at most once per eligible strike activation**, not once per projectile hit unless the specific node explicitly says *hit*.
3. `generated_payload`: fragments, additional volley projectiles, radial volleys, Shells, grenades, shrapnel, side rounds and burns. These are **never native inputs**. Additional rounds cannot directly recharge Fifth Shot, Spin Up or Grenadier's activation counter. Actual kills from eligible generated payloads can still trigger ordinary on-kill effects as expressly allowed.
4. Burn and ambient Heat damage ticks have **Proc Power 0**. A legitimate resulting death can still trigger ordinary Ranged on-kill abilities **once for that victim**; the damage tick itself cannot trigger extra *on-hit* copies.
5. A real death may generate each named on-kill family at most once. Preserve root-cast IDs and visited victim IDs through all descendants. Named conversions (e.g., fragment-to-execution fusion) must retain V4 ancestry behavior and avoid source loops.
6. A single initial input can generate many real attacks. **Do not silently delete valid damage** merely because an arbitrary visual/projectile count has been reached. Use pooling, batched simulation, virtual projectiles or queued emission if required. Add instrumentation before imposing any substantive gameplay cap.
7. For same-type burn on one target, apply the **strongest current damage rate**, refresh duration on reapplication, and do not create one independent stack per pellet. Separate named sources that explicitly stack remain governed by their own rules.
8. Round-based projectile visualizations should clearly distinguish ordinary Core rounds, generated seeking fragments, Grenadier grenades and artillery Shell telegraphs.

### 1.4 Balance targets, not claims of achieved balance

- A newly unlocked mechanic should be identifiable visually within its first few eligible activations.
- A rank purchase should noticeably change the relevant action without demanding an entirely new combo route.
- A normal encounter should showcase both a no-Heat Barrage path and a no-Mine-management Grenadier path.
- Avoid pricing so high that the rank-2 payoff arrives only after the player already switches trees.
- Compare against the unchanged Precision control using identical items, enemy seeds and run segments. Measure damage distribution, kills, firing uptime, boss damage and performance; **do not balance only from dummy DPS**.

---

## 2. PRECISION (`PR`) — CONTROL DISCIPLINE, SELECTIVE RANKS

**Direction:** Preserve V4's core loop because the author repeatedly chose it during ranged tests. Change only a few progression levers and quality-of-life issues; use it as the comparison build when testing Barrage and Ordnance. Keep original links, first-rank costs and initial prerequisites for every `PR` local.

### 2.1 All 12 local nodes — exact proposed behavior

| ID | Node | Status / max rank | Rank behavior (values are proposals where V4 changes) |
|---|---|---|---|
| `PR01` | Read | ADD RANKS / **3** | R1: unchanged V4: 3 weighted Ranged Core hit points to expose a Weak Point for 3s; next Core hit consumes it for +1D. R2: threshold **2.5** weighted points. R3: threshold **2.0**. One hit may not both expose and consume. |
| `PR02` | Far Shot | ADD RANKS / **3** | R1: unchanged: first Core hit from **>2R** immediately exposes; next Core hit consumes for +1D. R2: a Weak Point *created by Far Shot* adds another **+0.2D** when consumed (total +1.2D). R3: **+0.4D** instead (total +1.4D). Other Weak Points stay +1D. |
| `PR03` | Penetrator | ADD RANKS / **4** | Additional targets pierced: **2 / 3 / 4 / 5**. Preserve +0.2D per already-crossed target to later hits, capped at +1D, and preserve the no-geometric-pierce rule for native attacks with no projectile. |
| `PR04` | Second Read | UNCHANGED / 1 | Consuming a Weak Point exposes the next target hit by that same projectile after its damage; it may be consumed on a return or later shot. Further ranks deferred to avoid making exposure trivial. |
| `PR05` | Held Breath | ADD RANKS / **3** | No-native-input Aim preparation: **0.80 / 0.65 / 0.50 seconds**. Keep +1D, Proc Power 1.25, movement allowance, on-damage removal, Witness interaction and trajectory preview. |
| `PR06` | Bank Shot | ADD RANKS / **2** | R1: 1 terrain bounce at 75% current damage, Proc Power 0.7. R2: **2** terrain bounces; each successive bounce applies **×0.75** to current damage, and each bounce has Proc Power 0.7. A shot may not bounce indefinitely between walls. |
| `PR07` | Return Shot | ADD RANKS / **3** | Return damage: **60% / 75% / 90%** of the damage as it begins returning. Keep path reversal, one hit per victim on return, Proc Power 0.5, and no self-created second return. |
| `PR08` | Overpenetrate | UNCHANGED / 1 | Unused pierce increases return damage/width by +0.2D and +R/4 each, up to +1D/+R; when no Return Shot exists, preserve the 1D endpoint burst in R/2. |
| `PR09` | Split Line | ADD RANKS / **3** | On the existing exposed-kill-after-pierce condition, emit R1: **2** rounds at -20°/+20°; R2: **3** at -24°/0°/+24°; R3: **4** at -30°/-10°/+10°/+30°. Each remains **0.7D**, 1 pierce, Proc Power 0.4. Fresh real kills may restart the family, once per victim. |
| `PR10` | Dead Center | UNCHANGED / 1 | Preserve precise alignment feedback, +0.25s Q recovery and 50% Aim-preparation preservation, maximum one refund per native input. Add conspicuous UI feedback on successful central alignment. |
| `PR11` | Crossing Fire | ADD RANKS / **2** | Trajectory-intersection window **0.50 / 0.65 seconds**. Preserve extra 1D, 1 hit per target per second, Proc Power 0.4 and outbound-vs-return eligibility. |
| `PR12` | Long Game | ADD RANKS / **3** | Stored returning-kill spare-round cap **3 / 4 / 6**; next native input fires all stored rounds at 0.8D each, Proc Power 0.5. Spare rounds cannot generate spare rounds directly. |

**Important Precision clarifications:**

- `PR01`'s weighted threshold uses cumulative precision, not integer-rounded individual attacks. Different qualified attacks contribute their existing coefficient once; excess credit follows V4's existing counter policy rather than being repeatedly counted as free exposure.
- `PR02` bonuses apply only to Weak Points it creates. Maintain exposure-origin metadata if both `PR01` and `PR02` are owned; do not stack the two bonuses or duplicate one target's status.
- For `PR07`, snapshot outbound damage at the moment the return begins, then apply the selected return percentage once. Subsequent terrain bounces and the Cross-Eyed Keystone use their separate multiplicative rules where applicable.
- `PR09`'s count changes **the number of physical rounds** and does not multiply an individual round's damage. All copies inherit one initiating family root but may hit different targets.
- Avoid automatically steering normal `PR` rounds toward targets: that is already the optional `Smart Rounds` fork.

### 2.2 Precision Q, mutations, forks and Keystones

| ID | Exact handling in this pass |
|---|---|
| `PRQ` Deadshot | UNCHANGED: Q slow-world aim window up to 0.6 real seconds at 35% world speed, then one 4D beam, R/3 wide, 8s cooldown, Proc Power 1. |
| `PRQ1` Twin Shot | UNCHANGED: 2 planned 2.5D lines. |
| `PRQ2` Quick Draw | UNCHANGED: immediate aim-line Q, 3D, 5s cooldown; existing Twin Shot interaction retained. |
| `PRQ3` Wallbang | UNCHANGED: pass walls and gain +0.5D per distinct obstruction, max +2D; beam-width tradeoff retained. |
| `PRQ4` Fan | UNCHANGED: 5 parallel lines at 35% each, with the existing Proc Power and overlap rules. |
| `PRQ5` Recalculate | UNCHANGED: first 3 actual kills from the opening beam generate one additional 1.5D line each; children cannot re-request Recalculate. |
| `PRQ6` Last Round | UNCHANGED: execute eligible normals below 25% post-damage; existing elite/boss bonus retained. |
| `PRF1` Deadeye | UNCHANGED: manually aligned central Weak Point hit +1D and one pierce, no Precision homing. |
| `PRF2` Smart Rounds | **TEST CHANGE:** Core projectiles curve up to 30° toward exposed targets; reduce the penalty from **-20%** Core shot damage to **-15%**, leaving returning/split damage unchanged. If it crowds out Deadeye in testing, restore -20%. Preserve fork mutual exclusion. |
| `PRK1` One Bullet | UNCHANGED: doubled native firing interval, main projectile 3D/Proc Power 1.25; extra *same-volley* rounds convert to +0.4D and +R/8 width each. Ranked Fifth Shot rounds follow that conversion. Independent kill-generated Fragmentation rounds remain separate. |
| `PRK2` Cross-Eyed | UNCHANGED mechanically: alternate ±20° offsets; each bounce/return ×1.5 up to 3 multiplications. Improve selection tooltip warning that trajectory previews are disabled. |

### 2.3 Precision catastrophe and revelation

- `PRC` **Firing Squad:** keep the V4 trigger (one projectile root crosses **12 distinct enemies** or consumes **6 Weak Points**), six edge guns, 2D lines, 8s recovery and One Bullet's merged sweep. **Add a boss fallback**: one physical Ranged projectile root inflicts **at least 12D total damage** to a *single* elite/boss across **at least three separate physical hit events**. Generated burn ticks and Q beam hits do not qualify for that fallback. It triggers once per recovery period and uses the same six-gun payload.
- `PRV` **JUDGEMENT** and `PRV1` Auto-Plot, `PRV2` Back and Forth, `PRV3` One Line: **UNCHANGED** in this pass, including their existing exclusivity and damage/cast rules.
- `PRE1` Kill Line, `PRE2` Smart Grid: **FROZEN**—retain V4 recipe and effects for compatibility testing; do not invent new Evolutions in this task.
- `PRA` Precision Axiom, `PRS1` Shot Speed, `PRS2` Q Damage: **UNCHANGED**, including their V4 repeatable sink formulas and prices.

### 2.4 Precision feedback requirements

Show a readable target-wide Weak Point marker, a clear trail for returning rounds, a short flash when a trajectory intersection actually deals `PR11` damage and a hit indication for manual central alignment (`PR10`). Show the real return damage percentage and pierce count in the tooltip. Bank Shot's effectiveness must be tested against actual procedural terrain: terrain-bounce ranks are poor value on levels without useful walls.

---
## 3. BARRAGE (`BR`) — MACHINE-GUN FIRST; HEAT AS AN OPTIONAL THERMAL BRANCH

**Priority:** Highest. Replace V4's early resource-management experience with a visibly accelerating gun, additional projectile families and a separately purchased thermal path. Preserve named IDs wherever possible for links, Fusions and authoring; **do not preserve an old rule just because its ID still exists**.

### 3.1 New baseline: Spin Up is NOT Heat

**`BR01` Heat → `BR01` Spin Up** (`REPLACE`, still a free-eligible Ranged starter, max rank 3).

A **native Ranged firing streak** has three attack-speed stages. Time accrues only while firing real native Ranged inputs at the currently allowed rate; the player cannot gain a stage simply by holding fire while stunned, unable to attack or between encounters. Native shots, even misses, count. Q does not independently advance the timer through generated extra volleys. For **foreign Ranged access** via a Gate, use the defined Witness-stage adapter in §5.4 rather than pretending the player owns a native gun. Foreign Witness attacks do not increase the native Melee/Magic attack rate.

| Rank | Stage 1 after consecutive firing | Stage 2 | Stage 3 | Native firing-rate bonus at stages 1 / 2 / 3 |
|---|---:|---:|---:|---|
| **1** | 0.40s | 1.20s | 2.40s | **+15% / +35% / +60%** |
| **2** | 0.35s | 1.00s | 2.00s | **+15% / +40% / +70%** |
| **3** | 0.30s | 0.80s | 1.60s | **+20% / +45% / +80%** |

- Display three clear weapon stages: increased firing animation cadence, escalating weapon audio and an obvious stage-3 effect. **Do not rely on a tiny HUD percentage** to communicate this benefit.
- Pause less than **0.35s**: hold the current stage without adding timer credit. After **0.75s** without a real native firing input, drop **one stage every 0.5s** until stage 0. Any player stun lasting more than 0.75s uses this same decay, not an instant hard reset. A change of target does not reset Spin Up.
- Firing rate means attacks per second. Combine the Spin Up percentage **additively** with other percentage firing-rate bonuses before applying that additive sum to base attack frequency, unless the underlying game has an explicit alternative ordering; do not apply the Spin Up bonus again separately to a Q-accelerated attack. Burst Q's stated ×2 is one separate, explicit multiplier after normal speed bonuses.
- Stage effects are not projectile-generation events: extra shots still require purchased supporting nodes. `BR01` works fully with **no Heat bar**, no Jam and no cooling chore.
- If another source restricts native firing, the spinning weapon cannot bypass it. Do not implement a zero-frame firing interval; use the engine's legal native-fire scheduling and log the actual interval.

### 3.2 New optional Heat system: `BR03` Hot Core

**`BR03` Heat Sink → `BR03` Hot Core** (`REPLACE`, cost **400** remains the V4 ring-2 price). New initial purchase requirement: **own `BR01`** plus existing adjacency/Core-access rules. Owning `BR01` alone grants **no Heat**. `BR03` creates the 0–100 Heat pool and turns Heat into a clearly visible offensive investment.

**Heat generation and recovery:**

- Each eligible **native Ranged input** generates **+8 Heat**. A real foreign Witness: Shot generates **+4 Heat** at most once per Witness activation; ordinary generated extra projectiles, Burn ticks, reflected fragments and edge guns add **0 Heat**. During Burst, each *native* Ranged input generates **an additional +4 Heat** (total 12) rather than multiplying Heat generation by the current attack-speed multiplier. This prevents double counting.
- After **0.35s** without any **qualifying Heat-generating input** (native Ranged shot, actual Witness: Shot or `BRA`-eligible native Melee/Magic input), Heat cools at **25 units/s** except during an ordinary time-locked Meltdown. A mere generated projectile, damage tick or stationary effect cannot prevent Heat cooling.
- The pool uses real floating-point progress for all regeneration and cooling; the HUD may display rounded integers. Crossing each threshold triggers its effect once for the crossing, not once per hit or frame.
- A prototype *non-Overclock* Meltdown begins on reaching **100**. It lasts **2.0 real seconds**. Heat remains visually locked at 100 during this window; additional generated Heat in those 2s is discarded rather than banked. Then Heat drops to **40** and enters **3.0 seconds of Meltdown lockout** before it can reach 100 again; during lockout, ordinary Heat can rise only to **99**. **Normal firing continues before, during and after Meltdown. No baseline Jam and no 1.2-second lockout.** Cooling is suspended only for the 2s ordinary Meltdown window. Overclock uses its own special cooling rules, detailed in §3.5. Stage bonuses from Spin Up retain normal rules.
- Only if `BR03` is owned, allocate and display the Heat bar; related Burn/aura effects below are otherwise dormant. Other nodes cannot secretly activate Heat when reached from a sibling edge. If `BR03` is later removed, deactivate the Heat layer and cascade-refund nodes that explicitly require it.

**Thermal effects are granted by `BR03` itself** (higher nodes strengthen them):

| Heat | Offensive effect | Visual requirement |
|---|---|---|
| **0–49** | No thermal bonus; Spin Up and other projectiles still work. | Slight barrel glow only. |
| **50–74** | Each native input adds **one** visible **0.35D** side round (Proc Power **0.25**); enemies at **player-contact range `0.5R`** receive radiant Burn at **0.12D/s**. | Visible additional projectile and a thin shimmering heat outline. |
| **75–99** | Each native input adds **two** 0.35D side rounds (Proc Power 0.25 each); radiant Burn radius becomes **`R`** at **0.22D/s**. | Broad orange heat halo and visibly denser stream. |
| **100 Meltdown** | Each native input adds **three** 0.35D side rounds; radiant Burn reaches **`2R`** at **0.35D/s**, for the 2s Meltdown window. | Unmistakable circular heat aura, high-intensity barrel animation and audio. |

**Radiant damage implementation:** apply damage once every **0.25s** to enemies currently within range; the table lists effective damage per second, so each tick is `DPS × 0.25`, snapshotting the appropriate tier **at tick time**. Each tick's Proc Power is **0**. If it legitimately kills an enemy, the real death may generate Fragmentation, Secondary Blast (only if blast-origin conditions independently qualify), and other legitimate on-kill effects, each once. Radiant Burn **is not blast damage**, **cannot trigger blast-only on-kill nodes**, and must never recursively generate side rounds. This remains true when the player has a foreign Core.

At exact threshold boundaries, use `>=` comparisons and the highest active tier only; do not sum all lower-tier auras. Recalculate radius each tick and render a matching area indicator. Burn from bullets and Burn from radiant proximity are separate **named** status consumers, but each named consumer follows the non-stacking strongest/refresh rule from §1.

### 3.3 All 12 Barrage basic nodes — complete V5 prototype changes

All `BR` rank-1 node prices stay at the original V4 prices: `BR01` and `BR02` cost **200** (one may be the free Ranged starter); `BR03`–`BR10` cost **400** except ring-3 `BR09` and `BR10` cost **800**; `BR11` and `BR12` cost **800**. Apply §1's price rows for subsequent ranks. In all cases preserve V4 adjacency unless §8 explicitly says otherwise.

#### `BR01` Spin Up — REPLACE, max rank 3

Use the entire exact stage table and timing specification in §3.1. No Heat is owned by default.

#### `BR02` Fifth Shot — ADD RANKS, max rank 4

- R1: every **5th** weighted eligible Ranged Core strike arms **2** extra 0.6D rounds for the **next** eligible attack, Proc Power **0.5** each (V4).
- R2: every **5th** arms **3** rounds.
- R3: every **4th** arms **3** rounds.
- R4: every **3rd** arms **4** rounds.
- Count each *qualified Ranged Core strike activation* using its coefficient, not each pellet or target hit. The armed extra rounds are payloads, not new native inputs. Cap **one armed Fifth Shot package**; if another package would arm before the first launches, merge round counts **up to twice the currently selected rank's package size**, then release the whole package on the next eligible shot. Avoid losing a legitimately earned package when Burst changes cadence.
- If `PRK1` One Bullet is owned, convert every extra *same-volley* Fifth Shot round using that Keystone's +0.4D/+R/8 transformation rather than creating physical extra rounds.

#### `BR03` Hot Core — REPLACE, max rank 1

The complete optional Heat/Burn/thermal-aura system is in §3.2. **Own `BR01`** to buy. Do not retain V4 Heat Sink's cooling-patch producer under this ID. Optional passive cooling equipment retains its ordinary external mechanics and works with the new Heat pool.

#### `BR04` Hot Rounds — REPLACE, max rank 3; works with or without Hot Core

- R1: the first Ranged Core projectile impact from **every 3rd eligible strike** applies **0.15D/s for 2.0s** Burn to its victim; Proc Power of Burn **0**. **This basic effect works with no `BR03`.**
- R2: baseline Burn becomes **0.20D/s for 2.5s**.
- R3: baseline Burn becomes **0.30D/s for 3.0s**.
- With `BR03` and Heat **>=50**: the first Core projectile impact of **every native volley** instead creates a **0.5D** blast in **`R/2`** and applies the currently ranked Hot Rounds Burn to victims in it. This V4-inspired high-Heat splash has its own Proc Power **0.30** for the impact blast, Burn remains **0**. At **>=75**, apply that Burn to victims hit by any physical native Core projectile in the volley (refresh strongest rather than stacking dozens of dots); only the **first** hit gets the AoE blast. Foreign Witness: Shot qualifies for the ranked 3rd-strike Burn but never synthesizes missing native volleys.
- Count the unheated third-hit condition independently from Heat; buying `BR03` does not reset progress unnecessarily. `RM5 Wildfire` recognizes **Hot Rounds Burn kills** from either unheated or heated mode.

#### `BR05` Fragmentation — ADD RANKS, max rank 4

- On **every real Ranged kill**, release rank-dependent seeking fragments: **2 / 3 / 4 / 5**.
- Each fragment remains **0.6D**, lifetime **2s** and Proc Power **0.4**. They are **generated Ranged payloads**, never Core strikes. Fragments can kill fresh victims, which can spawn the next ranked pair/group. Every actual victim can generate this named family at most once; a fragment cannot generate an extra group simply by hitting the same victim twice.
- Each emitted fragment seeks a living target initially within **3R of the initiating corpse** (new explicit prototype targeting radius, not a claimed V4 constant); prefer separate viable targets when possible, but concentrating on one durable survivor is legal. If no viable target is found, it expires after the stated **2s** without invisible guaranteed damage.
- At rank 4, visual/projectile simulation may be batched, but **damage and eligible death chains must remain equivalent** to five individual fragment payloads. Do not address performance by nerfing every rank-4 proc to spawn only two fragments after an arbitrary event budget.
- `BR10 Pinball`, `BR12 Cluster Rounds`, `MR2 Kill Feed` and other modifiers each use these physical fragment events; their existing conflict/ancestry rules remain in force.

#### `BR06` Crossfire — ADD RANKS, max rank 3

- R1: **every 3rd** weighted eligible Core strike spawns **1** screen-edge firing point that shoots **0.8D** toward the cursor, Proc Power **0.5** (V4).
- R2: **every 3rd** spawns **2** separate edge points simultaneously, each **0.7D**, Proc Power 0.5.
- R3: **every 2nd** spawns **2** simultaneous edge points, each **0.65D**, Proc Power 0.5.
- Use deterministic alternating edge quadrants for separate points rather than randomly spawning both at the same exact origin. One generated edge shot never advances Crossfire's own counter. `MR5 Run and Gun`, `RM4 Bullet Runes` and `BAE1 Gun Shield` preserve their BR06 parent eligibility.

#### `BR07` Coolant → Kill Throttle — REPLACE, max rank 2

An offensive kill reward for Spin Up rather than a movement-dependent cooling chore:

- R1: while firing at **Spin Up stage >=2**, **every 3 distinct real Ranged kills** grants **2s Overdrive**. During Overdrive, each native Ranged input generates **1 additional 0.4D side round**, Proc Power **0.25**. Kills during Overdrive contribute to the *next* 3-kill group; reactivation refreshes duration but does **not** stack concurrent copies.
- R2: trigger after **2** distinct kills; duration **2.5s**. Side-round damage stays 0.4D.
- Generated Overdrive rounds cannot refill BR07's own counter except through a fresh legitimate real death. Overdrive does not generate Heat because it is not a native input. It works without Hot Core. Show a brief muzzle/character effect when triggered.
- If the player does not own `BR01` (possible through an opened Gate and sibling adjacency), this node is purchase-locked by a new explicit **requires `BR01`** predicate. Retain its original adjacency links.

#### `BR08` Loose Chamber → Vent Volley — REPLACE, max rank 2

The large radial release is still useful; remove mandatory Jam as its only trigger:

- R1: **every 12 real native Ranged inputs** automatically fires **8** outward radial rounds, **0.6D** each, Proc Power **0.3**. Generated rounds do not advance the 12-input counter. If `BRQ` ends normally, it may trigger **one extra** Vent Volley immediately even if the 12-input counter is not full; this one is part of the Q completion and does not separately increment any native-input counter.
- R2: auto trigger every **10** native inputs, **12** rounds per radial volley; Q completion fires the same 12-round size.
- If `BR03` is owned, a Q-completion Vent Volley **also vents** current Heat to **40** (snapshot once, after calculating all Q-end bonuses). At that moment add **1 extra 0.4D radial round per complete 10 Heat spent**, maximum **6** extra. Regular automatic 10/12-input volleys **do not** vent Heat.
- Non-native Ranged builds still get a viable BR08 via their actual `BRQ` completion, if purchased; absent native input or Q it is an explicit late foreign option and should show that limitation in preview.
- `MR8 Heavy Barrel`, `BRC Overload` and future Jam-references treat an **actual Vent Volley or Overclock emergency vent** as a legal authored release event where §5 specifies it. Avoid falsely creating a global baseline Jam that would disable unrelated Core inputs.

#### `BR09` Ricochet — ADD RANKS, max rank 2

- R1: preserve the one bounce from each Core projectile impact to a **different** enemy within **2R**, at **70%** current damage, Proc Power **0.6**.
- R2: permit **one additional different-enemy bounce**. Each bounce uses **70% of immediately previous hit damage**; the second has Proc Power **0.4**. A particular projectile never hits the same victim twice through its own Ricochet family. A bounce cannot start a new top-level Ricochet projectile identity with a fresh visited set.
- Keep returning-projectile (`PR07`) and terrain-bounce (`PR06`) metadata distinct from entity Ricochet; no infinite ping-pong with the same target.

#### `BR10` Pinball — UNCHANGED, max rank 1

Preserve: fragments bounce once to another enemy after first hit at **70%** current damage, Proc Power **0.3**. Preserve the `BR05` + `BR09` specific ownership prerequisites and the existing **conflict with `BR12`**. Do **not** add Pinball ranks in the initial prototype: rank-4 Fragmentation + ranked Ricochet already creates a heavy test surface. The normal physical Core Ricochet-rank increase does not automatically grant fragments a second Pinball bounce.

#### `BR11` Bigger Magazine → Reserve Feed — REPLACE, max rank 3

This must give value even without Heat and must not require the player to manually activate an unrelated vent:

| Rank | Every N actual native inputs | Stored rounds granted | Max stored |
|---|---:|---:|---:|
| 1 | 6 | 2 | 12 |
| 2 | 6 | 3 | 18 |
| 3 | 5 | 4 | 24 |

Stored rounds are **0.7D**, Proc Power **0.3**. Every **12th native input** automatically launches **up to 6** available reserve rounds toward current aim (a small fan); remaining rounds stay stored. If this same input triggers `BR08`'s automatic Vent Volley, consume up to those 6 stored rounds **into that radial volley** instead of firing a second untelegraphed fan; each stored projectile retains its normal 0.7D damage. On `BRQ` normal completion, consume **all** currently stored rounds into the Q end volley; cap that particular completion at **24**.

Optional `BR03` synergy: first crossing **50 Heat** and first crossing **75 Heat** in each ordinary Heat cycle each grants **+1 stored** reserve round, at most once per crossing until cooling below that respective tier and crossing again. This is a small bonus, not the only way to acquire reserves. Meltdown does not repeat those crossings while locked at 100.

#### `BR12` Cluster Rounds — ADD RANKS, max rank 2

- Preserve original requires (`BR05` and `BR09`) and **conflict with `BR10`**. R1: each physical **Core Ricochet impact** emits **2 non-bouncing 0.5D** fragments, Proc Power **0.3**, even if it does not kill. R2: emits **3** fragments, **0.45D** each, Proc Power 0.3.
- These impact fragments cannot themselves bounce or recursively create BR12; however, their **actual real kills** can trigger ordinary `BR05` on-kill Fragmentation once for the victim. Keep these trigger families separate in telemetry.
- The slightly reduced per-fragment rank-2 damage is **intentional as a prototype safeguard**: increasing count must still feel better against crowds but should be evaluated carefully against single-target performance.

### 3.4 Barrage Q (`BRQ`) and all seven existing mutations

**`BRQ` Burst — REPLACE baseline details, retain Q identity, original 800 Followers, 8s cooldown and 2-owned-local requirement.** On Q, for **2.0s**, fire the native gun at **×2 its current legal firing rate** while the player still aims and moves. During the Burst window, each native input additionally fires **one forward 0.45D Burst round** (Proc Power **0.35**). On normal completion, fire a visible **12-round 0.6D forward/aim-biased fan**. These **Q-generated Core-strike** rounds retain Proc Power **0.7** as specified below, but are never native inputs. Restore ordinary legal native firing. If `BR03` is owned, each Burst-native input adds +4 extra Heat on top of its normal +8. If `BR08` is owned, its separate Q-completion Vent Volley also occurs as specified. Burst itself never requires Heat, never causes an ordinary Jam and **does not silently double-count the Heat gain** from its attack-speed multiplier. The **one bonus 0.45D side round per native input during Q** is a generated payload at Proc Power **0.35**, not a Core strike. The **12-round Q completion fan** consists of Q-generated Ranged Core strikes at Proc Power **0.7**: each physical fan round can contribute its coefficient to eligible weighted Core-strike counters, but the whole completion is one activation and grants **at most one emitted counter reward per named family**, banking remaining weighted credit for later qualified attacks. Neither type is a native input and neither independently generates Heat or advances Spin Up.

| ID | Proposed exact mutation rules |
|---|---|
| `BRQ1` Sustained | Q lasts **3s** instead of 2. Movement penalty **10%** during Burst (prototype; V4 was 25%). Keep the normal completion volley and available End bonuses. |
| `BRQ2` Vented | On **normal completion**, a **1D** Burn nova in **R** if no Hot Core is owned, or a **2D** Burn nova in **2R** if Hot Core is owned. Proc Power **0.3** for the direct nova hit; Burn applied for **0.2D/s for 2s**, Proc Power 0. The Vented nova is distinct from the separate BR03 persistent Heat aura. With Hot Core, the normal Q end also vents Heat to **40** after snapshotting relevant bonuses. |
| `BRQ3` Enfilade | UNCHANGED intent: Burst-generated rounds get **one extra eligible enemy bounce**, at **70%** current damage/Proc Power 0.5. Preserve current Pinball/Cluster interactions without applying another duplicate bounce from BR09 merely because the physical bullet is flagged as both Q and Core. |
| `BRQ4` Three Guns | UNCHANGED: add **2 nearby firing points** that mirror the Burst with **50%** damage/Proc Power 0.35, adding no native-input beats and no Heat. Show each gun prominently. |
| `BRQ5` Ammo Dump | Change from Heat-dependent. Every **4 native inputs during this Q** earns **1 bonus 0.5D end-volley round**, maximum **12** bonus rounds (Proc Power 0.3). If Hot Core is owned, add **floor(Heat snapshot / 20)** extra rounds, maximum **5**, at Q end. Snapshot Heat *before* Vented/Vent Volley resets it. Canceling skips the bonus end dump. Stored `BR11` reserve rounds are separately consumed and clearly displayed. |
| `BRQ6` Emergency Stop | Cancel Burst during its **first half** to refund **50%** of the unused Q cooldown; if Hot Core exists, additionally remove **30 Heat** immediately. The canceled cast produces no Q final volley, Ammo Dump, Vented nova or Q-completion Vent Volley. No Heat is needed to make cooldown refund valuable. |
| `BRQ7` Belt-Fed | Every **distinct real kill** during an active Burst extends its current duration by **0.10s**, capped at **+2s** total. Generated eligible ordinary kills count once, but V-root kills cannot extend Burst. Duration extension never generates phantom native shots during a stun. |

**Event order at normal Q end:** snapshot Heat and Q-native-input count → calculate Q base fan → Ammo Dump count → merge `BR11` reserve rounds → issue `BR08` extra radial volley if owned → apply Vented nova if owned → vent Heat (once, when applicable) → start Q cooldown. Every generated attack keeps its appropriate ancestry; one Q end is not six unrelated root casts. Do not trigger two Vent Volleys simply because the same native input was the 12th input and Q ended that frame: finish native-input emission first, then Q end; the Q-end bonus still occurs once as a separate explicitly earned completion event.

### 3.5 Barrage forks (`BRF1/2`), keystones (`BRK1/2`)

Keep each fork's V4 800-Follower purchase price, four-owned-unique-local count and mutual conflict. Keep 1,200 for keystones and their four-local requirement, except for new named prerequisites below.

**`BRF1` Cool Head → `BRF1` Controlled Fire** (`REPLACE`): require **`BR01`**, no Heat requirement. Spin Up **stage 3 persists an extra 1.5s** before stage loss; while stage 3 is active, native projectiles gain **+25% travel speed** and `BR11`, if present, stores **one additional reserve round per completed reserve-generation event**. Optional Hot Core synergy: voluntarily ceasing native firing with Heat in **70–90** for **at least 0.35s** vents Heat to **40** and arms the next native attack with **+0.5D**, once per **3s**. This vent is an authored release event for BRC if conditions are otherwise met. Do not automatically buy Hot Core; Controlled Fire must work without it.

**`BRF2` Backfire → `BRF2` Thermal Fury** (`REPLACE`): require **`BR03`**, and four owned unique Barrage locals (existing adjacency preserved through `BR08` or `BR11`). While in Meltdown, radiant aura **DPS doubles** (0.70D/s at normal maximum Heat), and `BR08` Vent Volley, if owned, fires **twice** its normal radial count at the Meltdown transition or during Meltdown (once per Meltdown). At the **end** of each Meltdown, pay **5% of current HP**, respecting the existing pay-health floor and non-enemy-hit provenance. If `BR08` is not owned, the Meltdown still releases **8** radial **0.6D** shots as a built-in Thermal Fury reward. One Meltdown = at most one such special radial event. This branch is deliberately dangerous, but **not** a mandatory route for high projectile counts.

**`BRK1` Overclock** (`REPLACE`, require **`BR03`**): Heat capacity **200**, high-risk continual overheating. Unlike ordinary timed Meltdown, at **100 Heat** enter sustained Meltdown and remain there until cooling below 100 or emergency vent. **Overclock exception:** after 0.35s with no qualifying Heat-generating input, Heat **does cool at 25/s even while in sustained Meltdown**; this is not the ordinary 2s locked Heat window. Leaving sustained Meltdown through cooling below 100 ends its bonus without paying an emergency-vent cost. At 100–149, grant **3 additional 0.35D side rounds per native input** (instead of BR03's ordinary tier count) and **2R** radiant aura at **0.35D/s**. At 150–179, grant **4** such rounds and **2.5R** radiant aura at **0.50D/s**. Above 100 Heat, take **25% more enemy damage**; health-payment damage is not an enemy hit. Upon reaching **180**, emit one conspicuous emergency radial vent of **16 × 0.6D** rounds (Proc Power 0.3), prevent native Ranged firing for **0.60s**, reset Heat to **40**, and trigger BRC if owned and ready. No 1.2s inherited V4 Jam remains. After vent, apply **3s** max-Heat lockout; during lockout ordinary Heat stops at **99**. Prolonged 100+ exposure should feel powerful and dangerous, not like silently crossing an invisible stat threshold.

**`BRK2` Bottomless** (`ADAPT`, NO Heat requirement): auto-fire at the current normal native Ranged interval toward aim; **holding primary input suppresses firing** as the safety control. Movement speed is **-10% at Spin Up stage 3**, or **-20% during Heat >=100** if Hot Core is owned. Spin Up progresses normally from those real auto-fire inputs. Hot Core, if purchased, gains Heat normally. The player may still activate/cancel Burst. This must not synthesize firing while paused, stunned or otherwise unable to attack.

### 3.6 Barrage catastrophe, revelation, Axiom, sinks and Evolutions

**`BRC` Overload — REPLACE trigger, preserve general four-volley payoff:** Requires **6 unique BR locals**, `BR01` and at least one of `BR08`/`BR11` (V4 structural shape). Any of these can trigger it when ready:

1. **Non-thermal route:** land **20 real native Ranged inputs at Spin Up stage 3 within a rolling 8s window**. Each input counts once regardless of Fifth Shot pellets; this allows a fast gun to reach Overload without Hot Core.
2. **Thermal route:** one actual normal Meltdown end, Thermal Fury's Meltdown-release event or Overclock emergency vent.
3. **Controlled Fire route:** **three qualifying optional Heat vents within 10s**, if Hot Core and Controlled Fire are both owned.

Payoff: **4 radial volleys, 0.15s apart**, each with **12 × 0.8D** projectiles, Proc Power **0.4**, **8s recovery**. If Crossfire is owned, preserve its V4 one-time mirroring rule for these volleys. All bullets belong to the original BRC root; BRC-generated kills do **not** count toward a *new* BRC charge or bypass its recovery. In build previews, distinguish `continuous-fire trigger` from `thermal trigger`.

**`BRV` SUPPRESSION:** preserve V4 **5s**, **3 edge guns**, each mirroring native shots at **0.8D**/Proc Power 0.4. If Hot Core is owned, freeze Heat at its value for the 5s; **do not invent a Heat bar** when it is not owned. Spin Up holds at its actual current stage while V is active **only while actual firing continues**; do not auto-set maximum stage on pressing V. `BRV1` Six Guns and `BRV2` Sweep remain mechanically V4 unchanged.

**`BRV3` Final Jam → `BRV3` Final Salvo** (same ID): retain one **1D radial round per 4 SUPPRESSION gun shots**, max **60**, and Overload-ready interaction. Change inherited **1.5s firing lockout to 0.60s recovery** and display the discharge unmistakably. The name should not imply a baseline Jam system that no longer exists.

**`BRA` Hot Blood Axiom:** change requirement from `BR01` (which no longer owns Heat) to **`BR03`** while keeping its five-unique-local prerequisite, its **2,400** price and normal Axiom equipment-slot rules. Melee/Magic Core strikes add **5 Heat** if the Axiom is equipped, share the applicable owned Hot Core threshold effects and convert each bonus thermal round into one existing **0.4D** slash/impact after the native strike. Use the normal Meltdown/reset or Overclock rule; do **not** retain the V4 clause that a Jam disables all native styles, because ordinary Jam was removed. Generated afterimages/echoes do not mint a second real native input for Heat accumulation.

**`BRS1` Heat Control sink:** explicitly require `BR03` in addition to its V4 four-unique-local count; retain original formula **30% × rank/(rank+75)** *reduction* to Heat generation and original price **200 × (rank+1)^1.25**. Show a warning that buying more can **delay Thermal Fury/Meltdown**, making it a tactical tradeoff, not an automatic upgrade. `BRS2` Projectile Life: unchanged V4 **50% × rank/(rank+100)**, same original price and distinct-local gate; it works without Heat.

**`BRE1` Heat Beam and `BRE2` Bullet Hell:** **do not redesign Evolutions in the V5 prototype**; existing V4 effects remain reference designs, but they require the following minimal compatibility conditions if they are enabled in a test build:

- `BRE1` Heat Beam: preserve `BRQ`, `BRF1` (now Controlled Fire), `BRQ2`, `PR05` and evolution reward requirements; **add `BR03`** because its existing effect creates Heat every tick. Existing manual beam duration, tick damage and eligibility otherwise unchanged. Its V4 Cool Head release-band interaction becomes `BRF1`'s new **70–90 controlled vent band**. If not implemented, **hide this Evolution in V5 testing rather than allowing a broken recipe**.
- `BRE2` Bullet Hell: preserve existing `BRQ`, `BRF2` (now Thermal Fury), `BRQ4`, `BR10`, evolution reward recipe, rotating points and 4/s attacks. Because BRF2 requires BR03, Heat is guaranteed. Its ending **1.5s forced downtime remains an Evolution-specific shutdown**, not the return of ordinary global Jam; explain this explicitly in its tooltip. Hide the Evolution temporarily if this distinction is not implemented.

### 3.7 Required Barrage player feedback

At a minimum, deliver three separate readable cues: (a) **audible and visible Spin Up stage changes**, (b) **noticeably denser projectile streams** when Fifth Shot/Fragmentation/Crossfire ranks increase, and (c) **a genuine world-space radiant circle** whose size and color accurately match the damaging area from Hot Core. The heat aura must not be an uninformative character shader that looks identical at 50 and 100. Include a distinct Heat crossing sound and a 2s Meltdown timer/countdown. Use a different readout for Spin Up versus Heat so that players never mistake attack-speed progress for Heat progress.

---
## 4. ORDNANCE (`OR`) — GRENADIER FIRST; TRAPS OPTIONAL

**Priority:** High. V4's Shell/Secondary Blast chain is worth preserving. Replace the default Mine-manipulation chores with automatic thrown explosives, keeping Mines as a real **optional payload type** for fusions and specialized Q/movement variants. Every node should have a meaningful early function without already owning five other ordnance nodes.

### 4.1 Shared Ordnance payload definitions

Preserve the V4 **Shell** definition: falling area strike **1.5D in R**, **0.6s** landing tell, Proc Power **0.5**, with one original source/root identity. Preserve genuine **Mine** payloads where separately generated: **1.5D in R**, arm after **0.35s**, life **8s**, ordinary shared cap **12** unless explicitly modified by another ability. Q's dedicated Proximity traps retain their separate Q cap, but now carry the Mine-compatible tag for specified interactions.

**New `Grenade` (OR02 / OR09) definition:**

- Launched automatically from the player toward the nearest living enemy within **3R** of the cursor's aim point. If none qualifies, throw toward the actual cursor location clamped to **2L** from the player. Initial flight **0.35s**; show physical travel, not an invisible delayed explosion. Rank-generated grenades in the same volley may choose different enemies; otherwise separate their landing spots by at least **R/2** where possible.
- Baseline explosion **1.3D in R**, Proc Power **0.5**. If the grenade hits a living enemy, **attach visibly** to that victim and detonate after **0.40s**, or immediately if an eligible follow-up Ranged Core hit detonates it through `OR05`. If it lands on empty terrain, arm immediately and explode after **0.80s** unless detonated earlier by a legitimate chain reaction.
- A grenade is an explosive/blast source whether it detonates after enemy attachment, after ground expiry or through Chain Reaction. It is **not an ordinary Mine** merely because it briefly attaches to an enemy. Reserve the `Mine` tag for actual Mine-compatible objects produced through designated conversions below.
- The blast deals its damage once; an enemy-attached grenade must not apply 1.3D on attachment **and** 1.3D on detonation. Splash is evaluated at the grenade's actual detonation position. Every explosive object may detonate at most once; remove it from the armed graph before resolving any chained explosion.
- A grenade in **flight** is not yet chain-detonatable. An enemy-attached grenade and a grounded grenade **are** chain-detonatable. On conversion to an attached Sigil Mine (`RM7`), replace rather than duplicate the original Grenade payload.
- Grenade damage scales from equipped `D` at generation using the existing V4 damage-snapshot convention; an explicit `ORK2` damage bonus applies once at detonation. Grenade kills are **real blast kills** for `OR04`.

This preserves three legible explosive sources: **Grenades** travel; **Shells** fall from above; specialized **Mines/traps** are stationary or attached armed objects. Reuse one real blast resolver for their eligible shared interactions without claiming every effect is geometrically identical.

### 4.2 All 12 Ordnance basic nodes — complete V5 prototype changes

Keep original rank-1 prices: `OR01/OR02` **200** (eligible for the free starter), `OR03`–`OR08` **400**, `OR09`–`OR12` **800**. Use §1's general price table for additional ranks.

#### `OR01` Impact Fuse — ADD RANKS, max rank 3

- R1: every **4th** weighted Ranged Core **hit**, call **one V4 Shell** at that victim (V4), at most one per initiating Core strike activation and bank excess counter credit.
- R2: threshold every **3** weighted hits.
- R3: threshold every **2** weighted hits.
- Preserve one Shell maximum per qualifying Core activation even when a multihit attack banks several Shells. Its cooldown/tell and source attributes remain unchanged. Do not change the underlying event from *hit* to *shots fired*; `OR02` intentionally uses a different activation-based event.

#### `OR02` Caltrops → Grenadier — REPLACE, max rank 4

Use §4.1's `Grenade` definition. Auto-generation advances from **real eligible Ranged attack activations**, not hit confirmations: this is why the new branch works even when a projectile misses. One native Ranged input contributes **1** activation credit; a properly tagged real foreign Witness: Shot contributes **0.6**; Q-generated bonus rounds, fragmentation rounds and additional attack payloads contribute **0** activation credit.

| Rank | Activation threshold | Grenades launched together | Per-grenade direct blast |
|---|---:|---:|---:|
| **1** | Every **4** credits | **1** | **1.3D in R** |
| **2** | Every **3** credits | **1** | **1.3D in R** |
| **3** | Every **3** credits | **2** | **1.3D in R each** |
| **4** | Every **2** credits | **2** | **1.3D in R each** |

Bank weighted overflow to the next eligible activation. **At most one grouped OR02 grenade launch per actual activation**; if high-weight eligibility crosses multiple thresholds on one activation, retain the extra counter credit rather than emitting unlimited grenades instantly. All grenades from the same activation share one originating root while keeping individual explosion identities. Real subsequent kills may create `OR04` Shells.

**Optional legacy interaction:** a real dash may still generate one Mine, but only from a **separate explicit ability/equipment/Fusion** (e.g. MR6/ORQ4); purchasing `OR02` by itself **does not spawn a Mine on dash**. This is the point of the redesign, not a feature regression to hide.

#### `OR03` Short Fuse — ADAPT, max rank 1

Preserve: hitting a victim under a falling Shell advances its impact by **0.15s** per eligible Core strike; if the target dies, redirect once toward the nearest occupied area within **3R**; never chase indefinitely. Extend the same hit-timing benefit to a victim with an **attached grenade**, advancing that grenade's remaining **0.40s** fuse by **0.15s per qualified Core strike**, minimum remaining fuse **0.10s**. If `OR05` immediately detonates the grenade on that hit, resolve detonation **once** rather than also scheduling the delayed Short Fuse event. Does not change Shell identity or Q targeting.

#### `OR04` Secondary Blast — UNCHANGED, max rank 1

Every **real blast kill** calls **one V4 Shell** on the corpse; fresh blast kills can continue the same on-kill family once per new victim, Proc Power **0.5**. Explicitly count newly introduced Grenadier explosions as blast kills. Existing original requirements stay: any of `OR01`, `OR02`, `OR09` or `ORQ`, plus ordinary adjacency. A burn-only kill does not qualify unless its original damage record also includes a separate real blast killing hit. **Do not rank `OR04` yet:** higher explosive output through ranked producer nodes will already make its chains more frequent.

#### `OR05` Mine Toss → Sticky Follow-Up — REPLACE, max rank 1

Require `OR02`. A Ranged Core hit against a victim currently carrying **an attached `OR02` grenade** immediately detonates **one** of that victim's attached grenades and adds **+0.8D to that grenade's single blast**. Proc Power of the added damage is the same **0.5** as the resulting one blast; do not make it a second independent hit. Mark the victim with a brief crackling fuse visual before detonation. Choose the **oldest** attached grenade when multiple are present. At most **one** OR05 boosted detonation per actual initiating Core activation; any further attached grenades keep their original timers. This replaces shooting stationary Mines to shove them. If a shot and the grenade's timer expire in the same simulation step, resolve the earlier ordered trigger once.

For compatibility, MR6 and RM7 create or convert actual Mine-tagged objects independently (see §5). They do not need the old OR05 push action.

#### `OR06` Chain Reaction — ADAPT, max rank 1

Require `OR02` and retain original links. Any eligible real **Mine, attached grenade, grounded grenade or Q Proximity trap** blast immediately detonates **other armed explosive objects** if their physical blast radii touch. Do not detonate Shells *while still falling*; a real Shell's **impact blast** may initiate this chain normally. Use the V4 safety invariant: remove each explosive object from the live graph before resolving its blast, and each object detonates **once**. Effects triggered by a chain inherit the initiating attack root as directed by hit provenance. A converted RM7 Mine may trigger nearby *different* explosives, but may not bounce indefinitely Mine → its own Sigil → same Mine.

#### `OR07` Blast Pull — UNCHANGED, max rank 1

Preserve the existing outer-half pull of normals by **R/2**, elites by **R/4**, boss stagger **0.25D**, resolved after damage. It applies to new Grenade blasts through the same normal blast resolver. Do not silently pull the same enemy multiple times from one blast if several shrapnel events visually overlap.

#### `OR08` Fracture — ADD RANKS, max rank 3

- R1: original: **3 distinct real blasts** on one victim arm Fracture; next eligible blast consumes it and creates **3 × 0.6D** shrapnel projectiles, Proc Power **0.35**.
- R2: require **2** distinct blasts to arm; next blast creates the same 3 shrapnel projectiles.
- R3: require **2** distinct blasts; next blast creates **5 × 0.6D** shrapnel projectiles, Proc Power 0.35.
- One Fracture stack may be armed/consumed per physical blast activation. A source's copied splash hits or repeated visual traces are not separate blasts. Shrapnel hits cannot manufacture phantom self-triggered Fracture counts without an actual qualifying blast.

#### `OR09` Walking Barrage → Running Barrage — REPLACE, max rank 3

After **real** travel, automatically lob grenades toward the enemy nearest the current aim region (same fallback rule as OR02) rather than firing a Shell behind the player. No manual mine maintenance required.

| Rank | Real distance per trigger | Grenades per trigger | Trigger-rate ceiling |
|---|---:|---:|---:|
| 1 | **1.0L** | 1 | once / **0.50s** |
| 2 | **0.75L** | 1 | once / **0.50s** |
| 3 | **1.0L** | 2 | once / **0.50s** |

Walking and dashing count; enemy-forced displacement does not. Consume only the distance that caused each actual trigger; bank legitimate distance remaining past the threshold. While trigger-rate-limited, retain at most **2L** pending credit, not an infinite burst ready after standing still. This retains some movement identity without making an involuntary dash-Mine trail the whole discipline. `OR09` produces ordinary Grenades that can interact with `OR06`, `OR04` and `OR05`; its rank-1 price and its existing `ORA`/`ORF1` links remain.

#### `OR10` Magazine → Bandolier — REPLACE, max rank 3

Require **`OR02` OR `OR09`** (either one is a live grenade producer) plus original adjacency. This is an **automatic grenade reserve**, not another hotbar action and not a hidden Mine-cap increase.

| Rank | Every N eligible activation credits | Spare grenades stored | Reserve cap |
|---|---:|---:|---:|
| 1 | 6 | 1 | 3 |
| 2 | 5 | 1 | 5 |
| 3 | 4 | 1 | 7 |

Native Ranged attack = 1 credit; Witness: Shot = 0.6; generated rounds = 0. When `OR02` or `OR09` next launches a grenade group, **automatically add at most one** stored spare grenade to that launch and decrement reserve by one. If both producers would trigger on one frame, the first chronologically ordered activation receives that spare. No reserve release without a producer. UI displays `0/cap` spare grenades with an acquisition pip. An `OR10` spare may select another target but inherits the triggering producer's attack root. This replaces the old passive increase to Mine cap; **preserve the separate V4 Mine cap** for actual Mine sources.

#### `OR11` Saturation Scan — ADD RANKS, max rank 3

Retain V4's trigger: first qualifying real blast kill after moving **R** causes a snapshot scan of the densest occupied cell within **3R** (do not scan every frame). Rank 1 fires **3 Shells**, 0.2s apart; rank 2 fires **4**; rank 3 fires **5**. Target selection happens **once** at trigger time; moving targets can escape. These Shells have their original identity, can generate legitimate Secondary Blast descendants and share the one activation root.

#### `OR12` Big One — ADD RANKS, max rank 3

Every **7th / 6th / 5th** ordinary Shell (ranks **1/2/3**) becomes the existing **4D in 2R**, **0.9s** telegraphed Big One, Proc Power **1**. All Shell sources may contribute to the counter: Impact Fuse, Secondary Blast, Designate and Saturation Scan. Grenades, attached stickies and ordinary Mines **do not** count as Shells merely because they are explosive. Preserve the V4 rule that a Big One advances the Shell counter once and cannot be duplicated by source-copy effects.

### 4.3 Ordnance Q (`ORQ`) — immediate attack as default, preparation optional

**`ORQ` Designate — REPLACE only the interaction pattern**, preserving its existing 800-Follower price, two-owned-local requirement, 7s actual-fire cooldown and V4 baseline bombardment **4 Shells, 0.2s apart**.

- **Tap Q** (release before **0.35s**): select the cursor's location within the visible screen and immediately begin a normal 4-Shell Designate sequence at that target, as long as the actual-fire cooldown is available. This is the default Grenadier experience. No preplaced Coordinate required. The first Shell keeps its normal **0.6s** tell.
- **Hold Q for >=0.35s**: enter **Coordinate placement mode** instead of firing; show a reticle; on release, place one Coordinate, up to **3**, with **0.25s placement recovery**. Placement does **not** consume the 7s actual-fire cooldown, and a Coordinate remains available until fired/replaced.
- While hovering an existing Coordinate, **tap Q** to activate its ordinary 4-Shell Designate sequence and consume that Coordinate (unless `ORQ7` preserves it); all Coordinates share the same **7s actual-fire cooldown**. A selected Coordinate should display its planned affected area and can be activated even when there is no living enemy currently in that area.
- If the player begins holding Q during its actual-fire cooldown, permit Coordinate placement but clearly gray out firing until the shared cooldown expires. If the hold crosses the 0.35s threshold, **do not first fire a tap sequence**; commit the action only on key release. A normal quick tap should otherwise feel immediate.
- For controllers, provide an explicit alternate Coordinate placement binding/hold prompt if 0.35s hold-versus-tap proves unreliable. Do not silently require a mouse for the new control scheme.
- All Q Shells share the one Q root; a placed Coordinate is an aiming object, not an extra attack root. `ORQ1`/`ORQ2` alter both the instant-tap and Coordinate-fired versions, unless their rule explicitly says otherwise.

### 4.4 All seven Ordnance Q mutations

| ID | Exact V5 prototype handling |
|---|---|
| `ORQ1` Saturation | UNCHANGED: any activated Designate sequence uses **7 Shells across a 3R circle** rather than 4 on one point. Preserve existing **conflict** with `ORQ2`. Applies to instant tap and Coordinate activation. |
| `ORQ2` Homing | UNCHANGED: replace each sequence with **3 × 2.5D** tracking Shells that fix position for final **0.15s**. Preserve conflict with `ORQ1`. Applies to both Q input forms. |
| `ORQ3` Cascade | UNCHANGED: each distinct qualifying Q-sequence real kill adds **1 Shell**, at most **+6** additions per activated sequence/Coordinate. Descendants retaining the Q root can qualify within existing ancestry rules. Works with instant tap too. |
| `ORQ4` Proximity | UNCHANGED damage/timing: Designate Shells land as armed **3s traps**, exploding on contact or expiry, separate cap **24**. **ADD `Mine` compatibility tag** for specified hybrid interactions such as Rune Bomb; do not merge Q-trap capacity with ordinary Mine capacity. Tell shows the trap zone; no impact damage before detonation. This is the optional stationary-trap route. |
| `ORQ5` Walking Target | Preserve the V4 ability for *placed* Coordinates: the selected Coordinate follows at aim-set offset within **L** of the player, and its sequence follows. Additionally, for **instant-tap Q**, the selected impact region can track the current aim point for **the first 0.6s** of that sequence, after which the center fixes. Trap payloads that have landed never move. |
| `ORQ6` All Coordinates | UNCHANGED: when activating a placed Coordinate, trigger all current Coordinates in creation order **0.2s apart**, one shared fire cooldown/root, individual Cascade allowances. With **no** placed Coordinates, instant tap behaves as ordinary Q; buying this mutation is a visible investment in preparation, not an unadvertised boost to instant Q. |
| `ORQ7` Fire Again | UNCHANGED: fired **placed** Coordinates become dormant and reactivate when the 7s Q cooldown completes; replaced dormant Coordinates are removed. Instant-tap Q does **not** create an invisible permanent Coordinate and therefore gains nothing from this mutation unless the player places actual Coordinates. Make that limitation explicit in its purchase preview. |

### 4.5 Ordnance forks, Keystones and high-end abilities

**`ORF1` Carpet Fire** — keep V4 four-unique-local requirement, 800 price and conflict with `ORF2`. Automatic **Shells** cover distinct occupied cells before reusing one; three distinct real blast kills within 1s call an additional Shell at a less-covered enemy group; ordinary Shell direct damage remains **-15%**. **Grenades** also prefer different occupied groups if multiple are launched together, but do **not** inherit the Shell-only -15% penalty unless an explicit tooltip says so. Keep this area-coverage fork distinct from direct single-target guidance.

**`ORF2` Guidance** — keep four-unique-local requirement, price and conflict with Carpet Fire. The most recent actual Core hit on an elite/boss selects it for **4s**. Preserve V4 automatic Shell behavior (**+50%** to this target; every second eligible automatic Shell suppressed, with no counter gain). **ADD:** automatically launched **Grenadier/Running Barrage grenades** prioritize that tagged elite/boss and deal **+30%** against it; do **not** suppress half the grenades, because their attacks follow a separate cadence and their damage is already differently budgeted. Manual Designate remains independent. State which bonus applies in the tooltip; do not stack +50% and +30% on the same one payload.

**`ORK1` Spotter** — UNCHANGED: 3 distinct blasts establish a **5s** Beacon on a durable target, every **0.8s** it receives one **1D Shell**, max 3 Beacons; preserve the -15% damage to other Shells. New Grenade blasts count toward establishing the Beacon but are not themselves converted to recurring Spotter Shells.

**`ORK2` Danger Close** — UNCHANGED percentages, **explicitly inclusive of new Grenades**: +40% blast radius and +25% damage to actual blast payloads. An own-blast hit pays **3% maximum HP** as actual self-damage, max one self-hit per **0.25s**, with V4 mitigation, Force, retaliation and nonrecursive safeguards preserved. The enlarged self-damage zone must be previewed for grenades, Shells and visible traps. The player may still build long-range Ordnance without this Keystone.

**`ORC` Rolling Thunder** — preserve its structure: 6 unique OR locals, `OR12`, and at least `OR04` or `OR06`; same 2,400 price, six lanes, **4 × 2D Shells per lane** across the visible field over 1s, Proc Power **0.3**, 8s recovery, Mines touched by lanes detonate. **ADD alternative activation:** original **12 distinct blast activations within one attack root**, *or* **24 distinct owned Grenade/Shell/Mine blast activations across an 8s rolling window** (ordinary `OR` sources only). A physical explosive contributes at most once to either count, and the catastrophe fires once when either completes. ORC-generated blasts cannot build its own next trigger. The new rolling-window route lets ordinary automatic Grenadier play build toward an artillery payoff when kills do not happen to chain within one root.

**`ORV` FIRE MISSION**, `ORV1` No Safe Ground, `ORV2` Firewalk, `ORV3` Second Salvo — retain existing V4 attacks, prerequisites, 24/48-Shell counts, telegraphs, exclusive V1/V2 choice, and the danger-grid warning. Since normal play now produces more Grenades, the Revelation should remain specifically **Shell artillery**, not simply generate a hundred extra Grenades.

**`ORE1` Carpet Bomb / `ORE2` Bunker Buster** — frozen V4 Evolutions for now. Preserve their recipe IDs and mechanical effects as references; they **remain reachable** because `ORQ` still supports *placed Coordinates* via hold-Q. Their purchase previews must teach Coordinate placement explicitly. Do not auto-replace Evolutions until core Grenadier and instant Designate play are tested.

**`ORA` Fuse Axiom** — UNCHANGED: non-Shell Q endpoint leaves one Shell; Shell-producing Q advances Big One by one if owned; one grant per real Q activation, including Reaction Q. **Instant Designate is a Shell-producing Q**, exactly as placed-Coordinate Designate already was. Do not issue two additional Shells solely because the Q input became easier.

**`ORS1` Blast Damage / `ORS2` Blast Radius sinks** — UNCHANGED original formulas and price: damage **+1% × sqrt(rank)**; radius **+70% × rank/(rank+95)**; incremental price **200 × (rank+1)^1.25**, existing 4-unique-local prerequisite. New Grenade blasts are legitimate Ordnance blast payloads and receive these bonuses under the same existing “blast damage/radius” category; ordinary bullet Burn and Barrage's Heat aura do not.

### 4.6 Required Grenadier feedback

The player must see Grenades **leave the weapon/player**, move to their target, attach briefly (if they hit an enemy), show a short fuse, and explode at the actual position. Use different language and visual silhouettes for a moving Grenade, falling Shell and armed Mine. `OR05` boosted detonation needs a separate crackling cue; Chain Reaction should visually trace or sequence the chain enough to make its additional work obvious. Display spare Grenades gained/consumed by Bandolier without adding another manually managed resource bar. The player should be able to enjoy the `OR02 → OR01 → OR04 → OR08/OR09 → OR11/12` progression (subject to the actual traversable graph) **without purchasing `OR05`, `OR06` or any Q Coordinate mutation**.

---
## 5. CROSS-TREE COMPATIBILITY — REQUIRED, NOT OPTIONAL

V4 is an interconnected design, not nine independent class trees. A mechanical rewrite at an existing ID changes the meaning of every Fusion, Evolution, Axiom, old build route, and early-node unlock referencing it. **Before treating the Ranged redesign as complete, implement or explicitly disable all affected consumers below.** Preserve unlisted external nodes' original mechanics.

### 5.1 Melee × Ranged Fusions and dependent effects

| ID | Existing parents | V5 compatibility treatment |
|---|---|---|
| `MR1` Bloodshot | `EX03` + `PR03` | Preserve two extra pierces for the Spillover blood projectile. **Do not automatically add all PR03 rank pierces** to the extra two from MR1 unless a future review expressly changes its budget. When PR03's ranked native Core pierces apply to an eligible native projectile, those are the normal PR03 rule. |
| `MR2` Kill Feed | `EX10` + `BR05`, plus `EX01` | Keep half-line fragment Finish and **one extra fragment per real fragment execution**. Replace its tooltip phrase “the ordinary pair” with **“the current BR05 ranked ordinary fragment group”**. A real death gets the appropriate ranked BR05 group **once**, plus MR2's one distinct bonus if that death qualified as a fragment execution. Prevent source/visited reset loops. |
| `MR3` Corpse Mortar | `EX05` + `OR04` | UNCHANGED: eligible corpse becomes a travelling Shell; new OR04 accepts the resulting actual Shell blast kill exactly as before. Do not automatically turn the corpse into an OR02 Grenade. |
| `MR4` Rail Dash | `MO09` + `PR07` | UNCHANGED: catch up to three actual returning projectiles; keep each original return coefficient. Ranked PR07 increases the stored return coefficient appropriately; do not grant the bonus a second time on launch. |
| `MR5` Run and Gun | `MO04` + `BR06` | UNCHANGED concept: Afterimage fires 0.6D shot, every third **actual Crossfire edge shot** leaves one melee Afterimage. Ranked BR06 may produce 2 separate edge shots on one activation; process real shots individually, preserve each family once per source, and do not allow the Crossfire-created Afterimage's shot to regenerate the same conversion indefinitely. |
| `MR6` Mine Runner | `MO06` + `OR02` | ADAPT: Ram still creates **one genuine Mine** on the carried normal, even though OR02 now normally generates Grenades. Arm at endpoint, detonate on next body collision or after **0.5s**; counts toward the V4 ordinary **12-Mine** cap. Dashing through an existing friendly Mine can carry it instead of duplicating. Display this as **an additional hybrid Mine producer**, not a hidden return of baseline Caltrops. |
| `MR7` Countershot | `BA02` + `PR04` | UNCHANGED. A ranked Read can expose victims more often, but reflected projectiles still follow MR7's once-per-reflection rules. |
| `MR8` Heavy Barrel | `BA01` + `BR08` | **REPLACE Jam trigger with a real BR08 Vent Volley or BRK1 emergency vent.** On such a release, spend up to **60 Force once**, convert it to up to **+0.06D × spent Force total bonus**, and distribute that total evenly across eligible release rounds. At full 60 spent, each release round pierces once. BRC can snapshot **half that total damage bonus** for its eligible four-volley release **without another Force spend**. Prevent a 12-round Vent Volley from multiplying the full 60-Force damage bonus 12 times. |
| `MR9` Reactive Armor | `BA06` + `OR06` | UNCHANGED genuine Mine producer. Eligible real enemy-hit prevention generates Mines at feet per **10% max HP** prevented (fractions banked), max **3 per incoming hit**. Mine objects arm and detonate using original rules and interact normally with V5 Chain Reaction. Self-damage still cannot create them. |

`BAE1 Gun Shield` has a `BR06` Evolution requirement; a rank-2/3 Crossfire remains **the same owned BR06 ID** for its recipe. Generated edge shots must not duplicate held Guard projectile stock. `MOQ5 Carry` may still transport up to three genuine friendly Mines (from MR6, MR9 or appropriate Q trap), Sigils or Wells. Ordinary OR02 grenades attached to enemies are **not friendly stationary Mines** eligible for Carry.

### 5.2 Ranged × Magic Fusions

| ID | Existing parents | V5 compatibility treatment |
|---|---|---|
| `RM1` Spellshot | `PR03` + `IN06` | UNCHANGED; higher PR03 rank gives more eligible physical pierces, but each projectile still takes **at most one Echo per Sigil** and cannot reload itself from a just-released Echo. |
| `RM2` Backtrack | `PR07` + `DT06`, plus `DTA` | UNCHANGED. Ranked return damage never creates a new physical return; each real return hit advances the oldest Debt bucket by **0.5s** and uses the original +0.3D cap logic. |
| `RM3` Gravity Round | `PR04` + `DO01` | UNCHANGED: Weak Point consumption creates a forward Well. Make its line preview and pull readable, but don't redesign Gravity in this Ranged pass. |
| `RM4` Bullet Runes | `BR06` + `IN01` | UNCHANGED cadence **every third actual Crossfire shot**. Ranked BR06's two simultaneous points count as two real edge shots, **not two native inputs**. New Sigil pulses fire their prescribed one 0.5D Ranged shot and do not recursively advance Crossfire. |
| `RM5` Wildfire | `BR04` + `DT10` | Keep named **25%** combat roll and 3 × **0.5D** burning fragments on actual Hot Rounds Burn deaths; this now works from basic non-Heat Hot Rounds as well as thermal Hot Rounds. Misfortune roll/failure behavior stays V4. Do not let radiant-aura kills masquerade as Hot Rounds Burn kills unless they actually carry the Hot Rounds named damage provenance. |
| `RM6` Stormwire | `BR09` + `DO07` | UNCHANGED: a Core Ricochet hit against a Linked enemy travels along unvisited Link members. With ranked BR09, tag and track the physical ricochet family separately from the RM6 wire; the same Linked member may not be re-visited under a newly manufactured bounce identity. |
| `RM7` Rune Bomb | `OR02` + `IN09` | **Critical adapter:** when an OR02 or OR09 **travelling Grenade physically crosses/touches a friendly Sigil**, convert that **one** projectile into a genuine **Sigil-attached Mine** (do not first detonate the Grenade). It now counts against ordinary Mine capacity, arm timing and **max 3 attached Mines per Sigil**. A Proximity Q-trap may also qualify if it physically touches a Sigil; on conversion, **remove it from the separate Q trap pool and allocate one ordinary Mine slot**, never hold both pool slots for one object. Detonating either partner detonates the other once; prevent Mine → same Sigil → same Mine loops, but let nearby **different** Mines continue Chain Reaction. The attached Mine should visibly sit on the Sigil rim. |
| `RM8` Time Bomb | `OR04` + `DT09` | UNCHANGED: Secondary Blast Shells consume eligible unpaid Debt and use the existing 0.5s delay and 75% transfer bonus. New OR02 Grenade blast kills may generate more Secondary Blast Shells, but a **Grenade is not itself the RM8 time-debt Shell**. |
| `RM9` Meteor | `OR12` + `DO01` | UNCHANGED: Big One becomes 6D meteor after 1s with a Well at landing. Ranked OR12 changes **how often** a Big One qualifies, never duplicates one qualifying occurrence into multiple meteors. |

### 5.3 Resource, price, save and graph migration

1. **Preserve IDs and types:** `BR01`, `BR03`, `BR07`, `BR08`, `BR11`, `OR02`, `OR05`, `OR09`, `OR10`, `BRF1`, `BRF2`, `BRV3` all retain their IDs/kinds/Core affiliations despite renamed behavior. Explicitly update their display names, tooltips, `rules` strings and any duplicated documentation. Do not leave stale V4 Heat/Jam/Mine claims in UI or exported search entries.
2. **Remove implicit Heat claims:** in V4, `BR03/04/07/08/11/BRQ` may separately claim Heat. In V5, **only `BR03` purchases Hot Core** (or the explicitly documented equipped `BRA` acting on *owned* Hot Core). `BR04`, `BR08`, `BR11` and Q operate without Heat; they check whether `BR03` is actually owned for optional thermal bonuses. `BRF2`, `BRK1`, `BRS1`, `BRA` explicitly require it.
3. **Rebuild affected predicates:** `BR03` requires `BR01`; `BR07` requires `BR01`; `BRF1` requires `BR01`; `BRF2`/`BRK1`/`BRS1`/`BRA` require `BR03`; `OR05`/`OR06` require `OR02`; `OR10` requires `OR02 OR OR09`. Rank upgrades require their owner and the rank gates from §1.
4. **Preserve mutual exclusion:** `BR10` vs `BR12`, `BRF1` vs `BRF2`, `ORQ1` vs `ORQ2`, `ORF1` vs `ORF2`, `ORV1` vs `ORV2` and all pre-existing conflicts. A purchase of an additional **rank** does not deactivate a mutually exclusive sibling or grant permission to own one.
5. **Preserve adjacent edge identity:** no new tree-map node for ranks. Unless the existing graph forbids a legal route after new prerequisites, keep existing `links` and the corresponding 646-edge V4 graph. **Do not mutate only `nodes[].links` while leaving `edges[]` stale.** Validate symmetry and updated route reachability. If a link is genuinely changed later, modify both representations and rerun path tests.
6. **Native vs foreign:** V4 Gate still opens full foreign territories but does not replace the native player weapon. Precision pierced bullets, cross-Core fragments and Witness: Shot remain eligible only for the specific rule each node states. A Melee native cannot gain the native gun's Spin Up stages simply by owning foreign `BR01`; foreign Barrage remains useful through real Ranged Witness hits, `BR04` Burn, `BR05` kills, `BR06` Crossfire and relevant Fusions.
7. **Existing authored build routes are now stale as written:** V4's `Bullet Hell`, `Stormwire`, `Three-Core avalanche`, `Carpet Bomb`, and `Runes and mines` describe Heat/Jam/Caltrops mechanics that have changed. Recalculate exact prices, check that every node remains legally reachable, and rewrite their `play`, `risk` and `adapt` descriptions instead of merely editing node labels.
8. **Saved games:** The quick prototype should use **fresh saves or a separate V5 branch/save namespace**. This is a semantic schema change, not a harmless tooltip fix. Do not auto-convert an old owned V4 `BR01` into its new behavior in production without an explicit opt-in migration/refund plan. If production save migration is demanded later, version the ledger, archive old payment receipts, map old Heat-specific investments to one-time compensation or legal new purchases, verify refunds and preserve a rollback snapshot. This proposal does not invent a supposedly safe automatic old-save conversion.
9. **Evolutions remain a separate sign-off:** V5 may temporarily hide `BRE1`/`BRE2` while adapting their Heat/Jam semantics; do not permanently delete their recipes or claim all 18 V4 Evolutions were redesigned. Preserve `ORE1`/`ORE2` through the optional placed-Coordinate mode. Keep `PRE1`/`PRE2` unchanged.
10. **Named provenance:** Keep original root IDs through extra Fifth Shot volleys, ranked Fragmentation, Bonus reserve rounds, Grenadier groups, Sticky Follow-Up, generated Secondary Blast Shells, real Mine conversions and BRC/ORC emissions. Every consumer must know whether its incoming event was `native_input`, `core_strike`, `generated`, `blast`, `burn`, `projectile`, `shell`, `grenade` or `mine` as applicable. Never infer an event's class from the player's current visual weapon alone.

---

### 5.4 Definitive foreign-Barrage usability adapter

V4 Gates open the full foreign Core region without changing the player's *native attack*. Therefore V5 must not leave a purchased foreign Barrage starter or kill-throttle node completely inactive just because a Melee/Magic native player has no native Ranged input. This is an **explicit alternative mode**, not a hidden increase to native fire rate:

- **Foreign `BR01` Spin Up:** on foreign Ranged access, track actual **Witness: Shot** events. The first, second and third real Witness strikes within an ongoing chain (each successive Witness event at most **4s** after the last) yield foreign stages **1, 2 and 3**. A qualifying Witness strike receives **+0.1D / +0.2D / +0.3D** at these respective stages as bonus damage on that actual shot, not new virtual bullets. After **4s** with no real Witness: Shot, return to stage 0. Foreign mode never accelerates native Melee/Magic firing. Rank 2/3 of foreign `BR01` instead improve those flat per-Witness bonuses to **0.15/0.30/0.45D** and **0.20/0.40/0.60D**, respectively; timing stays 1/2/3 real Witness events. The ordinary native-Barrage rank table applies only when Ranged is the native Core.
- **Foreign `BR07` Kill Throttle:** at foreign `BR01` stage >=2, eligible distinct Ranged-source kills advance the normal 3/2-kill counter and grant Overdrive. During Overdrive, each *actual foreign Witness: Shot* creates one additional **0.4D** side round (Proc Power 0.25) with no native input or Heat gain, instead of generating a round per nonexistent native Ranged attack. Preserve 2/2.5s durations; if the next foreign Witness arrives after Overdrive expiry, the extra round is not free. Preview this lower-frequency behavior in the tree.
- **Foreign `BRQ` Burst:** for its 2s/3s active window, the player retains native Melee/Magic attacks. In addition, **every second real native attack activation during that Q** emits one **0.45D** Ranged side shot (Proc Power 0.35) toward the aim, distinct from the ordinary Gate Witness cadence and not another native input. Its normal 12-round Q completion fan still fires at the end, and appropriate V4 Q Core-strike weighting still applies. It does not double native Melee/Magic firing rate. Hot Core, if present, gains Heat only from the actual ordinary Gate Witness at +4 (not from these temporary Q side shots).
- **Foreign `BR08` Vent Volley:** the ordinary every-10/12-**native-Ranged** auto release does not exist for foreign builds, but a purchased `BRQ` completion remains a legal release source. Its tooltip must explain this difference before purchase.
- **Foreign `BR11` Reserve Feed:** each actual foreign Witness: Shot contributes **0.6** reserve-generation credit instead of native input credit. The **fourth real Witness: Shot** in a separate repeating foreign-shot counter can release up to six stored reserve rounds toward aim, even without `BRQ`; this counter is independent of the store threshold. Buying it on a foreign route therefore produces observable ammunition rather than holding inaccessible reserves indefinitely.
- **Foreign `BRC` Overload:** the ordinary 20-*native*-input Spin Up route does not exist for a foreign Core. It may still activate via any legitimate thermal `BRA`/Hot Core path or **the normal completion of `BRQ` after at least 6 eligible real BR05 fragment kills occurred during that same Q activation and its active duration**, with the existing 8s recovery and six-local prerequisites. Never count the catastrophe's own outgoing kills toward this threshold. This is intentionally a difficult hybrid payoff, not an automatic native-gun equivalent.

Every foreign-mode tooltip must display which parts of its native form are unavailable and what real Witness / Q event replaces them. If implementation proves incompatible with the actual Gate combat contract, surface that conflict during code review and gate the broken purchase in the **prototype** rather than silently awarding dead talents.

---

## 6. PROPOSED TEST BUILDS AND EARLY COST CHECKS

These are illustrative **local-component purchase totals** calculated using the existing base node prices plus the new additional-rank table; they **exclude equipment**, optional sinks and prerequisites not listed. Choosing a free starter makes its rank 1 cost zero. A valid prototype test must still confirm all required adjacency and unique-local gates from the authored graph.

### P1 — Precision control: long-range engineered bullet

Sequence: `core.ranged` → free `PR01` → `PR02` (200) → `PR03` (400) → `PR07` (400) → `PR03` rank 2 (700) → `PRQ` (800). **Proposed paid subtotal: 2,500 Followers.** After those local nodes, add `PR05` to test aimed fire or `PR09` after verifying its prerequisite. The expected play identity is geometrically meaningful long-range hits, not additional ammunition volume.

### B1 — No-Heat Barrage: immediately visible projectile storm

Sequence: `core.ranged` → free `BR01` Spin Up → `BR02` (200) → `BR05` (400) → `BR06` (400) → `BR05` rank 2 (700) → `BR01` rank 2 (350) → `BRQ` (800). **Proposed paid subtotal: 2,850 Followers.** It contains **no `BR03` Hot Core**: no Heat bar and no Jam. This is the essential A/B test against Precision. If it is still dull, adjusting Heat cannot fix the primary Barrage identity.

### B2 — Thermal machine gun: active risk and visible aura

Sequence: free `BR01` → `BR02` (200) → `BR03` Hot Core (400) → `BR04` (400) → `BR08` (400) → `BR05` (400) → `BRQ` (800) → `BRF2` Thermal Fury (800). **Proposed paid subtotal: 3,400 Followers.** At least six **unique** locals are owned before the fork, and the BR03 prerequisite is satisfied. Compare Meltdown uptime, close-range burn contribution, health-payment risk and the amount of visible extra fire with B1, using the same base items.

### O1 — Automatic Grenadier: no mandatory Mines or Coordinates

Sequence: `core.ranged` → free `OR02` Grenadier → `OR01` (200) → `OR04` (400) → `OR08` (400) → `OR02` rank 2 (350) → `ORQ` (800). **Proposed paid subtotal: 2,150 Followers.** Existing graph routes are legal via `OR02–OR01–OR04–OR08`; two local nodes allow Q. Use normal tap-Q for immediate bombardment. `OR05`, `OR06`, `ORQ4` and persistent Coordinates are **not required** for this route to be fun.

### O2 — Explosive chain specialist

Start from O1; buy `OR05` (400) through `OR02`, `OR06` (400) through `OR05/OR02`, `OR09` (800) through `OR04`, and then `OR11` (800) through `OR06/OR09` adjacency as legally available. The point of this build is **deliberately chosen additional explosive interactions** rather than an entry tax. Test a high-density horde and a durable isolated elite separately.

### Hybrid regression routes

- `MO04` + `BR06` + `MR5`: afterimages generate real edge-gun/fusion shots but no phantom native Ranged inputs.
- `EX10` + `BR05` + `EX01` + `MR2`: ranked fragments execute legitimate new victims while the one-extra-fragment rule remains separate from the ranked ordinary fragment group.
- `BA01` + `BR08` + `MR8`: Vent Volley spends Force exactly once, not once per radial projectile.
- `OR02` + `IN09` + `RM7`: a travelling Grenade becomes a real Sigil-attached Mine, then `OR06` can chain to a different explosive but not revisit itself.
- `OR04` + `DT09` + `RM8`: a Grenade kill can create a Secondary Blast Shell that then consumes the initiating corpse's eligible Debt.
- `OR12` + `DO01` + `RM9`: higher-rank Big One occurs more often, but each qualifying Shell creates exactly one Meteor.

---
## 7. IMPLEMENTATION ORDER AND ACCEPTANCE TESTS

This document describes **desired behavior**, not a claim that the current Godot prototype already supports it. Collaborators should first confirm the existing native-input, hit ledger, ancestry, projectile representation and tree purchase APIs in the actual repository. Do not rewrite combat architecture merely because a concept description uses a different label.

### 7.1 Work packages

1. **Branch, backup and baseline:** preserve V4 JSON and a testable V4 run. Add `ranged_v5_prototype` as a separate design/version identifier. Record existing reproducible Precision, Barrage and Ordnance test seeds.
2. **Ledger ranks:** implement rank fields and actual payment receipts; migrate only fresh V5 saves initially. Make ranks visible in the tree UI and searchable. Implement legal upgrade/rank refund, respec and unique-local counting before tuning numbers.
3. **Precision control:** implement small rank changes without restructuring its node geography; generate a baseline against unchanged V4 Precision to detect ordinary power creep from ranked builds.
4. **Barrage ordinary fire:** implement BR01 Spin Up, ranked BR02/05/06 and BR11's no-Heat reserve behavior. At this checkpoint, **a player must be able to build an enjoyable no-Heat machine gun**. Only then add BR03 Hot Core, ranked BR04, the world-space aura and later thermal forks.
5. **Grenadier:** implement a real travelling/attached `Grenade` payload, new OR02 ranking, passive OR05 Sticky Follow-Up, shared OR06 chain resolver and updated OR09/OR10. Then change Designate's tap/hold Q interaction. Do not initially require redesigning every late Revelation just to evaluate the new early path.
6. **Hybrid adapters:** repair §5 dependencies. Verify that V4 `Mine` remains a genuine supported object for MR6, MR9, RM7, Q Proximity and existing movement transport.
7. **Forks, Q mutations, catastrophes:** update triggers and tooltips. Implement only the minimal Evolution adapters described; hide incomplete recipe offers rather than issuing nonfunctional purchases.
8. **Presentation:** render distinct Spin Up/Heat states, one-to-one projectile/attack feedback, clear Grenade vs Shell telegraphs, rank-up previews and the true area of danger for Danger Close.
9. **Performance:** instrument and optimize emission without silently changing the gameplay event model. Evaluate grouped simulation only after confirming baseline event equivalence.
10. **Playtesting:** rerun matched native Ranged seeds, one hybrid seed for each changed fusion family and at least one long-run high-Follower test. Balance prices and numbers after observing behavior.

### 7.2 Deterministic purchase / graph tests

| Test | Required result |
|---|---|
| `RANK-01` | A 200-Follower free starter purchases rank 1 at actual paid 0; rank 2 costs 350 and records that actual payment. |
| `RANK-02` | Ranked BR05 counts once, not four times, toward BRQ/BRF/BRC/BRV unique-local gates. |
| `RANK-03` | Attempting rank 3 with fewer than 2 **other** unique local nodes fails without spending Followers. |
| `RANK-04` | Attempting rank 4 with fewer than 4 **other** unique local nodes fails without spending Followers. |
| `RANK-05` | Gate-locked foreign nodes cannot be purchased/upgraded before the corresponding Core is accessible. |
| `RANK-06` | Refund from rank 4 to rank 1 returns exactly the original recorded rank-4/3/2 payment totals. Removing other locals correctly refunds now-illegal higher ranks without duplicated receipts. |
| `RANK-07` | Undo Last Trade, saved-ledger roundtrip, branch migration guard and item/vendor purchases cannot recreate an already refunded rank payment. |
| `RANK-08` | Every updated `requires` points to an existing node; every `links` entry is reciprocal in the map representation and `edges[]` is synchronized. All three legal free starters per Core remain selectable. |
| `PR-01` | PR03 ranks give **2, 3, 4, 5** additional pierces, and unranked PR03 still qualifies all original Fusion parents. |
| `PR-02` | PR02's ranked +0.2/+0.4D applies only to Weak Points created through Far Shot, not all exposures. |
| `PR-03` | A PR07 return at rank 3 applies 90% once to its appropriate captured return damage; no duplicate physical return is created. |
| `PR-04` | PR09 emits exactly 2/3/4 physically distinct split projectiles under its actual authored kill condition, without calling itself from a non-kill. |
| `PR-05` | PRC's original dense-enemy trigger and alternate durable-target trigger each work; if both reach threshold together, catastrophe fires once and enters one recovery period. |
| `BR-01` | BR01 without BR03 shows **no** Heat bar, Jam, passive cooling state or thermal aura. Its stage bonuses are observable and decay at the authored rates. |
| `BR-02` | BR01 stage-3 bonus is additive with ordinary percentage-rate buffs; BRQ ×2 applies only once. Actual attack intervals correspond to displayed state. |
| `BR-03` | BR02 ranks arm exactly 2/3/3/4 projectiles every 5/5/4/3 credited Core-strike activations. Extra rounds never advance BR02's own counter. |
| `BR-04` | A rank-4 BR05 real Ranged kill emits five seeking fragments and one real fragment kill generates one new group, not duplicate groups for the same victim. |
| `BR-05` | A rank-3 BR06 event generates two external edge projectiles; RM4/MR5 count **actual edge shots**, not the one initiating native input. |
| `BR-06` | BR04 still burns without BR03. Owning BR03 adds only its separately specified higher-Heat AoE/refresh behavior. Burn ticks have Proc Power 0. |
| `BR-07` | Heat 50/75/100 has a correct visible firing change and **only the highest active** radiant aura radius/DPS. Enemies just outside the displayed aura take no radiant ticks. |
| `BR-08` | Ordinary Meltdown lasts 2s, resets to 40 and doesn't disable the basic weapon. Overclock uses its explicitly different sustained-Heat and emergency-vent rules. |
| `BR-09` | BR08's automatic 10/12-input release works without Hot Core or BRQ. BRQ completion adds its documented release once if BR08 exists. |
| `BR-10` | BR11 works without BR03: builds reserve on native inputs, automatically releases on its authored schedule and consumes stored rounds only once if BR08 fires on the same activation. |
| `BR-11` | Pinball and Cluster Rounds still conflict. Ranked BR05 increases the ordinary on-kill group but does not secretly increase Pinball bounce count. |
| `BR-12` | `BRQ6` early cancellation produces no completion fan, BR08 Q-end release, Vented nova or Ammo Dump. |
| `BR-13` | BRC activates on the stated no-Heat rapid-fire path and on legal Heat paths; it cannot recursively count its own outgoing BRC volleys toward another BRC trigger. |
| `BR-14` | A melee/magic `BRA` owner must actually own BR03. `BRA`-generated legitimate Heat respects native hit provenance, Health Payment exclusions and no phantom double native attack. |
| `OR-01` | OR02 ranks generate **1/1/2/2** Grenades every **4/3/3/2** activation credits; a miss still earns native input credit, generated explosions do not. |
| `OR-02` | A living-target grenade attaches and detonates once after 0.40s or once through OR05, never damaging once on attach and again on detonation. |
| `OR-03` | OR03 advancement + OR05 immediate detonation in the same physics frame yields one resolved blast, with OR05's +0.8D applied only once. |
| `OR-04` | OR06 removes each explosive from live armed graph before its effect resolves; three mutually touching Grenades each detonate once without infinite recursion. |
| `OR-05` | An OR02 Grenade blast kill triggers a legal OR04 Shell; that Shell's fresh blast kill may trigger another OR04 Shell from a *different* victim. A burn-only kill does not masquerade as a blast kill. |
| `OR-06` | OR09 requires real travel; enemy force-move does not advance its distance. Its rate limiter banks no more than 2L. |
| `OR-07` | OR10 stores by real eligible activation credit; reserve ammo is added only to an actual new OR02/OR09 group and doesn't generate another OR10 credit. |
| `OR-08` | OR11 fires 3/4/5 Shells according to rank and scans exactly once at the qualifying movement+blast-kill event. |
| `OR-09` | OR12 transforms only every 7th/6th/5th qualifying Shell; Grenades and Mines don't advance Big One. RM9 creates one meteor per Big One occurrence. |
| `OR-10` | Tap-Q does an immediate ordinary 4-Shell sequence; hold-Q >=0.35s places a Coordinate **without first firing**. Both respect their separate recovery/cooldown rules. |
| `OR-11` | `ORQ1` and `ORQ2` are still mutually exclusive and affect both tap-Q and Coordinate-fired sequences. |
| `OR-12` | `ORQ4`'s Mine-tagged proximity payload interacts with approved Rune Bomb and Chain Reaction logic while retaining its independent Q trap capacity. |
| `OR-13` | ORC activates via a twelve-blast same-root chain or a 24-blast 8-second rolling window, but an overlapping result fires it only once per recovery. |
| `HYB-01` | MR2 generates ranked BR05's ordinary group **plus exactly one** MR2 bonus fragment on a real fragment execution; no ancestry reset. |
| `HYB-02` | MR8 spends Force only once across the Vent Volley; BRC can reuse the allowed half-damage **snapshot**, not spend Force again. |
| `HYB-03` | RM7 physically converts a Grenade crossing a Sigil into one Mine and preserves the cap of three per Sigil; no grenade/Mine double explosion. |
| `HYB-04` | MR6/MR9 genuine Mines and ORQ4 Proximity traps remain supported independently of automatic Grenadier. |
| `HYB-05` | An existing authored build that now lacks a mandatory prerequisite fails *clearly*, rather than becoming silently unlocked or buying a nonfunctional node. |

### 7.3 Playtest methodology: don't confuse visibility and strength

Run **at least three** matched seeds per build (`P1`, `B1`, `B2`, `O1`, `O2`), ideally both a high-density encounter and a durable-target encounter. With only three, results are diagnostic rather than conclusive: avoid pretending small-sample means establish competitive balance. Keep the starting equipment, player level, segment length and environmental layout identical when feasible. Also complete at least one **free-choice** run, because a sterile matching setup may suppress interesting build adaptation.

Collect at least these fields by **node family and original cast root**:

- Purchases: first acquisition time, subsequent rank times, incremental Follower costs, available but skipped ranks, respec reasons if available.
- Ranged inputs: shots actually fired per second, uninterrupted firing time, Spin Up stage uptime, idle/reset behavior, Q firing uptime and real extra-projectile counts.
- Damage: primary Core; precision Weak Point; ranked pierce/return/split; Fifth Shot; Fragmentation; Crossfire; Hot Rounds Burn; Heat aura; grenades; Shells; actual Mines; Secondary Blast; catastrophe/revelation separately. Count both **damage dealt** and **damage delivered to a living target** so corpse/overkill spam isn't mistaken for useful damage.
- Heat: time in bands `<50`, `50–74`, `75–99`, Meltdown; aura hits per second; visible aura area vs actual damaging radius; player health payments and other self-risk.
- Ordnance: grenades launched/hit/attached/expired; OR05 early triggers; chain length; Secondary Blast depth; manual Coordinate use vs tap-Q use; detonations that hit zero living enemies.
- Performance: median and 95th-percentile frame times, peak live physical projectiles, virtual projectile payload count, projectile spawning per second, worst high-density on-kill cascade, enemy/spawn culling impact.
- Qualitative: after each short run, ask whether the player can name the strongest-feeling upgrade, whether they **noticed** the upgrade's trigger without reading the log, whether they ever felt compelled to buy a disliked node, and what caused them to pivot to Precision (if applicable).

**Pass/fail gates for another design review (prototype criteria):** B1 must be recognizable as a rapid bullet-generator **without Heat**; B2 must communicate thermal tiers and provide meaningful fire/area payoffs **without an ordinary baseline Jam**; O1 must feel like a Grenadier without Mine manipulation or Coordinate management; all key hybrid regressions must pass; and there must be no infinite ancestry recursion or unexplained Follower/refund duplication. Exact DPS/TTK parity is a **later tuning decision** after these gates, not an excuse to skip them.

### 7.4 Performance implementation suggestions (subject to existing architecture)

- Use existing array/data-oriented projectile simulation and `MultiMeshInstance2D` where already available. **Do not spawn a node-based enemy-like object for every rank-4 fragment** merely to show it visually.
- Use a fixed event ordering per physics tick for native input → projectile hit → damage/death → eligible on-kill emission → ordered chain resolution → cooldown/recovery state changes. Preserve ordering through queued virtual attacks.
- Particle effects and temporary visual duplicates can be pooled and allowed to visually degrade under stress **without deleting gameplay damage**. Instrument any visual pooling fallback.
- When high-density fragment groups would exceed physical projectile rendering capacity, merge rendering of spatially neighboring projectiles **only if each logical payload retains independent target selection, hit limits, damage, proc ancestry and death eligibility**. If exact equivalence cannot be proven, report the tradeoff and do not silently call it an optimization.
- V4's original per-target, per-root and per-family loop guards must still apply after increasing physical projectile counts and adding early-detoned Grenades.

---

## 8. REQUIRED JSON PATCH / TOOLTIP CHECKLIST

This `.md` is an **implementation specification**, not an already modified `tree_v5.json`. A collaborator should produce a proposed JSON diff and automated validation **before** committing it to the game. All changes to actual `rules`, `tooltip`, `requires`, `conflicts`, `links`, `edges`, optional new `rank_*` fields, supporting runtime definitions and saved-ledger logic should agree.

**Explicit new `requires` / data dependencies:**

```text
BR03: requires owned BR01               (Hot Core)
BR07: requires owned BR01               (Kill Throttle)
BRF1: requires owned BR01 AND 4 unique BR locals; conflicts BRF2
BRF2: requires owned BR03 AND 4 unique BR locals; conflicts BRF1
BRK1: requires owned BR03 AND 4 unique BR locals
BRS1: requires owned BR03 AND 4 unique BR locals
BRA: requires owned BR03 AND 5 unique BR locals
BRE1: IF ENABLED, add owned BR03 to the existing V4 Evolution recipe
OR05: requires owned OR02               (Sticky Follow-Up)
OR06: requires owned OR02               (Chain Reaction)
OR10: requires (owned OR02 OR owned OR09) (Bandolier)
All other original prerequisites: retain unless this document expressly changes them.
```

**Node IDs with explicitly changed semantics:** `BR01`, `BR03`, `BR04`, `BR07`, `BR08`, `BR11`, `BRQ`, `BRQ1–BRQ7` where specified, `BRF1`, `BRF2`, `BRK1`, `BRK2`, `BRC`, `BRV`'s optional-Heat handling, `BRV3`, `BRA`, `BRS1`; `OR02`, `OR03`, `OR05`, `OR06`, `OR09`, `OR10`, `ORQ` and applicable `ORQ4/5` adapters, `ORF1/2`, `ORC`; plus selective `PRF2` and `PRC` changes. Other ranked locals change only via their recorded per-rank table.

**Ranked node maxima:**

```text
PR01:3 PR02:3 PR03:4 PR05:3 PR06:2 PR07:3 PR09:3 PR11:2 PR12:3
BR01:3 BR02:4 BR04:3 BR05:4 BR06:3 BR07:2 BR08:2 BR09:2 BR11:3 BR12:2
OR01:3 OR02:4 OR08:3 OR09:3 OR10:3 OR11:3 OR12:3
```

All unlisted PR/BR/OR nodes in this proposal have **maximum rank 1**, apart from the original **separate infinite sinks**, which retain their own V4 scaling and unlock rules. In the first V5 pass, don't rank Q mutations, forks, Keystones, Catastrophes, Revelations, Evolutions, Axioms or other Core trees.

**Implementation artifacts expected from the collaborator:**

- Proposed `tree_v5_ranged.json` or a structured source diff from the complete V4 JSON; retain an archived V4 and **do not claim the MD itself edits gameplay**.
- A readable changelog mapping every renamed ID to its old/new `name`, `tooltip` and mechanical rule, with unmodified node IDs marked unchanged.
- Updated ledger and runtime event adapters, including rank purchase/undo/respec and new tagged `Grenade` payload.
- Updated UI labels/preview text, Spin Up states, actual Heat radius and Mine/Grenade/Shell silhouettes.
- Unit/integration tests from §7 and validation of all originally authored builds, affected Fusions, Gate routes, Evolutions (enabled/hidden status) and graph references.
- Performance evidence in a comparable high-density encounter before declaring the projectile multiplication safe.

---

## 9. PARKED NEXT PASS: AFTERIMAGE VISIBILITY AND LOW-TIER SIGIL LINK

These two points come from the same real playtest conversation but are **not required** to complete Ranged V5. They are intentionally separated to prevent an implementer from accidentally inventing an unapproved full Magic redesign.

### 9.1 Momentum Afterimage (`MO04` / `MO12`)

Preserve V4's mechanics: at 60 Momentum, `MO04` repeats a Melee Core strike from its original position after **0.3s for 0.6D**; `MO12` creates three Afterimages on its existing high-Momentum third-strike condition. The reported problem was mainly visibility. Proposed feedback patch: briefly display an identifiable translucent silhouette **at the saved original attack position**, replay the relevant weapon arc/attack animation at the correct delayed time, show distinct hit confirmation and then dissolve. The silhouette must be damage-source legible without obscuring hostile telegraphs or spawning a full duplicate gameplay player node. Test feedback **before** altering the numbers.

### 9.2 Invocation low-tier Sigil link (separate Magic discussion)

Prototype concept only: after **two live parent Sigils** exist, an early optional **Arcane Conduit** node creates a clearly drawn, damaging line between the **oldest two live parent Sigils** (not every possible pair, to avoid instant quadratic line spam). Link width **R/4**; enemies intersecting it receive **0.30D/s**, ticked every **0.25s** with Proc Power **0** and one application per target per tick regardless of overlap at an endpoint. On crossing from outside, apply an immediate **0.15D** hit, then require **0.5s** before that target can receive another crossing hit from the same line. Keep the original Sigil pulses independent. The line disappears when either parent expires, detonates or is replaced. Possible later ranks: width `R/4 → R/3 → R/2`, or a **20% slow for 1s** on crossing at rank 2; **only a later optional mutation** may apply a **0.4s stun after 1.5s continuous exposure**, with a per-target **4s** stun immunity. Bosses should receive a stagger equivalent rather than indefinite hard CC. These numbers are **parked experimental values**, not incorporated into `tree_v5_ranged.json` and not assigned a final `IN##` identifier yet.

---

## 10. COLLABORATOR INSTRUCTION (COPY/PASTE IF HANDING TO A CODING AGENT)

> Use the attached original `tree_v4.json` as the structural source of truth and this document as a **proposed Ranged V5 behavioral override**. First audit the actual game implementation to discover native input, projectile, event, resource, rank, ledger, Q and respec APIs. Then produce (1) a specific JSON/data diff covering PR, BR and OR; (2) an implementation/compatibility plan for the real repository; and (3) deterministic tests and an early playable prototype. Preserve all unchanged V4 nodes, original cross-Core connectivity and reciprocal graph edges. Do not implement Evolutions beyond the explicitly named compatibility adapters. Do not introduce new original node IDs for rank levels. Where an authored change conflicts with an existing engine contract, identify the conflict and propose the smallest preserving adapter rather than silently discarding the design or inventing missing infrastructure. Treat the listed numerical values as initial playtest hypotheses, validate them, and flag actual bugs, broken routes, overpowered multiplicative interactions, unclear graphics and performance regressions. Implement one work package at a time with passing tests. Do not present untested theoretical balance as proven.

**Design sign-off questions after the first playable pass:** Does Barrage feel great without Hot Core? Does Hot Core add an exciting *optional* risk/reward curve? Does Ordnance let you play an immediate aggressive Grenadier before buying secondary explosive interactions? Are early rank investments competitive with purchasing entirely new nodes? Did increasing projectile volume create genuine fun, comprehensible on-screen action and manageable frame times—or just numerical noise?

---

## APPENDIX A. HOW TO READ THIS AGAINST V4

The following index is generated from the uploaded **original V4** node records. It is **not the new effect table**: the new authoritative proposals are in §§2–5 above. It exists so a recipient can check original IDs, kinds, first-rank base costs and original player-facing effects without accidentally treating the new plan as the old implementation. For the exact complete V4 links, recipes and unmodified mechanics, **also attach `tree_v4.json`** to any coding agent or collaborator. A Markdown handoff cannot replace the full original data source.


### Original V4 Precision node index

| Original ID | Original name / kind | Base cost | Original specific prerequisites and conflicts | Original V4 tooltip |
|---|---|---:|---|---|
| `PR01` | Read (local) | 200 | requires: none; conflicts: none | Ranged Core hits build Read using their Proc Power. |
| `PR02` | Far Shot (local) | 200 | requires: none; conflicts: none | The first Ranged Core hit on an enemy farther than 2R exposes a Weak Point immediately. |
| `PR03` | Penetrator (local) | 400 | requires: none; conflicts: none | Ranged Core projectiles pierce two additional targets. |
| `PR04` | Second Read (local) | 400 | requires: ((PR01 OR PR02) AND PR03); conflicts: none | Consuming a Weak Point causes the next enemy struck by the same projectile to become exposed after its damage. |
| `PR05` | Held Breath (local) | 400 | requires: none; conflicts: none | Not making a native attack for 0.8s stores Aim. |
| `PR06` | Bank Shot (local) | 400 | requires: none; conflicts: none | Your Core projectiles may bounce once off terrain. |
| `PR07` | Return Shot (local) | 400 | requires: none; conflicts: none | A Core projectile reaching maximum range or exhausting pierce returns along its travelled path for 60% damage. |
| `PR08` | Overpenetrate (local) | 400 | requires: PR03; conflicts: none | Each unused pierce when a shot turns back adds 0.2D and R/4 width to its return, maximum +1D and +R width. |
| `PR09` | Split Line (local) | 800 | requires: ((PR01 OR PR02) AND PR03); conflicts: none | Killing an exposed enemy after a projectile has crossed another target emits two shots at ±20 degrees, each 0.7D with one pierce and Proc Power 0.4. |
| `PR10` | Dead Center (local) | 800 | requires: (PR01 OR PR02); conflicts: none | A native shot whose aim line crosses the central half of a Weak Point target returns 0.25s Q recovery and preserves half the Aim preparation time. |
| `PR11` | Crossing Fire (local) | 800 | requires: none; conflicts: none | An enemy crossed by two different projectile trajectories within 0.5s takes an extra 1D. |
| `PR12` | Long Game (local) | 800 | requires: PR07; conflicts: none | A returning shot that kills stores one spare round, up to three. |
| `PRQ` | Deadshot (active) | 800 | requires: 2 of (PR01,PR02,PR03,PR04…); conflicts: none | Q: slow world time to 35% for up to 0.6 real seconds while choosing a line; release fires a 4D beam across the screen, R/3 wide. |
| `PRQ1` | Twin Shot (mutation) | 600 | requires: PRQ; conflicts: none | Place two lines during the aiming pause; each fires for 2.5D. |
| `PRQ2` | Quick Draw (mutation) | 600 | requires: PRQ; conflicts: none | Deadshot fires immediately along aim, with cooldown 5s and 3D damage. |
| `PRQ3` | Wallbang (mutation) | 600 | requires: PRQ; conflicts: none | Deadshot crosses walls; each distinct obstruction crossed adds 0.5D, at most +2D. |
| `PRQ4` | Fan (mutation) | 600 | requires: PRQ; conflicts: none | Each Deadshot line becomes five parallel lines separated by R/3. |
| `PRQ5` | Recalculate (mutation) | 600 | requires: PRQ; conflicts: none | The first three real kills from the opening beam sequence fire new 1.5D lines from their victims toward current aim. |
| `PRQ6` | Last Round (mutation) | 600 | requires: PRQ; conflicts: none | Deadshot executes normals below 25% HP after damage. |
| `PRF1` | Deadeye (fork) | 800 | requires: 4 of (PR01,PR02,PR03,PR04…); conflicts: PRF2 | Manually aligned central Weak Point hits gain +1D and one pierce. |
| `PRF2` | Smart Rounds (fork) | 800 | requires: 4 of (PR01,PR02,PR03,PR04…); conflicts: PRF1 | Core projectiles curve up to 30 degrees toward exposed targets. |
| `PRK1` | One Bullet (keystone) | 1200 | requires: 4 of (PR01,PR02,PR03,PR04…); conflicts: none | Native Ranged firing interval doubles; its main projectile deals 3D with Proc Power 1.25. |
| `PRK2` | Cross-Eyed (keystone) | 1200 | requires: (4 of (PR01,PR02,PR03,PR04…) AND PR06); conflicts: none | Core shots alternate 20 degrees left/right of aim. |
| `PRC` | Firing Squad (catastrophe) | 2400 | requires: (6 of (PR01,PR02,PR03,PR04…) AND PR03 AND (PR07 OR PR09)); conflicts: none | One projectile root crossing twelve distinct enemies or consuming six Weak Points creates six edge guns. |
| `PRV` | JUDGEMENT (revelation) | 4800 | requires: (6 of (PR01,PR02,PR03,PR04…) AND (PRC OR ((PRK1 OR PRK2) AND 3 of (PRQ1,PRQ2,PRQ3,PRQ4…)))); conflicts: none | V: slow world time to 20% for up to 1.5 real seconds and place three wide lines across the screen. |
| `PRV1` | Auto-Plot (revelation_mutation) | 1800 | requires: PRV; conflicts: PRV3 | JUDGEMENT automatically chooses three high-density lines and fires after a 0.4s tell. |
| `PRV2` | Back and Forth (revelation_mutation) | 1800 | requires: PRV; conflicts: none | Each JUDGEMENT line fires again after 0.5s from its opposite end for 60% damage. |
| `PRV3` | One Line (revelation_mutation) | 1800 | requires: PRV; conflicts: PRV1 | Replace three placed lines with one cursor-steered sweep lasting 1.5s. |
| `PRE1` | Kill Line (evolution) | 0 | requires: (PRQ AND PRF1 AND PRQ5 AND PR04 AND milestone:evolution_reward); conflicts: none | Each fresh Deadshot kill redraws one 2D line from the victim toward current aim. |
| `PRE2` | Smart Grid (evolution) | 0 | requires: (PRQ AND PRF2 AND PRQ4 AND BR06 AND milestone:evolution_reward); conflicts: none | Deadshot places four edge guns for 2s. |
| `PRA` | Nothing Wasted (axiom) | 2400 | requires: (5 of (PR01,PR02,PR03,PR04…) AND PR07); conflicts: none | The first missed Core strike from each native input returns once from the far side of its aim: a shot retraces, a slash becomes a 0.8D crossing wave, and a Magic impact repeats at its original point. |
| `PRS1` | Shot Speed (sink) | 200 + V4 sink formula | requires: 4 of (PR01,PR02,PR03,PR04…); conflicts: none | Repeatable: projectile speed and maximum travel distance gain 80% × rank/(rank+80). |
| `PRS2` | Q Damage (sink) | 200 + V4 sink formula | requires: 4 of (PR01,PR02,PR03,PR04…); conflicts: none | Repeatable: total direct Q damage gains 1% × sqrt(rank). |

### Original V4 Barrage node index

| Original ID | Original name / kind | Base cost | Original specific prerequisites and conflicts | Original V4 tooltip |
|---|---|---:|---|---|
| `BR01` | Heat (local) | 200 | requires: none; conflicts: none | Claims Heat and its tier bonuses, Jam and cooling rules. |
| `BR02` | Fifth Shot (local) | 200 | requires: none; conflicts: none | Every fifth Ranged Core strike arms two extra rounds for the next strike, each 0.6D with Proc Power 0.5. |
| `BR03` | Heat Sink (local) | 400 | requires: none; conflicts: none | Ranged Core kills leave a cooling patch for 2s. |
| `BR04` | Hot Rounds (local) | 400 | requires: none; conflicts: none | Above 50 Heat, the first Core projectile impact in a volley explodes in R/2 for 0.5D and burns victims for 0.2D/s for 3s. |
| `BR05` | Fragmentation (local) | 400 | requires: none; conflicts: none | Every real Ranged kill releases two seeking fragments, each 0.6D, lifetime 2s, Proc Power 0.4. |
| `BR06` | Crossfire (local) | 400 | requires: none; conflicts: none | Every third Ranged Core strike fires one extra shot from a rotating point at the screen edge toward the cursor for 0.8D, Proc Power 0.5. |
| `BR07` | Coolant (local) | 400 | requires: none; conflicts: none | The first kill from each of four aim quadrants removes 10 Heat. |
| `BR08` | Loose Chamber (local) | 400 | requires: none; conflicts: none | Jamming fires twelve radial rounds, each 0.6D with Proc Power 0.4. |
| `BR09` | Ricochet (local) | 800 | requires: none; conflicts: none | Core projectiles bounce to one different enemy within 2R after impact, keeping 70% damage and Proc Power 0.6. |
| `BR10` | Pinball (local) | 800 | requires: (BR05 AND BR09); conflicts: BR12 | Fragments bounce once to another enemy after their first hit at 70% damage and Proc Power 0.3. |
| `BR11` | Bigger Magazine (local) | 800 | requires: none; conflicts: none | Crossing 50 or 75 Heat stores three 0.7D rounds. |
| `BR12` | Cluster Rounds (local) | 800 | requires: (BR05 AND BR09); conflicts: BR10 | Each Core ricochet impact throws two 0.5D fragments even if it does not kill, Proc Power 0.3. |
| `BRQ` | Burst (active) | 800 | requires: 2 of (BR01,BR02,BR03,BR04…); conflicts: none | Q: for 2s, double firing rate and Heat gain. |
| `BRQ1` | Sustained (mutation) | 600 | requires: BRQ; conflicts: none | Burst lasts 3s. |
| `BRQ2` | Vented (mutation) | 600 | requires: BRQ; conflicts: none | Burst completion also releases a 2D burning nova in 2R and cools to zero. |
| `BRQ3` | Enfilade (mutation) | 600 | requires: BRQ; conflicts: none | Burst rounds gain one additional bounce at 70% damage, with the selected Pinball/Cluster behavior. |
| `BRQ4` | Three Guns (mutation) | 600 | requires: BRQ; conflicts: none | Two nearby firing points mirror Burst at 50% damage and Proc Power 0.35. |
| `BRQ5` | Ammo Dump (mutation) | 600 | requires: BRQ; conflicts: none | At normal completion, fire an additional round per five Heat held immediately before the vent. |
| `BRQ6` | Emergency Stop (mutation) | 600 | requires: BRQ; conflicts: none | Canceling Burst during its first half returns half its cooldown and immediately removes 30 Heat. |
| `BRQ7` | Belt-Fed (mutation) | 600 | requires: BRQ; conflicts: none | Each distinct real death during Burst extends it by 0.08s, up to 2 additional seconds. |
| `BRF1` | Cool Head (fork) | 800 | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: BRF2 | Stopping fire between 65 and 80 Heat instantly vents to 20 and arms a +1D opening shot. |
| `BRF2` | Backfire (fork) | 800 | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: BRF1 | Jams fire twice the normal Loose Chamber rounds and pay 5% current HP. |
| `BRK1` | Overclock (keystone) | 1200 | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: none | Heat can reach 200. |
| `BRK2` | Bottomless (keystone) | 1200 | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: none | The weapon automatically fires at its normal current firing interval toward aim. |
| `BRC` | Overload (catastrophe) | 2400 | requires: (6 of (BR01,BR02,BR03,BR04…) AND BR01 AND (BR08 OR BR11)); conflicts: none | Backfire Jam, Overclock emergency vent, or three Cool Head vents within 10s emit four radial volleys 0.15s apart. |
| `BRV` | SUPPRESSION (revelation) | 4800 | requires: (6 of (BR01,BR02,BR03,BR04…) AND (BRC OR ((BRK1 OR BRK2) AND 3 of (BRQ1,BRQ2,BRQ3,BRQ4…)))); conflicts: none | For 5s, three camera-edge guns mirror native shots inward through the aim region for 0.8D each, Proc Power 0.4. |
| `BRV1` | Six Guns (revelation_mutation) | 1800 | requires: BRV; conflicts: none | SUPPRESSION has six guns dealing 0.6D per shot, retaining Proc Power 0.4. |
| `BRV2` | Sweep (revelation_mutation) | 1800 | requires: BRV; conflicts: none | SUPPRESSION guns fire independently at four shots per second even when you stop firing. |
| `BRV3` | Final Jam (revelation_mutation) | 1800 | requires: BRV; conflicts: none | On ending, SUPPRESSION fires one 1D radial round per four gun shots emitted, maximum sixty, then prevents native firing for 1.5s. |
| `BRE1` | Heat Beam (evolution) | 0 | requires: (BRQ AND BRF1 AND BRQ2 AND PR05 AND milestone:evolution_reward); conflicts: none | Burst becomes a manually swept piercing beam lasting 2s, or 3s with Sustained. |
| `BRE2` | Bullet Hell (evolution) | 0 | requires: (BRQ AND BRF2 AND BRQ4 AND BR10 AND milestone:evolution_reward); conflicts: none | Burst starts with three rotating firing points. |
| `BRA` | Hot Blood (axiom) | 2400 | requires: (5 of (BR01,BR02,BR03,BR04…) AND BR01); conflicts: none | Melee and Magic Core strikes add 5 Heat. |
| `BRS1` | Heat Control (sink) | 200 + V4 sink formula | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: none | Repeatable: Heat generation is reduced by 30% × rank/(rank+75). |
| `BRS2` | Projectile Life (sink) | 200 + V4 sink formula | requires: 4 of (BR01,BR02,BR03,BR04…); conflicts: none | Repeatable: friendly projectile lifetime increases by 50% × rank/(rank+100). |

### Original V4 Ordnance node index

| Original ID | Original name / kind | Base cost | Original specific prerequisites and conflicts | Original V4 tooltip |
|---|---|---:|---|---|
| `OR01` | Impact Fuse (local) | 200 | requires: none; conflicts: none | Every fourth weighted Ranged Core hit calls a Shell at the victim. |
| `OR02` | Caltrops (local) | 200 | requires: none; conflicts: none | Every dash drops one Mine at its start. |
| `OR03` | Short Fuse (local) | 400 | requires: (OR01 OR OR09 OR ORQ); conflicts: none | Hitting an enemy under a falling Shell advances impact by 0.15s, once per Core strike. |
| `OR04` | Secondary Blast (local) | 400 | requires: (OR01 OR OR02 OR OR09 OR ORQ); conflicts: none | A real blast kill calls one Shell on the corpse. |
| `OR05` | Mine Toss (local) | 400 | requires: OR02; conflicts: none | A Core projectile touching an unarmed Mine pushes it up to R toward aim. |
| `OR06` | Chain Reaction (local) | 400 | requires: OR02; conflicts: none | A Mine blast detonates every armed Mine whose radius it touches. |
| `OR07` | Blast Pull (local) | 400 | requires: none; conflicts: none | The outer half of a blast pulls normals R/2 toward its center after damage. |
| `OR08` | Fracture (local) | 400 | requires: none; conflicts: none | Three distinct blasts on one target arm Fracture. |
| `OR09` | Walking Barrage (local) | 800 | requires: none; conflicts: none | After travelling L, call a Shell R behind your position. |
| `OR10` | Magazine (local) | 800 | requires: none; conflicts: none | Mine cap rises to eighteen. |
| `OR11` | Saturation Scan (local) | 800 | requires: none; conflicts: none | The first blast kill after moving R marks the densest occupied cell within 3R for three Shells, 0.2s apart. |
| `OR12` | Big One (local) | 800 | requires: (OR01 OR OR09 OR ORQ); conflicts: none | Every seventh Shell becomes 4D in 2R with a 0.9s tell and Proc Power 1. |
| `ORQ` | Designate (active) | 800 | requires: 2 of (OR01,OR02,OR03,OR04…); conflicts: none | Q on empty ground places a Coordinate within the screen, up to three; placement recovery 0.25s. |
| `ORQ1` | Saturation (mutation) | 600 | requires: ORQ; conflicts: ORQ2 | Each Designate sequence calls seven Shells spread across a 3R circle rather than four at one point. |
| `ORQ2` | Homing (mutation) | 600 | requires: ORQ; conflicts: ORQ1 | Each Designate sequence calls three 2.5D Shells that track a chosen enemy until their final 0.15s landing tell. |
| `ORQ3` | Cascade (mutation) | 600 | requires: ORQ; conflicts: none | Each distinct kill by a Designate sequence adds one Shell to it, up to six additions per activated Coordinate. |
| `ORQ4` | Proximity (mutation) | 600 | requires: ORQ; conflicts: none | Designate Shells land as armed traps for 3s and explode on contact or expiry. |
| `ORQ5` | Walking Target (mutation) | 600 | requires: ORQ; conflicts: none | The selected Coordinate follows at an aim-set offset from you, up to L. |
| `ORQ6` | All Coordinates (mutation) | 600 | requires: ORQ; conflicts: none | Firing one Coordinate starts every current Coordinate in creation order, 0.2s apart, for the same cooldown. |
| `ORQ7` | Fire Again (mutation) | 600 | requires: ORQ; conflicts: none | Fired Coordinates become dormant instead of disappearing. |
| `ORF1` | Carpet Fire (fork) | 800 | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: ORF2 | Automatic Shells select different occupied cells before reusing one. |
| `ORF2` | Guidance (fork) | 800 | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: ORF1 | Your latest Core hit on an elite/boss makes it the automatic Shell target for 4s. |
| `ORK1` | Spotter (keystone) | 1200 | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: none | Three distinct blasts mark a durable target as a Beacon for 5s. |
| `ORK2` | Danger Close (keystone) | 1200 | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: none | Blasts gain +40% radius and +25% damage. |
| `ORC` | Rolling Thunder (catastrophe) | 2400 | requires: (6 of (OR01,OR02,OR03,OR04…) AND (OR04 OR OR06) AND OR12); conflicts: none | Twelve blast activations within one root draw six lanes across the visible field and land four 2D Shells along each lane over 1s. |
| `ORV` | FIRE MISSION (revelation) | 4800 | requires: (6 of (OR01,OR02,OR03,OR04…) AND (ORC OR ((ORK1 OR ORK2) AND 3 of (ORQ1,ORQ2,ORQ3,ORQ4…)))); conflicts: none | After a 1s grid tell, twenty-four 3D Shells land across occupied screen cells over 1s. |
| `ORV1` | No Safe Ground (revelation_mutation) | 1800 | requires: ORV; conflicts: ORV2 | FIRE MISSION uses forty-eight Shells and includes gaps between occupied cells. |
| `ORV2` | Firewalk (revelation_mutation) | 1800 | requires: ORV; conflicts: ORV1 | FIRE MISSION follows behind your movement and leaves a safe 1.5R corridor ahead for its duration. |
| `ORV3` | Second Salvo (revelation_mutation) | 1800 | requires: ORV; conflicts: none | Repeat the mission after 2s at 60% damage, targeting the current survivors. |
| `ORE1` | Carpet Bomb (evolution) | 0 | requires: (ORQ AND ORF1 AND ORQ1 AND OR09 AND milestone:evolution_reward); conflicts: none | Activated Coordinates follow the player for 3s, each dropping one ordinary Shell every 0.3s behind the route. |
| `ORE2` | Bunker Buster (evolution) | 0 | requires: (ORQ AND ORF2 AND ORQ2 AND OR12 AND milestone:evolution_reward); conflicts: none | Every activated Coordinate attaches to the chosen durable target. |
| `ORA` | Fuse (axiom) | 2400 | requires: 5 of (OR01,OR02,OR03,OR04…); conflicts: none | Any Q that does not already create Shells leaves one Shell at its endpoint. |
| `ORS1` | Blast Damage (sink) | 200 + V4 sink formula | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: none | Repeatable: blast damage gains 1% × sqrt(rank). |
| `ORS2` | Blast Radius (sink) | 200 + V4 sink formula | requires: 4 of (OR01,OR02,OR03,OR04…); conflicts: none | Repeatable: blast radius gains 70% × rank/(rank+95). |

**End of proposed Ranged V5 design handoff.**

<!-- END ORIGINAL RANGED V5 SPEC -->

## Appendix B — February item conversation and later Beka decisions

The user supplied this conversation dated 22 February; the export does not include a year. Preserve authorship: Varis's list contains ideas and jokes, while Nauris's replies indicate which directions interested the user. The current user has now included item development in the ordered handoff, with Beka first. Old numeric/set descriptions are historical context, not current implementation truth.

### Original supplied conversation

```text
[22.02. 18:15] Varis OP: Tev vajag missing pālis kā item
[22.02. 18:17] Varis OP: Kad iemācīsies rendedera scriptus custom taisīt, varēsi, ka missing pālis dod mazliet wavy screen efektu kad paņem. Vajag ka nav op lai nesastako tik daudz, ka neko mevar redzēt
[22.02. 18:29] Varis OP: Item ideas:
* The missing pālis
* Brutal assault gantlets
* Just molly
* Plot armor
* Duck corkscrew
* Beer(stacks up to 1 million)
* Gradmas bazooka
* 7mile boots(handmedowns)
* Degree(can be upgraded to worthless degree)
* Eldrich cristal(for head, idk. The thing that timeloops)
* Bazinga(random laugh tracks)
* Dads penis
* Druid tuning staff(spawn trees. Idk)
* Dignitiy(idk)
* Trauma(also idk)
* Along-the-way friendmaker(makes followers or smthn)
* Metaknowledge(idk. Enables minimap)
* Godot engine, the item
* The list
* Second breakfast
* Idfk(the item)
* Supa manki
[22.02. 18:30] Varis OP: The soul of coul. And its like that purple ai bird head from that one clip
[22.02. 18:30] Varis OP: If you have it you unlock the seduction minigame for shopkeepers
[22.02. 18:33] Nauris: But, hm, I could somehow work some of these items into something, like spec items, cause usual items come in sets and if you get 2/4/6 of the item set you get boost, like for conduit 2 items is just flat stat increase, 4 is electric zap, 6 for melee is big melee on kill, ranged is minigun, magic is the penis magic circle
[22.02. 18:35] Varis OP: Idk just rare items
[22.02. 18:35] Nauris: Like the minimap is funky idea
[22.02. 18:35] Nauris: Also follower making
[22.02. 18:36] Nauris: Yeye
[22.02. 18:36] Nauris: So you can't get full set bonus, but it kinda needs to equalize, that you can't get the full set
[22.02. 18:37] Nauris: Beer could be power and luck increase item, but I already have "infinity" stacking
[22.02. 18:37] Nauris: But an item, which does both, could be interesting
[22.02. 18:47] Varis OP: Straight up Beka, the item
[22.02. 19:40] Nauris: Hm, maybe I should actually make a hand item slot
[22.02. 19:40] Nauris: Then I can be able to put all the whacky items too maybe
[22.02. 23:25] Varis OP: Sure
```

The Latvian opening suggests a Missing Pālis item with a mild wavy screen effect on pickup and explicitly says stacking should not become so strong that the player cannot see. This supplies a readability constraint, not approval for unlimited full-screen distortion.

### Later user context and explicit prototype choices

The user clarified that Beka was Varis's recently deceased cat and that including her would be a wholesome memorial. The user described her as talkative, fond of sleeping in bed and climbing, chill/non-aggressive, timid, rescued when small, and fond of eating junk, with associated health problems/operations.

The user then insisted that she still needs actual game mechanics and numbers. The assistant proposed the shield and pickup pulse; while revising this handoff, the user explicitly answered:

> Use shield and pickup pulse as a prototype

After the repository check found direct Follower rewards rather than currency drops, the user explicitly approved the adaptation:

> Yes—pull health, highlight equipment

Those two answers authorize the Beka prototype in section 14. Other suggested item mechanics and additional Beka tuning details remain identified there as proposals/defaults rather than historical user decisions.

**End of revised full development handoff.**
