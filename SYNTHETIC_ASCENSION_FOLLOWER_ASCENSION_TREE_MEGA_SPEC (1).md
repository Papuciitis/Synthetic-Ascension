# SYNTHETIC ASCENSION — FOLLOWER ASCENSION TREE MEGA SPEC

**Status:** Design exploration / consolidated direction  
**Project:** Synthetic Ascension  
**Primary topic:** Followers as progression currency + radial Ascension skill tree  
**Core correction:** 4,000 Followers is **not** a large number in this game. It is readily achievable within roughly two segments. The game is intended to continue well beyond ten segments, with no hard cap on Followers earned per segment. Long runs may plausibly reach hundreds of thousands, millions, or eventually billions of Followers.

---

# 1. Executive Summary

Followers should become one of the central systems of Synthetic Ascension rather than remaining ordinary money.

The strongest direction is:

- The player explicitly chooses a **starting combat style** at the beginning of the run:
  - **Melee**
  - **Ranged**
  - **Magic**
- That choice defines the player's permanent **primary combat identity** for the run.
- Each style opens into a **large radial / concentric skill tree** with **three major subtrees**.
- The tree is bought directly with **Followers**.
- There is no need for conventional XP → level → skill-point progression.
- Early nodes may include modest statistical improvements, but deeper nodes should increasingly:
  - add mechanics;
  - mutate existing mechanics;
  - unlock active abilities;
  - create mutually exclusive build directions;
  - alter game rules;
  - unlock screen-wipe abilities;
  - create late-run transformations.
- Major active abilities may have their own small internal upgrade / mutation trees.
- Later in a run, authored bridges can allow limited **cross-style hybridization** without erasing the original Melee / Ranged / Magic identity.
- Items remain the system that defines the player's normal combat machinery, proc chains, sets, NEG interactions, rarity scaling, and “random bullshit go.”
- The Follower Ascension tree defines what increasingly **impossible things** the character can do.

The central fantasy is:

> You do not level up because an experience bar filled.  
> You become capable of impossible things because enough people believe that you can.

---

# 2. Why the Existing Follower Economy Is Misaligned

The current implementation creates a mismatch between the intended theme and the actual numerical economy.

Known issues:

- Belief Power reaches maximum at only around **225 Followers**.
- Around **4,000 Followers** can be gained relatively easily within approximately two segments.
- Shop prices around **100 Followers** become trivial very quickly.
- Death costing around **20% of Current Followers** is meaningful only when the player dies.
- Most enemies award at least one Follower.
- Overtime reward decay currently floors the result at one, meaning ordinary one-Follower enemies cannot actually be devalued by the decay.
- Because the game is intended to continue for many more than ten segments, any progression system balanced around “a few thousand Followers is huge” will collapse extremely early.

The solution should **not** be merely multiplying vendor prices by 40 or adding a hard per-segment earning cap.

The actual solution should be to give Followers a progression economy that remains useful at increasingly large scales.

---

# 3. Scale Assumption

Synthetic Ascension should be comfortable with Follower counts becoming absurd.

Possible rough magnitudes:

| Run State | Illustrative Scale |
|---|---:|
| Early run | 0–10,000 |
| Established build | 10,000–100,000 |
| Strong movement | 100,000–1,000,000 |
| Major movement | 1,000,000–10,000,000 |
| National / global-scale phenomenon | 10,000,000–1,000,000,000 |
| Endless-run absurdity | 1,000,000,000+ |

These are **not hard gates or caps**.

They exist only to remind designers that 4,000 is not an endgame number.

A player who breaks the economy and reaches 50 million Followers unusually early should not be stopped by an arbitrary ceiling. The rest of the game should instead react to the fact that the run has become abnormal.

---

# 4. Followers as the Main Progression Currency

The proposed progression loop:

```text
Combat / Objectives / Events / Exploration
                    ↓
                FOLLOWERS
                    ↓
         ASCENSION TREE INVESTMENT
                    ↓
   New mechanics / abilities / rule changes
                    ↓
 More power + stranger play + stronger world response
```

No traditional:

```text
XP → Level → Skill Point → Ability
```

Instead:

```text
Followers → Belief Investment → Ability
```

This gives Followers a long-term sink and strengthens the fiction.

---

# 5. Starting Style Is Explicit

At the beginning of the run, the player chooses:

- **Melee**
- **Ranged**
- **Magic**

This is not inferred later.

It should matter from minute one and remain the character's primary identity throughout the run.

The starting style may affect:

- starting weapon / moveset;
- initial stats;
- available base attacks;
- equipment weighting;
- item synergies;
- first Ascension tree region;
- animation language;
- early tutorial flow;
- default active ability;
- baseline scaling.

Later hybridization can expand the build, but it should not turn a Melee character into a generic “all classes unlocked” character.

---

# 6. High-Level Tree Architecture

Each starting style receives a large radial / concentric tree.

Suggested structure:

## Melee
- Execution
- Momentum
- Bastion / Retaliation

## Ranged
- Precision
- Barrage
- Ordnance

## Magic
- Invocation
- Distortion
- Dominion

The visual model:

```text
                         SUBTREE A
                            ▲
                            │
                     ●──●──◆──●──●
                   /             \
                  ●               ●
                /                   \
              ◆                       ◆
             /                         \
SUBTREE B ◄─────── [ STYLE CORE ] ───────► SUBTREE C
             \                         /
              ◆                       ◆
                \                   /
                  ●               ●
                   \             /
                     ●──●──◆──●
```

