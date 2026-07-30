# Syntethic Ascension 0.25.5 — Inventory Safety & Trade Flow

## Implemented

- Persistent per-item lock/favourite state on `ItemInstance`.
- Locked items display a gold `LOCK` badge in equipped and bag/vendor-style slots.
- Ctrl-click toggles item locking in the HUB trader.
- Locked items are excluded from Mark Bag and Mark NEG.
- Locked items cannot be sold, discarded, ejected, moved, swapped out, or replaced through `InventoryRouter` player actions.
- Item tooltip header identifies locked items.
- Tooltip now includes direct stat deltas against the relevant equipped slot, alongside existing set-breakpoint preview.
- One-step `Undo Last Trade` restores followers, equipped inventory, backpack, and vendor stock while the current HUB remains open.
- Vendor category, Affordable state, and search query persist during the current HUB visit and reset when leaving the HUB.
- Shop bag-grid interaction now carries mouse button, double-click, Shift, and Ctrl state, enabling safer quick actions.

## Scope note

This patch deliberately focuses on inventory/trade safety. Combat navigation, delayed loot magnetism, exit warnings, and accessibility sliders remain isolated for a later patch so regressions are easier to identify.
