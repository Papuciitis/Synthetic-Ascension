extends Node

# Shared V4 rules on the runner: a swapped Q keeps the greater remaining
# recovery; Revelation starts are 1.5 s apart and Ascendant's hold casts both;
# kill charge is uncapped while discipline action charge sums to four a
# second; Overflow banks reserve; Evolution claims arrive after segments 6, 9
# and every third; the milestone picks change Q casts (Hands On, Patient,
# Automatic, Momentum refund, Commitment, Encore); the Reaction Q obeys its
# chosen trigger, including the first elite inside 2R.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionSharedRulesTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _ledger: AscensionLedger


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_shared", "res://asc_shared.tscn", at, hp, 10.0, 8.0, 0, flags))


func _load(native: String, ids: Array) -> void:
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
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
	_runner.refresh()
	_runner.q_cooldown_left = 0.0


func _fire(style: String) -> void:
	RunEvents.weapon_fired.emit(_player, StringName(style), _player.global_position, _player.global_position + Vector2(100, 0), 1.0, 1.0)


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	var origin := _player.global_position

	# --- Luck bends named rolls by at most five points (T3)
	Global.run_luck = 100.0
	_runner.roll(&"luck_probe", 0.5)
	var lucky: float = _runner.last_roll_chance
	Global.run_luck = -100.0
	_runner.roll(&"luck_probe", 0.5)
	var jinxed: float = _runner.last_roll_chance
	Global.run_luck = 0.0
	_runner.roll(&"luck_probe", 0.5)
	_check(lucky > 0.545 and lucky < 0.551 and jinxed > 0.449 and jinxed < 0.455 and is_equal_approx(_runner.last_roll_chance, 0.5), "a 50%% roll reads 55%% at +100 Luck, 45%% at -100, 50%% at zero (%.3f / %.3f)" % [lucky, jinxed])
	_check(is_equal_approx(_player.clamp_shot_haste(4.0), 2.5) and is_equal_approx(_player.clamp_shot_haste(1.8), 1.8), "the shot haste multiplier caps at x2.5 (T4)")

	# --- Q swap keeps the greater remaining recovery
	_load("melee", ["EX01", "EX02", "EXQ", ["G1", "ranged"], "BR01", "BRQ"])
	_runner.aim_override = origin + Vector2(80, 0)
	_runner.activate_q()
	_check(_runner.q_cooldown_left > 6.0, "Gavel starts its 7 s recovery")
	_ledger.equip("q", "BRQ")
	_runner.refresh()
	_check(_runner.q_id == "BRQ" and _runner.q_cooldown_left > 6.0, "swapping to Burst keeps Gavel's remaining recovery (%.1f)" % _runner.q_cooldown_left)
	_runner.q_cooldown_left = 1.0
	_ledger.equip("q", "EXQ")
	_runner.refresh()
	_check(_runner.q_id == "EXQ" and _runner.q_cooldown_left > 5.0, "swapping back restores Gavel's own saved recovery (%.1f)" % _runner.q_cooldown_left)

	# --- charge: kills uncapped, actions capped at four a second, Overflow reserve
	_load("ranged", ["BR01", "BR02", "BRQ", "BRK1", "BRV"])
	var barrage := _runner.engine_for("BR01") as BarrageEngine
	_runner.v_charge = 0.0
	for i in range(6):
		var fodder := _spawn(1.0, origin + Vector2(60 + float(i) * 10.0, 0))
		_runner.damage_enemy(fodder, 10.0, AscensionTags.native("ranged", "bullet"))
	_check(is_equal_approx(_runner.v_charge, 3.0), "six normal kills in one frame all charge (no rate ceiling on kills): %.1f" % _runner.v_charge)
	_runner.v_charge = 0.0
	for _i in range(10):
		_runner.add_action_charge(1.0)
	_check(is_equal_approx(_runner.v_charge, 4.0), "action charge sums to at most four a second (%.1f)" % _runner.v_charge)
	_runner._process(1.05)
	_runner.add_action_charge(1.0)
	_check(is_equal_approx(_runner.v_charge, 5.0), "the action window resets each second")
	_runner.v_charge = 0.0
	barrage.heat = 49.0
	_fire("ranged")
	_check(is_equal_approx(_runner.v_charge, 1.0), "crossing 50 Heat grants one action charge")
	_ledger.record_purchase("pick.P2", 0)
	_runner.refresh()
	_runner._process(1.05)
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.add_action_charge(3.0)
	_check(is_equal_approx(_runner.v_reserve, 3.0), "Overflow banks charge past a full meter as reserve")
	_runner.activate_v()
	_check(is_equal_approx(_runner.v_charge, 3.0) and is_equal_approx(_runner.v_reserve, 0.0), "casting moves the reserve into the meter")
	barrage.suppression_left = 0.0
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	var verdict := _runner.activate_v()
	_check(not bool(verdict["ok"]) and verdict["message"] == "TOO SOON", "a second Revelation within 1.5 s is refused")
	_runner._process(1.6)
	barrage.suppression_left = 0.0
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]), "after the gap it casts")
	barrage.suppression_left = 0.0

	# --- Ascendant hold casts both, selected first, 0.25 s apart
	var tools := get_node_or_null("/root/DevSetCollisionTools")
	if tools != null:
		tools.call("apply_ascension_route", "Three-Core avalanche", true)
		_runner.refresh()
		_ledger = Global.ascension_ledger()
		var first_v := _runner.v_id
		var second_v := _runner.v2_id
		_check(not first_v.is_empty() and not second_v.is_empty(), "two Revelations are equipped at Ascendant (%s, %s)" % [first_v, second_v])
		_runner._process(2.0)
		_runner.v_charge = AscensionRunner.V_CHARGE_MAX
		_runner.v2_charge = 40.0
		verdict = _runner.activate_v_pair()
		_check(not bool(verdict["ok"]) and verdict["message"] == "PAIR NOT READY", "a pair needs both meters full; the first is not spent")
		_check(is_equal_approx(_runner.v_charge, AscensionRunner.V_CHARGE_MAX), "the meter is untouched by a refused pair")
		_runner.v_charge = 0.0
		_runner.v2_charge = 0.0
		for i in range(4):
			var body := _spawn(1.0, origin + Vector2(60 + float(i) * 10.0, 0))
			_runner.damage_enemy(body, 10.0, AscensionTags.native("melee", "slash"))
		_check(is_equal_approx(_runner.v_charge, 2.0) and is_equal_approx(_runner.v2_charge, 2.0), "kills charge both equipped meters")
		_runner.v_charge = AscensionRunner.V_CHARGE_MAX
		_runner.v2_charge = AscensionRunner.V_CHARGE_MAX
		var before_casts := int(_runner.telemetry["revelations"])
		verdict = _runner.activate_v_pair()
		_check(bool(verdict["ok"]) and int(_runner.telemetry["revelations"]) == before_casts + 1, "the pair casts the selected Revelation at once")
		_runner._process(0.3)
		_check(int(_runner.telemetry["revelations"]) == before_casts + 2, "and the second 0.25 s later")

	# --- Evolution claims after segments 6, 9, 12
	_load("melee", ["EX01"])
	var was_segment: int = Global.attempt_segment
	var was_active: bool = Global.attempt_active
	Global.attempt_active = true
	var claims: Array[int] = []
	for segment in [5, 6, 7, 9, 11, 12]:
		Global.on_segment_completed(segment)
		claims.append(int(Global.attempt_ascension["evolution_claims"]))
	_check(claims == [0, 1, 1, 2, 2, 3], "claims arrive after segments 6, 9 and 12 (%s)" % str(claims))
	Global.attempt_segment = was_segment
	Global.attempt_active = was_active
	Global.pending_big_choice = false
	Global.pending_augment_pick = false

	# --- milestone picks on Q casts
	_load("melee", ["EX01", "EX02", "EXQ", "pick.M1"])
	var execution := _runner.engine_for("EX01") as ExecutionEngine
	_runner.aim_override = origin + Vector2(80, 0)
	_runner.activate_q()
	var D := _runner.native_damage()
	_check(is_equal_approx(execution._gavel_damage(), 3.0 * D * 1.2), "Hands On: a manual Gavel deals +20%% (%s of %s)" % [str(execution._gavel_damage()), str(3.0 * D)])
	_load("melee", ["EX01", "EX02", "EXQ", "pick.M3"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	_runner._process(2.5)
	_runner.activate_q()
	D = _runner.native_damage()
	_check(is_equal_approx(execution._gavel_damage(), 3.0 * D * 1.3) and is_equal_approx(execution._gavel_radius(), 1.25 * AscensionRunner.R * 1.3), "Patient: after two idle seconds the Gavel gains +30%% damage and area")
	_load("melee", ["EX01", "EX02", "EXQ", "pick.M2"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	var wounded := _spawn(100.0, origin + Vector2(120, 0))
	_runner.damage_enemy(wounded, 85.0, AscensionTags.native("melee", "slash"))
	_runner._process(0.1)
	D = _runner.native_damage()
	_check(int(execution.counters["gavels"]) == 1 and is_equal_approx(execution._gavel_damage(), 3.0 * D * 0.7), "Automatic: the ready Gavel casts itself at 70%% (%d casts, %s)" % [int(execution.counters["gavels"]), str(execution._gavel_damage())])
	_check(execution._gavel_point.distance_to(_runner.enemy_position(wounded)) < 1.0, "the automatic Gavel targets the nearest wounded normal")
	EnemyWorld.remove_enemy(wounded, &"test")
	_load("melee", ["EX01", "EX02", "EXQ", "pick.D1"])
	_runner.aim_override = origin + Vector2(80, 0)
	_runner.activate_q()
	var left_before := _runner.q_cooldown_left
	_runner._travel_since_refund = AscensionRunner.L
	for _i in range(3):
		_fire("melee")
	_check(is_equal_approx(_runner.q_cooldown_left, left_before - 0.5), "Momentum pick: the third native input after L of travel refunds 0.5 s")
	_load("melee", ["EX01", "EX02", "EX03", "EX04", "EXK1", "pick.D3"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	_check(is_equal_approx(execution.line(), 0.10 + 0.12 * 1.25), "Commitment: a lone Keystone's +12 points become +15 (%s)" % str(execution.line()))
	_load("melee", ["EX01", "EX02", "EXQ", "EXV", "pick.P1"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	_runner._process(0.5)
	_runner.aim_override = origin + Vector2(80, 0)
	_runner.activate_q()
	_check(int(execution.counters["gavels"]) == 1, "the opening Gavel after DECIMATION casts")
	_runner._process(0.45)
	D = _runner.native_damage()
	_check(int(execution.counters["gavels"]) == 2 and is_equal_approx(execution._gavel_damage(), 3.0 * D * 0.5), "Encore repeats it once after 0.4 s at 50%% (%d casts)" % int(execution.counters["gavels"]))

	# A held Q must finish before its repeat starts. The repeated guard has
	# no held input, so it must end itself, keep its half-strength wave and
	# leave the original recovery running rather than restarting it.
	_load("melee", ["BA01", "BAQ", "pick.P1"])
	var bastion := _runner.engine_for("BAQ") as BastionEngine
	_runner.note_revelation_ended("BAV")
	_runner.activate_q()
	_runner._q_holding = true
	_runner._cast_encore()
	_check(int(bastion.counters["guards"]) == 1 and bastion.guarding, "Encore waits for the player's original held Guard to finish")
	bastion.release_q("BAQ")
	_runner._q_holding = false
	_runner.flush_attacks()
	_runner.q_cooldown_left = 2.25
	_runner.q_cooldown_max = 4.0
	var guard_target := _spawn(1000.0, origin + Vector2(60, 0))
	_runner._cast_encore()
	_check(bastion.guarding, "Encore starts a fresh finite Guard after the manual release")
	bastion.tick(0.76)
	_runner.flush_attacks()
	_check(not bastion.guarding and int(bastion.counters["guard_waves"]) == 2, "the repeated Guard releases without a second key press")
	_check(is_equal_approx(_runner.enemy_hp(guard_target), 1000.0 - 0.5 * _runner.native_damage()), "the delayed Encore guard wave retains its 50 percent payload")
	_check(is_equal_approx(_runner.q_cooldown_left, 2.25), "Encore's delayed release never restarts the original Guard recovery")
	EnemyWorld.remove_enemy(guard_target, &"test")
	_runner._encore_delay = -1.0

	# Bomb Bunker must replay the accepted action, not choose a new action
	# from the bunker left by the original Guard's release.
	_load("melee", ["BA01", "BAQ", "BAQ4", "BAQ2", "BAE2", "pick.P1"])
	bastion = _runner.engine_for("BAQ") as BastionEngine
	_runner.note_revelation_ended("BAV")
	_runner.activate_q()
	bastion.release_q("BAQ")
	_runner.flush_attacks()
	_runner.q_cooldown_left = 2.0
	_runner._cast_encore()
	_check(bastion.guarding and int(bastion.counters["bunker_waves"]) == 0, "Bomb Bunker Encore repeats Guard without prematurely detonating its original bunker")
	bastion.tick(0.76)
	_runner.flush_attacks()
	_check(not bastion.guarding and int(bastion.counters["guards"]) == 2 and int(bastion.counters["bunkers"]) == 2, "Bomb Bunker's repeated Guard releases and leaves its own finite bunker")
	guard_target = _spawn(1000.0, origin + Vector2(60, 0))
	bastion._tick_bunker(8.1)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(guard_target), 1000.0 - _runner.native_damage()), "the Encore bunker expires with half of the normal 2D wave")
	_check(is_equal_approx(_runner.q_cooldown_left, 2.0), "the evolved repeated Guard preserves recovery")
	EnemyWorld.remove_enemy(guard_target, &"test")
	_runner._encore_delay = -1.0

	# Conversely, a deliberately accepted remote detonation repeats that
	# consumed payload rather than unexpectedly starting a held Guard.
	bastion.activate_q("BAQ")
	bastion.release_q("BAQ")
	bastion._bunker["stored"] = 50.0
	_runner.flush_attacks()
	_runner.q_cooldown_left = 0.0
	_runner.note_revelation_ended("BAV")
	_runner.activate_q()
	_runner.flush_attacks()
	# Another ordinary Guard can create a later bunker before the repeat.
	bastion.activate_q("BAQ")
	bastion.release_q("BAQ")
	_runner.flush_attacks()
	guard_target = _spawn(1000.0, origin + Vector2(60, 0))
	_runner._cast_encore()
	_runner.flush_attacks()
	_check(not bastion.guarding and not bastion._bunker.is_empty(), "remote Detonate Encore preserves a later bunker and never starts Guard")
	_check(is_equal_approx(_runner.enemy_hp(guard_target), 1000.0 - 2.0 * _runner.native_damage()), "remote Detonate Encore retains stored pressure at half of its original 4D damage")
	EnemyWorld.remove_enemy(guard_target, &"test")
	_runner._encore_delay = -1.0

	# Mirror and Gun Shield fire after the runner's transient cast flag ends.
	for mirror_id in ["BAQ3", "BAE1"]:
		_load("melee", ["BA01", "BAQ", "BAQ3", "BAF1", "BR06", mirror_id, "pick.P1"])
		bastion = _runner.engine_for("BAQ") as BastionEngine
		ProjectileManager.clear_for_run_end()
		_runner.note_revelation_ended("BAV")
		_runner.activate_q()
		bastion.release_q("BAQ")
		_runner.flush_attacks()
		_runner._cast_encore()
		ProjectileManager.spawn_enemy(origin + Vector2(40, 0), Vector2.LEFT, 100.0, 5.0, 5.0, null)
		bastion.hold_q("BAQ", 0.16)
		bastion.release_q("BAQ")
		var mirror_damage := 0.0
		for bullet_index in range(ProjectileManager.active_count()):
			if AscensionTags.value_of(ProjectileManager._tags[bullet_index], "root") == mirror_id:
				mirror_damage += ProjectileManager._damage[bullet_index]
		var expected_mirror := 0.375 if mirror_id == "BAQ3" else 0.5
		_check(is_equal_approx(mirror_damage, expected_mirror * _runner.native_damage()), "%s delayed returned projectile retains Encore half damage" % mirror_id)
		_runner.flush_attacks()
		_runner._encore_delay = -1.0
	ProjectileManager.clear_for_run_end()

	_load("magic", ["DO01", "DO05", "DOQ", "DOQ3", "pick.P1"])
	var dominion := _runner.engine_for("DOQ") as DominionEngine
	_runner.aim_override = origin + Vector2(100, 0)
	_runner.note_revelation_ended("DOV")
	_runner.activate_q()
	dominion.release_q("DOQ")
	_runner._q_holding = false
	_runner.q_cooldown_left = 3.25
	var compel_target := _spawn(1000.0, origin + Vector2(80, 0))
	_runner._cast_encore()
	_check(int(dominion.counters["compels"]) == 2 and dominion._q_pending.is_empty(), "Encore's Compel repeat resolves instead of waiting for an absent key release")
	_check(is_equal_approx(_runner.enemy_hp(compel_target), 1000.0 - 0.75 * _runner.native_damage_for("magic")), "Compel Encore halves both its 1D hit and direct 0.5D well placement (HP %.3f, D %.3f)" % [_runner.enemy_hp(compel_target), _runner.native_damage_for("magic")])
	_check(is_equal_approx(_runner.q_cooldown_left, 3.25), "the Compel repeat preserves the original recovery")
	EnemyWorld.remove_enemy(compel_target, &"test")
	_runner._encore_delay = -1.0

	_load("magic", ["DO01", "DO05", "DOQ", "DOQ3", "DOQ4", "pick.P1"])
	dominion = _runner.engine_for("DOQ") as DominionEngine
	_runner.note_revelation_ended("DOV")
	_runner.activate_q()
	dominion.release_q("DOQ")
	_runner._cast_encore()
	compel_target = _spawn(1000.0, origin + Vector2(80, 0))
	dominion._tick_repeat(1.01)
	_check(int(dominion.counters["repeats"]) == 2, "DOQ4 keeps the original Aftershock when Encore schedules its own")
	_check(is_equal_approx(_runner.enemy_hp(compel_target), 1000.0 - 0.9 * _runner.native_damage_for("magic")), "original and Encore Aftershocks deal 0.6D plus 0.3D after transient cast flags clear")
	EnemyWorld.remove_enemy(compel_target, &"test")
	_runner._encore_delay = -1.0

	for secondary_id in ["DOQ6", "DOE1", "DOE2"]:
		_load("magic", ["DO01", "DO05", "DOQ", "DOQ3", secondary_id, "pick.P1"])
		dominion = _runner.engine_for("DOQ") as DominionEngine
		_runner.note_revelation_ended("DOV")
		_runner.activate_q()
		dominion.release_q("DOQ")
		compel_target = _spawn(1000.0, origin + Vector2(80, 0))
		_runner._cast_encore()
		if secondary_id == "DOQ6":
			_check(is_equal_approx(_runner.enemy_hp(compel_target), 1000.0 - 1.375 * _runner.native_damage_for("magic")), "Encore halves Compel Crush's 1.25D secondary hit as well as primary and placement")
		else:
			var hp_before_secondary := _runner.enemy_hp(compel_target)
			if secondary_id == "DOE1":
				dominion._grave_pulse(dominion._graves.back(), origin + Vector2(100, 0))
				_runner.flush_attacks()
			else:
				dominion._tick_pinballs(0.26)
				dominion._tick_pinballs(0.26)
				dominion._tick_pinballs(0.26)
			_check(is_equal_approx(_runner.enemy_hp(compel_target), hp_before_secondary - 0.5 * _runner.native_damage_for("magic")), "%s delayed Q evolution retains Encore half damage" % secondary_id)
		EnemyWorld.remove_enemy(compel_target, &"test")
		_runner._encore_delay = -1.0

	# --- Reaction trigger choice and the elite trigger
	_load("magic", ["DO01", "DO05", "DOQ", "DOQ3", "pick.P1"])
	dominion = _runner.engine_for("DOQ") as DominionEngine
	_runner.note_revelation_ended("DOV")
	_runner.activate_q()
	dominion.hold_q("DOQ", 0.31)
	dominion.release_q("DOQ")
	_runner.reaction_cast = true
	dominion.activate_q("DOQ")
	_runner.reaction_cast = false
	compel_target = _spawn(1000.0, origin + Vector2(80, 0))
	_runner._cast_encore()
	_check(_runner.enemy_position(compel_target).x > origin.x + 120.0, "an intervening Reaction pull cannot replace Encore's original held push action")
	EnemyWorld.remove_enemy(compel_target, &"test")
	_runner._encore_delay = -1.0

	_load("magic", ["DO01", "DO05", "DOQ", "DOQ3", "DOQ5", "pick.P1"])
	dominion = _runner.engine_for("DOQ") as DominionEngine
	_runner.note_revelation_ended("DOV")
	_runner.activate_q()
	dominion.release_q("DOQ")
	compel_target = _spawn(1000.0, origin + Vector2(80, 0))
	var thrown_into := _spawn(1000.0, origin + Vector2(140, 0))
	var throw_hits: Array[float] = []
	var observe_throw := func(hit: Dictionary):
		if int(hit["handle"]) == thrown_into and AscensionTags.value_of(hit["tags"], "root") == "DOQ5":
			throw_hits.append(float(hit["applied"]))
	_runner.hit_resolved.connect(observe_throw)
	_runner._cast_encore()
	_runner.hit_resolved.disconnect(observe_throw)
	_check(throw_hits.size() == 1 and is_equal_approx(throw_hits[0], 0.4 * _runner.native_damage_for("magic")), "Encore halves the separate Compel Throw collision payload")
	EnemyWorld.remove_enemy(compel_target, &"test")
	EnemyWorld.remove_enemy(thrown_into, &"test")
	_runner._encore_delay = -1.0

	_load("ranged", ["BR01", "BR02", "BRQ", ["G1", "melee"], "EX01", "EX02", "EXQ"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	_check(_runner.reaction_id == "EXQ" and _ledger.reaction_trigger() == "catastrophe", "the Reaction slot defaults to the catastrophe trigger")
	_runner.aim_override = origin + Vector2(80, 0)
	_ledger.set_reaction_trigger("elite")
	_runner.note_catastrophe("BRC")
	_check(int(execution.counters["gavels"]) == 0, "a catastrophe does not fire a Reaction set to the elite trigger")
	var elite := _spawn(100.0, origin + Vector2(100, 0), EnemyWorldTypes.Flags.ELITE)
	_runner._process(0.3)
	_check(int(execution.counters["gavels"]) == 1, "the first elite inside 2R fires the Reaction Gavel")
	_runner._process(0.3)
	_check(int(execution.counters["gavels"]) == 1, "the same elite does not fire it again")
	EnemyWorld.remove_enemy(elite, &"test")

	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionSharedRulesTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
