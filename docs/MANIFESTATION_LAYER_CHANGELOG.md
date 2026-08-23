# Manifestation Layer

Behavioural item effects: one curated trigger → behaviour rule attached to a
single item instance, sitting alongside rarity, POS/NEG, sets and augments
rather than replacing any of them. No new equipment slots. Design rules and the
full hook contract are in `docs/design/MANIFESTATIONS.md`.

## Implemented

- `ItemInstance.manifestation_id`: exported identity, rolled once at creation.
- `ManifestationCatalog`: the curated library, the slot-weighted roll, and the
  detached tooltip renderer. 16 rules across movement, attack, defence,
  Luck/Followers, shards and exploration.
- Slot chance decides *whether*, slot pool decides *which*: HP/Armour 22%,
  Movement 26%, Luck 30%, Power/Haste 35%, Offhand 60%, Ring 70%. NEG adds 8%.
  Luck bends the odds on the same diminishing curve as everything else.
- `ManifestationRunner` on the player: watches all eight equipped slots, owns
  every signal connection, and dispatches to whichever rules implement each
  hook. Dispatch order is by slot index so contention over a shared resource is
  stable and explainable.
- `ManifestationState`: one shared blackboard for Momentum, Stability, Shards,
  the Mark and Misfortune, including the shard orbit simulation and drawing.
  Resources are claimed by the rules that speak about them and stay dormant
  otherwise, so three unrelated items can build one engine.
- Six new gameplay hooks on `RunEvents`: `player_hit_landed`,
  `player_lucky_crit` (reported on failure too — a missed Luck roll is
  buildable material), `player_damage_taken`, `player_evaded`, `player_healed`,
  `player_entered_building`.
- Player integration: manifestation power/haste/move/damage-taken multipliers,
  bonus evasion, `apply_to_stats`, a one-shot `consume_attack_bonus()` channel
  consumed after the cooldown gate, and a projectile-shaping channel into the
  managed hit profile.
- `ThreatDirector.add_overtime_pressure()`: a public lever so a greed rule can
  make refusing to leave cost more, not just pay more.
- Presentation: a MANIFESTATION block and a before/after comparison row in the
  item tooltip, a ◆ badge on equipment and bag slots, and a MANIFESTATIONS
  section with live resource meters on the Run Sheet.
- Developer tools: grant a specific rule, roll every worn slot, clear all rules.
  The roll rate is deliberately low, so playtesting the layer by farming drops
  is not practical without them.

## Merging

Merging is never blocked by a rule mismatch, and an item never gains a rule by
being fed. The destination keeps its own Manifestation; the incoming one
dissolves, exactly like every other duplicate property.

The protection sits one level up. `ItemInstance.can_absorb_manifestation_of()`
is not a merge gate — it answers "would feeding this destroy a rule the player
has not seen yet?", and only unattended callers ask:

- `Inventory.add_or_feed()` declines by default, so a ground pickup carrying an
  unfamiliar rule reaches the bag instead of being absorbed on contact.
  Player-driven paths in `InventoryRouter` pass `allow_rule_loss = true`; they
  have already emptied the source slot, so declining there would destroy the
  item.
- `BagInventory` keeps differently-manifested stacks apart instead of
  consolidating them.
- Every automatic merge caller now honours a refused merge instead of assuming
  success — previously `_consolidate_duplicates` nulled the source slot
  regardless of the return value.

Fabricated merge material (`feed_roll`, `BagInventory.add_roll`) never rolls a
Manifestation, so it always feeds whatever rule the destination already has.

An earlier revision made `can_merge()` itself refuse a rule mismatch. That broke
ring progression: at a 70% roll chance across a 16-rule pool most ring
duplicates differ, so roughly two thirds of them stopped merging.
`AuditClosureTest`'s accessory progression assertions caught it.

## Save compatibility

`manifestation_id` is an exported field on `ItemInstance`, so it rides the
existing `Inventory` → `SaveData` resource path with no migration. Saves written
before this layer load with no rule, which is a legal state and the common one.
Covered by a round-trip assertion in `ManifestationSystemTest`.

