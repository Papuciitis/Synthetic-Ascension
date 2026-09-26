extends Node

# Item batch 4 (handoff §14.3 idea table, user-approved 2026-09-26):
# 7-Mile Boots (longer dash + a brief step-back window), Grandma's Bazooka
# (delayed homing retaliation with defined cadence and target loss), IDFK
# (a fixed learnable rule whose description becomes "Oh."), and Bazinga
# (a bounded near-miss sound decoy).
#
# Run: <godot> --headless --path . res://tools/tests/ItemBatch4Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const BOOTS = preload("res://data/items/defs/accessories/seven_mile_boots.tres")
const BAZOOKA = preload("res://data/items/defs/accessories/grandmas_bazooka.tres")
const IDFK = preload("res://data/items/defs/accessories/idfk.tres")
const BAZINGA = preload("res://data/items/defs/accessories/bazinga.tres")

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


static func _bare(data: ItemData) -> ItemInstance:
	var inst := ItemInstance.from_data(data)
	inst.manifestation_id = &""
	return inst


func _effect(type_name: String) -> Node:
	for child in _runner.get_children():
		if child.get_script() != null and String(child.get_script().get_global_name()) == type_name:
			return child
	return null


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _equip(data: ItemData) -> void:
	_inv.set_item(int(data.equip_slot), _bare(data))


func _unequip(data: ItemData) -> void:
	_inv.set_item(int(data.equip_slot), null)


