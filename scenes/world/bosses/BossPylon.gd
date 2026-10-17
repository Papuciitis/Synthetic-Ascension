extends Node2D
class_name BossPylon

const DeathContextScript = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
const WorldTypes = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const MUZZLE := Vector2(0, -34)
const COLLAPSE_SECONDS := 0.18

@export var max_hp: float = 40.0
@export var shoot_every: float = 1.25
@export var projectile_scene: PackedScene = preload("res://core/combat/projectile/EnemyProjectile.tscn")
@export var projectile_speed: float = 360.0
@export var projectile_damage: float = 7.0
@export var projectile_lifetime: float = 2.5
@export var lifetime: float = 12.0
@export var shot_windup: float = 0.3

@onready var hitbox: Area2D = $Hitbox
@onready var body: Sprite2D = $Body
@onready var shadow: Sprite2D = $Shadow
@onready var charge_cue: Sprite2D = $ChargeCue
@onready var charge_ring: Sprite2D = $ChargeRing
@onready var destruction_burst: Sprite2D = $DestructionBurst

var hp: float = 0.0
var dead: bool = false
var _cd: float = 0.0
var _life_left: float = 12.0
var _windup_left: float = 0.0
var _shot_dir := Vector2.RIGHT
var _flash_left: float = 0.0
var _collapse_left: float = 0.0
var _configured := false
var _spawn_position := Vector2.ZERO
var _body_scale := Vector2.ONE
var _source: WeakRef


## Configure before add_child so the first world/index snapshot is already
## at the intended position, including under a translated arena parent.
func setup(world_pos: Vector2, source: Node, life: float = 12.0) -> void:
	_spawn_position = world_pos
	_configured = true
	lifetime = clampf(life, 0.05, 30.0)
	_source = weakref(source) if source != null else null
	Scope.bind(self, source)

func _ready() -> void:
	if _configured:
		global_position = _spawn_position
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	hp = max_hp
	_life_left = clampf(lifetime, 0.05, 30.0)
	_body_scale = body.scale
	_set_sprite_size(shadow, Vector2(36.0, 10.8))
	add_to_group("enemies") # so player projectiles can confirm
	add_to_group(&"boss_like")
	add_to_group(&"boss_pylon")
	set_meta(&"objective_required", true)
	set_meta(&"never_cull", true)
	if hitbox != null:
		hitbox.add_to_group("enemy_hitbox")
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("register"):
		enemy_index.call("register", self)
	_cd = randf() * shoot_every
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	_unregister_enemy_index()

func take_damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	_flash_left = 0.07
	queue_redraw()
	if source != null:
		RunEvents.damage_dealt.emit(source, amount)
	if hp > 0.0:
		return
	_die(source)

func _die(source: Node) -> void:
	dead = true
	_windup_left = 0.0
	_hide_charge_sprites()
	destruction_burst.visible = true
	_set_sprite_size(destruction_burst, Vector2.ONE * 18.0)
	_disable_hitbox()
	var handle := EnemyCombat.handle_for_actor(self)
	var flags := EnemyWorld.get_flags(handle) if handle != WorldTypes.INVALID_HANDLE else WorldTypes.Flags.CRITICAL
	_unregister_enemy_index()
	var p: Node = source
	if p == null:
		p = get_tree().get_first_node_in_group("player")
	RunEvents.enemy_defeated.emit(DeathContextScript.new(
		handle,
		&"boss_pylon",
		global_position,
		flags,
		p,
		{"legacy_node": true},
	))
	RunEvents.enemy_killed.emit(p, self, global_position)
	_collapse_left = COLLAPSE_SECONDS
	queue_redraw()


## Expiry, boss death/leash and arena teardown remove the device without
## advertising a player kill to rewards, procs or the encounter UI.
func cancel_attack() -> void:
	dead = true
	_windup_left = 0.0
	_hide_charge_sprites()
	_disable_hitbox()
	_unregister_enemy_index()
	queue_free()


func _disable_hitbox() -> void:
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)


func _unregister_enemy_index() -> void:
	# _exit_tree already released the handle if scope teardown reaches us later.
	if not is_inside_tree():
		return
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and enemy_index.has_method("unregister"):
		enemy_index.call("unregister", self)

