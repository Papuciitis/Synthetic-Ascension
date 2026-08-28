# Run Sheet completeness audit — can every build mechanic be explained to the player?

**Date:** 2026-08-28 · **Tree:** `enemy-world-work` @ `c131cd2` · **Kind:** read-only audit (nothing modified).
**Question (roadmap §14–§15):** does the Run Sheet answer "What am I?" and "Why did this number change?", and do tooltips/cards tell the truth? Line numbers are from the working tree.

---

## 1. Player-facing explanation surfaces

| Surface | Where | What it shows |
|---|---|---|
| Run Sheet // PROFILE | `ui/widgets/RunSheetHUD.gd:93-131` | Six totals (HP cur/max, ARM, SPD *effective*, POW %, HST %, LCK %) plus a parenthesised delta that is **only** `inv.sum_mods()` (flat equipped-item StatDelta). Comment at :105-107 says these are "informational only". No other term is attributed. |
| Run Sheet // SETS | `RunSheetHUD.gd:166-247` | Equipped set list n/max; dossier of the selected set: identity sentence, playstyle, tier list with `mechanical_description` / `plain_description`, best-with, glossary (authored text from `SetData`/`SetTier`). |
| Run Sheet // MANIFESTATIONS | `RunSheetHUD.gd:293-632` | BuildIdentity sentence (:340-368); BURDEN ledger (:432-499: census, active count, total severity, Corruption Engine arithmetic, Doctrine arithmetic, Lens suppression); noun counts row; live meters row; one box per rule with `effect.describe()`; pairs with rule text; DOCTRINE RECORD (stage titles + event labels, :313-337). |
| Run Sheet // OBSERVATIONS | `RunSheetHUD.gd:634-681` | Enemy dossier entries (role/behaviour/expect/counter). |
| Item tooltip | `ui/widgets/ItemTooltip.gd:138-297` | Slot · R · POS/NEG · LOCKED; description; EFFECTS (`get_effects_short`, live numbers); MANIFESTATION block; ITEM STATS (`rolled_mods`, potency baked in); INSTANT COMPARISON (:322-397); SET summary (:426-454); EQUIP PREVIEW breakpoints (:456-500); R→R+1 meter + SELL; NEG-only burden lines (:242-283); feed direction (:285-293). |
| Augment card / tooltip / library | `ui/augments/AugmentCard.gd:123-140`, `ui/widgets/AugmentTooltip.gd:66-121` ("Name Lv.N", description, static `details`, "Stats:" from **base** `mods`), `ui/widgets/AugmentLibraryEntry.gd:35-48`; HUD slot tooltip is display_name only (`ui/screens/hud.gd:495`). |
| Manifestation HUD/cards | `ui/controllers/HudManifestationController.gd` (noun row with ◆◇ pips + headline meter; intro card :397-410; "×2" tip :352-364), `ui/controllers/ManifestationPairNotifier.gd:151-183`, `ui/components/ManifestationInfoBox.gd`, `ui/components/ManifestBadge.gd`. Rule popups via `ManifestationEffect.popup` (`core/systems/manifestations/ManifestationEffect.gd:231-240`). |
| Settings | `ui/screens/settings/SettingsScreen.gd:283-295` | Only "Show damage numbers" and "Show ability and Manifestation callouts"; `reduced_motion` silently drives HitFeel (`autoload/HitFeel.gd:210`). |
| Tutorial tips (`RunEvents.tutorial_tip`) | Emitters: `CursedVault.gd:78`, `ExitRite.gd:497,508,521,523`, `Level1Builder.gd:1535`, `BreachSealObjective.gd:56`, `WardVigilObjective.gd:53`, `SegmentProcBuilder.gd:146,728`, `Wardstone.gd:129-133,201`, `scenes/game.gd:345`, `BossArena.gd:232`, `MiniBossArena.gd:224,250`, `BagUI.gd:318,325`, `HudManifestationController.gd:359`. Blocking cards: `Level1Builder.gd:1530,1210,1236`, `game.gd:377,383`, `HudManifestationController.gd:390`. Displayed by `HudTutorialTipController.gd`. |
| BattleText callouts | LUCKY `player.gd:655`, EVADED `:1019`, damage taken `:1037`, encounter beat label `EncounterDirector.gd:264`, "THE DISTRICT SHIFTS — phase" `:226`, "CURSED VAULT"/"THE VAULT ANSWERS" `CursedVault.gd:76,127`, rule popups. **All `popup()` calls are dropped when `ability_callouts` is off** (`core/combat/BattleTextRenderer.gd:122-130`). |
| HUD | `hud.gd` HP bar/value/%; followers pill tooltip (:544, respawn cost only); Threat row `T# value` + `ThreatTooltip` (`HudThreatController.gd:216-230`: enemy HP/dmg/speed %, spawn rate, heat, overtime, loot bonus); resonance bar + SEALED/READY (`HudGateOverlayController.gd:211-228`); gate checklist; objective; boss bar; set breakpoint notifier; follower feedback narration. |
| Run archive | The "archive" is `RunSheetHUD` itself (node `Archive`, `tools/tests/RunSheetArchiveTest.gd`). `core/systems/run_sheet/BuildIdentity.gd` composes the identity dict but it is only rendered as one line. `ui/screens/GameOverUI.gd` shows three buttons and **no** run summary. Nothing persists a per-run sheet. |

