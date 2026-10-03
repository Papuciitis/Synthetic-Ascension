extends Node
## Renders the pop-up windows and the project-wide base theme to PNGs (needs a
## display, not --headless): the Settings reset confirmation and an open option
## list, the Ascension purchase confirmation (plain, Gate, and its Core list),
## a bare ConfirmationDialog / AcceptDialog / tooltip / PopupMenu with no theme
## of their own (they show what gui/theme/custom gives every control), a sheet
## of the stock controls, the developer console, the Imprinter, the loading card
## and the narrative cards. A throwaway attempt with no current save.
## Run: <godot> --path . res://tools/dev/DialogsShotProbe.tscn -- --out=/abs/dir
##        [--only=settings|ascension|generic|controls|console|imprint|cards]

const SETTINGS_SCENE := "res://ui/screens/settings/SettingsScreen.tscn"
const ASCENSION_SCENE := "res://ui/screens/AscensionScreen.tscn"
const CONSOLE_SCENE := "res://ui/widgets/PerformanceOverlay.tscn"
const NARRATIVE_SCENE := "res://ui/screens/Segment1NarrativeOverlay.tscn"
const OPENING_SCENE := "res://ui/screens/opening/OpeningPresentation.tscn"
const SCRIM_SCRIPT := "res://ui/widgets/LoadingScrim.gd"
const IMPRINT_SCRIPT := "res://ui/screens/ImprintScreen.gd"
const BACKDROP := "res://assets/ui/menu/vigil_backdrop.jpg"

var _out := "/tmp"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.transaction_followers(6000 - Global.followers, &"dev_grant", {}, false, false)
	await _wait(0.3)
	if _want("settings"):
		await _settings()
	if _want("ascension"):
		await _ascension()
	if _want("generic"):
		await _generic()
	if _want("controls"):
		await _controls()
	if _want("console"):
		await _console()
	if _want("imprint"):
		await _imprint()
	if _want("cards"):
		await _cards()
	get_tree().quit(0)


func _settings() -> void:
	var bg := _backdrop()
	var screen := (load(SETTINGS_SCENE) as PackedScene).instantiate() as Control
	add_child(screen)
	screen.call("open")
	await _wait(0.4)
	var reset := screen.find_child("ResetTab", true, false) as Button
	if reset != null:
		reset.pressed.emit()
	await _wait(0.45)
	await _shot("settings_reset")
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button:
		# The other choice, hovered, so both button states are on record.
		var other := focus.get_parent().get_child(1 - focus.get_index()) as Control
		_move_mouse(other.global_position + other.size * 0.5)
		await _wait(0.25)
		await _shot("settings_reset_hover")
	_cancel_input()
	await _wait(0.3)
	for dialog in screen.find_children("*", "Window", true, false):
		(dialog as Window).hide()
	screen.call("_set_section", &"video")
	await _wait(0.3)
	var option := _first_of(screen, "OptionButton") as OptionButton
	if option != null:
		option.show_popup()
		await _wait(0.35)
		await _shot("settings_option_list")
		option.get_popup().hide()
	screen.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _ascension() -> void:
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var screen := (load(ASCENSION_SCENE) as PackedScene).instantiate()
	add_child(screen)
	screen.call("open", false)
	await _wait(1.6)
	for id in ["EX01", "EX03", "EX02", "EX04", "EXQ"]:
		Global.ascension_buy(id)
	screen.call("_refresh_all")
	await _wait(3.5)
	screen.call("_on_activated", "EX06")
	await _wait(0.5)
	await _shot("ascension_confirm")
	var dialog: Window = screen.get("_confirm")
	if dialog != null:
		dialog.hide()
	screen.set("_pending_purchase", "")
	screen.call("_on_activated", "G1")
	await _wait(0.5)
	await _shot("ascension_confirm_gate")
	var core := screen.get("_confirm_core") as OptionButton
	if core != null and core.is_visible_in_tree():
		core.show_popup()
		await _wait(0.35)
		await _shot("ascension_core_list")
		core.get_popup().hide()
	if dialog != null:
		dialog.hide()
	screen.set("_pending_purchase", "")
	screen.queue_free()
	bg.queue_free()
	await _wait(0.3)