The player begins in the center and spends Followers outward.

---

# 7. Concentric Progression

Distance from the center should communicate transformation.

## Inner Ring — Fundamentals
Cheap, readable, mostly conventional improvements.

Examples:
- attack speed;
- attack area;
- projectile velocity;
- cooldown;
- max HP;
- dash recharge;
- mana / resource efficiency;
- crit / weak-point modifiers.

These should not dominate the tree.

## Middle Ring — Mechanics
Nodes begin changing actual gameplay.

Examples:
- overkill transfers;
- projectiles redirect after missing;
- dash attacks leave afterimages;
- explosions create secondary explosions;
- controlled enemies become linked;
- damage stored while blocking powers the next strike.

## Deep Ring — Specialization
The build acquires a strong identity.

Examples:
- execution thresholds;
- escalating barrage states;
- persistent spell infrastructure;
- retaliation engines;
- ballistic chains;
- causality manipulation.

## Outer Ring — Revelations
Rule-breaking nodes.

Examples:
- screen-wide executions;
- automated artillery;
- global enemy pulls;
- temporal rewriting;
- projectiles cast spells;
- lethal damage consumes Followers instead.

## Edge / Ascension Tier
Extremely expensive late-run transformations.

Examples:
- attacks count as multiple categories;
- impossible range rules;
- continuous large-scale abilities;
- semi-permanent transformations;
- high-cost abilities that consume Followers during use.

General rule:

> The farther outward the player travels, the less nodes should answer “how much stronger am I?” and the more they should answer “what can I now do that was previously impossible?”

---

# 8. Node Taxonomy

Not all nodes should be equivalent.

## 8.1 Small Nodes
Cheap tuning.

Examples:
- +6% area
- +8% attack speed
- +10% projectile velocity
- -5% cooldown

Purpose:
- smooth pathing;
- create readable local choices;
- connect meaningful nodes.

They should not become expensive point taxes.

## 8.2 Mechanic Nodes
Introduce a new interaction.

Examples:
- overkill damage transfers to a nearby enemy;
- dodge attacks create an afterimage;
- explosions apply a stacking fracture;
- linked enemies share control effects.

## 8.3 Choice Nodes
Mutually exclusive forks.

Inspired by systems such as Dota talent forks.

Example:

**Barrage Revelation Choice**

Option A:
> ONE WEAPON, INFINITE BULLETS  
> Dramatically scales attack rate and projectile duplication.

Option B:
> INFINITE WEAPONS, ONE TARGET  
> Attacks originate from multiple external positions.

The player cannot own both within the same build branch.

This prevents infinite-Follower runs from simply buying every identity.

## 8.4 Keystones / Revelations
Large rule-changing nodes.

Examples:
- missed projectiles seek another target;
- overkill always propagates;
- executions chain;
- blocking converts incoming projectile force into attack power;
- control effects become shared across linked enemies.

## 8.5 Active Ability Nodes
Unlock a major active ability.

Examples:
- Judgement;
- Total Fire Mission;
- Singularity;
- Kneel;
- False Sun;
- Annihilation.

## 8.6 Mutation Nodes
Modify an unlocked active ability.

Example:

```text
                      TOTAL FIRE MISSION
                              │
                 ┌────────────┼────────────┐
                 │            │            │
             SATURATION     GUIDANCE     CASCADE
                 │            │            │
            More shells    Seeks elites  Kills spawn
            Larger area    Fewer shells  more strikes
```

## 8.7 Axioms
Rare universal principles learned through one tree but applicable more broadly.

Examples:

**Violence Propagates**
> Overkill transfer can apply to more damage sources.

**Nothing Is Wasted**
> Missed projectiles may seek another target.

**Effects Have Memory**
> Major status effects have a chance to repeat.

These can support future hybrid builds.

## 8.8 Hybrid Bridge Nodes
Late-run nodes linking the primary style to another combat language.

These should be authored and limited, not “unlock the entire other tree.”

---

# 9. Melee Tree

## 9.1 Execution

Fantasy:

> I touch something and it dies.

Core mechanics:
- heavy hits;
- crit finishers;
- overkill;
- execution thresholds;
- elite killing;
- kill chaining.

Early ideas:
- increased heavy attack impact;
- higher overkill storage;
- crits against weakened enemies;
- increased execution threshold.

Mid ideas:
- executions cleave;
- overkill transfers;
- elite kills temporarily lower execution thresholds;
- critical kills refund part of attack recovery.

Deep ideas:

### Sentence
Mark an enemy. The next melee strike against it deals extreme damage.

### Collective Sentence
If Sentence kills the target, nearby enemies receive a weaker version.

### Fatal Momentum
Every execution strengthens the next one within a short window.

Apex:

## DECIMATION
All normal enemies below an execution threshold on screen are executed simultaneously.

Possible mutation directions:
- lower threshold, smaller radius;
- full-screen but elite-resistant;
- executions explode;
- executions generate Followers;
- costs Followers per executed enemy.

---

# 10. Melee — Momentum

Fantasy:

> Movement is violence.

Core mechanics:
- dash flow;
- combo retention;
- movement speed;
- attack chaining;
- animation cancel / recovery manipulation;
- afterimages.

Early:
- dash recharge;
- attack speed while moving;
- attack reach after dashing;
- momentum retention.

Mid:
- dashing through enemies primes them;
- moving attacks build Momentum;
- perfect dodge preserves combo;
- kills reset dash charges.

Deep:

### Afterimage
High-speed attacks leave delayed copies.

