extends RefCounted
## Cause-based weathering of composed walls and roofs (2026-10-22). Follows the
## lead's segment material brief
## (docs/art/2026-10-21-segment-material-atmosphere-direction/README.md) and its
## support masks (assets/world/material_support/v1/masks, rasterised for the
## runtime into assets/world/weathering/v1).
##
## Every stain has a physical source:
## - capillary damp rises 12-44 world px from the actual wall foot (the wall
##   field, plinth and stain shaders, through the sa_weather_damp* globals);
## - rain or mineral runoff falls from a real window sill, and rust only from
##   an iron-barred window in a working district;
## - lichen grows near shaded roof eaves (roof.gdshader, sa_weather_lichen*).
## - soot: no wall stain yet. The facade "service" module is a closed gauge
##   cabinet with no outlet (wall_service_box.png), so it is not a soot source;
##   the profiles' soot values wait for a real operating flue or vent owner.
## Theme light and air stay with ThemeAtmosphereProfiles. Ground belongs to
## DistrictGroundPolicy and is never touched here.
##
## A sill stain is a piece of the wall, not an overlay: the composer cuts its
## area out of the wall field like a window module, and the piece draws the
## same wall with the stain composited in (facade_stain.gdshader). Every facade
## pixel keeps one opaque owner, so the roof cutaway fades it once.
##
## Presentation only: no collision, cover faces, blockers, doors or rewards,
## and no generator RNG. Choices hash the building's visual seed with this
## file's own salts, so a streamed chunk rebuilds identical stains.

const RUNOFF_MASK := preload("res://assets/world/weathering/v1/runoff_streaks.png")
const STAIN_SHADER := preload("res://scenes/world/buildings/weathering/facade_stain.gdshader")
const SALT_RUNOFF := 0x52A0FF
## Window modules with a sill that sheds rain.
const SILLED: Array[StringName] = [&"shutters", &"flowers", &"small", &"arched"]
## Rust from iron fittings: only the barred window module carries iron.
const IRON_FITTED: Array[StringName] = [&"small"]
## runoff_streaks.png: leak source at (128, 32) of 256x512, gravity +y.
const RUNOFF_ROWS := Vector2(32.0 / 512.0, 1.0)
const META := &"facade_weathering"
## Plinth height of CityFacadeComposer (kept in step with PLINTH_PX).
const PLINTH_PX := 22.0

