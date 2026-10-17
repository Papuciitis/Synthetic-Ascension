extends "res://tools/dev/S5TeachingFightPreview.gd"
## Real Game / S10 court / production player controls for the main-boss kits.
## Each new S10 commitment is arranged through the brain entry point that runs
## BossEscapeOracle, so it starts only when the oracle found a route. The
## player then walks that same route with native input after 150 ms at the
## production 100 px/s, dash unavailable; a paired stationary control must be
## reached by the attack. Root serializes engine runs.
## <godot> --headless --path . res://tools/tests/S10MainBossEscapeTest.tscn
## Optional -- --seed=16102026 --role=tank|mage --out=/isolated/evidence
##   --s10-case=cleave|breach|fault|split|sweep|convergence|mines
## No fake clock steps, player damage immunity, resized Hurtbox or teleport
## during an attempt. Direct entry-point calls only arrange the attack.

const Oracle := preload("res://scenes/world/bosses/BossEscapeOracle.gd")
const Placement := preload("res://scenes/world/bosses/BossTeachingPlacement.gd")
const MAGE_BRAIN := preload("res://scenes/world/bosses/BossArcanistBrain.gd")
const TANK_CASES: Array[String] = ["cleave", "breach", "fault"]
const MAGE_CASES: Array[String] = ["split", "sweep", "convergence", "mines"]
## Long enough for each attack's last payload to have resolved.
const DURATIONS := {"cleave": 1.6, "breach": 2.4, "fault": 3.6, "split": 3.0, "sweep": 2.9, "convergence": 4.0, "mines": 2.8, "slam": 1.8}
## Bulldozer placements beside a wall where reviews found certified walks the
## turned body could not keep: the attack, the boss's distance, degrees off
## the wall's normal (both sides are walked) and the phase.
const WALL_WALKS := [
	{"attack": "fault", "distance": 300.0, "degrees": 40.0, "phase": 1},
	{"attack": "fault", "distance": 280.0, "degrees": 31.0, "phase": 2},
	{"attack": "slam", "distance": 130.0, "degrees": 8.0, "phase": 1},
	{"attack": "cleave", "distance": 130.0, "degrees": 11.0, "phase": 1},
]
const PARKED_CLOCKS: Array[String] = ["_slam_cd", "_shock_cd", "_rush_cd", "_cleave_cd", "_breach_cd", "_fan_cd", "_mines_cd", "_blink_cd", "_split_cd", "_sweep_cd", "_convergence_cd"]

var _main_arena: BossArena
var _s10_case := ""
var _results: Array[Dictionary] = []
var _expected_results := 0
var _observed_mines: Dictionary = {}
var _observed_mine_payloads: Dictionary = {}


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--s10-case="):
			_s10_case = arg.trim_prefix("--s10-case=")


func _requires_rendering() -> bool:
	return false


