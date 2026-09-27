extends Area2D
class_name HubStation
## One service stop in the walkable hub: a labelled spot with an interact
## prompt that lights up in range and emits `activated` on the interact
## action. Purely an entry point into a focused panel — it owns no economy.

signal activated

@export var station_name: String = "Station"
@export var prompt_text: String = "E"
@export var interact_radius: float = 72.0
@export var accent: Color = Color(0.95, 0.8, 0.45, 1.0)
## Painted emblem drawn in the ring's centre (hub_icon_*.png), if any.
@export var icon: Texture2D = null
## Where the name and the [key] prompt are drawn: a world-following layer
## above the player and outside the scene's CanvasModulate. Without one the
## text is drawn with the ring (the old behaviour).
var label_layer: CanvasLayer = null
## Offset of the sensing circle from the ring, so a scene can sense the
## player's drawn feet rather than their body origin (the hub passes -FEET).
var sense_offset: Vector2 = Vector2.ZERO
## When the scene arbitrates the interact key between several interactables
## (the hub picks the nearest), the station stops reading it itself.
var managed: bool = false
## Whether this station is the one the key would use; only it shows [key].
var focused: bool = true:
	set(value):
		if focused != value:
			focused = value
			queue_redraw()
## An in-world cue (used by the Ascension station when a mandatory choice
## blocks departure).
@export var attention: bool = false:
	set(value):
		attention = value
		queue_redraw()

var _player_inside: bool = false
var _pulse: float = 0.0
var _label: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # the player body layer
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	shape.position = sense_offset
	add_child(shape)
	body_entered.connect(_on_body)
	body_exited.connect(_on_body_left)
	if label_layer != null:
		_label = Node2D.new()
		_label.name = "%sLabel" % station_name.replace(" ", "")
		label_layer.add_child(_label)
		_label.draw.connect(_draw_text.bind(_label))
		tree_exiting.connect(_label.queue_free)
	set_process(true)


func _on_body(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_player_inside = true
		queue_redraw()


func _on_body_left(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_player_inside = false
		queue_redraw()


func player_inside() -> bool:
	return _player_inside


func _process(delta: float) -> void:
	_pulse += delta
	if _label != null:
		_label.global_position = global_position
	if _player_inside or attention:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if managed or not _player_inside or event == null or event.is_echo():
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		activated.emit()


func _draw() -> void:
	# A worn stone medallion on the ground with a lit accent ring, so each
	# service reads as a marked spot on the square.
	var r := interact_radius * 0.55
	draw_circle(Vector2.ZERO, r, Color(accent.r, accent.g, accent.b, 0.16 if _player_inside else 0.08))
	var ring := accent
	ring.a = 0.95 if _player_inside else 0.6
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, 3.0 if _player_inside else 2.0, true)
	draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 48, Color(ring.r, ring.g, ring.b, ring.a * 0.35), 1.5, true)
	if icon != null:
		var size := icon.get_size() * (48.0 / maxf(1.0, icon.get_size().y))
		draw_texture_rect(icon, Rect2(-size * 0.5, size), false, Color(1, 1, 1, 1.0 if _player_inside else 0.85))
	if attention:
		var blink := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_arc(Vector2.ZERO, interact_radius * (0.7 + 0.1 * blink), 0.0, TAU, 40, Color(1.0, 0.55, 0.35, 0.5 + 0.4 * blink), 3.0, true)
	if _label != null:
		_label.queue_redraw()
	else:
		_draw_text(self)


## The station's name above the ring and, in range, the [key] prompt below
## it (clear of the icon), drawn onto `canvas`.
func _draw_text(canvas: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var r := interact_radius * 0.55
	var label_pos := Vector2(-90.0, -r - 12.0)
	var name_color := Color(1.0, 0.95, 0.85, 1.0 if _player_inside else 0.85)
	canvas.draw_string_outline(font, label_pos, station_name, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, 5, Color(0.05, 0.04, 0.03, 0.85))
	canvas.draw_string(font, label_pos, station_name, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, name_color)
	if _player_inside and focused:
		var key_color := accent
		key_color.a = 0.7 + 0.3 * sin(_pulse * 5.0)
		var key_pos := Vector2(-70.0, r + 20.0)
		canvas.draw_string_outline(font, key_pos, "[%s]" % prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 16, 4, Color(0, 0, 0, 0.8))
		canvas.draw_string(font, key_pos, "[%s]" % prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 16, key_color)