## Performance

`player_hit_landed` runs per pellet per target per frame and `player_healed`
runs every frame under passive regen, so both emitters are guarded on
`Signal.has_connections()`. For that guard to mean anything the runner's
connections are **demand-driven**: `_sync_world_hooks()` connects a signal only
while some equipped rule implements a hook that needs it, so a player who has
never rolled a Manifestation pays nothing. (A first pass connected everything in
`_ready()` and silently defeated both guards for every run.)

`ManifestationState` stops repainting once the orbit is empty, and the Run Sheet
skips its 10 Hz rebuild while the panel is hidden — a refresh reallocates every
label and asks each equipped rule to format its text.

Four rules (Third Litany, Stored Violence, Martyr Circuit, Tithe Furnace) do
repaint every frame. Their overlays are sine-animated by design — a rhythm
countdown, a growing charge aura, a quickening heartbeat, a coal grate — so the
repaint is what the animation costs, not waste.

## Correctness fixes found in review

- **Exploration was farmable across a chunk boundary.** `IndoorVolume` tracked
  first entry on the node, but volumes are children of streamed chunks and are
  freed and rebuilt past the unload radius. First visit is now keyed on the
  stable seeded `building_id` through `Global.note_building_visit()`, mirroring
  how exploration loot already claims itself.
- **Predestination Sigil's re-entrancy latch was per-instance.** The rule can
  roll on Power, Haste and Ring at once, and a per-node flag only stops a copy
  re-entering itself: two copies cross-triggered through `player_hit_landed` and
  each paid its bonus on the other's bonus hit (~3x the advertised damage at
  high rank). The latch now lives on the shared state, so it covers every copy.
- **The shard sweep mutated the array it was iterating.** `apply_damage`
  re-enters synchronously, so a kill could spend the orbit and forge fresh
  shards mid-sweep — and a shard forged that instant fired immediately instead
  of waiting out its cooldown. The sweep is now bounded to the shards that
  existed when it started and stamps the cooldown before dealing damage.
- **The bag could strand same-rule stacks.** Consolidation remembered one
  destination per item key, so a rival-ruled stack sitting first blocked
  same-ruled stacks from ever finding each other — that item could never rank up
  from its own duplicates. Both the consolidation pass and `add_instance` now
  look for a destination that can actually absorb the incoming rule.
- **A Mark could go invisible.** With two Sigils equipped, unequipping the one
  that drew the marker left the Mark live (the other copy still claims it) with
  nothing on screen. Marker ownership is now an explicit token on the shared
  state, and a surviving copy adopts an orphaned Mark on its next frame.

## Intentional design decisions

- Rarity grows the item, not the rule. `potency()` is capped at ×1.60 and
  `threshold_scale()` eases requirements by at most 22%. Getting the effect is
  the reward; an R20 proc must never become the whole build by itself.
- Rules are never gained by feeding. An item with no rule stays plain no matter
  what it eats, so the roll rate means what it says.
- Some rules deliberately conflict. Anchor Rite rewards standing still and
  Pilgrim's Momentum rewards never stopping; both claim nothing from each other
  and the friction is content.
- Marked-elite kills only detonate when the player gets the credit. A burn tick
  that credits a different source wastes the Mark; the Mark is dropped as soon
  as its handle stops being valid so the damage penalty does not linger.
- Vector Halo self-feeds one attack in ten. As a pure consumer it was a dead
  roll without a producer equipped; the trickle makes it a slow loop alone and a
  fast one when it meets Orbiting Testament or Splinter Dividend.
- Anchor Rite's "carries through enemies" reaches ranged shots through the new
  hit-profile channel (pierce plus reach, and it only ever raises pierce so it
  cannot take away what another effect granted). Melee and magic have no pierce
  concept, so its tooltip states the damage payoff for them.

## Verification

