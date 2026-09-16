extends Node

# The 24 Fusions that were still missing after the discipline slices, and
# the three Unions. Each is driven through both parent engines.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionFusionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_fu", "res://asc_fu.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _spawn_attacker(hp: float, at: Vector2) -> Array:
	var handle := _spawn(hp, at)
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


func _load(native: String, ids: Array) -> void:
	_clear_enemies()
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
	_runner._q_holding = false
	_runner._dash_active = false
	_runner.still_seconds = 0.0
	_runner.travel_this_frame = 0.0
	_runner.aim_override = _origin + Vector2(200, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_player.get("_dash").cancel()
	_player.get("_dash").cooldown_left = 0.0
	_player.set("invulnerable_time", 0.0)
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	var state: Object = _runner.manifestation_state()
	if state != null:
		state.set("momentum", 0.0)


func _engine(code: String) -> AscensionEngine:
	return _runner.engine_of_discipline(code)


func _D(core: String) -> float:
	return _runner.native_damage_for(core)


func _native(core: String, path: String, execute: bool = false) -> PackedStringArray:
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	if execute:
		tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:1")
	return tags


## Headless frames run at whatever pace the machine allows, so waits are
## measured in resolved projectiles, not frames.
func _settle(max_frames: int = 600) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		if ProjectileManager.active_count() == 0:
			break
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
	var max_hp: float = _player.max_hp
	Global.run_luck = 0.0
	var br: BarrageEngine = null

	# ---------------- MM1 Blood Rite
	_load("melee", ["EX01", "EX04", ["G1", "magic"], "IN01", "IN05", "MM1"])
	var inv := _engine("IN") as InvocationEngine
	var ex := _engine("EX") as ExecutionEngine
	var sigil := inv.place_sigil(origin + Vector2(200, 0))
	sigil["growth"] = 1.0
	var rited := _spawn(100.0, origin + Vector2(210, 0))
	inv.pulse(sigil)
	_check(int(inv.counters.get("blood_rites", 0)) == 1 and is_equal_approx(float(sigil["growth"]), 0.0) and _runner.has_status(rited, "blood_rite") and is_equal_approx(float(_runner.status_of(rited)["blood_rite"]["bonus"]), 0.03), "Blood Rite: a pulse spends one Growth to raise Finish's line on its victims by 3 points")
	_check(is_equal_approx(ex._hit_line({"tags": _native("melee", "slash", true), "path": "slash"}, rited), ex.line() + 0.03), "Execution reads the raised line for that target (%.3f)" % ex._hit_line({"tags": _native("melee", "slash", true), "path": "slash"}, rited))
	_runner.damage_enemy(rited, 100.0, _native("melee", "slash", true))
	_check(not _runner.enemy_alive(rited) and is_equal_approx(float(sigil["growth"]), 3.0), "an execution inside the Sigil returns two Growth on top of Fed by Death (%.1f)" % float(sigil["growth"]))

	# ---------------- MM3 Corpse Well, MR3 Corpse Mortar, MR1 Bloodshot
	_load("melee", ["EX01", "EX05", ["G1", "magic"], "DO01", "MM3"])
	var dom := _engine("DO") as DominionEngine
	ex = _engine("EX") as ExecutionEngine
	var corpse := _spawn(100.0, origin + Vector2(60, 0))
	var mourner := _spawn(500.0, origin + Vector2(140, 0))
	_runner.damage_enemy(corpse, 95.0, _native("melee", "slash", true))
	_check(not _runner.enemy_alive(corpse) and int(ex.counters.get("corpse_wells", 0)) == 1 and dom.wells.size() == 1 and String(dom.wells[0]["kind"]) == "corpse", "Corpse Well: the bomb first leaves a 1 s Well at the corpse")
	ex.tick(1.01)
	_runner.flush_attacks()
	_check(ex._delayed_impacts.is_empty() and _runner.enemy_hp(mourner) < 500.0, "then resolves at +25%% radius (%.1f)" % _runner.enemy_hp(mourner))
	_load("melee", ["EX01", "EX05", ["G1", "ranged"], "OR01", "OR04", "MR3"])
	var orx := _engine("OR") as OrdnanceEngine
	ex = _engine("EX") as ExecutionEngine
	corpse = _spawn(100.0, origin + Vector2(60, 0))
	_spawn(500.0, origin + Vector2(260, 0))
	_runner.damage_enemy(corpse, 95.0, _native("melee", "slash", true))
	_check(int(ex.counters.get("corpse_mortars", 0)) == 1 and orx.shells.size() == 1 and is_equal_approx(float(orx.shells[0]["left"]), 0.4) and (orx.shells[0]["at"] as Vector2).distance_to(origin + Vector2(260, 0)) < 1.0, "Corpse Mortar: the bomb flies to the nearest cluster within 4R as a 0.4 s Shell")
	_load("melee", ["EX01", "EX03", ["G1", "ranged"], "PR01", "PR03", "MR1"])
	ex = _engine("EX") as ExecutionEngine
	var victim := _spawn(10.0, origin + Vector2(60, 0))
	_spawn(500.0, origin + Vector2(120, 0))
	var bullets_before := ProjectileManager.active_count()
	_runner.damage_enemy(victim, 50.0, _native("melee", "slash"))
	_check(int(ex.counters.get("bloodshots", 0)) == 1 and ProjectileManager.active_count() == bullets_before + 1 and ex._bolts.is_empty(), "Bloodshot: Spillover becomes a piercing blood shot")

	# ---------------- MM4 Riftwalk, MM5 Double Step, MM6 Slingshot
	_load("melee", ["MO01", "MO02", ["G1", "magic"], "IN01", "IN12", "MM4"])
	inv = _engine("IN") as InvocationEngine
	sigil = inv.place_sigil(origin + Vector2(80, 0))
	var pulses_before := int(inv.counters["pulses"])
	inv.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(inv.counters.get("riftwalks", 0)) == 1 and (sigil["at"] as Vector2).distance_to(origin + Vector2(160, 0)) < 15.0 and int(inv.counters["pulses"]) == pulses_before + 1, "Riftwalk: a dash through a Sigil carries it to the endpoint and pulses it")
	_load("melee", ["MO01", "MO04", ["G1", "magic"], "DT01", "MM5"])
	var mo := _engine("MO") as MomentumEngine
	_runner._rng = RandomNumberGenerator.new()
	_runner._rng.seed = 7
	for i in range(30):
		mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
		if int(mo.counters.get("double_steps", 0)) > 0:
			break
	_check(int(mo.counters.get("double_steps", 0)) >= 1 and int(mo.counters["afterimages"]) >= 1, "Double Step: Twice repeats the dash's endpoint slash at its start and leaves an Afterimage")
	_load("melee", ["MO01", "MO06", "MO02", ["G1", "magic"], "DO01", "MM6"])
	mo = _engine("MO") as MomentumEngine
	dom = _engine("DO") as DominionEngine
	mo.add_momentum(70.0)
	dom.place_well(origin + Vector2(200, 0), "well", false)
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(mo.counters.get("slingshots", 0)) == 1 and _player.global_position.distance_to(origin + Vector2(240, 0)) < 1.0 and _player.is_dashing(), "Slingshot: a dash ending in a Well swings around its centre and releases toward aim (%s)" % str(_player.global_position))
	_player.get("_dash").cancel()
	_player.global_position = origin

	# ---------------- MM7 Ward, MM8 Backlash, MM9 Gravity Armor
	_load("melee", ["BA01", "BA03", ["G1", "magic"], "IN01", "IN05", "IN07", "MM7"])
	var ba := _engine("BA") as BastionEngine
	inv = _engine("IN") as InvocationEngine
	sigil = inv.place_sigil(origin)
	sigil["growth"] = 2.0
	ba.tick(1.05)
	_check(ba._plate_ready, "Ward: inside a grown Sigil Plate reforms in 1 s")
	var pair := _spawn_attacker(500.0, origin + Vector2(40, 0))
	_player.take_damage(0.2 * max_hp, pair[1])
	_check(int(ba.counters.get("wards", 0)) == 1 and is_equal_approx(float(sigil["growth"]), 3.0) and (sigil["echoes"] as Array).size() >= 1, "a Plate broken there stores a 1D Echo and adds two Growth (growth %.1f)" % float(sigil["growth"]))
	_load("melee", ["BA01", "BA06", "BAQ", ["G1", "magic"], "DT06", "MM8"])
	ba = _engine("BA") as BastionEngine
	var dt := _engine("DT") as DistortionEngine
	pair = _spawn_attacker(500.0, origin + Vector2(50, 0))
	ba.force = 40.0
	_runner.activate_q()
	_player.take_damage(0.4 * max_hp, pair[1])
	var buckets: Array = dt.debts.get(pair[0], [])
	_check(buckets.size() == 1 and String(buckets[0]["source"]) == "backlash", "Backlash: Thorns deposits half its damage as Debt on the attacker")
	ba.release_q("BAQ")
	var force_before := ba.force
	dt.tick(2.1)
	_check(int(dt.counters.get("backlash_refunds", 0)) == 1 and is_equal_approx(ba.force, force_before + 10.0), "matured Backlash Debt returns 10 Force (%.1f)" % ba.force)
	_load("melee", ["BA01", "BA02", ["G1", "magic"], "DO01", "MM9"])
	ba = _engine("BA") as BastionEngine
	var orbiter := _spawn(500.0, origin + Vector2(60, 0))
	ba.force = 70.0
	ba.tick(0.2)
	_check(ba._orbiters.has(orbiter) and _runner.enemy_position(orbiter).y != origin.y, "Gravity Armor: above 60 Force nearby normals orbit you")
	ba.spend_force(20.0)
	_check(int(ba.counters.get("orbiters_thrown", 0)) == 1 and _runner.enemy_hp(orbiter) < 500.0 - 0.8 * _D("melee") + 0.01, "spending 20 Force throws orbiters toward aim for 0.8D")
	ba.force = 110.0
	_check(is_equal_approx(ba.move_speed_multiplier(), 0.8), "above 100 Force movement is 20%% slower")

	# ---------------- MR4 Rail Dash, MR6 Mine Runner, MR7 Countershot
	_load("melee", ["MO01", "MO09", ["G1", "ranged"], "PR01", "PR07", "MR4"])
	mo = _engine("MO") as MomentumEngine
	_runner.spawn_bullet(origin + Vector2(150, 0), Vector2.LEFT, 10.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR07", "return", 1, 0.5, PackedStringArray(["core_strike", "return"])), {"max_range": 600.0})
	var before_count := ProjectileManager.active_count()
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(mo.counters.get("rail_dashes", 0)) == 1 and ProjectileManager.active_count() == before_count, "Rail Dash: a returning shot near the endpoint is caught and released toward aim")
	_load("melee", ["MO01", "MO02", "MO06", ["G1", "ranged"], "OR01", "OR02", "MR6"])
	mo = _engine("MO") as MomentumEngine
	orx = _engine("OR") as OrdnanceEngine
	var rammed := _spawn(500.0, origin + Vector2(80, 0))
	_runner.status_of(rammed)["prime"] = 999.0
	mo.on_dash_ended(origin, origin + Vector2(160, 0), Vector2.RIGHT)
	_check(int(mo.counters.get("mine_runners", 0)) == 1 and orx.mines.size() == 1 and is_equal_approx(float(orx.mines[0]["life"]), 0.5), "Mine Runner: ramming attaches a fresh Mine that lives 0.5 s")
	_load("ranged", ["PR01", "PR03", "PR04", ["G1", "melee"], "BA01", "BA02", "MR7"])
	var pr := _engine("PR") as PrecisionEngine
	var reflected_target := _spawn(500.0, origin + Vector2(60, 0))
	var reflected := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA02", "return", 1, 0.4)
	_runner.spawn_bullet(origin, Vector2.RIGHT, 5.0, reflected, {"max_range": 200.0})
	await _settle()
	_check(pr.is_exposed(reflected_target), "Countershot: a reflected shot exposes its first target after damage")
	before_count = ProjectileManager.active_count()
	_runner.spawn_bullet(origin, Vector2.RIGHT, 5.0, reflected, {"max_range": 200.0})
	await _settle()
	_check(int(pr.counters.get("countershots", 0)) == 1 and not pr.is_exposed(reflected_target), "a reflected shot consuming a Weak Point returns once for 0.8D")

	# ---------------- MR5 Run and Gun
	_load("melee", ["MO01", "MO04", ["G1", "ranged"], "BR01", "BR06", "MR5"])
	mo = _engine("MO") as MomentumEngine
	br = _engine("BR") as BarrageEngine
	mo.add_momentum(60.0)
	before_count = ProjectileManager.active_count()
	mo.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	mo.tick(0.31)
	_runner.flush_attacks()
	_check(int(mo.counters.get("run_and_gun_shots", 0)) == 1 and ProjectileManager.active_count() == before_count + 1, "Run and Gun: an Afterimage fires a 0.6D Ranged shot toward aim when it slashes")
	var afterimages_before := int(mo.counters["afterimages"])
	for i in range(3):
		br._crossfire_shot(5.0, 0.4, "BR06")
	_check(int(br.counters.get("run_and_gun_afterimages", 0)) == 1 and int(mo.counters["afterimages"]) == afterimages_before + 1, "every third Crossfire shot leaves a 0.5D Melee Afterimage at its origin")
	await _settle()

	# ---------------- MR8 Heavy Barrel, MR9 Reactive Armor
	_load("ranged", ["BR01", "BR02", "BR08", ["G1", "melee"], "BA01", "MR8"])
	br = _engine("BR") as BarrageEngine
	ba = _engine("BA") as BastionEngine
	ba.force = 80.0
	before_count = ProjectileManager.active_count()
	br._jam()
	_check(is_equal_approx(float(br.counters.get("heavy_barrel_force", 0.0)), 60.0) and is_equal_approx(ba.force, 20.0) and ProjectileManager.active_count() == before_count + 12, "Heavy Barrel: a Jam spends up to 60 Force across its rounds")
	_load("melee", ["BA01", "BA06", "BAQ", ["G1", "ranged"], "OR01", "OR02", "OR06", "MR9"])
	ba = _engine("BA") as BastionEngine
	orx = _engine("OR") as OrdnanceEngine
	pair = _spawn_attacker(500.0, origin + Vector2(50, 0))
	ba.force = 40.0
	_runner.activate_q()
	_player.take_damage(0.4 * max_hp, pair[1])
	_check(int(ba.counters.get("reactive_mines", 0)) == 3 and orx.mines.size() == 3, "Reactive Armor: 30%% of max HP prevented drops three Mines (cap) at your feet")
	ba.release_q("BAQ")

	# ---------------- RM1 Spellshot, RM2 Backtrack, RM3 Gravity Round
	_load("ranged", ["PR01", "PR03", ["G1", "magic"], "IN01", "IN06", "RM1"])
	inv = _engine("IN") as InvocationEngine
	sigil = inv.place_sigil(origin + Vector2(80, 0))
	(sigil["echoes"] as Array).append(inv._new_echo("magic", origin, origin + Vector2(80, 0), 0.6 * _D("magic"), 0.4))
	var loaded_target := _spawn(500.0, origin + Vector2(200, 0))
	var profile := HitProfileAdapter.new()
	profile.reset(10.0)
	_runner.apply_to_managed_hit_profile(profile, &"ranged")
	ProjectileManager.spawn_player(origin, Vector2.RIGHT, profile, _player)
	await _settle()
	_check(int(inv.counters.get("spellshot_loads", 0)) == 1 and int(inv.counters.get("spellshots", 0)) == 1 and (sigil["echoes"] as Array).is_empty(), "Spellshot: a piercing shot crossing a Sigil loads an Echo and releases it at its next impact")
	_check(loaded_target != 0, "target present")
	_load("ranged", ["PR01", "PR07", ["G1", "magic"], "DT06", "DTA", "RM2"])
	dt = _engine("DT") as DistortionEngine
	var indebted := _spawn(500.0, origin + Vector2(100, 0))
	dt.deposit(indebted, 20.0, "core", false)
	(dt.debts[indebted] as Array)[0]["due"] = dt._clock + 0.3
	_runner.spawn_bullet(origin, Vector2.RIGHT, 5.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR07", "return", 1, 0.5, PackedStringArray(["core_strike", "return"])), {"max_range": 300.0, "pierce": 2})
	await _settle()
	var core_left := false
	for bucket in dt.debts.get(indebted, []):
		if String(bucket["source"]) == "core":
			core_left = true
	_check(int(dt.counters.get("backtracks", 0)) == 1 and not core_left and _runner.enemy_hp(indebted) < 500.0 - 5.0 - 19.0, "Backtrack: a return hastens the oldest bucket 0.5 s; its maturity adds +0.3D to the shot (%.1f)" % _runner.enemy_hp(indebted))
	_load("ranged", ["PR01", "PR03", "PR04", ["G1", "magic"], "DO01", "RM3"])
	pr = _engine("PR") as PrecisionEngine
	dom = _engine("DO") as DominionEngine
	var exposed := _spawn(500.0, origin + Vector2(100, 0))
	_runner.status_of(exposed)["weak_point"] = 999.0
	_runner.spawn_bullet(origin, Vector2.RIGHT, 5.0, _native("ranged", "bullet"), {"max_range": 300.0})
	await _settle()
	_check(int(pr.counters.get("gravity_rounds", 0)) == 1 and dom.wells.size() == 1 and (dom.wells[0]["at"] as Vector2).x > origin.x + 150.0 and is_equal_approx(pr._gravity_bonus, AscensionRunner.R * 0.25), "Gravity Round: consuming a Weak Point leaves a Well ahead of the shot and widens later Wells")

	# ---------------- RM4 Bullet Runes, RM6 Stormwire
	_load("ranged", ["BR01", "BR06", ["G1", "magic"], "IN01", "RM4"])
	br = _engine("BR") as BarrageEngine
	inv = _engine("IN") as InvocationEngine
	_runner.aim_override = origin
	var rune_target := _spawn(5000.0, origin)
	for i in range(3):
		br._crossfire_shot(5.0, 0.4, "BR06")
	await _settle()
	_check(int(br.counters.get("bullet_runes", 0)) == 1 and inv.sigils.size() == 1 and String(inv.sigils[0]["kind"]) == "rune", "Bullet Runes: every third Crossfire shot leaves a rune Sigil at its first impact (%d)" % inv.sigils.size())
	before_count = ProjectileManager.active_count()
	inv.pulse(inv.sigils[0])
	_check(ProjectileManager.active_count() == before_count + 1, "a rune Sigil fires a 0.5D shot per pulse instead of radial damage")
	_check(rune_target != 0, "rune target present")
	_runner.aim_override = origin + Vector2(200, 0)
	_load("ranged", ["BR01", "BR09", ["G1", "magic"], "DO01", "DO05", "DO07", "RM6"])
	dom = _engine("DO") as DominionEngine
	var w1 := _spawn(500.0, origin + Vector2(100, 0))
	var w2 := _spawn(500.0, origin + Vector2(130, 0))
	var w3 := _spawn(500.0, origin + Vector2(160, 0))
	dom.make_link([w1, w2, w3])
	_runner.damage_enemy(w1, 10.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR09", "ricochet", 1, 0.6))
	_check(int(dom.counters.get("wires", 0)) == 2 and _runner.enemy_hp(w2) < 500.0 and _runner.enemy_hp(w3) < 500.0, "Stormwire: a ricochet on a Linked enemy runs along the unvisited members for 0.5D")

	# ---------------- RM7 Rune Bomb, RM8 Time Bomb, RM9 Meteor
	_load("ranged", ["OR01", "OR02", ["G1", "magic"], "IN01", "IN05", "IN09", "RM7"])
	orx = _engine("OR") as OrdnanceEngine
	inv = _engine("IN") as InvocationEngine
	sigil = inv.place_sigil(origin + Vector2(200, 0))
	orx.drop_mine(origin + Vector2(210, 0))
	orx.tick(0.4)
	_check(int(orx.counters.get("rune_bombs", 0)) == 1 and int(orx.mines[0]["sigil"]) == int(sigil["id"]), "Rune Bomb: an armed Mine inside a Sigil attaches to it")
	inv._detonate(sigil, false)
	_check(orx.mines.is_empty() and int(orx.counters["mine_blasts"]) == 1 and int(inv.counters["detonations"]) == 1, "detonating the Sigil explodes the attached Mine once")
	_load("ranged", ["OR01", "OR04", ["G1", "magic"], "DT06", "DT09", "RM8"])
	orx = _engine("OR") as OrdnanceEngine
	dt = _engine("DT") as DistortionEngine
	var bombed := _spawn(1.0, origin + Vector2(200, 0))
	dt.deposit(bombed, 40.0, "core", false)
	orx.call_shell(origin + Vector2(200, 0))
	orx.tick(0.7)
	_runner.flush_attacks()
	if orx.shells.is_empty():
		orx.shells.append({"left": -1.0, "bonus": -1.0})
	_check(not _runner.enemy_alive(bombed) and int(orx.counters.get("time_bombs", 0)) == 1 and orx.shells.size() == 1 and is_equal_approx(float(orx.shells[0]["left"]), 1.1) and is_equal_approx(float(orx.shells[0]["bonus"]), 30.0), "Time Bomb: the Secondary Blast Shell collects the corpse's Debt, lands 0.5 s later with 75%% of it")
	_load("ranged", ["OR01", "OR12", ["G1", "magic"], "DO01", "RM9"])
	orx = _engine("OR") as OrdnanceEngine
	dom = _engine("DO") as DominionEngine
	orx._shell_count = 6
	var meteor := orx.call_shell(origin + Vector2(200, 0))
	_check(int(orx.counters.get("meteors", 0)) == 1 and is_equal_approx(float(meteor["damage"]), 6.0 * _D("ranged")) and is_equal_approx(float(meteor["left"]), 1.0) and dom.wells.size() == 1, "Meteor: Big One becomes 6D in 2R after 1 s with a Well at the landing")

	# ---------------- Unions
	_load("melee", ["EX01", "EX02", ["G1", "magic"], "IN01", "IN06", "DO01", "MM1", "MM3", "MM4", "UMM"])
	var un := _engine("UN") as UnionEngine
	inv = _engine("IN") as InvocationEngine
	dom = _engine("DO") as DominionEngine
	_check(un != null, "INCARNATE: the Union engine loads")
	sigil = inv.place_sigil(origin + Vector2(300, 0))
	(sigil["echoes"] as Array).append(inv._new_echo("magic", origin, origin + Vector2(60, 0), 10.0, 0.4))
	dom.place_well(origin + Vector2(300, 0), "well", false)
	un.tick(0.01)
	_check((sigil["at"] as Vector2).distance_to(origin) <= AscensionRunner.R + 0.01 and (dom.wells[0]["at"] as Vector2).distance_to(origin) <= AscensionRunner.R + 0.01, "your body carries the newest Sigil and Well within R")
	var through := _spawn(500.0, sigil["at"])
	un.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(through, 10.0, _native("melee", "slash"))
	_check(int(un.counters["incarnate_commands"]) == 1 and (sigil["echoes"] as Array).is_empty(), "a native Melee hit through the Sigil releases an Echo and commands a pull, once per input")
	_runner.damage_enemy(through, 10.0, _native("melee", "slash"))
	_check(int(un.counters["incarnate_commands"]) == 1, "once per native input")
	pair = _spawn_attacker(500.0, origin + Vector2(40, 0))
	_player.take_damage(0.1 * max_hp + 1.0, pair[1])
	_check(int(un.counters["incarnate_commands"]) == 2, "taking 10%% max HP commands both again")
	_load("melee", ["EX01", "EX02", ["G1", "ranged"], "BR01", "PR01", "MR1", "MR2", "MR3", "UMR"])
	un = _engine("UN") as UnionEngine
	var loader := _spawn(5000.0, origin + Vector2(60, 0))
	for i in range(6):
		_runner.damage_enemy(loader, 5.0, _native("melee", "slash"))
	_check(un.rack == 6, "TOTAL OFFENSIVE: Melee hits load the six-round rack (%d)" % un.rack)
	before_count = ProjectileManager.active_count()
	un.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(un.rack == 0 and int(un.counters["rack_volleys"]) == 1 and ProjectileManager.active_count() == before_count + 6, "a native Melee input with a full rack fires it across the arc")
	_runner.damage_enemy(loader, 5.0, _native("melee", "slash"))
	before_count = ProjectileManager.active_count()
	_runner.damage_enemy(loader, 5.0, _native("ranged", "bullet"))
	_check(un.rack == 0 and ProjectileManager.active_count() == before_count + 1, "a Ranged Core hit fires one loaded round")
	un.note_trigger("jam")
	_check(un.rack == 3 and int(un.counters["rack_dumps"]) == 1, "a Jam dumps the rack and loads three")
	_load("ranged", ["BR01", "BR02", ["G1", "magic"], "IN01", "DT06", "DO01", "RM1", "RM2", "RM3", "URM"])
	un = _engine("UN") as UnionEngine
	inv = _engine("IN") as InvocationEngine
	dt = _engine("DT") as DistortionEngine
	dom = _engine("DO") as DominionEngine
	var spelled := _spawn(5000.0, origin + Vector2(60, 0))
	for i in range(4):
		un.on_native_fire("ranged", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(spelled, 5.0, _native("ranged", "bullet"))
	_check(int(un.counters["spell_shots"]) == 1 and inv.sigils.size() == 1, "ARCANE BALLISTICS: every fourth Ranged input loads a spell rule; the first is a Sigil at the target")
	for i in range(4):
		un.on_native_fire("ranged", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(spelled, 5.0, _native("ranged", "bullet"))
	_check(dt.debts.has(spelled), "the next cycles to 1D Debt")
	for i in range(4):
		un.on_native_fire("ranged", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(spelled, 5.0, _native("ranged", "bullet"))
	_check(dom.wells.size() == 1, "then a Well")
	before_count = ProjectileManager.active_count()
	un.on_native_fire("magic", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check(int(un.counters["magic_shots"]) == 1 and ProjectileManager.active_count() == before_count + 1, "a native Magic input fires one piercing Ranged shot through aim")

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionFusionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
