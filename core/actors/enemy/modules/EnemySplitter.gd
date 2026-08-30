extends RefCounted
class_name EnemySplitter

var _owner: EnemyActor = null

func setup(owner: EnemyActor) -> void:
	_owner = owner

func spawn_splitters(is_elite: bool) -> Array[EnemyActor]:
	var spawned_children: Array[EnemyActor] = []
	if _owner == null or _owner.spec == null:
		return spawned_children

	var spec: EnemySpec = _owner.spec
	var generation: int = maxi(0, int(_owner.get_meta("split_generation", 0)))
	var max_generation: int = maxi(0, spec.split_max_generation + (spec.split_elite_extra_generations if is_elite else 0))
	if generation >= max_generation:
		return spawned_children

	var child_scene: PackedScene = _resolve_child_scene(spec)
	if child_scene == null:
		return spawned_children

	var count_min: int = spec.split_count_min
	var count_max: int = spec.split_count_max
	if not is_elite and generation > 0:
		count_min = spec.split_second_count_min
		count_max = spec.split_second_count_max
	var amount_low: int = mini(maxi(1, count_min), maxi(1, count_max))
	var amount_high: int = maxi(maxi(1, count_min), maxi(1, count_max))
	var wanted: int = Global._rng.randi_range(amount_low, amount_high)
	return _spawn_children(child_scene, wanted, generation, spec.split_inherit_elite and is_elite, {})


## Roadmap §9 SPLITTING: an elite of a non-splitting archetype leaves `count`
## smaller non-elite copies behind, through the same reservation, placement
## and spawn path as the Splitter. The copies carry `elite_split_child` so
## EnemyInit shrinks them; they never split again - not elite, not splitters.
func spawn_modifier_split(count: int) -> Array[EnemyActor]:
	var spawned_children: Array[EnemyActor] = []
	if _owner == null or _owner.spec == null or count <= 0:
		return spawned_children
	var child_scene: PackedScene = _resolve_child_scene(_owner.spec)
	if child_scene == null:
		return spawned_children
	var generation: int = maxi(0, int(_owner.get_meta("split_generation", 0)))
	return _spawn_children(child_scene, count, generation, false, {&"elite_split_child": true})


func _spawn_children(
	child_scene: PackedScene,
	wanted: int,
	generation: int,
	inherit_elite: bool,
	extra_meta: Dictionary,
) -> Array[EnemyActor]:
	var spawned_children: Array[EnemyActor] = []
	var enemy_index: Node = _owner.get_node_or_null("/root/EnemyIndex")
	var granted: int = wanted
	if enemy_index != null and enemy_index.has_method("try_reserve_special"):
		granted = int(enemy_index.call("try_reserve_special", &"split", wanted))

	for child_index in range(granted):
		var child_position: Vector2 = _pick_child_position(child_index, granted)
		if child_position == Vector2.INF:
			_release_reservation(enemy_index)
			continue
		var child_node: Node = child_scene.instantiate()
		if child_node == null or not (child_node is EnemyActor):
			if child_node != null:
				child_node.free()
			_release_reservation(enemy_index)
			continue

		var child := child_node as EnemyActor
		var spawn_filter := _owner.get_node_or_null("/root/DebugEnemySpawnFilter")
		if spawn_filter != null and spawn_filter.has_method("is_node_enabled"):
			if not bool(spawn_filter.call("is_node_enabled", child)):
				child.free()
				_release_reservation(enemy_index)
				continue
		child.set_meta("split_generation", generation + 1)
		child.set_meta("split_root_id", int(_owner.get_meta("split_root_id", _owner.get_instance_id())))
		for key in extra_meta:
			child.set_meta(key, extra_meta[key])
		child.add_to_group("splitter_spawned")
		child.global_position = child_position

		var current_scene: Node = _owner.get_tree().current_scene
		if current_scene == null:
			child.free()
			_release_reservation(enemy_index)
			continue
		if enemy_index != null and enemy_index.has_method("commit_special"):
			enemy_index.call("commit_special", child, &"split")
		if spawn_filter != null and spawn_filter.has_method("validate_deferred_node"):
			child.tree_entered.connect(Callable(spawn_filter, "validate_deferred_node").bind(child), CONNECT_ONE_SHOT)
		current_scene.call_deferred("add_child", child)
		if spawn_filter != null and spawn_filter.has_method("record_spawn") and child.spec != null:
			spawn_filter.call("record_spawn", StringName(child.spec.id))
		spawned_children.append(child)

		if inherit_elite and child.has_method("make_elite"):
			child.call_deferred("make_elite")

	return spawned_children


func _resolve_child_scene(spec: EnemySpec) -> PackedScene:
	if spec.split_scene != null:
		return spec.split_scene
	var scene_path: String = _owner.scene_file_path
	if scene_path == "":
		return null
	var resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
	return resource as PackedScene


func _pick_child_position(child_index: int, child_count: int) -> Vector2:
	var origin: Vector2 = _owner.global_position
	var cm: Node = _owner.get_tree().get_first_node_in_group("chunk_manager")
	for attempt in range(8):
		var angle: float = TAU * float(child_index) / float(maxi(1, child_count))
		angle += float(attempt) * 0.47 + Global._rng.randf_range(-0.10, 0.10)
		var radius: float = 24.0 + float(attempt) * 8.0
		var candidate: Vector2 = origin + Vector2.RIGHT.rotated(angle) * radius
		if _owner.has_method("point_blocked") and bool(_owner.call("point_blocked", candidate)):
			continue
		if cm != null and cm.has_method("world_to_cell") and cm.has_method("is_cell_walkable"):
			var cell: Vector2i = cm.call("world_to_cell", candidate) as Vector2i
			if not bool(cm.call("is_cell_walkable", cell)):
				continue
		return candidate
	return Vector2.INF


func _release_reservation(enemy_index: Node) -> void:
	if enemy_index != null and enemy_index.has_method("release_special"):
		enemy_index.call("release_special", &"split", 1)
