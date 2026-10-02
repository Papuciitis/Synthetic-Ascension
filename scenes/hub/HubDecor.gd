extends Node2D
## Procedural stand-ins for the hub's dressing (buildings, tents, trees,
## banners, braziers, the plaza dais) drawn in the warm top-down 3/4 style of
## the hub reference. Each kind is replaced by art when a matching PNG lands
## in res://assets/textures/hub/ (HubWorld checks before building one), so
## these are placeholders with the right silhouettes, palette and scale.

enum Kind { BUILDING, TENT, TREE, BANNER, BRAZIER, PLAZA, BARREL }

const CELL := 64.0
const OUTLINE := Color(0.08, 0.06, 0.05, 1.0)

var kind: int = Kind.BUILDING
## BUILDING: footprint in world px; the facade sits along the bottom edge.
var rect: Rect2 = Rect2()
var roof_color: Color = Color(0.45, 0.2, 0.15)
var wall_color: Color = Color(0.55, 0.47, 0.36)
var facade_height: float = 1.6 * CELL
var windows: int = 2
var door: bool = true
var chimney: bool = false
var forge: bool = false
## Bays (by index) that carry a cross gable breaking the roofline.
var gables: Array = []
## TENT / BANNER / TREE accents.
var cloth_color: Color = Color(0.2, 0.32, 0.36)
var size: float = 1.0
var seed_value: int = 0
## PLAZA: radii in px.
var radius: float = 5.0 * CELL
var dais_radius: float = 2.2 * CELL
var floor_texture: Texture2D = null
var dais_texture: Texture2D = null

var _clock: float = 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(kind == Kind.BRAZIER or kind == Kind.BANNER)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.BUILDING:
			_draw_building()
		Kind.TENT:
			_draw_tent()
		Kind.TREE:
			_draw_tree()
		Kind.BANNER:
			_draw_banner()
		Kind.BRAZIER:
			_draw_brazier()
		Kind.PLAZA:
			_draw_plaza()
		Kind.BARREL:
			_draw_barrel()


# ---------------------------------------------------------------- buildings

