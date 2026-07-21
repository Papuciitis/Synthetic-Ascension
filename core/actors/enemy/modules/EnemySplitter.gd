extends RefCounted
class_name EnemySplitter

var _owner: Enemy = null

func setup(owner: Enemy) -> void:
	_owner = owner

func spawn_splitters(is_elite: bool) -> void:
	if _owner == null or _owner.spec == null:
		return

	var spec: EnemySpec = _owner.spec
	if spec.split_scene == null:
		return

	var n: int = Global._rng.randi_range(spec.split_count_min, spec.split_count_max)
	for _i in range(n):
		var s: Node = spec.split_scene.instantiate()
		if s == null:
			continue

		var s2: Node2D = s as Node2D
		if s2 != null:
			var d: Vector2 = Vector2.RIGHT.rotated(Global._rng.randf() * TAU)
			s2.global_position = _owner.global_position + d * 18.0

		_owner.get_tree().current_scene.call_deferred("add_child", s)

		if spec.split_inherit_elite and is_elite and s.has_method("make_elite"):
			s.call("make_elite")
