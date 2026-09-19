extends Node

# Segment 1 pass S5: the two authored punctuations (a three-charger wedge
# after the security clear, a close sniper pair at the checkpoint) exist in
# the catalog, are sized for the tutorial, and place through the director.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/SegmentOneBeatsTest.tscn

const DIRECTOR := preload("res://core/systems/encounters/EncounterDirector.gd")
const BEATS := preload("res://core/systems/encounters/EncounterBeats.gd")

var _passes := 0
var _failures := 0


class FakeSpawner extends Node:
	var members: Array[Node] = []
	var elites := 0

	func spawn_beat_member(_scene: String, pos: Vector2, elite: bool) -> Node:
		var node := Node2D.new()
		node.global_position = pos
		add_child(node)
		members.append(node)
		if elite:
			elites += 1
		return node


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
	var wedge: Dictionary = BEATS.find(&"charger_wedge_small")
	var pair: Dictionary = BEATS.find(&"sniper_pair")
	_check(not wedge.is_empty() and (wedge["members"] as Array).size() == 3 and wedge["min_phase"] == &"disturbance", "the small wedge is three chargers from disturbance")
	var no_elite := true
	for member in wedge["members"]:
		if bool((member as Dictionary).get("elite", false)):
			no_elite = false
	_check(no_elite, "and none of them is an elite (segment 1 has no elite layer yet)")
	_check(not pair.is_empty() and (pair["members"] as Array).size() == 2 and float(pair["distance"]) < 700.0, "the sniper pair is two snipers within 700 px, not the 1,400 px crossfire")
	var spawner := FakeSpawner.new()
	add_child(spawner)
	var player := Node2D.new()
	add_child(player)
	var director := DIRECTOR.new()
	add_child(director)
	director.enabled = false
	director.setup(spawner, player, 77)
	director.phase_provider = func() -> StringName: return &"disturbance"
	var placed: Dictionary = director.try_spawn_beat(&"charger_wedge_small")
	_check(not placed.is_empty() and spawner.members.size() == 3 and spawner.elites == 0, "the director places the wedge on request (%d members)" % spawner.members.size())
	var placed_pair: Dictionary = director.try_spawn_beat(&"sniper_pair")
	_check(not placed_pair.is_empty() and spawner.members.size() == 5, "and the sniper pair after it (%d members)" % spawner.members.size())
	var far := 0.0
	for member in spawner.members.slice(3):
		far = maxf(far, (member as Node2D).global_position.distance_to(player.global_position))
	_check(far < 700.0, "both snipers stand within 700 px of the player (%.0f)" % far)
	print("SegmentOneBeatsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
