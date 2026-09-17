extends Node

# Plan §2.5 priced the Cursed Vault at "Threat spike + a Hunter beat +
# healing disabled for 45 s"; roadmap §10 Sacrifice and §8.1 ritual
# interference restrict healing too; §27 recorded "healing lock (no mechanism
# exists yet)". Pins the mechanism on the player: a sealed heal lands nothing
# and says nothing, a seal takes the longer of two locks and never shortens,
# RunEvents.healing_lock_changed fires on start / extension / expiry,
# BattleText gets one line per lock, the Rite's own mend is sealed like
# everything else (Decision - an export can exempt it), and the HP bar's
# controller shows the seal without processing while healing is open.
#
# Run: <godot> --headless --path . res://tools/tests/HealingLockTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const HealthControllerScript = preload("res://ui/controllers/HudHealthController.gd")

var _passes := 0
var _failures := 0
var _locks: Array = []           # [seconds_left, reason] per healing_lock_changed
var _heals: Array[float] = []    # applied amount per player_healed
var _tips: Array[String] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	RunEvents.healing_lock_changed.connect(_on_lock)
	RunEvents.player_healed.connect(_on_healed)
	RunEvents.tutorial_tip.connect(_on_tip)

	await _test_seal_on_the_player()
	await _test_expiry_reopens_healing()
	_test_exempt_sources_export()
	await _test_hp_bar_tell()

	RunEvents.healing_lock_changed.disconnect(_on_lock)
	RunEvents.player_healed.disconnect(_on_healed)
	RunEvents.tutorial_tip.disconnect(_on_tip)
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments
	print("HealingLockTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _on_lock(seconds_left: float, reason: StringName) -> void:
	_locks.append([seconds_left, reason])


func _on_healed(_player: Node, amount: float) -> void:
	_heals.append(amount)


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _spawn_player() -> CharacterBody2D:
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	_locks.clear()
	_heals.clear()
	_tips.clear()
	return player


func _free_player(player: CharacterBody2D) -> void:
	remove_child(player)
	player.free()


func _locked_seconds(player: Node) -> float:
	return float(player.call("healing_locked_seconds"))


func _lock_is(index: int, seconds: float, reason: StringName) -> bool:
	if index >= _locks.size():
		return false
	var entry: Array = _locks[index]
	return is_equal_approx(float(entry[0]), seconds) and StringName(entry[1]) == reason


# ---------------------------------------------------------------------------

## Through the real player: open healing lands and reports; a seal lands
## nothing from any source and reports nothing; the longer lock wins.
func _test_seal_on_the_player() -> void:
	var player := _spawn_player()
	await get_tree().process_frame
	var max_hp: float = float(player.get("max_hp"))
	var half: float = max_hp * 0.5
	player.set("hp", half)

	player.call("heal", 10.0)
	_check(is_equal_approx(float(player.get("hp")), half + 10.0), "open: a heal lands (%.1f)" % float(player.get("hp")))
	_check(_heals.size() == 1 and is_equal_approx(_heals[0], 10.0), "and player_healed reports what landed")
	_check(_locked_seconds(player) == 0.0, "no lock to begin with")

	var lines_before: int = BattleText._count
	player.call("lock_healing", 45.0, &"cursed_vault")
	_check(is_equal_approx(_locked_seconds(player), 45.0), "lock_healing seals for 45 s (%.1f)" % _locked_seconds(player))
	_check(_locks.size() == 1 and _lock_is(0, 45.0, &"cursed_vault"), "healing_lock_changed on the start, with the reason (%s)" % [_locks])
	_check(BattleText._count == lines_before + 1, "one combat line per lock (%d)" % (BattleText._count - lines_before))
	var line: String = BattleText._texts[lines_before] if BattleText._count > lines_before else ""
	_check(line == "HEALING SEALED - 45s", "and it is the seal line with the seconds (%s)" % line)
	_check(_tips.size() == 1 and _tips[0].begins_with("HEALING SEALED"), "the first seal of the run teaches once (%d)" % _tips.size())

	var hp_before: float = float(player.get("hp"))
	player.call("heal", 10.0)
	player.call("heal", 10.0, &"pickup")
	player.call("heal", 10.0, &"exit_rite")
	player.call("heal", 10.0, &"wardstone")
	_check(is_equal_approx(float(player.get("hp")), hp_before), "sealed: nothing lands - generic, pickup, the Rite's mend, the wardstone (%.1f)" % float(player.get("hp")))
	_check(_heals.size() == 1, "no player_healed for a heal that did not happen (%d)" % _heals.size())
	_check(BattleText._count == lines_before + 1, "and no line per refused heal")

	player.call("lock_healing", 10.0, &"sacrifice")
	_check(is_equal_approx(_locked_seconds(player), 45.0), "a shorter lock never shortens the seal (%.1f)" % _locked_seconds(player))
	_check(_locks.size() == 1, "and is not announced")
	player.call("lock_healing", 60.0, &"sacrifice")
	_check(is_equal_approx(_locked_seconds(player), 60.0), "a longer lock extends it to 60 s - max, not sum (%.1f)" % _locked_seconds(player))
	_check(_locks.size() == 2 and _lock_is(1, 60.0, &"sacrifice"), "healing_lock_changed on the extension (%s)" % [_locks])
	line = BattleText._texts[lines_before + 1] if BattleText._count > lines_before + 1 else ""
	_check(BattleText._count == lines_before + 2 and line == "HEALING SEALED - 60s", "one line for the extension too (%s)" % line)
	_check(_tips.size() == 1, "the teach does not repeat within the run")

	await get_tree().process_frame
	var left: float = _locked_seconds(player)
	_check(left < 60.0 and left > 50.0, "the seal counts down in the player's _process (%.3f)" % left)
	_check(_locks.size() == 2, "and counting down is not an announcement")

	_free_player(player)


## A seal that runs out says so once, with 0.0, and healing is open again.
func _test_expiry_reopens_healing() -> void:
	var player := _spawn_player()
	await get_tree().process_frame
	var half: float = float(player.get("max_hp")) * 0.5
	player.set("hp", half)

	player.call("lock_healing", 0.001, &"ritual")
	_check(_locks.size() == 1 and _lock_is(0, 0.001, &"ritual"), "fixture: a hair of a seal")
	player.call("heal", 10.0)
	_check(is_equal_approx(float(player.get("hp")), half), "fixture: sealed while it lasts")

	# Headless frames can be very short; wait for the player's clock, capped.
	for i in range(240):
		await get_tree().process_frame
		if _locked_seconds(player) <= 0.0:
			break
	_check(_locked_seconds(player) == 0.0, "the seal lifts (%.4f)" % _locked_seconds(player))
	_check(_locks.size() == 2 and _lock_is(1, 0.0, &"ritual"), "healing_lock_changed on expiry carries 0.0 and the reason (%s)" % [_locks])

	var before: float = float(player.get("hp"))
	var heals_before: int = _heals.size()
	player.call("heal", 10.0)
	_check(is_equal_approx(float(player.get("hp")), before + 10.0), "healing is open again (%.1f)" % float(player.get("hp")))
	_check(_heals.size() == heals_before + 1 and is_equal_approx(_heals[_heals.size() - 1], 10.0), "and reports again")

	_free_player(player)


## The Decision made exportable: an empty list seals every source; naming
## &"exit_rite" lets the Rite's mend through while the rest stays sealed.
func _test_exempt_sources_export() -> void:
	var player := _spawn_player()
	var exempt: Array[StringName] = [&"exit_rite"]
	player.set("healing_lock_exempt_sources", exempt)
	var half: float = float(player.get("max_hp")) * 0.5
	player.set("hp", half)

	player.call("lock_healing", 30.0, &"cursed_vault")
	player.call("heal", 10.0)
	_check(is_equal_approx(float(player.get("hp")), half), "a generic heal stays sealed")
	player.call("heal", 10.0, &"exit_rite")
	_check(is_equal_approx(float(player.get("hp")), half + 10.0), "an exempted source lands while sealed (%.1f)" % float(player.get("hp")))

	_free_player(player)


## The HP bar's tell: nothing added and no processing while healing is open;
## on a seal the fill takes the seal colour and a countdown label appears on
## the bar; an extension updates the count without losing the plain fill; the
## lift hands the fill back and the controller sleeps. Reduced motion holds
## the label steady where full motion pulses it.
func _test_hp_bar_tell() -> void:
	var root := Control.new()
	add_child(root)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	root.add_child(bar)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.2, 0.8, 0.3, 1.0)
	bar.add_theme_stylebox_override("fill", plain)
	var ctl: HudHealthController = HealthControllerScript.new()
	ctl.bar_path = NodePath("../Bar")
	root.add_child(ctl)

	_check(not ctl.is_processing(), "open: the controller does not process")
	_check(bar.get_node_or_null("HPSeal") == null, "and adds nothing to the bar")

	RunEvents.healing_lock_changed.emit(45.0, &"cursed_vault")
	var seal := bar.get_node_or_null("HPSeal") as Label
	_check(seal != null and seal.visible and seal.text == "SEALED 45s", "a seal puts the countdown on the bar (%s)" % (seal.text if seal != null else "<none>"))
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	_check(fill != null and fill.bg_color == ctl.sealed_fill_color, "and the fill takes the seal colour")
	_check(ctl.is_processing() and ctl.is_sealed(), "and counts down while sealed")

	RunEvents.healing_lock_changed.emit(60.0, &"sacrifice")
	_check(seal != null and seal.text == "SEALED 60s", "an extension updates the count (%s)" % (seal.text if seal != null else "<none>"))
	fill = bar.get_theme_stylebox("fill") as StyleBoxFlat
	_check(fill != null and fill.bg_color == ctl.sealed_fill_color, "and keeps the seal colour")

	# No player in the tree: the controller's own clock carries the count.
	ctl._process(1.5)
	_check(seal != null and seal.text == "SEALED 59s", "the count moves with time (%s)" % (seal.text if seal != null else "<none>"))
	_check(seal != null and seal.modulate.a < 1.0, "full motion: the label pulses (%.2f)" % (seal.modulate.a if seal != null else -1.0))

	RunEvents.healing_lock_changed.emit(0.0, &"sacrifice")
	_check(seal != null and not seal.visible, "the lift takes the label off the bar")
	_check(bar.get_theme_stylebox("fill") == plain, "and hands the plain fill back")
	_check(not ctl.is_processing(), "and the controller sleeps again")

	var saved_motion: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	RunEvents.healing_lock_changed.emit(5.0, &"ritual")
	ctl._process(0.6)
	_check(seal != null and is_equal_approx(seal.modulate.a, 1.0), "reduced motion: the label holds steady (%.2f)" % (seal.modulate.a if seal != null else -1.0))
	_check(seal != null and seal.text == "SEALED 5s", "but still counts (%s)" % (seal.text if seal != null else "<none>"))
	RunEvents.healing_lock_changed.emit(0.0, &"ritual")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", saved_motion, false)

	remove_child(root)
	root.free()
