extends Node
## The actual elite caller already raises its paint anchor before BattleText
## raises it again. Preserve that layout while keeping the physical birth Y.
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)

func _run() -> void:
	AudioManager.stop_all(true)
	var prior_rng := Global._rng.state
	var prior_scheduler := EnemySimulationScheduler.is_physics_processing()
	var prior_callouts: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	EnemySimulationScheduler.set_physics_process(false)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	BattleText.clear()
	var actor := ENEMY.instantiate() as EnemyActor
	actor.position = Vector2(300,444)
	add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	var ids: Array[StringName] = [EliteModifiers.ARMOURED]
	actor._announce_elite_modifiers(ids, Color.WHITE)
	BattleText.set_process(false)
	_check(BattleText._count == 1, "real visible elite announcer creates its status callout")
	if BattleText._count == 1:
		_check(is_equal_approx(BattleText.drawn_position(0).y, 376), "elite's existing two visual raises retain their original layout")
		_check(is_equal_approx(BattleText._feet_y[0],444), "elite callout physical birth contact is independent of its raised paint anchor")
	BattleText.clear()
	actor.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SettingsManager.set_value(&"accessibility", &"ability_callouts", prior_callouts, false)
	EnemySimulationScheduler.set_physics_process(prior_scheduler)
	Global._rng.state = prior_rng
	print("EnemyCalloutContactTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
