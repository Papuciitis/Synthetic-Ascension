extends CanvasLayer
class_name LoadingScrim
## A black card with the destination's name, drawn for the frames a scene
## change blocks the main thread. The 14 September captures show every
## segment start as a 500-900 ms stall while the game scene builds its
## 1,100-1,750 nodes; nothing to optimise there, so it reads as a transition
## instead of a hitch. Global.goto_scene shows it, lets two frames render,
## changes the scene, and the scrim lifts itself two frames after the new
## scene exists.

const FADE_SECONDS := 0.35
const HOLD_FRAMES := 2

var _scrim: ColorRect = null
var _title: Label = null
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
	_title.add_theme_font_size_override("font_size", 26)
	_title.modulate = Color(0.88, 0.8, 0.62, 1.0)
	_scrim.add_child(_title)
	visible = false
	set_process(false)


## Shows the card at once; `title` names where the player is going.
func show_for(title: String, current_scene: Node) -> void:
	_title.text = title
	_title.reset_size()
	_title.position = -_title.size * 0.5
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
