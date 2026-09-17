extends Control
class_name AscensionTreeView
## Draws the radial advancement tree and reports hover and clicks.
##
## State colours: owned gold, purchasable amber (breathing), reachable but
## unaffordable dim amber, locked bone, sealed by a conflict dull red, the
## equipped Q / V / Reaction with a bright halo. Zoom with the wheel about
## the cursor, pan by dragging. Everything is drawn in one _draw pass from
## AscensionTreeLayout; nodes are not scene children.

signal node_hovered(id: String)
signal node_clicked(id: String, button: int)

const COLOR_BG := Color(0.07, 0.06, 0.055, 1.0)
const COLOR_RING := Color(0.32, 0.27, 0.22, 0.55)
const COLOR_WEDGE := Color(0.5, 0.4, 0.3, 0.25)
const COLOR_EDGE := Color(0.42, 0.36, 0.3, 0.45)
const COLOR_EDGE_OWNED := Color(0.95, 0.78, 0.4, 0.8)
const COLOR_OWNED := Color(0.96, 0.8, 0.42, 1.0)
const COLOR_BUYABLE := Color(0.9, 0.55, 0.2, 1.0)
const COLOR_REACHABLE := Color(0.55, 0.38, 0.2, 1.0)
const COLOR_LOCKED := Color(0.36, 0.33, 0.3, 1.0)
const COLOR_SEALED := Color(0.5, 0.2, 0.18, 1.0)
const COLOR_EQUIPPED := Color(1.0, 0.95, 0.8, 1.0)
const COLOR_TEXT := Color(0.88, 0.84, 0.78, 1.0)
const CORE_TINT: Dictionary = {"melee": Color(0.85, 0.35, 0.3), "ranged": Color(0.35, 0.65, 0.9), "magic": Color(0.7, 0.45, 0.95)}
const LABEL_KINDS: Array[String] = ["active", "keystone", "axiom", "catastrophe", "evolution", "revelation", "fusion", "union", "gate", "ascendant", "core", "fork"]

var db: AscensionTreeDB = null
var layout: AscensionTreeLayout = null
var ledger: AscensionLedger = null
var followers: int = 0
var zoom: float = 0.55
var offset: Vector2 = Vector2.ZERO
var hovered: String = ""
var selected: String = ""
var _dragging: bool = false
var _drag_moved: float = 0.0
var _states: Dictionary = {}   # id -> "owned" | "buyable" | "reachable" | "locked" | "sealed"
var _time: float = 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	set_process(true)


func setup(tree: AscensionTreeDB, tree_layout: AscensionTreeLayout) -> void:
	db = tree
	layout = tree_layout
	fit()


func fit() -> void:
	if layout == null:
		return
	var extent := maxf(layout.extent(), 100.0)
	zoom = minf(size.x, size.y) * 0.48 / extent
	offset = Vector2.ZERO
	queue_redraw()


func refresh(run_ledger: AscensionLedger, wallet: int) -> void:
	ledger = run_ledger
	followers = wallet
	_states.clear()
	if ledger == null or db == null:
		queue_redraw()
		return
	for id in db.nodes:
		_states[id] = _state_of(String(id))
	queue_redraw()


func _state_of(id: String) -> String:
	if ledger.owns(id) and db.kind(id) != "sink":
		return "owned"
	for other in db.conflicts(id):
		if ledger.owns(other):
			return "sealed"
	var verdict := ledger.can_buy(id, followers, "melee" if db.kind(id) == "gate" else "")
	if db.kind(id) == "gate" and not bool(verdict["ok"]):
		for core in AscensionTreeDB.CORES:
			if bool(ledger.can_buy(id, followers, core)["ok"]):
				verdict = {"ok": true}
				break
	if bool(verdict["ok"]):
		return "owned" if (db.kind(id) == "sink" and ledger.rank(id) > 0) else "buyable"
	var rich := ledger.can_buy(id, 1 << 30, "melee" if db.kind(id) == "gate" else "")
	if bool(rich["ok"]) or (db.kind(id) == "sink" and ledger.rank(id) > 0):
		return "reachable" if ledger.rank(id) == 0 else "owned"
	return "locked"


func state_of(id: String) -> String:
	return String(_states.get(id, "locked"))


func _process(delta: float) -> void:
	_time += delta
	if visible and not _states.is_empty():
		queue_redraw()


# ---------------------------------------------------------------- transforms

func world_to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + offset + point * zoom


