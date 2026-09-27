extends Node2D
class_name HubWorld
## The walkable between-segment hub (handoff 2026-09-25 §15): finish a
## segment, arrive in a small sheltered courtyard as a real controllable
## character, walk to the merchant / Ascension station / gear corner /
## quiet alcove, resolve what must be resolved, and leave north into the
## next segment of the same attempt.
##
## The controller owns arrival, pending-choice presentation and departure.
## Stations are entry points into the existing focused panels (the trade
## post, the tree screen); a panel opening never advances segments, rerolls
## stock or replays rewards — Global.on_segment_completed already ran before
## this scene loaded, and the exit gate only routes back into the run.

const PLAYER_SCENE := preload("res://core/actors/player/player.tscn")
const HUB_SHOP_SCENE := preload("res://ui/screens/HubShop.tscn")
const ASCENSION_SCREEN := preload("res://ui/screens/AscensionScreen.tscn")
const MAJOR_CHOICE_SCENE := preload("res://ui/screens/MajorChoice.tscn")
const BAG_UI_SCENE := preload("res://ui/components/BagUI.tscn")
const STATION_SCRIPT := preload("res://scenes/hub/HubStation.gd")
const DECOR_SCRIPT := preload("res://scenes/hub/HubDecor.gd")
const CROWD_SCRIPT := preload("res://scenes/hub/HubCrowd.gd")

const CELL := 64.0
## Courtyard in cells: about 1.7 gameplay screens across the useful space.
const WIDTH := 32
const HEIGHT := 20
const GATE_HALF_W := 2  # gap half-width in cells for arrival / exit
## Market-square pass (2026-09-27, after the hub reference image): a plus-
## shaped square — a north arm to the departure gate, a wide market band, a
## south arm from the arrival — with a round plaza and the Ascension obelisk
## at its heart. Buildings fill the four corners outside the plus, so the
## edge of the walkable floor reads as house fronts, not a wall ring. Walls
## are still the OUTLINE of the rasterised floor (now invisible collision),
## so every floor cell is walkable. The band's corners are square so the
## paving runs right up to the house fronts (chamfers left dark wedges).
const COURTYARD_POLYGON: Array = [
	Vector2(13, 0), Vector2(19, 0), Vector2(19, 4), Vector2(31, 4), Vector2(31, 16), Vector2(19, 16),
	Vector2(19, 20), Vector2(13, 20), Vector2(13, 16), Vector2(1, 16), Vector2(1, 4), Vector2(13, 4),
]
const PLAZA_CENTER := Vector2(16, 10)
const PLAZA_RADIUS := 5.0
const DAIS_RADIUS := 2.1
## hub_plaza.png: how far (as a fraction of its width) the painted dais
## centre sits above the disc's centre (measured on the 2026-09-27 art).
const PLAZA_ART_DAIS_SHIFT := 0.075
## The painted dais's ground outline relative to PLAZA_CENTER, in px: an
## ellipse [centre offset, radii] measured on hub_plaza.png as placed (the
## front riser reaches further south than the back step, 3/4 view).
const PLAZA_ART_DAIS_FOOTPRINT := [Vector2(0, 33), Vector2(152, 143)]
## hub_ascension_obelisk.png: its plinth sits 7 px right of the texture's
## centre, and the plinth's ground centre 27 px above the sprite's bottom.
const OBELISK_FOOT_OFFSET := Vector2(-7, 27)
## The player's collision capsule is centred on the torso; the drawn feet
## are this far below it. Every blocker in the square is authored in feet
## space (where the art meets the ground) and the collision body is lifted
## by this much, so the feet — not the torso — stop at house fronts, props
## and the dais. The capsule's half-width is what keeps the feet clear.
const FEET := PlayerVisualController.FEET_BELOW_ORIGIN
## How much of a prop's visible base the capsule itself already covers.
const CAPSULE_MARGIN := 22.0## Where each service stands, in cells (tests and the probe read these).
const STATION_CELLS := {
	"arrival": Vector2(16, 18.5),
	"exit": Vector2(16, 0.9),
	"ascension": Vector2(16, 13.3),
	"merchant": Vector2(7.5, 7.0),
	"gear": Vector2(25.5, 13.0),
	"alcove": Vector2(5.5, 13.6),
}
## Houses around the square, in cells: [rect, roof, wall, extras]. The
## facade runs along each rect's bottom edge.
const BUILDINGS: Array = [
	[Rect2(-5, -4, 10.5, 8), "red", "plaster", {"chimney": true, "gables": [3]}],
	[Rect2(5.5, -3, 7.5, 7), "slate", "stone", {"windows": 3, "gables": [0]}],
	[Rect2(19, -3, 7, 7), "slate", "stone", {"forge": true, "chimney": true}],
	[Rect2(26, -4, 11, 8), "red", "plaster", {"windows": 3, "gables": [1, 4]}],
	[Rect2(-5, 4.5, 6, 6.5), "slate", "stone", {"door": false, "windows": 1}],
	[Rect2(-5, 11, 6, 5.5), "red", "plaster", {"door": false, "windows": 1}],
	[Rect2(31, 5, 6, 10.5), "red", "stone", {"door": false, "windows": 2}],
	[Rect2(-5, 16, 10.5, 7), "slate", "plaster", {"door": false, "windows": 0}],
	[Rect2(5.5, 16, 7.5, 6.5), "red", "stone", {"door": false, "windows": 0}],
	[Rect2(19, 16, 7.5, 6.5), "slate", "plaster", {"door": false, "windows": 0}],
	[Rect2(26.5, 16, 10.5, 7), "red", "stone", {"door": false, "windows": 0, "chimney": true}],
]
## Building art (batch B, docs/art/2026-09-27-hub-square-art.md), baked at
## world scale by tools/design/bake_hub_art.py: [texture, bottom-centre in
## cells, flip]. Listed back to front — later entries draw over earlier ones.
## Used when every texture is present; otherwise the procedural BUILDINGS.
const BUILDING_ART: Array = [
	["hub_house_wide", Vector2(0.55, 4.25), false],
	["hub_house_stone", Vector2(9.85, 4.25), false],
	["hub_forge", Vector2(22.8, 4.25), false],
	["hub_house_timber", Vector2(32.4, 4.25), false],
	["hub_house_side", Vector2(-1.6, 12.1), false],
	["hub_house_side", Vector2(-1.6, 16.0), false],
	["hub_house_side", Vector2(33.6, 12.1), true],
	["hub_house_side", Vector2(33.6, 16.0), true],
]
## Rows of the back-of-roofs strip, [edge x, direction, eave y, z]: whole
## copies laid edge to edge from `edge x` outward (direction -1 west, +1
## east), the first copy's corner post on the edge, alternately mirrored.
## Copies are never wrapped (the strip has transparent margins, which showed
## as slits), and each row's gutter sits on its eave line. The south rows
## face the square; the z -62 rows are the town behind the north houses and
## the side houses, filling the alleys and the wedges the angled art leaves.
const ROOF_RUNS: Array = [
	[13.0, -1, 16.0, -60], [19.0, 1, 16.0, -60],
	[13.0, -1, 19.0, -60], [19.0, 1, 19.0, -60],
	[13.0, -1, -5.2, -62], [19.0, 1, -5.2, -62],
	[13.0, -1, -2.1, -62], [19.0, 1, -2.1, -62],
	[13.0, -1, 1.0, -62], [19.0, 1, 1.0, -62],
	[1.0, -1, 4.0, -62], [31.0, 1, 4.0, -62],
	[1.0, -1, 7.1, -62], [31.0, 1, 7.1, -62],
	[1.0, -1, 10.2, -62], [31.0, 1, 10.2, -62],
	[1.0, -1, 13.3, -62], [31.0, 1, 13.3, -62],
]
## hub_roofs_back.png as baked: the opaque body spans these columns (the
## same either way round, the margins are symmetric) and the gutter line is
## this row; above it only chimney tips.
const ROOF_BODY := Vector2(16, 852)
const ROOF_EAVE_ROW := 27
## How far past the camera the rows are laid.
const ROOF_REACH_CELLS := 8.0
## Warm pools at the doors and windows of the building art, in cells.
const BUILDING_LIGHTS: Array = [
	Vector2(0.2, 3.2), Vector2(9.2, 3.3), Vector2(23.0, 3.0), Vector2(31.8, 3.2),
]
const ROOF_COLORS := {"red": Color(0.5, 0.22, 0.15), "slate": Color(0.2, 0.24, 0.3)}
const WALL_COLORS := {"plaster": Color(0.62, 0.52, 0.38), "stone": Color(0.46, 0.43, 0.4)}
const TEX_FLOOR := preload("res://assets/world/ground/ground_civic_brick_01.png")
const TEX_WALK := preload("res://assets/world/ground/ground_stone_tiles_01.png")
const TEX_OUTSIDE := preload("res://assets/world/ground/ground_cobble_01.png")
## World px one ground tile covers (WorldArt's street scale).
const GROUND_REPEAT_PX := 384.0
## Dusk: the square is lit by its lamps, braziers and the obelisk.
const DUSK := Color(0.58, 0.54, 0.62)

