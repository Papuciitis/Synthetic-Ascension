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
@export_range(0, 128, 1) var ambient_pool_limit_per_scene: int = 32
# Pre-fill pools at segment start so the first spawn waves reuse instead of
# paying scene.instantiate() during gameplay.
@export_range(0, 32, 1) var pool_warm_per_scene: int = 6
# Warm-up instantiation budget per frame: pool construction spreads across
# the first second of a segment instead of stalling the scene-change frame
# (measured 436ms process spike warming 12 scenes x 6 instances inline).
const POOL_WARM_FRAME_BUDGET_USEC := 2500
# Hard bound on live elites: promotion chance saturates at high threat and an
# uncapped elite population defeats pooling and the full-simulation budget.
@export_range(0, 128, 1) var max_concurrent_elites: int = 24
# Cap on _spawn_one calls per tick; the overflow carries to later ticks so a
# saturated director cannot construct a whole batch in a single frame.
@export_range(1, 16, 1) var max_spawn_batch_per_tick: int = 4


@export_group("Boss Suppression (nearby boss/miniboss)")
@export var boss_suppress_radius: float = 1050.0
@export var boss_spawn_interval_mul: float = 3.25   # higher = fewer ambient spawns during boss fights
@export var boss_max_alive_mul: float = 0.35        # lower = fewer ambient enemies alive
@export var boss_batch_mul: float = 0.55            # lower = fewer spawns per tick

@export_group("Culling (prevent spawner dead)")
@export var cull_enabled: bool = true

# Don't start deleting ambient enemies merely because we're moderately full.
# 0.90 means a 220-enemy cap starts pressure culling at ~198 enemies.
@export_range(0.50, 1.00, 0.01) var cull_threshold_ratio: float = 0.90

@export var cull_interval: float = 0.75

# Never retire giant batches in one frame.
@export_range(1, 32, 1) var cull_max_per_tick: int = 8

# After a cull, don't immediately refill the slots we just freed.
@export_range(0.0, 3.0, 0.05) var cull_refill_grace: float = 0.90

@export_range(1, 8, 1) var cull_keep_chunks: int = 2
@export var cull_distance_px_fallback: float = 3600.0

@export_group("Stale Enemy Cleanup")
@export var stale_cleanup_interval: float = 0.80
@export var stale_min_distance_px: float = 1700.0
@export var stale_stationary_seconds: float = 9.0
@export var stale_motion_epsilon_px: float = 22.0
@export var stale_max_per_tick: int = 10

# Cache refs
var _player: Node2D = null
var _cm: ChunkManager = null
var _timer: Timer = null
var _elapsed: float = 0.0
var _ei: Node = null
var _spawn_filter: Node = null
# Authored per-segment bounds (the segment_spawn_filter group, e.g.
# Level1Builder). Kept separate from _spawn_filter: that one is the debug
# autoload and is never null, so sharing the variable meant the authored
# filter was never consulted and enemies could spawn outside the map.
var _authored_spawn_filter: Node = null
var _scene_enemy_ids: Dictionary = {}
# _spawn_one() runs on every spawn tick, so both "nothing to spawn" reports warn
# once per spawner instead of once per tick.
var _warned_no_spawn_source: bool = false
var _warned_no_active_entry: bool = false
var _segment1_stage: int = -1
var _spawn_pause_left: float = 0.0
var _authored_wave_running: bool = false
var _pending_spawn_total: int = 0
var _spawn_debt: int = 0
var _pending_spawn_by_scene: Dictionary = {}

# Wardstone cache (avoid scanning group every spawn attempt)
var _wardstones: Array = []
var _wardstone_refresh_t: float = 0.0
var _cull_cd: float = 0.0
var _cull_refill_left: float = 0.0
var _maintenance_cd: float = 0.0
var _stale_samples: Dictionary = {} # enemy id -> {pos: Vector2, still: float}
var _spawn_geometry_refresh_t: float = 0.0
var _spawn_sockets: Array = []
var _indoor_volumes: Array = []
var _cull_counts: Dictionary = {}

var _pool_warm_queue: Array[PackedScene] = []
# Forced spawns drain in per-frame batches: entering ~100 bodies into the
# broadphase in one physics step measured as a 240-300ms physics spike.
const FORCE_SPAWN_PER_FRAME := 12
var _force_spawn_queue: int = 0


func _ready() -> void:
	add_to_group("enemy_spawner")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_cm = get_tree().get_first_node_in_group("chunk_manager") as ChunkManager
	_ei = get_node_or_null("/root/EnemyIndex")
	_spawn_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
	_register_spawn_table_ids()
	_configure_enemy_pool_limits()
	if _spawn_filter != null and _spawn_filter.has_signal("filters_changed"):
		_spawn_filter.connect("filters_changed", _on_spawn_filters_changed)

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = true
	_timer.wait_time = spawn_every
	add_child(_timer)
	_timer.timeout.connect(_on_tick)

