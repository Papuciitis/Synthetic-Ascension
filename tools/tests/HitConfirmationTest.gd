extends Node

# Hit confirmation (audit 2026-10-04, change 5): a materialized enemy that
# survives a hit flashes white for 0.07 s (at most once per 0.12 s), every
# crit and one ordinary hit in three throws a hit spark (12 per frame at most),
# damage-over-time ticks do neither, and a crit merging into a climbing damage
# number keeps its crit styling.

const BattleTextScript := preload("res://core/combat/BattleTextRenderer.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _live_sparks() -> int:
	return PooledVfx.live_count(VfxBursts.scene(&"hit_spark"))


func _run() -> void:
	var previous_flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	await _test_battle_text_crit_merge()
	await _test_flash_registry()
	await _test_spark_budget()
	await _test_enemy_feedback_path()
	SettingsManager.set_value(&"accessibility", &"combat_flash", previous_flash, false)
	print("HitConfirmationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_battle_text_crit_merge() -> void:
	var text := BattleTextScript.new()
	add_child(text)
	await get_tree().process_frame
	text.damage(Vector2(10, 10), 10.0, false, 77)
	text.damage(Vector2(10, 10), 5.0, true, 77)
	var count := int(text.get("_count"))
	var colors: PackedColorArray = text.get("_colors")
	var scales: PackedFloat32Array = text.get("_scales")
	var amounts: PackedFloat32Array = text.get("_amounts")
	var lifetimes: PackedFloat32Array = text.get("_lifetimes")
	_check(count == 1 and is_equal_approx(amounts[0], 15.0), "the crit merges into the climbing number (%d entries, %.0f)" % [count, amounts[0] if count > 0 else -1.0])
	_check(count == 1 and colors[0] == BattleTextScript.CRIT_COLOR, "and promotes it to the crit colour")
	_check(count == 1 and is_equal_approx(scales[0], BattleTextScript.CRIT_SCALE), "and the crit size")
	_check(count == 1 and is_equal_approx(lifetimes[0], BattleTextScript.CRIT_LIFETIME), "and the crit lifetime")
	text.damage(Vector2(10, 10), 3.0, false, 77)
	colors = text.get("_colors")
	_check(int(text.get("_count")) == 1 and colors[0] == BattleTextScript.CRIT_COLOR, "a later ordinary hit never demotes a crit number")
	text.queue_free()
	await get_tree().process_frame


func _test_flash_registry() -> void:
	var feedback := get_node("/root/WorldFeedbackVfx")
	var body := Node2D.new()
	add_child(body)
	feedback.flash_hit(body)
	_check(body.modulate.r > 2.0 and body.modulate.g > 2.0 and is_equal_approx(body.modulate.a, 1.0), "a flashed body turns overbright white (%s)" % body.modulate)
	_check(feedback.is_flashing(body) and feedback.live_flash_count() == 1, "the flash is tracked once")
	feedback.flash_hit(body)
	_check(feedback.live_flash_count() == 1, "a repeat inside the flash extends it instead of stacking")
	await _wait_ms(feedback.FLASH_MS + 60)
	_check(body.modulate == Color.WHITE and not feedback.is_flashing(body), "after 0.07 s the body is its own colour again (%s)" % body.modulate)

	# A tinted body comes back to its tint, not to white.
	body.modulate = Color(0.5, 0.8, 1.0, 0.9)
	feedback.flash_hit(body)
	await _wait_ms(feedback.FLASH_MS + 60)
	_check(body.modulate.is_equal_approx(Color(0.5, 0.8, 1.0, 0.9)), "a tinted body gets its tint back (%s)" % body.modulate)

	# Freed mid-flash: nothing touches it again and the slot clears.
	var doomed := Node2D.new()
	add_child(doomed)
	feedback.flash_hit(doomed)
	doomed.free()
	await _wait_ms(feedback.FLASH_MS + 60)
	_check(feedback.live_flash_count() == 0, "a body freed mid-flash leaves no slot behind")

	# Combat Flashes: Reduced dims the flash, Off skips it.
	body.modulate = Color.WHITE
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"reduced", false)
	feedback.flash_hit(body)
	_check(body.modulate.r > 1.01 and body.modulate.r < 2.0, "Reduced combat flashes dim the flash (%.2f)" % body.modulate.r)
	await _wait_ms(feedback.FLASH_MS + 60)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
	feedback.flash_hit(body)
	_check(body.modulate == Color.WHITE and feedback.live_flash_count() == 0, "Combat Flashes off skips it")
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	body.queue_free()
	await get_tree().process_frame


func _test_spark_budget() -> void:
	var feedback := get_node("/root/WorldFeedbackVfx")
	await _wait_ms(300) # let earlier sparks return to the pool
	feedback.set("_hits_since_spark", 0)
	var before := _live_sparks()
	for i in range(3):
		feedback.note_enemy_hit(Vector2(i * 10, 0), false, Vector2.RIGHT)
	_check(_live_sparks() - before == 1, "one ordinary hit in three throws a spark (%d)" % (_live_sparks() - before))
	await get_tree().process_frame
	before = _live_sparks()
	feedback.note_enemy_hit(Vector2(0, 50), true, Vector2.RIGHT)
	_check(_live_sparks() - before == 1, "a crit always throws one")
	await get_tree().process_frame
	before = _live_sparks()
	for i in range(40):
		feedback.note_enemy_hit(Vector2(i * 5, 100), true, Vector2.RIGHT)
	_check(_live_sparks() - before == feedback.HIT_SPARKS_PER_FRAME, "a storm of crits in one frame throws at most %d (%d)" % [feedback.HIT_SPARKS_PER_FRAME, _live_sparks() - before])
	await _wait_ms(400)


func _test_enemy_feedback_path() -> void:
	var feedback := get_node("/root/WorldFeedbackVfx")
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var pool := get_node("/root/PoolManager")
	var enemy := pool.call("obtain", scene, self) as EnemyActor
	_check(enemy != null, "fixture: a real pooled enemy spawns")
	if enemy == null:
		return
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	enemy.configure_health(500.0, true)
	await get_tree().process_frame
	enemy.take_damage(2.0, null)
	_check(feedback.is_flashing(enemy), "a hit the enemy survives flashes it")
	_check(enemy.modulate.r > 2.0, "through the actor's modulate, which the batched renderer multiplies in (%s)" % enemy.modulate)
	await _wait_ms(feedback.FLASH_MS + 20)
	_check(not feedback.is_flashing(enemy) and enemy.modulate == Color.WHITE, "and the flash ends on its own")
	# Inside the 0.12 s per-enemy window a second hit does not re-flash.
	enemy.take_damage(2.0, null)
	_check(not feedback.is_flashing(enemy), "a hit inside 0.12 s of the last flash does not flash again")
	await _wait_ms(150)
	EnemyCombat.apply_status_damage(EnemyWorld.handle_for_actor(enemy), 2.0, null, &"burn")
	_check(not feedback.is_flashing(enemy), "a burn tick does not flash")
	# A crit through a ledger flashes and always sparks.
	var before := _live_sparks()
	var ledger := HitLedger.new()
	ledger.add_resolved_hit(3.0, null, Vector2.ZERO, true, 0, 0.0, 0.5, 0.0)
	enemy.apply_hit_ledger(ledger)
	_check(feedback.is_flashing(enemy), "a crit ledger flashes the enemy")
	_check(_live_sparks() - before == 1, "and throws a spark")
	await _wait_ms(feedback.FLASH_MS + 40)
	enemy.take_damage(9999.0, null)
	await get_tree().process_frame
	_check(feedback.live_flash_count() == 0, "a dead enemy leaves no flash behind")