- `ScriptParseAuditTest`: 276 passed, 0 failed.
- `ManifestationSystemTest` (new, headless): 65 passed, 0 failed — catalog
  shape, roll rates against the authored chances, slot-pool legality, the
  detached tooltip contract and the real tooltip widget, every merge invariant,
  container-level protection, shared-resource claim/release gating, and the
  save round trip.
- `ManifestationPlaytestProbe` (new, rendered, needs a display): 19 passed,
  0 failed — runs the real game with an interlocking eight-rule loadout and
  asserts that travelling, planting, critting and being hit each move the
  shared state they are supposed to move, then opens the Run Sheet and checks
  the chain is actually listed.
- `AuditClosureTest`: 61 passed, 0 failed.
- `SaveIntegrityTest`: 29 passed, 0 failed.
- `PlaytestRegressionTest`: 11 passed, 0 failed.
- `EnemyCombatServiceTest` 38, `EnemyDeathEventTest` 10,
  `ProjectileHandleCombatTest` 12, `EnemyLegacyCombatCompatibilityTest` 17,
  `EnemyCombatLifecycleTest` 20, `DotSchedulingTest` 8 — all 0 failures.

The headless suites still report the project's pre-existing ObjectDB/resource
leak diagnostics at shutdown; they do not fail any suite.

The rendered probe was stabilised over ten repeat runs. Two of its assertions
were racing the game rather than testing it: the Run Sheet check bet on one
settle window landing after the HUD's 10 Hz tick (it now polls), and the
stillness check read a final value in a live world where a wandering enemy
shoving the player legitimately resets the clock (it now samples the peak).
Neither was a defect in the layer, but the second is a real playtest question —
see "Open questions".

`PlaytestRegressionTest._test_equipped_duplicate_feed` was made deterministic:
its fixture built both copies through `from_roll`, which now rolls a
Manifestation, so at the armour slot's 22% chance the two copies sometimes
carried different rules and the automatic feed correctly declined — the suite
failed roughly one run in six. Both copies are now built as ordinary material;
the declining case is pinned in `ManifestationSystemTest` instead.

## Open questions for playtest

- **Should being shoved break Stability?** `ManifestationState` counts any real
  travel as movement, so at horde density an enemy bumping into a planted player
  resets Anchor Rite's clock. "Find a firing lane and hold it" reads as the
  intended fantasy, but it may want a small grace window or a knock-immune
  threshold before it feels fair rather than arbitrary.
- **Vector Halo plus Predestination Sigil compete for the same orbit.** Both
  spend shards, and the Sigil can drain a halo before it fills. That is the
  designed friction, not a bug, but it is the first tuning knob likely to want
  attention.
- Manifestations do not affect item value. A rule makes an item more desirable
  but `compute_item_value()` ignores it, so the vendor prices a manifested ring
  like any other. Changing that has to keep the tested invariant that no
  buy → merge → sell sequence nets Followers.

## Not done

- No Manifestation transfer or reroll. Design rule 6 wants that as a rare,
  expensive ritual or vendor action, not normal merge behaviour.
- No dash, so the authored "dashing launches the halo" trigger became "the halo
  launches the moment it fills".
- `ItemEffectRunner.apply_to_melee_slash` is still not wired in `player.gd`
  (pre-existing); the manifestation channel mirrors only the paths that are.

---

# Follow-up: making the families real (phases A–B)

The layer shipped claiming twelve families. `ManifestationDef.family` was read by
nothing that affected gameplay — only two dead accessors, one dict key the Run
Sheet ignored, and three test assertions. The only families that existed
mechanically were those backed by a resource in `ManifestationState.claim()`,
and of five claim keys only two had more than one claimer. **Seven of sixteen
rules claimed nothing at all.**

Monte Carlo over the shipped catalog: two rules sharing real runtime state were
live in **17.0%** of loadouts, three in **1.1%**. The layer's whole promise —
that two unrelated items accidentally combine — was firing about one run in six,
and half of what looked like an engine was two rules wearing the same label
while sharing nothing.

**After retagging the same sixteen rules across five real nouns: 68.4% and
20.6%.** No new content.

## Phase A — foundation, and three latent bugs