var _player: Node2D = null
var _panel_layer: CanvasLayer = null
var _open_panel: Node = null
var _gear_bag: Node = null
var _stations: Array[HubStation] = []
var _exit_station: HubStation = null
var _ascension_station: HubStation = null
var _departing: bool = false
## Tests block the real scene change to observe the transition state.
var departure_scene_change_enabled: bool = true
var _major_choice: Node = null
var _beka_home: Vector2 = Vector2.ZERO
var _clock: float = 0.0
## [position, colour, energy, scale] gathered while placing props.
var _lights: Array = []
## Painted brazier sprites, stepped through their flicker frames.
var _braziers: Array[Sprite2D] = []
var _flicker_clock: float = 0.0
## Every blocker in the square, in feet space (see FEET).
var _ground_body: StaticBody2D = null
## The same solids at their VISIBLE size in feet space, for anything that
## routes on foot (the crowd): [{"circle": centre, "r": radius} |
## {"box": Rect2} | {"ellipse": centre, "radii": Vector2}].
var solids: Array = []
## Station names and prompts: world-space text above the player and outside
## the dusk tint (a CanvasLayer has its own canvas, so CanvasModulate skips it).
var _label_layer: CanvasLayer = null
## The square's people (HubCrowd): service NPCs, the Follower crowd, Beka.
var crowd: Node = null
## Tests pin the crowd's choices; -1 picks a fresh seed each visit.
var crowd_seed: int = -1
## The one interactable the interact key would use now (nearest in range).
var _focus: Object = null
var _interact_enabled: bool = true


func _ready() -> void:
	if Global == null:
		return
	if not Global.attempt_active:
		Global.start_new_attempt()
	# The hub is the resume point for this attempt until departure.
	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_HUB_WORLD
		Global.save_current_profile(false)
	get_tree().paused = false
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 120
	add_child(_panel_layer)
	# The hub owns its own developer console (playtest finding: the only
	# instance lived inside the embedded shop and died with it).
	var dev_console_scene := load("res://ui/widgets/PerformanceOverlay.tscn") as PackedScene
	if dev_console_scene != null:
		var console_layer := CanvasLayer.new()
		console_layer.layer = 140
		add_child(console_layer)
		console_layer.add_child(dev_console_scene.instantiate())
	_build_courtyard()
	_spawn_player()
	_build_stations()
	# The crowd is sized from the Followers the player arrives with.
	crowd = CROWD_SCRIPT.new()
	crowd.name = "Crowd"
	add_child(crowd)
	crowd.setup(self, crowd_seed if crowd_seed >= 0 else randi(), Global.followers)
	_update_pending_cue()
	if Global.pending_big_choice:
		call_deferred(&"_open_major_choice")


