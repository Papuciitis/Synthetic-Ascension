extends Node

## Guards actual casts against random payloads, lost seeking volleys and
## targets outside their search radius. Fixtures use the real combat service,
## projectile movement, status ticks and the player's Hex consumer.
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PLAYER_SCRIPT = preload("res://core/actors/player/player.gd")
const MISSILE_EFFECT = preload("res://effects/augments/scenes/MagicMissileEffect.tscn")
const MISSILE = preload("res://effects/augments/scenes/MagicMissileProjectile.tscn")
const SLASH = preload("res://effects/augments/scenes/SpiritSlashEffect.tscn")
const HEX = preload("res://effects/augments/scenes/HexBlinkMarkEffect.tscn")
const SPIDERS = preload("res://effects/augments/scenes/SpiderlingSummonEffect.tscn")
const HP := 10000.0

class TestPlayer:
	extends Node2D
	var base_weapon_damage := 12.0
	var stats := Stats.new()
	func _current_aim_target() -> Vector2:
		return global_position

var _passes := 0
var _failures := 0
var _handles: Array[int] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.025

func _spawn(at: Vector2) -> int:
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"reliability_dummy", "res://reliability_dummy.tscn", at, HP, 0.0, 4.0, 0))
	_handles.append(handle)
	return handle

func _lost(handle: int) -> float:
	return HP - EnemyWorld.get_health(handle)

func _cleanup() -> void:
	for handle in _handles:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"reliability_test")
	_handles.clear()
	for child in get_children():
		if child is MagicMissileProjectile or child is PoisonSpiderling:
			child.free()

func _missiles() -> Array[MagicMissileProjectile]:
	var out: Array[MagicMissileProjectile] = []
	for child in get_children():
		if child is MagicMissileProjectile and not child.is_queued_for_deletion():
			out.append(child)
	return out