## Per district family. Each value states the local change at full mask
## coverage, with no hidden gain:
## - damp: value decrease at the wall foot (the hue comes from damp_tint);
## - runoff: share of the way to runoff_tint (a 0.36 stain on 0.8 plaster at
##   0.30 darkens it by about 0.13); runoff_share: the share of silled windows
##   that shed visible runoff, so most walls stay clean; rust: iron-barred
##   windows shed rust instead;
## - lichen: share of the way to the lichen hue on shaded eaves (value kept);
## - soot: intent for a future operating flue/vent owner (0 = none operating).
## The brief's trial range is a 10-25% local value change at the strongest
## deposit; masks peak below 1 (damp 0.87, runoff 0.71, lichen 0.64) and
## deposits vary, so most stained pixels change much less.
const PROFILES := {
	&"service_courtyards": {"damp": 0.10, "damp_tint": Color(0.80, 0.82, 0.77), "runoff": 0.28, "runoff_share": 0.14, "runoff_tint": Color(0.36, 0.37, 0.36), "soot": 0.0, "lichen": 0.30},
	&"checkpoint_lanes": {"damp": 0.08, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.34, "runoff_share": 0.30, "runoff_tint": Color(0.34, 0.36, 0.37), "soot": 0.0, "lichen": 0.18},
	&"collapsed_ward": {"damp": 0.10, "damp_tint": Color(0.80, 0.80, 0.75), "runoff": 0.40, "runoff_share": 0.36, "runoff_tint": Color(0.38, 0.37, 0.34), "soot": 0.0, "lichen": 0.45},
	&"civilian_cutthrough": {"damp": 0.10, "damp_tint": Color(0.80, 0.82, 0.77), "runoff": 0.26, "runoff_share": 0.16, "runoff_tint": Color(0.37, 0.37, 0.35), "soot": 0.0, "lichen": 0.32},
	&"inner_district_gate": {"damp": 0.07, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.38, "runoff_share": 0.32, "runoff_tint": Color(0.33, 0.35, 0.37), "soot": 0.0, "lichen": 0.18},
	&"industrial_cutthrough": {"damp": 0.09, "damp_tint": Color(0.79, 0.79, 0.76), "runoff": 0.34, "runoff_share": 0.22, "runoff_tint": Color(0.36, 0.36, 0.35), "rust": true, "soot": 0.22, "lichen": 0.20},
	&"ruined_services": {"damp": 0.14, "damp_tint": Color(0.76, 0.79, 0.72), "runoff": 0.46, "runoff_share": 0.42, "runoff_tint": Color(0.36, 0.35, 0.32), "soot": 0.0, "lichen": 0.50},
	&"underpass_veins": {"damp": 0.20, "damp_tint": Color(0.74, 0.80, 0.74), "runoff": 0.42, "runoff_share": 0.36, "runoff_tint": Color(0.36, 0.39, 0.38), "soot": 0.0, "lichen": 0.40},
	&"canal_services": {"damp": 0.22, "damp_tint": Color(0.72, 0.79, 0.73), "runoff": 0.38, "runoff_share": 0.30, "runoff_tint": Color(0.34, 0.38, 0.36), "soot": 0.0, "lichen": 0.45},
	&"rail_yard": {"damp": 0.06, "damp_tint": Color(0.80, 0.79, 0.76), "runoff": 0.32, "runoff_share": 0.20, "runoff_tint": Color(0.36, 0.36, 0.35), "rust": true, "soot": 0.14, "lichen": 0.15},
	&"military_staging": {"damp": 0.07, "damp_tint": Color(0.80, 0.79, 0.75), "runoff": 0.22, "runoff_share": 0.12, "runoff_tint": Color(0.37, 0.37, 0.36), "soot": 0.0, "lichen": 0.18},
	&"outer_wall": {"damp": 0.10, "damp_tint": Color(0.79, 0.81, 0.77), "runoff": 0.30, "runoff_share": 0.22, "runoff_tint": Color(0.36, 0.37, 0.36), "soot": 0.0, "lichen": 0.38},
	&"siege_services": {"damp": 0.07, "damp_tint": Color(0.80, 0.79, 0.76), "runoff": 0.34, "runoff_share": 0.26, "runoff_tint": Color(0.36, 0.36, 0.35), "rust": true, "soot": 0.05, "lichen": 0.22},
	&"gate_district": {"damp": 0.07, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.32, "runoff_share": 0.26, "runoff_tint": Color(0.34, 0.35, 0.36), "soot": 0.0, "lichen": 0.18},
}
const LICHEN_TINT := Color(0.52, 0.56, 0.40)
const RUST_TINT := Color(0.42, 0.29, 0.18)

static var _materials: Dictionary = {}
static var _theme: StringName = &"__unset__"
static var _white: ImageTexture


## The weathering of a district family. An empty family (S1, the Hub, authored
## contexts, tests without a theme) is clean; an unknown procedural family
## falls back to Service Courtyards like the ground and atmosphere profiles.
static func resolve(family: StringName) -> Dictionary:
	if family == &"":
		return {"damp": 0.0, "damp_tint": Color.WHITE, "runoff": 0.0, "runoff_share": 0.0, "runoff_tint": Color.BLACK, "soot": 0.0, "lichen": 0.0}
	return (PROFILES.get(family, PROFILES[&"service_courtyards"]) as Dictionary).duplicate()


## Sets the theme's wall-foot damp and roof lichen for every wall, plinth,
## stain and roof material at once (project shader globals; nothing is scanned
## or rewritten per material). WorldAtmosphere calls it when the district's
## atmosphere applies, and with an empty family when it leaves the scene.
static func apply_theme(family: StringName) -> void:
	if family == _theme:
		return
	_theme = family
	var profile := resolve(family)
	RenderingServer.global_shader_parameter_set(&"sa_weather_damp", float(profile.damp))
	RenderingServer.global_shader_parameter_set(&"sa_weather_damp_tint", profile.damp_tint as Color)
	RenderingServer.global_shader_parameter_set(&"sa_weather_lichen", float(profile.lichen))
	RenderingServer.global_shader_parameter_set(&"sa_weather_lichen_tint", LICHEN_TINT)


static func current_theme() -> StringName:
	return _theme


