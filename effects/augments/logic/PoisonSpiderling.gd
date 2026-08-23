extends CharacterBody2D
class_name PoisonSpiderling

@export var move_speed: float = 300.0
@export var seek_radius: float = 520.0
@export var bite_range: float = 22.0
@export var bite_cd: float = 0.55

@export var tail_len_min: float = 14.0
@export var tail_len_max: float = 42.0


@export var bite_dice_sides: int = 3
@export var bite_base_bonus: float = 1.0

@export var unblockable_method: StringName = &"take_damage_unblockable"

# NEW: visuals (no extra scenes required)
@export var color_core: Color = Color(0.75, 1.00, 0.25, 1.0)
@export var color_glow: Color = Color(0.10, 0.80, 0.25, 0.65)
@export var trail_width: float = 2.6
@export var trail_alpha: float = 0.7
@export var tail_len: float = 22.0
@export var glow_mul: float = 3.0
@export var body_radius: float = 5.0

# Optional: assign later if you want extra pop
@export var vfx_bite_scene: PackedScene
@export var vfx_explode_scene: PackedScene

var player: Node2D = null
var _life_left: float = 12.0
var _bite_timer: float = 0.0

var _bite_power_scale: float = 6.0
var _owner_power: float = 0.0

var _last_vel: Vector2 = Vector2.ZERO

var _target_handle: int = EnemyWorldTypes.INVALID_HANDLE
var _target_refresh: float = 0.0
var _redraw_t: float = 0.0
var _pooled: bool = false

func setup(p: Node2D, lifetime: float, bite_power_scale: float, power: float) -> void:
	player = p
	_life_left = lifetime
	_bite_power_scale = bite_power_scale
	_owner_power = power

func _ready() -> void:
	set_process(true)
	add_to_group("spiderlings")

	_pooled = has_meta("__pool_key")
	_target_refresh = randf_range(0.0, 0.1)
	_redraw_t = 0.0

	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		material = CanvasItemMaterial.new()
		(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	queue_redraw()

func _process(dt: float) -> void:
	_life_left -= dt
	if _life_left <= 0.0:
		_despawn()
		return

	_bite_timer = maxf(_bite_timer - dt, 0.0)

	# Throttle target refresh (lots of spiderlings is common)
	_target_refresh = maxf(_target_refresh - dt, 0.0)
	if _target_refresh <= 0.0:
		_target_refresh = 0.10
		_target_handle = _find_nearest_enemy()

	if EnemyWorld.is_valid_handle(_target_handle) and not EnemyWorld.is_dying(_target_handle):
		_chase_and_bite(_target_handle)
	else:
		_target_handle = EnemyWorldTypes.INVALID_HANDLE
		_orbit_player()

	# keep a stable facing for trail drawing
	if velocity.length_squared() > 0.001:
		_last_vel = velocity
		rotation = velocity.angle()

	# Don't redraw every frame unless fading/points change: cap to ~15fps
	_redraw_t = maxf(_redraw_t - dt, 0.0)
	if _redraw_t <= 0.0:
		_redraw_t = 0.066
		queue_redraw()

func _chase_and_bite(handle: int) -> void:
	var target_position := EnemyCombat.position_for_handle(handle)
	var to_t: Vector2 = target_position - global_position
	var d2: float = to_t.length_squared()

	if d2 <= bite_range * bite_range:
		velocity = Vector2.ZERO
		if _bite_timer <= 0.0:
			_bite_timer = bite_cd
			_deal_bite(handle, target_position)
		return

	var dir: Vector2 = to_t.normalized()
	velocity = dir * move_speed
	move_and_slide()

func _orbit_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	var to_p: Vector2 = player.global_position - global_position
	var d: float = to_p.length()

	if d > 60.0:
		velocity = to_p.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _deal_bite(handle: int, target_position: Vector2) -> void:
	var roll: int = randi_range(1, max(1, bite_dice_sides))
	var dmg: float = float(roll) + bite_base_bonus + (_owner_power * _bite_power_scale)

	# VFX (fangs)
	if vfx_bite_scene != null:
		var v: Node = vfx_bite_scene.instantiate()
		var v2: Node2D = v as Node2D
		if v2 != null:
			get_tree().current_scene.add_child(v2)
			var dir: Vector2 = (target_position - global_position).normalized()
			v2.global_position = target_position
			if v2.has_method("setup"):
				v2.call("setup", target_position, dir)

	# Credit the summoner: without a source, bites emit no damage_dealt
	# (no lifesteal) and kills have no attribution, unlike detonations.
	EnemyCombat.apply_damage(handle, dmg, 1, player)


func explode(dmg: float, radius: float, source: Node = null) -> void:
	_spawn_explode_vfx(radius)

	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(global_position, radius, handles)
	for handle in handles:
		EnemyCombat.apply_damage(handle, dmg, 1, source)

	_despawn()

func take_damage(_amount: float, _source: Node = null) -> void:
	_despawn()

func _apply_damage(target: Node, dmg: float, source: Node) -> void:
	if target == null:
		return

	var mname: String = String(unblockable_method)
	if target.has_method(mname):
		target.call(mname, dmg, source)
	elif target.has_method("take_damage"):
		target.call("take_damage", dmg, source)

func _find_nearest_enemy() -> int:
	return EnemyCombat.nearest_enemy(global_position, seek_radius)

# -----------------------
# Optional VFX scenes
# -----------------------

func _spawn_bite_vfx(pos: Vector2) -> void:
	if vfx_bite_scene == null:
		return
	var v: Node = vfx_bite_scene.instantiate()
	var n2 := v as Node2D
	if n2 != null:
		n2.global_position = pos
	get_tree().current_scene.add_child(v)

func _spawn_explode_vfx(radius: float) -> void:
	if vfx_explode_scene == null:
		return
	var v: Node = vfx_explode_scene.instantiate()
	if v == null:
		return
	get_tree().current_scene.add_child(v)

	if v.has_method("setup"):
		v.call("setup", global_position, radius, color_core, color_glow)
	else:
		var n2 := v as Node2D
		if n2 != null:
			n2.global_position = global_position

# -----------------------
# Built-in draw “juice”
# -----------------------

func _despawn() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()

func _draw() -> void:
	# local X axis is forward because we rotate in _process()
	var spd: float = velocity.length()
	var speed_t: float = clampf(spd / 320.0, 0.0, 1.0)

	# Read optional exported vars safely (won't error if they don't exist)
	var vmin: Variant = get("tail_len_min")
	var vmax: Variant = get("tail_len_max")

	var min_len: float = 14.0
	var max_len: float = 42.0

	if typeof(vmin) == TYPE_FLOAT or typeof(vmin) == TYPE_INT:
		min_len = float(vmin)
	if typeof(vmax) == TYPE_FLOAT or typeof(vmax) == TYPE_INT:
		max_len = float(vmax)

	var tail_length: float = lerpf(min_len, max_len, speed_t)

	var a: float = trail_alpha
	var back: Vector2 = Vector2.LEFT * tail_length

	# glow underlay (wide)
	draw_line(
		Vector2.ZERO,
		back,
		Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * a),
		trail_width * 3.2,
		true
	)

	# core
	draw_line(
		Vector2.ZERO,
		back,
		Color(color_core.r, color_core.g, color_core.b, a),
		trail_width,
		true
	)

	# head dot
	draw_circle(
		Vector2.ZERO,
		maxf(2.0, trail_width * 0.75),
		Color(color_core.r, color_core.g, color_core.b, 0.9)
	)
