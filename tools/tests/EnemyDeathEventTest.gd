extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const CombatScript = preload("res://core/systems/enemy_world/EnemyCombatService.gd")

var _passes := 0
var _failures := 0
var _contexts: Array[RefCounted] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_enemy_defeated(context: RefCounted) -> void:
	_contexts.append(context)


func _run() -> void:
	var callback := Callable(self, "_on_enemy_defeated")
	_check(RunEvents.has_signal("enemy_defeated"), "run event bus exposes future-proof enemy defeat event")
	if not RunEvents.has_signal("enemy_defeated"):
		_finish()
		return
	RunEvents.connect("enemy_defeated", callback)

	var world := WorldScript.new()
	add_child(world)
	var combat := CombatScript.new()
	combat.setup(world)
	add_child(combat)
	var source := Node.new()
	add_child(source)
	var state := SpawnState.new(
		&"event_elite",
		"res://event_elite.tscn",
		Vector2(44.0, 55.0),
		25.0,
		100.0,
		20.0,
		0,
		Types.Flags.ELITE,
		{"opening_scripted": true},
	)
	var handle := world.create_enemy(state)
	combat.apply_damage(handle, 25.0, 1, source)
	_check(_contexts.size() == 1, "successful death transition emits one generic event")
	if _contexts.size() == 1:
		var context := _contexts[0]
		_check(int(context.get("handle")) == handle, "event context preserves handle")
		_check(context.get("spec_id") == &"event_elite", "event context preserves spec id")
		_check(context.get("position") == Vector2(44.0, 55.0), "event context preserves death position")
		_check(bool(context.get("is_elite")), "event context preserves elite state")
		_check(context.get("source") == source, "event context preserves valid source")
		var metadata := context.get("metadata") as Dictionary
		_check(bool(metadata.get("opening_scripted", false)), "event context snapshots progression metadata")
	combat.apply_damage(handle, 25.0, 1, source)
	_check(_contexts.size() == 1, "repeated lethal damage cannot duplicate generic event")
	world.remove_enemy(handle, &"event_test")
	var replacement := world.create_enemy(SpawnState.new(&"replacement", "res://replacement.tscn", Vector2.ZERO, 10.0, 10.0, 4.0, 0))
	combat.apply_damage(handle, 100.0, 1, source)
	_check(_contexts.size() == 1 and world.get_health(replacement) == 10.0, "stale death handle cannot emit or affect replacement")

	if RunEvents.is_connected("enemy_defeated", callback):
		RunEvents.disconnect("enemy_defeated", callback)
	_finish()


func _finish() -> void:
	print("EnemyDeathEventTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)

