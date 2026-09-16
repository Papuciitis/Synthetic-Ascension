extends Node

# Momentum (Melee): the claimed pool, Stride, Passing Blade and Prime, Kill
# Reset, Afterimage, Turn, Ram, Running Cut, Slipstream, Long Step, Shock
# Front, Trail, Thousand Cuts, Lunge with its mutations, both forks, both
# keystones, Moving Fire, Blade Storm, both Evolutions, the sinks and BLINK.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionMomentumTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const CORE: Array = ["MO01", "MO02", "MO03", "MO04", "MO05", "MO06", "MO07", "MO08", "MO09", "MO10", "MO11", "MO12"]

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _ledger: AscensionLedger
var _spawned: Array[int] = []


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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_mo", "res://asc_mo.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	_runner.flush_attacks()


func _load(ids: Array) -> MomentumEngine:
	_clear_enemies()
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
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
	_runner._dash_active = false
	_player.get("_dash").cancel()
	_player.get("_dash").cooldown_left = 0.0
	_player.global_position = _origin
	_runner.aim_override = Vector2.INF
	_runner.travel_this_frame = 0.0
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	var state: Object = _runner.manifestation_state()
	if state != null:
		state.set("momentum", 0.0)
		state.set("momentum_hold_seconds", 0.0)
	return _runner.engine_for("MO01") as MomentumEngine


func _D() -> float:
	return _runner.native_damage()


var _origin: Vector2


