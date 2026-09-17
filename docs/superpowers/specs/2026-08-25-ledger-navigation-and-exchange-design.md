# Ledger Navigation and Exchange Identity Design

## Purpose

Replace the current long Run Sheet and generic rectangular notification/shop
surfaces with one coherent occult-institutional interface language. The result
must feel like an archive and ritual apparatus built by an institution that
studies divinity, not like a desktop dashboard with a different font.

This design extends
`docs/superpowers/specs/2026-08-25-occult-institutional-ui.md`; it corrects the
parts of that pass which changed typography without changing enough of the
underlying construction.

## Visual principles

- Typography supplies hierarchy, but structure supplies identity.
- Use dark physical surfaces, thin bronze rules, inset classifications,
  geometric seals, and restrained sacred accents.
- Avoid large collections of identical closed rectangles. Prefer open ledger
  regions separated by rules and one deliberately emphasized ritual module.
- Corners remain nearly square: 0-3 px radius.
- IBM Plex Sans Condensed carries mechanical text, Alegreya SC carries
  institutional headings, and Marcellus SC is reserved for rites,
  manifestations, concordances, and major ritual actions.
- No neon, holographic glass, futuristic computer framing, or cyber-terminal
  motifs.

## Run Sheet: fixed archive with a side index

### Construction

The Run Sheet becomes a fixed-height archive rather than one vertical document.
It remains attached beneath the top-left HUD while management mode is open.

- The content panel is approximately the width of the top-left HUD.
- A narrow vertical index projects from its right side.
- The index contains four focusable buttons in this order:
  `PROFILE`, `SETS`, `MANIFESTATIONS`, `OBSERVATIONS`.
- The selected tab uses a bronze edge, a small diamond marker, and stronger
  heading colour. Unselected tabs stay legible but visually recess.
- Only one page is visible at a time.
- Each page owns a bounded `ScrollContainer`; the overall panel never grows
  beyond the available viewport height.
- The selected tab survives refreshes and remains stable for the duration of
  the management session.

### Pages

`PROFILE` contains HP, armour, speed, power, haste, and luck totals and item
deltas. It is the default page when no prior selection exists.

`SETS` contains only equipped set names and real piece progress. It must not
show empty Manifestation or Observation sections.

`MANIFESTATIONS` contains noun counts, meters, equipped Manifestation rules,
and active pair protocols. Long rules may use a bounded two-line summary with
the complete text available from the focused/hovered record.

`OBSERVATIONS` contains discovered archetypes. Every visible row contains the
name and actionable counter. The complete quote, role, behaviour, expectation,
and counter remain available through a focusable record tooltip/detail state.

### Refresh and performance behaviour

- Opening the management layer performs an initial refresh.
- Static pages rebuild only when their input signature changes: inventory/set
  state, Manifestation state, or discovered enemy IDs respectively.
- The active `PROFILE` values may update periodically, but hidden pages are not
  destroyed and recreated at 10 Hz.
- Pointer or keyboard focus must never be invalidated by a background rebuild.
- Changing tabs performs no world mutation and does not release management
  pause ownership.

## Follower feedback: witness account

Follower feedback becomes a compact archive notice using the same construction
as encounter records.

- The surface is angular and uses the shared interface theme.
- A small seal/delta cell sits at the left.
- The eyebrow reads `WITNESS ACCOUNT // PATTERN FEED`.
- The primary line shows the signed amount and singular/plural follower noun.
- The explanatory sentence is a separate body line.
- Positive, negative, trade, and victory meanings retain their current copy and
  aggregation behaviour.
- The notice remains non-blocking, ignores pointer input, and retracts after the
  existing display duration.

The notice must not use the old rounded card with one large multiline label.

## Exchange Hub: ritual ledger

The Exchange keeps all current inventory, cart, filter, undo, tooltip, and save
behaviour. Node paths consumed by `HubShop.gd` remain stable unless the script is
updated in the same change.

### Hierarchy

- The top banner gains an institutional classification line and a restrained
  geometric seal/rule treatment.
- `Aftermath` becomes a route/account ledger rather than an isolated generic
  panel.
- Gear, Backpack, and Trader Stock become open register regions divided by
  bronze rules and inset headers.
- `Balance the Exchange` is the single emphasized ritual module. It uses the
  sacred heading register and stronger containment geometry.
- Buttons, filters, search, and confirmation controls use shared institutional
  button/input styles rather than default Godot controls.
- Empty register space carries a faint grid and small archive marks so it reads
  as reserved capacity, not unfinished black space.

### Responsive behaviour

- The existing five functional regions remain usable at 1920x1080.
- At narrower widths, inventory regions may compress before the central rite or
  action controls become unreadable.
- No critical label or confirmation control may be clipped at 1280x720.

## Shared theme additions

The shared theme may add focused variations with one responsibility each:

- `LedgerPanel`: low-fill open register surface with bronze top/left rules.
- `RitualPanel`: emphasized containment surface for the Exchange rite.
- `SideIndexButton`: compact vertical archive navigation.
- `InstitutionalLineEdit` and `InstitutionalCheckBox`: non-default controls
  matching existing institutional buttons.
- `WitnessNotice`: compact notification surface.

These variations must reuse the existing palette and fonts rather than create a
second visual system.

## Accessibility and interaction

- Side tabs participate in keyboard/controller focus navigation.
- Active tab state is communicated through more than colour.
- Observation counters remain visible without hover.
- Full records remain accessible through focus as well as pointer hover.
- Font sizes must remain readable at the project reference resolution and obey
  existing interface-scale settings.

## Verification

- An automated Run Sheet test proves fixed bounds, exclusive page visibility,
  tab focusability, visible observation counters, and signature-based caching.
- A follower feedback test proves shared styling and separated eyebrow/value/body
  fields without changing aggregation semantics.
- An Exchange consistency test proves shared theme use, ledger/ritual panel
  variations, institutional controls, and preserved critical node paths.
- Visual captures cover every Run Sheet tab, follower feedback, and the Exchange
  at 1920x1080 and 1280x720.
- Existing management pause, Manifestation, inventory, save, and Exchange tests
  continue to pass.

## Out of scope

- Rewriting Exchange economics or inventory behavior.
- A new full-screen codex.
- New illustrative art assets.
- Combat-performance tuning, which is specified separately.
