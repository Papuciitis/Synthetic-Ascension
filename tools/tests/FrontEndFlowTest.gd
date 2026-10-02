extends SceneTree
## The front end's behaviour beyond its looks: where New Run and Archives land,
## that a card's first click selects and only a second opens, that Erase asks
## before it deletes, that tabs keep their paint while focus moves on, and that
## the backdrop answers moods. Runs on a scratch save folder; the player's real
## slots are never read or written.

const SCRATCH_DIR := "user://frontend_flow_test_saves/"

var _passes := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	var real_dir: String = sm.get("save_dir")
	sm.set("save_dir", SCRATCH_DIR)
	for slot in range(1, 4):
		sm.call("delete_slot", slot)

	await _check_menu_items()
	await _check_intents(sm)
	await _check_card_clicks(sm)
	await _check_erase_asks(sm)
	await _check_backdrop()
	await _check_new_chronicle()

	for slot in range(1, 4):
		sm.call("delete_slot", slot)
	sm.set("save_dir", real_dir)
	print("FrontEndFlowTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _check_menu_items() -> void:
	var host := Control.new()
	host.theme = load("res://ui/theme/ArcaneMenuTheme.tres")
	root.add_child(host)
	var item_script := load("res://ui/components/ArcaneMenuItem.gd") as GDScript
	var a := item_script.new() as Button
	a.text = "ALPHA"
	var b := item_script.new() as Button
	b.text = "BETA"
	b.set("stroke_on_focus", false)
	var box := VBoxContainer.new()
	host.add_child(box)
	box.add_child(a)
	box.add_child(b)
	await process_frame
	_check(a.text == "ALPHA", "a menu entry keeps its caption in Button.text")
	_check(a.custom_minimum_size.x > 100.0, "a menu entry sizes itself to its caption and stroke")
	a.grab_focus()
	await process_frame
	_check(bool(a.call("is_selected")), "focus selects a menu entry")
	b.set("active", true)
	a.grab_focus()
	await process_frame
	_check(bool(b.get("active")) and bool(b.get("_stroked")), "an active tab keeps its stroke while focus is elsewhere")
	b.grab_focus()
	await process_frame
	_check(not bool(a.get("_stroked")), "leaving an entry wipes its stroke away")
	# Reduced motion: the stroke is simply there or not, at once (no tween).
	var settings := root.get_node("SettingsManager")
	var was_reduced: bool = bool(settings.call("get_value", &"accessibility", &"reduced_motion", false))
	settings.call("set_value", &"accessibility", &"reduced_motion", true, false)
	a.grab_focus()
	_check(is_equal_approx(float(a.get("_reveal")), 1.0), "under reduced motion the stroke appears at once")
	b.grab_focus()
	_check(is_equal_approx(float(a.get("_reveal")), 0.0), "and leaves at once")
	settings.call("set_value", &"accessibility", &"reduced_motion", was_reduced, false)
	host.queue_free()
	await process_frame


func _make_save(sm: Node, slot: int, name: String, updated: int) -> void:
	var save: Resource = sm.call("create_slot", slot, name)
	save.set("mortal_name", name)
	sm.call("save_slot", save)
	# save_slot stamps the wall clock; pin the order the test needs.
	save.set("updated_unix", updated)
	ResourceSaver.save(save, String(sm.call("_slot_path", slot)))


func _open_archives(intent: StringName) -> Control:
	var script := load("res://ui/screens/SaveSelect.gd") as GDScript
	script.set("open_intent", intent)
	var screen := (load("res://ui/screens/SaveSelect.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	await process_frame
	return screen


func _check_intents(sm: Node) -> void:
	_make_save(sm, 1, "Older", 1000)
	_make_save(sm, 3, "Newer", 2000)
	var archives := await _open_archives(&"browse")
	_check(int(archives.get("selected_slot")) == 3, "Archives open on the most recently saved chronicle")
	_check((archives.find_child("Title", true, false) as Label).text == "ARCHIVES", "browsing is titled Archives")
	archives.queue_free()
	await process_frame
	var fresh := await _open_archives(&"new")
	_check(int(fresh.get("selected_slot")) == 2, "New Run opens on the first free slot")
	_check((fresh.find_child("Title", true, false) as Label).text == "NEW RUN", "New Run is titled New Run")
	var script := load("res://ui/screens/SaveSelect.gd") as GDScript
	_check(StringName(script.get("open_intent")) == &"browse", "the intent is read once and reset")
	fresh.queue_free()
	await process_frame


func _click(card: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = card.get_global_rect().get_center()
	event.position = card.size * 0.5
	card.call("_gui_input", event)


func _check_card_clicks(_sm: Node) -> void:
	var archives := await _open_archives(&"browse")
	var opened := [0]
	var card := archives.call("_card", 1) as Control
	card.connect("pressed", func() -> void: opened[0] += 1)
	# The selecting click: focus arrives in the same frame as the press.
	card.grab_focus()
	_click(card, true)
	_click(card, false)
	_check(int(archives.get("selected_slot")) == 1, "the first click selects the card")
	_check(opened[0] == 0, "the first click does not open the chronicle")
	await process_frame
	_click(card, true)
	_click(card, false)
	_check(opened[0] == 1, "a second click on the selected card opens it")
	archives.queue_free()
	await process_frame


func _check_erase_asks(sm: Node) -> void:
	var archives := await _open_archives(&"browse")
	archives.call("_request_delete", 1)
	await process_frame
	var dialog := archives.find_child("EraseDialog", true, false) as Control
	_check(dialog != null and dialog.visible, "Erase opens a confirmation first")
	_check(sm.call("load_slot", 1) != null, "nothing is erased before the player confirms")
	# Tab / d-pad must not reach the cards behind the veil.
	(archives.call("_card", 2) as Control).grab_focus()
	await process_frame
	await process_frame
	var owner := archives.get_viewport().gui_get_focus_owner()
	_check(owner != null and dialog.is_ancestor_of(owner), "focus that escapes an open dialog is brought back")
	_check(int(archives.get("selected_slot")) != 2, "a card behind an open dialog cannot take the selection")
	dialog.call("cancel")
	await process_frame
	_check(sm.call("load_slot", 1) != null, "Keep leaves the chronicle where it was")
	archives.call("_request_delete", 1)
	await process_frame
	(dialog.find_child("Confirm", true, false) as Button).pressed.emit()
	await process_frame
	_check(sm.call("load_slot", 1) == null, "confirming Erase deletes the slot")
	var rename := archives.find_child("RenameDialog", true, false) as Control
	archives.call("_on_rename_pressed", 3)
	await process_frame
	_check(rename != null and rename.visible, "Rename asks for the new name")
	rename.emit_signal("confirmed", "Renamed Penitent")
	await process_frame
	var renamed: Resource = sm.call("load_slot", 3)
	_check(renamed != null and String(renamed.get("mortal_name")) == "Renamed Penitent", "a confirmed rename is saved")
	_check(renamed != null and int(renamed.get("updated_unix")) == 2000, "a rename does not make the chronicle the one Continue resumes")
	archives.queue_free()
	await process_frame


func _check_backdrop() -> void:
	var backdrop_script := load("res://ui/widgets/ArcaneBackdrop.gd") as GDScript
	for profile in [&"threshold", &"vigil"]:
		var backdrop := backdrop_script.new() as Control
		backdrop.set("profile", profile)
		backdrop.size = Vector2(1920, 1080)
		root.add_child(backdrop)
		await process_frame
		var plate := backdrop.find_child("Plate", true, false) as TextureRect
		_check(plate != null and plate.texture != null, "%s backdrop loads its painting" % profile)
		backdrop.call("set_mood", &"dusk")
		_check(StringName(backdrop.get("mood")) == &"dusk", "%s backdrop takes a mood" % profile)
		backdrop.call("set_mood", &"no_such_mood")
		_check(StringName(backdrop.get("mood")) == &"calm", "an unknown mood falls back to calm")
		backdrop.queue_free()
		await process_frame


func _check_new_chronicle() -> void:
	var global := root.get_node("Global")
	var was_race := String(global.get("selected_race_id"))
	var was_style := String(global.get("selected_style_id"))
	var was_name := String(global.get("mortal_name"))
	var screen := (load("res://ui/screens/base.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	await process_frame
	var races := screen.find_child("RacesGrid", true, false) as Control
	var styles := screen.find_child("StylesGrid", true, false) as Control
	_check(races != null and races.get_child_count() == (global.get("race_db") as Dictionary).size(), "New Chronicle offers every race")
	_check(styles != null and styles.get_child_count() == (global.get("style_db") as Dictionary).size(), "and every path")
	var elf := screen.find_child("Race_elf", true, false) as BaseButton
	if elf != null:
		elf.emit_signal("pressed")
		await process_frame
		_check(String(global.get("selected_race_id")) == "elf" and elf.button_pressed, "choosing a race tile commits it")
	var name_edit := screen.find_child("MortalName", true, false) as LineEdit
	var start := screen.find_child("StartRun", true, false) as BaseButton
	name_edit.text = ""
	name_edit.text_changed.emit("")
	_check(start.disabled, "the run cannot begin without a mortal name")
	name_edit.text = "Vey"
	name_edit.text_changed.emit("Vey")
	_check(not start.disabled, "a named vessel may begin")
	screen.queue_free()
	await process_frame
	global.set("selected_race_id", was_race)
	global.set("selected_style_id", was_style)
	global.set("mortal_name", was_name)
