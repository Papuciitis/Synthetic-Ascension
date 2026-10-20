extends "res://tools/tests/WorldCueCoverRenderTest.gd"
## Remaining genuine secondary draw owners, separated from the first native
## probe so their untouched presentation produces an independent RED.
const BLAST := preload("res://assets/vfx/world/enemies/VFX_BomberBlast.gd")
const IMPACTS := preload("res://core/combat/projectile/ImpactBurstRenderer.gd")
const NODE_BOLT := preload("res://core/combat/projectile/EnemyProjectile.tscn")

func _probe(label: String, rect: Rect2i, feet_y: float = 200.0, ground_points: bool = true, front_control: bool = false) -> void:
	if "--only-node" in OS.get_cmdline_user_args() and not label.begins_with("ordinary node"):
		return
	await super._probe(label, rect, feet_y, ground_points, front_control)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WorldCueAdditionalRenderTest requires native Compatibility rendering")
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
	var prior_motion := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var point := Vector2(128,200)
	var rect := Rect2i(32,100,300,200)
	var cone := VFX_EnemyShootCone.new()
	_world.add_child(cone)
	cone.setup(point - Vector2(18,0),Vector2.RIGHT,80,0.6,10,Color.WHITE,Color.ORANGE)
	cone.set_process(false)
	await _probe("shooter ground cone",rect)
	await _retire(cone)
	var muzzle := VFX_EnemyMuzzleFlash.new()
	_world.add_child(muzzle)
	muzzle.setup(point - Vector2(18,0),Vector2.RIGHT,&"enemy_spitter")
	muzzle.set_process(false)
	await _probe("shooter muzzle flash",rect)
	await _retire(muzzle)
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_Bomber.tres") as EnemySpec
	actor.position = point
	_world.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	# Isolate secondary owners from the already-tested body and hitbox paint.
	for child: Node in actor.get_children():
		if child is CanvasItem: (child as CanvasItem).hide()
	var ring := VFX_BomberHazardRing.new()
	ring.setup(actor)
	actor.add_child(ring)
	ring.set_process(false)
	ring.set("_r",80.0)
	actor._bomber.set("_fuse_left",0.2)
	ring._update_sprites()
	await _probe("bomber actual perimeter and fuse",rect)
	ring.get("_perimeter").hide()
	await _probe("bomber actual fuse separately",Rect2i(95,155,70,70),point.y,false)
	actor.position.y = 440
	ring._update_sprites()
	await _probe("front bomber owner raised fuse",Rect2i(95,395,70,50),440,false,true)
	actor.position = point
	await _retire(ring)
	for id_list: Array in [[EliteModifiers.ARMOURED,EliteModifiers.SHIELDED,EliteModifiers.FAST],[EliteModifiers.VAMPIRIC,EliteModifiers.SPLITTING]]:
		var ids: Array[StringName] = []
		ids.assign(id_list)
		var mark := VFX_EliteModifierMark.new()
		mark.setup(actor,ids,Color.WHITE)
		actor.add_child(mark)
		mark.set_process(false)
		await _probe("elite secondary marks "+str(ids),rect,point.y,false)
		await _retire(mark)
	await _retire(actor)
	var blast := BLAST.new() as Node2D
	blast.call("setup",point,80.0)
	_world.add_child(blast)
	blast.set_process(false)
	await _probe("bomber actual blast",rect)
	await _retire(blast)
	var impact := IMPACTS.new() as ImpactBurstRenderer
	_world.add_child(impact)
	impact.add_burst(point)
	impact._process(0.04)
	impact.set_process(false)
	await _probe("batched impact emission",rect,point.y,false)
	await _retire(impact)
	var bolt := NODE_BOLT.instantiate() as EnemyProjectile
	bolt.position = point + Vector2(4,0)
	bolt.setup(Vector2.RIGHT,320,1,20)
	_world.add_child(bolt)
	bolt.set_process(false)
	bolt.set_physics_process(false)
	await _probe("ordinary node projectile emission",rect,point.y,false)
	await _retire(bolt)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", prior_motion, false)
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	EnemySimulationScheduler.set_physics_process(prior_scheduler)
	Global.debug_enemy_visual_batching = prior_batching
	Global._rng.state = prior_rng
	print("WorldCueAdditionalRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
