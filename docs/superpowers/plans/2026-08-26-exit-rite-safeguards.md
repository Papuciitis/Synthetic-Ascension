# Exit Rite Safeguards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Exit Rite horde pressure intact while sealing progress at thirds, firing escalating recovery pulses, and converting exploration into manually spendable emergency safeguards.

**Architecture:** Extract monotonic seal/wave bookkeeping into a small `RiteProgressLedger`, and proxy-safe pulse effects into `RitePulseResolver`; `ExitRite` composes both and remains the channel/input/presentation owner. `SegmentProcBuilder` awards deduplicated segment-local charges from Wardstones and secondary objectives, while the existing evacuation HUD exposes only a contextual input hint.

**Tech Stack:** Godot 4.7.1, typed GDScript, `EnemyCombat`/`EnemyWorld`, CanvasItem drawing, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-08-26-exit-rite-safeguards-design.md`

## Global Constraints

- Rite seals are exactly 33%, 66%, and 100% of `hold_time`.
- Automatic pulses use `(radius, force, stun, missing-HP heal)` values `(420, 650, 0.15, 0.15)`, `(500, 850, 0.35, 0.25)`, and `(620, 1100, 0.60, 0.35)`.
- The final pulse grants exactly 5.0 seconds of player invulnerability.
- Manual pulses use 420 px radius, 700 force, 0.20 seconds stun, and 10% missing-HP healing.
- One Wardstone or one unique secondary objective grants one charge; duplicate source IDs grant nothing; capacity is three.
- Scripted burst waves fire at most once and never rewind after drain or death.
- The existing 20-second hold, burst thresholds, burst counts, Threat, per-second channel healing, and spawn regulation remain unchanged.
- All enemy displacement and stun must work for materialized and data-only enemies through `EnemyCombat` handles.
- Presentation remains occult-industrial: physical ochre/ivory seals, no neon shockwave, and no persistent new HUD panel.
- Preserve unrelated user changes and keep `.superpowers/` and performance captures out of feature commits.

---

## File Structure

- `core/systems/world/rite/RiteProgressLedger.gd`: pure state object for sealed thirds, progress floors, and monotonically spent wave indices.
- `core/systems/world/rite/RitePulseResolver.gd`: one proxy-safe operation for enemy knockback/stun and player missing-HP healing/invulnerability.
- `core/systems/world/ExitRite.gd`: channel state, seal transitions, charge ownership, manual input eligibility, VFX trigger, and glyph drawing.
- `core/systems/world/SegmentProcBuilder.gd`: maps Wardstone and secondary completions to stable deduplicated source keys and replays early sources into a later Rite instance.
- `ui/controllers/HudEvacOverlayController.gd`: shows and clears the short contextual safeguard prompt.
- `ui/overlays/EvacOverlay.tscn`: adds one compact prompt label to the existing evacuation overlay.
- `tools/tests/ExitRiteTest.gd`: deterministic seal floor, wave monotonicity, charge, and automatic pulse contracts.
- `tools/tests/RitePulseResolverTest.gd` and `.tscn`: materialized/data-only-neutral pulse operation contract through a fake combat service.
- `tools/tests/RiteSafeguardIntegrationTest.gd` and `.tscn`: Wardstone/secondary award and source replay contract.
- `tools/tests/HudContextPresentationTest.gd`: contextual prompt visibility and clearing contract.

### Task 1: Seal Progress and Make Burst History Monotonic

**Files:**
- Create: `core/systems/world/rite/RiteProgressLedger.gd`
- Modify: `tools/tests/ExitRiteTest.gd`

**Interfaces:**
- Consumes: normalized progress fractions in `[0.0, 1.0]` and zero-based scripted wave indices.
- Produces: `func update_fraction(fraction: float) -> PackedInt32Array`, `func clamp_loss_fraction(proposed: float) -> float`, `func sealed_count() -> int`, `func floor_fraction() -> float`, `func mark_wave_spent(index: int) -> bool`, `func spent_wave_count() -> int`, and `func initialize_sealed(count: int) -> void`.

- [ ] **Step 1: Replace the rewind expectation with failing ledger contracts**

Preload `RiteProgressLedger` in `ExitRiteTest.gd` and add assertions equivalent to:

```gdscript
var ledger := RiteProgressLedger.new()
_check(ledger.update_fraction(0.34) == PackedInt32Array([1]), "crossing one third seals stage 1")
_check(is_equal_approx(ledger.clamp_loss_fraction(0.10), 1.0 / 3.0), "loss stops at first seal")
_check(ledger.update_fraction(0.80) == PackedInt32Array([2]), "crossing two thirds seals stage 2")
_check(is_equal_approx(ledger.clamp_loss_fraction(0.40), 2.0 / 3.0), "loss stops at second seal")
_check(ledger.mark_wave_spent(0), "an unspent wave may fire")
_check(not ledger.mark_wave_spent(0), "a spent wave never re-arms")
_check(ledger.spent_wave_count() == 1, "wave history is monotonic")
```

Also assert `initialize_sealed(1)` makes the floor `1.0 / 3.0` without returning a newly crossed stage; this is the future `Law of Admission` integration point.

- [ ] **Step 2: Run the focused test and confirm the missing class failure**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ExitRiteTest.tscn
```

