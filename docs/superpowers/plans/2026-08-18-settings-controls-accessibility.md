# Settings, Controls, and Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent audio/video/accessibility settings, safe display previews, complete keyboard/mouse/controller rebinding, and manual twin-stick aiming through one reusable Settings screen.

**Architecture:** A versioned `SettingsStore` performs isolated disk I/O while an autoloaded `SettingsManager` owns normalized state, runtime application, and public signals. Input serialization/conflict policy and display operations live behind focused helper classes; the reusable Settings scene calls those interfaces without changing scenes or pause state. Player input consumes dedicated movement/aim actions and a small aim-state object so controller aiming remains manual and testable.

**Tech Stack:** Godot 4.7.1, typed GDScript, `ConfigFile`, `InputMap`, `AudioServer`, `DisplayServer`, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-08-18-settings-controls-accessibility-design.md`

## Global Constraints

- Settings are global machine preferences stored outside the three profile save slots.
- Ordinary changes apply and persist immediately; only mode/resolution changes require a 12-second confirmation.
- `ui_accept`, `ui_cancel`, and menu-direction actions remain protected and usable.
- Controller aiming is direct right-stick input with no enemy query, snapping, magnetism, or automatic fire.
- Accessibility settings may change presentation only, never combat timing, hitboxes, damage, or enemy simulation.
- Existing uncommitted tutorial typewriter work must be preserved and incorporated rather than overwritten.
- Every production change begins with a focused failing headless test.

---

### Task 1: Versioned Settings State and Safe Persistence

**Files:**
- Create: `core/settings/SettingsSchema.gd`
- Create: `core/settings/SettingsStore.gd`
- Create: `autoload/SettingsManager.gd`
- Create: `tools/tests/SettingsPersistenceTest.gd`
- Modify: `project.godot:18-35`

**Interfaces:**
- Produces: `SettingsSchema.defaults() -> Dictionary`
- Produces: `SettingsSchema.normalize(raw: Dictionary) -> Dictionary`
- Produces: `SettingsStore.new(primary_path: String)`
- Produces: `SettingsStore.load_settings() -> Dictionary`
- Produces: `SettingsStore.save_settings(values: Dictionary) -> bool`
- Produces: `SettingsManager.storage_path: String` (set before entering the tree when an isolated manager instance is required)
- Produces: `SettingsManager.get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant`
- Produces: `SettingsManager.set_value(section: StringName, key: StringName, value: Variant, persist: bool = true) -> bool`
- Produces: `SettingsManager.reset_section(section: StringName) -> void`
- Produces signal: `SettingsManager.settings_changed(section: StringName, key: StringName, value: Variant)`

- [ ] **Step 1: Write the failing persistence test**

Create a `SceneTree` test that uses `user://tests/settings_test.cfg`, removes only that fixture's primary, temporary, and backup files, and asserts literal defaults and normalized round trips:

```gdscript
var schema_script := load("res://core/settings/SettingsSchema.gd") as Script
var store_script := load("res://core/settings/SettingsStore.gd") as Script
_check(schema_script != null, "settings schema loads")
_check(store_script != null, "settings store loads")
if schema_script != null and store_script != null:
    var defaults: Dictionary = schema_script.call("defaults")
    _check(defaults[&"audio"][&"master_volume"] == 1.0, "master defaults to full volume")
    _check(defaults[&"accessibility"][&"typewriter_speed"] == &"normal", "typewriter defaults to normal")
    var store = store_script.new("user://tests/settings_test.cfg")
    var values := defaults.duplicate(true)
    values[&"audio"][&"music_volume"] = 0.42
    _check(store.save_settings(values), "isolated settings save succeeds")
    _check(is_equal_approx(float(store.load_settings()[&"audio"][&"music_volume"]), 0.42), "music volume round-trips")

var malformed := {
    &"audio": {&"master_volume": 12.0},
    &"video": {&"frame_limit": 17},
    &"accessibility": {&"ui_scale": 9.0, &"typewriter_speed": &"warp"},
}
var normalized: Dictionary = schema_script.call("normalize", malformed)
_check(normalized[&"audio"][&"master_volume"] == 1.0, "volume clamps to one")
_check(normalized[&"video"][&"frame_limit"] == 0, "unsupported frame limit falls back to unlimited")
_check(normalized[&"accessibility"][&"ui_scale"] == 1.5, "UI scale clamps to 150 percent")
_check(normalized[&"accessibility"][&"typewriter_speed"] == &"normal", "unknown text speed uses default")
```

