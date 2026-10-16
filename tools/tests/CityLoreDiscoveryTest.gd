extends Node
## Optional source collection through the existing Chronicle profile layer.
## Isolated save directory; never opens or writes a player's save slot.

const LIBRARY := preload("res://ui/screens/HubLibraryData.gd")
const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const DISCOVERY_PATH := "res://core/systems/narrative/CityLoreDiscovery.gd"
const PAPERS_PATH := "res://ui/screens/CityLorePapers.gd"
const CITY_IDS: Array[String] = [
	"city_service_lamp", "city_interval_margin", "city_order_times", "city_laundry_window",
	"city_bren_copy", "city_tree_door", "city_reconstruction_stores", "city_blank_destination",
]

var _passes := 0
var _failures := 0
var _discovery: RefCounted = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("CityLoreDiscoveryTest: " + message)


func _fresh() -> void:
	SaveManager.current_save = null
	Global.meta_pending_peep.clear()
	Global.meta_city_commitments.clear()
	Global.start_new_attempt()
	Global.attempt_doctrine_stage_ids.clear()
	Global.attempt_segment1_milestones.clear()
	Global.grimoire_entries.clear()
	Global.library_read_entries.clear()
	Global.library_target_key = ""
	StoryDirector.load_state({})


func _find(entries: Array, key: String) -> Dictionary:
	for row: Dictionary in entries:
		if String(row.get("key", "")) == key:
			return row
	return {}


func _available_ids() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _discovery.call("available_documents"):
		out.append(String(row["id"]))
	return out


func _test_catalogue() -> void:
	var records := StoryDirector.record_catalogue()
	_check(records.size() == 27, "Chronicles adds eight source documents to the existing nineteen records")
	for id: String in CITY_IDS:
		var row := _find(records, "record:" + id)
		_check(not row.is_empty() and String(row.get("section", "")) == "RECORDS", "the Library can address optional Chronicle " + id)
	for original: Dictionary in StoryLines.RECORDS:
		var row := _find(records, "record:" + String(original["id"]))
		_check(not row.is_empty() and row.get("name") == original["name"] and row.get("rule") == original["rule"] and row.get("hint") == original["hint"], "existing Chronicle adaptation remains intact: " + String(original["id"]))
	_check(Global.grimoire_entries.is_empty(), "building the catalogue discovers no optional page")


func _test_sealed_guidance_matches_collectible_route() -> void:
	var entries := LIBRARY.build_entries()
	for source: Dictionary in [
		{"id": "city_service_lamp", "stage": 1, "gate": "complet", "absent": "beside the admission desk"},
		{"id": "city_interval_margin", "stage": 1, "gate": "complet"},
		{"id": "city_order_times", "stage": 2, "gate": "reach", "absent": "through the service yards"},
		{"id": "city_laundry_window", "stage": 4, "gate": "reach", "absent": "safe approach"},
		{"id": "city_bren_copy", "stage": 3, "gate": "complet"},
		{"id": "city_tree_door", "stage": 6, "gate": "reach", "absent": "inside a marked service door"},
		{"id": "city_reconstruction_stores", "stage": 7, "gate": "reach"},
		{"id": "city_blank_destination", "stage": 10, "gate": "reach", "absent": "safe arrival side"},
	]:
		var id := String(source["id"])
		var page := _find(entries, "record:" + id)
		var hint := String(page.get("hint", "")).to_lower()
		_check(hint.contains("papers") and hint.contains("quiet alcove"), "sealed Chronicle guidance points to the implemented Papers tray beside Quiet Alcove: " + id)
		_check(hint.contains(String(source["gate"])) and hint.contains("segment %d" % int(source["stage"])), "sealed Chronicle guidance describes its actual reached/completed availability stage: " + id)
		if source.has("absent"):
			_check(not hint.contains(String(source["absent"])), "sealed Chronicle guidance does not direct players to a deferred physical pickup: " + id)
	_check(Global.grimoire_entries.is_empty(), "reading recovery clues never collects or reads the optional sources")


