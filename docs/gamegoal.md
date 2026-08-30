# Synthetic Ascension — Master Game Vision & Design Plan

> **Superseded 2026-08-30.** The canonical statement of what the game is trying
> to achieve is `docs/SYNTHETIC_ASCENSION_VISION.md`; priorities, phases and the
> status log are `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md`. This file
> is the August 2026 design snapshot, kept for its system detail and because
> `docs/design/*` cite its section numbers. Its status tags are stale: Doctrine
> of Burden (§23), Inversion Lens (§23) and Manifestations (§29) are shipped and
> tested, not DESIGNED/PROPOSED.

**Current design snapshot: August 2026**

This document is meant to describe **what Synthetic Ascension is actually trying to become**, not merely what exists in code today.

Where useful:

* **ESTABLISHED** = already agreed design direction.
* **IMPLEMENTED** = substantially exists in the current game.
* **DESIGNED** = design is agreed but implementation/content is incomplete.
* **PROPOSED** = recent idea worth prototyping, not yet foundational doctrine.
* **SUPERSEDED / OLD** = historical design whose original purpose may now be fulfilled differently.

---

# 1. High-level identity

**Synthetic Ascension is a 2D top-down action roguelite / horde-survivor about a mortal gradually reverse-engineering divinity and becoming Syn'Tek, a synthetic technology-magic god.**

The game combines ideas from:

* Vampire Survivors — escalating hordes and absurd late-run power.
* Risk of Rain — exploration, time/pressure, item interactions and increasingly dangerous runs.
* Slay the Spire — adaptation, risk/reward choices and builds emerging from combinations rather than fixed classes.
* Traditional RPGs — inventory, vendors, sets, item identity and deliberate buildcraft.

But it should **not** simply become another survivor arena.

The intended loop is:

> enter a real location → explore → pursue an objective → discover optional opportunities → acquire strange items → build something increasingly broken → world pressure escalates → prepare the Exit Rite → decide whether to greed more rewards or leave → continue the Ascension.

The key distinction is:

> **The player should be moving through and interacting with a place, not standing in a circle waiting for a timer.**

---

# 2. The five central design pillars

## Ascension

The character begins mortal and eventually becomes Syn'Tek.

Power should feel earned and increasingly absurd.

## Exploration

Levels are actual locations containing streets, buildings, interiors, alleys, landmarks, alternate routes and optional discoveries.

## Buildcraft

Items, rarity, POS/NEG polarity, sets, augments, Luck and eventually behavioral item effects interact to create strange builds.

## Probability

Luck bends many systems across the game rather than functioning as a single loot-quality stat.

## Pressure

Objectives, Threat, Resonance and the Exit Rite force the player to keep moving and eventually leave rather than farming comfortably forever.

---

# 3. What the game must NOT become

Synthetic Ascension should not drift into:

* a tiny static survivor arena;
* an AFK auto-attack game;
* endless optimal enemy farming;
* “wait X minutes for the level to end”;
* objective → door immediately beside objective;
* generic bigger-green-number loot;
* NEG items that are simply garbage;
* Luck = item rarity bonus;
* random corridors with no reason to explore them;
* twenty separate inventory/build menus;
* a spreadsheet-like gray sci-fi UI;
* generic hacking/terminal/neon cyberpunk;
* performance being solved by simply reducing the amount of chaos.

The setting is **synthetic magic / reverse-engineered divinity**, not conventional cyberpunk.

---

# 4. Syn'Tek and the central fantasy

The protagonist does **not** begin fully formed as Syn'Tek.

The intended identity curve is:

> mortal → anomaly → dangerous magical-technological force → figure people begin trusting/fearing/following → nascent divinity → Syn'Tek.

The player originally enters or possesses a mortal identity before Syn'Tek becomes the dominant identity.

The lore originates from an artificer/arcanist discovering the underlying components of magic and learning to **manufacture synthetic magic**.

This eventually becomes something larger:

* divinity itself is reverse-engineered;
* Followers/belief strengthen Syn'Tek;
* other divine/magical powers oppose the ascent;
* Syn'Tek becomes an actual technology-magic god;
* much later, Syn'Tek hides/reaches the planet's core;
* ultimately the continents are chained together into a supercontinent.

The early game should therefore not scream:

> “YOU ARE ALREADY A GOD.”

The transformation is one of the game's main progression fantasies.

---

# 5. World structure

