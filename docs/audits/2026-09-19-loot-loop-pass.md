# Item and loot degenerate-loop pass, 2026-09-19

Scope: every way the item layer could manufacture Followers or items, or
let the player skip its own progression: vendor -> merge -> undo, equip-feed
exploits, rarity bypasses, infinite Follower loops. Findings are marked
**verified** (a test pins them, or the code path was read end to end) or
**read** (code read, no test). Proposals are not coded.

Code read: `data/items/Inventory.gd`, `BagInventory.gd`, `StashInventory.gd`,
`ItemInstance.gd`, `core/systems/items/RarityMath.gd`, `ItemGenerator.gd`,
`LuckResolver.gd`, `core/systems/inventory/InventoryRouter.gd`,
`ui/screens/HubShop.gd` (trade, undo, refresh, stock, quick moves),
`autoload/global.gd` (pricing, follower transactions, guaranteed delivery,
drop context, Ascension buy/refund), `core/systems/ascension/AscensionLedger.gd`
(price, refund), `core/systems/world/objectives/WagerShrineObjective.gd`,
`scenes/world/pickups/ItemPickup.gd`, `core/actors/enemy/modules/EnemyDrops.gd`.

Tests: `tools/tests/LootLoopTest.tscn` (new, 22 checks) plus the existing
`InventoryRouterTest` (111), `PlaytestRegressionTest` (11) and
`AuditClosureTest` (93), all green at this commit.

## Verdict

No Follower-creating loop exists in the item layer. Every buy, merge, sell,
consolidate and undo path is lossy or neutral to the Follower, at every
rank, roll and Luck, on every item in the database. The two real problems
are design-level: **Ascension refunds are total and available mid-run**, so
any node can be rented for free; and **the vendor and the wager shrine sell
rarities the drop system withholds**, so the segment's rarity soft cap only
binds enemies. One silent-loss trap exists in equip-feeding.

## 1. Vendor, merge, undo (verified)

| Path | Rule | Result |
|---|---|---|
| Sell then buy back | sell = value x 0.55 x (1 + 0.08 luck), buy = value x (1 - 0.12 luck) | Buy is at least 1.48x the sell price for the same instance at any Luck (2,912 cases: every item x ranks 0-30 x rolls x Luck 0-100k). |
| Vendor buy -> merge -> sell | merge mass = quality x 2^((incoming - dest) / 1.5), overflow x 0.63; value = base(r) x quality + stats + progress | Never positive on any real item at the revision-2 curves (30,208 cases: dest ranks 0-15, meters 0/0.5, all authored rolls, material one rank below to three above, Luck 0/100). Two cases break exactly even (`conduit_charm` R1 fed a maximum-roll R0 at Luck 100); none gain. |
| Bag auto-consolidation | same id + polarity merge on pickup and on every stack change; locked stacks exempt; manifestations must match or be absent | Total sell value never rises beyond one Follower of rounding per merge (60 random multisets). The vendor's own bag has `auto_consolidate = false`, so a sold duplicate never ranks the vendor's copy (`PlaytestRegressionTest`). |
| Hub undo | snapshot of Followers, equipped, bag and vendor before the trade; restored by copy; cleared on any equipment, bag, stash, lock, refresh, augment or screen change | Snapshot copies carry identical value, meter, lock and manifestation (312 cases). Undo restores the Follower delta with `trade_undo`, which the balance ledger classes as an adjustment, so a trade + undo is invisible to income. |
| Vendor refresh | 3 x 1.75^n, capped 999, counter reset with each segment's fresh vendor | Refreshing then selling bought stock is lossy by the buyback rule; refreshing to *equip* is a power path, not a loop (see the follower economy audit, section 2). |

What undo does not cover (read): the refresh counter (irrelevant, refresh
clears undo), the profile's autosave (a trade and its undo both save
immediately, so quitting between them never rolls anything back), and
`hub_sell_marks_*` (cleared by `_clear_selection` after every trade and
undo).

## 2. Ascension buy -> refund (verified neutral; design gap read)

`AscensionLedger.refund` returns the full recorded price of the node and
of every node whose requirement or adjacency it breaks, sinks included
(1,466 back for three sink ranks), and `Global.ascension_refund` credits
all of it. 25 buy/refund cycles leave the wallet exactly where it started.

The gap: the tree opens **mid-run on the tree key** (`hud.gd`, action
`ascension_open`) with the same Refund button as the Hub, and nothing in
`Global.ascension_refund` or the ledger checks where the player is. So a
4,800-Follower Revelation, a Q, a Keystone or a Catastrophe can be bought
before an encounter and refunded after it at zero cost, and a build can be
re-specced between rooms for free. The V4 design specified Hub-only
refunds, a share that shrinks with the segment
(`0.5 x 0.9^(seg-2)`, floor 0.1), and no refund for Revelations, forks,
Gates and bridges.

## 3. Rarity bypasses (read)

| Source | Rarity band | Soft cap that applies | Note |
|---|---|---|---|
| Enemy drops | spec `drop_rarity_min..max` + Threat loot bonus (+ elite bonus) | `max(rarity_max + 1, floor(seg / 3) + source_rank)`: promotions above it run at 8% of their chance | The only source the cap binds. |
| Hub vendor | `1 + floor((seg - 1) / 2)` to `+3`, so R1-R4 at segments 1-2, R2-R5 at 3-4, R8-R10 by segment 15; source rank 1 | cap = `rarity_max + 1`, so it never binds the vendor | At segment 1 an R4 item costs about 150-260 Followers against a first-segment income near 1,400 (economy audit). |
| Wager shrine | tier 3: R7-R10 for 85 Followers at 40% (+ up to 18 points from Luck), two items | none | Outcome is seeded by shrine, tier and stake, so a reload cannot reroll it; the stake is refused below the reconstruction cost. Steep by design, but at segment 1 it is the only R7+ source. |
| Exploration / site / vault loot | authored 3-5 (+ per-segment bonus), vault 4+ | `rarity_max + 1` | Authored placement, cap never binds. |
| Meta stash | any rank carried from earlier attempts | none | By design; a fresh attempt can start at segment 1 wearing R12. |

