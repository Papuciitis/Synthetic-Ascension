extends Node

# Gates and the three Fusions of the first slice. A Gate grants a Witness
# strike every second native input (review F12) that qualifies for the
# foreign Core's rules: a Witness Slash is execution-enabled, a Witness
# Impact deposits Debt. Kill Feed lets fragments finish normals at half the
# line and pays an extra fragment; Death Debt turns an executed target's
# unpaid Debt into a Magic blast; Wildfire throws burning fragments from a
# Burn kill. The Reaction Q opens with the first Gate (review F14) and casts
# the second owned Q on a catastrophe at 60% with doubled recovery. The three
# hybrid routes from the review load through the dev loader at their prices.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionHybridTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_hybrid", "res://asc_hybrid.tscn", at, hp, 10.0, 8.0, 0, 0))


func _load(native: String, ids: Array) -> AscensionLedger:
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
	var ledger := Global.ascension_ledger()
	for entry in ids:
		if entry is Array:
			ledger.record_purchase(String(entry[0]), 1600, String(entry[1]))
		else:
			ledger.record_purchase(String(entry), 100)
	_runner.refresh()
	return ledger


func _fire(style: String, target: Vector2) -> void:
	RunEvents.weapon_fired.emit(_player, StringName(style), _player.global_position, target, 1.0, 1.0)


func _count_nodes(type_name: String) -> int:
	var count := 0
	for child in get_tree().current_scene.get_children():
		if child.get_class() == "Area2D" and child.get_script() != null and String(child.get_script().get_global_name()) == type_name:
			count += 1
	return count


