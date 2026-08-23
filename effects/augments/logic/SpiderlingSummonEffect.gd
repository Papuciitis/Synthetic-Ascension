extends Node
class_name SpiderlingSummonEffect

signal active_cd_changed(time_left: float, max_cd: float)

@export var hud_priority: int = 10
@export var hud_key_text: String = "1"
@export var hud_title_text: String = "Spiderlings"
@export var hud_icon: Texture2D

@export var active_action: StringName = &"augment_active"
@export var detonate_action: StringName = &"augment_detonate"

@export var spiderling_scene: PackedScene

@export var cast_range: float = 320.0
@export var cooldown: float = 1.25
@export var spawn_count: int = 1
@export var spider_lifetime: float = 12.0

@export var explosion_radius: float = 52.0
@export var explosion_d4_count: int = 1
@export var explosion_power_scale: float = 8.0

@export var bite_power_scale: float = 6.0

# NEW: world hint (no extra scene needed)
@export var detonate_hint_text: String = "Detonate: G / MMB"
@export var detonate_hint_seconds: float = 1.35
@export var detonate_hint_offset: Vector2 = Vector2(0, -56)

var player: Node2D = null

var _cd: float = 0.0
var _cd_max: float = 1.25
var _last_report: float = -999.0

# hint runtime
var _hint_label: Label = null
var _hint_time: float = 0.0

func setup(p: Node) -> void:
	player = p as Node2D

func _ready() -> void:
	set_process(true)
	_cd_max = cooldown
	_report_cd(true)

func _exit_tree() -> void:
	_cleanup_hint()

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if _cd > 0.0:
		_cd = maxf(_cd - dt, 0.0)

	_update_hint(dt)

	if not Global.active_augment_input_blocked() and Input.is_action_just_pressed(active_action):
		_try_spawn()

	if Input.is_action_just_pressed(detonate_action):
		_detonate_all()

	_report_cd(false)

func _try_spawn() -> void:
	if _cd > 0.0:
		return
	if spiderling_scene == null:
		push_warning("[Spiderlings] spiderling_scene is NULL (assign in SpiderlingSummonEffect.tscn)")
		return

	_cd_max = cooldown
	_cd = _cd_max

	var target_pos: Vector2 = _get_target_point()
	var power: float = _get_power()

	var count: int = maxi(1, spawn_count)
	for i in range(count):
		var inst: Node = spiderling_scene.instantiate()
		var s: CharacterBody2D = inst as CharacterBody2D
		if s == null:
			inst.queue_free()
			push_warning("[Spiderlings] spiderling_scene root must be CharacterBody2D")
			continue

		get_tree().current_scene.add_child(s)

		# small scatter so they don't stack perfectly
		var scatter: Vector2
		if Engine.has_singleton("Global") and Global.has_variable("_rng"):
			scatter = Vector2(Global._rng.randf_range(-12.0, 12.0), Global._rng.randf_range(-12.0, 12.0))
		else:
			scatter = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))

		s.global_position = target_pos + scatter

		# owner id lets us detonate only our spiderlings
		s.set_meta("spider_owner_id", int(get_instance_id()))

		# pass tuning into the spiderling
		if s.has_method("setup"):
			s.call("setup", player, spider_lifetime, bite_power_scale, power)

	_show_detonate_hint()
	_report_cd(true)

func _detonate_all() -> void:
	var power: float = _get_power()
	var dmg: float = _roll_explosion_damage(power)

	var owner_id: int = int(get_instance_id())

	for n in get_tree().get_nodes_in_group("spiderlings"):
		var s: Node = n as Node
		if s == null or not is_instance_valid(s):
			continue
		if not s.has_meta("spider_owner_id"):
			continue
		if int(s.get_meta("spider_owner_id")) != owner_id:
			continue

		# IMPORTANT: pass player as "source" if spiderling supports it
		if s.has_method("explode"):
			s.call("explode", dmg, explosion_radius, player)

func _get_target_point() -> Vector2:
	var mouse: Vector2 = player.get_global_mouse_position()
	var dir: Vector2 = mouse - player.global_position
	var d: float = dir.length()
	if d <= 0.001:
		return player.global_position
	if d > cast_range:
		return player.global_position + (dir / d) * cast_range
	return mouse

