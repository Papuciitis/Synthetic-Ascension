extends Node

# These real casts catch shared-looking attacks, missing anticipation and
# cosmetic nodes that outlive cancellation or disappear with damage payloads.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const MINE := preload("res://scenes/world/bosses/BossMine.tscn")
const Scope := preload("res://scenes/world/bosses/BossAttackScope.gd")
const SLAM_ART := "res://scenes/world/bosses/art/vfx/slam_fracture_v1.png"
const SHOCK_ART := "res://scenes/world/bosses/art/vfx/shock_crackle_v1.png"
const MINE_ART := "res://scenes/world/bosses/art/vfx/mine_sigil_v1.png"
const CHARGE_ART := "res://scenes/world/bosses/art/vfx/charge_windup_v1.png"
const CASTER_ART := "res://assets/textures/vfx/encounters/pulse_ripple_v1.png"
const IMPACT_SCRIPT := "res://scenes/world/bosses/BossImpactSprites.gd"
const WINDUP_SCRIPT := "res://scenes/world/bosses/BossWindupSprites.gd"

var _passes := 0
var _failures := 0
var _world: Node2D
var _player: Node2D


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


func _sprites(node: Node, path: String) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D and child.texture != null and child.texture.resource_path == path and child.is_visible_in_tree() and child.modulate.a > 0.0:
			found.append(child)
		found.append_array(_sprites(child, path))
	return found


func _components(node: Node, path: String) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child in node.get_children():
		if child is Node2D and child.get_script() != null and child.get_script().resource_path == path and not child.is_queued_for_deletion():
			found.append(child)
		found.append_array(_components(child, path))
	return found


func _circles(kind: StringName) -> Array[DamageCircle]:
	var found: Array[DamageCircle] = []
	for child in _world.get_children():
		if child is DamageCircle and child.get("attack_style") == kind:
			found.append(child)
	return found


func _spawn(scene: PackedScene, pos: Vector2) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.position = _world.to_local(pos)
	_world.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.player = _player
	actor.get_node("BossBrain").set_process(false)
	actor.get_node("BossBrain").set_physics_process(false)
	return actor


