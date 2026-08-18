# Settings, Controls, and Accessibility Design

## Goal

Build a persistent, reusable settings foundation that works from the main menu now and can be opened unchanged from a future in-run menu. The foundation must support audio and display configuration, full keyboard/mouse/controller rebinding, and presentation/input accessibility without adding aim assistance, automatic firing, or other balance-affecting aids.

## Scope

This feature includes:

- A global settings service with validated defaults and versioned persistence.
- A reusable Settings screen opened by the existing main-menu Settings button.
- Audio, Video, Controls, and Accessibility tabs.
- Immediate application and persistence for ordinary settings.
- Confirm-or-revert handling for display-mode and resolution changes.
- Keyboard, mouse, controller-button, and controller-axis rebinding.
- Manual twin-stick controller aiming without snapping or target assistance.
- Conflict detection, replace/swap/cancel choices, and default restoration.
- Dedicated gameplay movement and interaction actions so menu navigation retains safe fallback inputs.
- Automated coverage for persistence, validation, runtime application, rebinding, and the main-menu route.

The player-facing in-run menu, true pause behavior, Ascension Archive, aim assist, auto-fire, balance changes, save-slot content, localization, and new gameplay augments are out of scope. Settings are machine-wide and do not belong to an individual profile slot.

## Architecture

`SettingsManager` will be an autoload and the single authority for settings values. Callers read typed accessors, request a setting change through the manager, and subscribe to a `settings_changed(section, key, value)` signal when they need live presentation updates. The manager validates every loaded or assigned value, applies supported runtime effects, and persists the complete normalized state.

Persistence and policy remain separate from UI. `SettingsScreen` reads values from `SettingsManager`, sends user changes back to it, and emits `closed` when the caller should regain focus. It does not change scenes, alter pause state, or know whether it was opened from the main menu or during a run. This makes the same scene reusable by the future in-run menu without allowing Settings to decide the game's pause rules.

Input bindings use an explicit catalog of player-facing actions and default bindings. Serialization helpers convert supported `InputEventKey`, `InputEventMouseButton`, `InputEventJoypadButton`, and directional `InputEventJoypadMotion` events into plain configuration dictionaries and restore them into `InputMap`. UI navigation actions remain protected and are not removed by player rebinding.

## Persistence and Validation

Settings are stored in `user://settings.cfg` with a schema version. The file contains separate `audio`, `video`, `controls`, and `accessibility` sections. The manager loads defaults first and then overlays valid persisted values, so missing keys from older files inherit current defaults.

The initial defaults preserve the current presentation: Master 100%, Music 32% (approximately the existing -10 dB), SFX 100%, UI 100%, 1920×1080 borderless window, VSync On, Unlimited frame limit, 100% UI scale, Normal typewriter speed at 58 characters per second, reduced motion Off, combat flashes Full, and controller deadzone 0.20. Slow typewriter speed is 30 characters per second and Fast is 100; Instant reveals the applicable text immediately.

The manager will reject malformed types and clamp numeric values to their documented ranges. Unknown keys are ignored. Unsupported display modes, unavailable resolutions, unrecognized actions, and unsupported input-event descriptions fall back to defaults without preventing the rest of the file from loading.

Saving uses primary, temporary, and backup files. The manager validates the temporary file, moves the existing primary to backup, promotes the temporary file, and restores the backup if promotion fails. Loading falls back to a valid backup when the primary is corrupt. A failed write reports an error and leaves a readable previous generation available. Tests use an injected test path under `user://tests/` and never read or overwrite the player's real settings file.

## Audio Settings

The project audio layout will expose `Master`, `Music`, `SFX`, and `UI` buses. `AudioManager` routes music players through `Music`; `SfxManager` continues selecting `SFX` and `UI` according to its manifest and no longer needs to fall back to Master when the project starts normally.

