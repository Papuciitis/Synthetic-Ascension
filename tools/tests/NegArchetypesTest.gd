extends Node

# NEG archetypes A3 Equilibrium Sigil, A5 Litany of Wounds, A7 Gambler's Rite
# and A6 the Gravemarch polarity rule (docs/design/NEG_BUILDCRAFT_ARCHETYPES.md,
# docs/design/2026-09-19-neg-expansion-and-playtest-spec.md). Each rule is
# pinned on the resolver, then on the real thing that reads it: the player's
# stat pass, a world pickup, the augment runner, the item operation events,
# the set runner, the combat service and the merge law.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/NegArchetypesTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const PICKUP_SCENE = preload("res://scenes/world/pickups/ItemPickup.tscn")
const LITANY_SCENE = preload("res://effects/augments/LitanyOfWounds.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const SIGIL := &"augment_equilibrium_sigil"
const LITANY := &"augment_litany_of_wounds"
const GAMBLER := &"augment_gamblers_rite"
const LENS := &"augment_inversion_lens"
const ENGINE := &"augment_corruption_engine"
const CURSED_BALLAST := "res://effects/gravemarch/scenes/GravemarchCursedBallast.tscn"
const FIXTURE_HP := 50000.0


class StubPlayer:
	extends Node2D
	var hp: float = 100.0
	var max_hp: float = 100.0
	var last_burden: BurdenSnapshot = null
	var stats: Stats = Stats.new()
	var base_weapon_damage: float = 20.0
	var healed: float = 0.0

	func heal(amount: float, _source: StringName = &"generic") -> void:
		healed += amount


var _passes := 0
var _failures := 0
var _spawned: Array[int] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _near(a: float, b: float, tolerance: float = 0.0005) -> bool:
	return absf(a - b) <= tolerance


func _run() -> void:
	_test_definitions_load()
	_test_equilibrium_rule()
	await _test_equilibrium_on_the_player()
	await _test_sigil_sends_pickups_to_the_bag()
	_test_litany_rule()
	_test_litany_effect_reads_the_player()
	await _test_litany_through_the_augment_runner()
	_test_gambler_rule()
	_test_gambler_pays_and_banks()
	_test_gravemarch_census()
	await _test_cursed_ballast_replaces_armour()
	await _test_cursed_ballast_drains_and_heals()
	_test_cursed_gravemarch_deepens()
	_cleanup_enemies()
	await get_tree().process_frame
	print("NegArchetypesTest: %d passed, %d failed" % [_passes, _failures])
	print("passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make_data(item_id: String, slot: int, set_id: String = "") -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.set_id = set_id
	data.pct_min = -0.95
	data.pct_max = 0.95
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _cursed(slot: int, severity: float, set_id: String = "", item_id: String = "") -> ItemInstance:
	var id := item_id if item_id != "" else "curse_%s_%d_%d" % [set_id, slot, int(severity * 100.0)]
	return ItemInstance.from_roll(_make_data(id, slot, set_id), 0, ItemInstance.Polarity.NEG, -severity, false)


func _blessed(slot: int, roll: float = 0.0, set_id: String = "") -> ItemInstance:
	return ItemInstance.from_roll(_make_data("bless_%s_%d" % [set_id, slot], slot, set_id), 0, ItemInstance.Polarity.POS, roll, false)


func _spawn(id: StringName, position: Vector2) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), position, FIXTURE_HP, 0.0, 4.0, 0))
	_spawned.append(handle)
	return handle


func _cleanup_enemies() -> void:
	for handle in _spawned:
		EnemyWorld.remove_enemy(handle, &"neg_archetypes_test")
	_spawned.clear()


func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


# ---------------------------------------------------------------------------
# 0. Definitions
# ---------------------------------------------------------------------------

func _test_definitions_load() -> void:
	var sigil := load("res://data/augments/Augment_EquilibriumSigil.tres") as AugmentData
	var litany := load("res://data/augments/Augment_LitanyOfWounds.tres") as AugmentData
	var gambler := load("res://data/augments/Augment_GamblersRite.tres") as AugmentData
	_check(sigil != null and sigil.id == SIGIL and litany != null and litany.id == LITANY and gambler != null and gambler.id == GAMBLER, "the three new archetype augments load with their ids")
	_check(Global.augment_db.has(SIGIL) and Global.augment_db.has(LITANY) and Global.augment_db.has(GAMBLER), "and the augment database offers them")
	_check(litany != null and litany.effect_scenes.size() == 1, "the Litany carries its effect scene")
	_check(sigil != null and sigil.details.contains("Inversion Lens still") and sigil.details.contains("bag"), "the Sigil says a suppressed curse still counts and that pickups go to the bag")
	_check(litany != null and litany.details.contains("suppressed") and litany.details.contains("statistical"), "the Litany says suppressed curses contribute nothing and that it reads statistical slots")
	_check(gambler != null and gambler.details.contains("Trades") and gambler.details.contains("per segment"), "the Rite says trades are not pickups and that Resonance is per segment")


