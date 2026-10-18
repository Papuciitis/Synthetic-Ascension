extends Node
## A live arena spawn must select its final form before EnemyInit runs.
## Building S5 and replacing it with S10 loads two large textures and creates
## two acting nodes on the entrance frame (2026-10-18 incident 106).
const MAIN := preload("res://scenes/world/events/BossArena.tscn")
const MINI := preload("res://scenes/world/events/MiniBossArena.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const APPEARANCE := preload("res://scenes/world/bosses/BossAppearance.gd")

var _passes := 0
var _failures := 0
var _forms: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _record_acting(node: Node) -> void:
	if node.name != &"BossActing" or not node.get_parent() is EnemyActor:
		return
	var sprite := node.get_parent().get_node("Sprite2D") as Sprite2D
	_forms.append(sprite.texture.resource_path)


func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_spawn_presentation_%d/" % Time.get_ticks_usec()
	Global.start_new_attempt()
	Global.attempt_opening_completed = true
	Global.attempt_segment = 10
	get_tree().node_added.connect(_record_acting)
	for arena_scene: PackedScene in [MAIN, MINI]:
		var tier := 1 if arena_scene == MAIN else 0
		for packed: PackedScene in [MAGE, TANK]:
			var arena := arena_scene.instantiate() as Node2D
			# Make archetype selection deterministic without bypassing _spawn.
			arena.set("tank_boss_scenes", [packed] as Array[PackedScene])
			arena.set("mage_boss_scenes", [packed] as Array[PackedScene])
			arena.position = Vector2(5000, 5000)
			add_child(arena)
			arena.set_process(false)
			_forms.clear()
			var started := Time.get_ticks_usec()
			arena.call("_spawn")
			var spawn_usec := Time.get_ticks_usec() - started
			var actor := arena.get("_boss" if tier == 1 else "_enemy") as EnemyActor
			_check(actor != null, "tier %d arena spawns its configured boss" % tier)
			if actor != null:
				actor.process_mode = Node.PROCESS_MODE_DISABLED
				var id := String(actor.spec.id)
				var profile: Dictionary = APPEARANCE.PROFILES[actor.spec.id][tier]
				var expected := APPEARANCE.ART_ROOT + String(profile["form"]) + ".png"
				_check(_forms.size() == 1 and _forms[0] == expected,
					"%s tier %d initializes only its final form (%s)" % [id, tier, str(_forms)])
				_check(int(actor.get_meta(&"boss_visual_tier", -1)) == tier,
					"%s retains the arena's visual tier" % id)
				var body := actor.get_node("CollisionShape2D") as CollisionShape2D
				_check(is_equal_approx((body.shape as CircleShape2D).radius, float(profile["radius"]))
					and is_equal_approx(EnemyWorld.get_collision_radius(EnemyWorld.handle_for_actor(actor)), float(profile["radius"])),
					"%s tier %d body and world handle share the final footprint" % [id, tier])
				print("SPAWN_PRESENTATION ", JSON.stringify({"boss": id, "tier": tier,
					"spawn_usec": spawn_usec, "initialized_forms": _forms.duplicate()}))
			arena.queue_free()
			await get_tree().process_frame
	get_tree().node_added.disconnect(_record_acting)
	print("BossSpawnPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
