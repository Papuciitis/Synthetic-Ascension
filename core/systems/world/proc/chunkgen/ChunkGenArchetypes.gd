extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _generate_default(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	var roll: float = (0.0 if gen.debug_force_content else rng.randf())
	var a := maxf(0.0, gen.weight_empty)
	var b := a + maxf(0.0, gen.weight_building)
	var c := b + maxf(0.0, gen.weight_ruins)

	if roll < b and roll >= a:
		gen._spawn_building(chunk, rng)
	elif roll < c and roll >= b:
		gen._spawn_ruins(chunk, rng)
	# else: empty


static func _generate_arena(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	# Big open center (for wardstones / gates), cover on the perimeter.
	var cells := gen._cells_per_chunk()
	var cx: int = int(cells / 2.0)
	var cy: int = int(cells / 2.0)
	var clear_half := 6 # clears a 13x13 square

	# Perimeter walls (sparse) + half cover clusters.
	var clusters := rng.randi_range(6, 10)
	for i in range(clusters):
		var x := rng.randi_range(2, cells - 3)
		var y := rng.randi_range(2, cells - 3)
		if abs(x - cx) <= clear_half and abs(y - cy) <= clear_half:
			continue
		gen._spawn_block(chunk, gen.cover_half_scene, x, y)

	# Add a few short wall stubs near edges (LoS breaks).
	var stubs := rng.randi_range(3, 6)
	for i in range(stubs):
		var edge := rng.randi_range(0, 3)
		var stub_len := rng.randi_range(4, 7)
		var sx := 0
		var sy := 0
		var dir := Vector2i.ZERO
		match edge:
			0:
				sx = rng.randi_range(2, cells - 3); sy = 2; dir = Vector2i(0, 1)
			1:
				sx = cells - 3; sy = rng.randi_range(2, cells - 3); dir = Vector2i(-1, 0)
			2:
				sx = rng.randi_range(2, cells - 3); sy = cells - 3; dir = Vector2i(0, -1)
			_:
				sx = 2; sy = rng.randi_range(2, cells - 3); dir = Vector2i(1, 0)

		for j in range(stub_len):
			var x := sx + dir.x * j
			var y := sy + dir.y * j
			if abs(x - cx) <= clear_half and abs(y - cy) <= clear_half:
				continue
			gen._spawn_block(chunk, gen.cover_full_scene, x, y)


static func _generate_courtyard(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	# Mostly open with a few half-cover islands.
	var cells := gen._cells_per_chunk()
	var islands := rng.randi_range(4, 8)
	for i in range(islands):
		var x0 := rng.randi_range(4, cells - 5)
		var y0 := rng.randi_range(4, cells - 5)
		var n := rng.randi_range(3, 6)
		for j in range(n):
			var x := x0 + rng.randi_range(-1, 1)
			var y := y0 + rng.randi_range(-1, 1)
			gen._spawn_block(chunk, gen.cover_half_scene, x, y)

	# Occasional window wall line to suggest architecture without boxing the player in.
	if rng.randf() < 0.35:
		var y := rng.randi_range(6, cells - 7)
		for x in range(6, cells - 6):
			if rng.randf() < 0.15:
				continue
			gen._spawn_block(chunk, gen.cover_window_scene, x, y)


static func _generate_street(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	# Two building masses on the sides, leaving a central lane.
	var cells := gen._cells_per_chunk()
	var lane_w := rng.randi_range(10, 14)
	var lane_x0: int = int((cells - lane_w) / 2.0)

	# Left "building" rectangle
	var left_w := lane_x0 - 2
	if left_w >= 6 and rng.randf() < 0.85:
		var x0 := 2
		var y0 := rng.randi_range(3, 8)
		var h := rng.randi_range(14, 22)
		h = mini(h, cells - y0 - 3)
		gen._spawn_wall_rect_cells(chunk, x0, y0, left_w, h, rng.randi_range(0,3), 2, 2, rng)

	# Right "building" rectangle
	var right_x0 := lane_x0 + lane_w
	var right_w := cells - right_x0 - 2
	if right_w >= 6 and rng.randf() < 0.85:
		var x1 := right_x0
		var y1 := rng.randi_range(3, 8)
		var h2 := rng.randi_range(14, 22)
		h2 = mini(h2, cells - y1 - 3)
		gen._spawn_wall_rect_cells(chunk, x1, y1, right_w, h2, rng.randi_range(0,3), 2, 2, rng)

	# Scatter some half-cover near lane edges.
	var props := rng.randi_range(3, 7)
	for i in range(props):
		var side := (0 if rng.randf() < 0.5 else 1)
		var x := (lane_x0 - 1 if side == 0 else lane_x0 + lane_w)
		x += rng.randi_range(-2, 2)
		var y := rng.randi_range(3, cells - 4)
		gen._spawn_block(chunk, gen.cover_half_scene, clampi(x, 2, cells - 3), y)



# ------------------------------------------------------------
# District / Donjon-ish generation (Phase 1)
# ------------------------------------------------------------

const _DIR_N := 1
const _DIR_E := 2
const _DIR_S := 4
const _DIR_W := 8
