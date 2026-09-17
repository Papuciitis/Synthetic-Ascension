extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var theme := load("res://ui/theme/SyntheticHudTheme.tres") as Theme
	_check(theme != null, "shared interface theme loads")
	if theme == null:
		_finish()
		return
	var institutional_panel := theme.get_stylebox(&"panel", &"InstitutionalPanel") as StyleBoxFlat
	var archive_card := theme.get_stylebox(&"panel", &"ArchiveCard") as StyleBoxFlat
	var institutional_button := theme.get_stylebox(&"normal", &"InstitutionalButton") as StyleBoxFlat
	var ledger_panel := theme.get_stylebox(&"panel", &"LedgerPanel") as StyleBoxFlat
	var ritual_panel := theme.get_stylebox(&"panel", &"RitualPanel") as StyleBoxFlat
	var witness_notice := theme.get_stylebox(&"panel", &"WitnessNotice") as StyleBoxFlat
	var side_index_normal := theme.get_stylebox(&"normal", &"SideIndexButton") as StyleBoxFlat
	var side_index_pressed := theme.get_stylebox(&"pressed", &"SideIndexButton") as StyleBoxFlat
	_check(theme.has_stylebox(&"panel", &"InstitutionalPanel") and _is_angular(institutional_panel), "institutional panels use restrained angular corners")
	_check(theme.has_stylebox(&"panel", &"ArchiveCard") and _is_angular(archive_card), "archive cards use restrained angular corners")
	_check(theme.has_stylebox(&"normal", &"InstitutionalButton") and _is_angular(institutional_button), "institutional buttons use restrained angular corners")
	_check(
		theme.has_stylebox(&"panel", &"LedgerPanel")
		and _is_angular(ledger_panel)
		and ledger_panel.border_width_top >= 1,
		"ledger surfaces use an open bronze rule"
	)
	_check(
		theme.has_stylebox(&"panel", &"RitualPanel")
		and _is_angular(ritual_panel)
		and ritual_panel.border_width_left >= 2,
		"the rite is the stronger contained surface"
	)
	_check(
		theme.has_stylebox(&"panel", &"WitnessNotice") and _is_angular(witness_notice),
		"witness notices use the angular shared surface"
	)
	_check(
		theme.has_stylebox(&"normal", &"SideIndexButton")
		and theme.has_stylebox(&"pressed", &"SideIndexButton")
		and _is_angular(side_index_normal)
		and side_index_pressed != null
		and side_index_pressed.border_width_left > side_index_normal.border_width_left,
		"side-index selection adds a structural marker"
	)
	_check(
		theme.has_stylebox(&"normal", &"InstitutionalLineEdit"),
		"Exchange search uses the institutional input"
	)
	_check(
		theme.has_stylebox(&"normal", &"InstitutionalCheckBox"),
		"Exchange toggles use the institutional checkbox"
	)

	var main_menu := _instantiate("res://ui/screens/MainMenu.tscn") as Control
	_check(main_menu != null and main_menu.theme == theme, "Main Menu inherits the shared interface theme")
	if main_menu != null:
		_check(
			(main_menu.get_node("Center/Panel/Padding/VBox/Title") as Label).theme_type_variation == &"InstitutionalHeading",
			"Main Menu heading uses the institutional register"
		)
		_check(
			(main_menu.get_node("Center/Panel/Padding/VBox/Continue") as Button).theme_type_variation == &"InstitutionalButton",
			"Main Menu actions use the shared button construction"
		)

	var save_select := _instantiate("res://ui/screens/SaveSelect.tscn") as Control
	_check(save_select != null and save_select.theme == theme, "Save Select inherits the shared interface theme")
	if save_select != null:
		_check(
			(save_select.get_node("Margin/Main/Title") as Label).theme_type_variation == &"InstitutionalHeading",
			"Save Select heading uses the institutional register"
		)

	var save_card := _instantiate("res://ui/components/SaveCard.tscn") as Control
	if save_card != null:
		_check(save_card.theme == theme, "Save Cards inherit the shared interface theme")
		_check(
			(save_card.get_node("CardPanel") as Panel).theme_type_variation == &"ArchiveCard",
			"Save Cards use the archive-card construction"
		)

	var hud := _instantiate("res://ui/screens/HUD.tscn") as Control
	if hud != null:
		var manage_overlay := hud.get_node("ManageOverlay") as ColorRect
		var top_left := hud.get_node("TopLeft") as PanelContainer
		_check(manage_overlay.color.a >= 0.32, "management mode strongly separates the analysis layer from combat")
		_check(_is_angular(top_left.get_theme_stylebox(&"panel") as StyleBoxFlat), "Top Left telemetry uses angular construction")
	await _verify_management_layering()

	var bag := _instantiate("res://ui/components/BagUI.tscn") as PanelContainer
	var run_sheet := _instantiate("res://ui/widgets/RunSheetHUD.tscn") as PanelContainer
	_check(bag != null and _is_angular(bag.get_theme_stylebox(&"panel") as StyleBoxFlat), "Bag uses the angular management surface")
	_check(run_sheet != null and _is_angular(run_sheet.get_theme_stylebox(&"panel") as StyleBoxFlat), "Run Sheet uses the angular management surface")

	var modal_scene := load("res://ui/screens/TutorialCardOverlay.tscn") as PackedScene
	var modal := modal_scene.instantiate()
	root.add_child(modal)
	await process_frame
	var panels := modal.find_children("*", "PanelContainer", true, false)
	var modal_panel: PanelContainer = panels[0] as PanelContainer if not panels.is_empty() else null
	_check(modal_panel != null and _is_angular(modal_panel.get_theme_stylebox(&"panel") as StyleBoxFlat), "blocking records share the angular institutional surface")
	modal.queue_free()

	for node in [main_menu, save_select, save_card, hud, bag, run_sheet]:
		if node != null:
			node.free()
	await process_frame
	_finish()


