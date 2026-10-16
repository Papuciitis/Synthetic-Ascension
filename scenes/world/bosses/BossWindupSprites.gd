extends Node2D
## Authored raster anticipation attached to a boss. Its ground lane communicates
## committed charge travel; its upper accent remains visible over body artwork.
const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const CHARGE = preload("res://scenes/world/bosses/art/vfx/charge_windup_v1.png")
const RIPPLE = preload("res://assets/textures/vfx/encounters/pulse_ripple_v1.png")
const RIPPLE_CONTENT_RADIUS := 562.741948
# Measured alpha > .2 texel centers in the unchanged 2172 x 724 source.
const CHARGE_LEFT := 65.5
const CHARGE_RIGHT := 2108.5
const CHARGE_TOP := 109.5
const CHARGE_BOTTOM := 596.5

var _duration := 0.55
var _elapsed := 0.0
var _kind: StringName = &"charge"
var _direction := Vector2.RIGHT
var _length := 280.8
var _lane: Sprite2D
var _accent: Sprite2D
var _brace: Sprite2D


func setup(direction: Vector2, seconds: float, kind: StringName, length: float = 280.8) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_duration = maxf(seconds, 0.05)
	_kind = kind
	_length = maxf(length, 1.0)
	_elapsed = 0.0
	if is_node_ready():
		_update_art()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_lane = _sprite("ChargeLane", CHARGE, 1)
	_brace = _sprite("BracedFooting", RIPPLE, 1)
	_accent = _sprite("CastingAccent", RIPPLE, 11)
	_update_art()


func _sprite(label: String, texture: Texture2D, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_as_relative = false
	sprite.z_index = depth
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		cancel_attack()
		return
	_update_art()


func _update_art() -> void:
	var actor := get_parent() as Node2D
	if actor == null:
		return
	# Arena body scaling must not multiply the lane's actual world distance.
	global_transform = Transform2D(0.0, actor.global_position)
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	var physical := _kind == &"charge" or _kind == &"slam" or _kind == &"shock"
	_lane.visible = _kind == &"charge"
	var sx := _length / (CHARGE_RIGHT - CHARGE_LEFT)
	var sy := 64.0 / (CHARGE_BOTTOM - CHARGE_TOP)
	_lane.scale = Vector2(sx, sy)
	_lane.rotation = _direction.angle()
	var center := Vector2(CHARGE.get_size()) * 0.5
	_lane.position = Vector2((center.x - CHARGE_LEFT) * sx, (center.y - (CHARGE_TOP + CHARGE_BOTTOM) * 0.5) * sy).rotated(_lane.rotation)
	_lane.modulate = Color(1, 1, 1, lerpf(0.55, 0.95, progress))
	_brace.visible = physical
	_brace.scale = Vector2.ONE * 36.0 / RIPPLE_CONTENT_RADIUS
	_brace.modulate = Color(1.0, 0.84, 0.60, 0.45 + 0.2 * progress)
	_accent.position = _direction * 24.0 + Vector2(0.0, -28.0)
	var radius := 34.0 if reduced else lerpf(24.0, 34.0, progress)
	_accent.scale = Vector2.ONE * radius / RIPPLE_CONTENT_RADIUS
	var tint := Color(1.0, 0.88, 0.65) if physical else Color(0.88, 0.72, 1.0)
	tint.a = maxf(0.35, AccessibilityPresentation.current_flash_alpha(0.55 + 0.35 * progress))
	_accent.modulate = tint


func cancel_attack() -> void:
	visible = false
	set_process(false)
	queue_free()
