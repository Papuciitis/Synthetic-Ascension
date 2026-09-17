# Follower economy audit

13 September 2026 · gameplay baseline `b4845e7` · Godot 4.7.1

## Verdict

**Keeping roughly 4,000 Followers attainable in the first two segments is compatible with this game. The spending, progression and late-run income systems do not currently form an economy around that starting point.**

The intended arc is survivor combat, consequential run decisions and increasingly absurd build interactions, continuing well beyond ten segments and eventually accommodating billions of Followers. The fix must preserve early progress and spectacular builds while giving equipment, tree investment, survival and future ambitions meaningful claims on the same reserve.

This audit changes no gameplay balance. It adds a reproducible diagnostic, its measurements and this assessment. Proposed corrections below are recommendations, not implemented or playtested prices.

## What was actually checked

- Read the task **“audit the idea”**, including the user's corrections about long runs, uncapped income and fun chaos, and its final V4 deliverables dated 12 September.
- Traced the current project’s acquisition, transactions, vendor stock, pricing, free reward cards, reconstruction, tithes, drains and save fields.
- Generated **100 ten-item vendor stocks at each of six segment indices: 6,000 actual item instances**, using production generation and pricing, seed 20260913, zero Luck and no equipped items. These are controlled samples, not observations of a particular player's run.
  Price summaries select sorted observations at indices `floor(n/2)` and `floor(0.9n)`; the median is the upper middle observation for these even sample sizes.
- Killed controlled enemy fixtures through both production death paths, with ordinary rewards and maximum overtime decay.
- Exercised production belief, reconstruction and in-memory save snapshot functions.
- Ran the existing `AuditClosureTest`: **93 assertions passed, zero failed**. Its buy → merge → sell checks remained lossy, with worst tested margin −2 Followers. That suite also emitted shutdown object/resource/RID leak diagnostics; its exit code and assertion result do not imply clean teardown.

The dedicated economy probe exited successfully without warning/error diagnostics. The user's 4,000-Follower observation is the early-wallet benchmark; this audit did **not** reproduce a timed two-segment run or establish a reliable late-run income rate.

## 1. The shop loses purchasing tension very early

The production vendor creates ten offers. Its ordinary rarity range rises with segment, but the lower bound stops at rarity 8 and the upper bound at 10. Further rarity promotions remain possible; those bounds are not an absolute item-rarity cap.

| Shop before segment | Median item buy price | 90th-percentile item | Median cost of all ten offers |
|---:|---:|---:|---:|
| 2, after completing 1 | 116 | 193 | 1,232 |
| 3, after completing 2 | 154 | 237 | 1,570 |
| 5 | 202 | 289 | 2,043 |
| 10 | 305 | 428 | 3,120 |
| 20 | 484 | 597 | 4,832 |
| 40 | 474 | 607 | 4,825 |

At the supplied 4,000 benchmark, a typical item after segment 2 uses **3.85%** of the wallet. The wallet can fund about 26 median-priced items, or two complete median-priced stocks, before any sale proceeds. Inventory capacity and build compatibility still constrain purchases, but Followers provide little pressure to choose between ordinary offers.

The similar segment-20 and segment-40 samples are especially significant: production stock does not acquire a million/billion-scale price through progression. Rare outliers and valuable merged items do not solve the affordability of ordinary stock.

**Root cause:** item value is mostly a quadratic rarity term, quality, stats, scripted value and set membership. It has no movement-scale valuation. It is inaccurate to say all item prices are literally fixed, but their growth is far too narrow for the intended economy.

**Correction:** tune useful equipment against competing tree investments at representative progression budgets. Preserve cheap minor supplies where appropriate, but make desirable gear and build-defining pieces compete with saving. Establish this using predetermined item/tier values, not a price that rises merely because the player has money.

Evidence: `autoload/global.gd:2030` (`compute_item_value`, buy/sell helpers); `ui/screens/HubShop.gd:1383` (`_generate_vendor_stock`); `core/systems/items/ItemGenerator.gd:5` (promotion probability).

## 2. Cheap refreshes let wealth buy away uncertainty

Actual successive refresh prices are:

`3, 5, 9, 16, 28, 49, 86, 151, 264, 462, 808, 999, 999…`

