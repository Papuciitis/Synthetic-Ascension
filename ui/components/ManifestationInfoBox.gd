extends VBoxContainer
class_name ManifestationInfoBox

## One Manifestation entry on the Run Sheet, with the full rule on hover.
##
## The panel trims each rule to two lines and ellipsis, because eight untrimmed
## paragraphs push it off the bottom of a 1080p screen - but that left the
## player unable to read, anywhere in the run, what a rule they are wearing
## actually does. The item tooltip has the full text and requires finding the
## item; this is the list they are already looking at.
##
## Godot's default tooltip is a single unwrapped line, which for a paragraph is
## a strip wider than the screen. _make_custom_tooltip is the supported way to
## replace it, so the tooltip gets the same name, nouns and wrapped body the
## entry itself is showing a truncated version of.

const TOOLTIP_MAX_WIDTH: float = 420.0

var info_title: String = ""
var info_nouns: String = ""
var info_body: String = ""
var accent: Color = Color(1, 1, 1, 1)


func setup(title: String, nouns: String, body: String, colour: Color) -> void:
	info_title = title
	info_nouns = nouns
	info_body = body
	accent = colour
	# Godot only asks for a custom tooltip when tooltip_text is non-empty; the
	# text itself is never displayed because _make_custom_tooltip replaces it.
	tooltip_text = body if body.strip_edges() != "" else title
	mouse_filter = Control.MOUSE_FILTER_STOP


func _make_custom_tooltip(_for_text: String) -> Object:
	# The archive's own card: near-black, a rule in the rule's noun colour,
	# square corners; the name in Cinzel, the nouns in italic, the rule in
	# Garamond. Built per hover, as Godot asks for it.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.026, 0.023, 0.97)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size.x = TOOLTIP_MAX_WIDTH
	panel.add_child(column)

	var heading := Label.new()
	heading.text = info_title
	heading.theme_type_variation = &"InstitutionalHeading"
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.15))
	column.add_child(heading)

	if info_nouns.strip_edges() != "":
		var nouns := Label.new()
		nouns.text = info_nouns
		nouns.theme_type_variation = &"HudItalic"
		nouns.add_theme_font_size_override("font_size", 15)
		column.add_child(nouns)

	var body := Label.new()
	body.text = info_body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = TOOLTIP_MAX_WIDTH
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.88, 0.83, 0.74, 1))
	column.add_child(body)

	return panel
