extends Node

## Every primary objective type must be buildable, self-describing, drivable and
## finishable, and an unfinished one must keep the Exit Rite shut.
##
## The catalog picks by seed, so a type that crashes or never completes would
## only surface on the unlucky run that rolled it - which is exactly the class
## of bug that survives playtesting for months.
##
## The three types are driven here the way a player drives them: a stand-in
## player is walked onto the sites, the objective is ticked with a delta the
## test owns, and only OUTCOMES are asserted - activation, step counts, the
## three contract signals, the waves each objective asks the spawner for, and
## the Exit Rite state its completion produces through the real
## SegmentProcBuilder handlers. Nothing here asserts a redraw, a frame count or
## a log line; the objectives' _draw() is deliberately left running so a crash
## in it still surfaces, but nothing about it is measured.

const BUILDER_SCRIPT: Script = preload("res://core/systems/world/SegmentProcBuilder.gd")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")

## Fine enough that no objective's dwell, grace or spawn interval is stepped
## over in a single tick, so the mechanics are measured rather than sampled.
const TICK: float = 0.05


## The objectives read exactly two things off the player: where it is and
## whether it is a corpse. Anything more would be a fixture pretending to be a
## player, and the dead-player guards are the point of half these checks.
class StubPlayer extends Node2D:
	var is_dead: bool = false


## Objectives call spawn_burst() on whatever is in the "enemy_spawner" group.
## Recording the counts is how the waves and the breach pour become assertable
## without a single real enemy.
class StubSpawner extends Node:
	var bursts: Array[int] = []
	## Each breach pour: {"position", "count"}. The stand-in enemies it returns
	## sit in the "enemies" group so the objective's own liveness count can see
	## them - and leave it when a test "kills" them.
	var pours: Array = []

	func spawn_burst(count: int) -> void:
		bursts.append(count)

	func spawn_burst_at(position: Vector2, count: int, _spread_px: float = 0.0) -> Array:
		pours.append({"position": position, "count": count})
		var out: Array = []
		for _i in range(count):
			var enemy := Node2D.new()
			enemy.add_to_group(&"enemies")
			add_child(enemy)
			enemy.global_position = position
			out.append(enemy)
		return out


## The real SegmentProcBuilder minus its world build. _ready() needs a
## ChunkManager, a player and a generated DistrictPlan before it will do
## anything, and the gate wiring under test reads none of them - the signal
## handlers, _update_gate_lock() and _push_objective_ui() are the production
## code, untouched.
class BuilderHarness extends SegmentProcBuilder:
	func _ready() -> void:
		set_process(false)


var _passes: int = 0
var _failures: int = 0

var _tips: Array[String] = []
var _checklists: Array = []
var _objective_ui: Array = []
var _phases: Array = []

var _saved_objective_target: Vector2 = Vector2.INF
var _saved_exit_gate: Vector2 = Vector2.INF
var _saved_tip_gate_hold: bool = false
var _saved_threat_resonance: float = 0.0
var _saved_threat_phase: StringName = &"recon"
var _saved_threat_unsealed: bool = false


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## One frame of the objective, on a clock the test owns. Driving _process()
## directly is what CursedVaultTest does: the alternative is waiting on real
## frames, which would make every timing here a guess.
func _tick(objective: PrimaryObjective, count: int = 1, delta: float = TICK) -> void:
	for _i in range(count):
		objective._process(delta)


## Bounded drive-until, so a broken objective fails the assertion after it
## instead of hanging the suite.
func _tick_until(objective: PrimaryObjective, predicate: Callable, max_ticks: int = 2000, delta: float = TICK) -> int:
	var ticks: int = 0
	while ticks < max_ticks and not bool(predicate.call()):
		objective._process(delta)
		ticks += 1
	return ticks


## The seed the catalog needs to hand back a given type on a procedural segment.
func _seed_for(id: StringName, segment: int) -> int:
	for seed_value in range(4096):
		if PrimaryObjectiveCatalog.pick_id(segment, seed_value) == id:
			return seed_value
	return -1


func _spawn_stub_player(at: Vector2) -> StubPlayer:
	var stub := StubPlayer.new()
	stub.add_to_group(&"player")
	stub.global_position = at
	add_child(stub)
	return stub


func _spawn_stub_spawner() -> StubSpawner:
	var stub := StubSpawner.new()
	stub.add_to_group(&"enemy_spawner")
	add_child(stub)
	return stub


func _install(objective: PrimaryObjective, at: Vector2) -> void:
	objective.global_position = at
	add_child(objective)
	# _ready() turns processing on; the test owns the clock from here.
	objective.set_process(false)