func _test_actual_arrival_and_hub_boundary() -> void:
	_fresh()
	Global.attempt_segment = 4
	StoryDirector.note_segment_completed(3)
	StoryDirector.note_progress()
	var at_hub := _available_ids()
	_check(at_hub.has("city_service_lamp") and at_hub.has("city_interval_margin") and at_hub.has("city_order_times") and at_hub.has("city_bren_copy"), "completed S3 offers the earlier hub copies")
	_check(not at_hub.has("city_laundry_window"), "the hub's next-segment counter is not evidence of arrival in S4")
	StoryDirector.note_progress(4)
	_check(_available_ids().has("city_laundry_window"), "actual played S4 makes its optional copy available")
	_check(not Global.grimoire_has("record:city_laundry_window"), "arrival availability never auto-discovers the laundry note")
	var saved_story := StoryDirector.state_for_save()
	Global.start_new_attempt()
	StoryDirector.load_state(saved_story)
	_check(_available_ids().has("city_laundry_window"), "actual arrival evidence survives a fresh attempt and story reload")
	_check(not _available_ids().has("city_tree_door"), "S4 evidence does not reveal the sixth district's source")


func _test_opening_milestone_and_completed_stage_limits() -> void:
	_fresh()
	Global.attempt_segment1_milestones.append(&"admitted")
	StoryDirector.note_progress(1)
	_check(StoryDirector.has_flag("city_lore:milestone:admitted"), "observed admission is latched in the existing durable story flags")
	_check(not _available_ids().has("city_service_lamp"), "the lamp's recovery copy waits for completed S1 even after admission")
	_check(not Global.grimoire_has("record:city_service_lamp"), "admission does not collect its slip")
	StoryDirector.note_segment_completed(1)
	_check(_available_ids().has("city_service_lamp") and _available_ids().has("city_interval_margin"), "completed S1 makes both first-hub working copies available")
	_check(not _available_ids().has("city_order_times"), "completed S1 alone does not prove entry into S2")
	StoryDirector.note_progress(2)
	_check(_available_ids().has("city_order_times"), "the S2 source appears on actual arrival without requiring a defeat")
	_check(not _available_ids().has("city_bren_copy"), "Bren's cover sheet waits for completed S3")
	StoryDirector.note_segment_completed(3)
	_check(_available_ids().has("city_bren_copy"), "completed S3 makes Bren's packet available")


func _test_legacy_progress_is_conservative() -> void:
	for evidence: Dictionary in [
		{"best": 3, "want": "city_bren_copy", "absent": "city_laundry_window"},
		{"stage": "method", "want": "city_bren_copy", "absent": "city_laundry_window"},
		{"stage": "doctrine", "want": "city_tree_door", "absent": "city_reconstruction_stores"},
		{"stage": "apotheosis", "want": "city_reconstruction_stores", "absent": "city_blank_destination"},
	]:
		_fresh()
		if evidence.has("best"):
			StoryDirector.load_state({"v": 1, "best": int(evidence["best"])})
		else:
			Global.meta_city_commitments[String(evidence["stage"])] = "preserved_choice"
		var available := _available_ids()
		_check(available.has(String(evidence["want"])) and not available.has(String(evidence["absent"])), "legacy evidence proves its own completed stage only: " + str(evidence))
		_check(Global.grimoire_entries.is_empty(), "legacy progress does not silently discover or read pages")
	_fresh()
	StoryDirector.add_flag("area:1")
	_check(_available_ids().size() == 8, "Area I completion offers all eight copies after a successful escape")
	_check(Global.grimoire_entries.is_empty(), "successful escape availability remains optional")
	_fresh()
	Global.set_followers(100000)
	StoryDirector.note_reconstruction()
	_check(_available_ids().is_empty(), "Followers and reconstruction alone unlock no city source document")


