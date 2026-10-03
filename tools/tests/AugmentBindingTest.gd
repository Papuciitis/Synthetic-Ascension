extends Node

# The Binding (docs/design/2026-10-03-bindings-and-theses.md §3): a graded
# augment pick after every segment, with Recast, Abstain, Swap and the
# Transcend card. Pins the grade table, the deal, the Global flow and the
# save round trip.
#
# Run: <godot> --headless --path . res://tools/tests/AugmentBindingTest.tscn

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
	_test_grades()
	_test_deal()
	_test_levels()
	_test_cadence()
	_test_global_flow()
	_test_save_round_trip()
	print("AugmentBindingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- grades

func _shares(segment: int, luck: float, grade_mul: float = 1.0) -> PackedFloat32Array:
	var w := AugmentScaling.grade_weights(segment, luck, grade_mul)
	var total := 0.0
	for v in w:
		total += v
	var out := PackedFloat32Array()
	for v in w:
		out.append(v / total)
	return out


func _test_grades() -> void:
	var seg2 := _shares(2, 0.0)
	_check(absf(seg2[0] - 0.646) < 0.01 and absf(seg2[1] - 0.271) < 0.01 and absf(seg2[2] - 0.078) < 0.01, "seg 2 deals about 65 / 27 / 8 %% (%s)" % [seg2])
	var seg9 := _shares(9, 0.0)
	_check(absf(seg9[0] - 0.448) < 0.01 and absf(seg9[3] - 0.029) < 0.01, "seg 9 deals about 45%% Etched and 3%% Apocryphal (%s)" % [seg9])
	_check(_shares(5, 1.0)[0] < _shares(5, 0.0)[0], "Luck makes rarer grades more likely")
	_check(_shares(5, -1.0)[0] > _shares(5, 0.0)[0], "bad Luck makes them rarer")
	_check(_shares(5, 0.0, 1.6)[0] < _shares(5, 0.0)[0], "the Doctrine's grade multiplier shifts the deal")
	_check(AugmentScaling.grade_levels(0) == 1 and AugmentScaling.grade_levels(3) == 4, "Etched adds 1 level, Apocryphal 4")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var counts := [0, 0, 0, 0]
	for i in range(20000):
		counts[AugmentScaling.roll_grade(rng, 9, 0.0)] += 1
	_check(absf(float(counts[0]) / 20000.0 - seg9[0]) < 0.015, "rolls follow the weights (Etched %d / 20000)" % counts[0])
	var floored := true
	for i in range(500):
		if AugmentScaling.roll_grade(rng, 1, 0.0, 1.0, 1) < 1:
			floored = false
	_check(floored, "a grade floor (the Archive Canon) deals nothing below Gilded")


# ---------------------------------------------------------------- the deal

func _pool() -> Array:
	var pool: Array = []
	for id in Global.augment_db.keys():
		pool.append(StringName(id))
	pool.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return pool


func _context(equipped: Array, extra: Dictionary = {}) -> Dictionary:
	var context := {
		"equipped": equipped, "locked": [false, false, false], "pool": _pool(),
		"transcend_ready": [], "segment": 4, "luck": 0.0, "grade_mul": 1.0,
		"grade_floor": 0, "card_count": 3, "neg_guarantee": false,
	}
	context.merge(extra, true)
	return context


func _kinds(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(String(card["kind"]))
	return out


func _test_deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var open := AugmentBinding.build_offer(_context([&"augment_tesla_aura", StringName(), StringName()]), rng)
	_check(open.size() == 3 and _kinds(open) == ["new", "new", "new"], "a free slot deals three new augments (%s)" % [_kinds(open)])
	var no_dupes := true
	for card in open:
		if String(card["id"]) == "augment_tesla_aura":
			no_dupes = false
	_check(no_dupes, "a new card is never an augment already equipped")

	var full := [&"augment_tesla_aura", &"augment_magic_missile", &"augment_lucky_charm"]
	var full_offer := AugmentBinding.build_offer(_context(full), rng)
	_check(_kinds(full_offer) == ["rank", "rank", "swap"], "full slots deal two rank-ups and one swap (%s)" % [_kinds(full_offer)])
	var locked_offer := AugmentBinding.build_offer(_context(full, {"locked": [true, true, true]}), rng)
	_check(not _kinds(locked_offer).has("swap") and locked_offer.size() == 3, "with every slot locked there is no swap (%s)" % [_kinds(locked_offer)])

	var ready_offer := AugmentBinding.build_offer(_context(full, {"transcend_ready": [&"augment_magic_missile"]}), rng)
	_check(String(ready_offer[0]["kind"]) == "transcend" and String(ready_offer[0]["id"]) == "augment_magic_missile", "a ready augment's Transcendence is the first card")
	_check(int(ready_offer[0]["grade"]) == -1, "the Transcend card carries no grade")
	var ranked_again := false
	for i in range(1, ready_offer.size()):
		if String(ready_offer[i]["id"]) == "augment_magic_missile":
			ranked_again = true
	_check(not ranked_again, "the transcending augment is not also offered as a rank-up")

	var four := AugmentBinding.build_offer(_context([StringName(), StringName(), StringName()], {"card_count": 4}), rng)
	_check(four.size() == 4, "a fourth card when the Doctrine adds one")

	var graded := true
	for card in four:
		if int(card["grade"]) < 0 or int(card["grade"]) > 3:
			graded = false
	_check(graded, "every ordinary card is graded")

	# The fresh-profile intro keeps its NEG-archetype guarantee.
	var all_neg := true
	for i in range(40):
		rng.seed = 1000 + i
		var intro := AugmentBinding.build_offer(_context([StringName(), StringName(), StringName()], {"neg_guarantee": true}), rng)
		var has_neg := false
		for card in intro:
			if AugmentBinding.NEG_ARCHETYPE_IDS.has(StringName(str(card["id"]))):
				has_neg = true
		if not has_neg:
			all_neg = false
	_check(all_neg, "a fresh profile's first offer always carries a NEG archetype (40 seeds)")

	var a := AugmentBinding.build_offer(_context(full), _seeded(9))
	var b := AugmentBinding.build_offer(_context(full), _seeded(9))
	_check(a == b, "the same context and seed deal the same cards")


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_levels() -> void:
	_check(AugmentBinding.resulting_level({"kind": "new", "grade": 0}, 1) == 1, "an Etched new augment binds at Lv.1")
	_check(AugmentBinding.resulting_level({"kind": "new", "grade": 1}, 1) == 2, "a Gilded new augment binds at Lv.2")
	_check(AugmentBinding.resulting_level({"kind": "swap", "grade": 2}, 4) == 6, "a Sanctified swap-in keeps its stored Lv.4 and adds two")
	_check(AugmentBinding.resulting_level({"kind": "rank", "grade": 3}, 5) == 9, "an Apocryphal rank-up adds four")
	_check(AugmentBinding.resulting_level({"kind": "transcend", "grade": -1}, 5) == 6, "a Transcendence adds one")
	_check(AugmentBinding.resulting_level({"kind": "rank", "grade": 3}, 19) == AugmentScaling.MAX_LEVEL, "levels stop at the cap")


# ---------------------------------------------------------------- Global

func _fresh_attempt() -> void:
	Global.start_new_attempt()
	Global.attempt_world_seed = 424242
	Global.run_luck = 0.0


func _test_cadence() -> void:
	_fresh_attempt()
	var every := true
	for completed in range(1, 12):
		Global.pending_augment_pick = false
		Global.on_segment_completed(completed)
		if not Global.pending_augment_pick:
			every = false
	_check(every, "a Binding follows every segment (1 through 11), not just 2 and 7")
	Global.attempt_segment = 1
	_check(not Global.binding_can_trade(), "the intro pick cannot be recast or abstained")
	Global.attempt_segment = 5
	_check(Global.binding_can_trade() and Global.binding_segment() == 4, "the pick that opens segment 5 belongs to segment 4 and can trade")


func _test_global_flow() -> void:
	_fresh_attempt()
	Global.permanent_augment_ids = [&"augment_tesla_aura", StringName(), StringName()]
	Global.augment_slot_locks = [false, false, false]
	Global.attempt_augment_levels = {"augment_tesla_aura": 2}
	Global.on_segment_completed(3)
	_check(Global.pending_augment_pick, "segment 3 queues a Binding")
	var first := Global.binding_offer()
	var again := Global.binding_offer()
	_check(not first.is_empty() and first == again, "the offer is dealt once and kept")
	_check(first == Global.attempt_binding_offer, "and it is the persisted offer")

	Global.set_followers(1000)
	var cost := Global.binding_recast_cost()
	_check(cost == AugmentScaling.recast_cost(3, 0), "the first Recast costs 40 x segment (%d)" % cost)
	_check(Global.binding_recast(), "a Recast with enough Followers succeeds")
	_check(Global.followers == 1000 - cost, "and spends exactly its price")
	_check(Global.binding_recast_cost() == AugmentScaling.recast_cost(3, 1), "the next Recast costs more (%d)" % Global.binding_recast_cost())
	_check(Global.attempt_binding_recasts == 1, "the recast is counted")
	Global.set_followers(0)
	_check(not Global.binding_recast(), "a Recast without the Followers is refused")

	Global.set_doctrine_rule(&"binding_free_recasts", 2.0)
	_check(Global.binding_recast_cost() == 0, "a free Recast from the Doctrine costs nothing")
	Global.set_doctrine_rule(&"binding_free_recasts", 0.0)

	# A rank-up applies the dealt grade.
	var rank := {"kind": "rank", "id": "augment_tesla_aura", "grade": 2}
	Global.attempt_binding_offer = [rank, {"kind": "new", "id": "augment_lucky_charm", "grade": 1}]
	_check(not Global.apply_binding_card({"kind": "new", "id": "augment_sprint_servos", "grade": 3}), "a card that was not dealt is refused")
	_check(Global.apply_binding_card(rank), "a dealt rank-up applies")
	_check(Global.get_augment_level(&"augment_tesla_aura") == 5, "Sanctified adds three levels: 2 -> 5")
	_check(not Global.pending_augment_pick and Global.attempt_binding_offer.is_empty() and Global.attempt_binding_recasts == 0, "applying closes the Binding")

	# A new card binds into the first free slot at its grade.
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "new", "id": "augment_lucky_charm", "grade": 1}]
	_check(Global.apply_binding_card({"kind": "new", "id": "augment_lucky_charm"}), "a new card applies (the dealt grade is authoritative)")
	_check(Global.permanent_augment_ids[1] == &"augment_lucky_charm" and Global.get_augment_level(&"augment_lucky_charm") == 2, "Gilded binds Lucky Charm at Lv.2 in slot II")

	# A swap needs an unlocked slot and keeps the old augment's level.
	Global.permanent_augment_ids = [&"augment_tesla_aura", &"augment_lucky_charm", &"augment_magic_missile"]
	Global.init_owned_augments()
	Global.augment_slot_locks = [false, true, false]
	Global.pending_augment_pick = true
	var swap := {"kind": "swap", "id": "augment_sprint_servos", "grade": 0}
	Global.attempt_binding_offer = [swap]
	_check(not Global.apply_binding_card(swap), "a swap without a slot is refused")
	_check(not Global.apply_binding_card(swap, 1), "a swap into a locked slot is refused")
	_check(Global.apply_binding_card(swap, 2), "a swap into an unlocked slot applies")
	_check(Global.permanent_augment_ids[2] == &"augment_sprint_servos" and Global.owned_augment_ids.has(&"augment_magic_missile"), "the swapped-out augment stays in the library")
	Global.augment_slot_locks = [false, false, false]

	# Abstain pays and closes.
	Global.attempt_segment = 7
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = []
	Global.set_followers(0)
	var reward := Global.binding_abstain_reward()
	_check(reward == AugmentScaling.abstain_reward(6), "Abstain pays 75 x segment (%d)" % reward)
	_check(Global.binding_abstain() == reward and Global.followers == reward, "Abstain pays it")
	_check(not Global.pending_augment_pick, "and closes the Binding")
	_check(Global.binding_abstain() == -1, "nothing to abstain from once closed")

	# The Transcend card.
	Global.permanent_augment_ids = [&"augment_tesla_aura", &"augment_sprint_servos", StringName()]
	Global.attempt_augment_levels["augment_tesla_aura"] = 5
	_check(Global.augment_transcend_ready(&"augment_tesla_aura"), "Tesla Aura at Lv.5 beside Sprint Servos is ready to Transcend")
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = []
	var deal := Global.binding_offer()
	_check(String(deal[0]["kind"]) == "transcend" and String(deal[0]["id"]) == "augment_tesla_aura", "the Binding deals its Transcendence first")
	_check(Global.apply_binding_card(deal[0]), "the Transcend card applies")
	_check(Global.is_augment_transcended(&"augment_tesla_aura") and Global.get_augment_level(&"augment_tesla_aura") == 6, "Tesla Aura is Storm Crown at Lv.6")
	_check(Global.augment_display_name(&"augment_tesla_aura") == "Storm Crown", "and every surface names it so")
	_check(not Global.augment_transcend_ready(&"augment_tesla_aura"), "a Transcended augment never offers it again")