func _instantiate(path: String) -> Node:
	var scene := load(path) as PackedScene
	return scene.instantiate() if scene != null else null


func _verify_management_layering() -> void:
	var host := Control.new()
	var overlay := ColorRect.new()
	overlay.name = "ManageOverlay"
	var top_left := PanelContainer.new()
	top_left.name = "TopLeft"
	var run_sheet := PanelContainer.new()
	run_sheet.name = "RunSheetHUD"
	var bag := Control.new()
	bag.name = "BagUI"
	host.add_child(overlay)
	host.add_child(top_left)
	host.add_child(run_sheet)
	host.add_child(bag)
	var controller_script := load("res://ui/controllers/HudBagController.gd") as Script
	var controller: Node = controller_script.new()
	controller.name = "BagController"
	controller.set("top_left_path", NodePath("../TopLeft"))
	controller.set("run_sheet_path", NodePath("../RunSheetHUD"))
	controller.set("manage_overlay_path", NodePath("../ManageOverlay"))
	host.add_child(controller)
	root.add_child(host)
	await process_frame

	controller.call("_on_bag_open_changed", true)
	_check(
		overlay.visible and overlay.z_index < top_left.z_index and overlay.z_index < run_sheet.z_index and overlay.z_index < bag.z_index,
		"open management surfaces render above the world-dimming layer"
	)
	controller.call("_on_bag_open_changed", false)
	_check(
		not overlay.visible and top_left.z_index == 0 and run_sheet.z_index == 0 and bag.z_index == 0,
		"closing management mode restores ordinary HUD layering"
	)
	host.queue_free()
	await process_frame


func _is_angular(style: StyleBoxFlat) -> bool:
	return (
		style != null
		and style.corner_radius_top_left <= 4
		and style.corner_radius_top_right <= 4
		and style.corner_radius_bottom_left <= 4
		and style.corner_radius_bottom_right <= 4
	)


func _finish() -> void:
	print("InterfaceThemeConsistencyTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
