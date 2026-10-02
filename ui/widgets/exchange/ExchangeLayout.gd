extends Container
## The Exchange's composition (Root/HBox keeps its name and its five panels):
##
##   Left ledger | Worn gear over Backpack | the Balance | the Exchanger's stock
##
## Your goods on the left, his on the right, the scales between. The gear and
## the backpack share one column so neither panel is a tall empty strip.
##
## `intro` (0..1) settles the panels in when the screen opens: each rises a few
## pixels and fades up in turn, the Balance first. It only re-sorts while it
## runs; a settled layout does no per-frame work.

const COLUMN_GAP := 16.0
const STACK_GAP := 14.0
const LEFT_W := 292.0
const GOODS_W := 404.0
const VENDOR_W := 432.0
const CENTER_MIN := 560.0

const RISE := 16.0
## Where the fade starts: the panels are legible from the first frame (a
## screenshot taken on it still shows the layout) and warm up as they rise.
const ALPHA_FLOOR := 0.45
const INTRO_TIME := 0.85
const PANEL_TIME := 0.5
## When each panel starts settling, in seconds after the screen opens.
const DELAYS := {&"CartPanel": 0.0, &"Equipped": 0.07, &"Vendor": 0.07, &"Backpack": 0.14, &"Left": 0.2}

var intro: float = 1.0:
	set(value):
		if is_equal_approx(intro, value):
			return
		intro = value
		queue_sort()

## Emitted each frame the intro advances (0..1), so the screen can bring
## its header up in step.
signal intro_progress(t: float)

## Real time, one frame's worth at most per step: neither a loading hitch
## nor a zero time scale can swallow or freeze the motion.
const MAX_STEP := 1.0 / 30.0
var _skip_frames := 0
var _last_usec := 0


func _ready() -> void:
	set_process(false)


## Starts from the hidden state; the first two frames (which carry the
## screen's loading hitch) are skipped before it moves.
func play_intro(still: bool) -> void:
	if still:
		intro = 1.0
		set_process(false)
		intro_progress.emit(1.0)
		return
	intro = 0.0
	_skip_frames = 2
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var step := minf(float(now - _last_usec) / 1000000.0, MAX_STEP)
	_last_usec = now
	if _skip_frames > 0:
		_skip_frames -= 1
		return
	intro = minf(1.0, intro + step / INTRO_TIME)
	intro_progress.emit(intro)
	if intro >= 1.0:
		set_process(false)


func _panel(name_: StringName) -> Control:
	var node := get_node_or_null(NodePath(String(name_))) as Control
	return node if node != null and node.visible else null


func _get_minimum_size() -> Vector2:
	var h := 0.0
	for name_: StringName in [&"Left", &"CartPanel", &"Vendor"]:
		var c := _panel(name_)
		if c != null:
			h = maxf(h, c.get_combined_minimum_size().y)
	var eq := _panel(&"Equipped")
	var bp := _panel(&"Backpack")
	var stack := 0.0
	if eq != null:
		stack += eq.get_combined_minimum_size().y
	if bp != null:
		stack += bp.get_combined_minimum_size().y + (STACK_GAP if eq != null else 0.0)
	h = maxf(h, stack)
	return Vector2(_left_w() + GOODS_W + VENDOR_W + CENTER_MIN + COLUMN_GAP * 3.0, h)


## The ledger column's width: its design width, or more if its content needs
## it (a long Continue label), so it pushes the Balance rather than overlap.
func _left_w() -> float:
	var left := _panel(&"Left")
	if left == null:
		return LEFT_W
	return maxf(LEFT_W, left.get_combined_minimum_size().x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _sort() -> void:
	var w := size.x
	var h := size.y
	var left_w := _left_w()
	var center_w := maxf(CENTER_MIN, w - left_w - GOODS_W - VENDOR_W - COLUMN_GAP * 3.0)
	var x := 0.0
	_place(&"Left", Rect2(x, 0, left_w, h))
	x += left_w + COLUMN_GAP
	var eq := _panel(&"Equipped")
	var eq_h := eq.get_combined_minimum_size().y if eq != null else 0.0
	_place(&"Equipped", Rect2(x, 0, GOODS_W, eq_h))
	var bp_y := eq_h + STACK_GAP if eq != null else 0.0
	_place(&"Backpack", Rect2(x, bp_y, GOODS_W, maxf(0.0, h - bp_y)))
	x += GOODS_W + COLUMN_GAP
	_place(&"CartPanel", Rect2(x, 0, center_w, h))
	x += center_w + COLUMN_GAP
	_place(&"Vendor", Rect2(x, 0, maxf(VENDOR_W, w - x), h))


func _place(name_: StringName, rect: Rect2) -> void:
	var c := _panel(name_)
	if c == null:
		return
	var settle := _settle(name_)
	fit_child_in_rect(c, Rect2(rect.position + Vector2(0.0, RISE * (1.0 - settle)), rect.size))
	c.modulate.a = lerpf(ALPHA_FLOOR, 1.0, settle)


func _settle(name_: StringName) -> float:
	if intro >= 1.0:
		return 1.0
	var t := clampf((intro * INTRO_TIME - float(DELAYS.get(name_, 0.0))) / PANEL_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)
