extends Node2D
class_name BossMine

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")

@export var fuse: float = 1.10
@export var radius: float = 90.0
@export var damage: float = 14.0

@export var telegraph_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ShockRing.tscn")
@export var impact_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_Shockwave.tscn")
@export var damage_circle_scene: PackedScene = preload("res://core/combat/hazards/DamageCircle.tscn")

var source: Node = null
var _elapsed := 0.0
var _exploded := false
var _configured := false
var _world_origin := Vector2.ZERO
var _warning
var _intro_started := false

func setup(world_pos: Vector2, src: Node, fuse_sec: float, radius_px: float, dmg: float) -> void:
	_world_origin = world_pos
	_configured = true
	source = src
	fuse = fuse_sec
	radius = radius_px
	damage = dmg
	_elapsed = 0.0
	_exploded = false
	_intro_started = false
	if is_node_ready():
		global_position = world_pos
		_configure_warning()

func _ready() -> void:
	if _configured:
		global_position = _world_origin
	_configure_warning()
	set_process(true)


func _configure_warning() -> void:
	if not is_instance_valid(_warning):
		_warning = GroundWarning.new()
		_warning.name = "BlastWarning"
		add_child(_warning)
	_warning.configure_circle(radius)
	_warning.set_progress(0.0)


func _process(delta: float) -> void:
	if not _attack_is_valid():
		cancel_attack()
		return
	if get_tree().paused or _exploded:
		return
	if not _intro_started:
		_intro_started = true
		# Keep the authored arrival accent; the fixed boundary remains until
		# detonation instead of relying on this brief decorative ring.
		if telegraph_scene != null:
			var accent := telegraph_scene.instantiate()
			if accent.has_method("setup"):
				accent.call("setup", Vector2.ZERO, radius)
			add_child(accent)
	_elapsed += delta
	_warning.set_progress(_elapsed / maxf(0.05, fuse))
	if _elapsed >= maxf(0.05, fuse):
		_explode()

func _explode() -> void:
	if not is_inside_tree() or _exploded:
		return
	if not _attack_is_valid():
		cancel_attack()
		return
	if get_tree().paused:
		return
	_exploded = true
	var scene := get_tree().current_scene
	if scene == null:
		cancel_attack()
		return
	SfxManager.play_2d_limited(&"boss_mine_burst", global_position, 120)

	# Impact VFX
	if impact_scene != null:
		var v := impact_scene.instantiate()
		if v is Node2D:
			v.top_level = true
		if v.has_method("setup"):
			v.call("setup", global_position, radius)
		Scope.bind(v, source)
		scene.add_child(v)

	# Damage (instant / short)
	if damage_circle_scene != null:
		var d := damage_circle_scene.instantiate() as DamageCircle
		if d != null:
			d.setup(global_position, radius, damage, 0.15, source)
			d.show_footprint = true
			Scope.bind(d, source)
			scene.add_child(d)

	queue_free()


func _attack_is_valid() -> bool:
	if not Scope.is_valid_attack(self):
		return false
	if source == null:
		return true
	return is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion() and not ("dead" in source and bool(source.get("dead")))


func cancel_attack() -> void:
	_exploded = true
	set_process(false)
	visible = false
	queue_free()
