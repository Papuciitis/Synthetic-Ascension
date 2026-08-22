@static_unload
extends Control
class_name AugmentActiveBadge

@export var player_group: StringName = &"player"
@export var runner_node_name: StringName = &"AugmentRunner" # can be a direct child name or a path-like name
@export var effect_signal: StringName = &"active_cd_changed"
@export var slot_index: int = 0

# Path to the slot PanelContainer (we use it to hide badge when slot empty)
@export var slot_owner_path: NodePath

# How often we rescan runner children for the "best" effect (handles swaps reliably)
@export var rebind_interval: float = 0.15

# Keep signal connection even when slot UI is empty (prevents missing the first CD signal during swaps)
@export var keep_bound_when_slot_empty: bool = true

@onready var frame: PanelContainer = $Frame
@onready var cd: TextureProgressBar = $Frame/Root/Cooldown
@onready var label: Label = $Frame/Root/KeyLabel
@export var border_ready: Color = Color(1.0, 0.55, 0.20, 1.0)
@export var border_cooldown: Color = Color(0.12, 0.12, 0.12, 1.0)

@export var wedge_full: Color = Color(1.0, 0.55, 0.20, 0.75)  # start of cooldown
@export var wedge_empty: Color = Color(0.7, 0.7, 0.7, 0.20)   # near ready

@export var ui_blend_speed: float = 12.0

var _target_ready: bool = true
var _ready_blend: float = 1.0



var _player: Node = null
var _runner: Node = null
var _effect: Node = null

var _frame_style: StyleBoxFlat = null
var _base_text: String = ""

var _scan_timer: float = 0.0

# last known cooldown state (we locally tick it down)
var _time_left: float = 0.0
var _max_cd: float = 0.0

static var _circle_tex: Texture2D = null


static func release_static_caches() -> void:
	# Shutdown-order mitigation: drop the RID-backed texture before script
	# server teardown outlives rendering cleanup.
	_circle_tex = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Keep frame also shrink + clip children so the CD can't overflow
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size = custom_minimum_size
	frame.clip_contents = true

	# Default invisible until slot actually has something (but we may still bind internally)
	visible = false

	# Per-instance stylebox
	var sb: StyleBox = frame.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		_frame_style = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		frame.add_theme_stylebox_override("panel", _frame_style)

	_setup_cd_visuals()
	_set_ready_visual(true)

	# Try binding ASAP (so we don't miss early cooldown signals)
	_refresh_player_and_runner()
	_rescan_and_rebind(true)

func _process(dt: float) -> void:
	# Keep references valid
	if _player == null or not is_instance_valid(_player):
		_player = null
		_runner = null
		_effect = null
		_refresh_player_and_runner()
	elif _runner == null or not is_instance_valid(_runner):
		_runner = null
		_refresh_player_and_runner()

	# Periodic rescan for best effect (handles swaps / node replacement / priority changes)
	_scan_timer -= dt
	if _scan_timer <= 0.0:
		_scan_timer = rebind_interval
		_rescan_and_rebind(false)

	# If effect got freed, detach
	if _effect != null and not is_instance_valid(_effect):
		_unbind()

	# Slot empty logic: hide badge, but optionally KEEP connection to avoid missing signals during swaps
	var empty := _is_slot_empty()
	if empty:
		visible = false
		if not keep_bound_when_slot_empty:
			_unbind()
	else:
		visible = (_effect != null)

	# Local countdown tick (smooth + works even if effect emits rarely)
	if _max_cd > 0.0 and _time_left > 0.0:
		_time_left = maxf(_time_left - dt, 0.0)
		_apply_cd_state()
		
	var target: float = 1.0 if _target_ready else 0.0
	_ready_blend = move_toward(_ready_blend, target, ui_blend_speed * dt)
	_apply_ready_blend()


