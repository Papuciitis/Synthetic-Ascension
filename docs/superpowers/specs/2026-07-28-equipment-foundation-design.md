# Equipment Foundation Design

## Goal

Unify equipment generation, merging, Luck interpretation, rarity scaling, reward delivery, pricing, and polarity metadata around the confirmed long-term item-project design.

## Canonical Item Projects

An item project is uniquely identified by item ID and polarity. POS and NEG projects never merge automatically.

Every equipment source creates a complete `ItemInstance`. Raw `item_id + amount` feeding is removed from gameplay paths. Inventory, bag, pickup, vendor, exploration, enemy, debug, and scripted-reward sources all route duplicates through `ItemInstance.merge_from(incoming)`.

## Continuous Rarity Mass

`upgrade_meter` remains normalized progress toward the next rarity.

An incoming instance contributes:

```text
quality_factor × 2^(incoming_rarity - destination_rarity)
```

Quality is derived from the incoming absolute roll within the item's authored roll range:

```text
0.75 + 0.50 × normalized_absolute_roll
```

Zero-range legacy items use neutral quality `1.0`. Contributions use a numerically safe exponent range. Extremely low-rarity items continue providing non-zero progress for all practical rarity levels.

When progress reaches one:

- Rarity increases.
- Overflow remains.
- The strongest roll for the project's polarity remains.
- Flat rarity stats recalculate.

Equal-rarity average-quality merges normally add approximately one rarity level. Higher-rarity incoming items first transfer their rarity mass instead of directly overwriting destination rarity.

## Accessories

Crusher's Ring and Ring of Regeneration receive meaningful signed effect-strength ranges. Their scripted effects multiply authored values by `max(0.1, 1 + active_pct)`.

They use the same polarity, rarity, merge-mass, overflow, and best-roll rules as other items. The temporary `duplicate_feed_value` field is retained only for old custom resources and is not used by the two rings.

## Luck Resolver

Add a pure centralized `LuckResolver` with diminishing normalized Luck:

```text
effective = luck / (abs(luck) + softcap)
```

Positive Luck slightly favors POS polarity while preserving NEG availability. Configurable channels expose bounded modifiers for:

- Item drop chance.
- Roll quality.
- Rarity promotion.
- Vendor stock quality.
- Buy discount.
- Sell bonus.
- Extra follower gain.
- Future lucky crit.
- Future lucky evasion.
- Future secondary-event and augment quality.

Only existing safe systems are activated in this patch. Future channels return bounded values but do not alter unfinished mechanics.

## Item Drop Context

Add `ItemDropContext`, a small data resource containing segment, threat, source rank, elite status, base rarity range, soft cap, over-cap chance, player Luck, and equipped-rarity catch-up.

`ItemGenerator` creates complete instances for enemies, exploration, indoor loot, vendors, and scripted rewards. Rarity starts in the authored range, then receives bounded promotion rolls from segment, Threat, source rank, Luck, and a small equipped-rarity catch-up. Promotions above the source soft cap remain possible at a reduced probability.

R0 never becomes invalid or useless because canonical merge mass always gives it value.

## Diminishing Infinite Scaling

Central rarity potency is:

```text
1 + 0.45 × sqrt(rarity) + 0.05 × rarity
```

`Inventory.get_set_strength()` uses this curve instead of `1.35 ^ average_rarity`. Tooltip projections use the same helper. Item flat-stat rarity scaling moves from the capped quadratic curve to the same unbounded diminishing potency delta.

## Polarity Hooks

Inventory exposes:

- Negative equipped-item count.
- Negative rarity total.
- Negative magnitude total.
- Per-set POS/NEG composition.

`ItemData` supports optional POS and NEG effect-scene arrays. Existing `effect_scenes` remain the shared fallback for save/resource compatibility. No new NEG gameplay effects or augments are invented.

## Guaranteed Reward Delivery

`Global.deliver_guaranteed_item(instance, prefer_equip)` tries:

1. Empty compatible equipment slot.
2. Canonical bag insertion/merge.
3. Meta stash insertion.
4. Protected persistent world pickup near the player.

Failure is reported and the instance remains owned by a recoverable caller; rewards are never silently discarded. `MCE_GrantItemRoll` uses this API.

## Pricing

Pricing combines:

- Unbounded rarity.
- Normalized rarity progress.
- Merge mass.
- Absolute roll.
- Flat stats.
- Scripted-effect weight.
- Set membership.

The universal NEG premium is removed. Luck applies a bounded buy discount and smaller sell bonus while preserving a non-profitable buy/sell spread.

## Comparison and UI

Tooltip comparison continues showing flat stats, active roll, scripted effect text, and projected set strength, but projected set strength uses the centralized potency curve.

Upgrade progress remains visible. Rarity increases no longer create a roll reset or price decrease.

## Compatibility

- Existing `ItemInstance` fields remain.
- New `ItemData` and context fields have defaults.
- Old saves with zero-roll rings load; their next generated duplicates use the new authored ranges.
- Existing shared effect scenes remain active through fallback behavior.
- Unsafe legacy movement functions remain callable for compatibility but are documented deprecated; gameplay continues through `InventoryRouter`.
- Developer Mode remains unchanged.

## Verification

Tests must prove:

- POS and NEG never merge.
- Every source uses complete instances.
- R0 contributes to higher rarities.
- Equal-rarity average merges upgrade approximately once.
- Overflow and best rolls survive upgrades.
- Raw-roll and full-instance paths produce identical results or the raw path is removed.
- Ring effect rolls scale their scripts.
- Set strength matches the diminishing curve at R0, R10, and R100.
- Luck channels are bounded and monotonic.
- Drop promotions respond to segment, Threat, elite rank, Luck, and equipped-rarity catch-up.
- Guaranteed rewards reach equip, bag, stash, or protected ground fallback.
- Pricing grows with rarity progress and no longer universally favors NEG.
- Existing save-integrity and procedural tests remain green.

