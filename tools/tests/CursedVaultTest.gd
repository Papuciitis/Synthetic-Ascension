extends Node

# Roadmap Phase 2.5: one deliberate risk/reward moment. The vault must be a
# CHOICE (stand inside it for open_time, announced on approach), pay out a
# guaranteed Manifestation on a high-rarity item, and immediately bill the
# player through the encounter director.

const VaultScript = preload("res://core/systems/world/CursedVault.gd")

class FakePlayer:
	extends Node2D
	var is_dead := false

class FakeDirector:
	extends Node
	var beats: Array[StringName] = []

	func try_spawn_beat(id: StringName) -> Dictionary:
		beats.append(id)
		return {"id": id}

var _passes := 0
var _failures := 0
var _opened_signals := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_check(Global != null and not Global.item_db.is_empty(), "the item database is loaded")
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

	if reward != null:
		reward.queue_free()
	vault.queue_free()
	second.queue_free()
	player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("CursedVaultTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
