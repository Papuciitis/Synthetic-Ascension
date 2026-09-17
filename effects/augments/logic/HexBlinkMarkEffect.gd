extends Node
class_name HexBlinkMarkEffect

signal active_cd_changed(time_left: float, max_cd: float)

@export var hud_priority: int = 10
@export var hud_key_text: String = ""
@export var hud_title_text: String = "Hex Blink"
@export var hud_icon: Texture2D

# Default fallback action
@export var active_action: StringName = &"augment_active"

@export var debug_prints: bool = false

@export var blink_range: float = 320.0
@export var active_base_cd: float = 6.0

@export var mark_duration: float = 6.0
@export var marked_shots: int = 1

@export var bonus_d8_count: int = 2
@export var bonus_power_scale: float = 12.0
@export var bonus_flat: float = 0.0

# VFX (assign in the effect scene inspector)
@export var vfx_blink_scene: PackedScene
@export var vfx_mark_scene: PackedScene

var player: Node2D = null

var _cd: float = 0.0
var _cd_max: float = 6.0
var _mark_left: float = 0.0
var _mark_vfx: Node = null
var _last_report: float = -999.0
var _warned_missing_action: bool = false

func setup(p: Node) -> void:
	player = p as Node2D

func _ready() -> void:
	set_process(true)

	_cd_max = active_base_cd
	_resolve_action_from_slot()

	if debug_prints:
		print("[HexBlink] READY. action=", String(active_action),
			" has_action=", InputMap.has_action(String(active_action)),
			" slot_meta=", get_meta("hud_slot_index", -1))

	_report_cd(true)

func _exit_tree() -> void:
	_cleanup_mark_vfx()

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if not InputMap.has_action(String(active_action)):
		if debug_prints and not _warned_missing_action:
			_warned_missing_action = true
			print("[HexBlink] Missing InputMap action:", String(active_action),
				" (add augment_active or augment_active_1/2/3 in Project Settings > Input Map)")
		return

	if _cd > 0.0:
		_cd = max(_cd - dt, 0.0)

	if _mark_left > 0.0:
		_mark_left = max(_mark_left - dt, 0.0)
		if _mark_left <= 0.0:
			_clear_mark()

	if not Global.active_augment_input_blocked(int(get_meta("hud_slot_index", -1))) and Input.is_action_just_pressed(active_action):
		if debug_prints:
			print("[HexBlink] pressed. cd=", _cd)
		_try_cast()

	_report_cd(false)

func _try_cast() -> void:
	if _cd > 0.0:
		if debug_prints:
			print("[HexBlink] blocked by cd:", _cd)
		return

	var origin: Vector2 = player.global_position
	var dest: Vector2 = _clamped_mouse_point()

	# Blink
	player.global_position = dest

	# VFX burst
	_spawn_blink_vfx(origin)
	_spawn_blink_vfx(dest)

	# Apply mark to next ranged shot(s)
	_mark_left = mark_duration
	player.set_meta("hex_mark_shots_left", int(max(1, marked_shots)))
	player.set_meta("hex_mark_d8_count", int(max(1, bonus_d8_count)))
	player.set_meta("hex_mark_power_scale", float(bonus_power_scale))
	player.set_meta("hex_mark_flat", float(bonus_flat))

	_spawn_mark_vfx()

	# Cooldown with “1d10 > 9” refund => only 10 refunds
	_cd_max = Global.doctrine_active_cooldown(active_base_cd)
	_cd = _cd_max
	Global.notify_active_augment_used(int(get_meta("hud_slot_index", -1)))
	var r: int = randi_range(1, 10)
	if r >= 10:
		if debug_prints:
			print("[HexBlink] refund! (1d10=", r, ")")
		_cd = 0.0

	_report_cd(true)

func _clamped_mouse_point() -> Vector2:
	# Aim-aware: on controller the mouse cursor is a stale screen point with
	# no relation to where the player is aiming — blinking toward it read
	# as a random teleport. The player's aim state resolves both devices.
	var aim: Vector2 = player.get_global_mouse_position()
	if player.has_method("_current_aim_target"):
		aim = player.call("_current_aim_target")
	var mouse: Vector2 = aim
	var dir: Vector2 = mouse - player.global_position
	var d: float = dir.length()
	if d <= 0.001:
		return player.global_position
	if d > blink_range:
		dir = dir / d
		return player.global_position + dir * blink_range
	return mouse

