extends Node2D
class_name WorldAtmosphere

## Theme presentation only. Daylight samples world coordinates; low air sits
## below actors and excludes actual indoor volumes, including open cutaways.
## Neither pass owns visibility, collision, theme selection or gameplay time.

const PROFILES := preload("res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd")
const SHADER := preload("res://core/systems/world/atmosphere/world_atmosphere.gdshader")
const MIST_SHADER := preload("res://core/systems/world/atmosphere/ground_air.gdshader")
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const WEATHERING := preload("res://scenes/world/buildings/weathering/CityWeathering.gd")
const Z := 1400
const AIR_Z := -8
const ROOM_POLL_SECONDS := 0.5
const MASK_CELLS := 126.0
# Headless RenderingServer uses dummy values. These mirror the source shader
# contract only for that fallback; native reads the actual defaults.
const GROUND_DEFAULTS := {"cell_px":64.0,"map_size":256.0,"warp_cells":0.62,
	"grain":0.3,"overgrowth_bias":0.08,"overgrowth_a":Vector4.ZERO,
	"overgrowth_b":Vector4.ZERO,"stain_strength":0.8,"stain_layer":5.0,
	"policy_enabled":false,"hard_a":Vector4.ZERO,"hard_b":Vector4.ZERO,
	"paved_stain_strength":1.0}
## Mirrored onto the air as receiver_<name>: the warp/winner inputs and the
## district ground policy's paved classification (DistrictGroundPolicy).
const GROUND_PARAMETERS: Array[String] = ["cover_a","cover_b","light_map","noise_tex",
	"cell_px","map_size","warp_cells","grain","overgrowth_bias",
	"overgrowth_a","overgrowth_b","stain_strength","policy_enabled",
	"hard_a","hard_b","paved_stain_strength"]

signal profile_changed(profile: Dictionary)

# A local clock also permits reproducible native stills without changing
# Engine.time_scale or using shader TIME. Reduced Motion holds its phase.
var weather_time := 0.0
var weather_frozen := false

var _rect: ColorRect
var _mist: ColorRect
var _material: ShaderMaterial
var _mist_material: ShaderMaterial
var _profile: Dictionary = {}
var _reduced_motion := false
var _frozen_phase := 0.0
var _rooms: Array[Rect2] = []
var _rooms_dirty := true
var _room_poll := 0.0
var _room_revision := 0
var _mask_revision := -1
var _mask_origin := Vector2.INF
var _mask_size := Vector2i.ZERO
var _mask_cell := 0.0
var _mask_rebuilds := 0
var _mask_image: Image
var _mask: ImageTexture
var _environment_dirty := true
var _environment_poll := 0.0
var _ground: WeakRef
var _ground_signature: Array = []
var _environment_scans := 0
var _shader_defaults: Dictionary = {}


func _init() -> void:
	name = "WorldAtmosphere"
	z_index = Z
	z_as_relative = false
	# The binder waits for the final selected district family. An unconfigured
	# default must not flash another theme's weather during startup.
	visible = false
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Daylight"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = MIST_SHADER
	_mist = ColorRect.new()
	_mist.name = "GroundAir"
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.z_as_relative = false
	_mist.z_index = AIR_Z
	_mist.material = _mist_material
	_mist.visible = false
	add_child(_mist)


func _ready() -> void:
	# Streamed rooms invalidate the receiver before the next rendered frame.
	# The slower poll catches in-place shape/transform edits without rebuilding
	# the world mask on every frame or connecting to every shape resource.
	get_tree().node_added.connect(_on_room_node_changed)
	get_tree().node_removed.connect(_on_room_node_changed)


func _exit_tree() -> void:
	_restore_environment()


