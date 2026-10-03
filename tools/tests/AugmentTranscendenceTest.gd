extends Node

# Transcendence (docs/design/2026-10-03-bindings-and-theses.md §5): an
# augment at Lv.5 whose catalyst holds can turn into a stronger form with a
# new rule. Pins the catalysts, the readiness rule and its Doctrine waivers,
# then each combat Transcendence against live enemies and each passive one
# through the real stat pass or kill path that reads it.
#
# Run: <godot> --headless --path . res://tools/tests/AugmentTranscendenceTest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const DeathContext = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const TESLA_SCENE = preload("res://effects/augments/scenes/TeslaAuraEffect.tscn")
const MISSILE_SCENE = preload("res://effects/augments/scenes/MagicMissileProjectile.tscn")
const SLASH_SCENE = preload("res://effects/augments/scenes/SpiritSlashEffect.tscn")
const HEX_SCENE = preload("res://effects/augments/scenes/HexBlinkMarkEffect.tscn")
const SPIDER_SCENE = preload("res://effects/augments/scenes/SpiderlingSummonEffect.tscn")
const SHIELD_SCENE = preload("res://effects/augments/scenes/ReflectedShieldEffect.tscn")
const CORE_SCENE = preload("res://effects/augments/scenes/StaminaCoreEffect.tscn")
const FIXTURE_HP := 100000.0


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


func _spawn(position: Vector2, health: float = FIXTURE_HP) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(&"transcend_dummy", "res://transcend_dummy.tscn", position, health, 0.0, 4.0, 0))
	_spawned.append(handle)
	return handle


func _cleanup() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"transcend_test")
	_spawned.clear()


func _lost(handle: int, from: float = FIXTURE_HP) -> float:
	return from - EnemyWorld.get_health(handle) if EnemyWorld.is_valid_handle(handle) else from


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {}
	Global.selected_style_id = &"ranged"
	_test_table()
	_test_catalysts()
	_test_readiness()
	var player := TestPlayer.new()
	add_child(player)
	_test_storm_crown(player)
	_test_choir_of_needles(player)
	_test_thousand_cuts(player)
	_test_hexgate(player)
	_test_brood_mother(player)
	_test_mirror_aegis(player)
	_test_undying_engine(player)
	player.queue_free()
	_test_passive_rules()
	await _test_stat_pass()
	_cleanup()
	await get_tree().process_frame
	print("AugmentTranscendenceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_table() -> void:
	var every := true
	for id in Global.augment_db.keys():
		if not AugmentScaling.can_transcend(StringName(id)) or AugmentScaling.transcended_name(StringName(id)) == "" or AugmentScaling.transcend_rule(StringName(id)) == "" or AugmentScaling.catalyst_text(StringName(id)) == "":
			every = false
			print("missing Transcendence for ", id)
	_check(every and AugmentScaling.TRANSCENDENCE.size() == Global.augment_db.size(), "every augment has a Transcended form, a rule and a catalyst (%d)" % AugmentScaling.TRANSCENDENCE.size())


func _context(extra: Dictionary) -> Dictionary:
	var context := {"equipped": [], "stats": {}, "disciplines": {}, "families": {}, "curses": 0, "followers": 0, "waive": false}
	context.merge(extra, true)
	return context


func _test_catalysts() -> void:
	_check(not AugmentScaling.catalyst_holds(&"augment_tesla_aura", _context({})), "no catalyst, no Transcendence")
	_check(AugmentScaling.catalyst_holds(&"augment_tesla_aura", _context({"equipped": [&"augment_tesla_aura", &"augment_sprint_servos"]})), "a partner augment is a catalyst (Tesla + Sprint Servos)")
	_check(AugmentScaling.catalyst_holds(&"augment_tesla_aura", _context({"stats": {"move_speed": 180.0}})), "a stat threshold is a catalyst (180 move speed)")
	_check(not AugmentScaling.catalyst_holds(&"augment_tesla_aura", _context({"stats": {"move_speed": 179.0}})), "and just under it is not")
	_check(AugmentScaling.catalyst_holds(&"augment_tesla_aura", _context({"disciplines": {"MO": true}})), "a tree discipline is a catalyst (a Momentum node)")
	_check(AugmentScaling.catalyst_holds(&"augment_corruption_engine", _context({"families": {&"vessel": 1}})), "a Doctrine family is a catalyst (vessel)")
	_check(AugmentScaling.catalyst_holds(&"augment_doctrine_of_burden", _context({"curses": 4})) and not AugmentScaling.catalyst_holds(&"augment_doctrine_of_burden", _context({"curses": 3})), "a curse count is a catalyst (four)")
	_check(AugmentScaling.catalyst_holds(&"augment_cult_of_personality", _context({"followers": 300})), "a Follower hoard is a catalyst (300)")
	_check(AugmentScaling.catalyst_holds(&"augment_magic_missile", _context({"waive": true})), "a waiver holds every catalyst")
	_check(not AugmentScaling.catalyst_holds(&"augment_lucky_charm", _context({"equipped": [&"augment_lucky_charm"]})), "an augment is never its own catalyst")


func _test_readiness() -> void:
	Global.permanent_augment_ids = [&"augment_magic_missile", &"augment_lucky_charm", StringName()]
	Global.attempt_augment_levels = {"augment_magic_missile": 4}
	Global.attempt_augment_transcended = {}
	_check(not Global.augment_transcend_ready(&"augment_magic_missile"), "Lv.4 is not ready")
	Global.attempt_augment_levels["augment_magic_missile"] = 5
	_check(Global.augment_transcend_ready(&"augment_magic_missile"), "Lv.5 with Lucky Charm beside it is ready")
	Global.permanent_augment_ids = [&"augment_magic_missile", StringName(), StringName()]
	_check(not Global.augment_transcend_ready(&"augment_magic_missile"), "without the catalyst it is not")
	Global.attempt_augment_levels["augment_magic_missile"] = 4
	Global.set_doctrine_rule(&"augment_transcend_level", 4)
	Global.set_doctrine_rule(&"augment_catalyst_waived", true)
	_check(Global.augment_transcend_ready(&"augment_magic_missile"), "Liturgy of Overclock: Lv.4 and no catalyst")
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_choir_of_recurrence", "apotheosis": "doctrine_apotheosis_perfected_engine"}
	Global.attempt_augment_levels["augment_magic_missile"] = 5
	_check(Global.augment_transcend_ready(&"augment_magic_missile"), "the Circuit Canon waives every catalyst")
	Global.attempt_doctrine_stage_ids = {}
	Global.permanent_augment_ids = [&"augment_magic_missile", &"augment_sprint_servos", &"augment_reflect_shield"]
	Global.attempt_augment_levels = {}
	_check(Global.transcend_equipped_augments() == 3, "The Engine Prays turns every equipped augment at any level")
	_check(Global.augment_display_name(&"augment_sprint_servos") == "Velocity Engine" and Global.augment_display_name(&"augment_reflect_shield") == "Mirror Aegis", "and they take their new names")
	_check(Global.transcend_equipped_augments() == 0, "an augment turns once")
	Global.attempt_augment_transcended = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]


