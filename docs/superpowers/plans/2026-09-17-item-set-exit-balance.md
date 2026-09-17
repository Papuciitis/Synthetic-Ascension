# Item, Set, Economy and Exit Balance Implementation Plan

> For agentic workers: Use superpowers:executing-plans, if installed, to implement this plan task by task. Otherwise follow the same test, implement, verify, commit sequence directly. No plugin installation is required. The user's request takes precedence over a skill's approval ceremony; do not reopen approval of the idea. The present deliverable is a plan for Claude, not an implementation.

**Goal:** Make earned equipment upgrades materially improve damage and survival, preserve the three sets' identities, and make exiting a readable sniper encounter with occasional melee pressure.

**Architecture:** Give item stats, accessory effects and set effects separate, continuous scaling profiles. Retain the existing item identities, polarity, inventory, combat and telemetry systems. Add one exit-encounter controller to coordinate proximity, spawn budgets and recovery through existing systems.

**Tech stack:** Godot 4.7.x, GDScript, authored resources, existing scene-based headless test suites.

**Spec:** Sections 1-10 of this file are the design specification. Sections 11-13 are the implementation and validation plan. The sibling `.gd` contains this entire handoff as comments and is not a gameplay script to attach or autoload.

**Baseline inspected:** `4e79a2bbd916`, branch `feat/authoritative-enemy-world`, game version `0.0.0.25.5`. Recheck HEAD and local changes before implementing; adapt paths if subsequent work moved them.

## Global constraints

- Ascension tree redesign is explicitly deferred. Preserve nodes, connections, acquisition rules, ability coefficients and player choices. Instrument existing abilities when necessary, without redesigning them.
- All numbers labelled V1 below are proposed playtest values, not externally proven balance and not results of a new game simulation.
- No live difficulty scaling against the player's current HP, DPS, equipped rarity or selected build. Strong upgrades must visibly make the player stronger.
- Preserve item IDs, polarity, roll quality, rank, fractional upgrade progress, Manifestations and locks. Preserve all save slots and unrelated working-tree changes.
- No new currency, item slots, rarity ceiling, skill tree or external dependency.
- Keep simulation time and wall time distinct. Tests must account for pauses, slow motion, travel, hub visits and resurrection.
- Follow README.md: do not run Godot, even headless, during a human playtest. Check running Godot processes before invoking it; prepare work and report the constraint if a playtest prevents testing. Do not stop a player's game.
- Use a `codex/` branch if a new branch is needed. Make local commits after each verified stage; do not push automatically.
- Existing untracked `tools/tests/BalanceRecorderLoadTest.gd.uid` predates this plan; do not claim, delete or include it accidentally.

## 1. Evidence and scope

### Player intent

The player reported a roughly two-hour earlier run using god mode: damage stopped keeping up, ultimates stopped clearing grunts, and an R15 HP item gave only about +50 HP versus +10 at R1. That earlier run was not recorded. The recorded run deliberately began at segment 5 to investigate that difficulty and was a legitimate attempt to finish, not intentional overtime farming.

Near the unlocked exit, normal melee reinforcements should stop. Existing enemies may still need clearing. A larger sniper presence should create aimed shots to dodge; occasional small melee arrivals keep the player moving. Dodging outside the channel circle must not resume the ordinary horde.

### Capture evidence

Source folder: `balance_captures/2026-09-17/2026-09-17_07-18-08_31368_289361846_1/`.

- 9,991 consecutive records, zero dropped records, zero writer failures, reconciled wallet. One observed session, not a complete early-to-late run.
- Gameplay seconds / deaths: segment 5 = 423.53 / 2; segment 6 = 390.01 / 2; segment 7 = 528.01 / 9. All 13 deaths occurred in collapse.
- Segment 7's first sampled live exit-channel attempt was 230.62 gameplay seconds into the segment, about 57.13 seconds after collapse began. HP was full at 213.08; enemy HP multiplier was 8.80 and damage multiplier 16.71. Death followed about 4.65 gameplay seconds later.
- Four later segment-7 lives lasted roughly 4-6 seconds after respawning. Segment 7 reconstruction charges were 5,584 versus 5,365 combat income.
- Spitters caused about 53% of recorded HP loss; contact swarm about 22%; unknown sources about 11%. These are exposure-weighted contributions, not proof that any individual attack is overtuned.
- Healing applied 3,580.65, overflow 6,994.14. Do not infer a healing nerf from overflow alone: healing at full HP and lethal bursts can coexist.
- Dev mode was enabled and the starting equipment was prepared. Recorded god mode was false, enemy debug HP scale was 1, and no developer currency grants occurred. This does not establish natural item acquisition pace.

### Confirmed code findings

1. `RarityMath.potency(r) = 1 + 0.45*sqrt(r) + 0.05*r`; raw stat additions use potency minus one. This is square-root-plus-linear, not logarithmic.
2. Conduit Heart gives +10 at R1 and +49.86 at R15. Lattice Pulsecoil gives +9 -> +12.99; Gravemarch Vessel +15.50 -> +21.48.
3. Rate-stat additions clamp at 2.25 potency-minus-one, approximately R13. Crusher's positive-roll effect caps even earlier. Expensive later upgrades can stop changing the item's own movement benefits.
4. Oakheart R1, neutral roll, grants 47.5 armour plus 12% separate reduction: about 40.34% combined mitigation before other defences. Armour-slot items are on a radically smaller scale.
5. Set flat bonuses do not grow with rarity. Set effect strength uses average integer rank, ignoring banked upgrade progress.
6. Set damage, hit count, radius and sometimes trigger frequency already scale together. Replacing the shared potency formula globally would multiply several growth channels at once.
7. Weaker duplicate merge value halves every 1.5 ranks. A six-rank gap has a 1/16 multiplier before quality. The rarity-only price term grows from 46.5 at R1 to 858.5 at R15; those are not final shop prices.
8. Ordinary spawning already stops during active channeling and a three-sniper formation exists. The gap is proximity/latching: stepping outside the circle restores ordinary spawning, while existing nearby enemies remain.

## 2. Research basis and how it is used

Sources were read on 2026-09-17. They inform principles; none supplies the numeric values proposed for this game.

