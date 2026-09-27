extends Node2D
## Beka at home in the hub (docs/art/2026-09-27-hub-npc-art.md §3). The hub
## is where she lives: every visit she naps on her bed in the Quiet Alcove,
## wanders to warm spots, grooms, and comes to sit by the player when they
## linger. When she rides with this run (the Offhand), she follows the player
## around the square instead, and naps on her bed while they linger there.
## Whenever she ends up near her bed, she curls up on it.
##
## She can be petted (the interact key; HubWorld picks the nearest thing in
## range): a purr and a small heart, nothing else. She is safe and blocks
## nothing: no collision, no gameplay effect. Anchored at her FEET like
## everyone in the square. The combat companion's own cat stays hidden while
## this one exists (group "hub_beka").

enum State { SLEEP, STRETCH, WALK, SIT, GROOM, CONTENT }

const PET_RANGE := 60.0
const BED_RANGE := 2.5 * 64.0
const WALK_SPEED := 62.0
const CATCH_UP_SPEED := 150.0
## Following: where she keeps to, beside and a little behind the player's feet.
const FOLLOW_OFFSET := Vector2(-40.0, 8.0)
const SIT_HEIGHT := 34.0
const SLEEP_HEIGHT := 24.0
const WALK_HEIGHT := 28.0

var state: State = State.SLEEP
var following: bool = false
var focused: bool = false:
	set(value):
		if focused != value:
			focused = value
			_overlay_redraw()
## Counts pets this visit (tests read it).
var pets: int = 0
var bed: Vector2 = Vector2.ZERO

var _hub: HubWorld = null
var _crowd: Node = null
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite2D = null
var _overlay: Node2D = null
var _tex: Dictionary = {}
var _path := PackedVector2Array()
var _path_i: int = 0
var _timer: float = 0.0
var _speed: float = WALK_SPEED
var _face_left: bool = false
var _after_content: State = State.SIT
var _outings: int = 0
var _still: float = 0.0
var _last_player := Vector2.INF
var _walk_clock: float = 0.0
var _heart: float = 0.0
var _purr: float = 0.0
var _bed_linger: float = 0.0
var _goal_bed: bool = false
## Where the current path was planned to; she re-plans only when the player
## has moved (a target inside a prop's clearance is never reached exactly).
var _aim := Vector2.INF
var _equip_check: float = 0.0


func setup(world: HubWorld, crowd: Node, bed_feet: Vector2, equipped: bool) -> void:
	_hub = world
	_crowd = crowd
	bed = bed_feet
	following = equipped
	_rng.randomize()
	name = "Beka"
	add_to_group(&"hub_beka")
	for key in ["sit", "sleep"]:
		_tex[key] = _load("res://assets/textures/companions/beka_%s.png" % key)
	for key in ["walk", "content", "groom", "stretch", "stand"]:
		_tex[key] = _load("res://assets/textures/hub/hub_beka_%s.png" % key)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_overlay = Node2D.new()
	_overlay.name = "BekaOverlay"
	_overlay.draw.connect(_draw_overlay)
	world._label_layer.add_child(_overlay)
	tree_exiting.connect(_overlay.queue_free)
	var player: Node2D = world._player
	if following and player != null:
		position = player.global_position + Vector2(0.0, world.FEET) + FOLLOW_OFFSET
		_enter(State.SIT)
	elif _rng.randf() < 0.6:
		position = bed
		_enter(State.SLEEP)
	else:
		position = _warm_spot()
		_enter(State.SIT)


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func is_asleep_on_bed() -> bool:
	return state == State.SLEEP and position.distance_to(bed) < 6.0


func interact_point() -> Vector2:
	return global_position


func in_pet_range(feet: Vector2) -> bool:
	return feet.distance_to(global_position) < PET_RANGE


## Petting: a purr and a heart. Asleep, she stays asleep.
func pet() -> void:
	pets += 1
	_heart = 1.4
	_purr = 1.6
	if state != State.SLEEP:
		_after_content = State.SIT
		_path = PackedVector2Array()
		_enter(State.CONTENT)
	_overlay_redraw()


# ---------------------------------------------------------------- behaviour

func tick(delta: float) -> void:
	_sync_following(delta)
	var feet := _player_feet()
	if feet != Vector2.INF:
		_still = _still + delta if _last_player != Vector2.INF and feet.distance_to(_last_player) < 2.0 else 0.0
		_last_player = feet
	_heart = maxf(0.0, _heart - delta)
	_purr = maxf(0.0, _purr - delta)
	if following:
		_tick_follow(delta, feet)
	else:
		_tick_home(delta, feet)
	_update_sprite(delta)
	if _overlay != null:
		_overlay.global_position = global_position
		if _heart > 0.0 or _purr > 0.0 or state == State.SLEEP:
			_overlay.queue_redraw()


