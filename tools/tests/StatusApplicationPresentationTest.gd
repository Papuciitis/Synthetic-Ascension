extends Node

## Exercises actual applications, not calls to the presentation helper: new
## statuses speak with semantic badges, refreshes and damage ticks do not.
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PLAYER_SCENE := preload("res://core/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const FEEDBACK_PATH := "res://core/combat/CombatStatusFeedback.gd"

var _passes := 0
var _failures := 0
var _handles: Array[int] = []
var _feedback: Script = null
var _tips: Array = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn() -> int:
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"status_presentation", "res://status_presentation.tscn", Vector2(300.0 + _handles.size() * 80.0, 200.0), 500.0, 10.0, 8.0, 0))
	_handles.append(handle)
	return handle


func _reset() -> void:
	BattleText.clear()
	if _feedback != null:
		_feedback.call("clear")


func _effect_count(id: StringName) -> int:
	var count := 0
	for slot in range(BattleText._count):
		if (BattleText._icon_ids[slot] as Array).has(id):
			count += 1
	return count


func _test_dots() -> void:
	_reset()
	var handle := _spawn()
	_check(EnemyStatus.apply_burn(handle, 1, 3.0, 0.5, 1.0), "a live burn application succeeds")
	_check(_effect_count(&"burn") == 1, "a new burn announces its canonical badge")
	EnemyStatus.apply_burn(handle, 2, 4.0, 0.5, 2.0)
	EnemyStatus.apply_named_burn(handle, &"hot_rounds", 3.0, 0.5, 4.0)
	EnemyStatus.advance(0.6)
	_check(_effect_count(&"burn") == 1, "refresh, a coexisting named burn, and damage ticks never repeat BURN")
	EnemyStatus.apply_bleed(handle, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_bleed(handle, 2, 4.0, 0.5, 2.0)
	EnemyStatus.advance(0.6)
	_check(_effect_count(&"bleed") == 1, "bleed has its own announcement and silent refresh/ticks")
	_reset()
	var named := _spawn()
	EnemyStatus.apply_named_burn(named, &"hot_rounds", 3.0, 0.5, 4.0)
	EnemyStatus.apply_burn(named, 1, 3.0, 0.5, 1.0)
	_check(_effect_count(&"burn") == 1, "named-first and generic-second burn share one semantic introduction")


func _test_representation_and_rejection() -> void:
	_reset()
	var data_only := _spawn()
	var materialized := _spawn()
	var mirror := Node2D.new()
	add_child(mirror)
	EnemyWorld.bind_actor(materialized, mirror)
	EnemyStatus.apply_bleed(data_only, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_bleed(materialized, 1, 3.0, 0.5, 1.0)
	_check(_effect_count(&"bleed") == 2, "data-only and materialized enemies get the same semantic status feedback")
	_reset()
	var stale := _spawn()
	EnemyWorld.remove_enemy(stale, &"presentation_test")
	var dying := _spawn()
	EnemyWorld.set_representation(dying, EnemyWorldTypes.Representation.DYING)
	EnemyStatus.apply_burn(0, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_bleed(stale, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_burn(dying, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_burn(data_only, 0, 3.0, 0.5, 1.0)
	EnemyCombat.apply_stun(0, 1.0)
	EnemyCombat.apply_stun(dying, 1.0)
	_check(BattleText._count == 0, "invalid, stale, dying and rejected applications produce no status line")
	mirror.free()


func _test_stun_and_enemy_buffs() -> void:
	_reset()
	var handle := _spawn()
	EnemyCombat.apply_stun(handle, 0.5)
	EnemyCombat.apply_stun(handle, 1.0)
	_check(_effect_count(&"stun") == 1, "stun announces once when control is first lost")
	_reset()
	var actor := ENEMY_SCENE.instantiate() as EnemyActor
	actor.global_position = Vector2(600.0, 400.0)
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.apply_ward_buff(0.2, 2.0)
	actor.apply_ward_buff(0.25, 3.0)
	actor.apply_speed_buff(1.2, 2.0)
	actor.apply_speed_buff(1.3, 3.0)
	actor.set_stability_mul(0.85)
	actor.set_stability_mul(0.75)
	_check(_effect_count(&"warded") == 1 and _effect_count(&"haste") == 1 and _effect_count(&"slow") == 1, "Herald ward/haste and stability slow announce accepted transitions only")
	actor.free()


func _test_tree_applications() -> void:
	_reset()
	var runner := AscensionRunner.new()
	var handle := _spawn()
	var precision := PrecisionEngine.new()
	precision.setup(runner)
	precision.expose(handle)
	precision.expose(handle)
	_check(_effect_count(&"weak_point") == 1, "a real Weak Point exposure announces once across refreshes")
	var distortion := DistortionEngine.new()
	distortion.setup(runner)
	distortion._apply_fading(handle)
	distortion._apply_fading(handle)
	distortion._apply_slow(handle)
	distortion._apply_slow(handle)
	_check(_effect_count(&"fading") == 1 and _effect_count(&"slow") == 1, "real Distortion DoT/slow applications carry distinct badges")
	var dominion := DominionEngine.new()
	dominion.setup(runner)
	dominion.make_link([handle])
	_check(_effect_count(&"link") == 1, "joining a real Dominion link announces LINKED")
	runner.free()


func _on_tip(text: String, duration: float, ids: Array[StringName]) -> void:
	_tips.append([text, duration, ids.duplicate()])


func _test_prime_refresh_and_reapplication() -> void:
	_reset()
	var runner := AscensionRunner.new()
	var momentum := MomentumEngine.new()
	momentum.setup(runner)
	momentum.active["MO02"] = true
	var handle := _spawn()
	var at := EnemyWorld.get_position(handle)
	momentum._dash_strip(at - Vector2(6.0, 0.0), at + Vector2(6.0, 0.0), Vector2.RIGHT)
	# Clear only presentation cooldowns: the existing Prime remains active.
	# This isolates the state transition from the helper's 1.5-second limit.
	_reset()
	momentum._clock = 2.0
	momentum._dash_strip(at - Vector2(6.0, 0.0), at + Vector2(6.0, 0.0), Vector2.RIGHT)
	_check(_effect_count(&"prime") == 0 and is_equal_approx(float(runner.status_of(handle).get("prime", 0.0)), 5.0), "Passing Blade refreshes an active Prime without a new caption after feedback cooldown clears")
	runner.clear_status(handle, "prime")
	_reset()
	momentum._dash_strip(at - Vector2(6.0, 0.0), at + Vector2(6.0, 0.0), Vector2.RIGHT)
	_check(_effect_count(&"prime") == 1, "Passing Blade announces Prime again after the previous status was consumed")
	runner.free()


func _test_bastion_cracked_refresh_and_reapplication() -> void:
	_reset()
	var runner := AscensionRunner.new()
	var bastion := BastionEngine.new()
	bastion.setup(runner)
	bastion._armor_break_pending = true
	var handle := _spawn()
	var hit := {"handle": handle, "tags": PackedStringArray(["flag:core_strike"]), "family": AscensionTags.FAMILY_NATIVE, "core": "melee", "is_boss": false, "position": EnemyWorld.get_position(handle)}
	bastion.on_hit(hit)
	runner.status_of(handle)["cracked"] = 3
	_reset()
	bastion.on_hit(hit)
	_check(_effect_count(&"cracked") == 0 and int(runner.status_of(handle).get("cracked", 0)) == 5, "Armour Break refreshes remaining Cracked charges without a new caption after feedback cooldown clears")
	runner.clear_status(handle, "cracked")
	_reset()
	bastion.on_hit(hit)
	_check(_effect_count(&"cracked") == 1, "Armour Break announces Cracked again after the previous charges were consumed")
	runner.free()


func _test_gavel_cracked_refresh_and_reapplication() -> void:
	_reset()
	var runner := AscensionRunner.new()
	var execution := ExecutionEngine.new()
	execution.setup(runner)
	var handle := _spawn()
	var at := EnemyWorld.get_position(handle)
	var boss := Node2D.new()
	boss.position = at
	add_child(boss)
	boss.add_to_group(&"boss")
	EnemyWorld.bind_actor(handle, boss)
	execution._strike(at, 1.0, 16.0, "presentation", "impact", PackedStringArray())
	runner.status_of(handle)["cracked"] = 3
	_reset()
	execution._strike(at, 1.0, 16.0, "presentation", "impact", PackedStringArray())
	_check(_effect_count(&"cracked") == 0 and int(runner.status_of(handle).get("cracked", 0)) == 5, "Gavel refreshes a boss's remaining Cracked charges without a new caption after feedback cooldown clears")
	runner.clear_status(handle, "cracked")
	_reset()
	execution._strike(at, 1.0, 16.0, "presentation", "impact", PackedStringArray())
	_check(_effect_count(&"cracked") == 1, "Gavel announces Cracked again after the boss's previous charges were consumed")
	boss.free()
	runner.free()


func _test_player_debuff() -> void:
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	_reset()
	_tips.clear()
	Global._run_taught.erase(&"healing_lock")
	RunEvents.illustrated_tutorial_tip.connect(_on_tip)
	player.call("lock_healing", 45.0, &"cursed_vault")
	_check(_effect_count(&"healing_sealed") == 1 and BattleText._texts[0] == "HEALING SEALED - 45s" and is_equal_approx(BattleText._scales[0], 1.2), "healing seal retains exact wording/scale with its canonical badge")
	player.call("lock_healing", 20.0, &"sacrifice")
	_check(_effect_count(&"healing_sealed") == 1, "a shorter healing lock is silent")
	_check(_tips.size() == 1 and _tips[0][2] == [&"healing_sealed"] and is_equal_approx(_tips[0][1], 4.0), "the first healing seal teaches with its own illustrated badge")
	RunEvents.illustrated_tutorial_tip.disconnect(_on_tip)
	player.free()


func _test_disabled_callouts() -> void:
	_reset()
	SettingsManager.set_value(&"accessibility", &"ability_callouts", false, false)
	var handle := _spawn()
	EnemyStatus.apply_burn(handle, 1, 3.0, 0.5, 1.0)
	EnemyStatus.apply_bleed(handle, 1, 3.0, 0.5, 1.0)
	EnemyCombat.apply_stun(handle, 1.0)
	_check(BattleText._count == 0, "disabling ability callouts silences actual status applications")
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)


func _run() -> void:
	Global.debug_disable_autosave = true
	var previous_callouts: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	BattleText.set_process(false)
	EnemyStatus.set_physics_process(false)
	if ResourceLoader.exists(FEEDBACK_PATH):
		_feedback = load(FEEDBACK_PATH) as Script
	_test_dots()
	_test_representation_and_rejection()
	_test_stun_and_enemy_buffs()
	_test_tree_applications()
	_test_prime_refresh_and_reapplication()
	_test_bastion_cracked_refresh_and_reapplication()
	_test_gavel_cracked_refresh_and_reapplication()
	_test_player_debuff()
	_test_disabled_callouts()
	for handle in _handles:
		EnemyStatus.clear_handle(handle)
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"presentation_test")
	SettingsManager.set_value(&"accessibility", &"ability_callouts", previous_callouts, false)
	print("StatusApplicationPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