func apply_theme(theme_id: StringName, context: StringName = &"procedural", reduced_motion: bool = false) -> void:
	_profile = PROFILES.resolve(theme_id, context)
	_reduced_motion = reduced_motion
	_frozen_phase = weather_time
	visible = bool(_profile.enabled)
	for key: String in ["environment_tint", "ambient_fill", "direct_light", "cloud_opacity", "cloud_scale_px", "cloud_velocity"]:
		_material.set_shader_parameter(key, _profile[key])
	for key: String in ["mist_opacity", "mist_tint", "wind"]:
		_mist_material.set_shader_parameter(key, _profile[key])
	for material: ShaderMaterial in [_material, _mist_material]:
		material.set_shader_parameter("weather_motion_enabled", not reduced_motion)
		material.set_shader_parameter("frozen_weather_time", _frozen_phase)
	_mist.visible = visible and float(_profile.mist_opacity) > 0.0
	# The district's wall-foot damp and roof lichen (shader globals); authored
	# S1/Hub contexts stay clean.
	WEATHERING.apply_theme(theme_id if bool(_profile.enabled) else &"")
	_rooms_dirty = true
	_mask_revision = -1
	refresh_environment(true)
	profile_changed.emit(_profile.duplicate(true))


func get_shader_material() -> ShaderMaterial:
	return _material


func get_mist_material() -> ShaderMaterial:
	return _mist_material


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func diagnostics() -> Dictionary:
	return {"profile":get_profile(), "weather_time":weather_time, "frozen_phase":_frozen_phase,
		"reduced_motion":_reduced_motion, "weather_frozen":weather_frozen,
		"air_z":AIR_Z, "room_count":_rooms.size(), "mask_rebuilds":_mask_rebuilds,
		"mask_size":_mask_size, "mask_cell_px":_mask_cell, "mask_origin":_mask_origin,
		"particle_count":0, "vignette_strength":0.0,
		"environment_scans":_environment_scans, "roof_material_count":_count_roof_materials(),
		"sun_shadow_count":_count_sun_shadows(), "ground_receiver_enabled":not _ground_signature.is_empty()}


func _process(delta: float) -> void:
	_environment_poll -= maxf(0.0,delta)
	refresh_environment()
	if not visible:
		return
	if not _reduced_motion and not weather_frozen:
		weather_time += maxf(0.0, delta)
	_material.set_shader_parameter("weather_time", weather_time)
	_mist_material.set_shader_parameter("weather_time", weather_time)
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_2d()
	var size := viewport.get_visible_rect().size
	var centre := Vector2.ZERO
	var zoom := Vector2.ONE
	if camera != null:
		centre = camera.get_screen_center_position()
		zoom = camera.zoom
	var world_size := size / Vector2(maxf(zoom.x, 0.001), maxf(zoom.y, 0.001))
	# A small margin so camera shake never shows an ungraded edge.
	var margin := world_size * 0.05
	global_position = centre - world_size * 0.5 - margin
	_rect.size = world_size + margin * 2.0
	_mist.size = _rect.size
	if not _mist.visible:
		return
	_room_poll -= delta
	if _rooms_dirty or _room_poll <= 0.0:
		_refresh_rooms()
		_room_poll = ROOM_POLL_SECONDS
	_update_receiver(Rect2(global_position, _rect.size))


func _on_room_node_changed(node: Node) -> void:
	if node is IndoorVolume or (node is CollisionShape2D and node.get_parent() is IndoorVolume):
		_rooms_dirty = true
	# Roofs and casts take theme light from shared uniforms; only the ground
	# host binding needs rediscovery when streaming changes it.
	if node is GroundSplatRenderer or (node is Sprite2D and node.get_parent() is GroundSplatRenderer):
		_environment_dirty = true


func refresh_environment(force: bool = false) -> void:
	if not is_inside_tree():
		return
	if _profile.is_empty() or not bool(_profile.get("enabled",false)):
		_restore_environment()
		return
	if force or _environment_dirty or _environment_poll <= 0.0:
		_environment_dirty = false
		_environment_poll = ROOM_POLL_SECONDS
		_discover_environment()
		_apply_direct_light(_profile)
	# Ground maps can be repainted in place while the node survives. Sampling
	# its eight-slot signature is constant work and cannot hold stale wet slots
	# for the slower discovery interval after a stream/reset.
	_bind_ground_receiver()


