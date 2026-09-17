extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const BossPylonScene = preload("res://scenes/world/bosses/BossPylon.tscn")
const OpeningActorScene = preload("res://core/systems/world/opening/OpeningActor.tscn")

var _passes := 0
var _failures := 0
var _defeated_contexts: Array[RefCounted] = []
var _legacy_kills := 0


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
	_defeated_contexts.append(context)


func _on_enemy_killed(_player: Node, _enemy: Node, _position: Vector2) -> void:
	_legacy_kills += 1


func _run() -> void:
	RunEvents.enemy_defeated.connect(_on_enemy_defeated)
	RunEvents.enemy_killed.connect(_on_enemy_killed)
	var source := Node.new()
	add_child(source)

	var pylon := BossPylonScene.instantiate() as BossPylon
	pylon.max_hp = 10.0
	pylon.shoot_every = 9999.0
	pylon.projectile_scene = null
	add_child(pylon)
	var pylon_handle := EnemyCombat.handle_for_actor(pylon)
	_check(pylon_handle != Types.INVALID_HANDLE, "BossPylon registers in the authoritative world")
	if pylon_handle != Types.INVALID_HANDLE:
		var flags := EnemyWorld.get_flags(pylon_handle)
		_check(Types.has_flag(flags, Types.Flags.CRITICAL), "BossPylon is permanently critical")
		_check(Types.has_flag(flags, Types.Flags.OBJECTIVE), "BossPylon preserves objective responsibility")
		_check(Types.has_flag(flags, Types.Flags.NEVER_RETIRE), "BossPylon cannot be retired into a proxy")
		_check(EnemyCombat.apply_damage(pylon_handle, 20.0, 1, source) == 10.0, "handle damage delegates to BossPylon's Node-owned lifecycle")
		_check(_defeated_contexts.size() == 1 and _legacy_kills == 1, "BossPylon emits each legacy death event exactly once")
		if not _defeated_contexts.is_empty():
			_check(int(_defeated_contexts[0].get("handle")) == pylon_handle, "BossPylon death context preserves its stable handle")
		_check(not EnemyWorld.is_valid_handle(pylon_handle), "BossPylon unregister removes its authoritative shadow")
		_check(EnemyCombat.apply_damage(pylon_handle, 5.0, 1, source) == 0.0 and _defeated_contexts.size() == 1, "stale BossPylon damage cannot repeat death")

	var opening := OpeningActorScene.instantiate() as OpeningActor
	opening.max_hp = 10.0
	opening.role = &"construct"
	opening.hostile = true
	var opening_defeats := [0]
	opening.defeated.connect(func(_actor: OpeningActor, _source: Node) -> void: opening_defeats[0] += 1)
	add_child(opening)
	var opening_handle := EnemyCombat.handle_for_actor(opening)
	_check(opening_handle != Types.INVALID_HANDLE, "OpeningActor registers in the authoritative world")
	if opening_handle != Types.INVALID_HANDLE:
		var flags := EnemyWorld.get_flags(opening_handle)
		_check(Types.has_flag(flags, Types.Flags.CRITICAL), "OpeningActor is permanently critical")
		_check(Types.has_flag(flags, Types.Flags.TUTORIAL), "OpeningActor preserves tutorial responsibility")
		_check(Types.has_flag(flags, Types.Flags.NEVER_RETIRE), "OpeningActor cannot be retired into a proxy")
		_check(EnemyCombat.apply_damage(opening_handle, 20.0, 1, source) == 10.0, "handle damage delegates to OpeningActor's scripted lifecycle")
		_check(opening_defeats[0] == 1 and opening.dead, "OpeningActor defeat signal fires exactly once")
		_check(not EnemyWorld.is_valid_handle(opening_handle), "OpeningActor unregister removes its authoritative shadow")
		_check(EnemyCombat.apply_damage(opening_handle, 5.0, 1, source) == 0.0 and opening_defeats[0] == 1, "stale OpeningActor damage cannot repeat defeat")

	if is_instance_valid(pylon):
		pylon.queue_free()
	if is_instance_valid(opening):
		opening.queue_free()
	source.queue_free()
	await get_tree().process_frame
	if RunEvents.enemy_defeated.is_connected(_on_enemy_defeated):
		RunEvents.enemy_defeated.disconnect(_on_enemy_defeated)
	if RunEvents.enemy_killed.is_connected(_on_enemy_killed):
		RunEvents.enemy_killed.disconnect(_on_enemy_killed)
	print("EnemyLegacyCombatCompatibilityTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
