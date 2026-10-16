extends Node2D
## Staged art/type catalogue: actual BattleText badges and canonical colours.
## This does not apply gameplay statuses or claim every build was playtested.
## --out=<absolute directory> [--visible] [--reduced-motion]

const StatusIcons := preload("res://core/combat/CombatStatusIcons.gd")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")
const LOGICAL_SIZE := Vector2i(1920, 1080)
const OUTPUT_SIZE := Vector2i(1280, 720)
const GOLD := Color("d6bf86")
const IVORY := Color("eee5cf")
const MUTED := Color("a5afa2")
const IDS: Array[StringName] = [
	&"burn", &"bleed", &"stun", &"slow", &"warded", &"haste", &"fading",
	&"execution_mark", &"wound", &"cracked", &"prime", &"weak_point", &"fracture", &"link",
	&"blood_rite", &"healing_sealed", &"jam", &"debt", &"anchored", &"marked", &"scarred",
]
const NOTES: Array[String] = [
	"Damage over time", "Damage over time", "Movement / cast interruption", "Movement penalty",
	"Herald / Chanter protection", "Herald movement buff", "Distortion damage over time",
	"Execution target mark", "Execution wound", "Limited-hit vulnerability", "Momentum setup",
	"Precision Weak Point", "Ordnance vulnerability", "Dominion linked targets",
	"Invocation / Execution interaction", "Player healing lock", "Barrage jam window", "Persistent Debt marker · Staged timer sample",
	"Full Anchor Rite stability", "Predestination target mark", "Scar Tissue armour",
]

class StagedDebtRenderer:
	extends AscensionRunner

	# Keep the real inherited world-marker draw path, without building engines,
	# connecting gameplay events or advancing a pretend Debt timer.
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

