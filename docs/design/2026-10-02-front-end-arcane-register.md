# The front-end register (2026-10-02)

The title logo draws itself on when the main menu opens (`title_reveal.png`
plus `title_sheen.gdshader`, built by `build_menu_art.py`). The ring engraves
first, then the words line by line with an ember pen tip, then the blade and
the stars.

The main menu, the Archives (save select), the New Chronicle screen (race,
path and name before a run), Settings, the loading card and the augment pick
were rebuilt toward the user's main-menu mock-up and design sheet
(`incoming/menu/reference_main_menu_mockup.png`,
`incoming/menu/reference_design_sheet.png`) and the inspiration notes that came
with them: an ancient arcane workshop left running, painterly and dark, an
understated menu, warm candle/ember light first, the orange-gold accent used
sparingly, blue magic only as an accent, never sci-fi neon.

Phase 2 brought the in-run screens into the same register:

- **The Exchange (HubShop).** Its helpers are in `ui/widgets/exchange/`: the
  brass Balance scale, the follower counter, the Exchanger portrait, the trade
  flare and the four-column layout. The screen runs standalone over the vigil
  painting, or embedded over the hub with a translucent veil.
- **The Ascension tree.** `ui/shaders/ascension_sky.gdshader` draws the nebula
  sky, and `ascension_nodes.gdshader` draws the instanced nodes. The screen adds
  the astrolabe rings, light flowing through owned edges, an unfurling opening,
  a purchase burst and an arcane side panel. Cores, the equipped loadout and
  anything buyable now are always named; other names give way when crowded and
  show on hover.
  After the opening unfurls, the camera glides in (`AscensionTreeView._start_glide`).
  While nothing is bought it goes to the core at about 1.9×. Once nodes are owned
  it goes to the furthest owned node at about 2.1×, choosing the most important
  kind if several are equally far. The glide never runs once the player has moved
  the view, Fit cancels it, and under reduced motion it cuts straight there.
- **The augment library, the Doctrine choice, Gear & Stash and Game Over.**
  Their helpers are in `ui/widgets/chambers/` (ChamberKit). The Doctrine
  plates are held cards that use `card_tilt`.

Titles use the `ArcaneTitle` FontVariation (Cinzel Decorative with
`spacing_space = 10`), because the face's swashes otherwise fill the word gap.

## Palette

| Role | Colour |
| --- | --- |
| Parchment text | `#E8DCC4` (0.91, 0.86, 0.77) |
| Body text | (0.82, 0.77, 0.68) |
| Gold (rules, icons) | (0.86, 0.64, 0.36); dim (0.62, 0.47, 0.30) |
| Gold bright (focus, headings) | (0.99, 0.84, 0.58) |
| Ink (text on the gold stroke) | (0.13, 0.08, 0.045) |
| Panels | (0.032, 0.028, 0.025) at 0.9 alpha, 1 px gold-dim border, square corners |
| Ember | (1.0, 0.62, 0.30) |
| Arcane accent | (0.42, 0.62, 1.0), used for magic only |
| Danger | (0.86, 0.32, 0.24) |

## Type

All from Google Fonts, SIL OFL, under `assets/fonts/`:

- **Cinzel Decorative** for screen titles (`ArcaneTitle`).
- **Cinzel** (variable, wght 500/600) for menu entries, headings, captions and buttons.
- **EB Garamond** (variable, plus italic) for body text, inputs and flavour.

## Theme

`ui/theme/ArcaneMenuTheme.tres` is the theme for every front-end screen. Its
type variations:

- `ArcaneTitle`, `ArcaneHeading`, `ArcaneCaption`, `ArcaneBody`, `ArcaneItalic` (Labels).
- `ArcaneMenuButton`, used by ArcaneMenuItem.
- `ArcaneSmallButton` and `ArcaneDangerButton` (Buttons).
- `ArcaneKeyButton` and `ArcaneLinkButton` (key bindings, inline links).
- `ArcanePanel` (an unpadded PanelContainer; the plain PanelContainer default is padded).
- `ArchiveCard` (Panel).

