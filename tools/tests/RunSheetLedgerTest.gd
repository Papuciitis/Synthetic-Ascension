extends Control

## Roadmap §15 / Run Sheet audit 2026-08-28 §4: the sheet explains its numbers
## with the arithmetic that produced them. Instantiates the real RunSheetHUD
## with a fixture player, feeds it recorded state, and reads its labels.
##
## Run: <godot> --headless --path . res://tools/tests/RunSheetLedgerTest.tscn

class ManifestationRunnerFixture:
	extends Node
	var summaries: Array[Dictionary] = []
	var pairs: Array[Dictionary] = []
	var noun_counts: Dictionary = {}
	var meters: Array[Dictionary] = []
	var power_multiplier: float = 1.0
	var haste_multiplier: float = 1.0

	func get_active_summaries() -> Array[Dictionary]:
		return summaries

	func get_active_pairs() -> Array[Dictionary]:
		return pairs

	func get_noun_counts() -> Dictionary:
		return noun_counts

	func get_meters() -> Array[Dictionary]:
		return meters

	func get_power_multiplier() -> float:
		return power_multiplier

	func get_haste_multiplier() -> float:
		return haste_multiplier


class ItemEffectRunnerFixture:
	extends Node
	var power_multiplier: float = 1.0
	var haste_multiplier: float = 1.0

	func get_power_multiplier() -> float:
		return power_multiplier

	func get_haste_multiplier() -> float:
		return haste_multiplier


class PlayerFixture:
	extends Node
	var hp := 85.0
	var max_hp := 100.0
	var armor := 3.0
	var speed := 135.0
	var power := 0.31
	var haste := 0.15
	var luck := 0.70
	var stats: Variant = null
	var last_burden: BurdenSnapshot = null


var _passes := 0
var _failures := 0

@onready var _run_sheet: RunSheetHUD = $RunSheetHUD

var _player: PlayerFixture = null
var _runner: ManifestationRunnerFixture = null
var _item_runner: ItemEffectRunnerFixture = null