### Unbroken Motion
Kills pause or reset Momentum decay.

### Thousand Cuts
At high Momentum, melee attacks repeat as weaker echoes.

Apex:

## NO DISTANCE BETWEEN US
For a short duration, melee attacks automatically collapse distance to valid enemies, creating rapid chained assaults across the battlefield.

Mutations:
- prioritize elites;
- prioritize nearest;
- teleport only on kill;
- every teleport creates an AoE;
- Followers consumed per chained target.

---

# 11. Melee — Bastion / Retaliation

Fantasy:

> The enemy's violence becomes my violence.

Core mechanics:
- armor;
- block;
- damage storage;
- retaliation;
- shockwaves;
- crowd pressure.

Early:
- armor;
- guard;
- stagger resistance;
- recovery after heavy hits.

Mid:
- store part of incoming damage as Force;
- surrounded state increases retaliation;
- block creates shockwave;
- absorbed projectile damage powers next melee attack.

Deep:

### Immovable
Knockback and displacement effects are converted into shockwaves or Force.

### Return to Sender
Incoming projectile force contributes to the next strike.

### Pressure Vessel
Stored Force decays slowly but detonates if filled.

Apex:

## THE WORLD BREAKS FIRST
Release all stored Force as a massive radial rupture. Damage reflects the pressure recently absorbed.

Mutations:
- smaller but repeatable;
- huge radius with long recharge;
- sends radial fissures;
- converts some damage to Followers;
- can be charged by deliberate self-damage / NEG effects.

---

# 12. Ranged Tree

## 12.1 Precision

Fantasy:

> One shot, mathematically perfect consequence.

Core mechanics:
- weak points;
- penetration;
- ricochet geometry;
- targeting;
- long-range reward;
- crit precision.

Early:
- projectile speed;
- weak-point multiplier;
- penetration;
- accuracy.

Mid:
- hitting same target reveals weak points;
- crit projectiles pierce;
- piercing increases projectile damage;
- ricochets prefer weakened enemies.

Deep:

### Ballistic Solution
Brief aim / targeting state calculates an efficient multi-target trajectory.

### Impossible Shot
Missed projectiles can retarget.

### Terminal Geometry
Penetrating hits can bend toward another valid target.

Apex:

## LINE OF JUDGEMENT
Generate one or more ideal firing lines through dense enemy formations; firing executes the calculated shot through every intersected target.

---

# 13. Ranged — Barrage

Fantasy:

> Random bullshit go — but engineered.

Core mechanics:
- attack speed;
- projectile count;
- multishot;
- proc multiplication;
- ricochet;
- heat;
- ammo sustain.

Early:
- additional projectiles;
- shot duplication;
- kill-based reload;
- attack speed.

Mid:
- shots create weaker shots;
- ricochets can ricochet;
- selected on-hit effects can repeat at reduced efficiency;
- sustained fire escalates attack rate.

Deep:

### Escalation
Continuous firing increases projectile count or firing layers.

### Crossfire
Some attacks originate from off-screen / perimeter positions.

### Recursive Fire
Secondary projectiles can generate limited tertiary projectiles.

Apex:

## ABSOLUTE SUPPRESSION
For a short duration, every ranged attack generates secondary fire from multiple directions around the battlefield.

Critical implementation note:
Proc generations must be tagged so secondary attacks cannot infinitely regenerate their parent trigger.

---

# 14. Ranged — Ordnance

Fantasy:

> Prepare the battlefield, then cause a disaster.

Core mechanics:
- rockets;
- mines;
- bombs;
- artillery;
- drones;
- delayed attacks;
- area denial.

Early:
- explosion radius;
- fuse control;
- mine count;
- projectile impact force.

Mid:
- explosive kills spawn secondary charges;
- mines chain;
- overkill increases blast radius;
- elites can become artillery beacons.

Deep:

### Saturation Coordinates
Dense enemy groups are automatically designated.

### Walking Barrage
Bombardment follows the player's movement.

### Secondary Detonation
A percentage of explosions can create delayed follow-up blasts.

Apex:

## TOTAL FIRE MISSION
Mark the battlefield. After a warning delay, large regions are struck by sequential bombardment.

Mutation paths:
- Saturation: more shells, wider area;
- Guidance: fewer shells, tracks elites;
- Cascade: killed enemies create extra strike coordinates;
- Walking Fire: bombardment follows the player;
- Apocalypse: enormous cost, near-screenwipe.

---

# 15. Magic Tree

Magic must not become “ranged but purple.”

It should primarily manipulate rules, space, causality, constructs, and battlefield state.

---

# 16. Magic — Invocation

Fantasy:

> Bring impossible things into existence.

Core mechanics:
- manifestations;
- constructs;
- persistent spell objects;
- summoned anomalies;
- infrastructure.

Early:
- construct duration;
- spell persistence;
- summon count;
- area.

Mid:
- spells leave manifestations;
- manifestations cast weaker spells;
- kills near constructs grow them;
- constructs inherit selected item effects.

Deep:

### Echo Shrine
Repeated casting near a manifestation stores spell echoes.

### Autonomous Invocation
Manifestations act without direct player input.

### Recursive Ritual
Manifestations can create weaker manifestations under strict limits.

Apex:

## THE HOST
Every active manifestation duplicates or enters an empowered state temporarily, flooding the battlefield with spell infrastructure.

---

# 17. Magic — Distortion

Fantasy:

> Reality behaves incorrectly around you.

Core mechanics:
- Luck;
- probability;
- time;
- causality;
- duplicated outcomes;
- impossible states.

