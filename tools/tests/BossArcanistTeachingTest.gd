extends Node

const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const ARRIVAL_PATH := "res://scenes/world/bosses/BossArrivalSprites.gd"
const RAY_ART := "res://scenes/world/bosses/art/vfx/arcane_beam_body.tres"
var _passes := 0
var _failures := 0
var _world: Node2D
var _mage: EnemyActor
var _brain: Node
var _player: Target

class Target:
	extends CharacterBody2D
	var hits: Array[float] = []
	func take_damage(amount: float, _source: Node = null) -> void:
		hits.append(amount)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _fixture(main_boss: bool = false) -> void:
	_world = Node2D.new()
	_world.position = Vector2(360, -210)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = Target.new()
	_player.collision_layer = 4
	_player.collision_mask = 1795
	_player.add_to_group(&"player")
	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 25.0
	capsule.height = 58.0
	body.shape = capsule
	_player.add_child(body)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.add_to_group(&"player_hurtbox")
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 2
	var hurt := CollisionShape2D.new()
	hurt.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70, 70)
	hurt.shape = rectangle
	hurtbox.add_child(hurt)
	_player.add_child(hurtbox)
	_world.add_child(_player)
	_player.global_position = Vector2(1900, 1100)
	_mage = MAGE.instantiate() as EnemyActor
	_mage.add_to_group(&"boss" if main_boss else &"miniboss")
	_mage.add_to_group(&"boss_like")
	_mage.set_meta(&"boss_home_pos", Vector2(1500, 1100))
	_mage.set_meta(&"boss_leash_radius", 750.0)
	_mage.set_meta(&"boss_disengage_radius", 1050.0)
	_mage.position = _world.to_local(Vector2(1500, 1100))
	_world.add_child(_mage)
	_mage.set_process(false)
	_mage.set_physics_process(false)
	_mage.player = _player
	_brain = _mage.get_node("BossBrain")
	_brain.set_process(false)
	_brain.set_physics_process(false)
	for key in [&"_fan_cd", &"_mines_cd", &"_beam_cd", &"_pylons_cd", &"_blink_cd"]:
		_brain.set(key, 99.0)

func _finish_fixture() -> void:
	get_tree().paused = false
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _shots() -> Array[EnemyProjectile]:
	var result: Array[EnemyProjectile] = []
	for child in _world.get_children():
		if child is EnemyProjectile and child.shooter == _mage and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _mines() -> Array[BossMine]:
	var result: Array[BossMine] = []
	for child in _world.get_children():
		if child is BossMine and child.source == _mage and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _sprites(node: Node, path: String) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D and child.texture != null and child.texture.resource_path == path and child.is_visible_in_tree():
			result.append(child)
		result.append_array(_sprites(child, path))
	return result

