extends RefCounted
## Cause-based weathering of composed walls and roofs (2026-10-22). Follows the
## lead's segment material brief
## (docs/art/2026-10-21-segment-material-atmosphere-direction/README.md) and its
## support masks (assets/world/material_support/v1/masks, rasterised for the
## runtime into assets/world/weathering/v1).
##
## Every stain has a physical source:
## - capillary damp rises 12-44 world px from the actual wall foot (the wall
##   field and plinth shaders, through the sa_weather_damp* shader globals);
## - rain or mineral runoff falls from a real window sill;
## - soot rises above a working service vent on a workshop wall;
## - lichen grows near shaded roof eaves (roof.gdshader, sa_weather_lichen*).
## Strengths are the brief's trial range: 10-25% local value change at the
## strongest deposit and much less elsewhere, and most walls stay mostly clean.
## Theme light and air stay with ThemeAtmosphereProfiles. Ground belongs to
## DistrictGroundPolicy and is never touched here.
##
## Presentation only: no collision, cover faces, blockers, doors or rewards,
## and no generator RNG. Choices hash the building's visual seed with this
## file's own salts, so a streamed chunk rebuilds identical stains.

const RUNOFF_MASK := preload("res://assets/world/weathering/v1/runoff_streaks.png")
const SOOT_MASK := preload("res://assets/world/weathering/v1/vent_soot.png")
const STAIN_SHADER := preload("res://scenes/world/buildings/weathering/weathering_stain.gdshader")
const SALT_RUNOFF := 0x52A0FF
const SALT_SOOT := 0x5007D2
## Window modules with a sill that sheds rain.
const SILLED: Array[StringName] = [&"shutters", &"flowers", &"small", &"arched"]
## runoff_streaks.png: leak source at (128, 32) of 256x512, gravity +y.
const RUNOFF_SOURCE := Vector2(0.5, 32.0 / 512.0)
## vent_soot.png: outlet at (256, 420) of 512x512, deposit rises toward -y.
const SOOT_OUTLET := Vector2(0.5, 420.0 / 512.0)
const META := &"facade_weathering"
## Plinth height of CityFacadeComposer (kept in step with PLINTH_PX).
const PLINTH_PX := 22.0

