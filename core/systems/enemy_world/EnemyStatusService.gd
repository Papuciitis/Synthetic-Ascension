class_name EnemyStatusService
extends Node

const BURN: StringName = &"burn"
const BLEED: StringName = &"bleed"

class StatusRecord:
	extends RefCounted
	var handle: int
	var kind: StringName
	var stacks: int
	var time_left: float
	var tick_interval: float
	var tick_left: float
	var damage_per_tick_per_stack: float
	var source_ref: WeakRef = null

	func source() -> Node:
		if source_ref == null:
			return null
		var candidate: Variant = source_ref.get_ref()
		return candidate as Node if candidate is Node else null

var _world: EnemyWorldService = null
var _combat: EnemyCombatService = null
var _active: Array[StatusRecord] = []
var _by_handle: Dictionary = {} # handle -> Dictionary[StringName, StatusRecord]


func _exit_tree() -> void:
	# Shutdown-order hazard mitigation: drop status records (they hold WeakRefs
	# to damage sources) before script teardown.
	_active.clear()
	_by_handle.clear()
	_world = null
	_combat = null


func setup(world: EnemyWorldService, combat: EnemyCombatService) -> void:
	_world = world
	_combat = combat


func _ready() -> void:
	if _world == null:
		_world = get_node_or_null("/root/EnemyWorld") as EnemyWorldService
	if _combat == null:
		_combat = get_node_or_null("/root/EnemyCombat") as EnemyCombatService
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	advance(delta)


func apply_burn(
	handle: int,
	stacks: int,
	duration: float,
	tick_interval: float,
	damage_per_tick_per_stack: float,
	source: Node = null,
) -> bool:
	return _apply_status(handle, BURN, stacks, duration, tick_interval, damage_per_tick_per_stack, source)


func apply_bleed(
	handle: int,
	stacks: int,
	duration: float,
	tick_interval: float,
	damage_per_tick_per_stack: float,
	source: Node = null,
) -> bool:
	return _apply_status(handle, BLEED, stacks, duration, tick_interval, damage_per_tick_per_stack, source)


func advance(delta: float) -> void:
	if delta <= 0.0 or _world == null or _combat == null:
		return
	for index in range(_active.size() - 1, -1, -1):
		if index >= _active.size():
			# A lethal tick below re-entered clear_handle and shrank the list.
			continue
		var record := _active[index]
		if not _world.is_valid_handle(record.handle) or _world.is_dying(record.handle):
			_remove_at(index)
			continue
		record.time_left -= delta
		if record.time_left <= 0.0:
			_remove_at(index)
			continue
		record.tick_left -= delta
		if record.tick_left > 0.0:
			continue
		record.tick_left = record.tick_interval
		var damage := float(record.stacks) * record.damage_per_tick_per_stack
		_combat.apply_damage(record.handle, damage, 1, record.source())
		# The damage call can finalize a proxy death, which re-enters
		# clear_handle; only remove by index if this exact record still
		# occupies it.
		if (
			index < _active.size()
			and _active[index] == record
			and (not _world.is_valid_handle(record.handle) or _world.is_dying(record.handle))
		):
			_remove_at(index)


func has_status(handle: int, kind: StringName) -> bool:
	var by_kind: Variant = _by_handle.get(handle)
	return by_kind is Dictionary and (by_kind as Dictionary).has(kind)


func active_status_count() -> int:
	return _active.size()


func clear_handle(handle: int) -> void:
	for index in range(_active.size() - 1, -1, -1):
		if _active[index].handle == handle:
			_remove_at(index)


func clear_all() -> void:
	_active.clear()
	_by_handle.clear()


func get_debug_counters() -> Dictionary:
	var burn_count := 0
	var bleed_count := 0
	for record in _active:
		if record.kind == BURN:
			burn_count += 1
		elif record.kind == BLEED:
			bleed_count += 1
	return {"active": _active.size(), "burn": burn_count, "bleed": bleed_count}


func _apply_status(
	handle: int,
	kind: StringName,
	stacks: int,
	duration: float,
	tick_interval: float,
	damage_per_tick_per_stack: float,
	source: Node,
) -> bool:
	if (
		_world == null
		or not _world.is_valid_handle(handle)
		or _world.is_dying(handle)
		or stacks <= 0
		or duration <= 0.0
		or damage_per_tick_per_stack <= 0.0
	):
		return false
	var by_kind_variant: Variant = _by_handle.get(handle)
	var by_kind: Dictionary
	if by_kind_variant is Dictionary:
		by_kind = by_kind_variant as Dictionary
	else:
		by_kind = {}
		_by_handle[handle] = by_kind
	var existing_variant: Variant = by_kind.get(kind)
	if existing_variant is StatusRecord:
		var existing := existing_variant as StatusRecord
		existing.stacks = maxi(existing.stacks, stacks)
		existing.time_left = maxf(existing.time_left, duration)
		existing.tick_interval = maxf(tick_interval, 0.05)
		existing.tick_left = minf(existing.tick_left, existing.tick_interval)
		existing.damage_per_tick_per_stack = maxf(damage_per_tick_per_stack, 0.01)
		if source != null and is_instance_valid(source):
			existing.source_ref = weakref(source)
		return true
	var record := StatusRecord.new()
	record.handle = handle
	record.kind = kind
	record.stacks = stacks
	record.time_left = duration
	record.tick_interval = maxf(tick_interval, 0.05)
	record.tick_left = 0.0
	record.damage_per_tick_per_stack = maxf(damage_per_tick_per_stack, 0.01)
	record.source_ref = weakref(source) if source != null and is_instance_valid(source) else null
	by_kind[kind] = record
	_active.append(record)
	return true


func _remove_at(index: int) -> void:
	if index < 0 or index >= _active.size():
		return
	var record := _active[index]
	var by_kind_variant: Variant = _by_handle.get(record.handle)
	if by_kind_variant is Dictionary:
		var by_kind := by_kind_variant as Dictionary
		by_kind.erase(record.kind)
		if by_kind.is_empty():
			_by_handle.erase(record.handle)
	var last_index := _active.size() - 1
	if index != last_index:
		_active[index] = _active[last_index]
	_active.pop_back()