Each bus receives a 0–100 volume control and a mute toggle. Slider values are converted to decibels with Godot's linear-volume conversion, with zero treated as silence. Changes apply while the slider is moved and persist immediately.

## Video Settings

The Video tab provides:

- Window mode: Windowed, Borderless, or Fullscreen.
- Resolution selection from valid common sizes that fit the current display, plus the current window size when necessary.
- VSync: Off, On, or Adaptive when supported by the platform.
- Frame limit: Unlimited, 60, 90, 120, 144, 165, 240, and 360 FPS.

VSync and frame-limit changes apply and save immediately. Window-mode and resolution changes begin a 12-second confirmation countdown. Keeping the change persists it; cancelling or allowing the timer to expire restores the prior mode, size, and position. The confirmation overlay processes while the tree is paused, but the Settings screen itself never changes the pause state.

Windowed resolution controls are disabled when a mode makes them irrelevant. Platform APIs may report that a requested mode or VSync option is unsupported; the manager then keeps the actual supported value and the UI refreshes to match it.

## Controls

Player-facing actions are shown by category and friendly name. The initial catalog includes:

- Movement: Move Left, Move Right, Move Up, Move Down.
- Aim: Aim Left, Aim Right, Aim Up, and Aim Down.
- Combat: Primary Attack and Secondary Attack.
- Interaction: Interact, Inventory, and Activate Set.
- Augments: General Augment Action, Augment Slot 1, Slot 2, Slot 3, and Detonate.

Gameplay movement changes from `ui_left/right/up/down` to dedicated `move_left/right/up/down` actions. WASD, arrow keys, and the left stick populate those actions; the D-pad remains available for protected menu navigation and augment-slot defaults. The opening interaction changes from `ui_accept` to the player-facing `interact` action. `ui_accept`, `ui_cancel`, and menu-direction actions keep engine-compatible keyboard and controller bindings and are not exposed for destructive rebinding.

Controller aim is fully manual. The default right-stick axes populate `aim_left/right/up/down`; the right and left triggers populate Primary Attack and Secondary Attack. The player tracks the most recently active pointing device. Mouse movement returns aim to the cursor, while right-stick motion above the configured deadzone aims directly along the stick vector and remembers the last valid direction when the stick returns to center. Controller firing uses that direction. There is no target query, snapping, magnetism, automatic rotation toward an enemy, or automatic firing. A small non-targeting reticle shows the current controller aim direction and hides when mouse aiming becomes active.

Each gameplay action can hold up to two keyboard/mouse bindings and two controller bindings. A capture overlay accepts keyboard keys, mouse buttons, controller buttons, and controller axes after an activation threshold. Escape or the controller Back button cancels capture and cannot be consumed as the only way out.

When a new event is already assigned to another exposed action in the same device family, the UI offers:

- Replace: remove the conflicting assignment and bind the event to the selected action.
- Swap: exchange the selected slot with the conflicting action's slot when both are compatible.
- Cancel: leave all bindings unchanged.

Duplicate bindings on the same action are collapsed. Player-facing actions may be intentionally unbound, but the protected menu fallbacks always remain usable so Reset and Back stay reachable. Reset Tab restores all control bindings and the controller deadzone to project defaults. A global controller deadzone setting ranges from 0.10 to 0.90 and updates the gameplay actions' `InputMap` deadzones.

## Accessibility

The Accessibility tab provides settings with immediate, observable effects:

- UI scale from 80% to 150%.
- Typewriter speed: Instant, Slow, Normal, or Fast.
- Reduced motion: Off or On.
- Combat flash intensity: Full, Reduced, or Off.

UI scale updates the root content scale while retaining the project's 1920×1080 canvas layout. Values that would make the current window unusable are clamped by the manager.

Typewriter speed replaces fixed presentation constants with a value supplied by `SettingsManager`. Instant completes text on presentation; the other presets use documented character rates. Enemy dossiers retain their special rule: only lore types, and the tactical block becomes instant when the lore boundary is reached.

