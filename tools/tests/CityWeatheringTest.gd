extends Node2D
## Cause-based weathering (CityWeathering): every stain sits on its physical
## source (runoff under a real sill, soot over a working vent), never covers a
## doorway frame or another module, never becomes cover, fades with the facade,
## stays deterministic, and follows the district's profile. The wall field and
## plinth carry what the wall-foot damp shader needs.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
const WEATHERING := preload("res://scenes/world/buildings/weathering/CityWeathering.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const FAMILIES: Array[StringName] = [&"service_courtyards", &"checkpoint_lanes", &"collapsed_ward", &"civilian_cutthrough", &"inner_district_gate", &"industrial_cutthrough", &"ruined_services", &"underpass_veins", &"canal_services", &"rail_yard", &"military_staging", &"outer_wall", &"siege_services", &"gate_district"]
const USAGES: Array[StringName] = [&"row_house", &"shop", &"workshop", &"passage"]
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _kit(segment: int, usage: StringName, family: StringName, seed_value: int) -> Dictionary:
	Global.attempt_segment = segment
	var host := Node2D.new()
	add_child(host)
	var roof := ROOF.instantiate() as RoofOverlay
	host.add_child(roof)
	var rect := Rect2i(3, 15, 14, 8)
	var doors: Array = [{"pos": Vector2i(9, 22), "dir": Vector2i.DOWN, "width": 2}]
	roof.configure(rect, 64, Vector2i.DOWN, null, usage, seed_value, doors)
	var kit := KIT.new()
	host.add_child(kit)
	kit.configure(rect, 64, doors, roof, false, PackedVector2Array(), true, {"building_usage": usage, "visual_seed": seed_value, "family_id": family})
	return {"host": host, "kit": kit}


func _rect_of(shape: Polygon2D) -> Rect2:
	var rect := Rect2(shape.transform * shape.polygon[0], Vector2.ZERO)
	for point: Vector2 in shape.polygon: rect = rect.expand(shape.transform * point)
	return rect


func _run() -> void:
	var previous_segment := Global.attempt_segment
	_test_profiles()
	var stains_by_family: Dictionary = {}
	var signatures: Dictionary = {}
	for family: StringName in FAMILIES:
		stains_by_family[family] = 0
		for usage: StringName in USAGES:
			for index in 3:
				var seed_value := 7001 + index * 131 + int(usage.hash() % 97)
				var made := _kit(6, usage, family, seed_value)
				var kit: Node2D = made.kit
				var signature := _check_kit(kit, family, usage)
				stains_by_family[family] = int(stains_by_family[family]) + signature.size()
				# The same building rebuilds the same stains.
				var again := _kit(6, usage, family, seed_value)
				_check(_check_kit(again.kit, family, usage) == signature, "%s %s seed %d rebuilds identical weathering" % [family, usage, seed_value])
				signatures[signature] = true
				(made.host as Node).queue_free()
				(again.host as Node).queue_free()
	_check(int(stains_by_family[&"canal_services"]) > int(stains_by_family[&"service_courtyards"]), "damp canal walls shed more runoff than tidy service courtyards (%d vs %d)" % [stains_by_family[&"canal_services"], stains_by_family[&"service_courtyards"]])
	_check(int(stains_by_family[&"service_courtyards"]) > 0, "service courtyards keep a little runoff below some sills")
	_check(signatures.size() > 8, "weathering varies between buildings (%d distinct layouts)" % signatures.size())
	# Districts without a family (S1, the Hub, plain fixtures) stay clean.
	var plain := _kit(2, &"row_house", &"", 5)
	_check(_stains(plain.kit).is_empty(), "a kit without a district family carries no stains")
	(plain.host as Node).queue_free()
	Global.attempt_segment = previous_segment
	print("CityWeatheringTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _test_profiles() -> void:
	for family: StringName in FAMILIES:
		var profile := WEATHERING.resolve(family)
		var ok := true
		# damp: value decrease at full coverage (mask peaks 0.87, street variation <= 1.25);
		# runoff: share toward a ~0.36 stain on ~0.8 plaster (mask peaks 0.71); lichen: hue share.
		ok = ok and float(profile.damp) > 0.0 and float(profile.damp) * 0.87 * 1.25 <= 0.25
		ok = ok and float(profile.runoff) > 0.0 and float(profile.runoff) * 0.71 * 0.45 <= 0.25
		ok = ok and float(profile.lichen) >= 0.0 and float(profile.lichen) <= 0.5 and float(profile.soot) >= 0.0 and float(profile.soot) <= 0.3
		_check(ok, "%s strongest deposits stay within the brief's 10-25%% local value change" % family)
		var share := float(profile.get("runoff_share", -1.0))
		_check(share >= 0.0 and share <= 0.5, "%s sheds runoff below at most half of its silled windows, so most walls stay clean" % family)
		_check(float(profile.damp) > 0.0 and float(profile.lichen) > 0.0, "%s has some wall-foot damp and roof lichen" % family)
	var clean := WEATHERING.resolve(&"")
	_check(float(clean.damp) == 0.0 and float(clean.runoff) == 0.0 and float(clean.lichen) == 0.0 and float(clean.soot) == 0.0, "authored contexts (no family) are clean")
	_check(WEATHERING.resolve(&"unknown_future_family") == WEATHERING.resolve(&"service_courtyards"), "an unknown procedural family falls back to Service Courtyards")
	_check(float(WEATHERING.resolve(&"canal_services").damp) > float(WEATHERING.resolve(&"service_courtyards").damp), "the canal is damper at the wall foot than service courtyards")
	_check(float(WEATHERING.resolve(&"industrial_cutthrough").soot) > 0.0 and float(WEATHERING.resolve(&"ruined_services").soot) == 0.0, "only districts with operating vents keep soot intent (abandoned stacks do not)")
	# The actual owner: a district atmosphere sets the globals, an authored
	# context clears them, and leaving the scene never leaks them onward.
	var atmosphere := WorldAtmosphere.new()
	add_child(atmosphere)
	atmosphere.apply_theme(&"canal_services")
	_check(WEATHERING.current_theme() == &"canal_services", "the district atmosphere applies its damp and lichen")
	atmosphere.apply_theme(&"", &"hub")
	_check(WEATHERING.current_theme() == &"", "the authored Hub context is clean")
	atmosphere.apply_theme(&"rail_yard")
	remove_child(atmosphere)
	atmosphere.free()
	_check(WEATHERING.current_theme() == &"", "leaving the district clears its weathering for the next scene")


## Checks one composed kit; returns its stain signature (kind + rect).
func _check_kit(kit: Node2D, family: StringName, usage: StringName) -> Array:
	var signature: Array = []
	var modules: Array[Polygon2D] = []
	var fields: Array[Polygon2D] = []
	var blockers: Array[Rect2] = []
	for node: Node in kit.find_children("*", "Polygon2D", true, false):
		var shape := node as Polygon2D
		if shape.has_meta(&"facade_module"):
			modules.append(shape)
			blockers.append(_rect_of(shape))
		if shape.has_meta(&"facade_wall_field"):
			fields.append(shape)
			var field: Rect2 = shape.get_meta(&"facade_wall_field")
			_check(is_equal_approx(shape.uv[0].x, field.size.y - COMPOSER.PLINTH_PX), "%s %s: the wall field carries its height for the wall-foot damp" % [family, usage])
		if shape.has_meta(&"facade_plinth"):
			_check(shape.material is ShaderMaterial and (shape.material as ShaderMaterial).shader == COMPOSER.PLINTH_SHADER, "%s %s: the plinth draws through the damp-aware plinth shader" % [family, usage])
	var profile := WEATHERING.resolve(family)
	for stain: Polygon2D in _stains(kit):
		var kind: StringName = stain.get_meta(WEATHERING.META)
		var area := _rect_of(stain)
		var source: Rect2 = stain.get_meta(&"facade_weathering_source")
		signature.append([kind, area])
		_check(stain.get_parent() != kit and stain.get_parent().get_parent() == kit, "%s %s: a stain lives in its facade group, so it fades with the roof cutaway" % [family, usage])
		_check(not stain.is_in_group(&"foreground_solid_occluders") and not stain.is_in_group(&"foreground_occluders") and not stain.has_meta(&"facade_coverage"), "%s %s: a stain is never cover" % [family, usage])
		# Single fade: an opaque wall piece (its own alpha 1, no blend tricks), so the
		# group's cutaway alpha is the only translucency, as for the field and modules.
		_check(is_equal_approx(stain.color.a, 1.0) and is_equal_approx(stain.modulate.a, 1.0) and is_equal_approx(stain.self_modulate.a, 1.0) and stain.material is ShaderMaterial and (stain.material as ShaderMaterial).shader == WEATHERING.STAIN_SHADER, "%s %s: a stain is an opaque wall piece drawn through the stain wall shader" % [family, usage])
		_check(area.is_equal_approx(stain.get_meta(&"facade_weathering_rect")), "%s %s: the stain piece covers exactly its planned area" % [family, usage])
		var strength := fmod(stain.uv[0].x, 1.0)
		_check(strength > 0.0 and strength <= float(profile.runoff) + 0.001, "%s %s: the stain's strength stays within its district's runoff" % [family, usage])
		for field: Polygon2D in fields:
			_check(_rect_of(field).intersection(area).get_area() <= 0.5, "%s %s: the wall field is cut around the stain, so no pixel is drawn twice" % [family, usage])
		var on_source := false
		for module: Polygon2D in modules:
			if _rect_of(module).is_equal_approx(source): on_source = true
		_check(on_source, "%s %s: a %s stain belongs to an actual module" % [family, usage, kind])
		_check(kind == &"runoff" or kind == &"rust", "%s %s: only sill runoff and fitting rust exist; no facade piece is a soot source yet" % [family, usage])
		_check(is_equal_approx(area.position.y, source.end.y) and absf(area.get_center().x - source.get_center().x) < 0.5, "%s %s: %s starts at its window's sill" % [family, usage, kind])
		if kind == &"rust":
			_check(bool(profile.get("rust", false)) and _module_kind(modules, source) == &"small", "%s %s: rust runs only from an iron-barred window in a working district" % [family, usage])
		for blocker: Rect2 in blockers:
			if blocker.is_equal_approx(source): continue
			_check(blocker.intersection(area).get_area() <= 0.5, "%s %s: a stain never covers another module" % [family, usage])
	return signature


func _module_kind(modules: Array[Polygon2D], source: Rect2) -> StringName:
	for module: Polygon2D in modules:
		if _rect_of(module).is_equal_approx(source): return StringName(module.get_meta(&"facade_module"))
	return &""


func _stains(kit: Node2D) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for node: Node in kit.find_children("*", "Polygon2D", true, false):
		if node.has_meta(WEATHERING.META): result.append(node as Polygon2D)
	return result
