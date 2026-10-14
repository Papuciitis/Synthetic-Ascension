# Augment balance and artwork audit

2026-10-14 · Completed implementation and verification record

The pass strengthens eight augments that needed a clearer early payoff and retains eight whose existing role is already distinct. Combat and passive changes, descriptions, readouts and 52 painted illustrations are implemented. All existing Duos, Facets and Transcendences were reviewed; specific future tuning and addition proposals are recorded separately from shipped changes. Automated checks and actual Godot card captures verify the implementation; human playtesting remains necessary to judge encounter feel.

## Balance decisions

Values describe the unmodified level-one ability. Combat damage uses native attack damage `D` and gains 35% of its level-one value per rank through level 20; count growth stops after eight rank steps. Facets, Duos and Transcendence modify these baselines.

| Augment | Decision and reason |
|---|---|
| Magic Missile | **Buff:** each missile rises from 0.45D to 0.75D. Retain two seeking shots, 0.75s cadence and count growth; its automatic volley should feel useful immediately. |
| Tesla Aura | **Retain:** 0.5D per zap, four targets, 0.55s cadence and +10% Haste. Its sustained coverage and existing combinations already give it a clear role. |
| Spirit Slash | **Buff and simplify:** strike two nearest targets for consistent 2.4D each at every ordinary rank; start with two Bleed stacks, +1 stack per four count steps, maximum four. Keep the 50% manual refund and 12% stun/knockback proc without describing the latter as extra critical damage. A manual cast receives dependable area payoff. |
| Blink Hex | **Buff and simplify:** cooldown 6s → 4s; consistent 3D mark bonus, one empowered attack and 10% refund, with existing mark growth. More frequent movement makes the active more useful without raising its average damage coefficient. |
| Summon Spiderlings | **Buff and simplify:** two per cast instead of one, 70px blasts instead of 52px, consistent 1.4D detonations; retain 0.5D bites and living caps 7/11/14 at L1/L5/L10. A cast establishes a useful brood while the population remains bounded. |
| Reflect Shield | **Retain:** +8 Armor; 0.14s parry, 0.06s perfect window, 0.40s cooldown. Perfect reflection already supplies a potency-scaled zap floor of 1.2D and supports Bulwark Engine. The earlier shield request is already represented by this ability. |
| Stamina Core | **Retain:** +80 HP, +10 Armor, 2s initial invulnerability and 25% lifesteal during its 4s manual active. Protection and recovery already offer a substantial tactical choice. |
| Sprint Servos | **Retain:** +100 Move Speed and +12% Haste, with existing stat growth. Movement is valuable on its own and feeds Slipstream Coil. |
| Lucky Charm | **Retain:** +0.5 Luck and existing growth. It supports item quality, drops, evasion, lucky hits and recruitment rather than adding another damage button. |
| Corruption Engine | **Buff:** level-one severity conversion 12% → 25%, ceiling 24% → 50%, Power cap 30% → 45%. Keep the two strongest active stat curses and deeper negative merges; concentrated curses should repay the risk earlier. |
| Doctrine of Burden | **Retain:** +8 Armor and +4.5% Max HP per qualifying curse at L1, ≥10% authored-range threshold. Its count-based defense remains distinct from severity conversion. |
| Inversion Lens | **Retain:** suppress one worst stat curse, return 55% as its own stat, plus 15% of suppressed severity as Luck at L1. The suppression itself is valuable and preserves its single-curse identity. |
| Equilibrium Sigil | **Retain:** +12% Power and Haste at L1, each capped at 20%; exact parity with ≥2 items of each polarity. Bag routing protects the deliberate equipment choice. |
| Litany of Wounds | **Buff:** start below 80% HP instead of 60%, reach full effect at 30% instead of 20%; level-one severity share 25% → 35%, ceiling 50% → 70%, Haste cap 35% → 45%. More of the health bar now supports the build. Requiem retains 85%/35% thresholds and 70% caps. |
| Cult of Personality | **Buff early recruitment:** base 10% → 25%; rank growth becomes +2.5 points and the normal cap is 75%. Luck remains additive. A higher early chance makes recruitment noticeable, while the slower rank slope controls late growth. |
| Gambler's Rite | **Buff and add meaningful normal ranks:** base 15% → 35%, +1.5 points per rank, normal cap 60%; distinct curse Resonance 0.5% → 2%, segment cap 4% → 12%. House Edge retains a doubled chance capped at 70% and pays two Followers. |

At zero Luck, Gambler's Rite recruits at 35% / 41% / 48.5% at L1 / L5 / L10, reaching 60% at L18. House Edge already reaches its 70% cap at L1 with zero Luck, so its later ranks do not increase this chance. Loaded Dice adds 15 points after that calculation, up to 85%. Only genuinely new world pickups qualify; moves, trades, rewards and undo do not.

Spirit Slash hits and Bleed stacks, Blink Hex bonuses and spiderling detonations replace tabletop damage/stack rolls with consistent outcomes. Explicit proc, refund and recruitment chances remain. The descriptions use direct numbers and probabilities.

