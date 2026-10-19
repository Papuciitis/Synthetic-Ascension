extends "res://tools/dev/S10BossTelegraphPreview.gd"

const LARGE_OUT := "res://docs/art/reference/2026-10-19-dungeon-architecture-v1/final-facilities/"
var _cm: ChunkManager
var _builder: SegmentProcBuilder
var _large_notes: Array[Dictionary] = []
var _fight_fires := 0
var _fight_hits := 0
var _fight_deaths := 0

func _run() -> void:
	_out = LARGE_OUT
	var early := "--review=runtime" in OS.get_cmdline_user_args()
	if early: _out = "res://docs/art/reference/2026-10-19-dungeon-architecture-v1/final-runtime/"
	var donjon: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/reference/2026-10-19-large-site-walls/actual-donjon-candidate.json"))
	var only_donjon := "--donjon-only" in OS.get_cmdline_user_args()
	var capture_seed := 16102026
	var capture_segment := 2
	if only_donjon:
		capture_seed = int(donjon.candidate.attempt_seed)
		capture_segment = int(donjon.candidate.segment)
		_out = "res://docs/art/reference/2026-10-19-dungeon-architecture-v1/final-district/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.trim_prefix("--out=")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_out)) and not DirAccess.get_files_at(_out).is_empty():
		_fail("Evidence folder already contains files; choose a new --out directory")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	SettingsManager.set_value(&"accessibility",&"combat_flash","off",false)
	SettingsManager.set_value(&"accessibility",&"reduced_motion",true,false)
	SettingsManager.set_value(&"controls",&"hold_to_attack",true,false)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.selected_weapon_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = capture_segment
	Global.attempt_world_seed = capture_seed
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().size = Vector2i(1280,720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	var configured := _game.get_node("ChunkManager") as ChunkManager
	configured.use_camera_stream_bounds = false
	configured.load_radius = 1
	configured.unload_radius = 2
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_cm = configured
	await _settle()
	_quiet_tutorials()
	_builder = get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	_builder.set_process(false)
	_cm.set_process(false)
	var candidates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/reference/2026-10-19-large-site-walls/actual-site-candidates.json"))
	for sample: Dictionary in candidates.samples:
		if only_donjon: break
		if early and int(sample.size_chunks[1]) != 1: continue
		await _facility(sample)
	if not donjon.get("candidate",{}).is_empty() and int(donjon.candidate.segment) == capture_segment and int(donjon.candidate.attempt_seed) == capture_seed:
		await _donjon(donjon.candidate)
	elif only_donjon: _fail("No genuine Donjon candidate available")
	var hashes: Array[Dictionary] = []
	for path: String in ["core/systems/world/proc/SiteOverlayImpl.gd","core/systems/world/proc/RectFacilityCarver.gd","core/systems/world/proc/DonjonCarver.gd","core/systems/world/proc/chunkgen/ChunkGenDistrict.gd","core/systems/world/proc/SiteParcelsImpl.gd","core/systems/world/chunks/ChunkBlockVisualCatalog.gd","core/systems/world/chunks/ChunkBlockRenderer.gd","core/systems/world/chunks/ChunkBlockPhysics.gd","core/systems/world/ChunkManager.gd"]:
		hashes.append({"path":path,"sha256":FileAccess.get_sha256("res://"+path)})
	for path: String in ["core/systems/world/proc/DungeonLayout.gd","scenes/world/buildings/DungeonBuilding.gd","scenes/world/buildings/DungeonRoof.gd","assets/world/city_block/donjon_gate_arch.png","assets/world/city_block/donjon_cell_grille.png"]:
		hashes.append({"path":path,"sha256":FileAccess.get_sha256("res://"+path)})
	for path: String in ["core/actors/player/PlayerRoofOcclusion.gd","assets/world/city_block/donjon_masonry_bay.png","assets/world/city_block/slate.png","assets/world/city_block/clay.png","assets/world/city_block/paving.png","assets/world/city_block/wall_lantern.png","assets/world/city_block/pressure_plant.png","assets/world/city_block/planted_corner.png","assets/world/city_block/temperate_tree.png","scenes/world/buildings/roof.gdshader","scenes/world/buildings/city_paving.gdshader"]:
		hashes.append({"path":path,"sha256":FileAccess.get_sha256("res://"+path)})
	var writes := SaveManager.debug_save_writes-_save_writes_before
	var file := FileAccess.open(_out.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"attempt_seed":capture_seed,"segment":capture_segment,"mixed_world_seed":_cm.world_seed,"captures":_captures,"notes":_large_notes,"source_hashes":hashes,"failures":_failures,"save_writes":writes,"presentation":"Actual Game enclosed dungeon architecture. Overview zoom explicitly recorded. New authoritative procedural dungeon layouts; frozen art poses, physical routes and seam rays explicitly recorded."},"\t"))
	file.close()
	print("DungeonFinalCapture: captures=%d failures=%d save_writes=%d" % [_captures.size(),_failures,writes])
	get_tree().current_scene = null
	_game.queue_free()
	await _frames(5)
	get_tree().quit(0 if _failures == 0 and writes == 0 else 1)

