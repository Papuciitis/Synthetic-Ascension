extends Node
## Real player, boss and wall physics. The grid deliberately marks the
## player's resting cell blocked, as production court cells do beside walls.
const PLAYER := preload("res://core/actors/player/player.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const Placement := preload("res://scenes/world/bosses/BossTeachingPlacement.gd")
var _passes := 0
var _failures := 0
var _world: Node2D
var _player: CharacterBody2D
var _mage: EnemyActor
var _brain: Node
var _grid: RestingGrid

class RestingGrid extends Node:
	var built := true
	func world_to_cell(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / 64.0), floori(point.y / 64.0))
	func has_built_cell(_cell: Vector2i) -> bool:
		return built
	func is_cell_walkable(cell: Vector2i) -> bool:
		return built and cell.x > 23

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _fixture(main: bool, world_seed: int) -> void:
	Global.attempt_world_seed = world_seed
	_world = Node2D.new()
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_grid = RestingGrid.new()
	_grid.add_to_group(&"chunk_manager")
	_world.add_child(_grid)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(1435, 1100)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80, 1400)
	collider.shape = rectangle
	wall.add_child(collider)
	_world.add_child(wall)
	_player = PLAYER.instantiate()
	_world.add_child(_player)
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.position = Vector2(1500, 1100) # Body touches the wall at x1475.
	_player.rotation = 0.0
	_player.velocity = Vector2.ZERO
	_mage = MAGE.instantiate()
	_mage.add_to_group(&"boss" if main else &"miniboss")
	_mage.add_to_group(&"boss_like")
	_mage.position = Vector2(1800, 1100)
	_mage.set_meta(&"boss_home_pos", _mage.position)
	_mage.set_meta(&"boss_leash_radius", 900.0)
	_world.add_child(_mage)
	_mage.player = _player
	_mage.set_process(false)
	_mage.set_physics_process(false)
	_brain = _mage.get_node("BossBrain")
	_brain.set_process(false)
	_brain.set_physics_process(false)
	_brain.call("_ensure_teaching")
	await get_tree().physics_frame
	await get_tree().physics_frame

func _clear() -> void:
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _route_obstacle(at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = at
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70, 125)
	collider.shape = rectangle
	wall.add_child(collider)
	_world.add_child(wall)
	return wall

func _test_aperture() -> void:
	await _fixture(false, 18102026)
	var upper := _route_obstacle(Vector2(1595, 1012.5))
	var lower := _route_obstacle(Vector2(1595, 1187.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var end := _player.global_position + Vector2(195, 0)
	_check(_player.test_move(_player.global_transform, Vector2(195, 0)), "fixture: the real 58px capsule cannot cross a later 50px aperture")
	_check(not Placement.player_route_clear(_mage, _player, _player.global_position, end), "the advertised route refuses a gap the physical capsule cannot pass")
	upper.position.y -= 5.0
	lower.position.y += 5.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not _player.test_move(_player.global_transform, Vector2(195, 0)), "fixture: widening the aperture to60px admits the actual capsule")
	_check(Placement.player_route_clear(_mage, _player, _player.global_position, end), "a 60px opening remains a usable advertised route")
	await _clear()

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	Global.debug_disable_autosave = true
	await _test_aperture()
	for main in [false, true]:
		for world_seed in [16102026, 16102027, 18102026]:
			await _fixture(main, world_seed)
			var count := 4 if main else 3
			var started := bool(_brain.call("_start_teaching_mines", count))
			_check(started, "S%d seed%d mines can commit beside a real wall without requiring space behind it" % [10 if main else 5, world_seed])
			var points: PackedVector2Array = _brain.get("_teaching_mine_points")
			var safe_points := points.size() == count
			for point in points:
				safe_points = safe_points and point.x > 1570.0 and point.distance_to(_player.global_position) > 150.0
			_check(safe_points, "the finite mine arc stays fully inside the court and clear of the player's full Hurtbox")
			await _clear()
			await _fixture(main, world_seed)
			_check(bool(_brain.call("_start_teaching_blink")), "S%d seed%d blink keeps a valid announced landing when the player rests at a wall" % [10 if main else 5, world_seed])
			var destination: Vector2 = _brain.get("_teaching_destination")
			_check(destination.x > 1540.0, "the announced blink destination stays on the open side of the wall")
			await _clear()
	await _fixture(false, 18102026)
	_grid.built = false
	_check(not bool(_brain.call("_start_teaching_mines", 3)) and not bool(_brain.call("_start_teaching_blink")), "neither attack certifies a route through unloaded ground")
	await _clear()
	print("BossWallPlacementTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
