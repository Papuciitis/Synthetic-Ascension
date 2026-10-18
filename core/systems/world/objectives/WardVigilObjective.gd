extends PrimaryObjective
class_name WardVigilObjective

## VIGIL — stand in the circle and hold it while the district answers.
##
## The relay asks you to visit three places. This asks you to refuse to leave
## one, which is the opposite decision and the only primary objective that is a
## fight rather than a route. It is deliberately the Exit Rite's shape used
## early: the player learns the verb here, cheaply, so the Rite at the end of
## the segment is a skill they already have rather than a surprise.
##
## Stepping out DRAINS rather than voids, for the same reason the Rite does -
## zeroing on exit makes the only correct play "stand still and pray", which is
## a dare with no counterplay. Dodging out is a real option that costs real
## progress.

@export var vigil_seconds: float = 26.0
@export var vigil_radius_px: float = 190.0
@export var lapse_drain_rate: float = 0.5
@export var lapse_grace: float = 1.2

## Waves across the whole vigil, escalating, so each one arrives, is fought, and
## is followed by another. Spread out rather than stacked at the end: that is
## the difference between a siege and a jump scare.
const WAVE_STAGES: Array[Vector2] = [
	Vector2(0.06, 3.0),
	Vector2(0.22, 4.0),
	Vector2(0.40, 5.0),
	Vector2(0.58, 6.0),
	Vector2(0.76, 8.0),
	Vector2(0.90, 10.0),
]

var _held: float = 0.0
var _lapse: float = 0.0
var _wave: int = 0
var _reported_tenth: int = -1
var _inside: bool = false
var _sigil_phase: float = 0.0
var _braces: VigilBraces


## Ground machinery changes shape without an animation clock: closed inward
## jaws while held, separated jaws in grace and dropped/disconnected on drain.
class VigilBraces extends Node2D:
	var phase := ""

	func set_phase(next_phase: String) -> void:
		if phase == next_phase:
			return
		phase = next_phase
		queue_redraw()

	func _draw() -> void:
		var engaged := phase == "holding" or phase == "complete"
		var draining := phase == "draining"
		var reach := 27.0 if engaged else 39.0
		var dropped := 10.0 if draining else 0.0
		var metal := Color(0.55, 0.56, 0.48, 0.95)
		for side in [-1.0, 1.0]:
			var at := Vector2(side * reach, 7.0 + dropped)
			draw_rect(Rect2(at - Vector2(7.0, 17.0), Vector2(14.0, 34.0)), Color(0.17, 0.19, 0.18, 0.95))
			for end in [-1.0, 1.0]:
				var jaw := at + Vector2(-side * 7.0, end * 13.0)
				draw_line(jaw + Vector2(side * 12.0, 0), jaw + Vector2(-side * 6.0, 0), metal, 5.0, true)
			if draining:
				# A separated downward tab supplements the receding boundary cue.
				draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 24), at + Vector2(5, 24), at + Vector2(0, 31)]), metal)
		if phase == "complete":
			draw_rect(Rect2(-22.0, 3.0, 44.0, 10.0), metal)
			draw_line(Vector2(-14.0, 8.0), Vector2(14.0, 8.0), Color(0.23, 0.26, 0.23), 3.0, true)
		elif phase == "grace":
			# The held charge is paused, not yet bleeding: two horizontal stops.
			draw_line(Vector2(-10.0, 19.0), Vector2(-2.0, 19.0), metal, 3.0, true)
			draw_line(Vector2(2.0, 19.0), Vector2(10.0, 19.0), metal, 3.0, true)


func build_presentation() -> void:
	objective_art = WorldArt.install(self, "vigil", 105.0)
	_braces = VigilBraces.new()
	_braces.name = "VigilBraces"
	_braces.z_as_relative = false
	_braces.z_index = -1
	add_child(_braces)
	update_presentation()


func update_presentation() -> void:
	var draining := _presentation_draining()
	if objective_art != null:
		objective_art.call("set_state", "complete" if is_finished() else ("draining" if draining else ("working" if _inside else "dormant")), progress_fraction())
	if _braces != null:
		_braces.set_phase("complete" if is_finished() else ("draining" if draining else ("holding" if _inside else ("grace" if _held > 0.0 else "dormant"))))


func _presentation_draining() -> bool:
	# Corpse decay bypasses the living exit-grace clock. Observe that existing
	# rule rather than displaying a grace countdown while hold is being lost.
	var dead := player != null and is_instance_valid(player) and bool(player.get("is_dead"))
	return not is_finished() and _held > 0.0 and (is_draining() or dead)


func build_layout(rng_source: RandomNumberGenerator) -> void:
	# Nothing to place - the objective IS this spot. The seed only shifts the
	# sigil so two vigils do not look identical.
	#
	# Deliberately NOT node rotation: _draw() renders the label too, so rotating
	# the node prints "HOLD THE WARD VIGIL" upside down.
	_sigil_phase = rng_source.randf_range(-PI, PI)


func on_activated() -> void:
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit(
			"The ward answers only while you stand in it. Hold for %ds." % int(round(vigil_seconds)),
			4.0
		)


