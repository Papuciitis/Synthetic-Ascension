extends "res://tools/dev/CityStreetTraversalProbe.gd"
## First gameplay trailer: one staged take of the actual Game per run, recorded
## offline by Movie Maker (4 November 2026). Run it through
## tools/capture/trailer/README.md: the movieclock.so preload advances
## Time.get_ticks_* by exactly one frame per recorded frame (enemy strides, hit
## flashes, HUD pulses and SFX throttles otherwise race ahead of the footage)
## and reports the pointer position this script chooses, so the window stays
## off-screen and unfocused while mouse aim and hover behave as they do in play.
##
## Staged and disclosed in each take log: the segment jump, world seed,
## loadout, starting location, any placed enemy or item, god mode and the
## onboarding bypass. Played with production input: movement, attack, dash and
## bag actions, mouse aim through the pointer, bag hover and clicks through
## pushed GUI events. Streaming, spawning, the encounter director, collisions,
## roofs, pickups and HUD stay live; nothing is frozen.
## -- --take=<name> --log=<absolute json path> [--segment=7] [--world-seed=16102028]

const SPEC_DIR := "res://core/actors/enemy/EnemySpec_%s.tres"
const SLATE_COLOR := Color(1.0, 0.0, 1.0)

var _take := "street"
var _log_path := ""
var _marks: Array[Dictionary] = []
var _take_frame0 := -1
var _slates: Array[int] = []
var _slate_layer: CanvasLayer
var _counters := {"weapon_fired": 0, "hits": 0, "kills": 0, "player_hits_absorbed": 0}

# Steering: a goal followed along a string-pulled walkable path with a
# smoothed stick, instead of the probe walker's cell-centre steps.
var _steering := false
var _steer_goal := Vector2.ZERO
var _steer_dir := Vector2.ZERO
var _steer_speed := 1.0
var _steer_arrive := 24.0
var _steer_path: Array[Vector2i] = []
var _steer_path_frame := -100
var _steer_stall := 0
var _steer_last := Vector2.ZERO

# Aim: a world point the pointer follows, smoothed so the reticle never snaps.
var _aiming := false
var _aim_goal := Vector2.ZERO
var _aim_point := Vector2.ZERO
var _aim_follow := 0.22

var _hold_attack := false
var _attack_frames := 0
# Ordinary fighting: aim at the nearest live enemy, fire while one is in range.
var _auto_aim := false
var _auto_fire := true
var _auto_range := 760.0
var _found: ItemInstance
var _pace_real := 0.0
var _pace_frame := 0
var _dash_frames := 0


func _enter_tree() -> void:
	super._enter_tree()
	# The inherited shutdown writes its report here: keep it in the isolated profile.
	_out = "user://trailer_take"
	_city_segment = 7
	_city_world_seed = 16102028
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--take="): _take = arg.trim_prefix("--take=")
		elif arg.begins_with("--log="): _log_path = arg.trim_prefix("--log=")
		elif arg.begins_with("--world-seed="): _city_world_seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--segment="): _city_segment = int(arg.trim_prefix("--segment="))


func _ready() -> void:
	process_priority = -1000
	process_physics_priority = -1000
	super._ready()


func _process(_delta: float) -> void:
	# First callback of every frame: one recorded frame, one clock step.
	OS.get_environment("SA_MOVIE_CLOCK_TICK")
	if _slate_layer != null and _slate_layer.visible and Engine.get_process_frames() > _slates.back():
		_slate_layer.visible = false
	_pace()


