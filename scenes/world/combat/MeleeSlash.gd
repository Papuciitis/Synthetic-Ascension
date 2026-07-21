extends Area2D
class_name MeleeSlash

@export var damage: float = 16.0
@export var lifetime: float = 0.10

# visuals
@export var arc_radius: float = 62.0
@export var arc_degrees: float = 145.0
@export var thickness: float = 18.0
@export var rim_width: float = 3.0
@export var z: int = 220

# Color language (melee = "steel + energy edge")
@export var color_core: Color = Color(0.95, 0.97, 1.0, 0.90)      # bright steel
@export var color_edge: Color = Color(0.35, 0.85, 0.95, 0.55)     # teal edge
@export var color_glow: Color = Color(0.12, 0.55, 1.0, 0.22)      # soft blue glow
@export var spark_color: Color = Color(1.0, 0.70, 0.25, 0.55)     # warm metal sparks

@export var edge_glow_mul: float = 0.85
@export var glow_mul: float = 1.0

# tiny spark accents (optional, still “melee” not “magic”)
@export var sparks: int = 6
@export var spark_len: float = 16.0
@export var spark_width: float = 2.0
@export var spark_jitter_deg: float = 9.0

# Hitbox (wedge)
@export var hitbox_segments: int = 8

# optional hit burst
@export var vfx_hit_spokes_scene: PackedScene

var _t: float = 0.0
var _hit_ids: Dictionary = {}
var _seed: float = 0.0
var source: Node = null

# Cached geometry (avoid per-frame allocations)
var _seg_visual: int = 24
var _arc_dirs: PackedVector2Array = PackedVector2Array()
var _poly_pts: PackedVector2Array = PackedVector2Array()
var _a0: float = 0.0
var _a1: float = 0.0


const _HB_PREFIX: StringName = &"HB_"

@onready var _legacy_col: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

