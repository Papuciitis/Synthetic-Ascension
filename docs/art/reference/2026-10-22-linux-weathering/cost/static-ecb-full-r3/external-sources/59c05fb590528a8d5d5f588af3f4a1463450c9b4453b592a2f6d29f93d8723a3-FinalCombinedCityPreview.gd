extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Final actual-Game views; exterior staging only, ordinary fades/materials live.
var _final_parking: Vector2 = Vector2.INF
var _final_reuse_parking: bool = false
var _final_parking_info: Dictionary = {}
var _final_stills: Array[Dictionary] = []
var _final_volumes: Array[IndoorVolume] = []
var _final_roofs: Array[RoofOverlay] = []
var _final_kits: Array[Node2D] = []

func _prepare_runtime() -> void:
	super._prepare_runtime()
	Engine.max_fps = 20

func _reload_ground_context() -> void:
	await super._reload_ground_context()
	if _failures > 0: return
	for node: Node in _game.find_children("*", "", true, false):
		if node is IndoorVolume: _final_volumes.append(node as IndoorVolume)
		if node is RoofOverlay: _final_roofs.append(node as RoofOverlay)
		if node is Node2D and node.is_in_group(&"city_block_building"): _final_kits.append(node as Node2D)
	_final_parking = _final_find_parking()
	if _final_parking == Vector2.INF:
		_fail("No loaded walkable exterior cell clears all bounds and the actual capsule")
		return
	_player.global_position = _final_parking
	_player.velocity = Vector2.ZERO
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_release_inputs()
	_dismiss_dossiers()
	var began: int = Engine.get_physics_frames()
	var stable: int = 0
	for _frame: int in range(120):
		await get_tree().physics_frame
		await get_tree().process_frame
		if get_tree().paused: _dismiss_dossiers()
		stable = stable + 1 if bool(_final_state().all_opaque_outside) else 0
		if stable >= 3 and Engine.get_physics_frames() - began >= 4: break
	_final_reuse_parking = true # Parent capture's next exact context placement.
	_final_parking_info = {"selected_world":str(_final_parking), "cell":str(_chunks.world_to_cell(_final_parking)), "distance_from_camera":_final_parking.distance_to(_ground_context), "clearance_px":64.0, "static_capsule_checked":true, "ordinary_physics_frames":Engine.get_physics_frames()-began, "outside_and_opaque_after_settle":stable >= 3, "camera_unchanged":_camera.global_position.is_equal_approx(_ground_context)}
	if stable < 3 or _player.global_position.distance_to(_final_parking) > 1.0: _fail("Ordinary exterior exits/roof/facade fades did not settle")

func _free_spawn_position(desired: Vector2) -> Vector2:
	if _final_reuse_parking and desired.is_equal_approx(_ground_context):
		_final_reuse_parking = false
		return _final_parking
	return super._free_spawn_position(desired)

func _final_outside(point: Vector2) -> bool:
	for volume: IndoorVolume in _final_volumes:
		var extent: Vector2 = Vector2(volume.size_cells) * float(volume.cell_size_px)
		if Rect2(volume.global_position - extent * 0.5, extent).grow(64.0).has_point(point): return false
	for kit: Node2D in _final_kits:
		var bounds: Rect2 = kit.get("bounds")
		if (kit.global_transform * bounds).grow(64.0).has_point(point): return false
	return true

