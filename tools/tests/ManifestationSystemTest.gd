extends Node

# Pins the Manifestation layer: the curated library's shape, the roll, and -
# most importantly - the merge invariants. A Manifestation is item IDENTITY,
# so the failure mode that matters is not "the effect is weak", it is "the
# run's most interesting item was silently dissolved by a tidy-up pass".
#
# Run: <godot> --headless --path . res://tools/tests/ManifestationSystemTest.tscn

const BagInventoryScript = preload("res://data/items/BagInventory.gd")

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
	_test_catalog_integrity()
	_test_tag_model()
	_test_noun_display_registry()
	_test_prerequisite_weighting()
	_test_engine_density_floor()
	_test_median_run_is_legible()
	_test_slot_pools()
	_test_roll_respects_slot_and_chance()
	_test_describe_is_detached_safe()
	_test_identity_survives_merge()
	_test_identity_survives_auto_swap_merge()
	_test_a_deliberate_merge_keeps_the_destination_rule()
	_test_plain_material_still_feeds_a_manifested_item()
	_test_fabricated_material_never_rolls()
	_test_snapshot_copy_preserves_identity()
	_test_equipped_feed_declines_conflicting_rule()
	_test_bag_consolidation_keeps_rules_apart()
	_test_shared_state_gating()
	_test_shared_nouns_are_shared()
	_test_dash_hook()
	_test_identity_survives_a_save_round_trip()
	_test_tooltip_renders_the_rule()
	print("ManifestationSystemTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _make_instance(data: ItemData, rarity: int, roll: float, manifestation: StringName) -> ItemInstance:
	var inst := ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.POS, roll, false)
	inst.manifestation_id = manifestation
	return inst


func _first_two_ids_for_slot(slot: int) -> Array:
	var pool := ManifestationCatalog.pool_for_slot(slot)
	var out: Array = []
	for def in pool:
		out.append(def.id)
		if out.size() >= 2:
			break
	return out


# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

func _test_catalog_integrity() -> void:
	var ids: Array = ManifestationCatalog.all_ids()
	_check(ids.size() >= 12, "catalog holds a prototype-sized library (%d rules)" % ids.size())

	var seen_families: Dictionary = {}
	var complete := true
	var logic_ok := true
	var slots_ok := true
	for id_value in ids:
		var def := ManifestationCatalog.get_def(id_value)
		if def == null or String(def.display_name).strip_edges() == "" or String(def.rule).strip_edges() == "":
			complete = false
			continue
		if def.logic == null:
			logic_ok = false
			continue
		var probe: Object = def.logic.new()
		if probe is ManifestationEffect:
			(probe as Node).free()
		else:
			logic_ok = false
			if probe is Node:
				(probe as Node).free()
		if def.slots.is_empty():
			slots_ok = false
		for slot in def.slots:
			if slot < 0 or slot >= Inventory.SLOT_COUNT:
				slots_ok = false
		if def.tags.is_empty():
			complete = false
		for tag in def.tags:
			seen_families[tag] = int(seen_families.get(tag, 0)) + 1

	_check(complete, "every rule has a display name and an authored rule line")
	_check(logic_ok, "every rule's logic script is a ManifestationEffect")
	_check(slots_ok, "every rule declares at least one valid equip slot")

	# Shared mechanics are the point: a family nobody else touches cannot
	# produce the accidental non-set builds the design is built around.
	var shared_families := 0
	for family in seen_families.keys():
		if int(seen_families[family]) >= 2:
			shared_families += 1
	_check(shared_families >= 2, "at least two families are shared by several rules (%d)" % shared_families)


## The tag model's own guarantees. A `family` StringName that nothing read was
## how this layer shipped claiming twelve families while only two of them
## existed at runtime; these assertions are what stop that recurring.
func _test_tag_model() -> void:
	var every_rule_tagged := true
	var every_tag_registered := true
	var untagged: PackedStringArray = PackedStringArray()
	var unknown: PackedStringArray = PackedStringArray()

	for id_value in ManifestationCatalog.all_ids():
		var def := ManifestationCatalog.get_def(id_value)
		if def == null:
			continue
		if def.tags.is_empty():
			every_rule_tagged = false
			untagged.append(String(id_value))
		for tag in def.tags:
			if not ManifestationState.NOUNS.has(tag):
				every_tag_registered = false
				unknown.append("%s:%s" % [String(id_value), String(tag)])

	_check(every_rule_tagged, "every rule declares at least one noun (%s)" % ", ".join(untagged))
	_check(every_tag_registered, "every declared noun is registered (%s)" % ", ".join(unknown))

	# A noun with one member can never combine with anything. That is the exact
	# failure this restructure exists to remove, so it is asserted rather than
	# left to review.
	var thin: PackedStringArray = PackedStringArray()
	for noun in ManifestationState.NOUNS:
		var members := ManifestationCatalog.rules_with_tag(noun)
		if members.size() < 2:
			thin.append("%s(%d)" % [String(noun), members.size()])
	_check(thin.is_empty(), "every noun has at least two member rules (thin: %s)" % ", ".join(thin))

	# Source-level heuristic, and honest about being one: a tag is only real if
	# the rule actually touches that noun. A behavioural proof would mean
	# driving sixteen bespoke rules; this catches the case that matters, which
	# is a tag added to the catalog with no wiring behind it at all.
	var unwired: PackedStringArray = PackedStringArray()
	for id_value in ManifestationCatalog.all_ids():
		var def := ManifestationCatalog.get_def(id_value)
		if def == null or def.logic == null:
			continue
		var source: String = def.logic.source_code
		for tag in def.tags:
			if not _source_mentions_noun(source, tag):
				unwired.append("%s:%s" % [String(id_value), String(tag)])
	_check(unwired.is_empty(), "every declared noun is referenced by its rule (%s)" % ", ".join(unwired))


