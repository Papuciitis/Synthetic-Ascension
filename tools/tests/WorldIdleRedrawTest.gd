extends Node

## Performance hygiene audit (2026-08-28) §2: the world's idle painters.
##
## Every node here repainted its canvas EVERY frame for state that was not
## moving - a locked rite, an objective the player is a screen away from, a
## wardstone nobody is standing in, nine waypoint sigils, the item rings on the
## player. This suite pins the gates that stopped them, and it pins them the
## only way that cannot lie: by counting the `draw` signal on the real node.
## Headless issues NOTIFICATION_DRAW like any other build - it only rasterises
## into a dummy - so one queue_redraw() before a frame is exactly one _draw.
##
## The wall-clock 30 Hz bucket (ManifestationEffect.pulse_redraw) is checked
## against elapsed milliseconds rather than a frame count, because a headless
## frame is far shorter than a rendered one.

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const WARDSTONE_SCENE: PackedScene = preload("res://scenes/world/wardstones/Wardstone.tscn")
const WAYPOINT_SIGIL_SCENE: PackedScene = preload("res://scenes/world/waypoints/WaypointSigil.tscn")
const IDLE_AURA_SCENE: PackedScene = preload("res://assets/vfx/world/wardstones/VFX_WardstoneIdleAura.tscn")
const OBJECTIVE_SCRIPT: Script = preload("res://core/systems/world/objectives/PrimaryObjective.gd")
const WARDSTONE_SCRIPT: Script = preload("res://core/systems/world/Wardstone.gd")
const IDLE_AURA_SCRIPT: Script = preload("res://assets/vfx/world/wardstones/VFX_WardstoneIdleAura.gd")
const WAYPOINT_SIGIL_SCRIPT: Script = preload("res://scenes/world/waypoints/WaypointSigil.gd")
const REGEN_RING_SCRIPT: Script = preload("res://effects/items/logic/RegenerationRingEffect.gd")
const FIRESTONE_SCRIPT: Script = preload("res://effects/items/logic/FirestoneEffect.gd")
const OAKHEART_SCRIPT: Script = preload("res://effects/items/logic/OakheartShieldEffect.gd")

## Long enough that a per-frame painter is unmistakable.
const IDLE_FRAMES: int = 24

## ...and long enough in wall-clock terms that the 30 Hz bucket has had several
## chances to fire, whatever a headless frame happens to cost today.
const IDLE_MIN_MS: int = 150

## The shared bucket the audit's §3 pattern list names, in milliseconds.
const PULSE_REDRAW_MS: int = 33


class ProbePlayer:
	extends Node2D
	var is_dead: bool = false


var _passes := 0
var _failures := 0
var _draws := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_draw() -> void:
	_draws += 1


## Reads a tuning constant out of the script under test rather than naming it
## directly, so this suite still parses against a tree where the constant does
## not exist yet - which is what makes "revert the fix and watch it fail" a
## usable check rather than a parse error.
func _tunable(script: Script, name: StringName, fallback: float) -> float:
	var constants: Dictionary = script.get_script_constant_map()
	return float(constants.get(String(name), fallback))


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


## Draws counted over at least `count` frames AND at least IDLE_MIN_MS of wall
## clock, returned as [draws, elapsed_ms, frames]. A headless frame is far
## shorter than a rendered one, so a 30 Hz painter has to be judged against the
## clock it actually buckets on.
func _count_draws(count: int) -> Array:
	_draws = 0
	var started := Time.get_ticks_msec()
	var frames := 0
	while frames < count or Time.get_ticks_msec() - started < IDLE_MIN_MS:
		await get_tree().process_frame
		frames += 1
	return [_draws, Time.get_ticks_msec() - started, frames]


## The most repaints the shared 30 Hz bucket can produce in `elapsed_ms`, plus
## one for the partial bucket at each end.
func _bucket_ceiling(elapsed_ms: int) -> int:
	return int(elapsed_ms / PULSE_REDRAW_MS) + 2


