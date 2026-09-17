extends RefCounted
class_name AscensionTreeLayout
## Radial placement of the V4 tree: three Core territories of 120 degrees
## (Melee top, Ranged lower right, Magic lower left), three discipline
## wedges per territory, rings 1-6 outward. Fusions sit on the border
## between the two territories they join, Unions further out on the same
## border, Gates below the centre, milestone picks in the border gutters
## near the centre, and Ascendant in the middle with the three Core anchors
## around it. Mutations orbit their Active or Revelation as satellites.
##
## Pure: computed once from AscensionTreeDB, no scene dependency.

const RING_RADIUS: Array = [0.0, 150.0, 300.0, 440.0, 560.0, 680.0, 800.0]
const CORE_ANGLE: Dictionary = {"melee": -90.0, "ranged": 30.0, "magic": 150.0}
const BORDER_ANGLE: Dictionary = {"MR": -30.0, "RM": 90.0, "MM": 210.0}
const TERRITORY_DEGREES := 120.0
const TERRITORY_USABLE := 112.0
const CORE_ANCHOR_RADIUS := 64.0
const SATELLITE_OFFSET := 58.0
const SATELLITE_STEP := 4.0
## Ring 3 carries locals, forks and keystones; forks and keystones sit on an
## outer arc of the same ring so eight nodes do not share thirty degrees.
const OUTER_ARC_OFFSET := 50.0
const OUTER_ARC_KINDS: Array[String] = ["fork", "keystone"]
const NODE_RADIUS: Dictionary = {
	"core": 22.0, "local": 11.0, "active": 20.0, "mutation": 7.5, "fork": 13.0, "keystone": 17.0,
	"axiom": 15.0, "catastrophe": 17.0, "evolution": 15.0, "revelation": 20.0, "revelation_mutation": 7.5,
	"sink": 11.0, "fusion": 14.0, "union": 18.0, "gate": 16.0, "ascendant": 26.0, "choice": 8.0,
}

var positions: Dictionary = {}   # id -> Vector2
var angles: Dictionary = {}      # id -> degrees
var radii: Dictionary = {}       # id -> node radius
var discipline_order: Dictionary = {}  # core -> Array of codes
var discipline_center: Dictionary = {} # code -> degrees
var discipline_half: float = 0.0


func compute(db: AscensionTreeDB) -> void:
	positions.clear()
	angles.clear()
	radii.clear()
	_discipline_wedges(db)
	_place_core_and_hub(db)
	_place_discipline_nodes(db)
	_place_satellites(db)
	_place_borders(db)
	_place_choices(db)
	for id in db.nodes:
		if not positions.has(id):
			positions[id] = Vector2.ZERO
			angles[id] = 0.0
		radii[id] = float(NODE_RADIUS.get(db.kind(id), 10.0))


func _discipline_wedges(db: AscensionTreeDB) -> void:
	discipline_order.clear()
	discipline_center.clear()
	for core in AscensionTreeDB.CORES:
		discipline_order[core] = []
	for entry in db.disciplines:
		var dict := entry as Dictionary
		var core := String(dict.get("core", ""))
		if discipline_order.has(core):
			(discipline_order[core] as Array).append(String(dict.get("code", "")))
	for core in discipline_order:
		var codes: Array = discipline_order[core]
		var count := maxi(codes.size(), 1)
		var pitch := TERRITORY_USABLE / float(count)
		discipline_half = pitch * 0.5
		for i in range(codes.size()):
			discipline_center[codes[i]] = float(CORE_ANGLE[core]) - TERRITORY_USABLE * 0.5 + pitch * (float(i) + 0.5)


func _place(id: String, angle_degrees: float, radius: float) -> void:
	var angle := deg_to_rad(angle_degrees)
	positions[id] = Vector2(cos(angle), sin(angle)) * radius
	angles[id] = angle_degrees


func _place_core_and_hub(db: AscensionTreeDB) -> void:
	for core in AscensionTreeDB.CORES:
		_place("core.%s" % core, float(CORE_ANGLE[core]), CORE_ANCHOR_RADIUS)
	if db.has("ASC"):
		positions["ASC"] = Vector2.ZERO
		angles["ASC"] = 0.0
	var asc_satellites := ["ASC1", "ASC2", "ASC3", "ASC.S1", "ASC.S2"]
	var live: Array = []
	for id in asc_satellites:
		if db.has(id):
			live.append(id)
	for i in range(live.size()):
		_place(live[i], 90.0 + (float(i) - float(live.size() - 1) * 0.5) * 18.0, 118.0)
	# Gates on the lower border, between the hub and ring 1.
	if db.has("G1"):
		_place("G1", 90.0, RING_RADIUS[1] + 22.0)
	if db.has("G2"):
		_place("G2", 90.0, RING_RADIUS[2] + 30.0)


