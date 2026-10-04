extends Node

## EnemyActor's per-step record mirror (EnemyIndex.update_actor ->
## EnemyWorld.sync_actor_motion, FPS audit 2026-10-04 item 3) must leave the
## world and the index exactly as the reflective update_enemy ->
## sync_legacy_actor path did; only the health copy back into the actor is
## gone (EnemyCombatService mirrors health into the actor on every change).
## Each case primes two real, registered EnemyActors and their records into
## the same state, runs the old path on one and the new on the other, and
## compares every record field, the spatial answers and the profile signals.

var _passes := 0
var _failures := 0
var _profile_signals: Dictionary = {}


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_profile_changed(handle: int) -> void:
	_profile_signals[handle] = int(_profile_signals.get(handle, 0)) + 1


func _spawn(scene: PackedScene) -> EnemyActor:
	var enemy := scene.instantiate() as EnemyActor
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	add_child(enemy)
	# Registered on _ready; keep the engine and the scheduler from stepping it.
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _prime(enemy: EnemyActor, handle: int, state: Dictionary) -> void:
	var world := EnemyWorld
	world.set_position(handle, state["previous"])
	world.set_position(handle, state["record_position"])
	world.set_velocity(handle, Vector2(-1.0, -2.0))
	world.set_knockback_velocity(handle, Vector2(5.0, 5.0))
	world.set_knockback_decay(handle, 1234.0)
	world.set_stun_time(handle, 0.25)
	var flags := world.get_flags(handle)
	flags = (flags | EnemyWorldTypes.Flags.ELITE) if bool(state.get("record_elite", false)) else (flags & ~EnemyWorldTypes.Flags.ELITE)
	world.set_flags(handle, flags)
	if bool(state.get("dying", false)):
		world.set_health(handle, 0.0)
		world.try_begin_death(handle)
	enemy.global_position = state["position"]
	enemy.velocity = state["velocity"]
	enemy.knockback_vel = state["knockback"]
	enemy.knockback_decay = float(state["decay"])
	enemy.stun_time = float(state["stun"])
	enemy.is_elite = bool(state.get("elite", false))
	_profile_signals.erase(handle)


func _snapshot(enemy: EnemyActor, handle: int) -> Dictionary:
	var world := EnemyWorld
	var nearby: Array[int] = []
	world.gather_in_radius(world.get_position(handle), 0.5, nearby)
	var indexed: Array = []
	EnemyIndex.gather_in_radius(enemy.global_position, 8.0, indexed)
	return {
		"valid": world.is_valid_handle(handle),
		"position": world.get_position(handle),
		"previous": world.get_previous_position(handle),
		"velocity": world.get_velocity(handle),
		"knockback": world.get_knockback_velocity(handle),
		"decay": world.get_knockback_decay(handle),
		"stun": world.get_stun_time(handle),
		"elite_flag": EnemyWorldTypes.has_flag(world.get_flags(handle), EnemyWorldTypes.Flags.ELITE),
		"representation": world.get_representation(handle),
		"record_health": world.get_health(handle),
		"world_grid_finds_record": nearby.has(handle),
		"index_bucket_finds_actor": indexed.has(enemy),
		"profile_signals": int(_profile_signals.get(handle, 0)),
	}


func _run_case(label: String, old_enemy: EnemyActor, new_enemy: EnemyActor, state: Dictionary) -> void:
	var old_handle := EnemyWorld.handle_for_actor(old_enemy)
	var new_handle := EnemyWorld.handle_for_actor(new_enemy)
	_prime(old_enemy, old_handle, state)
	_prime(new_enemy, new_handle, state)
	EnemyIndex.update_enemy(old_enemy)
	var cached_handle := int(state.get("cached_handle", new_handle))
	EnemyIndex.update_actor(new_enemy, cached_handle, new_enemy.global_position, new_enemy.velocity, new_enemy.knockback_vel, new_enemy.knockback_decay, new_enemy.stun_time, new_enemy.is_elite)
	var old_snapshot := _snapshot(old_enemy, old_handle)
	var new_snapshot := _snapshot(new_enemy, new_handle)
	if old_snapshot != new_snapshot:
		push_error("%s\n  old %s\n  new %s" % [label, str(old_snapshot), str(new_snapshot)])
	_check(old_snapshot == new_snapshot, label)