func _run() -> void:
	var player := ProbePlayer.new()
	player.add_to_group(&"player")
	player.global_position = Vector2(20000.0, 20000.0)
	add_child(player)
	await _frames(1)

	await _test_exit_rite(player)
	await _test_primary_objective(player)
	await _test_wardstone(player)
	await _test_idle_aura(player)
	await _test_waypoint_sigil(player)
	await _test_item_rings()

	player.queue_free()
	print("WorldIdleRedrawTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Row 2: the locked Exit Rite
# ---------------------------------------------------------------------------

func _test_exit_rite(player: ProbePlayer) -> void:
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	rite.global_position = Vector2.ZERO
	player.global_position = Vector2(20000.0, 20000.0)
	rite.set_revealed(true)
	rite.set_locked(true)
	await _frames(2)

	rite.draw.connect(_on_draw)
	var locked_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(locked_draws[0]) == 0,
		"a locked rite repaints nothing while it waits (%d draws in %d frames)" % [locked_draws[0], locked_draws[2]]
	)

	# ...but every input to the locked drawing still wakes it.
	_draws = 0
	rite.grant_safeguard(&"idle_test:1")
	await _frames(2)
	_check(_draws == 1, "granting a safeguard repaints the pips (%d draws)" % _draws)

	_draws = 0
	rite.set_locked(true)
	await _frames(2)
	_check(_draws == 1, "a repeated set_locked still repaints the ring (%d draws)" % _draws)

	_draws = 0
	rite.set_revealed(false)
	rite.set_revealed(true)
	await _frames(2)
	_check(_draws > 0, "revealing the rite repaints its reset ledger (%d draws)" % _draws)

	_draws = 0
	rite.configure_doctrine_rules()
	await _frames(2)
	_check(_draws == 1, "a doctrine change repaints the safeguard capacity (%d draws)" % _draws)

	_draws = 0
	rite.set_locked(false)
	await _frames(3)
	_check(_draws > 0, "an unlocked rite is animated again (%d draws)" % _draws)

	rite.draw.disconnect(_on_draw)
	rite.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Row 3: the primary objective before activation and after completion
# ---------------------------------------------------------------------------

func _test_primary_objective(player: ProbePlayer) -> void:
	var objective := Node2D.new()
	objective.set_script(OBJECTIVE_SCRIPT)
	add_child(objective)
	objective.global_position = Vector2.ZERO
	var cull: float = float(objective.get("activation_radius_px")) \
		+ _tunable(OBJECTIVE_SCRIPT, &"IDLE_DRAW_MARGIN_PX", 1200.0)

	player.global_position = Vector2(cull * 3.0, 0.0)
	await _frames(2)
	objective.draw.connect(_on_draw)
	var far_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(far_draws[0]) == 0,
		"an objective the player cannot see repaints nothing (%d draws in %d frames)" % [far_draws[0], far_draws[2]]
	)
	_check(not bool(objective.call("is_activated")), "and it is still waiting to be reached")

	# Inside drawing range but outside activation range: the pulse animates, on
	# the shared bucket rather than every frame.
	player.global_position = Vector2(float(objective.get("activation_radius_px")) + 40.0, 0.0)
	var near_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(near_draws[0]) > 0 and int(near_draws[0]) <= _bucket_ceiling(int(near_draws[1])),
		"a visible unreached objective pulses on the 30 Hz bucket (%d draws in %d frames / %d ms)"
			% [near_draws[0], near_draws[2], near_draws[1]]
	)
	_check(not bool(objective.call("is_activated")), "and it has still not activated at that distance")

	objective.call("finish")
	await _frames(2)
	var done_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(done_draws[0]) <= _bucket_ceiling(int(done_draws[1])),
		"a finished objective idles on the 30 Hz bucket (%d draws in %d frames / %d ms)"
			% [done_draws[0], done_draws[2], done_draws[1]]
	)

	objective.draw.disconnect(_on_draw)
	objective.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Row 4a: the wardstone nobody is standing in
# ---------------------------------------------------------------------------

func _test_wardstone(player: ProbePlayer) -> void:
	var stone := WARDSTONE_SCENE.instantiate() as Wardstone
	add_child(stone)
	stone.global_position = Vector2.ZERO
	player.global_position = Vector2(20000.0, 20000.0)
	await _frames(3)

	stone.draw.connect(_on_draw)
	var away_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(away_draws[0]) == 0,
		"a wardstone nobody is near repaints nothing (%d draws in %d frames)" % [away_draws[0], away_draws[2]]
	)

	# Walking into the stability ring's reveal range is a state change, so it
	# repaints - once, and then holds still again.
	_draws = 0
	player.global_position = Vector2(stone.stability_radius * 0.5, 0.0)
	var poll_deadline := Time.get_ticks_msec() \
		+ int(_tunable(WARDSTONE_SCRIPT, &"STABILITY_POLL_INTERVAL", 0.25) * 4000.0) + 500
	while _draws == 0 and Time.get_ticks_msec() < poll_deadline:
		await get_tree().process_frame
	var arrival_draws := _draws
	_check(arrival_draws > 0, "walking into range shows the stability ring (%d draws)" % arrival_draws)
	var settled: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(settled[0]) == 0,
		"and standing there repaints nothing more (%d draws in %d frames)" % [settled[0], settled[2]]
	)

	_draws = 0
	stone.restore_active()
	await _frames(2)
	_check(_draws == 1, "attuning the wardstone repaints it (%d draws)" % _draws)

	stone.draw.disconnect(_on_draw)
	stone.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Row 4b: the wardstone idle aura
