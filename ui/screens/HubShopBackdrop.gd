extends Control
class_name HubShopBackdrop

const INK := Color(0.022, 0.018, 0.023, 1.0)
const WARM_INK := Color(0.075, 0.043, 0.035, 0.34)
const BRONZE := Color(0.86, 0.56, 0.25, 0.23)
const BRONZE_FAINT := Color(0.86, 0.56, 0.25, 0.08)
const TEAL_FAINT := Color(0.18, 0.72, 0.72, 0.055)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var redraw_cb := Callable(self, "queue_redraw")
	if not resized.is_connected(redraw_cb):
		resized.connect(redraw_cb)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, INK)

	# Layered warm wash: subtle enough to keep item colours readable, but stops the
	# hub from reading as a flat grey debug screen.
	var band_count: int = 14
	for index in range(band_count):
		var t := float(index) / float(maxi(1, band_count - 1))
		var band_h := size.y / float(band_count)
		var alpha := lerpf(0.18, 0.0, t)
		draw_rect(Rect2(0.0, float(index) * band_h, size.x, band_h + 1.0), Color(WARM_INK.r, WARM_INK.g, WARM_INK.b, alpha))

	# Large ritual/ledger arcs echo the ornate trade-screen silhouette without
	# importing unrelated fantasy assets into the project's visual language.
	var left_center := Vector2(-90.0, size.y * 0.52)
	var right_center := Vector2(size.x + 90.0, size.y * 0.52)
	for radius in [300.0, 430.0, 560.0]:
		draw_arc(left_center, radius, -1.15, 1.15, 72, BRONZE_FAINT, 2.0, true)
		draw_arc(right_center, radius, PI - 1.15, PI + 1.15, 72, BRONZE_FAINT, 2.0, true)

	# A faint synthetic counter-form keeps the hub tied to the cyan/orange game UI.
	draw_arc(Vector2(size.x * 0.5, size.y + 190.0), size.x * 0.33, PI + 0.25, TAU - 0.25, 96, TEAL_FAINT, 3.0, true)

	var y_top := 58.0
	var center_x := size.x * 0.5
	draw_line(Vector2(28.0, y_top), Vector2(center_x - 175.0, y_top), BRONZE, 1.5, true)
	draw_line(Vector2(center_x + 175.0, y_top), Vector2(size.x - 28.0, y_top), BRONZE, 1.5, true)
	_draw_diamond(Vector2(center_x - 190.0, y_top), 5.0, BRONZE)
	_draw_diamond(Vector2(center_x + 190.0, y_top), 5.0, BRONZE)

	var y_bottom := size.y - 22.0
	draw_line(Vector2(size.x * 0.37, y_bottom), Vector2(size.x * 0.63, y_bottom), BRONZE_FAINT, 1.0, true)
	_draw_diamond(Vector2(center_x, y_bottom), 4.0, BRONZE)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
