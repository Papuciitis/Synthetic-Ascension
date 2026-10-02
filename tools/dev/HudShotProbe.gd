extends Node
## Renders the combat HUD over a real run (needs a display, not --headless):
## worn gear, a carried bag, equipped augments, three ability faces (one
## ready, one cooling, one just come ready), a hurt health bar caught mid
## damage trail, a boss bar, and management mode with each Run Sheet page.
## A throwaway attempt with no current save, so nothing is written to the
## player's slots; the player is invulnerable and the spawner is held after
## one wave so the shots stay comparable.
##   <godot> --path . res://tools/dev/HudShotProbe.tscn -- --out=/abs/dir [--segment=2] [--seed=n] [--dev] [--only=combat,hurt,boss,manage] [--reduced]

var _out := "/tmp"
var _segment := 2
var _seed := 424242
var _dev := false
var _only := ""
var _reduced := false
var _is_worker := false


class FakeAbility:
	extends Node
	signal active_cd_changed(time_left: float, max_cd: float)

	var hud_key_text: String = "R"
	var hud_title_text: String = "Fixture Rite"
	var hud_priority: int = 50
	var hud_icon: Texture2D = null
	var cooldown_max: float = 8.0
	var cooldown_left: float = 0.0
	var combat_text: String = ""

	func _process(delta: float) -> void:
		if cooldown_left <= 0.0:
			return
		cooldown_left = maxf(0.0, cooldown_left - delta)
		active_cd_changed.emit(cooldown_left, cooldown_max)

	func start(seconds: float) -> void:
		cooldown_left = seconds
		active_cd_changed.emit(cooldown_left, cooldown_max)

	func get_active_state() -> Dictionary:
		var is_ready := cooldown_left <= 0.05
		return {
			"ready": is_ready,
			"cooldown_left": cooldown_left,
			"cooldown_max": cooldown_max,
			"status_text": "READY" if is_ready else "%.1f" % cooldown_left,
			"combat_text": combat_text,
		}


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
			push_error("HudShotProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--segment="):
			_segment = int(arg.trim_prefix("--segment="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--dev":
			_dev = true
		elif arg == "--reduced":
			_reduced = true
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1784, 1004))
	# Must outlive goto_game()'s scene change.
	var worker := Node.new()
	worker.name = "HudShotWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	for key in ["_out", "_segment", "_seed", "_dev", "_only", "_reduced"]:
		worker.set(key, get(key))
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _want(shot_name: String) -> bool:
	return _only == "" or shot_name in _only.split(",")


## Wall-clock waits, frame by frame: a screenshot can stall one frame for
## seconds, and a timer would spend that whole stall at once.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	await get_tree().process_frame
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, shot_name]
	image.save_png(path)
	print("HudShotProbe -> ", path, " ", image.get_size())


