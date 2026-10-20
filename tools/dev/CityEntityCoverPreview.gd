extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Controlled actors in the actual generated Game. Actor simulation is frozen;
## production batch publishing, icon refresh, scenery and doorway signals live.
## -- --world-seed=16102026 --target-building-id=944996572 --target-chunk=0,3
## --review=small|normal [--tree-kind=ordinary|fruit|any] --out=<fresh directory>

const COVER_PROVIDER := preload("res://core/systems/world/visibility/WorldCover.gd")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const ITEM_SCENE := preload("res://scenes/world/pickups/ItemPickup.tscn")
const HEALTH_SCENE := preload("res://scenes/world/pickups/HealthPickup.tscn")

var _evidence_cover: Node
var _evidence_renderer: EnemyProxyRenderer
var _evidence_kit: Node2D
var _evidence_entities: Array[Dictionary] = []
var _evidence_plates: Array[Dictionary] = []
var _tree_kind := "any"
var _player_tree_only := false
var _last_quiet_wait: Dictionary = {}


func _enter_tree() -> void:
	super._enter_tree()
	_still_only = true  # This controller explicitly frames each real surface.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-kind="):
			_tree_kind = arg.trim_prefix("--tree-kind=")
		if arg == "--player-tree-only":
			_player_tree_only = true
	if _out.begins_with("res://docs/art/reference/2026-10-18-city-block/"):
		_out = "user://dev_previews/city_entity_cover/" + _review


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _target_building_id <= 0 or not _has_target_chunk:
		_fail("Entity cover evidence requires native rendering and explicit seed/home/chunk identity")
		await _shutdown()
		return
	if _tree_kind not in ["ordinary", "fruit", "any"]:
		_fail("tree-kind must be ordinary, fruit or any")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
	_reduced_motion = _review == "reduced"
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", "off" if _reduced_motion else "full", false)
	get_window().size = Vector2i(960, 540) if _review in ["small", "reduced"] else Vector2i(1280, 720)
	get_window().title = "Synthetic Ascension — controlled entity cover evidence"
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	await _settle()
	_dismiss_dossiers()
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder != null:
		builder.set_process(false)
	_player.global_position = (Vector2(_target_chunk) + Vector2.ONE * 0.5) * _chunks.chunk_size_px + Vector2(0, 600)
	await _settle()
	_dismiss_dossiers()
	for candidate: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if candidate is IndoorVolume and _matches_volume(candidate as IndoorVolume, _target_building_id):
			_volume = candidate as IndoorVolume
			break
	if _volume == null:
		_fail("The explicit generated home did not stream")
		await _shutdown()
		return
	await _reload_check(_target_building_id)
	if _volume == null:
		await _shutdown()
		return
	for connection: Dictionary in _volume.body_entered.get_connections():
		var owner: Object = (connection.callable as Callable).get_object()
		if owner is RoofOverlay:
			_roof = owner as RoofOverlay
	for kit: Node in _chunks.find_children("*", "", true, false):
		if kit.is_in_group(&"city_block_building") and kit.get("_roof") == _roof:
			_evidence_kit = kit as Node2D
	var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
	if proxy_root != null:
		_evidence_renderer = proxy_root.get("renderer") as EnemyProxyRenderer
	if _roof == null or _evidence_kit == null or _evidence_renderer == null:
		_fail("Missing actual home roof/kit or production batch renderer")
		await _shutdown()
		return
	# Disable simulation assignment only. The renderer and WorldCover retain
	# their ordinary processing; each staged enemy keeps its real batch entry.
	EnemySimulationScheduler.set_physics_process(false)
	_chunks.set_process(false)
	var door := _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	_player.global_position = _free_spawn_position(door + outward * 160.0)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_evidence_cover = COVER_PROVIDER.get_for(_player)
	await _wait_for_temporary_tips()
	if _player_tree_only:
		await _capture_player_tree_route(_tree_target())
		await _shutdown()
		return
	var roof_target := _roof_target()
	var facade_target := _facade_target()
	var tree_target := _tree_target()
	for target: Dictionary in [roof_target, facade_target, tree_target]:
		if target.is_empty():
			continue
		# The original fruit tree has a small real canopy. Keep distinct actors
		# and icons readable across two plates instead of crowding its source.
		var groups: Array = [[0, 1], [2, 3, 4]] if String(target.kind).contains("tree") else [[]]
		for indices: Array in groups:
			var suffix := "-enemies" if indices == [0, 1] else ("-pickups" if not indices.is_empty() else "")
			await _stage_target(target, false, indices)
			await _capture_entities(String(target.kind) + suffix + "-covered", target, true)
			_clear_entities()
			await _frames(2)
			await _stage_target(target, true, indices)
			await _capture_entities(String(target.kind) + suffix + "-front-controls", target, false)
			_clear_entities()
			await _frames(2)
	# Retain the same real actors/icons while walking across the production
	# threshold. This is physical input, not a manufactured inside counter.
	await _stage_target(roof_target, false)
	await _capture_entities("roof-before-entry", roof_target, true)
	await _walk_to(door + outward * 96.0)
	await _walk_to(door - outward * float(_chunks.cell_size_px))
	await _frames(30)
	var inside_alpha := (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
	if _roof._inside_count <= 0 or inside_alpha > 0.01:
		_fail("Actual player entry did not open the real roof")
	await _capture_entities("roof-player-inside-cutaway", roof_target, false, true)
	await _walk_to(door + outward * 160.0)
	await _frames(30)
	var outside_alpha := (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
	if _roof._inside_count != 0 or outside_alpha < 0.99:
		_fail("Actual player exit did not restore the real roof")
	await _capture_entities("roof-player-outside-restored", roof_target, true)
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Controlled cover evidence wrote or selected a profile")
	var report := {"capture_scene":"res://tools/dev/CityEntityCoverPreview.tscn", "scene":"res://scenes/game.tscn", "args":OS.get_cmdline_user_args(), "attempt_seed":_city_world_seed, "segment":_city_segment, "requested_building_id":_target_building_id, "requested_chunk":str(_target_chunk), "tree_kind":_tree_kind, "inside_alpha":inside_alpha, "outside_alpha":outside_alpha, "plates":_evidence_plates, "route":_route_notes, "save_writes":writes, "failures":_failures, "limits":"Controlled native visual evidence in actual generated Game. Real ordinary/elite EnemyActors, production batches and genuine equipment/health scenes; enemy physics/scheduler frozen, staged enemies carry the existing never_cull fixture metadata to preserve the same bodies during doorway traversal, ambient spawner and encounter beats disabled, staged pickup Area2D monitoring disabled to prevent collection while preserving locked/unlocked icon presentation, god-mode player, fixed cameras, streaming frozen after verified reload. Authored tutorial tips and floating callouts expire naturally before stills; no runtime VFX are hidden or deleted. Staging may use non-walkable covered points and every requested/actual position and walkability is disclosed. Not a spontaneous spawn, continuous human run, balance/performance test, collection test or proof of encounter reachability. Doorway entry/exit uses production input and Area2D signals."}
	report.merge(_district_evidence(), false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file := FileAccess.open(_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write entity-cover evidence manifest")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("CityEntityCoverPreview: plates=%d failures=%d save_writes=%d -> %s" % [_evidence_plates.size(), _failures, writes, _out])
	_clear_entities()
	await _shutdown()


func _roof_target() -> Dictionary:
	var poly := _roof.get_node("RoofPoly") as Polygon2D
	var points := PackedVector2Array()
	var front_y := -INF
	for point: Vector2 in poly.polygon:
		points.append(poly.to_global(point))
	for point: Vector2 in _roof.footprint_outline_px:
		front_y = maxf(front_y, _roof.to_global(point).y)
	return {"kind":"roof", "bounds":_points_bounds(points), "front_y":front_y, "surfaces":[{"kind":"polygon", "points":points, "front_y":front_y, "path":str(poly.get_path())}]}


func _facade_target() -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group(FOREGROUND.GROUP):
		if node is Sprite2D and _evidence_kit.is_ancestor_of(node) and not String(node.name).contains("Tree"):
			var descriptor := _sprite_surface(node as Sprite2D)
			if not descriptor.is_empty():
				surfaces.append(descriptor)
	for node: Node in get_tree().get_nodes_in_group(&"foreground_solid_occluders"):
		if not node is Polygon2D or not _evidence_kit.is_ancestor_of(node) or not (node as Polygon2D).is_visible_in_tree():
			continue
		var poly := node as Polygon2D
		var parent := poly.get_parent() as Node2D
		var contact: Vector2 = poly.get_meta(FOREGROUND.GROUND_CONTACT, Vector2.ZERO)
		var points := PackedVector2Array()
		for point: Vector2 in poly.polygon:
			points.append(poly.to_global(point))
		surfaces.append({"kind":"polygon", "points":points, "front_y":parent.to_global(contact).y, "path":str(poly.get_path()), "bounds":_points_bounds(points)})
	if surfaces.is_empty():
		_fail("Selected actual home has no registered facade surfaces")
		return {}
	var bounds: Rect2 = surfaces[0].bounds
	var front_y := -INF
	for surface: Dictionary in surfaces:
		bounds = bounds.merge(surface.bounds)
		front_y = maxf(front_y, float(surface.front_y))
	return {"kind":"facade", "bounds":bounds, "front_y":front_y, "surfaces":surfaces}


func _tree_target() -> Dictionary:
	var selected: Dictionary = {}
	var best := INF
	for node: Node in get_tree().get_nodes_in_group(FOREGROUND.GROUP):
		if not node is Sprite2D or not String(node.name).contains("Tree"):
			continue
		var sprite := node as Sprite2D
		var fruit := sprite.texture != null and sprite.texture.resource_path.contains("fruit_tree")
		if (_tree_kind == "fruit" and not fruit) or (_tree_kind == "ordinary" and fruit):
			continue
		var distance := sprite.global_position.distance_squared_to(_volume.global_position)
		if distance >= best:
			continue
		var descriptor := _sprite_surface(sprite)
		if not descriptor.is_empty():
			selected = descriptor
			best = distance
	if selected.is_empty():
		_fail("No actual registered %s tree is streamed near the explicit home" % _tree_kind)
		return {}
	return {"kind":"fruit-tree" if String(selected.texture).contains("fruit_tree") else "ordinary-tree", "bounds":selected.bounds, "front_y":selected.front_y, "ground_world":selected.ground_world, "surfaces":[selected]}


func _sprite_surface(sprite: Sprite2D) -> Dictionary:
	var descriptor := FOREGROUND.describe(sprite)
	if descriptor.is_empty():
		return {}
	var texture: Texture2D = descriptor.texture
	var image := texture.get_image()
	if image == null:
		return {}
	if image.is_compressed():
		image.decompress()
	descriptor["image"] = image
	descriptor["texture"] = texture.resource_path
	descriptor["path"] = str(sprite.get_path())
	descriptor["kind"] = "sprite"
	var parent := sprite.get_parent() as Node2D
	var ground_parent_local: Vector2 = sprite.get_meta(FOREGROUND.GROUND_CONTACT)
	descriptor["ground_world"] = parent.to_global(ground_parent_local)
	return descriptor


func _stage_target(target: Dictionary, front: bool, indices: Array = []) -> void:
	if target.is_empty():
		return
	var bounds: Rect2 = target.bounds
	# Keep materialized actors near the real player while framing a neighboring
	# actual tree. This is explicit plate staging, separate from doorway walking.
	var observer := Vector2(bounds.get_center().x, float(target.front_y) + 180.0)
	if _player.global_position.distance_to(observer) > 500.0:
		_player.global_position = _free_spawn_position(observer)
	_camera.global_position = bounds.get_center() + Vector2(0, 30)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_evidence_cover.call("refresh", _player, true)
	if target.kind == "roof":
		target["other_cover"] = _other_roof_cover()
	var kinds: Array[String] = ["ordinary", "elite", "equipment-pos-locked", "equipment-neg", "health"]
	var group_size := kinds.size() if indices.is_empty() else indices.size()
	var group_index := 0
	for index in kinds.size():
		if not indices.is_empty() and not indices.has(index):
			continue
		var desired := bounds.get_center() + Vector2((group_index - float(group_size - 1) * 0.5) * 56.0, 20.0 if group_index % 2 == 0 else -25.0)
		group_index += 1
		if front:
			desired.y = float(target.front_y) + 110.0
		var node: Node2D
		if index < 2:
			var enemy := ENEMY.instantiate() as EnemyActor
			enemy.spec = load("res://core/actors/enemy/EnemySpec_Brute.tres" if index == 1 else "res://core/actors/enemy/EnemySpec_Grunt.tres") as EnemySpec
			# Existing authored persistence hook: the ordinary body must remain
			# the same body when the real doorway route leaves its 640px band.
			enemy.set_meta(&"never_cull", true)
			enemy.position = desired
			_game.add_child(enemy)
			enemy.player = _player
			if index == 1:
				enemy.apply_elite_modifiers([EliteModifiers.ARMOURED] as Array[StringName])
			enemy.set_scheduler_tier(0)
			enemy.set_physics_process(false)
			node = enemy
		elif index < 4:
			var item := ITEM_SCENE.instantiate() as ItemPickup
			var data := Global.get_item_data("ring_crusher")
			if data == null:
				_fail("Real ring_crusher item data is unavailable")
				item.free()
				continue
			item.item_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS if index == 2 else ItemInstance.Polarity.NEG, 0.25, false)
			item.item_id = String(data.id)
			item.persistent_world_drop = true
			item.is_exploration_loot = index == 2
			item.pickup_delay = 120.0 if index == 2 else 0.0
			item.drop_pickup_delay = 0.0
			item.position = desired
			_game.add_child(item)
			# This isolated presentation fixture tests unlocked art, not pickup
			# acquisition. Keep VFX readiness/modulation and icon refresh live.
			item.monitoring = false
			item.monitorable = false
			node = item
		else:
			var health := HEALTH_SCENE.instantiate() as HealthPickup
			health.pickup_delay = 120.0
			health.lifetime_seconds = 120.0
			health.position = desired
			_game.add_child(health)
			health.monitoring = false
			health.monitorable = false
			node = health
		_evidence_entities.append({"node":weakref(node), "kind":kinds[index], "requested":desired, "initial_instance_id":node.get_instance_id(), "initial_world_handle":int(node.get("_enemy_world_handle")) if node is EnemyActor else 0})
	await _frames(4)
	var occupied: Array[Vector2] = []
	for entry: Dictionary in _evidence_entities:
		var node := (entry.node as WeakRef).get_ref() as Node2D
		var geometry := _entity_geometry(node)
		var offset: Vector2 = geometry.center - node.global_position
		var feet_delta := float(geometry.feet_y) - (geometry.center as Vector2).y
		var sample := _choose_point(target, entry.requested, feet_delta, occupied, front)
		node.global_position = sample - offset
		if node is EnemyActor:
			(node as EnemyActor).velocity = Vector2.ZERO
		entry["resolved"] = node.global_position
		entry["selected_visual_center"] = sample
		entry["cutaway_independent_cover"] = _target_strength({"kind":"other", "surfaces":target.get("other_cover",[])}, sample, sample.y + feet_delta)
		occupied.append(sample)
	await _frames(6)


func _choose_point(target: Dictionary, desired: Vector2, feet_delta: float, occupied: Array[Vector2], front: bool) -> Vector2:
	# Diagnostic placement only: expand a bounded grid until the first valid
	# original-source sample, avoiding a full world-cover scan for each point.
	var prefer_isolated: bool = target.kind == "roof" and not front
	for isolation_pass in range(2 if prefer_isolated else 1):
		for radius in range(21):
			for y in range(-radius, radius + 1):
				for x in range(-radius, radius + 1):
					if maxi(absi(x), absi(y)) != radius:
						continue
					var point := desired + Vector2(x, y) * 8.0
					var feet_y := point.y + feet_delta
					if front:
						if feet_y < float(target.front_y):
							continue
					elif _target_strength(target, point, feet_y) < 0.65:
						continue
					if prefer_isolated and isolation_pass == 0 and _target_strength({"kind":"other", "surfaces":target.get("other_cover",[])}, point, feet_y) > 0.01:
						continue
					var separated := true
					for previous: Vector2 in occupied:
						if point.distance_squared_to(previous) < 42.0 * 42.0:
							separated = false
					if not separated:
						continue
					var strength := float(_evidence_cover.call("strength_at", point, feet_y))
					if (front and strength <= 0.01) or (not front and strength >= 0.65):
						return point
	_fail("No separated genuine %s sample near %s for feet offset %.1f" % [target.kind, desired, feet_delta])
	return desired


func _target_strength(target: Dictionary, point: Vector2, feet_y: float) -> float:
	if target.kind == "roof" and (_roof._inside_count > 0 or (_roof.get_node("RoofPoly") as Polygon2D).modulate.a <= 0.0):
		return 0.0
	var result := 0.0
	for surface: Dictionary in target.surfaces:
		if feet_y >= float(surface.front_y):
			continue
		if surface.kind == "polygon":
			if Geometry2D.is_point_in_polygon(point, surface.points):
				result = maxf(result, float(surface.get("strength", 1.0)))
		else:
			var uv: Vector2 = (surface.world_to_uv as Transform2D) * point
			if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
				continue
			var region: Rect2 = surface.source_rect
			var image: Image = surface.image
			var source := Vector2i(region.position + uv * region.size)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(source):
				result = maxf(result, image.get_pixelv(source).a * float(surface.get("strength", 1.0)))
	return result


func _other_roof_cover() -> Array[Dictionary]:
	# Read the already published snapshot and its cached geometry/images. This
	# diagnostic does not alter roof counters, fades or shared cover state.
	var result: Array[Dictionary] = []
	var roof_cache: Dictionary = _evidence_cover.get("_roof_cache")
	var selected: Array = (roof_cache.get(_roof.get_instance_id(), {}) as Dictionary).get("pieces", [])
	var sources: Dictionary = _evidence_cover.get("_source_cache")
	var records: Array = _evidence_cover.get("_records")
	for record: Dictionary in records:
		if int(record.kind) == 0:
			var belongs_to_selected := false
			for piece: Dictionary in selected:
				if piece.points == record.points and is_equal_approx(float(piece.front_y), float(record.front_y)):
					belongs_to_selected = true
					break
			if not belongs_to_selected:
				result.append({"kind":"polygon", "points":record.points, "front_y":record.front_y, "strength":record.strength})
		else:
			var texture: Texture2D = record.texture
			var cached: Dictionary = sources.get(texture.get_instance_id(), {})
			if not cached.is_empty():
				result.append({"kind":"sprite", "image":cached.image, "world_to_uv":record.world_to_uv, "source_rect":record.source_rect, "front_y":record.front_y, "strength":record.strength})
	return result


func _entity_geometry(node: Node2D) -> Dictionary:
	if node is EnemyActor:
		var transform := _evidence_renderer.debug_actor_instance_transform(node)
		var handle := int(node.get("_enemy_world_handle"))
		return {"center":transform.origin, "feet_y":(transform * Vector2(0, -0.5)).y, "uv":str(_evidence_renderer.debug_actor_instance_uv(node)), "batched":bool(node.get("_visual_batched")), "world_handle":handle, "world_handle_valid":EnemyWorld.is_valid_handle(handle), "world_flags":EnemyWorld.get_flags(handle) if EnemyWorld.is_valid_handle(handle) else 0, "dead":bool(node.get("dead")), "hp":float(node.get("hp")), "in_pool":bool(node.get_meta(&"__in_pool",false)), "fixture_never_cull":bool(node.get_meta(&"never_cull",false)), "actor_instance_id":node.get_instance_id()}
	var icon := node.get_node("Icon") as Sprite2D
	var area := node as Area2D
	return {"center":icon.global_position, "feet_y":node.global_position.y, "texture":icon.texture.resource_path if icon.texture != null else "", "modulate":str(icon.modulate), "visible":icon.is_visible_in_tree(), "fixture_noncollecting":area != null and not area.monitoring and not area.monitorable, "monitoring":area.monitoring if area != null else false, "pickup_ready":bool(node.get("_pickup_ready"))}


func _capture_entities(name: String, target: Dictionary, covered: bool, cutaway: bool = false) -> void:
	_evidence_cover.call("refresh", _player, true)
	await _frames(4)
	await _still(name)
	var entities: Array[Dictionary] = []
	for entry: Dictionary in _evidence_entities:
		var node := (entry.node as WeakRef).get_ref() as Node2D
		if node == null:
			var initial_handle := int(entry.get("initial_world_handle",0))
			var current_actor: Node2D = EnemyWorld.actor_for_handle(initial_handle) if EnemyWorld.is_valid_handle(initial_handle) else null
			entities.append({"kind":entry.kind, "missing":true, "initial_instance_id":entry.get("initial_instance_id",0), "initial_world_handle":initial_handle, "world_handle_valid":EnemyWorld.is_valid_handle(initial_handle), "current_representation":EnemyWorld.get_representation(initial_handle) if EnemyWorld.is_valid_handle(initial_handle) else -1, "replacement_actor_instance_id":current_actor.get_instance_id() if current_actor != null else 0})
			_fail("Staged %s disappeared before %s (initial handle %d)" % [entry.kind,name,initial_handle])
			continue
		var geometry := _entity_geometry(node)
		var center: Vector2 = geometry.center
		var feet_y := float(geometry.feet_y)
		var strength := float(_evidence_cover.call("strength_at", center, feet_y))
		var target_strength := _target_strength(target, center, feet_y)
		var independent_cover := float(entry.get("cutaway_independent_cover", 0.0))
		if cutaway and target_strength > 0.01:
			_fail("%s %s retained selected-roof coverage after actual entry" % [name, entry.kind])
		elif cutaway and independent_cover <= 0.01 and strength > 0.01:
			_fail("%s %s retained shared cover despite an isolated roof sample" % [name, entry.kind])
		elif not cutaway and ((covered and strength < 0.5) or (not covered and strength > 0.01)):
			_fail("%s %s actual cover strength %.3f contradicts the plate's intended condition" % [name, entry.kind, strength])
		var record := {"kind":entry.kind, "requested_visual_center":str(entry.requested), "selected_visual_center":str(entry.get("selected_visual_center",center)), "resolved_actor_origin":str(entry.get("resolved",node.global_position)), "actual_actor_origin":str(node.global_position), "actual_visual_center":str(center), "feet_y":feet_y, "cover_strength":strength, "target_surface_strength":target_strength, "independent_cover_before_cutaway":independent_cover, "shared_uncovered_expected":cutaway and independent_cover <= 0.01, "actual_cell_walkable":_chunks.is_cell_walkable(_chunks.world_to_cell(node.global_position)), "physics_processing":node.is_physics_processing()}
		record.merge(geometry, false)
		if node is EnemyActor and not bool(geometry.batched):
			_fail("Staged enemy bypassed the production batch renderer")
		entities.append(record)
	var surfaces: Array[Dictionary] = []
	for surface: Dictionary in target.surfaces:
		surfaces.append({"path":surface.path, "kind":surface.kind, "texture":surface.get("texture",""), "front_y":surface.front_y})
	_evidence_plates.append({"file":name+".png", "target":target.kind, "surface_bounds":str(target.bounds), "surfaces":surfaces, "intended_covered":covered, "expected_condition_asserted":true, "condition":"Selected roof coverage is zero; shared coverage is also zero for independently isolated samples. Other live cover is disclosed per entity." if cutaway else ("Shared coverage is positive." if covered else "Shared coverage is zero."), "entities":entities, "quiet_wait":_last_quiet_wait.duplicate(), "player":str(_player.global_position), "roof_inside_count":_roof._inside_count, "roof_alpha":(_roof.get_node("RoofPoly") as Polygon2D).modulate.a, "camera":str(_camera.global_position), "camera_zoom":str(_camera.zoom), "window":str(get_window().size), "renderer_visible_count":_evidence_renderer.visible_count(), "renderer_registered_actors":_evidence_renderer.registered_actor_count(), "snapshot":_evidence_cover.call("snapshot_stats")})


func _clear_entities() -> void:
	for entry: Dictionary in _evidence_entities:
		var node := (entry.node as WeakRef).get_ref() as Node
		if node != null:
			node.queue_free()
	_evidence_entities.clear()


func _points_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


func _still(name: String) -> void:
	await _wait_for_coverage_quiet()
	await super._still(name)


func _wait_for_coverage_quiet() -> void:
	# Elite status callouts last exactly 0.9s (BattleText.statuses_popup).
	# Their illustrated HUD teaching lasts 4s plus its authored 0.12s gap.
	# Observe the live owners so delayed/queued notices expire naturally.
	var controllers: Array[HudTutorialTipController] = []
	for node: Node in _game.find_children("*", "", true, false):
		if node is HudTutorialTipController:
			controllers.append(node as HudTutorialTipController)
	var began := Time.get_ticks_msec()
	var stable_empty := 0
	for _step in range(300):
		var running := false
		var queued := 0
		for controller: HudTutorialTipController in controllers:
			if is_instance_valid(controller):
				running = running or bool(controller.get("_running"))
				var queue: Array = controller.get("_queue")
				queued += queue.size()
		var battle_entries := int(BattleText.get("_count"))
		stable_empty = stable_empty + 1 if not running and queued == 0 and battle_entries == 0 else 0
		if stable_empty >= 2:
			await _frames(2)
			_last_quiet_wait = {"wall_seconds":float(Time.get_ticks_msec()-began)/1000.0, "hud_running":running, "hud_queued":queued, "battle_text_entries":battle_entries, "controllers":controllers.size()}
			return
		await get_tree().create_timer(0.1, false).timeout
	_fail("Actual tutorial/callout owners did not become quiet within 30 seconds")


func _capture_player_tree_route(target: Dictionary) -> void:
	var plates: Array[Dictionary] = []
	if not target.is_empty():
		var bounds: Rect2 = target.bounds
		_camera.global_position = bounds.get_center() + Vector2(0, 45)
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		await _frames(6)
		_evidence_cover.call("refresh", _player, true)
		var reachable := _player_reachable_cells()
		var samples := _player_fragment_samples()
		var front := _player_tree_waypoint(target, reachable, samples, false)
		var behind := _player_tree_waypoint(target, reachable, samples, true)
		if front == Vector2.INF or behind == Vector2.INF:
			_fail("The actual selected tree has no verified reachable player front/covered pair")
		else:
			for phase: Dictionary in [{"name":"player-tree-front", "desired":front, "covered":false}, {"name":"player-tree-behind", "desired":behind, "covered":true}, {"name":"player-tree-front-restored", "desired":front, "covered":false}]:
				var desired: Vector2 = phase.desired
				var failures_before := _failures
				await _walk_to(desired)
				await _frames(6)
				if _failures > failures_before or _player.global_position.distance_to(desired) > 16.0:
					_fail("Player did not physically reach the requested tree waypoint: " + String(phase.name))
					break
				plates.append(await _capture_player_tree_plate(String(phase.name), target, desired, bool(phase.covered)))
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Player tree evidence selected or wrote a profile")
	var report := {"capture_scene":"res://tools/dev/CityEntityCoverPreview.tscn", "scene":"res://scenes/game.tscn", "player_tree_only":true, "args":OS.get_cmdline_user_args(), "attempt_seed":_city_world_seed, "segment":_city_segment, "requested_building_id":_target_building_id, "requested_chunk":str(_target_chunk), "tree_kind":_tree_kind, "plates":plates, "route":_route_notes, "save_writes":writes, "failures":_failures, "limits":"Controlled native actual-Game player-only route around an original generated city/fruit tree. Player walks to real reachable walkable cell centers using production inputs and collision. Actual Body/Head animation, shared material and cover refresh remain live; no shader replacement, canopy movement, counter manipulation or route teleport. Initial home staging, ambient spawn/encounter suppression, god mode and fixed camera are inherited capture controls. Pixel/coverage samples are diagnostic and not continuous human-motion acceptance."}
	report.merge(_district_evidence(), false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file := FileAccess.open(_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write player-tree evidence manifest")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("CityEntityCoverPreview player-tree-only: plates=%d failures=%d save_writes=%d -> %s" % [plates.size(), _failures, writes, _out])


func _player_reachable_cells() -> Dictionary:
	var start: Vector2i = _chunks.world_to_cell(_player.global_position)
	var reachable: Dictionary = {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if reachable.has(next) or absi(next.x - start.x) > 40 or absi(next.y - start.y) > 40 or not _chunks.is_cell_walkable(next):
				continue
			reachable[next] = true
			queue.append(next)
	return reachable


func _player_tree_waypoint(target: Dictionary, reachable: Dictionary, samples: Array[Dictionary], behind: bool) -> Vector2:
	var visual := _player.get_node("Visual") as Node2D
	var feet_offset: Vector2 = visual.global_position - _player.global_position
	var ground: Vector2 = target.ground_world
	var desired := ground + Vector2(0, -56.0 if behind else 80.0) - feet_offset
	var bounds: Rect2 = (target.bounds as Rect2).grow(160.0)
	var first: Vector2i = _chunks.world_to_cell(bounds.position)
	var last: Vector2i = _chunks.world_to_cell(bounds.end)
	var selected := Vector2.INF
	var best := INF
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not reachable.has(cell) or not _chunks.is_cell_walkable(cell):
				continue
			var point: Vector2 = _chunks.cell_to_world_center(cell)
			var feet_y: float = point.y + feet_offset.y
			if (behind and feet_y >= float(target.front_y) - 8.0) or (not behind and feet_y < float(target.front_y) + 8.0):
				continue
			var covered_samples := 0
			for sample: Dictionary in samples:
				var offset: Vector2 = (sample.world as Vector2) - _player.global_position
				if _target_strength(target, point + offset, feet_y) >= 0.65:
					covered_samples += 1
			if behind and covered_samples < 2:
				continue
			var distance: float = point.distance_squared_to(desired)
			if distance < best:
				best = distance
				selected = point
	return selected


func _player_fragment_samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part: String in ["Body", "HeadAnchor/Head"]:
		var sprite := _player.get_node("Visual/" + part) as AnimatedSprite2D
		if sprite.sprite_frames == null or sprite.animation == &"":
			continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var image := texture.get_image()
		if image == null:
			continue
		if image.is_compressed():
			image.decompress()
		var image_origin := Vector2.ZERO
		if texture is AtlasTexture:
			image_origin = (texture as AtlasTexture).margin.position
		var draw_origin: Vector2 = sprite.offset - (texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO)
		for gy in range(1, 7):
			for gx in range(1, 7):
				var source := Vector2i(Vector2(image.get_size()) * Vector2(gx, gy) / 7.0)
				if image.get_pixelv(source).a < 0.6:
					continue
				var logical := image_origin + Vector2(source) + Vector2.ONE * 0.5
				if sprite.flip_h:
					logical.x = texture.get_width() - logical.x
				if sprite.flip_v:
					logical.y = texture.get_height() - logical.y
				result.append({"part":part, "world":sprite.to_global(draw_origin + logical), "source_alpha":image.get_pixelv(source).a})
	return result


func _capture_player_tree_plate(name: String, target: Dictionary, desired: Vector2, covered: bool) -> Dictionary:
	_evidence_cover.call("refresh", _player, true)
	await _frames(2)
	await _still(name)
	var visual := _player.get_node("Visual") as Node2D
	var body := _player.get_node("Visual/Body") as AnimatedSprite2D
	var head := _player.get_node("Visual/HeadAnchor/Head") as AnimatedSprite2D
	var feet_y: float = visual.global_position.y
	var fragments: Array[Dictionary] = []
	var max_tree := 0.0
	var max_shared := 0.0
	for sample: Dictionary in _player_fragment_samples():
		var point: Vector2 = sample.world
		var tree_strength: float = _target_strength(target, point, feet_y)
		var shared_strength := float(_evidence_cover.call("strength_at", point, feet_y))
		max_tree = maxf(max_tree, tree_strength)
		max_shared = maxf(max_shared, shared_strength)
		fragments.append({"part":sample.part, "world":str(point), "source_alpha":sample.source_alpha, "tree_strength":tree_strength, "shared_strength":shared_strength})
	if covered and max_tree < 0.65:
		_fail("Actual reached player body/head pixels are not covered by the selected real tree")
	if not covered and (feet_y < float(target.front_y) or max_tree > 0.01):
		_fail("Actual player front control did not restore normal tree-depth presentation")
	if body.material == null or body.material != head.material:
		_fail("The live player body/head lost their shared authored coverage material")
	var parts: Array[Dictionary] = []
	for sprite: AnimatedSprite2D in [body, head]:
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var material := sprite.material as ShaderMaterial
		parts.append({"node":str(sprite.get_path()), "animation":String(sprite.animation), "frame":sprite.frame, "frame_texture":texture.resource_path, "offset":str(sprite.offset), "global_transform":str(sprite.global_transform), "modulate":str(sprite.modulate), "material_id":material.get_instance_id() if material != null else 0, "shader":material.shader.resource_path if material != null and material.shader != null else "", "material_feet_y":material.get_shader_parameter("world_cover_feet_y") if material != null else null})
	return {"file":name+".png", "target":target.kind, "tree_surface":(target.surfaces as Array)[0].path, "tree_texture":(target.surfaces as Array)[0].texture, "tree_measured_ground_world":str(target.ground_world), "requested_player_root":str(desired), "actual_player_root":str(_player.global_position), "actual_visual_feet":str(visual.global_position), "actual_cell_walkable":_chunks.is_cell_walkable(_chunks.world_to_cell(_player.global_position)), "intended_tree_covered":covered, "max_tree_strength":max_tree, "max_shared_strength":max_shared, "body_head_share_material":body.material == head.material, "parts":parts, "opaque_fragment_samples":fragments, "camera":str(_camera.global_position), "camera_zoom":str(_camera.zoom), "window":str(get_window().size), "roof_inside_count":_roof._inside_count, "roof_alpha":(_roof.get_node("RoofPoly") as Polygon2D).modulate.a, "snapshot":_evidence_cover.call("snapshot_stats")}
