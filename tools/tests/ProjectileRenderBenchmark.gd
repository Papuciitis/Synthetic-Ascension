extends SceneTree

## Times the two ways to fill a MultiMesh - per-instance setters against one
## packed buffer write - AND asserts they produce the same thing.
##
## The 12-float layout it packs is the layout production writes: see
## EnemyProxyRenderer.FLOATS_PER_INSTANCE and _write_instance, which hand-pack
## exactly these offsets (basis at 0,1,4,5; origin at 3 and 7; RGBA at 8..11).
## If RenderingServer ever changed that layout the renderers would draw
## garbage while this benchmark carried on reporting a happy speedup - it used
## to call quit() with no argument, so it exited 0 whatever it measured.
##
## Run: <godot> --headless --path . -s res://tools/tests/ProjectileRenderBenchmark.gd

const COUNTS := [100, 500, 1000, 4000]
const WARMUPS := 5
const ITERATIONS := 25
## The setters round-trip through a Transform2D, the packed path writes floats
## straight in, so the two agree to float precision rather than exactly.
const BUFFER_EPSILON := 0.001

var _passes := 0
var _failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


## A MultiMesh under the dummy (headless) renderer stores nothing: the
## per-instance setters are no-ops and get_instance_transform_2d comes back as
## the identity, while a whole-buffer assignment still round-trips. Timing that
## measures the call overhead of nothing - which is why a headless run reports
## the setters as FASTER than the packed write, the reverse of the result this
## benchmark exists to show.
func _renderer_stores_instance_data() -> bool:
	var probe := MultiMesh.new()
	probe.transform_format = MultiMesh.TRANSFORM_2D
	probe.use_colors = true
	probe.mesh = QuadMesh.new()
	probe.instance_count = 1
	probe.set_instance_transform_2d(0, Transform2D(0.0, Vector2(5.0, 7.0)))
	return probe.get_instance_transform_2d(0).origin.is_equal_approx(Vector2(5.0, 7.0))


## The packed layout, checked against Transform2D itself rather than against
## the renderer, so this assertion runs everywhere including headless. These
## are the offsets EnemyProxyRenderer._write_instance hand-packs in production.
func _check_packed_layout() -> void:
	var positions := PackedVector2Array([Vector2(11.0, -3.0)])
	var velocities := PackedVector2Array([Vector2.RIGHT.rotated(0.7)])
	var sizes := PackedVector2Array([Vector2(1.3, 0.6)])
	var colors := PackedColorArray([Color(0.2, 0.4, 0.6, 0.8)])
	var buffer := _build_buffer(positions, velocities, sizes, colors)
	_check(buffer.size() == 12, "one 2D coloured instance packs into 12 floats (%d)" % buffer.size())
	if buffer.size() != 12:
		return
	var expected := Transform2D(velocities[0].angle(), positions[0]).scaled_local(sizes[0])
	var packed_transform := Transform2D(
		Vector2(buffer[0], buffer[4]), Vector2(buffer[1], buffer[5]), Vector2(buffer[3], buffer[7])
	)
	_check(
		packed_transform.is_equal_approx(expected),
		"the packed basis and origin land where the renderer reads them (%s vs %s)"
			% [str(packed_transform), str(expected)]
	)
	_check(
		is_equal_approx(buffer[2], 0.0) and is_equal_approx(buffer[6], 0.0),
		"the two padding floats of the padded transform rows stay zero"
	)
	_check(
		Color(buffer[8], buffer[9], buffer[10], buffer[11]).is_equal_approx(colors[0]),
		"the instance colour follows the transform as RGBA"
	)


