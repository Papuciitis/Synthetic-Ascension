# Gravemarch / Momentum playtest: 2026-09-18

Status: capture and source-code analysis only. No gameplay changes or engine runs. This supplements the 2026-09-17 balance plan; it does not represent results from implementing that plan.

## Evidence

- Capture: `balance_captures/2026-09-18/2026-09-18_00-09-15_25988_48318681_1/`.
- Game version `0.0.0.25.5`, commit `16a53a5671a6`, seed `1790069408878`.
- The commit since the previous capture added the handoff documents and a test UID; no balancing code changed.
- 43,486 consecutive events, no sequence gaps, no dropped records, no wallet discontinuities, no writer failures, artifacts complete.
- Started at segment 1 with no equipment. Dragonborn, native melee; assembled six-piece Gravemarch by the segment-2 shop. Later used Momentum / Lunge / No Brakes / BLINK, Oakheart, Regeneration Ring, Sprint Servos, Magic Missile and Tesla Aura.
- All sampled god-mode flags were false, enemy debug HP multiplier was 1, and recorded developer currency grants were zero. Dev mode and the revelation debug flag were enabled; this is not proof of a completely ordinary release configuration.
- One 0.35 time-scale sample occurred during the opening; OpeningSequenceController sets that value for its cinematic. Other samples were 1.0.

## Outcome

Cleared segments 1-10. The application closed in the segment-11 shop, with zero segment-11 gameplay time. This was neither a failed run nor proof of a complete endgame clear.

- 56.07 gameplay minutes; 43.48 hub minutes; 103.32 elapsed minutes overall.
- 25,215 kills, seven deaths, seven paid reconstructions.
- Deaths by segment: 2 = one; 6 = two; 7 = one; 8 = two; 10 = one. All seven occurred in collapse.
- The two repeat deaths within the same segment occurred 35.78 and 30.54 gameplay seconds after reconstruction. The prior run's 4-6-second reconstruction death loop was not reproduced here.
- 48,519 combat income; 30,800 Ascension purchase spending; 7,457 reconstruction spending; closing wallet 16,424. The final shop sale added 3,475 after completing segment 10.

## Comparison with the September 17 ranged run

Different race, style, gear, seed, Ascension choices and starting segment: this is an observational comparison, not a controlled test of a single feature.

| Segment | Earlier ranged deaths / seconds | New melee deaths / seconds |
|---|---:|---:|
| 5 | 2 / 423.53 | 0 / 296.66 |
| 6 | 2 / 390.01 | 2 / 318.12 |
| 7 | 9 / 528.01, failed | 1 / 433.52, completed |

Using the last living samples in segment 7:

| Quantity | Earlier ranged | New melee |
|---|---:|---:|
| Max HP | 216.04 | 340.62 |
| Armour | 5.26 | 115.27 |
| Item damage-taken multiplier | 1.0000 | 0.6951 |
| Raw-damage health budget before temporary effects | 227.40 | 1,054.97 |
| Applied lifesteal during segment | 397.49 | 997.41 |

The health budget is `HP * (1 + armour/100) / item_damage_taken_multiplier`, for attacks using normal armour. The new value is about 4.64 times the old one. It excludes healing, evasion, temporary guards and other conditional effects; it is not a full survival simulation.

Across the new session, lifesteal applied 4,509.80 HP, 42.10% of all applied healing. Generic healing applied 4,681.05; the ring calls the generic heal path, so the log cannot attribute that entire amount to the ring. Exit healing applied 1,349.68. The build also activates shard/ward protection through Reliquary Guard; zero Manifestation damage multipliers in samples mean a conditional guard was available at the query, not continuous invulnerability.

## Item growth remains weak

Max HP at the ends of segments 5 and 9 was 339.54 and 341.77: only +2.23 HP, about 0.66%, despite equipment progression.

Final recorded item contributions below are authored flat contributions before the character's slot-roll multipliers:

| Item | Effective rank | Flat contribution |
|---|---:|---:|
| Gravemarch Vessel | 11.32 | +20.24 HP |
| Gravemarch Carapace | 11.78 | +2.25 armour |
| Gravemarch Censer | 13.18 | +0.07439 Power |
| Gravemarch Clockjaw | 9.59 | -0.000634 Haste |
| Oakheart | 11.39 | +71.32 armour, +40.88 HP |
| Regeneration Ring | 11.04 | +20.24 HP |

Oakheart additionally supplied about 30.81% separate damage reduction at the end. Its flat armour was about 32 times the armour-slot item's flat armour. The armour-slot roll still multiplies the character's armour pool, so its full value is larger than its own flat contribution; keep that distinction in comparisons.

HP dropped from about 342 to 239 entering segment 10 because the recorded doctrine rules gained `max_hp_mul: 0.7`. This matches Perfected Engine's authored -30% HP cost, +35% Power and +2 equipped augment levels. It is an intended choice, not evidence of an item losing its HP upgrade.