Expected: non-zero exit because `RiteProgressLedger` does not exist.

- [ ] **Step 3: Implement the pure ledger**

Use exactly three thresholds and never derive spent wave history from current progress:

```gdscript
extends RefCounted
class_name RiteProgressLedger

const SEAL_FRACTIONS := PackedFloat32Array([1.0 / 3.0, 2.0 / 3.0, 1.0])

var _sealed_count: int = 0
var _spent_waves: Dictionary = {}

func update_fraction(fraction: float) -> PackedInt32Array:
	var crossed := PackedInt32Array()
	var clamped := clampf(fraction, 0.0, 1.0)
	while _sealed_count < SEAL_FRACTIONS.size() and clamped >= SEAL_FRACTIONS[_sealed_count]:
		_sealed_count += 1
		crossed.append(_sealed_count)
	return crossed

func clamp_loss_fraction(proposed: float) -> float:
	return maxf(clampf(proposed, 0.0, 1.0), floor_fraction())

func sealed_count() -> int:
	return _sealed_count

func floor_fraction() -> float:
	return 0.0 if _sealed_count == 0 else float(SEAL_FRACTIONS[_sealed_count - 1])

func initialize_sealed(count: int) -> void:
	_sealed_count = clampi(count, 0, SEAL_FRACTIONS.size())

func mark_wave_spent(index: int) -> bool:
	if index < 0 or _spent_waves.has(index):
		return false
	_spent_waves[index] = true
	return true

func spent_wave_count() -> int:
	return _spent_waves.size()
```

- [ ] **Step 4: Run the focused test**

Run `ExitRiteTest.tscn` again. Expected: all ledger assertions pass; the old `_resync_burst_stage` assertions have been removed.

- [ ] **Step 5: Commit the state object and its tests**

```powershell
git add -- core/systems/world/rite/RiteProgressLedger.gd tools/tests/ExitRiteTest.gd
git commit -m "test: define sealed rite progress"
```

### Task 2: Resolve Pulses Through the Authoritative Enemy World

**Files:**
- Create: `core/systems/world/rite/RitePulseResolver.gd`
- Create: `tools/tests/RitePulseResolverTest.gd`
- Create: `tools/tests/RitePulseResolverTest.tscn`

**Interfaces:**
- Consumes: a combat service implementing `gather_in_radius(Vector2, float, Array[int])`, `position_for_handle(int) -> Vector2`, `apply_knockback(int, Vector2) -> bool`, and `apply_stun(int, float) -> bool`; a player exposing `health`, `max_hp`, `heal(float)`, and optional `grant_invulnerability(float)`.
- Produces: `static func apply(combat: Node, origin: Vector2, radius: float, force: float, stun_seconds: float, player: Node, missing_hp_fraction: float, invulnerability_seconds: float = 0.0) -> Dictionary` returning `{"targets": int, "healed": float, "protected": bool}`.

- [ ] **Step 1: Write a failing fake-service test**

Create a fake combat node with two handles at `(100, 0)` and `(0, 200)`, record forces/stuns, and a fake player at 40/100 HP. Assert:

```gdscript
var result := RitePulseResolver.apply(combat, Vector2.ZERO, 300.0, 600.0, 0.25, player, 0.25, 2.0)
_check(result.targets == 2, "both handles are affected")
_check(combat.knockbacks[1] == Vector2(600.0, 0.0), "force points away from origin")
_check(is_equal_approx(player.health, 55.0), "heals 25 percent of 60 missing HP")
_check(is_equal_approx(player.invulnerability, 2.0), "protection is granted")
```

