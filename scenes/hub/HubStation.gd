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
## An in-world cue (used by the Ascension station when a mandatory choice
## blocks departure).
@export var attention: bool = false:
	set(value):
		attention = value
		queue_redraw()

var _player_inside: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # the player body layer
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)
	body_exited.connect(_on_body_left)
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
	if _player_inside or attention:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or event == null or event.is_echo():
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		activated.emit()


func _draw() -> void:
	var ground := accent
	ground.a = 0.35 if _player_inside else 0.18
	draw_arc(Vector2.ZERO, interact_radius * 0.55, 0.0, TAU, 40, ground, 2.0, true)
	if attention:
		var blink := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_arc(Vector2.ZERO, interact_radius * (0.7 + 0.1 * blink), 0.0, TAU, 40, Color(1.0, 0.55, 0.35, 0.5 + 0.4 * blink), 3.0, true)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var name_color := Color(0.92, 0.88, 0.8, 0.95 if _player_inside else 0.7)
	draw_string(font, Vector2(-70.0, -interact_radius * 0.55 - 10.0), station_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, name_color)
	if _player_inside:
		var key_color := accent
		key_color.a = 0.7 + 0.3 * sin(_pulse * 5.0)
		draw_string(font, Vector2(-70.0, 6.0), "[%s]" % prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, key_color)