func _arrivals() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in _world.get_children():
		if child is Node2D and child.get_script() != null and child.get_script().resource_path == ARRIVAL_PATH and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _state() -> StringName:
	return StringName(_mage.get_meta(&"boss_teaching_state", &""))

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://arcanist_teaching_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var previous_seed := Global.attempt_world_seed
	Global.attempt_world_seed = 7341
	await _test_fan_and_recovery()
	await _test_recovery_stun()
	await _test_gameplay_clock()
	await _test_mine_gameplay_clock()
	await _test_mines()
	await _test_blocked_mine_corridor()
	await _test_blink()
	await _test_body_blocked_blink()
	await _test_blink_release_revalidation()
	await _test_neutral_budget_and_tier()
	Global.attempt_world_seed = previous_seed
	print("BossArcanistTeachingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _test_gameplay_clock() -> void:
	_fixture()
	_brain.call("_fan_shot")
	_brain.call("_process", 0.96)
	_check(_state() == &"fan" and _shots().is_empty(), "render time cannot release S5 pressure before physics movement catches up")
	var has_physics_clock := _brain.has_method("_physics_process")
	if has_physics_clock:
		_brain.call("_physics_process", 0.96)
	_check(has_physics_clock and _state() == &"recovery" and _shots().size() == 5, "S5 commitments advance on the same physics clock as baseline walking")
	await _finish_fixture()

func _test_mine_gameplay_clock() -> void:
	_fixture()
	_brain.call("_drop_mines")
	_brain.call("_tick_teaching", 0.61)
	var mines := _mines()
	_check(mines.size() == 3, "mine clock fixture plants a real three-node constellation")
	if not mines.is_empty():
		var mine := mines[0]
		mine.call("_process", 1.41)
		_check(not bool(mine.get("_exploded")), "render time cannot shorten the S5 mine walking escape fuse")
		var has_physics_clock := mine.has_method("_physics_process")
		if has_physics_clock:
			get_tree().paused = true
			mine.call("_physics_process", 1.41)
			_check(not bool(mine.get("_exploded")), "pause cannot spend the mine's physics fuse")
			get_tree().paused = false
			mine.call("_physics_process", 1.41)
		_check(has_physics_clock and bool(mine.get("_exploded")), "S5 mine fuse follows the baseline movement physics clock")
	await _finish_fixture()

func _test_recovery_stun() -> void:
	_fixture()
	_brain.call("_fan_shot")
	_brain.call("_tick_teaching", 0.96)
	_mage.call("_apply_enemy_world_stun", 0.01)
	_mage.stun_time = 0.0
	_brain.call("_tick_teaching", 0.1)
	_check(_state() == &"recovery" and bool(_mage.get_meta(&"boss_cast_locked", false)), "brief stun cannot shorten an already promised Arcanist recovery")
	_mage.call("_apply_enemy_world_stun", 0.5)
	var scope_ref := _mage.get_meta(&"boss_attack_scope") as WeakRef
	var scope: Node = scope_ref.get_ref()
	scope.call("cancel")
	_check(_state() == &"idle" and not bool(_mage.get_meta(&"boss_cast_locked", false)), "full source cancellation still clears recovery movement locks during a stun")
	await _finish_fixture()

func _test_fan_and_recovery() -> void:
	_fixture()
	var origin := _mage.global_position
	_brain.call("_fan_shot")
	_check(_state() == &"fan" and bool(_mage.get_meta(&"boss_cast_locked", false)), "S5 fan visibly commits and holds movement")
	var rays := _sprites(_world, RAY_ART)
	_check(rays.size() == 5, "five real raster ray cues preview the five fan bolts")
	_brain.call("_tick_teaching", 0.50)
	get_tree().paused = true
	_brain.call("_tick_teaching", 0.80)
	_check(_shots().is_empty() and _state() == &"fan", "pause spends no S5 fan anticipation")
	get_tree().paused = false
	_player.global_position = origin + Vector2(0, 400)
	_mage.global_position += Vector2(80, 30)
	_brain.call("_tick_teaching", 0.44)
	_check(_shots().is_empty(), "S5 fan holds all five bolts for the full 0.95-second tell")
	_brain.call("_tick_teaching", 0.02)
	var shots := _shots()
	_check(shots.size() == 5, "S5 releases one compact five-bolt fan")
	var geometry_matches := shots.size() == 5
	for i in range(shots.size()):
		var shot := shots[i]
		shot.set_process(false)
		shot.set_physics_process(false)
		var expected := deg_to_rad(-23.0 + 11.5 * float(i))
		geometry_matches = geometry_matches and shot.global_position.is_equal_approx(origin) and absf(angle_difference(shot.velocity.angle(), expected)) < 0.001 and absf(shot.velocity.length() - 320.0) < 0.01 and absf(shot.velocity.length() * shot.lifetime - 520.0) < 0.01
	_check(geometry_matches, "released fan matches captured origin, locked 46-degree geometry and warned 520px travel")
	_check(_state() == &"recovery" and bool(_mage.get_meta(&"boss_cast_locked", false)), "fan release opens a planted recovery instead of moving immediately")
	var hp_before := _mage.hp
	_mage.take_damage(3.0, _player)
	_check(_mage.hp < hp_before, "the recovering Arcanist still accepts incoming melee damage")
	_brain.call("_drop_mines")
	_brain.call("_blink")
	_check(_mines().is_empty() and _state() == &"recovery", "fan recovery cannot hide an overlapping mine pattern or blink")
	_brain.call("_tick_teaching", 0.89)
	_check(bool(_mage.get_meta(&"boss_cast_locked", false)), "fan retains its full 0.9-second movement opening")
	_brain.call("_tick_teaching", 0.02)
	_brain.call("_drop_mines")
	_check(_mines().is_empty() and _state() == &"idle", "released fan pressure resolves before a new major pattern")
	await _finish_fixture()

func _mine_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for mine in _mines():
		mine.set_process(false)
		result.append(mine.global_position)
	result.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y)
	return result

