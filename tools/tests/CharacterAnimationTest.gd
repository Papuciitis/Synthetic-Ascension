extends Node

# The character animation integration: every race's baked frame set is
# complete, the player's visual controller maps velocity to the right
# idle/run facing with diagonal hysteresis and keeps the art upright while
# the body rotates, race switching swaps the frames, the enemy animator
# drives atlas regions from velocity, and the batched proxy renderer hands
# the shader a region-sized quad with the frame's UV rectangle.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")

const RACES: Array[StringName] = [&"human", &"elf", &"dragonborn", &"warforged"]
const FACINGS: Array[StringName] = [&"down", &"left", &"up", &"right"]

var _passes := 0
var _failures := 0


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
	_test_frame_sets()
	await _test_player_visuals()
	_test_enemy_animator()
	await _test_renderer_regions()
	print("%d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_frame_sets() -> void:
	for race in RACES:
		var path: String = PlayerVisualController.RACE_DEFINITIONS[race]
		var definition := load(path) as RaceVisualDefinition
		_check(definition != null, "%s: definition loads" % race)
		if definition == null:
			continue
		var frame_set := load(definition.baked_frames_path()) as CharacterFrameSet
		_check(frame_set != null and frame_set.frames != null, "%s: baked frame set loads" % race)
		if frame_set == null or frame_set.frames == null:
			continue
		for facing in FACINGS:
			for layer_state in ["body_idle", "body_run", "head_idle"]:
				var animation := StringName("%s_%s" % [layer_state, facing])
				var count := frame_set.frame_count(animation)
				var expected := 8 if layer_state == "body_run" else 1
				_check(count >= expected, "%s: %s has %d frame(s)" % [race, animation, count])
				var anchor := frame_set.anchor(animation, 0)
				_check(anchor.y > 0.0, "%s: %s hangs from a measured anchor" % [race, animation])
			var collar := frame_set.collar(StringName("body_idle_" + String(facing)), 0)
			_check(collar.y < -30.0 and collar.y > -60.0, "%s: idle %s collar sits above the feet (%s)" % [race, facing, collar])
		_check(not frame_set.mirrored.has("head_idle_up") and not frame_set.mirrored.has("head_idle_down"), "%s: front/back heads are never mirrors" % race)


func _test_player_visuals() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	var visual := player.get_node("Visual") as PlayerVisualController
	_check(visual != null, "player.tscn carries the visual controller")
	if visual == null:
		player.queue_free()
		return
	_check(visual.body.sprite_frames != null and visual.head.sprite_frames != null, "spawn shows the selected race's frames")
	_check(visual.body_animation == &"body_idle_down", "spawn idles facing down (%s)" % visual.body_animation)

	player.velocity = Vector2(100.0, 0.0)
	visual._process(0.016)
	_check(visual.body_animation == &"body_run_right" and visual.head_animation == &"head_idle_right", "moving right runs right (%s / %s)" % [visual.body_animation, visual.head_animation])
	player.velocity = Vector2(100.0, 110.0)
	visual._process(0.016)
	_check(visual.facing == &"right", "a near-diagonal keeps the horizontal facing (bias)")
	player.velocity = Vector2(100.0, 140.0)
	visual._process(0.016)
	_check(visual.facing == &"down", "a clearly vertical diagonal turns down")
	player.velocity = Vector2(0.0, -100.0)
	visual._process(0.016)
	_check(visual.body_animation == &"body_run_up", "moving up runs up")
	player.velocity = Vector2.ZERO
	visual._process(0.016)
	_check(visual.body_animation == &"body_idle_up" and visual.head_animation == &"head_idle_up", "stopping idles facing the last direction (%s)" % visual.body_animation)
	_check(visual.breath.is_playing() and visual.breath.current_animation == &"breathe", "idle plays the breathing loop")
	player.velocity = Vector2(-100.0, 0.0)
	visual._process(0.016)
	_check(not visual.breath.is_playing(), "running stops the breathing loop")
	var frame_anchor := visual.frame_set.anchor(visual.body_animation, visual.body.frame)
	_check(visual.body.offset == -frame_anchor, "the body hangs from its frame anchor")
	_check(visual.head_anchor.position.y < 0.0, "the head sits above the feet")

	player.rotation = 1.3
	visual._process(0.016)
	_check(is_zero_approx(visual.global_rotation), "the art stays upright while the body rotates")
	var expected_drop := player.global_position + Vector2(0.0, PlayerVisualController.FEET_BELOW_ORIGIN)
	_check(visual.global_position.is_equal_approx(expected_drop), "the art hangs mid-body on the origin whatever the body's rotation (%s)" % visual.global_position)
	_check(player.position == Vector2.ZERO, "the visual never moves the gameplay body")

	for race in RACES:
		_check(visual.set_race(race), "set_race(%s)" % race)
		_check(visual.race_id == race and visual.body.sprite_frames == visual.frame_set.frames, "%s frames are live after the switch" % race)
		_check(visual.body_animation == &"body_run_left", "%s keeps the pose across the switch" % race)
	_check(not visual.set_race(&"no_such_race") or visual.race_id == PlayerVisualController.DEFAULT_RACE, "an unknown race falls back to the default")
	player.queue_free()


func _test_enemy_animator() -> void:
	var frame_set := load("res://assets/textures/characters/baked/grunt_frames.tres") as CharacterFrameSet
	_check(frame_set != null, "grunt frames load")
	if frame_set == null:
		return
	var sprite := Sprite2D.new()
	add_child(sprite)
	var animator := EnemyAnimator.new()
	_check(animator.setup(sprite, sprite, frame_set, 10.0), "animator accepts the grunt frames")
	_check(sprite.region_enabled and sprite.texture != null, "the sprite shows an atlas region")
	var idle_down := sprite.region_rect
	_check(idle_down == frame_set.frames.get_frame_texture(&"idle_down", 0).region, "it starts on the standing frame")
	animator.tick(Vector2(0.0, 80.0))
	var run_regions: Array[Rect2] = []
	for index in range(frame_set.frames.get_frame_count(&"run_down")):
		run_regions.append((frame_set.frames.get_frame_texture(&"run_down", index) as AtlasTexture).region)
	_check(run_regions.has(sprite.region_rect), "walking down shows a run_down frame")
	animator.tick(Vector2(0.0, -80.0))
	var up_regions: Array[Rect2] = []
	for index in range(frame_set.frames.get_frame_count(&"run_up")):
		up_regions.append((frame_set.frames.get_frame_texture(&"run_up", index) as AtlasTexture).region)
	_check(up_regions.has(sprite.region_rect), "walking up shows a run_up frame")
	animator.tick(Vector2.ZERO)
	_check(sprite.region_rect == frame_set.frames.get_frame_texture(&"idle_up", 0).region, "stopping keeps the last facing")
	_check(animator.idle_region() == sprite.region_rect, "idle_region reports the proxy frame")
	sprite.queue_free()


func _test_renderer_regions() -> void:
	var world := WorldScript.new()
	add_child(world)
	var renderer := RendererScript.new()
	renderer.setup(world)
	add_child(renderer)
	var actor := Node2D.new()
	actor.position = Vector2(10.0, 20.0)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/textures/characters/baked/grunt_atlas.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(40.0, 0.0, 30.0, 60.0)
	actor.add_child(sprite)
	add_child(actor)
	await get_tree().process_frame
	renderer.register_actor(actor, sprite)
	renderer.publish(1.0, false)
	var uv := renderer.debug_actor_instance_uv(actor)
	var size := sprite.texture.get_size()
	var expected := Rect2(40.0 / size.x, 0.0, 30.0 / size.x, 60.0 / size.y)
	_check(uv.is_equal_approx(expected), "a region sprite publishes its UV rectangle (%s)" % uv)
	var xf := renderer.debug_actor_instance_transform(actor)
	_check(is_equal_approx(xf.x.length(), 30.0) and is_equal_approx(xf.y.length(), 60.0), "the quad is sized to the region, not the sheet (%s)" % xf)
	sprite.region_enabled = false
	renderer.publish(1.0, false)
	_check(renderer.debug_actor_instance_uv(actor).is_equal_approx(Rect2(0.0, 0.0, 1.0, 1.0)), "a plain sprite publishes the whole texture")
	actor.queue_free()
	renderer.queue_free()
	world.queue_free()
