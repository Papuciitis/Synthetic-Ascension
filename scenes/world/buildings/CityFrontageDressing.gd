extends RefCounted
## Street life at the foot of every ordinary city building's visible south
## wall, in every city segment: small deterministic groups of painted props
## chosen by building use and district family, a tended household garden that
## belongs to its house, and one corner tree where a house or hall owns one.
##
## Presentation only. Nothing here adds collision, blockers, doors, encounters
## or rewards, and nothing draws from a generator, parcel, chunk or global RNG:
## variation comes from the building's stable visual seed with this file's own
## salt, so a streamed chunk regenerates exactly the same street.
##
## Placement contract: every prop's front ground contact stands on the
## building's own blocked wall strip (ground_y - 16 .. ground_y, in front of
## the facade foot), so actors - who can never enter a wall cell - never stand
## inside a prop and always draw in front of it. The doorway, its frame and
## DOOR_CLEAR_PX either side stay clear, props do not hide windows, and goods
## in front of a shopfront stay below its sill. Props are never mirrored: the
## painted light comes from the upper right like the rest of the world.

const ROOT := "res://assets/world/dressing_v2/"
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
## Own hash salt: never shared with parcel (4001) or facade composition seeds.
const SALT := 0x3D57A1
const STRIP_PX := 16.0
const DOOR_CLEAR_PX := 40.0
const CORNER_INSET_PX := 4.0
const GROUP_GAP_PX := 16.0
const MIN_SPAN_PX := 40.0
## A prop may not hide more than this share of a window's width and height.
const WINDOW_COVER_LIMIT := Vector2(0.3, 0.25)
const SHADOW_COLOR := Color(0.06, 0.10, 0.13, 0.25)
## Painted props sit a touch under the actors and the lit wall in value.
const PROP_TINT := Color(0.93, 0.93, 0.90)
const TREE_TINT := Color(1.04, 1.08, 0.99)

