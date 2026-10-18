extends Node
## Owns one boss's temporary pressure without owning its rewards or health.

signal cast_interrupted

const SCOPE_META := &"boss_attack_scope"
const GENERATION_META := &"boss_attack_generation"
var generation: int = 0
var cast_epoch: int = 0
var _actor: WeakRef
var _members: Dictionary = {}
var _was_available := true
var _was_stunned := false

func setup(actor: Node2D) -> void:
	_actor = weakref(actor)
	actor.set_meta(SCOPE_META, weakref(self))
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -100
	actor.tree_exiting.connect(cancel)
	var events := get_node_or_null("/root/RunEvents")
	if events != null:
		events.enemy_killed.connect(_on_enemy_killed)

static func bind(node: Node, source: Node) -> void:
	if not is_instance_valid(source) or not source.has_meta(SCOPE_META):
		return
	var ref := source.get_meta(SCOPE_META) as WeakRef
	var scope = ref.get_ref() if ref != null else null
	if not is_instance_valid(scope):
		return
	node.set_meta(SCOPE_META, weakref(scope))
	node.set_meta(GENERATION_META, scope.generation)
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	scope._members[node.get_instance_id()] = weakref(node)

static func is_valid_attack(node: Node) -> bool:
	if not node.has_meta(SCOPE_META):
		return true
	var ref := node.get_meta(SCOPE_META) as WeakRef
	var scope = ref.get_ref() if ref != null else null
	return is_instance_valid(scope) and int(node.get_meta(GENERATION_META, -1)) == scope.generation and scope.owner_available()

## The boss's projectiles still in the air: its own and its pylons'.
func projectiles_in_flight() -> Array[EnemyProjectile]:
	var live: Array[EnemyProjectile] = []
	for ref: WeakRef in _members.values():
		var node := ref.get_ref() as EnemyProjectile
		if node != null and node.is_inside_tree() and not node.is_queued_for_deletion() and is_valid_attack(node):
			live.append(node)
	return live

func owner_available() -> bool:
	var actor = _actor.get_ref() if _actor != null else null
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if ("dead" in actor and bool(actor.get("dead"))) or bool(actor.get_meta(&"boss_returning", false)):
		return false
	# The actor updates its cached return flag after charge movement. Check the
	# actual boundary too, so a pending cast cannot escape during that interval.
	if actor.has_meta(&"boss_home_pos"):
		var home: Vector2 = actor.get_meta(&"boss_home_pos")
		var leash := float(actor.get_meta(&"boss_leash_radius", 900.0))
		if actor.global_position.distance_to(home) > leash:
			return false
		var player = actor.get("player") if "player" in actor else null
		if is_instance_valid(player) and player.global_position.distance_to(home) > float(actor.get_meta(&"boss_disengage_radius", leash * 1.25)):
			return false
	return true

func is_active() -> bool:
	if not owner_available():
		return false
	var actor = _actor.get_ref()
	return not ("stun_time" in actor and float(actor.get("stun_time")) > 0.0)

func owns_actor(actor: Node) -> bool:
	return _actor != null and _actor.get_ref() == actor

func _process(_delta: float) -> void:
	var available := owner_available()
	if not available and _was_available:
		cancel()
	_was_available = available
	var actor = _actor.get_ref() if _actor != null else null
	var stunned: bool = is_instance_valid(actor) and "stun_time" in actor and float(actor.get("stun_time")) > 0.0
	if stunned and not _was_stunned:
		interrupt_cast()
	_was_stunned = stunned
	# Expired projectiles must not accumulate weak references over a long fight.
	for id in _members.keys():
		if not is_instance_valid((_members[id] as WeakRef).get_ref()):
			_members.erase(id)

func interrupt_cast() -> void:
	cast_epoch += 1
	cast_interrupted.emit()

func cancel() -> void:
	generation += 1
	interrupt_cast()
	var members := _members.values()
	_members.clear()
	for ref: WeakRef in members:
		var node = ref.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node.has_method("cancel_attack"):
			node.call("cancel_attack")
		elif node.has_method("despawn"):
			node.call("despawn", &"boss_cleanup")
		else:
			node.queue_free()

func _on_enemy_killed(_who: Node, enemy: Node, _position: Vector2) -> void:
	if _actor != null and enemy == _actor.get_ref():
		cancel()

func _exit_tree() -> void:
	cancel()