func _run() -> void:
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	Global.selected_style_id = &"ranged"
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.attempt_augment_duos = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	var player := TestPlayer.new()
	add_child(player)
	player.add_to_group(&"player")
	_test_slash_coverage_and_bleed(player)
	_test_hex_consumer(player)
	_test_spider_cast_and_damage(player)
	_test_burst_retargets(player)
	_test_projectile_retargets(player)
	_test_lance_retarget_range(player)
	_test_retarget_preserves_lifetime(player)
	_test_shard_retarget_range(player)
	_test_shard_parent_exclusion(player)
	_test_retarget_keeps_walls(player)
	_cleanup()
	player.free()
	await get_tree().process_frame
	print("AugmentCombatReliabilityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _test_slash_coverage_and_bleed(player: Node2D) -> void:
	var slash := SLASH.instantiate() as SpiritSlashEffect
	slash.setup(player)
	slash.vfx_scene = null
	add_child(slash)
	slash.set_process(false)
	for row in [{"level": 1, "hit": 28.8, "tick": 3.456}, {"level": 5, "hit": 69.12, "tick": 12.4416}]:
		slash.set_level(int(row["level"]))
		slash.set("_cd", 0.0)
		var first := _spawn(Vector2(40, 0))
		var second := _spawn(Vector2(80, 0))
		var third := _spawn(Vector2(120, 0))
		slash._try_cast(false)
		_check(_near(_lost(first), float(row["hit"])) and _near(_lost(second), float(row["hit"])) and _near(_lost(third), 0.0), "Slash Lv.%d reliably cuts exactly the two nearest enemies" % int(row["level"]))
		EnemyStatus.advance(0.5)
		_check(_near(_lost(first), float(row["hit"]) + float(row["tick"])) and _near(_lost(second), float(row["hit"]) + float(row["tick"])), "Slash Lv.%d applies deterministic bleed to both survivors" % int(row["level"]))
		_cleanup()
	slash.free()

func _test_hex_consumer(player: Node2D) -> void:
	var hex := HEX.instantiate() as HexBlinkMarkEffect
	hex.setup(player)
	hex.vfx_blink_scene = null
	hex.vfx_mark_scene = null
	add_child(hex)
	hex.set_process(false)
	hex.set_level(1)
	seed(123)
	for i in range(12):
		hex._try_cast()
		if float(hex.get("_cd")) > 0.0:
			break
	_check(_near(float(hex.get("_cd")), 4.0), "Blink's first cast returns after four seconds without a refund")
	var consumer := PLAYER_SCRIPT.new() as Node2D
	consumer.set("stats", Stats.new())
	var all_reliable := true
	for i in range(12):
		consumer.set_meta("hex_mark_shots_left", 1)
		consumer.set_meta("hex_mark_bonus", player.get_meta("hex_mark_bonus"))
		all_reliable = all_reliable and _near(float(consumer.call("_consume_hex_mark_bonus", 12.0)), 48.0)
		all_reliable = all_reliable and _near(float(consumer.call("_consume_hex_mark_bonus", 12.0)), 12.0)
	_check(all_reliable, "the actual player's Hex consumer adds exactly 36 damage and spends one charge")
	consumer.free()
	hex.free()

func _test_spider_cast_and_damage(player: Node2D) -> void:
	var summoner := SPIDERS.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	summoner.detonate_hint_seconds = 0.0
	add_child(summoner)
	summoner.set_process(false)
	summoner.set_level(1)
	summoner._try_spawn()
	var brood: Array[PoisonSpiderling] = []
	for child in get_children():
		if child is PoisonSpiderling:
			child.set_physics_process(false)
			brood.append(child)
	_check(brood.size() == 2, "a first-rank cast immediately supplies two hunting spiderlings")
	if not brood.is_empty():
		var bitten := _spawn(Vector2(1000, 0))
		brood[0].vfx_bite_scene = null
		var reliable := true
		for i in range(12):
			brood[0]._deal_bite(bitten, Vector2(1000, 0))
			reliable = reliable and _near(_lost(bitten), 6.0 * float(i + 1))
		_check(reliable, "every spider bite deals six damage, including consecutive hits")
	_cleanup()
	var blast_at := Vector2(1500, 0)
	var inside := _spawn(blast_at + Vector2(65, 0))
	var outside := _spawn(blast_at + Vector2(85, 0))
	var spider := summoner._hatch(blast_at) as PoisonSpiderling
	if spider != null:
		spider.set_physics_process(false)
		spider.vfx_explode_scene = null
	summoner._detonate_all()
	_check(_near(_lost(inside), 16.8) and _near(_lost(outside), 0.0), "a first-rank detonation reliably hits inside seventy pixels and misses beyond it")
	_cleanup()
	for i in range(12):
		summoner._hatch(Vector2(2000, 0))
	_check(summoner.living_spiders() == 7, "faster first-rank summons still stop at seven living spiders")
	_cleanup()
	summoner.free()

func _test_burst_retargets(player: Node2D) -> void:
	var effect := MISSILE_EFFECT.instantiate() as MagicMissileEffect
	effect.setup(player)
	add_child(effect)
	effect.set_process(false)
	effect.set_level(1)
	var first := _spawn(Vector2(60, 0))
	var next := _spawn(Vector2(120, 0))
	_spawn(Vector2(950, 0))
	effect._process(0.01)
	effect._process(0.01)
	var fired := _missiles()
	_check(fired.size() == 1 and _near(fired[0].damage, 9.0), "a first-rank seeking missile carries nine damage")
	for missile in fired:
		missile.free()
	EnemyWorld.remove_enemy(first, &"reliability_test")
	effect._process(0.1)
	fired = _missiles()
	_check(fired.size() == 1 and fired[0].target_handle == next, "the remaining burst shot seeks the nearest survivor when its first target dies")
	_cleanup()
	effect.free()

func _test_projectile_retargets(player: Node2D) -> void:
	var dead := _spawn(Vector2(20, 0))
	var live := _spawn(Vector2(80, 0))
	var missile := MISSILE.instantiate() as MagicMissileProjectile
	missile.speed = 100.0
	add_child(missile)
	missile.set_physics_process(false)
	missile.setup_handle(dead, 9.0, Vector2.RIGHT, player)
	EnemyWorld.remove_enemy(dead, &"reliability_test")
	missile._physics_process(0.9)
	_check(_near(_lost(live), 9.0), "an airborne missile retargets and damages a live nearby enemy")
	_cleanup()
	dead = _spawn(Vector2(20, 0))
	var distant := _spawn(Vector2(900, 0))
	missile = MISSILE.instantiate() as MagicMissileProjectile
	add_child(missile)
	missile.set_physics_process(false)
	missile.setup_handle(dead, 9.0, Vector2.RIGHT, player)
	EnemyWorld.remove_enemy(dead, &"reliability_test")
	missile._physics_process(0.01)
	_check(missile.is_queued_for_deletion() and _near(_lost(distant), 0.0), "retargeting cannot extend the ordinary seven-hundred-fifty-pixel seek range")
	_cleanup()

func _test_lance_retarget_range(player: Node2D) -> void:
	var effect := MISSILE_EFFECT.instantiate() as MagicMissileEffect
	effect.setup(player)
	add_child(effect)
	effect.set_process(false)
	effect.set_level(1)
	effect.set_facet(&"lance")
	var dead := _spawn(Vector2(1000, 0))
	var replacement := _spawn(Vector2(1100, 0))
	effect._process(0.01)
	effect._process(0.01)
	var fired := _missiles()
	if fired.size() == 1:
		EnemyWorld.remove_enemy(dead, &"reliability_test")
		fired[0].set_physics_process(false)
		fired[0]._physics_process(0.01)
	_check(fired.size() == 1 and fired[0].target_handle == replacement and not fired[0].is_queued_for_deletion(), "a Lance missile carries its wider seek range into airborne retargeting")
	_cleanup()
	effect.free()

func _test_retarget_keeps_walls(player: Node2D) -> void:
	var manager := ChunkManager.new()
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.world_atmosphere_enabled = false
	add_child(manager)
	manager.set_process(false)
	manager.register_manual_block_cell(Vector2i(1, 0))
	var dead := _spawn(Vector2(20, 32))
	var behind_wall := _spawn(Vector2(150, 32))
	var missile := MISSILE.instantiate() as MagicMissileProjectile
	missile.position = Vector2(0, 32)
	missile.speed = 200.0
	add_child(missile)
	missile.set_physics_process(false)
	missile.setup_handle(dead, 9.0, Vector2.RIGHT, player)
	EnemyWorld.remove_enemy(dead, &"reliability_test")
	missile._physics_process(1.0)
	_check(missile.target_handle == behind_wall and missile.is_queued_for_deletion() and _near(_lost(behind_wall), 0.0), "retargeted missiles still stop at the wall before an enemy behind it")
	_cleanup()
	manager.free()

func _test_retarget_preserves_lifetime(player: Node2D) -> void:
	var first := _spawn(Vector2(40, 0))
	var next := _spawn(Vector2(500, 0))
	var missile := MISSILE.instantiate() as MagicMissileProjectile
	missile.speed = 1.0
	missile.hit_radius = 4.0
	add_child(missile)
	missile.set_physics_process(false)
	missile.setup_handle(first, 9.0, Vector2.RIGHT, player)
	missile._physics_process(1.0)
	EnemyWorld.remove_enemy(first, &"reliability_test")
	missile._physics_process(0.9)
	_check(missile.target_handle == next and not missile.is_queued_for_deletion(), "a retarget can use the last tenth of a second of an airborne missile's life")
	missile._physics_process(0.2)
	_check(missile.is_queued_for_deletion() and _near(_lost(next), 0.0), "retargeting never restarts the missile's two-second lifetime")
	_cleanup()

func _test_shard_retarget_range(player: Node2D) -> void:
	var struck := _spawn(Vector2(80, 0))
	var next := _spawn(Vector2(120, 0))
	var outside := _spawn(Vector2(600, 0))
	var main := MISSILE.instantiate() as MagicMissileProjectile
	add_child(main)
	main.set_physics_process(false)
	main.setup_handle(struck, 9.0, Vector2.RIGHT, player)
	main.set_split(1, MISSILE, 0.6)
	main._split(struck, Vector2(100, 0))
	var shards: Array[MagicMissileProjectile] = []
	for missile in _missiles():
		if missile != main:
			shards.append(missile)
	EnemyWorld.remove_enemy(struck, &"reliability_test")
	EnemyWorld.remove_enemy(next, &"reliability_test")
	if shards.size() == 1:
		shards[0].set_physics_process(false)
		shards[0]._physics_process(0.01)
	_check(shards.size() == 1 and shards[0].target_handle == EnemyWorldTypes.INVALID_HANDLE and _near(_lost(outside), 0.0), "a Choir shard cannot retarget beyond its four-hundred-twenty-pixel search")
	_cleanup()

func _test_shard_parent_exclusion(player: Node2D) -> void:
	var parent_victim := _spawn(Vector2(40, 0))
	var doomed := _spawn(Vector2(100, 0))
	var survivor := _spawn(Vector2(180, 0))
	var main := MISSILE.instantiate() as MagicMissileProjectile
	add_child(main)
	main.set_physics_process(false)
	main.setup_handle(parent_victim, 9.0, Vector2.RIGHT, player)
	main.set_split(1, MISSILE, 0.6)
	main._split(parent_victim, Vector2(40, 0))
	var shards: Array[MagicMissileProjectile] = []
	for missile in _missiles():
		if missile != main:
			shards.append(missile)
	EnemyWorld.remove_enemy(doomed, &"reliability_test")
	if shards.size() == 1:
		var shard := shards[0]
		shard.speed = 200.0
		shard.set_physics_process(false)
		shard.setup_handle(doomed, 5.4, Vector2.RIGHT, player)
		shard._physics_process(0.001)
		_check(shard.target_handle == survivor and _near(_lost(parent_victim), 0.0), "a Choir shard with a dead target retargets beyond the surviving parent victim")
		if shard.target_handle == survivor:
			shard._physics_process(0.9)
	_check(shards.size() == 1 and _near(_lost(parent_victim), 0.0) and _near(_lost(survivor), 5.4), "a retargeted Choir shard hits a new enemy without hitting its parent victim on the way")
	_cleanup()

	parent_victim = _spawn(Vector2(80, 0))
	survivor = _spawn(Vector2(180, 0))
	main = MISSILE.instantiate() as MagicMissileProjectile
	add_child(main)
	main.set_physics_process(false)
	main.setup_handle(parent_victim, 9.0, Vector2.RIGHT, player)
	main.set_split(1, MISSILE, 0.6)
	main._split(parent_victim, Vector2(60, 0))
	shards.clear()
	for missile in _missiles():
		if missile != main:
			shards.append(missile)
	if shards.size() == 1:
		var shard := shards[0]
		shard.speed = 200.0
		shard.set_physics_process(false)
		shard.setup_handle(survivor, 5.4, Vector2.RIGHT, player)
		shard._physics_process(0.9)
	_check(shards.size() == 1 and _near(_lost(parent_victim), 0.0) and _near(_lost(survivor), 5.4), "a Choir shard's swept collision skips the surviving parent victim even with a valid target")
	var before_reuse := _lost(parent_victim)
	if shards.size() == 1:
		# Exercise the production pool-reset callback before reusing a shard
		# as an ordinary missile aimed at its former excluded victim.
		var reused := shards[0]
		reused._on_pool_recycle()
		reused.setup_handle(parent_victim, 9.0, Vector2.RIGHT, player)
		reused._physics_process(0.1)
	_check(shards.size() == 1 and _near(_lost(parent_victim), before_reuse + 9.0), "pool recycling clears a shard's victim exclusion before ordinary missile reuse")
	_cleanup()