## Opaque source rect (alpha > 0.5) of each original painted prop. The front
## ground contact is the bottom-centre of that rect; world size keeps aspect.
const PROPS := {
	&"barrels_group": {"file": "barrels_group.png", "rect": Rect2(4, 4, 503, 490), "width": 56.0},
	&"bench_stone": {"file": "bench_stone.png", "rect": Rect2(3, 2, 506, 122), "width": 90.0},
	&"bollard_pair": {"file": "bollard_pair.png", "rect": Rect2(4, 4, 503, 298), "width": 52.0},
	&"crates_stack": {"file": "crates_stack.png", "rect": Rect2(4, 4, 503, 394), "width": 70.0},
	&"cypress_tree": {"file": "cypress_tree.png", "rect": Rect2(3, 4, 176, 504), "height": 150.0},
	&"garden_bed": {"file": "garden_bed.png", "rect": Rect2(2, 4, 507, 156), "width": 150.0},
	&"handcart": {"file": "handcart.png", "rect": Rect2(3, 3, 504, 326), "width": 82.0},
	&"lamp_post": {"file": "lamp_post.png", "rect": Rect2(3, 3, 91, 505), "height": 110.0},
	&"pots_cluster": {"file": "pots_cluster.png", "rect": Rect2(4, 3, 504, 325), "width": 64.0},
	&"rubble_pile": {"file": "rubble_pile.png", "rect": Rect2(3, 5, 503, 175), "width": 84.0},
	&"sacks_pile": {"file": "sacks_pile.png", "rect": Rect2(4, 3, 503, 334), "width": 60.0},
	&"scaffold_crates": {"file": "scaffold_crates.png", "rect": Rect2(3, 3, 505, 248), "width": 92.0},
	&"table_benches": {"file": "table_benches.png", "rect": Rect2(4, 4, 504, 296), "width": 88.0},
	&"tree_planter": {"file": "tree_planter.png", "rect": Rect2(4, 4, 362, 503), "height": 130.0},
	&"water_trough": {"file": "water_trough.png", "rect": Rect2(3, 3, 505, 177), "width": 92.0},
	&"wattle_fence": {"file": "wattle_fence.png", "rect": Rect2(2, 2, 507, 99), "width": 96.0},
}
## Building-use vocabularies. "flank" stands beside a south doorway, "front"
## fills the rest of a street front, "rear" dresses back and side elevations.
const POOLS := {
	&"row_house": {
		"flank": [[&"pots_cluster"]],
		"front": [[&"bench_stone"], [&"pots_cluster"], [&"water_trough"]],
		"rear": [[&"barrels_group"], [&"water_trough"], [&"bench_stone"]],
	},
	&"shop": {
		"flank": [[&"crates_stack", &"sacks_pile"], [&"barrels_group"], [&"sacks_pile"]],
		"front": [[&"table_benches"], [&"crates_stack"], [&"sacks_pile", &"barrels_group"]],
		"rear": [[&"barrels_group"], [&"crates_stack"], [&"sacks_pile"], [&"barrels_group", &"crates_stack"]],
	},
	&"workshop": {
		"flank": [[&"handcart"], [&"crates_stack"]],
		"front": [[&"scaffold_crates"], [&"crates_stack", &"sacks_pile"], [&"handcart"]],
		"rear": [[&"crates_stack"], [&"sacks_pile"], [&"scaffold_crates"], [&"handcart"]],
	},
	&"passage": {
		"flank": [[&"bollard_pair"]],
		"front": [[&"lamp_post"], [&"bollard_pair"]],
		"rear": [[&"bollard_pair"], [&"lamp_post"]],
	},
	&"civic": {
		"flank": [[&"cypress_tree"], [&"tree_planter"]],
		"front": [[&"lamp_post"], [&"water_trough"], [&"bollard_pair"]],
		"rear": [[&"tree_planter"], [&"water_trough"], [&"bollard_pair"], [&"lamp_post"]],
	},
}
## District identity: each family adds its own working props to any use.
const FAMILY_POOLS := {
	&"service_courtyards": [[&"pots_cluster"], [&"barrels_group"], [&"crates_stack"]],
	&"checkpoint_lanes": [[&"sacks_pile"], [&"crates_stack"], [&"bollard_pair"]],
	&"collapsed_ward": [[&"rubble_pile"], [&"scaffold_crates"], [&"rubble_pile", &"barrels_group"]],
	&"civilian_cutthrough": [[&"pots_cluster"], [&"bench_stone"], [&"table_benches"], [&"bench_stone", &"pots_cluster"]],
	&"inner_district_gate": [[&"bollard_pair"], [&"water_trough"]],
	&"industrial_cutthrough": [[&"crates_stack"], [&"handcart"], [&"barrels_group", &"crates_stack"]],
	&"ruined_services": [[&"rubble_pile"], [&"scaffold_crates"], [&"rubble_pile", &"crates_stack"]],
	&"underpass_veins": [[&"barrels_group"], [&"crates_stack"], [&"bollard_pair"]],
	&"canal_services": [[&"barrels_group"], [&"crates_stack"], [&"bollard_pair"], [&"barrels_group", &"crates_stack"]],
	&"rail_yard": [[&"crates_stack"], [&"sacks_pile"], [&"handcart"], [&"crates_stack", &"sacks_pile"]],
	&"military_staging": [[&"crates_stack"], [&"sacks_pile"], [&"handcart"], [&"sacks_pile", &"crates_stack"]],
	&"outer_wall": [[&"crates_stack"], [&"sacks_pile"], [&"barrels_group"]],
	&"siege_services": [[&"scaffold_crates"], [&"rubble_pile"], [&"scaffold_crates", &"sacks_pile"]],
	&"gate_district": [[&"bollard_pair"], [&"water_trough"]],
}
## Share of shops, workshops and passages that own a corner shade tree.
const SHADE_TREE_SHARE := {
	&"service_courtyards": 0.35, &"civilian_cutthrough": 0.4, &"inner_district_gate": 0.3,
	&"gate_district": 0.3, &"canal_services": 0.3, &"outer_wall": 0.25, &"collapsed_ward": 0.25,
	&"checkpoint_lanes": 0.2, &"ruined_services": 0.2, &"underpass_veins": 0.2,
	&"industrial_cutthrough": 0.15, &"rail_yard": 0.15, &"siege_services": 0.15, &"military_staging": 0.1,
}
## How strongly a family's own props displace the use vocabulary.
const FAMILY_WEIGHT := {
	&"collapsed_ward": 0.55, &"ruined_services": 0.6, &"siege_services": 0.6,
	&"military_staging": 0.65, &"rail_yard": 0.65, &"industrial_cutthrough": 0.5,
	&"canal_services": 0.55, &"underpass_veins": 0.55, &"checkpoint_lanes": 0.45,
	&"outer_wall": 0.45, &"civilian_cutthrough": 0.35, &"service_courtyards": 0.25,
	&"inner_district_gate": 0.35, &"gate_district": 0.35,
}
## Household garden variants (|visual_seed| % 4, shared with household care):
## 0 stone-edged kitchen bed, 1 fruit tree, 2 fenced pot plot, 3 untended.
const GARDEN_BED := 0
const GARDEN_FRUIT_TREE := 1
const GARDEN_FENCED := 2
const GARDEN_UNTENDED := 3
const FRUIT_TREE := "res://assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png"
const FRUIT_TREE_ROOT := Vector2(660, 1060)
const FRUIT_TREE_SCALE := 135.0 / 1167.0
const TEMPERATE_TREE := "res://assets/world/city_block/temperate_tree.png"
const TEMPERATE_TREE_ROOT := Vector2(650, 1170)
const TEMPERATE_TREE_WIDTH := 280.0
## The measured roots stand on the blocked corner cell, as reviewed in S2.
const TREE_ROOT_INSET := Vector2(8.0, 21.0)
const TREE_CLEAR_PX := {&"fruit": 72.0, &"temperate": 96.0}
## How far above its root a corner crown spreads (measured art at kit scale).
const TREE_CROWN_REACH_PX := {&"fruit": 170.0, &"temperate": 300.0}
## Tall props keep this far from a corner tree's trunk.
const TREE_CROWN_PX := 150.0
## Narrowest kitchen bed / fence panel that still reads at gameplay scale.
const BED_MIN_PX := 88.0
const FENCE_MIN_PX := 84.0
## Neighbouring buildings within this distance steer prop choice away from
## repeating the same group on the next facade.
const NEARBY_PX := 1400.0

## Props that lie flat on the ground and so draw beneath the shared shade.
const FLAT_PROPS: Array[StringName] = [&"garden_bed"]

## Props that rise over windows and register as foreground cover.
const TALL: Array[StringName] = [&"cypress_tree", &"lamp_post", &"tree_planter"]

static var _cache: Dictionary = {}
static var _sizes: Dictionary = {}