## Controls with no theme of their own: before gui/theme/custom they wore
## Godot's grey, after it the project theme.
func _generic() -> void:
	var bg := _backdrop()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var confirm := ConfirmationDialog.new()
	confirm.title = "Abandon the attempt?"
	confirm.dialog_text = "The run ends here. Followers already committed stay committed."
	confirm.ok_button_text = "Abandon"
	host.add_child(confirm)
	confirm.popup_centered(Vector2i(560, 0))
	await _wait(0.35)
	await _shot("generic_confirm")
	confirm.hide()
	var accept := AcceptDialog.new()
	accept.title = "Record saved"
	accept.dialog_text = "The chronicle is written to the Archives."
	host.add_child(accept)
	accept.popup_centered(Vector2i(480, 0))
	await _wait(0.35)
	await _shot("generic_accept")
	accept.hide()
	var menu_button := MenuButton.new()
	menu_button.text = "Rites"
	menu_button.position = Vector2(820, 300)
	host.add_child(menu_button)
	var popup := menu_button.get_popup()
	popup.add_item("Kindle the Lamp")
	popup.add_item("Seal the Gate")
	popup.add_separator("Arcana")
	popup.add_check_item("Hold the Ward")
	popup.set_item_checked(popup.item_count - 1, true)
	popup.add_check_item("Let it Burn")
	popup.add_item("Forbidden")
	popup.set_item_disabled(popup.item_count - 1, true)
	await _wait(0.1)
	menu_button.show_popup()
	await _wait(0.2)
	_move_mouse(Vector2(popup.position) + Vector2(40, 62))
	await _wait(0.3)
	await _shot("generic_popup_menu")
	popup.hide()
	var tip := Button.new()
	tip.text = "Hover for the tooltip"
	tip.tooltip_text = "A tooltip in the project theme.\nTwo lines, to show the padding."
	tip.position = Vector2(860, 620)
	host.add_child(tip)
	await _wait(0.1)
	_move_mouse(tip.global_position + tip.size * 0.5)
	await _wait(1.3)
	_move_mouse(tip.global_position + tip.size * 0.5 + Vector2(1, 0))
	await _wait(0.3)
	await _shot("generic_tooltip")
	host.queue_free()
	bg.queue_free()
	_move_mouse(Vector2(10, 10))
	await _wait(0.2)


