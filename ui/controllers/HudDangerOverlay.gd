extends Control
class_name HudDangerOverlay

## The screen telling the player they are in danger (audit 2026-10-04,
## change 6). At or below 30% health the screen's edges pulse red - alpha
## 0.25 to 0.45 at 1.1 Hz - and a heartbeat sounds once per pulse, -14 dB at
## 30% rising to -8 dB at 15% and below. Reduced Motion holds the vignette
## steady; the heartbeat stays (it is sound, not motion).
##
## A Sniper winding up its shot from off-screen (perches sit 1,510-1,819 px
## out, beyond the 960 px half-screen) gets a red pip on the screen edge,
## pointing at it, for as long as it aims (change 7). At most MAX_SNIPER_PIPS.
##
## Full-rect and mouse-transparent, under the HUD panels. It draws nothing at
## all while health is fine and no sniper aims, and until then reads the
## player and the aiming group ten times a second.

const LOW_HP_RATIO := 0.30
const CRITICAL_HP_RATIO := 0.15
const PULSE_HZ := 1.1
const ALPHA_MIN := 0.25
const ALPHA_MAX := 0.45
const STEADY_ALPHA := 0.35
const HEARTBEAT_ID := &"player_heartbeat"
## Added to the manifest's -14 dB: +0 at 30% health, +6 at 15% and below.
const HEARTBEAT_GAIN_DB := 6.0
const VIGNETTE_COLOUR := Color(0.78, 0.04, 0.03, 1.0)
## While health is fine the player is read ten times a second, not every
## frame: nothing is drawn, so nothing needs the frame.
const IDLE_POLL_SECONDS := 0.1
const SNIPER_GROUP := &"enemy_sniper_aiming"
const MAX_SNIPER_PIPS := 4
const PIP_INSET := 26.0
const PIP_SIZE := 13.0
const PIP_COLOUR := Color(1.0, 0.24, 0.14, 1.0)

var _vignette_texture: GradientTexture2D = null
var _player_ref: WeakRef = null
var _low := false
var _ratio := 1.0
var _pulse := 0.0
var _alpha := 0.0
var _beats := 0
var _idle_accum := 0.0
var _pips := PackedVector2Array()
var _pip_dirs := PackedVector2Array()
var _pip_clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_texture = _build_vignette()
	set_process(true)


func _process(delta: float) -> void:
	if not _low and _pips.is_empty():
		_idle_accum += delta
		if _idle_accum < IDLE_POLL_SECONDS:
			return
		_idle_accum = 0.0
	_update_sniper_pips(delta)
	var player := _player()
	var ratio := 1.0
	var alive := false
	if player != null:
		var max_raw: Variant = player.get("max_hp")
		var hp_raw: Variant = player.get("hp")
		alive = player.get("is_dead") != true
		if (max_raw is float or max_raw is int) and (hp_raw is float or hp_raw is int) and float(max_raw) > 0.0:
			ratio = clampf(float(hp_raw) / float(max_raw), 0.0, 1.0)
	var low := alive and ratio > 0.0 and ratio <= LOW_HP_RATIO
	_ratio = ratio
	if low != _low:
		_low = low
		_pulse = 0.0
		_alpha = ALPHA_MIN
		queue_redraw()
		if low:
			_heartbeat()
	if not _low:
		return
	# A paused tree (the bag, a reconstruction card) holds the pulse and its
	# heartbeat where they are.
	if get_tree() != null and get_tree().paused:
		return
	var before := _pulse
	_pulse += delta * PULSE_HZ
	if floorf(_pulse) > floorf(before):
		_heartbeat()
	var alpha := STEADY_ALPHA if _reduced_motion() else lerpf(ALPHA_MIN, ALPHA_MAX, pulse_envelope(_pulse))
	if not is_equal_approx(alpha, _alpha):
		_alpha = alpha
		queue_redraw()


func _draw() -> void:
	if _low and _vignette_texture != null:
		var colour := VIGNETTE_COLOUR
		colour.a = _alpha
		draw_texture_rect(_vignette_texture, Rect2(Vector2.ZERO, size), false, colour)
	if not _pips.is_empty():
		var pip_alpha := 1.0 if _reduced_motion() else 0.7 + 0.3 * sin(_pip_clock * TAU * 3.0)
		for i in range(_pips.size()):
			_draw_pip(_pips[i], _pip_dirs[i], pip_alpha)


