extends Node

# Ranged V5 Precision (handoff 2026-09-25): the selective ranks change Read
# thresholds, pierce counts, Aim time, returns, splits and spares; Far Shot's
# ranked bonus stays on its own Weak Points; Smart Rounds costs -15%; and the
# Firing Squad boss fallback needs three physical hits worth 12D on one
# durable target from one root.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionPrecisionV5Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: PrecisionEngineV5


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2, elite: bool = false) -> int:
	var flags := EnemyWorldTypes.Flags.ELITE if elite else 0
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_pr_v5", "res://asc_pr_v5.tscn", at, hp, 10.0, 8.0, 0, flags))


func _bullet_tags(cast: String, pid: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:" + cast)
	return tags


## A STATIONARY target for the real-projectile routes: the shared helper's
## walk speed lets a target sidestep a later shot on unlucky frame timing.
func _spawn_still(hp: float, at: Vector2, elite: bool = false) -> int:
	var flags := EnemyWorldTypes.Flags.ELITE if elite else 0
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_pr_v5", "res://asc_pr_v5.tscn", at, hp, 0.0, 8.0, 0, flags))


## Physics frames until `done` answers true (without one: until the
## projectile field is empty), then one more so same-frame hit ledgers and
## end-of-flight reports have flushed. Projectiles advance on the physics
## clock, so render-frame pacing in headless runs would outrun flight time.
func _settle(done: Callable = Callable(), cap: int = 300) -> void:
	for _frame in range(cap):
		await get_tree().physics_frame
		if done.is_valid():
			if done.call():
				break
		elif ProjectileManager.active_count() == 0:
			break
	await get_tree().physics_frame


## Live player projectiles whose tags name `root`, as {id, position,
## velocity, damage, tags}: the physical field, not an engine counter.
func _projectiles_rooted(root: String) -> Array:
	var all: Array = []
	ProjectileManager.player_projectiles_in_radius(_player.global_position, 1.0e6, all)
	var out: Array = []
	for entry in all:
		if AscensionTags.value_of(entry["tags"], "root") == root:
			out.append(entry)
	return out


## Removes the targets and every projectile, then yields so the runner's
## status sweep and the engine's per-handle bookkeeping see them gone.
func _clear_field(handles: Array) -> void:
	for handle in handles:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	ProjectileManager.clear_for_run_end()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("PR01", 0)
	for id in ["PR02", "PR03", "PR05", "PR06", "PR07", "PR09", "PR11", "PR12", "PRC"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("PR01") as PrecisionEngineV5
	_check(_engine != null, "a V5 run loads PrecisionEngineV5")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()

	# --- Rank getters follow the authored tables.
	_check(is_equal_approx(_engine._read_threshold(), 3.0), "PR01 rank 1 exposes at 3.0")
	(ledger.state["owned"] as Dictionary)["PR01"] = 3
	_check(is_equal_approx(_engine._read_threshold(), 2.0), "PR01 rank 3 exposes at 2.0")
	_check(_engine._pierce_bonus() == 2, "PR03 rank 1 pierces 2 extra")
	(ledger.state["owned"] as Dictionary)["PR03"] = 4
	_check(_engine._pierce_bonus() == 5, "PR03 rank 4 pierces 5 extra")
	_check(is_equal_approx(_engine._aim_seconds(), 0.8), "PR05 rank 1 aims in 0.80 s")
	(ledger.state["owned"] as Dictionary)["PR05"] = 3
	_check(is_equal_approx(_engine._aim_seconds(), 0.5), "PR05 rank 3 aims in 0.50 s")
	_check(_engine._terrain_bounces() == 1, "PR06 rank 1 bounces once")
	(ledger.state["owned"] as Dictionary)["PR06"] = 2
	_check(_engine._terrain_bounces() == 2, "PR06 rank 2 bounces twice")
	_check(is_equal_approx(_engine._return_fraction(), 0.6), "PR07 rank 1 returns at 60%")
	(ledger.state["owned"] as Dictionary)["PR07"] = 3
	_check(is_equal_approx(_engine._return_fraction(), 0.9), "PR07 rank 3 returns at 90%")
	_check(_engine._split_angles().size() == 2, "PR09 rank 1 splits into 2")
	(ledger.state["owned"] as Dictionary)["PR09"] = 3
	_check(_engine._split_angles() == [-30.0, -10.0, 10.0, 30.0], "PR09 rank 3 splits into 4 at the authored angles")
	_check(is_equal_approx(_engine._crossing_window(), 0.5), "PR11 rank 1 window 0.50 s")
	(ledger.state["owned"] as Dictionary)["PR11"] = 2
	_check(is_equal_approx(_engine._crossing_window(), 0.65), "PR11 rank 2 window 0.65 s")
	_check(_engine._spare_cap() == 3, "PR12 rank 1 stores 3 spares")
	(ledger.state["owned"] as Dictionary)["PR12"] = 3
	_check(_engine._spare_cap() == 6, "PR12 rank 3 stores 6")
	_check(is_equal_approx(_engine._smart_rounds_scale(), 0.85), "Smart Rounds costs -15% in the V5 test change")

	# --- PR-01: PR03 ranks give 2, 3, 4, 5 additional pierces, on the real
	# decorated native profile and through real projectiles (a row of rank+3
	# stationary targets: the first rank+2 are crossed, the last is never
	# touched); and PR03 at rank 1 still satisfies every Fusion that named it
	# as a parent in the V4 tree, through the V5 ledger's own purchase gate.
	for pr03_rank in range(1, 5):
		(ledger.state["owned"] as Dictionary)["PR03"] = pr03_rank
		var native_profile := HitProfileAdapter.new()
		native_profile.reset(10.0)
		_runner.apply_to_managed_hit_profile(native_profile, &"ranged")
		_check(native_profile.pierce == pr03_rank + 1, "PR03 rank %d decorates the native shot with %d additional pierces (%d)" % [pr03_rank, pr03_rank + 1, native_profile.pierce])
		# Spaced past the 28 px hit diameter plus one step: the sim excludes
		# only the LAST hit handle, so packed targets would be re-hit and
		# burn pierce on repeats instead of crossings.
		var pierce_row: Array = []
		for i in range(pr03_rank + 3):
			pierce_row.append(_spawn_still(500.0, _player.global_position + Vector2(30.0 + 44.0 * float(i), 0.0)))
		ProjectileManager.spawn_player(_player.global_position, Vector2.RIGHT, native_profile, _player)
		await _settle()
		var crossed_count := 0
		for handle in pierce_row:
			if EnemyWorld.get_health(handle) < 500.0:
				crossed_count += 1
		var last_hp := EnemyWorld.get_health(pierce_row[pr03_rank + 2])
		_check(crossed_count == pr03_rank + 2 and is_equal_approx(last_hp, 500.0), "a rank %d native shot physically crosses %d targets and stops there (%d hit, target %d at %.0f)" % [pr03_rank, pr03_rank + 2, crossed_count, pr03_rank + 3, last_hp])
		await _clear_field(pierce_row)
	var v4_db := AscensionTreeDB.shared()
	var fusion_parents_checked := 0
	for fusion_id in v4_db.ids_of_kind("fusion"):
		var v4_parents: PackedStringArray = v4_db._owned_ids_in(v4_db.node(fusion_id).get("requires", {}))
		if not v4_parents.has("PR03"):
			continue
		var scratch := AscensionLedger.new(ledger.db, AscensionLedger.fresh_state("ranged", "v5_ranged"))
		for parent in v4_parents:
			(scratch.state["owned"] as Dictionary)[String(parent)] = 1
		var v5_parents: PackedStringArray = ledger.db._owned_ids_in(ledger.db.node(fusion_id).get("requires", {}))
		var verdict := scratch.can_buy(fusion_id, 100000)
		_check(v5_parents.has("PR03") and bool(verdict["ok"]), "unranked PR03 still qualifies its original Fusion parent %s in the V5 tree (%s)" % [fusion_id, "ok" if bool(verdict["ok"]) else String(verdict["reason"])])
		fusion_parents_checked += 1
	_check(fusion_parents_checked == 2, "PR03 parented exactly the two original Fusions, MR1 and RM1 (%d checked)" % fusion_parents_checked)

	# --- PR-02: the ranked bonus only on Far Shot's own Weak Points.
	(ledger.state["owned"] as Dictionary)["PR02"] = 3
	_runner.refresh()
	_engine = _runner.engine_for("PR01") as PrecisionEngineV5
	var far_victim := _spawn_enemy(500.0, _player.global_position + Vector2(200, 0))
	_engine.expose(far_victim, "far_shot")
	var preview := {"handle": far_victim, "raw": 10.0, "tags": _bullet_tags("t1", 1), "core": "ranged", "family": "native", "core_strike": true}
	var boosted := _engine.modify_outgoing_damage(preview, 10.0)
	_check(is_equal_approx(boosted, 10.0 + D + 0.4 * D), "a Far Shot Weak Point consumes for +1.4D at rank 3 (%.1f)" % boosted)
	var read_victim := _spawn_enemy(500.0, _player.global_position + Vector2(60, 0))
	_engine.expose(read_victim, "")
	var preview2 := {"handle": read_victim, "raw": 10.0, "tags": _bullet_tags("t2", 2), "core": "ranged", "family": "native", "core_strike": true}
	var plain := _engine.modify_outgoing_damage(preview2, 10.0)
	_check(is_equal_approx(plain, 10.0 + D), "an ordinary Weak Point stays +1D")
	EnemyWorld.remove_enemy(far_victim, &"test")
	EnemyWorld.remove_enemy(read_victim, &"test")
	await _clear_field([])

	# --- PR-03: a PR07 return at rank 3 applies 90% ONCE to the damage
	# captured as the return begins (the outbound's ramped damage after one
	# crossed target), and no second physical return is created. The victim
	# sits behind the outbound's start, on the return's leg only: its whole
	# loss is the one return hit.
	(ledger.state["owned"] as Dictionary)["PR07"] = 3
	var return_row := _player.global_position + Vector2(0.0, 100.0)
	var ramp_target := _spawn_still(500.0, return_row + Vector2(10.0, 0.0))
	var return_victim := _spawn_still(500.0, return_row + Vector2(-30.0, 0.0))
	var returns_before := int(_engine.counters["returns"])
	# Every PR07-rooted hit on the victim, counted per projectile id (a
	# Dictionary: lambdas copy ints): a duplicate return would fly the same
	# leg and land as a second id.
	var return_hits_by_id := {}
	var count_returns := func(hit: Dictionary) -> void:
		if int(hit["handle"]) == return_victim and hit["root"] == "PR07":
			var pid := int(hit["projectile_id"])
			return_hits_by_id[pid] = int(return_hits_by_id.get(pid, 0)) + int(hit["hit_count"])
	_runner.hit_resolved.connect(count_returns)
	_runner.spawn_bullet(return_row, Vector2.RIGHT, 10.0, _bullet_tags("return", 0), {"pierce": 1, "pierce_ramp": 0.2 * D, "pierce_ramp_cap": D, "max_range": 20.0})
	await _settle()
	_runner.hit_resolved.disconnect(count_returns)
	var captured := 10.0 + 0.2 * D
	var victim_hp := EnemyWorld.get_health(return_victim)
	var return_hits := 0
	for pid in return_hits_by_id:
		return_hits += int(return_hits_by_id[pid])
	_check(EnemyWorld.get_health(ramp_target) < 500.0 and is_equal_approx(victim_hp, 500.0 - 0.9 * captured), "the rank 3 return deals 90%% of the captured %.1f once: %.2f (victim lost %.2f)" % [captured, 0.9 * captured, 500.0 - victim_hp])
	_check(int(_engine.counters["returns"]) == returns_before + 1 and return_hits_by_id.size() == 1 and return_hits == 1 and ProjectileManager.active_count() == 0, "one outbound made exactly one physical return and the return made none (%d returns, %d return ids, %d return hits on the victim)" % [int(_engine.counters["returns"]) - returns_before, return_hits_by_id.size(), return_hits])
	await _clear_field([ramp_target, return_victim])

	# --- PR-04: PR09 emits exactly 2/3/4 physically distinct split rounds at
	# 0.7D under its authored condition (an exposed victim killed by a round
	# that already crossed another target), and a consuming hit on that same
	# condition that does not kill never calls it.
	for pr09_rank in range(1, 4):
		(ledger.state["owned"] as Dictionary)["PR09"] = pr09_rank
		var split_crossed := _spawn_still(500.0, _player.global_position + Vector2(40.0, 0.0))
		var split_victim := _spawn_still(1.0, _player.global_position + Vector2(80.0, 0.0))
		_engine.expose(split_victim)
		var splits_before := int(_engine.counters["splits"])
		_runner.spawn_bullet(_player.global_position, Vector2.RIGHT, 10.0, _bullet_tags("split:%d" % pr09_rank, 0), {"pierce": 2, "max_range": 200.0})
		await _settle(func() -> bool: return not _runner.enemy_alive(split_victim), 120)
		var rounds := _projectiles_rooted("PR09")
		var round_ids := {}
		var all_seven_tenths := true
		for entry in rounds:
			round_ids[int(entry["id"])] = true
			if not is_equal_approx(float(entry["damage"]), 0.7 * D):
				all_seven_tenths = false
		var expected_rounds := pr09_rank + 1
		_check(not _runner.enemy_alive(split_victim) and int(_engine.counters["splits"]) == splits_before + 1 and rounds.size() == expected_rounds and round_ids.size() == expected_rounds and all_seven_tenths, "PR09 rank %d: the exposed kill after a pierce emits %d distinct split rounds at 0.7D (%d live, %d ids, %d active)" % [pr09_rank, expected_rounds, rounds.size(), round_ids.size(), ProjectileManager.active_count()])
		await _clear_field([split_crossed, split_victim])
	var nonkill_crossed := _spawn_still(500.0, _player.global_position + Vector2(40.0, 0.0))
	var nonkill_victim := _spawn_still(500.0, _player.global_position + Vector2(80.0, 0.0))
	_engine.expose(nonkill_victim)
	var splits_nonkill := int(_engine.counters["splits"])
	_runner.spawn_bullet(_player.global_position, Vector2.RIGHT, 10.0, _bullet_tags("split:nonkill", 0), {"pierce": 2, "max_range": 200.0})
	await _settle(func() -> bool: return EnemyWorld.get_health(nonkill_victim) < 500.0, 120)
	var consumed_hp := EnemyWorld.get_health(nonkill_victim)
	var rounds_after_nonkill := _projectiles_rooted("PR09").size()
	await _settle()
	_check(is_equal_approx(consumed_hp, 500.0 - 10.0 - D) and not _engine.is_exposed(nonkill_victim) and rounds_after_nonkill == 0 and int(_engine.counters["splits"]) == splits_nonkill, "a consuming hit after a pierce that does not kill emits no split round (lost %.1f, %d rounds, %d splits)" % [500.0 - consumed_hp, rounds_after_nonkill, int(_engine.counters["splits"]) - splits_nonkill])
	await _clear_field([nonkill_crossed, nonkill_victim])

	# --- PRC boss fallback: >= 3 physical hits totalling >= 12D on one
	# elite from one projectile root triggers the six-gun payoff once.
	var boss := _spawn_enemy(4000.0, _player.global_position + Vector2(150, 0), true)
	var squads_before := int(_engine.counters["squads"])
	var tags := _bullet_tags("root:boss", 7)
	var ledger_payload := HitLedger.new()
	for i in range(3):
		var payload := HitLedger.new()
		payload.target_handle = boss
		payload.source = _player
		payload.hit_count = 1
		payload.total_raw_damage = 4.5 * D
		payload.tags = tags
		payload.projectile_id = 7
		EnemyCombat.apply_hit_ledger(boss, payload)
	_check(int(_engine.counters["squads"]) == squads_before + 1, "three physical hits worth 12D+ on one elite fire the Firing Squad fallback")
	_check(int(_engine.counters.get("squad_boss_triggers", 0)) == 1, "the fallback is attributed to the boss route")
	# During the 8 s recovery the same route cannot refire.
	for i in range(3):
		var payload2 := HitLedger.new()
		payload2.target_handle = boss
		payload2.source = _player
		payload2.hit_count = 1
		payload2.total_raw_damage = 4.5 * D
		payload2.tags = tags
		payload2.projectile_id = 7
		EnemyCombat.apply_hit_ledger(boss, payload2)
	_check(int(_engine.counters["squads"]) == squads_before + 1, "the fallback respects the recovery period")
	EnemyWorld.remove_enemy(boss, &"test")

	# --- PR-05: PRC's dense-enemy trigger and the alternate durable-target
	# trigger each work through REAL projectiles, and when one hit event
	# satisfies both thresholds the catastrophe fires once and enters one
	# recovery period. No synthetic HitLedger anywhere in this section.
	# (a) The durable-target route (playtest review finding 11): three legal
	# trajectories from the player's position, colliding through the actual
	# simulation, each with its own projectile id but one cast root.
	_engine._squad_recovery = 0.0
	_engine._boss_roots.clear()
	# A STATIONARY elite: the shared helper's walk speed let the target
	# sidestep a later shot on unlucky frame timing (flake), and this route
	# is about the hit rule, not marksmanship.
	var durable := EnemyWorld.create_enemy(SpawnState.new(&"asc_pr_v5", "res://asc_pr_v5.tscn", _player.global_position + Vector2(300, 0), 4000.0, 0.0, 8.0, 0, EnemyWorldTypes.Flags.ELITE))
	var squads_real := int(_engine.counters["squads"])
	var profile := HitProfileAdapter.new()
	profile.damage = 5.0 * D
	profile.speed = 900.0
	profile.max_range = 500.0
	profile.collision_radius = 6.0
	profile.set_meta("asc_tags", _bullet_tags("real:boss", 0))
	# Projectiles advance on the PHYSICS clock (ProjectileHandleCombatTest
	# pins that), so the waits are physics frames gated on the hit actually
	# landing — render-frame pacing in headless runs outruns flight time.
	var shot_log: Array = []
	for _shot in range(3):
		var aim := (EnemyWorld.get_position(durable) - (_player.global_position + Vector2(40, 0))).normalized()
		var hp_before_shot := EnemyWorld.get_health(durable)
		var spawned := ProjectileManager.spawn_player(_player.global_position + Vector2(40, 0), aim, profile, _player)
		for _frame in range(120):
			await get_tree().physics_frame
			if int(_engine.counters["squads"]) > squads_real:
				break
			if EnemyWorld.get_health(durable) < hp_before_shot:
				break
		shot_log.append([_shot, spawned, ProjectileManager.active_count(), EnemyWorld.get_health(durable)])
	for _frame in range(60):
		await get_tree().physics_frame
		if int(_engine.counters["squads"]) > squads_real:
			break
	_check(int(_engine.counters["squads"]) == squads_real + 1, "three REAL projectile hits on one elite fire the Firing Squad (%d, hp %.0f, roots %s, shots %s, active %d)" % [int(_engine.counters["squads"]), EnemyWorld.get_health(durable) if EnemyWorld.is_valid_handle(durable) else -1.0, str(_engine._boss_roots), str(shot_log), ProjectileManager.active_count()])
	await _clear_field([durable])

	# (b) The original dense-enemy route: one projectile root crossing 12
	# distinct enemies. One real piercing round through a stationary row.
	_engine._squad_recovery = 0.0
	_engine._boss_roots.clear()
	_engine._cast_crossed.clear()
	_engine._cast_consumed.clear()
	# Rows are spaced 44 px: the sim excludes only the LAST hit handle from
	# a sweep, so targets packed inside the hit diameter would be re-hit.
	var dense_row: Array = []
	for i in range(12):
		dense_row.append(_spawn_still(500.0, _player.global_position + Vector2(40.0 + 44.0 * float(i), 0.0)))
	var squads_dense := int(_engine.counters["squads"])
	var boss_triggers_dense := int(_engine.counters.get("squad_boss_triggers", 0))
	var lines_dense := int(_engine.counters["squad_lines"])
	_runner.spawn_bullet(_player.global_position, Vector2.RIGHT, 10.0, _bullet_tags("dense", 0), {"pierce": 14, "max_range": 700.0})
	await _settle(func() -> bool: return int(_engine.counters["squads"]) > squads_dense, 180)
	var recovery_dense: float = _engine._squad_recovery
	await _settle()
	_check(int(_engine.counters["squads"]) == squads_dense + 1 and int(_engine.counters.get("squad_boss_triggers", 0)) == boss_triggers_dense and recovery_dense > 0.0, "one real round crossing 12 distinct enemies fires the Firing Squad once by the dense route, not the boss route (%d squads, recovery %.2f)" % [int(_engine.counters["squads"]) - squads_dense, recovery_dense])
	_check(int(_engine.counters["squad_lines"]) == lines_dense + 6, "the dense route pays the same six edge guns (%d lines)" % (int(_engine.counters["squad_lines"]) - lines_dense))
	await _clear_field(dense_row)

	# (c) Both thresholds in ONE hit event: three co-located rounds of one
	# cast fly identical trajectories, so the simulation batches their hits
	# on each target into one ledger of hit_count 3. They cross eleven
	# normals and then an elite: that elite event is the root's 12th distinct
	# enemy AND its third physical hit reaching 15D on one elite.
	_engine._squad_recovery = 0.0
	_engine._boss_roots.clear()
	_engine._cast_crossed.clear()
	_engine._cast_consumed.clear()
	var both_row: Array = []
	for i in range(11):
		both_row.append(_spawn_still(500.0, _player.global_position + Vector2(40.0 + 44.0 * float(i), 0.0)))
	var both_elite := _spawn_still(4000.0, _player.global_position + Vector2(40.0 + 44.0 * 11.0, 0.0), true)
	both_row.append(both_elite)
	var elite_events: Array = []
	var capture := func(hit: Dictionary) -> void:
		if int(hit["handle"]) == both_elite and AscensionTags.value_of(hit["tags"], "cast") == "both":
			elite_events.append([int(hit["hit_count"]), float(hit["applied"])])
	_runner.hit_resolved.connect(capture)
	var squads_both := int(_engine.counters["squads"])
	var boss_triggers_both := int(_engine.counters.get("squad_boss_triggers", 0))
	for _round in range(3):
		_runner.spawn_bullet(_player.global_position, Vector2.RIGHT, 5.0 * D, _bullet_tags("both", 0), {"pierce": 14, "max_range": 600.0})
	await _settle(func() -> bool: return int(_engine.counters["squads"]) > squads_both, 180)
	var recovery_both: float = _engine._squad_recovery
	var squads_at_trigger := int(_engine.counters["squads"])
	await _settle()
	_runner.hit_resolved.disconnect(capture)
	var first_event: Array = elite_events[0] if not elite_events.is_empty() else [0, 0.0]
	_check(int(first_event[0]) == 3 and float(first_event[1]) >= 12.0 * D, "the elite's first event carries the root's three physical hits worth 12D+ (%d hits, %.1f)" % [int(first_event[0]), float(first_event[1])])
	_check(squads_at_trigger == squads_both + 1 and int(_engine.counters["squads"]) == squads_both + 1 and recovery_both > 7.0 and recovery_both <= 8.0, "with the 12th distinct enemy and the boss threshold met by that one event, the Firing Squad fires once and enters one 8 s recovery (%d squads, recovery %.2f, boss route +%d)" % [int(_engine.counters["squads"]) - squads_both, recovery_both, int(_engine.counters.get("squad_boss_triggers", 0)) - boss_triggers_both])
	await _clear_field(both_row)

	_finish()


func _finish() -> void:
	print("AscensionPrecisionV5Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
