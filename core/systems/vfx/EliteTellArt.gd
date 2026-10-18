class_name EliteTellArt
extends RefCounted

## Dedicated neutral painted tells, tinted by EliteModifiers. Bounds are the
## measured alpha > 32 content on the 1254px sources. Normalized source regions
## preserve their world size when Godot imports the art at smaller resolutions.
const DIR := "res://assets/textures/vfx/elites/"
const CONTENT := {
	&"armoured": Rect2(62.0 / 1254.0, 14.0 / 1254.0, 1131.0 / 1254.0, 1225.0 / 1254.0),
	&"vampiric": Rect2(58.0 / 1254.0, 9.0 / 1254.0, 1144.0 / 1254.0, 1199.0 / 1254.0),
	&"shielded": Rect2(86.0 / 1254.0, 19.0 / 1254.0, 1082.0 / 1254.0, 1213.0 / 1254.0),
	&"splitting": Rect2(59.0 / 1254.0, 435.0 / 1254.0, 1137.0 / 1254.0, 406.0 / 1254.0),
	&"fast": Rect2(75.0 / 1254.0, 473.0 / 1254.0, 1108.0 / 1254.0, 313.0 / 1254.0),
}

static var _cache: Dictionary = {}


## Application shutdown (Global._exit_tree), like the other RID-backed statics.
static func release_static_caches() -> void:
	_cache.clear()


static func texture(id: StringName) -> Texture2D:
	if not CONTENT.has(id):
		return null
	if _cache.has(id):
		return _cache[id] as Texture2D
	var path := DIR + String(id) + ".png"
	if not ResourceLoader.exists(path):
		return null
	var art := load(path) as Texture2D
	# Do not retain a failed load: later imports can make the art available.
	if art != null:
		_cache[id] = art
	return art


## Fit a collar or ward to its outer radius without changing its aspect.
## False lets the caller retain its existing generic fallback.
static func draw_radial(canvas: CanvasItem, id: StringName, radius: float, color: Color) -> bool:
	var art := texture(id)
	if art == null:
		return false
	var source := _source_rect(id, art)
	var size := source.size * (radius * 2.0 / maxf(source.size.x, source.size.y))
	canvas.draw_texture_rect_region(art, Rect2(-size * 0.5, size), source, color)
	return true


## Place a seam or wind ribbon at body scale or aligned to its velocity.
static func draw_strip(canvas: CanvasItem, id: StringName, at: Vector2, size: Vector2, color: Color, spin: float = 0.0) -> bool:
	var art := texture(id)
	if art == null:
		return false
	canvas.draw_set_transform(at, spin)
	canvas.draw_texture_rect_region(art, Rect2(-size * 0.5, size), _source_rect(id, art), color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0)
	return true


static func _source_rect(id: StringName, art: Texture2D) -> Rect2:
	var bounds: Rect2 = CONTENT[id]
	return Rect2(bounds.position * art.get_size(), bounds.size * art.get_size())