func _aim(at: Vector2) -> void:
	_camera.top_level = true
	_camera.global_position = at
	_camera.reset_smoothing()
	_camera.force_update_scroll()

func _stream_at(center: Vector2) -> void:
	_cm.set_process(false)
	_cm._current_center = _cm._world_to_chunk(center)
	_cm._update_streaming()
	for frame in range(600):
		_cm.process_chunk_generation_queue(2)
		_cm.flush_pending_blocker_stages()
		await get_tree().process_frame
		if frame >= 12 and _cm.debug_chunk_queue().is_empty() and _cm.pending_blocker_stage_count() == 0: return
	_fail("Large interior streaming did not settle")

func _facility(sample: Dictionary) -> void:
	var root := Vector2i(sample.root[0],sample.root[1])
	var site = _cm._site_mgr._overlay._get_plan(root,_cm,{"site_padding_cells":2})
	var center := Vector2(root)*2048+(Vector2(site.region.position)+Vector2(site.region.size)*0.5)*64
	var outward: Vector2 = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][site.door_side]
	var inward := -outward
	var perp := Vector2(-inward.y,inward.x)
	var door := Vector2(root)*2048+(Vector2(site.door_pos)+Vector2(0.5,0.5)+perp*(-float(site.door_width>>1)+float(site.door_width-1)*0.5))*64
	_player.global_position = door+outward*96
	await _stream_at(center)
	_quiet_tutorials()
	var data_check := _check_site_data(site,root)
	var key := "facility-%dx%d" % [site.size_chunks.x,site.size_chunks.y]
	var meta := {"family":"multi_chunk_dungeon_compound","root":str(root),"size_chunks":str(site.size_chunks),"region_cells":str(site.region),"site_seed_decimal":str(site.site_seed),"building_id":sample.building_id,"door_world":str(door),"roof_present":true}
	meta["actual_streamed_data"] = data_check
	_camera.zoom = Vector2.ONE*(0.24 if site.size_chunks.y == 2 else 0.43)
	_aim(center)
	meta["overview_camera_zoom"] = _camera.zoom.x
	var hud := _game.get_node("UI/HUD") as CanvasItem
	hud.visible = false
	meta["overview_hud_hidden"] = true
	await _shot_pair(key+"-overview","Zoomed-out layout inspection of an actual unmodified production site; not native gameplay framing",meta)
	hud.visible = true
	_camera.zoom = Vector2.ONE
	_aim(door-inward*60)
	await _shot_pair(key+"-outside","Native gameplay zoom1 at actual compound doorway and roof wings",meta)
	var rays: Array[Dictionary] = []
	for vertical in [true,false]:
		if (site.size_chunks.x < 2 if vertical else site.size_chunks.y < 2): continue
		for cell: Vector2i in site.carve.wall_cells:
			var neighbor := cell+(Vector2i.RIGHT if vertical else Vector2i.DOWN)
			if (cell.x != 31 if vertical else cell.y != 31) or not site.carve.wall_cells.has(neighbor): continue
			if site.carve.window_cells.has(cell) or site.carve.window_cells.has(neighbor): continue
			var at := Vector2(root)*2048+(Vector2(cell)+Vector2(0.5,0.5))*64+(Vector2.RIGHT if vertical else Vector2.DOWN)*32
			var across := Vector2.DOWN if vertical else Vector2.RIGHT
			var query := PhysicsRayQueryParameters2D.create(at-across*40,at+across*40,1,[(_player as CollisionObject2D).get_rid()])
			var hit := _game.get_world_2d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): _fail("Actual native seam collider has a hole at "+str(at))
			rays.append({"at":str(at),"seam":"x" if vertical else "y","hit":not hit.is_empty()})
			_aim(at)
			await _shot_pair(key+("-x-seam" if vertical else "-y-seam"),"Native zoom1 shared-chunk wall; ray checked actual world collider",meta)
			break
	_aim(door)
	await _walk_line(door-outward*64)
	var return_points: Array[Vector2] = [_player.global_position]
	var architecture: Dictionary = site.architecture
	var initial_inside := _inside_id(int(sample.building_id))
	if not initial_inside:
		var origin := Vector2(root)*2048
		var room: Rect2i = architecture.rooms[0]
		var route: Array[Vector2] = [origin+(Vector2(architecture.court.get_center())+Vector2.ONE*0.5)*64,origin+(Vector2(architecture.portals[0])+Vector2.ONE*0.5)*64,origin+(Vector2(room.get_center())+Vector2.ONE*0.5)*64]
		for target: Vector2 in route:
			await _path_walk(target)
			return_points.append(_player.global_position)
	var inside := false
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if volume is IndoorVolume and volume.building_id == int(sample.building_id) and volume.contains_world_point(_player.global_position): inside = true
	if not inside: _fail("Physical facility entry did not reach its actual indoor volume")
	_aim(_player.global_position)
	await _frames(14)
	await _shot_pair(key+"-inside","Native zoom1 after physical entry into actual roofed dungeon wing",meta)
	var entry_pose := _player.global_position
	var hall_room: Rect2i = architecture.rooms[-2]
	var hall_pose := Vector2(root)*2048+(Vector2(hall_room.get_center())+Vector2.ONE*0.5)*64
	_player.global_position = _nearest_walkable(hall_pose)
	_aim(_player.global_position+Vector2(60,0))
	await _frames(15)
	await _shot_pair(key+"-west-hall","Frozen actual west hall/cell/service sequence for art inspection; staged pose, not a traversal claim",meta)
	_player.global_position = entry_pose
	await _frames(14)
	var restored_wing_count := 0
	for node: Node in get_tree().get_nodes_in_group(&"roof_occluders"):
		if node.has_meta(&"dungeon_wing") and node._inside_count > 0:
			restored_wing_count += 1
			if node.get_node("RoofPoly").modulate.a > 0.01: _fail("Entered dungeon roof did not cut away")
	if restored_wing_count == 0: _fail("No dungeon wing acknowledged actual entry")
	return_points.reverse()
	for target: Vector2 in return_points: await _path_walk(target)
	await _walk_line(door+outward*96)
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if volume is IndoorVolume and volume.building_id == int(sample.building_id) and volume.contains_world_point(_player.global_position): _fail("Physical exit remained inside the large facility")
	await _frames(14)
	_aim(door)
	await _shot_pair(key+"-roof-restored","Native zoom1 after physical exit; separate dungeon roofs restored",meta)
	_large_notes.append({"family":meta,"seam_rays":rays,"physical_entry_inside":inside,"door_exit_position":str(_player.global_position)})
	if "--review=runtime" in OS.get_cmdline_user_args(): await _runtime_proof(site,root,door,outward,int(sample.building_id))

