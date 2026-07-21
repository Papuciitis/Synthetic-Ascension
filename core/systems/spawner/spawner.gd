extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene # fallback if no table
@export var spawn_table: EnemySpawnTable

@export var spawn_every: float = 0.90
@export var spawn_every_min: float = 0.22
@export var spawn_every_decay_per_min: float = 0.04

@export var spawn_radius: float = 500.0
@export var spawn_jitter: float = 80.0

# Fallback cap if table has none
@export var max_alive: int = 220

@export var batch_base: int = 2
@export var batch_per_min: float = 0.45
@export var batch_cap: int = 8

# Global elite scaling (added ON TOP of entry.elite_chance)
@export var elite_min_time: float = 20.0
@export_range(0.0, 1.0, 0.001) var elite_base_chance: float = 0.00
@export_range(0.0, 1.0, 0.001) var elite_chance_per_min: float = 0.012
@export_range(0.0, 1.0, 0.001) var elite_chance_cap: float = 0.85

@export var debug_spawns: bool = false
@export var spawning_enabled: bool = true


@export_group("Boss Suppression (nearby boss/miniboss)")
@export var boss_suppress_radius: float = 1050.0
@export var boss_spawn_interval_mul: float = 3.25   # higher = fewer ambient spawns during boss fights
@export var boss_max_alive_mul: float = 0.35        # lower = fewer ambient enemies alive
@export var boss_batch_mul: float = 0.55            # lower = fewer spawns per tick

@export_group("Culling (prevent spawner dead)")
@export var cull_enabled: bool = true
@export_range(0.50, 1.00, 0.01) var cull_threshold_ratio: float = 1.00  # start culling when alive >= cap*ratio
@export var cull_interval: float = 1.25
@export var cull_max_per_tick: int = 24
@export var cull_chunk_buffer: int = 1   # keep enemies within (unload_radius + buffer) chunks around the player
@export var cull_distance_px_fallback: float = 5200.0  # used if no ChunkManager

# Cache refs
var _player: Node2D = null
var _cm: ChunkManager = null
var _timer: Timer = null
var _elapsed: float = 0.0
var _ei: Node = null
var _spawn_filter: Node = null
var _segment1_stage: int = -1
var _spawn_pause_left: float = 0.0
var _authored_wave_running: bool = false

# Wardstone cache (avoid scanning group every spawn attempt)
var _wardstones: Array = []
var _wardstone_refresh_t: float = 0.0
var _cull_cd: float = 0.0

func _ready() -> void:
	add_to_group("enemy_spawner")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_cm = get_tree().get_first_node_in_group("chunk_manager") as ChunkManager
	_ei = get_node_or_null("/root/EnemyIndex")

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = true
	_timer.wait_time = spawn_every
	add_child(_timer)
	_timer.timeout.connect(_on_tick)

func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_pause_left = maxf(_spawn_pause_left - delta, 0.0)
	_wardstone_refresh_t = maxf(_wardstone_refresh_t - delta, 0.0)
	_cull_cd = maxf(_cull_cd - delta, 0.0)
	if _ei == null or not is_instance_valid(_ei):
		_ei = get_node_or_null("/root/EnemyIndex")

func _on_tick() -> void:
	if _timer == null:
		return
	if not spawning_enabled:
		return
	if _spawn_pause_left > 0.0:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	if _cm == null or not is_instance_valid(_cm):
		_cm = get_tree().get_first_node_in_group("chunk_manager") as ChunkManager

	# Segment 1 uses milestone-driven settings. Elapsed time and Threat cannot
	# unlock or accelerate its early tutorial stages.
	var minutes: float = _elapsed / 60.0
	var tutorial_cfg: Dictionary = _tutorial_settings()
	var tutorial_active: bool = not tutorial_cfg.is_empty()
	var cur_every: float = float(tutorial_cfg.get("interval", spawn_every)) if tutorial_active else spawn_every - (spawn_every_decay_per_min * minutes)
	cur_every = maxf(cur_every, spawn_every_min)

	# Threat scaling (attempt-only director)
	var td: Node = get_node_or_null("/root/ThreatDirector")
	if td != null and (not tutorial_active or bool(tutorial_cfg.get("threat", false))):
		var mul: float = float(td.get("spawn_interval_mul"))
		if mul > 0.0:
			cur_every *= mul
		cur_every = maxf(cur_every, spawn_every_min * 0.35) # extra safety floor (lets OT crank harder)

	var boss_near: bool = _is_boss_near_player()
	if boss_near:
		cur_every *= boss_spawn_interval_mul

	_timer.wait_time = cur_every

	# cap alive enemies (table overrides if present)
	var cap_total: int = _current_alive_cap()

	if boss_near:
		cap_total = maxi(8, int(floor(float(cap_total) * boss_max_alive_mul)))

	var alive: int = _alive_total()
	var threshold: int = ceili(float(cap_total) * cull_threshold_ratio)
	if alive >= threshold:
		_maybe_cull(cap_total, alive)
		alive = _alive_total()
		if alive >= cap_total:
			return

	# batch scaling
	var batch: int = int(tutorial_cfg.get("batch", 0)) if tutorial_active else batch_base + int(floor(batch_per_min * minutes))
	batch = clampi(batch, 0 if tutorial_active else 1, batch_cap)
	if batch <= 0:
		return
	if boss_near:
		batch = maxi(1, int(round(float(batch) * boss_batch_mul)))

	# Avoid repeated alive scans inside the loop: track local spawns this tick.
	var spawned_this_tick: int = 0

	for _i in range(batch):
		if alive + spawned_this_tick >= cap_total:
			return
		if _spawn_one(minutes):
			spawned_this_tick += 1