# ---------------------------------------------------------------- layout

func _cell(x: float, y: float) -> Vector2:
	return Vector2(x, y) * CELL


## The walkable courtyard cells: the rasterised square.
static func courtyard_cells() -> Dictionary:
	return ChunkShapeGen.rasterize_polygon(PackedVector2Array(COURTYARD_POLYGON), Rect2i(Vector2i(-6, -2), Vector2i(WIDTH + 12, HEIGHT + 4)))


## The wall ring around the courtyard with the arrival and exit gates open.
static func courtyard_walls(fill: Dictionary) -> Dictionary:
	var walls: Dictionary = ChunkShapeGen.outline_of_fill(fill)
	@warning_ignore("integer_division")
	var mid := WIDTH / 2
	for x in range(mid - GATE_HALF_W, mid + GATE_HALF_W + 1):
		walls.erase(Vector2i(x, -1))
		walls.erase(Vector2i(x, HEIGHT))
	return walls


## Generated in the reference's order: floor, buildings, collisions, props
## and their lights. Everything is authored, so the square is the same on
## every visit; only the ambient motion (flames, banners) moves.
func _build_courtyard() -> void:
	# Props, stations and the player sort by their feet.
	y_sort_enabled = true
	_label_layer = CanvasLayer.new()
	_label_layer.layer = 1
	_label_layer.follow_viewport_enabled = true
	add_child(_label_layer)
	_generate_floor()
	_place_buildings()
	_set_collisions()
	_place_props()
	_set_lighting()


func _polygon_px(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in cells:
		out.append(_cell(p.x, p.y))
	return out


func _rect_px(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_cell(r.position.x, r.position.y), _cell(r.end.x, r.position.y), _cell(r.end.x, r.end.y), _cell(r.position.x, r.end.y)])


## A tiled ground layer. Split into 6-cell tiles so no single canvas item
## has to take every light in the square (the Compatibility renderer caps
## lights per item).
func _ground(polygon: PackedVector2Array, texture: Texture2D, tint: Color, z: int) -> void:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		bounds = bounds.expand(p)
	var step := 6.0 * CELL
	var y := floorf(bounds.position.y / step) * step
	while y < bounds.end.y:
		var x := floorf(bounds.position.x / step) * step
		while x < bounds.end.x:
			var tile := PackedVector2Array([Vector2(x, y), Vector2(x + step, y), Vector2(x + step, y + step), Vector2(x, y + step)])
			for piece in Geometry2D.intersect_polygons(polygon, tile):
				var poly := Polygon2D.new()
				poly.polygon = piece
				poly.texture = texture
				poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				poly.texture_scale = Vector2.ONE * (float(texture.get_width()) / GROUND_REPEAT_PX)
				poly.color = tint
				poly.z_index = z
				add_child(poly)
			x += step
		y += step


func _generate_floor() -> void:
	# Beyond the square: old cobble under the houses and along the gate
	# roads (mostly covered by roofs; it shows at the road verges).
	_ground(_rect_px(Rect2(-8, -8, WIDTH + 16, HEIGHT + 16)), TEX_OUTSIDE, Color(0.5, 0.45, 0.42), -110)
	# The square: warm flagstones.
	var outline := _polygon_px(COURTYARD_POLYGON)
	_ground(outline, TEX_FLOOR, Color(0.95, 0.8, 0.62), -100)
	# The arrival-to-departure walk: smooth slabs running through both
	# gates and on out of sight.
	_ground(_rect_px(Rect2(14.5, -8, 3, HEIGHT + 16)), TEX_WALK, Color(0.9, 0.8, 0.68), -99)
	# A dark curb along the square's edge, where it meets the house fronts:
	# one line per edge, so no single item spans every light in the square.
	for i in range(outline.size()):
		var curb := Line2D.new()
		curb.points = PackedVector2Array([outline[i], outline[(i + 1) % outline.size()]])
		curb.width = 10.0
		curb.default_color = Color(0.12, 0.1, 0.09, 0.8)
		curb.z_index = -98
		add_child(curb)
	# The gate roads fade into the dark past the arch and the arrival.
	for fade in [Rect2(12, -8, 8, 7.5), Rect2(12, HEIGHT + 0.5, 8, 7.5)]:
		var r: Rect2 = fade
		var shade := Polygon2D.new()
		shade.polygon = _rect_px(r)
		var near_top: bool = r.position.y > 0
		var dark := Color(0.04, 0.035, 0.04, 0.95)
		var clear := Color(0.04, 0.035, 0.04, 0.0)
		shade.vertex_colors = PackedColorArray([clear, clear, dark, dark] if near_top else [dark, dark, clear, clear])
		shade.z_index = -96
		add_child(shade)
	# The round plaza and its dais at the heart of the square: the painted
	# plaza when it exists (fitted to the plaza radius plus its curb), the
	# drawn rings otherwise.
	var plaza_art := _art("hub_plaza")
	if plaza_art != null:
		var disc := Sprite2D.new()
		disc.texture = plaza_art
		var fit := (PLAZA_RADIUS * 2.0 + 0.25) * CELL / float(plaza_art.get_width())
		disc.scale = Vector2.ONE * fit
		# The painting is a raised disc seen slightly from the front, so its
		# dais centre sits above the disc's centre; shift the disc down so
		# the obelisk stands in the middle of the dais.
		disc.position = _cell(PLAZA_CENTER.x, PLAZA_CENTER.y) + Vector2(0.0, PLAZA_ART_DAIS_SHIFT * plaza_art.get_width() * fit)
		disc.z_index = -97
		add_child(disc)
		return
	var plaza := DECOR_SCRIPT.new()
	plaza.kind = DECOR_SCRIPT.Kind.PLAZA
	plaza.position = _cell(PLAZA_CENTER.x, PLAZA_CENTER.y)
	plaza.radius = PLAZA_RADIUS * CELL
	plaza.dais_radius = DAIS_RADIUS * CELL
	plaza.floor_texture = TEX_OUTSIDE
	plaza.dais_texture = TEX_WALK
	plaza.z_index = -97
	add_child(plaza)


