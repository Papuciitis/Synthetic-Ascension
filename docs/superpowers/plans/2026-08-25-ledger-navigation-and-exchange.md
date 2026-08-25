# Ledger Navigation and Exchange Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the oversized Run Sheet, rounded follower toast, and generic Exchange panels with a bounded occult-institutional ledger interface while preserving every existing gameplay interaction.

**Architecture:** Keep the current HUD, inventory, and Exchange controllers as behavior owners. Restructure the Run Sheet into four cached pages selected by a side index, rebuild each static page only when its data signature changes, and express the follower notice and Exchange hierarchy through shared theme variations rather than local card styles. Add scene-level contract tests before changing each surface, then capture both reference resolutions.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, `.tres` Theme resources, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-08-25-ledger-navigation-and-exchange-design.md`

## Global Constraints

- IBM Plex Sans Condensed carries mechanical text, Alegreya SC carries institutional headings, and Marcellus SC is reserved for rites, manifestations, concordances, and major ritual actions.
- Corners remain nearly square: 0-3 px radius.
- No neon, holographic glass, futuristic computer framing, cyber-terminal motifs, or rounded consumer-electronics styling.
- The Run Sheet index order is exactly `PROFILE`, `SETS`, `MANIFESTATIONS`, `OBSERVATIONS`.
- Only one Run Sheet page is visible at a time, and the overall panel never grows beyond the available viewport height.
- Existing follower copy, aggregation, display duration, pointer passthrough, Exchange economics, inventory behavior, cart behavior, filters, undo, tooltips, and save behavior remain unchanged.
- Existing `HubShop.gd` node paths remain valid.
- No new illustrative art assets or full-screen codex are introduced.
- Preserve unrelated user changes and keep `.superpowers/` and performance captures out of feature commits.

---

## File Structure

- `ui/theme/SyntheticHudTheme.tres`: owns the five new shared visual variations and their focus/pressed states.
- `ui/widgets/RunSheetHUD.tscn`: owns fixed archive bounds, four scroll pages, and the projecting side index.
- `ui/widgets/RunSheetHUD.gd`: owns page selection, per-page signatures, page rebuilds, and stable focus/selection.
- `ui/controllers/FollowerFeedbackUI.gd`: keeps transaction aggregation but builds a three-field witness notice.
- `ui/screens/HubShop.tscn`: keeps functional node paths while applying ledger and ritual hierarchy.
- `ui/screens/HubShopBackdrop.gd`: draws faint register grids and archive marks behind open Exchange regions.
- `tools/tests/RunSheetArchiveTest.gd` and `.tscn`: deterministic Run Sheet layout, navigation, accessibility, and cache contract.
- `tools/tests/FollowerFeedbackPresentationTest.gd`: deterministic notice structure, theme, copy, and aggregation contract.
- `tools/tests/ExchangeIdentityTest.gd`: theme, node-path, control-style, and 1280x720 layout contract.
- `tools/tests/UiConsistencyVisualProbe.gd`: capture entry points for the redesigned surfaces.

### Task 1: Shared Ledger Theme Primitives

**Files:**
- Modify: `ui/theme/SyntheticHudTheme.tres`
- Modify: `tools/tests/InterfaceThemeConsistencyTest.gd`

**Interfaces:**
- Consumes: existing palette, fonts, `InstitutionalPanel`, `ArchiveCard`, and `InstitutionalButton` variations.
- Produces: `LedgerPanel`, `RitualPanel`, `SideIndexButton`, `InstitutionalLineEdit`, `InstitutionalCheckBox`, and `WitnessNotice` theme variations.

- [ ] **Step 1: Add failing theme-contract assertions**

Add these checks after the existing shared-style assertions:

```gdscript
var ledger := theme.get_stylebox(&"panel", &"LedgerPanel") as StyleBoxFlat
var ritual := theme.get_stylebox(&"panel", &"RitualPanel") as StyleBoxFlat
var witness := theme.get_stylebox(&"panel", &"WitnessNotice") as StyleBoxFlat
var side_normal := theme.get_stylebox(&"normal", &"SideIndexButton") as StyleBoxFlat
var side_pressed := theme.get_stylebox(&"pressed", &"SideIndexButton") as StyleBoxFlat
_check(_is_angular(ledger) and ledger.border_width_top >= 1, "ledger surfaces use an open bronze rule")
_check(_is_angular(ritual) and ritual.border_width_left >= 2, "the rite is the stronger contained surface")
_check(_is_angular(witness), "witness notices use the angular shared surface")
_check(_is_angular(side_normal) and side_pressed.border_width_left > side_normal.border_width_left, "side-index selection adds a structural marker")
_check(theme.has_stylebox(&"normal", &"InstitutionalLineEdit"), "Exchange search uses the institutional input")
_check(theme.has_stylebox(&"normal", &"InstitutionalCheckBox"), "Exchange toggles use the institutional checkbox")
```

- [ ] **Step 2: Run the test and confirm the new contract fails**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
```

