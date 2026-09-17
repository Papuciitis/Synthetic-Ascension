# Equipment Foundation Patch

Date: entered the repo 2026-07-30 (`af1fc46`), during the 0.25.x line; the
verification below cites Godot 4.7.1. Kept as history.

## Implemented

- Added a single continuous rarity-mass merge model.
- Equal-rarity duplicates normally advance one rarity, low-quality rolls can fall short,
  and strong rolls carry correctly scaled overflow.
- Lower-rarity duplicates always retain non-zero value at higher rarity.
- Rarity upgrades preserve the strongest POS roll or strongest absolute NEG roll.
- POS and NEG projects remain separate.
- Added an infinite diminishing rarity/set potency curve.
- Routed inventory and bag merging through `ItemInstance.merge_from`.
- Added a centralized diminishing `LuckResolver` and safe future hooks for drops,
  roll quality, rarity, vendor stock, prices, lucky crits, evasion, events, followers,
  and augment quality.
- Routed random item rolls through the centralized generator.
- Added contextual rarity generation using segment, Threat, source rank, elite status,
  source soft cap, Luck, and equipped-item progression.
- Routed enemies, exploration loot, indoor loot, and vendor stock through that generator.
- Rings now have meaningful signed effect-strength rolls and use normal item progression.
- Replaced uncapped exponential set scaling with the diminishing potency curve.
- Added POS/NEG item-effect scene overrides without inventing unfinished effects.
- Added inventory queries for NEG count, rarity, magnitude, and set composition.
- Removed the unexplained NEG price premium.
- Pricing now includes rarity progress and bounded Luck buy/sell effects.
- Major-choice item rewards now try equipment, bag, stash, then a persistent ground pickup.
- Developer Mode and its tools remain intact.

## Save compatibility

The patch does not remove or rename serialized `ItemInstance` fields. Existing saves keep
`rarity`, `polarity`, `progress`, `upgrade_meter`, `best_pct`, and `locked`.

New `ItemData` polarity-effect arrays default to empty. When empty, items continue using
their existing shared effect scenes, so old item definitions require no migration.

Existing saved upgrade meters are interpreted as progress toward the next rarity. Future
merges use the corrected mass and overflow rules.

## Intentional design adjustments

- Overflow is halved after each rarity gained. This is required by the doubling rarity-mass
  model; carrying the same normalized percentage forward would overvalue duplicates.
- Luck affects polarity only slightly and remains capped, so NEG builds stay viable.
- Luck APIs for crits, evasion, events, followers, and augments are hooks only. No speculative
  gameplay behavior was activated without corresponding finished systems.
  (2026-08-30: since the 2026-08-23 audit session, crits, evasion, follower
  gain and exploration loot are live consumers; only `augment_quality_bonus`
  remains an unconsumed hook — `core/systems/items/LuckResolver.gd:57`, no
  caller.)
- NEG-specific effect slots fall back to existing shared effects. The patch provides the
  foundation but does not invent item or set variants.

## Verification

- `AuditClosureTest`: 50 passed, 0 failed.
- `SaveIntegrityTest`: 29 passed, 0 failed.
- Godot 4.7.1 project/editor initialization completed successfully.

The test runner reports engine resource/object leak diagnostics during headless shutdown;
these pre-existing shutdown diagnostics do not fail either suite.
