extends Control
class_name ActiveAbilityHUD

@export var player_group: StringName = &"player"

# Look in these player children for effect nodes
@export var runner_node_names: Array[StringName] = [&"SetRunner", &"AugmentRunner"]

# Signal the effect uses to report cooldown
@export var effect_signal: StringName = &"active_cd_changed"

# OPTIONAL: if set, HUD will ONLY bind to effects whose hud_key_text matches this (e.g. "R" or "F")
@export var required_key_text: String = ""

# Fallback text if effect doesn't provide its own
@export var default_key_text: String = "R"
@export var default_title_text: String = "Ability"

@onready var frame: PanelContainer = $Frame
@onready var icon_frame: PanelContainer = $Frame/Margin/RootHBox/IconFrame
@onready var icon: TextureRect = $Frame/Margin/RootHBox/IconFrame/Icon
@onready var title_label: Label = $Frame/Margin/RootHBox/RightVBox/TopRow/AbilityLabel
@onready var key_pill: PanelContainer = $Frame/Margin/RootHBox/RightVBox/TopRow/KeyPill
@onready var key_label: Label = $Frame/Margin/RootHBox/RightVBox/TopRow/KeyPill/KeyLabel
@onready var bar: ProgressBar = $Frame/Margin/RootHBox/RightVBox/BarWrap/CooldownBar
@onready var time_label: Label = $Frame/Margin/RootHBox/RightVBox/BarWrap/TimeLabel
@onready var state_label: Label = $Frame/Margin/RootHBox/RightVBox/StateLabel

var _effect: Node = null
var _frame_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _pill_style: StyleBoxFlat
var _bar_bg: StyleBoxFlat
var _bar_fill: StyleBoxFlat
var _failure_text: String = ""
var _failure_until_ms: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false

	key_label.text = default_key_text
	title_label.text = default_title_text

	_build_styles()
	_set_ready_visual(true)

	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	time_label.text = "READY"

func _process(_dt: float) -> void:
	# If bound effect got freed, unbind
	if _effect != null and not is_instance_valid(_effect):
		_unbind()

	# A bound effect remains authoritative: cooldown alone is not enough for
	# resource-gated set abilities such as Gravemarch Verdict.
	if _effect != null:
		_refresh_authoritative_state()
		return

	var p: Node = get_tree().get_first_node_in_group(player_group)
	if p == null:
		return

	# Find best matching effect among all runners
	var best: Node = null
	var best_priority := -999999

	for rn in runner_node_names:
		var runner: Node = p.get_node_or_null(String(rn))
		if runner == null:
			continue

		for c in runner.get_children():
			var n: Node = c as Node
			if n == null or not is_instance_valid(n):
				continue
			if not n.has_signal(effect_signal):
				continue

			# If HUD is configured for a specific key, filter by effect's hud_key_text
			if required_key_text != "":
				var k := _get_effect_key_text(n)
				if k != required_key_text:
					continue

			var pr := _get_effect_priority(n)
			if pr > best_priority:
				best_priority = pr
				best = n

	if best != null:
		_bind(best)

func _bind(effect: Node) -> void:
	_effect = effect

	var cb := Callable(self, "_on_cd_changed")
	if not _effect.is_connected(effect_signal, cb):
		_effect.connect(effect_signal, cb)
	if _effect.has_signal(&"active_failed"):
		var failed_cb := Callable(self, "_on_active_failed")
		if not _effect.is_connected(&"active_failed", failed_cb):
			_effect.connect(&"active_failed", failed_cb)

	# Pull optional UI fields from effect if present
	var key_txt := _get_effect_key_text(_effect)
	var title_txt := _get_effect_title_text(_effect)
	var icon_tex := _get_effect_icon(_effect)

	key_label.text = key_txt if key_txt != "" else default_key_text
	title_label.text = title_txt if title_txt != "" else default_title_text
	if icon_tex != null:
		icon.texture = icon_tex

	visible = true

	_refresh_authoritative_state()

func _unbind() -> void:
	if _effect != null and is_instance_valid(_effect):
		var cb := Callable(self, "_on_cd_changed")
		if _effect.is_connected(effect_signal, cb):
			_effect.disconnect(effect_signal, cb)
		var failed_cb := Callable(self, "_on_active_failed")
		if _effect.has_signal(&"active_failed") and _effect.is_connected(&"active_failed", failed_cb):
			_effect.disconnect(&"active_failed", failed_cb)

	_effect = null
	visible = false
	_failure_text = ""
	_failure_until_ms = 0

func _refresh_authoritative_state() -> void:
	if _effect == null or not is_instance_valid(_effect):
		return
	if not _effect.has_method("get_active_state"):
		return
	var state: Dictionary = _effect.call("get_active_state") as Dictionary
	var is_ready: bool = bool(state.get("ready", false))
	var cooldown_left: float = float(state.get("cooldown_left", 0.0))
	var cooldown_max: float = float(state.get("cooldown_max", 0.0))
	var resource_value: float = float(state.get("resource_value", 0.0))
	var resource_max: float = float(state.get("resource_max", 0.0))
	if cooldown_left > 0.05 and cooldown_max > 0.0:
		bar.max_value = cooldown_max
		bar.value = clampf(cooldown_max - cooldown_left, 0.0, cooldown_max)
	elif resource_max > 0.0:
		bar.max_value = resource_max
		bar.value = clampf(resource_value, 0.0, resource_max)
	else:
		bar.max_value = 1.0
		bar.value = 1.0 if is_ready else 0.0
	if Time.get_ticks_msec() < _failure_until_ms:
		time_label.text = _failure_text
	else:
		time_label.text = String(state.get("status_text", "READY" if is_ready else "LOCKED"))
	state_label.text = String(state.get("combat_text", ""))
	state_label.visible = state_label.text != ""
	_set_ready_visual(is_ready)

