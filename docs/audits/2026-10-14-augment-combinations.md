# Augment combinations: current behavior and future options

2026-10-14 · Read-only balance audit

This audit covers all **6 Duos, 14 Facets and 16 Transcendences**, including their runtime hooks and interaction with the current augment balance pass. The current-mechanics sections describe implemented behavior in the reviewed source. The proposal sections describe future work only: **no new combinations or proposed tuning changes have been implemented by this audit**.

The strongest existing combinations already have a substantial payoff. The most useful next improvements are restoring value to capped ranks, repairing Facets that weaken as their augment grows, and giving curse builds distinct combination choices. Increasing every damage multiplier would obscure those problems and further strengthen combinations that already compound.

## How to read the numbers

These are calculations from source, not measured DPS or playtest results. They assume unmodified Facets and Duos, valid targets, no mitigation, and sufficient enemies where a row describes maximum coverage. Travel time, walls, missed targets, cooldown frame timing and early enemy deaths can reduce the result. A full Bleed comparison assumes an isolated target survives its entire duration without reapplication.

- `D` is the player's native hit before runner multipliers: base weapon damage × combat-style damage multiplier × `max(0.05, 1 + Power)`. It excludes lucky crits, temporary attack bonuses and the native-only damage price of The Engine Prays.
- Augment damage gains 35% of its level-one payload per rank. At ranks **3 / 5 / 10**, potency is **1.70 / 2.40 / 4.15**.
- Most count, reach and cadence growth uses at most eight rank steps, reaching that limit at rank 9. Thousand Cuts is an exception: its target count uses the full rank, `3 + floor(rank / 4)`.
- Most Duos and Facets become available at rank 3, or rank 2 with their respective voucher. A Duo needs both members equipped and its Duo card taken; owning the pair alone does not activate it.
- Ordinary Transcendence requires rank 5 and a catalyst. The rank-3 Transcendence figures below are comparisons for an exceptional grant such as The Engine Prays, not a normal rank-3 offer.
- Chance increases expressed as **points** mean percentage points. A 15-point increase changes 40% to 55%.

The shared definitions are [AugmentScaling](../../core/systems/augments/AugmentScaling.gd), [AugmentDuos](../../core/systems/augments/AugmentDuos.gd), [AugmentFacets](../../core/systems/augments/AugmentFacets.gd), [BurdenResolver](../../core/systems/items/BurdenResolver.gd), and [LuckResolver](../../core/systems/items/LuckResolver.gd). The [current balance-pass record](2026-10-14-augment-pass.md) documents the approved base changes.

## Current Duos

| Duo and members | Rank 3 / 5 / 10 payoff | Reliability and limits | Assessment |
|---|---|---|---|
| **Lightning Rods** — Magic Missile + Tesla Aura | Up to **+4.59 / +8.64 / +22.41 D** across an ordinary volley. Each hit arcs to two other enemies for 60% of that missile's damage. | Needs other living enemies within 170px of each victim. Choir shards also trigger arcs; arcs do not recursively make more missiles. | Strong after the missile payload buff. Preserve its target and distance limits before considering further damage. |
| **Phantom Step** — Blink Hex + Spirit Slash | Three free cuts total **12.24 / 17.28 / 29.88 D**, plus the Slash's deterministic Bleed and control chance. | Chooses up to three nearest enemies within 220px of the landing. Does not spend Slash cooldown or create another active-use cross-lock. | Clear positional play. The shorter Blink cooldown already improves the Duo. |
| **Static Brood** — Spiderlings + Tesla Aura | An additional **0.85 / 1.20 / 2.075 D** per normal bite, with a 0.1s stun. | One other enemy within 150px. No additional damage against an isolated target. Living spiders remain capped. | Can double bites against a pair and spread control across a pack. Already benefits from the larger initial brood. |
| **Bulwark Engine** — Reflect Shield + Stamina Core | At every rank: a perfect parry heals **6% Max HP** and removes **2s** from Core cooldown. | At most once per second. Core refunds cannot end its cooldown inside the remaining invulnerability plus its 1.5s gap. | Strong defensive loop with a meaningful parry requirement. See the separate inherited Shield-refund concern below. |
| **Slipstream Coil** — Sprint Servos + Tesla Aura | **50% faster** pulses while moving, until the 0.15s pulse floor. | Movement is read from position change. Once other Haste reaches the floor, further acceleration can shrink to zero. | Good early and middle progression. Show its effective benefit clearly when the floor is reached. |
| **Loaded Dice** — Lucky Charm + Gambler's Rite | Rite acquisition chance gains **15 points**. With only the pair's own Luck, ordinary chance is approximately **61.2% / 65.5% / 74.2%**. House Edge reaches **85%** at all three ranks. | A lucky native attack with an enemy within 600px recruits one Follower, at most once per second. The ordinary Rite's base calculation caps at 60% before the Duo; final chance caps at 85%. | Broad economy value. The recruitment trigger does not require a confirmed hit, but it does require a nearby enemy. |

