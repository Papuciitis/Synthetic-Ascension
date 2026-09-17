# Occult-Institutional UI Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove competing objective text, replace blocking enemy dossiers with tethered recognition beats, and unify the pictured HUD/menu surfaces around one occult-institutional visual system.

**Architecture:** Keep gameplay state ownership in its emitters: procedural objectives clear the ordinary objective channel when the Exit Rite checklist takes over. Split enemy discovery presentation from blocking tutorial cards by adding a dedicated always-processing overlay that owns its short freeze, target tether, and auto-dismiss lifecycle. Extend the existing shared HUD theme with reusable interface variations and apply those variations plus clearer management layering to the pictured surfaces.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` scenes, `.tres` Theme resources, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-08-25-occult-institutional-ui.md`

## Global Constraints

- IBM Plex Sans Condensed is body copy, Alegreya SC is institutional copy, and Marcellus SC is sacred copy.
- No neon, holographic, hacker, or rounded consumer-electronics styling.
- The first encounter freeze is 0.8 seconds, restores prior pause ownership, and has no Continue button.
- Full enemy dossiers remain readable in the Run Sheet.
- Existing user changes and the untracked `.superpowers/` folder are preserved.

---

### Task 1: Exit Rite Objective Ownership

**Files:**
- Modify: `core/systems/world/SegmentProcBuilder.gd:516-567`
- Modify: `tools/tests/HudContextPresentationTest.gd`

**Interfaces:**
- Consumes: `RunEvents.objective_changed(title: String, detail: String)` and `RunEvents.gate_checklist_changed(state: StringName, items: Array, next_hint: String)`.
- Produces: post-primary procedural state emits `objective_changed("", "")` and sends all gate state through `gate_checklist_changed`.

- [ ] **Step 1: Write the failing ownership test**

Add a source-level regression assertion that the completed branch clears the ordinary objective signal before emitting the checklist, and a controller assertion that an empty objective hides its panel while the checklist remains visible.

```gdscript
_objective_controller.call("_on_objective_changed", "", "")
_gate_controller.call("_on_gate_checklist_changed", &"ready", checklist_items, "Follow the marker.")
_check(not _objective_panel.visible and _gate_panel.visible, "the Exit Rite checklist solely owns post-primary guidance")
```

- [ ] **Step 2: Run the test and verify the new assertion fails**

Run:

```powershell
& $godot --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
```

Expected: non-zero exit because the procedural completed branch still emits `EXIT RITE` through `objective_changed`.

- [ ] **Step 3: Implement emitter ownership**

Replace the post-primary ordinary objective emit in `SegmentProcBuilder._push_objective_ui()` with:

```gdscript
RunEvents.objective_changed.emit("", "")
_emit_gate_checklist(gate_state, items, guidance)
```

- [ ] **Step 4: Run the HUD test and verify it passes**

Run the command from Step 2. Expected: exit 0 with zero failed assertions.

### Task 2: Tethered First-Encounter Recognition Beat

**Files:**
- Create: `ui/overlays/FirstEncounterOverlay.gd`
- Create: `ui/overlays/FirstEncounterOverlay.tscn`
- Create: `tools/tests/FirstEncounterPresentationTest.gd`
- Modify: `ui/controllers/TutorialModalController.gd`
- Modify: `ui/widgets/RunSheetHUD.gd`
- Modify: `ui/widgets/RunSheetHUD.tscn`
- Modify: `tools/tests/TutorialTypewriterTest.gd`

**Interfaces:**
- Consumes: `present(entry: Dictionary, target: Node2D, texture: Texture2D, ratings: String)` and `Global.discovered_enemy_ids`.
- Produces: `signal dismissed`, `is_freeze_active() -> bool`, and Run Sheet observation rows generated from `EnemyDossierCatalog.DATA`.

- [ ] **Step 1: Write the failing overlay lifecycle test**

Test that the new scene loads, pauses an initially running tree, contains no Continue button, resumes after `0.8` seconds of always-processing time, preserves an initially paused tree, follows/clamps a target endpoint, and emits `dismissed` after its display interval.

```gdscript
overlay.present(entry, target, null, "Health: Low - Threat: Basic")
_check(get_tree().paused, "recognition beat acquires a short freeze")
overlay.call("_process", 0.81)
_check(not get_tree().paused, "recognition beat automatically resumes play")
```

- [ ] **Step 2: Run the new test and verify it fails because the overlay does not exist**

Run:

```powershell
& $godot --headless --path . --script res://tools/tests/FirstEncounterPresentationTest.gd
```

Expected: non-zero exit with a missing-resource or missing-interface failure.

- [ ] **Step 3: Build the minimal overlay scene and lifecycle**

Create an always-processing `CanvasLayer` with a full-rect drawing control and a compact panel. Implement constants `FREEZE_SECONDS := 0.8`, `VISIBLE_SECONDS := 5.8`, pause ownership, viewport-clamped card placement, target screen projection, tether drawing, and automatic dismissal.

- [ ] **Step 4: Route enemy cards through the new overlay**