func _execute() -> void:
	_immortal = false
	_ambient = false
	if not _s10_case.is_empty() and not (TANK_CASES.has(_s10_case) or MAGE_CASES.has(_s10_case)):
		_fail("Unknown --s10-case selection.")
		return
	var seeds: Array[int] = []
	seeds.assign([_seed_value] if _seed_explicit else [16102026, 16102027])
	var roles: Array[String] = []
	roles.assign([_role] if _role_explicit else ["tank", "mage"])
	for chosen_seed in seeds:
		for role_value in roles:
			var cases: Array[String] = []
			cases.assign(TANK_CASES if role_value == "tank" else MAGE_CASES)
			if not _s10_case.is_empty():
				cases.assign([_s10_case] if cases.has(_s10_case) else [])
			if cases.is_empty():
				continue
			# Count requested work before any awaited setup, so an aborted
			# helper cannot pass by omission.
			_expected_results += cases.size() * 2
			if _s10_case.is_empty():
				# The native-melee recovery, the wall rest, the wall end, and the
				# tank's walks beside a wall, the boss to either side.
				_expected_results += 3 + (2 * WALL_WALKS.size() if role_value == "tank" else 0)
			if not await _setup_world(role_value, chosen_seed):
				continue
			for attack in cases:
				var stationary := await _escape_attempt(attack, "stay")
				var walking := await _escape_attempt(attack, "walk")
				# Mine patterns are not oracle-gated: the player's spot is safe by
				# construction and the walk follows the committed corridor.
				var walked := "the committed corridor" if attack == "mines" else "the oracle's route"
				if attack != "mines":
					_check(int(stationary.get("danger_attempts", 0)) > 0, "%s seed%d stationary control is reached by the actual attack" % [attack, chosen_seed])
				_check(bool(walking.get("committed", false)) and int(walking.get("danger_attempts", 1)) == 0, "%s seed%d walking %s after150ms escapes without dash or a damage-resolution attempt" % [attack, chosen_seed, walked])
				if attack == "mines":
					_check(is_zero_approx(float(walking.get("ordinary_contact_hp_loss", -1.0))), "mines seed%d: the corridor never leads into the boss's body" % chosen_seed)
				_check(int(walking.get("dashes", -1)) == 0, "%s seed%d walking case never invokes dash" % [attack, chosen_seed])
			if _s10_case.is_empty():
				# At body contact the main Arcanist commits its focused fan; the
				# oracle rightly refuses a Split Fan there.
				await _melee_recovery_attempt("cleave" if role_value == "tank" else "fan")
				await _wall_hug_attempt()
				await _wall_end_attempt()
				if role_value == "tank":
					var committed_any := false
					for placement: Dictionary in WALL_WALKS:
						for side in [1.0, -1.0]:
							var committed := await _wall_walk_attempt(String(placement["attack"]), float(placement["distance"]), float(placement["degrees"]) * side, int(placement["phase"]))
							committed_any = committed_any or committed
					_check(committed_any, "fixture: tank seed%d: beside the wall, some placement commits, so the walk is exercised" % chosen_seed)
	_execution_completed = _expected_results > 0 and _results.size() == _expected_results
	_check(_execution_completed, "all %d requested S10 case results completed; no setup/helper abort or omitted case" % _expected_results)
	if _out != "res://.superpowers/sdd/s5-teaching-fights/live":
		var absolute_out := ProjectSettings.globalize_path(_out)
		DirAccess.make_dir_recursive_absolute(absolute_out)
		_write_json(absolute_out.path_join("s10-escape-results.json"), {"presentation": "Automated paired real Game/S10 court controls along the oracle's own routes (the mine arc: its committed corridor); not human satisfaction or finished animation", "reaction": REACTION, "speed": 100.0, "hurtbox": "real70x70 rectangle", "body": "real radius25 height58 capsule", "expected_case_results": _expected_results, "completed_case_results": _results.size(), "cases": _results, "passes": _passes, "failures": _failures, "save_writes": SaveManager.debug_save_writes - _save_writes_before})


func _setup_world(role_value: String, seed_value: int) -> bool:
	await _shutdown_world()
	_role = role_value
	_seed_value = seed_value
	SettingsManager.set_value(&"accessibility", &"combat_flash", "full", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"controls", &"hold_to_attack", true, false)
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = false
	Global.debug_encounter_beats = false
	Global.selected_race_id = "human"
	Global.selected_style_id = "melee"
	Global.selected_weapon_id = "melee"
	Global.start_new_attempt()
	Global.attempt_segment = Global.FINAL_SEGMENT
	Global.attempt_world_seed = seed_value
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	seed(seed_value)
	Global._rng.seed = seed_value
	Engine.max_fps = 60
	Engine.time_scale = 1.0
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	if builder == null:
		_fail("Actual Game has no procedural builder.")
		return false
	_plan = builder._plan.duplicate(true)
	var planned: Vector2 = _plan.get("boss_world", Vector2.ZERO)
	if planned == Vector2.ZERO:
		_fail("S10 district has no boss court.")
		return false
	_origin = SPACE.anchor_world(planned, _chunks.chunk_size_px)
	_main_arena = null
	for child: Node in _game.find_children("*", "", true, false):
		if child is BossArena or child is MiniBossArena:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			var trigger := child.get_node_or_null("Trigger") as Area2D
			if trigger != null:
				trigger.monitoring = false
				trigger.monitorable = false
			if child is BossArena and child.global_position.is_equal_approx(_origin):
				_main_arena = child as BossArena
	if _main_arena == null:
		_fail("S10 court does not contain its actual BossArena.")
		return false
	_player.global_position = _origin + Vector2(0, 320)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var settled := false
	for frame in range(360):
		await get_tree().process_frame
		if frame >= 12 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	_dismiss_tutorials()
	_check(settled, "actual S10 court finished streaming (seed%d)" % seed_value)
	_check(is_equal_approx(float(_player.call("get_effective_move_speed")), 100.0), "unmodified production human melee speed is100 world px/s at S10")
	var body := _player.get_node("CollisionShape2D") as CollisionShape2D
	var hurt := _player.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	_check(body.shape is CapsuleShape2D and hurt.shape is RectangleShape2D and (hurt.shape as RectangleShape2D).size == Vector2(70, 70), "production capsule and complete70x70 Hurtbox are retained")
	return settled


