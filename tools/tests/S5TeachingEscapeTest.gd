extends "res://tools/dev/S5TeachingFightPreview.gd"
## Real Game/court/player tests. Root serializes engine runs.
## <godot> --headless --path . res://tools/tests/S5TeachingEscapeTest.tscn
## Optional -- --seed=16102026 --case=slam|shock|rush|fan|mines|melee|boundary|ambient|adds
##   --role=tank|mage --out=C:/isolated/evidence
## No fake clock steps, player damage immunity, resized Hurtbox or teleport
## during an attempt. Direct cast calls only arrange a controlled attack.

var _results: Array[Dictionary] = []
var _observed_mines: Dictionary = {}
var _observed_mine_payloads: Dictionary = {}
var _runner_access_active := false
var _observed_runners: Dictionary = {}
var _runner_kills: Dictionary = {}


func _requires_rendering() -> bool:
	return false


func _execute() -> void:
	_immortal = false
	_ambient = false
	var seeds: Array[int] = [_seed_value] if _seed_explicit else [16102026, 16102027]
	var roles: Array[String] = [_role] if _role_explicit else ["tank", "mage"]
	for chosen_seed in seeds:
		for role_value in roles:
			var cases: Array[String] = ["rush", "slam", "shock"] if role_value == "tank" else ["fan", "mines"]
			if not _only_case.is_empty():
				cases = [_only_case] if cases.has(_only_case) else []
			if cases.is_empty() and _only_case != "melee":
				continue
			if not await _setup_world(role_value, chosen_seed):
				continue
			for attack in cases:
				var stationary := await _escape_attempt(attack, "stay")
				var walking := await _escape_attempt(attack, "walk")
				if attack != "mines":
					_check(int(stationary.get("danger_attempts", 0)) > 0, "%s seed%d stationary control reaches the actual full Hurtbox" % [attack, chosen_seed])
				_check(int(walking.get("danger_attempts", 1)) == 0, "%s seed%d baseline walking after150ms escapes without dash or a damage-resolution attempt" % [attack, chosen_seed])
				_check(int(walking.get("dashes", -1)) == 0, "%s walking case never invokes dash" % attack)
				# Independent dash case: verify the actual input verb, not a
				# borrowed invulnerability grant or artificial relocation.
				if attack in ["rush", "slam", "fan"]:
					var dashed := await _escape_attempt(attack, "dash")
					_check(int(dashed.get("dashes", 0)) == 1, "%s separate dash case fires exactly one native dash" % attack)
					_check(float(dashed.get("danger_hp_loss", 1.0)) <= 0.001, "%s separate dash case avoids boss hazard HP loss" % attack)
			if _only_case.is_empty() or _only_case == "melee":
				await _melee_recovery_attempt()
		# One additional real court-edge case per seed validates movement
		# against surrounding production geometry, not an empty fixture plane.
		if (_only_case.is_empty() or _only_case == "boundary") and roles.has("tank"):
			if await _setup_world("tank", chosen_seed):
				var boundary := await _escape_attempt("slam", "walk", true)
				_check(int(boundary.get("danger_attempts", 1)) == 0, "court-edge slam seed%d has a full-body walking escape into the actual court" % chosen_seed)
		if (_only_case.is_empty() or _only_case == "adds") and roles.has("tank"):
			await _runner_access_attempt(chosen_seed)
	if (_only_case.is_empty() or _only_case == "ambient") and roles.has("mage"):
		await _ambient_access_attempt()
	if _out != "res://.superpowers/sdd/s5-teaching-fights/live":
		var absolute_out := ProjectSettings.globalize_path(_out)
		DirAccess.make_dir_recursive_absolute(absolute_out)
		_write_json(absolute_out.path_join("escape-results.json"), {"presentation": "Automated paired real Game/court controls, not human satisfaction or finished animation", "reaction": REACTION, "speed": 100.0, "hurtbox": "real70x70 rectangle", "body": "real radius25 height58 capsule", "cases": _results, "passes": _passes, "failures": _failures, "save_writes": SaveManager.debug_save_writes - _save_writes_before})
	print("S5TeachingEscapeTest: ", _passes, " passed, ", _failures, " failed")


