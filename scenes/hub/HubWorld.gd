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
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const STATION_SCRIPT := preload("res://scenes/hub/HubStation.gd")

const CELL := 64.0
## Courtyard in cells: about 1.7 gameplay screens across the useful space.
const WIDTH := 30
const HEIGHT := 18
const GATE_HALF_W := 2  # gap half-width in cells for arrival / exit

var _player: Node2D = null
var _panel_layer: CanvasLayer = null
var _open_panel: Node = null
var _stations: Array[HubStation] = []
var _exit_station: HubStation = null
var _ascension_station: HubStation = null
var _departing: bool = false
## Tests block the real scene change to observe the transition state.
var departure_scene_change_enabled: bool = true
var _major_choice: Node = null
var _beka_home: Vector2 = Vector2.ZERO
var _clock: float = 0.0


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
	_build_courtyard()
	_spawn_player()
	_build_stations()
	_update_pending_cue()
	if Global.pending_big_choice:
		call_deferred(&"_open_major_choice")


# ---------------------------------------------------------------- layout

func _cell(x: float, y: float) -> Vector2:
	return Vector2(x, y) * CELL


func _build_courtyard() -> void:
	# Ground: a warm paved base, a lighter walk loop, dirt at the seams.
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([_cell(0, 0), _cell(WIDTH, 0), _cell(WIDTH, HEIGHT), _cell(0, HEIGHT)])
	ground.color = Color(0.23, 0.215, 0.19, 1.0)
	ground.z_index = -100
	add_child(ground)
	var loop := Polygon2D.new()
	loop.polygon = PackedVector2Array([_cell(3, 3), _cell(WIDTH - 3, 3), _cell(WIDTH - 3, HEIGHT - 3), _cell(3, HEIGHT - 3)])
	loop.color = Color(0.27, 0.255, 0.225, 1.0)
	loop.z_index = -99
	add_child(loop)
	var walk := Polygon2D.new()
	# The direct arrival-to-exit route: a clear north-south path.
	walk.polygon = PackedVector2Array([_cell(WIDTH / 2.0 - 1.5, 0), _cell(WIDTH / 2.0 + 1.5, 0), _cell(WIDTH / 2.0 + 1.5, HEIGHT), _cell(WIDTH / 2.0 - 1.5, HEIGHT)])
	walk.color = Color(0.30, 0.285, 0.25, 1.0)
	walk.z_index = -98
	add_child(walk)

	# Perimeter walls with the two gates, plus offset service bay walls so
	# the boundary reads staggered rather than one rectangle.
	var cells: Dictionary = {}
	var mid := WIDTH / 2
	for x in range(0, WIDTH):
		if absi(x - mid) > GATE_HALF_W:
			cells[Vector2i(x, 0)] = true
			cells[Vector2i(x, HEIGHT - 1)] = true
	for y in range(0, HEIGHT):
		cells[Vector2i(0, y)] = true
		cells[Vector2i(WIDTH - 1, y)] = true
	# Recessed merchant bay (east) and Ascension bay (west).
	for y in range(6, 12):
		cells.erase(Vector2i(WIDTH - 1, y))
		cells[Vector2i(WIDTH + 2, y)] = true
	for offset in range(0, 3):
		cells[Vector2i(WIDTH - 1 + offset, 5)] = true
		cells[Vector2i(WIDTH - 1 + offset, 12)] = true
	for y in range(6, 12):
		cells.erase(Vector2i(0, y))
		cells[Vector2i(-3, y)] = true
	for offset in range(0, 3):
		cells[Vector2i(-offset - 1, 5)] = true
		cells[Vector2i(-offset - 1, 12)] = true
	_spawn_walls(cells)

	# The central landmark: a statue ring beside the walk, not on it.
	var statue := Sprite2D.new()
	statue.texture = load("res://assets/world/props/prop_statue_01.png")
	statue.scale = Vector2(0.0625, 0.0625)
	statue.position = _cell(mid + 4, HEIGHT / 2.0 - 1)
	statue.z_index = -10
	add_child(statue)
	# Bay floors.
	for bay in [[_cell(WIDTH - 1, 6), _cell(WIDTH + 2, 12)], [_cell(-3, 6), _cell(0, 12)]]:
		var floor_poly := Polygon2D.new()
		floor_poly.polygon = PackedVector2Array([bay[0], Vector2(bay[1].x, bay[0].y), bay[1], Vector2(bay[0].x, bay[1].y)])
		floor_poly.color = Color(0.25, 0.235, 0.215, 1.0)
		floor_poly.z_index = -97
		add_child(floor_poly)
	_beka_home = _cell(4.0, HEIGHT - 4.0)


