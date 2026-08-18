extends Node

# Central registry + lightweight spatial hashing for enemies.
# Goal: avoid repeated get_nodes_in_group("enemies") scans in hot paths.

@export var cell_size: float = 64.0

@export_group("Special Population Budget")
@export var special_population_cap: int = 72
@export var summoned_population_cap: int = 36
@export var split_population_cap: int = 48
@export var boss_add_population_cap: int = 24

# Internal storage (do not modify returned arrays from outside)
var _enemies: Array = [] # Array[Enemy]
var _id_to_index: Dictionary = {} # int -> int
var _enemy_cell: Dictionary = {}  # int -> Vector2i
var _buckets: Dictionary = {}     # Vector2i -> Array[Enemy]
var _scene_counts: Dictionary = {} # String -> int
var _population_counted: Dictionary = {} # int -> bool
var _ambient_count: int = 0
var _ambient_scene_counts: Dictionary = {} # String -> int
var _special_alive_total: int = 0
var _special_alive_by_kind: Dictionary = {} # StringName -> int
var _special_reserved_total: int = 0
var _special_reserved_by_kind: Dictionary = {}
var _retired_counts: Dictionary = {}
var _elite_ids: Dictionary = {} # int -> true, for live (counted) elites
var _suppress_register_events: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)

func register(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _id_to_index.has(id):
		return

	_id_to_index[id] = _enemies.size()
	_enemies.append(enemy)

	# Population counts are maintained incrementally so spawn-cap checks stay O(1).
	# Dead nodes can briefly survive until queue_free; keep them indexed for safe
	# cleanup, but never re-add them to an alive population during a rebuild.
	var p: String = enemy.scene_file_path
	var should_count: bool = not _is_enemy_dead(enemy)
	_population_counted[id] = should_count
	if should_count:
		if p != "":
			_scene_counts[p] = int(_scene_counts.get(p, 0)) + 1
		_register_population_class(enemy, p)
		if _is_enemy_elite(enemy):
			_elite_ids[id] = true

	var cell := _cell_for_pos((enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO)
	_enemy_cell[id] = cell
	_bucket_add(cell, enemy)
	# The event payload builds four Strings; only pay for it when the recorder is
	# actually armed, and never for prune_invalid's silent re-registration.
	if (
		PerformanceFlightRecorder != null
		and not _suppress_register_events
		and bool(PerformanceFlightRecorder.get("enabled"))
	):
		var enemy_id := enemy.scene_file_path.get_file().get_basename().trim_prefix("Enemy").to_snake_case()
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"spawned", 1, {
			"enemy_id": enemy_id,
			"elite": _is_enemy_elite(enemy),
			"kind": String(enemy.get_meta("special_spawn_kind", &"")),
		})

func unregister(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return

	# Population counts
	var p: String = enemy.scene_file_path
	if bool(_population_counted.get(id, false)):
		_decrement_counter(_scene_counts, p)
		_unregister_population_class(enemy, p)
	_population_counted.erase(id)
	_elite_ids.erase(id)

	# buckets
	if _enemy_cell.has(id):
		var cell: Vector2i = _enemy_cell[id]
		_bucket_remove(cell, enemy)
		_enemy_cell.erase(id)

	# swap-remove from list
	var idx: int = int(_id_to_index[id])
	var last_idx: int = _enemies.size() - 1
	if idx != last_idx:
		var last_enemy: Node = _enemies[last_idx]
		_enemies[idx] = last_enemy
		_id_to_index[last_enemy.get_instance_id()] = idx
	_enemies.pop_back()
	_id_to_index.erase(id)

func mark_dead(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id: int = int(enemy.get_instance_id())
	if not _id_to_index.has(id) or not bool(_population_counted.get(id, false)):
		return
	var scene_path: String = enemy.scene_file_path
	_decrement_counter(_scene_counts, scene_path)
	_unregister_population_class(enemy, scene_path)
	_population_counted[id] = false
	_elite_ids.erase(id)
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"died", 1)


func retire_enemy(enemy: Node, reason: StringName = &"unknown") -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id) or enemy.is_queued_for_deletion():
		return false
	unregister(enemy)
	_retired_counts[reason] = int(_retired_counts.get(reason, 0)) + 1
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"retired", 1, {"reason": String(reason)})
	enemy.set_meta("culled", true)
	enemy.set_meta("cull_reason", reason)
	if enemy.has_method("despawn"):
		enemy.call("despawn", reason)
	else:
		enemy.queue_free()
	return true


