extends Control

## Breaks if the management archive grows with its content, rebuilds unchanged
## records, or loses a reader's selected/focused page during a HUD refresh.

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
			_check(
				(_run_sheet.get_node(path) as Button).focus_mode == Control.FOCUS_ALL,
				"%s tab accepts keyboard and controller focus" % page_name
			)

	_check(_run_sheet.has_method("select_page"), "Run Sheet exposes page selection")
	_check(_run_sheet.has_method("selected_page"), "Run Sheet exposes stable selected-page state")
	_check(_run_sheet.has_method("debug_rebuild_counts"), "Run Sheet exposes cache counters")

	if complete_index and _run_sheet.has_method("select_page"):
		for page_index in range(page_names.size()):
			_run_sheet.call("select_page", page_index)
			await get_tree().process_frame
			_check(_visible_page_count() == 1, "only %s page is visible" % page_names[page_index])

		_run_sheet.call("select_page", 3)
		await get_tree().process_frame
		var observations := _run_sheet.get_node_or_null("Archive/BodyMargin/Pages/ObservationsScroll")
		_check(
			observations != null and "COUNTER  //" in _collect_label_text(observations),
			"observation counters remain visible without hover"
		)
		var record := _first_focusable(observations)
		if record != null:
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

	Global.discovered_enemy_ids.assign(saved_discoveries)
	player.queue_free()
	print("RunSheetArchiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


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