Expected: non-zero exit with failures naming the six missing variations.

- [ ] **Step 3: Add the shared variations**

Define angular `StyleBoxFlat` resources using the existing charcoal and bronze palette, then register the exact base types:

```text
LedgerPanel/base_type = &"PanelContainer"
RitualPanel/base_type = &"PanelContainer"
SideIndexButton/base_type = &"Button"
InstitutionalLineEdit/base_type = &"LineEdit"
InstitutionalCheckBox/base_type = &"CheckBox"
WitnessNotice/base_type = &"PanelContainer"
```

Use `corner_radius_* = 0` for ledger/input surfaces and `corner_radius_* = 2` for the emphasized rite and witness notice. Give `SideIndexButton/styles/pressed` a 3 px left bronze edge, a visibly stronger fill, and the same focus style as hover. Reuse `ExtResource("1_body")`, `ExtResource("2_body_strong")`, `ExtResource("3_institutional")`, and `ExtResource("4_sacred")`; do not add fonts or colors outside the existing warm palette.

- [ ] **Step 4: Run the theme contract**

Run the command from Step 2. Expected: exit 0 and zero failed assertions.

- [ ] **Step 5: Commit only the shared primitive change**

```powershell
git add -- ui/theme/SyntheticHudTheme.tres tools/tests/InterfaceThemeConsistencyTest.gd
git commit -m "feat: add ritual ledger theme primitives"
```

### Task 2: Bounded Run Sheet with Side Index

**Files:**
- Create: `tools/tests/RunSheetArchiveTest.gd`
- Create: `tools/tests/RunSheetArchiveTest.tscn`
- Modify: `ui/widgets/RunSheetHUD.tscn`
- Modify: `ui/widgets/RunSheetHUD.gd`
- Modify: `tools/tests/HudContextPresentationTest.gd`

**Interfaces:**
- Consumes: `refresh(player: Node, inv: Inventory) -> void`, `Global.discovered_enemy_ids`, `EnemyDossierCatalog.get_entry(id)`, inventory set counts, and `ManifestationRunner` summaries/meters/pairs.
- Produces: `enum ArchivePage { PROFILE, SETS, MANIFESTATIONS, OBSERVATIONS }`, `select_page(page: ArchivePage) -> void`, `selected_page() -> ArchivePage`, and `debug_rebuild_counts() -> Dictionary` with keys `sets`, `manifestations`, and `observations`.

- [ ] **Step 1: Create the failing archive test scene**

Create a `Control` root containing an instance of `res://ui/widgets/RunSheetHUD.tscn`, with a fixture player and fixture `ManifestationRunner`. The test must assert:

```gdscript
_check(run_sheet.size.y <= 540.0, "Run Sheet remains bounded")
_check(run_sheet.get_node("Archive/Index/Profile").focus_mode == Control.FOCUS_ALL, "side tabs accept focus")
for page_name in ["Profile", "Sets", "Manifestations", "Observations"]:
	var button := run_sheet.get_node("Archive/Index/" + page_name) as Button
	button.emit_signal("pressed")
	await get_tree().process_frame
	_check(_visible_page_count(run_sheet) == 1, "only %s page is visible" % page_name)
_check("COUNTER  //" in _collect_label_text(run_sheet.get_node("Archive/Pages/ObservationsScroll")), "observation counters are visible without hover")
var before := run_sheet.debug_rebuild_counts()
run_sheet.refresh(player, inventory)
run_sheet.refresh(player, inventory)
var after := run_sheet.debug_rebuild_counts()
_check(before == after, "unchanged static pages are not rebuilt")
```

Also select `OBSERVATIONS`, focus its first record, refresh unchanged data, and assert both `selected_page()` and `get_viewport().gui_get_focus_owner()` remain unchanged.

- [ ] **Step 2: Run the archive test and verify it fails on missing side-index paths**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RunSheetArchiveTest.tscn
```

Expected: non-zero exit because `Archive/Index/Profile` and the page API do not exist.

- [ ] **Step 3: Restructure the scene without changing the public refresh call**

Replace the single `Margin/VBox` document with this stable hierarchy:

```text
RunSheetHUD (PanelContainer, LedgerPanel, max visual height 540)
└─ Archive (HBoxContainer)
   ├─ BodyMargin (MarginContainer)
   │  └─ Pages (Control)
   │     ├─ ProfileScroll/Content/StatsGrid
   │     ├─ SetsScroll/SetsVBox
   │     ├─ ManifestationsScroll/ManifestationsVBox
   │     └─ ObservationsScroll/ObservationsVBox
   └─ Index (VBoxContainer)
      ├─ Profile (Button)
      ├─ Sets (Button)
      ├─ Manifestations (Button)
      └─ Observations (Button)
```

Set every scroll page to full-rect anchors, `horizontal_scroll_mode = 0`, and bounded vertical scrolling. Give all four buttons `focus_mode = 2`, `toggle_mode = true`, and `theme_type_variation = &"SideIndexButton"`. Preserve the existing stat label names under `ProfileScroll/Content/StatsGrid` so the controller can bind them explicitly.

- [ ] **Step 4: Implement selection and signature caching**

Use explicit page arrays and rebuild counters:

```gdscript
enum ArchivePage { PROFILE, SETS, MANIFESTATIONS, OBSERVATIONS }

var _selected_page: ArchivePage = ArchivePage.PROFILE
var _page_signatures := {
	ArchivePage.SETS: "__UNINITIALIZED__",
	ArchivePage.MANIFESTATIONS: "__UNINITIALIZED__",
	ArchivePage.OBSERVATIONS: "__UNINITIALIZED__",
}
var _rebuild_counts := {"sets": 0, "manifestations": 0, "observations": 0}

func select_page(page: ArchivePage) -> void:
	_selected_page = page
	for index in range(_page_controls.size()):
		_page_controls[index].visible = index == page
		_page_buttons[index].button_pressed = index == page
		_page_buttons[index].text = ("◆  " if index == page else "◇  ") + PAGE_LABELS[index]

func selected_page() -> ArchivePage:
	return _selected_page

func debug_rebuild_counts() -> Dictionary:
	return _rebuild_counts.duplicate()
```

Split the existing destructive body into `_refresh_profile`, `_refresh_sets`, `_refresh_manifestations`, and `_refresh_observations`. Compute stable signatures from sorted set IDs/counts, Manifestation summary dictionaries plus meters/pairs, and sorted discovered enemy IDs. Increment the corresponding rebuild counter only after a changed signature is accepted. Remove `_pointer_is_reading()` because unchanged refreshes no longer free focused controls.

- [ ] **Step 5: Preserve accessible details and compact visible rows**

Keep observation `COUNTER  //  ...` labels visible and focusable record tooltips containing quote, role, behaviour, expectation, and counter. Keep Manifestation rules at two visible lines with complete `ManifestationInfoBox.setup(name, nouns, rule, accent)` details available through pointer and focus. Give Manifestation pair names `SacredHeading` and all page headings `InstitutionalHeading` except ritual protocol names.