func _process(delta: float) -> void:
	_elapsed += delta
	_drain_pool_warm_queue()
	_drain_force_spawn_queue()
	_spawn_pause_left = maxf(_spawn_pause_left - delta, 0.0)
	_wardstone_refresh_t = maxf(_wardstone_refresh_t - delta, 0.0)
	_cull_cd = maxf(_cull_cd - delta, 0.0)
	_cull_refill_left = maxf(_cull_refill_left - delta, 0.0)
	_maintenance_cd = maxf(_maintenance_cd - delta, 0.0)
	_spawn_geometry_refresh_t = maxf(_spawn_geometry_refresh_t - delta, 0.0)
	if _ei == null or not is_instance_valid(_ei):
		_ei = get_node_or_null("/root/EnemyIndex")
	if cull_enabled and _maintenance_cd <= 0.0:
		_maintenance_cd = maxf(0.25, stale_cleanup_interval)
		_run_enemy_maintenance()

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
	var threshold := (
		ceili(float(cap_total) * cull_threshold_ratio)
		if cap_total > 0
		else 2147483647
	)
	if cap_total > 0 and alive >= threshold:
		var culled := _maybe_cull(
			cap_total,
			alive
		)
		# Critical:
		# Don't delete enemies and create replacements during the same tick.
		if culled > 0:
			return
		alive = _alive_total()
	# A recent distance/stale cleanup opened capacity deliberately.
	# Give the world some time before the director consumes it again.
	if _cull_refill_left > 0.0:
		return
	if (
		cap_total > 0
		and alive + _pending_spawn_total >= cap_total
	):
		return

	# batch scaling
	var batch: int = int(tutorial_cfg.get("batch", 0)) if tutorial_active else batch_base + int(floor(batch_per_min * minutes))
	batch = clampi(batch, 0 if tutorial_active else 1, batch_cap)
	if batch <= 0:
		return
	if boss_near:
		batch = maxi(1, int(round(float(batch) * boss_batch_mul)))

	# Enemy construction runs inline in this tick; budget it so a saturated
	# director cannot build a whole batch in one frame. Overflow carries.
	var budgeted: int = _take_spawn_budget(batch)
	for _i in range(budgeted):
		var remaining_total: int = _remaining_total_capacity(cap_total, alive)
		if remaining_total <= 0:
			return
		_spawn_one(minutes, remaining_total)

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

func debug_force_spawn(count: int) -> Dictionary:
	# Dev overlay: fill the population immediately, bypassing spawn pacing
	# (timer interval, batch budget, cull-refill grace) while still honoring
	# the effective alive cap, spawn filters, and per-type caps so forced
	# populations stay comparable to director-driven ones. The director keeps
	# the population pinned near the cap during a run, so the result carries
	# alive/cap for the overlay to explain a zero instead of just showing it.
	var immediate := _force_spawn_batch(mini(count, FORCE_SPAWN_PER_FRAME))
	var queued := 0
	if immediate > 0 and count > FORCE_SPAWN_PER_FRAME:
		queued = count - FORCE_SPAWN_PER_FRAME
		_force_spawn_queue += queued
	return {
		"spawned": immediate,
		"queued": queued,
		"alive": _alive_total(),
		"pending": _pending_spawn_total,
		"cap": _current_alive_cap(),
	}


func _force_spawn_batch(count: int) -> int:
	var minutes: float = _elapsed / 60.0
	var spawned_total := 0
	# Weighted rolls can land on an entry whose type cap is full and return 0;
	# retry a bounded number of times instead of treating that as exhaustion.
	var attempts := maxi(count * 4, count + 8)
	while spawned_total < count and attempts > 0:
		attempts -= 1
		var cap_total: int = _current_alive_cap()
		var remaining: int = _remaining_total_capacity(cap_total, _alive_total())
		if remaining <= 0:
			break
		spawned_total += _spawn_one(
			minutes,
			mini(remaining, count - spawned_total)
		)
	return spawned_total


func _drain_force_spawn_queue() -> void:
	if _force_spawn_queue <= 0:
		return
	var batch := mini(_force_spawn_queue, FORCE_SPAWN_PER_FRAME)
	if _force_spawn_batch(batch) <= 0:
		# Cap or filters block everything; retrying forever is pointless.
		_force_spawn_queue = 0
		return
	_force_spawn_queue -= batch


