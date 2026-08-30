extends Node

# Roadmap §8.1 / Phase 2.7: ritual interference - a local rule change while
# the district collapses. The rule here is "the dead rise": a kill inside the
# sigil stands back up once, weakened, after a delay; kills outside stay down,
# revenants stay down, the cap holds, and expiry wipes the ring and stops
# listening. Fake spawner + synthetic death contexts; which rule the player
# remembers is the playtest's call.
#
# Run: <godot> --headless --path . res://tools/tests/RitualInterferenceTest.tscn

const RitualScript = preload("res://core/systems/world/RitualInterference.gd")
const DeathContextScript = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
const GRUNT := "res://scenes/world/enemies/EnemyGrunt.tscn"
const RUNNER := "res://scenes/world/enemies/EnemyRunner.tscn"

class FakeEnemy:
	extends Node2D
	var max_hp := 100.0
	var health_calls: Array = []

	func _init() -> void:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	func configure_health(new_max: float, fill: bool) -> bool:
		health_calls.append([new_max, fill])
		max_hp = new_max
		return true

class FakeSpawner:
	extends Node
	var calls: Array[Dictionary] = []
	var members: Array[Node] = []
	var refuse := false

	func spawn_beat_member(scene_path: String, pos: Vector2, elite: bool) -> Node:
		if refuse:
			return null
		calls.append({"scene": scene_path, "pos": pos, "elite": elite})
		var node := FakeEnemy.new()
		node.position = pos
		add_child(node)
		members.append(node)
		return node

var _passes := 0
var _failures := 0
var _actors: Dictionary = {}
var _tips: Array[String] = []
var _expired_signals := 0
var _spawner: FakeSpawner = null


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _corpse(handle: int, scene_path: String = GRUNT, revenant: bool = false) -> Node2D:
	var actor := Node2D.new()
	actor.scene_file_path = scene_path
	if revenant:
		actor.set_meta(RitualScript.REVENANT_META, true)
	add_child(actor)
	_actors[handle] = actor
	return actor


func _kill(handle: int, pos: Vector2) -> void:
	RunEvents.enemy_defeated.emit(DeathContextScript.new(handle, &"enemy_grunt", pos, 0, null, {}))


func _make(max_revenants: int = 8, teach: bool = false) -> Node2D:
	var ritual := RitualScript.new()
	ritual.radius = 300.0
	ritual.duration = 20.0
	ritual.revive_delay = 2.0
	ritual.revenant_hp_fraction = 0.35
	ritual.max_revenants = max_revenants
	ritual.position = Vector2(1000.0, 1000.0)
	ritual.actor_provider = func(handle: int) -> Node: return _actors.get(handle)
	add_child(ritual)
	# Driven by hand: the engine's own frames must not drain the timers.
	ritual.set_process(false)
	ritual.setup(_spawner, teach)
	ritual.expired.connect(func(_r: Node) -> void: _expired_signals += 1)
	return ritual


