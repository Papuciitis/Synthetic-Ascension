class_name EnemyDeathContext
extends RefCounted

var _handle: int
var _spec_id: StringName
var _position: Vector2
var _flags: int
var _source_ref: WeakRef = null
var _metadata: Dictionary

var handle: int:
	get:
		return _handle

var spec_id: StringName:
	get:
		return _spec_id

var position: Vector2:
	get:
		return _position

var flags: int:
	get:
		return _flags

var source: Node:
	get:
		if _source_ref == null:
			return null
		var candidate: Variant = _source_ref.get_ref()
		return candidate as Node if candidate is Node else null

var metadata: Dictionary:
	get:
		return _metadata.duplicate(true)

var is_elite: bool:
	get:
		return EnemyWorldTypes.has_flag(_flags, EnemyWorldTypes.Flags.ELITE)


func _init(
	p_handle: int,
	p_spec_id: StringName,
	p_position: Vector2,
	p_flags: int,
	p_source: Node = null,
	p_metadata: Dictionary = {},
) -> void:
	_handle = p_handle
	_spec_id = p_spec_id
	_position = p_position
	_flags = p_flags
	_source_ref = weakref(p_source) if p_source != null and is_instance_valid(p_source) else null
	_metadata = p_metadata.duplicate(true)