func _spawn_one(minutes: float, total_capacity: int = 2147483647) -> int:
	if total_capacity <= 0:
		return 0
	var entry: EnemySpawnEntry = null
	var tutorial_cfg: Dictionary = _tutorial_settings()
	if tutorial_cfg.is_empty() and spawn_table != null:
		entry = _pick_enabled_entry(_elapsed)

	var scene_to_spawn: PackedScene = null
	var count_min: int = 1
	var count_max: int = 1
	var per_type_cap: int = 0
	var entry_elite: float = 0.0
	if not tutorial_cfg.is_empty():
		var roster: Array = tutorial_cfg.get("roster", []) as Array
		if roster.is_empty():
			return 0
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
		_report_missing_spawn_scene()
		return 0

	var enemy_id := _enemy_id_for_scene(scene_to_spawn)
	if not _debug_enemy_enabled(enemy_id, false):
		return 0
	per_type_cap = _effective_type_cap(enemy_id, per_type_cap)

	var scene_path: String = scene_to_spawn.resource_path
	var pending_of_type: int = int(_pending_spawn_by_scene.get(scene_path, 0))

	# Per-type capacity includes deferred instances already reserved by prior ticks.
	if per_type_cap > 0:
		var alive_of_type: int = _alive_count_for_scene(scene_to_spawn)
		if alive_of_type + pending_of_type >= per_type_cap:
			return 0

	var amount: int = Global._rng.randi_range(count_min, count_max)
	amount = mini(amount, total_capacity)
	if per_type_cap > 0:
		amount = mini(amount, per_type_cap - _alive_count_for_scene(scene_to_spawn) - pending_of_type)
	if amount <= 0:
		return 0
	var spawned_count: int = 0

	for _j in range(amount):
		if per_type_cap > 0 and _alive_count_for_scene(scene_to_spawn) + int(_pending_spawn_by_scene.get(scene_path, 0)) >= per_type_cap:
			break
		if _spawn_instance(scene_to_spawn, minutes, entry_elite):
			spawned_count += 1

	return spawned_count

func _spawn_instance(scene_to_spawn: PackedScene, minutes: float, entry_elite: float, forced_pos: Vector2 = Vector2.INF, special_kind: StringName = &"") -> bool:
	return _spawn_instance_node(scene_to_spawn, minutes, entry_elite, forced_pos, special_kind) != null

func _spawn_instance_node(scene_to_spawn: PackedScene, minutes: float, entry_elite: float, forced_pos: Vector2 = Vector2.INF, special_kind: StringName = &"") -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	var use_pool := special_kind == &"" and PoolManager != null
	var e: Node = (
		PoolManager.obtain(scene_to_spawn, current_scene)
		if use_pool
		else scene_to_spawn.instantiate()
	)
	if e == null:
		return null
	var enemy_id := _enemy_id_from_node(e)
	var protected := _is_protected_spawn(e)
	if not _debug_enemy_enabled(enemy_id, protected):
		if use_pool and e.has_method("despawn"):
			e.call("despawn", &"spawn_filter")
		else:
			e.free()
		return null

	# position: ring around player + jitter (avoid blocked cells + wardstone fields)
	var pos: Vector2 = _pick_spawn_pos() if forced_pos == Vector2.INF else forced_pos
	if pos == Vector2.INF:
		if use_pool and e.has_method("despawn"):
			e.call("despawn", &"invalid_spawn_position")
		else:
			e.queue_free()
		return null

	var e2d: Node2D = e as Node2D
	if e2d != null:
		e2d.global_position = pos
	if use_pool and _ei != null and _ei.has_method("update_enemy"):
		_ei.call("update_enemy", e)
		# A reused record was re-adopted at its old death position before the
		# spawn position was assigned above; without a snapshot reset the
		# straddling previous-position renders one stale frame if the handle
		# demotes to data-only before its next position write.
		var world := get_node_or_null("/root/EnemyWorld")
		if world != null and world.has_method("handle_for_actor"):
			var handle := int(world.call("handle_for_actor", e))
			# INVALID_HANDLE is 0 in this build.
			if handle != 0 and world.has_method("reset_interpolation"):
				world.call("reset_interpolation", handle)
	if special_kind != &"":
		e.set_meta("special_spawn_kind", special_kind)

	var scene_path: String = scene_to_spawn.resource_path
	if use_pool:
		if _spawn_filter != null and _spawn_filter.has_method("validate_deferred_node"):
			_spawn_filter.call_deferred("validate_deferred_node", e)
	else:
		_reserve_pending_spawn(scene_path)
		e.tree_entered.connect(Callable(self, "_release_pending_spawn").bind(scene_path), CONNECT_ONE_SHOT)
		if _spawn_filter != null and _spawn_filter.has_method("validate_deferred_node"):
			e.tree_entered.connect(Callable(_spawn_filter, "validate_deferred_node").bind(e), CONNECT_ONE_SHOT)
		current_scene.call_deferred("add_child", e)

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
	if e is EnemyActor:
		var enemy_actor := e as EnemyActor
		if enemy_actor.spec != null:
			chance = minf(chance, clampf(enemy_actor.spec.elite_spawn_chance_cap, 0.0, 1.0))
	var roll: float = Global._rng.randf()

	if roll <= chance and e.has_method("make_elite") and not _elite_cap_reached():
		e.call_deferred("make_elite")
		if debug_spawns:
			print("[SPAWN] ELITE! chance=", snapped(chance, 0.001))

	if debug_spawns:
		print("[SPAWN]", str(e.name), " t=", int(_elapsed))
	if _spawn_filter != null and _spawn_filter.has_method("record_spawn"):
		_spawn_filter.call("record_spawn", enemy_id)

	return e


func _reserve_pending_spawn(scene_path: String) -> void:
	_pending_spawn_total += 1
	if scene_path != "":
		_pending_spawn_by_scene[scene_path] = int(_pending_spawn_by_scene.get(scene_path, 0)) + 1


