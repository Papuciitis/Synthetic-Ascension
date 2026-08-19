class_name EnemyDeathContext
extends RefCounted

var _handle: int
var _spec_id: StringName
var _position: Vector2
var _flags: int
var _source: Node

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
		return _source if _source == null or is_instance_valid(_source) else null

var is_elite: bool:
	get:
		return EnemyWorldTypes.has_flag(_flags, EnemyWorldTypes.Flags.ELITE)


func _init(
	p_handle: int,
	p_spec_id: StringName,
	p_position: Vector2,
	p_flags: int,
	p_source: Node = null,
) -> void:
	_handle = p_handle
	_spec_id = p_spec_id
	_position = p_position
	_flags = p_flags
	_source = p_source