## Pressure and deaths

- The sampled enemy damage multiplier reached its 30x cap in every segment from 5 through 10. Segment 7 enemy HP multiplier reached 29.39x.
- Only two deaths had an active exit channel in the last preceding sample, in segments 7 and 8. All deaths occurred in collapse; do not equate collapse with standing inside the channel.
- Spitters accounted for 41.68% of hit-related HP loss; contact swarm 39.25%. Together they were about 80.94%. Snipers accounted for only 42.76 HP in the entire run. These are exposure-weighted totals, not per-attack strength comparisons.
- The build carried one Overtime Gospel from segment 3 and two from segment 6 onward. The runner instantiates each equipped copy separately. Each provides rewards and advances the overtime clock. Thus the build itself adds pressure; do not attribute all escalation solely to the ambient overtime formula or assume deliberate farming.
- Detailed ability ancestry is absent from this recorder. It cannot prove whether BLINK, basic attacks, Gravemarch procs or a particular Manifestation contributed most of the outgoing damage.

## New finding 1: Death Rattle health costs are missing from the report

The loadout activates the cadence + ward pair, Death Rattle. While wounded, sufficiently fast use of its held beat spends roughly 4-5% max HP per payment, stopping at 1 HP. This can compete with recovery precisely when the player is trying to attack and lifesteal back to safety.

`effects/manifestations/pairs/DeathRattle.gd:194` computes the cost, and line 204 directly assigns player HP. It does not emit the paid-health event consumed by the recorder. The report therefore shows `HP intentionally paid = 0` despite visible health reductions consistent with these costs.

Concrete segment-6 example, approximately global gameplay seconds 1703.40 -> 1704.43:

- HP fell from 43.796 to 32.580.
- Applied healing in the interval was 29.426.
- Recorded hit damage was zero; max HP stayed 340.004.
- Reconciliation requires 40.641 additional HP loss, matching three payments of approximately 13.547 HP.

Additional intervals show matching multiples of the same payment. This is strong evidence that Death Rattle is draining health omitted from the report. The capture does not log individual payments, so do not present an exact whole-run Death Rattle damage total. Generic healing totals also cannot be interpreted as net recovery without accounting for health costs.

Recommended next implementation: route intentional costs through the existing paid-health reporting boundary while preserving nonlethal behaviour and bypassing armour/evasion. Test the real pair event path, cost timing and health reconciliation. Instrument other direct HP adjustments separately; do not turn a healing takeback into enemy damage.

## New finding 2: recorder snapshots consume a defence

This should precede further balance tuning.

1. `autoload/BalanceRecorder.gd:355` queries each runner's `get_damage_taken_multiplier()` during periodic snapshots, including gameplay-mode samples while paused.
2. `core/systems/manifestations/ManifestationRunner.gd:656` calls `state.consume_composure()`.
3. `core/systems/manifestations/ManifestationState.gd:573` resets the stored ward readiness and returns 0.55 when the six-second Composure guard is ready. That guard should reduce a real incoming hit by 45%.

Consequently a recording query can spend the next-hit defence without an incoming attack. There are 175 gameplay-mode samples reporting the resulting 0.55 multiplier; 174 were live and unpaused. Zero-multiplier samples can conceal additional consumption, so 175 is not an exhaustive total of all possible state changes.

Reliquary Guard's getter also arms a pending-hit latch. The sampler therefore crosses a second mutation boundary even though a sample is not a hit. Do not treat these getters as read-only merely because their names start with `get_`.

Recommended next implementation: add a side-effect-free preview/snapshot API, preserving the consuming path for actual landed hits. Test that repeated snapshots do not change ward readiness, pending-hit latches, shards, cooldowns or player HP; a subsequent real hit must consume exactly the intended defence once. Include paused/dead sampling. The code establishes the bug, but this analysis did not run a Godot regression test or quantify which deaths it changed.

## Implications for the existing balance plan

1. Fix snapshot side effects and missing health-cost reporting before collecting the next comparison.
2. Keep meaningful core-item progression and the accessory-versus-armour-slot comparison as priorities. This run supports those concerns even though the build progressed further.
3. Evaluate Oakheart reductions together with replacement armour/HP growth. It currently supplies much of the successful build's protection.
4. Test the proposed exit encounter against both this melee build and the previous ranged build. Preserve the user's intended aimed-sniper pressure and occasional melee arrivals.
5. Include Death Rattle, Reliquary Guard and duplicate Overtime Gospel in interaction tests. Bigger flat stats alone do not explain these mechanics.
6. Keep Ascension redesign deferred. Compare fixed choices and flag concerns for the separate tree review.

No original balance-plan values were changed by this analysis.
