extends Node
class_name ReflectShieldEffect

signal active_cd_changed(time_left: float, max_cd: float)

@export var hud_priority: int = 10
@export var hud_key_text: String = ""
@export var hud_title_text: String = "Reflect Shield"
@export var hud_icon: Texture2D

@export var active_action: StringName = &"augment_active"
@export var debug_prints: bool = false

# Balanced values (feels active but not godmode)
@export var active_base_cd: float = 0.40
@export var parry_window: float = 0.14
@export var max_reflect_per_frame: int = 9999 # set huge to reflect everything
@export var intercept_padding: float = 10.0

@export var projectile_groups: PackedStringArray = ["enemy_projectile"]

# Spawn this when reflecting (assign in the effect scene)
@export var reflected_projectile_scene: PackedScene

# Optional VFX (assign in effect scene)
@export var vfx_window_scene: PackedScene          # NEW: persistent parry aura on player hurtbox
@export var vfx_parry_flash_scene: PackedScene
@export var vfx_reflect_flash_scene: PackedScene
@export var vfx_perfect_flash_scene: PackedScene

# Reflection tuning
@export var reflect_damage_mult: float = 0.95
@export var reflect_speed_mult: float = 1.05

# Perfect parry (bonus)
@export var perfect_window: float = 0.06
@export var perfect_cd_after: float = 0.10
@export var perfect_zap_radius: float = 220.0
@export var perfect_zap_max_targets: int = 3
@export var perfect_zap_damage_mult: float = 0.35
@export var perfect_zap_stun: float = 0.12

var player: Node2D = null

var _cd: float = 0.0
var _cd_max: float = 0.40

var _active_left: float = 0.0
var _active_elapsed: float = 0.0
var _reflected_this_cast: int = 0
var _perfect_used_this_cast: bool = false

var _last_report: float = -999.0
var _warned_missing_action: bool = false

var _window_vfx: Node = null
var _was_active: bool = false

func setup(p: Node) -> void:
	player = p as Node2D

func _ready() -> void:
	set_process(true)
	_cd_max = active_base_cd
	_resolve_action_from_slot()
	_report_cd(true)

	if debug_prints:
		print("[ReflectShield] READY action=", String(active_action),
			" has_action=", InputMap.has_action(String(active_action)),
			" slot_meta=", get_meta("hud_slot_index", -1))

func _exit_tree() -> void:
	_cleanup_window_vfx()

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if not InputMap.has_action(String(active_action)):
		if debug_prints and not _warned_missing_action:
			_warned_missing_action = true
			print("[ReflectShield] Missing InputMap action:", String(active_action),
				" (add augment_active or augment_active_1/2/3 in Input Map)")
		return

	if _cd > 0.0:
		_cd = max(_cd - dt, 0.0)

	# parry window update
	if _active_left > 0.0:
		_active_left = max(_active_left - dt, 0.0)
		_active_elapsed += dt
		_scan_and_reflect()

	# cleanup on window end
	var now_active: bool = _active_left > 0.0
	if _was_active and not now_active:
		_cleanup_window_vfx()
	_was_active = now_active

	if not Global.active_augment_input_blocked(int(get_meta("hud_slot_index", -1))) and Input.is_action_just_pressed(active_action):
		_try_activate()

	_report_cd(false)

func _try_activate() -> void:
	if _cd > 0.0:
		return

	_cd_max = Global.doctrine_active_cooldown(active_base_cd)
	_cd = _cd_max
	Global.notify_active_augment_used(int(get_meta("hud_slot_index", -1)))

	_active_left = parry_window
	_active_elapsed = 0.0
	_reflected_this_cast = 0
	_perfect_used_this_cast = false
	_was_active = true

	# micro invuln during the parry window
	if player.has_method("grant_invulnerability"):
		player.call("grant_invulnerability", parry_window)

	_spawn_window_vfx()
	_spawn_flash(vfx_parry_flash_scene, player.global_position)

	if debug_prints:
		print("[ReflectShield] activate window=", parry_window)

	_report_cd(true)

