extends RefCounted
## A bounded household arrangement fitted to actual open cells. No RNG draws.

const CELL := 64.0
const KINDS: Array[StringName] = [&"cot", &"hearth", &"table", &"crate"]
const PROPS := {
	&"cot": {"source_path":"res://assets/world/domestic_interiors/v1/timber_cot.png", "anchor_px":Vector2(530,1345), "scale":60.0/632.0, "ground":Rect2(215,230,632,1129), "visible":Rect2(215,113,632,1246), "cells":Vector2i(1,2)},
	&"hearth": {"source_path":"res://assets/world/domestic_interiors/v1/cooking_hearth.png", "anchor_px":Vector2(800,805), "scale":120.0/1465.0, "ground":Rect2(69,265,1465,554), "visible":Rect2(69,175,1465,644), "cells":Vector2i(2,1)},
	&"table": {"source_path":"res://assets/world/props/prop_table_small_01.png", "anchor_px":Vector2(512,795), "scale":64.0/771.0, "ground":Rect2(127,474,771,324), "visible":Rect2(127,247,771,551), "cells":Vector2i.ONE},
	&"crate": {"source_path":"res://assets/world/dressing/generated/crate.tres", "anchor_px":Vector2(210,456), "scale":64.0/420.0, "ground":Rect2(8,300,404,156), "visible":Rect2(8,8,404,448), "cells":Vector2i.ONE},
}
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]


static func _eligible(context: Dictionary) -> bool:
	return int(context.get("segment",0)) == 2 and StringName(context.get("usage",&"")) == &"row_house" and not bool(context.get("civic",true))


static func _furniture_eligible(context: Dictionary) -> bool:
	# Placement can consume more seeded draws after each item is generated.
	# Only an actual known single-item ambient owner permits new blockers.
	return _eligible(context) and int(context.get("small_count_max",2)) <= 1 and not bool(context.get("local_encounter_enabled",true)) and not bool(context.get("force_large_loot",true)) and not bool(context.get("loot_is_large",false))


static func plan(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _furniture_eligible(context) or not is_equal_approx(float(context.get("cell_px",CELL)),CELL):
		return result
	var floor_cells: Dictionary = context.get("floor_cells",{})
	var walls: Dictionary = context.get("wall_cells",{})
	var protected: Dictionary = context.get("protected_cells",{})
	var outline: PackedVector2Array = context.get("footprint_px",PackedVector2Array())
	if floor_cells.is_empty() or outline.size() < 3:
		return result
	var cells: Array = floor_cells.keys()
	cells.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	var center := Vector2.ZERO
	for cell: Vector2i in cells:
		center += Vector2(cell)
	center /= float(cells.size())
	var occupied: Dictionary = {}
	for kind: StringName in KINDS:
		var candidates: Array[Dictionary] = []
		for cell: Vector2i in cells:
			var record := _fit(kind,cell,floor_cells,walls,protected,occupied,outline)
			if record.is_empty():
				continue
			record["score"] = _score(kind,record,walls,center,int(context.get("visual_seed",0)),result)
			candidates.append(record)
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.score) > float(b.score))
		for record: Dictionary in candidates:
			var remaining := floor_cells.duplicate()
			for cell: Vector2i in occupied:
				remaining.erase(cell)
			for cell: Vector2i in record.reserved_cells:
				remaining.erase(cell)
			if remaining.is_empty() or _flood(remaining,remaining.keys()[0]).size() != remaining.size():
				continue
			record.erase("score")
			result.append(record)
			for cell: Vector2i in record.reserved_cells:
				occupied[cell] = true
			break
	return result


