extends Node
class_name HudHealthController

## The HP bar's sealed state (plan §2.5 healing lock). While healing is locked
## the fill turns the seal colour and a "SEALED Ns" label on the bar itself
## counts the lock down; the moment it lifts, both go. Driven by
## RunEvents.healing_lock_changed: this node does not process at all while
## healing is open. While sealed it reads the seconds off the player once a
## frame instead of keeping its own clock - the HUD keeps processing through
## the bag's pause (PROCESS_MODE_ALWAYS) while the player does not, so a
## local countdown would drift by however long the bag stayed open.

@export var bar_path: NodePath
## Fill colour while sealed - the seal is a state of the bar, not a badge
## beside it.
@export var sealed_fill_color: Color = Color(0.62, 0.30, 0.78, 1.0)
@export var sealed_text_color: Color = Color(0.95, 0.82, 1.0, 1.0)
## Alpha pulse of the countdown label: period in seconds and the trough.
## Held steady at full alpha under the accessibility reduced_motion setting.
@export var pulse_period: float = 1.2
@export_range(0.0, 1.0, 0.05) var pulse_min_alpha: float = 0.55

var _bar: ProgressBar = null
var _label: Label = null
var _player: Node = null
var _plain_fill: StyleBox = null
var _had_fill_override: bool = false
var _left: float = 0.0
var _shown_seconds: int = -1
var _pulse_t: float = 0.0
var _reduced_motion: bool = false


func _ready() -> void:
	_resolve_nodes()
	_bind_events()
	set_process(false)


func _exit_tree() -> void:
	if RunEvents != null and RunEvents.has_signal("healing_lock_changed"):
		var cb := Callable(self, "_on_healing_lock_changed")
		if RunEvents.healing_lock_changed.is_connected(cb):
			RunEvents.healing_lock_changed.disconnect(cb)


func _resolve_nodes() -> void:
	# HealthController is a sibling of TopLeft, so the default uses ../TopLeft/...
	var bp: NodePath = bar_path
	if bp == NodePath():
		bp = NodePath("../TopLeft/Margin/VBox/TopRow/HPRow/HPBar")
	_bar = get_node_or_null(bp) as ProgressBar


func _bind_events() -> void:
	if RunEvents == null or not RunEvents.has_signal("healing_lock_changed"):
		return
	var cb := Callable(self, "_on_healing_lock_changed")
	if not RunEvents.healing_lock_changed.is_connected(cb):
		RunEvents.healing_lock_changed.connect(cb)


func is_sealed() -> bool:
	return is_processing()


func _on_healing_lock_changed(seconds_left: float, _reason: StringName) -> void:
	if _bar == null:
		return
	if seconds_left <= 0.0:
		_clear_seal()
		return
	_left = seconds_left
	if _label == null:
		_build_label()
	if not is_processing():
		# A fresh seal. An extension arrives while already sealed and must
		# not re-read the tinted fill as the plain one to hand back.
		_apply_sealed_fill()
		_player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		_reduced_motion = _reduced_motion_enabled()
		_pulse_t = 0.0
		_label.modulate.a = 1.0
		_label.visible = true
		set_process(true)
	_shown_seconds = -1
	_refresh_seconds()


func _process(delta: float) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("healing_locked_seconds"):
		_left = float(_player.call("healing_locked_seconds"))
	else:
		_left = maxf(_left - delta, 0.0)
	_refresh_seconds()
	if _reduced_motion or _label == null:
		return
	_pulse_t += delta
	# cos: full alpha at the instant of the seal, dipping to the trough at
	# half a period, so the label never appears mid-fade.
	var phase: float = 0.5 + 0.5 * cos(TAU * _pulse_t / maxf(pulse_period, 0.05))
	_label.modulate.a = lerpf(pulse_min_alpha, 1.0, phase)


func _refresh_seconds() -> void:
	if _label == null:
		return
	# The signal clears the seal at 0.0; until it does the bar never says 0.
	var seconds: int = maxi(1, ceili(_left))
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	_label.text = "SEALED %ds" % seconds


func _clear_seal() -> void:
	set_process(false)
	_player = null
	_left = 0.0
	_shown_seconds = -1
	if _label != null:
		_label.visible = false
		_label.modulate.a = 1.0
	_restore_fill()


func _build_label() -> void:
	_label = Label.new()
	_label.name = "HPSeal"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -6.0
	_label.offset_right = -6.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Same face as HPValue beside it; an outline so it reads over the fill.
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", sealed_text_color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 3)
	_label.visible = false
	_bar.add_child(_label)


func _apply_sealed_fill() -> void:
	# hud.gd styles the bar in its own _ready (after this node's), so the
	# fill is read at seal time, not at start, and handed back on lift.
	_had_fill_override = _bar.has_theme_stylebox_override("fill")
	_plain_fill = _bar.get_theme_stylebox("fill")
	var sealed: StyleBoxFlat = null
	if _plain_fill is StyleBoxFlat:
		sealed = (_plain_fill as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		sealed = StyleBoxFlat.new()
	sealed.bg_color = sealed_fill_color
	_bar.add_theme_stylebox_override("fill", sealed)
	_bar.add_theme_stylebox_override("fg", sealed)


func _restore_fill() -> void:
	if _bar == null or _plain_fill == null:
		return
	if _had_fill_override:
		_bar.add_theme_stylebox_override("fill", _plain_fill)
		_bar.add_theme_stylebox_override("fg", _plain_fill)
	else:
		_bar.remove_theme_stylebox_override("fill")
		_bar.remove_theme_stylebox_override("fg")
	_plain_fill = null


func _reduced_motion_enabled() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
