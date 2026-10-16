extends Node

const SCOPE = preload("res://scenes/world/bosses/BossAttackScope.gd")
const SHOT = preload("res://core/combat/projectile/EnemyProjectile.tscn")
const TANK = preload("res://scenes/world/bosses/BossBulldozer.tscn")
var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, text: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", text)
	else:
		_failures += 1
		push_error("FAIL: " + text)

func _has_visible_sprite(node: Node) -> bool:
	for child in node.get_children():
		if child is Sprite2D and child.visible and child.texture != null:
			return true
		if _has_visible_sprite(child):
			return true
	return false

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_sprite_vfx_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var source := Node2D.new()
	add_child(source)
	var scope := SCOPE.new()
	source.add_child(scope)
	scope.setup(source)
	var shot := SHOT.instantiate() as EnemyProjectile
	shot.setup(Vector2.RIGHT, 420.0, 7.0, 2.6, source)
	SCOPE.bind(shot, source)
	add_child(shot)
	_check(_has_visible_sprite(shot), "a bound boss projectile displays real raster sprite artwork")
	_check(shot.material == null, "boss projectile artwork keeps normal pixel-art blending")
	shot.queue_free()
	source.queue_free()
	await get_tree().process_frame
	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = Vector2(1600, 1000)
	add_child(player)
	var tank := TANK.instantiate() as EnemyActor
	tank.position = Vector2(1200, 1000)
	add_child(tank)
	tank.set_physics_process(false)
	tank.set_process(false)
	var brain := tank.get_node("BossBrain")
	brain.set_process(false)
	tank._charge._time_left = 0.36
	brain.call("_track_charge", 0.016)
	var trail = brain.get("_trail")
	_check(is_instance_valid(trail), "charge starts an actual trail component")
	if is_instance_valid(trail):
		trail.call("_process", 0.016)
		tank.position += Vector2(30, 0)
		trail.call("_process", 0.016)
		_check(_has_visible_sprite(trail), "charge movement leaves textured sprite segments rather than drawn lines")
		trail.call("stop_and_fade")
		trail.call("_process", 1.0)
		_check(trail.is_queued_for_deletion(), "sprite trail still finishes its finite fade")
	tank.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("BossSpriteVfxTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
