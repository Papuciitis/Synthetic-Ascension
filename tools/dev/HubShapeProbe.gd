extends Node
## Renders the hub courtyard cells (floor, walls, gates, stations) to a PNG.
## Run: <godot> --headless --path . res://tools/dev/HubShapeProbe.tscn -- --out=/abs/dir

const PX := 8


func _ready() -> void:
	var out_dir := "/tmp"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var fill: Dictionary = HubWorld.courtyard_cells()
	var walls: Dictionary = HubWorld.courtyard_walls(fill)
	var origin := Vector2i(-6, -3)
	var size := Vector2i(HubWorld.WIDTH + 12, HubWorld.HEIGHT + 6)
	var image := Image.create(size.x * PX, size.y * PX, false, Image.FORMAT_RGB8)
	image.fill(Color(0.16, 0.24, 0.14))
	for key in fill.keys():
		_cell(image, key - origin, Color(0.55, 0.52, 0.46))
	for key in walls.keys():
		_cell(image, key - origin, Color.BLACK)
	var marks: Dictionary = HubWorld.STATION_CELLS
	var all_on_floor := true
	for station in marks.keys():
		var at: Vector2 = marks[station]
		var cell := Vector2i(int(floor(at.x)), int(floor(at.y)))
		var ok := fill.has(cell) and not walls.has(cell)
		all_on_floor = all_on_floor and ok
		_cell(image, cell - origin, Color(0.2, 0.9, 0.3) if ok else Color(1.0, 0.1, 0.1))
	var path := "%s/hub_courtyard.png" % out_dir
	image.save_png(path)
	print("HubShapeProbe: floor=%d walls=%d stations_on_floor=%s -> %s" % [fill.size(), walls.size(), str(all_on_floor), path])
	get_tree().quit(0)


func _cell(image: Image, c: Vector2i, color: Color) -> void:
	for y in range(c.y * PX, c.y * PX + PX):
		for x in range(c.x * PX, c.x * PX + PX):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