The Run Sheet is only visible in management mode (bag open): `hud.gd:331-334`.

---

## 2. Coverage table: mechanic → surface → status → evidence

| Mechanic | Source of truth | Surface | Status | Evidence |
|---|---|---|---|---|
| Base stats (100 HP / 0 ARM / 200 SPD) | `data/Stats.gd:4-10`, `player.gd:486` | none | **Invisible** | No surface prints base. |
| Race / style additive stats | `player.gd:489-491`, `RaceData.gd`, `StyleData.gd` | RaceCard / PlaystyleCard at selection only | Partial | Not shown in-run. |
| Permanent augment stat mods (level-scaled) | `player.gd:493-494`, `global.gd:816-834`, `AugmentData.gd:30-46` | AugmentTooltip "Stats:" | **Wrong at Lv≥2** | Tooltip uses unscaled `a.mods` (`AugmentTooltip.gd:110-111`) though the header says `Lv.%d`; six augments have `mods_scale_per_level` (`data/augments/*.tres:17-19`). |
| Attempt modifiers (Doctrine StatDeltas) | `player.gd:496-497`, `MCE_AddStatDelta.gd` | Doctrine Record titles only | Partial | `RunSheetHUD.gd:313-337` prints stage/title; gift/price text only on the choice screen. |
| Follower belief → Power | `player.gd:500-501`, `global.gd:802-806` | none | **Invisible** | Only "Belief feeds your Power." in `Augment_CultOfPersonality.tres`; no number anywhere. |
| Equipped item flat mods | `player.gd:504-506`, `Inventory.gd:165-187` | Profile delta column; ItemTooltip ITEM STATS | Explained | |
| Rarity potency inside rolled_mods | `ItemInstance.gd:209-232`, `RarityMath.gd:17-19` | "Set strength x→y" (comparison only); "(rarity scales)" in effect shorts | Partial | No surface separates base vs potency; curve never stated. |
| Set tier stat mods | `player.gd:508-510`, `SetTier.gd:14-16` | Sets dossier `mechanical_description` | Explained (authored duplicate) | See §5. |
| Set effect scaling by rarity ("set strength") | `SetRunner.gd:31-34`, `Inventory.gd:331-333` | Glossary, comparison row | Partial | Glossary does not say tier stat mods are flat and only effect scenes scale (`SetRunner.gd:40`). |
| Set breakpoints | `SetData.active_tiers` | Notifier, tooltip preview, dossier | Explained | |
| Polarity composition / parity | `BurdenSnapshot.gd:43-45,92-93` | ItemTooltip "counts as NEG for parity and sets" | **Over-claim** | `is_balanced`/`neg_count` are read only by BurdenSnapshot, BuildIdentity and UI; no set or acquisition code consumes parity. |
| Scripted item effects (stats + multipliers) | `ItemEffectRunner.gd:78-136`, `player.gd:380-400,611-628` | `get_effects_short` in tooltip | Partial | Never attributed in Profile; POW/HST totals exclude `get_power_multiplier`/`get_haste_multiplier`. |
| Manifestation stat contributions | `ManifestationRunner.gd:591-599` | describe() text | Partial | LCK total silently includes fortune-noun Luck. |
| Manifestation multipliers (power/haste/speed/damage-taken/evasion, attack bonus) | `ManifestationRunner.gd:635-680,721`, `player.gd:611-630` | describe() text | Partial | Profile POW unchanged by an Anchor Rite ×1.85. |
| Duplicate-rule falloff | `ManifestationRunner.gd:615-632` | none | **Invisible** | |
| Manifestation potency/threshold per rank | `ManifestationEffect.gd:80-99` | Baked into describe() | Partial | "Duplicates rank this item up" (`ItemTooltip.gd:203`) hints, no rate. |
| Nouns, counts, "two of a noun" | `ManifestationRunner.gd:799-812` | HUD row, sheet noun row, intro card, ×2 tip | Explained | |
| Pairs | `ManifestationPairCatalog.gd`, `Runner.gd:299-315` | Sheet pairs, PairNotifier | Explained | |
| Meters | `ManifestationState.gd:833-932` | HUD row + sheet meters row | Explained | |
| Bond multiplier (drop weighting toward held nouns) | `ManifestationCatalog.gd:280-318` | Intro card sentence | Partial | Weighting never stated. |
| Slot chance / NEG bonus / Luck bonus for rolling a rule | `ManifestationCatalog.gd:27-45,260-267` | none | **Invisible** | |
| Per-slot roll (× for HP/ARM/SPD, + for POW/HST/LCK; clamps) | `player.gd:534-556` | Slot label "+NN" (`InventorySlotView.gd:311`); tooltip only for NEG or in comparison | Partial | POS roll % absent from the main tooltip; multiplicative vs additive never stated; HP "(+24)" delta ignores the multiplier. |
| Burden snapshot | `BurdenResolver.gd:47-110` | Sheet BURDEN, NEG tooltip lines | Explained | |
| Corruption Engine | `player.gd:566-576` | Sheet :452-466 | Explained | Literals duplicated (§5). |
| Doctrine of Burden | `player.gd:582-587`, `BurdenResolver.gd:124-129` | Sheet :468-485 | Explained | Augment `details` mis-states the qualifier (§4). |
| Inversion Lens suppression | `player.gd:543-544`, `BurdenResolver.gd:87-92` | Sheet :487-499, tooltip SUPPRESSED | Explained | |
| Inversion Lens Luck kicker | `player.gd:591-595` | none | **Invisible** | Not in the sheet's Lens line nor `Augment_InversionLens.tres`. |
| Doctrine final `max_hp_mul` (−25 % / −30 %) | `player.gd:599-600`, `global.gd:1057-1060` | choice-screen `price_text` only | **Invisible in-run** | Profile HP total silently reduced. |
| Doctrine rules (threat mul, healing muls, rite rules, witness) | `global.gd:1002-1075`, `ThreatDirector.gd:541-558`, `ExitRite.gd:447-468` | Doctrine Record titles, "WITNESS EXPENDED" event | Partial | Numbers never shown. |
| Merges (gap half-life, quality, overflow, curse stabilise/deepen) | `ItemInstance.gd:148-208`, `RarityMath.gd` | Meter bar R→R+1, feed-direction line | Partial | Maths invisible. |
| Luck effects (12 resolvers, softcap 0.5) | `core/systems/items/LuckResolver.gd` | Lucky Charm details (qualitative), LUCKY/EVADED callouts, LCK % total | Partial | Effective luck and actual crit/evade/drop %s never shown. |
| Armor formula 100/(100+armor); evasion clamp | `player.gd:1013-1033` | Glossary "according to the player defense rules" | **Invisible** | |
| Style regen / lifesteal budgets | `player.gd:60-70,1164-1235` | none | **Invisible** | |
| Followers as currency / respawn cost | `global.gd:1913-1923`, FollowerFeedbackUI | Pill tooltip (`hud.gd:544`), feed cards | Explained | |
| Resonance / Exit Rite | `ExitRite.gd`, `HudGateOverlayController.gd`, checklist | bar, SEALED/READY, checklist, "Rite draws for Ns" tip | Explained | |
| Rite channel pressure (spawn ×0.6, elite +0.15) | `ThreatDirector.gd:160-166,457-458` | none | **Invisible** | Tip at `ExitRite.gd:508` says "hold the circle", not that the world escalates. |
| ThreatDirector pressure | `ThreatDirector.gd:429-539` | ThreatTooltip | Explained | |
| Elite chance | `ThreatDirector.gd:511-512` | none | **Invisible** | Received and discarded: `HudThreatController.gd:193` `_elite_bonus` unused. |
| Segment phases | `ThreatDirector.gd:440-456`, `SegmentProcBuilder.gd:517-520` | Only "THE DISTRICT SHIFTS — X" popup (`EncounterDirector.gd:226`) | Partial | `segment_phase_changed` has no UI consumer; the popup vanishes if callouts are off. |
| Encounter beats | `EncounterBeats.gd`, `EncounterDirector.gd:262-264` | Beat label popup | Partial (callout-gated) | |
| Cursed Vault | `CursedVault.gd:74-78,125-132` | Tip + two popups | Explained (reward rarity 4-5 unstated) | |
| Power-contrast window | `ThreatDirector.gd:168-245,496-499` | none | **Invisible** | `power_threshold_noted` has no UI listener; the label "3 Manifestations active" (`ManifestationRunner.gd:775`) is never displayed. |
| HitFeel | `autoload/HitFeel.gd` | none (respects reduced_motion) | Invisible by design; not a build mechanic | |
| Build identity ("What am I?") | `BuildIdentity.gd` | One sentence on the sheet | Explained; Luck clause dead (§4) | |

