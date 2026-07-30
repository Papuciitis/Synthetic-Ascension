extends SetEffectBase

signal active_cd_changed(time_left: float, max_cd: float)
signal active_failed(message: String)

@export var hud_priority: int = 9
@export var hud_key_text: String = "R"
@export var hud_title_text: String = "Verdict"
@export var hud_icon: Texture2D

# --- Passive: bank damage, then yank + slam ---
@export var damage_needed_base: float = 200.0
@export var base_internal_cd: float = 2.25

@export var pull_radius: float = 280.0
@export var pull_time: float = 0.38
@export var pull_force: float = 1800.0

@export var slam_radius: float = 190.0
@export var slam_damage_mult: float = 1.55
@export var slam_knockback: float = 760.0
@export var slam_stun: float = 0.30

# style follow-ups (melee shock rings / ranged shrapnel / magic splinters)
@export var melee_aftershocks: int = 2
@export var melee_aftershock_delay: float = 0.18
@export var melee_aftershock_radius_step: float = 70.0
@export var melee_aftershock_damage_mult: float = 0.65
@export var melee_aftershock_stun: float = 0.10

@export var ranged_shrapnel_count: int = 12
@export var ranged_shrapnel_damage_mult: float = 0.35

@export var magic_splinters: int = 5
@export var magic_splinter_radius: float = 120.0
@export var magic_splinter_damage_mult: float = 0.55

# --- Active (R): force a verdict early (needs some bank) ---
@export var active_base_cd: float = 11.0
@export var active_bank_fraction: float = 0.60

@export var vfx_shockwave_scene: PackedScene
@export var vfx_pulse_ring_scene: PackedScene
@export var vfx_spokes_scene: PackedScene

var _bank: float = 0.0
var _internal_cd: float = 0.0

var _pull_left: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _mode: int = 0 # 0 idle, 1 pulling
var _style: StringName = &"melee"

# active HUD cd
var _active_cd: float = 0.0
var _active_cd_max: float = 0.0
var _last_cd_report: float = -999.0

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	effect_id = &"gravemarch_6_verdict"

func _ready() -> void:
	_rng.randomize()
	RunEvents.damage_dealt.connect(_on_damage_dealt)
	RunEvents.weapon_fired.connect(_on_weapon_fired)
	_report_active_cd(true)

func _exit_tree() -> void:
	if RunEvents.damage_dealt.is_connected(_on_damage_dealt):
		RunEvents.damage_dealt.disconnect(_on_damage_dealt)
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)

func _process(dt: float) -> void:
	_internal_cd = maxf(_internal_cd - dt, 0.0)
	_active_cd = maxf(_active_cd - dt, 0.0)

	if player != null and Input.is_action_just_pressed("set_active"):
		_try_active()

	if _mode == 1:
		_pull_left = maxf(_pull_left - dt, 0.0)
		_pull_tick(dt)
		if _pull_left <= 0.0:
			_mode = 0
			_slam()

	_report_active_cd()

func _on_weapon_fired(p: Node, style_id: StringName, _origin: Vector2, _target: Vector2, _power_mul: float, _haste_mul: float) -> void:
	if p != player:
		return
	_style = style_id

func _on_damage_dealt(p: Node, amount: float) -> void:
	if p != player:
		return
	if amount <= 0.0:
		return

	_bank += amount

	if _internal_cd > 0.0 or _mode != 0:
		return

	var need := _damage_needed()
	if _bank >= need:
		_bank = 0.0
		_start_verdict()

func _damage_needed() -> float:
	# Rarity scaling: stronger set => procs more often (a bit) AND hits harder (handled in damage).
	# This is the "collect rarity -> feels stronger" part.
	return maxf(60.0, damage_needed_base / pow(maxf(set_strength, 0.1), 0.75))

func _start_verdict() -> void:
	var p2 := player as Node2D
	if p2 == null:
		return

	_center = p2.global_position
	_mode = 1
	_pull_left = pull_time
	_internal_cd = base_internal_cd

	_spawn_spokes(_center)
	_spawn_pulse(_center, _pull_effect_radius())

