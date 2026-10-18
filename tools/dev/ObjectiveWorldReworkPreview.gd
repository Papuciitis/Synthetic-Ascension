extends "res://tools/dev/S10BossTelegraphPreview.gd"
## Controlled frozen states in the actual S3 Game/HUD, never a played fight.
## Run only in the coordinator's graphical engine slot with isolated APPDATA.
## Completion requires the manifest AND final summary, not --quit-after alone.
const WARD := preload("res://scenes/world/wardstones/Wardstone.tscn")
const RITE := preload("res://scenes/world/gates/ExitRite.tscn")
const RELAY := preload("res://core/systems/world/objectives/DistrictRelayObjective.gd")
const VIGIL := preload("res://core/systems/world/objectives/WardVigilObjective.gd")
const WAGER := preload("res://core/systems/world/objectives/WagerShrineObjective.gd")
const WORLD_ART := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
const PANELS: PackedStringArray = ["sanctuary", "rite-states", "rite-channel", "rite-grace-drain", "rite-pressure", "relay", "vigil", "wager", "wager-refusal"]
var _only := ""
var _finishing := false
var _panel_notes: Dictionary = {}
var _spawner: EnemySpawner
var _renderer: EnemyProxyRenderer


func _enter_tree() -> void:
	_out = "res://.superpowers/sdd/2026-10-18-objective-visual-rework/world-captures/"
	super._enter_tree()
	SaveManager.save_dir = "user://tests/objective_world_rework_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")


