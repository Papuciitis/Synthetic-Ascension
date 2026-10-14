extends Node
## Layout coverage for the library's readable controls and complete printed spreads.
const LIBRARY := preload("res://ui/screens/HubLibrary.gd")
const RIBBON_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
var _passes := 0
var _failures := 0
var _library: Node
var _out := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_dir = "user://saves_test_library_readability/"
	SaveManager.current_save = null
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibraryReadabilityTest: " + message)

func _frames(count: int = 4) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame

func _text_fits(button: Button) -> bool:
	var text_extent := button.get_theme_font(&"font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size(&"font_size"))
	var margins := button.get_theme_stylebox(&"normal").get_minimum_size()
	return text_extent.x + margins.x <= button.size.x + 1.0 and text_extent.y + margins.y <= button.size.y + 1.0

func _plain(bbcode: String) -> String:
	var prose := RichTextLabel.new()
	prose.bbcode_enabled = true
	prose.text = bbcode
	var parsed := prose.get_parsed_text()
	prose.free()
	return parsed

func _shot(caption: String) -> void:
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(caption + ".png"))

func _check_opening_print() -> void:
	var book: Control = _library.get("_open_book")
	var captured: Control = book.get("_opening_left_page")
	if not is_instance_valid(captured):
		return
	var icon: TextureRect = _library.get("_icon")
	var context: RichTextLabel = _library.get("_plate_body")
	var captured_icon := captured.find_child("AccountIllustration", true, false) as TextureRect
	var captured_context := captured.find_child("MarginalNote", true, false) as RichTextLabel
	_check(captured_icon.size.is_equal_approx(icon.size) and captured_icon.position.is_equal_approx(icon.position), "opening paper and settled page draw the portrait at identical geometry")
	_check(captured_context.size.is_equal_approx(context.size) and captured_context.position.is_equal_approx(context.position), "opening paper and settled page preserve identical context geometry")
	print("Captured portrait=", captured_icon.size, " at", captured_icon.position, " live=", icon.size, " at", icon.position)

