extends Node

# Precision (Ranged): Read and Weak Points, Far Shot, Penetrator, Second
# Read, Held Breath, Bank Shot, Return Shot, Overpenetrate, Split Line, Dead
# Center, Crossing Fire, Long Game, Deadshot with its mutations, both forks,
# both keystones, Nothing Wasted, Firing Squad, both Evolutions, the sinks
# and JUDGEMENT. Real projectiles fly through the simulation manager.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionPrecisionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _ledger: AscensionLedger
var _spawned: Array[int] = []
var _origin: Vector2


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn(hp: float, at: Vector2, flags: int = 0) -> int:
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_pr", "res://asc_pr.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	ProjectileManager.clear_for_run_end()
	_runner.flush_attacks()


func _load(ids: Array) -> PrecisionEngine:
	_clear_enemies()
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	_ledger = Global.ascension_ledger()
	_ledger.note_segment_completed(9)
	for entry in ids:
		if entry is Array:
			_ledger.record_purchase(String(entry[0]), 1600, String(entry[1]))
		else:
			_ledger.record_purchase(String(entry), 100)
	_runner.q_cooldown_left = 0.0
	_runner._saved_recovery.clear()
	_runner._v_gap_left = 0.0
	_runner.v_charge = 0.0
	_runner.v2_charge = 0.0
	_runner.v_reserve = 0.0
	_runner.v2_reserve = 0.0
	_runner._q_holding = false
	_runner.aim_override = _origin + Vector2(300, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	Engine.time_scale = 1.0
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for entry in ids:
		var id := String(entry[0]) if entry is Array else String(entry)
		var engine := _runner.engine_for(id) as PrecisionEngine
		if engine != null:
			return engine
	return null


func _D() -> float:
	return _runner.native_damage_for("ranged")


func _native(path: String = "bullet") -> PackedStringArray:
	var tags := AscensionTags.native("ranged", path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:native:1")
	return tags


func _core_tags(root: String = "test") -> PackedStringArray:
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, root, "bullet", 1, 1.0, PackedStringArray(["core_strike"]))
	tags.append("cast:native:1")
	return tags


func _profile(damage: float = 10.0) -> HitProfileAdapter:
	var profile := HitProfileAdapter.new()
	profile.reset(damage)
	_runner.apply_to_managed_hit_profile(profile, &"ranged")
	return profile


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
	_runner.flush_attacks()


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	var origin := _origin

	# ---------------- Read and Weak Points
	var pr := _load(["PR01", "PR03"])
	var target := _spawn(200.0, origin + Vector2(60, 0))
	for i in range(3):
		_runner.damage_enemy(target, 10.0, _native())
	_check(pr != null and pr.is_exposed(target) and int(pr.counters["exposed"]) == 1 and is_equal_approx(_runner.enemy_hp(target), 170.0), "three weighted Ranged Core hits expose a Weak Point without consuming it (%.1f)" % _runner.enemy_hp(target))
	_runner.damage_enemy(target, 10.0, _native())
	_check(not pr.is_exposed(target) and int(pr.counters["consumed"]) == 1 and is_equal_approx(_runner.enemy_hp(target), 170.0 - 10.0 - _D()), "the next Ranged Core hit consumes it for +1D (%.1f)" % _runner.enemy_hp(target))
	_runner.damage_enemy(target, 10.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR03", "fragment", 1, 0.5))
	_check(not pr.is_exposed(target), "a payload without core_strike builds no Read")

	# ---------------- Far Shot
	pr = _load(["PR02"])
	var far := _spawn(200.0, origin + Vector2(200, 0))
	var near := _spawn(200.0, origin + Vector2(60, 0))
	_runner.damage_enemy(far, 10.0, _native())
	_runner.damage_enemy(near, 10.0, _native())
	_check(pr.is_exposed(far) and not pr.is_exposed(near) and int(pr.counters["far_shots"]) == 1, "the first Core hit beyond 2R exposes at once")
	_runner.damage_enemy(far, 10.0, _native())
	_check(is_equal_approx(_runner.enemy_hp(far), 200.0 - 20.0 - _D()) and not pr.is_exposed(far), "and the next hit consumes for +1D (%.1f)" % _runner.enemy_hp(far))
	_runner.damage_enemy(far, 10.0, _native())
	_check(not pr.is_exposed(far), "Far Shot exposes each enemy once")

	# ---------------- Penetrator through real projectiles
	pr = _load(["PR01", "PR03"])
	var profile := _profile(10.0)
	_check(profile.pierce == 2 and is_equal_approx(profile.pierce_ramp, 0.2 * _D()) and is_equal_approx(profile.pierce_ramp_cap, _D()), "Penetrator adds two pierce and a 0.2D ramp to native shots")
	var row_a := _spawn(200.0, origin + Vector2(50, 0))
	var row_b := _spawn(200.0, origin + Vector2(90, 0))
	var row_c := _spawn(200.0, origin + Vector2(130, 0))
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, profile, _player)
	await _frames(20)
	_check(is_equal_approx(_runner.enemy_hp(row_a), 190.0) and is_equal_approx(_runner.enemy_hp(row_b), 190.0 - 0.2 * _D()) and is_equal_approx(_runner.enemy_hp(row_c), 190.0 - 0.4 * _D()), "each crossed target adds 0.2D to later hits on the trajectory (%.1f / %.1f / %.1f)" % [_runner.enemy_hp(row_a), _runner.enemy_hp(row_b), _runner.enemy_hp(row_c)])

	# ---------------- Second Read
	pr = _load(["PR01", "PR03", "PR04"])
	var first := _spawn(200.0, origin + Vector2(50, 0))
	var second := _spawn(200.0, origin + Vector2(90, 0))
	_runner.status_of(first)["weak_point"] = 999.0
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, _profile(10.0), _player)
	await _frames(20)
	_check(not pr.is_exposed(first) and pr.is_exposed(second) and int(pr.counters["second_reads"]) == 1, "consuming a Weak Point exposes the next enemy struck by the same projectile")

	# ---------------- Held Breath
	pr = _load(["PR01", "PR05"])
	pr._since_native = 1.0
	profile = _profile(10.0)
	var tags: PackedStringArray = profile.get_meta("asc_tags")
	_check(is_equal_approx(profile.damage, 10.0 + _D()) and AscensionTags.value_of(tags, "pp") == "1.250" and int(pr.counters["aims"]) == 1, "0.8 s without a native input stores Aim: +1D and Proc Power 1.25")
	pr.on_native_fire("ranged", origin, origin + Vector2(100, 0), 1.0, 1.0)
	pr._since_native = 1.0
	pr.on_player_damage_resolved(null, 5.0, 5.0, &"unknown")
	profile = _profile(10.0)
	_check(is_equal_approx(profile.damage, 10.0), "taking damage removes Aim")

	# ---------------- Bank Shot and Cross-Eyed
	pr = _load(["PR01", "PR06"])
	profile = _profile(10.0)
	_check(profile.bounces == 1 and is_equal_approx(profile.bounce_scale, 0.75) and is_equal_approx(profile.bounce_proc_power, 0.7), "Bank Shot: one terrain bounce at 75%% with Proc Power 0.7")
	pr = _load(["PR01", "PR02", "PR03", "PR06", "PRK2"])
	var left_profile := _profile(10.0)
	var right_profile := _profile(10.0)
	_check(is_equal_approx(left_profile.direction_offset_degrees, 20.0) and is_equal_approx(right_profile.direction_offset_degrees, -20.0) and left_profile.bounces == 3 and is_equal_approx(left_profile.bounce_scale, 1.5), "Cross-Eyed alternates 20 degrees and multiplies bounces by 1.5 up to three times")

	# ---------------- Return Shot, Overpenetrate, Long Game
	pr = _load(["PR01", "PR07", "PR12"])
	var struck := _spawn(200.0, origin + Vector2(30, 0))
	var behind := _spawn(3.0, origin - Vector2(20, 0))
	_runner.spawn_bullet(origin, Vector2.RIGHT, 10.0, _core_tags(), {"max_range": 60.0})
	await _frames(30)
	_check(int(pr.counters["returns"]) == 1 and not _runner.enemy_alive(behind), "a Core projectile that exhausts pierce returns along its path for 60%% and can kill")
	_check(pr._spare_rounds == 1, "Long Game stores a spare round from a returning kill")
	var bullets_before := ProjectileManager.active_count()
	pr.on_native_fire("ranged", origin, origin + Vector2(100, 0), 1.0, 1.0)
	_check(int(pr.counters["spares"]) == 1 and pr._spare_rounds == 0 and ProjectileManager.active_count() == bullets_before + 1, "the next native input fires the spare round from the return endpoint")
	pr = _load(["PR01", "PR03", "PR08"])
	var beside := _spawn(200.0, origin + Vector2(60, 20))
	_runner.spawn_bullet(origin, Vector2.RIGHT, 10.0, _core_tags(), {"max_range": 40.0, "pierce": 2})
	await _frames(30)
	_check(int(pr.counters["bursts"]) == 1 and is_equal_approx(_runner.enemy_hp(beside), 200.0 - _D()), "Overpenetrate without Return Shot: unused pierce bursts 1D in R/2 at the endpoint (%.1f)" % _runner.enemy_hp(beside))

	# ---------------- Split Line
	pr = _load(["PR01", "PR03", "PR09"])
	var crossed := _spawn(200.0, origin + Vector2(40, 0))
	var exposed := _spawn(5.0, origin + Vector2(80, 0))
	_runner.status_of(exposed)["weak_point"] = 999.0
	_runner.spawn_bullet(origin, Vector2.RIGHT, 10.0, _core_tags(), {"pierce": 2, "max_range": 200.0})
	await _frames(20)
	_check(not _runner.enemy_alive(exposed) and int(pr.counters["splits"]) == 1, "killing an exposed enemy after crossing another emits two split shots")

	# ---------------- Dead Center and Deadeye
	pr = _load(["PR01", "PR10"])
	var centred := _spawn(200.0, origin + Vector2(100, 0))
	_runner.status_of(centred)["weak_point"] = 999.0
	_runner.q_cooldown_left = 3.0
	pr.on_native_fire("ranged", origin, origin + Vector2(300, 0), 1.0, 1.0)
	_check(is_equal_approx(_runner.q_cooldown_left, 2.75) and int(pr.counters["dead_centers"]) == 1, "a shot aimed through a Weak Point's centre refunds 0.25 s of Q recovery")
	pr = _load(["PR01", "PR02", "PR03", "PR10", "PRF1"])
	centred = _spawn(200.0, origin + Vector2(100, 0))
	_runner.status_of(centred)["weak_point"] = 999.0
	profile = _profile(10.0)
	_check(is_equal_approx(profile.damage, 10.0 + _D()) and profile.pierce == 3, "Deadeye: a manually centred Weak Point shot gains +1D and one pierce")

	# ---------------- Crossing Fire
	pr = _load(["PR01", "PR11"])
	var crossing := _spawn(200.0, origin + Vector2(100, 0))
	_runner.spawn_bullet(origin + Vector2(60, 0), Vector2.RIGHT, 10.0, _core_tags(), {"max_range": 120.0})
	await _frames(6)
	_runner.spawn_bullet(origin + Vector2(100, -40), Vector2.DOWN, 10.0, _core_tags(), {"max_range": 120.0})
	await _frames(20)
	_check(int(pr.counters["crossings"]) == 1 and is_equal_approx(_runner.enemy_hp(crossing), 200.0 - 20.0 - _D()), "two trajectories within 0.5 s add 1D once (%.1f)" % _runner.enemy_hp(crossing))

	# ---------------- Smart Rounds and One Bullet
	pr = _load(["PR01", "PR02", "PR03", "PR06", "PRF2"])
	var marked := _spawn(200.0, origin + Vector2(200, 100))
	_runner.status_of(marked)["weak_point"] = 999.0
	profile = _profile(10.0)
	_check(profile.seek_handle == marked and is_equal_approx(profile.seek_turn_degrees, 30.0) and is_equal_approx(profile.damage, 8.0), "Smart Rounds curve toward an exposed target at 80%% damage")
	_runner.spawn_bullet(origin, Vector2.LEFT, 10.0, _core_tags(), {"max_range": 40.0})
	await _frames(20)
	_check(int(pr.counters["edge_returns"]) == 1, "a miss returns once from the far screen edge")
	pr = _load(["PR01", "PR02", "PR03", "PR07", "PRK1"])
	profile = _profile(10.0)
	_check(is_equal_approx(pr.haste_multiplier("ranged"), 0.5) and is_equal_approx(profile.damage, 30.0) and AscensionTags.value_of(profile.get_meta("asc_tags"), "pp") == "1.250", "One Bullet: interval doubled, main projectile 3D at Proc Power 1.25")

	# ---------------- Nothing Wasted
	pr = _load(["PR01", "PR02", "PR03", "PR07", "PR05", "PRA", ["G1", "melee"], "EX01", "EX02"])
	var swung := _spawn(200.0, origin + Vector2(50, 0))
	pr.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	pr.tick(0.4)
	_runner.flush_attacks()
	_check(int(pr.counters["misses_returned"]) == 1 and _runner.enemy_hp(swung) < 200.0, "a missed Melee strike returns as a 0.8D crossing wave (%.1f)" % _runner.enemy_hp(swung))
	pr.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(swung, 5.0, AscensionTags.with_flag(AscensionTags.native("melee", "slash"), "core_strike"))
	pr.tick(0.4)
	_check(int(pr.counters["misses_returned"]) == 1, "a strike that hit returns nothing")

	# ---------------- Firing Squad
	pr = _load(["PR01", "PR02", "PR03", "PR04", "PR07", "PR09", "PRC"])
	for i in range(4):
		_spawn(500.0, origin + Vector2(150 + 30 * i, 40))
	var sixth := _spawn(500.0, origin + Vector2(60, 0))
	_runner.status_of(sixth)["weak_point"] = 999.0
	pr._cast_consumed["native:1"] = 5
	_runner.damage_enemy(sixth, 10.0, _native())
	_check(int(pr.counters["squads"]) == 1 and int(pr.counters["squad_lines"]) >= 5 and pr._squad_recovery > 0.0, "six Weak Points consumed under one root call six edge guns (%d lines)" % int(pr.counters["squad_lines"]))

	# ---------------- Deadshot
	pr = _load(["PR01", "PR02", "PRQ"])
	var lined := _spawn(500.0, origin + Vector2(200, 0))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and pr.q_active("PRQ") and is_equal_approx(Engine.time_scale, 0.35), "Q slows the world to 35%% while aiming")
	verdict = pr.release_q("PRQ")
	_check(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(_runner.enemy_hp(lined), 500.0 - 4.0 * _D()) and is_equal_approx(float(verdict["cooldown"]), 8.0), "release fires a 4D beam across the screen with an 8 s cooldown (%.1f)" % _runner.enemy_hp(lined))
	pr = _load(["PR01", "PR02", "PRQ", "PRQ1", "PRQ2", "PRQ6"])
	lined = _spawn(500.0, origin + Vector2(200, 0))
	var twin := _spawn(500.0, origin + Vector2(200, AscensionRunner.R))
	verdict = _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(_runner.q_cooldown_left, 5.0) and is_equal_approx(_runner.enemy_hp(lined), 500.0 - 3.0 * _D() * 0.65), "Quick Draw fires at once for 3D with a 5 s cooldown; Twin Shot lines deal 65%% (%.1f)" % _runner.enemy_hp(lined))
	pr.tick(0.16)
	_check(is_equal_approx(_runner.enemy_hp(twin), 500.0 - 3.0 * _D() * 0.65), "the second line follows after 0.15 s from R to the right (%.1f)" % _runner.enemy_hp(twin))
	var low_normal := _spawn(100.0, origin + Vector2(250, 0))
	EnemyWorld.set_health(low_normal, 40.0)
	var low_elite := _spawn(1000.0, origin + Vector2(300, 0), EnemyWorldTypes.Flags.ELITE)
	EnemyWorld.set_health(low_elite, 200.0)
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	_check(not _runner.enemy_alive(low_normal) and int(pr.counters["executions"]) == 1, "Last Round executes a normal left below 25%%")
	_check(is_equal_approx(_runner.enemy_hp(low_elite), 200.0 - 3.0 * _D() * 0.65 - _D()), "and adds +1D against an elite below 25%% (%.1f)" % _runner.enemy_hp(low_elite))
	pr = _load(["PR01", "PR02", "PRQ", "PRQ4", "PRQ5"])
	var fanned := _spawn(500.0, origin + Vector2(200, AscensionRunner.R / 3.0))
	var victim := _spawn(5.0, origin + Vector2(150, 0))
	_runner.activate_q()
	pr.release_q("PRQ")
	_check(is_equal_approx(_runner.enemy_hp(fanned), 500.0 - 4.0 * _D() * 0.35) and int(pr.counters["lines"]) >= 5, "Fan: five parallel lines at 35%% each (%.1f)" % _runner.enemy_hp(fanned))
	_check(not _runner.enemy_alive(victim) and int(pr.counters["recalculates"]) == 1, "Recalculate: a kill by the opening beam fires a 1.5D line from the victim toward aim")

	# ---------------- Evolutions
	pr = _load(["PR01", "PR02", "PR03", "PR04", "PRQ", "PRQ2", "PRQ5", "PRF1", "PRE1"])
	var chain_a := _spawn(5.0, origin + Vector2(150, 0))
	var chain_b := _spawn(5.0, origin + Vector2(200, 0))
	_runner.activate_q()
	_check(not _runner.enemy_alive(chain_a) and not _runner.enemy_alive(chain_b) and int(pr.counters["kill_lines"]) >= 1, "Kill Line redraws a 2D line from each fresh victim toward aim (%d)" % int(pr.counters["kill_lines"]))
	pr = _load(["PR01", "PR02", "PR03", "PRQ", "PRQ2", "PRQ4", "PRF2", "BR06", "PRE2"])
	_spawn(500.0, origin + Vector2(200, 0))
	_runner.activate_q()
	_check(pr._guns.size() == 4, "Smart Grid places four edge guns")
	pr.tick(0.51)
	_check(int(pr.counters["grid_lines"]) == 4, "each gun fires a 1.5D line every 0.5 s")

	# ---------------- sinks
	pr = _load(["PR01", "PR02", "PR03", "PR07", "PRS1", "PRS1", "PRS2", "PRS2", "PRS2", "PRS2"])
	profile = _profile(10.0)
	_check(is_equal_approx(profile.speed, 700.0 * (1.0 + 0.8 * 2.0 / 82.0)) and is_equal_approx(profile.max_range, 520.0 * (1.0 + 0.8 * 2.0 / 82.0)), "Shot Speed rank 2 raises speed and range by 80%% x 2/82")
	_check(is_equal_approx(_runner.q_scale(), 1.0 + 0.01 * 2.0), "Q Damage rank 4 adds 1%% x sqrt(4) to every Q")

	# ---------------- JUDGEMENT
	pr = _load(["PR01", "PR02", "PR03", "PR04", "PR07", "PR09", "PRC", "PRV", "PRV2"])
	var judged := _spawn(5000.0, origin + Vector2(200, 0))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and pr.judgement_left > 1.4 and is_equal_approx(Engine.time_scale, 0.2), "V slows the world to 20%% for up to 1.5 s of plotting")
	pr.place_line(Vector2.RIGHT)
	pr.place_line(Vector2.RIGHT)
	pr.place_line(Vector2.RIGHT)
	pr.tick(0.01)
	_check(is_equal_approx(Engine.time_scale, 1.0) and int(pr.counters["judgement_lines"]) == 3 and is_equal_approx(_runner.enemy_hp(judged), 5000.0 - 3.0 * 5.0 * _D()), "three placed lines fire for 5D each; a target crossed by all three takes every hit (%.1f)" % _runner.enemy_hp(judged))
	pr.tick(0.51)
	_check(is_equal_approx(_runner.enemy_hp(judged), 5000.0 - 3.0 * 5.0 * _D() - 3.0 * 3.0 * _D()), "Back and Forth fires each line again after 0.5 s at 60%% (%.1f)" % _runner.enemy_hp(judged))
	pr = _load(["PR01", "PR02", "PR03", "PR04", "PR07", "PR09", "PRC", "PRV", "PRV1"])
	judged = _spawn(5000.0, origin + Vector2(200, 0))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	_check(pr._judgement_lines.size() >= 1 and is_equal_approx(Engine.time_scale, 1.0), "Auto-Plot picks lines itself without a pause")
	pr.tick(0.41)
	_check(int(pr.counters["judgement_lines"]) >= 1 and _runner.enemy_hp(judged) < 5000.0, "and fires after a 0.4 s tell")
	pr = _load(["PR01", "PR02", "PR03", "PR04", "PR07", "PR09", "PRC", "PRV", "PRV3", "PRV2"])
	judged = _spawn(5000.0, origin + Vector2(200, 0))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	for i in range(5):
		pr.tick(0.3)
	_check(int(pr.counters["sweep_ticks"]) == 5 and is_equal_approx(_runner.enemy_hp(judged), 5000.0 - 5.0 * 3.0 * _D()), "One Line sweeps for 3D every 0.3 s, at most five hits per target (%.1f)" % _runner.enemy_hp(judged))
	for i in range(3):
		pr.tick(0.3)
	_check(int(pr.counters["sweep_ticks"]) >= 7 and _runner.enemy_hp(judged) < 5000.0 - 5.0 * 3.0 * _D(), "Back and Forth adds a 0.75 s reverse sweep at half damage (%.1f)" % _runner.enemy_hp(judged))

	Engine.time_scale = 1.0
	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionPrecisionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
