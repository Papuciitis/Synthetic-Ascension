extends Node
class_name OpeningSequenceController

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")

signal sequence_finished

enum Phase {
	NONE,
	HISTORICAL,
	BREN,
	SYNTHESIS,
	CALIBRATION,
	CONSTRUCT,
	OFFICER,
	AFTERMATH,
	BREN_SEPARATION,
	COMPLETE,
}

const PRESENTATION_SCENE := preload("res://ui/screens/opening/OpeningPresentation.tscn")
const WORLD_SCENE := preload("res://core/systems/world/opening/OpeningSequenceWorld.tscn")
const ACTOR_SCENE := preload("res://core/systems/world/opening/OpeningActor.tscn")
const CONSTRUCT_SPEC := preload("res://core/actors/enemy/EnemySpec_ContainmentConstruct.tres")
const OFFICER_SPEC := preload("res://core/actors/enemy/EnemySpec_OpeningOfficer.tres")
const MAX_CINEMATIC_CAMERA_OFFSET: float = 144.0
const CALIBRATION_AIM_RADIUS: float = 192.0
const CALIBRATION_MELEE_RADIUS: float = 144.0

var _player: Node2D
var _level: Level1Builder
var _presentation: OpeningPresentation
var _world: OpeningSequenceWorld
var _actors: Array[OpeningActor] = []
var _camera: Camera2D
var _camera_origin := Vector2.ZERO
var _camera_tween: Tween
var _calibration_target: OpeningActor
var _original_time_scale: float = 1.0
var _sequence_active: bool = false
var _anchor := Vector2.ZERO
var _debug_response_override := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"opening_sequence_controller")

func run_sequence(player_node: Node2D, level_builder: Level1Builder) -> void:
	if Global == null or int(Global.attempt_segment) != 1 or Global.attempt_opening_completed:
		sequence_finished.emit()
		return
	_player = player_node
	_level = level_builder
	if _player == null or _level == null:
		push_warning("[Opening] Segment 1 controller could not bind player/level; using safe skip.")
		_safe_skip_without_world()
		sequence_finished.emit()
		return

	_sequence_active = true
	_original_time_scale = Engine.time_scale
	_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _camera != null:
		_camera_origin = _camera.position
	var anchors := _level.get_opening_anchors()
	_anchor = anchors.get("apparatus", _player.global_position) as Vector2
	_presentation = PRESENTATION_SCENE.instantiate() as OpeningPresentation
	_world = WORLD_SCENE.instantiate() as OpeningSequenceWorld
	add_child(_world)
	add_child(_presentation)
	_level.begin_opening_sequence()
	_set_player_lock(true, true)
	_frame_position(_anchor, true)

	var mode := String(Global.attempt_opening_mode)
	if mode not in ["full", "short", "skip"]:
		mode = "full" if not Global.opening_full_intro_seen else "short"
		Global.attempt_opening_mode = StringName(mode)
	if Global.debug_opening_force_phase >= 0:
		Global.attempt_opening_phase = clampi(Global.debug_opening_force_phase, Phase.NONE, Phase.BREN_SEPARATION)
	_debug_response_override = Global.debug_opening_response_override
	Global.debug_opening_mode_override = ""
	Global.debug_opening_force_phase = -1
	Global.debug_opening_response_override = ""
	_restore_phase_prerequisites(Global.attempt_opening_phase)
	if RunEvents != null:
		RunEvents.opening_sequence_state_changed.emit(true, Global.attempt_opening_phase, StringName(mode))

	match mode:
		"skip":
			await _run_skip()
		"short":
			await _run_short()
		_:
			await _run_full()

	_finish_sequence(mode)
	sequence_finished.emit()