func _release_pending_spawn(scene_path: String) -> void:
	_pending_spawn_total = maxi(0, _pending_spawn_total - 1)
	if scene_path == "" or not _pending_spawn_by_scene.has(scene_path):
		return
	var remaining: int = int(_pending_spawn_by_scene.get(scene_path, 0)) - 1
	if remaining <= 0:
		_pending_spawn_by_scene.erase(scene_path)
	else:
		_pending_spawn_by_scene[scene_path] = remaining

func _alive_total() -> int:
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("ambient_alive_count"):
		return int(_ei.call("ambient_alive_count"))
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("alive_count"):
		return int(_ei.call("alive_count"))
	return get_tree().get_nodes_in_group("enemies").size()

func _alive_count_for_scene(scene: PackedScene) -> int:
	if scene == null:
		return 0

	if _ei != null and is_instance_valid(_ei) and _ei.has_method("ambient_alive_count_for_scene"):
		return int(_ei.call("ambient_alive_count_for_scene", scene))
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
	_refresh_spawn_geometry_cache()
	if not _spawn_sockets.is_empty() and Global._rng.randf() < 0.78:
		var socket_pos := _pick_socket_spawn_pos()
		if socket_pos != Vector2.INF:
			return socket_pos

	var attempts: int = 10
	for _k in range(attempts):
		var dir: Vector2 = Vector2.RIGHT.rotated(Global._rng.randf() * TAU)
		var r: float = spawn_radius + Global._rng.randf_range(-spawn_jitter, spawn_jitter)
		var pos: Vector2 = _player.global_position + dir * r

		if _is_spawn_position_valid(pos):
			return pos

	return Vector2.INF

func _refresh_spawn_geometry_cache() -> void:
	if _spawn_geometry_refresh_t > 0.0:
		return
	_spawn_geometry_refresh_t = 0.75
	_spawn_sockets = get_tree().get_nodes_in_group(&"enemy_spawn_socket")
	_indoor_volumes = get_tree().get_nodes_in_group(&"indoor_volume")

func _pick_socket_spawn_pos() -> Vector2:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(_player) or _spawn_sockets.is_empty():
		return Vector2.INF
	var min_radius: float = maxf(260.0, spawn_radius - spawn_jitter * 2.0)
	var max_radius: float = spawn_radius + spawn_jitter * 2.5
	var min_dist2: float = min_radius * min_radius
	var max_dist2: float = max_radius * max_radius
	var start_index: int = Global._rng.randi_range(0, _spawn_sockets.size() - 1)
	for offset in range(_spawn_sockets.size()):
		var socket_variant: Variant = _spawn_sockets[(start_index + offset) % _spawn_sockets.size()]
		if not is_instance_valid(socket_variant):
			continue
		var socket := socket_variant as Node2D
		if socket == null or not socket.is_inside_tree():
			continue
		var distance2: float = socket.global_position.distance_squared_to(_player.global_position)
		if distance2 < min_dist2 or distance2 > max_dist2:
			continue
		var candidate: Vector2 = socket.global_position + Vector2.RIGHT.rotated(Global._rng.randf() * TAU) * Global._rng.randf_range(0.0, 28.0)
		if _is_spawn_position_valid(candidate):
			return candidate
	return Vector2.INF

func _is_spawn_position_valid(pos: Vector2) -> bool:
	# Handcrafted segments may provide authored playable bounds.
	if _authored_spawn_filter == null or not is_instance_valid(_authored_spawn_filter):
		_authored_spawn_filter = get_tree().get_first_node_in_group(&"segment_spawn_filter")
	if _authored_spawn_filter != null and _authored_spawn_filter.has_method("is_spawn_position_allowed"):
		if not bool(_authored_spawn_filter.call("is_spawn_position_allowed", pos)):
			return false
	if _is_in_wardstone_field(pos):
		return false
	if _cm != null and is_instance_valid(_cm):
		var cell := _cm.world_to_cell(pos)
		if not _cm.is_cell_walkable(cell):
			return false
	for volume_variant in _indoor_volumes:
		# Group snapshots can retain an object after it has been queue-freed. Validate
		# the Variant before casting it, because casting a freed object raises an error.
		if not is_instance_valid(volume_variant):
			continue
		var volume := volume_variant as Node
		if volume == null or not volume.is_inside_tree():
			continue
		if not bool(volume.get("ambient_spawn_excluded")):
			continue
		if volume.has_method("contains_world_point") and bool(volume.call("contains_world_point", pos)):
			return false
	return true

func spawn_local_encounter(area: Rect2, count: int, encounter_owner: Node = null) -> Array:
	var spawned: Array = []
	if count <= 0 or not spawning_enabled:
		return spawned
	var amount: int = clampi(count, 1, 12)
	for _index in range(amount):
		var entry: EnemySpawnEntry = null
		if spawn_table != null:
			entry = spawn_table.pick(_elapsed, Global._rng)
		var scene_to_spawn: PackedScene = entry.enemy_scene if entry != null else enemy_scene
		if scene_to_spawn == null:
			continue
		var pos := _pick_local_encounter_pos(area)
		if pos == Vector2.INF:
			continue
		var entry_elite: float = clampf(entry.elite_chance, 0.0, 1.0) if entry != null else 0.0
		var enemy := _spawn_instance_node(scene_to_spawn, _elapsed / 60.0, entry_elite, pos, &"interior")
		if enemy != null:
			enemy.set_meta("interior_owner_id", encounter_owner.get_instance_id() if encounter_owner != null else 0)
			enemy.set_meta("interior_active", true)
			spawned.append(enemy)
	return spawned

