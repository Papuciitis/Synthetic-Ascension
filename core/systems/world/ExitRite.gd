extends Node2D
class_name ExitRite

signal cleared(rite: ExitRite)

@export var radius: float = 92.0
@export var hold_time: float = 3.0
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
var _hold: float = 0.0
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
		_hold = 0.0
		_burst_stage = 0
		queue_redraw()
		return

	# A dead body inside the circle must not keep channeling the rite
	# (same guard DistrictRelayObjective got for the same bug).
	var channeling_player := get_tree().get_first_node_in_group("player")
	if channeling_player != null and bool(channeling_player.get("is_dead")):
		_hold = 0.0
		_burst_stage = 0
		queue_redraw()
		return

	_hold = minf(_hold + delta, hold_time)
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

func _maybe_spawn_bursts(t: float) -> void:
	# Near the end of the hold, spike pressure so the last second feels scary.
	if _spawner == null or not is_instance_valid(_spawner):
		return

	# 3 stages: mild -> medium -> panic
	if _burst_stage < 1 and t >= 0.55:
		_spawner.spawn_burst(2)
		_burst_stage = 1
		return
	if _burst_stage < 2 and t >= 0.80:
		_spawner.spawn_burst(4)
		_burst_stage = 2
		return
	if _burst_stage < 3 and t >= 0.95:
		_spawner.spawn_burst(6)
		_burst_stage = 3

func _on_body_entered(b: Node) -> void:
	if b == null:
		return
	if not b.is_in_group("player"):
		return

	if locked:
		# Not ready yet -> shove the player out a bit (keeps you in the same segment)
		var p := b as Node2D
		if p != null:
			var d := (p.global_position - global_position)
			if d.length() < 0.001:
				d = Vector2.RIGHT
			p.global_position += d.normalized() * backlash_push
		if b.has_method("grant_invulnerability"):
			b.call("grant_invulnerability", backlash_invuln)
		return

	_player_inside = true
	add_to_group(&"exit_rite_channeling")
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
		var prog := Color(0.98, 0.92, 0.55, 0.98)
		# main stroke
		draw_arc(Vector2.ZERO, radius + 11.0, -PI/2, -PI/2 + TAU * t, 96, prog, 10.0, true)
		# soft glow fill
		draw_arc(Vector2.ZERO, radius + 4.0, -PI/2, -PI/2 + TAU * t, 96, Color(prog.r, prog.g, prog.b, 0.32), 18.0, true)