func _spawn_walls(cells: Dictionary) -> void:
	for cell_key in cells.keys():
		var cell := cell_key as Vector2i
		var wall := COVER_FULL.instantiate()
		wall.position = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
		var mask := 0
		if cells.has(cell + Vector2i(0, -1)):
			mask |= 1
		if cells.has(cell + Vector2i(1, 0)):
			mask |= 2
		if cells.has(cell + Vector2i(0, 1)):
			mask |= 4
		if cells.has(cell + Vector2i(-1, 0)):
			mask |= 8
		wall.set("connections_mask", mask)
		add_child(wall)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.global_position = _cell(WIDTH / 2.0, HEIGHT - 1.5)
	add_child(_player)
	var runner := _player.get_node_or_null("AscensionRunner")
	if runner != null:
		runner.set("combat_inputs_enabled", false)
	_player.set("_cinematic_attack_locked", true)
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = int(-4 * CELL)
		camera.limit_right = int((WIDTH + 4) * CELL)
		camera.limit_top = int(-2 * CELL)
		camera.limit_bottom = int((HEIGHT + 2) * CELL)
	if _player.has_method("recompute_run_stats"):
		var race: RaceData = Global.race_db.get("human", null)
		var style: StyleData = Global.style_db.get(String(Global.selected_style_id), null)
		_player.recompute_run_stats(race, style, false)


# ---------------------------------------------------------------- stations

func _make_station(at: Vector2, station_name: String, accent: Color) -> HubStation:
	var station := STATION_SCRIPT.new() as HubStation
	station.station_name = station_name
	station.accent = accent
	station.position = at
	add_child(station)
	_stations.append(station)
	return station


func _build_stations() -> void:
	var merchant := _make_station(_cell(WIDTH + 0.6, 9.0), "Merchant", Color(0.95, 0.8, 0.45))
	merchant.activated.connect(_open_merchant)
	_ascension_station = _make_station(_cell(-1.6, 9.0), "Ascension", Color(0.7, 0.6, 0.95))
	_ascension_station.activated.connect(_open_ascension)
	var gear := _make_station(_cell(WIDTH - 4.0, HEIGHT - 4.0), "Gear & Stash", Color(0.6, 0.85, 0.7))
	gear.activated.connect(_open_gear)
	var alcove := _make_station(_beka_home + Vector2(CELL, 0), "Quiet Alcove", Color(0.75, 0.7, 0.65))
	alcove.activated.connect(_rest_a_moment)
	_exit_station = _make_station(_cell(WIDTH / 2.0, 0.9), "Next Segment", Color(0.95, 0.55, 0.4))
	_exit_station.activated.connect(_try_depart)
	# Gear corner props.
	for i in range(2):
		var crate := Sprite2D.new()
		crate.texture = load("res://assets/world/props/prop_crate_01.png")
		crate.scale = Vector2(0.0625, 0.0625)
		crate.position = _cell(WIDTH - 3.0 + float(i) * 0.9, HEIGHT - 3.2)
		crate.z_index = -10
		add_child(crate)


func _stations_enabled(enabled: bool) -> void:
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
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bag := BAG_UI_SCENE.instantiate()
	wrap.add_child(bag)
	_panel_layer.add_child(wrap)
	if bag.has_method("bind_bag"):
		bag.call("bind_bag", Global.run_bag)
	if bag.has_method("bind_core_inventory"):
		bag.call("bind_core_inventory", Global.run_inventory)
	if bag.has_method("toggle_open") and not bool(bag.call("is_open")):
		bag.call("toggle_open")
	_open_panel = wrap
	_stations_enabled(false)
	if bag.has_signal("open_changed"):
		bag.connect("open_changed", func(now_open: bool) -> void:
			if not now_open:
				_on_panel_closed())


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
	if BattleText != null and _player != null:
		BattleText.popup(_beka_home + Vector2(0, -20), "…", Color(0.8, 0.8, 0.85, 0.8), 1.4)


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
	queue_redraw()


func _draw() -> void:
	# Beka rests in the quiet alcove when she rides with this run.
	if _beka_visiting():
		var texture := load("res://assets/textures/companions/beka_sleep.png") as Texture2D
		if texture != null:
			var blanket := Rect2(_beka_home + Vector2(-20, 6), Vector2(40, 12))
			draw_rect(blanket, Color(0.42, 0.3, 0.24, 1.0))
			var size: Vector2 = texture.get_size() * 1.6
			draw_texture_rect(texture, Rect2(_beka_home - size * 0.5, size), false)
			var rise := fmod(_clock, 2.2) / 2.2
			draw_circle(_beka_home + Vector2(10.0, -8.0 - rise * 7.0), 1.4, Color(0.9, 0.9, 1.0, 0.6 * (1.0 - rise)))


func _beka_visiting() -> bool:
	if Global == null or Global.run_inventory == null:
		return false
	var item: ItemInstance = Global.run_inventory.get_at(Inventory.SLOT_OFFHAND)
	return item != null and item.data != null and String(item.data.id) == "beka"