Early:
- Luck scaling;
- debuff duration;
- cooldown variance manipulation;
- projectile displacement.

Mid:
- effects can happen twice;
- damage can repeat;
- enemy attacks can disappear;
- recent damage can be partially revised.

Deep:

### Causal Debt
A percentage of future damage is applied immediately.

### Revision
Undo a recent large damage instance.

### Contradiction
Enemies may hold mutually incompatible status states.

### Effects Have Memory
Selected effects can repeat without being directly reapplied.

Apex:

## CONSENSUS FAILURE
For a limited time, reality strongly favors beneficial outcomes:
- crits;
- proc duplications;
- cooldown resets;
- item triggers;
- enemy attack failures;
- favorable Luck checks.

This should be spectacular, but bounded enough to avoid deterministic permanent god mode.

---

# 18. Magic — Dominion

Fantasy:

> The battlefield itself obeys you.

Core mechanics:
- pull;
- push;
- gravity;
- slow;
- zones;
- linking;
- enemy group manipulation.

Early:
- spell area;
- slow strength;
- pull force;
- control duration.

Mid:
- controlled enemies share movement effects;
- collisions deal damage;
- enemies can become linked;
- groups can be compressed into kill zones.

Deep:

### Singularity
Pull a large cluster into a point.

### Collective Burden
Damage dealt to one linked enemy partially propagates to linked targets.

### Forced Orbit
Controlled enemies rotate around a point / player.

Apex:

## KNEEL
All normal visible enemies are forcibly pulled, staggered, or immobilized according to the build's Dominion configuration.

Mutation paths:
- pull toward player;
- pull toward cursor;
- pin enemies in place;
- linked enemies share damage;
- massive Follower cost for global range.

---

# 19. Major Abilities Should Have Their Own Small Trees

Inspired by Last Epoch-style skill specialization and modern branching active-skill systems.

The main Ascension tree unlocks an ability.

That ability can then be opened and customized.

Benefits:
- fewer total active abilities required;
- more depth per ability;
- different players can use the same named power differently;
- lowers content-production burden;
- improves replayability.

Example:

```text
                       JUDGEMENT
                           │
            ┌──────────────┼──────────────┐
            │              │              │
      CONDEMNATION    COLLECTIVE      FINAL WORD
       explosions       scaling       huge area
            │              │              │
            └───────┐      │      ┌───────┘
                    ▼      ▼
                  CAPSTONE
```

---

# 20. Followers as Unlock Cost and Operating Cost

Followers should be both:

- **capital expenditure** — unlock power;
- **operating expenditure** — use extreme power.

Example:

### Annihilation
Unlock:
> 500,000 Followers

Use:
> 10,000 Followers

Effect:
> Kill or massively damage normal visible enemies.

Another:

### Mass Resurrection
Unlock:
> 2,000,000 Followers

Use:
> 50,000 Followers or X% Current Followers

This keeps Followers relevant even after much of the authored tree is purchased.

Possible cost types:
- flat Followers;
- percentage of Current Followers;
- Followers per enemy affected;
- Followers per second;
- escalating cost per repeated use;
- hybrid flat + percentage.

---

# 21. Endless-Run Follower Sinks

The authored tree cannot remain infinite forever.

Late-game repeatable investments solve this.

Examples:

### Amplify Judgement
+4% damage per rank  
Cost ×1.35 each rank.

### Expand Dominion
+3% area per rank.

### Strengthen Consensus
Small increase to favorable probability manipulation.

### Deepen Invocation
Increase manifestation durability / duration.

Repeatable nodes should not replace authored transformative content.

They exist so Segment 40+ players still have somewhere meaningful to spend tens of millions or billions of Followers.

---

# 22. Hybridization

Hybridization is a **future / later-run** layer.

The player still explicitly started as Melee, Ranged, or Magic.

Hybridization should:
- preserve the primary style;
- unlock authored cross-style mechanics;
- appear later;
- require substantial investment;
- avoid giving full access to the other style tree.

Possible bridges:

## Melee + Magic
Themes:
- spellblade;
- bloodcasting;
- melee as spell origin;
- teleport strikes;
- body becomes manifestation.

Example:
### INCARNATE
Casting a major spell temporarily changes melee attacks into a manifestation of that spell.

## Melee + Ranged
Themes:
- gun-kata;
- projected violence;
- ranged fire integrated into melee flow;
- melee kills reload;
- ranged hits empower melee.

Example:
### TOTAL OFFENSIVE
For a duration, melee attacks trigger ranged fire and ranged attacks generate melee projections.

## Ranged + Magic
Themes:
- arcane ballistics;
- portal shots;
- spells originating from projectile impacts;
- bullets frozen in time;
- multi-dimensional trajectories.

Example:
### ARCANE BALLISTICS
Projectiles become possible spell origins.

## All Three
Very late.

Possible identity:
### ASCENDANT

Important:
Do not simply give +10% to everything.

Possible rule:
> Selected attacks may count as multiple styles for specifically whitelisted interactions.

This needs strict recursion safety.

---

# 23. Cross-Style Trigger Safety

The biggest danger in hybrid systems:

```text
Melee hit
→ Magic proc
→ Ranged proc
→ Item proc
→ Melee proc
→ Magic proc
→ ...
```

This can destroy both balance and performance.

Every generated attack / proc should carry metadata such as:

- source generation;
- parent trigger;
- proc depth;
- allowed child categories;
- “cannot trigger self” tags;
- “secondary cannot generate tertiary” limits;
- recursion budget.

