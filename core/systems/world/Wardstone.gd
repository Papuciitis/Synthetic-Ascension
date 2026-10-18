extends Node2D
class_name Wardstone

const WorldArt := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")

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

## How often an inactive wardstone re-asks whether the player is near enough for
## the stability ring to show. The ring is a proximity tell, not an animation;
## four looks a second is below the threshold at which "it appeared as I walked
## up" reads as late.
const STABILITY_POLL_INTERVAL: float = 0.25

var _player_inside: bool = false
var _player: Node2D = null
var _capture: float = 0.0
var _active: bool = false
var _spin_t: float = 0.0
## Whether the last proximity poll put the player inside the stability ring's
## reveal range. _draw reads this rather than measuring again, so the ring can
## only change on a poll - and a poll only repaints when it flips.
var _stability_ring_near: bool = false
var _stability_poll_t: float = 0.0
var _enemy_index: Node = null
var _pulse_targets: Array[int] = []
var _ground_details: Node2D
var _presentation_state := ""
var _presentation_bucket := -1

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
		obelisk.set_script(WorldArt)
		obelisk.call("configure", "wardstone", 142.0)
	_ground_details = Node2D.new()
	_ground_details.name = "GroundDetails"
	_ground_details.z_index = -12
	add_child(_ground_details)
	_ground_details.draw.connect(_draw_ground_details)
	_refresh_world_art()

	_set_idle_intensity(0.28)

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	_spin_t += delta
	if sigil != null:
		if not WorldArt.reduced_motion():
			sigil.rotation += 0.04 * delta
		var breathe := WorldArt.pulse(_spin_t, 1.1)
		var a := 0.10 if not _active else 0.035
		# While capturing, let it ramp up so it feels "busy"
		if (not _active) and _player_inside and capture_time > 0.0:
			var t := clampf(_capture / capture_time, 0.0, 1.0)
			a = lerpf(0.16, 0.30, t)
		sigil.modulate.a = a * (0.85 + 0.15 * breathe)
	_refresh_world_art()

	if _active:
		_set_idle_intensity(0.65)
		return

	_poll_stability_ring(delta)

	if not _player_inside:
		if _capture != 0.0:
			# The frame that clears the capture arc still paints: one last wipe,
			# then the wardstone is a still image until something moves.
			_capture = 0.0
			_refresh_world_art()
			queue_redraw()
		_set_idle_intensity(0.28)
		return

	_capture = minf(_capture + delta, capture_time)
	_refresh_world_art()
	# ramp idle aura while capturing
	if capture_time > 0.0:
		_set_idle_intensity(lerpf(0.35, 0.60, clampf(_capture / capture_time, 0.0, 1.0)))
	queue_redraw()

	if _capture >= capture_time:
		_activate()


## The stability ring "shows when near", which used to mean measuring the moving
## player every frame and repainting two arcs for an answer that changes twice a
## segment. Coarse hysteresis instead: look four times a second, repaint on the
## flip.
func _poll_stability_ring(delta: float) -> void:
	_stability_poll_t -= delta
	if _stability_poll_t > 0.0:
		return
	_stability_poll_t = STABILITY_POLL_INTERVAL
	var near := false
	if _player != null and is_instance_valid(_player):
		near = global_position.distance_to(_player.global_position) <= (stability_radius * 1.12)
	if near == _stability_ring_near:
		return
	_stability_ring_near = near
	queue_redraw()


func _activate() -> void:
	if _active:
		return
	_active = true
	add_to_group(&"wardstones_active")
	_refresh_world_art()

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
	if sigil != null and not WorldArt.reduced_motion():
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
		sigil.modulate.a = 0.035
	_refresh_world_art()
	queue_redraw()


func _pulse() -> void:
	EnemyCombat.gather_in_radius(global_position, pulse_radius, _pulse_targets)
	for handle in _pulse_targets:
		var d: Vector2 = EnemyCombat.position_for_handle(handle) - global_position
		var dist: float = d.length()
		if dist <= 0.001 or dist > pulse_radius:
			continue
		var dir: Vector2 = d / dist
		EnemyCombat.apply_knockback(handle, dir * pulse_force)
		if pulse_stun > 0.0:
			EnemyCombat.apply_stun(handle, pulse_stun)


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


