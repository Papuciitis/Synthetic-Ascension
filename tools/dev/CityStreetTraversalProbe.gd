extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Short final-dressed street traversal on the actual Game (2026-10-21 street
## pass): chunk streaming, ambient spawning, the procedural director, enemy
## scheduling, decoration, collisions and pickup eligibility stay live; the
## player moves by scripted input through real collisions (_walk_to).
## Route: through a recorded infill frontage passage (in one end, across its
## middle, out the other), into an actual building and out again (roof cutaway
## and restore, the building-entered event and its first-visit flag), into an
## infill building when one is near (first visit must be false), an ordinary
## staged item collected through its real arming delay, magnet and contact,
## and across a chunk seam into the next streaming centre.
## Staged and disclosed: the initial player warp to the passage, the staged
## ring item, god mode, modal onboarding bypass, scripted movement and aim/fire
## at the nearest live enemy. Nothing is
## frozen: no actor freeze, never_cull, pickup override or direct collection.
## -- --segment=2 [--world-seed=16102026] [--passage-chunk=x,y]
##    --out=<fresh absolute directory>

const ITEM_SCENE := preload("res://scenes/world/pickups/ItemPickup.tscn")

var _events: Array[Dictionary] = []
var _staging: Array[Dictionary] = []
var _route_cells: Array[Vector2i] = []
var _passage_trace: Array[Dictionary] = []
var _centers: Array[String] = []
var _pickup_ref: WeakRef
var _pickup_instance: ItemInstance
var _pickup_state: Dictionary = {}
var _report: Dictionary = {}
var _route_live := false
var _discovery: Array[Dictionary] = []
var _camera_points: Array[Dictionary] = []
var _has_passage_chunk := false
var _passage_chunk := Vector2i.ZERO
var _director_start: Dictionary = {}
var _director_stayed_live := true
var _passage_corridor := Rect2i()


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--passage-chunk="):
			continue
		var parts := arg.trim_prefix("--passage-chunk=").split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			_fail("Passage replay requires an explicit integer chunk x,y")
			continue
		_passage_chunk = Vector2i(int(parts[0]), int(parts[1]))
		_has_passage_chunk = true


func _run() -> void:
	if _failures > 0:
		await _shutdown()
		return
	if DisplayServer.get_name() == "headless":
		_fail("The traversal records native stills; run with a renderer")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
	# The inherited isolated fight setup disables authored encounter beats.
	# Restore production creation before Game's deferred director setup runs.
	Global.debug_encounter_beats = true
	get_window().size = Vector2i(1280, 720)
	get_window().title = "Synthetic Ascension — final-dressed street traversal"
	if _out.begins_with("res://docs/art/reference/2026-10-18-city-block"):
		_out = "user://dev_previews/street_traversal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = GAME.instantiate() as Node2D
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	RunEvents.player_entered_building.connect(_on_entered_building)
	await _settle()
	_dismiss_dossiers()
	_director_start = _director_evidence()
	if not bool(_director_start.live):
		_fail("The production EncounterDirector was not created, enabled and bound")
		await _shutdown()
		return
	var start := _player.global_position
	var passage := {} if _has_passage_chunk else _nearest_passage(start)
	if passage.is_empty() or not bool(passage.narrow_between_buildings):
		# Staged search: warp to planned chunks nearest the start, one at a
		# time, until a narrow passage between buildings has streamed in.
		var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
		var plan: Dictionary = builder.get("_plan") if builder != null else {}
		var coords: Array = (plan.get("role_by_chunk", {}) as Dictionary).keys()
		var start_chunk := _chunks._world_to_chunk(start)
		coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - start_chunk).length_squared() < (b - start_chunk).length_squared())
		if _has_passage_chunk:
			coords = [_passage_chunk]
		for coord: Vector2i in coords.slice(0, 40):
			var warp := await _stream_walkable_near((Vector2(coord) + Vector2.ONE * 0.5) * _chunks.chunk_size_px)
			if warp == Vector2.INF:
				continue
			_player.global_position = warp
			await _settle()
			_dismiss_dossiers()
			var found := _nearest_passage(_player.global_position)
			_discovery.append({"chunk": str(coord), "world": str(warp), "passage": str(found.get("cells", Rect2i())), "narrow": bool(found.get("narrow_between_buildings", false))})
			if not found.is_empty() and bool(found.narrow_between_buildings):
				passage = found
				_staging.append({"kind": "passage search warp", "chunk": str(coord), "world": str(_player.global_position)})
				break
	if passage.is_empty() or not bool(passage.narrow_between_buildings):
		_fail("No narrow recorded frontage passage found after bounded streamed search")
		await _shutdown()
		return
	var ends: Array = passage.ends
	_player.global_position = _free_spawn_position(ends[0] + (ends[0] - ends[1]).normalized() * 192.0)
	_staging.append({"kind": "player initial warp beside a recorded passage", "start": str(start), "warp": str(_player.global_position), "passage_world": str(passage.world)})
	await _settle()
	_dismiss_dossiers()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_centers.append(str(_chunks._current_center))
	_route_live = true
	await _frames(4)
	# 1. Reach the near mouth freely, then keep every planned step and
	# physical observation inside the actual passage plus its mouth rows.
	_phase = "passage_approach"
	await _walk_to(ends[0])
	var passage_cells: Rect2i = passage.cells
	var passage_chunk: Vector2i = passage.chunk
	passage_cells.position += passage_chunk * _chunks._cells_per_chunk()
	var along := Vector2i.DOWN if passage_cells.size.y > passage_cells.size.x else Vector2i.RIGHT
	_passage_corridor = Rect2i(passage_cells.position - along, passage_cells.size + along * 2)
	_route_cells.clear()
	_passage_trace.clear()
	_phase = "passage"
	_record_passage_cell()
	await _walk_to(passage.center)
	var inside_passage := (passage.world as Rect2).has_point(_player.global_position)
	if not inside_passage: _fail("The player did not stand inside the passage " + str(passage.world))
	await _still("traversal-1-passage")
	await _walk_to(ends[1])
	_record_passage_cell()
	var trace_result := _passage_trace_result(passage_cells, _route_cells)
	_passage_corridor = Rect2i()
	var through := (_player.global_position - (ends[1] as Vector2)).length() < 48.0 and bool(trace_result.valid)
	if not through: _fail("The player did not physically cross the recorded passage within its corridor: " + str(trace_result))
	# 2. An actual building: entry (roof cutaway) and exit (roof restored).
	_phase = "building"
	var original := _entry_target(_player.global_position, false)
	var entry := {}
	if original.is_empty(): _fail("No enterable original building near the passage")
	else: entry = await _enter_and_exit(original, "traversal-2-inside")
	var infill := _entry_target(_player.global_position, true)
	var infill_entry := {}
	if not infill.is_empty(): infill_entry = await _enter_and_exit(infill, "traversal-3-inside-infill")
	# 3. Collection of an ordinary staged item through the real pickup rules.
	_phase = "collection"
	_stage_pickup(_player.global_position + Vector2(256, 0))
	await _frames(75)
	var pickup := _pickup_ref.get_ref() as ItemPickup if _pickup_ref != null else null
	if pickup != null:
		_pickup_state["armed_before_walk"] = pickup._pickup_ready
		await _walk_to(pickup.global_position)
	await _wait_seconds(1.5)
	var collected := bool(_pickup_state.get("picked", false)) and _inventory_has(_pickup_instance)
	if not collected: _fail("The staged ordinary item was not collected into inventory or bag")
	await _still("traversal-4-collected")
	# 4. A chunk seam: into the neighbouring streaming centre.
	_phase = "boundary"
	var before_center: Vector2i = _chunks._current_center
	var crossing := _nearest_crossing(_player.global_position)
	await _walk_to(crossing)
	await _wait_seconds(1.5)
	var after_center: Vector2i = _chunks._current_center
	_centers.append(str(after_center))
	var crossed := after_center != before_center and _chunks._world_to_chunk(_player.global_position) == after_center
	if not crossed: _fail("The streaming centre did not follow the player across the seam")
	await _still("traversal-5-boundary")
	var director_end := _director_evidence()
	if not bool(director_end.live) or not _director_stayed_live:
		_fail("The production EncounterDirector did not remain live during traversal")
	_route_live = false
	_release_inputs()
	_report = {"capture_scene": "res://tools/dev/CityStreetTraversalProbe.tscn", "scene": "res://scenes/game.tscn", "args": OS.get_cmdline_user_args(),
		"segment": _city_segment, "world_seed": _city_world_seed, "window": str(get_window().size), "camera_zoom": str(_camera.zoom),
		"passage": {"world": str(passage.world), "cells": str(passage.cells), "chunk": str(passage.chunk), "narrow_between_buildings": passage.narrow_between_buildings, "flanked_cells": passage.flanked_cells, "inside": inside_passage, "through": through, "actual_physics_cell_trace": _passage_trace, "trace_validation": trace_result},
		"original_entry": entry, "infill_entry": infill_entry, "building_events": _events,
		"pickup": _pickup_state, "collected": collected,
		"boundary": {"before": str(before_center), "after": str(after_center), "crossed": crossed, "target": str(crossing)},
		"chunk_centers": _centers, "route": _route_notes, "staging": _staging, "discovery": _discovery, "camera_points": _camera_points, "failures": _failures,
		"decoration": _chunks.deco_enabled, "street_continuity": _chunks.street_continuity_enabled,
		"encounter_director": {"requested": Global.debug_encounter_beats, "start": _director_start, "end": director_end, "stayed_live": _director_stayed_live},
		"limits": "Staged: initial player warp beside the passage, one ordinary ring item, god mode, modal onboarding bypass, scripted input movement and aim/fire at the nearest live enemy. Live: streaming, ambient spawner, authored encounter beats, procedural director, enemy scheduler, decoration, collisions, roof fades, pickup delay/magnet/contact. No actor freeze, never_cull, pickup override or direct collection. Not a performance or human-play test."}
	print("CityStreetTraversalProbe: passage=%s through=%s original_entry=%s infill_entry=%s collected=%s crossed=%s failures=%d" % [str(inside_passage), str(through), str(entry.get("restored", false)), str(infill_entry.get("restored", false)), str(collected), str(crossed), _failures])
	await _shutdown()