- [ ] **Step 2: Run the test and verify the intended red state**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 600 --script res://tools/tests/SettingsPersistenceTest.gd
```

Expected: nonzero exit because the schema and store scripts do not exist.

- [ ] **Step 3: Implement the schema and safe store**

`SettingsSchema.gd` is a `RefCounted` `class_name SettingsSchema` with `SCHEMA_VERSION := 1`, literal nested defaults, and allowlists for window modes, VSync modes, frame limits, typewriter presets, and flash presets. Use `clampf` for volumes, UI scale, and deadzone; convert section/key names to `StringName`; deep-duplicate defaults before merging.

`SettingsStore.gd` is a `RefCounted` with exact primary, temporary, and backup paths. `load_settings()` uses `ConfigFile.load`, falls back to the backup when the primary cannot parse, reconstructs a nested dictionary from known schema sections, and returns `SettingsSchema.normalize(raw)`. `save_settings()` writes `schema_version` and every normalized value to the temporary path, validates it with a second `ConfigFile`, rotates the primary to backup, promotes the temporary file, and restores the backup if promotion fails. Never enumerate or remove a broad directory.

- [ ] **Step 4: Implement and register the manager**

Add `SettingsManager` after `SaveManager` in `project.godot`. Its `storage_path` defaults to `user://settings.cfg`; on `_ready`, construct the store from that property, load once, emit no startup change spam, and expose the typed public methods above. Tests may instantiate the same script with an isolated path before adding it to the tree. `set_value` normalizes a deep copy and emits/saves only when the normalized value differs. `reset_section` replaces only the selected section.

- [ ] **Step 5: Run focused and parse verification**

Run the persistence test, then:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit-after 600 --quit
```

Expected: persistence test reports zero failures; project parse exits zero. Existing shutdown-only resource diagnostics may remain.

- [ ] **Step 6: Commit the persistence foundation**

```powershell
git add -- core/settings/SettingsSchema.gd core/settings/SettingsStore.gd autoload/SettingsManager.gd project.godot tools/tests/SettingsPersistenceTest.gd tools/tests/SettingsPersistenceTest.gd.uid
git commit -m "feat: add persistent settings foundation"
```

---

### Task 2: Input Catalog, Serialization, and Conflict Policy

**Files:**
- Create: `core/settings/InputActionCatalog.gd`
- Create: `core/settings/InputBindingCodec.gd`
- Create: `core/settings/InputBindingService.gd`
- Create: `tools/tests/InputBindingServiceTest.gd`
- Modify: `autoload/SettingsManager.gd`
- Modify: `core/settings/SettingsSchema.gd`
- Modify: `project.godot:61-147`

**Interfaces:**
- Produces: `InputActionCatalog.entries() -> Array[Dictionary]`
- Produces: `InputActionCatalog.default_bindings() -> Dictionary`
- Produces: `InputBindingCodec.encode(event: InputEvent) -> Dictionary`
- Produces: `InputBindingCodec.decode(data: Dictionary) -> InputEvent`
- Produces: `InputBindingCodec.family(event: InputEvent) -> StringName`
- Produces: `InputBindingService.apply_saved_bindings(saved: Dictionary) -> void`
- Produces: `InputBindingService.bind_event(action: StringName, family: StringName, slot: int, event: InputEvent, resolution: StringName) -> Dictionary`
- Produces: `InputBindingService.reset_defaults() -> void`
- Produces: `InputBindingService.set_controller_deadzone(value: float) -> void`

- [ ] **Step 1: Write codec and policy failures first**

Create fixtures for a physical keyboard key, mouse button, joypad button, and signed joypad axis. Assert hand-written values after encode/decode, not equality computed through the same helper:

```gdscript
var key := InputEventKey.new()
key.physical_keycode = KEY_Q
var encoded_key: Dictionary = codec.call("encode", key)
_check(encoded_key == {&"type": &"key", &"physical_keycode": KEY_Q}, "physical key encodes literally")