func _run_full() -> void:
	# Autoload properties are dynamically exposed to the typed analyzer. Keep the
	# local explicit so Godot 4.7 does not attempt to infer it from a Variant.
	var resume_phase: int = int(Global.attempt_opening_phase)
	if resume_phase <= Phase.HISTORICAL:
		_set_phase(Phase.HISTORICAL)
		await _presentation.present_historical(Global.mortal_name)
		await get_tree().create_timer(0.35, true, false, true).timeout

	if resume_phase <= Phase.BREN:
		_set_phase(Phase.BREN)
		var choice_index := OpeningSequenceData.choice_index_for_id(StringName(_debug_response_override))
		if choice_index < 0:
			choice_index = await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_OPENING, OpeningSequenceData.RESPONSE_CHOICES)
		var response_id := OpeningSequenceData.choice_id(choice_index)
		Global.opening_response_id = response_id
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.choice_reaction(response_id))

	if resume_phase <= Phase.SYNTHESIS:
		_set_phase(Phase.SYNTHESIS)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_BEFORE_SYNTHESIS)
		_world.configure(_anchor, _player, 3)
		_presentation.show_prompt(OpeningSequenceData.INTERACT_PROMPT)
		_set_player_lock(false, true)
		for stage in range(3):
			var completed: int = await _world.wait_for_next_stage()
			_presentation.show_prompt(OpeningSequenceData.ALIGNMENT_STATUS[clampi(completed, 0, 2)])
		_set_player_lock(true, true)
		_presentation.hide_prompt()
		if AudioManager != null:
			AudioManager.stop_all(false)
		await _world.pulse()
		await get_tree().create_timer(0.45, true, false, true).timeout
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_AFTER_SYNTHESIS)
		await _presentation.present_synthetic(OpeningSequenceData.SYNTHESIS_TITLE, OpeningSequenceData.SYNTHESIS_BODY)
		_level.opening_complete_synthesis()

	if resume_phase <= Phase.CALIBRATION:
		_set_phase(Phase.CALIBRATION)
		var target := _spawn_actor(&"calibration", _anchor + Vector2(210, 10), null, false, 8.0)
		_presentation.show_prompt(OpeningSequenceData.CALIBRATION_PROMPT)
		_bind_calibration_target(target)
		_set_player_lock(false, false)
		if target != null:
			await target.defeated
		_unbind_calibration_target()
		_presentation.hide_prompt()
		_set_player_lock(true, true)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_BARRIER_1)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_BARRIER_2)
		await _presentation.present_announcement(OpeningSequenceData.DETECTION_TITLE, OpeningSequenceData.DETECTION_BODY)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_PROPAGATION)

	if resume_phase <= Phase.CONSTRUCT:
		_set_phase(Phase.CONSTRUCT)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_CONSTRUCT)
		var construct := _spawn_actor(&"construct", _anchor + Vector2(-210, -30), CONSTRUCT_SPEC, false, 18.0)
		if construct != null and RunEvents != null:
			RunEvents.enemy_archetype_encountered.emit(construct)
			await get_tree().process_frame
			while get_tree().paused:
				await get_tree().process_frame
		if construct != null:
			construct.set_hostile(true)
		_presentation.show_prompt(OpeningSequenceData.CONSTRUCT_PROMPT)
		_set_player_lock(false, false)
		if construct != null:
			await construct.defeated
		_presentation.hide_prompt()
		_set_player_lock(true, true)

	if resume_phase <= Phase.OFFICER:
		_set_phase(Phase.OFFICER)
		var officer := _spawn_actor(&"officer", _anchor + Vector2(235, -85), OFFICER_SPEC, false, 22.0)
		if officer != null:
			officer.requires_manual_fire = true
		await _presentation.present_dialogue("OFFICER", "CONTAINMENT OFFICER", OpeningSequenceData.officer_arrest(Global.mortal_name))
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_OFFICER)
		await _presentation.present_dialogue("OFFICER", "CONTAINMENT OFFICER", OpeningSequenceData.OFFICER_SECOND)
		if officer != null:
			officer.begin_seizure(_anchor)
		_presentation.show_prompt(OpeningSequenceData.OFFICER_PROMPT)
		_set_player_lock(false, false)
		if officer != null:
			await _wait_for_officer_choice(officer)
			if is_instance_valid(officer) and not officer.dead:
				await officer.defeated
		_presentation.hide_prompt()
		_set_player_lock(true, true)
		_level.opening_complete_officer()

	if resume_phase <= Phase.AFTERMATH:
		_set_phase(Phase.AFTERMATH)
		Engine.time_scale = 0.35
		if AudioManager != null:
			AudioManager.stop_all(false)
		await _presentation.present_announcement(OpeningSequenceData.LETHAL_TITLE, OpeningSequenceData.LETHAL_BODY, "Continue")
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_AFTER_DEATH)
		Engine.time_scale = _original_time_scale

	if resume_phase <= Phase.BREN_SEPARATION:
		_set_phase(Phase.BREN_SEPARATION)
		var records_anchor := _level.get_opening_anchors().get("records", _anchor) as Vector2
		_frame_position(records_anchor, true)
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, "%s\n\n%s" % [OpeningSequenceData.BREN_SEPARATION_1, OpeningSequenceData.BREN_SEPARATION_2])
		await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.bren_final(Global.mortal_name))
		_level.opening_complete_bren()
		await _presentation.present_follower(OpeningSequenceData.FOLLOWER_BODY)
		Global.opening_follower_explanation_seen = true

