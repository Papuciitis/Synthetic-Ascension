extends Control
## Read-only visual probe. Needs a display (do not use --headless).
## <godot> --path . res://tools/dev/AugmentArtGallery.tscn -- --skip-choosers
## Captures real card scenes; never starts a run, loads a save, or binds a pick.

const CARD_SCENE := preload("res://ui/augments/AugmentCard.tscn")
const SELECT_SCENE := preload("res://ui/augments/AugmentSelect.tscn")
const QA_DIR := "res://docs/art/reference/augment-cards-2026-10-14"
const BASE_SLUGS: PackedStringArray = [
	"magic_missile", "tesla_aura", "spirit_slash", "blink_hex",
	"summon_spiderlings", "reflect_shield", "stamina_core", "sprint_servos",
	"lucky_charm", "corruption_engine", "doctrine_of_burden", "inversion_lens",
	"equilibrium_sigil", "litany_of_wounds", "cult_of_personality", "gamblers_rite",
]
const MEMORY_FIELDS: PackedStringArray = [
	"attempt_augment_levels", "attempt_augment_transcended", "attempt_augment_facets",
	"pending_augment_pick",
]

var _out: String
var _saved_memory: Dictionary = {}
var _layer: Control
var _save_writes_before := 0
var _skip_choosers := false
var _failed := false


func _enter_tree() -> void:
	# This process has no profile loaded. The guard also prevents an accidental
	# autosave if a presentation helper starts requesting one in the future.
	Global.debug_disable_autosave = true


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_out = ProjectSettings.globalize_path(QA_DIR).simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").replace("\\", "/").simplify_path()
		elif arg == "--skip-choosers":
			_skip_choosers = true
	# Captures are restricted to this project QA folder, including a subfolder.
	var allowed := ProjectSettings.globalize_path(QA_DIR).replace("\\", "/").simplify_path()
	_out = _out.replace("\\", "/").trim_suffix("/")
	if _out.to_lower() != allowed.to_lower() and not _out.to_lower().begins_with(allowed.to_lower() + "/"):
		_fail("Output must stay inside " + allowed)
		return
	if not _validate_art():
		_finish()
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(_out)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("Cannot create capture folder: " + error_string(directory_error))
		return
	_save_writes_before = SaveManager.debug_save_writes
	for field: String in MEMORY_FIELDS:
		var value: Variant = Global.get(field)
		_saved_memory[field] = value.duplicate(true) if value is Dictionary else value
	Global.attempt_augment_levels = {}
	Global.attempt_augment_transcended = {}
	Global.attempt_augment_facets = {}
	Global.pending_augment_pick = false
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1280, 960)
	window.content_scale_size = Vector2i(1280, 960)
	window.content_scale_factor = 1.0
	window.title = "Augment art QA"
	await get_tree().process_frame
	var bases: Array[Dictionary] = []
	var transcends: Array[Dictionary] = []
	var facets: Array[Dictionary] = []
	var duos: Array[Dictionary] = []
	for slug: String in BASE_SLUGS:
		var id := StringName("augment_" + slug)
		bases.append({"kind": AugmentBinding.KIND_NEW, "id": String(id), "grade": 0})
		transcends.append({"kind": AugmentBinding.KIND_TRANSCEND, "id": String(id), "grade": -1})
		for option: Dictionary in AugmentFacets.options(id):
			facets.append({"kind": AugmentBinding.KIND_FACET, "id": String(id), "grade": -1, "facet": option["id"]})
	for id: StringName in AugmentDuos.ids():
		duos.append({"kind": AugmentBinding.KIND_DUO, "id": String(id), "grade": -1})
	await _pages("base", bases)
	await _pages("transcend", transcends)
	await _pages("facets", facets)
	await _pages("duos", duos)
	if not _skip_choosers and not _failed:
		for slug: String in BASE_SLUGS:
			if _failed:
				break
			var id := StringName("augment_" + slug)
			if AugmentFacets.has_facets(id):
				await _chooser(id, slug)
	_finish()


func _validate_art() -> bool:
	var expected: Dictionary = {"base": [], "transcend": [], "facets": [], "duos": []}
	if Global.augment_db.size() != 16 or AugmentArt.SLUGS.size() != 16:
		_fail("The gallery expects the current 16-augment roster.", false)
		return false
	for slug: String in BASE_SLUGS:
		var id := StringName("augment_" + slug)
		if not Global.augment_db.has(id) or String(AugmentArt.SLUGS.get(id, "")) != slug:
			_fail("Missing augment data or art mapping: " + slug, false)
			return false
		expected["base"].append(slug + ".png")
		expected["transcend"].append(slug + ".png")
		for option: Dictionary in AugmentFacets.options(id):
			expected["facets"].append(slug + "_" + String(option["id"]) + ".png")
	for id: StringName in AugmentDuos.ids():
		expected["duos"].append(String(id).trim_prefix("duo_") + ".png")
	if expected["facets"].size() != 14 or expected["duos"].size() != 6:
		_fail("The gallery expects 14 Facets and 6 Duos.", false)
		return false
	for group: String in expected:
		var directory := AugmentArt.CARD_DIR + ("" if group == "base" else group + "/")
		var found: Array[String] = []
		for filename: String in DirAccess.get_files_at(directory):
			if filename.get_extension().to_lower() == "png":
				found.append(filename)
		if found.size() != expected[group].size():
			_fail("Incomplete illustration group: " + group, false)
			return false
		for filename: String in expected[group]:
			var path := directory + filename
			if not found.has(filename) or not ResourceLoader.exists(path):
				_fail("Missing imported illustration: " + path, false)
				return false
			var texture := load(path) as Texture2D
			if texture == null or texture.get_width() != 512 or texture.get_height() != 512:
				_fail("Run the 512px export and import before the gallery: " + path, false)
				return false
	return true


