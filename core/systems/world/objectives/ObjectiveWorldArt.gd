extends Sprite2D
## Visual only: one stable world form per site, sharing its real site's origin.
## State writes are latched; no independent animation, gameplay clock or tween.
const STATE_SHADER := preload("res://core/systems/world/objectives/objective_world_art.gdshader")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const ART_DIRECTORY := "res://assets/world/objectives/painted/"
const TEXTURES := {
	"wardstone": preload("res://assets/world/objectives/painted/wardstone_v2.png"),
	"exit_rite": preload("res://assets/world/objectives/painted/exit_rite_v2.png"),
	"relay": preload("res://assets/world/objectives/painted/relay_v2.png"),
	"vigil": preload("res://assets/world/objectives/painted/vigil_v2.png"),
	"breach": preload("res://assets/world/objectives/painted/breach_open_v2.png"),
	"wager": preload("res://assets/world/objectives/painted/wager_v2.png"),
	"vault": preload("res://assets/world/objectives/painted/vault_closed_v2.png"),
}
const STATE_TEXTURES := {
	"breach": {"complete": preload("res://assets/world/objectives/painted/breach_sealed_v2.png")},
	"vault": {"spent": preload("res://assets/world/objectives/painted/vault_open_v2.png")},
}
## Source-normalized anchors are deliberate contact/footprint points, not
## alpha-bound centers. Extents only normalize occupied size across canvases.
const PLACEMENT := {
	"wardstone": {"anchor": Vector2(0.5, 0.899740), "extent": Vector2(0.669922, 0.822917)},
	"exit_rite": {"anchor": Vector2(0.5, 0.488281), "extent": Vector2(0.820964, 0.642578), "width": 1.0, "ground": true},
	"relay": {"anchor": Vector2(0.5, 0.746094), "extent": Vector2(0.593099, 0.615234), "features": {"lens": Vector2(0.5, 0.462)}},
	"vigil": {"anchor": Vector2(0.5, 0.5), "extent": Vector2(0.654948, 0.792969), "width": 1.45, "ground": true},
	"breach": {"anchor": Vector2(0.5, 0.5), "extent": Vector2(0.975, 0.736), "width": 1.65, "ground": true},
	"wager": {"anchor": Vector2(0.5, 0.891266), "extent": Vector2(0.875892, 0.844920), "features": {"tray": Vector2(0.5, 0.825)}},
	"vault": {"anchor": Vector2(0.517, 0.53), "extent": Vector2(0.821615, 0.948242), "width": 1.3, "ground": true},
}
var _state_material: ShaderMaterial
var _state := ""
var _progress_bucket := -1
var _art_name := ""
var _nominal_height := 0.0
var _ground := false
var _depth_elapsed := 0.0
var _viewer: Node2D
var _shadow: Node2D
var _cast: Sprite2D

class ContactShadow extends Node2D:
	var extent := Vector2(20.0, 7.0)
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, extent)
		draw_circle(Vector2.ZERO, 1.0, Color(0.07, 0.065, 0.055, 0.22))

static func install(parent: Node, art_name: String, height: float, at: Vector2 = Vector2.ZERO, node_name: String = "ObjectiveArt") -> Sprite2D:
	var sprite: Sprite2D = (load("res://core/systems/world/objectives/ObjectiveWorldArt.gd") as Script).new()
	sprite.name = node_name
	parent.add_child(sprite)
	sprite.call("configure", art_name, height)
	sprite.position = at
	return sprite

func configure(art_name: String, height: float) -> void:
	_art_name = art_name
	_nominal_height = height
	texture = TEXTURES.get(art_name)
	if texture == null:
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ground = bool(PLACEMENT.get(art_name, {}).get("ground", false))
	z_as_relative = false
	z_index = -11 if _ground else -2
	_apply_placement()
	set_process(not _ground)
	_state_material = ShaderMaterial.new()
	_state_material.shader = STATE_SHADER
	material = _state_material
	_state = ""
	_progress_bucket = -1
	set_state("dormant")
	if not _ground and _shadow == null:
		_shadow = ContactShadow.new()
		_shadow.name = "ContactShadow"
		_shadow.z_as_relative = false
		_shadow.z_index = -12
		add_child(_shadow)
		_shadow.scale = Vector2.ONE / scale
		var occupied_width := texture.get_width() * scale.x * float((PLACEMENT.get(art_name, {}).get("extent", Vector2.ONE) as Vector2).x)
		_shadow.set("extent", Vector2(occupied_width * 0.32, height * 0.055))
		_shadow.queue_redraw()
	if not _ground and _cast == null:
		# An upright form also casts its silhouette southwest from its contact
		# point, as actors do (one sun: WorldDepthStyle), not only a centred pool.
		_cast = Sprite2D.new()
		_cast.name = "CastShadow"
		_cast.z_as_relative = false
		_cast.z_index = DEPTH.SHADOW_Z
		_cast.transform = DEPTH.projection_at(Vector2.ZERO)
		_cast.texture_filter = texture_filter
		var cast_material := ShaderMaterial.new()
		cast_material.shader = DEPTH.SHADOW_SHADER
		cast_material.set_shader_parameter("shadow_color", DEPTH.SHADOW_COLOR)
		_cast.material = cast_material
		add_child(_cast)
		_apply_placement()

