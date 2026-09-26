extends Node

# Item batch 2 (handoff §14.3 design-ready rows): Plot Armor survives one
# lethal hit and rearms only through its rival's death or the fallback
# safeguards; Second Breakfast serves one delayed half portion through the
# real healing path with recursion and stacking guards; the Missing Pālis
# keeps one shared, hard-bounded screen wave no matter how many copies
# exist, and carries its Luck.
#
# Run: <godot> --headless --path . res://tools/tests/ItemBatch2Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const PLOT_ARMOR = preload("res://data/items/defs/accessories/plot_armor.tres")
const BREAKFAST = preload("res://data/items/defs/accessories/second_breakfast.tres")
const PALIS = preload("res://data/items/defs/accessories/missing_palis.tres")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: ItemEffectRunner
var _inv: Inventory


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _equip(data: ItemData) -> void:
	var inst := ItemInstance.from_data(data)
	# No rolled manifestation: a ward roll banks Composure and bends the numbers.
	inst.manifestation_id = &""
	_inv.set_item(int(data.equip_slot), inst)


func _effect(type_name: String) -> Node:
	for child in _runner.get_children():
		if child.get_script() != null and String(child.get_script().get_global_name()) == type_name:
			return child
	return null


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _hit(amount: float, source: Node, kind: StringName) -> void:
	# Deterministic hits: re-pin luck (the equip recompute rewrites it and
	# lucky evasion would randomly void the hit), spawn protection and armor.
	Global.run_luck = 0.0
	_player.set("invulnerable_time", 0.0)
	var stats_now: Variant = _player.get("stats")
	if stats_now != null:
		stats_now.armor = 0.0
	_player.call("_take_damage", amount, source, kind)


