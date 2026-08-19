extends SetEffectBase

signal active_cd_changed(time_left: float, max_cd: float)
signal active_failed(message: String)

@export var hud_priority: int = 9
@export var hud_key_text: String = "R"
@export var hud_title_text: String = "Index Commit"
@export var hud_icon: Texture2D

# --- Passive: Triangulate ---
@export var mark_lifetime: float = 2.6
@export var marks_needed: int = 3

@export var node_radius: float = 145.0
@export var node_knockback: float = 320.0
@export var node_stun: float = 0.10

@export var melee_node_damage_mult: float = 1.05
@export var ranged_bullet_damage_mult: float = 0.55
@export var magic_edge_damage_mult: float = 0.62

@export var ranged_bullets_per_node: int = 4
@export var ranged_spread_deg: float = 36.0

@export var magic_hits_per_edge: int = 2

# --- Active (R): for a short window, every shot places TWO marks (faster triangles) ---
@export var active_base_cd: float = 9.0
@export var active_duration: float = 2.35
@export var active_mirror_mul: float = 0.70

@export var vfx_arc_line_scene: PackedScene
@export var vfx_spokes_scene: PackedScene
@export var vfx_pulse_ring_scene: PackedScene
@export var vfx_cleave_arc_scene: PackedScene

var _marks: Array[Dictionary] = [] # [{pos:Vector2, t:float}]
var _active_time: float = 0.0
var _active_cd: float = 0.0
var _active_cd_max: float = 0.0
var _last_cd_report: float = -999.0

var _last_style: StringName = &"ranged"
var _rng := RandomNumberGenerator.new()
var _preview_line: Line2D = null

func _init() -> void:
	effect_id = &"lattice_6_index_commit"

func _ready() -> void:
	_rng.randomize()
	RunEvents.weapon_fired.connect(_on_weapon_fired)
	_report_active_cd(true)

func _exit_tree() -> void:
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)
	_clear_mark_visuals()
	if _preview_line != null and is_instance_valid(_preview_line):
		_preview_line.queue_free()

func _process(dt: float) -> void:
	# tick active window + cooldown
	_active_time = maxf(_active_time - dt, 0.0)
	_active_cd = maxf(_active_cd - dt, 0.0)

	# expire marks
	for i in range(_marks.size() - 1, -1, -1):
		_marks[i].t -= dt
		if _marks[i].t <= 0.0:
			_free_mark_vfx(_marks[i])
			_marks.remove_at(i)
	_update_preview_line()

	# Active trigger
	if player != null and Input.is_action_just_pressed("set_active"):
		_try_active()

	_report_active_cd()

func _on_weapon_fired(p: Node, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, _haste_mul: float) -> void:
	if p != player:
		return

	_last_style = style_id

	# For melee, aim can be far away; pull it a bit closer so triangles actually land.
	var pos := target
	var p2 := player as Node2D
	if p2 != null and style_id == &"melee":
		pos = p2.global_position.lerp(target, 0.62)

	_add_mark(pos, style_id, origin, target, power_mul, false)

	# Active window: also add a mirrored mark (geometry vibe)
	if _active_time > 0.0 and p2 != null:
		var mirror := p2.global_position + (p2.global_position - pos) * active_mirror_mul
		_add_mark(mirror, style_id, origin, target, power_mul, true)

func _add_mark(pos: Vector2, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, mirrored: bool = false) -> void:
	# push mark
	_marks.append({ "pos": pos, "t": mark_lifetime, "mirrored": mirrored, "vfx": _spawn_mark_vfx(pos, mirrored) })

	_spawn_spokes(pos)
	_spawn_pulse(pos, 44.0 + 12.0 * set_strength)

	# keep only last N marks
	while _marks.size() > marks_needed:
		_free_mark_vfx(_marks[0])
		_marks.remove_at(0)
	_update_preview_line()

	if _marks.size() < marks_needed:
		return

	# Snapshot positions, clear marks, and TRIANGULATE.
	var p0: Vector2 = _marks[0].pos
	var p1: Vector2 = _marks[1].pos
	var p2: Vector2 = _marks[2].pos
	_clear_mark_visuals()
	_marks.clear()
	_update_preview_line()

	_triangulate(style_id, origin, target, power_mul, p0, p1, p2)