# ---------------------------------------------------------------------------

func _test_idle_aura(player: ProbePlayer) -> void:
	var aura := IDLE_AURA_SCENE.instantiate() as WardstoneIdleAura
	add_child(aura)
	aura.global_position = Vector2.ZERO
	player.global_position = Vector2(_tunable(IDLE_AURA_SCRIPT, &"DRAW_MAX_PLAYER_DIST", 1400.0) * 4.0, 0.0)
	await _frames(3)

	aura.draw.connect(_on_draw)
	var far_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(far_draws[0]) == 0 and not aura.visible,
		"an off-screen idle aura hides instead of painting (%d draws, visible=%s)" % [far_draws[0], aura.visible]
	)

	player.global_position = Vector2(40.0, 0.0)
	var near_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		aura.visible and int(near_draws[0]) > 0 and int(near_draws[0]) <= _bucket_ceiling(int(near_draws[1])),
		"a nearby idle aura breathes on the 30 Hz bucket (%d draws in %d frames / %d ms)"
			% [near_draws[0], near_draws[2], near_draws[1]]
	)

	# The wardstone re-asserts its idle level every frame; only a level that
	# moved is worth a repaint. The aura's own breathe is silenced for this
	# check so the only thing that can queue a repaint is the setter.
	aura.set_process(false)
	_draws = 0
	var held: float = aura.intensity
	for _index in range(6):
		aura.set_intensity(held)
	await _frames(2)
	_check(_draws == 0, "re-asserting the same intensity repaints nothing (%d draws)" % _draws)
	_draws = 0
	aura.set_intensity(held * 0.5 + 0.11)
	await _frames(2)
	_check(_draws == 1, "a changed intensity repaints once (%d draws)" % _draws)
	aura.set_process(true)

	aura.draw.disconnect(_on_draw)
	aura.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Row 6: the waypoint sigils
# ---------------------------------------------------------------------------

func _test_waypoint_sigil(player: ProbePlayer) -> void:
	var sigil := WAYPOINT_SIGIL_SCENE.instantiate() as WaypointSigil
	add_child(sigil)
	sigil.global_position = Vector2.ZERO
	player.global_position = Vector2(_tunable(WAYPOINT_SIGIL_SCRIPT, &"DRAW_MAX_PLAYER_DIST", 1400.0) * 4.0, 0.0)
	await _frames(3)

	sigil.draw.connect(_on_draw)
	var far_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		int(far_draws[0]) == 0 and not sigil.visible,
		"an off-screen waypoint sigil hides instead of painting (%d draws, visible=%s)" % [far_draws[0], sigil.visible]
	)

	player.global_position = Vector2(60.0, 0.0)
	var near_draws: Array = await _count_draws(IDLE_FRAMES)
	_check(
		sigil.visible and int(near_draws[0]) > 0 and int(near_draws[0]) <= _bucket_ceiling(int(near_draws[1])),
		"a nearby waypoint sigil twinkles on the 30 Hz bucket (%d draws in %d frames / %d ms)"
			% [near_draws[0], near_draws[2], near_draws[1]]
	)

	sigil.draw.disconnect(_on_draw)
	sigil.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Row 9: the item rings on the player
# ---------------------------------------------------------------------------

func _test_item_rings() -> void:
	for entry in [
		[REGEN_RING_SCRIPT, "the regeneration ring"],
		[FIRESTONE_SCRIPT, "the firestone glow"],
		[OAKHEART_SCRIPT, "the oakheart shield"],
	]:
		var ring := Node2D.new()
		ring.set_script(entry[0] as Script)
		add_child(ring)
		await _frames(2)
		ring.draw.connect(_on_draw)
		var drawn: Array = await _count_draws(IDLE_FRAMES)
		_check(
			int(drawn[0]) <= _bucket_ceiling(int(drawn[1])),
			"%s paints on the 30 Hz bucket (%d draws in %d frames / %d ms)"
				% [entry[1], drawn[0], drawn[2], drawn[1]]
		)
		ring.draw.disconnect(_on_draw)
		ring.queue_free()
		await _frames(1)
