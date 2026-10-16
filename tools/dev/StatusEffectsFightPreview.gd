extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Production Game/camera/AI/native attacks from the bounded elite crowd fixture.
## Additional effects are SCRIPTED real API applications, recorded below.
## --out=<absolute directory> [--visible] [--seconds=10] [--fps=15]

const HERALD_SPEC := preload("res://core/actors/enemy/EnemySpec_Herald.tres")
const CHANTER_SPEC := preload("res://core/actors/enemy/EnemySpec_Chanter.tres")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

var _status_stage := 0
var _status_events: Array[Dictionary] = []
var _status_burn_successes := 0
var _status_bleed_successes := 0
var _status_stun_successes := 0
var _status_mixed_elite_stunned := false
var _status_buffs := 0
var _status_healing_lock := false
var _status_teach_seen := false


func _enter_tree() -> void:
	super._enter_tree()
	if _out == "user://dev_previews/elite_crowd_fight":
		_out = "user://dev_previews/status_effects_fight"


func _prepare_runtime() -> void:
	super._prepare_runtime()
	Global.tip_shown_intro_move = true
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	SettingsManager.set_value(&"accessibility", &"damage_numbers", true, false)
	# The already-reviewed elite lessons would otherwise queue for >20 s.
	# Keep the production popup names; leave the healing-lock lesson untaught.
	for id in EliteModifiers.ALL:
		EliteModifiers.consume_teach(id)
	get_window().title = "Synthetic Ascension — live combat status preview"


