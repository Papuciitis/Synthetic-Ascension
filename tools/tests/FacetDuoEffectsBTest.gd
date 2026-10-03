extends Node

# Facets and Duos on the Spiderlings, the Shield and the Core
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §1, §2). Each
# Facet against the live effect and live enemies: Swarm and Venom Sacs,
# Riposte and Long Guard, Second Wind and Iron Lung; that a Facet lands
# once however often the runner repeats set_level / set_transcended /
# set_facet; then Static Brood and Bulwark Engine, active and not.
#
# Run: <godot> --headless --path . res://tools/tests/FacetDuoEffectsBTest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const DeathContext = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
const SPIDER_SCENE = preload("res://effects/augments/scenes/SpiderlingSummonEffect.tscn")
const SHIELD_SCENE = preload("res://effects/augments/scenes/ReflectedShieldEffect.tscn")
const CORE_SCENE = preload("res://effects/augments/scenes/StaminaCoreEffect.tscn")
const REFLECTED_SCRIPT = preload("res://effects/augments/logic/ReflectedProjectile.gd")
const FIXTURE_HP := 100000.0

const SPIDERLINGS := &"augment_summon_spiderlings"
const SHIELD := &"augment_reflect_shield"
const CORE := &"augment_stamina_core"
const TESLA := &"augment_tesla_aura"


class TestPlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats: Stats = Stats.new()
	var hp: float = 100.0
	var max_hp: float = 100.0
	var healed: float = 0.0
	var invulnerable_for: float = 0.0

	func heal(amount: float, _source: StringName = &"generic") -> void:
		healed += amount

	func grant_invulnerability(seconds: float) -> void:
		invulnerable_for = seconds


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


func _spawn(at: Vector2, health: float = FIXTURE_HP) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(&"facet_dummy", "res://facet_dummy.tscn", at, health, 0.0, 4.0, 0))
	_spawned.append(handle)
	return handle


func _cleanup() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"facet_test")
	_spawned.clear()


func _lost(handle: int, from: float = FIXTURE_HP) -> float:
	return from - EnemyWorld.get_health(handle) if EnemyWorld.is_valid_handle(handle) else from


func _facet(aug: StringName, facet: StringName, key: String) -> float:
	return AugmentFacets.value(aug, facet, key, -1.0)


func _duo(duo: StringName, key: String) -> float:
	return AugmentDuos.value(duo, key, -1.0)


## Spiderlings are scene nodes: free them all, then let a frame pass so a
## queued one is gone before the next group scan.
func _clear_spiders() -> void:
	for n in get_tree().get_nodes_in_group("spiderlings"):
		n.queue_free()
	await get_tree().process_frame


