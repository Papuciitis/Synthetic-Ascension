extends Node2D
class_name ExitRite

signal cleared(rite: ExitRite)

## Room to fight in. At 92 px the circle was barely wider than the player, so
## "hold this ground" meant "stand on this spot" - there was nowhere to dodge
## that was not also outside. A siege needs a courtyard.
@export var radius: float = 168.0
## THE RITE IS A SIEGE, NOT A BUTTON.
##
## This was three seconds. After a whole segment of Threat climbing, objectives
## and the decision of when to leave, the climax was standing still for three
## seconds - and _maybe_spawn_bursts fired its "mild -> medium -> panic" stages
## at 1.65s, 2.4s and 2.85s, so all three waves spawned inside the final second
## and the rite completed before any of them could reach the player. The whole
## escalation existed and could not be experienced.
##
## Long enough now that the bursts land, the Threat you built is spent on you,
## and leaving is something you have to survive rather than something you walk
## into. This is the moment the segment has been building toward; it should cost
## something.
@export var hold_time: float = 20.0

## Stepping out DRAINS the channel instead of voiding it.
##
## Zeroing on exit makes the only correct play "stand in the circle and pray",
## which is not a fight - it is a dare with no counterplay, and one unlucky
## charger costs the whole rite. Draining at a fraction of the fill rate means
## dodging out to reposition is a real option that costs real progress, so the
## rite becomes what it should be: hold this ground, give it up when you must,
## take it back.
@export var lapse_drain_rate: float = 0.45

## The rite's own resonance: the channel keeps drawing while you are away, and
## a player who abandons it entirely still loses everything - just not instantly.
@export var lapse_grace: float = 1.5

## What a death costs the channel.
##
## Dying used to give the whole rite back, which sounds fair and plays terribly:
## twenty seconds of escalating waves is exactly when a death is likeliest, and
## losing all of it means the second attempt is the same twenty seconds against
## a higher Threat with fewer Followers. That is a run ending in a place the
## player already earned their way to. Keeping most of it makes a death a
## setback in a fight you are still winning, which is what a death should be.
@export_range(0.0, 1.0, 0.05) var death_progress_kept: float = 0.6

## Standing in the sigil closes your wounds.
##
## The Rite is the densest fight in the segment and it is the one you cannot
## walk away from, so the circle has to be worth standing in for reasons other
## than the objective. It also gives the drain a counterweight: ducking out to
## survive costs progress AND the mending, so holding the ground is the play
## and leaving is the concession.
@export var channel_regen_per_sec: float = 2.6

## Fraction of max HP per second, added to the flat rate above, so the mending
## still means something at a large health pool.
@export_range(0.0, 0.10, 0.001) var channel_regen_max_hp_pct: float = 0.012
@export var locked: bool = true
@export var narrative_mode: bool = false
@export var hide_location_while_locked: bool = false
@export var revealed: bool = true

@export var backlash_push: float = 150.0
@export var backlash_invuln: float = 0.4

@onready var zone: Area2D = $Zone
@onready var shape: CollisionShape2D = $Zone/CollisionShape2D
@onready var sigil: Sprite2D = $Sigil
@onready var vfx: Node2D = $Vfx

const UNLOCK_BURST_SCENE := preload("res://assets/vfx/world/gates/VFX_GateUnlockBurst.tscn")

var _player_inside: bool = false
var _last_backlash_ms: int = -100000
var _hold: float = 0.0
var _lapse: float = 0.0
var _death_taken: bool = false
var _announced_channel: bool = false
var _sigil_t: float = 0.0

# Optional: lets the gate "call" extra spawns near the end of the hold.
var _spawner: EnemySpawner = null
var _burst_stage: int = 0

var _sfx_channel_tag: StringName = &"channel"

func _ready() -> void:
	if shape != null and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = radius
	if zone != null:
		zone.body_entered.connect(_on_body_entered)
		zone.body_exited.connect(_on_body_exited)

	if sigil != null:
		sigil.rotation = randf() * TAU
		_sigil_refresh()

	# Cache spawner (best-effort). This makes the final seconds of the hold feel tense.
	_spawner = get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	if _spawner == null:
		var root := get_tree().current_scene
		if root != null:
			_spawner = root.get_node_or_null("Spawner") as EnemySpawner

	set_process(true)
	queue_redraw()
	_apply_reveal_state()

	# Apply attempt modifier (major choice)
	if Global != null:
		hold_time *= clampf(float(Global.attempt_exit_hold_mul), 0.25, 2.0)

	# Share gate location with HUD (for direction arrow, etc.)
	_share_location_with_hud()

func _exit_tree() -> void:
	if Global != null and Global.exit_gate_pos == global_position:
		Global.exit_gate_pos = Vector2.INF

