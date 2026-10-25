extends SceneTree
## Run this external script with --main-pack <Windows EXE> --script <absolute
## script path>. Every res:// load and every autoload then comes from the EXE.
## Catches exported .tres.remap entries being skipped by startup catalogs.
## Stage 1 presses the real Base tiles and Begin, requiring a normal S1 opening.
## Stage 2 explicitly stages an opening-completed S1 through the real Game;
## it tests the evidence-store picker API, not completion of the cinematic,
## walking to the store, or combat. No developer run/world bypass is enabled.
## The launcher must isolate XDG_DATA_HOME/CONFIG_HOME/CACHE_HOME as well.
## Optional native captures: append -- --capture-dir=/absolute/output/path.

const BASE_PATH := "res://ui/screens/base.tscn"
const GAME_PATH := "res://scenes/game.tscn"
const MENU_PATH := "res://ui/screens/MainMenu.tscn"
const EXPECTED_RACES: Array[String] = ["dragonborn", "elf", "human", "warforged"]
const EXPECTED_STYLES: Array[String] = ["magic", "melee", "ranged"]
const EXPECTED_AUGMENTS: Array[String] = [
	"augment_blink_hex", "augment_corruption_engine", "augment_cult_of_personality",
	"augment_doctrine_of_burden", "augment_equilibrium_sigil", "augment_gamblers_rite",
	"augment_inversion_lens", "augment_litany_of_wounds", "augment_lucky_charm",
	"augment_magic_missile", "augment_reflect_shield", "augment_spirit_slash",
	"augment_sprint_servos", "augment_stamina_core", "augment_summon_spiderlings",
	"augment_tesla_aura",
]
const WAIT_MS := 300000

var _passes := 0
var _failures := 0
var _global: Node
var _save_manager: Node
var _capture_dir := ""


func _initialize() -> void:
	Engine.max_fps = 20
	_run.call_deferred()


func _check(ok: bool, message: String) -> bool:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
	return ok


func _expect_ids(property: StringName, expected: Array[String]) -> bool:
	var db: Dictionary = _global.get(property)
	var actual: Array[String] = []
	for key: Variant in db:
		actual.append(String(key))
	actual.sort()
	return _check(actual == expected, "%s contains the authored IDs; actual=%s" % [property, actual])


func _wait_until(condition: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not bool(condition.call()):
		if Time.get_ticks_msec() >= deadline:
			return false
		await process_frame
	return true


func _wait_scene(path: String) -> bool:
	return await _wait_until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == path \
			and (not current_scene.has_method("is_transition_ready") or bool(current_scene.call("is_transition_ready"))) \
			and not bool(_global.call("is_scene_transition_active"))
	)


func _normal_flags() -> bool:
	return not bool(_global.get("debug_dev_segment")) and not bool(_global.get("debug_dev_mode")) \
		and not bool(_global.get("debug_performance_lab")) and not bool(_global.get("debug_player_god_mode"))