The game is divided into **Areas**, which contain **Segments**.

## Area 1

**The City.**

The first Area begins with the protagonist inside an institution/laboratory-like environment and gradually expands into the city.

Segment 1 is more handcrafted and story-heavy than later segments.

Later segments can rely more heavily on procedural districts while retaining authored landmarks and important structures.

Tentative broader progression previously included more peripheral/outskirts/mountain environments after the city, but later Areas should remain flexible until Area 1 works.

Area 1 Segment 10 is **not the ending of the game**. Progress continues into later Areas.

---

# 6. Segment 1 — the major current authoring priority

**STATUS: established, largely not authored yet.**

Segment 1 is currently too small relative to what the game's systems have become.

The redesign should not simply scale the map up.

The desired progression is roughly:

> controlled institution
> → experiment / strange event
> → early instability
> → first meaningful confrontation
> → lethal escalation
> → building becomes increasingly hostile
> → first important item/build decisions
> → broader institutional complex
> → transition toward the outside
> → city becomes visible/accessible
> → outer city block / route
> → final progression toward the Exit Rite.

Segment 1 should provide space for:

* tutorialization through gameplay;
* story;
* the mortal identity;
* the first signs of Syn'Tek;
* combat escalation;
* exploration;
* items;
* Resonance;
* optional content;
* the first meaningful build choices;
* actual spatial progression.

The player should feel that they have **escaped through something**, not completed a tutorial room.

The institution can feel enormous — almost like an institutional district blending into the surrounding city — but it must not become large empty filler.

---

# 7. Story tone in Segment 1

The initial institutional/arcanist context should not begin as:

> obviously evil cartoon villains doing evil experiments.

There can be secrecy, danger and morally questionable activity, but the setting should still initially feel believable.

The protagonist is mostly quiet, with meaningful dialogue choices rather than constant voiced personality.

An assistant/trusted character was planned for the early part of Area 1, but not as a permanent companion throughout the entire game.

Violence should become genuinely lethal relatively early.

The transformation should happen through escalation rather than an immediate exposition dump.

---

# 8. Segment progression curve

A good segment should roughly feel like:

## Slow burn

Player is comparatively weak.

Environment matters.

Individual enemies can still matter.

Exploration has breathing room.

## Pressure

Enemy density rises.

Objectives pull the player through the space.

Optional content creates greed.

## Power spike

Items begin interacting.

The build starts becoming recognizably strange.

## Rising danger

Threat escalates.

Enemy composition becomes more dangerous.

The player's increasingly absurd build is answered by increasingly absurd pressure.

## Exit decision

The Exit Rite is available or becoming available.

The player decides:

> leave now, or greed another building/event/item while Threat continues rising?

This tension is central.

---

# 9. Primary objectives

**IMPLEMENTED direction.**

Each Segment has a real primary objective.

The objective exists partly to prevent:

> find comfortable farming spot → remain there indefinitely.

Primary objectives should be meaningful actions within the location rather than arbitrary timer gates.

They can interact with story, Resonance, Threat and the Exit Rite.

---

# 10. Secondary objectives and events

Segments can contain approximately **0–3 optional secondary objectives/events**.

Their job is to tempt the player away from the efficient route.

They may provide:

* loot;
* Followers;
* Resonance;
* unusual events;
* build resources;
* opportunities affected by Luck;
* additional risk.

Secondary content should create the thought:

> “I should probably go toward the objective… but what the fuck is over there?”

Current system improvements include spawn announcements and reliable completion.

Still desired:

* more secondary templates;
* clear expiry/failure feedback;
* richer integration with buildings/locations;
* later, more content variety.

---

# 11. Resonance

**IMPLEMENTED direction.**

Resonance is not XP and should not be a disguised timer.

It represents Syn'Tek establishing enough presence/influence/control in the location for the next stage of ascension/escape.

Resonance should come primarily from **meaningful actions**:

* primary-objective progression;
* important world interactions;
* secondary objectives;
* exploration/progression;
* appropriate combat contributions.

It should not become:

> kill endless trash until bar reaches 100%.

Current direction includes meaningful Resonance sources and honest gating.

When a true external gate requirement blocks departure, the visible Resonance meter can remain just below completion rather than falsely telling the player they are ready.

---

# 12. Exit Rite

The segment exit is an **Exit Rite**, not merely a door.

Conceptual states:

> **LOCKED → LOCATED → READY**

