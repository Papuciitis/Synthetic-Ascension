extends PrimaryObjective
class_name BreachSealObjective

## COLLAPSE — three breaches are open and pouring. Shut them.
##
## The relay asks you to visit three quiet places; this asks you to visit three
## places that are actively making the situation worse while you decide which to
## go to first. That is the whole objective: it is the only primary that gets
## harder the longer you take, and it does it without a timer, a countdown or a
## threat number - an open breach just keeps sending things at you.
##
## Sealing one is immediate relief you can feel, so the order you pick and
## whether you commit to a seal or bail out mid-way are real decisions rather
## than route-planning. Bailing is allowed and costs progress, never all of it.

@export var breach_count: int = 3
@export var breach_orbit_px: float = 430.0
@export var seal_radius_px: float = 132.0
@export var seal_seconds: float = 5.0
@export var seal_decay_rate: float = 0.55

## Seconds between a live breach's spawns. Staggered per breach so three open
## breaches genuinely read as three sources rather than one louder one.
@export var breach_spawn_interval: float = 4.2
@export var breach_spawn_count: int = 3
## Ruling 2026-09-06: breaches pour from where they ARE. Before this, an
## activated breach called spawn_burst, which rings enemies around the player
## - so one visit pulled waves after the player anywhere in the district for
## the rest of the segment, and the breach position handed to the spawn tick
## went unused. Now a breach the player has walked away from is DORMANT:
## nothing ticks until they are back within breach_pour_radius_px of THAT
## breach, so it neither follows them nor stockpiles an off-screen army. Its
## enemies are ordinary (pooled, under the ambient cap, distance-culled like
## any other), and each breach keeps at most breach_max_alive of its own
## alive, so camping one is a bounded fight rather than an exponential one.
@export var breach_pour_radius_px: float = 1400.0
@export var breach_max_alive: int = 6
@export var breach_spawn_spread_px: float = 96.0

var _positions: Array[Vector2] = []
var _progress: PackedFloat32Array = PackedFloat32Array()
var _sealed: PackedByteArray = PackedByteArray()
var _spawn_cd: PackedFloat32Array = PackedFloat32Array()
var _spawned: Array = [] # per breach: the enemy nodes it poured that may still be alive


func is_layout_built() -> bool:
	return not _positions.is_empty()


func build_layout(rng_source: RandomNumberGenerator) -> void:
	var start_angle: float = rng_source.randf_range(-PI, PI)
	var count: int = maxi(1, breach_count)
	_positions.clear()
	_spawned.clear()
	_progress.resize(count)
	_sealed.resize(count)
	_spawn_cd.resize(count)
	for index in range(count):
		var angle := start_angle + TAU * float(index) / float(count)
		var radius := breach_orbit_px + rng_source.randf_range(-40.0, 40.0)
		_positions.append(Vector2.RIGHT.rotated(angle) * radius)
		_spawned.append([])
		_progress[index] = 0.0
		_sealed[index] = 0
		# Stagger the first spawn so all three do not fire on the same frame.
		_spawn_cd[index] = breach_spawn_interval * (0.35 + 0.30 * float(index))


func on_activated() -> void:
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit(
			"Breaches are open. Every one you leave keeps sending them.",
			4.0
		)


func tick_active(delta: float) -> void:
	var changed: bool = false
	for index in range(_positions.size()):
		if _sealed[index] != 0:
			continue
		var world := global_position + _positions[index]
		var inside: bool = player.global_position.distance_squared_to(world) <= seal_radius_px * seal_radius_px

		if inside:
			_progress[index] = minf(seal_seconds, _progress[index] + delta)
			changed = true
			if _progress[index] >= seal_seconds:
				_sealed[index] = 1
				_on_sealed(world)
				report_progress()
				continue
		elif _progress[index] > 0.0:
			# Bailing out costs progress, never all of it - a breach you gave up
			# on halfway should still be the one worth coming back to.
			_progress[index] = maxf(0.0, _progress[index] - delta * seal_decay_rate)
			changed = true

		_tick_breach_spawn(index, world, delta)

	# Every frame, not just on change: the breach pulse, the core ring and the
	# "(N OPEN)" label are all animated, and gating the redraw on progress froze
	# all three unless the player was standing on a seal.
	queue_redraw()
	if steps_done() >= steps_total():
		finish()


## A corpse seals nothing, but the breaches do not stop pouring either.
func on_player_dead(delta: float) -> void:
	for index in range(_positions.size()):
		if _sealed[index] == 0:
			_tick_breach_spawn(index, global_position + _positions[index], delta)


