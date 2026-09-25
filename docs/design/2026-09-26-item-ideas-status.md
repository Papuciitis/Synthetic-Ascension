# Item concepts — implementation and decision status (2026-09-26)

Source: the 2026-09-25 handoff §14.3 + Appendix B (the February list).
Statuses: **implemented** · **design-ready** (mechanic settled enough to
build next batch) · **needs design** (no settled mechanic) · **needs
reference** (personal/inside reference must be recovered from history or
the user before naming a mechanic). Nothing here is silently invented; a
"needs reference" item stays unbuilt rather than guessing the joke.

| Item | Status | Notes |
|---|---|---|
| **Beka** | **implemented** (2026-09-26) | Approved shield + pulse prototype; `BekaEffectTest` 30/30. Art is a text-described likeness (black/white tuxedo, white nose/neck/boots — user, 2026-09-25); photo/meow still welcome. |
| The Missing Pālis | design-ready | Bounded wavy-screen pickup effect (Varis) is settled and small; the delayed-damage-debt mechanic stays a proposal needing anti-duplication rules. Build the visual half first. |
| Plot Armor | design-ready | Assistant proposal with clear safeguards spelled out (rival marking, rearm on rival death, invalid-target fallback). Slots as Offhand. |
| Grandma's Bazooka | design-ready | Delayed homing retaliation; define damage/cadence/target-loss before build. |
| 7-Mile Boots | design-ready | Dash extension + return-to-start window; needs terrain/exit validation pass. |
| Second Breakfast | design-ready | Delayed second portion of any heal through real healing attribution; recursion guard. |
| Beer | design-ready | Power+Luck with the existing diminishing progression; "one million" is flavour, not a cap authorization. |
| Bazinga | design-ready | Near-miss sound decoy; bound audio repetition; define which AI reads decoys. |
| Trauma | design-ready | Adaptation vs the most recent major damage source; define source categories + cap. |
| Dignity | design-ready | Protection while intact; dropped recoverable object; placement rules must prevent softlocks. |
| Along-the-Way Friendmaker | design-ready | User explicitly liked follower-making; temporary ally recruitment with reward dedup + ally cap. |
| Metaknowledge | design-ready | User explicitly liked the minimap idea; audit the current navigation baseline first so nothing essential hides behind the item. |
| The List | design-ready | Ordered target marks; handle despawn/segment transitions. |
| IDFK | design-ready | Learnable hidden rule; description flips to "Oh." on discovery. |
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