var axis := InputEventJoypadMotion.new()
axis.axis = JOY_AXIS_RIGHT_X
axis.axis_value = -1.0
var encoded_axis: Dictionary = codec.call("encode", axis)
_check(encoded_axis == {&"type": &"joy_axis", &"axis": JOY_AXIS_RIGHT_X, &"direction": -1}, "negative stick axis retains direction")
```

Use fixture-only action names prefixed `test_settings_`. Assert Replace removes the other action's matching event, Swap exchanges literal slots, Cancel preserves both arrays, same-action duplicates collapse, malformed events are ignored, and `ui_cancel` remains unchanged.

- [ ] **Step 2: Run the binding test and confirm it fails because the classes are absent**

Run the new test with the standard Godot headless command. Expected: nonzero exit naming `InputBindingCodec` or `InputBindingService` as missing.

- [ ] **Step 3: Implement the explicit action catalog and defaults**

Catalog friendly labels and categories for `move_left/right/up/down`, `aim_left/right/up/down`, `attack`, `alt_attack`, `interact`, `bag_toggle`, `set_active`, `augment_active`, `augment_active_1/2/3`, and `augment_detonate`.

Defaults must include:

- WASD and arrow keys plus left-stick directions for movement; keep D-pad inputs out of gameplay movement so they can serve protected menu navigation and augment slots.
- Right-stick signed axes for aim.
- Mouse left/right plus right/left controller triggers for primary/secondary attack.
- Enter/E and controller A for Interact.
- Inventory: Tab/I/E and controller View/Back.
- Activate Set: R and controller Y.
- General Augment Action: F and right shoulder.
- Augment Slots 1/2/3: keyboard 1/2/3 and D-pad left/up/right.
- Detonate: G/middle mouse and controller X.

Add the move, aim, and interact actions to `project.godot` so scenes and editor tooling know them before runtime. Do not remove the existing `ui_*` defaults.

- [ ] **Step 4: Implement codec and binding service**

Encode only the four supported event types into plain dictionaries. For keys, persist `physical_keycode` and modifiers; for mouse/buttons persist the index; for axes persist axis plus normalized sign. Decode rejects unknown types, zero key/button identifiers, and zero axis direction.

`InputBindingService` receives an action catalog and operates only on catalog actions. Compare events by normalized encoded dictionaries. Return a result dictionary with `ok`, `conflict_action`, and `conflict_slot`; never silently modify a conflicting action without an explicit `&"replace"` or `&"swap"` resolution. Preserve and restore original fixture actions in test cleanup.

- [ ] **Step 5: Connect bindings to SettingsManager**

Store controls as encoded arrays by action and family. On startup, ensure catalog actions exist, restore valid saved events, fall back per action when none decode, and apply the normalized 0.10–0.90 controller deadzone. Manager methods delegate binding changes, then save the resulting encoded snapshot and emit `bindings_changed(action)`.

- [ ] **Step 6: Verify and commit**

Run `InputBindingServiceTest.gd`, `SettingsPersistenceTest.gd`, and project parse. Commit only the task files:

```powershell
git add -- core/settings/InputActionCatalog.gd core/settings/InputBindingCodec.gd core/settings/InputBindingService.gd core/settings/SettingsSchema.gd autoload/SettingsManager.gd project.godot tools/tests/InputBindingServiceTest.gd tools/tests/InputBindingServiceTest.gd.uid
git commit -m "feat: add safe cross-device input rebinding"
```

---

### Task 3: Runtime Audio and Safe Display Application

**Files:**
- Create: `default_bus_layout.tres`
- Create: `core/settings/DisplaySettingsAdapter.gd`
- Create: `core/settings/SettingsRuntimeApplier.gd`
- Create: `tools/tests/SettingsRuntimeTest.gd`
- Modify: `autoload/SettingsManager.gd`
- Modify: `autoload/AudioManager.gd:33-40`
- Modify: `project.godot:36-41`

**Interfaces:**
- Produces: `DisplaySettingsAdapter.capture_state() -> Dictionary`
- Produces: `DisplaySettingsAdapter.apply_state(values: Dictionary) -> Dictionary`
- Produces: `DisplaySettingsAdapter.restore_state(snapshot: Dictionary) -> void`
- Produces: `SettingsRuntimeApplier.new(display_adapter: DisplaySettingsAdapter)`
- Produces: `SettingsRuntimeApplier.apply_value(section: StringName, key: StringName, value: Variant) -> void`
- Produces: `SettingsManager.runtime_applier: SettingsRuntimeApplier` (production default is created when none is injected before `_ready`)
- Produces: `SettingsManager.begin_display_preview(changes: Dictionary) -> bool`
- Produces: `SettingsManager.confirm_display_preview() -> void`
- Produces: `SettingsManager.revert_display_preview() -> void`
- Produces signal: `SettingsManager.display_preview_started(seconds: float)`
- Produces signal: `SettingsManager.display_preview_finished(kept: bool)`

- [ ] **Step 1: Write failing runtime tests using real audio buses and a fake display adapter**

The fake adapter implements the three adapter methods and records literal requested values; it never calls the host monitor APIs. Assert Master 0.5, Music 0.32, SFX 0.75, and UI 0.8 reach their named buses within 0.01 linear tolerance. Assert frame limit 144 sets `Engine.max_fps == 144`, zero restores unlimited, and VSync is delegated.

For preview behavior, create an isolated manager with `SettingsRuntimeApplier.new(fake_adapter)`, assert the applier captures once and requests borderless 1920×1080, assert the manager persists only after confirmation, and assert rejection restores the captured dictionary. The autoload creates a production applier only when one was not injected before `_ready`.

- [ ] **Step 2: Run and verify the expected missing-runtime failure**

Run `SettingsRuntimeTest.gd`. Expected: failure because named buses/adapter/runtime helper are absent.

- [ ] **Step 3: Add named audio buses and route managers**

Create the standard Godot bus layout with Master at index 0 and Music, SFX, UI child buses sending to Master. Change both `AudioManager` players from Master to Music. Leave per-sound gains in `SfxManager`; its existing `_best_bus` will now resolve SFX/UI normally.

- [ ] **Step 4: Implement runtime application**

Convert linear audio values with `linear_to_db`; set bus mute when the stored mute is true or volume is zero. Apply `Engine.max_fps`, VSync, root `content_scale_factor`, and ordinary window settings through focused methods.

`DisplaySettingsAdapter` translates `&"windowed"`, `&"borderless"`, and `&"fullscreen"` into Godot window mode/border state and clamps requested sizes to the usable screen. It returns the actual resulting state. `SettingsRuntimeApplier` owns preview state, stores one snapshot, applies but does not persist risky values, and commits or restores atomically.

- [ ] **Step 5: Verify and commit**

Run runtime, persistence, and binding tests plus project parse. Restore `Engine.max_fps` and any audio bus values in test cleanup. Commit:

```powershell
git add -- default_bus_layout.tres core/settings/DisplaySettingsAdapter.gd core/settings/SettingsRuntimeApplier.gd autoload/SettingsManager.gd autoload/AudioManager.gd project.godot tools/tests/SettingsRuntimeTest.gd tools/tests/SettingsRuntimeTest.gd.uid
git commit -m "feat: apply audio and display preferences"
```

---

### Task 4: Accessibility Presentation Consumers

**Files:**
- Create: `core/settings/AccessibilityPresentation.gd`
- Create: `tools/tests/AccessibilitySettingsTest.gd`
- Modify: `ui/screens/TutorialCardOverlay.gd`
- Modify: `ui/screens/opening/OpeningPresentation.gd`
- Modify: `core/systems/world/opening/OpeningSequenceController.gd`
- Modify: `core/systems/world/opening/OpeningActor.gd`
- Modify: `core/actors/enemy/modules/EnemyShooter.gd`
- Modify: `core/actors/enemy/modules/EnemySniper.gd`
- Modify: `ui/screens/MajorChoice.gd`
- Modify: `tools/tests/TutorialTypewriterTest.gd`

**Interfaces:**
- Produces: `AccessibilityPresentation.typewriter_characters_per_second() -> float` (`INF` for Instant)
- Produces: `AccessibilityPresentation.motion_duration(normal_duration: float) -> float`
- Produces: `AccessibilityPresentation.flash_alpha(full_alpha: float) -> float`
- Consumes: `SettingsManager` accessibility values and `settings_changed` signal.

- [ ] **Step 1: Extend the existing typewriter test before production edits**

Set the manager preset to Instant, present a normal tutorial card, and assert `visible_characters == -1` on the first frame. Set Slow and process 0.5 seconds; assert exactly 15 visible characters when enough text exists. Retain the existing enemy lore-boundary assertions. Restore Normal in cleanup.

Add pure helper assertions: Reduced motion maps a 0.75-second cosmetic duration to 0.01, normal motion preserves 0.75, Reduced flash maps 0.95 alpha to 0.38, and Off maps it to 0.0.

- [ ] **Step 2: Run and verify red**

Run `TutorialTypewriterTest.gd` and `AccessibilitySettingsTest.gd`. Expected: new assertions fail because fixed constants and helpers remain.

- [ ] **Step 3: Implement centralized presentation policy**

`AccessibilityPresentation` reads the manager when available and otherwise returns normal defaults. Use literal rates 30, 58, and 100. Instant must complete presentation immediately without waiting for `_process`.

Replace both typewriter constants with the helper rate while preserving the dossier prefix limit: reaching the lore limit still reveals tactical text immediately. Continue still completes first and dismisses/advances second.

- [ ] **Step 4: Wire only cosmetic motion and flashes**

Apply `motion_duration` to opening camera/UI tweens and Major Choice opening transitions, not timers that gate combat or narrative data changes. Apply `flash_alpha` to opening hit flash, enemy muzzle flash, and the post-shot sniper beam/pop. When alpha is zero, skip only the decorative node creation; retain sniper telegraph lines and projectile/combat work.

- [ ] **Step 5: Verify and commit accessibility behavior**

Run both focused tests plus `DevSegmentTest.gd` and `Segment1TileIntegrationTest.gd`. Commit the approved existing typewriter files and the new accessibility integration together only after all assertions pass:

```powershell
git add -- core/settings/AccessibilityPresentation.gd ui/screens/TutorialCardOverlay.gd ui/screens/opening/OpeningPresentation.gd core/systems/world/opening/OpeningSequenceController.gd core/systems/world/opening/OpeningActor.gd core/actors/enemy/modules/EnemyShooter.gd core/actors/enemy/modules/EnemySniper.gd ui/screens/MajorChoice.gd ui/controllers/TutorialModalController.gd tools/tests/TutorialTypewriterTest.gd tools/tests/TutorialTypewriterTest.gd.uid tools/tests/AccessibilitySettingsTest.gd tools/tests/AccessibilitySettingsTest.gd.uid
git commit -m "feat: add accessible presentation controls"
```

---

### Task 5: Manual Twin-Stick Aim and Reticle

**Files:**
- Create: `core/actors/player/PlayerAimState.gd`
- Create: `core/actors/player/PlayerAimReticle.gd`
- Create: `tools/tests/PlayerAimStateTest.gd`
- Modify: `core/actors/player/player.gd:147-199,350-389`

**Interfaces:**
- Produces: `PlayerAimState.note_mouse_motion() -> void`
- Produces: `PlayerAimState.update_stick(vector: Vector2, deadzone: float) -> bool`
- Produces: `PlayerAimState.resolve_target(origin: Vector2, mouse_target: Vector2, controller_distance: float) -> Vector2`
- Produces: `PlayerAimState.using_controller() -> bool`
- Produces: `PlayerAimState.direction() -> Vector2`
- Produces: `PlayerAimReticle.set_aim(direction: Vector2, visible_for_controller: bool) -> void`

- [ ] **Step 1: Write the aim-state regression test**

Assert literal geometry and state transitions without constructing enemies:

```gdscript
var aim = aim_state_script.new()
_check(not aim.using_controller(), "mouse aim is the startup mode")
_check(aim.resolve_target(Vector2(10, 20), Vector2(90, 40), 100.0) == Vector2(90, 40), "mouse mode uses cursor target")
_check(not aim.update_stick(Vector2(0.1, 0.0), 0.2), "sub-deadzone stick does not steal aim")
_check(aim.update_stick(Vector2(0.0, -1.0), 0.2), "valid right stick selects controller aim")
_check(aim.resolve_target(Vector2(10, 20), Vector2.ZERO, 100.0) == Vector2(10, -80), "controller aim projects directly along stick")
aim.update_stick(Vector2.ZERO, 0.2)
_check(aim.direction() == Vector2.UP, "centered stick retains last valid direction")
aim.note_mouse_motion()
_check(not aim.using_controller(), "mouse motion returns control to cursor aim")
```

- [ ] **Step 2: Run and confirm missing aim-state failure**

Run the new test. Expected: nonzero exit because `PlayerAimState.gd` does not exist.

- [ ] **Step 3: Implement manual device switching and reticle**

`PlayerAimState` is a dependency-free `RefCounted`; it never receives a scene tree, enemy list, or target. Normalize stick values above deadzone and remember the last nonzero direction, defaulting to `Vector2.RIGHT`.

`PlayerAimReticle` is a lightweight `Node2D` drawing an orange ring/cross at a fixed local radius. It has no collision, query, or process loop and hides in mouse mode.

- [ ] **Step 4: Integrate player input**

Replace movement reads with `move_*`. Read `Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")`, update the aim state, set `aim_pivot`, and pass `resolve_target(...)` to `_fire_weapon`. In `_unhandled_input`, only `InputEventMouseMotion` selects mouse mode; button presses alone do not teleport aim. Add the reticle once in `_ready` or the player scene and update it from aim state. The same attack actions work for mouse and controller triggers.

