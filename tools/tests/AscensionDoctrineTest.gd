extends Node

const CONTEXT_PATH := "res://core/systems/major_choice/MajorChoiceContext.gd"

var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	var context_script := load(CONTEXT_PATH) as Script
	_check(context_script != null, "MajorChoiceContext exists")
	_check(Global.has_method("doctrine_stage_for_completed_segment"), "Global schedules Doctrine stages")
	if context_script == null or not Global.has_method("doctrine_stage_for_completed_segment"):
		_finish()
		return
	_check(Global.doctrine_stage_for_completed_segment(2) == &"", "Segment 2 has no Doctrine")
	_check(Global.doctrine_stage_for_completed_segment(3) == &"method", "Segment 3 grants Method")
	_check(Global.doctrine_stage_for_completed_segment(6) == &"doctrine", "Segment 6 grants Doctrine")
	_check(Global.doctrine_stage_for_completed_segment(9) == &"apotheosis", "Segment 9 grants Apotheosis")
	_test_role_offer(context_script)
	_test_authored_content()
	_test_exactly_once_application()
	_finish()


func _test_role_offer(context_script: Script) -> void:
	var context: RefCounted = context_script.new()
	context.set("stage_id", &"method")
	context.set("tags", {&"active_augment": true})
	var db := MajorChoiceDB.new()
	for role in [&"amplify", &"transfigure", &"covenant"]:
		var generic := _definition(StringName("generic_%s" % role), role, [], 1.0)
		var matched := _definition(StringName("matched_%s" % role), role, [&"active_augment"], 1.0)
		db.defs.append(generic)
		db.defs.append(matched)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var offer: Array = db.call("build_stage_offer", context, [], rng)
	_check(offer.size() == 3, "a staged offer contains three roles")
	if offer.size() == 3:
		_check(offer[0].offer_role == &"amplify", "Amplify is first")
		_check(offer[1].offer_role == &"transfigure", "Transfigure is second")
		_check(offer[2].offer_role == &"covenant", "Covenant is third")
		_check(offer[0].build_tags.has(&"active_augment"), "matching build candidate wins")


func _definition(id: StringName, role: StringName, tags: Array[StringName], score: float) -> MajorChoiceDef:
	var definition := MajorChoiceDef.new()
	definition.id = id
	definition.title = String(id)
	definition.set("enabled", true)
	definition.set("stage", &"method")
	definition.set("offer_role", role)
	definition.set("family_id", role)
	definition.set("gift_text", "Gift")
	definition.set("price_text", "Price")
	definition.set("consequence_text", "Consequence")
	definition.set("build_tags", tags)
	definition.set("base_offer_score", score)
	return definition


func _test_authored_content() -> void:
	var db := MajorChoiceDB.new()
	db.load_from_dir("res://data/major_choices/")
	var staged: Array[MajorChoiceDef] = []
	for definition in db.defs:
		if definition != null and definition.has_method("is_doctrine_complete") and definition.call("is_doctrine_complete"):
			staged.append(definition)
	_check(staged.size() == 9, "version one contains exactly nine complete Doctrines")
	var titles: Array[String] = []
	for definition in staged:
		titles.append(definition.title)
	for expected in ["Open Circuit", "Frame of Ash", "Black Archive", "Choir of Recurrence", "Vessel Without Mercy", "Pilgrim Engine", "Perfected Engine", "Law of Admission", "Manufactured Witness"]:
		_check(titles.has(expected), "authored Doctrine exists: %s" % expected)


func _test_exactly_once_application() -> void:
	_check(_has_property(Global, &"attempt_pending_doctrine_stage"), "Global stores a pending Doctrine stage")
	_check(_has_property(Global, &"attempt_doctrine_stage_ids"), "Global stores one selection per stage")
	_check(_has_property(Global, &"attempt_doctrine_rules"), "Global stores Doctrine rules")
	if not _has_property(Global, &"attempt_pending_doctrine_stage"):
		return
	var old_pending: bool = Global.pending_big_choice
	var old_source: int = Global.attempt_big_choice_source_segment
	var old_offer: Array[StringName] = Global.attempt_major_choice_offer_ids.duplicate()
	var old_taken: Array[StringName] = Global.attempt_major_choice_taken_ids.duplicate()
	var old_stage: StringName = Global.get("attempt_pending_doctrine_stage")
	var old_stage_ids: Dictionary = Global.get("attempt_doctrine_stage_ids").duplicate(true)
	Global.pending_big_choice = true
	Global.attempt_big_choice_source_segment = 3
	Global.set("attempt_pending_doctrine_stage", &"method")
	Global.attempt_major_choice_offer_ids = [&"doctrine_method_open_circuit"]
	Global.attempt_major_choice_taken_ids = []
	Global.set("attempt_doctrine_stage_ids", {})
	var first: Variant = Global.apply_major_choice(&"doctrine_method_open_circuit")
	var second: Variant = Global.apply_major_choice(&"doctrine_method_open_circuit")
	_check(first == true, "first valid Doctrine application succeeds")
	_check(second == false, "the same Doctrine cannot apply twice")
	_check(StringName(Global.get("attempt_doctrine_stage_ids").get(&"method", &"")) == &"doctrine_method_open_circuit", "selection is stored under Method")
	Global.pending_big_choice = old_pending
	Global.attempt_big_choice_source_segment = old_source
	Global.attempt_major_choice_offer_ids = old_offer
	Global.attempt_major_choice_taken_ids = old_taken
	Global.set("attempt_pending_doctrine_stage", old_stage)
	Global.set("attempt_doctrine_stage_ids", old_stage_ids)


func _has_property(object: Object, property_name: StringName) -> bool:
	for entry_variant in object.get_property_list():
		var entry := entry_variant as Dictionary
		if StringName(str(entry.get("name", ""))) == property_name:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("AscensionDoctrineTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