func _escape_attempt(attack: String, response: String, boundary: bool = false) -> Dictionary:
	if not await _spawn_boss():
		return {}
	# Keep unrelated automatic patterns outside this short isolated attempt.
	for property in ["_slam_cd", "_shock_cd", "_rush_cd", "_summon_cd", "_fan_cd", "_mines_cd", "_beam_cd", "_pylons_cd", "_blink_cd"]:
		if property in _brain:
			_brain.set(property, 100.0)
	_boss._charge._cd = 100.0
	if boundary:
		_boss.global_position = _origin + Vector2(-535, 0)
		_boss.set_meta(&"boss_home_pos", _boss.global_position)
	_player.rotation = 0.0
	var contact := _contact_distance()
	_player.global_position = _boss.global_position + Vector2(contact, 0)
	_player.velocity = Vector2.ZERO
	_player.call("cancel_dash")
	var dash := _player.get("_dash") as PlayerDashState
	dash.reset()
	if response != "dash":
		dash.cooldown_left = 100.0
	_player.set("invulnerable_time", 0.0)
	_player.set("hp", _player.get("max_hp"))
	# Let physics observe the arranged legal initial positions while player
	# and boss movement are disabled. No displacement occurs once time starts.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body := _player.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = body.global_transform
	query.collision_mask = _player.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_player.get_rid()]
	_check(_player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "%s starts at a legal capsule/body contact position in the real world" % attack)
	_reset_evidence()
	_control = response
	_escape_direction = Vector2.RIGHT if attack == "slam" or attack == "mines" else Vector2.DOWN
	_attack_enabled = false
	_activate_combat()
	_running = true
	match attack:
		"rush":
			if _brain.has_method("_begin_teaching_rush"):
				_brain.call("_begin_teaching_rush")
			else:
				_fail("Tank teaching rush interface is absent.")
		"slam":
			_brain.call("_do_slam")
		"shock":
			_brain.call("_do_shockwave")
		"fan":
			_brain.call("_fan_shot")
		"mines":
			_brain.call("_drop_mines")
			if "_teaching_escape" in _brain:
				_escape_direction = (_brain.get("_teaching_escape") as Vector2).normalized()
	var expected_state := "rush_tell" if attack == "rush" else attack
	_check(String(_boss.get_meta(&"boss_teaching_state", &"")) == expected_state, "%s controlled arrangement started its real teaching cast" % attack)
	var duration := 2.8 if attack == "mines" else (2.5 if attack == "shock" else 2.1)
	while _time < duration and not bool(_player.get("is_dead")):
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_boss.set_physics_process(false)
	_brain.set_process(false)
	_brain.set_physics_process(false)
	var danger_attempts := 0
	var danger_loss := 0.0
	var contact_loss := 0.0
	for hit in _damage:
		if String(hit["kind"]) == "contact_swarm":
			contact_loss += float(hit["applied"])
		elif bool(hit["boss_owned"]):
			danger_attempts += 1
			danger_loss += float(hit["applied"])
	if attack == "mines":
		_check(_observed_mines.size() == 3, "mine %s control observes all three actual boss-owned mines" % response)
		_check(_observed_mine_payloads.size() == 3, "mine %s control observes all three real detonation payloads, not a skipped cast" % response)
	var result := {"seed": _seed_value, "role": _role, "attack": attack, "response": response, "boundary": boundary, "contact_distance": contact, "escape_direction": str(_escape_direction), "danger_attempts": danger_attempts, "danger_hp_loss": danger_loss, "ordinary_contact_hp_loss": contact_loss, "dashes": _dashes, "observed_mines": _observed_mines.size(), "observed_mine_payloads": _observed_mine_payloads.size(), "player_final": str(_player.global_position), "boss_final": str(_boss.global_position), "events": _events.duplicate(true), "damage": _damage.duplicate(true)}
	_results.append(result)
	print("S5 escape case: ", JSON.stringify(result))
	return result


