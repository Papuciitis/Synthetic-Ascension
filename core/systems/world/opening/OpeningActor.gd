extends CharacterBody2D
class_name OpeningActor

signal engaged(actor: OpeningActor)
signal defeated(actor: OpeningActor, source: Node)

@export var role: StringName = &"construct"
@export var spec: EnemySpec
@export var max_hp: float = 16.0
@export var speed: float = 72.0
@export var hostile: bool = true
@export var requires_manual_fire: bool = false

var hp: float = 16.0
var dead: bool = false
var is_elite: bool = false
var _engaged_once: bool = false
var _player: Node2D
var _flash: float = 0.0
var _manual_fire_armed: bool = false
var _seizure_target := Vector2.INF

func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"opening_scripted_actor")
	set_meta(&"never_cull", true)
	set_meta(&"opening_scripted", true)
	set_meta(&"opening_non_hostile", not hostile)
	hp = max_hp
	if spec != null:
		max_hp = spec.max_hp
		speed = spec.speed
		hp = max_hp
	var hitbox := get_node_or_null("Hitbox") as Area2D
	if hitbox != null:
		hitbox.add_to_group(&"enemy_hitbox")
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and is_instance_valid(enemy_index) and enemy_index.has_method("register"):
		enemy_index.call("register", self)
	queue_redraw()

func _exit_tree() -> void:
	_unregister_enemy_index()

func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _flash > 0.0:
		queue_redraw()
	if dead or role == &"calibration":
		velocity = Vector2.ZERO
		return
	if not hostile:
		if role == &"officer" and _seizure_target != Vector2.INF:
			var to_records := _seizure_target - global_position
			velocity = to_records.normalized() * speed * 0.28 if to_records.length_squared() > 42.0 * 42.0 else Vector2.ZERO
			move_and_slide()
			_update_enemy_index()
		else:
			velocity = Vector2.ZERO
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		return
	var offset := _player.global_position - global_position
	velocity = offset.normalized() * speed if offset.length_squared() > 1600.0 else Vector2.ZERO
	move_and_slide()
	_update_enemy_index()

func _update_enemy_index() -> void:
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and is_instance_valid(enemy_index) and enemy_index.has_method("update_enemy"):
		enemy_index.call("update_enemy", self)

func _input(event: InputEvent) -> void:
	if requires_manual_fire and event.is_action_pressed(&"attack"):
		_manual_fire_armed = true

func take_damage(amount: float, source: Node = null) -> void:
	_apply_damage(maxf(0.0, amount), source)

func take_damage_unblockable(amount: float, source: Node = null) -> void:
	_apply_damage(maxf(0.0, amount), source)

func apply_hit_ledger(ledger: HitLedger) -> void:
	if ledger != null:
		_apply_damage(maxf(0.0, ledger.total_raw_damage), ledger.source)

func has_engaged() -> bool:
	return _engaged_once

func complete_calibration(source: Node) -> void:
	if role != &"calibration" or dead:
		return
	_apply_damage(maxf(max_hp, hp) + 1.0, source)

func _apply_damage(amount: float, source: Node) -> void:
	if dead or amount <= 0.0:
		return
	if requires_manual_fire and not _manual_fire_armed:
		return
	if not _engaged_once:
		_engaged_once = true
		hostile = role != &"calibration"
		set_meta(&"opening_non_hostile", not hostile)
		engaged.emit(self)
	hp -= amount
	_flash = 0.10
	queue_redraw()
	if RunEvents != null and source != null:
		RunEvents.damage_dealt.emit(source, amount)
	if hp <= 0.0:
		_die(source)

func set_hostile(value: bool) -> void:
	hostile = value
	set_meta(&"opening_non_hostile", not hostile)

func begin_seizure(world_target: Vector2) -> void:
	_seizure_target = world_target

func _die(source: Node) -> void:
	dead = true
	hostile = false
	velocity = Vector2.ZERO
	remove_from_group(&"enemies")
	_unregister_enemy_index()
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var hit_shape := get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if hit_shape != null:
		hit_shape.set_deferred("disabled", true)
	if SfxManager != null:
		SfxManager.play_2d(&"wardstone_complete" if role == &"calibration" else &"enemy_death", global_position)
	defeated.emit(self, source)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.2, 0.9, 1.0, 0.0), 0.75)
	tween.tween_callback(queue_free)
	queue_redraw()

func _unregister_enemy_index() -> void:
	var enemy_index := get_node_or_null("/root/EnemyIndex")
	if enemy_index != null and is_instance_valid(enemy_index) and enemy_index.has_method("unregister"):
		enemy_index.call("unregister", self)

func _draw() -> void:
	var main := Color("42d8e8")
	var edge := Color("b9f8ff")
	if role == &"officer":
		main = Color("b5453f")
		edge = Color("ffc0a8")
	elif role == &"calibration":
		main = Color("d7a34d")
		edge = Color("fff0bd")
	if _flash > 0.0:
		main = Color.WHITE
	if dead:
		main.a = 0.45
		edge.a = 0.35
	if role == &"officer":
		draw_circle(Vector2.ZERO, 22.0, Color(main, 0.25))
		draw_polyline(PackedVector2Array([Vector2(-15, -14), Vector2(0, -24), Vector2(15, -14), Vector2(18, 10), Vector2(0, 24), Vector2(-18, 10), Vector2(-15, -14)]), edge, 3.0, true)
		draw_line(Vector2(-10, 2), Vector2(10, 2), main, 4.0, true)
	elif role == &"calibration":
		draw_circle(Vector2.ZERO, 25.0, Color(main, 0.12))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, edge, 3.0, true)
		draw_line(Vector2(-28, 0), Vector2(28, 0), main, 2.0, true)
		draw_line(Vector2(0, -28), Vector2(0, 28), main, 2.0, true)
	else:
		var points := PackedVector2Array([Vector2(0, -27), Vector2(23, -8), Vector2(15, 22), Vector2(-15, 22), Vector2(-23, -8), Vector2(0, -27)])
		draw_colored_polygon(points, Color(main, 0.20))
		draw_polyline(points, edge, 3.0, true)
		draw_circle(Vector2.ZERO, 7.0, main)