func _draw_building() -> void:
	var r := rect
	var face_top := r.end.y - facade_height
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Contact shadow on the ground in front of the facade.
	draw_rect(Rect2(r.position.x + 6, r.end.y, r.size.x - 12, 10), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(r.position.x + 12, r.end.y + 10, r.size.x - 24, 6), Color(0, 0, 0, 0.18))

	# Facade: plaster between dark timber, a stone plinth at the base.
	var face := Rect2(r.position.x, face_top, r.size.x, facade_height)
	draw_rect(face, wall_color)
	var plinth_h := 14.0
	draw_rect(Rect2(face.position.x, face.end.y - plinth_h, face.size.x, plinth_h), wall_color.darkened(0.45))
	for i in range(int(face.size.x / 22.0)):
		draw_line(Vector2(face.position.x + i * 22.0 + (11.0 if i % 2 else 0.0), face.end.y - plinth_h), Vector2(face.position.x + i * 22.0 + (11.0 if i % 2 else 0.0), face.end.y), OUTLINE, 1.0)
	var beam := wall_color.darkened(0.62)
	var bays := maxi(2, int(round(face.size.x / (1.9 * CELL))))
	var bay_w := face.size.x / bays
	for i in range(bays + 1):
		var x := face.position.x + i * bay_w
		draw_rect(Rect2(x - 4, face_top, 8, facade_height - plinth_h), beam)
	draw_rect(Rect2(face.position.x, face_top + facade_height * 0.42, face.size.x, 6), beam)
	# Door and windows, one per bay, lit from inside.
	var door_bay := floori(bays / 2.0) if door else -1
	var lit := Color(1.0, 0.72, 0.32) if not forge else Color(1.0, 0.5, 0.18)
	var placed_windows := 0
	for i in range(bays):
		var cx := face.position.x + (i + 0.5) * bay_w
		if i == door_bay:
			var dw := 30.0
			var dh := facade_height * 0.62
			var dr := Rect2(cx - dw * 0.5, face.end.y - plinth_h - dh + plinth_h, dw, dh)
			draw_rect(dr.grow(3), beam.darkened(0.3))
			draw_rect(dr, Color(0.28, 0.17, 0.1))
			draw_line(Vector2(cx, dr.position.y), Vector2(cx, dr.end.y), OUTLINE, 1.5)
			draw_circle(Vector2(cx + 8, dr.position.y + dh * 0.55), 2.0, Color(0.85, 0.7, 0.35))
			if forge:
				draw_rect(dr.grow(-4), Color(0.9, 0.38, 0.12, 0.9))
				draw_rect(Rect2(dr.position.x + 6, dr.end.y - 16, dw - 12, 12), Color(1.0, 0.75, 0.3))
			continue
		if placed_windows >= windows:
			continue
		placed_windows += 1
		var ww := 22.0
		var wh := 24.0
		var wr := Rect2(cx - ww * 0.5, face_top + facade_height * 0.14, ww, wh)
		draw_circle(wr.get_center(), 26.0, Color(lit.r, lit.g, lit.b, 0.12))
		draw_rect(wr.grow(3), beam.darkened(0.3))
		draw_rect(wr, lit)
		draw_rect(Rect2(wr.position.x, wr.position.y + wh * 0.6, ww, wh * 0.4), lit.darkened(0.25))
		draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), OUTLINE, 2.0)
		draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), OUTLINE, 2.0)
		# Flower box under some windows.
		if rng.randf() < 0.5:
			draw_rect(Rect2(wr.position.x - 4, wr.end.y + 3, ww + 8, 6), Color(0.35, 0.22, 0.12))
			for f in range(4):
				draw_circle(Vector2(wr.position.x + 2 + f * 6.5, wr.end.y + 2), 3.0, Color(0.75, 0.35, 0.2) if f % 2 else Color(0.45, 0.5, 0.22))
	draw_rect(face, OUTLINE, false, 2.0)

	# Roof: the plane seen from above, shingle rows, a ridge and eaves.
	var roof := Rect2(r.position.x - 6, r.position.y, r.size.x + 12, face_top - r.position.y + 10)
	if roof.size.y > 4:
		draw_rect(roof, roof_color)
		var row_h := 11.0
		var rows := int(roof.size.y / row_h)
		for j in range(rows):
			var y := roof.position.y + j * row_h
			var shade := roof_color.darkened(0.1 + 0.12 * float(j) / maxf(1.0, rows))
			draw_rect(Rect2(roof.position.x, y, roof.size.x, row_h - 2), shade)
			var off := 8.0 if j % 2 else 0.0
			var x := roof.position.x + off
			while x < roof.end.x:
				draw_line(Vector2(x, y), Vector2(x, y + row_h - 2), roof_color.darkened(0.45), 1.0)
				x += 16.0 + rng.randf_range(-2.0, 3.0)
			draw_line(Vector2(roof.position.x, y + row_h - 1), Vector2(roof.end.x, y + row_h - 1), roof_color.darkened(0.55), 1.0)
		# Ridge a third of the way down (we look at the front slope).
		var ridge_y := roof.position.y + roof.size.y * 0.3
		draw_rect(Rect2(roof.position.x, ridge_y - 5, roof.size.x, 10), roof_color.darkened(0.35))
		draw_line(Vector2(roof.position.x, ridge_y - 5), Vector2(roof.end.x, ridge_y - 5), roof_color.lightened(0.25), 2.0)
		# Back slope darker (turned away from the plaza light).
		draw_rect(Rect2(roof.position.x, roof.position.y, roof.size.x, ridge_y - 5 - roof.position.y), Color(0, 0, 0, 0.28))
		# The front slope catches the square's light toward the eave.
		var lit_rows := 4
		for k in range(lit_rows):
			var band_h := (roof.end.y - ridge_y) / lit_rows
			draw_rect(Rect2(roof.position.x, roof.end.y - (k + 1) * band_h, roof.size.x, band_h), Color(1.0, 0.85, 0.6, 0.05 * (lit_rows - k)))
		# Eave shadow onto the facade.
		draw_rect(Rect2(face.position.x, face_top, face.size.x, 8), Color(0, 0, 0, 0.45))
		draw_rect(roof, OUTLINE, false, 2.0)
		if chimney:
			var cx := roof.position.x + roof.size.x * (0.2 + 0.6 * rng.randf())
			var ch := Rect2(cx - 12, ridge_y - 40, 24, 38)
			draw_rect(ch, Color(0.42, 0.36, 0.32))
			for k in range(3):
				draw_line(Vector2(ch.position.x, ch.position.y + 10 + k * 10), Vector2(ch.end.x, ch.position.y + 10 + k * 10), OUTLINE, 1.0)
			draw_rect(Rect2(ch.position.x - 3, ch.position.y - 4, 30, 7), Color(0.3, 0.26, 0.24))
			draw_rect(ch, OUTLINE, false, 2.0)
			for s in range(3):
				draw_circle(Vector2(cx + s * 7, ch.position.y - 14 - s * 14), 7 + s * 3, Color(0.75, 0.75, 0.78, 0.22 - s * 0.05))
	# Cross gables: plaster triangles rising into the roof over some bays.
	for g in gables:
		var gi := int(g)
		if gi < 0 or gi >= bays:
			continue
		var gx0 := face.position.x + gi * bay_w + 6
		var gx1 := gx0 + bay_w - 12
		var apex := Vector2((gx0 + gx1) * 0.5, face_top - bay_w * 0.5)
		# The gable's own roof: two eaves from the apex past the wall.
		var eave_l := Vector2(gx0 - 12, face_top + 6)
		var eave_r := Vector2(gx1 + 12, face_top + 6)
		draw_colored_polygon(PackedVector2Array([eave_l, apex + Vector2(0, -12), eave_r, Vector2(gx1, face_top), apex, Vector2(gx0, face_top)]), roof_color.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(gx0, face_top), apex, Vector2(gx1, face_top)]), wall_color.lightened(0.05))
		draw_line(Vector2(apex.x, apex.y + 4), Vector2(apex.x, face_top), wall_color.darkened(0.62), 5.0)
		draw_line(Vector2(gx0 + 8, face_top - 6), Vector2(gx1 - 8, face_top - 6), wall_color.darkened(0.62), 5.0)
		var gw := apex.lerp(Vector2(apex.x, face_top), 0.55)
		draw_circle(gw, 9.0, Color(0, 0, 0, 0.6))
		draw_circle(gw, 7.0, lit)
		draw_polyline(PackedVector2Array([eave_l, apex + Vector2(0, -12), eave_r]), OUTLINE, 2.0)
		draw_line(apex + Vector2(0, -12), apex + Vector2(0, -20), OUTLINE, 3.0)
	if forge:
		# A hanging anvil sign beside the door.
		var sx := face.position.x + face.size.x * 0.78
		var sy := face_top + facade_height * 0.2
		draw_line(Vector2(sx - 18, sy - 6), Vector2(sx + 18, sy - 6), OUTLINE, 3.0)
		draw_rect(Rect2(sx - 16, sy, 32, 30), Color(0.12, 0.1, 0.09))
		draw_rect(Rect2(sx - 16, sy, 32, 30), Color(0.55, 0.42, 0.2), false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 10, sy + 10), Vector2(sx + 10, sy + 10), Vector2(sx + 5, sy + 16), Vector2(sx + 4, sy + 23), Vector2(sx - 4, sy + 23), Vector2(sx - 5, sy + 16)]), Color(0.85, 0.65, 0.3))