func _apply_placement() -> void:
	if texture == null:
		return
	var data: Dictionary = PLACEMENT.get(_art_name, {})
	var size := texture.get_size()
	var anchor: Vector2 = data.get("anchor", Vector2(0.5, 0.5))
	var extent: Vector2 = data.get("extent", Vector2.ONE)
	var width_factor := float(data.get("width", 0.0))
	var occupied := size.x * extent.x if width_factor > 0.0 else size.y * extent.y
	scale = Vector2.ONE * _nominal_height * (width_factor if width_factor > 0.0 else 1.0) / maxf(1.0, occupied)
	offset = size * (Vector2(0.5, 0.5) - anchor)
	if is_instance_valid(_shadow):
		_shadow.scale = Vector2.ONE / scale
	if is_instance_valid(_cast):
		# Same texture and anchor; the projection pivots on the contact point.
		_cast.texture = texture
		_cast.offset = offset

func feature_offset(feature: String) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var data: Dictionary = PLACEMENT.get(_art_name, {})
	var anchor: Vector2 = data.get("anchor", Vector2(0.5, 0.5))
	var features: Dictionary = data.get("features", {})
	var point: Vector2 = features.get(feature, anchor)
	return (point - anchor) * texture.get_size() * scale

func _process(delta: float) -> void:
	# Visual depth only; no actor or objective state is modified. Ground forms
	# never run this and always stay below feet, shadows and combat warnings.
	_depth_elapsed += delta
	if _depth_elapsed < 0.05:
		return
	_depth_elapsed = 0.0
	if not is_instance_valid(_viewer):
		_viewer = get_tree().get_first_node_in_group(&"player") as Node2D
	if is_instance_valid(_viewer):
		z_index = 1 if _viewer.global_position.y < global_position.y - 8.0 else -2

func set_state(state: String, progress: float = 0.0) -> void:
	var bucket := int(clampf(progress, 0.0, 1.0) * 32.0)
	if _state == state and bucket == _progress_bucket:
		return
	_state = state
	_progress_bucket = bucket
	var variants: Dictionary = STATE_TEXTURES.get(_art_name, {})
	var next_texture: Texture2D = variants.get(state, TEXTURES.get(_art_name))
	if next_texture != texture:
		texture = next_texture
		_apply_placement()
	if _state_material == null:
		return
	_state_material.set_shader_parameter("energy", 0.35 if state in ["dormant", "locked"] else (0.75 + 0.25 * float(bucket) / 32.0))
	_state_material.set_shader_parameter("completed", state == "complete")
	_state_material.set_shader_parameter("draining", state == "draining")
	_state_material.set_shader_parameter("spent", state == "spent")
	_state_material.set_shader_parameter("working", state == "working")

static func reduced_motion() -> bool:
	return SettingsManager != null and bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))

static func pulse(clock: float, speed: float = 2.4) -> float:
	return 0.5 if reduced_motion() else 0.5 + 0.5 * sin(clock * speed)

static func draw_boundary(item: CanvasItem, at: Vector2, radius: float, color: Color, progress: float = -1.0) -> void:
	# Keep the exact boundary, with quiet support rather than a heavy diagram.
	item.draw_arc(at, radius, 0.0, TAU, 80, Color(0.035, 0.03, 0.035, 0.38), 3.0, true)
	item.draw_arc(at, radius, 0.0, TAU, 80, Color(color.r, color.g, color.b, color.a * 0.48), 1.1, true)
	for index in range(4):
		var direction := Vector2.from_angle(TAU * float(index) / 4.0)
		item.draw_line(at + direction * (radius - 3.0), at + direction * (radius + 3.0), Color(color.r, color.g, color.b, 0.65), 1.5, true)
	if progress > 0.0:
		item.draw_arc(at, radius - 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 80, Color(0.04, 0.03, 0.02, 0.65), 4.0, true)
		item.draw_arc(at, radius - 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 80, Color(0.84, 0.76, 0.5, 0.85), 2.0, true)

static func draw_complete(item: CanvasItem, at: Vector2, size: float = 15.0) -> void:
	var points := PackedVector2Array([at + Vector2(-size * 0.65, 0.0), at + Vector2(-size * 0.12, size * 0.5), at + Vector2(size * 0.8, -size * 0.65)])
	item.draw_polyline(points, Color(0.025, 0.04, 0.04, 0.95), 7.0, true)
	item.draw_polyline(points, Color(0.68, 1.0, 0.88, 1.0), 3.0, true)
