extends Control
## The Balance's scales: a brass beam on a post, a pan hanging from each end.
## The left pan carries what you offer, the right what you request; the
## heavier side sinks and the beam swings to it with a little overshoot, and
## the totals on the pans count to their new values. Drawn, no art.
##
## set_totals() is the only input. It redraws only while the beam or the
## numbers are moving; a settled scale costs nothing per frame.

const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

const MAX_TILT := deg_to_rad(8.5)
const PIVOT_Y := 34.0
const HANG := 54.0
const PAN_W := 136.0

## Half the beam, px: the Exchange hangs each pan over its grid. 0 = from width.
var arm: float = 0.0:
	set(value):
		if is_equal_approx(arm, value):
			return
		arm = value
		queue_redraw()

var _offer := 0
var _request := 0
var _tilt := 0.0
var _shown_offer := 0.0
var _shown_request := 0.0
var _tween: Tween = null
## 0..1, flashes when a trade settles.
var _flash := 0.0
var _flash_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 1.0:
		custom_minimum_size = Vector2(0, 150)
	resized.connect(queue_redraw)


func set_totals(offer: int, request: int, animate: bool = true) -> void:
	offer = maxi(0, offer)
	request = maxi(0, request)
	if offer == _offer and request == _request and is_node_ready():
		return
	_offer = offer
	_request = request
	var target := _target_tilt()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or ArcaneMotion.reduced() or not is_inside_tree():
		_set_tilt(target)
		_shown_offer = float(offer)
		_shown_request = float(request)
		queue_redraw()
		return
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_method(_set_tilt, _tilt, target, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_shown_offer, _shown_offer, float(offer), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_shown_request, _shown_request, float(request), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A brief brightening of the whole instrument (the trade has settled).
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, 0.9 if not ArcaneMotion.reduced() else 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _target_tilt() -> float:
	var heavier := maxi(_offer, _request)
	if heavier <= 0:
		return 0.0
	# Positive tilt (clockwise on screen) sinks the right (request) pan.
	return clampf(float(_request - _offer) / float(heavier), -1.0, 1.0) * MAX_TILT


func _set_tilt(v: float) -> void:
	_tilt = v
	queue_redraw()


func _set_shown_offer(v: float) -> void:
	_shown_offer = v
	queue_redraw()


func _set_shown_request(v: float) -> void:
	_shown_request = v
	queue_redraw()


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var pivot := Vector2(cx, PIVOT_Y)
	var half := arm if arm > 0.0 else clampf(size.x * 0.3, 140.0, 220.0)
	var gold := ExchangeStyle.GOLD.lerp(ExchangeStyle.GOLD_BRIGHT, _flash * 0.8)
	var dim := ExchangeStyle.GOLD_DIM
	var base_y := size.y - 6.0

	# Candle warmth pooled behind the post.
	for i in range(5):
		var r := 26.0 + i * 16.0
		draw_circle(pivot + Vector2(0, 30), r, Color(1.0, 0.6, 0.28, 0.018 + _flash * 0.03))

	# The post and its stepped foot.
	draw_line(pivot + Vector2(0, 6), Vector2(cx, base_y - 8), Color(dim, 0.9), 2.0, true)
	draw_line(pivot + Vector2(-3, 10), Vector2(cx - 3, base_y - 8), Color(dim, 0.35), 1.0, true)
	draw_line(Vector2(cx - 30, base_y), Vector2(cx + 30, base_y), Color(dim, 0.9), 1.5, true)
	draw_line(Vector2(cx - 18, base_y - 5), Vector2(cx + 18, base_y - 5), Color(dim, 0.8), 1.2, true)
	draw_line(Vector2(cx - 10, base_y - 8), Vector2(cx + 10, base_y - 8), Color(dim, 0.8), 1.0, true)

	# The beam.
	var dir := Vector2(cos(_tilt), sin(_tilt))
	var left := pivot - dir * half
	var right := pivot + dir * half
	var normal := Vector2(-dir.y, dir.x)
	draw_line(left, right, gold, 2.0, true)
	draw_line(left + normal * 3.0, right + normal * 3.0, Color(gold, 0.35), 1.0, true)
	for end: Vector2 in [left, right]:
		_diamond(end, 4.0, gold, true)

	# The finial: a small star over the pivot.
	_diamond(pivot, 6.5 + _flash * 2.0, gold, false)
	draw_line(pivot + Vector2(0, -17 - _flash * 6.0), pivot + Vector2(0, -8), gold, 1.0, true)
	draw_circle(pivot, 1.8, ExchangeStyle.GOLD_BRIGHT)
	if _flash > 0.01:
		draw_circle(pivot, 10.0 + _flash * 16.0, Color(1.0, 0.8, 0.5, 0.12 * _flash))

	var offer_heavy := _offer > _request
	var request_heavy := _request > _offer
	_draw_pan(left, int(round(_shown_offer)), ExchangeStyle.EMBER, offer_heavy, gold)
	_draw_pan(right, int(round(_shown_request)), ExchangeStyle.GOLD_BRIGHT, request_heavy, gold)


func _draw_pan(hook: Vector2, value: int, value_col: Color, heavy: bool, gold: Color) -> void:
	var rim := hook + Vector2(0, HANG)
	var half := PAN_W * 0.5
	# Two cords from the hook to the rim.
	for dx: float in [-half + 8.0, half - 8.0]:
		draw_line(hook, rim + Vector2(dx, 0), Color(gold, 0.45), 1.0, true)
	# The pan: a shallow bowl under the rim.
	var bowl := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var t := float(i) / steps
		var x := lerpf(-half, half, t)
		bowl.append(rim + Vector2(x, sin(t * PI) * 13.0))
	var fill := bowl.duplicate()
	draw_colored_polygon(fill, Color(0.07, 0.05, 0.035, 0.92))
	draw_polyline(bowl, gold, 1.5, true)
	draw_line(rim + Vector2(-half, 0), rim + Vector2(half, 0), Color(gold, 0.9), 1.0, true)
	if heavy:
		draw_line(rim + Vector2(-half + 8, 3), rim + Vector2(half - 8, 3), Color(value_col, 0.35), 1.0, true)

	var num_font := ExchangeStyle.font(&"ArcaneHeading")
	var num_size := 24
	var text := ExchangeStyle.grouped(value) if value > 0 else "—"
	var num_col := value_col if value > 0 else Color(ExchangeStyle.MUTED, 0.8)
	var num_w := num_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	draw_string(num_font, rim + Vector2(-num_w * 0.5, -12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, num_size, num_col)


func _diamond(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := ExchangeStyle.diamond(c, r)
	if filled:
		draw_colored_polygon(pts, col)
		return
	draw_colored_polygon(pts, Color(0.04, 0.034, 0.03, 1.0))
	pts.append(pts[0])
	draw_polyline(pts, col, 1.2, true)
	var i := r * 0.4
	draw_colored_polygon(ExchangeStyle.diamond(c, i), col)