## The accessor vocabulary each noun is reached through, so the heuristic above
## recognises a rule that uses the noun without naming it literally.
func _source_mentions_noun(source: String, noun: StringName) -> bool:
	var words: PackedStringArray = PackedStringArray([String(noun)])
	match noun:
		&"momentum":
			words.append_array(["stability", "distance_since_stop", "still_time", "is_moving"])
		&"shard":
			words.append_array(["shard", "mark", "orbit"])
		&"fortune":
			words.append_array(["misfortune", "lucky", "follower", "luck"])
		&"cadence":
			words.append_array(["attack_index", "time_since_attack", "consume_attack_bonus", "on_attack"])
		&"ward":
			words.append_array(["hp_fraction", "evasion", "on_damage_taken", "on_evaded", "on_healed"])
	for word in words:
		if source.containsn(word):
			return true
	return false


## The palette is the player-facing half of the noun model, and a noun with no
## registry entry falls back to a colourless grey that reads as "no noun" - a
## silent failure with no crash and no test to catch it. Hence this.
func _test_noun_display_registry() -> void:
	var every_noun_has_display := true
	var missing: PackedStringArray = PackedStringArray()
	for noun in ManifestationState.NOUNS:
		if not ManifestationNouns.known(noun):
			every_noun_has_display = false
			missing.append(String(noun))
	_check(every_noun_has_display, "every noun has a display entry (%s)" % ", ".join(missing))

	var order_matches: bool = ManifestationNouns.ORDER.size() == ManifestationState.NOUNS.size()
	for noun in ManifestationNouns.ORDER:
		if not ManifestationState.NOUNS.has(noun):
			order_matches = false
	_check(order_matches, "the authored display order covers exactly the registered nouns")

	# Every overlay blends additively, which washes toward white, so two nouns
	# separated only by lightness become one colour the moment they overlap.
	# Assert on HUE distance rather than on the raw Color.
	var hues_separate := true
	var collisions: PackedStringArray = PackedStringArray()
	var nouns: Array = ManifestationNouns.ORDER
	for i in range(nouns.size()):
		for j in range(i + 1, nouns.size()):
			var a: float = ManifestationNouns.colour(nouns[i]).h * 360.0
			var b: float = ManifestationNouns.colour(nouns[j]).h * 360.0
			var apart: float = absf(a - b)
			apart = minf(apart, 360.0 - apart)
			if apart < 12.0:
				hues_separate = false
				collisions.append("%s/%s %.0f deg" % [String(nouns[i]), String(nouns[j]), apart])
	_check(hues_separate, "no two nouns share a hue (%s)" % ", ".join(collisions))

	# Every noun the counter can display needs a number to display.
	var every_noun_has_headline := true
	for noun in ManifestationState.NOUNS:
		if ManifestationState.headline_channel(noun) == &"":
			every_noun_has_headline = false
	_check(every_noun_has_headline, "every noun resolves a headline channel for the HUD counter")


func _test_prerequisite_weighting() -> void:
	var ring := _make_data("test_bond", ManifestationCatalog.SLOT_RING)
	var rng := RandomNumberGenerator.new()

	# An empty loadout must roll exactly as it did before the weighting existed.
	var sample := 4000
	rng.seed = 424242
	var cold: Dictionary = {}
	for _i in range(sample):
		var id := ManifestationCatalog.roll_for(ring, ItemInstance.Polarity.POS, 0.0, rng)
		if id != &"":
			cold[id] = int(cold.get(id, 0)) + 1

	# Now hold both nouns of one specific rule and roll again.
	var target := &"pilgrims_momentum"
	var target_def := ManifestationCatalog.get_def(target)
	_check(target_def != null and target_def.tags.size() == 2, "the weighting fixture is a two-noun rule")
	if target_def == null:
		return
	var held: Dictionary = {}
	for tag in target_def.tags:
		held[tag] = 1

	rng.seed = 424242
	var warm: Dictionary = {}
	for _i in range(sample):
		var id := ManifestationCatalog.roll_for(ring, ItemInstance.Polarity.POS, 0.0, rng, held)
		if id != &"":
			warm[id] = int(warm.get(id, 0)) + 1

	var before: int = int(cold.get(target, 0))
	var after: int = int(warm.get(target, 0))
	_check(
		after > before,
		"holding a rule's nouns makes it likelier to roll (%d -> %d)" % [before, after]
	)
	_check(
		is_equal_approx(ManifestationCatalog.bond_multiplier(target_def, {}), 1.0),
		"an empty loadout leaves every weight untouched"
	)
	var one: Dictionary = {target_def.tags[0]: 1}
	_check(
		ManifestationCatalog.bond_multiplier(target_def, one)
		< ManifestationCatalog.bond_multiplier(target_def, held),
		"holding both nouns pulls harder than holding one"
	)


