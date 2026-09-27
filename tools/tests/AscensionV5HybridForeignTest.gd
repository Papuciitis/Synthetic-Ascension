extends Node

# Ranged V5 cross-tree and foreign-Core adapters (handoff 2026-09-25, spec
# §5; acceptance cases HYB-01..05 tagged below): foreign Spin Up stages ride
# real Witness shots and buff the shot itself, foreign Reserve Feed earns and
# releases through Witness cadence, Rune Bomb converts a travelling grenade
# into one genuine Sigil Mine under the cap of three (HYB-03), named Hot
# Rounds deaths carry their provenance (and radiant deaths do not), Heavy
# Barrel spends Force once on a real Vent Volley and Overload re-uses the
# half snapshot without another spend (HYB-02), genuine Mines from MR6/MR9
# and ORQ4 traps stay supported beside Grenadier (HYB-04), Kill Feed adds
# exactly one bonus fragment to ranked BR05's group on a real fragment
# execution (HYB-01), and an authored route that lost a V5 prerequisite
# fails loudly through the real purchase path (HYB-05).
#
# Run: <godot> --headless --path . res://tools/tests/AscensionV5HybridForeignTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PRESETS := "res://data/ascension/presets_v4.json"

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _kills: Array = []


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_hyb_v5", "res://asc_hyb_v5.tscn", at, hp, 10.0, 8.0, 0, 0))


func _witness_tags(serial: int) -> PackedStringArray:
	var tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "witness", "bullet", 1, 0.6, PackedStringArray(["core_strike", "witness"]))
	tags.append("cast:witness:%d" % serial)
	return tags


## Real player projectiles still sitting where they were spawned, by root.
func _rounds_at(origin: Vector2, root: String) -> Array:
	var near: Array = []
	ProjectileManager.player_projectiles_in_radius(origin, 4.0, near)
	return near.filter(func(p): return String(AscensionTags.parse(p["tags"])["root"]) == root)