func set_locked(v: bool) -> void:
	# IMPORTANT: Level1Builder calls this on every kill.
	# If the state didn't actually change, don't reset the hold/progress.
	if locked == v:
		queue_redraw()
		_sigil_refresh()
		_share_location_with_hud()
		return

	var was_locked := locked
	locked = v
	queue_redraw()
	_sigil_refresh()

	# State changed > reset channel state.
	_hold = 0.0
	_burst_stage = 0
	if locked:
		_player_inside = false
		remove_from_group(&"exit_rite_channeling")
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("stop_loop", self, _sfx_channel_tag)

	# On unlock: punchy but cheap VFX
	if was_locked and (not locked):
		if vfx != null:
			var b := UNLOCK_BURST_SCENE.instantiate()
			vfx.add_child(b)
			if b.has_method("setup"):
				b.call("setup", global_position)
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("play_2d", &"exit_unlock", global_position)

	# Share gate location with HUD (for direction arrow, etc.)
	_share_location_with_hud()

func set_revealed(value: bool) -> void:
	if revealed == value:
		_apply_reveal_state()
		return
	revealed = value
	_hold = 0.0
	_player_inside = false
	_burst_stage = 0
	_apply_reveal_state()

func _apply_reveal_state() -> void:
	visible = revealed
	if zone != null:
		zone.set_deferred("monitoring", revealed)
		zone.set_deferred("monitorable", revealed)
	if not revealed:
		remove_from_group(&"exit_rite_channeling")
	_share_location_with_hud()

func _sigil_refresh() -> void:
	if sigil == null:
		return
	# Locked -> dim, unlocked -> brighter
	sigil.modulate.a = 0.10 if locked else 0.22

func _process(delta: float) -> void:
	# Share gate location with HUD every frame (the HUD arrow reads this).
	_share_location_with_hud()
	if not revealed:
		return

	_sigil_t += delta
	if sigil != null:
		sigil.rotation += (0.06 if locked else 0.14) * delta
		var breathe := 0.9 + 0.1 * sin(_sigil_t * 1.15)
		sigil.modulate.a = (0.10 if locked else 0.22) * breathe

	if locked:
		_hold = 0.0
		_burst_stage = 0
		queue_redraw()
		return

	if not _player_inside:
		# Drain rather than void. See lapse_drain_rate.
		if _hold > 0.0:
			_lapse += delta
			if _lapse > lapse_grace:
				_hold = maxf(0.0, _hold - delta * lapse_drain_rate * _fill_rate())
				# The waves rewind with the channel. Without this a player who
				# drains back from 94% walks into a SILENT rite: every stage was
				# already spent, so the 30% they now have to redo spawns nothing.
				_resync_burst_stage()
			queue_redraw()
		return
	_lapse = 0.0

	# A dead body inside the circle must not keep channeling the rite
	# (same guard DistrictRelayObjective got for the same bug).
	var channeling_player := get_tree().get_first_node_in_group("player")
	if channeling_player != null and bool(channeling_player.get("is_dead")):
		# A death is a setback, not a reset. See death_progress_kept.
		if not _death_taken:
			_death_taken = true
			_hold *= clampf(death_progress_kept, 0.0, 1.0)
			# The waves re-arm from wherever the channel now stands, so the
			# second attempt is not the whole escalation over again.
			_resync_burst_stage()
		_lapse = 0.0
		queue_redraw()
		return
	_death_taken = false

	_hold = minf(_hold + delta, hold_time)
	_mend(channeling_player, delta)
	queue_redraw()

	var t: float = 0.0
	if hold_time > 0.0:
		t = clampf(_hold / hold_time, 0.0, 1.0)
	_maybe_spawn_bursts(t)

	if _hold >= hold_time:
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("stop_loop", self, _sfx_channel_tag)
			sm.call("play_2d", &"exit_complete", global_position)
		remove_from_group(&"exit_rite_channeling")
		cleared.emit(self)
		set_process(false)

## How fast the channel fills. One place, so the drain can be expressed as a
## fraction of it and the two can never drift.
func _fill_rate() -> float:
	return 1.0


## Waves across the WHOLE channel, escalating. Spread out rather than stacked at
## the end: the player needs time to feel each wave arrive, fight it, and watch
## the next one come - which is the difference between a siege and a jump scare.
const BURST_STAGES: Array[Vector2] = [
	Vector2(0.10, 2.0),
	Vector2(0.26, 3.0),
	Vector2(0.42, 4.0),
	Vector2(0.58, 5.0),
	Vector2(0.72, 6.0),
	Vector2(0.85, 8.0),
	Vector2(0.94, 10.0),
]