func _spawn_boss() -> bool:
	_running = false
	_release_inputs()
	if is_instance_valid(_boss):
		_boss.queue_free()
		await _frames(2)
	_main_arena.set("_boss", null)
	_main_arena.set("_spawned", false)
	_main_arena.set("_cleared", false)
	_main_arena.set("_spawn_in_progress", false)
	_main_arena.set("_retry_not_before_ms", 0)
	_main_arena.tank_boss_scenes.clear()
	_main_arena.mage_boss_scenes.clear()
	if _role == "tank":
		_main_arena.tank_boss_scenes.append(TANK)
	else:
		_main_arena.mage_boss_scenes.append(MAGE)
	_main_arena.call("_spawn")
	_boss = _main_arena.get("_boss") as EnemyActor
	if _boss == null:
		_fail("Actual S10 arena did not create its chosen archetype.")
		return false
	_boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	_boss.player = _player
	_brain = _boss.get_node("BossBrain")
	_boss.set_physics_process(false)
	_boss.set_process(false)
	_brain.set_process(false)
	_brain.set_physics_process(false)
	_boss_starting_health = _boss.hp
	_boss_max_health = _boss.max_hp
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_dismiss_tutorials()
	return true


func _escape_attempt(attack: String, response: String) -> Dictionary:
	if not await _spawn_boss():
		return {}
	_check(_boss.is_in_group(&"boss"), "%s: the actual S10 arena names its boss main tier" % attack)
	# Name the tier first: its opening clocks must not reopen after parking.
	if _brain.has_method("_sync_tier"):
		_brain.call("_sync_tier")
	if _brain.has_method("_ensure_teaching"):
		_brain.call("_ensure_teaching")
	for property in PARKED_CLOCKS:
		if property in _brain:
			_brain.set(property, 100.0)
	_boss._charge._cd = 100.0
	# The attack's phase is arranged directly; health and thresholds are untouched.
	_brain.set("_boss_phase", 2 if attack in ["breach", "fault", "convergence", "mines"] else 1)
	_player.rotation = 0.0
	_player.global_position = _boss.global_position + Vector2(_arranged_distance(attack), 0)
	_player.velocity = Vector2.ZERO
	_player.call("cancel_dash")
	var dash := _player.get("_dash") as PlayerDashState
	dash.reset()
	dash.cooldown_left = 100.0
	_player.set("invulnerable_time", 0.0)
	_player.set("hp", _player.get("max_hp"))
	# Let physics observe the arranged legal positions while movement is off.
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
	_check(_player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "%s starts at a legal capsule position in the real S10 court" % attack)
	_reset_evidence()
	_control = response
	_attack_enabled = false
	_activate_combat()
	_running = true
	var committed := false
	if _role == "tank":
		committed = bool(_brain.call("_try_main_attack", _tank_kind(attack)))
	else:
		committed = bool(_brain.call("_try_main_pattern", attack))
	_check(committed, "%s %s: the real entry point committed%s" % [attack, response, "" if attack == "mines" else ", so the oracle found a route"])
	var route: Variant = _route_for(attack) if committed else null
	# Recovery clears the commitment; keep what was committed for the record.
	var committed_direction: Vector2 = _brain.get("_cast_dir") if _role == "tank" else _brain.get("_split_dir")
	var followup: Vector2 = _brain.get("_followup_dir") if _role == "tank" else Vector2.ZERO
	_escape_direction = route if route is Vector2 else Vector2.ZERO
	if attack == "mines" and "_teaching_escape" in _brain:
		# Not oracle-gated: the constellation keeps its checked corridor.
		_escape_direction = (_brain.get("_teaching_escape") as Vector2).normalized()
	elif committed:
		_check(route is Vector2 and not (route as Vector2).is_zero_approx(), "%s %s: the arranged position needs a step, so the stationary control is meaningful" % [attack, response])
	if attack == "fault":
		_check(not followup.is_zero_approx(), "fault %s: the phase 3 follow-up line was committed, not the plain line" % response)
	var duration: float = DURATIONS[attack]
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
		_check(_observed_mines.size() == 4, "mine %s control observes all four actual boss-owned mines of the S10 arc" % response)
		_check(_observed_mine_payloads.size() == 4, "mine %s control observes all four real detonation payloads" % response)
	var result := {"seed": _seed_value, "role": _role, "attack": attack, "response": response, "committed": committed, "phase": int(_brain.get("_boss_phase")), "arranged_distance": _arranged_distance(attack), "route": str(_escape_direction), "committed_direction": str(committed_direction), "followup_direction": str(followup), "danger_attempts": danger_attempts, "danger_hp_loss": danger_loss, "ordinary_contact_hp_loss": contact_loss, "dashes": _dashes, "observed_mines": _observed_mines.size(), "observed_mine_payloads": _observed_mine_payloads.size(), "player_final": str(_player.global_position), "boss_final": str(_boss.global_position), "events": _events.duplicate(true), "damage": _damage.duplicate(true)}
	_results.append(result)
	print("S10 escape case: ", JSON.stringify(result))
	return result


