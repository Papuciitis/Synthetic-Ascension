extends Node

# Ranged V5 Ordnance (handoff 2026-09-25): Grenadier launches from activation
# credits with no dash Mines, grenades attach/ground and detonate exactly
# once, Sticky Follow-Up boosts one detonation, Chain Reaction spreads through
# grounded explosives, Running Barrage lobs after real travel, Bandolier
# stores spares, tap-Q bombards instantly while hold-Q places Coordinates,
# and Big One counts only true Shells.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionOrdnanceV5Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: OrdnanceEngineV5
var _hits: Array = []   # every resolved hit record, for payload-tag provenance checks


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_or_v5", "res://asc_or_v5.tscn", at, hp, 10.0, 8.0, 0, 0))


func _fire() -> void:
	RunEvents.weapon_fired.emit(_player, &"ranged", _player.global_position, _runner.aim_target(), 1.0, 1.0)


func _native_hit_tags(volley: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags.append("volley:%d" % volley)
	return AscensionTags.with_flag(tags, "core_strike")


func _settle_grenade() -> void:
	# Flight is 0.35 s; fuses are 0.40 (attached) / 0.80 (grounded).
	for _i in range(14):
		_engine.tick(0.1)
		_runner.flush_attacks(-1)


## A real grenade blast kill: 3 HP prey at `at`, one rank-1 launch (four
## credits from a zero balance), ticked only until the kill resolves. OR04
## answers every blast kill, so its counter is the kill signal. Leftover
## Shells, sequences and grenades are cleared first so nothing else lands
## on the prey. Returns the prey handle.
func _grenade_kill(at: Vector2) -> int:
	_engine.shells.clear()
	_engine._sequences.clear()
	_engine.grenades.clear()
	_runner.aim_override = at
	var prey := _spawn_enemy(3.0, at)
	var secondary_before := int(_engine.counters["secondary"])
	for _i in range(4):
		_fire()
	for _i in range(14):
		_engine.tick(0.1)
		_runner.flush_attacks(-1)
		if int(_engine.counters["secondary"]) > secondary_before:
			break
	return prey


func _first_sequence(root: String) -> Dictionary:
	for sequence in _engine._sequences:
		if String(sequence["root"]) == root:
			return sequence
	return {}


func _count_mines(trap: bool) -> int:
	var count := 0
	for mine in _engine.mines:
		if bool(mine["trap"]) == trap:
			count += 1
	return count


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("OR02", 0)
	for id in ["OR01", "OR03", "OR04", "OR05", "OR06", "OR09", "OR10", "OR12", "ORQ", "ORC"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_runner.hit_resolved.connect(func(hit: Dictionary) -> void: _hits.append(hit))
	_runner.aim_override = _player.global_position + Vector2(150, 0)
	_engine = _runner.engine_for("OR02") as OrdnanceEngineV5
	_check(_engine != null, "a V5 run loads OrdnanceEngineV5")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()

	# --- No dash Mine: the point of the redesign.
	RunEvents.player_dashed.emit(_player, _player.global_position, Vector2.RIGHT)
	_check(_engine.mines.is_empty(), "a dash drops no Mine in V5")

	# --- OR-01: rank 1 launches one grenade every 4 activation credits;
	# a miss still earns credit (no hits happened yet).
	for _i in range(4):
		_fire()
	_check(_engine.grenades.size() == 1, "four native inputs launch one grenade (%d)" % _engine.grenades.size())
	_check(int(_engine.counters.get("grenades", 0)) == 1, "grenade counter agrees")

	# --- OR-02: it attaches to a living target and detonates exactly once.
	var victim := _spawn_enemy(300.0, _runner.aim_target())
	_settle_grenade()
	_check(_engine.grenades.is_empty(), "the grenade resolved")
	var blasts := int(_engine.counters.get("grenade_blasts", 0))
	_check(blasts == 1, "one grenade, one detonation (%d)" % blasts)
	var hp_after := EnemyWorld.get_health(victim)
	_check(hp_after < 300.0 and hp_after > 300.0 - 2.0 * 1.3 * D, "the blast dealt its 1.3D once (hp %.1f)" % hp_after)

	# --- OR-03/OR-05: a hit on a carrier detonates the sticky for +0.8D.
	for _i in range(4):
		_fire()
	for _i in range(4):
		_engine.tick(0.1)
	var attached := false
	for grenade in _engine.grenades:
		if String(grenade["state"]) == "attached":
			attached = true
	_check(attached, "the next grenade attached to the wounded target")
	var hp_before_sticky := EnemyWorld.get_health(victim)
	_runner.damage_enemy(victim, 1.0, _native_hit_tags(50))
	_runner.flush_attacks(-1)
	_check(int(_engine.counters.get("stickies", 0)) == 1, "Sticky Follow-Up detonated the attached grenade")
	var sticky_damage := hp_before_sticky - EnemyWorld.get_health(victim)
	_check(sticky_damage >= (1.3 + 0.8) * D, "the boosted blast carried +0.8D (%.1f)" % sticky_damage)
	# Bandolier added a spare to that launch and Chain Reaction detonated the
	# second attached grenade through the sticky blast: three blasts total,
	# each explosive exactly once.
	_check(int(_engine.counters.get("grenade_blasts", 0)) == int(_engine.counters.get("grenades", 0)) - _engine.grenades.size(), "every resolved grenade detonated exactly once")
	EnemyWorld.remove_enemy(victim, &"test")

	# --- Grounded grenades and Chain Reaction through grenades.
	_runner.aim_override = _player.global_position + Vector2(500, 0)
	_engine.spare_grenades = 0
	_engine._bandolier_credits = -1000.0
	_engine._grenadier_credits = 0.0
	for _i in range(8):
		_fire()
	_check(_engine.grenades.size() == 2, "two grenades in the air toward empty ground (%d)" % _engine.grenades.size())
	for _i in range(4):
		_engine.tick(0.1)
	var grounded := 0
	for grenade in _engine.grenades:
		if String(grenade["state"]) == "grounded":
			grounded += 1
	_check(grounded == 2 and _engine.grenades.size() == 2, "both grenades grounded near the cursor point (%d)" % grounded)
	var chain_before := int(_engine.counters["chain"])
	var blasts_before := int(_engine.counters.get("grenade_blasts", 0))
	# Let the first fuse expire; its blast chains the second immediately.
	_engine.tick(0.85)
	_runner.flush_attacks(-1)
	_check(int(_engine.counters.get("grenade_blasts", 0)) == blasts_before + 2, "both grounded grenades detonated once each")
	_check(int(_engine.counters["chain"]) >= chain_before, "the chain path handled the neighbour")

	# --- OR-04: three mutually touching grounded Grenades each detonate once;
	# Chain Reaction takes each out of the armed graph before its blast resolves.
	# The first grenade is lobbed 0.3 s ahead so only ITS fuse expires; the
	# other two still hold 0.25 s of fuse and can only go by the chain.
	_engine.grenades.clear()
	_engine.spare_grenades = 0
	_engine._bandolier_credits = -1000.0
	_engine._grenadier_credits = 0.0
	var tri := _player.global_position + Vector2(400, 0)
	var corners: Array[Vector2] = [Vector2(30, 0), Vector2(-15, 26), Vector2(-15, -26)]
	_runner.aim_override = tri + corners[0]
	for _i in range(4):
		_fire()
	for _i in range(3):
		_engine.tick(0.1)
	for corner in corners.slice(1):
		_runner.aim_override = tri + corner
		for _i in range(4):
			_fire()
	_check(_engine.grenades.size() == 3, "three launches toward three empty corners (%d)" % _engine.grenades.size())
	for _i in range(4):
		_engine.tick(0.1)
	var settled := 0
	for grenade in _engine.grenades:
		if String(grenade["state"]) == "grounded" and (grenade["pos"] as Vector2).distance_to(tri) < 31.0:
			settled += 1
	_check(settled == 3, "all three grounded 52 px apart, every pair inside one blast radius (%d)" % settled)
	var cluster := _spawn_enemy(3000.0, tri)
	var tri_blasts_before := int(_engine.counters.get("grenade_blasts", 0))
	var tri_chain_before := int(_engine.counters["chain"])
	_engine.tick(0.55)
	_runner.flush_attacks(-1)
	var tri_blasts := int(_engine.counters.get("grenade_blasts", 0)) - tri_blasts_before
	_check(tri_blasts == 3, "one fuse expiry chained the cluster: three detonations, one per grenade (%d)" % tri_blasts)
	_check(_engine.grenades.is_empty(), "no grenade is left armed to be chained again")
	_check(int(_engine.counters["chain"]) >= tri_chain_before + 2, "the chain reached both neighbours (%d)" % (int(_engine.counters["chain"]) - tri_chain_before))
	var cluster_damage := 3000.0 - EnemyWorld.get_health(cluster)
	_check(absf(cluster_damage - 3.0 * 1.3 * D) < 0.01, "the enemy in the middle took exactly three 1.3D blasts (%.1f)" % cluster_damage)
	print("DIAG OR-04 chain delta ", int(_engine.counters["chain"]) - tri_chain_before)
	EnemyWorld.remove_enemy(cluster, &"test")

	# --- OR-05 (spec OR-05): a grenade blast kill calls a Secondary Shell.
	_runner.aim_override = _player.global_position + Vector2(150, 0)
	var _prey := _spawn_enemy(3.0, _runner.aim_target())
	var secondary_before := int(_engine.counters["secondary"])
	for _i in range(4):
		_fire()
	_settle_grenade()
	_runner.flush_attacks(-1)
	_check(int(_engine.counters["secondary"]) == secondary_before + 1, "a grenade blast kill calls one Secondary Blast Shell")

	# --- OR-06: Running Barrage triggers from real travel credit.
	var walking_before := int(_engine.counters["walking"])
	_engine._run_credit = AscensionRunner.L
	_engine.tick(0.016)
	_check(int(_engine.counters["walking"]) == walking_before + 1, "1.0L of travel lobs a grenade")
	_check(_engine._run_credit < AscensionRunner.L, "the credit that triggered is consumed")
	_engine._run_credit = 10.0 * AscensionRunner.L
	_engine.tick(0.016)
	_check(_engine._run_credit <= 2.0 * AscensionRunner.L, "banked travel credit caps at 2L")

	# --- OR-07: Bandolier stores by real eligible activation credit; a spare
	# joins only an actual OR02/OR09 group, and its release earns no credit.
	_engine.grenades.clear()
	_engine.spare_grenades = 0
	_engine._bandolier_credits = 0.0
	_engine._grenadier_credits = -100.0   # Grenadier stays quiet: nothing may spend the spare yet
	_engine._run_credit = 0.0
	var stored_before := int(_engine.counters.get("bandolier_stored", 0))
	for _i in range(5):
		_fire()
	_check(_engine.spare_grenades == 0 and is_equal_approx(_engine._bandolier_credits, 5.0), "five native inputs are five credits, one short of the rank-1 store")
	_fire()
	_check(_engine.spare_grenades == 1 and int(_engine.counters.get("bandolier_stored", 0)) == stored_before + 1, "the sixth credit stores one spare grenade (%d)" % _engine.spare_grenades)
	_check(is_zero_approx(_engine._bandolier_credits), "the store consumed exactly six credits")
	_engine.on_witness_strike("ranged", _player.global_position, _runner.aim_target())
	_check(is_equal_approx(_engine._bandolier_credits, 0.6), "a real Witness: Shot is 0.6 credit (%.2f)" % _engine._bandolier_credits)
	_engine.call_shell(_player.global_position + Vector2(200, 0))
	_engine.tick(0.016)
	_check(_engine.spare_grenades == 1 and is_equal_approx(_engine._bandolier_credits, 0.6), "a Shell and idle time neither release the spare nor credit the store")
	var bandolier_before := _engine._bandolier_credits
	var grenadier_before := _engine._grenadier_credits
	var live_before := _engine.grenades.size()
	var spent_before := int(_engine.counters.get("bandolier_spent", 0))
	_engine._launch_grenades(1, "OR09")
	_check(_engine.spare_grenades == 0 and int(_engine.counters.get("bandolier_spent", 0)) == spent_before + 1, "a Running Barrage group takes the one spare")
	_check(_engine.grenades.size() == live_before + 2, "the spare joined that group as a second grenade (%d live)" % _engine.grenades.size())
	var joined: Array = _engine.grenades.slice(-2)
	_check(int(joined[0]["seq"]) == int(joined[1]["seq"]) and String(joined[0]["root"]) == "OR09" and String(joined[1]["root"]) == "OR09", "the spare shares the producer's root and launch")
	_check(is_equal_approx(_engine._bandolier_credits, bandolier_before) and is_equal_approx(_engine._grenadier_credits, grenadier_before) and int(_engine.counters.get("bandolier_stored", 0)) == stored_before + 1, "the release generated no Bandolier or Grenadier credit and no new store")
	_engine.spare_grenades = 2
	_engine._grenadier_credits = 0.0
	live_before = _engine.grenades.size()
	for _i in range(4):
		_fire()
	_check(_engine.spare_grenades == 1 and _engine.grenades.size() == live_before + 2, "the next Grenadier launch takes exactly one spare of two (%d left, %d live)" % [_engine.spare_grenades, _engine.grenades.size()])
	_check(is_equal_approx(_engine._bandolier_credits, 4.6), "those four inputs credited the store once each and the spare added none (%.2f)" % _engine._bandolier_credits)
	_engine._grenadier_credits = -100.0
	_engine.spare_grenades = 3
	_engine._bandolier_credits = 0.0
	for _i in range(6):
		_fire()
	_check(_engine.spare_grenades == 3, "the rank-1 reserve caps at 3 (%d)" % _engine.spare_grenades)
	_engine._grenadier_credits = 0.0
	_engine.spare_grenades = 0
	_engine._bandolier_credits = -1000.0
	_engine.shells.clear()

	# --- OR-09: Big One counts only true Shells; grenades never advance it.
	_engine.grenades.clear()
	var big_before := int(_engine.counters["big_ones"])
	_engine._shell_count = 0
	for _i in range(7):
		_engine.call_shell(_player.global_position + Vector2(200, 0))
	_check(int(_engine.counters["big_ones"]) == big_before + 1, "the seventh Shell is the Big One")
	_engine._shell_count = 6
	_engine._launch_grenades(1, "OR02")
	_check(_engine._shell_count == 6, "a grenade launch does not advance the Shell counter")

	# --- OR-08: Saturation Scan fires 3/4/5 Shells by rank and scans exactly
	# once per qualifying event: R of real travel banked, then a blast kill.
	ledger.record_purchase("OR11", 100)
	_runner.refresh()
	_check(_engine.has("OR11") and is_same(_engine, _runner.engine_for("OR02")) and _engine.rank("OR11") == 1, "OR11 rank 1 joins the live engine without rebuilding it")
	_engine.grenades.clear()
	_engine.shells.clear()
	_engine._sequences.clear()
	_engine._blast_window.clear()
	_engine._shell_count = 0
	_engine._scan_travel = 0.0
	_engine._run_credit = 0.0
	_engine._grenadier_credits = 0.0
	_engine.spare_grenades = 0
	_engine._bandolier_credits = -1000.0
	var scan_at := _player.global_position + Vector2(150, 0)
	var scans_before := int(_engine.counters["scans"])
	_runner.travel_this_frame = AscensionRunner.R
	_engine.tick(0.016)
	_runner.travel_this_frame = 0.0
	_check(int(_engine.counters["scans"]) == scans_before and _engine._scan_travel >= AscensionRunner.R, "R of travel alone scans nothing; the distance waits for a blast kill")
	_grenade_kill(scan_at)
	_check(int(_engine.counters["scans"]) == scans_before + 1 and is_zero_approx(_engine._scan_travel), "the first blast kill after R of travel scans once and spends the distance")
	var scan := _first_sequence("OR11")
	_check(not scan.is_empty() and int(scan["shells"]) == 3 and is_equal_approx(float(scan["damage"]), OrdnanceEngine.SHELL_D), "rank 1 queues a 3-Shell 1.5D sequence at the densest cell")
	_engine.shells.clear()
	var scan_shells_before := int(_engine.counters["shells"])
	for _i in range(3):
		_engine.tick(0.25)
	var scan_shells := int(_engine.counters["shells"]) - scan_shells_before
	_check(scan_shells == 3 and _first_sequence("OR11").is_empty() and _engine.shells.size() == 3 and String(_engine.shells[0]["root"]) == "OR11", "the sequence calls exactly three OR11 Shells 0.2 s apart and ends")
	_grenade_kill(scan_at)
	_check(int(_engine.counters["scans"]) == scans_before + 1, "a second blast kill with no new travel does not scan again")
	_runner.travel_this_frame = AscensionRunner.R * 0.5
	_engine.tick(0.016)
	_runner.travel_this_frame = 0.0
	_grenade_kill(scan_at)
	_check(int(_engine.counters["scans"]) == scans_before + 1, "half an R of travel plus a blast kill is not a qualifying event")
	ledger.record_purchase("OR11", 100)
	_runner.refresh()
	_runner.travel_this_frame = AscensionRunner.R * 0.5
	_engine.tick(0.016)
	_runner.travel_this_frame = 0.0
	_grenade_kill(scan_at)
	scan = _first_sequence("OR11")
	_check(int(_engine.counters["scans"]) == scans_before + 2 and _engine.rank("OR11") == 2 and int(scan["shells"]) == 4, "the banked half-R completes R: rank 2 scans once for 4 Shells")
	ledger.record_purchase("OR11", 100)
	_runner.refresh()
	_runner.travel_this_frame = AscensionRunner.R
	_engine.tick(0.016)
	_runner.travel_this_frame = 0.0
	_grenade_kill(scan_at)
	scan = _first_sequence("OR11")
	_check(int(_engine.counters["scans"]) == scans_before + 3 and _engine.rank("OR11") == 3 and int(scan["shells"]) == 5, "rank 3 scans once for 5 Shells")
	_engine.shells.clear()
	scan_shells_before = int(_engine.counters["shells"])
	for _i in range(5):
		_engine.tick(0.25)
	scan_shells = int(_engine.counters["shells"]) - scan_shells_before
	_check(scan_shells == 5 and _first_sequence("OR11").is_empty(), "the rank-3 sequence calls exactly five Shells and ends (%d)" % scan_shells)
	_engine.shells.clear()
	_engine._sequences.clear()
	_engine.grenades.clear()
	_runner.flush_attacks(-1)

	# --- OR-10: tap-Q fires instantly; hold-Q places without firing.
	_runner.q_cooldown_left = 0.0
	_engine._sequences.clear()
	_engine.coordinates.clear()
	var press := _engine.activate_q("ORQ")
	_check(bool(press["ok"]) and _engine._sequences.is_empty() and _engine.coordinates.is_empty(), "a press alone neither fires nor places")
	var tap := _engine.release_q("ORQ")
	_check(bool(tap["ok"]) and _engine._sequences.size() == 1 and int(_engine._sequences[0]["shells"]) == 4, "a quick tap starts the 4-Shell instant sequence")
	_check(is_equal_approx(float(tap["cooldown"]), 7.0), "the tap consumed the 7 s fire cooldown")
	_check(_engine.coordinates.is_empty(), "the tap placed no Coordinate")
	_runner.q_cooldown_left = 5.0
	_engine.activate_q("ORQ")
	_engine.hold_q("ORQ", 0.4)
	var placed := _engine.release_q("ORQ")
	_check(bool(placed["ok"]) and _engine.coordinates.size() == 1, "holding 0.35 s places a Coordinate during the fire cooldown")
	_check(float(placed["cooldown"]) >= 5.0, "placement preserves the remaining fire cooldown")
	_engine.activate_q("ORQ")
	var refused := _engine.release_q("ORQ")
	_check(not bool(refused["ok"]) and String(refused["message"]) == "COOLING", "a tap during the fire cooldown is refused, not queued")

	# --- OR-11: ORQ1 and ORQ2 stay mutually exclusive in the ledger, and each
	# reshapes both the tap-Q sequence and the Coordinate-fired sequence.
	var q_at := _player.global_position + Vector2(200, 0)
	var spent_before_2 := int(ledger.state["spent"])
	var buy := ledger.can_buy("ORQ1", 100000)
	_check(bool(buy["ok"]), "Saturation is purchasable beside the owned Designate (%s)" % buy["reason"])
	ledger.record_purchase("ORQ1", int(buy["cost"]))
	var sealed := ledger.can_buy("ORQ2", 100000)
	_check(not bool(sealed["ok"]) and String(sealed["reason"]).begins_with("sealed by"), "Homing is sealed while Saturation is owned (%s)" % sealed["reason"])
	_check(int(ledger.state["spent"]) == spent_before_2 + int(buy["cost"]), "the refused purchase spent nothing")
	_runner.refresh()
	_check(_engine.has("ORQ1") and not _engine.has("ORQ2"), "the engine runs Saturation alone")
	_engine._sequences.clear()
	_engine.coordinates.clear()
	_engine.shells.clear()
	_engine._shell_count = 0
	_engine._blast_window.clear()
	_runner.aim_override = q_at
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	var sat_tap := _engine.release_q("ORQ")
	var sat_seq := _first_sequence("ORQ")
	_check(bool(sat_tap["ok"]) and _engine._sequences.size() == 1 and int(sat_seq["shells"]) == 7 and is_equal_approx(float(sat_seq["radius"]), 3.0 * AscensionRunner.R) and int(sat_seq["coord"]) == -1, "tap-Q under Saturation queues 7 Shells across a 3R circle")
	_engine.tick(0.25)
	_check(_engine.shells.size() == 1 and (_engine.shells[0]["at"] as Vector2).distance_to(q_at) <= 3.0 * AscensionRunner.R and String(_engine.shells[0]["root"]) == "ORQ", "its first Shell falls somewhere inside the 3R circle under the Q root")
	_engine._sequences.clear()
	_engine.shells.clear()
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	_engine.hold_q("ORQ", 0.4)
	_engine.release_q("ORQ")
	_check(_engine.coordinates.size() == 1 and _engine._sequences.is_empty(), "a hold places a Coordinate at the aim without firing")
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	var sat_coord := _engine.release_q("ORQ")
	sat_seq = _first_sequence("ORQ")
	_check(bool(sat_coord["ok"]) and _engine.coordinates.is_empty() and _engine._sequences.size() == 1 and int(sat_seq["shells"]) == 7 and is_equal_approx(float(sat_seq["radius"]), 3.0 * AscensionRunner.R) and int(sat_seq["coord"]) == 0, "tapping the hovered Coordinate consumes it and queues the same 7-Shell 3R sequence")
	_engine._sequences.clear()
	ledger.refund("ORQ1", 1.0, true)
	_check(not ledger.owns("ORQ1"), "Saturation refunded cleanly")
	var buy_homing := ledger.can_buy("ORQ2", 100000)
	_check(bool(buy_homing["ok"]), "Homing opens once Saturation is gone (%s)" % buy_homing["reason"])
	ledger.record_purchase("ORQ2", int(buy_homing["cost"]))
	var sealed_sat := ledger.can_buy("ORQ1", 100000)
	_check(not bool(sealed_sat["ok"]) and String(sealed_sat["reason"]).begins_with("sealed by"), "Saturation is sealed while Homing is owned (%s)" % sealed_sat["reason"])
	_runner.refresh()
	_check(_engine.has("ORQ2") and not _engine.has("ORQ1"), "the engine runs Homing alone")
	var mark := _spawn_enemy(5000.0, q_at + Vector2(40, 0))
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	var hom_tap := _engine.release_q("ORQ")
	var hom_seq := _first_sequence("ORQ")
	_check(bool(hom_tap["ok"]) and _engine._sequences.size() == 1 and int(hom_seq["shells"]) == 3 and is_equal_approx(float(hom_seq["damage"]), 2.5) and int(hom_seq["follow"]) == mark and int(hom_seq["coord"]) == -1, "tap-Q under Homing queues 3 × 2.5D Shells tracking the nearest enemy")
	_engine.tick(0.25)
	_check(_engine.shells.size() == 1 and is_equal_approx(float(_engine.shells[0]["damage"]), 2.5 * D) and int(_engine.shells[0]["follow"]) == mark, "its first Shell is a real 2.5D tracking Shell (%.1f)" % float(_engine.shells[0]["damage"]))
	_engine._sequences.clear()
	_engine.shells.clear()
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	_engine.hold_q("ORQ", 0.4)
	_engine.release_q("ORQ")
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	var hom_coord := _engine.release_q("ORQ")
	hom_seq = _first_sequence("ORQ")
	_check(bool(hom_coord["ok"]) and _engine.coordinates.is_empty() and _engine._sequences.size() == 1 and int(hom_seq["shells"]) == 3 and is_equal_approx(float(hom_seq["damage"]), 2.5) and int(hom_seq["follow"]) == mark and int(hom_seq["coord"]) == 0, "the Coordinate-fired sequence under Homing is the same 3 × 2.5D tracking salvo")
	ledger.refund("ORQ2", 1.0, true)
	_runner.refresh()
	_check(not _engine.has("ORQ2") and not _engine.has("ORQ1"), "back to plain Designate")
	_engine._sequences.clear()
	_engine.shells.clear()
	EnemyWorld.remove_enemy(mark, &"test")

	# --- OR-12: ORQ4 traps are Mine-tagged explosives that Chain Reaction
	# detonates (and that detonate others), on a 24-trap pool independent of
	# the 12-Mine cap. The Rune Bomb conversion half of this case is proved
	# in AscensionV5HybridForeignTest.
	ledger.record_purchase("ORQ4", 600)
	_runner.refresh()
	_check(_engine.has("ORQ4"), "Proximity joins the live engine")
	_engine.grenades.clear()
	_engine.shells.clear()
	_engine._sequences.clear()
	_engine.coordinates.clear()
	_engine.mines.clear()
	_engine._blast_window.clear()
	_engine._shell_count = 0
	_engine._grenadier_credits = 0.0
	_engine._run_credit = 0.0
	var trap_at := _player.global_position + Vector2(300, 0)
	_runner.aim_override = trap_at
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	_engine.release_q("ORQ")
	for _i in range(7):
		_engine.tick(0.25)
		_runner.flush_attacks(-1)
	_check(_count_mines(true) == 4 and _engine.shells.is_empty() and int(_engine.counters["traps"]) == 4, "the tap's four Designate Shells landed as four armed traps (%d)" % _count_mines(true))
	var trap: Dictionary = _engine.mines[0]
	_check(bool(trap["trap"]) and float(trap["arm"]) <= 0.0 and float(trap["life"]) <= 3.0 and is_equal_approx(float(trap["damage"]), 1.5 * D) and String(trap["root"]) == "ORQ", "a trap is armed on landing, lives 3 s and holds the Shell's 1.5D under the Q root")
	for _i in range(4):
		_fire()
	_check(_engine.grenades.size() == 1 and int(_engine.grenades[0]["victim"]) == 0, "a grenade lobbed at the trap point seeks nothing and heads for the ground")
	var bystander := _spawn_enemy(5000.0, trap_at + Vector2(50, 0))
	_hits.clear()
	var trap_blasts_before := int(_engine.counters["mine_blasts"])
	var trap_chain_before := int(_engine.counters["chain"])
	var trap_grenade_before := int(_engine.counters.get("grenade_blasts", 0))
	for _i in range(13):
		_engine.tick(0.1)
		_runner.flush_attacks(-1)
	_check(int(_engine.counters.get("grenade_blasts", 0)) == trap_grenade_before + 1 and int(_engine.counters["mine_blasts"]) == trap_blasts_before + 4 and int(_engine.counters["chain"]) == trap_chain_before + 4 and _engine.mines.is_empty(), "the grounded grenade's blast chained all four traps at once, each once")
	var bystander_damage := 5000.0 - EnemyWorld.get_health(bystander)
	_check(absf(bystander_damage - (1.3 + 4.0 * 1.5) * D) < 0.01, "the bystander took the 1.3D grenade and four 1.5D trap blasts once each (%.1f)" % bystander_damage)
	var mine_tagged := 0
	for hit in _hits:
		if int(hit["handle"]) == bystander and String(hit["path"]) == "mine" and String(hit["root"]) == "ORQ":
			mine_tagged += 1
	_check(mine_tagged == 4, "each trap blast hit carried the Mine payload tag under the Q root (%d)" % mine_tagged)
	# Trap-initiated: a trap explodes on contact and its blast chains a nearby grenade.
	_runner.q_cooldown_left = 0.0
	_engine.activate_q("ORQ")
	_engine.release_q("ORQ")
	for _i in range(7):
		_engine.tick(0.25)
		_runner.flush_attacks(-1)
	print("DIAG OR-12 traps after second tap ", _count_mines(true))
	for _i in range(4):
		_fire()
	for _i in range(4):
		_engine.tick(0.1)
	print("DIAG OR-12 grenade state ", _engine.grenades[0]["state"] if not _engine.grenades.is_empty() else "none")
	_runner.move_enemy_to(bystander, trap_at)
	trap_blasts_before = int(_engine.counters["mine_blasts"])
	trap_grenade_before = int(_engine.counters.get("grenade_blasts", 0))
	_engine.tick(0.05)
	_runner.flush_attacks(-1)
	print("DIAG OR-12 contact: mine_blasts +", int(_engine.counters["mine_blasts"]) - trap_blasts_before, " grenade_blasts +", int(_engine.counters.get("grenade_blasts", 0)) - trap_grenade_before, " mines left ", _engine.mines.size(), " grenades left ", _engine.grenades.size())
	EnemyWorld.remove_enemy(bystander, &"test")
	# Independent capacity: a full 12-Mine pool and a 24-trap pool coexist.
	_engine.mines.clear()
	_engine.grenades.clear()
	var far := _player.global_position + Vector2(-700, 0)
	for i in range(12):
		_engine.drop_mine(far + Vector2(0, i * 100), OrdnanceEngine.MINE_D, "MR9")
	_check(_engine.mine_cap() == 12 and _count_mines(false) == 12, "twelve genuine Mines fill the ordinary cap, which Bandolier left at 12")
	var pop_before := int(_engine.counters["mine_blasts"])
	_engine.drop_mine(far + Vector2(0, 1200), OrdnanceEngine.MINE_D, "MR9")
	_runner.flush_attacks(-1)
	_check(int(_engine.counters["mine_blasts"]) == pop_before + 1 and _count_mines(false) == 12, "a thirteenth Mine pops the oldest Mine")
	for i in range(24):
		_engine.drop_mine(far + Vector2(200 + (i % 6) * 100, int(i / 6.0) * 100), OrdnanceEngine.MINE_D, "ORQ", 0, true, 3.0, 0.0)
	_check(_count_mines(true) == 24 and _count_mines(false) == 12 and int(_engine.counters["mine_blasts"]) == pop_before + 1, "24 traps land beside the full Mine pool without popping a Mine")
	_engine.drop_mine(far + Vector2(200, 0), OrdnanceEngine.MINE_D, "ORQ", 0, true, 3.0, 0.0)
	_runner.flush_attacks(-1)
	_check(_count_mines(true) == 24 and _count_mines(false) == 12 and int(_engine.counters["mine_blasts"]) == pop_before + 2, "a 25th trap pops the oldest trap, never a Mine")
	_engine.mines.clear()
	_engine.grenades.clear()
	_engine.shells.clear()
	_runner.flush_attacks(-1)

	# --- OR-13: 24 owned blasts in a rolling 8 s window fire Rolling Thunder.
	_runner.q_cooldown_left = 0.0
	var thunder_before := int(_engine.counters["thunder"])
	_engine._thunder_recovery = 0.0
	_engine._blast_window.clear()
	for i in range(24):
		_engine._blast_with_path(_player.global_position + Vector2(300, 0), 1.0, 10.0, "OR02", 0.5, PackedStringArray(), 5000 + i, "grenade")
	_check(int(_engine.counters["thunder"]) == thunder_before + 1, "24 blasts inside 8 s fire Rolling Thunder once")
	_check(_engine._blast_window.is_empty(), "the window resets after the catastrophe")

	_finish()


func _finish() -> void:
	print("AscensionOrdnanceV5Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
