extends Control
class_name HudDangerOverlay

## The screen telling the player they are in danger (audit 2026-10-04,
## change 6). At or below 30% health the screen's edges pulse red - alpha
## 0.25 to 0.45 at 1.1 Hz - and a heartbeat sounds once per pulse, -14 dB at
## 30% rising to -8 dB at 15% and below. Reduced Motion holds the vignette
## steady; the heartbeat stays (it is sound, not motion).
##
## Full-rect and mouse-transparent, under the HUD panels. It reads the player
## once a frame and draws nothing at all while health is fine.

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

var _vignette_texture: GradientTexture2D = null
var _player_ref: WeakRef = null
var _low := false
var _ratio := 1.0
var _pulse := 0.0
var _alpha := 0.0
var _beats := 0
var _idle_accum := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_texture = _build_vignette()
	set_process(true)


func _process(delta: float) -> void:
	if not _low:
		_idle_accum += delta
		if _idle_accum < IDLE_POLL_SECONDS:
			return
		_idle_accum = 0.0
	var player := _player()
	var ratio := 1.0
	var alive := false
	if player != null:
		var max_hp := float(player.get("max_hp"))
		alive = not bool(player.get("is_dead"))
		if max_hp > 0.0:
			ratio = clampf(float(player.get("hp")) / max_hp, 0.0, 1.0)
	var low := alive and ratio > 0.0 and ratio <= LOW_HP_RATIO
	_ratio = ratio
	if low != _low:
		_low = low
		_pulse = 0.0
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
