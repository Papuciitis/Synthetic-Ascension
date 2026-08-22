extends Node2D
class_name ImpactBurstRenderer

# Batched replacement for the per-hit SpokesBurst nodes. Minigun-grade fire
# lands ~8 hits per frame; a node per impact meant ~70 live Node2Ds whose
# antialiased draw_line primitives cost ~290 draw calls on the GL renderer.
# Drawing the same primitives from one canvas item does not help — AA
# polylines do not batch — so the burst is baked into a texture once and
# every active impact renders as one MultiMesh instance: one draw call
# total, animated by per-instance transform (growth + spin) and color
# (additive fade). Visual tuning mirrors VFX_SpokesBurst.gd defaults.

const DURATION := 0.14
const SPOKES := 14
const INNER := 8.0
const OUTER := 74.0
const WIDTH := 3.0
const ALPHA := 0.85
const ROTATE_SPEED := 8.0
const COLOR_CORE := Color(0.95, 0.98, 1.0, 1.0)
const COLOR_GLOW := Color(0.25, 0.60, 1.0, 1.0)
const GLOW_MUL := 0.35
const MAX_BURSTS := 64
const TEXTURE_SIZE := 128

var _positions := PackedVector2Array()
var _ages := PackedFloat32Array()
var _rotations := PackedFloat32Array()
var _spins := PackedFloat32Array()
var _count := 0
var _overwrite_slot := 0
var _rng := RandomNumberGenerator.new()
var _multimesh: MultiMesh = null
var _instance: MultiMeshInstance2D = null


func _ready() -> void:
	z_index = 210
	_rng.randomize()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0) # unit-ish quad; instance scale is in pixels
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = MAX_BURSTS
	_multimesh.visible_instance_count = 0
	_instance = MultiMeshInstance2D.new()
	_instance.name = "BurstBatch"
	_instance.multimesh = _multimesh
	_instance.texture = _bake_burst_texture()
	var burst_material := CanvasItemMaterial.new()
	burst_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_instance.material = burst_material
	add_child(_instance)
	_positions.resize(MAX_BURSTS)
	_ages.resize(MAX_BURSTS)
	_rotations.resize(MAX_BURSTS)
	_spins.resize(MAX_BURSTS)
	set_process(false)


func add_burst(world_position: Vector2) -> void:
	var slot: int
	if _count < MAX_BURSTS:
		slot = _count
		_count += 1
	else:
		slot = _overwrite_slot
		_overwrite_slot = (_overwrite_slot + 1) % MAX_BURSTS
	_positions[slot] = world_position
	_ages[slot] = 0.0
	_rotations[slot] = _rng.randf_range(0.0, TAU)
	_spins[slot] = ROTATE_SPEED if _rng.randf() < 0.5 else -ROTATE_SPEED
	set_process(true)


func active_count() -> int:
	return _count


func clear() -> void:
	_count = 0
	if _multimesh != null:
		_multimesh.visible_instance_count = 0
	set_process(false)


func _process(delta: float) -> void:
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] >= DURATION:
			var last := _count - 1
			_positions[i] = _positions[last]
			_ages[i] = _ages[last]
			_rotations[i] = _rotations[last]
			_spins[i] = _spins[last]
			_count = last
			continue
		_rotations[i] += _spins[i] * delta
		i += 1
	for j in range(_count):
		var progress := clampf(_ages[j] / DURATION, 0.0, 1.0)
		var fade := (1.0 - progress) * (1.0 - progress)
		var radius := lerpf(INNER * 2.0, OUTER, 1.0 - pow(1.0 - progress, 3.0))
		var scale := radius / (float(TEXTURE_SIZE) * 0.5)
		var xform := Transform2D(_rotations[j], _positions[j]).scaled_local(Vector2(scale, scale))
		_multimesh.set_instance_transform_2d(j, xform)
		_multimesh.set_instance_color(j, Color(1.0, 1.0, 1.0, ALPHA * fade))
	_multimesh.visible_instance_count = _count
	if _count == 0:
		set_process(false)


func _bake_burst_texture() -> ImageTexture:
	# One-time bake of the spoke-burst pattern (radial spokes + core glow),
	# jittered like the old per-node version rolled per impact.
	var half := float(TEXTURE_SIZE) * 0.5
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var angles := PackedFloat32Array()
	var lens := PackedFloat32Array()
	var jitter := deg_to_rad(10.0)
	for i in range(SPOKES):
		angles.append(TAU * float(i) / float(SPOKES) + _rng.randf_range(-jitter, jitter))
		lens.append(_rng.randf_range(0.65, 1.10))
	var inner_n := INNER / OUTER
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var p := Vector2((float(x) + 0.5 - half) / half, (float(y) + 0.5 - half) / half)
			var r := p.length()
			if r > 1.0:
				continue
			var theta := p.angle()
			var spoke := 0.0
			for s in range(SPOKES):
				var d := absf(wrapf(theta - angles[s], -PI, PI))
				# Angular half-width shrinks with radius so spokes stay ~WIDTH px.
				var half_width := WIDTH / maxf(r * OUTER, 2.0)
				var along := clampf((r - inner_n) / maxf(lens[s] - inner_n, 0.01), 0.0, 1.0)
				if r < inner_n or r > lens[s]:
					continue
				var tip_fade := 1.0 - along * along
				spoke = maxf(spoke, exp(-pow(d / half_width, 2.0)) * tip_fade)
			var glow := exp(-pow((r - inner_n * 1.15) / 0.06, 2.0)) * GLOW_MUL
			var core := exp(-pow(r / (inner_n * 0.5), 2.0))
			var col := COLOR_CORE * maxf(spoke, core) + COLOR_GLOW * glow
			var alpha := clampf(maxf(spoke, core) + glow, 0.0, 1.0)
			if alpha <= 0.003:
				continue
			image.set_pixel(x, y, Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0), alpha))
	return ImageTexture.create_from_image(image)
