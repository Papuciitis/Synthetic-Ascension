extends Node

# Acquisition milestones must survive inherited wealth without changing
# ownership, combat activation, authored recipes or legacy ledger versions.
const SCREEN = preload("res://ui/screens/AscensionScreen.tscn")
const RICH := 2000000000

var _passes := 0
var _failures := 0


func _ready() -> void:
	SaveManager.current_save = null
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


# A hand-built, fully qualified Revelation recipe: six locals and its
# Catastrophe. Direct records isolate acquisition from route sequencing.
func _qualified(db: AscensionTreeDB, id: String, completed: int, revision: int = 1) -> AscensionLedger:
	var state := AscensionLedger.fresh_state(db.core_of(id), db.variant)
	state["city_pacing_revision"] = revision
	var ledger := AscensionLedger.new(db, state)
	var discipline := db.discipline_of(id)
	for index in range(1, 7):
		ledger.record_purchase("%s%02d" % [discipline, index], 400)
	ledger.record_purchase(discipline + "C", 3000)
	ledger.note_segment_completed(completed)
	return ledger


func _run() -> void:
	for version in ["v4", "v5_ranged"]:
		_test_boundaries(AscensionTreeDB.shared_for(version))
	_test_legacy_and_owned()
	_test_production_start()
	await _test_details()
	print("AscensionCityPacingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_boundaries(db: AscensionTreeDB) -> void:
	for id_variant in db.ids_of_kind("revelation"):
		var id := String(id_variant)
		for completed in [6, 7, 8, 9]:
			var ledger := _qualified(db, id, completed)
			var verdict := ledger.can_buy(id, RICH)
			_check(bool(verdict["ok"]) == (completed >= 8), "%s %s: rich qualified Revelation at completed %d" % [db.variant, id, completed])
			if completed < 8:
				_check(String(verdict["reason"]).contains("8"), "%s refusal explains completed segment 8" % id)
		var missing_recipe := AscensionLedger.new(db, AscensionLedger.fresh_state(db.core_of(id), db.variant))
		missing_recipe.state["city_pacing_revision"] = 1
		missing_recipe.note_segment_completed(8)
		missing_recipe.record_purchase(db.discipline_of(id) + "Q", 800)
		_check(not missing_recipe.can_buy(id, RICH)["ok"], "%s still needs its authored recipe after completed 8" % id)
		var missing_core := _qualified(db, id, 9)
		missing_core.state["cores"] = []
		_check(not missing_core.can_buy(id, RICH)["ok"], "%s still needs Core access after completed 9" % id)
		_check(not _qualified(db, id, 8).can_buy(id, 0)["ok"], "%s still needs Followers after its milestone" % id)
	for id_variant in db.ids_of_kind("revelation_mutation"):
		var id := String(id_variant)
		for completed in [6, 7, 8, 9]:
			var ledger := _qualified(db, id, completed)
			ledger.record_purchase(ledger.mutation_parent(id), 4800)
			var verdict := ledger.can_buy(id, RICH)
			_check(bool(verdict["ok"]) == (completed >= 9), "%s %s: rich parent-owned mutation at completed %d" % [db.variant, id, completed])
			if completed < 9:
				_check(String(verdict["reason"]).contains("9"), "%s refusal explains completed segment 9" % id)
		var missing_parent := _qualified(db, id, 9)
		_check(not missing_parent.can_buy(id, RICH)["ok"], "%s cannot bypass its missing parent after completed 9" % id)


func _test_legacy_and_owned() -> void:
	for version in ["v4", "v5_ranged"]:
		var db := AscensionTreeDB.shared_for(version)
		var ledger := _qualified(db, "MOV", 0, 0)
		ledger.state.erase("city_pacing_revision")
		var loaded := AscensionLedger.new(db, ledger.state.duplicate(true))
		_check(int(loaded.state.get("city_pacing_revision", -1)) == 0 and loaded.can_buy("MOV", RICH)["ok"], "%s missing marker remains legacy and can acquire BLINK before segment 8" % version)
		loaded.record_purchase("MOV", 4321)
		loaded.record_purchase("MOV1", 1234)
		loaded.state["paid_ranks"]["MO01"] = [0, 350]
		var saved := loaded.state.duplicate(true)
		var resumed := AscensionLedger.new(db, saved)
		_check(resumed.can_equip("v", "MOV") and resumed.effect_active("MOV") and resumed.effect_active("MOV1"), "%s old owned BLINK and its mutation remain usable before milestones" % version)
		_check(saved["tree_version"] == version and saved["paid"]["MOV"] == 4321 and saved["paid_ranks"]["MO01"] == [0, 350], "%s loading preserves tree version and exact receipts" % version)
		# Even an explicit pacing marker is acquisition-only for existing owners.
		resumed.state["city_pacing_revision"] = 1
		_check(resumed.effect_active("MOV") and resumed.effect_active("MOV1"), "%s pacing never disables owned abilities" % version)
		var old_rules := _qualified(db, "MOV", 0, 0)
		var paced := _qualified(db, "MOV", 0)
		for id in ["MOQ", "MOC", "MO07"]:
			old_rules.state["owned"].erase(id)
			paced.state["owned"].erase(id)
			_check(paced.can_buy(id, RICH) == old_rules.can_buy(id, RICH), "%s %s retains ordinary acquisition rules" % [version, id])


func _test_production_start() -> void:
	Global.start_new_attempt()
	var ledger := Global.ascension_ledger()
	_check(int(ledger.state.get("city_pacing_revision", 0)) == 1, "production new attempt opts into revision 1")
	var save := SaveData.new()
	Global.write_save(save)
	_check(int(save.attempt_ascension.get("city_pacing_revision", 0)) == 1, "new-attempt pacing marker persists in its save")
	var legacy := _qualified(AscensionTreeDB.shared(), "MOV", 0, 0).state
	legacy.erase("city_pacing_revision")
	Global.attempt_ascension = legacy
	_check(Global.ascension_ledger().can_buy("MOV", RICH)["ok"] and int(Global.attempt_ascension.get("city_pacing_revision", -1)) == 0, "production lazy loading never opts a nonempty old ledger into pacing")


func _test_details() -> void:
	Global.attempt_ascension = _qualified(AscensionTreeDB.shared(), "MOV", 7).state
	Global.set_followers(RICH)
	var screen := SCREEN.instantiate() as AscensionScreen
	add_child(screen)
	screen.open(false)
	await get_tree().process_frame
	screen._show("MOV")
	_check(screen.view.state_of("MOV") == "locked" and screen._status.text.contains("8"), "rich-wallet UI marks BLINK locked and explains the segment-8 requirement")
	var refused := Global.ascension_buy("MOV")
	_check(not refused["ok"] and Global.followers == RICH and not Global.ascension_ledger().owns("MOV"), "production purchase refuses a rich wallet without spending or granting ownership")
	Global.ascension_ledger().note_segment_completed(8)
	screen._refresh_all()
	screen._show("MOV")
	_check(screen._rules.text.contains("8"), "Revelation details retain the acquisition milestone after it is met")
	_check(Global.ascension_buy("MOV")["ok"], "production purchase unlocks at completed 8")
	screen._refresh_all()
	screen._show("MOV1")
	_check(screen.view.state_of("MOV1") == "locked" and screen._status.text.contains("9") and screen._rules.text.contains("9"), "owned-parent mutation details and refusal explain completed 9")
	Global.ascension_ledger().note_segment_completed(9)
	_check(Global.ascension_buy("MOV1")["ok"] and Global.ascension_ledger().effect_active("MOV1"), "production mutation purchase unlocks at completed 9 and activates normally")
	screen.close()
	screen.queue_free()
	await get_tree().process_frame
