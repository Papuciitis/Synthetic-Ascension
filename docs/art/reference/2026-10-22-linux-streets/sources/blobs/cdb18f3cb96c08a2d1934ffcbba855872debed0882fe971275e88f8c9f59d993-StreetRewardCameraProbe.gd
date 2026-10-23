extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Metadata-only extension of the actual fixed-camera ground preview. It does
## not select a different building, alter geometry, hide art or change time.

const REWARD_ID: int = 2098284276
const REWARD_CHUNK: Vector2i = Vector2i(0, 9)
var _reward_camera_evidence: Dictionary = {}
var _reward_render_fps: int = 60


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-fps="):
			var requested: String = arg.trim_prefix("--runtime-fps=")
			if requested not in ["20", "30", "60"]:
				_fail("Reward capture runtime FPS must be explicitly 20, 30 or 60")
			else:
				_reward_render_fps = int(requested)


func _prepare_runtime() -> void:
	super._prepare_runtime()
	Engine.max_fps = _reward_render_fps


func _capture_ground_review() -> void:
	_bind_reward_camera()
	await super._capture_ground_review()


func _district_evidence() -> Dictionary:
	var evidence: Dictionary = super._district_evidence()
	evidence["reward_camera_binding"] = _reward_camera_evidence
	return evidence


func _bind_reward_camera() -> void:
	if not _has_ground_context or _chunks._world_to_chunk(_ground_context) != REWARD_CHUNK:
		_fail("Reward camera requires the explicit ground context in chunk (0, 9)")
		return
	var volume: IndoorVolume = null
	for candidate: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if candidate is IndoorVolume and (candidate as IndoorVolume).building_id == REWARD_ID:
			volume = candidate as IndoorVolume
			break
	if volume == null or _chunks._world_to_chunk(volume.global_position) != REWARD_CHUNK:
		_fail("Reward camera did not stream actual building 2098284276 in chunk (0, 9)")
		return
	var entry: Vector2 = volume.to_global(volume.get("_presentation_entry"))
	var outward: Vector2 = volume.get("_presentation_outward")
	var width: float = volume.get("_presentation_width")
	if outward == Vector2.ZERO or width <= 0.0:
		_fail("Reward building has no actual presentation entry geometry")
		return
	var pixel: Vector2 = get_viewport().get_canvas_transform() * entry
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(pixel):
		_fail("Actual reward doorway is outside the requested camera")
	var roof: RoofOverlay = null
	for connection: Dictionary in volume.body_entered.get_connections():
		var owner: Object = (connection.callable as Callable).get_object()
		if owner is RoofOverlay:
			roof = owner as RoofOverlay
	if roof == null:
		_fail("Reward building has no connected production roof")
		return
	var footprint: Array = []
	for point: Vector2 in roof.footprint_outline_px:
		var world: Vector2 = roof.to_global(point)
		footprint.append([world.x, world.y])
	var splat: GroundSplatRenderer = _chunks.get_ground_splat()
	if splat == null:
		_fail("Reward camera has no production ground splat renderer")
		return
	var across: Vector2 = Vector2(-outward.y, outward.x)
	var taps: Array[Dictionary] = []
	for depth: int in range(1, 5):
		for side: float in [-1.0, -0.25, 0.25, 1.0]:
			var lateral: float = width * side if absf(side) < 0.5 else (width * 0.5 + float(_chunks.cell_size_px) * 0.5) * side
			var world: Vector2 = entry + outward * float(depth * _chunks.cell_size_px) + across * lateral
			var cell: Vector2i = _chunks.world_to_cell(world)
			taps.append({"depth_cells": depth, "side": side, "role": "core" if absf(side) < 0.5 else "shoulder", "world": [world.x, world.y], "cell": [cell.x, cell.y], "material": splat.material_at(cell), "care": splat.care_at(cell), "walkable": _chunks.is_cell_walkable(cell)})
	_reward_camera_evidence = {"building_id": volume.building_id, "chunk": [REWARD_CHUNK.x, REWARD_CHUNK.y], "entry_world": [entry.x, entry.y], "outward": [outward.x, outward.y], "width_px": width, "entry_viewport_pixel": [pixel.x, pixel.y], "entry_visible": viewport_rect.has_point(pixel), "world_footprint": footprint, "ground_taps": taps, "runtime_render_fps_cap": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second, "limits": "Read-only geometry and ground observations from the actually streamed reward building. The parent fixed-camera preview stages placement and freezes streaming after its checked reload; this is visual evidence, not live traversal or performance evidence."}
