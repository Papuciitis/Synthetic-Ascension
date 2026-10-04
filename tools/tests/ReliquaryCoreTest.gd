extends Node

# The core of Duos, Facets, the Burden, the Reliquary and the Grimoire
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md): the rules
# tables, the deal's DUO and FACET cards, Global's flow for each piece, the
# Vouchers wired into the Binding helpers, and the save round trip. The
# effects and screens that use this are pinned by their own suites.
#
# Run: <godot> --headless --path . res://tools/tests/ReliquaryCoreTest.tscn

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


func _near(a: float, b: float, tolerance: float = 0.0005) -> bool:
	return absf(a - b) <= tolerance


func _run() -> void:
	_test_tables()
	_test_deal()
	_test_duo_and_facet_cards()
	_test_burden()
	_test_corruption()
	_test_transfusion()
	_test_vouchers()
	_test_grimoire()
	_test_save()
	_test_review_fixes()
	print("ReliquaryCoreTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _fresh(equipped: Array, levels: Dictionary, segment: int = 5) -> void:
	Global.start_new_attempt()
	Global.attempt_world_seed = 777
	var typed: Array[StringName] = []
	typed.assign(equipped)
	Global.permanent_augment_ids = typed
	Global.init_owned_augments()
	Global.augment_slot_locks = [false, false, false]
	Global.attempt_augment_levels = levels
	Global.attempt_segment = segment
	Global.run_luck = 0.0


func _test_tables() -> void:
	var members_known := true
	for duo_id in AugmentDuos.ids():
		var pair := AugmentDuos.members(duo_id)
		if pair.size() != 2 or not Global.augment_db.has(pair[0]) or not Global.augment_db.has(pair[1]) or AugmentDuos.rule(duo_id) == "":
			members_known = false
	_check(AugmentDuos.ids().size() == 6 and members_known, "six Duos, each of two real augments with a rule")
	var facets_known := true
	for aug_id in AugmentFacets.FACETS:
		if not Global.augment_db.has(aug_id) or AugmentFacets.options(aug_id).size() != 2:
			facets_known = false
	_check(AugmentFacets.FACETS.size() == 7 and facets_known, "seven combat augments with two Facets each")
	_check(_near(AugmentFacets.value(&"augment_tesla_aura", &"overcharge", "damage_mul", 1.0), 1.7) and _near(AugmentFacets.value(&"augment_tesla_aura", &"", "damage_mul", 1.0), 1.0), "a Facet's numbers read from the table, 1.0 without one")
	var weights := AugmentRites.corruption_weights(0.0)
	_check(_near(weights[0], 45.0) and _near(weights[1], 35.0) and _near(weights[2], 20.0), "Corruption deals 45 / 35 / 20")
	var lucky := AugmentRites.corruption_weights(1000.0)
	_check(lucky[0] > 54.9 and lucky[2] < 10.1, "Luck moves up to 10 points from Sundered to Exalted")
	_check(AugmentRites.corrupted_level(AugmentRites.EXALTED, 4) == 7 and AugmentRites.corrupted_level(AugmentRites.SCARRED, 4) == 6 and AugmentRites.corrupted_level(AugmentRites.SUNDERED, 2) == 1, "Exalted +3, Scarred +2, Sundered -2 never below 1")
	_check(AugmentRites.transfusion_gain(1) == 0 and AugmentRites.transfusion_gain(5) == 2 and AugmentRites.transfusion_cost(2) == 80, "a Lv.5 donor pours 2 levels for 80 Followers; Lv.1 pours nothing")
	_check(Vouchers.ids().size() == 8 and Vouchers.price(1) == 300 and Vouchers.price(4) == 600, "eight Vouchers at 200 + 100 x segment, 300 at the first Hub as before (follower economy audit P4)")
	var catalogue := Grimoire.catalogue(Global.augment_db)
	_check(catalogue.size() == 16 + 6 + 14 + 3 + 3 + StoryLines.RECORDS.size(), "the Grimoire lists 16 Transcendences, 6 Duos, 14 Facets, 3 Theses, 3 Canons and the story's records (%d)" % catalogue.size())


func _context(extra: Dictionary) -> Dictionary:
	var pool: Array = Global.augment_db.keys()
	pool.sort()
	var context := {
		"equipped": [&"augment_magic_missile", &"augment_tesla_aura", StringName()], "locked": [false, false, false],
		"pool": pool, "transcend_ready": [], "segment": 5, "luck": 0.0, "grade_mul": 1.0,
		"grade_floor": 0, "card_count": 3, "neg_guarantee": false, "duo_ready": [], "facet_ready": [],
	}
	context.merge(extra, true)
	return context


func _test_deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var offer := AugmentBinding.build_offer(_context({"duo_ready": [AugmentDuos.LIGHTNING_RODS], "facet_ready": [&"augment_tesla_aura"]}), rng)
	_check(String(offer[0]["kind"]) == "duo" and String(offer[0]["id"]) == String(AugmentDuos.LIGHTNING_RODS), "a ready Duo is dealt first")
	_check(String(offer[1]["kind"]) == "facet" and String(offer[1]["id"]) == "augment_tesla_aura", "then a Facet")
	_check(offer.size() == 3 and not AugmentBinding.SPECIAL_KINDS.has(String(offer[2]["kind"])), "and at least one ordinary card")
	_check(int(offer[0]["grade"]) == -1 and int(offer[1]["grade"]) == -1, "Duo and Facet cards carry no grade")
	var crowded := AugmentBinding.build_offer(_context({"transcend_ready": [&"augment_tesla_aura"], "duo_ready": [AugmentDuos.LIGHTNING_RODS], "facet_ready": [&"augment_magic_missile"]}), rng)
	_check(String(crowded[0]["kind"]) == "transcend" and String(crowded[1]["kind"]) == "duo" and not AugmentBinding.SPECIAL_KINDS.has(String(crowded[2]["kind"])), "Transcend outranks Duo outranks Facet, and two specials is the most of three cards")
	_check(AugmentBinding.display_augment_id({"kind": "duo", "id": String(AugmentDuos.PHANTOM_STEP)}) == &"augment_blink_hex", "a Duo card shows its first member")
	_check(AugmentBinding.resulting_level({"kind": "facet", "id": "augment_tesla_aura", "grade": -1}, 4) == 4, "a Facet adds no level")


func _test_duo_and_facet_cards() -> void:
	_fresh([&"augment_magic_missile", &"augment_tesla_aura", StringName()], {"augment_magic_missile": 2, "augment_tesla_aura": 3})
	_check(Global.duos_ready().is_empty(), "a Duo waits for both augments at Lv.3")
	Global.attempt_augment_levels["augment_magic_missile"] = 3
	_check(Global.duos_ready() == [AugmentDuos.LIGHTNING_RODS], "Magic Missile and Tesla Aura at Lv.3 ready Lightning Rods")
	_check(Global.facets_ready() == [&"augment_magic_missile", &"augment_tesla_aura"], "both may take a Facet at Lv.3")
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = []
	var deal := Global.binding_offer()
	_check(String(deal[0]["kind"]) == "duo", "the Binding deals the Duo")
	_check(Global.apply_binding_card(deal[0]), "and it applies")
	_check(Global.augment_duo_active(AugmentDuos.LIGHTNING_RODS), "Lightning Rods is active")
	_check(Global.get_augment_level(&"augment_magic_missile") == 3, "a Duo adds no levels")
	_check(Global.duos_ready().is_empty(), "a taken Duo is not dealt again")
	Global.permanent_augment_ids[0] = StringName()
	_check(not Global.augment_duo_active(AugmentDuos.LIGHTNING_RODS), "a Duo sleeps while a member is unequipped")
	Global.permanent_augment_ids[0] = &"augment_magic_missile"

	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "facet", "id": "augment_tesla_aura", "grade": -1}]
	_check(not Global.apply_binding_card(Global.attempt_binding_offer[0]), "a Facet card needs a Facet")
	_check(not Global.apply_binding_card(Global.attempt_binding_offer[0], -1, &"salvo"), "and one of its own augment's")
	_check(Global.apply_binding_card(Global.attempt_binding_offer[0], -1, &"overcharge"), "Overcharge applies")
	_check(Global.augment_facet(&"augment_tesla_aura") == &"overcharge", "and is the Tesla's Facet")
	_check(not Global.facets_ready().has(&"augment_tesla_aura"), "one Facet per augment")


