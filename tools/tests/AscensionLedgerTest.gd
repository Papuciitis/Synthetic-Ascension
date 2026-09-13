extends Node

# The V4 advancement tree loads, its graph is what the package claims, and the
# purchase rules reproduce every authored example route at its authored price:
# adjacency, requirements, conflicts, the free starter, gate core choices,
# evolution claims, sink pricing, refunds and the save round trip.

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
	var db := AscensionTreeDB.shared()
	_check(db.nodes.size() == 350, "tree has 350 nodes (%d)" % db.nodes.size())
	var edge_count := 0
	var reciprocal := true
	for id in db.links:
		for other in db.links[id]:
			edge_count += 1
			if not db.neighbours(String(other)).has(String(id)):
				reciprocal = false
	_check(edge_count == 1292, "646 undirected links listed at both ends (%d)" % edge_count)
	_check(reciprocal, "every link is reciprocal")
	_check(db.ids_of_kind("fusion").size() == 27 and db.ids_of_kind("evolution").size() == 18 and db.ids_of_kind("revelation").size() == 9, "27 fusions, 18 evolutions, 9 revelations")
	_check(db.fusion_disciplines("MR2") == PackedStringArray(["EX", "BR"]), "Kill Feed joins EX and BR (%s)" % db.fusion_disciplines("MR2"))
	_check(db.sink_price("EXS1", 0) == 200 and db.sink_price("EXS1", 1) == 476, "sink pricing 200 x (rank+1)^1.25 (%d, %d)" % [db.sink_price("EXS1", 0), db.sink_price("EXS1", 1)])

	_test_rules(db)
	_test_routes(db)
	_test_global_state()
	print("%d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_rules(db: AscensionTreeDB) -> void:
	var ledger := AscensionLedger.new(db, AscensionLedger.fresh_state("melee"))
	var rich := 1000000
	_check(ledger.owns("core.melee") and not ledger.has_core("ranged"), "a fresh Melee ledger owns only its Core anchor")
	_check(ledger.can_buy("EX01", rich)["ok"] and ledger.price("EX01") == 0, "the first ring-1 native local is the free starter")
	_check(not ledger.can_buy("EX10", rich)["ok"], "Chain Sentence is not adjacent to anything owned yet: %s" % ledger.can_buy("EX10", rich)["reason"])
	_check(not ledger.can_buy("BR01", rich)["ok"], "a Ranged local needs the Ranged Core: %s" % ledger.can_buy("BR01", rich)["reason"])
	ledger.record_purchase("EX01", 0)
	_check(ledger.price("EX02") == 200, "the second entry costs 200")
	_check(not ledger.can_buy("EXQ", rich)["ok"], "Gavel needs two locals")
	ledger.record_purchase("EX02", 200)
	_check(ledger.can_buy("EXQ", rich)["ok"], "Gavel opens after two locals")
	_check(not ledger.can_buy("EXQ", 500)["ok"], "Gavel refuses a wallet under 800")
	ledger.record_purchase("EX03", 400)
	ledger.record_purchase("EX10", 800)
	ledger.record_purchase("EXQ", 800)
	_check(ledger.equipped("q") == "EXQ", "the first Q auto-equips")
	_check(not ledger.can_buy("G1", rich, "")["ok"], "a Gate needs a chosen Core")
	_check(ledger.can_buy("G1", rich, "ranged")["ok"], "G1 opens after four locals and a Q")
	ledger.record_purchase("G1", 1600, "ranged")
	_check(ledger.has_core("ranged") and ledger.owns("core.ranged"), "G1 grants the chosen Core anchor")
	_check(ledger.can_buy("BR02", rich)["ok"], "a Ranged entry is adjacent to the new anchor")
	ledger.record_purchase("BR02", 200)
	ledger.record_purchase("BR05", 400)
	_check(ledger.can_buy("MR2", rich)["ok"], "Kill Feed opens with Chain Sentence, Fragmentation and Finish")
	ledger.record_purchase("MR2", 1800)
	_check(ledger.milestone("one_fusion_owned"), "a fusion satisfies the G2 milestone")
	ledger.record_purchase("EX04", 400)
	ledger.record_purchase("EX05", 400)
	_check(ledger.can_buy("EXF1", rich)["ok"], "Meat opens after four locals and Corpse Bomb")
	ledger.record_purchase("EXF1", 800)
	_check(not ledger.can_buy("EXF2", rich)["ok"], "Blood is sealed by Meat: %s" % ledger.can_buy("EXF2", rich)["reason"])
	_check(not ledger.can_buy("EXE1", rich)["ok"], "an Evolution needs a banked claim")
	ledger.grant_evolution_claim()
	_check(not ledger.can_buy("EXE1", rich)["ok"], "Falling Gavel still needs Drop and Big One")
	_check(not ledger.can_buy("pick.M1", rich)["ok"], "a milestone pick waits for segment 3")
	ledger.note_segment_completed(3)
	_check(ledger.can_buy("pick.M1", rich)["ok"], "segment 3 unlocks Method picks")
	ledger.record_purchase("pick.M1", 0)
	_check(not ledger.can_buy("pick.M2", rich)["ok"], "Method picks are exclusive")
	var back := ledger.refund("EX03")
	_check(back == 400 and ledger.owns("EX10"), "refunding Spillover alone keeps Chain Sentence, still reachable through Kill Feed (%d)" % back)
	back = ledger.refund("BR05")
	_check(back == 400 + 1800 + 800, "refunding Fragmentation cascades through Kill Feed to the now-unreachable Chain Sentence (%d)" % back)
	_check(not ledger.owns("EX10") and not ledger.owns("MR2") and ledger.owns("EX01") and ledger.owns("BR02"), "dependents are removed, unrelated nodes stay")
	_check(ledger.effect_active("EX01") and ledger.effect_active("EXQ") and not ledger.effect_active("EXQ1"), "owned locals run, the equipped Q runs, an unowned mutation does not")
	_check(not ledger.can_buy("EXS1", rich)["ok"], "a sink still needs an owned neighbour: %s" % ledger.can_buy("EXS1", rich)["reason"])
	ledger.record_purchase("EX09", 400)
	_check(ledger.can_buy("EXS1", rich)["ok"] and ledger.price("EXS1") == 200, "first sink rank costs 200")
	ledger.record_purchase("EXS1", 200)
	_check(ledger.rank("EXS1") == 1 and ledger.price("EXS1") == 476, "sink rank 2 costs 476")


func _route_purchases(db: AscensionTreeDB, build: Dictionary) -> Dictionary:
	var native := String(build.get("native_core", "melee"))
	var ledger := AscensionLedger.new(db, AscensionLedger.fresh_state(native))
	ledger.note_segment_completed(9)
	var spent := 0
	var failed := ""
	var nodes: Array = build.get("nodes", [])
	for index in range(nodes.size()):
		var id := String(nodes[index])
		if id.begins_with("core."):
			continue  # anchors come with the preceding Gate
		var chosen := ""
		if db.kind(id) == "gate" and index + 1 < nodes.size() and String(nodes[index + 1]).begins_with("core."):
			chosen = String(nodes[index + 1]).trim_prefix("core.")
		if db.kind(id) == "evolution":
			ledger.grant_evolution_claim()
		var verdict := ledger.can_buy(id, 100000000, chosen)
		if not verdict["ok"]:
			failed = "%s: %s" % [id, verdict["reason"]]
			break
		spent += ledger.record_purchase(id, int(verdict["cost"]), chosen)
	return {"spent": spent, "failed": failed, "ledger": ledger}


func _test_routes(db: AscensionTreeDB) -> void:
	for build_variant in db.builds:
		var build := build_variant as Dictionary
		var result := _route_purchases(db, build)
		var name := String(build.get("name", "?"))
		_check(result["failed"] == "", "route '%s' purchases in order (%s)" % [name, result["failed"]])
		_check(result["spent"] == int(build.get("cost_followers", -1)), "route '%s' costs %d (authored %d)" % [name, result["spent"], int(build.get("cost_followers", -1))])
	var avalanche := _route_purchases(db, db.builds[db.builds.size() - 1])
	var ledger: AscensionLedger = avalanche["ledger"]
	_check(ledger.owns("ASC") and ledger.cores().size() == 3, "the Three-Core route ends with Ascendant and all three Cores")


func _test_global_state() -> void:
	_check(Global.attempt_ascension is Dictionary, "Global carries attempt_ascension")
	var ledger := Global.ascension_ledger()
	_check(ledger != null and ledger.native_core() in ["melee", "ranged", "magic"], "Global builds a ledger on the selected style (%s)" % (ledger.native_core() if ledger else "null"))
	var save := SaveData.new()
	Global.attempt_ascension["owned"]["EX01"] = 1
	var was_active := Global.attempt_active
	Global.attempt_active = true
	Global.write_save(save)
	_check(save.attempt_ascension.get("owned", {}).get("EX01", 0) == 1, "attempt_ascension round-trips into SaveData")
	Global.attempt_active = was_active
	Global.attempt_ascension["owned"].erase("EX01")