Example conceptual tags:

```text
origin = PLAYER_PRIMARY
generation = 0
tags = [MELEE, PRIMARY_ATTACK]

afterimage:
origin = PLAYER_PRIMARY
generation = 1
tags = [MELEE, SECONDARY_ATTACK, NO_AFTERIMAGE_TRIGGER]
```

This is especially important because the game already aims for 500+ enemies and high projectile counts.

---

# 24. Relationship Between Items and the Ascension Tree

The two systems should not compete for the same design job.

## Items
Define:
- ordinary combat machinery;
- proc chains;
- set behavior;
- POS / NEG interactions;
- rarity scaling;
- weapon statistics;
- lifesteal;
- on-hit behavior;
- “random bullshit go” scaling;
- emergent build interactions.

## Follower Ascension Tree
Defines:
- active powers;
- impossible mechanics;
- screen wipes;
- rule-breaking abilities;
- transformations;
- style identity;
- late-run specialization;
- hybrid doctrine.

Summary:

> Items tell you **how your build works**.  
> Followers tell you **what your character has become capable of**.

---

# 25. Current Followers vs Peak / Historical Followers

The tree's central resource is **Current Followers**.

However, there is still value in tracking a secondary historical number:

- Peak Followers;
- Total Followers Ever Gained;
- Maximum Congregation;
- Historical Reach.

This should not replace the main tree economy.

Possible uses later:
- world recognition;
- institutional response;
- dialogue;
- run milestones;
- event unlocks;
- large-scale belief thresholds.

Example:

```text
Current Followers: 320,000
Peak Followers: 2,400,000
```

The player spent most of their congregation on Ascension, but the world still remembers that a movement of 2.4 million existed.

This system is optional / adjacent, not the core focus of the first implementation.

---

# 26. Attention / World Response as Adjacent System

Followers can eventually also generate **Attention**.

Attention should represent:
- institutional awareness;
- media / public visibility;
- social instability;
- reality-containment response;
- increasingly specialized enemy pressure.

It should probably feed into the existing ThreatDirector rather than becoming a fully separate spawning system.

Possible relationship:

```text
Threat =
Base Progression
+ Overtime
+ Objective State
+ Attention Contribution
```

Attention could influence not only quantity but **enemy type and countermeasure selection**.

Important:
This is a future bridge between Followers and world state, not the first priority.

The tree itself should work before adding a giant world simulation.

---

# 27. Follower Income Should Feel Thematic

Ordinary enemies always dropping one Follower makes Followers feel like copper coins.

Possible future alternative:
- ordinary kills create conversion probability;
- multikills generate Follower bursts;
- elite kills generate larger belief events;
- objectives generate meaningful recruitment;
- world events can create large follower spikes;
- spectacular actions generate “witness” or conversion outcomes.

Potential presentation:

```text
WITNESSED MASSACRE
+47 Followers
```

or:

```text
47 CONVERTED
```

rather than every basic enemy literally dropping a person.

This should be audited with income-per-minute data before implementing major economy changes.

---

# 28. Screen-Wipe Philosophy

Screen wipes should not all be generic circles of damage.

Each subtree should receive a wipe consistent with its combat fantasy.

| Style / Subtree | Screen-Wipe Fantasy |
|---|---|
| Melee — Execution | Execute all sufficiently weakened enemies |
| Melee — Momentum | Rapidly chain / teleport through the battlefield |
| Melee — Retaliation | Release accumulated incoming pressure |
| Ranged — Precision | Fire ideal calculated lines through crowds |
| Ranged — Barrage | Flood battlefield with recursive fire |
| Ranged — Ordnance | Artillery saturates the area |
| Magic — Invocation | Manifestations multiply into a temporary army |
| Magic — Distortion | Reality begins favoring impossible outcomes |
| Magic — Dominion | Entire battlefield is forcibly repositioned / controlled |

The objective is not merely:
> “all trees eventually get 10,000% AoE damage.”

It is:
> “all trees eventually gain a different way to invalidate ordinary combat rules.”

---

# 29. Visual / UI Direction

The radial skill tree should feel like the player's belief spreading outward.

Potential visual language:
- central player / icon;
- radial spokes;
- concentric rings;
- thematic clusters;
- major nodes visibly larger;
- outer revelations dramatically distinct;
- hybrid bridges appear between regions later;
- purchased paths glow / fill outward;
- locked future regions remain visible.

The visual metaphor:

> Going outward = becoming less human.

Possible ring labels, if useful:
- Mortal
- Believer
- Prophet
- Icon
- Ascendant

These are placeholders, not final lore.

---

# 30. Large-Tree UI Requirements

A large tree requires navigation support.

Useful features:
- mouse-wheel zoom;
- pan;
- controller pan;
- node search;
- filter by:
  - Active Ability
  - Passive
  - Revelation
  - Mutation
  - Hybrid
  - Purchased
  - Affordable
- highlight connected path;
- minimap;
- recent purchase indicator;
- compare cost;
- respec / refund handling;
- readable preview of future nodes;
- controller focus navigation.

This is supported by lessons from large modded skill-tree interfaces such as Minecraft Passive Skill Tree / Astral Skill Tree.

---

# 31. Respec Philosophy

Open question.

Potential options:

## No Respec
Strong commitment, but punishing for experimentation.

## Full Respec
Good experimentation, weakens identity.

## Limited Follower Refund
Refund X% of Followers.

## Ritual Respec
Requires:
- Followers;
- special world event;
- rare item;
- reconstruction cost;
- Attention spike.