func _test_burden() -> void:
	_fresh([&"augment_magic_missile", StringName(), StringName()], {}, 6)
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [
		{"kind": "new", "id": "augment_tesla_aura", "grade": 0},
		{"kind": "new", "id": "augment_lucky_charm", "grade": 3},
		{"kind": "transcend", "id": "augment_magic_missile", "grade": -1},
	]
	Global.attempt_doctrine_threat_debt = 0.0
	var bag_before := _bag_count()
	_check(Global.binding_burden_available(), "a Binding with a card that can rise can be Burdened")
	var result := Global.binding_burden()
	_check(bool(result["ok"]), "the Burden applies")
	_check(int(Global.attempt_binding_offer[0]["grade"]) == 1 and int(Global.attempt_binding_offer[1]["grade"]) == 3 and int(Global.attempt_binding_offer[2]["grade"]) == -1, "every graded card rises one, Apocryphal stays, a Transcend card is untouched")
	_check(String(result["relic"]).begins_with("curse_") and _bag_count() == bag_before + 1, "a cursed relic is bound into the bag (%s)" % result["relic"])
	_check(_near(Global.attempt_doctrine_threat_debt, AugmentRites.BURDEN_THREAT), "and the district hunts you: +20 Threat debt")
	_check(not Global.binding_burden_available(), "once per Binding")
	Global.attempt_segment = 1
	Global.attempt_binding_burdened = false
	_check(not Global.binding_burden_available(), "never on the intro pick")
	_fresh([StringName(), StringName(), StringName()], {}, 6)
	Global.attempt_vouchers = [String(Vouchers.BURDEN_WRIT)]
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "new", "id": "augment_tesla_aura", "grade": 0}]
	Global.attempt_doctrine_threat_debt = 0.0
	Global.binding_burden()
	_check(_near(Global.attempt_doctrine_threat_debt, 0.0), "the Burden Writ waives the Threat")


