extends Node2D
## Native pixel regression for district-fill court support (2026-10-31).
## One fixture renders three times through the production ground shader:
## the yard alone, the stamped court as before (no support), and the court
## with its use support. Released corners and the ring must draw exactly like
## the plain yard (setts and kerb gone), the used middle and walking line
## exactly like the stamped court, and everything beyond the ring unchanged.
## A family that keeps its court (canal services) keeps the setts but loses
## the kerb ring. This tiny fixture does not establish whole-city appearance
## or performance.

const SPLAT := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")
const CELL := 64
const CELLS := 14
const VIEW_SIZE := Vector2i(CELLS * CELL, 12 * CELL)
const COURT := Rect2i(2, 2, 9, 9)
const PASSAGE := Rect2i(5, 0, 3, 3)
## Pixel boxes (view px): a released far corner, the court middle, the walking
## line in from the passage mouth, the kerb band just outside the west edge,
## and a strip beyond the support ring.
const CORNER := Rect2i(10 * CELL + 8, 10 * CELL + 8, 40, 40)
## The same corner one cell in, clear of the old kerb's gutter shadow.
const INNER_CORNER := Rect2i(9 * CELL + 8, 9 * CELL + 8, 40, 40)
const MIDDLE := Rect2i(6 * CELL + 16, 6 * CELL + 16, 32, 32)
const ARM := Rect2i(6 * CELL + 16, 3 * CELL + 8, 32, 40)
const KERB := Rect2i(2 * CELL - 9, 9 * CELL, 8, 48)
const BEYOND := Rect2i(12 * CELL + 8, 2 * CELL, 2 * CELL - 16, 8 * CELL)

var _passed: int = 0
var _failed: int = 0
var _view: SubViewport
var _out: String = ""


func _ready() -> void:
	Engine.max_fps = 20
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility":
		_check(false, "GroundCourtSupportRenderTest requires native Compatibility rendering")
		_finish()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = ProjectSettings.globalize_path(argument.trim_prefix("--out="))
	if not _out.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(_out) == OK, "finite native evidence directory is writable")
	_view = SubViewport.new()
	_view.size = VIEW_SIZE
	_view.disable_3d = true
	_view.transparent_bg = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var yard := await _render("yard", false, false)
	var stamped := await _render("stamped", true, false)
	var supported := await _render("supported", true, true)
	var kept_yard := await _render("kept-yard", false, false, &"canal_services")
	var kept_stamped := await _render("kept-stamped", true, false, &"canal_services")
	var kept := await _render("kept", true, true, &"canal_services")
	_check(_mean_diff(stamped, yard, CORNER) > 6.0, "control: the stamped court's corner draws setts, not yard (%.2f)" % _mean_diff(stamped, yard, CORNER))
	_check(_luma(stamped, KERB) > _luma(yard, KERB) * 1.04, "control: the stamped court draws a kerb top on the yard beside it (%.1f vs %.1f)" % [_luma(stamped, KERB), _luma(yard, KERB)])
	_check(_mean_diff(supported, yard, CORNER) < 1.0, "a released corner draws exactly the district yard (%.2f)" % _mean_diff(supported, yard, CORNER))
	_check(_mean_diff(supported, yard, KERB) < 1.0, "no kerb draws beside a flush court (%.2f)" % _mean_diff(supported, yard, KERB))
	_check(_mean_diff(supported, stamped, MIDDLE) < 1.0, "the court's working middle keeps its setts (%.2f)" % _mean_diff(supported, stamped, MIDDLE))
	_check(_mean_diff(supported, stamped, ARM) < 1.0, "the walking line in from the passage keeps its setts (%.2f)" % _mean_diff(supported, stamped, ARM))
	_check(_mean_diff(supported, stamped, BEYOND) == 0.0, "ground beyond the support ring is byte-identical")
	_check(_ragged(supported, yard), "the released edge wanders instead of following a straight cell line")
	_check(_luma(kept_stamped, KERB) > _luma(kept_yard, KERB) * 1.04, "control: the canal court draws a kerb top too (%.1f vs %.1f)" % [_luma(kept_stamped, KERB), _luma(kept_yard, KERB)])
	_check(_mean_diff(kept, kept_stamped, INNER_CORNER) < 1.0, "a family that keeps its court keeps the setts in every corner (%.2f)" % _mean_diff(kept, kept_stamped, INNER_CORNER))
	_check(_mean_diff(kept, kept_yard, KERB) < 1.0, "and its flush court draws no kerb ring (%.2f)" % _mean_diff(kept, kept_yard, KERB))
	_finish()


func _render(label: String, court: bool, support: bool, family: StringName = &"outer_wall") -> Image:
	for child: Node in _view.get_children():
		child.free()
	var splat: GroundSplatRenderer = SPLAT.new()
	_view.add_child(splat)
	splat.configure(CELL, CELLS)
	splat.set_ground_family(family)
	splat.get_shader_material().set_shader_parameter("debug_view", 0)
	splat.set_chunk_base(Vector2i.ZERO, POLICY.DISTRICT_GROUND_INDEX)
	if court:
		splat.paint_rect(COURT, 8, 0.88)
	splat.paint_rect(PASSAGE, 4, 0.80)
	if support:
		splat.paint_court_support(Vector2i.ZERO, COURT, [Vector2(6.5, 2.5)] as Array[Vector2])
	splat.flush()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if not _out.is_empty():
		image.save_png(_out.path_join(label + ".png"))
	return image


func _luma(image: Image, box: Rect2i) -> float:
	var total := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := image.get_pixel(x, y)
			total += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
	return total / float(box.get_area())


func _mean_diff(a: Image, b: Image, box: Rect2i) -> float:
	var total := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0 / 3.0
	return total / float(box.get_area())


## Along the released south-east quadrant, the column where yard gives way to
## setts must vary row to row (the noise-ragged edge), not stay on one line.
func _ragged(supported: Image, yard: Image) -> bool:
	var edges: Array[int] = []
	for y in range(8 * CELL, 10 * CELL, 8):
		for x in range(11 * CELL - 1, 6 * CELL, -1):
			var a := supported.get_pixel(x, y)
			var b := yard.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				edges.append(x)
				break
	if edges.size() < 8:
		return false
	var lo: int = edges.min()
	var hi: int = edges.max()
	print("Released edge columns: ", edges)
	return hi - lo >= 12


func _finish() -> void:
	print("GroundCourtSupportRenderTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