Runtime hooks: [Missile projectile](../../effects/augments/logic/MagicMissileProjectile.gd), [Blink Hex](../../effects/augments/logic/HexBlinkMarkEffect.gd), [Spirit Slash](../../effects/augments/logic/SpiritSlashEffect.gd), [Spiderling](../../effects/augments/logic/PoisonSpiderling.gd), [Tesla Aura](../../effects/augments/logic/TeslaAuraEffect.gd), [Reflect Shield](../../effects/augments/logic/ReflectShieldEffect.gd), [Stamina Core](../../effects/augments/logic/StaminaCoreEffect.gd), and [Global's economy hooks](../../autoload/global.gd).

Six curse passives currently have no Duo membership: Corruption Engine, Doctrine of Burden, Inversion Lens, Equilibrium Sigil, Litany of Wounds and Cult of Personality. Gambler's Rite has Loaded Dice and should not be counted as lacking combinations.

## Current Facets

Ratios compare with the same augment and rank without a Facet. They describe ordinary forms unless a row explicitly discusses Transcendence.

| Augment / Facet | Rank 3 / 5 / 10 result or fixed rule | Assessment |
|---|---|---|
| Magic Missile / **Salvo** | Two extra missiles; each ×0.75. Total volley damage becomes **×1.25 / ×1.125 / ×1.00**. | Its damage advantage disappears at rank 9. With Choir, the corresponding ratios are **×1.125 / ×1.05 / ×0.964**: at high rank it reduces total damage. Extra hits can still feed hit-based rules. |
| Magic Missile / **Lance** | Half the missiles, rounded down, at least one; each ×2.2; reach ×1.5. Total damage is **×0.733 / ×1.10 / ×1.10**. | Odd volley sizes create damage penalties. With Choir, ratios become **×1.10 / ×0.88 / ×0.943**. The longer range remains useful, but the damage trade alternates with count parity. |
| Tesla Aura / **Overcharge** | Two fewer primary targets, at least one; each ×1.7. A full primary sweep becomes **×1.02 / ×1.133 / ×1.275**. | Consistently +70% against an isolated target. Fewer targets provide a real cost, and higher rank improves crowd output. |
| Tesla Aura / **Static Field** | Radius ×1.3, damage ×0.85, 0.1s stun. | A useful control alternative. Storm Crown already supplies 0.12s stun, so this stun does not add another 0.1s; the reach still stacks. |
| Spirit Slash / **Hemorrhage** | Cut ×0.8; Bleed ticks ×2 for ×2 duration. Isolated full cut-plus-Bleed output is approximately **×2.14 / ×2.46 / ×2.69**. | Strong against survivors. Repeated applications refresh one Bleed record; they do not accumulate independent full-duration Bleeds. |
| Spirit Slash / **Executioner** | Cut ×2 against enemies below 30% health; Bleed is based on the ordinary payload. | Useful against large health pools. Against normal enemies, the ordinary cut can already kill a weakened target, wasting much of the bonus. Narrower payoff than Hemorrhage. |
| Blink Hex / **Long Step** | Range ×1.6; cooldown ×0.75. | Strong mobility choice. Also increases the frequency of Phantom Step and Hexgate. |
| Blink Hex / **Deep Mark** | One extra marked attack; bonus per mark ×1.5. If all charges are spent, total marked bonus becomes **×2.25 / ×2.00 / ×1.80**. | Strong attack choice. A new blink replaces unused charges, so rapid blinking can waste the extra mark. |
| Spiderlings / **Swarm** | Two extra spiders per cast; every bite ×0.7. Initial bite output becomes **×1.167 / ×1.05 / ×0.933**. | At the living cap it reduces sustained bite output to **×0.70** at every rank. It fills the cap sooner, but Brood Mother already does that through kills. Detonation damage per spider is not reduced. |
| Spiderlings / **Venom Sacs** | Detonation ×1.8; radius ×1.4. Each blast deals **4.284 / 6.048 / 10.458 D** in **126 / 154 / 210px**. | Reliable and strong after the base blast-radius increase. Also modifies Brood Mother expiry blasts. |
| Reflect Shield / **Riposte** | Reflected rounds ×1.5. Against the incoming round this is **×1.605 / ×1.785 / ×1.875**. | Clear value. The perfect-zap calculation deliberately removes Riposte's multiplier before reading the reflected-round share. |
| Reflect Shield / **Long Guard** | Parry window ×1.6; authored cooldown ×1.3. Actual minimum manual cooldown, with no other modifiers, is approximately **0.440 / 0.452 / 0.484s**. | Useful defense. The remaining-window safety floor changes the effective cooldown trade at higher ranks. Perfect window is not multiplied. |
| Stamina Core / **Second Wind** | Every activation heals 15% Max HP. | Consistent value as Core's HP grows. Undying's automatic activation also heals. |
| Stamina Core / **Iron Lung** | Cooldown ×0.65; active duration ×0.75. Base cooldown is **6.89 / 6.09 / 4.75s** before Haste and Doctrine modifiers. | Useful, with the Core's invulnerability gap retained. At higher rank, active duration can still exceed cooldown. Invulnerability duration is not shortened by the Facet. |

The high-rank problems in Salvo and Swarm are consequences of fixed extra counts combined with a penalty applied to the whole payload. Lance has a separate rounding problem. These deserve targeted repairs before adding more damage Facets.

## Current Transcendences

All sixteen Transcendence definitions have runtime hooks. A rule can be implemented correctly and still have capped progression or a narrow payoff; those are balance observations rather than missing hooks.

| Augment / Transcendence | Rank 3 / 5 / 10 behavior | Strength and progression limits |
|---|---|---|
| Magic Missile / **Choir of Needles** | **4 / 5 / 7** parent missiles. Each hit creates up to two shards at 60%, seeking other enemies within 420px. | Large damage and coverage jump. Shards retain lifetime, walls, source attribution and an exclusion for their parent's victim, including retargeting and swept collision. |
| Tesla Aura / **Storm Crown** | Radius ×1.3; two hops at ×0.7 and ×0.49; 0.12s stun; elites/bosses take ×2. | Already strong coverage and control. Primary/hop overlap is an inherited investigation concern, described below. |
| Spirit Slash / **Thousand Cuts** | **3 / 4 / 5** targets; automatic casting; a kill allows up to three further waves, excluding already cut targets. | Up to **12 / 16 / 20** distinct cuts in one successful chain. Automatic casts correctly skip the 50% manual refund. Ordinary Slash remains fixed at two nearest targets. |
| Blink Hex / **Hexgate** | **3 / 4 / 6** marked attacks. Each end of a blink tears a 120px rift for **4.25 / 6 / 10.375 D** and 0.6s stun. | Substantial burst and control. Deep Mark and Phantom Step can both compound the same blink. |
| Spiderlings / **Brood Mother** | 30% of kills within 600px may hatch a spider. Expiry detonates; living caps are **9 / 11 / 14**. | Strong brood sustain. Caps keep the population bounded; Swarm has less value once kills keep the cap full. |
| Reflect Shield / **Mirror Aegis** | Opens a ward every 1.6s; reflected rounds fan into three; a perfect zap hits every enemy in range. Minimum zap per victim is **2.04 / 2.88 / 4.98 D**. | Useful defensive automation and crowded-fight payoff. Perfect-refund overlap is inherited, described below. |
| Stamina Core / **Undying Engine** | 6% permanent lifesteal; active totals **41% / 51% / 51%**. Automatically activates below 35% HP when cooldown and active window permit. | Strong recovery. Healing can intentionally shorten Litany/Requiem's low-health bonus. |
| Lucky Charm / **Fortune's Engine** | Lucky-crit chance ×2; lucky damage ×2.5 instead of ×1.5. With only Charm's own Luck, chance is **6.59% / 7.58% / 8.56%**. | Broad crit/economy value, rather than doubling average damage. Maximum chance from Luck is 16%. It blesses native attacks, not automatic augment payloads. |
| Sprint Servos / **Velocity Engine** | +30% Power per 100 move speed above 100, cap +60%. Base speed plus Servos' own bonus yields **+42% / +54% / +60% Power**. | Conversion caps, but Servos' direct Movement and Haste stats continue to grow. Temporary runner movement bonuses are outside this stat-pass conversion. |
| Corruption Engine / **Heart of Ruin** | Three heaviest active curses, cap +75% Power. Severity share is **37.5% / 41.7% / 45.5%**. | Additional intake and ceiling are meaningful. Payout still depends on active severity; Lens can remove the most valuable fuel. |
| Doctrine of Burden / **Martyr's Frame** | +5% Power per qualifying active statistical-slot curse, authored cap +40%. | Today's six qualifying slots limit the actual maximum to **+30%**, or +25% with one suppressed. Defensive per-curse growth continues: Armor **12 / 13.33 / 14.55**, Max HP **6.75% / 7.5% / 8.18%**. |
| Inversion Lens / **Twin Lens** | Returns 110% of suppressed severity as its stat, capped by the slot pass. Luck kicker pays **45% / 50% / 54.5%** of suppressed severity. | Return strength stays fixed while ranks improve the Luck kicker. Statistical returns cap at 95%, except Luck at 99.99%. Suppression still removes burden fuel. |
| Equilibrium Sigil / **Perfect Balance** | Exact parity, at least two of each polarity, pays **+36% / +40% / +43.6% Power and Haste**. | Reaches its +45% cap at rank 15; ranks 16–20 add nothing to these payouts. Ordinary Sigil already caps at rank 5. |
| Litany of Wounds / **Requiem** | Starts below 85% HP; full at 35%. At full ramp with 100% active severity, pays **+52.5% / +58.3% / +63.6%** to native weapon Power/Haste multipliers, each capped at 70%. | Strong weapon-oriented low-health build. These runner bonuses do not amplify or accelerate automatic augments. Ordinary Litany starts below 80%, fills at 30%, and caps Haste at 45%. |
| Cult of Personality / **Prophet** | Zero-Luck chance **60% / 70% / 90%**, paying two Followers. Adds 15 points to the Belief Power ceiling. | Zero-Luck chance saturates at rank 9, earlier with Luck. The Belief ceiling still requires Followers held to fill it. |
| Gambler's Rite / **House Edge** | **70% / 70% / 70%** acquisition chance, paying two Followers. First distinct curses still bank 2% Resonance, cap 12% per segment. | The doubled rank-1 base already reaches 70%. **All subsequent ranks have no payout gain after Transcendence.** Loaded Dice raises the fixed chance to 85%. |

Stat-pass hooks are in [player.gd](../../core/actors/player/player.gd); effect delivery and refresh are in [AugmentRunner](../../core/systems/augments/AugmentRunner.gd). Dynamic Litany multipliers live in [LitanyOfWoundsEffect](../../effects/augments/LitanyOfWoundsEffect.gd). Economy and Belief rules live in [Global](../../autoload/global.gd).

## Stacked combinations worth watching

### Missile, shards and arcs

An ordinary missile hit plus its two Rod arcs delivers up to `1 + 2 × 0.6 = 2.2` times that missile's damage across the pack. Choir supplies two 60% shards; each shard can also make Rod arcs. With sufficient victims, the full parent-and-shard result becomes `2.2 × 2.2 = 4.84` times parent damage.

Accounting for Choir's extra parent missile, the maximum volley totals are approximately **24.68 / 43.56 / 105.45 D** at ranks 3/5/10. This is distributed pack damage, not guaranteed damage to one enemy. Salvo's extra hit events and Lance's longer reach change delivery, but do not justify a blanket increase to this stack.

### Blink, Slash and marked attacks

Phantom Step supplies three cuts independently of ordinary Slash's two-target limit. It uses the chosen Slash Facet and Bleed but neither spends Slash cooldown nor starts another active-use lock. Hexgate adds two rifts and another mark to the blink. Deep Mark then increases both bonus per mark and charge count; Long Step instead increases blink frequency and reach.

Charge use matters: blinking again replaces unused marks. A tooltip or test should distinguish the total bonus available per blink from the bonus a player actually spends before the next blink.

### Brood, leap and detonation

Static Brood can double bite damage against nearby pairs. Brood Mother can refill spiders through the resulting kills, while Venom Sacs strengthens expiry and commanded detonations. A full normal brood's simultaneous commanded blast budget is **21.42 / 36.96 / 81.34 D** before overlapping enemy coverage. Venom raises this to **38.556 / 66.528 / 146.412 D**.

The same living caps constrain Swarm. Its faster initial filling is useful, but a full Swarm brood deals 30% less bite damage than a full ordinary brood. Brood Mother's free hatches make that sustained penalty especially visible.

### Movement, Crown and control

Static Field and Storm Crown multiply reach separately. Slipstream accelerates pulses only until 0.15s. At that floor, Crown's 0.12s stun can occupy much of the interval between pulses; Static Field does not add its stun duration on top. Existing control is already strong, so a new stun or cadence multiplier needs careful limits.

### Parry, recovery and low health

Bulwark heals and refunds Core cooldown once per second. Second Wind adds 15% Max HP per Core activation, while Undying adds permanent lifesteal. Core retains a minimum 1.5s gap beyond invulnerability, including refunds. Those are useful bounds to preserve.

Healing can reduce Litany/Requiem's ramp. This is a real build trade: the player gets recovery and safety but spends less time at maximum low-health offense. Avoid silently changing Litany into a permanent buff merely because another augment heals.

### Economy and curse wardrobes

Cult, Gambler and Loaded Dice support Tithe spending and Congregation growth. Prophet adds 15 points to the congregation-based Belief ceiling; Census of Souls can add another 20, subject to the overall 60% ceiling. These lift potential Power rather than granting it immediately.

Gambler reaches its 12% segment Resonance cap after six distinct negative base items. New world pickups qualify whether equipped, bagged or fed. Trades, rewards, undo and inventory moves do not. Resonance is segment progression; it is not another damage multiplier.

Lens preserves negative polarity for Equilibrium and sets, while removing its suppressed curse from Engine/Litany severity and Doctrine qualification. Engine wants concentrated severity, Doctrine counts qualifying curses, and Equilibrium requires exact positive/negative parity. These differences are worth retaining in new combinations.

## Interaction with Manifestations and Doctrines

Augment hits and kills use the player as source. They can feed Manifestation hit/kill hooks and Core lifesteal through the common [EnemyCombatService](../../core/systems/enemy_world/EnemyCombatService.gd) events. This gives extra projectiles and targets some value beyond their aggregate damage. [ManifestationRunner](../../core/systems/manifestations/ManifestationRunner.gd) filters ownership, not just native weapon hits.

Native attack cadence and lucky-crit rules still depend on weapon attacks. Automatic augments do not advance the weapon-fired counter. Dynamic Manifestation and Litany multipliers are read by the native weapon; automatic augment scaling reads the underlying Stats instead. A future description should distinguish those scopes rather than promise that every Haste or Power effect affects every instrument.

The ordinary native shot multiplier caps at **2.5** after runner multipliers, before explicitly defined post-cap windows. Tesla has its separate **0.15s** floor. Low-health Haste combinations can therefore reach a point where another bonus changes the displayed ingredients without increasing actual cadence.

Circuit damage is multiplicative. The complete **Twin Seal Protocol + Choir of Recurrence + The Engine Prays** route, including Circuit Thesis and Canon, gives:

`1.25 × 1.25 × 1.50 × 1.20 × 1.50 = 4.21875`

This applies before the shared Power inside `D`. Choir's −15% Power lowers augment `D` too. The Engine Prays' native-only ×0.75 price does not lower augment `D`. An Open Circuit route instead of Twin Seal supplies a different trade: active cooldowns ×0.6 and +20% Haste, with a 2s cross-lock on other active augments. Free Phantom cuts do not start an additional lock; automatic Slash/Core casts do not count as manual activations.

Sources: [Doctrine families](../../core/systems/major_choice/DoctrineFamilies.gd), [Twin Seal](../../data/major_choices/doctrines/method_twin_seal_protocol.tres), [Choir of Recurrence](../../data/major_choices/doctrines/doctrine_choir_of_recurrence.tres), [The Engine Prays](../../data/major_choices/doctrines/apotheosis_the_engine_prays.tres), and [Open Circuit](../../data/major_choices/doctrines/method_open_circuit.tres).

## Inherited investigation and playtest concerns

These concerns existed before the current augment changes. They are **not regressions introduced by this pass**, and this audit does not change their behavior.

1. **Storm Crown can hit one enemy as both a hop and a primary zap in the same pulse.** The main candidate loop in [TeslaAuraEffect](../../effects/augments/logic/TeslaAuraEffect.gd) does not skip handles already added to the shared `struck` set by a hop. Current simple coverage tests put hop victims outside the primary radius, so they do not settle this overlap. Add a dense-ring case, confirm the intended hit policy, and measure its damage distribution before changing the loop or adding further chain combinations.
2. **Perfect Shield refunds can overlap invulnerability.** The manual activation path in [ReflectShieldEffect](../../effects/augments/logic/ReflectShieldEffect.gd) sets a cooldown floor beyond the parry window, but `_on_perfect_reflect` subsequently reduces cooldown to 0.10s. In a bullet stream, repeated perfect presses may overlap windows; Long Guard widens them. Test sustained projectile pressure and preserve the intended remaining-window gap if the overlap is unintended. Bulwark's one-second healing gate does not itself prevent this Shield overlap.

The current Choir shard correction is separate: retargeting and swept collision now both exclude the parent's victim, and pool recycling clears the exclusion. The focused combat regression covers those paths.

## Prioritized future upgrades — not implemented

### 1. Give House Edge meaningful later ranks

Keep its approved 70% chance and two-Follower payout. Add a bounded rank benefit to the non-Follower part of the Rite, for example Resonance per distinct curse of **2% + 0.1 percentage point per rank above one**, while retaining the **12% segment cap**. That yields **2.2% / 2.4% / 2.9%** at ranks 3/5/10 and reaches the bank sooner without raising the chance or payout ceiling.

This is a starting tuning proposal, not a complete solution through rank 20: the six-curse bank size means some later ranks can still require the same number of discoveries. An alternative or companion is to avoid offering a rank card when it changes no actual payout. Apply the same offer-awareness principle to Sigil and other capped passives.

### 2. Repair missile Facet progression

For **Lance**, derive per-missile damage from a stable aggregate volley budget after the actual integer count is known. A target budget of 110% of the unmodified volley would remove odd-count penalties while retaining fewer, farther-reaching missiles. It needs comparison against Choir and Rods rather than an unconditional larger coefficient.

For **Salvo**, make its extra count or damage trade scale with the capped volley size, or reduce the high-rank penalty. Preserve a meaningful extra-hit specialization without turning Choir/Rods into another broad damage increase. The decision should be evaluated at odd and even counts, before and after Transcendence.

### 3. Make Swarm's cost belong to its extra spiders

One concrete option is for the two extra hatchlings to bite at 70%, while ordinary hatchlings retain normal bites. Keep the current population cap. That preserves a visible smaller-spider trade without weakening every spider the player already established, including Brood Mother hatches.

Before adopting it, define which hatchlings occupy or replace a full cap and compare sustained bite, detonation and replenishment output. The objective is a useful brood-growth choice, not merely a larger population.

## New curse combination proposals — not implemented

These four options fill curse-specific gaps while retaining limits on population, targets and proc frequency. They are design candidates for review, not shipped mechanics.

| Candidate | Trigger and effect | Intended play pattern and boundaries |
|---|---|---|
| **Cinder Vow — Corruption Engine + Litany Duo** | Reaching full Litany strength banks one ember. The next native attack spends it on a secondary **1D** cut against at most two nearby enemies. Rearm only after healing above **60% HP**, with at least **8s** between ember grants. | Deliberately enter danger, then choose when to release a banked attack. Use Litany's actual full-ramp threshold, including Requiem. Spend once per native attack, not once per pellet; the secondary hit cannot recharge itself. |
| **False Providence — Inversion Lens + Gambler's Rite Duo** | A distinct world curse found while Lens suppresses a curse grants one charge for **12s**. The next native attack is a guaranteed lucky crit. One charge; at least **8s** between grants. | Collect a curse, then seek a valuable attack opportunity. The charge is spent on firing, as existing lucky attacks are. Preserve genuine acquisition provenance; trades and inventory moves cannot recharge it. Include Loaded Dice/Fortune in the tuning comparison. |
| **Crucible — Corruption Engine Facet** | Read only the single heaviest active curse, at **×2 severity share**. Keep the existing Power cap. | Concentrate the wardrobe around one severe curse. Smaller curses provide no fuel. Heart of Ruin retains its higher cap but still uses the single intake; Lens can remove its preferred fuel. |
| **Many Mouths — Corruption Engine Facet** | Add two active statistical-slot intakes; severity share **×0.65**. Ordinary Engine reads four curses; Heart of Ruin reads five. Keep existing caps. | Carry several moderate curses and maintain the wardrobe. This measures severity, so it remains different from Doctrine's qualifying count. Including Heart's fifth intake avoids a branch that becomes strictly worse when the augment Transcends. |

A curse Duo occupies two of the three augment slots. Its payoff must be useful with the remaining slot as well as with native weapon attacks. Avoid adding an effect that secretly requires a fourth augment, a permanent invulnerability loop, or an unbounded chain of hit-triggered damage.

## Follow-up validation

No engine was launched for this audit, and none of the proposals has been playtested. The existing focused tests provide implementation evidence, not an overall balance verdict:

- [Facet/Duo effects A](../../tools/tests/FacetDuoEffectsATest.gd) and [effects B](../../tools/tests/FacetDuoEffectsBTest.gd): runtime branches, Duo hooks and non-compounding setup.
- [Augment Transcendence](../../tools/tests/AugmentTranscendenceTest.gd): catalysts and runtime transformations.
- [Combat reliability](../../tools/tests/AugmentCombatReliabilityTest.gd): deterministic payloads, target replacement, lifetime/walls and shard exclusions.
- [Passive rewards](../../tools/tests/PassiveAugmentRewardTest.gd): actual recruitment paths on fixed rolls around payout boundaries.
- [Run Sheet ledger](../../tools/tests/RunSheetLedgerTest.gd): ordinary/transformed readouts, changing health and acquisition totals.

The next balance comparison should cover ranks 3/5/10 against an isolated durable target, a sparse pair and a dense pack, with and without Circuit modifiers. Count delivered hits, targets, proc opportunities and population alongside total damage. That distinguishes an actual new play pattern from a multiplier that merely increases the same output.

Design background: [Bindings and Theses](../design/2026-10-03-bindings-and-theses.md), [Duos, Facets and the Reliquary](../design/2026-10-03-duos-facets-and-the-reliquary.md), and [NEG buildcraft archetypes](../design/NEG_BUILDCRAFT_ARCHETYPES.md).
