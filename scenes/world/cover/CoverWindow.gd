extends StaticBody2D

var _rotate_90: bool = false

@export var rotate_90: bool = false:
	set(v):
		_rotate_90 = v
		_apply_rotation()
	get:
		return _rotate_90

func _ready() -> void:
	_apply_rotation()

func _apply_rotation() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	spr.rotation_degrees = 90.0 if _rotate_90 else 0.0