func _melee_recovery_attempt() -> void:
	if not await _spawn_boss():
		return
	for property in ["_slam_cd", "_shock_cd", "_rush_cd", "_summon_cd", "_fan_cd", "_mines_cd", "_beam_cd", "_pylons_cd", "_blink_cd"]:
		if property in _brain:
			_brain.set(property, 100.0)
	_boss._charge._cd = 100.0
	_player.rotation = 0.0
	_player.global_position = _boss.global_position + Vector2(_contact_distance() + 1.0, 0)
	_player.set("hp", _player.get("max_hp"))
	_player.set("invulnerable_time", 0.0)
	_reset_evidence()
	_control = "natural"
	_attack_enabled = true
	_activate_combat()
	_running = true
	if _role == "tank":
		_brain.call("_do_slam")
	else:
		_brain.call("_fan_shot")
	var hp_before := _boss.hp
	while _time < 3.0 and not bool(_player.get("is_dead")):
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_check(_boss_hits > 0 and _boss.hp < hp_before, "%s real native melee reaches the production body without resizing collision" % _role)
	_check(_recovery_hits > 0, "%s explicit recovery allows at least one genuine native melee hit" % _role)
	_results.append({"seed": _seed_value, "role": _role, "case": "native_melee_recovery", "hits": _boss_hits, "recovery_hits": _recovery_hits, "boss_hp_before": hp_before, "boss_hp_after": _boss.hp, "events": _events.duplicate(true), "damage": _damage.duplicate(true)})


func _ambient_access_attempt() -> void:
	# An explicit controlled ambient case, not an Arcanist reinforcement.
	# Its enemies come from the real normal spawner/table with real limits;
	# no fixture EnemyActor, synthetic death event or direct kill is injected.
	_ambient = true
	if not await _setup_world("mage", _seed_value):
		return
	if not await _spawn_boss():
		return
	_player.global_position = _boss.global_position + Vector2(0, 220)
	_start_bounded_ambient()
	_reset_evidence()
	_control = "natural"
	_attack_enabled = true
	_activate_combat()
	_running = true
	while _time < 18.0 and not bool(_player.get("is_dead")) and not get_tree().paused:
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_check(int(_ambient_result.get("spawned", 0)) > 0, "controlled ambient case used actual production normal-spawner targets")
	_check(_native_kills > 0, "S5 Mage controlled ambient case permits genuine player-attributed normal kills")
	_check(_cleaves() > _cleaves_before, "genuine ambient melee kills activate the existing connected Execution/Cleave consumer")
	_check(_max_enemies <= 9, "controlled ambient population remains bounded to8 normals plus the boss")
	var result := _summary()
	result["case"] = "CONTROLLED AMBIENT ACCESS; not Mage-provided adds or a difficulty claim"
	result["loadout"] = ["EX01", "EX03", "EX06"]
	result["spawner_result"] = _ambient_result
	result["cleaves_delta"] = _cleaves() - _cleaves_before
	result["events"] = _events.duplicate(true)
	result["damage"] = _damage.duplicate(true)
	_results.append(result)
	_ambient = false


func _runner_access_attempt(chosen_seed: int) -> void:
	# Install the existing Execution fixture loadout only. The ordinary
	# spawner stays disabled; all targets must arrive from the real tank call.
	_ambient = true
	var world_ready := await _setup_world("tank", chosen_seed)
	_ambient = false
	if not world_ready:
		return
	var previous_ratio := _boss_hp_ratio
	_boss_hp_ratio = 0.49
	if not await _spawn_boss():
		_boss_hp_ratio = previous_ratio
		return
	_player.global_position = _boss.global_position + Vector2(0, 220)
	_player.velocity = Vector2.ZERO
	_player.call("cancel_dash")
	(_player.get("_dash") as PlayerDashState).reset()
	_player.set("invulnerable_time", 0.0)
	_reset_evidence()
	_runner_access_active = true
	_game.child_entered_tree.connect(_observe_runner_arrival)
	_cleaves_before = _cleaves()
	var save_writes_before := SaveManager.debug_save_writes
	_control = "natural"
	_attack_enabled = true
	_activate_combat()
	_running = true
	# No cast, damage or death is injected. The below-half-health controller
	# chooses its one warned call, and native melee earns the first kill.
	while _time < 18.0 and not bool(_player.get("is_dead")) and not get_tree().paused:
		if _observed_runners.size() == 3 and not _runner_kills.is_empty() and _cleaves() > _cleaves_before:
			break
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_game.child_entered_tree.disconnect(_observe_runner_arrival)
	_check(_observed_runners.size() == 3, "controlled49% tank naturally calls exactly three real source-owned boss_add Runners")
	_check(not _runner_kills.is_empty(), "native player melee earns a real player-attributed boss_add Runner kill")
	_check(_cleaves() > _cleaves_before, "real Runner kill activates the connected Execution/Cleave consumer")
	_check(_max_enemies <= 4, "Runner access population remains bounded to the boss plus its three finite adds")
	_check(SaveManager.debug_save_writes == save_writes_before, "controlled Runner access writes no profile data")
	var result := _summary()
	result["case"] = "CONTROLLED TANK RUNNER ACCESS; starting HP49%; existing Execution fixture loadout; ordinary spawner disabled"
	result["loadout"] = ["EX01", "EX03", "EX06"]
	result["simulation_seconds"] = _time
	result["observed_runners"] = _observed_runners.duplicate(true)
	result["runner_kills"] = _runner_kills.duplicate(true)
	result["cleaves_delta"] = _cleaves() - _cleaves_before
	result["events"] = _events.duplicate(true)
	result["damage"] = _damage.duplicate(true)
	_results.append(result)
	_runner_access_active = false
	_boss_hp_ratio = previous_ratio