Likely best direction:
some ability to respec, but not costlessly and not constantly.

---

# 32. Design Lessons from Commercial Games

## Enshrouded
Useful lesson:
- radial class-region layout;
- Warrior / Ranger / Mage identity;
- visually readable paths around a shared center;
- hybrid connective possibilities.

Primary inspiration:
**visual organization**.

Reference:
https://enshrouded.com/

---

## Path of Exile
Useful lessons:
- giant passive web can still communicate local themed clusters;
- Keystones matter because they change rules rather than merely numbers;
- pathing itself creates commitment.

Primary inspiration:
**clusters + rule-changing Keystones**.

Reference:
https://www.pathofexile.com/passive-skill-tree

---

## Wolcen — Gate of Fates
Useful lessons:
- concentric radial rings;
- increasingly specialized outer progression;
- central-to-outer visual hierarchy.

Do not necessarily copy:
- rotating-ring gimmick.

Primary inspiration:
**concentric radial progression**.

Reference:
https://wolcen.fandom.com/wiki/Gate_of_Fates

---

## League of Legends — Runes
Useful lessons:
- primary path + secondary package;
- Keystone defines identity;
- not every upgrade needs to be available simultaneously.

Primary inspiration:
**primary identity + secondary influence + Keystone**.

Reference:
https://leagueoflegends.com/

---

## Last Epoch
Useful lesson:
- each individual active skill can have its own specialization tree.

Primary inspiration:
**major abilities mutate instead of simply stacking dozens of new hotkeys**.

Reference:
https://support.lastepoch.com/

---

## Mass Effect: Andromeda
Useful lesson:
- investment across Combat / Tech / Biotics supports pure and hybrid Profiles.

Primary inspiration:
**hybrids can emerge from cross-investment without discarding the core disciplines**.

Reference:
Mass Effect: Andromeda manual / Profile system documentation.

---

## Hades
Useful lesson:
- Duo Boons unlock only when prerequisites from two different gods are already owned.

Primary inspiration:
**hybrid powers as authored prerequisite combinations**.

Reference:
https://hades.fandom.com/wiki/Duo_Boons

---

## World of Warcraft — Hero Talents
Useful lesson:
- specialization-spanning trees can bridge two existing specs.

Primary inspiration:
**secondary cross-style layer without replacing primary class identity**.

Reference:
https://worldofwarcraft.blizzard.com/

---

## Warframe — Focus Schools
Useful lesson:
- distinct thematic schools;
- some progression concepts can eventually become usable outside the originating school.

Primary inspiration:
**Axiom-like deep nodes that can become broadly relevant**.

Reference:
https://warframe.fandom.com/wiki/Focus

---

## Dota 2 — Talent Forks
Useful lesson:
- mutually exclusive milestone choices prevent every build from becoming identical.

Primary inspiration:
**hard forks at transformative tiers**.

Reference:
https://www.dota2.com/

---

# 33. Design Lessons from Mods and Player-Made Overhauls

The important meta-lesson:

> Modders frequently change progression systems because players hate spending scarce progression currency on boring mandatory taxes.

This is directly relevant to Followers.

---

## Skyrim — Perkus Maximus

Useful philosophy:
- perks should change gameplay;
- mastery should feel different from low skill;
- avoid useless filler;
- avoid spending points merely to make the basic archetype work.

Primary inspiration:
**Followers should increasingly buy new behavior, not just bigger numbers.**

Reference:
https://www.nexusmods.com/skyrimspecialedition/mods/11044

---

## Skyrim — SPERG

Useful philosophy:
- basic fundamentals can be granted automatically;
- scarce perk points should be reserved for interesting specialization.

Primary inspiration:
**do not force Followers to pay for every baseline stat progression requirement**.

Reference:
https://www.nexusmods.com/skyrim/mods/24445

---

## Skyrim — Master of One

Useful philosophy:
- specialization should create genuinely different versions of the same skill;
- perks may involve both advantages and tradeoffs;
- commitment should matter.

Primary inspiration:
**three subtrees should represent different verbs / combat fantasies, not Damage / Defense / Speed columns**.

Reference:
https://www.nexusmods.com/skyrimspecialedition/mods/47024

---

## Skyrim — Vokriinator Black

Useful lesson:
- combining many perk overhauls can create enormous build freedom;
- at extreme complexity the rest of the game must be able to survive the player's power.

Primary inspiration:
**late-run absurdity is acceptable, but enemy/world scaling must account for it**.

Reference:
https://www.nexusmods.com/skyrimspecialedition/mods/26702

---

## Minecraft — Passive Skill Tree

Useful lesson:
- large web-based trees work in modded environments;
- multiple thematic regions can coexist in a large map;
- custom layouts can support very different playstyles.

Primary inspiration:
**tree as geography / regions rather than a vertical list**.

Reference:
https://www.curseforge.com/minecraft/mc-mods/passive-skill-tree

---

## Minecraft — Waifing Passive Skill Tree

Useful lesson:
- visually demonstrates center → spokes → clusters → outer major nodes.

Primary inspiration:
**radial visual language**.

Reference:
https://www.curseforge.com/minecraft/data-packs/waifing-passive-skill-tree

---

## Minecraft — Astral Skill Tree

Reported concepts include:
- many nodes;
- multiple branches;
- passive bonuses;
- active abilities;
- transformations;
- keystones;
- masteries;
- hybrid skills;
- legendary powers;
- navigation aids such as zoom / pan / search / minimap.

Primary inspiration:
**node taxonomy + UI requirements for very large trees**.