# ---------------------------------------------------------------------------
# 1. Equilibrium Sigil
# ---------------------------------------------------------------------------

func _test_equilibrium_rule() -> void:
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.30))
	inv.set_item(1, _cursed(1, 0.40))
	inv.set_item(2, _blessed(2))
	inv.set_item(5, _blessed(5))
	var balanced := BurdenResolver.resolve(inv, [])
	_check(_near(BurdenResolver.equilibrium_bonus(1, balanced), 0.12), "2 NEG = 2 POS pays 12% at level 1")
	_check(_near(BurdenResolver.equilibrium_bonus(3, balanced), 0.18) and _near(BurdenResolver.equilibrium_bonus(200, balanced), 0.20), "levels approach 24% and the cap is 20%")
	inv.set_item(3, _blessed(3))
	_check(_near(BurdenResolver.equilibrium_bonus(1, BurdenResolver.resolve(inv, [])), 0.0), "one extra POS piece breaks it")
	inv.set_item(3, null)
	inv.set_item(5, null)
	inv.set_item(1, null)
	_check(_near(BurdenResolver.equilibrium_bonus(1, BurdenResolver.resolve(inv, [])), 0.0), "1 NEG = 1 POS is not enough: at least two of each")
	inv.set_item(1, _cursed(1, 0.40))
	inv.set_item(5, _blessed(5))
	var lensed := BurdenResolver.resolve(inv, [LENS])
	_check(lensed.suppressed_slot >= 0 and _near(BurdenResolver.equilibrium_bonus(1, lensed), 0.12), "a Lens-suppressed curse still counts as NEG for parity")


func _test_equilibrium_on_the_player() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	Global.run_inventory.set_item(0, _cursed(0, 0.30))
	Global.run_inventory.set_item(1, _cursed(1, 0.40))
	Global.run_inventory.set_item(2, _blessed(2))
	Global.run_inventory.set_item(5, _blessed(5))
	player.call("recompute_run_stats", null, null)
	var without: Stats = (player.get("stats") as Stats).copy()
	Global.permanent_augment_ids = [SIGIL, StringName(), StringName()]
	player.call("recompute_run_stats", null, null)
	var with_sigil: Stats = (player.get("stats") as Stats).copy()
	_check(_near(with_sigil.power - without.power, 0.12) and _near(with_sigil.haste - without.haste, 0.12), "the real stat pass adds +12%% Power and +12%% Haste on a balanced wardrobe (%.3f / %.3f)" % [with_sigil.power - without.power, with_sigil.haste - without.haste])
	_check(Global.last_stat_ledger.any(func(row: Dictionary) -> bool: return String(row.get("label", "")) == "EQUILIBRIUM SIGIL"), "and the Run Sheet ledger records the step")
	Global.run_inventory.set_item(3, _blessed(3))
	player.call("recompute_run_stats", null, null)
	var broken: Stats = (player.get("stats") as Stats).copy()
	_check(_near(broken.power, without.power) and _near(broken.haste, without.haste), "a third POS piece takes it away again")
	_drop(player)
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments


func _test_sigil_sends_pickups_to_the_bag() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_bag: BagInventory = Global.run_bag
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.run_inventory = Inventory.new()
	Global.run_bag = BagInventory.new()
	Global.run_bag._ensure_size()
	Global.permanent_augment_ids = [SIGIL, StringName(), StringName()]
	var curated: Variant = PICKUP_SCENE.instantiate()
	curated.set("item_instance", _blessed(3, 0.2))
	add_child(curated)
	await get_tree().process_frame
	curated.call("_collect")
	await get_tree().process_frame
	_check(Global.run_inventory.get_at(3) == null, "with the Sigil slotted a pickup for an empty slot is not auto-equipped")
	var bagged := false
	for stack in Global.run_bag.slots:
		if stack != null and stack.data != null and stack.data.equip_slot == 3:
			bagged = true
	_check(bagged, "it goes to the bag for the player to place by hand")
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	var plain: Variant = PICKUP_SCENE.instantiate()
	plain.set("item_instance", _blessed(4, 0.2))
	add_child(plain)
	await get_tree().process_frame
	plain.call("_collect")
	await get_tree().process_frame
	_check(Global.run_inventory.get_at(4) != null, "without the Sigil the same pickup auto-equips as before")
	# Collected pickups free themselves; only an uncollected one is left.
	if is_instance_valid(curated):
		curated.queue_free()
	if is_instance_valid(plain):
		plain.queue_free()
	Global.run_inventory = saved_inventory
	Global.run_bag = saved_bag
	Global.permanent_augment_ids = saved_augments


# ---------------------------------------------------------------------------
# 2. Litany of Wounds
# ---------------------------------------------------------------------------

func _test_litany_rule() -> void:
	_check(_near(BurdenResolver.litany_ramp(0.70), 0.0) and _near(BurdenResolver.litany_ramp(0.60), 0.0), "nothing at or above 60% HP")
	_check(_near(BurdenResolver.litany_ramp(0.40), 0.5) and _near(BurdenResolver.litany_ramp(0.20), 1.0) and _near(BurdenResolver.litany_ramp(0.05), 1.0), "the ramp is half way at 40% HP and complete from 20% down")
	_check(_near(BurdenResolver.litany_haste(1, 1.0, 0.20), 0.25), "at 20% HP, 100% severity converts to +25% Haste at level 1")
	_check(_near(BurdenResolver.litany_haste(1, 2.0, 0.20), 0.35), "and the hard cap is +35%")
	_check(_near(BurdenResolver.litany_haste(2, 1.0, 0.20), 1.0 / 3.0), "level 2 converts a third of the severity")
	_check(_near(BurdenResolver.litany_haste(1, 1.0, 0.40), 0.125) and _near(BurdenResolver.litany_haste(1, 0.0, 0.20), 0.0) and _near(BurdenResolver.litany_haste(1, 1.0, 0.90), 0.0), "half the ramp halves it, no severity or a full bar gives nothing")


func _test_litany_effect_reads_the_player() -> void:
	var stub := StubPlayer.new()
	add_child(stub)
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.80))
	inv.set_item(3, _cursed(3, 0.70))
	stub.last_burden = BurdenResolver.resolve(inv, [])
	var effect: Node = LITANY_SCENE.instantiate()
	add_child(effect)
	effect.call("setup", stub)
	effect.call("set_level", 1)
	_check(_near(float(effect.call("get_haste_multiplier")), 1.0), "a full health bar is x1.0")
	stub.hp = 20.0
	_check(_near(float(effect.call("get_haste_multiplier")), 1.35), "at 20% HP, 150% severity is capped to x1.35")
	stub.hp = 40.0
	_check(_near(float(effect.call("get_haste_multiplier")), 1.175), "at 40% HP half of that: x1.175")
	stub.last_burden = BurdenResolver.resolve(inv, [LENS])
	stub.hp = 20.0
	_check(_near(float(effect.call("get_haste_multiplier")), 1.175), "a Lens-suppressed curse contributes nothing (70% left: x1.175)")
	_drop(effect)
	_drop(stub)