The first five cost **61 total**, revealing another 50 offers for 1.525% of a 4,000 wallet. The counter resets each completed segment. After eleven previous refreshes, the price reaches its **999 cap** and stops growing. That cap becomes trivial at millions of Followers.

The game correctly persists stock so reopening the shop cannot reroll it for free. However, paid rerolling is so cheap that it can still replace adapting to offers with searching repeatedly for the preferred combination.

**Correction:** price the service relative to the authored economy stage, with understandable successive charges. Avoid a permanent numerical cap that makes late-run searching effectively free. Keep the existing stock persistence. Test affordability in terms of offers inspected per hub, not just one refresh's price.

Evidence: `ui/screens/HubShop.gd:75`, `:94`, `:1349`; `autoload/global.gd:1889`.

## 3. Belief stops expressing growth at 225 Followers

The actual formula is `min(0.15, 0.01 × sqrt(current_followers))`.

| Current Followers | Belief Power |
|---:|---:|
| 100 | +10% |
| 225 | +15% |
| 4,000 | +15% |
| 1,000,000 | +15% |
| 1,000,000,000 | +15% |

The cap is already reached at **5.625% of the early 4,000 benchmark**. Meanwhile, spending below the cap can still lower the bonus, creating a small early hoarding incentive without a meaningful later movement-growth payoff.

**Correction:** distinguish spendable support from durable evidence that the movement has grown. Use an explicit progression record for belief/world milestones while preserving the single spendable wallet. Define whether that record means genuine recruited Followers or the highest held reserve: these produce different incentives. A peak-wallet gate deliberately encourages saving; cumulative recruitment does not. Sales, refunds, save restoration and trade undo must not masquerade as newly converted people.

This does not require damage to grow without limit. Larger congregations can unlock capabilities, transformations and world responses while individual combat multipliers remain manageable.

Evidence: `autoload/global.gd:821`; transaction accounting at `:360`; save fields `autoload/SaveData.gd:38` and `:74`.

## 4. The late-run income engine is missing

Ordinary kill rewards remain at the enemy definition's small base amount. Defaults give one Follower; Brutes give 2–3, Heralds 5–8 and the two ordinary boss definitions 10–14. Elite bonuses and Luck/Cult procs add small fixed amounts. Neither death path multiplies conversion by segment or a wider movement scale.

Boss-arena completion adds 25 and miniboss completion 8, beyond the boss's own kill reward. Other objectives can give gear and progression; they generally do not provide large direct recruitment payments. Selling found gear is another income source and must be included in any future income study.

Enemy mix, kill speed, elite frequency and loot sales mean income is **not proven constant**. Nonetheless, a very large increase in congregation size cannot be assumed to emerge from current per-body rewards. As an illustration only, at a sustained 2,000 Followers per segment, one billion would require 500,000 segments before spending. Making only the final purchase cost a billion would create a grind wall.

**Correction:** provide an explicit mechanism by which later victories convert or mobilize larger populations. Scale the relevant recurring rewards and costs coherently. Growth can follow reached regions or escalation stages; actual kills, objectives and performance must still determine what the player earns. This is compatible with uncapped early income and with forward progress being attractive.

The older repository's proposed Reach factor addresses this structural gap, but its `1.35^(segment−2)` ratio and 6,000 base gross were assumptions, not validated pacing. Under that ratio, segment-40 gross would be about **179M at a 2,000 base versus 538M at a 6,000 base**, before losses and spending. That uncertainty materially changes when billion-scale purchases become possible.

Evidence: `core/actors/enemy/modules/EnemyLifecycle.gd:89`; `core/systems/enemy_world/EnemyCombatService.gd:121`; `core/actors/enemy/EnemySpec.gd:29`; corresponding `EnemySpec_*.tres`; `scenes/world/events/BossArena.gd:39`, `MiniBossArena.gd:40`.

## 5. V4's prices do not support the intended final scale

**This also needs correcting in my own previous output.** V4’s structure and its provisional prices must be assessed separately.

| V4 purchase / route | Followers |
|---|---:|
| Entry local | 200 |
| Q ability / fork | 800 |
| First Gate | 1,600 |
| Revelation | 4,800 |
| Fusion | 1,800 |
| Ascendant node | 20,000 |
| Supplied complete focused routes | 11,600–13,600 |
| Supplied Three-Core avalanche route | 71,000 |

