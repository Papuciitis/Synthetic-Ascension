extends Node2D
class_name RoofOverlay

@export_range(0.0, 1.0, 0.01) var outside_alpha: float = 0.62
@export_range(0.0, 1.0, 0.01) var inside_alpha: float = 0.0
@export_range(0.05, 1.0, 0.01) var fade_time: float = 0.18
@export_range(0.0, 24.0, 1.0) var overhang_px: float = 8.0
@export_range(0.0, 12.0, 1.0) var front_edge_width_px: float = 6.0

@onready var _poly: Polygon2D = get_node("RoofPoly") as Polygon2D
@onready var _edge: Line2D = get_node("FrontEdge") as Line2D

var _inside_count: int = 0
var _tween: Tween


func configure(build_rect_cells: Rect2i, cell_size_px: int, door_dir: Vector2i, indoor_volume: Area2D) -> void:
	# Build a simple roof silhouette that makes parcels read as "buildings" from the street.
	# This is intentionally cheap: just a dark polygon + a stronger façade edge.
	var tl := Vector2(build_rect_cells.position) * float(cell_size_px)
	var sz := Vector2(build_rect_cells.size) * float(cell_size_px)
	var o := float(overhang_px)

	# Slightly inset on the street-facing side so the door apron remains readable.
	var inset := float(maxi(0, int(front_edge_width_px / 2.0)))
	var in_n := 0.0
	var in_e := 0.0
	var in_s := 0.0
	var in_w := 0.0
	if door_dir == Vector2i(0, -1):
		in_n = inset
	elif door_dir == Vector2i(1, 0):
		in_e = inset
	elif door_dir == Vector2i(0, 1):
		in_s = inset
	elif door_dir == Vector2i(-1, 0):
		in_w = inset

	var p0 := tl + Vector2(-o + in_w, -o + in_n)
	var p1 := tl + Vector2(sz.x + o - in_e, -o + in_n)
	var p2 := tl + Vector2(sz.x + o - in_e, sz.y + o - in_s)
	var p3 := tl + Vector2(-o + in_w, sz.y + o - in_s)

	_poly.polygon = PackedVector2Array([p0, p1, p2, p3])
	_poly.z_index = -92

	# Strong front edge (façade line) along the street-facing side.
	_edge.clear_points()
	_edge.width = front_edge_width_px
	_edge.z_index = -91
	_edge.antialiased = true

	if door_dir == Vector2i(0, -1):
		_edge.add_point(p0)
		_edge.add_point(p1)
	elif door_dir == Vector2i(1, 0):
		_edge.add_point(p1)
		_edge.add_point(p2)
	elif door_dir == Vector2i(0, 1):
		_edge.add_point(p2)
		_edge.add_point(p3)
	else: # W
		_edge.add_point(p3)
		_edge.add_point(p0)

	_set_alpha(outside_alpha)

	# Fade roof when the player enters the indoor volume.
	if indoor_volume != null:
		if not indoor_volume.body_entered.is_connected(_on_volume_body_entered):
			indoor_volume.body_entered.connect(_on_volume_body_entered)
		if not indoor_volume.body_exited.is_connected(_on_volume_body_exited):
			indoor_volume.body_exited.connect(_on_volume_body_exited)


func _on_volume_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_inside_count += 1
		_update_target()


func _on_volume_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_inside_count = maxi(0, _inside_count - 1)
		_update_target()


func _update_target() -> void:
	var target := (inside_alpha if _inside_count > 0 else outside_alpha)
	_fade_to(target)


func _fade_to(a: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _poly.modulate.a, a, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_alpha(a: float) -> void:
	var aa := clampf(a, 0.0, 1.0)
	_poly.modulate = Color(1, 1, 1, aa)
	# Slightly stronger façade edge
	_edge.modulate = Color(1, 1, 1, clampf(aa * 1.15, 0.0, 1.0))
