extends Node
## LIVE controlled S5 combat in the actual Game/court with native player input.
## <godot> --path . res://tools/dev/S5TeachingFightPreview.tscn --
##   --role=tank|mage --width=1280|960 --seconds=14 --fps=15 --out=C:/folder
## Optional: --seed=16102026 --ambient --visible --capture-only-immortal.
##   --boss-hp-ratio=0.49 controls starting HP only; default1, range0.05..1.
## Inherited escape selectors: --case=rush|slam|shock|fan|mines|melee|boundary|ambient|adds.
## Ambient uses the production spawner, with a disclosed bounded population;
## it is not an Arcanist reinforcement move. No engine run beside a playtest.

const GAME := preload("res://scenes/game.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const SPACE := preload("res://core/systems/world/proc/BossArenaSpace.gd")
const VIEWPORT := Vector2i(1920, 1080)
const REACTION := 0.15
const INPUT_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"aim_left", &"aim_right", &"aim_up", &"aim_down", &"attack", &"dash", &"alt_attack"]

var _out := "res://.superpowers/sdd/s5-teaching-fights/live"
var _role := "tank"
var _role_explicit := false
var _only_case := ""
var _dimensions := Vector2i(1280, 720)
var _seed_value := 16102026
var _seed_explicit := false
var _seconds := 14.0
var _fps := 15
var _ambient := false
var _immortal := false
var _visible := false
var _boss_hp_ratio := 1.0
var _boss_starting_health := 0.0
var _boss_max_health := 0.0
var _save_writes_before := 0
var _failures := 0
var _passes := 0
var _game: Node2D
var _player: CharacterBody2D
var _boss: EnemyActor
var _brain: Node
var _arena: MiniBossArena
var _chunks: ChunkManager
var _camera: Camera2D
var _origin := Vector2.ZERO
var _plan: Dictionary = {}
var _running := false
var _time := 0.0
var _control := "natural"
var _escape_direction := Vector2.RIGHT
var _dash_pending := false
var _dash_sent := false
var _attack_enabled := false
var _state := ""
var _state_began := 0.0
var _state_direction := Vector2.RIGHT
var _state_sidestep := Vector2.ZERO
var _damage: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _frame_info: Array[Dictionary] = []
var _pixels: Array[Image] = []
var _native_fires := 0
var _boss_hits := 0
var _recovery_hits := 0
var _native_kills := 0
var _dashes := 0
var _starting_health := 0.0
var _ambient_result: Dictionary = {}
var _cleaves_before := 0
var _max_enemies := 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/s5_teaching_probe_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
			_role_explicit = true
		elif arg.begins_with("--case="):
			_only_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--width="):
			var width_value := int(arg.trim_prefix("--width="))
			_dimensions = Vector2i(width_value, width_value * 9 / 16)
		elif arg.begins_with("--seed="):
			_seed_value = int(arg.trim_prefix("--seed="))
			_seed_explicit = true
		elif arg.begins_with("--seconds="):
			_seconds = clampf(float(arg.trim_prefix("--seconds=")), 2.0, 20.0)
		elif arg.begins_with("--fps="):
			_fps = clampi(int(arg.trim_prefix("--fps=")), 5, 24)
		elif arg.begins_with("--boss-hp-ratio="):
			_boss_hp_ratio = clampf(float(arg.trim_prefix("--boss-hp-ratio=")), 0.05, 1.0)
		elif arg == "--ambient":
			_ambient = true
		elif arg == "--visible":
			_visible = true
		elif arg == "--capture-only-immortal":
			_immortal = true
	_release_inputs()
	if not _visible:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	_run.call_deferred()


func _requires_rendering() -> bool:
	return true