---

## 3. §15 "Why did this number change?" ledger

**No surface shows a per-stat breakdown.** The closest is Profile's parenthesised item delta (`RunSheetHUD.gd:105-131`), explicitly informational, covering only `inv.sum_mods()`, and misleading for HP/ARM/SPD because the slot roll multiplies after the flat add (`player.gd:551-553`).

Data that already exists to build one (all reachable from `recompute_run_stats`, `player.gd:481-604`):

- `base_stats` (`:486`); `RaceData.apply_to` / `StyleData.apply_to` (`:489-491`).
- Per-augment `AugmentData.mods` + `Global.get_augment_level` + `apply_to_stats_at_level` (`global.gd:816-834`, `AugmentData.gd:30-46`).
- `Global.attempt_stat_delta` (`:496-497`); `Global.follower_belief_power()` (`:500-501`).
- `Inventory.sum_mods()` and per-item `rolled_mods` (`Inventory.gd:165-187`); the base-vs-potency split is reconstructible from `data.mods`, `data.rarity_base` and `RarityMath.potency(rarity + meter)` (`ItemInstance.gd:213-232`).
- `SetData.active_tiers(count)` → `tier.mods` (`SetRunner.gd:36-41`).
- `ItemEffectRunner`/`ManifestationRunner` `apply_to_stats` per node, `state.bonus_luck()` (`ManifestationRunner.gd:591-599`).
- `BurdenSnapshot` per-slot `entries` {severity, ratio, active, suppressed, qualifies}, `BurdenResolver.doctrine_bonus`, `asymptotic_rate`, `inverted_return`.
- `Global.get_doctrine_rule(&"max_hp_mul")` (`global.gd:1057-1060`).
- `RunSheetHUD._manifestation_state` already gathers burden/summaries/pairs/nouns/meters (`:371-398`).

