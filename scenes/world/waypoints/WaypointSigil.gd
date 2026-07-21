extends Node2D
class_name WaypointSigil

@export var base_alpha: float = 0.16
@export var active_alpha: float = 0.26
@export var spin_deg_per_sec: float = 7.5
@export var sparkle_radius: float = 30.0
@export var sparkle_count: int = 7
@export var sparkle_alpha: float = 0.18
@export var z: int = -40

var _t: float = 0.0
var _spark: Array = []

@onready var sigil: Sprite2D = $Sigil

func _ready() -> void:
	z_index = z
	if sigil != null:
		sigil.modulate = Color(1, 1, 1, base_alpha)
		sigil.material = CanvasItemMaterial.new()
		(sigil.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 1000.0) ^ int(global_position.y * 1000.0) ^ 0xBADC0DE
	for i in range(max(0, sparkle_count)):
		_spark.append({
			"a": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(sparkle_radius * 0.35, sparkle_radius),
			"s": rng.randf_range(0.7, 1.6),
			"p": rng.randf_range(0.0, TAU),
		})

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if sigil != null:
		sigil.rotation_degrees += spin_deg_per_sec * dt
		# subtle breathing
		var k := 0.5 + 0.5 * sin(_t * 1.2)
		sigil.modulate.a = lerpf(base_alpha, active_alpha, k)

	queue_redraw()

func _draw() -> void:
	var col: Color = Color(0.55, 0.85, 1.0, sparkle_alpha)

	for s in _spark:
		var a: float = float(s.a) + float(_t) * float(s.s)
		var p: Vector2 = Vector2(cos(a), sin(a)) * float(s.r)

		var tw: float = 0.55 + 0.45 * sin(float(s.p) + float(_t) * 3.2)
		var c: Color = Color(col.r, col.g, col.b, col.a * tw)

		draw_circle(p, 1.5, c)
		draw_circle(p, 3.2, Color(c.r, c.g, c.b, c.a * 0.35))