- [ ] **Step 5: Verify and commit**

Run `PlayerAimStateTest.gd`, project parse, and the segment smoke tests. Commit:

```powershell
git add -- core/actors/player/PlayerAimState.gd core/actors/player/PlayerAimReticle.gd core/actors/player/player.gd tools/tests/PlayerAimStateTest.gd tools/tests/PlayerAimStateTest.gd.uid
git commit -m "feat: add manual twin-stick aiming"
```

---

### Task 6: Reusable Settings Screen and Modal Layers

**Files:**
- Create: `ui/screens/settings/SettingsScreen.gd`
- Create: `ui/screens/settings/SettingsScreen.tscn`
- Create: `ui/screens/settings/InputCaptureOverlay.gd`
- Create: `ui/screens/settings/InputCaptureOverlay.tscn`
- Create: `ui/screens/settings/BindingConflictOverlay.gd`
- Create: `ui/screens/settings/BindingConflictOverlay.tscn`
- Create: `ui/screens/settings/DisplayConfirmationOverlay.gd`
- Create: `ui/screens/settings/DisplayConfirmationOverlay.tscn`
- Create: `ui/screens/settings/BindingRow.gd`
- Create: `ui/screens/settings/BindingRow.tscn`
- Create: `tools/tests/SettingsScreenTest.gd`