func screen_to_world(point: Vector2) -> Vector2:
	return (point - size * 0.5 - offset) / zoom


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if layout == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mouse.pressed:
				var factor := 1.12 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
				var before := screen_to_world(mouse.position)
				zoom = clampf(zoom * factor, 0.2, 3.0)
				var after := screen_to_world(mouse.position)
				offset += (after - before) * zoom
				queue_redraw()
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT or mouse.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0:
					var id := layout.hit(screen_to_world(mouse.position), 6.0 / zoom)
					if not id.is_empty():
						selected = id
						node_clicked.emit(id, mouse.button_index)
						queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging and (motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			offset += motion.relative
			_drag_moved += motion.relative.length()
			queue_redraw()
		var id := layout.hit(screen_to_world(motion.position), 6.0 / zoom)
		if id != hovered:
			hovered = id
			node_hovered.emit(id)
			queue_redraw()


func focus_on(id: String) -> void:
	if layout == null or not layout.positions.has(id):
		return
	offset = -(layout.position_of(id) * zoom)
	selected = id
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	if db == null or layout == null:
		return
	var center := world_to_screen(Vector2.ZERO)
	# rings and territory separators
	for ring in range(1, 7):
		draw_arc(center, float(AscensionTreeLayout.RING_RADIUS[ring]) * zoom, 0.0, TAU, 96, COLOR_RING, 1.0, true)
	for border in AscensionTreeLayout.BORDER_ANGLE:
		var angle := deg_to_rad(float(AscensionTreeLayout.BORDER_ANGLE[border]))
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * 40.0 * zoom, center + dir * 780.0 * zoom, COLOR_WEDGE, 1.0, true)
	for core in AscensionTreeLayout.CORE_ANGLE:
		var angle := deg_to_rad(float(AscensionTreeLayout.CORE_ANGLE[core]))
		var dir := Vector2(cos(angle), sin(angle))
		var tint: Color = CORE_TINT[core]
		tint.a = 0.7 if (ledger != null and ledger.has_core(core)) else 0.3
		if _font != null:
			var label := String(core).to_upper()
			var at := center + dir * 790.0 * zoom
			draw_string(_font, at + Vector2(-20.0, 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, tint)
	# edges
	for id in db.links:
		var from: Vector2 = layout.position_of(String(id))
		for other in db.links[id]:
			if String(other) < String(id):
				continue
			var to: Vector2 = layout.position_of(String(other))
			var owned_edge := ledger != null and ledger.owns(String(id)) and ledger.owns(String(other))
			draw_line(world_to_screen(from), world_to_screen(to), COLOR_EDGE_OWNED if owned_edge else COLOR_EDGE, 1.5 if owned_edge else 1.0, true)
	# nodes
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	for id in db.nodes:
		var sid := String(id)
		var at := world_to_screen(layout.position_of(sid))
		var radius := layout.radius_of(sid) * zoom
		var kind := db.kind(sid)
		var state := state_of(sid)
		var color := COLOR_LOCKED
		match state:
			"owned":
				color = COLOR_OWNED
			"buyable":
				color = COLOR_BUYABLE.lerp(COLOR_OWNED, pulse * 0.5)
			"reachable":
				color = COLOR_REACHABLE
			"sealed":
				color = COLOR_SEALED
		var core := db.core_of(sid)
		var fill := Color(0.12, 0.1, 0.09, 1.0)
		if not core.is_empty():
			fill = (CORE_TINT[core] as Color).darkened(0.75)
		if state == "owned":
			fill = color.darkened(0.55)
		draw_circle(at, radius, fill)
		var width := 2.0 if state != "locked" else 1.0
		if kind in ["keystone", "catastrophe", "axiom"]:
			_draw_polygon(at, radius, 6 if kind == "keystone" else (3 if kind == "axiom" else 8), color, width)
		elif kind == "fork":
			_draw_polygon(at, radius, 4, color, width)
		elif kind == "sink":
			draw_rect(Rect2(at - Vector2.ONE * radius * 0.8, Vector2.ONE * radius * 1.6), color, false, width)
			if ledger != null and ledger.rank(sid) > 0 and _font != null:
				draw_string(_font, at + Vector2(-radius, radius + 12.0), "x%d" % ledger.rank(sid), HORIZONTAL_ALIGNMENT_CENTER, int(radius * 2.0), 10, COLOR_OWNED)
		else:
			draw_arc(at, radius, 0.0, TAU, 32, color, width, true)
		if ledger != null and ledger.is_equipped(sid):
			draw_arc(at, radius + 4.0, 0.0, TAU, 32, COLOR_EQUIPPED, 1.5, true)
		if sid == selected:
			draw_arc(at, radius + 7.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 1.0, true)
		elif sid == hovered:
			draw_arc(at, radius + 5.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.5), 1.0, true)
		if _font != null and (kind in LABEL_KINDS or zoom >= 0.9) and kind != "mutation" and kind != "revelation_mutation":
			var label_text := String(db.node(sid).get("name", sid))
			var font_size := 11 if kind in LABEL_KINDS else 9
			draw_string(_font, at + Vector2(-60.0, radius + 12.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 120, font_size, COLOR_TEXT if state != "locked" else COLOR_LOCKED)


func _draw_polygon(at: Vector2, radius: float, sides: int, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(sides + 1):
		var angle := -PI * 0.5 + TAU * float(i) / float(sides)
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, width, true)