func _place_buildings() -> void:
	if _building_art_ready():
		_place_building_art()
		return
	for entry in BUILDINGS:
		var r: Rect2 = entry[0]
		var extras: Dictionary = entry[3]
		var house := DECOR_SCRIPT.new()
		house.kind = DECOR_SCRIPT.Kind.BUILDING
		house.rect = Rect2(_cell(r.position.x, r.position.y), r.size * CELL)
		house.roof_color = ROOF_COLORS[entry[1]]
		house.wall_color = WALL_COLORS[entry[2]]
		house.windows = int(extras.get("windows", 2))
		house.door = bool(extras.get("door", true))
		house.chimney = bool(extras.get("chimney", false))
		house.forge = bool(extras.get("forge", false))
		house.gables = extras.get("gables", [])
		# Houses seen from behind (the south row) show only roof.
		house.facade_height = 1.6 * CELL if r.end.y <= PLAZA_CENTER.y + 6.0 else 0.8 * CELL
		house.seed_value = int(r.position.x * 31.0 + r.position.y * 7.0)
		house.z_index = -60
		add_child(house)


func _art(texture_name: String) -> Texture2D:
	var path := "res://assets/textures/hub/%s.png" % texture_name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _building_art_ready() -> bool:
	for entry in BUILDING_ART:
		if _art(entry[0]) == null:
			return false
	return _art("hub_roofs_back") != null


## The baked art is at world scale, so every sprite is drawn 1:1 with its
## bottom centre on the given cell point.
func _place_building_art() -> void:
	for entry in BUILDING_ART:
		var texture := _art(entry[0])
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.flip_h = bool(entry[2])
		var base: Vector2 = entry[1]
		sprite.position = _cell(base.x, base.y) - Vector2(texture.get_width() * 0.5, texture.get_height())
		sprite.z_index = -60
		add_child(sprite)
	var roofs := _art("hub_roofs_back")
	var step := ROOF_BODY.y - ROOF_BODY.x - 6.0
	var reach := ROOF_REACH_CELLS * CELL
	for r in range(ROOF_RUNS.size()):
		var run: Array = ROOF_RUNS[r]
		# Runs come in west/east pairs; alternate rows start on the other
		# face so chimneys never stack into columns (a wallpaper grid).
		@warning_ignore("integer_division")
		var row := r / 2
		var edge := float(run[0]) * CELL
		var direction := int(run[1])
		var far := (-4.0 * CELL - reach) if direction < 0 else ((WIDTH + 4.0) * CELL + reach)
		var copies := int(ceil(absf(far - edge) / step))
		for k in range(copies):
			var strip := Sprite2D.new()
			strip.texture = roofs
			strip.centered = false
			strip.flip_h = (k + row + (1 if direction > 0 else 0)) % 2 == 1
			# The copy's opaque body is [ROOF_BODY.x, ROOF_BODY.y] either way
			# round; lay bodies edge to edge (with a hair of overlap) outward.
			var body_left := edge - k * step - (ROOF_BODY.y - ROOF_BODY.x) if direction < 0 else edge + k * step
			strip.position = Vector2(body_left - ROOF_BODY.x, float(run[2]) * CELL - ROOF_EAVE_ROW)
			strip.z_index = int(run[3])
			add_child(strip)
	for at in BUILDING_LIGHTS:
		_lights.append([_cell(at.x, at.y), Color(1.0, 0.72, 0.4), 0.7, 1.2])


## The floor outline as merged invisible blockers and the gate roads closed
## a cell past each arch, all in feet space on a body lifted by FEET. The
## props add their own footprints to the same body as they are placed.
func _set_collisions() -> void:
	_ground_body = StaticBody2D.new()
	_ground_body.collision_layer = 257
	_ground_body.collision_mask = 0
	_ground_body.position = Vector2(0.0, -FEET)
	add_child(_ground_body)
	var blockers: Dictionary = courtyard_walls(courtyard_cells())
	for x in range(12, 21):
		blockers[Vector2i(x, -2)] = true
		blockers[Vector2i(x, HEIGHT + 1)] = true
	for x in [13, 19]:
		blockers[Vector2i(x - 1, -1)] = true
		blockers[Vector2i(x + (1 if x == 19 else 0), -1)] = true
		blockers[Vector2i(x - 1, HEIGHT)] = true
		blockers[Vector2i(x + (1 if x == 19 else 0), HEIGHT)] = true
	for rect in ChunkShapeGen.cells_to_rects(blockers):
		_add_box(_ground_body, Rect2(Vector2(rect.position) * CELL, Vector2(rect.size) * CELL))
	# The dais: solid along its drawn outline, obelisk included.
	var centre := _cell(PLAZA_CENTER.x, PLAZA_CENTER.y)
	var radii := Vector2.ONE * DAIS_RADIUS * CELL
	if _art("hub_plaza") != null:
		centre += PLAZA_ART_DAIS_FOOTPRINT[0]
		radii = PLAZA_ART_DAIS_FOOTPRINT[1]
	_add_ellipse(_ground_body, centre, radii - Vector2.ONE * CAPSULE_MARGIN)
	solids.append({"ellipse": centre, "radii": radii})


