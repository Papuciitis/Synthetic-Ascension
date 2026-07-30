extends Node2D
class_name OpeningSequenceWorld

signal stage_activated(index: int)

var _anchor: Vector2
var _player: Node2D
var _nodes: Array[Vector2] = []
var _stage: int = -1
var _stage_count: int = 0
var _active: bool = false
var _pulse_strength: float = 0.0
var _spin: float = 0.0

func configure(anchor: Vector2, player: Node2D, stage_count: int = 3) -> void:
	_anchor = anchor
	_player = player
	_stage_count = clampi(stage_count, 1, 3)
	global_position = anchor
	_nodes = [Vector2(-82, 32), Vector2(0, -72), Vector2(82, 32)]
	_stage = 0
	_active = true
	queue_redraw()

func _process(delta: float) -> void:
	_spin += delta * (0.45 + _pulse_strength * 2.0)
	_pulse_strength = move_toward(_pulse_strength, 0.0, delta * 0.55)
	queue_redraw()
	if not _active or _player == null or _stage < 0 or _stage >= _stage_count:
		return
	var target := global_position + _nodes[_stage]
	if _player.global_position.distance_squared_to(target) <= 105.0 * 105.0 and Input.is_action_just_pressed(&"ui_accept"):
		var completed := _stage
		_stage += 1
		_pulse_strength = 1.0
		if SfxManager != null:
			SfxManager.play_2d(&"ui_click", target, -1.0)
		stage_activated.emit(completed)
		if _stage >= _stage_count:
			_active = false

func wait_for_next_stage() -> int:
	return await stage_activated

func pulse() -> void:
	_pulse_strength = 2.0
	if SfxManager != null:
		SfxManager.play_2d(&"wardstone_complete", global_position, -2.0)
	await get_tree().create_timer(0.9, true, false, true).timeout

func _draw() -> void:
	var cyan := Color("39d7e8")
	var amber := Color("d69a45")
	for radius in [54.0, 89.0, 126.0]:
		draw_arc(Vector2.ZERO, radius + _pulse_strength * 7.0, _spin, _spin + TAU * 0.78, 72, Color(cyan, 0.35), 2.0, true)
	for spoke in range(6):
		var direction := Vector2.RIGHT.rotated(_spin * -0.5 + float(spoke) * TAU / 6.0)
		draw_line(direction * 34.0, direction * (112.0 + _pulse_strength * 8.0), Color(cyan, 0.20), 1.0, true)
	# A freshly instanced world receives one draw before the controller can call
	# configure(). Clamp to the populated array so that startup draw is harmless.
	var drawable_count: int = mini(_stage_count, _nodes.size())
	for index in range(drawable_count):
		var done := index < _stage
		var current := index == _stage and _active
		var color := cyan if done else amber
		var radius := 15.0 + (sin(_spin * 5.0) * 2.0 if current else 0.0)
		draw_circle(_nodes[index], radius, Color(color, 0.16 if not done else 0.32))
		draw_arc(_nodes[index], radius, 0.0, TAU, 24, Color(color, 1.0 if current else 0.55), 3.0 if current else 2.0, true)
		draw_string(ThemeDB.fallback_font, _nodes[index] + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