func _ready() -> void:
	_seed = randf() * 999.0

	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

	# Disable the legacy capsule hitbox (we generate our own crescent slices).
	if _legacy_col != null:
		_legacy_col.disabled = true

	z_index = z
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		material = CanvasItemMaterial.new()
		(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# hide old Line2D if it exists
	var old_line := get_node_or_null("Line2D") as Line2D
	if old_line != null:
		old_line.visible = false

	_fit_hitbox_to_visual()
	_build_visual_cache()
	set_process(true)
	call_deferred("_scan_initial_overlaps")

func _process(dt: float) -> void:
	_t += dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _scan_initial_overlaps() -> void:
	# If we spawn already overlapping an enemy hitbox, area_entered may not fire reliably.
	# Scanning once after the first physics tick makes melee feel consistent.
	await get_tree().physics_frame
	for a in get_overlapping_areas():
		_on_area_entered(a)

func _fit_hitbox_to_visual() -> void:
	# Clear previously generated slices.
	# IMPORTANT: CollisionShape2D nodes must be DIRECT children of the Area2D to participate in collisions.
	for c in get_children():
		if c is CollisionShape2D and String(c.name).begins_with(String(_HB_PREFIX)):
			c.queue_free()

	var deg := clampf(arc_degrees, 5.0, 340.0)
	var seg: int = max(4, hitbox_segments)

	var r_out := maxf(2.0, arc_radius * 0.95)
	var r_in := maxf(0.0, r_out - thickness)

	# If thickness is too large, fall back to a wedge (better than a broken shape)
	if r_in < 2.0:
		var half_w := deg_to_rad(minf(deg, 170.0)) * 0.5
		var a0 := -half_w
		var a1 := +half_w

		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		for i in range(seg + 1):
			var a := lerpf(a0, a1, float(i) / float(seg))
			pts.append(Vector2(cos(a), sin(a)) * r_out)

		var poly := ConvexPolygonShape2D.new()
		poly.points = pts

		var cs := CollisionShape2D.new()
		cs.name = String(_HB_PREFIX) + "Wedge"
		cs.shape = poly
		add_child(cs)
		return

	# Crescent = thick arc band made from convex quad slices.
	var half := deg_to_rad(deg) * 0.5
	var a_start := -half
	var a_end := +half

	# Optional: if someone cranks arc_degrees huge, keep slices small enough to stay nicely convex.
	var max_step := deg_to_rad(25.0)
	var needed := int(ceil((a_end - a_start) / max_step))
	seg = max(seg, needed)

	for i in range(seg):
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var a0 := lerpf(a_start, a_end, t0)
		var a1 := lerpf(a_start, a_end, t1)

		var p0 := Vector2(cos(a0), sin(a0)) * r_out
		var p1 := Vector2(cos(a1), sin(a1)) * r_out
		var p2 := Vector2(cos(a1), sin(a1)) * r_in
		var p3 := Vector2(cos(a0), sin(a0)) * r_in

		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([p0, p1, p2, p3])

		var cs := CollisionShape2D.new()
		cs.name = "%s%02d" % [String(_HB_PREFIX), i]
		cs.shape = shape
		add_child(cs)

func _build_visual_cache() -> void:
	# Visual cache: precompute unit directions along the arc.
	_seg_visual = clampi(int(arc_degrees / 6.0), 16, 32)
	var half := deg_to_rad(arc_degrees) * 0.5
	_a0 = -half
	_a1 = +half

	_arc_dirs = PackedVector2Array()
	_arc_dirs.resize(_seg_visual + 1)

	for i in range(_seg_visual + 1):
		var a := lerpf(_a0, _a1, float(i) / float(_seg_visual))
		_arc_dirs[i] = Vector2(cos(a), sin(a))

	_poly_pts = PackedVector2Array()
	_poly_pts.resize((_seg_visual + 1) * 2)

func _on_area_entered(area: Area2D) -> void:
	if area == null or not area.is_in_group("enemy_hitbox"):
		return

	var enemy_node: Node = area.get_parent()
	if enemy_node == null or not enemy_node.is_in_group("enemies") or not enemy_node.has_method("take_damage"):
		return

	var id: int = enemy_node.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true

	enemy_node.call("take_damage", damage, source)
	_apply_burn_dot(enemy_node)

	if vfx_hit_spokes_scene != null and enemy_node is Node2D:
		var v: Node = vfx_hit_spokes_scene.instantiate()
		get_tree().current_scene.add_child(v)
		if v.has_method("setup"):
			v.call("setup", (enemy_node as Node2D).global_position)

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw() -> void:
	var p := clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var fade := 1.0 - p
	fade = fade * fade

	# punch early
	var k := _ease_out(minf(p / 0.55, 1.0))
	var r_outer := lerpf(arc_radius * 0.85, arc_radius, k)
	var r_inner := maxf(0.0, r_outer - thickness)

	var half := deg_to_rad(arc_degrees) * 0.5
	var a0 := -half
	var a1 := +half

	var center := Vector2.ZERO

	# main wedge polygon (cached directions; no per-frame array allocations)
	var seg := _seg_visual

	# Fill cached poly points (outer arc forward, inner arc backward)
	for i in range(seg + 1):
		_poly_pts[i] = center + _arc_dirs[i] * r_outer
	for i in range(seg + 1):
		_poly_pts[seg + 1 + i] = center + _arc_dirs[seg - i] * r_inner

	draw_colored_polygon(
		_poly_pts,
		Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade * glow_mul)
	)

	# outer rim (teal edge)
	draw_arc(
		center, r_outer, a0, a1, seg,
		Color(color_edge.r, color_edge.g, color_edge.b, color_edge.a * fade * edge_glow_mul),
		rim_width + 1.0, true
	)

	# inner rim (steel core)
	draw_arc(
		center, r_outer * 0.98, a0, a1, seg,
		Color(color_core.r, color_core.g, color_core.b, color_core.a * fade),
		rim_width, true
	)

	# inner arc faint (depth)
	draw_arc(
		center, r_inner, a0, a1, seg,
		Color(color_core.r, color_core.g, color_core.b, color_core.a * 0.35 * fade),
		maxf(2.0, rim_width * 0.65), true
	)

	# tiny warm sparks (metal scrape)
	if sparks > 0:
		var j := deg_to_rad(spark_jitter_deg)
		for i in range(sparks):
			var u := float(i) / float(max(1, sparks - 1))
			var a := lerpf(a0, a1, u) + sin(_seed + _t * 60.0 + i * 3.1) * j
			var dir := Vector2(cos(a), sin(a))

			var base := dir * lerpf(r_inner + 6.0, r_outer - 6.0, 0.65)
			var end := base + dir * lerpf(spark_len * 0.55, spark_len, u)

			draw_line(
				center + base,
				center + end,
				Color(spark_color.r, spark_color.g, spark_color.b, spark_color.a * fade),
				spark_width, true
			)


func _apply_burn_dot(enemy: Node) -> void:
	if enemy == null:
		return
	if not has_meta("burn_duration"):
		return
	var duration_v: Variant = get_meta("burn_duration")
	var tick_v: Variant = get_meta("burn_tick")
	var stacks_v: Variant = get_meta("burn_stacks")
	var mult_v: Variant = get_meta("burn_tick_mult")

	var duration: float = float(duration_v)
	var tick: float = float(tick_v)
	var stacks: int = int(stacks_v)
	var mult: float = float(mult_v)
	if duration <= 0.0 or tick <= 0.0 or stacks <= 0:
		return

	var dmg_per_tick_per_stack: float = maxf(0.05, damage * mult)

	var dot: BurnDot = null
	var existing: Node = enemy.get_node_or_null("BurnDot")
	if existing != null:
		dot = existing as BurnDot
	if dot == null:
		dot = BurnDot.new()
		dot.name = "BurnDot"
		enemy.add_child(dot)
	dot.setup(enemy, source, stacks, duration, tick, dmg_per_tick_per_stack)
