extends Area2D
class_name HealthPickup

@export_range(0.01, 1.0, 0.01) var restore_fraction: float = 0.20
@export_range(0.0, 5.0, 0.05) var pickup_delay: float = 0.20
@export_range(1.0, 120.0, 1.0) var lifetime_seconds: float = 20.0
@export var bob_height: float = 3.0
@export var bob_speed: float = 3.5

@onready var icon: Sprite2D = $Icon
@onready var glow: Sprite2D = $Glow

var _age: float = 0.0
var _picked: bool = false
var _pickup_ready: bool = false
var _icon_start: Vector2 = Vector2.ZERO
var _glow_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	monitoring = false
	monitorable = false
	_icon_start = icon.position
	_glow_start = glow.position

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_arm_pickup()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()
		return

	var bob: float = sin(_age * bob_speed) * bob_height
	icon.position = _icon_start + Vector2(0.0, bob)
	glow.position = _glow_start + Vector2(0.0, bob)
	var pulse: float = 1.08 + sin(_age * 4.0) * 0.08
	glow.scale = Vector2.ONE * pulse


func _arm_pickup() -> void:
	if pickup_delay > 0.0:
		await get_tree().create_timer(pickup_delay).timeout
	if not is_inside_tree() or _picked:
		return
	_pickup_ready = true
	monitorable = true
	monitoring = true


func _player_from(candidate: Node) -> Node:
	if candidate == null:
		return null
	if candidate.is_in_group("player"):
		return candidate
	var parent: Node = candidate.get_parent()
	if parent != null and parent.is_in_group("player"):
		return parent
	return null


func _try_pickup(candidate: Node) -> void:
	if _picked or not _pickup_ready:
		return

	var player: Node = _player_from(candidate)
	if player == null or not player.has_method("heal"):
		return

	var maximum_hp: float = float(player.get("max_hp"))
	var current_hp: float = float(player.get("hp"))
	if maximum_hp <= 0.0 or current_hp >= maximum_hp - 0.001:
		return

	_picked = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	player.call("heal", maximum_hp * clampf(restore_fraction, 0.01, 1.0))

	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.call("play_2d", &"pickup", global_position)
	queue_free()


func _on_area_entered(other: Area2D) -> void:
	_try_pickup(other)


func _on_body_entered(other: Node2D) -> void:
	_try_pickup(other)