**Interfaces:**
- Produces signal: `SettingsScreen.closed`
- Produces: `SettingsScreen.open() -> void`
- Produces: `SettingsScreen.close() -> void`
- Produces: `SettingsScreen.configure(settings_source: Node) -> void`
- Produces: `SettingsScreen.refresh_from_manager() -> void`
- Produces signal: `InputCaptureOverlay.captured(event: InputEvent)`
- Produces signal: `InputCaptureOverlay.cancelled`
- Produces signal: `BindingConflictOverlay.resolved(choice: StringName)`
- Produces signal: `DisplayConfirmationOverlay.finished(keep: bool)`

- [ ] **Step 1: Write the scene behavior test**

Instantiate a real `SettingsManager` script with `storage_path = "user://tests/settings_screen_test.cfg"` and an injected `SettingsRuntimeApplier` backed by a fake display adapter, add it to the test tree under a non-autoload name, and pass it to `SettingsScreen.configure`. Load and instantiate the Settings scene. Assert Audio/Video/Controls/Accessibility tabs exist, opening focuses the active tab, switching tabs shows exactly one pane, Audio changes update that isolated manager, controls build one row per catalog entry, capture Escape cancels, conflict buttons emit literal replace/swap/cancel values, Reset Tab leaves other sections unchanged, and Back closes the topmost layer before closing Settings.