## Aggregate backstop. NOT the primary protection: P(engine) saturates, so one
## untagged rule moves it only ~2 points and a floor tight enough to catch that
## would trip on any legitimate weight tuning. _test_tag_model() is what catches
## an untagged rule; this catches collective drift the structure cannot see -
## pool composition, weights, slot chances, each individually legal.
##
## Convention: an engine is two rules claiming the SAME noun, counting two
## copies of one rule as sharing, because two Vector Halos genuinely do share
## one orbit. Seeded, so it is deterministic rather than flaky.
func _test_engine_density_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260824
	var runs := 20000
	var engines := 0
	var triples := 0
	var shared_pairs_total := 0

	var slot_data: Array[ItemData] = []
	for slot in range(Inventory.SLOT_COUNT):
		slot_data.append(_make_data("density_%d" % slot, slot))

	for _run in range(runs):
		var held: Dictionary = {}
		for slot in range(Inventory.SLOT_COUNT):
			var id := ManifestationCatalog.roll_for(
				slot_data[slot], ItemInstance.Polarity.POS, 0.0, rng, held
			)
			if id == &"":
				continue
			var def := ManifestationCatalog.get_def(id)
			if def == null:
				continue
			for tag in def.tags:
				held[tag] = int(held.get(tag, 0)) + 1
		var best := 0
		for count in held.values():
			best = maxi(best, int(count))
			if int(count) >= 2:
				shared_pairs_total += int(count) - 1
		if best >= 2:
			engines += 1
		if best >= 3:
			triples += 1

	var engine_rate := float(engines) / float(runs)
	var triple_rate := float(triples) / float(runs)
	var shared_pairs := float(shared_pairs_total) / float(runs)
	print("  ENGINE DENSITY  P(engine)=%.3f  P(triple)=%.3f  E[shared pairs]=%.2f" % [
		engine_rate, triple_rate, shared_pairs,
	])

	_check(engine_rate >= 0.60, "most loadouts form an engine (%.3f)" % engine_rate)
	_check(triple_rate >= 0.20, "three of a noun is a real outcome (%.3f)" % triple_rate)
	# The sensitive one: linear rather than saturating, so it moves first.
	_check(shared_pairs >= 1.60, "shared pairs per run (%.2f)" % shared_pairs)


## The rendered probe forces all eight rules on, which is roughly a 1-in-4000
## loadout. This checks the run the player actually gets: what does the MEDIAN
## look like, and is it still readable?
func _test_median_run_is_legible() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99001
	var runs := 5000

	var slot_data: Array[ItemData] = []
	for slot in range(Inventory.SLOT_COUNT):
		slot_data.append(_make_data("median_%d" % slot, slot))

	var rule_histogram: Array[int] = []
	rule_histogram.resize(Inventory.SLOT_COUNT + 1)
	rule_histogram.fill(0)
	var pair_histogram: Array[int] = []
	pair_histogram.resize(11)
	pair_histogram.fill(0)

	for _run in range(runs):
		var held: Dictionary = {}
		var seen_rules: Dictionary = {}
		for slot in range(Inventory.SLOT_COUNT):
			var id := ManifestationCatalog.roll_for(
				slot_data[slot], ItemInstance.Polarity.POS, 0.0, rng, held
			)
			if id == &"":
				continue
			var def := ManifestationCatalog.get_def(id)
			if def == null:
				continue
			for tag in def.tags:
				held[tag] = int(held.get(tag, 0)) + 1
			seen_rules[id] = true
		rule_histogram[mini(seen_rules.size(), Inventory.SLOT_COUNT)] += 1

		# Pairs count DISTINCT rules per noun, so recount that way.
		var distinct: Dictionary = {}
		for id in seen_rules:
			var def := ManifestationCatalog.get_def(id)
			if def == null:
				continue
			for tag in def.tags:
				distinct[tag] = int(distinct.get(tag, 0)) + 1
		var pairs := ManifestationPairCatalog.active_for_counts(distinct).size()
		pair_histogram[mini(pairs, 10)] += 1

	var median_rules := 0
	var seen := 0
	for i in range(rule_histogram.size()):
		seen += rule_histogram[i]
		if seen >= runs / 2:
			median_rules = i
			break

	var loud := 0
	for i in range(3, pair_histogram.size()):
		loud += pair_histogram[i]
	var any_pair := runs - pair_histogram[0]

	print("  MEDIAN RUN  rules=%d  P(any pair)=%.3f  P(3+ pairs)=%.3f" % [
		median_rules, float(any_pair) / float(runs), float(loud) / float(runs),
	])

	_check(median_rules >= 2, "the median run actually carries rules (%d)" % median_rules)
	# The layer is a mutation, not the whole game: most runs should be readable.
	_check(median_rules <= 5, "and is not drowning in them (%d)" % median_rules)
	_check(
		float(any_pair) / float(runs) >= 0.20,
		"an authored pair is a real outcome, not a curiosity (%.3f)" % (float(any_pair) / float(runs))
	)
	# Three named payoffs at once is the glorious-nonsense tail, and it must
	# stay a tail - it is the state the HUD cannot render legibly.
	_check(
		float(loud) / float(runs) <= 0.20,
		"three or more pairs at once stays rare (%.3f)" % (float(loud) / float(runs))
	)


