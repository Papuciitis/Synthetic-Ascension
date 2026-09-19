extends Node

# Segment 1 pass S2: a fresh profile's first augment offer always carries
# one of the three NEG archetypes, so the first curse has a reader.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/AugmentOfferTest.tscn

const SELECT := preload("res://ui/augments/AugmentSelect.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _has_neg(offers: Array) -> bool:
	for a in offers:
		if a != null and SELECT.NEG_ARCHETYPE_IDS.has(a.id):
			return true
	return false


func _run() -> void:
	var options: Array[AugmentData] = []
	for value in Global.augment_db.values():
		if value is AugmentData:
			options.append(value)
	_check(options.size() >= 6, "the augment database holds enough augments (%d)" % options.size())
	var saved := Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	# Worst case: the shuffle put every NEG archetype past the third card.
	var ordered: Array[AugmentData] = []
	var negs: Array[AugmentData] = []
	for a in options:
		if SELECT.NEG_ARCHETYPE_IDS.has(a.id):
			negs.append(a)
		else:
			ordered.append(a)
	ordered.append_array(negs)
	var select := SELECT.new()
	var offers: Array = select._build_offers(ordered)
	_check(offers.size() == 3 and _has_neg(offers), "a fresh profile's three cards include a NEG archetype even when the shuffle buried them")
	_check(SELECT.NEG_ARCHETYPE_IDS.has(offers[2].id), "it takes the third card, the first two stay as shuffled")
	var already: Array[AugmentData] = [negs[0], ordered[0], ordered[1]]
	var kept: Array = SELECT.ensure_neg_archetype(already.duplicate(), ordered)
	_check(kept[0] == negs[0] and kept[1] == ordered[0] and kept[2] == ordered[1], "an offer that already carries one is left alone")
	Global.permanent_augment_ids = [&"augment_sprint_servos", StringName(), StringName()]
	var veteran: Array = select._build_offers(ordered)
	_check(veteran.size() == 3 and not _has_neg(veteran), "a profile that owns an augment gets the plain shuffled offer")
	select.free()
	Global.permanent_augment_ids = saved
	print("AugmentOfferTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
