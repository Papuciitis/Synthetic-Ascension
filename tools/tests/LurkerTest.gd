extends Node

# Roster audit N3: the Lurker spawns dormant, holds its distance while the
# player moves, and charges only once the player has stood still for a
# second.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/LurkerTest.tscn

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const LURKER_SPEC := preload("res://core/actors/enemy/EnemySpec_Lurker.tres")

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


func _run() -> void:
	Global.start_new_attempt()
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(0, 0)
	add_child(player)
	var lurker := ENEMY_SCENE.instantiate() as EnemyActor
	lurker.spec = LURKER_SPEC
	lurker.global_position = Vector2(300, 0)
	add_child(lurker)
	await get_tree().process_frame
	await get_tree().process_frame
	var charge: EnemyCharge = lurker.get("_charge")
	lurker.player = player
	_check(charge.is_dormant(), "the Lurker spawns dormant")
	var to_player := player.global_position - lurker.global_position
	_check(charge.brain(to_player, to_player.length()) == Vector2.ZERO, "and does not move while dormant")
	for i in 100:
		charge.tick(0.02)
	_check(not charge.is_dormant(), "after 1.5 s it wakes")
	# The player keeps moving: no charge, hold the distance.
	player.velocity = Vector2(200, 0)
	for i in 100:
		charge.tick(0.02)
	var moving := charge.brain(to_player, to_player.length())
	_check(charge.player_still_for() == 0.0 and moving.dot(to_player) < 0.0, "while the player moves it backs off from 300 px toward its 360 px hold")
	var far := Vector2(600, 0)
	_check(charge.brain(far, far.length()).dot(far) > 0.0, "and drifts closer when the player is far")
	_check(float(lurker.get("_charge").get("_windup_left")) == 0.0, "no wind-up has started")
	# The player stands still for a second: the charge comes.
	player.velocity = Vector2.ZERO
	for i in 60:
		charge.tick(0.02)
	var reaction := charge.brain(to_player, to_player.length())
	_check(charge.player_still_for() >= 1.0 and reaction == Vector2.ZERO and float(charge.get("_windup_left")) > 0.0, "once the player has been still for a second the wind-up begins")
	_check(is_equal_approx(float(charge.get("_windup_left")), 0.4), "with the Lurker's 0.4 s tell")
	lurker.queue_free()
	player.queue_free()
	print("LurkerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