func _pull_tick(dt: float) -> void:
	var r := _pull_effect_radius()
	var r2 := r * r
	var force := pull_force * (0.85 + 0.25 * set_strength)

	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var d2 := _center.distance_squared_to(e.global_position)
		if d2 > r2:
			continue

		if e.has_method("apply_knockback"):
			var dir := (_center - e.global_position)
			if dir.length_squared() > 0.001:
				# multiply by dt to make it stable across FPS
				e.call("apply_knockback", dir.normalized() * force * dt)

func _slam() -> void:
	_spawn_wave(_center, slam_radius * (0.92 + 0.18 * set_strength))
	_spawn_pulse(_center, slam_radius * (0.92 + 0.18 * set_strength))

	var base := _get_player_base_damage()
	var power_mul := _get_power_mul()
	var dmg := base * slam_damage_mult * power_mul * set_strength
	var kb := slam_knockback * (0.85 + 0.25 * set_strength)
	var st := slam_stun * (0.85 + 0.25 * set_strength)

	_damage_radius(_center, slam_radius * (0.92 + 0.18 * set_strength), dmg, kb, st)

	# Style follow-ups (this is where each style feels different)
	if _style == &"ranged":
		_ranged_shrapnel(base * power_mul * ranged_shrapnel_damage_mult * set_strength)
	elif _style == &"magic":
		_magic_splinters(base * power_mul * magic_splinter_damage_mult * set_strength)
	else:
		_melee_aftershocks(base * power_mul * melee_aftershock_damage_mult * set_strength)

func _melee_aftershocks(dmg: float) -> void:
	var count_extra := int(floor((set_strength - 1.0) * 2.0))
	var n := clampi(melee_aftershocks + count_extra, 2, 4)

	for i in range(n):
		var delay := melee_aftershock_delay * float(i + 1)
		var r := slam_radius + melee_aftershock_radius_step * float(i + 1)

		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if player == null or not is_instance_valid(player):
				return
			_spawn_wave(_center, r * (0.95 + 0.15 * set_strength))
			_damage_radius(_center, r * (0.95 + 0.15 * set_strength), dmg, slam_knockback * 0.55, melee_aftershock_stun)
		)

func _ranged_shrapnel(dmg: float) -> void:
	var scn: PackedScene = player.get("ranged_bullet_scene") as PackedScene
	if scn == null:
		return

	var extra := int(floor((set_strength - 1.0) * 8.0))
	var n := clampi(ranged_shrapnel_count + extra, 12, 22)

	for i in range(n):
		var a := TAU * (float(i) / float(n)) + _rng.randf_range(-0.06, 0.06)
		_spawn_bullet(scn, _center, Vector2.RIGHT.rotated(a), dmg)

func _magic_splinters(dmg: float) -> void:
	var extra := int(floor((set_strength - 1.0) * 3.0))
	var n := clampi(magic_splinters + extra, 5, 10)

	for i in range(n):
		var a := TAU * (float(i) / float(n))
		var p := _center + Vector2.RIGHT.rotated(a) * (magic_splinter_radius + _rng.randf_range(-14.0, 14.0))
		player.call("_spawn_magic", p, dmg)

	# center ping (very readable)
	player.call("_spawn_magic", _center, dmg * 1.10)

func _try_active() -> void:
	if player == null:
		return
	if _active_cd > 0.0:
		active_failed.emit("Cooldown %.1fs" % _active_cd)
		return
	if _mode != 0:
		active_failed.emit("Arrest already active")
		return

	# need some bank to spend
	var need := _damage_needed()
	if _bank < need * active_bank_fraction:
		active_failed.emit("Need %.0f more damage" % (need * active_bank_fraction - _bank))
		return

	_bank = maxf(0.0, _bank - need * active_bank_fraction)

	var st: Stats = player.get("stats") as Stats
	var haste_mul := 1.0
	if st != null:
		haste_mul = 1.0 + maxf(st.haste, -0.9)

	_active_cd = maxf(1.0, active_base_cd / maxf(haste_mul, 0.05))
	_active_cd_max = _active_cd

	_start_verdict()
	_report_active_cd(true)

func _pull_effect_radius() -> float:
	return pull_radius * (0.88 + 0.18 * set_strength)

