extends Node

# Big-hit protection (audit 2026-10-04, change 2): one contact tick takes at
# most 22% of max HP before armour, any other hit 30%, a boss's 45%; a hit
# that costs 8% or more buys 0.35 s of visible invulnerability; pay_health is
# untouched; and the telemetry reports the raw blow and what actually landed.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

var _passes := 0
var _failures := 0
var _resolved: Array[Dictionary] = []
var _changes: Array[Dictionary] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_resolved(_p: Node, raw: float, adjusted: float, applied: float, _source: Node, kind: StringName, outcome: StringName) -> void:
	_resolved.append({"raw": raw, "adjusted": adjusted, "applied": applied, "kind": kind, "outcome": outcome})


func _on_health_changed(_p: Node, change: Dictionary) -> void:
	_changes.append(change.duplicate())


func _run() -> void:
	var previous_luck: float = Global.run_luck
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	RunEvents.player_damage_resolved.connect(_on_resolved)
	RunEvents.balance_health_changed.connect(_on_health_changed)
	Global.run_luck = 0.0 # no Lucky evasion in the way

	var max_hp: float = player.max_hp
	var armour: float = maxf((player.get("stats") as Stats).armor, 0.0) if player.get("stats") != null else 0.0
	var k := 100.0 / (100.0 + armour)
	_check(bool(player.get("big_hit_protection")), "big-hit protection ships on")

	# A contact tick worth 90% of max HP lands as 22%, before armour.
	_reset(player)
	player.call("_take_damage", 0.9 * max_hp, null, &"contact_swarm")
	var lost := max_hp - float(player.get("hp"))
	_check(absf(lost - 0.22 * max_hp * k) < 0.01, "a 90%% contact tick lands as 22%% before armour (%.2f of %.0f)" % [lost, max_hp])
	_check(_resolved.size() == 1 and absf(float(_resolved[0]["raw"]) - 0.9 * max_hp) < 0.01, "telemetry keeps the raw blow (%.1f)" % (float(_resolved[0]["raw"]) if _resolved.size() > 0 else -1.0))
	_check(_resolved.size() == 1 and absf(float(_resolved[0]["applied"]) - lost) < 0.01, "and reports exactly what was applied")
	var change := _last_hit_change()
	_check(not change.is_empty() and absf(float(change["hp_before"]) - float(change["hp_after"]) - lost) < 0.01, "the health record reconciles with the HP lost")

	# A hit of 8% or more buys a 0.35 s visible grace.
	_check(float(player.get("invulnerable_time")) >= 0.349, "a hit costing 8%% or more grants 0.35 s of invulnerability (%.2f)" % float(player.get("invulnerable_time")))
	_check(float(player.get("_blink_left")) > 0.0, "and the body blinks for it")
	var hp_before := float(player.get("hp"))
	player.call("_take_damage", 0.25 * max_hp, null, &"contact_swarm")
	_check(is_equal_approx(float(player.get("hp")), hp_before) and String(_resolved[-1]["outcome"]) == "invulnerable", "a second hit inside the grace is refused and recorded as such")

	# Any other single hit lands as at most 30%.
	_reset(player)
	player.call("_take_damage", 0.8 * max_hp, self, &"unknown")
	lost = max_hp - float(player.get("hp"))
	_check(absf(lost - 0.30 * max_hp * k) < 0.01, "an 80%% bolt lands as 30%% before armour (%.2f)" % lost)

	# A boss's hit is allowed 45%.
	_reset(player)
	var boss := Node2D.new()
	boss.add_to_group(&"boss")
	add_child(boss)
	player.call("_take_damage", 0.8 * max_hp, boss, &"unknown")
	lost = max_hp - float(player.get("hp"))
	_check(absf(lost - 0.45 * max_hp * k) < 0.01, "a boss's 80%% blow lands as 45%% (%.2f)" % lost)
	boss.queue_free()

	# Small hits are untouched and buy no grace.
	_reset(player)
	player.call("_take_damage", 0.05 * max_hp, self, &"unknown")
	var small := max_hp - float(player.get("hp"))
	_check(absf(small - 0.05 * max_hp * k) < 0.01, "a 5% hit lands in full")
	_check(is_zero_approx(float(player.get("invulnerable_time"))), "and grants no grace")
	player.call("_take_damage", 0.05 * max_hp, self, &"unknown")
	_check(absf(max_hp - float(player.get("hp")) - 2.0 * small) < 0.01, "so a second one right after lands too")

	# A lethal-sized blow at full health no longer one-shots.
	_reset(player)
	player.call("_take_damage", 50.0 * max_hp, self, &"unknown")
	_check(float(player.get("hp")) > 0.0 and not bool(player.get("is_dead")), "a blow of fifty times max HP leaves a full-health player standing")

	# pay_health is a cost, not a hit: no cap, no grace.
	_reset(player)
	var paid := float(player.call("pay_health", 0.6 * max_hp, &"test", false))
	_check(absf(paid - 0.6 * max_hp) < 0.01 and is_zero_approx(float(player.get("invulnerable_time"))), "pay_health spends the full 60% and grants nothing")

	# The switch exists for fixture suites only.
	_reset(player)
	player.set("big_hit_protection", false)
	player.call("_take_damage", 0.8 * max_hp, self, &"unknown")
	_check(absf(max_hp - float(player.get("hp")) - 0.8 * max_hp * k) < 0.01 and is_zero_approx(float(player.get("invulnerable_time"))), "with the protection off a hit lands raw")
	player.set("big_hit_protection", true)

	RunEvents.player_damage_resolved.disconnect(_on_resolved)
	RunEvents.balance_health_changed.disconnect(_on_health_changed)
	Global.run_luck = previous_luck
	player.queue_free()
	await get_tree().process_frame
	print("BigHitProtectionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _reset(player: Node) -> void:
	player.set("hp", float(player.get("max_hp")))
	player.set("invulnerable_time", 0.0)
	player.set("_blink_left", 0.0)
	_resolved.clear()
	_changes.clear()


func _last_hit_change() -> Dictionary:
	for i in range(_changes.size() - 1, -1, -1):
		if String(_changes[i].get("category", "")) == "hit":
			return _changes[i]
	return {}
