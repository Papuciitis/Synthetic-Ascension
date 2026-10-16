extends Node

const BULLDOZER := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const GRUNT := preload("res://scenes/world/enemies/EnemyGrunt.tscn")
const RUNNER := preload("res://scenes/world/enemies/EnemyRunner.tscn")
const Scope := preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning := preload("res://scenes/world/bosses/BossGroundWarning.gd")

var _passes := 0
var _failures := 0
var _kills := 0
var _defeats := 0
var _wallet_grants := 0
var _player: Node2D
var _shock_boss: EnemyActor
var _capture_shock := false
var _release_positions: Array[Vector2] = []
var _release_radii: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	# Isolate every state writer before real EnemyActor readiness can emit events.
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_encounter_ownership_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	RunEvents.enemy_killed.connect(_on_killed)
	RunEvents.enemy_defeated.connect(_on_defeated)
	Global.followers_transaction.connect(_on_wallet_transaction)
	child_entered_tree.connect(_on_child_entered)
	_player = Node2D.new()
	_player.name = "OwnershipTestPlayer"
	_player.add_to_group(&"player")
	_player.position = Vector2(2200, 1500)
	add_child(_player)
	await _test_shockwave_commitment()
	await _test_runner_cleanup(&"death")
	await _test_runner_cleanup(&"return")
	_player.queue_free()
	await get_tree().process_frame
	RunEvents.enemy_killed.disconnect(_on_killed)
	RunEvents.enemy_defeated.disconnect(_on_defeated)
	Global.followers_transaction.disconnect(_on_wallet_transaction)
	child_entered_tree.disconnect(_on_child_entered)
	print("BossEncounterOwnershipTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _spawn_actor(scene: PackedScene, at: Vector2) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.position = at
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	var brain := actor.get_node_or_null("BossBrain")
	if brain != null:
		brain.set_process(false)
		brain.set_physics_process(false)
	return actor


func _scope_of(node: Node) -> Node:
	if not node.has_meta(Scope.SCOPE_META):
		return null
	var reference := node.get_meta(Scope.SCOPE_META) as WeakRef
	return reference.get_ref() as Node if reference != null else null


func _warnings_for(scope: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in get_children():
		if child is Node2D and child.get_script() == GroundWarning and _scope_of(child) == scope:
			result.append(child)
	return result


func _warnings_match(markers: Array[Node2D], expected: Array[Vector2]) -> bool:
	if markers.size() != expected.size():
		return false
	for i in range(markers.size()):
		if not is_instance_valid(markers[i]) or markers[i].is_queued_for_deletion():
			return false
		if not markers[i].global_position.is_equal_approx(expected[i]):
			return false
	return true


func _test_shockwave_commitment() -> void:
	var origin := Vector2(1600, 1200)
	var direction := Vector2(0.6, 0.8)
	_player.global_position = origin + direction * 400.0
	_shock_boss = _spawn_actor(BULLDOZER, origin)
	var brain := _shock_boss.get_node("BossBrain")
	var scope := _scope_of(_shock_boss)
	var spacing := float(brain.get("shockwave_spacing"))
	var radius := float(brain.get("shockwave_radius"))
	var expected: Array[Vector2] = []
	for i in range(3):
		expected.append(origin + direction * spacing * float(i + 1))
	_release_positions.clear()
	_release_radii.clear()
	_capture_shock = true
	brain.call("_do_shockwave")
	var markers := _warnings_for(scope)
	_check(markers.size() == 3, "a real Bulldozer shockwave previews all three impacts before releasing damage")
	_check(_warnings_match(markers, expected), "all shockwave previews use the captured origin, direction and authored spacing")
	var matching_radii := markers.size() == 3
	for marker: Node2D in markers:
		matching_radii = matching_radii and is_equal_approx(float(marker.get("_radius")), radius)
	_check(matching_radii, "each preview uses the shockwave's authored damage radius")
	brain.set_process(true)
	brain.set_physics_process(true)
	await get_tree().create_timer(0.05, true).timeout
	get_tree().paused = true
	await get_tree().create_timer(1.05, true).timeout
	_check(_release_positions.is_empty(), "pausing longer than the whole shock sequence releases no impacts")
	_check(_warnings_match(markers, expected), "pause preserves all three previews at their original positions")
	# Move both participants before the first release; later moves happen in the
	# actual hazard ready callback, even if two releases share a slow frame.
	_shock_boss.global_position = origin + Vector2(110, -80)
	_player.global_position = origin + Vector2(-440, 100)
	get_tree().paused = false
	await get_tree().create_timer(0.10, true).timeout
	_check(_release_positions.is_empty(), "resuming retains the shockwave's unspent anticipation")
	_check(_warnings_match(markers, expected), "moving boss and player cannot drag committed shockwave previews")
	await get_tree().create_timer(float(brain.call("_shock_time", 2)) + 0.95, true).timeout
	_check(_release_positions.size() == 3, "the resumed shockwave releases exactly three impacts")
	for i in range(3):
		var matching_position := i < _release_positions.size() and _release_positions[i].is_equal_approx(expected[i])
		var matching_radius := i < _release_radii.size() and is_equal_approx(_release_radii[i], radius)
		_check(matching_position and matching_radius, "shockwave impact %d matches its fixed preview despite intervening movement" % (i + 1))
	_check(not bool(_shock_boss.get_meta(&"boss_cast_locked", false)), "the completed sequence releases its movement lock")
	_check(_warnings_for(scope).is_empty(), "completed shockwave previews leave no lingering warnings")
	_capture_shock = false
	_shock_boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_shock_boss = null


func _on_child_entered(child: Node) -> void:
	if not _capture_shock or not (child is DamageCircle):
		return
	var circle := child as DamageCircle
	if circle.source != _shock_boss:
		return
	if circle.is_node_ready():
		_on_shock_circle_ready(circle)
	else:
		circle.ready.connect(_on_shock_circle_ready.bind(circle), CONNECT_ONE_SHOT)


func _on_shock_circle_ready(circle: DamageCircle) -> void:
	_release_positions.append(circle.global_position)
	_release_radii.append(circle.radius)
	# The next impact must keep its original geometry after these real moves.
	_shock_boss.global_position += Vector2(170, -95)
	_player.global_position += Vector2(-190, 230)


func _boss_add_count() -> int:
	var counters := EnemyIndex.get_debug_counters()
	var by_kind: Dictionary = counters.get("special_by_kind", {})
	return int(by_kind.get(&"boss_add", 0))


func _runners_for(scope: Node) -> Array[EnemyActor]:
	var result: Array[EnemyActor] = []
	for child in get_children():
		if child is EnemyActor and child.scene_file_path == RUNNER.resource_path and _scope_of(child) == scope:
			result.append(child)
	return result


func _test_runner_cleanup(reason: StringName) -> void:
	_player.global_position = Vector2(2200, 1500)
	var boss := _spawn_actor(BULLDOZER, Vector2(1800, 1500))
	var unrelated := _spawn_actor(GRUNT, Vector2(2600, 1500))
	var unrelated_handle := EnemyCombat.handle_for_actor(unrelated)
	var unrelated_hp := unrelated.hp
	var scope := _scope_of(boss)
	var before_adds := _boss_add_count()
	var before_reserved := int(EnemyIndex.get_debug_counters().get("reserved", 0))
	boss.hp = boss.max_hp * 0.49
	var brain := boss.get_node("BossBrain")
	brain.call("_summon_blockers")
	brain.call("_tick_cast", 1.01)
	var runners := _runners_for(scope)
	_check(runners.size() == 3, "%s cleanup fixture creates three real scope-bound Runners" % reason)
	var runner_refs: Array[WeakRef] = []
	var runner_handles: Array[int] = []
	var all_owned := scope != null and runners.size() == 3
	for runner: EnemyActor in runners:
		runner_refs.append(weakref(runner))
		runner_handles.append(EnemyCombat.handle_for_actor(runner))
		all_owned = all_owned and Scope.is_valid_attack(runner) and runner.get_meta(&"special_spawn_kind", &"") == &"boss_add"
		runner.set_physics_process(false)
		runner.set_process(false)
	_check(all_owned, "all %s Runners belong to the encounter and use the boss-add budget" % reason)
	_check(_boss_add_count() == before_adds + 3, "%s summons consume exactly three live boss-add slots" % reason)
	_check(int(EnemyIndex.get_debug_counters().get("reserved", 0)) == before_reserved, "%s summons leave no outstanding population reservations" % reason)
	var before_kills := _kills
	var before_defeats := _defeats
	var before_grants := _wallet_grants
	var before_wallet := Global.followers
	if reason == &"death":
		boss.dead = true
	else:
		boss.set_meta(&"boss_returning", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var all_removed := runner_refs.size() == 3
	for reference: WeakRef in runner_refs:
		all_removed = all_removed and not is_instance_valid(reference.get_ref())
	_check(all_removed, "owner %s removes every summoned Runner" % reason)
	var all_unregistered := runner_handles.size() == 3
	for handle: int in runner_handles:
		all_unregistered = all_unregistered and handle != 0 and not EnemyWorld.is_valid_handle(handle)
	_check(all_unregistered, "owner %s removes Runner handles from EnemyWorld" % reason)
	_check(_boss_add_count() == before_adds, "owner %s releases every occupied boss-add slot" % reason)
	_check(int(EnemyIndex.get_debug_counters().get("reserved", 0)) == before_reserved, "owner %s leaves no leaked population reservations" % reason)
	_check(_kills == before_kills and _defeats == before_defeats, "owner %s cleanup emits no Runner kill or defeat rewards" % reason)
	_check(_wallet_grants == before_grants and Global.followers == before_wallet, "owner %s cleanup grants no Followers" % reason)
	_check(is_instance_valid(unrelated) and not unrelated.dead and unrelated.hp == unrelated_hp and EnemyWorld.is_valid_handle(unrelated_handle), "owner %s preserves the unrelated Grunt and its combat registration" % reason)
	for reference: WeakRef in runner_refs:
		var remaining = reference.get_ref()
		if is_instance_valid(remaining):
			remaining.queue_free()
	boss.queue_free()
	unrelated.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _on_killed(_who: Node, _enemy: Node, _at: Vector2) -> void:
	_kills += 1


func _on_defeated(_context: RefCounted) -> void:
	_defeats += 1


func _on_wallet_transaction(_old: int, change: int, _new: int, _reason: StringName, _context: Dictionary, _show_feedback: bool, _allow_aggregate: bool) -> void:
	if change > 0:
		_wallet_grants += 1