static func _fit(kind: StringName, first: Vector2i, floor_cells: Dictionary, walls: Dictionary, protected: Dictionary, occupied: Dictionary, outline: PackedVector2Array) -> Dictionary:
	var prop: Dictionary = PROPS[kind]
	var size: Vector2i = prop.cells
	var reserved: Array[Vector2i] = []
	var supported := false
	for y in range(first.y,first.y+size.y):
		for x in range(first.x,first.x+size.x):
			var cell := Vector2i(x,y)
			if not floor_cells.has(cell) or walls.has(cell) or protected.has(cell) or occupied.has(cell):
				return {}
			reserved.append(cell)
			for direction: Vector2i in DIRECTIONS:
				supported = supported or walls.has(cell+direction)
	if not supported:
		return {}
	var scale_value := float(prop.scale)
	var anchor: Vector2 = prop.anchor_px
	var source_ground: Rect2 = prop.ground
	var source_visible: Rect2 = prop.visible
	var reserve_rect := Rect2(Vector2(first)*CELL,Vector2(size)*CELL)
	var contact := reserve_rect.get_center()-(source_ground.get_center()-anchor)*scale_value
	var ground := Rect2(contact+(source_ground.position-anchor)*scale_value,source_ground.size*scale_value)
	var visible := Rect2(contact+(source_visible.position-anchor)*scale_value,source_visible.size*scale_value)
	for corner: Vector2 in [visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]:
		if not Geometry2D.is_point_in_polygon(corner,outline):
			return {}
	return {"kind":kind,"source_path":prop.source_path,"anchor_px":anchor,"scale":scale_value,"contact_px":contact,"ground_rect_px":ground,"visible_rect_px":visible,"reserved_cells":reserved}


static func _score(kind: StringName, record: Dictionary, walls: Dictionary, center: Vector2, visual_seed: int, selected: Array[Dictionary]) -> float:
	var cells: Array = record.reserved_cells
	var first: Vector2i = cells[0]
	var score := Vector2(first).distance_squared_to(center)*4.0
	for cell: Vector2i in cells:
		if kind == &"cot" and (walls.has(cell+Vector2i.LEFT) or walls.has(cell+Vector2i.RIGHT)):
			score += 2000.0
		if kind == &"hearth" and walls.has(cell+Vector2i.UP):
			score += 4000.0
		for direction: Vector2i in DIRECTIONS:
			if walls.has(cell+direction):
				score += 80.0
	if kind == &"crate":
		for previous: Dictionary in selected:
			if previous.kind == &"table":
				score -= (record.contact_px as Vector2).distance_squared_to(previous.contact_px)*0.2
	var hash_value := (first.x*73856093) ^ (first.y*19349663) ^ visual_seed
	return score+float(posmod(hash_value,997))*0.001