Add a handle exactly at the origin and assert it receives a deterministic `Vector2.RIGHT * force` rather than NaN or no push.

- [ ] **Step 2: Run the new test and confirm it fails**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RitePulseResolverTest.tscn
```

Expected: non-zero exit because the resolver is missing.

- [ ] **Step 3: Implement the resolver with one reusable target buffer**

The resolver must calculate healing from missing HP, not max HP, and call only the supplied combat interface:

```gdscript
static func apply(combat: Node, origin: Vector2, radius: float, force: float, stun_seconds: float, player: Node, missing_hp_fraction: float, invulnerability_seconds: float = 0.0) -> Dictionary:
	var handles: Array[int] = []
	combat.call("gather_in_radius", origin, radius, handles)
	for handle in handles:
		var offset: Vector2 = combat.call("position_for_handle", handle) - origin
		var direction := Vector2.RIGHT if offset.length_squared() <= 0.000001 else offset.normalized()
		combat.call("apply_knockback", handle, direction * force)
		if stun_seconds > 0.0:
			combat.call("apply_stun", handle, stun_seconds)
	var healed := _heal_missing(player, missing_hp_fraction)
	var protected := invulnerability_seconds > 0.0 and player != null and player.has_method("grant_invulnerability")
	if protected:
		player.call("grant_invulnerability", invulnerability_seconds)
	return {"targets": handles.size(), "healed": healed, "protected": protected}
```

Implement `_heal_missing` with numeric type checks for `health` and `max_hp`, clamp the fraction to `[0, 1]`, and return the requested heal amount.

- [ ] **Step 4: Run pulse and proxy regression tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RitePulseResolverTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ProjectileHandleCombatTest.tscn
```

Expected: both exit 0.

- [ ] **Step 5: Commit**

```powershell
git add -- core/systems/world/rite/RitePulseResolver.gd tools/tests/RitePulseResolverTest.gd tools/tests/RitePulseResolverTest.tscn
git commit -m "feat: resolve proxy safe rite pulses"
```

### Task 3: Integrate Seals, Pulses, Charges, and Manual Invocation

**Files:**
- Modify: `core/systems/world/ExitRite.gd`
- Modify: `tools/tests/ExitRiteTest.gd`

**Interfaces:**
- Consumes: `RiteProgressLedger` and `RitePulseResolver.apply(...)` from Tasks 1-2; `Input` action `interact`; existing `EnemyCombat` autoload.
- Produces: `signal safeguard_state_changed(current: int, capacity: int, can_invoke: bool)`, `func grant_safeguard(source_key: StringName, amount: int = 1) -> int`, `func consume_safeguard() -> bool`, `func safeguard_count() -> int`, `func safeguard_capacity() -> int`, and `func can_invoke_safeguard() -> bool`.

- [ ] **Step 1: Add failing Exit Rite behavior assertions**

Extend `ExitRiteTest.gd` to unlock the instantiated Rite and directly exercise its public API:

```gdscript
_check(rite.grant_safeguard(&"wardstone:1") == 1, "first source grants one")
_check(rite.grant_safeguard(&"wardstone:1") == 0, "duplicate source grants none")
rite.grant_safeguard(&"secondary:10", 2)
rite.grant_safeguard(&"secondary:11", 2)
_check(rite.safeguard_count() == 3, "charges clamp to capacity")
```

Drive `_hold` across each threshold and call a focused internal `_update_rite_progress()` method. Assert the ledger seals once, `_hold` loss clamps at the floor, and `_burst_stage` never decreases after `_apply_progress_loss(...)`.

- [ ] **Step 2: Run the Exit Rite test and confirm the new API is missing**

Run `ExitRiteTest.tscn`. Expected: non-zero exit on `grant_safeguard` or `_update_rite_progress`.

- [ ] **Step 3: Replace rewind logic with ledger-driven channel logic**

In `ExitRite.gd`:

- instantiate one `RiteProgressLedger`;
- remove `_resync_burst_stage()` and every call to it;
- apply drain/death through `_apply_progress_loss(proposed_hold: float)`, which converts to a fraction, clamps with the ledger, and restores seconds;
- call `_update_rite_progress()` after every increase and before completion;
- for each returned seal index, call `_fire_automatic_seal(index)` exactly once;
- in `_maybe_spawn_bursts`, advance `_burst_stage` monotonically and require `ledger.mark_wave_spent(index)` before calling `spawn_burst`.

