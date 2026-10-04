extends Node
## The square's people: the service NPCs at their stations, a smith at the
## forge, Beka, and a crowd of the movement's supporters whose size follows
## the player's Followers (a log curve with a cap, so a million Followers is
## a full square, not a million people).
##
## The crowd count is taken on arrival and only grows during the visit:
## spending at the merchant or the tree never makes people vanish in front
## of the player; a sale that raises Followers brings newcomers in through
## the south gate. The next visit re-sizes from what the player arrives with.
##
## People walk a half-cell grid built from HubWorld.solids (the props' visible
## footprints) and the floor outline. They have no collision bodies: they give
## way to the player instead of blocking, and never stand on a station ring or
## in the gate lanes.

const PERSON_SCRIPT := preload("res://scenes/hub/HubPerson.gd")
const BEKA_SCRIPT := preload("res://scenes/hub/HubBeka.gd")
const HubText := preload("res://scenes/hub/ui/HubText.gd")

## Crowd size: CROWD_PER_DOUBLING more people each time Followers double,
## near-linear below CROWD_KNEE, capped. 1k -> 10, 4k -> 15, ~41k and up -> 24.
const CROWD_CAP := 24
const CROWD_PER_DOUBLING := 2.5
const CROWD_KNEE := 60.0

const NAV_CELL := 32.0
## A person's footprint radius on the nav grid.
const PERSON_RADIUS := 14.0
## Nobody idles this close to a station ring, the arrival point or a lane.
const RING_CLEARANCE := 76.0
## How close the player can come before a walker waits for them.
const GIVE_WAY := 38.0
## How many raw path points the smoother tries to skip at once.
const SMOOTH_LOOKAHEAD := 16
## New plans per frame; the rest wait a frame (a whole crowd deciding at
## once must not stall the frame).
const PLANS_PER_FRAME := 2

## Stand-in rigs until the crowd art lands: races cycled, outfits tinted into
## muted work clothes so the crowd is not a copy of the player.
const CROWD_RACES: Array[StringName] = [&"human", &"elf", &"human", &"dragonborn", &"warforged", &"human"]
const CROWD_TINTS: Array[Color] = [
	Color(0.62, 0.55, 0.46), Color(0.46, 0.52, 0.62), Color(0.52, 0.6, 0.46), Color(0.66, 0.54, 0.42),
	Color(0.46, 0.44, 0.52), Color(0.64, 0.48, 0.44), Color(0.55, 0.55, 0.55), Color(0.5, 0.46, 0.4),
]
## Painted crowd sheets (docs/art/2026-09-27-hub-npc-art.md §2): front, back,
## side facing right.
const CROWD_ART: Array[String] = [
	"hub_crowd_pilgrim", "hub_crowd_labourer", "hub_crowd_washer", "hub_crowd_elder",
	"hub_crowd_courier", "hub_crowd_clerk", "hub_crowd_baker", "hub_crowd_mender",
]

## What the crowd and the staff say lives in StoryLines (CROWD and the staff
## pools), keyed by archetype, crowd size, segment and Doctrine; this line
## only when the Followers outgrow the square.
const CROWD_LINE_OVERFLOW := "More of us outside than here."
## What the staff are called over their lines (the crowd speaks unnamed).
const SERVICE_TITLES := {
	"exchanger": "The Exchanger", "quartermaster": "The Quartermaster", "chronicler": "The Chronicler",
	"acolyte": "The Acolyte", "smith": "The Smith",
}
## Speech: how long a bubble takes to come and go, and how far it settles.
const SPEECH_FADE_IN := 0.22
const SPEECH_FADE_OUT := 0.4
const SPEECH_RISE := 6.0

## Service NPCs: feet in cells, stand-in race and tint. They stand
## beside their stalls, not behind them (a 140 px stall hides a person), so
## each gets a footprint.
const SERVICE: Array = [
	{"key": "exchanger", "at": Vector2(8.7, 5.95), "race": &"human", "tint": Color(0.5, 0.56, 0.82), "solid": true},
	{"key": "quartermaster", "at": Vector2(24.7, 12.3), "race": &"warforged", "tint": Color(0.62, 0.72, 0.52), "solid": true},
	{"key": "chronicler", "at": Vector2(5.2, 12.45), "race": &"elf", "tint": Color(0.88, 0.84, 0.74), "solid": true},
	{"key": "acolyte", "at": Vector2(14.75, 13.05), "race": &"human", "tint": Color(0.34, 0.36, 0.62), "solid": true},
	{"key": "smith", "at": Vector2(21.5, 4.62), "race": &"dragonborn", "tint": Color(0.72, 0.6, 0.5), "solid": true},
]
## Seconds a staff line stays up: longer lines get longer, never shorter.
const SERVICE_SPEECH_SECONDS := 3.4
const SERVICE_SPEECH_PER_CHAR := 0.055

