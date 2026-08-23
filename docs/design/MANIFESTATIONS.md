# Manifestations

**Rarity** answers "how developed is this item?".
**POS/NEG** answers "what risk does it carry?".
**Sets** answer "what deterministic build is this?".
**Augments** answer "what did the player deliberately commit to?".
**Manifestations** answer "what weird rule did *this particular instance* develop?"

A Manifestation is one handcrafted trigger → behaviour rule attached to a single
item instance. It is not another slot, not another affix layer, and not a stat.
The point is behavioural: two players holding the same weapon should end up
physically playing differently because of what their items rolled.

The playtest question is never "did DPS go up?". It is:

> Did I start moving, attacking, targeting or spending resources differently
> because of what my items rolled?

## Rules

1. **One Manifestation per item, maximum.** Ever.
2. **Not every item rolls one.** Slot chance (`ManifestationCatalog.SLOT_CHANCE`):
   HP/Armour 22%, Movement 26%, Luck 30%, Power/Haste 35%, Offhand 60%, Ring 70%.
   A NEG item gets +8% — corrupted material is unstable and develops anomalies
   more readily. Luck bends the odds shallowly, like it bends everything else.
3. **Slot weighting picks the POOL, not just the chance.** Boots get movement
   rules, armour gets damage-taken/HP rules, weapon slots get attack/targeting
   rules, offhands get projectile/orbit/storage rules, rings get anything.
4. **Handcrafted only.** RNG picks *which* rule from a curated library. It never
   assembles one out of effect grammar.
5. **The destination's Manifestation survives a merge. Always.** Duplicates rank
   an item up; they never reroll its identity — the same rule rank-up already
   follows. See "Merging" below for what that costs.
6. **Transfer/reroll is a later, rare, expensive ritual**, not normal merge
   behaviour. Nothing in this slice does it.
7. **Some rules deliberately share mechanics.** Three unrelated items all talk
   about Shards; three talk about Momentum. None requires the others. Getting
   two of them is how a non-set build accidentally becomes an engine.
8. **Some rules deliberately conflict.** Anchor Rite rewards standing still,
   Pilgrim's Momentum rewards never stopping. That friction is content.
9. **Eight strong interacting rules is the payoff, not a balance failure.** Keep
   early rules readable; let late synergy become glorious nonsense the player can
   still trace on the Run Sheet.

## Scaling

Rarity grows the *item*, not the *rule*. `ManifestationEffect.potency()` is a
shallow hard-capped curve (`1.0 + 0.045 × effective rank`, capped at `1.60`) and
`threshold_scale()` eases requirements by at most 22%. Getting the effect is the
reward; an R20 proc must never become the entire build by itself.

## Merging

**Merging is never blocked.** The destination keeps its own Manifestation and
the incoming one dissolves, exactly like every other duplicate property. A rule
mismatch must not refuse the merge: at a 70% ring roll chance across a 16-rule
pool, most ring duplicates would differ, and ring progression would stop
working. An item with no rule does not gain one by eating a manifested
duplicate either — rules are rolled, never farmed.

The protection lives one level up, in **automatic routing**.
`ItemInstance.can_absorb_manifestation_of()` is not a merge gate; it answers
"would feeding this destroy a rule the player has not seen yet?", and only
unattended callers ask:

* `Inventory.add_or_feed()` declines by default, so a ground pickup carrying a
  rule the worn item lacks goes to the bag instead of being absorbed on contact.
  Player-driven paths in `InventoryRouter` pass `allow_rule_loss = true` — they
  have already emptied the source slot, and the choice was the player's.
* `BagInventory` keeps two differently-manifested stacks apart instead of
  consolidating them, and every automatic caller now honours a refused merge
  rather than assuming success.

Fabricated merge material — the throwaway instance built inside `feed_roll()` /
`BagInventory.add_roll()` — never rolls a Manifestation of its own.

That preserves the intended loot decision: an R2 ring with an amazing rule
really can be worth more than an R9 ring with a dull one, it reaches the
player's hands rather than being auto-consumed, and rarity stops being
automatically decisive. Duplicates can still rank that R2 all the way up, so
committing to it is never a dead end.

`manifestation_id` is an exported field on `ItemInstance`, so it rides the
existing `Inventory` → `SaveData` resource path with no migration. Saves written
before this layer load with no rule, which is a legal state.

## Architecture