# ---------------------------------------------------------------- tents

func _draw_tent() -> void:
	var w := 2.6 * CELL * size
	var h := 1.3 * CELL * size
	var top := -h - 0.9 * CELL * size
	draw_rect(Rect2(-w * 0.5 + 6, -8, w - 12, 12), Color(0, 0, 0, 0.3))
	# Posts.
	for x in [-w * 0.5 + 6, w * 0.5 - 6]:
		draw_rect(Rect2(x - 3, top + h * 0.6, 6, -top - h * 0.6), Color(0.3, 0.2, 0.12))
	# Counter with goods.
	var counter := Rect2(-w * 0.45, -0.55 * CELL * size, w * 0.9, 0.45 * CELL * size)
	draw_rect(counter, Color(0.42, 0.28, 0.16))
	draw_rect(Rect2(counter.position.x, counter.position.y, counter.size.x, 6), Color(0.55, 0.38, 0.22))
	draw_rect(counter, OUTLINE, false, 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(6):
		var gx := counter.position.x + 10 + i * (counter.size.x - 20) / 5.0
		var goods := [Color(0.7, 0.3, 0.2), Color(0.8, 0.65, 0.3), Color(0.4, 0.5, 0.3), Color(0.55, 0.45, 0.6)]
		draw_circle(Vector2(gx, counter.position.y - 4), rng.randf_range(4.0, 7.0), goods[rng.randi() % goods.size()])
	# Canopy: a sloped cloth with scalloped hem and stripes.
	var canopy := PackedVector2Array([Vector2(-w * 0.5 - 8, top + h), Vector2(-w * 0.4, top), Vector2(w * 0.4, top), Vector2(w * 0.5 + 8, top + h)])
	draw_colored_polygon(canopy, cloth_color)
	var stripes := 5
	for i in range(stripes):
		if i % 2 == 0:
			continue
		var t0 := float(i) / stripes
		var t1 := float(i + 1) / stripes
		draw_colored_polygon(PackedVector2Array([
			canopy[0].lerp(canopy[3], t0), canopy[1].lerp(canopy[2], t0), canopy[1].lerp(canopy[2], t1), canopy[0].lerp(canopy[3], t1)]), cloth_color.darkened(0.3))
	var hem_y := top + h
	var n := 7
	for i in range(n):
		var x0 := -w * 0.5 - 8 + (w + 16) * i / n
		var x1 := -w * 0.5 - 8 + (w + 16) * (i + 1) / n
		draw_colored_polygon(PackedVector2Array([Vector2(x0, hem_y), Vector2(x1, hem_y), Vector2((x0 + x1) * 0.5, hem_y + 12)]), cloth_color.darkened(0.15))
	draw_polyline(PackedVector2Array([canopy[0], canopy[1], canopy[2], canopy[3], canopy[0]]), OUTLINE, 2.0)
	draw_line(canopy[1], canopy[2], cloth_color.lightened(0.3), 2.0)


# ---------------------------------------------------------------- trees

func _draw_tree() -> void:
	var s := size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(6, 4), 46 * s, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-7 * s, -60 * s, 14 * s, 60 * s), Color(0.28, 0.18, 0.11))
	draw_line(Vector2(-7 * s, -60 * s), Vector2(-7 * s, 0), OUTLINE, 2.0)
	draw_line(Vector2(7 * s, -60 * s), Vector2(7 * s, 0), OUTLINE, 2.0)
	# Autumn crown: an outlined silhouette, then shaded clusters.
	var blobs: Array = []
	for i in range(9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 30.0) * s
		blobs.append([Vector2(cos(a) * d * 1.2, -92 * s + sin(a) * d * 0.9), rng.randf_range(24.0, 34.0) * s])
	for b in blobs:
		draw_circle(b[0], b[1] + 3, OUTLINE)
	var base := Color(0.55, 0.42, 0.14).lerp(Color(0.62, 0.3, 0.1), rng.randf())
	for b in blobs:
		draw_circle(b[0], b[1], base.darkened(0.3))
	for b in blobs:
		draw_circle(b[0] + Vector2(-4, -5) * s, b[1] * 0.78, base)
	for b in blobs:
		draw_circle(b[0] + Vector2(-8, -10) * s, b[1] * 0.4, base.lightened(0.22))
	for i in range(14):
		var p := Vector2(rng.randf_range(-44, 44), rng.randf_range(-128, -60)) * s
		draw_circle(p, 3.0 * s, base.lightened(0.35) if i % 2 else base.darkened(0.4))