func _run() -> void:
	# ---------------- foreign adapters: a Melee native with a Ranged Gate.
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("EX01", 0)
	ledger.record_purchase("G1", 1600, "ranged")
	for id in ["BR01", "BR02", "BR07", "BR11"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_runner.kill_resolved.connect(func(hit: Dictionary, _context: RefCounted) -> void: _kills.append(hit))
	var engine := _runner.engine_for("BR01") as BarrageEngineV5
	_check(engine != null, "a foreign V5 Barrage engine loads for a Melee native")
	if engine == null:
		_finish()
		return
	var D := _runner.native_damage()
	var origin: Vector2 = _player.global_position
	var target := origin + Vector2(200, 0)
	for i in range(3):
		engine.on_witness_strike("ranged", origin, target)
		engine.tick(0.5)
	_check(engine._foreign_stage == 3, "three chained Witness shots reach foreign stage 3 (%d)" % engine._foreign_stage)
	_check(is_equal_approx(engine.haste_multiplier("melee"), 1.0), "foreign Spin Up never accelerates the native Melee weapon")
	var preview := {"handle": 0, "raw": 10.0, "tags": _witness_tags(9), "core": "ranged", "family": AscensionTags.FAMILY_TREE, "core_strike": true}
	var buffed := engine.modify_outgoing_damage(preview, 10.0)
	_check(is_equal_approx(buffed, 10.0 + 0.3 * D), "a stage-3 Witness shot gains its flat +0.3D of the native hit (%.1f, D=%.1f)" % [buffed, D])
	var native_preview := {"handle": 0, "raw": 10.0, "tags": AscensionTags.native("melee", "slash"), "core": "melee", "family": AscensionTags.FAMILY_NATIVE, "core_strike": true}
	_check(is_equal_approx(engine.modify_outgoing_damage(native_preview, 10.0), 10.0), "native Melee hits gain nothing from foreign stages")
	engine._foreign_last_witness = engine._clock - 4.5
	engine.on_witness_strike("ranged", origin, target)
	_check(engine._foreign_stage == 1, "a 4 s Witness gap resets the chain to stage 1")
	# Foreign Reserve Feed: 0.6 credit per Witness shot, release on the 4th.
	engine.stored_rounds = 0
	engine._reserve_credit = 0.0
	engine._foreign_witness_count = 0
	var released_before := int(engine.counters["stored_fired"])
	for i in range(12):
		engine.on_witness_strike("ranged", origin, target)
	_check(engine.stored_rounds > 0 or int(engine.counters["stored_fired"]) > released_before, "foreign Witness credit stores and releases reserve rounds")
	_check(int(engine.counters["stored_fired"]) > released_before, "every fourth Witness shot released stored rounds")
	_player.queue_free()
	await get_tree().process_frame

	# ---------------- named provenance: Hot Rounds deaths vs radiant deaths.
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	ledger = Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	for id in ["BR03", "BR04", "OR02", "OR06", "ORQ", "ORQ4", "BR08", "BRC"]:
		ledger.record_purchase(id, 100)
	# RM7, MR8 and MR9 parents (data-level shortcut; runtime only needs the ids).
	ledger.record_purchase("G1", 1600, "magic")
	for id in ["IN01", "IN09", "RM7", "BA01", "MR8", "MR9"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_runner.kill_resolved.connect(func(hit: Dictionary, _context: RefCounted) -> void: _kills.append(hit))
	var barrage := _runner.engine_for("BR01") as BarrageEngineV5
	var ordnance := _runner.engine_for("OR02") as OrdnanceEngineV5
	var invocation := _runner.engine_of_discipline("IN") as InvocationEngine
	_check(barrage != null and ordnance != null and invocation != null, "V5 Barrage + Ordnance and V4 Invocation coexist")
	var Dr := _runner.native_damage()

	_kills.clear()
	var burn_victim := _spawn_enemy(1.0, _player.global_position + Vector2(90, 0))
	EnemyStatus.apply_named_burn(burn_victim, &"hot_rounds", 3.0, 0.5, 0.30 * Dr, _player, barrage._hot_rounds_tags())
	EnemyStatus.advance(0.51)
	await get_tree().process_frame
	_check(_kills.size() == 1, "the named burn tick killed once")
	if _kills.size() == 1:
		var hit: Dictionary = _kills[0]
		_check(String(hit["family"]) == "status" and String(hit["root"]) == "BR04", "the death attributes to Hot Rounds (family %s, root %s)" % [hit["family"], hit["root"]])
		_check(AscensionTags.has_flag(hit["tags"], "hot_rounds"), "the hot_rounds provenance flag survives the tick")
	_kills.clear()
	var radiant_victim := _spawn_enemy(0.3, _player.global_position + Vector2(30, 0))
	barrage.heat = 60.0
	barrage._aura_tick_left = 0.0
	barrage._tick_aura(0.26)
	await get_tree().process_frame
	_check(_kills.size() == 1, "the radiant aura tick killed once")
	if _kills.size() == 1:
		var hit2: Dictionary = _kills[0]
		_check(String(hit2["root"]) == "BR03" and not AscensionTags.has_flag(hit2["tags"], "hot_rounds"), "a radiant death can never masquerade as a Hot Rounds kill")

	# --- HYB-03: RM7 physically converts a Grenade crossing a Sigil into one Mine, keeps the cap of three per Sigil, and no grenade/Mine double explosion.
	if EnemyWorld.is_valid_handle(radiant_victim):
		EnemyWorld.remove_enemy(radiant_victim, &"test")
	if EnemyWorld.is_valid_handle(burn_victim):
		EnemyWorld.remove_enemy(burn_victim, &"test")
	var sigil_at: Vector2 = _player.global_position + Vector2(120, 0)
	var sigil: Dictionary = invocation.place_sigil(sigil_at, "plain")
	_check(invocation.sigils.size() >= 1, "a Sigil stands in the grenade's path")
	_runner.aim_override = _player.global_position + Vector2(240, 0)
	ordnance.grenades.clear()
	ordnance._launch_grenades(1, "OR02")
	var mines_before := ordnance.mines.size()
	for _i in range(6):
		ordnance.tick(0.06)
	_check(ordnance.grenades.is_empty() and ordnance.mines.size() == mines_before + 1, "the grenade crossing the Sigil became a Mine, never both")
	var mine: Dictionary = ordnance.mines[ordnance.mines.size() - 1] if not ordnance.mines.is_empty() else {}
	_check(int(mine.get("sigil", 0)) == int(sigil["id"]), "the Mine is attached to the Sigil")
	_check(int(ordnance.counters.get("rune_bombs", 0)) == 1 and int(ordnance.counters.get("grenade_blasts", 0)) == 0, "the conversion transferred one logical explosive without detonating")
	# The cap of three per Sigil: three more grenades cross it in one flight.
	# Two convert, the third crosses unconverted and lands as a grenade.
	ordnance._launch_grenades(3, "OR02")
	for _i in range(6):
		ordnance.tick(0.06)
	var attached: Array = ordnance.mines.filter(func(m): return int(m.get("sigil", 0)) == int(sigil["id"]))
	_check(int(sigil.get("mines", 0)) == 3 and attached.size() == 3 and int(ordnance.counters.get("rune_bombs", 0)) == 3, "the Sigil holds exactly three attached Mines (%d attached, %d conversions)" % [attached.size(), int(ordnance.counters.get("rune_bombs", 0))])
	_check(ordnance.grenades.size() == 1 and String(ordnance.grenades[0]["state"]) == "grounded", "the fourth grenade crossed the full Sigil unconverted and landed as a grenade (%d live)" % ordnance.grenades.size())
	for _i in range(15):
		ordnance.tick(0.06)
	attached = ordnance.mines.filter(func(m): return int(m.get("sigil", 0)) == int(sigil["id"]))
	_check(ordnance.grenades.is_empty() and int(ordnance.counters.get("grenade_blasts", 0)) == 1 and int(ordnance.counters["mine_blasts"]) == 0 and attached.size() == 3 and ordnance.mines.size() == mines_before + 3, "four grenades resolved as three conversions plus one grenade blast; no object exploded twice and no Mine went with it (%d grenade blasts, %d mine blasts)" % [int(ordnance.counters.get("grenade_blasts", 0)), int(ordnance.counters["mine_blasts"])])
	# The Sigil-side partner rule: detonating the Sigil takes its three attached
	# Mines with it exactly once each, even though Chain Reaction (OR06, owned
	# here) already fires the co-located siblings off the first blast.
	var sigil_blasts_before := int(ordnance.counters["mine_blasts"])
	var sigil_chain_before := int(ordnance.counters["chain"])
	invocation._detonate(sigil, false)
	attached = ordnance.mines.filter(func(m): return int(m.get("sigil", 0)) == int(sigil["id"]))
	_check(int(ordnance.counters["mine_blasts"]) == sigil_blasts_before + 3 and attached.is_empty() and ordnance.mines.size() == mines_before, "a Sigil detonation blasts each of its three attached Mines exactly once (%d blasts, %d still attached)" % [int(ordnance.counters["mine_blasts"]) - sigil_blasts_before, attached.size()])
	_check(int(ordnance.counters["chain"]) == sigil_chain_before + 2, "the two siblings went by Chain Reaction, not by a second pass (%d chained)" % (int(ordnance.counters["chain"]) - sigil_chain_before))

	# --- HYB-04: MR6/MR9 genuine Mines and ORQ4 Proximity traps remain supported independently of automatic Grenadier.
	_check(ordnance.mine_cap() == 12, "the ordinary 12-Mine cap survives (Bandolier no longer raises it)")
	var genuine_before := ordnance.mines.size()
	ordnance.drop_mine(_player.global_position + Vector2(-60, 0), OrdnanceEngine.MINE_D, "MR6")
	var runner_mine: Dictionary = ordnance.mines[ordnance.mines.size() - 1] if not ordnance.mines.is_empty() else {}
	_check(ordnance.mines.size() == genuine_before + 1 and String(runner_mine.get("root", "")) == "MR6" and not bool(runner_mine.get("trap", true)), "a hybrid Mine producer still drops genuine Mines")
	# ORQ4: a Designate sequence lands its four Shells as armed traps in the
	# separate Q pool; Grenadier neither launches nor earns from it.
	var traps_before := int(ordnance.counters["traps"])
	var ordinary_before := ordnance.mines.filter(func(m): return not bool(m["trap"])).size()
	var launches_before := int(ordnance.counters.get("grenades", 0))
	var credits_before: float = ordnance._grenadier_credits
	var trap_at: Vector2 = _player.global_position + Vector2(0, 300)
	var designate := ordnance._instant_designate(trap_at)
	for _i in range(10):
		ordnance.tick(0.2)
	var traps: Array = ordnance.mines.filter(func(m): return bool(m["trap"]))
	var traps_placed := traps.size() == 4
	for trap in traps:
		traps_placed = traps_placed and String(trap["root"]) == "ORQ" and (trap["at"] as Vector2).distance_to(trap_at) < 1.0 and float(trap["arm"]) <= 0.0
	_check(bool(designate["ok"]) and int(ordnance.counters["traps"]) == traps_before + 4 and traps_placed, "Proximity's four-Shell Designate landed four armed ORQ traps on the point (%d traps)" % traps.size())
	_check(ordnance.mines.filter(func(m): return not bool(m["trap"])).size() == ordinary_before and ordnance.mine_cap() == 12, "traps live in their own pool: no ordinary Mine slot taken, the 12 cap untouched")
	_check(int(ordnance.counters.get("grenades", 0)) == launches_before and ordnance.grenades.is_empty() and is_equal_approx(ordnance._grenadier_credits, credits_before), "no Grenadier launch or activation credit came from the Q")
	# MR9: a real Guarded hit drops genuine Mines, three per hit, fraction banked.
	var bastion := _runner.engine_of_discipline("BA") as BastionEngine
	_check(bastion != null, "the Bastion engine carries Force for MR8 and Guard for MR9")
	if bastion != null:
		var reactive_before := ordnance.mines.size()
		bastion.guarding = true
		bastion.force = 30.0
		var taken := bastion.damage_taken_multiplier_for(null, &"hit")
		var max_hp := _runner.player_max_hp()
		bastion.on_player_damage_resolved(null, 0.5 * max_hp, 0.5 * max_hp * taken, &"hit")
		bastion.guarding = false
		var reactive: Array = ordnance.mines.filter(func(m): return String(m["root"]) == "MR9")
		_check(is_equal_approx(taken, 0.25) and reactive.size() == 3 and ordnance.mines.size() == reactive_before + 3 and int(bastion.counters.get("reactive_mines", 0)) == 3, "a Guarded hit (75%% prevented of a 50%% max-HP blow) drops three MR9 Mines, the per-hit cap (%d)" % reactive.size())
		_check(absf(bastion._mine_bank - 0.75) < 0.001 and reactive.all(func(m): return not bool(m["trap"])), "the 0.75 fraction is banked and the Mines are ordinary Mines, not Q traps (bank %.2f)" % bastion._mine_bank)

	# --- HYB-02: MR8 spends Force only once across the Vent Volley; BRC re-uses the allowed half-damage snapshot, never spends Force again.
	if bastion != null:
		bastion.force = 60.0
		barrage._auto_vent_volley(_player.global_position, false)
		_check(is_zero_approx(bastion.force), "the Vent Volley spent the 60 Force exactly once")
		_check(is_equal_approx(float(barrage.counters.get("heavy_barrel_force", 0.0)), 60.0), "MR8 recorded the single spend")
		_check(is_equal_approx(barrage._heavy_barrel_bonus, 0.06 * Dr * 60.0 * 0.5), "BRC's half snapshot is banked without another spend")
		var vent_rounds := _rounds_at(_runner.player_position(), "BR08")
		var vent_count := barrage._vent_round_count()
		var vent_even := vent_rounds.size() == vent_count
		for round in vent_rounds:
			vent_even = vent_even and absf(float(round["damage"]) - (0.6 * Dr + 0.06 * Dr * 60.0 / float(vent_count))) < 0.01
		_check(vent_even, "the %d real release rounds each carry an even share of the whole 60-Force bonus, not 60 Force each (%d spawned)" % [vent_count, vent_rounds.size()])
		# Overload: four volleys draw on the banked half, not on fresh Force.
		bastion.force = 30.0
		var overload_before := int(barrage.counters["overload_rounds"])
		var snapshot: float = barrage._heavy_barrel_bonus
		barrage._overload()
		barrage._tick_overload(0.6)
		var overload_rounds := _rounds_at(_runner.player_position(), "BRC")
		var overload_even := overload_rounds.size() == 48
		for round in overload_rounds:
			overload_even = overload_even and absf(float(round["damage"]) - (0.8 * Dr + snapshot / 48.0)) < 0.01
		_check(int(barrage.counters["overload_rounds"]) == overload_before + 48 and overload_even, "Overload's 48 real rounds each carry 1/48 of the half snapshot (%d spawned)" % overload_rounds.size())
		_check(is_equal_approx(bastion.force, 30.0) and is_equal_approx(float(barrage.counters.get("heavy_barrel_force", 0.0)), 60.0), "Overload spent no Force: the fresh 30 and the single 60 record survive (%.1f)" % bastion.force)
		_check(is_zero_approx(barrage._heavy_barrel_bonus) and barrage._overload_volleys_left == 0, "the snapshot clears with the fourth volley; nothing is left to re-use twice")

	# ---------------- Burst completion banks one 0.7 strike credit.
	barrage._strike_credit = 0.0
	barrage.burst_left = 0.01
	barrage.burst_total = 2.0
	barrage._burst_scale = 1.0
	barrage._burst_pp = 1.0
	barrage._tick_burst(0.02)
	_check(is_equal_approx(barrage._strike_credit, 0.7), "the whole completion fan is one 0.7-credit activation, banked (%0.2f)" % barrage._strike_credit)
	_player.queue_free()
	await get_tree().process_frame

	# --- HYB-01: MR2 generates ranked BR05's ordinary group plus exactly one MR2 bonus fragment on a real fragment execution; no ancestry reset.
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	ledger = Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	ledger.record_purchase("BR05", 100)
	(ledger.state["owned"] as Dictionary)["BR05"] = 4   # a ranked group: five ordinary fragments
	# MR2 parents (data-level shortcut; runtime only needs the ids).
	ledger.record_purchase("G1", 1600, "melee")
	for id in ["EX01", "EX10", "MR2"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_runner.kill_resolved.connect(func(hit: Dictionary, _context: RefCounted) -> void: _kills.append(hit))
	var feed := _runner.engine_for("BR05") as BarrageEngineV5
	var execution := _runner.engine_of_discipline("EX") as ExecutionEngine
	_check(feed != null and execution != null and _runner.engine_for("MR2") != null, "Kill Feed loads both halves: V5 Barrage fragments and V4 Execution finishes")
	if feed != null and execution != null:
		var Df := _runner.native_damage()
		var mark := _spawn_enemy(1.0, _player.global_position + Vector2(60, 0))
		_kills.clear()
		feed.fragments.clear()
		feed._pending_fragments.clear()
		var executions_before := int(execution.counters["executions"])
		feed._spawn_fragment(_player.global_position, 0.6 * Df, 0.4, 0, "BR05", 1, 0, false, "frag:hyb1")
		var fragments_before := int(feed.counters["fragments"])   # after the seed: the death alone emits the rest
		for _i in range(40):
			feed._tick_fragments(0.05)
			if not _kills.is_empty():
				break
		var execution_hit: Dictionary = _kills[0] if _kills.size() == 1 else {}
		_check(_kills.size() == 1 and String(execution_hit.get("path", "")) == "fragment" and String(execution_hit.get("root", "")) == "BR05" and int(execution.counters["executions"]) == executions_before + 1 and int(execution.counters.get("kill_feed", 0)) == 1, "a real seeking fragment killed the victim and Execution finished it once (%d kills, %d executions)" % [_kills.size(), int(execution.counters["executions"]) - executions_before])
		var spawned: Array = feed._pending_fragments.duplicate()
		var group: Array = spawned.filter(func(f): return String(f["root"]) == "BR05")
		var bonus: Array = spawned.filter(func(f): return String(f["root"]) == "MR2")
		_check(int(feed.counters["fragments"]) == fragments_before + 6 and group.size() == 5 and bonus.size() == 1 and spawned.size() == 6, "the death emits rank-4 BR05's five-fragment group plus exactly one MR2 bonus (%d + %d of %d)" % [group.size(), bonus.size(), spawned.size()])
		var lineage := not group.is_empty() and not execution_hit.is_empty()
		for fragment in group:
			lineage = lineage and String(fragment["cast"]) == "frag:hyb1" and int(fragment["gen"]) == int(execution_hit.get("gen", 0)) + 1 and int(fragment["last"]) == mark
		_check(lineage, "the ordinary group inherits the executing fragment's cast, deepens its generation by one and excludes the executed source")
		_check(bonus.size() == 1 and int(bonus[0]["last"]) == mark and int(bonus[0]["gen"]) == int(execution_hit.get("gen", 0)) + 1, "the bonus fragment excludes the executed source and sits one generation deeper")
		_check(bonus.size() == 1 and String(bonus[0]["cast"]) == "frag:hyb1", "the bonus fragment keeps the executing fragment's cast: no ancestry reset (%s)" % (String(bonus[0]["cast"]) if bonus.size() == 1 else "none"))
		if EnemyWorld.is_valid_handle(mark):
			EnemyWorld.remove_enemy(mark, &"test")
	_player.queue_free()
	await get_tree().process_frame

	# --- HYB-05: an existing authored build that now lacks a mandatory prerequisite fails clearly, never silently unlocked or bought nonfunctional.
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var stale := Global.ascension_ledger()
	Global.transaction_followers(100000 - Global.followers, &"dev_grant", {}, false, false)
	var presets: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS))
	var route: Array = []
	for preset in (presets as Dictionary).get("presets", []):
		if String(preset.get("name", "")) == "Barrage developed":
			route = preset["nodes"]
	_check(route.has("BRF2") and not route.has("BR03"), "the authored 'Barrage developed' route buys Thermal Fury without Hot Core, as written")
	var bought := PackedStringArray()
	var stale_at := ""
	var stale_verdict := {}
	var wallet_before_failure := 0
	for entry in route:
		var id := String(entry)
		if id.begins_with("core."):
			continue
		wallet_before_failure = Global.followers
		var verdict := Global.ascension_buy(id)
		if bool(verdict["ok"]):
			bought.append(id)
			continue
		stale_at = id
		stale_verdict = verdict
		break
	_check(stale_at == "BRF2" and bought.size() == 10, "every node before Thermal Fury still buys under the V5 requires; the route stops at %s after %d purchases" % [stale_at, bought.size()])
	_check(not stale_verdict.is_empty() and String(stale_verdict.get("reason", "")).contains("Hot Core"), "the refusal names the missing prerequisite (%s)" % String(stale_verdict.get("reason", "")))
	_check(not stale.owns("BRF2") and int((stale.state["paid"] as Dictionary).get("BRF2", 0)) == 0 and Global.followers == wallet_before_failure, "nothing was unlocked, recorded or paid for the nonfunctional node (%d Followers untouched)" % Global.followers)

	# HYB-01 cast inheritance and the HYB-03 Sigil-side rule were defects found by
	# this sweep (2026-09-27) and are fixed in BarrageEngine.extra_fragment /
	# ExecutionEngine and OrdnanceEngine.explode_attached; asserted above.
	_finish()


func _finish() -> void:
	print("AscensionV5HybridForeignTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