func _process(_delta: float) -> void:
	if _player != null and _camera != null:
		_camera.global_position = _player.global_position
		_camera.rotation = 0.0


## Live enemies body-block a player who never fights: once moving, the player
## aims at the nearest live enemy and holds the ordinary attack (scripted,
## disclosed), as the moving-cue route did.
func _physics_process(_delta: float) -> void:
	if not _route_live:
		return
	_record_passage_cell()
	if not get_tree().paused:
		var director := _game.get_node_or_null("EncounterDirector") as EncounterDirector
		_director_stayed_live = _director_stayed_live and director != null and director.enabled and director.is_physics_processing() and director.can_process() and director._spawner != null and director._spawner == _game.get_node_or_null("Spawner") and director._player == _player
	var aim := _aim_at_live_enemy()
	_set_axis(&"aim_left", &"aim_right", aim.x)
	_set_axis(&"aim_up", &"aim_down", aim.y)
	Input.action_press(&"attack")


## Sample the player's real post-collision location on each physics tick;
## retain each cell transition (stationary repeats carry no new route fact).
func _record_passage_cell() -> void:
	if not _passage_corridor.has_area():
		return
	var cell := _chunks.world_to_cell(_player.global_position)
	if not _route_cells.is_empty() and _route_cells.back() == cell:
		return
	_route_cells.append(cell)
	_passage_trace.append({"physics_frame": Engine.get_physics_frames(), "cell": [cell.x, cell.y], "world": str(_player.global_position)})


