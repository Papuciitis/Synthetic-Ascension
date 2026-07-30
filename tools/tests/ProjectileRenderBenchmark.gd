extends SceneTree

const COUNTS := [100, 500, 1000, 4000]
const WARMUPS := 5
const ITERATIONS := 25


func _init() -> void:
	for count in COUNTS:
		var result := _benchmark_count(count)
		print(
			"ProjectileRenderBenchmark count=%d setters_median_us=%d bulk_median_us=%d speedup=%.2fx"
			% [
				count,
				int(result.setters),
				int(result.bulk),
				float(result.setters) / maxf(1.0, float(result.bulk)),
			]
		)
	quit()


func _benchmark_count(count: int) -> Dictionary:
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
	return {
		"setters": setter_samples[setter_samples.size() / 2],
		"bulk": bulk_samples[bulk_samples.size() / 2],
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
		buffer[base] = c * sx
		buffer[base + 1] = s * sx
		buffer[base + 2] = 0.0
		buffer[base + 3] = positions[i].x
		buffer[base + 4] = -s * sy
		buffer[base + 5] = c * sy
		buffer[base + 6] = 0.0
		buffer[base + 7] = positions[i].y
		buffer[base + 8] = colors[i].r
		buffer[base + 9] = colors[i].g
		buffer[base + 10] = colors[i].b
		buffer[base + 11] = colors[i].a
	return buffer
