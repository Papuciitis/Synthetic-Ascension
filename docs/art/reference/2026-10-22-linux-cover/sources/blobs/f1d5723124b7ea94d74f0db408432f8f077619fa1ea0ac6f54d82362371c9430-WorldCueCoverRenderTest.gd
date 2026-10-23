extends Node2D
## Native RED on real remaining draw owners. A transparent roof host retains
## its actual coverage union, so raw consumer RGBA can be compared directly.

const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const PROJECTILES := preload("res://core/combat/projectile/ProjectileSimulationManager.gd")
const TEXT := preload("res://core/combat/BattleTextRenderer.gd")
const PICKUP_VFX := preload("res://scenes/world/pickups/PickupVfx.gd")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const SHIELD := preload("res://core/actors/enemy/FrontShieldVisual.gd")
var _passes := 0
var _failures := 0
var _view: SubViewport
var _world: Node2D
var _roof: RoofOverlay
var _cover: Node


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _pixels(alpha: float) -> Image:
	_roof._set_alpha(alpha)
	_cover.call("refresh",_world,true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _view.get_texture().get_image()


func _probe(label: String, rect: Rect2i, feet_y: float = 200.0, ground_points: bool = true, front_control: bool = false) -> void:
	var clear := await _pixels(0.0)
	var covered := await _pixels(1.0)
	var restored := await _pixels(0.0)
	var hidden_count := 0
	var changed_count := 0
	var exposed_count := 0
	var exposed_delta := 0.0
	var restore_delta := 0.0
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var a := clear.get_pixel(x,y)
			if a.a < 0.10: continue
			var b := covered.get_pixel(x,y)
			var c := restored.get_pixel(x,y)
			var point := Vector2(x+0.5,y+0.5)
			var within_face := point.x >= 128.0 and point.x < 640.0 and point.y >= 32.0 and point.y < 432.0
			var behind := (point.y if ground_points else feet_y) < 432.0
			var delta := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),maxf(absf(a.b-b.b),absf(a.a-b.a))))
			restore_delta = maxf(restore_delta,maxf(absf(a.r-c.r),maxf(absf(a.g-c.g),maxf(absf(a.b-c.b),absf(a.a-c.a)))))
			if within_face and behind and not front_control:
				hidden_count += 1
				if delta > 0.045: changed_count += 1
			else:
				exposed_count += 1
				exposed_delta = maxf(exposed_delta,delta)
	if not front_control:
		_check(hidden_count > 8,label+" renders actual pixels behind the cover edge")
		_check(changed_count > int(hidden_count*0.70),label+" covered pixels receive quiet depth presentation (%d/%d)" % [changed_count,hidden_count])
	_check(exposed_count > 8 and exposed_delta < 0.035,label+" exposed/front-depth pixels retain authored presentation")
	_check(restore_delta < 0.035,label+" actual cutaway restores current presentation")
	print("WorldCueCoverRenderTest probe=%s hidden=%d changed=%d exposed=%d delta=%.4f restored=%.4f" % [label,hidden_count,changed_count,exposed_count,exposed_delta,restore_delta])


