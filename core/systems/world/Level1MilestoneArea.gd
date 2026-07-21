extends Area2D
class_name Level1MilestoneArea

signal reached(milestone_id: StringName)

var milestone_id: StringName = &""
var _show_marker: bool = false
var _marker_radius: float = 54.0
var _fired: bool = false

func configure(id: StringName, world_position: Vector2, size_px: Vector2, show_marker: bool = false) -> void:
	milestone_id = id
	global_position = world_position
	_show_marker = show_marker
	_marker_radius = maxf(28.0, minf(size_px.x, size_px.y) * 0.32)

	collision_layer = 0
	collision_mask = 4 # Player CharacterBody2D layer.
	monitoring = true
	monitorable = false

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(32.0, size_px.x), maxf(32.0, size_px.y))
	shape_node.shape = rect
	add_child(shape_node)

	body_entered.connect(_on_body_entered)
	queue_redraw()

func mark_completed() -> void:
	_fired = true
	set_deferred(&"monitoring", false)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _fired or body == null or not body.is_in_group(&"player"):
		return
	_fired = true
	# Physics monitoring is locked while body_entered is being emitted.
	set_deferred(&"monitoring", false)
	reached.emit(milestone_id)
	queue_redraw()

func _draw() -> void:
	if not _show_marker:
		return
	var base := Color(0.25, 0.78, 1.0, 0.34 if not _fired else 0.12)
	draw_circle(Vector2.ZERO, _marker_radius * 0.36, Color(0.08, 0.18, 0.22, 0.72))
	draw_arc(Vector2.ZERO, _marker_radius, 0.0, TAU, 64, base, 4.0, true)
	draw_arc(Vector2.ZERO, _marker_radius * 0.68, PI * 0.25, PI * 1.75, 48, Color(1.0, 0.58, 0.22, base.a), 3.0, true)