Use this exact automatic pulse table:

```gdscript
const AUTOMATIC_PULSES: Array[Dictionary] = [
	{"radius": 420.0, "force": 650.0, "stun": 0.15, "heal": 0.15, "invuln": 0.0},
	{"radius": 500.0, "force": 850.0, "stun": 0.35, "heal": 0.25, "invuln": 0.0},
	{"radius": 620.0, "force": 1100.0, "stun": 0.60, "heal": 0.35, "invuln": 5.0},
]
```

- [ ] **Step 4: Implement deduplicated charges and manual input**

Store `_safeguard_sources: Dictionary`, `_safeguards: int`, and `_safeguard_capacity: int = 3`. `grant_safeguard` marks a non-empty source before clamping, returns the number actually added, and emits state. `consume_safeguard` returns false unless `can_invoke_safeguard()`; on success decrement once and call the resolver with the manual values from Global Constraints.

In `_unhandled_input(event)`, invoke only on a pressed, non-echo `interact` event, and call `get_viewport().set_input_as_handled()` only when `consume_safeguard()` returns true.

- [ ] **Step 5: Run focused tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ExitRiteTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RitePulseResolverTest.tscn
```

Expected: exit 0; test summary explicitly covers all three automatic profiles, the final 5-second protection, manual charge consumption, and no wave rewind.

- [ ] **Step 6: Commit**

```powershell
git add -- core/systems/world/ExitRite.gd tools/tests/ExitRiteTest.gd
git commit -m "feat: seal and safeguard exit rites"
```

### Task 4: Award Safeguards for Exploration

**Files:**
- Modify: `core/systems/world/SegmentProcBuilder.gd`
- Create: `tools/tests/RiteSafeguardIntegrationTest.gd`
- Create: `tools/tests/RiteSafeguardIntegrationTest.tscn`

**Interfaces:**
- Consumes: `ExitRite.grant_safeguard(source_key: StringName, amount: int = 1) -> int`; `Wardstone.activated`; `RunEvents.secondary_objective_completed(objective_id: int)`.
- Produces: `func register_rite_safeguard_source(source_key: StringName, amount: int = 1) -> int` and a `_pending_rite_safeguard_sources: Dictionary` replayed in `_spawn_exit_gate()`.

- [ ] **Step 1: Write the failing builder integration test**

Instantiate `SegmentProcBuilder`, attach an `ExitRite`, and call:

```gdscript
_check(builder.register_rite_safeguard_source(&"wardstone:0") == 1, "wardstone source grants")
_check(builder.register_rite_safeguard_source(&"wardstone:0") == 0, "wardstone source deduplicates")
builder.call("_on_secondary_objective_completed", 77)
builder.call("_on_secondary_objective_completed", 77)
_check(rite.safeguard_count() == 2, "unique wardstone and secondary each grant once")
```

Create a second builder with no Rite, register `secondary:88`, then attach/spawn the Rite and assert the pending source grants exactly once.

- [ ] **Step 2: Run the integration scene and verify failure**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RiteSafeguardIntegrationTest.tscn
```

Expected: non-zero exit because `register_rite_safeguard_source` is missing.

- [ ] **Step 3: Connect both exploration sources**

When spawning Wardstones, bind the plan index to a new callback:

```gdscript
s.activated.connect(_on_wardstone_activated.bind(index))

func _on_wardstone_activated(_stone: Wardstone, index: int) -> void:
	register_rite_safeguard_source(StringName("wardstone:%d" % index))
```

At the existing unique branch of `_on_secondary_objective_completed`, call:

```gdscript
register_rite_safeguard_source(StringName("secondary:%d" % objective_id))
```

Keep the builder's own dictionary so sources completed before the Rite exists can be replayed after `_spawn_exit_gate()`. Do not award again when `restore_active()` is used or when duplicate pickup events arrive.