func _final_find_parking() -> Vector2:
	var capsule: CollisionShape2D = _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if capsule == null or capsule.shape == null: return Vector2.INF
	var centre: Vector2i = _chunks.world_to_cell(_ground_context)
	var cells: Array[Vector2i] = []
	for y: int in range(-16, 17):
		for x: int in range(-16, 17): cells.append(centre + Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = _chunks.cell_to_world_center(a).distance_squared_to(_ground_context)
		var db: float = _chunks.cell_to_world_center(b).distance_squared_to(_ground_context)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = capsule.shape
	query.collision_mask = _player.collision_mask & ~2
	query.exclude = [_player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 2.0
	for cell: Vector2i in cells:
		if not _chunks.is_cell_walkable(cell) or not _chunks.has_built_cell(cell): continue
		var point: Vector2 = _chunks.cell_to_world_center(cell)
		if not _final_outside(point): continue
		var placement: Transform2D = capsule.global_transform
		placement.origin += point - _player.global_position
		query.transform = placement
		if _player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): return point
	return Vector2.INF

func _final_alpha(item: CanvasItem) -> float:
	var alpha: float = item.self_modulate.a
	var parent: Node = item
	while parent != null:
		if parent is CanvasItem: alpha *= (parent as CanvasItem).modulate.a
		parent = parent.get_parent()
	return alpha

func _final_state() -> Dictionary:
	var empty_slices: Array[Dictionary] = []
	var good: bool = not _final_roofs.is_empty() and not _final_kits.is_empty() and _final_outside(_player.global_position)
	var walkable: bool = _chunks.is_cell_walkable(_chunks.world_to_cell(_player.global_position)) and _chunks.has_built_cell(_chunks.world_to_cell(_player.global_position))
	var fixed_camera: bool = _camera.global_position.is_equal_approx(_ground_context)
	var overlaps: int = 0
	var inside: int = 0
	var planes: int = 0
	var facades: int = 0
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for volume: IndoorVolume in _final_volumes:
		if volume.contains_world_point(_player.global_position) or volume.overlaps_body(_player) or bool(volume.get("_player_inside")): overlaps += 1
	for roof: RoofOverlay in _final_roofs:
		inside += int(roof.get("_inside_count"))
		good = good and int(roof.get("_inside_count")) == 0
		var host: Polygon2D = roof.get_node_or_null("RoofPoly") as Polygon2D
		var tween: Tween = roof.get("_tween") as Tween
		good = good and host != null and roof.effective_outside_alpha() >= 0.99999 and (tween == null or not tween.is_running())
		if host == null: continue
		good = good and _final_alpha(host) >= 0.99999
		for node: Node in [host] + host.find_children("*", "", true, false):
			var plane: Polygon2D = node as Polygon2D
			if plane == null or (plane == host and plane.color.a <= 0.0): continue # Only the compound host may be transparent.
			var material: ShaderMaterial = plane.material as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != "res://scenes/world/buildings/roof.gdshader": continue
			if _final_empty_dungeon_slice(roof, plane, host):
				empty_slices.append({"classification":"empty_clipped_dungeon_host", "source_script":"res://scenes/world/buildings/DungeonRoof.gd", "footprint":_final_dungeon_footprint(roof), "polygon_vertices":0})
				continue
			good = good and plane.is_visible_in_tree() and _final_alpha(plane) * plane.color.a >= 0.99999 and plane.polygon.size() >= 3
			if plane.polygon.size() < 3: continue
			var bounds: Rect2 = Rect2(plane.polygon[0], Vector2.ZERO)
			for point: Vector2 in plane.polygon: bounds = bounds.expand(point)
			if (plane.global_transform * bounds).intersects(view): planes += 1
	for kit: Node2D in _final_kits:
		good = good and float(kit.get("_facade_alpha")) >= 0.99999
		var owners: int = 0
		for child: Node in kit.get_children():
			if not child is CanvasItem or not child.has_meta(&"city_facade_detail"): continue
			good = good and (child as CanvasItem).is_visible_in_tree() and _final_alpha(child as CanvasItem) >= 0.99999
			owners += 1
		var bounds: Rect2 = kit.get("bounds")
		var wall: Rect2 = Rect2(bounds.position.x, float(kit.get("_front"))-float(kit.get("_facade_height")), bounds.size.x, float(kit.get("_facade_height")))
		if owners > 0 and (kit.global_transform * wall).intersects(view): facades += 1
	return {"empty_clipped_roof_slices":empty_slices, "all_opaque_outside":good and walkable and fixed_camera and overlaps == 0 and inside == 0 and planes > 0 and facades > 0, "outside_bounds_grown64":_final_outside(_player.global_position), "indoor_overlap_or_flags":overlaps, "inside_counts":inside, "checked_roofs":_final_roofs.size(), "checked_kits":_final_kits.size(), "in_view_roof_planes":planes, "in_view_facades":facades, "actual_player":str(_player.global_position), "loaded_walkable":walkable, "camera_unchanged":fixed_camera}

func _still(name: String) -> void:
	await super._still(name)
	var proof: Dictionary = _final_state()
	_final_stills.append({"file":name+".png", "exterior":proof})
	if not bool(proof.all_opaque_outside): _fail("Native combined still lost exterior/opaque owners: " + name)

func _district_evidence() -> Dictionary:
	var result: Dictionary = super._district_evidence()
	var atmosphere: Node = _chunks.get_node_or_null("WorldAtmosphere")
	var profiles: Dictionary = {}
	for kit: Node2D in _final_kits:
		var profile: String = String(kit.get_meta(&"district_visual_profile", &"missing"))
		profiles[profile] = int(profiles.get(profile, 0)) + 1
	result["capture_scene"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-r3/FinalCombinedCityPreview.tscn"
	result["final_combined"] = {"render_dimensions":_final_render_dimensions(), "parking":_final_parking_info, "capture_stills":_final_stills, "final_exterior":_final_state(), "loaded_profile_counts":profiles, "render_fps_cap":Engine.max_fps, "physics_ticks_per_second":Engine.physics_ticks_per_second, "atmosphere":atmosphere.call("diagnostics") if atmosphere != null and atmosphere.has_method("diagnostics") else {}, "reduced_motion_setting":SettingsManager.get_value(&"accessibility", &"reduced_motion", false), "combat_flash_setting":SettingsManager.get_value(&"accessibility", &"combat_flash", "full"), "limits":"Parent actual Game, normal HUD/details/save isolation and optional five-second controlled fight retained. Only initial player parking changes; static capsule query excludes enemy layer. Camera remains fixed. Ordinary indoor exits and roof/facade tweens settle without counter, fade, shader or collision edits. No performance or full human-play claim."}
	return result


static func _final_empty_dungeon_slice(roof: RoofOverlay, plane: Polygon2D, host: Polygon2D) -> bool:
	var script: Script = roof.get_script() as Script
	return plane == host and plane.polygon.is_empty() and script != null and script.resource_path == "res://scenes/world/buildings/DungeonRoof.gd" and roof.has_meta(&"dungeon_wing")


func _final_dungeon_footprint(roof: RoofOverlay) -> Array:
	var points: Array = []
	for point: Vector2 in roof.footprint_outline_px:
		var world: Vector2 = roof.to_global(point)
		points.append([world.x,world.y])
	return points
## Exact ed1daf0bf source: CANVAS_ITEMS allocates the native screen-size
## target, while Window ViewportTexture.get_size multiplies by stretch again.
## Record that getter honestly; derive the native target from the complete
## observed Window/DisplayServer/logical/stretch contract without changing it.
func _final_render_dimensions() -> Dictionary:
	var window: Window = get_window()
	var viewport: Viewport = get_viewport()
	var logical: Vector2 = viewport.get_visible_rect().size
	var stretch: Transform2D = viewport.get_stretch_transform()
	var getter: Vector2 = viewport.get_texture().get_size()
	var display: Vector2i = DisplayServer.window_get_size(window.get_window_id())
	return {"basis":"Godot ed1daf0bf native CANVAS_ITEMS source contract", "engine_hash":String(Engine.get_version_info().get("hash", "")), "window_is_viewport":window == viewport, "native_window_id":window.get_window_id(), "nonembedded":not window.is_embedded(), "window_size":[window.size.x,window.size.y], "display_server_size":[display.x,display.y], "canvas_items_mode":window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "content_scale_mode":window.content_scale_mode, "content_scale_size":[window.content_scale_size.x,window.content_scale_size.y], "content_scale_factor":window.content_scale_factor, "content_scale_aspect":window.content_scale_aspect, "content_scale_stretch":window.content_scale_stretch, "logical_visible_size":[logical.x,logical.y], "stretch_transform":[stretch.x.x,stretch.x.y,stretch.y.x,stretch.y.y,stretch.origin.x,stretch.origin.y], "source_derived_native_size":[logical.x*stretch.x.x,logical.y*stretch.y.y], "texture_size_getter_diagnostic":[getter.x,getter.y]}