func _setup_cd_visuals() -> void:
	# ✅ smooth scaling (kills pixelated look)
	cd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Use a higher-res circle so radial edges look cleaner
	var tex: Texture2D = _get_circle_texture(256) # try 512 if you want even smoother
	cd.texture_progress = tex
	cd.texture_under = null
	_try_set_cd_color_property(&"tint_under", Color(0, 0, 0, 0))

	# Stretch to rect (prevents corner-crop)
	cd.nine_patch_stretch = true
	cd.stretch_margin_left = 0
	cd.stretch_margin_top = 0
	cd.stretch_margin_right = 0
	cd.stretch_margin_bottom = 0

	cd.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	cd.min_value = 0.0
	cd.max_value = 1.0
	cd.value = 0.0

	_try_set_cd_float_property(&"radial_initial_angle", -90.0)
	_try_set_cd_float_property(&"radial_fill_degrees", 360.0)

func _apply_ready_blend() -> void:
	if _frame_style == null:
		return

	_frame_style.border_color = border_cooldown.lerp(border_ready, _ready_blend)

	# Fade the pie out as it becomes ready
	var cd_alpha: float = 1.0 - _ready_blend
	cd.modulate = Color(1, 1, 1, cd_alpha)
	cd.visible = cd_alpha > 0.02

	# Slight label pop when ready
	var a: float = lerpf(0.85, 1.0, _ready_blend)
	label.modulate = Color(1, 1, 1, a)


func _refresh_player_and_runner() -> void:
	_player = get_tree().get_first_node_in_group(player_group)
	if _player == null:
		return
	_runner = _resolve_runner(_player)

func _resolve_runner(p: Node) -> Node:
	# Try as a node path first (fast, works if it's a direct child or real path)
	var r: Node = p.get_node_or_null(String(runner_node_name))
	if r != null:
		return r
	# Fallback: search by name anywhere under player (handles reorganized scene trees)
	return p.find_child(String(runner_node_name), true, false)

func _rescan_and_rebind(force: bool) -> void:
	if _runner == null or not is_instance_valid(_runner):
		return

	var best: Node = _find_best_effect_for_slot(_runner, slot_index)
	if best == _effect and not force:
		return

	# Switch binding if needed
	if best != _effect:
		_unbind()
		if best != null:
			_bind(best)

func _try_set_cd_color_property(prop: StringName, value: Color) -> void:
	for d in cd.get_property_list():
		var dd: Dictionary = d
		if StringName(dd.get("name", "")) == prop:
			cd.set(prop, value)
			return

func _try_set_cd_int_property(prop: StringName, value: int) -> void:
	for d in cd.get_property_list():
		var dd: Dictionary = d
		if StringName(dd.get("name", "")) == prop:
			cd.set(prop, value)
			return


func _find_best_effect_for_slot(runner: Node, wanted_slot: int) -> Node:
	var best: Node = null
	var best_pr: int = -999999

	for n: Node in runner.get_children():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_signal(effect_signal):
			continue

		var si: int = int(n.get_meta("hud_slot_index", -1))
		if si != wanted_slot:
			continue

		var pr := 0
		var pv: Variant = n.get("hud_priority")
		if typeof(pv) == TYPE_INT:
			pr = int(pv)

		if pr > best_pr:
			best_pr = pr
			best = n

	return best

func _bind(effect: Node) -> void:
	_effect = effect

	var cb := Callable(self, "_on_cd_changed")
	if not _effect.is_connected(effect_signal, cb):
		_effect.connect(effect_signal, cb)

	# Prefer effect's hud_key_text (AugmentRunner should set to "1/2/3")
	var key_txt := ""
	var v: Variant = _effect.get("hud_key_text")
	if typeof(v) == TYPE_STRING:
		key_txt = String(v)

	_base_text = key_txt if key_txt != "" else label.text
	label.text = _base_text

	# Best-effort: pull current state immediately (prevents "missed first signal" bugs)
	_pull_initial_cd_state_from_effect()
	_apply_cd_state()

func _unbind() -> void:
	if _effect != null and is_instance_valid(_effect):
		var cb := Callable(self, "_on_cd_changed")
		if _effect.is_connected(effect_signal, cb):
			_effect.disconnect(effect_signal, cb)

	_effect = null
	_time_left = 0.0
	_max_cd = 0.0
	_set_ready_visual(true)