Add `FIRST_ENCOUNTER_SCENE` to `TutorialModalController`. Enemy queue entries retain their target node and tactical fields. In `_drain_queue()`, enemy entries instantiate the recognition overlay without emitting `tutorial_modal_state_changed`; blocking records retain `TutorialCardOverlay` and the old pause/Continue lifecycle.

- [ ] **Step 5: Add archived observations to the Run Sheet**

Add an `OBSERVATIONS` section. For every ID in `Global.discovered_enemy_ids`, show the catalog name and counter in the panel, with quote, role, behaviour, expectation, and counter in the row tooltip. Empty archives remain hidden.

- [ ] **Step 6: Run encounter and tutorial regression tests**

Run:

```powershell
& $godot --headless --path . --script res://tools/tests/FirstEncounterPresentationTest.gd
& $godot --headless --path . --script res://tools/tests/TutorialTypewriterTest.gd
```

Expected: both exit 0; blocking tutorial typewriter behavior remains intact and enemy recognition is non-modal after its automatic freeze.

### Task 3: Shared Interface Theme and Management Clarity

**Files:**
- Modify: `ui/theme/SyntheticHudTheme.tres`
- Modify: `ui/screens/HUD.tscn`
- Modify: `ui/controllers/HudBagController.gd`
- Modify: `ui/components/BagUI.tscn`
- Modify: `ui/widgets/RunSheetHUD.tscn`
- Modify: `ui/screens/TutorialCardOverlay.gd`
- Modify: `ui/screens/MainMenu.tscn`
- Modify: `ui/screens/SaveSelect.tscn`
- Modify: `ui/components/SaveCard.tscn`
- Modify: `tools/tests/HudContextPresentationTest.gd`
- Create: `tools/tests/InterfaceThemeConsistencyTest.gd`

**Interfaces:**
- Consumes: shared `Theme` variations `InstitutionalHeading`, `SacredHeading`, and `BodyStrong`.
- Produces: variations `InstitutionalPanel`, `ArchiveCard`, and `InstitutionalButton`; management surface z-order above `ManageOverlay`.

- [ ] **Step 1: Write failing consistency assertions**

Instantiate Main Menu, Save Select, Save Card, HUD, and the blocking card. Assert they use the shared theme; assert headings select the institutional variation; assert panel/button radii are at most 4 px; assert management dim alpha is at least `0.32` and Top Left, Bag, and Run Sheet render above it while open.

- [ ] **Step 2: Run the consistency test and verify it fails on the old rounded local styles**

Run:

```powershell
& $godot --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
```

Expected: non-zero exit for missing shared themes and 10-18 px corner radii.

- [ ] **Step 3: Extend the shared theme**

Define warm-charcoal `StyleBoxFlat` resources with desaturated brass borders, 2-4 px corners, restrained shadows, and focus/hover variants. Expose them through the three named type variations without changing the existing font registrations.

- [ ] **Step 4: Migrate the pictured menus and modal**

Assign `SyntheticHudTheme.tres` at each screen root, use `InstitutionalHeading` on menu/save/dossier labels, apply shared panel/button variations, uppercase menu labels where appropriate, and remove superseded rounded local style overrides.

- [ ] **Step 5: Clarify management mode and HUD surfaces**

Increase `ManageOverlay` opacity to `0.38`. When management opens, set Top Left, Run Sheet, and Bag z-index above the overlay; restore their normal z-index when it closes. Apply angular surfaces and stronger label contrast to Top Left, Bag, Run Sheet, and objective surfaces without changing inventory behavior.

- [ ] **Step 6: Run theme, HUD, settings, and pause tests**

Run:

```powershell
& $godot --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
& $godot --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& $godot --headless --path . --script res://tools/tests/MainMenuSettingsIntegrationTest.gd
& $godot --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
```

Expected: every command exits 0.

### Task 4: Visual and Full Regression Verification

**Files:**
- Modify only if verification exposes a defect in files listed above.
- Capture: `performance_results/2026-08-25/ui-consistency/*.png`

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: current screenshots and fresh test evidence for review.

- [ ] **Step 1: Run parse and focused regression suites**

```powershell
& $godot --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
& $godot --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& $godot --headless --path . --script res://tools/tests/FirstEncounterPresentationTest.gd
& $godot --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
& $godot --headless --path . --script res://tools/tests/TutorialTypewriterTest.gd
```

Expected: all commands exit 0 with zero failed assertions.

- [ ] **Step 2: Capture representative UI states**

Capture expanded/settled objectives, open management mode, Main Menu, Save Select, blocking record, and first-encounter freeze/resumed states at 1920x1080. Inspect typography, target tethering, panel overlap, contrast, and edge clamping.

- [ ] **Step 3: Review the diff against the specification**

Confirm every spec section has evidence, unrelated user files remain untouched, `.superpowers/` remains untracked, and no placeholder content was introduced.

- [ ] **Step 4: Request independent code review**

Provide the reviewer with the specification path, baseline SHA `c58e18c755659e1ff00b8fb4a57e995af7ec9a5a`, current diff, and test evidence. Resolve every critical or important finding before reporting completion.
