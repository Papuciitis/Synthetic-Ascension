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


func _ready() -> void:
	call_deferred(&"_run")


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


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

	player.position = Vector2(200.0, 0.0)
	vault._process(1.0)
	_check(bool(vault.get("_announced")), "approaching announces the vault and its cost")
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

	RunEvents.tutorial_tip.disconnect(_on_tip)
	for node in [reward, third_reward, fourth_reward]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	vault.queue_free()
	second.queue_free()
	third.queue_free()
	fourth.queue_free()
	player.queue_free()
	locking.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("CursedVaultTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
