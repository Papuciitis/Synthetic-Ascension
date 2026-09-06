extends RefCounted
class_name EnemyAnimator
## Cheap stride/idle animation for a sheet-driven enemy: one region swap on
## the enemy's single Sprite2D per simulation step, the frame index read off
## the shared clock (no per-enemy timer), facing from the vertical velocity
## sign because the enemy sheets hold front and back rows only. The batched
## proxy renderer reads the same region, so materialized and proxied enemies
## draw the same frame.

const FACING_DOWN := &"down"
const FACING_UP := &"up"
const MOVING_SPEED_SQ := 25.0

var _sprite: Sprite2D = null
var _regions: Dictionary = {}  # animation name -> Array[Rect2]
var _fps := 10.0
var _phase_ms := 0
var _facing: StringName = FACING_DOWN
var _animation: StringName = &""
var _frame := -1


func setup(owner: Object, sprite: Sprite2D, frame_set: CharacterFrameSet, fps: float) -> bool:
	if sprite == null or frame_set == null or frame_set.frames == null:
		return false
	var frames := frame_set.frames
	var atlas: Texture2D = null
	_regions.clear()
	for animation_name in frames.get_animation_names():
		var rects: Array[Rect2] = []
		for index in range(frames.get_frame_count(animation_name)):
			var texture := frames.get_frame_texture(animation_name, index) as AtlasTexture
			if texture == null or texture.atlas == null:
				continue
			if atlas == null:
				atlas = texture.atlas
			rects.append(texture.region)
		if not rects.is_empty():
			_regions[StringName(animation_name)] = rects
	if atlas == null or not _regions.has(&"idle_down"):
		return false
	_sprite = sprite
	_fps = maxf(fps, 0.01)
	# Spread hordes across the stride so a crowd does not march in lockstep.
	_phase_ms = int(abs(owner.get_instance_id()) % 977) if owner != null else 0
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_facing = FACING_DOWN
	_animation = &""
	_frame = -1
	_show(&"idle_down", 0)
	return true


func is_active() -> bool:
	return _sprite != null


func tick(velocity: Vector2) -> void:
	if _sprite == null:
		return
	var moving := velocity.length_squared() > MOVING_SPEED_SQ
	if moving:
		_facing = FACING_UP if velocity.y < 0.0 else FACING_DOWN
	var animation := _pick(&"run_" if moving else &"idle_", _facing)
	var count: int = (_regions[animation] as Array).size()
	var frame := 0
	if count > 1:
		frame = int(float(Time.get_ticks_msec() + _phase_ms) * _fps / 1000.0) % count
	_show(animation, frame)


## The standing frame for the current facing: what a data-only proxy shows.
func idle_region() -> Rect2:
	if _sprite == null:
		return Rect2()
	return (_regions[_pick(&"idle_", _facing)] as Array)[0]


static func normalized_region(region: Rect2, texture_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	return Rect2(region.position / texture_size, region.size / texture_size)


func _pick(prefix: StringName, facing: StringName) -> StringName:
	var animation := StringName(String(prefix) + String(facing))
	if _regions.has(animation):
		return animation
	animation = StringName("idle_" + String(facing))
	if _regions.has(animation):
		return animation
	return &"idle_down"


func _show(animation: StringName, frame: int) -> void:
	if animation == _animation and frame == _frame:
		return
	_animation = animation
	_frame = frame
	_sprite.region_rect = (_regions[animation] as Array)[frame]