func _spawn_blink_vfx(pos: Vector2) -> void:
	if vfx_blink_scene == null:
		return
	var n: Node2D = vfx_blink_scene.instantiate() as Node2D
	if n == null:
		return
	get_tree().current_scene.add_child(n)
	n.global_position = pos

func _spawn_mark_vfx() -> void:
	_cleanup_mark_vfx()

	if vfx_mark_scene == null:
		return
	if player == null:
		return

	var hb: Area2D = player.get_node_or_null("Hurtbox") as Area2D
	if hb == null:
		return

	var n: Node = vfx_mark_scene.instantiate()
	if n == null:
		return

	# Parent to player so it follows and gets cleaned with player
	player.add_child(n)
	_mark_vfx = n

	if n.has_method("setup"):
		# pass hurtbox + player + duration
		n.call("setup", hb, player, mark_duration)

func _cleanup_mark_vfx() -> void:
	if _mark_vfx != null and is_instance_valid(_mark_vfx):
		_mark_vfx.queue_free()
	_mark_vfx = null

func _clear_mark() -> void:
	if player == null:
		return

	if player.has_meta("hex_mark_shots_left"):
		player.remove_meta("hex_mark_shots_left")
	if player.has_meta("hex_mark_d8_count"):
		player.remove_meta("hex_mark_d8_count")
	if player.has_meta("hex_mark_power_scale"):
		player.remove_meta("hex_mark_power_scale")
	if player.has_meta("hex_mark_flat"):
		player.remove_meta("hex_mark_flat")

	_cleanup_mark_vfx()

func _resolve_action_from_slot() -> void:
	# Prefer augment_active_<slot> if slot meta exists.
	var slot_var: Variant = get_meta("hud_slot_index", -1)
	var slot: int = -1
	if typeof(slot_var) == TYPE_INT:
		slot = int(slot_var)

	if slot >= 0:
		var candidate: StringName = StringName("augment_active_%d" % (slot + 1))
		if InputMap.has_action(String(candidate)):
			active_action = candidate
			if hud_key_text == "":
				hud_key_text = str(slot + 1)
			return

	# fallback: if chosen action doesn't exist but augment_active does
	if not InputMap.has_action(String(active_action)) and InputMap.has_action("augment_active"):
		active_action = &"augment_active"

func _report_cd(force: bool) -> void:
	if not force and absf(_cd - _last_report) < 0.05:
		return
	_last_report = _cd
	active_cd_changed.emit(_cd, _cd_max)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_hb: bool = false

var _base_blink_range: float
var _base_active_base_cd: float
var _base_mark_duration: float
var _base_marked_shots: int
var _base_bonus_d8_count: int
var _base_bonus_power_scale: float
var _base_bonus_flat: float

func _enter_tree() -> void:
	_capture_level_bases_hb()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_hb()
	_apply_level_scaling_hb()

func _capture_level_bases_hb() -> void:
	if _bases_captured_hb:
		return
	_bases_captured_hb = true

	_base_blink_range = blink_range
	_base_active_base_cd = active_base_cd
	_base_mark_duration = mark_duration
	_base_marked_shots = marked_shots
	_base_bonus_d8_count = bonus_d8_count
	_base_bonus_power_scale = bonus_power_scale
	_base_bonus_flat = bonus_flat

func _apply_level_scaling_hb() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		blink_range = _base_blink_range
		active_base_cd = _base_active_base_cd
		mark_duration = _base_mark_duration
		marked_shots = _base_marked_shots
		bonus_d8_count = _base_bonus_d8_count
		bonus_power_scale = _base_bonus_power_scale
		bonus_flat = _base_bonus_flat
		return

	blink_range = _base_blink_range * (1.0 + 0.08 * float(t))
	active_base_cd = maxf(2.5, _base_active_base_cd * pow(0.92, float(t)))

	mark_duration = _base_mark_duration + 0.75 * float(t)
	marked_shots = maxi(1, _base_marked_shots + int(floor(float(t) / 2.0)))

	bonus_d8_count = maxi(1, _base_bonus_d8_count + int(floor(float(t) / 2.0)))
	bonus_power_scale = _base_bonus_power_scale * (1.0 + 0.10 * float(t))
	bonus_flat = _base_bonus_flat