Checkboxes are diamonds, slider grabbers are diamonds, and option arrows are a
gold chevron.

`ArcaneMenuTheme` is also the project theme (`gui/theme/custom`), so every
control without a theme of its own takes the arcane look instead of Godot's
default. It gives base looks to:

- Window, AcceptDialog and ConfirmationDialog: a double gold rule, corner
  diamonds, a Cinzel title with a rule, and a gold ×.
- PopupPanel, ItemList, Tree, SpinBox, TextEdit, RichTextLabel, ProgressBar,
  TabContainer/TabBar, separators and scrollbars.

Its default PanelContainer is padded 30/24, so HUD and slot panels need a
panel style of their own.

## Components

- `ui/components/ArcaneMenuItem.gd` (Button). Diamond, caption and rule; when
  selected, the gold brush stroke wipes in, its star flares and sparks fly.
  Focus is the selection, and hovering takes focus. Use `active` together with
  `stroke_on_focus = false` for tabs.
- `ui/components/ArcaneRule.gd`. A fading gold line with a diamond or star.
- `ui/components/ArcaneFrame.gd`. Outer and inner rules, corner diamonds, a
  crown star, an optional pointed arch, and `glow` for hover or held states.
- `ui/components/ArcaneDialog.gd`. The modal used for confirm, rename or erase.
  Focus cannot leave it while it is open.
- `ui/components/ChoiceTile.gd`. A toggle tile: a portrait crop or a drawn
  playstyle sigil (`StyleSigil`: magic, melee or ranged), a name, a line of
  flavour and stat chips. Used for the New Chronicle screen's races and paths.
- `ui/widgets/ArcaneBackdrop.gd`. The living painting, with profiles
  `threshold` (main menu) and `vigil` (Archives), and moods `calm`, `hearth`,
  `arcane`, `archive`, `still`, `dusk` and `synthetic`.
- `ui/widgets/ArcaneParticles.gd`. Embers, dust, arcane motes and selection sparks.

Shaders live in `ui/shaders/`:

- `arcane_backdrop` for the painting.
- `menu_highlight` for the stroke wipe and its sheen.
- `title_sheen` for the logo.
- `card_portrait` for the arched card window.
- `card_tilt` for a real perspective tilt, with glare, glaze sweep and foil.

## Motion rules

- Every animation honours the `accessibility/reduced_motion` setting. Under it,
  camera drift and lean stop, there are no staggers or pops, and particles thin out.
- Screens shown while `Engine.time_scale` is 0 (AugmentSelect) integrate real
  time and use tweens with `set_ignore_time_scale(true)`.
- Selection is always marked by something besides colour: the stroke, the frame
  glow or the diamond.

## Art pipeline

`tools/design/build_menu_art.py` cuts and builds everything in
`assets/ui/menu/` from `incoming/menu/`. The LaMa inpainting and Real-ESRGAN
steps it documents were one-offs. `tools/bake_save_portraits.gd` bakes
`assets/textures/characters/portraits/<race>.png`. Dedicated portrait art can
simply overwrite those files.

## Checking a screen

- `tools/dev/MenuScreenshotProbe.tscn -- --out=<dir>` covers the main menu
  moods, the dev panel, Settings, and the Archives with fixture saves in a
  scratch folder.
- `tools/dev/ScreensShotProbe.tscn -- --out=<dir> [--only=...]` covers the
  augment pick (including the picked moment), the New Chronicle screen
  (`chronicle`), the major choice, the Ascension tree, the Exchange, the
  library, the loading card (`scrim`) and the remaining in-run screens (`misc`).
- `tools/dev/ExchangeShotProbe.tscn`, `tools/dev/AscensionShotProbe.tscn` and
  `tools/dev/ChambersShotProbe.tscn` give deeper fixtures for each of those
  areas.
- Both need a display (`DISPLAY=:0`), not `--headless`. The window comes out
  1784 x 1004.
- `tools/tests/FrontEndFlowTest.gd` (`-s`) covers the intents, card clicks,
  Erase confirmation, tab state and backdrop moods.
