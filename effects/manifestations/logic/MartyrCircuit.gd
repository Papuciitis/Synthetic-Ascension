extends ManifestationEffect

## Martyr Circuit - lowhp.
##
## Healthy, you attack slower. Wounded, you accelerate. Near death, your attacks
## echo. The rule exists to make a health pickup an actual decision instead of a
## free win: topping up costs you the whole bottom half of the curve.

## Where "wounded" and "dying" are is a property of the ward NOUN, not of this
## rule. Two ward rules that each picked their own thresholds would disagree
## about the same word, and the player would have no way to learn either.
const HEALTHY_AT: float = ManifestationState.WOUND_HEALTHY
const WOUNDED_AT: float = ManifestationState.WOUND_WOUNDED
const DYING_AT: float = ManifestationState.WOUND_DYING

const HEALTHY_HASTE: float = 0.80
const WOUNDED_HASTE_PER_POTENCY: float = 0.45
const ECHO_PER_POTENCY: float = 0.45

## The echo lands a beat after the shot it copies. Same-frame it would just read
## as a fatter attack; this reads as an echo.
const ECHO_DELAY: float = 0.09

var _echo_style: StringName = &""
var _echo_target: Vector2 = Vector2.ZERO
var _echo_wait: float = 0.0
var _echo_flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	# World-space draw: the player rotates to face its movement vector and a
	# warning aura must not spin with it.
	top_level = true
	z_as_relative = false
	z_index = 4060
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_echo_flash = maxf(0.0, _echo_flash - delta)
	global_position = player_position()

	if _echo_wait > 0.0:
		_echo_wait -= delta
		if _echo_wait <= 0.0:
			_fire_echo()

	queue_redraw()


func echo_multiplier() -> float:
	return ECHO_PER_POTENCY * potency()


func wounded_haste() -> float:
	return 1.0 + WOUNDED_HASTE_PER_POTENCY * potency()


func get_haste_multiplier() -> float:
	var fraction := player_hp_fraction()
	if fraction > HEALTHY_AT:
		return HEALTHY_HASTE
	if fraction > WOUNDED_AT:
		return 1.0
	return wounded_haste()


func on_attack(
	style_id: StringName,
	_origin: Vector2,
	target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if player_hp_fraction() >= DYING_AT:
		return
	# One pending echo at a time; a newer shot simply replaces the old aim.
	_echo_style = style_id
	_echo_target = target
	_echo_wait = ECHO_DELAY
	_echo_flash = 0.22


func describe() -> String:
	return (
		"Above %d%% HP you attack %d%% slower. Below %d%% you attack %d%% faster. Below %d%% every attack echoes for %d%% damage."
		% [
			int(round(HEALTHY_AT * 100.0)),
			int(round((1.0 - HEALTHY_HASTE) * 100.0)),
			int(round(WOUNDED_AT * 100.0)),
			int(round((wounded_haste() - 1.0) * 100.0)),
			int(round(DYING_AT * 100.0)),
			int(round(echo_multiplier() * 100.0)),
		]
	)


func _fire_echo() -> void:
	if player == null or not is_instance_valid(player):
		return
	repeat_player_attack(_echo_style, _echo_target, echo_multiplier())


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var fraction := player_hp_fraction()

	if fraction > HEALTHY_AT:
		# The slow state needs to be visible too, or the penalty reads as a bug.
		var drag := 0.85 + 0.15 * sin(_t * 1.6)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color(0.42, 0.52, 0.68, 0.20 * drag), 1.4, true)
		return

	if fraction > WOUNDED_AT:
		return

	var dying := fraction <= DYING_AT
	# Heartbeat quickens as the fraction falls, so the aura reads as a state and
	# not just as decoration.
	var beat := 4.0 + 9.0 * (1.0 - fraction / WOUNDED_AT)
	var pulse := 0.80 + 0.20 * sin(_t * beat)
	var intensity := clampf((WOUNDED_AT - fraction) / WOUNDED_AT, 0.0, 1.0)
	var radius := 27.0 + 9.0 * intensity * pulse
	# Identity hue from the noun registry; the deepening toward blood red as the
	# wound worsens is authored, as are the gold spokes and the echo flash.
	var ward := noun_colour()
	var tint := Color(ward.r, ward.g * (1.0 - 0.56 * intensity), ward.b * 0.73, 0.28 + 0.42 * intensity)

	draw_circle(Vector2.ZERO, radius * 1.15, Color(tint.r, tint.g, tint.b, tint.a * 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, tint, 1.6 + 1.8 * intensity, true)

	if not dying:
		return

	# Below the echo threshold the circuit shows its second ring and its spokes.
	draw_arc(Vector2.ZERO, radius * 1.34, 0.0, TAU, 30, Color(1.0, 0.86, 0.42, 0.45 + 0.35 * pulse), 1.6, true)
	for i in range(6):
		var angle := _t * 2.4 + TAU * float(i) / 6.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * radius * 1.05, dir * radius * (1.46 + 0.10 * pulse), Color(1.0, 0.72, 0.34, 0.55), 1.8, true)

	if _echo_flash > 0.0:
		var t := _echo_flash / 0.22
		draw_arc(Vector2.ZERO, radius * (1.4 + 0.9 * (1.0 - t)), 0.0, TAU, 30, Color(1.0, 0.95, 0.70, 0.55 * t), 2.0, true)
