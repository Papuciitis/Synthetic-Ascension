extends Node

# Batched enemy visuals lifecycle: a pooled actor registers with the scene's
# proxy renderer, leaves the registry when it goes back to the pool (so the
# registry tracks the live population, not the pool inventory), and gets its
# own sprite back when batching is off for the scene it is reused in.

const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")

class FakeProxyRoot:
	extends Node2D
	var renderer: Node = null

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


func _run() -> void:
	var previous_flag: bool = Global.debug_enemy_visual_batching
	Global.debug_enemy_visual_batching = true
	var world := WorldScript.new()
	add_child(world)
	var root := FakeProxyRoot.new()
	root.add_to_group(&"enemy_proxy_root")
	var renderer := RendererScript.new()
	renderer.setup(world)
	root.renderer = renderer
	root.add_child(renderer)
	add_child(root)

	var enemy := (load("res://core/actors/enemy/enemy.tscn") as PackedScene).instantiate() as EnemyActor
	enemy.spec = EnemySpec.new()
	add_child(enemy)
	await get_tree().process_frame
	var sprite := enemy.get_node("Sprite2D") as Sprite2D
	_check(renderer.registered_actor_count() == 1, "a live enemy registers with the scene renderer")
	_check(not sprite.visible, "a batched enemy hides its own sprite")

	enemy.call("_on_pool_recycle")
	_check(renderer.registered_actor_count() == 0, "returning to the pool unregisters the actor (registry tracks live enemies, not pool inventory)")

	enemy.call("_reset_for_pool_obtain", false)
	_check(renderer.registered_actor_count() == 1, "re-obtaining from the pool registers again")
	_check(not sprite.visible, "re-obtained batched enemy keeps its sprite hidden")

	# Same node reused in a scene with batching switched off: it must draw
	# itself again instead of staying invisible forever.
	enemy.call("_on_pool_recycle")
	Global.debug_enemy_visual_batching = false
	enemy.call("_reset_for_pool_obtain", false)
	_check(sprite.visible, "an enemy reused with batching disabled shows its own sprite again")
	_check(renderer.registered_actor_count() == 0, "batching disabled leaves the renderer registry empty")

	Global.debug_enemy_visual_batching = previous_flag
	enemy.queue_free()
	root.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyVisualBatchingTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