func _pick_local_encounter_pos(area: Rect2) -> Vector2:
	for _attempt in range(24):
		var pos := Vector2(
			Global._rng.randf_range(area.position.x, area.end.x),
			Global._rng.randf_range(area.position.y, area.end.y)
		)
		if _cm == null or not is_instance_valid(_cm):
			return pos
		var cell := _cm.world_to_cell(pos)
		if _cm.is_cell_walkable(cell):
			return _cm.cell_to_world_center(cell)
	return Vector2.INF

func _refresh_wardstones_cache() -> void:
	if _wardstone_refresh_t > 0.0:
		return
	_wardstone_refresh_t = 0.50
	_wardstones = get_tree().get_nodes_in_group("wardstones_active")

func _is_in_wardstone_field(pos: Vector2) -> bool:
	_refresh_wardstones_cache()

	for s in _wardstones:
		if not is_instance_valid(s):
			continue
		var n := s as Node
		if n == null:
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
	var threshold := (
		ceili(float(cap_total) * cull_threshold_ratio)
		if cap_total > 0
		else 2147483647
	)
	if cap_total > 0 and alive >= threshold:
		var culled := _maybe_cull(
			cap_total,
			alive
		)
		if culled > 0:
			return
		alive = _alive_total()
	if _cull_refill_left > 0.0:
		return
	if cap_total > 0 and alive >= cap_total:
		return

	var minutes: float = _elapsed / 60.0
	for _i in range(extra):
		var remaining_total: int = _remaining_total_capacity(cap_total, alive)
		if remaining_total <= 0:
			return
		_spawn_one(minutes, remaining_total)

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

## Encounter beats (EncounterDirector): spawn one member of an authored
## formation at an exact position. Beat members are specials - protected from
## culling and counted outside the ambient cap - so a formation stays a
## formation until the player answers it. `modifier_ids` names the elite a
## beat wants (plan §2.4 Hunter: fast + vampiric) instead of leaving it to the
## phase pick; a non-empty list implies elite.
func spawn_beat_member(
	scene_path: String,
	position: Vector2,
	elite: bool = false,
	modifier_ids: Array[StringName] = [],
) -> Node:
	if not spawning_enabled:
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("[Spawner] beat member scene missing: %s" % scene_path)
		return null
	if _ei != null and _ei.has_method("try_reserve_special"):
		if int(_ei.call("try_reserve_special", &"beat", 1)) <= 0:
			return null
	var node := _spawn_instance_node(scene, _elapsed / 60.0, 0.0, position, &"beat")
	if node == null:
		if _ei != null and _ei.has_method("release_special"):
			_ei.call("release_special", &"beat", 1)
		return null
	if _ei != null and _ei.has_method("commit_special"):
		_ei.call("commit_special", node, &"beat")
	if not modifier_ids.is_empty() and node.has_method("apply_elite_modifiers"):
		node.call_deferred("apply_elite_modifiers", modifier_ids)
	elif elite and node.has_method("make_elite"):
		node.call_deferred("make_elite")
	return node


func is_beat_position_valid(position: Vector2) -> bool:
	_refresh_spawn_geometry_cache()
	return _is_spawn_position_valid(position)


func is_tutorial_stage() -> bool:
	return _segment1_stage >= 0


func queue_authored_wave(count: int, spacing: float = 0.7, delay: float = 1.5) -> void:
	if _authored_wave_running or count <= 0:
		return
	_run_authored_wave(count, spacing, delay)

func _run_authored_wave(count: int, spacing: float, delay: float) -> void:
	_authored_wave_running = true
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		# A segment can end, or the scene change, while this wave is waiting.
		# Resuming would spawn into a spawner that has left the tree.
		if not is_inside_tree():
			_authored_wave_running = false
			return
	for _i in range(count):
		if not spawning_enabled:
			break
		var remaining_total: int = _remaining_total_capacity(_current_alive_cap(), _alive_total())
		if remaining_total > 0:
			_spawn_one(_elapsed / 60.0, remaining_total)
		if spacing > 0.0:
			await get_tree().create_timer(spacing, false).timeout
			if not is_inside_tree():
				_authored_wave_running = false
				return
	_authored_wave_running = false

func _tutorial_settings() -> Dictionary:
	if _segment1_stage < 0:
		return {}
	return Segment1SpawnProfile.settings(_segment1_stage)

func _current_alive_cap() -> int:
	var cfg := _tutorial_settings()
	if not cfg.is_empty():
		return _effective_total_cap(maxi(0, int(cfg.get("cap", 0))))
	if spawn_table != null and spawn_table.has_method("get_max_alive_total"):
		return _effective_total_cap(int(spawn_table.call("get_max_alive_total")))
	return _effective_total_cap(max_alive)


