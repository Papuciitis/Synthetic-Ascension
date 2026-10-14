extends CanvasLayer
## Choose a binding, read an account, follow a thread within that volume.
signal closed()
const LibraryData := preload("res://ui/screens/HubLibraryData.gd")
const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const BookSpine := preload("res://ui/widgets/library/LibraryBook.gd")
const OpenBook := preload("res://ui/widgets/library/LibraryOpenBook.gd")
const Bookmark := preload("res://ui/widgets/library/LibraryRibbon.gd")
const SectionIndex := preload("res://ui/widgets/library/LibrarySectionIndex.gd")
const PageSeal := preload("res://ui/widgets/library/LibrarySeal.gd")
const Pagination := preload("res://ui/widgets/library/LibraryPagination.gd")
const CHRONICLER := preload("res://assets/textures/hub/hub_npc_chronicler.png")
const PAGE_INK := Color(0.20, 0.115, 0.065)
const SPINE_TITLES := ["Buildcraft", "Rules", "Pairs", "Bestiary", "Equipment", "Augments", "Sets", "Recipes", "Chronicles"]
const BINDINGS := [Color(0.90, 0.83, 0.65), Color(0.68, 0.85, 0.75), Color(0.78, 0.69, 0.89), Color(0.80, 0.67, 0.56), Color(0.91, 0.73, 0.61), Color(0.64, 0.77, 0.90), Color(0.66, 0.84, 0.67), Color(0.90, 0.77, 0.53), Color(0.84, 0.65, 0.64)]
const CONTEXT := {
	"Buildcraft": "The Chronicler's primer\nEquipment, rules and the choices that shape an attempt.",
	"Manifestations": "Rules carried by equipment\nConnect their shared nouns to awaken pairs.",
	"Pairs": "Two nouns, one shared rule\nDistinct worn Manifestations supply their strength.",
	"Enemies": "Accounts from the field\nBehaviour, warning signs and ways to respond.",
	"Items": "The base copy\nRank, polarity and its carried rule can change the item you wear.",
	"Augments": "The base augment\nLevels and combinations can carry it further.",
	"Sets": "A shared equipment identity\nWorn members meet each tier's piece requirements.",
	"Recipes": "Ingredients before the outcome\nSeek the clue; its payoff is recorded once reached.",
	"Chronicles": "Testimony kept by the Chronicler\nAccounts are written as their events are witnessed.",
}
enum ReadingState { SHELVES, OPENING, READING, TURNING, CLOSING, SWITCHING }
var _reading_state := ReadingState.SHELVES
var _pending_category := ""
var _pending_turn := 0
var _pending_ribbon := ""
var _pending_account := ""
var _exit_pending := false
var _transfer: TextureRect
var _transfer_tween: Tween
var result_count := 0
var _entries: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _selected_key := ""
var _selected_index := 0
var _active_category := ""
var _last_book := "Buildcraft"
var _reading_places := {}
var _folios: Array[String] = []
var _left_folios: Array[String] = []
var _folio_index := 0
var _account_text := ""
var _layout: Control
var _shelves: Control
var _reader: Control
var _open_book: Control
var _book_pages: Control
var _left_leaf: Control
var _right_leaf: Control
var _left_page: VBoxContainer
var _right_page: VBoxContainer
var _title: Label
var _subtitle: Label
var _volume_title: Label
var _body: RichTextLabel
var _plate_body: RichTextLabel
var _continuation: RichTextLabel
var _right_caption: Label
var _icon: TextureRect
var _seal: Control
var _noun_study: VBoxContainer
var _track_button: Button
var _previous_page: Button
var _next_page: Button
var _page_number: Label
var _left_folio: Label
var _research_button: Button
var _shelf_note: Label
var _book_buttons: Array[Button] = []
var _ribbons: Array[Button] = []
var _section_index: Control
var _search: LineEdit
var _search_panel: PanelContainer
var _search_caption: Label
var _reading_veil: ColorRect
var _page_tween: Tween
var _open_tween: Tween
var _page_sound_index := 0
var _was_paused := false
var _closing := false
var _book_open := false
var _stick_axis := 0.0
var _stick_wait := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("ui_sound_manual", true)
	layer = 160
	_was_paused = get_tree().paused
	get_tree().paused = true
	_entries = LibraryData.build_entries()
	_build_screen()
	show_shelves(false)
	get_viewport().size_changed.connect(_place_books)
	_place_books.call_deferred()
	set_process(false)

func _build_screen() -> void:
	_layout = Control.new()
	_layout.name = "LibraryLayout"
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.theme = ChamberKit.THEME
	add_child(_layout)
	var backdrop := TextureRect.new()
	backdrop.name = "AlcoveCourtyard"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = load("res://assets/ui/library/alcove_library_courtyard.png")
	_layout.add_child(backdrop)
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_right = -24
	header.offset_top = 10
	header.offset_bottom = 66
	header.add_theme_constant_override("separation", 12)
	_layout.add_child(header)
	var heading := _label("Quiet Alcove", 28, ChamberKit.PARCHMENT, &"ArcaneHeading")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_research_button = _button("Research", _open_research_target)
	_research_button.name = "ResearchTarget"
	_research_button.custom_minimum_size.x = 176
	header.add_child(_research_button)
	var courtyard := _button("Return to courtyard", _close)
	courtyard.name = "ReturnToCourtyard"
	header.add_child(courtyard)
	_build_shelves()
	_build_reader()
	_refresh_book_marks()