func _spawn_window_vfx() -> void:
	_cleanup_window_vfx()
	if vfx_window_scene == null or player == null:
		return

	var hb := player.get_node_or_null("Hurtbox") as Area2D
	if hb == null:
		return

	var n := vfx_window_scene.instantiate()
	var n2 := n as Node2D
	if n2 == null:
		if n != null:
			n.queue_free()
		return

	# attach to player so it inherits pause/lifecycle cleanly
	player.add_child(n2)
	_window_vfx = n2

	if n2.has_method("setup"):
		n2.call("setup", hb, parry_window)

func _cleanup_window_vfx() -> void:
	if _window_vfx != null and is_instance_valid(_window_vfx):
		_window_vfx.queue_free()
	_window_vfx = null

func _scan_and_reflect() -> void:
	if reflected_projectile_scene == null:
		return

	var r: float = _get_hurtbox_radius(player) + intercept_padding
	var r2: float = r * r

	var is_perfect_now: bool = (not _perfect_used_this_cast) and (_active_elapsed <= perfect_window)

	# Collect first (safe even if we queue_free later)
	var to_reflect: Array[Node2D] = []

	for g in projectile_groups:
		for n in get_tree().get_nodes_in_group(StringName(g)):
			var p: Node2D = n as Node2D
			if p == null or not is_instance_valid(p):
				continue
			if p.get_meta("reflected", false) == true:
				continue

			# Check distance using current positions
			if player.global_position.distance_squared_to(p.global_position) > r2:
				continue

			to_reflect.append(p)
			if to_reflect.size() >= max_reflect_per_frame:
				break

		if to_reflect.size() >= max_reflect_per_frame:
			break

	for p2 in to_reflect:
		if p2 == null or not is_instance_valid(p2):
			continue

		var do_perfect: bool = is_perfect_now and (not _perfect_used_this_cast)
		_reflect_one(p2, do_perfect)

	# Simulated enemy bullets (ProjectileManager) are data records, not
	# nodes — the group scan above can never see them, which made the
	# shield a no-op against ordinary ranged enemies.
	var budget: int = max_reflect_per_frame - to_reflect.size()
	if budget > 0:
		var manager := get_node_or_null("/root/ProjectileManager")
		if manager != null and manager.has_method("consume_enemy_projectiles_in_radius"):
			var consumed: Array = []
			manager.call("consume_enemy_projectiles_in_radius", player.global_position, r, consumed)
			for entry_variant in consumed:
				if budget <= 0:
					break
				budget -= 1
				var entry := entry_variant as Dictionary
				var do_perfect_sim: bool = is_perfect_now and (not _perfect_used_this_cast)
				_reflect_simulated(entry, do_perfect_sim)

func _reflect_simulated(entry: Dictionary, is_perfect: bool) -> void:
	var ppos: Vector2 = entry.get("position", Vector2.ZERO)
	var velocity: Vector2 = entry.get("velocity", Vector2.ZERO)
	var dmg: float = float(entry.get("damage", 10.0)) * reflect_damage_mult
	var spd: float = maxf(200.0, velocity.length()) * reflect_speed_mult
	var dir: Vector2 = -velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT

	var rp: Node2D = reflected_projectile_scene.instantiate() as Node2D
	if rp != null:
		get_tree().current_scene.add_child(rp)
		rp.global_position = ppos
		if rp.get("speed") != null:
			rp.set("speed", spd)
		if rp.has_method("setup"):
			rp.call("setup", dir, dmg, player)

	_spawn_flash(vfx_reflect_flash_scene, ppos)

	if is_perfect and (not _perfect_used_this_cast):
		_perfect_used_this_cast = true
		_on_perfect_reflect(ppos, dmg)

