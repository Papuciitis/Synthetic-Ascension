extends Node

# Real Area2D overlaps at non-origin positions: no engine stubs, distance
# padding or source-text assertions. The player records actual damage calls.
const CIRCLE_SCENE = preload("res://core/combat/hazards/DamageCircle.tscn")
const MINE_SCENE = preload("res://scenes/world/bosses/BossMine.tscn")
const BEAM_SCENE = preload("res://scenes/world/bosses/BossBeamSweep.tscn")
const SCOPE_PATH := "res://scenes/world/bosses/BossAttackScope.gd"
const HOME := Vector2(1200.0, 900.0)
const AWAY := Vector2(6000.0, 6000.0)

class WitnessPlayer:
	extends Node2D
	var hits: Array[Dictionary] = []
	func take_damage(amount: float, source: Node = null) -> void:
		hits.append({"damage": amount, "source": source})

class Caster:
	extends Node2D
	var dead := false
	var stun_time := 0.0

var _passes := 0
var _failures := 0
var _player: WitnessPlayer
var _hurt_shape: CollisionShape2D


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _physics_frames(count: int = 3) -> void:
	for _i in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_hazard_geometry_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	_player = WitnessPlayer.new()
	_player.add_to_group(&"player")
	_player.position = AWAY
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 2
	hurtbox.add_to_group(&"player_hurtbox")
	_hurt_shape = CollisionShape2D.new()
	_hurt_shape.shape = RectangleShape2D.new()
	(_hurt_shape.shape as RectangleShape2D).size = Vector2(70.0, 70.0)
	hurtbox.add_child(_hurt_shape)
	_player.add_child(hurtbox)
	add_child(_player)
	await _physics_frames()
	await _test_circle_setup_and_geometry()
	await _test_actual_hurtbox_bounds()
	await _test_circle_lifetime_and_pause()
	await _test_mine_fuse_and_warning()
	await _test_mine_impact_under_translated_scene()
	await _test_beam_orientation_visibility_and_damage()
	await _test_source_death()
	await _test_scope_invalidation()
	get_tree().paused = false
	_clear_hazards()
	_player.queue_free()
	await get_tree().process_frame
	print("BossHazardGeometryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _reset_player(at: Vector2 = AWAY, size: Vector2 = Vector2(70.0, 70.0)) -> void:
	_player.position = at
	(_hurt_shape.shape as RectangleShape2D).size = size
	_player.hits.clear()


func _circle(at: Vector2, r: float, life: float = 1.0, source: Node = null, configure_first: bool = true) -> DamageCircle:
	var circle := CIRCLE_SCENE.instantiate() as DamageCircle
	if configure_first:
		circle.setup(at, r, 18.0, life, source)
	add_child(circle)
	if not configure_first:
		circle.setup(at, r, 18.0, life, source)
	return circle


func _clear_hazards() -> void:
	for child in get_children():
		if child is DamageCircle or child is BossMine or child is BossBeamSweep:
			child.free()


func _visible_sprites(node: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D and child.texture != null and child.is_visible_in_tree() and child.modulate.a > 0.0:
			result.append(child)
		result.append_array(_visible_sprites(child))
	return result


func _test_circle_setup_and_geometry() -> void:
	_reset_player()
	var small := _circle(HOME, 26.0)
	var large := _circle(HOME + Vector2(400.0, 0.0), 135.0, 1.0, null, false)
	await _physics_frames()
	var small_shape := small.get_node("CollisionShape2D") as CollisionShape2D
	var large_shape := large.get_node("CollisionShape2D") as CollisionShape2D
	_check(small_shape.shape != large_shape.shape, "simultaneous hazards own independent collision shapes")
	_check(is_equal_approx((small_shape.shape as CircleShape2D).radius, 26.0), "a configured charge crumb keeps its actual 26 px collision radius")
	_check(is_equal_approx((large_shape.shape as CircleShape2D).radius, 135.0), "setup after add updates a slam's actual 135 px collision radius")
	_clear_hazards()


func _test_actual_hurtbox_bounds() -> void:
	# A very small/scaled Hurtbox is 48 px from the circle edge here. The
	# former +32 distance allowance incorrectly damaged it on _ready.
	_reset_player(HOME + Vector2(50.0, 0.0), Vector2(4.0, 4.0))
	await _physics_frames()
	_circle(HOME, 20.0)
	await _physics_frames()
	_check(_player.hits.is_empty(), "a small Hurtbox outside the true circle is not hit by an invented 32 px allowance")
	_clear_hazards()
	_reset_player(HOME + Vector2(60.0, 0.0), Vector2(100.0, 20.0))
	await _physics_frames()
	_circle(HOME, 20.0)
	await _physics_frames()
	_check(_player.hits.size() == 1 and is_equal_approx(float(_player.hits[0]["damage"]), 18.0), "an already-overlapping wide Hurtbox receives the configured damage exactly once")
	_clear_hazards()
	# Late configuration must not damage a player at the default origin.
	_reset_player(Vector2.ZERO)
	await _physics_frames()
	_circle(HOME, 95.0, 1.0, null, false)
	await _physics_frames()
	_check(_player.hits.is_empty(), "adding before setup never causes a default-origin hit")
	_clear_hazards()


func _test_circle_lifetime_and_pause() -> void:
	_reset_player()
	var short := _circle(HOME, 85.0, 0.12, null, false)
	await _wait(0.17)
	_check(not is_instance_valid(short), "a late-configured short hazard expires at its authored lifetime")
	_clear_hazards()
	var paused := _circle(HOME, 85.0, 0.15)
	get_tree().paused = true
	await _wait(0.24)
	_check(is_instance_valid(paused), "a paused hazard does not spend its lifetime behind the pause menu")
	get_tree().paused = false
	await _wait(0.20)
	_check(not is_instance_valid(paused), "hazard lifetime resumes when gameplay resumes")
	_clear_hazards()


func _test_mine_fuse_and_warning() -> void:
	_reset_player()
	var mine := MINE_SCENE.instantiate() as BossMine
	add_child(mine)
	mine.setup(HOME, null, 0.65, 95.0, 15.0)
	await _wait(0.36)
	_check(is_instance_valid(mine) and not _visible_sprites(mine).is_empty(), "a mine still shows its real blast footprint well after the old quarter-second pop")
	if is_instance_valid(mine):
		var sprites := _visible_sprites(mine)
		var at_mine := false
		for sprite in sprites:
			at_mine = at_mine or sprite.global_position.distance_to(HOME) < 1.0
		_check(at_mine, "the persistent mine warning is at the configured world position")
	get_tree().paused = true
	await _wait(0.42)
	_check(is_instance_valid(mine), "a mine's fuse pauses with its warning")
	get_tree().paused = false
	await _wait(0.38)
	_check(not is_instance_valid(mine), "a late-configured mine uses its 0.65 s fuse instead of the default 1.10 s timer")
	_clear_hazards()


func _test_mine_impact_under_translated_scene() -> void:
	_reset_player()
	var original_scene := get_tree().current_scene
	var translated_scene := Node2D.new()
	translated_scene.name = "TranslatedMineExplosionScene"
	translated_scene.position = Vector2(360.0, -210.0)
	get_tree().root.add_child(translated_scene)
	get_tree().current_scene = translated_scene
	var mine := MINE_SCENE.instantiate() as BossMine
	mine.setup(HOME, null, 1.05, 95.0, 14.0)
	translated_scene.add_child(mine)
	var warning := mine.get_node("BlastWarning") as Node2D
	_check(warning.global_position.is_equal_approx(HOME), "a translated current scene keeps the mine warning at its configured world origin")
	# Exercise the production explosion and inspect the actual authored VFX,
	# not a replacement scene or a calculation of its expected local offset.
	mine._explode()
	var impact: Node2D = null
	var damage_circle: DamageCircle = null
	for child in translated_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scenes/world/bosses/BossImpactSprites.gd":
			impact = child
		elif child is DamageCircle:
			damage_circle = child
	_check(impact != null and impact.global_position.is_equal_approx(HOME), "mine explosion impact matches the warned world origin under a translated current scene (expected %s, actual %s)" % [HOME, impact.global_position if impact != null else "missing authored impact"])
	_check(damage_circle != null and damage_circle.global_position.is_equal_approx(HOME), "the real mine explosion damage circle matches its warning under a translated current scene")
	get_tree().current_scene = original_scene
	translated_scene.free()
	await _physics_frames()


func _test_beam_orientation_visibility_and_damage() -> void:
	_reset_player(HOME + Vector2(0.0, 100.0))
	await _physics_frames()
	var beam := BEAM_SCENE.instantiate() as BossBeamSweep
	beam.telegraph_time = 0.45
	beam.sweep_time = 0.60
	beam.length = 200.0
	beam.width = 28.0
	add_child(beam)
	beam.setup(HOME, PI * 0.5, PI * 0.5, null)
	await _physics_frames()
	_check(absf(angle_difference(beam.rotation, PI * 0.5)) < 0.001, "a late-configured beam telegraphs at its actual starting angle")
	_check(_player.hits.is_empty(), "the beam cannot hurt during anticipation")
	get_tree().paused = true
	await _wait(0.50)
	_check(is_instance_valid(beam) and _player.hits.is_empty(), "pausing does not advance the beam into its damaging phase")
	get_tree().paused = false
	await _wait(0.65)
	_check(is_instance_valid(beam) and not _visible_sprites(beam).is_empty(), "the active beam remains visibly drawn after the old telegraph effect would have vanished")
	_check(not _player.hits.is_empty() and is_equal_approx(float(_player.hits[0]["damage"]), 16.0), "a player inside the configured beam receives its unchanged 16 damage")
	_clear_hazards()
	_reset_player(HOME + Vector2(30.0, 0.0), Vector2(4.0, 4.0))
	await _physics_frames()
	var narrow := BEAM_SCENE.instantiate() as BossBeamSweep
	narrow.length = 150.0
	narrow.width = 12.0
	narrow.telegraph_time = 0.02
	narrow.sweep_time = 0.4
	narrow.setup(HOME, PI * 0.5, PI * 0.5, null)
	add_child(narrow)
	var second := BEAM_SCENE.instantiate() as BossBeamSweep
	second.length = 400.0
	second.width = 80.0
	second.setup(AWAY, 0.0, 0.0, null)
	add_child(second)
	await _wait(0.28)
	_check(_player.hits.is_empty(), "a simultaneous wide beam does not widen another beam or hit outside its rotated rectangle")
	var first_shape := narrow.get_node("Area/CollisionShape2D") as CollisionShape2D
	var second_shape := second.get_node("Area/CollisionShape2D") as CollisionShape2D
	_check(first_shape.shape != second_shape.shape, "simultaneous beams own independent rectangle resources")
	_clear_hazards()


func _test_source_death() -> void:
	_reset_player(HOME)
	await _physics_frames()
	var caster := Caster.new()
	add_child(caster)
	var mine := MINE_SCENE.instantiate() as BossMine
	mine.setup(HOME, caster, 0.5, 95.0, 15.0)
	add_child(mine)
	caster.dead = true
	mine._explode()
	await _physics_frames()
	_check(_player.hits.is_empty(), "a mine cannot explode into damage after its caster dies")
	_clear_hazards()
	_reset_player(HOME)
	caster.dead = false
	var beam := BEAM_SCENE.instantiate() as BossBeamSweep
	beam.telegraph_time = 0.01
	beam.sweep_time = 0.50
	beam.setup(HOME, 0.0, 0.0, caster)
	add_child(beam)
	caster.dead = true
	await _wait(0.28)
	_check(_player.hits.is_empty() and not is_instance_valid(beam), "a beam cancels instead of keeping its dead caster's damage active")
	_clear_hazards()
	_reset_player(HOME)
	caster.dead = false
	var circle := _circle(HOME + Vector2(100.0, 0.0), 20.0, 1.0, caster)
	caster.dead = true
	_player.position = HOME + Vector2(100.0, 0.0)
	await _physics_frames()
	_check(_player.hits.is_empty() and not is_instance_valid(circle), "a damage circle cancels when its caster dies before contact")
	_clear_hazards()
	caster.free()


func _test_scope_invalidation() -> void:
	var scope_script := load(SCOPE_PATH) as Script
	_check(scope_script != null, "the shared encounter attack scope is available")
	if scope_script == null:
		return
	_reset_player(HOME)
	await _physics_frames()
	var caster := Caster.new()
	add_child(caster)
	var scope := scope_script.new() as Node
	caster.add_child(scope)
	scope.call("setup", caster)
	var circle := CIRCLE_SCENE.instantiate() as DamageCircle
	circle.setup(AWAY, 26.0, 5.0, 0.65, caster)
	scope_script.call("bind", circle, caster)
	add_child(circle)
	await _wait(0.32)
	_check(is_instance_valid(circle) and not _visible_sprites(circle).is_empty(), "a bound damaging footprint remains visible for the entire active hazard")
	scope.call("cancel")
	await _physics_frames()
	_check(not is_instance_valid(circle), "scope cancellation also removes a visible active footprint")
	var mine := MINE_SCENE.instantiate() as BossMine
	mine.setup(HOME, caster, 0.12, 95.0, 15.0)
	scope_script.call("bind", mine, caster)
	add_child(mine)
	caster.set_meta("boss_returning", true)
	await _wait(0.22)
	_check(_player.hits.is_empty() and not is_instance_valid(mine), "a live returning caster invalidates its bound mine before damage")
	caster.set_meta("boss_returning", false)
	var beam := BEAM_SCENE.instantiate() as BossBeamSweep
	beam.setup(HOME, 0.0, 0.0, caster)
	scope_script.call("bind", beam, caster)
	add_child(beam)
	scope.call("cancel")
	await _physics_frames()
	_check(not is_instance_valid(beam) and _player.hits.is_empty(), "scope cancellation removes active hazards without damage")
	_clear_hazards()
	caster.free()
