extends Control
## Illustrated irregular wax carrying the Chronicler's familiar cloth stamp.
const SEAL_PATH := "res://assets/ui/library/wax_seal_pixel.png"
var _seal: AtlasTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(SEAL_PATH):
		_seal = AtlasTexture.new()
		_seal.atlas = load(SEAL_PATH) as Texture2D
		_seal.region = Rect2(127, 129, 996, 987)
		_seal.filter_clip = true
		# duplicate(0) intentionally removes draw scripts from page snapshots.
		# The capture consumer can retain this original raster instead.
		set_meta("library_capture_texture", _seal)
	resized.connect(queue_redraw)

func _draw() -> void:
	if _seal == null:
		return
	var edge := minf(size.x, size.y)
	draw_texture_rect(_seal, Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge), false)
