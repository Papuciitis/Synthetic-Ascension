extends Node2D
class_name BossMine

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")
const ImpactSprites = preload("res://scenes/world/bosses/BossImpactSprites.gd")
const GROUP := &"boss_mine"

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

func setup(world_pos: Vector2, src: Node, fuse_sec: float, radius_px: float, dmg: float) -> void:
	_world_origin = world_pos
	_configured = true
	source = src
	fuse = fuse_sec
	radius = radius_px
	damage = dmg
	_elapsed = 0.0
	_exploded = false
	if is_node_ready():
		global_position = world_pos
		_configure_warning()

func _ready() -> void:
	if _configured:
		global_position = _world_origin
	# Brains find live mines through this group, never by scanning the world.
	add_to_group(GROUP)
	_configure_warning()
	set_process(true)


func _configure_warning() -> void:
	if not is_instance_valid(_warning):
		_warning = GroundWarning.new()
		_warning.name = "BlastWarning"
		add_child(_warning)
	_warning.set_attack_style(&"mine")
	_warning.configure_circle(radius)
	_warning.set_progress(0.0)


func _process(delta: float) -> void:
	if not _uses_teaching_clock():
		_tick_fuse(delta)

func _physics_process(delta: float) -> void:
	if _uses_teaching_clock():
		_tick_fuse(delta)

func _uses_teaching_clock() -> bool:
	return is_instance_valid(source) and source.is_in_group(&"miniboss") and not source.is_in_group(&"boss")

func _tick_fuse(delta: float) -> void:
	if not _attack_is_valid():
		cancel_attack()
		return
	if get_tree().paused or _exploded:
		return
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

	# The planted occult glyph bursts in place; it never borrows the physical
	# slam or electrical shock artwork. It is cosmetic and owns no damage.
	var impact := ImpactSprites.new()
	impact.top_level = true
	impact.setup(global_position, radius, &"mine", 0.42)
	Scope.bind(impact, source)
	scene.add_child(impact)

	# Damage (instant / short)
	if damage_circle_scene != null:
		var d := damage_circle_scene.instantiate() as DamageCircle
		if d != null:
			d.attack_style = &"mine"
			d.setup(global_position, radius, damage, 0.15, source)
			d.show_footprint = true
			Scope.bind(d, source)
			# The mine node expires before its damage payload. Keep that brief
			# active pressure inside the S5 controller's pattern budget as well.
			if is_instance_valid(source):
				var brain := source.get_node_or_null("BossBrain")
				if brain != null and brain.has_method("_register_teaching_pressure"):
					brain.call("_register_teaching_pressure", d)
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
