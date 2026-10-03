extends Node

# Augment potency (docs/design/2026-10-03-bindings-and-theses.md §4): every
# combat augment pays in D - the native hit, style multiplier and Power
# included, the tree's unit - grows +35% per level, and no longer clamps at
# Lv.5. Pins the scaling module, each effect's payload against live enemies,
# and the level paths that used to stop at 5.
#
# Run: <godot> --headless --path . res://tools/tests/AugmentPotencyTest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const TESLA_SCENE = preload("res://effects/augments/scenes/TeslaAuraEffect.tscn")
const MISSILE_SCENE = preload("res://effects/augments/scenes/MagicMissileEffect.tscn")
const SLASH_SCENE = preload("res://effects/augments/scenes/SpiritSlashEffect.tscn")
const HEX_SCENE = preload("res://effects/augments/scenes/HexBlinkMarkEffect.tscn")
const SPIDER_SCENE = preload("res://effects/augments/scenes/SpiderlingSummonEffect.tscn")
const SHIELD_SCENE = preload("res://effects/augments/scenes/ReflectedShieldEffect.tscn")
const FIXTURE_HP := 100000.0


class TestPlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats: Stats = Stats.new()
	var hp: float = 100.0
	var max_hp: float = 100.0
	var healed: float = 0.0

	func heal(amount: float, _source: StringName = &"generic") -> void:
		healed += amount

	func grant_invulnerability(_seconds: float) -> void:
		pass


var _passes := 0
var _failures := 0
var _spawned: Array[int] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _near(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance * maxf(1.0, absf(b))


func _spawn(position: Vector2, health: float = FIXTURE_HP) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(&"potency_dummy", "res://potency_dummy.tscn", position, health, 0.0, 4.0, 0))
	_spawned.append(handle)
	return handle


func _cleanup() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"potency_test")
	_spawned.clear()


func _lost(handle: int, from: float = FIXTURE_HP) -> float:
	return from - EnemyWorld.get_health(handle)


