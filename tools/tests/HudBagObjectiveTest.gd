extends Node
## The real HUD: opening the backpack hides the objective stack, whichever
## happens first, and an objective change while the bag is open stays hidden
## until the bag closes. Drives the actual signals, not the handlers.

const HUD := preload("res://ui/screens/HUD.tscn")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	Global.debug_disable_autosave = true
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hud := HUD.instantiate()
	layer.add_child(hud)
	for _i in 3: await get_tree().process_frame
	var bag_controller := hud.get_node_or_null("BagController") as HudBagController
	var objective := hud.get_node_or_null("ObjectiveController")
	var panel := hud.get_node_or_null("GateOverlay/ContextStack/ObjectivePanel") as Control
	_check(bag_controller != null and objective != null and panel != null, "the HUD has its bag controller, objective controller and objective panel")
	if bag_controller == null or objective == null or panel == null:
		_finish()
		return
	_check(objective.get("_bag_controller") == bag_controller, "the objective controller resolves the real bag controller")
	var bag := bag_controller.get_bag_ui()
	print("bag ui: ", bag, " stack z: ", (hud.get_node("GateOverlay") as CanvasItem).z_index)
	RunEvents.objective_changed.emit("Hold the Ward Vigil • COLLAPSE", "")
	await get_tree().process_frame
	_check(panel.visible, "an objective shows while the bag is closed")
	if bag != null:
		bag.call("toggle_open")
		await get_tree().process_frame
		_check(bag_controller.is_management_mode(), "toggling the bag opens management mode")
		_check(not panel.visible, "opening the bag hides the objective panel")
		var stack := hud.get_node("GateOverlay/ContextStack") as CanvasItem
		# Even a panel some other path forces visible stays off screen.
		panel.visible = true
		_check(not stack.visible and not panel.is_visible_in_tree(), "the whole objective stack is hidden while the bag is open")
		panel.visible = false
		RunEvents.objective_changed.emit("Hold the Ward Vigil • SURGE", "")
		await get_tree().process_frame
		_check(not panel.visible, "an objective change while the bag is open stays hidden")
		bag.call("toggle_open")
		await get_tree().process_frame
		_check(panel.is_visible_in_tree(), "closing the bag restores the objective on screen")
	else:
		_check(false, "the bag controller created its bag UI")
	_finish()


func _finish() -> void:
	print("HudBagObjectiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
