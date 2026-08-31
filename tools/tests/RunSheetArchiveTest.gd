extends Control

## Breaks if the management archive grows with its content, rebuilds unchanged
## records, or loses a reader's selected/focused page during a HUD refresh.

## How many of the Conduit set's authored doctrine passages (playstyle, build
## guidance, and each tier's mechanical and plain wording) the Sets archive
## must be showing before "the compact hover omits them" means anything. The
## archive renders all 8 at 127d4be; 6 is a floor with slack, not a target.
const ARCHIVE_DOCTRINE_PASSAGES: int = 6


class ManifestationRunnerFixture:
	extends Node

	func get_active_summaries() -> Array[Dictionary]:
		return [{
			"slot": Inventory.SLOT_RING,
			"name": "Resonant Primer",
			"rule": "A complete fixture protocol remains available to focused readers.",
			"tags": [&"momentum"],
		}]

	func get_active_pairs() -> Array[Dictionary]:
		return [{
			"id": &"litany_engine",
			"name": "Litany Engine",
			"nouns": [&"momentum", &"cadence"],
			"rule": "Every third invocation seals the nearest wound.",
		}]

	func get_noun_counts() -> Dictionary:
		return {&"momentum": 2, &"cadence": 2}

	func get_meters() -> Array[Dictionary]:
		return [{"noun": &"cadence", "label": "CADENCE", "text": "1.9s"}]


class PlayerFixture:
	extends Node
	var hp := 85.0
	var max_hp := 100.0
	var armor := 3.0
	var speed := 135.0
	var power := 0.31
	var haste := 0.15
	var luck := 0.70
	var stats: Variant = null
	var last_burden: BurdenSnapshot = null


var _passes := 0
var _failures := 0

