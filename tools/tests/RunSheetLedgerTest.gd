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
# Helpers
# ---------------------------------------------------------------------------

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
