# Synthetic Ascension — Direction, Priorities, and Near-Term Roadmap

**Date:** 2026-08-27  
**Parent:** `docs/SYNTHETIC_ASCENSION_VISION.md` — the vision this roadmap serves; when they disagree, the vision wins.  
**Purpose:** Give collaborators and coding agents the missing design context behind the current technical backlog.

---

## 1. What Synthetic Ascension is trying to become

Synthetic Ascension is **not** trying to become the most technically scalable horde survivor.

The target is closer to:

> **Horde-survivor action + Slay the Spire-style run construction + Risk of Rain / Binding of Isaac / Nova Drift / Noita-style emergent build engines.**

The player should begin a run with understandable equipment and relatively ordinary combat, then gradually construct an increasingly absurd **synthetic-occult machine** out of:

- equipment;
- rarity and merging;
- POS / NEG polarity;
- augments;
- sets;
- Manifestations;
- Luck;
- Followers;
- Resonance;
- objectives;
- world reactions.

The ideal late-run feeling is:

> **"What the fuck have I built?"**

But the player should still be able to understand **roughly why it works**.

Performance work exists to make that escalation possible. Performance work is **not the product goal by itself**.

---

## 2. The current problem

The project has significantly more real infrastructure than earlier versions:

- procedural districts;
- enemy virtualization;
- ThreatDirector;
- Resonance and Exit Rite;
- rarity merging;
- POS / NEG equipment;
- NEG archetypes;
- Manifestations;
- Run Sheet;
- sets;
- vendors;
- secondary objectives;
- performance telemetry.

The danger now is continuing to add systems while the actual 20-minute play experience still feels like:

> kill -> move -> loot -> kill -> move -> objective -> loot

The game can already be played for a while, but it does not yet consistently produce the moments that make the player say:

> "Oh fuck, now the run changed."

or:

> "I need to survive long enough to see where this build goes."

The immediate development goal is therefore **not more breadth**.

It is:

> **Prove that the existing systems can produce one genuinely great run.**

---

# 3. Two development tracks

## Track A — Make the machine trustworthy

This is engineering / correctness work:

- broken benchmarks;
- materialization leaks;
- scheduler cost;
- exit crashes;
- save regressions;
- Burden calculation bugs;
- stale versioning;
- performance telemetry;
- CI;
- repository hygiene.

These matter because broken foundations make playtesting misleading.

But completing Track A does **not automatically make the game fun**.

## Track B — Find the "fuck yes"

This is the experiential game-design track.

The questions are:

- Does killing things feel good immediately?
- Does the run form a recognisable identity?
- Do builds change how the player behaves?
- Does the world create memorable situations?
- Are there visible power thresholds?
- Does the world react to the player's escalation?
- Is the Exit Rite something worth surviving to?
- Can a player finish a run and describe what happened without talking only about numbers?

Track B is currently at least as important as Track A.

---

# 4. Priority framework

Every backlog item should ideally be tagged as one of:

### OBSERVED
Measured or reproduced technical problem.

Example:

> Projectile processing costs 15–20 ms at 550 bullets.

### PLAYTEST
A problem repeatedly visible during actual play.

Example:

> Players cannot tell why a late wave is dangerous.

### DESIGN BET
A change we believe will improve the game, but it still needs testing.

Example:

> Add authored charger formations on top of continuous spawning.

### VISION
A requirement because it serves the intended identity of Synthetic Ascension.

Example:

> Followers should eventually function as belief / metaphysical pressure, not only currency.

This prevents:

> "Dictionary allocation costs 3 ms"

and:

> "The game has no emotional climax"

from appearing equally important just because both are backlog items.

---

# 5. Tier 0 — Correctness blockers

These should be fixed first because otherwise playtesting can lie.

## 5.1 Fix Burden normalization

Doctrine of Burden is intended to count curses that are at least a meaningful fraction of the item's **authored NEG range**.

Conceptually:

```text
burden_ratio =
current_negative_severity
/
maximum_authored_negative_severity
```

Example:

```text
Item A
NEG range: 0 -> -20%
roll: -3%
burden ratio: 15%

Item B
NEG range: 0 -> -90%
roll: -9%
burden ratio: 10%
```

Doctrine should judge them by relative burden, not by a universal raw `-10%` threshold.

Its identity is:

> **many mild but meaningful curses**

not:

> **only items with at least -10 percentage points qualify**

## 5.2 Separate polarity census from active stat Burden

There are multiple distinct questions.

### Polarity census

> How many equipped items are intrinsically POS or NEG?

This can reasonably include all equipment slots and can feed systems such as:

- Equilibrium Sigil;
- future set polarity;
- other polarity-count mechanics.

### Active stat Burden

> How much statistical curse is actively affecting the player?

This should reason about the slots that participate in the normal stat system.

Useful for:

- Corruption Engine;
- Doctrine of Burden;
- Inversion Lens;
- Litany of Wounds.

### Scripted accessory burden

Potential future category for equipment whose roll affects custom scripted behaviour.

Do not let accessories enter Burden arithmetic accidentally.

## 5.3 Lock Inversion Lens semantics

Recommended rules:

1. Lens selects the most severe active NEG roll among statistical equipment slots only.
2. The selected curse stops applying normally.
3. It does **not** contribute to Corruption severity.
4. It does **not** count as Doctrine Burden.
5. It should not contribute to Litany Burden later.
6. The item itself remains intrinsically NEG.
7. Therefore it may still participate in polarity-count systems.
8. Lens modifies runtime effective burden only; it does not rewrite the stored item roll.

This prevents:

> Equip a -100% curse -> Lens removes downside -> Corruption still counts -100% -> receive both rewards for almost no cost.

## 5.4 Add regression tests

At minimum:

### Doctrine normalization

```text
Item A:
max NEG = -20%
roll = -2.1%
=> qualifies

Item B:
max NEG = -100%
roll = -9%
=> does not qualify
```

### Lens slot eligibility

```text
Armor:
-50%

Ring:
-90%

Lens equipped
```

Expected:

```text
Armor is selected for inversion.
Ring is ignored if it is outside the statistical slot domain.
```

### Inverted burden exclusion

```text
Helmet = -80%
Chest = -40%
Boots = -20%
```

Lens consumes Helmet.

Expected:

```text
active Burden severity = 60%
not 140%
```

The polarity census may still report:

```text
NEG item count = 3
```

## 5.5 Add Doctrine contribution caps

Doctrine scales naturally with item count, so it needs a bounded ceiling.

Do **not** lock final balance numbers yet.

Add configurable cap infrastructure for:

```text
doctrine_hp_cap
doctrine_armor_cap
doctrine_hp_per_item
doctrine_armor_per_item
```

Then determine final values through playtesting.

## 5.6 Fix the pressure benchmark

The benchmark must actually exercise the pressure policy it claims to test.

Use either:

- a workload that genuinely crosses the pressure threshold; or
- a controlled pressure override that measures the tier-policy effect directly.

## 5.7 Instrument materialization reasons

Record why each actor is materialized:

- in-band;
- protected;
- not proxy-eligible;
- leased;
- special archetype;
- other.

Then compare live sessions against the benchmark.

## 5.8 Version / telemetry identity

Use one source of truth for the game version.

Developer telemetry should include:

```text
game_version
git_commit
git_branch
world_seed
Godot_version
```

---

# 6. Tier 1 — Make one run fucking good

This is the most important phase.

Do **not** ask procedural generation to discover the fun.

First create one deliberately strong approximately 20-minute run.

Then make the procedural systems reproduce variations of that experience.

## 6.1 The three missing "hits"

### Immediate hit

Within seconds:

> Moving and killing things feels good.

This is about:

- impact;
- hit confirmation;
- enemy death response;
- knockback;
- recoil;
- projectile weight;
- crit feedback;
- sound;
- animation timing.

One melee, one ranged, and one magic baseline option should feel satisfying **before buildcraft does anything**.

### Build hit

Within roughly 5–10 minutes:

> "Oh shit, I see what this run is becoming."

This is where:

- NEG archetypes;
- Manifestations;
- sets;
- augments;
- rarity;
- Luck

must start changing decisions and combat behaviour.

### Run hit

By approximately 20 minutes:

> Something happened that I would tell somebody about afterwards.

This requires:

- memorable encounters;
- escalation;
- risk/reward;
- power contrast;
- world response;
- a proper climax.

---

# 7. Suggested authored 20-minute test run

This is a vertical slice used to prove the game can produce the desired emotional rhythm.

## 0–3 minutes — establish the run

- readable combat;
- strong baseline weapon feel;
- world establishes place and tone;
- first objective begins;
- player is weak enough that basic enemies still matter.

## 3–6 minutes — first build identity

Give enough loot for a real decision:

- POS vs NEG choice;
- first Manifestation;
- first meaningful merge;
- early vendor or risky pickup.

The player should begin thinking:

> "Maybe this run is becoming a Corruption / Doctrine / Lens / Momentum / Shard thing."

## 6–9 minutes — first encounter punctuation

Introduce a situation that changes movement or targeting:

- charger line;
- shield formation;
- sniper crossfire;
- summoner nest;
- hunter elite.

The player should stop autopiloting.

## 9–12 minutes — engine starts connecting

The second / third Manifestation interaction should begin creating an actual play loop.

Example:

```text
dash
-> Momentum
-> heavy attack spends Momentum
-> Shards
-> Shard hit
-> Fortune / Cadence / Ward interaction
```

The build should become visible in combat, not only in the inventory.

## 12–15 minutes — deliberate risk

Add one clear:

> **"Fuck it, let's do this."**

moment.

Examples:

- optional monstrosity;
- ritual challenge;
- high-value convoy;
- cursed vault;
- guaranteed Manifestation reward;
- threat spike for rare loot.

## 15–18 minutes — power threshold

Allow the build to become visibly ridiculous.

Old enemies that were threatening at minute 4 should now sometimes be annihilated.

Then introduce something worse.

## 18–20+ minutes — Exit Rite as a climax

The Exit Rite should not feel like:

> bar full -> walk through door.

The world should know the player is trying to leave.

Possible changes:

- pressure spike;
- enemy compositions change;
- route closes;
- specialist response arrives;
- reality distortion increases;
- optional final reward appears;
- the build gets one last chance to show off.

The player should either:

> escape looking like a god

or:

> die painfully close to the exit.

---

# 8. Combat depth — pressure is not drama

The ThreatDirector creates continuous pressure.

Continuous pressure is useful, but it is not the same thing as encounter rhythm.

Add authored encounter beats on top of it.

## 8.1 Encounter grammar

Instead of only asking:

> How many enemies should spawn?

the director should eventually ask:

> What kind of problem should the player face?

Useful encounter categories:

### Assault
Direct horde pressure.

### Formation
Readable structure:

- shield wall + ranged rearline;
- charger wedge;
- sniper crossfire;
- summoner escort.

### Hunter
One dangerous enemy specifically pursues the player.

### Nest
A static or semi-static threat generates enemies until dealt with.

### Convoy
Enemies escort something valuable.

### Lockdown
Local routes or district rules change temporarily.

### Hunt target
A valuable target attempts to escape.

### Ritual interference
Local rules temporarily change.

Examples:

- projectiles curve;
- dead enemies revive;
- NEG effects intensify;
- Luck behaves strangely;
- healing is restricted.

---

# 9. Elite legibility

At high threat, "elite" should not become synonymous with "most enemies."

If everything is elite, nothing is elite.

Prefer fewer, strongly readable modifiers.

Examples:

### Armoured
Requires heavy attacks, flanking, armor break, or a build-specific answer.

### Vampiric
Feeds from nearby enemies or damage dealt.

### Shielded
Protects nearby enemies and creates formation structure.

### Splitting
Punishes careless kills in dense groups.

### Fast
Forces movement / spacing adaptation.

Escalation can increase modifier count, combinations, and formation complexity instead of simply raising elite probability toward 100%.

---

# 10. Objectives must create situations

Synthetic Ascension should not become:

> stand inside circle until progress bar fills.

Objectives should change the local game state.

Examples:

### Hold
Activate something that changes local spawning and creates directional pressure.

### Hunt
A target moves through the district and may escape.

### Extraction
Acquire something valuable and survive the route out.

### Sacrifice
Accelerate Resonance at a cost:

- temporary max HP reduction;
- disabled healing;
- immediate Threat increase;
- forced elite response.

### Rescue / escort
Follower group physically attempts to leave.

### Ritual disruption
Destroying the target weakens the district but causes a Resonance spike.

### Risk-reward objective
Guaranteed Manifestation or rare item in exchange for immediate escalation.

---

# 11. Power contrast

Avoid perfect treadmill scaling.

If the player becomes 30% stronger and enemies become 30% stronger at the same time, progression happened mathematically but not emotionally.

Sometimes:

> enemies that were dangerous earlier should simply die.

Then introduce a stronger threat.

Desired rhythm:

```text
"Oh, these guys used to be a problem."

BOOM.

"...what the fuck is THAT?"
```

---

# 12. NEG archetypes — playtest before expanding

The current three archetypes are already enough to test whether the NEG concept works.

Do not immediately add A3 / A5 / A6 / A7 until these three create genuinely different behaviour.

## 12.1 Corruption Engine

Fantasy:

> **A few horrifying curses are valuable.**

Playtest questions:

- Does the player actively inspect severity?
- Do they choose conventionally worse gear because the curse is useful?
- Do they seek NEG merges?
- Does replacing a severe curse feel meaningful?
- Does the cap matter?

## 12.2 Doctrine of Burden

Fantasy:

> **Many mild, real curses form a stable machine.**

Ideal inventory:

```text
-4%
-7%
-5%
-8%
-3%
-6%
```

Question:

> Does the player ever prefer six mediocre cursed items over two amazing cursed items?

## 12.3 Inversion Lens

Fantasy:

> **One horrific flaw becomes the crown jewel of the build.**

A roll such as:

```text
-95% attack speed
```

should create excitement for a Lens build rather than disappointment.

---

# 13. Manifestations — engines, not perks

The Manifestation system should not be judged mainly by:

> Are the individual effects strong enough?

The real question is:

> Do several Manifestations combine into a different play loop?

Useful roles:

### Generators
Create Momentum / Shards / Fortune / Ward / Cadence.

### Converters
Turn one resource into another.

### Spenders
Consume a resource for an effect.

### Amplifiers
Improve effects triggered by a resource.

### Bridges
Connect unrelated events.

Examples:

```text
crit -> Fortune
dash -> Momentum
```

### Loop closers
Feed an output back into an earlier stage.

Desired network:

```text
generator
-> converter
-> spender
-> trigger
-> bridge
-> generator
```

That is when a build begins feeling like Risk of Rain / Noita / Path of Achra rather than a collection of passive bonuses.

---

# 14. Manifestation playtest criterion

At the end of a run, ask:

> Can the player describe what the build **does** in one sentence without talking about stat percentages?

Bad:

> "I had a lot of damage and attack speed."

Good:

> "I dashed through enemies to build Momentum, dumped it with heavy attacks, sprayed Shards everywhere, and Shard hits fed Ward."

---

# 15. The Run Sheet should become the build brain

The Run Sheet is not only a statistics archive.

It should increasingly answer:

> **What am I?**

Example:

```text
Primary identity:
Doctrine of Burden

Secondary engine:
Momentum -> Shard conversion

Set:
Gravemarch 2/4

NEG:
6 pieces
91% active burden
1 curse inverted

Luck:
+38

Manifestations:
7 active
4 connected interactions
```

It should also answer:

> **Why did this number change?**

Example:

```text
Max HP

Base HP                 100
Chest                    +24
Rarity potency           +11
Doctrine                 +29%
Set bonus                +15
Manifestation Ward        +8
--------------------------------
Current                  181
```

Longer term, the Run Sheet should help explain interaction chains.

The goal is:

> **Noita / Risk of Rain complexity with enough Hades-like readability that the player can trace the machine.**

---

# 16. Followers should eventually become more than currency

Followers can potentially represent:

- belief;
- attention;
- social pressure;
- metaphysical power;
- reconstruction;
- reality destabilization.

Possible future uses:

- follower thresholds trigger world reactions;
- some abilities consume belief;
- events appear only at high follower counts;
- death damages the following;
- NPC/world response changes;
- Gambler's Rite produces Followers because cursed acquisitions become spectacle;
- high belief increases instability / attention.

Do not reduce them to generic kill currency if a richer use proves fun.

---

# 17. Luck should be a probability axis

Luck should not become:

> +X% better loot.

Potential effects include:

- POS / NEG roll behaviour;
- item drop rate;
- extra random crit events;
- evasion;
- follower gain;
- vendor quality / pricing;
- exploration events;
- Manifestations;
- rare outcomes;
- secondary events.

Useful philosophy:

> High Luck occasionally gives the player **another roll on reality**.

High Luck does not always need to mean:

> better result

It can sometimes mean:

> stranger result

---

# 18. The world should react to player escalation

The player is becoming increasingly impossible.

The world should notice.

## Early

Recognisably normal:

- institutional security;
- police;
- ordinary streets;
- subtle wrongness.

## Middle

The response adapts:

- specialist enemies;
- synthetic anomalies;
- strange tactical behaviour;
- increasingly unnatural encounters.

## Late

The world stops pretending:

- impossible enemies;
- architectural instability;
- strong manifestation effects;
- reality behaving differently;
- the player's build and environment visually converging.

## Exit Rite

The world actively resists departure.

This gives Resonance and run progression a narrative / visual function beyond:

> enemy stats increase.

---

# 19. Tier 2 — Proceduralize the proven run

Only after the authored vertical slice is genuinely fun should procedural systems be tasked with reproducing its rhythm.

Then:

- ThreatDirector chooses encounter grammar;
- procedural districts expose appropriate spaces;
- secondary objectives create risk/reward situations;
- events vary route decisions;
- loot pacing supports build thresholds;
- enemy ecology reacts to Resonance / build state;
- Exit Rite variants create different climaxes.

Principle:

> **Author fun first. Proceduralize its structure second.**

---

# 20. Tier 3 — Scale the proven game

Once target gameplay is proven:

- broader data-only enemy proxies;
- cheaper scheduler assignment;
- projectile batching;
- GDExtension only if the proven combat model actually needs it;
- shared spatial index;
- EnemyWorld as authoritative simulation state;
- deterministic benchmarking;
- CI performance gates;
- overlay batching;
- pickup magnet architecture;
- rendering cleanup.

Performance work now has a precise target:

> Preserve the proven gameplay at acceptable frame time.

---

# 21. How to interpret the current technical backlog

## High priority now

- pressure benchmark correctness;
- live materialization reason telemetry;
- hard control over pathological live actor counts;
- Burden correctness;
- exit crash;
- version / telemetry identity;
- combat-affecting scheduler regressions.

## Important, but only after gameplay demands it

### Data-only proxies for every archetype

Before implementing a proxy for every enemy, ask:

> Does this enemy need meaningful off-screen simulation at all?

Do not build simulation complexity merely because the architecture permits it.

### Projectile GDExtension

550 bullets costing 15–20 ms is real.

But do not immediately commit to C++ before the final combat model is proven.

The fun version may want:

- fewer but more consequential bullets;
- batch visual pseudo-projectiles;
- more chain reactions;
- fewer true collision entities.

Prefer cheaper batching / packed-math experiments first.

### Complete EnemyWorld migration

Architecturally attractive, but it is a longer-horizon investment unless gameplay work is blocked by duplicated authority.

---

# 22. Tier 4 — Expand buildcraft after the core hits

Once the current three NEG archetypes and Manifestations demonstrably create different runs:

## A5 — Litany of Wounds

Fantasy:

> **Suffering becomes tempo.**

While below a health threshold or shortly after meaningful damage, gain Haste based on active NEG severity.

Guard:

> only meaningful hits, e.g. >=2% max HP, arm the recent-damage window.

## A7 — Gambler's Rite

Fantasy:

> **A cursed pickup becomes a bet.**

On first acquisition of a NEG item:

```text
base chance
+ Luck contribution
-> possible Follower gain

always:
-> small Resonance gain
```

## A3 — Equilibrium Sigil

Fantasy:

> **Inventory as a polarity puzzle.**

Condition:

```text
POS count == NEG count
minimum 2 each
```

A player may reject a strong POS item because it breaks balance.

## A6 — Gravemarch NEG polarity

Fantasy:

> **A familiar set mutates when enough of it becomes cursed.**

Example:

```text
3+ NEG Gravemarch pieces
-> defensive armor identity transforms into life-drain aura
```

---

# 23. Explicitly do not do these things yet

- Do not add more scheduler tiers.
- Do not raise `max_physics_steps_per_frame` to hide performance problems.
- Do not tune pressure thresholds against a benchmark that does not exercise pressure.
- Do not build dozens of new Manifestations before proving the current graph can create memorable engines.
- Do not add A3 / A5 / A6 / A7 simply because they are next on an old roadmap.
- Do not turn every enemy archetype into an expensive data-only simulation because it is technically possible.
- Do not commit to a C++ projectile rewrite before the desired late-game combat model is proven.
- Do not assume procedural generation will discover good pacing on its own.
- Do not perfectly scale enemies alongside the player and erase the feeling of becoming powerful.
- Do not reduce Followers, Luck, NEG, or Resonance to generic percentage systems if they can become thematic mechanics.
- Do not confuse a clean benchmark with a fun game.

---

# 24. Near-term ordered roadmap

## Phase 1 — Trustworthy foundations

1. Fix Burden normalization.
2. Separate Lens statistical-slot selection from all-equipment polarity census.
3. Add regression tests.
4. Add Doctrine cap infrastructure.
5. Fix the pressure benchmark workload / override.
6. Instrument materialization reasons.
7. Reduce pathological >60 physics-enabled actor cases.
8. Fix version / telemetry identity.
9. Continue exit-time crash investigation.

## Phase 2 — Prove one great run

1. Improve baseline melee / ranged / magic hit feel.
2. Playtest Corruption / Doctrine / Lens as distinct builds.
3. Ensure at least 2–3 Manifestation engines can realistically emerge.
4. Add 5–8 encounter beat types.
5. Add one strong optional risk/reward encounter.
6. Add visible power contrast.
7. Add meaningful mid-run escalation.
8. Make Exit Rite a climax.

## Phase 3 — Proceduralize the rhythm

1. ThreatDirector schedules encounter grammar.
2. Objectives create different gameplay situations.
3. Procedural spaces support those situations.
4. Route decisions matter.
5. Loot pacing supports build thresholds.
6. World response escalates with Resonance / player state.
7. Exit Rite gets variants.

## Phase 4 — Scale it

1. Expand proxy coverage where gameplay justifies it.
2. Make scheduler refresh cheaper.
3. Batch projectile simulation.
4. Use GDExtension only if still necessary.
5. Consolidate spatial queries.
6. Continue EnemyWorld authority migration.
7. Add deterministic performance captures.
8. Run meaningful performance gates in CI.

## Phase 5 — Expand buildcraft

1. Litany of Wounds.
2. Gambler's Rite.
3. Equilibrium Sigil.
4. Gravemarch polarity mutation.
5. More Manifestations based on missing interaction roles.
6. More sets / augments only where they create new play patterns.

---

# 25. Success criteria

The next major milestone is **not**:

> "All planned systems are implemented."

It is:

### Immediate

> "Killing things feels good."

### Around 5–10 minutes

> "I know what my run is becoming."

### Around 15 minutes

The player experiences a visible power threshold.

### Around 20 minutes

The player experiences an encounter or escalation worth remembering.

### End of run

The player can describe the build in behavioural terms.

Good example:

> "I kept dashing through enemies to create Momentum, dumped it into heavy attacks, generated Shards, and used the Shards to keep Ward running while Doctrine made my six curses keep me alive."

Bad example:

> "I had +140% damage."

### Long-term

Different runs should create stories such as:

> "I found a horrific curse and built my entire Lens run around it."

> "I maintained exactly four POS and four NEG pieces because breaking Equilibrium would kill the build."

> "My cursed pickup economy kept feeding Followers through Luck."

> "I accidentally built a Momentum-Shard-Fortune loop that turned every dash into a chain reaction."

That is the game Synthetic Ascension is trying to become.

---

# 26. One-sentence collaborator brief

> **Synthetic Ascension is trying to combine horde-survivor action with Slay-the-Spire-style run construction and Risk-of-Rain / Isaac / Nova-Drift / Noita-style emergent build engines. The player should begin with understandable equipment and end with an absurd synthetic-occult machine they partially designed and partially discovered. Performance work exists to allow that escalation, not to become the project itself. The immediate design goal is to make one 20-minute run develop a clear identity, contain memorable encounter beats, visibly cross power thresholds, force meaningful build decisions, and culminate in an Exit Rite worth surviving to.**

---

# 27. Status log (appended by implementation; the sections above are the intent)

## 2026-08-28

**Phase 1 — done.** 1.1-1.4 in `9619305` (relative Doctrine burden, census vs
active domains, Lens on statistical slots, cap infrastructure; BurdenSystemTest
+28). 1.5-1.8 in `20b1b21` (pressure benchmark runs both arms under a pressure
override and gates on ordinary physics bodies, materialization reasons in the
policy and recorder, burst demotion over budget, BuildInfo identity in
incidents/reports). 1.9 in `6639ece`: three bisection arms measured on the
rollout repro; the residual ~25% is inside engine finalization with 332 leaked
objects; player-facing quits now end the process after flushing saves and
reports (`Global.request_quit`), tests keep exit codes.

**Phase 2 — mechanisms built, verdicts pending.** 2.1 HitFeel autoload
(hit-stop + camera punch, exports, reduced-motion aware); 2.2/2.3
BuildIdentity "what am I" sentence on the Run Sheet and manifestation
thresholds at 3/5 rules; 2.4 seven authored beats + EncounterDirector; 2.5
Cursed Vault placed from segment 2; 2.6 power-contrast window in the
ThreatDirector; 2.7 phase-escalation cue with a newly unlocked beat; 2.8 rite
pressure mode, specialist response, climax pulse (`6639ece`, `a8a535a`). Not
built: elite modifiers (§9), ritual-interference beats, healing lock, the 85%
optional rite reward, "route closes". Plan and per-item status:
`docs/superpowers/plans/2026-08-27-phase2-one-great-run.md`.

**What only a human can do next:** play the authored run and answer §25 —
protocol in `docs/2026-08-28-playtest-protocol.md`. Phase 3 stays gated on
that verdict (§19). Every number added in Phase 2 is an export; tuning is the
playtest's job, not the implementation's.

**Idle-time work while gated** (discover / verify / catalogue / test / clean /
document only): `docs/current_game_data.md` and the audit series under
`docs/audits/` (cleanup, stale docs, logging, performance hygiene, Godot
hygiene, Run Sheet completeness, save compatibility, naming).

**2026-08-28, later — audit series delivered** (`d7042b4` … `dc1783a`), all
read-only: `docs/audits/2026-08-28-cleanup-audit.md` (the ranked consolidation:
ten safest wins, ten highest-risk legacy areas, size scenarios, future-bug
sites) over `dead-code-orphans`, `stale-docs` (+ `-july-plans`), `stale-tests`,
`save-compatibility`, `naming-consistency`, `godot-hygiene`, `logging`,
`performance-hygiene`, `run-sheet-completeness`, `test-coverage-gaps` (329
production scripts, 118 with no test, 51 of them HIGH risk: InventoryRouter,
the item-effect scenes, the ten manifestation pair rules, the enemy-to-player
damage path, set effects, primary objectives). Headlines: 449 MB of tracked JSON captures nothing reads; ~26 MiB of
provably dead files shipping via `all_resources`; saves keyed by `res://`
paths (any item/script rename bricks them and the UI offers to overwrite);
zero tests target a removed system, but 13 probes/benchmarks cannot fail.

Final full sweep on the committed Phase 2 tree (`a8a535a`, headless
`--quit-after`): **83 suites, 0 failures, 0 script errors** — with the caveat
the stale-tests audit documents: the display-only probes report an empty
summary and exit 0 regardless, so "83 clean" overstates coverage by about a
dozen.