- Ian Schreiber, **Transitive Mechanics and Cost Curves**: evaluate benefits alongside currency cost, opportunity cost and drawbacks. Application: compare complete item packages and time to acquire, including curse penalties and lost set membership. https://gamebalanceconcepts.wordpress.com/2010/07/21/level-3-transitive-mechanics-and-cost-curves/
- Ian Schreiber, **Advancement, Progression and Pacing**: use playtest power curves and feedback loops to study how progression unfolds. Application: measure damage, effective health, acquisition time and failure phase separately; investigate the death/cost/escalation loop. https://gamebalanceconcepts.wordpress.com/2010/08/18/level-7-advancement-progression-and-pacing/
- Blizzard, **Master your Power in Season of Blood**, historical developer explanation: multiplicative damage combinations can make certain investments mandatory; monster tuning must accompany changes to player power. Application: keep additive Power and separate, controlled proc scaling; validate enemy matchups after changes. This is not a claim about today's Diablo rules. https://news.blizzard.com/en-us/article/24014289/master-your-power-in-season-of-blood
- Michael Booth / Valve, **The AI Systems of Left 4 Dead**, slides 80-81 and 91: population pacing includes relief and allows existing engagements to finish; pacing and difficulty are distinct controls. Application: replace the exit's reinforcement mix and provide recovery windows instead of relying on escalating stat multipliers. https://cdn.akamai.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
- Factorio developers, **Friday Facts #161**: diminishing-return infinite research is an optional late-game resource sink. Application: optional endless progression can taper, but required mid-run upgrades need useful returns. https://www.factorio.com/blog/post/fff-161

## 3. Item stat scaling: V1 specification

### 3.1 Common rules

Use effective rank `r = max(0, rarity) + clamp(upgrade_meter, 0, 0.999999)` everywhere item growth is intended. Stored rank/meter normalization remains the merge system's responsibility.

Use explicit anchor profiles for HP, armour, Power and Luck, interpolated linearly at ranks 0, 1, 6, 15 and 30. Above R30 continue the R15-to-R30 slope; do not cap the rank or grow exponentially. A new rank never reduces the same item's positive stat package at a fixed roll.

The table values below are TOTAL flat contributions from that item, not additions on top of the existing `mods + rarity_base` calculation. Apply the existing random roll once afterward, in the existing stat pipeline. Power/Haste/Luck numbers use StatDelta decimals: `1.00 Power` means +100 percentage points of additive Power, not a separate x2 multiplier.

Existing curse penalties, race modifiers and augment interactions still apply in their current order. No extra rarity multiplier goes on the final character stats. This avoids scaling a contribution twice.

Create `core/systems/items/ItemScaling.gd` for profile evaluation and `data/items/item_scaling_v2.json` for the explicit ID-keyed profiles. Include every runtime-enabled item; exclude `item_test`. Validate unknown IDs loudly in development and fall back to the existing formula for external/legacy items rather than returning empty stats.

### 3.2 Core stat profiles

| Item ID | Stat | R0 | R1 | R6 | R15 | R30 |
|---|---|---:|---:|---:|---:|---:|
| conduit_heart | max_hp | 0 | 10 | 70 | 180 | 380 |
| lattice_pulsecoil | max_hp | 8 | 9 | 55 | 150 | 310 |
| gravemarch_vessel | max_hp | 14 | 15.5 | 85 | 230 | 490 |
| conduit_plating | armor | 0 | 1 | 14 | 35 | 70 |
| lattice_shellplate | armor | 1 | 1.125 | 10 | 26 | 52 |
| gravemarch_carapace | armor | 1.5 | 1.675 | 18 | 46 | 92 |
| conduit_lens | power | 0 | 0.01 | 0.35 | 1.00 | 2.20 |
| lattice_focusnode | power | 0.03 | 0.035 | 0.30 | 0.90 | 2.00 |
| gravemarch_censer | power | 0.04 | 0.0475 | 0.38 | 1.10 | 2.40 |
| conduit_charm | luck | 0 | 0.005 | 0.08 | 0.20 | 0.40 |
| lattice_fingerprint | luck | 0.02 | 0.025 | 0.10 | 0.24 | 0.48 |
| gravemarch_bonekey | luck | 0.015 | 0.020 | 0.07 | 0.18 | 0.36 |

These anchors deliberately protect most R0/R1 behaviour and accelerate growth through the problem region. They are not a promise that R15 is naturally reachable by any particular segment.

### 3.3 Movement and Haste

Replace abrupt rarity caps with smooth growth. Between R0 and R1 interpolate the two endpoints. For r >= 1:

`value(r) = at_R1 + (limit - at_R1) * (1 - exp(-(r - 1) / tau))`

The limit is an asymptote, not a hard breakpoint. To keep high-rank investment useful after rate gains become small, all nine core movement/haste/luck items also gain secondary HP with anchors `[0, 0, 8, 24, 60]` at `[0, 1, 6, 15, 30]`. That secondary HP is included once in the item's flat stat result and displayed in the tooltip.

| Item ID | Stat | R0 | R1 | Limit | Tau |
|---|---|---:|---:|---:|---:|
| conduit_greaves | move_speed | 0 | 5 | 45 | 12 |
| lattice_strideframe | move_speed | 8 | 9 | 34 | 12 |
| gravemarch_stompers | move_speed | -4 | -3.5 | 12 | 12 |
| conduit_actuators | haste | 0 | 0.01 | 0.45 | 14 |
| lattice_tickspurs | haste | 0.02 | 0.025 | 0.32 | 14 |
| gravemarch_clockjaw | haste | -0.01 | -0.0075 | 0.24 | 14 |

Gravemarch's set-wide movement drawback remains; its boots and attack-speed item eventually overcome their own initial drawbacks. Keep LuckResolver's probability limits in V1. Evaluate the actual chance changes in tooltips; +20% Luck is not +20% critical chance. Its secondary HP prevents the slot's entire upgrade value relying on already-saturated chances.

### 3.4 Accessories

| Item ID | Flat stat | R0 | R1 | R6 | R15 | R30 |
|---|---|---:|---:|---:|---:|---:|
| acc_oakheart | max_hp | 10 | 12 | 30 | 70 | 140 |
| acc_oakheart | armor | 6 | 8 | 12 | 20 | 32 |
| ring_regeneration | max_hp | 10 | 12.5 | 24 | 55 | 110 |
| acc_firestone | power | 0.02 | 0.025 | 0.08 | 0.20 | 0.42 |
| ring_crusher | max_hp | 0 | 0 | 12 | 36 | 85 |

