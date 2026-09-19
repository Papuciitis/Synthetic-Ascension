extends Node

# Roster audit E6 and the new Chanter (N2): a Herald's pulse wards nearby
# allies (20% less damage taken for 1.8 s, composed and restored), and a
# Chanter's pulse mends them 8% of max HP and wards them 15%.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/HeraldWardTest.tscn

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const HERALD_SPEC := preload("res://core/actors/enemy/EnemySpec_Herald.tres")
const CHANTER_SPEC := preload("res://core/actors/enemy/EnemySpec_Chanter.tres")
const GRUNT_SPEC := preload("res://core/actors/enemy/EnemySpec_Grunt.tres")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn(spec: EnemySpec, at: Vector2) -> EnemyActor:
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	enemy.spec = spec
	enemy.global_position = at
	add_child(enemy)
	return enemy


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _run() -> void:
	Global.start_new_attempt()
	var herald := _spawn(HERALD_SPEC, Vector2(0, 0))
	var ally := _spawn(GRUNT_SPEC, Vector2(120, 0))
	var far := _spawn(GRUNT_SPEC, Vector2(900, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var ally_handle: int = EnemyCombat.handle_for_actor(ally)
	_check(EnemyWorld.is_valid_handle(ally_handle), "the ally is registered")
	herald.get("_herald").call("_do_pulse")
	_check(ally.is_warded() and is_equal_approx(float(ally.get_meta("damage_taken_mul", 1.0)), 0.8), "a Herald pulse wards the ally: damage taken x0.8")
	_check(not far.is_warded(), "an ally outside the pulse radius is not warded")
	var applied: float = EnemyCombat.apply_damage(ally_handle, 5.0, 1, null, null)
	_check(is_equal_approx(applied, 4.0), "a 5 damage hit lands as 4 on the warded ally (%.2f)" % applied)
	ally.set_meta("damage_taken_mul", 1.25)
	ally.apply_ward_buff(0.2, 1.8)
	_check(is_equal_approx(float(ally.get_meta("damage_taken_mul", 1.0)), 1.0), "a second ward composes on the unwarded value, not on the ward")
	ally.set_meta("damage_taken_mul", 1.0)
	ally.remove_meta("damage_taken_mul_unwarded")
	ally.remove_meta("damage_taken_mul_warded")
	ally.apply_ward_buff(0.2, 0.5)
	await _wait(2.2)
	_check(not ally.is_warded() and is_equal_approx(float(ally.get_meta("damage_taken_mul", 1.0)), 1.0), "after its duration the ward lifts and the multiplier is back to one")
	# The Chanter mends and wards.
	var chanter := _spawn(CHANTER_SPEC, Vector2(2000, 0))
	var wounded := _spawn(GRUNT_SPEC, Vector2(2100, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var wounded_handle: int = EnemyCombat.handle_for_actor(wounded)
	var max_hp: float = EnemyWorld.get_max_health(wounded_handle)
	EnemyCombat.apply_damage(wounded_handle, max_hp * 0.5, 1, null, null)
	var before: float = EnemyWorld.get_health(wounded_handle)
	chanter.get("_herald").call("_do_pulse")
	var after: float = EnemyWorld.get_health(wounded_handle)
	_check(is_equal_approx(after - before, max_hp * 0.08), "a Chanter pulse mends the wounded ally 8%% of max HP (%.2f of %.2f)" % [after - before, max_hp])
	_check(wounded.is_warded() and is_equal_approx(float(wounded.get_meta("damage_taken_mul", 1.0)), 0.85), "and wards it 15%")
	_check(CHANTER_SPEC.projectile_scene == null and CHANTER_SPEC.herald_player_drain_amount == 0, "the Chanter has no attack and drains no Followers")
	for enemy in [herald, ally, far, chanter, wounded]:
		if is_instance_valid(enemy):
			enemy.queue_free()
	print("HeraldWardTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