func _test_mines() -> void:
	_fixture()
	var center := _player.global_position
	_brain.call("_drop_mines")
	_check(_state() == &"mines" and _mines().is_empty(), "S5 plants nothing before its visible 0.6-second constellation tell")
	_brain.call("_tick_teaching", 0.59)
	_check(_mines().is_empty(), "mine planting keeps the full introductory tell")
	_player.global_position += Vector2(0, 200)
	_brain.call("_tick_teaching", 0.02)
	var positions := _mine_positions()
	_check(positions.size() == 3, "S5 plants exactly three announced mine nodes")
	var geometry_matches := positions.size() == 3
	for mine in _mines():
		geometry_matches = geometry_matches and absf(mine.global_position.distance_to(center) - 210.0) < 0.01 and absf(mine.fuse - 1.4) < 0.001
	_check(geometry_matches, "mine nodes keep the captured center and the full 1.4-second fuse")
	var safe_corridor := false
	for i in range(32):
		var end := center + Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * 240.0
		var safe := positions.size() == 3
		for point in positions:
			safe = safe and Geometry2D.get_closest_point_to_segment(point, center, end).distance_to(point) > 95.0 + 49.5 + 8.0
		safe_corridor = safe_corridor or safe
	_check(safe_corridor, "constellation preserves a corridor wider than the 70px hurtbox with safety margin")
	for _i in range(4):
		_brain.call("_drop_mines")
		_brain.call("_fan_shot")
	_check(_mines().size() == 3 and _shots().is_empty(), "live mines prevent carpet repetition and fan overlap, staying under five unresolved")
	_brain.call("_tick_teaching", 0.91)
	for mine in _mines():
		mine.call("_explode")
	_brain.call("_fan_shot")
	_check(_shots().is_empty() and _state() != &"fan", "mine detonation payloads finish before another fan can begin")
	await _finish_fixture()
	_fixture()
	_brain.call("_drop_mines")
	_brain.call("_tick_teaching", 0.61)
	_check(_mine_positions() == positions, "the same encounter seed and pattern counter reproduce the constellation across actor instances")
	await _finish_fixture()
	_fixture()
	_brain.call("_drop_mines")
	_mage.call("_apply_enemy_world_stun", 0.01)
	_mage.stun_time = 0.0
	_brain.call("_tick_teaching", 0.8)
	_check(_mines().is_empty(), "brief stun cancels a pending mine plant instead of leaving stale delayed nodes")
	await _finish_fixture()

func _test_blink() -> void:
	_fixture()
	_player.global_position = _mage.global_position + Vector2(80, 0)
	var origin := _mage.global_position
	_brain.set("_blink_cd", 0.0)
	_brain.call("_tick_teaching", 0.0)
	_check(_mage.global_position.is_equal_approx(origin) and _state() == &"blink", "S5 blink announces before moving")
	var cues := _arrivals()
	var destination := origin
	for cue in cues:
		if cue.global_position.distance_to(origin) > destination.distance_to(origin):
			destination = cue.global_position
	_check(cues.size() >= 2 and destination.distance_to(origin) > 30.0, "blink shows separate raster departure and landing markers")
	_check(destination.distance_to(_player.global_position) >= 180.0 - 0.01 and destination.distance_to(_player.global_position) <= 210.0 + 0.01, "announced landing remains within a finite melee approach")
	_brain.call("_tick_teaching", 0.79)
	_check(_mage.global_position.is_equal_approx(origin), "blink spends its full 0.8-second landing tell")
	_brain.call("_tick_teaching", 0.02)
	_check(_mage.global_position.is_equal_approx(destination) and _state() == &"recovery", "blink arrives only at its advertised location and enters recovery")
	_brain.call("_tick_teaching", 1.19)
	_check(bool(_mage.get_meta(&"boss_cast_locked", false)), "arrival holds the full 1.2-second melee opening")
	_brain.call("_tick_teaching", 0.02)
	_brain.set("_fan_cd", 99.0)
	_brain.set("_mines_cd", 99.0)
	_player.global_position = _mage.global_position + Vector2(60, 0)
	_brain.call("_tick_teaching", 0.5)
	_check(_state() != &"blink" and float(_brain.get("_blink_cd")) > 3.0, "blink cooldown prevents immediate repeated melee evasion")
	await _finish_fixture()