## Hold the ground, close your wounds. Deliberately generous - this is the one
## fight in the segment the player is not allowed to walk away from.
func _mend(who: Node, delta: float) -> void:
	if who == null or not is_instance_valid(who) or not who.has_method("heal"):
		return
	var max_hp_value: Variant = who.get("max_hp")
	if not (max_hp_value is float or max_hp_value is int):
		return
	var max_hp: float = float(max_hp_value)
	var amount: float = (channel_regen_per_sec + max_hp * channel_regen_max_hp_pct) * delta
	if amount > 0.0:
		who.call("heal", amount)


## After a death the channel jumps backwards, so the wave schedule has to jump
## with it - otherwise every stage is already spent and the rest of the rite is
## silent.
func _resync_burst_stage() -> void:
	var t: float = 0.0
	if hold_time > 0.0:
		t = clampf(_hold / hold_time, 0.0, 1.0)
	_burst_stage = 0
	for stage in BURST_STAGES:
		if t >= stage.x:
			_burst_stage += 1


func _maybe_spawn_bursts(t: float) -> void:
	if _spawner == null or not is_instance_valid(_spawner):
		return
	while _burst_stage < BURST_STAGES.size():
		var stage: Vector2 = BURST_STAGES[_burst_stage]
		if t < stage.x:
			return
		_burst_stage += 1
		_spawner.spawn_burst(int(stage.y))
		return

func _on_body_entered(b: Node) -> void:
	if b == null:
		return
	if not b.is_in_group("player"):
		return

	if locked:
		# Not ready yet -> the rite rejects the intruder. The old instant
		# global_position += 150px read as a random teleport (and could
		# two-stage pop through streamed colliders). Now: debounced, a
		# short slide instead of a snap, and it SAYS what happened.
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_backlash_ms < 1500:
			return
		_last_backlash_ms = now_ms
		var p := b as Node2D
		if p != null:
			var d := (p.global_position - global_position)
			if d.length() < 0.001:
				d = Vector2.RIGHT
			var target := p.global_position + d.normalized() * backlash_push
			var tween := create_tween()
			tween.tween_property(p, "global_position", target, 0.15)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if b.has_method("grant_invulnerability"):
			b.call("grant_invulnerability", backlash_invuln)
		if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
			RunEvents.tutorial_tip.emit("The rite rejects you — it is not ready.", 2.0)
		return

	_player_inside = true
	add_to_group(&"exit_rite_channeling")
	# Say what the player has just committed to, once. Twenty seconds of
	# escalating waves with no warning reads as the game breaking, not as a
	# siege - and the decision to start it is only a decision if they know.
	if not _announced_channel and RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		_announced_channel = true
		RunEvents.tutorial_tip.emit(
			"The Rite draws for %ds. Hold the circle - step out and it bleeds back." % int(round(hold_time)),
			4.0
		)
	var sm := get_node_or_null("/root/SfxManager")
	if sm != null:
		sm.call("ensure_loop_2d", self, _sfx_channel_tag, &"exit_channel_loop")

	# Level 1 tutorial: teach the "hold the zone to exit" loop (one-shot).
	if Global != null and (not Global.tip_shown_gate_hold):
		Global.tip_shown_gate_hold = true
		if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
			if narrative_mode:
				RunEvents.tutorial_tip.emit("Rewrite the Rite • Remain within the sigil", 3.5)
			else:
				RunEvents.tutorial_tip.emit("Hold within the Gate to Escape", 3.0)

func _on_body_exited(b: Node) -> void:
	if b != null and b.is_in_group("player"):
		_player_inside = false
		remove_from_group(&"exit_rite_channeling")
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("stop_loop", self, _sfx_channel_tag)

func _share_location_with_hud() -> void:
	if Global == null:
		return
	Global.exit_gate_pos = Vector2.INF if (not revealed) or (hide_location_while_locked and locked) else global_position

func _draw() -> void:
	# Readability pass: thicker ring + higher contrast progress so players
	# instantly understand "stand here and channel".
	var c_locked := Color(0.55, 0.25, 0.25, 0.48)
	var c_ready := Color(0.35, 0.85, 0.98, 0.62)
	var c := c_locked if locked else c_ready
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, c, 4.0, true)

	if not locked and hold_time > 0.0:
		var t := clampf(_hold / hold_time, 0.0, 1.0)
		# Losing the channel has to be as loud as gaining it, or a player who
		# stepped out to dodge cannot tell what it cost them.
		var draining: bool = not _player_inside and _hold > 0.0 and _lapse > lapse_grace
		var prog := Color(0.99, 0.44, 0.30, 0.98) if draining else Color(0.98, 0.92, 0.55, 0.98)
		# main stroke
		draw_arc(Vector2.ZERO, radius + 11.0, -PI/2, -PI/2 + TAU * t, 96, prog, 10.0, true)
		# soft glow fill
		draw_arc(Vector2.ZERO, radius + 4.0, -PI/2, -PI/2 + TAU * t, 96, Color(prog.r, prog.g, prog.b, 0.32), 18.0, true)