For display confirmation, manually tick its 12-second countdown in test and assert timeout emits `false`; do not change the real monitor.

- [ ] **Step 2: Run and confirm scene-missing red state**

Run `SettingsScreenTest.gd`. Expected: failure because the scene and overlays do not exist.

- [ ] **Step 3: Build the stable scene skeleton**

Use a full-rect Control, dark translucent backdrop, centered charcoal panel with orange border, left tab column, right `ScrollContainer`, and footer Reset Tab/Back buttons. Author stable node paths in `.tscn`; build repeated setting rows in GDScript. Give buttons focus and explicit directional neighbors where automatic ordering is ambiguous.

- [ ] **Step 4: Build typed setting controls**

Audio rows use sliders plus mute checkboxes. Video rows use option buttons and start a preview only for mode/resolution. Accessibility rows use UI-scale slider and option/toggle controls. Connect changes once in `_ready`; use a `_refreshing` guard so manager-to-UI refreshes do not write back.

- [ ] **Step 5: Build binding capture and conflicts**

Each `BindingRow` shows two keyboard/mouse and two controller slots plus clear controls. Capture accepts the next supported event after one frame, ignores mouse motion, requires controller-axis magnitude at least 0.65, and formats names through `InputEvent.as_text()` with explicit axis direction labels. On conflict, leave state unchanged until the conflict overlay returns Replace, Swap, or Cancel.

