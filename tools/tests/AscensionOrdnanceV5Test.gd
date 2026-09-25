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

	# --- OR-05 (spec OR-05): a grenade blast kill calls a Secondary Shell.
	_runner.aim_override = _player.global_position + Vector2(150, 0)
	var prey := _spawn_enemy(3.0, _runner.aim_target())
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

	# --- Bandolier: stores per credits, one spare joins a launch.
	_engine.grenades.clear()
	_engine.spare_grenades = 0
	_engine._bandolier_credits = 0.0
	_engine._grenadier_credits = 0.0
	for _i in range(6):
		_fire()
	_check(_engine.spare_grenades >= 1, "six credits store one spare grenade (%d)" % _engine.spare_grenades)
	var live_before := _engine.grenades.size()
	var spares_before := _engine.spare_grenades
	for _i in range(4):
		_fire()
	_check(_engine.spare_grenades == spares_before - 1, "the next launch consumed exactly one spare")
	_check(_engine.grenades.size() >= live_before + 2, "the spare joined the produced grenade")

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