var hub: HubWorld = null
var nav := AStarGrid2D.new()
## Each: {"p": person, "state": "walk"|"do", "path": PackedVector2Array,
## "i": int, "act": String, "spot": Vector2, "look": Vector2, "t": float,
## "wait": float, "spoke": float, "speed": float, "kind": String (the
## painted archetype, "" for a rig stand-in)}.
var believers: Array = []
## Each: {"p": person, "key", "at", "near": bool, "next": float}.
var service: Array = []
var beka: Node2D = null
## The Followers this visit is sized from (arrival, raised by any gain).
var visit_level: int = 0

var _rng := RandomNumberGenerator.new()
var _floor := PackedVector2Array()
var _spots: Dictionary = {}
var _no_idle: Array = []
var _time: float = 0.0
var _bark_gate: float = 3.0
var _recent_lines: Array[String] = []
var _spawn_gate: float = 0.0
var _check_gate: float = 0.0
var _speech: Node2D = null
var _said: Array = []
var _painted: Array[Texture2D] = []
## The archetype each painted sheet shows ("pilgrim" ...), parallel to
## _painted (only the sheets that loaded are in either).
var _painted_kinds: Array[String] = []
var _order: int = 0
var _solid_bounds: Array = []
var _plan_budget: int = PLANS_PER_FRAME


static func believer_count(followers: int) -> int:
	if followers <= 0:
		return 0
	var n := roundi(CROWD_PER_DOUBLING * log(1.0 + float(followers) / CROWD_KNEE) / log(2.0))
	return clampi(n, 1, CROWD_CAP)


## Built after the square's props and stations (it needs HubWorld.solids,
## the label layer and the player).
func setup(world: HubWorld, seed_value: int, arrival_followers: int) -> void:
	hub = world
	_rng.seed = seed_value
	# Sized from the Congregation (Followers recruited this attempt), never
	# below what the player arrives holding, so spending at the last Hub never
	# shrinks this one (follower economy audit P5).
	visit_level = maxi(maxi(0, arrival_followers), Global.congregation_crowd_basis() if Global != null else 0)
	for key in CROWD_ART:
		var texture: Texture2D = hub._art(key)
		if texture != null:
			_painted.append(texture)
			_painted_kinds.append(key.trim_prefix("hub_crowd_"))
	_speech = Node2D.new()
	_speech.name = "CrowdSpeech"
	# Under the station signs and prompts: what the key does stays on top.
	_speech.z_index = -1
	_speech.draw.connect(_draw_speech)
	hub._label_layer.add_child(_speech)
	for entry in SERVICE:
		if bool(entry["solid"]):
			hub._footprint(hub._cell(entry["at"].x, entry["at"].y), 30.0)
	_floor = hub._polygon_px(hub.COURTYARD_POLYGON)
	_build_nav()
	_build_spots()
	for entry in SERVICE:
		_spawn_service(entry)
	beka = BEKA_SCRIPT.new()
	hub.add_child(beka)
	beka.setup(hub, self, hub._beka_home, hub._beka_equipped())
	var count := believer_count(visit_level)
	for i in range(count):
		_spawn_believer(false)


# ---------------------------------------------------------------- navigation

func _build_nav() -> void:
	_solid_bounds.clear()
	for solid in hub.solids:
		var s: Dictionary = solid
		if s.has("circle"):
			_solid_bounds.append(Rect2(s["circle"], Vector2.ZERO).grow(float(s["r"]) + PERSON_RADIUS))
		elif s.has("box"):
			_solid_bounds.append((s["box"] as Rect2).grow(PERSON_RADIUS))
		else:
			_solid_bounds.append(Rect2(s["ellipse"] - s["radii"], s["radii"] * 2.0).grow(PERSON_RADIUS))
	nav.region = Rect2i(0, 0, (hub.WIDTH + 2) * 2, hub.HEIGHT * 2)
	nav.cell_size = Vector2(NAV_CELL, NAV_CELL)
	nav.offset = Vector2(NAV_CELL, NAV_CELL) * 0.5
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y in range(nav.region.position.y, nav.region.end.y):
		for x in range(nav.region.position.x, nav.region.end.x):
			var id := Vector2i(x, y)
			nav.set_point_solid(id, not is_walkable(_centre(id)))