func _run() -> void:
	get_tree().create_timer(180.0).timeout.connect(_timed_out)
	if DisplayServer.get_name() == "headless":
		_fail("ObjectiveWorldReworkPreview needs a native graphical renderer")
		await _finish()
		return
	if not _only.is_empty() and not PANELS.has(_only):
		_fail("unknown --only panel: " + _only)
		await _finish()
		return
	var mkdir := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if mkdir != OK and mkdir != ERR_ALREADY_EXISTS:
		_fail("capture directory cannot be created: " + error_string(mkdir))
		await _finish()
		return
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 3
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — CONTROLLED objective world rework"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_spawner = _game.get_node("Spawner") as EnemySpawner
	var chunks := _game.get_node("ChunkManager") as ChunkManager
	var settled := false
	for frame in range(360):
		await get_tree().process_frame
		if _finishing:
			return
		if frame >= 20 and chunks.debug_chunk_queue().is_empty() and chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	if not settled:
		_fail("bounded S3 world generation did not settle")
		await _finish()
		return
	_quiet_tutorials()
	get_tree().paused = false
	_origin = _player.global_position
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	for group: StringName in [&"primary_objective", &"secondary_objective", &"wardstones", &"exit_rite"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is CanvasItem:
				node.visible = false
	var proxy := _game.get_node_or_null("EnemyProxyRoot") as EnemyProxyRoot
	if proxy != null:
		_renderer = proxy.renderer
	if _renderer == null:
		_fail("actual Game has no enemy proxy renderer")
	await _clear_panel()
	if _finishing:
		return
	for mode: Dictionary in [
		{"size": Vector2i(1280, 720), "reduced": false, "suffix": "normal"},
		{"size": Vector2i(960, 540), "reduced": false, "suffix": "small"},
		{"size": Vector2i(960, 540), "reduced": true, "suffix": "reduced"},
	]:
		get_window().size = mode["size"]
		SettingsManager.set_value(&"accessibility", &"reduced_motion", mode["reduced"], false)
		SettingsManager.set_value(&"accessibility", &"combat_flash", &"off" if mode["reduced"] else &"full", false)
		for panel: String in PANELS:
			if _finishing:
				return
			if not _only.is_empty() and panel != _only:
				continue
			await _clear_panel()
			if _finishing:
				return
			_stage = _new_stage()
			_stage.name = "ControlledObjectiveWorldPanel"
			var before := _game.get_children()
			_panel_notes = {}
			Global.followers = 5000
			RunEvents.objective_changed.emit("", "")
			RunEvents.secondary_objective_changed.emit("", "")
			_place_player(Vector2(0, 280))
			_build_panel(panel)
			await _frames(2) # Deferred real payout nodes must join the panel too.
			if _finishing:
				return
			for child: Node in _game.get_children():
				if child != _stage and not before.has(child):
					child.reparent(_stage, true)
			BattleText.clear()
			_sync_visuals(_stage)
			_freeze(_stage)
			_label(Vector2(-700, -458), Vector2(1400, 34), "CONTROLLED / ACTUAL GAME S3 / " + panel.to_upper().replace("-", " ") + (" / REDUCED + FLASHES OFF" if mode["reduced"] else ""), 23)
			_label(Vector2(-660, 443), Vector2(1320, 26), "FROZEN IMMORTAL STAGING / production geometry and observers / not a played encounter", 17)
			await _frames(4)
			if _finishing:
				return
			var rendered := _renderer.publish() if _renderer != null else 0
			if panel == "rite-pressure" and rendered != 15:
				_fail("rite-pressure renderer published %d bodies, expected 15" % rendered)
			if panel != "rite-pressure" and rendered != 0:
				_fail("prior panel left %d enemy bodies in the renderer" % rendered)
			await RenderingServer.frame_post_draw
			var filename := "%s-%s.png" % [panel, mode["suffix"]]
			var pixels := get_viewport().get_texture().get_image()
			var saved := false
			if pixels.get_size() != mode["size"]:
				_fail("capture dimensions wrong: " + filename)
			else:
				saved = pixels.save_png(ProjectSettings.globalize_path(_out).path_join(filename)) == OK
				if not saved:
					_fail("cannot save " + filename)
			_captures.append({"file": filename, "saved": saved, "panel": panel, "window": str(mode["size"]), "reduced_motion": mode["reduced"], "combat_flash": "off" if mode["reduced"] else "full", "player_position": str(_player.global_position), "camera_center": str(_camera.global_position), "renderer_bodies": rendered, "notes": _panel_notes.duplicate(true)})
			print("ObjectiveWorldReworkPreview CAPTURE ", filename, " rendered_enemies=", rendered, " saved=", saved)
	await _clear_panel()
	var expected := (PANELS.size() if _only.is_empty() else 1) * 3
	if _captures.size() != expected:
		_fail("incomplete capture set: %d/%d" % [_captures.size(), expected])
	await _finish()


func _place_player(offset: Vector2) -> void:
	_player.global_position = _origin + offset
	_camera.position = -offset
	_camera.reset_smoothing()
	_camera.force_update_scroll()


func _objective(script: Script, at: Vector2) -> Node2D:
	var objective: Node2D = script.new()
	objective.position = _origin + at
	if objective.has_method("configure"):
		objective.call("configure", 87139)
	_stage.add_child(objective)
	if objective is PrimaryObjective:
		objective.player = _player
	return objective


func _rite(at: Vector2, state: String, fraction: float = 0.0, safeguards: int = 0) -> ExitRite:
	var saved_rules: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	Global.attempt_doctrine_rules = {"rite_safeguard_capacity": 5}
	var rite := RITE.instantiate() as ExitRite
	rite.position = _origin + at
	_stage.add_child(rite)
	if state != "locked":
		rite.set_locked(false)
	Global.attempt_doctrine_rules = saved_rules
	rite.set("_hold", rite.hold_time * fraction)
	rite.get("_progress_ledger").call("initialize_sealed", int(floorf(fraction * 3.0)))
	rite.set("_player_inside", state == "working")
	rite.set("_lapse", rite.lapse_grace + 0.3 if state == "draining" else rite.lapse_grace * 0.5)
	rite.set("_completed", state == "complete")
	if safeguards > 0:
		rite.grant_safeguard(&"controlled-preview", safeguards)
	rite.call("_refresh_world_art")
	rite.queue_redraw()
	for child: Node in rite.get_node("Vfx").get_children():
		child.queue_free()
	if rite.presentation_state() != state:
		_fail("Rite observer differs from staged %s: %s" % [state, rite.presentation_state()])
	if not "exit_rite_v2" in rite.gate_art.texture.resource_path:
		_fail("Rite capture still uses an old source asset")
	return rite


func _build_panel(panel: String) -> void:
	match panel:
		"sanctuary":
			_place_player(Vector2(-270, 20))
			var attuning := WARD.instantiate() as Wardstone
			attuning.position = _origin + Vector2(-270, 0)
			_stage.add_child(attuning)
			attuning.set("_player", _player)
			attuning.set("_player_inside", true)
			attuning.set("_capture", attuning.capture_time * 0.58)
			attuning.set("_stability_ring_near", true)
			attuning.call("_refresh_world_art")
			attuning.queue_redraw()
			var anchored := WARD.instantiate() as Wardstone
			anchored.position = _origin + Vector2(270, 0)
			_stage.add_child(anchored)
			anchored.restore_active()
			if not "wardstone_v2" in anchored.obelisk.texture.resource_path:
				_fail("Wardstone capture still uses an old source asset")
			_panel_notes = {"left": "58 percent temporary capture; player inside; resets on exit", "right": "restore_active; anchored base and real sanctuary; no reward replay"}
		"rite-states":
			_place_player(Vector2(0, -70))
			_rite(Vector2(-380, -120), "locked")
			_rite(Vector2(380, -120), "complete", 1.0)
			_rite(Vector2(0, 200), "ready")
			_panel_notes = {"layout": "locked upper left / complete upper right / ready lower center", "completed": "controlled completed flag and full durable ledger; no climax or segment transition"}
		"rite-channel", "rite-pressure":
			_place_player(Vector2(0, 65))
			if panel == "rite-pressure":
				var enemies: Array = _spawner.spawn_burst_at(_origin + Vector2(0, -15), 15, 235.0)
				if enemies.size() != 15:
					_fail("production source produced %d/15 enemies" % enemies.size())
				for enemy: Node in enemies:
					_freeze(enemy)
					enemy.reparent(_stage, true)
				_panel_notes["produced"] = enemies.size()
				_panel_notes["producer"] = "EnemySpawner.spawn_burst_at; real ordinary S3 source roster, not fabricated sprites or a claimed scripted Rite wave"
			var rite := _rite(Vector2.ZERO, "working", 0.74, 5)
			_panel_notes["rite"] = rite.balance_snapshot()
		"rite-grace-drain":
			_place_player(Vector2(0, 300))
			var grace := _rite(Vector2(-270, 0), "grace", 0.5, 1)
			var drain := _rite(Vector2(270, 0), "draining", 0.5, 1)
			_panel_notes = {"left": grace.balance_snapshot(), "right": drain.balance_snapshot(), "player": "outside both circles; grace and lapse clocks deliberately set to distinct production branches"}
		"relay":
			_place_player(Vector2(500, 300))
			var relay := _objective(RELAY, Vector2.ZERO) as DistrictRelayObjective
			relay.set("_component_silenced", PackedByteArray([1, 0, 0]))
			relay.set("_component_progress", PackedFloat32Array([relay.attune_time_sec, relay.attune_time_sec * 0.55, 0.0]))
			relay.update_presentation()
			relay.queue_redraw()
			if relay.get("_site_art").size() != 3 or relay.get_node_or_null("ObjectiveArt") != null:
				_fail("Relay has a false fourth receiver or missing real receiver")
			_panel_notes = {"real_sites": 3, "states": "one silenced / 55 percent banked while player outside / untouched", "layout": str(relay.get("_component_positions"))}
		"vigil":
			_place_player(Vector2(-270, 65))
			var held := _objective(VIGIL, Vector2(-270, 0)) as WardVigilObjective
			held.set("_inside", true)
			held.set("_held", held.vigil_seconds * 0.62)
			held.update_presentation()
			held.queue_redraw()
			var drain := _objective(VIGIL, Vector2(270, 0)) as WardVigilObjective
			drain.set("_inside", false)
			drain.set("_held", drain.vigil_seconds * 0.45)
			drain.set("_lapse", drain.lapse_grace + 0.3)
			drain.update_presentation()
			drain.queue_redraw()
			_panel_notes = {"left": "holding at 62 percent with real player inside radius190", "right": "45 percent and outside beyond grace; physical draining braces"}
		"wager":
			var paid := _objective(WAGER, Vector2(-270, 0)) as WagerShrineObjective
			paid.set("_player", _player)
			_place_player(Vector2(-270, 55))
			paid.call("_process", paid.seconds_per_tier * 1.5)
			var spent := _objective(WAGER, Vector2(270, 0)) as WagerShrineObjective
			spent.set("_player", _player)
			_place_player(Vector2(270, 55))
			spent.call("_process", spent.seconds_per_tier + 0.1)
			_place_player(Vector2(-270, 55))
			spent.call("_process", 0.0) # Real step-out settlement, including its actual deterministic roll.
			if int(paid.get("_tier")) != 0 or not bool(spent.get("_finished")):
				_fail("real Wager purchase/settlement staging did not reach intended states")
			paid.update_presentation()
			spent.update_presentation()
			paid.queue_redraw()
			spent.queue_redraw()
			_panel_notes = {"left": "real first tier purchased; halfway toward next dwell; real current odds/cost", "right": "real first-tier purchase then real step-out settlement; actual payout may appear", "paid_followers": paid.get("_spent"), "settled_followers": spent.get("_spent")}
		"wager-refusal":
			_place_player(Vector2(0, 55))
			var wager := _objective(WAGER, Vector2.ZERO) as WagerShrineObjective
			wager.set("_player", _player)
			var cost := WagerShrineObjective.tier_stake(0)
			Global.followers = cost + Global.reconstruction_cost_for(0)
			var before := Global.followers
			wager.call("_process", wager.seconds_per_tier + 0.1)
			wager.update_presentation()
			wager.queue_redraw()
			if Global.followers != before or int(wager.get("_tier")) != -1 or not wager.get("_refused_tier").has(0):
				_fail("Wager did not refuse a payment that consumes the real reconstruction reserve")
			_panel_notes = {"balance": before, "next_cost": cost, "would_remain": before - cost, "actual_reserve_cost": Global.reconstruction_cost_for(before - cost), "charge": Global.followers - before, "source": "real _process -> _try_raise_stake -> reconstruction_survivable refusal"}


func _sync_visuals(node: Node) -> void:
	if node.has_method("_refresh_world_art"):
		node.call("_refresh_world_art")
	if node.has_method("update_presentation"):
		node.call("update_presentation")
	if node.get_script() == WORLD_ART and not bool(node.get("_ground")):
		node.call("_process", 0.06) # Only the helper's player-side draw order; no gameplay clock.
	if node is CanvasItem:
		node.queue_redraw()
	for child: Node in node.get_children():
		_sync_visuals(child)


func _clear_panel() -> void:
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			EnemyIndex.retire_enemy(enemy, &"controlled_preview_cleanup")
	EnemyWorld.clear_world()
	if is_instance_valid(_stage):
		_stage.queue_free()
	await _frames(2)
	if is_instance_valid(_spawner):
		_spawner.set_rite_pressure_active(false) # Reset the frozen director's latched suppression between panels.
	if _renderer != null:
		_renderer.publish()
	BattleText.clear()
	# A real Wager payment notice lives for 3.6 s. Fast frozen panels must not
	# carry its cosmetic card into a later refusal or unrelated Rite image.
	FollowerFeedbackUI.call("_process", 10.0)


func _timed_out() -> void:
	if _finishing:
		return
	_fail("ObjectiveWorldReworkPreview bounded wall-clock timeout")
	await _finish()


func _fail(message: String) -> void:
	_failures += 1
	push_error("ObjectiveWorldReworkPreview: " + message)


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	await _clear_panel()
	if is_instance_valid(_game):
		get_tree().current_scene = null
		_game.queue_free()
		await _frames(3) # Destroy actual Game/render resources before RenderingServer teardown.
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_fail("unexpected profile write or selected real save")
	var info := {"scene": "res://scenes/game.tscn", "segment": 3, "world_seed": WORLD_SEED, "presentation": "CONTROLLED frozen actual Game/HUD; immortal ranged player; staged production states, not a human-played fight, pacing or final acceptance", "viewport": str(PROJECT_VIEWPORT), "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures, "complete": _captures.size() == (PANELS.size() if _only.is_empty() else 1) * 3 and _failures == 0}
	var file := FileAccess.open(ProjectSettings.globalize_path(_out).path_join("capture-info.json" if _only.is_empty() else "capture-info-%s.json" % _only), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
		file.close()
	else:
		_fail("capture manifest could not be written")
	Engine.time_scale = 1.0
	print("ObjectiveWorldReworkPreview COMPLETE: captures=%d failures=%d save_writes=%d" % [_captures.size(), _failures, SaveManager.debug_save_writes - _save_writes_before])
	get_tree().quit(1 if _failures else 0)