Missiles retarget if their victim dies before the remaining volley or during flight, while retaining range, lifetime and wall collisions. Choir shards exclude the parent's victim when acquiring, retargeting and checking swept collisions. Pool reuse clears that exclusion. Blink empowers the player's subsequent attacks; it does not require an enemy-target mark.

## Readouts and illustrations

All sixteen resources have distinct `assets/ui/augments/cards/<slug>.png` paths, replacing eight shared portrait assets. Six curse passives previously displayed Reflect Shield; Cult of Personality displayed Spiderlings; Lucky Charm displayed Blink Hex. The full set contains **16 base, 16 Transcendence, 14 Facet and 6 Duo illustrations**. Game textures are 512×512; the generated masters are preserved outside the game export.

The approved Magic Missile and Spirit Slash images were the direct style references for repainting the other cards: coarse matte painting, visible edges and atmospheric ability scenes. The set uses a serious tone, warm stone backgrounds and clear magic phenomena, avoiding enemy/villain backdrops, literal Tesla hardware and shiny photorealism. Upgraded forms change the depicted action: more projectiles or cuts, larger or branching fields, altered guards and brood behavior, or both powers working together in a Duo. The wrapper supplies the frame, labels and rarity color.

Exact prompts, reference paths and generated source paths are archived in [the 52 prompt records](../art/augment-card-prompts/). [ExportAugmentCards.ps1](../../tools/art/ExportAugmentCards.ps1) validates sources and makes the 512px exports, 220px/40px contact sheets and SHA-256 manifest. Painted illustration nodes use linear filtering; pixel book, backdrop and seal textures retain nearest filtering.

[AugmentArt](../../core/systems/augments/AugmentArt.gd) resolves Transcendence, then the chosen Facet, then base art. Explicit upgrade previews show their prospective form before ownership, with matching title and rules. Duo offers use combined art; individual equipped icons retain their own identity. Offers, the Facet chooser, HUD, tooltips, Library and Reliquary use this resolver. Base Library entries and undiscovered forms preserve their existing visibility rules.

[Actual Godot captures and contact sheets](../art/reference/augment-cards-2026-10-14/) show the whole set. [AugmentArtGallery](../../tools/dev/AugmentArtGallery.gd) renders real cards and all seven Facet choosers in an isolated process with autosaves disabled; it neither starts a run nor binds a pick. QA images are excluded from game imports with `.gdignore`.

Descriptions now label level-one baselines and separate damage growth from stat growth. The generic damage note appears only for Magic Missile, Tesla Aura, Spirit Slash, Blink Hex, Spiderlings and Reflect Shield; Stamina Core and Litany no longer imply a damage payload. The Run Sheet reads actual recruitment and curse conversion formulas.

## Existing combinations and proposed upgrades

The current implementation has **six Duos, fourteen Facets across seven augments and sixteen Transcendence definitions**.

The [full combination audit](2026-10-14-augment-combinations.md) covers all 36 definitions, rank comparisons, stacked interactions and inherited investigation concerns. It identifies high-rank diminishing value in Salvo/Swarm, Lance's count rounding and capped House Edge progression. Proposed remedies and new curse-build combinations are documented there; they have not been silently added to this balance pass.

| Duo | Members | Existing payoff |
|---|---|---|
| Lightning Rods | Magic Missile + Tesla Aura | Missile hits arc to two more targets at 60% damage. |
| Phantom Step | Blink Hex + Spirit Slash | A blink supplies free cuts to three enemies near the landing. |
| Static Brood | Spiderlings + Tesla Aura | Each bite leaps to another enemy for full bite damage and a short stun. |
| Bulwark Engine | Reflect Shield + Stamina Core | Perfect parries heal 6% max HP and refund 2s of Core cooldown, once per second. |
| Slipstream Coil | Sprint Servos + Tesla Aura | Moving makes Aura pulse 50% faster. |
| Loaded Dice | Lucky Charm + Gambler's Rite | Lucky hits may recruit once per second; Rite receives +15 chance points. |

Facets cover Missile, Aura, Slash, Blink, Spiderlings, Shield and Core. Corruption Engine, Doctrine of Burden, Inversion Lens, Equilibrium Sigil, Litany and Cult have no Duo membership in the six-pair roster. Gambler's Rite already has Loaded Dice; it should not be grouped into a claim that every passive lacks combinations.

The base buffs also strengthen Lightning Rods, Phantom Step and Static Brood. Review their effective damage, target limits and cadence before increasing their multipliers further. Preserve the distinction between an always-available base ability, a specialized Facet and a conditional Duo.

The following are **proposals**, separate from this balance pass:

- **Curse Facets and Duos:** add deliberate choices around severity, curse count, parity and low health. Respect Lens suppression: it keeps negative polarity for Equilibrium but removes that curse from Engine/Litany severity and Doctrine count.
- **Breaking and restoring parity:** `docs/design/NEG_BUILDCRAFT_ARCHETYPES.md:80` explicitly defers items or sets that react to breaking equilibrium. A deliberate break/restore payoff remains a possible addition.
- **Placed containment sigil:** a manual cursor-placed control zone could add deliberate positioning. Its cast interaction must differ from existing automatic item Manifestations; tuning and implementation are still open.