func _run() -> void:
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	_check(scene != null, "enemy scene loads")
	if scene == null:
		_finish()
		return
	EnemyWorld.enemy_profile_changed.connect(_on_profile_changed)
	var old_enemy := _spawn(scene)
	var new_enemy := _spawn(scene)
	await get_tree().process_frame
	var old_handle := EnemyWorld.handle_for_actor(old_enemy)
	var new_handle := EnemyWorld.handle_for_actor(new_enemy)
	_check(old_handle != 0 and new_handle != 0, "both actors own world records")
	_check(int(new_enemy.get("_enemy_world_handle")) == new_handle, "the actor caches its bound world handle")

	var base := {
		"previous": Vector2(90.0, 40.0), "record_position": Vector2(100.0, 40.0),
		"position": Vector2(110.0, 44.0), "velocity": Vector2(30.0, -12.0),
		"knockback": Vector2(-4.0, 9.0), "decay": 2200.0, "stun": 0.0,
	}
	_run_case("a step inside one cell leaves identical records", old_enemy, new_enemy, base)
	var crossing := base.duplicate()
	crossing["position"] = Vector2(1000.0, -650.0)
	_run_case("a step across cells moves the world grid and the index bucket the same", old_enemy, new_enemy, crossing)
	var promoted := base.duplicate()
	promoted["elite"] = true
	_run_case("an elite promotion sets the flag and announces the profile once", old_enemy, new_enemy, promoted)
	var unchanged_elite := promoted.duplicate()
	unchanged_elite["record_elite"] = true
	_run_case("an unchanged elite flag announces nothing", old_enemy, new_enemy, unchanged_elite)
	var cleared := base.duplicate()
	cleared["record_elite"] = true
	_run_case("a cleared elite flag is cleared and announced", old_enemy, new_enemy, cleared)
	var clamped := base.duplicate()
	clamped["decay"] = -50.0
	clamped["stun"] = -1.0
	clamped["knockback"] = Vector2(300.0, 0.0)
	_run_case("negative decay and stun clamp to zero the same way", old_enemy, new_enemy, clamped)
	var stunned := base.duplicate()
	stunned["stun"] = 1.75
	_run_case("a stunned actor's stun clock mirrors identically", old_enemy, new_enemy, stunned)
	var stale := base.duplicate()
	stale["cached_handle"] = new_handle ^ (1 << 40)
	_run_case("a stale cached handle falls back to the reflective sync", old_enemy, new_enemy, stale)
	var unbound := base.duplicate()
	unbound["cached_handle"] = old_handle
	_run_case("another actor's handle is refused and the reflective sync runs", old_enemy, new_enemy, unbound)

	# Dying records: position, velocity and decay still mirror, knockback and
	# stun do not, the representation stays DYING. A death cannot be undone,
	# so this case runs last on a fresh pair.
	var dying_old := _spawn(scene)
	var dying_new := _spawn(scene)
	await get_tree().process_frame
	var dying := base.duplicate()
	dying["dying"] = true
	dying["stun"] = 2.0
	dying["knockback"] = Vector2(77.0, 0.0)
	_run_case("a dying record keeps its knockback, stun and DYING state on both paths", dying_old, dying_new, dying)

	# Not indexed (detached or unregistered): neither path touches the record.
	var loose_old := _spawn(scene)
	var loose_new := _spawn(scene)
	await get_tree().process_frame
	var loose_old_handle := EnemyWorld.handle_for_actor(loose_old)
	var loose_new_handle := EnemyWorld.handle_for_actor(loose_new)
	EnemyWorld.set_position(loose_old_handle, Vector2(5.0, 5.0))
	EnemyWorld.set_position(loose_new_handle, Vector2(5.0, 5.0))
	var cached := int(loose_new.get("_enemy_world_handle"))
	EnemyIndex.call("_remove_materialized_storage", loose_old, loose_old.get_instance_id())
	EnemyIndex.call("_remove_materialized_storage", loose_new, loose_new.get_instance_id())
	loose_old.global_position = Vector2(400.0, 400.0)
	loose_new.global_position = Vector2(400.0, 400.0)
	EnemyIndex.update_enemy(loose_old)
	EnemyIndex.update_actor(loose_new, cached, loose_new.global_position, loose_new.velocity, loose_new.knockback_vel, loose_new.knockback_decay, loose_new.stun_time, loose_new.is_elite)
	_check(
		EnemyWorld.get_position(loose_old_handle) == Vector2(5.0, 5.0) and EnemyWorld.get_position(loose_new_handle) == Vector2(5.0, 5.0),
		"an actor the index no longer holds is not mirrored by either path"
	)

	# Health: the old path copied the record back into the actor every step;
	# combat already does it on every change, which is what keeps them equal.
	var record_health := EnemyWorld.get_health(new_handle)
	new_enemy.process_mode = Node.PROCESS_MODE_INHERIT
	EnemyCombat.apply_damage(new_handle, 1.0, 1, null)
	_check(is_equal_approx(new_enemy.hp, record_health - 1.0) and is_equal_approx(EnemyWorld.get_health(new_handle), new_enemy.hp), "combat damage still mirrors health into the actor")
	new_enemy.process_mode = Node.PROCESS_MODE_DISABLED

	# Cost per call on a live, registered actor (same process, same state).
	var iterations := 3000
	var started := Time.get_ticks_usec()
	for i in range(iterations):
		old_enemy.global_position = Vector2(100.0 + float(i % 7), 40.0)
		EnemyIndex.update_enemy(old_enemy)
	var old_usec := float(Time.get_ticks_usec() - started) / float(iterations)
	started = Time.get_ticks_usec()
	for i in range(iterations):
		new_enemy.global_position = Vector2(100.0 + float(i % 7), 40.0)
		new_enemy.call("_update_enemy_index", true)
	var new_usec := float(Time.get_ticks_usec() - started) / float(iterations)
	print("EnemyWorldSyncFastPathTest: per-step index update %.2f us (reflective) vs %.2f us (fast path, via the actor's own call)" % [old_usec, new_usec])
	_check(new_usec < old_usec, "the fast path is cheaper than the reflective sync")

	for enemy in [old_enemy, new_enemy, dying_old, dying_new, loose_old, loose_new]:
		(enemy as Node).queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("EnemyWorldSyncFastPathTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
