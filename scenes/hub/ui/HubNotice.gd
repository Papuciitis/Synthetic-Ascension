extends Node2D
## Passing lines in the square ("a quiet corner", "A decision waits before
## the road."): EB Garamond italic on a pool of shade that fades in, holds,
## drifts up a little and fades out. Lives on HubWorld's label layer, so it
## draws above the player and outside the dusk tint. Runs on real time and
## through a paused tree (a notice can be up when a panel opens over the
## square); under Reduced Motion it only fades.

const HubText := preload("res://scenes/hub/ui/HubText.gd")

const FADE_IN := 0.22
const FADE_OUT := 0.55
const RISE := 16.0

## Each: {"at": Vector2, "text": String, "colour": Color, "age": float, "life": float}.
var notices: Array = []
var _last_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Shows `text` centred on `at` (world space) for `seconds`. A new line at
## the same spot replaces the one already there instead of stacking on it.
func show_line(at: Vector2, text: String, colour: Color, seconds: float = 1.8) -> void:
	for entry in notices:
		if (entry["at"] as Vector2).distance_to(at) < 24.0:
			notices.erase(entry)
			break
	notices.append({"at": at, "text": text, "colour": colour, "age": 0.0, "life": maxf(seconds, FADE_IN + FADE_OUT)})
	_last_usec = Time.get_ticks_usec()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var dt := HubText.since(_last_usec)
	_last_usec = Time.get_ticks_usec()
	for entry in notices.duplicate():
		entry["age"] = float(entry["age"]) + dt
		if float(entry["age"]) >= float(entry["life"]):
			notices.erase(entry)
	if notices.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var still := HubText.reduced()
	for entry in notices:
		var age: float = entry["age"]
		var life: float = entry["life"]
		var alpha := clampf(age / FADE_IN, 0.0, 1.0) * clampf((life - age) / FADE_OUT, 0.0, 1.0)
		var at: Vector2 = entry["at"]
		if not still:
			at.y -= RISE * HubText.ease_out(age / life)
		HubText.draw_notice(self, at, entry["text"], entry["colour"], alpha)