@onready var _run_sheet: RunSheetHUD = $RunSheetHUD


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var saved_discoveries: Array[StringName] = Global.discovered_enemy_ids.duplicate()
	Global.discovered_enemy_ids.assign([&"enemy_grunt"])
	var player := PlayerFixture.new()
	var runner := ManifestationRunnerFixture.new()
	runner.name = "ManifestationRunner"
	player.add_child(runner)
	add_child(player)
	var inventory := Inventory.new()

	_run_sheet.visible = true
	_run_sheet.refresh(player, inventory)
	await get_tree().process_frame
	_check(_run_sheet.size.y <= 540.0, "Run Sheet remains bounded")

	var page_names := ["Profile", "Sets", "Manifestations", "Observations"]
	var complete_index := true
	for page_name in page_names:
		var path := NodePath("Archive/Index/" + page_name)
		var has_button := _run_sheet.has_node(path)
		complete_index = complete_index and has_button
		_check(has_button, "side index exposes the %s tab" % page_name)
		if has_button:
			var tab := _run_sheet.get_node(path) as Button
			_check(
				tab.focus_mode == Control.FOCUS_ALL,
				"%s tab accepts keyboard and controller focus" % page_name
			)
			_check(tab.get_theme_font_size("font_size") >= 12, "%s tab survives 1280 canvas scaling" % page_name)

	_check(_run_sheet.has_method("select_page"), "Run Sheet exposes page selection")
	_check(_run_sheet.has_method("selected_page"), "Run Sheet exposes stable selected-page state")
	_check(_run_sheet.has_method("debug_rebuild_counts"), "Run Sheet exposes cache counters")

	if complete_index and _run_sheet.has_method("select_page"):
		for page_index in range(page_names.size()):
			_run_sheet.call("select_page", page_index)
			await get_tree().process_frame
			_check(_visible_page_count() == 1, "only %s page is visible" % page_names[page_index])
		if _run_sheet.has_node("Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox"):
			var manifestation_page := _run_sheet.get_node("Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox")
			var boxes := manifestation_page.find_children("*", "ManifestationInfoBox", true, false)
			_check(not boxes.is_empty(), "Manifestations expose a readable protocol record")
			if not boxes.is_empty():
				var rule_label := (boxes[0] as Control).get_child((boxes[0] as Control).get_child_count() - 1) as Label
				_check(rule_label.get_theme_font_size("font_size") >= 12, "Manifestation protocols survive 1280 canvas scaling")

		_run_sheet.call("select_page", 3)
		await get_tree().process_frame
		var observations := _run_sheet.get_node_or_null("Archive/BodyMargin/Pages/ObservationsScroll")
		_check(
			observations != null and "COUNTER  //" in _collect_label_text(observations),
			"observation counters remain visible without hover"
		)
		var record := _first_focusable(observations)
		if record != null:
			var name_label := record.get_child(0) as Label
			var counter_label := record.get_child(1) as Label
			_check(name_label.get_theme_font_size("font_size") >= 12, "observation names survive 1280 canvas scaling")
			_check(counter_label.get_theme_font_size("font_size") >= 13, "observation counters survive 1280 canvas scaling")
			record.grab_focus()
			await get_tree().process_frame
			var focus_before := get_viewport().gui_get_focus_owner()
			var selected_before: int = int(_run_sheet.call("selected_page"))
			_run_sheet.refresh(player, inventory)
			await get_tree().process_frame
			_check(int(_run_sheet.call("selected_page")) == selected_before, "refresh preserves the selected page")
			_check(get_viewport().gui_get_focus_owner() == focus_before, "unchanged refresh preserves focused records")
		else:
			_check(false, "Observations expose a focusable dossier record")

	if _run_sheet.has_method("debug_rebuild_counts"):
		var before := _run_sheet.call("debug_rebuild_counts") as Dictionary
		_run_sheet.refresh(player, inventory)
		_run_sheet.refresh(player, inventory)
		var after := _run_sheet.call("debug_rebuild_counts") as Dictionary
		_check(before == after, "unchanged static pages are not rebuilt")

	await _verify_set_archive_owns_full_doctrine(player)

	Global.discovered_enemy_ids.assign(saved_discoveries)
	player.queue_free()
	print("RunSheetArchiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _verify_set_archive_owns_full_doctrine(player: Node) -> void:
	var previous_inventory: Inventory = Global.run_inventory
	var inventory := Inventory.new()
	var paths := [
		"res://data/items/defs/conduit/conduit_heart.tres",
		"res://data/items/defs/conduit/conduit_plating.tres",
		"res://data/items/defs/conduit/conduit_greaves.tres",
		"res://data/items/defs/conduit/conduit_lens.tres",
		"res://data/items/defs/conduit/conduit_actuators.tres",
		"res://data/items/defs/conduit/conduit_charm.tres",
	]
	var hovered_item: ItemInstance = null
	for path: String in paths:
		var data := load(path) as ItemData
		_check(data != null, "Conduit fixture loads from %s" % path.get_file())
		if data == null:
			continue
		var item := ItemInstance.from_roll(data, 4, ItemInstance.Polarity.POS, 0.45)
		inventory.set_item(int(data.equip_slot), item)
		if String(data.id) == "conduit_greaves":
			hovered_item = item

	Global.run_inventory = inventory
	_run_sheet.refresh(player, inventory)
	_run_sheet.select_page(RunSheetHUD.ArchivePage.SETS)
	await get_tree().process_frame
	var archive_text := _collect_label_text(_run_sheet)
	_check(
		"A velocity set that turns kills" in archive_text,
		"Sets archive owns the selected set identity"
	)
	_check(
		"Overclock Protocol" in archive_text and "Kills speed you up" in archive_text,
		"Sets archive owns full breakpoint doctrine"
	)
	_check(
		"PLAYSTYLE // Keep moving" in archive_text
		and "BEST WITH // Fast weapons" in archive_text
		and "Set strength — Scaling derived" in archive_text,
		"Sets archive owns playstyle, build guidance and terminology"
	)
	_check(
		_find_button_containing(_run_sheet, "CONDUIT") != null,
		"Sets archive exposes compact selectable set records"
	)
	_check(_run_sheet.has_method("inspect_set"), "item hover can select a matching set record")

	var tooltip_scene := load("res://ui/widgets/ItemTooltip.tscn") as PackedScene
	var tooltip := tooltip_scene.instantiate() as ItemTooltip if tooltip_scene != null else null
	_check(tooltip != null, "compact item dossier instantiates")
	if tooltip != null and hovered_item != null:
		add_child(tooltip)
		tooltip.show_item(hovered_item)
		var hover_text := tooltip.body_label.text
		# The compact hover must not repeat the long-form doctrine the Sets
		# archive owns. This used to assert the absence of "SET IDENTITY",
		# "SET PROGRESSION", "BEST WITH" and "TERMS": the first two occur in no
		# production file at all and the last two only as RunSheetHUD headings,
		# so nothing the tooltip can build could contain any of them and the
		# check could not fail. It now reads the forbidden passages off the same
		# SetData the tooltip itself holds, and only asserts about the ones the
		# archive is actually showing - so inlining any of that doctrine into
		# the hover turns it red.
		var conduit_set: SetData = Global.set_db.get(&"conduit", null) as SetData
		_check(conduit_set != null, "the Conduit set resource is reachable through Global.set_db")
		if conduit_set != null:
			var doctrine: Array[String] = [conduit_set.playstyle, conduit_set.best_with]
			for tier: SetTier in conduit_set.sorted_tiers():
				if tier == null:
					continue
				doctrine.append(tier.mechanical_description)
				doctrine.append(tier.plain_description)
			var owned_by_archive: Array[String] = []
			var leaked_into_hover: Array[String] = []
			for passage: String in doctrine:
				var text := passage.strip_edges()
				if text == "":
					continue
				if not text in archive_text:
					continue
				owned_by_archive.append(text)
				if text in hover_text:
					leaked_into_hover.append(text)
			_check(
				owned_by_archive.size() >= ARCHIVE_DOCTRINE_PASSAGES,
				"the Sets archive shows the set's long-form doctrine (%d passages, floor %d)"
					% [owned_by_archive.size(), ARCHIVE_DOCTRINE_PASSAGES]
			)
			_check(
				leaked_into_hover.is_empty(),
				"item hover omits doctrine already owned by the Sets archive (leaked: %s)"
					% "; ".join(leaked_into_hover)
			)
		_check(
			"RUN SHEET // SETS" in hover_text and "CONDUIT" in hover_text,
			"compact item hover preserves set status and points to its archive"
		)
		_check(tooltip.has_method("set_dossier_mode"), "paused hover supports a fixed dossier presentation")
		if tooltip.has_method("set_dossier_mode"):
			tooltip.call("set_dossier_mode", true)
			var kicker := tooltip.get_node_or_null("Margin/VBox/Kicker") as Control
			_check(kicker != null and kicker.visible, "paused dossier identifies itself as an equipment record")
			await _verify_management_dossier_is_a_fixed_sidecar(
				tooltip_scene, hovered_item, player, inventory
			)
		tooltip.queue_free()
		await get_tree().process_frame
	_run_sheet.inspect_set(&"lattice")
	_run_sheet.refresh(player, inventory)
	var cross_set_archive_text := _collect_label_text(_run_sheet)
	_check(
		"A spatial combo set that records attack positions" in cross_set_archive_text,
		"HUD refresh preserves an unequipped set selected by bag hover"
	)
	_run_sheet.refresh(player, Inventory.new())
	_run_sheet.inspect_set(&"conduit")
	var unequipped_archive_text := _collect_label_text(_run_sheet)
	_check(
		"A velocity set that turns kills" in unequipped_archive_text
		and "CONDUIT" in unequipped_archive_text,
		"hovered bag sets remain inspectable with zero pieces equipped"
	)
	Global.run_inventory = previous_inventory


func _verify_management_dossier_is_a_fixed_sidecar(
	tooltip_scene: PackedScene,
	hovered_item: ItemInstance,
	player: Node,
	equipped_inventory: Inventory
) -> void:
	var bag := Control.new()
	bag.name = "DossierBag"
	bag.position = Vector2(1000, 8)
	bag.size = Vector2(210, 260)
	add_child(bag)
	var source := Control.new()
	source.position = Vector2(24, 180)
	source.size = Vector2(44, 44)
	add_child(source)
	var controller := HudTooltipController.new()
	controller.tooltip_scene = tooltip_scene
	controller.bag_ui_path = NodePath("../DossierBag")
	controller.run_sheet_path = NodePath("../RunSheetHUD")
	add_child(controller)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(controller.has_method("set_management_mode"), "tooltip controller supports paused dossier layout")
	if controller.has_method("set_management_mode"):
		_run_sheet.select_page(RunSheetHUD.ArchivePage.PROFILE)
		var page_before := _run_sheet.selected_page()
		var lattice_data := load(
			"res://data/items/defs/lattice/lattice_focusnode.tres"
		) as ItemData
		var lattice_item := ItemInstance.from_roll(
			lattice_data, 3, ItemInstance.Polarity.POS, 0.35
		) if lattice_data != null else null
		controller.call("set_management_mode", true)
		# The controller's hover step is the same three calls it always was; the
		# measure/place split is the tooltip idle-cost fix (perf audit §2 #1),
		# which only changes how OFTEN the first two run.
		var shown: ItemInstance = lattice_item if lattice_item != null else hovered_item
		controller.call("_show_tooltip", shown)
		controller.call("_inspect_set_for", shown)
		controller.call("_measure_tooltip")
		controller.call("_place_tooltip", source)
		var sidecar := controller.get("_tooltip") as Control
		_check(sidecar != null and sidecar.visible, "paused dossier remains visible beside the management surfaces")
		if sidecar != null:
			_check(
				sidecar.global_position.x + sidecar.size.x <= bag.global_position.x - 8.0,
				"paused dossier anchors left of the Bag instead of following the hovered slot"
			)
		var hover_archive_text := _collect_label_text(_run_sheet)
		_check(
			"A spatial combo set that records attack positions" in hover_archive_text,
			"real tooltip controller routes hovered item sets into the archive"
		)
		_check(
			_run_sheet.selected_page() == page_before,
			"item hover updates set context without forcing the Sets page open"
		)
		_run_sheet.refresh(player, equipped_inventory)
		_check(
			"A spatial combo set that records attack positions" in _collect_label_text(_run_sheet),
			"hover-selected zero-equipped doctrine survives the next HUD refresh"
		)
	controller.queue_free()
	bag.queue_free()
	source.queue_free()
	await get_tree().process_frame


func _visible_page_count() -> int:
	var pages := _run_sheet.get_node_or_null("Archive/BodyMargin/Pages")
	if pages == null:
		return 0
	var count := 0
	for page in pages.get_children():
		if page is Control and (page as Control).visible:
			count += 1
	return count


func _collect_label_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _first_focusable(node: Node) -> Control:
	if node == null:
		return null
	if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL:
		return node as Control
	for child in node.get_children():
		var match := _first_focusable(child)
		if match != null:
			return match
	return null


func _find_button_containing(node: Node, needle: String) -> Button:
	if node is Button and needle in (node as Button).text.to_upper():
		return node as Button
	for child in node.get_children():
		var match := _find_button_containing(child, needle)
		if match != null:
			return match
	return null
