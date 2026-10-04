extends CanvasLayer
class_name LoadingScrim
## A black card with the destination's name, drawn for the frames a scene
## change blocks the main thread. The 14 September captures show every
## segment start as a 500-900 ms stall while the game scene builds its
## 1,100-1,750 nodes; nothing to optimise there, so it reads as a transition
## instead of a hitch. Global.goto_scene shows it, lets two frames render,
## changes the scene, and the scrim lifts itself two frames after the new
## scene exists. A segment card names its district under the rule
## (StoryDirector.loading_subtitle), in the menus' Garamond italic.

const FADE_SECONDS := 0.35
const HOLD_FRAMES := 2
## The front end's title face (docs/design/2026-10-02-front-end-arcane-register.md).
const TITLE_FONT := preload("res://assets/fonts/cinzel_decorative/CinzelDecorative-Regular.ttf")
const GOLD := Color(0.72, 0.55, 0.33, 0.85)
const SUBTITLE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const SUBTITLE_COLOR := Color(0.82, 0.77, 0.68, 0.92)

var _scrim: ColorRect = null
var _title: Label = null
var _rule: Control = null
var _subtitle: Label = null
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
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 40)
	# The colour itself, not a tint: the project theme's parchment Label
	# colour would otherwise be multiplied by it and the card would darken.
	_title.add_theme_color_override("font_color", Color(0.91, 0.85, 0.74, 1.0))
	_scrim.add_child(_title)
	# A gold rule with a diamond under the destination, as on the menus.
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.size = Vector2(360, 14)
	_rule.draw.connect(_draw_rule)
	_scrim.add_child(_rule)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var italic := SUBTITLE_THEME.get_font(&"font", &"ArcaneItalic") if SUBTITLE_THEME != null else null
	if italic != null:
		_subtitle.add_theme_font_override("font", italic)
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle.visible = false
	_scrim.add_child(_subtitle)
	visible = false
	set_process(false)


## Shows the card at once; `title` names where the player is going.
func show_for(title: String, current_scene: Node) -> void:
	_title.text = title
	_title.reset_size()
	var centre := _scrim.get_viewport_rect().size * 0.5 if _scrim.is_inside_tree() else Vector2.ZERO
	_title.position = centre - _title.size * 0.5
	_rule.visible = title != ""
	_rule.position = centre + Vector2(-_rule.size.x * 0.5, _title.size.y * 0.5 + 6.0)
	var subtitle := StoryDirector.loading_subtitle(title)
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_subtitle.reset_size()
	_subtitle.position = Vector2(centre.x - _subtitle.size.x * 0.5, _rule.position.y + _rule.size.y + 8.0)
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