# ---------------------------------------------------------------- combat

func _test_storm_crown(player: TestPlayer) -> void:
	var tesla := TESLA_SCENE.instantiate() as TeslaAuraEffect
	tesla.setup(player)
	add_child(tesla)
	tesla.set_level(1)
	var d := AugmentScaling.native_d(player)
	var first := _spawn(Vector2(200, 0))
	var second := _spawn(Vector2(330, 0))
	var third := _spawn(Vector2(460, 0))
	tesla._process(1.0)
	_check(_lost(first) == 0.0 and _lost(second) == 0.0, "an ordinary aura does not reach 200 px")
	tesla.set_transcended(true)
	tesla._process(1.0)
	_check(_near(_lost(first), d * 0.5), "Storm Crown's wider radius reaches it (%.2f)" % _lost(first))
	_check(_near(_lost(second), d * 0.5 * 0.7), "the zap chains to the next enemy at x0.7 (%.2f)" % _lost(second))
	_check(_near(_lost(third), d * 0.5 * 0.49), "and once more at x0.49 (%.2f)" % _lost(third))
	tesla.queue_free()
	_cleanup()


func _test_choir_of_needles(player: TestPlayer) -> void:
	var first := _spawn(Vector2(40, 0))
	var second := _spawn(Vector2(40, 120))
	var third := _spawn(Vector2(40, -120))
	var missile := MISSILE_SCENE.instantiate() as MagicMissileProjectile
	missile.global_position = Vector2.ZERO
	missile.speed = 100.0
	missile.hit_radius = 6.0
	add_child(missile)
	missile.setup_handle(first, 10.0, Vector2.RIGHT, player)
	missile.set_split(2, MISSILE_SCENE, 0.6)
	missile.call("_physics_process", 1.0)
	_check(_near(_lost(first), 10.0), "the missile lands its full damage")
	var shards: Array = []
	for child in get_children():
		if child is MagicMissileProjectile and child != missile and int(child.get("target_handle")) in [second, third]:
			shards.append(child)
	_check(shards.size() == 2, "Choir of Needles splits it into two shards seeking other enemies (%d)" % shards.size())
	for shard in shards:
		_check(int(shard.get("split_count")) == 0, "a shard never splits again")
		shard.set("speed", 400.0)
		shard.set("hit_radius", 12.0)
		for i in range(6):
			if is_instance_valid(shard) and shard.is_inside_tree():
				shard.call("_physics_process", 0.1)
	_check(_near(_lost(second), 6.0) and _near(_lost(third), 6.0), "each shard strikes for 60%% (%.1f, %.1f)" % [_lost(second), _lost(third)])
	_cleanup()


