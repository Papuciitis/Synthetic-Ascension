extends Node2D
class_name WorldAtmosphere

## Theme presentation only. Daylight samples world coordinates; low air sits
## below actors and excludes actual indoor volumes, including open cutaways.
## Neither pass owns visibility, collision, theme selection or gameplay time.

const PROFILES := preload("res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd")
const SHADER := preload("res://core/systems/world/atmosphere/world_atmosphere.gdshader")
const MIST_SHADER := preload("res://core/systems/world/atmosphere/ground_air.gdshader")
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
const ROOF_BASELINE: StringName = &"_theme_atmosphere_roof_baseline"
const SUN_BASELINE: StringName = &"_theme_atmosphere_sun_baseline"
const Z := 1400
const AIR_Z := -8
const ROOM_POLL_SECONDS := 0.5
const MASK_CELLS := 126.0
# Headless RenderingServer uses dummy values. These mirror the two source
# shader contracts only for that fallback; native reads the actual defaults.
const ROOF_DEFAULTS := {"lit_slope":1.12,"shade_slope":0.72,"ridge_light":0.4}
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
var _roof_materials: Dictionary = {}
var _sun_shadows: Dictionary = {}
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
		"environment_scans":_environment_scans, "roof_material_count":_roof_materials.size(),
		"sun_shadow_count":_sun_shadows.size(), "ground_receiver_enabled":not _ground_signature.is_empty()}


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
	if node is RoofOverlay or node is GroundSplatRenderer:
		_environment_dirty = true
	elif node is Sprite2D and node.get_parent() is GroundSplatRenderer:
		_environment_dirty = true
	elif node is Polygon2D:
		var polygon := node as Polygon2D
		var material := polygon.material as ShaderMaterial
		if polygon.has_meta(&"city_sun_shadow") or (material != null and material.shader == ROOF_SHADER):
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
		_apply_direct_light(float(_profile.direct_light))
	# Ground maps can be repainted in place while the node survives. Sampling
	# its eight-slot signature is constant work and cannot hold stale wet slots
	# for the slower discovery interval after a stream/reset.
	_bind_ground_receiver()


func _same_canvas(item: CanvasItem) -> bool:
	return item.is_inside_tree() and not item.is_queued_for_deletion() and item.get_world_2d() == get_world_2d() and item.get_canvas() == get_canvas()


func _discover_environment() -> void:
	_environment_scans += 1
	var next_materials: Dictionary = {}
	var next_shadows: Dictionary = {}
	var parents: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"roof_occluders"):
		var roof := node as RoofOverlay
		if roof == null or not _same_canvas(roof):
			continue
		for child: Node in roof.find_children("*","Polygon2D",true,false):
			var plane := child as Polygon2D
			if not _same_canvas(plane):
				continue
			var material := plane.material as ShaderMaterial
			if material == null or material.shader != ROOF_SHADER:
				continue
			var key := material.get_instance_id()
			if not material.has_meta(ROOF_BASELINE):
				material.set_meta(ROOF_BASELINE,{
					"lit_slope":material.get_shader_parameter("lit_slope"),
					"shade_slope":material.get_shader_parameter("shade_slope"),
					"ridge_light":material.get_shader_parameter("ridge_light")})
			next_materials[key] = weakref(material)
		var parent := roof.get_parent()
		if parent != null:
			parents[parent.get_instance_id()] = parent
	# Each loaded building/chunk scope is visited once per invalidation/poll,
	# even when many roofs share it. No full-tree search runs each frame.
	for parent: Node in parents.values():
		for child: Node in parent.find_children("*","Polygon2D",true,false):
			var shadow := child as Polygon2D
			if not shadow.has_meta(&"city_sun_shadow") or not _same_canvas(shadow):
				continue
			if not shadow.has_meta(SUN_BASELINE):
				shadow.set_meta(SUN_BASELINE,shadow.color.a)
			next_shadows[shadow.get_instance_id()] = weakref(shadow)
	for key: Variant in _roof_materials.keys():
		if not next_materials.has(key):
			_restore_roof((_roof_materials[key] as WeakRef).get_ref() as ShaderMaterial)
	for key: Variant in _sun_shadows.keys():
		if not next_shadows.has(key):
			_restore_sun((_sun_shadows[key] as WeakRef).get_ref() as Polygon2D)
	_roof_materials = next_materials
	_sun_shadows = next_shadows
	var ground := get_parent().get_node_or_null("GroundSplat") as GroundSplatRenderer
	_ground = weakref(ground) if ground != null and _same_canvas(ground) else null


func _apply_direct_light(direct: float) -> void:
	var amount := clampf(direct,0.0,1.0)
	for ref: WeakRef in _roof_materials.values():
		var material := ref.get_ref() as ShaderMaterial
		if material == null:
			continue
		if is_equal_approx(amount,1.0):
			_restore_roof(material)
			continue
		var base: Dictionary = material.get_meta(ROOF_BASELINE)
		material.set_shader_parameter("lit_slope",1.0+(_roof_value(material,base,"lit_slope")-1.0)*amount)
		material.set_shader_parameter("shade_slope",1.0+(_roof_value(material,base,"shade_slope")-1.0)*amount)
		material.set_shader_parameter("ridge_light",_roof_value(material,base,"ridge_light")*amount)
	for ref: WeakRef in _sun_shadows.values():
		var shadow := ref.get_ref() as Polygon2D
		if shadow != null:
			var color := shadow.color
			color.a = float(shadow.get_meta(SUN_BASELINE))*(0.35+0.65*amount)
			shadow.color = color


func _restore_roof(material: ShaderMaterial) -> void:
	if material == null or not material.has_meta(ROOF_BASELINE):
		return
	var base: Dictionary = material.get_meta(ROOF_BASELINE)
	for key: String in ["lit_slope","shade_slope","ridge_light"]:
		material.set_shader_parameter(key,base[key])


func _restore_sun(shadow: Polygon2D) -> void:
	if shadow != null and shadow.has_meta(SUN_BASELINE):
		var color := shadow.color
		color.a = float(shadow.get_meta(SUN_BASELINE))
		shadow.color = color


func _restore_environment() -> void:
	for ref: WeakRef in _roof_materials.values():
		_restore_roof(ref.get_ref() as ShaderMaterial)
	for ref: WeakRef in _sun_shadows.values():
		_restore_sun(ref.get_ref() as Polygon2D)
	_roof_materials.clear()
	_sun_shadows.clear()
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


func _roof_value(material: ShaderMaterial, base: Dictionary, key: String) -> float:
	# Read the preserved raw baseline, never the previously scaled override.
	# Restoring null below restores the owner's exact unset/default state.
	var raw: Variant = base[key]
	return float(raw if raw != null else _source_default(material.shader,key,ROOF_DEFAULTS[key]))


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