```
ItemInstance.manifestation_id      identity, exported, rolled once at creation
ManifestationCatalog               the curated library + the roll
ManifestationDef                   id / name / rule / tags / slots / weight / logic
ManifestationRunner (on Player)    watches all 8 slots, owns ALL signal wiring
ManifestationState (shared)        Momentum, Stability, Shards, Mark, Misfortune
ManifestationEffect                base class for one rule
effects/manifestations/logic/*.gd  the sixteen handcrafted rules
```

`ManifestationRunner` connects to each shared gameplay hook exactly once and
dispatches to whichever effects implement the matching method, so sixteen rules
do not each carry connect/disconnect boilerplate.

### Shared gameplay hooks

Implement any subset. The runner filters by owner before dispatching.

| Method | Fired by |
|---|---|
| `on_attack(style_id, origin, target, power_mul, haste_mul)` | `RunEvents.weapon_fired` |
| `on_lucky_crit(position)` / `on_lucky_crit_failed()` | `RunEvents.player_lucky_crit` |
| `on_hit(handle, position, amount, is_crit, is_elite)` | `RunEvents.player_hit_landed` |
| `on_kill(context: EnemyDeathContext)` | `RunEvents.enemy_defeated` |
| `on_damage_taken(amount, position)` | `RunEvents.player_damage_taken` |
| `on_evaded(position)` | `RunEvents.player_evaded` |
| `on_healed(amount)` | `RunEvents.player_healed` |
| `on_building_entered(first_visit)` | `RunEvents.player_entered_building` |
| `on_secondary_completed(objective_id)` | `RunEvents.secondary_objective_completed` |
| `on_followers_changed(change, reason)` | `Global.followers_transaction` |
| `on_gate_ready()` | `RunEvents.gate_checklist_changed` → `ready` |

`player_hit_landed` and `player_healed` are emitted behind
`Signal.has_connections()` guards: both run at horde/per-frame rates and must
cost nothing while nothing is listening. The runner therefore connects each
signal **only while some equipped rule implements a hook that needs it**
(`_sync_world_hooks()`, re-run whenever the equipped set changes). Connecting
everything up front would make those guards permanently true and charge every
player for a layer most runs barely roll.

### Passive contributions

Polled by the player exactly like `ItemEffectRunner`'s:
`get_power_multiplier`, `get_haste_multiplier`, `get_move_speed_multiplier`,
`get_damage_taken_multiplier`, `get_bonus_evasion_chance`, `apply_to_stats(s)`.

`consume_attack_bonus() -> float` is the one-shot channel: every charge, rhythm
and tithe rule reports through it, and the player consumes it **after** the
cooldown gate so a blocked click never eats the payload.

### Shared resources

`ManifestationState` owns Momentum, Stability, Shards, the Mark and Misfortune
exactly once, so "crits make shards" and "a full halo launches" can be rolled on
two unrelated items and still form a machine. A rule claims what it talks about
in `_on_manifestation_ready()` and releases it in `_exit_tree()`; an unclaimed
resource stays dormant and never shows in the HUD.

### describe()

`ManifestationCatalog.describe(id, inst)` builds the logic node **detached** and
sets only `item` and `definition`. `describe()` implementations may therefore
read `item`, `definition`, `potency()` and `threshold_scale()` — and nothing
else. No `player`, no `state`, no scene tree.

## The library

| Rule | Family | Slots | Behaviour |
|---|---|---|---|
| Pilgrim's Momentum | momentum | Move, Ring | travel builds Momentum; full Momentum fires your next attack twice |
| Anchor Rite | stability | Move, Armour, Ring | standing still builds Stability; full Stability makes attacks hit far harder and ranged shots pierce |
| Sunder Wake | momentum | Move, Offhand, Ring | attacking spends all Momentum as a shockwave |
| Third Litany | rhythm | Power, Haste, Ring | every third attack is empowered, only if you let the second resolve |
| Stored Violence | charge | Power, Offhand, Ring | not attacking accumulates Violence; the next attack releases it |
| Predestination Sigil | mark | Power, Haste, Ring | first hit Marks an elite; huge damage to it, less to everything else |
| Impact Scripture | momentum | HP, Armour, Ring | taking a hit detonates your Momentum |
| Martyr Circuit | lowhp | HP, Armour, Ring | healthy = slower, wounded = faster, near death = attacks echo |
| Retaliation Writ | evade | Armour, Move, Ring | more evasion, and every evade answers with a nova |
| Broken Providence | misfortune | Luck, Ring | failed Luck rolls bank Misfortune; the next Lucky Crit spends it all |
| Tithe Furnace | followers | Luck, Offhand, Ring | every eighth attack burns a Follower to empower itself |
| Orbiting Testament | shard | Offhand, Ring | Lucky Crits forge orbiting shards |
| Splinter Dividend | shard | Offhand, Power, Ring | elites shatter into shards on death |
| Vector Halo | shard | Offhand, Ring | one attack in ten curls into orbit; bigger halo; a full halo launches at your aim |
| Heretical Cartography | explore | Luck, Move, Ring | first entry into a building pays; secondaries extend it |
| Overtime Gospel | greed | HP, Luck, Offhand, Ring | staying after the Exit Rite opens escalates Power and Threat |