The available record of “Augment creation help” exposed five turns. The shield request is already implemented; no older requirements have been reconstructed from missing history.

## Reference principles

[Mega Crit's art-direction discussion](https://megacrit.com/news/2024-10-02-neowsletter-issue-3/) prioritizes clear small drawings and explains readability failures from ambiguous poses. The [official Slay the Spire screenshot](https://megacrit.com/images/ss8.jpg), from its [studio press kit](https://megacrit.com/press-kits/slay-the-spire/), shows compact action motifs such as Thunderclap's foot/impact. These support readable compositions; the coarse painted medium is the user's direction.

[Supergiant's boon-interface update](https://www.supergiantgames.com/blog/get-pumped-for-the-beefy-update/) provides a functional reference for presenting many powers together. It does not describe an illustration production process. [Red Hook's official media page](https://www.darkestdungeon.com/darkest-dungeon/media/) was verified as a reference catalog; individual gallery screenshots were not inspected.

## Verification

The pre-pass `AugmentPotencyTest` baseline was **27 passed, 0 failed**. New regression checks first reproduced unreliable combat outcomes, absent art resolution and mismatched explicit-form prose, then passed with the fixes. Final verification results and the controlled output probe are recorded below. These checks do not substitute for a human playtest.

### Focused automated coverage

Run individually with Godot 4.7.1, followed by ScriptParseAudit last. **21 suites, 3,488 passing checks, zero failed checks.** This is the focused augment/UI/economy battery, not a claim that every unrelated repository suite ran.

| Suites | Passing checks |
|---|---:|
| AugmentCombatReliability / AugmentPotency / EnemyHandleTargeting | 23 / 26 / 14 |
| FacetDuoEffectsA / FacetDuoEffectsB / AugmentTranscendence | 50 / 48 / 65 |
| PassiveAugmentReward / BurdenSystem / NegArchetypes | 14 / 74 / 67 |
| FollowerEconomyV3 / RunSheetLedger / RunSheetArchive | 134 / 90 / 59 |
| AugmentBinding / AugmentOffer / BindingRitesUi | 64 / 5 / 125 |
| AugmentArt / AugmentTooltip / ChoiceCopyFit | 33 / 25 / 182 |
| HubLibraryData / ReliquaryScreen | 1,813 / 70 |
| ScriptParseAudit | 507 scripts |

Core fixtures in FacetDuoEffectsB and AugmentTranscendence still emit their known missing-Hurtbox aura warnings. The BurdenSystem fixture's temporary ItemEffectRunner was explicitly freed to remove its exit leak. No functional test failure was accepted as a pass.

The artwork export has 52 matching source/export records and zero SHA-256 mismatches. All four illustration groups were inspected at 220px and 40px. The gallery captures 7 card pages and all 7 actual Facet choosers at 1280×960, with saves disabled. Its card grid freezes the deal animation so a capture cannot hide cards behind a longer sibling-index stagger.

### Controlled output probe

`AugmentPowerProbe` completed with exit 0 using a fixed 60Hz step, fixed seeds and a ten-second, 40-immortal-dummy crowd. Values are aggregate crowd damage in native hits per second, not single-target DPS or encounter success rates. Manual actives are used immediately when ready. No Facets, Duos or Doctrines are enabled.

| Augment | L1 ordinary / Transcended | L5 ordinary / Transcended | L10 ordinary / Transcended |
|---|---:|---:|---:|
| Magic Missile | 1.8 / 5.4 | 8.7 / 21.8 | 24.3 / 57.6 |
| Tesla Aura | 3.6 / 7.9 | 15.8 / 34.6 | 44.8 / 98.1 |
| Spirit Slash | 3.5 / 4.6 | 15.7 / 22.1 | 31.5 / 58.8 |
| Summon Spiderlings | 2.5 / 2.5 | 9.3 / 9.3 | 16.0 / 16.0 |

The immortal crowd does not exercise Thousand Cuts' kill chains or Brood Mother's kill hatches, and its short window does not represent expiry detonations. Spirit Slash still has a random manual cooldown refund, so a single ten-second window is not an expectation over many runs. Earlier unseeded probes are not a controlled before/after comparison for that ability. The dedicated reliability suite, rather than this DPS table, verifies fixed cut damage and Bleed stacks.

Blink's separate analytic mark budget is 0.8 / 7.5 / 24.9 D/s ordinarily and 1.5 / 10.1 / 29.9 when Transcended at L1/L5/L10, assuming every mark is spent before the next blink and excluding refunds. Hexgate also supplies two 2.5D-potency rifts per blink, requiring nearby victims at each end. These analytic budgets do not measure actual attack timing or charge use.

Human follow-up: compare early casts against a durable isolated target, sparse enemies and a crowd; judge the new low-health/recruitment payoff; then test high-rank Circuit combinations. The separate combination audit records the inherited Crown overlap and perfect-parry refund concerns, plus targeted future Facet/rank proposals.