func _build_shelves() -> void:
	_shelves = Control.new()
	_shelves.name = "LibraryShelves"
	_shelves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_shelves)
	for index: int in range(LibraryData.CATEGORIES.size()):
		var book: Button = BookSpine.new()
		book.name = "Book" + LibraryData.CATEGORIES[index]
		book.set("book_title", SPINE_TITLES[index])
		book.set("volume", index + 1)
		book.set("tint", BINDINGS[index])
		book.pressed.connect(select_book.bind(LibraryData.CATEGORIES[index]))
		book.mouse_entered.connect(_describe_book.bind(index))
		book.focus_entered.connect(_describe_book.bind(index))
		_shelves.add_child(book)
		_book_buttons.append(book)
	var note := PanelContainer.new()
	note.name = "ChroniclerNote"
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.anchor_left = 0.12
	note.anchor_right = 0.68
	note.offset_top = -106
	note.offset_bottom = -12
	note.add_theme_stylebox_override("panel", ChamberKit.box(Color(0.03, 0.025, 0.02, 0.82), Color.TRANSPARENT, 0, 12))
	_shelves.add_child(note)
	_shelf_note = _label("", 19, ChamberKit.BODY)
	_shelf_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shelf_note.max_lines_visible = 3
	_shelf_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.add_child(_shelf_note)

func _place_books() -> void:
	if not is_instance_valid(_shelves):
		return
	var extent := _layout.size
	for index: int in range(_book_buttons.size()):
		var upper := index < 5
		var column := index if upper else index - 5
		var columns := 5 if upper else 4
		var gap := extent.x * 0.008
		var width := (extent.x * 0.474 - gap * (columns - 1)) / columns
		_book_buttons[index].position = Vector2(extent.x * 0.134 + column * (width + gap), extent.y * (0.507 if upper else 0.674))
		_book_buttons[index].size = Vector2(width, extent.y * (0.10 if upper else 0.12))

func _build_reader() -> void:
	_reading_veil = ColorRect.new()
	_reading_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reading_veil.offset_top = 78
	_reading_veil.color = Color(0.02, 0.018, 0.014, 0.5)
	_reading_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_reading_veil)
	_reader = Control.new()
	_reader.name = "BookReader"
	_reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reader.offset_top = 82
	_reader.offset_bottom = -8
	_layout.add_child(_reader)
	_open_book = OpenBook.new()
	_open_book.name = "OpenBook"
	_open_book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_open_book.offset_left = 18
	_open_book.offset_right = -228
	_open_book.offset_bottom = -22
	_reader.add_child(_open_book)
	_book_pages = Control.new()
	_book_pages.name = "BookPages"
	_book_pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_open_book.add_child(_book_pages)
	_section_index = SectionIndex.new()
	_section_index.name = "SectionRibbons"
	_section_index.show_behind_parent = true
	_section_index.account_requested.connect(_jump_to_account)
	_open_book.add_child(_section_index)
	_open_book.open_progress_changed.connect(func(_progress: float) -> void: _sync_section_interaction())
	_left_leaf = _leaf_frame("LeftPrintedLeaf")
	_right_leaf = _leaf_frame("RightPrintedLeaf")
	_left_page = _paper_column("IdentityPage", 0.12, 0.44)
	_right_page = _paper_column("AccountPage", 0.55, 0.87)
	_volume_title = _label("", 18, Color(0.39, 0.24, 0.12), &"ArcaneItalic")
	_left_page.add_child(_volume_title)
	_title = _label("", 30, PAGE_INK, &"ArcaneHeading")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_page.add_child(_title)
	_subtitle = _label("", 19, Color(0.36, 0.23, 0.12), &"ArcaneItalic")
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_page.add_child(_subtitle)
	_icon = TextureRect.new()
	_icon.name = "AccountIllustration"
	_icon.custom_minimum_size.y = 280
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_left_page.add_child(_icon)
	_seal = PageSeal.new()
	_seal.name = "SealedPageWax"
	_seal.custom_minimum_size.y = 140
	_left_page.add_child(_seal)
	_noun_study = VBoxContainer.new()
	_noun_study.name = "NounStudy"
	_noun_study.add_theme_constant_override("separation", 4)
	_noun_study.hide()
	_left_page.add_child(_noun_study)
	_plate_body = _prose(20)
	_plate_body.name = "MarginalNote"
	_plate_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_page.add_child(_plate_body)
	# Wrapped type settles after the hidden reader becomes visible. Rebudget
	# the actual portrait after those metrics arrive, including window changes.
	for control: Control in [_left_page, _title, _subtitle, _plate_body]:
		control.resized.connect(func() -> void: _refresh_identity_layout.call_deferred())
	_left_page.visibility_changed.connect(func() -> void: _refresh_identity_layout.call_deferred())
	_track_button = _ink_button("Mark this clue", _toggle_research_target)
	_track_button.name = "BookmarkPage"
	_left_page.add_child(_track_button)
	_continuation = _prose(24)
	_continuation.name = "FacingContinuation"
	_continuation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_continuation.hide()
	_continuation.meta_clicked.connect(_follow_book_link)
	_left_page.add_child(_continuation)
	_right_caption = _label("The account", 24, PAGE_INK, &"ArcaneHeading")
	_right_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_page.add_child(_right_caption)
	_body = _prose(24)
	_body.name = "ReferenceText"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.focus_mode = Control.FOCUS_ALL
	_body.meta_clicked.connect(_follow_book_link)
	_right_page.add_child(_body)
	_body.resized.connect(func() -> void: _reflow_account.call_deferred())
	_left_folio = _label("", 21, PAGE_INK, &"ArcaneItalic")
	_page_number = _label("", 21, PAGE_INK, &"ArcaneItalic")
	for label: Label in [_left_folio, _page_number]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.anchor_top = 0.81
		label.anchor_bottom = 0.85
		label.anchor_left = 0.12 if label == _left_folio else 0.55
		label.anchor_right = 0.44 if label == _left_folio else 0.87
		(_left_leaf if label == _left_folio else _right_leaf).add_child(label)
	_previous_page = _ink_button("← Turn back", _turn_page.bind(-1))
	_next_page = _ink_button("Turn page →", _turn_page.bind(1))
	for button: Button in [_previous_page, _next_page]:
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.anchor_left = 0.10 if button == _previous_page else 0.71
		button.anchor_right = 0.29 if button == _previous_page else 0.90
		button.anchor_top = 0.84
		button.anchor_bottom = 0.91
		button.custom_minimum_size.y = 44
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT if button == _previous_page else HORIZONTAL_ALIGNMENT_RIGHT
		(_left_leaf if button == _previous_page else _right_leaf).add_child(button)
	for index: int in range(3):
		var ribbon: Button = Bookmark.new()
		ribbon.name = ["BeginningRibbon", "UnreadRibbon", "ResearchRibbon"][index]
		ribbon.set("label", ["First", "Unread", "Research"][index])
		ribbon.set("tint", [Color(0.93, 0.86, 0.65), Color(1, 0.92, 0.62), Color.WHITE][index])
		ribbon.pressed.connect(_pull_ribbon.bind(["beginning", "unread", "research"][index]))
		_open_book.add_child(ribbon)
		_ribbons.append(ribbon)
	_open_book.resized.connect(_reader_resized)
	var shelves := _button("Put back · Esc / B", show_shelves)
	shelves.name = "PutBookBack"
	shelves.position = Vector2(18, 0)
	_reader.add_child(shelves)
	var find := _button("Find in this volume", _toggle_find)
	find.name = "FindInVolume"
	find.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	find.offset_left = -250
	find.offset_right = -18
	_reader.add_child(find)
	_search_panel = PanelContainer.new()
	_search_panel.name = "FindAccount"
	_search_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_search_panel.offset_left = -450
	_search_panel.offset_right = -18
	_search_panel.offset_top = 62
	_search_panel.offset_bottom = 156
	_search_panel.add_theme_stylebox_override("panel", ChamberKit.box(ChamberKit.PANEL, ChamberKit.GOLD_DIM, 1, 10))
	_reader.add_child(_search_panel)
	var search_contents := VBoxContainer.new()
	_search_panel.add_child(search_contents)
	_search_caption = _label("Find an account", 23, ChamberKit.PARCHMENT)
	search_contents.add_child(_search_caption)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Names you know, or a clue…"
	_search.add_theme_font_size_override("font_size", 25)
	_search.text_changed.connect(func(_text: String) -> void: _refresh_results())
	search_contents.add_child(_search)
	_search_panel.hide()
	_reader_resized.call_deferred()

