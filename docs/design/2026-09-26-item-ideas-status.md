# Item concepts — implementation and decision status (2026-09-26, refreshed 2026-09-27)

Source: the 2026-09-25 handoff §14.3 + Appendix B (the February list).
Statuses: **implemented** · **design-ready** (mechanic settled enough to
build next batch) · **needs design** (no settled mechanic) · **needs
reference** (personal/inside reference must be recovered from history or
the user before naming a mechanic). Nothing here is silently invented; a
"needs reference" item stays unbuilt rather than guessing the joke.

| Item | Status | Notes |
|---|---|---|
| **Beka** | **implemented** (2026-09-26) | Approved shield + pulse prototype; `BekaEffectTest` 30/30. Art is a text-described likeness (black/white tuxedo, white nose/neck/boots — user, 2026-09-25); photo/meow still welcome. |
| The Missing Pālis | **implemented** (2026-09-26, visual half) | One shared hard-bounded screen wave (never above 5 px, idle 1.6 px, stacking adds nothing) + odd Luck. The delayed-damage-debt mechanic stays an unbuilt proposal. `ItemBatch2Test`. |
| Plot Armor | **implemented** (2026-09-26) | Offhand: survive one lethal at 1 HP, culprit becomes the rival; rearms on rival death, 45 s fallback when fate loses track, segment end clears; 1 s grace; never permanent. `ItemBatch2Test`. |
| Grandma's Bazooka | **implemented** (2026-09-26, batch 4, D-19) | Delayed homing retaliation against the enemy that hurt the player. `ItemBatch4Test`. |
| 7-Mile Boots | **implemented** (2026-09-26, batch 4, D-19) | Dash extension with a return-to-start window and a left-behind boot marker. `ItemBatch4Test`. |
| Second Breakfast | **implemented** (2026-09-26) | Ring: half of any applied heal, 3 s later, through the real heal path (locks apply); recursion-proof; pending portions coalesce. `ItemBatch2Test`. |
| Beer | design-ready | Power+Luck with the existing diminishing progression; "one million" is flavour, not a cap authorization. |
| Bazinga | **implemented** (2026-09-26, batch 4, D-19) | Near-miss decoy at the old position; audio repetition bounded. `ItemBatch4Test`. |
| Trauma | **implemented** (2026-09-26, batch 3a) | Per-source damage-taken multiplier vs the most recent major source, capped. `ItemBatch3Test`. |
| Dignity | **implemented** (2026-09-26, batch 3a) | Protection while intact; a strong hit drops a recoverable standard with auto-return; user-supplied art. `ItemBatch3Test`. |
| Along-the-Way Friendmaker | design-ready | User explicitly liked follower-making; temporary ally recruitment with reward dedup + ally cap. |
| Metaknowledge | design-ready | User explicitly liked the minimap idea; audit the current navigation baseline first so nothing essential hides behind the item. |
| The List | design-ready | Ordered target marks; handle despawn/segment transitions. |
| IDFK | **implemented** (2026-09-26, batch 4, D-19) | Learnable hidden rule; description flips to "Oh." on discovery. `ItemBatch4Test`. |
| Druid Tuning Staff | needs design | Trees: decorative vs blocking vs supportive undecided; navigation impact is the real question. |
| Godot Engine, the item | needs design | Enemy-to-collision conversion is a collision/nav feature, not an item skin; scope it as such or park it. |
| Degree → Worthless Degree | needs design | Learning-from-enemy-types progression and the conversion reward are both open. |
| Brutal Assault Gauntlets | needs design | Name only (Varis); wants a melee/impact identity. |
| Just Molly | needs reference | Name only; no mechanic, no visual reference. |
| Duck Corkscrew | needs reference | Name only. |
| Dad's Penis | needs reference | Name only; do not infer a system from the joke. |
| Supa Manki | needs reference | Recover the intended reference or clearly label a new interpretation. |
| Eldritch Crystal | needs reference | The time-loop head reference is unidentified; rewind semantics (save/HP/loot) must wait for it. |
| The Soul of Coul | needs reference | The purple AI bird clip is absent; the shopkeeper minigame is an unresolved scope addition either way. |

**Refresh 2026-09-27:** ten of the twenty-four concepts are implemented (Beka, Pālis' visual half, Plot Armor, Second Breakfast, Trauma, Dignity, Boots, Bazooka, IDFK, Bazinga); four are design-ready and unbuilt (Beer, Along-the-Way Friendmaker, Metaknowledge, The List); four need a design decision; six need their reference recovered. All 33 item defs carry icons (art program closed 2026-09-26).

**Recovery path for the "needs reference" rows:** the browser-ChatGPT
history consultation (handoff §13) — currently blocked by the session's
permission classifier on GUI input; the exact ready-to-send questions are
kept with the blocker note in `2026-09-25-v5-decision-log.md` (B-1).

**Existing-item texture audit result (2026-09-26):** the only missing
bindings in the whole catalog were the eight curse relic icons (every
`curse_*.tres` shipped without `icon`, rendering blank in inventory, shop,
tooltip and ground loot). Authored a consistent cursed-relic set
(`tools/design/build_curse_icons.py`) and bound them; all other 25 items
carry icons, and no null/misassigned world sprites were found (ground loot
draws `data.icon` directly). The two intentionally-shared placeholder
Offhand icons (Oakheart's) are deliberate, not errors.
