extends Node2D
class_name BossPylon

const DeathContextScript = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
const WorldTypes = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

@export var max_hp: float = 40.0
@export var shoot_every: float = 1.25
@export var projectile_scene: PackedScene = preload("res://core/combat/projectile/EnemyProjectile.tscn")
@export var projectile_speed: float = 360.0
@export var projectile_damage: float = 7.0
@export var projectile_lifetime: float = 2.5

@onready var hitbox: Area2D = $Hitbox

var hp: float = 0.0
var dead: bool = false
var _cd: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies") # so player projectiles can confirm
	add_to_group(&"boss_like")
	set_meta(&"objective_required", true)
	set_meta(&"never_cull", true)
	if hitbox != null:
		hitbox.add_to_group("enemy_hitbox")
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("register"):
		enemy_index.call("register", self)
	_cd = randf() * shoot_every
	set_process(true)


func _exit_tree() -> void:
	_unregister_enemy_index()

func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	if source != null:
		RunEvents.damage_dealt.emit(source, amount)
	if hp > 0.0:
		return
	_die(source)

func _die(source: Node) -> void:
	dead = true
	var handle := EnemyCombat.handle_for_actor(self)
	var p: Node = source
	if p == null:
		p = get_tree().get_first_node_in_group("player")
	RunEvents.enemy_defeated.emit(DeathContextScript.new(
		handle,
		&"boss_pylon",
		global_position,
		EnemyWorld.get_flags(handle) if handle != WorldTypes.INVALID_HANDLE else WorldTypes.Flags.CRITICAL,
		p,
		{"legacy_node": true},
	))
	RunEvents.enemy_killed.emit(p, self, global_position)
	_unregister_enemy_index()
	queue_free()


func _unregister_enemy_index() -> void:
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("unregister"):
		enemy_index.call("unregister", self)

func _process(delta: float) -> void:
	if dead:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _cd > 0.0:
		return
	_cd = maxf(shoot_every, 0.10)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var dir := (player.global_position - global_position)
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()

	if projectile_scene != null:
		var proj := projectile_scene.instantiate() as EnemyProjectile
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		proj.setup(dir, projectile_speed, projectile_damage, projectile_lifetime, self)