func _inside_id(id: int) -> bool:
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if volume is IndoorVolume and volume.building_id == id and volume.contains_world_point(_player.global_position): return true
	return false

func _runtime_proof(site, root: Vector2i, door: Vector2, outward: Vector2, id: int) -> void:
	var origin := Vector2(root)*2048
	var rooms: Array = site.architecture.rooms
	var route_steps := 0
	for index in range(rooms.size()-3,rooms.size()):
		var room: Rect2i = rooms[index]
		route_steps += await _path_walk(_nearest_walkable(origin+(Vector2(room.get_center())+Vector2.ONE*0.5)*64))
		if not _inside_id(id): _fail("Physical west hall route lost actual roofed indoor ownership")
	_aim(_player.global_position)
	await _frames(15)
	await _shot_pair("runtime-physical-west-hall","Physically walked from original outside doorway through court into all three west-wing rooms",{"walked_cells":route_steps})
	var before := _site_signature(site,root)
	var center := origin+(Vector2(site.region.position)+Vector2(site.region.size)*0.5)*64
	await _stream_at(center+Vector2(2048*80,0))
	for y in range(site.size_chunks.y):
		for x in range(site.size_chunks.x):
			if _cm._chunks.has(root+Vector2i(x,y)): _fail("Actual streaming did not unload original dungeon slice")
	await _stream_at(center)
	var equal := before == _site_signature(site,root)
	if not equal: _fail("Dungeon reload changed real blockers/floors/volumes/roof geometry")
	var hidden := 0
	for roof: Node in get_tree().get_nodes_in_group(&"roof_occluders"):
		if roof.has_meta(&"dungeon_wing") and roof._inside_count > 0:
			hidden += 1
			if roof.get_node("RoofPoly").modulate.a > 0.01: _fail("Reload while indoors flashed an opaque dungeon roof")
	if hidden == 0: _fail("Reload lost site-wide indoor roof coverage")
	await _shot_pair("runtime-reloaded-inside","Actual streamed unload/rebuild while player remained inside; blockers/floors/IDs/roof geometry equal",{"signature_equal":equal,"cutaway_roofs":hidden})
	route_steps += await _path_walk(door+outward*160)
	await _frames(15)
	_aim(door)
	await _shot_pair("runtime-exit-restored","Physically exited after reload; original entrance retained",{})
	var security_enabled := false
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if volume is IndoorVolume and volume.building_id == id: security_enabled = security_enabled or volume.local_encounter_enabled
	_large_notes.append({"runtime":"physical_hall_and_reload","walked_cells":route_steps,"reload_equal":equal,"reloaded_cutaway_roofs":hidden,"local_security_enabled":security_enabled,"security_contract":"Existing facilities have no local security encounter; no guards/reward rebalance added."})
	await _live_fight(door+outward*320)

