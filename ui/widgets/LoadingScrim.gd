extends CanvasLayer
class_name LoadingScrim
## Destination and explicit wait cue for scene changes. Global.goto_scene
## lets the card render before the synchronous scene build, then the card
## lifts itself after the new scene has rendered. The spinner advances while
## frames are available; scene construction itself can block those frames.
## Reduced Motion retains the same loading label and a static gold mark.

const FADE_SECONDS := 0.35
const HOLD_FRAMES := 2
## The front end's title face (docs/design/2026-10-02-front-end-arcane-register.md).
const TITLE_FONT := preload("res://assets/fonts/cinzel_decorative/CinzelDecorative-Regular.ttf")
const GOLD := Color(0.72, 0.55, 0.33, 0.85)
const SUBTITLE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const SUBTITLE_COLOR := Color(0.82, 0.77, 0.68, 0.92)
const MOTION := preload("res://ui/widgets/ArcaneMotion.gd")
const SPINNER_SPEED := TAU * 0.7

var _scrim: ColorRect = null
var _content: VBoxContainer = null
var _title: Label = null
var _rule: Control = null
var _rule_centre: CenterContainer = null
var _subtitle: Label = null
var _status_gap: Control = null
var _spinner: Control = null
var _armed_scene: Node = null
var _frames_after_change: int = 0
var _fading: bool = false
var _fade_left: float = 0.0


func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.015, 0.012, 1.0)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.add_child(_content)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 40)
	# The colour itself, not a tint: the project theme's parchment Label
	# colour would otherwise be multiplied by it and the card would darken.
	_title.add_theme_color_override("font_color", Color(0.91, 0.85, 0.74, 1.0))
	_content.add_child(_title)
	# A gold rule with a diamond under the destination, as on the menus.
	_rule_centre = CenterContainer.new()
	_content.add_child(_rule_centre)
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.custom_minimum_size = Vector2(360, 14)
	_rule.draw.connect(_draw_rule)
	_rule_centre.add_child(_rule)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var italic := SUBTITLE_THEME.get_font(&"font", &"ArcaneItalic") if SUBTITLE_THEME != null else null
	if italic != null:
		_subtitle.add_theme_font_override("font", italic)
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle.visible = false
	_content.add_child(_subtitle)
	_status_gap = Control.new()
	_status_gap.custom_minimum_size.y = 8.0
	_content.add_child(_status_gap)
	var status_centre := CenterContainer.new()
	_content.add_child(status_centre)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 12)
	status_centre.add_child(status)
	_spinner = Control.new()
	_spinner.name = "Spinner"
	_spinner.custom_minimum_size = Vector2(32, 32)
	_spinner.pivot_offset = Vector2(16, 16)
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner.draw.connect(_draw_spinner)
	status.add_child(_spinner)
	var loading_label := Label.new()
	loading_label.name = "LoadingLabel"
	loading_label.text = "Loading…"
	loading_label.theme = SUBTITLE_THEME
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 22)
	loading_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	status.add_child(loading_label)
	_scrim.resized.connect(_layout_card)
	_content.resized.connect(_centre_content)
	_content.minimum_size_changed.connect(_fit_content_height)
	visible = false
	set_process(false)


## Shows the card at once; `title` names where the player is going.
func show_for(title: String, current_scene: Node) -> void:
	_title.text = title
	_title.visible = title != ""
	_rule_centre.visible = title != ""
	_status_gap.visible = title != ""
	var subtitle := StoryDirector.loading_subtitle(title)
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_layout_card()
	_spinner.rotation = 0.0
	_scrim.modulate.a = 1.0
	_armed_scene = current_scene
	_frames_after_change = 0
	_fading = false
	visible = true
	set_process(true)


func is_showing() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_spinner.rotation = 0.0 if MOTION.reduced() else fposmod(_spinner.rotation + delta * SPINNER_SPEED, TAU)
	var tree := get_tree()
	if tree == null:
		return
	if _fading:
		_fade_left -= delta
		_scrim.modulate.a = clampf(_fade_left / FADE_SECONDS, 0.0, 1.0)
		if _fade_left <= 0.0:
			visible = false
			set_process(false)
		return
	# Wait for the new scene to exist and render a couple of frames, so the
	# card covers the build stall and the first uninitialised frames.
	if tree.current_scene == null or tree.current_scene == _armed_scene:
		return
	_frames_after_change += 1
	if _frames_after_change >= HOLD_FRAMES:
		_fading = true
		_fade_left = FADE_SECONDS


func _layout_card() -> void:
	var width := maxf(1.0, minf(880.0, _scrim.size.x - 48.0))
	_title.add_theme_font_size_override("font_size", 32 if width < 600.0 else 40)
	_rule.custom_minimum_size.x = minf(360.0, width)
	_rule.queue_redraw()
	_content.custom_minimum_size.x = width
	_content.size = Vector2(width, _content.get_combined_minimum_size().y)
	_content.queue_sort()
	_centre_content()


func _fit_content_height() -> void:
	# Wrapped labels settle after the container has assigned their width.
	_content.size.y = _content.get_combined_minimum_size().y
	_centre_content()


func _centre_content() -> void:
	_content.position = (_scrim.size - _content.size) * 0.5


func _draw_spinner() -> void:
	var centre := Vector2(16, 16)
	_spinner.draw_arc(centre, 12.0, 0.0, TAU, 40, Color(GOLD, 0.2), 1.0, true)
	_spinner.draw_arc(centre, 12.0, -PI * 0.5, PI * 0.8, 32, GOLD, 2.0, true)
	var r := 3.0
	_spinner.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)]), GOLD)


func _draw_rule() -> void:
	var w := _rule.size.x
	var y := 7.5
	for i in range(24):
		var a := float(i) / 24.0
		var b := float(i + 1) / 24.0
		if b > 0.47 and a < 0.53:
			continue
		var fade := clampf(minf(a, 1.0 - b) * 5.0, 0.0, 1.0)
		_rule.draw_line(Vector2(w * a, y), Vector2(w * b, y), Color(GOLD, GOLD.a * fade), 1.0, true)
	var c := Vector2(w * 0.5, y)
	var r := 4.0
	_rule.draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), GOLD, 1.2, true)
