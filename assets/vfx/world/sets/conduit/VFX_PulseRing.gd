extends Node2D
class_name PulseRing

@export var duration: float = 0.26
@export var line_width: float = 8.0
@export var fill_alpha: float = 0.09
@export var line_alpha: float = 0.65

@export var start_radius_mul: float = 0.18
@export var trailing_ring_mul: float = 0.86
@export var trailing_alpha_mul: float = 0.35

@export var dash_count: int = 10
@export var dash_gap: float = 0.22 # radians-ish gap amount
@export var z: int = 200

var _radius: float = 64.0
var _t: float = 0.0
var _ripple: Sprite2D
var _echo: Sprite2D

const RIPPLE_PATH := "res://assets/textures/vfx/encounters/pulse_ripple_v1.png"
# Calibrated to the source PNG's alpha coverage, not its square canvas.
const RIPPLE_CONTENT_RADIUS := 562.741948

func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	_radius = maxf(radius, 1.0)
	_update_sprites()

func _ready() -> void:
	z_index = z
	process_mode = Node.PROCESS_MODE_PAUSABLE
	material = null
	_ensure_sprites()
	_reset()

## Pooled reuse (PooledVfx): back to the first frame of the burst.
func _on_pool_obtain() -> void:
	_reset()

func _reset() -> void:
	_t = 0.0
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	set_process(true)
	_update_sprites()

func _process(dt: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	_t += dt
	if _t >= duration:
		PooledVfx.release(self)
		return
	_update_sprites()

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _ensure_sprites() -> void:
	if _ripple != null:
		return
	var texture := load(RIPPLE_PATH) as Texture2D if ResourceLoader.exists(RIPPLE_PATH) else null
	_echo = Sprite2D.new()
	_echo.name = "RippleEcho"
	_echo.texture = texture
	_echo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_echo)
	_ripple = Sprite2D.new()
	_ripple.name = "Ripple"
	_ripple.texture = texture
	_ripple.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ripple)


func _update_sprites() -> void:
	if _ripple == null:
		return
	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade := (1.0 - p) * (1.0 - p)
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	var radius := _radius if reduced else lerpf(_radius * start_radius_mul, _radius, _ease_out(p))
	_ripple.scale = Vector2.ONE * radius / RIPPLE_CONTENT_RADIUS
	_ripple.modulate = Color(1.0, 1.0, 1.0, AccessibilityPresentation.current_flash_alpha(line_alpha * fade))
	_echo.scale = _ripple.scale * trailing_ring_mul
	_echo.modulate = Color(0.70, 0.90, 1.0, AccessibilityPresentation.current_flash_alpha(line_alpha * trailing_alpha_mul * fade))
