extends RefCounted
class_name PlayerDashState

## The dash's timing, as a pure state machine with no scene tree.
##
## Lives here rather than on the player for the same reason PlayerAimState does:
## it is testable headlessly, and player.gd is long enough already. The player
## owns the velocity write, the collision mask and the signal; this owns only
## when a dash may start and how long it lasts.

## Flat, deliberately NOT scaled by move speed. i-frames are a time window and
## distance is not: a dash whose range floats with a stat is a different move on
## every build, and a NEG movement curse would quietly become a defensive nerf
## on the verb the player relies on to survive.
const DISTANCE: float = 160.0
const DURATION: float = 0.20

## Flat, deliberately NOT scaled by Haste. The dash is a base verb every build
## has, like attacking; one learnable rhythm beats a survival budget that an
## offence stat silently retunes.
const COOLDOWN: float = 1.6

## Grace beyond the travel itself. i-frames are DERIVED from the duration so the
## invariant "invulnerable for at least as long as you are phasing" cannot be
## broken by editing one number - otherwise contact damage resumes mid-dash
## while the player is still inside an enemy.
const IFRAME_GRACE: float = 0.08

## Input forgiveness: a dash pressed just before the cooldown ends still fires.
const BUFFER: float = 0.12

## Matches the reporting threshold the game's other cooldowns use.
const REPORT_EPSILON: float = 0.05

var time_left: float = 0.0
var cooldown_left: float = 0.0
var buffer_left: float = 0.0
var direction: Vector2 = Vector2.RIGHT

var _last_reported: float = -1.0


func speed() -> float:
	return DISTANCE / maxf(DURATION, 0.001)


func iframe_time() -> float:
	return DURATION + IFRAME_GRACE


func is_dashing() -> bool:
	return time_left > 0.0


func can_start() -> bool:
	return time_left <= 0.0 and cooldown_left <= 0.0


func request() -> void:
	buffer_left = BUFFER


func consume_request() -> bool:
	if buffer_left <= 0.0:
		return false
	buffer_left = 0.0
	return true


func start(dir: Vector2) -> void:
	direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	time_left = DURATION
	cooldown_left = COOLDOWN
	buffer_left = 0.0


func cancel() -> void:
	time_left = 0.0
	buffer_left = 0.0


## Returns true when the cooldown moved enough to be worth reporting to a HUD.
func tick(delta: float) -> bool:
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
	if buffer_left > 0.0:
		buffer_left = maxf(0.0, buffer_left - delta)
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if absf(cooldown_left - _last_reported) < REPORT_EPSILON and cooldown_left > 0.0:
		return false
	_last_reported = cooldown_left
	return true


func reset() -> void:
	time_left = 0.0
	cooldown_left = 0.0
	buffer_left = 0.0
	_last_reported = -1.0
