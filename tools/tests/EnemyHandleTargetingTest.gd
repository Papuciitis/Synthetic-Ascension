extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const RangedScene = preload("res://scenes/world/combat/RangedBullet.tscn")
const GenericProjectileScene = preload("res://core/combat/projectile/projectile.tscn")
const MissileScene = preload("res://effects/augments/scenes/MagicMissileProjectile.tscn")
const ReflectedScene = preload("res://effects/augments/scenes/ReflectedProjectile.tscn")
const SpiderlingScene = preload("res://effects/augments/scenes/PoisonSpiderling.tscn")
const ShieldScene = preload("res://effects/augments/scenes/ReflectedShieldEffect.tscn")
const MissileEffectScene = preload("res://effects/augments/scenes/MagicMissileEffect.tscn")
const MissileSpellScript = preload("res://spells/logic/MagicMissileSpell.gd")

class TestPlayer:
	extends Node2D
	var base_weapon_damage := 20.0
	var stats: Object = null

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


func _spawn(id: StringName, position: Vector2, health: float = 20.0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		position,
		health,
		0.0,
		4.0,
		0,
	))


func _remove(handles: Array[int]) -> void:
	for handle in handles:
		EnemyWorld.remove_enemy(handle, &"targeting_test")


func _run() -> void:
	var player := TestPlayer.new()
	add_child(player)

	var ranged_target := _spawn(&"ranged_data", Vector2(50.0, 0.0))
	var ranged := RangedScene.instantiate() as RangedBullet
	ranged.global_position = Vector2.ZERO
	ranged.velocity = Vector2(100.0, 0.0)
	ranged.damage = 5.0
	ranged.max_range = 1000.0
	ranged.source = player
	add_child(ranged)
	ranged.call("_physics_process", 1.0)
	_check(EnemyWorld.get_health(ranged_target) == 15.0, "scene-based ranged bullet sweeps through a data-only enemy")
	_remove([ranged_target])

	var generic_target := _spawn(&"generic_projectile_data", Vector2(50.0, 0.0))
	var generic_projectile := GenericProjectileScene.instantiate() as Area2D
	generic_projectile.global_position = Vector2.ZERO
	generic_projectile.set("velocity", Vector2(100.0, 0.0))
	generic_projectile.set("damage", 5.0)
	generic_projectile.set("source", player)
	add_child(generic_projectile)
	generic_projectile.call("_physics_process", 1.0)
	_check(EnemyWorld.get_health(generic_target) == 15.0, "generic weapon projectile sweeps through a data-only enemy")
	_remove([generic_target])

	var missile_target := _spawn(&"missile_data", Vector2(50.0, 0.0))
	var missile := MissileScene.instantiate() as MagicMissileProjectile
	missile.global_position = Vector2.ZERO
	missile.speed = 100.0
	missile.hit_radius = 4.0
	add_child(missile)
	_check(missile.has_method("setup_handle"), "homing missile accepts a generation-safe target handle")
	if missile.has_method("setup_handle"):
		missile.call("setup_handle", missile_target, 6.0, Vector2.RIGHT, player)
		missile.call("_physics_process", 1.0)
		_check(EnemyWorld.get_health(missile_target) == 14.0, "homing missile damages a data-only target")
	else:
		_check(false, "homing missile damages a data-only target")
	_remove([missile_target])

	var stale_target := _spawn(&"missile_stale", Vector2(50.0, 0.0))
	var stale_missile := MissileScene.instantiate() as MagicMissileProjectile
	stale_missile.global_position = Vector2.ZERO
	stale_missile.speed = 100.0
	add_child(stale_missile)
	stale_missile.setup_handle(stale_target, 20.0, Vector2.RIGHT, player)
	EnemyWorld.remove_enemy(stale_target, &"stale_target")
	var replacement_target := _spawn(&"missile_replacement", Vector2(50.0, 0.0))
	stale_missile.call("_physics_process", 1.0)
	_check(EnemyWorld.get_health(replacement_target) == 20.0, "stale homing handle cannot damage a replacement in the reused slot")
	_remove([replacement_target])

	var automatic_target := _spawn(&"automatic_missile_data", Vector2(45.0, 0.0))
	var missile_effect := MissileEffectScene.instantiate() as MagicMissileEffect
	missile_effect.debug_prints = false
	missile_effect.setup(player)
	add_child(missile_effect)
	var effect_target: Variant = missile_effect.call("_find_nearest_enemy", Vector2.ZERO, 100.0)
	_check(effect_target is int and int(effect_target) == automatic_target, "automatic missile effect acquires a data-only handle")
	var missile_spell := MissileSpellScript.new()
	missile_spell.caster = player
	add_child(missile_spell)
	var spell_target: Variant = missile_spell.call("_nearest_enemy")
	_check(spell_target is int and int(spell_target) == automatic_target, "magic missile spell acquires a data-only handle")
	missile_effect.queue_free()
	missile_spell.queue_free()
	_remove([automatic_target])

	var reflected_target := _spawn(&"reflected_data", Vector2(50.0, 0.0))
	var reflected := ReflectedScene.instantiate() as ReflectedProjectile
	reflected.global_position = Vector2.ZERO
	reflected.speed = 100.0
	add_child(reflected)
	reflected.setup(Vector2.RIGHT, 7.0, player)
	reflected.call("_process", 1.0)
	_check(EnemyWorld.get_health(reflected_target) == 13.0, "reflected bolt sweeps through a data-only enemy")
	_remove([reflected_target])

	var slash_target := _spawn(&"slash_data", Vector2(40.0, 0.0))
	var slash := SpiritSlashEffect.new()
	slash.range_px = 100.0
	slash.crit_chance = 0.0
	slash.bleed_min_stacks = 1
	slash.bleed_max_stacks = 1
	slash.setup(player)
	add_child(slash)
	slash.call("_try_cast")
	_check(EnemyWorld.get_health(slash_target) < 20.0, "Spirit Slash targets a data-only enemy")
	_check(EnemyStatus.has_status(slash_target, &"bleed"), "Spirit Slash attaches bleed by stable handle")
	slash.queue_free()
	_remove([slash_target])

	var chain_first := _spawn(&"chain_first", Vector2(30.0, 0.0))
	var chain_second := _spawn(&"chain_second", Vector2(60.0, 0.0))
	var arcs := ConduitArcBolts.new()
	arcs.setup(player)
	add_child(arcs)
	arcs.call("_on_weapon_fired", player, &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(EnemyWorld.get_health(chain_first) < 20.0, "chain lightning selects its first data-only target")
	_check(EnemyWorld.get_health(chain_second) < 20.0, "chain lightning excludes the first handle and reaches a second")
	arcs.queue_free()
	_remove([chain_first, chain_second])

	var spider_target := _spawn(&"spider_data", Vector2(25.0, 0.0))
	var spider := SpiderlingScene.instantiate() as PoisonSpiderling
	spider.global_position = Vector2.ZERO
	add_child(spider)
	spider.explode(5.0, 50.0, player)
	_check(EnemyWorld.get_health(spider_target) == 15.0, "spiderling explosion damages a data-only enemy")
	_remove([spider_target])

	var shield_near := _spawn(&"shield_near", Vector2(20.0, 0.0))
	var shield_far := _spawn(&"shield_far", Vector2(40.0, 0.0))
	var shield := ShieldScene.instantiate() as ReflectShieldEffect
	shield.setup(player)
	shield.perfect_zap_radius = 80.0
	shield.perfect_zap_max_targets = 1
	add_child(shield)
	shield.call("_on_perfect_reflect", Vector2.ZERO, 10.0)
	var shield_hits := int(EnemyWorld.get_health(shield_near) < 20.0) + int(EnemyWorld.get_health(shield_far) < 20.0)
	_check(shield_hits == 1, "perfect reflection reaches data-only enemies and preserves its target cap")
	shield.queue_free()
	_remove([shield_near, shield_far])

	player.queue_free()
	await get_tree().process_frame
	EnemyStatus.clear_all()
	print("EnemyHandleTargetingTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
