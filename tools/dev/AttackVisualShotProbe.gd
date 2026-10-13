extends Node2D
## Frozen production effects over the game's paving and character art.
## -- --out=/absolute/folder --label=before|after [--flash=off|reduced|full]

const MELEE := preload("res://scenes/world/combat/MeleeSlash.tscn")
const MAGIC := preload("res://scenes/world/combat/MagicImpact.tscn")
const BULLET := preload("res://scenes/world/combat/RangedBullet.tscn")
const TESLA := preload("res://assets/vfx/world/augments/VFX_TeslaArc2D.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const ART := preload("res://core/systems/world/WorldArt.gd")
const FOLIAGE := preload("res://core/systems/world/chunks/ChunkFoliageRenderer.gd")
const ROLES := ["Grunt", "Brute", "Herald", "Spitter", "Charger", "Runner", "Sniper", "Bomber", "Summoner", "Orbiter", "Warden", "Leech"]
var _out := "user://attack_visual_probe"
var _label := "after"
var _flash := "full"
var _dress := false
var _enemy_renderer: EnemyProxyRenderer
var _block_renderer: ChunkBlockRenderer
var _role_index := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.trim_prefix("--out=")
		elif arg.begins_with("--label="): _label = arg.trim_prefix("--label=")
		elif arg.begins_with("--flash="): _flash = arg.trim_prefix("--flash=")
		elif arg == "--dress": _dress = true
	Global.debug_disable_autosave = true
	SaveManager.save_dir = "user://tests/attack_visual_probe/"
	SettingsManager.set_value(&"accessibility", &"combat_flash", _flash, false)
	StoryDirector.cards_override = 0
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	get_viewport().content_scale_size = Vector2i(1440, 900)
	ProjectileManager.set_process(false)
	ProjectileManager.clear_for_run_end()
	var ground := Sprite2D.new()
	ground.texture = ART.ground_texture(6)
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 4096, 2560)
	ground.scale = Vector2.ONE * float(ART.ground_repeat_world_px(6)) / float(ground.texture.get_width())
	ground.z_index = -100
	add_child(ground)
	_enemy_renderer = EnemyProxyRenderer.new()
	add_child(_enemy_renderer)
	_enemy_renderer.setup(EnemyWorld)
	if _dress: _dressing()
	for pair in [[Vector2(170, 240), "MELEE"], [Vector2(860, 240), "RANGED"], [Vector2(170, 625), "MAGIC"], [Vector2(860, 625), "CHAIN ARC"]]:
		var origin: Vector2 = pair[0]
		_actor(origin, false)
		_caption(origin + Vector2(-90, -130), pair[1])
		for offset in [Vector2(250, -42), Vector2(330, 76), Vector2(430, -50)]:
			_actor(origin + offset, true)
	var slash := MELEE.instantiate() as MeleeSlash
	slash.position = Vector2(170, 218)
	slash._seed = 17.0
	add_child(slash)
	slash.set_process(false)
	slash._t = slash.lifetime * 0.15
	slash._seed = 17.0
	slash.queue_redraw()
	var bullet := BULLET.instantiate() as RangedBullet
	bullet.position = Vector2(1020, 208)
	bullet.velocity = Vector2(700, 0)
	add_child(bullet)
	bullet.set_physics_process(false)
	var profile := HitProfileAdapter.new()
	profile.damage = 0.0
	profile.speed = 700.0
	profile.max_range = 900.0
	for at in [Vector2(1120, 235), Vector2(1250, 258)]:
		ProjectileManager.spawn_player(at, Vector2.RIGHT, profile, self)
	ProjectileManager._update_renderer()
	var impact := MAGIC.instantiate() as MagicImpact
	impact.position = Vector2(425, 593)
	impact._did_burst = true
	impact.radius = 82.0
	add_child(impact)
	impact.set_process(false)
	impact._t = impact.lifetime * 0.18
	impact._seed = 17.0
	impact.queue_redraw()
	var arc := TESLA.instantiate() as VFX_TeslaArc2D
	arc.setup_positions(Vector2(860, 600), Vector2(1110, 583), 0.1)
	add_child(arc)
	arc.set_process(false)
	arc._t = 0.008
	arc._flip = false
	arc.queue_redraw()
	var arc2 := TESLA.instantiate() as VFX_TeslaArc2D
	arc2.setup_positions(Vector2(1110, 583), Vector2(1290, 545), 0.1)
	add_child(arc2)
	arc2.set_process(false)
	arc2._t = 0.01
	arc2._flip = false
	arc2.queue_redraw()
	var burst := ImpactBurstRenderer.new()
	add_child(burst)
	burst.add_burst(Vector2(1290, 545))
	burst.set_process(false)
	burst._process(0.012)
	burst.set_process(false)
	_enemy_renderer.publish(1.0, false)
	_caption(Vector2(55, 38), "ATTACK STUDY / " + _label.to_upper(), 24)
	_caption(Vector2(55, 78), "Production effects at a fixed instant / combat flash: " + _flash, 16)
	for _frame in range(6): await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_out)
	var path := _out.path_join("attacks_" + _label + "_" + _flash + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("AttackVisualShotProbe -> ", path, " (", err, ")")
	ProjectileManager.clear_for_run_end()
	get_tree().quit(err)

func _actor(at: Vector2, enemy: bool) -> void:
	if enemy:
		var actor := ENEMY.instantiate() as EnemyActor
		actor.position = at
		var role: String = ROLES[_role_index % ROLES.size()] if _dress else "Grunt"
		_role_index += 1
		actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % role)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(actor)
		var sprite := actor.get_node("Sprite2D") as Sprite2D
		_enemy_renderer.register_actor(actor, sprite)
		sprite.visible = false
	else:
		# Use the production visual/shadow controller without player input,
		# camera or combat components interfering with this frozen comparison.
		var scene := PLAYER.instantiate()
		var visual := scene.get_node("Visual") as PlayerVisualController
		scene.remove_child(visual)
		scene.free()
		var holder := Node2D.new()
		holder.position = at - Vector2(0, 14)
		holder.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(visual)
		add_child(holder)
		visual.set_preview(PlayerVisualController.State.IDLE, &"down")
		visual._process(0.0)
		visual.breath.stop()
		visual.body.frame = 0
		visual.head.frame = 0
		visual._apply()

