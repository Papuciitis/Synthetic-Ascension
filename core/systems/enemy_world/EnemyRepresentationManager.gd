class_name EnemyRepresentationManager
extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const PolicyScript = preload("res://core/systems/enemy_world/EnemyRepresentationPolicy.gd")

@export var enabled := false
@export_range(0.02, 1.0, 0.01) var decision_interval := 0.20

var _world: EnemyWorldService = null
var _pool: Node = null
var _index: Node = null
var _actor_parent: Node = null
var _policy: EnemyRepresentationPolicy = null
var _player: Node2D = null
var _decision_left := 0.0
var _promotions: Array[int] = []
var _demotions: Array[int] = []
var _scene_cache: Dictionary = {}
var _last_policy_counters: Dictionary = {}
var _counters := {
	"promotion_requests": 0,
	"promotions": 0,
	"promotion_failures": 0,
	"demotion_requests": 0,
	"demotions": 0,
	"demotion_failures": 0,
	"last_churn": 0,
}


func setup(
	world: EnemyWorldService,
	pool: Node,
	index: Node,
	actor_parent: Node,
	policy: EnemyRepresentationPolicy = null,
) -> void:
	_world = world
	_pool = pool
	_index = index
	_actor_parent = actor_parent
	_policy = policy if policy != null else PolicyScript.new()
	_decision_left = 0.0


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_decision_left -= maxf(delta, 0.0)
	if _decision_left > 0.0:
		return
	_decision_left = maxf(decision_interval, 0.02)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var player_position := _player.global_position if _player != null else Vector2.ZERO
	step(player_position)


func step(player_position: Vector2) -> Dictionary:
	_counters["last_churn"] = 0
	if not enabled or _world == null or _policy == null:
		return get_debug_counters()
	var policy_counters := _policy.evaluate(_world, player_position, _promotions, _demotions)
	_last_policy_counters = policy_counters
	# Demotions run first so the same step can reuse the released actors.
	for handle in _demotions:
		_counters["demotion_requests"] = int(_counters["demotion_requests"]) + 1
		if dematerialize(handle):
			_counters["demotions"] = int(_counters["demotions"]) + 1
			_counters["last_churn"] = int(_counters["last_churn"]) + 1
		else:
			_counters["demotion_failures"] = int(_counters["demotion_failures"]) + 1
	for handle in _promotions:
		_counters["promotion_requests"] = int(_counters["promotion_requests"]) + 1
		if materialize(handle) != null:
			_counters["promotions"] = int(_counters["promotions"]) + 1
			_counters["last_churn"] = int(_counters["last_churn"]) + 1
		else:
			_counters["promotion_failures"] = int(_counters["promotion_failures"]) + 1
	var result := get_debug_counters()
	result["policy"] = policy_counters
	return result


func dematerialize(handle: int) -> bool:
	if (
		_world == null
		or _pool == null
		or _index == null
		or not _world.is_valid_handle(handle)
		or _world.is_dying(handle)
	):
		return false
	if _policy != null and not _policy.is_proxy_eligible(_world, handle):
		return false
	var actor := _world.actor_for_handle(handle)
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	if not actor.has_method("commit_representation_lease"):
		return false
	if not bool(actor.call("commit_representation_lease", handle)):
		return false
	if not _index.has_method("detach_representation"):
		return false
	if not bool(_index.call("detach_representation", actor, handle)):
		return false
	if actor.has_method("_quiesce_representation_lease"):
		actor.call("_quiesce_representation_lease")
	_pool.call("recycle", actor, {
		"enemy_representation_lease": true,
		"enemy_world_handle": handle,
	})
	return (
		_world.is_valid_handle(handle)
		and _world.get_representation(handle) == Types.Representation.DATA_ONLY
		and _world.actor_for_handle(handle) == null
	)


func materialize(handle: int) -> Node2D:
	if (
		_world == null
		or _pool == null
		or _index == null
		or not _world.is_valid_handle(handle)
		or _world.is_dying(handle)
	):
		return null
	var existing := _world.actor_for_handle(handle)
	if existing != null:
		return existing
	if not _index.has_method("is_detached") or not bool(_index.call("is_detached", handle)):
		return null
	var scene := _scene_for_handle(handle)
	if scene == null:
		return null
	var parent := _actor_parent
	if parent == null or not is_instance_valid(parent):
		parent = get_tree().current_scene
	var node := _pool.call("obtain", scene, parent, {
		"enemy_representation_lease": true,
		"enemy_world_handle": handle,
	}) as Node2D
	if node == null:
		return null
	if _world.actor_for_handle(handle) != node:
		_pool.call("recycle", node, {"enemy_representation_lease": true})
		return null
	return node


func get_debug_counters() -> Dictionary:
	var result := _counters.duplicate(true)
	result["policy"] = _last_policy_counters
	if _world != null and is_instance_valid(_world):
		var world_counters := _world.get_debug_counters()
		result["logical"] = int(world_counters.get("logical", 0))
		result["materialized"] = int(world_counters.get("materialized", 0))
		result["data_only"] = int(world_counters.get("data_only", 0))
	return result


func _scene_for_handle(handle: int) -> PackedScene:
	var path := _world.get_scene_path(handle)
	if path.is_empty():
		return null
	var cached: Variant = _scene_cache.get(path)
	if cached is PackedScene:
		return cached as PackedScene
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var loaded := load(path) as PackedScene
	if loaded != null:
		_scene_cache[path] = loaded
	return loaded
