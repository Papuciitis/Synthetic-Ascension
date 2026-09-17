# Synthetic Ascension — What the Game Is Trying to Achieve

Synthetic Ascension is trying to become a **horde-survivor action roguelite where the real depth comes from constructing strange, emergent builds during a run**.

The goal is **not** to make another Vampire Survivors clone where progression mostly means:

> more damage, more projectiles, more enemies, bigger numbers.

The goal is also **not** to become a traditional ARPG where the player mainly searches for the same equipment with slightly better stats.

Instead, the player should begin a run with relatively understandable equipment and mechanics, then gradually assemble an increasingly complicated **synthetic-occult machine** out of:

* equipment;
* POS and NEG item polarity;
* rarity and merging;
* sets;
* augments;
* Manifestations;
* Luck;
* Followers;
* Resonance;
* objectives;
* environmental events;
* enemy responses.

By the late game, the build should feel partly **designed by the player** and partly **discovered accidentally**.

The desired reaction is:

> **“What the fuck have I built?”**

But the player should still be able to roughly explain why the build works.

---

# Core Design Goal

The most important goal is:

> **Different builds should make the player actually play differently.**

A build should not merely produce:

* +30% damage;
* +20% attack speed;
* +15% movement speed.

Instead, a build should produce a new gameplay loop.

For example:

```text
Dash
→ generates Momentum
→ heavy attack consumes Momentum
→ creates Shards
→ Shards trigger Fortune
→ Fortune creates extra crit events
→ crit events feed another Manifestation
→ that interaction creates Ward
```

Now the player has a behaviour:

> dash through enemies, build Momentum, dump it, trigger Shards, chain effects, repeat.

That is much more important than the final DPS number.

---

# The Game Should Have Three Different “Hits”

Synthetic Ascension needs to work on three timescales.

## 1. Immediate Hit

Within seconds:

> **Killing things feels good.**

Movement, weapons, hits and enemy deaths need satisfying impact even before the player has a build.

That means:

* good hit feedback;
* sound;
* recoil;
* knockback;
* stagger;
* crit feedback;
* enemy death response;
* projectile weight;
* clear melee impact.

The build system cannot compensate for weak baseline combat.

---

## 2. Build Hit

Within roughly 5–10 minutes:

> **“Oh shit, I understand what this run is becoming.”**

This is where the player begins constructing an identity.

Examples:

> “This is becoming a Corruption build.”

> “I have a Momentum–Shard engine forming.”

> “I found one horrifying curse and now my entire Inversion Lens run revolves around it.”

> “I am intentionally collecting lots of small curses because Doctrine rewards them.”

The run should start changing the player's decisions.

---

## 3. Run Hit

By roughly 20 minutes:

> **Something happens that makes the run memorable.**

The player should eventually have a story.

Not:

> “I survived 22 minutes.”

But:

> “I opened a cursed vault, everything went insane, my build suddenly came online, I started deleting enemies that nearly killed me ten minutes earlier, and then the Exit Rite turned into absolute chaos.”

This requires:

* encounter beats;
* escalation;
* risk/reward;
* visible power spikes;
* world reactions;
* special enemies;
* meaningful objectives;
* a climax.

---

# Builds Should Change How Loot Is Evaluated

One of the strongest goals is to make the player stop asking:

> **“Which item has the biggest number?”**

and instead ask:

> **“Which item belongs in the machine I am building?”**

This is where the NEG archetypes are important.

## Corruption Engine

Fantasy:

> **I want a few absolutely horrible curses.**

A normal player sees:

```text
-80% curse
```

and thinks:

> garbage.

A Corruption player should think:

> **holy shit.**

---

## Doctrine of Burden

Fantasy:

> **I want many small but meaningful curses.**

The ideal inventory could look like:

```text
-4%
-6%
-5%
-8%
-3%
-7%
```

The player should sometimes prefer six mediocre cursed items over two individually amazing items.

---

## Inversion Lens

Fantasy:

> **My worst flaw becomes the strongest part of my build.**

A ridiculous curse becomes something the player actively hunts for.

That fundamentally changes how loot is perceived.

---

## Future Equilibrium Sigil

Fantasy:

> **My inventory itself becomes a puzzle.**

For example:

```text
4 POS
4 NEG
```

gives a powerful bonus.

Then the player finds an excellent POS item.

Normally:

> obviously equip it.

But doing so gives:

```text
5 POS
4 NEG
```

and breaks Equilibrium.

So rejecting individually good loot becomes strategically correct.

That is exactly the kind of run construction Synthetic Ascension wants.

---

# Manifestations Should Create Engines

Manifestations are not supposed to be random extra passive bonuses.

Their purpose is to create **interaction networks**.

Useful conceptual categories include:

### Generators

Produce resources such as:

* Momentum;
* Shards;
* Fortune;
* Cadence;
* Ward.

### Converters

Turn one resource into another.

### Spenders

Consume resources for effects.

### Amplifiers

Make another part of the engine stronger.

### Bridges

