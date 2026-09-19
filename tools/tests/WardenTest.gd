extends Node

# Roster audit N1: the Warden's frontal shield swallows projectiles and
# impacts from the front, passes melee, drops after eight hits or one from
# behind, and comes back after a second.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/WardenTest.tscn

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const WARDEN_SPEC := preload("res://core/actors/enemy/EnemySpec_Warden.tres")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _bolt() -> BalanceProvenance:
	return BalanceAttribution.provenance("native:ranged", "native:ranged:bullet_node", "native", "ranged")


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _run() -> void:
	Global.start_new_attempt()
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(200, 0)
	add_child(player)
	var warden := ENEMY_SCENE.instantiate() as EnemyActor
	warden.spec = WARDEN_SPEC
	warden.global_position = Vector2.ZERO
	add_child(warden)
	await get_tree().process_frame
	await get_tree().process_frame
	warden.player = player
	# Drive the shield by hand: the actor's own step would turn it meanwhile.
	warden.set_physics_process(false)
	for i in 10:
		warden.call("_update_front_shield", 0.1)
	var handle: int = EnemyCombat.handle_for_actor(warden)
	var max_hp: float = EnemyWorld.get_max_health(handle)
	_check(warden.is_front_shield_up() and warden.front_shield_facing().dot(Vector2.RIGHT) > 0.99, "the Warden faces the player with its shield up")
	var applied: float = EnemyCombat.apply_damage(handle, 5.0, 1, player, _bolt())
	_check(is_equal_approx(applied, 0.0) and is_equal_approx(EnemyWorld.get_health(handle), max_hp), "a bolt from the front is absorbed")
	var melee: float = EnemyCombat.apply_damage(handle, 5.0, 1, player, null)
	_check(is_equal_approx(melee, 5.0), "a melee hit from the front lands (%.1f)" % melee)
	for i in 7:
		EnemyCombat.apply_damage(handle, 5.0, 1, player, _bolt())
	_check(not warden.is_front_shield_up(), "the eighth absorbed bolt drops the shield")
	var through: float = EnemyCombat.apply_damage(handle, 5.0, 1, player, _bolt())
	_check(is_equal_approx(through, 5.0), "and the next bolt lands (%.1f)" % through)
	warden.call("_update_front_shield", 1.3)
	_check(warden.is_front_shield_up(), "after its second down the shield is back")
	player.global_position = Vector2(-200, 0)
	var behind: float = EnemyCombat.apply_damage(handle, 5.0, 1, player, _bolt())
	_check(is_equal_approx(behind, 5.0) and not warden.is_front_shield_up(), "a bolt from behind lands and drops the shield")
	warden.call("_update_front_shield", 1.3)
	var turned_after_a_second := warden.front_shield_facing()
	_check(turned_after_a_second.dot(Vector2.LEFT) > 0.99, "a full second turns the shield all the way round (140 degrees per second)")
	player.global_position = Vector2(0, 200)
	for i in 3:
		warden.call("_update_front_shield", 0.1)
	_check(warden.front_shield_facing().dot(Vector2.DOWN) < 0.95 and warden.front_shield_facing().dot(Vector2.DOWN) > 0.2, "three tenths of a second turn the shield part of the way toward a new position (%.2f)" % warden.front_shield_facing().angle())
	for i in 10:
		warden.call("_update_front_shield", 0.1)
	_check(warden.front_shield_facing().dot(Vector2.DOWN) > 0.99, "and a second more brings it round")
	warden.queue_free()
	player.queue_free()
	print("WardenTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