func _passage_trace_result(passage: Rect2i, cells: Array[Vector2i]) -> Dictionary:
	var vertical := passage.size.y > passage.size.x
	var along := Vector2i.DOWN if vertical else Vector2i.RIGHT
	var length := passage.size.y if vertical else passage.size.x
	var cross_section := Vector2i(passage.size.x, 1) if vertical else Vector2i(1, passage.size.y)
	var near := Rect2i(passage.position - along, cross_section)
	var middle := Rect2i(passage.position + along * int(length / 2.0), cross_section)
	var far := Rect2i(passage.position + along * length, cross_section)
	var allowed := Rect2i(passage.position - along, passage.size + along * 2)
	var near_index := -1
	var middle_index := -1
	var far_index := -1
	var outside: Array[int] = []
	var jumps: Array[int] = []
	for index in cells.size():
		var cell := cells[index]
		if not allowed.has_point(cell):
			outside.append(index)
		if index > 0:
			var step := cell - cells[index - 1]
			if maxi(absi(step.x), absi(step.y)) > 1:
				jumps.append(index)
		if near_index < 0 and near.has_point(cell):
			near_index = index
		if middle_index < 0 and near_index >= 0 and index > near_index and middle.has_point(cell):
			middle_index = index
		if far_index < 0 and middle_index >= 0 and index > middle_index and far.has_point(cell):
			far_index = index
	var ends_far := not cells.is_empty() and far.has_point(cells.back())
	var ordered := near_index == 0 and middle_index > near_index and far_index > middle_index and ends_far
	return {"valid": ordered and outside.is_empty() and jumps.is_empty(), "ordered_mouth_middle_mouth": ordered, "allowed_cells": str(allowed), "near_mouth": str(near), "middle_cross_section": str(middle), "far_mouth": str(far), "near_index": near_index, "middle_index": middle_index, "far_index": far_index, "outside_indices": outside, "jump_indices": jumps, "observed_cell_count": cells.size()}