func _site_signature(site, root: Vector2i) -> String:
	var records: Array = []
	for y in range(site.size_chunks.y):
		for x in range(site.size_chunks.x):
			var coord := root+Vector2i(x,y)
			var data := _cm.get_chunk_build_data(coord)
			if data == null: return "missing"
			var volumes: Array[String] = []
			var geometry: Array[String] = []
			for child: Node in (_cm._chunks[coord] as Node).get_children():
				if child is IndoorVolume: volumes.append(str([child.building_id,child.cell_tl,child.size_cells,child.site_area_cells]))
				if child.is_in_group(&"dungeon_architecture"):
					for roof: Node in child.get_children():
						if roof is RoofOverlay:
							geometry.append(str([roof.position,roof.get_node("RoofPoly").position,roof.get_node("RoofPoly").polygon]))
			volumes.sort()
			records.append([data.blocker_kind_code,data.blocker_mask,data.blocker_variant,data.floor_rect_and_style,volumes,geometry])
	return str(records).sha256_text()

func _path_walk(target: Vector2) -> int:
	var start := _cm.world_to_cell(_player.global_position)
	var goal := _cm.world_to_cell(target)
	var queue: Array[Vector2i] = [start]
	var previous := {start:start}
	var cursor := 0
	while cursor < queue.size() and not previous.has(goal):
		var at := queue[cursor]
		cursor += 1
		for dir: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := at+dir
			if previous.has(next) or absi(next.x-start.x)>96 or absi(next.y-start.y)>96 or not _cm.is_cell_walkable(next): continue
			previous[next] = at
			queue.append(next)
	if not previous.has(goal): _fail("No actual blocker-data route to dungeon target "+str(target)); return 0
	var path: Array[Vector2i] = []
	var at := goal
	while at != start:
		path.append(at)
		at = previous[at]
	path.reverse()
	for cell: Vector2i in path: await _walk_line(_cm.cell_to_world_center(cell))
	return path.size()

