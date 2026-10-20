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
	var context := {"segment":2,"usage":&"row_house","civic":false,"building_id":944996572,"visual_seed":944996572}
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
	for segment: int in [1,3]:
		var other_segment := _wall_fixture(Vector2i(2,0))
		var before := other_segment.blocker_variant.duplicate()
		excluded = context.duplicate()
		excluded.segment = segment
		_adapter.call("mark_walls",other_segment,cells,excluded)
		_check(other_segment.blocker_variant == before,"S1 and reviewed S3 architecture retain their existing material ownership")
	for usage: StringName in [&"workshop",&"shop",&"passage"]:
		var nonhome := _wall_fixture(Vector2i(2,0))
		var before := nonhome.blocker_variant.duplicate()
		excluded = context.duplicate()
		excluded.usage = usage
		_adapter.call("mark_walls",nonhome,cells,excluded)
		_check(nonhome.blocker_variant == before,"Noncivic "+String(usage)+" keeps its own masonry")
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
