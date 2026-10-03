extends Node

# The Doctrine plate is a fixed 340 x 540 face and the Binding card a fixed
# 250 x 380 one; the eighteen plates' gift, price, consequence and family
# lines and every Binding badge must fit them (bindings-and-theses §6 grew
# several of them). Layout is measured headless - text shaping needs fonts,
# not a GPU - so this guards the copy where no screenshot can.
#
# Run: <godot> --headless --path . res://tools/tests/ChoiceCopyFitTest.tscn

const PLATE_SCENE := preload("res://ui/screens/MajorChoiceCard.tscn")
const CARD_SCENE := preload("res://ui/augments/AugmentCard.tscn")

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
	Global.start_new_attempt()
	await _plates()
	await _cards()
	print("ChoiceCopyFitTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _plates() -> void:
	var worst := 0.0
	var worst_id := ""
	for definition in Global.major_choice_db.defs:
		if definition == null or not definition.is_doctrine_complete():
			continue
		for held in [0, 1, 2]:
			Global.attempt_doctrine_stage_ids = {}
			for i in range(held):
				Global.attempt_doctrine_stage_ids["x%d" % i] = _same_family(definition.family_id, i)
			var plate := PLATE_SCENE.instantiate() as MajorChoiceCard
			add_child(plate)
			plate.set_def(definition, PackedStringArray(), 1)
			await get_tree().process_frame
			await get_tree().process_frame
			var face := plate.get_node("FaceViewport/Face") as Control
			var vbox := plate.get_node("FaceViewport/Face/Margin/VBox") as Control
			var margin := plate.get_node("FaceViewport/Face/Margin") as MarginContainer
			var room := face.size.y - float(margin.get_theme_constant("margin_top")) - float(margin.get_theme_constant("margin_bottom"))
			var need := vbox.get_combined_minimum_size().y
			if need / room > worst:
				worst = need / room
				worst_id = "%s (family %d held)" % [definition.id, held]
			_check(need <= room + 0.5, "%s fits its plate with %d of its family held (%.0f of %.0f px)" % [definition.title, held, need, room])
			plate.queue_free()
	Global.attempt_doctrine_stage_ids = {}
	print("tallest plate: %s at %.0f%% of the face" % [worst_id, worst * 100.0])


func _same_family(family: StringName, index: int) -> String:
	var found := 0
	for definition in Global.major_choice_db.defs:
		if definition != null and definition.is_doctrine_complete() and definition.family_id == family:
			if found == index:
				return String(definition.id)
			found += 1
	return ""


func _cards() -> void:
	var badge_room := 222.0
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	for id in Global.augment_db.keys():
		var data := Global.augment_db[id] as AugmentData
		for entry in [
			{"kind": "new", "id": String(id), "grade": 3},
			{"kind": "rank", "id": String(id), "grade": 2},
			{"kind": "swap", "id": String(id), "grade": 3},
			{"kind": "transcend", "id": String(id), "grade": -1},
		]:
			Global.attempt_augment_levels = {String(id): 17}
			var card := CARD_SCENE.instantiate()
			add_child(card)
			card.call("set_offer", data, entry)
			await get_tree().process_frame
			var badge := card.get_node("FaceViewport/Face/Badge") as Label
			var name_label := card.get_node("FaceViewport/Face/Name") as Label
			var width := badge.get_theme_font("font").get_string_size(badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge.get_theme_font_size("font_size")).x
			_check(width <= badge_room, "%s %s badge fits one line (%.0f of %.0f px: %s)" % [data.display_name, entry["kind"], width, badge_room, badge.text])
			_check(name_label.get_line_count() <= 2, "%s %s name fits two lines (%s)" % [data.display_name, entry["kind"], name_label.text])
			card.queue_free()
	Global.attempt_augment_levels = {}