func _test_body_blocked_blink() -> void:
	_fixture()
	_player.global_position = _mage.global_position + Vector2(80, 0)
	# A thin closed ring leaves candidate center points empty but intersects
	# every 36.72px body at radius180..210. Point-only tests miss this trap.
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(82, 2)
		collider.shape = rectangle
		wall.add_child(collider)
		_world.add_child(wall)
		wall.global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * 201.0
		wall.rotation = angle + PI * 0.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	var origin := _mage.global_position
	_brain.set("_blink_cd", 0.0)
	_brain.call("_tick_teaching", 0.0)
	_brain.call("_tick_teaching", 0.81)
	_check(_mage.global_position.is_equal_approx(origin) and _state() != &"blink", "blink skips a point-clear destination when the actual body cannot fit")
	await _finish_fixture()

func _wall_at(point: Vector2, size: Vector2, angle: float = 0.0) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	_world.add_child(wall)
	wall.global_position = point
	wall.rotation = angle

func _test_blocked_mine_corridor() -> void:
	_fixture()
	# Mine centers and full blast discs fit outside this ring. Only the
	# player's route to their deliberately open side is blocked by terrain.
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		_wall_at(_player.global_position + Vector2.RIGHT.rotated(angle) * 90.0, Vector2(38, 2), angle + PI * 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_brain.call("_drop_mines")
	var skipped_at_commit := _state() == &"idle"
	_brain.call("_tick_teaching", 0.61)
	_check(skipped_at_commit and _mines().is_empty(), "mine constellation skips terrain that blocks every full-hurtbox escape corridor")
	await _finish_fixture()

func _test_blink_release_revalidation() -> void:
	_fixture()
	_player.global_position = _mage.global_position + Vector2(80, 0)
	var origin := _mage.global_position
	_brain.call("_blink")
	var destination: Vector2 = _brain.get("_teaching_destination")
	_wall_at(destination, Vector2(80, 80))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_brain.call("_tick_teaching", 0.81)
	_check(_mage.global_position.is_equal_approx(origin) and _state() == &"recovery" and _arrivals().is_empty(), "new obstruction cancels the announced landing without retargeting or leaving stale cues")
	await _finish_fixture()

func _test_neutral_budget_and_tier() -> void:
	_fixture()
	_player.global_position = _mage.global_position + Vector2(80, 0)
	for _i in range(12):
		_brain.call("_tick_teaching", 0.1)
	_check(_state() == &"idle" and bool(_mage.get_meta(&"boss_cast_locked", false)), "neutral kiting expires after a finite reposition budget instead of evading forever")
	# Beyond the fan's 520px reach nothing can start: a spent budget must not
	# freeze the mage while the player shoots it from just outside that reach.
	_player.global_position = _mage.global_position + Vector2(600, 0)
	_brain.call("_tick_teaching", 0.1)
	_check(_state() == &"idle" and not bool(_mage.get_meta(&"boss_cast_locked", false)), "a spent budget still lets the mage close in when the player stands beyond fan range")
	_player.global_position = _mage.global_position + Vector2(80, 0)
	_brain.call("_tick_teaching", 0.1)
	_check(bool(_mage.get_meta(&"boss_cast_locked", false)), "back within reach, the spent budget holds the mage's ground again")
	_brain.call("_beam_sweep")
	_brain.call("_spawn_pylons")
	var forbidden := false
	for child in _world.get_children():
		forbidden = forbidden or child is BossBeamSweep or child is BossPylon
	_check(not forbidden, "S5 cannot start S10 beam or pylon pressure")
	await _finish_fixture()
	_fixture(true)
	_brain.call("_fan_shot")
	_brain.call("_tick_teaching", 0.94)
	_check(_shots().is_empty(), "S10 holds the same warned 0.95 s fan tell")
	_brain.call("_tick_teaching", 0.02)
	var shots := _shots()
	_check(shots.size() == 5 and (shots.is_empty() or absf(shots[0].velocity.length() - 320.0) < 0.01), "S10 fires the compact five-bolt fan instead of the legacy nine-bolt burst")
	await _finish_fixture()