- **A noun registry.** `claim()`, `has_source()`, `get_meters()` and the decay
  branch were four parallel `match` blocks over the same five literals, so a
  sixth noun meant four edits that were guaranteed to drift. Replaced with one
  `NOUNS` map of noun → channels plus a `CHANNELS` descriptor table (label,
  kind, cap, full-at, decay rate and gate). Adding a noun is one entry.
- **A contribution ledger.** `shard_cap` and `shard_damage_mult` were public
  fields that each shard rule raised through a hand-rolled four-part additive
  delta convention (`_apply_*`, an `_exit_tree` unwind, a `set_item_instance`
  re-level). A fourth shard rule that *assigned* would have silently clobbered
  the others. They are now methods — assignment is a parse error — reading a
  ledger keyed by contributor. Rank-up is re-registering the same key; removal
  is one `clear_contributions()`. Six functions deleted.
- **The Misfortune cap was on the wrong object.** `BrokenProvidence` clamped its
  own producer at 25 while the state clamped at 999 and `consume_misfortune()`
  zeroed the whole bank. A second producer would have banked past 25 and had the
  excess consumed and thrown away. The cap is now registry data, read statically
  so the detached tooltip path still quotes the real number.
- **Mark ownership moved into the state.** ~40 lines of marker ownership,
  orphan-adoption and hand-off bookkeeping lived in `PredestinationSigil`; a
  second Mark-reading rule would have duplicated it or left the Mark live but
  invisible. The state owns the marker, since the Mark outlives any one rule.

## Phase B — the tag model

- `ManifestationDef.tags: Array[StringName]` replaces `family`. The old field and
  both dead accessors are deleted rather than aliased — an alias would have
  preserved the lie in a new shape.
- **The runner claims, not the rule.** Nine rules hand-wrote claim/release pairs
  that could drift from what they declared. `ManifestationRunner._sync()` now
  claims each declared noun and releases it on removal, so the two cannot
  disagree. All nine pairs deleted.
  - *Claim before release, always.* Dropping a noun to zero claimers resets it,
    so releasing first would wipe the player's bank every time they swapped one
    momentum ring for another. That ordering used to be an accident of
    `queue_free()` timing; it is now deliberate and commented.
  - *Signal wiring learned about nouns.* `_sync_world_hooks()` connects a signal
    only while a rule implements a matching hook. It now also connects while a
    rule *claims* a relevant noun — otherwise moving shared counters onto the
    state would silently disconnect `weapon_fired` and kill the noun.
- **Two tags had to be earned rather than declared.** The new structural test
  refused four tags that were metadata with no wiring. Two were dropped as
  unjustified (Predestination Sigil and Heretical Cartography are honest
  one-noun rules). Two became real behaviour:
  - **Retaliation Writ's nova now spends banked Momentum**, the same pool Impact
    Scripture spends. They are the same behaviour with different triggers, so
    they share an economy instead of each inventing one — wearing both means
    competing for one bank, which is the friction, not a bug.
  - **Overtime Gospel now grants Luck per refused evacuation**, which is what
    makes it share an economy with Broken Providence and the Tithe Furnace
    rather than being a Power stat in a greed costume.

## Verification

`ScriptParseAudit` 276, `ManifestationSystemTest` **73** (was 65),
`AuditClosure` 61, `SaveIntegrity` 29, `PlaytestRegression` 11,
`EnemyCombatService` 38, `EnemyDeathEvent` 10 — all 0 failures. Rendered
`ManifestationPlaytestProbe` 19/19.

---

# Follow-up: phases C–E and H

## Phase C — earning the tags

A tag is only real if the rule genuinely reads or writes that noun. These moved
the nouns from labels into shared runtime state.

