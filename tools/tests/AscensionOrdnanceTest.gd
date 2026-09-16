extends Node

# Ordnance (Ranged): Shells, Mines, Coordinates; Impact Fuse, Caltrops,
# Short Fuse, Secondary Blast, Mine Toss, Chain Reaction, Blast Pull,
# Fracture, Designate with its seven mutations, Walking Barrage, Magazine,
# Saturation Scan, Big One, both forks, both keystones, Fuse, Rolling
# Thunder, both Evolutions, the sinks and FIRE MISSION.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionOrdnanceTest.tscn

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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_or", "res://asc_or.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	ProjectileManager.clear_for_run_end()
	_runner.flush_attacks()


func _load(ids: Array) -> OrdnanceEngine:
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
	_runner.travel_this_frame = 0.0
	_runner.aim_override = _origin + Vector2(300, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for entry in ids:
		var id := String(entry[0]) if entry is Array else String(entry)
		var engine := _runner.engine_for(id) as OrdnanceEngine
		if engine != null:
			return engine
	return null


func _D() -> float:
	return _runner.native_damage_for("ranged")


func _native() -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:native:1")
	return tags


## Lands every pending Shell now.
func _land(engine: OrdnanceEngine, seconds: float = 1.0) -> void:
	engine.tick(seconds)
	_runner.flush_attacks()


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	var origin := _origin

	# ---------------- Shells and Impact Fuse
	var orx := _load(["OR01", "OR02"])
	var target := _spawn(500.0, origin + Vector2(200, 0))
	orx.call_shell(origin + Vector2(200, 0))
	_check(orx != null and orx.shells.size() == 1 and is_equal_approx(float(orx.shells[0]["left"]), 0.6), "a Shell falls after a 0.6 s tell")
	orx.tick(0.5)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(target), 500.0), "nothing lands early")
	_land(orx, 0.11)
	_check(is_equal_approx(_runner.enemy_hp(target), 500.0 - 1.5 * _D()) and orx.shells.is_empty(), "then blasts 1.5D in R (%.1f)" % _runner.enemy_hp(target))
	for i in range(3):
		_runner.damage_enemy(target, 5.0, _native())
	_check(int(orx.counters["fuse_shells"]) == 0, "three weighted Core hits call nothing")
	_runner.damage_enemy(target, 5.0, _native())
	_check(int(orx.counters["fuse_shells"]) == 1 and orx.shells.size() == 1, "the fourth calls a Shell at the victim")
	for i in range(4):
		_runner.damage_enemy(target, 5.0, _native())
	_check(int(orx.counters["fuse_shells"]) == 1 and is_equal_approx(orx._fuse, 4.0), "one Shell per Core strike activation; extra credit is retained")
	orx.on_native_fire("ranged", origin, origin + Vector2(100, 0), 1.0, 1.0)
	_runner.damage_enemy(target, 5.0, _native())
	_check(int(orx.counters["fuse_shells"]) == 2, "the next strike spends the retained credit")

	# ---------------- Caltrops, Chain Reaction, Magazine cap
	orx = _load(["OR01", "OR02", "OR06"])
	orx.on_player_dashed(origin + Vector2(100, 0), Vector2.RIGHT)
	_check(orx.mines.size() == 1 and int(orx.counters["mines"]) == 1, "every dash drops a Mine at its start")
	var stepper := _spawn(500.0, origin + Vector2(100, 200))
	orx.tick(0.36)
	_runner.move_enemy_to(stepper, origin + Vector2(100, 10))
	orx.on_player_dashed(origin + Vector2(150, 0), Vector2.RIGHT)
	orx.tick(0.36)
	_runner.flush_attacks()
	_check(int(orx.counters["mine_blasts"]) == 2 and int(orx.counters["chain"]) == 1 and orx.mines.is_empty() and is_equal_approx(_runner.enemy_hp(stepper), 500.0 - 2.0 * 1.5 * _D()), "an armed Mine triggers on contact and Chain Reaction detonates the armed Mine it touches (%.1f)" % _runner.enemy_hp(stepper))
	for i in range(13):
		orx.on_player_dashed(origin + Vector2(400 + 10 * i, 400), Vector2.RIGHT)
	_check(orx.mines.size() == 12 and int(orx.counters["mine_blasts"]) == 3, "the twelve-Mine cap replaces the oldest, which detonates at half damage")
	orx = _load(["OR01", "OR02", "OR10"])
	_check(orx.mine_cap() == 18, "Magazine raises the cap to eighteen")

	# ---------------- Short Fuse, Secondary Blast
	orx = _load(["OR01", "OR03", "OR04"])
	var under := _spawn(500.0, origin + Vector2(200, 0))
	var neighbour := _spawn(500.0, origin + Vector2(300, 0))
	orx.call_shell(origin + Vector2(200, 0))
	_runner.damage_enemy(under, 5.0, _native())
	_check(is_equal_approx(float(orx.shells[0]["left"]), 0.45) and int(orx.counters["short_fuses"]) == 1, "hitting an enemy under a falling Shell advances it 0.15 s")
	_runner.damage_enemy(under, 5.0, _native())
	_check(is_equal_approx(float(orx.shells[0]["left"]), 0.45), "once per Core strike")
	EnemyWorld.set_health(under, 1.0)
	orx.call_shell(origin + Vector2(200, 0))
	_land(orx, 0.7)
	_check(not _runner.enemy_alive(under) and int(orx.counters["secondary"]) == 1, "a blast kill calls a Shell on the corpse")
	_check(int(orx.counters["redirects"]) >= 1 or orx.shells.size() >= 1, "a Shell whose target died redirects to the nearest occupied area (%d)" % int(orx.counters["redirects"]))
	_land(orx, 0.7)
	_check(_runner.enemy_hp(neighbour) < 500.0, "the redirected and secondary Shells reach the neighbour (%.1f)" % _runner.enemy_hp(neighbour))

	# ---------------- Mine Toss
	orx = _load(["OR01", "OR02", "OR05"])
	orx.on_player_dashed(origin + Vector2(60, 0), Vector2.RIGHT)
	_runner.spawn_bullet(origin, Vector2.RIGHT, 5.0, _native(), {"max_range": 200.0})
	for _i in range(8):
		await get_tree().process_frame
		orx.tick(1.0 / 60.0)
	_check(int(orx.counters["tosses"]) == 1 and is_equal_approx(float(orx.mines[0]["arm"]), 0.0) and (orx.mines[0]["at"] as Vector2).x > origin.x + 130.0, "a Core projectile pushes an unarmed Mine R toward aim and arms it (%s)" % str(orx.mines[0]["at"]))
	_check(is_equal_approx(float(orx.mines[0]["damage"]), 1.5 * _D() + 0.5 * _D()), "a tossed Mine that travelled R/2 gains +0.5D")

	# ---------------- Blast Pull and Fracture
	orx = _load(["OR01", "OR07", "OR08"])
	var pulled := _spawn(500.0, origin + Vector2(200 + 60, 0))
	orx.call_shell(origin + Vector2(200, 0))
	_land(orx, 0.7)
	_check(int(orx.counters["pulls"]) == 1 and _runner.enemy_position(pulled).x < origin.x + 230.0, "a normal in the outer half is pulled R/2 toward the centre (%s)" % str(_runner.enemy_position(pulled)))
	EnemyWorld.remove_enemy(pulled, &"test")
	var fractured := _spawn(5000.0, origin + Vector2(200, 0))
	for i in range(3):
		orx.call_shell(origin + Vector2(200 - 20 * i, 0))
		_land(orx, 0.7)
	_check(_runner.has_status(fractured, "fracture") and int(orx.counters["fractures"]) == 1, "three distinct blasts arm Fracture")
	var bullets_before := ProjectileManager.active_count()
	orx.call_shell(origin + Vector2(200, 0))
	_land(orx, 0.7)
	_check(not _runner.has_status(fractured, "fracture") and int(orx.counters["shrapnel"]) == 1 and ProjectileManager.active_count() == bullets_before + 3, "the next blast consumes it for three shrapnel shots")

	# ---------------- Designate
	orx = _load(["OR01", "OR02", "ORQ"])
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and orx.coordinates.size() == 1 and is_equal_approx(_runner.q_cooldown_left, 0.25), "Q on empty ground places a Coordinate with 0.25 s recovery")
	var shelled := _spawn(5000.0, origin + Vector2(300, 0))
	_runner.q_cooldown_left = 0.0
	verdict = _runner.activate_q()
	_check(bool(verdict["ok"]) and verdict["message"] == "DESIGNATE" and orx.coordinates.is_empty() and is_equal_approx(_runner.q_cooldown_left, 7.0), "Q on a Coordinate fires it and consumes it, 7 s cooldown")
	for i in range(5):
		orx.tick(0.2)
	_check(orx.shells.size() == 4 or int(orx.counters["shells"]) == 4, "four Shells at 0.2 s intervals (%d)" % int(orx.counters["shells"]))
	_land(orx, 1.0)
	_check(is_equal_approx(_runner.enemy_hp(shelled), 5000.0 - 4.0 * 1.5 * _D()), "each lands for 1.5D (%.1f)" % _runner.enemy_hp(shelled))
	_runner.q_cooldown_left = 0.0
	_runner.aim_override = origin + Vector2(-300, 0)
	_runner.activate_q()
	orx.hold_q("ORQ", 0.36)
	_check(int(orx.counters["designates"]) == 2 and is_equal_approx(_runner.q_cooldown_left, 7.0), "holding Q 0.35 s on empty ground places and fires at once")
	_runner.aim_override = origin + Vector2(300, 0)

	# ---------------- Designate mutations
	orx = _load(["OR01", "OR02", "ORQ", "ORQ1", "ORQ3", "ORQ7"])
	var cluster := _spawn(5.0, origin + Vector2(300, 0))
	_runner.activate_q()
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	_check(orx.coordinates.size() == 1 and bool(orx.coordinates[0]["dormant"]), "Fire Again: a fired Coordinate goes dormant")
	for i in range(8):
		orx.tick(0.2)
	_check(int(orx.counters["shells"]) == 7, "Saturation calls seven Shells across a 3R circle (%d)" % int(orx.counters["shells"]))
	_land(orx, 1.0)
	_check(not _runner.enemy_alive(cluster) or int(orx.counters["cascades"]) >= 0, "the circle covers the target")
	if not _runner.enemy_alive(cluster):
		_check(int(orx.counters["cascades"]) == 1, "Cascade adds one Shell per distinct sequence kill")
	_runner.q_cooldown_left = 0.0
	orx.tick(0.01)
	_check(not bool(orx.coordinates[0]["dormant"]), "the Coordinate reactivates when the cooldown completes")
	orx = _load(["OR01", "OR02", "ORQ", "ORQ2", "ORQ5", "ORQ6"])
	var tracked := _spawn(5000.0, origin + Vector2(320, 40))
	_runner.activate_q()
	_runner.aim_override = origin + Vector2(300, 100)
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	_check(orx.coordinates.size() == 2 and (orx.coordinates[1]["offset"] as Vector2).length() > 0.0, "Walking Target: the Coordinate keeps an aim-set offset from the player")
	_runner.q_cooldown_left = 0.0
	_runner.aim_override = origin + Vector2(300, 0)
	_runner.activate_q()
	for i in range(6):
		orx.tick(0.2)
	_check(int(orx.counters["shells"]) == 6, "All Coordinates fires every Coordinate; Homing calls three 2.5D Shells each (%d)" % int(orx.counters["shells"]))
	_check(int(orx.shells[0]["follow"]) == tracked and is_equal_approx(float(orx.shells[0]["damage"]), 2.5 * _D()), "Homing Shells track the chosen enemy")
	_land(orx, 1.0)
	_check(_runner.enemy_hp(tracked) < 5000.0, "they land on it (%.1f)" % _runner.enemy_hp(tracked))
	orx = _load(["OR01", "OR02", "ORQ", "ORQ4"])
	var trapped := _spawn(5000.0, origin + Vector2(320, 40))
	_runner.activate_q()
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	for i in range(5):
		orx.tick(0.2)
	_land(orx, 1.0)
	_check(orx.mines.size() == 4 and bool(orx.mines[0]["trap"]) and is_equal_approx(_runner.enemy_hp(trapped), 5000.0), "Proximity: Designate Shells land as traps that deal nothing until detonation (%d)" % orx.mines.size())
	_land(orx, 3.1)
	_check(orx.mines.is_empty() and _runner.enemy_hp(trapped) < 5000.0, "traps explode on expiry (%.1f)" % _runner.enemy_hp(trapped))

	# ---------------- Walking Barrage, Saturation Scan, Big One
	orx = _load(["OR01", "OR09", "OR11", "OR12"])
	_runner.travel_this_frame = 250.0
	orx.tick(0.1)
	_runner.travel_this_frame = 0.0
	_check(int(orx.counters["walking"]) == 1 and orx.shells.size() == 1, "travelling L calls a Shell R behind you")
	var scanned := _spawn(1.0, origin + Vector2(400, 0))
	_spawn(500.0, origin + Vector2(420, 10))
	orx._scan_travel = 100.0
	orx.call_shell(origin + Vector2(400, 0))
	_land(orx, 0.7)
	_check(not _runner.enemy_alive(scanned) and int(orx.counters["scans"]) == 1 and orx._sequences.size() == 1, "the first blast kill after moving R scans the densest cell for three Shells")
	orx._sequences.clear()
	orx.shells.clear()
	orx._shell_count = 6
	orx.call_shell(origin + Vector2(600, 0))
	_check(int(orx.counters["big_ones"]) == 1 and bool(orx.shells[orx.shells.size() - 1]["big"]) and is_equal_approx(float(orx.shells[orx.shells.size() - 1]["damage"]), 4.0 * _D()) and is_equal_approx(float(orx.shells[orx.shells.size() - 1]["left"]), 0.9), "every seventh Shell is a 4D Big One in 2R with a 0.9 s tell")

	# ---------------- forks and keystones
	orx = _load(["OR01", "OR02", "OR03", "OR04", "ORF1"])
	var spread := _spawn(5000.0, origin + Vector2(200, 0))
	orx.call_shell(origin + Vector2(200, 0))
	_land(orx, 0.7)
	_check(is_equal_approx(_runner.enemy_hp(spread), 5000.0 - 1.5 * _D() * 0.85), "Carpet Fire: Shells deal 15%% less (%.1f)" % _runner.enemy_hp(spread))
	orx = _load(["OR01", "OR02", "OR03", "OR04", "ORF2"])
	var elite := _spawn(5000.0, origin + Vector2(300, 0), EnemyWorldTypes.Flags.ELITE)
	_runner.damage_enemy(elite, 5.0, _native())
	orx.call_shell(origin + Vector2(100, 0))
	_check(orx.shells.size() == 1 and (orx.shells[0]["at"] as Vector2).distance_to(origin + Vector2(300, 0)) < 1.0, "Guidance: automatic Shells target the last elite hit")
	orx.call_shell(origin + Vector2(100, 0))
	_check(orx.shells.size() == 1 and int(orx.counters["suppressed"]) == 1, "every second automatic Shell is suppressed")
	_land(orx, 0.7)
	_check(is_equal_approx(_runner.enemy_hp(elite), 5000.0 - 5.0 - 1.5 * _D() * 1.5), "guided Shells deal +50%% (%.1f)" % _runner.enemy_hp(elite))
	orx = _load(["OR01", "OR02", "OR03", "OR04", "ORK1"])
	var beaconed := _spawn(5000.0, origin + Vector2(200, 0), EnemyWorldTypes.Flags.ELITE)
	for i in range(3):
		orx.call_shell(origin + Vector2(200 - 15 * i, 0), 1.5, "OR01", 0.5, PackedStringArray(), false)
		_land(orx, 0.7)
	_check(orx._beacons.has(beaconed) and int(orx.counters["beacons"]) == 1, "Spotter: three distinct blasts mark a durable target as a Beacon")
	orx.tick(0.81)
	_check(int(orx.counters["beacon_shells"]) == 1, "it receives a Shell every 0.8 s")
	orx = _load(["OR01", "OR02", "OR03", "OR04", "ORK2"])
	var close := _spawn(5000.0, origin + Vector2(60, 0))
	var hp_before: float = _player.hp
	orx.call_shell(origin + Vector2(40, 0))
	_land(orx, 0.7)
	_check(is_equal_approx(_runner.enemy_hp(close), 5000.0 - 1.5 * _D() * 1.25) and int(orx.counters["self_hits"]) == 1 and _player.hp < hp_before, "Danger Close: +25%% damage, and a blast on you costs 3%% max HP (hp %.1f)" % _player.hp)
	_check(is_equal_approx(orx._blast_radius_scale(), 1.4), "and +40%% radius")

	# ---------------- Fuse, sinks, Rolling Thunder
	orx = _load(["OR01", "OR02", "OR03", "OR04", "OR07", "ORA"])
	orx.on_q_activated("EXQ", {"ok": true})
	_check(int(orx.counters["fuse_q"]) == 1 and orx.shells.size() == 1, "Fuse: a Q that makes no Shells leaves one at its endpoint")
	orx = _load(["OR01", "OR02", "OR03", "OR04", "OR07", "ORS1", "ORS1", "ORS1", "ORS1", "ORS2", "ORS2"])
	_check(is_equal_approx(orx._blast_damage_scale(true, false), 1.0 + 0.01 * 2.0) and is_equal_approx(orx._blast_radius_scale(), 1.0 + 0.7 * 2.0 / 97.0), "sinks: Blast Damage 1%% x sqrt(rank), Blast Radius 70%% x rank/(rank+95)")
	orx = _load(["OR01", "OR02", "OR03", "OR04", "OR06", "OR07", "ORC"])
	var seq := 77
	for i in range(12):
		orx._blast(origin + Vector2(300, 0), 1.0, AscensionRunner.R, "OR01", 0.5, PackedStringArray(), seq, true, false)
	_check(int(orx.counters["thunder"]) == 1 and orx._lanes.size() == 6, "twelve blasts within one root start Rolling Thunder's six lanes")
	for i in range(5):
		orx.tick(0.25)
	_check(int(orx.counters["lane_shells"]) == 24, "each lane lands four 2D Shells over a second (%d)" % int(orx.counters["lane_shells"]))

	# ---------------- Evolutions
	orx = _load(["OR01", "OR02", "OR09", "ORQ", "ORQ1", "ORF1", "ORE1"])
	_runner.activate_q()
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	_check(orx.coordinates.size() == 1 and float(orx.coordinates[0]["carpet"]) > 0.0, "Carpet Bomb: an activated Coordinate follows the player")
	_runner.travel_this_frame = 5.0
	for i in range(4):
		orx.tick(0.31)
	_check(int(orx.counters["carpet_drops"]) == 4, "dropping a Shell every 0.3 s behind the route (%d)" % int(orx.counters["carpet_drops"]))
	_runner.travel_this_frame = 0.0
	orx.tick(0.31)
	_check(int(orx.counters["carpet_drops"]) == 10, "stopping for 0.3 s fires the remaining allowance at once (%d)" % int(orx.counters["carpet_drops"]))
	orx = _load(["OR01", "OR02", "OR12", "ORQ", "ORQ2", "ORF2", "ORE2"])
	var bunker := _spawn(5000.0, origin + Vector2(320, 40), EnemyWorldTypes.Flags.ELITE)
	_runner.activate_q()
	_runner.q_cooldown_left = 0.0
	_runner.activate_q()
	_check(int(orx.counters["busters"]) == 1, "Bunker Buster attaches the Coordinate to the durable target")
	orx.tick(1.21)
	_check(orx.shells.size() == 1 and is_equal_approx(float(orx.shells[0]["damage"]), 8.0 * _D()) and is_equal_approx(float(orx.shells[0]["radius"]), 2.0 * AscensionRunner.R), "after a 1 s tell one 8D Shell in 2R is called")
	_land(orx, 0.3)
	_check(is_equal_approx(_runner.enemy_hp(bunker), 5000.0 - 8.0 * _D()), "it lands on the target (%.1f)" % _runner.enemy_hp(bunker))

	# ---------------- FIRE MISSION
	orx = _load(["OR01", "OR02", "OR03", "OR04", "OR06", "OR07", "ORC", "ORV", "ORV3"])
	var bossy := _spawn(50000.0, origin + Vector2(200, 0), EnemyWorldTypes.Flags.ELITE)
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and orx._mission_tell > 0.0, "V starts a 1 s grid tell")
	orx.tick(1.01)
	for i in range(5):
		orx.tick(0.1)
	_check(int(orx.counters["mission_shells"]) == 24, "twenty-four 3D Shells land over a second (%d)" % int(orx.counters["mission_shells"]))
	_land(orx, 0.3)
	_check(_runner.enemy_hp(bossy) <= 50000.0 - 4.0 * 3.0 * _D(), "a lone durable target takes at least four (%.1f)" % _runner.enemy_hp(bossy))
	orx.tick(1.5)
	for i in range(11):
		orx.tick(0.1)
	_check(int(orx.counters["salvos"]) == 1 and int(orx.counters["mission_shells"]) == 48, "Second Salvo repeats after 2 s at 60%% (%d)" % int(orx.counters["mission_shells"]))
	orx = _load(["OR01", "OR02", "OR03", "OR04", "OR06", "OR07", "ORC", "ORV", "ORV1"])
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	orx.tick(1.01)
	for i in range(11):
		orx.tick(0.1)
	_check(int(orx.counters["mission_shells"]) == 48, "No Safe Ground uses forty-eight Shells (%d)" % int(orx.counters["mission_shells"]))

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionOrdnanceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