func _run() -> void:
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.selected_style_id = &"melee"
	_test_scaling_module()
	var player := TestPlayer.new()
	player.stats.power = 0.5
	add_child(player)
	_check(_near(AugmentScaling.native_d(player), 12.0 * 1.25 * 1.5), "D reads the style multiplier and Power: 12 x 1.25 x 1.5 = 22.5 (%.2f)" % AugmentScaling.native_d(player))
	_test_doctrine_multiplier(player)
	_test_tesla(player)
	_test_missile(player)
	_test_slash(player)
	_test_hex(player)
	_test_spiders(player)
	_test_shield(player)
	_test_level_paths()
	_cleanup()
	player.queue_free()
	await get_tree().process_frame
	print("AugmentPotencyTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_scaling_module() -> void:
	_check(_near(AugmentScaling.potency(1), 1.0) and _near(AugmentScaling.potency(5), 2.4) and _near(AugmentScaling.potency(10), 4.15), "potency is 1 / 2.4 / 4.15 at Lv.1 / 5 / 10")
	_check(AugmentScaling.clamp_level(99) == 20 and AugmentScaling.clamp_level(0) == 1, "levels run 1 to 20")
	_check(AugmentScaling.count_steps(1) == 0 and AugmentScaling.count_steps(5) == 4 and AugmentScaling.count_steps(15) == 8, "count growth stops after eight steps")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var total := 0.0
	for i in range(20000):
		total += AugmentScaling.dice_factor(3, 6, rng)
	_check(absf(total / 20000.0 - 1.0) < 0.01, "a dice expression averages 1.0 (3d6: %.3f)" % (total / 20000.0))
	_check(_near(AugmentData.stat_level_factor(0.2, 3), 1.4) and _near(AugmentData.stat_level_factor(0.2, 7), 2.0), "stat augments grow at the full rate to Lv.5 and half after (Lv.3 x1.4, Lv.7 x2.0)")


func _test_doctrine_multiplier(player: Node) -> void:
	var base := AugmentScaling.damage(player, 1.0, 1)
	Global.set_doctrine_rule(&"augment_damage_mul", 1.25)
	_check(_near(AugmentScaling.damage(player, 1.0, 1), base * 1.25), "the augment_damage_mul rule scales every payload")
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_choir_of_recurrence"}
	_check(_near(AugmentScaling.damage(player, 1.0, 1), base * 1.25 * 1.2), "the Circuit Thesis adds +20%")
	Global.attempt_doctrine_stage_ids["apotheosis"] = "doctrine_apotheosis_perfected_engine"
	_check(_near(AugmentScaling.damage(player, 1.0, 1), base * 1.25 * 1.2 * 1.5), "the Circuit Canon adds +50% more")
	Global.attempt_doctrine_stage_ids = {}
	Global.attempt_doctrine_rules = {}


func _test_tesla(player: Node) -> void:
	var tesla := TESLA_SCENE.instantiate() as TeslaAuraEffect
	tesla.setup(player)
	add_child(tesla)
	tesla.set_level(1)
	var d := AugmentScaling.native_d(player)
	_check(_near(tesla._compute_damage(), d * 0.5), "Tesla Lv.1 zaps for 0.5 D (%.2f)" % tesla._compute_damage())
	var near := [_spawn(Vector2(60, 0)), _spawn(Vector2(0, 80)), _spawn(Vector2(-90, 0))]
	tesla._process(1.0)
	var all_hit := true
	for handle in near:
		if not _near(_lost(handle), d * 0.5):
			all_hit = false
	_check(all_hit, "a pulse strikes each enemy in reach for exactly that")
	tesla.set_level(12)
	_check(tesla._aug_level == 12, "Tesla is not clamped to Lv.5 any more")
	_check(_near(tesla._compute_damage(), d * 0.5 * AugmentScaling.potency(12)), "Lv.12 pays potency 4.85")
	_check(tesla.max_targets == 8, "targets grow +1 per two levels for eight steps: 8 at Lv.12")
	player.stats.haste = 1.0
	_check(_near(tesla.current_tick_interval(), tesla.tick_interval / 2.0), "Haste speeds the aura's pulse")
	player.stats.haste = 0.0
	tesla.queue_free()
	_cleanup()


func _test_missile(player: Node) -> void:
	var missile := MISSILE_SCENE.instantiate() as MagicMissileEffect
	missile.setup(player)
	add_child(missile)
	missile.set_level(1)
	var d := AugmentScaling.native_d(player)
	_check(_near(missile._compute_damage(), d * 0.45) and missile.burst_count == 2, "Magic Missile Lv.1: two missiles of 0.45 D")
	missile.set_level(9)
	_check(missile.burst_count == 6 and _near(missile._compute_damage(), d * 0.45 * AugmentScaling.potency(9)), "Lv.9: six missiles at potency 3.8")
	missile.queue_free()


func _test_slash(player: Node) -> void:
	var slash := SLASH_SCENE.instantiate() as SpiritSlashEffect
	slash.setup(player)
	add_child(slash)
	slash.set_level(5)
	var d := AugmentScaling.native_d(player)
	var total := 0.0
	for i in range(6000):
		total += slash._roll_hit_damage()
	var mean := total / 6000.0
	_check(absf(mean - d * 2.4 * 2.4) / (d * 2.4 * 2.4) < 0.02, "Spirit Slash Lv.5 averages 2.4 D x potency 2.4 (%.1f vs %.1f)" % [mean, d * 2.4 * 2.4])
	var target := _spawn(Vector2(50, 0))
	slash._try_cast(true)
	_check(_lost(target) > 0.0, "a cast cuts the nearest enemy")
	slash.queue_free()
	_cleanup()


func _test_hex(player: Node) -> void:
	var hex := HEX_SCENE.instantiate() as HexBlinkMarkEffect
	hex.setup(player)
	add_child(hex)
	hex.set_level(3)
	_check(_near(hex.mark_bonus(), AugmentScaling.native_d(player) * 3.0 * AugmentScaling.potency(3)), "Blink Hex marks attacks for 3 D x potency")
	_check(hex.marked_shots == 2, "Lv.3 marks two attacks")
	hex.queue_free()


func _test_spiders(player: Node) -> void:
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(1)
	_check(summoner.spider_cap() == 7, "Lv.1 keeps at most seven spiderlings")
	summoner.set_level(20)
	_check(summoner.spider_cap() == 14, "and never more than fourteen")
	var total := 0.0
	for i in range(4000):
		total += summoner._roll_explosion_damage(0.0)
	var expected := AugmentScaling.native_d(player) * 1.4 * AugmentScaling.potency(20)
	_check(absf(total / 4000.0 - expected) / expected < 0.02, "detonations average 1.4 D x potency (%.1f vs %.1f)" % [total / 4000.0, expected])
	summoner.queue_free()


func _test_shield(player: Node) -> void:
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.setup(player)
	add_child(shield)
	shield.set_level(4)
	var floor_damage := AugmentScaling.native_d(player) * 1.2 * AugmentScaling.potency(4)
	_check(_near(shield.perfect_zap_damage(1.0), floor_damage), "a perfect parry of a weak round still zaps for 1.2 D x potency")
	_check(shield.perfect_zap_damage(10000.0) > floor_damage, "a heavy round's share wins when it is larger")
	shield.queue_free()


func _test_level_paths() -> void:
	Global.permanent_augment_ids = [&"augment_tesla_aura", StringName(), StringName()]
	Global.attempt_augment_levels = {"augment_tesla_aura": 7}
	var upgrade := MCE_UpgradeEquippedAugments.new()
	upgrade.amount = 2
	upgrade.apply(Global)
	_check(Global.get_augment_level(&"augment_tesla_aura") == 9, "the Doctrine's level grant no longer pulls Lv.7 down to 5 (got %d)" % Global.get_augment_level(&"augment_tesla_aura"))
	Global.attempt_augment_levels = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
