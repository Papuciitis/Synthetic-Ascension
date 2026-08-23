extends Node2D
class_name ShardSplinter

## A fragment thrown clear of a shattered elite, waiting to be collected.
##
## Splinter Dividend used to post shards straight into the orbit on an elite
## death, which made it a faucet with no verb attached: on a loadout with no
## shard consumer it was a passive damage trickle you could not influence, do
## wrong, or feel. A fragment you have to go and stand on turns an elite kill
## into a decision - break off the fight and collect, or leave it and keep
## shooting - which is the shape everything else in the noun already has.
##
## Drawn in local space with no children and no assets, matching VFX_ShardForge.

## Collected by walking into it. Generous, because the reward for killing an
## elite should not hinge on pixel-accurate positioning while a horde is
## arriving.
const PICKUP_RADIUS: float = 46.0

## Long enough to be worth crossing a room for, short enough that leaving one
## is a real choice rather than a chore you will get to eventually.
const LIFETIME: float = 7.0
const FADE_TAIL: float = 1.4

## Seconds before it can be collected, so a fragment cannot be swallowed by the
## same step that killed the elite.
const ARM_DELAY: float = 0.25

const FLIGHT_TIME: float = 0.45

signal collected(splinter: ShardSplinter)

var tint: Color = Color(1.00, 0.80, 0.46)

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _spin: float = 0.0
var _size: float = 1.0
var _taken: bool = false


func setup(at: Vector2, direction: Vector2, distance: float, colour: Color) -> void:
	_from = at
	_to = at + direction * distance
	tint = colour
	global_position = at
	_spin = randf_range(-3.0, 3.0)
	_size = randf_range(0.85, 1.20)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4070
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _t < FLIGHT_TIME:
		# Ease out: it is thrown, not fired.
		var p: float = clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		global_position = _from.lerp(_to, 1.0 - pow(1.0 - p, 3.0))
	else:
		global_position = _to
	queue_redraw()

	if _t >= LIFETIME:
		queue_free()
		return
	if _taken or _t < ARM_DELAY:
		return

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_squared_to(player.global_position) > PICKUP_RADIUS * PICKUP_RADIUS:
		return
	_taken = true
	collected.emit(self)
	queue_free()


func _draw() -> void:
	var life: float = clampf((LIFETIME - _t) / FADE_TAIL, 0.0, 1.0)
	# A slow pulse so a fragment lying on a busy floor still reads as a thing
	# waiting for you rather than as one more spark.
	var pulse: float = 0.72 + 0.28 * sin(_t * 5.2)
	var alpha: float = life * pulse
	var radius: float = 7.0 * _size
	var body := Color(tint.r, tint.g, tint.b, alpha)
	var halo := Color(tint.r, tint.g, tint.b, alpha * 0.22)

	draw_circle(Vector2.ZERO, radius * 2.6, halo)
	var points := PackedVector2Array()
	var angle: float = _t * _spin
	for i in range(4):
		var a: float = angle + float(i) * TAU * 0.25
		var reach: float = radius if i % 2 == 0 else radius * 0.52
		points.append(Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(points, body)