var _saved_augment_ids: Array[StringName] = []
var _saved_augment_levels: Dictionary = {}
var _saved_stat_delta: StatDelta = null
var _saved_doctrine_rules: Dictionary = {}
var _saved_stage_ids: Dictionary = {}
var _saved_followers: int = 0
var _saved_ledger: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_save_global_state()
	_player = PlayerFixture.new()
	_runner = ManifestationRunnerFixture.new()
	_runner.name = "ManifestationRunner"
	_player.add_child(_runner)
	_item_runner = ItemEffectRunnerFixture.new()
	_item_runner.name = "ItemEffectRunner"
	_player.add_child(_item_runner)
	add_child(_player)
	_run_sheet.visible = true

	await _test_ledger_records_every_step()
	await _test_profile_shows_runtime_multipliers()
	await _test_doctrine_record_prints_gift_price_and_hp_multiplier()
	await _test_lens_line_prints_luck_kicker()
	await _test_burden_ledger_names_slots_and_stubs_for_owned_augment()
	await _test_manifestation_list_shares_the_hud_vocabulary()

	_restore_global_state()
	_player.queue_free()
	print("RunSheetLedgerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# §4 #1 / §4 #7: the per-stat ledger, and belief as one of its rows.
# ---------------------------------------------------------------------------

func _test_ledger_records_every_step() -> void:
	# A step outside an open ledger records nothing: tests and the dev console
	# apply single steps without a pass around them.
	Global.stat_ledger_step("STRAY", Stats.new())
	_check(Global.last_stat_ledger.is_empty(), "a step before the pass opens the ledger is a no-op")

	# The pass's own shape: base copy, additive steps, the Global-owned steps
	# recording themselves, a multiplicative slot roll, the Doctrine price last.
	var base := Stats.new()
	var s := base.copy()
	Global.stat_ledger_begin(s)

	var race := Global.race_db.get("human", null) as RaceData
	_check(race != null, "the Human race loads for the fixture")
	if race != null:
		race.apply_to(s)
	Global.stat_ledger_step("HUMAN", s)

	Global.permanent_augment_ids = [&"augment_stamina_core", &"", &""]
	Global.attempt_augment_levels = {"augment_stamina_core": 2}
	Global.apply_permanent_augments_to_stats(s)

	var doctrine_delta := StatDelta.new()
	doctrine_delta.power = 0.30
	doctrine_delta.move_speed = 15.0
	Global.attempt_stat_delta = doctrine_delta
	Global.apply_attempt_modifiers_to_stats(s)

	Global.followers = 100
	s.power += Global.follower_belief_power()
	Global.stat_ledger_step("BELIEF", s)

	s.max_hp *= 1.24
	Global.stat_ledger_step("HEALTH +24%", s)

	Global.attempt_doctrine_rules = {"max_hp_mul": 0.75}
	Global.apply_doctrine_final_stat_multipliers(s)

	var rows: Array = Global.last_stat_ledger
	_check(not rows.is_empty(), "the pass leaves rows behind (%d)" % rows.size())

	# The one invariant that makes the ledger trustworthy: for every stat, the
	# base plus every recorded delta IS the final number - additive and
	# multiplicative steps alike, nothing skipped, nothing counted twice.
	for field in Global.STAT_LEDGER_FIELDS:
		var total: float = float(base.get(field))
		for row_value in rows:
			var row: Dictionary = row_value
			if StringName(row["stat"]) != field:
				continue
			total += float(row["after"]) - float(row["before"])
		_check(
			is_equal_approx(total, float(s.get(field))),
			"%s: base + recorded deltas equals the final stat (%.2f vs %.2f)" % [String(field), total, float(s.get(field))]
		)

	var labels := PackedStringArray()
	for row_value in rows:
		var row: Dictionary = row_value
		if not labels.has(String(row["label"])):
			labels.append(String(row["label"]))
		_check(
			not is_equal_approx(float(row["before"]), float(row["after"])),
			"no row records a zero delta (%s / %s)" % [row["label"], row["stat"]]
		)
	_check(labels.has("HUMAN"), "the race step is a row")
	_check(labels.has("STAMINA CORE Lv.2"), "augments record one row per augment, level-labelled (%s)" % ", ".join(labels))
	_check(labels.has("DOCTRINE"), "the Doctrine stat delta records itself")
	_check(labels.has("MAX HP ×0.75"), "the Doctrine Max HP price records itself with its multiplier")
	_check(labels[labels.size() - 1] == "MAX HP ×0.75", "and it is the last row, as it is the last step")
	var augment_hp := _row_for(rows, "STAMINA CORE Lv.2", &"max_hp")
	_check(
		not augment_hp.is_empty() and is_equal_approx(float(augment_hp["after"]) - float(augment_hp["before"]), 92.0),
		"the augment row carries the level-scaled delta (+92 = 80 × 1.15)"
	)
	var price := _row_for(rows, "MAX HP ×0.75", &"max_hp")
	_check(
		not price.is_empty() and is_equal_approx(float(price["before"]), 250.48) and is_equal_approx(float(price["after"]), 187.86),
		"the price row shows the HP it was applied to and what remained"
	)
	_check(_row_for(rows, "MAX HP ×0.75", &"power").is_empty(), "a step records only the stats it moved")

	# The sheet renders the rows under the stat each one moved.
	_run_sheet.refresh(_player, Inventory.new())
	_run_sheet.select_page(RunSheetHUD.ArchivePage.PROFILE)
	await get_tree().process_frame
	var ledger := _run_sheet.get_node_or_null("Archive/BodyMargin/Pages/ProfileScroll/Content/Ledger")
	_check(ledger != null, "the Profile page carries a Ledger under the stats grid")
	var text := _collect_label_text(ledger)
	_check("LEDGER // WHY THESE NUMBERS" in text, "the ledger announces itself in the sheet's register")
	_check("STAMINA CORE Lv.2" in text and "+92" in text and "→ 202" in text, "an additive row prints its delta and the running total (%s)" % _one_line(text))
	_check("MAX HP ×0.75" in text and "-63" in text and "→ 188" in text, "a multiplicative row prints the same shape")
	_check("DOCTRINE" in text and "+30%" in text and "→ +35%" in text, "percentage stats print as the grid does")
	_check("BELIEF" in text and "+10%" in text and "→ +45%" in text, "belief is a row under PWR")
	_check(text.count("BELIEF") == 1, "a recorded belief step is not printed twice")
	_check(_ledger_stat_index(text, "HP") < _ledger_stat_index(text, "PWR"), "rows are grouped in the grid's stat order")

	# Until the pass records a belief step, the same call it makes supplies
	# the line - the one term the pass adds with no step of its own.
	Global.stat_ledger_begin(Stats.new())
	_run_sheet.refresh(_player, Inventory.new())
	await get_tree().process_frame
	var belief_text := _collect_label_text(ledger)
	_check(
		"BELIEF · 100 FOLLOWERS" in belief_text and "+10%" in belief_text,
		"with no recorded step the belief line comes from follower_belief_power() (%s)" % _one_line(belief_text)
	)
	Global.followers = 0
	_run_sheet.refresh(_player, Inventory.new())
	await get_tree().process_frame
	_check(not "BELIEF" in _collect_label_text(ledger), "no followers, no belief row")


# ---------------------------------------------------------------------------
# §4 #2: PWR/HST carry the runtime multipliers _fire_weapon applies.
# ---------------------------------------------------------------------------

func _test_profile_shows_runtime_multipliers() -> void:
	var powv := _run_sheet.get_node("Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/POWV") as Label
	var hstv := _run_sheet.get_node("Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/HSTV") as Label
	_runner.power_multiplier = 1.0
	_runner.haste_multiplier = 1.0
	_item_runner.power_multiplier = 1.0
	_item_runner.haste_multiplier = 1.0
	_run_sheet.refresh(_player, Inventory.new())
	_check(powv.text == "+31%" and hstv.text == "+15%", "at x1.00 the totals print bare, as before (%s / %s)" % [powv.text, hstv.text])

	# An Anchor Rite-shaped rule multiplier and an item multiplier, on the two
	# runners _fire_weapon polls; the sheet shows their product.
	_runner.power_multiplier = 1.85
	_item_runner.haste_multiplier = 1.20
	_runner.haste_multiplier = 1.10
	_run_sheet.refresh(_player, Inventory.new())
	_check(powv.text == "+31% ×1.85", "PWR appends the rule multiplier the next shot uses (%s)" % powv.text)
	_check(hstv.text == "+15% ×1.32", "HST appends the product of the item and rule multipliers (%s)" % hstv.text)
	_runner.power_multiplier = 1.0
	_runner.haste_multiplier = 1.0
	_item_runner.haste_multiplier = 1.0


# ---------------------------------------------------------------------------
# §4 #4: the Doctrine Record carries each stage's gift and price, and the
# Max HP multiplier the stat pass applies last.
# ---------------------------------------------------------------------------

func _test_doctrine_record_prints_gift_price_and_hp_multiplier() -> void:
	var definition: MajorChoiceDef = Global.major_choice_db.get_def(&"doctrine_method_frame_of_ash")
	_check(definition != null and definition.gift_text != "" and definition.price_text != "", "Frame of Ash authors a gift and a price")
	Global.attempt_doctrine_stage_ids = {&"method": &"doctrine_method_frame_of_ash"}
	Global.attempt_doctrine_rules = {"max_hp_mul": 0.75}
	_run_sheet.refresh(_player, Inventory.new())
	_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
	await get_tree().process_frame
	var text := _manifestations_text()
	_check("METHOD // FRAME OF ASH" in text, "the stage title still leads the record")
	_check(
		definition != null and ("GIFT // " + definition.gift_text) in text,
		"the stage's gift is printed under it (%s)" % _one_line(text)
	)
	_check(definition != null and ("PRICE // " + definition.price_text) in text, "and its price")
	_check("MAX HP ×0.75" in text, "the Max HP multiplier the pass applies last is named")
	_check(text.find("GIFT // ") > text.find("METHOD // FRAME OF ASH"), "gift and price sit under their stage")

	# Without the price rule the line is absent rather than "x1.00".
	Global.attempt_doctrine_rules = {}
	_run_sheet.refresh(_player, Inventory.new())
	await get_tree().process_frame
	_check(not "MAX HP ×" in _manifestations_text(), "no multiplier line while the rule is 1.0")
	Global.attempt_doctrine_stage_ids = {}


# ---------------------------------------------------------------------------
# §4 #8: the Lens block prints the Luck kicker the stat pass adds.
# ---------------------------------------------------------------------------

func _test_lens_line_prints_luck_kicker() -> void:
	var inv := Inventory.new()
	inv.set_item(1, _cursed(1, 0.80))
	_player.last_burden = BurdenResolver.resolve(inv, [&"augment_inversion_lens"])
	Global.permanent_augment_ids = [&"augment_inversion_lens", &"", &""]
	Global.attempt_augment_levels = {}
	_run_sheet.refresh(_player, inv)
	_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
	await get_tree().process_frame
	var text := _manifestations_text()
	_check("ARMOR suppressed: 80% curse  →  +44% returned, 0% burden" in text, "the suppression line is unchanged (%s)" % _one_line(text))
	_check(
		"Luck +12%  (80% severity  ×  15%/100%)" in text,
		"the Lens block prints the Luck kicker: severity × asymptotic_rate(INVERSION_LUCK_KICKER, level)"
	)
	Global.attempt_augment_levels = {"augment_inversion_lens": 2}
	_run_sheet.refresh(_player, inv)
	await get_tree().process_frame
	var levelled := _manifestations_text()
	_check(
		"Luck +16%  (80% severity  ×  20%/100%)" in levelled,
		"and follows the augment level (L2: 0.30 × 2/3 = 20%%) (%s)" % _one_line(levelled)
	)
	Global.attempt_augment_levels = {}
	_player.last_burden = null


# ---------------------------------------------------------------------------
# Observability audit 2026-08-30 §6 #5 / #11: the BURDEN ledger names the
# slots behind each count, and an owned NEG augment with no curses shows a
# stub row instead of no section.
# ---------------------------------------------------------------------------

func _test_burden_ledger_names_slots_and_stubs_for_owned_augment() -> void:
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.40))
	inv.set_item(1, _cursed(1, 0.20))
	inv.set_item(2, _cursed(2, 0.80))
	var ids: Array[StringName] = [&"augment_corruption_engine", &"augment_doctrine_of_burden", &""]
	Global.permanent_augment_ids = ids
	_player.last_burden = BurdenResolver.resolve(inv, ids)
	_run_sheet.refresh(_player, inv)
	_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
	await get_tree().process_frame
	var text := _manifestations_text()
	_check("3 NEG / 0 POS   ·   3 active" in text, "the census line is unchanged (%s)" % _one_line(text))
	_check("active: HP −40%  ·  ARM −20%  ·  MOV −80%" in text, "the active count names its slots in slot order")
	_check("burning: MOV −80%  ·  HP −40%" in text, "the Engine names the two slots heaviest(2) sums, heaviest first")
	_check("qualifying: HP −40%  ·  ARM −20%  ·  MOV −80%" in text, "the Doctrine names its qualifying slots")

	# A Lens takes the movement curse out of every roster it fed.
	ids = [&"augment_corruption_engine", &"augment_inversion_lens", &""]
	Global.permanent_augment_ids = ids
	_player.last_burden = BurdenResolver.resolve(inv, ids)
	_run_sheet.refresh(_player, inv)
	await get_tree().process_frame
	var lensed := _manifestations_text()
	_check("active: HP −40%  ·  ARM −20%" in lensed and not "active: HP −40%  ·  ARM −20%  ·  MOV" in lensed, "a suppressed curse leaves the active roster (%s)" % _one_line(lensed))
	_check("burning: HP −40%  ·  ARM −20%" in lensed, "and the Engine's roster shows what it is left with")
	_check("MOVEMENT suppressed: 80% curse" in lensed, "while the Lens line still names it")

	# No curses, Engine owned: the section renders a stub instead of vanishing.
	var empty := Inventory.new()
	ids = [&"augment_corruption_engine", &"", &""]
	Global.permanent_augment_ids = ids
	_player.last_burden = BurdenResolver.resolve(empty, ids)
	_run_sheet.refresh(_player, empty)
	await get_tree().process_frame
	var stub := _manifestations_text()
	_check("BURDEN" in stub and "0 NEG / 0 POS" in stub, "an owned NEG augment keeps the BURDEN section with no curses (%s)" % _one_line(stub))
	_check("CORRUPTION ENGINE — no curses equipped" in stub, "and says which augment is waiting")
	_check(not "top two active" in stub, "without printing arithmetic over nothing")

	# No curses, no NEG augment: no section, as before.
	ids = [&"", &"", &""]
	Global.permanent_augment_ids = ids
	_player.last_burden = BurdenResolver.resolve(empty, ids)
	_run_sheet.refresh(_player, empty)
	await get_tree().process_frame
	_check(not "BURDEN" in _manifestations_text(), "no NEG augment and no curses: no BURDEN section")
	_player.last_burden = null


