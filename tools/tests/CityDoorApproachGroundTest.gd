extends Node
## Generate real rectangular and recessed L homes in every direction, paint
## their recorded stamps through the production splat renderer, then inspect
## ground at the independently configured presentation entry and footprint.

const PARCELS := preload("res://core/systems/world/proc/SiteParcelsImpl.gd")
const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const CELL := 64
var _checks := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	Global.attempt_segment = 2
	var splat := GroundSplatRenderer.new()
	splat.configure(CELL, 32)
	add_child(splat)
	var fixtures := 0
	for irregular: bool in [false, true]:
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
			var cm := ChunkManager.new()
			cm.world_seed = 701 + fixtures
			cm.generation_enabled = false
			cm.ground_enabled = true
			cm.ground_splat_enabled = false
			cm.world_atmosphere_enabled = false
			cm.decals_enabled = false
			cm.deco_enabled = false
			cm.sites_enabled = false
			cm.cover_full_scene = COVER_FULL
			cm.cover_window_scene = COVER_WINDOW
			add_child(cm)
			cm.set_process(false)
			cm._gen_coord = Vector2i.ZERO
			cm._chunk_blocked[Vector2i.ZERO] = []
			var data := ChunkBuildData.new(Vector2i.ZERO, 32)
			cm._active_build_data = data
			var chunk := Node2D.new()
			cm.add_child(chunk)
			var generator := PARCELS.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = cm.world_seed
			var placed: Array[Rect2i] = []
			var cfg := {"city_block_style": true, "city_shared_ground": true, "parcel_door_width": 2, "parcel_apron_len": 2, "parcel_recess_chance": 1.0, "facility_window_chance": 0.0}
			var region := Rect2i(8, 8, 12, 10)
			var extent := Rect2i(0, 0, 32, 32)
			var spawned := generator._spawn_building_footprint(cm, chunk, Vector2i.ZERO, region, direction, &"row_house", [], placed, cfg, rng, extent) if irregular else generator._spawn_building_rect(cm, chunk, Vector2i.ZERO, region, direction, &"row_house", [], placed, cfg, rng, extent)
			var tag := "irregular=%s direction=%s" % [str(irregular), str(direction)]
			_check(spawned, "Generated home did not fit: " + tag)
			var volume: IndoorVolume = null
			var kit: Node = null
			for child: Node in chunk.get_children():
				if child is IndoorVolume and float(child.get("_presentation_width")) > 0.0:
					volume = child as IndoorVolume
				if child.is_in_group(&"city_block_building"):
					kit = child
			_check(volume != null and kit != null, "Generated home lacks its actual entry/kit: " + tag)
			if volume != null and kit != null:
				var entry := volume.to_global(volume.get("_presentation_entry"))
				var outward: Vector2 = volume.get("_presentation_outward")
				var across := Vector2(-outward.y, outward.x)
				var width: float = volume.get("_presentation_width")
				var outline := GEOMETRY.outline_for(kit)
				_check(not irregular or outline.size() > 4, "Irregular fixture lost its real concave footprint: " + tag)
				splat.set_chunk_base(Vector2i.ZERO, 0)
				splat.paint_chunk_stamps(data)
				var core_ok := true
				var shoulders_ok := true
				var beyond_ok := true
				var outside_footprint := true
				var physical_clear := true
				var core_depth := 2 + (1 if irregular else 0)
				# Quarter-width offsets are the centres of the two actual door
				# cells, measured from IndoorVolume, not from the apron planner.
				for depth in range(1, core_depth + 1):
					for side: float in [-0.25, 0.25]:
						var point := entry + outward * float(depth * CELL) + across * width * side
						var cell := cm.world_to_cell(point)
						core_ok = core_ok and splat.material_at(cell) == 4
						outside_footprint = outside_footprint and not Geometry2D.is_point_in_polygon(point, outline)
					for side: float in [-1.0, 1.0]:
						var point := entry + outward * float(depth * CELL) + across * (width * 0.5 + CELL * 0.5) * side
						shoulders_ok = shoulders_ok and splat.material_at(cm.world_to_cell(point)) != 4
				for side: float in [-0.25, 0.25]:
					var point := entry + outward * float((core_depth + 1) * CELL) + across * width * side
					beyond_ok = beyond_ok and splat.material_at(cm.world_to_cell(point)) != 4
				for side in range(-1, 2):
					var cell := cm.world_to_cell(entry + outward * CELL + across * float(side * CELL))
					physical_clear = physical_clear and data.kind_at(cell) < 0
				_check(core_ok, "Actual doorway core does not join its first outside cell continuously: " + tag)
				_check(shoulders_ok, "Opaque lane allocation extends into the doorway shoulders: " + tag)
				_check(beyond_ok, "Opaque lane allocation extends beyond the doorway approach: " + tag)
				_check(outside_footprint, "Door approach enters the actual building footprint: " + tag)
				_check(physical_clear, "Three-cell physical door approach is obstructed: " + tag)
			cm.free()
			fixtures += 1
	print("CityDoorApproachGroundTest: fixtures=%d checks=%d failures=%d" % [fixtures, _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