## A solid footprint on the ground: `radius` is the visible base's half-width;
## the capsule's own width covers the first CAPSULE_MARGIN of it.
func _footprint(at: Vector2, radius: float) -> void:
	_add_circle(_ground_body, at, maxf(3.0, radius - CAPSULE_MARGIN))
	solids.append({"circle": at, "r": radius})


## A solid rectangular footprint (a stall's counter) sitting on `feet`.
func _footprint_box(feet: Vector2, size: Vector2) -> void:
	var inner := Vector2(maxf(6.0, size.x - CAPSULE_MARGIN * 2.0), maxf(6.0, size.y - CAPSULE_MARGIN * 2.0))
	_add_box(_ground_body, Rect2(feet - Vector2(inner.x * 0.5, size.y * 0.5 + inner.y * 0.5), inner))
	solids.append({"box": Rect2(feet - Vector2(size.x * 0.5, size.y), size)})


func _add_ellipse(body: StaticBody2D, centre: Vector2, radii: Vector2) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)


func _add_box(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	shape.position = r.get_center()
	body.add_child(shape)


func _add_circle(body: StaticBody2D, at: Vector2, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = at
	body.add_child(shape)


## The four braziers at the dais corners: the back pair on the paving
## behind the steps, the front pair in front of the painted risers (the dais
## is drawn from slightly in front, so its steps reach further south).
func _brazier_cells() -> Array:
	var out: Array = []
	for offset in [Vector2(-2.45, -2.35), Vector2(2.45, -2.35), Vector2(-2.45, 2.95), Vector2(2.45, 2.95)]:
		out.append(PLAZA_CENTER + offset)
	return out


func _decor(kind: int, at_cell: Vector2, settings: Dictionary = {}) -> Node2D:
	var node := DECOR_SCRIPT.new()
	node.kind = kind
	node.position = _cell(at_cell.x, at_cell.y)
	for key in settings.keys():
		node.set(key, settings[key])
	add_child(node)
	return node


func _place_props() -> void:
	# The Ascension obelisk crowns the dais, its plinth on the dais centre.
	_prop("hub_ascension_obelisk", _cell(PLAZA_CENTER.x, PLAZA_CENTER.y) + OBELISK_FOOT_OFFSET, 240.0)
	for at in _brazier_cells():
		_brazier(at)
		_footprint(_cell(at.x, at.y) - Vector2(0, 10), 30.0)
		# The light sits in the flame, above the bowl, so the stone plinth
		# is lit from above instead of washed from inside.
		_lights.append([_cell(at.x, at.y) + Vector2(0, -78), Color(1.0, 0.66, 0.34), 0.65, 1.3])
	# Banners stand guard around the plaza; lamps line both gate roads and
	# the market band.
	for at in [Vector2(11.2, 6.2), Vector2(20.8, 6.2), Vector2(11.2, 14.4), Vector2(20.8, 14.4)]:
		if _prop("hub_banner", _cell(at.x, at.y), 150.0) == null:
			_decor(DECOR_SCRIPT.Kind.BANNER, at, {"cloth_color": Color(0.14, 0.18, 0.34), "seed_value": int(at.x)})
		_footprint(_cell(at.x, at.y) - Vector2(0, 6), 16.0)
	for at in [Vector2(13.7, 2.6), Vector2(18.3, 2.6), Vector2(13.6, 17.4), Vector2(18.4, 17.4), Vector2(2.6, 10.0), Vector2(29.4, 10.0)]:
		_prop("hub_lamp", _cell(at.x, at.y), 120.0)
		_footprint(_cell(at.x, at.y) - Vector2(0, 5), 14.0)
		_lights.append([_cell(at.x, at.y) + Vector2(0, -98), Color(1.0, 0.74, 0.4), 0.85, 1.5])
	# Trees soften the corners where the square meets the houses and fill
	# the alleys between them; the two tree paintings alternate.
	var tree_at := [Vector2(2.0, 5.1), Vector2(30.0, 5.1), Vector2(2.1, 15.8), Vector2(29.9, 15.8), Vector2(6.0, 4.3), Vector2(27.3, 4.3)]
	for i in range(tree_at.size()):
		var big: bool = i < 4
		var tree := _prop("hub_tree_autumn_a" if i % 2 == 0 else "hub_tree_autumn_b", _cell(tree_at[i].x, tree_at[i].y), (190.0 if i % 2 == 0 else 180.0) * (1.0 if big else 0.85))
		if tree == null:
			_decor(DECOR_SCRIPT.Kind.TREE, tree_at[i], {"seed_value": 5 + i * 17, "size": 1.05 if big else 0.85})
		elif i % 3 == 1:
			tree.flip_h = true
		_footprint(_cell(tree_at[i].x, tree_at[i].y) - Vector2(0, 8), 18.0)
	# Merchant row (north-west): the stall, stacked goods, barrels.
	_prop("hub_merchant_stall", _cell(STATION_CELLS.merchant.x, STATION_CELLS.merchant.y - 1.2), 130.0)
	_footprint_box(_cell(STATION_CELLS.merchant.x, STATION_CELLS.merchant.y - 1.2), Vector2(110, 44))
	_prop("hub_crates", _cell(4.6, 5.4), 64.0)
	_footprint(_cell(4.6, 5.4) - Vector2(0, 14), 30.0)
	_prop("hub_sacks", _cell(5.7, 5.7), 50.0)
	_footprint(_cell(5.7, 5.7) - Vector2(0, 10), 22.0)
	_barrels([Vector2(10.4, 5.2), Vector2(10.9, 5.5)])
	_barrels([Vector2(3.8, 6.1)])
	_stall("hub_stall_green", Vector2(27.2, 6.4), {"cloth_color": Color(0.22, 0.3, 0.2), "seed_value": 3})
	_lights.append([_cell(22.8, 3.0), Color(1.0, 0.5, 0.2), 1.0, 1.6])  # the forge hearth
	# Gear & Stash (south-east): a teal awning over the armour rack.
	_stall("hub_stall_gear", STATION_CELLS.gear + Vector2(0.4, -0.9), {"cloth_color": Color(0.16, 0.3, 0.33), "seed_value": 11})
	_prop("hub_gear_rack", _cell(STATION_CELLS.gear.x - 1.9, STATION_CELLS.gear.y + 0.2), 80.0)
	_footprint(_cell(STATION_CELLS.gear.x - 1.9, STATION_CELLS.gear.y + 0.2) - Vector2(0, 8), 24.0)
	_prop("hub_crates", _cell(STATION_CELLS.gear.x + 2.4, STATION_CELLS.gear.y + 1.6), 64.0)
	_footprint(_cell(STATION_CELLS.gear.x + 2.4, STATION_CELLS.gear.y + 1.6) - Vector2(0, 14), 30.0)
	_barrels([Vector2(28.9, 14.4)])
	_barrels([Vector2(22.6, 15.0)])
	# Quiet Alcove (south-west): a red awning, the statue, Beka's cushion.
	_stall("hub_stall_alcove", Vector2(4.0, 12.3), {"cloth_color": Color(0.5, 0.18, 0.14), "seed_value": 7, "size": 0.9})
	_prop("hub_statue", _cell(9.6, 15.3), 130.0)
	_footprint(_cell(9.6, 15.3) - Vector2(0, 14), 32.0)
	_beka_home = _cell(STATION_CELLS.alcove.x - 1.4, STATION_CELLS.alcove.y + 1.0)
	# The cushion lies flat under Beka, whom the root draws in _draw (a z -1
	# child draws before the root's own z 0 commands).
	_prop("hub_alcove_bed", _beka_home + Vector2(0, 6), 30.0, -1)
	_lights.append([_cell(4.0, 11.6), Color(1.0, 0.7, 0.4), 0.6, 1.1])


## A market stall: the painting when present, the drawn awning otherwise.
func _stall(texture_name: String, at_cell: Vector2, fallback: Dictionary) -> void:
	var sprite := _prop(texture_name, _cell(at_cell.x, at_cell.y), 140.0)
	if sprite == null:
		_decor(DECOR_SCRIPT.Kind.TENT, at_cell, fallback)
	var width := 2.6 * CELL * float(fallback.get("size", 1.0)) if sprite == null else sprite.texture.get_width() * sprite.scale.x
	_footprint_box(_cell(at_cell.x, at_cell.y), Vector2(width * 0.8, 44))


## A barrel group: one painted cluster at the group's centre, or one drawn
## barrel per point.
func _barrels(points: Array) -> void:
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= float(points.size())
	if _prop("hub_barrels", _cell(centre.x, centre.y), 70.0) != null:
		_footprint(_cell(centre.x, centre.y) - Vector2(0, 16), 34.0)
		return
	for p in points:
		_decor(DECOR_SCRIPT.Kind.BARREL, p, {"size": 0.9})
		_footprint(_cell(p.x, p.y) - Vector2(0, 8), 16.0)


## A brazier: the three-frame painted flicker when present (stepped in
## _process), the drawn one otherwise.
func _brazier(at_cell: Vector2) -> void:
	var sheet := _art("hub_brazier_sheet")
	if sheet == null:
		_decor(DECOR_SCRIPT.Kind.BRAZIER, at_cell, {"seed_value": int(at_cell.x * 13.0)})
		return
	var sprite := Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = 3
	var frame_h := float(sheet.get_height())
	sprite.scale = Vector2.ONE * (90.0 / maxf(1.0, frame_h))
	sprite.position = _cell(at_cell.x, at_cell.y)
	sprite.offset = Vector2(0, -frame_h * 0.5)
	sprite.frame = _braziers.size() % 3
	add_child(sprite)
	_braziers.append(sprite)


## Dusk over the square; warm pools under every lamp and brazier, and the
## obelisk's gold glow at the centre.
func _set_lighting() -> void:
	var dusk := CanvasModulate.new()
	dusk.color = DUSK
	add_child(dusk)
	_lights.append([_cell(PLAZA_CENTER.x, PLAZA_CENTER.y - 1.2), Color(1.0, 0.78, 0.35), 1.1, 2.4])
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 256
	glow.height = 256
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.45))
	glow.gradient = gradient
	for entry in _lights:
		var light := PointLight2D.new()
		light.position = entry[0]
		light.color = entry[1]
		light.energy = entry[2]
		light.texture = glow
		light.texture_scale = entry[3]
		light.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(light)
	_lights.clear()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	# The spawn point is where the FEET stand; the body sits FEET above.
	_player.global_position = _cell(STATION_CELLS.arrival.x, STATION_CELLS.arrival.y) - Vector2(0.0, FEET)
	# Nested y-sort: the player's Visual (drawn at the feet) sorts on its own
	# Y against the props, which sort by their feet too.
	_player.y_sort_enabled = true
	add_child(_player)
	var runner := _player.get_node_or_null("AscensionRunner")
	if runner != null:
		runner.set("combat_inputs_enabled", false)
	_player.set("_cinematic_attack_locked", true)
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = int(-4 * CELL)
		camera.limit_right = int((WIDTH + 4) * CELL)
		# The arch's crown and the forge chimney rise about 2.6 cells above
		# the square's north edge.
		camera.limit_top = int(-3 * CELL)
		camera.limit_bottom = int((HEIGHT + 2) * CELL)
	if _player.has_method("recompute_run_stats"):
		var race: RaceData = Global.race_db.get("human", null)
		var style: StyleData = Global.style_db.get(String(Global.selected_style_id), null)
		_player.recompute_run_stats(race, style, false)


