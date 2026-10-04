extends Node

## Segment-1 load hitches from the FPS audit (2026-10-04, item 8):
## (b) decals reuse one prebuilt source per texture - the orientation is a
##     cell transform that must show exactly what the old baked image showed,
##     the alpha snaps to four levels, and painting adds no TileSet source;
## (c) clear_chunk erases exactly the cells painted in the chunk's rect,
##     whoever painted them, and leaves the neighbours alone;
## (d) the ground-splat noise builds the same bytes without the per-pixel
##     loop.
## Real decal looks need a rendered run; this covers the bookkeeping.

const RendererScript = preload("res://core/systems/world/ChunkTileRenderer.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


## A small image whose every pixel differs, so any orientation slip shows.
func _probe_image(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			image.set_pixel(x, y, Color8(x * 37 % 256, y * 59 % 256, (x * 7 + y * 11) % 256, 255))
	return image


## The old pipeline's baked orientation.
func _baked(source: Image, turns: int, flip_h: bool, flip_v: bool) -> Image:
	var image := source.duplicate() as Image
	if flip_h:
		image.flip_x()
	if flip_v:
		image.flip_y()
	for _turn in range(turns):
		image.rotate_90(CLOCKWISE)
	return image


## What a TileMapLayer cell shows with transform flags, per the canvas shader:
## the flips mirror the destination rect, transpose swaps the texture axes
## (uv = transpose ? base.yx : base.xy; vertex = flip ? 1 - base : base).
func _transformed(source: Image, flags: int) -> Image:
	var size := source.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var transpose := (flags & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var flip_h := (flags & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v := (flags & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	for gy in size:
		for gx in size:
			var bx := size - 1 - gx if flip_h else gx
			var by := size - 1 - gy if flip_v else gy
			var tx := by if transpose else bx
			var ty := bx if transpose else by
			out.set_pixel(gx, gy, source.get_pixel(tx, ty))
	return out


func _host(renderer: RefCounted) -> Node2D:
	var host := Node2D.new()
	add_child(host)
	renderer.call("configure_host", host, 64)
	return host


func _chunk(host: Node2D, renderer: RefCounted, coord: Vector2i) -> Node2D:
	var chunk := Node2D.new()
	host.add_child(chunk)
	chunk.set_meta(&"_chunk_tile_coord", coord)
	chunk.set_meta(&"_chunk_cells_per_side", 32)
	renderer.call("begin_chunk", chunk, 64)
	return chunk


func _run() -> void:
	_test_orientation_table()
	_test_decal_source_reuse()
	_test_clear_chunk_exact()
	_test_noise_bytes()
	await get_tree().process_frame
	print("ChunkTileDecalCacheTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_orientation_table() -> void:
	var source := _probe_image(5)
	var mismatches := 0
	for turns in range(4):
		for flip_h in [false, true]:
			for flip_v in [false, true]:
				var flags := int(RendererScript.DECAL_TRANSFORMS[turns * 4 + (2 if flip_h else 0) + (1 if flip_v else 0)])
				if _baked(source, turns, flip_h, flip_v).get_data() != _transformed(source, flags).get_data():
					mismatches += 1
	_check(mismatches == 0, "all sixteen turn/flip combinations draw exactly the old baked orientation")


func _test_decal_source_reuse() -> void:
	var renderer := RendererScript.new()
	var host := _host(renderer)
	var chunk := _chunk(host, renderer, Vector2i.ZERO)
	var texture := ImageTexture.create_from_image(_probe_image(64))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var painted := 0
	for i in range(60):
		var alpha := rng.randf_range(0.12, 0.25)
		if renderer.paint_decal(chunk, &"decal", Vector2i(i % 32, i / 32), texture, -90, rng.randi_range(0, 3), rng.randf() < 0.5, rng.randf() < 0.5, alpha):
			painted += 1
	var tile_set := renderer.get("_tile_set") as TileSet
	_check(painted == 60, "sixty decals paint")
	_check(tile_set.get_source_count() == 1, "sixty random decals of one texture share one source (%d)" % tile_set.get_source_count())
	var layer := host.find_children("WorldTiles_decal_90", "TileMapLayer", true, false)[0] as TileMapLayer
	var source := tile_set.get_source(tile_set.get_source_id(0)) as TileSetAtlasSource
	_check(source.get_alternative_tiles_count(Vector2i.ZERO) == 4, "the source carries one alternative per alpha level")
	var alpha_ok := true
	for level in range(4):
		alpha_ok = alpha_ok and is_equal_approx(source.get_tile_data(Vector2i.ZERO, level).modulate.a, float(RendererScript.DECAL_ALPHA_LEVELS[level]))
	_check(alpha_ok, "each level's tile carries its alpha")
	var alternative := layer.get_cell_alternative_tile(Vector2i(5, 0))
	_check((alternative & ~(TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE)) < 4, "a painted cell stores a level plus transform flags")
	_check(RendererScript.decal_alpha_level(0.12) == 0 and RendererScript.decal_alpha_level(0.25) == 3, "the range ends snap to the outer levels")
	var worst := 0.0
	for i in range(200):
		var a := lerpf(0.12, 0.25, float(i) / 199.0)
		worst = maxf(worst, absf(float(RendererScript.DECAL_ALPHA_LEVELS[RendererScript.decal_alpha_level(a)]) - a))
	_check(worst <= 0.0163, "no decal alpha moves more than 0.016 (worst %.4f)" % worst)
	# The generic path, for contrast: a source per orientation and alpha.
	var generic := RendererScript.new()
	var generic_host := _host(generic)
	var generic_chunk := _chunk(generic_host, generic, Vector2i.ZERO)
	rng.seed = 7
	for i in range(60):
		var alpha := rng.randf_range(0.12, 0.25)
		generic.paint_transformed_texture(generic_chunk, &"decal", Vector2i(i % 32, i / 32), texture, -90, rng.randi_range(0, 3), rng.randf() < 0.5, rng.randf() < 0.5, Color(1, 1, 1, alpha))
	var generic_sources := (generic.get("_tile_set") as TileSet).get_source_count()
	print("ChunkTileDecalCacheTest: 60 random decals -> %d sources on the generic path, 1 on the decal path" % generic_sources)
	_check(generic_sources > 20, "the generic path really did build a source per key (%d)" % generic_sources)
	host.queue_free()
	generic_host.queue_free()


func _test_clear_chunk_exact() -> void:
	var renderer := RendererScript.new()
	var host := _host(renderer)
	var west := _chunk(host, renderer, Vector2i.ZERO)
	var east := _chunk(host, renderer, Vector2i(1, 0))
	# An authored painter filed at coord (0, 0) too (Level1Builder's _geo).
	var authored := _chunk(host, renderer, Vector2i.ZERO)
	var texture := ImageTexture.create_from_image(_probe_image(64))
	for i in range(10):
		renderer.paint_texture(west, &"structure", Vector2i(i, 3), texture, 0)
		renderer.paint_texture(east, &"structure", Vector2i(i, 3), texture, 0)
	renderer.paint_repeating_rect(west, &"floor", Rect2i(2, 2, 4, 4), texture, 128, -95)
	renderer.paint_repeating_rect(east, &"floor", Rect2i(2, 2, 4, 4), texture, 128, -95)
	renderer.paint_decal(west, &"decal", Vector2i(20, 20), texture, -90, 1, true, false, 0.2)
	renderer.paint_texture(authored, &"structure", Vector2i(30, 30), texture, 0)
	renderer.erase_cell(west, &"structure", Vector2i(0, 3))
	var layers := host.find_children("WorldTiles_*", "TileMapLayer", true, false)
	var before := 0
	for layer in layers:
		before += (layer as TileMapLayer).get_used_cells().size()
	renderer.clear_chunk(west)
	var west_rect := Rect2i(Vector2i.ZERO, Vector2i(32, 32))
	var west_left := 0
	var east_left := 0
	for layer in layers:
		for cell in (layer as TileMapLayer).get_used_cells():
			if west_rect.has_point(cell):
				west_left += 1
			else:
				east_left += 1
	_check(west_left == 0, "clearing the west chunk empties its whole rect, the authored tile filed there included")
	_check(east_left == 10 + 16, "the east chunk's cells survive (%d)" % east_left)
	_check(before == (9 + 16 + 1 + 1) + (10 + 16), "the setup painted what it meant to (%d cells)" % before)
	_check(not (renderer.get("_painted") as Dictionary).has(Vector2i.ZERO), "the cleared chunk's record is dropped")
	renderer.clear_all()
	_check((renderer.get("_painted") as Dictionary).is_empty(), "clear_all forgets every painted cell")
	host.queue_free()


## The pre-2026-10-04 builder, copied: per-pixel get_pixel(x, y).r8.
func _reference_noise_bytes() -> PackedByteArray:
	var size := GroundSplatRenderer.NOISE_PX
	var specs := [[9173, 1.0 / 20.0, 2], [9304, 1.0 / 20.0, 2], [9435, 1.0 / 7.0, 3], [9566, 1.0 / 10.0, 2]]
	var channels: Array[Image] = []
	for spec in specs:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = int(spec[0])
		noise.frequency = float(spec[1])
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = int(spec[2])
		channels.append(noise.get_seamless_image(size, size))
	var data := PackedByteArray()
	data.resize(size * size * 4)
	for y in size:
		for x in size:
			var i := (y * size + x) * 4
			for channel in 4:
				data[i + channel] = channels[channel].get_pixel(x, y).r8
	return data


func _test_noise_bytes() -> void:
	var started := Time.get_ticks_usec()
	var expected := _reference_noise_bytes()
	var old_ms := float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var image := GroundSplatRenderer.noise_image()
	var new_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(image.get_format() == Image.FORMAT_RGBA8 and image.get_data() == expected, "the splat noise has exactly the old bytes")
	print("ChunkTileDecalCacheTest: splat noise build %.1f ms (per-pixel) vs %.1f ms (planes)" % [old_ms, new_ms])
	_check(new_ms < old_ms, "the plane interleave is faster")
