extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Real generated household: whole cutaway, physical prop contacts, occupied
## circulation and roof restoration. All movement after initial staging is input.
## -- --world-seed=16102026 --target-chunk=0,3 --target-building-id=944996572
## --review=small|normal --out=<fresh directory> [--no-occupied]

var _domestic_kit: Node2D
var _domestic_group: Node2D
var _domestic_roof_poly: Polygon2D
var _domestic_layout: Array = []
var _domestic_plates: Array[Dictionary] = []
var _domestic_contacts: Array[Dictionary] = []
var _domestic_enemies: Array[WeakRef] = []
var _domestic_occupied := true
var _fight_wall_seconds := 0.0


func _enter_tree() -> void:
	super._enter_tree()
	# Reuse the parent's complete Game/identity/reload setup, then replace only
	# its ground-review capture hook. These flags also preserve fixed framing.
	_ground_review = true
	_still_only = true
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-occupied": _domestic_occupied = false
	if _out.begins_with("res://docs/art/reference/2026-10-18-city-block/"):
		_out = "user://dev_previews/city_domestic_interiors/%d/%s" % [Time.get_ticks_usec(),_review]


func _capture_ground_review() -> void:
	if _city_segment != 2 or _has_ground_context or _volume == null or _volume.local_encounter_enabled:
		_fail("Domestic review requires an explicit actual ambient S2 home")
		await _shutdown()
		return
	for kit: Node in _chunks.find_children("*","",true,false):
		if kit.is_in_group(&"city_block_building") and kit.get("_roof") == _roof:
			_domestic_kit = kit as Node2D
	if _domestic_kit != null:
		_domestic_group = _domestic_kit.get_node_or_null("CityDomesticInterior") as Node2D
	if _domestic_group == null or bool(_domestic_kit.get("civic")) or _domestic_kit.get_meta(&"building_usage",&"") != &"row_house":
		_fail("Selected genuine home has no eligible domestic furniture owner")
		await _shutdown()
		return
	_domestic_roof_poly = _roof.get_node_or_null("RoofPoly") as Polygon2D
	if _domestic_roof_poly == null or _roof.footprint_outline_px.is_empty():
		_fail("Actual household lacks the production roof polygon or footprint")
		await _shutdown()
		return
	_domestic_layout = _domestic_group.get_meta(&"domestic_layout",[])
	if _domestic_layout.size() != 4:
		_fail("The kept home must demonstrate all four purposeful props; partial no-fit is disclosed")
	var before := var_to_str(_domestic_layout)
	var door := _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	_frame_home()
	await _wait_for_temporary_tips()
	await _plate("exterior-before-entry")
	await _walk_to(door+outward*96.0)
	await _walk_to(door-outward*float(_chunks.cell_size_px))
	await _frames(30)
	if _roof._inside_count <= 0 or _domestic_roof_poly.modulate.a > 0.01:
		_fail("Physical entry did not reveal the actual household roof")
	_frame_home()
	await _plate("interior-whole")
	for record: Dictionary in _domestic_layout:
		await _visit_prop(record)
	if _domestic_occupied and _failures == 0:
		await _occupied_circulation()
	await _walk_to(door+outward*160.0)
	await _frames(30)
	if _roof._inside_count != 0 or _domestic_roof_poly.modulate.a < 0.99:
		_fail("Physical return route did not restore the actual household roof")
	_frame_home()
	await _plate("exterior-restored")
	if before != var_to_str(_domestic_group.get_meta(&"domestic_layout",[])):
		_fail("Traversal changed the household layout")
	var additions := _addition_evidence()
	var writes := SaveManager.debug_save_writes-_save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Domestic review wrote or selected a profile")
	var report := _district_evidence()
	report["movement_fixture_revision"] = 2
	report["goal_tolerance_px"] = 8.0
	report["prior_evidence_qualification"] = "The first seven-plate bed architecture run at handoff-linux-next-20261020/domestic-bed-first-plates used the inherited same-cell route behavior: post-contact goals in the current cell could return23-41px off center. Its actual positions and contacts remain recorded. Revision2 physically centers resolved goals within8px or reports blocked movement."
	report.merge({"capture_scene":"res://tools/dev/CityDomesticInteriorPreview.tscn","scene":"res://scenes/game.tscn","args":OS.get_cmdline_user_args(),"attempt_seed":_city_world_seed,"target_chunk":str(_target_chunk),"target_building_id":_target_building_id,"layout":_layout_evidence(),"layout_sha256":before.sha256_text(),"furniture_additions":additions,"contacts":_domestic_contacts,"plates":_domestic_plates,"route":_route_notes,"occupied_requested":_domestic_occupied,"occupied_seconds":_combat_time,"wall_seconds":_fight_wall_seconds,"captured_frames":_pixels.size(),"weapon_fires":_weapon_fires,"hits":_player_hits,"deaths":_deaths,"max_projectiles":_max_projectiles,"frames":_capture_info,"source_hashes":_source_hashes(),"save_writes":writes,"failures":_failures,"limits":"Controlled actual generated Game household review. Real player inputs/collision, low furniture, roof entry/exit signals and actual streamed baseline reload. Initial outside placement only; no route teleport or physics/roof-counter overrides. God mode, disabled ambient spawner/encounter beats, fixed real-camera zoom and streaming frozen after reload. Optional two real controlled ordinary/elite enemies for a short occupied route. Not continuous human play, balance/performance approval or complete-street acceptance."},true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.path_join("frames")))
	for index in _pixels.size():
		_save_image(_pixels[index],_out.path_join("frames/frame-%04d.png" % index))
	var file := FileAccess.open(_out.path_join("capture-info.json"),FileAccess.WRITE)
	if file == null:
		_fail("Cannot write household review manifest")
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("CityDomesticInteriorPreview: plates=%d additions=%d contacts=%d occupied=%.2f failures=%d saves=%d -> %s" % [_domestic_plates.size(),additions.size(),_domestic_contacts.size(),_combat_time,_failures,writes,_out])
	await _shutdown()