# ---------------------------------------------------------------- stations

func _make_station(key: String, station_name: String, accent: Color) -> HubStation:
	var station := STATION_SCRIPT.new() as HubStation
	var at: Vector2 = STATION_CELLS[key] * CELL
	station.icon = _art("hub_icon_%s" % key)
	station.station_name = station_name
	station.accent = accent
	station.position = at
	# The ring lies on the ground: above the paving, under anyone standing.
	# Its text goes to the label layer, and it senses the player's feet.
	station.z_index = -50
	station.label_layer = _label_layer
	station.sense_offset = Vector2(0.0, -FEET)
	# The square decides which interactable the key goes to (_update_focus).
	station.managed = true
	add_child(station)
	_stations.append(station)
	return station


func _build_stations() -> void:
	var merchant := _make_station("merchant", "Merchant", Color(0.95, 0.8, 0.45))
	merchant.activated.connect(_open_merchant)
	_ascension_station = _make_station("ascension", "Ascension", Color(0.7, 0.6, 0.95))
	_ascension_station.activated.connect(_open_ascension)
	var gear := _make_station("gear", "Gear & Stash", Color(0.6, 0.85, 0.7))
	gear.activated.connect(_open_gear)
	var alcove := _make_station("alcove", "Quiet Alcove", Color(0.75, 0.7, 0.65))
	alcove.activated.connect(_rest_a_moment)
	_exit_station = _make_station("exit", "Next Segment", Color(0.95, 0.55, 0.4))
	_exit_station.activated.connect(_try_depart)
	# The sealed arch over the departure gate (the other service props are
	# placed with the square in _place_props).
	_prop("hub_gate_arch", _cell(STATION_CELLS.exit.x, 0.35), 190.0)
	for side in [-1.0, 1.0]:
		_footprint(_cell(STATION_CELLS.exit.x, 0.35) + Vector2(side * 100.0, -12.0), 30.0)