func _place_discipline_nodes(db: AscensionTreeDB) -> void:
	var groups: Dictionary = {}  # "code|ring" -> Array of ids
	for id in db.nodes:
		var kind := db.kind(id)
		if kind in ["mutation", "revelation_mutation", "core", "fusion", "union", "gate", "ascendant", "choice"]:
			continue
		if id.begins_with("ASC"):
			continue
		var code := db.discipline_of(id)
		if code.is_empty():
			continue
		var arc := "outer" if (db.ring_of(id) == 3 and kind in OUTER_ARC_KINDS) else "inner"
		var key := "%s|%d|%s" % [code, db.ring_of(id), arc]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(id)
	for key in groups:
		var parts: PackedStringArray = String(key).split("|")
		var code := parts[0]
		var ring := int(parts[1])
		var outer := parts[2] == "outer"
		var ids: Array = groups[key]
		ids.sort_custom(func(a: String, b: String) -> bool: return _order_key(db, a) < _order_key(db, b))
		var center := float(discipline_center.get(code, 0.0))
		var usable := discipline_half * 2.0 * 0.95
		var radius := float(RING_RADIUS[clampi(ring, 1, 6)]) + (OUTER_ARC_OFFSET if outer else 0.0)
		# Spacing weighted by node size, so a wide Active does not crowd the
		# locals beside it: each node takes its diameter plus a gap.
		var total := 0.0
		for id in ids:
			total += 2.0 * float(NODE_RADIUS.get(db.kind(id), 10.0)) + 8.0
		var arc_length := deg_to_rad(usable) * radius
		var scale := minf(1.0, arc_length / maxf(total, 1.0))
		var cursor := -total * 0.5 * scale
		for id in ids:
			var half := (float(NODE_RADIUS.get(db.kind(id), 10.0)) + 4.0) * scale
			cursor += half
			var angle := center + rad_to_deg(cursor / radius)
			_place(id, angle, radius)
			cursor += half


## Locals first by number, then the Q in the middle of its ring, then the rest.
func _order_key(db: AscensionTreeDB, id: String) -> String:
	var kind := db.kind(id)
	var rank: Dictionary = {"local": "1", "fork": "2", "active": "3", "keystone": "4", "axiom": "3", "catastrophe": "5", "evolution": "2", "revelation": "3", "sink": "6"}
	return String(rank.get(kind, "9")) + id


func _place_satellites(db: AscensionTreeDB) -> void:
	var by_parent: Dictionary = {}
	for id in db.nodes:
		var kind := db.kind(id)
		if kind != "mutation" and kind != "revelation_mutation":
			continue
		var parent := ""
		for req_id in db._owned_ids_in(db.node(id).get("requires", {})):
			var req_kind := db.kind(req_id)
			if req_kind == "active" or req_kind == "revelation":
				parent = req_id
		if parent.is_empty():
			continue
		if not by_parent.has(parent):
			by_parent[parent] = []
		(by_parent[parent] as Array).append(id)
	for parent in by_parent:
		var ids: Array = by_parent[parent]
		ids.sort()
		if not positions.has(parent):
			continue
		var base := float(angles[parent])
		var radius := (positions[parent] as Vector2).length() + SATELLITE_OFFSET
		for i in range(ids.size()):
			var angle := base + (float(i) - float(ids.size() - 1) * 0.5) * SATELLITE_STEP
			_place(ids[i], angle, radius)


func _place_borders(db: AscensionTreeDB) -> void:
	var fusions_by_border: Dictionary = {}
	for id in db.ids_of_kind("fusion"):
		var border := String(id).substr(0, 2)
		if not fusions_by_border.has(border):
			fusions_by_border[border] = []
		(fusions_by_border[border] as Array).append(id)
	for border in fusions_by_border:
		var ids: Array = fusions_by_border[border]
		ids.sort()
		var center := float(BORDER_ANGLE.get(border, 0.0))
		# Nine Fusions fit inside the gutter's clear angle, a little beyond
		# ring 4 so the outermost never touches a neighbouring Axiom.
		var spread := 32.0
		var count := ids.size()
		for i in range(count):
			var angle := center - spread * 0.5 + spread * (float(i) + 0.5) / float(count)
			_place(ids[i], angle, float(RING_RADIUS[4]) + 24.0)
	for id in db.ids_of_kind("union"):
		var border := String(id).substr(1, 2)
		_place(id, float(BORDER_ANGLE.get(border, 0.0)), float(RING_RADIUS[5]))


func _place_choices(db: AscensionTreeDB) -> void:
	var groups: Dictionary = {"M": "MM", "D": "MR", "P": "RM"}
	var seen: Dictionary = {}
	for id in db.ids_of_kind("choice"):
		if not String(id).begins_with("pick."):
			continue
		var letter := String(id).substr(5, 1)
		var border: String = groups.get(letter, "RM")
		var index := int(seen.get(letter, 0))
		seen[letter] = index + 1
		var center := float(BORDER_ANGLE.get(border, 0.0))
		_place(id, center + (float(index) - 1.0) * 10.0, 205.0)


func radius_of(id: String) -> float:
	return float(radii.get(id, 10.0))


func position_of(id: String) -> Vector2:
	return positions.get(id, Vector2.ZERO)


## The furthest placed point, for fitting the view.
func extent() -> float:
	var best := 0.0
	for id in positions:
		best = maxf(best, (positions[id] as Vector2).length() + radius_of(id))
	return best


## Nearest node to `point` within its own radius plus `slack`, or "".
func hit(point: Vector2, slack: float = 6.0) -> String:
	var best := ""
	var best_distance := INF
	for id in positions:
		var distance := (positions[id] as Vector2).distance_to(point)
		if distance <= radius_of(id) + slack and distance < best_distance:
			best_distance = distance
			best = id
	return best
