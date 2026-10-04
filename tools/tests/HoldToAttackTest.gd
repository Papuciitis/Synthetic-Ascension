extends Node

# Hold to Attack (audit 2026-10-04, change 3): a held attack button fires at
# the weapon's own cadence, never once per frame; the setting off restores one
# attack per press; and Death Rattle does not bill a held trigger as panic.
# The player's own _process is stopped and every frame is stepped by hand, so
# the cadence is counted against a known 60 Hz clock, not the headless one.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const STEP := 1.0 / 60.0

class FakePlayer extends Node2D:
	@warning_ignore("unused_signal")
	signal hp_changed(current: float, max_hp: float)
	var hp: float = 30.0
	var max_hp: float = 100.0
	var native_attack_repeated: bool = false

var _passes := 0
var _failures := 0
var _shots := 0
var _last_cooldown := 0.0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_weapon_fired(_p: Node, _style: StringName, _o: Vector2, _t: Vector2, _pm: float, _hm: float) -> void:
	_shots += 1


func _run() -> void:
	var defaults: Dictionary = SettingsSchema.defaults()
	_check(bool(defaults[&"controls"].get(&"hold_to_attack", false)), "Hold to Attack defaults ON")
	var normalized: Dictionary = SettingsSchema.normalize({&"controls": {&"hold_to_attack": 0}})
	_check(normalized[&"controls"][&"hold_to_attack"] is bool and not bool(normalized[&"controls"][&"hold_to_attack"]), "a stored value normalizes to a bool")

	var previous_hold: Variant = SettingsManager.get_value(&"controls", &"hold_to_attack", true)
	var previous_style: String = String(Global.selected_style_id)
	Global.selected_style_id = "ranged"
	RunEvents.weapon_fired.connect(_on_weapon_fired)

	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)

	# --- held, setting on: the cooldown is the cadence -------------------
	SettingsManager.set_value(&"controls", &"hold_to_attack", true, false)
	var shots := _hold_for(player, 60)
	var ranged_cd := _last_cooldown
	var expected := expected_for(ranged_cd)
	_check(ranged_cd > 0.0, "fixture: a shot starts the weapon cooldown (%.3fs)" % ranged_cd)
	_check(shots == expected, "holding for 1 s fires at the ranged cadence (%d shots, expected %d at %.3fs)" % [shots, expected, ranged_cd])
	_check(shots < 10, "and never once per frame (%d shots in 60 frames)" % shots)

	# Melee keeps its slower cadence under the same hold.
	Global.selected_style_id = "melee"
	player.set("_weapon_cd", 0.0)
	shots = _hold_for(player, 60)
	var melee_cd := _last_cooldown
	expected = expected_for(melee_cd)
	_check(melee_cd > ranged_cd, "fixture: melee recovers slower than ranged (%.3f vs %.3f)" % [melee_cd, ranged_cd])
	_check(shots == expected, "melee held for 1 s fires at its own cadence (%d shots, expected %d)" % [shots, expected])
	Global.selected_style_id = "ranged"

	# A press on cooldown is still refused: mashing every frame is no faster.
	player.set("_weapon_cd", 0.0)
	_shots = 0
	for i in range(60):
		player.call("_process", STEP)
		player.call("_step_attack_input", true, true, false, false, STEP)
	_check(_shots == expected_for(ranged_cd), "pressing every frame fires no faster than holding (%d)" % _shots)

	# --- held, setting off: one attack per press -------------------------
	SettingsManager.set_value(&"controls", &"hold_to_attack", false, false)
	player.set("_weapon_cd", 0.0)
	shots = _hold_for(player, 60)
	_check(shots == 1, "with Hold to Attack off a held button attacks once (%d)" % shots)

	# The held flag only stands while the held shot resolves.
	SettingsManager.set_value(&"controls", &"hold_to_attack", true, false)
	player.set("_weapon_cd", 0.0)
	var seen: Array = []
	var probe := func(p: Node, _s: StringName, _o: Vector2, _t: Vector2, _pm: float, _hm: float) -> void:
		seen.append(bool(p.get("native_attack_repeated")))
	RunEvents.weapon_fired.connect(probe)
	player.call("_step_attack_input", true, true, false, false, STEP)
	for i in range(30):
		player.call("_process", STEP)
		player.call("_step_attack_input", false, true, false, false, STEP)
	RunEvents.weapon_fired.disconnect(probe)
	_check(seen.size() >= 2 and seen[0] == false, "the press is not flagged as a held repeat (%s)" % [seen])
	_check(seen.size() >= 2 and seen[1] == true, "the held repeats are (%s)" % [seen])
	_check(not bool(player.get("native_attack_repeated")), "and the flag is down again once the shot resolved")

	_test_death_rattle()
	await _test_settings_row()

	RunEvents.weapon_fired.disconnect(_on_weapon_fired)
	SettingsManager.set_value(&"controls", &"hold_to_attack", previous_hold, false)
	Global.selected_style_id = previous_style
	player.queue_free()
	await get_tree().process_frame
	print("HoldToAttackTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func expected_for(cd: float) -> int:
	return 1 + int(floor(1.0 / (ceilf(cd / STEP) * STEP)))


## Presses on the first frame, then holds for `frames` frames of STEP.
func _hold_for(player: Node, frames: int) -> int:
	_shots = 0
	player.call("_step_attack_input", true, true, false, false, STEP)
	_last_cooldown = float(player.get("_weapon_cd"))
	for i in range(frames - 1):
		player.call("_process", STEP)
		player.call("_step_attack_input", false, true, false, false, STEP)
	return _shots


## The Controls page builds the row and shows the live value. Never toggled
## here: the screen persists what it changes, and a suite must not write the
## player's settings file.
func _test_settings_row() -> void:
	var screen_scene := load("res://ui/screens/settings/SettingsScreen.tscn") as PackedScene
	var screen := screen_scene.instantiate()
	screen.call("configure", SettingsManager)
	add_child(screen)
	await get_tree().process_frame
	screen.call("open")
	await get_tree().process_frame
	(screen.find_child("ControlsTab", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var row: CheckBox = null
	for node in screen.find_children("", "CheckBox", true, false):
		if (node as CheckBox).text == "Keep attacking while the attack button is held":
			row = node as CheckBox
	_check(row != null, "Controls builds the Hold to Attack checkbox")
	if row != null:
		_check(row.button_pressed == bool(SettingsManager.get_value(&"controls", &"hold_to_attack", true)), "and it shows the live setting")
	screen.call("close")
	screen.queue_free()
	await get_tree().process_frame


func _test_death_rattle() -> void:
	var fake := FakePlayer.new()
	add_child(fake)
	var state := ManifestationState.new()
	add_child(state)
	state.bind_player(fake)
	state.set_process(false)
	state.claim(&"cadence")
	state.claim(&"ward")
	var def := ManifestationPairCatalog.get_def(&"death_rattle")
	var pair := def.logic.new() as ManifestationPairEffect
	add_child(pair)
	pair.setup_pair(fake, state, def, 0.0)
	pair.set_process(false)
	var beats: int = int(def.logic.get_script_constant_map()["BEATS"])
	_check(state.wound_tier() >= 2, "fixture: 30% HP is wounded")

	# A held trigger reaching the empowered beat early does not arm the hold.
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = 0.0
	fake.native_attack_repeated = true
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(not bool(pair.get("_hold_armed")) and is_zero_approx(state.time_since_attack), "Death Rattle does not hold a beat for a held trigger")
	var hp_before := fake.hp
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(is_equal_approx(fake.hp, hp_before), "so holding fire while wounded costs nothing (%.1f)" % fake.hp)

	# A fresh press still arms it exactly as before.
	fake.native_attack_repeated = false
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = 0.0
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(bool(pair.get("_hold_armed")), "a fresh press still arms the held beat")
	pair.queue_free()
	state.queue_free()
	fake.queue_free()