func _paper_column(caption: String, left: float, right: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = caption
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.anchor_left = left
	column.anchor_right = right
	column.anchor_top = 0.14
	column.anchor_bottom = 0.78
	column.add_theme_constant_override("separation", 8)
	(_left_leaf if left < 0.5 else _right_leaf).add_child(column)
	return column

func _leaf_frame(caption: String) -> Control:
	var frame := Control.new()
	frame.name = caption
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_pages.add_child(frame)
	return frame

func _prose(font_size: int) -> RichTextLabel:
	var prose := RichTextLabel.new()
	prose.bbcode_enabled = true
	prose.scroll_active = false
	prose.selection_enabled = true
	prose.add_theme_font_size_override("normal_font_size", font_size)
	prose.add_theme_font_size_override("bold_font_size", font_size)
	prose.add_theme_color_override("default_color", PAGE_INK)
	prose.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	prose.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return prose

func _label(caption: String, font_size: int, colour: Color, variation: StringName = &"ArcaneBody") -> Label:
	var label := Label.new()
	label.text = caption
	ChamberKit.label(label, variation, font_size, colour)
	return label

func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.theme_type_variation = &"ArcaneSmallButton"
	button.add_theme_font_override("font", ChamberKit.THEME.get_font(&"font", &"ArcaneKeyButton"))
	button.add_theme_font_size_override("font_size", 25)
	button.custom_minimum_size.y = 56
	button.pressed.connect(action)
	return button

func _ink_button(caption: String, action: Callable) -> Button:
	var button := _button(caption, action)
	button.theme_type_variation = &"ArcaneLinkButton"
	button.add_theme_font_override("font", ChamberKit.THEME.get_font(&"font", &"ArcaneLinkButton"))
	button.add_theme_font_size_override("font_size", 25)
	button.custom_minimum_size.y = 44
	button.add_theme_color_override("font_color", PAGE_INK)
	button.add_theme_color_override("font_hover_color", Color(0.48, 0.22, 0.09))
	button.add_theme_color_override("font_focus_color", Color(0.48, 0.22, 0.09))
	button.add_theme_color_override("font_pressed_color", Color(0.48, 0.22, 0.09))
	button.add_theme_color_override("font_disabled_color", Color(PAGE_INK, 0.38))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var mark := StyleBoxFlat.new()
	mark.bg_color = Color(PAGE_INK, 0.045)
	mark.border_color = Color(PAGE_INK, 0.42)
	mark.border_width_bottom = 1
	button.add_theme_stylebox_override("hover", mark)
	button.add_theme_stylebox_override("focus", mark)
	button.add_theme_stylebox_override("pressed", mark)
	return button

func _reader_resized() -> void:
	_open_book.pivot_offset = _open_book.size * 0.5
	# The source book has a transparent outer margin. Sew the roots into its
	# painted fore-edge rather than the enclosing Control's invisible edge.
	_section_index.position = _open_book.size * Vector2(0.97, 0.15)
	_section_index.size = Vector2(210, _open_book.size.y * 0.70)
	for index: int in range(_ribbons.size()):
		var ribbon := _ribbons[index]
		var width := maxf(114.0, _open_book.size.x * 0.08)
		var gap := maxf(16.0, _open_book.size.x * 0.012)
		var left := _open_book.size.x * 0.5 - width - gap * 0.5 if index == 0 else _open_book.size.x * 0.5 + gap * 0.5 + (index - 1) * (width + gap)
		ribbon.position = Vector2(left, _open_book.size.y * 0.885)
		ribbon.size = Vector2(width, _open_book.size.y * 0.105)
		ribbon.set("rest_position", ribbon.position)
		ribbon.set("root_rect", Rect2(Vector2(0, -_open_book.size.y * 0.815), Vector2(ribbon.size.x, _open_book.size.y * 0.045)))
		ribbon.call("set_book_open_progress", float(_open_book.get("open_progress")), _open_book.size.x)
	_refresh_identity_layout.call_deferred()
	_seal.custom_minimum_size.y = clampf(_open_book.size.y * 0.15, 56, 140)
	_reflow_account.call_deferred()

func _refresh_identity_layout() -> void:
	if not is_instance_valid(_icon) or not _icon.is_visible_in_tree() or _left_page.size.x < 40 or _title.size.x < 40:
		return
	# Preserve the title and written context at larger text scales, then give
	# the actual game portrait the remaining illustrated area on this leaf.
	var fixed := _volume_title.get_combined_minimum_size().y + _title.get_combined_minimum_size().y + _subtitle.get_combined_minimum_size().y + 40.0
	fixed += _plate_body.get_content_height()
	if _track_button.visible:
		fixed += _track_button.get_combined_minimum_size().y + 8.0
	_icon.custom_minimum_size.y = floorf(minf(_open_book.size.y * 0.25, maxf(80.0, _left_page.size.y - fixed - 4.0)))

func select_book(category: String) -> void:
	if not LibraryData.CATEGORIES.has(category) or _closing:
		return
	_pending_account = ""
	if _reading_state in [ReadingState.OPENING, ReadingState.TURNING, ReadingState.CLOSING, ReadingState.SWITCHING]:
		_pending_category = category
		_pending_turn = 0
		_pending_ribbon = ""
		return
	if _reading_state == ReadingState.READING:
		if _active_category == category:
			if Global.library_target_key == String(_reading_places.get(category, {}).get("key", "")):
				_pull_ribbon("research")
			return
		_pending_category = category
		_retire_volume(true)
		return
	_open_volume(category)

func _open_volume(category: String) -> void:
	_reading_state = ReadingState.OPENING
	_open_book.set("turn_progress", 1.0)
	var place: Dictionary = _reading_places.get(category, {})
	_selected_key = String(place.get("key", ""))
	_assign_volume(category, "")
	_folio_index = clampi(int(place.get("folio", 0)), 0, maxi(0, _folios.size() - 1))
	_display_folio()
	_book_open = true
	_open_book.set("open_progress", 0.0)
	if ChamberKit.reduced():
		_begin_cover_open()
	else:
		_reader.hide()
		_reading_veil.hide()
		_shelves.show()
		var index := LibraryData.CATEGORIES.find(category)
		_book_buttons[index].modulate.a = 0.0
		_begin_pickup.call_deferred(index)

func _begin_pickup(index: int) -> void:
	# Let the newly titled cover render before freezing it for its trip.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await get_tree().process_frame
	if not _closing and _reading_state == ReadingState.OPENING:
		_move_cover(index, false, _begin_cover_open)

func _begin_cover_open() -> void:
	if _closing:
		return
	_shelves.hide()
	_reader.show()
	_reading_veil.show()
	if not ChamberKit.reduced():
		# Container wrapping must settle before freezing the ink onto the
		# moving paper. Keep this preparation invisible under the closed cover.
		_book_pages.modulate.a = 0.0
		_book_pages.show()
		await get_tree().process_frame
		_refresh_identity_layout()
		await get_tree().process_frame
		if _closing or _reading_state != ReadingState.OPENING:
			_book_pages.modulate.a = 1.0
			return
	if _open_book.has_method("capture_opening_pages"):
		_open_book.call("capture_opening_pages", _left_leaf, _right_leaf)
	if not ChamberKit.reduced():
		_book_pages.hide()
		_book_pages.modulate.a = 1.0
	SfxManager.play_ui(&"library_open")
	if ChamberKit.reduced():
		_open_book.set("open_progress", 1.0)
		_finish_open()
	else:
		_open_tween = ChamberKit.tween(self)
		_open_tween.tween_property(_open_book, "open_progress", 1.0, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_open_tween.tween_callback(_finish_open)

func _finish_open() -> void:
	_open_tween = null
	_reading_state = ReadingState.READING
	_sync_section_interaction()
	_mark_visible_account_read()
	_body.grab_focus()
	_run_pending_action()

func set_filter(category: String, query: String) -> void:
	# Immediate entry point for Hub callers and isolated validation tools.
	_cancel_motion()
	_pending_category = ""
	_pending_turn = 0
	_pending_ribbon = ""
	_pending_account = ""
	_reading_state = ReadingState.READING
	_assign_volume(category, query)

func _assign_volume(category: String, query: String) -> void:
	_active_category = category if LibraryData.CATEGORIES.has(category) else "All"
	_last_book = category if LibraryData.CATEGORIES.has(category) else _last_book
	_shelves.hide()
	_reader.show()
	_reading_veil.show()
	_book_open = true
	_open_book.scale = Vector2.ONE
	_open_book.set("open_progress", 1.0)
	var volume := LibraryData.CATEGORIES.find(_active_category)
	_open_book.set("cover_title", SPINE_TITLES[volume] if volume >= 0 else "Accounts")
	_open_book.set("cover_tint", BINDINGS[volume] if volume >= 0 else Color.WHITE)
	_search.set_text(query)
	_search_panel.hide()
	_search_caption.text = "Find in " + (SPINE_TITLES[volume] if volume >= 0 else "the library")
	_refresh_results()

func show_shelves(animate: bool = true) -> void:
	if _reading_state in [ReadingState.CLOSING, ReadingState.SWITCHING]:
		return
	_pending_category = ""
	_pending_turn = 0
	_pending_ribbon = ""
	_pending_account = ""
	if not animate or not _reader.visible:
		_cancel_motion()
		_reveal_shelves()
	else:
		_retire_volume(false)

func _retire_volume(switching: bool) -> void:
	_cancel_motion()
	_reading_state = ReadingState.SWITCHING if switching else ReadingState.CLOSING
	_book_open = false
	_sync_section_interaction()
	_stick_axis = 0.0
	set_process(false)
	_search_panel.hide()
	_refresh_book_marks()
	SfxManager.play_ui(&"library_close")
	if not ChamberKit.reduced():
		if _open_book.has_method("capture_opening_pages"):
			_open_book.call("capture_opening_pages", _left_leaf, _right_leaf)
		_open_tween = ChamberKit.tween(self)
		_open_tween.tween_property(_open_book, "open_progress", 0.0, 0.34).set_trans(Tween.TRANS_SINE)
		_open_tween.tween_callback(_return_closed_cover)
	else:
		_reveal_shelves()

func _return_closed_cover() -> void:
	_reader.hide()
	_reading_veil.hide()
	_shelves.show()
	_book_buttons[maxi(0, LibraryData.CATEGORIES.find(_last_book))].modulate.a = 0.0
	_move_cover(maxi(0, LibraryData.CATEGORIES.find(_last_book)), true, _reveal_shelves)

func _move_cover(index: int, returning: bool, finished: Callable) -> void:
	var skin := _open_book
	var extent := skin.size * Vector2(0.45, 0.91)
	var open_center := skin.global_position + skin.size * Vector2(0.725, 0.5)
	var shelf := _book_buttons[index].get_global_rect()
	var small := minf(shelf.size.x / extent.x, shelf.size.y / extent.y)
	_transfer = TextureRect.new()
	_transfer.name = "MovingVolume"
	_transfer.texture = skin.call("cover_texture") as Texture2D
	_transfer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_transfer.stretch_mode = TextureRect.STRETCH_SCALE
	_transfer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_transfer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transfer.z_index = 20
	_transfer.size = extent
	_transfer.pivot_offset = extent * 0.5
	_transfer.position = (open_center if returning else shelf.get_center()) - extent * 0.5
	_transfer.scale = Vector2.ONE if returning else Vector2.ONE * small
	_transfer.rotation = 0.0 if returning else -0.14
	_transfer.modulate = BINDINGS[index]
	_layout.add_child(_transfer)
	var target_center := shelf.get_center() if returning else open_center
	_transfer_tween = ChamberKit.tween(self).set_parallel(true)
	_transfer_tween.tween_property(_transfer, "position", target_center - extent * 0.5, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transfer_tween.tween_property(_transfer, "scale", Vector2.ONE * small if returning else Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transfer_tween.tween_property(_transfer, "rotation", -0.14 if returning else 0.0, 0.28)
	if returning:
		_transfer_tween.tween_property(_transfer, "modulate:a", 0.0, 0.10).set_delay(0.18)
	_transfer_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_transfer):
			_transfer.queue_free()
		_transfer = null
		finished.call())

func _reveal_shelves() -> void:
	_reading_state = ReadingState.SHELVES
	_book_open = false
	_reader.hide()
	_reading_veil.hide()
	_shelves.show()
	var index := maxi(0, LibraryData.CATEGORIES.find(_last_book))
	_book_buttons[index].modulate.a = 1.0
	_book_buttons[index].grab_focus()
	_describe_book(index)
	if _exit_pending:
		_exit_pending = false
		_close()
	else:
		_run_pending_action()

func _cancel_motion() -> void:
	for tween: Tween in [_page_tween, _open_tween, _transfer_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_page_tween = null
	_open_tween = null
	_transfer_tween = null
	_open_book.set("turn_progress", 1.0)
	if is_instance_valid(_transfer):
		_transfer.queue_free()
	_transfer = null
	for book: Button in _book_buttons:
		book.modulate.a = 1.0

func _run_pending_action() -> void:
	if _pending_category != "":
		var category := _pending_category
		_pending_category = ""
		select_book(category)
	elif _pending_account != "":
		var key := _pending_account
		_pending_account = ""
		_jump_to_account(key)
	elif _pending_ribbon != "":
		var ribbon := _pending_ribbon
		_pending_ribbon = ""
		_pull_ribbon(ribbon)
	elif _pending_turn != 0:
		var direction := _pending_turn
		_pending_turn = 0
		_turn_page(direction)

func _refresh_book_marks() -> void:
	var target := _entry_for_key(Global.library_target_key)
	for index: int in range(_book_buttons.size()):
		var known := 0
		var unread := 0
		var total := 0
		for entry: Dictionary in _entries:
			if entry["category"] != LibraryData.CATEGORIES[index]:
				continue
			total += 1
			if entry["discovered"]:
				known += 1
				if not Global.library_read_entries.has(String(entry["key"])):
					unread += 1
		var book := _book_buttons[index]
		book.set("discovered_pages", known)
		book.set("total_pages", total)
		book.set("unread_pages", unread)
		book.set("research_target", not target.is_empty() and target["category"] == LibraryData.CATEGORIES[index])
		book.call("refresh_marks")
		book.tooltip_text = LibraryData.CATEGORIES[index] + " · Volume " + ChamberKit.roman(index + 1) + "\n" + book.tooltip_text
	_research_button.disabled = target.is_empty()
	_research_button.text = "Research" if target.is_empty() else "Read account" if target["discovered"] else "Follow thread"
	_research_button.tooltip_text = "Mark a clue inside a volume to seek it out." if target.is_empty() else String(target["title"]) + "\n" + String(target["hint"])

func _describe_book(index: int) -> void:
	if not is_instance_valid(_shelf_note):
		return
	var book := _book_buttons[index]
	_shelf_note.text = "%s · Volume %s\n%d accounts recovered · %d still sealed · %d unread\n%s" % [LibraryData.CATEGORIES[index], ChamberKit.roman(index + 1), int(book.get("discovered_pages")), int(book.get("total_pages")) - int(book.get("discovered_pages")), int(book.get("unread_pages")), "A red thread marks your research." if bool(book.get("research_target")) else "Choose this binding to read its accounts."]

func _refresh_results() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = null
	if _reading_state == ReadingState.TURNING:
		_reading_state = ReadingState.READING
	_pending_turn = 0
	_pending_ribbon = ""
	_pending_account = ""
	_open_book.set("turn_progress", 1.0)
	_results = LibraryData.filter_entries(_entries, _active_category, _search.text)
	result_count = _results.size()
	var index := 0
	for candidate: int in range(_results.size()):
		if String(_results[candidate]["key"]) == _selected_key:
			index = candidate
	if _results.is_empty():
		_selected_key = ""
		_selected_index = 0
		_title.text = "An empty margin"
		_subtitle.text = "No account matches that wording."
		_volume_title.text = _active_category
		_icon.hide()
		_icon.texture = null
		_seal.hide()
		_noun_study.hide()
		_plate_body.text = "Try another name you know, or the words of a clue."
		_right_caption.text = "The search"
		_account_text = "Only discoveries and written clues on sealed accounts can be found."
		_track_button.hide()
		_folio_index = 0
		_reflow_account()
	else:
		_show_entry(index, false)
	_refresh_section_index()
	_update_ribbons()

func _refresh_section_index() -> void:
	if not is_instance_valid(_section_index):
		return
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if entry["category"] == _active_category:
			entries.append(entry)
	_section_index.call("set_entries", entries, _selected_key)
	_sync_section_interaction()

func _sync_section_interaction() -> void:
	if is_instance_valid(_section_index):
		_section_index.call("set_reading_enabled", _can_read() or (_book_open and _reading_state == ReadingState.TURNING))

func _jump_to_account(key: String) -> void:
	var entry := _entry_for_key(key)
	if entry.is_empty() or String(entry["category"]) != _active_category:
		return
	if _reading_state == ReadingState.TURNING:
		_pending_account = key
		_pending_turn = 0
		_pending_ribbon = ""
		return
	if not _can_read():
		return
	# Resolve against the whole binding, even when Find currently hides it.
	# The old printed spread stays intact until _start_leaf_turn captures it.
	_search.set_block_signals(true)
	_search.text = ""
	_search.set_block_signals(false)
	_results = LibraryData.filter_entries(_entries, _active_category, "")
	result_count = _results.size()
	var destination := -1
	var current := -1
	for candidate: int in _results.size():
		if String(_results[candidate]["key"]) == key:
			destination = candidate
		if String(_results[candidate]["key"]) == _selected_key:
			current = candidate
	if destination < 0:
		return
	_selected_index = maxi(0, current)
	if key == _selected_key and _folio_index == 0:
		_selected_index = destination
		_search_panel.hide()
		_display_folio()
		return
	_start_leaf_turn(-1 if destination <= current else 1)
	_show_entry(destination, false)
	_finish_leaf_target.call_deferred()

func _show_entry(index: int, animate: bool = true) -> void:
	if index < 0 or index >= _results.size():
		return
	if animate and _selected_key != String(_results[index]["key"]):
		_start_leaf_turn(1)
	_selected_index = index
	var entry: Dictionary = _results[index]
	_selected_key = String(entry["key"])
	_folio_index = 0
	_title.text = String(entry["title"]) if entry["discovered"] else "A sealed account"
	_subtitle.text = String(entry["subtitle"]) if entry["discovered"] else "Its name is held beneath the wax."
	var volume := LibraryData.CATEGORIES.find(String(entry["category"]))
	_volume_title.text = "%s · Volume %s" % [SPINE_TITLES[volume], ChamberKit.roman(volume + 1)]
	_icon.texture = entry["icon"] as Texture2D
	if _icon.texture == null and entry["discovered"] and entry["category"] in ["Buildcraft", "Chronicles"]:
		_icon.texture = CHRONICLER
	_icon.visible = _icon.texture != null
	_seal.visible = not bool(entry["discovered"])
	_plate_body.text = String(CONTEXT.get(entry["category"], ""))
	_right_caption.text = "The account" if entry["discovered"] else "A clue in the margin"
	_account_text = String(entry["body"]) if entry["discovered"] else "[b]Seek this account[/b]\n" + String(entry["hint"]) + "\n\nThe wax holds its name and effects until you discover it in play."
	if entry["category"] == "Recipes":
		_account_text += "\n\nThese are the base ingredients. [url=book:Buildcraft]Consult Buildcraft[/url] for card availability and the lower thresholds of this attempt."
	var research := LibraryData.research_notes(entry)
	if not research.is_empty():
		_account_text += "\n\n" + research
	_track_button.visible = bool(entry["trackable"])
	_update_noun_study(entry)
	_update_bookmark_button()
	_reflow_account()
	_refresh_identity_layout.call_deferred()
	_update_ribbons()
	if animate:
		_finish_leaf_target.call_deferred()

func _reflow_account() -> void:
	if not is_instance_valid(_body) or _body.size.x < 40 or _body.size.y < 50:
		return
	var font := _body.get_theme_font(&"normal_font")
	var right_height := _body.size.y - 8.0
	var left_text_height := _left_page.size.y - _title.get_combined_minimum_size().y - _volume_title.get_combined_minimum_size().y - 16.0
	var first_leaves := Pagination.paginate(_account_text, font, 24, _body.size.x, right_height)
	_folios.clear()
	_left_folios.clear()
	if not first_leaves.is_empty():
		_folios.append(first_leaves[0])
		_left_folios.append("")
		# The first right leaf has its full height. Following spreads retain the
		# volume and account title on the left, so budget those leaves separately.
		# Balanced fragments retain their formatting when measured again.
		var remaining := "".join(first_leaves.slice(1))
		var leaves: Array[String] = []
		if not remaining.is_empty():
			leaves = Pagination.paginate(remaining, font, 24, _body.size.x, minf(right_height, left_text_height))
		var leaf := 0
		while leaf < leaves.size():
			_left_folios.append(leaves[leaf])
			_folios.append(leaves[leaf + 1] if leaf + 1 < leaves.size() else "")
			leaf += 2
	if _folios.is_empty():
		_folios.append("")
	_folio_index = clampi(_folio_index, 0, _folios.size() - 1)
	_display_folio()

func _display_folio() -> void:
	if _folios.is_empty():
		return
	_body.text = _folios[_folio_index]
	var entry := _entry_for_key(_selected_key)
	var is_continuation := _folio_index > 0
	_continuation.visible = is_continuation
	_continuation.text = _left_folios[_folio_index] if is_continuation else ""
	var noun_study := _noun_study.get_child_count() > 0 and String(entry.get("category", "")) == "Pairs"
	_noun_study.visible = not is_continuation and noun_study
	_subtitle.visible = not is_continuation and not noun_study
	_icon.visible = not is_continuation and _icon.texture != null
	_seal.visible = not is_continuation and not entry.is_empty() and not bool(entry["discovered"])
	_plate_body.visible = not is_continuation and not noun_study
	_seal.custom_minimum_size.y = minf(_open_book.size.y * 0.10, 80.0) if noun_study else clampf(_open_book.size.y * 0.15, 56, 140)
	_track_button.visible = not is_continuation and bool(entry.get("trackable", false))
	_right_caption.text = "The search" if entry.is_empty() else "Continued account" if is_continuation and not _body.text.is_empty() else "End of account" if is_continuation else "The account" if bool(entry.get("discovered", false)) else "A clue in the margin"
	_body.scroll_to_line(0)
	_left_folio.text = "Folio %02d" % int(entry.get("folio", 0)) if not entry.is_empty() else "Find an account"
	_page_number.text = "Spread %d of %d" % [_folio_index + 1, _folios.size()]
	_previous_page.disabled = _selected_index == 0 and _folio_index == 0
	_next_page.disabled = _results.is_empty() or (_selected_index == _results.size() - 1 and _folio_index == _folios.size() - 1)
	if not _selected_key.is_empty():
		_reading_places[_active_category] = {"key": _selected_key, "folio": _folio_index}
	_mark_visible_account_read()
	_update_ribbons()

func _mark_visible_account_read() -> void:
	if not _can_read() or not _reader.is_visible_in_tree() or _selected_key.is_empty() or _folios.is_empty():
		return
	var entry := _entry_for_key(_selected_key)
	if bool(entry.get("discovered", false)) and _folio_index == _folios.size() - 1:
		Global.library_mark_read(_selected_key)
		_update_ribbons()

func _turn_page(direction: int) -> void:
	if _reading_state == ReadingState.TURNING:
		_pending_account = ""
		_pending_turn = direction
		_pending_ribbon = ""
		return
	if _results.is_empty() or not _can_read():
		return
	if direction > 0 and _folio_index + 1 < _folios.size():
		_start_leaf_turn(direction)
		_folio_index += 1
		_display_folio()
	elif direction < 0 and _folio_index > 0:
		_start_leaf_turn(direction)
		_folio_index -= 1
		_display_folio()
	else:
		var next := _selected_index + direction
		if next < 0 or next >= _results.size():
			return
		_start_leaf_turn(direction)
		_show_entry(next, false)
		if direction < 0:
			_folio_index = maxi(0, _folios.size() - 1)
			_display_folio()
	_finish_leaf_target.call_deferred()

func _finish_leaf_target() -> void:
	if not ChamberKit.reduced() and _open_book.has_method("capture_leaf_back") and float(_open_book.get("turn_progress")) < 1.0:
		_open_book.call("capture_leaf_back", _left_leaf if int(_open_book.get("turn_direction")) > 0 else _right_leaf)

func _start_leaf_turn(direction: int) -> void:
	_search_panel.hide()
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_open_book.set("turn_direction", direction)
	if not ChamberKit.reduced():
		_reading_state = ReadingState.TURNING
		_open_book.call("hold_facing_page", _left_leaf if direction > 0 else _right_leaf, 0 if direction > 0 else 1)
		_open_book.call("capture_leaf", _right_leaf if direction > 0 else _left_leaf, direction)
		_open_book.set("turn_progress", 0.0)
		_page_tween = ChamberKit.tween(self)
		_page_tween.tween_interval(0.03)
		_page_tween.tween_property(_open_book, "turn_progress", 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_page_tween.tween_callback(_finish_turn)
	else:
		_reading_state = ReadingState.READING
		_open_book.set("turn_progress", 1.0)
	SfxManager.play_ui(StringName("library_page_%d" % (_page_sound_index % 3 + 1)))
	_page_sound_index += 1

func _finish_turn() -> void:
	_page_tween = null
	_reading_state = ReadingState.READING
	_sync_section_interaction()
	_mark_visible_account_read()
	_run_pending_action()

func _pull_ribbon(kind: String) -> void:
	if _reading_state == ReadingState.TURNING:
		_pending_account = ""
		_pending_ribbon = kind
		_pending_turn = 0
		return
	if _active_category == "" or not _can_read():
		return
	var key := ""
	if kind == "research":
		var target := _entry_for_key(Global.library_target_key)
		if target.is_empty() or String(target["category"]) != _active_category:
			return
		key = Global.library_target_key
	elif kind == "unread":
		for entry: Dictionary in _entries:
			if entry["category"] == _active_category and entry["discovered"] and not Global.library_read_entries.has(String(entry["key"])):
				key = String(entry["key"])
				if key != _selected_key:
					break
		if key.is_empty():
			return
	_search.set_text("")
	_results = LibraryData.filter_entries(_entries, _active_category, "")
	result_count = _results.size()
	var index := 0
	var current_index := -1
	for candidate: int in range(_results.size()):
		if _results[candidate]["key"] == key:
			index = candidate
		if _results[candidate]["key"] == _selected_key:
			current_index = candidate
	if not _results.is_empty():
		_selected_index = maxi(0, current_index)
		if String(_results[index]["key"]) == _selected_key and _folio_index == 0:
			SfxManager.play_ui(&"library_bookmark")
			_update_ribbons()
			return
		_start_leaf_turn(-1 if index <= current_index else 1)
		_show_entry(index, false)
		_finish_leaf_target.call_deferred()

func _update_ribbons() -> void:
	if is_instance_valid(_section_index):
		_section_index.call("select_key", _selected_key)
		_sync_section_interaction()
	if _ribbons.size() < 3:
		return
	var has_unread := false
	for entry: Dictionary in _entries:
		if entry["category"] == _active_category and entry["discovered"] and not Global.library_read_entries.has(String(entry["key"])):
			has_unread = true
	_ribbons[0].tooltip_text = "Beginning of this volume"
	_ribbons[1].disabled = not has_unread
	_ribbons[1].tooltip_text = "Next unread account in this volume" if has_unread else "Every recovered account in this volume has been read."
	var target := _entry_for_key(Global.library_target_key)
	_ribbons[2].disabled = target.is_empty() or target["category"] != _active_category
	_ribbons[2].tooltip_text = "Your marked account in this volume" if not _ribbons[2].disabled else "No research thread in this volume." if target.is_empty() else "Your thread belongs to %s. Put this book back to follow it." % target["category"]
	for ribbon: Button in _ribbons:
		ribbon.set("active", not ribbon.disabled)
		ribbon.queue_redraw()

func _entry_for_key(key: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if entry["key"] == key:
			return entry
	return {}

func _update_bookmark_button() -> void:
	_track_button.text = "Remove thread" if Global.library_target_key == _selected_key else "Mark account" if _entry_for_key(_selected_key).get("discovered", false) else "Mark clue"
	_track_button.tooltip_text = "Remove this account's research thread." if Global.library_target_key == _selected_key else "Keep a research thread at this account."

func _update_noun_study(entry: Dictionary) -> void:
	for child: Node in _noun_study.get_children():
		_noun_study.remove_child(child)
		child.queue_free()
	if String(entry.get("category", "")) != "Pairs":
		_noun_study.hide()
		return
	var pair := ManifestationPairCatalog.get_def(StringName(entry.get("id", "")))
	if pair == null:
		_noun_study.hide()
		return
	# These nouns are already written in the public clue. The live counts use
	# the data helper's distinct worn-rule contract without naming hidden rules.
	var counts := LibraryData._equipped_noun_counts()
	_noun_study.add_child(_label("Your current equipment", 22, PAGE_INK, &"ArcaneItalic"))
	for noun: StringName in pair.nouns:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_noun_study.add_child(row)
		var glyph := _label(ManifestationNouns.glyph(noun), 32, ManifestationNouns.colour(noun))
		glyph.name = "NounGlyph" + String(noun).capitalize()
		glyph.custom_minimum_size.x = 40
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_theme_color_override("font_outline_color", PAGE_INK)
		glyph.add_theme_constant_override("outline_size", 4)
		row.add_child(glyph)
		var label := _label(ManifestationNouns.label(noun).capitalize(), 24, PAGE_INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_label("%d / %d" % [int(counts.get(noun, 0)), ManifestationPairCatalog.NOUN_THRESHOLD], 25, PAGE_INK))
	_noun_study.show()

func _toggle_research_target() -> void:
	if _selected_key.is_empty() or not _can_read():
		return
	Global.library_set_target("" if Global.library_target_key == _selected_key else _selected_key)
	SfxManager.play_ui(&"library_bookmark")
	_update_bookmark_button()
	_refresh_book_marks()
	_update_ribbons()

func _open_research_target() -> void:
	var entry := _entry_for_key(Global.library_target_key)
	if entry.is_empty():
		return
	_reading_places[String(entry["category"])] = {"key": Global.library_target_key, "folio": 0}
	select_book(String(entry["category"]))

func _follow_book_link(meta: Variant) -> void:
	if not _can_read():
		return
	var link := String(meta)
	if link.begins_with("book:"):
		select_book(link.trim_prefix("book:"))

func _toggle_find() -> void:
	if not _can_read():
		return
	_search_panel.visible = not _search_panel.visible
	if _search_panel.visible:
		_search.grab_focus()
	else:
		_body.grab_focus()
	SfxManager.play_ui(&"library_bookmark")

func _can_read() -> bool:
	return _reading_state == ReadingState.READING and _book_open and float(_open_book.get("open_progress")) >= 0.98

func _input(event: InputEvent) -> void:
	if _closing:
		return
	var cancel := event.is_action_pressed(&"ui_cancel")
	if event is InputEventJoypadButton and event.pressed:
		cancel = cancel or event.button_index == JOY_BUTTON_B
		if _book_open and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_turn_page(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
	if _book_open and event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_stick_axis = event.axis_value if absf(event.axis_value) > 0.6 else 0.0
		set_process(not is_zero_approx(_stick_axis))
		get_viewport().set_input_as_handled()
	if _book_open and event is InputEventKey and event.pressed and not _search.has_focus():
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			_turn_page(-1 if event.keycode == KEY_PAGEUP else 1)
			get_viewport().set_input_as_handled()
	if cancel:
		get_viewport().set_input_as_handled()
		if _search_panel.visible:
			_search_panel.hide()
			_body.grab_focus()
		elif _reading_state in [ReadingState.OPENING, ReadingState.READING, ReadingState.TURNING]:
			show_shelves()
		else:
			_close()

func _process(delta: float) -> void:
	if not _book_open or is_zero_approx(_stick_axis):
		set_process(false)
		return
	_stick_wait -= delta
	if _stick_wait <= 0.0:
		_turn_page(1 if _stick_axis > 0 else -1)
		_stick_wait = 0.7

func _close() -> void:
	if _closing:
		return
	if _reading_state != ReadingState.SHELVES:
		_exit_pending = true
		_pending_category = ""
		_pending_turn = 0
		_pending_ribbon = ""
		_pending_account = ""
		show_shelves()
		return
	_closing = true
	_cancel_motion()
	SfxManager.play_ui(&"ui_back")
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()
