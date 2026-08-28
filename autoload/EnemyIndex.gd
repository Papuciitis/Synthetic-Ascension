extends Node

# Central registry + lightweight spatial hashing for enemies.
# Goal: avoid repeated get_nodes_in_group("enemies") scans in hot paths.

@export var cell_size: float = 64.0

@export_group("Special Population Budget")
@export var special_population_cap: int = 72
@export var summoned_population_cap: int = 36
@export var split_population_cap: int = 48
@export var boss_add_population_cap: int = 24
@export var beat_population_cap: int = 24

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
var _detached_records: Dictionary = {} # enemy handle -> logical accounting snapshot
var _detached_elite_handles: Dictionary = {} # enemy handle -> true
var _world_handles: Dictionary = {} # materialized instance id -> enemy handle
var _accounting_by_id: Dictionary = {} # materialized instance id -> snapshot
var _suppress_register_events: bool = false
var _world_mirror_failures: int = 0

const LIFECYCLE_REVERSAL_WINDOW_USEC := 2_000_000

var _lifecycle_counters := {
	"attached": 0,
	"detached": 0,
	"retired": 0,
	"representation_reversals": 0,
	"tier_reversals": 0,
	"reversals": 0,
	
	"tier_changes": 0,

	"full_to_mid": 0,
	"mid_to_full": 0,
	"mid_to_far": 0,
	"far_to_mid": 0,
	"full_to_far": 0,
	"far_to_full": 0,

	"attach_total_usec": 0,
	"attach_max_usec": 0,

	"detach_total_usec": 0,
	"detach_max_usec": 0,

	"retire_total_usec": 0,
	"retire_max_usec": 0,
}

# handle -> {
#     "kind": StringName,
#     "t_usec": int,
# }
var _lifecycle_last_rep_transition: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)