## A player resting against a real court wall still draws the boss's aimed
## attack. The wall's blocked grid cells reach past its face, and judging a
## walk's whole width on that grid refused every walk along or away from it,
## so the boss never attacked a player hugging a wall.
func _wall_hug_attempt() -> void:
	if not await _spawn_boss():
		return
	_prepare_main_attack()
	var rest := await _rest_against_wall()
	if rest.is_empty():
		return
	var toward: Vector2 = rest["toward"]
	var wall: Vector2i = rest["wall"]
	var resting: bool = rest["resting"]
	# The boss attacks from 300 px straight out, so the attack's line meets
	# the wall square on and a walk along the wall leaves it. The court keeps
	# its own home, leash and disengage radius: this wall lies inside the
	# fight.
	var out := -toward
	_boss.global_position = _player.global_position + out * 300.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var home: Vector2 = _boss.get_meta(&"boss_home_pos", Vector2.INF)
	var player_from_home := _player.global_position.distance_to(home)
	var boss_from_home := _boss.global_position.distance_to(home)
	_check(player_from_home < float(_boss.get_meta(&"boss_disengage_radius", 0.0)) and boss_from_home < float(_boss.get_meta(&"boss_leash_radius", 0.0)), "fixture: %s seed%d: the wall lies inside the fight (player %.0f px from home, boss %.0f px)" % [_role, _seed_value, player_from_home, boss_from_home])
	var plan: Array = []
	var blockers: Array = []
	if _role == "tank":
		plan = _brain.call("_plan_for", &"shock", _boss.global_position, toward)
		blockers = [{"center": _boss.global_position, "radius": float(_brain.call("_body_radius"))}]
	else:
		plan = _brain.call("_fan_plan", _boss.global_position, toward, _brain.call("_focused_angles"), 0.95, 320.0, 1.625)
		blockers = [{"center": _boss.global_position, "radius": Placement.body_radius(_boss)}]
	_check(Oracle.has_escape(_player.global_position, plan, Oracle.player_shape(_player), blockers, Callable(), Oracle.walking_speed(_player)), "fixture: %s seed%d: in open ground the same attack leaves a walk out" % [_role, _seed_value])
	var committed := bool(_brain.call("_try_main_attack", &"shock")) if _role == "tank" else bool(_brain.call("_try_main_pattern", &"fan"))
	_check(committed, "%s seed%d: a player resting against a real court wall still draws the boss's aimed attack" % [_role, _seed_value])
	_results.append({"seed": _seed_value, "role": _role, "case": "wall_rest", "wall_cell": wall, "player_from_home": player_from_home, "boss_from_home": boss_from_home, "resting": resting, "committed": committed})


