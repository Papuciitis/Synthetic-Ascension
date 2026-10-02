extends Node
## Renders the HUD's overlays, tooltips, notices and story cards to PNGs over
## a live district (needs a display, not --headless): the item, augment and
## Threat tooltips, the objective stack, a tutorial tip, the Rite reveal, the
## evacuation warning, the follower notice, the set and pair notices, a
## first-encounter callout on a real enemy, a tutorial record, the Segment I
## chapter cards and every opening-card style. `lifted` opens the Exchange,
## the Ascension tree and Gear & Stash and fires a follower notice over each,
## without the game. `notices` prints the set and pair cards' alpha over real
## time; `encounter` shoots only the first-encounter callout. A throwaway
## attempt with no current save, autosave off, every archetype pre-discovered
## so no live recognition card interrupts the shots.
## Run: <godot> --path . res://tools/dev/OverlaysShotProbe.tscn -- --out=/abs/dir [--only=hud|cards|lifted|notices|encounter] [--reduced]

const HUB_SHOP := "res://ui/screens/HubShop.tscn"
const ASCENSION := "res://ui/screens/AscensionScreen.tscn"
const STASH := "res://ui/screens/InventoryStash.tscn"
const TUTORIAL_CARD := "res://ui/screens/TutorialCardOverlay.tscn"
const NARRATIVE := "res://ui/screens/Segment1NarrativeOverlay.tscn"
const OPENING := "res://ui/screens/opening/OpeningPresentation.tscn"
const FIRST_ENCOUNTER := "res://ui/overlays/FirstEncounterOverlay.tscn"

var _out := "/tmp"
var _only := ""
var _reduced := false
var _is_worker := false


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
			push_error("OverlaysShotProbe timed out")
			get_tree().quit(1)
		)
		_run_game.call_deferred()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--reduced":
			_reduced = true
	DirAccess.make_dir_recursive_absolute(_out)
	if _reduced and SettingsManager != null and SettingsManager.has_method("set_value"):
		SettingsManager.call("set_value", &"accessibility", &"reduced_motion", true, false)
	SaveManager.current_save = null
	if _only == "lifted":
		await _lifted()
		print("OverlaysShotProbe: done -> ", _out)
		get_tree().quit(0)
		return
	# Must outlive goto_game()'s scene change.
	var worker := Node.new()
	worker.name = "OverlaysShotWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_out", _out)
	worker.set("_only", _only)
	worker.set("_reduced", _reduced)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, file_name])
	print("shot ", file_name, " ", image.get_size())


## Warps the cursor (logical coordinates) and feeds a motion event so hover
## signals fire as they would under a real mouse.
func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	var window_pos: Vector2 = get_viewport().get_final_transform() * at
	motion.position = window_pos
	motion.global_position = window_pos
	Input.parse_input_event(motion)


func _hover(control: Control) -> void:
	if control != null:
		_move_mouse(control.get_global_rect().get_center())


# ------------------------------------------------------------------ the game

func _run_game() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = 424242
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.tip_shown_intro_move = true
	Global.debug_dev_segment = false
	Global.debug_encounter_beats = false
	Global.debug_player_god_mode = true
	Global.mortal_name = "Ilse Varn"
	Global.debug_force_enemy_introductions = false
	Global.debug_disable_autosave = true
	# Every archetype already known, so no live recognition card interrupts.
	for enemy_id in EnemyDossierCatalog.DATA.keys():
		Global.mark_enemy_discovered(StringName(enemy_id))
	Global.goto_game()
	var player: Node2D = null
	for _frame in range(600):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("OverlaysShotProbe: no player")
		get_tree().quit(1)
		return
	await _settle(120)
	_seed_items_and_augments()
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("debug_force_spawn"):
		spawner.call("debug_force_spawn", 14)
	if spawner != null and spawner.has_method("suspend_spawning"):
		spawner.call("suspend_spawning", 9999.0)
	await _settle(90)
	_move_mouse(Vector2(960, 700))
	if _only == "notices":
		await _notices_only()
	if _only == "encounter":
		await _first_encounter()
	if _want("hud"):
		await _hud_shots()
	if _want("cards"):
		await _card_shots()
	print("OverlaysShotProbe: done -> ", _out)
	get_tree().quit(0)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await get_tree().process_frame
		if get_tree().paused:
			_unblock(get_tree().root)
			get_tree().paused = false


