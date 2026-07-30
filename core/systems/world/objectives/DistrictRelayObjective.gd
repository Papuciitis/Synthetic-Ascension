extends Node2D
class_name DistrictRelayObjective

signal activated
signal progress_changed(silenced: int, total: int)
signal completed

@export var component_count: int = 3
@export var component_orbit_px: float = 250.0
@export var activation_radius_px: float = 720.0
@export var attune_radius_px: float = 96.0
@export var attune_time_sec: float = 1.10

var _player: Node2D = null
var _component_positions: Array[Vector2] = []
var _component_progress: PackedFloat32Array = PackedFloat32Array()
var _component_silenced: PackedByteArray = PackedByteArray()
var _seed: int = 0
var _activated: bool = false
var _finished: bool = false
var _pulse_time: float = 0.0

func configure(seed_value: int) -> void:
	_seed = seed_value
	_build_layout()

func _ready() -> void:
	add_to_group(&"primary_objective")
	if _component_positions.is_empty():
		_build_layout()
	_build_spawn_sockets()
	set_process(true)
	queue_redraw()

func _exit_tree() -> void:
	if Global != null and Global.objective_target_pos == global_position:
		Global.objective_target_pos = Vector2.INF

func _build_layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed if _seed != 0 else 87139
	var start_angle: float = rng.randf_range(-PI, PI)
	_component_positions.clear()
	_component_progress.resize(maxi(1, component_count))
	_component_silenced.resize(maxi(1, component_count))
	for index in range(maxi(1, component_count)):
		var angle := start_angle + TAU * float(index) / float(maxi(1, component_count))
		var radius := component_orbit_px + rng.randf_range(-24.0, 24.0)
		_component_positions.append(Vector2.RIGHT.rotated(angle) * radius)
		_component_progress[index] = 0.0
		_component_silenced[index] = 0

func _build_spawn_sockets() -> void:
	for index in range(8):
		var socket := Marker2D.new()
		socket.name = "ObjectiveSpawnSocket%02d" % index
		socket.position = Vector2.RIGHT.rotated(TAU * float(index) / 8.0) * 500.0
		socket.add_to_group(&"enemy_spawn_socket")
		socket.add_to_group(&"objective_spawn_socket")
		socket.set_meta("spawn_socket_kind", &"objective")
		add_child(socket)

func _process(delta: float) -> void:
	_pulse_time += delta
	if _finished:
		queue_redraw()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		return

	# Reconstruction keeps the player node in the world until the modal closes.
	# Do not let a relay node continue attuning underneath a dead player.
	if bool(_player.get("is_dead")):
		queue_redraw()
		return

	if not _activated and _player.global_position.distance_squared_to(global_position) <= activation_radius_px * activation_radius_px:
		_activated = true
		activated.emit()

	if not _activated:
		queue_redraw()
		return

	var changed: bool = false
	for index in range(_component_positions.size()):
		if _component_silenced[index] != 0:
			continue
		var component_world := global_position + _component_positions[index]
		if _player.global_position.distance_squared_to(component_world) > attune_radius_px * attune_radius_px:
			continue
		_component_progress[index] = minf(attune_time_sec, _component_progress[index] + delta)
		changed = true
		if _component_progress[index] >= attune_time_sec:
			_component_silenced[index] = 1
			progress_changed.emit(_silenced_count(), _component_positions.size())

	if changed:
		queue_redraw()
	if _silenced_count() >= _component_positions.size():
		_finished = true
		completed.emit()
		queue_redraw()

func _silenced_count() -> int:
	var count: int = 0
	for state in _component_silenced:
		if state != 0:
			count += 1
	return count

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 3.0)
	var core_color := Color(0.20, 0.92, 0.94, 0.90) if _finished else Color(0.86, 0.28, 0.88, 0.92)
	draw_circle(Vector2.ZERO, 48.0, Color(core_color.r, core_color.g, core_color.b, 0.20))
	draw_arc(Vector2.ZERO, 72.0 + pulse * 5.0, 0.0, TAU, 72, core_color, 6.0, true)
	draw_arc(Vector2.ZERO, activation_radius_px, 0.0, TAU, 96, Color(core_color.r, core_color.g, core_color.b, 0.055), 3.0, true)

	for index in range(_component_positions.size()):
		var local_pos := _component_positions[index]
		var silenced: bool = _component_silenced[index] != 0
		var node_color := Color(0.20, 0.95, 0.72, 0.96) if silenced else Color(0.98, 0.62, 0.18, 0.96)
		draw_line(Vector2.ZERO, local_pos, Color(core_color.r, core_color.g, core_color.b, 0.24), 4.0, true)
		draw_circle(local_pos, 28.0, Color(node_color.r, node_color.g, node_color.b, 0.20))
		draw_arc(local_pos, 42.0, 0.0, TAU, 48, node_color, 5.0, true)
		if not silenced and attune_time_sec > 0.0:
			var progress := clampf(_component_progress[index] / attune_time_sec, 0.0, 1.0)
			draw_arc(local_pos, 53.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.95, 0.65, 1.0), 8.0, true)

	var label := "DISTRICT RELAY SILENCED" if _finished else "SILENCE DISTRICT RELAY"
	draw_string(ThemeDB.fallback_font, Vector2(-190.0, -105.0), label, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 24, core_color)
