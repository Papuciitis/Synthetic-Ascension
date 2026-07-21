extends Node2D
class_name AtmosFireflies

@export var target_group: StringName = &"player"

@export var spawn_radius: float = 560.0
@export var max_fireflies: int = 28
@export var spawn_interval_min: float = 0.22
@export var spawn_interval_max: float = 0.55

@export var life_min: float = 1.7
@export var life_max: float = 4.6

@export var speed_min: float = 10.0
@export var speed_max: float = 28.0

@export var base_alpha: float = 0.12
@export var glow_alpha_mul: float = 0.35
@export var base_radius_min: float = 1.1
@export var base_radius_max: float = 2.4

@export var tint: Color = Color(0.40, 0.72, 1.00, 1.0)
@export var z: int = 1510

var _rng := RandomNumberGenerator.new()
var _target: Node2D = null
var _spawn_t: float = 0.0
var _flies: Array = []

func _ready() -> void:
	_rng.randomize()
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cache_target()
	_spawn_t = _rng.randf_range(spawn_interval_min, spawn_interval_max)
	set_process(true)
	queue_redraw()

func _cache_target() -> void:
	_target = get_tree().get_first_node_in_group(String(target_group)) as Node2D

func _process(dt: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_cache_target()
		if _target == null:
			return

	# Keep centered on the player so the "swarm" feels like atmosphere.
	global_position = _target.global_position

	# Spawn
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		var burst: int = 1
		# Occasionally spawn a tiny burst so it feels alive.
		if _rng.randf() < 0.28:
			burst = _rng.randi_range(2, 4)
		for i in range(burst):
			if _flies.size() >= max_fireflies:
				break
			_spawn_one()
		_spawn_t = _rng.randf_range(spawn_interval_min, spawn_interval_max)

	# Update
	for i in range(_flies.size() - 1, -1, -1):
		var f = _flies[i]
		f.age += dt
		if f.age >= f.life:
			_flies.remove_at(i)
			continue

		# gentle drift + jitter
		var jitter: Vector2 = Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * 8.0
		f.vel += jitter * dt
		f.vel *= pow(0.72, dt) # mild damping
		f.pos += f.vel * dt

		# softly pull back toward center so they don't all drift away
		var d: Vector2 = f.pos
		var dist: float = d.length()
		if dist > spawn_radius:
			f.vel += (-d.normalized()) * (dist - spawn_radius) * 0.18

		_flies[i] = f

	queue_redraw()

func _spawn_one() -> void:
	var a := _rng.randf_range(0.0, TAU)
	var r := sqrt(_rng.randf()) * spawn_radius
	var p := Vector2(cos(a), sin(a)) * r

	var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	var sp := _rng.randf_range(speed_min, speed_max)

	var f = {
		"pos": p,
		"vel": dir * sp,
		"life": _rng.randf_range(life_min, life_max),
		"age": 0.0,
		"rad": _rng.randf_range(base_radius_min, base_radius_max),
		"phase": _rng.randf_range(0.0, TAU),
		"tw": _rng.randf_range(2.2, 4.0),
	}
	_flies.append(f)

func _draw() -> void:
	# Neutral haze + subtle blue fireflies.
	for f in _flies:
		var t: float = clampf(f.age / f.life, 0.0, 1.0)
		# Smooth fade in/out
		var fade := sin(t * PI)
		var tw := 0.65 + 0.35 * sin(f.phase + f.age * f.tw)
		var a := base_alpha * fade * tw

		var col := Color(tint.r, tint.g, tint.b, a)
		var glow := Color(tint.r, tint.g, tint.b, a * glow_alpha_mul)

		draw_circle(f.pos, f.rad * 2.4, glow)
		draw_circle(f.pos, f.rad, col)
