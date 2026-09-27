extends Node2D
class_name VFX_ShockRing

@export var duration := 0.25
@export var radius_start := 12.0
@export var radius_end := 140.0
@export var segments := 48

@onready var ring: Line2D = $Ring

var _radius := 0.0

func setup(world_pos: Vector2, end_radius: float) -> void:
	global_position = world_pos
	radius_end = end_radius

func _ready() -> void:
	# Pixel-art kit (Batch B, 2026-09-27): the root draws the ring sprite at the live radius; the scene's unit-circle Line2D (once scaled up) stays in the scene but hidden.
	ring.visible = false
	_set_radius(radius_start)

	var tw := create_tween()
	tw.tween_method(_set_radius, radius_start, radius_end, duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)

func _set_radius(r: float) -> void:
	_radius = r
	queue_redraw()

func _draw() -> void:
	# The scene's modulate tints the sprite and carries the fade on modulate:a.
	VfxKit.draw_ring(self, Vector2.ZERO, _radius, Color.WHITE)