# ---------------------------------------------------------------- banners

func _draw_banner() -> void:
	var s := size
	var pole_h := 150.0 * s
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(4, 2), 14 * s, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-10 * s, -10 * s, 20 * s, 10 * s), Color(0.3, 0.28, 0.27))
	draw_rect(Rect2(-3 * s, -pole_h, 6 * s, pole_h), Color(0.14, 0.12, 0.12))
	draw_rect(Rect2(-22 * s, -pole_h + 8 * s, 44 * s, 5 * s), Color(0.14, 0.12, 0.12))
	draw_circle(Vector2(0, -pole_h), 5 * s, Color(0.8, 0.62, 0.28))
	var sway := sin(_clock * 1.3 + seed_value) * 2.0 * s
	var top := -pole_h + 13 * s
	var cloth := PackedVector2Array([
		Vector2(-18 * s, top), Vector2(18 * s, top), Vector2(18 * s + sway, top + 78 * s),
		Vector2(0 + sway, top + 64 * s), Vector2(-18 * s + sway, top + 78 * s)])
	draw_colored_polygon(cloth, cloth_color)
	draw_colored_polygon(PackedVector2Array([cloth[0], cloth[1], Vector2(18 * s, top + 8 * s), Vector2(-18 * s, top + 8 * s)]), cloth_color.darkened(0.35))
	draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3], cloth[4], cloth[0]]), OUTLINE, 2.0)
	# Gold rune: the tree glyph from the obelisk.
	var c := Vector2(sway * 0.6, top + 36 * s)
	var gold := Color(0.9, 0.7, 0.3)
	draw_line(c + Vector2(0, -16) * s, c + Vector2(0, 16) * s, gold, 2.5)
	draw_line(c + Vector2(0, -4) * s, c + Vector2(-9, -12) * s, gold, 2.0)
	draw_line(c + Vector2(0, -4) * s, c + Vector2(9, -12) * s, gold, 2.0)
	draw_line(c + Vector2(0, 6) * s, c + Vector2(-9, 0) * s, gold, 2.0)
	draw_line(c + Vector2(0, 6) * s, c + Vector2(9, 0) * s, gold, 2.0)
	draw_arc(c, 20 * s, 0, TAU, 20, Color(gold.r, gold.g, gold.b, 0.6), 1.5)


