extends Node

# Ranged V5 Barrage (handoff 2026-09-25): Spin Up climbs and decays with no
# Heat bar and no Jam, Burst's x2 rides after the shot-rate cap, ranked Fifth
# Shot / Fragmentation follow their tables, Hot Rounds burns unheated through
# the named strongest-refresh burn, Hot Core is a deliberate purchase whose
# Meltdown never stops the gun, and Overload has a no-Heat trigger.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionBarrageV5Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: BarrageEngineV5


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_br_v5", "res://asc_br_v5.tscn", at, hp, 10.0, 8.0, 0, 0))


func _fire(style: StringName = &"ranged") -> void:
	RunEvents.weapon_fired.emit(_player, style, _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)


func _native_bullet_tags(volley: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags.append("volley:%d" % volley)
	return AscensionTags.with_flag(tags, "core_strike")


## Slots of the real projectiles spawned since `start` whose tags name `root`
## and `path`. The run never yields a frame, so the manager's slots are
## append-only and stable while a block reads them.
func _spawned_since(start: int, root: String, path: String) -> Array:
	var out := []
	for i in range(start, ProjectileManager.active_count()):
		var tags: PackedStringArray = ProjectileManager._tags[i]
		if AscensionTags.value_of(tags, "root") == root and AscensionTags.value_of(tags, "path") == path:
			out.append(i)
	return out


## Enemy health is float32: compare ticks with a real tolerance.
func _near(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) <= tolerance


func _bounces_all(fragments: Array, bounces: int) -> bool:
	for fragment in fragments:
		if int((fragment as Dictionary)["bounces"]) != bounces:
			return false
	return not fragments.is_empty()


## The sum of the unit headings of the projectiles in `slots` (zero for an
## even radial spread).
func _heading_sum(slots: Array) -> Vector2:
	var total := Vector2.ZERO
	for slot in slots:
		total += (ProjectileManager._velocities[int(slot)] as Vector2).normalized()
	return total


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	_check(ledger.is_v5(), "the attempt runs the V5 tree")
	ledger.record_purchase("BR01", 0)
	for id in ["BR02", "BR04", "BR05", "BR06", "BR07", "BR08", "BR11", "BRQ", "BRC"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine != null, "a V5 run loads BarrageEngineV5")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()

	# --- BR-01: no Heat without Hot Core, Spin Up stages climb and decay.
	for _i in range(8):
		_fire()
		_engine.tick(0.2)
	_check(not _engine.claims_heat() and is_zero_approx(_engine.heat), "no BR03: no Heat pool, ever (%s)" % str(_engine.heat))
	_check(int(_engine.counters["jams"]) == 0 and not _engine.jammed(), "no BR03: nothing Jams")
	_check(_engine.spin_stage() >= 2, "1.4 s of sustained fire reaches Spin Up stage 2 (%d)" % _engine.spin_stage())
	_check(is_equal_approx(_engine.haste_multiplier("ranged"), 1.0 + _engine.spin_bonus()), "the engine haste is 1 + the stage bonus")
	_engine._spin_streak = 2.4
	_engine._spin_last_input = _engine._clock
	_check(_engine.spin_stage() == 3 and is_equal_approx(_engine.spin_bonus(), 0.60), "rank-1 stage 3 gives +60%")
	# Decay: after 0.75 s of idle grace, one stage per 0.5 s.
	_engine.tick(0.8)
	_check(_engine.spin_stage() == 3, "0.8 s idle is inside the grace + first step: stage holds")
	_engine.tick(0.5)
	_check(_engine.spin_stage() == 2, "0.5 s past the grace drops one stage (%d)" % _engine.spin_stage())
	_engine.tick(0.5)
	_check(_engine.spin_stage() == 1, "another 0.5 s drops another stage")
	# A pause under 0.35 s between shots still counts as firing time.
	_engine._spin_last_input = _engine._clock
	var streak_before: float = _engine._spin_streak
	_engine.tick(0.3)
	_fire()
	_check(is_equal_approx(_engine._spin_streak, streak_before + 0.3), "a 0.3 s gap between shots accrues as firing time")

	# --- BR-02: Burst is a post-cap window, not a capped haste source.
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 1.0), "no Burst: post-cap multiplier is 1")
	var verdict := _engine.activate_q("BRQ")
	_check(bool(verdict["ok"]), "Burst starts")
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 2.0), "Burst supplies exactly one x2 after the cap")
	_check(_engine.haste_multiplier("ranged") < 2.0, "Burst does not also inflate the capped haste")
	_engine.tick(2.1)
	_check(_engine.burst_left <= 0.0 and int(_engine.counters["burst_rounds"]) >= 12, "Burst completes with its 12-round fan (%d)" % int(_engine.counters["burst_rounds"]))
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 1.0), "the x2 ends with the window")

	# --- BR-03: Fifth Shot rank table.
	var fifths_before := int(_engine.counters["fifth_shots"])
	_engine._strike_credit = 0.0
	_engine._fifth_package = 0
	for _i in range(6):
		_fire()
	_check(int(_engine.counters["fifth_shots"]) == fifths_before + 1, "rank 1: the fifth strike arms, the sixth fires")
	(ledger.state["owned"] as Dictionary)["BR02"] = 4
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._strike_credit = 0.0
	_engine._fifth_package = 0
	fifths_before = int(_engine.counters["fifth_shots"])
	for _i in range(4):
		_fire()
	_check(int(_engine.counters["fifth_shots"]) == fifths_before + 1, "rank 4: every third strike arms four rounds")

	# --- BR-04: Fragmentation rank 4 emits five fragments per real kill.
	(ledger.state["owned"] as Dictionary)["BR05"] = 4
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var frags_before := int(_engine.counters["fragments"])
	var victim := _spawn_enemy(4.0, _player.global_position + Vector2(100, 0))
	_runner.damage_enemy(victim, 50.0, _native_bullet_tags(900))
	_check(int(_engine.counters["fragments"]) == frags_before + 5, "a rank-4 kill releases five seeking fragments (%d)" % (int(_engine.counters["fragments"]) - frags_before))

	# --- BR-05: a rank-3 Crossfire event fires two real edge projectiles; Bullet Runes and Run and Gun count those edge shots, not native inputs or events.
	(ledger.state["owned"] as Dictionary)["BR06"] = 3
	for id in ["RM4", "MR5"]:
		ledger.record_purchase(id, 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var momentum := _runner.engine_of_discipline("MO") as MomentumEngine
	_check(momentum != null and _runner.engine_of_discipline("IN") != null, "the Fusions bring their Momentum and Invocation halves")
	_engine._crossfire_credit = 0.0
	_engine._crossfire_count = 0
	var cross_before := int(_engine.counters["crossfire"])
	var edge_start := ProjectileManager.active_count()
	_fire()
	_check(_spawned_since(edge_start, "BR06", "crossfire").is_empty(), "rank 3: one credited strike is not yet an event")
	edge_start = ProjectileManager.active_count()
	_fire()
	var edge := _spawned_since(edge_start, "BR06", "crossfire")
	_check(edge.size() == 2 and int(_engine.counters["crossfire"]) == cross_before + 2, "rank 3: the second strike's event fires two real edge projectiles (%d)" % edge.size())
	if edge.size() == 2:
		var a: Vector2 = ProjectileManager._positions[int(edge[0])]
		var b: Vector2 = ProjectileManager._positions[int(edge[1])]
		_check(a.distance_to(b) > 100.0 and a.distance_to(_player.global_position) > 200.0 and b.distance_to(_player.global_position) > 200.0, "the two edge points are separate and off the player's body")
		_check(is_equal_approx(float(ProjectileManager._damage[int(edge[0])]), 0.65 * D) and is_equal_approx(float(ProjectileManager._damage[int(edge[1])]), 0.65 * D), "rank-3 edge shots are 0.65D each")
	# Rank 2 (every 3rd strike, two shots) tells the three candidate counts
	# apart: nine inputs are three events and six edge shots. Every third
	# EDGE SHOT (the 3rd and the 6th) carries the Rune and the Afterimage:
	# two, not three per native input and not one per event.
	(ledger.state["owned"] as Dictionary)["BR06"] = 2
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._crossfire_credit = 0.0
	_engine._crossfire_count = 0
	var afterimages_before := int(momentum.counters["afterimages"])
	var run_gun_before := int(_engine.counters.get("run_and_gun_afterimages", 0))
	edge_start = ProjectileManager.active_count()
	for _i in range(9):
		_fire()
	edge = _spawned_since(edge_start, "BR06", "crossfire")
	var runes := 0
	for slot in edge:
		if AscensionTags.has_flag(ProjectileManager._tags[int(slot)], "rune"):
			runes += 1
	_check(edge.size() == 6, "rank 2: nine inputs are three events of two edge shots (%d)" % edge.size())
	_check(edge.size() == 6 and runes == 2 and AscensionTags.has_flag(ProjectileManager._tags[int(edge[2])], "rune") and AscensionTags.has_flag(ProjectileManager._tags[int(edge[5])], "rune"), "Bullet Runes flags the 3rd and 6th edge shots: two, not three inputs' worth nor one event's (%d)" % runes)
	_check(int(_engine.counters.get("run_and_gun_afterimages", 0)) == run_gun_before + 2 and int(momentum.counters["afterimages"]) == afterimages_before + 2, "Run and Gun queued two Afterimages for six edge shots")
	(ledger.state["owned"] as Dictionary)["BR06"] = 1
	for id in ["RM4", "MR5"]:
		(ledger.state["owned"] as Dictionary).erase(id)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5

	# --- BR-11: Pinball and Cluster Rounds still seal each other; ranked Fragmentation grows the on-kill group without a hidden second Pinball bounce.
	var sealed := AscensionLedger.new(AscensionTreeDB.shared_for("v5_ranged"), AscensionLedger.fresh_state("ranged", "v5_ranged"))
	sealed.record_purchase("BR01", 0)
	for id in ["BR05", "BR09", "BR10"]:
		sealed.record_purchase(id, 100)
	var seal_verdict := sealed.can_buy("BR12", 1000000)
	_check(not bool(seal_verdict["ok"]) and String(seal_verdict["reason"]).contains("Pinball"), "owning Pinball seals Cluster Rounds (%s)" % String(seal_verdict["reason"]))
	sealed = AscensionLedger.new(AscensionTreeDB.shared_for("v5_ranged"), AscensionLedger.fresh_state("ranged", "v5_ranged"))
	sealed.record_purchase("BR01", 0)
	for id in ["BR05", "BR09", "BR12"]:
		sealed.record_purchase(id, 100)
	seal_verdict = sealed.can_buy("BR10", 1000000)
	_check(not bool(seal_verdict["ok"]) and String(seal_verdict["reason"]).contains("Cluster Rounds"), "owning Cluster Rounds seals Pinball (%s)" % String(seal_verdict["reason"]))
	# Rank-4 Fragmentation with Pinball: five fragments, each with exactly one bounce.
	for id in ["BR09", "BR10"]:
		ledger.record_purchase(id, 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine.fragments.clear()
	_engine._pending_fragments.clear()
	var frag_count_before := int(_engine.counters["fragments"])
	var frag_hits_before := int(_engine.counters["fragment_hits"])
	var seed := _spawn_enemy(4.0, _player.global_position + Vector2(100, 0))
	var wall_a := _spawn_enemy(400.0, _player.global_position + Vector2(140, 0))
	var wall_b := _spawn_enemy(400.0, _player.global_position + Vector2(180, 0))
	_runner.damage_enemy(seed, 50.0, _native_bullet_tags(901))
	_check(int(_engine.counters["fragments"]) == frag_count_before + 5, "rank 4 with Pinball: the on-kill group is still five (%d)" % (int(_engine.counters["fragments"]) - frag_count_before))
	_check(_engine._pending_fragments.size() == 5 and _bounces_all(_engine._pending_fragments, 1), "each fragment carries exactly one Pinball bounce")
	# The bounce is physical: five fragments strike the first wall, bounce
	# once to the second, then expire. Ten hits, never fifteen.
	for _i in range(60):
		_engine.tick(0.05)
	_check(int(_engine.counters["fragment_hits"]) == frag_hits_before + 10 and _engine.fragments.is_empty(), "five fragments made exactly ten hits: one bounce each (%d)" % (int(_engine.counters["fragment_hits"]) - frag_hits_before))
	# A rank-2 Ricochet does not hand fragments a second bounce.
	(ledger.state["owned"] as Dictionary)["BR09"] = 2
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var seed_two := _spawn_enemy(4.0, _player.global_position + Vector2(100, 0))
	_runner.damage_enemy(seed_two, 50.0, _native_bullet_tags(902))
	_check(_engine._pending_fragments.size() == 5 and _bounces_all(_engine._pending_fragments, 1), "rank-2 Ricochet leaves fragments at one bounce")
	_engine._pending_fragments.clear()
	for handle in [wall_a, wall_b]:
		EnemyWorld.remove_enemy(handle, &"test")
	for id in ["BR09", "BR10"]:
		(ledger.state["owned"] as Dictionary).erase(id)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._throttle_kills = 0
	_engine._hot_rounds_strikes = 0
	_engine._hot_volley_first_done = -1

	# --- BR-06: Hot Rounds burns without Heat, named, strongest-refresh.
	var target := _spawn_enemy(500.0, _player.global_position + Vector2(120, 0))
	for volley in range(1, 4):
		_runner.damage_enemy(target, 1.0, _native_bullet_tags(volley))
	_check(EnemyStatus.has_named_burn(target, &"hot_rounds"), "the third strike's first impact applies the named Hot Rounds burn")
	_check(not EnemyStatus.has_status(target, &"burn"), "the named burn is not the generic burn kind")
	# Strongest rate wins: a weaker reapplication cannot soften it.
	EnemyStatus.apply_named_burn(target, &"hot_rounds", 3.0, 0.5, 0.30 * D, _player)
	EnemyStatus.apply_named_burn(target, &"hot_rounds", 3.0, 0.5, 0.15 * D, _player)
	var hp_before := EnemyWorld.get_health(target)
	EnemyStatus.advance(0.51)
	var tick_damage := hp_before - EnemyWorld.get_health(target)
	_check(is_equal_approx(tick_damage, 0.30 * D * 0.5), "a weaker refresh keeps the stronger rate (tick %.2f)" % tick_damage)
	EnemyWorld.remove_enemy(target, &"test")

	# --- Kill Throttle: three stage-2 kills grant Overdrive.
	_engine._spin_streak = 2.4
	_engine._spin_last_input = _engine._clock
	var overdrives_before := int(_engine.counters.get("overdrives", 0))
	for i in range(3):
		var prey := _spawn_enemy(2.0, _player.global_position + Vector2(80 + i * 10, 0))
		_runner.damage_enemy(prey, 30.0, _native_bullet_tags(950 + i))
	_check(int(_engine.counters.get("overdrives", 0)) == overdrives_before + 1 and _engine._overdrive_left > 0.0, "three kills at stage 2+ grant Overdrive")

	# --- BR-10: Reserve Feed works with no Heat.
	_engine.stored_rounds = 0
	_engine._reserve_credit = 0.0
	_engine._reserve_release_inputs = 0
	for _i in range(6):
		_fire()
	_check(_engine.stored_rounds >= 2, "six inputs store two reserve rounds (%d)" % _engine.stored_rounds)
	var stored_fired_before := int(_engine.counters["stored_fired"])
	for _i in range(6):
		_fire()
	_check(int(_engine.counters["stored_fired"]) > stored_fired_before, "the twelfth input releases stored rounds toward aim")

	# --- BR-13: Overload's no-Heat trigger: 20 stage-3 inputs in 8 s.
	var overloads_before := int(_engine.counters["overloads"])
	_engine.overload_recovery_left = 0.0
	_engine._stage3_inputs.clear()
	_engine._spin_streak = 2.4
	for _i in range(20):
		_engine._spin_last_input = _engine._clock
		_fire()
		_engine.tick(0.05)
		_engine._spin_streak = maxf(_engine._spin_streak, 2.4)
	_check(int(_engine.counters["overloads"]) == overloads_before + 1, "twenty stage-3 inputs inside 8 s fire Overload with no Heat (%d)" % int(_engine.counters["overloads"]))

	# --- BR-09: Vent Volley's automatic 12/10-input release needs neither Hot Core nor Burst; a Burst completion adds its release exactly once.
	(ledger.state["owned"] as Dictionary).erase("BRQ")
	ledger._unequip("BRQ")
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(not _engine.claims_heat() and not _engine.has("BRQ") and _runner.q_id.is_empty(), "the release is tested with no Heat pool and no Burst at all")
	_engine._vent_inputs = 0
	_engine._last_vent_input = -1
	_engine.stored_rounds = 0
	_engine._reserve_credit = 0.0
	_engine._reserve_release_inputs = 0
	var loose_before := int(_engine.counters["loose_rounds"])
	var vent_start := ProjectileManager.active_count()
	for _i in range(11):
		_fire()
	_check(int(_engine.counters["loose_rounds"]) == loose_before and _spawned_since(vent_start, "BR08", "loose").is_empty(), "rank 1: eleven native inputs release nothing")
	vent_start = ProjectileManager.active_count()
	_fire()
	var loose := _spawned_since(vent_start, "BR08", "loose")
	_check(loose.size() == 8 and int(_engine.counters["loose_rounds"]) == loose_before + 8, "rank 1: the twelfth input fires eight real radial rounds (%d)" % loose.size())
	_check(loose.size() == 8 and is_equal_approx(float(ProjectileManager._damage[int(loose[0])]), 0.6 * D) and _heading_sum(loose).length() < 0.01, "the eight rounds are 0.6D and evenly radial")
	(ledger.state["owned"] as Dictionary)["BR08"] = 2
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._vent_inputs = 0
	_engine._last_vent_input = -1
	loose_before = int(_engine.counters["loose_rounds"])
	vent_start = ProjectileManager.active_count()
	for _i in range(9):
		_fire()
	_check(_spawned_since(vent_start, "BR08", "loose").is_empty(), "rank 2: nine inputs release nothing")
	vent_start = ProjectileManager.active_count()
	_fire()
	loose = _spawned_since(vent_start, "BR08", "loose")
	_check(loose.size() == 12 and int(_engine.counters["loose_rounds"]) == loose_before + 12, "rank 2: the tenth input fires twelve rounds (%d)" % loose.size())
	(ledger.state["owned"] as Dictionary)["BR08"] = 1
	# Burst back: its normal completion adds one 8-round release that
	# advances no input counter.
	ledger.record_purchase("BRQ", 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine.has("BRQ") and _runner.q_id == "BRQ", "Burst is owned and equipped again")
	_engine._vent_inputs = 3
	_engine._last_vent_input = -1
	loose_before = int(_engine.counters["loose_rounds"])
	verdict = _engine.activate_q("BRQ")
	_check(bool(verdict["ok"]), "Burst starts with no Heat")
	vent_start = ProjectileManager.active_count()
	_engine.tick(2.1)
	loose = _spawned_since(vent_start, "BR08", "loose")
	_check(loose.size() == 8 and int(_engine.counters["loose_rounds"]) == loose_before + 8, "a Burst completion adds one eight-round Vent Volley, once (%d)" % loose.size())
	_check(_engine._vent_inputs == 3, "the Q-completion release advances no native-input counter")

	# --- BR-12: an Emergency Stop in Burst's first half yields no completion fan, no BR08 Q-end release, no Vented nova and no Ammo Dump.
	for id in ["BRQ2", "BRQ5", "BRQ6"]:
		ledger.record_purchase(id, 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine.has("BRQ2") and _engine.has("BRQ5") and _engine.has("BRQ6"), "Vented, Ammo Dump and Emergency Stop ride the equipped Burst")
	_engine._vent_inputs = 0
	_engine._last_vent_input = -1
	verdict = _engine.activate_q("BRQ")
	_check(bool(verdict["ok"]), "Burst starts")
	for _i in range(8):
		_fire()   # eight Q inputs: Ammo Dump would owe two end rounds
	_engine.tick(0.5)
	_check(_engine.burst_left > _engine.burst_total * 0.5, "0.5 s in is the first half of the 2 s window")
	_runner.q_cooldown_left = 8.0
	var stop_rounds_before := int(_engine.counters["burst_rounds"])
	var stop_loose_before := int(_engine.counters["loose_rounds"])
	var stop_pending_before := _runner.pending_attacks().size()
	var stop_start := ProjectileManager.active_count()
	verdict = _engine.activate_q("BRQ")
	_check(not bool(verdict["ok"]) and String(verdict["message"]) == "STOPPED" and _engine.burst_left <= 0.0, "a second press stops the Burst early (%s)" % String(verdict["message"]))
	_check(is_equal_approx(_runner.q_cooldown_left, 4.0), "half of the unused Q cooldown is refunded")
	_engine.tick(3.0)
	_check(int(_engine.counters["burst_rounds"]) == stop_rounds_before, "no completion fan and no Ammo Dump")
	_check(int(_engine.counters["loose_rounds"]) == stop_loose_before and _engine._vent_inputs == 8, "no BR08 Q-end release")
	_check(_runner.pending_attacks().size() == stop_pending_before, "no Vented nova")
	_check(ProjectileManager.active_count() == stop_start, "no projectile of any family left the cancelled cast")
	for id in ["BRQ2", "BRQ5", "BRQ6"]:
		(ledger.state["owned"] as Dictionary).erase(id)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5

	# --- BR-07: Heat 50 / 75 (and 100, in the Meltdown block) each change the visible firing; only the highest tier's aura damages, and a body just outside its drawn edge takes nothing.
	ledger.record_purchase("BR03", 400)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine.claims_heat(), "owning BR03 creates the Heat pool")
	for _i in range(7):
		_fire()
	_check(_engine.heat >= 50.0 and _engine.tier_index() == 1, "seven inputs cross 50 Heat into tier 1 (%s)" % str(_engine.heat))
	var aura: Array = _engine.aura_state()
	_check(is_equal_approx(float(aura[0]), 0.5 * AscensionRunner.R) and is_equal_approx(float(aura[1]), 0.12 * D), "tier 1 aura: 0.5R radius at 0.12 D/s")
	# The visible firing change: exactly one 0.35D Hot Core side round per native input.
	var side_start := ProjectileManager.active_count()
	_fire()
	var side := _spawned_since(side_start, "BR03", "side")
	_check(_engine.tier_side_rounds() == 1 and side.size() == 1 and is_equal_approx(float(ProjectileManager._damage[int(side[0])]), 0.35 * D), "tier 1: one 0.35D side round rides each native input (%d)" % side.size())
	# The ring is drawn at exactly the damaging radius: a body wholly outside it is untouched.
	var enemy_r := 8.0
	var near := _spawn_enemy(300.0, _player.global_position + Vector2(0.5 * AscensionRunner.R - 1.0, 0))
	var far := _spawn_enemy(300.0, _player.global_position + Vector2(0.5 * AscensionRunner.R + enemy_r + 1.0, 0))
	_engine._aura_tick_left = 0.0
	_engine._tick_aura(0.26)
	_check(_near(300.0 - EnemyWorld.get_health(near), 0.12 * D * 0.25), "an enemy inside the aura takes one 0.25 s tick at 0.12 D/s (%.3f)" % (300.0 - EnemyWorld.get_health(near)))
	_check(is_equal_approx(EnemyWorld.get_health(far), 300.0), "an enemy just outside the drawn edge takes nothing")
	EnemyWorld.remove_enemy(near, &"test")
	EnemyWorld.remove_enemy(far, &"test")
	# Tier 2: two side rounds, R at 0.22 D/s: the highest tier only, never both summed.
	for _i in range(3):
		_fire()
	_check(_engine.heat >= 75.0 and _engine.heat < 100.0 and _engine.tier_index() == 2, "three more inputs cross 75 into tier 2 (%s)" % str(_engine.heat))
	aura = _engine.aura_state()
	_check(is_equal_approx(float(aura[0]), AscensionRunner.R) and is_equal_approx(float(aura[1]), 0.22 * D), "tier 2 aura: R at 0.22 D/s, not 0.34")
	side_start = ProjectileManager.active_count()
	_fire()
	side = _spawned_since(side_start, "BR03", "side")
	_check(_engine.tier_side_rounds() == 2 and side.size() == 2, "tier 2: two side rounds per native input (%d)" % side.size())
	var inner := _spawn_enemy(300.0, _player.global_position + Vector2(0.5 * AscensionRunner.R - 1.0, 0))
	near = _spawn_enemy(300.0, _player.global_position + Vector2(AscensionRunner.R - 1.0, 0))
	far = _spawn_enemy(300.0, _player.global_position + Vector2(AscensionRunner.R + enemy_r + 1.0, 0))
	_engine._aura_tick_left = 0.0
	_engine._tick_aura(0.26)
	_check(_near(300.0 - EnemyWorld.get_health(inner), 0.22 * D * 0.25), "inside both radii the tick is the top tier's rate alone (%.3f)" % (300.0 - EnemyWorld.get_health(inner)))
	_check(_near(300.0 - EnemyWorld.get_health(near), 0.22 * D * 0.25), "just inside R takes the tier-2 tick")
	_check(is_equal_approx(EnemyWorld.get_health(far), 300.0), "just outside R takes nothing")
	for handle in [inner, near, far]:
		EnemyWorld.remove_enemy(handle, &"test")

	# --- BR-08: an ordinary Meltdown is a 2 s window locked at 100 that ends at 40 with a 3 s lockout and never blocks the gun; Overclock's own rules follow in the next two blocks.
	_engine.heat = 96.0
	_engine.add_heat(8.0)
	_check(_engine._meltdown_left > 0.0 and is_equal_approx(_engine.heat, 100.0), "crossing 100 begins the 2 s Meltdown at locked 100")
	_check(is_equal_approx(_engine._meltdown_left, 2.0), "the window is 2.0 s")
	_engine.add_heat(50.0)
	_check(is_equal_approx(_engine.heat, 100.0), "Meltdown discards extra Heat instead of banking it")
	_check(int(_engine.counters["jams"]) == 0 and float(_player.get("_weapon_cd")) < 0.5, "Meltdown never stops the gun")
	# The basic weapon really fires inside the window: a native bullet leaves
	# through the player. BR-07's 100 row rides the same shot: three Hot Core
	# side rounds, and the 2R aura at 0.35 D/s.
	_check(is_zero_approx(float(_player.get("_weapon_cd"))), "Meltdown applied no native-fire block")
	var native_start := ProjectileManager.active_count()
	_player.call("_fire_weapon", _player.global_position + Vector2(200, 0))
	var native_fired := ProjectileManager.active_count() > native_start
	_check(native_fired and AscensionTags.value_of(ProjectileManager._tags[native_start], "family") == "native", "a real native shot leaves the gun during Meltdown")
	_check(_engine.tier_side_rounds() == 3 and _spawned_since(native_start, "BR03", "side").size() == 3, "Meltdown: three Hot Core side rounds per native input")
	_check(_engine._meltdown_left > 0.0 and is_equal_approx(_engine.heat, 100.0), "the shot's own Heat is discarded and the lock holds")
	aura = _engine.aura_state()
	_check(is_equal_approx(float(aura[0]), 2.0 * AscensionRunner.R) and is_equal_approx(float(aura[1]), 0.35 * D), "Meltdown aura: 2R at 0.35 D/s")
	near = _spawn_enemy(300.0, _player.global_position + Vector2(2.0 * AscensionRunner.R - 1.0, 0))
	far = _spawn_enemy(300.0, _player.global_position + Vector2(2.0 * AscensionRunner.R + enemy_r + 1.0, 0))
	_engine._aura_tick_left = 0.0
	_engine._tick_aura(0.26)
	_check(_near(300.0 - EnemyWorld.get_health(near), 0.35 * D * 0.25), "just inside 2R takes the Meltdown tick")
	_check(is_equal_approx(EnemyWorld.get_health(far), 300.0), "just outside 2R takes nothing")
	EnemyWorld.remove_enemy(near, &"test")
	EnemyWorld.remove_enemy(far, &"test")
	_engine.tick(2.1)
	_check(is_equal_approx(_engine.heat, 40.0) and _engine._meltdown_lockout_left > 0.0, "Meltdown ends at 40 with the 3 s lockout")
	_engine._idle = 0.0
	_engine.add_heat(200.0)
	_check(is_equal_approx(_engine.heat, 99.0), "during lockout ordinary Heat stops at 99")

	# --- BR-08 (Overclock): sustained Meltdown IS a Meltdown that keeps cooling at 25/s, and 180 Heat is its own emergency-vent release.
	# Overclock + Thermal Fury (playtest review findings 7 and 8). BRF2 needs
	# BR08+BR11-adjacent locals; both routes — Overclock owned before heating,
	# and heat carried through the lockout — must deliver the fork.
	ledger.record_purchase("BR03", 0)   # idempotent for a fresh read below
	for id in ["BRF2", "BRK1"]:
		ledger.record_purchase(id, 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._meltdown_lockout_left = 0.0
	_engine.heat = 0.0
	var overclock_loose_before := int(_engine.counters["loose_rounds"])
	_engine.add_heat(120.0)
	_check(_engine._sustained_meltdown and _engine.in_meltdown(), "Overclock crossing 100 enters SUSTAINED Meltdown")
	_check(int(_engine.counters.get("sustained_meltdowns", 0)) == 1, "the episode is counted")
	_check(_engine._meltdown_left <= 0.0 and is_equal_approx(_engine.heat, 120.0), "no 2 s lock: Heat keeps its real value above 100")
	_check(is_equal_approx(_runner.get_damage_taken_multiplier(), 1.25), "above 100 Heat enemy damage is +25%")
	var aura_hot: Array = _engine.aura_state()
	var expected_dps := 0.35 * D * 2.0
	_check(is_equal_approx(float(aura_hot[1]), expected_dps), "Thermal Fury doubles the Overclock aura while sustained (%.2f)" % float(aura_hot[1]))
	var hp_at_sustained := float(_player.get("hp"))
	_engine._idle = 999.0
	_engine.tick(1.0)   # cools 25/s -> 95, exits the sustained region
	_check(not _engine._sustained_meltdown and _engine.heat < 100.0, "cooling below 100 leaves sustained Meltdown")
	_check(_near(_engine.heat, 95.0), "Heat cooled 25/s INSIDE sustained Meltdown, the explicit Overclock exception (%s)" % str(_engine.heat))
	_check(float(_player.get("hp")) < hp_at_sustained, "Thermal Fury's 5%% tax lands at the end of the sustained episode")
	_check(is_zero_approx(float(_engine.aura_state()[1])), "below 100 the Overclock aura (and its doubling) is gone")

	# The 180 emergency vent is a Heavy Barrel release (finding 8): one
	# Force spend, the bonus spread over 16 rounds, BRC half-snapshot free.
	ledger.record_purchase("BA01", 100)
	ledger.record_purchase("MR8", 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var bastion := _runner.engine_of_discipline("BA") as BastionEngine
	_check(bastion != null, "the rig owns a Bastion engine for Force")
	if bastion != null:
		bastion.force = 60.0
		_engine._meltdown_lockout_left = 0.0
		_engine._emergency_vent_left = 0.0
		_engine.heat = 0.0
		_engine.add_heat(185.0)
		_check(int(_engine.counters.get("emergency_vents", 0)) == 1, "185 Heat fires the emergency vent")
		_check(is_zero_approx(bastion.force) and is_equal_approx(float(_engine.counters.get("heavy_barrel_force", 0.0)), 60.0), "the vent spends the 60 Force exactly once")
		_check(is_equal_approx(_engine._heavy_barrel_bonus, 0.06 * D * 60.0 * 0.5), "BRC's half-snapshot is banked without a second spend")
		_check(_near(_engine._emergency_vent_left, 0.60) and float(_player.get("_weapon_cd")) >= 0.59 and _engine.jammed(), "the vent blocks native fire for 0.60 s, its own rule")
		# Zero-Force: the vent still fires, nothing is spent.
		_engine.tick(0.7)   # vent recovery, heat rest
		_check(_engine._emergency_vent_left <= 0.0 and is_equal_approx(_engine.heat, 40.0) and _engine._meltdown_lockout_left > 0.0, "after the vent Heat rests at 40 under the 3 s lockout")
		_engine._meltdown_lockout_left = 0.0
		_engine._heavy_barrel_bonus = 0.0
		_engine.heat = 0.0
		_engine.add_heat(185.0)
		_check(int(_engine.counters.get("emergency_vents", 0)) == 2 and is_equal_approx(float(_engine.counters.get("heavy_barrel_force", 0.0)), 60.0), "a zero-Force vent fires without a spend")

	# Overclock acquired DURING an ordinary Meltdown converts the frozen
	# window into the sustained region (the second acceptance route).
	_engine._sustained_meltdown = false
	_engine._meltdown_left = 1.2
	_engine._meltdown_lockout_left = 0.0
	_engine.heat = 100.0
	_engine.tick(0.1)
	_check(_engine._meltdown_left <= 0.0 and _engine._sustained_meltdown, "a mid-Meltdown Overclock purchase converts to sustained instead of freezing")
	_engine._idle = 999.0
	_engine.tick(1.0)

	# --- Foreign Spin Up expires on the clock (finding 9).
	_engine._foreign_stage = 3
	_engine._foreign_last_witness = _engine._clock
	_engine.tick(3.0)
	_check(_engine._foreign_stage == 3, "a fresh foreign stage survives inside the 4 s window")
	_engine.tick(1.5)
	_check(_engine._foreign_stage == 0, "an idle foreign stage expires after 4 s without a Witness")

	# --- A Q-less Hot Core build keeps a persistent readout (finding 10).
	var q_state: Dictionary = _runner.slot_state("q")
	_check(float(q_state.get("resource_max", 0.0)) > 0.0, "the Heat pool reaches the Q readout without a Q equipped")
	_check(_runner._passive_q_readout_exists(), "a passive Hot Core build keeps its slot HUD")

	# --- BR-14: a Melee native's Hot Blood needs a real Hot Core; its Heat comes only from real native inputs and real Witness shots, never from generated strikes, other emitters or health payments, and never a phantom second native attack.
	_player.queue_free()
	await get_tree().process_frame
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee", "v5_ranged")
	ledger = Global.ascension_ledger()
	ledger.record_purchase("EX01", 0)
	ledger.record_purchase("G1", 1600, "ranged")
	for id in ["BR01", "BR02", "BR04", "BR05", "BR07"]:
		ledger.record_purchase(id, 100)
	var bra := ledger.can_buy("BRA", 1000000)
	_check(not bool(bra["ok"]) and String(bra["reason"]).contains("Hot Core"), "five Barrage locals without Hot Core cannot buy Hot Blood (%s)" % String(bra["reason"]))
	ledger.record_purchase("BR03", 400)
	bra = ledger.can_buy("BRA", 1000000)
	_check(bool(bra["ok"]), "owning Hot Core opens Hot Blood to the Melee native (%s)" % String(bra["reason"]))
	ledger.record_purchase("BRA", 2400)
	_check(ledger.effect_active("BRA"), "the Axiom is equipped on purchase")
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine != null and _runner.native_core == "melee" and _engine.claims_heat() and _engine.has("BRA"), "a Melee native with Hot Core and Hot Blood owns the Heat pool")
	if _engine == null:
		_finish()
		return
	var Dm := _runner.native_damage()
	# One real Melee input is one input: +5 Heat, one volley, no phantom second attack.
	_fire(&"melee")
	_check(is_equal_approx(_engine.heat, 5.0) and _engine._volley == 1 and _runner._native_inputs == 1, "one Melee input adds exactly 5 Heat as one input (%s)" % str(_engine.heat))
	# The second input also fires the Gate's Witness shot: a real foreign Core strike with its own +4.
	_fire(&"melee")
	_check(_runner.witness_strikes == 1 and is_equal_approx(_engine.heat, 14.0) and _runner._native_inputs == 2, "a real Witness shot adds its own +4, once (%s)" % str(_engine.heat))
	# Another emitter's weapon signal is not the player's input.
	RunEvents.weapon_fired.emit(self, &"melee", _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)
	_check(is_equal_approx(_engine.heat, 14.0) and _runner._native_inputs == 2 and _engine._volley == 3, "a foreign emitter's attack signal generates no Heat and no input")
	# Up to tier 1: the ninth input carries one 0.4D Hot Blood slash after the native strike.
	for _i in range(6):
		_fire(&"melee")
	_check(_engine.heat >= 50.0 and _engine.tier_index() == 1 and _runner._native_inputs == 8 and _runner.witness_strikes == 4, "eight inputs with four Witness shots reach tier 1 (%s)" % str(_engine.heat))
	# Drain attacks queued by the earlier inputs first, so the only pending
	# attack that can land on the target below is the Hot Blood slash.
	_runner.flush_attacks()
	var pending_before := _runner.pending_attacks().size()
	var blood_before := int(_engine.counters["hot_blood_rounds"])
	_fire(&"melee")
	var pending: Array = _runner.pending_attacks()
	var blood_round: Dictionary = pending[pending.size() - 1] if pending.size() > pending_before else {}
	_check(pending.size() == pending_before + 1 and int(_engine.counters["hot_blood_rounds"]) == blood_before + 1, "the tier-1 input adds exactly one Hot Blood round")
	_check(not blood_round.is_empty() and AscensionTags.value_of(blood_round["tags"], "core") == "melee" and AscensionTags.value_of(blood_round["tags"], "root") == "BRA" and AscensionTags.value_of(blood_round["tags"], "family") == AscensionTags.FAMILY_TREE and is_equal_approx(float(blood_round["damage"]), 0.4 * Dm), "the round is a 0.4D tree slash, not a native attack")
	_check(_runner._native_inputs == 9 and _engine._volley == 9 + _runner.witness_strikes, "nine inputs stay nine: no phantom native attack")
	# The generated slash lands on a real enemy and mints no Heat of its own.
	var heat_before_slash: float = _engine.heat
	var blood_target := _spawn_enemy(400.0, _player.global_position + Vector2(30, 0))
	_runner.flush_attacks()
	_check(_near(400.0 - EnemyWorld.get_health(blood_target), 0.4 * Dm), "the Hot Blood slash hit the enemy for 0.4D (%.3f)" % (400.0 - EnemyWorld.get_health(blood_target)))
	_check(is_equal_approx(_engine.heat, heat_before_slash) and int(_engine.counters["hot_blood_rounds"]) == blood_before + 1 and _runner._native_inputs == 9, "a generated strike mints no Heat, no round and no input")
	# A health payment is not an enemy hit and not an input.
	var hp_before_pay := float(_player.get("hp"))
	var paid := _runner.pay_health(5.0, &"test")
	_check(is_equal_approx(paid, 5.0) and is_equal_approx(float(_player.get("hp")), hp_before_pay - 5.0), "the payment takes exactly what it asked, unmultiplied")
	_check(is_equal_approx(_engine.heat, heat_before_slash) and _runner._native_inputs == 9 and _engine._volley == 9 + _runner.witness_strikes, "a health payment generates no Heat and no input")
	EnemyWorld.remove_enemy(blood_target, &"test")

	_finish()


func _finish() -> void:
	print("AscensionBarrageV5Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