func _run_short() -> void:
	_set_phase(Phase.SYNTHESIS)
	_player.global_position = _anchor + Vector2(0, 120)
	_frame_position(_anchor, true)
	await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_SHORT)
	_world.configure(_anchor, _player, 1)
	_presentation.show_prompt("Space / Enter to repeat the stable alignment")
	_set_player_lock(false, true)
	await _world.wait_for_next_stage()
	_set_player_lock(true, true)
	_presentation.hide_prompt()
	if AudioManager != null:
		AudioManager.stop_all(false)
	await _world.pulse()
	_level.opening_complete_short_or_skip()
	await _presentation.present_synthetic(OpeningSequenceData.SYNTHESIS_TITLE, OpeningSequenceData.SHORT_SYNTHESIS_BODY)

func _run_skip() -> void:
	_set_phase(Phase.BREN_SEPARATION)
	_level.opening_complete_short_or_skip()
	await get_tree().process_frame

func _wait_for_officer_choice(officer: OpeningActor) -> void:
	var elapsed := 0.0
	var warned := false
	while is_instance_valid(officer) and not officer.dead and not officer.has_engaged():
		await get_tree().create_timer(0.25, true, false, true).timeout
		elapsed += 0.25
		if elapsed >= 7.0 and not warned:
			warned = true
			_set_player_lock(true, true)
			await _presentation.present_announcement(OpeningSequenceData.ARREST_TITLE, OpeningSequenceData.ESCALATION_BODY, "Resist or surrender the work")
			await _presentation.present_dialogue("BREN", OpeningSequenceData.BREN_ROLE, OpeningSequenceData.BREN_WAIT)
			_set_player_lock(false, false)
	_presentation.show_prompt("Containment has turned hostile • Defend the work")

func _restore_phase_prerequisites(resume_phase: int) -> void:
	if _level == null:
		return
	if resume_phase >= Phase.CALIBRATION:
		_level.opening_complete_synthesis()
	if resume_phase >= Phase.AFTERMATH:
		_level.opening_complete_officer()

func _spawn_actor(role: StringName, world_position: Vector2, actor_spec: EnemySpec, starts_hostile: bool, fallback_hp: float) -> OpeningActor:
	var actor := ACTOR_SCENE.instantiate() as OpeningActor
	if actor == null:
		return null
	actor.role = role
	actor.spec = actor_spec
	actor.hostile = starts_hostile
	actor.max_hp = fallback_hp
	actor.global_position = world_position
	get_tree().current_scene.add_child(actor)
	_actors.append(actor)
	return actor

func _set_phase(value: int) -> void:
	if Global != null:
		Global.set_opening_phase(value)
	if RunEvents != null:
		RunEvents.opening_sequence_state_changed.emit(true, value, Global.attempt_opening_mode if Global != null else &"")

func _finish_sequence(mode: String) -> void:
	_set_player_lock(false, false)
	Engine.time_scale = _original_time_scale
	_restore_player_camera()
	if AudioManager != null:
		AudioManager.to_game(false)
	if _level != null and is_instance_valid(_level):
		_level.finish_opening_sequence()
	if Global != null:
		Global.mark_opening_completed()
		Global.tip_shown_intro_move = mode != "skip"
		Global.save_current_profile()
	if RunEvents != null:
		RunEvents.opening_sequence_state_changed.emit(false, Phase.COMPLETE, StringName(mode))
	_sequence_active = false
	_cleanup_nodes()