func _is_boss_near_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false

	var bosses := get_tree().get_nodes_in_group("boss_like")
	if bosses.is_empty():
		return false

	var p: Vector2 = (_player as Node2D).global_position
	var r2: float = boss_suppress_radius * boss_suppress_radius

	for n in bosses:
		var b := n as Node2D
		if b == null or not is_instance_valid(b) or not b.is_inside_tree():
			continue

		# Optional: if your boss nodes set this meta when dead, respect it.
		if b.has_meta("dead") and bool(b.get_meta("dead")):
			continue

		if b.global_position.distance_squared_to(p) <= r2:
			return true

	return false

func _spawn_one(minutes: float) -> bool:
	var entry: EnemySpawnEntry = null
	var tutorial_cfg: Dictionary = _tutorial_settings()
	if tutorial_cfg.is_empty() and spawn_table != null:
		entry = spawn_table.pick(_elapsed, Global._rng)

	var scene_to_spawn: PackedScene = null
	var count_min: int = 1
	var count_max: int = 1
	var per_type_cap: int = 0
	var entry_elite: float = 0.0
	if not tutorial_cfg.is_empty():
		var roster: Array = tutorial_cfg.get("roster", []) as Array
		if roster.is_empty():
			return false
		scene_to_spawn = roster[Global._rng.randi_range(0, roster.size() - 1)] as PackedScene

	if entry != null and scene_to_spawn == null:
		scene_to_spawn = entry.enemy_scene
		count_min = maxi(1, entry.count_min)
		count_max = maxi(1, entry.count_max)
		per_type_cap = maxi(0, entry.max_alive)
		entry_elite = clampf(entry.elite_chance, 0.0, 1.0)

	if scene_to_spawn == null:
		scene_to_spawn = enemy_scene

	if scene_to_spawn == null:
		push_warning("[Spawner] No enemy scene assigned (spawn_table empty + enemy_scene null).")
		return false

	# per-type cap
	if per_type_cap > 0:
		var alive_of_type: int = _alive_count_for_scene(scene_to_spawn)
		if alive_of_type >= per_type_cap:
			return false

	var amount: int = Global._rng.randi_range(count_min, count_max)
	var spawned_any: bool = false

	for _j in range(amount):
		if per_type_cap > 0 and _alive_count_for_scene(scene_to_spawn) >= per_type_cap:
			break
		if _spawn_instance(scene_to_spawn, minutes, entry_elite):
			spawned_any = true

	return spawned_any

func _spawn_instance(scene_to_spawn: PackedScene, minutes: float, entry_elite: float) -> bool:
	var e: Node = scene_to_spawn.instantiate()
	if e == null:
		return false

	# position: ring around player + jitter (avoid blocked cells + wardstone fields)
	var pos: Vector2 = _pick_spawn_pos()
	if pos == Vector2.INF:
		e.queue_free()
		return false

	var e2d: Node2D = e as Node2D
	if e2d != null:
		e2d.global_position = pos

	get_tree().current_scene.call_deferred("add_child", e)

	# elite roll: entry chance + global scaling bonus
	var cfg: Dictionary = _tutorial_settings()
	var allow_scaling: bool = cfg.is_empty() or bool(cfg.get("threat", false))
	var global_bonus: float = 0.0
	if allow_scaling and _elapsed >= elite_min_time:
		global_bonus = elite_base_chance + (minutes * elite_chance_per_min)

	# Threat bonus on top of global elite scaling
	var td2 := get_node_or_null("/root/ThreatDirector") as ThreatDirectorSingleton
	if allow_scaling and td2 != null:
		global_bonus += td2.elite_bonus

	var chance: float = clampf(entry_elite + global_bonus, 0.0, elite_chance_cap)
	var roll: float = Global._rng.randf()

	if roll <= chance and e.has_method("make_elite"):
		e.call_deferred("make_elite")
		if debug_spawns:
			print("[SPAWN] ELITE! chance=", snapped(chance, 0.001))

	if debug_spawns:
		print("[SPAWN]", str(e.name), " t=", int(_elapsed))

	return true

