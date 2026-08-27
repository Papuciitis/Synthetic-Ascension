extends Node

# Roadmap §14/§15: the Run Sheet must answer "what am I?" in behaviour, not
# percentages. Pins the identity composer's priorities and its sentence shape.

const BuildIdentityScript = preload("res://core/systems/run_sheet/BuildIdentity.gd")

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


func _run() -> void:
	# Nothing equipped: honest about it.
	var empty: Dictionary = BuildIdentityScript.compose({})
	_check(String(empty["primary"]) == "Unformed", "an empty run is Unformed")
	_check(String(empty["sentence"]).begins_with("Unformed"), "and the sentence says so (%s)" % empty["sentence"])

	# Doctrine wardrobe: six mild curses.
	var inv := Inventory.new()
	for slot in range(6):
		inv.set_item(slot, _cursed(slot, 0.30))
	var doctrine_burden := BurdenResolver.resolve(inv, [&"augment_doctrine_of_burden"])
	var doctrine: Dictionary = BuildIdentityScript.compose({
		"burden": doctrine_burden,
		"augment_ids": [&"augment_doctrine_of_burden"],
		"noun_counts": {&"Momentum": 2, &"Shard": 2},
		"pairs": [{"id": &"pair_momentum_shard", "name": "Loom", "nouns": [&"Momentum", &"Shard"]}],
		"set_counts": {&"gravemarch": 2},
		"luck": 38.0,
	})
	_check(String(doctrine["primary"]) == "Doctrine of Burden", "six qualifying curses read as a Doctrine build (%s)" % doctrine["primary"])
	_check(String(doctrine["secondary"]).contains("Momentum -> Shard"), "the connected pair is the secondary engine (%s)" % doctrine["secondary"])
	var sentence := String(doctrine["sentence"])
	_check(sentence.contains("6 mild curses") and sentence.contains("Momentum -> Shard") and sentence.contains("Luck +38"), "the sentence reads as behaviour (%s)" % sentence)
	_check(not sentence.contains("%") or sentence.contains("active burden"), "percentages only appear as the burden reading")
	_check(int(doctrine["connected_pairs"]) == 1 and int(doctrine["neg_count"]) == 6, "counts carry through")
	_check((doctrine["sets"] as Array).has("gravemarch x2"), "set progress is listed (%s)" % [doctrine["sets"]])

	# Same wardrobe, Lens equipped: the Lens wins the identity.
	var lens_burden := BurdenResolver.resolve(inv, [&"augment_inversion_lens", &"augment_doctrine_of_burden"])
	var lens: Dictionary = BuildIdentityScript.compose({
		"burden": lens_burden,
		"augment_ids": [&"augment_inversion_lens", &"augment_doctrine_of_burden"],
	})
	_check(String(lens["primary"]) == "Inversion Lens", "an inverted curse makes it a Lens build (%s)" % lens["primary"])
	_check(bool(lens["inverted"]), "the inversion is reported")

	# Corruption: two catastrophes.
	var conc := Inventory.new()
	conc.set_item(0, _cursed(0, 0.80))
	conc.set_item(1, _cursed(1, 0.70))
	var corruption: Dictionary = BuildIdentityScript.compose({
		"burden": BurdenResolver.resolve(conc, [&"augment_corruption_engine"]),
		"augment_ids": [&"augment_corruption_engine"],
	})
	_check(String(corruption["primary"]) == "Corruption Engine", "two catastrophes read as Corruption (%s)" % corruption["primary"])
	_check(String(corruption["sentence"]).contains("150%"), "the concentrated severity is the clause (%s)" % corruption["sentence"])

	# No NEG archetype: the dominant noun is the identity.
	var engine: Dictionary = BuildIdentityScript.compose({
		"noun_counts": {&"Shard": 3, &"Ward": 2},
		"manifestations": [{"id": &"a"}, {"id": &"b"}, {"id": &"c"}],
	})
	_check(String(engine["primary"]) == "Shard engine", "without a NEG archetype the dominant noun is the identity (%s)" % engine["primary"])
	_check(String(engine["sentence"]).contains("Shard and Ward both in play"), "two nouns without a pair read as unconnected (%s)" % engine["sentence"])

	# A lone set with nothing else.
	var set_only: Dictionary = BuildIdentityScript.compose({"set_counts": {&"gravemarch": 3}})
	_check(String(set_only["primary"]) == "gravemarch", "a set alone is still an identity (%s)" % set_only["primary"])

	print("BuildIdentityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
