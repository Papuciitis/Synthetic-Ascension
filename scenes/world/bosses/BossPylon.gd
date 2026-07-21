extends Node2D
class_name BossPylon

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
	if hitbox != null:
		hitbox.add_to_group("enemy_hitbox")
	_cd = randf() * shoot_every
	set_process(true)

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
	var p: Node = source
	if p == null:
		p = get_tree().get_first_node_in_group("player")
	RunEvents.enemy_killed.emit(p, self, global_position)
	queue_free()

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