func _run() -> void:
	if _reduced and SettingsManager != null and SettingsManager.has_method("set_value"):
		SettingsManager.call("set_value", &"accessibility", &"reduced_motion", true, false)
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.attempt_segment = _segment
	Global.attempt_world_seed = _seed
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.tip_shown_intro_move = true
	Global.debug_dev_segment = _dev
	Global.debug_encounter_beats = false
	Global.debug_player_god_mode = true
	Global.followers = 1240
	_seed_augments()
	_seed_items()
	Global.goto_game()
	var player: Node2D = null
	for _i in range(900):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("HudShotProbe: no player")
		get_tree().quit(1)
		return
	await _settle(120)
	var hud := _find_hud()
	if hud == null:
		push_error("HudShotProbe: no HUD")
		get_tree().quit(1)
		return
	if hud.has_method("set_followers"):
		hud.call("set_followers", Global.followers)
	var abilities := _seed_abilities(player)
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("debug_force_spawn"):
		spawner.call("debug_force_spawn", 18)
	await _settle(40)
	if spawner != null and spawner.has_method("suspend_spawning"):
		spawner.call("suspend_spawning", 9999.0)
	(abilities["q"] as FakeAbility).start(5.2)
	await _settle(30)

	if _want("combat"):
		await _shot("combat")

	if _only.contains("perf"):
		await _perf(hud)
	if _only.contains("breakdown"):
		await _perf_breakdown(hud)

	if _want("hurt"):
		var max_hp := float(player.get("max_hp"))
		player.set("hp", max_hp * 0.78)
		player.emit_signal("hp_changed", float(player.get("hp")), max_hp)
		await _wait(0.6)
		player.set("hp", max_hp * 0.24)
		player.emit_signal("hp_changed", float(player.get("hp")), max_hp)
		await _wait(0.12)
		await _shot("hurt_trail")
		await _wait(1.4)
		await _shot("hurt_settled")
		player.set("hp", max_hp)
		player.emit_signal("hp_changed", max_hp, max_hp)
		await _wait(0.3)

	if _want("seal"):
		var max_hp2 := float(player.get("max_hp"))
		player.set("hp", max_hp2 * 0.62)
		player.emit_signal("hp_changed", float(player.get("hp")), max_hp2)
		RunEvents.healing_lock_changed.emit(45.0, &"cursed_vault")
		await _wait(0.4)
		await _shot("hp_sealed")
		RunEvents.healing_lock_changed.emit(0.0, &"cursed_vault")
		player.set("hp", max_hp2)
		player.emit_signal("hp_changed", max_hp2, max_hp2)
		await _wait(0.2)

	if _want("ready"):
		(abilities["v"] as FakeAbility).start(0.5)
		await _wait(0.62)
		await _shot("ability_ready_flare")
		await _wait(0.8)

	if _want("boss"):
		var bar := hud.get_node_or_null("BossBarHUD")
		if bar != null and bar.has_method("show_boss"):
			bar.call("show_boss", "The Warden of Ash", null, 3400.0, 4800.0)
			await _wait(0.4)
			await _shot("boss")
			bar.call("update_hp", 2100.0, 4800.0)
			await _wait(0.1)
			await _shot("boss_hit")
			bar.call("hide_boss")

	if _want("manage"):
		var bag_ctl := hud.get_node_or_null("BagController")
		if bag_ctl != null:
			bag_ctl.call("toggle_bag_open")
			# Time and frames both: the sheet refreshes on the HUD's 10 Hz tick.
			await _wait(0.5)
			await _frames(12)
			await _shot("manage_profile")
			var sheet := hud.get_node_or_null("RunSheetHUD")
			if sheet != null and sheet.has_method("select_page"):
				for page in [[1, "manage_sets"], [2, "manage_manifest"], [3, "manage_observe"]]:
					sheet.call("select_page", page[0])
					await _wait(0.25)
					await _shot(String(page[1]))
				sheet.call("select_page", 0)
			var inv_bar := hud.get_node_or_null("TopLeft/Margin/VBox/BodyRow/InventoryBar")
			if inv_bar != null and inv_bar.has_method("get_slot_control"):
				var slot := inv_bar.call("get_slot_control", 1) as Control
				if slot != null:
					_move_mouse(slot.get_global_rect().get_center())
					await _wait(0.4)
					await _shot("manage_hover_slot")
			bag_ctl.call("toggle_bag_open")
			await _wait(0.3)
	print("HudShotProbe: done -> ", _out)
	get_tree().quit(0)