## Observe the real producer and its own counters; no route-forced beat or
## substitute director is created to satisfy this evidence.
func _director_evidence() -> Dictionary:
	var director := _game.get_node_or_null("EncounterDirector") as EncounterDirector
	if director == null:
		return {"present": false, "live": false}
	var spawner_bound := director._spawner != null and director._spawner == _game.get_node_or_null("Spawner")
	var player_bound := director._player == _player
	var live := director.enabled and director.is_physics_processing() and director.can_process() and spawner_bound and player_bound
	return {"present": true, "live": live, "path": str(director.get_path()), "enabled": director.enabled, "physics_processing": director.is_physics_processing(), "can_process": director.can_process(), "spawner_bound": spawner_bound, "player_bound": player_bound, "snapshot": director.balance_snapshot()}


## Initial staging only: unloaded cells are correctly unwalkable, so move the
## streaming centre first, wait for ordinary chunk/blocker activation, then
## resolve a free position. Recorded traversal starts after this search ends.
func _stream_walkable_near(desired: Vector2) -> Vector2:
	_player.global_position = desired
	_staging.append({"kind": "candidate streaming warp", "world": str(desired), "chunk": str(_chunks._world_to_chunk(desired))})
	await _settle()
	if _game != null:
		_dismiss_dossiers()
	return _walkable_near(desired)


func _still(name: String) -> void:
	_camera_points.append({"id": name, "phase": _phase, "player_world": str(_player.global_position), "camera_world": str(_camera.global_position), "zoom": str(_camera.zoom), "chunk": str(_chunks._current_center)})
	await super._still(name)