## Capture pace in real (unvirtualised) time, every 30 recorded frames.
func _pace() -> void:
	var frame := Engine.get_process_frames()
	if frame % 30 != 0:
		return
	var now := Time.get_unix_time_from_system()
	if _pace_frame > 0:
		print("TrailerPace frame=%d real_ms_per_frame=%d queue=%d blockers=%d enemies=%d clock=%s" % [frame,
			int((now - _pace_real) * 1000.0 / maxf(1.0, frame - _pace_frame)),
			_chunks.debug_chunk_queue().size() if _chunks != null else -1,
			_chunks.pending_blocker_stage_count() if _chunks != null else -1,
			get_tree().get_nodes_in_group(&"enemies").size(), OS.get_environment("SA_MOVIE_STATE")])
	_pace_real = now
	_pace_frame = frame


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_steer()
	if _auto_aim:
		_auto_combat()
	_point()
	if _hold_attack or _attack_frames > 0:
		Input.action_press(&"attack")
	else:
		Input.action_release(&"attack")
	_attack_frames = maxi(0, _attack_frames - 1)
	if _dash_frames > 0:
		Input.action_press(&"dash")
		_dash_frames -= 1
	else:
		Input.action_release(&"dash")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty():
		_fail("Trailer takes record with a renderer under --write-movie")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
	Global.debug_encounter_beats = true
	# A returning player's profile: the one-time onboarding tips are seen.
	for property: Dictionary in Global.get_property_list():
		if String(property.name).begins_with("tip_shown_"):
			Global.set(property.name, true)
	_staging.append({"kind": "onboarding tips marked seen (returning-player profile)"})
	# The probes' fixed 60 FPS cap would only add sleeps to an offline capture.
	Engine.max_fps = 0
	get_window().title = "Synthetic Ascension — trailer take " + _take
	get_window().borderless = true
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(-10000, -10000)
	# Game defaults otherwise; music is muted here and scored in the edit.
	SettingsManager.set_value(&"audio", &"music_muted", true, false)
	_game = GAME.instantiate() as Node2D
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	RunEvents.player_entered_building.connect(_on_entered_building)
	_connect_trailer_events()
	await _settle()
	_dismiss_dossiers()
	if get_window().size != Vector2i(1920, 1080):
		_fail("Capture window is %s, not 1920x1080" % str(get_window().size))
	if _failures == 0:
		match _take:
			"street": await _take_street()
			"find": await _take_find()
			"vigil": await _take_vigil()
			"setup": _mark("settled")
			_: _fail("Unknown take " + _take)
	await _finish()


## Release staging: the production camera follows the player again and the
## player takes input. The camera snaps once so the take opens settled.
func _go_live() -> void:
	_camera.top_level = false
	_camera.position = Vector2.ZERO
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_dismiss_dossiers()


## Mark the first usable frame of the take with a one-frame magenta slate so
## the edit can tie log frames to movie frames.
func _begin_take() -> void:
	_slate()
	await _frames(1)
	_take_frame0 = Engine.get_process_frames()
	_mark("take_start")


func _slate() -> void:
	if _slate_layer == null:
		_slate_layer = CanvasLayer.new()
		_slate_layer.layer = 127
		_slate_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		var fill := ColorRect.new()
		fill.color = SLATE_COLOR
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slate_layer.add_child(fill)
		get_tree().root.add_child(_slate_layer)
	_slate_layer.visible = true
	_slates.append(Engine.get_process_frames())


func _mark(name: String, extra: Dictionary = {}) -> void:
	var entry := {"mark": name, "process_frame": Engine.get_process_frames(),
		"take_frame": Engine.get_process_frames() - _take_frame0 if _take_frame0 >= 0 else -1,
		"player": _xy(_player.global_position) if _player != null else [], "counters": _counters.duplicate()}
	entry.merge(extra, true)
	_marks.append(entry)
	print("TrailerMark %s frame=%d take_frame=%d" % [name, entry.process_frame, entry.take_frame])


func _xy(point: Vector2) -> Array:
	return [snappedf(point.x, 0.1), snappedf(point.y, 0.1)]


func _connect_trailer_events() -> void:
	RunEvents.weapon_fired.connect(func(_source: Node, _style: StringName, _from: Vector2, _to: Vector2, _power: float, _haste: float) -> void: _counters.weapon_fired += 1)
	RunEvents.player_hit_landed.connect(func(_source: Node, _handle: int, _position: Vector2, _amount: float, _crit: bool, _elite: bool) -> void: _counters.hits += 1)
	RunEvents.enemy_defeated.connect(func(_context: RefCounted) -> void: _counters.kills += 1)


