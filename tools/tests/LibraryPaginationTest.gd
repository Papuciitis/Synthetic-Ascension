extends Node

const HELPER_PATH := "res://ui/widgets/library/LibraryPagination.gd"
const FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const GUIDES := preload("res://ui/screens/HubLibraryGuides.gd")
var _passes := 0
var _failures := 0
var _helper: Script


func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_pagination/"
	SaveManager.current_save = null
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibraryPaginationTest: " + message)


func _render(bbcode: String, size_px: int, width: float, height: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(width, height)
	for kind: String in ["normal", "bold", "italics", "bold_italics", "mono"]:
		label.add_theme_font_override(kind + "_font", FONT)
		label.add_theme_font_size_override(kind + "_font_size", size_px)
	label.add_theme_constant_override("line_separation", 4)
	add_child(label)
	label.text = bbcode
	return label


func _test_pages(source: String, size_px: int, width: float, height: float, caption: String) -> Array[String]:
	var pages: Array[String] = _helper.paginate(source, FONT, size_px, width, height)
	_check(pages.size() > 1, caption + " produces continuation pages")
	var joined := ""
	var reference := _render(source, size_px, width, height)
	await get_tree().process_frame
	var expected := reference.get_parsed_text()
	reference.queue_free()
	for page: String in pages:
		var label := _render(page, size_px, width, height)
		await get_tree().process_frame
		joined += label.get_parsed_text()
		_check(label.get_content_height() <= height, "%s stays on paper (%d > %.0f)" % [caption, label.get_content_height(), height])
		_check(label.get_content_width() <= width + 1.0, caption + " wraps even an unbroken word within the leaf")
		label.queue_free()
	_check(joined == expected, caption + " preserves every visible character in source order")
	return pages


func _run() -> void:
	_check(ResourceLoader.exists(HELPER_PATH), "a reusable measured paginator exists")
	if not ResourceLoader.exists(HELPER_PATH):
		_finish()
		return
	_helper = load(HELPER_PATH) as Script
	var empty: Array[String] = _helper.paginate("", FONT, 22, 420.0, 350.0)
	_check(empty == [""], "an empty account remains one readable blank leaf")
	var short: Array[String] = _helper.paginate("[b]Ward[/b]\nA short account.", FONT, 22, 420.0, 350.0)
	_check(short == ["[b]Ward[/b]\nA short account."], "a fitting account retains its exact markup")
	var paragraph := "Walk beside the old wall and record each new discovery before returning to the alcove. ".repeat(28)
	await _test_pages(paragraph, 22, 390.0, 285.0, "one long paragraph")
	var linked := "[b][i][url=\"book:Buildcraft\"]" + "Follow the chronicler's reference and compare the shared nouns. ".repeat(24) + "[/url][/i][/b]"
	var linked_pages: Array[String] = await _test_pages(linked, 33, 220.0, 210.0, "150 percent nested linked text")
	for page: String in linked_pages:
		_check(page.begins_with("[b][i][url=\"book:Buildcraft\"]") and page.ends_with("[/url][/i][/b]"), "each continuation keeps independently valid nested formatting and the same URL")
	var implicit_url := "https://alcove.invalid/" + "reference/".repeat(65)
	var implicit_pages: Array[String] = await _test_pages("[url]" + implicit_url + "[/url]", 33, 165.0, 175.0, "a URL with its destination in the text")
	for page: String in implicit_pages:
		_check(page.begins_with("[url=" + implicit_url + "]"), "a split shorthand URL retains its complete original destination")
	await _test_pages("[b]" + "W".repeat(270) + "[/b]", 33, 165.0, 175.0, "an unbroken word at larger text scale")
	var paragraphs := "[b]First account[/b]\nA known rule.\n\n" + "[url=book:Pairs]" + paragraph + "[/url]\n\n[b]Last account[/b]\nThe ink ends here."
	await _test_pages(paragraphs, 22, 350.0, 255.0, "paragraphs and adjacent tag boundaries")
	await _test_pages(("[lb]a[rb] é é 👩‍🔬 \n").repeat(35), 33, 160.0, 170.0, "literal brackets and Unicode")
	await _test_primer_paragraph_endings()
	_test_cut_inside_paragraph_break()
	_finish()


## A paragraph that exactly fills its leaf can leave the cut between the two
## newlines of its break; a short next paragraph ("— Bren", "Conduit") then
## used to spin the short-tail scan forever.
func _test_cut_inside_paragraph_break() -> void:
	for text: String in ["The archive keeps it, still an error.\n\n— Bren", "[b]Set[/b] pieces.\n\nConduit"]:
		var between := text.find("\n\n") + 1
		var cut: int = _helper._avoid_short_tail(text, 0, between)
		_check(cut == between, "a cut inside a paragraph break returns instead of hanging (%d)" % cut)


func _test_primer_paragraph_endings() -> void:
	var primer := String(GUIDES.pages()[0]["body"])
	for leaf_height: float in [230.0, 285.0, 340.0]:
		var pages: Array[String] = await _test_pages(primer, 36, 420.0, leaf_height, "the equipment primer at 150 percent text")
		var previous := ""
		for index: int in range(pages.size()):
			var label := _render(pages[index], 36, 420.0, leaf_height)
			var plain := label.get_parsed_text()
			if index > 0 and not previous.ends_with("\n\n"):
				var ending := plain.get_slice("\n\n", 0).strip_edges().replace("\n", " ").replace("\t", " ")
				_check(ending.split(" ", false).size() >= 3, "a continued primer paragraph does not leave one or two words alone before the next section: " + ending)
			previous = plain
			label.queue_free()


func _finish() -> void:
	print("LibraryPaginationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