The player should understand:

* whether they know where the exit is;
* whether the primary objective is complete;
* whether Resonance is sufficient;
* whether another requirement blocks departure.

A proper **Exit Rite checklist UI** remains desirable.

At later segment progress, directional guidance toward the gate is appropriate.

The Exit Rite should represent the end of a meaningful journey through the segment rather than sitting beside the primary objective.

---

# 13. Threat / pressure system

Threat exists to make the world increasingly hostile and discourage infinite comfortable farming.

Pressure should come from more than raw population.

Threat can affect:

* enemy composition;
* elites;
* overtime;
* objective danger;
* event intensity;
* possibly future environmental conditions.

Important philosophy:

> The player becomes ridiculous; the world responds by becoming ridiculous too.

Time can contribute to Threat, but future progression should likely consider **segment/story/objective phase as well as wall-clock time** so a player reading or exploring doesn't accidentally trigger nonsensical late-stage enemy composition.

---

# 14. Followers — one resource, three jobs

Followers are one of the oldest and most important systems.

They are intentionally:

## Currency

Used for vendors/trades/events.

## Lives / reconstruction

Death consumes Followers.

Reaching the point where the next death truly ends the Ascension should matter.

## Power / belief

Belief itself strengthens Syn'Tek.

This is now mechanically real through belief-based Power scaling.

This creates one of the game's best economic tensions:

> Do I spend my Followers?
> Preserve them as lives?
> Or accumulate them because belief itself makes me stronger?

Followers must never become “gold with a funny name.”

---

# 15. Death and reconstruction

Death is part of the run economy rather than merely reloading a checkpoint for free.

Reconstruction consumes Followers.

Important state must reset correctly on a fresh attempt:

* inappropriate Threat/overtime state;
* temporary encounter pressure;
* dead-state channels.

Persistent run progress should remain only where deliberately intended.

The player should understand when spending Followers risks losing the ability to reconstruct.

---

# 16. Combat styles

The broad combat identities are:

* Melee
* Ranged
* Magic

They should share the wider item ecosystem while maintaining distinct mechanical tendencies.

One established example is lifesteal:

* melee receives strongest baseline sustain;
* ranged receives lower sustain;
* magic receives lower baseline sustain;
* all have style-specific caps.

The important principle is not the exact current numbers.

It is:

> mechanics such as lifesteal are not unnecessarily restricted to one style; they scale differently according to style identity.

Future item behavior should allow the same starting style to produce radically different physical gameplay.

---

# 17. Items — central design goal

Items should eventually become one of the most distinctive parts of Synthetic Ascension.

The player should not merely compare:

> +18 attack vs +23 attack.

Items participate in:

* rarity progression;
* POS/NEG polarity;
* sets;
* augments;
* Luck interactions;
* behavioral synergies;
* future Manifestations.

A good run should create:

> “How the fuck did this build happen?”

while still allowing the player to understand the chain after the fact.

---

# 18. Rarity and merge mass

**CURRENT DESIGN FORMALIZED AND CORE IMPLEMENTATION LANDED.**

Rarity is not a fixed Common/Rare/Legendary ladder.

It is an effectively unbounded numerical progression.

The design promise:

> **Every duplicate contributes, but items near your current rarity matter much more than ancient low-rarity scraps.**

Core concept:

```text
mass = quality(material) × 2^((Rmaterial − Rdestination) / H)
```

Current first-playtest gap half-life:

```text
H = 1.5
```

Implications:

* same-rarity copy ≈ major progression / roughly one rank for an average roll;
* nearby rarity = serious upgrade material;
* much lower rarity = scraps;
* contributions mathematically approach zero but do not require a hard mass floor.

Meaningful practical range:

* individual duplicates matter strongly within roughly a 6–8 rank gap;
* bulk salvage can remain visible around 10–12 ranks;
* extremely distant material is deliberately negligible.

No minimum mass floor is desirable because it would eventually make farming huge quantities of ancient trash optimal.

---

# 19. Continuous rarity power

**GREENLIT direction.**

Merge progress should affect the actual item continuously rather than only at full-rank thresholds.

This realizes the original concept:

> R0 + R0 can become a **stronger R0**, not merely an R0 with an invisible XP bar.

Effective power can therefore interpolate based on:

```text
rarity + upgrade_meter
```

A partially progressed R5 should be slightly stronger than a fresh R5.