func _same_canvas(item: CanvasItem) -> bool:
	return item.is_inside_tree() and not item.is_queued_for_deletion() and item.get_world_2d() == get_world_2d() and item.get_canvas() == get_canvas()


func _discover_environment() -> void:
	# Theme light never rewrites roof planes or individual shadow alpha:
	# roofs keep their full plane hierarchy in every theme, and every sun
	# cast shares one material whose shade the theme sets. Only the ground
	# host is bound here; roofs and casts are counted on request.
	_environment_scans += 1
	var ground := get_parent().get_node_or_null("GroundSplat") as GroundSplatRenderer
	_ground = weakref(ground) if ground != null and _same_canvas(ground) else null


## Diagnostics only: roof plane materials on this canvas.
func _count_roof_materials() -> int:
	if not is_inside_tree():
		return 0
	var materials: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"roof_occluders"):
		var roof := node as RoofOverlay
		if roof == null or not _same_canvas(roof):
			continue
		for child: Node in roof.find_children("*","Polygon2D",true,false):
			var material := (child as Polygon2D).material as ShaderMaterial
			if material != null and material.shader == ROOF_SHADER:
				materials[material.get_instance_id()] = true
	return materials.size()


## Diagnostics only: building and kit-foliage sun casts beside those roofs.
func _count_sun_shadows() -> int:
	if not is_inside_tree():
		return 0
	var parents: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"roof_occluders"):
		var roof := node as RoofOverlay
		if roof != null and _same_canvas(roof) and roof.get_parent() != null:
			parents[roof.get_parent().get_instance_id()] = roof.get_parent()
	var count := 0
	for parent: Node in parents.values():
		for child: Node in parent.find_children("*","Polygon2D",true,false):
			if child.has_meta(&"city_sun_shadow"):
				count += 1
	return count


## The theme's physical sun reaches every cast through the shared shade
## material (WorldDepthStyle); lengths and softness were set at build time.
func _apply_direct_light(profile: Dictionary) -> void:
	DEPTH.set_sun_shade(profile.get("sun_shade",DEPTH.SUN_SHADE) as Color)


func _restore_environment() -> void:
	# Authored contexts call this every frame; touch the uniform only once.
	if not DEPTH.sun_shade().is_equal_approx(DEPTH.SUN_SHADE):
		DEPTH.set_sun_shade(DEPTH.SUN_SHADE)
	_ground = null
	_ground_signature.clear()
	if _mist_material != null:
		_mist_material.set_shader_parameter("ground_receiver_enabled",false)


func _bind_ground_receiver() -> void:
	var ground := _ground.get_ref() as GroundSplatRenderer if _ground != null else null
	if ground == null or not _same_canvas(ground) or ground.quad_count() == 0:
		_ground_signature.clear()
		_mist_material.set_shader_parameter("ground_receiver_enabled",false)
		return
	var source := ground.get_shader_material()
	var indices: PackedFloat32Array = source.get_shader_parameter("slot_index")
	var values: Dictionary = {}
	for key: String in GROUND_PARAMETERS:
		values[key] = _uniform_value(source,key,GROUND_DEFAULTS.get(key))
	var stain_layer := float(_uniform_value(source,"stain_layer",GROUND_DEFAULTS.stain_layer))
	var has_stain := ground.has_meta(&"_stain_set")
	var signature: Array = [ground.get_instance_id(),indices,stain_layer,has_stain,values]
	if signature == _ground_signature:
		return
	_ground_signature = signature
	for key: String in GROUND_PARAMETERS:
		_mist_material.set_shader_parameter("receiver_"+key,values[key])
	var damp_a := Vector4.ZERO
	var damp_b := Vector4.ZERO
	for slot: int in range(mini(8,indices.size())):
		var eligible := int(roundf(indices[slot])) in [5,12]
		if slot < 4:
			damp_a[slot] = 1.0 if eligible else 0.0
		else:
			damp_b[slot-4] = 1.0 if eligible else 0.0
	_mist_material.set_shader_parameter("receiver_damp_a",damp_a)
	_mist_material.set_shader_parameter("receiver_damp_b",damp_b)
	_mist_material.set_shader_parameter("receiver_damp_stain",has_stain and int(roundf(stain_layer)) in [5,12])
	_mist_material.set_shader_parameter("ground_receiver_enabled",true)