func _run() -> void:
	Global.run_luck = 0.0
	_inv = Inventory.new()
	Global.run_inventory = _inv
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await _settle()
	_runner = _player.get_node("ItemEffectRunner") as ItemEffectRunner

	# ---------------- 7-Mile Boots
	_equip(BOOTS)
	await _settle()
	var boots := _effect("SevenMileBootsEffect") as SevenMileBootsEffect
	_check(boots != null, "the boots equip")
	if boots != null:
		_check(is_equal_approx(_runner.get_dash_distance_multiplier(), 1.4), "the dash reaches 40%% further (%.2f)" % _runner.get_dash_distance_multiplier())
		var strong := _bare(BOOTS)
		strong.rarity = 30
		_check(boots.dash_bonus_for(strong) <= 0.6 + 0.0001, "the reach bonus caps at +60%%")
		# The return: dash ends, window opens, the recovering dash input
		# steps back to the boot.
		_player.global_position = Vector2(100, 100)
		RunEvents.player_dashed.emit(_player, _player.global_position, Vector2.RIGHT)
		boots._was_dashing = true
		_player.global_position = Vector2(324, 100)   # dash carried us away
		boots._process(0.016)                          # dash no longer running -> window
		_check(boots._window_left > 0.0, "a finished dash opens the return window")
		boots._return_to_boot()
		_check(_player.global_position == Vector2(100, 100), "the return steps back into the boot")
		_check(boots._window_left <= 0.0, "one boot, one return")
		# A new dash forfeits the old boot.
		RunEvents.player_dashed.emit(_player, Vector2(500, 500), Vector2.RIGHT)
		_check(boots._window_left <= 0.0 and boots._boot_at == Vector2(500, 500), "a new dash plants a new boot and forfeits the old return")
	_unequip(BOOTS)
	await _settle()

	# ---------------- Grandma's Bazooka
	_equip(BAZOOKA)
	await _settle()
	var bazooka := _effect("GrandmasBazookaEffect") as GrandmasBazookaEffect
	_check(bazooka != null, "the bazooka equips")
	if bazooka != null:
		var attacker := EnemyWorld.create_enemy(SpawnState.new(&"batch4_thug", "res://batch4_thug.tscn", _player.global_position + Vector2(200, 0), 300.0, 0.0, 8.0, 0, 0))
		var actor_like := Node2D.new()
		add_child(actor_like)
		# The wound: resolved with the enemy's ACTOR as source; the effect
		# resolves the handle through the combat service. Simulate directly.
		bazooka._pending_left = 0.0
		bazooka._cooldown_left = 0.0
		bazooka._on_damage_resolved(_player, 20.0, 20.0, 20.0, actor_like, &"claw", &"hit")
		_check(bazooka._pending_left <= 0.0, "a source without a handle angers nobody")
		# With a real handle, the grudge waits DELAY then fires a rocket.
		bazooka._pending_left = 0.01
		bazooka._pending_target = attacker
		ProjectileManager.clear_for_run_end()
		bazooka._process(0.02)
		_check(int(bazooka.telemetry["rockets"]) == 1 and ProjectileManager.active_count() == 1, "the grudge fires exactly one homing rocket")
		_check(bazooka._cooldown_left > 0.0, "grandma reloads for %.1f s" % bazooka.COOLDOWN)
		# Cadence: a second wound during cooldown fires nothing.
		bazooka._on_damage_resolved(_player, 20.0, 20.0, 20.0, actor_like, &"claw", &"hit")
		_check(bazooka._pending_left <= 0.0, "the cooldown holds the second grudge")
		# Target loss: the culprit dies, the nearest enemy inherits.
		var bystander := EnemyWorld.create_enemy(SpawnState.new(&"batch4_bystander", "res://batch4_bystander.tscn", _player.global_position + Vector2(150, 0), 300.0, 0.0, 8.0, 0, 0))
		EnemyWorld.remove_enemy(attacker, &"test")
		bazooka._cooldown_left = 0.0
		bazooka._fire(attacker)
		_check(int(bazooka.telemetry["retargeted"]) == 1, "a vanished culprit passes the grudge to the nearest enemy")
		# Nobody nearby: grandma holds fire AND her cooldown.
		EnemyWorld.remove_enemy(bystander, &"test")
		bazooka._cooldown_left = 0.0
		bazooka._fire(attacker)
		_check(int(bazooka.telemetry["held_fire"]) == 1 and bazooka._cooldown_left <= 0.0, "with nobody to blame the rocket and the cooldown are both kept")
		actor_like.queue_free()
		ProjectileManager.clear_for_run_end()
	_unequip(BAZOOKA)
	await _settle()

	# ---------------- IDFK
	_equip(IDFK)
	await _settle()
	var idfk := _effect("IdfkEffect") as IdfkEffect
	_check(idfk != null, "IDFK equips")
	if idfk != null:
		_check(idfk.get_effects_short(null)[0] == "IDFK. Something helps, sometimes.", "undiscovered, it admits nothing")
		_check(is_equal_approx(idfk.get_power_multiplier(), 1.0), "unarmed, it does nothing")
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
		idfk._process(0.7)
		_check(idfk._armed and idfk.get_power_multiplier() > 1.0, "standing still 0.6 s arms the bonus (%.2f)" % idfk.get_power_multiplier())
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2(100, 0)
		idfk._process(0.016)
		_check(not idfk._armed and is_equal_approx(idfk.get_power_multiplier(), 1.0), "moving ends it — the rule is learnable, not random")
		idfk._armings = idfk.DISCOVERIES_NEEDED
		_check(idfk.get_effects_short(null)[0] == "Oh.", "after the eighth arming the description becomes: Oh.")
	_unequip(IDFK)
	await _settle()

	# ---------------- Bazinga
	_equip(BAZINGA)
	await _settle()
	var bazinga := _effect("BazingaEffect") as BazingaEffect
	_check(bazinga != null, "Bazinga equips")
	if bazinga != null:
		var mark := EnemyWorld.create_enemy(SpawnState.new(&"batch4_mark", "res://batch4_mark.tscn", _player.global_position + Vector2(80, 0), 100.0, 60.0, 8.0, 0, 0))
		var far_mark := EnemyWorld.create_enemy(SpawnState.new(&"batch4_far", "res://batch4_far.tscn", _player.global_position + Vector2(900, 0), 100.0, 60.0, 8.0, 0, 0))
		bazinga._on_damage_resolved(_player, 10.0, 0.0, 0.0, null, &"claw", &"evaded")
		_check(int(bazinga.telemetry["decoys"]) == 1, "a lucky evasion drops the decoy")
		_check(is_equal_approx(EnemyWorld.get_speed(mark), 30.0), "a nearby enemy hesitates at half speed (%.0f)" % EnemyWorld.get_speed(mark))
		_check(is_equal_approx(EnemyWorld.get_speed(far_mark), 60.0), "a distant enemy never hears the joke")
		bazinga._on_damage_resolved(_player, 10.0, 0.0, 0.0, null, &"claw", &"evaded")
		_check(int(bazinga.telemetry["decoys"]) == 1, "one laugh per %.0f s — the audio repetition is bounded" % bazinga.COOLDOWN)
		bazinga._decoy_left = 0.01
		bazinga._process(0.02)
		_check(is_equal_approx(EnemyWorld.get_speed(mark), 60.0), "the hesitation ends with the original speed restored")
		# A plain blocked hit is not a near miss.
		bazinga._cooldown_left = 0.0
		bazinga._on_damage_resolved(_player, 10.0, 0.0, 0.0, null, &"claw", &"invulnerable")
		_check(int(bazinga.telemetry["decoys"]) == 1, "an invulnerable block without a dash is no dodge")
		EnemyWorld.remove_enemy(mark, &"test")
		EnemyWorld.remove_enemy(far_mark, &"test")
	_unequip(BAZINGA)
	await _settle()

	print("ItemBatch4Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
