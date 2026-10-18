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
var _site_art: Array[Sprite2D] = []


func build_presentation() -> void:
	objective_art = WorldArt.install(self, "relay", 122.0)
	for index in range(_component_positions.size()):
		_site_art.append(WorldArt.install(self, "relay", 83.0, _component_positions[index], "RelaySite%d" % index))
	update_presentation()


func update_presentation() -> void:
	if objective_art != null:
		objective_art.call("set_state", "complete" if is_finished() else "dormant")
	for index in range(_site_art.size()):
		var fraction := clampf(_component_progress[index] / maxf(0.001, attune_time_sec), 0.0, 1.0)
		_site_art[index].call("set_state", "complete" if _component_silenced[index] != 0 else ("working" if fraction > 0.0 else "dormant"), fraction)


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
	var done := is_finished()
	var color := Color(0.48, 0.94, 0.81, 0.95) if done else Color(0.84, 0.72, 0.96, 0.94)
	for index in range(_component_positions.size()):
		var at := _component_positions[index]
		var silenced := _component_silenced[index] != 0
		var site_color := Color(0.38, 0.9, 0.73, 0.85) if silenced else Color(0.9, 0.72, 0.4, 0.85)
		draw_line(Vector2.ZERO, at, Color(0.07, 0.05, 0.035, 0.7), 4.0, true)
		draw_dashed_line(Vector2.ZERO, at, Color(site_color.r, site_color.g, site_color.b, 0.24), 1.5, 10.0, true, true)
		var progress := clampf(_component_progress[index] / maxf(0.001, attune_time_sec), 0.0, 1.0)
		WorldArt.draw_boundary(self, at, attune_radius_px, site_color, progress if not silenced else -1.0)
		if silenced:
			WorldArt.draw_complete(self, at + Vector2(0, 23), 12.0)
	draw_completion(Vector2(0, 25), 82.0)
	var label := "DISTRICT RELAY SILENCED" if done else "SILENCE DISTRICT RELAY"
	draw_string_outline(ThemeDB.fallback_font, Vector2(-220.0, -118.0), label, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 22, 5, Color(0.025, 0.02, 0.03, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(-220.0, -118.0), label, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 22, color)