func _test_slot_pools() -> void:
	var every_slot_has_a_pool := true
	for slot in ManifestationCatalog.SLOT_CHANCE.keys():
		if ManifestationCatalog.pool_for_slot(int(slot)).is_empty():
			every_slot_has_a_pool = false
	_check(every_slot_has_a_pool, "every slot with a roll chance has a non-empty pool")

	# Rings are the casino slot; main equipment stays a reliable spine.
	var ring := ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_RING)
	var armour := ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_ARMOR)
	var offhand := ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_OFFHAND)
	_check(ring > offhand and offhand > armour, "ring > offhand > main equipment roll chance")

	var ring_pool := ManifestationCatalog.pool_for_slot(ManifestationCatalog.SLOT_RING).size()
	var boots_pool := ManifestationCatalog.pool_for_slot(ManifestationCatalog.SLOT_MOVE).size()
	_check(ring_pool > boots_pool, "the ring pool is the widest (%d vs %d on boots)" % [ring_pool, boots_pool])

	# Slot weighting must pick the POOL, not just the chance.
	var boots_families: Dictionary = {}
	for def in ManifestationCatalog.pool_for_slot(ManifestationCatalog.SLOT_MOVE):
		for tag in def.tags:
			boots_families[tag] = true
	_check(
		boots_families.has(&"momentum") or boots_families.has(&"stability"),
		"boots draw from movement-shaped rules"
	)

	# A slot with a high roll chance and a two-rule pool is a coin flip, not a
	# draw. Haste sat at 2 for a long time with neither rule about haste, and
	# nothing caught it - the roll-rate assertions only check how OFTEN a slot
	# rolls, never how much variety is behind it.
	var thin_slots: PackedStringArray = PackedStringArray()
	for slot in ManifestationCatalog.SLOT_CHANCE.keys():
		var pool_size := ManifestationCatalog.pool_for_slot(int(slot)).size()
		if pool_size < 3:
			thin_slots.append("%s(%d)" % [Inventory.slot_hint(int(slot)), pool_size])
	_check(thin_slots.is_empty(), "no slot draws from fewer than three rules (%s)" % ", ".join(thin_slots))


func _test_roll_respects_slot_and_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260823

	var unslotted := _make_data("test_unslotted", int(ItemData.EquipSlot.NONE))
	var never := true
	for _i in range(200):
		if ManifestationCatalog.roll_for(unslotted, ItemInstance.Polarity.POS, 0.0, rng) != &"":
			never = false
	_check(never, "an item with no equip slot never rolls a Manifestation")

	var ring_data := _make_data("test_ring", ManifestationCatalog.SLOT_RING)
	var armour_data := _make_data("test_armour", ManifestationCatalog.SLOT_ARMOR)
	var samples := 4000
	var ring_hits := 0
	var armour_hits := 0
	var off_pool := 0
	for _i in range(samples):
		var ring_id := ManifestationCatalog.roll_for(ring_data, ItemInstance.Polarity.POS, 0.0, rng)
		if ring_id != &"":
			ring_hits += 1
			var def := ManifestationCatalog.get_def(ring_id)
			if def == null or not def.allows_slot(ManifestationCatalog.SLOT_RING):
				off_pool += 1
		if ManifestationCatalog.roll_for(armour_data, ItemInstance.Polarity.POS, 0.0, rng) != &"":
			armour_hits += 1

	var ring_rate := float(ring_hits) / float(samples)
	var armour_rate := float(armour_hits) / float(samples)
	_check(
		absf(ring_rate - ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_RING)) < 0.04,
		"ring roll rate matches its authored chance (%.3f)" % ring_rate
	)
	_check(
		absf(armour_rate - ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_ARMOR)) < 0.04,
		"armour roll rate matches its authored chance (%.3f)" % armour_rate
	)
	_check(off_pool == 0, "a rolled rule is always legal for the slot that rolled it")
	_check(armour_rate < ring_rate, "main equipment stays mostly ordinary")

	# A curse is unstable material.
	var neg_chance := ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_RING, ItemInstance.Polarity.NEG)
	var pos_chance := ManifestationCatalog.slot_chance(ManifestationCatalog.SLOT_RING, ItemInstance.Polarity.POS)
	_check(neg_chance > pos_chance, "NEG items develop anomalies more readily")


