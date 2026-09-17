extends Node

# Contact-damage bookkeeping on the player: which enemies are currently
# touching, and therefore how hard the swarm multiplier bites.
#
# The audit's coverage gap #13 (2026-08-28) notes player.gd is 1,324 lines
# with two methods exercised. This pins the part that decides how much
# contact damage the player pays, and the specific way it broke when pooled
# enemies started leaving the "enemies" group: EXIT used to be gated on
# group membership, so an enemy parked (pool recycle / representation-lease
# quiesce) while overlapping was never unregistered - the player kept paying
# swarm-scaled damage for it, and a later prune found a freed object.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

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


func _make_enemy(name_hint: String) -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.name = name_hint
	enemy.add_to_group(&"enemies")
	add_child(enemy)
	return enemy


func _touching(player: Node) -> int:
	return int(player.get("_touching_enemies"))


func _run() -> void:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame

	# --- ordinary overlap bookkeeping -------------------------------------
	var a := _make_enemy("EnemyA")
	var b := _make_enemy("EnemyB")
	player.call("_on_hurtbox_body_entered", a)
	_check(_touching(player) == 1, "one overlapping enemy is one contact source (%d)" % _touching(player))
	player.call("_on_hurtbox_body_entered", b)
	_check(_touching(player) == 2, "a second enemy is a second source (%d)" % _touching(player))
	player.call("_on_hurtbox_body_entered", a)
	_check(_touching(player) == 2, "the same enemy twice is still one source (%d)" % _touching(player))
	player.call("_on_hurtbox_body_exited", a)
	_check(_touching(player) == 2, "and needs as many exits as entries (%d)" % _touching(player))
	player.call("_on_hurtbox_body_exited", a)
	_check(_touching(player) == 1, "the balanced exit drops it (%d)" % _touching(player))
	player.call("_on_hurtbox_body_exited", b)
	_check(_touching(player) == 0, "and the last exit clears the swarm (%d)" % _touching(player))

	# --- the regression: parked while overlapping -------------------------
	# A pool recycle or a lease quiesce removes the node from the group while
	# its body is still inside the hurtbox; the exit signal arrives after.
	var parked := _make_enemy("EnemyParked")
	player.call("_on_hurtbox_body_entered", parked)
	_check(_touching(player) == 1, "fixture: the enemy is touching")
	parked.remove_from_group(&"enemies")
	player.call("_on_hurtbox_body_exited", parked)
	_check(
		_touching(player) == 0,
		"an enemy parked while touching is still unregistered on exit (%d)" % _touching(player)
	)

	# --- prune never casts a freed object ---------------------------------
	var doomed := _make_enemy("EnemyDoomed")
	player.call("_on_hurtbox_body_entered", doomed)
	_check(_touching(player) == 1, "fixture: the doomed enemy is touching")
	remove_child(doomed)
	doomed.free()
	player.call("_prune_contact_sources")
	_check(
		_touching(player) == 0,
		"pruning drops a freed enemy without casting it (%d)" % _touching(player)
	)

	# A source whose node left the tree but is still valid also prunes.
	var detached := _make_enemy("EnemyDetached")
	player.call("_on_hurtbox_body_entered", detached)
	remove_child(detached)
	player.call("_prune_contact_sources")
	_check(_touching(player) == 0, "and drops one that left the tree (%d)" % _touching(player))
	detached.free()

	for leftover in [a, b, parked]:
		if is_instance_valid(leftover):
			leftover.free()
	player.free()

	print("PlayerContactSourceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
