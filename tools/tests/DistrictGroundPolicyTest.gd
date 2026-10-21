extends Node
## District ground for every procedural theme (2026-10-21): the built
## district stands on a continuous hard surface presented per family, the
## exploration web and the wilderness stay wild, each theme fits the eight
## splat slots without borrowing, and the presentation pass (occlusion and
## household care) is deterministic and consumes no RNG.
##
## Run: <godot> --headless --path . res://tools/tests/DistrictGroundPolicyTest.tscn

const POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const CPC := 32
const EXPLORATION_ROLES: Array[StringName] = [&"service_lane", &"exploration_reward"]
const TARGETS: Array[Dictionary] = [
	{"segment": 2, "theme": &"service_courtyards"},
	{"segment": 3, "theme": &"checkpoint_lanes"},
	{"segment": 4, "theme": &"collapsed_ward"},
	{"segment": 4, "theme": &"civilian_cutthrough"},
	{"segment": 5, "theme": &"inner_district_gate"},
	{"segment": 6, "theme": &"industrial_cutthrough"},
	{"segment": 6, "theme": &"ruined_services"},
	{"segment": 7, "theme": &"underpass_veins"},
	{"segment": 7, "theme": &"canal_services"},
	{"segment": 8, "theme": &"rail_yard"},
	{"segment": 8, "theme": &"military_staging"},
	{"segment": 9, "theme": &"outer_wall"},
	{"segment": 9, "theme": &"siege_services"},
	{"segment": 10, "theme": &"gate_district"},
	{"segment": 11, "theme": &"service_courtyards"},
]