func _remaining_total_capacity(cap_total: int, alive: int) -> int:
	if cap_total <= 0:
		return 2147483647
	return cap_total - alive - _pending_spawn_total


func _effective_total_cap(production_cap: int) -> int:
	if _spawn_filter == null or not is_instance_valid(_spawn_filter):
		_spawn_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
	if _spawn_filter != null and _spawn_filter.has_method("effective_total_cap"):
		return int(_spawn_filter.call("effective_total_cap", production_cap))
	return production_cap


func _effective_type_cap(enemy_id: StringName, production_cap: int) -> int:
	if _spawn_filter != null and _spawn_filter.has_method("effective_type_cap"):
		return int(_spawn_filter.call("effective_type_cap", enemy_id, production_cap))
	return production_cap


func _debug_enemy_enabled(enemy_id: StringName, protected: bool) -> bool:
	if _spawn_filter == null or not is_instance_valid(_spawn_filter):
		_spawn_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
	if _spawn_filter != null and _spawn_filter.has_method("is_enemy_enabled"):
		return bool(_spawn_filter.call("is_enemy_enabled", enemy_id, protected))
	return true


func _enemy_id_from_node(enemy: Node) -> StringName:
	if enemy == null:
		return &""
	var spec_value: Variant = enemy.get("spec")
	if spec_value != null:
		return StringName(spec_value.get("id"))
	return StringName(enemy.get_meta("enemy_id", &""))


func _enemy_id_for_scene(scene: PackedScene) -> StringName:
	if scene == null:
		return &""
	var path := scene.resource_path
	if _scene_enemy_ids.has(path):
		return StringName(_scene_enemy_ids[path])
	var node := scene.instantiate()
	var enemy_id := _enemy_id_from_node(node)
	if node != null:
		node.free()
	if path != "":
		_scene_enemy_ids[path] = enemy_id
	if _spawn_filter != null and _spawn_filter.has_method("register_enemy_id"):
		_spawn_filter.call("register_enemy_id", enemy_id)
	return enemy_id


func _register_spawn_table_ids() -> void:
	if spawn_table == null:
		return
	for entry_variant: Variant in spawn_table.entries:
		var entry := entry_variant as EnemySpawnEntry
		if entry != null and entry.enemy_scene != null:
			_enemy_id_for_scene(entry.enemy_scene)


func _take_spawn_budget(requested: int) -> int:
	var total: int = maxi(0, requested) + _spawn_debt
	var allowed: int = mini(total, maxi(1, max_spawn_batch_per_tick))
	_spawn_debt = clampi(total - allowed, 0, maxi(1, batch_cap) * 2)
	return allowed


func _elite_cap_reached() -> bool:
	# Deferred promotions from the current tick may overshoot the cap by the
	# in-flight batch; that slack is bounded by max_spawn_batch_per_tick.
	if max_concurrent_elites <= 0:
		return false
	if _ei == null or not is_instance_valid(_ei):
		_ei = get_node_or_null("/root/EnemyIndex")
	if _ei == null or not _ei.has_method("elite_alive_count"):
		return false
	return int(_ei.call("elite_alive_count")) >= max_concurrent_elites


func _configure_enemy_pool_limits() -> void:
	if PoolManager == null or not PoolManager.has_method("set_limit_for_scene"):
		return
	var can_warm := PoolManager.has_method("warm_step") and pool_warm_per_scene > 0
	if enemy_scene != null:
		PoolManager.set_limit_for_scene(enemy_scene, ambient_pool_limit_per_scene)
		if can_warm:
			_pool_warm_queue.append(enemy_scene)
	if spawn_table == null:
		return
	for entry_variant: Variant in spawn_table.entries:
		var entry := entry_variant as EnemySpawnEntry
		if entry != null and entry.enemy_scene != null:
			PoolManager.set_limit_for_scene(entry.enemy_scene, ambient_pool_limit_per_scene)
			if can_warm:
				_pool_warm_queue.append(entry.enemy_scene)


func _drain_pool_warm_queue() -> void:
	if _pool_warm_queue.is_empty():
		return
	var scene := _pool_warm_queue[0]
	if scene == null:
		_pool_warm_queue.pop_front()
		return
	if not PoolManager.warm_step(scene, pool_warm_per_scene, POOL_WARM_FRAME_BUDGET_USEC):
		_pool_warm_queue.pop_front()


func has_no_spawn_source() -> bool:
	# True only when nothing in the configuration can EVER produce an enemy. A
	# populated table whose entries are simply not active yet (time windows) or
	# are switched off by the debug filter is a transient state, not a
	# misconfiguration, and must not disable the spawner for the rest of the run.
	if enemy_scene != null:
		return false
	if spawn_table == null:
		return true
	for entry_variant: Variant in spawn_table.entries:
		var entry := entry_variant as EnemySpawnEntry
		if entry != null and entry.enemy_scene != null:
			return false
	return true


