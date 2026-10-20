extends Node
## Cold world resources must let the visible wait cue advance. Also verifies
## that incremental preparation builds exactly the same ground pixels.
const Art = preload("res://core/systems/world/WorldArt.gd")
const Manager = preload("res://core/systems/world/ChunkManager.gd")
var _passes := 0
var _failures := 0
var _monitor := false
var _last_usec := 0
var _largest_gap_ms := 0.0
var _frames := 0

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
	Art.release_static_caches()
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var scrim := Global.loading_scrim()
	scrim.show_for("Segment 2", get_tree().current_scene)
	await get_tree().process_frame
	_monitor = true
	_last_usec = Time.get_ticks_usec()
	# The old path is intentionally exercised if no incremental preparation
	# exists; it blocks ChunkManager._ready and fails the frame-gap checks.
	var manager_script: Script = load("res://core/systems/world/ChunkManager.gd")
	var methods := manager_script.get_script_method_list()
	for method: Dictionary in methods:
		if method["name"] == "prepare_transition_resources":
			await manager_script.call("prepare_transition_resources", get_tree())
			break
	var manager := Manager.new()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	_monitor = false
	_check(_frames >= 5, "cold preparation renders multiple loading-cue frames rather than one frozen card")
	_check(_largest_gap_ms < 250.0, "cold preparation avoids the previous one-second main-thread block (largest %.1f ms)" % _largest_gap_ms)
	print("WARMUP frames=%d largest_gap_ms=%.3f" % [_frames, _largest_gap_ms])
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
	print("TransitionResourceWarmupTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