## Per district family. damp/lichen: strength at the strongest mask value;
## runoff: strength and the share of silled windows that shed visible runoff;
## soot: strength above a workshop's service vent (0 = no operating vents).
## Tints are the stain colours drawn at that strength. Values follow the
## brief's per-theme "weathering with a cause" column; trial values for
## native judgement, not measured limits.
const PROFILES := {
	&"service_courtyards": {"damp": 0.14, "damp_tint": Color(0.80, 0.82, 0.77), "runoff": 0.12, "runoff_share": 0.14, "runoff_tint": Color(0.36, 0.37, 0.36), "soot": 0.0, "lichen": 0.10},
	&"checkpoint_lanes": {"damp": 0.10, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.16, "runoff_share": 0.30, "runoff_tint": Color(0.34, 0.36, 0.37), "soot": 0.0, "lichen": 0.06},
	&"collapsed_ward": {"damp": 0.12, "damp_tint": Color(0.80, 0.80, 0.75), "runoff": 0.18, "runoff_share": 0.36, "runoff_tint": Color(0.38, 0.37, 0.34), "soot": 0.0, "lichen": 0.18},
	&"civilian_cutthrough": {"damp": 0.13, "damp_tint": Color(0.80, 0.82, 0.77), "runoff": 0.11, "runoff_share": 0.16, "runoff_tint": Color(0.37, 0.37, 0.35), "soot": 0.0, "lichen": 0.12},
	&"inner_district_gate": {"damp": 0.09, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.18, "runoff_share": 0.32, "runoff_tint": Color(0.33, 0.35, 0.37), "soot": 0.0, "lichen": 0.06},
	&"industrial_cutthrough": {"damp": 0.11, "damp_tint": Color(0.79, 0.79, 0.76), "runoff": 0.15, "runoff_share": 0.22, "runoff_tint": Color(0.42, 0.29, 0.18), "soot": 0.22, "lichen": 0.07},
	&"ruined_services": {"damp": 0.17, "damp_tint": Color(0.76, 0.79, 0.72), "runoff": 0.21, "runoff_share": 0.42, "runoff_tint": Color(0.36, 0.35, 0.32), "soot": 0.0, "lichen": 0.22},
	&"underpass_veins": {"damp": 0.22, "damp_tint": Color(0.74, 0.80, 0.74), "runoff": 0.20, "runoff_share": 0.36, "runoff_tint": Color(0.36, 0.39, 0.38), "soot": 0.0, "lichen": 0.16},
	&"canal_services": {"damp": 0.24, "damp_tint": Color(0.72, 0.79, 0.73), "runoff": 0.17, "runoff_share": 0.30, "runoff_tint": Color(0.34, 0.38, 0.36), "soot": 0.0, "lichen": 0.18},
	&"rail_yard": {"damp": 0.07, "damp_tint": Color(0.80, 0.79, 0.76), "runoff": 0.15, "runoff_share": 0.20, "runoff_tint": Color(0.43, 0.28, 0.17), "soot": 0.14, "lichen": 0.06},
	&"military_staging": {"damp": 0.09, "damp_tint": Color(0.80, 0.79, 0.75), "runoff": 0.09, "runoff_share": 0.12, "runoff_tint": Color(0.37, 0.37, 0.36), "soot": 0.0, "lichen": 0.06},
	&"outer_wall": {"damp": 0.12, "damp_tint": Color(0.79, 0.81, 0.77), "runoff": 0.13, "runoff_share": 0.22, "runoff_tint": Color(0.36, 0.37, 0.36), "soot": 0.0, "lichen": 0.15},
	&"siege_services": {"damp": 0.09, "damp_tint": Color(0.80, 0.79, 0.76), "runoff": 0.16, "runoff_share": 0.26, "runoff_tint": Color(0.42, 0.29, 0.18), "soot": 0.05, "lichen": 0.08},
	&"gate_district": {"damp": 0.09, "damp_tint": Color(0.80, 0.82, 0.80), "runoff": 0.15, "runoff_share": 0.26, "runoff_tint": Color(0.34, 0.35, 0.36), "soot": 0.0, "lichen": 0.06},
}
const LICHEN_TINT := Color(0.52, 0.56, 0.40)
const SOOT_TINT := Color(0.10, 0.09, 0.085)

static var _stain_materials: Dictionary = {}
static var _white: ImageTexture
static var _theme: StringName = &"__unset__"


## The weathering of a district family. An empty family (S1, the Hub, authored
## contexts, tests without a theme) is clean; an unknown procedural family
## falls back to Service Courtyards like the ground and atmosphere profiles.
static func resolve(family: StringName) -> Dictionary:
	if family == &"":
		return {"damp": 0.0, "damp_tint": Color.WHITE, "runoff": 0.0, "runoff_share": 0.0, "runoff_tint": Color.BLACK, "soot": 0.0, "lichen": 0.0}
	return (PROFILES.get(family, PROFILES[&"service_courtyards"]) as Dictionary).duplicate()


## Sets the theme's wall-foot damp and roof lichen for every wall, plinth and
## roof material at once (project shader globals; nothing is scanned or
## rewritten per material). Called when the district's atmosphere applies.
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