func _spiders() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("spiderlings"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.selected_style_id = &"ranged"
	Global.attempt_augment_duos = {}
	var player := TestPlayer.new()
	add_child(player)
	_test_no_compounding(player)
	await _test_swarm(player)
	await _test_venom_sacs(player)
	await _test_static_brood(player)
	await _test_riposte(player)
	_test_long_guard(player)
	_test_second_wind(player)
	_test_iron_lung(player)
	_test_bulwark_engine(player)
	await _clear_spiders()
	player.queue_free()
	Global.attempt_augment_duos = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	_cleanup()
	await get_tree().process_frame
	print("FacetDuoEffectsBTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- compounding

## The runner repeats its calls whenever level, Transcendence or Facet
## changes; a Facet must come out of the captured bases every time.
func _churn(effect: Node, level: int, facet: StringName) -> void:
	for i in range(3):
		effect.call("set_level", level)
		effect.call("set_facet", facet)
		effect.call("set_transcended", i % 2 == 0)
	effect.call("set_facet", facet)
	effect.call("set_level", level)


func _test_no_compounding(player: TestPlayer) -> void:
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(6)
	var spawn_plain := summoner.spawn_count
	var radius_plain := summoner.explosion_radius
	_churn(summoner, 6, &"swarm")
	_check(summoner.spawn_count == spawn_plain + int(_facet(SPIDERLINGS, &"swarm", "extra_spawn")), "Swarm adds its spiderlings once through repeated calls (%d -> %d)" % [spawn_plain, summoner.spawn_count])
	_churn(summoner, 6, &"venom_sacs")
	_check(_near(summoner.explosion_radius, radius_plain * _facet(SPIDERLINGS, &"venom_sacs", "radius_mul")) and summoner.spawn_count == spawn_plain, "Venom Sacs widens the blast once and Swarm's spiderlings leave with it (%.1f)" % summoner.explosion_radius)
	summoner.set_facet(&"")
	_check(_near(summoner.explosion_radius, radius_plain), "clearing the Facet restores the level's blast")
	summoner.queue_free()

	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.setup(player)
	add_child(shield)
	shield.set_level(6)
	var reflect_plain := shield.reflect_damage_mult
	var window_plain := shield.parry_window
	var cd_plain := shield.active_base_cd
	_churn(shield, 6, &"riposte")
	_check(_near(shield.reflect_damage_mult, reflect_plain * _facet(SHIELD, &"riposte", "reflect_mul")), "Riposte multiplies the reflection once through repeated calls (%.3f)" % shield.reflect_damage_mult)
	_churn(shield, 6, &"long_guard")
	_check(_near(shield.parry_window, window_plain * _facet(SHIELD, &"long_guard", "window_mul")) and _near(shield.active_base_cd, cd_plain * _facet(SHIELD, &"long_guard", "cooldown_mul")), "Long Guard multiplies window and cooldown once (%.3f s, %.3f s)" % [shield.parry_window, shield.active_base_cd])
	_check(_near(shield.reflect_damage_mult, reflect_plain), "and Riposte's reflection leaves with its Facet")
	shield.queue_free()

	var core := CORE_SCENE.instantiate() as StaminaCoreEffect
	core.setup(player)
	add_child(core)
	core.set_level(6)
	var core_cd_plain := core.active_base_cd
	var duration_plain := core.active_duration
	_churn(core, 6, &"iron_lung")
	_check(_near(core.active_base_cd, core_cd_plain * _facet(CORE, &"iron_lung", "cooldown_mul")) and _near(core.active_duration, duration_plain * _facet(CORE, &"iron_lung", "duration_mul")), "Iron Lung multiplies cooldown and duration once (%.2f s, %.2f s)" % [core.active_base_cd, core.active_duration])
	core.queue_free()


# ---------------------------------------------------------------- Spiderlings

func _test_swarm(player: TestPlayer) -> void:
	await _clear_spiders()
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(1)
	var plain_count := summoner.spawn_count
	var plain_bite := AugmentScaling.damage(player, summoner.bite_d, 1)
	summoner.set_facet(&"swarm")
	var bite_mul := _facet(SPIDERLINGS, &"swarm", "bite_mul")
	summoner._try_spawn()
	var brood := _spiders()
	_check(brood.size() == plain_count + int(_facet(SPIDERLINGS, &"swarm", "extra_spawn")), "a Swarm cast hatches %d spiderlings, not %d (%d)" % [plain_count + 2, plain_count, brood.size()])
	var thinned := true
	for spider in brood:
		if not _near(float(spider.get("bite_damage")), plain_bite * bite_mul):
			thinned = false
	_check(thinned and not brood.is_empty(), "every Swarm spiderling carries the x%.1f bite" % bite_mul)

	var target := _spawn(Vector2(900, 0))
	var spider: Node = brood[0] if not brood.is_empty() else null
	if spider != null:
		spider.call("_deal_bite", target, Vector2(900, 0))
		var factor := _lost(target) / (plain_bite * bite_mul)
		_check(_near(factor, 0.5) or _near(factor, 1.0) or _near(factor, 1.5), "and a live bite lands the thinned damage (%.2f)" % _lost(target))
	await _clear_spiders()

	summoner.set_transcended(true)
	Global._rng.seed = 2024
	for i in range(40):
		RunEvents.enemy_defeated.emit(DeathContext.new(0, &"dummy", Vector2(100, 0), 0, player, {}))
	var hatched := _spiders()
	var all_thinned := not hatched.is_empty()
	for s in hatched:
		if not _near(float(s.get("bite_damage")), plain_bite * bite_mul):
			all_thinned = false
	_check(all_thinned, "Brood Mother's hatchlings carry Swarm's bite too (%d hatched)" % hatched.size())
	await _clear_spiders()
	summoner.queue_free()
	_cleanup()


## One detonation of one spiderling at `at`; the global RNG is seeded first
## so a plain and a Venom Sacs blast roll the same d4.
func _detonate_one(summoner: SpiderlingSummonEffect, at: Vector2) -> void:
	await _clear_spiders()
	summoner._hatch(at)
	seed(77)
	summoner._detonate_all()
	await _clear_spiders()


func _test_venom_sacs(player: TestPlayer) -> void:
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(1)
	var at := Vector2(1500, 0)
	var radius_plain := summoner.explosion_radius
	var blast_mul := _facet(SPIDERLINGS, &"venom_sacs", "blast_mul")
	var radius_mul := _facet(SPIDERLINGS, &"venom_sacs", "radius_mul")
	var edge := radius_plain * (1.0 + radius_mul) * 0.5

	var near_plain := _spawn(at + Vector2(10, 0))
	var edge_plain := _spawn(at + Vector2(0, edge))
	await _detonate_one(summoner, at)
	var plain_hit := _lost(near_plain)
	_check(plain_hit > 0.0 and _lost(edge_plain) == 0.0, "a plain detonation misses an enemy %.0f px out (radius %.0f)" % [edge, radius_plain])
	_cleanup()

	summoner.set_facet(&"venom_sacs")
	var near_venom := _spawn(at + Vector2(10, 0))
	var edge_venom := _spawn(at + Vector2(0, edge))
	await _detonate_one(summoner, at)
	_check(_near(_lost(near_venom), plain_hit * blast_mul), "Venom Sacs detonates for x%.1f (%.2f vs %.2f)" % [blast_mul, _lost(near_venom), plain_hit])
	_check(_lost(edge_venom) > 0.0, "and its x%.1f blast reaches the enemy the plain one missed" % radius_mul)
	_cleanup()

	summoner.set_transcended(true)
	var hatched := summoner._hatch(at)
	_check(hatched != null and _near(float(hatched.get("_expiry_radius")), radius_plain * radius_mul), "a Brood Mother spiderling's expiry blast takes the wider radius")
	await _clear_spiders()
	summoner.queue_free()


func _test_static_brood(player: TestPlayer) -> void:
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(1)
	var leap_range := _duo(AugmentDuos.STATIC_BROOD, "range")
	var bitten_at := Vector2(-2000, 0)
	var bitten := _spawn(bitten_at)
	var neighbour := _spawn(bitten_at + Vector2(leap_range * 0.6, 0))
	var beyond := _spawn(bitten_at + Vector2(0, leap_range * 1.4))
	var spider := summoner._hatch(bitten_at + Vector2(-10, 0))
	_check(spider != null, "a spiderling to bite with")
	if spider == null:
		summoner.queue_free()
		_cleanup()
		return

	Global.permanent_augment_ids = [SPIDERLINGS, TESLA, StringName()]
	Global.attempt_augment_duos = {}
	spider.call("_deal_bite", bitten, bitten_at)
	_check(_lost(bitten) > 0.0 and _lost(neighbour) == 0.0 and EnemyWorld.get_stun_time(neighbour) <= 0.0, "without the Duo a bite stays on its target")

	Global.attempt_augment_duos = {String(AugmentDuos.STATIC_BROOD): true}
	Global.permanent_augment_ids = [SPIDERLINGS, StringName(), StringName()]
	spider.call("_deal_bite", bitten, bitten_at)
	_check(_lost(neighbour) == 0.0, "a taken Duo sleeps while Tesla Aura is unequipped")

	Global.permanent_augment_ids = [SPIDERLINGS, TESLA, StringName()]
	var before := _lost(bitten)
	spider.call("_deal_bite", bitten, bitten_at)
	var bite := _lost(bitten) - before
	_check(bite > 0.0 and _near(_lost(neighbour), bite), "Static Brood leaps the full bite to the nearest other enemy (%.2f, %.2f)" % [bite, _lost(neighbour)])
	_check(_near(EnemyWorld.get_stun_time(neighbour), _duo(AugmentDuos.STATIC_BROOD, "stun"), 0.05), "and stuns it for %.2f s" % EnemyWorld.get_stun_time(neighbour))
	_check(_lost(beyond) == 0.0, "an enemy beyond %.0f px is out of reach" % leap_range)

	Global.attempt_augment_duos = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	await _clear_spiders()
	summoner.queue_free()
	_cleanup()


# ---------------------------------------------------------------- Shield

func _reflections() -> Array:
	var out: Array = []
	for child in get_children():
		if child.get_script() == REFLECTED_SCRIPT and not child.is_queued_for_deletion():
			out.append(child)
	return out


func _clear_reflections() -> void:
	for child in _reflections():
		child.queue_free()


func _bullet(at: Vector2, damage: float) -> Dictionary:
	return {"position": at, "velocity": Vector2(-300, 0), "damage": damage}


func _test_riposte(player: TestPlayer) -> void:
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.setup(player)
	add_child(shield)
	shield.set_level(1)
	var mul := _facet(SHIELD, &"riposte", "reflect_mul")

	_clear_reflections()
	shield._reflect_simulated(_bullet(Vector2(3000, 3000), 10.0), false)
	var plain := _reflections()
	var plain_damage := float(plain[0].get("damage")) if plain.size() == 1 else -1.0
	_check(_near(plain_damage, 10.0 * shield.reflect_damage_mult), "a plain reflection returns %.2f of a 10-damage round" % plain_damage)
	_clear_reflections()

	shield.set_facet(&"riposte")
	shield._reflect_simulated(_bullet(Vector2(3000, 3000), 10.0), false)
	var sharp := _reflections()
	var sharp_damage := float(sharp[0].get("damage")) if sharp.size() == 1 else -1.0
	_check(_near(sharp_damage, plain_damage * mul), "Riposte's reflected round deals x%.1f (%.2f)" % [mul, sharp_damage])
	_clear_reflections()

	# At a level where the reflection sits on its 1.25 ceiling, Riposte
	# still multiplies past it.
	shield.set_facet(&"")
	shield.set_level(20)
	var capped := shield.reflect_damage_mult
	shield.set_facet(&"riposte")
	_check(_near(shield.reflect_damage_mult, capped * mul) and shield.reflect_damage_mult > 1.25, "Riposte is a true x%.1f past the level ceiling (%.3f -> %.3f)" % [mul, capped, shield.reflect_damage_mult])
	# The perfect zap reads the round as it would be without Riposte.
	var zapped := _spawn(Vector2(30, 0))
	var heavy := 400.0
	shield._on_perfect_reflect(Vector2.ZERO, heavy * shield.reflect_damage_mult)
	var expected_zap := shield.perfect_zap_damage(heavy * shield.reflect_damage_mult / mul)
	_check(_near(_lost(zapped), expected_zap), "Riposte leaves the perfect zap alone (%.1f, not %.1f)" % [_lost(zapped), shield.perfect_zap_damage(heavy * shield.reflect_damage_mult)])
	shield.queue_free()
	await get_tree().process_frame


func _test_long_guard(player: TestPlayer) -> void:
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.setup(player)
	add_child(shield)
	shield.set_level(20)
	var window_plain := shield.parry_window
	var cd_plain := shield.active_base_cd
	shield.set_facet(&"long_guard")
	var window_mul := _facet(SHIELD, &"long_guard", "window_mul")
	_check(_near(shield.parry_window, window_plain * window_mul) and shield.parry_window > 0.24, "Long Guard opens x%.1f past the 0.24 s ceiling (%.3f s)" % [window_mul, shield.parry_window])
	_check(_near(shield.active_base_cd, cd_plain * _facet(SHIELD, &"long_guard", "cooldown_mul")), "and costs x1.3 cooldown (%.3f s)" % shield.active_base_cd)
	player.invulnerable_for = 0.0
	shield._open_window()
	_check(_near(shield._active_left, shield.parry_window) and _near(player.invulnerable_for, shield.parry_window), "an opened ward lasts, and guards, the longer window")
	# The cooldown never ends inside the window it guards: without the floor
	# Long Guard chained a pressed shield into unbroken invulnerability.
	for level in [6, 8, 20]:
		shield.set_level(level)
		shield._cd = 0.0
		shield._try_activate()
		_check(shield._cd_max >= shield.parry_window + ReflectShieldEffect.PARRY_GAP - 0.0001, "Lv.%d: the cooldown (%.3f s) outlasts the window (%.3f s)" % [level, shield._cd_max, shield.parry_window])
	shield.set_facet(&"")
	shield.set_level(8)
	shield._cd = 0.0
	shield._try_activate()
	_check(shield._cd_max >= shield.parry_window + ReflectShieldEffect.PARRY_GAP - 0.0001, "and a plain Lv.8 shield too (%.3f s against %.3f s)" % [shield._cd_max, shield.parry_window])
	shield.queue_free()


# ---------------------------------------------------------------- Core

func _test_second_wind(player: TestPlayer) -> void:
	var core := CORE_SCENE.instantiate() as StaminaCoreEffect
	core.setup(player)
	add_child(core)
	core.set_level(1)
	player.healed = 0.0
	core._try_activate()
	_check(player.healed == 0.0, "a plain activation mends nothing")

	core.set_facet(&"second_wind")
	var fraction := _facet(CORE, &"second_wind", "heal_fraction")
	core._cd = 0.0
	core._try_activate()
	_check(_near(player.healed, player.max_hp * fraction), "Second Wind: pressing heals %.0f%% of max HP (%.1f)" % [fraction * 100.0, player.healed])

	core.set_transcended(true)
	player.healed = 0.0
	core._cd = 0.0
	core._active_time = 0.0
	player.hp = 30.0
	core._process(0.016)
	_check(core._active_time > 0.0 and _near(player.healed, player.max_hp * fraction, 0.01), "and Undying's own activation heals too (%.1f)" % player.healed)
	player.hp = 100.0
	core.queue_free()


func _test_iron_lung(player: TestPlayer) -> void:
	var core := CORE_SCENE.instantiate() as StaminaCoreEffect
	core.setup(player)
	add_child(core)
	core.set_level(1)
	var cd_plain := core.active_base_cd
	var duration_plain := core.active_duration
	core.set_facet(&"iron_lung")
	core._try_activate()
	_check(_near(core._active_time, duration_plain * _facet(CORE, &"iron_lung", "duration_mul")), "Iron Lung's active window is x0.75 (%.2f s)" % core._active_time)
	_check(_near(core._cd_max, Global.doctrine_active_cooldown(maxf(3.0, cd_plain * _facet(CORE, &"iron_lung", "cooldown_mul")))), "and its cooldown x0.65 (%.2f s)" % core._cd_max)
	# The core grants invulnerability, so its cooldown always outlasts it:
	# at Lv.9 with Iron Lung and Haste the old 3 s floor met the 3 s
	# invulnerability and the core chained into unbroken invulnerability.
	core.set_level(9)
	player.stats.haste = 1.5
	core._cd = 0.0
	core._try_activate()
	_check(core._cd_max >= core.invuln_duration + StaminaCoreEffect.INVULN_GAP - 0.0001, "Lv.9 + Iron Lung + Haste: the cooldown (%.2f s) outlasts the invulnerability (%.2f s)" % [core._cd_max, core.invuln_duration])
	core.bulwark_refund(100.0)
	_check(core._cd >= core.invuln_duration + StaminaCoreEffect.INVULN_GAP - 0.0001, "and a refund right after activating stops short of it (%.2f s left)" % core._cd)
	core._since_activation = 999.0
	core.bulwark_refund(100.0)
	_check(core._cd == 0.0, "long after, a refund may take it to ready")
	player.stats.haste = 0.0
	core.queue_free()


# ---------------------------------------------------------------- Bulwark Engine

func _test_bulwark_engine(player: TestPlayer) -> void:
	var runner := AugmentRunner.new()
	add_child(runner)
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.set_meta("augment_id", SHIELD)
	runner.add_child(shield)
	shield.setup(player)
	shield.set_level(1)
	var core := CORE_SCENE.instantiate() as StaminaCoreEffect
	core.set_meta("augment_id", CORE)
	runner.add_child(core)
	core.setup(player)
	core.set_level(1)
	var reported: Array = [-1.0]
	core.active_cd_changed.connect(func(time_left: float, _max_cd: float) -> void: reported[0] = time_left)
	var heal_fraction := _duo(AugmentDuos.BULWARK_ENGINE, "heal_fraction")
	var refund := _duo(AugmentDuos.BULWARK_ENGINE, "cooldown_refund")

	Global.permanent_augment_ids = [SHIELD, CORE, StringName()]
	Global.attempt_augment_duos = {}
	core._cd = 10.0
	player.healed = 0.0
	shield._open_window()
	shield._reflect_simulated(_bullet(Vector2(4000, 4000), 10.0), true)
	_check(shield._perfect_used_this_cast, "the parry was perfect")
	_check(player.healed == 0.0 and core._cd == 10.0, "without the Duo a perfect parry neither heals nor refunds")

	Global.attempt_augment_duos = {String(AugmentDuos.BULWARK_ENGINE): true}
	shield._open_window()
	shield._reflect_simulated(_bullet(Vector2(4000, 4000), 10.0), true)
	_check(_near(player.healed, player.max_hp * heal_fraction), "Bulwark Engine: a perfect parry heals %.0f%% of max HP (%.1f)" % [heal_fraction * 100.0, player.healed])
	_check(_near(core._cd, 10.0 - refund), "and takes %.0f s off Stamina Core's cooldown (%.2f)" % [refund, core._cd])
	_check(_near(float(reported[0]), core._cd), "and the Core's HUD badge hears it (%.2f)" % float(reported[0]))

	# A perfect parry leaves the shield at 0.1 s, so a bullet stream could
	# be parried ten times a second: the mend is rate-limited.
	var cd_after_first := core._cd
	player.healed = 0.0
	shield._open_window()
	shield._reflect_simulated(_bullet(Vector2(4000, 4000), 10.0), true)
	_check(player.healed == 0.0 and _near(core._cd, cd_after_first), "a second perfect parry within a second neither heals nor refunds")

	shield._bulwark_last_ms = -1000000
	core._cd = refund * 0.5
	shield._open_window()
	shield._reflect_simulated(_bullet(Vector2(4000, 4000), 10.0), true)
	_check(core._cd == 0.0, "the refund never takes the cooldown below ready")

	Global.permanent_augment_ids = [SHIELD, StringName(), StringName()]
	shield._bulwark_last_ms = -1000000
	core._cd = 10.0
	player.healed = 0.0
	shield._open_window()
	shield._reflect_simulated(_bullet(Vector2(4000, 4000), 10.0), true)
	_check(player.healed == 0.0 and core._cd == 10.0, "a taken Duo sleeps while Stamina Core is unequipped")

	Global.attempt_augment_duos = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	_clear_reflections()
	runner.queue_free()
