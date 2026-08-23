extends SceneTree

# PlayerDashState is a pure state machine with no scene tree, so its invariants
# are checked headlessly here rather than in the rendered probe.
# Run: <godot> --headless --path . -s res://tools/tests/PlayerDashStateTest.gd

var _passes := 0
var _failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _init() -> void:
	_test_invariants()
	_test_cooldown()
	_test_buffer()
	_test_direction_locks()
	print("PlayerDashStateTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _test_invariants() -> void:
	var dash := PlayerDashState.new()
	# The one that must never be broken by editing a single number: contact
	# damage resumes the moment invulnerability ends, so a dash that is still
	# phasing through a body at that point takes a hit from inside an enemy.
	_check(
		dash.iframe_time() >= PlayerDashState.DURATION,
		"i-frames last at least as long as the dash (%.2f >= %.2f)" % [dash.iframe_time(), PlayerDashState.DURATION]
	)
	_check(
		is_equal_approx(dash.speed() * PlayerDashState.DURATION, PlayerDashState.DISTANCE),
		"speed and duration agree with the authored distance"
	)
	_check(PlayerDashState.COOLDOWN > PlayerDashState.DURATION, "the dash is not permanently available")


func _test_cooldown() -> void:
	var dash := PlayerDashState.new()
	_check(dash.can_start(), "a fresh dash is available")
	dash.start(Vector2.RIGHT)
	_check(dash.is_dashing(), "starting a dash begins the travel window")
	_check(not dash.can_start(), "a dash cannot restart while it is running")

	dash.tick(PlayerDashState.DURATION + 0.01)
	_check(not dash.is_dashing(), "the travel window ends on time")
	_check(not dash.can_start(), "and the cooldown still blocks a restart")

	dash.tick(PlayerDashState.COOLDOWN)
	_check(dash.can_start(), "the cooldown eventually clears")


func _test_buffer() -> void:
	var dash := PlayerDashState.new()
	dash.start(Vector2.RIGHT)
	dash.tick(PlayerDashState.DURATION + 0.01)

	# Pressed while still on cooldown: the press should survive long enough to
	# fire the instant the cooldown clears. That forgiveness is what players
	# actually perceive as responsiveness.
	dash.request()
	_check(not dash.can_start(), "the buffered press does not fire early")
	dash.tick(PlayerDashState.BUFFER * 0.5)
	_check(dash.buffer_left > 0.0, "the press is still buffered a moment later")
	dash.tick(PlayerDashState.BUFFER)
	_check(not dash.consume_request(), "an expired press is forgotten rather than queued forever")


func _test_direction_locks() -> void:
	var dash := PlayerDashState.new()
	dash.start(Vector2(3.0, 0.0))
	_check(dash.direction.is_equal_approx(Vector2.RIGHT), "the dash direction is normalised")

	var locked := dash.direction
	dash.tick(0.05)
	_check(dash.direction == locked, "the direction is locked for the whole dash")

	dash.start(Vector2.ZERO)
	_check(dash.direction.length() > 0.0, "a zero direction falls back rather than stalling")

	dash.cancel()
	_check(not dash.is_dashing(), "cancelling ends the dash immediately")
