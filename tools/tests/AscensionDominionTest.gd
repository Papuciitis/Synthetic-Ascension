extends Node

# Dominion (Magic): Wells, Links, Weight; Gravity Well, Dead Weight,
# Lingering Weight, Collision, Bind, Dragnet, Collective Burden, Crushing,
# Anchor, Collapse, Crowded Well, Compel with its six mutations, both forks,
# both keystones, Common Ground, Black Hole, both Evolutions, the sinks and
# KNEEL. Throw needs terrain, which the headless world lacks.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionDominionTest.tscn

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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_do", "res://asc_do.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	ProjectileManager.clear_for_run_end()
	_runner.flush_attacks()


func _load(ids: Array) -> DominionEngine:
	_clear_enemies()
	Global.selected_style_id = "magic"
	Global.attempt_ascension = AscensionLedger.fresh_state("magic")
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
	_runner.aim_override = _origin + Vector2(200, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for entry in ids:
		var id := String(entry[0]) if entry is Array else String(entry)
		var engine := _runner.engine_for(id) as DominionEngine
		if engine != null:
			return engine
	return null


func _D() -> float:
	return _runner.native_damage_for("magic")


func _native(core: String = "magic", path: String = "impact") -> PackedStringArray:
	var tags := AscensionTags.native(core, path)
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

	# ---------------- Gravity Well and the pull
	var dom := _load(["DO01", "DO02"])
	var centre := origin + Vector2(300, 0)
	var target := _spawn(500.0, centre)
	var puller := _spawn(500.0, centre + Vector2(100, 0))
	var elite := _spawn(500.0, centre + Vector2(0, 100), EnemyWorldTypes.Flags.ELITE)
	for i in range(2):
		_runner.damage_enemy(target, 5.0, _native())
	_check(dom != null and dom.wells.is_empty(), "two weighted Magic Core hits leave nothing")
	_runner.damage_enemy(target, 5.0, _native())
	_check(dom.wells.size() == 1 and is_equal_approx(_runner.enemy_hp(puller), 500.0 - 0.5 * _D()), "the third leaves a Well at the impact; placement deals 0.5D in 1.5R (%.1f)" % _runner.enemy_hp(puller))
	dom.tick(0.25)
	_check(absf(_runner.enemy_position(puller).x - (centre.x + 100.0 - 40.0)) < 1.0, "normals are pulled R over 0.5 s (%s)" % str(_runner.enemy_position(puller)))
	_check(absf(_runner.enemy_position(elite).y - (centre.y + 100.0 - 26.67)) < 1.0, "elites move R/3 (%s)" % str(_runner.enemy_position(elite)))
	dom.tick(0.5)
	_check(absf(_runner.enemy_position(puller).x - (centre.x + 20.0)) < 1.0 and dom.weight > 0.0, "a normal stops after R; an elite resisting the rest stores Weight (%.1f)" % dom.weight)
	dom.tick(1.0)
	_check(dom.wells.is_empty(), "a Well lives 1.5 s")
	for handle in [target, puller, elite]:
		EnemyWorld.remove_enemy(handle, &"test")
	dom.weight = 100.0
	var far := _spawn(500.0, centre + Vector2(110, 0))
	dom.place_well(centre)
	for i in range(6):
		dom.tick(0.25)
	_check(_runner.enemy_position(far).distance_to(centre) < 2.0 and is_equal_approx(dom.weight, 0.0), "Dead Weight: the next pull spends stored Weight for travel beyond R (%s)" % str(_runner.enemy_position(far)))

	# ---------------- Lingering Weight, Collision, Crowded Well
	dom = _load(["DO01", "DO03", "DO04", "DO12"])
	dom.place_well(centre)
	dom.tick(1.6)
	_check(dom.wells.is_empty() and dom.stains.size() == 1 and int(dom.counters["stains"]) == 1, "an expired Well leaves a stain")
	var crossed := _spawn(500.0, centre + Vector2(60, 0))
	dom.place_well(centre + Vector2(120, 0))
	_check(dom.stains.is_empty() and int(dom.counters["stain_pulls"]) == 1 and _runner.enemy_hp(crossed) < 500.0 - 0.5 * _D() + 0.01, "a new Well within 2R consumes it and pulls once along the line for 0.5D (%.1f)" % _runner.enemy_hp(crossed))
	dom = _load(["DO01", "DO04", "DO12"])
	var mover := _spawn(500.0, centre + Vector2(100, 0))
	var wall := _spawn(500.0, centre + Vector2(70, 0))
	dom.place_well(centre)
	dom.tick(0.2)
	_check(int(dom.counters["collisions"]) == 1 and _runner.enemy_hp(mover) < 500.0 and _runner.enemy_hp(wall) < 500.0, "Collision: a pulled normal crossing another deals 0.6D to both once")
	dom.on_player_dashed(origin, Vector2.RIGHT)
	_runner.damage_enemy(mover, 5.0, _native())
	dom.tick(0.01)
	_check(dom.wells.size() == 2 and is_equal_approx(dom._well_radius(dom.wells[1]), 1.5 * AscensionRunner.R * 1.1), "Crowded Well: the impact after a dash creates a Well; each enemy inside adds 5%% radius (%.1f)" % dom._well_radius(dom.wells[1]))

	# ---------------- Bind, Collective Burden, Collapse, Dragnet
	dom = _load(["DO05", "DO07", "DO11"])
	var a := _spawn(500.0, origin + Vector2(200, 0))
	var b := _spawn(500.0, origin + Vector2(230, 0))
	var c := _spawn(500.0, origin + Vector2(260, 0))
	dom.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_runner.damage_enemy(a, 10.0, _native())
	_check(dom.links.is_empty(), "one victim binds nothing")
	_runner.damage_enemy(b, 10.0, _native())
	_check(dom.links.size() == 1 and (dom.links[0]["members"] as Array).size() == 2 and _runner.has_status(a, "link"), "a Magic Core impact hitting two enemies links them for 3 s")
	_check(is_equal_approx(_runner.enemy_hp(a), 500.0 - 10.0 - 2.0), "Collective Burden copies 20%% of a member's damage to the others (%.1f)" % _runner.enemy_hp(a))
	_runner.damage_enemy(c, 10.0, _native())
	_check((dom.links[0]["members"] as Array).size() == 3, "later victims of the same activation join")
	_runner.damage_enemy(a, 1000.0, _native())
	_check(not _runner.enemy_alive(a) and dom.links.is_empty() and int(dom.counters["collapses"]) == 1 and _runner.enemy_position(b).x < origin.x + 230.0 and _runner.enemy_hp(b) < 500.0 - 0.8 * _D() + 0.01, "Collapse: the first death pulls survivors R toward the corpse for 0.8D and breaks the Link (%s)" % str(_runner.enemy_position(b)))
	dom.tick(3.1)
	dom = _load(["DO01", "DO05", "DO06"])
	var linked_a := _spawn(500.0, centre + Vector2(5, 0))
	var linked_b := _spawn(500.0, centre + Vector2(0, 5))
	dom.make_link([linked_a, linked_b])
	var stray := _spawn(500.0, centre + Vector2(60, 0))
	dom.place_well(centre)
	dom.tick(0.2)
	dom.tick(0.2)
	_check(int(dom.counters["dragnets"]) == 1 and not dom.link_of(stray).is_empty(), "Dragnet: a pulled enemy crossing a Linked one joins the group")

	# ---------------- Crushing, Anchor
	dom = _load(["DO01", "DO08"])
	for i in range(4):
		_spawn(500.0, centre + Vector2(5 * i, 0))
	var well := dom.place_well(centre)
	dom.tick(0.31)
	_check(bool(well["shrunk"]) and int(dom.counters["crush_hits"]) == 1 and is_equal_approx(dom._well_radius(well), 1.5 * AscensionRunner.R * 0.8), "Crushing: four enemies shrink the Well 20%% and its centre is hit 0.5D every 0.3 s")
	for i in range(4):
		dom.tick(0.31)
	_check(int(dom.counters["crush_hits"]) == 4, "up to four hits")
	dom.tick(0.5)
	_runner.flush_attacks()
	_check(int(dom.counters["crush_releases"]) == 1 and _runner.enemy_hp(_spawned[0]) < 500.0 - 4.0 * 0.5 * _D(), "expiry releases 0.5D per completed hit in 2R")
	dom = _load(["DO01", "DO09"])
	var big := _spawn(5000.0, centre + Vector2(60, 0))
	var small := _spawn(100.0, centre + Vector2(-60, 0))
	well = dom.place_well(centre)
	dom.tick(0.2)
	_check(int(well["anchor"]) == big and int(dom.counters["anchors"]) == 1 and (well["at"] as Vector2).x > centre.x and _runner.enemy_position(small).x > centre.x - 60.0, "Anchor: the highest-max-HP enemy anchors the Well; everyone is pulled toward it")

	# ---------------- Compel and mutations
	dom = _load(["DO01", "DO05", "DOQ"])
	var cone := _spawn(500.0, origin + Vector2(160, 20))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(_runner.q_cooldown_left, 6.0) and is_equal_approx(_runner.enemy_hp(cone), 500.0 - _D() - 0.5 * _D()) and _runner.enemy_position(cone).distance_to(origin + Vector2(200, 0)) < 45.0 and dom.wells.size() == 1, "Compel pulls the cone toward the cursor up to R for 1D and leaves a Well (0.5D placement) at convergence (%s)" % str(_runner.enemy_position(cone)))
	dom = _load(["DO01", "DO05", "DOQ", "DOQ1", "DOQ2", "DOQ6"])
	var ring_a := _spawn(500.0, origin + Vector2(200, 150))
	var ring_b := _spawn(500.0, origin + Vector2(200, -150))
	var ring_c := _spawn(500.0, origin + Vector2(210, 0))
	_runner.activate_q()
	_check(_runner.enemy_position(ring_a).y < origin.y + 150.0 - 70.0 and _runner.enemy_position(ring_b).y > origin.y - 150.0 + 70.0, "Ring: a 2.5R circle at the cursor pulls from every side")
	_check(dom.links.size() == 1 and (dom.links[0]["members"] as Array).size() == 3, "Chain links the affected enemies in distance order")
	_check(int(dom.counters["crushes"]) >= 1 and _runner.enemy_hp(ring_c) <= 500.0 - _D() - (_D() + 0.25 * _D() * 3.0) + 0.01, "Crush: bodies reaching the centre take 1D + 0.25D per body moved (%.1f)" % _runner.enemy_hp(ring_c))
	dom = _load(["DO01", "DO05", "DOQ", "DOQ3", "DOQ4", "DOQ5"])
	var shoved := _spawn(500.0, origin + Vector2(160, 0))
	_runner.activate_q()
	dom.hold_q("DOQ", 0.35)
	verdict = dom.release_q("DOQ")
	_check(bool(verdict["ok"]) and _runner.enemy_position(shoved).x > origin.x + 160.0 + AscensionRunner.R + 1.5 * AscensionRunner.R - 1.0, "Repulse: holding 0.3 s shoves outward instead; Throw sends bodies another 1.5R (%s)" % str(_runner.enemy_position(shoved)))
	var hp_after_shove := _runner.enemy_hp(shoved)
	dom.tick(1.01)
	_check(int(dom.counters["repeats"]) == 1 and _runner.enemy_hp(shoved) <= hp_after_shove, "Repeat: after 1 s Compel repeats at 60%% in the opposite direction")

	# ---------------- forks, keystones, axiom
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DOF1"])
	for i in range(6):
		_spawn(500.0, centre + Vector2(40 * cos(float(i)), 40 * sin(float(i))))
	dom.place_well(centre)
	dom.tick(0.05)
	_check(int(dom.counters["singularities"]) == 1 and dom.wells.is_empty() and _runner.enemy_position(_spawned[0]).distance_to(centre) < 8.0 and _runner.enemy_hp(_spawned[0]) < 500.0 - 1.5 * _D() + 0.01, "Singularity: six normals collapse to the centre for 1.5D and the Well expires")
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DOF2"])
	var orbiter := _spawn(500.0, centre + Vector2(60, 0))
	dom.place_well(centre)
	dom.tick(0.1)
	_check(int(dom.counters["orbits"]) == 1 and absf(_runner.enemy_position(orbiter).distance_to(centre) - 60.0) < 1.0 and _runner.enemy_position(orbiter).y != centre.y, "Forced Orbit: Wells move normals around the centre instead of inward")
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DO07", "DOK1"])
	_runner.still_seconds = 0.8
	dom.tick(0.01)
	_check(dom.territories.size() == 1 and int(dom.counters["territories"]) == 1 and is_equal_approx(dom.pull_speed(), AscensionRunner.R / 0.5 * 1.5), "Sovereign Ground: standing still 0.75 s leaves a territory; inside it pull speed gains 50%%")
	_player.global_position = origin + Vector2(600, 0)
	var outside := _spawn(500.0, origin + Vector2(700, 0))
	_runner.damage_enemy(outside, 10.0, AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOQ", "pull", 1, 1.0))
	_check(is_equal_approx(_runner.enemy_hp(outside), 500.0 - 7.5), "outside all territory Dominion damage is 25%% lower (%.1f)" % _runner.enemy_hp(outside))
	_player.global_position = origin
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DOK2"])
	var distant := _spawn(500.0, centre + Vector2(400, 0))
	well = dom.place_well(centre)
	dom.tick(0.2)
	_check(_runner.enemy_position(distant).x < centre.x + 400.0 - 20.0, "Event Horizon: the acquisition radius is the visible camera (%s)" % str(_runner.enemy_position(distant)))
	_check(_player.global_position.x > origin.x + 10.0, "the strongest Well pulls the player at 0.5L/s (%s)" % str(_player.global_position))
	dom.tick(1.4)
	_runner.flush_attacks()
	_check(int(dom.counters["horizons"]) == 1, "at expiry it collapses for 2D in 2R")
	_player.global_position = origin
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DO05", "DOA", ["G1", "melee"], "EX01", "EX02"])
	var m1 := _spawn(500.0, origin + Vector2(50, 0))
	var m2 := _spawn(500.0, origin + Vector2(50, 20))
	dom.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_runner.damage_enemy(m1, 10.0, _native("melee", "slash"))
	_runner.damage_enemy(m2, 10.0, _native("melee", "slash"))
	_check(dom.links.size() == 1, "Common Ground: a wide melee swing binds its victims")

	# ---------------- Black Hole
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DO05", "DO06", "DOC"])
	for i in range(20):
		_spawn(500.0, centre + Vector2(60 * cos(float(i) * 0.31), 60 * sin(float(i) * 0.31)))
	well = dom.place_well(centre)
	dom.tick(0.05)
	_check(int(dom.counters["black_holes"]) == 1 and float(well["black"]) > 0.0, "twenty normals in a Well make a Black Hole")
	dom.tick(1.0)
	_runner.flush_attacks()
	_check(dom.wells.is_empty() and dom._hole_recovery > 0.0 and _runner.enemy_hp(_spawned[0]) <= 500.0 - 0.5 * _D() - 8.0 * _D() + 0.01, "its collapse deals 2D + 0.3D per enemy caught, capped at 8D, in 3R (%.1f)" % _runner.enemy_hp(_spawned[0]))

	# ---------------- Evolutions and sinks
	dom = _load(["DO01", "DO05", "DO11", "DOQ", "DOF1", "DOQ6", "DOE1"])
	var buried := _spawn(5.0, origin + Vector2(190, 0))
	var mourner := _spawn(500.0, origin + Vector2(300, 0))
	_runner.activate_q()
	_check(int(dom.counters["graves"]) == 1 and not _runner.enemy_alive(buried) and int(dom.counters["grave_pulses"]) == 1, "Mass Grave: Compel leaves a 3R grave; a death in it pulls survivors and pulses 1D")
	_runner.flush_attacks()
	_check(_runner.enemy_position(mourner).x < origin.x + 300.0, "survivors are pulled R toward the corpse (%s)" % str(_runner.enemy_position(mourner)))
	dom = _load(["DO01", "DO04", "DOQ", "DOF2", "DOQ5", "DOE2"])
	var ball := _spawn(500.0, origin + Vector2(190, 0))
	_runner.activate_q()
	_check(int(dom.counters["pinballs"]) == 1, "Crowd Pinball places two bumpers")
	for i in range(4):
		dom.tick(0.26)
	_check(int(dom.counters["pinballs"]) == 1 and _runner.enemy_hp(ball) < 500.0 - _D() - _D() + 0.01, "bodies travel two legs and are launched tangentially for 1D (%.1f)" % _runner.enemy_hp(ball))
	dom = _load(["DO01", "DO02", "DO03", "DO04", "DO05", "DOS1", "DOS1", "DOS1", "DOS2", "DOS2"])
	_check(is_equal_approx(dom.pull_speed(), AscensionRunner.R / 0.5 * (1.0 + 0.8 * 3.0 / 103.0)) and is_equal_approx(dom.link_life(), 3.0 + 2.0 * 2.0 / 72.0), "sinks: Pull 80%% x rank/(rank+100), Link Life 2 s x rank/(rank+70)")

	# ---------------- KNEEL
	dom = _load(["DO01", "DO02", "DO03", "DO05", "DO06", "DOC", "DOV", "DOV3"])
	var kneelers: Array[int] = []
	for i in range(5):
		kneelers.append(_spawn(5000.0, origin + Vector2(-300 + 40 * i, 200)))
	var big_elite := _spawn(50000.0, origin + Vector2(400, 200), EnemyWorldTypes.Flags.ELITE)
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and not dom._kneel.is_empty() and dom.links.size() == 1 and (dom.links[0]["members"] as Array).size() == 5, "V pulls every visible normal to the cursor and forms temporary Links")
	for i in range(6):
		dom.tick(0.1)
	_check(int(dom.counters["slams"]) == 0 and _runner.enemy_position(kneelers[0]).distance_to(origin + Vector2(200, 0)) < 30.0 and String(dom._kneel["phase"]) == "hold", "normals arrive at 900 px/s and the pile is held (%s)" % str(_runner.enemy_position(kneelers[0])))
	_check(_runner.enemy_position(big_elite).distance_to(origin + Vector2(400, 200)) > AscensionRunner.R - 1.0 and _runner.enemy_position(big_elite).distance_to(origin + Vector2(400, 200)) < AscensionRunner.R + 1.0, "elites move at most R (%s)" % str(_runner.enemy_position(big_elite)))
	for i in range(6):
		dom.tick(0.1)
	_check(int(dom.counters["slams"]) == 1, "after the 0.5 s hold the pile is slammed")
	var slam := minf(12.0 * _D(), 4.0 * _D() + 0.2 * _D() * 5.0)
	_check(is_equal_approx(_runner.enemy_hp(kneelers[0]), 5000.0 - slam), "for 4D + 0.2D per normal caught (%.1f)" % _runner.enemy_hp(kneelers[0]))
	_check(is_equal_approx(_runner.enemy_hp(big_elite), 50000.0 - slam), "elites receive the slam (%.1f)" % _runner.enemy_hp(big_elite))
	_check(int(dom.counters["second_slams"]) == 1 and _runner.enemy_position(kneelers[0]).distance_to(origin + Vector2(200, 0)) > 100.0, "Again: survivors are thrown 3R outward")
	for i in range(25):
		dom.tick(0.1)
	_check(int(dom.counters["slams"]) == 2 and is_equal_approx(_runner.enemy_hp(kneelers[0]), 5000.0 - slam - 0.6 * slam) and dom._kneel.is_empty(), "and pulled back for a second slam at 60%% (%.1f)" % _runner.enemy_hp(kneelers[0]))

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionDominionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
