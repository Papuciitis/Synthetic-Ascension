extends Node
## Real boss scenes and arena rules: catches returning root-scale enlargement,
## tier art aliasing, shared collider/spec mutation and misanchored feet.

const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const MINI_ARENA := preload("res://scenes/world/events/MiniBossArena.tscn")
const MAIN_ARENA := preload("res://scenes/world/events/BossArena.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const BRUTE := preload("res://core/actors/enemy/EnemySpec_Brute.tres")
const APPEARANCE_PATH := "res://scenes/world/bosses/BossAppearance.gd"

var _passes := 0
var _failures := 0
var _actors: Array[EnemyActor] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.save_dir = "user://boss_proportion_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	var player := Node2D.new()
	player.position = Vector2(9000, 9000)
	player.add_to_group(&"player")
	add_child(player)
	var has_appearance := ResourceLoader.exists(APPEARANCE_PATH)
	_check(has_appearance, "boss proportions have an explicit tier appearance contract")
	var textures := PackedStringArray()
	for row: Dictionary in [
		{"scene": TANK, "tank": true, "tier": 0, "radius": 39.015, "box": 78.03, "height": 88.0, "form": "bulldozer_s5_v1"},
		{"scene": TANK, "tank": true, "tier": 1, "radius": 44.795, "box": 89.59, "height": 88.0, "form": "bulldozer_s10_v1"},
		{"scene": MAGE, "tank": false, "tier": 0, "radius": 36.72, "box": 73.44, "height": 82.0, "form": "arcanist_s5_v1"},
		{"scene": MAGE, "tank": false, "tier": 1, "radius": 42.16, "box": 84.32, "height": 86.0, "form": "arcanist_s10_v1"},
	]:
		var actor := _spawn(row["scene"] as PackedScene)
		var original_texture := actor.spec.sprite_texture
		var original_scale := actor.spec.sprite_scale
		var original_color := actor.spec.sprite_modulate
		_check(actor.scale.is_equal_approx(Vector2.ONE), "%s scene starts at unit root scale" % row["form"])
		_apply_arena(actor, bool(row["tank"]), int(row["tier"]))
		_check(actor.scale.is_equal_approx(Vector2.ONE), "%s arena leaves anatomy independent of root scale" % row["form"])
		var body := actor.get_node("CollisionShape2D") as CollisionShape2D
		var hitbox := actor.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
		var world_radius := (body.shape as CircleShape2D).radius * absf(actor.scale.x)
		var world_box := (hitbox.shape as RectangleShape2D).size * actor.scale.abs()
		_check(is_equal_approx(world_radius, float(row["radius"])), "%s preserves its physical body radius" % row["form"])
		_check(world_box.is_equal_approx(Vector2.ONE * float(row["box"])), "%s preserves its contact footprint" % row["form"])
		var handle := EnemyWorld.handle_for_actor(actor)
		_check(handle != 0 and is_equal_approx(EnemyWorld.get_collision_radius(handle), float(row["radius"])), "%s authoritative radius agrees with its physical shape" % row["form"])
		var sprite := actor.get_node("Sprite2D") as Sprite2D
		var texture_path := sprite.texture.resource_path if sprite.texture != null else ""
		textures.append(texture_path)
		_check(texture_path.ends_with(String(row["form"]) + ".png"), "%s selects dedicated authored art" % row["form"])
		_check(sprite.modulate.is_equal_approx(Color.WHITE), "%s retains its authored material palette" % row["form"])
		var notes: Dictionary = actor.get_meta(&"boss_appearance", {})
		_check(notes.has("anatomy_rect") and notes.has("equipment_rect") and notes.has("feet_anchor"), "%s records anatomy, equipment and feet independently" % row["form"])
		if notes.has("anatomy_rect") and notes.has("equipment_rect") and notes.has("feet_anchor"):
			var anatomy: Rect2 = notes["anatomy_rect"]
			var equipment: Rect2 = notes["equipment_rect"]
			var foot: Vector2 = notes["feet_anchor"]
			_check(is_equal_approx(anatomy.size.y * absf(sprite.scale.y), float(row["height"])), "%s anatomy stays at its human-relative target" % row["form"])
			_check(equipment.encloses(anatomy), "%s equipment envelope contains its anatomy" % row["form"])
			var foot_local := sprite.position + (foot - sprite.texture.get_size() * 0.5) * sprite.scale
			# Match the production player's mid-body combat origin. Its feet are
			# 42 world px below that origin; moving them to zero displaces the
			# whole upper body outside the retained contact/query footprint.
			_check(foot_local.distance_to(Vector2(0, 42)) < 0.01, "%s feet preserve the production mid-body origin contract" % row["form"])
			var actual_anatomy := Rect2(sprite.position + (anatomy.position - sprite.texture.get_size() * 0.5) * sprite.scale, anatomy.size * sprite.scale.abs())
			var upper_body := Vector2(actual_anatomy.get_center().x, actual_anatomy.position.y + actual_anatomy.size.y * 0.15)
			var contact_rect := Rect2(world_box * -0.5, world_box)
			_check(contact_rect.has_point(upper_body) and upper_body.length() <= world_radius, "%s visible upper body remains targetable inside its real body and contact shapes" % row["form"])
			var noted_anatomy: Rect2 = notes.get("anatomy_bounds_world", Rect2())
			var actual_equipment := Rect2(sprite.position + (equipment.position - sprite.texture.get_size() * 0.5) * sprite.scale, equipment.size * sprite.scale.abs())
			var noted_equipment: Rect2 = notes.get("equipment_bounds_world", Rect2())
			_check(noted_anatomy.is_equal_approx(actual_anatomy) and noted_equipment.is_equal_approx(actual_equipment), "%s recorded bounds follow the actual sprite translation" % row["form"])
		_check(actor.spec.sprite_texture == original_texture and actor.spec.sprite_scale == original_scale and actor.spec.sprite_modulate == original_color, "%s never mutates its shared EnemySpec" % row["form"])
	var unique_paths := {}
	for path: String in textures:
		unique_paths[path] = true
	_check(unique_paths.size() == 4, "all four forms remain visually distinct resources")
	await _test_unique_shapes_and_tier_reapply(has_appearance)
	await _test_ordinary_enemy_unchanged()
	_test_authoritative_radius_limits()
	for actor: EnemyActor in _actors:
		actor.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("BossProportionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _spawn(scene: PackedScene) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.position = Vector2(1200 + _actors.size() * 200, 1800)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(actor)
	_actors.append(actor)
	return actor


func _apply_arena(actor: EnemyActor, tank: bool, tier: int) -> void:
	var arena: Node = (MINI_ARENA if tier == 0 else MAIN_ARENA).instantiate()
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(arena)
	arena.set("_is_tank", tank)
	Global.attempt_segment = 5 if tier == 0 else 10
	arena.call("_apply_miniboss_rules" if tier == 0 else "_apply_boss_rewards_and_rules", actor)
	arena.queue_free()


func _test_unique_shapes_and_tier_reapply(has_appearance: bool) -> void:
	var first := _spawn(TANK)
	var second := _spawn(TANK)
	_apply_arena(first, true, 0)
	_apply_arena(second, true, 0)
	var first_body := first.get_node("CollisionShape2D") as CollisionShape2D
	var second_body := second.get_node("CollisionShape2D") as CollisionShape2D
	var first_hit := first.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
	var second_hit := second.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
	_check(first_body.shape != second_body.shape and first_hit.shape != second_hit.shape, "each boss owns its collision resources")
	if has_appearance:
		var appearance: Script = load(APPEARANCE_PATH)
		appearance.call("apply", first, 1)
		appearance.call("apply", first, 1)
		_check(first.scale.is_equal_approx(Vector2.ONE) and is_equal_approx((first_body.shape as CircleShape2D).radius, 44.795), "reapplying main-boss presentation cannot multiply its footprint")
		_check(is_equal_approx(EnemyWorld.get_collision_radius(EnemyWorld.handle_for_actor(first)), 44.795), "tier reconfiguration updates the authoritative collision radius")
		_check(is_equal_approx((second_body.shape as CircleShape2D).radius, 39.015), "changing one tier cannot resize a sibling boss")
		appearance.call("apply", first, 0)
		_check(is_equal_approx((first_body.shape as CircleShape2D).radius, 39.015), "returning to S5 restores its authored footprint")
	await get_tree().process_frame


func _test_ordinary_enemy_unchanged() -> void:
	var brute := ENEMY.instantiate() as EnemyActor
	brute.spec = BRUTE
	brute.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(brute)
	_actors.append(brute)
	var sprite := brute.get_node("Sprite2D") as Sprite2D
	var body := brute.get_node("CollisionShape2D") as CollisionShape2D
	_check(sprite.texture == BRUTE.sprite_texture and sprite.scale == BRUTE.sprite_scale, "ordinary Brute presentation keeps its existing spec")
	_check(is_equal_approx((body.shape as CircleShape2D).radius, 17.0), "boss collider normalization cannot mutate ordinary enemy bodies")
	_check(not brute.has_meta(&"boss_appearance"), "boss appearance hooks leave ordinary enemies alone")
	await get_tree().process_frame


func _test_authoritative_radius_limits() -> void:
	# Broadphase padding must grow and shrink with a changed physical radius.
	var has_setter := EnemyWorld.has_method("set_collision_radius")
	_check(has_setter, "authoritative footprints can be reconfigured without replacing enemy identity")
	if not has_setter:
		return
	var before := EnemyWorld.largest_collision_radius()
	var first := EnemyWorld.create_enemy(EnemySpawnState.new(&"radius_fixture", "", Vector2(8000, 8000), 1.0, 0.0, 500.0, 0))
	var second := EnemyWorld.create_enemy(EnemySpawnState.new(&"radius_fixture", "", Vector2(8200, 8000), 1.0, 0.0, 550.0, 0))
	EnemyWorld.call("set_collision_radius", first, 600.0)
	_check(is_equal_approx(EnemyWorld.largest_collision_radius(), 600.0), "broadphase padding expands when an existing enemy grows")
	EnemyWorld.call("set_collision_radius", first, 400.0)
	_check(is_equal_approx(EnemyWorld.largest_collision_radius(), 550.0), "shrinking the largest enemy restores the next real footprint")
	EnemyWorld.call("set_collision_radius", second, -10.0)
	_check(is_zero_approx(EnemyWorld.get_collision_radius(second)) and is_equal_approx(EnemyWorld.largest_collision_radius(), 400.0), "negative radius input clamps safely and updates the maximum")
	EnemyWorld.remove_enemy(first, &"test_cleanup")
	_check(not bool(EnemyWorld.call("set_collision_radius", first, 900.0)), "a retired enemy handle cannot change collision padding")
	EnemyWorld.remove_enemy(second, &"test_cleanup")
	_check(is_equal_approx(EnemyWorld.largest_collision_radius(), before), "temporary radius records leave ordinary broadphase padding intact")