func _centre(id: Vector2i) -> Vector2:
	return Vector2(id) * NAV_CELL + nav.offset


## Walkable for a person: on the floor with room for their footprint, and
## clear of every solid's visible outline.
func is_walkable(p: Vector2, radius: float = PERSON_RADIUS) -> bool:
	for probe in [p, p + Vector2(radius, 0), p - Vector2(radius, 0), p + Vector2(0, radius), p - Vector2(0, radius)]:
		if not Geometry2D.is_point_in_polygon(probe, _floor):
			return false
	return not _inside_any(p, radius, hub.solids)


func _nearest_open(p: Vector2) -> Vector2i:
	var base := Vector2i(floori(p.x / NAV_CELL), floori(p.y / NAV_CELL))
	for ring in range(0, 5):
		var best := Vector2i(-9999, -9999)
		var best_d := INF
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var id := base + Vector2i(dx, dy)
				if not nav.is_in_boundsv(id) or nav.is_point_solid(id):
					continue
				var d := _centre(id).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = id
		if best.x != -9999:
			return best
	return Vector2i(-9999, -9999)


## A walkable path from `from` to `to` (both feet points), smoothed so people
## walk straight across open paving instead of along grid steps. Empty when
## there is no way through.
func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_open(from)
	var b := _nearest_open(to)
	if a.x == -9999 or b.x == -9999:
		return PackedVector2Array()
	var raw := nav.get_point_path(a, b)
	if raw.is_empty():
		return raw
	if raw.size() == 1:
		# Already in the target's cell: one short step, never an empty path.
		return PackedVector2Array([to if is_walkable(to) else raw[0]])
	if is_walkable(to):
		raw[raw.size() - 1] = to
	# Smooth from where the walker really stands, not its cell's centre, so
	# the first straight leg is checked too.
	if is_walkable(from, PERSON_RADIUS * 0.6):
		raw[0] = from
	var out := PackedVector2Array()
	var i := 0
	while i < raw.size() - 1:
		# Look a bounded way ahead so one plan stays cheap on long paths.
		var j := mini(raw.size() - 1, i + SMOOTH_LOOKAHEAD)
		while j > i + 1 and not _clear_line(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out


## A straight walk from a to b stays on open cells and clear of every solid
## (checked on the real outlines, so a shortcut never clips a corner). The
## grid rejects most lines for free; only solids near the line are tested.
func _clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 8.0) + 1
	var points := PackedVector2Array()
	for k in range(1, steps):
		var at := a.lerp(b, float(k) / steps)
		var id := Vector2i(floori(at.x / NAV_CELL), floori(at.y / NAV_CELL))
		if not nav.is_in_boundsv(id) or nav.is_point_solid(id):
			return false
		points.append(at)
	var r := PERSON_RADIUS * 0.6
	var span := Rect2(a, Vector2.ZERO).expand(b).grow(r + 2.0)
	var near: Array = []
	for n in range(_solid_bounds.size()):
		if (_solid_bounds[n] as Rect2).intersects(span):
			near.append(hub.solids[n])
	for at in points:
		if not Geometry2D.is_point_in_polygon(at, _floor) or _inside_any(at, r, near):
			return false
	return true


func _inside_any(p: Vector2, radius: float, solids: Array) -> bool:
	for solid in solids:
		var s: Dictionary = solid
		if s.has("circle"):
			if p.distance_to(s["circle"]) < float(s["r"]) + radius:
				return true
		elif s.has("box"):
			if (s["box"] as Rect2).grow(radius).has_point(p):
				return true
		elif s.has("ellipse"):
			var d: Vector2 = p - s["ellipse"]
			var rr: Vector2 = s["radii"] + Vector2.ONE * radius
			if (d.x * d.x) / (rr.x * rr.x) + (d.y * d.y) / (rr.y * rr.y) < 1.0:
				return true
	return false


# ---------------------------------------------------------------- places

