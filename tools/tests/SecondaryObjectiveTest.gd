extends Node

## Secondary objectives must be more than one shape, and the wager must be a
## wager - it cannot silently be free, unwinnable, or able to strand the player.

var _passes: int = 0
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	_test_plans_offer_variety()
	_test_wager_tiers()
	_test_wager_cannot_strand_the_player()
	print("SecondaryObjectiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## A district with three secondaries used to plan two identical alley caches.
func _test_plans_offer_variety() -> void:
	var seen: Dictionary = {}
	var triples: int = 0
	for seed_value in range(60):
		var plan := DistrictPlan.generate(6, 90000 + seed_value, 2048, null)
		var secondaries: Array = plan.get("secondary_objectives", [])
		for entry_variant in secondaries:
			seen[StringName((entry_variant as Dictionary).get("type", &""))] = true
		if secondaries.size() >= 3:
			triples += 1
			var types: Dictionary = {}
			for entry_variant in secondaries:
				types[StringName((entry_variant as Dictionary).get("type", &""))] = true
			_check(
				types.size() >= 2,
				"a three-secondary district offers more than one kind (%d kinds)" % types.size()
			)
	_check(triples > 0, "some districts plan three secondaries (%d of 60)" % triples)
	_check(
		seen.has(&"wager_shrine"),
		"the wager shrine reaches the plan (types seen: %s)" % str(seen.keys())
	)
	_check(seen.size() >= 3, "districts offer at least three secondary kinds (%d)" % seen.size())


func _test_wager_tiers() -> void:
	var shrine := WagerShrineObjective.new()
	shrine.configure(4242)
	var tiers: Array = WagerShrineObjective.TIERS
	_check(tiers.size() >= 3, "the wager escalates through tiers (%d)" % tiers.size())

	# A higher stake must buy strictly better loot and strictly worse odds, or
	# raising it is not a decision.
	for index in range(1, tiers.size()):
		var lower: Dictionary = tiers[index - 1]
		var higher: Dictionary = tiers[index]
		_check(int(higher["stake"]) > int(lower["stake"]), "tier %d costs more" % index)
		_check(
			WagerShrineObjective.tier_band(index).x > WagerShrineObjective.tier_band(index - 1).x,
			"tier %d pays better" % index
		)
		_check(
			float(higher["base_odds"]) < float(lower["base_odds"]),
			"tier %d is less likely to pay at all" % index
		)

	# The top tier rides the segment's rarity cap (loot loop pass L5): no
	# R7+ at segment 1, and it keeps climbing with the segment.
	var saved_segment := int(Global.attempt_segment)
	Global.attempt_segment = 1
	_check(WagerShrineObjective.tier_band(0) == Vector2i(2, 4) and WagerShrineObjective.tier_band(2) == Vector2i(4, 6), "at segment 1 the Offering pays R2-R4 and the Covenant R4-R6 (%s)" % str(WagerShrineObjective.tier_band(2)))
	Global.attempt_segment = 9
	_check(WagerShrineObjective.tier_band(2) == Vector2i(7, 9), "at segment 9 it pays R7-R9")
	Global.attempt_segment = saved_segment
	_check(int(tiers[0]["stake"]) == 20, "the first stake is 20 Followers, not pocket change")
	# Luck has to bend it, and the curve must stay a probability.
	var before: float = shrine.odds_for(1)
	Global.run_luck = 40.0
	var after: float = shrine.odds_for(1)
	Global.run_luck = 0.0
	_check(after > before, "Luck improves the wager (%.2f -> %.2f)" % [before, after])
	_check(shrine.odds_for(0) <= 0.97 and shrine.odds_for(2) >= 0.05, "odds stay a probability")
	_check(shrine.odds_for(-1) == 0.0, "no tier bought is no chance of a payout")
	shrine.free()


## Followers are lives. A player may go broke at the shrine; they must never be
## unable to reconstruct because of it.
func _test_wager_cannot_strand_the_player() -> void:
	var shrine := WagerShrineObjective.new()
	shrine.configure(99)
	var floor_cost: int = int(Global.compute_respawn_cost())
	var stake: int = int(WagerShrineObjective.TIERS[0]["stake"])

	# A death charges the cost and then needs a balance above zero, so the
	# stake must leave more than the cost, not exactly the cost.
	Global.followers = floor_cost + stake + 1
	_check(shrine.call("_can_afford", stake), "the stake is allowed when it leaves more than the reconstruction cost")
	Global.followers = floor_cost + stake
	_check(not shrine.call("_can_afford", stake), "a stake that leaves exactly the reconstruction cost is refused: that death would end the run")
	Global.followers = floor_cost + stake - 1
	_check(
		not shrine.call("_can_afford", stake),
		"the stake is refused when it would eat a reconstruction"
	)
	Global.followers = 0
	_check(not shrine.call("_can_afford", stake), "a broke player is refused")
	shrine.free()