func _run() -> void:
	Global.run_luck = 0.0
	_inv = Inventory.new()
	Global.run_inventory = _inv
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await _settle()
	_runner = _player.get_node("ItemEffectRunner") as ItemEffectRunner
	_player.set("max_hp", 100.0)
	_player.set("hp", 100.0)
	var stats: Variant = _player.get("stats")
	if stats != null:
		stats.armor = 0.0

	# ---------------- Plot Armor
	_equip(PLOT_ARMOR)
	await _settle()
	var armor := _effect("PlotArmorEffect") as PlotArmorEffect
	_check(armor != null and armor.armed, "Plot Armor equips armed")
	if armor != null:
		var rival_node := Node2D.new()
		add_child(rival_node)
		_player.set("hp", 10.0)
		_hit(50.0, rival_node, &"test")
		_check(is_equal_approx(float(_player.get("hp")), 1.0) and not bool(_player.get("is_dead")), "a lethal hit leaves the protagonist at 1 HP")
		_check(not armor.armed and armor.rival == rival_node, "the protection disarms and marks the culprit as rival")
		_check(float(_player.get("invulnerable_time")) > 0.0, "one brief grace follows the save")
		_check(not armor.intercept_lethal_damage(99.0, null), "no second save while disarmed: never permanent invulnerability")
		# Revenge rearms.
		RunEvents.enemy_killed.emit(_player, rival_node, Vector2.ZERO)
		_check(armor.armed and armor.rival == null, "the rival's death rearms the protection")
		# An untrackable killer: the fallback timer carries the rearm.
		_player.set("invulnerable_time", 0.0)
		_player.set("hp", 5.0)
		_hit(50.0, null, &"test")
		_check(is_equal_approx(float(_player.get("hp")), 1.0) and not armor.armed and armor.rival == null, "an untrackable killer still costs the charge")
		armor._process(46.0)
		_check(armor.armed, "the fallback timer rearms when fate loses track")
		# A vanished rival also falls back instead of gating forever.
		var vanishing := Node2D.new()
		add_child(vanishing)
		_player.set("invulnerable_time", 0.0)
		_player.set("hp", 5.0)
		_hit(50.0, vanishing, &"test")
		vanishing.free()
		armor._process(0.1)
		armor._process(46.0)
		_check(armor.armed, "a despawned rival cannot gate the rearm forever")
	_player.set("hp", 100.0)
	_player.set("invulnerable_time", 0.0)
	_inv.set_item(int(PLOT_ARMOR.equip_slot), null)
	await _settle()

	# ---------------- Second Breakfast
	_equip(BREAKFAST)
	await _settle()
	_player.set("max_hp", 100.0)
	var meal := _effect("SecondBreakfastEffect") as SecondBreakfastEffect
	_check(meal != null, "Second Breakfast equips")
	if meal != null:
		meal.set_process(false)
		_player.set("hp", 40.0)
		_player.call("heal", 20.0, &"test_pickup")
		_check(is_equal_approx(float(_player.get("hp")), 60.0), "the first helping lands normally")
		_check(is_equal_approx(meal._pending, 10.0), "half of what landed is plated for later (%.1f)" % meal._pending)
		# Coalesce, never stack.
		_player.call("heal", 30.0, &"test_pickup")
		_check(is_equal_approx(meal._pending, 15.0), "a bigger meal replaces the pending portion, never adds (%.1f)" % meal._pending)
		_player.set("hp", 60.0)  # headroom, so the clamp cannot eat the check
		meal._process(3.1)
		_check(is_equal_approx(float(_player.get("hp")), 75.0), "the portion arrives through the real healing path (%.1f)" % float(_player.get("hp")))
		_check(is_equal_approx(meal._pending, 0.0), "second portions never earn a third")
		# Overheal truth: portion derives from APPLIED, not requested.
		_player.set("hp", 95.0)
		_player.call("heal", 50.0, &"test_pickup")
		_check(is_equal_approx(meal._pending, 2.5), "the portion follows what actually landed (%.1f)" % meal._pending)
		meal._pending = 0.0
		# A healing lock blocks the portion like any other heal.
		_player.set("hp", 50.0)
		_player.call("heal", 20.0, &"test_pickup")
		_player.set("_healing_lock_left", 5.0)
		var locked_before := float(_player.get("hp"))
		meal._process(3.1)
		_check(is_equal_approx(float(_player.get("hp")), locked_before), "a healing lock blocks the second portion too")
		_check(is_equal_approx(meal._pending, 0.0), "a blocked portion is forfeit, not banked")
		_player.set("_healing_lock_left", 0.0)
	_inv.set_item(int(BREAKFAST.equip_slot), null)
	await _settle()

	# ---------------- The Missing Pālis
	_equip(PALIS)
	await _settle()
	var palis := _effect("MissingPalisEffect") as MissingPalisEffect
	_check(palis != null, "the Missing Pālis equips")
	if palis != null:
		var overlay := get_tree().root.get_node_or_null("MissingPalisOverlay")
		_check(overlay != null, "one shared screen overlay exists")
		_check(MissingPalisEffect._owners == 1, "one owner registered")
		palis._process(0.0)
		var rect := overlay.get_node("Wave") as ColorRect
		var amp := float((rect.material as ShaderMaterial).get_shader_parameter("amplitude_px"))
		_check(amp <= MissingPalisEffect.AMPLITUDE_EQUIP + 0.001, "the equip pulse never exceeds the hard bound (%.1f)" % amp)
		palis._process(5.0)
		amp = float((rect.material as ShaderMaterial).get_shader_parameter("amplitude_px"))
		_check(is_equal_approx(amp, MissingPalisEffect.AMPLITUDE_IDLE), "the wave settles to its gentle idle (%.1f)" % amp)
		# A second copy adds nothing: same overlay, same bound.
		var second := (load("res://effects/items/scenes/MissingPalisEffect.tscn") as PackedScene).instantiate()
		add_child(second)
		await _settle()
		_check(MissingPalisEffect._owners == 2, "a second copy registers")
		_check(get_tree().root.get_node_or_null("MissingPalisOverlay") == overlay, "still exactly one overlay: distortion is bounded independently of stacking")
		second.queue_free()
		await _settle()
		# Luck rides the item.
		var luck_stats := Stats.new()
		_runner.apply_effects_to_stats(luck_stats)
		var inst: ItemInstance = _inv.get_at(int(PALIS.equip_slot))
		_check(inst != null and inst.rolled_mods != null and float(inst.rolled_mods.luck) > 0.0, "the pālis carries its odd luck")
	_inv.set_item(int(PALIS.equip_slot), null)
	await _settle()
	_check(get_tree().root.get_node_or_null("MissingPalisOverlay") == null, "unequipping the last copy removes the overlay")

	print("ItemBatch2Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
