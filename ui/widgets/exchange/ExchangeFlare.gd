extends Control
## The seal on a completed trade: a gold star flares where the scales meet, a
## thin ring of light runs outward, and a spray of sparks falls away. Every
## piece frees itself when it is done. Under reduced motion it is only a short
## soft flash. Real time throughout, so it plays whatever the time scale.

const FLARE := preload("res://assets/ui/menu/flare_star.png")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

## Spent rings, as [centre, start time (ms), lifetime (s)].
var _rings: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func burst(global_point: Vector2, strength: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var at := global_point - global_position
	var still := ArcaneMotion.reduced()
	var star := TextureRect.new()
	star.texture = FLARE
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.material = ArcaneParticles.additive()
	star.size = Vector2(220, 220) * strength
	star.pivot_offset = star.size * 0.5
	star.position = at - star.size * 0.5
	star.modulate = Color(1.0, 0.84, 0.56, 0.0)
	add_child(star)
	var tw := star.create_tween().set_ignore_time_scale(true).set_parallel(true)
	if still:
		star.scale = Vector2.ONE * 0.7
		tw.tween_property(star, "modulate:a", 0.75, 0.08)
		tw.chain().tween_property(star, "modulate:a", 0.0, 0.35)
	else:
		star.scale = Vector2.ONE * 0.25
		star.rotation = -0.25
		tw.tween_property(star, "modulate:a", 1.0, 0.07)
		tw.tween_property(star, "scale", Vector2.ONE * 1.25, 0.75).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "rotation", 0.18, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "modulate:a", 0.0, 0.7).set_delay(0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_rings.append([at, Time.get_ticks_msec(), 0.75])
		set_process(true)
		var sparks := ArcaneParticles.select_sparks()
		sparks.amount = 22
		sparks.spread = 180.0
		sparks.direction = Vector2(0, -1)
		sparks.gravity = Vector2(0, 140.0)
		sparks.initial_velocity_min = 90.0
		sparks.initial_velocity_max = 300.0
		sparks.lifetime = 0.95
		sparks.position = at
		add_child(sparks)
		sparks.emitting = true
		sparks.finished.connect(sparks.queue_free)
	tw.chain().tween_callback(star.queue_free)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var alive: Array = []
	for ring: Array in _rings:
		if float(now - int(ring[1])) / 1000.0 < float(ring[2]):
			alive.append(ring)
	_rings = alive
	queue_redraw()
	if _rings.is_empty():
		set_process(false)


func _draw() -> void:
	var now := Time.get_ticks_msec()
	for ring: Array in _rings:
		var t := clampf(float(now - int(ring[1])) / 1000.0 / float(ring[2]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		var r := lerpf(14.0, 230.0, e)
		var a := (1.0 - t) * 0.55
		draw_arc(ring[0], r, 0.0, TAU, 96, Color(1.0, 0.8, 0.5, a), 1.5, true)
		draw_arc(ring[0], r * 0.82, 0.0, TAU, 96, Color(1.0, 0.7, 0.4, a * 0.4), 1.0, true)