- **Oakheart:** keep -10 flat movement. Replace its old rarity multiplier for shield reduction with `E(r) = 1 + 0.4*(1-exp(-max(0,r-1)/12))`; at R0 use E=1. Separate reduction is `(0.04 + max(roll,0)*0.10)*E`, clamped to 0..0.15. Use the existing roll clamp. This deliberate early nerf removes the shield's dominance while armour-slot growth rises. Assess full EHP, not just armour values.
- **Regeneration Ring:** retain the 1-second tick, but use `mean_heal = (1.5 + 0.015*max_hp)*A(r)*max(0.10,1+roll)`. A has anchors `[0.9,1.0,1.2,1.5,1.9]` at `[0,1,6,15,30]`; above R30 use `1.9 + 0.2*(1-exp(-(r-30)/20))`. Preserve randomness with a uniform 0.4..1.6 multiplier, whose mean is 1. Hard-limit a tick to 5% max HP to avoid extreme-roll regeneration; test low-HP curse builds separately. `mean_heal` is the mean before this limit and overheal; report actual applied healing separately. Never heal a dead player. Label healing as `item:ring_regeneration` in telemetry.
- **Crusher's Ring:** movement uses the smooth rate formula with R0=35, R1=39, limit=70, tau=12. For positive rolls use `roll * (1.5 + 0.5*(1-exp(-max(0,r-1)/12)))`; at R0 use the original roll without amplification. Interpolate that amplification from 1 to 1.5 over R0..R1. Negative rolls retain their current treatment. The extra HP above supplies later upgrade value.
- **Firestone:** retain +0.01 flat Haste. Use accessory-effect anchors B=`[2/3,1,1.2,1.5,1.8]` at ranks `[0,1,6,15,30]`, with a tail approaching 2.0 as `1.8 + 0.2*(1-exp(-(r-30)/20))`. Burn per tick is `0.045*B*(1+max(roll,0)*0.60)` times the originating attack's damage. Keep burn interval, duration and stack rules. Magic-only additional Power becomes `(0.06 + 0.525*clamp(roll,-0.25,0.5))*B`; other styles do not gain this bonus. Magic-only Haste is 0.02 at R0, 0.03 at R1, then smoothly approaches 0.05 with tau=12. Do not multiply burn by Power a second time; its attack damage already includes Power.

### 3.5 All eight curses

Preserve current polarity, authored roll ranges, negative-effect behaviour and destination Manifestation rules. Profiles below are positive flat contributions BEFORE the curse penalty, not final benefits. Existing default merges continue choosing the milder negative roll unless the existing build rule explicitly inverts that behaviour.

| Item ID | Stat | R0 | R1 | R6 | R15 | R30 |
|---|---|---:|---:|---:|---:|---:|
| curse_starving_crown | max_hp | 55 | 61 | 105 | 220 | 450 |
| curse_slow_heart | max_hp | 40 | 44.5 | 95 | 205 | 430 |
| curse_ashen_ballast | armor | 34 | 37.5 | 48 | 80 | 140 |
| curse_tithe_bones | armor | 26 | 29 | 40 | 68 | 118 |
| curse_hollow_reliquary | power | 0.22 | 0.245 | 0.50 | 1.25 | 2.80 |
| curse_jinxed_coin | luck | 0.30 | 0.33 | 0.50 | 0.90 | 1.60 |
| curse_sour_providence | luck | 0.22 | 0.245 | 0.40 | 0.80 | 1.40 |

Leadfoot Vigil (`curse_leadfoot_vigil`) uses movement R0=30, R1=33, limit=65, tau=12. Leadfoot, Jinxed Coin and Sour Providence receive the same secondary HP anchors `[0,0,8,24,60]` as the core utility items.

Do not raise curse penalties to cancel these gains. Test each curse at mild, midpoint and deepest authored rolls, both alone and with its existing intended build support. Deeply cursed gear may be a poor generic choice; mild curses must not become universally superior to all set pieces. Remember that a curse can lose set membership and can reduce the WHOLE HP/armour/movement pool.

## 4. Set bonus scaling: V1 specification

### 4.1 Continuous rank and separate growth channels

Average `rarity + upgrade_meter` over equipped members of that set in slots 0..5. Accessories never count. Do not round the average. Keep the 2/4/6-piece activation thresholds.

Create `core/systems/items/SetScaling.gd` with `profile(mean_rank: float) -> Dictionary`. Return these exact keys:

- `stat`: anchors `[1,1,1.5,2.5,4]` at `[0,1,6,15,30]`, extending the final slope after 30.
- `damage`: anchors `[1,1.5,2.025,2.85,4.20]` at those ranks, extending the final slope. These replace the old set-strength damage factor; do NOT multiply by legacy potency as well.
- `rate`: 1 at R0..R1, then `1 + 0.5*(1-exp(-(r-1)/12))`.
- `control`: evaluate the OLD potency at `min(r,15)`. This intentionally bounds radius, knockback and stun growth while damage continues growing.
- `density`: evaluate the OLD potency at `min(r,15)`. Preserve the existing projectile/hit-count formulas and their existing caps using this factor, instead of the new damage factor.
- `frequency`: evaluate the OLD potency at `min(r,15)`. Use only for existing rarity-based trigger thresholds; retain minimum cooldowns and action locks.

Why the damage factor is conservative: the newly stronger Power items already increase set damage through `power_mul`. Raising that and every set multiplier aggressively together would compound the increase. The acceptance tests below judge TOTAL output, not whether each individual multiplier is larger than before.

Migrate every effect's `set_strength` use to the correct named channel. `SetEffectBase` stores `set_scaling: Dictionary` from this profile; retain setup signatures while callers migrate. No damage path should use both `set_strength` and `set_scaling.damage`.

### 4.2 Conduit

- 2 pieces: movement `15*rate`, Haste `0.06*rate`.
- 4 pieces: existing two-target arcs. Damage uses `damage`; radius uses `control`. Haste continues to affect cooldown; do not add another rank-based cooldown divisor.
- 6 pieces: preserve kill-triggered priming and style-specific discharge. All discharge and Circuit Feedback damage use `damage`; physical area/knockback/stun use `control`.
- Overclock duration stays 2.5 seconds. Its movement and Haste multipliers become `1 + 0.18*rate` and `1 + 0.22*rate`. Refresh duration normally; do not stack another multiplier on each kill.

### 4.3 Lattice

- 2 pieces: movement `10*rate`, Power `0.03*stat`.
- 4 pieces: Haste `0.02*rate`, Afterstrike damage uses `damage`, radius uses `control`; existing cooldown and minimum remain.
- 6 pieces: Haste `0.04*rate`, Luck `0.02*stat`.
- Triangles retain their existing mark requirements and active mirroring. Damage uses `damage`; projectile and edge-hit counts use `density` with the current hard count limits (ranged 4..7 per node, magic 2..4 per edge).
- Do not grow mirror count, mark creation rate, damage and projectile count through the same new multiplier. Geometry remains recognisable and the projectile budget bounded.

