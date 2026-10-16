extends Node

# Catches fallback-font combat text, stale badges after pooled slot reuse,
# icons left on untagged merges, and icons painted over their accompanying
# label. The rendered checks use the actual generated textures and draw path.
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")
const TEXT_SCRIPT := preload("res://core/combat/BattleTextRenderer.gd")
const ICON_SCRIPT_PATH := "res://core/combat/CombatStatusIcons.gd"
const VAMPIRIC_IDS: Array[StringName] = [&"vampiric"]
const SPLITTING_IDS: Array[StringName] = [&"splitting"]

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.debug_disable_autosave = true
	var previous_callouts: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	var previous_numbers: Variant = SettingsManager.get_value(&"accessibility", &"damage_numbers", true)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	SettingsManager.set_value(&"accessibility", &"damage_numbers", true, false)
	var text := TEXT_SCRIPT.new()
	add_child(text)
	text.set_process(false)
	_test_themed_faces(text)
	var supports_icons := _has_icon_argument(text)
	_check(supports_icons, "callouts accept explicit status IDs without inferring their words")
	var has_loader := ResourceLoader.exists(ICON_SCRIPT_PATH)
	_check(has_loader, "generated combat icons have a dedicated five-modifier loader")
	if has_loader:
		_test_icon_resources()
	if supports_icons and has_loader:
		_test_icon_lifecycle(text)
		_test_merge_keys_stay_in_channel(text)
		_test_modifier_lifecycle(text)
		if DisplayServer.get_name() != "headless":
			await _test_rendered_badges()
			await _test_rendered_modifier_colours()
	text.queue_free()
	SettingsManager.set_value(&"accessibility", &"ability_callouts", previous_callouts, false)
	SettingsManager.set_value(&"accessibility", &"damage_numbers", previous_numbers, false)
	print("CombatTextPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _has_icon_argument(text: Node) -> bool:
	for method in text.get_method_list():
		if method.name == &"popup":
			return method.args.size() >= 6
	return false


func _test_themed_faces(text: Node) -> void:
	text.clear()
	text.damage(Vector2(300.0, 200.0), 853.0)
	text.popup(Vector2(600.0, 200.0), "VAMPIRIC", Color.WHITE)
	var number_line: TextLine = text.call("_shaped_line", 0, 15)
	var callout_line: TextLine = text.call("_shaped_line", 1, 15)
	var number_font := HUD_THEME.get_font(&"font", &"HudFigure")
	var callout_font := HUD_THEME.get_font(&"font", &"HudCaption")
	var callout_width := callout_font.get_string_size("VAMPIRIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var number_uses_theme := true
	for glyph in TextServerManager.get_primary_interface().shaped_text_get_glyphs(number_line.get_rid()):
		number_uses_theme = number_uses_theme and glyph.font_rid in number_font.get_rids()
	_check(number_uses_theme, "damage shapes its actual glyphs with the HUD's strong figure face")
	_check(absf(callout_line.get_line_width() - callout_width) < 0.01, "named combat text uses the HUD caption face (%.1f vs %.1f)" % [callout_line.get_line_width(), callout_width])


func _test_icon_resources() -> void:
	var icons := load(ICON_SCRIPT_PATH) as Script
	for id in [&"armoured", &"vampiric", &"shielded", &"splitting", &"fast"]:
		var texture := icons.call("texture", id) as Texture2D
		_check(texture != null and texture.resource_path == "res://assets/textures/ui/combat_status/%s.png" % id, "%s loads its authored badge" % id)
		if texture != null:
			_check(icons.call("texture", id) == texture, "%s reuses the loaded badge" % id)
	_check(icons.call("texture", &"not_a_status") == null, "unknown status IDs omit safely")


func _test_icon_lifecycle(text: Node) -> void:
	text.clear()
	var ids: Array[StringName] = [&"vampiric", &"splitting"]
	text.popup(Vector2(600.0, 200.0), "TWO TELLS", Color.WHITE, 1.0, 33, ids)
	ids.clear()
	_check(text.get("_icon_ids")[0] == [&"vampiric", &"splitting"], "a callout keeps its own modifier IDs when the caller reuses the array")
	text.popup(Vector2(600.0, 200.0), "PLAIN AGAIN", Color.WHITE, 1.0, 33)
	_check(text.get("_icon_ids")[0].is_empty(), "merging an untagged message removes its previous badges")
	text.progress(Vector2(900.0, 200.0), "ONE TELL", 44, Color.WHITE, SPLITTING_IDS)
	text.progress(Vector2(900.0, 200.0), "ANOTHER TELL", 44, Color.WHITE, VAMPIRIC_IDS)
	_check(text.get("_icon_ids")[1] == [&"vampiric"], "progress merges replace their badge metadata with the message")
	text.call("_remove_at", 0)
	_check(text.get("_texts")[0] == "ANOTHER TELL" and text.get("_icon_ids")[0] == [&"vampiric"], "pool compaction keeps each surviving line with its own badge")
	text.clear()
	text.damage(Vector2.ZERO, 853.0)
	_check(text.get("_icon_ids")[0].is_empty(), "damage reusing a callout slot never inherits an icon")
	var number_line: TextLine = text.call("_shaped_line", 0, 15)
	var number_font := HUD_THEME.get_font(&"font", &"HudFigure")
	_check(absf(number_line.get_line_width() - number_font.get_string_size("853", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) < 0.01, "reused text cache changes from caption to figure face")
	text.clear()
	text.popup(Vector2.ZERO, "853", Color.WHITE)
	var caption_line: TextLine = text.call("_shaped_line", 0, 15)
	var caption_font := HUD_THEME.get_font(&"font", &"HudCaption")
	_check(absf(caption_line.get_line_width() - caption_font.get_string_size("853", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) < 0.01, "identical text and size still rebuild the cache when a figure slot becomes a caption")
	text.clear()
	text.popup(Vector2(600.0, 200.0), "LOWER", Color.WHITE, 1.0, 0, VAMPIRIC_IDS)
	text.popup(Vector2(600.0, 200.0), "UPPER", Color.WHITE, 1.0, 0, SPLITTING_IDS)
	for _frame in range(16):
		text.call("_process", 1.0 / 60.0)
	var first: Vector2 = text.drawn_extent(0)
	var second: Vector2 = text.drawn_extent(1)
	_check(first.y <= second.x or second.y <= first.x, "stacked badge callouts reserve enough vertical space to clear each other")


func _test_merge_keys_stay_in_channel(text: Node) -> void:
	var at := Vector2(600.0, 200.0)
	text.clear()
	text.popup(at, "VAMPIRIC", Color.WHITE, 1.0, 77, VAMPIRIC_IDS)
	text.damage(at, 853.0, false, 77)
	_check(text.get("_count") == 2 and text.get("_texts")[0] == "VAMPIRIC", "a damage key cannot overwrite a named callout sharing the same integer")
	var clean_damage := false
	for slot in range(text.get("_count")):
		if text.get("_texts")[slot] == "853":
			clean_damage = text.get("_icon_ids")[slot].is_empty() and text.get("_columns")[slot] == 0
	_check(clean_damage, "that damage stays iconless and outside the callout column")
	text.clear()
	text.damage(at, 853.0, false, 88)
	text.popup(at, "VAMPIRIC", Color.WHITE, 1.0, 88, VAMPIRIC_IDS)
	_check(text.get("_count") == 2 and text.get("_texts")[0] == "853", "a popup key cannot convert an existing damage number into a caption")
	text.clear()
	text.damage(at, 853.0, false, 99)
	text.progress(at, "FEED", 99, Color.WHITE, SPLITTING_IDS)
	_check(text.get("_count") == 2 and text.get("_texts")[0] == "853", "a progress key likewise stays in the named callout channel")


func _capture_badges(ids: Array[StringName], colour: Color = Color.WHITE) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 240)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var text := TEXT_SCRIPT.new()
	viewport.add_child(text)
	text.call("popup", Vector2(320.0, 150.0), "VAMPIRIC", colour, 1.0, 0, ids)
	text.set_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image


func _test_modifier_lifecycle(text: Node) -> void:
	# Reusing a modifier entry for a plain callout or damage must remove the
	# coloured spans; compaction must carry them with the surviving entry.
	var supports_modifiers := text.has_method("modifier_popup")
	_check(supports_modifiers, "modifier announcements accept semantic IDs and retain each name's own colour")
	if not supports_modifiers:
		return
	text.clear()
	var ids: Array[StringName] = [&"armoured", &"vampiric"]
	text.call("modifier_popup", Vector2(320.0, 180.0), ids, 1.15)
	ids.clear()
	text.popup(Vector2(600.0, 180.0), "PLAIN", Color.WHITE)
	text.call("_remove_at", 1)
	_check(text.get("_texts")[0] == "ARMOURED · VAMPIRIC" and text.get("_modifier_ids")[0] == [&"armoured", &"vampiric"], "modifier names keep copied IDs when a caller or another slot is cleared")
	text.popup(Vector2(600.0, 180.0), "PLAIN", Color.WHITE)
	text.call("_remove_at", 0)
	_check(text.get("_texts")[0] == "PLAIN" and text.get("_modifier_ids")[0].is_empty(), "compaction cannot transfer modifier colours into a surviving plain callout")
	text.clear()
	text.call("modifier_popup", Vector2(320.0, 180.0), SPLITTING_IDS, 1.0)
	text.clear()
	text.damage(Vector2(320.0, 180.0), 853.0)
	_check(text.get("_modifier_ids")[0].is_empty(), "a damage number reusing a modifier slot has no coloured spans")
	text.clear()
	text.popup(Vector2.ZERO, "LEFT", Color.WHITE)
	text.call("modifier_popup", Vector2(600.0, 180.0), SPLITTING_IDS, 1.0)
	text.call("_remove_at", 0)
	_check(text.get("_texts")[0] == "SPLITTING" and text.get("_modifier_ids")[0] == [&"splitting"], "compaction retains a moved modifier's own coloured spans")
	text.clear()


func _capture_modifier_text(ids: Array[StringName], words: String, reuse: String = "") -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 240)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var text := TEXT_SCRIPT.new()
	viewport.add_child(text)
	var at := Vector2(320.0, 150.0)
	if text.has_method("modifier_popup"):
		text.call("modifier_popup", at, ids, 1.0)
	else:
		# Exercise today's actual single-tint path for the red regression.
		text.popup(at, words, Color(0.72, 0.78, 0.86), 1.0, 0, ids)
	text.set_process(false)
	if not reuse.is_empty():
		# Build the real modifier glyph cache before its slot is reused.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		text.clear()
		if reuse == "damage":
			text.damage(at + Vector2(0.0, -14.0), 853.0)
		else:
			text.popup(at, words, Color(0.98, 0.96, 0.92))
	text.set_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image


func _pixels_near_colour(image: Image, area: Rect2i, colour: Color, tolerance: float = 0.08) -> int:
	var count := 0
	for y in range(maxi(0, area.position.y), mini(image.get_height(), area.end.y)):
		for x in range(maxi(0, area.position.x), mini(image.get_width(), area.end.x)):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5 and absf(pixel.r - colour.r) < tolerance and absf(pixel.g - colour.g) < tolerance and absf(pixel.b - colour.b) < tolerance:
				count += 1
	return count


func _test_rendered_modifier_colours() -> void:
	# Independent expected labels/tints. Selecting the first modifier's tint
	# for the whole line must fail the red/green/yellow glyph assertions.
	var fixtures := [
		{"ids": [&"armoured", &"vampiric"], "labels": ["ARMOURED", "VAMPIRIC"], "colours": [Color(0.72, 0.78, 0.86), Color(1.0, 0.22, 0.28)]},
		{"ids": [&"shielded", &"splitting", &"fast"], "labels": ["SHIELDED", "SPLITTING", "FAST"], "colours": [Color(0.45, 0.85, 1.0), Color(0.75, 1.0, 0.45), Color(1.0, 0.95, 0.55)]},
	]
	var font := HUD_THEME.get_font(&"font", &"HudCaption")
	var evidence := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var ids: Array[StringName] = []
		ids.assign(fixture.ids)
		var words := " · ".join(fixture.labels)
		var image := await _capture_modifier_text(ids, words)
		evidence.blit_rect(image, Rect2i(0, 0, 640, 240), Vector2i(0, 240 * index))
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var badges := 26.0 * ids.size() + 2.0 * (ids.size() - 1)
		var left := 320.0 - (width + 4.0 + badges) * 0.5 + badges + 4.0
		var separator := font.get_string_size(" · ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		for n in range(fixture.labels.size()):
			var word: String = fixture.labels[n]
			var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var area := Rect2i(int(floor(left)), 94, int(ceil(word_width)), 25)
			var pixels := _pixels_near_colour(image, area, fixture.colours[n])
			_check(pixels >= 8, "%s glyphs retain their own modifier colour in a %d-effect announcement (%d pixels)" % [word, ids.size(), pixels])
			left += word_width
			if n + 1 < fixture.labels.size():
				# At 15px the tiny dot's brightest antialiased pixel reaches
				# (229,225,216), just below the solid ivory fill (250,245,235).
				var neutral := _pixels_near_colour(image, Rect2i(int(floor(left)), 94, int(ceil(separator)), 25), Color(0.98, 0.96, 0.92), 0.12)
				_check(neutral >= 1, "mixed modifier names have a neutral, readable separator")
				left += separator
	var directory := ProjectSettings.globalize_path("res://.godot/modifier-colour-pixels")
	DirAccess.make_dir_recursive_absolute(directory)
	evidence.save_png(directory.path_join("double-triple.png"))
	var single := await _capture_modifier_text(SPLITTING_IDS, "SPLITTING")
	var single_width := font.get_string_size("SPLITTING", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var single_left := 320.0 - (single_width + 30.0) * 0.5 + 30.0
	_check(_pixels_near_colour(single, Rect2i(int(ceil(single_left)), 94, int(ceil(single_width)), 25), Color(0.75, 1.0, 0.45)) >= 8, "a single modifier's glyphs also use its canonical colour, excluding its painted badge")
	var plain := await _capture_modifier_text([&"armoured", &"vampiric"], "ARMOURED · VAMPIRIC", "plain")
	_check(_pixels_near_colour(plain, Rect2i(180, 94, 300, 25), Color(0.98, 0.96, 0.92)) >= 30 and _pixels_near_colour(plain, Rect2i(180, 94, 300, 25), Color(1.0, 0.22, 0.28)) == 0, "a reused plain callout renders uniformly without stale modifier colours")
	var number := await _capture_modifier_text([&"armoured", &"vampiric"], "853", "damage")
	_check(_pixels_near_colour(number, Rect2i(280, 94, 80, 25), Color(0.98, 0.96, 0.92)) >= 8, "a reused damage slot draws normal figure glyphs without stale modifier colours")


func _painted_bounds(image: Image, area: Rect2i) -> Rect2i:
	var first := area.end
	var last := Vector2i(-1, -1)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a > 0.08:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= first.x else Rect2i()


func _test_rendered_badges() -> void:
	var plain := await _capture_badges([])
	var one := await _capture_badges([&"vampiric"])
	var two := await _capture_badges([&"vampiric", &"splitting"])
	var unknown := await _capture_badges([&"not_a_status"])
	var full_area := Rect2i(0, 0, 640, 240)
	var plain_bounds := _painted_bounds(plain, full_area)
	var one_bounds := _painted_bounds(one, full_area)
	var two_bounds := _painted_bounds(two, full_area)
	_check(one_bounds.size.x > plain_bounds.size.x + 12 and two_bounds.size.x > one_bounds.size.x + 12, "one and two generated badges actually paint alongside the label")
	_check(absf(one_bounds.get_center().x - 320.0) <= 4.0 and absf(two_bounds.get_center().x - 320.0) <= 4.0, "badge and text rows stay centred over their actor")
	_check(unknown.get_data() == plain.get_data(), "unknown badges neither paint nor leave a blank gap")
	var coloured := await _capture_badges([&"vampiric"], Color(0.2, 0.8, 0.3))
	var text_width := HUD_THEME.get_font(&"font", &"HudCaption").get_string_size("VAMPIRIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	# The left badge sits outside the centred word, leaving the intervening
	# gap empty. Its authored red/brass pixels cannot inherit green text tint.
	var badge_right := int(floor(320.0 - text_width * 0.5 + 8.0))
	var changed := 0
	var painted := 0
	for y in range(80, 140):
		for x in range(180, badge_right):
			var pixel := one.get_pixel(x, y)
			if pixel.a > 0.08:
				painted += 1
				if pixel != coloured.get_pixel(x, y):
					changed += 1
	_check(painted > 20 and changed == 0, "a status badge keeps its authored colours when its text colour changes")