func _is_owned_runner(node: Node) -> bool:
	if not is_instance_valid(node) or not node is EnemyActor or not is_instance_valid(_boss):
		return false
	if node.scene_file_path != "res://scenes/world/enemies/EnemyRunner.tscn" or node.get_meta(&"special_spawn_kind", &"") != &"boss_add":
		return false
	var reference := node.get_meta(&"boss_attack_scope", null) as WeakRef
	var scope = reference.get_ref() if reference != null else null
	return is_instance_valid(scope) and scope.owns_actor(_boss)


func _observe_runner_arrival(node: Node) -> void:
	if not _runner_access_active or not _running or node.is_queued_for_deletion() or not _is_owned_runner(node):
		return
	var id := node.get_instance_id()
	var handle := EnemyWorld.handle_for_actor(node)
	if not _observed_runners.has(id):
		_observed_runners[id] = {"instance_id": id, "handle": handle, "arrival_time": _time, "arrival_world": str((node as Node2D).global_position), "spawn_kind": "boss_add", "scene": node.scene_file_path}
		_events.append({"time": _time, "event": "real_runner_arrival", "instance_id": id})
	elif handle != 0:
		_observed_runners[id]["handle"] = handle


func _attack_target() -> Vector2:
	if _runner_access_active and is_instance_valid(_game) and is_instance_valid(_player):
		var nearest := INF
		var target := Vector2.INF
		for node: Node in _game.get_children():
			var runner := node as EnemyActor
			if runner == null or not _is_owned_runner(runner) or runner.dead or runner.is_queued_for_deletion():
				continue
			var distance := _player.global_position.distance_squared_to(runner.global_position)
			if distance < nearest:
				nearest = distance
				target = runner.global_position
		if target != Vector2.INF:
			return target
	return super._attack_target()


func _on_death(context: RefCounted) -> void:
	super._on_death(context)
	if not _runner_access_active or not _running or context.get("source") != _player or context.get("spec_id") != &"enemy_runner":
		return
	var metadata: Dictionary = context.get("metadata")
	if metadata.get("special_spawn_kind", &"") != &"boss_add":
		return
	var handle := int(context.get("handle"))
	var runner := EnemyWorld.actor_for_handle(handle)
	if not _is_owned_runner(runner) or not _observed_runners.has(runner.get_instance_id()):
		return
	var id := runner.get_instance_id()
	_observed_runners[id]["handle"] = handle
	_runner_kills[handle] = {"instance_id": id, "handle": handle, "time": _time, "source": "native player", "spawn_kind": "boss_add"}
	_events.append({"time": _time, "event": "native_runner_kill", "instance_id": id, "handle": handle})


func _reset_evidence() -> void:
	super._reset_evidence()
	_observed_mines.clear()
	_observed_mine_payloads.clear()
	_observed_runners.clear()
	_runner_kills.clear()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _running or not is_instance_valid(_game) or not is_instance_valid(_boss):
		return
	# A safe corridor is meaningful only beside a real released constellation.
	# Observe production nodes; do not manufacture a positive damage control
	# in the deliberately safe center or invoke mine explosion manually.
	for node: Node in _game.get_children():
		if node.is_queued_for_deletion():
			continue
		if _runner_access_active:
			_observe_runner_arrival(node)
		if node is BossMine and node.source == _boss:
			_observed_mines[node.get_instance_id()] = true
		elif node is DamageCircle and node.source == _boss and node.attack_style == &"mine":
			_observed_mine_payloads[node.get_instance_id()] = true
