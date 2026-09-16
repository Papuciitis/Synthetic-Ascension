extends Node

# Invocation (Magic): Sigils, pulses, Growth, Echoes; Leave a Sigil, Stretch
# Sigil, Endure, Congregation, Fed by Death, Echo Shrine, Warm Circle, Off
# Beat, Detonate Sigil, Chain Pulse, Copy Rune, Home Rune, Consecrate with
# its six mutations, both forks, both keystones, Echo Chamber, Choir, both
# Evolutions, the sinks and THE HOST.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionInvocationTest.tscn

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
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_in", "res://asc_in.tscn", at, hp, 10.0, 8.0, 0, flags))
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


func _load(ids: Array) -> InvocationEngine:
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
	_runner.travel_this_frame = 0.0
	_runner.aim_override = _origin + Vector2(200, 0)
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for entry in ids:
		var id := String(entry[0]) if entry is Array else String(entry)
		var engine := _runner.engine_for(id) as InvocationEngine
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
	var max_hp: float = _player.max_hp

	# ---------------- Leave a Sigil and pulses
	var inv := _load(["IN01", "IN05"])
	var target := _spawn(500.0, origin + Vector2(200, 0))
	for i in range(3):
		_runner.damage_enemy(target, 5.0, _native())
	_check(inv != null and inv.sigils.is_empty(), "three weighted Magic Core hits place nothing")
	_runner.damage_enemy(target, 5.0, _native())
	_check(inv.sigils.size() == 1 and (inv.sigils[0]["at"] as Vector2).distance_to(origin + Vector2(200, 0)) < 1.0, "the fourth places a Sigil at the victim")
	for i in range(4):
		_runner.damage_enemy(target, 5.0, _native())
	_check(inv.sigils.size() == 1 and is_equal_approx(inv._hits, 4.0), "one placement per Core activation; excess progress is banked")
	inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_runner.damage_enemy(target, 5.0, _native())
	_check(inv.sigils.size() == 2, "the next activation spends the bank")
	var hp_before := _runner.enemy_hp(target)
	inv.tick(1.01)
	_check(int(inv.counters["pulses"]) == 2 and is_equal_approx(_runner.enemy_hp(target), hp_before - 2.0 * 0.6 * _D()), "each Sigil pulses once per second for 0.6D in R (%.1f)" % _runner.enemy_hp(target))
	_check(is_equal_approx(float(inv.sigils[0]["life"]), 8.0 - 1.01) and is_equal_approx(inv.capacity(), 3.0), "Sigils live 8 s; base capacity three")

	# ---------------- Growth and Copy Rune
	inv = _load(["IN01", "IN05", "IN11"])
	var sigil := inv.place_sigil(origin + Vector2(200, 0))
	var prey := _spawn(5.0, origin + Vector2(220, 0))
	_runner.damage_enemy(prey, 50.0, _native())
	_check(is_equal_approx(float(sigil["growth"]), 1.0) and is_equal_approx(inv.sigil_damage(sigil), 0.6 * _D() + 0.15 * _D()) and is_equal_approx(inv.sigil_radius(sigil), AscensionRunner.R * 1.08), "a real death within 1.5R grants one Growth: +0.15D and +8%% radius")
	prey = _spawn(5.0, origin + Vector2(220, 0))
	_runner.damage_enemy(prey, 50.0, AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DT01", "impact", 1, 0.5))
	_check(is_equal_approx(float(sigil["growth"]), 1.5), "a generated kill grants half")
	inv.add_growth(sigil, 3.5)
	_check(int(inv.counters["children"]) == 1 and inv.sigils.size() == 2 and is_equal_approx(float(inv.sigils[1]["radius"]), 0.5 * AscensionRunner.R) and is_equal_approx(float(inv.sigils[1]["life"]), 6.0), "at five Growth Copy Rune spawns one half-size child for 6 s")
	inv.add_growth(sigil, 1.0)
	_check(int(inv.counters["children"]) == 1, "a parent keeps one living child")

	# ---------------- Echo Shrine, expiry release, capacity
	inv = _load(["IN01", "IN06"])
	sigil = inv.place_sigil(origin)
	inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_check((sigil["echoes"] as Array).size() == 1 and int(inv.counters["echoes_stored"]) == 1, "a Magic Core strike made inside a Sigil stores one Echo")
	for i in range(3):
		inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_check((sigil["echoes"] as Array).size() == 3 and int(inv.counters["echoes_released"]) == 1, "a Sigil stores three; the fourth releases the oldest")
	var listener := _spawn(500.0, origin + Vector2(60, 0))
	inv.tick(8.1)
	_runner.flush_attacks()
	_check(inv.sigils.is_empty() and int(inv.counters["echoes_released"]) == 4 and _runner.enemy_hp(listener) < 500.0, "expiry releases stored Echoes toward current enemies (%.1f)" % _runner.enemy_hp(listener))
	inv = _load(["IN01", "IN05", "IN06", "IN09"])
	var near := _spawn(5000.0, origin + Vector2(200, 0))
	var first := inv.place_sigil(origin + Vector2(200, 0))
	inv.place_sigil(origin + Vector2(400, 0))
	inv.place_sigil(origin + Vector2(600, 0))
	first["growth"] = 2.0
	inv.place_sigil(origin + Vector2(800, 0))
	_check(inv.sigils.size() == 3 and not inv.sigils.has(first) and int(inv.counters["detonations"]) == 1 and is_equal_approx(_runner.enemy_hp(near), 5000.0 - 1.5 * _D() - 0.3 * _D() * 2.0), "at capacity the oldest is replaced; Detonate Sigil explodes it for 1.5D + 0.3D per Growth (%.1f)" % _runner.enemy_hp(near))
	var full: Dictionary = inv.sigils[0]
	full["growth"] = 5.0
	inv.add_growth(full, 1.0)
	_check(is_equal_approx(float(full["growth"]), 2.0) and int(inv.counters["detonations"]) == 2 and inv.sigils.has(full), "Growth overflow detonates for three Growth and keeps the Sigil")

	# ---------------- Endure, Congregation, Warm Circle
	inv = _load(["IN01", "IN03", "IN04", "IN05", "IN07"])
	sigil = inv.place_sigil(origin)
	sigil["growth"] = 3.0
	inv.tick(1.0)
	_check(is_equal_approx(float(sigil["life"]), 8.0) and is_equal_approx(float(sigil["growth"]), 2.0), "Endure: standing inside pauses expiry for one Growth per second")
	var second := inv.place_sigil(origin + Vector2(120, 0))
	var third := inv.place_sigil(origin + Vector2(240, 0))
	_check(inv.capacity() == 5, "Congregation: each connected parent beyond the first adds a slot (%d)" % inv.capacity())
	prey = _spawn(5.0, origin + Vector2(60, 0))
	_runner.damage_enemy(prey, 50.0, _native())
	_check(is_equal_approx(float(second["growth"]), 1.0) and is_equal_approx(float(sigil["growth"]), 2.0), "touching Sigils give the kill to their least-grown member")
	var pair := _spawn_attacker(500.0, origin + Vector2(40, 0))
	_player.hp = max_hp
	_player.take_damage(0.2 * max_hp, pair[1])
	_check(absf(_player.hp - (max_hp - 0.2 * max_hp * 0.65)) < 0.5 and is_equal_approx(float(sigil["growth"]), 1.0) and int(inv.counters["warm_circles"]) == 1 and (sigil["echoes"] as Array).size() == 1, "Warm Circle prevents 35%% of a hit inside a grown Sigil for one Growth and stores a 0.8D Echo (hp %.1f)" % _player.hp)
	_player.take_damage(0.2 * max_hp, pair[1])
	_check(int(inv.counters["warm_circles"]) == 1, "once per 2 s")
	_check(third != null, "third present")

	# ---------------- Stretch, Off Beat, Chain Pulse, Home Rune
	inv = _load(["IN02", "IN08", "IN10", "IN12"])
	inv._travel = AscensionRunner.L
	inv.tick(0.01)
	inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_check(inv.sigils.size() == 1 and int(inv.counters["placed"]) == 1, "Stretch Sigil: after L of travel the next impact places a Sigil when none exists")
	inv._travel = AscensionRunner.L
	inv.tick(0.01)
	inv.on_native_fire("magic", origin, origin + Vector2(400, 0), 1.0, 1.0)
	_check(int(inv.counters["stretches"]) == 1 and absf((inv.sigils[0]["at"] as Vector2).x - (origin.x + 200.0 + AscensionRunner.R)) < 3.0, "otherwise the nearest Sigil stretches up to R toward the impact (%s)" % str(inv.sigils[0]["at"]))
	sigil = inv.sigils[0]
	sigil["pulse"] = 1.0
	inv.on_native_fire("magic", origin, (sigil["at"] as Vector2) + Vector2(AscensionRunner.R * 0.9, 0), 1.0, 1.0)
	_check(is_equal_approx(float(sigil["pulse"]), 0.6), "Off Beat: an impact in the outer third advances the pulse 0.4 s")
	inv.on_native_fire("magic", origin, sigil["at"], 1.0, 1.0)
	_check(is_equal_approx(float(sigil["pulse"]), 0.8) and is_equal_approx(float(sigil["next_echo_bonus"]), 0.4 * _D()), "a centre impact delays 0.2 s and gives the next Echo +0.4D")
	for i in range(6):
		_spawn(500.0, (sigil["at"] as Vector2) + Vector2(10 * i, 10))
	var far_sigil := inv.place_sigil(origin + Vector2(700, 0))
	var pulses_before := int(inv.counters["pulses"])
	inv.pulse(sigil)
	_check(int(inv.counters["chain_pulses"]) == 1 and int(inv.counters["pulses"]) == pulses_before + 2, "Chain Pulse: a pulse hitting six commands the nearest unpulsed Sigil")
	_check(bool(far_sigil["home"]), "Home Rune: the newest parent is the homing one")
	far_sigil["at"] = origin + Vector2(700, 0)
	inv.tick(1.0)
	_check((far_sigil["at"] as Vector2).x < origin.x + 700.0 - 0.5 * AscensionRunner.L + 1.0, "it follows at 0.5L/s (%s)" % str(far_sigil["at"]))
	far_sigil["at"] = (sigil["at"] as Vector2) + Vector2(20, 0)
	inv.tick(0.01)
	_check(int(inv.counters["home_touches"]) == 1, "touching another Sigil pulses both once")

	# ---------------- Consecrate and mutations
	inv = _load(["IN01", "IN05", "INQ"])
	var near_q := _spawn(5000.0, origin + Vector2(200, 0))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and inv.sigils.size() == 1 and is_equal_approx(_runner.q_cooldown_left, 7.0) and is_equal_approx(_runner.enemy_hp(near_q), 5000.0 - 0.6 * _D()), "Q places a Sigil at the cursor and commands every Sigil to pulse (%.1f)" % _runner.enemy_hp(near_q))
	inv = _load(["IN01", "IN05", "IN06", "INQ", "INQ1", "INQ2", "INQ6"])
	sigil = inv.place_sigil(origin + Vector2(100, 0))
	(sigil["echoes"] as Array).append(inv._new_echo("magic", origin, origin + Vector2(100, 0), 0.6 * _D(), 0.4))
	var between := _spawn(5000.0, origin + Vector2(150, 0))
	_runner.activate_q()
	_check(inv.sigils.size() == 2 and int(inv.sigils[1]["slots"]) == 2 and is_equal_approx(float(inv.sigils[1]["radius"]), 2.0 * AscensionRunner.R) and int(inv.sigils[1]["echo_slots"]) == 6, "Great Sigil: 2R, six Echo slots, two slots")
	_check(int(inv.counters["resonance_lines"]) == 1 and int(inv.counters["echoes_released"]) == 1, "Resonance draws one line per pair; Open the Vault releases stored Echoes")
	_check(between != 0, "between present")
	inv = _load(["IN01", "IN05", "INQ", "INQ4", "INQ3"])
	_runner.activate_q()
	_check(inv.sigils.size() == 3 and is_equal_approx(float(inv.sigils[0]["radius"]), 0.7 * AscensionRunner.R) and bool(inv.sigils[0]["follow_cursor"]), "Swarm places three small Sigils; Wandering makes them follow the cursor")
	_runner.aim_override = origin + Vector2(300, 0)
	var before_x: float = (inv.sigils[0]["at"] as Vector2).x
	inv.tick(0.1)
	_check((inv.sigils[0]["at"] as Vector2).x > before_x, "they move toward the cursor at L/s")
	inv = _load(["IN01", "IN05", "IN09", "INQ", "INQ5"])
	sigil = inv.place_sigil(origin + Vector2(100, 0))
	sigil["life"] = 3.5
	_runner.activate_q()
	_check(int(inv.counters["consumed"]) == 1 and int(inv.counters["detonations"]) == 1 and inv.sigils.size() == 1 and inv._consume_queue.size() == 1 and int(inv._consume_queue[0]["pulses"]) == 3, "Consume destroys the old network, detonating it and scheduling its remaining pulses at the cursor")
	inv.tick(1.05)
	_check(inv._consume_queue.is_empty() and int(inv.counters["pulses"]) >= 4, "the stored pulses release over one second")

	# ---------------- forks and keystones
	inv = _load(["IN01", "IN05", "IN06", "IN11", "INF1"])
	sigil = inv.place_sigil(origin + Vector2(100, 0))
	_spawn(500.0, origin + Vector2(300, 0))
	_check(is_equal_approx(inv.sigil_radius(sigil), 0.75 * AscensionRunner.R), "Roaming Sigils: radius -25%%")
	inv.tick(0.5)
	_check((sigil["at"] as Vector2).x > origin.x + 100.0 + 0.7 * AscensionRunner.L * 0.5 - 1.0, "parents move toward enemies at 0.7L/s (%s)" % str(sigil["at"]))
	inv = _load(["IN01", "IN05", "IN06", "IN11", "INF2"])
	sigil = inv.place_sigil(origin + Vector2(100, 0))
	inv.add_growth(sigil, 5.0)
	_check(int(inv.counters["children"]) == 2 and inv.sigils.size() == 3 and is_equal_approx(float(inv.sigils[1]["growth"]), 5.0), "Split Sigils: a full parent creates two children sharing its Growth")
	inv = _load(["IN01", "IN05", "IN06", "IN10", "INK1"])
	sigil = inv.place_sigil(origin + Vector2(100, 0))
	var pulsed := _spawn(500.0, origin + Vector2(120, 0))
	for i in range(4):
		inv.pulse(sigil)
	_check(inv.sigils.size() == 1 and is_equal_approx(inv._hits, 1.6), "Inherit the Word: pulses advance Leave a Sigil at their Proc Power (%.1f)" % inv._hits)
	for i in range(6):
		inv.pulse(sigil)
	_check(inv.sigils.size() == 2, "ten pulses place a Sigil")
	_runner.damage_enemy(pulsed, 10.0, _native())
	_check(is_equal_approx(_runner.enemy_hp(pulsed), 500.0 - 10.0 * 0.6 * _D() - 7.5), "and native Magic damage is 25%% lower (%.1f)" % _runner.enemy_hp(pulsed))
	inv = _load(["IN01", "IN05", "IN06", "IN10", "INK2"])
	_player.hp = max_hp
	inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_check(int(inv.counters["blood_sigils"]) == 1 and is_equal_approx(float(inv.sigils[0]["growth"]), 2.0) and is_equal_approx(_player.hp, max_hp * 0.97), "Blood Rune: a native Magic attack places a Sigil with two Growth for 3%% current HP")
	_check(is_equal_approx(_runner.get_heal_multiplier(), 0.75), "healing is reduced 25%% while a blood Sigil lives")
	_player.hp = 0.2 * max_hp
	inv.on_native_fire("magic", origin, origin + Vector2(200, 0), 1.0, 1.0)
	_check(int(inv.counters["blood_sigils"]) == 1, "blood placement stops at 25%% max HP")
	_player.hp = max_hp

	# ---------------- Echo Chamber, Choir
	inv = _load(["IN01", "IN05", "IN06", "IN10", "IN11", "INA", ["G1", "melee"], "EX01", "EX02"])
	sigil = inv.place_sigil(origin)
	inv.on_native_fire("melee", origin, origin + Vector2(60, 0), 1.0, 1.0)
	_check((sigil["echoes"] as Array).size() == 1 and String(sigil["echoes"][0]["core"]) == "melee" and is_equal_approx(float(sigil["echoes"][0]["damage"]), 0.6 * _runner.native_damage_for("melee")), "Echo Chamber stores a foreign Core strike with its own geometry at 0.6D")
	inv = _load(["IN01", "IN05", "IN06", "IN10", "IN11", "INC"])
	var a := inv.place_sigil(origin + Vector2(100, 0))
	var b := inv.place_sigil(origin + Vector2(300, 0))
	var c := inv.place_sigil(origin + Vector2(500, 0))
	for s in [a, b, c]:
		inv.add_growth(s, 1.0)
	var on_line := _spawn(5.0, origin + Vector2(200, 0))
	for i in range(6):
		_spawn(500.0, origin + Vector2(100 + 8 * i, 12))
	inv.pulse(a)
	_check(int(inv.counters["choirs"]) == 1 and not _runner.enemy_alive(on_line) and int(inv.counters["choir_detonations"]) == 1, "Choir: with three grown Sigils the next Chain Pulse pulses all, draws lines, and a line kill detonates a Sigil for 2D")
	_check(inv._choir_recovery > 0.0, "Choir recovers over 8 s")

	# ---------------- Evolutions and sinks
	inv = _load(["IN01", "IN05", "IN06", "INQ", "INF1", "INQ3", "MO04", "INE1"])
	_runner.activate_q()
	_check(not inv._band.is_empty() and float(inv._band["left"]) == 6.0, "Mobile Choir forms the new Sigils into a band")
	inv.tick(0.1)
	_check((inv.sigils[0]["at"] as Vector2).distance_to(origin) < 1.5 * AscensionRunner.R, "the band orbits the player")
	inv = _load(["IN01", "IN05", "IN06", "IN10", "INQ", "INF2", "INQ6", "INE2"])
	inv.place_sigil(origin + Vector2(100, 0))
	inv.place_sigil(origin + Vector2(300, 0))
	_runner.activate_q()
	_check(inv._web_left > 0.0 and int(inv.counters["web_edges"]) >= 2, "Sigil Web connects the network and pulses travel along the two nearest links")
	inv = _load(["IN01", "IN05", "IN06", "IN10", "INS1", "INS1", "INS1", "INS1", "INS2", "INS2"])
	sigil = inv.place_sigil(origin)
	_check(is_equal_approx(float(sigil["life"]), 8.0 + 0.25 * 2.0) and is_equal_approx(inv.sigil_damage(sigil), 0.6 * _D() * (1.0 + 0.005 * 2.0)) and is_equal_approx(inv.sigil_radius(sigil), AscensionRunner.R * (1.0 + 0.8 * 2.0 / 107.0)), "sinks: Sigil Life 0.25 s and 0.5%% per sqrt(rank); Sigil Size 80%% x rank/(rank+105)")

	# ---------------- THE HOST
	inv = _load(["IN01", "IN05", "IN06", "IN10", "IN11", "INC", "INV"])
	a = inv.place_sigil(origin + Vector2(100, 0))
	var hosted := _spawn(50000.0, origin + Vector2(110, 0))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and inv.host_left > 5.9 and int(inv.counters["host_copies"]) == 1 and inv.sigils.size() == 4, "V duplicates each Sigil and fills to three parents with blanks (%d)" % inv.sigils.size())
	var before_pulses := int(inv.counters["pulses"])
	inv.tick(1.0)
	_check(int(inv.counters["pulses"]) - before_pulses >= 9, "pulse speed triples (%d pulses in a second)" % (int(inv.counters["pulses"]) - before_pulses))
	_check(_runner.enemy_hp(hosted) < 50000.0, "copies pulse at half damage on the target (%.1f)" % _runner.enemy_hp(hosted))
	inv.tick(5.1)
	_check(inv.host_left <= 0.0 and inv.sigils.size() == 1, "after 6 s copies and blanks are removed")
	inv = _load(["IN01", "IN05", "IN06", "IN10", "IN11", "INC", "INV", "INV3"])
	a = inv.place_sigil(origin + Vector2(100, 0))
	hosted = _spawn(50000.0, origin + Vector2(400, 0))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	inv.tick(1.01)
	_check(int(inv.counters["one_voice_pulses"]) == 1 and is_equal_approx(_runner.enemy_hp(hosted), 50000.0 - 3.0 * _D()) and inv.sigils.is_empty(), "One Voice: one screen-sized pulse per second for at least 3D while originals are stored (%.1f)" % _runner.enemy_hp(hosted))
	inv.tick(5.1)
	_check(inv.sigils.size() == 1 and inv.host_left <= 0.0, "originals return when the state ends")

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionInvocationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