**2026-08-29 — cleanup wins executed, save system hardened** (`13bebb4` …
`2dca035`, 16 commits). The ten safest cleanup wins are done (cover art moved
to `marketing/`, not deleted; `EnemyIndex.gather_in_radius` and
`Weapon.try_attack` kept — see the cleanup audit's status section); two
permitted bugfixes with regression tests (pooled projectile despawn,
game-over fallback); save hardening per the save-compatibility audit
(unreadable primary set aside, SaveSelect refuses to overwrite,
`save_version`/`game_version`, dangling manifestation ids, settings schema
warning). Risk #5 (a data-only save format) remains a design decision.
Regression sweep: 85 suites on `2dca035` (the 82 from the pre-series baseline plus PooledProjectileRecycleTest, GameOverFallbackTest, SaveSelectUnreadableSlotTest): **0 failures**; the only script-error lines are the corrupt save fixtures that SaveIntegrityTest and SaveSelectUnreadableSlotTest parse on purpose. Four suites exited non-zero — DevConsoleShotProbe, ManifestationHoverProbe, ObjectiveShotProbe, UiConsistencyVisualProbe — all display-only probes hitting their own watchdogs because this runner no longer quits them by frame count; that is the vacuous-pass behaviour the stale-tests audit documents, not a regression.


## 2026-08-30

**Three audit findings fixed** (`13c7d0f`, `2aebf62`, `b2b1604`): the
BuildIdentity Luck clause compared a fraction against `20.0` and could never
fire — a green test was hiding a dead branch (run-sheet audit #9; threshold
`0.20`, prints `%`, fixture corrected); MagicMissile and StaminaCore printed
in release builds (logging audit #1-#3; traces behind `debug_prints`, aura
failures become one-shot warnings); the two manifestation catalogs' static
caches lacked `@static_unload` (Godot hygiene §1; released from
`Global._exit_tree` like the other caches).

**Every 2026-08-28 audit now carries a status section** (`f14868a`): the ten
that had none were re-verified finding by finding against the tree — 59
findings fixed or overtaken by the 08-29 deletions, ~209 still open, and five
claims in the audits themselves corrected (a perf row that costed a script
nothing ever ran, a naming row that read a signal name as player text, a
stale-docs row wrong on the day it was written). Coverage counts re-derived:
322 production scripts, 111 uncovered, HIGH 51 unchanged — the new 08-29/30
tests all deepen already-covered scripts.

**Two new read-only audits, both idle-time work while Phase 3 stays gated:**

- `docs/audits/2026-08-30-save-path-stable-id-plan.md` (`a2c302a`) — the
  plan the save-compatibility audit's risk #5 was waiting for. Exactly two
  persisted fields are `res://`-path-keyed (`attempt_resume_scene`,
  `ItemInstance.data` through the four containers) and six scripts are
  path-referenced; everything else already uses stable ids. A headless probe
  (reproduced independently) shows a renamed item `.tres` kills the whole
  profile file, both generations. Proposed: `save_version 2`, `data_id` +
  resume token, a 31-row alias table in `res://`, resolution on the load path
  so the slot cards see it. **Nothing renamed, nothing implemented** — the
  format is unchanged until that decision is taken.
- `docs/audits/2026-08-30-neg-manifestation-observability.md` (`5b6bfc3`) —
  the three NEG archetypes, all 18 rules and all 10 pairs, judged only on
  what the player can see. 80 mistakable-for-bug moments and 42 invisible
  truths, ranked; the burden ledger is formula-true but two clicks deep and
  absent at zero curses; a suppressed slot still shows its stored `-80`
  while contributing `+44%`; the pair rule lives only in code comments; six
  live `describe()` strings contradict their code. No balance or design
  change proposed — this is the §15 "build debugger" gap list, and the
  readability half of §25's "can the player describe the build".

Both new audits went through two adversarial review rounds; the first round
removed three proposed fixes that were redesigns in disguise. Local only, not
a repo change: this machine's import cache was regenerated, which cleared two
`ScriptParseAuditTest` failures that were never in the code (317/0 now).

Regression sweep on `a2c302a` (all 89 `tools/tests/*.tscn`, headless,
`--quit-after 3000`): every suite exited 0, zero FAIL lines, zero script
errors. 51 suites report 1683 passed / 0 failed, 20 report 463 passes /
0 failures, and the remaining 18 are the display-only probes and
benchmarks the stale-tests audit documents as unable to fail.

## 2026-08-30, later — readability wave 1 (25 commits, `333fcb6` … `8e42061`)

Basis: `docs/SYNTHETIC_ASCENSION_VISION.md` is now the canonical vision
(`b874dba`; `gamegoal.md` is bannered as superseded) and the observability /
Run Sheet audits are its gap list. This wave implements the surfacing half of
that list — every change shows a value, slot, condition or event the code
already computed; no constant, threshold, rate, cap or activation rule moved.

**Run Sheet as build debugger (vision §Run Sheet; §15).** The per-stat ledger:
`recompute_run_stats` records itself step by step (race, style, belief, items,
sets, item effects, manifestations, every slot roll — INVERTED when the Lens
holds it — Engine, Doctrine, Lens, the Max HP price) and the Profile shows the
rows under each stat, so "why is this stat this high?" has an answer that sums
exactly to the number above it (`RunSheetLedgerTest`, and
`LensRetargetFeedbackTest` drives the real pass). PWR/HST show the runtime
multipliers the next shot uses; the Doctrine Record prints each stage's gift
and price and the Max HP multiplier; belief and the Lens Luck kicker are
named; the BURDEN block names the slots behind every count, says which two the
Engine burns, renders at zero curses when an archetype is owned, and states the
Doctrine's statistical-slot scope; the LCK row prints the Lucky Crit chance
(0% at or below zero Luck — why two rules never fire there); one box per rule
with a copy count; ◆◇ pips shared with the HUD; "meter appears at first bank";
a dimmed "next pair" line.

**Loot evaluated by build (vision §Corruption / Doctrine / Lens).** A slot the
Lens suppresses now says what it *pays* (+44%) on the bar, the tooltip and the
swap preview instead of the stored −80; the tooltip comparison reads a deeper
curse the way the Lens will; the feed line says when feeding would shrink the
inverted return; a Lens retarget is announced from the stat pass ("LENS: …
curse returns — … curse inverted"); the Engine's feed toast says "deepened to
−N%"; the SUPPRESSED line says the curse counts for neither the Doctrine nor
the Engine; augment `details` name the statistical-slot rule and the
Doctrine's range floor; augment tooltips show level-scaled stats and Luck as a
percentage; "polarity census" replaces the false "parity and sets" claim and a
POS roll prints what it does to its slot.

**Power escalation should be visible (vision §Power Escalation).** The
power-contrast window is finally announced — `power_threshold_noted` has a
listener — and the Threat tooltip shows "Enemy scaling held — Ns", the segment
phase, the elite chance and the rite channel (it also called sped-up spawns
"slower"; fixed).

**Manifestations as engines, readably (vision §Manifestations, Hades lesson).**
Six `describe()` strings that contradicted their code now say what the rule
does (Pilgrim's Momentum's real fill distance, Marching Order, Red Line's
re-arm, Death Rattle's empowered beat, Orbiting Testament's Luck sharpening,
Tithe Rhythm) and the two Lucky-Crit rules state their ignition condition;
Death Rattle's toll is a damage number; Scar Tissue and Bad Fortune say when
they act; Composure's meter says what a full bar buys (as a sheet-only hint —
the HUD row stays bare); the pair rule is taught in the intro card and the
pair notifier; a two-channel noun's HUD row shows the fuller channel; the
callouts checkbox says what it silences.

Method: five file-ownership clusters in isolated worktrees, each branch
adversarially reviewed before integration (three should-fix findings, all
fixed: an unpinned pickup path, a comment describing a mechanism that does not
exist, the Composure clause in the wrong field). Agents refused two audit
wordings as untrue ("ranks the rule up"; "curse returns" on removal) and
reported five items outside their ownership, which were integrated by hand.
The Engine's rate/cap and the Lens kicker now live in `BurdenResolver` and the
sheet reads them — one pair of numbers, not two copies.

Not done, deliberately: `AugmentSelect.gd` still formats unscaled stats (its
own copy — a follow-up); `docs/current_game_data.md` paraphrases the old rule
texts; the catalog's fallback rule strings are unchanged; the Engine deepen
toast is not shown on the bag-stack path because a bagged copy moves no stat.
Still not built from the vision: elite legibility, objectives as situations,
the world losing normality, Followers as belief, Equilibrium, route changes in
the Rite — Phase 3+, and still gated on the playtest, which these surfaces
exist to make honest.

Regression sweep on `8e42061` (all 95 `tools/tests/*.tscn`, headless,
`--quit-after 3000`; six suites new this wave): every suite exited 0, zero
FAIL lines, zero script errors — 57 suites report 1917 passed / 0 failed, 20
report 463 passes / 0 failures, 18 are the display-only probes and benchmarks.

## 2026-08-30, later still — Phase 2 completed: wave 2 (`99d2ab0` … `cdab69e`)

§27's "not built" list for Phase 2 — elite modifiers, the ritual-interference
beat, the healing lock, the Rite's 85% reward and 50% cue — is built. All of
it is DESIGN BET work per §4: every number is an export or a commented const,
no existing balance number moved, and each mechanism carries a tell on the
thing itself and a first-sight teach line. Verdicts remain the playtest's.

**Elite legibility (§9, plan 2.7).** `EliteModifiers`: ARMOURED (a flat plate
per hit — small hits bounce), VAMPIRIC (drains nearby non-elite allies on a
clock — the §9 fallback, because no enemy-owned enemy→player damage hook
exists), SHIELDED (non-elites inside its radius take less), SPLITTING (reuses
the Splitter machinery; an archetype that already splits never gets it), FAST.
Picked by segment phase — recon/disturbance none (today's plain elite),
ascension one, collapse two distinct — so "if everything is elite, nothing is
elite" stops being true at high threat. `apply_elite_modifiers()` lets beats
compose them: the Hunter is now fast + vampiric as the plan wrote it. Tells:
tint + a mark per modifier (plate ring, shield hexagon, seam, streak, pulse;
static under reduced_motion); the Threat tooltip names what the phase
unlocks. Verified an elite is never a data-only proxy (ELITE is a required
flag), so modifier state lives on the actor and two O(1) registries in the
damage path. `EliteModifierTest` 92.

**Ritual interference (§8.1, plan 2.7).** A collapse-only beat: a sigil radius
where the dead rise once as weakened revenants (delay, HP fraction, cap and
duration exported); bosses, pylons and objective actors never rise; ring tell
+ teach. `RitualInterferenceTest` 35, `EncounterDirectorTest` 56.

**Healing lock (plan 2.5, §10).** `player.lock_healing(seconds, reason)` —
max-extend semantics, a lock is a lock (the Rite's own mend included), one
"HEALING SEALED" line per lock, a sealed state on the HP bar, a
`healing_lock_changed` event. The Cursed Vault now bills it (45 s export)
alongside its beats — the "fuck it" moment names its price on approach.
`HealingLockTest` 41.

**Exit Rite climax (plan 2.8).** At 50% hold the district warps — a
distortion level drives the vignette's strength/tint on the rig's own copy of
the material (a shared sub-resource was the first review's must-fix); at 85%
a last-chance vault at the rite's edge, guaranteed Manifestation, costing the
whole safeguard buffer; both once per channel via the progress ledger, both
reset with it. `RiteClimaxTest` 54, `CursedVaultTest` 22.

Three must-fix review findings repaired before integration (a replaced FAST
elite kept its speed; arena bosses could rise as revenants; the shared
vignette material), then one systemic defect fixed centrally: all four "teach
once per run" guards lived on per-segment nodes and repeated every segment —
`Global.teach_once()` is now the run's registry (`cdab69e`). Hygiene from
wave 1 closed on the way: AugmentSelect shows level-scaled stats,
BurdenSnapshot's header names the census's real readers, `current_game_data`
quotes the corrected rule texts.

Not done: "route closes" during the Rite (navigation/world work, Phase 3
shaped); manifestation overlays intensifying at 50% (plan 2.8's second
clause — the overlays are the manifestation layer's, a follow-up);
per-archetype allow/deny values in the EnemySpec resources (exports exist,
all default to allowed).

**Polish pass** (`dd2185d` … `8ad55b7`, every review clean): a status tick is
not a hit — burn and bleed pass the ARMOURED plate (an armoured elite had been
immune to every DoT); a cleared elite gets its body colour back; FAST keeps a
still tell (chevrons) under reduced_motion and behind another tint; the
choice screen's "Lv.N" is the level a pick actually yields; the last-chance
vault announces itself once with the whole bill; every presentation number
named as an export or const, no value moved.

Regression sweep on `8ad55b7` (all 99 `tools/tests/*.tscn`, headless,
`--quit-after 3000`; ten suites new today): 61 suites report 2214 passed /
1 failed, 20 report 463 passes / 0 failures, 18 display-only probes and
benchmarks, zero script errors. The one failure — `DevForceSpawnTest`'s "no
detached records survive a full cull" — is a wall-clock-phased soak check
that passed 3/3 on immediate re-run and touches nothing this wave changed;
it belongs with the timing-sensitive probes the stale-tests audit lists.

## 2026-08-31 — audit closure, mostly by hand

Two five-cluster agent waves were launched (audit closure; test-coverage
gaps) and **both ran out of usage credits mid-flight**: ten of twelve agents
died, and both survivors lost their reviewers. Everything below is either one
of those two survivors — reviewed by hand before integration — or done
directly. The dead clusters are listed at the end as the resume list.

**Coverage: the router every item move goes through** (`356b3ea`).
`InventoryRouterTest`, 111 checks, closes test-coverage gap #1 (audit: "zero
tests; item loss or duplication would be invisible to the suite"). Mutation-
checked rather than trusted: neutralising the `locked` guards turns it red,
removing the eject rollback turns it red. It found a live defect, fixed with
its own pin (`adb705d`): a refused eject left the bag's staged VFX origin
armed, so the next vendor buy or granted reward flew in from an equip slot
nothing had left.

**Docs: the entry point that was missing** (`f3bb742` … `076ac4b`, 8
commits). A real `README.md`; `PROJECT_STRUCTURE.md` retitled as the
historical map with its four wrong claims fixed; `OPTIMIZATION_HANDOFF.md`
superseded-bannered with dated corrections; the opening/segment/projectile/
dev-log/changelog rows. Every claim re-verified against the tree of the day —
three of the audit's own specifics had drifted and were corrected in passing.

**Godot hygiene: the top ten are closed** (`2f3f744`, `5d2274f`,
`85b74fa`, `29e2a28`, `08c77b1`, `a089db4`, `518a9ce`, `b223519` — details and the
audit corrections in
that audit's 08-31 status section). The two that matter most for feel: enemy
bullets and spiderlings now travel in physics time like everything else, so
they stop getting relatively faster on a weak machine; and pooled enemies
leave the `"enemies"` group, so a segment restart no longer frees the entire
warm pool and heralds no longer buff parked corpses.

**One self-inflicted regression, caught and fixed** (`e83d588`): the group
change broke the player's contact-source bookkeeping, inflating contact
damage. It surfaced as three script errors in a sweep where **every suite
passed** — the second time in two days that a green sweep was not a clean
one. Both new suites (`PlayerContactSourceTest`,
`EnemyProjectileTimeBaseTest`) cover classes nothing drove before.

**Resume list — the seven clusters the credit exhaustion killed**, all
specified and ready to relaunch: performance-hygiene's ten idle-cost rows;
logging's remaining nine top-15 rows; the never-failing probes plus the
`DevForceSpawnTest` wall-clock flake; and the four coverage clusters (item
effects, the ten manifestation pair rules, SetRunner tiers, the three primary
objectives). Save risk #5 is still a plan
awaiting a format decision, deliberately unimplemented.

Regression sweep on `b223519` (all 102 `tools/tests/*.tscn`, headless,
`--quit-after 3000`; four suites new today): 64 suites report 2353 passed / 0
failed, 20 report 465 passes / 0 failures, 18 display-only probes — and
**zero script errors of any kind**, which is the figure that matters here. An
earlier sweep the same day was green while quietly emitting three
freed-object casts; that is how the contact-source regression was found, and
error count is now read alongside pass/fail.

The last three hygiene rows (#6 `PoolManager`'s autoload fallback parent, #7
`FlowFieldNav`'s stale build state, #8 the await-after-free sites) landed
after that sweep and were swept clean here.

## 2026-08-31, later — the audit series is closed

The seven clusters the credit exhaustion killed were relaunched and all
landed (`d1ad489` … `278c229`). Every audit in the 2026-08-28 series now has
a status section saying what closed, what was corrected, and what was
deliberately left. The counts: **107 suites, 3990 assertions, 0 failures, 0
script errors.**

- **Performance hygiene** — §2's ten idle-cost rows, the audit's ~0.4–0.7
  ms/frame, using its own §3 house patterns. Verified by reverting each
  group, not by inspection.
- **Logging** — the top-15 closed; the floods are once-guards and errors name
  the file and the engine's own error string.
- **Stale tests** — the never-failing probes can fail. Giving
  `ProjectileRenderBenchmark` its first real assertion found its packing had
  been transposed all along, which is the whole argument for that audit in
  one commit.
- **Test coverage** — gaps #1, #2, #3, #5 and #6 closed: the router every
  item move passes through, the seven item effects, all ten pair rules,
  SetRunner's tiers, the three objectives that gate the rite. HIGH drops
  from 51 to ~45.

**Four real defects surfaced by writing tests for untested code**, two fixed:
the whole Conduit set damaged with no source (so neither breakpoint fed
lifesteal or any Manifestation `on_hit` rule — a build engine silently
disconnected), and Slow Heart re-intercepted its own payout (returning
0.89 HP/s against the 5.95 it advertises).

**Two are design decisions and are recorded, not made** (details in the
test-coverage audit's status section): an activated Breach Seal pulls waves
after the player anywhere in the district, spawning around the *player* while
ignoring the breach position it is handed; and `DeathRattle` clobbers a
shared cadence clock another rule may have just reset. Both need a ruling
before code moves.

Method note worth keeping: reviewers were required to *actually mutate* the
production code rather than reason about vacuity, and found real vacuity in
three of four coverage suites plus two must-fix defects in the tooltip cache.
Three separate times this week a sweep was green while emitting script
errors, so error count is now read alongside pass/fail — that is how the
contact-source regression was caught.

**Still open:** the three LOW deferred-call rows in the Godot-hygiene audit;
naming consistency and run-sheet rows; the remaining ~45 HIGH coverage rows.
Save risk #5 remains a plan awaiting a format decision. Phase 2's mechanisms
are complete and the human playtest is still the gate on Phase 3.

## 2026-09-06 — the first playtest, and the stabilization pass it triggered

**One run, Elf ranged, about an hour** — the easiest combination, so this is
a first reading, not the §19 verdict. Against the protocol's questions:

- Run Sheet: the Profile mostly answers "why is my Power this value", but the
  Manifestations page no longer fit on screen.
- Deep curse + Lens: read correctly, with low confidence ("I think I did").
- Noun/pair system: **not taught** — discovered, not learned.
- Elites: read as *different*, but not *which* — the introduction popup is
  gone too fast, and the modifier needs to be recoverable afterwards.
- Exit Rite: better, but it plays as a bullet hell while channelling — a full
  screen of melee and ranged with no tool to clear a lane.
- Impact: the hit shake reads as **lag**, not impact — "I thought my game was
  lagging".
- Economy: ~4,000 Followers by segment 2–3 against shop prices around 100,
  and the shop is the only sink. The vision's Followers-as-belief model
  (§Followers) is not what the economy currently expresses.
- FPS drops during sustained combat; captures taken.
- Conduit and Slow Heart after their fixes: fine for now.

**The stabilization pass (`24413a5`) took the four priorities that fell out
of it**, tests before every change, on top of `a49f4ab`:

1. **Run Sheet** — the overflow was the unwrapped build-identity sentence
   plus fixed-width child labels; Manifestation rows now wrap inside the
   archive. Observations gains a persistent, cross-archetype **elite
   modifiers** reference for every modifier met this run, so a missed popup
   is recoverable (`RunSheetHUD.gd`).
2. **Hit feel** — a four-arm comparison (`HitFeelTest`) proved hit-stop and
   camera punch independent, and found the actual defect: the default decay
   of 16 px per reference frame erased the 3.5–12 px punch within one
   frame, so the view snapped away and straight back — the "lag". The punch
   now keeps a short visible decay tail (`docs/diagnostics/2026-09-06-hit-feel-comparison.md`).
3. **Sustained combat** — the drops are real and **process-bound**, scaling
   with materialized population: frame p95 16.7 ms below 40 enemies,
   55.6 ms at 120+; 97 of 106 incidents process-dominant. The flight recorder
   can hitch (one 32.9 ms snapshot; a repeat peaked at 3.1 ms) but does not
   explain the slope. Ranked next target: the process-side cost of
   materialized enemies at 80–130 (`docs/diagnostics/2026-09-06-sustained-combat-profile.md`).
   The pasted compiler warnings are hygiene, not the cause.
4. **Exit Rite composition** — channelling now caps ambient pressure (81),
   stops random melee refills, reroutes scripted waves into bounded
   specialists, raises the crossfire to three snipers (Rite-only; ordinary
   crossfire stays at two) and replenishes only cleared formations. Seal
   pulses reach 560/680/820 px with the impulse and stun to open a lane,
   with a persistent ring, callout and sound — no damage, no screen wipe.

Its plan (`docs/superpowers/plans/2026-09-06-playtest-stabilization.md`)
was committed with its 32 checkboxes unticked; the work is done, the boxes
are not, so read the commit rather than the boxes.

**Two rulings given and implemented the same day** (details in the
test-coverage audit's status): Breach Seal enemies pour from the breach's
fixed location — dormant when the player is away, capped per breach, with
the culling condition the ruling attached made concrete; and a shared
cadence clock resolves a restore to the *freshest* attack rather than the
first or last writer, through one seam every rule hands a value back to.

**Open design thread, not started:** the Follower economy is an order of
magnitude out — belief Power caps at 225 Followers, most kills grant at
least one, the overtime decay floors at one and cannot devalue them, and
death is the only sink that scales. The vision's answer is current
Followers as spendable reserve, *peak* Followers unlocking run-specific
belief thresholds, and attention escalating the world's response — not a
generic XP bar and not shop prices ×40.

Verified here rather than taken on trust: the stabilization commit was made
while its own review was still running, so the first complete review is the
one below. Sweep on `24413a5` (all 107 `tools/tests/*.tscn`, Godot 4.7.2
headless): 75 suites report 3560 passed / 0 failed, 20 report 465 passes /
0 failures, 12 display-only probes, **zero script errors**. The review found
one of the plan's own constraints half-met — elite modifiers were recoverable
in Observations only if their introduction popped *in view*, so an elite
promoted off-screen left no field note — fixed by owing the introduction
until first sight instead of dropping it. Everything else in the seven
production files held up: the rite cap restores on channel end and on exit,
replenishment cannot duplicate an active formation, the three-sniper
crossfire is Rite-only.

Sweep on `6bcea16` with both rulings in (all 107 `tools/tests/*.tscn`,
headless): 75 suites report 3574 passed / 0 failed, 20 report 465 passes / 0
failures, 12 display-only probes, zero script errors. Each ruling was proved
red→green against the code it replaced before landing: the breach's first
pour pin fails under the old objective (207/1), and the cadence pin fails
with exactly the clobber it names (`0.59s vs gap 0.59s`).

## 2026-09-06, later — the first character art is in the game

The four races and the grunt/spitter test sheets now draw as directional
idle/run characters; the placeholder sprites are gone from `player.tscn`.
Map of the pipeline, the real sheet layouts and the art gaps:
`docs/design/CHARACTER_ANIMATION.md`. In one line: hand-authored
`data/visuals/*` definitions → `tools/bake_character_atlases.gd` →
committed `assets/textures/characters/baked/*` → `PlayerVisualController`
(body + separately anchored head, breathing, dominant-axis facing with
hysteresis) and `EnemyAnimator` (one region swap per step, batched through
the proxy renderer's new per-instance region). Player movement, aiming,
dash, collision and enemy AI are untouched. Known art gaps: no right-facing
heads (left is mirrored), no enemy side views or idle poses.

Same evening, from the second look: sprites are split where neighbours touch
and stripped of spill-over and resampling halo (the enemy side artifacts,
the dragonborn's clipped and floating tail, the stray border pixels);
dragonborn and warforged are drawn bigger with smaller heads; a 1–2 px stride
bob carries the elf's near-static front/back run rows; dossier cards show one
standing frame rather than the sheet. Hit-stop and camera punch are archived: off by
default, kept and tested, entry in the improvement backlog. The art hangs
mid-body on the player origin (feet 42 px below it) so ability rings wrap
the character, not the legs.

## 2026-09-06, night — the Ascension tree is designed, not built

The Follower economy thread above now has an answer on paper:
`docs/design/ASCENSION_TREE_SPEC.md` (research verdicts, economy, structure,
all nine wedges as node tables, bridges, integration, UI, tests, the numbers
marked load-bearing or tunable, and the telemetry that settles them) and an
interactive mock-up, `tools/design/ascension_tree_mockup.html`, generated
from `tools/design/ascension_tree_data.py`. In one line: income scales with
a per-segment Reach factor instead of prices ×40; belief Power keys to peak
Followers; capital costs are fixed per class and escalate per class owned;
peak-congregation gates the outer rings; Revelations charge per target after
resolution; refunds shrink by segment and sworn nodes never refund; the Hub
holds the full tree and Wardstones sell tactical nodes; the Doctrine picks
become the tree's centre. No game code changed. Build order in the spec §8.

## 2026-09-13 — Follower economy audit against the later V4 tree

The production economy is still unresolved. The 6 September Reach/peak proposal
above was not implemented, and the 12 September V4 tree from the task
“audit the idea” uses a different provisional economy. Neither set of prices
has established the intended long-run, billion-Follower progression.

See [the economy audit](audits/2026-09-13-follower-economy-audit.md) and its
captured measurements. A 6,000-item production sample puts the shop after
segment 2 at a median 154 Followers per item and 1,570 for all ten offers,
against the user's roughly 4,000 early reserve. Belief still caps at 225.
V4's supplied complete three-Core route costs 71,000, including its 20,000
Ascendant node; that is prototype pricing, not a finished ascension economy.

The runtime diagnostic also reproduced zero-reward actors paying one Follower,
one-Follower kills ignoring overtime decay, and the exact reconstruction reserve
leaving zero while the death handler requires a positive remainder. Fix these
and the shop's post-trade survival advice before measuring a new balance curve.

Next: settle V4's production progression scale, instrument income and spending,
and balance equipment, tree investment, refreshes and recurring sacrifices
together. Preserve early recruitment and exciting early builds; provide later
growth and decisions beyond segment 9. This update adds audit documentation and
a reproducible probe only; no gameplay formulas or tree prices changed.

## 2026-09-19 — balance revision 2, the seven NEG archetypes, the audit series, the performance war room

Thirty-five local commits (`4d56d7b` … `b5304a3`), all headless-verified,
none pushed. What landed, by the ten workstreams asked for:

1. **Progression-tree audit**: `docs/audits/2026-09-19-progression-tree-audit.md`,
   28 proposals, no code; the redesign stays deferred.
2. **NEG expansion**: Equilibrium Sigil, Litany of Wounds, Gambler's Rite and
   the Gravemarch polarity rule are built on the shared `BurdenResolver`
   (`NegArchetypesTest`, 62 checks); the spec is
   `docs/design/2026-09-19-neg-expansion-and-playtest-spec.md` and the
   measured study of all seven against the tree is
   `docs/design/2026-09-19-neg-archetypes-and-the-tree.md` (a relic costs a
   set slot; Doctrine is safe; the Lens is survivability; Luck is invisible
   to the tree; no global haste cap; the cursed Ballast Frame now capped).
3. **Build simulator**: `tools/tests/BuildSimulator.tscn` with campaigns,
   ablation, set, NEG-wardrobe and held-Q modes and the report scripts under
   `tools/sim/`; results under `docs/audits/2026-09-19-build-simulator/`.
   Balance revision 2 rode on it: continuous item curves, accessory
   effects, set scaling channels, merge progress and prices aligned with
   upgrade value (`ItemScaling`, `SetScaling`, `RarityMath`).
4. **Performance war room**: `docs/audits/2026-09-19-performance-war-room.md`
   with fresh horde numbers at 60 / 100 / 180 / 300, the plan M0-M7, and
   M1 and M3 built: every ground texture warmed at configure (the first
   plaza paid 25-31 ms per first-touch PNG), blocker physics and rendering
   staged over the queue steps after content (worst streaming step 33 ms
   to 8 ms headless), and every recorder hitch over 28 ms tagged with the
   subsystem behind it. `RoamStreamProbe`, `ChunkStagedBlockerTest`,
   `PerformanceHitchTaggerTest`. M0 (rendered) needs the display.
5. **Segment 1 design pass**: `docs/design/2026-09-19-segment-1-design-pass.md`.
6. **Enemy roster audit**: `docs/audits/2026-09-19-enemy-roster-audit.md`,
   eight findings, roster changes and five new enemies proposed, not built.
7. **Loot deep pass**: `docs/audits/2026-09-19-loot-loop-pass.md`, the loop
   invariants pinned by `LootLoopTest` (27 checks), proposals L1-L6 open.
8. **Run telemetry**: balance recorder revision 2 with `run_history.py`
   across captures; the human baseline capture is still owed.
9. **Break-the-game audit**: `docs/audits/2026-09-19-break-the-game-audit.md`;
   five fixed with tests (slow-motion leak at run end, the reconstruction
   survival rule shared by the Hub and the wager shrine, damaged saves
   normalized, autosave suppression released, the tree hotkey while dead).
10. **Vertical slice**: `docs/design/2026-09-19-vertical-slice-definition.md`,
    acceptance criteria A1-A10 with their measures and the playtest script.

Everything here is a headless result; the next human run with both
recorders on is what turns "built" into "verified".

## 2026-09-19, later — the audits acted on: loops closed, segment 1 decisions, the roster rebased, new enemies, VFX and terrain

Sixteen local commits (`ece47c9` … `b610947`), all headless-verified,
none pushed, none seen rendered; the full headless regression (144
test scenes) is green. What the audits proposed and this
stretch built:

- **Loot loops (L1-L6, P5, P6).** Refunds are Hub-only, return half the
  price through segment 2 and a tenth less per segment after, and sworn
  nodes (Revelations, forks, Unions, Axioms, Catastrophes) never refund;
  one rarity soft cap for every source, the vendor band and every wager
  tier riding it; a same-item equip that would dissolve a Manifestation
  swaps instead of feeding; items whose data is gone leave saves; the run
  RNG's state rides the save.
- **Segment 1 (S1-S3, S5, S6, S10).** Veterans get a blessed / cursed
  "take one" pair at the evidence store; the first augment offer carries
  a NEG archetype; the three service rooms pay Followers; a charger wedge
  after the security clear and a sniper pair at the checkpoint; the
  Sniper in the approach; six vendor offers at the first Hubs.
- **Roster (E1-E6, N1-N3, N5).** HP re-based to time-to-act, phase-gated
  unlocks with segment-scaled start times, weights toward specialists,
  rewards by durability, elite chances doubled, the Herald's pulse wards
  allies; three new enemies: the Warden (frontal shield, melee passes),
  the Chanter (mends and wards), the Lurker (charges the moment you
  stop), the Siphon (drinks Force, Momentum or Heat instead of
  Followers), each on the ambient table, three of them in authored beats.
- **NEG-versus-tree (T3, T4).** Luck bends named tree rolls by at most
  five points; the shot-rate multiplier caps at x2.5.
- **Assets.** Kenney's CC0 particle textures power a pooled burst layer
  (death, elite death, pickup, dash, cast; the hit spark is available,
  not wired); three CC0 terrains (meadow, scrub, moss) and per-theme
  vegetation and decal density, so segments 4-9 stop looking alike.
- **Performance.** Tag attribution memoized (M8's first step).

Not done from the audits: the Weaver (N4), the Siphon's placed-object
half, miniboss specialist pools (E7), the tree audit's 28 proposals (redesign deferred),
segment 1's S4 / S7-S9 / S11 (measure first), the rest of M8, M0
(display). Every number here is the audit's proposal; the human run with
both recorders on is still the gate.


## 2026-09-25/26 — the Ranged V5 handoff: five phases' cores, headless-verified

Executed from `Synthetic_Ascension_Claude_Handoff_2026-09-25.md` while the
user slept. Six local commits (`1e6ce14` … `1ebebd4`), none pushed (no
credentials in this session — one `git push` sends them all). Everything
below is a headless result; the rendered checks are listed as owed.

- **Ranged V5 (Phase 1).** `tree_v5_ranged.json` (generated + validated,
  V4 untouched and byte-verified against the handoff hash); ordinary local
  ranks with exact receipts, gates, Hub-only downgrades, cascades; Spin Up
  replaces baseline Heat (Hot Core optional, Meltdown never stops the gun);
  Grenadier replaces Caltrops (tap-Q instant, hold-Q places); Big One
  requires a true Shell producer; named burns with strongest-rate refresh
  and full provenance; foreign Witness adapters; Burst's ×2 rides after the
  ×2.5 cap as an explicit window (finding A, decision D-4); the projectile
  overflow queue retains player attacks at capacity (finding E). New
  suites: LedgerV5Rank 63, BarrageV5 37, OrdnanceV5 33, PrecisionV5 23,
  V5HybridForeign 26, ProjectileOverflow 11 — green; the V4 battery
  (Barrage 38 / Precision 47 / Ordnance 63 / Hybrid 41 / SharedRules 32 /
  Runner 29 / Screen 20 / Status 19 / Combat 38) unchanged and green.
  First matched V4/V5 simulator baseline (seeds 101/202/303):
  `docs/audits/2026-09-26-v5-sim-baseline.md` — B1 competitive without
  Heat, B2's risk pays, O1 strong, O2 flagged for density review.
- **Ranged visuals (Phase 2, first pass).** Twelve authored textures in
  the retrieved identity (needle/diamond gold-white Precision, tracer
  Barrage, round/spiked/reticle Ordnance silhouettes, true-radius Hot Core
  aura, Spin Up muzzle glow), integrated: shaped batched bullets, textured
  beams + needle-burst caps, fragment motes. Identity table recovered from
  the "JSON lasīšana" chat; the rest of that chat (and GPT asset
  generation) is blocked on browser-automation permissions — exact resume
  prompt in the decision log (B-1).
- **World shapes (Phase 3).** L-footprint parcels with recessed entrances
  on the real procedural path: footprint cells drive floor, perimeter
  walls, collision, two IndoorVolumes (one id, one loot owner) and a real
  outline-polygon roof; interiors stay open reachable halls. Shallow
  depth: authored south stone faces + slight cap lift in both render
  paths. WorldFootprintTest 10/10; world battery green.
- **Beka (Phase 4 first).** The approved memorial companion: a real
  absorbable shield (4 s / 4%/s / min(30%, 20%·S)) consumed before
  lethality, telemetry-distinct from HP loss; the 12 s / 320 u pulse pulls
  health to a wounded player with line of sight and highlights equipment
  without touching it; provisional tuxedo-cat art from the user's
  description; she sleeps while the shield regrows. BekaEffectTest 30/30
  (stable ×5). Existing-item audit: the eight curse relics were the only
  icon-less defs — authored and bound a consistent cursed-relic set.
  Remaining item ideas: statuses in
  `docs/design/2026-09-26-item-ideas-status.md`.
- **The hub (Phase 5).** `scenes/hub/HubWorld.tscn`: a walkable courtyard
  between segments — arrival→exit walk, recessed service bays, merchant /
  Ascension / gear / quiet alcove / exit gate stations; HubShop embeds as
  the trade panel (economy identical, no scene-level side effects);
  combat inputs disabled in the safe hub; departure single-fire and gated
  by pending mandatory choices; old shop-target saves route in; Beka
  sleeps in the alcove. HubWorldTest 19/19; save/economy battery green.

Owed to the next human run: rendered legibility (faces, VFX, hub) at
gameplay zoom, rank-purchase noticeability, the free-choice and
durable-target comparisons, Beka-vs-Offhands with the balance recorder,
and the §15.6 walkthrough capture. Parse audit finished at 425/425.

## 2026-10-03 — Bindings and Theses: augments and Doctrines above the tree

The user's call: with the Ascension tree in, augments and the choice
moments felt weak beside it. Read from code, they were: three augment picks
a run at most, payloads of `12 x k x (1 + Power)` that never grew with gear
while the tree pays in D, a Lv.5 clamp, and nine Doctrine plates that were
the same every run. Design, numbers and measurements:
`docs/design/2026-10-03-bindings-and-theses.md`.

- **The Binding.** An augment pick after every segment; graded cards
  (Etched / Gilded / Sanctified / Apocryphal, +1 to +4 levels, Luck shifts
  the grades), NEW / RANK UP / SWAP / TRANSCEND, a paid Recast and a paid
  Abstain, the offer kept in the save.
- **Potency.** Combat augments pay in D, +35% per level, levels to 20.
  Measured (AugmentPowerProbe, 40-dummy crowd): one augment is a fraction
  of the native weapon at Lv.1, one to three weapons at Lv.5, several at
  Lv.10.
- **Transcendence.** Sixteen Transcended forms, each with a catalyst
  (another augment, a stat, a tree discipline, a Doctrine family, curses,
  Followers): Storm Crown chains, Choir of Needles splits, Thousand Cuts
  casts itself, Brood Mother hatches from kills, Heart of Ruin, Twin Lens,
  Prophet and the rest.
- **Theses.** Eighteen plates (nine new: Second Hand, Iron Liturgy,
  Second Revelation, Tithe Ledger, The Engine Prays, ...), a weighted
  draw, Thesis / Canon bonuses for two / three of a family, Apocrypha
  stages every three segments after 9. Several plates now multiply the
  tree (Q recovery, Revelation charge, native hit count, node prices).
- **Fixed on the way.** An in-session restart kept the last run's
  Doctrine history, levels and stat delta (the next segment-3 offer could
  come back empty and hold the Hub); the Doctrine level grant clamped
  Lv.7 down to 5; Perfected Engine's consequence did nothing.

Six new suites (AugmentBinding 64, AugmentPotency 27,
AugmentTranscendence 64, DoctrineThesis 87, AttemptReset 18,
ChoiceCopyFit 182); the full headless battery is green apart from the
known PrimaryObjectiveTest and AscensionSliceCompletionTest's
hostile-bullet slow check, which fails about one run in four on a clean
HEAD worktree too. Godot itself crashed intermittently at start-up that
day (signal 11 / double free, clean HEAD included), so a crashed suite is
rerun before it is read as a failure. Owed: a rendered look at the Binding and the
plates (tools/dev/BindingShotProbe; rendered Godot crashed at start-up on
this session's display) and the first human run with it — whether three
Lv.5+ augments flatten segments 6–9 and whether Abstain is ever taken.

## 2026-10-03, later — Duos, Facets and the Reliquary

After the Bindings landed the user asked to build what was worth stealing
from other games. Design and the review record:
`docs/design/2026-10-03-duos-facets-and-the-reliquary.md`.

- **Duos** (Hades): six pairs of augments unlock a shared rule through a
  DUO card (Lightning Rods, Phantom Step, Static Brood, Bulwark Engine,
  Slipstream Coil, Loaded Dice).
- **Facets** (the Daedalus Hammer, support gems): each combat augment has
  two; a FACET card asks which.
- **Burdened Binding** (Neow, the devil's bargain): every card one grade
  up, for a cursed relic in the bag and +20 Threat.
- **The Reliquary** (a Hub screen): Corruption (Vaal), Transfusion
  (Inscryption's altar), Vouchers (Balatro) and the Grimoire, a
  profile-wide record of every Transcendence, Duo, Facet, Thesis and Canon
  reached.

Built as a shared core first (rules tables, Global flow, save fields), then
four parallel implementers with disjoint files, an adversarial reviewer
each, and a cross-cutting review with a skeptic per finding. The review
found a free-levels loop (library spare corrupted at Lv.1 and transfused;
corrupted donors are now refused), invulnerability chains on Reflect
Shield and Stamina Core (both floored), and a Burden lost to a Recast,
among smaller ones; all fixed and pinned. New suites: ReliquaryCore,
FacetDuoEffectsA/B, BindingRitesUi, ReliquaryScreen. Owed: a rendered look
and the first human run.

## 2026-10-14 — Augment strength and painted upgrade cards

Reviewed all sixteen base augments, six Duos, fourteen Facets and sixteen
Transcendences. Eight bases gained an earlier payoff: Missile, Slash,
Blink, Spiderlings, Corruption, Litany, Cult and Gambler. Slash, Blink and
spider damage no longer use tabletop dice; missiles reacquire living
targets, and Choir shards exclude the parent's victim through collision
and retargeting. The Run Sheet reports actual transformed curse and
recruitment formulas, including live HP and acquisition changes.

Replaced the shared portraits with 52 distinct illustrations in the
user-approved Magic Missile/Spirit Slash painted style: 16 base, 16
Transcendence, 14 Facet and 6 Duo. Game exports are 512px. Upgrade previews,
equipped icons, tooltips and reference screens resolve the appropriate
form; seven real card pages and all seven Facet choosers were rendered.
The detailed evidence, prompts and gallery are linked from
`docs/audits/2026-10-14-augment-pass.md`.

Focused verification: 21 suites, 3,488 passing checks, zero failed checks;
parse audit 507/507. The seeded immortal-crowd power probe completed.
These are implementation checks; a human encounter playtest remains due.
`docs/audits/2026-10-14-augment-combinations.md` records capped/weak rank
progression, inherited Crown/parry overlap concerns and targeted future
curse combinations. Those proposals have not been shipped as new rules.

## 2026-10-16 — First-city continuity and pacing prototype

The user's October 11 normal run reached its desired engine early and cleared
seven Rites without interruption. This pass makes a reversible city test,
with evidence and lore provenance in
`docs/audits/2026-10-16-city-continuity-and-pacing.md`.

- Fresh attempts save pacing revision 1: Revelations require completed S8,
  their mutations completed S9. Older ledgers keep their existing access.
  These thresholds are a design bet, not established optimums.
- Ordinary reconstruction keeps the attempt. Terminal defeat now leaves a
  durable PeeP decision, including through menu/quit/reload; acceptance
  closes the failed story once and begins one fresh city attempt.
- Discoveries, owned augment identities/preferences and exact Stash items
  endure. Carried gear, Followers, tree purchases and temporary augment
  development reset. Method/Doctrine/Apotheosis commitments endure as IDs
  and reactivate through their normal effects only after S3/S6/S9.
- PeeP's presentation uses short dialogue and the existing dark/gold theme,
  with an explicit retained/reset summary and small-window navigation.
  PeeP prevents death becoming final; creator and mechanism remain unchosen.
- Three independent developer launch flags test overtime drop probability,
  overtime rarity and strongest Gospel reward contributions. Defaults are
  off and captures record each selection. Gospel pressure and defiance stay
  intact; this is not a claim that unbounded farming is solved.

Segment 10 remains escape from Area I. Godhood and opposition outside the
city remain the longer direction; this pass adds no outside-city content.
A successful strong build should be allowed to leave. No forced death,
automatic enemy catch-up or increased population is introduced.

Verification: 21 relevant suites exited successfully; the final continuation
regression passed 92/0 and gameplay parse audit 509/0. AuditClosureTest
completed 93/0 but has a native teardown crash/resource-leak failure also
reproduced at pre-change commit629f941. It is recorded as an existing
limitation, not a clean pass. Five actual UI captures were inspected;
independent reviews and the final scoped correction review are approved.
Human playtesting is still owed for emotional continuity, late-city
purchase satisfaction and matched fresh-versus-stocked farming comparisons.

## 2026-10-16 — Pause, save and return to the main menu

Gameplay and the hub now share a pause menu: Resume, Settings, Main Menu
and Quit. Escape, controller B or the lower-right Pause button opens it; D-pad
navigation and A confirmation use shared UI defaults. Existing gameplay
bindings and remapped keys retain their own actions.

Leaving asks for confirmation and saves the current attempt. Continue
returns to the existing Wardstone or segment start, or to the hub when
leaving there. Gear, wallet, pending choices and the vendor snapshot use
the existing save; leaving creates no death, new attempt or checkpoint.
The world stays paused through the menu transition. Closing Settings or
a confirmation returns to pause, and Resume restores any prior mandatory
choice and its pause ownership.

Verification and limits are recorded in
`docs/audits/evidence/2026-10-16-pause-menu/verification.json`. The real
rendered pause/save/Continue regression passed 38/0, including conflicting
custom bindings and native controller events. Normal and small-window
captures are in `docs/art/reference/2026-10-16-pause-menu/`. Actual hardware
controller use and terminating the application through Quit remain manual
checks; Quit confirmation/cancellation is covered automatically.

## 2026-10-16 — Combat cues and durable Rite completion

Autonomous work while the user was away focused on existing combat feedback
and run reliability:

- **Reflect Shield:** perfect refunds, live rank/Facet refreshes and Mirror
  Aegis/manual casts now retain the actual protection window plus the
  existing 0.1-second recovery gap. Long cooldowns can still be refunded;
  reflections, perfect zaps and Bulwark retain their effects.
- **Rite completion:** Game saves completion intent before the release or
  story card awaits. Loading settles it once after the full build loads,
  with the next Hub, Binding/Doctrine/Evolution rewards and story state in
  one snapshot. Terminal continuation takes precedence; stale markers and
  new attempts cannot replay the completion. Ordinary pause/save/Continue
  behavior is preserved.
- **Dash and injury:** two sourced Kenney CC0 recordings supply a quiet
  positional dash cue and a non-positional cue for actual HP loss, limited
  to once per 220 ms. Absorption, evasion, invulnerability and intentional
  HP payments stay silent. Both use the existing SFX settings; exact source
  files, licenses and hashes are in `assets/audio/sfx/actions/`.

Source commits: `b89aa9a`, `339acbb`, `68bb8c7`. Verification: 18 relevant
suites, 1,900 reported passing checks, zero failed checks and successful
process exits throughout; final gameplay parse audit 510/0. New regressions
were observed failing before fixes. Additional recovery checks cover
remembered commitments, unselected-slot isolation and zero-marker legacy
saves. Independent code review found no actionable P1/P2 issues. Exact
commands, source hashes, run results and expected fixture warnings are in
`docs/audits/evidence/2026-10-16-overnight/verification.json`.

The audio was prepared and checked silently; its final mix needs a human
listen. The existing Stamina Core live-refresh cooldown clamp is recorded
as an unverified follow-up in the augment-combinations audit, not changed
as part of this Shield repair. Existing unrelated working edits were
preserved and excluded from these commits.

## 2026-10-16 — Elite edge highlight and glint

All elites now have a steady gold/ivory inside edge and a slow diagonal sheen,
with a lighter body-colour wash so the original character art remains visible.
The shared renderer separates elite surfaces from ordinary texture peers;
fallback sprites use the same effect, including animated regions and role
atlases. Reduced motion keeps the steady edge and stops the glint. Existing
hit feedback and shadow silhouettes are preserved.

Modifier marks follow the actual body renderer's depth: shield fields, plates
and trails stay behind the body; splitting seams and vampiric inner rings draw
in front. This includes the live proxy root's z=10 layer and fallback scenes.
`tools/dev/EliteSheenPreview.tscn` compares ordinary, former tint and new elite
appearances at native and enlarged sizes, plus modifier examples. The actual
rendered PNG, animated GIF and verification record are in
`docs/art/reference/2026-10-16-elite-sheen/`.

Verification: seven focused suites/audits, 900 reported passing checks and no
failed checks in the final runs, including real rendered-pixel assertions and
the 510-script audit. One concurrent run missed the existing 50ms upload pin;
the isolated final renderer run passed, with a 4.261ms final upload. Independent
review and the depth-correction re-review found no remaining P1/P2 issues.
Dense human combat playtesting is still needed to tune brightness/readability.

## 2026-10-16 — Elite modifier art and palette follow-up (visual review)

The second pass replaces the five modifier tells with dedicated transparent
ImageGen art: steel plates, a red fang ring, a cyan ward, a lime fissure and
a pale-yellow wind ribbon. The first modifier now controls the edge/glint
colour; other marks retain their own colours. Vampiric brightness preserves
the dominant hue, and FAST keeps a static ribbon between movements. Reduced
motion retains static tells, including correct expiry of the blood-feed flash.

Actual rendered 1.8× animation and native-scale stills are recorded in
`docs/art/reference/2026-10-16-elite-modifiers/`, alongside verification and
capture diagnostics. Source art and exact prompts are in
`assets/textures/vfx/elites/`. The shield retains its real 180px world radius.

Six focused suites/audits passed 726 checks, including rendered-pixel colour
and art tests and the final 513-script audit. Scoped independent review found
no actionable P1/P2 issues. The native fissure and mixed red ring remain finer
than the shield and wind ribbon; dense combat still needs human review.
The user approved the preview and requested a separate commit and push for
this pass. The first gold/ivory pass was committed and pushed separately.

## 2026-10-16 — Crowded elite fight and feedback corrections

The elite tells were checked in a live seeded Game scene with 48 enemies,
including ten elites and double/triple modifier stress cases. Production
terrain, HUD, native camera, player attacks, AI, projectiles and deaths stay
active; controlled spawning and player god mode make the test repeatable.
The triple is forced beyond normal collapse's two-modifier roll. The clean
run recorded 46 attacks, 55 hits and 17 deaths, including two elites, with
zero save writes or runtime errors. Native PNGs, a silent MP4 and telemetry
are in `docs/art/reference/2026-10-16-elite-crowd-fight/`.

Wards, wind ribbons and coloured edges remain clear. The secondary red ring
and body seams are subtler during tight overlaps/impact flashes; this is a
readability check, not a difficulty or performance benchmark.

Three verified corrections accompany the review: existing elite marks now
honour live Reduced Motion changes; elite death bursts retain a small
independent per-frame allowance when fodder dies in the same attack; and
objective hums emit at the owner's origin instead of applying its transform
twice. Focused regressions failed before each fix. Seven final suites/audits
passed 752 checks, including real rendered art and the final 514-script
audit; independent scoped review found no P1/P2 issues. The user approved
the crowded fight preview and fixes and requested a separate commit and push.

## 2026-10-16 — Secondary elite tells and illustrated combat text

Secondary Vampiric rings now retain a stronger red collar through their dim
pulse, with a dark separation edge. Splitting seams extend wider across and
beyond the body with a dark underlay. The first modifier still controls the
sheen; reduced motion and the blood-feed flash remain supported.

Floating damage figures and named messages use the HUD's Cinzel figure and
caption faces. Top-centre teaching alerts use the matching caption face too.
Five dedicated transparent ImageGen badges accompany modifier announcements
and their first-sight teaching alerts. Explicit modifier IDs select artwork;
ordinary tips and damage numbers remain clear. The shared badge API supports
future named effects without adding new status application messages here.
Each modifier name in a mixed announcement retains its own original tell
colour, with neutral separators and the existing independently coloured badges.
A discovered merge-key collision between damage and named text was corrected
so a numeric hit cannot absorb a named message or inherit its badges.

The native live crowded fight, controlled six-actor before/after screenshots,
enlarged comparison and verification record are in
`docs/art/reference/2026-10-16-elite-readability/`. Generated sources and exact
prompts are in `assets/textures/ui/combat_status/`. The live capture records
48 initial enemies, ten elites and a forced triple-modifier example, with
zero save writes, capture failures, runtime errors or warnings. It preserves
measured wall-clock timing and is a readability review, not a benchmark.

Seven final suites/audits passed 801 checks, including actual rendered pixel,
font, badge and per-name colour assertions and the final 518-script audit. Regressions failed
before fixes; independent scoped review found no actionable P1/P2 issues.
The user approved the preview and requested this pass be committed and pushed,
including per-name modifier colours without a further visual approval step.

## 2026-10-16 — Boss proportions, clear courts and raster effects

The approved second boss delivery step now has four distinct S5/S10 rough
forms beside all player races at gameplay zoom. Anatomy is fitted separately
from equipment: Bulldozer 88 world px in both tiers, Arcanist 82/86, compared
with the human's 77 px occupied height. Unit actor roots replace enlarged
generic bodies, while private walking/contact shapes preserve existing world
sizes and the authoritative enemy record stays synchronized. These are
single-pose studies for review; finished animation and human art approval
remain pending.

Procedural S5/S10 courts reserve 20/28-cell squares before blockers and
dressing, with one shared fixed encounter center and open street access.
The arena regression passes 728 checks across 88 chunks and 40 seeds; the
existing reachability suite checks 3840 chunks with no failures. This does
not guarantee space beyond the court or full visibility of long attacks
from every player-camera position.

Dedicated transparent raster sprites distinguish slam fractures, branching
shock crackles, planted mines, charge arrows and casting accents. The beam
loses its dark rectangular backing. Pulse and Bomber receive finer sprites
while retaining their existing clocks, pooling and damage geometry. Current
boss sound mappings replace the rejected initial electronic/ping selection
with recorded thuds, air and electrical material, including a shorter mine
blast. Exact clips, triggers and credits are in
`assets/audio/sfx/bosses/CREDITS.md`; final mix weight needs human listening.

Actual Game scale, court and effect captures, tests, source hashes and review
limits are linked from `docs/audits/2026-10-16-boss-step2.md` and
`docs/art/2026-10-16-boss-step2-assets.md`. Captures use isolated profiles and
record zero save writes. Frozen samples establish art presence and fit;
they do not establish motion quality, dense-fight readability or balance.
The random S10 boss choice remains. S5 teaching kits, new S10 phase kits,
entrance/music/HUD and durable reward settlement remain later steps.

## 2026-10-16 — Existing combat statuses: badges and coloured captions

The illustrated combat-text treatment now covers 21 existing status identities
across enemy conditions, ascension disciplines and Manifestations. Dedicated
transparent ImageGen badges share the established brass/charcoal style. Each
name keeps its semantic colour, including mixed rows; the two Mark systems
have distinct red and violet artwork. Debt keeps its amount/countdown world
marker, now with the HUD caption font and its own badge. The existing healing
seal lesson uses the matching illustrated alert.

New application captions share a bounded gate: eight per process frame,
1.5 seconds per target/effect and at most 512 cached targets. Refreshes and
damage ticks stay quiet. Prime and Cracked regressions distinguish an active
refresh from consumption/reapplication. Existing magnitudes, durations,
charges and expiry behaviour are preserved.

Three native catalogue pages show all 21 identities through production text
renderers, including the persistent Debt path. Floating catalogue samples
use 1.35× emphasis; the live fight uses the actual gameplay paths and scales.
The 48-enemy capture retains ten elites and double/triple modifier stress
cases, with scripted real status applications, native attacks, AI and deaths.
Its 10 simulation seconds recorded 47 attacks, 90 hits and 21 deaths, with
zero save writes or capture failures. The silent MP4 retains measured sample
timing. This is a visual review, not all-build or performance verification.

Artwork, prompts, native media and test logs are linked from
`docs/art/2026-10-16-combat-status-assets.md` and
`docs/art/reference/2026-10-16-combat-status/`. Native text checks pass 87/0,
column checks 41/0 and final application/refresh checks 22/0; initial fixture
diagnostics are retained separately. Shared runtime-safety checks pass 21/0
and the final parse audit passes all 530 gameplay scripts. Nine focused
suites/audits report 792 passing checks with no failures. The user approved
the preview and requested a separate commit and push for this pass.


## 2026-10-16 — Cumulative city Development and conditional Binding Echo

The first-city prototype awards one Research for each genuinely first profile clear of segments 1–10. One purchase selects one rank from health, armor, carrying space, augment training, Haste, movement speed, Luck, Power, native attack reach, native attack size or Binding Echo. Earlier purchases accumulate. Every rank costs one point; ten city points cannot buy the whole catalogue. Death, reconstruction, Followers and repeated clears award no Research.

Purchases prepare the next attempt through a saved snapshot. Continue and reconstruction retain their original snapshot; training can be retargeted for a later attempt. The trained starting level cannot be donated repeatedly through transfusion. Loaded bags retain their capacity and occupied tail. Binding Echo is the first conditional meta choice: purchase it, then complete S5 in a future attempt to take two sequential ordinary Binding rewards. Its saved queue survives reload and duplicate settlement cannot create another reward. Temporary results still reset at true defeat.

Development is available from the main menu, base and merchant. The current and next-attempt distinction is explicit, with keyboard/controller checks and native normal/small-window captures. The existing completed-S8 Revelation and S9 mutation gates remain. Controlled real-mechanics comparisons and an independent no-development flag support subsequent city tests; they do not establish full-city pacing or eliminate existing Stash/reward farming. See `docs/audits/2026-10-16-city-development.md` for exact values, evidence and the remaining human playtest. This bounded city allocation does not define the eventual godhood ceiling.

## 2026-10-16 — Painted opening, PeeP and optional city papers

The approved opening now uses four stills in the selected unfinished painted
style: the working city, admission, stable synthesis and the records-conduit
departure. The existing playable actions, phase numbers and full/short/skip
modes remain. Three approved short additions connect the ordinary shift,
Bren's preservation of the intervals and the original pages leaving the lab.
Cards support small-window scrolling and defer input to the shared pause menu.

PeeP presents the full first conversation once, a compact return encounter and
an optional replay. Its seen memory is saved independently of accepting a new
attempt. Menu and quit retain the pending decision; acceptance starts exactly
one fresh attempt. Prepare next attempt opens the shared lasting-development
screen before acceptance. The summary names retained development and unspent
Research, and distinguishes temporary growth from the prepared foundation.
The scene adds a static rough page-corner mark without settling PeeP's form,
creator or mechanism.

Eight approved source documents supplement the existing nineteen Chronicles.
The Papers tray beside the Quiet Alcove offers copies as city progress makes
them available. Inspecting does not collect; Keep a copy saves one unread
Library entry. Existing full-text search, reading and bookmarks remain in use.
No paper requires death, Followers, random dialogue or repeated boss kills.

All eight texts use the safe hub recovery route in this pass. Five proposed
physical placements remain deferred: admission desk, S2 service notice board,
S4 washhouse/basket, S6 shelter door and S10 gatehouse shelf. Their sealed
Library clues point to the implemented tray and correct progress gates.

Focused input/save/hub/Library checks, the corrected Reliquary catalogue check
and the shared 530-script audit passed. All thirty actual UI captures were
inspected across normal/small windows and Reduced Motion. Audits are in
`docs/audits/2026-10-16-painted-opening.md`, `2026-10-16-peep-encounter.md` and
`2026-10-16-city-lore.md`. Human pacing and final sound remain review work;
the opening still uses existing audio cues.


## 2026-10-16 — Segment 5 teaching boss fights

The third boss delivery gives Bulldozer a committed physical rush, planted impact, fully previewed three-node Fault Line and one warned finite Runner call below half health. Arcanist uses a locked five-bolt fan, announced validated blink and deterministic three-mine pattern with a checked full-Hurtbox escape corridor. Commitments/recovery use gameplay physics time, retreat is bounded, and seeded random choice, production maximum health and rewards remain.

Dedicated raster sprites distinguish blink destinations and Runner arrivals. Actual paired Game controls cover walking, separate native dashes, recovery melee, court-edge escape and genuine kill-trigger access. The original matrix remains RED for two corrected Runner attribution checks; focused follow-ups, 99 continuation checks and five compatibility suites pass. A native lethal-hazard cleanup error found by the controls now pauses immediately and defers collision disabling safely. The audit retains exact source/log identities and limitations.

Four normal/small-window clips show the sprite cues in the actual court/HUD using clearly labelled immortal playback; actual-damage controls are separate. Ordinary body contact remains active outside the Tank's committed states and remains a separate cost for Mage. Dense human readability, slowed builds, pacing, finished character animation and final mix still need playtesting. S10 phase kits and later entrance/music/HUD/reward presentation remain later deliveries. See `docs/audits/2026-10-16-s5-teaching-fights.md`.


## 2026-10-17 — Pull review and Segment 10 main-boss kits

The 48 pulled commits were reviewed by area. Twenty-nine follow-ups fix what the review confirmed:

- a library pagination freeze, and a pause that could stay frozen under a closing Binding;
- a completion that stranded the player, deaths recorded as quits, and an erased chronicle that could be rewritten;
- a repeatable free Binding grant, Reliquary level reports, and doorless carved buildings;
- input and HUD details in the opening, hub and pause menu, and two S5 boss edges;
- six performance passes (the shadow and page-turn ones verified bit- and pixel-identical), and five suites aligned with deliberate changes.

Both S10 bosses now run three phases at 65% / 30%. Phases only advance, with a short damageable phase beat; tells never shorten and cooldowns tighten by tempo.

- **Bulldozer:** Sweeping Cleave and one warned Runner call in phase 2, then a Breach Sequence and a fully previewed Fault Line follow-up in phase 3.
- **Arcanist:** a Split Fan with a drawn gap, a rebuilt Arc Sweep showing its start and end lanes, and one Pylon Pair in phase 2. Phase 3 adds a Convergence Sequence, a four-node mine arc and a fresh pair. Pylons hold fire through each major pattern and the recovery after it and fire in a neutral beat between them; bolts they still have in the air join the next pattern's walk-out check.

A walk-out oracle commits a main-boss attack only when a walk the player can keep up still escapes it: its stat speed under the slows it cannot shed at will, capped at 100 px/s, the eight keyboard directions, and the real Hurtbox and body turned as the player turns; nothing is certified while the player dashes. Mine patterns keep a checked corridor that never leads into the boss. The arenas' movement tuning now reaches movement. Projectile batches now pay a boss's damage cap and an elite's plate hit by hit, exactly as separate hits. The S10 boss bar shows phase marks, and each role has its own entrance line.

Staged captures in the actual Game at segment 10 show every new telegraph. Actual-Game controls on two seeds pair a stationary control with a walk for each new S10 attack: 14 pairs. Every walk draws no boss damage attempt, along the oracle's route (the mine arc: its committed corridor), and every stationary control is struck except the mine arc's, whose centre is safe by design.

A second review, three verifiers per finding, confirmed 49 findings across this work and the pull-review fixes, and all are fixed: the oracle reworked as above, a committed rush that keeps its lane and spares a player behind it, pylons held through recoveries, arena clears kept through Continue, a developer run's Doctrine never imported as a commitment, and a dozen boss checks that now fail under the faults they name. A third review of those fixes found more, and a fourth review of the third round more again, all fixed. The oracle refused every walk for a player against a real wall (the first fix reached only its physics half), carried a dash through the boss, let a held guard pacify the Bulldozer and a passing boost hide a slow. A resumed developer attempt claimed Research and wrote commitments, a restored clear and any segment rebuilt at the same number kept the wrong threat pressure, console jumps left fights settled, and several checks still could not fail. A fifth review of those fixes found more, all fixed: the walk-out check now judges a player meeting the boss both stopped and sliding (the body is Godot's grounded kind), starts walks where the turned body settles beside a wall, lets a player beside a wall run's end walk, and leaves out a Burst the player can cancel; console jumps start their segment afresh. The game now opens on its own logo and icon instead of Godot's, the saved window state no longer flashes undrawn window over that splash, and the opening's stills paint in over the world and wash out to it in brush strokes.

A human playtest, music, portraits and the boss reward floor/settlement remain. See `docs/audits/2026-10-17-pull-review-and-s10-boss-kits.md`.

## 2026-10-18 — Boss delivery completed for human playtesting

The remaining implementation now includes the three-phase main-boss score, dedicated phase and defeat/release cues, warning-priority music ducking, phase equipment treatment and feet-anchored anticipation/recovery acting. Following the user's portrait correction, four coherent S5/S10 role icons now match the established world forms. Whole-form raster acting preserves collision geometry and supports Reduced Motion; this is not a new animation frame sheet.

S5/S10 now guarantee their existing configured item requests. A durable encounter settlement saves the complete payout and actual rolled items once, and pending loot recovers on Continue, Hub entry or segment handoff even after a full-bag failure. Completed objective/Resonance sources and Rite safeguards persist without being paid twice. Legacy clear-only saves retain their clear without gaining retrospective items.

Slow S5 players receive a captured longer slam warning. Arcanist mine/blink routes beside walls use the real turned body, keep full-Hurtbox hazard clearance and can choose a finite inward mine arc. Held Encore guard and Compel repeats now finish, preserve their selected action and retain scaling in delayed Q payloads without restarting recovery. The shared loading card also has a gold spinner, explicit loading label, compact layout and a static Reduced Motion treatment.

Focused audio, persistence, presentation, combat and UI suites pass. Actual Game controls cover both roles and three S10 seeds (84 case results, 438 passing checks), plus S5's two-seed controls and separate three-seed 80 px/s slam controls. Final native rendering is clean and isolated; the last audit compiles all 535 gameplay scripts. Evidence and exact limits are in [the completion audit](audits/2026-10-18-boss-delivery-completion.md), including source records and refreshed normal/small-window captures.

Human assessment remains: busy-fight readability, audible mix and animation weight, build/role balance and full-city/Rite pacing. No HP or damage retuning is inferred from synthetic controls. The deliberately omitted debris/fan additions and the separately documented developer-profile behavior remain outside this delivery.

## 2026-10-18 — Playtest feedback presentation and loading pass

Development now opens from a fresh restart, choosing a readable profile or presenting profile creation. Threaded resource loading and staged HUD/world construction keep the wait cue advancing through real work; explicit routed-entry ownership preserves direct-scene behavior, terminal priority, cancellation and caller pauses.

Deadshot/Judgment and the Wardstone, Exit Rite, Relay, Vigil, Breach and Wager presentation now use coherent painted forms, real boundaries and bounded effects. Hub camera buttons are removed; interaction focus, wheel zoom and outlined native cursors remain. S5 gains its missing score, both boss tiers gain stronger accepted-action/recovery acting and defeat treatment, and major audio cues have protected voices and corrected gain staging.

The latest reports led to a duplicate boss-form initialization fix, an exact derived ground array, corrected segment/loading clocks and retained incoming projectile ancestry. Recorder revision is now 3; combat numbers were not retuned from the single prepared-build session. Functional checks and all 539 gameplay script parses pass. Some native frame-time diagnostics still fail at occasional 440–500 ms stalls; their cause remains unresolved. Human mix/readability and full-run balance remain playtest work. See [the feedback delivery audit](audits/2026-10-18-playtest-feedback-delivery.md) for evidence and exact limits.

## 2026-10-18 — Objective visual review implemented

The first objective art pass was rejected for poor centering and terrain fit.
The approved replacement now uses explicit footprint/base anchors, muted city
stone and iron, quiet exact boundaries and physical state changes. Breaches are
three real ruptures that become filled caps; Relay shutters cover actual lenses;
Vigil is an embedded plate; Wardstones engage their bases; Rites use an overhead
threshold with separate durable thirds and safeguard shields; Wager closes its
collection tray. Closed/open vaults, Last Chance costs, real building/cache
rewards and corpse-return hazard cues complete the reviewed objective scope.

Exact production checks also fixed tagged-cache placement running before chunk
registration and released hardware cursor textures at shutdown. Hold times,
costs, combat numbers, spawning and rewards were preserved. Final native sessions
produced 69 controlled images with zero failures/save writes and clean shutdown;
independent reviewers inspected all 69 and found no blocking visual issue.
Focused checks and all 539 gameplay script parses pass. Human moving-fight
readability and discovery remain playtest work. See the [rework audit and previews](audits/2026-10-18-objective-visual-rework.md)
for state provenance, review limits and the previously unresolved loading stalls.

## 2026-10-18 — First playable city block ready for visual review

Segment 2's existing searchable-building block now has a small original
Mediterranean / medieval / municipal-industrial kit: a shallow civic arcade,
shuttered house frontage, quieter slate and terracotta roofs, practical service
plant, clipped limestone frontage paving and restrained planting. Actual parcel
footprints, door gaps, collision, local security/rewards and roof entry/exit
ownership remain. Tall frontage cuts away with the roof; wall geometry continues
through the shared renderer. Other city blocks retain their existing art.

Four isolated native runs cover normal/small windows, Reduced Motion with Combat
Flashes Off, and an original-art control. All complete physical perimeter/alley
traversal, real interior entry/security clearance/exit, streamed regeneration and
a populated moving outside fight. The final runs report zero failures/save writes
and clean native exits; before/after videos, source hashes and explicit god-mode /
scripted-input limits are retained. Focused checks pass and all 540 gameplay
scripts parse. No combat/balance/save-rule retuning or Git publication occurred.

This is one bounded playable example, with painted fronts currently supporting
south-facing doors. It is ready for human aesthetic/readability review rather
than whole-city rollout; compound roof silhouettes, broader directional coverage
and the previously reported loading stalls remain later work. See the
[first-block audit and native review media](audits/2026-10-18-first-city-block.md).

## 2026-10-18 — City-block designer corrections and roof concealment

The first art iteration required rework. The art chat subsequently cleared the
revised architectural shape: taller occupied arcade, connected pitched roof
forms, distinct domestic roof, quieter material hierarchy, continuous block
paving and purposeful service/planting groups. This supersedes the initial
static rejection for this bounded block; whole-city rollout remains outside it.
Three fresh normal/small/reduced native runs pass, with 467 captured frames.

User follow-up reduces the default hardware cursor by 35%, retaining enlarged
accessibility sizes and aligned hotspots. Roof-covered player pixels now show
a restrained cool translucent silhouette; exposed parts and indoor cutaways keep
normal art. Depth classification handles recessed wings and courtyard spans.
The designer cleared the staged shadow treatment and both compact/enlarged
cursor previews. One further final-source native moving run passes physical
entry/exit, streamed reload and populated combat with zero failures/save writes
or diagnostics. Roof-mask tests pass 11, animation 163, actor-depth/shadows 38,
and all 542 gameplay scripts parse. Human continuous-motion comfort and crowded
player recovery remain separate from sampled-image approval. No balance/save
retuning or Git publication occurred. See the updated
[audit, versioned evidence and designer verdicts](audits/2026-10-18-first-city-block.md).

## 2026-10-18 — Procedural kit checks and designer-led city refinement

Following the user's request to continue with the art chat, the bounded block
receives a thinner domestic eave, shallow entrance contact/flush worn thresholds,
a coherent aged-copper plant-to-drain connection, and one wall-mounted civic
records group. Its corrected opaque ledger faces sit above masonry fills and
below the roof, and dressing is omitted if a real north doorway would conflict.
The art chat cleared all four relationships at small native size.

The user's chimney correction replaces clean pale boxes with role-specific civic
coping/flue and domestic clay-pot assemblies, roof flashing and short shadows.
The shared helper derives placement from the generated supporting roof polygon,
clears ridges/eaves and skips unsafe spans. The designer cleared the shown
original and generated placement/cutaway states. Five native generated-layout
inspection views include horizontal/vertical streets, cross, L and T junctions;
curb openings now follow only road arms actually reaching that edge.

The procedural sweep covers four seeds and five road layouts: 20 distinct
layouts, 76 parcels and 75 styled rectangular instances across 22 sizes, with all
four entrance directions. Its 2,685 checks preserve geometry, actual doors,
identities, deterministic regeneration and open road connections. Kit checks
pass 1,112; roof-mask checks pass 11; all 542 gameplay scripts parse. A final
post-chimney small native Game run passes traversal, entry/security clearance/
exit, streamed reload and populated combat without failures, diagnostics or save
writes. No balance/save-rule changes or Git publication occurred.

This validates a parametric prototype, not finished procedural art coverage:
painted detailed fronts remain south-facing, irregular footprints retain existing
art, and rollout is still limited to the S2 example role. Multi-facing frontage
and irregular-family coverage remain explicit next steps. Sampled art approval
does not certify human continuous-motion comfort or performance. See the
[refinement audit and versioned native evidence](audits/2026-10-18-first-city-block.md).

## 2026-10-19 — Procedural streetscape and original city dressing

The S2 prototype now separates quieter worn street setts from limestone
frontages, with broad asymmetric paved width, open generated road connectors,
broken shallow curbs and localized soil/growth/repair groups. Shared southwest
building and foliage shadows, a deeper civic entry and an actually mounted
outlet over a flush catch drain give the block more physical depth. No road,
door, collision, objective, balance or save rules changed.

Following the user's stronger visual direction in the art chat, five original
assets are integrated: temperate tree, ivy/stone planter, one domestic awning,
shielded entry lantern and worn setts. Measured roots/mounts and span checks keep
them tied to real generated geometry; mounted art follows the actual cutaway,
while outdoor foliage remains. Source images, exact generation prompts and
anchors are retained. The designer cleared the combined shown scene, one
generated L layout and sampled inside/outside combat, with explicit sampled-review
limits and the existing crowded-player recovery limit retained.

The square road-edge discontinuity was traced with native ownership captures:
replacing floating sine hashing with integer lattice hashing changes the
maximum sampled adjacent-column jump from 18 pixels to one at both window sizes.
Final checks pass 1,118 for the kit, 4,326 across 20 generated layouts (22 parcel
sizes/all four entrances), and all 542 gameplay script parses. The final native
small-window moving run passes perimeter traversal, entry/security/exit, streamed
reload and populated combat: 150 frames, 61 fires/61 hits/28 deaths, clean exit,
zero failures/diagnostics/save writes. Current source hashes and measured-timing
videos are preserved and both videos decode cleanly.

This is a materially richer reusable block family, not whole-city rollout or a
new organic city topology. Detailed non-south/irregular art coverage, human
continuous-play comfort and packed-export/performance validation remain separate.
See the [street/ground audit and native review evidence](audits/2026-10-18-city-ground.md).

## 2026-10-19 — Actual city generation inspection and corrections

Actual Game inspection across attempt seeds 16102026 and 211 and five production
roles exposed the gap between the example block and the broader S2 city. Shared
S2 ground now carries the quieter original setts/limestone and subdued soil/grass
treatment through existing organic coverage. Road/access material joins no longer
read as overlapping dark patches; legacy S2 roof texture contrast is reduced.
Composed block paving is clipped to its owning chunk and fades into shared
ground, fixing overdraw into uninspected neighboring interiors.

Seed 211 also genuinely omitted a planned searchable building: courtyard access
crossed the full-depth frontage bands. Only when required placement fails, a
smaller workshop now fits within a safe part of the same band, using the standard
door/interior/keepout path. Actual-plan checks verify the objective and reachable
entry in four plans. The broader route suite passes 3,840 chunks, 2,538 doors and
1,728 reward placements; the kit passes 1,118 checks, its 20-layout sweep 4,580,
and all 542 gameplay scripts parse. Ground ownership/streaming and S2 switching
checks pass cleanly.

A fresh native seed-211 run passes perimeter movement, real entry/security/exit,
roof restoration, streamed regeneration and populated combat: 145 frames, 61
fires/60 hits/29 deaths, no failures, diagnostics or save writes. An earlier
scripted attempt to walk through live guards before fighting remains failed
evidence; the corrected check stops just inside the actual threshold. Collision
and encounter rules remain active. Current source/asset hashes are retained.

The art chat keeps the corrected junctions, ground boundary and visible repaired
building. Whole-city concept fidelity still needs work: non-south/irregular
frontages, connected neighboring building groups, broader depth/shadows and
organized mature planting remain visibly incomplete. No new assets, whole-city
topology rewrite or balance/save retuning were performed. See the
[actual-generation audit](audits/2026-10-19-actual-city-generation.md) and
[designer's sampled review](art/reviews/2026-10-19-production-city-generation-designer-review.md).

## 2026-10-19 — Procedural civic and domestic neighborhood coverage

The accepted civic arcade and inhabited domestic families now extend through S2
street parcels and courtyard fill. Visible south wall depth is independent of
entrance direction: north/east/west entrances retain upright closed frontage
bays and receive recess/contact geometry at their real openings. Compound roof
faces preserve doorway notches. Irregular buildings keep their actual L/recess
silhouette, with roof setbacks and wall bays following exposed footprint edges;
bounding-box awnings and replacement interior floors are omitted there.

Ambient workshops receive a stable occasional civic identity; domestic planting
adds measured tree/stone groups on eligible blocked corners. Service plant and
drain stay on the same wall, away from east entrances. Original textures are
shared across streamed instances, including the raw-source fallback. New roles
retain the existing shared organic ground; the reviewed prototype's composed
paving remains local to its original role. No physical footprint, security,
reward, combat, balance or save-rule changes were made.

Independent code review identified an inherited irregular north/east even-width
door-record offset. Its presentation anchor now matches the already carved
cells, with a regression covering every declared opening cell in all four
directions. Kit checks pass 1,257; the 20-layout sweep passes 5,430 across all 76
parcels, including the irregular parcel. Four actual plans exercise 20 production
chunks and 60 styled buildings, both families and all four entrance directions.
The required searchable-building, protected access, ground, roof occlusion and
3,840-chunk reachability checks remain clean; all 543 gameplay scripts parse.

Fresh production Game captures cover attempt seeds 16102026 and 211: 48 normal/
small role and directional stills, including irregular buildings. Two native
moving runs cover normal and small Reduced Motion/Combat Flashes Off windows.
Both pass physical perimeter movement, entry/security clearance/exit, roof
restoration, streamed reload and populated outside combat: 291 recorded frames,
zero failures, diagnostics or save writes, and all 40 source/asset hashes match
in each run. Scripted input and god mode remain explicit fixture limits.

The implementation and personally inspected native samples are ready for the
coordinating designer's review; these checks do not confer new aesthetic or
human continuous-play approval. Earlier visual iterations are preserved and
marked superseded in the [versioned verification record](art/reference/2026-10-19-city-neighborhood-v1/checks.json).

## 2026-10-19 — House wall continuity correction, review pending

Irregular parcel walls now join inward corners cardinally, closing the diagonal
holes and reconnecting bars beside recessed entrances. Declared door cells stay
open. The original window-roll sequence is retained so the repair does not
change later parcel choices. Ordinary and irregular parcel walls carry an intact
building flag, preserving existing roof/material bits while avoiding broken ruin
sections and raised piers. Real interior partitions remain in place.

Fresh checks pass: 1,298 kit assertions; 5,430 procedural assertions across 76
parcels; 60 actual buildings in 20 chunks; blocker data/rendering/physics; roof
occlusion; 3,840-chunk reachability; and 543 script parses. The unchanged chunk
integration fixture passes 64 assertions with its established missing-player
warning, recorded separately rather than treated as a clean production run.

Both reviewed irregular houses have fresh native exterior/physical-entry/exit
captures at 1280×720 and 960×540: 12 images, zero failures, diagnostics or save
writes. A current-code reduced-motion native route also passes perimeter travel,
five-guard clearance, roof restoration and streamed reload: 148 recorded frames,
62 weapon fires, 61 hits and 29 deaths, zero failures/diagnostics/save writes.
All 40 captured source/asset hashes match. Scripted input, god mode and controlled
outside combat remain explicit fixture limits.

The ordinary rectangular cutaway retains actual inner room-boundary runs near
the perimeter. That remaining double-wall appearance is explicitly a visual
review item; this correction does not claim it resolved every reported interior
layout issue. Facility seam work and its native proof have a separate owner.
Publication remains on hold pending combined review. The generic duplicate
IndoorVolume ownership issue is deferred by designer direction. See the
[current house verification packet](art/reference/2026-10-19-house-wall-repair-v1/checks.json).

## 2026-10-19 — Small-house redundant inner shell corrected

The ordinary-house double wall was physical layout, not only art. When fewer
than two rooms fitted, RectFacilityCarver inset its fallback room another cell
inside the parcel envelope. The boundary-wall pass then enclosed that room a
second time, producing 13 redundant inner cells in the reproduced 8×7 parcel
and a blocked lane inside the east entrance. The fallback now uses the existing
envelope as one usable room. Its cover stays inside the room and clear of door
approaches. Successful multi-room layouts retain their partitions.

The focused regression first failed 12 checks, then passed all 161. The larger
four-room fixture retains all 80 partition cells, full floor/window/cover output
and RNG state. Exact before/after comparisons of all three actual captured
facility plans retain 684, 368 and 421 wall cells, identical masks, windows,
floors, cover, doors and identities. Their native captures predate the shared
carver edit; this output comparison does not claim their old source hashes match.

Fresh checks pass 1,298 kit assertions, 5,430 procedural assertions, 60 actual
styled buildings in 20 chunks, 21,547 site-continuity assertions, roof occlusion,
3,840-chunk reachability and all 543 script parses. A native reduced-motion run
at the rejected ordinary-house location now shows the inner shell and entry
bars removed. It passes physical entry, five-guard clearance, exit/roof
restoration, streamed reload and controlled combat: 147 frames, 61 weapon fires,
60 hits, 29 deaths, zero failures/diagnostics/save writes. All 40 runner hashes
and the 16-entry supplemental source record match. Scripted input and god mode
remain fixture limits; designer acceptance is pending.

The human requested a progress checkpoint, superseding the earlier publication
hold without granting aesthetic approval. The sole integration owner created
commit `3aa358c5`; final evidence packaging here is a later uncommitted update.
No independent commit or push was performed by the house repair chat. See the
[version-two verification packet](art/reference/2026-10-19-house-wall-repair-v2/checks.json).

## 2026-10-19 — Enclosed procedural Donjons, first implementation

Large sites now generate enclosed stone compounds with three roofed wings, an
outdoor court and a connected west hall/cell/service sequence. Compact district
Donjons use enclosed halls and side chambers fitted around protected access.
Original site/region reward identities and rules remain; a no-fit region stays
an honest outdoor ruin/cache rather than receiving false indoor tags over roads.
Ordinary house geometry and room-carver RNG baselines are retained.

Original modular gate, grille and masonry art supports actual carved openings.
Raised gatehouse caps, a restrained clay service roof, wall lamps and deliberate
court planting give the family a first architectural identity. Roofs and upright
returns clip per streamed slice, cut away under actual indoor ownership and keep
actors visible behind opaque forms. Courts remain outdoors; compact halls have a
continuous quiet interior floor. Existing large-site seam topology remains intact.

All eleven relevant automated runs pass, including 33,001 layout checks, 96 raised
roof/door checks, 762 actual compact-production checks, existing house/city/site
regressions, 3,840-chunk reachability and 546 script parses. A natural 16-seed
comparison finds six selected chunks/seven enclosed regions with unchanged reward
IDs and selection counts; its sample contains no no-fit cases.

Final native evidence includes 66 normal/small stills across actual 2×2 west,
2×1 north, 1×2 east and S3 compact dungeons, plus 32 moving fight frames. Physical
hall travel, real doorway entry/exit, streamed reload while inside, roof restoration
and controlled exterior combat pass with no failures, diagnostics or save writes.
All 75 final product-source/asset hash checks match. These are scripted god-mode
fixtures and sampled art reviews, not human continuous-play or performance approval.

The coordinating designer accepts this bounded first implementation. Long roof
bands, sparse courts and interior dressing remain refinement. Mixed planned/default
multi-chunk anchor completeness is a preexisting separate whole-city limit; the
three facility candidates have all-default slices. Generic duplicate IndoorVolume
ownership is still deferred. Failed/superseded captures are retained and labelled.
See the [implementation audit](audits/2026-10-19-dungeon-architecture.md) and
[verification packet](art/reference/2026-10-19-dungeon-architecture-v1/checks.json).
The human authorized applicable commits; this batch has no new push request.

## 2026-10-19 — Common urban-building foundation across procedural segments

The human lifted the inventory hold and requested base buildings throughout all
other segments. The accepted civic/domestic parcel treatment now applies from
S2 onward, including the current S11+ Service Courtyards fallback. Composed
paving remains exclusive to the accepted S2 reward block; later parcels retain
their theme terrain and semantic route materials. Theme selection, district
plans, density, vegetation, checkpoints and physical/reward rules are unchanged.

New paired production-parcel checks cover all 14 themes plus S11: 30 chunks,
121 styled buildings, 150 assertions, identical physical/reward snapshots and
no later composed paving. The fixtures explicitly disable terrain/decorations/
sites; actual native S3, S7 and S11 runs supplement them. Their 437 recorded
frames pass physical perimeter/door travel, security clearance, roof cutaway/
restoration, deterministic streamed reload and controlled exterior combat with
zero failures, diagnostics or save writes. The first S11 recording timed out
while saving frames and remains labelled incomplete; its fresh longer-output
run passed without changing product timing or thresholds.

All twelve behavior suites and the final 546-script parse audit pass. The strict
reported-warning check reloads all 14 target scripts without diagnostics or a
working-project settings change; all 1,536 runtime source/resource hashes match
the tested candidate. Code/evidence review has no actionable findings. Native
fixtures use scripted input/god mode and do not establish performance, balance,
human continuous-play or whole-concept-fidelity acceptance. The existing 250 ms
warmup guard remains unresolved; no timing threshold or scheduling edit is made.

S1 and Hub retain their authored architecture/progression; their safe common
material/depth opportunities are documented separately. Legacy roofless default
exploration rooms remain an explicit separate architecture contract, not newly
completed civic houses. Distinct district generation follows this foundation.
The human-requested checkpoint `d0f99e06` backed up the implementation and evidence
completed at that point; final verification is a separate local record. See the
[foundation audit](audits/2026-10-19-city-foundation-rollout.md).

## 2026-10-19 — First distinct district family: S3 guard loggias

After the explicit common-base lane handoff at `a798043d`, S3 civic parcels now
select fitted masonry arch bays, closed iron inspection bays and a compact
supported watch roof. The already selected family is forwarded through both
real parcel paths without new generation RNG draws. Physical doors, footprints,
IDs, floor/blocker data, security/rewards and terrain/layout remain the comparator.
Other themes and ordinary houses retain the common foundation.

Final evidence covers 79 natural chunks, all four entrance directions and an
irregular service parcel. Two full native runs and three ambient entry runs
preserve roof entry/exit and identical streamed reload; normal and small/reduced
combat runs total 306 frames, 127 fires, 118 hits and 58 deaths. All nine current
captures have zero failures, diagnostics/save writes and 459 matching runtime
source/asset hashes. Twenty-two final scene/script suites, including the 548-script parse
audit, and isolated strict reported-warning check pass. Cost sampling is a bounded
headless diagnostic, not performance acceptance. Native fixtures use scripted
input/god mode; final coordinating-design and human aesthetic acceptance remain
distinct from these checks.

This completes one bounded architectural prototype, not all district concepts.
The fourteen-theme matrix, other bespoke families, connected gates/gantries,
rail/canal topology, S1/Hub, DonJons and legacy roofless structures retain their
separate scopes. No new push is performed. See the [S3 audit](audits/2026-10-19-s3-guard-loggia.md)
and [native evidence](art/reference/2026-10-19-s3-guard-loggia-v1/README.md).

## 2026-10-19 — S3 visual refinement closed

The bounded follow-up adds one original quiet plaster/limestone material,
continuous watch-room side/front depth inside the original supported envelope,
and attached north/east/west sill/landing treatments at real openings. The
coordinating designer closed all three findings after native review. A small
side corner exposed by a doorway-notched cap was reproduced and corrected in
the actor mask before final verification. Physical generation, doors, rewards,
security, RNG, navigation, terrain and the global32-triangle limit are retained.

Runtime `7f4c12e6` passes16 final suites,548 gameplay-script parses and strict
reported warnings in14 targets. Ten fresh native runs pass with0failures,
diagnostics or save writes and530 matching source/asset hashes. Normal/reduced
footage totals329frames/122fires/115hits/56deaths; four videos decode cleanly.
These are scripted native samples, separate from continuous human play,
balance, comparative performance and whole-city aesthetic acceptance.

The next selected building packet is one S4A municipal/service-hall ruin on
genuine eligible sites with safe no-fit fallback. Street-material coverage and
staged player/tree, batched-enemy and pickup visibility are separately prepared
follow-ups; none is silently implemented by this S3 refinement. Existing
branch/sole production ownership is retained and no push is performed. See the
[v2 audit](audits/2026-10-19-s3-visual-refinement-v2.md) and
[evidence](art/reference/2026-10-19-s3-guard-loggia-v2/README.md).

## 2026-10-20 — Concept fidelity audit and single lead

The human requested an audit of four art/production chats, then appointed this
audit chat as lead designer toward the accepted concept. The audit retains the
shared civic/domestic foundation and completed S3 refinement, but finds that
the generated city still lacks the concept's connected inhabited frontage,
roof/wall mass hierarchy, coherent street materials and practical infrastructure.
All four old chats were completed/idle and are now archived; their assets and
evidence remain. One fresh production chat owns implementation in this checkout.

Fresh seed16102026 actual S2 environment captures produced24 normal/small plates
with exit0, zero diagnostics/failures/save writes. These frozen camera plates
show current generation, not an ordinary human run. Independently verified final
S3 source/asset comparisons still match530/530; old S2 release hashes no longer
all match. No product code or gameplay rules changed during this audit.

The lead-selected next benchmark is one complete playable generated S2 street
and its immediate neighbors, judged at the real camera before another bespoke
family. Appropriate later street-material coverage, staged tree/enemy/pickup
visibility and S4A remain outstanding. This changes production priority without
reopening S3's three closed local findings. See the [audit and acceptance
contract](audits/2026-10-20-concept-fidelity-and-chat-audit.md) and [fresh baseline](art/reference/2026-10-20-lead-design-audit/README.md).

## 2026-10-20 — Uneven medieval streets and lived-in homes

The human clarified that uneven medieval development remains desired; coherent
street relationships must not become uniform square blocks. Suitable near-home
green space should look tended through modest lawn, flowers/herbs or a small
fruit tree, while outside greenery retains procedural wilderness. One separate
asset-only chat is creating the two missing garden sprites. Production retains
the sole code/integration/engine lane and its monitored recovery procedure.

The human also rejected empty ordinary-house interiors and their placeholder-
looking pale masonry, preferring the older harsher brick/stone character. The
original rough stone sources remain; the common city shader compresses their
values into a pale range. A real domestic cutaway confirms the empty interior.
The next domestic packet follows the exterior checkpoint: purposeful household
groups and stronger masonry, preserving physical wall/door/roof repairs. Old
slate security-building captures are material references, not dwelling proof.
See the [current art direction and acceptance requirements](art/2026-10-20-medieval-gardens-and-domestic-interiors.md).

## 2026-10-20 — Ground care states and rejected S7 blue carpet

The human requested distinct tended/open-wild/neglected grass backgrounds and
appropriate dirt variation, and asked the lead to challenge off-target results.
Source inspection confirms S7's blue greenery comes primarily from its blue/
teal/purple broadleaf moss PNG, modestly reinforced by theme tint. The lead
rejects that broad carpet for this temperate city. Cool dampness should come
from quiet green moss, soil, stone and contextual growth.

The next asset-only ground packet is two opaque material sources: short lawn
and restrained damp moss/soil. Existing rough grass, localized dense growth,
dirt and wet mud remain reuse candidates subject to native review. Integration
must preserve terrain IDs/organic masks, distinguish cared residential patches
from wilderness and validate the derived texture cache. No ground fix is yet
claimed. The latest isolated street scene improves wall mass and neighboring
context but omits Game/player/HUD/combat; it does not close playable acceptance.
See the [source findings, production boundaries and visual gates](art/2026-10-20-ground-material-direction.md).

## 2026-10-20 — Linux production / Windows art handoff

The human assigned the higher-memory Linux PC heavy implementation/checking,
with Windows retaining lead art direction, source asset creation and visual
review. [HANDOFF](../HANDOFF.md) records fresh-clone setup, branch exchange,
current source/results, asset anchors and ordered L0–L3 tasks. The two owned
records in `docs/handoff/` carry acknowledgments, evidence and requests through
Git; cross-PC live chat access is not assumed. Integration stays on
`enemy-world-work`; Linux publishes `codex/linux-world-production` for review.

The S2 checkpoint passes focused post-review source checks but still lacks
current native home/garden and full gameplay acceptance. Lawn/moss, cot and
hearth candidates are supplied; ground and domestic interior integration remain
queued. The four old chats stay archived and local production yields heavy
engine work. Normal scoped checkpoint pushes are authorized; no force-push or
blanket staging is part of this workflow.

## 2026-10-20 — Linux native home fit reviewed; ground care is next

The lead fetched Linux packet `1fa7a552` (implementation `5f851103`, evidence
`1e90f92a`), verified the published artifacts, and personally reviewed both real
home exteriors at normal/small sizes, genuine cutaways, occupied stills and
sampled sequences from all three videos. Keep the measured herb-bed/tree fit,
irregular footprint and fitted neighbor provisionally. Accept the monitored
capture/test improvements as qualified WIP; no whole-street approval is given.

Next Linux packet is L2 on the same homes plus natural S7: locally tended ground
versus real wilderness/neglect, using the already supplied lawn/moss sources and
validated cache. L3 then supplies purposeful domestic furnishing and stronger
masonry, with the blank tan exterior band and oversized dark entry also needing
refinement. Fully coloured actors/projectiles crossing opaque roofs remain a
named V1 visual blocker before occupied-street acceptance. More district families
or speculative asset packs are not requested. See the [lead review and return
criteria](art/reviews/2026-10-20-linux-s2-lead-review/README.md) and updated
[ART_STATUS](handoff/ART_STATUS.md). Linux publication succeeded; its recorded
authentication failure is historical, and the human can relay Git manually.

## 2026-10-20 — L2 ground trial kept in part; bounded correction required

Received Linux `ce5671e6` (implementation `0d6f761a`, evidence `d4b647a1`) through
the human's push. Lead review keeps the subdued S7 moss and actual household-care
infrastructure, with relevant source/cache/mask evidence and no important code
blocker. Integrate as qualified WIP, not complete-ground acceptance.

At960 the local cared strip is still too subtle; inspect and improve one useful
garden-adjoining pocket and its actual owning-chunk x=0 boundary. Wet mud retains
strong repeated ribbons and dark-actor contrast needs attention. The next bounded
L2 correction checks sampling/cache, returns the same S7 crop and a real dry-earth
control, and trials one supplied wet-earth candidate if needed. The original PNG
and exact built-in generation prompt are preserved. No Windows engine/bake was
used, and no new terrain or district family is requested. L3 and V1 remain open.
See [review, asset support and return criteria](art/reviews/2026-10-20-linux-l2-lead-review/README.md).

## 2026-10-20 — Linux city continuation reviewed; domestic composition remains

The human published Linux `fd80106a`. Native review and independent scoped
implementation/evidence review support qualified integration of the selected
wet earth, useful lawn core, rough domestic masonry and purposeful furnishings,
connected irregular roof planes/paving/casts, selected daylight and body/icon
foreground depth. The accepted temperate uneven medieval concept remains the
full goal; these improvements do not establish complete street/game fidelity.

The next bounded correction composes the same two households into believable
sleep/cook/work/storage spaces and finishes their unfinished-looking entry.
Windows supplies one original plain rush-mat source with exact prompt and fit
metadata; runtime use is unaccepted. Linux also completes remaining cue/projectile
depth with moving occupied-street/collection evidence and profiles the changed
cover/footway cost without capture readback. Natural chunk-edge care continuation
remains an explicit L2 limit. No new districts or broad asset pack are requested.
See the [lead review and return scope](art/reviews/2026-10-20-linux-city-continuation-review/README.md)
and [ART_STATUS](handoff/ART_STATUS.md). Windows ran no engine; Linux owns heavy
implementation/imports/captures/performance work and its status acknowledgment.
