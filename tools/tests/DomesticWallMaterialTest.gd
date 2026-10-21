extends Node
## Mixed batches prove envelope/partition/window/fill ownership, not just a flag.

const ADAPTER_PATH := "res://scenes/world/buildings/CityDomesticInterior.gd"
const CITY_SHADER := "res://scenes/world/buildings/city_stone.gdshader"
const DOMESTIC_SHADER := "res://scenes/world/buildings/domestic_stone.gdshader"
var _adapter: GDScript
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


func _run() -> void:
	_check(ResourceLoader.exists(ADAPTER_PATH),"Domestic masonry needs explicit building-use ownership before batch rendering")
	if not ResourceLoader.exists(ADAPTER_PATH):
		_finish()
		return
	_adapter = load(ADAPTER_PATH) as GDScript
	var methods: Array[StringName] = []
	for method: Dictionary in _adapter.get_script_method_list():
		methods.append(StringName(method.name))
	_check(methods.has(&"mark_walls"),"Domestic adapter marks the actual wall dictionary")
	if not methods.has(&"mark_walls"):
		_finish()
		return
	var domestic := _wall_fixture(Vector2i.ZERO)
	var civic := _wall_fixture(Vector2i(1,0))
	var cells := {Vector2i(1,1):true,Vector2i(2,1):true,Vector2i(1,2):true,Vector2i(2,2):true}
	var original_kinds := domestic.blocker_kind_code.duplicate()
	var original_masks := domestic.blocker_mask.duplicate()
	var original_variants := domestic.blocker_variant.duplicate()
	var context := {"segment":2,"usage":&"row_house","civic":false,"building_id":944996572,"visual_seed":944996572,"roof_material":&"clay"}
	_adapter.call("mark_walls",domestic,cells,context)
	_check(domestic.blocker_kind_code == original_kinds and domestic.blocker_mask == original_masks,"Domestic material changes no physical wall/window cells or connection masks")
	for cell: Vector2i in cells:
		var index := domestic._index(cell)
		_check((domestic.variant_at(cell)&int(original_variants[index])) == int(original_variants[index]),"Domestic material preserves under-roof, city and intact-envelope flags")
		_check(domestic.variant_at(cell) != int(original_variants[index]),"Both actual perimeter and partition cells receive explicit domestic presentation ownership")
	var civic_before := civic.blocker_variant.duplicate()
	var excluded := context.duplicate()
	excluded.civic = true
	_adapter.call("mark_walls",civic,cells,excluded)
	_check(civic.blocker_variant == civic_before,"Civic/security building-use exclusion keeps reviewed city/S3 treatment")
	var reward_sensitive := _wall_fixture(Vector2i(2,0))
	var sensitive_context := context.duplicate()
	sensitive_context.small_count_max = 2
	_adapter.call("mark_walls",reward_sensitive,cells,sensitive_context)
	_check(reward_sensitive.blocker_variant != civic_before,"Multi-item household can retain domestic wall presentation while furnishing is excluded")
	var authored := _wall_fixture(Vector2i(2,0))
	var authored_before := authored.blocker_variant.duplicate()
	excluded = context.duplicate()
	excluded.segment = 1
	_adapter.call("mark_walls",authored,cells,excluded)
	_check(authored.blocker_variant == authored_before,"The authored S1 Institution retains its own material ownership")
	# Warm cutaway walls: every ordinary home in every city segment, whatever
	# its roof (the reviewed slate-roofed S2 bed home keeps its lived-in rubble
	# instead of the pale placeholder relief), and every other clay-roofed
	# (warm plaster) non-civic building. Slate working buildings keep city stone.
	for segment: int in [2,3,4,7,10,11]:
		for usage: StringName in [&"row_house",&"workshop",&"shop",&"passage"]:
			for roof: StringName in [&"clay",&"slate"]:
				var marked_fixture := _wall_fixture(Vector2i(2,0))
				var before := marked_fixture.blocker_variant.duplicate()
				var roof_context := context.duplicate()
				roof_context.segment = segment
				roof_context.usage = usage
				roof_context.roof_material = roof
				_adapter.call("mark_walls",marked_fixture,cells,roof_context)
				_check(marked_fixture.blocker_kind_code == authored.blocker_kind_code and marked_fixture.blocker_mask == authored.blocker_mask,"Cutaway material changes no physical cell in S%d %s %s" % [segment,usage,roof])
				var warm := usage == &"row_house" or roof == &"clay"
				if not warm:
					_check(marked_fixture.blocker_variant == before,"Slate-roofed (pale ashlar) S%d %s keeps city stone" % [segment,usage])
					continue
				var marked := true
				for cell: Vector2i in cells:
					var original := int(before[marked_fixture._index(cell)])
					marked = marked and (marked_fixture.variant_at(cell)&ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE) != 0 and (marked_fixture.variant_at(cell)&original) == original
				_check(marked,"%s S%d %s cutaway walls keep warm domestic rubble" % [String(roof).capitalize(),segment,usage])
	var unknown := _wall_fixture(Vector2i(2,0))
	var unknown_before := unknown.blocker_variant.duplicate()
	excluded = context.duplicate()
	excluded.usage = &"workshop"
	excluded.erase("roof_material")
	_adapter.call("mark_walls",unknown,cells,excluded)
	_check(unknown.blocker_variant == unknown_before,"A working building without a known warm frontage keeps city stone")
	# The kit gate that lets every other building skip the context scan agrees
	# with the context rules for homes, warm and pale working fronts and halls.
	var previous_segment := Global.attempt_segment
	for sample: Dictionary in [
		{"segment":3,"usage":&"row_house","civic":false,"roof":&"slate","eligible":true},
		{"segment":7,"usage":&"workshop","civic":false,"roof":&"clay","eligible":true},
		{"segment":2,"usage":&"shop","civic":false,"roof":&"slate","eligible":false},
		{"segment":11,"usage":&"workshop","civic":true,"roof":&"slate","eligible":false},
		{"segment":1,"usage":&"row_house","civic":false,"roof":&"clay","eligible":false},
	]:
		Global.attempt_segment = int(sample.segment)
		var probe: Node2D = preload("res://scenes/world/buildings/CityBlockKit.gd").new()
		probe.set("civic",bool(sample.civic))
		probe.set_meta(&"building_usage",sample.usage)
		probe.set_meta(&"city_roof_material",sample.roof)
		_check(bool(_adapter.call("eligible_kit",probe)) == bool(sample.eligible),"Context gate matches the context rules for S%d %s %s civic=%s" % [sample.segment,sample.roof,sample.usage,sample.civic])
		probe.free()
	Global.attempt_segment = previous_segment
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host,256,64)
	renderer.add_chunk(domestic)
	renderer.add_chunk(civic)
	var domestic_instances := 0
	var civic_instances := 0
	var domestic_fills := 0
	var civic_fills := 0
	for batch: ChunkBlockRenderer.TextureBatch in (renderer.get("_batches") as Dictionary).values():
		var material := batch.visual.material as ShaderMaterial
		_check(material != null and material.shader != null,"Every scoped stone/fill batch retains an explicit material")
		if material == null or material.shader == null:
			continue
		var shader_path := material.shader.resource_path
		for index in batch.owners.size():
			var is_domestic := batch.owners[index] == Vector2i.ZERO
			_check(shader_path == (DOMESTIC_SHADER if is_domestic else CITY_SHADER),"Shared source texture retains the correct per-building stone material")
			if batch.shadowless:
				if is_domestic:
					domestic_fills += 1
				else:
					civic_fills += 1
			else:
				if is_domestic:
					domestic_instances += 1
				else:
					civic_instances += 1
		_check(batch.visual.z_index in [ChunkBlockVisualCatalog.WALL_Z,ChunkBlockVisualCatalog.PROP_Z,ChunkBlockVisualCatalog.FILL_Z],"Domestic material preserves original depth policy")
	_check(domestic_instances == 4 and civic_instances == 4,"Envelope, window and real under-roof partition all render with their own building material")
	_check(domestic_fills > 0 and civic_fills == domestic_fills,"Domestic corner plugs follow their walls while civic plugs retain the original shader")
	renderer.remove_chunk(Vector2i.ZERO)
	for batch: ChunkBlockRenderer.TextureBatch in (renderer.get("_batches") as Dictionary).values():
		_check(not batch.owners.has(Vector2i.ZERO),"Domestic streamed unload retires only its instances")
		var material := batch.visual.material as ShaderMaterial
		_check(material != null and material.shader.resource_path == CITY_SHADER,"Removing the home preserves the neighboring civic/S3 material")
	renderer.clear()
	host.free()
	_finish()


func _wall_fixture(coord: Vector2i) -> ChunkBuildData:
	var data := ChunkBuildData.new(coord,4)
	var envelope := ChunkBlockVisualCatalog.VARIANT_CITY_STONE|ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE
	data.add_blocker(Vector2i(1,1),WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.E|WorldBlockerGeometry.S,envelope)
	data.add_blocker(Vector2i(2,1),WorldBlockerGeometry.Kind.WINDOW,WorldBlockerGeometry.N|WorldBlockerGeometry.S,envelope)
	data.add_blocker(Vector2i(1,2),WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.E|WorldBlockerGeometry.W,envelope|ChunkBlockVisualCatalog.VARIANT_UNDER_ROOF)
	data.add_blocker(Vector2i(2,2),WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.N|WorldBlockerGeometry.W,envelope|ChunkBlockVisualCatalog.VARIANT_UNDER_ROOF)
	return data


func _finish() -> void:
	print("DomesticWallMaterialTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