## One prop sprite at a fixed WORLD height, whatever the art's resolution.
## The node sits at the prop's FEET so the y-sorted square layers it
## correctly against the player.
func _prop(texture_name: String, at: Vector2, world_height: float, z: int = 0) -> Sprite2D:
	var path := "res://assets/textures/hub/%s.png" % texture_name
	if not ResourceLoader.exists(path):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	var height := maxf(1.0, float(sprite.texture.get_height()))
	sprite.scale = Vector2.ONE * (world_height / height)
	sprite.position = at
	sprite.offset = Vector2(0, -height * 0.5)
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _stations_enabled(enabled: bool) -> void:
	_interact_enabled = enabled
	for station in _stations:
		station.set_process_unhandled_input(enabled)


# ---------------------------------------------------------------- panels

func _panel_is_open() -> bool:
	return (_open_panel != null and is_instance_valid(_open_panel)) or (_major_choice != null and is_instance_valid(_major_choice))


## The trade post: the existing HubShop screen embedded as a focused panel.
## Its vendor snapshot logic is idempotent (Global.attempt_vendor_*), so
## reopening never rerolls stock; embedded mode hides departure controls.
func _open_merchant() -> void:
	if _panel_is_open():
		return
	var shop := HUB_SHOP_SCENE.instantiate()
	shop.set("embedded", true)
	_panel_layer.add_child(shop)
	_open_panel = shop
	_stations_enabled(false)
	if shop.has_signal("embedded_closed"):
		shop.connect("embedded_closed", _on_panel_closed)


## The gear corner: the run's own bag and equipment, without the vendor —
## the existing BagUI component bound to the run's containers. Nothing new
## is invented and no cross-run storage appears because a chest is drawn.
func _open_gear() -> void:
	if _panel_is_open():
		return
	var bag_wrap := Control.new()
	bag_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bag := BAG_UI_SCENE.instantiate()
	bag_wrap.add_child(bag)
	# A visible way out (playtest finding: the wrapper trapped station input
	# with no discoverable close). Esc and the bag key also close, below.
	var close_btn := Button.new()
	close_btn.text = "CLOSE  (Esc)"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -150.0
	close_btn.offset_top = 12.0
	close_btn.offset_right = -16.0
	close_btn.offset_bottom = 48.0
	bag_wrap.add_child(close_btn)
	close_btn.pressed.connect(_close_gear)
	_panel_layer.add_child(bag_wrap)
	if bag.has_method("bind_bag"):
		bag.call("bind_bag", Global.run_bag)
	if bag.has_method("bind_core_inventory"):
		bag.call("bind_core_inventory", Global.run_inventory)
	if bag.has_method("toggle_open") and not bool(bag.call("is_open")):
		bag.call("toggle_open")
	_open_panel = bag_wrap
	_gear_bag = bag
	_stations_enabled(false)
	if bag.has_signal("open_changed"):
		bag.connect("open_changed", func(now_open: bool) -> void:
			if not now_open:
				_gear_bag = null
				_on_panel_closed())