- **`cadence`.** Three rules each kept a private attack counter and two also kept
  a private time-since-attack. `ManifestationState` now owns `attack_index` and
  `time_since_attack`; Third Litany, Stored Violence, the Tithe Furnace and
  Vector Halo read them through **join markers** (where in the shared count this
  rule's cycle started) rather than tallies of their own.
  - The counter advances in `_on_weapon_fired`, **never** in the
    `consume_attack_bonus` path — the player reads that bonus before it emits
    `weapon_fired`, so a counter bumped there would be one ahead and every
    "every Nth attack" rule would pay out on the wrong beat.
  - **`repeat_player_attack()` now advances the beat.** One line, and it is what
    turns cadence from a shared read into a shared write: Martyr Circuit's
    death-door echoes carry Third Litany's litany forward.
- **`ward`.** The wound tiers were private constants in Martyr Circuit, so a
  second ward rule would have had to guess where "wounded" was. They are state
  now, alongside `time_since_hit`, a shared `try_retaliate()` gate (Impact
  Scripture and Retaliation Writ answer one hit once *between them*, not once
  each) and the evasion budget with its single clamp.
- **`fortune`.** Misfortune, a lucky-crit tally, and a Luck ledger. Heretical
  Cartography and Overtime Gospel now publish Luck into one pool instead of each
  writing `Stats` directly, so a run carrying both reads as one number. Orbiting
  Testament sharpens its shards with the shared lucky tally, which is what earns
  it the second tag.

## Phase D — the roll, and regression protection

- **Prerequisite weighting** (the Hades Tier-3 idea). A rule whose noun the
  player already carries is likelier to be the one that rolls: `×2` for one
  matched noun, `×5` for both. It biases the **pick**, never the **chance** —
  `slot_chance()` carries a separate promise the suite pins to within 0.04, and
  letting synergy raise the chance would snowball into *more items* rather than
  better-matched ones. Threaded as a defaulted argument, so every existing
  caller and test is unchanged, through the one choke point every drop path
  already funnels into.
- **Deliberately NOT Hades' hard gate.** A Boon is an offer the player opened and
  can reroll; a Manifestation is a property of a drop they did not ask for, so a
  gate would make the first roll of a run dictate every later one.
- **Regression protection is structural, not statistical.** A floor on P(engine)
  cannot detect the regression it would be asked to detect: it saturates, so one
  untagged rule moves it about two points and a floor tight enough to catch that
  would trip on any legitimate tuning. What ships instead: every rule declares a
  noun; every declared noun is registered; **every noun has at least two
  members**; every declared noun is referenced by its rule (a source-level
  heuristic, and the test says so). The seeded 20,000-loadout Monte Carlo is an
  aggregate backstop that prints its three numbers on pass so drift is visible
  long before a floor trips.

Measured through the real roll path: **P(engine) 0.747, P(triple) 0.293,
E[shared pairs] 1.65.**

## Phase E — the dash

The verb half the design kept assuming. Vector Halo fired itself the instant the
orbit filled purely because there was nothing to dash with.

- 160 px over 0.20 s, 1.6 s cooldown, 0.28 s i-frames, 0.12 s input buffer.
  Bound to Shift and left shoulder — **not** Space or pad B, both of which are
  Godot `ui_accept`/`ui_cancel` defaults, and every ability here polls `Input`
  rather than consuming events, so a focused Button would fire both.
- **Distance is flat, not speed-scaled.** i-frames are a time window and distance
  is not: a range that floats with a stat makes the dash a different move on
  every build and turns a NEG movement curse into a silent defensive nerf on the
  verb the player relies on to survive. Cooldown is flat for the same class of
  reason — coupling a survival budget to Haste makes an offence stat quietly the
  best defensive one.
- **It lives on `player.gd`, not a child node.** `_physics_process` dispatches
  parent-before-child, so a child could only ever act after the player had
  already written walk velocity and called `move_and_slide()`.
- **One derived collision-mask writer.** `start_respawn_phase()` is deliberately
  not reused: `get_effective_move_speed()` multiplies by `respawn_speed_mul`
  whenever that timer is live, so a dash borrowing it would leave the player 35%
  faster for two seconds afterwards. And with two naive write sites, a dash
  ending during a respawn phase would restore enemy-body collision early.
- **i-frames are derived from the duration**, so "invulnerable for at least as
  long as you are phasing" cannot be broken by editing one number — otherwise
  contact damage resumes mid-dash while the player is inside an enemy.
- **Vector Halo now launches on the dash, at any shard count**, along the dash
  vector. The on-full auto-launch is gone: two triggers on one resource meant
  the player controlled neither. Removing it exposed a hazard the old code was
  accidentally hiding — `add_shard()` refuses at the cap, so a full orbit with
  the dash on cooldown silently rejects every incoming shard. A one-shot "HALO
  FULL" prompt turns that silent waste into a legible "dash now".
- **No other rule gained `on_dash`.** Stored Violence already works the moment a
  dash exists (its resource is time-since-*attack*). Retaliation Writ fires off
  the Luck roll; a dash trigger would turn a Luck item into a guaranteed 1.6 s
  AoE clock. Anchor Rite's Stability already shatters on a dash through existing
  telemetry — correct friction, zero code.
- The dash counts toward movement telemetry for free (~160 px per 1.6 s, about
  one base move speed), so dashing on cooldown roughly doubles Pilgrim's Momentum
  accrual. That reads as a build rather than an exploit; flagged as a tuning knob.

## Phase F — legibility

The counter is the load-bearing half. Isaac ships no transformation-progress
indicator and its most-installed QoL mod exists largely to add one.

- **`ManifestationNouns`** — one static registry of label, colour, hex and glyph
  per noun. Every overlay blends additively, which washes toward white, so the
  five separate on **hue and saturation, never lightness**: ward red (~2°),
  momentum orange (~31°), fortune gold (~48°), shard cyan-white (~192°), cadence
  violet (~264°). Four of the five were already the de-facto colour of their
  rules; cadence painted gold and collided with fortune, so it takes the layer's
  own identity violet. `ManifestationSystemTest` asserts every registered noun
  has an entry and that no two are within 12° of hue.
- **The colour is now the vocabulary.** The item tooltip colours its
  MANIFESTATION header, its noun list and its rule text per noun; the Run Sheet
  colours the noun counts, the meters and each rule's name; the ◆ item badge is
  the noun's colour rather than one violet for everything. That badge had three
  identical hand-built implementations (`InventorySlotView`, `BagSlot`,
  `HubItemSlot`) — a fourth would have been a fourth place for the palette to
  drift, so it is now one `ui/components/ManifestBadge.gd` and the call sites
  only say where it goes.
- **Nine rule overlays take their dominant hue from the registry** via
  `ManifestationEffect.noun_colour()`. Only the dominant hue: accents, payout
  flashes and hot cores stay authored, because recolouring every draw call would
  flatten fourteen hand-drawn overlays into one. Two deliberate exceptions are
  commented in place — **Anchor Rite keeps its cold blue**, because it paints
  Stability, the *opposite* pole of the momentum noun, and painting it momentum
  orange would make standing still look identical to running; **Overtime Gospel
  paints its second noun**, because the halo is the danger the sermon is buying
  and fortune gold would read as a reward. The overlays were **not** centralised
  into `ManifestationState._draw()`, which would repaint whenever any noun moved
  and discard the per-rule repaint gating that already exists.
- **The counter.** A `ManifestationRow` in the HUD's top-left panel, between
  Threat and the item grid — not the empty column below it, which is where the
  Run Sheet opens, and the counter has to be readable while the Run Sheet is
  shut. `MOMENTUM ◆◇ 40%` dimmed at one claimer is the state that matters: it is
  the "one more item would turn this on" readout. `◆◆` at two, plus a one-shot
  flash; `◆◆+1` beyond. The panel's fixed `offset_bottom` went 270 → 306 or the
  row clips.
- **`HudManifestationController`.** Structure rebuilt only on
  `manifestations_changed`; values on its own 10 Hz accumulator, written only
  when the number *at display precision* has moved. `get_meters()` formats a
  String per meter per call and is left to the Run Sheet. `set_process(false)`
  when nothing is live, woken by `manifestations_changed` and by the runner's
  `tree_exiting` — without that second one a respawn would leave the row bound
  to a freed runner.
- **Popups no longer pile up.** They all spawn at the player, so one kill that
  trips four rules drew four lines on one point. `ManifestationState` hands out a
  per-**frame** popup slot, 16 px apart. Deliberately not a merge: the four lines
  are four rules saying different things. `popup()` was **not** rerouted through
  `progress()` — that hardcodes `entry_scale = 1.0` and would have silently
  discarded the authored 1.10–1.55 emphasis that scales with the payout. The
  renderer gained optional `entry_scale`/`merge_key` instead, reusing
  `progress()`'s replace loop.
- **The accessibility setting was one switch doing two jobs.**
  `BattleText.enabled()` gated *everything* on `accessibility/damage_numbers`, so
  a player who turned the per-hit number spam off also turned off every word the
  Manifestation layer speaks. Split into `damage_numbers` (the stream) and
  `ability_callouts` (named lines), both defaulting on and both with a row on the
  settings screen — neither had one before. No `ignore_setting` flag: that makes
  the setting a lie. The meter row stays the load-bearing channel because it is a
  `Control` the setting cannot touch, and it now shows **fired** as well as
  **full** through a per-noun pulse driven by `resource_spent`.
- **Announcements are split by volume.** A noun reaching two is quiet: the row's
  flash, plus one `RunEvents.tutorial_tip` the *first time ever per noun per
  profile* — tips play serially at ~2.8 s, so three nouns landing at once would
  otherwise queue nine seconds of banner. A pair is loud:
  `ManifestationPairNotifier`, structurally a copy of `SetBreakpointNotifier`
  rather than a reuse of it (that class is hard-wired to `equipment_changed` and
  `SetData`). It caches the live pair set itself and **announces loss too** —
  silently losing your engine is the worst failure available — with a 0.25 s
  debounce so a ground-pickup shuffle collapses LOST-then-GAINED into no card.
- **The first-Manifestation explainer fires on a safe boundary**, the first time
  the player opens the bag while actually carrying a live rule, and **never from
  the equip path**: a non-enemy card skips the dossier spacing and pauses
  unconditionally, so equipping a drop mid-boss would have paused the boss fight.
  It goes through `present_card_and_wait()`, not
  `RunEvents.blocking_info_requested` — the fire-and-forget path discards the
  card id, so a card aborted by a scene change would be marked seen and never
  shown again. `TutorialModalController._unsafe_for_enemy_card` generalised into
  `_unsafe_now(card)` with an opt-in `defer_until_safe`.
- `SaveData.meta_seen_manifestation_cards: Array[String]` holds **prefixed** ids
  (`"intro"`, `"noun:momentum"`, `"pair:…"`) — one field and one migration rather
  than one per card kind — mirroring the `meta_discovered_enemy_ids` round trip
  exactly, and asserted in `SaveIntegrityTest`.

## Phase H — content for the thin slots

- **Fever Litany** (cadence; Haste/Power/Ring) — the anti-Third-Litany. Every
  other cadence rule pays for *waiting*; this pays for sustained fire, so the
  noun contains a real argument instead of three variations on patience. Rolling
  it beside Stored Violence is a deliberate conflict, like Anchor Rite beside
  Pilgrim's Momentum. It also fixes the Haste slot, which had the
  second-highest roll chance in the table against a **two-rule pool in which
  neither rule was about haste**.
- **Scar Tissue** (ward; HP/Armour/Ring) — the layer's only consumer of
  `on_healed`, a hook that was wired with nothing listening. It refuses most
  incoming healing and converts what it refuses into decaying Armour, which makes
  a health pickup a decision rather than a freebie.
- `ManifestationSystemTest` now asserts **no slot draws from fewer than three
  rules** — the roll-rate assertions only ever checked how often a slot rolls,
  never how much variety was behind it.
- A **median-run** check replaces guessing from the forced-eight probe: the
  median loadout carries 3 rules, 29% of runs light an authored pair, and three
  or more pairs at once stays a 6% tail.
