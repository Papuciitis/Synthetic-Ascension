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
## The veil that withdraws clockwise over the icon as the ability recharges,
## and the whole seconds left, large, on the icon itself.
@onready var sweep: Control = get_node_or_null("Frame/Margin/RootHBox/IconFrame/Sweep") as Control
@onready var icon_count: Label = get_node_or_null("Frame/Margin/RootHBox/IconFrame/IconCount") as Label

const HudStyle := preload("res://ui/widgets/hud/HudStyle.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

## How often the HUD asks an effect for its state, or scans the runners for one
## to bind. A bound effect pushes every change through active_cd_changed, so
## this poll is the safety net for state nothing announces (a resource meter, a
## failure message timing out) - not the thing driving the readout.
const POLL_INTERVAL: float = 0.1
## The ready flare: the plate's rule flashes gold and a soft rim spreads and
## fades, once, when a cooldown completes. Reduced Motion keeps only the
## colour change.
const FLARE_TIME: float = 0.6

var _effect: Node = null
var _poll_accum: float = 0.0
## State polls since this HUD was built. The idle-cost pin reads it.
var _polls: int = 0
var _failure_text: String = ""
var _failure_until_ms: int = 0
## -1 never painted, 0 cooling, 1 ready: the plate's look is written only when
## this changes, not on every cooldown tick an effect announces.
var _shown_ready: int = -1
var _shown_count: int = -1
var _flare: Control = null
var _flare_amount: float = 0.0
var _flare_tween: Tween = null

static var _styles: Dictionary = {}

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

func _process(dt: float) -> void:
	# If bound effect got freed, unbind
	if _effect != null and not is_instance_valid(_effect):
		_unbind()

	# Bound, this allocated a state Dictionary and rewrote two bars and two
	# labels every frame; unbound, it walked the children of two runners with
	# has_signal every frame. Neither answer changes 60 times a second.
	_poll_accum += dt
	if _poll_accum < POLL_INTERVAL:
		return
	_poll_accum = 0.0
	_polls += 1

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

## State polls since this HUD was built (perf pin).
func debug_poll_count() -> int:
	return _polls


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
	# A reused slot HUD can be re-configured to a different ability without a
	# rebind (equipping a new Q/V re-titles the same AscensionSlotHud), so the
	# poll re-reads identity too — a stale label executing a new ability was a
	# playtest finding. Cheap: this runs at POLL_INTERVAL, not per frame.
	var title_now := _get_effect_title_text(_effect)
	if title_now != "" and title_label.text != title_now:
		title_label.text = title_now
		var icon_now := _get_effect_icon(_effect)
		if icon_now != null:
			icon.texture = icon_now
		var key_now := _get_effect_key_text(_effect)
		key_label.text = key_now if key_now != "" else default_key_text
	if not _effect.has_method("get_active_state"):
		return
	var state: Dictionary = _effect.call("get_active_state") as Dictionary
	var is_ready: bool = bool(state.get("ready", false))
	var cooldown_left: float = float(state.get("cooldown_left", 0.0))
	var cooldown_max: float = float(state.get("cooldown_max", 0.0))
	var resource_value: float = float(state.get("resource_value", 0.0))
	var resource_max: float = float(state.get("resource_max", 0.0))
	_update_sweep(cooldown_left, cooldown_max)
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
		_update_sweep(0.0, 0.0)
		_set_ready_visual(true)
		return

	bar.max_value = max_cd
	bar.value = clampf(max_cd - time_left, 0.0, max_cd)
	_update_sweep(time_left, max_cd)

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
	var state := 1 if is_ready else 0
	if state == _shown_ready:
		return
	var was_cooling := _shown_ready == 0
	_shown_ready = state
	frame.add_theme_stylebox_override("panel", _style(&"plate_ready" if is_ready else &"plate"))
	key_pill.add_theme_stylebox_override("panel", _style(&"key_ready" if is_ready else &"key"))
	bar.add_theme_stylebox_override("fill", _style(&"bar_ready" if is_ready else &"bar"))
	key_label.add_theme_color_override("font_color", HudStyle.GOLD_BRIGHT if is_ready else HudStyle.MUTED)
	time_label.add_theme_color_override("font_color", HudStyle.GOLD_BRIGHT if is_ready else HudStyle.PARCHMENT)
	icon.modulate = Color(1, 1, 1, 1) if is_ready else Color(0.78, 0.74, 0.70, 1)
	if is_ready:
		_update_sweep(0.0, 0.0)
	if is_ready and was_cooling and visible:
		_play_flare()


## The icon's veil and its big count, from the same numbers the bar shows.
func _update_sweep(cooldown_left: float, cooldown_max: float) -> void:
	var remaining := 0.0
	if cooldown_left > 0.05 and cooldown_max > 0.0:
		remaining = clampf(cooldown_left / cooldown_max, 0.0, 1.0)
	if sweep != null:
		sweep.set("fraction", remaining)
	if icon_count == null:
		return
	var count := ceili(cooldown_left) if remaining > 0.0 else 0
	if count == _shown_count:
		return
	_shown_count = count
	icon_count.visible = count > 0
	if count > 0:
		icon_count.text = str(count)


func _play_flare() -> void:
	if ArcaneMotion.reduced() or _flare == null:
		return
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	_flare_amount = 1.0
	_flare.visible = true
	_flare.queue_redraw()
	_flare_tween = create_tween().set_ignore_time_scale(true)
	_flare_tween.tween_method(_set_flare, 1.0, 0.0, FLARE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_flare(value: float) -> void:
	_flare_amount = value
	if _flare == null:
		return
	_flare.visible = value > 0.001
	_flare.queue_redraw()


func _draw_flare() -> void:
	if _flare == null or _flare_amount <= 0.0:
		return
	var rect := Rect2(Vector2.ZERO, _flare.size)
	var spread := (1.0 - _flare_amount) * 7.0
	for i in range(4):
		var grow := spread + float(i) * 2.0
		_flare.draw_rect(rect.grow(grow), Color(HudStyle.GOLD_BRIGHT, 0.22 * _flare_amount * float(4 - i) / 4.0), false, 2.0)
	_flare.draw_rect(Rect2(Vector2(0.5, 0.5), rect.size - Vector2.ONE), Color(HudStyle.GOLD_BRIGHT, _flare_amount), false, 1.0)
	var top := Vector2(rect.size.x * 0.5, 0.5)
	var r := 4.0 + 3.0 * _flare_amount
	_flare.draw_colored_polygon(HudStyle.diamond(top, r), Color(HudStyle.GOLD_BRIGHT, _flare_amount))


## Shared plates for every ability HUD, built once.
static func _style(key: StringName) -> StyleBox:
	if _styles.has(key):
		return _styles[key]
	var sb: StyleBox = null
	match key:
		&"plate", &"plate_ready":
			var p := StyleBoxFlat.new()
			p.bg_color = Color(HudStyle.PANEL, 0.9)
			p.set_border_width_all(1)
			p.set_corner_radius_all(1)
			p.shadow_color = Color(0, 0, 0, 0.5)
			p.shadow_size = 12
			p.shadow_offset = Vector2(0, 5)
			if key == &"plate_ready":
				p.border_color = Color(HudStyle.GOLD, 0.95)
				p.shadow_color = Color(1.0, 0.62, 0.3, 0.12)
				p.shadow_size = 10
				p.shadow_offset = Vector2.ZERO
			else:
				p.border_color = Color(0.52, 0.39, 0.24, 0.6)
			sb = p
		&"well":
			var w := StyleBoxFlat.new()
			w.bg_color = Color(0.012, 0.010, 0.009, 1.0)
			w.set_border_width_all(1)
			w.border_color = Color(0.62, 0.47, 0.30, 0.75)
			w.set_corner_radius_all(1)
			w.set_content_margin_all(2.0)
			sb = w
		&"key", &"key_ready":
			var k := StyleBoxFlat.new()
			k.set_border_width_all(1)
			k.set_corner_radius_all(1)
			k.content_margin_left = 6.0
			k.content_margin_right = 6.0
			k.content_margin_top = 1.0
			k.content_margin_bottom = 1.0
			if key == &"key_ready":
				k.bg_color = Color(0.2, 0.13, 0.062, 0.95)
				k.border_color = HudStyle.GOLD
			else:
				k.bg_color = Color(0.05, 0.04, 0.03, 0.9)
				k.border_color = Color(HudStyle.GOLD_DIM, 0.6)
			sb = k
		&"bar_bg":
			var b := StyleBoxFlat.new()
			b.bg_color = Color(0.012, 0.010, 0.009, 0.9)
			b.set_border_width_all(1)
			b.border_color = Color(0.52, 0.39, 0.24, 0.5)
			b.set_corner_radius_all(1)
			sb = b
		&"bar", &"bar_ready":
			var f := StyleBoxFlat.new()
			f.set_corner_radius_all(1)
			f.border_width_top = 1
			f.border_blend = true
			if key == &"bar_ready":
				f.bg_color = Color(0.5, 0.33, 0.15, 0.95)
				f.border_color = Color(HudStyle.GOLD_BRIGHT, 0.7)
			else:
				f.bg_color = Color(0.46, 0.34, 0.2, 0.9)
				f.border_color = Color(HudStyle.GOLD, 0.55)
			sb = f
	_styles[key] = sb
	return sb


func _build_styles() -> void:
	icon_frame.add_theme_stylebox_override("panel", _style(&"well"))
	bar.add_theme_stylebox_override("background", _style(&"bar_bg"))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_flare = Control.new()
	_flare.name = "ReadyFlare"
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare.visible = false
	_flare.draw.connect(_draw_flare)
	frame.add_child(_flare)