func get_active_state() -> Dictionary:
	var full_threshold: float = _damage_needed()
	var active_threshold: float = full_threshold * active_bank_fraction
	var is_ready: bool = player != null and _active_cd <= 0.05 and _mode == 0 and _bank >= active_threshold
	var status: String = "READY"
	if _mode != 0:
		status = "ARRESTING"
	elif _active_cd > 0.05:
		status = String.num(_active_cd, 1)
	elif _bank < active_threshold:
		status = "NEED %.0f DMG" % (active_threshold - _bank)
	return {
		"ready": is_ready,
		"cooldown_left": _active_cd,
		"cooldown_max": _active_cd_max if _active_cd_max > 0.0 else active_base_cd,
		"resource_value": _bank,
		"resource_max": active_threshold,
		"status_text": status,
		"combat_text": "BANK %.0f / %.0f · R REQ %.0f%s" % [_bank, full_threshold, active_threshold, " · PULLING" if _mode != 0 else ""],
	}

func debug_set_bank(value: float) -> void:
	_bank = clampf(value, 0.0, _damage_needed())

func debug_fill_active_bank() -> void:
	_bank = _damage_needed() * active_bank_fraction

func debug_clear_bank() -> void:
	_bank = 0.0

func _report_active_cd(force: bool = false) -> void:
	if not force and absf(_active_cd - _last_cd_report) < 0.10:
		return
	_last_cd_report = _active_cd
	active_cd_changed.emit(_active_cd, _active_cd_max if _active_cd_max > 0.0 else 0.0)

func _get_player_base_damage() -> float:
	if player != null:
		var v = player.get("base_weapon_damage")
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			return float(v)
	return 12.0

func _get_power_mul() -> float:
	var st: Stats = player.get("stats") as Stats
	if st != null:
		return 1.0 + st.power
	return 1.0

func _damage_radius(center: Vector2, r: float, dmg: float, kb: float, st: float) -> void:
	var r2 := r * r
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if center.distance_squared_to(e.global_position) > r2:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, player)
		if kb > 0.0 and e.has_method("apply_knockback"):
			var dir := (e.global_position - center)
			if dir.length_squared() > 0.001:
				e.call("apply_knockback", dir.normalized() * kb)
		if st > 0.0 and e.has_method("apply_stun"):
			e.call("apply_stun", st)

func _spawn_bullet(scn: PackedScene, pos: Vector2, dir: Vector2, dmg: float) -> void:
	var bullet := scn.instantiate()
	if bullet == null:
		return

	if bullet is Node2D:
		(bullet as Node2D).global_position = pos

	var hb: Area2D = player.get_node_or_null("Hurtbox") as Area2D
	if hb != null and bullet is CollisionObject2D:
		(bullet as CollisionObject2D).collision_layer = hb.collision_layer
		(bullet as CollisionObject2D).collision_mask = hb.collision_mask

	bullet.set("damage", dmg)

	var speed_val := 600.0
	var s = bullet.get("speed")
	if typeof(s) in [TYPE_INT, TYPE_FLOAT]:
		speed_val = float(s)
	bullet.set("velocity", dir.normalized() * speed_val)

	bullet.add_to_group("player_projectile")
	get_tree().current_scene.add_child(bullet)

func _spawn_wave(pos: Vector2, r: float) -> void:
	if vfx_shockwave_scene == null:
		return
	var vfx := vfx_shockwave_scene.instantiate()
	var n2 := vfx as Node2D
	if n2 == null:
		if vfx != null:
			vfx.queue_free()
		return
	get_tree().current_scene.add_child(n2)
	if n2.has_method("setup"):
		n2.call("setup", pos, r)
	else:
		n2.global_position = pos

func _spawn_pulse(pos: Vector2, r: float) -> void:
	if vfx_pulse_ring_scene == null:
		return
	var vfx := vfx_pulse_ring_scene.instantiate()
	var n2 := vfx as Node2D
	if n2 == null:
		if vfx != null:
			vfx.queue_free()
		return
	get_tree().current_scene.add_child(n2)
	if n2.has_method("setup"):
		n2.call("setup", pos, r)
	else:
		n2.global_position = pos

func _spawn_spokes(pos: Vector2) -> void:
	if vfx_spokes_scene == null:
		return
	var vfx := vfx_spokes_scene.instantiate()
	var n2 := vfx as Node2D
	if n2 == null:
		if vfx != null:
			vfx.queue_free()
		return
	get_tree().current_scene.add_child(n2)
	if n2.has_method("setup"):
		n2.call("setup", pos)
	else:
		n2.global_position = pos