## Rests the production player against the wall cell nearest the court's
## centre in the middle of a straight run of nine wall cells with open ground
## before them, so a walk along the wall is open both ways rather than into a
## corner, and open ground out to where the boss stands: {wall, toward,
## resting}, or {} with no such wall.
func _rest_against_wall() -> Dictionary:
	var home_cell := _chunks.world_to_cell(_origin)
	var found := false
	var wall := home_cell
	var open := home_cell
	for ring in range(1, 21):
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if found or maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell := home_cell + Vector2i(dx, dy)
				var inward := Vector2i(-signi(dx), 0) if absi(dx) >= absi(dy) else Vector2i(0, -signi(dy))
				var side := Vector2i(inward.y, inward.x)
				var straight := true
				for k in range(-4, 5):
					var along := cell + side * k
					for depth in range(1, 4 if absi(k) > 1 else 7):
						straight = straight and _chunks.is_cell_walkable(along + inward * depth)
					straight = straight and not _chunks.is_cell_walkable(along)
				if straight:
					found = true
					wall = cell
					open = cell + inward
		if found:
			break
	_check(found, "%s seed%d: the court has a wall to rest against" % [_role, _seed_value])
	if not found:
		return {}
	var toward := Vector2(wall - open).normalized()
	var resting := await _rest_player(_chunks.cell_to_world_center(open), toward)
	_check(resting, "fixture: %s seed%d: the player rests against the wall" % [_role, _seed_value])
	return {"wall": wall, "toward": toward, "resting": resting}


## Walks the production player from `from` toward `toward` until it touches,
## facing it, then stops it there.
func _rest_player(from: Vector2, toward: Vector2) -> bool:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.rotation = toward.angle()
	_player.velocity = Vector2.ZERO
	_player.global_position = from
	await get_tree().physics_frame
	var resting := false
	for _step in range(48):
		if _player.move_and_collide(toward * 4.0) != null:
			resting = true
			break
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	return resting


## A player standing beside a wall run's end, inside its blocked cell (the
## wall's bar stops at the cell's centre), still draws the boss's aimed
## attack: every walk used to start on a blocked cell and was refused.
func _wall_end_attempt() -> void:
	if not await _spawn_boss():
		return
	_prepare_main_attack()
	# The wall cell ending a straight run (one wall neighbour along the run,
	# open cells beyond it and on both sides) nearest the boss's home, where a
	# player beside it is inside the fight.
	var home: Vector2 = _boss.get_meta(&"boss_home_pos", _origin)
	var reach := float(_boss.get_meta(&"boss_disengage_radius", 0.0)) - 20.0
	var home_cell := _chunks.world_to_cell(home)
	var best := INF
	var end_cell := home_cell
	var run := Vector2i.ZERO
	for dx in range(-20, 21):
		for dy in range(-20, 21):
			var cell := home_cell + Vector2i(dx, dy)
			if _chunks.is_cell_walkable(cell):
				continue
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var side := Vector2i(d.y, d.x)
				var shape_ok := not _chunks.is_cell_walkable(cell + d) and not _chunks.is_cell_walkable(cell + d * 2)
				for k in range(1, 3):
					shape_ok = shape_ok and _chunks.is_cell_walkable(cell - d * k)
				for along in [cell, cell - d]:
					shape_ok = shape_ok and _chunks.is_cell_walkable(along + side) and _chunks.is_cell_walkable(along - side)
				var distance := (_chunks.cell_to_world_center(cell) - Vector2(d) * 27.0).distance_to(home)
				if shape_ok and distance < reach and distance < best:
					best = distance
					end_cell = cell
					run = d
	_check(best < INF, "%s seed%d: the court has a wall run's end inside the fight to stand beside" % [_role, _seed_value])
	if best == INF:
		return
	# Walk into the bar's end along the run, and stop where the body touches.
	var resting := await _rest_player(_chunks.cell_to_world_center(end_cell) + Vector2(-run) * 60.0, Vector2(run))
	var inside := not _chunks.is_cell_walkable(_chunks.world_to_cell(_player.global_position))
	_check(resting and inside, "fixture: %s seed%d: the player rests against the run's end inside its blocked cell" % [_role, _seed_value])
	# The boss 300 px from the player toward its home, inside its leash.
	var aim := (_player.global_position - home).normalized()
	_boss.global_position = _player.global_position - aim * 300.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var plan: Array = []
	var blockers: Array = []
	if _role == "tank":
		plan = _brain.call("_plan_for", &"shock", _boss.global_position, aim)
		blockers = [{"center": _boss.global_position, "radius": float(_brain.call("_body_radius"))}]
	else:
		plan = _brain.call("_fan_plan", _boss.global_position, aim, _brain.call("_focused_angles"), 0.95, 320.0, 1.625)
		blockers = [{"center": _boss.global_position, "radius": Placement.body_radius(_boss)}]
	_check(Oracle.has_escape(_player.global_position, plan, Oracle.player_shape(_player), blockers, Callable(), Oracle.walking_speed(_player)), "fixture: %s seed%d: in open ground the same attack leaves a walk out (player %.0f px from home)" % [_role, _seed_value, best])
	var committed := bool(_brain.call("_try_main_attack", &"shock")) if _role == "tank" else bool(_brain.call("_try_main_pattern", &"fan"))
	_check(committed, "%s seed%d: a player beside a wall run's end, inside its blocked cell, still draws the boss's aimed attack" % [_role, _seed_value])
	_results.append({"seed": _seed_value, "role": _role, "case": "wall_end", "end_cell": end_cell, "from_home": best, "inside_blocked_cell": inside, "resting": resting, "committed": committed})