func _test_save_round_trip() -> void:
	_fresh_attempt()
	Global.attempt_active = true
	Global.permanent_augment_ids = [&"augment_magic_missile", StringName(), StringName()]
	Global.attempt_augment_transcended = {"augment_magic_missile": true}
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "rank", "id": "augment_magic_missile", "grade": 1}]
	Global.attempt_binding_recasts = 2
	var save := SaveData.new()
	Global.write_save(save)
	_check(bool(save.attempt_augment_transcended.get("augment_magic_missile", false)), "Transcendence is written")
	_check(save.attempt_binding_offer.size() == 1 and save.attempt_binding_recasts == 2, "the pending offer and its recast count are written")
	Global.attempt_augment_transcended = {}
	Global.attempt_binding_offer = []
	Global.attempt_binding_recasts = 0
	Global.apply_save(save)
	_check(Global.is_augment_transcended(&"augment_magic_missile"), "Transcendence survives a reload")
	_check(Global.attempt_binding_offer.size() == 1 and String(Global.attempt_binding_offer[0]["id"]) == "augment_magic_missile", "the same cards come back: a reload is not a free Recast")
	_check(Global.attempt_binding_recasts == 2, "and so does the recast count")
	var old := SaveData.new()
	_check(old.attempt_augment_transcended.is_empty() and old.attempt_binding_offer.is_empty() and old.attempt_binding_recasts == 0, "an older save loads the new fields as empty")