func _run() -> void:
	_spawner = FakeSpawner.new()
	add_child(_spawner)
	RunEvents.tutorial_tip.connect(func(text: String, _d: float) -> void: _tips.append(text))

	# --- the rule: a kill inside the sigil rises once, after the delay ---
	var ritual := _make(8, true)
	_check(_tips.size() == 1 and _tips[0].contains("sigil"), "the first ritual of a run teaches the rule (%s)" % [_tips])
	_check(RunEvents.enemy_defeated.is_connected(Callable(ritual, "_on_enemy_defeated")), "a live ritual listens for defeats")
	_corpse(1)
	_kill(1, Vector2(1100.0, 1000.0))
	_check(ritual.pending() == 1 and _spawner.calls.is_empty(), "a kill inside the radius is a pending rise, not an instant spawn")
	ritual._process(1.0)
	_check(_spawner.calls.is_empty(), "nothing rises before revive_delay")
	ritual._process(1.5)
	_check(_spawner.calls.size() == 1 and ritual.pending() == 0 and ritual.raised() == 1, "exactly one revenant rises after the delay (%d)" % _spawner.calls.size())
	if _spawner.calls.size() == 1:
		var call: Dictionary = _spawner.calls[0]
		_check(String(call["scene"]) == GRUNT and (call["pos"] as Vector2) == Vector2(1100.0, 1000.0) and not bool(call["elite"]), "the revenant is the same archetype at the death position, not elite")
	await get_tree().process_frame
	if _spawner.members.size() == 1:
		var member := _spawner.members[0] as FakeEnemy
		_check(member.health_calls.size() == 1 and is_equal_approx(float(member.health_calls[0][0]), 35.0) and bool(member.health_calls[0][1]), "the revenant is configured to revenant_hp_fraction of its max, filled (%s)" % [member.health_calls])
		_check((member.get_node("Sprite2D") as CanvasItem).modulate == ritual.revenant_tint, "the revenant wears the ritual tint")
		_check(member.has_meta(RitualScript.REVENANT_META), "the revenant is flagged so it never rises again")
	ritual._process(5.0)
	_check(_spawner.calls.size() == 1, "a rise happens once per corpse")

	# --- outside the radius, revenants, and bodies with no actor stay down ---
	_corpse(2)
	_kill(2, Vector2(1400.0, 1000.0))
	_check(ritual.pending() == 0, "a kill outside the radius does not rise")
	_corpse(3, GRUNT, true)
	_kill(3, Vector2(1050.0, 1000.0))
	_check(ritual.pending() == 0, "a revenant's own death does not rise")
	_kill(99, Vector2(1050.0, 1000.0))
	_check(ritual.pending() == 0, "a defeat with no actor (data-only proxy) does not rise")
	ritual._process(5.0)
	_check(_spawner.calls.size() == 1, "none of them spawned anything")

	# --- the cap counts corpses still waiting ---
	var capped := _make(2)
	for handle in range(10, 15):
		_corpse(handle, RUNNER)
		_kill(handle, Vector2(1000.0, 1050.0))
	_check(capped.pending() == 2, "max_revenants caps pending rises (%d)" % capped.pending())
	_spawner.calls.clear()
	capped._process(2.5)
	_check(_spawner.calls.size() == 2 and capped.raised() == 2, "...and the cap holds through the rises (%d)" % _spawner.calls.size())
	_corpse(15, RUNNER)
	_kill(15, Vector2(1000.0, 1050.0))
	_check(capped.pending() == 0, "a full ritual raises nothing more")
	_spawner.refuse = true
	var refused := _make(8)
	_corpse(20)
	_kill(20, Vector2(1000.0, 1000.0))
	refused._process(2.5)
	_check(refused.raised() == 0 and refused.pending() == 0, "a spawner refusal leaves the corpse down without counting a rise")
	_spawner.refuse = false
	_check(_tips.size() == 1, "later rituals do not teach again (%d tips)" % _tips.size())

	# --- expiry: the ring wipes, the listener goes, the node leaves ---
	ritual._process(20.0)
	_check(ritual.is_expired() and _expired_signals == 1, "the ritual expires after duration and signals it")
	_check(not RunEvents.enemy_defeated.is_connected(Callable(ritual, "_on_enemy_defeated")), "an expired ritual stops listening")
	_corpse(30)
	_kill(30, Vector2(1000.0, 1000.0))
	_check(ritual.pending() == 0, "a kill after expiry does not rise")
	ritual._process(5.0)
	_spawner.calls.clear()
	var aborted := _make(8)
	aborted.despawn(&"beat_aborted")
	_check(aborted.is_expired() and _expired_signals == 2, "the director's despawn ends a ritual the same way")
	await get_tree().process_frame
	_check(not is_instance_valid(ritual) and not is_instance_valid(aborted), "expired rituals leave the tree")
	_check(get_tree().get_nodes_in_group(&"ritual_interference").size() == 2, "the live rituals remain (%d)" % get_tree().get_nodes_in_group(&"ritual_interference").size())

	# --- reduced motion: the ring is static, read from the accessibility setting ---
	var previous: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var still := _make(8)
	_check(bool(still.get("_reduced_motion")), "a ritual under reduced_motion draws a static ring")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", bool(previous), false)
	_check(not bool(_make(8).get("_reduced_motion")), "...and pulses otherwise")

	for node in get_tree().get_nodes_in_group(&"ritual_interference"):
		node.call("expire")
	await get_tree().process_frame
	print("RitualInterferenceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