func _native(path: String = "slash") -> PackedStringArray:
	var tags := AscensionTags.native("melee", path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:native:1")
	return tags


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	var origin := _origin

	# ---------------- the pool and Stride
	var mo := _load(["MO01", "MO02"])
	var state: Object = _runner.manifestation_state()
	_check(mo != null and mo.claimed_nouns() == [&"momentum"] and bool(state.call("has_source", &"momentum")), "Stride claims the existing Momentum noun")
	mo.add_momentum(50.0)
	_check(is_equal_approx(mo.momentum(), 50.0) and is_equal_approx(mo.arc_multiplier(), 1.2), "50 Momentum widens native arcs by 20%% (%.1f)" % mo.momentum())
	mo.add_momentum(80.0)
	_check(is_equal_approx(mo.momentum(), 100.0) and is_equal_approx(mo.arc_multiplier(), 1.4), "the pool caps at 100 without No Brakes and Stride gives 40%%")
	_check(is_equal_approx(_runner.get_arc_multiplier(), 1.4), "the runner reads the width through get_arc_multiplier")
	mo.spend_momentum(30.0)
	_check(is_equal_approx(mo.momentum(), 70.0), "spending takes from the pool (%.1f)" % mo.momentum())

	# ---------------- Passing Blade, Prime, Kill Reset
	mo = _load(["MO01", "MO02", "MO03"])
	var crossed := _spawn(100.0, origin + Vector2(80, 0))
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(is_equal_approx(_runner.enemy_hp(crossed), 100.0 - 0.6 * _D()) and _runner.has_status(crossed, "prime"), "a dash cuts 0.6D along its strip and Primes (%.1f)" % _runner.enemy_hp(crossed))
	_runner.damage_enemy(crossed, 10.0, _native())
	_check(is_equal_approx(_runner.enemy_hp(crossed), 100.0 - 0.6 * _D() - 10.0 - 0.5 * _D()) and not _runner.has_status(crossed, "prime"), "the next Melee Core hit consumes Prime for +0.5D (%.1f)" % _runner.enemy_hp(crossed))
	_player.get("_dash").cooldown_left = 1.0
	_runner.damage_enemy(crossed, 500.0, _native())
	_check(not _runner.enemy_alive(crossed) and is_equal_approx(_player.get("_dash").cooldown_left, 0.85), "Kill Reset returns 0.15 s of dash recovery on a Melee kill (%.2f)" % _player.get("_dash").cooldown_left)

	# ---------------- Afterimage
	mo = _load(["MO01", "MO04"])
	mo.add_momentum(60.0)
	var behind := _spawn(100.0, origin + Vector2(40, 0))
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(mo.counters["afterimages"]) == 1, "at 60 Momentum a Melee Core strike queues an Afterimage")
	mo.tick(0.2)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(behind), 100.0), "the repeat waits 0.3 s")
	mo.tick(0.15)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(behind), 100.0 - 0.6 * _D()), "then swings from the original position for 0.6D (%.1f)" % _runner.enemy_hp(behind))
	mo.spend_all_momentum()
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(mo.counters["afterimages"]) == 1, "below 60 Momentum no Afterimage forms")

	# ---------------- Turn
	mo = _load(["MO01", "MO05"])
	mo._heading = Vector2.RIGHT
	mo._turn_credit = AscensionRunner.L
	_runner.travel_this_frame = 6.0
	_runner._last_player_position = origin - Vector2(0, 6)
	mo._track_heading()
	_check(mo._turn_armed, "after travelling L, a 90-degree turn arms Turn")
	var left := _spawn(100.0, origin + Vector2(60, -60))
	var right := _spawn(100.0, origin + Vector2(60, 60))
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.flush_attacks()
	_check(int(mo.counters["turns"]) == 1 and is_equal_approx(_runner.enemy_hp(left), 100.0 - 0.5 * _D()) and is_equal_approx(_runner.enemy_hp(right), 100.0 - 0.5 * _D()) and not mo._turn_armed, "the next attack adds two crossing 0.5D slashes over 2R (%.1f / %.1f)" % [_runner.enemy_hp(left), _runner.enemy_hp(right)])
	_runner.travel_this_frame = 0.0

	# ---------------- Ram
	mo = _load(["MO01", "MO02", "MO06"])
	var primed := _spawn(100.0, origin + Vector2(80, 0))
	_runner.status_of(primed)["prime"] = 999.0
	var wall := _spawn(100.0, origin + Vector2(200, 0))
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(mo.counters["rams"]) == 1 and _runner.enemy_position(primed).distance_to(origin + Vector2(172, 0)) < 1.0, "a Primed normal is carried to the dash endpoint (%s)" % str(_runner.enemy_position(primed)))
	_check(is_equal_approx(_runner.enemy_hp(primed), 100.0 - 0.6 * _D() - 0.8 * _D()) and is_equal_approx(_runner.enemy_hp(wall), 100.0 - 0.8 * _D()), "the collision deals 0.8D to the carried enemy and the struck one (%.1f / %.1f)" % [_runner.enemy_hp(primed), _runner.enemy_hp(wall)])

	# ---------------- Running Cut
	mo = _load(["MO01", "MO07"])
	_player.set("_weapon_cd", 0.5)
	mo._travel_since_input = AscensionRunner.L
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(is_equal_approx(_player.native_recovery_left(), 0.3) and int(mo.counters["running_cuts"]) == 1, "travelling L between inputs cuts the next recovery by 40%% (%.2f)" % _player.native_recovery_left())
	_player.set("_weapon_cd", 0.5)
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(is_equal_approx(_player.native_recovery_left(), 0.5), "the distance is consumed by that attack")

	# ---------------- Slipstream
	mo = _load(["MO01", "MO08"])
	_runner.travel_this_frame = 6.0
	mo._heading = Vector2.RIGHT
	for i in range(3):
		var prey := _spawn(5.0, origin + Vector2(60, 0))
		_runner.damage_enemy(prey, 50.0, _native())
	_check(int(mo.counters["slipstreams"]) == 1 and float(state.get("momentum_hold_seconds")) >= 2.0 and not mo._lane.is_empty(), "three kills while moving pause decay 2 s and leave a lane")
	_check(is_equal_approx(mo.move_speed_multiplier(), 1.2), "inside the lane movement is 20%% faster")
	_runner.travel_this_frame = 0.0

	# ---------------- Long Step
	mo = _load(["MO01", "MO02", "MO09"])
	mo.add_momentum(60.0)
	Input.action_press(&"dash")
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	Input.action_release(&"dash")
	_check(int(mo.counters["long_steps"]) == 1 and is_equal_approx(mo.momentum(), 20.0) and _player.is_dashing() and is_equal_approx(float(_player.get("invulnerable_time")), 0.0), "holding dash extends it another L for 40 Momentum without invulnerability (%.1f)" % mo.momentum())
	_player.get("_dash").cancel()
	_runner._dash_active = false
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(mo.counters["long_steps"]) == 1, "without the key held the dash ends normally")

	# ---------------- Shock Front and Trail
	mo = _load(["MO01", "MO02", "MO10", "MO11"])
	mo.add_momentum(75.0)
	for i in range(8):
		_spawn(100.0, origin + Vector2(20 + 16 * i, 0))
	var flank := _spawn(100.0, origin + Vector2(160, 120))
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(int(mo.counters["shock_fronts"]) == 1 and is_equal_approx(_runner.enemy_hp(flank), 100.0 - 2.0 * _D()), "crossing eight enemies emits two 2D outward waves (%.1f)" % _runner.enemy_hp(flank))
	_check(int(mo.counters["trails"]) == 1, "at 75 Momentum the dash leaves a Trail")
	var on_path := _spawned[0]
	var hp_after_strip := _runner.enemy_hp(on_path)
	mo.tick(0.5)
	_check(is_equal_approx(_runner.enemy_hp(on_path), hp_after_strip - 0.4 * _D()), "the Trail ticks 0.4D every 0.5 s (%.1f)" % _runner.enemy_hp(on_path))
	mo.tick(1.1)
	_check(mo._strips.is_empty(), "and expires after 1.5 s")

	# ---------------- Thousand Cuts
	mo = _load(["MO01", "MO02", "MO04", "MO12"])
	mo.add_momentum(80.0)
	var c1 := _spawn(100.0, origin + Vector2(40, 0))
	var c2 := _spawn(100.0, origin + Vector2(80, 0))
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	for i in range(3):
		mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(mo.counters["thousand_cuts"]) == 1 and int(mo.counters["afterimages"]) == 5, "every third strike at 75+ leaves Afterimages on the last crossed enemies (%d)" % int(mo.counters["afterimages"]))
	_check(c1 != c2, "two crossed targets remembered")

	# ---------------- Lunge and its mutations
	mo = _load(["MO01", "MO02", "MOQ"])
	_runner.aim_override = origin + Vector2(400, 0)
	var far := _spawn(100.0, origin + Vector2(270, 0))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and verdict["message"] == "LUNGE" and _player.is_dashing() and mo.q_active("MOQ"), "Q lunges toward the aim")
	mo.on_dash_ended(origin, origin + Vector2(240, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(int(mo.counters["lunge_strikes"]) == 1 and is_equal_approx(_runner.enemy_hp(far), 100.0 - 2.0 * _D()) and not mo.q_active("MOQ"), "the endpoint semicircle deals 2D (%.1f)" % _runner.enemy_hp(far))
	_check(is_equal_approx(_runner.q_cooldown_left, 5.0), "Lunge recovers over 5 s (%.1f)" % _runner.q_cooldown_left)
	_player.get("_dash").cancel()
	mo = _load(["MO01", "MO02", "MOQ", "MOQ1", "MOQ4", "MOQ3"])
	_runner.aim_override = origin + Vector2(400, 0)
	var elite := _spawn(500.0, origin + Vector2(270, 0), EnemyWorldTypes.Flags.ELITE)
	var weak := _spawn(5.0, origin + Vector2(250, 20))
	_runner.activate_q()
	_check(int(mo.counters["afterimages"]) == 1, "Shadow Step leaves an Afterimage at the start")
	mo.on_dash_ended(origin, origin + Vector2(240, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(int(mo.counters["forks"]) == 1, "Fork: an elite hit by Lunge sends two waves")
	_check(not _runner.enemy_alive(weak) and mo._rebound_left > 0.0, "Rebound: the first Lunge kill grants a free return within 2 s")
	_player.get("_dash").cancel()
	_runner._dash_active = false
	_runner.q_cooldown_left = 0.0
	verdict = _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(_runner.q_cooldown_left, 0.0) and int(mo.counters["rebounds"]) == 1, "the return costs no cooldown")
	_player.get("_dash").cancel()
	_runner._dash_active = false
	mo._lunge_active = false
	_check(elite != 0, "elite present")
	mo = _load(["MO01", "MO02", "MOQ", "MOQ2", "MOQ5", "MOQ6"])
	_runner.aim_override = origin + Vector2(900, 0)
	var dragged := _spawn(100.0, origin + Vector2(100, 0))
	_runner.activate_q()
	mo.on_dash_ended(origin, origin + Vector2(720, 0), Vector2.RIGHT)
	_check(int(mo.counters["carries"]) == 1 and _runner.enemy_position(dragged).x > origin.x + 700.0, "Carry drags one crossed normal to the endpoint (%s)" % str(_runner.enemy_position(dragged)))
	_check(mo._strips.size() == 1 and String(mo._strips[0]["root"]) == "MOQ2", "Wake leaves a 2 s strip behind the Lunge")
	_player.get("_dash").cancel()
	_runner._dash_active = false

	# ---------------- forks: Keep Moving and Burnout
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOQ", "MOF1"])
	mo.add_momentum(40.0)
	var kept := _spawn(5.0, origin + Vector2(60, 0))
	_runner.damage_enemy(kept, 50.0, _native())
	_check(float(state.get("momentum_hold_seconds")) >= 3.0, "Keep Moving: kills pause decay for 3 s")
	mo.tick(0.6)
	_check(is_equal_approx(float(_ledger.state.get("momentum_carry", 0.0)), 40.0), "Momentum is stored for the next segment (%.1f)" % float(_ledger.state.get("momentum_carry", 0.0)))
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOQ", "MOF2"])
	mo.add_momentum(100.0)
	_runner.aim_override = origin + Vector2(400, 0)
	var burned := _spawn(500.0, origin + Vector2(270, 0))
	_runner.activate_q()
	_check(is_equal_approx(mo.momentum(), 15.0), "Burnout: Lunge spends all Momentum, then counts as a dash for +15 (%.1f)" % mo.momentum())
	mo.on_dash_ended(origin, origin + Vector2(240, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(burned), 500.0 - 2.0 * _D() * 2.5), "a full pool gives +150%% damage (%.1f)" % _runner.enemy_hp(burned))
	_player.get("_dash").cancel()
	_runner._dash_active = false

	# ---------------- keystones
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOK1"])
	_check(is_equal_approx(mo.haste_multiplier("melee"), 1.0 / 1.4), "Never Stop: at zero Momentum attack recovery is 40%% longer")
	_player.get("_dash").cooldown_left = 1.6
	mo.on_player_dashed(origin, Vector2.RIGHT)
	_check(is_equal_approx(_player.get("_dash").cooldown_left, 0.0) and not mo._extra_dash_ready, "the second dash charge makes the next dash immediately available")
	mo.add_momentum(50.0)
	_player.get("_dash").cooldown_left = 1.6
	mo.on_player_dashed(origin, Vector2.RIGHT)
	_check(is_equal_approx(_player.get("_dash").cooldown_left, 1.2), "at 50+ Momentum dash recovery is 25%% shorter (%.2f)" % _player.get("_dash").cooldown_left)
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOK2"])
	mo.add_momentum(150.0)
	_check(is_equal_approx(mo.momentum(), 150.0) and is_equal_approx(mo.move_speed_multiplier(), 1.35) and is_equal_approx(mo.haste_multiplier("melee"), 1.35), "No Brakes: Momentum reaches 150 and grants up to 35%% speed (%.1f)" % mo.momentum())
	mo.spend_momentum(75.0)
	_check(is_equal_approx(mo.momentum(), 75.0), "spending drains the overflow first, then the pool (%.1f)" % mo.momentum())

	# ---------------- Moving Fire
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MO05", "MOA", ["G1", "ranged"], "BR01", "BR02"])
	_runner.travel_this_frame = 6.0
	mo.add_momentum(20.0)
	var shot := _spawn(100.0, origin + Vector2(60, 0))
	mo.on_native_fire("ranged", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(is_equal_approx(mo.momentum(), 8.0), "Moving Fire: a Ranged strike while moving adds 8 and spends 20 (%.1f)" % mo.momentum())
	var ranged_tags := AscensionTags.native("ranged", "bullet")
	ranged_tags = AscensionTags.with_flag(ranged_tags, "core_strike")
	_runner.damage_enemy(shot, 10.0, ranged_tags)
	_check(is_equal_approx(_runner.enemy_hp(shot), 100.0 - 10.0 - 0.5 * _D()), "its first payload gains +0.5D (%.1f)" % _runner.enemy_hp(shot))
	_runner.damage_enemy(shot, 10.0, ranged_tags)
	_check(is_equal_approx(_runner.enemy_hp(shot), 100.0 - 20.0 - 0.5 * _D()), "only once per strike")
	_runner.travel_this_frame = 0.0

	# ---------------- Blade Storm
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MO05", "MO12", "MOC"])
	mo.add_momentum(100.0)
	for i in range(6):
		_spawn(100.0, origin + Vector2(60 + 30 * i, 0))
	for i in range(6):
		mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(mo.counters["blade_storms"]) == 1 and mo._cutters.size() == 6, "six Afterimages within 4 s release Blade Storm with six cutters (%d)" % mo._cutters.size())
	mo.tick(0.8)
	_runner.flush_attacks()
	_check(int(mo.counters["cutter_cuts"]) == 6 and _runner.enemy_hp(_spawned[0]) < 100.0, "each cutter makes 1D line cuts every 0.75 s")
	_check(mo._storm_recovery > 0.0, "Blade Storm recovers over 8 s")

	# ---------------- Evolutions
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOQ", "MOF1", "MOQ1", "MOE1"])
	_runner.aim_override = origin + Vector2(400, 0)
	var chain_a := _spawn(5.0, origin + Vector2(250, 0))
	_runner.activate_q()
	mo.on_dash_ended(origin, origin + Vector2(240, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(not _runner.enemy_alive(chain_a) and mo._endless_left > 0.0 and mo._return_count == 1, "Endless Lunge: a fresh Lunge kill grants another Lunge within 2 s")
	_player.get("_dash").cancel()
	_runner._dash_active = false
	mo._lunge_active = false
	mo._return_count = 6
	mo._endless_left = 0.01
	mo.tick(0.02)
	_check(int(mo.counters["blade_storms"]) == 1, "six successful returns release Blade Storm even without MOC")
	mo = _load(["MO01", "MO02", "MO03", "MO10", "MOQ", "MOF2", "MOQ6", "MOE2"])
	mo.add_momentum(100.0)
	_runner.aim_override = origin + Vector2(1200, 0)
	var crash_target := _spawn(1000.0, origin + Vector2(1020, 0))
	_runner.activate_q()
	_check(is_equal_approx(mo._crash_spent, 100.0), "Crash Run spends all Momentum")
	mo.on_dash_ended(origin, origin + Vector2(960, 0), Vector2.RIGHT)
	_runner.flush_attacks()
	_check(int(mo.counters["crash_fronts"]) == 4 and is_equal_approx(_runner.enemy_hp(crash_target), 1000.0 - 3.0 * _D() * 2.5), "the endpoint deals 3D with the Burnout bonus and four Shock Fronts (%.1f)" % _runner.enemy_hp(crash_target))
	_player.get("_dash").cancel()
	_runner._dash_active = false

	# ---------------- sinks
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MOS1", "MOS1", "MOS1", "MOS2", "MOS2"])
	_check(is_equal_approx(mo.move_speed_multiplier(), 1.0 + 0.45 * 3.0 / 63.0), "Run Speed rank 3 gives 45%% x 3/63")
	_check(is_equal_approx(mo.arc_multiplier(), 1.0 + 0.6 * 2.0 / 82.0), "Slash Width rank 2 gives 60%% x 2/82")

	# ---------------- BLINK
	mo = _load(["MO01", "MO02", "MO03", "MO04", "MO05", "MO12", "MOC", "MOV", "MOV1", "MOV2", "MOV3"])
	var b1 := _spawn(100.0, origin + Vector2(200, 0))
	var b2 := _spawn(100.0, origin + Vector2(-200, 0))
	_runner.aim_override = origin + Vector2(300, 0)
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	mo.blink_forced = true
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and mo.blink_left > 3.9, "V starts BLINK for 4 s")
	mo.tick(0.16)
	_runner.flush_attacks()
	_check(int(mo.counters["landings"]) == 1 and _player.global_position.distance_to(_runner.enemy_position(b1)) < 30.0, "each 0.15 s the player lands beside a visible enemy (%s)" % str(_player.global_position))
	_check(_runner.enemy_hp(b1) < 100.0 - 1.9 * _D() and int(mo.counters["ghosts"]) == 1 and _runner.enemy_hp(b2) < 100.0, "the landing strikes for 2D and All of Them ghost-slashes another normal (%.1f / %.1f)" % [_runner.enemy_hp(b1), _runner.enemy_hp(b2)])
	mo.tick(0.16)
	_runner.flush_attacks()
	_check(int(mo.counters["landings"]) == 1, "a normal is visited once")
	mo.tick(4.0)
	_check(mo.blink_left <= 0.0 and not mo._retrace.is_empty(), "after the chain, Back Again queues the retrace")
	mo.tick(0.11)
	_runner.flush_attacks()
	_check(int(mo.counters["retraces"]) == 1, "and retraces the landings at 0.1 s")
	_check(int(mo.counters["afterimages"]) == 0 and mo._delayed.size() >= 0, "Don't Blink's Shadow Steps ride the delayed queue, not the Afterimage count")
	mo.blink_forced = false
	_player.global_position = origin

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionMomentumTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