func _live_fight(at: Vector2) -> void:
	RunEvents.weapon_fired.connect(func(_s: Node,_style: StringName,_f: Vector2,_t: Vector2,_p: float,_h: float) -> void: _fight_fires += 1)
	RunEvents.player_hit_landed.connect(func(_s: Node,_h: int,_p: Vector2,_a: float,_c: bool,_e: bool) -> void: _fight_hits += 1)
	RunEvents.enemy_defeated.connect(func(_ctx: RefCounted) -> void: _fight_deaths += 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.path_join("fight-frames")))
	var frame_index := 0
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		get_window().size = dimensions
		await _frames(5)
		_player.global_position = _nearest_walkable(at)
		var origin := _player.global_position
		_aim(origin+Vector2(0,140))
		var actors: Array[EnemyActor] = []
		for index in range(20):
			var actor := preload("res://core/actors/enemy/enemy.tscn").instantiate() as EnemyActor
			actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % ["Grunt","Brute","Spitter","Orbiter"][index%4])
			var angle := index*2.39996323
			actor.position = _nearest_walkable(origin+Vector2(cos(angle),sin(angle))*float(180+index%3*65))
			_game.add_child(actor)
			actor.player = _player
			actors.append(actor)
		_quiet_tutorials()
		var before := Vector3i(_fight_fires,_fight_hits,_fight_deaths)
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		Input.action_press(&"attack")
		for tick in range(240):
			var time := float(tick)/60.0
			var movement := (origin+Vector2(sin(time)*88,cos(time)*58)-_player.global_position).normalized()
			var nearest: EnemyActor
			var distance := INF
			for actor: EnemyActor in actors:
				if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_squared_to(_player.global_position)<distance:
					nearest = actor
					distance = actor.global_position.distance_squared_to(_player.global_position)
			var aim := _player.global_position.direction_to(nearest.global_position) if nearest != null else Vector2.RIGHT
			for pair: Array in [[&"move_left",maxf(0,-movement.x)],[&"move_right",maxf(0,movement.x)],[&"move_up",maxf(0,-movement.y)],[&"move_down",maxf(0,movement.y)],[&"aim_left",maxf(0,-aim.x)],[&"aim_right",maxf(0,aim.x)],[&"aim_up",maxf(0,-aim.y)],[&"aim_down",maxf(0,aim.y)]]:
				if pair[1]>0: Input.action_press(pair[0],pair[1])
				else: Input.action_release(pair[0])
			await get_tree().physics_frame
			if tick%15 == 0:
				await RenderingServer.frame_post_draw
				var file := _out.path_join("fight-frames/frame-%04d.png" % frame_index)
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
				frame_index += 1
		for action: StringName in [&"attack",&"move_left",&"move_right",&"move_up",&"move_down",&"aim_left",&"aim_right",&"aim_up",&"aim_down"]: Input.action_release(action)
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		var counts := Vector3i(_fight_fires,_fight_hits,_fight_deaths)-before
		if counts.x == 0 or counts.y == 0: _fail("Populated dungeon-front fight did not exercise actual attacks and hits")
		_large_notes.append({"combat_window":str(dimensions),"controlled_population":20,"fires":counts.x,"hits":counts.y,"deaths":counts.z,"frames":16,"god_mode":true,"scripted_input":true,"reduced_motion":true,"combat_flashes":"off","timing_limit":"Readback fixture, not a performance benchmark"})
		for actor: EnemyActor in actors:
			if is_instance_valid(actor): actor.queue_free()
		await _frames(3)