The cap formula itself is the bypass: `rarity_soft_cap = max(rarity_max + 1,
...)` means any source that *asks* for a band above the segment cap is
exempt from it. Only enemies ask for low bands.

## 4. Equip-feed (read; one trap)

- Feeding is one-way and consumes the material; the merge law is
  symmetric in rank (feeding an R0 into an R6 or the reverse is the same
  1/16 mass), so no ordering of feeds creates rank. Feeding sixteen
  maximum-roll R0 copies into an R6 does reach R7; that is the law, not a
  hole.
- **Trap:** `InventoryRouter._equip_from_bag` and `_move_between` feed a
  bag item into an equipped item of the same id with `allow_rule_loss =
  true`, so a bag item carrying a *different* Manifestation is consumed
  and its Manifestation destroyed without a prompt. Pickups use `false`
  (the pickup goes to the bag instead). `_test_equip_same_id_feeds_instead_of_swapping`
  pins the feed, not the loss.
- The router conserves items on every refused move (full bag, wrong slot,
  locked target, invalid container): 111 checks, including the eject
  rollback and the full-stash exchange.
- Guaranteed rewards fall through equipped -> feed -> bag -> stash ->
  protected world drop and are never lost.

## 5. Follower sources and sinks (read)

Sources: combat kills (`combat_influence`; suppressed in segment 1 until
the assistant milestone; decays under Overtime; proxies pay the same as
actors), boss and miniboss victories, selling loot (0.55 x value, the
largest discretionary income: one R4 site item is 60-120 Followers,
thirty to seventy kills), Ascension refunds (neutral), trade undo
(neutral), developer grants.

Sinks: trades, vendor refreshes, Ascension purchases, wager stakes,
reconstruction (`max(flat, 20%)`), Leech and Herald drains, Backfire's 5%
HP is health not Followers.

No source pays for an action the player can repeat without cost. Loot
selling is bounded by drops; kills by spawns and Overtime; the wager by a
seeded outcome and a negative expectation at tiers 1-2 (an R3-R5 item
sells for 40-100 against an 8 or 30 stake at 85% / 62%, so tier 1 is
positive in expectation on *sell value* alone: 0.85 x ~55 = 47 for 8). That
is the one arithmetically positive bet, once per shrine.

## 6. Proposals

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| L1 | Refunds only from the Hub: `Global.ascension_refund` refuses unless the Hub screen opened the tree (a flag set by `HubShop._open_ascension`, cleared on close); the mid-run screen hides the Refund button. | Free rental of any node between rooms (section 2). | New `LootLoopTest` check: refund refused with the flag unset; `AscensionScreenTest` still passes. |
| L2 | Refund share `paid x clamp(0.5 x 0.9^(seg-2), 0.1, 0.5)` for locals, mutations and sinks; Revelations, forks, Gates, Unions, Axioms and Catastrophes non-refundable; dependents still leave, at the same share. | The V4 economy rule; refunds today are a free respec. | Ledger test: refund total equals the share; wallet never exceeds start. |
| L3 | Vendor band `floor(seg / 3) + 1` to `+2`, source rank 1 kept; or keep the band and price the gap (`compute_buy_value` x 1.5 for every rank above the enemy cap). | The vendor is the segment's rarity bypass (section 3). | `HubShop` stock test at segments 1, 4, 9. |
| L4 | `rarity_soft_cap` = `floor(seg / 3) + source_rank + 1` for every source; authored bands above it keep their minimum but promote at the over-cap chance. | The cap only binds enemies because it defers to the asked band. | `ItemGenerator` test: promotion above cap at 8% for a vendor context. |
| L5 | Wager tier 3 band `soft cap + 2 .. + 4` instead of R7-R10; tier 1 stake 8 -> 20. | The one positive-expectation bet and the segment-1 R7+ source. | Arithmetic check in `LootLoopTest`. |
| L6 | Equip-feed with a differing Manifestation asks, or routes to the bag like a pickup (`allow_rule_loss = false` in the router; the Hub and inventory screens show a confirm). | Silent destruction of a Manifestation (section 4). | `InventoryRouterTest`: same-id, different-Manifestation equip lands in the bag. |
| L7 | Keep the `LootLoopTest` invariants in the plan's Task 5 (merge mass and prices): any price or merge change must keep buyback > sell, merge-sell <= 0, consolidation <= rounding. | Task 5 changes exactly these numbers. | The suite. |

## 7. Not verified here

- The Hub UI flow end to end (sell marks, cart, undo button) runs only
  through `ExchangeIdentityTest`'s identity checks; the trade arithmetic
  above was pinned at the `Global` and container level.
- Save-scumming enemy drops: `Global._rng` is not persisted, so a reload
  before a kill re-rolls the drop. Not a loop, and not measured.
- Whether players *feel* the vendor's early rarity as a bypass or as the
  shop's point is a playtest question; the economy audit already argues
  the shop loses tension early.