var _passes := 0
var _failures := 0
var _samples: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var previous_segment := Global.attempt_segment
	_test_policy_catalogue()
	for target: Dictionary in TARGETS:
		_test_theme_district(int(target.segment), StringName(target.theme))
	Global.attempt_segment = previous_segment
	print("DistrictGroundPolicy samples: ", JSON.stringify(_samples))
	print("DistrictGroundPolicyTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


static func _luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


func _test_policy_catalogue() -> void:
	var signatures: Dictionary = {}
	for family: StringName in POLICY.FAMILIES:
		var policy := POLICY.resolve(family)
		_check(bool(policy.get("enabled", false)) and StringName(policy.get("id", &"")) == family, "%s resolves its own enabled ground policy" % family)
		_check(StringName(policy.get("district_terrain", &"")) == &"urban", "%s builds its district on the hard urban surface" % family)
		var roles: Dictionary = policy.get("roles", {})
		var complete := true
		for role in range(1, POLICY.ROLE_COUNT):
			var entry: Dictionary = roles.get(role, {})
			var source := int(entry.get("source", -1))
			if entry.is_empty() or source < POLICY.SOURCE_OWN or source > POLICY.SOURCE_LAYER or float(entry.get("repeat_px", 0.0)) < 64.0:
				complete = false
			if source == POLICY.SOURCE_LAYER and int(entry.get("layer", -1)) < 0:
				complete = false
		_check(complete, "%s defines every presentation role with a valid source" % family)
		# Bright temperate daylight, cool-neutral stone: paving stays light and
		# never drifts to beige (red may not run far ahead of blue).
		var bright := true
		var temperate := true
		for role: int in [POLICY.ROLE_ROAD, POLICY.ROLE_LANE, POLICY.ROLE_FOOTWAY, POLICY.ROLE_YARD]:
			var mid: Color = (roles.get(role, {}) as Dictionary).get("mid", Color.BLACK)
			if _luminance(mid) < 0.36 or _luminance(mid) > 0.66:
				bright = false
			if mid.r - mid.b > 0.07:
				temperate = false
		var footway: Color = (roles.get(POLICY.ROLE_FOOTWAY, {}) as Dictionary).get("mid", Color.BLACK)
		_check(bright and _luminance(footway) >= 0.5, "%s paving mid tones stay in the bright daylight band" % family)
		_check(temperate, "%s paving stays cool-neutral (no desert drift)" % family)
		_check(float(policy.get("kerb", 0.0)) > 0.0 and float(policy.get("ao", 0.0)) > 0.0 and float(policy.get("ao", 1.0)) <= 0.4, "%s draws kerbs and a bounded ground occlusion" % family)
		var signature := POLICY.signature(policy)
		_check(not signatures.has(signature), "%s has its own physical ground look (not a copy of %s)" % [family, str(signatures.get(signature, ""))])
		signatures[signature] = family
	var fallback := POLICY.resolve(&"unknown_future_family")
	_check(bool(fallback.enabled) and StringName(fallback.id) == &"service_courtyards", "an unknown procedural family falls back to Service Courtyards")
	var legacy := POLICY.resolve(&"")
	_check(not bool(legacy.enabled), "no district family (S1, Hub) keeps the raw palette")
	var first := POLICY.resolve(&"canal_services")
	first.roles[POLICY.ROLE_YARD]["repeat_px"] = 1.0
	_check(float(POLICY.resolve(&"canal_services").roles[POLICY.ROLE_YARD].repeat_px) > 64.0, "resolved policies are independent copies")
	var expected := {7: POLICY.ROLE_ROAD, 8: POLICY.ROLE_ROAD, 9: POLICY.ROLE_ROAD, 3: POLICY.ROLE_FOOTWAY, 4: POLICY.ROLE_LANE, 2: POLICY.ROLE_FOOTWAY, 6: POLICY.ROLE_YARD, 0: POLICY.ROLE_LAWN, 10: POLICY.ROLE_LAWN, 11: POLICY.ROLE_LAWN, 12: POLICY.ROLE_LAWN, 1: POLICY.ROLE_SOIL, 5: POLICY.ROLE_SOIL}
	var mapped := true
	for index: int in expected:
		if POLICY.role_for_index(index) != int(expected[index]): mapped = false
	_check(mapped, "semantic materials map to their presentation roles")


func _theme_seed(segment: int, theme_id: StringName) -> int:
	for seed_value in range(1, 400):
		if SegmentThemePicker.get_theme(segment, seed_value).id == theme_id:
			return seed_value
	return -1


func _manager(theme: SegmentThemeData, plan: Dictionary) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.generation_enabled = false
	cm.ground_enabled = true
	cm.ground_splat_enabled = true
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	cm.parcels_chunk_chance = 0.95
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm.set_process(false)
	cm.configure_procedural_world(int(plan.seed), plan.connectors_by_chunk, plan.urban_access_by_chunk, plan.role_by_chunk, plan.terrain_by_chunk, plan.archetype_by_chunk)
	return cm


func _count(splat: GroundSplatRenderer, coord: Vector2i, index: int) -> int:
	var count := 0
	for y in CPC:
		for x in CPC:
			if splat.material_at(coord * CPC + Vector2i(x, y)) == index: count += 1
	return count


func _test_theme_district(segment: int, theme_id: StringName) -> void:
	var seed_value := _theme_seed(segment, theme_id)
	_check(seed_value > 0, "a natural seed selects %s for segment %d" % [theme_id, segment])
	if seed_value <= 0:
		return
	Global.attempt_segment = segment
	var theme := SegmentThemePicker.get_theme(segment, seed_value)
	var plan := DistrictPlan.generate(segment, seed_value, 2048, theme)
	var exploration: Dictionary = {}
	for coord: Vector2i in plan.exploration_chunks: exploration[coord] = true
	for coord: Vector2i in plan.exploration_end_chunks: exploration[coord] = true
	var terrain_ok := true
	for coord: Vector2i in plan.terrain_by_chunk:
		var terrain: StringName = plan.terrain_by_chunk[coord]
		if exploration.has(coord) and terrain != StringName(theme.exploration_terrain): terrain_ok = false
		if not exploration.has(coord) and terrain != &"urban": terrain_ok = false
	_check(terrain_ok, "%s: district chunks stand on the urban surface, the exploration web keeps %s" % [theme_id, theme.exploration_terrain])
	# Stream the start neighbourhood: route, envelope and (wild) exploration.
	var start: Vector2i = plan.start_chunk
	var chosen: Array[Vector2i] = []
	for coord: Vector2i in plan.main_route.slice(0, 5):
		if not chosen.has(coord): chosen.append(coord)
	var by_distance: Array = plan.role_by_chunk.keys()
	by_distance.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - start).length_squared()
		var db := (b - start).length_squared()
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var wild_chosen := 0
	var fill_chosen := 0
	# The presentation maps are a ring of MAP_SIZE cells: two chunks a whole
	# ring apart share one slot and are never streamed together, so the
	# fixture never loads such a pair either.
	var ring := GroundSplatRenderer.MAP_SIZE / CPC
	for coord: Vector2i in by_distance:
		var role: StringName = plan.role_by_chunk[coord]
		var aliased := false
		for other: Vector2i in chosen:
			if other != coord and posmod(other.x - coord.x, ring) == 0 and posmod(other.y - coord.y, ring) == 0: aliased = true
		if aliased:
			continue
		if exploration.has(coord) and wild_chosen < 2 and not chosen.has(coord):
			chosen.append(coord)
			wild_chosen += 1
		elif role == &"district_fill" and fill_chosen < 3 and not chosen.has(coord):
			chosen.append(coord)
			fill_chosen += 1
	var cm := _manager(theme, plan)
	for coord: Vector2i in chosen:
		cm._chunks[coord] = cm._create_chunk(coord)
	var splat := cm.get_ground_splat()
	var active := splat.active_slot_materials()
	_check(splat.slot_borrow_count() == 0 and active.size() <= 8, "%s fits the eight splat slots without borrowing (%s)" % [theme_id, str(active)])
	_check(StringName(splat.ground_policy().get("id", &"")) == theme.district_family, "%s presents its own family policy" % theme_id)
	var exploration_index := cm._ground_index_for_terrain(StringName(theme.exploration_terrain))
	var district_cells := 0
	var wild_in_district := 0
	var urban_in_wild := 0
	var wild_cells := 0
	for coord: Vector2i in chosen:
		if exploration.has(coord):
			urban_in_wild += _count(splat, coord, 6)
			wild_cells += _count(splat, coord, exploration_index)
		else:
			district_cells += _count(splat, coord, 6)
			wild_in_district += _count(splat, coord, exploration_index)
	_check(district_cells > 0, "%s district chunks show their continuous hard surface (%d cells)" % [theme_id, district_cells])
	_check(urban_in_wild == 0 and (wild_chosen == 0 or wild_cells > 0), "%s exploration chunks stay wild (%d wild, %d urban cells)" % [theme_id, wild_cells, urban_in_wild])
	# Presentation pass: deterministic, alpha/blue only, no RNG.
	# The busiest district chunk (most walls and props) is the costliest case.
	var district_coord := Vector2i(999999, 999999)
	var most := 0
	for coord: Vector2i in chosen:
		if exploration.has(coord) or cm.get_chunk_build_data(coord) == null:
			continue
		var occupied := cm.get_chunk_build_data(coord).occupied_indices().size()
		if occupied > most:
			most = occupied
			district_coord = coord
	var presentation_ms := -1.0
	var occlusion_ms := -1.0
	if district_coord != Vector2i(999999, 999999):
		var occluded := 0
		for y in CPC:
			for x in CPC:
				if splat.openness_at(district_coord * CPC + Vector2i(x, y)) < 0.85: occluded += 1
		_check(occluded > 0, "%s walls and props shade the ground around them (%d cells)" % [theme_id, occluded])
		var light: PackedByteArray = (splat.get("_light") as Image).get_data()
		var cover: PackedByteArray = (splat.get("_cover_a") as Image).get_data()
		var rng_state := Global._rng.state
		seed(20261021)
		var expected_next := randi()
		seed(20261021)
		var started := Time.get_ticks_usec()
		cm._activate_ground_care(district_coord, cm._chunks[district_coord])
		presentation_ms = float(Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		splat.paint_occlusion(district_coord, cm.get_chunk_build_data(district_coord))
		occlusion_ms = float(Time.get_ticks_usec() - started) / 1000.0
		_check(randi() == expected_next and Global._rng.state == rng_state, "%s ground presentation consumes no RNG" % theme_id)
		_check(light == (splat.get("_light") as Image).get_data() and cover == (splat.get("_cover_a") as Image).get_data(), "%s repeated presentation reproduces exact bytes" % theme_id)
	# Upload cost of the coverage mip chain (CPU side; headless has a dummy GPU).
	splat.set("_dirty", true)
	var flush_started := Time.get_ticks_usec()
	splat.flush()
	var flush_ms := float(Time.get_ticks_usec() - flush_started) / 1000.0
	_samples.append({"flush_ms": flush_ms, "segment": segment, "seed": seed_value, "theme": String(theme_id), "slots": Array(active), "district_cells": district_cells, "wild_cells": wild_cells, "wild_margin_cells_in_district": wild_in_district, "chunks": chosen.size(), "presentation_ms": presentation_ms, "occlusion_ms": occlusion_ms, "blockers": cm.get_chunk_build_data(district_coord).occupied_indices().size() if district_coord != Vector2i(999999, 999999) else 0})
	cm.free()
	_test_carriageway_index(theme, plan, theme_id)


## The district's carriageway uses of the old index 3 (exit approach and
## checkpoint lanes, gate and arena courts, hub pads) stamp the kerbed
## main-street index; index 3 is left to building and room floors.
func _test_carriageway_index(theme: SegmentThemeData, plan: Dictionary, theme_id: StringName) -> void:
	var targets: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		if plan.role_by_chunk[coord] in [&"exit_approach", &"gate", &"checkpoint", &"miniboss_arena", &"boss_arena"]:
			targets.append(coord)
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	if targets.is_empty():
		return
	var cm := _manager(theme, plan)
	var road_cells := 0
	var floor_on_road := 0
	var ring := GroundSplatRenderer.MAP_SIZE / CPC
	var loaded: Array[Vector2i] = []
	for coord: Vector2i in targets:
		var aliased := false
		for other: Vector2i in loaded:
			if posmod(other.x - coord.x, ring) == 0 and posmod(other.y - coord.y, ring) == 0: aliased = true
		if aliased:
			continue
		loaded.append(coord)
		var chunk := cm._create_chunk(coord)
		cm._chunks[coord] = chunk
		var clear: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
		for local: Vector2i in clear:
			var material := cm.get_ground_splat().material_at(coord * CPC + local)
			if material == 7: road_cells += 1
			elif material == 3: floor_on_road += 1
	_check(road_cells > 0 and floor_on_road == 0, "%s approach, gate and court carriageways stamp the main-street paving, never the floor index (%d road cells, %d floor cells)" % [theme_id, road_cells, floor_on_road])
	cm.free()
