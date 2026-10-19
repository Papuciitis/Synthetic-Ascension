extends Node
## Native hardware cursors stay above busy effects without a following UI
## layer or input interception. Their static ink edge and warm enamel match
## the arcane menus; UI Scale enlarges the actual cursor and its hotspot.

const CURSORS := {
	Input.CURSOR_ARROW: [preload("res://ui/cursor/arrow.svg"), Vector2(4, 4)],
	Input.CURSOR_POINTING_HAND: [preload("res://ui/cursor/point.svg"), Vector2(14, 4)],
	Input.CURSOR_CROSS: [preload("res://ui/cursor/cross.svg"), Vector2(20, 20)],
}
const BASE_SCALE := 0.65

var _textures: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_scale()
	if SettingsManager != null:
		SettingsManager.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	# Input retains each custom ImageTexture beyond the autoload's lifetime.
	# Release those native cursor references while RenderingServer still exists.
	for shape: int in CURSORS:
		Input.set_custom_mouse_cursor(null, shape)
	_textures.clear()


func _on_settings_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"accessibility" and key == &"ui_scale":
		_apply_scale()


func _apply_scale() -> void:
	var scale_factor := BASE_SCALE
	if SettingsManager != null:
		# Keep the smaller default while retaining accessibility enlargement.
		scale_factor *= maxf(1.0, float(SettingsManager.get_value(&"accessibility", &"ui_scale", 1.0)))
	for shape: int in CURSORS:
		var source := CURSORS[shape][0] as Texture2D
		var image := source.get_image()
		if image == null:
			continue # Keep the operating-system cursor if an asset cannot load.
		if not is_equal_approx(scale_factor, 1.0):
			image.resize(roundi(image.get_width() * scale_factor), roundi(image.get_height() * scale_factor), Image.INTERPOLATE_LANCZOS)
		var texture := ImageTexture.create_from_image(image)
		_textures[shape] = texture
		Input.set_custom_mouse_cursor(texture, shape, (CURSORS[shape][1] as Vector2) * scale_factor)