func _exit_tree() -> void:
	# Shutdown-order hazard mitigation: drop node references and accounting
	# graphs before script teardown walks them.
	_enemies.clear()
	_id_to_index.clear()
	_enemy_cell.clear()
	_buckets.clear()
	_world_handles.clear()
	_accounting_by_id.clear()
	_detached_records.clear()
	_detached_elite_handles.clear()
	_lifecycle_last_rep_transition.clear()

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
	_accounting_by_id[id] = _snapshot_from_enemy(enemy, p, should_count)
	if should_count:
		if p != "":
			_scene_counts[p] = int(_scene_counts.get(p, 0)) + 1
		_register_population_class(enemy, p)
		if _is_enemy_elite(enemy):
			_elite_ids[id] = true

	var cell := _cell_for_pos((enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO)
	_enemy_cell[id] = cell
	_bucket_add(cell, enemy)
	if enemy is Node2D:
		var world_handle := EnemyWorld.adopt_legacy_actor(enemy as Node2D)
		if world_handle == 0:
			_world_mirror_failures += 1
		else:
			_world_handles[id] = world_handle
			if enemy.has_method("_bind_enemy_world_handle"):
				enemy.call("_bind_enemy_world_handle", world_handle)
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
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return
	if enemy is Node2D:
		var handle := int(_world_handles.get(id, EnemyWorld.handle_for_actor(enemy as Node2D)))
		if handle != 0:
			if not EnemyWorld.release_legacy_actor(enemy as Node2D, &"legacy_unregistered"):
				EnemyWorld.unbind_actor(handle, enemy as Node2D)
				EnemyWorld.remove_enemy(handle, &"materialized_unregistered")
		if enemy.has_method("_bind_enemy_world_handle"):
			enemy.call("_bind_enemy_world_handle", 0)

	# Population counts
	var p: String = enemy.scene_file_path
	if bool(_population_counted.get(id, false)):
		_decrement_counter(_scene_counts, p)
		_unregister_population_class(enemy, p)
	_population_counted.erase(id)
	_elite_ids.erase(id)
	_world_handles.erase(id)
	_accounting_by_id.erase(id)

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

func _lifecycle_audit_enabled() -> bool:
	return (
		PerformanceFlightRecorder != null
		and bool(PerformanceFlightRecorder.get("enabled"))
	)


func _record_lifecycle_operation(
	operation: StringName,
	elapsed_usec: int,
	handle: int = 0
) -> void:
	if not _lifecycle_audit_enabled():
		return

	match operation:
		&"attach":
			_lifecycle_counters["attached"] = (
				int(_lifecycle_counters.get("attached", 0)) + 1
			)
			_lifecycle_counters["attach_total_usec"] = (
				int(_lifecycle_counters.get("attach_total_usec", 0))
				+ elapsed_usec
			)
			_lifecycle_counters["attach_max_usec"] = maxi(
				int(_lifecycle_counters.get("attach_max_usec", 0)),
				elapsed_usec
			)

		&"detach":
			_lifecycle_counters["detached"] = (
				int(_lifecycle_counters.get("detached", 0)) + 1
			)
			_lifecycle_counters["detach_total_usec"] = (
				int(_lifecycle_counters.get("detach_total_usec", 0))
				+ elapsed_usec
			)
			_lifecycle_counters["detach_max_usec"] = maxi(
				int(_lifecycle_counters.get("detach_max_usec", 0)),
				elapsed_usec
			)

		&"retire":
			_lifecycle_counters["retired"] = (
				int(_lifecycle_counters.get("retired", 0)) + 1
			)
			_lifecycle_counters["retire_total_usec"] = (
				int(_lifecycle_counters.get("retire_total_usec", 0))
				+ elapsed_usec
			)
			_lifecycle_counters["retire_max_usec"] = maxi(
				int(_lifecycle_counters.get("retire_max_usec", 0)),
				elapsed_usec
			)

	# Only attach/detach can form representation reversals.
	if handle == 0 or (
		operation != &"attach"
		and operation != &"detach"
	):
		return

	var now_usec := Time.get_ticks_usec()
	var previous_variant: Variant = _lifecycle_last_rep_transition.get(handle, {})

	if previous_variant is Dictionary:
		var previous := previous_variant as Dictionary

		if not previous.is_empty():
			var previous_kind := StringName(previous.get("kind", &""))
			var previous_usec := int(previous.get("t_usec", 0))

			if (
				previous_kind != operation
				and previous_usec > 0
				and now_usec - previous_usec <= LIFECYCLE_REVERSAL_WINDOW_USEC
			):
				_lifecycle_counters["representation_reversals"] = (
					int(_lifecycle_counters.get(
						"representation_reversals",
						0
					)) + 1
				)

	_lifecycle_last_rep_transition[handle] = {
		"kind": operation,
		"t_usec": now_usec,
	}

func detach_representation(enemy: Node2D, handle: int = 0) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var id := int(enemy.get_instance_id())
	if not _id_to_index.has(id):
		return false
	var resolved_handle := handle
	if resolved_handle == 0:
		resolved_handle = int(_world_handles.get(id, EnemyWorld.handle_for_actor(enemy)))
	if not EnemyWorld.is_valid_handle(resolved_handle):
		return false
	if EnemyWorld.actor_for_handle(resolved_handle) != enemy:
		return false
	var audit_started_usec := (
		Time.get_ticks_usec()
		if _lifecycle_audit_enabled()
		else 0
	)
	EnemyWorld.sync_legacy_actor(enemy)
	var snapshot_variant: Variant = _accounting_by_id.get(id)
	var snapshot := (
		(snapshot_variant as Dictionary).duplicate(true)
		if snapshot_variant is Dictionary
		else _snapshot_from_enemy(enemy, enemy.scene_file_path, bool(_population_counted.get(id, false)))
	)
	_remove_materialized_storage(enemy, id)
	_world_handles.erase(id)
	_accounting_by_id.erase(id)
	_population_counted.erase(id)
	_elite_ids.erase(id)
	if bool(snapshot.get("counted", false)) and bool(snapshot.get("elite", false)):
		_detached_elite_handles[resolved_handle] = true
	_detached_records[resolved_handle] = snapshot
	EnemyWorld.unbind_actor(resolved_handle, enemy)
	if enemy.has_method("_bind_enemy_world_handle"):
		enemy.call("_bind_enemy_world_handle", 0)
	if audit_started_usec > 0:
		_record_lifecycle_operation(
			&"detach",
			Time.get_ticks_usec() - audit_started_usec,
			resolved_handle
		)
	return true


func attach_representation(enemy: Node2D, handle: int) -> bool:
	if (
		enemy == null
		or not is_instance_valid(enemy)
		or enemy.is_queued_for_deletion()
		or not EnemyWorld.is_valid_handle(handle)
		or not _detached_records.has(handle)
	):
		return false
	var id := int(enemy.get_instance_id())
	if _id_to_index.has(id) or not EnemyWorld.bind_actor(handle, enemy):
		return false
	var audit_started_usec := (
		Time.get_ticks_usec()
		if _lifecycle_audit_enabled()
		else 0
	)
	var snapshot := (_detached_records[handle] as Dictionary).duplicate(true)
	_id_to_index[id] = _enemies.size()
	_enemies.append(enemy)
	var cell := _cell_for_pos(enemy.global_position)
	_enemy_cell[id] = cell
	_bucket_add(cell, enemy)
	var counted := bool(snapshot.get("counted", false))
	_population_counted[id] = counted
	_accounting_by_id[id] = snapshot
	_world_handles[id] = handle
	if counted and bool(snapshot.get("elite", false)):
		_elite_ids[id] = true
	_detached_records.erase(handle)
	_detached_elite_handles.erase(handle)
	if enemy.has_method("_bind_enemy_world_handle"):
		enemy.call("_bind_enemy_world_handle", handle)
	if audit_started_usec > 0:
		_record_lifecycle_operation(
			&"attach",
			Time.get_ticks_usec() - audit_started_usec,
			handle
		)
	return true


func release_detached(handle: int, reason: StringName = &"detached_released") -> bool:
	var snapshot_variant: Variant = _detached_records.get(handle)
	if not (snapshot_variant is Dictionary):
		return false

	var audit_started_usec := (
		Time.get_ticks_usec()
		if _lifecycle_audit_enabled()
		else 0
	)

	var snapshot := snapshot_variant as Dictionary

	_detached_records.erase(handle)
	_detached_elite_handles.erase(handle)

	if bool(snapshot.get("counted", false)):
		_decrement_snapshot(snapshot)

	var removed := EnemyWorld.remove_enemy(handle, reason)

	_retired_counts[reason] = (
		int(_retired_counts.get(reason, 0)) + 1
	)

	if removed and audit_started_usec > 0:
		_record_lifecycle_operation(
			&"retire",
			Time.get_ticks_usec() - audit_started_usec
		)

	# This logical enemy no longer exists, so its transition history is useless.
	_lifecycle_last_rep_transition.erase(handle)

	return removed

func is_detached(handle: int) -> bool:
	return _detached_records.has(handle)


func detached_handles() -> Array:
	return _detached_records.keys()

func mark_dead(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id: int = int(enemy.get_instance_id())
	if not _id_to_index.has(id) or not bool(_population_counted.get(id, false)):
		return
	if enemy is Node2D:
		EnemyWorld.sync_legacy_actor(enemy as Node2D)
	var scene_path: String = enemy.scene_file_path
	_decrement_counter(_scene_counts, scene_path)
	_unregister_population_class(enemy, scene_path)
	_population_counted[id] = false
	_elite_ids.erase(id)
	var snapshot_variant: Variant = _accounting_by_id.get(id)
	if snapshot_variant is Dictionary:
		(snapshot_variant as Dictionary)["counted"] = false
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"died", 1)


func retire_enemy(enemy: Node, reason: StringName = &"unknown") -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id) or enemy.is_queued_for_deletion():
		return false
	var audit_started_usec := (
		Time.get_ticks_usec()
		if _lifecycle_audit_enabled()
		else 0
	)

	var audit_handle := 0

	if audit_started_usec > 0 and enemy is Node2D:
		audit_handle = int(
			_world_handles.get(
				id,
				EnemyWorld.handle_for_actor(enemy as Node2D)
			)
		)
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
	if audit_started_usec > 0:
		_record_lifecycle_operation(
			&"retire",
			Time.get_ticks_usec() - audit_started_usec
		)

	if audit_handle != 0:
		_lifecycle_last_rep_transition.erase(audit_handle)
	return true


