extends Node2D

# A finite raster burst survives its source's destruction without retaining
# a gameplay owner, collision or damage responsibility.
const ART_PATH := "res://assets/textures/vfx/encounters/bomber_blast_v1.png"
const CONTENT_RADIUS := 534.266319

var duration := 0.32
var _radius := 105.0
var _t := 0.0
var _blast: Sprite2D


func setup(at: Vector2, radius: float) -> void:
	position = at
	_radius = maxf(radius, 1.0)


func _ready() -> void:
	top_level = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 2
	_blast = Sprite2D.new()
	_blast.name = "EmberBlast"
	_blast.texture = load(ART_PATH) as Texture2D if ResourceLoader.exists(ART_PATH) else null
	_blast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_blast)
	_update_sprite()


func _process(dt: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	_t += dt
	if _t >= duration:
		queue_free()
		return
	_update_sprite()


func _update_sprite() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	var radius := _radius if reduced else _radius * lerpf(0.35, 1.0, 1.0 - pow(1.0 - p, 3.0))
	_blast.scale = Vector2.ONE * radius / CONTENT_RADIUS
	_blast.modulate = Color(1.0, 1.0, 1.0, AccessibilityPresentation.current_flash_alpha((1.0 - p) * 0.85))
