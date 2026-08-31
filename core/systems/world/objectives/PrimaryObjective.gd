extends Node2D
class_name PrimaryObjective

## Base class for a segment's primary objective.
##
## There was exactly one procedural objective - the District Relay - and its
## identity was split in half: the node owned the behaviour while
## SegmentProcBuilder hardcoded the wording, the completion resonance and the
## checklist row. That made a second objective type a rewrite of the builder
## rather than a new file, which is why for a long time there was only ever one.
##
## An objective now owns everything about itself: where its sites are, what the
## player has to do at them, what the HUD calls it, and what the Exit Rite
## checklist says once it is done. The builder only asks.
##
## THE CONTRACT IS THREE SIGNALS, and every subclass drives them the same way:
##   activated        - the player got close enough for this to become real
##   progress_changed - a step was taken (done, total)
##   completed        - the last step was taken
##
## Subclasses override the small surface at the bottom of this file. Everything
## above it - player tracking, the activation ring, spawn sockets, the dead
## player guard, the objective marker - is shared, because every one of those
## was a bug fixed once in the relay that a second objective would otherwise
## have had to rediscover.

signal activated
signal progress_changed(done: int, total: int)
signal completed

## How close the player has to get before the objective wakes up. Deliberately
## large: the objective announcing itself IS the "the objective is that way"
## signal the route readability section asks for.
@export var activation_radius_px: float = 720.0

## Enemy spawn sockets ringed around the site, so pressure arrives from the
## objective rather than from wherever the player happened to walk in from.
@export var socket_count: int = 8
@export var socket_radius_px: float = 500.0

## Shared 30 Hz wall-clock bucket for idle repaints, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter in the world lands on
## the same frames rather than drifting out of phase with the others.
const PULSE_REDRAW_MS: int = 33

## How far past its own activation ring - the widest thing any subclass draws -
## an objective still repaints while idle. Half of a 1920x1080 viewport's
## diagonal is ~1101 px, and HitFeel's camera punch is capped at 18 px, so this
## margin keeps every visible pixel painted.
const IDLE_DRAW_MARGIN_PX: float = 1200.0

var player: Node2D = null
var seed_value: int = 0
var pulse_time: float = 0.0

var _activated: bool = false
var _finished: bool = false
var _last_pulse_bucket: int = -1


func configure(new_seed: int) -> void:
	seed_value = new_seed
	build_layout(_rng())


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else 87139
	return rng


func _ready() -> void:
	add_to_group(&"primary_objective")
	# Set here rather than in a scene file: objectives are instantiated from the
	# catalog as scripts, so a .tscn per type would be six lines of boilerplate
	# whose only job is to carry this number.
	z_index = 35
	if not is_layout_built():
		build_layout(_rng())
	_build_spawn_sockets()
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	if Global != null and Global.objective_target_pos == global_position:
		Global.objective_target_pos = Vector2.INF


func _build_spawn_sockets() -> void:
	for index in range(maxi(0, socket_count)):
		var socket := Marker2D.new()
		socket.name = "ObjectiveSpawnSocket%02d" % index
		socket.position = Vector2.RIGHT.rotated(TAU * float(index) / float(maxi(1, socket_count))) * socket_radius_px
		socket.add_to_group(&"enemy_spawn_socket")
		socket.add_to_group(&"objective_spawn_socket")
		socket.set_meta("spawn_socket_kind", &"objective")
		add_child(socket)


func is_activated() -> bool:
	return _activated


func is_finished() -> bool:
	return _finished


func _process(delta: float) -> void:
	pulse_time += delta
	if _finished:
		tick_finished(delta)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return

	# Reconstruction keeps the player node in the world until the modal closes,
	# so without this an objective keeps making progress underneath a corpse.
	#
	# Gated on _activated: this used to run before the activation check, so an
	# objective the player had never reached still ticked - and a Breach Seal
	# four thousand pixels away kept firing waves at their corpse.
	if bool(player.get("is_dead")):
		if _activated:
			on_player_dead(delta)
		queue_redraw()
		return

	if not _activated:
		if player.global_position.distance_squared_to(global_position) > activation_radius_px * activation_radius_px:
			idle_redraw()
			return
		_activated = true
		activated.emit()
		on_activated()

	tick_active(delta)


## Subclasses call this rather than emitting `completed` themselves, so the
## finished latch and the signal can never disagree.
func finish() -> void:
	if _finished:
		return
	_finished = true
	completed.emit()
	queue_redraw()


func report_progress() -> void:
	progress_changed.emit(steps_done(), steps_total())


## The repaint for a state nobody is acting on: the objective is thousands of
## pixels away and only pulse_time is moving, or it is finished and painting a
## static "done" mark. Culls to nothing beyond the range where its own drawing
## can reach the screen, and inside that range repaints on the shared 30 Hz
## bucket instead of every frame. What it paints is unchanged.
func idle_redraw() -> void:
	if player != null and is_instance_valid(player):
		var cull := activation_radius_px + IDLE_DRAW_MARGIN_PX
		if player.global_position.distance_squared_to(global_position) > cull * cull:
			return
	var bucket := int(Time.get_ticks_msec() / PULSE_REDRAW_MS)
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()


# ---------------------------------------------------------------------------
# The subclass surface
# ---------------------------------------------------------------------------

## Place the objective's sites. Called with a seeded RNG so the same segment
## seed always produces the same layout.
func build_layout(_rng_source: RandomNumberGenerator) -> void:
	pass


## Has build_layout() already run? Guards the _ready() fallback for an objective
## added to the tree without configure().
func is_layout_built() -> bool:
	return true


## One frame of the objective while the player is near and alive.
func tick_active(_delta: float) -> void:
	pass


## One frame after completion - usually just the idle visual.
func tick_finished(_delta: float) -> void:
	idle_redraw()


## The player is down. Default is to do nothing, which is the safe answer for
## anything that measures progress.
func on_player_dead(_delta: float) -> void:
	pass


func on_activated() -> void:
	pass


func steps_done() -> int:
	return 0


func steps_total() -> int:
	return 1


## "Silence the District Relay" - the headline, without any phase suffix.
func objective_title() -> String:
	return "Primary Objective"


## "Attune relay nodes 0/3" - what to do right now.
func objective_detail() -> String:
	return "%d/%d" % [steps_done(), steps_total()]


## The row this objective contributes to the Exit Rite checklist once done.
func checklist_label() -> String:
	return "Primary objective complete"


## Stable id for the checklist row.
func checklist_id() -> StringName:
	return &"primary"