func _check_site_data(site, root: Vector2i) -> Dictionary:
	var missing := 0
	var bad_mask := 0
	var bad_flag := 0
	for cell: Vector2i in site.carve.wall_cells:
		var offset := Vector2i(floori(float(cell.x)/32.0),floori(float(cell.y)/32.0))
		var data := _cm.get_chunk_build_data(root+offset)
		var local := cell-offset*32
		if data == null or data.kind_at(local) not in [WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.Kind.WINDOW]:
			missing += 1
			continue
		var mask := 0
		for index in range(4):
			if site.carve.wall_cells.has(cell+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][index]): mask |= 1<<index
		if data.mask_at(local) != mask: bad_mask += 1
		if (data.variant_at(local)&ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE)==0: bad_flag += 1
	if missing+bad_mask+bad_flag>0: _fail("Actual streamed facility differs from complete site plan: missing=%d mask=%d flag=%d" % [missing,bad_mask,bad_flag])
	return {"source_wall_cells":site.carve.wall_cells.size(),"missing":missing,"bad_masks":bad_mask,"bad_intact_flags":bad_flag}

func _walk_line(target: Vector2) -> void:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	var arrived := false
	for tick in range(240):
		var delta := target-_player.global_position
		if delta.length()<8:
			arrived = true
			break
		var axis := delta.normalized()
		for pair: Array in [[&"move_left",maxf(0,-axis.x)],[&"move_right",maxf(0,axis.x)],[&"move_up",maxf(0,-axis.y)],[&"move_down",maxf(0,axis.y)]]:
			if float(pair[1])>0: Input.action_press(pair[0],pair[1])
			else: Input.action_release(pair[0])
		await get_tree().physics_frame
	for action: StringName in [&"move_left",&"move_right",&"move_up",&"move_down"]: Input.action_release(action)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_quiet_tutorials()
	if not arrived: _fail("Physical large-site door route blocked at "+str(_player.global_position)+" toward "+str(target))

func _donjon(sample: Dictionary) -> void:
	if int(sample.segment) != Global.attempt_segment or int(sample.attempt_seed) != Global.attempt_world_seed:
		_fail("Donjon candidate requires a separate production attempt capture")
		return
	var coord := Vector2i(sample.coord[0],sample.coord[1])
	var center := (Vector2(coord)+Vector2(0.5,0.5))*2048
	_player.global_position = center+Vector2(0,700)
	await _stream_at(center)
	var actual_regions: Array[Dictionary] = []
	for child: Node in (_cm._chunks[coord] as Node).get_children():
		if child is IndoorVolume and not child.exploration_loot_enabled:
			actual_regions.append({"cell_tl":str(child.cell_tl),"size_cells":str(child.size_cells),"building_id":child.building_id})
	if actual_regions.is_empty(): _fail("Production Donjon candidate did not reproduce in actual Game")
	_camera.zoom = Vector2.ONE*0.50
	_aim(center)
	var hud := _game.get_node("UI/HUD") as CanvasItem
	hud.visible = false
	await _shot_pair("donjon-overview","Actual production enclosed district dungeons, overview zoom0.5",{"candidate":sample,"actual_regions":actual_regions,"camera_zoom":0.5})
	hud.visible = true
	if not actual_regions.is_empty():
		var volume: IndoorVolume
		for child: Node in (_cm._chunks[coord] as Node).get_children():
			if child is IndoorVolume and not child.exploration_loot_enabled: volume = child; break
		_camera.zoom = Vector2.ONE
		var plans: Array = (_cm._chunks[coord] as Node).get_meta(&"dungeon_plans",[])
		if not plans.is_empty():
			_player.global_position = _nearest_walkable(Vector2(coord)*2048+(Vector2(plans[0].court.get_center())+Vector2.ONE*0.5)*64)
		await _frames(15)
		_aim(_player.global_position)
		await _shot_pair("donjon-interior-detail","Native zoom1 enclosed compact hall/cells; controlled pose for architecture review",{"region":actual_regions[0],"camera_zoom":1.0,"family":"district_CA_Donjon"})
	_large_notes.append({"donjon_candidate":sample,"actual_regions":actual_regions})
	var production_plans: Array = (_cm._chunks[coord] as Node).get_meta(&"dungeon_plans",[])
	if not production_plans.is_empty():
		var plan: Dictionary = production_plans[0]
		var region: Rect2i = plan.region
		var entries: Array[Vector2i] = plan.entrance_cells
		var door := Vector2.ZERO
		for cell: Vector2i in entries: door += (Vector2(cell)+Vector2.ONE*0.5)*64
		door = door/entries.size()+Vector2(coord)*2048
		var outward := Vector2.LEFT if entries[0].x == region.position.x else Vector2.RIGHT
		if entries[0].y == region.position.y: outward = Vector2.UP
		elif entries[0].y == region.end.y-1: outward = Vector2.DOWN
		var outside := _nearest_walkable(door+outward*96)
		_player.global_position = outside
		var hall := _nearest_walkable(Vector2(coord)*2048+(Vector2(plan.court.get_center())+Vector2.ONE*0.5)*64)
		var walked := await _path_walk(hall)
		var id := int(plan.seed&0x7fffffff)+1
		if not _inside_id(id): _fail("Physical compact Donjon entry missed actual indoor hall")
		_aim(_player.global_position)
		await _frames(15)
		await _shot_pair("donjon-physical-hall","Physical walk through actual compact dungeon doorway into enclosed hall",{"walked_cells":walked,"building_id":id})
		var descriptor := SiteOverlayImpl.SitePlan.new()
		descriptor.size_chunks = Vector2i.ONE
		var before := _site_signature(descriptor,coord)
		await _stream_at(center+Vector2(2048*80,0))
		if _cm._chunks.has(coord): _fail("Actual compact dungeon did not unload")
		await _stream_at(center)
		var equal := before == _site_signature(descriptor,coord)
		if not equal: _fail("Compact dungeon reload changed recorded geometry/ownership")
		if not _inside_id(id): _fail("Compact dungeon reload lost indoor ownership")
		await _shot_pair("donjon-reloaded-hall","Actual unload/rebuild while inside compact hall",{"signature_equal":equal})
		walked += await _path_walk(outside)
		await _frames(15)
		_aim(door)
		await _shot_pair("donjon-exit-roof-restored","Actual compact doorway exit restores enclosed roof family",{"walked_cells":walked})
		_large_notes.append({"compact_physical_entry_exit_cells":walked,"reload_equal":equal,"building_id":id,"exploration_loot_enabled":false,"reward_contract":"Original independent dungeon spawner/ID/counts retained"})







