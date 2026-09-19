extends Node

# Roster audit N5: the Siphon drains the discipline meter the run banks
# (Force, Momentum, Heat) instead of Followers, and falls back to a
# Follower bite when the build carries no meter.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/SiphonTest.tscn

const PLAYER_SCENE := preload("res://core/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const SIPHON_SPEC := preload("res://core/actors/enemy/EnemySpec_Siphon.tres")

var _passes := 0
var _failures := 0
var _player: Node = null
var _runner: AscensionRunner = null
var _ledger: AscensionLedger = null


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _load(native: String, ids: Array) -> void:
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
	_ledger = Global.ascension_ledger()
	_ledger.note_segment_completed(9)
	for entry in ids:
		_ledger.record_purchase(String(entry), 100)
	_runner.refresh()


func _engine_with(method: String) -> AscensionEngine:
	for engine in _runner.engines:
		if engine.has_method(method):
			return engine
	return null


func _run() -> void:
	Global.start_new_attempt()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_load("melee", ["BA01", "BA02"])
	var bastion := _engine_with("spend_force")
	_check(bastion != null, "a Bastion build carries the Force engine")
	bastion.set("force", 50.0)
	var drained: float = _runner.drain_discipline(8.0)
	_check(is_equal_approx(drained, 8.0) and is_equal_approx(float(bastion.get("force")), 42.0), "a bite drains 8 Force (%.1f left)" % float(bastion.get("force")))
	bastion.set("force", 3.0)
	_check(is_equal_approx(_runner.drain_discipline(8.0), 3.0) and is_zero_approx(float(bastion.get("force"))), "it cannot take more Force than is banked")
	_load("ranged", ["BR01", "BR02"])
	var barrage := _engine_with("vent_heat")
	_check(barrage != null, "a Barrage build carries the Heat engine")
	barrage.set("heat", 30.0)
	_check(is_equal_approx(_runner.drain_discipline(8.0), 8.0) and is_equal_approx(float(barrage.get("heat")), 22.0), "a bite vents 8 Heat")
	_load("melee", ["EX01", "EX02"])
	_check(is_zero_approx(_runner.drain_discipline(8.0)), "a build with no meter gives nothing to drain")
	# The Siphon's bite through the Leech module: meter first, Followers only
	# when there is none.
	var siphon := ENEMY_SCENE.instantiate() as EnemyActor
	siphon.spec = SIPHON_SPEC
	siphon.global_position = Vector2(400, 0)
	add_child(siphon)
	await get_tree().process_frame
	var leech: EnemyLeech = siphon.get("_leech")
	Global.set_followers(100)
	leech.call("_drain_once", _player)
	_check(int(Global.followers) == 99, "with no meter the Siphon bites one Follower like a Leech")
	_load("melee", ["BA01", "BA02"])
	var bastion2 := _engine_with("spend_force")
	bastion2.set("force", 40.0)
	Global.set_followers(100)
	leech.call("_drain_once", _player)
	_check(is_equal_approx(float(bastion2.get("force")), 32.0) and int(Global.followers) == 100, "with Force banked the Siphon drains 8 Force and no Followers")
	siphon.queue_free()
	_player.queue_free()
	print("SiphonTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
