extends Node
## State signs observe real gameplay; they never buy, clear, revive, or claim.
const VAULT := preload("res://core/systems/world/CursedVault.gd")
const RITUAL := preload("res://core/systems/world/RitualInterference.gd")
const VOLUME := preload("res://scenes/world/volumes/IndoorVolume.tscn")
const DEATH := preload("res://core/systems/enemy_world/EnemyDeathContext.gd")
var _passes := 0
var _failures := 0

class Player:
	extends Node2D
	var is_dead := false
	var locks: Array[float] = []
	func lock_healing(seconds: float, _reason: StringName) -> void:
		locks.append(seconds)

class Rite:
	extends Node2D
	var safeguards := 2
	func safeguard_count() -> int:
		return safeguards
	func drain_safeguards(_reason: StringName) -> int:
		var paid := safeguards
		safeguards = 0
		return paid

class Director:
	extends Node
	var beats: Array[StringName] = []
	func try_spawn_beat(id: StringName) -> Dictionary:
		beats.append(id)
		return {"id": id}

func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/vault_exploration_presentation/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)

func _ready() -> void:
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		push_error("VaultExplorationPresentationTest incomplete or timed out")
		get_tree().quit(1))
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var writes := SaveManager.debug_save_writes
	var player := Player.new()
	player.add_to_group(&"player")
	player.position = Vector2(1000, 1000)
	add_child(player)
	var director := Director.new()
	director.add_to_group(&"encounter_director")
	add_child(director)
	var vault := VAULT.new()
	add_child(vault)
	vault.set_process(false)
	_check(vault.has_method("presentation_state"), "vault exposes the physical state its art reads")
	_check(vault.has_method("commitment_lines"), "vault has persistent precommitment reward and bill")
	if vault.has_method("presentation_state") and vault.has_method("commitment_lines"):
		_check(vault.open_radius == 64.0 and vault.open_time == 3.0, "vault still uses its true 64 px / three second hold")
		var lines: PackedStringArray = vault.call("commitment_lines")
		_check("\n".join(lines).contains("Guaranteed Manifestation") and "\n".join(lines).contains("Hunter + wedge") and "\n".join(lines).contains("45 s"), "ordinary vault sign states the actual reward, encounter, and healing bill")
		player.position = Vector2.ZERO
		vault._process(1.5)
		_check(vault.call("presentation_state") == "working" and is_equal_approx(vault.progress(), 0.5), "half-open shape reads live channel progress")
		player.is_dead = true
		vault._process(9.0)
		_check(vault.call("presentation_state") == "paused" and is_equal_approx(vault.progress(), 0.5), "a dead player freezes the actual channel and displays a paused physical state")
		var paused_text := "\n".join(vault.call("commitment_lines"))
		_check(paused_text.contains("Opening paused") and not paused_text.contains("decays"), "a frozen channel never claims to be draining")
		player.is_dead = false
		player.remove_from_group(&"player")
		vault.set("_player", null)
		vault._process(9.0)
		_check(vault.call("presentation_state") == "paused" and is_equal_approx(vault.progress(), 0.5), "a missing player pauses the actual channel and its presentation")
		player.add_to_group(&"player")
		player.position = Vector2(200, 0)
		vault._process(1.0)
		_check(vault.call("presentation_state") == "draining" and is_equal_approx(vault.progress(), 1.0 / 3.0), "leaving shows decay and preserves the original half-speed bleed")
		player.position = Vector2.ZERO
		vault._process(3.0)
		var reward := vault.reward() as ItemPickup
		_check(vault.call("presentation_state") == "spent" and not vault.is_processing(), "genuine opening latches the empty physical form immediately")
		_check(reward != null and reward.item_instance != null and reward.item_instance.has_manifestation(), "genuine opening pays its promised Manifestation")
		_check(player.locks == [45.0], "ordinary opening bills healing once")
		_check(director.beats == [&"hunter", &"charger_wedge"], "ordinary opening requests exactly the hunter and wedge")
		if reward != null:
			reward.queue_free()
	vault.queue_free()
	var rite := Rite.new()
	rite.add_to_group(&"exit_rite")
	add_child(rite)
	var chance := VAULT.new()
	chance.cost_all_safeguards = true
	chance.cost_beats = []
	rite.add_child(chance)
	chance.set_process(false)
	if chance.has_method("commitment_lines"):
		var text := "\n".join(chance.call("commitment_lines"))
		_check(text.contains("all 2 safeguards") and text.contains("No extra encounter") and not text.contains("Hunter"), "Last Chance reads actual remaining safeguards and no extra encounter")
		rite.safeguards = 0
		text = "\n".join(chance.call("commitment_lines"))
		_check(text.contains("all 0 safeguards"), "zero safeguards stays truthful")
		chance._process(0.0)
		var fixtures := chance.get_node("VaultFasteners")
		_check(int(fixtures.get("sacrifices")) == 0, "zero remaining safeguards draws no invented charged shields")
		rite.safeguards = 6
		text = "\n".join(chance.call("commitment_lines"))
		_check(text.contains("all 6 safeguards"), "expanded safeguard capacity is never depicted as three fixed pips")
		chance._process(0.0)
		_check(int(fixtures.get("sacrifices")) == 6 and not bool(fixtures.get("spent")), "all six actual charges feed the intact shield fixtures before purchase")
		chance._process(3.0)
		_check(int(fixtures.get("sacrifices")) == 6 and bool(fixtures.get("spent")), "the six paid charges remain as broken empty shield fixtures after purchase")
		_check(rite.safeguards == 0 and player.locks == [45.0, 45.0] and director.beats.size() == 2, "Last Chance genuinely takes all six safeguards and 45 seconds healing, without another encounter")
		var chance_reward := chance.reward() as ItemPickup
		_check(chance_reward != null and chance_reward.item_instance != null and chance_reward.item_instance.has_manifestation() and chance.call("presentation_state") == "spent", "genuine Last Chance pays and physically spends immediately")
		if chance_reward != null:
			chance_reward.queue_free()
	rite.queue_free()
	var volume := VOLUME.instantiate() as IndoorVolume
	volume.configure(Vector2i(20, 20), Vector2i(6, 5), 64, 9898, {"local_encounter_enabled": true, "secondary_objective_id": 777})
	add_child(volume)
	_check(volume.has_method("configure_presentation_entry") and volume.has_method("presentation_status"), "building uses the real doorway and encounter state for its sign")
	if volume.has_method("presentation_status"):
		volume.call("configure_presentation_entry", Vector2(1472, 1664), Vector2.DOWN, 128.0)
		_check(volume.get_node_or_null("BuildingEntrySign") != null and volume.get_node_or_null("ServiceRoomFloorTone") != null, "real doorway configuration builds the threshold sign and quiet interior floor")
		var volume_shape := volume.get_node("CollisionShape2D") as CollisionShape2D
		_check((volume_shape.shape as RectangleShape2D).size == Vector2(384, 320), "entrance presentation preserves the actual encounter volume")
		_check(String(volume.call("presentation_status")).contains("Enter and clear security"), "unentered guarded building invites the actual action")
		volume.set("_encounter_started", true)
		volume.set("_encounter_remaining", 4)
		_check(String(volume.call("presentation_status")).contains("4 security remaining"), "active building shows actual remaining security")
		volume.set("_encounter_completed", true)
		_check(String(volume.call("presentation_status")).contains("Security cleared"), "cleared building replaces its invitation")
	volume.queue_free()
	var ritual := RITUAL.new()
	add_child(ritual)
	ritual.set_process(false)
	_check(ritual.has_method("corpse_return_fraction"), "ritual exposes honest local corpse countdown")
	if ritual.has_method("corpse_return_fraction"):
		var actor := Node2D.new()
		actor.scene_file_path = "res://scenes/world/enemies/EnemyGrunt.tscn"
		add_child(actor)
		ritual.actor_provider = func(_handle: int) -> Node: return actor
		ritual._on_enemy_defeated(DEATH.new(1, &"enemy_grunt", Vector2(10, 20), 0, null, {}))
		_check(ritual.pending() == 1 and is_equal_approx(float(ritual.call("corpse_return_fraction", 0)), 0.0), "only actual affected corpses receive a fresh return mark")
		ritual._process(0.8)
		_check(is_equal_approx(float(ritual.call("corpse_return_fraction", 0)), 0.5), "corpse countdown reads the real 1.6 second pending interval")
		ritual.expire()
		_check(ritual.pending() == 0, "expiry removes corpse cues with the real pending queue")
		actor.queue_free()
	else:
		ritual.expire()
	player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	_check(SaveManager.debug_save_writes == writes, "presentation and real vault payout write no saves")
	print("VaultExplorationPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
