extends Node

# Run Sheet audit 2026-08-28 §4 #3: the augment tooltip's stat block must show
# the level its header names - read back from apply_to_stats_at_level, the
# call the stat pass makes - and print Luck as the percentage every other
# surface uses, not "+1 Luck" for a +0.5 charm. Exercises the real widget.
#
# Run: <godot> --headless --path . res://tools/tests/AugmentTooltipTest.tscn

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


func _fixture() -> AugmentData:
	var a := AugmentData.new()
	a.id = &"test_scaled_charm"
	a.display_name = "Scaled Charm"
	a.mods = StatDelta.new()
	a.mods.max_hp = 10.0
	a.mods.power = 0.05
	a.mods.luck = 0.5
	a.mods_scale_per_level = 0.2
	return a


## Drives the real pick handler (no card node, so no fly VFX to await) and
## reports the level the stat pass will apply afterwards.
func _picked_level(select: CanvasLayer, a: AugmentData) -> int:
	await select.call("_on_card_picked", a, null)
	return Global.get_augment_level(a.id)


func _run() -> void:
	var scene := load("res://ui/widgets/AugmentTooltip.tscn") as PackedScene
	var tooltip := scene.instantiate() as AugmentTooltip if scene != null else null
	if tooltip == null:
		_check(false, "the augment tooltip scene loads as an AugmentTooltip")
		get_tree().quit(1)
		return
	add_child(tooltip)
	var a := _fixture()

	tooltip.show_augment(a, 1)
	var body: String = tooltip.body_label.text
	_check(body.contains("Stats at Lv.1:"), "the stat block names its level (%s)" % body)
	_check(body.contains("+10 Max HP") and body.contains("+5% Power"), "Lv.1 is the base delta")
	_check(body.contains("+50% Luck"), "Luck is a percentage, as on every other surface")
	_check(not body.contains("+1 Luck"), "the integer Luck format that read +0.5 as +1 is gone")

	tooltip.show_augment(a, 3)
	body = tooltip.body_label.text
	_check(tooltip.name_label.text.ends_with("Lv.3"), "the header says Lv.3")
	_check(body.contains("Stats at Lv.3:"), "and so does the stat block")
	_check(body.contains("+14 Max HP"), "Lv.3 scales by 1 + 0.2 x 2 = 1.4: +14 Max HP (%s)" % body)
	_check(body.contains("+7% Power"), "+7% Power")
	_check(body.contains("+70% Luck"), "+70% Luck")
	_check(not body.contains("+10 Max HP") and not body.contains("+50% Luck"), "the unscaled numbers are gone")

	# An augment with no per-level scale reads the same at every level.
	var flat := _fixture()
	flat.mods_scale_per_level = 0.0
	tooltip.show_augment(flat, 3)
	body = tooltip.body_label.text
	_check(body.contains("+10 Max HP") and body.contains("+50% Luck"), "no scale, no change at Lv.3 (%s)" % body)

	tooltip.queue_free()

	# The augment-choice screen's hover panel is an augment tooltip too, and
	# it read the base `mods` and printed Luck as an integer (readability
	# wave 1's deliberate leftover). It shows the level the stat pass will
	# apply after the pick - Global.get_augment_level, which slotting does not
	# touch: Lv.1 for an augment never levelled, the stored level for an owned
	# but unslotted one (the pick only slots it), the next level for a slotted
	# one (the pick levels it up in place). Each case is checked against the
	# level the real pick handler leaves behind.
	var select_scene := load("res://ui/augments/AugmentSelect.tscn") as PackedScene
	var select: CanvasLayer = select_scene.instantiate() as CanvasLayer if select_scene != null else null
	if select == null:
		_check(false, "the augment select scene loads")
	else:
		add_child(select)
		var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
		var saved_owned: Array[StringName] = Global.owned_augment_ids.duplicate()
		var saved_levels: Dictionary = Global.attempt_augment_levels.duplicate()

		# Never owned: no slot, no library entry, no stored level.
		Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
		Global.owned_augment_ids = []
		Global.attempt_augment_levels.erase(String(a.id))
		var text: String = str(select.call("_build_numbers_text", a))
		_check(text.contains("Stats at Lv.1:"), "AugmentSelect: a new augment shows the Lv.1 the pick gives (%s)" % text)
		_check(text.contains("+10 Max HP") and text.contains("+5% Power"), "AugmentSelect: Lv.1 is the base delta")
		_check(text.contains("+50% Luck") and not text.contains("+1 Luck"), "AugmentSelect: Luck is a percentage, not +1")
		var picked: int = await _picked_level(select, a)
		_check(picked == 1, "AugmentSelect: and the pick leaves a new augment at Lv.1 (got %d)" % picked)

		# Owned but unslotted at Lv.2: the pick slots it and keeps its level.
		Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
		Global.owned_augment_ids = [a.id]
		Global.attempt_augment_levels[String(a.id)] = 2
		text = str(select.call("_build_numbers_text", a))
		_check(text.contains("Stats at Lv.2:"), "AugmentSelect: an owned, unslotted Lv.2 augment shows the Lv.2 the pick keeps (%s)" % text)
		_check(text.contains("+12 Max HP") and text.contains("+6% Power") and text.contains("+60% Luck"), "AugmentSelect: scaled to Lv.2 - neither the base delta nor the next level")
		picked = await _picked_level(select, a)
		_check(picked == 2, "AugmentSelect: and the pick leaves an unslotted augment at its stored level (got %d)" % picked)

		# Slotted at Lv.2: the pick levels it up in place.
		Global.permanent_augment_ids = [a.id, StringName(), StringName()]
		Global.attempt_augment_levels[String(a.id)] = 2
		text = str(select.call("_build_numbers_text", a))
		_check(text.contains("Stats at Lv.3:"), "AugmentSelect: a slotted Lv.2 augment shows the Lv.3 the pick gives (%s)" % text)
		_check(text.contains("+14 Max HP") and text.contains("+7% Power") and text.contains("+70% Luck"), "AugmentSelect: scaled through apply_to_stats_at_level")
		_check(not text.contains("+10 Max HP") and not text.contains("+50% Luck"), "AugmentSelect: the unscaled numbers are gone")
		picked = await _picked_level(select, a)
		_check(picked == 3, "AugmentSelect: and the pick levels a slotted augment up in place (got %d)" % picked)

		Global.permanent_augment_ids = saved_augments
		Global.owned_augment_ids = saved_owned
		Global.attempt_augment_levels = saved_levels
		select.queue_free()

	print("AugmentTooltipTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