func _unblock(node: Node) -> void:
	var node_script := node.get_script() as Script
	if node_script != null:
		var path := node_script.resource_path
		if path.ends_with("TutorialModalController.gd"):
			node.queue_free()
			return
		if path.ends_with("TutorialCardOverlay.gd") and node.has_method("_dismiss"):
			node.call("_dismiss")
	if node.has_method("open_choose_3"):
		node.queue_free()
		return
	for child in node.get_children():
		_unblock(child)


func _seed_items_and_augments() -> void:
	var ids: Array = Global.item_db.keys()
	ids.sort()
	var worn := 0
	for id in ids:
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null or String(id) == "item_test":
			continue
		var slot := int(data.equip_slot)
		if slot < 0 or slot >= Inventory.SLOT_COUNT or not Global.run_inventory.is_slot_empty(slot):
			continue
		var polarity := ItemInstance.Polarity.NEG if worn == 3 else ItemInstance.Polarity.POS
		var inst := ItemInstance.from_roll(data, 2 + worn % 3, polarity, -0.35 if worn == 3 else 0.3, false)
		Global.run_inventory.set_item(slot, inst, {"player_driven": false})
		worn += 1
		if worn >= 6:
			break
	var aug_ids: Array = Global.augment_db.keys()
	aug_ids.sort()
	Global.init_permanent_augments()
	for i in range(mini(2, aug_ids.size())):
		Global.add_owned_augment(aug_ids[i + 1])
		Global.set_permanent_augment(i, aug_ids[i + 1])


func _hud() -> Control:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("UI/HUD") as Control if scene != null else null


func _first_with_meta(root: Node, key: String) -> Control:
	if root == null:
		return null
	for node in root.find_children("*", "Control", true, false):
		if not node.has_meta(key):
			continue
		var value: Variant = node.get_meta(key)
		if value != null and not (value is String and String(value) == ""):
			return node as Control
	return null