- [ ] **Step 6: Update the existing HUD test to use tab selection**

Before checking pair text, call:

```gdscript
_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
var manifestation_text := _collect_label_text(_run_sheet)
_check("Litany Engine" in manifestation_text, "the Manifestations page exposes the active pair")
_run_sheet.select_page(RunSheetHUD.ArchivePage.OBSERVATIONS)
var observation_text := _collect_label_text(_run_sheet)
_check("CONTAINMENT OFFICER" in observation_text and "Keep moving" in observation_text, "the Observations page keeps its actionable counter visible")
```

- [ ] **Step 7: Run focused Run Sheet regressions**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RunSheetArchiveTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
```

Expected: all three commands exit 0; management pause ownership is unchanged.

- [ ] **Step 8: Commit the bounded archive**

```powershell
git add -- ui/widgets/RunSheetHUD.gd ui/widgets/RunSheetHUD.tscn tools/tests/RunSheetArchiveTest.gd tools/tests/RunSheetArchiveTest.tscn tools/tests/HudContextPresentationTest.gd
git commit -m "feat: split run sheet into cached ledger tabs"
```

### Task 3: Witness Account Follower Notice

**Files:**
- Create: `tools/tests/FollowerFeedbackPresentationTest.gd`
- Modify: `ui/controllers/FollowerFeedbackUI.gd`

**Interfaces:**
- Consumes: `Global.followers_transaction`, `_on_transaction(old, change, new, reason, context, show_feedback, allow_aggregate)`, the current 0.9 second aggregation window, and 3.6 second visibility window.
- Produces: children `FollowerFeedback/Margin/Row/Seal`, `Copy/Eyebrow`, `Copy/Value`, and `Copy/Body`, with `WitnessNotice`, `InstitutionalHeading`, and `BodyStrong` variations.

- [ ] **Step 1: Write the failing follower presentation test**

Instantiate the script as a `CanvasLayer`, call `_on_transaction(10, 2, 12, &"combat_influence", {}, true, true)`, advance `_process(0.91)`, and assert:

```gdscript
var panel := feedback.get_node("FollowerFeedback") as PanelContainer
var eyebrow := feedback.get_node("FollowerFeedback/Margin/Row/Copy/Eyebrow") as Label
var value := feedback.get_node("FollowerFeedback/Margin/Row/Copy/Value") as Label
var body := feedback.get_node("FollowerFeedback/Margin/Row/Copy/Body") as Label
_check(panel.theme_type_variation == &"WitnessNotice", "notice uses the shared witness surface")
_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "notice remains non-blocking")
_check(eyebrow.text == "WITNESS ACCOUNT // PATTERN FEED", "notice carries the archive classification")
_check(value.text == "+2 FOLLOWERS", "aggregated gain has a separate signed value")
_check("containment line breaks" in body.text, "existing combat copy is preserved")
feedback.call("_process", 3.61)
_check(not panel.visible, "notice retracts after the existing duration")
```

Repeat with `change = -1`, `reason = &"trade"`, and assert `-1 FOLLOWER` plus the existing trade sentence.

- [ ] **Step 2: Run the follower test and verify the old one-label card fails**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/FollowerFeedbackPresentationTest.gd
```

Expected: non-zero exit because the named field nodes and `WitnessNotice` variation are absent.

- [ ] **Step 3: Separate transaction data from presentation fields**

Replace `_format_feed() -> String` with:

```gdscript
func _format_feed(body: String, change: int) -> Dictionary:
	return {
		"value": "%+d %s" % [change, "FOLLOWER" if absi(change) == 1 else "FOLLOWERS"],
		"body": body,
	}

func _show(feed: Dictionary) -> void:
	_value.text = String(feed.get("value", ""))
	_body.text = String(feed.get("body", ""))
	_panel.visible = true
	_visible_left = 3.6
```

