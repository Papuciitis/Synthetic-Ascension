extends Node
## CPU-only provider comparison on one composed, static fixture. No Game budget
## claim. Use --release-marker=COVER_COST_READY in the guarded launcher so setup
## duty limiting ends before warm-up and measured refreshes.

const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
var _roof_count := 56
var _face_count := 94
var _rounds := 5
var _frames := 48
var _output := ""
var _specs: Array[Dictionary] = []

func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--roofs="): _roof_count = clampi(int(arg.trim_prefix("--roofs=")),4,120)
		elif arg.begins_with("--faces="): _face_count = clampi(int(arg.trim_prefix("--faces=")),6,2000)
		elif arg.begins_with("--rounds="): _rounds = clampi(int(arg.trim_prefix("--rounds=")),1,10)
		elif arg.begins_with("--frames="): _frames = clampi(int(arg.trim_prefix("--frames=")),10,200)
		elif arg.begins_with("--json="): _output = arg.trim_prefix("--json=")
		elif arg.begins_with("--provider="):
			var parts := arg.trim_prefix("--provider=").split("=",true,1)
			if parts.size() == 2: _specs.append({"name":parts[0],"path":parts[1]})
	if _specs.is_empty(): _specs.append({"name":"current","path":"res://core/systems/world/visibility/WorldCover.gd"})

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 30
	Global.attempt_segment = 2
	var world := Node2D.new()
	add_child(world)
	var forms := 0
	var slate := KIT._texture("slate.png")
	for index in _roof_count:
		var roof := ROOF.instantiate() as RoofOverlay
		world.add_child(roof)
		roof.position = Vector2(200+(index%4)*500,200) if index < 4 else Vector2(6000+(index%8)*700,(index/8)*600)
		roof.configure(Rect2i(0,0,7,5),64,Vector2i.DOWN,null)
		roof.apply_city_material(slate,false,112.0,true,{"visual_seed":index*977,"building_usage":&"row_house"})
		for child: Node in (roof.get_node("RoofPoly") as Polygon2D).find_children("*","Polygon2D",true,false):
			if child.has_meta(&"city_roof_form"): forms += 1
	for index in _face_count:
		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([Vector2.ZERO,Vector2(96,0),Vector2(96,120),Vector2(48,140),Vector2(0,120)])
		face.position = Vector2(300+(index%6)*120,700) if index < 6 else Vector2(6000+(index%20)*110,4000+(index/20)*160)
		world.add_child(face)
		face.add_to_group(&"foreground_solid_occluders")
		face.set_meta(&"foreground_ground_contact",face.position+Vector2(48,140))
	var providers: Array[Node] = []
	var report := {"kind":"static-cover-cpu-probe","headless":DisplayServer.get_name()=="headless","roofs":_roof_count,"forms":forms,"faces":_face_count,"rounds":_rounds,"refreshes_per_round":_frames,"cooldown_seconds":0.5,"variants":[]}
	for spec: Dictionary in _specs:
		var script := load(spec.path) as GDScript
		if script == null:
			push_error("Unable to load provider "+str(spec.path)); get_tree().quit(1); return
		var provider := script.new() as Node
		add_child(provider)
		provider.set_process(false)
		providers.append(provider)
		report.variants.append({"name":spec.name,"path":spec.path,"sha256":FileAccess.get_sha256(spec.path),"rounds":[]})
	await get_tree().process_frame
	print("COVER_COST_READY")
	await get_tree().create_timer(1.0,true,false,true).timeout
	var semantics: Array = []
	for at in providers.size():
		for warm in 20: providers[at].call("refresh",world,true)
		var records: Array = providers[at].call("_semantic_records")
		if at == 0: semantics = records
		report.variants[at]["same_static_records_as_first"] = records == semantics
	for round_index in _rounds:
		# Rotate which provider runs first, keeping equal samples per provider.
		for offset in providers.size():
			var at := (round_index+offset)%providers.size()
			var provider := providers[at]
			# Cooling is outside measured refreshes; no external pauses in them.
			await get_tree().create_timer(0.5,true,false,true).timeout
			var samples: Array[float] = []
			var validation: Array[float] = []
			for step in _frames:
				var start := Time.get_ticks_usec()
				provider.call("refresh",world,true)
				samples.append(float(Time.get_ticks_usec()-start))
				var stats: Dictionary = provider.call("snapshot_stats")
				validation.append(float(stats.get("validation_usec",0)))
			report.variants[at].rounds.append({"refresh_usec_median":_median(samples),"validation_usec_median":_median(validation)})
		await get_tree().process_frame
	for at in providers.size():
		var medians: Array[float] = []
		for item: Dictionary in report.variants[at].rounds: medians.append(item.refresh_usec_median)
		report.variants[at]["refresh_usec_median"] = _median(medians)
		report.variants[at]["final_stats"] = providers[at].call("snapshot_stats")
		providers[at].free()
	world.free()
	if not _output.is_empty():
		var file := FileAccess.open(_output,FileAccess.WRITE)
		if file == null: push_error("Cannot write cover CPU report"); get_tree().quit(1); return
		file.store_string(JSON.stringify(report,"  ")+"\n")
	print("COVER_COST ",JSON.stringify(report))
	await get_tree().process_frame
	get_tree().quit(0)

func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var at := sorted.size()/2
	return sorted[at] if sorted.size()%2 else (sorted[at-1]+sorted[at])*0.5
