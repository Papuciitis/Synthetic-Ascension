extends PrimaryObjective
class_name DistrictRelayObjective

## RECON — attune the relay's outlying nodes.
##
## The original objective, and still the gentlest: the sites are visible from
## the centre, the dwell is short, and nothing punishes you for taking them in
## any order. It is the district teaching you what a primary objective looks
## like before the harder templates ask anything of you.

@export var component_count: int = 3
@export var component_orbit_px: float = 250.0
@export var attune_radius_px: float = 96.0
@export var attune_time_sec: float = 1.10

var _component_positions: Array[Vector2] = []
var _component_progress: PackedFloat32Array = PackedFloat32Array()
var _component_silenced: PackedByteArray = PackedByteArray()


func is_layout_built() -> bool:
	return not _component_positions.is_empty()


func build_layout(rng_source: RandomNumberGenerator) -> void:
	var start_angle: float = rng_source.randf_range(-PI, PI)
	_component_positions.clear()
	_component_progress.resize(maxi(1, component_count))
	_component_silenced.resize(maxi(1, component_count))
	for index in range(maxi(1, component_count)):
		var angle := start_angle + TAU * float(index) / float(maxi(1, component_count))
		var radius := component_orbit_px + rng_source.randf_range(-24.0, 24.0)
		_component_positions.append(Vector2.RIGHT.rotated(angle) * radius)
		_component_progress[index] = 0.0
		_component_silenced[index] = 0


func tick_active(delta: float) -> void:
	var changed: bool = false
	for index in range(_component_positions.size()):
		if _component_silenced[index] != 0:
			continue
		var component_world := global_position + _component_positions[index]
		if player.global_position.distance_squared_to(component_world) > attune_radius_px * attune_radius_px:
			continue
		_component_progress[index] = minf(attune_time_sec, _component_progress[index] + delta)
		changed = true
		if _component_progress[index] >= attune_time_sec:
			_component_silenced[index] = 1
			report_progress()

	if changed:
		queue_redraw()
	if steps_done() >= steps_total():
		finish()


func steps_done() -> int:
	var count: int = 0
	for state in _component_silenced:
		if state != 0:
			count += 1
	return count


func steps_total() -> int:
	return _component_positions.size()


func objective_title() -> String:
	return "Silence the District Relay"


func objective_detail() -> String:
	return "Attune relay nodes %d/%d • The exit remains hidden" % [steps_done(), steps_total()]


func checklist_label() -> String:
	return "District Relay silenced"


func checklist_id() -> StringName:
	return &"relay"


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(pulse_time * 3.0)
	var core_color := Color(0.20, 0.92, 0.94, 0.90) if is_finished() else Color(0.86, 0.28, 0.88, 0.92)
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

	var label := "DISTRICT RELAY SILENCED" if is_finished() else "SILENCE DISTRICT RELAY"
	draw_string(ThemeDB.fallback_font, Vector2(-190.0, -105.0), label, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 24, core_color)
