extends Control
## The ornament of a HUD bar (the health bar, the boss bar), as a child of the
## ProgressBar. Two instances per bar:
##
## BEHIND (show_behind_parent) draws the well and the damage trail under the
## bar's own fill: when the bar drops, the chunk just lost stays lit in a pale
## ember for a moment and then falls to the new value, so a hit reads as a
## size, not only as a shorter bar.
##
## FRONT draws over the fill and under the bar's labels: the gold rule, the
## quarter ticks, a brief flash of the rule on a hit, and the low warning (a
## warm inner glow that breathes slowly while the bar is under the threshold).
##
## Both only process while something is moving (a trail, a flash, the low
## breath), on real time so a hit-stop or a pause cannot freeze a trail half
## way. Reduced Motion drops the trail, the flash and the breath; the low
## state then shows steadily.

const HudStyle := preload("res://ui/widgets/hud/HudStyle.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

enum Layer { BEHIND, FRONT }

@export var layer: Layer = Layer.BEHIND
## Quarter marks across the bar; 0 draws none.
@export var tick_count: int = 4
## Ratio at or under which FRONT warns; 0 never warns.
@export var low_threshold: float = 0.3
@export var trail_colour: Color = Color(0.98, 0.74, 0.48, 0.86)
@export var rule_colour: Color = Color(0.62, 0.47, 0.30, 0.85)
@export var low_colour: Color = Color(1.0, 0.36, 0.22, 1.0)
## FRONT: a soft top light over the filled part.
@export var sheen: bool = true
## Seconds the lost chunk holds before it falls, and how long the fall takes.
@export var trail_hold: float = 0.3
@export var trail_fall: float = 0.45

var _ratio: float = 1.0
var _trail: float = 1.0
var _trail_top: float = 1.0
var _hold_left: float = 0.0
var _fall_t: float = 0.0
var _flash: float = 0.0
var _breath_t: float = 0.0
var _last_us: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_behind_parent = layer == Layer.BEHIND
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func ratio() -> float:
	return _ratio


func is_low() -> bool:
	return low_threshold > 0.0 and _ratio <= low_threshold and _ratio > 0.0


## The bar's new value as a fraction. `animate` false snaps (a respawn, the
## first paint).
func set_ratio(value: float, animate: bool = true) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, _ratio):
		return
	var dropped := next < _ratio
	var moving := animate and not ArcaneMotion.reduced()
	if layer == Layer.BEHIND:
		if dropped and moving:
			# A second hit while the trail still shows keeps its top, so a
			# flurry reads as one growing chunk instead of a flicker.
			_trail_top = maxf(_trail if _hold_left > 0.0 or _fall_t > 0.0 else _ratio, _ratio)
			_trail = _trail_top
			_hold_left = trail_hold
			_fall_t = 0.0
		else:
			_trail = next
			_trail_top = next
			_hold_left = 0.0
			_fall_t = 0.0
	else:
		if dropped and moving:
			_flash = 1.0
	_ratio = next
	if layer == Layer.BEHIND and _trail < _ratio:
		_trail = _ratio
	_wake()
	queue_redraw()


func _wake() -> void:
	var needs := false
	if layer == Layer.BEHIND:
		needs = _trail > _ratio + 0.0005
	else:
		needs = _flash > 0.0 or (is_low() and not ArcaneMotion.reduced())
	if needs and not is_processing():
		_last_us = Time.get_ticks_usec()
		set_process(true)
	elif not needs and is_processing():
		set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	if layer == Layer.BEHIND:
		if _hold_left > 0.0:
			_hold_left -= dt
		else:
			_fall_t = minf(1.0, _fall_t + dt / maxf(trail_fall, 0.01))
			var eased := 1.0 - pow(1.0 - _fall_t, 3.0)
			_trail = lerpf(_trail_top, _ratio, eased)
			if _fall_t >= 1.0:
				_trail = _ratio
				_fall_t = 0.0
	else:
		_flash = maxf(0.0, _flash - dt / 0.28)
		_breath_t += dt
	queue_redraw()
	_wake()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	if layer == Layer.BEHIND:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.012, 0.010, 0.92))
		# A faint warm floor so an empty bar still reads as a vessel.
		draw_rect(Rect2(Vector2(0, h - 2.0), Vector2(w, 2.0)), Color(0.3, 0.12, 0.08, 0.35))
		if _trail > _ratio + 0.0005:
			var x0 := roundf(_ratio * w)
			var x1 := roundf(_trail * w)
			var fade := 1.0 if _hold_left > 0.0 else clampf(1.0 - _fall_t * 0.6, 0.0, 1.0)
			draw_rect(Rect2(Vector2(x0, 1.0), Vector2(maxf(1.0, x1 - x0), h - 2.0)), Color(trail_colour, trail_colour.a * fade))
		return
	# A soft top light and a darker foot over the filled part, so the fill
	# reads as a lit, rounded vessel rather than a flat swatch.
	if sheen and _ratio > 0.0:
		var fw := roundf(_ratio * w)
		if fw > 2.0:
			draw_rect(Rect2(Vector2(1.0, 2.0), Vector2(fw - 2.0, maxf(1.0, h * 0.3))), Color(1.0, 0.9, 0.8, 0.13))
			draw_rect(Rect2(Vector2(1.0, h * 0.68), Vector2(fw - 2.0, h * 0.32 - 1.0)), Color(0.0, 0.0, 0.0, 0.16))
	var low := is_low()
	if low:
		var breath := 1.0
		if not ArcaneMotion.reduced():
			breath = 0.55 + 0.45 * (0.5 + 0.5 * cos(TAU * _breath_t / 1.6))
		for i in range(3):
			var inset := 1.0 + float(i) * 1.5
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(low_colour, (0.32 - 0.09 * float(i)) * breath), false, 1.5)
	if tick_count > 1:
		for i in range(1, tick_count):
			var x := roundf(w * float(i) / float(tick_count)) + 0.5
			draw_line(Vector2(x, 2.0), Vector2(x, h - 2.0), Color(0.0, 0.0, 0.0, 0.3), 1.0)
			draw_line(Vector2(x + 1.0, 2.0), Vector2(x + 1.0, h - 2.0), Color(1.0, 0.86, 0.66, 0.07), 1.0)
	var rule := rule_colour
	if low:
		rule = rule.lerp(low_colour, 0.55)
	if _flash > 0.0:
		rule = rule.lerp(HudStyle.GOLD_BRIGHT, _flash)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), rule, false, 1.0)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(-1.5, -1.5), size + Vector2(3, 3)), Color(HudStyle.GOLD_BRIGHT, 0.35 * _flash), false, 2.0)
