extends Node

## The release beat after a completed Exit Rite (2026-10-04 design audit §2).
##
## The vision asks for an escape that looks "completely broken and
## overpowered"; until now the loading scrim covered the rite's climax pulse
## within about three frames, and the segment ended mid-crowd. Research
## references: Risk of Rain 2's Void Fields kill every enemy when a cell
## completes, Vampire Survivors clears the screen at 30:00, Left 4 Dead
## relaxes after every peak - the release is the point (and it hands the next
## scene a clean entity count).
##
## What happens, in real time so a slowed clock cannot stretch it:
##   - the player is untouchable for the whole beat;
##   - ambient spawning and the encounter director stop;
##   - ordinary enemies near the player dissolve nearest-first, a few dozen a
##     frame, with a death puff for some of them (retired, not killed: no
##     rewards, no on-kill procs, so the payoff cannot spike a frame or farm);
##     elites, bosses and everything the spawner refuses to cull stay;
##   - a brief slow-motion breath, an ESCAPED callout, then `finished`.

signal finished

const RADIUS_PX := 1230.0
const RETIRE_PER_FRAME := 40
const PUFFS_PER_FRAME := 10
const DURATION_SEC := 2.4
const SLOW_SCALE := 0.4
const SLOW_SEC := 0.35
const RETIRE_REASON := &"escape_release"

var _queue: Array[Dictionary] = []
var _started_ms := 0
var _slowed := false
var _running := false
var _cleared := 0


## Runs the beat around `player`; await `finished` (or this coroutine).
func play(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_ms = Time.get_ticks_msec()
	if player.has_method("grant_invulnerability"):
		player.call("grant_invulnerability", DURATION_SEC + 1.0)
	_halt_pressure()
	_queue = collect_targets(player.global_position, RADIUS_PX)
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(player.global_position + Vector2(0.0, -96.0), "ESCAPED", Color(1.0, 0.82, 0.45, 1.0), 1.6)
	if is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = SLOW_SCALE
		_slowed = true
	_running = true
	await finished


func _process(_delta: float) -> void:
	if not _running:
		return
	var elapsed := float(Time.get_ticks_msec() - _started_ms) / 1000.0
	if _slowed and elapsed >= SLOW_SEC:
		_restore_time()
	_retire_some()
	if elapsed >= DURATION_SEC:
		_running = false
		_restore_time()
		finished.emit()


func _exit_tree() -> void:
	# Freed mid-beat (the scene changed): never leave the clock slowed.
	_restore_time()


func cleared_count() -> int:
	return _cleared


func _restore_time() -> void:
	if _slowed and is_equal_approx(Engine.time_scale, SLOW_SCALE):
		Engine.time_scale = 1.0
	_slowed = false


func _halt_pressure() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var spawner := tree.get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("set_spawning_enabled"):
		spawner.call("set_spawning_enabled", false)
	var director := tree.get_first_node_in_group(&"encounter_director")
	if director != null and "enabled" in director:
		director.set("enabled", false)


## Ordinary enemies within `radius` of `origin`, nearest first: materialized
## actors (formation members and summons included - the escape outranks the
## culling protection that keeps a formation whole) and data-only proxies,
## never elites, bosses, objective or tutorial actors, loot-entitled
## splitter heirs, or the members of a live interior/boss encounter.
func collect_targets(origin: Vector2, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r2 := radius * radius
	var index := get_node_or_null("/root/EnemyIndex")
	var world := get_node_or_null("/root/EnemyWorld")
	if index != null and index.has_method("get_all"):
		for value in (index.call("get_all") as Array):
			var enemy := value as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var d2 := origin.distance_squared_to(enemy.global_position)
			if d2 > r2 or not _releasable(enemy) or _is_elite_actor(enemy, world):
				continue
			out.append({"node": enemy, "pos": enemy.global_position, "d2": d2})
	if index != null and index.has_method("detached_handles") and world != null:
		for value in (index.call("detached_handles") as Array):
			var handle := int(value)
			if not bool(world.call("is_valid_handle", handle)):
				continue
			var flags := int(world.call("get_flags", handle))
			if EnemyWorldTypes.has_flag(flags, EnemyWorldTypes.Flags.ELITE):
				continue
			var pos: Vector2 = world.call("get_position", handle)
			var d2 := origin.distance_squared_to(pos)
			if d2 > r2:
				continue
			out.append({"handle": handle, "pos": pos, "d2": d2})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d2"]) < float(b["d2"]))
	return out


const _PROTECTED_META: Array[StringName] = [&"objective_required", &"tutorial_actor", &"never_cull", &"split_item_entitled"]


func _releasable(enemy: Node2D) -> bool:
	if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return false
	if enemy.is_in_group(&"boss_like") or enemy.is_in_group(&"boss") or enemy.is_in_group(&"miniboss"):
		return false
	for key in _PROTECTED_META:
		if bool(enemy.get_meta(key, false)):
			return false
	var kind := enemy.get_meta(&"special_spawn_kind", &"") as StringName
	if kind == &"interior" and bool(enemy.get_meta(&"interior_active", true)):
		return false
	if kind == &"boss_add" and bool(enemy.get_meta(&"encounter_active", true)):
		return false
	return not ("dead" in enemy and bool(enemy.get("dead")))


func _is_elite_actor(enemy: Node2D, world: Node) -> bool:
	if world != null and world.has_method("handle_for_actor"):
		var handle := int(world.call("handle_for_actor", enemy))
		if handle != 0:
			return EnemyWorldTypes.has_flag(int(world.call("get_flags", handle)), EnemyWorldTypes.Flags.ELITE)
	return "is_elite" in enemy and bool(enemy.get("is_elite"))


func _retire_some() -> void:
	if _queue.is_empty():
		return
	var index := get_node_or_null("/root/EnemyIndex")
	if index == null:
		_queue.clear()
		return
	var puffs := 0
	var budget := mini(RETIRE_PER_FRAME, _queue.size())
	for _i in range(budget):
		var target: Dictionary = _queue.pop_front()
		var retired := false
		if target.has("node"):
			var enemy := target["node"] as Node
			if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				retired = bool(index.call("retire_enemy", enemy, RETIRE_REASON))
		elif target.has("handle"):
			retired = bool(index.call("release_detached", int(target["handle"]), RETIRE_REASON))
		if not retired:
			continue
		_cleared += 1
		if puffs < PUFFS_PER_FRAME:
			puffs += 1
			VfxBursts.play(&"death", target["pos"] as Vector2, 1.0)
