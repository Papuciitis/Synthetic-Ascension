extends StaticBody2D
class_name CoverHalfLab

# Lab-friendly half cover props (avoid statues/ritual vibe)
const PROP_TEX: Array[Texture2D] = [
	preload("res://assets/world/props/prop_table_long_01.png"),
	preload("res://assets/world/props/prop_table_small_01.png"),
	preload("res://assets/world/props/prop_crate_01.png"),
	preload("res://assets/world/props/prop_crate_rot_01.png"),
	preload("res://assets/world/props/prop_rubble_small_01.png"),
	preload("res://assets/world/props/prop_rubble_big_01.png"),
	preload("res://assets/world/props/prop_broken_pillar_01.png"),
]

func _ready() -> void:
	add_to_group(&"cover_half")
	_apply()

func _apply() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var rng := RandomNumberGenerator.new()
	var sx := int(floor(global_position.x))
	var sy := int(floor(global_position.y))
	rng.seed = int((sx * 73856093) ^ (sy * 19349663) ^ 0x6C4B1AB)

	var tex := PROP_TEX[rng.randi_range(0, PROP_TEX.size() - 1)]
	spr.texture = tex

	# Keep rotation more "placed" than chaotic.
	var rot_steps := [0, 90, 180, 270]
	spr.rotation_degrees = float(rot_steps[rng.randi_range(0, rot_steps.size() - 1)])

	# Quick win readability: cheap drop-shadow sprite
	var sh := get_node_or_null("Shadow") as Sprite2D
	if sh != null:
		sh.texture = tex
		sh.texture_filter = spr.texture_filter
		sh.texture_repeat = spr.texture_repeat
		sh.scale = spr.scale
		sh.flip_h = spr.flip_h
		sh.flip_v = spr.flip_v
		sh.rotation = spr.rotation
		sh.position = spr.position + Vector2(2, 3)
		sh.z_index = spr.z_index - 1
		sh.modulate = Color(0, 0, 0, 0.33)