func _tick_breach_spawn(index: int, world: Vector2, delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Dormant beyond the pour radius: the clock does not even tick, so a
	# returning player meets the breach as they left it, not an ambush it
	# banked while they were away.
	if player.global_position.distance_squared_to(world) > breach_pour_radius_px * breach_pour_radius_px:
		return
	_spawn_cd[index] -= delta
	if _spawn_cd[index] > 0.0:
		return
	_spawn_cd[index] = breach_spawn_interval
	var room: int = breach_max_alive - _prune_breach_spawns(index)
	if room <= 0:
		return
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner == null or not spawner.has_method("spawn_burst_at"):
		return
	var poured: Array = spawner.call("spawn_burst_at", world, mini(maxi(1, breach_spawn_count), room), breach_spawn_spread_px)
	(_spawned[index] as Array).append_array(poured)


## This breach's enemies that are still in the fight: valid, still in the
## enemies group (a parked or quiesced node has left it) and not a corpse.
## Validity is checked before any cast - a freed node is exactly what this
## prunes.
func _prune_breach_spawns(index: int) -> int:
	var kept: Array = []
	for node_variant in (_spawned[index] as Array):
		if node_variant == null or not is_instance_valid(node_variant):
			continue
		var node := node_variant as Node
		# `get("dead")` is null on anything that is not an enemy actor; compare
		# against true rather than converting, which null does not do.
		if node == null or not node.is_in_group(&"enemies") or node.get("dead") == true:
			continue
		kept.append(node)
	_spawned[index] = kept
	return kept.size()


func _on_sealed(at: Vector2) -> void:
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(at, "BREACH SEALED", Color(0.35, 0.95, 0.80, 1.0), 1.35)


func open_count() -> int:
	return steps_total() - steps_done()


func steps_done() -> int:
	var count: int = 0
	for state in _sealed:
		if state != 0:
			count += 1
	return count


func steps_total() -> int:
	return _positions.size()


func objective_title() -> String:
	return "Seal the Breaches"


func objective_detail() -> String:
	if is_finished():
		return "Every breach is shut"
	return "Breaches open: %d/%d • Each one keeps pouring • The exit remains hidden" % [
		open_count(), steps_total()
	]


func checklist_label() -> String:
	return "District breaches sealed"


func checklist_id() -> StringName:
	return &"breaches"


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(pulse_time * 3.4)
	var done := is_finished()
	var core := Color(0.30, 0.95, 0.82, 0.90) if done else Color(0.98, 0.34, 0.26, 0.92)
	draw_circle(Vector2.ZERO, 40.0, Color(core.r, core.g, core.b, 0.16))
	draw_arc(Vector2.ZERO, 62.0 + pulse * 4.0, 0.0, TAU, 64, core, 5.0, true)
	draw_arc(Vector2.ZERO, activation_radius_px, 0.0, TAU, 96, Color(core.r, core.g, core.b, 0.05), 3.0, true)

	for index in range(_positions.size()):
		var local_pos := _positions[index]
		var sealed: bool = _sealed[index] != 0
		var colour := Color(0.30, 0.95, 0.82, 0.96) if sealed else Color(0.99, 0.42, 0.22, 0.96)
		draw_line(Vector2.ZERO, local_pos, Color(core.r, core.g, core.b, 0.18), 3.0, true)

		if sealed:
			draw_circle(local_pos, 30.0, Color(colour.r, colour.g, colour.b, 0.22))
			draw_arc(local_pos, 46.0, 0.0, TAU, 48, colour, 5.0, true)
			continue

		# An open breach breathes: it has to read as a live thing across a room,
		# because deciding which one to go to first is the objective.
		var breath := 1.0 + 0.10 * sin(pulse_time * 4.6 + float(index) * 1.7)
		draw_circle(local_pos, seal_radius_px, Color(colour.r, colour.g, colour.b, 0.045))
		draw_arc(local_pos, seal_radius_px, 0.0, TAU, 64, Color(colour.r, colour.g, colour.b, 0.30), 3.0, true)
		draw_circle(local_pos, 34.0 * breath, Color(colour.r, colour.g, colour.b, 0.26))
		draw_arc(local_pos, 50.0 * breath, 0.0, TAU, 48, colour, 6.0, true)
		if seal_seconds > 0.0 and _progress[index] > 0.0:
			var fraction := clampf(_progress[index] / seal_seconds, 0.0, 1.0)
			draw_arc(local_pos, 62.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 48, Color(1.0, 0.95, 0.65, 1.0), 8.0, true)

	var label := "BREACHES SEALED" if done else "SEAL THE BREACHES (%d OPEN)" % open_count()
	draw_string(ThemeDB.fallback_font, Vector2(-210.0, -100.0), label, HORIZONTAL_ALIGNMENT_CENTER, 420.0, 24, core)