# ---------------------------------------------------------------------------
# Observability audit 2026-08-30 §5 #2 / §6 #1 / §6 #10: one box per rule
# with a copy count, the HUD's pip vocabulary on the noun row, the meter gate
# named, and the pair one lit noun away.
# ---------------------------------------------------------------------------

func _test_manifestation_list_shares_the_hud_vocabulary() -> void:
	Global.permanent_augment_ids = [&"", &"", &""]
	_runner.summaries = [
		{"id": &"anchor_rite", "name": "Anchor Rite", "tags": [&"momentum"], "slot": Inventory.SLOT_OFFHAND, "rule": "Stand still to anchor."},
		{"id": &"anchor_rite", "name": "Anchor Rite", "tags": [&"momentum"], "slot": Inventory.SLOT_RING, "rule": "Stand still to anchor."},
		{"id": &"pilgrims_momentum", "name": "Pilgrim's Momentum", "tags": [&"momentum"], "slot": 2, "rule": "Travel fills Momentum."},
		{"id": &"shard_forge", "name": "Shard Forge", "tags": [&"shard"], "slot": 3, "rule": "Kills forge shards."},
	]
	_runner.noun_counts = {&"momentum": 2, &"shard": 1}
	_runner.meters = [{"noun": &"shard", "channel": &"shard", "label": "SHARDS", "text": "0/4", "full": false}]
	_runner.pairs = []
	_run_sheet.refresh(_player, Inventory.new())
	_run_sheet.select_page(RunSheetHUD.ArchivePage.MANIFESTATIONS)
	await get_tree().process_frame
	var page := _run_sheet.get_node("Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox")
	var boxes := page.find_children("*", "ManifestationInfoBox", true, false)
	_check(boxes.size() == 3, "two copies of one rule collapse into one box (%d boxes)" % boxes.size())
	var text := _collect_label_text(page)
	_check("OFF·RING  Anchor Rite ×2" in text, "the collapsed box names both slots and the copy count (%s)" % _one_line(text))
	_check(text.count("Anchor Rite") == 1, "and the rule is listed once")
	_check("MOV  Pilgrim's Momentum" in text and not "×1" in text, "a single copy prints as before")
	_check("MOMENTUM ◆◆" in text and "SHARDS ◆◇" in text, "the noun row uses the HUD's pips")
	_check(not "MOMENTUM 2*" in text, "and no longer the * glyph")
	_check("MOMENTUM — meter appears at first bank" in text, "a claimed noun with no meter says when its meter appears")
	_check(not "SHARDS — meter" in text, "a metered noun does not")
	_check("next pair: SLIPSTREAM FOUNDRY — one more SHARDS rule" in text, "the pair one lit noun away is named with what lights it")

	# Two nouns lit: their pair is live, and the next pair needs a third noun.
	_runner.noun_counts = {&"momentum": 2, &"shard": 2}
	_runner.pairs = [{"id": &"slipstream_foundry", "name": "Slipstream Foundry", "nouns": [&"momentum", &"shard"], "rule": "Shards string out behind you."}]
	_run_sheet.refresh(_player, Inventory.new())
	await get_tree().process_frame
	var lit := _manifestations_text()
	_check("MOMENTUM ◆◆" in lit and "SHARDS ◆◆" in lit, "two lit nouns")
	_check(not "next pair: SLIPSTREAM FOUNDRY" in lit, "a live pair is not the next pair")
	_check("next pair: RED LINE — 2 WARD rules" in lit, "the next pair is the first unlit partner in noun order with its full cost (%s)" % _one_line(lit))

	# Nothing lit: nothing is one noun away.
	_runner.noun_counts = {&"momentum": 1, &"shard": 1}
	_runner.pairs = []
	_run_sheet.refresh(_player, Inventory.new())
	await get_tree().process_frame
	_check(not "next pair:" in _manifestations_text(), "with no lit noun there is no next pair line")
	_runner.summaries = []
	_runner.noun_counts = {}
	_runner.meters = []


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