func _shutdown() -> void:
	# A failed discovery must leave the attempted chunks in its result too.
	if _report.is_empty():
		_report = {"capture_scene": "res://tools/dev/CityStreetTraversalProbe.tscn", "args": OS.get_cmdline_user_args(), "segment": _city_segment, "world_seed": _city_world_seed, "discovery": _discovery, "staging": _staging, "encounter_director_start": _director_start, "failures": _failures}
	var output := FileAccess.open(_out.path_join("traversal.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(_report, "\t"))
		output.close()
	await super._shutdown()


## A walkable cell centre within 12 cells of `desired`, or INF (no failure:
## the passage search simply tries the next chunk).
func _walkable_near(desired: Vector2) -> Vector2:
	var cell := _chunks.world_to_cell(desired)
	for radius in range(13):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) == radius and _chunks.is_cell_walkable(cell + Vector2i(x, y)):
					return _chunks.cell_to_world_center(cell + Vector2i(x, y))
	return Vector2.INF


func _nearest_passage(origin: Vector2) -> Dictionary:
	var best := {}
	var best_distance := INF
	for chunk: Node in _chunks.get_children():
		if not (chunk is Node2D) or not chunk.has_meta(&"_proc_frontage_passages"):
			continue
		var coord := _chunks._world_to_chunk((chunk as Node2D).global_position + Vector2.ONE)
		for rect: Rect2i in chunk.get_meta(&"_proc_frontage_passages"):
			var world := Rect2((chunk as Node2D).global_position + Vector2(rect.position) * _chunks.cell_size_px, Vector2(rect.size) * _chunks.cell_size_px)
			var center := world.get_center()
			var vertical := rect.size.y > rect.size.x
			var half := (world.size.y if vertical else world.size.x) * 0.5 + _chunks.cell_size_px * 0.5
			var axis := Vector2(0, 1) if vertical else Vector2(1, 0)
			var ends := [center - axis * half, center + axis * half]
			var ok := true
			for point: Vector2 in [ends[0], center, ends[1]]:
				if not _chunks.is_cell_walkable(_chunks.world_to_cell(point)): ok = false
			# Prefer a narrow (3-cell) passage between buildings: both long
			# sides blocked for at least half its length.
			var flanked := 0
			var length := rect.size.y if vertical else rect.size.x
			for t in length:
				var a := Vector2i(rect.position.x - 1, rect.position.y + t) if vertical else Vector2i(rect.position.x + t, rect.position.y - 1)
				var b := Vector2i(rect.end.x, rect.position.y + t) if vertical else Vector2i(rect.position.x + t, rect.end.y)
				var base := coord * _chunks._cells_per_chunk()
				if not _chunks.is_cell_walkable(base + a) and not _chunks.is_cell_walkable(base + b): flanked += 1
			var narrow := mini(rect.size.x, rect.size.y) <= 3 and flanked * 2 >= length
			var distance := center.distance_to(origin) + (0.0 if narrow else 100000.0)
			if ok and distance < best_distance:
				best_distance = distance
				best = {"world": world, "cells": rect, "chunk": coord, "center": center, "ends": ends, "narrow_between_buildings": narrow, "flanked_cells": flanked}
	return best


func _entry_target(origin: Vector2, infill: bool) -> Dictionary:
	var best := {}
	var best_distance := 3200.0
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		var volume := node as IndoorVolume
		if volume == null or volume.has_meta(&"dungeon_roof_volume") or volume.has_meta(&"city_street_infill") != infill:
			continue
		var entry: Variant = volume.get("_presentation_entry")
		var outward: Variant = volume.get("_presentation_outward")
		if not (entry is Vector2) or not (outward is Vector2) or (outward as Vector2) == Vector2.ZERO:
			continue
		var door := volume.to_global(entry)
		var roof: RoofOverlay = null
		for connection: Dictionary in volume.body_entered.get_connections():
			var subscriber: Object = (connection.callable as Callable).get_object()
			if subscriber is RoofOverlay: roof = subscriber as RoofOverlay
		if roof == null:
			continue
		var outside: Vector2 = door + (outward as Vector2) * 96.0
		if not _chunks.is_cell_walkable(_chunks.world_to_cell(outside)) or not _chunks.is_cell_walkable(_chunks.world_to_cell(door - (outward as Vector2) * float(_chunks.cell_size_px))):
			continue
		var distance := outside.distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			best = {"volume": volume, "roof": roof, "door": door, "outward": outward}
	return best


func _enter_and_exit(target: Dictionary, still_name: String) -> Dictionary:
	var volume: IndoorVolume = target.volume
	var roof: RoofOverlay = target.roof
	var door: Vector2 = target.door
	var outward: Vector2 = target.outward
	var events_before := _events.size()
	await _walk_to(door + outward * 96.0)
	await _walk_to(door - outward * float(_chunks.cell_size_px))
	await _wait_seconds(0.6)
	var opened := roof._inside_count > 0 and (roof.get_node("RoofPoly") as Polygon2D).modulate.a < 0.01
	if not opened: _fail("Entry did not open the roof of building %d" % volume.building_id)
	await _still(still_name)
	await _walk_to(door + outward * 160.0)
	await _wait_seconds(0.6)
	var restored := roof._inside_count == 0 and (roof.get_node("RoofPoly") as Polygon2D).modulate.a > 0.99
	if not restored: _fail("Exit did not restore the roof of building %d" % volume.building_id)
	var mine := _events.slice(events_before).filter(func(event: Dictionary) -> bool: return int(event.building_id) == volume.building_id)
	var infill := volume.has_meta(&"city_street_infill")
	if mine.is_empty(): _fail("No building-entered event for building %d" % volume.building_id)
	elif infill and bool(mine[0].first_visit): _fail("Infill building %d counted as a first exploration visit" % volume.building_id)
	elif not infill and not bool(mine[0].first_visit): _fail("Original building %d did not count as a first visit" % volume.building_id)
	return {"building_id": volume.building_id, "infill": infill, "door": str(door), "opened": opened, "restored": restored, "events": mine}


func _on_entered_building(volume: Node, first_visit: bool) -> void:
	var indoor := volume as IndoorVolume
	_events.append({"building_id": indoor.building_id if indoor != null else 0, "infill": indoor != null and indoor.has_meta(&"city_street_infill"), "first_visit": first_visit, "phase": _phase})


func _stage_pickup(desired: Vector2) -> void:
	var data := Global.get_item_data("ring_crusher")
	if data == null:
		_fail("Missing ordinary ring item")
		return
	var pickup := ITEM_SCENE.instantiate() as ItemPickup
	_pickup_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25, false)
	pickup.item_instance = _pickup_instance
	pickup.position = _free_spawn_position(desired)
	_game.add_child(pickup)
	_pickup_ref = weakref(pickup)
	_pickup_state = {"item_id": data.id, "world": str(pickup.global_position), "delay": pickup.pickup_delay, "picked": false}
	_staging.append({"kind": "ordinary ring item", "world": str(pickup.global_position)})
	pickup.tree_exiting.connect(func() -> void:
		_pickup_state["picked"] = pickup._picked
		_pickup_state["collection_distance"] = pickup.global_position.distance_to(_player.global_position))


