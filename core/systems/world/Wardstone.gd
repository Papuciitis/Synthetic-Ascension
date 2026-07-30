extends Node2D
class_name Wardstone

signal activated(stone: Wardstone)

@export var capture_time: float = 2.0
@export var stability_radius: float = 220.0
@export_range(0.1, 1.0, 0.01) var stability_slow_mul: float = 0.85

@export var pulse_radius: float = 360.0
@export var pulse_force: float = 650.0
@export var pulse_stun: float = 0.15

@export var capture_zone_radius: float = 56.0
@export var narrative_index: int = 0 # 1/2 for authored Segment 1 Wardstones.

@onready var capture_zone: Area2D = $CaptureZone
@onready var capture_shape: CollisionShape2D = $CaptureZone/CollisionShape2D
@onready var stability_field: Area2D = $StabilityField
@onready var stability_shape: CollisionShape2D = $StabilityField/CollisionShape2D

@onready var sigil: Sprite2D = $Sigil
@onready var idle_aura: Node = $IdleAura
@onready var vfx_root: Node2D = $Vfx
@onready var obelisk: Sprite2D = $Obelisk

const ATTUNE_BURST_SCENE := preload("res://assets/vfx/world/wardstones/VFX_WardstoneAttuneBurst.tscn")

var _player_inside: bool = false
var _player: Node2D = null
var _capture: float = 0.0
var _active: bool = false
var _spin_t: float = 0.0
var _enemy_index: Node = null
var _pulse_targets: Array = []

var _sfx_capture_tag: StringName = &"capture"

func _ready() -> void:
	add_to_group(&"wardstones")

	# Setup shapes from exported radii
	if capture_shape != null and capture_shape.shape is CircleShape2D:
		(capture_shape.shape as CircleShape2D).radius = capture_zone_radius
	if stability_shape != null and stability_shape.shape is CircleShape2D:
		(stability_shape.shape as CircleShape2D).radius = get_stability_radius()

	if capture_zone != null:
		capture_zone.body_entered.connect(_on_capture_body_entered)
		capture_zone.body_exited.connect(_on_capture_body_exited)

	if stability_field != null:
		stability_field.body_entered.connect(_on_field_body_entered)
		stability_field.body_exited.connect(_on_field_body_exited)

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_enemy_index = get_node_or_null("/root/EnemyIndex")

	# Visual defaults
	if sigil != null:
		sigil.rotation = randf() * TAU
		sigil.modulate.a = 0.14
	if obelisk != null:
		obelisk.modulate = Color(0.92, 0.92, 0.92, 1.0)

	_set_idle_intensity(0.28)

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	_spin_t += delta
	if sigil != null:
		# Very slow rotation + soft breathe
		sigil.rotation += 0.08 * delta
		var breathe := 0.5 + 0.5 * sin(_spin_t * 1.1)
		var a := 0.14 if not _active else 0.26
		# While capturing, let it ramp up so it feels "busy"
		if (not _active) and _player_inside and capture_time > 0.0:
			var t := clampf(_capture / capture_time, 0.0, 1.0)
			a = lerpf(0.16, 0.30, t)
		sigil.modulate.a = a * (0.85 + 0.15 * breathe)

	if _active:
		_set_idle_intensity(0.65)
		return

	if not _player_inside:
		_capture = 0.0
		_set_idle_intensity(0.28)
		queue_redraw()
		return

	_capture = minf(_capture + delta, capture_time)
	# ramp idle aura while capturing
	if capture_time > 0.0:
		_set_idle_intensity(lerpf(0.35, 0.60, clampf(_capture / capture_time, 0.0, 1.0)))
	queue_redraw()

	if _capture >= capture_time:
		_activate()