## One close path: through the bag's own toggle, so its input lock and the
## open_changed -> _on_panel_closed chain always run exactly once.
func _close_gear() -> void:
	if _gear_bag != null and is_instance_valid(_gear_bag) and bool(_gear_bag.call("is_open")):
		_gear_bag.call("toggle_open")


func _unhandled_input(event: InputEvent) -> void:
	if _gear_bag == null:
		if _interact_enabled and not _panel_is_open() and event != null and not event.is_echo() and event.is_action_pressed(&"interact"):
			if interact():
				get_viewport().set_input_as_handled()
		return
	var close := event.is_action_pressed(&"ui_cancel")
	if not close and InputMap.has_action(&"bag_toggle"):
		close = event.is_action_pressed(&"bag_toggle")
	if close:
		_close_gear()
		get_viewport().set_input_as_handled()


func _open_ascension() -> void:
	if _panel_is_open():
		return
	var screen := ASCENSION_SCREEN.instantiate()
	_panel_layer.add_child(screen)
	Global.ascension_refund_context_hub = true
	screen.open(false)
	_open_panel = screen
	_stations_enabled(false)
	screen.closed.connect(func() -> void:
		Global.ascension_refund_context_hub = false
		_on_panel_closed())


func _rest_a_moment() -> void:
	# Honest about what it is (playtest finding): a quiet spot — Beka's bed
	# is here — not a recovery service.
	if BattleText == null or _player == null:
		return
	var line := "a quiet corner"
	if crowd != null and crowd.beka != null and crowd.beka.is_asleep_on_bed():
		line = "Beka is comfortable here"
	BattleText.popup(_beka_home + Vector2(0, -20), line, Color(0.8, 0.8, 0.85, 0.8), 1.6)


# ---------------------------------------------------------------- interaction

## The interactable the key would use: the nearest station the player's
## feet are on, else Beka within reach — and Beka asleep on her bed when
## she is nearer than the alcove's ring. Only it shows its prompt.
func _update_focus() -> void:
	var best: Object = null
	if _interact_enabled and not _panel_is_open() and _player != null:
		var feet := _player.global_position + Vector2(0.0, FEET)
		var best_d := INF
		for station in _stations:
			if station.player_inside():
				var d := feet.distance_to(station.global_position)
				if d < best_d:
					best_d = d
					best = station
		# A station the player stands in keeps the key (Beka follows and sits
		# close, so nearest-wins would let her block every ring); she wins
		# one only while asleep on her bed by the alcove.
		var beka: Node2D = crowd.beka if crowd != null else null
		if beka != null and beka.in_pet_range(feet):
			var beka_d := feet.distance_to(beka.interact_point())
			if best == null or (beka.is_asleep_on_bed() and beka_d < best_d):
				best = beka
	if best == _focus:
		return
	_focus = best
	for station in _stations:
		station.focused = station == best
	if crowd != null and crowd.beka != null:
		crowd.beka.focused = crowd.beka == best


## Uses the focused interactable; false when nothing is in reach.
func interact() -> bool:
	_update_focus()
	if _focus == null:
		return false
	if _focus is HubStation:
		(_focus as HubStation).activated.emit()
	elif _focus.has_method("pet"):
		_focus.call("pet")
	return true


func _beka_equipped() -> bool:
	if Global == null or Global.run_inventory == null:
		return false
	var item: ItemInstance = Global.run_inventory.get_at(Inventory.SLOT_OFFHAND)
	return item != null and item.data != null and String(item.data.id) == "beka"


func _open_major_choice() -> void:
	if _major_choice != null and is_instance_valid(_major_choice):
		return
	var choice := MAJOR_CHOICE_SCENE.instantiate()
	_panel_layer.add_child(choice)
	_major_choice = choice
	_stations_enabled(false)
	if choice.has_signal("choice_committed"):
		choice.connect("choice_committed", func(_id: StringName) -> void: _on_major_choice_closed())
	if choice.has_method("open"):
		choice.call("open")


func _on_major_choice_closed() -> void:
	_major_choice = null
	_on_panel_closed()


func _on_panel_closed() -> void:
	if _open_panel != null and is_instance_valid(_open_panel):
		_open_panel.queue_free()
	_open_panel = null
	get_tree().paused = false
	_stations_enabled(true)
	_update_pending_cue()


func _update_pending_cue() -> void:
	var pending: bool = Global != null and Global.pending_big_choice
	if _exit_station != null:
		_exit_station.attention = pending
	if _ascension_station != null:
		_ascension_station.attention = false


# ---------------------------------------------------------------- departure

## The same attempt continues into the next segment. The segment counter
## already advanced in Global.on_segment_completed before this scene loaded;
## departure only routes back into the run, exactly once.
func _try_depart() -> void:
	if _departing:
		return
	if Global.pending_big_choice:
		if BattleText != null:
			BattleText.popup(_exit_station.global_position + Vector2(0, 30), "A decision waits before the road.", Color(1.0, 0.7, 0.5, 1.0), 1.6)
		_open_major_choice()
		return
	_departing = true
	Global.attempt_deaths_this_segment = 0
	Global.attempt_checkpoint_pos = Vector2.INF
	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_GAME
	Global.save_current_profile(false)
	if departure_scene_change_enabled:
		Global.goto_game()


# ---------------------------------------------------------------- ambience

func _process(delta: float) -> void:
	_clock += delta
	_update_focus()
	if not _braziers.is_empty():
		_flicker_clock += delta
		if _flicker_clock >= 0.11:
			_flicker_clock = 0.0
			for i in range(_braziers.size()):
				# Each brazier walks the loop from its own phase.
				_braziers[i].frame = (_braziers[i].frame + 1 + (i % 2)) % 3