func _hud_shots() -> void:
	var hud := _hud()
	if hud == null:
		push_error("OverlaysShotProbe: no HUD")
		return
	await _wait(0.6)
	await _shot("hud_base")

	var bar := hud.get_node_or_null("TopLeft/Margin/VBox/BodyRow/InventoryBar")
	var item_slot := _first_with_meta(bar, "item_instance")
	if item_slot != null:
		_hover(item_slot)
		await _wait(0.4)
		await _shot("hud_item_tooltip")
	# Management mode: the dossier form beside the open bag.
	var bag_ctl := hud.get_node_or_null("BagController")
	if bag_ctl != null and item_slot != null:
		bag_ctl.call("toggle_bag_open")
		await _wait(0.5)
		_hover(item_slot)
		await _wait(0.4)
		await _shot("hud_item_dossier")
		_move_mouse(Vector2(960, 700))
		if bool(bag_ctl.call("is_management_mode")):
			bag_ctl.call("toggle_bag_open")
		await _wait(0.4)
		get_tree().paused = false
	# The augment and Threat hovers are driven through their controllers: a
	# warped cursor does not always reach a row whose children take the hover.
	var aug_ctl := hud.get_node_or_null("AugmentTooltipController")
	var aug_panel := hud.get_node_or_null("TopLeft/Margin/VBox/BodyRow/AugmentsPanel")
	var aug_slot := _first_with_meta(aug_panel, "augment_data")
	if aug_ctl != null and aug_slot != null:
		_hover(aug_slot)
		aug_ctl.set_process(false)
		aug_ctl.call("_show_tooltip", aug_slot.get_meta("augment_data"))
		await _wait(0.1)
		aug_ctl.call("_position_tooltip_near_mouse")
		await _wait(0.25)
		await _shot("hud_augment_tooltip")
		aug_ctl.call("_hide_tooltip")
		aug_ctl.set_process(true)
	var threat_ctl := hud.get_node_or_null("ThreatController")
	var threat_row := hud.get_node_or_null("TopLeft/Margin/VBox/ThreatRow") as Control
	if threat_ctl != null and threat_row != null:
		_hover(threat_row)
		threat_ctl.call("_on_hover_entered")
		await _wait(0.3)
		await _shot("hud_threat_tooltip")
		threat_ctl.call("_on_hover_exited")
	_move_mouse(Vector2(960, 700))
	await _wait(0.2)

	var checklist := hud.get_node_or_null("GateChecklistController")
	if checklist != null and checklist.has_method("set_details_requested"):
		checklist.call("set_details_requested", true)
	var objective := hud.get_node_or_null("ObjectiveController")
	if objective != null:
		objective.call("_on_secondary_objective_changed", "SECONDARY: UNSTABLE SHRINE", "Remain nearby while the vessel stabilises.")
	var tips := hud.get_node_or_null("TutorialTipController")
	if tips != null:
		tips.call("enqueue_tip", "Hold Shift to read the Exit Rite in full.", 5.0)
	await _wait(0.4)
	await _shot("hud_context_and_tip")
	if checklist != null and checklist.has_method("set_details_requested"):
		checklist.call("set_details_requested", false)

	var gate := hud.get_node_or_null("GateOverlayController")
	if gate != null:
		gate.call("_show_gate_ready_popup")
		await _wait(0.08)
		await _shot("rite_exposed_early")
		await _wait(0.5)
		await _shot("rite_exposed")
	await _wait(2.4)

	var evac := hud.get_node_or_null("EvacOverlayController")
	var evac_overlay := hud.get_node_or_null("EvacOverlay")
	if evac != null and evac_overlay != null:
		evac.set_process(false)
		var warning := evac_overlay.get_node("EvacWarning") as Label
		warning.visible = true
		warning.text = "GATE UNSEALED  •  EVAC IN 23s"
		var vignette := evac_overlay.get_node("Vignette") as ColorRect
		if vignette.material is ShaderMaterial:
			(vignette.material as ShaderMaterial).set_shader_parameter("vignette_strength", 0.34)
		evac.call("set_safeguard_prompt", true, 2)
		await _wait(0.2)
		await _shot("evac")
		warning.visible = false
		evac.call("set_safeguard_prompt", false, 0)
		if vignette.material is ShaderMaterial:
			(vignette.material as ShaderMaterial).set_shader_parameter("vignette_strength", 0.18)
		evac.set_process(true)

	var feedback := get_tree().root.get_node_or_null("FollowerFeedbackUI")
	if feedback != null:
		feedback.call("_on_transaction", 6000, -28, 5972, &"enemy_drain", {}, true, false)
		await _wait(0.06)
		await _shot("follower_toast_early")
		await _wait(0.5)
		await _shot("follower_toast")

	var sets := hud.get_node_or_null("SetBreakpointNotifier")
	var set_ids: Array = Global.set_db.keys() if Global.set_db != null else []
	set_ids.sort()
	if sets != null and not set_ids.is_empty():
		sets.call("debug_force_notification", StringName(set_ids[0]), 2, true)
	var pairs := hud.get_node_or_null("ManifestationPairNotifier")
	if pairs != null:
		pairs.call("debug_force_notification", {"name": "Litany Engine", "nouns": [&"momentum", &"cadence"]}, true)
	await _wait(0.07)
	await _shot("notices_early")
	await _wait(0.45)
	await _shot("notices")
	await _wait(3.6)

	await _first_encounter()