## The walk certified beside a wall is the one the production player makes:
## turned to walk along it, its capsule lies crosswise and the wall pushes it
## about 4 px off. The Bulldozer stands `distance` out, `degrees` off the
## wall's normal, and commits `attack` only if a walk the body can keep
## escapes it: refusing is fair, and a committed attack is walked along its
## certified route with native input and must draw no boss hit.
func _wall_walk_attempt(attack: String, distance: float, degrees: float, phase: int) -> bool:
	if not await _spawn_boss():
		return false
	_prepare_main_attack()
	_brain.set("_boss_phase", phase)
	var rest := await _rest_against_wall()
	if rest.is_empty():
		return false
	var toward: Vector2 = rest["toward"]
	_boss.global_position = _player.global_position + (-toward).rotated(deg_to_rad(degrees)) * distance
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.set("hp", _player.get("max_hp"))
	_player.set("invulnerable_time", 0.0)
	var dash := _player.get("_dash") as PlayerDashState
	dash.reset()
	dash.cooldown_left = 100.0
	_reset_evidence()
	_control = "walk"
	_attack_enabled = false
	_activate_combat()
	_running = true
	var committed := bool(_brain.call("_try_main_attack", _tank_kind(attack)))
	var route: Variant = _route_for(attack) if committed else null
	_escape_direction = route if route is Vector2 else Vector2.ZERO
	var label := "tank seed%d, %s phase %d at %.0f px, %+.0f deg" % [_seed_value, attack, phase, distance, degrees]
	_check(not committed or route is Vector2, "fixture: %s: a committed attack's certified route is rebuilt (%s)" % [label, route])
	while _time < float(DURATIONS[attack]) and not bool(_player.get("is_dead")):
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_boss.set_physics_process(false)
	_brain.set_process(false)
	_brain.set_physics_process(false)
	var danger_attempts := 0
	for hit in _damage:
		if String(hit["kind"]) != "contact_swarm" and bool(hit["boss_owned"]):
			danger_attempts += 1
	_check(danger_attempts == 0, "%s: %s draws no boss hit" % [label, "walking the certified route beside the wall" if committed else "refused, the attack"])
	_results.append({"seed": _seed_value, "role": _role, "case": "wall_walk", "attack": attack, "distance": distance, "degrees": degrees, "phase": phase, "route": str(_escape_direction), "committed": committed, "danger_attempts": danger_attempts, "player_final": str(_player.global_position), "damage": _damage.duplicate(true)})
	return committed


## The S10 brain as an attack finds it: its tier named, every other clock
## parked, phase 1.
func _prepare_main_attack() -> void:
	if _brain.has_method("_sync_tier"):
		_brain.call("_sync_tier")
	if _brain.has_method("_ensure_teaching"):
		_brain.call("_ensure_teaching")
	for property in PARKED_CLOCKS:
		if property in _brain:
			_brain.set(property, 100.0)
	_boss._charge._cd = 100.0
	_brain.set("_boss_phase", 1)


