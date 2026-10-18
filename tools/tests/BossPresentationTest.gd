extends Node
## Exercises real attack state transitions. Catches missing/reversed acting,
## phase visual rollback, collision resizing and Reduced Motion regressions.
const APPEARANCE := preload("res://scenes/world/bosses/BossAppearance.gd")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const BAR := preload("res://ui/widgets/BossBarHUD.tscn")
var _passes := 0
var _failures := 0
var _world: Node2D
var _player: Node2D

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_presentation_%d/" % Time.get_ticks_usec()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	_world = Node2D.new()
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = PLAYER.instantiate()
	_world.add_child(_player)
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.position = Vector2(1300, 1000)
	for packed: PackedScene in [TANK, MAGE]:
		await _test_role(packed)
	await _test_portrait_routing()
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	print("BossPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)

func _test_portrait_routing() -> void:
	var hud := Control.new()
	add_child(hud)
	var bar := BAR.instantiate() as BossBarHUD
	bar.name = "BossBarHUD"
	hud.add_child(bar)
	var controller := HudBossController.new()
	controller.boss_bar_path = NodePath("../BossBarHUD")
	hud.add_child(controller)
	var legacy := load("res://ui/boss/portraits/boss_portrait.png") as Texture2D
	var paths: Array[String] = []
	for row: Dictionary in [
		{"scene": TANK, "tier": 0, "portrait": "res://ui/boss/portraits/bulldozer_s5_v2.png"},
		{"scene": MAGE, "tier": 0, "portrait": "res://ui/boss/portraits/arcanist_s5_v2.png"},
		{"scene": TANK, "tier": 1, "portrait": "res://ui/boss/portraits/bulldozer_s10_v2.png"},
		{"scene": MAGE, "tier": 1, "portrait": "res://ui/boss/portraits/arcanist_s10_v2.png"},
	]:
		var actor := (row["scene"] as PackedScene).instantiate() as EnemyActor
		_world.add_child(actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		RunEvents.boss_spawned.emit(actor, int(row["tier"]), legacy, "Boss")
		paths.append(bar.portrait.texture.resource_path)
		_check(bar.portrait.visible and bar.portrait.texture.resource_path == String(row["portrait"]), "%s tier %d HUD selects its matching world-form portrait" % [actor.spec.id, row["tier"]])
		RunEvents.boss_spawned.emit(actor, 2, legacy, "Unknown tier")
		_check(bar.portrait.texture == legacy, "unsupported boss tier preserves the caller's fallback")
		actor.spec = actor.spec.duplicate()
		actor.spec.id = &"unknown_boss_fixture"
		RunEvents.boss_spawned.emit(actor, 1, legacy, "Unknown role")
		_check(bar.portrait.texture == legacy, "unknown boss identity preserves the caller's fallback")
		actor.queue_free()
	var unique_paths := {}
	for path: String in paths:
		unique_paths[path] = true
	_check(unique_paths.size() == 4, "both boss choices in both tiers have distinct portraits")
	hud.queue_free()
	await get_tree().process_frame

func _test_role(packed: PackedScene) -> void:
	var actor := packed.instantiate() as EnemyActor
	actor.position = Vector2(1000, 1000)
	_world.add_child(actor)
	actor.add_to_group(&"boss")
	actor.set_process(false)
	actor.set_physics_process(false)
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	brain.set_physics_process(false)
	APPEARANCE.apply(actor, 1)
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	var rest := sprite.transform
	var body := actor.get_node("CollisionShape2D") as CollisionShape2D
	var contact := actor.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
	# Enemy actors receive hits through their real body shape; the player has
	# a separate Hurtbox, while these boss scenes deliberately do not.
	var footprint := [body.transform, body.shape, (body.shape as CircleShape2D).radius, contact.transform, contact.shape, (contact.shape as RectangleShape2D).size, actor.transform]
	var acting := actor.get_node_or_null("BossActing")
	_check(acting != null, "%s has attack acting independent of its physics root" % actor.spec.id)
	if acting == null:
		actor.queue_free()
		await get_tree().process_frame
		return
	acting.set_physics_process(false)
	if packed == TANK:
		brain.call("_do_slam")
	else:
		brain.call("_ensure_teaching")
		brain.call("_start_teaching_fan")
	acting.call("_physics_process", 0.2)
	var windup := sprite.transform
	_check(not windup.is_equal_approx(rest), "%s visibly anticipates a real committed attack" % actor.spec.id)
	var foot := Vector2(595, 1317) if packed == TANK else Vector2(500, 1477)
	_check((sprite.transform * (foot - sprite.texture.get_size() * 0.5)).distance_to(Vector2(0, 42)) < 0.01, "%s attack acting stays anchored to the original feet" % actor.spec.id)
	get_tree().paused = true
	acting.call("_physics_process", 0.2)
	_check(sprite.transform.is_equal_approx(windup), "%s pause freezes its attack acting" % actor.spec.id)
	get_tree().paused = false
	if packed == TANK:
		brain.call("_tick_cast", 2.0)
	else:
		brain.call("_process_teaching", 1.0)
	acting.call("_physics_process", 0.02)
	var release := sprite.transform
	_check(not release.is_equal_approx(windup), "%s real release changes its stance" % actor.spec.id)
	acting.call("_physics_process", 0.3)
	_check(not sprite.transform.is_equal_approx(release) and not sprite.transform.is_equal_approx(rest), "%s release settles into an exposed recovery stance" % actor.spec.id)
	# The production phase entry point owns monotonic equipment changes.
	if packed == TANK:
		brain.call("_tick_cast", 2.0)
	else:
		brain.call("_process_teaching", 2.0)
	brain.call("_begin_phase_shift", 2)
	acting.call("_physics_process", 0.2)
	var material := sprite.material as ShaderMaterial
	_check(material != null and int(material.get_shader_parameter("phase")) == 2, "%s phase three visibly energizes its own equipment" % actor.spec.id)
	actor.hp = actor.max_hp
	acting.call("_physics_process", 0.2)
	_check(material != null and int(material.get_shader_parameter("phase")) == 2, "%s healing cannot roll equipment back to phase one" % actor.spec.id)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	acting.call("_physics_process", 0.2)
	_check(sprite.transform.is_equal_approx(rest), "%s Reduced Motion restores the exact authored body pose" % actor.spec.id)
	_check([body.transform, body.shape, (body.shape as CircleShape2D).radius, contact.transform, contact.shape, (contact.shape as RectangleShape2D).size, actor.transform] == footprint, "%s acting and phase changes preserve damage-receiving body/contact geometry" % actor.spec.id)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	actor.dead = true
	acting.call("_physics_process", 0.2)
	_check(sprite.transform.is_equal_approx(rest) and not acting.is_physics_processing(), "%s defeat stops acting and restores the authored pose" % actor.spec.id)
	APPEARANCE.apply(actor, 0)
	_check(actor.get_node_or_null("BossActing") != null and sprite.material is ShaderMaterial and int((sprite.material as ShaderMaterial).get_shader_parameter("phase")) == 0, "%s changing to teaching tier keeps body acting and resets main-boss phase equipment" % actor.spec.id)
	actor.queue_free()
	await get_tree().process_frame