func _run() -> void:
	if _role not in ["tank", "mage"] or _dimensions.x not in [1280, 960]:
		_fail("Use --role=tank|mage and --width=1280|960.")
		get_tree().quit(1)
		return
	if _only_case not in ["", "rush", "slam", "shock", "fan", "mines", "melee", "boundary", "ambient", "adds"]:
		_fail("Unknown focused --case selection.")
		get_tree().quit(1)
		return
	if _requires_rendering() and DisplayServer.get_name() == "headless":
		_fail("Live image capture requires a rendering driver.")
		get_tree().quit(1)
		return
	_connect_events()
	await _execute()
	await _shutdown_world()
	_check(SaveManager.debug_save_writes == _save_writes_before and SaveManager.current_save == null and SaveManager.current_slot == -1, "isolated fixture made zero profile writes or slot selections")
	_release_inputs()
	print("S5TeachingFightPreview: passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _execute() -> void:
	if not await _setup_world(_role, _seed_value):
		return
	if not await _spawn_boss():
		return
	_player.global_position = _boss.global_position + Vector2(0, 220)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	if _ambient:
		_start_bounded_ambient()
	_make_caption()
	_reset_evidence()
	_control = "natural"
	_attack_enabled = true
	_activate_combat()
	_running = true
	var began := Time.get_ticks_usec()
	var next_capture := 0.0
	while _time < _seconds and not _player.get("is_dead"):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if get_tree().paused:
			_fail("An unexpected modal paused the live fight.")
			break
		if _time + 0.0001 < next_capture:
			continue
		var pixels := get_viewport().get_texture().get_image()
		pixels.convert(Image.FORMAT_RGB8)
		_pixels.append(pixels)
		_frame_info.append(_sample(float(Time.get_ticks_usec() - began) / 1_000_000.0))
		next_capture = _time + 1.0 / float(_fps)
	_running = false
	_release_inputs()
	var combat_wall_duration := float(Time.get_ticks_usec() - began) / 1_000_000.0
	get_tree().paused = true
	var absolute_out := ProjectSettings.globalize_path(_out)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_out.path_join("frames"))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Cannot create capture output: " + error_string(dir_error))
		return
	# PNG compression happens after combat. VFR encoding must use wall_time
	# from these samples, not accelerate output to the requested sample rate.
	for index in range(_pixels.size()):
		_save_image(_pixels[index], absolute_out.path_join("frames/frame-%04d.png" % index))
		if index % 20 == 0:
			await get_tree().process_frame
	if not _pixels.is_empty():
		_save_image(_pixels[0], absolute_out.path_join("opening.png"))
		_save_image(_pixels[_pixels.size() / 2], absolute_out.path_join("midfight.png"))
		_save_image(_pixels.back(), absolute_out.path_join("ending.png"))
	_check(_native_fires > 0, "live native attack input fired")
	_check(_boss_hits > 0, "live native melee reached the actual boss")
	if _ambient:
		_check(_native_kills > 0 and _cleaves() > _cleaves_before, "controlled normal-spawner targets supplied genuine player kills and on-kill Cleave activation")
	var info := _summary()
	info["presentation"] = "LIVE controlled S5 production Game/court, native player movement/aim/attack, actual AI/projectiles/physics; rough static boss art, final animation pending"
	info["capture_only_immortal"] = _immortal
	info["avoidability_claim"] = "none from immortal playback" if _immortal else "observed outcomes only; focused paired escape cases establish geometry"
	info["ambient_conditions"] = "controlled production spawner: initial forced batch up to6, normal table, bounded ambient cap8; not Mage reinforcement" if _ambient else "ambient disabled for isolated readability"
	info["ambient_initial_result"] = _ambient_result
	info["simulation_seconds"] = _time
	info["wall_seconds"] = combat_wall_duration
	info["target_capture_fps"] = _fps
	info["frames"] = _frame_info
	info["damage"] = _damage
	info["events"] = _events
	info["cleaves_delta"] = _cleaves() - _cleaves_before
	_write_json(absolute_out.path_join("capture-info.json"), info)
	print("S5TeachingFightPreview -> ", absolute_out)


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
	Global.debug_player_god_mode = _immortal
	Global.debug_encounter_beats = false
	Global.selected_race_id = "human"
	Global.selected_style_id = "melee"
	Global.selected_weapon_id = "melee"
	Global.start_new_attempt()
	Global.attempt_segment = 5
	Global.attempt_world_seed = seed_value
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	seed(seed_value)
	Global._rng.seed = seed_value
	if _ambient:
		Global.attempt_ascension = AscensionLedger.fresh_state("melee")
		var ledger := Global.ascension_ledger()
		ledger.record_purchase("EX01", 0)
		ledger.record_purchase("EX03", 200)
		ledger.record_purchase("EX06", 400)
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = _dimensions
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
	var planned: Vector2 = _plan.get("miniboss_world", Vector2.INF)
	if planned == Vector2.INF:
		_fail("S5 district has no miniboss court.")
		return false
	_origin = SPACE.anchor_world(planned, _chunks.chunk_size_px)
	_arena = null
	for child: Node in _game.find_children("*", "", true, false):
		if child is BossArena or child is MiniBossArena:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			var trigger := child.get_node_or_null("Trigger") as Area2D
			if trigger != null:
				trigger.monitoring = false
				trigger.monitorable = false
			if child is MiniBossArena and child.global_position.is_equal_approx(_origin):
				_arena = child as MiniBossArena
	if _arena == null:
		_fail("S5 court does not contain its actual MiniBossArena.")
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
	_check(settled, "actual S5 court finished streaming")
	_check(is_equal_approx(float(_player.call("get_effective_move_speed")), 100.0), "unmodified production human melee speed is100 world px/s")
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
	_arena.set("_enemy", null)
	_arena.set("_spawned", false)
	_arena.set("_cleared", false)
	_arena.set("_spawn_in_progress", false)
	_arena.set("_retry_not_before_ms", 0)
	_arena.tank_boss_scenes.clear()
	_arena.mage_boss_scenes.clear()
	if _role == "tank":
		_arena.tank_boss_scenes.append(TANK)
	else:
		_arena.mage_boss_scenes.append(MAGE)
	_arena.call("_spawn")
	_boss = _arena.get("_enemy") as EnemyActor
	if _boss == null:
		_fail("Actual S5 arena did not create its chosen archetype.")
		return false
	_boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	_boss.player = _player
	_brain = _boss.get_node("BossBrain")
	_boss.set_physics_process(false)
	_boss.set_process(false)
	_brain.set_process(false)
	_brain.set_physics_process(false)
	# Arrange a disclosed threshold condition after the arena has configured
	# production maximum health. Do not inject a damage or death event.
	if _boss_hp_ratio < 1.0:
		var handle := EnemyWorld.handle_for_actor(_boss)
		if not EnemyWorld.set_health(handle, _boss.max_hp * _boss_hp_ratio) or not _boss.configure_health(_boss.max_hp, false):
			_fail("Cannot arrange controlled starting boss HP in the actual EnemyWorld.")
			return false
	_boss_starting_health = _boss.hp
	_boss_max_health = _boss.max_hp
	if _boss_hp_ratio < 1.0:
		print("S5TeachingProbe: ", _boss_hp_conditions(), " / HP ", _boss_starting_health, "/", _boss_max_health)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_dismiss_tutorials()
	return true


