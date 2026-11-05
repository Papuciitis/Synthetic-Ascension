extends Node
## Small native material fixture; NOT Game/S7 layout, traversal or cost acceptance.
const CURRENT = preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const BASELINE = preload("res://core/systems/world/ground/BaselineGroundSplatRenderer.gd")
const PLANNER = preload("res://core/systems/world/ground/CityYardSupport.gd")
const COORD := Vector2i(-2,3)
const SEED_VALUE := 944996572
const N := 32
const SIZE := 512
var passes := 0
var failures := 0
var pixels := {}
var current: Node2D
var baseline: Node2D
var current_view: SubViewport
var baseline_view: SubViewport
var controls := {}
var out: String

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passes += 1
		print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func spec() -> Dictionary:
	return {"footprint_px": PackedVector2Array([Vector2(512,512),Vector2(1152,512),Vector2(1152,1152),Vector2(512,1152)]),
		"doors":[{"pos":Vector2i(12,17),"dir":Vector2i.DOWN,"width":2}],
		"garden_contact_px":Vector2(512,1152),"visual_seed":SEED_VALUE}

func viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(SIZE,SIZE)
	view.disable_3d = true
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Both separate worlds sample IDENTICAL global world coordinates.
	var scale_value := float(SIZE)/float(N*64)
	view.canvas_transform = Transform2D(Vector2(scale_value,0),Vector2(0,scale_value),-Vector2(COORD*N*64)*scale_value)
	add_child(view)
	return view

func prepare(renderer: Node2D) -> void:
	renderer.configure(64,N)
	renderer.set_ground_family(&"underpass_veins")
	renderer.set_chunk_base(COORD,6)
	for label in controls:
		var entry: Dictionary = controls[label]
		var cell: Vector2i = entry.cell
		if entry.material != 6:
			renderer.paint_rect(Rect2i(COORD*N+cell,Vector2i.ONE),entry.material,1.0)
		else:
			renderer.paint_planting(COORD,Rect2i(cell,Vector2i.ONE))
	renderer.flush()

func frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(view: SubViewport, name_value: String) -> Image:
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	check(image.get_size() == Vector2i(SIZE,SIZE), name_value + " readback dimensions")
	check(image.save_png(out.path_join(name_value + ".png")) == OK, name_value + " original PNG saved")
	return image

func changed(a: Image, b: Image, region: Rect2i = Rect2i(0,0,SIZE,SIZE)) -> int:
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
	return count