## Where people go and what they face: stall fronts, the dais, the braziers,
## the forge; loitering picks open paving at run time.
func _build_spots() -> void:
	for station in hub._stations:
		_no_idle.append([(station as Node2D).global_position, RING_CLEARANCE])
	var arrival: Vector2 = hub.STATION_CELLS["arrival"]
	_no_idle.append([hub._cell(arrival.x, arrival.y), RING_CLEARANCE])
	_no_idle.append(Rect2(hub._cell(14.0, 0.0), Vector2(4, 4) * hub.CELL))
	_no_idle.append(Rect2(hub._cell(14.0, 16.0), Vector2(4, 4) * hub.CELL))
	_add_spots("browse", [
		[Vector2(6.2, 6.8), Vector2.UP], [Vector2(9.4, 6.9), Vector2.LEFT],
		[Vector2(26.5, 7.15), Vector2.UP], [Vector2(27.9, 7.15), Vector2.UP],
		[Vector2(27.35, 12.9), Vector2.UP], [Vector2(23.6, 13.95), Vector2.UP],
		[Vector2(2.8, 13.0), Vector2.UP],
	])
	var centre: Vector2 = hub._cell(hub.PLAZA_CENTER.x, hub.PLAZA_CENTER.y)
	var obelisk := centre
	var dais: Array = hub.PLAZA_ART_DAIS_FOOTPRINT if hub._art("hub_plaza") != null else [Vector2.ZERO, Vector2.ONE * hub.DAIS_RADIUS * hub.CELL]
	var pray: Array = []
	for degrees in [160.0, 190.0, 215.0, 240.0, 300.0, 325.0, 350.0, 20.0]:
		var a := deg_to_rad(degrees)
		var p: Vector2 = centre + dais[0] + Vector2(cos(a) * (dais[1].x + 34.0), sin(a) * (dais[1].y + 34.0))
		pray.append([(p - centre) / hub.CELL + hub.PLAZA_CENTER, obelisk])
	_add_spots("pray", pray)
	var warm: Array = []
	for at in hub._brazier_cells():
		var out: Vector2 = (at - hub.PLAZA_CENTER).normalized()
		warm.append([at + out * 0.95, hub._cell(at.x, at.y) + Vector2(0, -20)])
	_add_spots("warm", warm)
	_add_spots("forge", [[Vector2(22.4, 5.1), Vector2.UP], [Vector2(23.6, 5.2), Vector2.UP]])


## Keeps only spots a person can stand on; `look` is a direction or a point.
func _add_spots(activity: String, entries: Array) -> void:
	var kept: Array = []
	for entry in entries:
		var at: Vector2 = hub._cell(entry[0].x, entry[0].y)
		if is_walkable(at) and _idle_ok(at):
			kept.append({"at": at, "look": entry[1]})
	_spots[activity] = kept


func _idle_ok(p: Vector2) -> bool:
	for zone in _no_idle:
		if zone is Rect2:
			if (zone as Rect2).has_point(p):
				return false
		elif p.distance_to(zone[0]) < float(zone[1]):
			return false
	return true


func _spot_free(p: Vector2, except: Dictionary) -> bool:
	for other in believers:
		if other == except:
			continue
		if (other["spot"] as Vector2).distance_to(p) < 40.0:
			return false
	return true


func _random_open_spot() -> Vector2:
	for attempt in range(40):
		var p := Vector2(_rng.randf_range(1.6, 30.4), _rng.randf_range(4.6, 15.4)) * hub.CELL
		if is_walkable(p) and _idle_ok(p) and not nav.is_point_solid(_nearest_open(p)):
			return p
	return hub._cell(10.0, 10.0)


# ---------------------------------------------------------------- people

func _spawn_service(entry: Dictionary) -> void:
	var person: Node2D = PERSON_SCRIPT.new()
	person.name = "Npc_%s" % entry["key"]
	var art: Texture2D = hub._art("hub_npc_%s" % entry["key"])
	if art != null:
		person.setup_painted(art, 1)
	else:
		person.setup_rig(entry["race"], entry["tint"])
	person.position = hub._cell(entry["at"].x, entry["at"].y)
	hub.add_child(person)
	service.append({"p": person, "key": entry["key"], "at": person.position, "near": false, "next": 0.0})


