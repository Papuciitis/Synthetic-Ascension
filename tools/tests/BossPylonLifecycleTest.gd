extends Node

const PYLON := preload("res://scenes/world/bosses/BossPylon.tscn")
const ScopeScript := preload("res://scenes/world/bosses/BossAttackScope.gd")

class TestBoss extends Node2D:
	var dead := false
	var stun_time := 0.0

class ErrorCapture extends Logger:
	var errors := PackedStringArray()
	var mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append(rationale if not rationale.is_empty() else code)
		mutex.unlock()

var _passes := 0
var _failures := 0
var _defeats := 0
var _kills := 0
var _player: Node2D


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
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_pylon_lifecycle_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	RunEvents.enemy_defeated.connect(_on_defeated)
	RunEvents.enemy_killed.connect(_on_killed)
	_player = Node2D.new()
	_player.add_to_group(&"player")
	_player.position = Vector2(1200, 700)
	add_child(_player)
	await _test_legacy_and_body()
	await _test_setup_and_lifetime()
	await _test_firing_and_scope()
	await _test_detached_scope_cleanup()
	await _test_destroyed()
	_player.queue_free()
	await get_tree().process_frame
	RunEvents.enemy_defeated.disconnect(_on_defeated)
	RunEvents.enemy_killed.disconnect(_on_killed)
	print("BossPylonLifecycleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _on_defeated(context: RefCounted) -> void:
	if context.get("spec_id") == &"boss_pylon":
		_defeats += 1


func _on_killed(_who: Node, enemy: Node, _at: Vector2) -> void:
	if enemy is BossPylon:
		_kills += 1


func _new_owner() -> Dictionary:
	var boss := TestBoss.new()
	add_child(boss)
	var scope: Node = ScopeScript.new()
	boss.add_child(scope)
	scope.call("setup", boss)
	return {"boss": boss, "scope": scope}


func _configured(at: Vector2, source: Node, life: float, parent_node: Node = null) -> BossPylon:
	var pylon := PYLON.instantiate() as BossPylon
	var has_setup := pylon.has_method("setup")
	_check(has_setup, "pylons support setup before entering the world")
	if has_setup:
		pylon.call("setup", at, source, life)
	else:
		pylon.position = at
	pylon.shoot_every = 0.15
	(parent_node if parent_node != null else self).add_child(pylon)
	pylon.set_process(false)
	return pylon


func _test_legacy_and_body() -> void:
	var pylon := PYLON.instantiate() as BossPylon
	pylon.position = Vector2(430, 270)
	pylon.projectile_scene = null
	add_child(pylon)
	pylon.set_process(false)
	var handle := EnemyCombat.handle_for_actor(pylon)
	_check(handle != 0, "legacy standalone pylons still register")
	_check(EnemyWorld.get_position(handle).is_equal_approx(Vector2(430, 270)), "legacy registration uses its placed non-origin position")
	var body := pylon.get_node_or_null("Body") as Sprite2D
	_check(body != null and body.texture != null and body.visible, "a pylon has a visible textured body")
	var shadow := pylon.get_node_or_null("Shadow") as Sprite2D
	_check(_is_png_sprite(shadow) and shadow.visible, "the pylon ground shadow uses a real PNG sprite")
	_check(not _has_procedural_effect_nodes(pylon), "pylon art effects contain no line or particle nodes")
	if body != null and body.texture != null:
		var drawn := body.texture.get_size() * body.scale.abs()
		_check(drawn.y >= 36.0 and drawn.y <= 72.0, "the target reads at gameplay size without becoming a boss-sized landmark")
	pylon.queue_free()
	await get_tree().process_frame
	_check(not EnemyWorld.is_valid_handle(handle), "standalone teardown unregisters immediately")


func _test_setup_and_lifetime() -> void:
	var owner := _new_owner()
	var before_defeats := _defeats
	var before_kills := _kills
	var container := Node2D.new()
	container.position = Vector2(-140, 220)
	add_child(container)
	var pylon := _configured(Vector2(650, 390), owner["boss"], 0.1, container)
	var handle := EnemyCombat.handle_for_actor(pylon)
	_check(EnemyWorld.get_position(handle).is_equal_approx(Vector2(650, 390)), "setup position reaches EnemyWorld on the registration frame")
	_check(pylon.has_method("cancel_attack"), "encounter cancellation has an explicit non-reward cleanup path")
	pylon.call("_process", 0.11)
	_check(not EnemyWorld.is_valid_handle(handle), "an expired pylon unregisters before deferred deletion")
	await get_tree().process_frame
	_check(not is_instance_valid(pylon), "a pylon cannot remain indefinitely after its configured life")
	_check(_defeats == before_defeats and _kills == before_kills, "expiry produces neither defeat nor kill rewards")
	if is_instance_valid(pylon):
		pylon.queue_free()
	container.queue_free()
	(owner["boss"] as Node).queue_free()
	await get_tree().process_frame


func _shots_from(pylon: BossPylon) -> Array[Node]:
	var result: Array[Node] = []
	for shot: Node in get_tree().get_nodes_in_group(&"enemy_projectile"):
		if shot.get("shooter") == pylon:
			result.append(shot)
	return result


func _is_png_sprite(sprite: Sprite2D) -> bool:
	return sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with(".png")


func _has_procedural_effect_nodes(node: Node) -> bool:
	if node is Line2D or node is GPUParticles2D or node is CPUParticles2D:
		return true
	for child in node.get_children():
		if _has_procedural_effect_nodes(child):
			return true
	return false


func _test_firing_and_scope() -> void:
	var owner := _new_owner()
	var pylon := _configured(Vector2(620, 350), owner["boss"], 12.0)
	var handle := EnemyCombat.handle_for_actor(pylon)
	pylon.call("_process", 0.2)
	var cue := pylon.get_node_or_null("ChargeCue") as Sprite2D
	_check(_is_png_sprite(cue) and cue.visible, "a visible PNG sprite gives the directional charge before the shot")
	var ring := pylon.get_node_or_null("ChargeRing") as Sprite2D
	_check(_is_png_sprite(ring) and ring.visible, "the muzzle charge uses a visible PNG ring rather than a drawn arc")
	_check(_shots_from(pylon).is_empty(), "firing feedback provides a real reaction window before damage leaves")
	pylon.call("_process", 0.4)
	_check(cue != null and not cue.visible and ring != null and not ring.visible, "raster charge cues end when the shot releases")
	var shots := _shots_from(pylon)
	var shot_refs: Array[WeakRef] = []
	for shot: Node in shots:
		shot_refs.append(weakref(shot))
	_check(shots.size() == 1, "one completed windup releases one shot")
	if not shots.is_empty():
		var binding: Variant = shots[0].get_meta(&"boss_attack_scope") if shots[0].has_meta(&"boss_attack_scope") else null
		_check(binding is WeakRef and binding.get_ref() == owner["scope"], "pylon shots inherit the encounter scope")
	var before_defeats := _defeats
	var before_kills := _kills
	(owner["scope"] as Node).call("cancel")
	_check(not EnemyWorld.is_valid_handle(handle), "scope cancellation unregisters its pylon immediately")
	await get_tree().process_frame
	_check(not is_instance_valid(pylon), "scope cancellation removes its pylon")
	var shots_gone := true
	for shot_ref: WeakRef in shot_refs:
		shots_gone = shots_gone and not is_instance_valid(shot_ref.get_ref())
	_check(shots_gone, "scope cancellation also clears the pylon's in-flight shots")
	_check(_defeats == before_defeats and _kills == before_kills, "encounter cleanup produces no kill or defeat rewards")
	if is_instance_valid(pylon):
		pylon.queue_free()
	for shot_ref: WeakRef in shot_refs:
		var remaining: Variant = shot_ref.get_ref()
		if remaining != null and is_instance_valid(remaining):
			remaining.queue_free()
	(owner["boss"] as Node).queue_free()
	await get_tree().process_frame


func _test_detached_scope_cleanup() -> void:
	var owner := _new_owner()
	var pylon := _configured(Vector2(700, 400), owner["boss"], 12.0)
	pylon.projectile_scene = null
	var handle := EnemyCombat.handle_for_actor(pylon)
	var before_defeats := _defeats
	var before_kills := _kills
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	# Scene teardown can detach a pylon before its owning scope exits.
	remove_child(pylon)
	(owner["scope"] as Node).call("cancel")
	pylon.take_damage(999.0, _player)
	OS.remove_logger(errors)
	_check(not EnemyWorld.is_valid_handle(handle), "detaching a pylon releases its combat handle before scope cleanup")
	_check(pylon.is_queued_for_deletion(), "scope cleanup also disposes of an already-detached pylon")
	_check(errors.errors.is_empty(), "detached scope cleanup reports no runtime errors: %s" % [errors.errors])
	_check(_defeats == before_defeats and _kills == before_kills, "detached cleanup and late damage produce no kill or defeat rewards")
	await get_tree().process_frame
	_check(not is_instance_valid(pylon), "the detached pylon is freed at the next deletion flush")
	(owner["boss"] as Node).queue_free()
	await get_tree().process_frame


func _test_destroyed() -> void:
	var pylon := PYLON.instantiate() as BossPylon
	pylon.projectile_scene = null
	add_child(pylon)
	pylon.set_process(false)
	var handle := EnemyCombat.handle_for_actor(pylon)
	var before_defeats := _defeats
	var before_kills := _kills
	pylon.take_damage(999.0, _player)
	var burst := pylon.get_node_or_null("DestructionBurst") as Sprite2D
	_check(_is_png_sprite(burst) and burst.visible, "destruction feedback uses an actual PNG burst sprite")
	_check(_defeats == before_defeats + 1 and _kills == before_kills + 1, "player destruction emits the existing defeat and kill once")
	_check(not EnemyWorld.is_valid_handle(handle), "destroyed pylons leave combat indexing immediately")
	pylon.take_damage(999.0, _player)
	_check(_defeats == before_defeats + 1 and _kills == before_kills + 1, "repeated damage cannot duplicate a destroyed pylon's events")
	pylon.call("_process", 0.08)
	_check(not pylon.is_queued_for_deletion() and pylon.modulate.a < 1.0, "destruction has a short visible collapse before deletion")
	pylon.call("_process", 1.0)
	await get_tree().process_frame
	_check(not is_instance_valid(pylon), "destruction feedback finishes and frees the target")