var _out := "user://dev_previews/combat_status_catalog"
var _visible := false
var _reduced_motion := false
var _failures := 0
var _save_writes_before := 0
var _page_nodes: Array[Node] = []
var _heading_font: Font = null
var _body_font: Font = null


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/status_catalog_%d/" % Time.get_ticks_usec()
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--visible":
			_visible = true
		elif arg == "--reduced-motion":
			_reduced_motion = true
	if not _visible:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("A rendering driver is required for actual status pixels.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Cannot create output: " + error_string(dir_error))
		get_tree().quit(1)
		return
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	SettingsManager.set_value(&"accessibility", &"damage_numbers", true, false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced_motion, false)
	get_window().title = "Synthetic Ascension — staged combat status catalogue"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = LOGICAL_SIZE
	get_window().content_scale_factor = 1.0
	get_window().size = OUTPUT_SIZE
	_heading_font = HUD_THEME.get_font(&"font", &"InstitutionalHeading")
	_body_font = HUD_THEME.get_font(&"font", &"Label")
	BattleText.visible = true
	var pages: Array[Dictionary] = []
	for page in range(3):
		_clear_page()
		_build_page(page)
		# Hold an ordinary settled callout age; no artificial font/icon renderer.
		BattleText.set_process(false)
		var ages: PackedFloat32Array = BattleText.get("_ages")
		for index in range(int(BattleText.get("_count"))):
			ages[index] = 0.28
		BattleText.set("_ages", ages)
		BattleText.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		pixels.convert(Image.FORMAT_RGB8)
		var filename := "status-catalog-%d.png" % (page + 1)
		_save_image(pixels, absolute_out.path_join(filename))
		var entries: Array[Dictionary] = []
		for offset in range(7):
			var id := IDS[page * 7 + offset]
			var art := StatusIcons.texture(id)
			if art == null:
				_fail("Missing authored icon: " + String(id))
			entries.append({"id": String(id), "label": StatusIcons.label(id), "colour": StatusIcons.colour(id).to_html(), "art": art.resource_path if art != null else "", "presentation_path": "AscensionRunner._draw tagged persistent world label" if id == &"debt" else "BattleText.status_popup"})
		pages.append({"file": filename, "statuses": entries, "pooled_callout_entries": BattleText.get("_count")})
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Unexpected profile selection or save write.")
	var info := {
		"scene": "res://tools/dev/StatusEffectsPreview.tscn",
		"presentation": "STAGED PRESENTATION. All 21 existing-effect badges and canonical names through production BattleText, with Debt through the actual AscensionRunner persistent-world-label draw path. Gameplay states and Debt timers are not applied or advanced by this catalogue.",
		"viewport": [1920, 1080], "image_size": [1280, 720], "world_px_to_image_px": 2.0 / 3.0,
		"sample_entry_scale": 1.35, "held_callout_age_seconds": 0.28,
		"persistent_debt_sample": {"text": "DEBT 24  1.5s", "font_size_world_px": 15, "badge_size_world_px": 26, "sample_scale": 1.0, "timer": "Static staged value; no live Debt collection claim"},
		"reduced_motion": _reduced_motion, "pages": pages, "save_writes": writes, "failures": _failures,
	}
	var file := FileAccess.open(absolute_out.path_join("catalog-capture-info.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write catalogue metadata.")
	else:
		file.store_string(JSON.stringify(info, "\t") + "\n")
		file.close()
	print("StatusEffectsPreview: pages=", pages.size(), " statuses=", IDS.size(), " save writes=", writes, " failures=", _failures, " -> ", absolute_out)
	_clear_page()
	BattleText.set_process(false)
	get_tree().quit(1 if _failures > 0 else 0)


func _build_page(page: int) -> void:
	_fill(Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE)), Color("0e1311"), -1000)
	_fill(Rect2(0, 0, 1920, 150), Color("131913"), -999)
	_label(Rect2(42, 22, 1836, 52), "COMBAT STATUS BADGES  /  %d OF 3" % (page + 1), 35, GOLD, true)
	_label(Rect2(43, 85, 1834, 42), "Staged presentation · Production combat text and artwork · Native 1280 × 720 output", 27, MUTED)
	for offset in range(7):
		var index := page * 7 + offset
		var cell := _cell(offset)
		var id := IDS[index]
		_card(cell, StatusIcons.colour(id))
		_label(Rect2(cell.position + Vector2(22, 14), Vector2(850, 40)), NOTES[index], 27, IVORY)
		if id == &"debt":
			_persistent_debt_sample(cell)
		else:
			BattleText.status_popup(cell.position + Vector2(cell.size.x * 0.5, 128), id, "", 1.35)
	var mixed := _cell(7)
	_card(mixed, GOLD)
	var ids: Array[StringName] = []
	if page == 0:
		ids.assign([&"burn", &"bleed", &"slow"])
		_label(Rect2(mixed.position + Vector2(22, 14), Vector2(850, 40)), "Mixed status names retain their own colours", 27, IVORY)
		BattleText.statuses_popup(mixed.position + Vector2(mixed.size.x * 0.5, 128), ids, 1.35)
	elif page == 1:
		ids.assign([&"execution_mark", &"wound", &"cracked"])
		_label(Rect2(mixed.position + Vector2(22, 14), Vector2(850, 40)), "Mixed target conditions · Neutral separators", 27, IVORY)
		BattleText.statuses_popup(mixed.position + Vector2(mixed.size.x * 0.5, 128), ids, 1.35)
	else:
		ids.assign([&"armoured", &"vampiric", &"fast"])
		_label(Rect2(mixed.position + Vector2(22, 14), Vector2(850, 40)), "Existing elite palette remains per name", 27, IVORY)
		BattleText.modifier_popup(mixed.position + Vector2(mixed.size.x * 0.5, 128), ids, 1.35)
	_label(Rect2(43, 1008, 1834, 45), "1920 × 1080 at ⅔ scale · Callouts 1.35×; Debt default 15px · Staged presentation · No profile saves", 24, MUTED)


func _persistent_debt_sample(cell: Rect2) -> void:
	var runner := StagedDebtRenderer.new()
	runner.name = "StagedPersistentDebtRenderer"
	add_child(runner)
	_page_nodes.append(runner)
	# Draw-point coordinates are world/canvas positions in this camera-free
	# stage. The fifth semantic ID selects the real persistent status path.
	runner._draw_points = [[cell.position + Vector2(cell.size.x * 0.5, 94), 2.0, StatusIcons.colour(&"debt"), "DEBT 24  1.5s", &"debt"]]
	runner.queue_redraw()


func _cell(index: int) -> Rect2:
	return Rect2(Vector2(42 + (index % 2) * 936, 174 + floori(float(index) / 2.0) * 204), Vector2(900, 184))


func _card(rect: Rect2, colour: Color) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = -100
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172018")
	style.border_color = colour.darkened(0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_page_nodes.append(panel)


func _fill(rect: Rect2, colour: Color, layer: int) -> void:
	var fill := ColorRect.new()
	fill.position = rect.position
	fill.size = rect.size
	fill.color = colour
	fill.z_index = layer
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	_page_nodes.append(fill)


func _label(rect: Rect2, text: String, size: int, colour: Color, heading: bool = false) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_override("font", _heading_font if heading else _body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_page_nodes.append(label)


func _clear_page() -> void:
	BattleText.clear()
	for node in _page_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_page_nodes.clear()


func _save_image(pixels: Image, path: String) -> void:
	var result := pixels.save_png(path)
	if result != OK:
		_fail("Capture write failed: " + error_string(result))


func _fail(message: String) -> void:
	_failures += 1
	push_error("StatusEffectsPreview: " + message)