This makes every merge physically meaningful.

Rate-based stats such as:

* movement speed;
* haste;
* lifesteal;
* evasion;

must use caps/transforms rather than scaling infinitely through the raw rarity curve.

---

# 20. Merge invariants

Important rarity rules:

* merge progress must be path-independent;
* overflow follows the same rank conversion implied by H;
* higher-rarity mathematical state survives;
* inventory/equipment identity must remain stable when auto-swapping merge destination;
* POS merge retains the best positive roll;
* rank-up never rerolls identity;
* stored merge progress is not lost;
* vendor buy/merge/resell must never generate positive Follower arbitrage.

The player should be able to see merge progress.

Example:

> R5 → R6 — 62%

Manual/tooltip UI can show detailed merge math.

Combat auto-feed should show a compact update rather than debug-spamming the screen.

---

# 21. POS and NEG items

POS and NEG are **separate item states/items**, not simply two generic affixes on one item.

NEG is intended as a genuine **risk/reward buildcraft ecosystem**.

The desired reaction is:

> “Normally this curse would suck, but this build actively wants it.”

NEG must never become:

> bad loot that everyone eventually optimizes away.

Luck can bias polarity but must never erase NEG from the ecosystem.

---

# 22. NEG merge philosophy

Default NEG progression **stabilizes**.

When merging ordinary NEG items:

> the milder curse survives.

This means ordinary progression represents refining/stabilizing a flawed synthetic object.

However:

**Corruption Engine changes this rule.**

While Corruption Engine is equipped:

> NEG merges deepen and preserve the more severe curse.

This is deliberately important:

> an augment changes what item progression itself means.

---

# 23. NEG build archetypes

The goal is not twenty variations of:

> +damage per curse.

Different builds should desire NEG for fundamentally different reasons.

## Corruption Engine — concentrated severity

**IMPLEMENTED.**

Only the two most severe active curses feed the engine.

Wants:

> a few catastrophic curses.

Also causes NEG merges to deepen.

## Doctrine of Burden — count

**DESIGNED.**

Wants:

> many mild-but-real curses.

Rewards qualifying NEG item count with defensive stats.

Default stabilizing merges are exactly what this build wants.

## Equilibrium Sigil — parity

**DESIGNED.**

Rewards exact POS/NEG count parity.

Can make the player deliberately reject a great POS item because it would break equilibrium.

While active, auto-equip should not destroy parity without player consent.

## Inversion Lens — reinterpretation

**DESIGNED.**

The single most severe NEG item remains intrinsically NEG but its active burden is suppressed and partially converted into the corresponding positive stat.

Wants:

> one absolutely horrific curse.

This introduces the distinction:

**Polarity** = what the item intrinsically is.

**Active burden/severity** = how much curse is currently affecting the player.

An inverted item remains NEG for parity/set/acquisition purposes but contributes zero active burden to burden-based effects.

## Litany of Wounds — health as resource

**DESIGNED.**

Below a health threshold, NEG burden increasingly converts into Haste as HP falls.

The player may deliberately operate at dangerous HP rather than automatically maximizing safety.

The gameplay question becomes:

> lifesteal back to safety, or remain wounded because the build becomes terrifying there?

## Gravemarch polarity mutation — set-specific curse build

**DESIGNED.**

Certain Gravemarch pieces being NEG mutate a set bonus into a life-drain aura.

This is proof that **sets themselves can read polarity**.

The set should have a way to deepen its relevant cursed pieces without being completely dependent on Corruption Engine.

## Gambler's Rite — acquisition / Luck

**DESIGNED.**

Wants:

> finding cursed items, even if they are never equipped.

NEG acquisition can interact with:

* Luck;
* Followers;
* limited Resonance reward.

Resonance must be capped/limited per segment and reward distinct discoveries rather than enemy-drop farming.

---

# 24. Deep curses

Current item data does not contain enough curse severity variance to make:

> few catastrophic curses vs many mild curses

a meaningful choice.

The game therefore needs several **authored deep-curse items**.

These should not simply use a global −95% range.

Severity must consider the stat family because:

* −95% movement speed;
* −95% Max HP;
* −95% regeneration;

are not equally playable.

The best deep-curse items should be memorable.

A normal build sees one and thinks:

> “Absolutely fucking not.”

An Inversion/Corruption build sees the same drop and thinks:

> “GIVE ME THAT.”

---

# 25. Luck

