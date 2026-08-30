extends Node2D
class_name ExitRite

signal cleared(rite: ExitRite)
signal safeguard_state_changed(current: int, capacity: int, can_invoke: bool)

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

## THE WORLD REALISES YOU ARE LEAVING (plan 2.8; vision "The Exit Rite").
##
## From this fraction of the hold the district visibly warps: the rite reports
## a distortion level that climbs 0..1 with the channel on
## RunEvents.rite_distortion_changed and the VisionRig tints the screen to it.
## A static ramp - it only ever moves with progress - and it falls back to 0
## the moment the channel lapses past its grace, the player dies, or the rite
## resets or clears.
@export_range(0.0, 1.0, 0.01) var distortion_start_fraction: float = 0.5

## LAST CHANCE (plan 2.8): once per channel, at this fraction of the hold, a
## Cursed Vault appears at the rite's edge on the far side from the player -
## a guaranteed Manifestation for every safeguard the rite holds. Its opening
## spot lies mostly outside the circle, so taking it means feeding the drain;
## that is the tension, and the drain is untouched.
@export_range(0.0, 1.0, 0.01) var last_chance_fraction: float = 0.85

## How far past the rite's radius the vault sits. Against the vault's 64 px
## open radius, 32 leaves a sliver of the circle it can be opened from
## without lapsing - a precise stand, not a free lunch.
@export var last_chance_edge_offset: float = 32.0
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
const RITE_PROGRESS_LEDGER_SCRIPT: Script = preload("res://core/systems/world/rite/RiteProgressLedger.gd")
const RITE_PULSE_RESOLVER_SCRIPT: Script = preload("res://core/systems/world/rite/RitePulseResolver.gd")
const RITE_PULSE_VFX_SCRIPT: Script = preload("res://core/systems/world/rite/RitePulseVFX.gd")
## The distortion ramp is reported in this many steps per channel, not once
## per frame: a few dozen shader writes across the whole hold.
const DISTORTION_STEPS: int = 32
## How long the 50% cue's line stays on the tip channel.
const DISTORTION_TIP_SECONDS: float = 3.5
const LAST_CHANCE_VAULT_NAME := "LastChanceVault"
## Each charge drain_safeguards spends leaves as a ring this fraction smaller
## than the one before it, so the rings read as a count.
const DRAIN_RING_SHRINK_PER_CHARGE: float = 0.18
const AUTOMATIC_PULSES: Array[Dictionary] = [
	{"radius": 420.0, "force": 650.0, "stun": 0.15, "heal": 0.15, "invuln": 0.0},
	{"radius": 500.0, "force": 850.0, "stun": 0.35, "heal": 0.25, "invuln": 0.0},
	{"radius": 620.0, "force": 1100.0, "stun": 0.60, "heal": 0.35, "invuln": 5.0},
]
const MANUAL_PULSE: Dictionary = {
	"radius": 420.0,
	"force": 700.0,
	"stun": 0.20,
	"heal": 0.10,
	"invuln": 0.0,
}

var _player_inside: bool = false
var _last_backlash_ms: int = -100000
var _hold: float = 0.0
var _lapse: float = 0.0
var _death_taken: bool = false
var _announced_channel: bool = false
var _sigil_t: float = 0.0
var _progress_ledger: RefCounted = RITE_PROGRESS_LEDGER_SCRIPT.new()
var _safeguard_sources: Dictionary = {}
var _safeguards: int = 0
var _safeguard_capacity: int = 3
var _safeguard_source_multiplier: int = 1
var _burst_count_multiplier: float = 1.0
var _rite_stun_bonus_seconds: float = 0.0
var _completed: bool = false
var _distortion_level: float = 0.0
var _last_chance_vault: Node2D = null

# Optional: lets the gate "call" extra spawns near the end of the hold.
var _spawner: EnemySpawner = null
var _burst_stage: int = 0

var _sfx_channel_tag: StringName = &"channel"

func _ready() -> void:
	add_to_group(&"exit_rite")
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
	configure_doctrine_rules()

	# Share gate location with HUD (for direction arrow, etc.)
	_share_location_with_hud()
	_emit_safeguard_state()

func _exit_tree() -> void:
	# A rite freed mid-channel must not leave the screen warped.
	_set_distortion(0.0)
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
	_progress_ledger = RITE_PROGRESS_LEDGER_SCRIPT.new()
	_completed = false
	configure_doctrine_rules()
	_reset_channel_extras()
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
	_progress_ledger = RITE_PROGRESS_LEDGER_SCRIPT.new()
	_completed = false
	configure_doctrine_rules()
	_reset_channel_extras()
	_apply_reveal_state()