func _test_thousand_cuts(player: TestPlayer) -> void:
	var slash := SLASH_SCENE.instantiate() as SpiritSlashEffect
	slash.setup(player)
	add_child(slash)
	slash.set_level(4)
	slash.refund_on_3plus = false
	var weak := [_spawn(Vector2(30, 0), 1.0), _spawn(Vector2(0, 35), 1.0), _spawn(Vector2(-40, 0), 1.0)]
	var sturdy := [_spawn(Vector2(0, -60)), _spawn(Vector2(70, 10))]
	_check(slash.target_count() == 1, "an ordinary slash strikes one enemy")
	slash.set_transcended(true)
	_check(slash.target_count() == 4, "Thousand Cuts strikes 3 + 1 per 4 levels (4 at Lv.4)")
	_check(slash._try_cast(false), "it casts without a key")
	var dead := 0
	for handle in weak:
		if not EnemyWorld.is_valid_handle(handle) or EnemyWorld.is_dying(handle):
			dead += 1
	_check(dead == 3, "the first cut kills the three weak enemies")
	_check(_lost(sturdy[0]) > 0.0 and _lost(sturdy[1]) > 0.0, "and the kills re-cast into the sturdy ones beyond them")
	slash.queue_free()
	_cleanup()


func _test_hexgate(player: TestPlayer) -> void:
	var hex := HEX_SCENE.instantiate() as HexBlinkMarkEffect
	hex.setup(player)
	add_child(hex)
	hex.set_level(2)
	var marked := hex.marked_shots
	hex.set_transcended(true)
	_check(hex.marked_shots == marked + 1, "Hexgate marks one more attack")
	var inside := _spawn(Vector2(500, 60))
	var outside := _spawn(Vector2(500, 300))
	hex._tear_rift(Vector2(500, 0))
	_check(_near(_lost(inside), AugmentScaling.native_d(player) * 2.5 * AugmentScaling.potency(2)), "a rift strikes for 2.5 D x potency")
	_check(_lost(outside) == 0.0, "and only inside its circle")
	hex.queue_free()
	_cleanup()


func _test_brood_mother(player: TestPlayer) -> void:
	var summoner := SPIDER_SCENE.instantiate() as SpiderlingSummonEffect
	summoner.setup(player)
	add_child(summoner)
	summoner.set_level(1)
	Global._rng.seed = 2024
	for i in range(30):
		RunEvents.enemy_defeated.emit(DeathContext.new(0, &"dummy", Vector2(100, 0), 0, player, {}))
	_check(summoner.living_spiders() == 0, "an ordinary summoner hatches nothing from kills")
	summoner.set_transcended(true)
	for i in range(40):
		RunEvents.enemy_defeated.emit(DeathContext.new(0, &"dummy", Vector2(100, 0), 0, player, {}))
	var hatched := summoner.living_spiders()
	_check(hatched > 0 and hatched <= summoner.spider_cap(), "Brood Mother hatches spiderlings from kills, within its cap (%d of %d)" % [hatched, summoner.spider_cap()])
	var far_before := summoner.living_spiders()
	for i in range(20):
		RunEvents.enemy_defeated.emit(DeathContext.new(0, &"dummy", Vector2(5000, 0), 0, player, {}))
	_check(summoner.living_spiders() == far_before, "a kill far away hatches nothing")
	var target := _spawn(Vector2(100, 0))
	var spider: Node = null
	for n in get_tree().get_nodes_in_group("spiderlings"):
		spider = n
		break
	if spider != null:
		spider.set("_life_left", 0.01)
		spider.call("_physics_process", 0.1)
		_check(_lost(target) > 0.0, "a hatched spiderling detonates when its life ends")
	for n in get_tree().get_nodes_in_group("spiderlings"):
		n.queue_free()
	summoner.queue_free()
	_cleanup()