func _alive_total() -> int:
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("alive_count"):
		return int(_ei.call("alive_count"))
	return get_tree().get_nodes_in_group("enemies").size()

func _alive_count_for_scene(scene: PackedScene) -> int:
	if scene == null:
		return 0

	if _ei != null and is_instance_valid(_ei) and _ei.has_method("alive_count_for_scene"):
		return int(_ei.call("alive_count_for_scene", scene))

	# fallback
	var path: String = scene.resource_path
	if path == "":
		return 0
	var c: int = 0
	var nodes: Array = get_tree().get_nodes_in_group("enemies")
	for n in nodes:
		var node: Node = n as Node
		if node != null and node.scene_file_path == path:
			c += 1
	return c

func _pick_spawn_pos() -> Vector2:
	if _player == null:
		return Vector2.INF

	var attempts: int = 10
	for _k in range(attempts):
		var dir: Vector2 = Vector2.RIGHT.rotated(Global._rng.randf() * TAU)
		var r: float = spawn_radius + Global._rng.randf_range(-spawn_jitter, spawn_jitter)
		var pos: Vector2 = _player.global_position + dir * r

		# Handcrafted segments may provide authored playable bounds. This prevents
		# ambient enemies appearing outside the institution or behind sealed geometry.
		if _spawn_filter == null or not is_instance_valid(_spawn_filter):
			_spawn_filter = get_tree().get_first_node_in_group(&"segment_spawn_filter")
		if _spawn_filter != null and _spawn_filter.has_method("is_spawn_position_allowed"):
			if not bool(_spawn_filter.call("is_spawn_position_allowed", pos)):
				continue

		# Avoid wardstone stability fields
		if _is_in_wardstone_field(pos):
			continue

		# Avoid blocked cells if chunk manager exists
		if _cm != null and is_instance_valid(_cm):
			var cell := _cm.world_to_cell(pos)
			if not _cm.is_cell_walkable(cell):
				continue

		return pos

	return Vector2.INF

func _refresh_wardstones_cache() -> void:
	if _wardstone_refresh_t > 0.0:
		return
	_wardstone_refresh_t = 0.50
	_wardstones = get_tree().get_nodes_in_group("wardstones_active")

func _is_in_wardstone_field(pos: Vector2) -> bool:
	_refresh_wardstones_cache()

	for s in _wardstones:
		var n := s as Node
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("get_stability_radius"):
			var r: float = float(n.call("get_stability_radius"))
			var n2 := n as Node2D
			if n2 == null:
				continue
			var d2 := (pos - n2.global_position).length_squared()
			if d2 <= r * r:
				return true
	return false

# Called by ExitRite to spike pressure near the end of a hold.
func spawn_burst(extra: int) -> void:
	if extra <= 0:
		return
	if not spawning_enabled:
		return
	if _player == null or not is_instance_valid(_player):
		return

	# cap alive enemies (table overrides if present)
	var cap_total: int = _current_alive_cap()

	var alive: int = _alive_total()
	var threshold: int = ceili(float(cap_total) * cull_threshold_ratio)
	if alive >= threshold:
		_maybe_cull(cap_total, alive)
		alive = _alive_total()
		if alive >= cap_total:
			return

	var minutes: float = _elapsed / 60.0
	var spawned: int = 0
	for _i in range(extra):
		if alive + spawned >= cap_total:
			return
		if _spawn_one(minutes):
			spawned += 1

func set_spawning_enabled(value: bool) -> void:
	spawning_enabled = value
	reset_spawn_clock()

func set_segment1_stage(stage: int, grace_override: float = -1.0) -> void:
	_segment1_stage = clampi(stage, Segment1SpawnProfile.Stage.BEFORE_SYNTHESIS, Segment1SpawnProfile.Stage.EXIT_RITE)
	var cfg := Segment1SpawnProfile.settings(_segment1_stage)
	spawning_enabled = int(cfg.get("cap", 0)) > 0
	_spawn_pause_left = float(cfg.get("grace", 0.0)) if grace_override < 0.0 else maxf(0.0, grace_override)
	reset_spawn_clock()

func reset_spawn_clock() -> void:
	if _timer == null:
		return
	var cfg := _tutorial_settings()
	_timer.wait_time = maxf(0.05, float(cfg.get("interval", spawn_every)))
	_timer.stop()
	_timer.start()