func update_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return
	if not (enemy is Node2D):
		return
	var new_cell := _cell_for_pos((enemy as Node2D).global_position)
	var old_cell: Vector2i = _enemy_cell.get(id, new_cell)
	if new_cell == old_cell:
		return
	_enemy_cell[id] = new_cell
	_bucket_remove(old_cell, enemy)
	_bucket_add(new_cell, enemy)

func alive_count() -> int:
	return _enemies.size()


func simulation_tier_counts() -> Dictionary:
	var counts := {"near": 0, "mid": 0, "far": 0}
	for enemy_variant in _enemies:
		var enemy := enemy_variant as Node
		if (
			enemy == null
			or not is_instance_valid(enemy)
			or enemy.is_queued_for_deletion()
			or ("dead" in enemy and bool(enemy.get("dead")))
			or not enemy.has_method("simulation_tier")
		):
			continue
		var tier := int(enemy.call("simulation_tier"))
		var key := "near" if tier <= 0 else ("mid" if tier == 1 else "far")
		counts[key] = int(counts[key]) + 1
	return counts


func get_debug_counters() -> Dictionary:
	return {
		"indexed": _enemies.size(),
		"ambient": _ambient_count,
		"special": _special_alive_total,
		"special_by_kind": _special_alive_by_kind.duplicate(),
		"reserved": _special_reserved_total,
		"retired": _retired_counts.duplicate(),
		"tiers": simulation_tier_counts(),
		"buckets": _buckets.size(),
	}

func prune_invalid() -> int:
	# Rebuild the compact indexes when freed/queued nodes survive a missed unregister.
	# This is intentionally a maintenance operation, not something called in hot paths.
	var previous_count: int = _enemies.size()
	var valid_enemies: Array = []
	var seen_ids: Dictionary = {}
	for enemy_variant in _enemies:
		var enemy := enemy_variant as Node
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
			continue
		var enemy_id: int = int(enemy.get_instance_id())
		if seen_ids.has(enemy_id):
			continue
		seen_ids[enemy_id] = true
		valid_enemies.append(enemy)

	if valid_enemies.size() == previous_count:
		return 0

	_enemies.clear()
	_id_to_index.clear()
	_enemy_cell.clear()
	_buckets.clear()
	_scene_counts.clear()
	_population_counted.clear()
	_ambient_count = 0
	_ambient_scene_counts.clear()
	_special_alive_total = 0
	_special_alive_by_kind.clear()
	_elite_ids.clear()
	# Rebuilding is maintenance, not gameplay: re-registration must not emit
	# phantom "spawned" telemetry for enemies that already existed.
	_suppress_register_events = true
	for enemy_variant in valid_enemies:
		register(enemy_variant as Node)
	_suppress_register_events = false
	return previous_count - valid_enemies.size()


func ambient_alive_count() -> int:
	return _ambient_count


func elite_alive_count() -> int:
	return _elite_ids.size()


func note_elite(enemy: Node) -> void:
	# Called by EnemyActor.make_elite so promotions keep the live count exact.
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _id_to_index.has(id) and bool(_population_counted.get(id, false)):
		_elite_ids[id] = true


func try_reserve_special(kind: StringName, requested: int) -> int:
	if requested <= 0:
		return 0
	var kind_cap: int = _special_kind_cap(kind)
	var total_remaining: int = maxi(0, special_population_cap - _special_alive_count(&"") - _special_reserved_total)
	var kind_reserved: int = int(_special_reserved_by_kind.get(kind, 0))
	var kind_remaining: int = maxi(0, kind_cap - _special_alive_count(kind) - kind_reserved)
	var granted: int = mini(requested, mini(total_remaining, kind_remaining))
	if granted <= 0:
		return 0
	_special_reserved_total += granted
	_special_reserved_by_kind[kind] = kind_reserved + granted
	return granted


