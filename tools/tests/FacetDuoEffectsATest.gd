extends Node

# Facets and Duos on Magic Missile, Tesla Aura, Spirit Slash and Blink Hex
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §1-2). Each
# Facet against live enemies, each Duo active and inactive, Facets stacked
# on Transcendence, and that repeated set_level / set_transcended /
# set_facet calls never compound a Facet's multipliers.
#
# Run: <godot> --headless --path . res://tools/tests/FacetDuoEffectsATest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const TESLA_SCENE = preload("res://effects/augments/scenes/TeslaAuraEffect.tscn")
const MISSILE_EFFECT_SCENE = preload("res://effects/augments/scenes/MagicMissileEffect.tscn")
const MISSILE_SCENE = preload("res://effects/augments/scenes/MagicMissileProjectile.tscn")
const SLASH_SCENE = preload("res://effects/augments/scenes/SpiritSlashEffect.tscn")
const HEX_SCENE = preload("res://effects/augments/scenes/HexBlinkMarkEffect.tscn")
const FIXTURE_HP := 100000.0

const MISSILE := &"augment_magic_missile"
const TESLA := &"augment_tesla_aura"
const SLASH := &"augment_spirit_slash"
const HEX := &"augment_blink_hex"


class TestPlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats: Stats = Stats.new()
	var hp: float = 100.0
	var max_hp: float = 100.0
	var aim: Vector2 = Vector2.ZERO

	func heal(_amount: float, _source: StringName = &"generic") -> void:
		pass

	func grant_invulnerability(_seconds: float) -> void:
		pass

	func _current_aim_target() -> Vector2:
		return aim


## Stands in for the AugmentRunner: Phantom Step finds the Slash through it.
class FakeRunner:
	extends Node

	func effect_for(aug_id: StringName) -> Node:
		for n in get_children():
			if StringName(str(n.get_meta("augment_id", ""))) == aug_id:
				return n
		return null


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
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(&"facet_dummy", "res://facet_dummy.tscn", position, health, 0.0, 4.0, 0))
	_spawned.append(handle)
	return handle


func _cleanup() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"facet_test")
	_spawned.clear()


func _lost(handle: int, from: float = FIXTURE_HP) -> float:
	return from - EnemyWorld.get_health(handle) if EnemyWorld.is_valid_handle(handle) else from


func _equip(augments: Array, duos: Array) -> void:
	var typed: Array[StringName] = []
	typed.assign(augments)
	while typed.size() < 3:
		typed.append(StringName())
	Global.permanent_augment_ids = typed
	Global.attempt_augment_duos = {}
	for duo in duos:
		Global.attempt_augment_duos[String(duo)] = true