func _test_litany_through_the_augment_runner() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [LITANY, StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	Global.run_inventory.set_item(0, _cursed(0, 0.80))
	Global.run_inventory.set_item(3, _cursed(3, 0.70))
	player.call("recompute_run_stats", null, null)
	var runner: Node = player.get_node_or_null("AugmentRunner")
	_check(runner != null and runner.has_method("get_haste_multiplier"), "the player's AugmentRunner exposes the runtime haste multiplier")
	if runner != null:
		var litany_nodes := 0
		for child in runner.get_children():
			if child is LitanyOfWoundsEffect:
				litany_nodes += 1
		_check(litany_nodes == 1, "and runs exactly one Litany effect for the slotted augment")
		_check(_near(float(runner.call("get_haste_multiplier")), 1.0), "at full HP the multiplier is 1.0")
		player.set("hp", float(player.get("max_hp")) * 0.2)
		_check(float(runner.call("get_haste_multiplier")) > 1.30, "at 20%% HP the real player's shots are faster (x%.3f)" % float(runner.call("get_haste_multiplier")))
	_drop(player)
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments


# ---------------------------------------------------------------------------
# 3. Gambler's Rite
# ---------------------------------------------------------------------------

func _test_gambler_rule() -> void:
	var neg := _cursed(0, 0.5)
	var pos := _blessed(0)
	_check(GamblersRite.is_new_neg_acquisition(&"bagged", neg, {"source": "pickup"}), "a curse bagged from a pickup is an acquisition")
	_check(GamblersRite.is_new_neg_acquisition(&"equipped", neg, {"source": "pickup"}), "so is one equipped from a pickup")
	_check(GamblersRite.is_new_neg_acquisition(&"merged", pos, {"source": "pickup", "incoming": {"polarity": ItemInstance.Polarity.NEG}}), "and a cursed copy fed into a worn piece")
	_check(not GamblersRite.is_new_neg_acquisition(&"merged", neg, {"source": "pickup", "incoming": {"polarity": ItemInstance.Polarity.POS}}), "a blessed copy fed into a curse is not")
	_check(not GamblersRite.is_new_neg_acquisition(&"bagged", pos, {"source": "pickup"}), "nor a blessed pickup")
	_check(not GamblersRite.is_new_neg_acquisition(&"bagged", neg, {"source": "trade"}) and not GamblersRite.is_new_neg_acquisition(&"bagged", neg, {"source": "undo"}) and not GamblersRite.is_new_neg_acquisition(&"bagged", neg, {}), "nor a trade, an undo or an operation with no source")
	_check(not GamblersRite.is_new_neg_acquisition(&"unbagged", neg, {"source": "pickup"}), "nor leaving a container")
	_check(_near(BurdenResolver.gambler_follower_chance(0.0), 0.15) and BurdenResolver.gambler_follower_chance(100000.0) <= 0.35, "the Follower chance is 15% plus at most 20% from Luck")


func _test_gambler_pays_and_banks() -> void:
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	var saved_followers := int(Global.followers)
	var saved_luck: float = Global.run_luck
	Global.permanent_augment_ids = [GAMBLER, StringName(), StringName()]
	Global.run_luck = 0.0
	Global.followers = 1000
	Global.gambler_reset_segment()
	var relic := _cursed(0, 0.5, "", "relic_a")
	for i in range(400):
		RunEvents.item_operation.emit(&"bagged", relic, {"source": "pickup"})
	var won := int(Global.followers) - 1000
	_check(won >= 30 and won <= 90 and won == int(Global.attempt_gambler_followers), "400 cursed pickups at Luck 0 pay about 15%% Followers (%d)" % won)
	_check(_near(Global.attempt_gambler_resonance, 0.005) and Global.attempt_gambler_seen.size() == 1, "the same relic banks Resonance once per segment (+0.5%)")
	for i in range(1, 12):
		RunEvents.item_operation.emit(&"bagged", _cursed(0, 0.5, "", "relic_%d" % i), {"source": "pickup"})
	_check(_near(Global.attempt_gambler_resonance, 0.04) and Global.attempt_gambler_seen.size() == 12, "twelve distinct curses stop at the +4% segment cap")
	var before_trade := int(Global.followers)
	for i in range(200):
		RunEvents.item_operation.emit(&"bagged", relic, {"source": "trade"})
	_check(int(Global.followers) == before_trade, "buying curses pays nothing")
	Global.gambler_reset_segment()
	_check(Global.attempt_gambler_seen.is_empty() and _near(Global.attempt_gambler_resonance, 0.0) and Global.attempt_gambler_followers == 0, "a new segment starts the registry over")
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	var before_unowned := int(Global.followers)
	for i in range(200):
		RunEvents.item_operation.emit(&"bagged", relic, {"source": "pickup"})
	_check(int(Global.followers) == before_unowned and Global.attempt_gambler_seen.is_empty(), "without the Rite nothing happens")
	Global.permanent_augment_ids = saved_augments
	Global.followers = saved_followers
	Global.run_luck = saved_luck


# ---------------------------------------------------------------------------
# 4. Gravemarch polarity rule
# ---------------------------------------------------------------------------

func _gravemarch_wardrobe(neg_count: int) -> Inventory:
	var inv := Inventory.new()
	for slot in range(3):
		if slot < neg_count:
			inv.set_item(slot, _cursed(slot, 0.50, "gravemarch"))
		else:
			inv.set_item(slot, _blessed(slot, 0.0, "gravemarch"))
	return inv


func _test_gravemarch_census() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	Global.run_inventory = _gravemarch_wardrobe(3)
	_check(Global.gravemarch_curse_active(), "three cursed Gravemarch pieces curse the set")
	Global.run_inventory = _gravemarch_wardrobe(2)
	_check(not Global.gravemarch_curse_active(), "two do not")
	Global.run_inventory = null
	_check(not Global.gravemarch_curse_active(), "and no wardrobe is no curse")
	Global.run_inventory = saved_inventory


func _test_cursed_ballast_replaces_armour() -> void:
	var host := StubPlayer.new()
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)
	var base := Stats.new()
	var cursed := Stats.new()
	runner.apply_sets_to_stats(cursed, _gravemarch_wardrobe(3))
	var keys: Array = runner.get_active_effect_keys()
	var hp_delta := cursed.max_hp - base.max_hp
	var armour_delta := cursed.armor - base.armor
	var move_delta := cursed.move_speed - base.move_speed
	_check(_near(hp_delta, 18.0) and _near(armour_delta, 0.0) and _near(move_delta, -6.0), "with three cursed pieces the Ballast Frame keeps its HP and drawback but grants no armour (%.1f / %.2f / %.1f)" % [hp_delta, armour_delta, move_delta])
	_check(keys.has(StringName(CURSED_BALLAST)), "and the runner runs the life-drain aura")
	var plain := Stats.new()
	runner.apply_sets_to_stats(plain, _gravemarch_wardrobe(2))
	_check(_near(plain.armor - base.armor, 2.0) and not runner.get_active_effect_keys().has(StringName(CURSED_BALLAST)), "with two cursed pieces the armour is back and the aura is gone")
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	await get_tree().process_frame