func commit_special(enemy: Node, kind: StringName) -> void:
	if enemy == null:
		release_special(kind, 1)
		return
	var old_kind: StringName = enemy.get_meta("special_spawn_kind", &"") as StringName
	enemy.set_meta("special_spawn_kind", kind)
	enemy.add_to_group(StringName("special_spawn_%s" % String(kind)))
	# Most special enemies are tagged before entering the tree. Handle the rarer
	# already-registered case too so the O(1) counters never drift.
	var enemy_id: int = int(enemy.get_instance_id())
	if _id_to_index.has(enemy_id) and bool(_population_counted.get(enemy_id, false)) and old_kind != kind:
		_reclassify_registered_enemy(enemy, old_kind, kind)
	if enemy.is_inside_tree():
		release_special(kind, 1)
	else:
		enemy.tree_entered.connect(Callable(self, "release_special").bind(kind, 1), CONNECT_ONE_SHOT)


func release_special(kind: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var reserved: int = int(_special_reserved_by_kind.get(kind, 0))
	var released: int = mini(amount, reserved)
	if released <= 0:
		return
	_special_reserved_total = maxi(0, _special_reserved_total - released)
	reserved -= released
	if reserved <= 0:
		_special_reserved_by_kind.erase(kind)
	else:
		_special_reserved_by_kind[kind] = reserved


func _special_alive_count(kind: StringName) -> int:
	if kind == &"":
		return _special_alive_total
	return int(_special_alive_by_kind.get(kind, 0))


func _special_kind_cap(kind: StringName) -> int:
	match kind:
		&"summon":
			return summoned_population_cap
		&"split":
			return split_population_cap
		&"boss_add":
			return boss_add_population_cap
		_:
			return special_population_cap

func alive_count_for_scene(scene: PackedScene) -> int:
	if scene == null:
		return 0
	var p := scene.resource_path
	if p == "":
		return 0
	return int(_scene_counts.get(p, 0))


func ambient_alive_count_for_scene(scene: PackedScene) -> int:
	if scene == null:
		return 0
	var path: String = scene.resource_path
	if path == "":
		return 0
	return int(_ambient_scene_counts.get(path, 0))


func _is_enemy_dead(enemy: Node) -> bool:
	return "dead" in enemy and bool(enemy.get("dead"))


func _is_enemy_elite(enemy: Node) -> bool:
	return "is_elite" in enemy and bool(enemy.get("is_elite"))


func _register_population_class(enemy: Node, scene_path: String) -> void:
	var kind: StringName = enemy.get_meta("special_spawn_kind", &"") as StringName
	if kind == &"":
		_ambient_count += 1
		if scene_path != "":
			_ambient_scene_counts[scene_path] = int(_ambient_scene_counts.get(scene_path, 0)) + 1
		return
	_special_alive_total += 1
	_special_alive_by_kind[kind] = int(_special_alive_by_kind.get(kind, 0)) + 1


func _unregister_population_class(enemy: Node, scene_path: String) -> void:
	var kind: StringName = enemy.get_meta("special_spawn_kind", &"") as StringName
	if kind == &"":
		_ambient_count = maxi(0, _ambient_count - 1)
		_decrement_counter(_ambient_scene_counts, scene_path)
		return
	_special_alive_total = maxi(0, _special_alive_total - 1)
	_decrement_counter(_special_alive_by_kind, kind)


func _reclassify_registered_enemy(enemy: Node, old_kind: StringName, new_kind: StringName) -> void:
	var scene_path: String = enemy.scene_file_path
	if old_kind == &"":
		_ambient_count = maxi(0, _ambient_count - 1)
		_decrement_counter(_ambient_scene_counts, scene_path)
	else:
		_special_alive_total = maxi(0, _special_alive_total - 1)
		_decrement_counter(_special_alive_by_kind, old_kind)
	if new_kind == &"":
		_ambient_count += 1
		if scene_path != "":
			_ambient_scene_counts[scene_path] = int(_ambient_scene_counts.get(scene_path, 0)) + 1
	else:
		_special_alive_total += 1
		_special_alive_by_kind[new_kind] = int(_special_alive_by_kind.get(new_kind, 0)) + 1


func _decrement_counter(counter: Dictionary, key: Variant) -> void:
	if key == null or not counter.has(key):
		return
	var value: int = int(counter[key]) - 1
	if value <= 0:
		counter.erase(key)
	else:
		counter[key] = value

func get_all() -> Array:
	# WARNING: do not mutate the returned array.
	return _enemies

func nearest_enemy(origin: Vector2, max_dist: float = 999999.0, exclude: Node = null) -> Node2D:
	var best: Node2D = null
	var best_d2: float = max_dist * max_dist

	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(max_dist / cs))

	# Huge radii would probe (2cr+1)^2 mostly-empty cells; once the window
	# exceeds the occupied bucket count, walking the buckets directly is
	# strictly cheaper and gives identical results.
	if (2 * cr + 1) * (2 * cr + 1) > _buckets.size():
		for arr_variant in _buckets.values():
			for n in arr_variant:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				var d2 := origin.distance_squared_to(e.global_position)
				if d2 < best_d2:
					best_d2 = d2
					best = e
		return best

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				var d2 := origin.distance_squared_to(e.global_position)
				if d2 < best_d2:
					best_d2 = d2
					best = e

	return best

