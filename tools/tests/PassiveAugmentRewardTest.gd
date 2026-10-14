extends Node

## Exercises the actual reward paths with rolls fixed on either side of a
## payout boundary. Catches a missing rank argument, an uncapped ordinary
## chance, or losing the two-Follower Transcendence payout.
const CULT := &"augment_cult_of_personality"
const GAMBLER := &"augment_gamblers_rite"
var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _roll_seed(low: float, high: float) -> int:
	var fixture_rng := RandomNumberGenerator.new()
	for candidate in range(10000):
		fixture_rng.seed = candidate
		var roll := fixture_rng.randf()
		if roll > low and roll < high:
			return candidate
	_check(false, "a fixed roll exists between %.3f and %.3f" % [low, high])
	return 0


func _equip(id: StringName, level: int, transcended: bool = false) -> void:
	Global.permanent_augment_ids = [id, StringName(), StringName()]
	Global.attempt_augment_levels = {String(id): level}
	Global.attempt_augment_transcended = {String(id): true} if transcended else {}
	Global.attempt_doctrine_rules = {}
	Global.attempt_augment_duos = {}
	Global.run_luck = 0.0


func _curse() -> ItemInstance:
	var data := ItemData.new()
	data.id = "rank_reward_fixture"
	data.equip_slot = ItemData.EquipSlot.HP
	data.pct_min = -0.95
	data.mods = StatDelta.new()
	return ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.50, false)


func _gambler_roll(low: float, high: float) -> int:
	Global.followers = 1000
	Global.gambler_reset_segment()
	Global._rng.seed = _roll_seed(low, high)
	Global.gambler_note_acquisition(_curse())
	return int(Global.followers) - 1000


func _run() -> void:
	var saved_ids: Array[StringName] = Global.permanent_augment_ids.duplicate()
	var saved_levels: Dictionary = Global.attempt_augment_levels.duplicate(true)
	var saved_transcended: Dictionary = Global.attempt_augment_transcended.duplicate(true)
	var saved_doctrines: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	var saved_duos: Dictionary = Global.attempt_augment_duos.duplicate(true)
	var saved_luck: float = Global.run_luck
	var saved_followers: int = Global.followers
	var saved_congregation: int = Global.attempt_congregation
	var saved_rng_state: int = Global._rng.state
	var saved_seen: Dictionary = Global.attempt_gambler_seen.duplicate(true)
	var saved_resonance: float = Global.attempt_gambler_resonance
	var saved_won: int = Global.attempt_gambler_followers

	_equip(CULT, 1)
	Global._rng.seed = _roll_seed(0.20, 0.24)
	_check(Global.bonus_kill_followers() == 1, "rank-1 Cult recruits below its 25% base chance")
	var cult_rank_seed := _roll_seed(0.28, 0.29)
	Global._rng.seed = cult_rank_seed
	_check(Global.bonus_kill_followers() == 0, "rank-1 Cult does not recruit above 25%")
	_equip(CULT, 3)
	Global._rng.seed = cult_rank_seed
	_check(Global.bonus_kill_followers() == 1, "Cult rank 3 recruits on the same roll at its 30% chance")
	_equip(CULT, 20)
	Global.run_luck = 100000.0
	Global._rng.seed = _roll_seed(0.76, 0.80)
	_check(Global.bonus_kill_followers() == 0, "ordinary Cult never exceeds its 75% chance cap")
	_equip(CULT, 1, true)
	Global._rng.seed = _roll_seed(0.45, 0.49)
	_check(Global.bonus_kill_followers() == 2, "Prophet doubles rank-1 chance and pays two Followers")
	_equip(CULT, 20, true)
	Global._rng.seed = _roll_seed(0.87, 0.89)
	_check(Global.bonus_kill_followers() == 2, "Prophet reaches its 90% cap")
	Global._rng.seed = _roll_seed(0.91, 0.93)
	_check(Global.bonus_kill_followers() == 0, "Prophet leaves rolls above 90% unpaid")

	_equip(GAMBLER, 1)
	_check(_gambler_roll(0.30, 0.34) == 1, "rank-1 Rite pays below its 35% base chance")
	_check(_gambler_roll(0.355, 0.36) == 0, "rank-1 Rite does not pay above 35%")
	_equip(GAMBLER, 2)
	_check(_gambler_roll(0.355, 0.36) == 1, "the acquisition path passes Rite rank 2 to its 36.5% chance")
	_equip(GAMBLER, 20)
	_check(_gambler_roll(0.58, 0.59) == 1, "ordinary rank-20 Rite reaches its 60% cap")
	_check(_gambler_roll(0.61, 0.62) == 0, "ordinary Rite never exceeds 60%, even at rank 20")
	_equip(GAMBLER, 20, true)
	_check(_gambler_roll(0.68, 0.69) == 2, "House Edge retains its two-Follower payout below 70%")
	_check(_gambler_roll(0.71, 0.72) == 0, "House Edge retains its 70% chance cap")

	Global.permanent_augment_ids = saved_ids
	Global.attempt_augment_levels = saved_levels
	Global.attempt_augment_transcended = saved_transcended
	Global.attempt_doctrine_rules = saved_doctrines
	Global.attempt_augment_duos = saved_duos
	Global.run_luck = saved_luck
	Global.followers = saved_followers
	Global.attempt_congregation = saved_congregation
	Global._rng.state = saved_rng_state
	Global.attempt_gambler_seen = saved_seen
	Global.attempt_gambler_resonance = saved_resonance
	Global.attempt_gambler_followers = saved_won
	print("PassiveAugmentRewardTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