The full route is **71,000**, not merely the 20,000 terminal node: prerequisites matter. Its cost is still only 17.75 times the early 4,000 benchmark. It cannot serve as a billion-scale final ambition if these prices are retained while income starts growing rapidly.

V4 explicitly calls these first-playable numbers, fixes prices by node type, uses increasing repeatable-sink prices, and promises to tune from observed income. That qualifies the result; it does not finish the economy. Structural route validation checked legality, not long-run affordability or player time.

There are currently three different states:

1. **Live game:** small per-enemy income, current-wallet belief, the existing shop and free milestone doctrines. No purchaseable V4 tree.
2. **6 September repository proposal:** Reach growth, expensive capital nodes, peak gates, per-class escalation and paid Revelation operation.
3. **12 September external V4:** changed tree/recipes, much smaller prototype prices, charge-based Revelations and different respec rules. Its graph and browser live outside this repository.

**Correction:** choose one explicit production economy for V4. Preserve the ability to form a recognizable engine early; reserve later transformations and cross-Core ambitions for the larger scale. Treat early build identity, a developed build and final ascension as different milestones. Do not blindly combine the old Reach growth with V4's cheap terminal prices, or reinstate old per-cast charges as though V4 already approved them.

Sources: `docs/design/ASCENSION_TREE_SPEC.md`, sections 3.2–3.10; external `Synthetic_Ascension_V4_Full_Tree.md`, “First playable economy”; `Synthetic_Ascension_V4_Validation.md`. External package location: `C:/Users/NaurisKrišjānis/Documents/Codex/2026-09-11/aud/outputs/`.

## 6. Free reward cards are not inherently the problem

Two distinct existing reward flows need separate treatment:

- Augment offers select one option, add it to a slot or upgrade an owned augment. Segment-completion picks are scheduled at 2 and 7; the fresh-profile introduction also has an initial offer. Augment ownership/levels have persistent profile fields.
- Method, Doctrine and Apotheosis offer a single committed choice after 3, 6 and 9. Some options impose permanent-for-the-run drawbacks such as reduced maximum health or healing. Their `price_text` describes those tradeoffs, not a Follower bill.

These cards do not debit Followers, so they cannot absorb the wallet surplus. But choosing one reward and losing the alternatives is a real opportunity cost. Charging every earned reward would make money govern both guaranteed development and optional investment, and could deny early build identity after losses.

**Correction:** keep milestone rewards meaningful on their own terms and place paid choices where shopping, branch investment and saving should compete. Evaluate whether each free option changes the build and gives up a desirable alternative. Do not treat “costs zero Followers” as sufficient proof that a reward is badly balanced.

There is also a **cadence gap**: the current completion handler schedules no additional augment picks after 7 and no doctrine stages after 9. Segments themselves continue; completion increments the segment without an upper limit. That explains why the structured reward progression feels front-loaded even though the game does not literally end at segment 10. V4's recurring Evolution rewards are a proposal, not live behavior.

Evidence: `ui/augments/AugmentSelect.gd:100`, `:171`; `autoload/global.gd:1225`, `:1875`, `:1913`; `data/major_choices/doctrines/`; `scenes/game.gd:356`.

## 7. Several supposed sacrifices have negligible financial weight

| System | Current amount | Share of 4,000 |
|---|---:|---:|
| Tithe Furnace payment | 1 per eligible proc | 0.025% |
| Tithe Rhythm payment | 1, with a possible kill refund | 0.025% |
| Debt Collector payment | 1 per Lucky Crit | 0.025% |
| Leech / Herald drain | 1 per drain tick by default | 0.025% |
| Tithe Bones, representative severity 0.5 | 22 per full health bar damaged | 0.55% |
| Wager Shrine: first / second / third total commitment | 8 / 30 / 85 | 0.2% / 0.75% / 2.125% |
| Manufactured Witness rescue | 100, once per segment | 2.5% |

The shrine takes **incremental stakes 8 + 22 + 55**; calling the final tier simply “55 total” understates its cost. It can award rarity 7–10 equipment at its final tier, subject to success and item generation. It is not an unlimited guaranteed cash payout.