## Where sill runoff falls on one composed wall run, before the wall field is
## built (the composer cuts each area out of the field). `modules` are the
## run's placed modules ({kind, rect}); `cuts` every rect a stain must not
## cover (door frames, quoins, vines, the modules themselves).
static func plan_run(kit: Node2D, modules: Array[Dictionary], cuts: Array[Rect2], bottom: float) -> Array[Dictionary]:
	var stains: Array[Dictionary] = []
	var district: Variant = kit.get("_district_profile")
	var family: StringName = StringName((district as Dictionary).get("family_id", &"")) if district is Dictionary else &""
	var profile := resolve(family)
	if float(profile.runoff) <= 0.0:
		return stains
	var seed_value := int((district as Dictionary).get("visual_seed", 0)) if district is Dictionary else 0
	var foot := bottom - PLINTH_PX
	for module: Dictionary in modules:
		var kind: StringName = module.kind
		var rect: Rect2 = module.rect
		if not kind in SILLED or _roll(seed_value, SALT_RUNOFF, rect) >= float(profile.runoff_share): continue
		# From the sill down the wall, at most to the plinth.
		var width := roundf(rect.size.x * 0.62)
		var length := floorf(minf(foot - rect.end.y, rect.size.x * 2.2))
		if length < 24.0: continue
		# The piece starts at the sill, where the mask's leak source sits.
		var area := Rect2(roundf(rect.get_center().x - width * 0.5), rect.end.y, width, length)
		if not _clear(area, cuts, rect): continue
		var rust := bool(profile.get("rust", false)) and kind in IRON_FITTED
		stains.append({"kind": &"rust" if rust else &"runoff", "area": area, "source": rect,
			"tint": RUST_TINT if rust else profile.runoff_tint as Color,
			"strength": float(profile.runoff) * lerpf(0.55, 1.0, _roll(seed_value, SALT_RUNOFF + 1, rect))})
	return stains


## Draws the planned stains as opaque wall pieces in the facade group. `wall`
## is the family's wall field material (its tile, mean, contrast and tint are
## shared), `field` the run's wall rect including the plinth, `light` the
## field's face light.
static func draw_run(group: Node2D, wall: ShaderMaterial, stains: Array[Dictionary], field: Rect2, light: Color) -> void:
	var field_h := roundf(field.size.y - PLINTH_PX)
	for spec: Dictionary in stains:
		var area: Rect2 = spec.area
		var piece := Polygon2D.new()
		piece.name = "FacadeWeathering"
		# Keep the wall cut and its replacement in the same transform domain.
		# Fractional sill positions belong in polygon vertices: a separate item
		# origin would be rounded independently by 2D transform snapping.
		var corners := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		var polygon := PackedVector2Array()
		for corner: Vector2 in corners:
			polygon.append(area.position + corner * area.size)
		piece.polygon = polygon
		piece.color = light
		# A 1x1 texture keeps polygon UVs unnormalised (as the wall field).
		piece.texture = _white_texture()
		var strength := clampf(float(spec.strength), 0.0, 0.99)
		var uv := PackedVector2Array()
		# Encode mask corners alongside the existing wall-height/strength UVs.
		# The shader decodes these at vertices, before interpolation. This keeps
		# one shared material per wall/tint rather than a bounds uniform per piece.
		for index: int in corners.size():
			var corner: Vector2 = corners[index]
			var wall_y := (polygon[index].y - field.position.y) / field_h
			uv.append(Vector2(2.0 * field_h + corner.x + strength, wall_y + 2.0 * corner.y))
		piece.uv = uv
		piece.material = _stain_material(wall, spec.tint as Color)
		piece.set_meta(META, spec.kind)
		piece.set_meta(&"facade_weathering_source", spec.source)
		piece.set_meta(&"facade_weathering_rect", area)
		group.add_child(piece)


## True when a stain area covers no frame, quoin, vine or other module (its
## own source module excepted).
static func _clear(area: Rect2, cuts: Array[Rect2], source: Rect2) -> bool:
	for cut: Rect2 in cuts:
		if cut.is_equal_approx(source): continue
		if cut.intersection(area).get_area() > 0.5: return false
	return true


static func _roll(seed_value: int, salt: int, rect: Rect2) -> float:
	return float(posmod(hash([seed_value, salt, int(rect.position.x), int(rect.position.y)]), 10000)) / 10000.0


static func _stain_material(wall: ShaderMaterial, tint: Color) -> ShaderMaterial:
	var key := "%d|%s" % [wall.get_instance_id(), tint.to_html()]
	if _materials.has(key): return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = STAIN_SHADER
	for parameter: String in ["wall_tex", "repeat_px", "tile_mean", "contrast", "tint"]:
		var value: Variant = wall.get_shader_parameter(parameter)
		if value != null: material.set_shader_parameter(parameter, value)
	material.set_shader_parameter("mask", RUNOFF_MASK)
	material.set_shader_parameter("stain", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("mask_rows", RUNOFF_ROWS)
	_materials[key] = material
	return material


static func _white_texture() -> ImageTexture:
	if _white == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