Reduced motion removes or shortens nonessential menu transitions and cinematic camera/UI tweens. It does not alter enemy movement, attack timing, hitboxes, or any other gameplay simulation.

Combat flash intensity is consumed by the existing enemy muzzle flash, sniper beam flash, and opening-character hit flash. Reduced lowers peak brightness/opacity and softens timing; Off suppresses the decorative flash while leaving readable attack telegraphs and gameplay objects intact. UI feedback that communicates an inventory or selection result is not removed unless it is purely decorative.

## Settings Screen and Navigation

The reusable screen follows the existing charcoal/black surface, orange border, white text, and orange-accent style. A left column contains Audio, Video, Controls, and Accessibility tabs. The right side is a scrollable settings pane. The footer contains Reset Tab and Back. Reset requires confirmation and affects only the active tab.

Every setting has a visible label and current value. Controls display separate keyboard/mouse and controller slots. The capture and conflict overlays block interaction with the settings beneath them and restore focus to the initiating binding button when closed.

The screen supports mouse, keyboard, and controller navigation. Opening it focuses the active tab; switching tabs focuses the first control in the new panel; closing returns focus to the main-menu Settings button. Back closes only the topmost capture, conflict, display-confirmation, or Settings layer in that order.

`MainMenu` connects its existing Settings button to instantiate or show the reusable screen. It does not change scenes. The future in-run menu will use the same public `open()` and `closed` contract.

## Error Handling

- Missing settings files create no error and use defaults.
- Corrupt or partially invalid files preserve every independently valid setting and replace invalid values with defaults.
- Failed persistence reports an error without rolling back a runtime-only non-display change.
- Failed display application restores the actual display state and refreshes the UI.
- Unsupported or malformed serialized bindings are skipped; an action with no valid persisted events receives its defaults.
- Rebinding never edits developer-only shortcuts such as the performance console or debug keys.

## Testing

All production behavior is developed test-first using Godot 4.7.1 headless tests.

Focused tests will prove:

1. Defaults load when no file exists, valid changes round-trip through an isolated configuration path, and malformed values normalize safely.
2. Audio values apply to the correct buses and persist independently.
3. Input events serialize and restore without losing device family, physical key, mouse button, controller button, axis, or direction.
4. Replace, swap, cancellation, duplicate collapse, per-tab reset, and fallback protection behave as specified.
5. Dedicated movement actions drive the player input path while menu navigation actions remain intact.
6. Mouse activity selects cursor aim; controller aim uses the right-stick direction, retains the last nonzero direction, and never queries or snaps to enemies.
7. Typewriter presets affect both presentation classes while preserving enemy-lore-only reveal behavior.
8. Reduced-motion and flash-intensity values produce their documented presentation result without changing gameplay timing.
9. The Settings scene opens from the existing main-menu button, supports focus navigation, and closes back to the menu.
10. Display confirmation keeps an accepted mode and restores a rejected or timed-out mode through an injectable display adapter, avoiding disruptive real monitor changes in headless tests.

After focused coverage passes, the existing main-menu, developer-segment, and segment integration smoke tests run to catch scene or autoload regressions. Godot's existing shutdown-only resource leak diagnostics are recorded separately from assertion failures.

## Success Criteria

- Settings persist globally across restarts without modifying any save slot.
- Audio, video, accessibility, and input changes have visible or audible runtime effects.
- Keyboard/mouse and controller players can rebind all exposed gameplay actions and recover defaults.
- Controller players can aim and fire manually through twin-stick input without aim assistance.
- No binding operation can strand the player without menu navigation or cancellation.
- Risky display changes automatically recover unless explicitly accepted.
- The main menu opens and closes the reusable Settings screen with correct focus behavior.
- The screen can later be embedded in an in-run menu without changing persistence, input, or pause policy.
- Aim assist, auto-fire, and other build-strength mechanics remain outside accessibility settings.
