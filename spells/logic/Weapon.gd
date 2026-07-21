extends Node2D
class_name Weapon

@export var data: WeaponData

var _owner: Node2D
var _player: Node = null

var _cooldown_left: float = 0.0

@onready var muzzle: Marker2D = $Muzzle

func setup(caster: Node2D, player: Node) -> void:
	_owner = caster
	_player = player
	_cooldown_left = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func try_attack() -> void:
	if _cooldown_left > 0.0:
		return
	if data == null or data.projectile_scene == null:
		return

	# apply Haste as faster cooldown
	var cd: float = data.base_cooldown
	if _player != null and "stats" in _player and _player.stats != null:
		cd = cd / (1.0 + float(_player.stats.haste))
	_cooldown_left = maxf(cd, 0.001)

	# Spawn projectile (pool if available)
	var pm := get_node_or_null("/root/PoolManager")
	var p: Node = null
	if pm != null and is_instance_valid(pm) and pm.has_method("obtain"):
		p = pm.call("obtain", data.projectile_scene, get_tree().current_scene) as Node
	else:
		p = data.projectile_scene.instantiate()

	if p == null:
		return

	var p2 := p as Node2D
	if p2 != null:
		p2.global_position = muzzle.global_position

	var dir: Vector2 = (get_global_mouse_position() - muzzle.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# velocity
	if "velocity" in p:
		p.set("velocity", dir * data.projectile_speed)

	# source hook (if supported)
	if "source" in p:
		p.set("source", _owner)

	# apply Power from player.stats if present
	var dmg: float = data.base_damage
	if _player != null and "stats" in _player and _player.stats != null:
		dmg *= (1.0 + float(_player.stats.power))

	if "damage" in p:
		p.set("damage", dmg)

	# If we didn't pool, add to scene now
	if p.get_parent() == null:
		get_tree().current_scene.add_child(p)