func _test_describe_is_detached_safe() -> void:
	# The tooltip builds the logic node with no player, no state and no tree.
	var data := _make_data("test_describe", ManifestationCatalog.SLOT_RING)
	var all_described := true
	var all_scaled := true
	for id_value in ManifestationCatalog.all_ids():
		var low := _make_instance(data, 0, 0.2, id_value)
		var high := _make_instance(data, 12, 0.2, id_value)
		var low_text := ManifestationCatalog.describe(id_value, low)
		var high_text := ManifestationCatalog.describe(id_value, high)
		if low_text.strip_edges() == "" or high_text.strip_edges() == "":
			all_described = false
		if low_text == ManifestationCatalog.rule_text(id_value):
			# Falling back to the authored line means describe() was not
			# overridden - legal, but then it cannot show real numbers.
			all_scaled = false
	_check(all_described, "every rule produces tooltip text detached from the tree")
	_check(all_scaled, "every rule overrides describe() with instance numbers")


# ---------------------------------------------------------------------------
# Merge invariants - the load-bearing part
# ---------------------------------------------------------------------------

func _test_identity_survives_merge() -> void:
	var data := _make_data("test_identity", ManifestationCatalog.SLOT_RING)
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var destination := _make_instance(data, 3, 0.4, ids[0])
	var plain := _make_instance(data, 3, 0.4, &"")
	var merged := destination.merge_from(plain)
	_check(merged, "a plain duplicate still feeds a manifested item")
	_check(destination.manifestation_id == ids[0], "the destination keeps its own rule after a merge")


func _test_identity_survives_auto_swap_merge() -> void:
	# merge_from swaps the PROGRESSION payload when the incoming side is the
	# higher rank. Identity must not ride along with it.
	var data := _make_data("test_swap", ManifestationCatalog.SLOT_RING)
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var destination := _make_instance(data, 1, 0.2, ids[0])
	var stronger_plain := _make_instance(data, 9, 0.9, &"")
	var merged := destination.merge_from(stronger_plain)
	_check(merged, "a higher-rank plain duplicate merges into the worn item")
	_check(destination.rarity >= 9, "the higher rank became the destination's rank (%d)" % destination.rarity)
	_check(destination.manifestation_id == ids[0], "rank-up never rerolls identity, even on the auto-swap path")


func _test_a_deliberate_merge_keeps_the_destination_rule() -> void:
	var data := _make_data("test_conflict", ManifestationCatalog.SLOT_RING)
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	_check(ids.size() >= 2, "the ring pool offers at least two distinct rules to conflict")
	if ids.size() < 2:
		return

	# Merging is NEVER blocked by a rule mismatch. Two independently found
	# rings would otherwise usually refuse to combine - at a 70% roll chance
	# across a 16-rule pool that is most duplicates, and ring progression
	# would simply stop working.
	var destination := _make_instance(data, 4, 0.4, ids[0])
	var rival := _make_instance(data, 4, 0.4, ids[1])
	_check(destination.can_merge(rival), "two differently-manifested duplicates can still be merged")
	_check(destination.merge_from(rival), "and the merge actually happens")
	_check(
		destination.rarity > 4 or destination.upgrade_meter > 0.0,
		"the duplicate advanced the item (R%d + %.2f)" % [destination.rarity, destination.upgrade_meter]
	)
	_check(destination.manifestation_id == ids[0], "the destination's rule wins; the incoming one dissolves")

	# An item with no rule of its own does not silently inherit one either:
	# that would make Manifestations farmable by feeding duplicates.
	var blank := _make_instance(data, 4, 0.4, &"")
	_check(blank.merge_from(_make_instance(data, 4, 0.4, ids[1])), "a plain item still merges duplicates")
	_check(blank.manifestation_id == &"", "but it stays plain - rules are never gained by feeding")

	# The protection lives one level up, in AUTOMATIC routing.
	_check(
		not destination.can_absorb_manifestation_of(_make_instance(data, 0, 0.1, ids[1])),
		"automatic routing is told a rival rule would be destroyed"
	)
	_check(
		destination.can_absorb_manifestation_of(_make_instance(data, 0, 0.1, &"")),
		"and that ordinary material is safe to consume"
	)


func _test_plain_material_still_feeds_a_manifested_item() -> void:
	# The promise that stops rarity loss from being a trap: the R2 with the
	# rule you love can be ranked all the way up with ordinary duplicates.
	var data := _make_data("test_feeding", ManifestationCatalog.SLOT_RING)
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var keeper := _make_instance(data, 2, 0.3, ids[0])
	var start_rank := keeper.rarity
	for _i in range(12):
		keeper.merge_from(_make_instance(data, 2, 0.3, &""))
	_check(keeper.rarity > start_rank, "duplicates rank a manifested item up (R%d -> R%d)" % [start_rank, keeper.rarity])
	_check(keeper.manifestation_id == ids[0], "and it is still the same item afterwards")


func _test_fabricated_material_never_rolls() -> void:
	var data := _make_data("test_material", ManifestationCatalog.SLOT_RING)
	var clean := true
	for _i in range(200):
		var material := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.3, false)
		if material.has_manifestation():
			clean = false
	_check(clean, "fabricated merge material never rolls a rule of its own")

	# feed_roll builds exactly that kind of material internally.
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var destination := _make_instance(data, 1, 0.3, ids[0])
	for _i in range(8):
		destination.feed_roll(0.4, 1)
	_check(destination.manifestation_id == ids[0], "feed_roll cannot change an item's rule")


