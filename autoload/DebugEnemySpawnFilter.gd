extends Node

signal filters_changed(disabled_ids: Array[StringName])
signal settings_changed

enum CapMode { PRODUCTION, CUSTOM, UNLIMITED }

var cap_mode: CapMode = CapMode.PRODUCTION:
	set(value):
		cap_mode = value
		settings_changed.emit()
var custom_total_cap: int = 180:
	set(value):
		custom_total_cap = maxi(0, value)
		settings_changed.emit()
var filter_protected_actors := false:
	set(value):
		filter_protected_actors = value
		settings_changed.emit()
var spawning_enabled := true:
	set(value):
		if spawning_enabled == value:
			return
		spawning_enabled = value
		if not value:
			_apply_disabled_ids(known_enemy_ids())
		else:
			filters_changed.emit([])
			settings_changed.emit()

var _enabled: Dictionary = {}
var _known_ids: Dictionary = {}
var _custom_type_caps: Dictionary = {}
var _spawn_counts: Dictionary = {}


func register_enemy_id(enemy_id: StringName) -> void:
	if enemy_id == &"":
		return
	_known_ids[enemy_id] = true
	if not _enabled.has(enemy_id):
		_enabled[enemy_id] = true


func known_enemy_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in _known_ids.keys():
		result.append(StringName(key))
	result.sort()
	return result


func is_enemy_enabled(enemy_id: StringName, protected: bool = false) -> bool:
	if enemy_id == &"":
		return true
	register_enemy_id(enemy_id)
	if protected and not filter_protected_actors:
		return true
	if not spawning_enabled:
		return false
	return bool(_enabled.get(enemy_id, true))


func is_node_enabled(enemy: Node) -> bool:
	if enemy == null:
		return false
	return is_enemy_enabled(_enemy_id(enemy), _is_protected(enemy))


func validate_deferred_node(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or is_node_enabled(enemy):
		return
	# Validation runs at tree entry, before some EnemyActor _ready registrations.
	# Defer once so the canonical index path can remove it when available.
	call_deferred("_retire_deferred_node", enemy)


func _retire_deferred_node(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or is_node_enabled(enemy):
		return
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("retire_enemy"):
		if bool(enemy_index.call("retire_enemy", enemy, &"debug_spawn_filter")):
			return
	enemy.queue_free()


func set_enemy_enabled(enemy_id: StringName, value: bool) -> void:
	if enemy_id == &"":
		return
	register_enemy_id(enemy_id)
	if bool(_enabled.get(enemy_id, true)) == value:
		return
	_enabled[enemy_id] = value
	var disabled: Array[StringName] = []
	if not value:
		disabled.append(enemy_id)
	_apply_disabled_ids(disabled)


func enable_all() -> void:
	for enemy_id: Variant in _known_ids.keys():
		_enabled[enemy_id] = true
	filters_changed.emit([])
	settings_changed.emit()


func disable_all() -> void:
	var disabled: Array[StringName] = []
	for enemy_id: Variant in _known_ids.keys():
		var id := StringName(enemy_id)
		_enabled[id] = false
		disabled.append(id)
	_apply_disabled_ids(disabled)


func isolate_enemy(enemy_id: StringName) -> void:
	register_enemy_id(enemy_id)
	var disabled: Array[StringName] = []
	for known: Variant in _known_ids.keys():
		var id := StringName(known)
		var enabled := id == enemy_id
		_enabled[id] = enabled
		if not enabled:
			disabled.append(id)
	cap_mode = CapMode.CUSTOM
	set_custom_type_cap(enemy_id, 0)
	_apply_disabled_ids(disabled)


func set_custom_type_cap(enemy_id: StringName, value: int) -> void:
	register_enemy_id(enemy_id)
	_custom_type_caps[enemy_id] = maxi(0, value)
	settings_changed.emit()


func effective_total_cap(production_cap: int) -> int:
	match cap_mode:
		CapMode.CUSTOM:
			return custom_total_cap
		CapMode.UNLIMITED:
			return 0
		_:
			return maxi(0, production_cap)


func effective_type_cap(enemy_id: StringName, production_cap: int) -> int:
	register_enemy_id(enemy_id)
	match cap_mode:
		CapMode.CUSTOM:
			return maxi(0, int(_custom_type_caps.get(enemy_id, 0)))
		CapMode.UNLIMITED:
			return 0
		_:
			return maxi(0, production_cap)


func record_spawn(enemy_id: StringName) -> void:
	if enemy_id == &"":
		return
	register_enemy_id(enemy_id)
	_spawn_counts[enemy_id] = int(_spawn_counts.get(enemy_id, 0)) + 1


func get_debug_snapshot() -> Dictionary:
	var live_counts: Dictionary = {}
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("get_all"):
		for enemy_variant: Variant in enemy_index.call("get_all") as Array:
			var enemy := enemy_variant as Node
			if enemy == null or not is_instance_valid(enemy):
				continue
			var enemy_id := _enemy_id(enemy)
			if enemy_id != &"":
				live_counts[enemy_id] = int(live_counts.get(enemy_id, 0)) + 1
	return {
		"cap_mode": int(cap_mode),
		"custom_total_cap": custom_total_cap,
		"protected_filtering": filter_protected_actors,
		"spawning_enabled": spawning_enabled,
		"known_ids": known_enemy_ids(),
		"enabled": _enabled.duplicate(),
		"custom_type_caps": _custom_type_caps.duplicate(),
		"spawn_counts": _spawn_counts.duplicate(),
		"live_counts": live_counts,
	}


func _apply_disabled_ids(disabled_ids: Array[StringName]) -> void:
	if not disabled_ids.is_empty():
		_retire_disabled_live_enemies(disabled_ids)
	filters_changed.emit(disabled_ids)
	settings_changed.emit()


func _retire_disabled_live_enemies(disabled_ids: Array[StringName]) -> void:
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index == null or not enemy_index.has_method("get_all"):
		return
	var disabled_lookup: Dictionary = {}
	for enemy_id in disabled_ids:
		disabled_lookup[enemy_id] = true
	var snapshot := (enemy_index.call("get_all") as Array).duplicate()
	for enemy_variant: Variant in snapshot:
		var enemy := enemy_variant as Node
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not disabled_lookup.has(_enemy_id(enemy)):
			continue
		if _is_protected(enemy) and not filter_protected_actors:
			continue
		enemy_index.call("retire_enemy", enemy, &"debug_spawn_filter")


func _enemy_id(enemy: Node) -> StringName:
	if enemy == null:
		return &""
	var spec: Variant = enemy.get("spec")
	if spec != null:
		var value: Variant = spec.get("id")
		if value != null:
			return StringName(value)
	return StringName(enemy.get_meta("enemy_id", &""))


func _is_protected(enemy: Node) -> bool:
	return (
		enemy.is_in_group(&"boss_like")
		or enemy.is_in_group(&"boss")
		or enemy.is_in_group(&"miniboss")
		or bool(enemy.get_meta("objective_required", false))
		or bool(enemy.get_meta("tutorial_actor", false))
	)