static func _flood(cells: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not cells.has(start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for direction: Vector2i in DIRECTIONS:
			var next := cell+direction
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


static func context_for(kit: Node2D, data: ChunkBuildData, wall_cells: Dictionary, building_id: int) -> Dictionary:
	var roof := kit.get("_roof") as RoofOverlay
	if roof == null or data == null:
		return {}
	var outline := roof.footprint_outline_px
	var floor_cells: Dictionary = {}
	var chunk := kit.get_parent() as Node2D
	var manager := chunk.get_parent() as ChunkManager
	for y in data.cells_per_side:
		for x in data.cells_per_side:
			var cell := Vector2i(x,y)
			if data.kind_at(cell) < 0 and (manager == null or not manager.is_cell_blocked(data.coord*data.cells_per_side+cell)) and Geometry2D.is_point_in_polygon((Vector2(cell)+Vector2.ONE*0.5)*CELL,outline):
				floor_cells[cell] = true
	var protected: Dictionary = {}
	for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells",{}):
		if floor_cells.has(cell):
			protected[cell] = true
	var doors: Array = kit.get("_doors")
	var start := Vector2i(-1,-1)
	for door: Dictionary in doors:
		var direction: Vector2i = door.dir
		var perpendicular := Vector2i(-direction.y,direction.x)
		var width := int(door.get("width",2))
		var first: Vector2i = door.pos-perpendicular*(width>>1)
		for index in width:
			var entry := first+perpendicular*index
			if floor_cells.has(entry):
				start = entry
			for depth in data.cells_per_side:
				var cell := entry-direction*depth
				if floor_cells.has(cell):
					protected[cell] = true
	if start.x >= 0:
		floor_cells = _flood(floor_cells,start)
	var context := {"segment":Global.attempt_segment,"usage":kit.get_meta(&"building_usage",&""),"civic":bool(kit.get("civic")),"building_id":building_id,"visual_seed":building_id,"cell_px":64,"footprint_px":outline,"doors":doors,"wall_cells":wall_cells,"floor_cells":floor_cells,"protected_cells":protected,"world_origin":kit.global_position}
	context.merge(_reward_policy(chunk,roof,building_id),true)
	return context


static func _reward_policy(chunk: Node2D, roof: RoofOverlay, building_id: int) -> Dictionary:
	var found := false
	var max_count := 0
	var encounter := false
	var forced_large := false
	var large := false
	for child: Node in chunk.get_children():
		if not child is IndoorVolume or (child as IndoorVolume).building_id != building_id:
			continue
		var connected := false
		for connection: Dictionary in child.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof:
				connected = true
		if not connected:
			continue
		var volume := child as IndoorVolume
		found = true
		max_count = maxi(max_count,volume.small_count_max)
		encounter = encounter or volume.local_encounter_enabled
		forced_large = forced_large or volume.force_large_loot
		large = large or maxi(volume.size_cells.x*volume.size_cells.y,volume.site_area_cells) >= volume.large_area_threshold_cells
	return {"small_count_max":max_count if found else 2,"local_encounter_enabled":encounter if found else true,"force_large_loot":forced_large if found else true,"loot_is_large":large}


static func mark_walls(data: ChunkBuildData, wall_cells: Dictionary, context: Dictionary) -> void:
	if data == null or not _eligible(context):
		return
	for cell: Vector2i in wall_cells:
		if data.kind_at(cell) in [WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.Kind.WINDOW]:
			data.blocker_variant[data._index(cell)] |= ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE


static func compose(kit: Node2D, manager: ChunkManager, data: ChunkBuildData, context: Dictionary) -> Node2D:
	if not _furniture_eligible(context) or data == null or manager == null or manager.cover_half_scene == null:
		return null
	var existing := kit.get_node_or_null("CityDomesticInterior") as Node2D
	if existing != null:
		return existing
	var layout := plan(context)
	if layout.is_empty():
		return null
	var group := Node2D.new()
	group.name = "CityDomesticInterior"
	group.z_index = ChunkBlockVisualCatalog.PROP_Z-kit.z_index
	group.set_meta(&"domestic_layout",layout)
	kit.add_child(group)
	var chunk := kit.get_parent() as Node2D
	for record: Dictionary in layout:
		var texture := load(String(record.source_path)) as Texture2D
		if texture == null:
			continue
		for cell: Vector2i in record.reserved_cells:
			manager._spawn_block(chunk,manager.cover_half_scene,cell.x,cell.y)
			if data.kind_at(cell) == WorldBlockerGeometry.Kind.HALF_COVER:
				data.blocker_variant[data._index(cell)] |= ChunkBlockVisualCatalog.VARIANT_FURNITURE_ART
		var art := Sprite2D.new()
		art.name = "Domestic"+String(record.kind).capitalize()
		art.texture = texture
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.scale = Vector2.ONE*float(record.scale)
		art.position = (record.contact_px as Vector2)+(texture.get_size()*0.5-(record.anchor_px as Vector2))*float(record.scale)
		art.set_meta(&"domestic_kind",record.kind)
		group.add_child(art)
		var shadow := Sprite2D.new()
		shadow.name = art.name+"ContactShadow"
		shadow.texture = texture
		shadow.texture_filter = art.texture_filter
		shadow.transform = art.transform
		shadow.position += Vector2(-4,3)
		shadow.modulate = Color(0.02,0.025,0.03,0.2)
		shadow.z_index = -1
		group.add_child(shadow)
	return group
