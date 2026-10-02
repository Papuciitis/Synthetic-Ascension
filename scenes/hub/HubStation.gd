extends Area2D
class_name HubStation
## One service stop in the walkable hub: a labelled spot with an interact
## prompt that lights up in range and emits `activated` on the interact
## action. Purely an entry point into a focused panel — it owns no economy.
##
## The sign is in the front end's register (scenes/hub/ui/HubText.gd): the
## name in Cinzel over a thin gold rule and diamond just above the ring.
## When the player steps on, it warms to gold and lifts clear of their head,
## and the prompt (a key cap and a verb) comes up above it. Everything eases
## on real time, and the label redraws only while something on it changes.

signal activated

const HubText := preload("res://scenes/hub/ui/HubText.gd")
## The sign's rule, above the ring's centre: clear of the head of a player
## whose feet stand on the medallion. Idle, the sign sits just over the ring
## and lifts to this height as the player steps on (under Reduced Motion it
## stays up here).
const SIGN_RULE_Y := -78.0
const SIGN_IDLE_Y := -58.0
## The prompt row's centre, above the rule.
const PROMPT_Y := SIGN_RULE_Y - 46.0
const LIGHT_SECONDS := 0.24
const PROMPT_SECONDS := 0.18
const PROMPT_RISE := 6.0

@export var station_name: String = "Station"
## The key shown when the interact action has no keyboard key bound.
@export var prompt_text: String = "E"
## What the key does here, shown beside the key cap ("Trade").
@export var verb: String = ""
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
		_redraw_label()

var _player_inside: bool = false
var _pulse: float = 0.0
var _label: Node2D = null
## 0..1: how lit the ring and sign are (the player in range), and how shown
## the prompt is (in range and focused). Eased on real time.
var _lit: float = 0.0
var _prompt: float = 0.0
var _key: String = ""
var _prompt_width: float = 0.0
var _title_width: float = 0.0
var _last_usec: int = 0


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
	_title_width = HubText.text_width(HubText.heading(), station_name, HubText.SIGN_SIZE)
	_set_key(HubText.interact_key(prompt_text))
	if label_layer != null:
		_label = Node2D.new()
		_label.name = "%sLabel" % station_name.replace(" ", "")
		label_layer.add_child(_label)
		_label.global_position = global_position
		_label.draw.connect(_draw_text.bind(_label))
		tree_exiting.connect(_label.queue_free)
	_last_usec = Time.get_ticks_usec()
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
	var dt := HubText.since(_last_usec)
	_last_usec = Time.get_ticks_usec()
	if _label != null and _label.global_position != global_position:
		_label.global_position = global_position
	var lit_target := 1.0 if _player_inside else 0.0
	var prompt_target := 1.0 if _player_inside and focused else 0.0
	if prompt_target > 0.0 and _prompt <= 0.0:
		# A rebind in Settings shows the next time the prompt comes up.
		_set_key(HubText.interact_key(prompt_text))
	var changed := false
	if _lit != lit_target:
		_lit = HubText.approach(_lit, lit_target, dt, LIGHT_SECONDS)
		changed = true
	if _prompt != prompt_target:
		_prompt = HubText.approach(_prompt, prompt_target, dt, PROMPT_SECONDS)
		changed = true
	if changed:
		queue_redraw()
		_redraw_label()
	elif attention:
		# Only the ring's cue pulses; the sign holds still.
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
	draw_circle(Vector2.ZERO, r, Color(accent.r, accent.g, accent.b, lerpf(0.08, 0.16, _lit)))
	var ring := accent
	ring.a = lerpf(0.6, 0.95, _lit)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, lerpf(2.0, 3.0, _lit), true)
	draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 48, Color(ring.r, ring.g, ring.b, ring.a * 0.35), 1.5, true)
	if icon != null:
		var icon_size := icon.get_size() * (48.0 / maxf(1.0, icon.get_size().y))
		draw_texture_rect(icon, Rect2(-icon_size * 0.5, icon_size), false, Color(1, 1, 1, lerpf(0.85, 1.0, _lit)))
	if attention:
		var blink := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_arc(Vector2.ZERO, interact_radius * (0.7 + 0.1 * blink), 0.0, TAU, 40, Color(1.0, 0.55, 0.35, 0.5 + 0.4 * blink), 3.0, true)
	if _label == null:
		_draw_text(self)


func _redraw_label() -> void:
	if _label != null:
		_label.queue_redraw()


func _set_key(key: String) -> void:
	_key = key
	_prompt_width = HubText.prompt_width(_key, verb)


func _sign_y() -> float:
	if HubText.reduced():
		return SIGN_RULE_Y
	return lerpf(SIGN_IDLE_Y, SIGN_RULE_Y, HubText.ease_out(_lit))


## Where the sign and (while shown) the prompt are, in world space, so
## speech bubbles can keep clear of them (HubCrowd).
func text_rect() -> Rect2:
	var rule_y := _sign_y()
	var half := maxf(46.0, _title_width * 0.5 + 18.0)
	var area := Rect2(global_position + Vector2(-half, rule_y - 9.0 - HubText.SIGN_SIZE), Vector2(half * 2.0, HubText.SIGN_SIZE + 14.0))
	if _prompt > 0.0:
		var prompt_half := Vector2(_prompt_width * 0.5, HubText.KEY_H * 0.5)
		area = area.merge(Rect2(global_position + Vector2(0.0, PROMPT_Y) - prompt_half, prompt_half * 2.0))
	return area


## The station's sign over the ring and, in range, the key-cap prompt above
## it; under a pending choice, an ember line under the ring. Drawn onto
## `canvas` (the label-layer node, or the station itself without one).
func _draw_text(canvas: CanvasItem) -> void:
	HubText.draw_sign(canvas, Vector2(0.0, _sign_y()), station_name, _title_width, _lit, 1.0)
	# The pending-choice cue sits in the prompt row above the sign (never across
	# the player walking up from the south) and gives way to the prompt.
	if attention:
		HubText.draw_notice(canvas, Vector2(0.0, PROMPT_Y), "a decision waits", HubText.EMBER, 0.95 * (1.0 - HubText.ease_out(_prompt)))
	if _prompt > 0.0:
		var lift := 0.0 if HubText.reduced() else PROMPT_RISE * (1.0 - HubText.ease_out(_prompt))
		HubText.draw_prompt(canvas, Vector2(0.0, PROMPT_Y + lift), _key, verb, HubText.ease_out(_prompt))
