extends Area2D
class_name MagicImpact

@export var radius: float = 48.0
@export var damage: float = 14.0
@export var lifetime: float = 0.22

# visuals
@export var line_width: float = 7.0
@export var fill_alpha: float = 0.10
@export var line_alpha: float = 0.80
@export var dash_count: int = 10
@export var dash_gap: float = 0.22
@export var z: int = 210

# MAGIC PALETTE (unstable-stable)
@export var color_core: Color = Color(1.0, 0.92, 0.98, 1.0)      # pale pink-white
@export var color_glow: Color = Color(0.86, 0.25, 1.0, 1.0)      # magenta glow
@export var color_fill: Color = Color(1.0, 0.42, 0.16, 1.0)      # orange fill

@export var flicker_strength: float = 0.20  # 0 = stable, 0.3 = wild
@export var wobble_strength: float = 0.035  # radius wobble %
@export var wobble_speed: float = 28.0

@onready var shape_node: CollisionShape2D = $CollisionShape2D
var _did_burst: bool = false
var _t: float = 0.0
var _seed: float = 0.0
var source: Node = null


func _ready() -> void:
	_seed = randf() * 1000.0

	if shape_node.shape == null:
		shape_node.shape = CircleShape2D.new()

	var cs: CircleShape2D = shape_node.shape as CircleShape2D
	if cs != null:
		cs.radius = radius
	shape_node.disabled = false

	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# hide old Line2D if it exists
	var old_line := get_node_or_null("Line2D") as Line2D
	if old_line != null:
		old_line.visible = false

	set_process(true)

	await get_tree().physics_frame
	_burst_once()

func _process(dt: float) -> void:
	_t += dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _burst_once() -> void:
	if _did_burst:
		return
	_did_burst = true

	var r2: float = radius * radius

	# The authoritative query reaches both represented and data-only enemies.
	# Critical legacy actors are intentionally left for the compatibility scan
	# below until their Node-owned lifecycle is bridged.
	var combat := get_node_or_null("/root/EnemyCombat") as EnemyCombatService
	if combat != null:
		var handles: Array[int] = []
		combat.gather_in_radius(global_position, radius, handles)
		for handle in handles:
			var actor := combat.actor_for_handle(handle)
			if actor != null and not actor.has_method("_apply_enemy_world_health"):
				continue
			combat.apply_damage(handle, damage, 1, source)

	var hitboxes: Array = get_tree().get_nodes_in_group("enemy_hitbox")
	var legacy_hit_ids: Dictionary = {}

	for h in hitboxes:
		var hb: Area2D = h as Area2D
		if hb == null:
			continue

		if hb.global_position.distance_squared_to(global_position) > r2:
			continue

		var enemy_node: Node = hb.get_parent()
		if enemy_node == null or not enemy_node.is_in_group("enemies") or not enemy_node.has_method("take_damage"):
			continue
		if combat != null:
			var handle := combat.handle_for_actor(enemy_node)
			if handle != EnemyWorldTypes.INVALID_HANDLE and enemy_node.has_method("_apply_enemy_world_health"):
				continue
		var instance_id := enemy_node.get_instance_id()
		if legacy_hit_ids.has(instance_id):
			continue
		legacy_hit_ids[instance_id] = true
		enemy_node.call("take_damage", damage, source)


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw() -> void:
	var p := clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var fade := 1.0 - p
	fade = fade * fade

	# flicker (unstable but controlled)
	var flick := 1.0 + sin((_t * wobble_speed) + _seed) * flicker_strength
	flick = clampf(flick, 0.65, 1.35)

	# expanding ring
	var r0 := radius * 0.22
	var r := lerpf(r0, radius, _ease_out(p))

	# subtle wobble in radius (magic instability)
	var wob := 1.0 + sin((_t * wobble_speed * 0.72) + _seed * 1.7) * wobble_strength
	r *= wob

	var w := lerpf(line_width, line_width * 0.35, p)

	# soft fill early
	var fill_k := clampf(1.0 - (p / 0.55), 0.0, 1.0)
	if fill_k > 0.0 and fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, r * 0.96, Color(color_fill.r, color_fill.g, color_fill.b, fill_alpha * fill_k * fade * flick))

	# dashed bright ring
	var dash_len := TAU / float(max(dash_count, 1))
	var phase := sin(_t * wobble_speed * 0.35 + _seed) * 0.18

	for i in range(dash_count):
		var a0 := i * dash_len + phase
		var a1 := a0 + dash_len * (1.0 - dash_gap)

		draw_arc(Vector2.ZERO, r, a0, a1, 24,
			Color(color_glow.r, color_glow.g, color_glow.b, (line_alpha * 0.55) * fade * flick),
			w * 1.25, true)

		draw_arc(Vector2.ZERO, r, a0, a1, 24,
			Color(color_core.r, color_core.g, color_core.b, line_alpha * fade),
			w, true)

	# trailing faint ring
	draw_arc(Vector2.ZERO, r * 0.86, 0.0, TAU, 56,
		Color(color_glow.r, color_glow.g, color_glow.b, 0.18 * fade),
		maxf(2.0, w * 0.40), true)

	# center pop
	draw_circle(Vector2.ZERO, maxf(2.0, w * 0.35), Color(color_core.r, color_core.g, color_core.b, 0.35 * fade))


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