## Gardens, corner tree and dressing for one configured kit.
static func compose(kit: Node2D) -> void:
	if kit == null or StringName(kit.get("_district_profile").get("profile_id", &"")) == &"checkpoint_guard_loggia":
		return
	var layout := plan(spec_for(kit))
	if not (layout.tree as Dictionary).is_empty():
		_add_tree(kit, layout.tree)
	var garden: Node2D
	var contact: Variant = (layout.garden as Dictionary).get("contact")
	if contact is Vector2:
		garden = Node2D.new()
		garden.name = "DomesticGarden"
		garden.set_meta(&"city_domestic_garden", int(layout.garden.variant))
		garden.set_meta(&"city_garden_contact", contact)
		kit.add_child(garden)
		# Household ground care anchors to this kit-local ground contact.
		var marker := Marker2D.new()
		marker.name = "GardenContact"
		marker.position = contact
		marker.set_meta(&"city_garden_contact", contact)
		garden.add_child(marker)
	var dressing: Node2D = null
	var records: Array = (layout.props as Array).duplicate()
	# Further-back feet draw first; nothing here is y-sorted at runtime.
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _draws_before(a, b))
	for record: Dictionary in records:
		var parent: Node2D = garden
		if record.role != &"garden" or garden == null:
			if dressing == null:
				dressing = Node2D.new()
				dressing.name = "FrontageDressing"
				kit.add_child(dressing)
			parent = dressing
		_add_prop(kit, parent, record)
	if dressing != null:
		dressing.set_meta(&"frontage_dressing_layout", layout.props)
	_reserve_from_wild_scatter(kit, layout)


## Tended gardens and working groups keep wild scatter off their doorstep:
## their wall cells join the chunk's deco-clear set, whose one-cell margin
## keeps ambient shrubs out of the ground row directly in front of them (the
## same opt-in the DonJon compounds use for their deliberate planting).
static func _reserve_from_wild_scatter(kit: Node2D, layout: Dictionary) -> void:
	var chunk := kit.get_parent()
	if chunk == null: return
	var cell_px := float(kit.get("_cell_px"))
	var origin := kit.position
	var cells: Dictionary = {}
	for record: Dictionary in layout.props:
		var span: Vector2 = (record.span as Vector2) + Vector2.ONE * origin.x
		var row := int(floor(((record.foot as Vector2).y + origin.y - 1.0) / cell_px))
		for x in range(int(floor(span.x / cell_px)), int(floor((span.y - 1.0) / cell_px)) + 1):
			cells[Vector2i(x, row)] = true
	if not (layout.tree as Dictionary).is_empty():
		cells[Vector2i((((layout.tree.root as Vector2) + origin) / cell_px).floor())] = true
	if cells.is_empty(): return
	var clear: Dictionary = chunk.get_meta(&"_proc_deco_clear_cells", {}).duplicate()
	clear.merge(cells, true)
	chunk.set_meta(&"_proc_deco_clear_cells", clear)


static func _draws_before(a: Dictionary, b: Dictionary) -> bool:
	var foot_a: Vector2 = a.foot
	var foot_b: Vector2 = b.foot
	if not is_equal_approx(foot_a.y, foot_b.y): return foot_a.y < foot_b.y
	return foot_a.x < foot_b.x


## Pure description of the visible south runs, their openings and fittings.
## All coordinates are kit-local pixels.
static func spec_for(kit: Node2D) -> Dictionary:
	var bounds: Rect2 = kit.get("bounds")
	var cell_px := int(kit.get("_cell_px"))
	var profile: Dictionary = kit.get("_district_profile")
	var civic := bool(kit.get("civic"))
	var declared := StringName(kit.get_meta(&"building_usage", &""))
	var usage := &"civic" if civic else declared
	if not POOLS.has(usage): usage = &"row_house"
	var seed_value := int(profile.get("visual_seed", int(bounds.position.x) * 31 + int(bounds.position.y) * 17))
	var home := not civic and declared == &"row_house"
	var runs: Array[Dictionary] = []
	var outline: PackedVector2Array = kit.get_meta(&"city_irregular_outline", PackedVector2Array()) if bool(kit.get("_irregular")) else PackedVector2Array()
	if outline.is_empty():
		runs.append({"x0": bounds.position.x + 16.0, "x1": bounds.end.x - 16.0, "ground_y": bounds.end.y})
	else:
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			if is_equal_approx(a.y, b.y) and b.x < a.x:
				runs.append({"x0": b.x + 16.0, "x1": a.x - 16.0, "ground_y": b.y})
	var modules := _facade_modules(kit)
	# A hall's roof-mounted plant hangs over its facade end: treat it like a
	# window so tall planting never stands in front of the machinery.
	for rect: Rect2 in _roof_fittings(kit):
		modules.append({"kind": &"fitting", "rect": rect})
	for run: Dictionary in runs:
		var doors: Array[Rect2] = []
		for door: Dictionary in kit.get("_doors"):
			if door.get("dir") != Vector2i.DOWN: continue
			var gap := COMPOSER.door_box(door, cell_px)
			if is_equal_approx(gap.end.y, float(run.ground_y)) and gap.end.x > float(run.x0) and gap.position.x < float(run.x1):
				doors.append(gap)
		var openings: Array[Rect2] = []
		var keep_clear: Array[Vector2] = []
		var foot := float(run.ground_y) - STRIP_PX
		for module: Dictionary in modules:
			var rect: Rect2 = module.rect
			if rect.end.y > foot + 8.0 or rect.end.y < foot - 320.0 or rect.end.x <= float(run.x0) or rect.position.x >= float(run.x1):
				continue
			match StringName(module.kind):
				&"shutters", &"flowers", &"small", &"arched", &"shopfront", &"fitting":
					openings.append(rect)
				&"service", &"door_frame":
					keep_clear.append(Vector2(rect.position.x - 4.0, rect.end.x + 4.0))
		# Hand-drawn civic services (closed arcade bays) keep their wall foot.
		var service: Vector2 = kit.call("service_clear_span") if kit.has_method("service_clear_span") else Vector2.ZERO
		if outline.is_empty() and service != Vector2.ZERO:
			keep_clear.append(service)
		run["doors"] = doors
		run["openings"] = openings
		run["keep_clear"] = keep_clear
	# East/west doorways: a corner crown must not lean over their approach.
	var side_doors: Array[Dictionary] = []
	for door: Dictionary in kit.get("_doors"):
		var dir: Vector2i = door.get("dir", Vector2i.ZERO)
		if dir.x != 0: side_doors.append({"dir": dir.x, "box": COMPOSER.door_box(door, cell_px)})
	return {
		"runs": runs, "usage": usage, "home": home, "civic": civic,
		"family": StringName(profile.get("family_id", &"")),
		"seed": seed_value, "variant": absi(seed_value) % 4 if home else -1,
		"side_doors": side_doors, "nearby": _nearby_props(kit),
	}