# --- production input -------------------------------------------------------

func _steer_to(goal: Vector2, speed: float = 1.0, arrive: float = 24.0) -> void:
	# Replan only for a new goal cell: moving goals are re-aimed every frame.
	if not _steering or _chunks.world_to_cell(goal) != _chunks.world_to_cell(_steer_goal):
		_steer_path_frame = -100
		_steer_stall = 0
	_steer_goal = goal
	_steer_speed = speed
	_steer_arrive = arrive
	_steering = true


func _stop_steering() -> void:
	_steering = false
	_steer_dir = Vector2.ZERO
	_set_axis(&"move_left", &"move_right", 0.0)
	_set_axis(&"move_up", &"move_down", 0.0)


## Await arrival (or the frame budget), steering all the while.
func _travel(goal: Vector2, max_frames: int = 600, speed: float = 1.0, arrive: float = 24.0) -> bool:
	_steer_to(goal, speed, arrive)
	for _frame in max_frames:
		await get_tree().physics_frame
		if not _steering:
			return true
	_stop_steering()
	return false


func _steer() -> void:
	if not _steering:
		return
	var at := _player.global_position
	if at.distance_to(_steer_goal) <= _steer_arrive:
		_stop_steering()
		return
	var frame := Engine.get_physics_frames()
	if frame - _steer_path_frame >= 12:
		_steer_path_frame = frame
		var start := _chunks.world_to_cell(at)
		var goal := _chunks.world_to_cell(_steer_goal)
		_steer_path = _live_path(start, goal, {}) if _chunks.is_cell_walkable(goal) else []
	var waypoint := _steer_goal
	for index in range(_steer_path.size() - 1, -1, -1):
		var candidate := _chunks.cell_to_world_center(_steer_path[index])
		if _clear_line(at, candidate):
			waypoint = candidate if index < _steer_path.size() - 1 else _steer_goal
			break
	var desired := at.direction_to(waypoint)
	_steer_dir = desired if _steer_dir == Vector2.ZERO else _steer_dir.lerp(desired, 0.2).normalized()
	if at.distance_to(_steer_last) < 0.6:
		_steer_stall += 1
	else:
		_steer_stall = 0
	_steer_last = at
	var axis := _steer_dir
	if _steer_stall > 20:
		# Slide off whatever body is in the way, then resume.
		axis = _steer_dir.orthogonal() * (1.0 if (_steer_stall / 20) % 2 == 0 else -1.0)
	axis *= _steer_speed
	_set_axis(&"move_left", &"move_right", axis.x)
	_set_axis(&"move_up", &"move_down", axis.y)


## Whether a straight walk keeps a third of a cell clear of unwalkable cells.
func _clear_line(from: Vector2, to: Vector2) -> bool:
	var cell := float(_chunks.cell_size_px)
	var steps := maxi(1, int(from.distance_to(to) / (cell * 0.33)))
	var side := from.direction_to(to).orthogonal() * cell * 0.33
	for step in range(1, steps + 1):
		var sample := from.lerp(to, float(step) / steps)
		for offset: Vector2 in [Vector2.ZERO, side, -side]:
			if not _chunks.is_cell_walkable(_chunks.world_to_cell(sample + offset)):
				return false
	return true


func _aim_at(point: Vector2, snap: bool = false) -> void:
	if snap or not _aiming:
		_aim_point = point
	_aim_goal = point
	_aiming = true


func _point() -> void:
	if not _aiming:
		return
	_aim_point = _aim_point.lerp(_aim_goal, _aim_follow)
	_pointer_at_screen(get_viewport().get_canvas_transform() * _aim_point)


func _pointer_at_screen(point: Vector2) -> void:
	var at := get_window().position + Vector2i(point.round())
	OS.get_environment("SA_MOVIE_POINTER:%d,%d" % [at.x, at.y])


func _click_attack() -> void:
	_attack_frames = 2


func _dash() -> void:
	_dash_frames = 2


func _tap_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		Input.parse_input_event(event)
		await get_tree().process_frame