func _process(delta: float) -> void:
	if dead:
		if _collapse_left > 0.0:
			_collapse_left = maxf(0.0, _collapse_left - delta)
			modulate.a = _collapse_left / COLLAPSE_SECONDS
			body.scale = _body_scale * (0.75 + 0.25 * modulate.a)
			_set_sprite_size(destruction_burst, Vector2.ONE * lerpf(18.0, 52.0, 1.0 - modulate.a))
			destruction_burst.modulate.a = modulate.a
			queue_redraw()
			if _collapse_left <= 0.0:
				queue_free()
		return
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	_life_left -= delta
	if _life_left <= 0.0:
		cancel_attack()
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	body.modulate = Color(1.65, 1.3, 1.8) if _flash_left > 0.0 else Color.WHITE
	if _windup_left > 0.0:
		if _holds_fire():
			# A major pattern began during the windup: this shot waits for the
			# next gap instead of joining the pattern.
			_windup_left = 0.0
			_hide_charge_sprites()
			queue_redraw()
			return
		_windup_left = maxf(0.0, _windup_left - delta)
		_update_charge_sprites()
		queue_redraw()
		if _windup_left <= 0.0:
			_hide_charge_sprites()
			_fire_shot()
		return
	_cd = maxf(_cd - delta, 0.0)
	if _cd > 0.0 or _holds_fire():
		return
	_cd = maxf(shoot_every, 0.10)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var dir := (player.global_position - (global_position + MUZZLE))
	if dir.length_squared() < 0.001:
		return
	_shot_dir = dir.normalized()
	_windup_left = maxf(0.05, shot_windup)
	charge_cue.position = MUZZLE + _shot_dir * 25.0
	charge_cue.rotation = _shot_dir.angle()
	_set_sprite_size(charge_cue, Vector2(50.0, 8.0))
	charge_cue.visible = true
	charge_ring.visible = true
	_update_charge_sprites()
	queue_redraw()


## A main boss's major pattern (its tell, its release, its recovery, its
## bolts and mines in play) is one spatial demand at a time: pylons wait.
func _holds_fire() -> bool:
	var owner_boss = _source.get_ref() if _source != null else null
	if not is_instance_valid(owner_boss):
		return false
	var brain: Node = owner_boss.get_node_or_null("BossBrain")
	return brain != null and brain.has_method("pylons_hold_fire") and bool(brain.call("pylons_hold_fire"))


func _update_charge_sprites() -> void:
	var progress := 1.0 - _windup_left / maxf(shot_windup, 0.05)
	_set_sprite_size(charge_ring, Vector2.ONE * (8.0 + progress * 10.0))
	charge_ring.modulate.a = 0.5 + progress * 0.5


func _hide_charge_sprites() -> void:
	if is_instance_valid(charge_cue):
		charge_cue.visible = false
	if is_instance_valid(charge_ring):
		charge_ring.visible = false


## Keep gameplay dimensions stable when a higher-resolution PNG is assigned.
func _set_sprite_size(sprite: Sprite2D, size: Vector2) -> void:
	if sprite.texture != null:
		sprite.scale = size / sprite.texture.get_size()


func _fire_shot() -> void:
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return

	if projectile_scene != null:
		var world := get_tree().current_scene
		if world == null:
			return
		var proj := projectile_scene.instantiate() as EnemyProjectile
		if proj == null:
			return
		proj.setup(_shot_dir, projectile_speed, projectile_damage, projectile_lifetime, self)
		Scope.bind(proj, self)
		proj.position = (world as Node2D).to_local(global_position + MUZZLE) if world is Node2D else global_position + MUZZLE
		world.add_child(proj)
		SfxManager.play_2d_limited(&"boss_pylon_shot", global_position + MUZZLE, 150)
		_flash_left = 0.09
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	# The health strip is UI; world art and feedback use PNG sprites.
	if hp < max_hp:
		draw_rect(Rect2(-15, 9, 30, 3), Color(0.08, 0.03, 0.08, 0.9))
		draw_rect(Rect2(-15, 9, 30 * clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0), 3), Color(0.85, 0.55, 0.95))
