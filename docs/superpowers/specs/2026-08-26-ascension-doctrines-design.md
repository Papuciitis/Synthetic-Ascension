# Ascension Doctrines Design

## Problem

The current Segment 5 Major Choice is a single generic card row. Its offer buckets are mostly predetermined, many rewards are flat statistics or inventory capacity, and the choice does not express Syn'Tek's transformation. It resembles an ordinary perk selection rather than a dangerous thesis about how to manufacture divinity.

## Design Goal

Replace the one-off reward with three authored Ascension Doctrine decisions that arrive after Segments 3, 6, and 9. Every card must visibly state a gift, a price, and a lasting consequence; every selected Doctrine must materially alter how the current run plays.

## Progression

- Segment 3 reward: `METHOD` — mortal artificer/researcher becomes an impossible synthetic mage.
- Segment 6 reward: `DOCTRINE` — the build becomes a cultic technological system.
- Segment 9 reward: `APOTHEOSIS` — the system becomes manufactured divinity.
- Each stage presents exactly three authored roles: `AMPLIFY`, `TRANSFIGURE`, and `COVENANT`.
- Offers are generated deterministically from attempt seed plus stage and persisted by ID. There is no reroll by reload.
- Version one ships one authored card per role per stage. This intentionally favors nine strong cards over a large shallow pool. The database still accepts multiple eligible definitions per role and deterministically picks the highest build score, with seeded tie-breaking, so content can expand without UI or save changes.

## Initial Doctrine Set

### METHOD — after Segment 3

1. **Open Circuit** (`AMPLIFY`)
   - Gift: +20% Haste and active augment cooldowns ×0.70.
   - Price: activating an augment locks the other active augments for 2.0 seconds.
   - Consequence: establishes the `circuit` family.
2. **Frame of Ash** (`TRANSFIGURE`)
   - Gift: +30% Power and +15% movement speed.
   - Price: −25% Max HP.
   - Consequence: establishes the `vessel` family.
3. **Black Archive** (`COVENANT`)
   - Gift: +20% Luck and one additional reward roll from each unique secondary objective.
   - Price: Threat gain ×1.25.
   - Consequence: establishes the `archive` family.

### DOCTRINE — after Segment 6

1. **Choir of Recurrence** (`AMPLIFY`)
   - Gift: +2 levels to every equipped augment and +15% Haste.
   - Price: −15% weapon Power.
   - Consequence: `circuit` selections show a resonance bonus in preview but the card remains legal for other builds.
2. **Vessel Without Mercy** (`TRANSFIGURE`)
   - Gift: Wardstone restoration and Exit Rite healing ×1.60.
   - Price: all other healing ×0.50.
   - Consequence: Rite milestone pulses gain +0.10 seconds of stun.
3. **Pilgrim Engine** (`COVENANT`)
   - Gift: safeguard capacity becomes five and every unique exploration source grants one additional charge.
   - Price: Exit Rite hold time ×1.25.
   - Consequence: `archive` selections show an extra-reward synergy in preview.

### APOTHEOSIS — after Segment 9

1. **Perfected Engine** (`AMPLIFY`)
   - Gift: +2 levels to every equipped augment and +35% Power.
   - Price: −30% Max HP.
   - Consequence: all three augment slots are permanently treated as occupied for run-summary identity, even if one is empty.
2. **Law of Admission** (`TRANSFIGURE`)
   - Gift: every Exit Rite starts with its first third sealed.
   - Price: every scripted Rite burst count is multiplied by 1.50 and rounded up.
   - Consequence: the first automatic pulse does not replay at spawn; it is already archived as spent.
3. **Manufactured Witness** (`COVENANT`)
   - Gift: once per segment, lethal player damage consumes 100 Followers, restores 50% Max HP, and grants 2.0 seconds invulnerability.
   - Price: the rescue immediately adds 25 Threat-equivalent carry for that segment.
   - Consequence: the rescue is recorded in the Run Sheet as `WITNESS EXPENDED`.

## Data and Offer Model

`MajorChoiceDef` remains the resource class for compatibility, but gains:

- `stage: StringName` (`method`, `doctrine`, `apotheosis`)
- `offer_role: StringName` (`amplify`, `transfigure`, `covenant`)
- `family_id: StringName`
- `gift_text`, `price_text`, `consequence_text`
- `build_tags: Array[StringName]`
- `base_offer_score: float`

`MajorChoiceContext` snapshots style, equipped augments and levels, set piece counts, prior Doctrine families, and source segment. `MajorChoiceDB.build_stage_offer(context, taken_ids, rng)` returns one eligible definition for each role in fixed display order.

## Runtime and Save State

- `attempt_doctrine_stage_ids: Dictionary` stores stage string to selected ID.
- `attempt_doctrine_rules: Dictionary` stores named numeric/bool rules applied by effects.
- Existing `attempt_major_choice_taken_ids` remains the unique-ID history and existing modifier fields remain readable.
- Legacy saves keep already-applied effects. A non-empty legacy `attempt_major_choice_id` is copied into taken history but does not retroactively schedule missed stages.
- New pending stages are only created when Segments 3, 6, or 9 complete after migration.
- One pending stage is shown in HubShop before Continue. Selecting it clears only that stage's pending offer.

## UI Identity

- Rename visible `Major Choice` copy to `ASCENSION DOCTRINE`.
- Use the shared occult-institutional theme and the game's display/body fonts.
- Cards are ritual thesis plates: square/brutalist geometry, thin ochre rules, seal index, stage and role labels, then distinct `GIFT`, `PRICE`, and `CONSEQUENCE` sections.
- Selection requires two actions: first click focuses and expands the card; `Inscribe Doctrine` confirms. Escape/back clears focus before leaving.
- The screen pauses in the Hub, not combat, and remains keyboard/controller navigable.

## Non-Goals

- Do not add deckbuilding, card rarity, card removal, or combat-time draw mechanics.
- Do not create more than the nine listed Doctrine resources in version one.
- Do not delete legacy `.tres` resources until save migration has shipped and been verified.
- Do not silently reapply effects from a legacy save.

## Acceptance Criteria

- Completing Segments 3, 6, and 9 queues the correct stage exactly once.
- Every stage resolves to exactly one Amplify, Transfigure, and Covenant card in stable order.
- Reloading preserves the same offer and never applies a selection twice.
- All nine cards show non-empty Gift, Price, and Consequence copy and their runtime effects match the values above.
- Legacy saves load without lost effects, crashes, forced missed-stage popups, or duplicated rewards.
- The new screen visually matches the occult-industrial interface rather than the old rounded generic cards.