func _test_explicit_collection_and_existing_reader() -> void:
	_fresh()
	_check(not bool(_discovery.call("collect", "city_blank_destination")), "an unavailable source cannot be copied")
	_check(not bool(_discovery.call("collect", "unknown_document")), "unknown source IDs cannot create arbitrary Chronicle discoveries")
	StoryDirector.note_segment_completed(1)
	var before := _find(LIBRARY.build_entries(), "record:city_service_lamp")
	_check(not bool(before.get("discovered", true)), "available sources remain sealed in the existing Library before collection")
	var followers_before := Global.followers
	var rng_before := Global._rng.state
	SaveManager.current_save = SaveData.new()
	SaveManager.current_save.slot_index = 96
	var writes_before := SaveManager.debug_save_writes
	_check(bool(_discovery.call("collect", "city_service_lamp")), "explicit copying records a previously uncollected source")
	_check(Global.grimoire_has("record:city_service_lamp") and SaveManager.current_save.meta_grimoire.has("record:city_service_lamp"), "copying saves the existing Grimoire key before returning control")
	_check(SaveManager.debug_save_writes == writes_before + 1, "a successful explicit copy writes one coherent profile snapshot")
	_check(not Global.library_read_entries.has("record:city_service_lamp"), "copying leaves the full Chronicle unread")
	var page := _find(LIBRARY.build_entries(), "record:city_service_lamp")
	_check(String(page.get("category", "")) == "Chronicles" and bool(page.get("unread", false)), "the collected page enters the existing unread Chronicles view")
	_check(LIBRARY.filter_entries([page], "Chronicles", "spare coil").size() == 1, "the collected full text participates in existing Library search")
	_check(not bool(_discovery.call("collect", "city_service_lamp")) and SaveManager.debug_save_writes == writes_before + 1, "duplicate collection neither rewards nor writes a second pickup")
	_check(Global.followers == followers_before and Global._rng.state == rng_before, "source copying spends no Followers and rolls no gameplay RNG")
	Global.library_mark_read("record:city_service_lamp")
	Global.library_set_target("record:city_service_lamp")
	var snapshot := SaveData.new()
	Global.write_save(snapshot)
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.apply_save(snapshot)
	_check(Global.grimoire_has("record:city_service_lamp") and Global.library_read_entries.has("record:city_service_lamp") and Global.library_target_key == "record:city_service_lamp", "existing profile reload retains copied, read and bookmark states independently")


func _test_papers_panel() -> void:
	_fresh()
	StoryDirector.note_segment_completed(1)
	_check(ResourceLoader.exists(PAPERS_PATH), "available sources have an optional inspection panel")
	if not ResourceLoader.exists(PAPERS_PATH):
		return
	var panel_script := load(PAPERS_PATH) as Script
	var panel: CanvasLayer = panel_script.new()
	add_child(panel)
	await get_tree().process_frame
	_check(bool(panel.call("inspect_document", "city_service_lamp")), "a title can be inspected without collecting its page")
	var inspected: Dictionary = _discovery.call("document", "city_service_lamp")
	var excerpt := panel.get("_excerpt") as Label
	_check(excerpt.text == String(inspected["excerpt"]) and excerpt.text != String(inspected["body"]), "inspection shows the field excerpt while the full document waits in Chronicles")
	_check(not Global.grimoire_has("record:city_service_lamp"), "showing an excerpt does not discover the full document")
	panel.call("leave_document")
	_check(not Global.grimoire_has("record:city_service_lamp") and _available_ids().has("city_service_lamp"), "Leave keeps an uncollected source available")
	panel.call("inspect_document", "city_service_lamp")
	_check(bool(panel.call("keep_copy")) and Global.grimoire_has("record:city_service_lamp"), "Keep a copy explicitly discovers the inspected source")
	panel.call("_close")
	await get_tree().process_frame
	_check(not get_tree().paused, "closing the optional papers panel restores its previous pause state")


