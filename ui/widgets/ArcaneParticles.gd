extends RefCounted
## Particle recipes for the front-end screens. All additive, all CPU (the
## Compatibility renderer, and a handful of particles each), all built from one
## soft dot so nothing here needs an art file.

static var _dot: Texture2D = null


static func soft_dot() -> Texture2D:
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.55))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		_dot = texture
	return _dot


static func additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


static func _ramp(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(stop: Array) -> float: return stop[0]))
	gradient.colors = PackedColorArray(stops.map(func(stop: Array) -> Color: return stop[1]))
	return gradient


static func _base(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = soft_dot()
	p.material = additive()
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.randomness = 0.6
	p.emitting = true
	return p


## Sparks lifting off a flame: quick, bright at birth, swaying as they cool.
static func embers(amount: int, strength: float) -> CPUParticles2D:
	var p := _base(amount, 2.8)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2(4.0, -16.0)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 34.0
	p.tangential_accel_min = -14.0
	p.tangential_accel_max = 14.0
	p.damping_min = 2.0
	p.damping_max = 6.0
	p.scale_amount_min = 0.05 * strength + 0.04
	p.scale_amount_max = 0.13 * strength + 0.05
	p.color_ramp = _ramp([
		[0.0, Color(1.0, 0.86, 0.55, 0.0)],
		[0.08, Color(1.0, 0.78, 0.42, 1.0)],
		[0.5, Color(1.0, 0.48, 0.16, 0.75)],
		[1.0, Color(0.6, 0.16, 0.04, 0.0)],
	])
	return p


## Dust hanging in the lamplight: slow, faint, warm.
static func dust() -> CPUParticles2D:
	var p := _base(26, 11.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(400, 300)
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.gravity = Vector2(1.5, -0.6)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 5.0
	p.tangential_accel_min = -1.0
	p.tangential_accel_max = 1.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	p.color_ramp = _ramp([
		[0.0, Color(1.0, 0.82, 0.6, 0.0)],
		[0.3, Color(1.0, 0.82, 0.6, 0.32)],
		[0.7, Color(0.95, 0.78, 0.6, 0.26)],
		[1.0, Color(0.9, 0.75, 0.6, 0.0)],
	])
	return p


## Cold motes climbing the castle beam.
static func arcane_motes() -> CPUParticles2D:
	var p := _base(12, 5.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 200)
	p.direction = Vector2(0, -1)
	p.spread = 8.0
	p.gravity = Vector2(0, -6.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.tangential_accel_min = -3.0
	p.tangential_accel_max = 3.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color_ramp = _ramp([
		[0.0, Color(0.6, 0.8, 1.0, 0.0)],
		[0.2, Color(0.75, 0.88, 1.0, 0.9)],
		[0.8, Color(0.45, 0.62, 1.0, 0.5)],
		[1.0, Color(0.3, 0.45, 1.0, 0.0)],
	])
	return p


## A one-shot spray of gold sparks along a freshly selected menu stroke.
static func select_sparks() -> CPUParticles2D:
	var p := _base(12, 0.75)
	p.preprocess = 0.0
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.direction = Vector2(1, -0.25)
	p.spread = 38.0
	p.gravity = Vector2(0, 60.0)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 220.0
	p.damping_min = 90.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	p.color_ramp = _ramp([
		[0.0, Color(1.0, 0.95, 0.8, 1.0)],
		[0.4, Color(1.0, 0.72, 0.36, 0.9)],
		[1.0, Color(0.9, 0.4, 0.1, 0.0)],
	])
	return p