func _reflect_one(p: Node2D, is_perfect: bool) -> void:
	if p == null or not is_instance_valid(p):
		return

	# Snapshot position early (before any chance of freeing)
	var ppos: Vector2 = p.global_position

	# mark so we don't double reflect
	p.set_meta("reflected", true)

	var dmg: float = _read_float(p, "damage", 10.0) * reflect_damage_mult
	var spd: float = _read_float(p, "speed", 1100.0) * reflect_speed_mult

	var dir: Vector2 = _infer_projectile_dir(p, ppos)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var rp: Node2D = reflected_projectile_scene.instantiate() as Node2D
	if rp != null:
		get_tree().current_scene.add_child(rp)
		rp.global_position = ppos

		# set speed if the node has a speed property
		if rp.get("speed") != null:
			rp.set("speed", spd)

		if rp.has_method("setup"):
			rp.call("setup", dir, dmg, player)

	_spawn_flash(vfx_reflect_flash_scene, ppos)

	if is_perfect and (not _perfect_used_this_cast):
		_perfect_used_this_cast = true
		_on_perfect_reflect(ppos, dmg)

	# kill original projectile last
	if is_instance_valid(p):
		p.queue_free()

func _on_perfect_reflect(pos: Vector2, reflected_dmg: float) -> void:
	_cd = min(_cd, perfect_cd_after)
	_spawn_flash(vfx_perfect_flash_scene, pos)

	var zap_dmg: float = maxf(1.0, reflected_dmg * perfect_zap_damage_mult)
	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(pos, perfect_zap_radius, handles)
	handles.sort_custom(func(a: int, b: int) -> bool:
		return pos.distance_squared_to(EnemyCombat.position_for_handle(a)) < pos.distance_squared_to(EnemyCombat.position_for_handle(b))
	)
	if handles.size() > perfect_zap_max_targets:
		handles.resize(perfect_zap_max_targets)
	for handle in handles:
		EnemyCombat.apply_damage(handle, zap_dmg, 1, player)
		if perfect_zap_stun > 0.0:
			EnemyCombat.apply_stun(handle, perfect_zap_stun)

	if debug_prints:
		print("[ReflectShield] PERFECT! cd->", _cd, " zap_dmg=", zap_dmg)

	_report_cd(true)

func _infer_projectile_dir(p: Node2D, ppos: Vector2) -> Vector2:
	var shv: Variant = p.get("shooter")
	if typeof(shv) == TYPE_OBJECT and is_instance_valid(shv):
		var sh_node: Node2D = shv as Node2D
		if sh_node != null and is_instance_valid(sh_node):
			var d1: Vector2 = (sh_node.global_position - ppos)
			if d1 != Vector2.ZERO:
				return d1.normalized()

	var v: Variant = p.get("velocity")
	if typeof(v) == TYPE_VECTOR2 and (v as Vector2) != Vector2.ZERO:
		return (-(v as Vector2)).normalized()

	var v2: Variant = p.get("vel")
	if typeof(v2) == TYPE_VECTOR2 and (v2 as Vector2) != Vector2.ZERO:
		return (-(v2 as Vector2)).normalized()

	if player != null and is_instance_valid(player):
		var away: Vector2 = (ppos - player.global_position)
		if away != Vector2.ZERO:
			return away.normalized()

	return Vector2.RIGHT

func _read_float(obj: Object, prop: StringName, fallback: float) -> float:
	if obj == null:
		return fallback
	var v: Variant = obj.get(prop)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback

func _spawn_flash(scn: PackedScene, pos: Vector2) -> void:
	if scn == null:
		return
	var n: Node2D = scn.instantiate() as Node2D
	if n == null:
		return
	get_tree().current_scene.add_child(n)
	n.global_position = pos

