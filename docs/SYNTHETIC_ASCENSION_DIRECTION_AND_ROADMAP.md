# Synthetic Ascension — Direction, Priorities, and Near-Term Roadmap

**Date:** 2026-08-27  
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
`performance-hygiene`, `run-sheet-completeness`; `test-coverage-gaps` in
progress. Headlines: 449 MB of tracked JSON captures nothing reads; ~26 MiB of
provably dead files shipping via `all_resources`; saves keyed by `res://`
paths (any item/script rename bricks them and the UI offers to overwrite);
zero tests target a removed system, but 13 probes/benchmarks cannot fail.

Final full sweep on the committed Phase 2 tree (`a8a535a`, headless
`--quit-after`): **83 suites, 0 failures, 0 script errors** — with the caveat
the stale-tests audit documents: the display-only probes report an empty
summary and exit 0 regardless, so "83 clean" overstates coverage by about a
dozen.