func _get_power() -> float:
	var power: float = 0.0
	var st: Stats = player.get("stats") as Stats
	if st != null:
		power = st.power
	return power

func _roll_explosion_damage(power: float) -> float:
	var total: int = 0
	var dice: int = maxi(1, explosion_d4_count)
	for i in range(dice):
		total += randi_range(1, 4)

	var cast_mod: float = power * explosion_power_scale
	return float(total) + cast_mod

func _report_cd(force: bool) -> void:
	if not force and absf(_cd - _last_report) < 0.05:
		return
	_last_report = _cd
	active_cd_changed.emit(_cd, _cd_max)

# -----------------------
# Detonate hint (world-space)
# -----------------------

func _show_detonate_hint() -> void:
	if detonate_hint_seconds <= 0.0:
		return

	_hint_time = detonate_hint_seconds

	if _hint_label != null and is_instance_valid(_hint_label):
		return

	var lbl := Label.new()
	lbl.text = detonate_hint_text
	lbl.top_level = true
	lbl.z_index = 4095
	lbl.modulate = Color(1, 1, 1, 0.0)

	# cheap readability
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 6)

	get_tree().current_scene.add_child(lbl)
	_hint_label = lbl

	# fade in
	var tw: Tween = get_tree().create_tween()
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_hint(dt: float) -> void:
	if _hint_label == null or not is_instance_valid(_hint_label):
		return

	_hint_time = maxf(_hint_time - dt, 0.0)
	_hint_label.global_position = player.global_position + detonate_hint_offset

	if _hint_time <= 0.0:
		var lbl := _hint_label
		_hint_label = null

		var tw: Tween = get_tree().create_tween()
		tw.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(Callable(lbl, "queue_free"))

func _cleanup_hint() -> void:
	if _hint_label != null and is_instance_valid(_hint_label):
		_hint_label.queue_free()
	_hint_label = null
	_hint_time = 0.0


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_sp: bool = false

var _base_cast_range_sp: float
var _base_cooldown_sp: float
var _base_spawn_count_sp: int
var _base_spider_lifetime_sp: float
var _base_explosion_radius_sp: float
var _base_explosion_d4_sp: int
var _base_explosion_power_scale_sp: float
var _base_bite_power_scale_sp: float

func _enter_tree() -> void:
	_capture_level_bases_sp()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_sp()
	_apply_level_scaling_sp()

func _capture_level_bases_sp() -> void:
	if _bases_captured_sp:
		return
	_bases_captured_sp = true

	_base_cast_range_sp = cast_range
	_base_cooldown_sp = cooldown
	_base_spawn_count_sp = spawn_count
	_base_spider_lifetime_sp = spider_lifetime
	_base_explosion_radius_sp = explosion_radius
	_base_explosion_d4_sp = explosion_d4_count
	_base_explosion_power_scale_sp = explosion_power_scale
	_base_bite_power_scale_sp = bite_power_scale

func _apply_level_scaling_sp() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		cast_range = _base_cast_range_sp
		cooldown = _base_cooldown_sp
		spawn_count = _base_spawn_count_sp
		spider_lifetime = _base_spider_lifetime_sp
		explosion_radius = _base_explosion_radius_sp
		explosion_d4_count = _base_explosion_d4_sp
		explosion_power_scale = _base_explosion_power_scale_sp
		bite_power_scale = _base_bite_power_scale_sp
	else:
		cast_range = _base_cast_range_sp * (1.0 + 0.05 * float(t))
		cooldown = maxf(0.6, _base_cooldown_sp * pow(0.94, float(t)))

		spawn_count = maxi(1, _base_spawn_count_sp + int(floor(float(t) / 2.0)))
		spider_lifetime = _base_spider_lifetime_sp + 1.5 * float(t)

		explosion_radius = _base_explosion_radius_sp + 10.0 * float(t)
		explosion_d4_count = maxi(1, _base_explosion_d4_sp + int(floor(float(t) / 2.0)))
		explosion_power_scale = _base_explosion_power_scale_sp * (1.0 + 0.10 * float(t))

		bite_power_scale = _base_bite_power_scale_sp * (1.0 + 0.12 * float(t))

	_cd_max = cooldown
	_cd = minf(_cd, _cd_max)
