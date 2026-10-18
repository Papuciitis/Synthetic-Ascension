extends RefCounted
## Authored forms keep anatomy independent of equipment and collision shapes.
## Main-tier equipment and feet-anchored acting follow the committed brain.

const Acting := preload("res://scenes/world/bosses/BossActing.gd")
const PORTRAITS := {
	&"boss_bulldozer": "res://ui/boss/portraits/bulldozer_s10_portrait.tres",
	&"boss_arcanist": "res://ui/boss/portraits/arcanist_s10_portrait.tres",
}

const ART_ROOT := "res://scenes/world/bosses/art/forms/"
## The game places actor combat origins near mid-body. Follow the player's
## established feet offset so the visible body stays inside combat queries.
const FEET_OFFSET := Vector2(0, PlayerVisualController.FEET_BELOW_ORIGIN)
const PROFILES := {
	&"boss_bulldozer": [
		{"form": "bulldozer_s5_v1", "height": 88.0, "radius": 39.015, "hitbox": 78.03,
			"anatomy_rect": Rect2(250, 55, 705, 1202), "equipment_rect": Rect2(39, 55, 1112, 1202), "feet_anchor": Vector2(610, 1257)},
		{"form": "bulldozer_s10_v1", "height": 88.0, "radius": 44.795, "hitbox": 89.59,
			"anatomy_rect": Rect2(208, 111, 785, 1206), "equipment_rect": Rect2(32, 24, 1090, 1293), "feet_anchor": Vector2(595, 1317)},
	],
	&"boss_arcanist": [
		{"form": "arcanist_s5_v1", "height": 82.0, "radius": 36.72, "hitbox": 73.44,
			"anatomy_rect": Rect2(168, 110, 660, 1327), "equipment_rect": Rect2(168, 76, 744, 1361), "feet_anchor": Vector2(485, 1437)},
		{"form": "arcanist_s10_v1", "height": 86.0, "radius": 42.16, "hitbox": 84.32,
			"anatomy_rect": Rect2(146, 220, 740, 1257), "equipment_rect": Rect2(146, 10, 851, 1467), "feet_anchor": Vector2(500, 1477)},
	],
}


static func apply(actor: EnemyActor, tier: int) -> void:
	if actor == null or actor.spec == null or not PROFILES.has(actor.spec.id):
		return
	var normalized_tier := clampi(tier, 0, 1)
	var old_acting := actor.get_node_or_null("BossActing")
	if old_acting != null:
		actor.remove_child(old_acting)
		old_acting.free()
	var profile: Dictionary = PROFILES[actor.spec.id][normalized_tier]
	actor.scale = Vector2.ONE
	actor.set_meta(&"boss_visual_tier", normalized_tier)
	_set_footprint(actor, float(profile["radius"]), float(profile["hitbox"]))
	# Initial EnemyInit application precedes registration; an arena tier
	# application or later reconfiguration must update the same world handle.
	var handle := EnemyWorld.handle_for_actor(actor)
	if handle != 0:
		EnemyWorld.set_collision_radius(handle, float(profile["radius"]))
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var art_path := ART_ROOT + String(profile["form"]) + ".png"
	if not ResourceLoader.exists(art_path):
		return
	var texture := load(art_path) as Texture2D
	if texture == null:
		return
	var anatomy: Rect2 = profile["anatomy_rect"]
	var foot: Vector2 = profile["feet_anchor"]
	var factor := float(profile["height"]) / anatomy.size.y
	sprite.texture = texture
	sprite.region_enabled = false
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector2.ONE * factor
	sprite.position = FEET_OFFSET + (texture.get_size() * 0.5 - foot) * factor
	sprite.modulate = Color.WHITE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	actor.animator = null
	# Alpha >= 128 encloses visible equipment; a few alpha-1 export pixels
	# reach the canvas edge and are not anatomy or a meaningful gear envelope.
	# Crown/boot and equipment measurements were inspected independently.
	var gear: Rect2 = profile["equipment_rect"]
	actor.set_meta(&"boss_appearance", {
		"form_id": StringName(profile["form"]), "tier": normalized_tier,
		"anatomy_rect": anatomy, "equipment_rect": gear, "feet_anchor": foot,
		"feet_offset_world": FEET_OFFSET,
		"anatomy_height_world": float(profile["height"]),
		"equipment_bounds_world": Rect2(FEET_OFFSET + (gear.position - foot) * factor, gear.size * factor),
		"anatomy_bounds_world": Rect2(FEET_OFFSET + (anatomy.position - foot) * factor, anatomy.size * factor),
		"physical_radius": float(profile["radius"]), "contact_size": Vector2.ONE * float(profile["hitbox"]),
		"art_status": "equipped form with phase treatment and feet-anchored attack acting" if normalized_tier == 1 else "teaching proportion study",
	})
	if normalized_tier == 1:
		var acting := Acting.new()
		acting.name = "BossActing"
		actor.add_child(acting)
		acting.setup(actor, sprite)


static func portrait_for(actor: EnemyActor, tier: int, fallback: Texture2D = null) -> Texture2D:
	if tier != 1 or actor == null or actor.spec == null:
		return fallback
	var path: String = PORTRAITS.get(actor.spec.id, "")
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else fallback


static func _set_footprint(actor: EnemyActor, body_radius: float, contact_width: float) -> void:
	var body := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body != null and body.shape is CircleShape2D:
		var shape := body.shape.duplicate() as CircleShape2D
		shape.radius = body_radius
		body.shape = shape
	var contact := actor.get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	if contact != null and contact.shape is RectangleShape2D:
		var shape := contact.shape.duplicate() as RectangleShape2D
		shape.size = Vector2.ONE * contact_width
		contact.shape = shape
