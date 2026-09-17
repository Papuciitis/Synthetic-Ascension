extends Control

## Verifies that combat objectives remain readable without becoming a second
## inventory screen. Changes may expand briefly; settled HUD state is compact.

const SETTLE_SECONDS := 3.25


class PairRunnerFixture:
	extends Node

	func get_active_summaries() -> Array[Dictionary]:
		return [{
			"slot": Inventory.SLOT_RING,
			"name": "Resonant Primer",
			"rule": "A fixture rule.",
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
		return []


class PairPlayerFixture:
	extends Node
	var hp: float = 100.0
	var max_hp: float = 100.0
	var armor: float = 0.0
	var speed: float = 100.0
	var power: float = 0.0
	var haste: float = 0.0
	var luck: float = 0.0
	var stats: Variant = null
	var last_burden: BurdenSnapshot = null

var _passes: int = 0
var _failures: int = 0

@onready var _objective_controller: Node = $ObjectiveController
@onready var _gate_controller: Node = $GateChecklistController
@onready var _pair_notifier: Control = $ManifestationPairNotifier
@onready var _run_sheet: RunSheetHUD = $RunSheetHUD
@onready var _overlay: Control = $GateOverlay
@onready var _objective_panel: PanelContainer = $GateOverlay/ContextStack/ObjectivePanel
@onready var _objective_title: Label = $GateOverlay/ContextStack/ObjectivePanel/Margin/VBox/Title
@onready var _objective_detail: Label = $GateOverlay/ContextStack/ObjectivePanel/Margin/VBox/Detail
@onready var _secondary_panel: PanelContainer = $GateOverlay/ContextStack/SecondaryObjectivePanel
@onready var _secondary_detail: Label = $GateOverlay/ContextStack/SecondaryObjectivePanel/Margin/VBox/Detail
@onready var _gate_panel: PanelContainer = $GateOverlay/ContextStack/GateChecklistPanel
@onready var _gate_header: Label = $GateOverlay/ContextStack/GateChecklistPanel/Margin/VBox/Header
@onready var _gate_rows: VBoxContainer = $GateOverlay/ContextStack/GateChecklistPanel/Margin/VBox/Rows
@onready var _gate_hint: Label = $GateOverlay/ContextStack/GateChecklistPanel/Margin/VBox/Hint
@onready var _rite_title: Label = $GateOverlay/GateReadyOverlay/Center/Panel/Margin/VBox/Title


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _verify_exit_rite_ownership()

	var checklist_items: Array = [
		{"id": &"primary", "label": "Primary objective", "done": true},
		{"id": &"resonance", "label": "Reach 80% resonance", "done": false},
	]
	_objective_controller.call(
		"_on_objective_changed",
		"STABILISE THE DISTRICT RELAY",
		"Align the three resonators without breaking the circuit."
	)
	_gate_controller.call(
		"_on_gate_checklist_changed",
		&"locked",
		checklist_items,
		"Increase resonance to expose the Rite."
	)
	await get_tree().process_frame

	_check(_objective_panel.visible, "the primary objective appears")
	_check(_objective_detail.visible, "a changed objective briefly shows its detail")
	_check(_gate_panel.visible, "Exit Rite status appears when requirements exist")
	_check(_gate_rows.visible, "changed Exit Rite requirements briefly show the checklist")
	await _capture_if_requested("hud_context_expanded.png")

	# Procedural builders can refresh unchanged HUD data several times per
	# second. Identical refreshes must not restart the presentation timer.
	for _repeat in range(8):
		await get_tree().create_timer(0.45).timeout
		_objective_controller.call(
			"_on_objective_changed",
			"STABILISE THE DISTRICT RELAY",
			"Align the three resonators without breaking the circuit."
		)
		_gate_controller.call(
			"_on_gate_checklist_changed",
			&"locked",
			checklist_items,
			"Increase resonance to expose the Rite."
		)
	_check(_objective_panel.visible, "the primary objective persists after settling")
	_check(not _objective_detail.visible, "the settled primary objective collapses to one line")
	_check(_gate_panel.visible, "the compact Exit Rite status persists")
	_check(not _gate_rows.visible, "the settled Exit Rite checklist collapses")
	_check(not _gate_hint.visible, "the settled Exit Rite hint collapses with its rows")
	_check("1/2" in _gate_header.text, "the compact Exit Rite status preserves progress")
	_check("H" in _gate_header.text, "the compact Exit Rite status exposes its inspect control")

	_objective_controller.call(
		"_on_secondary_objective_changed",
		"SECONDARY: UNSTABLE SHRINE",
		"Remain nearby while the vessel stabilises."
	)
	await get_tree().process_frame
	_check(_secondary_panel.visible, "a nearby secondary objective appears")
	_check(_secondary_detail.visible, "a newly nearby secondary briefly shows its detail")
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	_check(_secondary_panel.visible, "the nearby secondary remains discoverable")
	_check(not _secondary_detail.visible, "the settled secondary objective becomes marginal")
	await _capture_if_requested("hud_context_settled.png")
	_objective_controller.call("_on_secondary_objective_changed", "", "")
	_check(not _secondary_panel.visible, "a secondary objective disappears when no longer nearby")

	_check(
		_gate_controller.has_method("set_details_requested"),
		"Exit Rite details expose a hold-to-inspect entry point"
	)
	if _gate_controller.has_method("set_details_requested"):
		_gate_controller.call("set_details_requested", true)
		_check(_gate_rows.visible and _gate_hint.visible, "holding details expands the full Exit Rite")
		_gate_controller.call("set_details_requested", false)
		_check(not _gate_rows.visible and not _gate_hint.visible, "releasing details restores compact status")

	_objective_controller.call("_on_management_mode_changed", true)
	_gate_controller.call("_on_management_mode_changed", true)
	_check(not _objective_panel.visible and not _gate_panel.visible, "management mode clears combat context")

	_check(_overlay.theme != null, "the HUD overlay carries its readable body typography")
	if _overlay.theme != null:
		_check(
			"IBMPlexSansCondensed" in _overlay.theme.default_font.resource_path,
			"IBM Plex Sans Condensed is the HUD body face"
		)
	_check(
		_objective_title.theme_type_variation == &"InstitutionalHeading",
		"ordinary objectives use the institutional Alegreya register"
	)
	_check(
		_gate_header.theme_type_variation == &"SacredHeading"
		and _rite_title.theme_type_variation == &"SacredHeading",
		"Exit Rite language uses the Marcellus sacred register"
	)
	_check(InputMap.has_action(&"hud_details"), "the player has a hold-to-inspect HUD action")
	_check(
		&"hud_details" in InputActionCatalog.action_names()
		and InputActionCatalog.default_bindings().has(&"hud_details"),
		"HUD inspect participates in remappable control settings"
	)
	var saved_detail_events := InputMap.action_get_events(&"hud_details")
	var remapped_key := InputEventKey.new()
	remapped_key.physical_keycode = KEY_J
	InputMap.action_erase_events(&"hud_details")
	InputMap.action_add_event(&"hud_details", remapped_key)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("J" in _gate_header.text, "the inspect prompt follows the remapped action")
	InputMap.action_erase_events(&"hud_details")
	for saved_event in saved_detail_events:
		InputMap.action_add_event(&"hud_details", saved_event)

	_pair_notifier.call("debug_force_notification", {
		"name": "Litany Engine",
		"nouns": [&"machine", &"faith"],
		"rule": "This deliberately long mechanical rule belongs in the Run Sheet.",
	})
	await get_tree().process_frame
	var pair_box := _pair_notifier.get_node("ManifestationPairPanel").get_child(0).get_child(0) as VBoxContainer
	var pair_name := pair_box.get_child(1) as Label
	var pair_detail := pair_box.get_child(2) as Label
	_check(pair_name.theme_type_variation == &"SacredHeading", "pair names use the sacred register")
	_check(
		not "deliberately long mechanical rule" in pair_detail.text
		and "Run Sheet" in pair_detail.text,
		"pair notifications stay brief and send full rules to the Run Sheet"
	)

	var pair_player := PairPlayerFixture.new()
	var pair_runner := PairRunnerFixture.new()
	pair_runner.name = "ManifestationRunner"
	pair_player.add_child(pair_runner)
	add_child(pair_player)
	_run_sheet.visible = true
	var saved_discoveries: Array[StringName] = Global.discovered_enemy_ids.duplicate()
	if not Global.discovered_enemy_ids.has(&"enemy_grunt"):
		Global.discovered_enemy_ids.append(&"enemy_grunt")
	_run_sheet.refresh(pair_player, Inventory.new())
	_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
	var manifestation_text := _collect_label_text(_run_sheet)
	_check(
		"Litany Engine" in manifestation_text
		and "Every third invocation seals the nearest wound." in manifestation_text,
		"the Run Sheet exposes each active pair and its full protocol"
	)
	_run_sheet.select_page(RunSheetHUD.ArchivePage.OBSERVATIONS)
	var observation_text := _collect_label_text(_run_sheet)
	_check(
		"OBSERVATIONS" in observation_text and "CONTAINMENT OFFICER" in observation_text,
		"the Run Sheet archives discovered enemy archetypes"
	)
	_check(
		"Keep moving and use doors or cover to split the group." in observation_text,
		"archived observations expose their counter without requiring a pointer"
	)
	_check(
		_contains_tooltip_text(_run_sheet, "BEHAVIOUR") and _contains_tooltip_text(_run_sheet, "COUNTER"),
		"archived observations retain the full tactical dossier"
	)
	await _capture_if_requested("hud_context_run_sheet.png")
	Global.discovered_enemy_ids.assign(saved_discoveries)
	pair_player.queue_free()

	var export_config := ConfigFile.new()
	var export_error := export_config.load("res://export_presets.cfg")
	var include_filter := String(export_config.get_value("preset.0", "include_filter", ""))
	_check(
		export_error == OK and "assets/fonts/*/*.txt" in include_filter,
		"exported builds carry the font license notices"
	)

	print("HudContextPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _verify_exit_rite_ownership() -> void:
	var objective_events: Array[Array] = []
	var checklist_events: Array[Array] = []
	var objective_cb := func(title: String, detail: String) -> void:
		objective_events.append([title, detail])
	var checklist_cb := func(state: StringName, items: Array, hint: String) -> void:
		checklist_events.append([state, items, hint])
	RunEvents.objective_changed.connect(objective_cb)
	RunEvents.gate_checklist_changed.connect(checklist_cb)

	var builder_script := load("res://core/systems/world/SegmentProcBuilder.gd") as Script
	var builder: Node = builder_script.new()
	add_child(builder)
	builder.set("_primary_completed", true)
	builder.set("resonance", 1.0)
	builder.set("_miniboss_required", false)
	builder.set("_boss_required", false)
	builder.call("_push_objective_ui")
	await get_tree().process_frame

	_check(not objective_events.is_empty(), "post-primary state updates the ordinary objective channel")
	if not objective_events.is_empty():
		_check(
			String(objective_events[-1][0]).is_empty() and String(objective_events[-1][1]).is_empty(),
			"the Exit Rite clears ordinary objective copy instead of duplicating it"
		)
	_check(
		not checklist_events.is_empty() and StringName(checklist_events[-1][0]) == &"ready",
		"the Exit Rite checklist solely owns ready-state guidance"
	)

	RunEvents.objective_changed.disconnect(objective_cb)
	RunEvents.gate_checklist_changed.disconnect(checklist_cb)
	if is_instance_valid(builder):
		builder.queue_free()
	await get_tree().process_frame


func _capture_if_requested(file_name: String) -> void:
	var shot_dir := OS.get_environment("HUD_CONTEXT_SHOT_DIR")
	if shot_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await get_tree().process_frame
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	var path := "%s/%s" % [shot_dir, file_name]
	print("HUD context shot -> %s (err=%d)" % [path, image.save_png(path)])


func _collect_label_text(node: Node) -> String:
	var parts := PackedStringArray()
	var label := node as Label
	if label != null:
		parts.append(label.text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _contains_tooltip_text(node: Node, needle: String) -> bool:
	var control := node as Control
	if control != null and needle in control.tooltip_text:
		return true
	for child in node.get_children():
		if _contains_tooltip_text(child, needle):
			return true
	return false