func _apply_reveal_state() -> void:
	visible = revealed
	if zone != null:
		zone.set_deferred("monitoring", revealed)
		zone.set_deferred("monitorable", revealed)
	if not revealed:
		remove_from_group(&"exit_rite_channeling")
	_share_location_with_hud()
	_emit_safeguard_state()

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
		queue_redraw()
		return

	if not _player_inside:
		# Drain rather than void. See lapse_drain_rate.
		if _hold > 0.0:
			_lapse += delta
			if _lapse > lapse_grace:
				_apply_progress_loss(_hold - delta * lapse_drain_rate * _fill_rate())
				# The warp is the rite drawing on you. Past the grace it is
				# not - the same moment the ring turns red, so a short dodge
				# does not blink the screen.
				_set_distortion(0.0)
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
			_apply_progress_loss(_hold * clampf(death_progress_kept, 0.0, 1.0))
			_lapse = 0.0
		_set_distortion(0.0)
		queue_redraw()
		return
	_death_taken = false

	_hold = minf(_hold + delta, hold_time)
	_mend(channeling_player, delta)
	_update_rite_progress()
	queue_redraw()

	var t: float = 0.0
	if hold_time > 0.0:
		t = clampf(_hold / hold_time, 0.0, 1.0)
	_set_distortion(_distortion_level_for(t))
	_maybe_spawn_bursts(t)

	if _hold >= hold_time:
		_completed = true
		_emit_safeguard_state()
		# The world stops warping and the last chance is gone: you are leaving.
		_reset_channel_extras()
		# Escape looking like a god: one last, larger pulse before the segment
		# completes (roadmap 2.8).
		_apply_pulse(_climax_pulse_profile())
		_spawn_pulse_vfx(_climax_pulse_profile())
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
		who.call("heal", amount, &"exit_rite")


func _apply_progress_loss(proposed_hold: float) -> void:
	if hold_time <= 0.0:
		_hold = 0.0
		return
	var fraction: float = float(_progress_ledger.call("clamp_loss_fraction", proposed_hold / hold_time))
	_hold = fraction * hold_time


func _update_rite_progress() -> void:
	if hold_time <= 0.0:
		return
	var fraction := _hold / hold_time
	var crossed: PackedInt32Array = _progress_ledger.call("update_fraction", fraction)
	for seal_number in crossed:
		_fire_automatic_seal(seal_number)
	if fraction >= last_chance_fraction and bool(_progress_ledger.call("mark_once", &"last_chance")):
		_spawn_last_chance_vault()


## Where the 50% cue stands for a hold fraction: 0 until the start fraction,
## 1 at a full hold, straight between - monotone with progress.
func _distortion_level_for(fraction: float) -> float:
	var start := clampf(distortion_start_fraction, 0.0, 0.999)
	return clampf((fraction - start) / (1.0 - start), 0.0, 1.0)


## Reports the level in DISTORTION_STEPS steps, only when a step changes: a
## handful of signals across the whole channel, none while it sits at 0.
func _set_distortion(level: float) -> void:
	var stepped := floorf(clampf(level, 0.0, 1.0) * float(DISTORTION_STEPS)) / float(DISTORTION_STEPS)
	if is_equal_approx(stepped, _distortion_level):
		return
	var rising_from_zero := _distortion_level <= 0.0 and stepped > 0.0
	_distortion_level = stepped
	if RunEvents != null and RunEvents.has_signal("rite_distortion_changed"):
		RunEvents.rite_distortion_changed.emit(stepped)
	if rising_from_zero:
		_on_distortion_started()


func _on_distortion_started() -> void:
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"rite_distortion_started", 1)
	# Teach it once: a screen that turns colour with no word reads as a bug.
	if RunEvents == null or not RunEvents.has_signal("tutorial_tip"):
		return
	if not Global.teach_once(&"rite_distortion"):
		return
	RunEvents.tutorial_tip.emit("The Rite is half drawn — the district warps. Hold the circle.", DISTORTION_TIP_SECONDS)


## The distortion and the last-chance vault belong to one channel; a reset
## takes both (their once-per-channel marks live in the ledger, which is
## recreated on the same paths).
func _reset_channel_extras() -> void:
	_set_distortion(0.0)
	_despawn_last_chance_vault()