func _cursed(slot: int, severity: float) -> ItemInstance:
	return ItemInstance.from_roll(_make_data("curse_%d" % slot, slot), 3, ItemInstance.Polarity.NEG, -severity, false)


func _manifestations_text() -> String:
	return _collect_label_text(_run_sheet.get_node_or_null("Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox"))

func _row_for(rows: Array, label: String, stat: StringName) -> Dictionary:
	for row_value in rows:
		var row: Dictionary = row_value
		if String(row["label"]) == label and StringName(row["stat"]) == stat:
			return row
	return {}


func _ledger_stat_index(text: String, key: String) -> int:
	return text.find("\n%s\n" % key)


func _one_line(text: String) -> String:
	return text.replace("\n", " | ")


func _collect_label_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _save_global_state() -> void:
	_saved_augment_ids = Global.permanent_augment_ids.duplicate()
	_saved_augment_levels = Global.attempt_augment_levels.duplicate(true)
	_saved_stat_delta = Global.attempt_stat_delta
	_saved_doctrine_rules = Global.attempt_doctrine_rules.duplicate(true)
	_saved_stage_ids = Global.attempt_doctrine_stage_ids.duplicate(true)
	_saved_followers = Global.followers
	_saved_ledger = Global.last_stat_ledger.duplicate(true)


func _restore_global_state() -> void:
	Global.permanent_augment_ids = _saved_augment_ids
	Global.attempt_augment_levels = _saved_augment_levels
	Global.attempt_stat_delta = _saved_stat_delta
	Global.attempt_doctrine_rules = _saved_doctrine_rules
	Global.attempt_doctrine_stage_ids = _saved_stage_ids
	Global.followers = _saved_followers
	Global.last_stat_ledger = _saved_ledger
