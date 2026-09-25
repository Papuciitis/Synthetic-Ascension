extends Node

# Ranged V5 cross-tree and foreign-Core adapters (handoff 2026-09-25, spec
# §5): foreign Spin Up stages ride real Witness shots and buff the shot
# itself, foreign Reserve Feed earns and releases through Witness cadence,
# Rune Bomb converts a travelling grenade into one genuine Sigil Mine, named
# Hot Rounds deaths carry their provenance (and radiant deaths do not),
# Heavy Barrel spends Force once on a real Vent Volley, genuine Mines stay
# supported, and the V5 requires make stale routes fail loudly.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionV5HybridForeignTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

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
	for id in ["BR03", "BR04", "OR02", "OR06", "ORQ", "BR08"]:
		ledger.record_purchase(id, 100)
	# RM7 and MR8 parents (data-level shortcut; runtime only needs the ids).
	ledger.record_purchase("G1", 1600, "magic")
	for id in ["IN01", "IN09", "RM7", "BA01", "MR8"]:
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

	# ---------------- Rune Bomb: a travelling grenade becomes one Sigil Mine.
	if EnemyWorld.is_valid_handle(radiant_victim):
		EnemyWorld.remove_enemy(radiant_victim, &"test")
	if EnemyWorld.is_valid_handle(burn_victim):
		EnemyWorld.remove_enemy(burn_victim, &"test")
	var sigil_at: Vector2 = _player.global_position + Vector2(120, 0)
	invocation.place_sigil(sigil_at, "plain")
	_check(invocation.sigils.size() >= 1, "a Sigil stands in the grenade's path")
	_runner.aim_override = _player.global_position + Vector2(240, 0)
	ordnance.grenades.clear()
	ordnance._launch_grenades(1, "OR02")
	var mines_before := ordnance.mines.size()
	for _i in range(6):
		ordnance.tick(0.06)
	_check(ordnance.grenades.is_empty() and ordnance.mines.size() == mines_before + 1, "the grenade crossing the Sigil became a Mine, never both")
	var mine: Dictionary = ordnance.mines[ordnance.mines.size() - 1] if not ordnance.mines.is_empty() else {}
	_check(int(mine.get("sigil", 0)) != 0, "the Mine is attached to the Sigil")
	_check(int(ordnance.counters.get("rune_bombs", 0)) == 1 and int(ordnance.counters.get("grenade_blasts", 0)) == 0, "the conversion transferred one logical explosive without detonating")
	# Genuine Mine producers keep working: an ordinary drop obeys the V4 cap.
	_check(ordnance.mine_cap() == 12, "the ordinary 12-Mine cap survives (Bandolier no longer raises it)")
	ordnance.drop_mine(_player.global_position + Vector2(-60, 0), OrdnanceEngine.MINE_D, "MR6")
	_check(ordnance.mines.size() == mines_before + 2, "a hybrid Mine producer still drops genuine Mines")

	# ---------------- Heavy Barrel: one Force spend per real Vent Volley.
	var bastion := _runner.engine_of_discipline("BA") as BastionEngine
	_check(bastion != null, "the Bastion engine carries Force for MR8")
	if bastion != null:
		bastion.force = 60.0
		barrage._auto_vent_volley(_player.global_position, false)
		_check(is_zero_approx(bastion.force), "the Vent Volley spent the 60 Force exactly once")
		_check(is_equal_approx(float(barrage.counters.get("heavy_barrel_force", 0.0)), 60.0), "MR8 recorded the single spend")
		_check(is_equal_approx(barrage._heavy_barrel_bonus, 0.06 * Dr * 60.0 * 0.5), "BRC's half snapshot is banked without another spend")

	# ---------------- Burst completion banks one 0.7 strike credit.
	barrage._strike_credit = 0.0
	barrage.burst_left = 0.01
	barrage.burst_total = 2.0
	barrage._burst_scale = 1.0
	barrage._burst_pp = 1.0
	barrage._tick_burst(0.02)
	_check(is_equal_approx(barrage._strike_credit, 0.7), "the whole completion fan is one 0.7-credit activation, banked (%0.2f)" % barrage._strike_credit)

	# ---------------- stale routes fail loudly under the V5 requires.
	var fresh := AscensionLedger.new(AscensionTreeDB.shared_for("v5_ranged"), AscensionLedger.fresh_state("ranged", "v5_ranged"))
	fresh.record_purchase("BR01", 0)
	for id in ["BR02", "BR04", "BR05", "BR08"]:
		fresh.record_purchase(id, 100)
	var verdict := fresh.can_buy("BRF2", 1000000)
	_check(not bool(verdict["ok"]) and String(verdict["reason"]).contains("Hot Core"), "Thermal Fury without Hot Core fails with the reason named (%s)" % String(verdict["reason"]))

	_finish()


func _finish() -> void:
	print("AscensionV5HybridForeignTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