func _report_missing_spawn_scene() -> void:
	var table_path: String = spawn_table.resource_path if spawn_table != null else "<unassigned>"
	if has_no_spawn_source():
		if not _warned_no_spawn_source:
			_warned_no_spawn_source = true
			push_error(
				"[Spawner] no enemy source: spawn_table=%s enemy_scene=<unassigned>; spawning disabled for this run"
				% table_path
			)
		spawning_enabled = false
		return
	if _warned_no_active_entry:
		return
	_warned_no_active_entry = true
	push_warning(
		"[Spawner] nothing to spawn: spawn_table=%s entries=%d none active at t=%.1fs and enemy_scene=<unassigned>"
		% [table_path, spawn_table.entries.size(), _elapsed]
	)


func _pick_enabled_entry(time_seconds: float) -> EnemySpawnEntry:
	if spawn_table == null:
		return null
	var candidates: Array[EnemySpawnEntry] = []
	var total_weight := 0.0
	for entry_variant: Variant in spawn_table.entries:
		var entry := entry_variant as EnemySpawnEntry
		if entry == null or not entry.is_active(time_seconds):
			continue
		if not _debug_enemy_enabled(_enemy_id_for_scene(entry.enemy_scene), false):
			continue
		candidates.append(entry)
		total_weight += entry.weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll := Global._rng.randf() * total_weight
	var accumulated := 0.0
	for entry in candidates:
		accumulated += entry.weight
		if roll <= accumulated:
			return entry
	return candidates[candidates.size() - 1]


func _is_protected_spawn(enemy: Node) -> bool:
	return (
		enemy.is_in_group(&"boss_like")
		or enemy.is_in_group(&"boss")
		or enemy.is_in_group(&"miniboss")
		or bool(enemy.get_meta("objective_required", false))
		or bool(enemy.get_meta("tutorial_actor", false))
	)


func _on_spawn_filters_changed(_disabled_ids: Array[StringName]) -> void:
	# Deferred instances may still enter after a filter change, but their one-shot
	# release callbacks are idempotent against these cleared counters.
	_pending_spawn_total = 0
	_pending_spawn_by_scene.clear()

# ------------------------------------------------------------
# Culling + stale cleanup
# ------------------------------------------------------------
func _run_enemy_maintenance() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	if _cm == null or not is_instance_valid(_cm):
		_cm = get_tree().get_first_node_in_group("chunk_manager") as ChunkManager
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("prune_invalid"):
		_ei.call("prune_invalid")

	# Distance retirement is handled exclusively by _maybe_cull().
	# Having another distance-cull pass here allowed maintenance + cap culling
	# to stack in the same frame.
	var stale_culled := _cull_stale_enemies(stale_max_per_tick)

	if stale_culled > 0:
		_cull_refill_left = maxf(
			_cull_refill_left,
			cull_refill_grace
		)

func _maybe_cull(cap_total: int, alive: int) -> int:
	if not cull_enabled:
		return 0
	if cap_total <= 0:
		return 0
	if _cull_cd > 0.0:
		return 0
	var threshold := ceili(
		float(cap_total) * cull_threshold_ratio
	)
	if alive < threshold:
		return 0
	_cull_cd = maxf(0.10, cull_interval)
	var culled := _cull_far_enemies(
		maxi(1, cull_max_per_tick)
	)
	if culled > 0:
		_cull_refill_left = maxf(
			_cull_refill_left,
			cull_refill_grace
		)
		if debug_spawns:
			print(
				"[SPAWN] Culled ",
				culled,
				" distant ambient enemies; refill paused for ",
				cull_refill_grace,
				"s."
			)
	return culled

func _enemy_list_for_cleanup() -> Array:
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("get_all"):
		return _ei.call("get_all") as Array
	return get_tree().get_nodes_in_group("enemies")

func is_enemy_cull_eligible(enemy: Node2D, player_position: Vector2) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if enemy.is_queued_for_deletion():
		return false
	if enemy.is_in_group(&"boss_like") or enemy.is_in_group(&"boss") or enemy.is_in_group(&"miniboss"):
		return false
	if bool(enemy.get_meta("objective_required", false)) or bool(enemy.get_meta("tutorial_actor", false)):
		return false
	if bool(enemy.get_meta("never_cull", false)):
		return false
	# A splitter family's qualified drop lives on exactly one heir; culling
	# that heir would silently destroy loot the player already earned.
	if bool(enemy.get_meta("split_item_entitled", false)):
		return false
	if "dead" in enemy and bool(enemy.get("dead")):
		return false
	var player_distance := enemy.global_position.distance_to(player_position)
	if enemy.has_method("is_retirement_protected") and bool(enemy.call("is_retirement_protected", player_distance)):
		return false
	var kind := enemy.get_meta("special_spawn_kind", &"") as StringName
	if kind == &"summon":
		return false
	if kind == &"interior" and bool(enemy.get_meta("interior_active", true)):
		return false
	if kind == &"boss_add" and bool(enemy.get_meta("encounter_active", true)):
		return false
	if enemy.has_meta("sniper_engagement_range"):
		if bool(enemy.get_meta("sniper_combat_committed", false)):
			return false
		if player_distance <= maxf(0.0, float(enemy.get_meta("sniper_engagement_range"))):
			return false
	return true