func _frame_home() -> void:
	var outline := _roof.footprint_outline_px
	var box := Rect2(_roof.to_global(outline[0]),Vector2.ZERO)
	for point: Vector2 in outline:
		box = box.expand(_roof.to_global(point))
	_camera.global_position = box.get_center()+Vector2(0,24)
	_camera.reset_smoothing()
	_camera.force_update_scroll()


func _plate(name: String) -> void:
	await _frames(4)
	await _still(name)
	_domestic_plates.append({"file":name+".png","player_root":str(_player.global_position),"camera":str(_camera.global_position),"zoom":str(_camera.zoom),"window":str(get_window().size),"roof_alpha":_domestic_roof_poly.modulate.a,"inside_count":_roof._inside_count,"enemies":EnemyWorld.active_count(),"projectiles":ProjectileManager.active_count()})


func _inside_cell(cell: Vector2i) -> bool:
	var world := _chunks.cell_to_world_center(cell)
	return _chunks.is_cell_walkable(cell) and Geometry2D.is_point_in_polygon(_roof.to_local(world),_roof.footprint_outline_px)


func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	var failures_before: int = _failures
	var resolved: Vector2 = _chunks.cell_to_world_center(_chunks.world_to_cell(_free_spawn_position(desired)))
	if _failures > failures_before: return
	await super._walk_to(desired,strict_perimeter)
	if _failures > failures_before: return
	# The inherited BFS has no path cells when the goal is the current cell.
	# Finish that last physical approach as well; never assign player position.
	var start: Vector2 = _player.global_position
	var arrived := false
	for tick: int in range(180):
		var delta: Vector2 = resolved-_player.global_position
		if delta.length() < 8.0:
			arrived = true
			break
		var axis: Vector2 = delta.normalized()
		_set_axis(&"move_left",&"move_right",axis.x)
		_set_axis(&"move_up",&"move_down",axis.y)
		await get_tree().physics_frame
	_release_inputs()
	if not arrived:
		_fail("Physical collision prevented final household goal centering at "+str(resolved))
	_route_notes.append({"event":"physical_goal_centering","desired":str(desired),"resolved":str(resolved),"before":str(start),"arrived":str(_player.global_position),"distance":_player.global_position.distance_to(resolved),"tolerance_px":8.0,"success":arrived})


