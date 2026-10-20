extends Node2D
## Exact snapshot reuse must remove redundant packing/uploads while preserving
## same-frame alpha, geometry, streaming, camera and new-consumer semantics.

const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const CONSUMER_SHADER := preload("res://core/systems/world/visibility/pickup_cover.gdshader")
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ",message)
	else:
		_failed += 1
		push_error("FAIL: "+message)


func _stats(cover: Node) -> Dictionary:
	return cover.call("snapshot_stats") as Dictionary


func _run() -> void:
	var cover := COVER.get_for(self)
	cover.set_process(false)
	var initial := _stats(cover)
	if not initial.has("snapshot_builds") or not initial.has("data_uploads") or not initial.has("snapshot_reuses") or not initial.has("material_binds"):
		_check(false,"shared cover exposes exact snapshot/upload/reuse/material-bind counters before its refresh work can be bounded")
		cover.queue_free()
		await get_tree().process_frame
		_finish()
		return
	var original_canvas := get_viewport().canvas_transform
	var parent := Node2D.new()
	add_child(parent)
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(100,100),Vector2(180,100),Vector2(180,180),Vector2(100,180)])
	face.add_to_group(&"foreground_solid_occluders")
	face.set_meta(FOREGROUND.GROUND_CONTACT,Vector2(140,240))
	parent.add_child(face)
	var material := ShaderMaterial.new()
	material.shader = CONSUMER_SHADER
	cover.call("bind_material",material)
	cover.call("refresh",self,true)
	var first := _stats(cover)
	_check(int(first.data_uploads)-int(initial.data_uploads) == 3,"first actual masonry snapshot uploads exactly its three data textures")
	_check(float(cover.call("strength_at",Vector2(140,140),200.0)) > .99,"first snapshot retains actual masonry coverage")
	cover.call("refresh",self,true)
	var reused := _stats(cover)
	_check(int(reused.snapshot_builds) == int(first.snapshot_builds) and int(reused.snapshot_reuses) == int(first.snapshot_reuses)+1,"unchanged forced collection reuses the exact packed snapshot")
	_check(int(reused.data_uploads) == int(first.data_uploads),"unchanged coverage performs zero additional data uploads")
	_check(int(reused.material_binds) == int(first.material_binds),"unchanged snapshot does not rebind persistent consumers")
	parent.modulate.a = .5
	cover.call("refresh",self,true)
	var faded := _stats(cover)
	_check(is_equal_approx(float(cover.call("strength_at",Vector2(140,140),200.0)),.5),"a same-frame inherited fade reaches current coverage without throttling")
	_check(int(faded.data_uploads) == int(reused.data_uploads)+3,"changed live alpha uploads its current snapshot immediately")
	if DisplayServer.get_name() != "headless":
		# Focused test readback only. The live profiling tool never does this.
		var uploaded_texture := material.get_shader_parameter("world_cover_data") as ImageTexture
		var uploaded: Image = uploaded_texture.get_image() if uploaded_texture != null else null
		_check(uploaded != null and is_equal_approx(uploaded.get_pixel(0,0).g,.5),"native current data texture contains the changed fractional strength")
	parent.modulate.a = 1.0
	face.position.x = 8.0
	cover.call("refresh",self,true)
	var moved := _stats(cover)
	_check(int(moved.snapshot_builds) == int(faded.snapshot_builds)+1 and is_zero_approx(float(cover.call("strength_at",Vector2(104,140),200.0))),"a transformed face invalidates reuse and removes its old pixels")
	get_viewport().canvas_transform = Transform2D(0.0,Vector2(-32,0))*original_canvas
	cover.call("refresh",self,true)
	var small_pan := _stats(cover)
	_check(int(small_pan.data_uploads) == int(moved.data_uploads),"camera movement within unchanged grid and record bounds reuses the same world snapshot")
	get_viewport().canvas_transform = Transform2D(0.0,Vector2(-512,0))*original_canvas
	cover.call("refresh",self,true)
	var large_pan := _stats(cover)
	_check(int(large_pan.snapshot_builds) == int(small_pan.snapshot_builds)+1,"camera movement changing grid origin rebuilds its world index")
	_check(material.get_shader_parameter("world_cover_origin") == cover.get("_origin"),"camera grid-origin change reaches the already bound material")
	get_viewport().canvas_transform = original_canvas
	cover.call("refresh",self,true)
	var before_late := _stats(cover)
	var late := ShaderMaterial.new()
	late.shader = CONSUMER_SHADER
	cover.call("bind_material",late)
	_check(late.get_shader_parameter("world_cover_grid") == cover.get("_grid") and late.get_shader_parameter("world_cover_enabled") == true,"a new consumer receives the current snapshot immediately")
	var after_late := _stats(cover)
	_check(int(after_late.material_binds) == int(before_late.material_binds)+1,"new-consumer binding is counted independently of a snapshot rebuild")
	var weak_late: WeakRef = weakref(late)
	late = null
	cover.call("refresh",self,true)
	_check(weak_late.get_ref() == null and int(_stats(cover).materials) == int(before_late.materials),"reuse prunes a dead consumer without retaining its material")
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector2(260,140)
	parent.add_child(sprite)
	FOREGROUND.register(sprite,Vector2(260,240))
	var before_sprite := _stats(cover)
	cover.call("refresh",self,true)
	_check(int(_stats(cover).snapshot_builds) == int(before_sprite.snapshot_builds)+1 and float(cover.call("strength_at",Vector2(260,140),200.0)) > .99,"streamed foreground appearance updates current geometry and alpha binding")
	var sprite_snapshot := _stats(cover)
	cover.call("refresh",self,true)
	_check(int(_stats(cover).data_uploads) == int(sprite_snapshot.data_uploads) and int(_stats(cover).snapshot_reuses) == int(sprite_snapshot.snapshot_reuses)+1,"unchanged sprite semantic coverage reuses despite its newly allocated descriptor WeakRef")
	var before_texture := _stats(cover)
	sprite.texture = ImageTexture.create_from_image(image)
	cover.call("refresh",self,true)
	_check(int(_stats(cover).snapshot_builds) == int(before_texture.snapshot_builds)+1 and int(_stats(cover).alpha_uploads) == int(before_texture.alpha_uploads)+1,"a replacement original texture invalidates semantic identity and its bound alpha array")
	sprite.position.x += 20.0
	cover.call("refresh",self,true)
	_check(is_zero_approx(float(cover.call("strength_at",Vector2(260,140),200.0))) and float(cover.call("strength_at",Vector2(280,140),200.0)) > .99,"live sprite movement invalidates cached packed coordinates")
	face.visible = false
	sprite.visible = false
	cover.call("refresh",self,true)
	_check(int(_stats(cover).primitive_count) == 0 and material.get_shader_parameter("world_cover_enabled") == false,"cutaway/hidden owners clear existing consumer coverage immediately")
	var empty := _stats(cover)
	cover.call("refresh",self,true)
	_check(int(_stats(cover).data_uploads) == int(empty.data_uploads),"unchanged empty coverage also avoids redundant uploads")
	var before_control := _stats(cover)
	cover.set_meta(COVER.FORCE_UPLOAD_META,true)
	cover.call("refresh",self,true)
	cover.call("refresh",self,true)
	var control := _stats(cover)
	_check(int(control.data_uploads) == int(before_control.data_uploads)+6 and int(control.snapshot_builds) == int(before_control.snapshot_builds)+2,"same-source forced-upload control reproduces three actual data uploads per refresh")
	cover.set_meta(COVER.FORCE_UPLOAD_META,false)
	cover.call("refresh",self,true)
	_check(int(_stats(cover).data_uploads) == int(control.data_uploads),"leaving forced-upload control resumes exact snapshot reuse immediately")
	parent.queue_free()
	await get_tree().process_frame
	cover.call("refresh",self,true)
	_check(int(_stats(cover).primitive_count) == 0,"unloaded hidden owners cannot revive stale coverage")
	get_viewport().canvas_transform = original_canvas
	cover.queue_free()
	material = null
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("WorldCoverSnapshotReuseTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
