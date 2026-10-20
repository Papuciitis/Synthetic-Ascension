extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Same frozen actual Game: legacy whole roof, then fitted connected planes.
## -- --visible --review=small|normal --world-seed=16102026 --segment=2
## --target-building-id=944996572 --target-chunk=0,3 --out=<fresh directory>

const ROOF_COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
var _pair_checks := 0


func _enter_tree() -> void:
	super._enter_tree()
	_ground_review = true
	_ground_fight = false


func _require(ok: bool, label: String) -> void:
	_pair_checks += 1
	if not ok: _fail(label)


func _host_state(host: Polygon2D) -> Dictionary:
	var chimneys: Array[Dictionary] = []
	for node: Node in host.find_children("*","Node2D",true,false):
		if node.has_meta(&"city_chimney"):
			var chimney := node as Node2D
			chimneys.append({"path":str(host.get_path_to(chimney)),"visible":chimney.visible,"transform":str(chimney.transform)})
	return {"rgb":[host.color.r,host.color.g,host.color.b],"alpha":host.color.a,"modulate":str(host.modulate),"self_modulate":str(host.self_modulate),"polygon":str(host.polygon),"uv":str(host.uv),"transform":str(host.global_transform),"texture":host.texture.resource_path if host.texture != null else "","texture_scale":str(host.texture_scale),"texture_offset":str(host.texture_offset),"material_instance":host.material.get_instance_id() if host.material != null else 0,"chimneys":chimneys,"footprint":str(_roof.footprint_outline_px),"inside_count":_roof._inside_count,"camera_position":str(_camera.global_position),"camera_rotation":_camera.rotation,"camera_zoom":str(_camera.zoom),"player_position":str(_player.global_position)}


func _same_except_draw_alpha(first: Dictionary, second: Dictionary) -> bool:
	var a := first.duplicate(true)
	var b := second.duplicate(true)
	a.erase("alpha")
	b.erase("alpha")
	return a == b


