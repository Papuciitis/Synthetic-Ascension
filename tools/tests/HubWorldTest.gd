extends Node

# The walkable between-segment hub (handoff 2026-09-25 §15): arriving after a
# completed segment puts a controllable player in a courtyard with the five
# stations; the segment counter never advances a second time; the merchant
# panel reuses the same vendor stock across open/close; combat inputs are
# disabled; departure is gated by a pending mandatory choice, happens once
# even when spammed, and routes the resume target back into the run; old
# saves that pointed at the full-screen shop route into the hub world.
#
# Run: <godot> --headless --path . res://tools/tests/HubWorldTest.tscn

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const BEKA_DATA := preload("res://data/items/defs/accessories/beka.tres")

var _passes := 0
var _failures := 0
var _hub: HubWorld


func _ready() -> void:
	call_deferred(&"_run")


## Collision matches the art (playtest 2026-09-27: blockers stopped the
## torso, so feet walked onto roofs and through props): with the player's
## real capsule placed so its drawn FEET stand on a point, every station
## medallion and the arrival are standable, the dais and a prop are solid,
## and the feet stop short of the south roofs.
func _check_feet_space_walkability(player: Node2D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var capsule := (player.get_node("CollisionShape2D") as CollisionShape2D).shape
	var space := player.get_world_2d().direct_space_state
	var blocked := func(feet: Vector2) -> bool:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = capsule
		query.transform = Transform2D(0.0, feet - Vector2(0.0, HubWorld.FEET))
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		return not space.intersect_shape(query, 1).is_empty()
	for key in HubWorld.STATION_CELLS.keys():
		var feet: Vector2 = HubWorld.STATION_CELLS[key] * HubWorld.CELL
		_check(not blocked.call(feet), "the %s medallion is standable (feet at %s)" % [key, str(feet)])
	var dais := HubWorld.PLAZA_CENTER * HubWorld.CELL
	_check(blocked.call(dais), "the dais under the obelisk is solid")
	_check(blocked.call(dais + Vector2(0.0, 100.0)), "the dais's front steps are solid")
	_check(blocked.call(Vector2(7.0, 15.8) * HubWorld.CELL), "feet stop before the south roofs")
	_check(not blocked.call(Vector2(7.0, 15.3) * HubWorld.CELL), "feet reach the square's south edge")
	_check(not blocked.call(Vector2(7.0, 4.6) * HubWorld.CELL), "feet reach the north house fronts")
	_check(blocked.call(Vector2(13.7, 2.6) * HubWorld.CELL + Vector2(0.0, -5.0)), "a lamp's base is solid")
	var station := _station("Merchant")
	player.global_position = station.global_position - Vector2(0.0, HubWorld.FEET)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(station.player_inside(), "standing on the medallion (feet on the ring) is in range")
	player.global_position = HubWorld.STATION_CELLS.arrival * HubWorld.CELL - Vector2(0.0, HubWorld.FEET)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _station(named: String) -> HubStation:
	for station in _hub._stations:
		if station.station_name == named:
			return station
	return null


func _stock_snapshot() -> Array:
	var out: Array = []
	var vendor_bag: BagInventory = Global.attempt_vendor_bag
	if vendor_bag == null:
		return out
	for slot in range(vendor_bag.get_slot_count()):
		var inst := vendor_bag.get_at(slot)
		if inst != null and inst.data != null:
			out.append(String(inst.data.id) + ":" + str(inst.rarity))
	return out


## Item identity is unique (integration pass b-4): one ItemInstance object
## lives in exactly one container, through trades and their undo alike.
func _identity_violations(shop: Node) -> Array:
	var containers := {
		"equipped": Global.run_inventory.items if Global.run_inventory != null else [],
		"bag": Global.run_bag.slots if Global.run_bag != null else [],
		"vendor": Global.attempt_vendor_bag.slots if Global.attempt_vendor_bag != null else [],
	}
	if shop != null:
		for extra in ["_offer_bag", "_demand_bag"]:
			var preview: BagInventory = shop.get(extra)
			if preview != null:
				containers[extra] = preview.slots
	var seen := {}
	var out: Array = []
	for where in containers:
		for inst in (containers[where] as Array):
			if inst == null:
				continue
			var id: int = (inst as Object).get_instance_id()
			if seen.has(id):
				out.append("%s duplicates %s" % [where, seen[id]])
			else:
				seen[id] = where
	return out


func _run() -> void:
	# A run that just completed segment 2: Global's completion transaction
	# already advanced the counter before the hub scene loads.
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	var save := SaveData.new()
	# Full isolation (D-18, after the slot-0 incident): this test's flows
	# (autosave debounce, the trade path's save_current_profile) write real
	# files, so they write into their own directory on the test slot — no
	# path here can touch a player's slots.
	SaveManager.save_dir = "user://saves_test_hub/"
	save.slot_index = 97
	SaveManager.current_save = save
	Global.attempt_segment = 2
	Global.on_segment_completed(2)
	_check(Global.attempt_segment == 3, "completion advanced the segment before the hub (%d)" % Global.attempt_segment)
	_check(save.attempt_resume_scene == Global.PATH_HUB_WORLD, "completion saves the hub world as the resume target")
	var vendor_segment_before: int = Global.attempt_vendor_segment
	var pending_choice: bool = Global.pending_big_choice

	_hub = HUB_WORLD.instantiate()
	_hub.departure_scene_change_enabled = false
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Global.attempt_segment == 3, "arriving in the hub never advances the segment again")
	var player := _hub._player
	_check(player != null and player.is_in_group(&"player"), "the arrival state is a controllable character in the world")
	var runner := player.get_node_or_null("AscensionRunner")
	_check(runner != null and not bool(runner.get("combat_inputs_enabled")), "ability inputs are disabled in the safe hub")
	_check(bool(player.get("_cinematic_attack_locked")), "the native weapon is locked in the safe hub")
	_check(_hub._stations.size() == 5, "merchant, ascension, gear, alcove and exit stand in the courtyard (%d)" % _hub._stations.size())
	_check(_station("Next Segment") != null and _station("Merchant") != null, "the stations carry their service names")
	await _check_feet_space_walkability(player)

	# The merchant panel: same stock across open/close, no side effects.
	_hub._open_merchant()
	await get_tree().process_frame
	await get_tree().process_frame
	var shop := _hub._open_panel
	_check(shop != null and bool(shop.get("embedded")), "the merchant opens the existing trade post as an embedded panel")
	var btn_return: Button = shop.get("btn_continue")
	_check(btn_return != null and btn_return.text == "Return to Courtyard", "the embedded return button says what it does (%s)" % (btn_return.text if btn_return != null else "missing"))
	var pending_before: bool = Global.pending_big_choice
	Global.pending_big_choice = true
	shop.call("_refresh_info")
	_check(btn_return != null and not btn_return.disabled and btn_return.text == "Return to Courtyard", "a pending mandatory choice never traps the player in the shop")
	Global.pending_big_choice = pending_before
	shop.call("_refresh_info")
	var stock_ids: Array = _stock_snapshot()
	_check(not stock_ids.is_empty(), "the vendor stocked its shelf")
	var segment_after_open: int = Global.attempt_segment
	shop.emit_signal("embedded_closed")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hub._open_panel == null, "closing the panel returns to the courtyard")
	_check(Global.attempt_segment == segment_after_open, "opening a shop panel never advances anything")
	_hub._open_merchant()
	await get_tree().process_frame
	await get_tree().process_frame
	var stock_again: Array = _stock_snapshot()
	_check(stock_again == stock_ids, "reopening the merchant is never a free reroll")
	(_hub._open_panel as Node).emit_signal("embedded_closed")
	await get_tree().process_frame


	# --- Item identity through a real trade and its undo (invariants b-4):
	# an ItemInstance object never sits in two containers at once, followers
	# come back exactly, and buyback keeps the sold item's identity.
	_hub._open_merchant()
	await get_tree().process_frame
	await get_tree().process_frame
	var trade_shop := _hub._open_panel
	_check(trade_shop != null, "the identity pass trades in a live merchant panel")
	var owned := ItemInstance.from_data(BEKA_DATA)
	owned.manifestation_id = &""
	Global.run_bag.add_instance(owned)
	var owned_slot: int = Global.run_bag.slots.find(owned)
	var vendor_bag: BagInventory = Global.attempt_vendor_bag
	var buy_slot := -1
	for slot in range(vendor_bag.get_slot_count()):
		if vendor_bag.get_at(slot) != null:
			buy_slot = slot
			break
	var bought: ItemInstance = vendor_bag.get_at(buy_slot)
	Global.set_followers(1000000)
	var followers_before: int = Global.followers
	_check(_identity_violations(trade_shop).is_empty(), "before the trade every item lives in exactly one container")
	trade_shop._sell_bag[owned_slot] = true
	trade_shop._buy_vendor[buy_slot] = true
	trade_shop.call("_refresh_cart")
	trade_shop.call("_perform_trade")
	var violations: Array = _identity_violations(trade_shop)
	_check(violations.is_empty(), "the trade moved items without duplicating any (%s)" % str(violations))
	_check(Global.run_bag.slots.has(bought) and not vendor_bag.slots.has(bought), "the bought instance moved vendor -> bag by identity")
	_check(vendor_bag.slots.has(owned) and not Global.run_bag.slots.has(owned), "the sold instance sits on the buyback shelf by identity")
	_check(Global.followers != followers_before, "the trade settled a real follower net")
	trade_shop.call("_undo_last_trade")
	violations = _identity_violations(trade_shop)
	_check(violations.is_empty(), "undo restores snapshots without duplicating any item (%s)" % str(violations))
	_check(Global.followers == followers_before, "undo returns the exact follower balance (%d)" % Global.followers)
	_check(not Global.run_bag.slots.has(owned) or not vendor_bag.slots.has(owned), "the sold original exists at most once after undo")
	(trade_shop as Node).emit_signal("embedded_closed")
	await get_tree().process_frame

	# The gear corner opens the run's own bag panel, not the vendor.
	_hub._open_gear()
	await get_tree().process_frame
	var gear_panel := _hub._open_panel
	_check(gear_panel != null, "the gear corner opens its own panel")
	var bag_ui: Node = gear_panel.get_child(0) if gear_panel != null and gear_panel.get_child_count() > 0 else null
	_check(bag_ui != null and bag_ui.has_method("is_open") and bool(bag_ui.call("is_open")), "the bag view opens bound to the run's containers")
	var close_button: Button = null
	for child in gear_panel.get_children():
		if child is Button:
			close_button = child
	_check(close_button != null and close_button.visible, "the gear panel shows a visible close button")
	# Real input: Escape closes the panel (playtest finding: the wrapper
	# trapped station input with no discoverable way out).
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hub._open_panel == null, "Escape closes the gear panel and returns to the courtyard")
	_check(_hub._gear_bag == null, "the bag reference is released with the panel")

	# The close button path too: reopen, click, closed again.
	_hub._open_gear()
	await get_tree().process_frame
	close_button = null
	for child in (_hub._open_panel as Node).get_children():
		if child is Button:
			close_button = child
	if close_button != null:
		close_button.emit_signal("pressed")
	await get_tree().process_frame
	_check(_hub._open_panel == null, "the close button also returns to the courtyard")

	# Departure: gated by a pending mandatory choice, and only once.
	Global.pending_big_choice = true
	_hub._update_pending_cue()
	_check(_hub._exit_station.attention, "a pending required choice shows an in-world cue at the gate")
	_hub._try_depart()
	await get_tree().process_frame
	_check(not _hub._departing, "the gate refuses departure while the choice waits")
	_check(_hub._major_choice != null, "the gate opens the required choice instead")
	if _hub._major_choice != null:
		_hub._major_choice.queue_free()
		_hub._major_choice = null
	Global.pending_big_choice = false
	_hub._on_panel_closed()

	# Block the actual scene change so the test can observe the transition
	# state; double-activation must still collapse to one departure.
	_hub._try_depart()
	_check(_hub._departing, "departure engages once")
	var resume_after: String = save.attempt_resume_scene
	_hub._try_depart()
	_hub._try_depart()
	_check(_hub._departing and resume_after == Global.PATH_GAME, "spamming the gate cannot load the next segment twice; the resume target is the run (%s)" % resume_after)

	# Old saves that pointed at the full-screen shop route into the hub —
	# through the production mapping goto_resume itself uses.
	save.attempt_active = true
	save.attempt_resume_scene = Global.PATH_HUB_SHOP
	_check(Global.resume_scene_for(save) == Global.PATH_HUB_WORLD, "an old shop-target save resumes into the walkable hub")
	save.attempt_resume_scene = ""
	_check(Global.resume_scene_for(save) == Global.PATH_HUB_WORLD, "a save with no resume target lands in the hub, never nowhere")
	save.attempt_resume_scene = Global.PATH_GAME
	_check(Global.resume_scene_for(save) == Global.PATH_GAME, "a mid-segment save resumes into the segment")

	# Leave no residue: remove this run's isolated save files and hand the
	# manager its production directory back.
	var test_dir := ProjectSettings.globalize_path(SaveManager.save_dir)
	if DirAccess.dir_exists_absolute(test_dir):
		for file in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(test_dir.path_join(file))
		DirAccess.remove_absolute(test_dir)
	SaveManager.save_dir = SaveManager.SAVE_DIR
	SaveManager.current_save = null
	_check(not FileAccess.file_exists("user://saves_test_hub/slot_97.tres"), "the isolated save directory is cleaned up")

	print("HubWorldTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
