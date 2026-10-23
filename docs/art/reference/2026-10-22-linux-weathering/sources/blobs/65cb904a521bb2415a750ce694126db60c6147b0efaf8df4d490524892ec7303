extends Node2D
## Native single-owner check for facade stains (CityWeathering.draw_run): a
## stain replaces exactly the wall field's cut, so with 2D transform snapping
## and a partial cutaway fade no pixel along its edges is drawn twice (alpha
## too high) or left empty (alpha too low), and a zero-strength stain draws the
## plain wall. Sills sit on fractional pixels, as real small-window sills do.
## Readback only in this fixture. Headless runs skip the rendered checks.
## Pass `-- --out=DIR` to keep the reference and candidate images.

const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
const WEATHERING := preload("res://scenes/world/buildings/weathering/CityWeathering.gd")
const VIEW := Vector2i(192, 192)
## Wall with its plinth, in group space; the group sits on a fractional origin.
const FIELD := Rect2(0.0, 0.0, 160.0, 208.0)
const ORIGIN := Vector2(173.35, -86.25)
## A real small-window sill (bottom - 116.53875) and a .75 top of the opposite
## rounding direction.
const AREAS: Array[Rect2] = [Rect2(24.0, 91.46125, 40.0, 70.0), Rect2(96.0, 30.75, 36.0, 60.0)]
const ZOOMS: Array[float] = [1.0, 0.75, 1.25, 2.0]
const FADES: Array[float] = [0.5, 0.25, 1.0]
var _passes := 0
var _failures := 0
var _out := ""


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): _out = argument.trim_prefix("--out=")
	var previous := WEATHERING.current_theme()
	_check(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")), "the project snaps 2D transforms to pixels, the case this guards")
	if DisplayServer.get_name() != "headless":
		print("renderer: %s %s" % [RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method")])
		for theme: StringName in [&"", &"canal_services"]:
			WEATHERING.apply_theme(theme)
			for family: StringName in [&"warm", &"pale"]:
				for zoom: float in ZOOMS:
					for fade: float in FADES:
						await _compare(theme, family, zoom, fade, 0.0)
						await _compare(theme, family, zoom, fade, 0.3)
	WEATHERING.apply_theme(previous)
	print("CityWeatheringSeamRenderTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Renders the plain wall and the same wall with its stains, under the same
## camera, and compares them over each stain grown by 3 px (inside the wall).
func _compare(theme: StringName, family: StringName, zoom: float, fade: float, strength: float) -> void:
	var camera_at := ORIGIN + FIELD.get_center() + Vector2(0.37, -0.29)
	var reference := _view(camera_at, zoom)
	var candidate := _view(camera_at, zoom)
	COMPOSER._wall_field(_group(reference, fade), family, FIELD, [])
	var group := _group(candidate, fade)
	COMPOSER._wall_field(group, family, FIELD, AREAS)
	var stains: Array[Dictionary] = []
	for area: Rect2 in AREAS:
		stains.append({"kind": &"runoff", "area": area, "source": Rect2(area.position - Vector2(0, 20), Vector2(area.size.x, 20)), "tint": Color(0.36, 0.33, 0.29), "strength": strength})
	WEATHERING.draw_run(group, COMPOSER._family_material(family, false), stains, FIELD, COMPOSER.FACE_LIGHT)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var plain := (reference[0] as SubViewport).get_texture().get_image()
	var stained := (candidate[0] as SubViewport).get_texture().get_image()
	var label := "%s %s zoom %.2f fade %.2f strength %.1f" % [theme if theme != &"" else &"dry", family, zoom, fade, strength]
	var inner := Rect2(ORIGIN + FIELD.position, Vector2(FIELD.size.x, FIELD.size.y - COMPOSER.PLINTH_PX)).grow(-3.0)
	var worst_alpha := 0
	var worst_rgb := 0
	var bad := Vector2i(-1, -1)
	for area: Rect2 in AREAS:
		var strip := Rect2(ORIGIN + area.position, area.size).grow(3.0).intersection(inner)
		var from := _pixel(strip.position, camera_at, zoom)
		var to := _pixel(strip.end, camera_at, zoom)
		for y in range(maxi(from.y, 0), mini(to.y, VIEW.y)):
			for x in range(maxi(from.x, 0), mini(to.x, VIEW.x)):
				var a := plain.get_pixel(x, y)
				var b := stained.get_pixel(x, y)
				var alpha := absi(roundi(a.a * 255.0) - roundi(b.a * 255.0))
				var rgb := maxi(absi(roundi(a.r * 255.0) - roundi(b.r * 255.0)), maxi(absi(roundi(a.g * 255.0) - roundi(b.g * 255.0)), absi(roundi(a.b * 255.0) - roundi(b.b * 255.0))))
				if alpha > worst_alpha: bad = Vector2i(x, y)
				worst_alpha = maxi(worst_alpha, alpha)
				worst_rgb = maxi(worst_rgb, rgb)
	_check(worst_alpha <= 1, "%s: each stain edge has exactly one opaque owner (worst alpha step %d at %s)" % [label, worst_alpha, bad])
	if strength == 0.0:
		_check(worst_rgb <= 2, "%s: a zero-strength stain draws the plain wall, damp and light included (worst step %d)" % [label, worst_rgb])
	if not _out.is_empty() and zoom == 1.25 and fade == 0.5:
		DirAccess.make_dir_recursive_absolute(_out)
		var name := label.replace(" ", "_")
		plain.save_png(_out.path_join(name + "-reference.png"))
		stained.save_png(_out.path_join(name + "-candidate.png"))
	for view: Array in [reference, candidate]:
		(view[0] as SubViewport).queue_free()


func _view(camera_at: Vector2, zoom: float) -> Array:
	var view := SubViewport.new()
	view.size = VIEW
	view.transparent_bg = true
	view.snap_2d_transforms_to_pixel = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var camera := Camera2D.new()
	camera.position = camera_at
	camera.zoom = Vector2(zoom, zoom)
	world.add_child(camera)
	camera.make_current()
	return [view, world]


func _group(view: Array, fade: float) -> Node2D:
	var group := Node2D.new()
	group.position = ORIGIN
	group.modulate.a = fade
	(view[1] as Node2D).add_child(group)
	return group


func _pixel(world: Vector2, camera_at: Vector2, zoom: float) -> Vector2i:
	var at := (world - camera_at) * zoom + Vector2(VIEW) * 0.5
	return Vector2i(roundi(at.x), roundi(at.y))
