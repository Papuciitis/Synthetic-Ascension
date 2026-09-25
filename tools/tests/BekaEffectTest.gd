extends Node

# Beka's approved prototype (handoff 2026-09-25 §14.2): at 200 max HP the
# shield waits 4 s then charges 8/s to 40; absorbed hits restart the delay
# without reporting HP loss; overflow reaches HP once; capacity clamps when
# max HP falls and never auto-fills when it rises; unequip clears everything;
# pay_health neither consumes the shield nor farms hit reactions; the 12 s
# pulse pulls health to a wounded player once per selection, highlights
# equipment without touching it, and skips health at full HP.
#
# Run: <godot> --headless --path . res://tools/tests/BekaEffectTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const BEKA_DATA = preload("res://data/items/defs/accessories/beka.tres")

var _passes := 0
var _failures := 0
var _player: Node2D
var _effect: BekaCompanionEffect
var _hp_loss_events: Array = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _hit(amount: float) -> void:
	_player.call("_take_damage", amount, null, &"test")


func _run() -> void:
	Global.run_luck = 0.0
	var inv := Inventory.new()
	Global.run_inventory = inv
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	RunEvents.player_damage_taken.connect(func(who: Node, amount: float, _p: Vector2) -> void:
		if who == _player:
			_hp_loss_events.append(amount))

	var beka := ItemInstance.from_data(BEKA_DATA)
	inv.set_item(int(BEKA_DATA.equip_slot), beka)
	var runner := _player.get_node("ItemEffectRunner") as ItemEffectRunner
	await get_tree().process_frame
	await get_tree().process_frame
	for child in runner.get_children():
		if child is BekaCompanionEffect:
			_effect = child
	_check(_effect != null, "equipping Beka runs her effect")
	if _effect == null:
		_finish()
		return
	_effect.set_process(false)   # deterministic manual ticks below
	# Pin the handoff's reference statline AFTER the equip settled, so the
	# player's own stat recompute cannot shift the numbers mid-test.
	_player.set("max_hp", 200.0)
	_player.set("hp", 200.0)
	var stats: Variant = _player.get("stats")
	if stats != null:
		stats.armor = 0.0

	# --- Comfortable Company at 200 max HP.
	_check(is_equal_approx(_effect.capacity(), 40.0), "baseline capacity is 20%% of max HP (%.1f)" % _effect.capacity())
	_check(_effect.shield == 0.0 and _effect._delay_left > 0.0, "a fresh equip starts empty with the full delay")
	_effect._process(3.9)
	_check(_effect.shield == 0.0, "no charging before 4 seconds")
	_effect._process(0.1)
	_effect._process(1.0)
	_check(is_equal_approx(_effect.shield, 8.0), "then 8 shield per second (%.1f)" % _effect.shield)
	_effect._process(10.0)
	_check(is_equal_approx(_effect.shield, 40.0), "charging stops at capacity (%.1f)" % _effect.shield)
	# Scaling cap: even a maximal item strength stays at or below 30%.
	var strong := ItemInstance.from_data(BEKA_DATA)
	strong.rarity = 30
	_check(_effect.capacity_fraction_for(strong) <= 0.30 + 0.0001, "scaled capacity never exceeds 30%% of max HP (%.3f)" % _effect.capacity_fraction_for(strong))

	# --- Absorption: no false HP loss, delay restarts, overflow lands once.
	_hp_loss_events.clear()
	_hit(30.0)
	_check(is_equal_approx(_effect.shield, 10.0), "the shield soaked the 30 (%.1f left)" % _effect.shield)
	_check(is_equal_approx(float(_player.get("hp")), 200.0), "a fully absorbed hit costs no HP")
	_check(_hp_loss_events.is_empty(), "a fully absorbed hit never reports HP loss")
	_check(is_equal_approx(_effect._delay_left, 4.0), "an absorbed hit restarts the 4 s delay")
	_hit(30.0)
	_check(is_equal_approx(float(_player.get("hp")), 180.0), "overflow reaches HP exactly once (hp %.1f)" % float(_player.get("hp")))
	_check(_effect.shield == 0.0, "the shield emptied")
	_check(_hp_loss_events.size() == 1 and is_equal_approx(float(_hp_loss_events[0]), 20.0), "HP loss reports only the unabsorbed 20")

	# --- A shielded nonlethal hit never tests lethality paths.
	_effect.shield = 40.0
	_player.set("hp", 5.0)
	_hit(30.0)
	_check(not bool(_player.get("is_dead")) and is_equal_approx(float(_player.get("hp")), 5.0), "a shielded nonlethal hit leaves 5 HP untouched, no death")
	_player.set("hp", 200.0)

	# --- pay_health: its own path, never absorbed, never a hit reaction.
	_effect.shield = 20.0
	_effect._delay_left = 0.0
	var paid: float = _player.call("pay_health", 10.0, &"test_cost")
	_check(is_equal_approx(paid, 10.0) and is_equal_approx(_effect.shield, 20.0), "a scripted health cost bypasses the shield")
	_check(_effect._delay_left == 0.0, "a health cost is not a hit reaction")
	_player.set("hp", 200.0)

	# --- Max HP movement: clamp down, never auto-fill up.
	_effect.shield = 40.0
	_player.set("max_hp", 100.0)
	_effect._process(0.0)
	_check(is_equal_approx(_effect.shield, 20.0), "a fallen max HP clamps the stored shield (%.1f)" % _effect.shield)
	_player.set("max_hp", 200.0)
	_effect._process(0.0)
	_check(is_equal_approx(_effect.shield, 20.0), "a raised max HP does not instantly fill the new space")

	# --- The pulse: selection once, wounded-only health, highlight-only gear.
	_player.set("hp", 100.0)
	_player.global_position = Vector2.ZERO
	var health := Node2D.new()
	health.add_to_group(GroundLootCap.HEALTH_GROUP)
	health.global_position = Vector2(200, 0)
	add_child(health)
	var far_health := Node2D.new()
	far_health.add_to_group(GroundLootCap.HEALTH_GROUP)
	far_health.global_position = Vector2(900, 0)
	add_child(far_health)
	var gear := Node2D.new()
	gear.add_to_group(GroundLootCap.ITEM_GROUP)
	gear.global_position = Vector2(-150, 0)
	add_child(gear)
	_effect._pulse_left = 0.01
	_effect._process(0.02)
	_check(_effect._pulls.has(health) and not _effect._pulls.has(far_health), "the pulse selects armed health inside 320 units, once")
	_check(_effect._highlights.has(gear), "equipment is highlighted")
	_check(_effect._pulse_left > 11.0, "the timer resets to 12 s and never banks")
	var before := health.global_position.x
	_effect._process(0.5)
	var moved := before - health.global_position.x
	_check(moved > 100.0 and moved <= 210.1, "attraction moves health at up to 420 u/s (%.0f in 0.5 s)" % moved)
	_check(is_equal_approx(gear.global_position.x, -150.0), "highlighted equipment is never moved, equipped or consumed")
	# Full HP stops the remaining pull.
	_player.set("hp", 200.0)
	_effect._process(0.1)
	_check(_effect._pulls.is_empty(), "reaching full HP stops the remaining attraction")
	# A pulse at full HP skips health entirely.
	_effect._pulse_left = 0.01
	_effect._process(0.02)
	_check(not _effect._pulls.has(health), "a full-HP pulse wastes no health")
	# Highlights restore on expiry.
	_effect._process(3.5)
	_check(not _effect._highlights.has(gear) and gear.modulate == Color(1, 1, 1, 1), "the highlight expires and restores the original look")

	# --- Unequip clears; re-equip starts empty with the full delay.
	_effect.shield = 33.0
	inv.set_item(int(BEKA_DATA.equip_slot), null)
	await get_tree().process_frame
	await get_tree().process_frame
	var still := false
	for child in runner.get_children():
		if child is BekaCompanionEffect:
			still = true
	_check(not still, "unequipping removes the companion and her shield")
	inv.set_item(int(BEKA_DATA.equip_slot), ItemInstance.from_data(BEKA_DATA))
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh: BekaCompanionEffect = null
	for child in runner.get_children():
		if child is BekaCompanionEffect:
			fresh = child
	_check(fresh != null and fresh.shield == 0.0 and fresh._delay_left > 0.0, "re-equipping begins empty with the full delay")

	# --- Two instances never stack shields: one absorb pool per runner pass.
	if fresh != null:
		fresh.set_process(false)
		fresh.shield = 10.0
		_hp_loss_events.clear()
		_player.set("max_hp", 200.0)
		_player.set("hp", 200.0)
		var stats2: Variant = _player.get("stats")
		if stats2 != null:
			stats2.armor = 0.0
		fresh._delay_left = 999.0
		_hit(30.0)
		_check(is_equal_approx(float(_player.get("hp")), 180.0), "one companion, one shield: exactly 20 reaches HP (hp %.2f, shield %.2f, events %s)" % [float(_player.get("hp")), fresh.shield, str(_hp_loss_events)])

	_finish()


func _finish() -> void:
	print("BekaEffectTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
