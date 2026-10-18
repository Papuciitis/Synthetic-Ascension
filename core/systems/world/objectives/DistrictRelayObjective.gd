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
var _site_shutters: Array[RelayShutter] = []


## A broad ground latch reads open/closed in a frozen, desaturated view. It
## observes the real site's banked hold; it has no timer or interaction area.
class RelayShutter extends Node2D:
	var closed := false
	var _progress_bucket := -1

	func set_status(next_closed: bool, progress: float) -> void:
		var bucket := int(clampf(progress, 0.0, 1.0) * 48.0)
		if closed == next_closed and _progress_bucket == bucket:
			return
		closed = next_closed
		_progress_bucket = bucket
		queue_redraw()

	func _draw() -> void:
		var metal := Color(0.43, 0.42, 0.35, 0.95)
		draw_rect(Rect2(-25.0, 1.0, 50.0, 16.0), Color(0.12, 0.13, 0.12, 0.95))
		var separation := 10.0 if closed else 23.0
		for side in [-1.0, 1.0]:
			var center := Vector2(side * separation, 8.0)
			draw_rect(Rect2(center - Vector2(10.0, 6.0), Vector2(20.0, 12.0)), metal)
			draw_line(center + Vector2(-7.0, -3.0), center + Vector2(7.0, -3.0), Color(0.66, 0.63, 0.51, 0.85), 2.0, true)
		if closed:
			draw_line(Vector2(-9.0, 8.0), Vector2(9.0, 8.0), Color(0.16, 0.17, 0.16), 3.0, true)
		elif _progress_bucket > 0:
			# Stored progress stays solid and still after the player leaves.
			draw_line(Vector2(-24.0, 23.0), Vector2(24.0, 23.0), Color(0.05, 0.05, 0.045, 0.85), 5.0, true)
			draw_line(Vector2(-24.0, 23.0), Vector2(-24.0 + float(_progress_bucket), 23.0), Color(0.74, 0.68, 0.47, 0.9), 3.0, true)

func build_presentation() -> void:
	for index in range(_component_positions.size()):
		_site_art.append(WorldArt.install(self, "relay", 83.0, _component_positions[index], "RelaySite%d" % index))
		var shutter := RelayShutter.new()
		shutter.name = "RelayShutter%d" % index
		shutter.position = _component_positions[index]
		shutter.z_as_relative = false
		shutter.z_index = -1
		add_child(shutter)
		_site_shutters.append(shutter)
	update_presentation()


func update_presentation() -> void:
	for index in range(_site_art.size()):
		var fraction := clampf(_component_progress[index] / maxf(0.001, attune_time_sec), 0.0, 1.0)
		var silenced := is_finished() or _component_silenced[index] != 0
		_site_art[index].call("set_state", "complete" if silenced else ("working" if _site_occupied(index) else "dormant"), 1.0 if silenced else fraction)
		_site_shutters[index].position = _component_positions[index] + (_site_art[index].call("feature_offset", "lens") as Vector2) - Vector2(0, 8)
		_site_shutters[index].z_index = _site_art[index].z_index + 1
		_site_shutters[index].set_status(silenced, 1.0 if silenced else fraction)


func _site_occupied(index: int) -> bool:
	return player != null and is_instance_valid(player) and not bool(player.get("is_dead")) and player.global_position.distance_squared_to(global_position + _component_positions[index]) <= attune_radius_px * attune_radius_px


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
	var color := Color(0.57, 0.68, 0.59, 0.82) if done else Color(0.72, 0.68, 0.54, 0.88)
	# A tiny inert junction replaces the misleading fourth receiver. There is
	# no central hold edge; only the three outlying receivers accept a dwell.
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(0, -5), Vector2(9, 0), Vector2(0, 5)]), Color(0.22, 0.24, 0.21, 0.7))
	for index in range(_component_positions.size()):
		var at := _component_positions[index]
		var silenced := done or _component_silenced[index] != 0
		var site_color := Color(0.45, 0.57, 0.48, 0.42) if silenced else Color(0.76, 0.67, 0.44, 0.7)
		WorldArt.draw_boundary(self, at, attune_radius_px, site_color)
		if silenced:
			WorldArt.draw_complete(self, at + Vector2(0, 29), 9.0)
	var label := "RELAY SILENCED" if done else "RELAY • %d/%d" % [steps_done(), steps_total()]
	draw_string_outline(ThemeDB.fallback_font, Vector2(-140.0, -22.0), label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, 4, Color(0.025, 0.02, 0.03, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-140.0, -22.0), label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, color)
