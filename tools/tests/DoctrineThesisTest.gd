extends Node

# Theses (docs/design/2026-10-03-bindings-and-theses.md §6): eighteen
# Doctrine plates, two per role per stage, drawn by weight; Apocrypha stages
# after segment 9; the Thesis and Canon of each family; every new plate's
# rule on the system that reads it (the Binding, the stat pass, the tree's
# ledger and runner, the kill path, the augment runner).
#
# Run: <godot> --headless --path . res://tools/tests/DoctrineThesisTest.tscn

const CONTEXT_SCRIPT := preload("res://core/systems/major_choice/MajorChoiceContext.gd")

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
	Global.start_new_attempt()
	_test_content()
	_test_weighted_offer()
	_test_apocrypha()
	_test_families()
	_test_buffed_plates()
	_test_new_plates()
	_test_tree_hooks()
	print("DoctrineThesisTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _complete() -> Array[MajorChoiceDef]:
	var out: Array[MajorChoiceDef] = []
	for definition in Global.major_choice_db.defs:
		if definition != null and definition.is_doctrine_complete():
			out.append(definition)
	return out


func _test_content() -> void:
	var plates := _complete()
	_check(plates.size() == 18, "eighteen complete Doctrine plates (%d)" % plates.size())
	var grid := {}
	for definition in plates:
		var key := "%s/%s" % [definition.stage, definition.offer_role]
		grid[key] = int(grid.get(key, 0)) + 1
	var even := grid.size() == 9
	for key in grid:
		if int(grid[key]) != 2:
			even = false
	_check(even, "two plates for every stage and role (%s)" % [grid])
	var families_follow_roles := true
	for definition in plates:
		var expected: StringName = {&"amplify": &"circuit", &"transfigure": &"vessel", &"covenant": &"archive"}[definition.offer_role]
		if definition.family_id != expected:
			families_follow_roles = false
	_check(families_follow_roles, "each role keeps its family: amplify/circuit, transfigure/vessel, covenant/archive")


func _context(stage: StringName, tags: Dictionary = {}) -> RefCounted:
	var context: RefCounted = CONTEXT_SCRIPT.new()
	context.set("stage_id", stage)
	context.set("tags", tags)
	return context


func _test_weighted_offer() -> void:
	var seen := {}
	var rng := RandomNumberGenerator.new()
	for i in range(200):
		rng.seed = 7000 + i
		var offer := Global.major_choice_db.build_stage_offer(_context(&"method"), [], rng)
		if offer.size() != 3:
			_check(false, "a Method offer deals three plates")
			return
		for definition in offer:
			seen[definition.id] = true
	_check(seen.size() == 6, "over many runs every Method plate appears (%d of 6)" % seen.size())
	var tagged := 0
	for i in range(1000):
		rng.seed = 9000 + i
		var offer := Global.major_choice_db.build_stage_offer(_context(&"method", {&"active_augment": true}), [], rng)
		if offer[0].build_tags.has(&"active_augment") and offer[0].id == &"doctrine_method_twin_seal_protocol":
			tagged += 1
	# Open Circuit and Twin Seal both carry the tag, so the draw is even there;
	# the weight shows against an untagged plate instead.
	var both_tagged := tagged > 350 and tagged < 650
	_check(both_tagged, "two plates with the build's tag share the draw (%d of 1000)" % tagged)
	var db := MajorChoiceDB.new()
	db.defs.append(_synthetic(&"plain", []))
	db.defs.append(_synthetic(&"tagged", [&"active_augment"]))
	var wins := 0
	for i in range(1000):
		rng.seed = 11000 + i
		var offer := db.build_stage_offer(_context(&"method", {&"active_augment": true}), [], rng)
		if offer.size() == 1 and offer[0].id == &"tagged":
			wins += 1
	_check(wins > 600 and wins < 730, "a matching tag makes a plate about twice as likely, never certain (%d of 1000)" % wins)
	var taken_offer := Global.major_choice_db.build_stage_offer(_context(&"method"), [&"doctrine_method_open_circuit"], rng)
	_check(taken_offer[0].id == &"doctrine_method_twin_seal_protocol", "a taken plate leaves its role's other plate")


func _synthetic(id: StringName, tags: Array[StringName]) -> MajorChoiceDef:
	var definition := MajorChoiceDef.new()
	definition.id = id
	definition.title = String(id)
	definition.stage = &"method"
	definition.offer_role = &"amplify"
	definition.family_id = &"circuit"
	definition.gift_text = "Gift"
	definition.price_text = "Price"
	definition.consequence_text = "Consequence"
	definition.build_tags = tags
	return definition


func _test_apocrypha() -> void:
	_check(Global.doctrine_stage_for_completed_segment(10) == &"" and Global.doctrine_stage_for_completed_segment(11) == &"", "segments 10 and 11 have no Doctrine")
	_check(Global.doctrine_stage_for_completed_segment(12) == &"apocrypha_12" and Global.doctrine_stage_for_completed_segment(15) == &"apocrypha_15", "the Doctrine returns at 12, 15, ... as Apocrypha")
	var taken: Array = []
	for definition in _complete():
		if definition.stage == &"method" or definition.stage == &"doctrine":
			taken.append(definition.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var offer := Global.major_choice_db.build_stage_offer(_context(&"apocrypha_12"), taken, rng)
	_check(offer.size() == 3, "an Apocrypha deals one plate per role")
	var all_apotheosis := true
	for definition in offer:
		if definition.stage != &"apotheosis":
			all_apotheosis = false
	_check(all_apotheosis, "drawn from every stage's untaken plates (only Apotheosis plates were left)")

	Global.start_new_attempt()
	Global.attempt_segment = 12
	Global.on_segment_completed(12)
	_check(Global.pending_big_choice and Global.attempt_pending_doctrine_stage == &"apocrypha_12", "completing segment 12 queues an Apocrypha")
	var plates: Array = Global.get_major_choice_offer(3)
	_check(plates.size() == 3, "its offer has three plates")
	_check(plates.size() > 0 and Global.apply_major_choice((plates[0] as MajorChoiceDef).id), "and any stage's plate can be inscribed there")
	_check(Global.attempt_doctrine_stage_ids.has("apocrypha_12"), "the Apocrypha is recorded under its own stage")

	Global.start_new_attempt()
	for definition in _complete():
		Global.attempt_major_choice_taken_ids.append(definition.id)
	_check(not Global.doctrine_stage_has_plates(&"apocrypha_15"), "with every plate taken, nothing is left to show")
	Global.on_segment_completed(15)
	_check(not Global.pending_big_choice, "so no stage opens an empty screen that would hold the Hub forever")
	Global.start_new_attempt()


func _inscribe(stages: Dictionary) -> void:
	Global.attempt_doctrine_stage_ids = stages


func _test_families() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 5
	_inscribe({"method": "doctrine_method_open_circuit"})
	_check(not Global.doctrine_has_thesis(&"circuit"), "one plate is not a Thesis")
	_inscribe({"method": "doctrine_method_open_circuit", "doctrine": "doctrine_liturgy_of_overclock"})
	_check(Global.doctrine_has_thesis(&"circuit") and not Global.doctrine_has_canon(&"circuit"), "two circuit plates inscribe its Thesis")
	_check(Global.binding_card_count() == 4, "the Circuit Thesis deals a fourth Binding card")
	_inscribe({"method": "doctrine_method_open_circuit", "doctrine": "doctrine_liturgy_of_overclock", "apotheosis": "doctrine_apotheosis_the_engine_prays"})
	_check(Global.doctrine_has_canon(&"circuit"), "three inscribe its Canon")
	_check(bool(Global.augment_catalyst_context()["waive"]), "the Circuit Canon waives every catalyst")

	_inscribe({"method": "doctrine_method_frame_of_ash", "doctrine": "doctrine_iron_liturgy"})
	var stats := Stats.new()
	Global.attempt_stat_delta = null
	Global.apply_attempt_modifiers_to_stats(stats)
	_check(_near(stats.power, 0.15), "the Vessel Thesis is +15% Power")
	_inscribe({"method": "doctrine_method_frame_of_ash", "doctrine": "doctrine_iron_liturgy", "apotheosis": "doctrine_apotheosis_second_revelation"})
	stats = Stats.new()
	Global.apply_attempt_modifiers_to_stats(stats)
	_check(_near(stats.power, 0.40), "the Vessel Canon adds +25% more")
	Global.set_doctrine_rule(&"max_hp_mul", 0.6)
	_check(_near(Global.doctrine_max_hp_multiplier(), 0.8), "and moves a Max HP price halfway back to 1 (0.6 -> 0.8)")
	Global.set_doctrine_rule(&"max_hp_mul", 1.3)
	_check(_near(Global.doctrine_max_hp_multiplier(), 1.3), "a Max HP gift is left alone")
	Global.attempt_doctrine_rules = {}

	_inscribe({"method": "doctrine_method_black_archive", "doctrine": "doctrine_tithe_ledger"})
	_check(_near(Global.binding_grade_multiplier(), 1.5) and Global.binding_free_recasts() == 1, "the Archive Thesis: grades x1.5 and one free Recast")
	_inscribe({"method": "doctrine_method_black_archive", "doctrine": "doctrine_tithe_ledger", "apotheosis": "doctrine_apotheosis_mass_conversion"})
	_check(Global.binding_grade_floor() == 1, "the Archive Canon deals nothing below Gilded")
	_check(Global.binding_abstain_reward() == AugmentScaling.abstain_reward(4) * 2, "and pays Abstain double")
	_check(DoctrineFamilies.plate_line(&"archive", 1).contains("THESIS NEXT") and DoctrineFamilies.awakening_line(&"archive", 1).contains("ARCHIVE THESIS"), "a plate tells what inscribing it would awaken")
	_check(DoctrineFamilies.plate_line(&"archive", 2).contains("CANON NEXT") and DoctrineFamilies.awakening_line(&"archive", 2).contains("ARCHIVE CANON"), "including the Canon")
	_check(DoctrineFamilies.awakening_line(&"archive", 0) == "" and DoctrineFamilies.awakening_line(&"archive", 3) == "", "and nothing when inscribing awakens nothing new")
	_inscribe({})


func _apply(id: StringName) -> void:
	var definition: MajorChoiceDef = Global.major_choice_db.get_def(id)
	_check(definition != null and definition.is_doctrine_complete(), "%s loads complete" % String(id))
	if definition == null:
		return
	for effect in definition.effects:
		if effect != null:
			effect.apply(Global)


func _reset_rules() -> void:
	Global.attempt_doctrine_rules = {}
	Global.attempt_stat_delta = null
	Global.attempt_mutations = {}
	Global.attempt_augment_transcended = {}
	Global.attempt_doctrine_stage_ids = {}


func _test_buffed_plates() -> void:
	_reset_rules()
	_apply(&"doctrine_method_open_circuit")
	_check(_near(Global.doctrine_active_cooldown(10.0), 6.0), "Open Circuit: active cooldowns x0.6")
	_check(Global.binding_card_count() == 4, "and a fourth Binding card")
	_reset_rules()
	_apply(&"doctrine_method_black_archive")
	_check(_near(float(Global.get_doctrine_rule(&"threat_gain_mul", 1.0)), 1.25), "Black Archive: Threat x1.25")
	_check(_near(Global.binding_grade_multiplier(), 1.6), "and Binding grades x1.6")
	_apply(&"doctrine_apotheosis_mass_conversion")
	_check(_near(float(Global.get_doctrine_rule(&"threat_gain_mul", 1.0)), 1.5625), "Mass Conversion's Threat price multiplies with it (1.5625), it no longer overwrites")
	_reset_rules()
	_apply(&"doctrine_choir_of_recurrence")
	_check(_near(Global.augment_damage_multiplier(), 1.25), "Choir of Recurrence: augment damage +25%")
	_reset_rules()
	_apply(&"doctrine_vessel_without_mercy")
	_check(_near(Global.doctrine_max_hp_multiplier(), 1.3), "Vessel Without Mercy: +30% Max HP")
	_reset_rules()
	_apply(&"doctrine_pilgrim_engine")
	_check(Global.binding_free_recasts() == 1, "Pilgrim Engine: one free Recast per Binding")
	_reset_rules()
	_apply(&"doctrine_apotheosis_perfected_engine")
	_check(Global.augment_transcend_level() == 4, "Perfected Engine: augments Transcend at Lv.4")
	_reset_rules()


func _test_new_plates() -> void:
	Global.permanent_augment_ids = [&"augment_tesla_aura", &"augment_magic_missile", StringName()]
	Global.attempt_augment_levels = {"augment_tesla_aura": 2, "augment_magic_missile": 4}
	_apply(&"doctrine_method_twin_seal_protocol")
	_check(Global.get_augment_level(&"augment_magic_missile") == 7 and Global.get_augment_level(&"augment_tesla_aura") == 2, "Twin Seal: the highest-level augment gains 3 (4 -> 7), the other none")
	_check(_near(Global.augment_damage_multiplier(), 1.25), "and augment damage +25%")
	Global.attempt_segment = 4
	Global.attempt_binding_recasts = 0
	_check(Global.binding_recast_cost() == AugmentScaling.recast_cost(3, 0) * 2, "its price: Recast costs double")
	_reset_rules()

	Global.selected_style_id = &"melee"
	_apply(&"doctrine_method_second_hand")
	_check(Global.has_mutation(&"mut_melee_dual_slash"), "Second Hand gives a melee run Twin Cut")
	_check(Global.attempt_stat_delta != null and _near(Global.attempt_stat_delta.haste, -0.1), "for -10% Haste")
	_reset_rules()
	Global.selected_style_id = &"magic"
	_apply(&"doctrine_method_second_hand")
	_check(Global.has_mutation(&"mut_magic_trisigil") and not Global.has_mutation(&"mut_melee_dual_slash"), "and a magic run the Tri-Sigil")
	_reset_rules()
	Global.selected_style_id = &"ranged"

	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	_apply(&"doctrine_method_census_of_souls")
	Global.set_followers(2500)
	_check(_near(Global.follower_belief_power(), 0.40), "Census of Souls: belief reaches +40% (at 2,500 Followers)")
	Global.attempt_segment = 3
	Global.attempt_deaths_this_segment = 0
	Global.set_followers(1000)
	_check(Global.reconstruction_cost_for(1000) == 300, "its price: reconstruction costs 1.5x (200 -> 300)")
	Global._rng.seed = 5
	var extra := 0
	for i in range(4000):
		extra += Global.bonus_kill_followers()
	_check(absf(float(extra) / 4000.0 - 0.08) < 0.015, "kills recruit one more 8%% of the time (%.3f)" % (float(extra) / 4000.0))
	Global.set_followers(0)
	_reset_rules()

	Global.permanent_augment_ids = [&"augment_tesla_aura", StringName(), StringName()]
	Global.attempt_augment_levels = {"augment_tesla_aura": 3}
	_apply(&"doctrine_liturgy_of_overclock")
	_check(Global.get_augment_level(&"augment_tesla_aura") == 4, "Liturgy of Overclock: +1 level")
	_check(Global.augment_transcend_ready(&"augment_tesla_aura"), "and Lv.4 Transcends with no catalyst")
	_check(Global.binding_abstain_reward() == 0, "its price: Abstain pays nothing")
	_reset_rules()

	_apply(&"doctrine_tithe_ledger")
	var ledger := Global.ascension_ledger()
	_check(_near(ledger.price_multiplier, 0.75), "Tithe Ledger: the tree's prices x0.75")
	_check(ledger.scaled_price(400) == 300 and ledger.scaled_price(1) == 1 and ledger.scaled_price(0) == 0, "400 -> 300; a discount never makes a node free")
	_check(Global.ascension_refunds_forfeit(), "its price: refunds return nothing")
	Global.ascension_refund_context_hub = true
	_check(Global.ascension_refund("anything") == 0, "the Hub refund pays nothing")
	Global.ascension_refund_context_hub = false
	_reset_rules()
	_check(_near(Global.ascension_ledger().price_multiplier, 1.0), "and the prices return when the rule is gone")

	Global.permanent_augment_ids = [&"augment_tesla_aura", &"augment_lucky_charm", StringName()]
	Global.attempt_augment_levels = {}
	_apply(&"doctrine_apotheosis_the_engine_prays")
	_check(Global.is_augment_transcended(&"augment_tesla_aura") and Global.is_augment_transcended(&"augment_lucky_charm"), "The Engine Prays Transcends every equipped augment at Lv.1")
	_check(_near(Global.augment_damage_multiplier(), 1.5) and _near(float(Global.get_doctrine_rule(&"native_damage_mul", 1.0)), 0.75), "augment damage +50%, native weapon x0.75")
	_reset_rules()

	_apply(&"doctrine_apotheosis_second_revelation")
	_check(_near(float(Global.get_doctrine_rule(&"revelation_charge_mul", 1.0)), 3.0) and _near(Global.doctrine_max_hp_multiplier(), 0.75), "Second Revelation: charge x3 for -25% Max HP")
	_reset_rules()

	_apply(&"doctrine_apotheosis_mass_conversion")
	var runner := AugmentRunner.new()
	add_child(runner)
	Global.permanent_augment_ids = [&"augment_tesla_aura", StringName(), StringName()]
	Global.attempt_augment_levels = {"augment_tesla_aura": 2}
	Global.set_followers(0)
	_check(runner.mass_conversion() == &"augment_tesla_aura", "Mass Conversion raises an equipped augment")
	_check(Global.get_augment_level(&"augment_tesla_aura") == 3 and Global.followers == AugmentRunner.MASS_CONVERSION_FOLLOWERS, "by one level, and pays 40 Followers")
	_check(runner.mass_conversion() == StringName(), "at most once every 20 seconds")
	runner._process(AugmentRunner.MASS_CONVERSION_GAP)
	_check(runner.mass_conversion() == &"augment_tesla_aura", "and again once the gap has passed")
	runner.queue_free()
	Global.set_followers(0)
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.attempt_augment_levels = {}
	_reset_rules()


func _test_tree_hooks() -> void:
	var runner := AscensionRunner.new()
	_check(_near(runner._recovery(10.0), 10.0), "Q recovery is untouched without the Doctrine")
	_apply(&"doctrine_iron_liturgy")
	_check(_near(runner._recovery(10.0), 6.0), "Iron Liturgy: Q recovery x0.6")
	_check(_near(Global.doctrine_max_hp_multiplier(), 0.8), "for -20% Max HP")
	_reset_rules()
	runner.v_charge = 0.0
	runner._gain_charge(10.0)
	_check(_near(runner.v_charge, 10.0), "Revelation charge as authored")
	_apply(&"doctrine_apotheosis_second_revelation")
	runner.v_charge = 0.0
	runner._gain_charge(10.0)
	_check(_near(runner.v_charge, 30.0), "Second Revelation: every source charges x3")
	_reset_rules()
	runner.free()
