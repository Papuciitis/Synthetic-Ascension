extends Node

# Item batch 3a (handoff §14.3): Trauma learns a capped resistance against
# the one source category that last hurt badly — never blanket immunity,
# never retroactive; Dignity trades a Power bonus for a recoverable
# standard dropped where you were struck, with softlock-proof returns.
#
# Run: <godot> --headless --path . res://tools/tests/ItemBatch3Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const TRAUMA = preload("res://data/items/defs/accessories/trauma.tres")
const DIGNITY = preload("res://data/items/defs/accessories/dignity.tres")
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


func _effect(type_name: String) -> Node:
	for child in _runner.get_children():
		if child.get_script() != null and String(child.get_script().get_global_name()) == type_name:
			return child
	return null


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## from_data rolls a random Manifestation (intended for real drops). A rolled
## ward noun banks Composure and blunts the next hit by 45%, which bends the
## exact numbers this suite pins — so test instances carry no manifestation.
static func _bare(data: ItemData) -> ItemInstance:
	var inst := ItemInstance.from_data(data)
	inst.manifestation_id = &""
	return inst


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

	# ---------------- Trauma
	_inv.set_item(int(TRAUMA.equip_slot), _bare(TRAUMA))
	await _settle()
	_player.set("max_hp", 100.0)
	_player.set("hp", 100.0)
	var trauma := _effect("TraumaEffect") as TraumaEffect
	_check(trauma != null, "Trauma equips")
	var stats_t: Variant = _player.get("stats")
	if stats_t != null:
		stats_t.armor = 0.0
	if trauma != null:
		_check(trauma.learned_category == &"", "nothing is learned before the first wound")
		# A minor hit teaches nothing.
		_hit(5.0, null, &"claw")
		_check(trauma.learned_category == &"", "a minor hit teaches nothing")
		# A major hit teaches its category (kind, for spec-less sources).
		_hit(30.0, null, &"claw")
		_check(trauma.learned_category == &"claw", "a major hit teaches its category (%s)" % trauma.learned_category)
		# The teaching hit was never reduced retroactively: 100-5-30 = 65.
		_check(is_equal_approx(float(_player.get("hp")), 65.0), "the teaching hit itself lands at full damage (hp %.1f)" % float(_player.get("hp")))
		# The next hit from the learned category is reduced by 30% at S=1.
		_hit(20.0, null, &"claw")
		_check(is_equal_approx(float(_player.get("hp")), 65.0 - 14.0), "the learned category is resisted at 30%% (hp %.1f)" % float(_player.get("hp")))
		# Other categories pass at full strength: never blanket immunity.
		_hit(20.0, null, &"fang")
		_check(is_equal_approx(float(_player.get("hp")), 51.0 - 20.0), "an unlearned category lands in full (hp %.1f)" % float(_player.get("hp")))
		# That fang hit was major (20 >= 15): the lesson is replaced.
		_check(trauma.learned_category == &"fang", "a new major wound replaces the lesson (%s)" % trauma.learned_category)
		# The cap: even a maximal item strength stays at or below 40%.
		var strong := _bare(TRAUMA)
		strong.rarity = 30
		_check(trauma.reduction_for(strong) <= 0.40 + 0.0001, "the reduction caps at 40%% (%.2f)" % trauma.reduction_for(strong))
	_inv.set_item(int(TRAUMA.equip_slot), null)
	await _settle()

	# ---------------- Dignity
	_inv.set_item(int(DIGNITY.equip_slot), _bare(DIGNITY))
	await _settle()
	_player.set("max_hp", 100.0)
	_player.set("hp", 100.0)
	_player.global_position = Vector2.ZERO
	var dignity := _effect("DignityEffect") as DignityEffect
	_check(dignity != null, "Dignity equips")
	if dignity != null:
		dignity.set_process(false)
		_check(dignity.intact and dignity.get_power_multiplier() > 1.0, "intact dignity carries its Power bonus (%.2f)" % dignity.get_power_multiplier())
		# A moderate hit does not drop it.
		_hit(20.0, null, &"test")
		_check(dignity.intact, "a moderate hit leaves dignity standing")
		# A crushing hit drops it where the player stands.
		_player.global_position = Vector2(300, 200)
		_hit(30.0, null, &"test")
		_check(not dignity.intact, "a 25%%+ hit drops the standard")
		_check(is_equal_approx(dignity.get_power_multiplier(), 1.0), "the bonus is gone while it lies there")
		_check(dignity._drop_at == Vector2(300, 200), "it fell exactly where you were struck — always reachable")
		# Walking back over it restores.
		_player.global_position = Vector2(2000, 2000)
		dignity._process(0.1)
		_check(not dignity.intact, "distance does not restore it")
		_player.global_position = Vector2(310, 205)
		dignity._process(0.1)
		_check(dignity.intact and dignity.get_power_multiplier() > 1.0, "walking back over it restores the bonus")
		# The patience timer: it always comes back eventually.
		_hit(30.0, null, &"test")
		_player.global_position = Vector2(5000, 5000)
		dignity._process(61.0)
		_check(dignity.intact, "the standard returns by itself after the patience timer")
		_check(int(dignity.telemetry["auto_returns"]) == 1, "the auto-return is counted honestly")
	_inv.set_item(int(DIGNITY.equip_slot), null)
	await _settle()

	print("ItemBatch3Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
