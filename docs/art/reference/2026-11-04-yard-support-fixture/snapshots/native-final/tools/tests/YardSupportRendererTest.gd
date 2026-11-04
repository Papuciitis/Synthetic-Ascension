extends Node
## Actual renderer API regression. Absence is an assertion, never a parse error.
const RENDERER = preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
var passes := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passes += 1
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var renderer = RENDERER.new()
	add_child(renderer)
	var api := renderer.has_method("configure_yard_support_preview") and renderer.has_method("paint_yard_support") and renderer.has_method("yard_support_signature")
	check(api, "actual renderer exposes independent yard support API")
	if api:
		await _contract(renderer)
	renderer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	RENDERER.release_static_caches()
	print("YardSupportRendererTest: %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures else 0)

func spec(seed_value: int = 944996572) -> Dictionary:
	return {"footprint_px": PackedVector2Array([Vector2(512,512),Vector2(1152,512),Vector2(1152,1152),Vector2(512,1152)]),
		"doors": [{"pos":Vector2i(12,17),"dir":Vector2i.DOWN,"width":2}],
		"garden_contact_px":Vector2(512,1152),"visual_seed":seed_value}

func paint(renderer: Node, coord: Vector2i, specs: Array[Dictionary]) -> void:
	renderer.call("paint_yard_support",coord,specs)

func signature(renderer: Node, coord: Vector2i = Vector2i.ZERO) -> PackedByteArray:
	return renderer.call("yard_support_signature",coord)

func zeros(bytes: PackedByteArray) -> bool:
	for value in bytes:
		if value != 0: return false
	return true

func snapshot(renderer: Node) -> Array:
	return [renderer.get("_cover_a").get_data(),renderer.get("_cover_b").get_data(),
		renderer.get("_light").get_data(),renderer.active_slot_materials(),renderer.slot_borrow_count()]

func _contract(renderer: Node) -> void:
	renderer.configure(64,32)
	var material: ShaderMaterial = renderer.get_shader_material()
	var original: Shader = material.shader
	check(original == RENDERER.SHADER, "default uses exact original shader resource")
	check(renderer.get("_yard_support_map") == null, "default allocates no presentation mask")
	var valid: Dictionary = renderer.call("parse_yard_support_target", " -2, 3, -944996572 ")
	check(valid == {"coord":Vector2i(-2,3),"seed":-944996572}, "explicit target parser accepts signed decimal and field whitespace")
	for bad in ["", "1,2", "1,2,3,4", "1.0,2,3", "+1,2,3", "01,2,3", "-0,2,3", "1000001,0,3", "0,-1000001,3", "-9223372036854775808,0,3", "0,-9223372036854775808,3", "1,2,9223372036854775808", "1,2,-9223372036854775809", "1,2,three"]:
		check(renderer.call("parse_yard_support_target",bad).is_empty(), "invalid/overflow/noncanonical target rejected: " + bad)
	check(renderer.call("parse_yard_support_target","-1000000,1000000,-9223372036854775808").size() == 2, "parser preserves int64 lower seed and bounded axes")
	check(not renderer.call("configure_yard_support_preview",true,Vector2i.ZERO,944996572), "request remains inactive without S7 policy")
	check(material.shader == original and renderer.get("_yard_support_map") == null, "inactive policy keeps base resource and lazy data")
	renderer.set_ground_family(&"market_wards")
	check(material.shader == original, "other enabled district cannot activate preview")
	renderer.set_ground_family(&"underpass_veins")
	check(material.shader != original, "saved request activates when S7 policy arrives")
	check(renderer.get("_yard_support_map") != null, "S7 activation creates independent data owner lazily")
	renderer.set_chunk_base(Vector2i.ZERO,6)
	var before := snapshot(renderer)
	seed(5478)
	var rng_before := randi()
	var expected_next := randi()
	seed(5478)
	check(randi() == rng_before, "RNG control starts identically")
	paint(renderer,Vector2i.ZERO,[spec()])
	check(randi() == expected_next, "renderer/planner leave global RNG untouched")
	var first := signature(renderer)
	check(first.size() == 1024 and not zeros(first), "selected household creates positive independent mask")
	check(snapshot(renderer) == before, "mask painting preserves every cover/light/care/slot byte and borrowing count")
	var spec_before := spec().duplicate(true)
	var incoming: Array[Dictionary] = [spec_before]
	paint(renderer,Vector2i.ZERO,incoming)
	check(signature(renderer) == first and incoming == [spec()], "repeat is idempotent and leaves household input untouched")
	var later_care := spec()
	later_care.garden_contact_px = Vector2(1152,512)
	renderer.paint_domestic_care(Vector2i.ZERO,later_care)
	var later_bytes: PackedByteArray = renderer.care_signature(Vector2i.ZERO)
	var overlap := 0
	var care_veto := true
	var after_care := signature(renderer)
	for i in first.size():
		if first[i] > 0 and later_bytes[i] > 0:
			overlap += 1
			care_veto = care_veto and after_care[i] == 0
	check(overlap > 0 and care_veto, "actual later household care clears every overlapping support byte")
	paint(renderer,Vector2i.ZERO,[spec()])
	check(renderer.care_signature(Vector2i.ZERO) == later_bytes, "support repaints preserve actual fractional household care bytes")
	var care_fractional := false
	for value in later_bytes:
		care_fractional = care_fractional or (value > 0 and value < 255)
	check(care_fractional, "household veto fixture includes real fractional care")
	renderer.set_chunk_base(Vector2i.ZERO,6)
	paint(renderer,Vector2i.ZERO,[spec()])
	paint(renderer,Vector2i(1,0),[spec()])
	check(signature(renderer) == first and zeros(signature(renderer,Vector2i(1,0))), "non-target chunk cannot paint")
	paint(renderer,Vector2i.ZERO,[spec(3)])
	check(zeros(signature(renderer)), "wrong household seed clears target rather than selecting all homes")
	paint(renderer,Vector2i.ZERO,[spec(),spec()])
	check(zeros(signature(renderer)), "ambiguous duplicate household seed fails closed")
	paint(renderer,Vector2i.ZERO,[spec()])
	renderer.flush()
	check(not renderer.get("_dirty"), "original dirty state is clean before independent upload")
	paint(renderer,Vector2i.ZERO,[])
	check(not renderer.get("_dirty") and renderer.get("_yard_support_dirty"), "mask dirty state is independent of original maps")
	renderer.flush()
	check(not renderer.get("_yard_support_dirty") and zeros(material.get_shader_parameter("yard_support_map").get_image().get_data()), "independent texture uploads even when original maps are clean")
	paint(renderer,Vector2i.ZERO,[spec()])
	var positive := -1
	for i in first.size():
		if first[i] > 0: positive = i; break
	var cell := Vector2i(positive%32,positive/32)
	renderer.paint_planting(Vector2i.ZERO,Rect2i(cell,Vector2i.ONE))
	check(signature(renderer)[positive] == 0, "later positive care erases existing preview cell")
	renderer.paint_rect(Rect2i(cell,Vector2i.ONE),6,1.0)
	check(signature(renderer)[positive] == 0, "replacing care with floor does not revive stale preview")
	for index in [4,2,3,7,8,9,13]:
		renderer.set_chunk_base(Vector2i.ZERO,index)
		paint(renderer,Vector2i.ZERO,[spec()])
		check(zeros(signature(renderer)), "semantic material control remains zero: " + str(index))
	renderer.set_chunk_base(Vector2i.ZERO,6)
	renderer.paint_planting(Vector2i.ZERO,Rect2i(0,0,32,32))
	var care_bytes: PackedByteArray = renderer.care_signature(Vector2i.ZERO)
	paint(renderer,Vector2i.ZERO,[spec()])
	check(zeros(signature(renderer)) and renderer.care_signature(Vector2i.ZERO) == care_bytes, "real care bytes veto support without changing care")
	renderer.set_chunk_base(Vector2i.ZERO,6)
	paint(renderer,Vector2i.ZERO,[spec()])
	renderer.set_chunk_base(Vector2i(8,0),6)
	check(zeros(signature(renderer)), "wrapped replacement clears previous target occupant")
	renderer.set_chunk_base(Vector2i.ZERO,6)
	paint(renderer,Vector2i.ZERO,[spec()])
	check(signature(renderer) == first, "reload rebuilds deterministic bytes")
	renderer.clear()
	check(zeros(signature(renderer)), "world clear erases presentation bytes")
	renderer.set_chunk_base(Vector2i.ZERO,6)
	paint(renderer,Vector2i.ZERO,[spec()])
	material.set_shader_parameter("world_tint",Color(0.7,0.8,0.9))
	material.set_shader_parameter("warp_cells",0.41)
	material.set_shader_parameter("debug_view",2)
	var params := {}
	for uniform: Dictionary in original.get_shader_uniform_list():
		params[uniform.name] = material.get_shader_parameter(uniform.name)
	check(not renderer.call("configure_yard_support_preview",false,Vector2i.ZERO,944996572), "explicit disable returns inactive")
	check(material.shader == original and zeros(signature(renderer)), "disable restores exact base object and clears bytes")
	var shared_equal := true
	for key in params:
		shared_equal = shared_equal and material.get_shader_parameter(key) == params[key]
	check(shared_equal, "disable preserves every shared shader parameter")
	check(renderer.call("configure_yard_support_preview",true,Vector2i(-2,3),944996572), "explicit negative target activates")
	renderer.set_chunk_base(Vector2i(-2,3),6)
	paint(renderer,Vector2i(-2,3),[spec()])
	check(not zeros(signature(renderer,Vector2i(-2,3))), "negative coordinate maps to independent wrapped bytes")
	renderer.set_ground_family(&"canal_services")
	check(material.shader != original, "second permitted S7 family activates")
	renderer.set_ground_policy({"enabled":true,"family":&"other"})
	check(material.shader == original and zeros(signature(renderer,Vector2i(-2,3))), "unsupported policy restores base and clears stale support")
	renderer.set_ground_family(&"underpass_veins")
	check(material.shader != original, "request survives policy deactivation")
	check(not renderer.call("configure_yard_support_preview",true,Vector2i(1000001,0),944996572) and material.shader == original, "direct API rejects out-of-bounds target")
	_test_factory(original)

func _test_factory(original: Shader) -> void:
	var factory: GDScript = load("res://core/systems/world/ground/YardSupportPreviewShader.gd")
	var original_code := original.code
	var preview: Shader = factory.call("build",original)
	check(preview != null and preview != original and original.code == original_code, "factory creates separate resource without mutating original source")
	check(preview.code.contains("yard_support_amount(p)") and preview.code.contains("debug_view == 3"), "preview source binds unwarped cell field and debug mask")
	var care_start := original_code.find("\t\t\t\t\tif (light.b > 0.001) {")
	var care_end := original_code.find("\n\t\t\t\t}\n\t\t\t}",care_start)
	check(care_start >= 0 and preview.code.contains(original_code.substr(care_start,care_end-care_start)), "current care-rendering block is byte-for-byte preserved")
	for needle in ["uniform sampler2D light_map : filter_linear, repeat_enable;", "void fragment() {", "float inside = 0.5 - yard_patch.y * 0.25 - field;", "if (inside > -soft - 0.03) {", "float amount = smoothstep(-soft, soft, inside);", "} else if (debug_view == 2) {"]:
		var unsupported := Shader.new()
		unsupported.code = original_code.replace(needle,needle + "\n" + needle)
		check(factory.call("build",unsupported) == null, "duplicate source hook fails closed: " + needle)
		unsupported.code = original_code.replace(needle,"")
		check(factory.call("build",unsupported) == null, "missing source hook fails closed: " + needle)
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../generated-yard-support.gdshader"),FileAccess.WRITE)
	file.store_string(preview.code)