func _run() -> void:
	Engine.max_fps = 20
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_global = root.get_node_or_null("Global")
	_save_manager = root.get_node_or_null("SaveManager")
	if not _check(_global != null and _save_manager != null, "packed project autoloads initialize"):
		_finish()
		return
	_save_manager.set("save_dir", "user://packed_frontend_flow_%d/" % Time.get_ticks_usec())
	_save_manager.set("current_save", null)
	_save_manager.set("current_slot", -1)
	_global.set("debug_disable_autosave", true)
	for name: String in ["PerformanceFlightRecorder", "BalanceRecorder"]:
		var recorder := root.get_node_or_null(NodePath(name))
		if recorder != null:
			recorder.set("report_directory", String(_save_manager.get("save_dir")) + name + "/")
	print("PACKED_FRONTEND scratch saves: ", ProjectSettings.globalize_path(String(_save_manager.get("save_dir"))))
	_expect_ids(&"race_db", EXPECTED_RACES)
	_expect_ids(&"style_db", EXPECTED_STYLES)
	_expect_ids(&"augment_db", EXPECTED_AUGMENTS)
	for property: StringName in [&"spell_db", &"weapon_db", &"item_db", &"set_db"]:
		var db: Dictionary = _global.get(property)
		_check(not db.is_empty(), "%s is nonempty (count=%d)" % [property, db.size()])
	var major_db: RefCounted = _global.get("major_choice_db")
	_check(major_db != null and not (major_db.get("defs_by_id") as Dictionary).is_empty(), "major-choice catalog is nonempty")

	# Real profile creation/application, isolated before any save operation.
	var save: Resource = _save_manager.call("create_slot", 1, "Packed regression")
	if not _check(save != null, "a scratch profile can be created"):
		_finish()
		return
	_save_manager.call("set_current", 1, save)
	_check(_normal_flags(), "normal run starts without developer flags")
	var packed := load(BASE_PATH) as PackedScene
	if not _check(packed != null, "packed New Chronicle scene loads"):
		_finish()
		return
	var base := packed.instantiate() as Control
	root.add_child(base)
	current_scene = base
	await process_frame
	var races := base.find_child("RacesGrid", true, false)
	var styles := base.find_child("StylesGrid", true, false)
	_check(races != null and races.get_child_count() == 4, "packed New Chronicle shows four ancestry choices")
	_check(styles != null and styles.get_child_count() == 3, "packed New Chronicle shows three path choices")
	var start := base.find_child("StartRun", true, false) as BaseButton
	var name_edit := base.find_child("MortalName", true, false) as LineEdit
	if not _check(start != null and name_edit != null, "New Chronicle contains naming and Begin controls"):
		_finish()
		return
	name_edit.text = "Packed Vey"
	name_edit.text_changed.emit(name_edit.text)
	_check(not start.disabled, "a named vessel can Begin in the exported game")
	var elf := base.find_child("Race_elf", true, false) as BaseButton
	var magic := base.find_child("Style_magic", true, false) as BaseButton
	_check(elf != null and magic != null, "nondefault Elf and Magic choices exist")
	# The broken EXE ends here with assertions, never dereferencing absent tiles
	# or attempting a developer/default-ID workaround.
	if _failures > 0:
		_finish()
		return
	elf.pressed.emit()
	magic.pressed.emit()
	_check(String(_global.get("selected_race_id")) == "elf" and elf.button_pressed, "real Elf tile commits ancestry")
	_check(String(_global.get("selected_style_id")) == "magic" and magic.button_pressed \
		and String(_global.get("selected_weapon_id")) == "magic", "real Magic tile commits path and starter weapon")
	if _failures > 0:
		_finish()
		return
	if _wants_capture():
		var curtain := base.get_node_or_null("Curtain") as CanvasItem
		var revealed := await _wait_until(func() -> bool:
			if curtain != null and curtain.visible:
				return false
			for column: Node in [races, styles]:
				for tile: CanvasItem in column.get_children():
					if tile.modulate.a < 0.99:
						return false
			return true
		)
		_check(revealed, "New Chronicle finishes revealing its populated choices")
		await _capture("base-populated.png")
	print("PACKED_FRONTEND stage 1: pressing normal Begin")
	start.pressed.emit()
	if not _check(await _wait_scene(GAME_PATH), "normal Begin reaches a ready real Game"):
		_finish()
		return
	_check(bool(_global.get("attempt_active")) and int(_global.get("attempt_segment")) == 1, "Begin creates an active Segment 1 attempt")
	_check(_normal_flags(), "real Game retains normal-run flags")
	_check(String(_global.get("mortal_name")) == "Packed Vey" \
		and String(_global.get("selected_race_id")) == "elf" \
		and String(_global.get("selected_style_id")) == "magic", "Game receives the named Elf/Magic vessel")
	_check(current_scene.get_node_or_null("Level1") != null and current_scene.get_node_or_null("Spawner") != null, "normal authored world and spawner are installed")
	var opening_started := await _wait_until(func() -> bool:
		return get_first_node_in_group(&"opening_sequence_controller") != null
	)
	_check(opening_started and not bool(_global.get("attempt_opening_completed")) \
		and String(_global.get("attempt_opening_mode")) == "full", "a fresh profile enters its full normal opening")
	if _failures > 0:
		_finish()
		return
	await _check_staged_binding()
	_finish()


