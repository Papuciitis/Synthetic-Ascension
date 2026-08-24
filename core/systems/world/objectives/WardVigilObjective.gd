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


func build_layout(rng_source: RandomNumberGenerator) -> void:
	# Nothing to place - the objective IS this spot. The seed still shifts the
	# sigil so two vigils do not look identical.
	rotation = rng_source.randf_range(-PI, PI)


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


func steps_total() -> int:
	return int(round(vigil_seconds))


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
	var pulse := 0.5 + 0.5 * sin(pulse_time * 2.4)
	var done := is_finished()
	var core := Color(0.20, 0.92, 0.94, 0.90) if done else Color(0.42, 0.72, 1.00, 0.92)
	if is_draining():
		core = Color(0.99, 0.44, 0.30, 0.95)

	draw_circle(Vector2.ZERO, vigil_radius_px, Color(core.r, core.g, core.b, 0.055))
	draw_arc(Vector2.ZERO, vigil_radius_px, 0.0, TAU, 96, Color(core.r, core.g, core.b, 0.55), 5.0, true)
	draw_arc(Vector2.ZERO, activation_radius_px, 0.0, TAU, 96, Color(core.r, core.g, core.b, 0.05), 3.0, true)

	# The progress ring sits outside the circle so the player can read it
	# without looking away from what is walking at them.
	var fraction := 1.0 if done else progress_fraction()
	draw_arc(
		Vector2.ZERO, vigil_radius_px + 13.0,
		-PI * 0.5, -PI * 0.5 + TAU * fraction,
		96, Color(0.98, 0.92, 0.55, 0.98), 10.0, true
	)

	# Spokes: a plain circle on a busy floor reads as one more decal.
	for i in range(6):
		var angle := rotation + pulse_time * 0.25 + TAU * float(i) / 6.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(
			direction * (vigil_radius_px * 0.42),
			direction * (vigil_radius_px * (0.86 + pulse * 0.05)),
			Color(core.r, core.g, core.b, 0.42), 3.0, true
		)
	draw_circle(Vector2.ZERO, 34.0 + pulse * 4.0, Color(core.r, core.g, core.b, 0.20))

	var label := "VIGIL HELD" if done else "HOLD THE WARD VIGIL"
	draw_string(ThemeDB.fallback_font, Vector2(-190.0, -vigil_radius_px - 34.0), label, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 24, core)
