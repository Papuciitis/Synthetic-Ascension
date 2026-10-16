extends Node

# A perfect refund, a Facet/rank refresh, or Mirror Aegis must not erase the
# authored 0.1 s gap after a ward's actual protection. Feed the real simulated
# hostile bullets through the effect; only the player's clock is controlled.

const SHIELD_SCENE = preload("res://effects/augments/scenes/ReflectedShieldEffect.tscn")
const GAP := 0.1
const EPSILON := 0.0001

class TestPlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats := Stats.new()
	var now := 0.0
	var grants: Array[Vector2] = []

	func grant_invulnerability(seconds: float) -> void:
		grants.append(Vector2(now, seconds))


var _passes := 0
var _failures := 0
var _player: TestPlayer


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
	SaveManager.current_save = null
	SaveManager.save_dir = "user://reflect_shield_gap_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	Global.start_new_attempt()
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.attempt_augment_duos = {}
	Global.selected_style_id = &"ranged"
	_player = TestPlayer.new()
	add_child(_player)
	ProjectileManager.set_physics_process(false)
	for level in [1, 8, 20]:
		for facet: StringName in [&"", &"long_guard"]:
			for cooldown_mul in [1.0, 0.0]:
				_test_projectile_stream(level, facet, cooldown_mul)
	_test_remaining_refund()
	_test_refresh_preserves_granted_window()
	_test_refresh_does_not_invent_protection()
	_test_mirror_manual_interactions()
	ProjectileManager.clear_for_run_end()
	_clear_reflections()
	_player.queue_free()
	Global.attempt_doctrine_rules = {}
	await get_tree().process_frame
	print("ReflectShieldGapTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _new_shield(level: int, facet: StringName = &"", turned: bool = false) -> ReflectShieldEffect:
	ProjectileManager.clear_for_run_end()
	_player.now = 0.0
	_player.grants.clear()
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.vfx_window_scene = null
	shield.vfx_parry_flash_scene = null
	shield.vfx_reflect_flash_scene = null
	shield.vfx_perfect_flash_scene = null
	shield.setup(_player)
	add_child(shield)
	shield.set_process(false)
	shield.set_level(level)
	shield.set_facet(facet)
	shield.set_transcended(turned)
	return shield


func _step(shield: ReflectShieldEffect, seconds: float) -> void:
	_player.now += seconds
	shield._process(seconds)


func _bullet() -> bool:
	return ProjectileManager.spawn_enemy(_player.global_position, Vector2.RIGHT, 200.0, 10.0, 2.0, null)


func _clear_reflections() -> void:
	for child in get_children():
		if child is ReflectedProjectile:
			child.free()


func _all_grants_have_gap() -> bool:
	for i in range(1, _player.grants.size()):
		var previous := _player.grants[i - 1]
		if _player.grants[i].x + EPSILON < previous.x + previous.y + GAP:
			return false
	return true


func _test_projectile_stream(level: int, facet: StringName, cooldown_mul: float) -> void:
	Global.attempt_doctrine_rules = {"active_augment_cooldown_mul": cooldown_mul}
	var shield := _new_shield(level, facet)
	var perfects := 0
	var consumed := 0
	for tick in range(300):
		shield._try_activate()
		var was_perfect := shield._perfect_used_this_cast
		var spawned := _bullet()
		_step(shield, 0.01)
		if spawned and ProjectileManager.active_count() == 0:
			consumed += 1
		if not was_perfect and shield._perfect_used_this_cast:
			perfects += 1
		ProjectileManager.clear_for_run_end()
		_clear_reflections()
	var label := "Lv.%d %s cooldown x%.1f" % [level, String(facet), cooldown_mul]
	_check(perfects >= 3 and consumed >= 3, "%s: a real bullet stream repeatedly reflects and perfect-parries" % label)
	_check(_all_grants_have_gap(), "%s: repeated perfect presses leave a 0.1 s gap between protection grants" % label)
	shield.free()
	Global.attempt_doctrine_rules = {}


func _test_remaining_refund() -> void:
	var shield := _new_shield(1)
	shield.active_base_cd = 2.0
	shield._try_activate()
	_step(shield, 0.04)
	_check(_bullet(), "the timed refund has a real hostile bullet")
	_step(shield, 0.01)
	_check(shield._perfect_used_this_cast and shield._cd < 1.0, "a perfect parry still refunds a genuinely long cooldown")
	_step(shield, 0.18)
	shield._try_activate()
	_check(_player.grants.size() == 1, "the refunded shield is unavailable just before its actual protection plus gap ends")
	_step(shield, 0.02)
	shield._try_activate()
	_check(_player.grants.size() == 2 and _all_grants_have_gap(), "the refund uses remaining protection time, so a new cast is ready after 0.24 s")
	shield.free()
	_clear_reflections()


func _test_refresh_preserves_granted_window() -> void:
	var shield := _new_shield(20, &"long_guard")
	shield._try_activate()
	_step(shield, 0.03)
	for repeat in range(3):
		shield.set_level(1)
		shield.set_facet(&"")
	_step(shield, 0.42)
	shield._try_activate()
	_check(_player.grants.size() == 1, "rank and Facet refresh cannot shorten the already granted 0.384 s ward plus its gap")
	_step(shield, 0.04)
	shield._try_activate()
	_check(_player.grants.size() == 2 and _all_grants_have_gap(), "a refreshed shield becomes usable after the original protection and gap finish")
	shield.free()


func _test_refresh_does_not_invent_protection() -> void:
	var shield := _new_shield(1)
	shield._try_activate()
	_check(_bullet(), "the rank-up fixture has a real hostile bullet")
	_step(shield, 0.01)
	for repeat in range(3):
		shield.set_level(20)
		shield.set_facet(&"long_guard")
	_step(shield, 0.24)
	shield._try_activate()
	_check(_player.grants.size() == 2 and _all_grants_have_gap(), "rank-up uses the short ward actually granted, without restarting a longer protection clock")
	_step(shield, 1.0)
	for repeat in range(3):
		shield.set_level(20)
		shield.set_facet(&"long_guard")
	shield._try_activate()
	_check(_player.grants.size() == 3, "refreshing an idle shield does not create a fresh cooldown")
	shield.free()
	_clear_reflections()


func _test_mirror_manual_interactions() -> void:
	var shield := _new_shield(20, &"long_guard", true)
	_step(shield, 1.55)
	shield._try_activate()
	_step(shield, 0.39)
	_check(_player.grants.size() == 1, "Mirror's due automatic ward waits through the manual ward's 0.1 s gap")
	_step(shield, 0.10)
	_check(_player.grants.size() == 2, "the waiting Mirror ward opens once that gap ends")
	shield._try_activate()
	_check(_player.grants.size() == 2, "manual activation cannot overlap Mirror's automatic protection")
	_step(shield, 0.47)
	shield._try_activate()
	_check(_player.grants.size() == 2, "manual activation also waits through the automatic ward's gap")
	_step(shield, 0.02)
	shield._try_activate()
	_check(_player.grants.size() == 3 and _all_grants_have_gap(), "Mirror and manual casts keep alternating after their real protection and gap")
	shield.free()