func _test_snapshot_copy_preserves_identity() -> void:
	var data := _make_data("test_snapshot", ManifestationCatalog.SLOT_RING)
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var original := _make_instance(data, 5, 0.5, ids[0])
	var copy := original.snapshot_copy()
	_check(copy.manifestation_id == ids[0], "transaction snapshots carry the rule (undo cannot erase it)")


# ---------------------------------------------------------------------------
# Container-level protection
# ---------------------------------------------------------------------------

func _test_equipped_feed_declines_conflicting_rule() -> void:
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	if ids.size() < 2:
		return
	var data := _make_data("test_equipped", ManifestationCatalog.SLOT_RING)

	var inventory := Inventory.new()
	var worn := _make_instance(data, 6, 0.6, ids[0])
	inventory.set_item(ManifestationCatalog.SLOT_RING, worn)

	var found := _make_instance(data, 2, 0.2, ids[1])
	var consumed := inventory.add_or_feed(found)
	_check(not consumed, "an auto-pickup will not dissolve a rival rule into the worn item")
	_check(worn.manifestation_id == ids[0], "the worn item is unchanged")
	_check(found.manifestation_id == ids[1], "the found item still exists with its own rule to choose from")

	# The same call is the player's own equip-a-duplicate path, and there the
	# decision has already been made - it must never decline, because the
	# router has emptied the source slot before calling it.
	var deliberate := _make_instance(data, 2, 0.2, ids[1])
	_check(
		inventory.add_or_feed(deliberate, null, true),
		"a player-driven merge of a rival rule goes through"
	)
	_check(worn.manifestation_id == ids[0], "and the worn item still keeps its own rule")

	# The ordinary case must keep working.
	var plain := _make_instance(data, 2, 0.2, &"")
	var rank_before := worn.rarity
	var meter_before := worn.upgrade_meter
	_check(inventory.add_or_feed(plain), "an ordinary duplicate still auto-feeds the worn item")
	_check(
		worn.rarity > rank_before or worn.upgrade_meter > meter_before,
		"and it actually advanced the item"
	)


func _test_bag_consolidation_keeps_rules_apart() -> void:
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	if ids.size() < 2:
		return
	var data := _make_data("test_bag", ManifestationCatalog.SLOT_RING)

	var bag: BagInventory = BagInventoryScript.new()
	var first := _make_instance(data, 3, 0.3, ids[0])
	var second := _make_instance(data, 3, 0.3, ids[1])
	bag.add_instance(first)
	bag.add_instance(second)

	var surviving: Dictionary = {}
	for slot_index in range(bag.get_slot_count()):
		var stack: ItemInstance = bag.get_at(slot_index)
		if stack != null:
			surviving[stack.manifestation_id] = true
	_check(surviving.has(ids[0]) and surviving.has(ids[1]), "the bag keeps two differently-manifested stacks apart")

	# But a plain copy must still consolidate into one of them.
	var plain := _make_instance(data, 3, 0.3, &"")
	bag.add_instance(plain)
	var stacks := 0
	for slot_index in range(bag.get_slot_count()):
		if bag.get_at(slot_index) != null:
			stacks += 1
	_check(stacks == 2, "a plain duplicate consolidates instead of taking a third slot (%d stacks)" % stacks)

	# And a duplicate of the SECOND rule must find that second stack, not stall
	# on the rival-ruled one the index happens to remember first. Otherwise a
	# manifested item could never rank up from its own duplicates, which is the
	# promise that makes committing to a low-rank rule safe.
	var second_rule_before: int = int((bag.get_at(1) as ItemInstance).rarity)
	for _i in range(10):
		bag.add_instance(_make_instance(data, 3, 0.3, ids[1]))
	var still_two := 0
	var second_stack: ItemInstance = null
	for slot_index in range(bag.get_slot_count()):
		var stack: ItemInstance = bag.get_at(slot_index)
		if stack == null:
			continue
		still_two += 1
		if stack.manifestation_id == ids[1]:
			second_stack = stack
	_check(still_two == 2, "same-rule duplicates keep consolidating (%d stacks)" % still_two)
	_check(
		second_stack != null and second_stack.rarity > second_rule_before,
		"and they rank their own stack up (R%d -> R%d)" % [
			second_rule_before,
			(second_stack.rarity if second_stack != null else -1),
		]
	)


