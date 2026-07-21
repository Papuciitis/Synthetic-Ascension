extends Node2D
class_name PickupVfx

@export var show_lock_indicator: bool = true
@export var lock_ring_px: int = 36
@export var lock_ring_thickness: int = 2
@export var lock_ring_rotation_speed: float = 3.0
@export var lock_dim_alpha: float = 0.55

@export_group("Exploration Marker (loot caches)")
@export var show_exploration_indicator: bool = true
@export var exploration_ring_px: int = 46
@export var exploration_ring_thickness: int = 3
@export var exploration_ring_rotation_speed: float = -2.0
@export var exploration_alpha: float = 0.75

var icon: Sprite2D = null
var _lock_ring: Sprite2D = null
var _explore_ring: Sprite2D = null

var _locked: bool = false
var _exploration: bool = false
var _t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_modulate: Color = Color(1,1,1,1)

func bind_icon(s: Sprite2D) -> void:
	icon = s
	if icon == null:
		return
	_base_scale = icon.scale
	_base_modulate = icon.modulate
	if show_lock_indicator:
		_ensure_lock_ring()
	_apply_lock_visuals()
	_apply_exploration_visuals()

func set_locked(v: bool) -> void:
	_locked = v
	_apply_lock_visuals()
	_refresh_process()

func set_exploration(v: bool) -> void:
	_exploration = v
	if _exploration and show_exploration_indicator:
		_ensure_explore_ring()
	_apply_exploration_visuals()
	_refresh_process()

func _refresh_process() -> void:
	var want := (_locked and _lock_ring != null and show_lock_indicator) or (_exploration and _explore_ring != null and show_exploration_indicator)
	set_process(want)

func play_throw(start_pos: Vector2, end_pos: Vector2, throw_time: float, arc_height: float, land_scale: float, land_time: float) -> void:
	if icon == null:
		# fallback: just snap the parent pickup
		get_parent().global_position = end_pos
		return

	var pickup := get_parent() as Node2D
	if pickup == null:
		return

	pickup.global_position = start_pos

	if throw_time <= 0.0:
		pickup.global_position = end_pos
		_play_land_bounce(land_scale, land_time)
		return

	var tw := get_tree().create_tween()
	tw.tween_property(pickup, "global_position", end_pos, throw_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# arc using icon offset
	var icon0 := icon.position
	var mid := (start_pos + end_pos) * 0.5
	var peak := mid + Vector2(0, -absf(arc_height))
	var tw2 := get_tree().create_tween()
	tw2.tween_method(func(t: float) -> void:
		# quadratic bezier between start->peak->end
		var a := start_pos.lerp(peak, t)
		var b := peak.lerp(end_pos, t)
		var p := a.lerp(b, t)
		icon.position = icon0 + (p - pickup.global_position)
	, 0.0, 1.0, throw_time)

	tw.finished.connect(func() -> void:
		icon.position = icon0
		_play_land_bounce(land_scale, land_time)
	)

func _play_land_bounce(land_scale: float, land_time: float) -> void:
	if icon == null:
		return
	var tw := get_tree().create_tween()
	var s0 := icon.scale
	tw.tween_property(icon, "scale", s0 * land_scale, maxf(0.01, land_time * 0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", s0, maxf(0.01, land_time * 0.55)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta

	if _locked and _lock_ring != null and show_lock_indicator:
		_lock_ring.rotation += lock_ring_rotation_speed * delta
		var a := 0.30 + 0.25 * (0.5 + 0.5 * sin(_t * 6.0))
		var c := _lock_ring.modulate
		c.a = a
		_lock_ring.modulate = c

	if _exploration and _explore_ring != null and show_exploration_indicator:
		_explore_ring.rotation += exploration_ring_rotation_speed * delta
		var a2 := exploration_alpha * (0.70 + 0.30 * (0.5 + 0.5 * sin(_t * 3.5)))
		var c2 := _explore_ring.modulate
		c2.a = a2
		_explore_ring.modulate = c2

func _apply_lock_visuals() -> void:
	if icon != null:
		var c := _base_modulate
		c.a *= (lock_dim_alpha if _locked else 1.0)
		icon.modulate = c
	if _lock_ring != null:
		_lock_ring.visible = (_locked and show_lock_indicator)

func _apply_exploration_visuals() -> void:
	if _explore_ring != null:
		_explore_ring.visible = (_exploration and show_exploration_indicator)

func _ensure_lock_ring() -> void:
	if _lock_ring != null:
		return
	_lock_ring = Sprite2D.new()
	_lock_ring.name = "LockRing"
	_lock_ring.centered = true
	_lock_ring.texture = _make_ring_texture(lock_ring_px, lock_ring_thickness)
	_lock_ring.modulate = Color(1.0, 0.55, 0.20, 0.45)
	add_child(_lock_ring)

func _ensure_explore_ring() -> void:
	if _explore_ring != null:
		return
	_explore_ring = Sprite2D.new()
	_explore_ring.name = "ExploreRing"
	_explore_ring.centered = true
	_explore_ring.texture = _make_ring_texture(exploration_ring_px, exploration_ring_thickness)
	# Cyan-ish to stand out from orange lock ring and enemy drops.
	_explore_ring.modulate = Color(0.25, 0.95, 1.0, exploration_alpha)
	_explore_ring.z_index = -1
	add_child(_explore_ring)

func _make_ring_texture(size_px: int, thickness_px: int) -> Texture2D:
	var s := maxi(8, size_px)
	var t := maxi(1, thickness_px)

	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center := Vector2(s * 0.5, s * 0.5)
	var r := (s * 0.5) - 1.0

	for y in range(s):
		for x in range(s):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := p.distance_to(center)
			if d <= r and d >= (r - float(t)):
				img.set_pixel(x, y, Color(1, 1, 1, 1))

	return ImageTexture.create_from_image(img)