func _check_staged_binding() -> void:
	# Full opening completion requires interactive dialogue, movement and combat.
	# Leave the witnessed opening through the production transition, then load a
	# separately staged S1. Keep the actual first Binding earned by Begin.
	print("PACKED_FRONTEND stage 2: STAGED opening-completed Segment 1; no cinematic/store traversal claim")
	_global.call("goto_main_menu")
	if not _check(await _wait_scene(MENU_PATH), "normal opening tears down through the real menu transition"):
		return
	_global.set("attempt_opening_completed", true)
	_global.set("attempt_opening_phase", 10)
	_global.set("tip_shown_intro_move", true)
	var story := root.get_node_or_null("StoryDirector")
	if story != null:
		story.set("cards_override", 0)
	_global.call("goto_game")
	if not _check(await _wait_scene(GAME_PATH), "staged real Game loads with its normal world"):
		return
	var game := current_scene
	_check(_normal_flags(), "staged Binding still uses normal Game rather than a developer world")
	_check(bool(_global.get("pending_augment_pick")), "Begin's first Binding remains pending until chosen")
	_check(not paused, "staged world is running before the Binding")
	if _failures > 0:
		return
	# This is the same public Game API invoked by Segment 1's evidence store.
	game.call("present_augment_pick_and_wait")
	var picker_ready := await _wait_until(func() -> bool:
		var picker: CanvasLayer = game.get("augment_select")
		return is_instance_valid(picker) and picker.visible and bool(picker.get("_is_open"))
	)
	if not _check(picker_ready, "the real Game opens its augment picker"):
		return
	var picker: CanvasLayer = game.get("augment_select")
	var cards: Container = picker.get("cards_box")
	var offer: Array = picker.call("current_offer")
	_check(cards != null and cards.get_child_count() == 3 and offer.size() == 3, "the exported first Binding displays three actual offer cards")
	_check(paused and bool(game.get("_augment_pause_owned")), "Game owns the pause while choosing")
	if _failures > 0:
		return
	if _wants_capture():
		var center: CanvasItem = picker.get("center")
		_check(await _wait_until(func() -> bool: return center != null and center.modulate.a >= 0.99), "Binding finishes revealing its three cards")
		await _capture("augment-three-cards.png")
	var card := cards.get_child(0) as BaseButton
	var data: Resource = card.get("data") if card != null else null
	if not _check(card != null and data != null and not card.disabled, "the first offer is a usable real augment card"):
		return
	var chosen_id := String(data.get("id"))
	card.pressed.emit()
	var settled := await _wait_until(func() -> bool:
		return not bool(_global.get("pending_augment_pick")) and not bool(game.get("_augment_pause_owned")) \
			and not bool(game.get("_augment_transition_pending")) and not is_instance_valid(game.get("augment_select"))
	)
	_check(settled, "choosing a card consumes the Binding and closes the real picker")
	var equipped: Array = _global.get("permanent_augment_ids")
	_check(equipped.has(StringName(chosen_id)) and int(_global.call("get_augment_level", StringName(chosen_id))) > 0, "the selected augment is actually equipped and ranked")
	_check(not paused, "closing the Binding restores the previously running world")
	_check(_normal_flags(), "picking an augment does not enable developer bypasses")


func _wants_capture() -> bool:
	return _capture_dir != "" and DisplayServer.get_name() != "headless"


func _capture(filename: String) -> void:
	if not _wants_capture():
		return
	if not _check(_capture_dir.is_absolute_path(), "native capture directory is absolute"):
		return
	var error := DirAccess.make_dir_recursive_absolute(_capture_dir)
	if not _check(error == OK, "native capture directory can be created"):
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _capture_dir.path_join(filename)
	_check(image.save_png(path) == OK, "native viewport capture saved: " + path)


func _finish() -> void:
	# Keep scratch save routing through autoload teardown; restoring a real save
	# path here could redirect a deferred save. Launcher deletes its isolated XDG.
	paused = false
	print("PackedFrontEndFlowTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
