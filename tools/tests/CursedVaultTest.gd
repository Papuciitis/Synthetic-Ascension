extends Node

# Roadmap Phase 2.5: one deliberate risk/reward moment. The vault must be a
# CHOICE (stand inside it for open_time, announced on approach), pay out a
# guaranteed Manifestation on a high-rarity item, and immediately bill the
# player through the encounter director.

const VaultScript = preload("res://core/systems/world/CursedVault.gd")

class FakePlayer:
	extends Node2D
	var is_dead := false

# Cluster B's player grows lock_healing(seconds, reason); the vault bills it
# through has_method, so a player with it is locked and one without is fine.
class LockingPlayer:
	extends FakePlayer
	var locks: Array = []

	func lock_healing(seconds: float, reason: StringName) -> void:
		locks.append([seconds, reason])

class FakeDirector:
	extends Node
	var beats: Array[StringName] = []

	func try_spawn_beat(id: StringName) -> Dictionary:
		beats.append(id)
		return {"id": id}

var _passes := 0
var _failures := 0
var _opened_signals := 0
var _tips: Array[String] = []
var _vault_draws := 0


func _ready() -> void:
	call_deferred(&"_run")


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _on_vault_draw() -> void:
	_vault_draws += 1


## Rendered frames, so every queue_redraw() requested since the last one has
## turned into a _draw. Headless issues NOTIFICATION_DRAW like any other build;
## it only draws into a dummy rasteriser.
func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _popups_since(start: int) -> PackedStringArray:
	var texts := PackedStringArray()
	for index in range(start, int(BattleText.get("_count"))):
		texts.append(BattleText._texts[index])
	return texts


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_check(Global != null and not Global.item_db.is_empty(), "the item database is loaded")
	RunEvents.tutorial_tip.connect(_on_tip)
	# Popups are what the announce pins count, and the setting gates them.
	var saved_callouts: Variant = SettingsManager.get_value(&"accessibility", &"ability_callouts", true)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	player.position = Vector2(2000.0, 0.0)
	add_child(player)
	var director := FakeDirector.new()
	director.add_to_group(&"encounter_director")
	add_child(director)
	var vault := VaultScript.new()
	vault.open_time = 3.0
	vault.position = Vector2.ZERO
	add_child(vault)
	vault.opened.connect(func(_v: Node) -> void: _opened_signals += 1)

	vault._process(1.0)
	_check(not bool(vault.get("_announced")) and vault.progress() == 0.0, "a distant player sees and does nothing")

	var popups_before := int(BattleText.get("_count"))
	player.position = Vector2(200.0, 0.0)
	vault._process(1.0)
	_check(bool(vault.get("_announced")), "approaching announces the vault and its cost")
	_check(int(BattleText.get("_count")) == popups_before + 1 and String(BattleText._texts[popups_before]) == "CURSED VAULT", "as CURSED VAULT, by default (%s)" % [_popups_since(popups_before)])
	_check(vault.cost_heal_lock_sec == 45.0 and not vault.cost_all_safeguards, "the defaults: a 45 s heal lock, no safeguard cost")
	_check(_tips.size() == 1 and _tips[0].contains("Something will come for you") and _tips[0].contains("No healing for 45s"), "the sign carries the whole bill - the hunt and the healing (%s)" % [_tips])
	_check(vault.progress() == 0.0, "standing outside the open radius does not open it")

	player.position = Vector2(10.0, 0.0)
	vault._process(1.5)
	_check(is_equal_approx(vault.progress(), 0.5), "standing inside fills the channel (%.2f)" % vault.progress())
	player.position = Vector2(200.0, 0.0)
	vault._process(1.0)
	_check(vault.progress() < 0.5 and vault.progress() > 0.0, "stepping out bleeds progress instead of voiding it (%.2f)" % vault.progress())
	player.position = Vector2(0.0, 0.0)
	vault._process(3.0)
	_check(vault.is_opened(), "holding for open_time opens the vault")
	_check(not player.has_method("lock_healing") and vault.is_opened(), "a player without lock_healing pays the other costs and the vault still opens")
	_check(_opened_signals == 1, "the vault signals once")
	var reward := vault.reward() as ItemPickup
	_check(reward != null, "opening spawns a reward pickup")
	if reward != null:
		var inst: ItemInstance = reward.item_instance
		_check(inst != null and inst.rarity >= vault.reward_rarity_min, "the reward is high rarity (%s)" % [inst.rarity if inst != null else -1])
		_check(inst != null and inst.has_manifestation(), "the reward carries a guaranteed Manifestation (%s)" % [inst.manifestation_id if inst != null else &""])
	_check(director.beats.size() == 2 and director.beats.has(&"hunter") and director.beats.has(&"charger_wedge"), "the cost is billed immediately: a hunter and a wedge (%s)" % [director.beats])

	vault._process(3.0)
	_check(_opened_signals == 1 and director.beats.size() == 2, "a vault opens once")

	# --- idle cost: the vault paints the channel, not the clock (perf audit
	# 2026-08-28 §2, below the cut) ---
	var idle := VaultScript.new()
	idle.position = Vector2(3200.0, 0.0)
	add_child(idle)
	idle.draw.connect(_on_vault_draw)
	player.position = Vector2(3200.0, 400.0)
	await _frames(3)
	_vault_draws = 0
	await _frames(8)
	_check(_vault_draws == 0, "a vault nobody is standing in repaints nothing (%d draws in 8 frames)" % _vault_draws)

	_vault_draws = 0
	player.position = Vector2(3200.0, 0.0)
	await _frames(3)
	_check(_vault_draws > 0, "standing in it paints the filling channel again (%d draws)" % _vault_draws)

	_vault_draws = 0
	player.position = Vector2(3200.0, 400.0)
	idle._process(60.0)
	await _frames(2)
	var bleed_draws := _vault_draws
	_check(idle.progress() == 0.0, "stepping out bleeds the channel back to empty")
	_vault_draws = 0
	await _frames(8)
	_check(
		bleed_draws > 0 and _vault_draws == 0,
		"the bleed paints down to the empty ring and then stops (%d then %d)" % [bleed_draws, _vault_draws]
	)

	player.position = Vector2(3200.0, 0.0)
	idle._process(idle.open_time + 0.1)
	_check(idle.is_opened(), "the idle vault opens when stood in")
	_check(not idle.is_processing(), "an opened vault stops processing")
	idle.draw.disconnect(_on_vault_draw)
	var idle_reward := idle.reward()

	# A dead body inside the vault cannot channel it.
	var second := VaultScript.new()
	second.position = Vector2(600.0, 0.0)
	add_child(second)
	player.position = Vector2(600.0, 0.0)
	player.is_dead = true
	second._process(5.0)
	_check(not second.is_opened(), "a dead player does not open a vault")
	player.is_dead = false

	# --- the healing lock (plan 2.5) reaches a player that has one ---
	player.remove_from_group(&"player")
	var locking := LockingPlayer.new()
	locking.add_to_group(&"player")
	locking.position = Vector2(1200.0, 0.0)
	add_child(locking)
	var third := VaultScript.new()
	third.position = Vector2(1200.0, 0.0)
	add_child(third)
	third._process(third.open_time + 0.1)
	_check(third.is_opened(), "the third vault opens")
	_check(locking.locks == [[45.0, &"cursed_vault"]], "opening locks healing for cost_heal_lock_sec, billed to the vault (%s)" % [locking.locks])
	var third_reward := third.reward()

	# --- the safeguard cost without a rite in reach, and no lock at 0 ---
	var fourth := VaultScript.new()
	fourth.position = Vector2(1800.0, 0.0)
	fourth.cost_all_safeguards = true
	fourth.cost_heal_lock_sec = 0.0
	var no_beats: Array[StringName] = []
	fourth.cost_beats = no_beats
	add_child(fourth)
	_check(fourth.announcement().contains("every safeguard") and not fourth.announcement().contains("Something will come") and not fourth.announcement().contains("healing"), "the sign lists only the costs configured (%s)" % fourth.announcement())
	locking.position = Vector2(1800.0, 0.0)
	fourth._process(fourth.open_time + 0.1)
	_check(fourth.is_opened(), "a safeguard-cost vault with no rite in the tree still opens")
	_check(locking.locks.size() == 1, "a zero heal lock bills nothing")
	var fourth_reward := fourth.reward()

	# --- the announce is the vault's own, under whatever name it is spawned ---
	# The rite's last chance (plan 2.8) spawns one of these with the player
	# already inside its approach radius and tells it to announce at once.
	var fifth := VaultScript.new()
	fifth.position = Vector2(2400.0, 0.0)
	fifth.announce_label = "LAST CHANCE"
	fifth.announce_line = "LAST CHANCE — a vault at the rite's edge: a guaranteed Manifestation."
	fifth.cost_all_safeguards = true
	fifth.cost_beats = no_beats
	add_child(fifth)
	locking.position = Vector2(2600.0, 0.0)
	var tips_before := _tips.size()
	var popups_at_spawn := int(BattleText.get("_count"))
	fifth.announce()
	fifth.announce()
	fifth._process(0.016)
	var popups := int(BattleText.get("_count")) - popups_at_spawn
	_check(popups == 1 and String(BattleText._texts[popups_at_spawn]) == "LAST CHANCE", "a vault told to announce pops its label once - a repeat and the approach add nothing (%s)" % [_popups_since(popups_at_spawn)])
	_check(_tips.size() == tips_before + 1 and _tips[tips_before] == "LAST CHANCE — a vault at the rite's edge: a guaranteed Manifestation. It takes every safeguard. No healing for 45s.", "and one line: its own sign, opening with the line it was given, with the whole bill (%s)" % [_tips.slice(tips_before)])
	_check(vault.announce_label == "CURSED VAULT" and vault.announcement().begins_with("Stand in the vault to open it: a guaranteed Manifestation."), "the default vault keeps its label and its line")

	RunEvents.tutorial_tip.disconnect(_on_tip)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", saved_callouts, false)
	for node in [reward, idle_reward, third_reward, fourth_reward]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	vault.queue_free()
	idle.queue_free()
	second.queue_free()
	third.queue_free()
	fourth.queue_free()
	fifth.queue_free()
	player.queue_free()
	locking.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("CursedVaultTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