func tick_active(delta: float) -> void:
	_inside = player.global_position.distance_squared_to(global_position) <= vigil_radius_px * vigil_radius_px
	if _inside:
		_lapse = 0.0
		_held = minf(vigil_seconds, _held + delta)
		_maybe_spawn_wave()
	elif _held > 0.0:
		_lapse += delta
		if _lapse > lapse_grace:
			_held = maxf(0.0, _held - delta * lapse_drain_rate)

	# Report in tenths rather than every frame: progress_changed drives a HUD
	# repaint and a checklist emit, and 60 of those a second is a lot of nothing.
	var tenth: int = int(floor(progress_fraction() * 10.0))
	if tenth != _reported_tenth:
		_reported_tenth = tenth
		report_progress()
	queue_redraw()

	if _held >= vigil_seconds:
		finish()


## The vigil bleeds while you are away, so a corpse must not hold the ground.
func on_player_dead(delta: float) -> void:
	_inside = false
	_held = maxf(0.0, _held - delta * lapse_drain_rate)


func _maybe_spawn_wave() -> void:
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner == null or not spawner.has_method("spawn_burst"):
		return
	var fraction := progress_fraction()
	while _wave < WAVE_STAGES.size():
		var stage: Vector2 = WAVE_STAGES[_wave]
		if fraction < stage.x:
			return
		_wave += 1
		spawner.call("spawn_burst", int(stage.y))
		return


func progress_fraction() -> float:
	return clampf(_held / maxf(0.001, vigil_seconds), 0.0, 1.0)


func is_draining() -> bool:
	return not _inside and _held > 0.0 and _lapse > lapse_grace


func steps_done() -> int:
	return int(round(progress_fraction() * float(steps_total())))


## Tenths, matching how often report_progress() actually fires. This used to
## claim a 26-step scale while only ever emitting every second or third value.
func steps_total() -> int:
	return 10


func objective_title() -> String:
	return "Hold the Ward Vigil"


func objective_detail() -> String:
	if is_finished():
		return "The vigil holds"
	var remaining: int = int(ceil(maxf(0.0, vigil_seconds - _held)))
	if is_draining():
		return "THE VIGIL IS BLEEDING • return to the circle (%ds left)" % remaining
	if _inside:
		return "Holding • %ds remaining • The exit remains hidden" % remaining
	return "Stand in the ward circle and hold it • The exit remains hidden"


func checklist_label() -> String:
	return "Ward Vigil held"


func checklist_id() -> StringName:
	return &"vigil"


func _draw() -> void:
	var done := is_finished()
	var draining := _presentation_draining()
	var core := Color(0.5, 0.65, 0.57, 0.5) if done else Color(0.59, 0.68, 0.7, 0.76)
	if draining:
		core = Color(0.8, 0.54, 0.4, 0.78)
	WorldArt.draw_boundary(self, Vector2.ZERO, vigil_radius_px, core)
	var fraction := progress_fraction()
	if not done and fraction > 0.0:
		var progress_color := Color(0.83, 0.56, 0.4, 0.82) if draining else Color(0.79, 0.74, 0.54, 0.82 if _inside else 0.53)
		var end_angle := -PI * 0.5 + TAU * fraction
		draw_arc(Vector2.ZERO, vigil_radius_px - 9.0, -PI * 0.5, end_angle, 96, Color(0.025, 0.03, 0.025, 0.65), 5.0, true)
		draw_arc(Vector2.ZERO, vigil_radius_px - 9.0, -PI * 0.5, end_angle, 96, progress_color, 2.5, true)
		if draining:
			var tip := Vector2.from_angle(end_angle) * (vigil_radius_px - 9.0)
			var tangent := Vector2.from_angle(end_angle - PI * 0.5)
			var normal := tangent.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip + tangent * 6.0, tip - tangent * 4.0 + normal * 4.0, tip - tangent * 4.0 - normal * 4.0]), progress_color)
	for index in range(6):
		var direction := Vector2.from_angle(_sigil_phase + TAU * float(index) / 6.0)
		var tip := direction * (vigil_radius_px - 22.0 if not draining else vigil_radius_px - 9.0)
		var back := direction * (vigil_radius_px - 10.0 if not draining else vigil_radius_px - 24.0)
		draw_polyline(PackedVector2Array([back + direction.orthogonal() * 5.0, tip, back - direction.orthogonal() * 5.0]), core, 2.0, true)
	if done:
		WorldArt.draw_complete(self, Vector2(0, 34), 10.0)
	var label := "HOLD THE WARD VIGIL"
	if done:
		label = "VIGIL HELD"
	elif draining:
		label = "VIGIL DRAINING • RETURN"
	elif _inside:
		label = "HOLD • %ds" % int(ceil(vigil_seconds - _held))
	elif _held > 0.0:
		label = "RETURN • %.1fs GRACE" % maxf(0.0, lapse_grace - _lapse)
	var at := Vector2(-190.0, -vigil_radius_px - 19.0)
	draw_string_outline(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 18, 4, Color(0.025, 0.02, 0.03, 0.9))
	draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 18, Color(core.r, core.g, core.b, 0.92))