func _activate_combat() -> void:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_boss.set_process(true)
	_boss.set_physics_process(true)
	_brain.set_process(true)
	_brain.set_physics_process(true)
	get_tree().paused = false


func _start_bounded_ambient() -> void:
	var spawner := _game.get_node("Spawner") as EnemySpawner
	if spawner.spawn_table != null:
		spawner.spawn_table = spawner.spawn_table.duplicate(true) as EnemySpawnTable
		spawner.spawn_table.max_alive_total = 8
	spawner.max_alive = 8
	spawner.batch_base = 1
	spawner.batch_cap = 1
	spawner.max_spawn_batch_per_tick = 1
	spawner.process_mode = Node.PROCESS_MODE_INHERIT
	spawner.set_spawning_enabled(true)
	_ambient_result = spawner.debug_force_spawn(6)
	_cleaves_before = _cleaves()


func _physics_process(delta: float) -> void:
	if not _running or not is_instance_valid(_player) or not is_instance_valid(_boss):
		return
	_time += delta
	_max_enemies = maxi(_max_enemies, EnemyWorld.active_count())
	var observed := String(_boss.get_meta(&"boss_teaching_state", &"idle"))
	_observe_boss_state(observed)
	var movement := Vector2.ZERO
	if _control == "natural":
		movement = _natural_movement()
	elif _time >= REACTION:
		if _control == "walk":
			movement = _escape_direction
		elif _control == "dash":
			movement = _escape_direction
			if not _dash_sent:
				Input.action_press(&"dash")
				_dash_pending = true
				_dash_sent = true
	_set_axis(&"move_left", &"move_right", movement.x)
	_set_axis(&"move_up", &"move_down", movement.y)
	var target := _attack_target()
	var aim := _player.global_position.direction_to(target)
	_set_axis(&"aim_left", &"aim_right", aim.x)
	_set_axis(&"aim_up", &"aim_down", aim.y)
	if _attack_enabled:
		Input.action_press(&"attack")
	else:
		Input.action_release(&"attack")
	# Keep a dash press through a render update until the production verb fires.
	if _dash_pending and bool(_player.call("is_dashing")):
		Input.action_release(&"dash")
		_dash_pending = false


