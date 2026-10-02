extends Label
## A gold number that counts to its new value instead of jumping, and warms
## for a moment when it changes. Text is only rewritten while it is counting.

const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")

@export var prefix: String = ""
@export var suffix: String = ""
@export var signed: bool = false
@export var count_time: float = 0.45
@export var base_colour: Color = ExchangeStyle.GOLD_BRIGHT
@export var flash_colour: Color = Color(1.0, 0.95, 0.82)

var value: int = 0
var _shown: float = 0.0
var _has_value := false
var _tween: Tween = null


func _ready() -> void:
	add_theme_color_override(&"font_color", base_colour)
	_render(value)


func set_value(v: int, animate: bool = true) -> void:
	if _has_value and v == value:
		return
	var from := _shown if _has_value else float(v)
	value = v
	_has_value = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree() or ArcaneMotion.reduced() or is_equal_approx(from, float(v)):
		_shown = float(v)
		_render(v)
		return
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_method(_count, from, float(v), count_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_warm, 1.0, 0.0, count_time + 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_colour(c: Color) -> void:
	if c == base_colour:
		return
	base_colour = c
	add_theme_color_override(&"font_color", base_colour)


func _count(v: float) -> void:
	_shown = v
	_render(int(round(v)))


func _warm(t: float) -> void:
	# self_modulate past 1 brightens the glyphs without touching the theme.
	self_modulate = Color(1, 1, 1).lerp(Color(flash_colour.r * 1.3, flash_colour.g * 1.25, flash_colour.b * 1.2), t * 0.6)


func _render(v: int) -> void:
	var body := ExchangeStyle.grouped(absi(v))
	var sign_ := ""
	if v < 0:
		sign_ = "−"
	elif signed and v > 0:
		sign_ = "+"
	text = prefix + sign_ + body + suffix
