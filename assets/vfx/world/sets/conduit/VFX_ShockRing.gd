extends Node2D
class_name VFX_ShockRing

@export var duration := 0.25
@export var radius_start := 12.0
@export var radius_end := 140.0
@export var segments := 48

@onready var ring: Line2D = $Ring

func setup(world_pos: Vector2, end_radius: float) -> void:
	global_position = world_pos
	radius_end = end_radius

func _ready() -> void:
	ring.clear_points()
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		ring.add_point(Vector2(cos(a), sin(a)))

	scale = Vector2.ONE * radius_start

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * radius_end, duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)