func _approach(record: Dictionary) -> Vector2:
	var occupied: Dictionary = {}
	var chunk_origin := _target_chunk*32
	for cell: Vector2i in record.reserved_cells:
		occupied[cell+chunk_origin] = true
	var candidates: Array[Vector2] = []
	for cell: Vector2i in occupied:
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell+direction
			if not occupied.has(next) and _inside_cell(next):
				candidates.append(_chunks.cell_to_world_center(next))
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(_player.global_position) < b.distance_squared_to(_player.global_position))
	return candidates[0] if not candidates.is_empty() else Vector2.INF


func _visit_prop(record: Dictionary) -> void:
	var desired := _approach(record)
	if desired == Vector2.INF:
		_fail("No genuine floor approach to "+String(record.kind))
		return
	var failures_before := _failures
	await _walk_to(desired)
	if _failures > failures_before or _player.global_position.distance_to(desired) > 16.0:
		_fail("Player did not physically reach the selected household approach")
		return
	var target := Vector2.INF
	for cell: Vector2i in record.reserved_cells:
		var point := _chunks.cell_to_world_center(_target_chunk*32+cell)
		if target == Vector2.INF or point.distance_squared_to(_player.global_position) < target.distance_squared_to(_player.global_position):
			target = point
	var start := _player.global_position
	var axis := (target-start).normalized()
	_set_axis(&"move_left",&"move_right",axis.x)
	_set_axis(&"move_up",&"move_down",axis.y)
	for tick in 24:
		await get_tree().physics_frame
	_release_inputs()
	await _frames(3)
	var contact_distance := _player.global_position.distance_to(target)
	if contact_distance < 39.0:
		_fail("Player crossed the expected low-cover support at "+String(record.kind))
	var art: Sprite2D
	for child: Node in _domestic_group.get_children():
		if child is Sprite2D and child.get_meta(&"domestic_kind",&"") == record.kind:
			art = child as Sprite2D
	var source_contact := Vector2.INF
	if art != null:
		source_contact = art.to_global((record.anchor_px as Vector2)-art.texture.get_size()*0.5)
	_domestic_contacts.append({"kind":String(record.kind),"requested_approach":str(desired),"approach_actual":str(start),"support_center":str(target),"actual_player_contact":str(_player.global_position),"support_distance":contact_distance,"actual_art_contact":str(source_contact),"measured_art_contact":str(_domestic_kit.to_global(record.contact_px)),"reserved_cells":str(record.reserved_cells),"ground_rect_local":str(record.ground_rect_px),"projectile_hit_t":_chunks.projectile_hit_t(target-Vector2(24,0),target+Vector2(24,0),0.0)})
	await _plate("interior-"+String(record.kind)+"-contact")
	await _walk_to(desired)


func _interior_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for y in range(32):
		for x in range(32):
			var cell := _target_chunk*32+Vector2i(x,y)
			if _inside_cell(cell):
				points.append(_chunks.cell_to_world_center(cell))
	var center := _camera.global_position
	points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	return points