- [ ] **Step 4: Run integration and existing objective tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RiteSafeguardIntegrationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/SecondaryObjectiveTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/Segment1ProgressionTest.gd
```

Expected: all exit 0; existing Resonance and rewards still happen once.

- [ ] **Step 5: Commit**

```powershell
git add -- core/systems/world/SegmentProcBuilder.gd tools/tests/RiteSafeguardIntegrationTest.gd tools/tests/RiteSafeguardIntegrationTest.tscn
git commit -m "feat: reward exploration with rite safeguards"
```

### Task 5: Add Physical Glyphs and a Contextual Prompt

**Files:**
- Modify: `core/systems/world/ExitRite.gd`
- Modify: `ui/controllers/HudEvacOverlayController.gd`
- Modify: `ui/overlays/EvacOverlay.tscn`
- Modify: `tools/tests/HudContextPresentationTest.gd`

**Interfaces:**
- Consumes: `ExitRite.safeguard_state_changed(current, capacity, can_invoke)` and the existing `exit_rite_channeling` group.
- Produces: three in-world seal glyphs drawn by `ExitRite._draw()` and `HudEvacOverlayController.set_safeguard_prompt(visible: bool, count: int) -> void`.

- [ ] **Step 1: Add failing presentation assertions**

Extend `HudContextPresentationTest.gd` to locate `SafeguardPrompt`, assert it starts hidden, then call:

```gdscript
controller.set_safeguard_prompt(true, 2)
_check(prompt.visible, "safeguard prompt appears in context")
_check("2" in prompt.text and "Invoke safeguard" in prompt.text, "prompt states action and count")
controller.set_safeguard_prompt(false, 0)
_check(not prompt.visible, "prompt clears outside the Rite")
```

- [ ] **Step 2: Run the HUD test and confirm failure**

Run `HudContextPresentationTest.tscn`. Expected: non-zero exit because the label/API is absent.

- [ ] **Step 3: Draw Rite seals and safeguard pips**

In `ExitRite._draw()`, place three diamond glyphs at angles `-150°`, `-90°`, and `-30°` on `radius + 22`. Use muted bronze for unsealed glyphs, ochre/ivory for sealed glyphs, and draw up to three smaller inner pips for charges. Animate a crossed seal with the existing `_sigil_t` breathe only; do not add per-frame nodes or particle emitters.

Trigger one expanding ring under `Vfx` per pulse using a lightweight tweened `Node2D`/existing gate burst colors. Reuse assets already in the repository and keep the visual ring below enemy sprites.

- [ ] **Step 4: Add and bind the contextual prompt**

Add a single `Label` named `SafeguardPrompt` to `EvacOverlay.tscn`, styled through the shared theme, with no rounded card background. The controller text is:

```gdscript
safeguard_prompt.text = "[Interact] Invoke safeguard · %d" % count
```

Bind to the live Rite when the evacuation overlay resolves its target; clear on Rite removal, lock, completion, player exit, pause transition, or zero charges.

- [ ] **Step 5: Run presentation and input regressions**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . -s res://tools/tests/InputBindingServiceTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
```

Expected: all exit 0 and no new generic rounded panel is reported.

- [ ] **Step 6: Commit**

```powershell
git add -- core/systems/world/ExitRite.gd ui/controllers/HudEvacOverlayController.gd ui/overlays/EvacOverlay.tscn tools/tests/HudContextPresentationTest.gd
git commit -m "feat: present rite seals and safeguards"
```

### Task 6: Balance and Full Verification

**Files:**
- Modify feature files only when a failing test or measured playtest identifies a concrete defect.

**Interfaces:**
- Consumes: completed Tasks 1-5.
- Produces: verified functional and balance evidence without population changes.

- [ ] **Step 1: Run the full focused suite**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ExitRiteTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RitePulseResolverTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RiteSafeguardIntegrationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/HudContextPresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ProjectileHandleCombatTest.tscn
```

Expected: every command exits 0.

- [ ] **Step 2: Perform two controlled in-game comparisons**

Use the same seed for both runs. In the first, enter Segment 2's Rite with zero optional sources; in the second, attune at least one Wardstone and complete at least one secondary. Record completion time, deaths, lowest progress after a death, charges earned/spent, and whether any scripted wave index fires twice. Repeat the same protocol in Segment 3.

- [ ] **Step 3: Enforce the balance acceptance rules**

Accept only when all four runs retain `hold_time == 20.0`, all seven `BURST_STAGES` thresholds/counts remain unchanged, no wave repeats, loss never crosses a seal floor, and exploration produces a visibly easier recovery without making the zero-exploration run automatic. Do not change spawner caps, segment population targets, or Threat to make the gate pass.

- [ ] **Step 4: Commit only evidence-driven corrections**

Stage exact corrected feature/test paths and use:

```powershell
git commit -m "fix: close rite safeguard verification gaps"
```

Skip this commit when verification finds no defect.
