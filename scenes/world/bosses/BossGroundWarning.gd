extends Node2D
## Persistent ground bounds assembled from authored raster sprites. A standalone
## warning owns its duration; a mine/beam child is driven by that attack's clock.

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const WARNING_COLOR := Color(1.0, 0.40, 0.20, 0.78)
const SEAL_TEXTURE = preload("res://scenes/world/bosses/art/vfx/hazard_seal_v1.png")
const BEAM_TEXTURE = preload("res://scenes/world/bosses/art/vfx/arcane_beam_body.tres")
# Measured alpha >= 128 extent; source pixels remain unchanged.
const SEAL_CONTENT_RADIUS := 570.1
const STYLE_ART := {
	&"slam": preload("res://scenes/world/bosses/art/vfx/slam_fracture_v1.png"),
	&"shock": preload("res://scenes/world/bosses/art/vfx/shock_crackle_v1.png"),
	&"mine": preload("res://scenes/world/bosses/art/vfx/mine_sigil_v1.png"),
}
const STYLE_RADIUS := {&"slam": 594.427876, &"shock": 542.347214, &"mine": 575.500217}

var _radius := 90.0
var _length := 680.0
var _width := 34.0
var _beam := false
var _duration := 0.0
var _elapsed := 0.0
var _color := WARNING_COLOR
var _world_origin := Vector2.ZERO
var _has_world_origin := false
var _ring: Sprite2D
var _fill: Sprite2D
var _core: Sprite2D
var _identity: Sprite2D
var _style: StringName = &"generic"
var _edges: Array[Sprite2D] = []


func setup(world_pos: Vector2, radius: float, duration: float, color: Color = WARNING_COLOR) -> void:
	_world_origin = world_pos
	_has_world_origin = true
	_duration = maxf(0.0, duration)
	_elapsed = 0.0
	_color = color
	configure_circle(radius)
	if is_inside_tree():
		global_position = world_pos


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	if _has_world_origin:
		global_position = _world_origin
	set_progress(0.0)


func set_attack_style(kind: StringName) -> void:
	_style = kind if STYLE_ART.has(kind) else &"generic"
	if not _beam:
		configure_circle(_radius)


func configure_circle(radius: float) -> void:
	_beam = false
	_radius = maxf(0.0, radius)
	_ensure_sprites()
	# Fine engraving needs room to read; tiny charge crumbs keep a simple ring.
	var detailed := _radius >= 60.0
	var large := _radius > VfxKit.RING_LARGE_FROM
	_ring.texture = SEAL_TEXTURE if detailed else VfxKit.texture("ring_large" if large else "ring")
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if detailed else CanvasItem.TEXTURE_FILTER_NEAREST
	_ring.scale = Vector2.ONE * _radius / (SEAL_CONTENT_RADIUS if detailed else (VfxKit.RING_LARGE_HALF if large else VfxKit.RING_HALF))
	_ring.visible = true
	_core.visible = false
	_identity.visible = STYLE_ART.has(_style)
	if _identity.visible:
		_identity.texture = STYLE_ART[_style]
		_identity.scale = Vector2.ONE * _radius / float(STYLE_RADIUS[_style])
	_fill.texture = VfxKit.texture("disc")
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill.position = Vector2.ZERO
	_fill.scale = Vector2.ONE * _radius / VfxKit.DISC_HALF
	for edge in _edges:
		edge.visible = false
	set_progress(0.0)


func configure_beam(length: float, width: float) -> void:
	_beam = true
	_length = maxf(0.0, length)
	_width = maxf(0.0, width)
	_ensure_sprites()
	_ring.visible = false
	_identity.visible = false
	_fill.texture = BEAM_TEXTURE
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fit_segment(_fill, Vector2.ZERO, Vector2(_length, 0.0), _width, BEAM_TEXTURE.get_height())
	_core.texture = BEAM_TEXTURE
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fit_segment(_core, Vector2.ZERO, Vector2(_length, 0.0), _width * 0.40, BEAM_TEXTURE.get_height())
	var half := _width * 0.5
	var corners := [Vector2(0.0, -half), Vector2(_length, -half), Vector2(_length, half), Vector2(0.0, half)]
	for i in range(4):
		_edges[i].visible = true
		_fit_segment(_edges[i], corners[i], corners[(i + 1) % 4], 3.0)
	set_progress(0.0)


func set_progress(value: float, active: bool = false) -> void:
	if _fill == null:
		return
	var progress := clampf(value, 0.0, 1.0)
	var edge_color := _color
	if _style == &"shock" and not _beam:
		edge_color = Color(1.0, 0.82, 0.38)
	elif _style == &"mine" and not _beam:
		edge_color = Color(0.78, 0.43, 1.0)
	# Essential danger bounds stay visible when decorative flashes are disabled.
	edge_color.a = lerpf(0.65, 0.95, progress)
	if active and _beam:
		edge_color = Color(0.82, 0.62, 1.0, 0.95)
	_ring.modulate = edge_color
	for edge in _edges:
		edge.modulate = edge_color
	var fill_color := Color(0.78, 0.22, 1.0, 0.70) if active and _beam else _color
	fill_color.a = AccessibilityPresentation.current_flash_alpha((0.85 if active else lerpf(0.30, 0.50, progress)) if _beam else (0.18 if active else lerpf(0.08, 0.16, progress)))
	_fill.modulate = fill_color
	var identity_alpha := (0.82 if active else lerpf(0.32, 0.70, progress))
	_identity.modulate = Color(1, 1, 1, maxf(0.32, AccessibilityPresentation.current_flash_alpha(identity_alpha)))
	_core.visible = _beam and active
	_core.modulate = Color(0.96, 0.85, 1.0, AccessibilityPresentation.current_flash_alpha(0.85))


func _process(delta: float) -> void:
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	if get_tree().paused or _duration <= 0.0:
		return
	_elapsed += delta
	set_progress(_elapsed / _duration)
	if _elapsed >= _duration:
		queue_free()


func cancel_attack() -> void:
	visible = false
	queue_free()


func _ensure_sprites() -> void:
	if _fill != null:
		return
	_fill = _sprite("Fill", "disc")
	_identity = _sprite("AttackIdentity", "disc")
	_identity.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_identity.visible = false
	_ring = _sprite("Boundary", "ring_large")
	_core = _sprite("Core", "streak")
	_core.visible = false
	for i in range(4):
		_edges.append(_sprite("Edge%d" % i, "streak"))


func _sprite(label: String, texture_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = VfxKit.texture(texture_name)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite


func _fit_segment(sprite: Sprite2D, from: Vector2, to: Vector2, width: float, content_height: float = VfxKit.STREAK_CONTENT_H) -> void:
	var direction := to - from
	sprite.position = (from + to) * 0.5
	sprite.rotation = direction.angle()
	if sprite.texture != null:
		sprite.scale = Vector2(direction.length() / float(sprite.texture.get_width()), width / content_height)