## One pip: a solid triangle pointing at the sniper with a dark rim, so it
## reads on bright ground and on the red vignette alike.
func _draw_pip(at: Vector2, dir: Vector2, alpha: float) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * PIP_SIZE
	var back := at - dir * PIP_SIZE * 0.6
	var points := PackedVector2Array([tip, back + side * PIP_SIZE * 0.85, back - side * PIP_SIZE * 0.85])
	var rim := PackedVector2Array([tip + dir * 2.5, back + side * (PIP_SIZE * 0.85 + 2.5) - dir * 1.5, back - side * (PIP_SIZE * 0.85 + 2.5) - dir * 1.5])
	draw_colored_polygon(rim, Color(0.05, 0.02, 0.02, 0.75 * alpha))
	draw_colored_polygon(points, Color(PIP_COLOUR.r, PIP_COLOUR.g, PIP_COLOUR.b, alpha))


## Edge pips for snipers aiming from outside the view.
func _update_sniper_pips(delta: float) -> void:
	var had := _pips.size()
	_pips.clear()
	_pip_dirs.clear()
	var tree := get_tree()
	if tree == null:
		return
	var aimers := tree.get_nodes_in_group(SNIPER_GROUP)
	if aimers.is_empty():
		if had > 0:
			queue_redraw()
		return
	_pip_clock += delta
	var view := get_viewport()
	if view == null:
		return
	var to_screen := view.get_canvas_transform()
	var rect := Rect2(Vector2.ZERO, size)
	var centre := rect.size * 0.5
	var inner := rect.grow(-PIP_INSET)
	for node in aimers:
		if _pips.size() >= MAX_SNIPER_PIPS:
			break
		var sniper := node as Node2D
		if sniper == null or not sniper.is_inside_tree():
			continue
		var on_screen := to_screen * sniper.global_position
		if rect.has_point(on_screen):
			continue
		var dir := (on_screen - centre).normalized()
		if dir == Vector2.ZERO:
			continue
		_pips.append(edge_point(inner, centre, dir))
		_pip_dirs.append(dir)
	if had > 0 or not _pips.is_empty():
		queue_redraw()


## Where a ray from `centre` along `dir` leaves `inner`.
static func edge_point(inner: Rect2, centre: Vector2, dir: Vector2) -> Vector2:
	var half := inner.size * 0.5
	var tx := INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
	var ty := INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
	return centre + dir * minf(tx, ty)


func sniper_pips() -> PackedVector2Array:
	return _pips


## The vignette swells with each heartbeat: a fast rise (0.08 of a cycle)
## then a decay that is nearly spent by the next beat, so sound and screen
## pulse together.
static func pulse_envelope(pulse: float) -> float:
	var phase := pulse - floorf(pulse)
	var rise := clampf(phase / 0.08, 0.0, 1.0)
	return rise * exp(-maxf(phase - 0.08, 0.0) * 3.5)


func is_low_health_shown() -> bool:
	return _low


func vignette_alpha() -> float:
	return _alpha if _low else 0.0


func heartbeats() -> int:
	return _beats


## The heartbeat's level for the current health: louder as it falls.
func heartbeat_gain_db() -> float:
	var depth := clampf((LOW_HP_RATIO - _ratio) / (LOW_HP_RATIO - CRITICAL_HP_RATIO), 0.0, 1.0)
	return HEARTBEAT_GAIN_DB * depth


func _heartbeat() -> void:
	_beats += 1
	if SfxManager != null:
		SfxManager.play_global(HEARTBEAT_ID, heartbeat_gain_db())


func _player() -> Node2D:
	if _player_ref != null:
		var cached := _player_ref.get_ref() as Node2D
		if cached != null and cached.is_inside_tree():
			return cached
	var tree := get_tree()
	if tree == null:
		return null
	var found := tree.get_first_node_in_group(&"player") as Node2D
	_player_ref = weakref(found) if found != null else null
	return found


func _reduced_motion() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))


## Clear in the middle, red only toward the rim: a radial gradient stretched
## over the screen, drawn as one textured rect (no shader to compile).
static func _build_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 1.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