func _notices_only() -> void:
	var hud := _hud()
	var sets := hud.get_node_or_null("SetBreakpointNotifier")
	var pairs := hud.get_node_or_null("ManifestationPairNotifier")
	var set_ids: Array = Global.set_db.keys()
	set_ids.sort()
	sets.call("debug_force_notification", StringName(set_ids[0]), 2, true)
	pairs.call("debug_force_notification", {"name": "Litany Engine", "nouns": [&"momentum", &"cadence"]}, true)
	var t0 := Time.get_ticks_msec()
	for _i in range(30):
		await _wait(0.1)
		var sp := sets.get_node_or_null("SetBreakpointPanel") as Control
		var pp := pairs.get_node_or_null("ManifestationPairPanel") as Control
		print("notice t=%d ts=%.3f set=%.2f/%s pair=%.2f/%s" % [Time.get_ticks_msec() - t0, Engine.time_scale, sp.modulate.a, sp.visible, pp.modulate.a, pp.visible])


func _nearest_enemy() -> Node2D:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.is_visible_in_tree() or enemy.get("spec") == null:
			continue
		var d := enemy.global_position.distance_to(player.global_position) if player != null else 0.0
		if d < best_d:
			best_d = d
			best = enemy
	return best


## The card's picture the way TutorialModalController takes it: the spec's
## portrait, else the one frame the sprite shows.
func _portrait_of(enemy: Node2D) -> Texture2D:
	if enemy == null:
		return null
	var spec := enemy.get("spec") as EnemySpec
	var texture: Texture2D = spec.portrait_texture() if spec != null else null
	if texture != null:
		return texture
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return null
	if not sprite.region_enabled:
		return sprite.texture
	var region := AtlasTexture.new()
	region.atlas = sprite.texture
	region.region = sprite.region_rect
	return region


func _first_encounter() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		push_warning("OverlaysShotProbe: no enemy for the first-encounter card")
		return
	var spec: EnemySpec = enemy.get("spec") as EnemySpec
	var entry := EnemyDossierCatalog.get_entry(spec.id)
	if entry.is_empty():
		entry = {"name": spec.display_name, "role": "Melee pursuer", "counter": "Keep moving and divide the group."}
	var overlay := (load(FIRST_ENCOUNTER) as PackedScene).instantiate()
	get_tree().current_scene.add_child(overlay)
	entry = entry.duplicate()
	entry["name"] = String(entry.get("name", spec.display_name))
	overlay.call("present", entry, enemy, _portrait_of(enemy), EnemyDossierCatalog.ratings(spec))

	await _wait(0.06)
	await _shot("first_encounter_early")
	await _wait(0.5)
	await _shot("first_encounter")
	await _wait(6.0)
	if is_instance_valid(overlay):
		overlay.queue_free()
	get_tree().paused = false


