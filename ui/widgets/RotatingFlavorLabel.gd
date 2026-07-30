extends Label
class_name RotatingFlavorLabel

@export_file("*.txt") var lines_path: String = "res://ui/data/respite_flavor_lines.txt"
@export_range(3.0, 30.0, 0.5) var interval_seconds: float = 8.0
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.35

var _lines: Array[String] = []
var _index: int = -1
var _elapsed: float = 0.0
var _transitioning: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_lines()
	_show_next()


func _process(delta: float) -> void:
	if _lines.size() <= 1 or _transitioning:
		return
	_elapsed += delta
	if _elapsed >= interval_seconds:
		_elapsed = 0.0
		_transition_to_next()


func _load_lines() -> void:
	_lines.clear()
	if not FileAccess.file_exists(lines_path):
		_lines.append("The lamps stay low while the survivors count what remains.")
		return
	var raw: String = FileAccess.get_file_as_string(lines_path)
	for raw_line: String in raw.split("\n", false):
		var line: String = raw_line.strip_edges()
		if line != "" and not line.begins_with("#"):
			_lines.append(line)
	if _lines.is_empty():
		_lines.append("The lamps stay low while the survivors count what remains.")


func _show_next() -> void:
	_index = (_index + 1) % _lines.size()
	text = _lines[_index]


func _transition_to_next() -> void:
	_transitioning = true
	var fade_out: Tween = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, fade_seconds)
	await fade_out.finished
	_show_next()
	var fade_in: Tween = create_tween()
	fade_in.tween_property(self, "modulate:a", 0.68, fade_seconds)
	await fade_in.finished
	_transitioning = false
