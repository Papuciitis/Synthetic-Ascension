# First-trailer build feasibility — source audit, 4 November 2026

Audited `60b34df4`, read-only except this report. No engine, capture, rolls,
save changes or tests were run. Read the vision, README, latest roadmap status
and provisional shot plan. This establishes source feasibility, not an earned
build, measured readability, audio quality or smooth current Game footage.

Follow-up: the stale Sunder header and its aim-position wording were corrected
after this source audit. This changes comments/display copy only; acquisition,
slot dispatch, resource fill/spend, attack timing and damage are unchanged. The
defect descriptions below retain what the audit observed at its stated base.
Independent scoped review found no actionable issue. A direct source comparison
confirmed that executable bodies differ only in the two display literals; no
runtime test, whole-project parse or Game capture is claimed for this copy fix.

## Decision

Prefer **one genuinely acquired Sunder Wake** for the first before/after insert.
The current shared Momentum resource fills from travel even with Sunder alone.
Pilgrim's Momentum is optional faster generation, and competes with Sunder for
the same bank on attacks. Do not promise an echo and tear together at full bank.
If the run yields Pilgrim alone, its travel → full bar → delayed second attack
is another complete, genuine fallback. Neither named roll is guaranteed.

## Acquisition and equipment

- A new `ItemInstance.from_roll()` normally rolls its Manifestation once
  (`data/items/ItemInstance.gd:49–83`), using the item's fixed equipment slot,
  current run Luck, global RNG and currently equipped distinct rule tags.
  A rule is item identity, not a rarity unlock. Rarity/merge progress scales it;
  duplicates do not reroll it.
- `data/manifestations/ManifestationCatalog.gd:28–46,269–310`: base chance of
  **any** rule is Movement 26%, Offhand 60%, Ring 70%; NEG adds eight percentage
  points, effective Luck adds `0.12 × LuckResolver.effective(luck)`, total capped
  at 95%. These are not chances of the desired named rule. Slot pool and weighted
  selection still apply. An already held matching noun doubles a one-tag rule's
  weight; two matching tags give ×5 (`:289–345`). This changes selection, not
  the chance to obtain any rule. No particular seed or drop is established here.
- Pilgrim can roll only on **Movement(2) or Ring(7)**; Sunder on
  **Movement(2), Offhand(6), Ring(7)** (`ManifestationCatalog.gd:65–90`).
  Equipment has one slot of each type; a ring cannot be put into Offhand or
  Movement (`data/items/Inventory.gd:14–23,118–128`). Thus both rules need
  separate items in separate allowed slots, never two rules on one item.
  The item name is not a slot guarantee: `7-Mile Boots (Hand-Me-Downs)` is a
  Ring (`data/items/defs/accessories/seven_mile_boots.tres:20–32`).
- Normal full-instance sources include exploration loot
  (`scenes/world/pickups/ExplorationLootSpawner.gd:119–126`), vendor stock
  (`ui/screens/HubShop.gd:1544–1600`) and Cursed Vault rewards
  (`core/systems/world/CursedVault.gd:210–247`). Inspect actual earned offers.
  Vendor reopening does not create free rerolls; refresh spends Followers
  (`HubShop.gd:1513–1523`). The vault guarantees **a** slot-compatible rule,
  not Sunder/Pilgrim, and requires a 3s hold, normally calls Hunter + charger
  wedge and seals healing for 45s (`CursedVault.gd:25–37`). Its encounter is
  a genuine risk, not a capture shortcut.
- Full-instance pickups auto-equip an empty matching slot; a same-ID,
  same-polarity equipped duplicate can automatically merge into the worn copy
  (`scenes/world/pickups/ItemPickup.gd:252–294`). Otherwise they enter the bag.
  ID-only pickups can directly feed a percentage roll into a matching worn
  item without rolling a fresh Manifestation; existing bag stacks likewise feed
  fabricated rule-free material (`ItemPickup.gd:333–363`;
  `data/items/BagInventory.gd:406–447`). Repeated copies of a worn item are
  therefore not a reliable way to hunt a new named rule.

## The real equip/merge decision