Keep every reason-to-sentence mapping and `_pending_gain` behavior byte-for-byte except for passing the resulting dictionary to `_show`.

- [ ] **Step 4: Build the angular three-level notice**

In `_build_ui`, assign the project theme, set `_panel.theme_type_variation = &"WitnessNotice"`, add a narrow bronze seal/delta cell at the left, and create the exact named eyebrow/value/body labels. Keep bottom-right anchoring, pointer ignore, layer 180, always processing, and the existing footprint no wider than 460 px.

- [ ] **Step 5: Run follower and parse tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/FollowerFeedbackPresentationTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit the witness notice**

```powershell
git add -- ui/controllers/FollowerFeedbackUI.gd tools/tests/FollowerFeedbackPresentationTest.gd
git commit -m "feat: restyle follower feedback as witness account"
```

### Task 4: Exchange Ritual Ledger

**Files:**
- Create: `tools/tests/ExchangeIdentityTest.gd`
- Modify: `ui/screens/HubShop.tscn`
- Modify: `ui/screens/HubShopBackdrop.gd`
- Modify only if a node path must move: `ui/screens/HubShop.gd`

**Interfaces:**
- Consumes: every `HubShop.gd` `$Root/HBox/...` path listed at lines 3-38, `ConfirmSell`, `Tooltip`, `FlyVfx`, current signals, and current responsive root anchors.
- Produces: shared-theme Exchange root, `LedgerPanel` variations on `Left`, `Equipped`, `Backpack`, and `Vendor`; `RitualPanel` on `CartPanel`; institutional button/input/checkbox variations; classification and geometric rule nodes above the existing banner.

- [ ] **Step 1: Write the failing Exchange identity test**

Instantiate `HubShop.tscn` without calling economy actions. Assert every critical path exists, then assert:

```gdscript
_check(shop.theme != null and "SyntheticHudTheme" in shop.theme.resource_path, "Exchange uses the shared theme")
for path in ["Root/HBox/Left", "Root/HBox/Equipped", "Root/HBox/Backpack", "Root/HBox/Vendor"]:
	_check((shop.get_node(path) as PanelContainer).theme_type_variation == &"LedgerPanel", path + " is an open register")
_check((shop.get_node("Root/HBox/CartPanel") as PanelContainer).theme_type_variation == &"RitualPanel", "Balance the Exchange is the sole emphasized rite")
_check((shop.get_node("Root/HBox/Vendor/Margin/VBox/VendorTools/Search") as LineEdit).theme_type_variation == &"InstitutionalLineEdit", "stock search matches the ledger")
_check((shop.get_node("Root/HBox/CartPanel/Margin/VBox/TradeTools/IncludeEquipped") as CheckBox).theme_type_variation == &"InstitutionalCheckBox", "trade checkbox matches the ledger")
```

Set the root viewport to `Vector2i(1280, 720)`, await two process frames, and assert `BtnBarter`, `Continue`, `Search`, and `VendorGrid` have non-empty visible rects fully inside the viewport.

