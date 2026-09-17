extends Node

# Barrage on a Ranged native: Heat climbs 8 per input and unlocks tiers, Fifth
# Shot arms on the fifth strike, Bigger Magazine stores on tier crossings and
# re-arms after cooling, the Jam fires Loose Chamber (doubled and paid for by
# Backfire) and triggers Overload, Hot Rounds explode and burn above 50 Heat,
# Ricochet bounces a Core bullet, Fragmentation chains through a wounded pair,
# Burst doubles the rate and vents into a volley, SUPPRESSION mirrors native
# shots, and a native shot's profile carries its volley and Core-strike tags.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionBarrageTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: BarrageEngine


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_barrage", "res://asc_barrage.tscn", at, hp, 10.0, 8.0, 0, 0))


func _fire() -> void:
	RunEvents.weapon_fired.emit(_player, &"ranged", _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)


func _native_bullet_tags(volley: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags.append("volley:%d" % volley)
	return AscensionTags.with_flag(tags, "core_strike")


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	for id in ["BR02", "BR04", "BR05", "BR09", "BR10", "BR08", "BR11", "BRQ", "BRQ4", "BRF2", "BRC", "BRV"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngine
	_check(_engine != null and _runner.q_id == "BRQ" and _runner.v_id == "BRV", "the Barrage engine loads with Burst on Q and SUPPRESSION on V")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()
	_check(is_equal_approx(D, 12.0), "a Ranged native's D is 12 (%s)" % str(D))

	# --- Heat, tiers, Fifth Shot, Bigger Magazine
	for _i in range(6):
		_fire()
	_check(is_equal_approx(_engine.heat, 48.0) and _engine.tier_index() == 0, "six inputs add 48 Heat, still tier 0 (%s)" % str(_engine.heat))
	_check(int(_engine.counters["fifth_shots"]) == 1, "the fifth strike armed two rounds that fired on the sixth")
	_fire()
	_check(is_equal_approx(_engine.heat, 56.0) and _engine.tier_index() == 1, "the seventh input crosses 50 into tier 1")
	_check(is_equal_approx(_engine.haste_multiplier("ranged"), 1.15), "tier 1 fires 15% faster")
	_check(_engine.stored_rounds == 3, "crossing 50 stores three rounds")
	_fire()
	_check(int(_engine.counters["side_rounds"]) == 2, "each input at tier 1 fires one side round, the crossing input included (%d)" % int(_engine.counters["side_rounds"]))
	_engine.tick(0.35)
	_engine.tick(1.0)
	_check(_engine.heat < 40.0 and _engine.heat > 20.0, "idle cooling removes Heat at 25/s (%s)" % str(_engine.heat))
	for _i in range(3):
		_fire()
	_check(_engine.stored_rounds == 6, "re-crossing 50 after cooling stores again (%d)" % _engine.stored_rounds)

	# --- Jam with Backfire, Loose Chamber and Overload
	var hp_before: float = _player.hp
	while not _engine.jammed() and _engine.heat < 100.0:
		_fire()
	_check(_engine.jammed() and int(_engine.counters["jams"]) == 1, "reaching 100 Heat jams the weapon")
	_check(int(_engine.counters["loose_rounds"]) == 24, "Backfire doubles Loose Chamber to 24 radial rounds (%d)" % int(_engine.counters["loose_rounds"]))
	_check(int(_engine.counters["stored_fired"]) == 9 and _engine.stored_rounds == 0, "crossing 75 stored three more and the Jam empties the magazine (%d)" % int(_engine.counters["stored_fired"]))
	_check(_player.hp < hp_before, "Backfire pays 5% of current HP")
	_check(int(_engine.counters["overloads"]) == 1, "a Backfire Jam triggers Overload")
	_check(float(_player.get("_weapon_cd")) >= 1.0, "the Jam blocks native fire")
	_engine.tick(0.7)
	_check(int(_engine.counters["overload_rounds"]) == 48, "Overload emits four twelve-round volleys (%d)" % int(_engine.counters["overload_rounds"]))
	_engine.tick(0.6)
	_check(not _engine.jammed() and is_equal_approx(_engine.heat, 20.0), "after 1.2 s the Jam clears to 20 Heat")

	# --- Hot Rounds
	_engine.heat = 60.0
	var victim := _spawn_enemy(200.0, _player.global_position + Vector2(100, 0))
	_runner.damage_enemy(victim, 5.0, _native_bullet_tags(1))
	_check(int(_engine.counters["hot_rounds"]) == 1, "above 50 Heat the first Core impact of a volley explodes")
	_check(EnemyStatus.has_status(victim, &"burn"), "Hot Rounds burns the victims")
	_runner.damage_enemy(victim, 5.0, _native_bullet_tags(1))
	_check(int(_engine.counters["hot_rounds"]) == 1, "the second impact of the same volley does not")

	# --- Ricochet
	var neighbour := _spawn_enemy(200.0, _player.global_position + Vector2(160, 0))
	var bullets_before := ProjectileManager.active_count()
	_runner.damage_enemy(victim, 5.0, _native_bullet_tags(2))
	_check(int(_engine.counters["ricochets"]) == 1 and ProjectileManager.active_count() == bullets_before + 1, "a Core bullet bounces to a different enemy within 2R")
	EnemyWorld.remove_enemy(victim, &"test")
	EnemyWorld.remove_enemy(neighbour, &"test")

	# --- Fragmentation chain through a wounded pair
	var first := _spawn_enemy(5.0, _player.global_position + Vector2(300, 0))
	var second := _spawn_enemy(5.0, _player.global_position + Vector2(340, 0))
	_runner.damage_enemy(first, 100.0, _native_bullet_tags(3))
	_check(int(_engine.counters["fragments"]) == 2, "a real Ranged kill releases two fragments")
	var steps := 0
	while _runner.enemy_alive(second) and steps < 180:
		_engine.tick(1.0 / 60.0)
		steps += 1
	_check(not _runner.enemy_alive(second), "seeking fragments kill the wounded neighbour within 3 s (%d steps)" % steps)
	_check(int(_engine.counters["fragments"]) >= 4, "the fragment kill releases another pair (%d)" % int(_engine.counters["fragments"]))
	_check(int(_runner.telemetry["seed_kills"]) == 1 and int(_runner.telemetry["chain_kills"]) >= 1 and _runner.r0() >= 1.0, "R0 counts chain kills per seed kill (%s)" % str(_runner.r0()))

	# --- Burst
	_engine.heat = 30.0
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(float(verdict["cooldown"]), 8.0), "Burst activates on an 8 s cooldown")
	_check(is_equal_approx(_engine.haste_multiplier("ranged"), 2.0), "Burst doubles the firing rate")
	bullets_before = ProjectileManager.active_count()
	_fire()
	_check(ProjectileManager.active_count() >= bullets_before + 2, "Three Guns mirrors each Burst shot from two points")
	_check(is_equal_approx(_engine.heat, 46.0), "Heat gain doubles during Burst (%s)" % str(_engine.heat))
	_engine.tick(2.0)
	_check(_engine.burst_left <= 0.0 and int(_engine.counters["burst_rounds"]) == 12 and _engine.heat <= 20.0, "completion fires a twelve-round volley and vents to 20")

	# --- SUPPRESSION and charge
	_runner.v_charge = 0.0
	var fodder := _spawn_enemy(1.0, _player.global_position + Vector2(-100, 0))
	_runner.damage_enemy(fodder, 10.0, _native_bullet_tags(4))
	_check(is_equal_approx(_runner.v_charge, 0.5), "a normal kill charges the Revelation by half a point")
	verdict = _runner.activate_v()
	_check(not bool(verdict["ok"]) and verdict["message"] == "CHARGING", "V refuses until the charge is full")
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and _engine.suppression_left > 0.0 and is_equal_approx(_runner.v_charge, 0.0), "a full charge starts SUPPRESSION and empties")
	_fire()
	_check(int(_engine.counters["suppression_rounds"]) == 3, "three edge guns mirror a native shot")
	_engine.tick(5.0)
	_check(_engine.suppression_left <= 0.0, "SUPPRESSION ends after 5 s")

	# --- a real native shot carries provenance
	_engine.tick(2.0)
	_player.set("_weapon_cd", 0.0)
	bullets_before = ProjectileManager.active_count()
	_player.call("_fire_weapon", _player.global_position + Vector2(200, 0))
	_check(ProjectileManager.active_count() > bullets_before, "the native weapon fires through the player")
	var tags: PackedStringArray = ProjectileManager._tags[bullets_before]
	_check(AscensionTags.value_of(tags, "family") == "native" and AscensionTags.has_flag(tags, "core_strike") and AscensionTags.value_of(tags, "volley") != "", "the native bullet is tagged native, Core strike, with its volley (%s)" % str(tags))

	for handle in [first, second, fodder]:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	Global.attempt_ascension = {}
	_player.queue_free()
	_finish()


func _finish() -> void:
	print("AscensionBarrageTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