func _spawn_encounter() -> void:
	super._spawn_encounter()
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(28, 998)
	caption.size = Vector2(640, 62)
	caption.text = "LIVE COMBAT · SCRIPTED STATUS APPLICATIONS\nNative attacks + AI · God mode · No profile saves"
	caption.add_theme_font_override("font", HUD_THEME.get_font(&"font", &"Label"))
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color("eee5cf"))
	caption.add_theme_color_override("font_outline_color", Color("0b100d"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _running or _player == null:
		return
	var thresholds := [0.20, 0.48, 1.05, 1.60, 3.00, 3.35, 4.05, 5.75, 6.05, 7.25, 8.50]
	if _status_stage < thresholds.size() and _combat_time >= float(thresholds[_status_stage]):
		_apply_stage(_status_stage)
		_status_stage += 1
	var label := _game.get_node_or_null("UI/HUD/GateOverlay/TutorialTip/Margin/Row/Label") as Label
	var icons := _game.get_node_or_null("UI/HUD/GateOverlay/TutorialTip/Margin/Row/StatusIcons") as HBoxContainer
	if label != null and label.is_visible_in_tree() and label.text.begins_with("HEALING SEALED") and icons != null and icons.is_visible_in_tree() and icons.get_child_count() > 0:
		_status_teach_seen = true


func _apply_stage(stage: int) -> void:
	if stage == 3:
		_player.call("lock_healing", 12.0, &"status_preview")
		_status_healing_lock = float(_player.call("healing_locked_seconds")) > 0.0
		_record(&"healing_sealed", 0, {"seconds": _player.call("healing_locked_seconds"), "source": "Player.lock_healing"})
		return
	var actor := _status_actor(stage == 0 or stage == 1 or stage == 5 or stage == 8)
	if actor == null:
		_fail("No live actor available for status stage %d" % stage)
		return
	var handle := EnemyCombat.handle_for_actor(actor)
	if stage in [0, 4, 7, 9]:
		var burn := EnemyStatus.apply_burn(handle, 1, 2.2, 0.5, 1.0, _player)
		var bleed := EnemyStatus.apply_bleed(handle, 1, 2.2, 0.5, 1.0, _player)
		_status_burn_successes += 1 if burn else 0
		_status_bleed_successes += 1 if bleed else 0
		_record(&"burn_bleed", handle, {"burn_accepted": burn, "bleed_accepted": bleed, "burn_present": EnemyStatus.has_status(handle, &"burn"), "bleed_present": EnemyStatus.has_status(handle, &"bleed"), "source": "EnemyStatus.apply_burn + apply_bleed"})
	elif stage in [1, 5, 8]:
		var stunned := EnemyCombat.apply_stun(handle, 0.85)
		_status_stun_successes += 1 if stunned else 0
		if stunned and actor.elite_modifier_ids().size() >= 2:
			_status_mixed_elite_stunned = true
		_record(&"stun", handle, {"accepted": stunned, "seconds": EnemyWorld.get_stun_time(handle), "modifiers": actor.elite_modifier_ids(), "source": "EnemyCombat.apply_stun"})
	else:
		actor.apply_ward_buff(CHANTER_SPEC.herald_ally_ward_fraction, CHANTER_SPEC.herald_ally_ward_duration)
		actor.apply_speed_buff(HERALD_SPEC.herald_ally_speed_mult, HERALD_SPEC.herald_ally_speed_duration)
		if not actor.is_warded() or float(actor.get("_speed_mul")) <= 1.0 or float(actor.get("_speed_mul_time")) <= 0.0:
			_fail("Authored ward / haste applications did not reach the actor.")
		_status_buffs += 1
		_record(&"ward_haste", handle, {"ward_present": actor.is_warded(), "ward_fraction": CHANTER_SPEC.herald_ally_ward_fraction, "haste_multiplier": actor.get("_speed_mul"), "haste_seconds": actor.get("_speed_mul_time"), "source": "EnemyActor.apply_ward_buff + apply_speed_buff using authored Chanter/Herald values"})


func _status_actor(prefer_mixed_elite: bool) -> EnemyActor:
	if prefer_mixed_elite and _elite_refs.size() > 5:
		var mixed := _elite_refs[5].get_ref() as EnemyActor
		if mixed != null and is_instance_valid(mixed) and not mixed.dead:
			return mixed
	var result: EnemyActor = null
	var best := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var actor := node as EnemyActor
		if actor == null or actor.dead:
			continue
		var handle := EnemyCombat.handle_for_actor(actor)
		if not EnemyWorld.is_valid_handle(handle) or EnemyWorld.is_dying(handle):
			continue
		var distance := actor.global_position.distance_squared_to(_player.global_position)
		if distance < best:
			best = distance
			result = actor
	return result


func _record(id: StringName, handle: int, detail: Dictionary) -> void:
	detail["status"] = String(id)
	detail["handle"] = handle
	detail["simulation_time"] = _combat_time
	_status_events.append(detail)


func _sample(wall_time: float) -> Dictionary:
	var sample := super._sample(wall_time)
	sample["status_events_recorded"] = _status_events.size()
	sample["healing_lock_seconds"] = _player.call("healing_locked_seconds")
	sample["healing_teach_seen"] = _status_teach_seen
	sample["battletext_entries"] = BattleText.get("_count")
	return sample


func _shutdown() -> void:
	# The base writes ordinary fight metrics and measured frame timestamps.
	# Add evidence of real applications without claiming all 21 build behaviours.
	if _status_burn_successes == 0 or _status_bleed_successes == 0 or _status_stun_successes == 0 or not _status_mixed_elite_stunned or _status_buffs == 0 or not _status_healing_lock or not _status_teach_seen:
		_fail("The intended live status applications or healing teaching alert were not observed.")
	var info := {
		"scene": "res://tools/dev/StatusEffectsFightPreview.tscn",
		"base_fixture": "res://tools/dev/EliteCrowdFightPreview.tscn",
		"presentation": "LIVE production combat with SCRIPTED real API status applications. Native player attacks, enemy AI, terrain, camera, projectiles and deaths remain live.",
		"limits": "Player god mode; scripted controller input; ambient spawning and encounter beats disabled. Direct status API applications are not natural item/build triggers. Only common statuses are exercised here; the separate all-21 catalogue is staged presentation.",
		"initial_enemies": ORDINARY_COUNT + ELITE_CASES.size(),
		"burn_applications_accepted": _status_burn_successes, "bleed_applications_accepted": _status_bleed_successes,
		"stun_applications_accepted": _status_stun_successes, "ward_haste_applications": _status_buffs,
		"mixed_elite_stunned": _status_mixed_elite_stunned,
		"healing_lock_applied": _status_healing_lock, "healing_illustrated_teach_seen": _status_teach_seen,
		"events": _status_events, "failures": _failures,
	}
	var path := ProjectSettings.globalize_path(_out).path_join("status-application-info.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write status application evidence.")
	else:
		file.store_string(JSON.stringify(info, "\t") + "\n")
		file.close()
	print("StatusEffectsFightPreview: burn=", _status_burn_successes, " bleed=", _status_bleed_successes, " stun=", _status_stun_successes, " buffs=", _status_buffs, " healing teach=", _status_teach_seen, " failures=", _failures)
	await super._shutdown()
