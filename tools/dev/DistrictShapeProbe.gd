extends Node
## Renders a hand-authored 5x3 district (plazas, streets, crossings, a
## building chunk on each side) to a PNG cell map so layout changes can be
## judged without a display. Non-block city pass, 2026-09-27.
##
## Run: <godot> --headless --path . res://tools/dev/DistrictShapeProbe.tscn -- --out=/abs/dir --organic=1 --seed=424242

const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const _WORLD_ART = preload("res://core/systems/world/WorldArt.gd")
const PX := 4

var _out_dir := "/tmp"
var _organic := true
var _seed := 424242


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--organic="):
			_organic = arg.trim_prefix("--organic=") != "0"
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	call_deferred(&"_run")


func _manager() -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = _seed
	manager.ground_enabled = true
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.batched_chunk_blockers = true
	manager.debug_draw_chunk_outlines = false
	manager.debug_show_blocks = false
	manager.tiled_world_rendering = false
	manager.set("organic_shapes_enabled", _organic)
	manager.set("parcels_enabled", true)
	manager.set("parcels_chunk_chance", 1.0)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	var connectors: Dictionary = {}
	var roles: Dictionary = {}
	var archetypes: Dictionary = {}
	var N := 1
	var E := 2
	var S := 4
	var W := 8
	for x in range(0, 5):
		for y in range(0, 3):
			var c := Vector2i(x, y)
			connectors[c] = 0
			roles[c] = &"wilderness"
			archetypes[c] = &"building"
	for x in range(0, 5):
		connectors[Vector2i(x, 1)] = E | W
		roles[Vector2i(x, 1)] = &"secondary"
		archetypes[Vector2i(x, 1)] = &"street"
	connectors[Vector2i(2, 0)] = N | S
	connectors[Vector2i(2, 2)] = N | S
	connectors[Vector2i(2, 1)] = N | E | S | W
	roles[Vector2i(0, 1)] = &"entry_court"
	archetypes[Vector2i(0, 1)] = &"plaza"
	roles[Vector2i(2, 1)] = &"landmark_plaza"
	archetypes[Vector2i(2, 1)] = &"plaza"
	roles[Vector2i(4, 1)] = &"primary_objective"
	archetypes[Vector2i(4, 1)] = &"plaza"
	roles[Vector2i(2, 0)] = &"checkpoint"
	archetypes[Vector2i(2, 0)] = &"gate"
	roles[Vector2i(2, 2)] = &"exploration_reward"
	archetypes[Vector2i(2, 2)] = &"street"
	manager.configure_procedural_world(_seed, connectors, {}, roles, {}, archetypes)
	add_child(manager)
	return manager


func _tex_index(texture: Texture2D) -> int:
	for i in range(_WORLD_ART.ground_texture_count()):
		if _WORLD_ART.ground_texture(i) == texture:
			return i
	return -1


func _run() -> void:
	var manager := _manager()
	var cpc := int(manager.call("_cells_per_chunk"))
	var image := Image.create(5 * cpc * PX, 3 * cpc * PX, false, Image.FORMAT_RGB8)
	image.fill(Color(0.16, 0.24, 0.14))
	var palette := {
		0: Color(0.22, 0.42, 0.18), 1: Color(0.42, 0.33, 0.22), 2: Color(0.52, 0.52, 0.50), 3: Color(0.72, 0.70, 0.64),
		4: Color(0.50, 0.40, 0.26), 5: Color(0.30, 0.26, 0.20), 6: Color(0.45, 0.45, 0.45), 7: Color(0.60, 0.58, 0.55),
		8: Color(0.48, 0.55, 0.44), 9: Color(0.66, 0.62, 0.55), 10: Color(0.26, 0.46, 0.20), 11: Color(0.55, 0.55, 0.30), 12: Color(0.30, 0.45, 0.28),
	}
	var walls := 0
	var stamps := 0
	var blocked_hash := 0
	for y in range(0, 3):
		for x in range(0, 5):
			var coord := Vector2i(x, y)
			var chunk := manager.call("_create_chunk", coord) as Node2D
			if chunk == null:
				continue
			var data: ChunkBuildData = (manager.get("_chunk_build_data") as Dictionary).get(coord)
			if data != null:
				# Floor stamps straight from the packed build data (activation is staged, so sprites may not exist yet).
				var order: Array[int] = []
				for i in range(data.floor_stamp_count()):
					order.append(i)
				order.sort_custom(func(a: int, b: int) -> bool: return data.floor_rect_and_style[a * 6 + 5] < data.floor_rect_and_style[b * 6 + 5])
				for i in order:
					var o := i * 6
					var packed := data.floor_rect_and_style
					var idx: int = packed[o + 4]
					var color: Color = palette.get(idx, Color.MAGENTA)
					color = color.lerp(Color(0.16, 0.24, 0.14), 1.0 - data.floor_alpha[i])
					_fill(image, (x * cpc + packed[o]) * PX, (y * cpc + packed[o + 1]) * PX, packed[o + 2] * PX, packed[o + 3] * PX, color)
					stamps += 1
			if data != null:
				for index in data.occupied_indices():
					var cell := data.cell_for_index(index)
					var kind := data.kind_at(cell)
					var color := Color.BLACK
					if kind == WorldBlockerGeometry.Kind.WINDOW:
						color = Color(0.25, 0.45, 0.95)
					elif kind == WorldBlockerGeometry.Kind.HALF_COVER:
						color = Color(0.85, 0.55, 0.20)
					_fill(image, (x * cpc + cell.x) * PX + 1, (y * cpc + cell.y) * PX + 1, PX - 1, PX - 1, color)
					walls += 1
					blocked_hash = (blocked_hash * 31 + (coord.x * 1000003 + coord.y * 7919 + cell.x * 131 + cell.y * 17 + kind)) & 0x7fffffff
	# chunk seams
	for x in range(1, 5):
		_fill(image, x * cpc * PX, 0, 1, image.get_height(), Color(0.9, 0.2, 0.2))
	for y in range(1, 3):
		_fill(image, 0, y * cpc * PX, image.get_width(), 1, Color(0.9, 0.2, 0.2))
	var path := "%s/district_%s_%d.png" % [_out_dir, "organic" if _organic else "rect", _seed]
	var err := image.save_png(path)
	print("DistrictShapeProbe: %s stamps=%d blockers=%d hash=%d -> %s (%s)" % ["organic" if _organic else "rect", stamps, walls, blocked_hash, path, error_string(err)])
	get_tree().quit(0)


func _fill(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(maxi(0, y), mini(image.get_height(), y + h)):
		for xx in range(maxi(0, x), mini(image.get_width(), x + w)):
			image.set_pixel(xx, yy, color)
