extends Node2D

const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PlayerVisual = preload("res://core/actors/player/PlayerVisualController.gd")

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
	var style: Script = load("res://core/systems/world/WorldDepthStyle.gd") if ResourceLoader.exists("res://core/systems/world/WorldDepthStyle.gd") else null
	_check(style != null, "world and characters share one cast-shadow projection")
	if style != null:
		var feet := Vector2(42, 80)
		var projected: Transform2D = style.projection_at(feet)
		_check((projected * feet).is_equal_approx(feet), "projection keeps the feet planted")
		var cast := projected * (feet + Vector2(0, -60)) - feet
		_check(cast.x < -20 and cast.y > 20, "upright silhouettes cast visibly southwest")
		_check((projected * (feet + Vector2(10, 0))).is_equal_approx(feet + Vector2(10, 0)), "projection preserves the contact width")
	await _test_enemies(style)
	await _test_player(style)
	print("ActorDepthShadowTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_enemies(style: Script) -> void:
	var world := WorldScript.new()
	add_child(world)
	var renderer := RendererScript.new()
	renderer.setup(world)
	add_child(renderer)
	var texture_path := "res://assets/textures/characters/baked/grunt_atlas.png"
	var handle := world.create_enemy(SpawnState.new(&"shadow", "res://shadow.tscn", Vector2(300, 200), 20, 0, 8, 0, 0, {
		"proxy_visual_key": &"shadow", "proxy_texture_path": texture_path,
		"proxy_size": Vector2(41, 63), "proxy_region": Rect2(0.01, 0.02, 0.12, 0.24), "proxy_color": Color.WHITE,
	}))
	renderer.publish()
	var batch: Dictionary = (renderer.get("_batches") as Dictionary).values()[0]
	var shadow := batch.get("shadow_multimesh") as MultiMesh
	_check(shadow != null, "every visible enemy batch publishes a cast-shadow batch")
	if shadow != null and style != null:
		_check(shadow.visible_instance_count == 1 and renderer.visible_count() == 1 and renderer.batch_count() == 1, "shadows preserve gameplay population and batch counts")
		var visual := renderer.debug_instance_transform(handle)
		var shadow_transform := _shadow_transform(batch)
		var feet := visual.origin - visual.y * 0.5
		_check((shadow_transform * Vector2(0, -0.5)).is_equal_approx(feet), "enemy shadow stays attached to its frame's feet")
		var custom := _shadow_region(batch)
		_check(absf(custom.r - 0.01) < 0.0001 and absf(custom.g - 0.02) < 0.0001 and absf(custom.b - 0.12) < 0.0001 and absf(custom.a - 0.24) < 0.0001, "shadow samples only the selected atlas region")
		renderer.flash_handle(handle)
		world.set_position(handle, Vector2(320, 200))
		renderer.publish(0.25)
		visual = renderer.debug_instance_transform(handle)
		feet = visual.origin - visual.y * 0.5
		_check(renderer.debug_instance_flashing(handle) and _shadow_region(batch).a > 0, "hit flashes never flag the shadow for a white flash")
		_check((_shadow_transform(batch) * Vector2(0, -0.5)).is_equal_approx(feet), "shadow follows the same interpolated proxy pose")
		var retained := _shadow_transform(batch)
		renderer.publish(1, false)
		_check(_shadow_transform(batch).is_equal_approx(retained), "half-rate proxy publication retains its matching shadow")
		world.set_representation(handle, 1)
		renderer.publish()
		_check(shadow.visible_instance_count == 0, "materializing removes the data-only shadow without a duplicate")
		world.set_representation(handle, 0)
		world.set_position(handle, Vector2(-5000, 200))
		renderer.publish()
		_check(shadow.visible_instance_count == 0, "offscreen proxies have no cast shadows")
		world.remove_enemy(handle, &"shadow_test")
		renderer.publish()
		_check(shadow.visible_instance_count == 0, "removed generations leave no stale cast shadows")
	var actor := Node2D.new()
	actor.position = Vector2(400, 200)
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(2, 129, 41, 63)
	actor.add_child(sprite)
	add_child(actor)
	renderer.register_actor(actor, sprite)
	renderer.publish()
	var actor_batch: Dictionary = (renderer.get("_batches") as Dictionary).get(StringName("actor:" + texture_path), {})
	var actor_shadow := actor_batch.get("shadow_multimesh") as MultiMesh
	_check(actor_shadow != null, "materialized actors share the same batched shadow path")
	if actor_shadow != null:
		var visual := renderer.debug_actor_instance_transform(actor)
		_check((_shadow_transform(actor_batch) * Vector2(0, -0.5)).is_equal_approx(visual.origin - visual.y * 0.5), "materialized shadow anchors the active stride frame")
		actor.set_meta(&"__in_pool", true)
		renderer.publish()
		_check(actor_shadow.visible_instance_count == 0, "pool inventory never leaves an actor shadow")
		actor.remove_meta(&"__in_pool")
		actor.position = Vector2(-5000, 200)
		renderer.publish()
		_check(actor_shadow.visible_instance_count == 0, "offscreen materialized actors have no shadows")
		actor.position = Vector2(400, 200)
		renderer.reset_actor_snapshot(actor)
		renderer.publish()
		_check(actor_shadow.visible_instance_count == 1, "reused actor restores exactly one shadow")
	actor.free()
	renderer.publish()
	if actor_shadow != null:
		_check(actor_shadow.visible_instance_count == 0, "freed actor shadows disappear with the visual")
	# Static role art arrives as AtlasTexture, whose RID exposes the full sheet.
	# The batched path must normalize its region explicitly, unlike Sprite2D.
	var static_actor := Node2D.new()
	static_actor.position = Vector2(400, 200)
	var static_sprite := Sprite2D.new()
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load(texture_path)
	atlas_texture.region = Rect2(2, 2, 41, 63)
	static_sprite.texture = atlas_texture
	static_actor.add_child(static_sprite)
	add_child(static_actor)
	renderer.register_actor(static_actor, static_sprite)
	renderer.publish()
	var static_uv := renderer.debug_actor_instance_uv(static_actor)
	var sheet_size := atlas_texture.atlas.get_size()
	_check(static_uv.position.is_equal_approx(Vector2(2, 2) / sheet_size) and static_uv.size.is_equal_approx(Vector2(41, 63) / sheet_size), "static actor AtlasTexture samples its own cropped role")
	_check(absf(renderer.debug_actor_instance_transform(static_actor).x.length() - 41) < 0.01, "static actor AtlasTexture keeps its frame size")
	var baked: CharacterFrameSet = load("res://assets/textures/characters/baked/grunt_frames.tres")
	var baked_texture := baked.frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	var static_proxy := world.create_enemy(SpawnState.new(&"static_shadow", "res://static_shadow.tscn", Vector2(600, 200), 20, 0, 8, 0, 0, {
		"proxy_visual_key": &"static_shadow", "proxy_texture_path": baked_texture.resource_path,
		"proxy_size": Vector2(41, 63), "proxy_color": Color.WHITE,
	}))
	renderer.publish()
	var profile: Dictionary = (renderer.get("_visual_profiles") as Dictionary)[static_proxy]
	var proxy_uv := profile.get("region") as Rect2
	_check(proxy_uv.position.is_equal_approx(Vector2(2, 2) / sheet_size) and proxy_uv.size.is_equal_approx(Vector2(41, 63) / sheet_size), "static proxy AtlasTexture samples the same cropped role as its actor")
	static_actor.free()
	renderer.free()
	world.free()


func _test_player(style: Script) -> void:
	var parent := Node2D.new()
	parent.position = Vector2(500, 300)
	parent.rotation = 0.8
	var visual := PlayerVisual.new()
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.centered = false
	visual.add_child(body)
	var head_anchor := Node2D.new()
	head_anchor.name = "HeadAnchor"
	var head := AnimatedSprite2D.new()
	head.name = "Head"
	head.centered = false
	head_anchor.add_child(head)
	visual.add_child(head_anchor)
	var breath := AnimationPlayer.new()
	breath.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	library.add_animation(&"breathe", Animation.new())
	breath.add_animation_library(&"", library)
	visual.add_child(breath)
	parent.add_child(visual)
	add_child(parent)
	var shadow := visual.get_node_or_null("CastShadow") as Node2D
	_check(shadow != null, "player casts body and head shadows from its real pose")
	if shadow != null and style != null:
		_check(shadow.get_child_count() == 2, "player shadow contains both body and head")
		for facing: StringName in [&"down", &"left", &"up", &"right"]:
			visual.set_preview(PlayerVisual.State.RUN, facing)
			visual.call("_apply")
			body.frame = 1
			visual.call("_apply")
			var body_shadow := shadow.get_node("Body") as Sprite2D
			var head_shadow := shadow.get_node("Head") as Sprite2D
			_check(body_shadow.texture == body.sprite_frames.get_frame_texture(body.animation, body.frame) and head_shadow.texture == head.sprite_frames.get_frame_texture(head.animation, head.frame), "player shadow matches %s body and head atlas frames" % facing)
			var ground_feet := parent.global_position + Vector2(0, PlayerVisual.FEET_BELOW_ORIGIN)
			_check(shadow.global_position.is_equal_approx(ground_feet), "rotating player preserves the %s shadow foot anchor" % facing)
			_check(body_shadow.global_transform.origin.is_equal_approx(shadow.global_transform * body.position), "stride bob is projected from the same planted feet")
		visual.set_race(&"elf")
		visual.call("_apply")
		_check((shadow.get_node("Body") as Sprite2D).texture == body.sprite_frames.get_frame_texture(body.animation, body.frame), "race changes replace the shadow pose without stale textures")
	parent.free()


func _shadow_transform(batch: Dictionary) -> Transform2D:
	var buffer := batch.get("shadow_buffer") as PackedFloat32Array
	return Transform2D(Vector2(buffer[0], buffer[4]), Vector2(buffer[1], buffer[5]), Vector2(buffer[3], buffer[7]))


func _shadow_region(batch: Dictionary) -> Color:
	var buffer := batch.get("shadow_buffer") as PackedFloat32Array
	return Color(buffer[12], buffer[13], buffer[14], buffer[15])