func _observe_boss_state(observed: String) -> void:
	if observed == _state:
		return
	var continuing_rush := observed == "rush" and _state == "rush_tell"
	_state = observed
	if not continuing_rush:
		_state_began = _time
		_state_direction = _boss.global_position.direction_to(_player.global_position)
		# Read the production commitment rather than a later player bearing.
		if _state == "fan" and "_fan_dir" in _brain:
			_state_direction = (_brain.get("_fan_dir") as Vector2).normalized()
		elif _state in ["rush_tell", "rush", "shock"] and "_cast_dir" in _brain:
			_state_direction = (_brain.get("_cast_dir") as Vector2).normalized()
		if _state_direction.is_zero_approx():
			_state_direction = Vector2.RIGHT
		var perpendicular := _state_direction.orthogonal()
		# Choose the side once. Re-evaluating at the court center flips the
		# sign every tick and turns an intended escape into a stationary wobble.
		_state_sidestep = perpendicular if perpendicular.dot(_origin - _player.global_position) >= 0.0 else -perpendicular
	# Rush release keeps both the chosen side and the original reaction clock.
	_events.append({"time": _time, "event": "boss_state", "value": _state, "committed_direction": str(_state_direction), "sidestep_direction": str(_state_sidestep)})


func _natural_movement() -> Vector2:
	var offset := _player.global_position - _boss.global_position
	var away := offset.normalized()
	if _state in ["rush_tell", "rush", "fan", "shock"]:
		if _time - _state_began < REACTION:
			return Vector2.ZERO
		return _state_sidestep
	if _state == "slam":
		return away if _time - _state_began >= REACTION else Vector2.ZERO
	var owned_mines := false
	for node in _game.get_children():
		if node is BossMine and node.source == _boss and not node.is_queued_for_deletion():
			owned_mines = true
			break
	if _state == "mines" or owned_mines:
		if _state == "mines" and _time - _state_began < REACTION:
			return Vector2.ZERO
		# Follow the committed visible opening; do not chase back across the
		# ring when the caster's recovery starts before planted mines settle.
		if "_teaching_escape" in _brain:
			var committed_escape: Vector2 = _brain.get("_teaching_escape")
			if not committed_escape.is_zero_approx():
				return committed_escape.normalized()
		var escape := Vector2.ZERO
		for node in _game.get_children():
			if node is BossMine:
				var mine_offset: Vector2 = _player.global_position - node.global_position
				escape += mine_offset.normalized() / maxf(mine_offset.length(), 20.0)
		if not escape.is_zero_approx():
			return escape.normalized()
	var target := _attack_target()
	var delta := target - _player.global_position
	return delta.normalized() if delta.length() > _contact_distance(delta.normalized()) + 2.0 else Vector2.ZERO


func _attack_target() -> Vector2:
	var target := _boss.global_position
	if not _ambient:
		return target
	var closest := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var actor := node as EnemyActor
		if actor == null or actor == _boss or actor.dead or actor.is_in_group(&"boss_like"):
			continue
		var distance := _player.global_position.distance_squared_to(actor.global_position)
		if distance < closest:
			closest = distance
			target = actor.global_position
	return target