func update_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return
	if not (enemy is Node2D):
		return
	EnemyWorld.sync_legacy_actor(enemy as Node2D)
	var new_cell := _cell_for_pos((enemy as Node2D).global_position)
	var old_cell: Vector2i = _enemy_cell.get(id, new_cell)
	if new_cell == old_cell:
		return
	_enemy_cell[id] = new_cell
	_bucket_remove(old_cell, enemy)
	_bucket_add(new_cell, enemy)

func alive_count() -> int:
	return _ambient_count + _special_alive_total


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
		"detached": _detached_records.size(),
		"logical": _ambient_count + _special_alive_total,
		"ambient": _ambient_count,
		"special": _special_alive_total,
		"special_by_kind": _special_alive_by_kind.duplicate(),
		"reserved": _special_reserved_total,
		"retired": _retired_counts.duplicate(),
		"tiers": simulation_tier_counts(),
		"buckets": _buckets.size(),
		"world_mirror_failures": _world_mirror_failures,
		"lifecycle": _lifecycle_counters.duplicate(true),
	}

func prune_invalid() -> int:
	# Rebuild only materialized indexes. Logical counters and world records survive
	# a representation node disappearing unexpectedly.
	var previous_count: int = _enemies.size()
	var valid_enemies: Array = []
	var seen_ids: Dictionary = {}
	for enemy_variant in _enemies:
		if enemy_variant == null or not is_instance_valid(enemy_variant):
			continue
		if not (enemy_variant is Node):
			continue
		var enemy: Node = enemy_variant
		if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
			continue
		var enemy_id: int = int(enemy.get_instance_id())
		if seen_ids.has(enemy_id):
			continue
		seen_ids[enemy_id] = true
		valid_enemies.append(enemy)

	if valid_enemies.size() == previous_count:
		return 0
	var old_handles := _world_handles.duplicate()
	var old_accounting := _accounting_by_id.duplicate(true)
	var old_counted := _population_counted.duplicate()
	for id_variant in _id_to_index.keys():
		var id := int(id_variant)
		if seen_ids.has(id):
			continue
		# A healthy lease detaches through detach_representation before its actor
		# is ever recycled, so an invalid actor still indexed here died
		# irregularly. Its logical record must die with it: keeping it detached
		# would leak an immortal ghost the representation manager could even
		# re-materialize.
		var handle := int(old_handles.get(id, 0))
		var snapshot_variant: Variant = old_accounting.get(id)
		var snapshot := snapshot_variant as Dictionary if snapshot_variant is Dictionary else {}
		if handle != 0 and EnemyWorld.is_valid_handle(handle):
			EnemyWorld.unbind_actor(handle)
			EnemyWorld.remove_enemy(handle, &"prune_invalid_actor")
		if bool(snapshot.get("counted", false)):
			_decrement_snapshot(snapshot)
	_enemies.clear()
	_id_to_index.clear()
	_enemy_cell.clear()
	_buckets.clear()
	_population_counted.clear()
	_elite_ids.clear()
	_world_handles.clear()
	_accounting_by_id.clear()
	for enemy_variant in valid_enemies:
		var enemy := enemy_variant as Node
		var id := int(enemy.get_instance_id())
		_id_to_index[id] = _enemies.size()
		_enemies.append(enemy)
		var cell := _cell_for_pos((enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO)
		_enemy_cell[id] = cell
		_bucket_add(cell, enemy)
		var counted := bool(old_counted.get(id, false))
		_population_counted[id] = counted
		var snapshot_variant: Variant = old_accounting.get(id)
		var snapshot := (
			(snapshot_variant as Dictionary).duplicate(true)
			if snapshot_variant is Dictionary
			else _snapshot_from_enemy(enemy, enemy.scene_file_path, counted)
		)
		_accounting_by_id[id] = snapshot
		if counted and bool(snapshot.get("elite", false)):
			_elite_ids[id] = true
		var handle := int(old_handles.get(id, 0))
		if handle != 0 and EnemyWorld.is_valid_handle(handle):
			_world_handles[id] = handle
	EnemyWorld.prune_invalid_bindings()
	return previous_count - valid_enemies.size()


func ambient_alive_count() -> int:
	return _ambient_count


func elite_alive_count() -> int:
	return _elite_ids.size() + _detached_elite_handles.size()


func note_elite(enemy: Node) -> void:
	# Called by EnemyActor.make_elite so promotions keep the live count exact.
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _id_to_index.has(id) and bool(_population_counted.get(id, false)):
		_elite_ids[id] = true
		var snapshot_variant: Variant = _accounting_by_id.get(id)
		if snapshot_variant is Dictionary:
			(snapshot_variant as Dictionary)["elite"] = true
		if enemy is Node2D:
			EnemyWorld.sync_legacy_actor(enemy as Node2D)


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
		&"beat":
			return beat_population_cap
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
	var id := int(enemy.get_instance_id())
	var snapshot_variant: Variant = _accounting_by_id.get(id)
	if snapshot_variant is Dictionary:
		(snapshot_variant as Dictionary)["kind"] = new_kind


func _decrement_counter(counter: Dictionary, key: Variant) -> void:
	if key == null or not counter.has(key):
		return
	var value: int = int(counter[key]) - 1
	if value <= 0:
		counter.erase(key)
	else:
		counter[key] = value


func _snapshot_from_enemy(enemy: Node, scene_path: String, counted: bool) -> Dictionary:
	return {
		"scene_path": scene_path,
		"kind": enemy.get_meta("special_spawn_kind", &"") as StringName,
		"elite": _is_enemy_elite(enemy),
		"counted": counted,
	}


func _decrement_snapshot(snapshot: Dictionary) -> void:
	var scene_path := String(snapshot.get("scene_path", ""))
	_decrement_counter(_scene_counts, scene_path)
	var kind := snapshot.get("kind", &"") as StringName
	if kind == &"":
		_ambient_count = maxi(0, _ambient_count - 1)
		_decrement_counter(_ambient_scene_counts, scene_path)
	else:
		_special_alive_total = maxi(0, _special_alive_total - 1)
		_decrement_counter(_special_alive_by_kind, kind)


func _remove_materialized_storage(enemy: Node, id: int) -> void:
	if _enemy_cell.has(id):
		var cell: Vector2i = _enemy_cell[id]
		_bucket_remove(cell, enemy)
		_enemy_cell.erase(id)
	var index := int(_id_to_index.get(id, -1))
	if index >= 0:
		var last_index := _enemies.size() - 1
		if index != last_index:
			var last_enemy := _enemies[last_index] as Node
			_enemies[index] = last_enemy
			if last_enemy != null and is_instance_valid(last_enemy):
				_id_to_index[last_enemy.get_instance_id()] = index
		_enemies.pop_back()
	_id_to_index.erase(id)

func get_all() -> Array:
	# WARNING: do not mutate the returned array.
	return _enemies

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