func _settle() -> void:
	for frame in range(360):
		await get_tree().process_frame
		if frame >= 25 and _cm.debug_chunk_queue().is_empty() and _cm.pending_blocker_stage_count() == 0:
			return
	_fail("world streaming did not settle")


func _nearest_walkable(at: Vector2, within: IndoorVolume = null) -> Vector2:
	var base := _cm.world_to_cell(at)
	for ring in range(14):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if ring > 0 and absi(dx) != ring and absi(dy) != ring:
					continue
				var cell := base + Vector2i(dx, dy)
				var point: Vector2 = _cm.cell_to_world_center(cell)
				if _cm.is_cell_walkable(cell) and (within == null or within.contains_world_point(point)):
					return point
	_fail("no loaded walkable capture position near " + str(at))
	return at


func _shot_pair(key: String, note: String, metadata: Dictionary) -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		_camera.force_update_scroll()
		var proxy := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		var drawn := 0
		if proxy != null and proxy.get("renderer") != null:
			drawn = int(proxy.get("renderer").call("publish"))
		await _frames(6)
		await RenderingServer.frame_post_draw
		var filename := "%s-%dx%d.png" % [key, dimensions.x, dimensions.y]
		var pixels := get_viewport().get_texture().get_image()
		if pixels.get_size() != dimensions or pixels.save_png(_out.path_join(filename)) != OK:
			_fail("native capture failed " + filename)
		_captures.append({"file": filename, "panel": key, "window": str(dimensions), "camera_center": str(_camera.global_position), "player_position": str(_player.global_position), "proxy_published_instances": drawn, "note": note, "metadata": metadata.duplicate(true)})
		print("CITY_CAPTURE ", filename, " camera=", _camera.global_position, " player=", _player.global_position)