Tithe Bones actually charges `22 × (0.5 + severity)` per health bar. Proc frequency also matters: one Follower per high-frequency event can accumulate. These mechanisms need total-per-minute or total-per-segment measurements, not just inspection of one proc. Even so, flat one/22/100 amounts clearly lose relevance at millions and billions.

Manufactured Witness's 100-Follower rescue competes against reconstruction consuming at least 20% of the wallet. At one million, this is 100 versus at least 200,000, although the rescue also incurs Threat and has a once-per-segment limit. Its monetary tradeoff approaches zero as wealth rises.

**Correction:** give operating costs authored scale units or an appropriate explicit percentage-plus-minimum for insurance effects. Measure the total burden of a functioning build. Keep its core attacks enjoyable to use; arbitrary charges on every button would undermine the desired chaos. Preserve the different personalities of optional tithes, compulsory debts and safety-respecting curses.

Evidence: `effects/manifestations/logic/TitheFurnace.gd:115`; `effects/manifestations/pairs/TitheRhythm.gd:120`, `DebtCollector.gd:219`; `effects/items/logic/curses/TitheBonesCurse.gd:15`; `core/systems/world/objectives/WagerShrineObjective.gd:26`, `:96`; `autoload/global.gd:1148`.

## 8. Confirmed reward bugs precede numerical balancing

### Zero-reward bodies become income

The active-actor path unconditionally wraps the reward in `maxi(1, round(reward × overtime_multiplier))`. It does so even when overtime has not started. The data-only proxy path applies the wrapper only when the reward was positive.

The runtime probe demonstrated:

| Authored base | Multiplier | Active actor pays | Data-only proxy pays |
|---:|---:|---:|---:|
| 0 | 1.00 | **1** | **0** |
| 0 | 0.35 | **1** | **0** |
| 1 | 0.35 | **1** | **1** |
| 2 | 0.35 | 1 | 1 |
| 3 | 0.35 | 1 | 1 |
| 5 | 0.35 | 2 | 2 |

Summoned Minions explicitly have zero Follower rewards and zero elite bonus. The opening officer and containment construct also have zero base rewards, although the opening narrative separately suppresses combat recruitment until the assistant milestone. The reward floor undermines authored zero rewards; it is not evidence that the user's entire 4,000 surplus came from this bug.

### One-Follower enemies ignore overtime decay

Both paths keep a one-Follower kill worth one even at the maximum 65% reduction. Thus the reward multiplier can pass its existing function tests while actual ordinary recruitment is unchanged. Some higher reward types do lose value, and overtime danger still rises.

**Correction:** consolidate reward resolution, preserve genuine zero rewards, and settle fractional positive earnings consistently. A fractional accumulator can pay whole Followers over several kills while preserving the intended average; a seeded stochastic rule is another option. Keep zero-reward eligibility explicit so elite or recruitment procs cannot accidentally bypass it. Test actual wallet changes through both death paths, with Luck/Cult, elites and overtime, and preserve Overtime Gospel's explicit exception.

Evidence: `core/actors/enemy/modules/EnemyLifecycle.gd:110`; `core/systems/enemy_world/EnemyCombatService.gd:142`; `core/actors/enemy/EnemySpec_SummonedMinion.tres:13`; `autoload/ThreatDirector.gd:388`. Existing tests around `tools/tests/ManifestationSystemTest.gd:1075` check the multiplier, not these payout results.

## 9. Reconstruction gives inconsistent spending advice

Actual reconstruction is:

`max(ceil((10 + 2 × (segment−1)) × 1.7^deaths_this_segment), ceil(0.20 × current_wallet))`

It is a **maximum**, not “flat cost plus 20%”. This already scales a major loss with wealth. But it depends on the wallet remaining at death, so purchasing durable power before danger also reduces the later bill. That may be a deliberate tension; it must be included in balance simulations.

Two concrete correctness issues accompany it:

1. **An exact reserve cannot buy survival.** In segment 2 with no previous deaths, 12 Followers quotes a 12 cost; consumption leaves zero. `player.die()` respawns only if the remaining count is strictly greater than zero. Several protective spenders allow leaving exactly the quoted cost, despite promises to preserve the next reconstruction. The probe confirms the zero remainder and the failed respawn condition. A consistent policy must either permit a paid reconstruction at zero or reserve one additional Follower everywhere.
2. **Shop warnings use the old wallet's quote.** Starting with 4,000 gives a quote of 800. A trade leaving 500 is warned that death would end the run because 500 < 800; the actual next quote at 500 is 100, leaving 400 after death. Conversely, an exact-flat-reserve case can escape the shop's strict-less-than warning. The warning should evaluate the actual post-trade survival rule.

Refreshes merely check affordability and can also consume the entire reserve; they do not use the trade's reconstruction warning. That is a policy/UI consistency issue to decide explicitly.

Evidence: `autoload/global.gd:2008`; `core/actors/player/player.gd:1158`; `ui/screens/HubShop.gd:1118`, `:1349`; `core/systems/world/objectives/WagerShrineObjective.gd:133`; `effects/items/logic/curses/TitheBonesCurse.gd:75`.

## 10. The project cannot yet explain the money curve

The transaction function already publishes reason-labelled wallet changes. This is a good foundation. However, the persistent model principally keeps current attempt Followers and an all-time best wallet recorded when writing a save; it does not keep a complete attempt recruitment/spending history or the proposed attempt peak. A transient high wallet can therefore be missed by that save-time record.

Combat base rewards, Luck extras and Cult extras are merged into one `combat_influence` amount. Trade reports net movement plus buy/sell totals. The current Run Sheet's BELIEF row shows the wallet, not an income-and-spending breakdown.

**Correction:** capture per-segment opening/closing reserve, genuine recruitment by source, sales, gear purchases, refresh count/cost, tree purchases, operating costs, death losses, elapsed combat time and milestones. Track grants/undo/refunds separately. Measure fresh profiles and developed profiles because persistent augments and stash items can change early power and cash generation.

One billion is not currently blocked by the basic wallet field: the probe preserved 1,000,000,000 in the in-memory attempt save snapshot. This was not a disk round-trip, large-number UI or extreme-endless-overflow test.

## Recommended correction order

1. **Repair reward and reconstruction correctness.** Shared reward settlement, zero-reward eligibility, fractional overtime earnings, and post-spend reconstruction checks. These affect the reliability of every later measurement.
2. **Choose V4's production progression scale and record the money flow.** Retain the early 4,000 benchmark. Specify milestones for first working engine, developed specialization, hybridization and billion-scale ascension. Do not use segment 10 as the endpoint, and do not defer every exciting mechanic until the billions.
3. **Balance the whole shared budget.** Price equipment, local tree growth, major branch commitments, searching and operating costs together. A useful early acceptance target is that the player can fund a few meaningful priorities but cannot routinely buy every attractive offer and branch at the same hub. Numerical prices must follow those choices and observed rates.
4. **Provide the late-run acquisition curve and recurring decisions.** Make later recruitment larger and let reward opportunities continue beyond the early scripted milestones. Preserve free earned picks where their opportunity costs work.
5. **Run long, varied economic replays.** Include fast clears, prolonged farming, low/high Luck, deaths, frequent spending, deliberate saving, refund/undo flows and stash starts. Check purchase timing and time spent at each scale, not just ending balances. Keep equipment resale/merge tests when changing valuation: revaluing old stock at each new scale could introduce arbitrage that does not exist now.

The key design constraint is **meaningful choices at every scale while the build grows more outrageous**. Raising shop prices alone would leave early belief saturation, the weak long-run income curve, cheap terminal V4 progression, flat sacrifices and post-segment-9 reward cadence unresolved.

## Reproduce the measurements

From this project, run Godot 4.7.1 headlessly with `res://tools/tests/FollowerEconomyAuditProbe.tscn` as the main scene. It prints a single `AUDIT_JSON=` record. No save slot is loaded; autosaving is disabled in the probe process.

Probe: `tools/tests/FollowerEconomyAuditProbe.gd` and companion `.tscn`.

Captured data: `docs/audits/2026-09-13-follower-economy-measurements.json`.

All source line references above refer to the audited gameplay baseline. The probe is diagnostic: successful execution means it measured current behavior, not that the economy or the reproduced bugs passed acceptance criteria.