Connect two previously unrelated mechanics.

Example:

```text
crit → Fortune
dash → Momentum
```

### Loop Closers

Feed the result back into an earlier stage.

The ideal build begins forming chains like:

```text
generator
→ converter
→ spender
→ trigger
→ bridge
→ generator
```

At that point the character begins behaving like a machine.

---

# Emergence Is the Main Long-Term Goal

Synthetic Ascension should eventually allow combinations that were **not explicitly authored as one ability**.

For example:

```text
NEG severity
→ Litany Haste
→ more attacks
→ Cadence generation
→ Momentum
→ Shards
→ crit
→ Fortune
→ Followers
→ Resonance
```

There should not necessarily be an ability called:

> “Curse-Fortune Resonance Engine.”

The player accidentally creates it by combining understandable systems.

That is where the game becomes interesting.

---

# Power Escalation Should Be Visible

The player should not remain at roughly the same relative power level for the entire run.

If:

```text
player power +30%
enemy power +30%
```

then progression happened mathematically, but emotionally nothing changed.

Enemies that were dangerous early should sometimes return later and simply get annihilated.

The desired rhythm is:

> “These guys nearly killed me earlier.”

**BOOM**

> entire group disappears.

Then:

> “...what the fuck is THAT?”

And a new threat appears.

The run should have visible phase changes.

---

# Continuous Pressure Is Not Enough

The game already has a ThreatDirector and large enemy populations.

But:

> more enemies

is not automatically:

> more interesting.

The game needs **encounter punctuation**.

Examples:

* charger formation;
* shield wall;
* sniper crossfire;
* summoner nest;
* hunter enemy;
* moving convoy;
* optional monstrosity;
* district lockdown;
* ritual event;
* high-risk cursed vault;
* enemy carrying guaranteed valuable loot.

The director should eventually ask:

> **“What kind of problem should I give the player?”**

not merely:

> **“How many enemies should I spawn?”**

---

# Objectives Should Create Situations

Objectives should not become generic progress bars.

Different objectives should force different behaviour.

Examples:

## Hold

Activate something and defend it while enemy directions change.

## Hunt

A target moves through the district and can escape.

## Extraction

Acquire something valuable and then get out alive.

## Sacrifice

Gain Resonance much faster in exchange for:

* lower max HP;
* disabled healing;
* immediate threat;
* specialist enemies.

## Rescue

Followers physically attempt to escape and need protection.

## Ritual Disruption

Destroying something weakens local enemies but massively increases attention.

The objective should alter the local rules of play.

---

# The World Should React to the Player

Synthetic Ascension should have a stronger world-progression identity than a standard arena survivor.

The run should begin relatively grounded.

## Early

* institution;
* security;
* police;
* ordinary streets;
* subtle evidence that something is wrong.

## Middle

The response becomes strange.

* specialist enemies;
* unusual formations;
* synthetic anomalies;
* more aggressive containment.

## Late

The world begins losing normality.

* impossible enemies;
* altered environments;
* reality distortion;
* architecture behaving strangely;
* Manifestations and the world visually beginning to resemble one another.

The player is becoming something the world increasingly cannot tolerate.

---

# The Exit Rite Should Be a Climax

The Exit Rite should not be:

> fill Resonance bar → walk through exit.

It should feel like:

> **the world realizes you are trying to leave.**

Pressure rises.

Routes may change.

Special enemies appear.

Reality becomes unstable.

The player's build gets one final opportunity to show what it has become.

The ideal outcomes are:

> escape looking completely broken and overpowered

or:

> die painfully close to escaping.

The Exit Rite should be something the player wants to reach because it is an event in itself.

---

# Followers

Followers should eventually become more than ordinary currency.

They can represent:

* belief;
* attention;
* social influence;
* metaphysical power;
* reconstruction;
* reality instability.

Eventually, high Follower counts could affect:

* events;
* enemy response;
* world state;
* certain abilities;
* reconstruction;
* Resonance;
* NPC behaviour.

Followers can become one of the thematic bridges between the run economy and the game's world.

---

# Luck

Luck should not simply mean:

> +15% better loot.

Luck should act like a **probability axis**.

It can influence:

* POS / NEG rolls;
* drops;
* random additional crits;
* evasion;
* Followers;
* vendors;
* prices;
* events;
* Manifestations;
* rare encounters;
* secondary objectives.

A useful philosophy is:

> **Luck sometimes gives the player another roll on reality.**

High Luck can mean not only:

> better things happen

but sometimes:

> stranger things happen.

---

# The Run Sheet

Because the game is meant to become complicated, the player needs a way to understand the machine they created.

The Run Sheet should eventually function as a **build debugger**.

It should answer:

> What is my build?

> What systems are currently active?

> Why is this stat this high?

> What is producing Momentum?

> Where are my Shards coming from?

> Why did this curse stop applying?

> Which Manifestations are feeding each other?

The desired combination is:

> **Noita / Risk of Rain complexity with Hades-like readability.**

---