Reference:
https://www.curseforge.com/minecraft/mc-mods/astral-skill-tree

---

## Minecraft — RPG Series Skill Tree

Useful lesson:
- tree choices can transform existing spells rather than merely unlock new ones.

Primary inspiration:
**ability mutation nodes**.

Reference:
https://www.curseforge.com/minecraft/mc-mods/skill-tree

---

## XCOM 2 — Musashi's RPG Overhaul

Useful lesson:
- modular specialization combinations can create strange but coherent hybrid characters;
- class identity can become a product of specialization.

Synthetic Ascension should NOT copy the classless start because SA already explicitly chooses Melee / Ranged / Magic.

Primary inspiration:
**late-run authored specialization mixing**.

Reference:
Search for “Musashi RPG Overhaul XCOM 2”.

---

## Grim Dawn — Dawn of Masteries

Useful lesson:
- huge numbers of mastery combinations create enormous theorycrafting freedom;
- balance becomes increasingly difficult as combinations multiply.

Primary inspiration:
**hybrid variety is fun, but unrestricted “everything triggers everything” becomes impossible to balance and expensive to simulate**.

Reference:
Grim Dawn modding community / Dawn of Masteries.

---

# 34. Key Design Rules

## Rule 1
The starting playstyle remains important for the whole run.

## Rule 2
Followers directly buy progression.

## Rule 3
Do not add conventional XP and skill points unless there is a very strong reason.

## Rule 4
4,000 Followers is early-run money, not endgame money.

## Rule 5
No hard per-segment Follower cap.

## Rule 6
The tree must support extremely long runs and very large numerical economies.

## Rule 7
Small passive nodes are acceptable, but must not dominate.

## Rule 8
Deep nodes should change gameplay.

## Rule 9
Major abilities should be visually and mechanically extreme.

## Rule 10
Each of the nine subtrees must have a distinct combat fantasy.

## Rule 11
Screen wipes should reflect subtree identity.

## Rule 12
Items and Ascension should have different jobs.

## Rule 13
Hybridization comes later and preserves primary identity.

## Rule 14
Some late nodes should be mutually exclusive.

## Rule 15
Hybrid / proc recursion needs explicit technical safeguards.

## Rule 16
Repeatable sinks are needed for endless runs.

## Rule 17
The tree should visually communicate transformation from human → impossible.

---

# 35. Anti-Patterns

Avoid:

### 35.1 Stat Tax Corridors
```text
+5% damage
↓
+5% damage
↓
+10% damage
↓
actual fun node
```

### 35.2 Nine Cosmetic Trees
If all nine subtrees are just damage variations, the structure is fake.

### 35.3 Magic as Purple Ranged
Magic must change battlefield rules.

### 35.4 Screen Wipes as Identical AoE Nukes
Every subtree should wipe differently.

### 35.5 Unlimited Hybrid Access
A Melee player should not simply unlock the entire Magic tree.

### 35.6 Endless Proc Recursion
Generated attacks must have trigger-generation rules.

### 35.7 Buying Everything Eventually
Use:
- choice nodes;
- exclusive Revelations;
- authored bridges;
- specialization requirements.

### 35.8 Follower Caps
Do not solve balance with arbitrary per-segment caps.

### 35.9 Followers as Only Money
Followers should fund Ascension and eventually bridge into world response.

### 35.10 Followers as Just XP with a New Name
Avoid level bars and generic point conversions that destroy the metaphor.

---

# 36. Proposed First Prototype

Do not build the entire mega-tree immediately.

Prototype one style first.

Suggested: **Melee**.

## Phase 1 — Data / Economy
1. Audit Followers gained per minute across several run lengths.
2. Audit current shop expenditure.
3. Audit death-related expenditure.
4. Measure typical Follower counts at:
   - Segment 1;
   - Segment 2;
   - Segment 5;
   - Segment 10+.
5. Establish a rough cost curve without hard caps.

## Phase 2 — Tree Framework
Implement:
- radial node graph;
- connected-node purchasing;
- Follower costs;
- saved run state;
- center → outer pathing;
- three Melee regions.

## Phase 3 — Node Types
Support:
- small passive;
- mechanic;
- exclusive choice;
- Revelation;
- active ability;
- mutation.

## Phase 4 — One Complete Subtree
Build Execution first.

Example minimum:
- 5–8 small nodes;
- 3 mechanic nodes;
- 1 exclusive fork;
- 1 active ability;
- 2–4 mutations;
- 1 major Revelation;
- 1 screen-wipe capstone.

## Phase 5 — Full Melee
Add:
- Momentum;
- Retaliation.

## Phase 6 — Ranged and Magic
Only after node framework and economy feel good.

## Phase 7 — Hybrid Bridge Prototype
Add exactly one:
- Melee + Magic;
or
- Melee + Ranged.

Test recursion and identity preservation.

---

# 37. Example Follower Cost Philosophy

Do not treat these as final numbers.

Illustrative curve:

```text
Inner passive:               100–2,000
Mechanic node:             2,000–10,000
Strong mechanic:          10,000–50,000
Major choice:             25,000–100,000
Active ability:           50,000–500,000
Revelation:              100,000–2,000,000
Apex transformation:      1,000,000+
Endless-run investment:   exponential / percentage scaling
```

The actual values must be calibrated against measured Follower income.

At long-run scales, flat costs may stop mattering.

Use:
- increasing flat cost;
- percentage cost;
- hybrid costs;
- per-target costs;
- escalating use costs.