## LAST CHANCE. A child of the rite, so it shares the rite's visibility and
## lifetime; its opening disc overlaps the circle's edge on the far side from
## the player, so reaching it means crossing the circle first.
func _spawn_last_chance_vault() -> void:
	_despawn_last_chance_vault()
	var away := Vector2.RIGHT.rotated(randf() * TAU)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		var toward_player := player.global_position - global_position
		if toward_player.length_squared() > 1.0:
			away = -toward_player.normalized()
	var no_beats: Array[StringName] = []
	var vault := CursedVault.new()
	vault.name = LAST_CHANCE_VAULT_NAME
	vault.guarantee_manifestation = true
	vault.cost_beats = no_beats
	vault.cost_all_safeguards = true
	vault.announce_label = "LAST CHANCE"
	vault.announce_line = "LAST CHANCE — a vault at the rite's edge: a guaranteed Manifestation."
	vault.position = away * (radius + last_chance_edge_offset)
	add_child(vault)
	_last_chance_vault = vault
	# The vault announces itself, now: one popup and one line, the line being
	# its own sign with the whole bill on it. Its approach check next frame
	# finds it already said, so nothing overdraws it.
	vault.announce()
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"rite_last_chance_spawned", 1, {"safeguards": _safeguards})


func _despawn_last_chance_vault() -> void:
	if _last_chance_vault != null and is_instance_valid(_last_chance_vault):
		_last_chance_vault.queue_free()
	_last_chance_vault = null


func last_chance_vault() -> Node2D:
	if _last_chance_vault != null and is_instance_valid(_last_chance_vault) and not _last_chance_vault.is_queued_for_deletion():
		return _last_chance_vault
	return null


func distortion_level() -> float:
	return _distortion_level


func _fire_automatic_seal(seal_number: int) -> void:
	var index := seal_number - 1
	if index < 0 or index >= AUTOMATIC_PULSES.size():
		return
	_apply_pulse(_automatic_pulse_profile(index))
	queue_redraw()


func _climax_pulse_profile() -> Dictionary:
	var profile := AUTOMATIC_PULSES[AUTOMATIC_PULSES.size() - 1].duplicate(true)
	profile["radius"] = float(profile.get("radius", 620.0)) * 1.5
	profile["stun"] = maxf(float(profile.get("stun", 0.6)), 1.0)
	return profile


func _automatic_pulse_profile(index: int) -> Dictionary:
	if index < 0 or index >= AUTOMATIC_PULSES.size():
		return {}
	var profile := AUTOMATIC_PULSES[index].duplicate(true)
	profile["stun"] = float(profile.get("stun", 0.0)) + _rite_stun_bonus_seconds
	return profile


func _apply_pulse(profile: Dictionary) -> Dictionary:
	_spawn_pulse_vfx(profile)
	var player := get_tree().get_first_node_in_group(&"player")
	return RITE_PULSE_RESOLVER_SCRIPT.call("apply",
		EnemyCombat,
		global_position,
		float(profile.get("radius", 0.0)),
		float(profile.get("force", 0.0)),
		float(profile.get("stun", 0.0)),
		player,
		float(profile.get("heal", 0.0)),
		float(profile.get("invuln", 0.0))
	)


func _spawn_pulse_vfx(profile: Dictionary) -> void:
	if vfx == null:
		return
	var pulse := RITE_PULSE_VFX_SCRIPT.new() as Node2D
	pulse.name = "RitePulseVFX"
	vfx.add_child(pulse)
	pulse.call(
		"setup",
		float(profile.get("radius", 420.0)),
		float(profile.get("invuln", 0.0)) > 0.0
	)


func _maybe_spawn_bursts(t: float) -> void:
	if _spawner == null or not is_instance_valid(_spawner):
		return
	while _burst_stage < BURST_STAGES.size():
		var current_index := _burst_stage
		var stage: Vector2 = BURST_STAGES[current_index]
		if t < stage.x:
			return
		_burst_stage += 1
		if bool(_progress_ledger.call("mark_wave_spent", current_index)):
			_spawner.spawn_burst(_burst_spawn_count(int(stage.y)))
		return


func _burst_spawn_count(base_count: int) -> int:
	return maxi(0, ceili(float(base_count) * _burst_count_multiplier))


func grant_safeguard(source_key: StringName, amount: int = 1) -> int:
	if source_key == StringName() or amount <= 0 or _safeguard_sources.has(source_key):
		return 0
	_safeguard_sources[source_key] = true
	var before := _safeguards
	_safeguards = mini(_safeguard_capacity, _safeguards + amount * _safeguard_source_multiplier)
	_emit_safeguard_state()
	queue_redraw()
	return _safeguards - before


func consume_safeguard() -> bool:
	if not can_invoke_safeguard():
		return false
	_safeguards -= 1
	_apply_pulse(MANUAL_PULSE)
	_emit_safeguard_state()
	queue_redraw()
	return true