## The stock controls, untouched: what the base theme makes of each.
func _controls() -> void:
	var bg := _backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 60)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 40)
	margin.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 12)
	columns.add_child(left)
	var title := Label.new()
	title.text = "A plain Label, then the stock controls"
	left.add_child(title)
	var line := LineEdit.new()
	line.placeholder_text = "A LineEdit placeholder"
	left.add_child(line)
	var spin := SpinBox.new()
	spin.value = 28
	left.add_child(spin)
	var option := OptionButton.new()
	for item in ["Windowed", "Borderless", "Fullscreen"]:
		option.add_item(item)
	left.add_child(option)
	var check := CheckBox.new()
	check.text = "A CheckBox"
	check.button_pressed = true
	left.add_child(check)
	var toggle := CheckButton.new()
	toggle.text = "A CheckButton"
	toggle.button_pressed = true
	left.add_child(toggle)
	var slider := HSlider.new()
	slider.value = 60
	left.add_child(slider)
	var progress := ProgressBar.new()
	progress.value = 64
	left.add_child(progress)
	left.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	left.add_child(buttons)
	for text in ["Button", "Another"]:
		var b := Button.new()
		b.text = text
		buttons.add_child(b)
	var disabled := Button.new()
	disabled.text = "Disabled"
	disabled.disabled = true
	buttons.add_child(disabled)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.text = "A RichTextLabel with [b]bold[/b], [i]italics[/i] and [b][i]both[/i][/b]."
	left.add_child(rich)
	var text_edit := TextEdit.new()
	text_edit.text = "A TextEdit.\nSecond line."
	text_edit.custom_minimum_size = Vector2(0, 90)
	left.add_child(text_edit)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 12)
	columns.add_child(right)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 200)
	right.add_child(tabs)
	for tab_name in ["Overview", "Enemies", "Tests"]:
		var page := Label.new()
		page.name = tab_name
		page.text = "The %s page." % tab_name
		tabs.add_child(page)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 150)
	for item in ["First entry", "Second entry", "Third entry", "Fourth entry", "Fifth entry", "Sixth entry"]:
		list.add_item(item)
	list.select(1)
	right.add_child(list)
	var tree := Tree.new()
	tree.custom_minimum_size = Vector2(0, 170)
	var root_item := tree.create_item()
	root_item.set_text(0, "Root")
	for branch in ["Sets", "Manifestations"]:
		var item := tree.create_item(root_item)
		item.set_text(0, branch)
		for leaf in ["One", "Two"]:
			tree.create_item(item).set_text(0, "%s %s" % [branch, leaf])
	var collapsed := tree.create_item(root_item)
	collapsed.set_text(0, "Collapsed branch")
	tree.create_item(collapsed).set_text(0, "Hidden")
	collapsed.collapsed = true
	right.add_child(tree)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	right.add_child(scroll)
	var long := Label.new()
	long.text = "\n".join(PackedStringArray(range(12).map(func(i: int) -> String: return "A ScrollContainer line %d, long enough to need the horizontal bar as well as the vertical one." % i)))
	scroll.add_child(long)
	await _wait(0.4)
	_move_mouse(buttons.get_child(1).global_position + Vector2(20, 12))
	await _wait(0.3)
	await _shot("controls_sheet")
	margin.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _console() -> void:
	var was_dev: bool = Global.debug_dev_mode
	Global.debug_dev_mode = true
	var bg := _backdrop()
	var console := (load(CONSOLE_SCENE) as PackedScene).instantiate() as Control
	add_child(console)
	await _wait(0.2)
	console.call("toggle_overlay")
	await _wait(0.6)
	await _shot("console_overview")
	var tabs := console.get_node_or_null("Margin/Root/Tabs") as TabContainer
	if tabs != null:
		for i in range(tabs.get_tab_count()):
			tabs.current_tab = i
			await _wait(0.35)
			await _shot("console_%s" % tabs.get_tab_title(i).to_lower())
		tabs.current_tab = 1
		await _wait(0.3)
		var mode := console.get_node_or_null("Margin/Root/Tabs/Enemies/Content/CapRow/Mode") as OptionButton
		if mode != null:
			mode.show_popup()
			await _wait(0.35)
			await _shot("console_option_list")
			mode.get_popup().hide()
	console.queue_free()
	bg.queue_free()
	Global.debug_dev_mode = was_dev
	await _wait(0.2)