## Runoff below real sills and soot above a workshop's service vent on one
## composed wall run. `modules` are the run's placed modules ({kind, rect});
## `cuts` every rect a stain must not cover (door frames, quoins, vines and
## the modules themselves). Stains are translucent pieces of the facade group,
## so they fade with the roof cutaway; they are never coverage faces.
static func decorate_run(group: Node2D, kit: Node2D, modules: Array[Dictionary], cuts: Array[Rect2], bottom: float, height: float) -> void:
	var district: Variant = kit.get("_district_profile")
	var family: StringName = StringName((district as Dictionary).get("family_id", &"")) if district is Dictionary else &""
	var profile := resolve(family)
	if float(profile.runoff) <= 0.0 and float(profile.soot) <= 0.0:
		return
	var seed_value := int((district as Dictionary).get("visual_seed", 0)) if district is Dictionary else 0
	var usage := StringName(kit.get_meta(&"building_usage", &"row_house"))
	var top := bottom - height
	var foot := bottom - PLINTH_PX
	for module: Dictionary in modules:
		var kind: StringName = module.kind
		var rect: Rect2 = module.rect
		if kind in SILLED and float(profile.runoff) > 0.0:
			if _roll(seed_value, SALT_RUNOFF, rect) >= float(profile.runoff_share): continue
			# From the sill down the wall, at most to the plinth.
			var width := rect.size.x * 0.62
			var length := minf(foot - rect.end.y, rect.size.x * 2.2)
			if length < 24.0: continue
			# The quad starts at the sill, where the mask's leak source sits.
			var area := Rect2(rect.get_center().x - width * 0.5, rect.end.y, width, length)
			if not _clear(area, cuts, rect): continue
			var strength := float(profile.runoff) * lerpf(0.55, 1.0, _roll(seed_value, SALT_RUNOFF + 1, rect))
			_stain(group, area, RUNOFF_MASK, profile.runoff_tint as Color, strength, &"runoff", rect, Vector2(RUNOFF_SOURCE.y, 1.0))
		elif kind == &"service" and usage == &"workshop" and float(profile.soot) > 0.0:
			# An operating vent's soot rises up the wall above it, short of the eave.
			var width := rect.size.x * 2.0
			var rise := minf(rect.position.y - top - 10.0, width * 1.6)
			if rise < 32.0: continue
			# The quad ends at the vent's top, where the mask's outlet sits.
			var area := Rect2(rect.get_center().x - width * 0.5, rect.position.y - rise, width, rise)
			if not _clear(area, cuts, rect): continue
			var strength := float(profile.soot) * lerpf(0.7, 1.0, _roll(seed_value, SALT_SOOT, rect))
			_stain(group, area, SOOT_MASK, SOOT_TINT, strength, &"soot", rect, Vector2(0.0, SOOT_OUTLET.y))


## True when a stain area covers no frame, quoin, vine or other module (its
## own source module excepted) and stays on the wall.
static func _clear(area: Rect2, cuts: Array[Rect2], source: Rect2) -> bool:
	for cut: Rect2 in cuts:
		if cut.is_equal_approx(source): continue
		if cut.intersection(area).get_area() > 0.5: return false
	return true


static func _roll(seed_value: int, salt: int, rect: Rect2) -> float:
	return float(posmod(hash([seed_value, salt, int(rect.position.x), int(rect.position.y)]), 10000)) / 10000.0


## One translucent stain quad showing the mask rows `v_range` (0 = mask top),
## so the quad's edge sits exactly on the stain's physical source.
static func _stain(group: Node2D, area: Rect2, mask: Texture2D, tint: Color, strength: float, kind: StringName, source: Rect2, v_range: Vector2) -> void:
	var stain := Polygon2D.new()
	stain.name = "FacadeWeathering"
	stain.polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	# A 1x1 texture keeps polygon UVs unnormalised (0..1 across the mask).
	stain.texture = _white_texture()
	stain.uv = PackedVector2Array([Vector2(0.0, v_range.x), Vector2(1.0, v_range.x), Vector2(1.0, v_range.y), Vector2(0.0, v_range.y)])
	stain.material = _stain_material(mask, tint)
	stain.color = Color(1.0, 1.0, 1.0, clampf(strength, 0.0, 0.35))
	stain.set_meta(META, kind)
	stain.set_meta(&"facade_weathering_source", source)
	group.add_child(stain)


static func _stain_material(mask: Texture2D, tint: Color) -> ShaderMaterial:
	var key := "%s|%s" % [mask.resource_path, tint.to_html()]
	if _stain_materials.has(key): return _stain_materials[key]
	var material := ShaderMaterial.new()
	material.shader = STAIN_SHADER
	material.set_shader_parameter("mask", mask)
	material.set_shader_parameter("stain", Vector3(tint.r, tint.g, tint.b))
	_stain_materials[key] = material
	return material


static func _white_texture() -> ImageTexture:
	if _white == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