func _tick_home(delta: float, feet: Vector2) -> void:
	match state:
		State.SLEEP:
			_timer -= delta
			if _timer <= 0.0:
				_enter(State.STRETCH)
		State.STRETCH, State.GROOM, State.CONTENT:
			_timer -= delta
			if _timer <= 0.0:
				if state == State.CONTENT:
					_enter(_after_content)
				else:
					_decide(feet)
		State.SIT:
			_timer -= delta
			# A player who lingers nearby gets company.
			if feet != Vector2.INF and _still > 3.0 and feet.distance_to(position) < 8.0 * 64.0 and feet.distance_to(position) > 70.0:
				_go(_beside(feet), false)
			elif _timer <= 0.0:
				if _rng.randf() < 0.3:
					_enter(State.GROOM)
				else:
					_decide(feet)
		State.WALK:
			if _walk(delta, _speed):
				_arrive()


func _tick_follow(delta: float, feet: Vector2) -> void:
	if feet == Vector2.INF:
		return
	# Lingering by her bed: she hops on and naps until the player moves off.
	if feet.distance_to(bed) < 2.0 * 64.0:
		_bed_linger += delta
	else:
		_bed_linger = 0.0
	if state == State.SLEEP:
		if feet.distance_to(bed) > 4.0 * 64.0:
			_enter(State.STRETCH)
		return
	if state == State.CONTENT or state == State.STRETCH:
		_timer -= delta
		if _timer > 0.0:
			return
		_enter(State.SIT)
	if _bed_linger > 4.0 and state != State.WALK:
		_go(bed, true)
	var target := feet + FOLLOW_OFFSET
	var gap := position.distance_to(target)
	if state == State.WALK:
		if _goal_bed:
			if _walk(delta, WALK_SPEED):
				_arrive()
			return
		# Re-aim at the moving player; run to catch up when far behind.
		if gap < 18.0:
			_enter(State.SIT)
			return
		_speed = CATCH_UP_SPEED if gap > 180.0 else WALK_SPEED * 1.4
		if _path_i >= _path.size() or _aim.distance_to(target) > 48.0:
			_set_path(target)
		if _walk(delta, _speed):
			_enter(State.SIT)
	elif gap > 70.0 and _aim.distance_to(target) > 24.0:
		_goal_bed = false
		_set_path(target)
		# Unreachable, or already as close as the paving allows: stay put.
		if not _path.is_empty() and _path[_path.size() - 1].distance_to(position) > 12.0:
			_enter(State.WALK)


## Equipping or unequipping her at the gear corner switches her over at once.
func _sync_following(delta: float) -> void:
	_equip_check -= delta
	if _equip_check > 0.0 or _hub == null:
		return
	_equip_check = 0.5
	var equipped := _hub._beka_equipped()
	if equipped == following:
		return
	following = equipped
	_goal_bed = false
	_bed_linger = 0.0
	_path = PackedVector2Array()
	_path_i = 0
	_aim = Vector2.INF
	if state == State.WALK or state == State.GROOM:
		_enter(State.SIT)


func _decide(feet: Vector2) -> void:
	_outings += 1
	if _outings >= 3 and _rng.randf() < 0.5:
		_go(bed, true)
		return
	if feet != Vector2.INF and _rng.randf() < 0.3 and feet.distance_to(position) < 8.0 * 64.0:
		_go(_beside(feet), false)
		return
	_go(_warm_spot(), false)


func _arrive() -> void:
	# Near her bed, she goes to sleep on it.
	if _goal_bed or position.distance_to(bed) < BED_RANGE:
		if position.distance_to(bed) > 6.0:
			_go(bed, true)
			return
		position = bed
		_outings = 0
		_enter(State.SLEEP)
		return
	_enter(State.SIT)
	var feet := _player_feet()
	if feet != Vector2.INF and feet.distance_to(position) < 90.0:
		_face_left = feet.x < position.x


func _go(target: Vector2, to_bed: bool) -> void:
	_goal_bed = to_bed
	_speed = WALK_SPEED
	_set_path(target)
	if _path.is_empty():
		if to_bed:
			position = bed
			_enter(State.SLEEP)
		else:
			_enter(State.SIT)
		return
	_enter(State.WALK)


func _set_path(target: Vector2) -> void:
	_path = _crowd.path_between(position, target) if _crowd != null else PackedVector2Array([target])
	_path_i = 0
	_aim = target


## Moves along the path; true on arrival.
func _walk(delta: float, speed: float) -> bool:
	if _path_i >= _path.size():
		return true
	var to := _path[_path_i] - position
	var step := minf(to.length(), speed * delta)
	if to.length() > 0.5:
		_face_left = to.x < 0.0
	position += to.normalized() * step if to.length() > 0.001 else Vector2.ZERO
	_walk_clock += delta * speed / 60.0
	if to.length() <= step + 0.5:
		_path_i += 1
	return _path_i >= _path.size()


func _enter(next: State) -> void:
	state = next
	match next:
		State.SLEEP:
			_timer = _rng.randf_range(25.0, 50.0)
		State.STRETCH:
			_timer = 1.4
		State.GROOM:
			_timer = 3.0
		State.CONTENT:
			_timer = 2.2
		State.SIT:
			_timer = _rng.randf_range(8.0, 18.0)
		State.WALK:
			_walk_clock = 0.0
	_overlay_redraw()