# ---------------------------------------------------------------- braziers

func _draw_brazier() -> void:
	var s := size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(3, 2), 22 * s, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Stone plinth and iron bowl.
	draw_rect(Rect2(-14 * s, -22 * s, 28 * s, 22 * s), Color(0.36, 0.33, 0.31))
	draw_rect(Rect2(-14 * s, -22 * s, 28 * s, 22 * s), OUTLINE, false, 2.0)
	draw_rect(Rect2(-17 * s, -26 * s, 34 * s, 5 * s), Color(0.46, 0.42, 0.38))
	var bowl := PackedVector2Array([Vector2(-20, -40), Vector2(20, -40), Vector2(14, -27), Vector2(-14, -27)])
	for i in range(bowl.size()):
		bowl[i] *= s
	draw_colored_polygon(bowl, Color(0.17, 0.14, 0.13))
	draw_polyline(PackedVector2Array([bowl[0], bowl[1], bowl[2], bowl[3], bowl[0]]), OUTLINE, 2.0)
	draw_rect(Rect2(-20 * s, -42 * s, 40 * s, 4 * s), Color(0.55, 0.4, 0.22))
	# Flame: three flickering tongues and embers.
	var t := _clock * 9.0 + seed_value
	for i in range(3):
		var fx := (i - 1) * 8.0 * s
		var fh := (22.0 + 8.0 * sin(t + i * 2.1)) * s * (1.2 if i == 1 else 0.85)
		var tip := Vector2(fx + sin(t * 0.7 + i) * 3.0 * s, -42 * s - fh)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 9 * s, -42 * s), tip, Vector2(fx + 9 * s, -42 * s)]), Color(0.95, 0.42, 0.1, 0.95))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 5 * s, -42 * s), tip.lerp(Vector2(fx, -42 * s), 0.35), Vector2(fx + 5 * s, -42 * s)]), Color(1.0, 0.85, 0.4))
	for i in range(3):
		var rise := fmod(_clock * 0.8 + i * 0.33 + seed_value * 0.1, 1.0)
		draw_circle(Vector2(sin(t * 0.3 + i * 2.0) * 10 * s, -60 * s - rise * 40 * s), 1.6, Color(1.0, 0.7, 0.3, 1.0 - rise))


# ---------------------------------------------------------------- barrels