func _release(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _on_checklist(state: StringName, items: Array, hint: String) -> void:
	_checklists.append([state, items.duplicate(true), hint])


func _on_objective_ui(title: String, detail: String) -> void:
	_objective_ui.append([title, detail])


func _on_phase(phase: StringName, _label: String) -> void:
	_phases.append(phase)


func _reset_capture() -> void:
	_tips.clear()
	_checklists.clear()
	_objective_ui.clear()
	_phases.clear()


# ---------------------------------------------------------------------------

func _run() -> void:
	_saved_objective_target = Global.objective_target_pos
	_saved_exit_gate = Global.exit_gate_pos
	_saved_tip_gate_hold = bool(Global.tip_shown_gate_hold)
	_saved_threat_resonance = float(ThreatDirector.resonance)
	_saved_threat_phase = ThreatDirector.segment_phase
	_saved_threat_unsealed = bool(ThreatDirector.gate_unsealed)

	RunEvents.tutorial_tip.connect(_on_tip)
	RunEvents.gate_checklist_changed.connect(_on_checklist)
	RunEvents.objective_changed.connect(_on_objective_ui)
	RunEvents.segment_phase_changed.connect(_on_phase)

	_test_catalog()
	await _test_district_relay()
	await _test_ward_vigil()
	await _test_ward_vigil_wave_gate()
	await _test_breach_seal()
	await _test_rite_gate(&"district_relay", true)
	await _test_rite_gate(&"ward_vigil", false)
	await _test_rite_gate(&"breach_seal", false)

	RunEvents.tutorial_tip.disconnect(_on_tip)
	RunEvents.gate_checklist_changed.disconnect(_on_checklist)
	RunEvents.objective_changed.disconnect(_on_objective_ui)
	RunEvents.segment_phase_changed.disconnect(_on_phase)

	Global.objective_target_pos = _saved_objective_target
	Global.exit_gate_pos = _saved_exit_gate
	Global.tip_shown_gate_hold = _saved_tip_gate_hold
	ThreatDirector.call("reset_run_state")
	ThreatDirector.resonance = _saved_threat_resonance
	ThreatDirector.gate_unsealed = _saved_threat_unsealed
	ThreatDirector.segment_phase = _saved_threat_phase
	ThreatDirector.call("_recompute", true)

	print("PrimaryObjectiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# The catalog: every type is buildable and self-describing
# ---------------------------------------------------------------------------

func _test_catalog() -> void:
	var ids: Array = PrimaryObjectiveCatalog.all_ids()
	_check(ids.size() >= 3, "the catalog offers more than one objective (%d)" % ids.size())

	for id in ids:
		var script := PrimaryObjectiveCatalog.script_for(id)
		_check(script != null, "'%s' resolves to a script" % String(id))
		if script == null:
			continue
		var objective := script.new() as PrimaryObjective
		_check(objective != null, "'%s' is a PrimaryObjective" % String(id))
		if objective == null:
			continue
		objective.configure(4242)

		# describe() runs on a detached node in the HUD path, so it must not
		# depend on being in the tree or on a player existing.
		_check(objective.objective_title().strip_edges() != "", "'%s' has a title" % String(id))
		_check(objective.objective_detail().strip_edges() != "", "'%s' has a detail line" % String(id))
		_check(objective.checklist_label().strip_edges() != "", "'%s' has a checklist row" % String(id))
		_check(objective.checklist_id() != StringName(), "'%s' has a checklist id" % String(id))

		_check(objective.steps_total() >= 1, "'%s' has at least one step" % String(id))
		_check(objective.steps_done() == 0, "'%s' starts at zero progress" % String(id))
		_check(not objective.is_finished(), "'%s' does not start finished" % String(id))
		_check(not objective.is_activated(), "'%s' does not start activated" % String(id))

		# finish() is the only route to `completed`, and it must latch.
		# An Array, not an int: GDScript lambdas capture by VALUE, so a counter
		# incremented inside one only ever moves a copy.
		var fired: Array[int] = [0]
		objective.completed.connect(func() -> void: fired[0] += 1)
		objective.finish()
		objective.finish()
		_check(fired[0] == 1, "'%s' emits completed exactly once (%d)" % [String(id), fired[0]])
		_check(objective.is_finished(), "'%s' latches finished" % String(id))
		objective.free()

	# Checklist ids must be distinct, or two objective types would collide on
	# the same Exit Rite row.
	var seen: Dictionary = {}
	for id in ids:
		var script := PrimaryObjectiveCatalog.script_for(id)
		if script == null:
			continue
		var probe := script.new() as PrimaryObjective
		if probe == null:
			continue
		var key := probe.checklist_id()
		_check(not seen.has(key), "checklist id '%s' is unique" % String(key))
		seen[key] = true
		probe.free()

	# The teaching segment must always be the gentlest template, and later
	# segments must actually vary.
	_check(
		PrimaryObjectiveCatalog.pick_id(2, 111) == &"district_relay"
		and PrimaryObjectiveCatalog.pick_id(2, 999) == &"district_relay",
		"segment 2 always teaches with the relay"
	)
	var picked: Dictionary = {}
	for seed_value in range(400):
		picked[PrimaryObjectiveCatalog.pick_id(6, seed_value)] = true
	_check(
		picked.size() == ids.size(),
		"later segments reach every objective type (%d of %d)" % [picked.size(), ids.size()]
	)
	# Same seed, same district: the plan validator and seed reproduction both
	# assume a seed fully determines a segment.
	_check(
		PrimaryObjectiveCatalog.pick_id(7, 31337) == PrimaryObjectiveCatalog.pick_id(7, 31337),
		"the pick is deterministic"
	)

	# create_for() must hand back the type its own pick_id() promised, already
	# configured - the builder never calls configure() itself.
	for id in ids:
		var segment: int = (2 if id == &"district_relay" else 6)
		var seed_value: int = (11 if id == &"district_relay" else _seed_for(id, 6))
		_check(seed_value >= 0, "a segment-%d seed exists that rolls '%s'" % [segment, String(id)])
		if seed_value < 0:
			continue
		var built := PrimaryObjectiveCatalog.create_for(segment, seed_value)
		_check(built != null, "create_for(%d, %d) builds an objective" % [segment, seed_value])
		if built == null:
			continue
		var reference := PrimaryObjectiveCatalog.script_for(id).new() as PrimaryObjective
		_check(built.checklist_id() == reference.checklist_id(), "create_for(%d, %d) yields the '%s' type" % [segment, seed_value, String(id)])
		reference.free()
		_check(built.is_layout_built(), "create_for returns '%s' with its layout already placed" % String(id))
		_check(built.steps_total() >= 1, "create_for returns '%s' with real steps (%d)" % [String(id), built.steps_total()])
		built.free()


# ---------------------------------------------------------------------------
# RECON - the District Relay: visit three quiet places
# ---------------------------------------------------------------------------

func _test_district_relay() -> void:
	_reset_capture()
	var objective := PrimaryObjectiveCatalog.create_for(2, 24601) as DistrictRelayObjective
	_check(objective != null, "the teaching segment's objective is the District Relay")
	if objective == null:
		return

	# Deliberately not the origin: every site is a LOCAL offset added to
	# global_position, and a local/global mix-up would pass at (0, 0).
	var home := Vector2(5120.0, -3072.0)
	_install(objective, home)
	var spawner := _spawn_stub_spawner()
	var player := _spawn_stub_player(home + Vector2(4000.0, 0.0))

	var activations: Array[int] = [0]
	var completions: Array[int] = [0]
	var reports: Array = []
	objective.activated.connect(func() -> void: activations[0] += 1)
	objective.completed.connect(func() -> void: completions[0] += 1)
	objective.progress_changed.connect(func(done: int, total: int) -> void: reports.append(Vector2i(done, total)))

	_check(objective.steps_total() == objective.component_count, "the relay has one step per node it placed (%d)" % objective.steps_total())

	# Shared base behaviour: the objective rings itself with spawn sockets so
	# pressure arrives from the objective, not from wherever the player walked in.
	var sockets: Array = []
	for child in objective.get_children():
		if child is Marker2D and StringName(child.get_meta("spawn_socket_kind", &"")) == &"objective":
			sockets.append(child)
	_check(sockets.size() == objective.socket_count, "the objective rings itself with %d enemy spawn sockets" % objective.socket_count)
	var ringed: bool = not sockets.is_empty()
	for socket in sockets:
		if absf((socket as Marker2D).position.length() - objective.socket_radius_px) > 0.01:
			ringed = false
		if not (socket as Marker2D).is_in_group(&"enemy_spawn_socket"):
			ringed = false
	_check(ringed, "every socket sits on the objective's socket ring and is registered for spawning")

	_tick(objective, 10)
	_check(not objective.is_activated(), "a relay four thousand pixels away stays asleep")
	_check(activations[0] == 0, "...and announces nothing")
	_check(objective.steps_done() == 0, "...and makes no progress")

	player.global_position = home + Vector2(objective.activation_radius_px - 20.0, 0.0)
	_tick(objective, 2)
	_check(objective.is_activated(), "crossing the activation ring wakes the relay")
	_check(activations[0] == 1, "activation announces itself exactly once")
	_tick(objective, 10)
	_check(activations[0] == 1, "...and never re-announces while the player stays close")

	# Fixture read, not an assertion: the sites are seeded, so the test has to
	# ask the relay where it put them before it can stand on one.
	var sites: Array = objective.get("_component_positions")
	_check(sites.size() == objective.steps_total(), "every relay step has a site on the ground")

	player.global_position = home
	_tick(objective, 40)
	_check(objective.steps_done() == 0, "standing on the relay core attunes nothing - the sites are the objective")

	player.global_position = home + (sites[0] as Vector2)
	var first_ticks := _tick_until(objective, func() -> bool: return objective.steps_done() >= 1)
	_check(objective.steps_done() == 1, "standing on a relay node for its dwell attunes it")
	_check(
		float(first_ticks) * TICK >= objective.attune_time_sec - TICK,
		"the dwell is actually waited out (%.2fs of %.2fs)" % [float(first_ticks) * TICK, objective.attune_time_sec]
	)
	_check(
		reports.size() == 1 and reports[0] == Vector2i(1, objective.steps_total()),
		"attuning a node reports 1/%d to the HUD" % objective.steps_total()
	)
	_check(not objective.is_finished(), "one node of three does not finish the relay")

	# The relay is the forgiving template: bailing out of a half-attuned node
	# costs the walk back, not the dwell.
	var banked := int(floor(objective.attune_time_sec * 0.5 / TICK))
	player.global_position = home + (sites[1] as Vector2)
	_tick(objective, banked)
	_check(objective.steps_done() == 1, "half a dwell is not a step")
	player.global_position = home
	_tick(objective, 40)
	_check(objective.steps_done() == 1, "walking away from a half-attuned node never finishes it")
	player.global_position = home + (sites[1] as Vector2)
	var resume_ticks := _tick_until(objective, func() -> bool: return objective.steps_done() >= 2)
	_check(objective.steps_done() == 2, "returning to a half-attuned node finishes it")
	_check(
		float(resume_ticks) * TICK < objective.attune_time_sec,
		"the relay keeps banked dwell across a bail-out (%.2fs to resume, %.2fs from scratch)" % [float(resume_ticks) * TICK, objective.attune_time_sec]
	)

	# The last site finishes it.
	for index in range(2, sites.size()):
		player.global_position = home + (sites[index] as Vector2)
		_tick_until(objective, func() -> bool: return objective.steps_done() > index)
	_check(objective.is_finished(), "attuning every node finishes the relay")
	_check(completions[0] == 1, "the relay emits completed exactly once")
	_check(objective.steps_done() == objective.steps_total(), "a finished relay reads full")
	_check(reports.size() == objective.steps_total(), "one progress report per node, no more (%d)" % reports.size())
	_check(
		objective.objective_detail().contains("%d/%d" % [objective.steps_total(), objective.steps_total()]),
		"the detail line reads the relay out in full"
	)

	_tick(objective, 20)
	_check(completions[0] == 1, "ticking a finished relay never fires completed again")
	_check(objective.steps_done() == objective.steps_total(), "...and never moves its count")

	# The relay is the quiet one: it never calls for a wave of its own.
	_check(spawner.bursts.is_empty(), "the relay asks the spawner for nothing - it is a route, not a siege")

	_release(objective)
	_release(spawner)
	_release(player)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# VIGIL - the Ward Vigil: refuse to leave one place
# ---------------------------------------------------------------------------

func _test_ward_vigil() -> void:
	_reset_capture()
	var seed_value := _seed_for(&"ward_vigil", 6)
	_check(seed_value >= 0, "a segment-6 seed rolls the Ward Vigil")
	if seed_value < 0:
		return
	var objective := PrimaryObjectiveCatalog.create_for(6, seed_value) as WardVigilObjective
	_check(objective != null, "the catalog builds a Ward Vigil for that seed")
	if objective == null:
		return

	# A shorter vigil, same shape: the wave stages are fractions of it, so
	# every stage is still crossed exactly once.
	objective.vigil_seconds = 4.0
	var home := Vector2(-2048.0, 6144.0)
	_install(objective, home)
	var spawner := _spawn_stub_spawner()
	var player := _spawn_stub_player(home + Vector2(4000.0, 0.0))

	var completions: Array[int] = [0]
	var reports: Array = []
	objective.completed.connect(func() -> void: completions[0] += 1)
	objective.progress_changed.connect(func(done: int, total: int) -> void: reports.append(Vector2i(done, total)))

	_tick(objective, 10)
	_check(not objective.is_activated(), "a vigil across the district stays asleep")
	_check(spawner.bursts.is_empty(), "...and calls no waves at a player who has not reached it")

	# Inside the activation ring but outside the circle itself.
	player.global_position = home + Vector2(objective.vigil_radius_px + 140.0, 0.0)
	_tick(objective, 2)
	_check(objective.is_activated(), "approaching the vigil wakes it")
	_check(
		_tips.size() == 1 and _tips[0].contains("Hold for"),
		"waking the vigil tells the player the verb and the price"
	)
	_tick(objective, 40)
	_check(is_zero_approx(objective.progress_fraction()), "standing next to the circle holds nothing")
	_check(spawner.bursts.is_empty(), "...and a vigil nobody is holding calls no waves")

	# Step in and hold.
	player.global_position = home
	var hold_ticks := int(floor(objective.vigil_seconds * 0.25 / TICK))
	_tick(objective, hold_ticks)
	var held := objective.progress_fraction()
	_check(held > 0.0 and held < 1.0, "standing in the circle holds it (%.2f)" % held)
	_check(not objective.is_draining(), "a held vigil is not bleeding")
	_check(not reports.is_empty(), "the vigil reports progress while it is held")
	_check(objective.objective_detail().contains("Holding"), "...and the detail line says it is holding")

	# A moment out of the circle is free - dodging has to stay legal.
	var waves_while_held := spawner.bursts.size()
	_check(waves_while_held > 0, "holding the vigil is what calls its waves (%d so far)" % waves_while_held)
	player.global_position = home + Vector2(objective.vigil_radius_px + 40.0, 0.0)
	var grace_ticks := maxi(1, int(floor(objective.lapse_grace / TICK)) - 2)
	_tick(objective, grace_ticks)
	_check(is_equal_approx(objective.progress_fraction(), held), "a moment out of the circle costs nothing")
	_check(not objective.is_draining(), "...and does not read as bleeding")

	# Past the grace it DRAINS. Zeroing on exit would make "stand still and
	# pray" the only correct play, which is a dare with no counterplay.
	var drain_ticks := 24
	_tick(objective, drain_ticks)
	var drained := objective.progress_fraction()
	_check(drained < held, "past the grace the vigil bleeds (%.3f -> %.3f)" % [held, drained])
	_check(drained > 0.0, "stepping out drains the vigil, it never voids it")
	_check(objective.is_draining(), "...and the vigil says it is bleeding")
	# A hold that is going backwards crosses no new stage, so no wave is due and
	# none arrives. That is all this can see: the guard that stops the siege for
	# a player who has walked away only shows itself when a wave IS due, which is
	# the state _test_ward_vigil_wave_gate() builds deliberately below.
	_check(
		spawner.bursts.size() == waves_while_held,
		"a bleeding vigil crosses no new stage, so no wave arrives (%d, still)" % spawner.bursts.size()
	)

	# The bleed is slower than the gain, or dodging out is never worth it.
	var lost := held - drained
	player.global_position = home
	_tick(objective, 1)
	_check(not objective.is_draining(), "returning to the circle stops the bleed at once")
	var regain_start := objective.progress_fraction()
	_tick(objective, drain_ticks)
	var gained := objective.progress_fraction() - regain_start
	_check(gained > lost, "holding gains faster than stepping out loses (%.3f gained vs %.3f lost)" % [gained, lost])

	# A corpse must not hold the ground.
	var before_death := objective.progress_fraction()
	player.is_dead = true
	_tick(objective, 20)
	var after_death := objective.progress_fraction()
	_check(after_death < before_death, "a dead player standing in the circle still bleeds the vigil (%.3f -> %.3f)" % [before_death, after_death])
	_check(after_death > 0.0, "...and death drains the vigil rather than voiding it")
	_check(not objective.is_finished(), "a corpse never finishes the vigil")
	player.is_dead = false

	# Hold it out.
	player.global_position = home
	var stages: Array = WardVigilObjective.WAVE_STAGES
	_tick_until(objective, func() -> bool: return objective.is_finished())
	_check(objective.is_finished(), "holding the circle for the full vigil finishes it")
	_check(completions[0] == 1, "the vigil emits completed exactly once")
	_check(objective.progress_fraction() >= 1.0, "a finished vigil reads full")
	_check(objective.objective_detail() == "The vigil holds", "...and the detail line says so")

	_check(
		spawner.bursts.size() == stages.size(),
		"the vigil calls one wave per stage across the whole hold (%d of %d)" % [spawner.bursts.size(), stages.size()]
	)
	var escalating: bool = spawner.bursts.size() == stages.size()
	for index in range(spawner.bursts.size()):
		if spawner.bursts[index] != int((stages[index] as Vector2).y):
			escalating = false
	_check(escalating, "each wave is the size its stage authored, in order - a siege, not a jump scare")
	# The vigil bled back below a stage's fraction and crossed it again; a
	# stage that re-fired would turn dodging out into a spawn button.
	_check(
		spawner.bursts.size() <= stages.size(),
		"no wave stage re-fires after the vigil bleeds back past it (%d calls, %d stages)" % [spawner.bursts.size(), stages.size()]
	)

	var wave_count := spawner.bursts.size()
	_tick(objective, 40)
	_check(spawner.bursts.size() == wave_count, "a finished vigil stops calling waves")
	_check(completions[0] == 1, "...and never fires completed again")

	var in_range: bool = true
	for report in reports:
		var pair: Vector2i = report
		if pair.x < 0 or pair.x > pair.y or pair.y != objective.steps_total():
			in_range = false
	_check(in_range, "every progress report the vigil emits is a real fraction of its scale")

	_release(objective)
	_release(spawner)
	_release(player)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# VIGIL - the siege belongs to the circle, not to the player
# ---------------------------------------------------------------------------

## The vigil calls its waves from inside its "the player is in the circle"
## branch, so stepping out stops the siege as well as the progress. That guard
## is invisible on an ordinary hold: waves are called at authored fractions of
## the hold, and a hold that nobody is holding only ever goes DOWN, so no stage
## is ever due while the player is away and a gated vigil and an ungated one
## look identical.
##
## It becomes visible with a wave OWED. The vigil calls at most one wave per
## frame, so a single long frame that carries the hold past two authored stages
## at once leaves the second one owed at a fraction the hold has already
## reached. Ticking from outside the circle in that state is the one thing that
## tells the two apart - and the owed wave must not be dropped either: it is
## owed until somebody holds the ground again.
##
## On its own vigil, so the stage accounting of the long hold above keeps
## measuring an ordinary hold.
func _test_ward_vigil_wave_gate() -> void:
	_reset_capture()
	var seed_value := _seed_for(&"ward_vigil", 6)
	# Loud rather than a quiet skip: a section that silently stops running is
	# exactly the failure this whole fix is about.
	_check(seed_value >= 0, "a segment-6 seed still rolls the Ward Vigil")
	if seed_value < 0:
		return
	var objective := PrimaryObjectiveCatalog.create_for(6, seed_value) as WardVigilObjective
	_check(objective != null, "the catalog builds a second Ward Vigil for the siege gate")
	if objective == null:
		return

	objective.vigil_seconds = 4.0
	var home := Vector2(5120.0, -3072.0)
	_install(objective, home)
	var spawner := _spawn_stub_spawner()
	var player := _spawn_stub_player(home)

	var stages: Array = WardVigilObjective.WAVE_STAGES
	var first_stage: Vector2 = stages[0]
	var owed_stage: Vector2 = stages[1]

	_tick(objective, 1)
	_check(objective.is_activated(), "standing in the circle wakes the vigil")

	# One long frame - a hitch, or simply a coarser clock - carries the hold
	# past both of the first two stages.
	_tick(objective, 1, owed_stage.x * objective.vigil_seconds + 0.2)
	_check(
		objective.progress_fraction() >= owed_stage.x,
		"a long frame carries the hold past two stages at once (%.3f, past %.2f)"
			% [objective.progress_fraction(), owed_stage.x]
	)
	_check(
		spawner.bursts.size() == 1 and spawner.bursts[0] == int(first_stage.y),
		"...and one frame calls one wave, never the whole siege at once (%s)" % [spawner.bursts]
	)

	# Out of the circle with that second wave owed. The waves are the price of
	# holding the ground; a player who is not holding it is not owed a siege,
	# and pressure poured at them would be landing wherever they walked to.
	player.global_position = home + Vector2(objective.vigil_radius_px + 60.0, 0.0)
	_tick(objective, 4)
	_check(not objective.is_draining(), "a moment out of the circle is still free")
	_check(
		objective.progress_fraction() >= owed_stage.x,
		"...and the wave the hold has already earned is still owed (%.3f, past %.2f)"
			% [objective.progress_fraction(), owed_stage.x]
	)
	_check(
		spawner.bursts.size() == 1,
		"a vigil the player has stepped out of calls no wave even with one owed (%d)"
			% spawner.bursts.size()
	)

	# Same again past the grace, while the vigil is bleeding back.
	var bleed_ticks := _tick_until(objective, func() -> bool: return objective.is_draining(), 400)
	_check(objective.is_draining(), "the vigil past its grace is bleeding (%d ticks)" % bleed_ticks)
	_check(
		objective.progress_fraction() >= owed_stage.x,
		"...with the owed wave still behind the hold (%.3f, past %.2f)"
			% [objective.progress_fraction(), owed_stage.x]
	)
	_check(
		spawner.bursts.size() == 1,
		"a bleeding vigil calls no wave either (%d)" % spawner.bursts.size()
	)

	# Owed, not forfeited: it arrives the moment the circle is held again. This
	# is also what proves the two checks above were watching something real -
	# the wave was there to be called the whole time.
	player.global_position = home
	_tick(objective, 1)
	_check(
		spawner.bursts.size() == 2 and spawner.bursts[1] == int(owed_stage.y),
		"holding the circle again collects the owed wave at its authored size (%s)" % [spawner.bursts]
	)

	_release(objective)
	_release(spawner)
	_release(player)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# COLLAPSE - the Breach Seal: three places actively making it worse
# ---------------------------------------------------------------------------

func _test_breach_seal() -> void:
	_reset_capture()
	var seed_value := _seed_for(&"breach_seal", 6)
	_check(seed_value >= 0, "a segment-6 seed rolls the Breach Seal")
	if seed_value < 0:
		return
	var objective := PrimaryObjectiveCatalog.create_for(6, seed_value) as BreachSealObjective
	_check(objective != null, "the catalog builds a Breach Seal for that seed")
	if objective == null:
		return

	objective.seal_seconds = 1.5
	objective.breach_spawn_interval = 0.4
	objective.breach_spawn_count = 2
	var home := Vector2(-7168.0, -1024.0)
	_install(objective, home)
	var spawner := _spawn_stub_spawner()
	var player := _spawn_stub_player(home + Vector2(4000.0, 0.0))

	var completions: Array[int] = [0]
	var reports: Array = []
	objective.completed.connect(func() -> void: completions[0] += 1)
	objective.progress_changed.connect(func(done: int, total: int) -> void: reports.append(Vector2i(done, total)))

	_check(objective.steps_total() == objective.breach_count, "the objective opens one breach per step (%d)" % objective.steps_total())
	_check(objective.open_count() == objective.steps_total(), "every breach starts open")

	# An unreached objective is inert. A Breach Seal four thousand pixels away
	# firing waves at the player is the exact regression the base class's
	# activation gate was added for.
	_tick(objective, 40)
	_check(not objective.is_activated(), "an unreached Breach Seal stays asleep")
	_check(spawner.pours.is_empty(), "...and an unreached breach pours nothing")
	player.is_dead = true
	_tick(objective, 40)
	_check(not objective.is_activated(), "a dead player never activates a distant Breach Seal")
	_check(spawner.pours.is_empty(), "...and a distant breach never pours at a corpse")
	player.is_dead = false

	player.global_position = home + Vector2(objective.activation_radius_px - 20.0, 0.0)
	_tick(objective, 2)
	_check(objective.is_activated(), "reaching the breaches wakes them")
	_check(
		_tips.size() == 1 and _tips[0].contains("Breaches are open"),
		"waking the Breach Seal names the pressure it just started"
	)
	_check(
		objective.objective_detail().contains("%d/%d" % [objective.open_count(), objective.steps_total()]),
		"the detail line counts the open breaches"
	)

	# Fixture read, not an assertion: the breaches are seeded, so the test has
	# to ask the objective where it opened them.
	var sites: Array = objective.get("_positions")
	_check(sites.size() == objective.steps_total(), "every breach step has a site on the ground")

	# An open breach keeps sending things: that IS the objective's timer. And
	# it sends them FROM THE BREACH (ruling 2026-09-06) - the old spawn_burst
	# rang them around the player instead, so a breach's pour followed the
	# player across the district for the rest of the segment.
	_tick(objective, 40)
	_check(not spawner.pours.is_empty(), "an open breach keeps pouring while the player is near")
	var sized: bool = true
	var at_a_breach: bool = true
	for pour in spawner.pours:
		if int(pour["count"]) != objective.breach_spawn_count:
			sized = false
		var where: Vector2 = pour["position"]
		var on_site := false
		for site in sites:
			if where.is_equal_approx(home + (site as Vector2)):
				on_site = true
		if not on_site or where.is_equal_approx(player.global_position):
			at_a_breach = false
	_check(sized, "every pour is the authored breach burst size (%d)" % objective.breach_spawn_count)
	_check(at_a_breach, "and every pour is AT a breach, never around the player")

	# A breach the player has walked away from is DORMANT: it neither follows
	# them nor banks a wave for their return. The breaches sit 430 px from the
	# centre; with the pour radius pulled in to 300 px, standing at the centre
	# is out of reach of all three.
	var pours_before := spawner.pours.size()
	objective.breach_pour_radius_px = 300.0
	player.global_position = home
	_tick(objective, 40)
	_check(spawner.pours.size() == pours_before, "a breach beyond its pour radius is dormant - it neither follows the player nor banks a wave")
	# Back within reach of breach 0 - but outside its seal radius, so this is
	# a fight next to it, not a seal.
	var near_zero := home + (sites[0] as Vector2) + Vector2(200.0, 0.0)
	player.global_position = near_zero
	_tick(objective, 40)
	_check(spawner.pours.size() > pours_before, "returning within reach of a breach wakes it")
	var only_that_one: bool = true
	for index in range(pours_before, spawner.pours.size()):
		if not (spawner.pours[index]["position"] as Vector2).is_equal_approx(home + (sites[0] as Vector2)):
			only_that_one = false
	_check(only_that_one, "and only THAT breach pours - the two out of reach stay dormant")

	# Each breach keeps at most breach_max_alive of its own alive: camping one
	# is a bounded fight, not an exponential one. Killing them reopens it.
	_tick(objective, 200)
	var own: Array = (objective.get("_spawned") as Array)[0]
	var alive_here := 0
	for enemy_variant in own:
		if is_instance_valid(enemy_variant) and (enemy_variant as Node).is_in_group(&"enemies"):
			alive_here += 1
	_check(alive_here == objective.breach_max_alive, "a camped breach keeps at most breach_max_alive of its own alive (%d)" % alive_here)
	var pours_at_cap := spawner.pours.size()
	_tick(objective, 40)
	_check(spawner.pours.size() == pours_at_cap, "and pours nothing more while they live")
	for enemy_variant in own:
		if is_instance_valid(enemy_variant):
			(enemy_variant as Node).remove_from_group(&"enemies")
	_tick(objective, 40)
	_check(spawner.pours.size() > pours_at_cap, "killing them reopens the breach")
	objective.breach_pour_radius_px = 1400.0

	player.global_position = home
	_tick(objective, 40)
	_check(objective.steps_done() == 0, "standing at the centre seals nothing - the breaches are the objective")

	if BattleText != null and BattleText.has_method("clear"):
		BattleText.clear()
	player.global_position = home + (sites[0] as Vector2)
	var seal_ticks := _tick_until(objective, func() -> bool: return objective.steps_done() >= 1)
	_check(objective.steps_done() == 1, "standing on a breach for the seal time shuts it")
	_check(
		float(seal_ticks) * TICK >= objective.seal_seconds - TICK,
		"the seal is actually held (%.2fs of %.2fs)" % [float(seal_ticks) * TICK, objective.seal_seconds]
	)
	_check(objective.open_count() == objective.steps_total() - 1, "sealing one breach closes one source")
	_check(
		reports.size() == 1 and reports[0] == Vector2i(1, objective.steps_total()),
		"sealing a breach reports 1/%d to the HUD" % objective.steps_total()
	)
	if BattleText != null and BattleText.has_method("callouts_enabled") and bool(BattleText.callouts_enabled()):
		var texts: PackedStringArray = BattleText.get("_texts")
		var announced: bool = false
		for index in range(int(BattleText.get("_count"))):
			if texts[index] == "BREACH SEALED":
				announced = true
		_check(announced, "sealing a breach says so where the player is looking")
		BattleText.clear()

	# Bailing out costs progress, never all of it - a breach you gave up on
	# halfway should still be the one worth coming back to.
	var half := int(floor(objective.seal_seconds * 0.5 / TICK))
	player.global_position = home + (sites[1] as Vector2)
	_tick(objective, half)
	_check(objective.steps_done() == 1, "half a seal is not a step")
	player.global_position = home
	_tick(objective, 10)
	_check(objective.steps_done() == 1, "bailing out of a seal never completes it")
	player.global_position = home + (sites[1] as Vector2)
	var resume_ticks := _tick_until(objective, func() -> bool: return objective.steps_done() >= 2)
	_check(objective.steps_done() == 2, "returning to a bailed breach seals it")
	_check(
		resume_ticks > seal_ticks - half,
		"bailing out of a seal costs progress (%d ticks to resume, %d banked)" % [resume_ticks, half]
	)
	_check(
		resume_ticks < seal_ticks,
		"...but never all of it (%d ticks to resume vs %d from scratch)" % [resume_ticks, seal_ticks]
	)

	# A corpse seals nothing, but the breaches do not stop pouring either. The
	# breach it lies on may be at its local cap from earlier: those count as
	# killed first, which is the only way a capped breach ever pours again.
	for enemy_variant in (objective.get("_spawned") as Array)[2]:
		if is_instance_valid(enemy_variant):
			(enemy_variant as Node).remove_from_group(&"enemies")
	var pours_before_corpse := spawner.pours.size()
	var done_before := objective.steps_done()
	player.is_dead = true
	player.global_position = home + (sites[2] as Vector2)
	_tick(objective, 40)
	_check(objective.steps_done() == done_before, "a corpse lying on a breach seals nothing")
	_check(spawner.pours.size() > pours_before_corpse, "...and the breach it is lying on keeps pouring - at the breach")
	_check(not objective.is_finished(), "a corpse never finishes the Breach Seal")
	player.is_dead = false

	_tick_until(objective, func() -> bool: return objective.is_finished())
	_check(objective.is_finished(), "sealing every breach finishes the objective")
	_check(completions[0] == 1, "the Breach Seal emits completed exactly once")
	_check(objective.open_count() == 0, "a finished Breach Seal has no open breach left")
	_check(objective.objective_detail() == "Every breach is shut", "...and the detail line says so")
	_check(reports.size() == objective.steps_total(), "one progress report per breach, no more (%d)" % reports.size())

	var pours_at_finish := spawner.pours.size()
	_tick(objective, 60)
	_check(spawner.pours.size() == pours_at_finish, "a sealed district stops pouring")
	_check(completions[0] == 1, "...and never fires completed again")

	_release(objective)
	_release(spawner)
	_release(player)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# The gate: an unfinished primary keeps the Exit Rite shut
# ---------------------------------------------------------------------------

## Wires a real objective to the real SegmentProcBuilder handlers exactly the
## way _spawn_primary_objective() does, against a real Exit Rite, and pins what
## the player can and cannot do at each stage.
func _test_rite_gate(id: StringName, deep: bool) -> void:
	_reset_capture()
	var segment: int = (2 if id == &"district_relay" else 6)
	var seed_value: int = (11 if id == &"district_relay" else _seed_for(id, 6))
	if seed_value < 0:
		_check(false, "a seed exists that rolls '%s' for the gate wiring" % String(id))
		return
	var objective := PrimaryObjectiveCatalog.create_for(segment, seed_value)
	if objective == null:
		_check(false, "the catalog builds '%s' for the gate wiring" % String(id))
		return

	var harness := BuilderHarness.new()
	add_child(harness)

	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	# Exactly what _spawn_exit_gate() does while the primary is still open.
	rite.revealed = false
	rite.hide_location_while_locked = true
	rite.global_position = Vector2(12288.0, 4096.0)
	add_child(rite)
	await get_tree().process_frame
	rite.set_revealed(false)
	harness.set("_exit_rite", rite)

	# Exactly what _spawn_primary_objective() does: hand the builder the
	# objective it will ask for wording, then make its three connections.
	harness.set("_primary_objective", objective)
	objective.activated.connect(Callable(harness, "_on_primary_activated"))
	objective.progress_changed.connect(Callable(harness, "_on_primary_progress_changed"))
	objective.completed.connect(Callable(harness, "_on_primary_completed"))
	harness.add_child(objective)
	objective.set_process(false)

	# THE GUARD: a full resonance bar does not open the rite while the primary
	# objective is still open.
	harness.set("resonance", 1.0)
	harness.call("_update_gate_lock")
	_check(rite.locked, "'%s' unfinished keeps the Exit Rite sealed at full resonance" % String(id))
	_check(not rite.revealed, "...and keeps the rite itself unrevealed")
	_check(Global.exit_gate_pos == Vector2.INF, "...and keeps the exit's location off the HUD")

	# Same call, same resonance, only the primary flag moved: proof the seal
	# tracks THIS gate and not the resonance bar on its own.
	harness.set("_primary_completed", true)
	harness.call("_update_gate_lock")
	_check(not rite.locked, "...and that same resonance unseals the rite the moment the primary is done")
	harness.set("_primary_completed", false)
	harness.call("_update_gate_lock")
	_check(rite.locked, "...and the seal follows the primary straight back down")

	_reset_capture()
	harness.call("_push_objective_ui")
	_check(
		_objective_ui.size() == 1 and String(_objective_ui[0][0]).contains(objective.objective_title()),
		"the HUD headline is the '%s' objective's own title" % String(id)
	)
	_check(
		_objective_ui.size() == 1 and String(_objective_ui[0][1]) == objective.objective_detail(),
		"...and the detail line is the objective's own wording"
	)
	_check(
		_checklists.size() == 1 and _checklists[0][0] == &"locked" and (_checklists[0][1] as Array).is_empty(),
		"the gate checklist stays locked and empty while the primary is open"
	)

	if deep:
		# The lock is not decoration: the rite physically refuses the player.
		var intruder := _spawn_stub_player(rite.global_position)
		_reset_capture()
		rite.call("_on_body_entered", intruder)
		_check(not rite.is_in_group(&"exit_rite_channeling"), "a sealed rite refuses to start channelling")
		_check(
			_tips.size() == 1 and _tips[0].contains("not ready"),
			"...and tells the player why instead of silently doing nothing"
		)
		_release(intruder)

	# Completion alone, measured from zero resonance.
	harness.set("resonance", 0.0)
	harness.call("_update_gate_lock")
	_reset_capture()
	# finish() is the base class's only route to `completed`; the mechanics
	# that reach it are driven for real in the per-type sections above.
	objective.finish()

	_check(rite.revealed, "completing '%s' reveals the Exit Rite" % String(id))
	_check(rite.locked, "...but completing it alone does not unseal the rite")
	_check(
		float(harness.get("resonance")) >= float(harness.get("primary_completion_resonance")),
		"...and pays the primary's resonance"
	)
	_check(_phases.has(&"ascension"), "completing the primary moves the district into ASCENSION")

	_check(not _checklists.is_empty(), "completing the primary rebuilds the gate checklist")
	if not _checklists.is_empty():
		var last: Array = _checklists.back()
		var items: Array = last[1]
		var row: Dictionary = {}
		var has_resonance_row: bool = false
		for item_variant in items:
			var item: Dictionary = item_variant
			if StringName(item.get("id", &"")) == objective.checklist_id():
				row = item
			if StringName(item.get("id", &"")) == &"resonance":
				has_resonance_row = true
		_check(not row.is_empty(), "the checklist carries the '%s' row id '%s'" % [String(id), String(objective.checklist_id())])
		_check(String(row.get("label", "")) == objective.checklist_label(), "...with the objective's own wording, not a generic one")
		_check(bool(row.get("done", false)), "...marked done")
		_check(last[0] == &"locked", "the gate is still locked while resonance is unpaid")
		_check(has_resonance_row, "...and the checklist names the lock that is still shut")

	if deep:
		# The primary is one lock of several, and every one of them holds.
		harness.set("_miniboss_required", true)
		harness.call("grant_resonance", 1.0)
		_check(rite.locked, "full resonance does not unseal the rite while a miniboss is owed")
		_reset_capture()
		harness.call("set_miniboss_defeated")
		_check(not rite.locked, "primary, resonance and miniboss together unseal the Exit Rite")
		_check(Global.exit_gate_pos == rite.global_position, "an unsealed rite finally tells the HUD where it is")
		var ready_state: bool = false
		for entry in _checklists:
			if entry[0] == &"ready":
				ready_state = true
		_check(ready_state, "the checklist reports the gate ready once every lock is open")

		var arrival := _spawn_stub_player(rite.global_position)
		rite.call("_on_body_entered", arrival)
		_check(rite.is_in_group(&"exit_rite_channeling"), "an unsealed rite accepts the player and starts channelling")
		_release(arrival)

	_release(rite)
	_release(harness)
	await get_tree().process_frame
	await get_tree().process_frame