func _on_cd_changed(time_left: float, max_cd: float) -> void:
	_time_left = float(time_left)
	_max_cd = float(max_cd)
	_apply_cd_state()

func _apply_cd_state() -> void:
	# Ready / no cooldown
	if _time_left <= 0.0 and _max_cd <= 0.0:
		cd.value = 0.0
		label.text = _base_text
		_set_ready_visual(true)
		return

	# If max_cd is missing but time_left exists, still show "cooling down"
	if _max_cd <= 0.0 and _time_left > 0.0:
		cd.value = 1.0
		cd.queue_redraw()
		_set_ready_visual(false)
		label.text = str(int(ceil(_time_left)))
		return

	var ratio: float = clampf(_time_left / _max_cd, 0.0, 1.0)
	cd.value = ratio
	cd.queue_redraw()

	# ✅ gradual tint shift as it approaches ready
	cd.tint_progress = wedge_full.lerp(wedge_empty, 1.0 - ratio)

	var is_ready: bool = _time_left <= 0.05
	_target_ready = is_ready  # ✅ for smooth fade/border blend (instead of snapping)


	if is_ready:
		label.text = _base_text
	else:
		label.text = str(int(ceil(_time_left)))

func _set_ready_visual(is_ready: bool) -> void:
	if _frame_style == null:
		return

	if is_ready:
		_frame_style.border_color = Color(1.0, 0.55, 0.20, 1.0)
		cd.visible = false
		label.modulate = Color(1, 1, 1, 1)
	else:
		_frame_style.border_color = Color(0.12, 0.12, 0.12, 1.0)
		cd.visible = true
		label.modulate = Color(1, 1, 1, 0.85)

func _is_slot_empty() -> bool:
	if slot_owner_path == NodePath():
		return false

	var slot_node: Node = get_node_or_null(slot_owner_path)
	if slot_node == null:
		return false

	var icon: TextureRect = slot_node.get_node_or_null("Content/Icon") as TextureRect
	var nm: Label = slot_node.get_node_or_null("Content/NameStrip/Name") as Label

	var empty_icon := (icon == null) or (icon.texture == null)
	var empty_name := (nm == null) or (nm.text.strip_edges() == "")

	return empty_icon and empty_name

func _try_set_cd_float_property(prop: StringName, value: float) -> void:
	for d in cd.get_property_list():
		var dd: Dictionary = d
		if StringName(dd.get("name", "")) == prop:
			cd.set(prop, value)
			return

static func _get_circle_texture(tex_size: int) -> Texture2D:
	if _circle_tex != null:
		return _circle_tex

	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx: float = (tex_size - 1) * 0.5
	var cy: float = (tex_size - 1) * 0.5
	var r: float = (tex_size * 0.5) - 1.0
	var feather: float = 1.25 # edge softness in pixels

	for y in range(tex_size):
		for x in range(tex_size):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var dist: float = sqrt(dx * dx + dy * dy)

			# alpha 1 inside, smoothly fades to 0 across 'feather' pixels
			var a: float = clampf((r + feather - dist) / feather, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))

	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex


func _pull_initial_cd_state_from_effect() -> void:
	if _effect == null or not is_instance_valid(_effect):
		return

	# Returns -1.0 if missing
	var tl: float = _read_number_from_effect_float([
		&"active_time_left", &"active_cd_left", &"cd_left", &"cooldown_left", &"time_left", &"cooldown_time_left"
	])
	var mx: float = _read_number_from_effect_float([
		&"active_max_cd", &"active_cd_max", &"cd_max", &"cooldown_max", &"max_cd", &"cooldown_duration"
	])

	if tl >= 0.0:
		_time_left = tl
	if mx > 0.0:
		_max_cd = mx


func _read_number_from_effect_float(names: Array[StringName]) -> float:
	# -1.0 means "not found"
	if _effect == null or not is_instance_valid(_effect):
		return -1.0

	for n: StringName in names:
		var v: Variant = _effect.get(n)
		var t: int = typeof(v)
		if t == TYPE_INT or t == TYPE_FLOAT:
			return float(v)

	return -1.0
