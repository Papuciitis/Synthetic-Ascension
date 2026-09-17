extends Node
class_name StaminaCoreEffect

signal active_cd_changed(time_left: float, max_cd: float)

@export var hud_priority: int = 10
@export var hud_key_text: String = "F"
@export var hud_title_text: String = "Stamina Core"
@export var hud_icon: Texture2D

# AugmentRunner will overwrite this to augment_active_1 / _2 / _3 if you have those actions
@export var active_action: StringName = &"augment_active"

@export var active_base_cd: float = 12.0
@export var active_duration: float = 4.0
@export var invuln_duration: float = 2.0
@export var lifesteal_pct: float = 0.25

# assign VFX_StaminaCoreAura.tscn (optional)
@export var vfx_aura_scene: PackedScene

@export var debug_prints: bool = false

var player: Node2D = null

var _cd := 0.0
var _cd_max := 12.0
var _active_time := 0.0
var _last_report := -999.0

var _aura: Node = null
var _damage_cb: Callable = Callable()
var _warned_aura := false

func setup(p: Node2D) -> void:
	player = p

func _ready() -> void:
	set_process(true)
	if debug_prints:
		print("[StaminaCore] ready has_action=", InputMap.has_action(String(active_action)), " action=", String(active_action))
	_connect_damage_dealt_safely()
	_report_cd(true) # push initial state to badge

func _exit_tree() -> void:
	if _damage_cb.is_valid() and RunEvents != null and RunEvents.has_signal("damage_dealt"):
		if RunEvents.damage_dealt.is_connected(_damage_cb):
			RunEvents.damage_dealt.disconnect(_damage_cb)
	_cleanup_aura()

func _process(dt: float) -> void:
	if _active_time > 0.0:
		_active_time = max(_active_time - dt, 0.0)
		if _active_time <= 0.0:
			_cleanup_aura()

	if _cd > 0.0:
		_cd = max(_cd - dt, 0.0)

	if not Global.active_augment_input_blocked(int(get_meta("hud_slot_index", -1))) and player != null and Input.is_action_just_pressed(active_action):
		if debug_prints:
			print("[StaminaCore] pressed cd=", _cd, " active_time=", _active_time)
		_try_activate()

	_report_cd(false)
	
func _try_activate() -> void:
	if _cd > 0.0:
		if debug_prints:
			print("[StaminaCore] blocked by cd=", _cd)
		return

	var haste: float = 0.0
	var st = player.get("stats")
	if st != null:
		var v: Variant = st.get("haste")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			haste = float(v)

	var haste_mul: float = 1.0 + maxf(haste, -0.9)

	_cd_max = Global.doctrine_active_cooldown(maxf(3.0, active_base_cd / maxf(haste_mul, 0.05)))
	_cd = _cd_max
	Global.notify_active_augment_used(int(get_meta("hud_slot_index", -1)))
	_active_time = active_duration

	if player.has_method("grant_invulnerability"):
		player.call("grant_invulnerability", invuln_duration)

	if debug_prints:
		print("[StaminaCore] activated cd_max=", _cd_max, " duration=", _active_time)

	_spawn_aura()
	_report_cd(true)

func _spawn_aura() -> void:
	_cleanup_aura()
	if player == null:
		_warn_aura_once("player is null")
		return
	if vfx_aura_scene == null:
		_warn_aura_once("vfx_aura_scene is null (not assigned in StaminaCoreEffect.tscn)")
		return

	var hb := player.get_node_or_null("Hurtbox") as Area2D
	if hb == null:
		_warn_aura_once("player has no Hurtbox")
		return

	var aura := vfx_aura_scene.instantiate() as Node2D
	if aura == null:
		_warn_aura_once("aura instantiate failed")
		return

	# ✅ Parent to hurtbox so it shares the same world canvas/viewport
	hb.add_child(aura)
	aura.position = Vector2.ZERO
	_aura = aura

	if aura.has_method("setup"):
		aura.call("setup", hb, active_duration)

	if debug_prints:
		print("[StaminaCore] aura spawned parent=", aura.get_parent().name)

func _warn_aura_once(reason: String) -> void:
	if _warned_aura:
		return
	_warned_aura = true
	push_warning("[StaminaCore] cannot spawn aura: %s (scene=%s)" % [reason, scene_file_path])


func _cleanup_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null

func _connect_damage_dealt_safely() -> void:
	if RunEvents == null or not RunEvents.has_signal("damage_dealt"):
		return

	# Connect in a way that survives signal arg changes (extra args).
	var argc := 2
	for s in RunEvents.get_signal_list():
		if StringName(s.get("name", "")) == &"damage_dealt":
			var args: Array = s.get("args", [])
			argc = max(2, args.size())
			break

	var cb := Callable(self, "_on_damage_dealt")
	if argc > 2:
		cb = cb.unbind(argc - 2)

	_damage_cb = cb
	if not RunEvents.damage_dealt.is_connected(_damage_cb):
		RunEvents.damage_dealt.connect(_damage_cb)

func _on_damage_dealt(a, b) -> void:
	if player == null or _active_time <= 0.0:
		return

	var src: Node = null
	var amt: float = 0.0

	if a is Node:
		src = a
		amt = float(b)
	elif b is Node:
		src = b
		amt = float(a)
	else:
		return

	if src != player:
		return

	if player.has_method("heal"):
		player.call("heal", amt * lifesteal_pct)

func _report_cd(force: bool) -> void:
	if not force and absf(_cd - _last_report) < 0.05:
		return
	_last_report = _cd
	active_cd_changed.emit(_cd, _cd_max)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_sc: bool = false

var _base_active_base_cd_sc: float
var _base_active_duration_sc: float
var _base_invuln_duration_sc: float
var _base_lifesteal_pct_sc: float

func _enter_tree() -> void:
	_capture_level_bases_sc()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_sc()
	_apply_level_scaling_sc()

func _capture_level_bases_sc() -> void:
	if _bases_captured_sc:
		return
	_bases_captured_sc = true

	_base_active_base_cd_sc = active_base_cd
	_base_active_duration_sc = active_duration
	_base_invuln_duration_sc = invuln_duration
	_base_lifesteal_pct_sc = lifesteal_pct

func _apply_level_scaling_sc() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		active_base_cd = _base_active_base_cd_sc
		active_duration = _base_active_duration_sc
		invuln_duration = _base_invuln_duration_sc
		lifesteal_pct = _base_lifesteal_pct_sc
	else:
		active_base_cd = maxf(6.0, _base_active_base_cd_sc * pow(0.94, float(t)))
		active_duration = _base_active_duration_sc + 0.5 * float(t)
		invuln_duration = clampf(_base_invuln_duration_sc + 0.2 * float(t), 0.0, 3.0)
		lifesteal_pct = clampf(_base_lifesteal_pct_sc + 0.05 * float(t), 0.0, 0.45)

	_cd_max = active_base_cd
	_cd = minf(_cd, _cd_max)