func _test_mirror_aegis(player: TestPlayer) -> void:
	var shield := SHIELD_SCENE.instantiate() as ReflectShieldEffect
	shield.setup(player)
	add_child(shield)
	shield.set_level(1)
	shield._process(1.7)
	_check(shield._active_left <= 0.0, "an ordinary shield never opens by itself")
	shield.set_transcended(true)
	shield._process(1.7)
	_check(shield._active_left > 0.0 and player.invulnerable_for > 0.0, "Mirror Aegis opens its ward on its own rhythm")
	var target := _spawn(Vector2(30, 0))
	var far_targets := [_spawn(Vector2(0, 40)), _spawn(Vector2(-40, 0)), _spawn(Vector2(0, -50)), _spawn(Vector2(60, 60))]
	shield._on_perfect_reflect(Vector2.ZERO, 1.0)
	var struck := 0
	for handle in [target] + far_targets:
		if _lost(handle) > 0.0:
			struck += 1
	_check(struck == 5, "its perfect zap strikes everything in range (%d of 5)" % struck)
	shield.queue_free()
	_cleanup()


func _test_undying_engine(player: TestPlayer) -> void:
	var core := CORE_SCENE.instantiate() as StaminaCoreEffect
	core.setup(player)
	add_child(core)
	core.set_level(1)
	core._on_damage_dealt(player, 100.0)
	core._process(0.016)
	_check(player.healed == 0.0, "an idle core steals nothing")
	core.set_transcended(true)
	core._on_damage_dealt(player, 100.0)
	core._process(0.016)
	_check(_near(player.healed, 6.0), "Undying Engine steals 6%% always (%.2f)" % player.healed)
	player.hp = 30.0
	core._process(0.016)
	_check(core._active_time > 0.0, "and fires itself below 35% HP")
	player.hp = 100.0
	core.queue_free()


# ---------------------------------------------------------------- passives

func _test_passive_rules() -> void:
	_check(_near(AugmentScaling.velocity_power(280.0), 0.54) and _near(AugmentScaling.velocity_power(900.0), 0.6) and AugmentScaling.velocity_power(90.0) == 0.0, "Velocity Engine: +30% Power per 100 move speed above 100, at most +60%")
	_check(_near(AugmentScaling.lucky_crit_chance(1.0, true), 2.0 * LuckResolver.lucky_crit_chance(1.0)) and _near(AugmentScaling.lucky_crit_multiplier(true), 2.5), "Fortune's Engine doubles the lucky crit and makes it x2.5")
	_check(_near(BurdenResolver.gambler_follower_chance(100000.0, true), 0.70, 0.01) and _near(BurdenResolver.gambler_follower_chance(100000.0), 0.35, 0.01), "House Edge lifts the Rite's cap from 35% to 70%")
	_check(_near(BurdenResolver.gambler_follower_chance(0.0, true), 0.30), "and doubles the base chance (15% -> 30%)")
	_check(BurdenResolver.litany_ramp(0.8) == 0.0 and BurdenResolver.litany_ramp(0.8, true) > 0.0, "Requiem starts at 85% HP, not 60%")
	_check(_near(BurdenResolver.litany_haste(20, 5.0, 0.0, true), 0.70), "and its cap is 70%")
	var snapshot := BurdenSnapshot.new()
	snapshot.neg_count = 2
	snapshot.pos_count = 2
	_check(_near(BurdenResolver.equilibrium_bonus(20, snapshot), 0.20) and _near(BurdenResolver.equilibrium_bonus(20, snapshot, true), 0.45), "Perfect Balance lifts the Sigil's cap from 20% to 45%")

	Global.permanent_augment_ids = [&"augment_cult_of_personality", StringName(), StringName()]
	Global.attempt_augment_levels = {"augment_cult_of_personality": 20}
	Global.set_followers(10000)
	_check(_near(Global.belief_power_cap(), 0.15), "belief caps at +15%")
	Global.attempt_augment_transcended = {"augment_cult_of_personality": true}
	_check(_near(Global.belief_power_cap(), 0.30) and _near(Global.follower_belief_power(), 0.30), "Prophet lifts it to +30%")
	Global._rng.seed = 11
	var extra := 0
	for i in range(1000):
		extra += Global.bonus_kill_followers()
	_check(extra > 1600 and extra % 2 == 0, "Prophet recruits two at a time, 90%% of kills at its cap (%d per 1000)" % extra)
	Global.attempt_augment_transcended = {}
	Global.set_followers(0)
	Global.attempt_augment_levels = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.pct_min = -0.95
	data.pct_max = 0.95
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _cursed(slot: int, severity: float) -> ItemInstance:
	return ItemInstance.from_roll(_make_data("curse_%d" % slot, slot), 0, ItemInstance.Polarity.NEG, -severity, false)