Use Tab/I to open management; the shot plan's existing HUD references establish
that it pauses gameplay. Hover the actual item and hold its full tooltip:
`ui/widgets/ItemTooltip.gd:252–279` names the rule/nouns and calls the
instance-specific `ManifestationCatalog.describe()`. Run Sheet rows are limited
to two visible lines, with full text on hover (`ui/widgets/RunSheetHUD.gd:1029–1056`).

An unlocked bag item equips by ordinary left click (or right click without
Shift); Ctrl controls locking (`ui/bag/BagSlot.gd:279–304`). Same item ID and
polarity **merge instead of swapping** into its worn duplicate
(`core/systems/inventory/InventoryRouter.gd:105–143`). Different IDs or polarity
replace the matching equipment slot. Do not label a same-slot replacement as
adding a second coexisting rule.

Merge requires same ID, same polarity, distinct instances and neither locked
(`data/items/ItemInstance.gd:120–130`); equal rarity is not required. Destination
keeps its rule, or adopts the incoming rule if it has none; a different incoming
rule becomes a Hub imprint (`:151–170,235–236`). Merging never fuses the two rules.
Thus clicking a Sunder duplicate onto a different-rule worn copy can bank Sunder
as an imprint instead of activating it. Inspect the actual result before filming
the causal after-shot. No confirmation dialog is part of this routing path.

An already earned imprint is another genuine route at the Hub: it must be held,
the target must be unlocked and in an allowed slot, and the player must afford
25% of market value × market scale, at least 20 Followers. Applying consumes the
imprint; the replaced rule returns to the pouch (`core/systems/items/ImprintService.gd:19–63`).
This is conditional on existing run inventory/imprints/Follower balance, not an
available starting loadout established by this audit.

## What the two rules really do

`core/systems/manifestations/ManifestationState.gd:33–48,985–1067` supplies
Momentum to any claimer at **704px = 22 design metres** of actual travel per
full bank. Movement means more than 12px/s; the odometer resets after 0.18s
stillness. Momentum itself decays while still at 0.85 of a bank per second.
Keep moving while preparing the trigger; do not stop to aim and expect a full
bank to persist. Dash is not required.

- **Sunder alone:** attack with at least 20% Momentum, consume all, immediately
  deal radial damage and spawn the tear at the attack's aim position
  (`effects/manifestations/logic/SunderWake.gd:17–47,54–74`). The earliest
  eligible bank is roughly 140.8px/4.4m from zero; full bank takes 22m.
  At R0 and full bank, radius is 188px/5.875m, damage is 135% of the helper's
  attack damage and knockback 420. Less bank gives less damage/knockback and a
  radius interpolated from 72 to 188px. Prefer full bank for the legible take.
- **Pilgrim alone:** its own 480px/15m fill runs **in parallel** with the 704px
  shared fill. At R0 the combined fill is `1/(1/480 + 1/704)` = 285.4px,
  **8.9m**, not 15m. Actual rarity eases its own distance, so quote the earned
  tooltip (`effects/manifestations/logic/PilgrimsMomentum.gd:78–101,149–164`;
  scaling `core/systems/manifestations/ManifestationEffect.gd:80–97`). At
  >=99.9% the next attack consumes all Momentum, calls out **TWICE**, and
  repeats the player's attack after 0.09s (`PilgrimsMomentum.gd:104–132`).

Both coexist in the runner, but attack hooks dispatch in **ascending equipment
slot**, then rule ID (`core/systems/manifestations/ManifestationRunner.gd:324–355,473–490`):

| Actual allocation | Full-bank result with no other spenders |
| --- | --- |
| Pilgrim Movement(2), Sunder Offhand(6) or Ring(7) | Pilgrim consumes first: echo; Sunder sees zero. At 20–99.8%, Pilgrim declines and Sunder spends instead. |
| Sunder Movement(2) or Offhand(6), Pilgrim Ring(7) | Sunder consumes first whenever eligible: tear; Pilgrim sees zero and cannot echo. Pilgrim still accelerates travel fill. |

There is no automatic extra authored pair from these two alone: distinct noun
counts are Momentum 2, Cadence 1; a pair needs two lit nouns at two distinct
rules each (`data/manifestations/ManifestationPairCatalog.gd:18,131–146`).
`tools/tests/ManifestationPairBehaviourTest.gd:1567–1583` contains this real
allocation as a synthetic fixture, not proof of normal-run acquisition.
`tools/tests/ManifestationSystemTest.gd:588–615` pins combined-fill text; it was
read, not run here.

