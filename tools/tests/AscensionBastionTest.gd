extends Node

# Bastion (Melee): Force from enemy pressure, Stored Force, Return to
# Sender, Plate, Full Tank, Razor Guard, Thorns, Surrounded, Vessel, Armor
# Break, Slow Leak, Last Hit, Guard with its mutations, both forks, both
# keystones, Heavy Hands, Meltdown, Gun Shield, Bomb Bunker, the sinks and
# RUPTURE.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionBastionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")


class FakeSlash extends Node:
	var arc_radius: float = 62.0
	var arc_degrees: float = 145.0


var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _ledger: AscensionLedger
var _spawned: Array[int] = []
var _actors: Array[Node] = []
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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_ba", "res://asc_ba.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


## An enemy with a bound actor node, so player damage has a source.
func _spawn_attacker(hp: float, at: Vector2, flags: int = 0) -> Array:
	var handle := _spawn(hp, at, flags)
	var actor := Node2D.new()
	actor.global_position = at
	add_child(actor)
	EnemyWorld.bind_actor(handle, actor)
	_actors.append(actor)
	return [handle, actor]


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	ProjectileManager.clear_for_run_end()
	_runner.flush_attacks()


func _load(ids: Array) -> BastionEngine:
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
	_runner._q_holding = false
	_runner.still_seconds = 0.0
	_runner.travel_this_frame = 0.0
	_runner.aim_override = _origin + Vector2(100, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_player.set("invulnerable_time", 0.0)
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for entry in ids:
		var id := String(entry[0]) if entry is Array else String(entry)
		var engine := _runner.engine_for(id) as BastionEngine
		if engine != null:
			return engine
	return null


func _D() -> float:
	return _runner.native_damage()


func _native(path: String = "slash", core: String = "melee") -> PackedStringArray:
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:native:1")
	return tags


func _hostile_bullet(at: Vector2, direction: Vector2, source: Node = null) -> void:
	ProjectileManager.spawn_enemy(at, direction, 100.0, 5.0, 5.0, source)


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	var origin := _origin
	var run_stats := Stats.new()
	run_stats.max_hp = _player.max_hp
	run_stats.move_speed = _player.speed
	_player.apply_run_stats(run_stats)
	var max_hp: float = _player.max_hp
	Global.run_luck = 0.0

	# ---------------- Force from pressure
	var ba := _load(["BA01", "BA02"])
	var pair := _spawn_attacker(200.0, origin + Vector2(50, 0))
	_player.take_damage(0.05 * max_hp, pair[1])
	_check(ba != null and is_equal_approx(ba.force, 10.0), "an enemy hit for 5%% max HP grants 10 Force (%.1f)" % ba.force)
	_player.take_damage(0.5 * max_hp, pair[1])
	_check(is_equal_approx(ba.force, 35.0), "a hit is capped at 25 Force (%.1f)" % ba.force)
	_player.hp = max_hp
	_player.pay_health(0.2 * max_hp, &"test")
	_check(is_equal_approx(ba.force, 35.0), "health payments grant nothing")
	_check(is_equal_approx(ba.capacity(), 100.0), "capacity is 100")

	# ---------------- Stored Force
	var slash := FakeSlash.new()
	ba.decorate_native_slash(slash)
	_check(is_equal_approx(slash.arc_radius, 62.0 + AscensionRunner.R * 0.5), "at 20+ Force the arc gains R/2 radius (%.1f)" % slash.arc_radius)
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(is_equal_approx(ba.force, 15.0) and int(ba.counters["stored_spends"]) == 1, "a Melee Core strike spends up to 20 Force (%.1f)" % ba.force)
	_runner.damage_enemy(pair[0], 10.0, _native())
	_check(is_equal_approx(_runner.enemy_hp(pair[0]), 200.0 - 10.0 - 0.05 * _D() * 20.0), "and adds 0.05D per point to that strike (%.1f)" % _runner.enemy_hp(pair[0]))
	_runner.damage_enemy(pair[0], 10.0, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EX06", "slash", 1, 0.5))
	_check(is_equal_approx(_runner.enemy_hp(pair[0]), 200.0 - 20.0 - 0.05 * _D() * 20.0), "payloads of the same volley gain nothing")
	slash.free()

	# ---------------- Return to Sender and Razor Guard
	ba = _load(["BA02", "BA05"])
	var shooter := _spawn_attacker(200.0, origin + Vector2(300, 0))
	for i in range(3):
		_hostile_bullet(origin + Vector2(40, -10 + 10 * i), Vector2.LEFT, shooter[1])
	var friendly_before := ProjectileManager.active_count()
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(ba.counters["returns"]) == 3 and is_equal_approx(ba.force, 30.0), "a Melee Core strike catches up to three hostile projectiles for 10 Force each (%.1f)" % ba.force)
	_check(ProjectileManager.active_count() == friendly_before - 3 + 3 + 6 and int(ba.counters["razor_rings"]) == 1, "copies fly back and three catches within 1 s ring six blades (%d)" % ProjectileManager.active_count())

	# ---------------- Plate
	ba = _load(["BA01", "BA03"])
	pair = _spawn_attacker(200.0, origin + Vector2(50, 0))
	ba.tick(2.1)
	_check(ba._plate_ready, "two seconds without a hit forms a plate")
	_player.take_damage(0.2 * max_hp, pair[1])
	_check(is_equal_approx(_player.hp, max_hp - 0.1 * max_hp) and is_equal_approx(ba.force, 15.0 + 25.0) and not ba._plate_ready, "the plate halves the next hit and grants 15 Force (hp %.1f force %.1f)" % [_player.hp, ba.force])
	ba.force = 60.0
	ba.tick(2.1)
	_check(not ba._plate_ready, "no plate reforms above 50 Force")

	# ---------------- Full Tank, Vessel, Armor Break
	ba = _load(["BA01", "BA04", "BA08", "BA09"])
	var near := _spawn(500.0, origin + Vector2(100, 0))
	ba.add_force(145.0, false)
	_check(is_equal_approx(ba.force, 100.0) and ba.plates == 2, "Force beyond capacity becomes plates of 20 (%d)" % ba.plates)
	var bullets_before := ProjectileManager.active_count()
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.flush_attacks()
	_check(int(ba.counters["full_tanks"]) == 1 and is_equal_approx(ba.force, 0.0) and is_equal_approx(_runner.enemy_hp(near), 500.0 - 3.0 * _D()), "at 100 Force the next Melee Core strike discharges a 3D nova in 2R (%.1f)" % _runner.enemy_hp(near))
	_check(ba.plates == 0 and ProjectileManager.active_count() == bullets_before + 2, "the discharge fires unbroken plates as blades")
	_runner.damage_enemy(near, 10.0, _native())
	_check(_runner.has_status(near, "cracked") and int(ba.counters["armor_breaks"]) == 1, "Armor Break: a 20+ spend Cracks the strike's victims")

	# ---------------- Thorns through Guard
	ba = _load(["BA01", "BA06", "BAQ"])
	pair = _spawn_attacker(200.0, origin + Vector2(50, 0))
	ba.force = 40.0
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and ba.guarding and ba.q_is_hold("BAQ"), "Q is a held Guard")
	_player.take_damage(0.4 * max_hp, pair[1])
	var prevented := 0.4 * max_hp * 0.75
	_check(absf(_player.hp - (max_hp - 0.1 * max_hp)) < 0.5, "with Force the guard prevents 75%% (hp %.1f, Melee lifesteal from Thorns aside)" % _player.hp)
	_check(is_equal_approx(_runner.enemy_hp(pair[0]), 200.0 - clampf(0.35 * prevented, 0.2 * _D(), 2.0 * _D())) and int(ba.counters["thorns"]) == 1, "Thorns returns 35%% of the prevented damage, bounded by 0.2D and 2D (%.1f)" % _runner.enemy_hp(pair[0]))
	ba.hold_q("BAQ", 0.5)
	_check(is_equal_approx(ba.force, 40.0 + 25.0 - 6.0), "holding spends 12 Force per second (%.1f)" % ba.force)
	var near_wave := _spawn(500.0, origin + Vector2(120, 0))
	verdict = ba.release_q("BAQ")
	_runner.flush_attacks()
	_check(not ba.guarding and is_equal_approx(float(verdict["cooldown"]), 4.0) and is_equal_approx(_runner.enemy_hp(near_wave), 500.0 - _D()), "release throws a 1D 2R wave with a 4 s cooldown (%.1f)" % _runner.enemy_hp(near_wave))
	ba.force = 0.0
	_runner.activate_q()
	_player.hp = max_hp
	_player.take_damage(0.4 * max_hp, pair[1])
	_check(absf(_player.hp - (max_hp - 0.4 * max_hp * 0.7)) < 0.5, "at zero Force the guard prevents 30%% (hp %.1f)" % _player.hp)
	ba.release_q("BAQ")

	# ---------------- Guard catches, Mirror, Bulwark, Counterweight, Bunker
	ba = _load(["BA01", "BAQ", "BAQ1", "BAQ2", "BAQ3", "BAQ4"])
	shooter = _spawn_attacker(200.0, origin + Vector2(300, 0))
	_runner.activate_q()
	_check(is_equal_approx(ba.move_speed_multiplier(), 0.5), "Bulwark halves movement while holding")
	_hostile_bullet(origin + Vector2(-40, 0), Vector2.RIGHT, shooter[1])
	_hostile_bullet(origin + Vector2(40, 0), Vector2.LEFT, shooter[1])
	ba.hold_q("BAQ", 0.1)
	_check(int(ba.counters["catches"]) == 2 and ba._guard_pool_stored.size() == 2 and is_equal_approx(ba.force, 20.0), "a 360-degree guard catches from behind too and Mirror stores them (force %.1f)" % ba.force)
	ba.force = 50.0
	var wave_target := _spawn(500.0, origin + Vector2(120, 0))
	bullets_before = ProjectileManager.active_count()
	ba.release_q("BAQ")
	_runner.flush_attacks()
	_check(is_equal_approx(ba.force, 25.0) and is_equal_approx(_runner.enemy_hp(wave_target), 500.0 - _D() - 0.06 * _D() * 25.0), "Counterweight spends half the Force for +0.06D per point (%.1f)" % _runner.enemy_hp(wave_target))
	_check(int(ba.counters["mirror_shots"]) == 2 and ProjectileManager.active_count() == bullets_before + 2, "Mirror fires the stored projectiles back")
	_check(not ba._bunker.is_empty() and is_equal_approx(float(ba._bunker["force"]), 30.0), "Bunker leaves a 3 s guard with 30 Force")
	ba.tick(3.1)
	_runner.flush_attacks()
	_check(ba._bunker.is_empty() and int(ba.counters["bunker_waves"]) == 1 and is_equal_approx(_runner.enemy_hp(wave_target), 500.0 - _D() - 0.06 * _D() * 25.0 - 2.0 * _D()), "an expired Bunker emits a 2D wave (%.1f)" % _runner.enemy_hp(wave_target))

	# ---------------- Martyr and Living Rampart
	ba = _load(["BA01", "BAQ", "BAQ5", "BAQ6"])
	_runner.activate_q()
	ba.force = 0.0
	_player.hp = max_hp
	ba.hold_q("BAQ", 1.0)
	_check(is_equal_approx(_player.hp, max_hp - 0.02 * max_hp) and ba._martyr_active, "Martyr pays 2%% max HP per second to keep 75%% prevention at zero Force (hp %.1f)" % _player.hp)
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 0.25), "the guard then prevents 75%%")
	_player.hp = 0.2 * max_hp
	ba.hold_q("BAQ", 1.0)
	_check(is_equal_approx(_player.hp, 0.2 * max_hp) and not ba._martyr_active, "it stops paying at 25%% HP")
	ba.force = 30.0
	_runner.still_seconds = 0.5
	ba.hold_q("BAQ", 1.0)
	_check(is_equal_approx(ba.force, 30.0), "Living Rampart: no upkeep while standing still")
	_runner.still_seconds = 0.0
	_runner.travel_this_frame = 5.0
	ba.hold_q("BAQ", 1.0)
	_check(is_equal_approx(ba.force, 18.0), "moving resumes upkeep (%.1f)" % ba.force)
	_runner.travel_this_frame = 0.0
	ba.release_q("BAQ")
	_player.hp = max_hp

	# ---------------- Surrounded
	ba = _load(["BA01", "BA07"])
	for angle in [0.0, 60.0, 180.0, 300.0]:
		_spawn(100.0, origin + Vector2.from_angle(deg_to_rad(angle)) * 50.0)
	slash = FakeSlash.new()
	ba.decorate_native_slash(slash)
	_check(is_equal_approx(slash.arc_degrees, 340.0) and int(ba.counters["surrounded"]) == 1, "four enemies within R close the arc into a circle")
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	for handle in _spawned:
		_runner.damage_enemy(handle, 5.0, _native())
	_check(is_equal_approx(ba.force, 5.0), "the rear half grants 5 Force per victim (%.1f)" % ba.force)
	slash.free()

	# ---------------- Slow Leak and decay
	ba = _load(["BA01", "BA11"])
	_spawn(100.0, origin + Vector2(300, 0))
	ba.force = 50.0
	ba.tick(1.0)
	_check(is_equal_approx(ba.force, 40.0), "in combat, two seconds after the last hit Force decays 10 per second (%.1f)" % ba.force)
	ba.tick(1.0)
	_check(is_equal_approx(ba.force, 30.0) and int(ba.counters["scraps"]) == 1, "every 20 Force lost drops a scrap")
	_clear_enemies()
	ba.force = 30.0
	ba.tick(1.0)
	_check(is_equal_approx(ba.force, 30.0), "outside combat Force keeps")

	# ---------------- Last Hit
	ba = _load(["BA01", "BA12"])
	pair = _spawn_attacker(200.0, origin + Vector2(50, 0))
	ba.force = 60.0
	_player.hp = 10.0
	_player.take_damage(50.0, pair[1])
	_check(is_equal_approx(_player.hp, 1.0) and is_equal_approx(ba.force, 0.0) and int(ba.counters["last_hits"]) == 1 and float(_player.get("invulnerable_time")) >= 0.5, "Last Hit: at 50+ Force a lethal hit leaves 1 HP and empties Force")
	_player.hp = max_hp

	# ---------------- forks and keystones
	ba = _load(["BA01", "BA03", "BA04", "BA08", "BAF1"])
	near = _spawn(500.0, origin + Vector2(100, 0))
	ba.add_force(100.0, false)
	_runner.flush_attacks()
	_check(int(ba.counters["full_tanks"]) == 1 and is_equal_approx(ba.force, 0.0) and ba._refill_pause > 0.0, "Pressure Vessel detonates at 100 automatically and pauses refill")
	ba.add_force(20.0)
	_check(is_equal_approx(ba.force, 0.0), "nothing fills during the pause")
	ba = _load(["BA01", "BA03", "BA04", "BA08", "BAF2"])
	ba.add_force(130.0, false)
	_check(is_equal_approx(ba.capacity(), 150.0) and is_equal_approx(ba.force, 130.0) and is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 1.2), "Overpressure: capacity 150, 20%% more damage taken above 100")
	near = _spawn(1000.0, origin + Vector2(100, 0))
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.flush_attacks()
	_check(is_equal_approx(_runner.enemy_hp(near), 1000.0 - 3.0 * _D() - 0.03 * _D() * 30.0), "discharges gain 0.03D per point above 100 (%.1f)" % _runner.enemy_hp(near))
	ba = _load(["BA01", "BA03", "BA04", "BA08", "BAK1"])
	_runner.still_seconds = 0.6
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 0.8), "Anvil: stationary for 0.5 s prevents another 20%%")
	ba.add_force(10.0)
	_check(is_equal_approx(ba.force, 20.0), "and doubles Force gain")
	_runner.still_seconds = 0.0
	ba = _load(["BA01", "BA03", "BA04", "BA08", "BAK2"])
	ba.force = 100.0
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 0.4), "Glass Armor: 60%% reduction at 100 Force")
	_player.stats.armor = 50.0
	ba.force = 0.0
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 150.0 / 125.0), "and armor contribution is halved")
	_player.stats.armor = 0.0

	# ---------------- Heavy Hands
	ba = _load(["BA01", "BA02", "BA03", "BA04", "BA08", "BAA", ["G1", "ranged"], "BR01", "BR02"])
	ba.force = 40.0
	var shot := _spawn(200.0, origin + Vector2(60, 0))
	ba.on_native_fire("ranged", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(shot, 10.0, _native("bullet", "ranged"))
	_runner.flush_attacks()
	_check(is_equal_approx(ba.force, 20.0) and _runner.enemy_hp(shot) < 200.0 - 10.0 - 0.025 * _D() * 20.0 + 0.01, "Heavy Hands: a Ranged strike spends at half the coefficient and adds a 0.5R blast (%.1f)" % _runner.enemy_hp(shot))

	# ---------------- Meltdown
	ba = _load(["BA01", "BA02", "BA03", "BA04", "BA05", "BA06", "BAC"])
	near = _spawn(1000.0, origin + Vector2(60, 0))
	ba.force = 100.0
	ba.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(ba.counters["meltdowns"]) == 1 and ba._rings.size() == 3, "a 100-Force discharge starts Meltdown's three rings")
	ba.tick(0.01)
	ba.tick(0.4)
	ba.tick(0.4)
	_runner.flush_attacks()
	_check(ba._rings.is_empty() and is_equal_approx(_runner.enemy_hp(near), 1000.0 - 3.0 * _D() - 3.0 * 2.0 * _D() - clampf(0.35 * 0.2 * max_hp, 0.2 * _D(), 2.0 * _D())), "the rings deal 2D each and the third fires Thorns' virtual block (%.1f)" % _runner.enemy_hp(near))
	_check(int(ba.counters["razor_rings"]) == 1, "and Razor Guard's ring")

	# ---------------- Gun Shield and Bomb Bunker
	ba = _load(["BA01", "BA04", "BAQ", "BAF1", "BAQ3", "BR06", "BAE1"])
	shooter = _spawn_attacker(200.0, origin + Vector2(300, 0))
	_runner.activate_q()
	_hostile_bullet(origin + Vector2(40, 0), Vector2.LEFT, shooter[1])
	ba.hold_q("BAQ", 0.1)
	bullets_before = ProjectileManager.active_count()
	ba.hold_q("BAQ", 0.1)
	_check(int(ba.counters["gun_shield_shots"]) == 1 and ProjectileManager.active_count() == bullets_before + 1, "Gun Shield fires a stored projectile every 0.15 s while guarding")
	ba.release_q("BAQ")
	ba = _load(["BA01", "BA04", "BAQ", "BAF2", "BAQ4", "BAQ2", "BAE2"])
	near = _spawn(1000.0, origin + Vector2(60, 0))
	_runner.activate_q()
	ba.release_q("BAQ")
	_runner.flush_attacks()
	_check(not ba._bunker.is_empty() and is_equal_approx(float(ba._bunker["life"]), 8.0), "Bomb Bunker lasts 8 s")
	ba._bunker["stored"] = 50.0
	var hp_before_boom := _runner.enemy_hp(near)
	_runner.q_cooldown_left = 0.0
	verdict = _runner.activate_q()
	_runner.flush_attacks()
	_check(verdict["message"] == "DETONATE" and ba._bunker.is_empty() and is_equal_approx(_runner.enemy_hp(near), hp_before_boom - 2.0 * _D() - 0.04 * _D() * 50.0), "a tap while not guarding detonates it for 2D + 0.04D per stored Force (%.1f)" % _runner.enemy_hp(near))

	# ---------------- sinks
	ba = _load(["BA01", "BA03", "BA04", "BA08", "BAS1", "BAS1", "BAS1", "BAS1", "BAS2", "BAS2"])
	_check(is_equal_approx(ba.capacity(), 100.0 + 3.0 * 2.0), "Force Capacity rank 4 adds 3 x sqrt(4)")
	_player.stats.armor = 100.0
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 200.0 / (100.0 + 100.0 * (1.0 + 0.35 * 2.0 / 72.0))), "Armor rank 2 multiplies armor rating by 1 + 35%% x 2/72")
	_player.stats.armor = 0.0

	# ---------------- RUPTURE
	ba = _load(["BA01", "BA02", "BA03", "BA04", "BA05", "BA06", "BAC", "BAV", "BAV1", "BAV2", "BAV3"])
	near = _spawn(5000.0, origin + Vector2(200, 0))
	var other := _spawn(5000.0, origin + Vector2(-200, 100))
	_hostile_bullet(origin + Vector2(100, 100), Vector2.LEFT)
	_hostile_bullet(origin + Vector2(-100, 100), Vector2.RIGHT)
	ba.force = 50.0
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and is_equal_approx(ba.force, 0.0) and ba._rupture_tell > 0.0, "V spends Force and starts the 0.5 s tell")
	ba.tick(0.51)
	_runner.flush_attacks()
	var first := (5.0 * _D() + 0.04 * _D() * 50.0) * 2.0
	var near_hp := _runner.enemy_hp(near)
	var other_hp := _runner.enemy_hp(other)
	_check(int(ba.counters["ruptures"]) == 1 and near_hp <= 5000.0 - first + 0.01 and near_hp >= 5000.0 - first - _D() - 0.01 and other_hp <= 5000.0 - first + 0.01 and other_hp >= 5000.0 - first - _D() - 0.01, "RUPTURE hits every visible enemy for 5D + 0.04D per Force, doubled by Zero Armor, plus Fallout blades (%.1f / %.1f)" % [near_hp, other_hp])
	_check(int(ba.counters["fallout_blades"]) == 2 and ba._no_armor_left > 0.0, "erased projectiles fall as blades and armor is zero for 3 s")
	_player.stats.armor = 50.0
	ba._plate_ready = false
	_check(is_equal_approx(ba.damage_taken_multiplier_for(null, &"unknown"), 1.5), "Zero Armor removes the armor contribution")
	_player.stats.armor = 0.0
	ba.tick(1.01)
	_runner.flush_attacks()
	_check(int(ba.counters["ruptures"]) == 2 and _runner.enemy_hp(near) <= near_hp - first * 0.5 + 0.01 and _runner.enemy_hp(near) >= near_hp - first * 0.5 - _D() - 0.01, "Aftershock repeats after 1 s at half damage (%.1f)" % _runner.enemy_hp(near))

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionBastionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
