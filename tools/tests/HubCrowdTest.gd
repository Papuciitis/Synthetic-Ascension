extends Node

# The hub's people (scenes/hub/HubCrowd.gd, HubBeka.gd): the crowd follows
# the Followers on a capped log curve, is sized on arrival and only grows
# during a visit; nobody walks through props or idles on a station ring;
# the service NPCs stand at their posts; Beka lives in the hub whether or
# not she is equipped, sleeps when she ends up by her bed, follows the player
# when she rides with the run, and petting her wins the interact key over a
# station ring in reach.
#
# Run: <godot> --headless --path . res://tools/tests/HubCrowdTest.tscn

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const CROWD := preload("res://scenes/hub/HubCrowd.gd")
const BEKA_DATA := preload("res://data/items/defs/accessories/beka.tres")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	# The curve: one person for any Followers at all, ~10 at 1k, ~15 at 4k,
	# the cap from ~41k, and nothing silly at a million or a billion.
	var table := {0: 0, 1: 1, 60: 3, 1000: 10, 4000: 15, 16000: 20, 41000: 24, 1000000: 24, 1000000000: 24}
	for followers in table.keys():
		_check(CROWD.believer_count(followers) == table[followers], "%d Followers -> %d people (%d)" % [followers, table[followers], CROWD.believer_count(followers)])
	var monotone := true
	for f in range(0, 60000, 250):
		monotone = monotone and CROWD.believer_count(f + 250) >= CROWD.believer_count(f)
	_check(monotone, "more Followers never means fewer people")

	if not Global.attempt_active:
		Global.start_new_attempt()
	SaveManager.current_save = null
	Global.followers = 4000
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 7
	add_child(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var crowd: Node = hub.crowd
	_check(crowd != null, "the square has a crowd")
	_check(crowd.believers.size() == 15, "4000 Followers bring 15 people (%d)" % crowd.believers.size())
	_check(crowd.service.size() == 5, "the Exchanger, Quartermaster, Chronicler, Acolyte and smith stand at their posts (%d)" % crowd.service.size())
	for s in crowd.service:
		_check((s["p"] as Node2D).get_parent() == hub, "%s is a y-sorted child of the square" % s["key"])
	_check(crowd.beka != null and get_tree().get_first_node_in_group(&"hub_beka") == crowd.beka, "Beka is home without being equipped")
	_check(not crowd.beka.following, "unequipped, she keeps her own company")

	# A simulated minute: never inside a prop, never loitering on a ring.
	var inside := 0
	var loitering := 0
	for step in range(600):
		crowd.tick(0.1)
		if step % 5 != 0:
			continue
		for b in crowd.believers:
			var at: Vector2 = (b["p"] as Node2D).position
			if not crowd.is_walkable(at, 4.0):
				inside += 1
			if b["state"] == "do" and not crowd._idle_ok(at):
				loitering += 1
	_check(inside == 0, "over a minute nobody stands inside a prop or off the floor (%d samples)" % inside)
	_check(loitering == 0, "nobody settles on a station ring or in a gate lane (%d samples)" % loitering)
	var moved := 0
	for b in crowd.believers:
		if b["state"] == "walk" or float(b["t"]) > 0.0:
			moved += 1
	_check(moved == crowd.believers.size(), "everyone is walking or doing something")

	# Spending never removes anyone mid-visit; gains bring newcomers, capped.
	Global.followers = 100
	for i in range(20):
		crowd.tick(0.1)
	_check(crowd.believers.size() == 15, "spending leaves the crowd as it was (%d)" % crowd.believers.size())
	Global.followers = 1000000
	for i in range(300):
		crowd.tick(0.1)
	_check(crowd.believers.size() == CROWD.CROWD_CAP, "a million Followers fills the square to the cap (%d)" % crowd.believers.size())
	Global.followers = 1000000000
	for i in range(50):
		crowd.tick(0.1)
	_check(crowd.believers.size() == CROWD.CROWD_CAP, "a billion is still the cap (%d)" % crowd.believers.size())

	# Petting wins the key over the alcove ring when Beka is nearer.
	var beka: Node2D = crowd.beka
	var player: Node2D = hub._player
	beka.position = beka.bed
	beka._enter(beka.State.SLEEP)
	var feet: Vector2 = beka.bed + Vector2(38.0, -28.0)
	player.global_position = feet - Vector2(0.0, HubWorld.FEET)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var alcove: HubStation = null
	for station in hub._stations:
		if station.station_name == "Quiet Alcove":
			alcove = station
	_check(alcove != null and alcove.player_inside(), "the alcove ring is in reach too")
	var fired := [false]
	alcove.activated.connect(func() -> void: fired[0] = true)
	hub.interact()
	_check(beka.pets == 1 and not fired[0], "the key pets Beka, the nearer of the two")
	_check(beka.state == beka.State.SLEEP, "asleep, she stays asleep through a pet")
	_check(beka.focused and not alcove.focused, "only Beka shows a prompt")

	# Near her bed, she goes to sleep on it.
	player.global_position = hub._cell(16.0, 18.0) - Vector2(0.0, HubWorld.FEET)
	beka.position = beka.bed + Vector2(90.0, -20.0)
	beka._enter(beka.State.SIT)
	beka._arrive()
	for i in range(120):
		crowd.tick(0.1)
		if beka.is_asleep_on_bed():
			break
	_check(beka.is_asleep_on_bed(), "ending up near her bed, she curls up on it")

	# The merchant's ring still opens the merchant through the same key.
	var merchant_feet: Vector2 = HubWorld.STATION_CELLS["merchant"] * HubWorld.CELL
	player.global_position = merchant_feet - Vector2(0.0, HubWorld.FEET)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hub.interact()
	_check(hub._open_panel != null, "on the merchant's ring the key opens the merchant")
	if hub._open_panel != null and hub._open_panel.has_signal("embedded_closed"):
		hub._open_panel.emit_signal("embedded_closed")
	hub.queue_free()
	await get_tree().process_frame

	# Equipped: she follows the player around the square.
	var cat := ItemInstance.from_data(BEKA_DATA)
	var previous := Global.run_inventory.get_at(Inventory.SLOT_OFFHAND)
	Global.run_inventory.set_item(Inventory.SLOT_OFFHAND, cat)
	Global.followers = 0
	var hub2: HubWorld = HUB_WORLD.instantiate()
	hub2.departure_scene_change_enabled = false
	hub2.crowd_seed = 11
	add_child(hub2)
	await get_tree().process_frame
	_check(hub2.crowd.believers.is_empty(), "no Followers, no crowd — the staff still stand at their posts (%d)" % hub2.crowd.service.size())
	var beka2: Node2D = hub2.crowd.beka
	_check(beka2.following, "equipped, Beka follows the player in the hub")
	var target: Vector2 = hub2._cell(24.0, 8.0)
	hub2._player.global_position = target - Vector2(0.0, HubWorld.FEET)
	var start_gap := beka2.position.distance_to(target)
	for i in range(100):
		hub2.crowd.tick(0.1)
	_check(beka2.position.distance_to(target) < minf(start_gap, 110.0), "she catches up with the player (%.0f -> %.0f px)" % [start_gap, beka2.position.distance_to(target)])
	_check(get_tree().get_first_node_in_group(&"hub_beka") == beka2, "the combat companion's own cat defers to her in the hub")
	# Following close, she never takes a station's key.
	var ring: Vector2 = HubWorld.STATION_CELLS["merchant"] * HubWorld.CELL + Vector2(0.0, 50.0)
	hub2._player.global_position = ring - Vector2(0.0, HubWorld.FEET)
	beka2.position = ring + beka2.FOLLOW_OFFSET
	beka2._enter(beka2.State.SIT)
	# A teleport needs a few physics frames before the ring's area sees it.
	for k in range(4):
		await get_tree().physics_frame
	hub2.interact()
	_check(hub2._open_panel != null and beka2.pets == 0, "on the Merchant's ring the key opens the merchant, not a pet (pets %d)" % beka2.pets)
	if hub2._open_panel != null and hub2._open_panel.has_signal("embedded_closed"):
		hub2._open_panel.emit_signal("embedded_closed")
	Global.run_inventory.set_item(Inventory.SLOT_OFFHAND, previous)
	hub2.queue_free()
	await get_tree().process_frame

	print("HubCrowdTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