---

# 38. Example Long-Run Decision

Player has:

```text
Current Followers: 1,840,000
Primary Style: Ranged
Build: Barrage / Ordnance hybrid
```

Possible expenditures:

- 40,000 → +projectile-generation mechanic
- 120,000 → unlock secondary barrage origin
- 300,000 → mutate Total Fire Mission
- 750,000 → Revelation
- 50,000 per cast → emergency screen-wide artillery
- begin saving toward 2,500,000 → Ranged/Magic bridge

This is more interesting than:

> Level up → choose one point.

---

# 39. Thematic Arc

Early run:

> People follow you because you appear powerful.

Mid run:

> Their belief begins shaping what you are capable of.

Late run:

> You are powerful because people believe you are.

Very late:

> Reality can no longer distinguish between what is true and what enough people believe is true.

That is the thematic endpoint the progression system should reinforce.

---

# 40. Open Questions

## Economy
- Should buying Ascension nodes reduce Current Followers directly? **Likely yes.**
- Should some Follower expenditure be permanent investment while others are temporary sacrifices?
- Should Current Followers generate a small passive Belief Power effect?
- Should there be Peak / Historical Followers?
- How should shops remain relevant once tree costs reach millions?

## Tree
- Exact names of the 9 subtrees?
- Bastion vs Retaliation naming?
- How many nodes per subtree?
- How many active abilities should each subtree own?
- How many exclusive forks?
- Can a player invest in all three subtrees of their primary style freely?
- Should outer rings require a minimum total investment?

## Hybridization
- When does the first bridge unlock?
- Is bridge access based on:
  - total Followers spent;
  - segment;
  - specific Revelation;
  - world event;
  - item;
  - combination?
- Can all three styles be hybridized in one run?
- Does triple-style Ascendant exist only in endless mode / very late runs?

## Active Abilities
- Number of hotkeys?
- Should some abilities be automatic?
- Should screen wipes occupy one dedicated “Manifestation” slot?
- Can abilities be swapped?
- Are abilities permanent once purchased?

## Respec
- None?
- Partial?
- Follower cost?
- Ritual?
- Limited number per segment?

## Presentation
- What visual language represents belief?
- Does the tree physically grow?
- Do unlocked nodes animate?
- Does the center character icon transform?
- Do outer rings visibly become less human / more abstract?

---

# 41. Recommended Next Design Task

Before coding the entire tree:

Design **one complete Melee radial tree on paper**.

Specifically:
- central Melee Core;
- Execution wedge;
- Momentum wedge;
- Retaliation wedge;
- ~15–25 meaningful nodes per wedge;
- 2–3 major active abilities per wedge;
- 1–2 exclusive forks per wedge;
- 1 screen-wipe / Revelation per wedge;
- one possible future bridge location toward Magic;
- one possible future bridge location toward Ranged.

If that single tree feels exciting without relying on items, then the overall architecture is sound.

If it feels like “+damage with pretty circles,” redesign before implementing Ranged and Magic.

---

# 42. Final Direction

The proposed system is:

```text
START RUN
   ↓
CHOOSE PRIMARY STYLE
Melee / Ranged / Magic
   ↓
ENTER STYLE-SPECIFIC RADIAL TREE
   ↓
SPEND FOLLOWERS DIRECTLY
   ↓
3 SUBTREES
   ↓
Mechanics / Choices / Keystones / Abilities / Mutations
   ↓
Outer Revelations / Screen Wipes
   ↓
Late-Run Hybrid Bridges
   ↓
Ascendant / Endless-Run Progression
```

The design should aim for one feeling:

> The player is not filling out a talent menu.

> The player is watching belief spread outward until their character becomes something reality was not built to support.

---

# Reference Index

Commercial systems:
- Enshrouded — https://enshrouded.com/
- Path of Exile Passive Tree — https://www.pathofexile.com/passive-skill-tree
- Wolcen Gate of Fates — https://wolcen.fandom.com/wiki/Gate_of_Fates
- League of Legends — https://www.leagueoflegends.com/
- Last Epoch Support / Skill Specialization — https://support.lastepoch.com/
- Hades Duo Boons — https://hades.fandom.com/wiki/Duo_Boons
- World of Warcraft — https://worldofwarcraft.blizzard.com/
- Warframe Focus — https://warframe.fandom.com/wiki/Focus
- Dota 2 — https://www.dota2.com/

Player-made / modded systems:
- Perkus Maximus — https://www.nexusmods.com/skyrimspecialedition/mods/11044
- SPERG — https://www.nexusmods.com/skyrim/mods/24445
- Master of One — https://www.nexusmods.com/skyrimspecialedition/mods/47024
- Vokriinator Black — https://www.nexusmods.com/skyrimspecialedition/mods/26702
- Minecraft Passive Skill Tree — https://www.curseforge.com/minecraft/mc-mods/passive-skill-tree
- Waifing Passive Skill Tree — https://www.curseforge.com/minecraft/data-packs/waifing-passive-skill-tree
- Astral Skill Tree — https://www.curseforge.com/minecraft/mc-mods/astral-skill-tree
- RPG Series Skill Tree — https://www.curseforge.com/minecraft/mc-mods/skill-tree
- Musashi's RPG Overhaul — search XCOM 2 Workshop / community mirrors
- Dawn of Masteries — search Grim Dawn modding community / Nexus / forums

---

**Design principle to keep at the top of the implementation file:**

> **Followers should not primarily buy bigger numbers. They should buy permission to violate increasingly fundamental rules of the game.**
