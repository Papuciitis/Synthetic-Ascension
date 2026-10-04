extends Node

# Reconstruction near the Exit Rite (audit 2026-10-04, change 9; plan
# 2026-09-17 §6.4): after the unseal, a death near a revealed, unlocked rite
# rebuilds the player 800-1200 px from it, toward where they died, on a point
# the spawner calls valid - never in the channel circle or a wall - with 5 s
# of invulnerability and phasing (attacking after 2 s ends the invulnerability).
# Otherwise, or when the checkpoint is nearer the rite, the checkpoint as
# before. A fake rite and spawner stand in for the world.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

class FakeRite extends Node2D:
	var revealed := true
	var locked := false
	var radius := 168.0
	var _completed := false

class FakeSpawner extends Node:
	## World rectangles the fake calls unwalkable.
	var walls: Array[Rect2] = []
	var everything_blocked := false
	var asked := 0

	func is_beat_position_valid(point: Vector2) -> bool:
		asked += 1
		if everything_blocked:
			return false
		for wall in walls:
			if wall.has_point(point):
				return false
		return true

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var previous_unsealed: bool = ThreatDirector.gate_unsealed
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	var rite := FakeRite.new()
	rite.add_to_group(&"exit_rite")
	rite.global_position = Vector2(5000.0, 0.0)
	add_child(rite)
	var spawner := FakeSpawner.new()
	spawner.add_to_group(&"enemy_spawner")
	add_child(spawner)
	player.set("spawn_pos", Vector2.ZERO)
	var death := Vector2(3200.0, 0.0) # 1,800 px short of the rite

	# Sealed gate: the checkpoint, as before.
	ThreatDirector.gate_unsealed = false
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2.ZERO, "before the unseal a death rebuilds at the checkpoint")
	_check(absf(float(player.get("invulnerable_time")) - float(player.get("respawn_invuln_time"))) < 0.01, "with the usual protection")

	# Unsealed: near the rite, toward the death.
	ThreatDirector.gate_unsealed = true
	_die_at(player, death)
	player.call("respawn")
	var landed: Vector2 = player.global_position
	var from_rite := landed.distance_to(rite.global_position)
	_check(from_rite >= 800.0 and from_rite <= 1200.0, "after the unseal it rebuilds 800-1200 px from the rite (%.0f px)" % from_rite)
	_check(landed.x < rite.global_position.x and absf(landed.y) < 1.0, "on the side the player died on (%s)" % landed)
	_check(from_rite > rite.radius, "outside the channel circle")
	_check(float(player.get("invulnerable_time")) >= 4.99 and float(player.get("respawn_phase_left")) >= 4.99, "with 5 s of invulnerability and phasing")

	# Attacking inside the first 2 s keeps the invulnerability; after, ends it.
	_step(player, 1.0)
	player.call("_step_attack_input", true, true, false, false, 0.016)
	_check(float(player.get("invulnerable_time")) > 3.5, "an attack 1 s in keeps the invulnerability (%.2f)" % float(player.get("invulnerable_time")))
	_step(player, 1.2)
	player.set("_weapon_cd", 0.0)
	player.call("_step_attack_input", true, true, false, false, 0.016)
	_check(is_zero_approx(float(player.get("invulnerable_time"))), "an attack after 2 s ends it (%.2f)" % float(player.get("invulnerable_time")))
	_check(float(player.get("respawn_phase_left")) > 2.0, "while the phasing holds for the full 5 s (%.2f)" % float(player.get("respawn_phase_left")))
	_step(player, 3.0)

	# A wall on the preferred line: another valid point, still never inside.
	spawner.walls = [Rect2(3700.0, -300.0, 700.0, 600.0)]
	_die_at(player, death)
	player.call("respawn")
	landed = player.global_position
	from_rite = landed.distance_to(rite.global_position)
	_check(not spawner.walls[0].has_point(landed), "a blocked line is never used (%s)" % landed)
	_check(from_rite >= 800.0 and from_rite <= 1200.0, "it swings round to another point 800-1200 px out (%.0f px)" % from_rite)
	spawner.walls.clear()

	# Nowhere valid: the checkpoint.
	spawner.everything_blocked = true
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2.ZERO, "with no valid point it falls back to the checkpoint")
	spawner.everything_blocked = false

	# A checkpoint nearer the rite than any recovery point wins.
	player.set("spawn_pos", Vector2(4500.0, 300.0))
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2(4500.0, 300.0), "a checkpoint nearer the rite is kept")
	player.set("spawn_pos", Vector2.ZERO)

	# A locked or finished rite does not count.
	rite.locked = true
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2.ZERO, "a locked rite does not pull the respawn")
	rite.locked = false
	rite._completed = true
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2.ZERO, "nor does a completed one")
	rite._completed = false

	# Nothing to validate against: no relocation at all.
	spawner.remove_from_group(&"enemy_spawner")
	_die_at(player, death)
	player.call("respawn")
	_check(player.global_position == Vector2.ZERO, "without a spawner or chunk map it never guesses")

	# The real ExitRite is read by the same property names.
	rite.remove_from_group(&"exit_rite")
	var real := (load("res://scenes/world/gates/ExitRite.tscn") as PackedScene).instantiate() as ExitRite
	real.position = Vector2(-6000.0, 0.0)
	add_child(real)
	await get_tree().process_frame
	real.set_process(false)
	real.set_locked(false)
	_check(player.call("_live_exit_rite") == real, "a real revealed, unlocked rite is found")
	real.set_locked(true)
	_check(player.call("_live_exit_rite") == null, "and a real locked one is not")
	real.queue_free()

	ThreatDirector.gate_unsealed = previous_unsealed
	player.queue_free()
	rite.queue_free()
	spawner.queue_free()
	await get_tree().process_frame
	print("RiteRespawnTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Puts the body where it fell, without the death card's await chain.
func _die_at(player: Node2D, at: Vector2) -> void:
	player.global_position = at
	player.set("is_dead", true)
	player.set("_death_position", at)
	player.set("invulnerable_time", 0.0)
	player.set("respawn_phase_left", 0.0)
	player.set("_rite_recovery_left", 0.0)


func _step(player: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		player.call("_process", minf(0.05, left))
		left -= 0.05
