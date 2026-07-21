extends StaticBody2D
class_name FenceBlock

# Connection bitmask: N=1, E=2, S=4, W=8
@export var connections_mask: int = 0

const N := 1
const E := 2
const S := 4
const W := 8

const TEX_H := preload("res://assets/world/fences/fence_wood_h.png")
const TEX_V := preload("res://assets/world/fences/fence_wood_v.png")
const TEX_NE := preload("res://assets/world/fences/fence_wood_corner_ne.png")
const TEX_NW := preload("res://assets/world/fences/fence_wood_corner_nw.png")
const TEX_SE := preload("res://assets/world/fences/fence_wood_corner_se.png")
const TEX_SW := preload("res://assets/world/fences/fence_wood_corner_sw.png")
const TEX_POST := preload("res://assets/world/fences/fence_post_01.png")

func _ready() -> void:
	add_to_group(&"fences")
	_apply()

func _apply() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var tex := _pick_tex(connections_mask)
	spr.texture = tex
	_apply_collisions()

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
		sh.modulate = Color(0, 0, 0, 0.28)

func _apply_collisions() -> void:
	# Thin fence intent: match the visible line segments (N/E/S/W half-legs).
	# If we don't have a supported segment mask (ends / weird), fall back to a post.
	var is_segment: bool = (
		connections_mask == (N | S)
		or connections_mask == (E | W)
		or connections_mask == (N | E)
		or connections_mask == (N | W)
		or connections_mask == (S | E)
		or connections_mask == (S | W)
	)

	var want_n: bool = is_segment and ((connections_mask & N) != 0)
	var want_e: bool = is_segment and ((connections_mask & E) != 0)
	var want_s: bool = is_segment and ((connections_mask & S) != 0)
	var want_w: bool = is_segment and ((connections_mask & W) != 0)
	var want_post: bool = not is_segment

	_set_col("CollisionN", want_n)
	_set_col("CollisionE", want_e)
	_set_col("CollisionS", want_s)
	_set_col("CollisionW", want_w)
	_set_col("CollisionPost", want_post)

func _set_col(col_node: String, enabled: bool) -> void:
	var c: CollisionShape2D = get_node_or_null(col_node) as CollisionShape2D
	if c != null:
		c.disabled = not enabled

func _pick_tex(mask: int) -> Texture2D:
	# Straight
	if mask == (N | S):
		return TEX_V
	if mask == (E | W):
		return TEX_H

	# Corners
	if mask == (N | E):
		return TEX_NE
	if mask == (N | W):
		return TEX_NW
	if mask == (S | E):
		return TEX_SE
	if mask == (S | W):
		return TEX_SW

	# Everything else (ends / isolated) -> post
	return TEX_POST