func _uniform_value(material: ShaderMaterial, key: String, fallback: Variant) -> Variant:
	var value: Variant = material.get_shader_parameter(key)
	return value if value != null else _source_default(material.shader,key,fallback)


func _source_default(shader: Shader, key: String, fallback: Variant) -> Variant:
	if shader == null:
		return fallback
	var cache_key := "%d/%s" % [shader.get_instance_id(),key]
	if not _shader_defaults.has(cache_key):
		# get_shader_parameter returns only an assigned material override here.
		# RenderingServer documents this API as the source uniform's default:
		# docs.godotengine.org/en/stable/classes/class_renderingserver.html
		var value: Variant = RenderingServer.shader_get_parameter_default(shader.get_rid(),StringName(key))
		_shader_defaults[cache_key] = value if value != null else fallback
	return _shader_defaults[cache_key]


func _refresh_rooms() -> void:
	_rooms_dirty = false
	var next: Array[Rect2] = []
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		var volume := node as Area2D
		if volume == null or volume.is_queued_for_deletion() or volume.get_world_2d() != get_world_2d() or volume.get_canvas() != get_canvas():
			continue
		var collision := volume.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		# Actual transformed shape bounds are conservative for rotated rooms and
		# non-rectangular shapes: an outside margin may clear, indoors never haze.
		var bounds: Rect2 = collision.global_transform * collision.shape.get_rect()
		if bounds.has_area():
			next.append(bounds)
	if next != _rooms:
		_rooms = next
		_room_revision += 1


func _update_receiver(area: Rect2) -> void:
	# At most 127x127 texels, snapped to a world grid. Camera subpixel movement
	# does not regenerate it. Rooms stream lazily; no per-frame full-world scan.
	var cell := maxf(32.0, ceilf(maxf(area.size.x, area.size.y) / MASK_CELLS))
	var origin := (area.position / cell).floor() * cell
	var size := Vector2i(((area.end - origin) / cell).ceil())
	if origin == _mask_origin and size == _mask_size and is_equal_approx(cell, _mask_cell) and _mask_revision == _room_revision:
		return
	_mask_origin = origin
	_mask_size = size
	_mask_cell = cell
	_mask_revision = _room_revision
	_mask_image = Image.create(size.x, size.y, false, Image.FORMAT_L8)
	_mask_image.fill(Color.WHITE)
	for bounds: Rect2 in _rooms:
		if not bounds.grow(cell).intersects(area):
			continue
		# Exclude every texel touching the room plus one conservative cell. The
		# nearest-filtered receiver has no translucent edge crossing a doorway.
		var first := Vector2i(((bounds.position-origin)/cell).floor())-Vector2i.ONE
		var last := Vector2i(((bounds.end-origin)/cell).ceil())+Vector2i.ONE
		first = first.clamp(Vector2i.ZERO, size)
		last = last.clamp(Vector2i.ZERO, size)
		if last.x > first.x and last.y > first.y:
			_mask_image.fill_rect(Rect2i(first,last-first), Color.BLACK)
	if _mask == null or _mask.get_width() != size.x or _mask.get_height() != size.y:
		_mask = ImageTexture.create_from_image(_mask_image)
	else:
		_mask.update(_mask_image)
	_mist_material.set_shader_parameter("outdoor_mask", _mask)
	_mist_material.set_shader_parameter("mask_origin", origin)
	_mist_material.set_shader_parameter("mask_extent", Vector2(size)*cell)
	_mask_rebuilds += 1
