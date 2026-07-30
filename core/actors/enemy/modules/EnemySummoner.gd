extends RefCounted
class_name EnemySummoner

var _owner: EnemyActor = null
var _cd: float = 0.0

# Hard rules (safe defaults). If you want these configurable later, we can move them into EnemySpec.
const MAX_ALIVE_PER_SUMMONER: int = 6
const SUMMONED_LIFETIME: float = 10.0
const SPAWN_TRIES_PER_MINION: int = 10
const SPAWN_MIN_SEPARATION: float = 22.0

func setup(owner: EnemyActor) -> void:
	_owner = owner
	_cd = Global._rng.randf_range(0.2, 0.7)

func tick(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)

func brain(to_player: Vector2, dist: float, spd: float) -> Vector2:
	if _owner == null or _owner.spec == null:
		return to_player * spd

	var spec: EnemySpec = _owner.spec

	# movement: coward summoner (backs off if you're close)
	var desired: Vector2 = Vector2.ZERO
	if dist < spec.preferred_range:
		desired = -to_player * spd * 0.8
	else:
		desired = to_player * spd * 0.25

	if spec.summon_scene != null and _cd <= 0.0:
		_try_summon_wave()
		_cd = maxf(spec.summon_every, 0.2)

	return desired

func _try_summon_wave() -> void:
	if _owner == null or _owner.spec == null:
		return

	var spec: EnemySpec = _owner.spec
	if spec.summon_scene == null:
		return

	# Per-summoner cap
	var available_for_owner: int = MAX_ALIVE_PER_SUMMONER - _alive_summons_count()
	if available_for_owner <= 0:
		return

	var want: int = mini(available_for_owner, Global._rng.randi_range(spec.summon_count_min, spec.summon_count_max))
	var enemy_index: Node = _owner.get_node_or_null("/root/EnemyIndex")
	var granted: int = want
	if enemy_index != null and enemy_index.has_method("try_reserve_special"):
		granted = int(enemy_index.call("try_reserve_special", &"summon", want))
	for _i in range(granted):
		if not _spawn_one(spec, enemy_index):
			if enemy_index != null and enemy_index.has_method("release_special"):
				enemy_index.call("release_special", &"summon", 1)

func _spawn_one(spec: EnemySpec, enemy_index: Node) -> bool:
	var spawn_point: Vector2 = _pick_spawn_point(spec)
	if spawn_point == Vector2.INF:
		return false
	var m: Node = spec.summon_scene.instantiate()
	if m == null:
		return false
	var spawn_filter := _owner.get_node_or_null("/root/DebugEnemySpawnFilter")
	if spawn_filter != null and spawn_filter.has_method("is_node_enabled"):
		if not bool(spawn_filter.call("is_node_enabled", m)):
			m.free()
			return false

	var m2 := m as Node2D
	if m2 != null:
		m2.global_position = spawn_point

	# Tag summons so we can count them per summoner
	var g := _summon_group()
	m.add_to_group("summoned")
	m.add_to_group(g)

	# Attach lifetime + "die if summoner dies" controller
	var ctrl := EnemySummoned.new()
	ctrl.setup(_owner.get_instance_id(), SUMMONED_LIFETIME)
	m.add_child(ctrl)

	var current_scene: Node = _owner.get_tree().current_scene
	if current_scene == null:
		m.free()
		return false
	if enemy_index != null and enemy_index.has_method("commit_special"):
		enemy_index.call("commit_special", m, &"summon")
	if spawn_filter != null and spawn_filter.has_method("validate_deferred_node"):
		m.tree_entered.connect(Callable(spawn_filter, "validate_deferred_node").bind(m), CONNECT_ONE_SHOT)
	current_scene.call_deferred("add_child", m)
	if spawn_filter != null and spawn_filter.has_method("record_spawn"):
		var spawned_enemy := m as EnemyActor
		spawn_filter.call("record_spawn", StringName(spawned_enemy.spec.id) if spawned_enemy != null and spawned_enemy.spec != null else &"")
	return true

func _pick_spawn_point(spec: EnemySpec) -> Vector2:
	var origin: Vector2 = _owner.global_position
	var r: float = maxf(8.0, spec.summon_radius)

	for _i in range(SPAWN_TRIES_PER_MINION):
		var ang: float = Global._rng.randf() * TAU
		var rr: float = Global._rng.randf_range(0.55, 1.0) * r
		var cand: Vector2 = origin + Vector2.RIGHT.rotated(ang) * rr

		# If EnemyActor exposes point_blocked() helper, use it (your enemy.gd does)
		if _owner.has_method("point_blocked") and _owner.call("point_blocked", cand):
			continue

		# Also avoid stacking on top of the summoner
		if cand.distance_to(origin) < SPAWN_MIN_SEPARATION:
			continue

		return cand

	return Vector2.INF

func _alive_summons_count() -> int:
	if _owner == null:
		return 0
	var nodes := _owner.get_tree().get_nodes_in_group(_summon_group())
	var alive: int = 0
	for n in nodes:
		if n != null and is_instance_valid(n):
			alive += 1
	return alive

func _summon_group() -> String:
	# stable group name per summoner instance
	return "summoned_by_%s" % str(_owner.get_instance_id())