## Props already standing at neighbouring buildings of the same chunk. Kits
## configure in the parcel generator's fixed order, so this stays exact under
## streaming; it only steers choices away from repeating the street next door.
static func _nearby_props(kit: Node2D) -> Dictionary:
	var nearby: Dictionary = {}
	var parent := kit.get_parent()
	if parent == null: return nearby
	var center: Vector2 = (kit.get("bounds") as Rect2).get_center()
	for sibling: Node in parent.get_children():
		if sibling == kit or not sibling.is_in_group(&"city_block_building"): continue
		var other: Rect2 = sibling.get("bounds")
		if other.get_center().distance_to(center) > NEARBY_PX: continue
		for root_name: String in ["FrontageDressing", "DomesticGarden"]:
			var root := sibling.get_node_or_null(root_name)
			if root == null: continue
			for node: Node in root.get_children():
				if node.has_meta(&"city_dressing_prop"):
					var prop: StringName = node.get_meta(&"city_dressing_prop")
					nearby[prop] = int(nearby.get(prop, 0)) + 1
	return nearby


## Deterministic layout: {"props": [...], "garden": {...}, "tree": {...}}.
## Each prop record carries its id, kit-local front ground contact ("foot"),
## role (garden/flank/dressing), occupied x span and run index.
static func plan(spec: Dictionary) -> Dictionary:
	var result := {"props": [], "garden": {}, "tree": {}}
	var runs: Array = spec.get("runs", [])
	var usage: StringName = spec.get("usage", &"row_house")
	var home := bool(spec.get("home", false))
	var variant := int(spec.get("variant", -1))
	# Untended households stay bare: no garden and no tidy street dressing.
	if runs.is_empty() or (home and variant == GARDEN_UNTENDED):
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(spec.get("seed", 0)), SALT])
	# Some ordinary working buildings stay bare; homes and halls never do.
	if not home and usage != &"civic" and rng.randf() < 0.12:
		return result
	var spans := _spans(runs)
	if spans.is_empty():
		return result
	var state := {"spans": spans, "props": result.props, "tall": 0, "tall_budget": 2 if usage == &"civic" else 1, "rng": rng, "runs": runs, "trees": [], "side_doors": spec.get("side_doors", [])}
	var front_run := -1
	for index in runs.size():
		if not (runs[index].doors as Array).is_empty():
			front_run = index
			break
	# 1. A corner tree: the fruit-tree household, a hall's shaded back, or a
	# share of working buildings (greener districts plant more of them).
	var family: StringName = spec.get("family", &"")
	if home and variant == GARDEN_FRUIT_TREE:
		result.tree = _place_tree(state, &"fruit")
		if not result.tree.is_empty():
			result.garden = {"variant": variant, "contact": result.tree.root, "run": result.tree.run}
	elif usage == &"civic" and front_run < 0:
		result.tree = _place_tree(state, &"temperate")
	elif not home and usage != &"civic" and rng.randf() < float(SHADE_TREE_SHARE.get(family, 0.3)):
		result.tree = _place_tree(state, &"temperate")
	# 2. The household garden beside the door (street front) or at the back.
	var garden_side := -1
	if home and (variant == GARDEN_BED or variant == GARDEN_FENCED):
		result.garden = _place_garden(state, variant, front_run)
		garden_side = int(result.garden.get("side", -1))
	# 3. Door flanks: a matched pair for halls and passages, one side otherwise.
	var pools: Dictionary = POOLS[usage]
	var nearby: Dictionary = spec.get("nearby", {})
	if front_run >= 0 and not (home and variant == GARDEN_FENCED):
		var template := _pick(pools.flank, rng, nearby, [])
		if (usage == &"civic" or usage == &"passage") and _flank_pair_fits(state, front_run, template):
			_place_flank(state, front_run, template, 0)
			_place_flank(state, front_run, template, 1)
		else:
			var first := rng.randi_range(0, 1)
			# A household's door pots stand on the side away from its garden.
			if garden_side >= 0: first = 1 - garden_side
			if not _place_flank(state, front_run, template, first):
				_place_flank(state, front_run, template, 1 - first)
	# 4. Further groups by remaining width, from the use or district vocabulary.
	var free := 0.0
	for span: Dictionary in state.spans:
		free += float(span.x1) - float(span.x0)
	var wanted := 1 if free < 300.0 else 2 if free < 560.0 else 3
	if home: wanted = 1 if free >= 220.0 else 0
	elif usage == &"civic": wanted = 2 if free >= 240.0 else 1
	var family_pool: Array = FAMILY_POOLS.get(family, [])
	var family_weight: float = FAMILY_WEIGHT.get(family, 0.0)
	var used: Array = []
	for record: Dictionary in state.props:
		used.append(record.prop)
	for _group in wanted:
		for attempt in 6:
			var from_family := not family_pool.is_empty() and rng.randf() < family_weight
			var kind := "front" if front_run >= 0 and rng.randf() < 0.5 else "rear"
			var pool: Array = family_pool if from_family else pools[kind]
			# Prefer a prop neither this building nor its neighbours show yet.
			var template := _pick(pool, rng, nearby if attempt < 3 else {}, used if attempt < 5 else [])
			if _place_free(state, template):
				used.append(template[0])
				break
	return result


