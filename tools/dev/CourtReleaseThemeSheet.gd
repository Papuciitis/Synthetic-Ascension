extends Node2D
## Native contact sheet for DistrictGroundPolicy court_release (2026-10-31):
## one district-fill court fixture (two passages, two doorways) drawn through
## the production ground shader for every district family, two ways: the
## stamped court as before, and unused cells released to the district yard
## (whatever the family's policy says). Choosing a family's release is a
## visual call; this puts every family side by side at gameplay scale.
##
## Run: <godot> --rendering-driver opengl3 --audio-driver Dummy res://tools/dev/CourtReleaseThemeSheet.tscn -- --out=/abs/dir
## Writes <family>.png (stamped | released, half scale) per family.

const SPLAT := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")
const CELL := 64
const CELLS := Vector2i(16, 14)
const COURT := Rect2i(3, 2, 11, 10)
const PASSAGES: Array[Rect2i] = [Rect2i(7, 0, 3, 3), Rect2i(13, 6, 3, 3)]
const DOORS: Array[Vector2] = [Vector2(4.5, 12.5), Vector2(12.5, 1.5)]

var _view: SubViewport
var _out := ""


func _ready() -> void:
	Engine.max_fps = 20
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _out.is_empty():
		push_error("CourtReleaseThemeSheet needs native rendering and --out")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_view = SubViewport.new()
	_view.size = CELLS * CELL
	_view.disable_3d = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	for family: StringName in POLICY.FAMILIES:
		var tiles: Array[Image] = []
		for release: int in [-1, POLICY.COURT_TO_YARD]:
			tiles.append(await _render(family, release))
		var half := tiles[0].get_size() / 2
		var sheet := Image.create(half.x * 2 + 8, half.y, false, Image.FORMAT_RGB8)
		sheet.fill(Color.WHITE)
		for index in tiles.size():
			tiles[index].resize(half.x, half.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(tiles[index], Rect2i(Vector2i.ZERO, half), Vector2i(index * (half.x + 8), 0))
		sheet.save_png(_out.path_join(String(family) + ".png"))
		print("CourtReleaseThemeSheet: ", family)
	get_tree().quit(0)


## release -1 = the stamped court (no support painted).
func _render(family: StringName, release: int) -> Image:
	for child: Node in _view.get_children():
		child.free()
	var splat: GroundSplatRenderer = SPLAT.new()
	_view.add_child(splat)
	splat.configure(CELL, CELLS.x)
	splat.set_ground_family(family)
	splat.set_chunk_base(Vector2i.ZERO, POLICY.DISTRICT_GROUND_INDEX)
	splat.paint_rect(COURT, 8, 0.88)
	for passage: Rect2i in PASSAGES:
		splat.paint_rect(passage, 4, 0.80)
	if release >= 0:
		var entrances: Array[Vector2] = [Vector2(8.5, 2.5), Vector2(13.5, 7.5)]
		entrances.append_array(DOORS)
		splat.paint_court_support(Vector2i.ZERO, COURT, entrances)
		splat.get_shader_material().set_shader_parameter("court_release", release)
	splat.flush()
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image