## Readability, audio and capture recipe

1. Capture ordinary baseline combat in a usable lane before activating the
   earned rule. Keep weapon, location/enemy family and other choices stable.
   Prefer an actual Sunder item in the bag replacing a different-ID current
   item, or a held imprint at the Hub, so the decision is visible. Log the
   accompanying item stat/effect change; it is not pure isolated rule damage.
2. Hold tooltip/name, perform the genuine equip/imprint, close management and
   let any first-time tutorial card settle. Do not alter discovery flags.
3. For Sunder alone, release attack while running a clear loop, watch Momentum
   reach 100%, then click once while still moving, aiming at enemies on visible
   ground near the player. Record HUD spend + ground tear + enemy response in
   one continuous take. Repeat. Holding attack continually spends each small
   eligible bank and hides the full-payoff loop. If Pilgrim alone is earned,
   use the same travel-and-single-click pattern to show TWICE and the echo.
4. HUD exists for either lone rule: it shows the claimed noun percentage with
   one dim pip; two distinct Momentum rules brighten it. Values update at 10Hz,
   filled/spent signals pulse it (`ui/controllers/HudManifestationController.gd:202–228,250–292,365–390`).
   A lone Sunder has no Pilgrim-specific player ring/chevron trail.
   The tear lasts 0.34s (`assets/vfx/world/manifestations/VFX_SunderTear.gd:12`).
   Inspect native and 960×540 frames; those observations remain unperformed.
5. First rehearsal settings: 1920×1080, UI Scale **1.0**, Ability Callouts **on**,
   Damage Numbers **off**, Combat Flash **reduced**, Screen Shake **off**,
   Hit Feel **off**, Reduced Motion **off**, Hold to Attack **on** but use
   discrete clicks for this demonstration. Master/SFX/UI **1.0 unmuted**,
   Music **0.32 unmuted**; VSync on, frame limit 0. Defaults and independent
   toggles are in `core/settings/SettingsSchema.gd:13–56`; UI scale changes the
   entire root viewport (`core/settings/SettingsRuntimeApplier.gd:15–27`).
   These are starting choices, not proven best visuals. Keep normal camera,
   60Hz physics and time scale 1 per shot plan; record measured 60/30FPS.
6. Ability Callouts preserves Pilgrim's TWICE; Sunder itself has **no named
   per-trigger popup**. Existing audio includes pickup/UI click and ordinary
   weapon/death cues (`ItemPickup.gd:153–156`; `autoload/UiSoundRouter.gd:6,73–78`;
   `autoload/SfxManager.gd:125–134,301–319`; `assets/audio/sfx/sfx_manifest.txt:7,56`).
   Neither rule nor Sunder tear calls SFX, no matching dedicated cue exists in
   that manifest, and Momentum filled/spent signals drive HUD pulses rather
   than sound. Pilgrim echo directly spawns an attack instead of emitting
   weapon_fired (`ManifestationEffect.gd:196–217`); do not promise a second
   weapon-fire sound. Live audio balance and impact quality still need listening.

## Confirmed documentation/wording defects, no runtime fix proposed

- `effects/manifestations/logic/SunderWake.gd:5–8` says a lone spender has
  nothing filling its pool. This is obsolete: shared travel fill above makes
  Sunder alone work. It is a documentation defect, not evidence of inert runtime.
- The user-visible Sunder description says the tear happens “where it lands”
  (`SunderWake.gd:69–74`; catalog `:84–86`), but it executes from weapon_fired
  using `mouse_pos`, immediately after attack creation
  (`core/actors/player/player.gd:1023–1031`), not from landed-hit coordinates.
  Treat it as **attack → tear at aim position** in capture/editorial wording;
  do not claim a projectile impact-triggered or heavy-attack-only rule.

No additional runtime bug is established by this read-only audit. The safe
trailer claim is the particular earned movement/attack loop actually captured.
The memory-gated current Game, RNG availability, survival, native readability,
real-time performance and audible quality remain open gates. No fake HUD,
deterministic item grant, dev loadout, god mode or scripted reward is authorized
as ordinary-run footage by this report.
