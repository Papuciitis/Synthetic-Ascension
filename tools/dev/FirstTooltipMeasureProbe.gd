extends Node

## Measures the very first show of each tooltip surface, frame by frame, the
## way a player meets them: a fresh instance that has never been laid out,
## shown with a long body, sized as its host reads it on the hover frame and
## on the frames after. A screen-tall reading on any frame is the first-hover
## bug (an autowrapped body measured before it had a width).
## Run: <godot> --headless --path . res://tools/dev/FirstTooltipMeasureProbe.tscn

const SCREEN_H := 1080.0

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _item_tooltip("item tooltip (HUD / Exchange)", false)
	await _item_tooltip("item dossier (Gear & Stash)", true)
	await _augment_tooltip()
	await _builtin_tooltip()
	print("FirstTooltipMeasureProbe: %s" % ("clean" if _failures == 0 else "%d screen-tall readings" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, frame: String, tip_size: Vector2) -> void:
	var tall := tip_size.y > SCREEN_H * 0.9
	if tall:
		_failures += 1
	print("%-34s %-10s %s%s" % [label, frame, tip_size, "   <-- SCREEN-TALL" if tall else ""])


func _wordy_item() -> ItemInstance:
	var data := ItemData.new()
	data.id = "probe_wordy"
	data.display_name = "Probe Wordy Item"
	data.equip_slot = 1 as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var desc := ""
	for i in range(8):
		desc += "Sentence number %d of a description long enough to wrap many times. " % i
	data.description = desc
	return ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25, false)


func _item_tooltip(label: String, dossier: bool) -> void:
	var host := CanvasLayer.new()
	host.layer = 50
	add_child(host)
	var tip := (load("res://ui/widgets/ItemTooltip.tscn") as PackedScene).instantiate() as ItemTooltip
	tip.visible = false
	host.add_child(tip)
	if dossier:
		tip.set_dossier_mode(true)
	tip.show_item(_wordy_item())
	# What a host reads on the hover frame: the HUD's place_beside.
	tip.place_beside(Rect2(Vector2(400, 300), Vector2(64, 64)), Rect2(Vector2.ZERO, Vector2(1920, SCREEN_H)))
	_report(label, "hover", tip.size)
	for f in range(3):
		await get_tree().process_frame
		_report(label, "frame %d" % (f + 1), tip.size)
	host.queue_free()
	await get_tree().process_frame


func _augment_tooltip() -> void:
	var label := "augment tooltip (HUD)"
	var host := CanvasLayer.new()
	add_child(host)
	var tip := (load("res://ui/widgets/AugmentTooltip.tscn") as PackedScene).instantiate() as Control
	tip.visible = false
	host.add_child(tip)
	var aug := AugmentData.new()
	aug.id = &"probe_aug"
	aug.display_name = "Probe Augment"
	var desc := ""
	for i in range(8):
		desc += "Sentence number %d of an augment description long enough to wrap. " % i
	aug.description = desc
	tip.call("show_augment", aug, 2)
	_report(label, "hover", tip.size)
	for f in range(3):
		await get_tree().process_frame
		_report(label, "frame %d (vis=%s)" % [f + 1, tip.visible], tip.size)
	host.queue_free()
	await get_tree().process_frame


## Godot's own tooltip under the project theme: the popup it builds is a
## TooltipPanel around a TooltipLabel. Rebuild the same pair and measure it.
func _builtin_tooltip() -> void:
	var label := "built-in tooltip (theme)"
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	var text := Label.new()
	text.theme_type_variation = &"TooltipLabel"
	text.text = "Health equipment slot"
	panel.add_child(text)
	add_child(panel)
	panel.reset_size()
	_report(label, "hover", panel.get_combined_minimum_size())
	await get_tree().process_frame
	_report(label, "frame 1", panel.size)
	panel.queue_free()
	await get_tree().process_frame
