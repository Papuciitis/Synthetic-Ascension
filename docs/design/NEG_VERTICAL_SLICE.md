# The NEG slice: three archetypes that disagree

`gamegoal.md` §21 sets the bar: *"Normally this curse would suck, but this build
actively wants it"* — and never *"bad loot everyone eventually optimises away"*.

Before this slice, that bar could not be cleared, and §24 says why: the worst
curse in the game was −50%, every item's NEG range was roughly −20%…−50%, and so
**every archetype valued every cursed item identically.** There was no argument
to have. Corruption Engine existed alone, inlining its own severity loop inside
`recompute_run_stats`.

## Polarity is not burden

The distinction the whole ecosystem rests on:

- **Polarity** is what an item intrinsically *is*. It never changes. It is what
  parity, set composition and acquisition rewards count.
- **Active burden** is how much curse is presently weighing on the player. An
  Inversion Lens drops one item's burden to zero **without making it any less
  NEG** — so it still counts for parity while feeding nothing that eats severity.

`BurdenResolver.resolve(inventory, augment_ids)` returns the one `BurdenSnapshot`
every archetype reads. Each computing its own totals is exactly how two augments
quietly come to disagree about the same item, and it is also why nothing could
previously show the player the arithmetic.

## The three archetypes, and why they argue

Given two wardrobes of *identical* total severity — two 75% catastrophes, or
five 30% scratches — they must rank them oppositely. That is asserted in
`BurdenSystemTest._test_archetypes_disagree()`.

| | Reads | Wants | Hates |
|---|---|---|---|
| **Corruption Engine** | the top **two** active severities | two catastrophes | spreading severity thin |
| **Doctrine of Burden** | the **count** of curses at ≥10% | six real-but-mild curses | consolidating them |
| **Inversion Lens** | the **single worst** severity | one horror it can switch off | a wardrobe of scratches |

They also fight each other on purpose. A Lens suppressing your worst curse
**starves the Engine that was eating it** — so running both is a real cost, not
a stack. Ordinary NEG merging stabilises a curse toward mild, which is precisely
what the Doctrine wants and precisely what Corruption Engine inverts (§22).

`INVERSION_RETURN` is 0.55, deliberately well under 1.0: a suppressed
catastrophe should make a horrific item **worth carrying**, never strictly
better than an equivalent blessing, or the POS/NEG choice collapses.

## Deep curses, tuned per stat family

§24's warning is the design constraint: −95% movement, −95% Max HP and −95%
Armour are not equally playable. Severity is therefore authored per family
rather than from one global range.

| Item | Slot | Floor | Why that floor |
|---|---|---|---|
| Ashen Ballast | Armour | −95% | Mitigation. Losing all of it is survivable, so it can be catastrophic. |
| Jinxed Coin | Luck | −95% | Pure upside. Losing all of it costs nothing you had. |
| Hollow Reliquary | Power | −80% | Your weapon stops mattering; everything your items *do* still does. |
| Starving Crown | Max HP | −60% | Dangerous, and the point — it makes every low-HP payoff constant. |
| Leadfoot Vigil | Movement | −45% | Capped hard. A horde does not forgive being slow. |

All five can **only** roll NEG (`pct_max = 0`), so they are relics rather than
items that happened to come out badly.

They also carry `drop_weight = 0.3`. Uniform selection would have made them 18%
of all drops; they land at ~7%. A catastrophe met every other fight stops being
a catastrophe and becomes wallpaper. `ItemData.drop_weight` is new and every
random-item path — enemies, buildings, exploration, vendor shelves — now funnels
through `Global.pick_weighted_item_id()`, so authored rarity means one thing.

## Showing the arithmetic

§46 asks for the calculation rather than the name. The Run Sheet's BURDEN block
shows live totals and, per equipped archetype, the actual sum:

```
CORRUPTION ENGINE
   top two active: 145%  ×  16%/100%  →  Power +23.2%
INVERSION LENS
   ARMOUR suppressed: 92% curse  →  +51% returned, 0% burden
```

The item tooltip states a cursed item's **active** burden and whether it is
currently suppressed — because the same item is a prize to one build and nearly
worthless to another, and the player cannot tell from the roll alone.

## Not done

- Equilibrium Sigil (parity), Litany of Wounds (HP→Haste conversion),
  Gravemarch polarity mutation and Gambler's Rite remain designed and unbuilt.
  The snapshot already exposes `is_balanced()` and per-slot severity for them.
- Deep curses have no authored icons yet.
