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
			int(higher["rarity_min"]) > int(lower["rarity_min"]),
			"tier %d pays better" % index
		)
		_check(
			float(higher["base_odds"]) < float(lower["base_odds"]),
			"tier %d is less likely to pay at all" % index
		)

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

	Global.followers = floor_cost + stake
	_check(shrine.call("_can_afford", stake), "the stake is allowed above the reconstruction floor")
	Global.followers = floor_cost + stake - 1
	_check(
		not shrine.call("_can_afford", stake),
		"the stake is refused when it would eat a reconstruction"
	)
	Global.followers = 0
	_check(not shrine.call("_can_afford", stake), "a broke player is refused")
	shrine.free()