func _triangulate(style_id: StringName, _origin: Vector2, _target: Vector2, power_mul: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	# VFX triangle
	_spawn_arc(a, b)
	_spawn_arc(b, c)
	_spawn_arc(c, a)

	# Heavy node pops
	if style_id == &"ranged":
		_ranged_triangle(power_mul, a, b, c)
	elif style_id == &"magic":
		_magic_triangle(power_mul, a, b, c)
	else:
		_melee_triangle(power_mul, a, b, c)

func _ranged_triangle(power_mul: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	var scn: PackedScene = player.get("ranged_bullet_scene") as PackedScene
	if scn == null:
		return

	var base := _get_player_base_damage()
	var dmg := base * ranged_bullet_damage_mult * power_mul * set_strength

	var extra := int(floor((set_strength - 1.0) * 3.0))
	var n_per := clampi(ranged_bullets_per_node + extra, 4, 7)
	var spread := deg_to_rad(ranged_spread_deg)

	for pnt in [a, b, c]:
		_spawn_spokes(pnt)
		var dir := _aim_dir_from(pnt)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		for i in range(n_per):
			var t := 0.0 if n_per <= 1 else float(i) / float(n_per - 1)
			var ang := lerpf(-spread * 0.5, spread * 0.5, t)
			_spawn_bullet(scn, pnt, dir.rotated(ang), dmg)

func _melee_triangle(power_mul: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	var base := _get_player_base_damage()
	var dmg := base * melee_node_damage_mult * power_mul * set_strength

	var r := node_radius * (0.90 + 0.18 * set_strength)
	var kb := node_knockback * (0.85 + 0.25 * set_strength)
	var st := node_stun * (0.85 + 0.25 * set_strength)

	for pnt in [a, b, c]:
		_spawn_cleave(pnt, (pnt - (player as Node2D).global_position).normalized(), r * 0.70)
		_spawn_pulse(pnt, r)
		_damage_radius(pnt, r, dmg, kb, st)

	# bonus: center pop (this is the 'wow' for melee)
	var center := (a + b + c) / 3.0
	_spawn_cleave(center, Vector2.RIGHT.rotated(_rng.randf_range(-1.0, 1.0)), r * 0.85)
	_spawn_pulse(center, r * 1.05)
	_damage_radius(center, r * 1.05, dmg * 0.85, kb * 1.10, st * 1.25)

func _magic_triangle(power_mul: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	var base := _get_player_base_damage()
	var dmg := base * magic_edge_damage_mult * power_mul * set_strength

	var hits_extra := int(floor((set_strength - 1.0) * 2.0))
	var hits := clampi(magic_hits_per_edge + hits_extra, 2, 4)

	# Node pops
	for pnt in [a, b, c]:
		_spawn_pulse(pnt, 66.0 + 18.0 * set_strength)
		player.call("_spawn_magic", pnt, dmg * 1.15)

	# Edge stitching (lots of impacts = big magic wow)
	_magic_edge(a, b, hits, dmg)
	_magic_edge(b, c, hits, dmg)
	_magic_edge(c, a, hits, dmg)

func _magic_edge(a: Vector2, b: Vector2, hits: int, dmg: float) -> void:
	for i in range(1, hits + 1):
		var t := float(i) / float(hits + 1)
		var p := a.lerp(b, t) + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-10.0, 10.0))
		player.call("_spawn_magic", p, dmg)

func _damage_radius(center: Vector2, r: float, dmg: float, kb: float, st: float) -> void:
	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(center, r, handles)
	for handle in handles:
		var hit_position := EnemyCombat.position_for_handle(handle)
		EnemyCombat.apply_damage(handle, dmg, 1, player)
		var direction := hit_position - center
		if direction.length_squared() > 0.001 and kb > 0.0:
			EnemyCombat.apply_knockback(handle, direction.normalized() * kb)
		if st > 0.0:
			EnemyCombat.apply_stun(handle, st)

func _aim_dir_from(from: Vector2) -> Vector2:
	var handle := EnemyCombat.nearest_enemy(from, 100000.0)
	if handle == EnemyWorldTypes.INVALID_HANDLE:
		return Vector2.ZERO
	return (EnemyCombat.position_for_handle(handle) - from).normalized()

func _get_player_base_damage() -> float:
	if player != null:
		var v = player.get("base_weapon_damage")
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			return float(v)
	return 12.0

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

func _try_active() -> void:
	if player == null:
		return
	if _active_cd > 0.0:
		active_failed.emit("Cooldown %.1fs" % _active_cd)
		return

	# haste reduces cd
	var st: Stats = player.get("stats") as Stats
	var haste_mul := 1.0
	if st != null:
		haste_mul = 1.0 + maxf(st.haste, -0.9)

	_active_cd = maxf(1.0, active_base_cd / maxf(haste_mul, 0.05))
	_active_cd_max = _active_cd
	_active_time = active_duration

	# Immediate pop so it feels responsive
	var p2 := player as Node2D
	if p2 != null:
		_spawn_pulse(p2.global_position, 92.0 + 22.0 * set_strength)
		_spawn_spokes(p2.global_position)

	_report_active_cd(true)

func get_active_state() -> Dictionary:
	var is_ready: bool = player != null and _active_cd <= 0.05
	var shortest: float = mark_lifetime
	for mark: Dictionary in _marks:
		shortest = minf(shortest, float(mark.get("t", mark_lifetime)))
	var mark_text: String = "MARKS %d / %d" % [_marks.size(), marks_needed]
	if not _marks.is_empty():
		mark_text += " · %.1fs" % shortest
	if _active_time > 0.0:
		mark_text += " · INDEX ACTIVE %.1fs" % _active_time
	return {
		"ready": is_ready,
		"cooldown_left": _active_cd,
		"cooldown_max": _active_cd_max if _active_cd_max > 0.0 else active_base_cd,
		"status_text": "READY" if is_ready else String.num(_active_cd, 1),
		"combat_text": mark_text,
	}

func debug_place_mark(world_position: Vector2, mirrored: bool = false) -> void:
	_add_mark(world_position, _last_style, world_position, world_position, 1.0, mirrored)

func debug_clear_marks() -> void:
	_clear_mark_visuals()
	_marks.clear()
	_update_preview_line()

func _spawn_mark_vfx(world_position: Vector2, mirrored: bool) -> Node2D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var vfx := LatticeMarkVfx.new()
	scene.add_child(vfx)
	vfx.setup(world_position, mirrored, mark_lifetime)
	return vfx

func _free_mark_vfx(mark: Dictionary) -> void:
	var value: Variant = mark.get("vfx", null)
	if is_instance_valid(value):
		var vfx: Node = value as Node
		vfx.queue_free()

func _clear_mark_visuals() -> void:
	for mark: Dictionary in _marks:
		_free_mark_vfx(mark)

func _update_preview_line() -> void:
	if _marks.size() < 2:
		if _preview_line != null:
			_preview_line.visible = false
		return
	if _preview_line == null or not is_instance_valid(_preview_line):
		_preview_line = Line2D.new()
		_preview_line.name = "LatticePreview"
		_preview_line.width = 1.5
		_preview_line.default_color = Color(0.76, 0.36, 1.0, 0.28)
		_preview_line.antialiased = true
		_preview_line.z_index = 185
		get_tree().current_scene.add_child(_preview_line)
	var points := PackedVector2Array()
	for mark: Dictionary in _marks:
		var mark_position: Vector2 = mark.get("pos", Vector2.ZERO)
		points.append(mark_position)
	_preview_line.points = points
	_preview_line.visible = true

func _report_active_cd(force: bool = false) -> void:
	# Throttle updates so HUD isn't spammed
	if not force and absf(_active_cd - _last_cd_report) < 0.10:
		return
	_last_cd_report = _active_cd
	active_cd_changed.emit(_active_cd, _active_cd_max if _active_cd_max > 0.0 else 0.0)

func _spawn_arc(a: Vector2, b: Vector2) -> void:
	if vfx_arc_line_scene == null:
		return
	var vfx := vfx_arc_line_scene.instantiate()
	if vfx == null:
		return
	get_tree().current_scene.add_child(vfx)
	if vfx.has_method("setup"):
		vfx.call("setup", a, b)

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

func _spawn_cleave(pos: Vector2, dir: Vector2, r: float) -> void:
	if vfx_cleave_arc_scene == null:
		return
	var vfx := vfx_cleave_arc_scene.instantiate()
	var n2 := vfx as Node2D
	if n2 == null:
		if vfx != null:
			vfx.queue_free()
		return
	get_tree().current_scene.add_child(n2)
	if n2.has_method("setup"):
		n2.call("setup", pos, dir, r)
	else:
		n2.global_position = pos
