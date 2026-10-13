extends SceneTree

# Catalog art must resolve through role-specific transparent atlas regions;
# visual normalization must leave the splitter's parent scale curve intact.
const ROLE_FOR_SPEC := {
	"Bomber": "bomber", "Charger": "charger", "Lurker": "charger", "Runner": "runner",
	"Summoner": "summoner", "Brute": "brute", "Warden": "warden", "BossBulldozer": "brute",
	"Herald": "herald", "Chanter": "herald", "BossArcanist": "herald", "Sniper": "sniper",
	"Orbiter": "orbiter", "Leech": "leech", "Siphon": "leech", "SummonedMinion": "minion",
	"OpeningOfficer": "warden", "ContainmentConstruct": "minion", "SplitterSlime": "splitter",
}
const ART_ROOT := "res://assets/textures/characters/generated/"
var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	root.get_node("Global").set("debug_disable_autosave", true)
	root.get_node("SaveManager").set("save_dir", "user://tests/enemy_art_catalog/")
	_check_batch_filtering()
	var regions: Dictionary = {}
	for name: String in ROLE_FOR_SPEC:
		var spec := load("res://core/actors/enemy/EnemySpec_%s.tres" % name)
		var texture: Texture2D = spec.sprite_texture
		var role: String = ROLE_FOR_SPEC[name]
		_check(texture is AtlasTexture and texture.resource_path == ART_ROOT + "enemy_%s.tres" % role, "%s uses its matching role atlas" % name)
		if not texture is AtlasTexture:
			continue
		_check(texture.atlas != null and texture.atlas.resource_path == ART_ROOT + "enemy_roles_v4.png", "%s resolves to the new character sheet" % name)
		var visual_size: Vector2 = texture.get_size() * spec.sprite_scale
		if name == "SplitterSlime":
			_check(visual_size.distance_to(Vector2(43.68, 38.64)) < 0.02, "slime preserves the old texture's pre-parent visual dimensions")
			_check(is_equal_approx(spec.split_base_scale, 2.0) and is_equal_approx(spec.split_scale_per_generation, 0.5) and is_equal_approx(spec.split_elite_scale_mult, 2.0), "slime retains its authored split and elite scale curve")
		elif name == "SummonedMinion":
			_check(is_equal_approx(visual_size.y, 44.0) and is_equal_approx(spec.sprite_scale.x, spec.sprite_scale.y), "summoned elemental preserves its small 44 px frame with uniform proportions")
		else:
			_check(visual_size.y >= 64.0 and visual_size.y <= 72.1, "%s has a regular humanoid frame height before parent scaling" % name)
		regions[role] = texture.region
	for role: String in regions:
		var texture := load(ART_ROOT + "enemy_%s.tres" % role) as AtlasTexture
		var image := texture.get_image()
		_check(image != null and image.detect_alpha() != Image.ALPHA_NONE, "%s retains transparent pixels" % role)
		if image != null:
			var clear_gutter := true
			for x in range(image.get_width()):
				clear_gutter = clear_gutter and image.get_pixel(x, 0).a < 0.05 and image.get_pixel(x, image.get_height() - 1).a < 0.05
			for y in range(image.get_height()):
				clear_gutter = clear_gutter and image.get_pixel(0, y).a < 0.05 and image.get_pixel(image.get_width() - 1, y).a < 0.05
			_check(clear_gutter, "%s has transparent gutters around the complete frame" % role)
	_check(regions.size() == 12, "all twelve generated roles are represented in the enemy catalog")
	var separate_regions := true
	var roles := regions.keys()
	for first in range(roles.size()):
		for second in range(first + 1, roles.size()):
			separate_regions = separate_regions and not (regions[roles[first]] as Rect2).intersects(regions[roles[second]])
	_check(separate_regions, "role atlas regions do not overlap neighboring sprites")
	for name in ["Grunt", "Spitter"]:
		var spec := load("res://core/actors/enemy/EnemySpec_%s.tres" % name)
		_check(spec.visual_frames != null and spec.visual_frames.has_animation(&"idle_down"), "%s keeps its existing baked animation" % name)
	_check_actor_visuals()
	print("EnemyArtCatalogTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _check_actor_visuals() -> void:
	for name in ["Brute", "SummonedMinion"]:
		var actor := load("res://scenes/world/enemies/Enemy%s.tscn" % name).instantiate() as Node2D
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(actor)
		var sprite := actor.get_node("Sprite2D") as Sprite2D
		var spec: Resource = actor.get("spec")
		_check(sprite.texture is AtlasTexture and sprite.texture == spec.sprite_texture, "%s scene replaces its inherited placeholder with role art" % name)
		actor.free()
	for generation in range(3):
		var actor := load("res://scenes/world/enemies/EnemySplitter.tscn").instantiate() as Node2D
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.set_meta("split_generation", generation)
		root.add_child(actor)
		_check(actor.scale.is_equal_approx(Vector2.ONE * 2.0 * pow(0.5, generation)), "splitter generation %d keeps its authored parent scale" % generation)
		actor.free()


func _check_batch_filtering() -> void:
	var renderer := load("res://core/systems/enemy_world/EnemyProxyRenderer.gd").new() as Node2D
	root.add_child(renderer)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	# The resource path is the production distinction between the painted
	# sheet and the existing baked frames; pixel contents do not affect it.
	texture.take_over_path(ART_ROOT + "filter_fixture.png")
	var batch: Dictionary = renderer.call("_batch_for", &"painted_filter_fixture", {"texture": texture})
	var instance := batch.instance as MultiMeshInstance2D
	var shadow := renderer.get_node("CastShadow_painted_filter_fixture") as MultiMeshInstance2D
	_check(instance.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "painted enemy batches use linear filtering at normal gameplay size")
	_check(shadow.texture_filter == instance.texture_filter, "painted cast shadows use the same filter as their actors")
	var baked := load("res://assets/textures/characters/baked/grunt_atlas.png") as Texture2D
	batch = renderer.call("_batch_for", &"baked_filter_fixture", {"texture": baked})
	_check((batch.instance as MultiMeshInstance2D).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "existing baked/pixel characters keep nearest filtering")
	renderer.free()