func _run() -> void:
	_check(_plain("[b]Known[/b]") == "Known", "parsed-text comparisons inspect actual printed characters")
	Global.start_new_attempt()
	Global.library_note("item:beka")
	Global.library_note("record:accounts")
	var old_motion: bool = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1280, 720)
	_library = LIBRARY.new()
	add_child(_library)
	await _frames()
	_library.call("select_book", "Buildcraft")
	await get_tree().create_timer(1.4, true).timeout
	await _frames(8)
	var first_icon: TextureRect = _library.get("_icon")
	var first_book: Control = _library.get("_open_book")
	var source_extent := first_icon.texture.get_size()
	var drawn_extent := source_extent * minf(first_icon.size.x / source_extent.x, first_icon.size.y / source_extent.y)
	_check(drawn_extent.y >= first_book.size.y * 0.23, "the first natural opening draws a large native portrait before any filtering")
	print("First portrait: source=", source_extent, " drawn=", drawn_extent, " leaf=", first_book.size)
	_check_opening_print()
	await _shot("portrait_first_natural_1280")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	for scale: float in [1.0, 1.5]:
		window.content_scale_factor = scale
		await _frames(8)
		if scale == 1.5:
			_library.call("show_shelves", false)
			SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
			window.content_scale_factor = scale
			await _frames(8)
			_library.set("_reading_places", {})
			_library.call("select_book", "Buildcraft")
			await get_tree().create_timer(1.4, true).timeout
			await _frames(8)
			var natural_context: RichTextLabel = _library.get("_plate_body")
			_check(int(_library.get("_folio_index")) == 0 and _library.get("_icon").visible, "the larger-text natural opening inspects the illustrated first spread")
			_check(natural_context.get_content_height() <= natural_context.size.y + 1.0, "the natural animated opening at larger text scale preserves the full context")
			_check_opening_print()
			await _shot("portrait_first_natural_scale150")
			SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
			window.content_scale_factor = scale
			await _frames(8)
		for name: String in ["ResearchTarget", "ReturnToCourtyard", "PutBookBack", "FindInVolume"]:
			var button := _library.find_child(name, true, false) as Button
			_check(button != null, name + " exposes a stable control")
			if button == null:
				continue
			_check(button.get_theme_font_size(&"font_size") >= 25, name + " has readable native type")
			_check(_text_fits(button), name + " prints its entire caption at scale " + str(scale))
		for button: Button in [_library.get("_previous_page"), _library.get("_next_page")]:
			_check(button.get_theme_font_size(&"font_size") >= 25 and button.size.y >= 44, "page corners are readable, broad targets")
			_check(_text_fits(button), "a page corner caption fits on the paper")
		for ribbon: Button in _library.get("_ribbons"):
			var geometry: Dictionary = ribbon.call("tail_geometry")
			_check(int(geometry.font_size) >= 17, "cloth captions never shrink to miniature type")
			_check(RIBBON_FONT.get_string_size(String(ribbon.get("label")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(geometry.font_size)).x <= ribbon.size.x * 0.86, "the complete cloth caption fits its tail")
			var rest: Vector2 = ribbon.get("rest_position")
			var gutter: float = _library.get("_open_book").size.x * 0.5
			_check(rest.x + ribbon.size.x <= gutter or rest.x >= gutter, "a cloth marker attaches entirely to one physical leaf")
		_library.call("set_filter", "Buildcraft", "")
		await _frames()
		var icon: TextureRect = _library.get("_icon")
		var book: Control = _library.get("_open_book")
		var texture_extent := icon.texture.get_size()
		var art_extent := texture_extent * minf(icon.size.x / texture_extent.x, icon.size.y / texture_extent.y)
		var physical_height: float = art_extent.y * window.size.y / _library.get("_layout").size.y
		_check(physical_height >= (150.0 if scale == 1.0 else 110.0), "the Chronicler's actual native texture draws at a readable physical size")
		print("Portrait scale", scale, ": actual physical height=", physical_height, " context=", _library.get("_plate_body").get_content_height(), "/", _library.get("_plate_body").size.y)
		var joined := ""
		var folios: Array = _library.get("_folios")
		var facing: Array = _library.get("_left_folios")
		for spread: int in range(folios.size()):
			joined += _plain(String(facing[spread])) + _plain(String(folios[spread]))
		_check(joined == _plain(String(_library.get("_account_text"))), "measured spreads preserve every source character exactly")
		var body: RichTextLabel = _library.get("_body")
		_check(body.get_content_height() <= body.size.y + 1.0, "the full first leaf remains on paper")
		if scale == 1.0:
			_check(String(body.text).contains("Manifestation identity"), "the first spread uses available right-page height")
		_check(_library.get("_plate_body").get_content_height() <= _library.get("_plate_body").size.y + 1.0, "the illustrated primer preserves its full written context")
		await _shot("portrait_primer_scale" + str(roundi(scale * 100)))
		for spread: int in range(folios.size()):
			_library.set("_folio_index", spread)
			_library.call("_display_folio")
			await _frames()
			var continuation: RichTextLabel = _library.get("_continuation")
			_check(body.get_content_height() <= body.size.y + 1.0, "every right leaf stays on paper")
			_check(not continuation.visible or continuation.get_content_height() <= continuation.size.y + 1.0, "every facing continuation stays on paper")
	_library.call("set_filter", "Pairs", "")
	await _frames()
	var diagram := _library.find_child("NounStudy", true, false) as Control
	_check(diagram != null and diagram.visible, "a sealed pair illustrates only its public nouns and worn counts")
	if diagram != null:
		_check(diagram.find_children("NounGlyph*", "Label", true, false).size() == 2, "the pair diagram uses both canonical nouns")
		var left_page: Control = _library.get("_left_page")
		var marker: Control = _library.get("_track_button")
		_check(left_page.get_global_rect().encloses(diagram.get_global_rect()) and left_page.get_global_rect().encloses(marker.get_global_rect()), "the wax, noun study and research action fit their leaf at larger text scale")
	_check(not String(_library.get("_account_text")).contains("Red Line"), "the diagram does not reveal a sealed pair name")
	await _shot("portrait_pair_scale150")
	_library.call("_toggle_research_target")
	await _frames()
	_check(_text_fits(_library.get("_research_button")), "the research shortcut fits a marked sealed clue")
	Global.library_set_target("item:beka")
	_library.call("_refresh_book_marks")
	await _frames()
	_check(_text_fits(_library.get("_research_button")), "the research shortcut fits a recovered account")
	for category: String in ["Items", "Recipes", "Chronicles"]:
		_library.call("set_filter", category, "beka" if category == "Items" else "")
		await _frames(8)
		var context: RichTextLabel = _library.get("_plate_body")
		_check(not context.visible or context.get_content_height() <= context.size.y + 1.0, category + " preserves its written identity context at larger text scale")
		var left: Control = _library.get("_left_page")
		var art: Control = _library.get("_icon") if _library.get("_icon").visible else _library.get("_seal")
		_check(left.get_global_rect().encloses(art.get_global_rect()), category + " illustration or wax stays on its leaf at larger text scale")
		await _shot("portrait_" + category.to_lower() + "_scale150")
	_library.call("set_filter", "Items", "nothing matches this phrase")
	await _frames()
	_check(_library.get("_next_page").disabled, "an empty find leaves no stale turn target")
	_check(String(_library.get("_body").text) == "Only discoveries and written clues on sealed accounts can be found.", "an empty find prints its own short account")
	_library.call("set_filter", "Buildcraft", "")
	await _frames()
	_library.set("_account_text", "A short known account.")
	_library.call("_reflow_account")
	await _frames()
	_check(_library.get("_folios").size() == 1 and _library.get("_body").text == "A short known account.", "a short account prints in one independent leaf")
	_library.call("_close")
	await _frames()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", old_motion, false)
	print("HubLibraryReadabilityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
