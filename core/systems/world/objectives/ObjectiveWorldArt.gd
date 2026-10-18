extends Sprite2D
## Visual only: one stable world form per site, sharing its real site's origin.
## State writes are latched; no independent animation, gameplay clock or tween.
const STATE_SHADER := preload("res://core/systems/world/objectives/objective_world_art.gdshader")
const ART_DIRECTORY := "res://assets/world/objectives/painted/"
const TEXTURES := {
	"wardstone": preload("res://assets/world/objectives/painted/wardstone_v1.png"),
	"exit_rite": preload("res://assets/world/objectives/painted/exit_rite_v1.png"),
	"relay": preload("res://assets/world/objectives/painted/relay_v1.png"),
	"vigil": preload("res://assets/world/objectives/painted/vigil_v1.png"),
	"breach": preload("res://assets/world/objectives/painted/breach_v1.png"),
	"wager": preload("res://assets/world/objectives/painted/wager_v1.png"),
}
var _state_material: ShaderMaterial
var _state := ""
var _progress_bucket := -1

static func install(parent: Node, art_name: String, height: float, at: Vector2 = Vector2.ZERO, node_name: String = "ObjectiveArt") -> Sprite2D:
	var sprite: Sprite2D = (load("res://core/systems/world/objectives/ObjectiveWorldArt.gd") as Script).new()
	sprite.name = node_name
	parent.add_child(sprite)
	sprite.call("configure", art_name, height)
	sprite.position = at
	return sprite

func configure(art_name: String, height: float) -> void:
	texture = TEXTURES.get(art_name)
	if texture == null:
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var size := texture.get_size()
	scale = Vector2.ONE * height / maxf(1.0, size.y)
	# The contact foot stays close to the site origin. The visual never moves it.
	offset = Vector2(0.0, -size.y * 0.35)
	z_index = 4
	_state_material = ShaderMaterial.new()
	_state_material.shader = STATE_SHADER
	material = _state_material
	set_state("dormant")

func set_state(state: String, progress: float = 0.0) -> void:
	var bucket := int(clampf(progress, 0.0, 1.0) * 32.0)
	if _state == state and bucket == _progress_bucket:
		return
	_state = state
	_progress_bucket = bucket
	if _state_material == null:
		return
	_state_material.set_shader_parameter("energy", 0.25 if state == "dormant" else (0.7 + 0.3 * float(bucket) / 32.0))
	_state_material.set_shader_parameter("completed", state == "complete")
	_state_material.set_shader_parameter("draining", state == "draining")
	_state_material.set_shader_parameter("spent", state == "spent")
	_state_material.set_shader_parameter("working", state == "working")

static func reduced_motion() -> bool:
	return SettingsManager != null and bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))

static func pulse(clock: float, speed: float = 2.4) -> float:
	return 0.5 if reduced_motion() else 0.5 + 0.5 * sin(clock * speed)

static func draw_boundary(item: CanvasItem, at: Vector2, radius: float, color: Color, progress: float = -1.0) -> void:
	# Dark under-stroke keeps the exact interaction edge legible on pale stone.
	item.draw_arc(at, radius, 0.0, TAU, 80, Color(0.035, 0.03, 0.035, 0.8), 6.0, true)
	item.draw_arc(at, radius, 0.0, TAU, 80, Color(color.r, color.g, color.b, 0.64), 2.0, true)
	for index in range(8):
		var direction := Vector2.from_angle(TAU * float(index) / 8.0)
		item.draw_line(at + direction * (radius - 5.0), at + direction * (radius + 5.0), color, 2.0, true)
	if progress > 0.0:
		item.draw_arc(at, radius + 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 80, Color(0.04, 0.03, 0.02, 0.85), 9.0, true)
		item.draw_arc(at, radius + 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 80, Color(0.98, 0.89, 0.59, 0.96), 5.0, true)

static func draw_complete(item: CanvasItem, at: Vector2, size: float = 15.0) -> void:
	var points := PackedVector2Array([at + Vector2(-size * 0.65, 0.0), at + Vector2(-size * 0.12, size * 0.5), at + Vector2(size * 0.8, -size * 0.65)])
	item.draw_polyline(points, Color(0.025, 0.04, 0.04, 0.95), 7.0, true)
	item.draw_polyline(points, Color(0.68, 1.0, 0.88, 1.0), 3.0, true)
