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
## ring item, god mode, modal onboarding bypass, scripted movement. Nothing is
## frozen: no actor freeze, never_cull, pickup override or direct collection.
## -- --segment=2 [--world-seed=16102026] --out=<fresh absolute directory>

const ITEM_SCENE := preload("res://scenes/world/pickups/ItemPickup.tscn")

var _events: Array[Dictionary] = []
var _staging: Array[Dictionary] = []
var _route_cells: Array[String] = []
var _centers: Array[String] = []
var _pickup_ref: WeakRef
var _pickup_instance: ItemInstance
var _pickup_state: Dictionary = {}
var _report: Dictionary = {}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("The traversal records native stills; run with a renderer")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
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
	var start := _player.global_position
	var passage := _nearest_passage(start)
	if passage.is_empty():
		_fail("No recorded frontage passage streamed near the start")
		await _shutdown()
		return
	var ends: Array = passage.ends
	_player.global_position = _free_spawn_position(ends[0] + (ends[0] - ends[1]).normalized() * 192.0)
	_staging.append({"kind": "player initial warp beside a recorded passage", "start": str(start), "warp": str(_player.global_position), "passage_world": str(passage.world)})
	await _settle()
	_dismiss_dossiers()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_centers.append(str(_chunks._current_center))
	await _frames(4)
	# 1. The narrow passage, end to end through its middle.
	_phase = "passage"
	await _walk_to(ends[0])
	await _walk_to(passage.center)
	var inside_passage := (passage.world as Rect2).has_point(_player.global_position)
	if not inside_passage: _fail("The player did not stand inside the passage " + str(passage.world))
	await _still("traversal-1-passage")
	await _walk_to(ends[1])
	var through := (_player.global_position - (ends[1] as Vector2)).length() < 48.0
	if not through: _fail("The player did not come out of the passage's far end")
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
	_release_inputs()
	_report = {"capture_scene": "res://tools/dev/CityStreetTraversalProbe.tscn", "scene": "res://scenes/game.tscn", "args": OS.get_cmdline_user_args(),
		"segment": _city_segment, "world_seed": _city_world_seed, "window": str(get_window().size), "camera_zoom": str(_camera.zoom),
		"passage": {"world": str(passage.world), "cells": str(passage.cells), "chunk": str(passage.chunk), "inside": inside_passage, "through": through},
		"original_entry": entry, "infill_entry": infill_entry, "building_events": _events,
		"pickup": _pickup_state, "collected": collected,
		"boundary": {"before": str(before_center), "after": str(after_center), "crossed": crossed, "target": str(crossing)},
		"chunk_centers": _centers, "route": _route_notes, "staging": _staging, "failures": _failures,
		"decoration": _chunks.deco_enabled, "street_continuity": _chunks.street_continuity_enabled,
		"limits": "Staged: initial player warp beside the passage, one ordinary ring item, god mode, modal onboarding bypass, scripted input movement. Live: streaming, ambient spawner, procedural director, enemy scheduler, decoration, collisions, roof fades, pickup delay/magnet/contact. No actor freeze, never_cull, pickup override or direct collection. Not a performance or human-play test."}
	var output := FileAccess.open(_out.path_join("traversal.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(_report, "\t"))
		output.close()
	print("CityStreetTraversalProbe: passage=%s through=%s original_entry=%s infill_entry=%s collected=%s crossed=%s failures=%d" % [str(inside_passage), str(through), str(entry.get("restored", false)), str(infill_entry.get("restored", false)), str(collected), str(crossed), _failures])
	await _shutdown()


func _process(_delta: float) -> void:
	if _player != null and _camera != null:
		_camera.global_position = _player.global_position
		_camera.rotation = 0.0


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
			var distance := center.distance_to(origin)
			if ok and distance < best_distance:
				best_distance = distance
				best = {"world": world, "cells": rect, "chunk": coord, "center": center, "ends": ends}
	return best


func _entry_target(origin: Vector2, infill: bool) -> Dictionary:
	var best := {}
	var best_distance := 1800.0
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