## The opening after an S10 commitment: native melee from body contact must
## land during the recovery the attack earns.
func _melee_recovery_attempt(attack: String) -> void:
	if not await _spawn_boss():
		return
	if _brain.has_method("_sync_tier"):
		_brain.call("_sync_tier")
	if _brain.has_method("_ensure_teaching"):
		_brain.call("_ensure_teaching")
	for property in PARKED_CLOCKS:
		if property in _brain:
			_brain.set(property, 100.0)
	_boss._charge._cd = 100.0
	_brain.set("_boss_phase", 1)
	_player.rotation = 0.0
	_player.global_position = _boss.global_position + Vector2(_contact_distance() + 1.0, 0)
	_player.velocity = Vector2.ZERO
	_player.set("hp", _player.get("max_hp"))
	_player.set("invulnerable_time", 0.0)
	_reset_evidence()
	_control = "natural"
	_attack_enabled = true
	_activate_combat()
	_running = true
	var committed := bool(_brain.call("_try_main_attack" if _role == "tank" else "_try_main_pattern", _tank_kind(attack) if _role == "tank" else StringName(attack)))
	_check(committed, "%s melee case: the S10 %s committed through its real entry point" % [_role, attack])
	var hp_before := _boss.hp
	while _time < 3.0 and not bool(_player.get("is_dead")):
		await get_tree().physics_frame
	_running = false
	_release_inputs()
	_check(_boss_hits > 0 and _boss.hp < hp_before, "%s S10 native melee reaches the production main-boss body" % _role)
	_check(_recovery_hits > 0, "%s S10 %s recovery allows at least one genuine native melee hit" % [_role, attack])
	_results.append({"seed": _seed_value, "role": _role, "case": "native_melee_recovery", "attack": attack, "committed": committed, "hits": _boss_hits, "recovery_hits": _recovery_hits, "boss_hp_before": hp_before, "boss_hp_after": _boss.hp, "events": _events.duplicate(true), "damage": _damage.duplicate(true)})


## Where each case stands the player, on the boss's +x side: inside the
## attack's selection range and inside its footprint.
func _arranged_distance(attack: String) -> float:
	match attack:
		"cleave":
			return _contact_distance() + 15.0
		"breach", "fault":
			return 200.0
		"mines":
			return 260.0
	return 300.0


func _tank_kind(attack: String) -> StringName:
	return &"shock" if attack == "fault" else StringName(attack)


## The route the oracle grants for the plan the brain just committed: the
## same hazards, timings, player shapes, body blocker and world corridor.
func _route_for(attack: String) -> Variant:
	var shape: Dictionary = Oracle.player_shape(_player)
	var plan: Array = []
	var blockers: Array = []
	if _role == "tank":
		var origin: Vector2 = _brain.get("_cast_origin")
		plan = _brain.call("_plan_for", _tank_kind(attack), origin, _brain.get("_cast_dir"), _brain.get("_followup_dir"))
		blockers = [{"center": origin, "radius": float(_brain.call("_body_radius"))}]
	else:
		var origin := _boss.global_position
		if attack in ["split", "convergence"]:
			plan = _brain.call("_fan_plan", _brain.get("_fan_origin"), _brain.get("_split_dir"), _brain.call("_split_angles", float(_brain.get("_split_side"))), MAGE_BRAIN.SPLIT_TELL, MAGE_BRAIN.SPLIT_SPEED, MAGE_BRAIN.SPLIT_LIFE)
		if attack in ["sweep", "convergence"]:
			var beam := _brain.get("_channel") as BossBeamSweep
			if beam == null:
				_fail("%s: no sweep channel was committed." % attack)
				return null
			var tell: float = MAGE_BRAIN.SWEEP_TELL if attack == "sweep" else MAGE_BRAIN.SPLIT_TELL + MAGE_BRAIN.CONVERGENCE_BEAM_DELAY
			plan.append(_brain.call("_sweep_hazard", origin, float(beam.get("_a0")), float(beam.get("_a1")), tell))
		blockers = [{"center": origin, "radius": Placement.body_radius(_boss)}]
	var clearance := Oracle.corridor_radius(shape)
	var path_clear := func(from: Vector2, to: Vector2) -> bool:
		return Placement.walk_clear(_boss, from, to, clearance)
	var settle := func(point: Vector2, facing: float) -> Vector2:
		return Placement.settled_position(_player, point, facing)
	return Oracle.escape_route(_player.global_position, plan, shape, blockers, path_clear, Oracle.walking_speed(_player), settle)


func _reset_evidence() -> void:
	super._reset_evidence()
	_observed_mines.clear()
	_observed_mine_payloads.clear()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _running or not is_instance_valid(_game) or not is_instance_valid(_boss):
		return
	# Observe the production mines and their payloads; never detonate one.
	for node: Node in _game.get_children():
		if node.is_queued_for_deletion():
			continue
		if node is BossMine and node.source == _boss:
			_observed_mines[node.get_instance_id()] = true
		elif node is DamageCircle and node.source == _boss and node.attack_style == &"mine":
			_observed_mine_payloads[node.get_instance_id()] = true
