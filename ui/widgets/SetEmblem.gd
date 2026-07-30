extends Control
class_name SetEmblem

var set_id: StringName = &""
var accent: Color = Color(1.0, 0.55, 0.20)
var shape: StringName = &"ring"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(16.0, 16.0)
	queue_redraw()

func configure(value: StringName) -> void:
	set_id = value
	visible = set_id != StringName()
	if visible and Global != null and Global.set_db != null:
		var data: SetData = Global.set_db.get(set_id, null) as SetData
		if data != null:
			accent = data.accent_color
			shape = data.emblem_shape
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var center: Vector2 = size * 0.5
	var radius: float = maxf(3.0, minf(size.x, size.y) * 0.34)
	draw_circle(center, radius + 2.0, Color(0.03, 0.03, 0.03, 0.88))
	match shape:
		&"circuit":
			draw_arc(center, radius, 0.35, TAU - 0.35, 18, accent, 1.7, true)
			draw_line(center, center + Vector2(radius + 2.0, 0.0), accent, 1.5, true)
			draw_circle(center + Vector2(radius + 2.0, 0.0), 1.5, accent)
		&"gravity":
			draw_rect(Rect2(center - Vector2(radius * 0.8, radius * 0.8), Vector2(radius * 1.6, radius * 1.15)), accent, false, 1.6)
			draw_polyline(PackedVector2Array([center + Vector2(-radius, radius * 0.15), center + Vector2(0.0, radius), center + Vector2(radius, radius * 0.15)]), accent, 1.7, true)
		&"lattice":
			var points := PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius, radius), center + Vector2(-radius, radius), center + Vector2(0.0, -radius)])
			draw_polyline(points, accent, 1.6, true)
			draw_circle(points[0], 1.5, accent)
			draw_circle(points[1], 1.5, accent)
			draw_circle(points[2], 1.5, accent)
		_:
			draw_arc(center, radius, 0.0, TAU, 18, accent, 1.6, true)