func _pages(group: String, entries: Array[Dictionary]) -> void:
	for start in range(0, entries.size(), 8):
		if _failed:
			return
		await _clear_layer()
		Global.attempt_augment_facets = {}
		Global.attempt_augment_transcended = {}
		_layer = Control.new()
		_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_layer)
		_background(_layer)
		var page := (start >> 3) + 1
		_label(_layer, Vector2(40, 14), Vector2(1200, 30), "AUGMENT CARDS / %s / PAGE %d" % [group.to_upper(), page], 24)
		_label(_layer, Vector2(40, 45), Vector2(1200, 22), "Actual AugmentCard scene / 1280 x 960 / 222 x 220 art window / preview only", 16)
		for index in range(start, mini(start + 8, entries.size())):
			var entry := entries[index]
			var id := AugmentBinding.display_augment_id(entry)
			var data := Global.augment_db.get(id) as AugmentData
			Global.attempt_augment_levels[String(id)] = 5 if group == "transcend" else (3 if group == "facets" or group == "duos" else 1)
			if entry.has("facet"):
				Global.attempt_augment_facets[String(id)] = String(entry["facet"])
			var local_index := index - start
			var origin := Vector2(75 + (local_index % 4) * 295, 90 + (local_index >> 2) * 430)
			var card := CARD_SCENE.instantiate() as Control
			card.position = origin
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(card)
			card.call("set_offer", data, entry)
			# Inspect the settled face. This grid has captions between cards, so
			# sibling-based deal staggering is longer than in the real offer row.
			card.set("_dealt", true)
			card.set("_deal", 1.0)
			card.set("_deal_delay", 0.0)
			card.set("_tilt", Vector2.ZERO)
			card.set("_tilt_vel", Vector2.ZERO)
			card.modulate.a = 1.0
			var caption := AugmentFacets.display_name(id, StringName(entry["facet"])) if entry.has("facet") else String(entry["id"]).trim_prefix("augment_").trim_prefix("duo_")
			_label(_layer, origin + Vector2(-10, 385), Vector2(270, 24), caption, 16)
		await _settle()
		await _shot("godot_%s_%02d" % [group, page])


func _chooser(id: StringName, slug: String) -> void:
	await _clear_layer()
	Global.attempt_augment_facets = {}
	Global.attempt_augment_transcended = {}
	Global.attempt_augment_levels = {String(id): 3}
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_background(_layer)
	var screen := SELECT_SCENE.instantiate() as CanvasLayer
	_layer.add_child(screen)
	screen.visible = true
	var entry := {"kind": AugmentBinding.KIND_FACET, "id": String(id), "grade": -1}
	# Only presentation methods: no offer generation, selection, or commit.
	screen.call("_spawn_cards", [entry])
	var cards := screen.get_node("Center/VBox/CardsPanel/CardsMargin/Cards")
	if cards.get_child_count() != 1:
		_fail("Facet chooser failed to create its actual card: " + slug, false)
		return
	# An existing desktop cursor must not cover the chooser with a hover tip.
	var card := cards.get_child(0)
	card.disconnect("hovered", Callable(screen, "_on_card_hovered"))
	screen.call("_open_facet_chooser", Global.augment_db[id], cards.get_child(0), entry)
	await _settle()
	screen.call("_hide_tooltip")
	await _shot("godot_facet_chooser_" + slug)


func _settle() -> void:
	# Allow deal stagger, perspective springs, and the real glaze to settle.
	await get_tree().create_timer(3.0, true, false, true).timeout
	for _frame in range(3):
		await get_tree().process_frame


func _clear_layer() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
	await get_tree().process_frame


func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1280, 960):
		_fail("Unexpected viewport capture dimensions: " + str(image.get_size()), false)
		return
	var path := _out.path_join(filename + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("Cannot save capture: " + path + " / " + error_string(error), false)
	else:
		print("AugmentArtGallery -> ", path)


func _background(parent: Control) -> void:
	var background := ColorRect.new()
	background.color = Color("1c1917")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(background)


func _label(parent: Control, origin: Vector2, dimensions: Vector2, text: String, font_size: int) -> void:
	var label := Label.new()
	label.position = origin
	label.size = dimensions
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ebe0c5"))
	parent.add_child(label)


func _fail(message: String, finish_now := true) -> void:
	_failed = true
	push_error("AugmentArtGallery: " + message)
	if finish_now:
		_finish()


func _finish() -> void:
	for field: String in _saved_memory:
		Global.set(field, _saved_memory[field])
	# Keep autosaves disabled through process teardown; no persistent state was
	# opened or changed. Never call Global.request_quit() or SaveManager APIs.
	if not _saved_memory.is_empty() and SaveManager.debug_save_writes != _save_writes_before:
		_failed = true
		push_error("AugmentArtGallery: unexpected save write")
	get_tree().quit(1 if _failed else 0)