func _inventory_has(instance: ItemInstance) -> bool:
	if instance == null:
		return false
	for slot in range(Inventory.SLOT_COUNT):
		if Global.run_inventory.get_at(slot) == instance: return true
	for item: ItemInstance in Global.run_bag.slots:
		if item == instance: return true
	return false


## A walkable point two cells past the nearest seam of the player's chunk.
func _nearest_crossing(origin: Vector2) -> Vector2:
	var coord := _chunks._world_to_chunk(origin)
	var size := float(_chunks.chunk_size_px)
	var tl := Vector2(coord) * size
	var options: Array[Vector2] = [
		Vector2(tl.x - 128.0, origin.y), Vector2(tl.x + size + 128.0, origin.y),
		Vector2(origin.x, tl.y - 128.0), Vector2(origin.x, tl.y + size + 128.0)]
	options.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(origin) < b.distance_to(origin))
	for option: Vector2 in options:
		var point := _free_spawn_position(option)
		if _chunks._world_to_chunk(point) != coord:
			return point
	return options[0]


func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		if get_tree().paused:
			_dismiss_dossiers()


## Bounded replanning walker, as in CityMovingCoverPreview (2026-10-20): grid
## path over walkable cells, input-driven steps through real collisions, an
## obstructed cell recorded with its actual contacts and replanned around,
## capsule-tested sidesteps; the destination itself stays mandatory.
func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	# Route goals are walkable cell centers, not enemy-spawn reservations.
	# A shooter staged here earlier may already be hundreds of pixels away.
	var goal := _chunks.world_to_cell(desired)
	if _passage_corridor.has_area() and (not _passage_corridor.has_point(goal) or not _chunks.is_cell_walkable(goal)):
		_fail("Mandatory passage destination is blocked or outside its corridor: " + str(goal))
		return
	if not _chunks.is_cell_walkable(goal):
		var found := false
		for radius in range(1,7):
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					if maxi(absi(x),absi(y)) != radius: continue
					var candidate := goal + Vector2i(x,y)
					if _chunks.is_cell_walkable(candidate):
						goal = candidate
						found = true
						break
				if found: break
			if found: break
		if not found:
			_fail("No walkable mandatory route destination near " + str(desired))
			return
	var resolved := _chunks.cell_to_world_center(goal)
	if strict_perimeter and resolved.distance_to(desired) > 64:
		_fail("Mandatory perimeter destination moved outside its intended cell")
		return
	var blocked: Dictionary = {}
	var reached := false
	var walked_cells := 0
	var retries: Array[Dictionary] = []
	for attempt in range(9):
		var start := _chunks.world_to_cell(_player.global_position)
		if _player.global_position.distance_to(resolved) < 8:
			reached = true
			break
		var path := _live_path(start,goal,blocked)
		if path.is_empty() and start != goal:
			retries.append({"attempt":attempt,"event":"no alternative grid path","world":str(_player.global_position)})
			if not await _live_sidestep(resolved,blocked): break
			continue
		if path.is_empty(): path.append(goal)
		var obstructed := false
		for cell: Vector2i in path:
			walked_cells += 1
			if await _live_step(_chunks.cell_to_world_center(cell)):
				continue
			var contacts: Array[Dictionary] = []
			for index in range(_player.get_slide_collision_count()):
				var collision := _player.get_slide_collision(index)
				var collider: Object = collision.get_collider()
				var identity := str(collider)
				if collider is Node and is_instance_valid(collider) and (collider as Node).is_inside_tree():
					identity = str((collider as Node).get_path())
				contacts.append({"collider":identity,"class":collider.get_class() if is_instance_valid(collider) else "freed", "position":str(collision.get_position()), "normal":str(collision.get_normal())})
			retries.append({"attempt":attempt,"event":"physical obstruction","cell":str(cell),"world":str(_player.global_position),"remaining":_player.global_position.distance_to(_chunks.cell_to_world_center(cell)),"contacts":contacts})
			# Replan around the actually obstructed cell. The final goal itself
			# remains mandatory and can be retried after an input-driven sidestep.
			if cell != goal: blocked[cell] = true
			obstructed = true
			break
		if not obstructed and _player.global_position.distance_to(resolved) < 8:
			reached = true
			break
		if not await _live_sidestep(resolved,blocked): break
	_release_inputs()
	_route_notes.append({"event":"walk","phase":_phase,"desired":str(desired),"resolved":str(resolved),"resolution_distance":resolved.distance_to(desired),"arrived":str(_player.global_position),"arrival_distance":_player.global_position.distance_to(resolved),"destination_reached":reached,"path_cells":walked_cells,"replans":retries})
	if not reached:
		_fail("Mandatory live route destination was not reached after bounded replanning: " + str(goal))