- [ ] **Step 2: Run the Exchange test and verify it fails on local panel styles**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/ExchangeIdentityTest.gd
```

Expected: non-zero exit for missing shared theme variations on the scene nodes.

- [ ] **Step 3: Migrate panels and controls while preserving paths**

Add `SyntheticHudTheme.tres` as an external resource and assign it at `HubShop`. Delete `sb_panel` and `sb_panel_accent`. Apply `LedgerPanel` to the four register nodes and `RitualPanel` only to `CartPanel`. Apply `InstitutionalHeading` to route/register headings, `SacredHeading` to `ExchangeBanner` and `CartTitle`, `InstitutionalButton` to actions and filters, `InstitutionalLineEdit` to `Search`, and `InstitutionalCheckBox` to `IncludeEquipped`.

Keep these node paths unchanged:

```text
Root/HBox/Left/Margin/VBox
Root/HBox/Equipped/Margin/VBox/InventoryBar
Root/HBox/Backpack/Margin/VBox/BagGrid
Root/HBox/CartPanel/Margin/VBox/Grids/OfferBox/OfferGrid
Root/HBox/CartPanel/Margin/VBox/Grids/DemandBox/DemandGrid
Root/HBox/Vendor/Margin/VBox/VendorGrid
ConfirmSell
Tooltip
FlyVfx
```

- [ ] **Step 4: Add classification, rules, and reserved-capacity marks**

Add non-interactive banner children reading `RECONSTRUCTION EXCHANGE // AFTERMATH REGISTER` and `LEDGER AUTHORITY 03`, plus thin bronze rules and a small diamond seal. Extend `HubShopBackdrop._draw()` with a low-alpha 32 px grid clipped to the root register area and four small corner/diamond archive marks. Use alpha at or below `0.08` so item icons and text remain dominant.

- [ ] **Step 5: Make 1280x720 compression explicit**

Set minimum widths to `Left 170`, `Equipped 112`, `Backpack 176`, `CartPanel 330`, and `Vendor 218`; reduce `HBox` separation to 5 at the scene level. Keep the rite controls at minimum height 30 and allow inventory registers to receive horizontal compression first. The four critical controls from Step 1 must remain unclipped.

- [ ] **Step 6: Run Exchange and behavior regressions**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/ExchangeIdentityTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/SaveIntegrityTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManifestationSystemTest.tscn
```

Expected: all commands exit 0; no Exchange node lookup errors appear.

- [ ] **Step 7: Commit the Exchange identity pass**

```powershell
git add -- ui/screens/HubShop.tscn ui/screens/HubShopBackdrop.gd ui/screens/HubShop.gd tools/tests/ExchangeIdentityTest.gd
git commit -m "feat: rebuild exchange as ritual ledger"
```

### Task 5: Visual Capture and Full UI Regression

**Files:**
- Modify: `tools/tests/UiConsistencyVisualProbe.gd`
- Capture: `performance_results/2026-08-25/ledger-ui/*.png`
- Modify feature files only when a capture demonstrates a concrete defect.

**Interfaces:**
- Consumes: completed Tasks 1-4 and environment variable `UI_CONSISTENCY_SHOT_DIR`.
- Produces: captures for four Run Sheet pages, follower notice, and Exchange at 1920x1080 and 1280x720.

- [ ] **Step 1: Add deterministic visual states**

Extend the existing probe to call `select_page()` for each archive page, trigger one aggregated positive follower transaction, and instantiate the Exchange with seeded inventory. Save filenames containing the surface and resolution, for example `run-sheet-observations-1920x1080.png` and `exchange-1280x720.png`.

- [ ] **Step 2: Run parse and focused UI suites**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RunSheetArchiveTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/FollowerFeedbackPresentationTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/ExchangeIdentityTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
```

Expected: every command exits 0 with zero failed assertions.

- [ ] **Step 3: Capture and inspect both resolutions**

Run the visual probe once at 1920x1080 and once at 1280x720. Inspect that the Run Sheet never extends offscreen, active tabs show both a diamond and structural edge, observations retain visible counters, the follower notice is subordinate to combat, Exchange controls remain legible, and only the central rite reads as a contained card.

- [ ] **Step 4: Review scope and commit probe updates**

Confirm the diff contains no Exchange economy changes, no new art, no changes to follower timing/copy semantics, and no unrelated files. Commit only the probe and any directly demonstrated corrections:

```powershell
git add -- tools/tests/UiConsistencyVisualProbe.gd ui/theme/SyntheticHudTheme.tres ui/widgets/RunSheetHUD.gd ui/widgets/RunSheetHUD.tscn ui/controllers/FollowerFeedbackUI.gd ui/screens/HubShop.tscn ui/screens/HubShopBackdrop.gd
git commit -m "test: verify ritual ledger interface states"
```