# Main Inspiration Games

## Risk of Rain 2

Probably one of the most important inspirations.

Useful for:

* item interaction chains;
* late-run escalation;
* proc networks;
* stacking systems;
* turning ordinary items into ridiculous combinations;
* strong transition from weak early game to absurd late game.

Synthetic Ascension should borrow the feeling of:

> one effect triggers another effect which triggers another until the screen becomes chaos.

---

## Slay the Spire

Not because Synthetic Ascension is a card game.

The important inspiration is **run construction**.

Slay the Spire teaches the player:

> A strong option is not automatically the correct option.

The player rejects strong cards because they do not fit the deck.

Synthetic Ascension should create the equipment equivalent:

> “This item is objectively powerful, but it ruins my build.”

This is especially relevant for:

* NEG archetypes;
* Equilibrium;
* set choices;
* Manifestations;
* route decisions;
* vendors.

---

## Nova Drift

One of the closest buildcraft inspirations.

Nova Drift is excellent at combining simple modifications until the player's entire combat style changes.

Useful inspiration for:

* modular mechanics;
* converters;
* build-defining upgrades;
* radically different playstyles;
* interactions rather than pure stat increases.

Synthetic Ascension's Manifestations should often feel closer to Nova Drift mods than standard survivor upgrades.

---

## The Binding of Isaac

Useful because individual items often change meaning depending on what else the player owns.

The memorable part of Isaac is usually not:

> “I had +300% damage.”

It is:

> “I somehow created giant homing splitting lasers that filled the entire room.”

Synthetic Ascension should create similar run memories.

---

## Noita

Not because Synthetic Ascension should copy Noita's physics simulation.

The inspiration is the feeling of:

> **building a machine from understandable pieces and accidentally creating something insane.**

Noita starts with:

> wand shoots projectile.

Later:

> the wand appears to violate several laws of physics.

Synthetic Ascension should eventually create the same feeling at the **whole-character level**.

A useful description is:

> **The late-game character should feel like a Noita wand where the entire player build is the wand.**

---

## Path of Achra

Very useful niche reference for deep interaction chains.

Builds can behave almost like programs:

```text
when X happens
→ trigger Y
→ which triggers Z
→ which activates another passive
```

This is extremely relevant to the long-term Manifestation / augment interaction direction.

---

## Brotato

Useful for:

* stat tradeoffs;
* accepting disadvantages;
* shops;
* skewed builds;
* deliberately ignoring stats a build does not need.

Synthetic Ascension pushes this idea further with NEG:

> The downside itself can become something desirable.

---

## Hades

Not primarily a mechanical reference.

The important inspiration is **readability**.

Hades is good at communicating:

* what a mechanic belongs to;
* which effects interact;
* what status is active;
* why a synergy exists.

Synthetic Ascension can become much more complicated than Hades, but it should still try to explain its systems clearly.

---

## Horde Survivors / Vampire Survivors

This is primarily the **physical shell**:

* hordes;
* escalating enemy population;
* increasingly ridiculous player power;
* top-down combat;
* run-based progression.

But Synthetic Ascension should become less like Vampire Survivors as the deeper systems develop.

The survivor genre provides the battlefield.

It should not define the entire design philosophy.

---

# Condensed Inspiration Map

| Game                                    | Main lesson for Synthetic Ascension                          |
| --------------------------------------- | ------------------------------------------------------------ |
| **Risk of Rain 2**                      | Proc chains, interaction explosions, power escalation        |
| **Slay the Spire**                      | Run construction and rejecting individually strong choices   |
| **Nova Drift**                          | Modular build engineering and radically different playstyles |
| **Binding of Isaac**                    | Unexpected item combinations and memorable broken runs       |
| **Noita**                               | Emergent machines created from understandable rules          |
| **Path of Achra**                       | Deep trigger chains and character-as-program                 |
| **Brotato**                             | Stat sacrifice and intentionally skewed builds               |
| **Hades**                               | Synergy readability                                          |
| **Vampire Survivors / Horde Survivors** | Combat format, hordes and power fantasy                      |

---

# What Synthetic Ascension Should NOT Become

It should not become:

> Vampire Survivors with more complicated item descriptions.

It should not become:

> Diablo where the primary progression is replacing R14 Sword with R15 Sword.

It should not become:

> a technical enemy simulation whose main achievement is having 1,000 enemies alive.

It should not become:

> a giant collection of disconnected mechanics.

And it should not become:

> a game where every build ultimately plays the same but with different damage numbers.

---

# Shortest Possible Description

> **Synthetic Ascension is a horde-survivor action roguelite about constructing increasingly absurd synthetic-occult build engines. It combines the combat pressure and escalation of survivor games with Slay-the-Spire-style run decisions and Risk-of-Rain / Isaac / Nova-Drift / Noita-style emergent interactions. The player should start with understandable gear and end as a barely comprehensible machine whose curses, equipment, Manifestations, Luck, Followers and other systems feed into one another — while still being able to understand roughly how the machine works.**
