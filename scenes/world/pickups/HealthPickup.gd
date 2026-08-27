extends Area2D
class_name HealthPickup

@export_range(0.01, 1.0, 0.01) var restore_fraction: float = 0.20
@export_range(0.0, 5.0, 0.05) var pickup_delay: float = 0.20
@export_range(1.0, 120.0, 1.0) var lifetime_seconds: float = 20.0
@export var bob_height: float = 3.0
@export var bob_speed: float = 3.5

@onready var icon: Sprite2D = $Icon
@onready var glow: Sprite2D = $Glow

const MAGNET_RADIUS: float = 110.0
const MAGNET_SPEED_MAX: float = 420.0
# Far pickups re-check the player distance at 4 Hz instead of every frame
# (same idle poll as ItemPickup).
const MAGNET_IDLE_DISTANCE: float = MAGNET_RADIUS * 3.0
const MAGNET_IDLE_POLL_SEC: float = 0.25

var _age: float = 0.0
var _picked: bool = false
var _pickup_ready: bool = false
var _icon_start: Vector2 = Vector2.ZERO
var _glow_start: Vector2 = Vector2.ZERO
var _magnet_cooldown: float = 0.0
var _player_ref: Node2D = null


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
	_magnet(delta)


func _magnet(delta: float) -> void:
	# Drift toward a nearby wounded player; the close-range retry also fixes
	# the latch where a full-HP player standing inside the pickup never
	# triggers it again after healing down (area signals only fire on entry).
	if _picked or not _pickup_ready:
		return
	if _magnet_cooldown > 0.0:
		_magnet_cooldown -= delta
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		if _player_ref == null:
			return
	var maximum_hp: float = float(_player_ref.get("max_hp"))
	if maximum_hp <= 0.0 or float(_player_ref.get("hp")) >= maximum_hp - 0.001:
		return
	var distance: float = global_position.distance_to(_player_ref.global_position)
	if distance > MAGNET_RADIUS:
		if distance > MAGNET_IDLE_DISTANCE:
			_magnet_cooldown = MAGNET_IDLE_POLL_SEC
		return
	var pull: float = 1.0 - distance / MAGNET_RADIUS
	var speed: float = lerpf(60.0, MAGNET_SPEED_MAX, pull * pull)
	global_position = global_position.move_toward(_player_ref.global_position, speed * delta)
	if distance < 16.0:
		_try_pickup(_player_ref)
		if not _picked:
			_magnet_cooldown = 1.0


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