func _dressing() -> void:
	var chunk := Node2D.new()
	chunk.name = "CourtyardDressing"
	add_child(chunk)
	var placements: Array[Dictionary] = []
	for cell in [Vector2i(0, 5), Vector2i(9, 6), Vector2i(22, 5), Vector2i(0, 11), Vector2i(11, 12), Vector2i(21, 12), Vector2i(12, 3)]:
		placements.append({"cell": cell, "species": 0, "scale": 0.9, "alpha": 1.0})
	for cell in [Vector2i(1, 7), Vector2i(11, 6), Vector2i(21, 7), Vector2i(6, 12)]:
		placements.append({"cell": cell, "species": 1, "scale": 1.0, "alpha": 1.0})
	FOLIAGE.add_to_chunk(chunk, placements, 64, Color.WHITE)
	var data := ChunkBuildData.new(Vector2i.ZERO, 24)
	for pair in [[Vector2i(7, 6), 0], [Vector2i(19, 6), 2], [Vector2i(2, 12), 6], [Vector2i(19, 12), 7]]:
		data.add_blocker(pair[0], WorldBlockerGeometry.Kind.HALF_COVER, 0, pair[1])
	# Courtyard boundary uses the production shaded wall kit and batching.
	for x in range(3, 19):
		data.add_blocker(Vector2i(x, 13), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E | WorldBlockerGeometry.W)
	_block_renderer = ChunkBlockRenderer.new()
	_block_renderer.configure(chunk, 1536, 64)
	_block_renderer.add_chunk(data)

func _caption(at: Vector2, text_value: String, size: int = 18) -> void:
	var label := Label.new()
	label.position = at
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 0.91, 0.71))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