func _spawn_believer(arriving: bool) -> void:
	var person: Node2D = PERSON_SCRIPT.new()
	person.name = "Believer_%d" % _order
	# Who they are is what they wear: the painted sheet's archetype picks
	# their lines; the rig stand-ins speak only the common ones.
	var kind := ""
	if not _painted.is_empty():
		person.setup_painted(_painted[_order % _painted.size()], 3)
		kind = _painted_kinds[_order % _painted_kinds.size()]
	else:
		person.setup_rig(CROWD_RACES[_order % CROWD_RACES.size()], CROWD_TINTS[_order % CROWD_TINTS.size()])
	_order += 1
	var b := {"p": person, "state": "do", "path": PackedVector2Array(), "i": 0, "act": "", "spot": Vector2.ZERO,
		"look": Vector2.DOWN, "t": 0.0, "wait": 0.0, "spoke": -99.0, "speed": _rng.randf_range(44.0, 60.0), "kind": kind}
	believers.append(b)
	if arriving:
		# Newcomers walk in through the south gate.
		person.position = hub._cell(16.0 + _rng.randf_range(-0.8, 0.8), 19.4)
		hub.add_child(person)
		_choose_next(b)
		return
	# The opening crowd is already mid-activity when the player arrives.
	_pick_activity(b)
	person.position = b["spot"]
	b["state"] = "do"
	b["t"] = _rng.randf_range(2.0, 12.0)
	hub.add_child(person)
	_face(b)


func _choose_next(b: Dictionary) -> void:
	_pick_activity(b)
	_walk_to(b, b["spot"])


## Picks what to do next and where (b.act, b.spot, b.look) without moving.
func _pick_activity(b: Dictionary) -> void:
	var roll := _rng.randf() * 12.5
	var act := "loiter"
	if roll < 3.0:
		act = "browse"
	elif roll < 5.0:
		act = "pray"
	elif roll < 6.5:
		act = "warm"
	elif roll < 7.5:
		act = "forge"
	elif roll < 9.0:
		act = "chat"
	var target := Vector2.INF
	var look: Variant = Vector2.DOWN
	if _spots.has(act):
		var options: Array = (_spots[act] as Array).duplicate()
		options.shuffle()
		for option in options:
			if _spot_free(option["at"], b):
				target = option["at"]
				look = option["look"]
				break
	if act == "chat":
		target = _start_chat(b)
		look = b.get("chat_look", Vector2.RIGHT)
	if target == Vector2.INF:
		act = "loiter"
		target = _random_open_spot()
		look = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP][_rng.randi() % 4]
	b["act"] = act
	b["spot"] = target
	b["look"] = look


## Two people talk: the initiator walks over to someone nearby who is
## standing about, and that person waits for them.
func _start_chat(b: Dictionary) -> Vector2:
	var me: Vector2 = (b["p"] as Node2D).position
	var partner: Dictionary = {}
	var best_d := 360.0
	for other in believers:
		if other == b or other["state"] != "do" or other["act"] in ["chat", "pray"]:
			continue
		var d := me.distance_to((other["p"] as Node2D).position)
		if d < best_d:
			best_d = d
			partner = other
	if partner.is_empty():
		return Vector2.INF
	var q: Vector2 = (partner["p"] as Node2D).position
	for side in [-1.0, 1.0]:
		var p := q + Vector2(46.0 * side, 0.0)
		if not (is_walkable(p) and _idle_ok(p) and _spot_free(p, b)):
			continue
		partner["act"] = "chat"
		partner["spot"] = q
		# Each faces the other: the partner toward p, the initiator back.
		partner["look"] = Vector2.RIGHT * side
		# Long enough for the walk over and the talk itself.
		partner["t"] = maxf(float(partner["t"]), best_d / float(b["speed"]) + _rng.randf_range(7.0, 10.0))
		(partner["p"] as Node2D).set_pose(false, &"right" if side > 0.0 else &"left", partner["speed"])
		b["chat_look"] = Vector2.RIGHT * -side
		return p
	return Vector2.INF


func _walk_to(b: Dictionary, target: Vector2) -> void:
	var person: Node2D = b["p"]
	if _plan_budget <= 0:
		# Over this frame's planning budget: stand a frame, then plan.
		b["state"] = "plan"
		b["spot"] = target
		return
	_plan_budget -= 1
	var path := path_between(person.position, target)
	if path.is_empty():
		b["state"] = "do"
		b["t"] = _rng.randf_range(2.0, 4.0)
		b["spot"] = person.position
		return
	b["path"] = path
	b["i"] = 0
	b["wait"] = 0.0
	b["state"] = "walk"


