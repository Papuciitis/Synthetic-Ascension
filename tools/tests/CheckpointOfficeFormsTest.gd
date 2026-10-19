extends Node

const FORMS_PATH := "res://scenes/world/buildings/CheckpointOfficeForms.gd"
var passed := 0
var failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _validate(script: Script, footprint: PackedVector2Array, support: PackedVector2Array, doors: Array, expected_gaps: Array, want_watch: bool, label: String) -> Dictionary:
	var original := str([footprint,support,doors])
	var result: Dictionary = script.plan(footprint,support,doors,64,17)
	_check(str(result) == str(script.plan(footprint,support,doors,64,17)), label+" repeats deterministically")
	_check(original == str([footprint,support,doors]), label+" leaves caller geometry untouched")
	_check(result.entry_recesses.size() == doors.size(), label+" retains every actual entry")
	for index: int in doors.size():
		_check(result.entry_recesses[index].opening == expected_gaps[index], label+" preserves the hand-checked full even-width doorway")
		_check(result.entry_recesses[index].door == doors[index], label+" preserves normalised direction/anchor record")
	for bay: Dictionary in result.arch_bays:
		_check(bay.kind == &"closed_inspection", label+" non-entry arch is explicitly closed")
		_check(bay.face.size.x >= 128.0 and bay.face.size.x <= 192.0, label+" uses whole supported bays rather than stretched grilles")
		_check(Geometry2D.clip_polygons(_rect_poly(bay.support),footprint).is_empty(),label+" bay feet sit on the real footprint")
		for gap: Rect2 in expected_gaps:
			_check(not bay.support.intersects(gap),label+" closed masonry does not occupy real door cells")
	_check(result.has_watch == want_watch, label+" watch presence follows support")
	if result.has_watch:
		_check(result.watch_support.size() == 4,label+" compact watch has one physical support quad")
		var watch_bounds := Rect2(result.watch_support[0],Vector2.ZERO)
		for point: Vector2 in result.watch_support: watch_bounds = watch_bounds.expand(point)
		_check(watch_bounds.size == Vector2(128,128),label+" compact watch footprint retains intended scale")
		_check(Geometry2D.clip_polygons(_rect_poly(watch_bounds.grow(16)),support).is_empty(),label+" full watch margin fits the actual roof support")
	else:
		_check(not String(result.fallback_reason).is_empty(),label+" omission has an explicit safe fallback reason")
	return result

func _run() -> void:
	var forms: Script = load(FORMS_PATH) if ResourceLoader.exists(FORMS_PATH) else null
	_check(forms != null,"Guard architecture needs a fitted form planner")
	if forms != null:
		var footprint := PackedVector2Array([Vector2(128,256),Vector2(832,256),Vector2(832,832),Vector2(128,832)])
		var support := _rect_poly(Rect2(138,266,684,556))
		var samples := [
			{"door":{"pos":Vector2i(7,4),"dir":Vector2i.UP,"width":2},"gap":Rect2(384,256,128,64)},
			{"door":{"pos":Vector2i(7,12),"dir":Vector2i.DOWN,"width":2},"gap":Rect2(448,768,128,64)},
			{"door":{"pos":Vector2i(12,8),"dir":Vector2i.RIGHT,"width":2},"gap":Rect2(768,448,64,128)},
			{"door":{"pos":Vector2i(2,8),"dir":Vector2i.LEFT,"width":2},"gap":Rect2(128,512,64,128)},
		]
		for sample: Dictionary in samples:
			var result := _validate(forms,footprint,support,[sample.door],[sample.gap],true,str(sample.door.dir))
			_check(not result.arch_bays.is_empty(),"Rectangular family retains deep closed arch bays for every entrance orientation")
		_validate(forms,footprint,support,[samples[0].door,samples[1].door],[samples[0].gap,samples[1].gap],true,"two-ended passage")
		_validate(forms,_rect_poly(Rect2(960,256,576,576)),_rect_poly(Rect2(970,266,556,556)),[],[],true,"second existing parcel")
		var irregular := PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(384,576),Vector2(384,320),Vector2(128,320)])
		var irregular_result := _validate(forms,irregular,irregular,[],[],true,"L footprint")
		for bay: Dictionary in irregular_result.arch_bays:
			_check(is_equal_approx(bay.face.size.y,112),"Irregular exposed-edge frontage keeps the safe reduced height")
		for plane: Dictionary in irregular_result.roof_planes:
			if float(plane.lift) == 0.0:
				_check(Geometry2D.clip_polygons(plane.polygon,irregular).is_empty(),"Irregular roof cannot bridge the missing L corner")
		var narrow := _rect_poly(Rect2(128,128,256,128))
		var narrow_door := {"pos":Vector2i(3,3),"dir":Vector2i.DOWN,"width":2}
		var reduced := _validate(forms,narrow,_rect_poly(Rect2(138,138,236,108)),[narrow_door],[Rect2(192,192,128,64)],false,"shallow parcel")
		_check(reduced.arch_bays.size()+reduced.entry_recesses.size()>0,"No-watch fallback retains recognisable entry/arch architecture")
		for empty_outline: PackedVector2Array in [PackedVector2Array(),PackedVector2Array([Vector2.ZERO,Vector2.ONE,Vector2(2,2)])]:
			var invalid: Dictionary = forms.plan(empty_outline,PackedVector2Array(),[],64,0)
			_check(invalid.fallback_reason == &"invalid_footprint" and invalid.roof_planes.is_empty() and invalid.arch_bays.is_empty(),"Invalid support produces an honest empty plan")
	print("CheckpointOfficeFormsTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)