## This state describes the existing capture only; reading it never banks or
## advances attunement. The physical base and painted obelisk share the answer.
func presentation_state() -> String:
	return "complete" if _active else ("working" if _player_inside else "dormant")


func _refresh_world_art() -> void:
	var state := presentation_state()
	var progress := 1.0 if _active else clampf(_capture / maxf(capture_time, 0.001), 0.0, 1.0)
	if obelisk != null:
		obelisk.call("set_state", state, progress)
	var bucket := int(progress * 32.0)
	if state == _presentation_state and bucket == _presentation_bucket:
		return
	_presentation_state = state
	_presentation_bucket = bucket
	if _ground_details != null:
		_ground_details.queue_redraw()


func _draw_ground_details() -> void:
	if _ground_details == null:
		return
	var state := presentation_state()
	var engaged := state == "complete"
	var working := state == "working"
	# A shallow civic plinth, centered on the real foot rather than the PNG's
	# transparent bounds. Broad clamps close into the foot when it anchors.
	var plinth := PackedVector2Array([Vector2(-35, -12), Vector2(29, -12), Vector2(39, 6), Vector2(25, 20), Vector2(-29, 20), Vector2(-40, 5)])
	_ground_details.draw_colored_polygon(plinth, Color(0.12, 0.15, 0.14, 0.72))
	_ground_details.draw_polyline(PackedVector2Array([plinth[0], plinth[1], plinth[2], plinth[3], plinth[4], plinth[5], plinth[0]]), Color(0.56, 0.59, 0.51, 0.53), 1.5, true)
	var closure := 1.0 if engaged else (clampf(_capture / maxf(capture_time, 0.001), 0.0, 1.0) * 0.65 if working else 0.0)
	var gap := lerpf(27.0, 15.0, closure)
	var metal := Color(0.69, 0.72, 0.60, 0.9) if engaged else Color(0.43, 0.44, 0.38, 0.8)
	for side in [-1.0, 1.0]:
		var center := Vector2(gap * side, 6.0)
		_ground_details.draw_rect(Rect2(center - Vector2(8.0, 5.0), Vector2(16.0, 10.0)), Color(0.08, 0.10, 0.09, 0.94))
		_ground_details.draw_line(center - Vector2(7.0, 0.0), center + Vector2(7.0, 0.0), metal, 4.0, true)
		if engaged:
			_ground_details.draw_line(center + Vector2(-side * 5.0, -5.0), center + Vector2(-side * 5.0, 5.0), metal, 3.0, true)
	if engaged:
		_ground_details.draw_line(Vector2(-17.0, 18.0), Vector2(17.0, 18.0), Color(0.64, 0.77, 0.66, 0.85), 3.0, true)


func _draw() -> void:
	# Once anchored, the actual slowing field takes priority over the obsolete
	# capture ornament. Its exact edge remains stable when motion is disabled.
	var show_stability: bool = _active or _stability_ring_near
	if show_stability:
		if _active:
			WorldArt.draw_boundary(self, Vector2.ZERO, get_stability_radius(), Color(0.54, 0.79, 0.68, 0.62))
		else:
			draw_arc(Vector2.ZERO, get_stability_radius(), 0.0, TAU, 96, Color(0.42, 0.56, 0.52, 0.13), 1.25, true)
	if not _active:
		WorldArt.draw_boundary(self, Vector2.ZERO, capture_zone_radius, Color(0.55, 0.68, 0.62, 0.48))
	if _active or _stability_ring_near:
		var label := "ANCHORED • SANCTUARY" if _active else ("ATTUNING" if _player_inside else "WARDSTONE")
		var at := Vector2(-140.0, -132.0)
		draw_string_outline(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, 4, Color(0.025, 0.02, 0.03, 0.95))
		draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, Color(0.7, 0.9, 0.84, 0.95))

	# Temporary capture progress resets on exit; it has no durable seal marks.
	if (not _active) and capture_time > 0.0 and _capture > 0.0:
		var t := clampf(_capture / capture_time, 0.0, 1.0)
		var prog_col := Color(0.83, 0.77, 0.52, 0.72)
		draw_arc(Vector2.ZERO, capture_zone_radius + 5.0, -PI/2, -PI/2 + TAU * t, 64, prog_col, 2.5, true)