func _face(b: Dictionary) -> void:
	var person: Node2D = b["p"]
	var look: Variant = b["look"]
	if look is Vector2 and (look as Vector2).length() <= 1.01:
		person.set_pose(false, PERSON_SCRIPT.facing_of(look), b["speed"])
	else:
		person.face_towards(look)


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	if hub == null:
		return
	tick(delta)


## One step for everyone (tests call this directly to fast-forward).
func tick(delta: float) -> void:
	_time += delta
	_plan_budget = PLANS_PER_FRAME
	var feet := _player_feet()
	for b in believers:
		_tick_believer(b, delta, feet)
		(b["p"] as Node2D).tick(delta)
	for s in service:
		_tick_service(s, feet)
		(s["p"] as Node2D).tick(delta)
	if beka != null:
		beka.tick(delta)
	_check_gate -= delta
	if _check_gate <= 0.0:
		_check_gate = 0.5
		_grow_with_followers()
		_maybe_bark(feet)
	_tick_speech(delta)


func _player_feet() -> Vector2:
	var player: Node2D = hub._player
	if player == null or not is_instance_valid(player):
		return Vector2.INF
	return player.global_position + Vector2(0.0, hub.FEET)


func _tick_believer(b: Dictionary, delta: float, feet: Vector2) -> void:
	var person: Node2D = b["p"]
	if b["state"] == "plan":
		if _plan_budget > 0:
			_walk_to(b, b["spot"])
		return
	if b["state"] == "walk":
		var path: PackedVector2Array = b["path"]
		var i: int = b["i"]
		if i >= path.size():
			b["state"] = "do"
			b["t"] = _rng.randf_range(5.0, 12.0)
			_face(b)
			return
		var to: Vector2 = path[i] - person.position
		var step := minf(to.length(), float(b["speed"]) * delta)
		var next := person.position + to.normalized() * step
		if feet != Vector2.INF and next.distance_to(feet) < GIVE_WAY and next.distance_to(feet) < person.position.distance_to(feet):
			# The player is in the way: wait, then find something else.
			b["wait"] = float(b["wait"]) + delta
			person.face_towards(feet)
			if float(b["wait"]) > 1.6:
				_choose_next(b)
			return
		b["wait"] = 0.0
		if not is_walkable(next, 4.0):
			# Never step into a prop: plan again from here instead.
			_choose_next(b)
			return
		person.position = next
		person.drive(to.normalized() * float(b["speed"]))
		if to.length() <= step + 0.5:
			b["i"] = i + 1
		return
	b["t"] = float(b["t"]) - delta
	if feet != Vector2.INF and person.position.distance_to(feet) < 26.0:
		# Someone is standing on them: step aside.
		_choose_next(b)
		return
	if float(b["t"]) <= 0.0:
		_choose_next(b)


func _tick_service(s: Dictionary, feet: Vector2) -> void:
	if feet == Vector2.INF:
		return
	var person: Node2D = s["p"]
	var d := feet.distance_to(s["at"])
	if d < 170.0:
		person.face_towards(feet)
	elif person.facing != &"down":
		person.set_pose(false, &"down")
	if d < 120.0 and not bool(s["near"]):
		s["near"] = true
		if _time >= float(s["next"]):
			s["next"] = _time + 18.0
			var line := _service_line(s)
			if line != "":
				say(person, line, maxf(SERVICE_SPEECH_SECONDS, line.length() * SERVICE_SPEECH_PER_CHAR), String(SERVICE_TITLES.get(s["key"], "")))
	elif d > 170.0:
		s["near"] = false


## A staff member's line (StoryDirector.staff_line): the Chronicler relays
## the last account and the Acolyte answers the Doctrine before everyday talk.
func _service_line(s: Dictionary) -> String:
	if s["key"] == "acolyte" and Global != null and Global.pending_big_choice:
		return "A decision waits before the road."
	var aside := ""
	if s["key"] == "chronicler" and beka != null and beka.is_asleep_on_bed():
		aside = "She found the warm spot again."
	return StoryDirector.staff_line(String(s["key"]), _rng, aside)


## Sales and refunds raise the visit's level; newcomers arrive one by one.
func _grow_with_followers() -> void:
	if Global == null:
		return
	visit_level = maxi(visit_level, Global.congregation_crowd_basis())
	if believers.size() < believer_count(visit_level) and _time >= _spawn_gate:
		_spawn_gate = _time + 0.9
		_spawn_believer(true)


