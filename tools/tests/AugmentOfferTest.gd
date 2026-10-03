extends Node

# Segment 1 pass S2: a fresh profile's first augment offer always carries
# one of the three NEG archetypes, so the first curse has a reader. The offer
# is AugmentBinding's deal now (bindings-and-theses §3); the guarantee rides
# its neg_guarantee flag, which Global sets exactly for a fresh profile.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/AugmentOfferTest.tscn

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
	for card in offers:
		if AugmentBinding.NEG_ARCHETYPE_IDS.has(StringName(str(card["id"]))):
			return true
	return false


func _run() -> void:
	_check(Global.augment_db.size() >= 6, "the augment database holds enough augments (%d)" % Global.augment_db.size())
	var saved := Global.permanent_augment_ids.duplicate()

	# Worst case: a pool whose NEG archetypes come last, dealt by a seed that
	# would never reach them.
	var ordered: Array = []
	var negs: Array = []
	for id in Global.augment_db.keys():
		if AugmentBinding.NEG_ARCHETYPE_IDS.has(StringName(id)):
			negs.append(StringName(id))
		else:
			ordered.append(StringName(id))
	var context := {
		"equipped": [StringName(), StringName(), StringName()], "locked": [false, false, false],
		"pool": ordered + negs, "transcend_ready": [], "segment": 1, "luck": 0.0,
		"grade_mul": 1.0, "grade_floor": 0, "card_count": 3, "neg_guarantee": true,
	}
	var every_seed := true
	var third_only := true
	for seed_value in range(60):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var offers := AugmentBinding.build_offer(context, rng)
		if offers.size() != 3 or not _has_neg(offers):
			every_seed = false
		var plain_rng := RandomNumberGenerator.new()
		plain_rng.seed = seed_value
		var plain := AugmentBinding.build_offer(context.merged({"neg_guarantee": false}, true), plain_rng)
		if not _has_neg(plain) and (String(offers[0]["id"]) != String(plain[0]["id"]) or String(offers[1]["id"]) != String(plain[1]["id"])):
			third_only = false
	_check(every_seed, "a fresh profile's three cards include a NEG archetype on every seed")
	_check(third_only, "when the deal missed them, only the third card is replaced")

	# Global sets the guarantee for a fresh profile and drops it after.
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	_check(bool(Global.binding_context()["neg_guarantee"]), "an empty profile asks for the guarantee")
	Global.permanent_augment_ids = [&"augment_sprint_servos", StringName(), StringName()]
	_check(not bool(Global.binding_context()["neg_guarantee"]), "a profile that owns an augment gets the plain deal")
	Global.permanent_augment_ids = saved
	print("AugmentOfferTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