func _safe_skip_without_world() -> void:
	if Global == null:
		return
	Global.record_segment1_milestone(&"synthesis")
	Global.record_segment1_milestone(&"first_confrontation")
	Global.record_segment1_milestone(&"assistant_commitment")
	Global.set_followers(1)
	Global.attempt_opening_officer_completed = true
	Global.attempt_opening_bren_committed = true
	Global.mark_opening_completed()

func _set_player_lock(move_locked: bool, attack_locked: bool) -> void:
	# A child Camera2D offset is safe only while the player is stationary. Restore
	# it before movement is returned so camera space and mouse aim cannot drift.
	if not move_locked:
		_restore_player_camera()
	if _player != null and is_instance_valid(_player) and _player.has_method("set_cinematic_input"):
		_player.call("set_cinematic_input", move_locked, attack_locked)

func _frame_position(world_position: Vector2, framed: bool) -> void:
	if _camera == null or not is_instance_valid(_camera) or _player == null:
		return
	_stop_camera_tween()
	var target := _camera_origin
	if framed:
		var offset := world_position - _player.global_position
		target += offset.limit_length(MAX_CINEMATIC_CAMERA_OFFSET)
	_camera_tween = create_tween()
	_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_camera_tween.set_trans(Tween.TRANS_QUAD)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "position", target, Accessibility.current_motion_duration(0.35))

func _stop_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null

func _restore_player_camera() -> void:
	_stop_camera_tween()
	if _camera != null and is_instance_valid(_camera):
		_camera.position = _camera_origin

func _bind_calibration_target(target: OpeningActor) -> void:
	_unbind_calibration_target()
	_calibration_target = target
	if RunEvents == null or target == null:
		return
	var fired_cb := Callable(self, "_on_calibration_weapon_fired")
	if not RunEvents.weapon_fired.is_connected(fired_cb):
		RunEvents.weapon_fired.connect(fired_cb)

func _unbind_calibration_target() -> void:
	if RunEvents != null:
		var fired_cb := Callable(self, "_on_calibration_weapon_fired")
		if RunEvents.weapon_fired.is_connected(fired_cb):
			RunEvents.weapon_fired.disconnect(fired_cb)
	_calibration_target = null

func _on_calibration_weapon_fired(
		firing_player: Node,
		style_id: StringName,
		_origin: Vector2,
		aimed_target: Vector2,
		_power_mul: float,
		_haste_mul: float
) -> void:
	if firing_player != _player or _calibration_target == null:
		return
	if not is_instance_valid(_calibration_target) or _calibration_target.dead:
		return
	var aimed_close := aimed_target.distance_squared_to(_calibration_target.global_position) <= CALIBRATION_AIM_RADIUS * CALIBRATION_AIM_RADIUS
	var melee_close := style_id == &"melee" and _player.global_position.distance_squared_to(_calibration_target.global_position) <= CALIBRATION_MELEE_RADIUS * CALIBRATION_MELEE_RADIUS
	if aimed_close or melee_close:
		# Managed ranged projectiles resolve after weapon_fired. This scripted hit
		# keeps calibration authoritative and prevents a physics/index mismatch
		# from trapping the opening while the ordinary projectile still plays.
		_calibration_target.complete_calibration(firing_player)
	elif _presentation != null and is_instance_valid(_presentation):
		_presentation.show_prompt("Aim at the gold calibration target, then fire")

func _cleanup_nodes() -> void:
	_unbind_calibration_target()
	_stop_camera_tween()
	if _presentation != null and is_instance_valid(_presentation):
		_presentation.queue_free()
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	for actor in _actors:
		if actor != null and is_instance_valid(actor):
			actor.queue_free()
	_actors.clear()

func _exit_tree() -> void:
	if not _sequence_active:
		return
	Engine.time_scale = _original_time_scale
	_set_player_lock(false, false)
	_restore_player_camera()
	_unbind_calibration_target()
	if _level != null and is_instance_valid(_level):
		_level.finish_opening_sequence()
	if AudioManager != null:
		AudioManager.to_game(false)