## What the HUD costs a frame: the HUD shown and hidden in alternation over
## a still world (enemies cleared, tree paused), render CPU / GPU medians of
## eight windows each, so a neighbour's load on the machine averages out.
## Prints only.
func _perf(hud: Control) -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node and is_instance_valid(enemy):
			(enemy as Node).queue_free()
	await _frames(10)
	get_tree().paused = true
	var shown_cpu: Array[float] = []
	var shown_gpu: Array[float] = []
	var hidden_cpu: Array[float] = []
	var hidden_gpu: Array[float] = []
	for i in range(16):
		var on := i % 2 == 0
		hud.visible = on
		var r: Array = await _measure(40)
		if on:
			shown_cpu.append(r[0])
			shown_gpu.append(r[1])
		else:
			hidden_cpu.append(r[0])
			hidden_gpu.append(r[1])
	hud.visible = true
	get_tree().paused = false
	print("HudShotProbe perf HUD shown : render cpu %.2f ms  gpu %.2f ms (medians)" % [_median(shown_cpu), _median(shown_gpu)])
	print("HudShotProbe perf HUD hidden: render cpu %.2f ms  gpu %.2f ms (medians)" % [_median(hidden_cpu), _median(hidden_gpu)])


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[floori(sorted.size() * 0.5)] if not sorted.is_empty() else 0.0


func _measure(frames: int = 120) -> Array:
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _frames(20)
	var cpu := 0.0
	var gpu := 0.0
	var proc := 0.0
	for _f in range(frames):
		await RenderingServer.frame_post_draw
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return [cpu / frames, gpu / frames, proc / frames]


## Which part of the HUD the frame pays for: each surface hidden in turn,
## over a still world (enemies cleared, the tree paused), so only the HUD
## moves the numbers.
func _perf_breakdown(hud: Control) -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node and is_instance_valid(enemy):
			(enemy as Node).queue_free()
	await _frames(10)
	get_tree().paused = true
	var parts := ["TopLeft", "BagUI", "ActiveAbilityHud_Q", "ActiveAbilityHud_R", "ActiveAbilityHud_V", "GateOverlay"]
	var base: Array = await _measure()
	print("HudShotProbe breakdown all shown: cpu %.2f gpu %.2f proc %.2f" % base)
	for part in parts:
		var node := hud.get_node_or_null(part) as CanvasItem
		if node == null:
			continue
		var was := node.visible
		node.visible = false
		var r: Array = await _measure()
		node.visible = was
		print("HudShotProbe breakdown without %s: cpu %.2f (%+.2f) gpu %.2f (%+.2f) proc %.2f (%+.2f)" % [part, r[0], r[0] - base[0], r[1], r[1] - base[1], r[2], r[2] - base[2]])
	hud.visible = false
	var hidden: Array = await _measure()
	hud.visible = true
	print("HudShotProbe breakdown HUD hidden: cpu %.2f (%+.2f) gpu %.2f (%+.2f) proc %.2f (%+.2f)" % [hidden[0], hidden[0] - base[0], hidden[1], hidden[1] - base[1], hidden[2], hidden[2] - base[2]])
	# Theme experiments, reverted after.
	var theme := load("res://ui/theme/SyntheticHudTheme.tres") as Theme
	var shadow := theme.get_color(&"font_shadow_color", &"Label")
	theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	var r1: Array = await _measure()
	print("HudShotProbe breakdown no label shadow: cpu %.2f (%+.2f) gpu %.2f (%+.2f)" % [r1[0], r1[0] - base[0], r1[1], r1[1] - base[1]])
	var outline := theme.get_constant(&"outline_size", &"HudFigure")
	theme.set_constant(&"outline_size", &"HudFigure", 0)
	var r2: Array = await _measure()
	print("HudShotProbe breakdown no shadow + no figure outline: cpu %.2f (%+.2f) gpu %.2f (%+.2f)" % [r2[0], r2[0] - base[0], r2[1], r2[1] - base[1]])
	theme.set_color(&"font_shadow_color", &"Label", shadow)
	theme.set_constant(&"outline_size", &"HudFigure", outline)
	get_tree().paused = false


func _find_hud() -> Control:
	for node in get_tree().root.find_children("HUD", "Control", true, false):
		if node.has_method("bind_player"):
			return node as Control
	return null