func _on_active_failed(message: String) -> void:
	_failure_text = message.to_upper()
	_failure_until_ms = Time.get_ticks_msec() + 1200

func _on_cd_changed(time_left: float, max_cd: float) -> void:
	if _effect != null and is_instance_valid(_effect) and _effect.has_method("get_active_state"):
		_refresh_authoritative_state()
		return
	# max_cd <= 0 means "ready / idle"
	if max_cd <= 0.0:
		bar.max_value = 1.0
		bar.value = 1.0
		time_label.text = "READY"
		_set_ready_visual(true)
		return

	bar.max_value = max_cd
	bar.value = clampf(max_cd - time_left, 0.0, max_cd)

	var is_ready: bool = time_left <= 0.05
	_set_ready_visual(is_ready)

	time_label.text = "READY" if is_ready else String.num(time_left, 1)

func _get_effect_priority(n: Node) -> int:
	# effect can define: @export var hud_priority: int = 0
	var v = n.get("hud_priority")
	if typeof(v) == TYPE_INT:
		return int(v)
	return 0

func _get_effect_key_text(n: Node) -> String:
	# effect can define: @export var hud_key_text: String = "R"
	var v = n.get("hud_key_text")
	if typeof(v) == TYPE_STRING:
		return String(v)
	return ""

func _get_effect_title_text(n: Node) -> String:
	# effect can define: @export var hud_title_text: String = "Circuit Feedback"
	var v = n.get("hud_title_text")
	if typeof(v) == TYPE_STRING:
		return String(v)
	return ""

func _get_effect_icon(n: Node) -> Texture2D:
	# effect can define: @export var hud_icon: Texture2D
	var v = n.get("hud_icon")
	return v as Texture2D

func _set_ready_visual(is_ready: bool) -> void:
	if is_ready:
		_frame_style.border_color = Color(1.0, 0.55, 0.20)
		_pill_style.bg_color = Color(1.0, 0.55, 0.20, 0.95)
		_pill_style.border_color = Color(1.0, 0.55, 0.20)
		_bar_fill.bg_color = Color(1.0, 0.55, 0.20, 0.95)
		icon.modulate.a = 0.90
	else:
		_frame_style.border_color = Color(0.12, 0.12, 0.12)
		_pill_style.bg_color = Color(0.20, 0.20, 0.20, 0.95)
		_pill_style.border_color = Color(0.12, 0.12, 0.12)
		_bar_fill.bg_color = Color(0.45, 0.45, 0.45, 0.95)
		icon.modulate.a = 0.55

func _build_styles() -> void:
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	_frame_style.set_border_width_all(2)
	_frame_style.border_color = Color(0.12, 0.12, 0.12)
	_frame_style.corner_radius_top_left = 3
	_frame_style.corner_radius_top_right = 3
	_frame_style.corner_radius_bottom_left = 3
	_frame_style.corner_radius_bottom_right = 3
	_frame_style.shadow_size = 10
	_frame_style.shadow_offset = Vector2(0, 6)
	_frame_style.shadow_color = Color(0, 0, 0, 0.40)
	frame.add_theme_stylebox_override("panel", _frame_style)

	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = Color(0.08, 0.08, 0.08, 1.0)
	_icon_style.set_border_width_all(1)
	_icon_style.border_color = Color(0.10, 0.10, 0.10, 1.0)
	_icon_style.corner_radius_top_left = 2
	_icon_style.corner_radius_top_right = 2
	_icon_style.corner_radius_bottom_left = 2
	_icon_style.corner_radius_bottom_right = 2
	icon_frame.add_theme_stylebox_override("panel", _icon_style)

	_pill_style = StyleBoxFlat.new()
	_pill_style.bg_color = Color(0.20, 0.20, 0.20, 0.95)
	_pill_style.set_border_width_all(1)
	_pill_style.border_color = Color(0.12, 0.12, 0.12)
	_pill_style.corner_radius_top_left = 2
	_pill_style.corner_radius_top_right = 2
	_pill_style.corner_radius_bottom_left = 2
	_pill_style.corner_radius_bottom_right = 2
	key_pill.add_theme_stylebox_override("panel", _pill_style)

	_bar_bg = StyleBoxFlat.new()
	_bar_bg.bg_color = Color(0.06, 0.06, 0.06, 1.0)
	_bar_bg.set_border_width_all(1)
	_bar_bg.border_color = Color(0.10, 0.10, 0.10, 1.0)
	_bar_bg.corner_radius_top_left = 2
	_bar_bg.corner_radius_top_right = 2
	_bar_bg.corner_radius_bottom_left = 2
	_bar_bg.corner_radius_bottom_right = 2

	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Color(0.45, 0.45, 0.45, 0.95)
	_bar_fill.corner_radius_top_left = 2
	_bar_fill.corner_radius_top_right = 2
	_bar_fill.corner_radius_bottom_left = 2
	_bar_fill.corner_radius_bottom_right = 2

	bar.add_theme_stylebox_override("background", _bar_bg)
	bar.add_theme_stylebox_override("fill", _bar_fill)