What is missing:

- `recompute_run_stats` mutates one `Stats` in place; no step records `{source, stat, before, after}`. A ledger needs an ordered list appended at each of the ~13 existing steps (order matters: multiplicative slot rolls and Doctrine HP % come after flat adds; `max_hp_mul` is last).
- `StatDelta` carries no source label; effect nodes' `apply_to_stats` have no "describe contribution" hook.
- The Corruption ceiling `0.24`, cap `0.30`, and Lens luck ceiling `0.30` are unnamed literals in `player.gd:574,576,595` (not in `BurdenResolver`), so UI must copy them.
- Runtime multipliers (`get_power_multiplier`, `get_haste_multiplier`, `get_move_speed_multiplier`, `consume_attack_bonus`) live outside `Stats`; the ledger must poll them separately, as `_fire_weapon` (`player.gd:611-628`) and `get_effective_move_speed` (`:380-400`) already do.

---

## 4. Ten most important invisible or wrong explanations (ranked), with minimal surfacing fixes

Surfacing existing truths only — no design changes.

1. **No per-stat ledger** (§15 core ask). Fix: in `recompute_run_stats`, push `{label, stat, before, after}` into a `last_stat_ledger` array at each existing step (race, style, augments, doctrine delta, belief, items, sets, item effects, manifestations, slot rolls, Engine, Doctrine, Lens, max_hp_mul); render rows under each Profile stat in `_refresh_profile`. Every number is already computed there.
2. **Profile POW/HST/SPD hide runtime multipliers.** `RunSheetHUD.gd:101-102` prints `stats.power/haste`; real damage also multiplies by `ier.get_power_multiplier()`, `mr.get_power_multiplier()` (`player.gd:611-628`). Fix: append "× %.2f (rules/items)" using the same runner calls; SPD already does this via `get_effective_move_speed`.
3. **AugmentTooltip stats are unscaled and Luck is formatted as an integer.** `AugmentTooltip.gd:110-111` uses `a.mods`; `:155` prints `"%+d Luck"` so Lucky Charm (+0.5) reads "+1 Luck" while every other surface prints Luck as %. Fix: compute the level-scaled delta (same formula as `AugmentData.apply_to_stats_at_level`) and format luck via a %-style helper.
4. **Doctrine (Major Choice) prices are invisible in-run.** `max_hp_mul` 0.75/0.7 applied at `player.gd:599-600`; Doctrine Record lists titles only. Fix: print `gift_text` / `price_text` under each stage and a "MAX HP ×%.2f" line from `get_doctrine_rule(&"max_hp_mul")`.
5. **Power-contrast window is never announced.** `ThreatDirector.power_threshold_noted` has no UI listener. Fix: `HudThreatController` connects to it, emits a `tutorial_tip` with the label, and appends "Enemy scaling held — %ds" to the tooltip while `power_contrast_active` (expose `_contrast_left`).
6. **Threat tooltip omits phase, rite channel and elite chance.** Fix: three extra lines from `_td.segment_phase`, `_td.rite_channel_active`, and the already-received `elite_bonus` (discarded at `HudThreatController.gd:193`).
7. **Follower belief → Power is invisible.** `global.gd:802-806`. Fix: followers pill tooltip adds "Belief: +%d%% Power"; ledger row in Profile.
8. **Inversion Lens Luck kicker is invisible.** `player.gd:595`. Fix: the sheet's Lens line appends "Luck +%d%%"; hoist `0.30` into `BurdenResolver` next to `INVERSION_RETURN`.
9. **BuildIdentity Luck clause can never fire.** `BuildIdentity.gd:72-73` tests `luck >= 20.0` but `Global.run_luck` is a fraction (0.5 = +50 %, `LuckResolver.SOFTCAP 0.5`); `BuildIdentityTest.gd:56` passes `38.0`, hiding it. Fix: threshold `0.20`, print `luck*100` with `%`; fix the fixture. *(Introduced 2026-08-27 — my defect.)*
10. **Item tooltip over-claims parity and hides the POS roll.** `ItemTooltip.gd:254,260` say a curse "counts as NEG for parity and sets" but nothing outside Burden/UI reads parity; POS items show their roll only in the comparison block or the slot label. Fix: reword to "polarity census"; add an "EFFECT ROLL +NN% (× on this slot)" line mirroring the NEG burden line.