func _contact_distance(direction: Vector2 = Vector2.RIGHT) -> float:
	var player_shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var player_collider := _player.get_node("CollisionShape2D") as CollisionShape2D
	var boss_shape := (_boss.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	# Capsule support: central segment plus its round cap. This does not
	# replace hazard overlap queries, which retain the actual square Hurtbox.
	var capsule_axis := player_collider.global_transform.y.normalized()
	var player_support := player_shape.radius + maxf(0.0, player_shape.height * 0.5 - player_shape.radius) * absf(direction.normalized().dot(capsule_axis))
	return boss_shape.radius + player_support + 0.10


func _reset_evidence() -> void:
	_time = 0.0
	_state = ""
	_state_began = 0.0
	_state_direction = Vector2.RIGHT
	_state_sidestep = Vector2.ZERO
	_damage.clear()
	_events.clear()
	_frame_info.clear()
	_pixels.clear()
	_native_fires = 0
	_boss_hits = 0
	_recovery_hits = 0
	_native_kills = 0
	_dashes = 0
	_max_enemies = EnemyWorld.active_count()
	_dash_pending = false
	_dash_sent = false
	_starting_health = float(_player.get("hp"))


func _connect_events() -> void:
	RunEvents.player_damage_resolved.connect(_on_damage)
	RunEvents.player_hit_landed.connect(_on_hit)
	RunEvents.weapon_fired.connect(_on_fire)
	RunEvents.player_dashed.connect(_on_dash)
	RunEvents.enemy_defeated.connect(_on_death)


func _on_damage(player: Node, raw: float, adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if not _running or player != _player:
		return
	var boss_owned: bool = source == _boss or (source is EnemyProjectile and source.shooter == _boss)
	_damage.append({"time": _time, "raw": raw, "adjusted": adjusted, "applied": applied, "kind": String(kind), "outcome": String(outcome), "boss_owned": boss_owned, "boss_state": _state, "player_position": str(_player.global_position)})


func _on_hit(source: Node, handle: int, _at: Vector2, amount: float, _crit: bool, _elite: bool) -> void:
	if not _running or source != _player or not is_instance_valid(_boss):
		return
	if handle == EnemyWorld.handle_for_actor(_boss):
		_boss_hits += 1
		if String(_boss.get_meta(&"boss_teaching_state", &"")) == "recovery":
			_recovery_hits += 1
		_events.append({"time": _time, "event": "native_boss_hit", "amount": amount, "state": String(_boss.get_meta(&"boss_teaching_state", &""))})


func _on_fire(source: Node, style: StringName, _from: Vector2, _to: Vector2, _power: float, _haste: float) -> void:
	if _running and source == _player:
		_native_fires += 1
		_events.append({"time": _time, "event": "native_fire", "style": String(style)})


func _on_dash(player: Node, _from: Vector2, direction: Vector2) -> void:
	if _running and player == _player:
		_dashes += 1
		_events.append({"time": _time, "event": "native_dash", "direction": str(direction)})


func _on_death(context: RefCounted) -> void:
	if _running and context.get("source") == _player:
		_native_kills += 1
		var metadata: Dictionary = context.get("metadata")
		_events.append({"time": _time, "event": "native_kill", "enemy_id": String(context.get("spec_id")), "special_spawn_kind": String(metadata.get("special_spawn_kind", &""))})


func _sample(wall_time: float) -> Dictionary:
	return {"simulation_time": _time, "wall_time": wall_time, "player_world": str(_player.global_position), "player_hp": _player.get("hp"), "invulnerability_left": _player.get("invulnerable_time"), "dashing": _player.call("is_dashing"), "boss_world": str(_boss.global_position), "boss_hp": _boss.hp, "boss_state": String(_boss.get_meta(&"boss_teaching_state", &"idle")), "boss_returning": _boss.get_meta(&"boss_returning", false), "active_enemies": EnemyWorld.active_count(), "managed_projectiles": ProjectileManager.active_count(), "native_hits": _boss_hits, "recovery_hits": _recovery_hits, "native_kills": _native_kills}


func _summary() -> Dictionary:
	return {"scene": "res://scenes/game.tscn", "role": _role, "seed": _seed_value, "segment": 5, "viewport": str(VIEWPORT), "window": str(_dimensions), "camera_zoom": str(_camera.zoom), "player_speed": _player.call("get_effective_move_speed"), "player_body": "production CapsuleShape2D radius25 height58", "player_hurtbox": "production RectangleShape2D70x70", "reaction_seconds": REACTION, "native_fires": _native_fires, "native_boss_hits": _boss_hits, "recovery_hits": _recovery_hits, "native_kills": _native_kills, "native_dashes": _dashes, "max_active_enemies": _max_enemies, "initial_hp": _starting_health, "final_hp": _player.get("hp"), "boss_initial_hp": _boss_starting_health, "boss_max_hp": _boss_max_health, "boss_starting_hp_ratio_control": _boss_hp_ratio, "boss_starting_hp_conditions": _boss_hp_conditions(), "boss_hp": _boss.hp, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures}


func _boss_hp_conditions() -> String:
	return "CONTROLLED starting boss HP %.1f%% / production max HP retained / threshold condition only; no damage or kill injected" % (_boss_hp_ratio * 100.0) if _boss_hp_ratio < 1.0 else "production full starting boss HP"


func _cleaves() -> int:
	if not is_instance_valid(_player):
		return 0
	var runner := _player.get_node("AscensionRunner") as AscensionRunner
	var engine := runner.engine_for("EX01") as ExecutionEngine
	return int(engine.counters.get("cleaves", 0)) if engine != null else 0


func _make_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	_game.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(420, 880)
	caption.size = Vector2(1250, 135)
	caption.text = "LIVE CONTROLLED S5 %s / normal camera / native melee + movement\n" % _role.to_upper()
	caption.text += "CONTROLLED AMBIENT: production normal spawner, bounded population; not Mage adds" if _ambient else "ISOLATED BOSS / ambient disabled for readability"
	caption.text += "\nIMMORTAL CAPTURE ONLY / no avoidability claim" if _immortal else "\nReal damage enabled / rough static boss art; finished animation pending"
	if _boss_hp_ratio < 1.0:
		caption.text += "\nCONTROLLED STARTING BOSS HP %.1f%% / production max HP retained" % (_boss_hp_ratio * 100.0)
	caption.add_theme_font_size_override("font_size", 23)
	caption.add_theme_color_override("font_color", Color("eee9d8"))
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size", 4)
	layer.add_child(caption)


func _dismiss_tutorials() -> void:
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		for entry: Array in [[RunEvents.enemy_archetype_encountered, "_on_enemy_encountered"], [RunEvents.blocking_info_requested, "_on_blocking_info_requested"]]:
			var callback := Callable(tutorials, String(entry[1]))
			if entry[0].is_connected(callback):
				entry[0].disconnect(callback)
		tutorials.set("_queue", [])
	for child in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")
	var tip := _game.get_node_or_null("UI/HUD/TutorialTipController")
	if tip != null:
		for entry: Array in [[RunEvents.tutorial_tip, "_on_tutorial_tip"], [RunEvents.illustrated_tutorial_tip, "_on_illustrated_tutorial_tip"]]:
			var callback := Callable(tip, String(entry[1]))
			if entry[0].is_connected(callback):
				entry[0].disconnect(callback)
		tip.call("_abort_queue")
		tip.call("_hide_now")
	get_tree().paused = false


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value > 0.0:
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_press(negative, -value)


func _release_inputs() -> void:
	for action in INPUT_ACTIONS:
		Input.action_release(action)


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("S5TeachingProbe: " + message)


func _save_image(pixels: Image, path: String) -> void:
	if pixels.save_png(path) != OK:
		_fail("Cannot write capture: " + path)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write metadata: " + path)
	else:
		file.store_string(JSON.stringify(value, "\t"))
		file.close()


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _shutdown_world() -> void:
	_running = false
	_release_inputs()
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.queue_free()
		await _frames(2)
	_game = null
	_boss = null
	_brain = null
	_arena = null
	ProjectileManager.clear_for_run_end()


func _exit_tree() -> void:
	_release_inputs()
	Engine.time_scale = 1.0
