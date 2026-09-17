extends Node

const SCREEN_SCENE := preload("res://ui/screens/MajorChoice.tscn")

var _passes := 0
var _failures := 0
var _saved: Dictionary = {}


func _ready() -> void:
	_saved = {
		"pending": Global.pending_big_choice,
		"stage": Global.attempt_pending_doctrine_stage,
		"offer": Global.attempt_major_choice_offer_ids.duplicate(),
		"taken": Global.attempt_major_choice_taken_ids.duplicate(),
		"stages": Global.attempt_doctrine_stage_ids.duplicate(true),
		"rules": Global.attempt_doctrine_rules.duplicate(true),
		"delta": Global.attempt_stat_delta,
	}
	Global.pending_big_choice = true
	Global.attempt_pending_doctrine_stage = &"method"
	Global.attempt_major_choice_offer_ids = [
		"doctrine_method_open_circuit",
		"doctrine_method_frame_of_ash",
		"doctrine_method_black_archive",
	]
	Global.attempt_major_choice_taken_ids = []
	Global.attempt_doctrine_stage_ids = {}
	Global.attempt_doctrine_rules = {}
	Global.attempt_stat_delta = null

	var screen := SCREEN_SCENE.instantiate()
	add_child(screen)
	screen.open()
	await get_tree().process_frame

	var title := screen.get_node_or_null("Center/Window/Margin/VBox/Title") as Label
	var stage := screen.get_node_or_null("Center/Window/Margin/VBox/Stage") as Label
	var cards := screen.get_node("Center/Window/Margin/VBox/Cards") as HBoxContainer
	var confirm := screen.get_node_or_null("Center/Window/Margin/VBox/Actions/Confirm") as Button
	_check(title != null and title.text == "ASCENSION DOCTRINE", "screen carries the Ascension Doctrine title")
	_check(stage != null and "METHOD" in stage.text, "screen identifies the current Doctrine stage")
	_check(cards.get_child_count() == 3, "screen presents exactly three thesis plates")
	_check(confirm != null and confirm.disabled, "inscription begins disabled until a plate is focused")

	for card_node in cards.get_children():
		var card := card_node as MajorChoiceCard
		_check(card != null and card.corner_radius <= 2, "thesis plate uses square institutional geometry")
		_check(card_node.find_child("GiftText", true, false) != null, "plate exposes Gift copy")
		_check(card_node.find_child("PriceText", true, false) != null, "plate exposes Price copy")
		_check(card_node.find_child("ConsequenceText", true, false) != null, "plate exposes Consequence copy")

	var first := cards.get_child(0) as MajorChoiceCard
	var chosen_id := first.choice_id
	first.pressed.emit()
	_check(not Global.attempt_major_choice_taken_ids.has(chosen_id), "first press focuses without applying")
	_check(confirm != null and not confirm.disabled, "focused plate enables inscription")
	if confirm != null:
		confirm.pressed.emit()
	_check(Global.attempt_major_choice_taken_ids.has(chosen_id), "explicit inscription applies the Doctrine")
	var taken_count := Global.attempt_major_choice_taken_ids.size()
	if confirm != null:
		confirm.pressed.emit()
	_check(Global.attempt_major_choice_taken_ids.size() == taken_count, "confirmation cannot apply a Doctrine twice")

	screen.queue_free()
	_restore()
	print("AscensionDoctrinePresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _restore() -> void:
	Global.pending_big_choice = bool(_saved.pending)
	Global.attempt_pending_doctrine_stage = _saved.stage
	Global.attempt_major_choice_offer_ids = _saved.offer
	Global.attempt_major_choice_taken_ids = _saved.taken
	Global.attempt_doctrine_stage_ids = _saved.stages
	Global.attempt_doctrine_rules = _saved.rules
	Global.attempt_stat_delta = _saved.delta


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
