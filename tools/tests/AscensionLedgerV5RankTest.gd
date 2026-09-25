extends Node

# Ranged V5 ordinary local ranks (handoff 2026-09-25, spec RANK-01..RANK-08):
# the V5 tree loads beside the untouched V4 control, rank purchases record
# exact per-rank receipts, gates hold, downgrades and cascades repay exactly,
# and the authored starter set is validated as authored rather than as prose.

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


func _fresh(native: String = "ranged") -> AscensionLedger:
	var db := AscensionTreeDB.shared_for("v5_ranged")
	return AscensionLedger.new(db, AscensionLedger.fresh_state(native, "v5_ranged"))


func _buy(ledger: AscensionLedger, id: String, wallet: int = 1000000) -> Dictionary:
	var verdict := ledger.can_buy(id, wallet)
	if bool(verdict["ok"]):
		ledger.record_purchase(id, int(verdict["cost"]))
	return verdict


func _run() -> void:
	_test_data_integrity()
	_test_rank01_receipts()
	_test_rank02_unique_counting()
	_test_rank03_04_gates()
	_test_rank05_foreign_lock()
	_test_rank06_downgrades_and_cascade()
	_test_rank07_no_duplicate_receipts()
	_test_rank08_starters_and_v4_control()
	print("%d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_data_integrity() -> void:
	var db := AscensionTreeDB.shared_for("v5_ranged")
	_check(db.version == "5.0-ranged-prototype", "V5 tree loads (%s)" % db.version)
	_check(db.nodes.size() == 350, "V5 keeps 350 nodes (%d)" % db.nodes.size())
	var reciprocal := true
	var edge_count := 0
	for id in db.links:
		for other in db.links[id]:
			edge_count += 1
			if not db.neighbours(String(other)).has(String(id)):
				reciprocal = false
	_check(reciprocal and edge_count == 1292, "V5 links reciprocal, 646 edges (%d)" % edge_count)
	var missing := PackedStringArray()
	for id in db.nodes:
		for rid in _requirement_ids(db.node(String(id)).get("requires", {})):
			if not db.has(rid):
				missing.append(rid)
	_check(missing.is_empty(), "every V5 requires id exists (%s)" % ", ".join(missing))
	_check(db.max_rank("BR05") == 4 and db.rank_cost("BR05", 2) == 700 and db.rank_cost("BR05", 4) == 2300, "BR05 rank prices follow the 400 row")
	_check(db.max_rank("EX01") == 1, "unauthored nodes stay rank 1")
	# The Big One correction: OR09 no longer satisfies OR12.
	var or12_ids := _requirement_ids(db.node("OR12").get("requires", {}))
	_check(not or12_ids.has("OR09") and or12_ids.has("OR01") and or12_ids.has("OR04") and or12_ids.has("OR11") and or12_ids.has("ORQ"), "OR12 requires a genuine Shell producer (%s)" % ", ".join(or12_ids))
	for pair in [["BR03", "BR01"], ["BR07", "BR01"], ["BRF1", "BR01"], ["BRF2", "BR03"], ["BRK1", "BR03"], ["BRS1", "BR03"], ["BRA", "BR03"], ["BRE1", "BR03"]]:
		_check(_requirement_ids(db.node(pair[0]).get("requires", {})).has(pair[1]), "%s requires %s" % [pair[0], pair[1]])


func _requirement_ids(rule: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if rule is Dictionary:
		var dict := rule as Dictionary
		if dict.has("owned"):
			out.append(String(dict["owned"]))
		if dict.has("count"):
			for id in (dict["count"] as Dictionary).get("ids", []):
				out.append(String(id))
		for key in ["all", "any"]:
			for child in dict.get(key, []):
				out.append_array(_requirement_ids(child))
	return out


func _test_rank01_receipts() -> void:
	var ledger := _fresh()
	var verdict := _buy(ledger, "BR01")
	_check(bool(verdict["ok"]) and int(verdict["cost"]) == 0, "BR01 is the free starter")
	_check(ledger.rank_receipts("BR01") == [0], "RANK-01: the free starter records an exact zero receipt (%s)" % str(ledger.rank_receipts("BR01")))
	var rank2 := ledger.can_buy("BR01", 1000000)
	_check(bool(rank2["ok"]) and bool(rank2.get("rank_up", false)) and int(rank2["cost"]) == 350, "RANK-01: BR01 rank 2 costs 350 (%d)" % int(rank2["cost"]))
	ledger.record_purchase("BR01", 350)
	_check(ledger.rank("BR01") == 2 and ledger.rank_receipts("BR01") == [0, 350], "RANK-01: rank 2 payment recorded exactly")
	_check(int(ledger.state["spent"]) == 350, "spent tracks only real payments (%d)" % int(ledger.state["spent"]))


func _test_rank02_unique_counting() -> void:
	var solo := _fresh()
	_buy(solo, "BR01")
	solo.record_purchase("BR01", 350)
	var rank3 := solo.can_buy("BR01", 1000000)
	_check(not bool(rank3["ok"]), "rank 3 refused with 0 other locals (%s)" % String(rank3["reason"]))
	# RANK-02: a high-rank node counts once toward count predicates.
	var counted := _fresh()
	_buy(counted, "BR01")
	counted.record_purchase("BR01", 350)
	_check(not bool(counted.can_buy("BRQ", 1000000)["ok"]), "RANK-02: BR01 rank 2 alone does not satisfy BRQ's two unique locals")
	_buy(counted, "BR02", 1000000)
	_check(bool(counted.can_buy("BRQ", 1000000)["ok"]), "RANK-02: two unique locals open BRQ")


func _test_rank03_04_gates() -> void:
	var ledger := _fresh()
	_buy(ledger, "BR01")
	_buy(ledger, "BR02")
	ledger.record_purchase("BR01", 350)
	var rank3 := ledger.can_buy("BR01", 1000000)
	_check(not bool(rank3["ok"]), "RANK-03: rank 3 with 1 other local refused (%s)" % String(rank3["reason"]))
	_buy(ledger, "BR04")
	rank3 = ledger.can_buy("BR01", 1000000)
	_check(bool(rank3["ok"]) and int(rank3["cost"]) == 750, "RANK-03: rank 3 opens with 2 other locals")
	ledger.record_purchase("BR01", 750)
	_check(ledger.rank("BR01") == 3 and db_max(ledger, "BR01") == 3, "BR01 caps at rank 3")
	_check(not bool(ledger.can_buy("BR01", 1000000)["ok"]), "a maxed node refuses further ranks")
	# RANK-04 on a max-4 node: BR05 rank 4 with 3 others refused.
	_buy(ledger, "BR05")
	ledger.record_purchase("BR05", 700)
	ledger.record_purchase("BR05", 1300)
	var rank4 := ledger.can_buy("BR05", 1000000)
	_check(not bool(rank4["ok"]), "RANK-04: rank 4 with 3 other locals refused (%s)" % String(rank4["reason"]))
	_buy(ledger, "BR06")
	rank4 = ledger.can_buy("BR05", 1000000)
	_check(bool(rank4["ok"]) and int(rank4["cost"]) == 2300, "RANK-04: rank 4 opens with 4 other locals")
	# A refused purchase changes neither ownership nor receipts.
	var before := ledger.rank_receipts("BR05").duplicate()
	var poor := ledger.can_buy("BR05", 10)
	_check(not bool(poor["ok"]) and ledger.rank_receipts("BR05") == before and ledger.rank("BR05") == 3, "a blocked rank purchase changes nothing")


func db_max(ledger: AscensionLedger, id: String) -> int:
	return ledger.db.max_rank(id)


func _test_rank05_foreign_lock() -> void:
	var melee := _fresh("melee")
	_check(not bool(melee.can_buy("BR01", 1000000)["ok"]), "RANK-05: a Ranged local refuses purchase without the Core")
	# An owned foreign node (simulated) still refuses rank upgrades without access.
	(melee.state["owned"] as Dictionary)["BR01"] = 1
	var verdict := melee.can_buy("BR01", 1000000)
	_check(not bool(verdict["ok"]), "RANK-05: rank upgrade refused without Core access (%s)" % String(verdict["reason"]))
	(melee.state["owned"] as Dictionary).erase("BR01")


func _test_rank06_downgrades_and_cascade() -> void:
	var ledger := _fresh()
	_buy(ledger, "BR01")
	_buy(ledger, "BR02")
	_buy(ledger, "BR04")
	_buy(ledger, "BR05")
	_buy(ledger, "BR06")
	ledger.record_purchase("BR05", 700)
	ledger.record_purchase("BR05", 1300)
	ledger.record_purchase("BR05", 2300)
	_check(ledger.rank("BR05") == 4 and ledger.rank_receipts("BR05") == [400, 700, 1300, 2300], "BR05 reaches rank 4 with exact receipts")
	var spent_before := int(ledger.state["spent"])
	_check(ledger.downgrade_rank("BR05") == 2300, "RANK-06: downgrading rank 4 returns exactly 2300")
	_check(ledger.downgrade_rank("BR05") == 1300, "RANK-06: then exactly 1300")
	_check(ledger.downgrade_rank("BR05") == 700, "RANK-06: then exactly 700")
	_check(ledger.rank("BR05") == 1 and ledger.rank_receipts("BR05") == [400], "rank 1 and its receipt remain")
	_check(not bool(ledger.downgrade_preview("BR05")["ok"]), "rank 1 leaves through an ordinary refund, not a downgrade")
	_check(int(ledger.state["spent"]) == spent_before - 4300, "spent shrinks by the exact repayments")
	# Cascade: rebuild rank 4, then refund another local so only 3 others remain.
	ledger.record_purchase("BR05", 700)
	ledger.record_purchase("BR05", 1300)
	ledger.record_purchase("BR05", 2300)
	var refunded := ledger.refund("BR04", 0.5)
	_check(ledger.rank("BR05") == 3, "cascade: losing a unique local drops BR05 to its legal rank 3 (%d)" % ledger.rank("BR05"))
	_check(refunded == int(round(400 * 0.5)) + 2300, "cascade refund = share of BR04 + exact rank-4 receipt (%d)" % refunded)
	_check(ledger.rank_receipts("BR05") == [400, 700, 1300], "cascade pops exactly one receipt")


func _test_rank07_no_duplicate_receipts() -> void:
	var ledger := _fresh()
	_buy(ledger, "BR01")
	_buy(ledger, "BR02")
	_buy(ledger, "BR04")
	ledger.record_purchase("BR01", 350)
	ledger.record_purchase("BR01", 750)
	# Saved-ledger roundtrip: a duplicated state reproduces the receipts.
	var copy: Dictionary = ledger.state.duplicate(true)
	var restored := AscensionLedger.new(AscensionTreeDB.shared_for("v5_ranged"), copy)
	_check(restored.tree_version() == "v5_ranged", "the tree version rides the save")
	_check(restored.rank("BR01") == 3 and restored.rank_receipts("BR01") == [0, 350, 750], "RANK-07: receipts round-trip through a saved state")
	# A downgrade in the restored ledger cannot be repeated for free money.
	_check(restored.downgrade_rank("BR01") == 750 and restored.downgrade_rank("BR01") == 350, "RANK-07: repeated downgrades follow the receipts down")
	_check(restored.downgrade_rank("BR01") == 0, "RANK-07: rank 1 refuses a third downgrade")
	# The original ledger's receipts were not disturbed by the copy.
	_check(ledger.rank_receipts("BR01") == [0, 350, 750], "RANK-07: the original receipts are untouched")
	# A whole-node V5 refund returns exact rank receipts + share of rank 1.
	var full := _fresh()
	_buy(full, "BR01")
	_buy(full, "BR02")
	_buy(full, "BR04")
	full.record_purchase("BR02", 350)
	var value := full.refund_value("BR02", 0.5)
	var back := full.refund("BR02", 0.5)
	_check(back == 350 + int(round(200 * 0.5)), "V5 node refund: exact rank-2 receipt plus half of rank 1 (%d)" % back)
	_check(value == back, "refund_value predicted the actual refund (%d vs %d)" % [value, back])
	_check(not full.owns("BR02") and full.rank_receipts("BR02").is_empty(), "the refunded node leaves no receipts behind")


func _test_rank08_starters_and_v4_control() -> void:
	var db := AscensionTreeDB.shared_for("v5_ranged")
	# The authored ranged starter set (validated as authored, not as prose).
	var starters := PackedStringArray()
	for node_variant in db.nodes.values():
		var node := node_variant as Dictionary
		if node.get("kind") == "local" and int(node.get("ring", 0)) == 1 and String(node.get("core", "")) == "ranged" and (node.get("links", []) as Array).has("core.ranged"):
			starters.append(String(node["id"]))
	starters.sort()
	_check(starters == PackedStringArray(["BR01", "BR02", "OR01", "OR02", "PR01", "PR02"]), "RANK-08: the authored ranged starter set is intact (%s)" % ", ".join(starters))
	for candidate in starters:
		var ledger := _fresh()
		var verdict := ledger.can_buy(candidate, 0)
		_check(bool(verdict["ok"]) and int(verdict["cost"]) == 0, "starter %s is selectable free" % candidate)
	# The V4 control is untouched: same file, no rank fields, old defaults.
	var v4 := AscensionTreeDB.shared()
	_check(v4.version == "4.0-prototype", "V4 stays 4.0-prototype (%s)" % v4.version)
	_check(v4.max_rank("BR05") == 1 and v4.max_rank("PR03") == 1, "V4 nodes expose no ordinary ranks")
	_check(String(v4.node("BR01").get("name")) == "Heat" and String(v4.node("OR02").get("name")) == "Caltrops", "V4 keeps its original names")
	var v4_ledger := AscensionLedger.new(v4, AscensionLedger.fresh_state("ranged"))
	_check(v4_ledger.tree_version() == "v4", "a fresh default ledger is V4")
	v4_ledger.record_purchase("BR01", 0)
	_check(not bool(v4_ledger.can_buy("BR01", 1000000)["ok"]), "V4 refuses rank investment (already owned)")
	# A V5 state never leaks into a V4 DB: version follows the state.
	var v5_state := AscensionLedger.fresh_state("ranged", "v5_ranged")
	_check(String(v5_state["tree_version"]) == "v5_ranged", "fresh V5 state is stamped")