func _draw_barrel() -> void:
	var s := size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(3, 2), 17 * s, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var body := Rect2(-14 * s, -36 * s, 28 * s, 36 * s)
	draw_rect(body, Color(0.42, 0.27, 0.15))
	for i in range(1, 4):
		draw_line(Vector2(body.position.x + i * 7 * s, body.position.y + 6 * s), Vector2(body.position.x + i * 7 * s, body.end.y), Color(0.3, 0.19, 0.1), 1.0)
	for y in [body.position.y + 10 * s, body.end.y - 8 * s]:
		draw_rect(Rect2(body.position.x, y, body.size.x, 4 * s), Color(0.25, 0.23, 0.22))
	draw_set_transform(Vector2(0, body.position.y), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14 * s, Color(0.5, 0.34, 0.2))
	draw_arc(Vector2.ZERO, 14 * s, 0, TAU, 20, OUTLINE, 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(body, OUTLINE, false, 2.0)


# ---------------------------------------------------------------- plaza

## The round plaza: concentric paving courses around a two-step dais.
func _draw_plaza() -> void:
	var uv_scale := 1.0 / 384.0 * 1024.0
	_textured_disc(radius, floor_texture, Color(1.0, 0.84, 0.66), uv_scale)
	# Paving courses: rings with staggered radial joints.
	var courses := 6
	for i in range(courses):
		var r0 := dais_radius + (radius - dais_radius) * float(i) / courses
		var r1 := dais_radius + (radius - dais_radius) * float(i + 1) / courses
		draw_arc(Vector2.ZERO, r1, 0, TAU, 96, Color(0.1, 0.08, 0.06, 0.55), 2.0, true)
		var joints := int(TAU * r1 / 46.0)
		for j in range(joints):
			var a := (float(j) + (0.5 if i % 2 else 0.0)) / joints * TAU
			draw_line(Vector2(cos(a), sin(a)) * r0, Vector2(cos(a), sin(a)) * r1, Color(0.1, 0.08, 0.06, 0.4), 1.5)
	# Outer curb.
	draw_arc(Vector2.ZERO, radius, 0, TAU, 128, Color(0.34, 0.3, 0.27), 12.0, true)
	draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 128, OUTLINE, 2.0, true)
	draw_arc(Vector2.ZERO, radius - 6, 0, TAU, 128, Color(0.5, 0.45, 0.4), 2.0, true)
	# Two-step dais with a soft drop shadow.
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.9))
	draw_circle(Vector2.ZERO, dais_radius + 6, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	for step in range(2):
		var rr := dais_radius * (1.0 - 0.3 * step)
		var lift := -8.0 * step
		draw_circle(Vector2(0, lift + 8), rr, Color(0.2, 0.18, 0.17))
		draw_set_transform(Vector2(0, lift))
		_textured_disc(rr, dais_texture, Color(0.85, 0.8, 0.74).darkened(0.08 * (1 - step)), uv_scale * 0.8)
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2(0, lift), rr, 0, TAU, 72, OUTLINE, 2.0, true)
		draw_arc(Vector2(0, lift), rr - 4, PI * 1.1, PI * 1.9, 32, Color(1, 1, 1, 0.18), 2.0, true)
	# Carved ring of runes on the top step.
	var inner := dais_radius * 0.55
	draw_arc(Vector2(0, -8), inner, 0, TAU, 64, Color(0.85, 0.65, 0.3, 0.55), 2.0, true)
	for k in range(12):
		var a := k / 12.0 * TAU
		draw_line(Vector2(cos(a), sin(a)) * (inner - 6) + Vector2(0, -8), Vector2(cos(a), sin(a)) * (inner + 6) + Vector2(0, -8), Color(0.85, 0.65, 0.3, 0.55), 2.0)


func _textured_disc(r: float, tex: Texture2D, tint: Color, uv_scale: float) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 64
	for i in range(n):
		var p := Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r
		pts.append(p)
		if tex != null:
			uvs.append((p + position) / tex.get_size() * uv_scale)
	if tex != null:
		draw_colored_polygon(pts, tint, uvs, tex)
	else:
		draw_colored_polygon(pts, tint.darkened(0.6))