func _bag_count() -> int:
	var count := 0
	if Global.run_bag == null:
		return 0
	for item in Global.run_bag.slots:
		if item != null:
			count += 1
	return count


func _test_corruption() -> void:
	_fresh([&"augment_tesla_aura", StringName(), StringName()], {"augment_tesla_aura": 4})
	_check(Global.can_corrupt_augment(&"augment_tesla_aura") and not Global.can_corrupt_augment(&"augment_lucky_charm"), "only an equipped augment can be corrupted")
	var result := Global.corrupt_augment(&"augment_tesla_aura")
	_check(bool(result["ok"]) and AugmentRites.OUTCOMES.has(StringName(result["outcome"])), "a Corruption deals an outcome (%s)" % result.get("outcome", ""))
	_check(Global.get_augment_level(&"augment_tesla_aura") == AugmentRites.corrupted_level(StringName(result["outcome"]), 4), "and moves the level by it")
	_check(not Global.can_corrupt_augment(&"augment_tesla_aura") and not bool(Global.corrupt_augment(&"augment_tesla_aura")["ok"]), "once per augment per run")
	# Seeded: the same attempt, augment and segment always deal the same fate.
	var first := String(result["outcome"])
	_fresh([&"augment_tesla_aura", StringName(), StringName()], {"augment_tesla_aura": 4})
	_check(String(Global.corrupt_augment(&"augment_tesla_aura")["outcome"]) == first, "a reload deals the same fate")
	var counts := {"exalted": 0, "scarred": 0, "sundered": 0}
	for i in range(3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		counts[String(AugmentRites.roll_corruption(rng, 0.0))] += 1
	_check(absf(float(counts["exalted"]) / 3000.0 - 0.45) < 0.03 and absf(float(counts["sundered"]) / 3000.0 - 0.20) < 0.03, "rolls follow 45 / 35 / 20 (%s)" % [counts])
	var stats := Stats.new()
	stats.max_hp = 200.0
	Global.attempt_augment_corruptions = {"augment_tesla_aura": "scarred"}
	Global.apply_augment_scars(stats)
	_check(_near(stats.max_hp, 180.0), "a Scarred augment worn costs 10% Max HP")
	Global.permanent_augment_ids[0] = StringName()
	stats.max_hp = 200.0
	Global.apply_augment_scars(stats)
	_check(_near(stats.max_hp, 200.0), "and nothing once it is taken off")


func _test_transfusion() -> void:
	# The Hub before segment 3 (Binding segment 2): the 40-a-level price the
	# stage scale keeps through the second Binding (follower economy audit P4).
	_fresh([&"augment_tesla_aura", StringName(), StringName()], {"augment_tesla_aura": 3, "augment_lucky_charm": 5}, 3)
	Global.owned_augment_ids.append(&"augment_lucky_charm")
	Global.set_followers(100)
	var preview := Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")
	_check(bool(preview["ok"]) and int(preview["gain"]) == 2 and int(preview["cost"]) == 80, "a Lv.5 donor offers 2 levels for 80")
	_check(not bool(Global.transfusion_preview(&"augment_lucky_charm", &"augment_tesla_aura")["ok"]), "an unequipped recipient is refused")
	_check(not bool(Global.transfusion_preview(&"augment_tesla_aura", &"augment_tesla_aura")["ok"]), "an augment cannot feed itself")
	var done := Global.transfuse_augment(&"augment_tesla_aura", &"augment_lucky_charm")
	_check(bool(done["ok"]) and Global.get_augment_level(&"augment_tesla_aura") == 5 and Global.get_augment_level(&"augment_lucky_charm") == 1, "Transfusion: Tesla 3 -> 5, the donor back to Lv.1")
	_check(Global.followers == 20, "and it cost 80 Followers")
	_check(not bool(Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")["ok"]), "a spent donor has nothing left to give")
	# Near the cap only the levels the recipient can take are paid for.
	Global.attempt_augment_levels["augment_tesla_aura"] = 19
	Global.attempt_augment_levels["augment_lucky_charm"] = 6
	Global.set_followers(1000)
	var capped := Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")
	_check(bool(capped["ok"]) and int(capped["gain"]) == 1 and int(capped["cost"]) == 40, "a Lv.19 recipient takes 1 of the donor's 3 levels and pays for 1 (%s)" % [capped])
	Global.attempt_augment_levels["augment_tesla_aura"] = 20
	_check(not bool(Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")["ok"]), "a recipient at the cap is refused, so the donor is never burned for nothing")
	Global.attempt_augment_levels["augment_tesla_aura"] = 5
	Global.attempt_augment_levels["augment_lucky_charm"] = 9
	Global.set_followers(10)
	_check(not bool(Global.transfuse_augment(&"augment_tesla_aura", &"augment_lucky_charm")["ok"]) and Global.get_augment_level(&"augment_tesla_aura") == 5, "without the Followers nothing moves")


func _test_vouchers() -> void:
	_fresh([StringName(), StringName(), StringName()], {}, 5)
	var offer := Global.voucher_offer()
	_check(offer.size() == Vouchers.OFFER_SIZE and offer == Global.voucher_offer(), "two Vouchers, dealt once per Hub visit")
	Global.attempt_segment = 6
	var next := Global.voucher_offer()
	_check(Global.attempt_voucher_segment == 6, "a new segment deals a new offer")
	Global.set_followers(0)
	_check(not Global.buy_voucher(StringName(next[0])), "a Voucher needs its price")
	Global.set_followers(10000)
	var price := Global.voucher_price()
	_check(Global.buy_voucher(StringName(next[0])) and Global.followers == 10000 - price, "a bought Voucher costs %d" % price)
	_check(not Global.buy_voucher(StringName(next[0])), "once per run")
	_check(not Global.buy_voucher(&"not_offered"), "only what is offered")

	_fresh([StringName(), StringName(), StringName()], {}, 5)
	var cards := Global.binding_card_count()
	var grades := Global.binding_grade_multiplier()
	Global.pending_augment_pick = true
	Global.attempt_binding_recasts = 0
	var recast := Global.binding_recast_cost()
	var abstain := Global.binding_abstain_reward()
	var level := Global.augment_transcend_level()
	Global.attempt_vouchers = [String(Vouchers.FOURTH_SEAL), String(Vouchers.GILDED_INK), String(Vouchers.RECAST_INDULGENCE), String(Vouchers.TITHE_SERMON), String(Vouchers.CATALYST_PRIMER), String(Vouchers.CONCORDANCE), String(Vouchers.WHETSTONE)]
	_check(Global.binding_card_count() == cards + 1, "Fourth Seal Draft deals one more card")
	_check(_near(Global.binding_grade_multiplier(), grades * 1.4), "Gilded Ink: grades x1.4")
	_check(Global.binding_recast_cost() == int(round(recast * 0.5)), "Recast Indulgence halves the Recast")
	_check(Global.binding_abstain_reward() == int(round(abstain * 1.5)), "Tithe Sermon: Abstain x1.5")
	_check(Global.augment_transcend_level() == level - 1, "Catalyst Primer: Transcend a level sooner")
	_check(Global.duo_level_required() == 2 and Global.facet_level_required() == 2, "Concordance and Whetstone: Duos and Facets from Lv.2")
	Global.set_doctrine_rule(&"augment_transcend_level", 4)
	_check(Global.augment_transcend_level() == 3, "and never below Lv.3")


func _test_grimoire() -> void:
	var saved: Array[String] = Global.grimoire_entries.duplicate()
	Global.grimoire_entries.clear()
	var heard: Array = []
	var listener := func(key: String) -> void: heard.append(key)
	Global.grimoire_discovered.connect(listener)
	_fresh([&"augment_tesla_aura", &"augment_sprint_servos", StringName()], {"augment_tesla_aura": 5})
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "transcend", "id": "augment_tesla_aura", "grade": -1}]
	Global.apply_binding_card(Global.attempt_binding_offer[0])
	_check(Global.grimoire_has(Grimoire.transcend_key(&"augment_tesla_aura")), "a Transcendence enters the Grimoire")
	_check(heard == [Grimoire.transcend_key(&"augment_tesla_aura")], "and is announced once")
	_check(not Global.grimoire_note(Grimoire.transcend_key(&"augment_tesla_aura")), "a known entry is not noted twice")
	Global.start_new_attempt()
	_check(Global.grimoire_has(Grimoire.transcend_key(&"augment_tesla_aura")), "the Grimoire survives a new attempt")
	Global.start_new_attempt()
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit"}
	Global.attempt_major_choice_taken_ids = [&"doctrine_method_open_circuit"]
	Global.pending_big_choice = true
	Global.attempt_pending_doctrine_stage = &"doctrine"
	Global.attempt_major_choice_offer_ids = [&"doctrine_choir_of_recurrence"]
	Global.apply_major_choice(&"doctrine_choir_of_recurrence")
	_check(Global.grimoire_has(Grimoire.thesis_key(&"circuit")) and not Global.grimoire_has(Grimoire.canon_key(&"circuit")), "a second circuit plate writes the Circuit Thesis")
	Global.grimoire_discovered.disconnect(listener)
	Global.grimoire_entries = saved


func _test_save() -> void:
	_fresh([&"augment_tesla_aura", StringName(), StringName()], {})
	Global.attempt_active = true
	Global.attempt_augment_duos = {"duo_slipstream_coil": true}
	Global.attempt_augment_facets = {"augment_tesla_aura": "static_field"}
	Global.attempt_augment_corruptions = {"augment_tesla_aura": "scarred"}
	Global.attempt_binding_burdened = true
	Global.attempt_vouchers = ["gilded_ink"]
	Global.attempt_voucher_offer = ["gilded_ink", "whetstone"]
	Global.attempt_voucher_segment = 5
	var saved_grimoire: Array[String] = Global.grimoire_entries.duplicate()
	Global.grimoire_entries = ["duo:duo_slipstream_coil"]
	var save := SaveData.new()
	Global.write_save(save)
	Global.attempt_augment_duos = {}
	Global.attempt_augment_facets = {}
	Global.attempt_augment_corruptions = {}
	Global.attempt_binding_burdened = false
	Global.attempt_vouchers = []
	Global.attempt_voucher_offer = []
	Global.attempt_voucher_segment = 0
	Global.grimoire_entries = []
	Global.apply_save(save)
	_check(Global.attempt_augment_duos.has("duo_slipstream_coil") and Global.augment_facet(&"augment_tesla_aura") == &"static_field" and Global.augment_corruption(&"augment_tesla_aura") == AugmentRites.SCARRED, "Duos, Facets and Corruptions survive a reload")
	_check(Global.attempt_binding_burdened and Global.has_voucher(Vouchers.GILDED_INK) and Global.attempt_voucher_offer.size() == 2 and Global.attempt_voucher_segment == 5, "so do the Burden, the Vouchers and their offer")
	_check(Global.grimoire_has("duo:duo_slipstream_coil"), "and the Grimoire")
	Global.attempt_active = false
	var idle := SaveData.new()
	Global.write_save(idle)
	_check(idle.attempt_augment_duos.is_empty() and idle.attempt_vouchers.is_empty() and idle.meta_grimoire.has("duo:duo_slipstream_coil"), "with no attempt the run state is cleared but the Grimoire is kept")
	var old := SaveData.new()
	_check(old.attempt_augment_duos.is_empty() and old.meta_grimoire.is_empty() and old.attempt_voucher_segment == 0, "an older save loads the new fields as empty")
	Global.grimoire_entries = saved_grimoire


# Findings of the cross-cutting review, each pinned so it cannot return.
func _test_review_fixes() -> void:
	# A Corruption's levels never pour on: equipping a spare from the meta
	# library, corrupting it at Lv.1 (where Sundered costs nothing) and
	# draining it took a main augment to Lv.18-20 at the first Hub visit.
	_fresh([&"augment_tesla_aura", &"augment_lucky_charm", StringName()], {"augment_tesla_aura": 2, "augment_lucky_charm": 1})
	Global.set_followers(5000)
	Global.corrupt_augment(&"augment_lucky_charm")
	Global.permanent_augment_ids[1] = StringName()
	var poured := Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")
	_check(not bool(poured["ok"]) and String(poured["reason"]).contains("corrupted"), "a corrupted augment cannot be a donor (%s)" % poured["reason"])

	# A Burden lasts the whole Binding: a Recast deals the new table raised.
	_fresh([&"augment_magic_missile", StringName(), StringName()], {}, 6)
	Global.set_followers(5000)
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = []
	var plain_grades := _grades(Global.binding_offer())
	Global.binding_burden()
	Global.binding_recast()
	var recast := Global.binding_offer()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Global.attempt_world_seed) ^ (Global.binding_segment() * 0x2545F491) ^ (2 * 0x9E3779B9) ^ 0xB1D
	var unraised := _grades(AugmentBinding.build_offer(Global.binding_context(), rng))
	var raised_all := not unraised.is_empty()
	for i in range(mini(unraised.size(), recast.size())):
		if int(recast[i]["grade"]) >= 0 and int(recast[i]["grade"]) != mini(unraised[i] + 1, AugmentScaling.GRADE_COUNT - 1):
			raised_all = false
	_check(raised_all, "a Recast after a Burden deals the new table raised too (%s from %s; first deal %s)" % [_grades(recast), unraised, plain_grades])

	# The relic is bound into the run's bag, or the Burden is not offered.
	_fresh([StringName(), StringName(), StringName()], {}, 6)
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = [{"kind": "new", "id": "augment_tesla_aura", "grade": 0}]
	# Distinct items (and polarities) so the bag's auto-consolidation cannot
	# merge two of them and free a place.
	var item_ids: Array = Global.item_db.keys()
	item_ids.sort()
	for slot in range(Global.run_bag.get_slot_count()):
		var data := Global.item_db[item_ids[slot % item_ids.size()]] as ItemData
		var polarity := ItemInstance.Polarity.POS if floori(slot / float(item_ids.size())) % 2 == 0 else ItemInstance.Polarity.NEG
		Global.run_bag.set_at(slot, ItemInstance.from_roll(data, 1, polarity, 0.5, false))
	_check(not Global.binding_burden_has_room() and not Global.binding_burden_available(), "with a full bag the Burden is not offered, so the relic never leaves the run")
	var stash_before := _stash_count()
	_check(not bool(Global.binding_burden()["ok"]) and _stash_count() == stash_before, "and nothing reaches the profile stash")
	Global.run_bag.set_at(0, null)
	_check(Global.binding_burden_available(), "one free place is enough")
	var bound := Global.binding_burden()
	_check(String(bound["relic"]).begins_with("curse_") and Global.run_bag.get_at(0) != null and String(Global.run_bag.get_at(0).data.id) == String(bound["relic"]), "and the relic lands in it")

	# Loaded Dice recruits only with an enemy near enough to witness.
	_fresh([&"augment_lucky_charm", &"augment_gamblers_rite", StringName()], {})
	Global.attempt_augment_duos = {String(AugmentDuos.LOADED_DICE): true}
	Global.set_followers(0)
	Global.on_lucky_crit(Vector2(90000, 90000))
	_check(Global.followers == 0, "a lucky crit swung at empty air recruits nobody")
	var witness: int = EnemyWorld.create_enemy(preload("res://core/systems/enemy_world/EnemySpawnState.gd").new(&"dice_witness", "res://dice_witness.tscn", Vector2(90100, 90000), 50.0, 0.0, 4.0, 0))
	Global.on_lucky_crit(Vector2(90000, 90000))
	_check(Global.followers == 1, "one with an enemy near recruits a Follower")
	EnemyWorld.remove_enemy(witness, &"reliquary_core_test")

	# A loaded run teaches the Grimoire what it already holds.
	var saved_grimoire: Array[String] = Global.grimoire_entries.duplicate()
	_fresh([&"augment_tesla_aura", StringName(), StringName()], {})
	Global.attempt_active = true
	Global.attempt_augment_transcended = {"augment_tesla_aura": true}
	Global.attempt_augment_facets = {"augment_tesla_aura": "overcharge"}
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_choir_of_recurrence"}
	var save := SaveData.new()
	Global.write_save(save)
	save.meta_grimoire = []
	Global.apply_save(save)
	_check(Global.grimoire_has(Grimoire.transcend_key(&"augment_tesla_aura")) and Global.grimoire_has(Grimoire.facet_key(&"augment_tesla_aura", &"overcharge")) and Global.grimoire_has(Grimoire.thesis_key(&"circuit")), "a run saved before the Grimoire fills it on load")
	Global.attempt_active = false
	Global.grimoire_entries = saved_grimoire


func _grades(offer: Array) -> Array:
	var out: Array = []
	for card in offer:
		out.append(int(card.get("grade", -1)))
	return out


func _stash_count() -> int:
	if Global.meta_stash == null:
		return 0
	var count := 0
	for item in Global.meta_stash.slots:
		if item != null:
			count += 1
	return count