func _retire(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WorldCueCoverRenderTest requires native Compatibility rendering")
		get_tree().quit(2)
		return
	AudioManager.stop_all(true)
	var prior_batching := Global.debug_enemy_visual_batching
	var prior_rng := Global._rng.state
	var prior_scheduler := EnemySimulationScheduler.is_physics_processing()
	Global.debug_enemy_visual_batching = false
	EnemySimulationScheduler.set_physics_process(false)
	_view = SubViewport.new()
	_view.size = Vector2i(768,512)
	_view.transparent_bg = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_world = Node2D.new()
	_view.add_child(_world)
	_roof = ROOF.instantiate() as RoofOverlay
	_world.add_child(_roof)
	_roof.footprint_outline_px = PackedVector2Array([Vector2(128,0),Vector2(640,0),Vector2(640,432),Vector2(128,432)])
	var poly := _roof.get_node("RoofPoly") as Polygon2D
	poly.polygon = PackedVector2Array([Vector2(128,32),Vector2(640,32),Vector2(640,432),Vector2(128,432)])
	poly.color = Color(1,1,1,0) # Exact same authoritative host used by fitted roofs.
	(_roof.get_node("FrontEdge") as CanvasItem).hide()
	_cover = COVER.get_for(_world)
	_cover.call("refresh",_world,true)
	_check(float(_cover.call("strength_at",Vector2(200,200),200.0)) > 0.99,"transparent duplicate host retains actual opaque shared cover")
	var point := Vector2(110,200)
	var rect := Rect2i(32,100,300,200)
	var holder := Node2D.new()
	holder.position = point
	_world.add_child(holder)
	var shot := VFX_EnemyShotWindup.new()
	holder.add_child(shot)
	shot.configure(&"enemy_spitter")
	shot.show_progress(0.8,Vector2.RIGHT)
	await _probe("shooter windup",rect)
	await _retire(holder)
	var charge := VFX_ChargeWindup.new()
	charge.position = point
	charge.setup(Vector2.RIGHT,10.0)
	_world.add_child(charge)
	charge.set_process(false)
	charge.set("_t",8.0)
	charge.queue_redraw()
	await _probe("charge fan",rect)
	await _retire(charge)
	var herald := VFX_HeraldPulseRing.new()
	_world.add_child(herald)
	herald.setup(point,64)
	herald.set_process(false)
	herald.set("_t",0.1)
	herald.queue_redraw()
	await _probe("herald ground ring",rect)
	await _retire(herald)
	var shield := SHIELD.new()
	shield.position = point
	_world.add_child(shield)
	shield.sync(Vector2.RIGHT,true,1.4)
	await _probe("warden shield frame",rect,point.y,false)
	await _retire(shield)
	var pickup := PICKUP_VFX.new()
	pickup.position = point
	_world.add_child(pickup)
	var icon := Sprite2D.new()
	pickup.add_child(icon)
	pickup.bind_icon(icon)
	pickup.set_locked(true)
	pickup.set_exploration(true)
	pickup.set_process(false)
	await _probe("pickup lock/exploration frames",rect,point.y,false)
	await _retire(pickup)
	await _projectile_probes(rect)
	await _sniper_probe(rect)
	await _text_probes()
	await _fallback_probes()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	EnemySimulationScheduler.set_physics_process(prior_scheduler)
	Global.debug_enemy_visual_batching = prior_batching
	Global._rng.state = prior_rng
	print("WorldCueCoverRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _projectile_probes(rect: Rect2i) -> void:
	var manager := PROJECTILES.new()
	_world.add_child(manager)
	manager.set_process(false)
	manager.set_physics_process(false)
	var source := Node2D.new()
	_world.add_child(source)
	for family: String in ["native","needle","tracer","enemy"]:
		manager.clear_for_run_end()
		if family == "enemy": manager.spawn_enemy(Vector2(128,200),Vector2.RIGHT,100,1,20,source,&"enemy_spitter")
		else:
			var profile := HitProfileAdapter.new()
			profile.damage = 1.0
			profile.speed = 100.0
			profile.max_range = 1000.0
			var tags := AscensionTags.native("ranged","bullet")
			if family == "needle": tags = AscensionTags.make("ranged",AscensionTags.FAMILY_TREE,"PR02","bullet",1,0.6)
			elif family == "tracer": tags = AscensionTags.make("ranged",AscensionTags.FAMILY_TREE,"BR05","fragment",1,0.4)
			profile.set_meta("asc_tags",tags)
			manager.spawn_player(Vector2(128,200),Vector2.RIGHT,profile,source)
		manager._update_renderer()
		var before := manager.active_count()
		await _probe("batched projectile "+family,rect,200,false)
		_check(manager.active_count() == before,"presentation preserves "+family+" projectile simulation count")
	manager.clear_for_run_end()
	await _retire(manager)
	await _retire(source)


func _text_probes() -> void:
	var text := TEXT.new() as Node2D
	_world.add_child(text)
	text.call("popup",Vector2(140,300),"COVER",Color.WHITE,1.0,0)
	text.set_process(false)
	await _probe("pooled world callout",Rect2i(60,235,200,80),300,false)
	text.call("clear")
	text.call("popup",Vector2(300,440),"FRONT",Color.WHITE,1.0,0)
	text.set_process(false)
	await _probe("front owner's raised callout",Rect2i(220,375,200,80),440,false,true)
	text.call("clear")
	# Nearby physical owners may share one visual column while straddling a
	# roof front. The lower row must retain the second owner's birth depth.
	var prior_motion := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	text.call("popup",Vector2(140,420),"BACK",Color.WHITE,1.0,0)
	text.call("popup",Vector2(140,444),"FRONT",Color.WHITE,1.0,0)
	text.set_process(false)
	var extent: Vector2 = text.call("drawn_extent",1)
	await _probe("shared visual column preserves front birth depth",Rect2i(60,ceili(extent.x),200,floori(extent.y)-ceili(extent.x)),444,false,true)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", prior_motion, false)
	text.call("clear")
	await _retire(text)


func _sniper_probe(rect: Rect2i) -> void:
	var owner := ENEMY.instantiate() as EnemyActor
	owner.spec = EnemySpec.new()
	owner.position = Vector2(700,480)
	_world.add_child(owner)
	owner.set_physics_process(false)
	owner._sniper._ensure_telegraph()
	var line := owner._sniper.get("_tele") as Line2D
	# The production sniper intentionally adds its three world lines to the
	# current root scene. Relocate those actual owners into this isolated
	# viewport; SceneTree.current_scene itself must remain a root child.
	line.reparent(_world)
	line.points = PackedVector2Array([Vector2(64,200),Vector2(320,200)])
	for key: String in ["_glow_id","_mark_id"]:
		var extra := instance_from_id(int(line.get_meta(key))) as Line2D
		extra.reparent(_world)
		extra.points = line.points
	# Reapply the actual owner's attachment after an explicit viewport move;
	# sharing one material between two viewport services would be invalid.
	if owner._sniper.has_method("_bind_telegraph_cover"):
		owner._sniper.call("_bind_telegraph_cover")
	await _probe("sniper telegraph and additive layers",rect)
	owner._sniper.cleanup()
	await _retire(owner)


func _fallback_probes() -> void:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.position = Vector2(128,200)
	_world.add_child(actor)
	actor.set_physics_process(false)
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.9,0.8,0.5,1))
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.modulate = Color.WHITE
	var rect := Rect2i(112,184,32,32)
	await _probe("ordinary fallback sprite",rect,216,false)
	# Compare static presentation through the real accessibility path; a
	# TIME-driven glint may legitimately move between raw readbacks.
	var prior_motion := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	actor._apply_elite_surface()
	await _probe("elite fallback sprite",rect,216,false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", prior_motion, false)
	actor._clear_elite_surface()
	actor.position = Vector2(128,400)
	var atlas := Image.create(64,64,false,Image.FORMAT_RGBA8)
	atlas.fill(Color(0.9,0.8,0.5,1))
	sprite.texture = ImageTexture.create_from_image(atlas)
	# Texture change first records a 64px frame, whose feet are exactly at
	# the front edge. A real atlas region then makes the frame 32px tall and
	# puts its feet behind the edge, without changing the texture or frame ID.
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0,0,32,32)
	await _probe("fallback resized atlas region contact",Rect2i(112,384,32,32),416,false)
	actor.position = Vector2(128,420)
	await _probe("front fallback with raised pixels over roof",Rect2i(112,404,32,32),436,false,true)
	await _retire(actor)
