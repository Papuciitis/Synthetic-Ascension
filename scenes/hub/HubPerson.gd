extends Node2D
## One person in the hub square, anchored at the FEET (the square y-sorts by
## feet). Shows painted art when it exists — a three-view sheet (front, back,
## side facing right; left mirrors it) or a single standing pose — and
## otherwise a race rig from the baked character atlases. The rigs all wear
## the player's own outfit, so a stand-in person is tinted to read apart.
## Only a pose lives here: HubCrowd decides where people go and what they do,
## and calls tick() once a frame for everyone.

const RUN_BOB: Array[float] = [0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0]
## player.tscn's breathe loop: the head sits 1 px lower from 0.7 s to 1.9 s.
const BREATHE := 2.4
## The player's base speed, which the rig's run cycle is timed against.
const RIG_SPEED := 100.0
const AXIS_BIAS := 1.25

var facing: StringName = &"down"
var walking: bool = false
## Height of the head above the feet, for speech and labels.
var head_height: float = 80.0

var _sprite: Sprite2D = null
var _views: int = 1
var _body: AnimatedSprite2D = null
var _head_anchor: Node2D = null
var _head: AnimatedSprite2D = null
var _definition: RaceVisualDefinition = null
var _frames: CharacterFrameSet = null
var _body_anim: StringName = &""
var _head_anim: StringName = &""
var _anchors := PackedVector2Array()
var _collars := PackedVector2Array()
var _nudge := Vector2.ZERO
var _clock: float = 0.0
var _step: float = 0.0
var _speed: float = 60.0
var _horizontal: bool = false


## Painted art: `views` is 3 for a front/back/side sheet, 1 for one pose.
func setup_painted(texture: Texture2D, views: int) -> void:
	_views = maxi(1, views)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = _views
	var frame_h := float(texture.get_height())
	_sprite.offset = Vector2(0.0, -frame_h * 0.5)
	add_child(_sprite)
	head_height = frame_h
	_clock = randf() * BREATHE
	_apply()


## A race rig stand-in. `tint` multiplies the body (the outfit) only.
func setup_rig(race: StringName, tint: Color) -> bool:
	var path: String = PlayerVisualController.RACE_DEFINITIONS.get(race, "")
	if path.is_empty():
		return false
	_definition = load(path) as RaceVisualDefinition
	_frames = load(_definition.baked_frames_path()) as CharacterFrameSet if _definition != null else null
	if _frames == null or _frames.frames == null:
		return false
	_body = AnimatedSprite2D.new()
	_head_anchor = Node2D.new()
	_head = AnimatedSprite2D.new()
	for sprite in [_body, _head]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = _frames.frames
	_body.self_modulate = tint
	add_child(_body)
	add_child(_head_anchor)
	_head_anchor.add_child(_head)
	head_height = absf(_frames.collar(&"body_idle_down", 0).y) + 34.0
	_clock = randf() * BREATHE
	_apply()
	return true


func set_pose(is_walking: bool, new_facing: StringName, speed: float = 60.0) -> void:
	_speed = speed
	if is_walking == walking and new_facing == facing:
		return
	walking = is_walking
	facing = new_facing
	_apply()


## Walk pose from a velocity, with the player's hysteresis between the
## horizontal and vertical facings.
func drive(velocity: Vector2) -> void:
	if velocity.length_squared() <= 1.0:
		set_pose(false, facing, _speed)
		return
	var ax := absf(velocity.x)
	var ay := absf(velocity.y)
	if _horizontal and ay > ax * AXIS_BIAS:
		_horizontal = false
	elif not _horizontal and ax > ay * AXIS_BIAS:
		_horizontal = true
	var next: StringName
	if _horizontal:
		next = &"left" if velocity.x < 0.0 else &"right"
	else:
		next = &"up" if velocity.y < 0.0 else &"down"
	set_pose(true, next, velocity.length())


func face_towards(point: Vector2) -> void:
	var d := point - global_position
	if d.length_squared() < 1.0:
		return
	var next: StringName
	if absf(d.x) > absf(d.y):
		next = &"left" if d.x < 0.0 else &"right"
	else:
		next = &"up" if d.y < 0.0 else &"down"
	set_pose(false, next, _speed)


static func facing_of(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"left" if direction.x < 0.0 else &"right"
	return &"up" if direction.y < 0.0 else &"down"


func tick(delta: float) -> void:
	_clock = fmod(_clock + delta, BREATHE)
	if walking:
		_step += delta * maxf(20.0, _speed) / 32.0
	if _sprite != null:
		# A walking bob of two pixels; standing, the breathing pixel.
		var lift := absf(sin(_step * PI)) * 2.0 if walking else (1.0 if _clock >= 0.7 and _clock < 1.9 else 0.0)
		_sprite.position.y = -roundf(lift)
		return
	if _body != null:
		_follow()


func _apply() -> void:
	if _sprite != null:
		match facing:
			&"up":
				_sprite.frame = 1 if _views >= 3 else 0
				_sprite.flip_h = false
			&"left":
				_sprite.frame = 2 if _views >= 3 else 0
				_sprite.flip_h = true
			&"right":
				_sprite.frame = 2 if _views >= 3 else 0
				_sprite.flip_h = false
			_:
				_sprite.frame = 0
				_sprite.flip_h = false
		return
	if _body == null:
		return
	var state := "run" if walking else "idle"
	var body_anim := _pick("body", state)
	var head_anim := _pick("head", state)
	if body_anim == &"" or head_anim == &"":
		return
	if body_anim != _body_anim:
		_body_anim = body_anim
		_anchors = _frames.anchors.get(String(body_anim), PackedVector2Array())
		_collars = _frames.collars.get(String(body_anim), PackedVector2Array())
		_body.play(body_anim)
		if not walking:
			# Idle frames follow this person's own breathing clock, so a
			# crowd never breathes in lockstep.
			var n := maxi(1, _frames.frame_count(body_anim))
			var per := BREATHE / n
			_body.set_frame_and_progress(int(_clock / per) % n, fmod(_clock, per) / per)
	_body.speed_scale = clampf(_speed / RIG_SPEED, 0.4, 1.2) if walking else 1.0
	if head_anim != _head_anim:
		_head_anim = head_anim
		_head.play(head_anim)
		_head.offset = -_frames.anchor(head_anim, 0)
	_nudge = _definition.head_offset(facing)
	_follow()


func _follow() -> void:
	var f := _body.frame
	var bob := Vector2.ZERO
	if walking:
		bob.y = -_definition.run_bob_px * RUN_BOB[f % RUN_BOB.size()]
	_body.offset = -_at(_anchors, f)
	_body.position = bob
	_head_anchor.position = _at(_collars, f) + _nudge + bob
	_head.position = Vector2(0.0, -1.0 if not walking and _clock >= 0.7 and _clock < 1.9 else 0.0)


func _pick(layer: String, state: String) -> StringName:
	for candidate in ["%s_%s_%s" % [layer, state, facing], "%s_idle_%s" % [layer, facing], "%s_idle_down" % layer]:
		var anim := StringName(candidate)
		if _frames.has_animation(anim):
			return anim
	return &""


static func _at(points: PackedVector2Array, index: int) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	return points[clampi(index, 0, points.size() - 1)]
