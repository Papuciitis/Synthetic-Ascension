class_name EnemyProxyRoot
extends Node2D

## Wires the proxy vertical slice into a live run: data-only simulation for
## distant ordinary enemies, the budgeted representation manager, and the
## batched proxy renderer. Created by game.gd when Global.enemy_proxy_rollout
## is enabled.

var simulation: EnemyProxySimulation = null
var renderer: EnemyProxyRenderer = null
var manager: EnemyRepresentationManager = null

var _world: EnemyWorldService = null
var _player: Node2D = null
var _flow: FlowFieldNav = null


func _ready() -> void:
	add_to_group(&"enemy_proxy_root")
	_world = get_node_or_null("/root/EnemyWorld") as EnemyWorldService
	var pool := get_node_or_null("/root/PoolManager")
	var index := get_node_or_null("/root/EnemyIndex")
	if _world == null or pool == null or index == null:
		push_warning("EnemyProxyRoot missing autoloads; proxy rollout disabled")
		set_physics_process(false)
		set_process(false)
		return

	simulation = EnemyProxySimulation.new()
	simulation.name = "ProxySimulation"
	add_child(simulation)
	simulation.setup(_world)
	simulation.set_direction_provider(_proxy_direction)

	renderer = EnemyProxyRenderer.new()
	renderer.name = "ProxyRenderer"
	add_child(renderer)
	renderer.setup(_world)

	manager = EnemyRepresentationManager.new()
	manager.name = "RepresentationManager"
	add_child(manager)
	# Materialized actors join the same parent the spawner uses (the run scene).
	manager.setup(_world, pool, index, get_parent())
	manager.enabled = true


func _physics_process(delta: float) -> void:
	if simulation == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var target := _player.global_position if _player != null else Vector2.ZERO
	simulation.advance(delta, target)


# Above this many drawn proxies, visual uploads run every other frame:
# distant swarm sprites at 30Hz are visually indistinguishable, and the
# per-frame buffer build was the measured process-time cost at 400+.
const HALF_RATE_PROXY_THRESHOLD := 300
var _publish_skip := false


func _process(_delta: float) -> void:
	if renderer == null or simulation == null:
		return
	# Batched actor sprites refresh every frame (near-player fidelity); only
	# the offscreen proxy buffers drop to half rate under load.
	var include_proxies := true
	if renderer.visible_count() > HALF_RATE_PROXY_THRESHOLD:
		_publish_skip = not _publish_skip
		include_proxies = not _publish_skip
	else:
		_publish_skip = false
	renderer.publish(
		simulation.interpolation_phase(),
		include_proxies,
		simulation.clock(),
		simulation.update_interval()
	)


func _exit_tree() -> void:
	# Data-only records have no Node to unregister them when the run scene is
	# torn down; release every detached record so menus and the next run start
	# from a clean population.
	var index := get_node_or_null("/root/EnemyIndex")
	if index == null or not index.has_method("detached_handles"):
		return
	for handle in (index.call("detached_handles") as Array):
		index.call("release_detached", int(handle), &"run_teardown")


func _proxy_direction(_handle: int, from_position: Vector2, target_position: Vector2) -> Vector2:
	# Prefer the shared flow field; fall back to direct pursuit exactly like the
	# materialized horde does when the field has no answer.
	if _flow == null or not is_instance_valid(_flow):
		_flow = get_tree().get_first_node_in_group(&"flow_field_nav") as FlowFieldNav
	if _flow != null:
		var flow_direction := _flow.sample_dir_smooth(from_position)
		if flow_direction != Vector2.ZERO:
			return flow_direction
	var offset := target_position - from_position
	return offset.normalized() if offset != Vector2.ZERO else Vector2.ZERO