Three momentum rules, three shard rules, two mark-adjacent rules. Nothing
requires anything. Two of a noun is an accident; three is a build.

## Nouns

| Noun | Channels it owns | Members |
|---|---|---|
| `momentum` | `momentum`, `stability` — two poles of one movement decision | 5 |
| `cadence` | the attack counter and the one-shot attack-bonus channel | 7 |
| `shard` | the orbit, and the Mark | 4 |
| `ward` | HP fraction, the evasion budget, retaliation | 4 |
| `fortune` | Misfortune, Luck contribution, the Follower ledger | 5 |

25 tags over 16 rules; nothing untagged. `ManifestationState.NOUNS` maps each
noun to its channels — Stability is a *channel* of `momentum`, not a noun,
because Momentum builds while you run and Stability while you stand: one
decision with a sign. Splitting them made "these two items hate each other"
read as coincidence rather than design.

`ManifestationSystemTest._test_tag_model()` asserts every rule declares a noun,
every declared noun is registered, **every noun has at least two members**, and
every declared noun is actually referenced by its rule. That last one is a
source-level heuristic and says so — it catches a tag added to the catalog with
no wiring behind it, which is the failure that matters.

### The palette

`data/manifestations/ManifestationNouns.gd` owns one entry per noun: label,
colour, hex and glyph. Nothing else may hardcode a noun's colour.

| Noun | Colour | Hue / Sat | Glyph |
|---|---|---|---|
| `ward` | `Color(1.00, 0.32, 0.30)` | ~2° / .70 | ⬡ |
| `momentum` | `Color(1.00, 0.62, 0.22)` | ~31° / .78 | ➶ |
| `fortune` | `Color(1.00, 0.84, 0.32)` | ~48° / .68 | ✺ |
| `shard` | `Color(0.72, 0.95, 1.00)` | ~192° / .28 | ✦ |
| `cadence` | `Color(0.78, 0.61, 1.00)` | ~264° / .39 | ⚔ |

**Hue and saturation, never lightness.** Every rule overlay and the shared state
itself paint through `BLEND_MODE_ADD`, which washes toward white: two nouns
separated only by lightness become one colour the instant they overlap each
other or a lit sprite. `ManifestationSystemTest._test_noun_display_registry()`
asserts every registered noun has an entry and that no two are within 12° of
hue.

Four of the five were already the de-facto colour of their rules' overlays,
which is independent evidence the noun split matches how the art reads. Cadence
is the exception — its rules painted gold, colliding with fortune — so it takes
the layer's own identity violet, the colour the Run Sheet and the item tooltip
already use for Manifestations as a whole.

A rule's overlay converts its **dominant hue only**, through
`ManifestationEffect.noun_colour()`. Accents, payout flashes and hot cores stay
authored; converting every colour would flatten fourteen hand-drawn overlays
into one. Two rules deliberately opt out and say so in place: Anchor Rite keeps
its cold blue because it paints Stability, the *opposite* pole of the momentum
noun, and Overtime Gospel paints its second noun because its halo is danger
rather than reward.

### The counter

`ManifestationRow` in the HUD's top-left panel, driven by
`HudManifestationController`. The state that matters is **1/2**, not 2/2: a
dimmed `MOMENTUM ◆◇ 40%` is the readout that says one more movement item would
turn something on. `◆◆` at two claimers plus a one-shot flash, `◆◆+n` beyond,
hidden entirely when nothing is live. Structure is rebuilt only on
`manifestations_changed`; values tick at 10 Hz and are written only when the
number at display precision has actually moved.

It is a `Control`, so `accessibility/ability_callouts` cannot switch it off.
That is why it is the load-bearing channel and why it shows *fired* as well as
*full*, pulsing per noun off `ManifestationState.resource_spent`.