## The last-chance vault's price: every charge, at once. Not consume_safeguard
## in a loop - that refuses unless the player stands inside the circle (the
## vault's opening spot mostly does not), and each call fires the manual
## pulse, so the "cost" would heal and stun on the player's behalf. The
## charges leave as rings only: the buffer is seen going, nothing is gained.
func drain_safeguards(reason: StringName = &"") -> int:
	var drained := _safeguards
	if drained <= 0:
		return 0
	_safeguards = 0
	for index in range(drained):
		_spawn_pulse_vfx({
			"radius": float(MANUAL_PULSE.get("radius", 420.0)) * (1.0 - DRAIN_RING_SHRINK_PER_CHARGE * float(index)),
			"invuln": 0.0,
		})
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"rite_safeguards_drained", drained, {"reason": String(reason)})
	_emit_safeguard_state()
	queue_redraw()
	return drained


func safeguard_count() -> int:
	return _safeguards


func safeguard_capacity() -> int:
	return _safeguard_capacity


func can_invoke_safeguard() -> bool:
	return revealed and not locked and not _completed and _player_inside and _safeguards > 0


func _emit_safeguard_state() -> void:
	safeguard_state_changed.emit(_safeguards, _safeguard_capacity, can_invoke_safeguard())


func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	if consume_safeguard():
		get_viewport().set_input_as_handled()


func configure_doctrine_rules() -> void:
	_safeguard_capacity = 3
	_safeguard_source_multiplier = 1
	_burst_count_multiplier = 1.0
	_rite_stun_bonus_seconds = 0.0
	var initial_seals := 0
	if Global != null and Global.has_method("get_doctrine_rule"):
		_safeguard_capacity = maxi(1, int(Global.get_doctrine_rule(&"rite_safeguard_capacity", 3)))
		_safeguard_source_multiplier = maxi(1, int(Global.get_doctrine_rule(&"rite_safeguard_source_multiplier", 1)))
		_burst_count_multiplier = maxf(0.0, float(Global.get_doctrine_rule(&"rite_burst_count_mul", 1.0)))
		_rite_stun_bonus_seconds = maxf(0.0, float(Global.get_doctrine_rule(&"rite_stun_bonus_seconds", 0.0)))
		initial_seals = clampi(int(Global.get_doctrine_rule(&"rite_initial_seals", 0)), 0, 2)
	_safeguards = mini(_safeguards, _safeguard_capacity)
	if initial_seals > 0 and hold_time > 0.0:
		_progress_ledger.call("initialize_sealed", initial_seals)
		_hold = float(_progress_ledger.call("floor_fraction")) * hold_time
		_burst_stage = 0
		while _burst_stage < BURST_STAGES.size() and BURST_STAGES[_burst_stage].x <= float(_progress_ledger.call("floor_fraction")):
			_progress_ledger.call("mark_wave_spent", _burst_stage)
			_burst_stage += 1
	_emit_safeguard_state()
	queue_redraw()

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
	_emit_safeguard_state()
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
		_emit_safeguard_state()
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

	# Three physical archive seals: channel thirds are durable.
	for seal_index in range(3):
		var angle := deg_to_rad(-150.0 + 60.0 * float(seal_index))
		var center := Vector2.from_angle(angle) * (radius + 22.0)
		var sealed: bool = seal_index < int(_progress_ledger.call("sealed_count"))
		var seal_color := Color(0.98, 0.83, 0.48, 0.95) if sealed else Color(0.42, 0.32, 0.22, 0.62)
		var points := PackedVector2Array([
			center + Vector2(0.0, -7.0), center + Vector2(7.0, 0.0),
			center + Vector2(0.0, 7.0), center + Vector2(-7.0, 0.0),
		])
		draw_colored_polygon(points, Color(seal_color.r, seal_color.g, seal_color.b, 0.18))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), seal_color, 2.0, true)

	# Safeguards are a separate physical ledger. Pilgrim Engine raises this to
	# five, so coupling them to the three archive seals hid the last two charges.
	var pip_positions := safeguard_pip_positions()
	for pip_index in range(pip_positions.size()):
		var pip_center := pip_positions[pip_index]
		draw_circle(pip_center, 4.5, Color(0.12, 0.10, 0.07, 0.90))
		draw_arc(pip_center, 5.0, 0.0, TAU, 20, Color(0.70, 0.49, 0.22, 0.85), 1.5, true)
		if pip_index < _safeguards:
			draw_circle(pip_center, 2.7, Color(1.0, 0.91, 0.62, 1.0))


func safeguard_pip_positions() -> PackedVector2Array:
	var output := PackedVector2Array()
	var count := maxi(1, _safeguard_capacity)
	for index in range(count):
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		var angle := lerpf(deg_to_rad(35.0), deg_to_rad(145.0), ratio)
		output.append(Vector2.from_angle(angle) * (radius + 23.0))
	return output