func _get_hurtbox_radius(p: Node) -> float:
	var hb: Area2D = p.get_node_or_null("Hurtbox") as Area2D
	if hb == null:
		return 40.0

	var csn: CollisionShape2D = null
	for c in hb.get_children():
		csn = c as CollisionShape2D
		if csn != null:
			break

	if csn == null or csn.shape == null:
		return 40.0

	var sh := csn.shape
	if sh is CircleShape2D:
		return (sh as CircleShape2D).radius
	if sh is RectangleShape2D:
		var sz := (sh as RectangleShape2D).size
		return maxf(sz.x, sz.y) * 0.5
	if sh is CapsuleShape2D:
		var cap := sh as CapsuleShape2D
		return maxf(cap.radius, cap.height * 0.5 + cap.radius)

	return 40.0

func _resolve_action_from_slot() -> void:
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

	if not InputMap.has_action(String(active_action)) and InputMap.has_action("augment_active"):
		active_action = &"augment_active"

func _report_cd(force: bool) -> void:
	if not force and absf(_cd - _last_report) < 0.05:
		return
	_last_report = _cd
	active_cd_changed.emit(_cd, _cd_max)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_rs: bool = false

var _base_active_base_cd_rs: float
var _base_parry_window_rs: float
var _base_reflect_damage_mult_rs: float
var _base_reflect_speed_mult_rs: float
var _base_perfect_window_rs: float
var _base_perfect_zap_radius_rs: float
var _base_perfect_zap_max_targets_rs: int
var _base_perfect_zap_damage_mult_rs: float

func _enter_tree() -> void:
	_capture_level_bases_rs()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_rs()
	_apply_level_scaling_rs()

func _capture_level_bases_rs() -> void:
	if _bases_captured_rs:
		return
	_bases_captured_rs = true

	_base_active_base_cd_rs = active_base_cd
	_base_parry_window_rs = parry_window
	_base_reflect_damage_mult_rs = reflect_damage_mult
	_base_reflect_speed_mult_rs = reflect_speed_mult
	_base_perfect_window_rs = perfect_window
	_base_perfect_zap_radius_rs = perfect_zap_radius
	_base_perfect_zap_max_targets_rs = perfect_zap_max_targets
	_base_perfect_zap_damage_mult_rs = perfect_zap_damage_mult

func _apply_level_scaling_rs() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		active_base_cd = _base_active_base_cd_rs
		parry_window = _base_parry_window_rs
		reflect_damage_mult = _base_reflect_damage_mult_rs
		reflect_speed_mult = _base_reflect_speed_mult_rs
		perfect_window = _base_perfect_window_rs
		perfect_zap_radius = _base_perfect_zap_radius_rs
		perfect_zap_max_targets = _base_perfect_zap_max_targets_rs
		perfect_zap_damage_mult = _base_perfect_zap_damage_mult_rs
	else:
		active_base_cd = maxf(0.18, _base_active_base_cd_rs * pow(0.92, float(t)))
		parry_window = clampf(_base_parry_window_rs + 0.02 * float(t), 0.05, 0.24)

		reflect_damage_mult = clampf(_base_reflect_damage_mult_rs + 0.06 * float(t), 0.0, 1.25)
		reflect_speed_mult = clampf(_base_reflect_speed_mult_rs + 0.03 * float(t), 0.0, 1.35)

		perfect_window = clampf(_base_perfect_window_rs + 0.01 * float(t), 0.01, 0.10)
		perfect_zap_radius = _base_perfect_zap_radius_rs * (1.0 + 0.05 * float(t))
		perfect_zap_max_targets = clampi(_base_perfect_zap_max_targets_rs + int(floor(float(t) / 2.0)), 1, _base_perfect_zap_max_targets_rs + 2)
		perfect_zap_damage_mult = _base_perfect_zap_damage_mult_rs * (1.0 + 0.12 * float(t))

	# Keep internal cooldown max in sync (important if level changes while running).
	_cd_max = active_base_cd
	_cd = minf(_cd, _cd_max)