func _clear() -> void:
	for child in _world.get_children():
		if child != _player:
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_attack_identity_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var previous_motion: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var previous_flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	var old_scene := get_tree().current_scene
	_world = Node2D.new()
	_world.name = "TranslatedAttackIdentityWorld"
	_world.position = Vector2(360, -210)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = Node2D.new()
	_player.add_to_group(&"player")
	_world.add_child(_player)
	_player.global_position = Vector2(1700, 1100)
	await _test_physical_attacks()
	await _test_mine()
	await _test_charge_windup()
	await _test_caster_windup()
	get_tree().paused = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", previous_flash, false)
	get_tree().current_scene = old_scene
	_world.queue_free()
	await get_tree().process_frame
	print("BossAttackIdentityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_physical_attacks() -> void:
	var origin := Vector2(1500, 1100)
	var tank := _spawn(TANK, origin)
	var brain := tank.get_node("BossBrain")
	brain.call("_do_slam")
	_check(not _sprites(_world, SLAM_ART).is_empty(), "committed slam previews fractured ground instead of the common seal")
	_check(_sprites(_world, SHOCK_ART).is_empty() and _sprites(_world, MINE_ART).is_empty(), "slam preview cannot borrow shock or mine artwork")
	brain.call("_tick_cast", float(brain.get("slam_windup")) + 0.01)
	var slams := _circles(&"slam")
	_check(slams.size() == 1 and not _sprites(slams[0], SLAM_ART).is_empty(), "real slam damage retains the matching fractured-ground footprint")
	var impacts := _components(_world, IMPACT_SCRIPT)
	_check(impacts.size() == 1 and impacts[0].global_position.is_equal_approx(origin), "released slam impact stays at the warned world origin under a translated scene")
	if impacts.size() == 1:
		var impact := impacts[0]
		impact.set_process(false)
		impact.call("_process", 0.22)
		_check(not impact.is_queued_for_deletion() and not _sprites(impact, SLAM_ART).is_empty(), "cosmetic terrain fractures remain visible after slam damage has ended")
		tank.call("_apply_enemy_world_stun", 0.01)
		tank.stun_time = 0.0
		_check(not impact.is_queued_for_deletion(), "a brief stun preserves the already released terrain impact")
		get_tree().paused = true
		impact.call("_process", 1.0)
		_check(not impact.is_queued_for_deletion(), "pause preserves the terrain impact's remaining lifetime")
		get_tree().paused = false
		impact.call("_process", 1.0)
		_check(impact.is_queued_for_deletion(), "terrain fractures still have a finite cosmetic lifetime")
	await _clear()
	tank = _spawn(TANK, origin)
	brain = tank.get_node("BossBrain")
	brain.call("_do_shockwave")
	var warnings: Array = brain.get("_warnings")
	var distinct := warnings.size() == 3
	for warning: Node in warnings:
		distinct = distinct and not _sprites(warning, SHOCK_ART).is_empty() and _sprites(warning, SLAM_ART).is_empty()
	_check(distinct, "all three committed shockwave positions show dedicated crackling sprites")
	brain.call("_tick_cast", float(brain.call("_shock_time", 2)) + 0.01)
	var shocks := _circles(&"shock")
	var matching := shocks.size() == 3
	for circle in shocks:
		matching = matching and not _sprites(circle, SHOCK_ART).is_empty()
	_check(matching, "all three real shock damage circles carry their crackling footprint identity")
	impacts = _components(_world, IMPACT_SCRIPT)
	_check(impacts.size() == 3, "shock releases three distinct raster impact components")
	tank.set_meta(&"boss_returning", true)
	for impact in impacts:
		impact.call("_process", 0.0)
	var removed := not impacts.is_empty()
	for impact in impacts:
		removed = removed and impact.is_queued_for_deletion()
	_check(removed, "returning cancels released shock cosmetics together with encounter pressure")
	await _clear()


func _test_mine() -> void:
	var mage := _spawn(MAGE, Vector2(1500, 1100))
	var mine := MINE.instantiate() as BossMine
	mine.setup(Vector2(1810, 1200), mage, 1.05, 95.0, 15.0)
	Scope.bind(mine, mage)
	_world.add_child(mine)
	mine.set_process(false)
	_check(not _sprites(mine, MINE_ART).is_empty(), "planted mine has its own readable occult glyph throughout the fuse")
	_check(_sprites(mine, SLAM_ART).is_empty() and _sprites(mine, SHOCK_ART).is_empty(), "mine glyph remains distinct from physical slam and crackling shock")
	mine.call("_explode")
	var circles := _circles(&"mine")
	_check(circles.size() == 1 and not _sprites(circles[0], MINE_ART).is_empty(), "detonated mine damage keeps its planted-glyph identity")
	var impacts := _components(_world, IMPACT_SCRIPT)
	_check(impacts.size() == 1 and impacts[0].global_position.is_equal_approx(Vector2(1810, 1200)), "mine glyph burst matches its warned origin under a translated scene")
	await _clear()


func _painted_world_bounds(sprite: Sprite2D) -> Rect2:
	var pixels := sprite.texture.get_image()
	var center := Vector2(pixels.get_size()) * 0.5
	var result := Rect2()
	var started := false
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			if pixels.get_pixel(x, y).a <= 0.2:
				continue
			var at := sprite.to_global(Vector2(x + 0.5, y + 0.5) - center)
			result = result.expand(at) if started else Rect2(at, Vector2.ZERO)
			started = true
	return result


func _test_charge_windup() -> void:
	var tank := _spawn(TANK, Vector2(1500, 1100))
	# S5 owns charge selection in its teaching controller; the legacy module
	# deliberately cannot start a second independent rush for this actor.
	tank.get_node("BossBrain").call("_begin_teaching_rush")
	var lanes := _sprites(tank, CHARGE_ART)
	_check(not lanes.is_empty(), "real Bulldozer charge shows authored raster anticipation")
	if not lanes.is_empty():
		var bounds := _painted_world_bounds(lanes[0])
		# The swept body reaches one radius past the centre's 280.8px travel.
		var radius := ((tank.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
		_check(bounds.position.x >= 1496.0 and absf(bounds.end.x - (1780.8 + radius)) <= 4.0, "charge lane depicts the full rush to the body's leading edge (%.1f px) instead of a tiny muzzle fan" % (280.8 + radius))
	var cues := _components(tank, WINDUP_SCRIPT)
	_check(not cues.is_empty(), "charge creates a cancellable windup component attached to the boss")
	tank.call("_apply_enemy_world_stun", 0.01)
	var cancelled := not cues.is_empty()
	for cue in cues:
		cancelled = cancelled and cue.is_queued_for_deletion()
	_check(cancelled, "interrupting charge removes its full lane and braced accent immediately")
	await _clear()


func _test_caster_windup() -> void:
	var mage := _spawn(MAGE, Vector2(1500, 1100))
	var brain := mage.get_node("BossBrain")
	brain.call("_fan_shot")
	var glows := _sprites(mage, CASTER_ART)
	_check(not glows.is_empty(), "fan anticipation visibly charges the Arcanist's hand or staff with detailed sprite art")
	if not glows.is_empty():
		_check(not glows[0].z_as_relative and glows[0].z_index >= 11, "caster windup draws above the actual z10 enemy body renderer")
	var cues := _components(mage, WINDUP_SCRIPT)
	mage.call("_apply_enemy_world_stun", 0.01)
	mage.stun_time = 0.0
	var cancelled := not cues.is_empty()
	for cue in cues:
		cancelled = cancelled and cue.is_queued_for_deletion()
	_check(cancelled, "a brief stun immediately removes the cancelled fan's visible casting cue")
	await get_tree().process_frame
	brain.call("_beam_sweep")
	_check(not _sprites(mage, CASTER_ART).is_empty(), "beam anticipation visibly charges the Arcanist before release")
	brain.call("_cancel_cast")
	await get_tree().process_frame
	brain.call("_drop_mines")
	_check(not _sprites(mage, CASTER_ART).is_empty(), "mine planting has a visible casting accent around the hand or staff")
	await _clear()