func _capture_ground_review() -> void:
	_require(_city_segment == 2 and _city_world_seed == 16102026 and _target_building_id == 944996572 and _target_chunk == Vector2i(0,3) and not _has_ground_context,"Roof pair requires the explicit retained S2 bed home")
	_require(_review in ["small","normal"] and not _playable and not _hide_district_details,"Roof pair requires normal HUD/details and small or normal native output")
	_require(_volume != null and not _volume.local_encounter_enabled and _roof != null,"Roof pair retains the real ambient parcel and roof owner")
	if _failures > 0:
		await _shutdown()
		return
	var host := _roof.get_node("RoofPoly") as Polygon2D
	var group := host.get_node_or_null("CityIrregularRoofComposition") as Node2D
	_require(group != null and group.get_child_count() > 1,"Actual retained roof supplies its connected production planes")
	if group == null or _failures > 0:
		await _shutdown()
		return
	var footprint_bounds := Rect2(_roof.footprint_outline_px[0],Vector2.ZERO)
	for point: Vector2 in _roof.footprint_outline_px: footprint_bounds = footprint_bounds.expand(point)
	_camera.global_position = _roof.to_global(footprint_bounds.get_center())-Vector2(0,40)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_chunks.set_process(false)
	_release_inputs()
	await _wait_for_temporary_tips()
	await _frames(4)
	var original_color := host.color
	var original_visibility := group.visible
	_require(original_visibility and is_zero_approx(original_color.a) and host.modulate.a > 0.99 and _roof._inside_count == 0,"Original connected roof is opaque through its children and has no duplicate base mesh")
	var coord := _chunks._world_to_chunk(_volume.global_position)
	var physical_before := _signature(coord)
	var cover: Node = ROOF_COVER.get_for(_player)
	cover.call("refresh",_player,true)
	var mesh_bounds := Rect2(host.polygon[0],Vector2.ZERO)
	for point: Vector2 in host.polygon: mesh_bounds = mesh_bounds.expand(point)
	var cover_point := host.to_global(mesh_bounds.get_center())
	var feet_y := cover_point.y+16.0
	var strength_before := float(cover.call("strength_at",cover_point,feet_y))
	_require(strength_before > 0.99,"Actual roof pair probe starts under opaque shared cover")
	if _failures > 0:
		await _shutdown()
		return
	get_tree().paused = true
	Engine.time_scale = 0.0
	await _frames(2)
	var before := _host_state(host)
	# Only these two draw controls change. The original whole host mesh keeps
	# its material, RGB, geometry, inherited fade and separately owned chimney.
	group.visible = false
	var legacy_color := original_color
	legacy_color.a = 1.0
	host.color = legacy_color
	await _frames(2)
	var legacy := _host_state(host)
	_require(_same_except_draw_alpha(before,legacy) and is_equal_approx(host.color.a,1.0) and not group.visible,"Legacy control changes only composition visibility and host draw alpha")
	await _still("legacy-whole-roof")
	cover.call("refresh",_player,true)
	var strength_legacy := float(cover.call("strength_at",cover_point,feet_y))
	host.color = original_color
	group.visible = original_visibility
	await _frames(2)
	var restored := _host_state(host)
	_require(restored == before and group.visible == original_visibility,"Connected capture exactly restores original host state and group visibility")
	_require(_signature(coord) == physical_before,"Both states preserve actual physical cells, floor stamps, care and reward owners")
	cover.call("refresh",_player,true)
	var strength_restored := float(cover.call("strength_at",cover_point,feet_y))
	_require(is_equal_approx(strength_before,strength_legacy) and is_equal_approx(strength_before,strength_restored),"Shared cover remains identical through legacy control and connected restoration")
	await _still("connected-roof-planes")
	var writes := SaveManager.debug_save_writes-_save_writes_before
	_require(writes == 0 and SaveManager.current_save == null,"Frozen roof pair selects no profile and writes no save")
	var info := _district_evidence()
	info.merge({"capture_scene":"res://tools/dev/CityRoofDepthPreview.tscn","scene":"res://scenes/game.tscn","args":OS.get_cmdline_user_args(),"review":_review,"seed":_city_world_seed,"attempt_seed":_city_world_seed,"segment":_city_segment,"fixed_camera":true,"normal_hud":true,"optional_details_hidden":false,"image_size":str(get_window().size),"same_state_pair":true,"scene_tree_paused":get_tree().paused,"engine_time_scale":Engine.time_scale,"ambient_spawner":false,"player_god_mode":true,"scripted_input":false,"route":_route_notes,"frames":[],"captured_frames":0,"plates":[{"file":"legacy-whole-roof.png","composition_visible":false,"host_color_alpha":1.0},{"file":"connected-roof-planes.png","composition_visible":original_visibility,"host_color_alpha":original_color.a}],"original_host":before,"legacy_host":legacy,"restored_host":restored,"physical_signature_preserved":_signature(coord) == physical_before,"cover_probe":{"point":str(cover_point),"feet_y":feet_y,"before":strength_before,"legacy":strength_legacy,"restored":strength_restored},"checks":_pair_checks,"save_writes":writes,"failures":_failures,"limits":"One actual generated Game after real reload and quiet HUD. Scene tree paused and time_scale0 for two draw-only states: hide connected composition/restore base draw alpha1, then exact original restoration. Ground, purpose, chimney, material, geometry and coverage stay owned by the same scene. Initial placement is staged; no input/AI/combat/performance or whole-street acceptance is exercised."},true)
	var file := FileAccess.open(_out.path_join("capture-info.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(info,"\t"))
	file.close()
	print("CityRoofDepthPreview: checks=%d failures=%d saves=%d same_state=%s cover=%.3f/%.3f/%.3f" % [_pair_checks,_failures,writes,restored == before,strength_before,strength_legacy,strength_restored])
	await _shutdown()
