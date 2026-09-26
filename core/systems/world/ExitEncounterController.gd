extends RefCounted
class_name ExitEncounterController
## The exit encounter's lifecycle (authored plan 2026-09-17 §6.1, wired for
## the 2026-09-26 playtest finding 4): once a player has engaged an eligible
## exit, the encounter stays active through channel-edge exits and ordinary
## dodges. It ends by DISENGAGING — 8 continuous living seconds beyond the
## release radius — by completing the rite, or by scene cleanup.
##
## Owned by the current ExitRite, never a global singleton. Channel PROGRESS
## remains owned by the rite: proximity never fills the channel, this class
## only says whether the encounter (and so the ambient-spawn suppression the
## ThreatDirector/EncounterDirector chain derives from it) is live.

signal state_changed(state: StringName)

const ENTRY_RADIUS_PX := 1200.0
const RELEASE_RADIUS_PX := 1800.0
const RELEASE_SECONDS := 8.0
const RECOVERY_HOLD_SECONDS := 10.0

const STATE_INACTIVE := &"inactive"
const STATE_APPROACH := &"approach"
const STATE_CHANNEL := &"channel"
const STATE_RECOVERY := &"recovery"
const STATE_COMPLETED := &"completed"

var _state: StringName = STATE_INACTIVE
var _release_outside_seconds: float = 0.0
var _recovery_left: float = 0.0
var _channeling: bool = false


func state() -> StringName:
	return _state


func is_active() -> bool:
	return _state == STATE_APPROACH or _state == STATE_CHANNEL or _state == STATE_RECOVERY


## The rite feeds this every gameplay frame: eligibility (unlocked AND
## revealed), the player's distance to the rite, whether the player lives,
## and the frame delta.
func update_state(eligible: bool, distance_px: float, alive: bool, delta: float) -> void:
	if _state == STATE_COMPLETED:
		return
	if not eligible:
		# A resealed or hidden rite has no encounter to keep alive.
		if _state != STATE_INACTIVE:
			_set_state(STATE_INACTIVE)
		return

	if _state == STATE_RECOVERY:
		# Recovery protection takes precedence over approach/channel
		# transitions until its hold expires (plan §6.1).
		_recovery_left -= delta
		if _recovery_left > 0.0:
			return
		_set_state(STATE_CHANNEL if _channeling else STATE_APPROACH)

	match _state:
		STATE_INACTIVE:
			if distance_px <= ENTRY_RADIUS_PX:
				_release_outside_seconds = 0.0
				_set_state(STATE_APPROACH)
		STATE_APPROACH, STATE_CHANNEL:
			if _channeling:
				if _state != STATE_CHANNEL:
					_set_state(STATE_CHANNEL)
				_release_outside_seconds = 0.0
				return
			if _state != STATE_APPROACH:
				_set_state(STATE_APPROACH)
			# Disengagement is deliberate: continuously outside the release
			# radius, alive, for the full window. Any re-entry resets it.
			if distance_px > RELEASE_RADIUS_PX and alive:
				_release_outside_seconds += delta
				if _release_outside_seconds >= RELEASE_SECONDS:
					_set_state(STATE_INACTIVE)
			else:
				_release_outside_seconds = 0.0


## Real channel membership, straight from the rite's Area2D. A channel-edge
## exit drops back to approach — never to inactive.
func set_channeling(active: bool) -> void:
	_channeling = active
	if _state == STATE_COMPLETED or _state == STATE_RECOVERY:
		return
	if active and is_active():
		_set_state(STATE_CHANNEL)
	elif not active and _state == STATE_CHANNEL:
		_release_outside_seconds = 0.0
		_set_state(STATE_APPROACH)


## Death/reconstruction inside an active encounter holds it active for at
## least the recovery window rather than letting the 8 s release run out
## while the player is being rebuilt.
func begin_recovery() -> void:
	if not is_active():
		return
	_recovery_left = RECOVERY_HOLD_SECONDS
	_release_outside_seconds = 0.0
	_set_state(STATE_RECOVERY)


## Terminal until scene cleanup: the completed rite never re-arms pressure.
func complete() -> void:
	_channeling = false
	_set_state(STATE_COMPLETED)


func _set_state(next: StringName) -> void:
	if _state == next:
		return
	_state = next
	if next != STATE_RECOVERY:
		_recovery_left = 0.0
	if next == STATE_INACTIVE or next == STATE_COMPLETED:
		_release_outside_seconds = 0.0
	state_changed.emit(next)


func describe() -> Dictionary:
	return {"state": String(_state), "channeling": _channeling,
		"release_outside_seconds": _release_outside_seconds, "recovery_left": _recovery_left}
