class_name EnemySpawnState
extends RefCounted

var spec_id: StringName
var scene_path: String
var position: Vector2
var velocity: Vector2 = Vector2.ZERO
var health: float
var max_health: float
var speed: float
var collision_radius: float
var ai_kind: int
var flags: int = 0
var cold_state: Dictionary = {}


func _init(
	p_spec_id: StringName,
	p_scene_path: String,
	p_position: Vector2,
	p_max_health: float,
	p_speed: float,
	p_collision_radius: float,
	p_ai_kind: int,
	p_flags: int = 0,
	p_cold_state: Dictionary = {},
) -> void:
	spec_id = p_spec_id
	scene_path = p_scene_path
	position = p_position
	health = maxf(p_max_health, 0.0)
	max_health = maxf(p_max_health, 0.0)
	speed = maxf(p_speed, 0.0)
	collision_radius = maxf(p_collision_radius, 0.0)
	ai_kind = p_ai_kind
	flags = p_flags
	cold_state = p_cold_state.duplicate(true)