func _is_cull_eligible(enemy: Node2D) -> bool:
	var player_position := _player.global_position if _player != null and is_instance_valid(_player) else Vector2.ZERO
	return is_enemy_cull_eligible(enemy, player_position)

func _queue_cull_enemy(enemy: Node2D, reason: StringName) -> bool:
	if not _is_cull_eligible(enemy):
		return false
	var enemy_id: int = int(enemy.get_instance_id())
	_stale_samples.erase(enemy_id)
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("retire_enemy"):
		var retired := bool(_ei.call("retire_enemy", enemy, reason))
		if retired:
			_cull_counts[reason] = int(_cull_counts.get(reason, 0)) + 1
		return retired
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("unregister"):
		_ei.call("unregister", enemy)
	enemy.set_meta("culled", true)
	enemy.set_meta("cull_reason", reason)
	enemy.queue_free()
	_cull_counts[reason] = int(_cull_counts.get(reason, 0)) + 1
	return true


func get_cull_counters() -> Dictionary:
	return _cull_counts.duplicate()

func _cull_far_enemies(max_to_cull: int) -> int:
	if max_to_cull <= 0 or _player == null or not is_instance_valid(_player):
		return 0

	var list: Array = _enemy_list_for_cleanup()
	var keep_chunks: int = 0
	var keep_px2: float = cull_distance_px_fallback * cull_distance_px_fallback
	var chunk_sz: float = 2048.0
	if _cm != null and is_instance_valid(_cm):
		chunk_sz = maxf(1.0, float(_cm.chunk_size_px))
		keep_chunks = maxi(1, cull_keep_chunks)

	var player_pos: Vector2 = _player.global_position
	var player_chunk := Vector2i(floori(player_pos.x / chunk_sz), floori(player_pos.y / chunk_sz))
	var candidates: Array[Dictionary] = []
	for enemy_variant in list:
		var enemy := enemy_variant as Node2D
		if not is_enemy_cull_eligible(enemy, player_pos):
			continue

		if keep_chunks > 0:
			var enemy_chunk := Vector2i(floori(enemy.global_position.x / chunk_sz), floori(enemy.global_position.y / chunk_sz))
			var chunk_distance: int = maxi(abs(enemy_chunk.x - player_chunk.x), abs(enemy_chunk.y - player_chunk.y))
			if chunk_distance > keep_chunks:
				candidates.append({"enemy": enemy, "score": float(chunk_distance)})
		else:
			var distance_sq: float = enemy.global_position.distance_squared_to(player_pos)
			if distance_sq > keep_px2:
				candidates.append({"enemy": enemy, "score": distance_sq})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var culled: int = 0
	for candidate in candidates:
		if culled >= max_to_cull:
			break
		var enemy := candidate.get("enemy") as Node2D
		if _queue_cull_enemy(enemy, &"distance"):
			culled += 1
	return culled

func _cull_stale_enemies(max_to_cull: int) -> int:
	if max_to_cull <= 0 or _player == null or not is_instance_valid(_player):
		return 0

	var min_distance_sq: float = stale_min_distance_px * stale_min_distance_px
	var movement_sq: float = stale_motion_epsilon_px * stale_motion_epsilon_px
	var step_seconds: float = maxf(0.25, stale_cleanup_interval)
	var player_pos: Vector2 = _player.global_position
	var seen: Dictionary = {}
	var candidates: Array[Dictionary] = []

	for enemy_variant in _enemy_list_for_cleanup():
		var enemy := enemy_variant as Node2D
		if not is_enemy_cull_eligible(enemy, player_pos):
			continue
		var enemy_id: int = int(enemy.get_instance_id())
		seen[enemy_id] = true
		var current_pos: Vector2 = enemy.global_position
		var distance_sq: float = current_pos.distance_squared_to(player_pos)
		var sample: Dictionary = _stale_samples.get(enemy_id, {"pos": current_pos, "still": 0.0}) as Dictionary
		var previous_pos: Vector2 = sample.get("pos", current_pos) as Vector2
		var still_seconds: float = float(sample.get("still", 0.0))

		if distance_sq < min_distance_sq or current_pos.distance_squared_to(previous_pos) > movement_sq:
			still_seconds = 0.0
		else:
			still_seconds += step_seconds
		_stale_samples[enemy_id] = {"pos": current_pos, "still": still_seconds}

		# Elites can legitimately hold ranged positions; only distance culling handles them.
		var is_elite: bool = "is_elite" in enemy and bool(enemy.get("is_elite"))
		if not is_elite and still_seconds >= stale_stationary_seconds:
			candidates.append({"enemy": enemy, "score": distance_sq})

	for tracked_id in _stale_samples.keys():
		if not seen.has(tracked_id):
			_stale_samples.erase(tracked_id)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var culled: int = 0
	for candidate in candidates:
		if culled >= max_to_cull:
			break
		var enemy := candidate.get("enemy") as Node2D
		if _queue_cull_enemy(enemy, &"stale"):
			culled += 1
	if debug_spawns and culled > 0:
		print("[SPAWN] Cleaned ", culled, " stale ambient enemies.")
	return culled