func suspend_spawning(seconds: float) -> void:
	_spawn_pause_left = maxf(_spawn_pause_left, maxf(0.0, seconds))
	reset_spawn_clock()

func queue_authored_wave(count: int, spacing: float = 0.7, delay: float = 1.5) -> void:
	if _authored_wave_running or count <= 0:
		return
	_run_authored_wave(count, spacing, delay)

func _run_authored_wave(count: int, spacing: float, delay: float) -> void:
	_authored_wave_running = true
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	for _i in range(count):
		if not spawning_enabled:
			break
		if _alive_total() < _current_alive_cap():
			_spawn_one(_elapsed / 60.0)
		if spacing > 0.0:
			await get_tree().create_timer(spacing, false).timeout
	_authored_wave_running = false

func _tutorial_settings() -> Dictionary:
	if _segment1_stage < 0:
		return {}
	return Segment1SpawnProfile.settings(_segment1_stage)

func _current_alive_cap() -> int:
	var cfg := _tutorial_settings()
	if not cfg.is_empty():
		return maxi(0, int(cfg.get("cap", 0)))
	if spawn_table != null and spawn_table.has_method("get_max_alive_total"):
		return int(spawn_table.call("get_max_alive_total"))
	return max_alive

# ------------------------------------------------------------
# Culling (prevents "spawner dead" when the player outruns the horde)
# ------------------------------------------------------------
func _maybe_cull(cap_total: int, alive: int) -> void:
	if not cull_enabled:
		return
	if _cull_cd > 0.0:
		return
	# Only bother when near/at cap (or above threshold ratio).
	var threshold: int = ceili(float(cap_total) * cull_threshold_ratio)
	if alive < threshold:
		return
	_cull_cd = maxf(0.10, cull_interval)
	var culled: int = _cull_far_enemies(cull_max_per_tick)
	if debug_spawns and culled > 0:
		print("[SPAWN] Culled ", culled, " far enemies to free cap.")

func _cull_far_enemies(max_to_cull: int) -> int:
	if max_to_cull <= 0:
		return 0
	if _player == null or not is_instance_valid(_player):
		return 0

	# Get enemy list (prefer EnemyIndex for speed).
	var list: Array = []
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("get_all"):
		list = _ei.call("get_all")
	else:
		list = get_tree().get_nodes_in_group("enemies")

	# Determine keep radius.
	var keep_chunks: int = 0
	var keep_px2: float = cull_distance_px_fallback * cull_distance_px_fallback
	var chunk_sz: float = 2048.0
	if _cm != null and is_instance_valid(_cm):
		chunk_sz = float(_cm.chunk_size_px)
		keep_chunks = int(_cm.unload_radius) + maxi(0, cull_chunk_buffer)

	var ppos: Vector2 = _player.global_position
	var pchunk: Vector2i = Vector2i(floori(ppos.x / chunk_sz), floori(ppos.y / chunk_sz))

	# Build candidate list (furthest first).
	var candidates: Array = []  # Array[Dictionary]{n:Node2D, score:int/float}
	for n in list:
		var e := n as Node2D
		if e == null or not is_instance_valid(e) or not e.is_inside_tree():
			continue
		# Never cull bosses/minibosses/objective enemies.
		if e.is_in_group(&"boss_like") or e.is_in_group(&"boss") or e.is_in_group(&"miniboss"):
			continue
		if e.has_meta("never_cull") and bool(e.get_meta("never_cull")):
			continue
		if "dead" in e and bool(e.get("dead")):
			continue

		if keep_chunks > 0:
			var ec: Vector2i = Vector2i(floori(e.global_position.x / chunk_sz), floori(e.global_position.y / chunk_sz))
			var d: int = maxi(abs(ec.x - pchunk.x), abs(ec.y - pchunk.y))
			if d > keep_chunks:
				candidates.append({"e": e, "s": d})
		else:
			var d2: float = e.global_position.distance_squared_to(ppos)
			if d2 > keep_px2:
				candidates.append({"e": e, "s": d2})

	if candidates.is_empty():
		return 0

	# Sort furthest first.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["s"]) > float(b["s"])
	)

	var culled: int = 0
	var limit: int = mini(max_to_cull, candidates.size())
	for i in range(limit):
		var e := candidates[i]["e"] as Node2D
		if e == null or not is_instance_valid(e):
			continue
		# Remove from index immediately so cap frees up this tick.
		if _ei != null and is_instance_valid(_ei) and _ei.has_method("unregister"):
			_ei.call("unregister", e)
		e.set_meta("culled", true)
		e.queue_free()
		culled += 1

	return culled