## Seeded template choice that skips props already shown (if any remain).
static func _pick(pool: Array, rng: RandomNumberGenerator, nearby: Dictionary, used: Array) -> Array:
	var fresh: Array = []
	for template: Array in pool:
		if not nearby.has(template[0]) and not used.has(template[0]): fresh.append(template)
	var source: Array = fresh if not fresh.is_empty() else pool
	return source[rng.randi_range(0, source.size() - 1)]


## Free x spans per run after doors, their frames and service fittings.
static func _spans(runs: Array) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	for index in runs.size():
		var run: Dictionary = runs[index]
		var pieces: Array[Vector2] = [Vector2(float(run.x0) + CORNER_INSET_PX, float(run.x1) - CORNER_INSET_PX)]
		for gap: Rect2 in run.get("doors", []):
			pieces = _subtract(pieces, Vector2(gap.position.x - DOOR_CLEAR_PX, gap.end.x + DOOR_CLEAR_PX))
		for cut: Vector2 in run.get("keep_clear", []):
			pieces = _subtract(pieces, cut)
		for piece: Vector2 in pieces:
			if piece.y - piece.x < MIN_SPAN_PX: continue
			var door_right := false
			var door_left := false
			for gap: Rect2 in run.get("doors", []):
				# A span ending at a doorway's clear zone flanks that doorway.
				if gap.position.x >= piece.y and gap.position.x - piece.y <= DOOR_CLEAR_PX + 24.0: door_right = true
				if piece.x >= gap.end.x and piece.x - gap.end.x <= DOOR_CLEAR_PX + 24.0: door_left = true
			spans.append({"run": index, "x0": piece.x, "x1": piece.y, "ground_y": float(run.ground_y), "door_on_right": door_right, "door_on_left": door_left})
	return spans


static func _subtract(pieces: Array[Vector2], cut: Vector2) -> Array[Vector2]:
	var next: Array[Vector2] = []
	for piece: Vector2 in pieces:
		if cut.y <= piece.x or cut.x >= piece.y:
			next.append(piece)
			continue
		if cut.x > piece.x: next.append(Vector2(piece.x, cut.x))
		if cut.y < piece.y: next.append(Vector2(cut.y, piece.y))
	return next


static func prop_scale(prop: StringName) -> float:
	var spec: Dictionary = PROPS[prop]
	var rect: Rect2 = spec.rect
	return float(spec.width) / rect.size.x if spec.has("width") else float(spec.height) / rect.size.y


## Visible world size of a prop's opaque art (cached: planning asks often).
static func prop_size(prop: StringName) -> Vector2:
	var size: Variant = _sizes.get(prop)
	if size == null:
		size = (PROPS[prop].rect as Rect2).size * prop_scale(prop)
		_sizes[prop] = size
	return size


static func is_tall(prop: StringName) -> bool:
	return TALL.has(prop)


static func _template_width(template: Array) -> float:
	var total := 0.0
	for index in template.size():
		total += prop_size(template[index]).x - (6.0 if index > 0 else 0.0)
	return total


static func _tall_count(template: Array) -> int:
	var count := 0
	for prop: StringName in template:
		if is_tall(prop): count += 1
	return count


