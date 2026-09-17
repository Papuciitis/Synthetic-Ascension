extends Node

const RESOLVER_PATH := "res://core/systems/world/rite/RitePulseResolver.gd"

var _passes: int = 0
var _failures: int = 0


class FakeCombat:
	extends Node
	var positions: Dictionary = {1: Vector2(100.0, 0.0), 2: Vector2(0.0, 200.0), 3: Vector2.ZERO, 4: Vector2(301.0, 0.0)}
	var knockbacks: Dictionary = {}
	var stuns: Dictionary = {}

	func gather_in_radius(origin: Vector2, radius: float, out: Array[int], _excluded: int = -1) -> void:
		for handle in positions:
			if origin.distance_to(positions[handle]) <= radius:
				out.append(handle)

	func position_for_handle(handle: int) -> Vector2:
		return positions.get(handle, Vector2.ZERO)

	func apply_knockback(handle: int, force: Vector2) -> bool:
		knockbacks[handle] = force
		return true

	func apply_stun(handle: int, seconds: float) -> bool:
		stuns[handle] = seconds
		return true


class FakePlayer:
	extends Node
	var health: float = 40.0
	var max_hp: float = 100.0
	var invulnerability: float = 0.0
	var heal_source: StringName = &""

	func heal(amount: float, source: StringName = &"generic") -> void:
		health = minf(max_hp, health + amount)
		heal_source = source

	func grant_invulnerability(seconds: float) -> void:
		invulnerability = seconds


func _ready() -> void:
	var resolver_script: Script = load(RESOLVER_PATH) as Script
	_check(resolver_script != null, "RitePulseResolver exists")
	if resolver_script == null:
		_finish()
		return
	var combat := FakeCombat.new()
	var player := FakePlayer.new()
	add_child(combat)
	add_child(player)
	var result: Dictionary = resolver_script.call("apply", combat, Vector2.ZERO, 300.0, 600.0, 0.25, player, 0.25, 2.0)
	_check(int(result.get("targets", 0)) == 3, "all gathered handles are affected")
	_check(combat.knockbacks.get(1, Vector2.ZERO).is_equal_approx(Vector2(600.0, 0.0)), "force points away from origin")
	_check(combat.knockbacks.get(3, Vector2.ZERO).is_equal_approx(Vector2(600.0, 0.0)), "zero offset uses deterministic direction")
	_check(not combat.knockbacks.has(4) and not combat.stuns.has(4), "an enemy beyond the pulse remains in the fight")
	_check(is_equal_approx(float(combat.stuns.get(2, 0.0)), 0.25), "stun reaches every handle")
	_check(is_equal_approx(player.health, 55.0), "healing uses missing HP")
	_check(player.heal_source == &"exit_rite", "pulse identifies Rite healing for Doctrine rules")
	_check(is_equal_approx(player.invulnerability, 2.0), "protection is granted")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("RitePulseResolverTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