## Hover a GUI point the way a mouse does: the pointer the game reads and the
## motion event GUI picking uses agree.
func _gui_hover(point: Vector2) -> void:
	_aiming = false
	_pointer_at_screen(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)


func _gui_click(point: Vector2) -> void:
	_gui_hover(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _hold_for(seconds: float) -> void:
	await _frames(int(round(seconds * 60.0)))


func _live_enemies(near: Vector2, radius: float) -> Array[EnemyActor]:
	var found: Array[EnemyActor] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var actor := node as EnemyActor
		if actor != null and not actor.dead and actor.global_position.distance_to(near) <= radius:
			found.append(actor)
	found.sort_custom(func(a: EnemyActor, b: EnemyActor) -> bool: return a.global_position.distance_squared_to(near) < b.global_position.distance_squared_to(near))
	return found


# --- takes ------------------------------------------------------------------

## Pilot: an ordinary Canal Services street fight at the trailer check's street.
func _take_street() -> void:
	var start := _free_spawn_position(Vector2(-1184, 1312))
	_player.global_position = start
	_staging.append({"kind": "player warp to the trailer check street", "world": _xy(start)})
	await _settle()
	_dismiss_dossiers()
	await _go_live()
	await _begin_take()
	_hold_attack = true
	var route: Array[Vector2] = [start + Vector2(260, -40), start + Vector2(420, 120), start + Vector2(140, 220), start]
	for goal: Vector2 in route:
		_steer_to(goal, 0.85)
		for _frame in 150:
			var enemies := _live_enemies(_player.global_position, 900.0)
			_aim_at(enemies[0].global_position if not enemies.is_empty() else _player.global_position + _steer_dir * 240.0)
			await get_tree().physics_frame
			if not _steering:
				break
	_hold_attack = false
	_stop_steering()
	_mark("take_end")


## City, choice and payoff in one run (trailer 0:06–0:58): a Canal Services
## street fight, a real narrow passage, a real doorway with its roof cutaway,
## the staged Sunder Wake item inside, the bag decision, then the Momentum
## payoff on the street outside.
func _take_find() -> void:
	_stage_loadout()
	var origin := Vector2(-1184, 1312)
	_player.global_position = _free_spawn_position(origin)
	await _settle()
	_dismiss_dossiers()
	var entry := _facade_entry(origin)
	if entry.is_empty():
		_fail("No enterable building with a visible front door near the trailer street")
		return
	var door: Vector2 = entry.door
	var outward: Vector2 = entry.outward
	# Start out on the street facing the frontage, as far back as a clear
	# straight walk to the door allows.
	var street := Vector2.INF
	for back: float in [680.0, 600.0, 520.0, 440.0, 360.0]:
		for side: float in [0.0, 160.0, -160.0]:
			var candidate := door + outward * back + outward.orthogonal() * side
			if _chunks.is_cell_walkable(_chunks.world_to_cell(candidate)) and _clear_line(candidate, door + outward * 110.0):
				street = candidate
				break
		if street != Vector2.INF:
			break
	if street == Vector2.INF:
		_fail("No clear street approach to the doorway")
		return
	var passage := _nearest_passage(door)
	var use_passage := not passage.is_empty() and bool(passage.narrow_between_buildings) and (passage.center as Vector2).distance_to(door) < 1400.0
	_staging.append({"kind": "player warp onto the street in front of an enterable building", "world": _xy(street),
		"door": _xy(door), "outward": _xy(outward), "building_id": (entry.volume as IndoorVolume).building_id,
		"passage": str(passage.get("world", "none")) if use_passage else "none nearby"})
	_player.global_position = street
	await _settle()
	_dismiss_dossiers()
	await _go_live()
	await _preroll(14.0)
	await _begin_take()
	_auto_aim = true
	_mark("street_fight")
	await _skirmish(street, 4.0)
	if use_passage:
		var ends: Array = passage.ends
		if (ends[1] as Vector2).distance_to(street) < (ends[0] as Vector2).distance_to(street):
			ends.reverse()
		_mark("to_passage")
		await _travel(ends[0], 420, 0.9)
		_mark("passage_enter")
		await _travel(passage.center, 240, 0.8)
		await _travel(ends[1], 240, 0.8)
		_mark("passage_exit")
	_mark("to_doorway")
	await _travel(door + outward * 260.0, 480, 0.85)
	_auto_aim = false
	_hold_attack = false
	_found = _sunder_item()
	var inside := _inside_point(door, outward)
	_place_pickup(_found, inside)
	_aim_at(inside)
	await _travel(door + outward * 110.0, 240, 0.7, 14.0)
	_mark("doorway")
	await _travel(door - outward * float(_chunks.cell_size_px) * 0.8, 240, 0.6, 12.0)
	_mark("inside", {"roof_open": (entry.roof as RoofOverlay)._inside_count > 0})
	await _travel(inside, 240, 0.55, 10.0)
	var collected := await _until(func() -> bool: return _inventory_has(_found), 150)
	_mark("collected", {"in_bag": Global.run_bag.slots.has(_found)})
	if not collected:
		_fail("The found item was not collected")
		return
	await _hold_for(0.9)
	await _choose_in_bag(_found, 2)
	# Back out onto the open street in front of the facade for the payoff.
	await _travel(door + outward * 260.0, 360, 0.9)
	await _payoff(2, door + outward * 430.0)
	_mark("take_end")


const LOADOUT := {0: ["conduit_heart", 3], 1: ["conduit_plating", 3], 2: ["gravemarch_stompers", 3],
	3: ["conduit_lens", 3], 4: ["gravemarch_clockjaw", 2], 5: ["conduit_charm", 2], 6: ["acc_oakheart", 3], 7: ["ring_crusher", 3]}


## A plausible segment-7 kit with no Manifestations, so the found rule is the
## only one in play and its before/after is causal.
func _stage_loadout() -> void:
	for slot: int in LOADOUT:
		var data := Global.get_item_data(LOADOUT[slot][0])
		if data == null:
			_fail("Missing loadout item " + LOADOUT[slot][0])
			continue
		Global.run_inventory.set_item(slot, ItemInstance.from_roll(data, LOADOUT[slot][1], ItemInstance.Polarity.POS, 0.6, false))
	_staging.append({"kind": "equipped loadout without Manifestations", "items": LOADOUT})


func _sunder_item() -> ItemInstance:
	var item := ItemInstance.from_roll(Global.get_item_data("lattice_strideframe"), 4, ItemInstance.Polarity.POS, 0.7, false)
	item.manifestation_id = &"sunder_wake"
	return item


func _place_pickup(item: ItemInstance, at: Vector2) -> void:
	var pickup := ITEM_SCENE.instantiate() as ItemPickup
	pickup.item_instance = item
	pickup.position = at
	_game.add_child(pickup)
	_staging.append({"kind": "item placed inside the building", "item": item.data.id, "rarity": item.rarity,
		"manifestation": String(item.manifestation_id), "world": _xy(at)})


func _inside_point(door: Vector2, outward: Vector2) -> Vector2:
	for depth: float in [1.8, 1.4, 2.4, 1.1]:
		var point := door - outward * float(_chunks.cell_size_px) * depth
		if _chunks.is_cell_walkable(_chunks.world_to_cell(point)):
			return point
	return door - outward * float(_chunks.cell_size_px)


## Unrecorded build-up before the slate: the production spawner and director
## populate the street at 4x time scale; the take itself runs at 1x.
func _preroll(game_seconds: float) -> void:
	_auto_aim = true
	Engine.time_scale = 4.0
	await _frames(int(game_seconds * 60.0 / 4.0))
	Engine.time_scale = 1.0
	_auto_aim = false
	_hold_attack = false
	_staging.append({"kind": "pre-roll before the slate at 4x time scale", "game_seconds": game_seconds,
		"enemies_after": get_tree().get_nodes_in_group(&"enemies").size()})
	_dismiss_dossiers()


## Hold ground near a point: short strafing moves while auto combat fights.
func _skirmish(center: Vector2, seconds: float) -> void:
	var frames := int(seconds * 60.0)
	var angle := 0.0
	while frames > 0:
		angle += 1.9
		_steer_to(_free_spawn_position(center + Vector2(cos(angle), sin(angle)) * 110.0), 0.6, 16.0)
		for _frame in 50:
			await get_tree().physics_frame
			frames -= 1
			if not _steering or frames <= 0:
				break
	_stop_steering()


func _auto_combat() -> void:
	var near := _live_enemies(_player.global_position, _auto_range)
	if near.is_empty():
		_hold_attack = false
		if _steering:
			_aim_at(_player.global_position + _steer_dir * 260.0)
		return
	_aim_at(near[0].global_position)
	_hold_attack = _auto_fire


func _until(condition: Callable, max_frames: int) -> bool:
	for _frame in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _bag_slot_for(item: ItemInstance) -> Control:
	var index := Global.run_bag.slots.find(item)
	var bag := get_tree().root.find_child("BagUI", true, false)
	if index < 0 or bag == null:
		return null
	for group: String in ["_grid_slots", "_quick_slots"]:
		for slot: BagSlot in bag.get(group):
			if slot.slot_index == index and slot.is_visible_in_tree():
				return slot
	return null


## The decision: open the bag, glide onto the found item, hold its card long
## enough to read, click to equip it, then close.
func _choose_in_bag(item: ItemInstance, slot: int) -> void:
	_auto_aim = false
	_hold_attack = false
	_stop_steering()
	await _hold_for(0.3)
	_mark("bag_open")
	await _tap_action(&"bag_toggle")
	await _hold_for(0.7)
	var bag_slot := _bag_slot_for(item)
	if bag_slot == null:
		_fail("The found item has no visible bag slot")
		await _tap_action(&"bag_toggle")
		return
	var at := bag_slot.get_global_rect().get_center()
	var from := at + Vector2(-160.0, 60.0)
	for step in 18:
		_gui_hover(from.lerp(at, ease(float(step + 1) / 18.0, 0.4)))
		await _frames(1)
	_mark("card_hover", {"slot_rect": str(bag_slot.get_global_rect())})
	await _hold_for(4.5)
	_mark("equip_click")
	await _gui_click(at)
	await _hold_for(1.6)
	var worn := Global.run_inventory.get_at(slot) == item
	_mark("equipped", {"slot": slot, "worn": worn, "manifestation": String(item.manifestation_id)})
	if not worn:
		_fail("The found item did not equip into slot %d" % slot)
	await _tap_action(&"bag_toggle")
	await _hold_for(0.4)
	_mark("bag_closed")


func _manifestations() -> ManifestationState:
	var runner := _player.get_node_or_null("ManifestationRunner") as ManifestationRunner
	return runner.state if runner != null else null


## Travel a loop until the shared Momentum bank is full (attack released),
## then, still moving, click once at the densest live cluster nearby.
func _payoff(times: int, center: Vector2) -> void:
	var state := _manifestations()
	if state == null:
		_fail("No ManifestationState on the player")
		return
	_auto_aim = false
	_hold_attack = false
	var angle := (_player.global_position - center).angle()
	for n in times:
		_mark("bank_%d" % n, {"momentum": snappedf(state.momentum, 0.01)})
		var frames := 0
		while state.momentum < 0.999 and frames < 720:
			angle += 0.03
			_steer_to(_free_spawn_position(center + Vector2.from_angle(angle) * 200.0), 1.0, 40.0)
			var ahead := _cluster_point(_player.global_position, 120.0, 520.0)
			_aim_at(ahead if ahead != Vector2.INF else _player.global_position + _steer_dir * 260.0)
			await get_tree().physics_frame
			frames += 1
		var target := _cluster_point(_player.global_position, 140.0, 440.0)
		if target == Vector2.INF:
			target = _player.global_position + _steer_dir * 240.0
		_aim_at(target)
		for _frame in 12:
			angle += 0.03
			_steer_to(_free_spawn_position(center + Vector2.from_angle(angle) * 200.0), 1.0, 40.0)
			await get_tree().physics_frame
		_mark("sunder_click_%d" % n, {"momentum": snappedf(state.momentum, 0.01), "aim": _xy(target)})
		_click_attack()
		for _frame in 100:
			angle += 0.03
			_steer_to(_free_spawn_position(center + Vector2.from_angle(angle) * 200.0), 1.0, 40.0)
			await get_tree().physics_frame
	_stop_steering()


## The nearest original building whose door faces the camera (south), so the
## doorway reads on the facade before the roof cuts away.
func _facade_entry(origin: Vector2) -> Dictionary:
	var best := {}
	var best_distance := 2600.0
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		var volume := node as IndoorVolume
		if volume == null or volume.has_meta(&"dungeon_roof_volume") or volume.has_meta(&"city_street_infill"):
			continue
		var entry: Variant = volume.get("_presentation_entry")
		var outward: Variant = volume.get("_presentation_outward")
		if not (entry is Vector2) or not (outward is Vector2) or (outward as Vector2).y < 0.7:
			continue
		var door := volume.to_global(entry)
		var roof: RoofOverlay = null
		for connection: Dictionary in volume.body_entered.get_connections():
			var subscriber: Object = (connection.callable as Callable).get_object()
			if subscriber is RoofOverlay: roof = subscriber as RoofOverlay
		if roof == null:
			continue
		var inside := door - (outward as Vector2) * float(_chunks.cell_size_px)
		if not _chunks.is_cell_walkable(_chunks.world_to_cell(door + (outward as Vector2) * 110.0)) or not _chunks.is_cell_walkable(_chunks.world_to_cell(inside)):
			continue
		var distance := door.distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			best = {"volume": volume, "roof": roof, "door": door, "outward": outward}
	return best


## Escalation (trailer 0:58–1:22): this seed's Ward Vigil, with the found rule
## already worn. Wake it, hold its circle through the waves (circling inside
## banks Momentum; a full bank is spent into the densest crowd), dash out of
## charge wind-ups aimed at the player, and hold the Vigil. One real
## charger_wedge beat is called early instead of waiting for its cadence.
func _take_vigil() -> void:
	_stage_loadout()
	Global.run_inventory.set_item(2, _sunder_item())
	_staging.append({"kind": "found Sunder Wake Strideframe already worn (the find take's choice)"})
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	var vigil: PrimaryObjective = builder.get("_primary_objective") if builder != null else null
	if vigil == null:
		_fail("No primary objective in this segment")
		return
	var centre := vigil.global_position
	_mark("objective", {"title": vigil.objective_title(), "world": _xy(centre)})
	var start := Vector2.INF
	for turn in 8:
		var candidate := centre + Vector2.DOWN.rotated(turn * TAU / 8.0) * 1000.0
		_player.global_position = candidate
		await _settle()
		_dismiss_dossiers()
		var cell := _chunks.world_to_cell(candidate)
		if _chunks.is_cell_walkable(cell) and not _live_path(cell, _chunks.world_to_cell(centre), {}).is_empty():
			start = candidate
			break
	if start == Vector2.INF:
		_fail("No walkable approach to the Vigil")
		return
	_staging.append({"kind": "player warp 1000 px from the Vigil", "world": _xy(start)})
	_player.global_position = start
	await _go_live()
	await _preroll(10.0)
	await _begin_take()
	vigil.activated.connect(func() -> void: _mark("vigil_woken"))
	vigil.completed.connect(func() -> void: _mark("vigil_held"))
	_auto_aim = true
	_mark("approach")
	await _travel(centre, 720, 1.0, 110.0)
	var state := _manifestations()
	var director := get_tree().get_first_node_in_group(&"encounter_director")
	var phase := "bank"
	var phase_frames := 0
	var angle := (_player.global_position - centre).angle()
	var called_wedge := false
	var spent_after_hold := false
	for frame in 60 * 50:
		if spent_after_hold and phase_frames > 150:
			break
		phase_frames += 1
		angle += 0.032
		if await _dodge_charge(centre):
			continue
		_steer_to(centre + Vector2.from_angle(angle) * 100.0, 0.9, 30.0)
		if not called_wedge and frame == 60 * 7 and director != null:
			called_wedge = true
			var placed: Dictionary = director.try_spawn_beat(&"charger_wedge")
			_mark("charger_wedge_called", {"placed": not placed.is_empty()})
		if phase == "bank":
			_auto_aim = false
			_hold_attack = false
			var cluster := _cluster_point(_player.global_position, 130.0, 460.0)
			_aim_at(cluster if cluster != Vector2.INF else _player.global_position + _steer_dir * 260.0)
			if state.momentum >= 0.999 and cluster != Vector2.INF and _aim_point.distance_to(cluster) < 40.0:
				_click_attack()
				_mark("sunder_click", {"aim": _xy(cluster), "held": vigil.is_finished()})
				spent_after_hold = vigil.is_finished()
				phase = "fire"
				phase_frames = 0
		elif phase_frames > 100:
			phase = "bank"
			phase_frames = 0
		else:
			_auto_aim = true
		await get_tree().physics_frame
	_auto_aim = false
	_hold_attack = false
	_stop_steering()
	_mark("take_end", {"vigil_finished": vigil.is_finished()})


## Dash sideways out of a charge whose wind-up is about to release at the
## player; the side that keeps the player nearer the Vigil centre wins.
func _dodge_charge(centre: Vector2) -> bool:
	for actor: EnemyActor in _live_enemies(_player.global_position, 380.0):
		var charge: Variant = actor.get("_charge")
		if charge == null:
			continue
		var windup: float = charge._windup_left
		var direction: Vector2 = charge._dir
		if windup <= 0.0 or windup > 0.14 or direction.dot(actor.global_position.direction_to(_player.global_position)) < 0.85:
			continue
		var side := direction.orthogonal()
		if side.dot(centre - _player.global_position) < 0.0:
			side = -side
		_stop_steering()
		_set_axis(&"move_left", &"move_right", side.x)
		_set_axis(&"move_up", &"move_down", side.y)
		_dash()
		_mark("dodge", {"from": actor.spec.resource_path.get_file() if actor.spec != null else "", "windup_left": snappedf(windup, 0.01)})
		for _frame in 16:
			await get_tree().physics_frame
		return true
	return false


## Centre of the densest group of live enemies at a usable distance, or INF.
func _cluster_point(origin: Vector2, near: float, far: float) -> Vector2:
	var candidates: Array[EnemyActor] = []
	for actor: EnemyActor in _live_enemies(origin, far):
		if actor.global_position.distance_to(origin) >= near:
			candidates.append(actor)
	var best := Vector2.INF
	var best_count := 0
	for actor in candidates:
		var sum := Vector2.ZERO
		var count := 0
		for other in candidates:
			if other.global_position.distance_to(actor.global_position) <= 130.0:
				sum += other.global_position
				count += 1
		if count > best_count:
			best_count = count
			best = sum / count
	return best


func _finish() -> void:
	_release_inputs()
	_stop_steering()
	_hold_attack = false
	OS.get_environment("SA_MOVIE_POINTER:off")
	var report := {"take": _take, "capture_scene": "res://tools/capture/trailer/TrailerDirector.tscn",
		"movie": Engine.get_write_movie_path(), "args": OS.get_cmdline_user_args(),
		"segment": _city_segment, "world_seed": _city_world_seed, "window": str(get_window().size),
		"style": Global.selected_style_id, "god_mode": Global.debug_player_god_mode,
		"slates_process_frames": _slates, "take_frame0": _take_frame0, "marks": _marks, "staging": _staging,
		"counters": _counters, "failures": _failures, "clock": OS.get_environment("SA_MOVIE_STATE")}
	if not _log_path.is_empty():
		var output := FileAccess.open(_log_path, FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(report, "\t"))
			output.close()
	print("TrailerDirector: take=%s failures=%d marks=%d counters=%s" % [_take, _failures, _marks.size(), str(_counters)])
	_report = report
	await super._shutdown()