## The point of the restructure: a noun is a resource several rules read and
## write, not a label. These assert the sharing itself, one noun at a time.
func _test_shared_nouns_are_shared() -> void:
	var state := ManifestationState.new()
	add_child(state)

	# --- cadence: one counter, and echoes advance it -----------------------
	state.claim(&"cadence")
	var start: int = state.attack_index
	state.note_attack()
	state.note_attack()
	_check(state.attack_index == start + 2, "the attack counter is shared and monotonic")
	_check(is_zero_approx(state.time_since_attack), "attacking resets the shared cadence clock")
	_check(state.beat_in_cycle(3) == (start + 2) % 3, "beat_in_cycle reads the shared counter")

	state.release(&"cadence")
	state.note_attack()
	_check(state.attack_index == 0, "an unclaimed cadence stops counting and resets")

	# --- ward: one gate, so two rules answer one hit once ------------------
	state.claim(&"ward")
	_check(state.try_retaliate(), "the first ward rule answers a hit")
	_check(not state.try_retaliate(), "and the second does not answer the same instant")

	_check(state.wound_tier() == 0, "a player with no HP data reads as healthy")
	_check(
		ManifestationState.WOUND_HEALTHY > ManifestationState.WOUND_WOUNDED
		and ManifestationState.WOUND_WOUNDED > ManifestationState.WOUND_DYING,
		"the wound tiers are ordered"
	)

	state.set_contribution(ManifestationState.CHANNEL_EVASION, &"rule_a", 0.30)
	state.set_contribution(ManifestationState.CHANNEL_EVASION, &"rule_b", 0.30)
	_check(
		is_equal_approx(state.bonus_evasion(), ManifestationState.EVASION_CLAMP),
		"the evasion budget is one shared pool with one clamp (%.2f)" % state.bonus_evasion()
	)

	# --- fortune: one Luck pool, one lucky tally ---------------------------
	state.claim(&"fortune")
	state.note_lucky_crit(true)
	state.note_lucky_crit(false)
	_check(state.lucky_crits == 1 and state.lucky_crit_failures == 1, "lucky rolls tally on the shared noun")

	state.set_contribution(ManifestationState.CHANNEL_LUCK, &"cartography", 0.20)
	state.set_contribution(ManifestationState.CHANNEL_LUCK, &"gospel", 0.15)
	_check(
		is_equal_approx(state.bonus_luck(), 0.35),
		"two fortune rules stack into one Luck pool (%.2f)" % state.bonus_luck()
	)
	state.clear_contributions(&"gospel")
	_check(
		is_equal_approx(state.bonus_luck(), 0.20),
		"and unequipping one leaves the other intact"
	)

	state.queue_free()


func _test_dash_hook() -> void:
	_check(ManifestationRunner.HOOKS.has(&"on_dash"), "the runner dispatches on_dash")
	_check(RunEvents.has_signal("player_dashed"), "the dash reports itself to the layer")

	# The behaviour change: the halo launches on a dash at ANY shard count, not
	# only when full. A full-orbit test would pass against the old code too.
	var halo_def := ManifestationCatalog.get_def(&"vector_halo")
	_check(halo_def != null and halo_def.logic != null, "vector_halo is in the catalog")
	if halo_def == null or halo_def.logic == null:
		return

	var state := ManifestationState.new()
	add_child(state)
	# Composure: the ward noun's clock has to actually do something, and it has
	# to be the counterweight to four rules that all reward being nearly dead.
	state.claim(&"ward")
	state.time_since_hit = 0.0
	_check(not state.composure_ready(), "a fresh wound banks no guard")
	_check(is_equal_approx(state.consume_composure(), 1.0), "and blunts nothing")
	state.time_since_hit = ManifestationState.COMPOSURE_SECONDS + 0.1
	_check(state.composure_ready(), "going unhurt banks a guard")
	var blunted: float = state.consume_composure()
	_check(
		is_equal_approx(blunted, 1.0 - ManifestationState.COMPOSURE_REDUCTION),
		"the banked guard blunts the next hit (%.2f)" % blunted
	)
	_check(not state.composure_ready(), "and spending it resets the clock")
	state.release(&"ward")
	state.time_since_hit = 999.0
	_check(not state.composure_ready(), "an unclaimed ward banks nothing")

	state.claim(&"shard")

	var halo := halo_def.logic.new() as ManifestationEffect
	add_child(halo)
	var data := _make_data("test_dash_halo", ManifestationCatalog.SLOT_OFFHAND)
	halo.setup_manifestation(null, _make_instance(data, 4, 0.3, &"vector_halo"), 6, state, halo_def)

	var cap: int = state.shard_cap()
	state.add_shard(cap - 1)
	_check(state.shard_count() == cap - 1, "the orbit is deliberately NOT full (%d/%d)" % [state.shard_count(), cap])
	_check(not state.shards_full(), "and the old on-full trigger would not have fired")

	halo.call(&"on_dash", Vector2.ZERO, Vector2.RIGHT)
	_check(state.shard_count() == 0, "dashing launches a partial orbit")

	# Re-arm guard: a second dash in the same instant must not double-fire.
	state.add_shard(2)
	halo.call(&"on_dash", Vector2.ZERO, Vector2.RIGHT)
	_check(state.shard_count() == 2, "a dash inside the re-arm window is refused")

	halo.queue_free()
	state.queue_free()