### 4.4 Gravemarch

- 2 pieces: HP `18*stat`, armour `2*stat`, fixed movement drawback -6.
- 4 pieces: Power `0.02*stat`; Sunderstep damage uses `damage`, control values use `control`; existing cooldown rules remain.
- 6 pieces: armour `1.5*stat`. Mass Arrest damage uses `damage`; additional shards/aftershocks use `density`; bank threshold uses `max(60,200/pow(frequency,0.75))`.
- Keep the active requirement at 60% of the threshold. Preserve its action lock and existing cooldown. Extra set damage must not recursively bank itself into unlimited instant procs; test the existing event source/lock semantics before deciding a change is needed.

### 4.5 Manifestations

Keep the existing rule-potency cap of 1.60 and threshold floor of 0.78 in this pass. Host item HP/Power growth and attack-derived damage already strengthen many of these effects. Audit damage inheritance, maximum simultaneous objects and trigger recursion with the new profiles. Do not raise global Manifestation caps to make a cosmetic rarity number feel better.

## 5. Merge effort and economy

### 5.1 Merge value

V1: change `GAP_HALF_LIFE` from 1.5 to 3.0. Continue using the SAME constant for incoming mass and overflow conversion:

`mass = quality * pow(2, (incoming_rank - destination_rank) / 3)`

`overflow_factor = pow(2, -1.0/3)`

At equal quality, a six-rank gap contributes 0.25 of a peer instead of 0.0625. Equal-rank material still gives its quality-scaled progress. Keep existing quality range, higher-rank swapping, fractional material transfer, matching-ID/polarity requirements and lock protection. Retain numerical overflow guards. Do not fabricate low-rank pickups at destination rank.

### 5.2 Prices

Replace the rarity-only price component with `base(r)=26+14*r+r*r`, evaluated at integer rank. Fractional price progress is exactly `lerp(base(r),base(r+1),meter)`; use one helper for both endpoints. This also removes the current mismatch where the next-rank base starts at 10 while the current one starts at 26.

Retain quality factor `0.90 + 0.50*clamp(abs(roll),0,1)`, set premium 1.15, authored scripted-value weights, Luck buy/sell multipliers and 55% base sell spread. V1 stat-value weights: HP=0.30, armour=0.80, movement=0.35, Power=60, Haste=50, Luck=35; multiply weights by absolute flat stat values in their stored units. This is a starting price model, not a full utility estimate for curses.

Run buy/merge/sell and undo round-trip tests before accepting this economy. Test R0..R30, quality extrema, positive and negative polarity, fractional meters and the maximum discounts. A newly purchased set of inputs must not sell for more than its total purchase cost, including through repeated merges. If violated, adjust the price/spread consistently; do not hide the exploit with an arbitrary transaction ban.

### 5.3 Acquisition targets

- During segments 5-10, aim for one visible rank increase somewhere in the equipped build every 45-90 seconds of active play, with partial gains more frequently. This is a proposed cohort target, not an individual guarantee.
- Track the selected item ID's drop frequency and drop-rank gap. Do not increase drop quantity before establishing whether weak duplicate value or insufficient compatible drops is the bottleneck.
- A useful shop upgrade should typically cost roughly 30-90 seconds of the corresponding stage's organic earnings. Exclude debug grants and do not count selling stock as recurring combat income.
- Keep current reconstruction pricing for the first item-only comparisons. Its nine-death escalation is not enough evidence to change it before fixing recovery. Revisit only if legitimate exits still require repeated paid deaths.

## 6. Exit encounter and pressure

### 6.1 State model

Create `core/systems/world/ExitEncounterController.gd`, owned by the current exit/segment rather than a persistent global singleton. Expose `update_state(eligible: bool, distance_px: float, alive: bool, delta: float) -> void`, `set_channeling(active: bool) -> void`, `begin_recovery() -> void`, `complete() -> void`, `is_active() -> bool` and signal `state_changed(state: StringName)`. The rite supplies `eligible = unlocked and revealed`, real channel membership, and gameplay delta. Completed is terminal until scene cleanup; recovery protection takes precedence over approach/channel transitions until its timer expires.

States: inactive, approach, channel, recovery, completed. Actual channel progress remains owned by ExitRite; proximity must not fill the channel.

V1 entry radius=1200 px from the unlocked, revealed rite. Release radius=1800 px, requiring 8 continuous seconds outside it while alive. Channel-circle exits and ordinary dodges keep the encounter active. Recovery keeps it active for at least 10 seconds. Completion and scene exit release all state exactly once. No overlapping controllers should compete for the global spawner.

### 6.2 Spawn rules

- While active, suspend all ordinary ambient reinforcement paths, including timer spawns, bursts, queued/authored ambient waves and world-source bursts. Recheck the state immediately before delayed spawns execute. Keep normal spawning elsewhere in a later multi-area implementation only if it cannot refill this fight; this single-player V1 uses the existing global ambient gate.
- Existing visible enemies are not deleted. Existing offscreen, non-protected enemies may retire through the current culling rules. Do not delete bosses, objective actors or drop-entitled splitter heirs. The approach radius gives the player space to thin the crowd before channeling.
- Start with 3 snipers; allow up to 4 living or pending snipers for this exit encounter. Count existing nearby snipers, authored members, pending spawns and proxy/full representations once by stable enemy handle. The exit cap is distinct from ordinary sniper limits.
- Each sniper has at least a 1.2-second visible aim warning. Resolve exit sniper shots at least 0.65 seconds apart through one encounter firing schedule; a denied shot remains telegraphed/retries rather than firing a queued burst. Verify that the player can dodge without leaving the wider exit area.
- Occasional melee reinforcement: at most 2 living/pending authored melee, one small arrival every 10-14 seconds, first arrival no earlier than 4 seconds after activation. A charger counts as a full arrival by itself. Do not immediately refill a killed group.
- Re-entering the area does not resend the initial formations, reset reinforcement timers or duplicate active beat IDs. Existing seven-second specialist replenishment and rite burst requests must go through the same budget rather than each becoming a separate source of pressure.
- New exit-authored reinforcements have no repeatable item/currency drops; still emit ordinary combat/kill hooks so builds function. Preserve rewards on pre-existing ordinary enemies. Tag the distinction explicitly and test that this creates no repeatable farming loop.

### 6.3 Overtime

V1 outside-exit overtime keeps the same shape and caps but reduces the kill coefficient from 0.035 to 0.004 and gives the TIME component a 60-second travel grace:

`overtime = max(0,unseal_time-60)*0.008 + max(0,kills_since_unseal-55)*0.004*dominance_mul`

Exclude exit-authored reinforcement kills from the overtime kill counter. Continue recording them as kills. For an active exit, clamp the overtime ADDITIONS to HP at 2.0 and damage at 1.5 before adding normal segment/heat terms. Do not confuse these additions with final multipliers. Stop stacking the old channel-only spawn multiplier and elite bonus on top of the new authored formation budgets.

This is a provisional anti-runaway adjustment, not a blanket promise of safety. Existing enemies keep their spawned HP; do not refill or resize live HP bars at the boundary. Existing projectiles retain their launch damage. New enemy and projectile scaling must use the declared encounter profile; contact damage must follow the same pressure policy. Test transitions explicitly so the fields shown in telemetry reflect the multipliers actually used.

Do not use observed player HP/DPS to set these caps. Retain enemy archetype differences and elite modifiers. If V1 trivialises ordinary fights, adjust this pressure stage separately from the item stage using the matched test matrix.

### 6.4 Reconstruction

- During an active exit, register a temporary safe recovery anchor near its perimeter, 800-1200 px from the rite, outside the channel. Validate navigation, collisions, enemy proximity and map streaming before using it. Fall back to the existing checkpoint if no safe point exists; do not teleport inside a wall or directly complete the rite.
- Give up to 5 seconds of invulnerability/phasing and block new local reinforcements for those 5 seconds. Offensive actions may end invulnerability after a minimum 2 seconds; phasing remains for the full 5 seconds. No overlapping grace stacking from repeated signals.
- Keep the current 60% death-progress retention. Suspend progress drain for up to 10 seconds after this exit recovery begins; resuming channeling ends that suspension. Afterwards the normal lapse rules apply. This retention must not be lost immediately during the return trip.
- Do not grant money, erase death count or reset overtime on death. Keep paid reconstruction and final failure distinguishable in telemetry.

## 7. Save compatibility, UI and data ownership

The proposed profiles replace derived numbers, not earned item identity. Recompute rolled_mods for equipped, bagged and stashed instances on load from ID/rank/meter, without feeding or rerolling them. Audit resource sharing so recomputing an instance cannot mutate its ItemData or another save slot.

Introduce an explicit item-balance revision of 2 in capture metadata when the new item profiles become active. Instrumentation-only baseline captures remain revision 1. Also record the enabled tuning stages and profile hash so item-only, item-plus-set and full changes cannot be mistaken for the same balance state. If a persisted field's interpretation changes, bump SaveData.CURRENT_SAVE_VERSION from the version found at implementation time and implement a one-time migration. Preserve old rank and fractional progress exactly; apply the new merge law only to future combinations. Test repeated load/save/load for idempotence and preserve future-version handling. Do not overwrite raw capture history.

Use the same evaluators in runtime stats, item tooltips, set descriptions, comparison previews and shop pricing. Show current contribution and the next rank's change, plus relevant capped/saturated effect information. Do not describe +Power as an independent damage multiplier or +Luck as an equal crit chance.

Keep user-facing text about benefits, requirements and tradeoffs; internal profile names and schema versions belong only in developer views.

## 8. Recorder additions needed to judge the result

Extend the existing recorder rather than adding another logger. Preserve its bounded buffering and asynchronous writer; aggregate frequent events into windows.

- `balance_revision` and a stable tuning/profile hash in capture metadata; record debug settings and capture coverage as today.
- Item upgrade events: item ID, slot, old/new rank and meter, roll/polarity, source and source rank, before/after stat contributions, time since previous upgrade. Add actual merge material/value and shop prices where available; never imply dropped items were acquired if only seen.
- Set snapshot: mean effective rank, active tiers and each named scaling channel.
- Exit events: activation, entry/leave distance, channel progress, hold required, lapse/drain reason, progress lost on death, recovery anchor, alive/pending counts by melee/ranged, spawn request accepted/rejected and reason.
- Death context: actual terminal hit source, raw/adjusted/applied damage, pre-hit/max HP, pressure, active effects, elapsed time since respawn. One-second samples cannot reconstruct the exact lethal hit on their own.
- Separate enemy damage by ability/item/set root where a stable tag already exists. Report attributed and unattributed shares explicitly; never assign the old direct-player credit gap to sets by assumption.
- Report healing by source, requested/applied/overflow, and non-hit HP adjustments. Slow Heart currently takes back HP after a heal and later releases it; record the takeback as an adjustment so applied healing is not mistaken for net retained healing. Preserve behaviour in this instrumentation stage.
- Compare exposure-normalised enemy damage where available: attacks launched, resolved hits, time exposed and HP lost. The current spitter share alone is not a reason for an immediate nerf.
- Report exit completion rate, travel time to first attempt, deaths within 10 seconds of reconstruction, and reconstruction spend as a share of organic earnings. Separate completed, failed and unfinished attempts.

## 9. Explicit interfaces for the implementation

These are NEW proposed helpers, not claims that these APIs already exist:

```gdscript
# core/systems/items/ItemScaling.gd (class_name ItemScaling)
static func effective_rank(item: ItemInstance) -> float
static func sample_anchors(rank: float, points: Array[Vector2]) -> float
static func sample_rate(rank: float, r0: float, r1: float, limit: float, tau: float) -> float
static func flat_mods(item: ItemInstance) -> StatDelta
static func accessory_factor(item_id: String, rank: float) -> float

# core/systems/items/SetScaling.gd (class_name SetScaling)
static func profile(mean_rank: float) -> Dictionary

# Existing Inventory method: retain its name but include fractional progress.
func get_set_rarity_average(set_id: StringName) -> float

# New helper in autoload/global.gd; price endpoints both call it.
func item_rank_value(rank: int) -> float
```

`sample_anchors` requires strictly increasing, finite rank coordinates, clamps below the first anchor to its value, interpolates within intervals and extrapolates the final segment above the last anchor. Rate tau must be positive. Validate profiles at load and fail developer tests on malformed data; do not silently clamp a corrupt profile into plausible balance.

Reference formula for interpolation (the implementation should use the project's normal error/reporting conventions):

```gdscript
static func sample_anchors(rank: float, points: Array[Vector2]) -> float:
    assert(points.size() >= 2)
    var r := maxf(0.0, rank)
    if r <= points[0].x:
        return points[0].y
    for i in range(1, points.size()):
        if r <= points[i].x:
            var left := points[i - 1]
            var right := points[i]
            return lerpf(left.y, right.y, (r - left.x) / (right.x - left.x))
    var tail_left := points[points.size() - 2]
    var tail_right := points[points.size() - 1]
    return tail_right.y + (r - tail_right.x) * (tail_right.y - tail_left.y) / (tail_right.x - tail_left.x)
```

Do not paste these declarations as unimplemented stubs into gameplay. They specify the implementation boundary; complete and test a stage before committing it.

## 10. Acceptance targets and comparison method

### Measured quantities

- Effective health against a named ordinary attack: `HP * (1 + max(armor,0)/100) / product(other_damage_taken_multipliers)`, assuming that attack uses the current armour rule. Report evasion, temporary invulnerability and healing separately; they are not constant EHP.
- Single-target primary attacks-to-kill and TTK: measure actual hits against fresh, standard targets. Do not use whole-session damage/gameplay seconds as single-target DPS.
- Sustained and burst set output: same gear, rolls, style and targets with set effects enabled versus disabled. Keep item stats fixed when isolating set effects.
- Acquisition: gameplay time and organic earnings to each rank, compatible drops, merge gap and effective progress per material item.

### V1 playtest targets

At the expected gear quality actually observed for a segment, ordinary non-elite grunts should generally take 1-4 connected primary attacks, and ordinary hits should generally allow 4-8 hits from full health before healing. Treat these as windows for baseline builds, not invariants across glass-cannon, tank or deliberately cursed builds. Sniper hits should be clearly telegraphed and generally cost 20-35% of the baseline build's HP after mitigation rather than instantly killing a full-health baseline player.

For a real full damaging ultimate cast, record total damage, per-target damage and grunt kills. Its intended primary target should normally die if it is a standard grunt at the corresponding stage; do not assume every individual fan pellet is a whole ultimate. If the existing Ascension ability misses this target, record it for the separately deferred tree/ability pass instead of quietly changing its nodes here.

With an unchanged loadout except upgrading the relevant HP or Power item from R6 to R15, aim for at least +25% baseline EHP or primary-hit damage respectively. Compare R1/R6/R15/R30 across all three sets and accessories. Rank +1 and fractional upgrades should never reduce the same fixed-roll contribution; rate slots can deliver later value through secondary HP.

A complete set's passive effects should initially target roughly +60-120% sustained output over the same gear with those effects disabled, in a controlled mixed pack; active bursts are reported separately. This is a broad tuning band, not a guarantee that every encounter benefits equally. Preserve mobility/control differences and evaluate Gravemarch's defensive value too. No set should dominate matched offence AND defence AND mobility across every tested style.

For legitimate exits, target 70-90% completion within two attempts for the familiar tester using an adequate baseline build, with fewer than 10% of paid reconstructions followed by death within 10 seconds. Start with at least 10 attempts per primary comparison; report counts and wide uncertainty rather than treating a small sample as a population estimate. Validate with additional players later.

### Test matrix

- Stage fixtures: segments 1, 5, 7, 10, 15 crossed with R1, R6, R15, R30. These are laboratory fixtures, not assumed natural rank-to-segment mappings.
- Main reproduction: capture seed `1787280239369`, ranged elf, R6 Conduit plus its recorded accessories, starting segment 5. Also use fixed seeds `104729`, `130363`, `155921`, `196613`. Recreate the captured initial build exactly, including recorded rolls that may exceed normal authored ranges; label it a prepared regression fixture.
- Separate natural runs begin at segment 1 and track earned equipment. Do not draw acquisition conclusions from the prepared fixture.
- Neutral and fixed representative positive rolls; mild/mid/deep curse rolls; full sets and mixed equipment; each weapon style; without changing Ascension choices between an A/B pair.
- Capture one item-only stage, then items+sets, then full exit/pressure stage. Do not compare all changes at once and claim which one caused the improvement.
- Performance: compare the same fixed-density pack and set effects before/after. Projectile counts remain within authored limits; no unbounded proc recursion, new per-hit disk writes or new steady-state allocation spikes. Record frame-time distributions, not just one sample callback maximum.

## 11. Implementation tasks and local commit boundaries

The existing tests use scene runners and `_check(condition, message)`. New suites should follow that convention and have matching `.gd` / `.tscn` files, not introduce a testing framework. Use the actual available Godot 4.7.x executable. On Windows the command shape is `& $godotPath --headless --path . 'res://tools/tests/Name.tscn' --quit-after 3000`; resolve `$godotPath` from the local setup rather than copying the Linux path in README.

### Task 1: Baseline probe and recorder context

**Modify:** `autoload/BalanceRecorder.gd`, `core/systems/telemetry/BalanceLedger.gd`, existing telemetry event/report code after locating its current writer; `effects/items/logic/RegenerationRingEffect.gd`, `effects/items/logic/curses/SlowHeartCurse.gd` for source/adjustment reporting only.

**Create:** `tools/tests/ItemBalanceProbe.gd` and `.tscn`; deterministic fixtures under `tools/tests/fixtures/item_balance/`; `tools/tests/BalanceRevisionTest.gd` and `.tscn`.

**Consumes:** current production formulas, real inventory and combat entry points. **Produces:** baseline JSON with revision, per-item contributions, primary-hit damage, EHP assumptions and set root attribution coverage; the new capture fields in section 8 where already observable.

- [ ] Add a failing test that a Regeneration Ring heal has a stable item source and that Slow Heart's takeback/release can be reconciled to observed HP changes without being counted as enemy damage.
- [ ] Add a probe fixture with known HP=200, armour=50, other damage multiplier=0.8; expected constant EHP=375. Feed an ordinary 50 raw-damage hit through the real player path and assert 26.6667 HP loss, within tolerance, with evasion and temporary effects disabled.
- [ ] Run the new tests, record the expected missing-metadata/source failure, implement instrumentation only, and rerun existing BalanceLedgerTest, BalanceRecorderTest and BalanceRecorderOutcomeTest.
- [ ] Export the baseline probe results for R0/1/6/15/30 before changing any numbers. Record missing root attribution honestly.
- [ ] Commit: `test(balance): capture item and encounter baselines`.

### Task 2: Core item curves, curse profiles and save reconstruction

**Create:** `core/systems/items/ItemScaling.gd`, `data/items/item_scaling_v2.json`, `tools/tests/ItemScalingV2Test.gd` and `.tscn`.

**Modify:** `data/items/ItemInstance.gd`, `autoload/global.gd` load paths, `autoload/SaveData.gd` only if migration is required, `data/items/BagInventory.gd` and `data/items/StashInventory.gd` load/rebuild paths where applicable; `ui/widgets/ItemTooltip.gd` and relevant comparison code.

**Consumes:** sections 3.1-3.3 and 3.5. **Produces:** ItemScaling interfaces from section 9 and derived flat stats for all items. Accessory flat profiles are included now; scripted accessory effects change in Task 3.

- [ ] Add profile fixtures for every runtime item and assert all expected stat channels exist exactly once.
- [ ] Before implementation, run tests with these explicit expectations: Conduit Heart R6=70 HP; R15=180 HP; R10.5=125 HP; Lattice Pulsecoil R15=150 HP; Gravemarch Carapace R15=46 armour. At R6.5 a Conduit Heart must exceed its R6 contribution without changing roll or Manifestation.
- [ ] Implement validated anchor and smooth-rate evaluation, route `_recompute_flat_mods` through it, and remove the obsolete per-stat cap only on migrated profiles. Leave legacy potency available for unmigrated effect channels.
- [ ] Test fractional-rank continuity at every anchor, monotonicity at fixed roll, and finite outputs at R0/1/6/15/30/50/100. Negative initial Gravemarch rate stats must improve monotonically.
- [ ] Test save/load/save idempotence across equipped/bag/stash items: same ID/rank/meter/roll/polarity/lock/Manifestation, newly derived stats, no shared-resource mutation. Preserve a saved fractional meter exactly when adopting the new balance revision.
- [ ] Run AuditClosureTest, SaveIntegrityTest, BurdenSystemTest, ItemTooltipLensTest, and the new suite. Update old numeric assertions only where the spec intentionally changes the contract.
- [ ] Commit: `feat(items): add meaningful continuous stat progression`.

### Task 3: Accessory effects and meaningful utility upgrades

**Modify:** `effects/items/logic/OakheartShieldEffect.gd`, `RegenerationRingEffect.gd`, `SpeedRingEffect.gd`, `FirestoneEffect.gd`; corresponding scene overrides if present; `tools/tests/ItemEffectRunnerTest.gd`.

**Consumes:** ItemScaling.flat_mods/accessory_factor and section 3.4. **Produces:** matching runtime and tooltip effects without reapplying stat growth.

- [ ] Write failing real-runner checks: neutral R1 Oakheart has 8 armour and 4% shield reduction; its combined multiplier with no other armour is `100/108*0.96`, not the old `100/147.5*0.88`.
- [ ] At 200 max HP, neutral R6 regeneration has mean 5.4 HP per tick before randomisation and the 10 HP tick limit. Inject a deterministic midpoint roll of 1.0 for an exact check; separately test the capped endpoints and dead-player suppression.
- [ ] Assert R15 Crusher contributes 36 secondary HP and R16 contributes more; its speed profile remains continuous. Test positive and negative roll paths separately.
- [ ] At R15 and neutral roll, Firestone burn multiplier is 0.0675 per tick. A 100-damage input attack therefore carries 6.75 damage/tick, not an additional multiplication by character Power. Exercise both pooled and node projectile paths and magic-only stat bonuses.
- [ ] Implement the effects, compare displayed values to actual hooks, run ItemEffectRunnerTest and relevant projectile/status tests.
- [ ] Commit: `feat(items): rebalance accessory effects and late utility value`.

### Task 4: Continuous set growth with independent channels

**Create:** `core/systems/items/SetScaling.gd`, `tools/tests/SetScalingV2Test.gd` and `.tscn`.

**Modify:** `data/items/Inventory.gd`, `data/sets/SetRunner.gd`, `effects/SetEffectBase.gd`; all six set scripts under `effects/conduit/scenes`, `effects/lattice/scenes`, `effects/gravemarch/scenes`; the three set resources and tooltip descriptions.

**Consumes:** effective rank, stronger item stats, section 4. **Produces:** named set_scaling channels and continuous set-tier benefits.

- [ ] Write a failing average-rank test: two members at R6 with meters 0 and 0.5 produce mean 6.25, not 6.0. Accessories must not affect this average.
- [ ] Add exact tests: at mean R15, profile.stat=2.5 and profile.damage=2.85; Gravemarch's 2-piece HP bonus is 45 and total 2+6-piece armour bonus is 8.75 before the armour-slot roll.
- [ ] Implement named channel application once per effect and per tier. Verify a fractional feed updates live effects without recreating nodes or resetting cooldowns/resources.
- [ ] Test Lattice counts stay in their existing ranges at R30/R100, Conduit overclock refresh never compounds, and Gravemarch cannot recursively trigger an unbounded bank/proc chain. Use actual event paths, not just helper arithmetic.
- [ ] Run SetRunnerTest, ManifestationSystemTest, ManifestationPairBehaviourTest and the new suite; run the controlled set-output probe for all three styles.
- [ ] Commit: `feat(sets): scale bonuses continuously with bounded proc density`.

### Task 5: Merge effort and market prices

**Modify:** `core/systems/items/RarityMath.gd`, `autoload/global.gd` item value helpers; merge tests in `tools/tests/AuditClosureTest.gd` and economy tests/probes.

**Create:** `tools/tests/ItemEconomyV2Test.gd` and `.tscn`.

**Consumes:** new item benefits; section 5. **Produces:** consistent merge-mass/overflow law and monotone fractional pricing.

- [ ] Write failing checks: quality=1, incoming R0 -> destination R6 gives mass 0.25; overflow equals `pow(2,-1.0/3)`; rank price endpoints at R6/R7 are 146 and 173, so a half-filled R6's rarity component is 159.5.
- [ ] Implement the shared half-life and one price helper; preserve matching, locks, polarity and rule retention.
- [ ] Preserve the existing equal-quality, same-rank carrier test: transferring banked meter without a carrier rank-up must match direct feeds within numerical tolerance. Extend the probe across rank crossings, mixed qualities and feed orders, reporting rank/meter and value differences. Matching the gap and overflow constants alone does not prove full associativity when a carrier ranks up or its retained quality changes; do not silently redesign progression to force that stronger claim. Any new value-creation or arbitrage regression must be resolved before acceptance. Check higher-rank auto-swap preserves the destination Manifestation.
- [ ] Enumerate the arbitrage matrix described in section 5.2, including undo and discounts; run FollowerEconomyAuditProbe and AuditClosureTest.
- [ ] Commit: `feat(economy): align merge progress and prices with upgrade value`.

### Task 6: Exit proximity and authored reinforcement budget

**Create:** `core/systems/world/ExitEncounterController.gd`, `tools/tests/ExitEncounterBudgetTest.gd` and `.tscn`.

**Modify:** `core/systems/world/ExitRite.gd`, `core/systems/spawner/spawner.gd`, `core/systems/encounters/EncounterDirector.gd`, `EncounterBeats.gd`, `core/actors/enemy/modules/EnemySniper.gd`; spawn/death context only where required for tagged rewards. Preserve the scene `scenes/world/gates/ExitRite.tscn` and its existing safeguard/pulse behaviour.

**Consumes:** section 6.1-6.2, existing authoritative enemy handles. **Produces:** stable encounter state independent of instantaneous channel membership, all spawning paths sharing one budget, and recorder events.

- [ ] Fail a boundary test: unlock at 1199 px activates; leave the 168 px channel but stay at 400 px and ambient spawning remains suppressed; 1801 px for 7.9 seconds stays active, reaching 8 seconds releases. Locked or unrevealed rites never activate.
- [ ] Fail a queued-wave test: a wave scheduled before activation must recheck state at its execution time and not add ordinary melee afterward.
- [ ] Test four alive/pending snipers block another reservation; a failed placement releases its reservation. Proxy/full promotion never changes the count. Re-entering does not duplicate the initial formation.
- [ ] Implement formation cadence and firing staggering; use injected clock/RNG in controller tests so no wall-clock sleep is required for each boundary case.
- [ ] Test existing protected enemies/rewards survive activation, exit-authored reinforcements do not farm currency, and normal combat hooks still fire.
- [ ] Run ExitRiteTest, RiteClimaxTest, RiteSafeguardIntegrationTest, enemy lifecycle/representation tests and the new budget suite.
- [ ] Commit: `feat(exit): keep sniper encounter active through approach and dodges`.

### Task 7: Pressure and reconstruction recovery

**Modify:** `autoload/ThreatDirector.gd`, `core/actors/player/player.gd`, `core/systems/world/ExitRite.gd`, the new ExitEncounterController; existing checkpoint/navigation integration after locating the current owner. Add telemetry from section 8 at the same integration boundaries.

**Create:** `tools/tests/ExitRecoveryTest.gd` and `.tscn`. Extend ThreatDirectorPressureTest and relevant damage tests.

**Consumes:** stable exit state and section 6.3-6.4. **Produces:** bounded exit overtime contributions and validated temporary recovery.

- [ ] With unseal_time=60, kills=155 and dominance=1, expected overtime is 0.4; at time=120 it is 0.88. Exit-authored kills must not advance that counter.
- [ ] Assert active-exit overtime HP/damage additions cannot exceed 2.0/1.5 while normal segment/heat terms are retained. Leaving encounter mode restores ordinary evaluation without duplicating or resetting accumulated history.
- [ ] Test death at 10 seconds of channel keeps 6 seconds; the recovery window does not drain that immediately. At 10 seconds without return, ordinary lapse resumes. A paid reconstruction never grants currency or decrements death count.
- [ ] Test valid anchor selection, blocked-anchor fallback, one-shot protection windows, scene cleanup and unchanged stored projectile damage. Verify contact/projectile telemetry agrees with their real damage calculation.
- [ ] Implement, run ThreatDirectorPressureTest, ExitRecoveryTest, ExitRiteTest and relevant player lifecycle suites discovered in the current tree.
- [ ] Commit: `fix(balance): prevent exit escalation and reconstruction death loops`.

### Task 8: Matched playtests, report and final validation

**Create/update:** results under `docs/audits/2026-09-17-item-set-exit-balance/`, `docs/current_game_data.md`, and relevant status documentation according to repository conventions.

- [ ] Run the fixture matrix and natural acquisition sessions from section 10, recording exactly which stages and revision each capture includes. Human feel/aiming results require human playtests; do not claim a headless damage probe demonstrates enjoyable dodging.
- [ ] Report each acceptance target as passed, failed or not measured, with counts and paired before/after values. Keep raw captures and a concise conclusion per subsystem.
- [ ] If calibration is needed, adjust one subsystem's profile values at a time, rerun its matched cases, and record the reason. Do not silently alter Ascension mechanics to make the item target pass.
- [ ] Run the relevant suites above plus ScriptParseAuditTest LAST after changes. Include the import step after adding scripts when the human game is not running. Inspect each suite's reported failure count, not only process exit code.
- [ ] Commit: `docs(balance): record item progression and exit validation`.

## 12. Required regression assertions: concrete examples

Use fixtures built through ItemInstance.from_roll with Manifestation rolling disabled, then set meter and recompute through the public production path added in Task 2. The following checks specify exact required behaviour; `_check` is the existing scene-test helper.

```gdscript
var points: Array[Vector2] = [Vector2(0, 0), Vector2(1, 10), Vector2(6, 70), Vector2(15, 180), Vector2(30, 380)]
_check(is_equal_approx(ItemScaling.sample_anchors(10.5, points), 125.0), "fractional HP progression")
_check(is_equal_approx(ItemScaling.sample_anchors(30, points), 380.0), "R30 HP anchor")
_check(ItemScaling.sample_anchors(31, points) > 380.0, "no post-R30 HP dead rank")
_check(ItemScaling.sample_rate(16, 0, 5, 45, 12) > ItemScaling.sample_rate(15, 0, 5, 45, 12), "boots grow after former cap")
_check(is_equal_approx(float(SetScaling.profile(15)["damage"]), 2.85), "set damage factor applied once")
_check(is_equal_approx(RarityMath.merge_mass(0, 6, 1.0), 0.25), "lower-rank material remains useful")
_check(is_equal_approx(Global.item_rank_value(6), 146.0), "one price helper")
```

Also test the real observable outcomes: fewer attacks to kill when upgrading Power, more damage absorbed when upgrading HP/armour, bounded set objects, unchanged normal spawn rules outside the exit, and a recoverable path from reconstruction back to the rite. Formula-mirroring assertions alone do not satisfy acceptance.

## 13. Handoff instructions to Claude

Read this whole file before editing. Preserve the player's stated intent and follow the stages in order. The design is already authorised for handoff; do not spend a turn asking whether the general idea is acceptable. Inspect the current repository and identify any material divergence from the inspected baseline. Resolve routine implementation details yourself; report genuine blockers with their exact cause.

Implement the plan through small local commits with relevant tests. Keep Ascension tree changes deferred. Do not bulk-replace RarityMath.potency and assume all consumers should grow alike. Do not conflate authored profile targets, static arithmetic checks, deterministic combat probes and human playtest evidence.

At completion, report commit hashes, changed behaviour, tests run, measured before/after results, outstanding playtest targets and any values adjusted from this V1 proposal. If the human playtest prevents engine validation, finish all independent preparation and clearly state which checks remain; do not claim the feature is verified.
