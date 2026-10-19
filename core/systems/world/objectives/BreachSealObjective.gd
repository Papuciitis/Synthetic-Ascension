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
var _site_art: Array[Sprite2D] = []
var _site_hardware: Array[Node2D] = []

class BreachHardware extends Node2D:
	var state := ""
	var bucket := -1
	func sync(next_state: String, progress: float) -> void:
		var next_bucket := int(clampf(progress, 0.0, 1.0) * 32.0)
		if state != next_state or bucket != next_bucket:
			state = next_state
			bucket = next_bucket
			queue_redraw()
	func _draw() -> void:
		if state == "complete":
			return
		# Sparse inner embers and a displaced restraint survive minification.
		# They stay inside the opening and below feet, without a glow field.
		draw_polyline(PackedVector2Array([Vector2(-31, 4), Vector2(-17, 0), Vector2(-4, 6), Vector2(10, 2), Vector2(29, 7)]), Color(0.53, 0.18, 0.075, 0.87), 3.5, true)
		var metal := Color(0.36, 0.31, 0.22, 1.0)
		var reach := lerpf(48.0, 13.0, float(bucket) / 32.0)
		for side in [-1.0, 1.0]:
			var start := Vector2(side * 61.0, -9.0)
			var end := Vector2(side * reach, 4.0)
			draw_line(start, end, Color(0.065, 0.055, 0.04, 0.95), 8.0, true)
			if state == "draining":
				draw_line(start, start.lerp(end, 0.48), metal, 5.0, true)
				draw_line(start.lerp(end, 0.7) + Vector2(0, 3), end + Vector2(0, 3), metal, 5.0, true)
			else:
				draw_line(start, end, metal, 5.0, true)
			draw_line(start + Vector2(0, -2), start.lerp(end, 0.4) + Vector2(0, -2), Color(0.51, 0.47, 0.35, 0.8), 1.3, true)


func build_presentation() -> void:
	# Only real enemy sources have a breach form. The district center is not
	# another interaction site and must not masquerade as a fourth rupture.
	for index in range(_positions.size()):
		_site_art.append(WorldArt.install(self, "breach", 100.0, _positions[index], "BreachSite%d" % index))
		var hardware := BreachHardware.new()
		hardware.name = "BreachHardware%d" % index
		hardware.position = _positions[index]
		hardware.z_as_relative = false
		hardware.z_index = -10
		add_child(hardware)
		_site_hardware.append(hardware)
	update_presentation()


func update_presentation() -> void:
	for index in range(_site_art.size()):
		var fraction := clampf(_progress[index] / maxf(0.001, seal_seconds), 0.0, 1.0)
		var state := site_presentation_state(index)
		_site_art[index].call("set_state", state, fraction)
		_site_hardware[index].call("sync", state, fraction)


func site_presentation_state(index: int) -> String:
	if _sealed[index] != 0:
		return "complete"
	if _progress[index] <= 0.0:
		return "dormant"
	if is_instance_valid(player):
		if bool(player.get("is_dead")):
			return "grace" # Sealing pauses during death; it does not decay.
		if player.global_position.distance_squared_to(global_position + _positions[index]) > seal_radius_px * seal_radius_px:
			return "draining"
	return "working"


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
	for index in range(_positions.size()):
		if _sealed[index] != 0:
			continue
		var world := global_position + _positions[index]
		var inside: bool = player.global_position.distance_squared_to(world) <= seal_radius_px * seal_radius_px

		if inside:
			_progress[index] = minf(seal_seconds, _progress[index] + delta)
			if _progress[index] >= seal_seconds:
				_sealed[index] = 1
				_on_sealed(world)
				report_progress()
				continue
		elif _progress[index] > 0.0:
			# Bailing out costs progress, never all of it - a breach you gave up
			# on halfway should still be the one worth coming back to.
			_progress[index] = maxf(0.0, _progress[index] - delta * seal_decay_rate)

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
	var done := is_finished()
	var core := Color(0.4, 0.95, 0.8, 0.95) if done else Color(0.98, 0.55, 0.35, 0.92)
	for index in range(_positions.size()):
		var at := _positions[index]
		var sealed := _sealed[index] != 0
		var color := Color(0.38, 0.9, 0.73, 0.85) if sealed else Color(0.98, 0.5, 0.28, 0.9)
		var fraction := clampf(_progress[index] / maxf(0.001, seal_seconds), 0.0, 1.0)
		var state := site_presentation_state(index)
		WorldArt.draw_boundary(self, at, seal_radius_px, color if not sealed else Color(0.49, 0.56, 0.48, 0.38), fraction if not sealed and state != "draining" else -1.0)
		if state == "draining":
			# Broken stored progress differs from an advancing solid seal even
			# with hue removed and all animation disabled.
			for segment in range(16):
				var begin := float(segment) / 16.0
				if begin >= fraction:
					break
				var end := minf(fraction, begin + 0.039)
				draw_arc(at, seal_radius_px - 6.0, -PI * 0.5 + TAU * begin, -PI * 0.5 + TAU * end, 8, Color(0.81, 0.57, 0.36, 0.9), 3.0, true)
		if sealed:
			WorldArt.draw_complete(self, at + Vector2(0, 42), 8.0)
		else:
			if state in ["working", "draining", "grace"]:
				var direction := -1.0 if state == "working" else 1.0
				var cue := at + Vector2(0, seal_radius_px - 22.0)
				draw_polyline(PackedVector2Array([cue + Vector2(-6, -direction * 4), cue + Vector2(0, direction * 4), cue + Vector2(6, -direction * 4)]), color, 2.0, true)
				if state == "grace":
					draw_line(cue + Vector2(-3, -5), cue + Vector2(-3, 5), color, 2.0, true)
					draw_line(cue + Vector2(3, -5), cue + Vector2(3, 5), color, 2.0, true)
				var caption := "SEALING" if state == "working" else ("LOSING SEAL" if state == "draining" else "SEAL PAUSED")
				var text_at := at + Vector2(-86.0, seal_radius_px + 26.0)
				draw_string_outline(ThemeDB.fallback_font, text_at, caption, HORIZONTAL_ALIGNMENT_CENTER, 172.0, 20, 3, Color(0.035, 0.03, 0.025, 0.95))
				draw_string(ThemeDB.fallback_font, text_at, caption, HORIZONTAL_ALIGNMENT_CENTER, 172.0, 20, color)
	draw_completion(Vector2(0, 25), 80.0)
	var label := "BREACHES SEALED" if done else "SEAL THE BREACHES (%d OPEN)" % open_count()
	var heading_at := Vector2(-220.0, -106.0)
	draw_string_outline(ThemeDB.fallback_font, heading_at, label, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 22, 5, Color(0.025, 0.02, 0.03, 0.95))
	draw_string(ThemeDB.fallback_font, heading_at, label, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 22, core)