## Lay a template out left to right from `start`; [] if it hides the facade.
static func _layout(state: Dictionary, template: Array, span: Dictionary, start: float, role: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng: RandomNumberGenerator = state.rng
	var x := start
	for index in template.size():
		var prop: StringName = template[index]
		var size := prop_size(prop)
		if index > 0: x -= 6.0
		# Feet stay on the 16 px wall strip; a little depth keeps groups loose.
		var inset := 2.0 + float(rng.randi_range(0, 3)) * 2.0
		out.append({"prop": prop, "foot": Vector2(x + size.x * 0.5, float(span.ground_y) - inset), "role": role, "span": Vector2(x, x + size.x), "run": int(span.run)})
		x += size.x
	if not _clear_of_facade((state.runs as Array)[int(span.run)], out): out.clear()
	return out


## Props stay out of windows and below shopfront sills.
static func _clear_of_facade(run: Dictionary, props: Array[Dictionary]) -> bool:
	for record: Dictionary in props:
		var foot: Vector2 = record.foot
		var span: Vector2 = record.span
		var size := prop_size(record.prop)
		if record.has("width"): size *= float(record.width) / size.x
		var visible := Rect2(span.x, foot.y - size.y, span.y - span.x, size.y)
		for opening: Rect2 in run.get("openings", []):
			var overlap := visible.intersection(opening)
			if overlap.size.x > opening.size.x * WINDOW_COVER_LIMIT.x and overlap.size.y > opening.size.y * WINDOW_COVER_LIMIT.y:
				return false
	return true


## Remove [a, b] plus spacing from one span; pieces keep their flank roles
## only while they still touch the doorway.
static func _consume(state: Dictionary, span_index: int, a: float, b: float) -> void:
	var spans: Array = state.spans
	var span: Dictionary = spans[span_index]
	var whole: Array[Vector2] = [Vector2(float(span.x0), float(span.x1))]
	var pieces := _subtract(whole, Vector2(a - GROUP_GAP_PX, b + GROUP_GAP_PX))
	spans.remove_at(span_index)
	for piece: Vector2 in pieces:
		if piece.y - piece.x < MIN_SPAN_PX: continue
		var next := span.duplicate()
		next.x0 = piece.x
		next.x1 = piece.y
		next.door_on_right = bool(span.door_on_right) and is_equal_approx(piece.y, float(span.x1))
		next.door_on_left = bool(span.door_on_left) and is_equal_approx(piece.x, float(span.x0))
		spans.insert(span_index, next)
		span_index += 1


static func _commit(state: Dictionary, span_index: int, props: Array[Dictionary]) -> void:
	var a := INF
	var b := -INF
	for record: Dictionary in props:
		a = minf(a, (record.span as Vector2).x)
		b = maxf(b, (record.span as Vector2).y)
		if is_tall(record.prop): state.tall = int(state.tall) + 1
		(state.props as Array).append(record)
	_consume(state, span_index, a, b)


## Corner, then far-corner, then centred fits in a seeded span order, so
## groups read as anchored to the house rather than strewn along it.
static func _place_free(state: Dictionary, template: Array) -> bool:
	var tall := _tall_count(template)
	if tall > 0 and int(state.tall) + tall > int(state.tall_budget): return false
	var width := _template_width(template)
	var rng: RandomNumberGenerator = state.rng
	var count := (state.spans as Array).size()
	if count == 0: return false
	var shift := rng.randi_range(0, count - 1)
	var left_first := rng.randf() < 0.5
	for step in count:
		var span_index := (step + shift) % count
		var span: Dictionary = (state.spans as Array)[span_index]
		var x0 := float(span.x0)
		var x1 := float(span.x1)
		if x1 - x0 < width: continue
		if tall > 0 and _near_tree(state, x0, x1, int(span.run)): continue
		var starts: Array[float] = [x0, x1 - width, (x0 + x1 - width) * 0.5]
		if not left_first: starts = [x1 - width, x0, (x0 + x1 - width) * 0.5]
		for start: float in starts:
			var props := _layout(state, template, span, start, &"dressing")
			if props.is_empty(): continue
			_commit(state, span_index, props)
			return true
	return false


static func _near_tree(state: Dictionary, x0: float, x1: float, run: int) -> bool:
	for tree: Dictionary in state.trees:
		var root: Vector2 = tree.root
		if int(tree.run) == run and root.x > x0 - TREE_CROWN_PX and root.x < x1 + TREE_CROWN_PX: return true
	return false


## side 0: the span ending at a doorway's left clear edge; side 1: its right.
static func _flank_span(state: Dictionary, run: int, side: int) -> int:
	for index in (state.spans as Array).size():
		var span: Dictionary = (state.spans as Array)[index]
		if int(span.run) != run: continue
		if (side == 0 and bool(span.door_on_right)) or (side == 1 and bool(span.door_on_left)): return index
	return -1


static func _flank_pair_fits(state: Dictionary, run: int, template: Array) -> bool:
	if int(state.tall) + _tall_count(template) * 2 > int(state.tall_budget): return false
	var width := _template_width(template)
	for side in 2:
		var index := _flank_span(state, run, side)
		if index < 0: return false
		var span: Dictionary = (state.spans as Array)[index]
		if float(span.x1) - float(span.x0) < width: return false
	return true


## Hug the doorway's clear edge on one side.
static func _place_flank(state: Dictionary, run: int, template: Array, side: int) -> bool:
	var index := _flank_span(state, run, side)
	if index < 0: return false
	var tall := _tall_count(template)
	if tall > 0 and int(state.tall) + tall > int(state.tall_budget): return false
	var span: Dictionary = (state.spans as Array)[index]
	var width := _template_width(template)
	if float(span.x1) - float(span.x0) < width: return false
	var props := _layout(state, template, span, float(span.x1) - width if side == 0 else float(span.x0), &"flank")
	if props.is_empty(): return false
	_commit(state, index, props)
	return true


## Fruit or shade tree rooted on the blocked corner away from the doorway.
static func _place_tree(state: Dictionary, kind: StringName) -> Dictionary:
	var runs: Array = state.runs
	var best := -1
	var best_width := 0.0
	for index in runs.size():
		var width := float(runs[index].x1) - float(runs[index].x0)
		if width > best_width:
			best_width = width
			best = index
	if best < 0 or best_width < 160.0: return {}
	var run: Dictionary = runs[best]
	var rng: RandomNumberGenerator = state.rng
	# A corner is free unless drawn services hold its wall foot or the crown
	# would lean over the approach to a side doorway close above that corner.
	var west_ok := true
	var east_ok := true
	var reach: float = TREE_CROWN_REACH_PX[kind]
	for side: Dictionary in state.side_doors:
		var box: Rect2 = side.box
		if box.end.y <= float(run.ground_y) - reach: continue
		if int(side.dir) < 0 and absf(box.position.x - (float(run.x0) - 16.0)) < 96.0: west_ok = false
		if int(side.dir) > 0 and absf(box.end.x - (float(run.x1) + 16.0)) < 96.0: east_ok = false
	for cut: Vector2 in run.get("keep_clear", []):
		if cut.x < float(run.x0) + 90.0: west_ok = false
		if cut.y > float(run.x1) - 90.0: east_ok = false
	var west := rng.randf() < 0.5
	var doors: Array = run.get("doors", [])
	if not doors.is_empty():
		west = (doors[0] as Rect2).get_center().x > (float(run.x0) + float(run.x1)) * 0.5
	if west and not west_ok: west = false
	elif not west and not east_ok: west = true
	if (west and not west_ok) or (not west and not east_ok): return {}
	var clear: float = TREE_CLEAR_PX[kind]
	var root := Vector2(float(run.x0) - 16.0 + TREE_ROOT_INSET.x if west else float(run.x1) + 16.0 - TREE_ROOT_INSET.x, float(run.ground_y) - TREE_ROOT_INSET.y)
	var a := float(run.x0) if west else float(run.x1) - clear
	var b := float(run.x0) + clear if west else float(run.x1)
	# The trunk keeps its own stretch of wall free of other props.
	var index := 0
	while index < (state.spans as Array).size():
		var span: Dictionary = (state.spans as Array)[index]
		if int(span.run) == best and b > float(span.x0) and a < float(span.x1):
			_consume(state, index, a, b)
			index = 0
			continue
		index += 1
	var tree := {"kind": kind, "root": root, "run": best, "west": west}
	(state.trees as Array).append(tree)
	return tree


## Kitchen bed or fenced pot plot against the house wall: beside the doorway
## on a street front, otherwise on the widest back or side stretch.
static func _place_garden(state: Dictionary, variant: int, front_run: int) -> Dictionary:
	var rng: RandomNumberGenerator = state.rng
	var candidates: Array[int] = []
	var sides: Array[int] = []
	if front_run >= 0:
		for side: int in ([0, 1] if rng.randf() < 0.5 else [1, 0]):
			var index := _flank_span(state, front_run, side)
			if index >= 0:
				candidates.append(index)
				sides.append(side)
	var widest := -1
	var widest_width := 0.0
	for index in (state.spans as Array).size():
		var width := float((state.spans as Array)[index].x1) - float((state.spans as Array)[index].x0)
		if width > widest_width:
			widest_width = width
			widest = index
	if widest >= 0 and not candidates.has(widest):
		candidates.append(widest)
		sides.append(-1)
	for order in candidates.size():
		var index := candidates[order]
		var span: Dictionary = (state.spans as Array)[index]
		var flank := bool(span.door_on_right) or bool(span.door_on_left)
		var props: Array[Dictionary] = _bed_plot(state, span, flank) if variant == GARDEN_BED else _fenced_plot(state, span)
		if props.is_empty(): continue
		var a := INF
		var b := -INF
		for record: Dictionary in props:
			a = minf(a, (record.span as Vector2).x)
			b = maxf(b, (record.span as Vector2).y)
		_commit(state, index, props)
		return {"variant": variant, "contact": Vector2((a + b) * 0.5, float(span.ground_y) - 2.0), "span": Vector2(a, b), "run": int(span.run), "side": sides[order]}
	return {}


## Gardens keep to the corner end of a doorway flank so the doorstep side
## stays free for pots or passers-by; elsewhere they sit centred.
static func _plot_start(span: Dictionary, width: float) -> float:
	if bool(span.door_on_right): return float(span.x0)
	if bool(span.door_on_left): return float(span.x1) - width
	return (float(span.x0) + float(span.x1) - width) * 0.5


static func _bed_plot(state: Dictionary, span: Dictionary, flank: bool) -> Array[Dictionary]:
	var room := float(span.x1) - float(span.x0)
	if room < BED_MIN_PX: return []
	var bed_width := minf(room, prop_size(&"garden_bed").x)
	var pots_width := prop_size(&"pots_cluster").x
	# Off the street, the bed shares its stretch with a few pots.
	var template: Array = [&"garden_bed"]
	if not flank and room >= bed_width + pots_width - 6.0:
		template = [&"garden_bed", &"pots_cluster"]
	var width := bed_width + (pots_width - 6.0 if template.size() > 1 else 0.0)
	var start := _plot_start(span, width)
	var props: Array[Dictionary] = []
	var rng: RandomNumberGenerator = state.rng
	var x := start
	for prop: StringName in template:
		var w := bed_width if prop == &"garden_bed" else pots_width
		var record := {"prop": prop, "foot": Vector2(x + w * 0.5, float(span.ground_y) - 2.0 - float(rng.randi_range(0, 2)) * 2.0), "role": &"garden", "span": Vector2(x, x + w), "run": int(span.run)}
		if prop == &"garden_bed": record["width"] = bed_width
		props.append(record)
		x += w - 6.0
	if not _clear_of_facade((state.runs as Array)[int(span.run)], props): props.clear()
	return props


## Low wattle fence along the strip's front with pots behind it, against the
## wall: a small front-garden plot that never reaches walkable ground.
static func _fenced_plot(state: Dictionary, span: Dictionary) -> Array[Dictionary]:
	var room := float(span.x1) - float(span.x0)
	var tile := prop_size(&"wattle_fence").x
	var tiles := 2 if room >= tile * 2.0 - 4.0 else 1
	# A single panel may close up to fit a narrow wall (uniform scale only).
	if tiles == 1: tile = minf(tile, room)
	if tile < FENCE_MIN_PX: return []
	var width := tile * tiles - 4.0 * (tiles - 1)
	var start := _plot_start(span, width)
	var props: Array[Dictionary] = []
	var rng: RandomNumberGenerator = state.rng
	var pot_w := prop_size(&"pots_cluster").x
	for index in tiles:
		var at := start + (width / tiles) * (index + 0.5)
		props.append({"prop": &"pots_cluster", "foot": Vector2(at, float(span.ground_y) - 9.0 - float(rng.randi_range(0, 2))), "role": &"garden", "span": Vector2(at - pot_w * 0.5, at + pot_w * 0.5), "run": int(span.run)})
	for index in tiles:
		var x := start + index * (tile - 4.0)
		props.append({"prop": &"wattle_fence", "foot": Vector2(x + tile * 0.5, float(span.ground_y) - 1.0), "role": &"garden", "span": Vector2(x, x + tile), "run": int(span.run), "width": tile})
	if not _clear_of_facade((state.runs as Array)[int(span.run)], props): props.clear()
	return props


static func _add_prop(kit: Node2D, parent: Node2D, record: Dictionary) -> void:
	var prop: StringName = record.prop
	var spec: Dictionary = PROPS[prop]
	var texture := _texture(ROOT + String(spec.file))
	if texture == null: return
	var rect: Rect2 = spec.rect
	var scale_value := float(record.width) / rect.size.x if record.has("width") else prop_scale(prop)
	var foot: Vector2 = record.foot
	var sprite := Sprite2D.new()
	sprite.name = "Dressing" + String(prop).to_pascal_case()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = foot + (texture.get_size() * 0.5 - Vector2(rect.get_center().x, rect.end.y)) * scale_value
	sprite.modulate = PROP_TINT
	sprite.z_index = 1
	if prop in FLAT_PROPS:
		# A flush garden bed is flat ground: it takes the building's shade and
		# the actors' shadows like the soil around it (WorldDepthStyle layers).
		sprite.z_as_relative = false
		sprite.z_index = DEPTH.GROUND_SHADE_Z - 1
	sprite.set_meta(&"city_dressing_prop", prop)
	sprite.set_meta(&"city_dressing_contact", foot)
	sprite.set_meta(&"city_dressing_role", record.role)
	parent.add_child(sprite)
	# Tall props silhouette actors who pass behind them, like the kit trees.
	if is_tall(prop):
		FOREGROUND.register(sprite, foot)
	# A flush bed is ground and casts nothing; a pile casts from its footprint.
	if not prop in FLAT_PROPS:
		_add_shadow(kit, sprite, foot, texture, DEPTH.footprint_pivot(foot, rect.size * scale_value))


static func _add_tree(kit: Node2D, tree: Dictionary) -> void:
	var fruit := StringName(tree.kind) == &"fruit"
	var texture := _texture(FRUIT_TREE if fruit else TEMPERATE_TREE)
	if texture == null: return
	var anchor := FRUIT_TREE_ROOT if fruit else TEMPERATE_TREE_ROOT
	var scale_value := FRUIT_TREE_SCALE if fruit else TEMPERATE_TREE_WIDTH / texture.get_width()
	var root: Vector2 = tree.root
	var plant := Sprite2D.new()
	plant.name = "CityTemperateTree"
	plant.texture = texture
	plant.scale = Vector2.ONE * scale_value
	plant.position = root + (texture.get_size() * 0.5 - anchor) * scale_value
	plant.modulate = TREE_TINT
	plant.z_index = 1
	plant.set_meta(&"city_ground_contact", root)
	kit.add_child(plant)
	FOREGROUND.register(plant, root)
	var shade := _add_shadow(kit, plant, root, texture)
	if shade != null: shade.name = "CityFoliageShadow"


## A ground shadow projected from the sprite's own silhouette, like the kit
## trees: same light, and the same receiver trimming (city_sun_shadow + UV
## metas let CityBlockKit.trim_paving cut it out of every occupied footprint).
## `pivot` is where the cast starts: the root for a tree, a painted pile's
## footprint centre (WorldDepthStyle.footprint_pivot).
static func _add_shadow(kit: Node2D, sprite: Sprite2D, foot: Vector2, texture: Texture2D, pivot: Variant = null) -> Polygon2D:
	var projection := DEPTH.project_transform(sprite.transform, foot if pivot == null else pivot as Vector2)
	var half := texture.get_size() * 0.5
	var uv := PackedVector2Array([Vector2.ZERO, Vector2(texture.get_width(), 0), texture.get_size(), Vector2(0, texture.get_height())])
	var points := PackedVector2Array()
	for pixel: Vector2 in uv:
		points.append(projection * (pixel - half))
	var shade := Polygon2D.new()
	shade.name = "DressingShadow"
	shade.set_meta(&"city_sun_shadow", true)
	shade.set_meta(&"city_dressing_shadow", true)
	shade.set_meta(&"shadow_uv_transform", projection.affine_inverse())
	shade.set_meta(&"shadow_uv_offset", half)
	shade.polygon = points
	shade.uv = uv
	shade.texture = texture
	shade.color = SHADOW_COLOR
	shade.z_index = -90
	kit.add_child(shade)
	return shade


## Window, shopfront, service and door-frame modules of the composed facade.
## The composer adds them directly under the kit's facade groups (rectangular
## "ComposedFacade", irregular "CardinalWallReturns"); no deep tree search.
static func _facade_modules(kit: Node2D) -> Array[Dictionary]:
	var modules: Array[Dictionary] = []
	for group_name: String in ["ComposedFacade", "CardinalWallReturns"]:
		var group := kit.get_node_or_null(group_name) as Node2D
		if group == null: continue
		for node: Node in group.get_children():
			if not node is Polygon2D or not node.has_meta(&"facade_module"): continue
			var shape := node as Polygon2D
			if shape.polygon.is_empty(): continue
			var rect := Rect2(shape.polygon[0], Vector2.ZERO)
			for point: Vector2 in shape.polygon:
				rect = rect.expand(point)
			rect.position += group.position
			modules.append({"kind": StringName(shape.get_meta(&"facade_module")), "rect": rect})
	return modules


## Optional fittings drawn on the roof plane over the south facade (the civic
## pressure plant), in kit-local pixels.
static func _roof_fittings(kit: Node2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var roof := kit.get("_roof") as Node2D
	if roof == null or not is_instance_valid(roof): return rects
	var poly := roof.get_node_or_null("RoofPoly") as Node2D
	if poly == null: return rects
	for node: Node in poly.get_children():
		var sprite := node as Sprite2D
		if sprite == null or sprite.texture == null or not sprite.has_meta(&"district_optional_detail"): continue
		var size := sprite.texture.get_size() * sprite.scale.abs()
		var center := roof.position + poly.position + sprite.position - kit.position
		rects.append(Rect2(center - size * 0.5, size))
	return rects


static func _texture(path: String) -> Texture2D:
	if _cache.has(path): return _cache[path]
	var texture: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	else:
		var pixels := Image.load_from_file(path)
		if pixels != null and not pixels.is_empty():
			pixels.generate_mipmaps()
			texture = ImageTexture.create_from_image(pixels)
	if texture != null: _cache[path] = texture
	return texture