func _run() -> void:
	out = ProjectSettings.globalize_path("res://").path_join("..")
	var field := PLANNER.plan(COORD,spec(),64,N)
	var positive: Array[int] = []
	for i in field.size():
		if field[i] > 60: positive.append(i)
	check(positive.size() > 12, "real footprint planner yields enough potential cells for controls")
	var kinds := {"road":7,"lane":4,"footway":2,"courtyard":8,"indoor":9,"care":6}
	var k := 0
	for label in kinds:
		var index: int = positive[k*positive.size()/kinds.size()]
		controls[label] = {"cell":Vector2i(index%N,index/N),"material":kinds[label]}
		k += 1
	baseline_view = viewport()
	current_view = viewport()
	baseline = BASELINE.new()
	current = CURRENT.new()
	baseline_view.add_child(baseline)
	current_view.add_child(current)
	prepare(baseline)
	prepare(current)
	check(baseline.get_shader_material().shader != current.get_shader_material().shader, "baseline binds separately pinned original shader resource")
	check(baseline.get_shader_material().shader.code == current.get_shader_material().shader.code, "default current shader source equals original d7cfb52f source")
	check(current.get_shader_material().get_shader_parameter("materials").get_layers() == 14, "native fixture loads actual fourteen-layer material cache")
	await frame()
	var before := capture(baseline_view,"original-before")
	var off := capture(current_view,"default-off")
	pixels.default_off_changed = changed(before,off)
	check(pixels.default_off_changed == 0, "default-off native RGBA equals original at identical world coordinates")
	check(current.configure_yard_support_preview(true,COORD,SEED_VALUE), "explicit S7 preview activates natively")
	current.flush()
	await frame()
	var empty := capture(current_view,"enabled-empty")
	pixels.enabled_empty_changed = changed(before,empty)
	check(pixels.enabled_empty_changed == 0, "enabled-empty native RGBA equals original")
	var specs: Array[Dictionary] = [spec()]
	current.paint_yard_support(COORD,specs)
	current.flush()
	await frame()
	var after := capture(current_view,"preview-after")
	var signature: PackedByteArray = current.yard_support_signature(COORD)
	pixels.positive_yard_changed = 0
	pixels.zero_mask_changed = 0
	pixels.alpha_changed = 0
	for y in SIZE:
		for x in SIZE:
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if a.a != b.a: pixels.alpha_changed += 1
			if a != b:
				if signature[(y/16)*N+x/16] > 0: pixels.positive_yard_changed += 1
				else: pixels.zero_mask_changed += 1
	check(pixels.positive_yard_changed > 0, "real mask changes positive yard pixels using actual art")
	check(pixels.zero_mask_changed == 0 and pixels.alpha_changed == 0, "zero-centre controls and alpha remain byte-identical")
	pixels.controls = {}
	for label in controls:
		var cell: Vector2i = controls[label].cell
		pixels.controls[label] = changed(before,after,Rect2i(cell*16,Vector2i(16,16)))
		check(pixels.controls[label] == 0, "native control unchanged: " + label)
	var generated := FileAccess.open(out.path_join("generated-yard-support.gdshader"),FileAccess.WRITE)
	generated.store_string(current.get_shader_material().shader.code)
	generated.close()
	current.get_shader_material().set_shader_parameter("debug_view",3)
	await frame()
	capture(current_view,"mask-debug3")
	current.get_shader_material().set_shader_parameter("debug_view",0)
	# Apply care after preview to a positive cell, then replace that care with
	# index6 floor: stale mask must never revive in either state.
	var late := Vector2i.ZERO
	var late_found := false
	for i in signature.size():
		if signature[i] > 100:
			late = Vector2i(i%N,i/N)
			late_found = true
			break
	check(late_found, "late-care fixture selected a real positive support cell")
	baseline.paint_planting(COORD,Rect2i(late,Vector2i.ONE))
	current.paint_planting(COORD,Rect2i(late,Vector2i.ONE))
	baseline.flush()
	current.flush()
	await frame()
	var care_original := capture(baseline_view,"original-late-care")
	var care_preview := capture(current_view,"preview-late-care")
	pixels.late_care_changed = changed(care_original,care_preview,Rect2i(late*16,Vector2i(16,16)))
	check(pixels.late_care_changed == 0, "care painted after preview retains original native cell pixels")
	baseline.paint_rect(Rect2i(COORD*N+late,Vector2i.ONE),6,1.0)
	current.paint_rect(Rect2i(COORD*N+late,Vector2i.ONE),6,1.0)
	baseline.flush()
	current.flush()
	await frame()
	var floor_original := capture(baseline_view,"original-late-floor")
	var floor_preview := capture(current_view,"preview-late-floor")
	pixels.late_floor_changed = changed(floor_original,floor_preview,Rect2i(late*16,Vector2i(16,16)))
	check(pixels.late_floor_changed == 0, "floor replacing later care cannot revive stale preview pixels")
	current.configure_yard_support_preview(false,COORD,SEED_VALUE)
	current.flush()
	await frame()
	var disabled := capture(current_view,"disabled-restored")
	pixels.disabled_changed = changed(floor_original,disabled)
	check(pixels.disabled_changed == 0, "disable restores original native RGBA after painted preview")
	current.configure_yard_support_preview(true,COORD,SEED_VALUE)
	current.clear()
	baseline.clear()
	prepare(current)
	prepare(baseline)
	await frame()
	var reset_original := capture(baseline_view,"original-reset")
	var reset := capture(current_view,"enabled-reset")
	pixels.reset_changed = changed(reset_original,reset)
	check(pixels.reset_changed == 0, "enabled world reset equals original native RGBA")
	var receipt := FileAccess.open(out.path_join("native-pixels.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"fixture_only":true,"world_coord":COORD,"visual_seed":SEED_VALUE,"viewport":SIZE,"pixels":pixels,"controls":controls,"passes":passes,"failures":failures},"\t"))
	receipt.close()
	baseline_view.queue_free()
	current_view.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	CURRENT.release_static_caches()
	BASELINE.release_static_caches()
	preload("res://core/systems/world/WorldArt.gd").release_static_caches()
	print("YardSupportNativeTest: %d passed, %d failed" % [passes,failures])
	get_tree().quit(1 if failures else 0)