func _live_path(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	if _passage_corridor.has_area() and (not _passage_corridor.has_point(start) or not _passage_corridor.has_point(goal)):
		return []
	var previous: Dictionary = {start:start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not previous.has(goal):
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell + direction
			if _passage_corridor.has_area() and not _passage_corridor.has_point(next): continue
			if previous.has(next) or blocked.has(next) or absi(next.x-start.x)>40 or absi(next.y-start.y)>40 or not _chunks.is_cell_walkable(next): continue
			previous[next] = cell
			queue.append(next)
	var path: Array[Vector2i] = []
	if not previous.has(goal): return path
	var cell := goal
	while cell != start:
		path.push_front(cell)
		cell = previous[cell]
	return path


func _live_step(target: Vector2) -> bool:
	var last_progress := _player.global_position
	var still_ticks := 0
	for tick in range(120):
		var movement := target - _player.global_position
		if movement.length() < 8: return true
		var axis := movement.normalized()
		_set_axis(&"move_left",&"move_right",axis.x)
		_set_axis(&"move_up",&"move_down",axis.y)
		await get_tree().physics_frame
		if get_tree().paused: return false
		if _player.global_position.distance_to(last_progress) < 1.0:
			still_ticks += 1
		else:
			still_ticks = 0
			last_progress = _player.global_position
		if still_ticks >= 30: return false
	return false


func _live_sidestep(goal: Vector2, blocked: Dictionary) -> bool:
	# Test the actual unchanged player capsule against current physical bodies;
	# select one clear nearby step, then perform it using production input.
	var current := _chunks.world_to_cell(_player.global_position)
	var best := Vector2.INF
	var best_score := INF
	for direction: Vector2i in [Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT,Vector2i.LEFT,Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var cell := current + direction
		if _passage_corridor.has_area() and not _passage_corridor.has_point(cell): continue
		if blocked.has(cell) or not _chunks.is_cell_walkable(cell): continue
		var point := _chunks.cell_to_world_center(cell)
		if _player.test_move(_player.global_transform,point-_player.global_position): continue
		var score := point.distance_to(goal)
		if score < best_score:
			best_score = score
			best = point
	if best == Vector2.INF:
		# Keep native aim/fire active briefly so live enemies can move/die. This
		# is a bounded retry, not collision suppression or an arrival shortcut.
		_set_axis(&"move_left",&"move_right",0)
		_set_axis(&"move_up",&"move_down",0)
		await _wait_seconds(0.5)
		return true
	await _live_step(best)
	return true
