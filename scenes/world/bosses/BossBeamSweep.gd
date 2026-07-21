extends Node2D
class_name BossBeamSweep

@export var telegraph_time: float = 0.55
@export var sweep_time: float = 1.15
@export var width: float = 34.0
@export var length: float = 680.0
@export var damage: float = 16.0

@export var telegraph_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ExplosiveT.tscn")
@export var damage_tick: float = 0.20

@onready var area: Area2D = $Area
@onready var shape: CollisionShape2D = $Area/CollisionShape2D

var source: Node = null
var _t: float = 0.0
var _phase: int = 0 # 0 telegraph, 1 sweep
var _a0: float = 0.0
var _a1: float = 0.0
var _tick: float = 0.0
var _touching: bool = false

func setup(world_pos: Vector2, a0: float, a1: float, src: Node) -> void:
	global_position = world_pos
	_a0 = a0
	_a1 = a1
	source = src

func _ready() -> void:
	top_level = true
	# Setup collision shape
	if shape != null and shape.shape is RectangleShape2D:
		var rs := shape.shape as RectangleShape2D
		rs.size = Vector2(length, width)
	shape.position = Vector2(length * 0.5, 0.0)

	if not area.area_entered.is_connected(_on_area_entered):
		area.area_entered.connect(_on_area_entered)
	if not area.area_exited.is_connected(_on_area_exited):
		area.area_exited.connect(_on_area_exited)

	# Telegraph line using existing VFX (purely visual)
	if telegraph_scene != null:
		var v := telegraph_scene.instantiate()
		add_child(v)
		if v.has_method("setup"):
			var from := global_position
			var to := global_position + Vector2(cos(_a0), sin(_a0)) * length
			v.call("setup", from, to)

	rotation = _a0
	set_process(true)

func _process(delta: float) -> void:
	_t += delta

	if _phase == 0:
		if _t >= telegraph_time:
			_phase = 1
			_t = 0.0
			_tick = 0.0
		return

	# Sweep
	var k := clampf(_t / maxf(sweep_time, 0.001), 0.0, 1.0)
	rotation = lerpf(_a0, _a1, k)

	_tick += delta
	if _touching and _tick >= damage_tick:
		_tick = 0.0
		_damage_player()

	if _t >= sweep_time:
		queue_free()

func _on_area_entered(a: Area2D) -> void:
	if a != null and a.is_in_group("player_hurtbox"):
		_touching = true
		_tick = damage_tick # hit quickly

func _on_area_exited(a: Area2D) -> void:
	if a != null and a.is_in_group("player_hurtbox"):
		_touching = false

func _damage_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	if not p.has_method("take_damage"):
		return

	# If the boss died/was freed, don't pass a freed reference.
	# Use the beam itself as a valid fallback source.
	var src: Node = self
	if source != null and is_instance_valid(source):
		src = source

	p.call("take_damage", float(damage), src)