func _settle() -> void:
	for _i in range(3):
		await get_tree().physics_frame


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	var origin := _player.global_position

	# --- Witness Slash for a Ranged native that opened Melee
	var ledger := _load("ranged", ["BR01", "BR02", "BRQ", ["G1", "melee"], "EX01"])
	_check(_runner.foreign_cores() == ["melee"], "the Gate opens Melee as a foreign Core")
	var slashes := _count_nodes("MeleeSlash")
	_fire("ranged", origin + Vector2(100, 0))
	_check(_runner.witness_strikes == 0, "the first native input has no Witness")
	_fire("ranged", origin + Vector2(100, 0))
	_check(_runner.witness_strikes == 1 and _count_nodes("MeleeSlash") == slashes + 1, "the second native input emits a Witness Slash")
	var slash: Node = null
	for child in get_tree().current_scene.get_children():
		if child.has_meta("asc_tags") and AscensionTags.value_of(child.get_meta("asc_tags"), "root") == "witness":
			slash = child
	var slash_tags: PackedStringArray = slash.get_meta("asc_tags") if slash != null else PackedStringArray()
	_check(AscensionTags.value_of(slash_tags, "core") == "melee" and AscensionTags.has_flag(slash_tags, "core_strike") and AscensionTags.has_flag(slash_tags, "execute_enabled"), "the Witness Slash is a Melee Core strike that Finish enables (%s)" % str(slash_tags))
	_check(is_equal_approx(float(slash.get("damage")), 0.6 * 15.0), "a Witness Slash deals 0.6 of Melee's D (%s)" % str(slash.get("damage")))
	await _settle()

	# --- Witness Impact for a Melee native that opened Magic, plus Late Payment
	ledger = _load("melee", ["EX01", "EX02", "EXQ", ["G1", "magic"], "DT06", "DTA"])
	var distortion := _runner.engine_for("DT06") as DistortionEngine
	var debtor := _spawn_enemy(300.0, origin + Vector2(120, 0))
	_runner.aim_override = origin + Vector2(120, 0)
	var impacts := _count_nodes("MagicImpact")
	_fire("melee", origin + Vector2(120, 0))
	_fire("melee", origin + Vector2(120, 0))
	_check(_count_nodes("MagicImpact") == impacts + 1, "the Melee native's Witness is an Impact at the aim")
	await _settle()
	var witness_debt := distortion.unpaid_debt(debtor)
	_check(witness_debt > 0.0 and witness_debt < 0.25 * 0.6 * 18.6 + 0.01, "the Witness Impact deposits a quarter of its damage as Debt (%s)" % str(witness_debt))
	var melee_tags := AscensionTags.native("melee", "slash")
	melee_tags = AscensionTags.with_flag(melee_tags, "core_strike")
	_runner.damage_enemy(debtor, 40.0, melee_tags)
	_check(is_equal_approx(distortion.unpaid_debt(debtor), witness_debt + 5.0), "Late Payment deposits 12.5%% of a Melee Core hit (%s)" % str(distortion.unpaid_debt(debtor)))
	EnemyWorld.remove_enemy(debtor, &"test")

	# --- Kill Feed
	ledger = _load("ranged", ["BR01", "BR05", "BRQ", ["G1", "melee"], "EX01", "EX03", "EX10", "MR2"])
	var execution := _runner.engine_for("EX01") as ExecutionEngine
	var barrage := _runner.engine_for("BR05") as BarrageEngine
	var wounded := _spawn_enemy(100.0, origin + Vector2(150, 0))
	var fragment_tags := AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR05", "fragment", 1, 0.4)
	_runner.damage_enemy(wounded, 94.0, fragment_tags)
	_check(_runner.enemy_alive(wounded), "a fragment leaving 6%% is above half the line")
	var ledger_before := int(barrage.counters["fragments"])
	_runner.damage_enemy(wounded, 2.0, fragment_tags)
	_check(not _runner.enemy_alive(wounded) and int(execution.counters["executions"]) == 1, "a fragment leaving 4%% finishes the normal through Kill Feed")
	_check(int(execution.counters.get("kill_feed", 0)) == 1 and int(barrage.counters["fragments"]) == ledger_before + 3, "the fragment execution grants an extra fragment beside the ordinary pair (%d)" % (int(barrage.counters["fragments"]) - ledger_before))
	_check(int(execution.counters["spillovers"]) == 0, "a Ranged kill does not Spillover")
	barrage.fragments.clear()
	barrage._pending_fragments.clear()

	# --- Death Debt
	ledger = _load("melee", ["EX01", "EX02", "EXQ", ["G1", "magic"], "DT06", "MM2", "DTA"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	distortion = _runner.engine_for("DT06") as DistortionEngine
	var indebted := _spawn_enemy(100.0, origin + Vector2(-150, 0))
	var slash_tags2 := AscensionTags.native("melee", "slash")
	slash_tags2 = AscensionTags.with_flag(slash_tags2, "core_strike")
	slash_tags2 = AscensionTags.with_flag(slash_tags2, "execute_enabled")
	_runner.damage_enemy(indebted, 40.0, slash_tags2)
	_check(is_equal_approx(distortion.unpaid_debt(indebted), 5.0), "the swing loads a 5 Debt bill")
	impacts = _count_nodes("MagicImpact")
	_runner.damage_enemy(indebted, 51.0, slash_tags2)
	_check(not _runner.enemy_alive(indebted) and int(execution.counters.get("death_debts", 0)) == 1, "executing the indebted target fires Death Debt")
	_check(distortion.unpaid_debt(indebted) == 0.0 and _count_nodes("MagicImpact") == impacts + 1, "the bill is paid by a Magic blast, not billed to the player")
	await _settle()

	# --- Wildfire
	ledger = _load("ranged", ["BR01", "BR04", "BRQ", ["G1", "magic"], "DT02", "DT10", "RM5"])
	barrage = _runner.engine_for("BR01") as BarrageEngine
	var burning := _spawn_enemy(10.0, origin + Vector2(0, 150))
	EnemyStatus.apply_burn(burning, 1, 3.0, 0.5, 4.0, _player)
	_runner.manifestation_state().set("misfortune", 5)
	EnemyCombat.apply_status_damage(burning, 20.0, _player)
	_check(int(barrage.counters.get("wildfires", 0)) == 1 and int(barrage.counters["fragments"]) == 3, "a Burn kill with five Misfortune throws three burning fragments")
	_check(_runner.misfortune() == 0, "the guarantee spent the Misfortune")
	barrage.fragments.clear()
	barrage._pending_fragments.clear()

	# --- Reaction Q at the first Gate
	ledger = _load("ranged", ["BR01", "BR02", "BRQ", ["G1", "melee"], "EX01", "EX02", "EXQ"])
	_check(ledger.equipped("q") == "BRQ" and ledger.equipped("reaction") == "EXQ", "the second Q fills the Reaction slot the Gate opened")
	_check(_runner.reaction_id == "EXQ", "the runner sees the Reaction Q")
	execution = _runner.engine_for("EX01") as ExecutionEngine
	_runner.aim_override = origin + Vector2(80, 0)
	_runner.note_catastrophe("BRC")
	_check(int(execution.counters["gavels"]) == 1, "a catastrophe casts the Reaction Gavel")
	_check(is_equal_approx(_runner.reaction_cooldown_left, 14.0), "the Reaction recovery is doubled (%s)" % str(_runner.reaction_cooldown_left))
	_check(is_equal_approx(execution._gavel_damage(), 3.0 * 12.0 * 0.6), "the Reaction Gavel deals 60%% (%s)" % str(execution._gavel_damage()))
	_runner.note_catastrophe("BRC")
	_check(int(execution.counters["gavels"]) == 1, "a second catastrophe waits for the recovery")
	execution.tick(0.5)
	await _settle()

	# --- the review's hybrid routes load through the dev loader
	var tools := get_node_or_null("/root/DevSetCollisionTools")
	_check(tools != null and tools.has_method("apply_ascension_route"), "the dev route loader exists")
	if tools != null:
		var expected := {"Kill Feed, ranged side": 18000, "Wildfire, ranged side": 17600, "Death Debt, melee side": 19800}
		for route_name in expected:
			var result: Dictionary = tools.call("apply_ascension_route", route_name, true)
			_check(String(result["failed"]).is_empty(), "route '%s' loads in order (%s)" % [route_name, String(result["failed"])])
			_check(int(result["spent"]) == int(expected[route_name]), "route '%s' costs %d (expected %d)" % [route_name, int(result["spent"]), int(expected[route_name])])
		_runner.refresh()
		_check(_runner.foreign_cores().size() == 1 and _runner.engines.size() == 2, "the Death Debt route runs Execution and Distortion across two Cores (%d)" % _runner.engines.size())

	Global.attempt_ascension = {}
	_player.queue_free()
	_finish()


func _finish() -> void:
	print("AscensionHybridTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
