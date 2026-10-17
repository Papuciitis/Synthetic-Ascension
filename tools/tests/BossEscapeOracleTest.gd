extends Node

# The walk-out oracle behind main-boss attack selection. It must agree with
# the S5 audit's measured escapes (a 1.3 s slam tell from body contact
# escapes at 100 px/s, 1.15 s does not), solve moving hazards exactly, and
# respect the bodies a player cannot walk through.
const ORACLE := preload("res://scenes/world/bosses/BossEscapeOracle.gd")
const PLAYER := preload("res://core/actors/player/player.tscn")
const S10_TANK_RADIUS := 44.795
const S5_TANK_RADIUS := 39.015

var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _slam(tell: float, radius: float = 135.0) -> Array:
	return [{"kind": &"circle", "center": Vector2.ZERO, "radius": radius, "from": tell, "to": tell + 0.18}]


func _run() -> void:
	var player := PLAYER.instantiate()
	add_child(player)
	var shape: Dictionary = ORACLE.player_shape(player)
	_check(shape["hurtbox_half"] == Vector2(35, 35) and is_equal_approx(float(shape["body_radius"]), 25.0) and is_equal_approx(float(shape["body_half_segment"]), 4.0), "the oracle reads the production Hurtbox square and body capsule")
	player.queue_free()

	var body := [{"center": Vector2.ZERO, "radius": S5_TANK_RADIUS}]
	var contact := Vector2(S5_TANK_RADIUS + 25.0, 0.0)
	_check(ORACLE.has_escape(contact, _slam(1.3), shape, body), "a 1.3 s slam tell escapes from body contact at 100 px/s (S5 audit)")
	_check(not ORACLE.has_escape(contact, _slam(1.15), shape, body), "a 1.15 s slam tell does not (S5 audit)")
	var route: Variant = ORACLE.escape_route(contact, _slam(1.3), shape, body)
	_check(route is Vector2 and (route as Vector2).x > 0.9, "the escape walks straight away from the planted body")
	var left := Vector2(-(S5_TANK_RADIUS + 25.0), 0.0)
	var left_route: Variant = ORACLE.escape_route(left, _slam(1.3), shape, body)
	_check(left_route is Vector2 and (left_route as Vector2).x < -0.5, "a contact on the other side escapes the other way, never through the body")
	_check(ORACLE.escape_route(Vector2(600, 0), _slam(1.3), shape, body) == Vector2.ZERO, "a player already outside stands still")
	# Bodies bar walks. A late, small blast just beyond the player leaves
	# walks toward the body as the only way out: from contact (into it) and
	# from a step away (across it). Without the body each escapes; with it,
	# neither does.
	var beyond := func(start: Vector2, away: Vector2) -> Array:
		return [{"kind": &"circle", "center": start + away * 40.0, "radius": 30.0, "from": 0.6, "to": 0.7}]
	var into: Array = beyond.call(contact, Vector2.RIGHT)
	_check(ORACLE.has_escape(contact, into, shape) and not ORACLE.has_escape(contact, into, shape, body), "from contact, a walk out into the body is refused")
	var near := Vector2(-80.0, 0.0)
	var across: Array = beyond.call(near, Vector2.LEFT)
	_check(ORACLE.has_escape(near, across, shape) and not ORACLE.has_escape(near, across, shape, body), "a step away, a walk out across the body is refused")

	# Rush: the S10 body sweeps its lane; physical contact uses the capsule.
	var rush := [{"kind": &"sweep", "a": Vector2.ZERO, "b": Vector2(280.8, 0.0), "radius": S10_TANK_RADIUS, "from": 0.85, "to": 1.21, "body": true}]
	_check(not ORACLE.has_escape(Vector2(150, 0), rush, shape, [], Callable(), 0.0), "standing in the committed lane is struck")
	_check(ORACLE.has_escape(Vector2(150, 0), rush, shape), "a sidestep from the lane escapes the S10 rush")
	_check(ORACLE.escape_route(Vector2(150, 160), rush, shape) == Vector2.ZERO, "beside the lane, standing still is safe")
	_check(not ORACLE.has_escape(Vector2(150, 0), rush, shape, [], Callable(), 40.0), "a badly slowed player cannot always escape (baseline movement only)")

	# Moving bolts are solved exactly in the player's frame.
	var bolt := [{"kind": &"bolt", "origin": Vector2.ZERO, "velocity": Vector2(320, 0), "radius": 5.0, "from": 0.95, "to": 0.95 + 1.625}]
	_check(not ORACLE.has_escape(Vector2(300, 0), bolt, shape, [], Callable(), 0.0), "a bolt along its lane strikes a standing player")
	_check(ORACLE.has_escape(Vector2(300, 0), bolt, shape), "a single bolt is sidestepped")
	_check(ORACLE.escape_route(Vector2(600, 0), bolt, shape) == Vector2.ZERO, "a bolt that expires short of the player cannot reach it")

	# Sectors: the cleave's own polygon.
	var cleave := [{"kind": &"sector", "center": Vector2.ZERO, "facing": 0.0, "radius": 125.0, "half_angle": deg_to_rad(75.0), "from": 1.1, "to": 1.28}]
	var s10_body := [{"center": Vector2.ZERO, "radius": S10_TANK_RADIUS}]
	_check(ORACLE.has_escape(Vector2(S10_TANK_RADIUS + 25.0, 0), cleave, shape, s10_body), "a 1.1 s cleave of 125 px escapes from frontal body contact")
	_check(ORACLE.escape_route(Vector2(-150, 0), cleave, shape, s10_body) == Vector2.ZERO, "behind the boss a cleave needs no step")
	_check(not ORACLE.has_escape(Vector2(80, 0), [{"kind": &"sector", "center": Vector2.ZERO, "facing": 0.0, "radius": 260.0, "half_angle": deg_to_rad(80.0), "from": 1.0, "to": 1.18}], shape, s10_body), "an oversized short-tell sector is judged inescapable")

	# A rotating beam: the start lane is announced, crossing behind it escapes.
	var beam := [{"kind": &"beam", "origin": Vector2.ZERO, "angle_from": 0.0, "angle_to": deg_to_rad(70.0), "length": 520.0, "width": 34.0, "from": 1.1, "to": 2.7}]
	_check(not ORACLE.has_escape(Vector2(300, 0), beam, shape, [], Callable(), 0.0), "the start lane strikes a standing player")
	_check(ORACLE.has_escape(Vector2(300, 0), beam, shape), "a player on the announced start lane has a walk out of the sweep")
	_check(ORACLE.escape_route(Vector2(-300, 0), beam, shape) == Vector2.ZERO, "behind the caster the sweep needs no step")

	# Sequences are judged as one walk.
	var sequence := _slam(1.3) + [{"kind": &"circle", "center": Vector2(220, 0), "radius": 100.0, "from": 1.6, "to": 1.78}]
	_check(not ORACLE.has_escape(contact, sequence, shape, body), "a follow-up waiting on the only escape makes the pair inescapable")
	_check(ORACLE.has_escape(Vector2(0, 160), sequence, shape, body), "the same pair from beside the boss keeps a route")

	# World geometry vetoes a walk.
	var open_court := func(_from: Vector2, _to: Vector2) -> bool: return true
	var boxed_in := func(_from: Vector2, _to: Vector2) -> bool: return false
	_check(ORACLE.has_escape(contact, _slam(1.3), shape, body, open_court), "an open court keeps the slam's escape")
	_check(not ORACLE.has_escape(contact, _slam(1.3), shape, body, boxed_in), "walls across every walk veto the attack")

	# The player as it really moves: it turns to face its motion, keeps that
	# motion while reacting, walks one of eight keyboard directions, and at its
	# own permanent speed.
	var instant := [{"kind": &"circle", "center": Vector2(50, 0), "radius": 10.0, "from": 0.0, "to": 0.1}]
	var square_on := shape.duplicate()
	square_on["rotation"] = 0.0
	var corner_on := shape.duplicate()
	corner_on["rotation"] = PI * 0.25
	_check(ORACLE.has_escape(Vector2.ZERO, instant, square_on), "a hazard 15 px clear of the square's side misses it")
	_check(not ORACLE.has_escape(Vector2.ZERO, instant, corner_on), "the same hazard meets the square turned 45 degrees: the player's facing is part of its shape")
	var ahead := [{"kind": &"circle", "center": Vector2(60, 0), "radius": 10.0, "from": 0.0, "to": 0.2}]
	var still := shape.duplicate()
	still["velocity"] = Vector2.ZERO
	var closing := shape.duplicate()
	closing["velocity"] = Vector2(100, 0)
	_check(ORACLE.has_escape(Vector2.ZERO, ahead, still), "standing 25 px clear, the player has time")
	_check(not ORACLE.has_escape(Vector2.ZERO, ahead, closing), "walking into it at commitment, the reaction carries the player on into it")
	var keyboard_route = ORACLE.escape_route(contact, _slam(1.3), shape, body)
	var on_grid := false
	if keyboard_route is Vector2 and not (keyboard_route as Vector2).is_zero_approx():
		var step := fposmod((keyboard_route as Vector2).angle(), PI * 0.25)
		on_grid = is_zero_approx(step) or is_equal_approx(step, PI * 0.25)
	_check(on_grid, "routes are keyboard directions, multiples of 45 degrees")
	_check(not ORACLE.has_escape(contact, _slam(1.3), shape, body, Callable(), 80.0), "the 1.3 s slam from contact traps an 80 px/s player")
	var slow := WalkSpeed.new()
	slow.speed = 80.0
	var quick := WalkSpeed.new()
	quick.speed = 300.0
	_check(is_equal_approx(ORACLE.walking_speed(slow), 80.0) and is_equal_approx(ORACLE.walking_speed(quick), ORACLE.BASE_SPEED) and is_equal_approx(ORACLE.walking_speed(null), ORACLE.BASE_SPEED), "each player walks at its own speed, never above the 100 px/s baseline")
	slow.free()
	quick.free()
	_check(is_equal_approx(ORACLE.walking_clearance(shape), 29.0), "corridors clear the capsule's crosswise half length")
	_finish()


class WalkSpeed:
	extends Node
	var speed := 100.0


func _finish() -> void:
	print("BossEscapeOracleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
