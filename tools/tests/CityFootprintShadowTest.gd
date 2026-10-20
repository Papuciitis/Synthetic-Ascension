extends Node2D
## Bounding-box substitution must fail these hand-checked L-footprint probes.

const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _probes(kit: Node, stage: String) -> void:
	_check(FIXTURE.covering_pieces(kit,Vector2(150,650)) == 0,stage+": no phantom caster over the empty northwest notch")
	_check(FIXTURE.covering_pieces(kit,Vector2(340,680)) == 1,stage+": the real east wing casts into its empty L notch")
	_check(FIXTURE.covering_pieces(kit,Vector2(150,900)) == 1,stage+": the lower west wing retains its real cast")
	var disjoint := true
	for y in range(579,1150,19):
		for x in range(103,899,23):
			if FIXTURE.covering_pieces(kit,Vector2(x,y)) > 1: disjoint = false
	_check(disjoint,stage+": overlapping extrusion pieces cannot double-darken the ground")


func _run() -> void:
	var old_segment := Global.attempt_segment
	Global.attempt_segment = 2
	var chunk := Node2D.new()
	add_child(chunk)
	var bed := FIXTURE.create(chunk)
	var kit := bed.kit as Node2D
	_check(not FIXTURE.untextured_shadows(kit).is_empty(),"actual production bed kit creates a sun shadow")
	_probes(kit,"configured production kit")
	var placed: Array[Rect2i] = [FIXTURE.BED_RECT]
	kit.trim_paving(placed,64)
	await get_tree().process_frame
	_probes(kit,"after actual parcel trimming")
	var roof := bed.roof as RoofOverlay
	roof._set_alpha(0.0)
	var cutaway_preserved := true
	for shade: Polygon2D in FIXTURE.untextured_shadows(kit):
		cutaway_preserved = cutaway_preserved and is_equal_approx(shade.modulate.a,0.65)
	_check(cutaway_preserved,"roof cutaway preserves the established residual building-ground cast")
	roof._set_alpha(1.0)
	# This second real orthogonal shape has empty ground in the top-right
	# of its parcel bounds. It must not erase a valid neighboring cast there.
	var neighbor_outline := PackedVector2Array([Vector2(64,768),Vector2(128,768),Vector2(128,896),Vector2(192,896),Vector2(192,1024),Vector2(64,1024)])
	var neighbor := FIXTURE.create(chunk,Vector2i.UP,neighbor_outline,Rect2i(1,12,2,4))
	placed.append(Rect2i(1,12,2,4))
	kit.trim_paving(placed,64)
	await get_tree().process_frame
	_check(FIXTURE.covering_pieces(kit,Vector2(150,850)) == 1,"neighbor's empty concave ground does not erase the bed wing cast")
	_check(FIXTURE.covering_pieces(kit,Vector2(150,950)) == 0,"neighbor's actual interior does clip the bed wing cast")
	_check((neighbor.outline as PackedVector2Array).size() == 6,"neighbor clipping fixture retains its recorded concavity")
	chunk.queue_free()
	await get_tree().process_frame
	Global.attempt_segment = old_segment
	print("CityFootprintShadowTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