func _occupied_circulation() -> void:
	var points := _interior_points()
	if points.size() < 6:
		_fail("Household has insufficient actual floor for a bounded occupied comparison")
		return
	await _walk_to(points[0])
	for point: Vector2 in points:
		if point.distance_to(_player.global_position) < 128.0:
			continue
		var actor := _spawn_actor("Grunt" if _domestic_enemies.is_empty() else "Brute",point)
		if _domestic_enemies.size() == 1:
			actor.apply_elite_modifiers([EliteModifiers.ARMOURED] as Array[StringName])
		_domestic_enemies.append(weakref(actor))
		if _domestic_enemies.size() == 2:
			break
	await _wait_for_temporary_tips()
	await _plate("interior-occupied-start")
	_phase = "domestic-occupied-fight"
	_began_usec = Time.get_ticks_usec()
	_combat_time = 0.0
	_recording = true
	_clearing_interior = true
	Input.action_press(&"attack")
	await _walk_to(points[1])
	await _walk_to(points[3])
	while _combat_time < 3.0:
		await get_tree().physics_frame
	_clearing_interior = false
	_recording = false
	_fight_wall_seconds = float(Time.get_ticks_usec()-_began_usec)/1_000_000.0
	_release_inputs()
	await _plate("interior-occupied-ending")
	if _weapon_fires == 0 or _max_projectiles == 0:
		_fail("Occupied household comparison did not exercise production attacks/projectiles")
	# Explicit controlled-fixture teardown after the comparison, not a fake
	# kill or a teleport through bodies to prove the architectural exit.
	for reference: WeakRef in _domestic_enemies:
		var actor := reference.get_ref() as Node
		if actor != null: actor.queue_free()
	await _frames(3)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _clearing_interior:
		_combat_time += delta


func _addition_evidence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data := _chunks.get_chunk_build_data(_target_chunk)
	for record: Dictionary in _domestic_layout:
		for cell: Vector2i in record.reserved_cells:
			var kind := data.kind_at(cell)
			var variant := data.variant_at(cell)
			if kind != WorldBlockerGeometry.Kind.HALF_COVER or (variant&ChunkBlockVisualCatalog.VARIANT_FURNITURE_ART) == 0:
				_fail("Visible household prop lost explicit low-cover ownership")
			result.append({"prop":String(record.kind),"local_cell":str(cell),"global_cell":str(_target_chunk*32+cell),"kind":kind,"variant":variant,"walkable":_chunks.is_cell_walkable(_target_chunk*32+cell)})
	return result


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://tools/dev/CityDomesticInteriorPreview.gd","res://tools/dev/CityDomesticInteriorPreview.tscn","res://tools/dev/CityBlockPlayablePreview.gd","res://scenes/world/buildings/CityDomesticInterior.gd","res://scenes/world/buildings/CityBlockFrontages.gd","res://scenes/world/buildings/CityBlockKit.gd","res://scenes/world/buildings/domestic_stone.gdshader","res://scenes/world/buildings/domestic_plaster.gdshader","res://core/systems/world/proc/SiteParcelsImpl.gd","res://core/systems/world/chunks/ChunkBlockRenderer.gd","res://assets/world/domestic_interiors/v1/timber_cot.png","res://assets/world/domestic_interiors/v1/timber_cot.png.import","res://assets/world/domestic_interiors/v1/cooking_hearth.png","res://assets/world/domestic_interiors/v1/cooking_hearth.png.import"]:
		result[path] = FileAccess.get_sha256(path)
	return result


func _layout_evidence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _domestic_layout:
		var cells: Array = []
		for cell: Vector2i in record.reserved_cells:
			cells.append([cell.x,cell.y])
		var datum: Vector2 = record.anchor_px
		var contact: Vector2 = record.contact_px
		var ground: Rect2 = record.ground_rect_px
		var visible: Rect2 = record.visible_rect_px
		result.append({"kind":String(record.kind),"source_path":String(record.source_path),"source_sha256":FileAccess.get_sha256(record.source_path),"uniform_scale":float(record.scale),"source_ground_datum_px":[datum.x,datum.y],"kit_contact_px":[contact.x,contact.y],"ground_rect_kit_px":[ground.position.x,ground.position.y,ground.size.x,ground.size.y],"visible_rect_kit_px":[visible.position.x,visible.position.y,visible.size.x,visible.size.y],"reserved_cells":cells})
	return result