func _init() -> void:
	_check_packed_layout()
	var stores_instance_data := _renderer_stores_instance_data()
	if not stores_instance_data:
		print("NOTE  this renderer keeps no per-instance data (the headless dummy does not).")
		print("NOTE  The setter column below therefore times no-op calls and its speedup is")
		print("NOTE  fiction, and the packed-vs-setter comparison cannot run at all.")
		print("NOTE  Run this windowed for a number worth reading.")
	for count in COUNTS:
		var result := _benchmark_count(count, stores_instance_data)
		print(
			"ProjectileRenderBenchmark count=%d setters_median_us=%d bulk_median_us=%d speedup=%.2fx"
			% [
				count,
				int(result.setters),
				int(result.bulk),
				float(result.setters) / maxf(1.0, float(result.bulk)),
			]
		)
		_check(
			int(result.setters) > 0 and int(result.bulk) > 0,
			"count=%d actually timed both paths" % count
		)
		if stores_instance_data:
			_check(
				String(result.mismatch) == "",
				"count=%d packed buffer matches what the setters write (%s)" % [
					count, String(result.mismatch),
				]
			)
	print("ProjectileRenderBenchmark: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)

func _benchmark_count(count: int, compare_against_setters: bool) -> Dictionary:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = count
	var positions := PackedVector2Array()
	var velocities := PackedVector2Array()
	var sizes := PackedVector2Array()
	var colors := PackedColorArray()
	positions.resize(count)
	velocities.resize(count)
	sizes.resize(count)
	colors.resize(count)
	for i in range(count):
		positions[i] = Vector2(float(i % 100) * 8.0, float(i / 100) * 8.0)
		velocities[i] = Vector2.RIGHT.rotated(float(i) * 0.017) * 700.0
		sizes[i] = Vector2(0.8 + float(i % 5) * 0.1, 0.75)
		colors[i] = Color.from_hsv(float(i % 360) / 360.0, 0.8, 1.0)
	var setter_samples: Array[int] = []
	var bulk_samples: Array[int] = []
	for iteration in range(WARMUPS + ITERATIONS):
		var start_setters := Time.get_ticks_usec()
		for i in range(count):
			var transform := Transform2D(velocities[i].angle(), positions[i]).scaled_local(sizes[i])
			multimesh.set_instance_transform_2d(i, transform)
			multimesh.set_instance_color(i, colors[i])
		var setter_us := Time.get_ticks_usec() - start_setters
		var start_bulk := Time.get_ticks_usec()
		multimesh.buffer = _build_buffer(positions, velocities, sizes, colors)
		var bulk_us := Time.get_ticks_usec() - start_bulk
		if iteration >= WARMUPS:
			setter_samples.append(setter_us)
			bulk_samples.append(bulk_us)
	setter_samples.sort()
	bulk_samples.sort()
	# Correctness, not speed: leave the multimesh filled by the SETTERS and
	# compare it against the hand-packed buffer. The timing loop ends on a bulk
	# write, so this re-runs the setter pass first.
	var mismatch := ""
	if not compare_against_setters:
		return {
			"setters": setter_samples[setter_samples.size() / 2],
			"bulk": bulk_samples[bulk_samples.size() / 2],
			"mismatch": mismatch,
		}
	for i in range(count):
		var verify_transform := Transform2D(velocities[i].angle(), positions[i]).scaled_local(sizes[i])
		multimesh.set_instance_transform_2d(i, verify_transform)
		multimesh.set_instance_color(i, colors[i])
	var from_setters: PackedFloat32Array = multimesh.buffer
	var packed := _build_buffer(positions, velocities, sizes, colors)
	if from_setters.size() != packed.size():
		mismatch = "buffer is %d floats, packed %d" % [from_setters.size(), packed.size()]
	else:
		for i in range(from_setters.size()):
			if absf(from_setters[i] - packed[i]) > BUFFER_EPSILON:
				mismatch = "float %d of instance %d: %f vs %f" % [
					i % 12, i / 12, from_setters[i], packed[i],
				]
				break
	return {
		"setters": setter_samples[setter_samples.size() / 2],
		"bulk": bulk_samples[bulk_samples.size() / 2],
		"mismatch": mismatch,
	}


func _build_buffer(
	positions: PackedVector2Array,
	velocities: PackedVector2Array,
	sizes: PackedVector2Array,
	colors: PackedColorArray
) -> PackedFloat32Array:
	var count := positions.size()
	var buffer := PackedFloat32Array()
	buffer.resize(count * 12)
	for i in range(count):
		var angle := velocities[i].angle()
		var c := cos(angle)
		var s := sin(angle)
		var sx := sizes[i].x
		var sy := sizes[i].y
		var base := i * 12
		# Two PADDED ROWS, not two columns: row 0 is (x.x, y.x, 0, origin.x) and
		# row 1 is (x.y, y.y, 0, origin.y), which is what
		# EnemyProxyRenderer._write_instance_transform packs in production. This
		# used to write the transpose (x.y at offset 1, y.x at offset 4), so the
		# arm it was recommending wrote mirrored transforms - invisible because
		# the benchmark asserted nothing.
		buffer[base] = c * sx
		buffer[base + 1] = -s * sy
		buffer[base + 2] = 0.0
		buffer[base + 3] = positions[i].x
		buffer[base + 4] = s * sx
		buffer[base + 5] = c * sy
		buffer[base + 6] = 0.0
		buffer[base + 7] = positions[i].y
		buffer[base + 8] = colors[i].r
		buffer[base + 9] = colors[i].g
		buffer[base + 10] = colors[i].b
		buffer[base + 11] = colors[i].a
	return buffer