Runner-up: Doctrine of Burden `details` says "at least 10% severity" while code qualifies by ratio of the authored range and excludes accessories — the sheet line is correct, the augment text is stale; Luck's actual crit/evade/drop %s could be listed on LCK hover; encounter/phase/vault announcements disappear entirely when `ability_callouts` is off — route them through `tutorial_tip` as well; Manifestation slot chances, bond weighting and duplicate-rule falloff have no surface.

---

## 5. Hard-coded UI/data numbers that duplicate code constants

| UI / data side | Code side | Note |
|---|---|---|
| `ui/widgets/RunSheetHUD.gd:456` `0.24` | `core/actors/player/player.gd:574` `0.24` | Corruption ceiling; unnamed literal in both. Also `data/augments/Augment_CorruptionEngine.tres:12-15`. |
| `RunSheetHUD.gd:462-463` `0.30` | `player.gd:576` `minf(0.30, …)` | Corruption cap; also in the `.tres` text. |
| `Augment_InversionLens.tres` "55% of its severity returns" | `BurdenResolver.gd:16` `INVERSION_RETURN = 0.55` | Sheet computes via `inverted_return()` — fine. |
| `Augment_DoctrineOfBurden.tres` "at least 10% severity" | `BurdenSnapshot.gd:32` `QUALIFYING_BURDEN_RATIO = 0.10` | Semantics differ (ratio of range vs absolute). Per-item 16 armour / 9 % HP and caps 96 / 54 % appear nowhere in the augment text. |
| `Augment_CultOfPersonality.tres` "10% … +5% per level … up to +20%" | `EnemyLifecycle.gd:94`, `EnemyCombatService.gd:113`, `LuckResolver.gd:41-42` | Two code copies plus text. |
| `Augment_LuckyCharm.tres` "+0.5 Luck" | same file `luck = 0.5`, `mods_scale_per_level = 0.2` | Stale at Lv≥2; shown as "+1 Luck" by `AugmentTooltip.gd:155`. |
| `Augment_StaminaCore.tres`, `Augment_SprintServos.tres`, `Augment_TeslaAura.tres`, `Augment_SummonSpiderlings.tres`, `Augment_ReflectShield.tres` details | same files' `mods` + `mods_scale_per_level` | All stale after any level-up; `apotheosis_perfected_engine.tres:12` grants +2 levels. |
| `data/sets/gravemarch/Gravemarch.tres:18,31,45` | same file `:11-13`, `:25`, `:39` | Authored duplicates of tier `mods`. |
| `Gravemarch.tres:45` "spend 60% of the current threshold" | `GravemarchMassArrest.gd:40` `active_bank_fraction = 0.60` (an `@export`) | Can drift via scene override. |
| `data/sets/lattice/Lattice.tres:17,30,45`; `data/sets/conduit/Conduit.tres:18` | same files | Duplicates. |
| `method_frame_of_ash.tres:29-30`; `apotheosis_perfected_engine.tres:33-34` | same files | Duplicates. |
| `ItemTooltip.gd:269-271` weight words at severity 0.70 / 0.40 | `BuildIdentity.gd:19` uses 0.50 for "catastrophic" | Two vocabularies for one word. |
| `ItemTooltip.gd:418` breakpoint pips hard-code 2/4/6 | `SetTier.required_count` per set | Works today because all three sets use 2/4/6. |
| `RunSheetHUD.gd:181` fallback `set_max := 6` | `SetData.max_pieces()` | Fallback only. |
| `HudThreatController.gd:8,182` `tier_size 25` | `ThreatDirector.gd:520` | UI-only convention. |

Key files for follow-up: `ui/widgets/RunSheetHUD.gd`, `ui/widgets/ItemTooltip.gd`, `ui/widgets/AugmentTooltip.gd`, `core/actors/player/player.gd` (481-604), `core/systems/run_sheet/BuildIdentity.gd`, `ui/controllers/HudThreatController.gd`, `autoload/ThreatDirector.gd`, `core/systems/items/BurdenResolver.gd`.