func _test_identity_survives_a_save_round_trip() -> void:
	# manifestation_id is @export-ed, so it rides the existing Inventory ->
	# SaveData resource path. Old saves simply come back with no rule.
	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var data := _make_data("test_persist", ManifestationCatalog.SLOT_RING)
	var inventory := Inventory.new()
	inventory.set_item(ManifestationCatalog.SLOT_RING, _make_instance(data, 4, 0.4, ids[0]))

	var path := "user://manifestation_roundtrip.tres"
	var write_error := ResourceSaver.save(inventory, path)
	_check(write_error == OK, "an inventory carrying a rule serialises (err=%d)" % write_error)

	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Inventory
	_check(reloaded != null, "and loads back")
	if reloaded != null:
		var restored: ItemInstance = reloaded.get_at(ManifestationCatalog.SLOT_RING)
		_check(
			restored != null and restored.manifestation_id == ids[0],
			"the rule survives the save round trip"
		)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_tooltip_renders_the_rule() -> void:
	# The tooltip is the only place the player reads what a rule does, and it
	# is also the one place describe() runs on a detached node. Exercise the
	# real widget rather than just the catalog helper.
	var scene := load("res://ui/widgets/ItemTooltip.tscn") as PackedScene
	if scene == null:
		_check(false, "the item tooltip scene loads")
		return
	var tooltip := scene.instantiate() as ItemTooltip
	if tooltip == null:
		_check(false, "the item tooltip scene root is an ItemTooltip")
		return
	add_child(tooltip)

	var ids := _first_two_ids_for_slot(ManifestationCatalog.SLOT_RING)
	var data := _make_data("test_tooltip", ManifestationCatalog.SLOT_RING)
	data.display_name = "Probe Ring"
	var manifested := _make_instance(data, 5, 0.35, ids[0])

	tooltip.show_item(manifested)
	var body: String = tooltip.body_label.text if tooltip.body_label != null else ""
	_check(body.contains("MANIFESTATION"), "the tooltip announces the rule")
	_check(
		body.contains(ManifestationCatalog.display_name(ids[0]).to_upper()),
		"and names it"
	)

	tooltip.show_item(_make_instance(data, 5, 0.35, &""))
	var plain_body: String = tooltip.body_label.text if tooltip.body_label != null else ""
	_check(not plain_body.contains("MANIFESTATION"), "an ordinary item says nothing about rules")

	# The R2-with-the-good-rule versus R9-with-the-dull-one decision has to be
	# visible in the swap preview, or the player cannot make it.
	var rows := tooltip.build_comparison_rows(manifested, _make_instance(data, 2, 0.1, ids[1]), Inventory.new())
	var mentions_rules := false
	for row in rows:
		if row.contains("MANIFESTATION"):
			mentions_rules = true
	_check(mentions_rules, "the swap preview shows the rule changing")

	tooltip.queue_free()


# ---------------------------------------------------------------------------
# Shared blackboard
# ---------------------------------------------------------------------------

func _test_shared_state_gating() -> void:
	var state := ManifestationState.new()
	add_child(state)

	state.add_momentum(1.0)
	_check(is_zero_approx(state.momentum), "an unclaimed resource stays dormant")
	_check(state.get_meters().is_empty(), "and never shows up in the readout")

	state.claim(&"momentum")
	state.add_momentum(0.6)
	_check(state.momentum > 0.0, "a claimed resource accumulates")
	# The momentum noun owns two opposite poles - Momentum and Stability - so
	# claiming it lights both meters. That is the point: one movement decision
	# with a sign, not two unrelated resources.
	_check(state.get_meters().size() == 2, "claiming a noun lights every channel it owns")
	state.add_stability(0.5)
	_check(state.stability > 0.0, "the opposite pole shares the same claim")

	# Two rules can talk about the same noun; the resource must survive the
	# first of them being unequipped.
	state.claim(&"momentum")
	state.release(&"momentum")
	_check(state.momentum > 0.0, "the resource survives while another rule still claims it")
	state.release(&"momentum")
	_check(is_zero_approx(state.momentum), "and resets once nothing claims it")

	state.claim(&"shard")
	# The cap is a shared number several rules raise, so it is reached through
	# the ledger rather than assigned - assignment is now a parse error, which
	# is the point of the change.
	state.set_contribution(
		ManifestationState.CHANNEL_SHARD_CAP,
		&"test_fixture",
		float(3 - ManifestationState.BASE_SHARD_CAP)
	)
	_check(state.shard_cap() == 3, "the ledger sets the shared cap (%d)" % state.shard_cap())
	_check(state.add_shard(5) == 3, "shards respect the shared cap")
	_check(state.take_shards(2) == 2, "shards can be spent by a consumer rule")
	_check(state.shard_count() == 1, "and the remainder stays in orbit")

	state.claim(&"fortune")
	state.add_misfortune(4)
	_check(state.consume_misfortune() == 4, "misfortune banks and pays out in full")
	_check(state.misfortune == 0, "and empties when spent")

	# The bank cap is enforced by the state, so a second producer cannot bank
	# past what a consumer is able to pay out.
	var cap: int = int(ManifestationState.noun_cap(&"misfortune"))
	state.add_misfortune(cap + 50)
	_check(state.misfortune == cap, "the bank clamps to the noun's cap (%d)" % state.misfortune)
	_check(state.consume_misfortune() == cap, "and the whole bank is payable")

	state.queue_free()