func _card_shots() -> void:
	var host := get_tree().current_scene
	var enemy := _nearest_enemy()
	var portrait := _portrait_of(enemy)
	var card := (load(TUTORIAL_CARD) as PackedScene).instantiate()
	host.add_child(card)
	get_tree().paused = true
	card.call("present", "THE EXIT RITE", "Every district hides an Exit Rite. Raise the Resonance by completing objectives, find the Rite, and rewrite it before the institution closes the city around you.", "PATTERN RECORD", null, -1)
	await _wait(0.08)
	await _shot("tutorial_card_early")
	await _wait(0.5)
	await _shot("tutorial_card_typing")
	card.call("_complete_reveal")
	await _wait(0.2)
	await _shot("tutorial_card")
	card.call("_dismiss")
	card.queue_free()
	if portrait != null:
		var dossier := (load(TUTORIAL_CARD) as PackedScene).instantiate()
		host.add_child(dossier)
		dossier.call("present", "CONTAINMENT OFFICER", "You cannot outrun containment.\n\nRole: Melee pursuer\nCounter: Keep moving and divide the group.", "FIRST ENCOUNTER", portrait, -1)
		dossier.call("_complete_reveal")
		await _wait(0.6)
		await _shot("tutorial_card_portrait")
		dossier.call("_dismiss")
		dossier.queue_free()
	get_tree().paused = false

	var narrative := (load(NARRATIVE) as PackedScene).instantiate()
	host.add_child(narrative)
	narrative.call("present_opening", "Ilse Varn")
	await _wait(0.08)
	await _shot("narrative_early")
	await _wait(0.6)
	await _shot("narrative_opening")
	narrative.call("_dismiss")
	narrative.call("present_completion", "Ilse Varn")
	await _wait(0.6)
	await _shot("narrative_completion")
	narrative.call("_dismiss")
	narrative.queue_free()

	var opening := (load(OPENING) as PackedScene).instantiate()
	host.add_child(opening)
	await get_tree().process_frame
	var cards: Array = [
		["opening_historical", 0, OpeningSequenceData.HISTORICAL_EYEBROW, "A PROHIBITED EXPERIMENT", OpeningSequenceData.historical_body("Ilse Varn"), []],
		["opening_dialogue", 1, OpeningSequenceData.BREN_ROLE, "BREN", OpeningSequenceData.BREN_OPENING, []],
		["opening_choices", 1, OpeningSequenceData.BREN_ROLE, "BREN", OpeningSequenceData.BREN_OPENING, OpeningSequenceData.RESPONSE_CHOICES],
		["opening_institutional", 2, "FACILITY ANNOUNCEMENT", OpeningSequenceData.DETECTION_TITLE, OpeningSequenceData.DETECTION_BODY, []],
		["opening_synthetic", 3, "SYNTHETIC RESPONSE", OpeningSequenceData.SYNTHESIS_TITLE, OpeningSequenceData.SYNTHESIS_BODY, []],
		["opening_follower", 4, "HUMAN COMMITMENT", OpeningSequenceData.FOLLOWER_TITLE, OpeningSequenceData.FOLLOWER_BODY, []],
	]
	for spec: Array in cards:
		opening.call("present_card", int(spec[1]), String(spec[2]), String(spec[3]), String(spec[4]), spec[5] as Array, "Continue")
		if String(spec[0]) == "opening_dialogue":
			await _wait(0.07)
			await _shot("opening_dialogue_early")
		await _wait(0.4)
		opening.call("advance")
		await _wait(0.5)
		await _shot(String(spec[0]))
		if (spec[5] as Array).is_empty():
			opening.call("advance")
		else:
			opening.call("_select_choice", 0)
		await _wait(0.2)
	opening.call("show_prompt", OpeningSequenceData.INTERACT_PROMPT)
	await _wait(0.3)
	await _shot("opening_prompt")
	opening.call("hide_prompt")
	opening.queue_free()


# ------------------------------------------------------------------ lifted

func _lifted() -> void:
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.transaction_followers(6000 - Global.followers, &"dev_grant", {}, false, false)
	var feedback := get_tree().root.get_node_or_null("FollowerFeedbackUI")
	var shop: Control = (load(HUB_SHOP) as PackedScene).instantiate()
	add_child(shop)
	await _wait(1.6)
	if feedback != null:
		feedback.call("_on_transaction", 6000, -28, 5972, &"trade", {}, true, false)
	await _wait(0.6)
	await _shot("lifted_exchange")
	await _wait(3.4)
	shop.queue_free()
	await _wait(0.2)

	var tree_screen := (load(ASCENSION) as PackedScene).instantiate()
	add_child(tree_screen)
	if tree_screen.has_method("open"):
		tree_screen.call("open", false)
	await _wait(1.8)
	if feedback != null:
		feedback.call("_on_transaction", 6000, -600, 5400, &"ascension_purchase", {}, true, false)
	await _wait(0.6)
	await _shot("lifted_ascension")
	await _wait(3.4)
	tree_screen.queue_free()
	await _wait(0.2)

	var stash := (load(STASH) as PackedScene).instantiate()
	add_child(stash)
	await _wait(1.4)
	if feedback != null:
		feedback.call("_on_transaction", 5400, 12, 5412, &"legacy", {}, true, false)
	await _wait(0.6)
	await _shot("lifted_stash")
	stash.queue_free()
	await _wait(0.2)
	if feedback != null:
		feedback.call("_on_transaction", 5412, -3, 5409, &"vendor_refresh", {}, true, false)
	await _wait(0.6)
	await _shot("lifted_none")