func _viewport_key(viewport: Viewport, key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		viewport.push_input(event, true)


func _viewport_pad(viewport: Viewport, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		viewport.push_input(event, true)


func _test_small_excerpt_reading() -> void:
	_fresh()
	StoryDirector.note_segment_completed(10)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.disable_3d = true
	add_child(viewport)
	var panel_script := load(PAPERS_PATH) as Script
	var panel: CanvasLayer = panel_script.new()
	viewport.add_child(panel)
	await get_tree().process_frame
	panel.call("inspect_document", "city_blank_destination")
	for frame: int in range(4):
		await get_tree().process_frame
	var scroll := panel.get("_scroll") as ScrollContainer
	var excerpt := panel.get("_excerpt") as Label
	var title := panel.get("_detail_title") as Label
	var keep := panel.get("_keep_button") as Button
	var leave := panel.get("_leave_button") as Button
	var maximum := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	print("City lore 640 reading fixture: overflow=%d excerpt=%s clip=%s" % [maximum, str(excerpt.get_global_rect()), str(scroll.get_global_rect())])
	if maximum > 0:
		_check(scroll.has_focus() and scroll.scroll_vertical == 0 and title.get_global_rect().position.y >= scroll.get_global_rect().position.y, "overflowing 640 excerpt opens at its beginning with reading focus")
		_viewport_key(viewport, KEY_DOWN)
		await get_tree().process_frame
		_check(scroll.has_focus() and scroll.scroll_vertical > 0 and scroll.scroll_vertical <= mini(maximum, 64), "Down incrementally reads the real excerpt without moving focus to the actions")
		scroll.scroll_vertical = 0
		await get_tree().process_frame
		_viewport_key(viewport, KEY_PAGEDOWN)
		await get_tree().process_frame
		_check(scroll.has_focus() and scroll.scroll_vertical > 0, "Page Down advances the real excerpt while retaining reading focus")
		scroll.scroll_vertical = 0
		await get_tree().process_frame
		_viewport_pad(viewport, JOY_BUTTON_DPAD_DOWN)
		await get_tree().process_frame
		_check(scroll.has_focus() and scroll.scroll_vertical > 0 and scroll.scroll_vertical <= mini(maximum, 64), "controller Down incrementally reads the real excerpt")
		for page: int in range(8):
			_viewport_key(viewport, KEY_PAGEDOWN)
			await get_tree().process_frame
		_check(excerpt.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "keyboard reading reaches the final line of the approved excerpt")
		_viewport_key(viewport, KEY_TAB)
		await get_tree().process_frame
		_check(keep.has_focus(), "Tab leaves excerpt reading for Keep a copy")
	else:
		_check(excerpt.get_global_rect().position.y >= scroll.get_global_rect().position.y and excerpt.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "a non-overflowing 640 excerpt is visible in full without scrolling")
	for action: Button in [keep, leave]:
		var bounds := action.get_global_rect()
		_check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 640.5 and bounds.end.y <= 480.5, "640 reading keeps its action inside the viewport: " + action.text)
	_check(not Global.grimoire_has("record:city_blank_destination"), "reading with keyboard and controller never silently copies the source")
	panel.call("_close")
	viewport.queue_free()
	await get_tree().process_frame


func _test_hub_papers_entry() -> void:
	_fresh()
	Global.attempt_segment = 2
	StoryDirector.note_segment_completed(1)
	StoryDirector.cards_override = 0
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 4
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var papers: HubStation = null
	var alcove: HubStation = null
	for station: HubStation in hub._stations:
		if station.station_name == "Papers":
			papers = station
		if station.station_name == "Quiet Alcove":
			alcove = station
	_check(papers != null and alcove != null, "Quiet Alcove has an optional Papers entry alongside Browse")
	if papers != null and alcove != null:
		_check(papers.global_position.distance_to(alcove.global_position) <= 256.0, "the papers tray stands beside the Quiet Alcove")
		var segment_before := Global.attempt_segment
		var followers_before := Global.followers
		papers.activated.emit()
		await get_tree().process_frame
		_check(is_instance_valid(hub._open_panel) and hub._open_panel.has_method("inspect_document"), "the managed Papers station opens the actual optional inspection panel")
		if is_instance_valid(hub._open_panel):
			hub._open_panel.call("_close")
		await get_tree().process_frame
		_check(not hub._panel_is_open() and Global.attempt_segment == segment_before and Global.followers == followers_before, "closing papers returns to the courtyard without progression or currency changes")
	hub.queue_free()
	await get_tree().process_frame
	StoryDirector.cards_override = -1


func _run() -> void:
	SaveManager.save_dir = "user://saves_test_city_lore/"
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	_fresh()
	_test_catalogue()
	_test_sealed_guidance_matches_collectible_route()
	if ResourceLoader.exists(DISCOVERY_PATH):
		var discovery_script := load(DISCOVERY_PATH) as Script
		_discovery = discovery_script.new()
		_test_actual_arrival_and_hub_boundary()
		_test_opening_milestone_and_completed_stage_limits()
		_test_legacy_progress_is_conservative()
		_test_explicit_collection_and_existing_reader()
		await _test_papers_panel()
		await _test_small_excerpt_reading()
	else:
		_check(false, "source availability and explicit collection must be implemented separately from story progress")
	await _test_hub_papers_entry()
	SaveManager.current_save = null
	Global._cancel_autosave_timer()
	print("CityLoreDiscoveryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