func _test_cursed_ballast_drains_and_heals() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	Global.run_inventory = _gravemarch_wardrobe(3)
	var host := StubPlayer.new()
	host.max_hp = 200.0
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)
	runner.apply_sets_to_stats(Stats.new(), Global.run_inventory)
	var aura: Node = null
	for child in runner.get_children():
		if child.get("effect_id") == &"gravemarch_2_cursed_ballast":
			aura = child
			aura.set_process(false)
	_check(aura != null, "fixture: the aura node exists")
	if aura != null:
		_check(_near(float(aura.call("severity_sum")), 1.5) and _near(float(aura.call("radius")), 200.0), "three 50% curses reach 200 px (120 + 160 x 1.5 / 3)")
		var near := _spawn(&"ballast_near", Vector2(60.0, 0.0))
		var far := _spawn(&"ballast_far", Vector2(300.0, 0.0))
		var dealt := float(aura.call("pulse", 0.5))
		_check(_near(dealt, 2.0, 0.01) and _near(FIXTURE_HP - EnemyWorld.get_health(near), 2.0, 0.01), "half a second drains 1%% of max HP from an enemy in reach (%.2f)" % dealt)
		_check(_near(FIXTURE_HP - EnemyWorld.get_health(far), 0.0), "and nothing from one beyond the aura")
		_check(_near(host.healed, 0.6, 0.01), "30%% of the drain comes back as healing (%.2f)" % host.healed)
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	_cleanup_enemies()
	Global.run_inventory = saved_inventory
	await get_tree().process_frame


func _test_cursed_gravemarch_deepens() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = _gravemarch_wardrobe(3)
	var worn: ItemInstance = Global.run_inventory.get_at(0)
	_check(worn.merge_from(_cursed(0, 0.80, "gravemarch", String(worn.data.id))), "fixture: a cursed copy of the worn piece merges")
	_check(_near(worn.best_pct, -0.80), "a cursed Gravemarch piece fed a deeper cursed copy deepens (%.2f)" % worn.best_pct)
	var lattice := _cursed(1, 0.30, "lattice", "lattice_piece")
	_check(lattice.merge_from(_cursed(1, 0.80, "lattice", "lattice_piece")) and _near(lattice.best_pct, -0.30), "a cursed Lattice piece under the same wardrobe still stabilises (%.2f)" % lattice.best_pct)
	Global.run_inventory = _gravemarch_wardrobe(2)
	var mild: ItemInstance = Global.run_inventory.get_at(0)
	_check(mild.merge_from(_cursed(0, 0.80, "gravemarch", String(mild.data.id))) and _near(mild.best_pct, -0.50), "with only two cursed pieces Gravemarch merges stabilise too (%.2f)" % mild.best_pct)
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments
