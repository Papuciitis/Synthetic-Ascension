extends Node

# Kill audio and callouts (audit 2026-10-04, change 10): the death sound
# climbs a semitone per 5 kills inside 1.5 s (max +7) and settles after a
# pause; 15+ kills inside 0.6 s say "xN" once with a thump; an elite says
# ELITE DOWN with its sting at most once a second; the melee connect, item
# drop and instance pickup sounds that existed but never played now do.
# SfxManager records requests before its headless guard (debug_record).

const PICKUP := preload("res://scenes/world/pickups/ItemPickup.tscn")

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


func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _requests(id: StringName) -> Array:
	return SfxManager.debug_requests.filter(func(r: Dictionary) -> bool: return r["id"] == id)


func _kill(handle: int, flags: int, position: Vector2) -> void:
	RunEvents.enemy_defeated.emit(EnemyDeathContext.new(handle, &"enemy_test", position, flags, null, {}))


func _callout_texts() -> PackedStringArray:
	var out := PackedStringArray()
	var texts: PackedStringArray = BattleText.get("_texts")
	for i in range(int(BattleText.get("_count"))):
		out.append(texts[i])
	return out


func _run() -> void:
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	BattleText.clear()
	var previous_callouts: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)

	_test_pitch_ladder_shape()
	await _test_pitch_ladder_live()
	await _test_multi_kill()
	await _test_elite_down()
	await _test_melee_hit()
	await _test_item_sounds()

	SettingsManager.set_value(&"accessibility", &"ability_callouts", previous_callouts, false)
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	BattleText.clear()
	print("KillAudioTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_pitch_ladder_shape() -> void:
	_check(is_equal_approx(SfxManager.kill_streak_pitch(1), 1.0) and is_equal_approx(SfxManager.kill_streak_pitch(4), 1.0), "kills 1-4 in the window sound as authored")
	_check(is_equal_approx(SfxManager.kill_streak_pitch(5), pow(2.0, 1.0 / 12.0)), "the fifth raises it one semitone")
	_check(is_equal_approx(SfxManager.kill_streak_pitch(12), pow(2.0, 2.0 / 12.0)), "twelve raise it two")
	_check(is_equal_approx(SfxManager.kill_streak_pitch(35), pow(2.0, 7.0 / 12.0)) and is_equal_approx(SfxManager.kill_streak_pitch(400), pow(2.0, 7.0 / 12.0)), "and it stops at +7")


func _test_pitch_ladder_live() -> void:
	await _wait_ms(SfxManager.KILL_WINDOW_MS + 100) # an empty window
	SfxManager.debug_requests.clear()
	for i in range(12):
		_kill(100 + i, EnemyWorldTypes.Flags.NONE, Vector2(i * 40, 0))
	var deaths := _requests(&"enemy_death")
	_check(deaths.size() == 12, "every defeat asks for the death sound (%d)" % deaths.size())
	if deaths.size() == 12:
		_check(is_equal_approx(float(deaths[0]["pitch"]), 1.0), "the first kill of a quiet spell is at authored pitch")
		_check(is_equal_approx(float(deaths[11]["pitch"]), pow(2.0, 2.0 / 12.0)), "the twelfth inside 1.5 s is two semitones up (%.3f)" % float(deaths[11]["pitch"]))
	await _wait_ms(SfxManager.KILL_WINDOW_MS + 100)
	SfxManager.debug_requests.clear()
	_kill(200, EnemyWorldTypes.Flags.NONE, Vector2.ZERO)
	deaths = _requests(&"enemy_death")
	_check(deaths.size() == 1 and is_equal_approx(float(deaths[0]["pitch"]), 1.0), "after a 1.5 s pause the ladder is back at the bottom")


func _test_multi_kill() -> void:
	var feedback := get_node("/root/WorldFeedbackVfx")
	await _wait_ms(feedback.MULTI_KILL_COOLDOWN_MS + 100)
	SfxManager.debug_requests.clear()
	BattleText.clear()
	var before: int = feedback.multi_kills()
	for i in range(14):
		_kill(300 + i, EnemyWorldTypes.Flags.NONE, Vector2(i * 10, 500))
	_check(feedback.multi_kills() == before, "14 kills inside 0.6 s are not a multi-kill")
	_kill(314, EnemyWorldTypes.Flags.NONE, Vector2(140, 500))
	_check(feedback.multi_kills() == before + 1, "the 15th makes one")
	_check(_callout_texts().has("×15"), "it says x15 (%s)" % [_callout_texts()])
	_check(_requests(&"multikill_thump").size() == 1, "with one thump")
	for i in range(5):
		_kill(320 + i, EnemyWorldTypes.Flags.NONE, Vector2(0, 500))
	_check(_callout_texts().has("×20") and not _callout_texts().has("×15"), "kills while it holds count on the same line (%s)" % [_callout_texts()])
	_check(_requests(&"multikill_thump").size() == 1 and feedback.multi_kills() == before + 1, "without another thump or multi-kill")
	# After the burst ends a fresh burst inside the cooldown says nothing.
	await _wait_ms(feedback.MULTI_KILL_HOLD_MS + 100)
	for i in range(20):
		_kill(340 + i, EnemyWorldTypes.Flags.NONE, Vector2(0, 600))
	_check(feedback.multi_kills() == before + 1 and _requests(&"multikill_thump").size() == 1, "a new burst inside 2.5 s of the last thump is quiet")
	await _wait_ms(feedback.MULTI_KILL_COOLDOWN_MS + 100)


func _test_elite_down() -> void:
	var feedback := get_node("/root/WorldFeedbackVfx")
	SfxManager.debug_requests.clear()
	BattleText.clear()
	var before: int = feedback.elite_downs()
	_kill(400, EnemyWorldTypes.Flags.ELITE, Vector2(800, 0))
	_check(feedback.elite_downs() == before + 1 and _callout_texts().has("ELITE DOWN"), "an elite kill says ELITE DOWN (%s)" % [_callout_texts()])
	_check(_requests(&"elite_down").size() == 1, "with its sting")
	_kill(401, EnemyWorldTypes.Flags.ELITE, Vector2(800, 0))
	_check(_callout_texts().has("ELITE DOWN ×2"), "a second inside a second counts on the same line (%s)" % [_callout_texts()])
	_check(_requests(&"elite_down").size() == 1, "without a second sting")
	_kill(402, EnemyWorldTypes.Flags.NONE, Vector2(800, 0))
	_check(_requests(&"elite_down").size() == 1, "fodder never stings")
	await _wait_ms(feedback.ELITE_DOWN_COOLDOWN_MS + 50)
	_kill(403, EnemyWorldTypes.Flags.ELITE, Vector2(800, 0))
	_check(_requests(&"elite_down").size() == 2, "a second later the next elite stings again")


func _test_melee_hit() -> void:
	var previous_style: String = String(Global.selected_style_id)
	var striker := Node2D.new()
	striker.add_to_group(&"player")
	add_child(striker)
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := get_node("/root/PoolManager").call("obtain", scene, self) as EnemyActor
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	enemy.configure_health(500.0, true)
	await get_tree().process_frame
	SfxManager.debug_requests.clear()
	Global.selected_style_id = "melee"
	enemy.take_damage(2.0, striker)
	_check(_requests(&"player_melee_hit").size() == 1, "a melee hit plays the connect sound")
	enemy.take_damage(2.0, striker)
	_check(_requests(&"player_melee_hit").size() == 1, "once per swing (90 ms), however many bodies it catches")
	await _wait_ms(120)
	var shot := HitLedger.new()
	shot.projectile_id = 7
	shot.add_resolved_hit(2.0, striker, Vector2.ZERO, false, 0, 0.0, 0.5, 0.0)
	enemy.apply_hit_ledger(shot)
	_check(_requests(&"player_melee_hit").size() == 1, "a projectile hit is not a melee connect")
	Global.selected_style_id = "ranged"
	enemy.take_damage(2.0, striker)
	_check(_requests(&"player_melee_hit").size() == 1, "nor is any hit on a ranged build")
	Global.selected_style_id = previous_style
	enemy.take_damage(9999.0, null)
	striker.queue_free()
	await get_tree().process_frame


func _make_data(item_id: String) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = ItemData.EquipSlot.RING
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _test_item_sounds() -> void:
	Global.start_new_attempt()
	var watcher := Node2D.new()
	watcher.add_to_group(&"player")
	add_child(watcher)
	await _wait_ms(150)
	SfxManager.debug_requests.clear()
	var dropped := PICKUP.instantiate() as ItemPickup
	dropped.item_instance = ItemInstance.from_roll(_make_data("audio_ring"), 1, ItemInstance.Polarity.POS, 0.5, false)
	dropped.item_id = "audio_ring"
	dropped.pickup_delay = 0.0
	dropped.global_position = Vector2(120, 0)
	add_child(dropped)
	_check(_requests(&"drop").size() == 1, "an item instance landing near the player clinks")
	var far := PICKUP.instantiate() as ItemPickup
	far.item_instance = ItemInstance.from_roll(_make_data("far_ring"), 1, ItemInstance.Polarity.POS, 0.5, false)
	far.item_id = "far_ring"
	far.global_position = Vector2(4000, 0)
	await _wait_ms(150)
	add_child(far)
	_check(_requests(&"drop").size() == 1, "one far off-screen stays quiet")
	var cache := PICKUP.instantiate() as ItemPickup
	cache.item_instance = ItemInstance.from_roll(_make_data("cache_ring"), 1, ItemInstance.Polarity.POS, 0.5, false)
	cache.item_id = "cache_ring"
	cache.is_exploration_loot = true
	cache.global_position = Vector2(60, 0)
	add_child(cache)
	_check(_requests(&"drop").size() == 1, "and level-built exploration loot does not clink")
	SfxManager.debug_requests.clear()
	dropped.call("_collect")
	_check(_requests(&"pickup").size() == 1, "collecting an item instance plays the pickup sound (it used to return first)")
	for node in [far, cache]:
		if is_instance_valid(node):
			node.queue_free()
	watcher.queue_free()
	await get_tree().process_frame