func _stats_with(player: Node, augments: Array, transcended: Dictionary) -> Stats:
	var typed: Array[StringName] = []
	typed.assign(augments)
	Global.permanent_augment_ids = typed
	Global.attempt_augment_transcended = transcended
	player.call("recompute_run_stats", null, null)
	return (player.get("stats") as Stats).copy()


func _test_stat_pass() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	Global.run_inventory = Inventory.new()
	Global.attempt_augment_levels = {}
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame

	# Heart of Ruin: three heaviest curses, cap 75%.
	Global.run_inventory.set_item(0, _cursed(0, 0.9))
	Global.run_inventory.set_item(1, _cursed(1, 0.9))
	Global.run_inventory.set_item(2, _cursed(2, 0.9))
	var engine := [&"augment_corruption_engine", StringName(), StringName()]
	Global.attempt_augment_levels = {"augment_corruption_engine": 20}
	var none := _stats_with(player, [StringName(), StringName(), StringName()], {})
	var plain := _stats_with(player, engine, {})
	var ruin := _stats_with(player, engine, {"augment_corruption_engine": true})
	_check(_near(plain.power - none.power, 0.30), "Corruption Engine pays its 30%% cap (%.3f)" % (plain.power - none.power))
	_check(ruin.power - none.power > 0.30 and ruin.power - none.power <= 0.75 + 0.0001, "Heart of Ruin reads three curses past the old cap (%.3f)" % (ruin.power - none.power))
	Global.attempt_augment_levels = {}

	# Martyr's Frame: +5% Power per qualifying curse.
	var burden := [&"augment_doctrine_of_burden", StringName(), StringName()]
	var doctrine := _stats_with(player, burden, {})
	var martyr := _stats_with(player, burden, {"augment_doctrine_of_burden": true})
	_check(_near(martyr.power - doctrine.power, 0.15), "Martyr's Frame adds 5%% Power per curse (three: %.3f)" % (martyr.power - doctrine.power))

	# Twin Lens: the suppressed curse returns 110%.
	Global.run_inventory = Inventory.new()
	Global.run_inventory.set_item(3, _cursed(3, 0.5))
	var lens := [&"augment_inversion_lens", StringName(), StringName()]
	var bare := _stats_with(player, [StringName(), StringName(), StringName()], {})
	var lensed := _stats_with(player, lens, {})
	var twin := _stats_with(player, lens, {"augment_inversion_lens": true})
	_check(_near(lensed.power - bare.power, 0.5 + 0.5 * 0.55, 0.01), "the Lens turns a -50%% Power curse into +27.5%% (%.3f)" % (lensed.power - bare.power))
	_check(_near(twin.power - bare.power, 0.5 + 0.5 * 1.10, 0.01), "Twin Lens turns it into +55%% (%.3f)" % (twin.power - bare.power))
	_check(twin.luck > lensed.luck, "and doubles the Luck kicker")

	# Velocity Engine through the real pass.
	Global.run_inventory = Inventory.new()
	var servos := [&"augment_sprint_servos", StringName(), StringName()]
	var fast := _stats_with(player, servos, {})
	var velocity := _stats_with(player, servos, {"augment_sprint_servos": true})
	_check(_near(velocity.power - fast.power, AugmentScaling.velocity_power(fast.move_speed), 0.01), "Velocity Engine turns %d move speed into +%.0f%% Power" % [int(fast.move_speed), (velocity.power - fast.power) * 100.0])
	_check(Global.last_stat_ledger.any(func(row: Dictionary) -> bool: return String(row.get("label", "")) == "VELOCITY ENGINE"), "and the Run Sheet ledger names it")

	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.free()
	Global.run_inventory = saved_inventory
	Global.attempt_augment_transcended = {}
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
