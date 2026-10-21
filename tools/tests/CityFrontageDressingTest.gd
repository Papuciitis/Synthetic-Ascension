extends Node
## Street dressing, household gardens and corner trees for ordinary city
## buildings in every segment: original assets at measured anchors, props on
## the building's own blocked wall strip, doorways and windows clear, no
## collision, no generator/global RNG, exact regeneration, and every use and
## district family receiving its own valid vocabulary. Real generated chunks
## in several segments prove the physical contract on production parcels.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const DRESSING := preload("res://scenes/world/buildings/CityFrontageDressing.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
const FOREGROUND_GROUP := &"foreground_occluders"
const FAMILIES: Array[StringName] = [&"service_courtyards", &"checkpoint_lanes", &"collapsed_ward", &"civilian_cutthrough", &"inner_district_gate", &"industrial_cutthrough", &"ruined_services", &"underpass_veins", &"canal_services", &"rail_yard", &"military_staging", &"outer_wall", &"siege_services", &"gate_district"]
const USAGES: Array[StringName] = [&"row_house", &"shop", &"workshop", &"passage", &"civic"]
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
var _passed := 0
var _failed := 0
var _messages: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		# One report per distinct failure keeps sweeps readable.
		if not _messages.has(message):
			_messages[message] = true
			push_error("FAIL: " + message)


func _run() -> void:
	var previous_segment := Global.attempt_segment
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	_test_assets()
	_test_pure_plan()
	_test_care_fixtures()
	await _test_synthetic_kits()
	for sample: Dictionary in [
		{"segment": 2, "theme": &"service_courtyards"},
		{"segment": 3, "theme": &"checkpoint_lanes"},
		{"segment": 4, "theme": &"civilian_cutthrough"},
		{"segment": 6, "theme": &"industrial_cutthrough"},
		{"segment": 8, "theme": &"military_staging"},
		{"segment": 9, "theme": &"siege_services"},
	]:
		await _test_generated(sample)
	player.free()
	Global.attempt_segment = previous_segment
	print("CityFrontageDressingTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _test_assets() -> void:
	for prop: StringName in DRESSING.PROPS:
		var spec: Dictionary = DRESSING.PROPS[prop]
		var path := DRESSING.ROOT + String(spec.file)
		var texture := DRESSING._texture(path)
		_check(texture != null, "original dressing art loads: " + path)
		if texture == null: continue
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var rect: Rect2 = spec.rect
		_check(Rect2(Vector2.ZERO, texture.get_size()).encloses(rect), "measured opaque rect lies inside %s" % prop)
		# The front ground contact is the measured opaque bottom-centre.
		var bottom := int(rect.end.y)
		var opaque_below := false
		for y in range(mini(bottom + 3, image.get_height()), image.get_height()):
			for x in range(int(rect.position.x), int(rect.end.x), 2):
				if image.get_pixel(x, y).a > 0.5: opaque_below = true
		_check(not opaque_below, "no opaque art hangs below the measured contact of %s" % prop)
		var size := DRESSING.prop_size(prop)
		_check(size.x >= 18.0 and size.x <= 156.0 and size.y >= 15.0 and size.y <= 152.0, "%s keeps human street scale (%s)" % [prop, size])
	for prop: StringName in [&"barrels_group", &"bench_stone", &"crates_stack"]:
		_check(absf(DRESSING.prop_size(prop).x - {&"barrels_group": 56.0, &"bench_stone": 90.0, &"crates_stack": 70.0}[prop]) < 0.5, "%s width matches the brief" % prop)
	_check(absf(DRESSING.prop_size(&"lamp_post").y - 110.0) < 0.5 and absf(DRESSING.prop_size(&"cypress_tree").y - 150.0) < 0.5, "lamp post and cypress heights match the brief")
	for usage: StringName in USAGES:
		var pools: Dictionary = DRESSING.POOLS[usage]
		for kind: String in ["flank", "front", "rear"]:
			for template: Array in pools[kind]:
				for prop: StringName in template:
					_check(DRESSING.PROPS.has(prop), "%s %s vocabulary names a real prop %s" % [usage, kind, prop])
	for family: StringName in FAMILIES:
		_check(DRESSING.FAMILY_POOLS.has(family) and DRESSING.FAMILY_WEIGHT.has(family), "district %s has its own working props" % family)
	for prop: StringName in [&"rubble_pile", &"scaffold_crates"]:
		for family: StringName in [&"collapsed_ward", &"ruined_services", &"siege_services"]:
			_check(_pool_has(DRESSING.FAMILY_POOLS[family], prop), "ruined district %s carries %s" % [family, prop])
	for family: StringName in [&"military_staging", &"rail_yard"]:
		for prop: StringName in [&"crates_stack", &"sacks_pile", &"handcart"]:
			_check(_pool_has(DRESSING.FAMILY_POOLS[family], prop), "%s carries %s" % [family, prop])
	for family: StringName in [&"canal_services", &"underpass_veins"]:
		for prop: StringName in [&"barrels_group", &"crates_stack", &"bollard_pair"]:
			_check(_pool_has(DRESSING.FAMILY_POOLS[family], prop), "%s carries %s" % [family, prop])


func _pool_has(pool: Array, prop: StringName) -> bool:
	for template: Array in pool:
		if template.has(prop): return true
	return false


func _run_spec(usage: StringName, seed_value: int, door: bool, width: float = 544.0) -> Dictionary:
	var doors: Array[Rect2] = []
	if door:
		var center := 80.0 + width * 0.5
		doors.append(Rect2(center - 64.0, 1024.0, 128.0, 64.0))
	var openings: Array[Rect2] = []
	var keep_clear: Array[Vector2] = []
	var run := {"x0": 80.0, "x1": 80.0 + width, "ground_y": 1088.0, "doors": doors, "openings": openings, "keep_clear": keep_clear}
	var home := usage == &"row_house"
	return {"runs": [run], "usage": usage, "home": home, "civic": usage == &"civic", "family": &"", "seed": seed_value, "variant": absi(seed_value) % 4 if home else -1}


func _test_pure_plan() -> void:
	var spec := _run_spec(&"shop", 77, true)
	var before := var_to_str(spec)
	var run_state := Global._rng.state
	seed(20261021)
	var expected := randi()
	seed(20261021)
	var layout := DRESSING.plan(spec)
	_check(randi() == expected and Global._rng.state == run_state, "planning consumes neither engine-global nor run-owned RNG")
	_check(var_to_str(spec) == before, "planning does not mutate its building description")
	_check(var_to_str(layout) == var_to_str(DRESSING.plan(spec)), "planning is deterministic")
	# Untended homes (variant 3) stay bare; tended variants own a garden.
	for variant in 4:
		var home := _run_spec(&"row_house", 400 + variant, true)
		var plan := DRESSING.plan(home)
		if variant == DRESSING.GARDEN_UNTENDED:
			_check((plan.props as Array).is_empty() and (plan.garden as Dictionary).is_empty() and (plan.tree as Dictionary).is_empty(), "untended household stays bare")
		else:
			_check((plan.garden as Dictionary).get("contact") is Vector2, "tended household variant %d owns a garden contact" % variant)
		if variant == DRESSING.GARDEN_FRUIT_TREE:
			_check(not (plan.tree as Dictionary).is_empty() and plan.tree.kind == &"fruit", "fruit-tree household keeps its fruit tree")
	# Civic halls with a street door get a matched door pair when room allows.
	var civic := DRESSING.plan(_run_spec(&"civic", 5, true, 700.0))
	var flanks := (civic.props as Array).filter(func(record: Dictionary) -> bool: return record.role == &"flank")
	_check(flanks.size() == 2 and flanks[0].prop == flanks[1].prop, "a civic street door is flanked by a matched pair")
	# The reviewed S3 guard loggia keeps its own accepted frontage untouched.
	var guard := KIT.new()
	add_child(guard)
	guard.set("bounds", Rect2(256, 384, 640, 512))
	guard.set("_district_profile", {"profile_id": &"checkpoint_guard_loggia", "visual_seed": 7})
	guard.set("civic", true)
	var children := guard.get_child_count()
	DRESSING.compose(guard)
	_check(guard.get_child_count() == children, "the S3 guard loggia receives no street dressing")
	guard.free()
	# Narrow fronts degrade gracefully instead of overlapping.
	for width: float in [40.0, 96.0, 180.0, 260.0]:
		for usage: StringName in USAGES:
			for seed_value in range(6):
				var narrow := DRESSING.plan(_run_spec(usage, seed_value, width >= 180.0, width))
				_check_layout_spacing(narrow.props, "narrow %s %d" % [usage, int(width)])


func _check_layout_spacing(props: Array, tag: String) -> void:
	var spans: Array[Vector2] = []
	for record: Dictionary in props:
		var span: Vector2 = record.span
		if record.prop == &"pots_cluster" and record.role == &"garden": continue
		if record.prop == &"wattle_fence": continue
		for other: Vector2 in spans:
			_check(minf(span.y, other.y) - maxf(span.x, other.x) <= 6.5, tag + " groups do not pile into each other")
		spans.append(span)


## Real CityBlockKit instances for every use, door side, family and segment.
func _test_synthetic_kits() -> void:
	var census: Dictionary = {}
	var families: Array[StringName] = [&""]
	families.append_array(FAMILIES)
	var segments: Array[int] = [2, 3, 7, 11]
	var combination := 0
	for family: StringName in families:
		for usage: StringName in USAGES:
			for direction: Vector2i in DIRECTIONS:
				for seed_value: int in [11, 26, 403, 1001]:
					combination += 1
					var segment := segments[combination % segments.size()]
					Global.attempt_segment = segment
					var visual_seed := seed_value * 7919 + segment * 131 + families.find(family) * 17 + USAGES.find(usage)
					var first := _kit(Rect2i(4, 6, 10, 8), direction, usage, family, visual_seed)
					var again := _kit(Rect2i(4, 6, 10, 8), direction, usage, family, visual_seed)
					_check(_signature(first) == _signature(again), "same seed regenerates the same dressing")
					_check_kit(first, "seg%d %s %s %s" % [segment, family, usage, direction])
					for node: Node in first.find_children("*", "Sprite2D", true, false):
						if not node.has_meta(&"city_dressing_prop"): continue
						var key := String(family) + ":" + String(usage)
						if not census.has(key): census[key] = {}
						(census[key] as Dictionary)[node.get_meta(&"city_dressing_prop")] = true
					first.get_parent().free()
					again.get_parent().free()
		await get_tree().process_frame
	for family: StringName in families:
		for usage: StringName in USAGES:
			var seen: Dictionary = census.get(String(family) + ":" + String(usage), {})
			_check(not seen.is_empty(), "%s %s receives dressing" % [family, usage])
			for prop: StringName in seen:
				_check(DRESSING.PROPS.has(prop), "%s %s uses a valid prop" % [family, usage])
	for family: StringName in FAMILIES:
		var own: Dictionary = {}
		for usage: StringName in USAGES:
			own.merge(census.get(String(family) + ":" + String(usage), {}))
		var shown := 0
		for template: Array in DRESSING.FAMILY_POOLS[family]:
			if own.has(template[0]): shown += 1
		_check(shown >= 1, "district %s shows its own vocabulary on real kits" % family)
	print("CityFrontageDressingTest census: ", JSON.stringify(_census_text(census)))
	# Chunk-build budget: describing, planning and building one frontage.
	Global.attempt_segment = 4
	var sample := _kit(Rect2i(4, 6, 12, 8), Vector2i.DOWN, &"civic", &"civilian_cutthrough", 4242)
	var started := Time.get_ticks_usec()
	var spec: Dictionary
	for _repeat in 40:
		spec = DRESSING.spec_for(sample)
	var spec_us := float(Time.get_ticks_usec() - started) / 40.0
	started = Time.get_ticks_usec()
	for _repeat in 40:
		var layout := DRESSING.plan(spec)
		_check(not (layout.props as Array).is_empty(), "timing sample keeps a dressed frontage")
	var plan_us := spec_us + float(Time.get_ticks_usec() - started) / 40.0
	started = Time.get_ticks_usec()
	for _repeat in 20:
		var host := Node2D.new()
		add_child(host)
		var kit := KIT.new()
		host.add_child(kit)
		kit.configure(Rect2i(4, 6, 12, 8), 64, [{"pos": Vector2i(10, 13), "dir": Vector2i.DOWN, "width": 2}], null, true, PackedVector2Array(), true, {"building_usage": &"workshop", "visual_seed": 4242, "family_id": &"civilian_cutthrough"})
		host.free()
	var kit_us := float(Time.get_ticks_usec() - started) / 20.0
	sample.get_parent().free()
	_check(plan_us < 2000.0, "one frontage plan stays well inside the chunk-build budget (%.0f us)" % plan_us)
	print("CityFrontageDressingTest timing: spec %.0f us + plan %.0f us per building; full kit configure incl. facade and dressing %.0f us" % [spec_us, plan_us - spec_us, kit_us])


func _census_text(census: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in census:
		var props: Array = (census[key] as Dictionary).keys()
		props.sort()
		out[key] = ",".join(props.map(func(prop: StringName) -> String: return String(prop)))
	return out


func _kit(rect: Rect2i, direction: Vector2i, usage: StringName, family: StringName, visual_seed: int) -> Node2D:
	var host := Node2D.new()
	host.position = Vector2(-4096, 6144)
	add_child(host)
	var door_pos := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
	match direction:
		Vector2i.UP: door_pos = Vector2i(rect.position.x + rect.size.x / 2, rect.position.y)
		Vector2i.LEFT: door_pos = Vector2i(rect.position.x, rect.position.y + rect.size.y / 2)
		Vector2i.RIGHT: door_pos = Vector2i(rect.end.x - 1, rect.position.y + rect.size.y / 2)
	var doors: Array = [{"pos": door_pos, "dir": direction, "width": 2}]
	var roof := ROOF.instantiate() as RoofOverlay
	host.add_child(roof)
	roof.configure(rect, 64, direction, null, &"row_house" if usage == &"civic" else usage, visual_seed, doors)
	var kit := KIT.new()
	host.add_child(kit)
	var global_seed_before := Global._rng.state
	seed(424242)
	var expected := randi()
	seed(424242)
	kit.configure(rect, 64, doors, roof, usage == &"civic", PackedVector2Array(), true, {"building_usage": &"workshop" if usage == &"civic" else usage, "visual_seed": visual_seed, "family_id": family})
	_check(randi() == expected and Global._rng.state == global_seed_before, "configuring street dressing consumes no global or run RNG")
	return kit


func _signature(kit: Node2D) -> String:
	var parts: Array[String] = []
	for node: Node in kit.find_children("*", "", true, false):
		if node is Sprite2D and (node.has_meta(&"city_dressing_prop") or node.name == &"CityTemperateTree"):
			parts.append("%s@%s*%s" % [node.get_meta(&"city_dressing_prop", node.name), (node as Sprite2D).position, (node as Sprite2D).scale])
		if node is Polygon2D and node.has_meta(&"city_sun_shadow") and (node as Polygon2D).texture != null:
			parts.append("shadow:%s" % (node as Polygon2D).polygon)
		if node.has_meta(&"city_garden_contact"):
			parts.append("garden:%s" % node.get_meta(&"city_garden_contact"))
	return "|".join(parts)


func _check_kit(kit: Node2D, tag: String) -> void:
	var bounds: Rect2 = kit.get("bounds")
	var spec := DRESSING.spec_for(kit)
	_check(kit.find_children("*", "CollisionObject2D", true, false).is_empty(), tag + " adds no collision")
	var ground_y := bounds.end.y
	var doors: Array[Rect2] = []
	for door: Dictionary in kit.get("_doors"):
		if door.dir == Vector2i.DOWN: doors.append(COMPOSER.door_box(door, 64))
	var home := spec.home as bool
	var variant := int(spec.variant)
	var garden := kit.get_node_or_null("DomesticGarden") as Node2D
	var dressing := kit.get_node_or_null("FrontageDressing") as Node2D
	if home and variant == DRESSING.GARDEN_UNTENDED:
		_check(garden == null and dressing == null and kit.get_node_or_null("CityTemperateTree") == null, tag + " untended household stays bare")
	if garden != null:
		_check(home and variant != DRESSING.GARDEN_UNTENDED, tag + " gardens belong only to tended households")
		var contact: Variant = garden.get_meta(&"city_garden_contact", null)
		_check(contact is Vector2, tag + " garden root carries its kit-local ground contact")
		var marker := garden.get_node_or_null("GardenContact")
		_check(marker != null and marker.get_meta(&"city_garden_contact", null) == contact, tag + " garden root keeps a child with the same contact")
		if contact is Vector2:
			_check((contact as Vector2).y >= ground_y - DRESSING.STRIP_PX - 6.0 and (contact as Vector2).y <= ground_y and bounds.grow(1).has_point(contact), tag + " garden contact sits on the household's own wall foot")
		var roof := kit.get("_roof") as RoofOverlay
		roof._set_alpha(0.0)
		_check(is_equal_approx(garden.modulate.a, 1.0), tag + " outdoor garden does not fade with the interior roof")
		roof._set_alpha(1.0)
	elif home and variant in [DRESSING.GARDEN_BED, DRESSING.GARDEN_FENCED]:
		# Only a facade too short for any plot may leave a tended home plain.
		_check(false, tag + " tended household variant %d places its garden" % variant)
	var tree := kit.get_node_or_null("CityTemperateTree") as Sprite2D
	if home and variant == DRESSING.GARDEN_FRUIT_TREE:
		_check(tree != null and tree.texture != null and tree.texture.resource_path == DRESSING.FRUIT_TREE, tag + " fruit-tree household keeps its fruit tree")
	if tree != null:
		var root: Vector2 = tree.get_meta(&"city_ground_contact")
		_check(tree.is_in_group(FOREGROUND_GROUP) and is_equal_approx(root.y, ground_y - 21.0) and (is_equal_approx(root.x, bounds.position.x + 8.0) or is_equal_approx(root.x, bounds.end.x - 8.0)), tag + " tree root stands on a blocked corner and covers actors behind it")
		var source := DRESSING.FRUIT_TREE_ROOT if tree.texture.resource_path == DRESSING.FRUIT_TREE else DRESSING.TEMPERATE_TREE_ROOT
		_check(tree.to_global(source - tree.texture.get_size() * 0.5).is_equal_approx(kit.to_global(root)), tag + " tree uses its measured root anchor")
		if tree.texture.resource_path == DRESSING.FRUIT_TREE:
			_check(tree.scale.is_equal_approx(Vector2.ONE * DRESSING.FRUIT_TREE_SCALE), tag + " fruit tree keeps its measured scale")
	var tall := 0
	for node: Node in kit.find_children("*", "Sprite2D", true, false):
		if not node.has_meta(&"city_dressing_prop"): continue
		var sprite := node as Sprite2D
		var prop: StringName = sprite.get_meta(&"city_dressing_prop")
		var source: Rect2 = DRESSING.PROPS[prop].rect
		var half := sprite.texture.get_size() * 0.5
		var left := sprite.position + (source.position - half) * sprite.scale
		var right := sprite.position + (source.end - half) * sprite.scale
		var contact: Vector2 = sprite.get_meta(&"city_dressing_contact")
		_check(sprite.scale.x > 0.0 and sprite.scale.is_equal_approx(Vector2.ONE * sprite.scale.x), tag + " %s keeps its painted light (no mirroring, uniform scale)" % prop)
		_check(is_equal_approx(right.y, contact.y) and contact.y >= ground_y - DRESSING.STRIP_PX and contact.y < ground_y, tag + " %s front contact stands on the blocked wall strip" % prop)
		_check(left.x >= bounds.position.x + 15.0 and right.x <= bounds.end.x - 15.0, tag + " %s stays in front of its own facade" % prop)
		for gap: Rect2 in doors:
			_check(right.x <= gap.position.x - DRESSING.DOOR_CLEAR_PX + 0.5 or left.x >= gap.end.x + DRESSING.DOOR_CLEAR_PX - 0.5, tag + " %s keeps the doorway and its frame clear" % prop)
		_check(sprite.is_in_group(FOREGROUND_GROUP) == DRESSING.is_tall(prop), tag + " only tall %s registers as foreground cover" % prop)
		if DRESSING.is_tall(prop): tall += 1
		_check(sprite.z_index + kit.z_index + (sprite.get_parent() as Node2D).z_index == -1, tag + " props draw with the kit trees, under every actor")
	_check(tall <= (2 if bool(kit.get("civic")) else 1), tag + " tall props stay sparse")
	for node: Node in kit.get_children():
		if node is Polygon2D and node.has_meta(&"city_dressing_shadow"):
			var shade := node as Polygon2D
			_check(shade.texture != null and shade.has_meta(&"shadow_uv_transform") and shade.has_meta(&"shadow_uv_offset") and shade.z_index == -90, tag + " prop shadows follow the trimmable kit-tree shadow contract")
			_check(not shade.is_in_group(FOREGROUND_GROUP), tag + " shadows never enter foreground cover")
	# Hand-drawn civic services stay only where the facade has none of its own.
	if bool(kit.get("civic")):
		var south := not doors.is_empty()
		_check(bool(kit.call("_draws_services")) == (not south), tag + " drawn pipe/cabinet only on closed civic bays")


## Production chunks: dressing on actual parcels stays on blocked wall cells.
func _test_generated(sample: Dictionary) -> void:
	var segment: int = sample.segment
	Global.attempt_segment = segment
	var seed_value := 16102026
	for step in 400:
		if SegmentThemePicker.get_theme(segment, seed_value + step).id == sample.theme:
			seed_value += step
			break
	var theme := SegmentThemePicker.get_theme(segment, seed_value)
	_check(theme.id == sample.theme, "seed scan finds %s" % sample.theme)
	var plan := DistrictPlan.generate(segment, seed_value, 2048, theme)
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	add_child(manager)
	manager.set_process(false)
	manager.configure_procedural_world(int(plan.seed), plan.connectors_by_chunk, plan.urban_access_by_chunk, plan.role_by_chunk, plan.terrain_by_chunk, plan.archetype_by_chunk)
	var coords: Array = plan.role_by_chunk.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	var kits := 0
	var dressed := 0
	var gardens := 0
	var props := 0
	var visited := 0
	var examples: Array[String] = []
	for coord: Vector2i in coords:
		if not (plan.role_by_chunk[coord] in [&"district_fill", &"service_lane", &"secondary_route", &"main_route", &"dangerous_alley", &"secondary_reward_building"]): continue
		if visited >= 6: break
		visited += 1
		var chunk := manager._create_chunk(coord)
		manager._chunks[coord] = chunk
		var data := manager.get_chunk_build_data(coord)
		var signature := ""
		for kit: Node in chunk.get_children():
			if not kit.is_in_group(&"city_block_building"): continue
			kits += 1
			if kit.get_node_or_null("FrontageDressing") != null or kit.get_node_or_null("DomesticGarden") != null: dressed += 1
			if kit.get_node_or_null("DomesticGarden") != null: gardens += 1
			for node: Node in kit.find_children("*", "Sprite2D", true, false):
				if not node.has_meta(&"city_dressing_prop"): continue
				props += 1
				var sprite := node as Sprite2D
				var source: Rect2 = DRESSING.PROPS[sprite.get_meta(&"city_dressing_prop")].rect
				var half := sprite.texture.get_size() * 0.5
				var left := (kit as Node2D).position + sprite.position + (source.position - half) * sprite.scale
				var right := (kit as Node2D).position + sprite.position + (source.end - half) * sprite.scale
				# Every cell under the prop's front contact line is a real blocker,
				# so no actor can ever stand inside the dressing.
				var blocked := true
				for x in range(int(floor((left.x + 1.0) / 64.0)), int(floor((right.x - 1.0) / 64.0)) + 1):
					var cell := Vector2i(x, int(floor((right.y - 1.0) / 64.0)))
					blocked = blocked and data.kind_at(cell) >= 0 and not manager.is_cell_walkable(coord * 32 + cell)
				_check(blocked, "seg%d %s dressing stands only on blocked wall cells" % [segment, sample.theme])
			signature += DRESSING.spec_for(kit).get("usage", &"") + _signature(kit)
			if examples.size() < 6 and (kit.get_node_or_null("FrontageDressing") != null or kit.get_node_or_null("DomesticGarden") != null):
				examples.append("seed=%d chunk=%d,%d id=%d usage=%s civic=%s doors=%s props=%s" % [seed_value, coord.x, coord.y, _building_id(kit), kit.get_meta(&"building_usage", &""), kit.get("civic"), str((kit.get("_doors") as Array).map(func(door: Dictionary) -> Vector2i: return door.dir)), str(kit.find_children("Dressing*", "Sprite2D", true, false).map(func(node: Node) -> String: return String(node.get_meta(&"city_dressing_prop"))))])
		# Streaming the same chunk again rebuilds the same street.
		manager._unregister_chunk_cells(coord)
		manager._chunks.erase(coord)
		chunk.free()
		var again := manager._create_chunk(coord)
		manager._chunks[coord] = again
		var repeat := ""
		for kit: Node in again.get_children():
			if kit.is_in_group(&"city_block_building"):
				repeat += DRESSING.spec_for(kit).get("usage", &"") + _signature(kit)
		_check(repeat == signature, "seg%d %s streamed chunk regenerates identical dressing" % [segment, sample.theme])
		manager._unregister_chunk_cells(coord)
		manager._chunks.erase(coord)
		again.free()
		await get_tree().process_frame
	_check(kits == 0 or dressed > 0, "seg%d %s actual buildings receive street life" % [segment, sample.theme])
	print("CityFrontageDressingTest generated: seg%d %s kits=%d dressed=%d gardens=%d props=%d" % [segment, sample.theme, kits, dressed, gardens, props])
	for example: String in examples:
		print("CityFrontageDressingTest example: seg%d %s %s" % [segment, sample.theme, example])
	manager.free()


func _building_id(kit: Node) -> int:
	var roof := kit.get("_roof") as RoofOverlay
	for child: Node in kit.get_parent().get_children():
		if not child is IndoorVolume: continue
		for connection: Dictionary in child.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof:
				return (child as IndoorVolume).building_id
	return 0


## The two reviewed S2 households as CityGroundCareTest builds them: their
## garden contact (consumed by household lawn care) is reported for that suite
## and must stand on the home's own wall foot or corner.
func _test_care_fixtures() -> void:
	Global.attempt_segment = 2
	for fixture: Dictionary in [
		{"footprint": PackedVector2Array([Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]), "doors": [{"pos":Vector2i(8,16),"dir":Vector2i.DOWN,"width":2}], "seed": 944996572, "variant": 0},
		{"footprint": PackedVector2Array([Vector2(192,960),Vector2(960,960),Vector2(960,1472),Vector2(192,1472)]), "doors": [{"pos":Vector2i(9,15),"dir":Vector2i.UP,"width":2}], "seed": 2128236757, "variant": 1},
	]:
		var outline: PackedVector2Array = fixture.footprint
		var roof := ROOF.instantiate() as RoofOverlay
		add_child(roof)
		var rect := Rect2(outline[0], Vector2.ZERO)
		for point: Vector2 in outline: rect = rect.expand(point)
		roof.configure_polygon(outline, outline[-2], outline[-1], [], &"row_house", int(fixture.seed), fixture.doors, 64)
		var kit := KIT.new()
		add_child(kit)
		kit.configure(Rect2i(Vector2i(rect.position / 64), Vector2i(rect.size / 64)), 64, fixture.doors, roof, false, outline, true, {"building_usage": &"row_house", "visual_seed": fixture.seed})
		var garden := kit.get_node_or_null("DomesticGarden") as Node2D
		_check(garden != null and int(garden.get_meta(&"city_domestic_garden", -1)) == int(fixture.variant), "reviewed household %d keeps its garden variant" % fixture.seed)
		if garden != null:
			var contact: Vector2 = garden.get_meta(&"city_garden_contact")
			_check(rect.has_point(contact) and contact.y >= rect.end.y - 21.5, "reviewed household %d garden contact stands on its own wall foot" % fixture.seed)
			print("CityFrontageDressingTest care contact: seed=%d variant=%d contact=%s" % [fixture.seed, fixture.variant, contact])
		kit.free()
		roof.free()