func first_in_radius(origin: Vector2, radius: float, exclude: Node = null) -> Node2D:
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	if (2 * cr + 1) * (2 * cr + 1) > _buckets.size():
		for arr_variant in _buckets.values():
			for n in arr_variant:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					return e
		return null

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					return e
	return null

func gather_in_radius(origin: Vector2, radius: float, out: Array) -> void:
	if out == null:
		return
	out.clear()

	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	if (2 * cr + 1) * (2 * cr + 1) > _buckets.size():
		for arr_variant in _buckets.values():
			for n in arr_variant:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					out.append(e)
		return

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					out.append(e)

func sample_sep(e: Node2D, radius: float, max_neighbors: int = 8) -> Vector2:
	if e == null or not is_instance_valid(e):
		return Vector2.ZERO
	if radius <= 0.0:
		return Vector2.ZERO

	var pos: Vector2 = e.global_position
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(pos.x / cs), floori(pos.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	if (2 * cr + 1) * (2 * cr + 1) > _buckets.size():
		for arr_variant in _buckets.values():
			for n in arr_variant:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				var d: Vector2 = pos - other.global_position
				var d2: float = d.length_squared()
				if d2 <= 0.0001 or d2 > r2:
					continue
				sum += d / d2
				count += 1
				if count >= max_neighbors:
					break
			if count >= max_neighbors:
				break
		return (sum.normalized() if sum.length_squared() > 0.0001 else Vector2.ZERO)

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				var d: Vector2 = pos - other.global_position
				var d2: float = d.length_squared()
				if d2 <= 0.0001 or d2 > r2:
					continue
				sum += d / d2
				count += 1
				if count >= max_neighbors:
					break
			if count >= max_neighbors:
				break
		if count >= max_neighbors:
			break

	return (sum.normalized() if sum.length_squared() > 0.0001 else Vector2.ZERO)

func count_allies(e: Node2D, radius: float, max_count: int = 999) -> int:
	if e == null or not is_instance_valid(e):
		return 0
	if radius <= 0.0:
		return 0

	var pos: Vector2 = e.global_position
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(pos.x / cs), floori(pos.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	var count: int = 0

	if (2 * cr + 1) * (2 * cr + 1) > _buckets.size():
		for arr_variant in _buckets.values():
			for n in arr_variant:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				if pos.distance_squared_to(other.global_position) > r2:
					continue
				count += 1
				if count >= max_count:
					return count
		return count

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				if pos.distance_squared_to(other.global_position) > r2:
					continue
				count += 1
				if count >= max_count:
					return count
	return count

func _cell_for_pos(pos: Vector2) -> Vector2i:
	var cs := maxf(cell_size, 1.0)
	return Vector2i(floori(pos.x / cs), floori(pos.y / cs))

func _bucket_add(cell: Vector2i, enemy: Node) -> void:
	var arr = _buckets.get(cell)
	if arr == null:
		arr = []
		_buckets[cell] = arr
	arr.append(enemy)

func _bucket_remove(cell: Vector2i, enemy: Node) -> void:
	var arr = _buckets.get(cell)
	if arr == null:
		return
	# Swap-remove: order inside a bucket is irrelevant, and erase() would shift
	# every trailing element on each cell crossing.
	var idx: int = arr.find(enemy)
	if idx < 0:
		return
	var last: int = arr.size() - 1
	if idx != last:
		arr[idx] = arr[last]
	arr.pop_back()
	if arr.is_empty():
		_buckets.erase(cell)