- [ ] **Step 6: Build safe layer and focus behavior**

Settings never changes `SceneTree.paused`. `ui_cancel` closes capture, then conflict, then display confirmation (reverting), then the screen. Every close restores focus to its opener. Display overlay calls `confirm_display_preview` only for Keep and `revert_display_preview` for Cancel/timeout.

- [ ] **Step 7: Verify and commit**

Run screen, persistence, binding, and runtime tests plus project parse. Commit:

```powershell
git add -- ui/screens/settings tools/tests/SettingsScreenTest.gd tools/tests/SettingsScreenTest.gd.uid
git commit -m "feat: add reusable settings screen"
```

---

### Task 7: Main-Menu Route and Full Regression Verification

**Files:**
- Create: `tools/tests/MainMenuSettingsIntegrationTest.gd`
- Modify: `ui/screens/MainMenu.gd:3-60`
- Modify: `ui/screens/MainMenu.tscn:178-220`

**Interfaces:**
- Consumes: `SettingsScreen.open()`, `SettingsScreen.closed`
- Produces: the existing Main Menu Settings button opens one reusable Settings instance and regains focus on close.

- [ ] **Step 1: Write the failing menu integration test**

Instantiate `MainMenu.tscn`, locate the existing Settings button, assert the four player-facing menu buttons accept focus, emit Settings `pressed`, await one frame, and assert exactly one `SettingsScreen` exists and is visible. Emit its close path, then assert it is hidden and the menu Settings button owns focus. Press twice across two open/close cycles and assert no duplicate signal side effects or stacked screens.

- [ ] **Step 2: Run and confirm the dormant-button failure**

Run `MainMenuSettingsIntegrationTest.gd`. Expected: the existing Settings button does not open a screen.

- [ ] **Step 3: Connect the reusable screen**

Set Continue, Saves, Settings, and Quit to `Control.FOCUS_ALL` in the scene. Add an onready Settings button reference and preload the Settings scene. Instantiate once on demand beneath the menu, call `configure(SettingsManager)`, connect `closed` once, call `open`, and restore Settings-button focus when it hides on close. Do not free/recreate it, change scenes, or alter pause state.

- [ ] **Step 4: Run every focused settings/input/accessibility test**

Run, individually, with exit code zero:

```text
SettingsPersistenceTest.gd
InputBindingServiceTest.gd
SettingsRuntimeTest.gd
AccessibilitySettingsTest.gd
TutorialTypewriterTest.gd
PlayerAimStateTest.gd
SettingsScreenTest.gd
MainMenuSettingsIntegrationTest.gd
```

- [ ] **Step 5: Run existing smoke coverage**

Run:

```text
DevSegmentTest.gd
Segment1TileIntegrationTest.gd
```

Then run `git diff --check` and project parse. Treat existing shutdown-only RID/ObjectDB/resource leak diagnostics as known test-harness cleanup output only when every test reports zero assertion failures and exits zero.

- [ ] **Step 6: Perform a manual menu/controller check**

From Main Menu: open Settings, change and restore each audio bus, navigate all tabs with keyboard and controller, bind one keyboard key and one controller axis, resolve one conflict each way, test Reset Tab, preview/reject a window change, select Instant typewriter mode, close Settings, restart, and confirm persistence. In a developer segment, verify WASD/left-stick movement, mouse aim, right-stick aim and reticle, both trigger attacks, and no target snapping.

- [ ] **Step 7: Commit the integration**

```powershell
git add -- ui/screens/MainMenu.gd ui/screens/MainMenu.tscn tools/tests/MainMenuSettingsIntegrationTest.gd tools/tests/MainMenuSettingsIntegrationTest.gd.uid
git commit -m "feat: open settings from main menu"
```

- [ ] **Step 8: Review the final branch state**

Confirm `git status --short`, `git log --oneline --decorate -12`, and `git diff origin/main...HEAD --stat` contain only the approved typewriter, settings, controls, accessibility, twin-stick, tests, specification, and plan changes. Do not push unless the user requests it.