## Ability faces: R is a set rite at rest, Q a tree active on cooldown, V a
## revelation that comes ready mid-probe. Fixture nodes under the player's
## runners, found the way the HUD finds any effect.
func _seed_abilities(player: Node) -> Dictionary:
	var out := {}
	var icons: Array[Texture2D] = []
	for id in Global.augment_db.keys():
		var a := Global.augment_db[id] as AugmentData
		if a != null and a.icon != null:
			icons.append(a.icon)
		if icons.size() >= 3:
			break
	var specs := [
		["r", &"SetRunner", "R", "Circuit Feedback"],
		["q", &"AscensionRunner", "Q", "Hex Volley"],
		["v", &"AscensionRunner", "V", "Revelation of Ash"],
	]
	for i in range(specs.size()):
		var spec: Array = specs[i]
		var runner := player.get_node_or_null(String(spec[1]))
		if runner == null:
			runner = Node.new()
			runner.name = String(spec[1])
			player.add_child(runner)
		var ability := FakeAbility.new()
		ability.name = "HudProbe_%s" % String(spec[0])
		ability.hud_key_text = String(spec[2])
		ability.hud_title_text = String(spec[3])
		ability.hud_icon = icons[i] if i < icons.size() else null
		if String(spec[0]) == "r":
			ability.combat_text = "CHARGE 3/5"
		runner.add_child(ability)
		out[spec[0]] = ability
	return out


func _seed_augments() -> void:
	var ids: Array = Global.augment_db.keys()
	ids.sort()
	var count := 0
	for id in ids:
		Global.add_owned_augment(id)
		count += 1
		if count >= 6:
			break
	Global.init_permanent_augments()
	if ids.size() >= 3:
		Global.set_permanent_augment(0, ids[1])
		Global.set_permanent_augment(1, ids[4] if ids.size() > 4 else ids[2])


func _seed_items() -> void:
	var by_slot: Dictionary = {}
	var loose: Array = []
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		if String(id) == "item_test":
			continue
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null:
			continue
		var slot := int(data.equip_slot)
		if slot >= 0 and not by_slot.has(slot):
			by_slot[slot] = data
		else:
			loose.append(data)
	var rarity := 0
	for slot in by_slot:
		if int(slot) == 6:
			continue
		var polarity := ItemInstance.Polarity.NEG if rarity == 3 else ItemInstance.Polarity.POS
		var inst := ItemInstance.from_roll(by_slot[slot], (rarity % 4) + 1, polarity, 0.4, false)
		inst.upgrade_meter = 0.35 if rarity == 1 else 0.0
		# Two worn rules, so the Manifestation row has something to count.
		var rules: Array = ManifestationCatalog.all_ids()
		if rarity < 2 and rules.size() > rarity:
			inst.manifestation_id = StringName(rules[rarity])
		Global.run_inventory.set_item(int(slot), inst, {"player_driven": true})
		rarity += 1
	if Global.run_bag != null:
		for i in range(mini(6, loose.size())):
			var stack := ItemInstance.from_roll(loose[i * 3 % loose.size()], (i % 4) + 1, ItemInstance.Polarity.POS if i % 3 != 2 else ItemInstance.Polarity.NEG, 0.5, false)
			Global.run_bag.add_instance(stack)


func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	var window_pos: Vector2 = get_viewport().get_final_transform() * at
	motion.position = window_pos
	motion.global_position = window_pos
	Input.parse_input_event(motion)


func _settle(frames: int) -> void:
	for _f in range(frames):
		await get_tree().process_frame
		if get_tree().paused:
			_unblock()


func _unblock() -> void:
	_strip(get_tree().root)
	get_tree().paused = false


func _strip(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null:
		var path := String(script.resource_path)
		if path.ends_with("TutorialModalController.gd"):
			node.queue_free()
			return
		if path.ends_with("TutorialCardOverlay.gd") and node.has_method("_dismiss"):
			node.call("_dismiss")
	if node.has_method("open_choose_3"):
		node.queue_free()
		return
	var button := node as Button
	if button != null and button.visible and button.text.strip_edges().to_lower() == "continue":
		button.emit_signal("pressed")
	for child in node.get_children():
		_strip(child)
