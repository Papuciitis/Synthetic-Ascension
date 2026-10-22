extends Node
## Cold world resources must let the visible wait cue advance. Also verifies
## that incremental preparation builds exactly the same ground pixels and
## prepares a worn plaza state before a manager can warm it synchronously.
const Art = preload("res://core/systems/world/WorldArt.gd")
const Manager = preload("res://core/systems/world/ChunkManager.gd")
const PlazaKit = preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
const TARGET_SEGMENT := 6
const TARGET_WORLD_SEED := 16102028
var _passes := 0
var _failures := 0
var _monitor := false
var _last_usec := 0
var _largest_gap_ms := 0.0
var _frames := 0
var _plaza_frames := 0
var _plaza_draw_frames := 0

func _ready() -> void:
	_run.call_deferred()

func _process(_delta: float) -> void:
	if not _monitor:
		return
	var now := Time.get_ticks_usec()
	var gap_ms := float(now - _last_usec) / 1000.0
	_largest_gap_ms = maxf(_largest_gap_ms, gap_ms)
	if OS.get_environment("FRONTEND_TRACE_READY") == "1" and gap_ms > 60.0:
		print("PREP_FRAME phase=%s gap_ms=%.3f" % [Manager._transition_resource_stage, gap_ms])
	_last_usec = now
	_frames += 1
	if Manager._transition_resource_stage == &"plaza":
		_plaza_frames += 1

func _on_frame_post_draw() -> void:
	if _monitor and Manager._transition_resource_stage == &"plaza":
		_plaza_draw_frames += 1

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)

func _signatures(array: Texture2DArray) -> Array[String]:
	var result: Array[String] = []
	for index in array.get_layers():
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(array.get_layer_data(index).get_data())
		result.append(hash.finish().hex_encode())
	return result

func _run() -> void:
	# This resource fixture does not exercise music. Stop the autoload's menu
	# playback while there are still frames for the audio server to release it.
	AudioManager.stop_all(true)
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	Global.debug_disable_autosave = true
	var save_writes_before: int = SaveManager.debug_save_writes
	var previous_segment: int = Global.attempt_segment
	var previous_seed: int = Global.attempt_world_seed
	Global.attempt_segment = TARGET_SEGMENT
	Global.attempt_world_seed = TARGET_WORLD_SEED
	var theme := SegmentThemePicker.get_theme(TARGET_SEGMENT, TARGET_WORLD_SEED)
	_check(theme.district_family == &"industrial_cutthrough", "pinned segment and seed select the real working district")
	Art.release_static_caches()
	PlazaKit.release_static_caches()
	var plaza_paths := PlazaKit.state_texture_paths(PlazaKit.STATE_WORKING)
	var plaza_cold := not plaza_paths.is_empty()
	for path: String in plaza_paths:
		plaza_cold = plaza_cold and not ResourceLoader.has_cached(path)
	_check(plaza_cold, "working plaza additions begin cold before integrated preparation")
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var scrim := Global.loading_scrim()
	scrim.show_for("Segment 6", get_tree().current_scene)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	# Let the guard release setup duty before measuring loading-cue gaps.
	# _monitor stays false throughout this marker and settling interval.
	print("TRANSITION_WARMUP_READY")
	await get_tree().create_timer(1.0).timeout
	_monitor = true
	_last_usec = Time.get_ticks_usec()
	# Exercise the scene router's entry point with a genuinely cold worn state;
	# the assertions below precede any direct-scene synchronous fallback.
	var manager_script: Script = load("res://core/systems/world/ChunkManager.gd")
	var methods := manager_script.get_script_method_list()
	for method: Dictionary in methods:
		if method["name"] == "prepare_transition_resources":
			await manager_script.call("prepare_transition_resources", get_tree())
			break
	# Assert here, before constructing a manager: its synchronous warm fallback
	# must never hide a missing plaza stage in the transition preparation.
	_check(Manager._transition_resource_stage == &"ready", "integrated preparation reaches ready after the plaza stage")
	_check(PlazaKit.resident_style() == PlazaKit.STYLE_KERB and PlazaKit._loaded_fill != null,
		"working plaza edge cache is ready before manager instantiation")
	_check(PlazaKit._dressing_state == PlazaKit.STATE_WORKING and PlazaKit._dressing.get(&"worn_atlas") != null,
		"working plaza dressing cache is ready before manager instantiation")
	var plaza_cached := not plaza_paths.is_empty()
	for path: String in plaza_paths:
		plaza_cached = plaza_cached and ResourceLoader.has_cached(path)
	_check(plaza_cached, "all working plaza additions are retained after integrated preparation")
	_check(_plaza_frames > 0, "cold plaza preparation yields loading-cue process frames")
	if DisplayServer.get_name() != "headless":
		_check(_plaza_draw_frames > 0, "cold plaza preparation submits visible loading-cue frames")
	var manager := Manager.new()
	# Match Game's supported pre-configuration state: _ready must not replace
	# the prepared working cache with the default tended-family warm fallback.
	manager.generation_enabled = false
	theme.apply_to_chunk_manager(manager)
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	_monitor = false
	_check(PlazaKit.resident_style() == PlazaKit.STYLE_KERB and PlazaKit._dressing_state == PlazaKit.STATE_WORKING,
		"generation-disabled manager preserves the prepared working plaza state")
	_check(_frames >= 5, "cold preparation renders multiple loading-cue frames rather than one frozen card")
	_check(_largest_gap_ms < 250.0, "cold preparation avoids the previous one-second main-thread block (largest %.1f ms)" % _largest_gap_ms)
	print("WARMUP frames=%d largest_gap_ms=%.3f plaza_process_frames=%d plaza_draw_frames=%d renderer=%s" % [_frames, _largest_gap_ms, _plaza_frames, _plaza_draw_frames, DisplayServer.get_name()])
	# The dummy headless renderer cannot read Texture2DArray layers back.
	# Pixel equivalence is exercised by this same scene with a real renderer.
	if DisplayServer.get_name() != "headless":
		var prepared := _signatures(Art.ground_material_array())
		Art.release_static_caches()
		var synchronous := _signatures(Art.ground_material_array(false))
		_check(prepared == synchronous and prepared.size() > 0, "prepared ground layers are pixel-identical to the original synchronous route")
	manager.queue_free()
	player.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
	PlazaKit.release_static_caches()
	Global.attempt_segment = previous_segment
	Global.attempt_world_seed = previous_seed
	_check(SaveManager.debug_save_writes == save_writes_before and SaveManager.current_save == null,
		"transition resource fixture makes no save writes or profile selection")
	print("TransitionResourceWarmupTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