func _activate() -> void:
	if _active:
		return
	_active = true
	add_to_group(&"wardstones_active")

	var sm := get_node_or_null("/root/SfxManager")
	if sm != null:
		sm.call("stop_loop", self, _sfx_capture_tag)
		sm.call("play_2d", &"wardstone_complete", global_position)

	# Player checkpoint + restore
	var p := get_tree().get_first_node_in_group("player") as Node
	if p != null and p.has_method("set_checkpoint"):
		p.call("set_checkpoint", global_position, false)
	if p != null and p.has_method("wardstone_full_restore"):
		p.call("wardstone_full_restore")

	# Tutorial/narrative: clarify the synthetic rewrite and checkpoint function.
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		if narrative_index == 1:
			RunEvents.tutorial_tip.emit(Segment1Text.WARDSTONE_1, 4.0)
		elif narrative_index == 2:
			RunEvents.tutorial_tip.emit(Segment1Text.WARDSTONE_2, 4.0)
		elif Global != null and (not Global.tip_shown_wardstone_anchor):
			RunEvents.tutorial_tip.emit("Wardstone Attuned: new respawn anchor", 3.0)
	if Global != null and (not Global.tip_shown_wardstone_anchor):
		Global.tip_shown_wardstone_anchor = true

	# New VFX burst (custom, not reused)
	if vfx_root != null:
		var burst := ATTUNE_BURST_SCENE.instantiate()
		vfx_root.add_child(burst)
		if burst.has_method("setup"):
			burst.call("setup", global_position, capture_zone_radius + 18.0)

	# Tiny visual pop
	if sigil != null:
		var tw := create_tween()
		tw.tween_property(sigil, "scale", sigil.scale * 1.10, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sigil, "scale", sigil.scale, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_pulse()
	activated.emit(self)
	queue_redraw()

func restore_active() -> void:
	# Continue-safe restore: reproduce the sanctuary without replaying rewards,
	# tutorial copy, checkpoint writes, or the activation pulse.
	if _active:
		return
	_active = true
	_capture = capture_time
	add_to_group(&"wardstones_active")
	_set_idle_intensity(0.65)
	if sigil != null:
		sigil.modulate.a = 0.26
	queue_redraw()


func _pulse() -> void:
	var enemies: Array = []
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("gather_in_radius"):
		_enemy_index.call("gather_in_radius", global_position, pulse_radius, _pulse_targets)
		enemies = _pulse_targets
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var en := e as Node2D
		if en == null or not is_instance_valid(en):
			continue
		var d: Vector2 = en.global_position - global_position
		var dist: float = d.length()
		if dist <= 0.001 or dist > pulse_radius:
			continue
		var dir: Vector2 = d / dist
		if e.has_method("apply_knockback"):
			e.call("apply_knockback", dir * pulse_force)
		if pulse_stun > 0.0 and e.has_method("apply_stun"):
			e.call("apply_stun", pulse_stun)


func get_stability_radius() -> float:
	var mul: float = 1.0
	if Global != null:
		mul = float(Global.attempt_wardstone_radius_mul)
	return stability_radius * mul


func _on_capture_body_entered(b: Node) -> void:
	if _active:
		return
	if b != null and b.is_in_group("player"):
		_player_inside = true
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("ensure_loop_2d", self, _sfx_capture_tag, &"wardstone_loop")

		# Level 1 tutorial: teach that you must stand inside to attune (one-shot)
		if Global != null and (not Global.tip_shown_wardstone_attune):
			Global.tip_shown_wardstone_attune = true
			if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
				RunEvents.tutorial_tip.emit("Stand within the Wardstone to Attune", 3.0)


func _on_capture_body_exited(b: Node) -> void:
	if _active:
		return
	if b != null and b.is_in_group("player"):
		_player_inside = false
		var sm := get_node_or_null("/root/SfxManager")
		if sm != null:
			sm.call("stop_loop", self, _sfx_capture_tag)


func _on_field_body_entered(b: Node) -> void:
	if not _active:
		return
	if b != null and b.is_in_group("enemies"):
		if b.has_method("set_stability_mul"):
			var mul: float = 1.0
			if Global != null:
				mul = float(Global.attempt_wardstone_slow_mul)
			b.call("set_stability_mul", stability_slow_mul * mul)


func _on_field_body_exited(b: Node) -> void:
	if b != null and b.is_in_group("enemies"):
		if b.has_method("clear_stability_mul"):
			b.call("clear_stability_mul")


func _set_idle_intensity(v: float) -> void:
	if idle_aura == null:
		return
	if idle_aura.has_method("set_intensity"):
		idle_aura.call("set_intensity", v)


func _draw() -> void:
	# In-world readability (capture ring + progress) + stability ring when relevant.
	var show_stability: bool = _active
	if (not show_stability) and _player != null:
		show_stability = global_position.distance_to(_player.global_position) <= (stability_radius * 1.12)

	if show_stability:
		var c := Color(0.25, 0.55, 0.70, 0.10) if not _active else Color(0.35, 0.88, 0.80, 0.16)
		draw_arc(Vector2.ZERO, stability_radius, 0.0, TAU, 96, c, 3.0, true)

	# Capture ring
	draw_arc(Vector2.ZERO, capture_zone_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.22), 2.0, true)

	# Capture progress (kept as requested)
	if (not _active) and capture_time > 0.0 and _capture > 0.0:
		var t := clampf(_capture / capture_time, 0.0, 1.0)
		var prog_col := Color(0.95, 0.80, 0.35, 0.78)
		draw_arc(Vector2.ZERO, capture_zone_radius + 6.0, -PI/2, -PI/2 + TAU * t, 64, prog_col, 4.0, true)