func _beside(feet: Vector2) -> Vector2:
	for side in [Vector2(40.0, 6.0), Vector2(-40.0, 6.0), Vector2(0.0, 34.0)]:
		var p: Vector2 = feet + side
		if _crowd == null or _crowd.is_walkable(p, 8.0):
			return p
	return feet + Vector2(40.0, 6.0)


## Somewhere warm: beside a brazier or a lamp, or the Chronicler's stall.
func _warm_spot() -> Vector2:
	var options: Array = []
	for at in _hub._brazier_cells():
		options.append(_hub._cell(at.x, at.y) + (at - _hub.PLAZA_CENTER).normalized() * 50.0)
	for at in [Vector2(2.6, 10.0), Vector2(29.4, 10.0), Vector2(4.9, 12.5), Vector2(23.0, 5.2)]:
		options.append(_hub._cell(at.x, at.y) + Vector2(30.0, 10.0))
	options.shuffle()
	for p in options:
		if _crowd == null or _crowd.is_walkable(p, 8.0):
			return p
	return bed


func _player_feet() -> Vector2:
	var player: Node2D = _hub._player if _hub != null else null
	if player == null or not is_instance_valid(player):
		return Vector2.INF
	return player.global_position + Vector2(0.0, _hub.FEET)


# ---------------------------------------------------------------- drawing

func _update_sprite(delta: float) -> void:
	var key := "sit"
	var height := SIT_HEIGHT
	var frames := 1
	var bob := 0.0
	match state:
		State.SLEEP:
			key = "sleep"
			height = SLEEP_HEIGHT
		State.WALK:
			if _tex.get("walk") != null:
				key = "walk"
				frames = 6
			elif _tex.get("stand") != null:
				key = "stand"
				bob = absf(sin(_walk_clock * PI * 2.0)) * 1.5
			height = WALK_HEIGHT
		State.CONTENT:
			key = "content" if _tex.get("content") != null else "sit"
		State.GROOM:
			key = "groom" if _tex.get("groom") != null else "sit"
		State.STRETCH:
			key = "stretch" if _tex.get("stretch") != null else "sit"
			height = WALK_HEIGHT if _tex.get("stretch") != null else SIT_HEIGHT
	var texture: Texture2D = _tex.get(key)
	if texture == null:
		texture = _tex.get("sit")
		frames = 1
	if texture == null:
		return
	if _sprite.texture != texture:
		_sprite.texture = texture
		_sprite.hframes = frames
	var frame_h := float(texture.get_height())
	_sprite.scale = Vector2.ONE * (height / maxf(1.0, frame_h))
	_sprite.offset = Vector2(0.0, -frame_h * 0.5)
	_sprite.position.y = -roundf(bob)
	_sprite.flip_h = _face_left
	if frames > 1:
		_sprite.frame = int(_walk_clock * 10.0) % frames


func _overlay_redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


## Drawn on the label layer: the pet prompt, the heart, the purr, and the
## sleeping z-dots.
func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var top := -(SLEEP_HEIGHT if state == State.SLEEP else SIT_HEIGHT) - 6.0
	if state == State.SLEEP:
		var t := Time.get_ticks_msec() / 1000.0
		var rise := fmod(t, 1.8) / 1.8
		_overlay.draw_circle(Vector2(10.0, top - rise * 10.0), 1.6, Color(0.9, 0.9, 1.0, 0.7 * (1.0 - rise)))
	if _heart > 0.0:
		var k := 1.0 - _heart / 1.4
		_draw_heart(Vector2(0.0, top - 6.0 - k * 18.0), 5.0, Color(1.0, 0.55, 0.65, clampf(_heart / 0.5, 0.0, 1.0)))
	if font == null:
		return
	if _purr > 0.0:
		_overlay.draw_string_outline(font, Vector2(-40.0, top - 22.0), "prrr", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, 4, Color(0, 0, 0, 0.6 * clampf(_purr, 0.0, 1.0)))
		_overlay.draw_string(font, Vector2(-40.0, top - 22.0), "prrr", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(0.95, 0.85, 0.9, clampf(_purr, 0.0, 1.0)))
	if focused:
		_overlay.draw_string_outline(font, Vector2(-50.0, 22.0), "[E] Pet", HORIZONTAL_ALIGNMENT_CENTER, 100, 14, 4, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, Vector2(-50.0, 22.0), "[E] Pet", HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color(1.0, 0.85, 0.9, 1.0))


func _draw_heart(at: Vector2, size: float, color: Color) -> void:
	_overlay.draw_circle(at + Vector2(-size * 0.5, 0.0), size * 0.55, color)
	_overlay.draw_circle(at + Vector2(size * 0.5, 0.0), size * 0.55, color)
	_overlay.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 1.02, size * 0.2), at + Vector2(size * 1.02, size * 0.2), at + Vector2(0.0, size * 1.3)]), color)
