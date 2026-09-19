# Manifestation imprints (2026-09-19)

The problem, from play: with Manifestations, duplicates stopped combining.
A drop rolls a rule 22–35% of the time on stat slots and 60–70% on rings
and offhands, two copies rarely roll the same one, and every path that
combined copies refused when their rules differed, so the ring you were
building stopped ranking up and the bag filled with rivals. Rarity
progression and rule identity were welded together.

## The model

Rules are a commitment, not a treasure to sort: the copy you wear is the
one you committed to.

- A merge never refuses and never destroys a rule. The destination keeps
  its rule; a copy without one adopts the incoming rule; a different rule
  on the incoming copy is dissolved from the item but kept as an
  **imprint** (`Global.attempt_imprints`, eight held, oldest forgotten,
  one of each).
- Every path feeds again: pickups auto-feed the worn copy, bag stacks
  consolidate, dragging a copy onto the worn item feeds it.
- The Hub has an **imprinter** (`ImprintScreen`, `ImprintService`): a held
  imprint goes onto any worn or bagged item of a slot the rule allows, for
  a quarter of the item's value (20 Followers at least). The rule the item
  carried goes back into the pouch. Between Hubs there is no switching.
- Imprints ride the save (`SaveData.attempt_imprints`) and reset with the
  attempt.

Precedents: Diablo IV's Codex of Power (a legendary power extracted from
its item and imprinted at a station, so items are progression and the
power is the choice) and Risk of Rain 2's scrapper (the player decides
what is sacrificed to a printer, never the printer). Sources:
https://diablo4.wiki.fextralife.com/Codex+of+Power,
https://riskofrain2.wiki.gg/wiki/Item_Scrap.

## Alongside it

- **The toss.** A throw from the bag now lands 120–250 px away, its pickup
  delay is pause-aware (the bag pauses the game, and the old timer spent
  the delay while it was open), and a deliberate drop arms only once the
  player has stepped off it. Discarding to make room works.
- **The vendor.** The shelf grows by eight slots (to 64) instead of losing
  the seventeenth thing you sold; eight offers through segment 2, ten at
  3–5, twelve after; the band runs from one under the segment's rarity cap
  to two over it (R1–R4 at segments 1–2, R2–R5 at 3–5, R4–R7 at 9), so the
  shop is where rarity is bought without outrunning the run.

## Not done

A walkable Hub (vendors, the tree, the imprinter as places rather than
buttons) is the next design conversation, not this change.