func _maybe_bark(feet: Vector2) -> void:
	if feet == Vector2.INF or _time < _bark_gate:
		return
	var best: Dictionary = {}
	var best_d := 96.0
	for b in believers:
		var d := (b["p"] as Node2D).position.distance_to(feet)
		if d < best_d and _time - float(b["spoke"]) > 40.0:
			best_d = d
			best = b
	if best.is_empty():
		return
	var pool: Array[String] = StoryDirector.crowd_pool(String(best.get("kind", "")), visit_level)
	if CROWD_PER_DOUBLING * log(1.0 + float(visit_level) / CROWD_KNEE) / log(2.0) > float(CROWD_CAP) + 0.5:
		pool.append(CROWD_LINE_OVERFLOW)
		pool.append(CROWD_LINE_OVERFLOW)
	for line in _recent_lines:
		while pool.has(line):
			pool.erase(line)
	var text: String = pool[_rng.randi() % pool.size()]
	_recent_lines.append(text)
	if _recent_lines.size() > 3:
		_recent_lines.pop_front()
	best["spoke"] = _time
	_bark_gate = _time + 7.0
	if best["state"] == "do":
		(best["p"] as Node2D).face_towards(feet)
	say(best["p"], text, 3.0)


# ---------------------------------------------------------------- speech

## A short line above someone's head, drawn on the label layer (above the
## player, outside the dusk tint) in a small bubble (HubText.draw_bubble),
## with `title` over it when the speaker is one of the staff. One line per
## speaker at a time. Each entry: [speaker, text, seconds left, seconds,
## layout, box offset]; the layout is measured here once, never per frame.
func say(speaker: Node2D, text: String, seconds: float, title: String = "") -> void:
	for entry in _said:
		if entry[0] == speaker:
			_said.erase(entry)
			break
	_said.append([speaker, text, seconds, seconds, HubText.bubble_layout(text, title), Vector2.INF])
	_speech.queue_redraw()


func _tick_speech(delta: float) -> void:
	if _said.is_empty():
		return
	for entry in _said.duplicate():
		entry[2] = float(entry[2]) - delta
		if float(entry[2]) <= 0.0 or not is_instance_valid(entry[0]):
			_said.erase(entry)
	_speech.queue_redraw()


func _draw_speech() -> void:
	var still := HubText.reduced()
	for entry in _said:
		var speaker: Node2D = entry[0]
		if not is_instance_valid(speaker):
			continue
		var left: float = entry[2]
		var shown: float = float(entry[3]) - left
		var alpha := clampf(left / SPEECH_FADE_OUT, 0.0, 1.0) * clampf(shown / SPEECH_FADE_IN, 0.0, 1.0)
		var height: float = speaker.get("head_height") if speaker.get("head_height") != null else 40.0
		var tip := speaker.global_position + Vector2(0.0, -height - 6.0)
		if not still:
			# The bubble settles into place as it appears.
			tip.y += SPEECH_RISE * (1.0 - HubText.ease_out(shown / SPEECH_FADE_IN))
		# Clear of the signs and prompts: eased toward where it must be, so a
		# prompt coming up beside a line moves the bubble rather than hiding.
		var aim := _bubble_offset(HubText.bubble_rect(tip, entry[4]))
		var offset: Vector2 = entry[5]
		offset = aim if offset == Vector2.INF or still else offset.lerp(aim, 0.25)
		entry[5] = offset
		HubText.draw_bubble(_speech, tip, entry[4], alpha, offset)


## How far a bubble at `rect` must move to keep off every station's sign and
## prompt: sideways first, as far as its tail can still reach the speaker,
## then up over what is left.
func _bubble_offset(rect: Rect2) -> Vector2:
	var offset := Vector2.ZERO
	var slack := maxf(0.0, rect.size.x * 0.5 - HubText.BUBBLE_TAIL - 5.0)
	for station in hub._stations:
		var keep: Rect2 = station.text_rect().grow(4.0)
		var moved := Rect2(rect.position + offset, rect.size)
		if not moved.intersects(keep):
			continue
		var dx := keep.position.x - moved.end.x if moved.get_center().x < keep.get_center().x else keep.end.x - moved.position.x
		offset.x = clampf(offset.x + dx, -slack, slack)
		moved = Rect2(rect.position + offset, rect.size)
		if moved.intersects(keep):
			offset.y -= moved.end.y - keep.position.y
	return offset
