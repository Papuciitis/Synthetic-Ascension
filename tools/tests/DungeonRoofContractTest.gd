extends Node2D
const LAYOUT := preload("res://core/systems/world/proc/DungeonLayout.gd")
const BUILDING := preload("res://scenes/world/buildings/DungeonBuilding.gd")
var passed := 0
var failed := 0

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 10: push_error(message)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	var player := Node2D.new()
	player.position = Vector2(-500,-500)
	player.add_to_group(&"player")
	add_child(player)
	var body := AnimatedSprite2D.new()
	var head := AnimatedSprite2D.new()
	add_child(body)
	add_child(head)
	var occlusion := preload("res://core/actors/player/PlayerRoofOcclusion.gd").new()
	occlusion.configure(body,head)
	for size: Vector2i in [Vector2i(60,28),Vector2i(28,60),Vector2i(60,60)]:
		for side in range(4):
			var region := Rect2i(Vector2i(2,2),size)
			var first := Vector2i(21,2)
			if side == 1: first = Vector2i(region.end.x-1,10)
			elif side == 2: first = Vector2i(21,region.end.y-1)
			elif side == 3: first = Vector2i(2,10)
			var entries: Array[Vector2i] = [first,first+(Vector2i.DOWN if side in [1,3] else Vector2i.RIGHT)]
			var plan := LAYOUT.build(region,71849,entries)
			var chunks: Array[Node2D] = []
			var roofs: Array[RoofOverlay] = []
			for cy in range(2 if size.y>32 else 1):
				for cx in range(2 if size.x>32 else 1):
					var chunk := Node2D.new()
					chunk.position = Vector2(cx,cy)*2048
					add_child(chunk)
					chunks.append(chunk)
					var host := BUILDING.attach(chunk,plan,Vector2i(cx,cy)*32,32,64)
					for node: Node in host.get_children():
						if node is RoofOverlay: roofs.append(node)
			var door := Rect2(Vector2(entries[0])*64,Vector2.ONE*64).merge(Rect2(Vector2(entries[1])*64,Vector2.ONE*64))
			var door_poly := PackedVector2Array([door.position,Vector2(door.end.x,door.position.y),door.end,Vector2(door.position.x,door.end.y)])
			for roof: RoofOverlay in roofs:
				for node: Node in roof.get_node("RoofPoly").get_children():
					if not node is Polygon2D or node.get_meta(&"city_roof_form",&"") != &"dungeon_gatehouse_return": continue
					var face := node as Polygon2D
					var points := PackedVector2Array()
					for point: Vector2 in face.polygon: points.append(face.to_global(point))
					var overlap := 0.0
					for part: PackedVector2Array in Geometry2D.intersect_polygons(points,door_poly): overlap += _area(part)
					_check(overlap < 0.1,"Raised return/gable never paints over real cardinal doorway: "+str([size,side]))
					if _area(points)<64: continue
					var bounds := Rect2(points[0],Vector2.ZERO)
					for point: Vector2 in points: bounds = bounds.expand(point)
					var sample := Vector2(bounds.get_center().x,bounds.end.y-minf(16,bounds.size.y*0.2))
					if not Geometry2D.is_point_in_polygon(sample,points): continue
					for other: RoofOverlay in roofs: other.visible = other == roof
					var sprite_bounds := Rect2(sample-Vector2(16,24),Vector2(32,48))
					var edge := roof.to_global(roof.footprint_outline_px[2]).y
					occlusion.update(self,Vector2(sample.x,edge-4),sprite_bounds)
					_check(occlusion.strength_at(sample)>0.9,"Lower raised stone return participates in actor silhouette without relying on adjacent roofs")
					occlusion.update(self,Vector2(sample.x,edge+4),sprite_bounds)
					_check(occlusion.strength_at(sample)==0,"Actor in front of raised return remains clear")
					for other: RoofOverlay in roofs: other.visible = true
			for chunk: Node2D in chunks: chunk.free()
	print("DungeonRoofContractTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)

func _area(points: PackedVector2Array) -> float:
	var value := 0.0
	for index in points.size(): value += points[index].cross(points[(index+1)%points.size()])
	return absf(value)*0.5