func _facet_value(aug: StringName, facet: StringName, key: String) -> float:
	return AugmentFacets.value(aug, facet, key, -999.0)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.selected_style_id = &"ranged"
	var player := TestPlayer.new()
	add_child(player)
	_test_no_compounding(player)
	_test_salvo(player)
	_test_lance(player)
	_test_overcharge(player)
	_test_static_field(player)
	_test_crown_with_overcharge(player)
	_test_slipstream_coil(player)
	_test_lightning_rods(player)
	_test_hemorrhage(player)
	_test_executioner(player)
	_test_long_step(player)
	_test_deep_mark(player)
	_test_phantom_step(player)
	player.queue_free()
	_equip([], [])
	_cleanup()
	await get_tree().process_frame
	print("FacetDuoEffectsATest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- no compounding

func _test_no_compounding(player: TestPlayer) -> void:
	var missile := MISSILE_EFFECT_SCENE.instantiate() as MagicMissileEffect
	missile.setup(player)
	add_child(missile)
	missile.set_level(3)
	var plain_mult := missile.damage_mult
	var plain_burst := missile.burst_count
	for i in range(3):
		missile.set_facet(&"salvo")
		missile.set_level(3)
		missile.set_transcended(false)
	_check(_near(missile.damage_mult, plain_mult * _facet_value(MISSILE, &"salvo", "damage_mul")), "Salvo's damage multiplier applies once however often it is set (%.3f)" % missile.damage_mult)
	_check(missile.burst_count == plain_burst + int(_facet_value(MISSILE, &"salvo", "extra_missiles")), "and its extra missiles once (%d)" % missile.burst_count)
	missile.set_facet(&"")
	_check(_near(missile.damage_mult, plain_mult) and missile.burst_count == plain_burst, "clearing the Facet restores the plain volley")
	missile.queue_free()

	var tesla := TESLA_SCENE.instantiate() as TeslaAuraEffect
	tesla.setup(player)
	add_child(tesla)
	tesla.set_level(2)
	var plain_radius := tesla.radius
	var plain_targets := tesla.max_targets
	var plain_zap := tesla.damage_mult
	for i in range(3):
		tesla.set_facet(&"static_field")
		tesla.set_level(2)
		tesla.set_transcended(true)
	_check(_near(tesla.radius, plain_radius * _facet_value(TESLA, &"static_field", "radius_mul")), "Static Field's radius applies once (%.1f)" % tesla.radius)
	_check(_near(tesla.damage_mult, plain_zap * _facet_value(TESLA, &"static_field", "damage_mul")) and _near(tesla.zap_stun, _facet_value(TESLA, &"static_field", "stun")), "and its damage and stun once (%.3f, %.2f s)" % [tesla.damage_mult, tesla.zap_stun])
	for i in range(3):
		tesla.set_facet(&"overcharge")
		tesla.set_level(2)
	_check(tesla.max_targets == maxi(1, plain_targets + int(_facet_value(TESLA, &"overcharge", "target_delta"))), "Overcharge's targets apply once (%d)" % tesla.max_targets)
	_check(_near(tesla.damage_mult, plain_zap * _facet_value(TESLA, &"overcharge", "damage_mul")) and _near(tesla.zap_stun, 0.0), "and its damage once, with Static Field's stun gone (%.3f)" % tesla.damage_mult)
	tesla.queue_free()

	var slash := SLASH_SCENE.instantiate() as SpiritSlashEffect
	slash.setup(player)
	add_child(slash)
	slash.set_level(2)
	var plain_duration := slash.bleed_duration
	var plain_tick := slash.bleed_tick_mult_of_hit
	for i in range(3):
		slash.set_facet(&"hemorrhage")
		slash.set_level(2)
	_check(_near(slash.bleed_duration, plain_duration * _facet_value(SLASH, &"hemorrhage", "bleed_duration_mul")) and _near(slash.bleed_tick_mult_of_hit, plain_tick * _facet_value(SLASH, &"hemorrhage", "bleed_mul")), "Hemorrhage's bleed applies once (%.2f s, %.3f)" % [slash.bleed_duration, slash.bleed_tick_mult_of_hit])
	slash.queue_free()

	var hex := HEX_SCENE.instantiate() as HexBlinkMarkEffect
	hex.setup(player)
	add_child(hex)
	hex.set_level(2)
	var plain_range := hex.blink_range
	var plain_cd := hex.active_base_cd
	for i in range(3):
		hex.set_facet(&"long_step")
		hex.set_level(2)
		hex.set_transcended(false)
	_check(_near(hex.blink_range, plain_range * _facet_value(HEX, &"long_step", "range_mul")) and _near(hex.active_base_cd, plain_cd * _facet_value(HEX, &"long_step", "cooldown_mul")), "Long Step's range and cooldown apply once (%.0f px, %.2f s)" % [hex.blink_range, hex.active_base_cd])
	hex.queue_free()


# ---------------------------------------------------------------- Magic Missile

## Runs the effect until its volley is spent; returns the missiles it fired
## at `handle`, removed from the tree.
func _fire_volley(missile: MagicMissileEffect, handle: int) -> Array:
	for i in range(30):
		missile._process(0.2)
	var fired: Array = []
	for child in get_children():
		if child is MagicMissileProjectile and not child.is_queued_for_deletion() and child.is_physics_processing() and int(child.get("target_handle")) == handle:
			fired.append({"damage": float(child.get("damage"))})
			child.call("_despawn")
	return fired


func _missile_effect(player: TestPlayer, facet: StringName) -> MagicMissileEffect:
	var missile := MISSILE_EFFECT_SCENE.instantiate() as MagicMissileEffect
	missile.setup(player)
	add_child(missile)
	missile.set_level(1)
	missile.set_facet(facet)
	missile.base_cooldown = 100.0  # one volley per test
	return missile


func _test_salvo(player: TestPlayer) -> void:
	var target := _spawn(Vector2(300, 0))
	var plain := _missile_effect(player, &"")
	var plain_volley := _fire_volley(plain, target)
	plain.queue_free()
	var salvo := _missile_effect(player, &"salvo")
	var volley := _fire_volley(salvo, target)
	salvo.queue_free()
	var each := AugmentScaling.damage(player, 0.45 * _facet_value(MISSILE, &"salvo", "damage_mul"), 1)
	_check(plain_volley.size() == 2 and volley.size() == plain_volley.size() + 2, "Salvo fires 2 more missiles a volley (%d vs %d)" % [volley.size(), plain_volley.size()])
	_check(volley.size() > 0 and volley.all(func(m: Dictionary) -> bool: return _near(float(m["damage"]), each)), "each for x0.75 (%.2f)" % each)
	_cleanup()


func _test_lance(player: TestPlayer) -> void:
	var far := _spawn(Vector2(1000, 0))
	var plain := _missile_effect(player, &"")
	_check(_fire_volley(plain, far).is_empty(), "an ordinary missile does not seek 1000 px")
	plain.queue_free()
	var lance := _missile_effect(player, &"lance")
	var volley := _fire_volley(lance, far)
	_check(volley.size() == 1, "Lance seeks x1.5 farther and halves the volley of 2 to 1 (%d)" % volley.size())
	_check(volley.size() == 1 and _near(float(volley[0]["damage"]), AugmentScaling.damage(player, 0.45 * _facet_value(MISSILE, &"lance", "damage_mul"), 1)), "each Lance missile hits x2.2")
	lance.set_transcended(true)
	_check(lance.burst_count == 1, "Choir's extra missile then halves too, never below one (%d)" % lance.burst_count)
	lance.queue_free()
	_cleanup()


# ---------------------------------------------------------------- Tesla Aura

func _tesla(player: TestPlayer, facet: StringName) -> TeslaAuraEffect:
	var tesla := TESLA_SCENE.instantiate() as TeslaAuraEffect
	tesla.setup(player)
	add_child(tesla)
	tesla.set_level(1)
	tesla.set_facet(facet)
	return tesla


func _test_overcharge(player: TestPlayer) -> void:
	var ring := [_spawn(Vector2(50, 0)), _spawn(Vector2(0, 60)), _spawn(Vector2(-70, 0)), _spawn(Vector2(0, -80))]
	var tesla := _tesla(player, &"overcharge")
	tesla._process(1.0)
	var struck := 0
	var each := true
	var zap := AugmentScaling.native_d(player) * 0.5 * _facet_value(TESLA, &"overcharge", "damage_mul")
	for handle in ring:
		if _lost(handle) > 0.0:
			struck += 1
			each = each and _near(_lost(handle), zap)
	_check(struck == 2, "Overcharge strikes 2 fewer of four in reach (%d)" % struck)
	_check(each, "each zap x1.7 (%.2f)" % zap)
	tesla.queue_free()
	_cleanup()


func _test_static_field(player: TestPlayer) -> void:
	var edge := _spawn(Vector2(210, 0))
	var plain := _tesla(player, &"")
	plain._process(1.0)
	_check(_lost(edge) == 0.0 and EnemyWorld.get_stun_time(edge) <= 0.0, "an ordinary aura neither reaches 210 px nor stuns")
	plain.queue_free()
	var field := _tesla(player, &"static_field")
	field._process(1.0)
	_check(_near(_lost(edge), AugmentScaling.native_d(player) * 0.5 * _facet_value(TESLA, &"static_field", "damage_mul")), "Static Field's x1.3 ring reaches it for x0.85 (%.2f)" % _lost(edge))
	_check(_near(EnemyWorld.get_stun_time(edge), _facet_value(TESLA, &"static_field", "stun"), 0.05), "and the zap stuns 0.15 s (%.2f)" % EnemyWorld.get_stun_time(edge))
	field.queue_free()
	_cleanup()


func _test_crown_with_overcharge(player: TestPlayer) -> void:
	var first := _spawn(Vector2(200, 0))
	var second := _spawn(Vector2(330, 0))
	var tesla := _tesla(player, &"overcharge")
	tesla.set_transcended(true)
	tesla._process(1.0)
	var zap := AugmentScaling.native_d(player) * 0.5 * _facet_value(TESLA, &"overcharge", "damage_mul")
	_check(_near(_lost(first), zap), "Storm Crown + Overcharge: the crown's reach, the facet's zap (%.2f)" % _lost(first))
	_check(_near(_lost(second), zap * 0.7), "and the crown's chain carries the heavier zap (%.2f)" % _lost(second))
	tesla.queue_free()
	_cleanup()


func _test_slipstream_coil(player: TestPlayer) -> void:
	var target := _spawn(Vector2(60, 0))
	player.global_position = Vector2.ZERO
	_equip([TESLA, &"augment_sprint_servos"], [])
	var tesla := _tesla(player, &"")
	player.global_position = Vector2(5, 0)
	tesla._process(0.4)
	_check(_lost(target) == 0.0, "without Slipstream Coil a moving aura waits its full 0.55 s")
	tesla.queue_free()

	_equip([TESLA, &"augment_sprint_servos"], [AugmentDuos.SLIPSTREAM_COIL])
	tesla = _tesla(player, &"")
	player.global_position = Vector2(10, 0)
	tesla._process(0.4)
	var after_moving := _lost(target)
	_check(after_moving > 0.0, "Slipstream Coil: while moving it pulses 50% faster (0.4 s)")
	tesla._process(0.4)
	_check(_near(_lost(target), after_moving), "standing still it keeps its full interval")
	_check(_near(tesla.current_tick_interval(), tesla.tick_interval), "and reads its plain interval at rest")
	tesla.queue_free()
	_equip([], [])
	player.global_position = Vector2.ZERO
	_cleanup()


# ---------------------------------------------------------------- Lightning Rods

func _step_missiles(missiles: Array) -> void:
	for i in range(6):
		for m in missiles:
			if is_instance_valid(m) and m.is_inside_tree() and m.is_physics_processing():
				m.call("_physics_process", 0.1)


func _shards_of(main: Node, targets: Array) -> Array:
	var out: Array = []
	for child in get_children():
		if child is MagicMissileProjectile and child != main and not child.is_queued_for_deletion() and child.is_physics_processing() and int(child.get("target_handle")) in targets:
			out.append(child)
	return out


func _test_lightning_rods(player: TestPlayer) -> void:
	seed(7)
	var rod := AugmentDuos.value(AugmentDuos.LIGHTNING_RODS, "damage_mul")
	# A struck enemy, two in arc range, a third farther than the nearest two
	# and one beyond the range.
	for active in [false, true]:
		_equip([MISSILE, TESLA], [AugmentDuos.LIGHTNING_RODS] if active else [])
		var struck := _spawn(Vector2(40, 0))
		var near_a := _spawn(Vector2(40, 100))
		var near_b := _spawn(Vector2(40, -110))
		var third := _spawn(Vector2(180, 0))
		var beyond := _spawn(Vector2(40, 400))
		var missile := MISSILE_SCENE.instantiate() as MagicMissileProjectile
		missile.global_position = Vector2.ZERO
		missile.speed = 100.0
		missile.hit_radius = 6.0
		add_child(missile)
		missile.setup_handle(struck, 10.0, Vector2.RIGHT, player)
		missile.set_split(0, null, 0.6)
		missile.call("_physics_process", 1.0)
		if active:
			_check(_near(_lost(struck), 10.0), "Lightning Rods: the missile lands its own hit")
			_check(_near(_lost(near_a), 10.0 * rod) and _near(_lost(near_b), 10.0 * rod), "and arcs to the two nearest for 60%% (%.1f, %.1f)" % [_lost(near_a), _lost(near_b)])
			_check(_lost(third) == 0.0 and _lost(beyond) == 0.0, "no further than two arcs, none past 170 px")
		else:
			_check(_lost(near_a) == 0.0 and _lost(near_b) == 0.0, "without the Duo a missile hit does not arc")
		_cleanup()

	# Shards arc too: A splits into one shard that strikes B; B's own arcs
	# reach C, which nothing else could.
	_equip([MISSILE, TESLA], [AugmentDuos.LIGHTNING_RODS])
	var a := _spawn(Vector2(40, 0))
	var b := _spawn(Vector2(40, 160))
	var c := _spawn(Vector2(40, 320))
	var main := MISSILE_SCENE.instantiate() as MagicMissileProjectile
	main.global_position = Vector2.ZERO
	main.speed = 100.0
	main.hit_radius = 6.0
	add_child(main)
	main.setup_handle(a, 10.0, Vector2.RIGHT, player)
	main.set_split(1, MISSILE_SCENE, 0.6)
	main.call("_physics_process", 1.0)
	var shards := _shards_of(main, [b])
	_check(shards.size() == 1, "Choir still splits beside the Duo (%d shard)" % shards.size())
	for shard in shards:
		shard.set("speed", 400.0)
		shard.set("hit_radius", 12.0)
	_step_missiles(shards)
	_check(_near(_lost(b), 10.0 * rod + 6.0), "B takes A's arc and the shard (%.1f)" % _lost(b))
	_check(_near(_lost(c), 6.0 * rod), "the shard's hit arcs on to C for 60%% of the shard (%.2f)" % _lost(c))
	_equip([], [])
	_cleanup()


# ---------------------------------------------------------------- Spirit Slash

func _slash(player: TestPlayer, facet: StringName) -> SpiritSlashEffect:
	var slash := SLASH_SCENE.instantiate() as SpiritSlashEffect
	slash.setup(player)
	add_child(slash)
	slash.set_level(1)
	slash.set_facet(facet)
	return slash


func _bleed(handle: int) -> Variant:
	var by_kind: Variant = EnemyStatus._by_handle.get(handle)
	if by_kind is Dictionary:
		return (by_kind as Dictionary).get(EnemyStatusService.BLEED)
	return null


func _test_hemorrhage(player: TestPlayer) -> void:
	var plain_target := _spawn(Vector2(30, 0))
	var bled_target := _spawn(Vector2(30, 50))
	var plain := _slash(player, &"")
	seed(99)
	plain._cut(plain_target)
	var hemorrhage := _slash(player, &"hemorrhage")
	seed(99)
	hemorrhage._cut(bled_target)
	_check(_near(_lost(bled_target), _lost(plain_target) * _facet_value(SLASH, &"hemorrhage", "damage_mul")), "Hemorrhage: the same roll cuts x0.8 (%.2f vs %.2f)" % [_lost(bled_target), _lost(plain_target)])
	var plain_bleed: Variant = _bleed(plain_target)
	var bled: Variant = _bleed(bled_target)
	_check(plain_bleed != null and bled != null, "both cuts open a bleed")
	if plain_bleed != null and bled != null:
		_check(_near(bled.damage_per_tick_per_stack, plain_bleed.damage_per_tick_per_stack * _facet_value(SLASH, &"hemorrhage", "bleed_mul")), "the bleed ticks twice as hard (%.3f vs %.3f)" % [bled.damage_per_tick_per_stack, plain_bleed.damage_per_tick_per_stack])
		_check(_near(bled.time_left, plain_bleed.time_left * _facet_value(SLASH, &"hemorrhage", "bleed_duration_mul")), "for twice as long (%.1f s)" % bled.time_left)
	plain.queue_free()
	hemorrhage.queue_free()
	_cleanup()


func _test_executioner(player: TestPlayer) -> void:
	var healthy := _spawn(Vector2(30, 0))
	var wounded := _spawn(Vector2(30, 50))
	var wounded_plain := _spawn(Vector2(30, -50))
	var cut_to := FIXTURE_HP * 0.2
	EnemyCombat.apply_damage(wounded, FIXTURE_HP - cut_to)
	EnemyCombat.apply_damage(wounded_plain, FIXTURE_HP - cut_to)
	var plain := _slash(player, &"")
	var executioner := _slash(player, &"executioner")
	seed(5)
	executioner._cut(healthy)
	var healthy_loss := _lost(healthy)
	seed(5)
	executioner._cut(wounded)
	seed(5)
	plain._cut(wounded_plain)
	_check(_lost(wounded, cut_to) > 0.0 and _near(_lost(wounded, cut_to), healthy_loss * _facet_value(SLASH, &"executioner", "damage_mul")), "Executioner cuts x2 under 30%% health (%.2f vs %.2f)" % [_lost(wounded, cut_to), healthy_loss])
	_check(_near(_lost(wounded_plain, cut_to), healthy_loss), "an ordinary slash does not (%.2f)" % _lost(wounded_plain, cut_to))
	plain.queue_free()
	executioner.queue_free()
	_cleanup()


# ---------------------------------------------------------------- Blink Hex

func _hex(player: TestPlayer, facet: StringName, parent: Node = null) -> HexBlinkMarkEffect:
	var hex := HEX_SCENE.instantiate() as HexBlinkMarkEffect
	hex.set_meta("augment_id", HEX)
	hex.setup(player)
	(parent if parent != null else self).add_child(hex)
	hex.set_level(1)
	hex.set_facet(facet)
	return hex


func _clear_mark_meta(player: TestPlayer) -> void:
	for key in ["hex_mark_shots_left", "hex_mark_d8_count", "hex_mark_bonus", "hex_mark_power_scale", "hex_mark_flat"]:
		if player.has_meta(key):
			player.remove_meta(key)


func _test_long_step(player: TestPlayer) -> void:
	player.global_position = Vector2.ZERO
	player.aim = Vector2(2000, 0)
	var plain := _hex(player, &"")
	plain._try_cast()
	var plain_reach := player.global_position.x
	var plain_cd := plain._cd_max
	plain.queue_free()
	player.global_position = Vector2.ZERO
	var long_step := _hex(player, &"long_step")
	long_step._try_cast()
	_check(_near(player.global_position.x, plain_reach * _facet_value(HEX, &"long_step", "range_mul")), "Long Step blinks x1.6 as far (%.0f vs %.0f px)" % [player.global_position.x, plain_reach])
	_check(_near(long_step._cd_max, plain_cd * _facet_value(HEX, &"long_step", "cooldown_mul")), "on x0.75 the cooldown (%.2f s)" % long_step._cd_max)
	long_step.queue_free()
	player.global_position = Vector2.ZERO
	_clear_mark_meta(player)


func _test_deep_mark(player: TestPlayer) -> void:
	player.global_position = Vector2.ZERO
	player.aim = Vector2(100, 0)
	var plain := _hex(player, &"")
	plain._try_cast()
	var plain_shots := int(player.get_meta("hex_mark_shots_left", 0))
	var plain_bonus := float(player.get_meta("hex_mark_bonus", 0.0))
	plain.queue_free()
	_clear_mark_meta(player)
	player.global_position = Vector2.ZERO
	var deep := _hex(player, &"deep_mark")
	deep.set_transcended(true)
	deep._try_cast()
	_check(int(player.get_meta("hex_mark_shots_left", 0)) == plain_shots + 1 + int(_facet_value(HEX, &"deep_mark", "extra_marks")), "Deep Mark marks one more attack, on top of Hexgate's (%d)" % int(player.get_meta("hex_mark_shots_left", 0)))
	_check(plain_bonus > 0.0 and _near(float(player.get_meta("hex_mark_bonus", 0.0)), plain_bonus * _facet_value(HEX, &"deep_mark", "damage_mul")), "and each mark carries x1.5 (%.2f vs %.2f)" % [float(player.get_meta("hex_mark_bonus", 0.0)), plain_bonus])
	deep.queue_free()
	player.global_position = Vector2.ZERO
	_clear_mark_meta(player)


func _test_phantom_step(player: TestPlayer) -> void:
	for active in [false, true]:
		_equip([HEX, SLASH], [AugmentDuos.PHANTOM_STEP] if active else [])
		var runner := FakeRunner.new()
		add_child(runner)
		var slash := SLASH_SCENE.instantiate() as SpiritSlashEffect
		slash.set_meta("augment_id", SLASH)
		slash.setup(player)
		runner.add_child(slash)
		slash.set_level(1)
		slash._cd = 1.5
		var hex := _hex(player, &"", runner)
		# Open Circuit's cross-lock: a pressed active locks the others. The
		# free cut is not a press, so the Slash's slot must stay as the
		# blink alone left it.
		Global.set_doctrine_rule(&"active_augment_cross_lock_seconds", 2.0)
		hex.set_meta("hud_slot_index", 0)
		slash.set_meta("hud_slot_index", 1)
		player.global_position = Vector2.ZERO
		player.aim = Vector2(300, 0)
		var nearest := [_spawn(Vector2(330, 0)), _spawn(Vector2(300, 40)), _spawn(Vector2(250, 0))]
		var fourth := _spawn(Vector2(300, -90))
		var outside := _spawn(Vector2(300, 260))
		hex._try_cast()
		var cut := 0
		for handle in nearest:
			if _lost(handle) > 0.0:
				cut += 1
		if active:
			_check(cut == 3, "Phantom Step: a blink cuts the 3 enemies nearest where it lands (%d)" % cut)
			_check(_lost(fourth) == 0.0 and _lost(outside) == 0.0, "and no fourth, none beyond 220 px")
			_check(_near(slash._cd, 1.5), "the free slash spends no cooldown (%.2f)" % slash._cd)
			_check(Global.active_augment_slot_blocked(1) and not Global.active_augment_slot_blocked(0), "and adds no cross-lock of its own: only the Hex's press locked the Slash's slot")
			_check(slash.phantom_cut(Vector2(300, 0), 2) == 2, "phantom_cut reports how many it cut")
			_check(slash.phantom_cut(Vector2(5000, 0), 3) == 0, "and none where nothing stands")
		else:
			_check(cut == 0, "without the Duo a blink cuts nothing")
		hex.queue_free()
		runner.queue_free()
		_clear_mark_meta(player)
		_cleanup()
		Global.set_doctrine_rule(&"active_augment_cross_lock_seconds", 0.0)
		Global.notify_active_augment_used(-1)
	_equip([], [])
	player.global_position = Vector2.ZERO