## The Imprinter with two held rules and a worn ring they could go onto.
## The Imprinter, then its hover dossiers: a held imprint (`imprint_held`),
## a worn item's before -> after (`imprint_preview`), a bagged item's
## (`imprint_bag`) and the dossiers keyboard focus brings
## (`imprint_focus_first`, `imprint_focus`).
func _imprint() -> void:
	var bg := _backdrop()
	Global.attempt_imprints.clear()
	for rule in [&"retaliation_writ", &"third_litany", &"orbiting_testament"]:
		Global.store_imprint(rule)
	Global.set_followers(2400)
	var was_worn: Array = []
	for slot in range(Inventory.SLOT_COUNT):
		was_worn.append(Global.run_inventory.get_at(slot))
	Global.run_inventory.set_item(ItemData.EquipSlot.RING, _probe_item(ItemData.EquipSlot.RING, 3, &"stored_violence"))
	Global.run_inventory.set_item(ItemData.EquipSlot.MOVE, _probe_item(ItemData.EquipSlot.MOVE, 2, &"pilgrims_momentum"))
	Global.run_inventory.set_item(ItemData.EquipSlot.ARMOR, _probe_item(ItemData.EquipSlot.ARMOR, 1, &"martyr_circuit"))
	var bag_slot := -1
	for slot in range(Global.run_bag.get_slot_count()):
		if Global.run_bag.get_at(slot) == null:
			bag_slot = slot
			break
	if bag_slot >= 0:
		Global.run_bag.set_item(bag_slot, _probe_item(ItemData.EquipSlot.MOVE, 1, &"", 1))
	var screen := (load(IMPRINT_SCRIPT) as Script).new() as CanvasLayer
	add_child(screen)
	await _wait(0.4)
	await _shot("imprint")
	for shot in [
		["imprint_held", "Imprint_retaliation_writ"],
		["imprint_preview", "Candidate_worn_%d" % ItemData.EquipSlot.RING],
		["imprint_bag", "Candidate_bag_%d" % bag_slot],
	]:
		var row := screen.find_child(String(shot[1]), true, false) as Control
		if row == null:
			continue
		_move_mouse(row.global_position + Vector2(minf(140.0, row.size.x * 0.5), row.size.y * 0.5))
		await _wait(0.3)
		await _shot(String(shot[0]))
	# The pointer parks on the title. The first key shows the hidden starting
	# focus on the first imprint (`imprint_focus_first`); the next walks down
	# to the second (`imprint_focus`); each brings its dossier.
	_move_mouse(Vector2(960, 150))
	await _wait(0.2)
	for shot_name in ["imprint_focus_first", "imprint_focus"]:
		_action(&"ui_down")
		await _wait(0.35)
		await _shot(shot_name)
	screen.call("close")
	for slot in range(Inventory.SLOT_COUNT):
		Global.run_inventory.set_item(slot, was_worn[slot])
	if bag_slot >= 0:
		Global.run_bag.set_item(bag_slot, null)
	Global.attempt_imprints.clear()
	bg.queue_free()
	await _wait(0.2)


## A real item of the slot (the `skip`-th by id, so two of a slot differ),
## so the dossiers show real icons and stats.
func _probe_item(slot: int, rarity: int, rule: StringName, skip: int = 0) -> ItemInstance:
	var keys: Array = Global.item_db.keys()
	keys.sort()
	var data: ItemData = null
	for key in keys:
		var candidate: ItemData = Global.get_item_data(String(key))
		if candidate != null and int(candidate.equip_slot) == slot:
			data = candidate
			if skip <= 0:
				break
			skip -= 1
	var inst := ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.POS, 0.5, false)
	inst.manifestation_id = rule
	return inst


func _action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _cards() -> void:
	var scrim := (load(SCRIM_SCRIPT) as Script).new() as CanvasLayer
	add_child(scrim)
	await _wait(0.1)
	scrim.call("show_for", "The Hub", null)
	await _wait(0.2)
	await _shot("card_loading")
	scrim.queue_free()
	await _wait(0.2)
	var bg := _backdrop()
	var narrative := (load(NARRATIVE_SCENE) as PackedScene).instantiate()
	add_child(narrative)
	await _wait(0.1)
	narrative.call("present_opening", "Ilyra Vey")
	await _wait(0.5)
	await _shot("card_narrative")
	narrative.queue_free()
	await _wait(0.2)
	var opening := (load(OPENING_SCENE) as PackedScene).instantiate()
	add_child(opening)
	await _wait(0.1)
	opening.call("present_card", 1, "A VOICE IN THE DARK", "The Archivist", "You came back. They always come back, the ones the Pattern keeps.", [{"label": "I remember nothing."}, {"label": "Who are you?"}], "Continue")
	await _wait(1.6)
	opening.call("_complete_reveal")
	await _wait(0.2)
	await _shot("card_opening_dialogue")
	opening.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _backdrop() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = load(BACKDROP) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.modulate = Color(0.55, 0.5, 0.46)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	add_child(holder)
	return holder


func _first_of(node: Node, type_name: String) -> Node:
	var found := node.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null


func _cancel_input() -> void:
	var press := InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


## Warps the pointer and delivers the motion GUI input listens for.
func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
