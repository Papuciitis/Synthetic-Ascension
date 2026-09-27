extends Node2D
class_name SpiderlingVisual

@export var body_scale: float = 1.0

@export var body_color: Color = Color(0.12, 0.75, 0.25, 1.0)      # poison-green
@export var outline_color: Color = Color(0.02, 0.10, 0.04, 1.0)
@export var leg_color: Color = Color(0.05, 0.22, 0.09, 1.0)
@export var glow_color: Color = Color(0.45, 1.0, 0.55, 0.20)

@export var wiggle_amp: float = 0.45
@export var wiggle_speed: float = 10.0
@export var z: int = 5

var _t: float = 0.0

func _ready() -> void:
	z_index = z
	# Pixel-art kit (Batch D, 2026-09-27): the kit sprite is the body now, so a
	# Sprite2D child carrying Spiderling10x6.png must not double-draw over it.
	var sprite := get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null:
		sprite.visible = false
	set_process(true)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var s: float = body_scale

	# Thorax anchor: where the old three-segment body sat its glow.
	var r_th: float = 5.3 * s
	var p_th: Vector2 = Vector2(2.8 * s, 0.0)

	# Soft poison glow
	# Pixel-art kit (Batch D, 2026-09-27): the disc sprite replaces the glow circle.
	VfxKit.draw_disc(self, p_th, r_th * 2.25, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a))

	# Pixel-art kit (Batch D, 2026-09-27): one spiderling sprite (it carries its
	# own greens) replaces the three outlined body circles, the two eyes and the
	# eight wiggling legs; the leg wiggle survives as a cheap breathing of the
	# body size on the same phase.
	var wiggle: float = 1.0 + 0.06 * sin(_t * wiggle_speed)
	VfxKit.draw_spiderling(self, Vector2.ZERO, 0.0, 22.0 * s * wiggle, Color(1.0, 1.0, 1.0, 1.0))