Luck is a **systemic probability stat**, not a loot-rarity stat.

It already or eventually influences:

* POS/NEG probability distribution;
* roll quality;
* item drop chance;
* Lucky Crits;
* Lucky Evasion;
* Follower gain;
* exploration loot;
* events;
* secondary-event probability;
* vendor prices;
* vendor stock quality;
* augments;
* other genuinely random systems.

Normal Crit Chance and Lucky Crit are distinct concepts.

Luck should use diminishing returns.

High Luck must never make NEG impossible because NEG is now an entire build ecosystem.

The fantasy is:

> the universe keeps behaving suspiciously well around you.

---

# 26. Sets

Sets provide **reliable build direction**.

They should eventually evolve beyond:

> 2-piece +10 stat
> 4-piece +20 stat
> 6-piece +30 stat.

Higher-tier sets should increasingly **change mechanics**.

Examples of the intended direction:

* Gravemarch mutating into a life-drain aura when sufficiently cursed;
* attacks leaving persistent mechanics;
* movement interacting with projectiles;
* overkill becoming another offensive pattern;
* spell/sigil geometry changing.

Set completion should increasingly feel like:

> “the build just came online.”

rather than merely increasing DPS.

---

# 27. Augments

Augments are the player's **deliberate build steering/commitment layer**.

Current augment system already provides:

* three augment slots;
* duplicate augments leveling up;
* uncapped levels structurally;
* increasing cross-system interaction.

Future augments should manipulate:

* NEG;
* Luck;
* sets;
* item behavior;
* resource economies;
* playstyle.

Because levels can continue, capped augment effects should use **asymptotic/diminishing scaling** rather than linear bonuses that hit a wall and make future levels meaningless.

---

# 28. Old persistent three-slot module/spell concept

**SUPERSEDED unless future testing proves otherwise.**

The original game had the idea of:

* random temporary items creating chaos;
* three persistent module/spell/enchantment slots providing controlled build identity.

The modern **three-slot augment system appears to serve this same purpose**.

Therefore:

> do not resurrect another three-slot persistent subsystem right now.

Treat the old system as intentionally superseded by Augments unless later playtests show the player lacks enough deliberate build control.

Avoid:

> equipment + sets + rarity + POS/NEG + augments + manifestations + another module system.

---

# 29. NEW PROPOSED LAYER — behavioral item effects / Manifestations

The current item system has a strong economy but risks producing builds that are mathematically different while playing identically.

Example of the problem:

> Build A has more Power.
> Build B has more Haste.
> Build C has curses.

But all three still physically:

> walk around and attack the same way.

The proposed solution is **NOT another equipment slot system**.

Instead:

> existing individual item instances have a chance to roll one handcrafted behavioral effect.

Working name:

**Manifestation**

Other thematic names remain possible, but avoid generic “affix” language because this is not just another number.

---

# 30. What Manifestations do

Each item can have **at most one** Manifestation.

Not every item has one.

Rings and offhands can have significantly higher Manifestation probability.

The Manifestation changes **how the player behaves**, for example:

* standing still builds Stability;
* travelling distance builds Momentum;
* crits create orbiting shards;
* dashing launches stored projectiles;
* kills mark/chain targets;
* evasion creates retaliation;
* stopping attacks stores Power for the next strike;
* low HP changes attack behavior;
* spending Followers fuels attacks;
* exploration provides combat bonuses;
* completing secondaries powers an effect;
* failed Luck rolls accumulate Misfortune;
* healing converts into barrier;
* another resource converts into an offensive mechanic.

The test for a good Manifestation is:

> **Does this change how I move, attack, target, spend resources or take risks?**

If the answer is merely:

> DPS increased,

it probably belongs in ordinary stats rather than Manifestations.

---

# 31. Manifestation slot weighting

The item slot can influence both probability and effect pool.

## Boots

Prefer:

* movement;
* dash;
* distance;
* standing still;
* trails/path behavior.

## Armor

Prefer:

* HP;
* damage taken;
* barriers;
* healing;
* retaliation.

## Weapon

Prefer:

* attacks;
* attack rhythm;
* crits;
* target selection;
* charge/release behavior.

## Ring

Highest chaos potential.

Can interact with:

* Luck;
* Followers;
* Resonance;
* NEG;
* acquisition;
* conversion;
* unusual cross-system logic.

## Offhand

Also high weirdness.

Prefer:

* projectiles;
* orbiting objects;
* stored attacks;
* summons;
* conversion;
* utility mechanics.

---

# 32. Manifestations are handcrafted

Do **not** procedurally generate meaningless grammar such as:

> 13% chance on crit while below 47% HP after moving 8.2 metres.

Create a curated library of actual designed effects.

Randomness chooses:

> which designed effect this item rolled.

The effect itself remains understandable and intentionally fun.

Prototype with approximately **12–15 effects first**, not 100.

---

# 33. Shared gameplay hooks

Manifestations and future complex items should use a common event/hook architecture.

Useful hooks include:

* attack;
* hit;
* crit;
* Lucky Crit;
* kill;
* elite kill;
* damage taken;
* evade;
* heal;
* lifesteal;
* dash;
* distance travelled;
* standing still;
* Follower gained;
* Follower spent;
* Resonance gained;
* secondary completed;
* item acquired;
* item merged;
* NEG burden changed;
* set activation;
* entering/clearing exploration spaces.

This keeps code architecture manageable while allowing many combinations.

---

# 34. Manifestation identity and merging

Manifestation should be part of an item's identity.

Therefore:

> merging into an item preserves the destination/surviving Manifestation.

Normal rarity progression should **not reroll the item's personality**.

This creates valuable loot tension:

> R9 item with mediocre Manifestation
> vs
> R2 item with an incredible Manifestation.

The player may choose to rebuild around the weaker-rarity item because its behavior transforms the run.

Later, a rare/expensive ritual/vendor mechanic could potentially transplant Manifestations, but this should not be normal merge behavior.

---

# 35. Manifestation engines

The most exciting effects should create **engines**, not merely isolated bonuses.

Example:

> Crit → creates Shard
> Shard pickup → grants Haste
> excess Haste → Shards begin orbiting
> Evade → launches orbiting Shards
> Shard kill → creates explosion

No formal “Shard Set” is required.

The interactions themselves create the build.

Multiple independent Manifestations can share concepts such as:

* Shards;
* Momentum;
* Stability;
* Marks;
* Misfortune;
* Barriers;
* Sigils.

This creates emergent non-set archetypes.

---

# 36. Manifestations can conflict

Not every random effect needs to cooperate.

For example:

> one item rewards constant movement
> another rewards standing still.

This can create:

* a genuine replacement decision;
* an awkward build;
* or an unexpected rotation such as sprint → plant → burst → sprint.

RNG should create situations the player must interpret, not automatically produce perfect synergies.

---

# 37. Relationship between the major build systems

The cleanest current hierarchy is:

> **Rarity = how developed the item is.**

> **POS/NEG = what risk/corruption profile it carries.**

> **Set = reliable build direction.**

> **Manifestation = random behavioral mutation.**

> **Augment = deliberate steering/commitment.**

> **Luck = bends the probability ecosystem around all of this.**

This prevents every mechanic from competing for the same design job.

---

# 38. Late-run chaos is intentional

If a player somehow equips 6–8 Manifestations that interact in ridiculous ways, the result is allowed to approach:

> Risk of Rain levels of “what the fuck is happening?”

That is payoff.

The goal is **not** to keep every late-game interaction polite.

The requirement is:

> the player can eventually understand why the chaos is happening.

This is where the Run Sheet becomes important.

---

# 39. Exploration

World generation must make exploration rewarding rather than decorative.

Districts should contain:

* streets;
* alleys;
* enterable buildings;
* optional interiors;
* landmarks;
* side routes;
* safer paths;
* dangerous shortcuts;
* optional events;
* rewards.

The desired player thought:

> “The objective is that way, but what is down this alley?”

Exploration should interact with:

* Luck;
* loot;
* secondaries;
* Manifestations;
* events;
* Followers;
* Threat.

---

# 40. Route readability

Exploration should not mean being constantly lost.

Useful information can include:

* objective indicators;
* distance language;
* gate arrows;
* cleared-building states;
* secondary feedback;
* Exit Rite state;
* threat language.

Avoid turning the game into permanent GPS autopilot, but the player should understand what the world is asking of them.

---

# 41. Vendors / hub

Vendor UI should feel like an actual RPG interaction rather than a gray debug spreadsheet.

Existing/desired vendor behavior includes:

* buying;
* selling;
* affordability filtering;
* remembered filters;
* instant comparison;
* set progress preview;
* undo last trade;
* buyback shelf;
* locked items protected;
* right-click quick move;
* Shift mark-for-sale;
* Ctrl lock;
* double-click equip;
* warning when spending below reconstruction safety.

Buying duplicate peers specifically to improve an item is allowed and useful.

Vendor arbitrage that generates Followers must not be possible.

---

# 42. Inventory philosophy

The game can have complex items without becoming an inventory-management simulator.

Inventory should therefore aggressively reduce friction.

Important principles:

* duplicates merge into progression rather than clutter;
* locks protect important items;
* quick actions exist;
* comparisons are immediate;
* set progress is visible;
* Manifestation identity is visible;
* merge progress is visible.

Complexity belongs in **decisions**, not repetitive clicking.

---

# 43. Enemy spawning

The game wants very large enemy populations.

The challenge should be:

> hundreds of meaningful threats

not:

> hundreds of invisible nodes eating CPU offscreen.

Current architecture increasingly uses:

* data-only EnemyWorld state;
* pooling/materialization;
* culling;
* stale cleanup;
* stuck-enemy protection;
* controlled refill;
* special handling for splitter descendants and elite context.

Pressure should scale through composition and behavior as well as count.

---

# 44. Loot

Enemy loot can interact with Luck.

Loot handling should support:

* item drops;
* rare percentage-based health pickups;
* pickup magnet;
* consolidation/auto-feed;
* splitter inheritance rules where appropriate.

The ground should not become permanent inventory garbage.

Pickup UX should support the build system rather than interrupt it.

---

# 45. Performance philosophy

The game is supposed to become chaotic.

Therefore architecture must support the design rather than forcing the design to become smaller.

Current work has moved toward:

* data-oriented enemy state;
* pooling/materialization;
* MultiMesh/projectile batching;
* batched damage numbers;
* reduced draw calls;
* avoiding physics catch-up bottlenecks;
* avoiding invisible pooled-node/render-lifetime bugs.

Recent tests have reached enemy populations in the several hundreds with dramatically better frame times than earlier builds.

Do not chase raw population count merely for a benchmark.

Use performance headroom for:

* enemy variety;
* bosses;
* interiors;
* VFX;
* Manifestations;
* richer environment;
* set effects.

---

# 46. Run Sheet / build communication

Do **not** create another separate “build summary” panel unless absolutely necessary.

The existing **Run Sheet** should become the one screen answering:

## What am I?

* weapon/style;
* core stats;
* Followers;
* important run state.

## What is my build doing?

* equipped items;
* rarity;
* POS/NEG;
* active burden;
* sets;
* augments;
* Manifestations;
* key interactions.

Whenever possible, show the calculation rather than only the name.

Example:

> Corruption Engine
> Top two active curses: 184% severity
> Power gained: +22.1%

or:

> Equilibrium Sigil
> 3 POS / 3 NEG
> ACTIVE

## What happened this run?

Potentially:

* kills;
* elite kills;
* damage dealt;
* damage taken;
* damage by source;
* secondaries;
* deaths/reconstructions;
* major upgrades;
* important events.

The Run Sheet should eventually help explain:

> “Why is the entire screen exploding?”

---

# 47. Accessibility / visual intensity

Late-game chaos is part of the fantasy.

Unreadability is not.

Current direction includes damage-number controls.

Future accessibility should consider:

* effect intensity;
* damage-number density;
* screen flashes;
* projectile clarity;
* objective visibility;
* important enemy visibility.

The goal is:

> spectacular chaos that remains playable.

---

# 48. RNG philosophy

The game **does want randomness**.

But random should mean:

> the game gives me a strange situation and I adapt.

Not:

> the game randomly decided my run sucks.

Ways the player can manipulate randomness include:

* Luck;
* vendors;
* Augments;
* sets;
* duplicate merging;
* choosing whether to equip NEG;
* exploration;
* optional objectives;
* eventually Manifestation selection/replacement decisions.

The desired structure is:

> **RNG creates opportunity/problems → player identifies a direction → deliberate systems let them lean into it.**

---

# 49. What a mature run should eventually feel like

A possible run:

> enter an institutional/city segment
> → begin weak
> → find first item
> → discover a NEG item
> → decide whether to stabilize, use or ignore it
> → find a ring whose Manifestation creates Shards on crit
> → complete a risky secondary
> → obtain an augment that supports evasion
> → another item launches Shards when dashing
> → Luck starts increasing drops and Lucky Crits
> → Followers accumulate and increase Power
> → Threat rises
> → the build becomes an accidental movement/Shard machine
> → primary objective completes
> → Resonance approaches completion
> → Exit Rite becomes available
> → optional building appears nearby
> → player knows leaving is safe but greedily explores it
> → receives another interaction that makes the build ridiculous
> → Threat escalates heavily
> → player races back to the Exit Rite through hundreds of enemies
> → exits with a build that plays completely differently from the previous run.

That is the game.

---

# 50. Example of genuinely different playstyles

Two characters can use the same starting ranged weapon and become:

## Momentum runner

Constant movement builds Momentum.

Crits create Shards.

Dash launches Shards.

Elites become priority targets.

Gameplay:

> keep moving → build resources → line up elite → dash-burst → keep moving.

## Stability artillery

Standing still builds Stability.

Not attacking stores Power.

Maximum Stability grants penetration.

Gameplay:

> find firing lane → plant → charge → enormous shot → relocate.

## Wounded curse build

Deep NEG burden powers low-HP Haste.

Lifesteal must be carefully managed.

Gameplay:

> deliberately ride dangerous HP rather than automatically healing to full.

## Corruption build

Two catastrophic curses power Corruption Engine.

NEG merges deepen.

Gameplay/build economy:

> actively hunt horrifying cursed items everyone else avoids.

## Doctrine tank

Many stabilized mild NEG items create durability.

Gameplay/build economy:

> refine curses instead of deepening them.

## Gambler/explorer

NEG discoveries, Luck and exploration rewards drive Followers and opportunities.

Gameplay:

> detour into dangerous places because strange loot itself is valuable.

These must eventually feel physically different, not merely show different stat sheets.

---

# 51. Current major priorities

The project has crossed the point where the main problem is missing plumbing.

Most of the foundational systems now exist or have clear designs.

The largest remaining distance is **authored game content**.

Recommended priority:

## 1. Segment 1 spatial + story redesign

Use the systems inside a level worthy of them.

This is currently the biggest bottleneck.

## 2. Finish core Exit Rite/readability presentation during Segment 1

Especially the LOCKED / LOCATED / READY checklist and final route communication.

## 3. Build the Run Sheet expansion

One screen, not another pile of menus.

## 4. Implement a small NEG vertical slice

Do not immediately build all six remaining archetypes.

Good first test:

* existing Corruption Engine;
* Doctrine of Burden;
* Inversion Lens;
* 3–5 deliberately authored deep-curse items.

This tests three radically different valuations of cursed loot.

## 5. Prototype Manifestations

Create only approximately 12–15.

Test whether items actually change how the player physically plays.

Do not scale to a huge library until this succeeds.

## 6. Increase authored content volume

* secondary types;
* buildings;
* landmarks;
* city chunks;
* events;
* interiors;
* enemy compositions;
* set content;
* deep-curse items;
* Manifestations.

---

# 52. The main playtest questions now

Future testing should increasingly answer gameplay questions instead of only code correctness.

### Segment 1

> Does this feel like an actual journey from mortal/institution into the larger city?

### Objectives

> Do objectives create movement without feeling like chores?

### Threat

> Do I feel increasing urgency without feeling arbitrarily punished for exploring?

### Items

> Do I care about what an item does, or only its numbers?

### NEG

> Do different builds genuinely disagree about whether the same curse is good?

### Rarity

> Do duplicates feel useful without making ancient trash farming optimal?

### Manifestations

> Did an item make me physically change how I move, attack, target or take risks?

### Sets

> Does completing a set change the build, or merely increase DPS?

### Luck

> Does Luck feel like reality bending around me rather than +loot rarity?

### Followers

> Do spending, reconstruction and belief create real tension?

### Run Sheet

> Can I understand why my build became absurd?

### Overall

> Can I play three runs and tell three meaningfully different stories about how the build and route developed?

---

# 53. The one-sentence target

> **Synthetic Ascension is an exploration-driven horde roguelite about a mortal reverse-engineering divinity, completing objectives through increasingly hostile places, and building an absurd synthetic-magic machine out of items whose risks, rarity, sets, random behaviors and augments interact until both the player and the world reach ridiculous levels of power.**

And the most important design goal going forward is:

> **Stop adding complexity merely to increase numbers. Make systems change decisions, behavior and the story of the run.**

