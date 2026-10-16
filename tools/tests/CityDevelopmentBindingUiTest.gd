extends Node
## Uses the production Game Binding lifecycle and actual AugmentSelect cards,
## with only unrelated world construction omitted from the fixture host.
const SELECT := preload("res://ui/augments/AugmentSelect.tscn")
const MISSILE := &"augment_magic_missile"
const TESLA := &"augment_tesla_aura"
class BindingHost:
	extends "res://scenes/game.gd"
	func _ready() -> void:
		pass
class WorldWitness:
	extends Node
	var ticks := 0
	var inputs := 0
	func _process(_delta: float) -> void:
		ticks += 1
	func _input(event: InputEvent) -> void:
		if event.is_pressed():
			inputs += 1
var _passes := 0
var _failures := 0
var _host: Node2D
var _witness: WorldWitness

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/city_development_binding_ui_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _frames(count: int = 3) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _run() -> void:
	if not Global.has_method("purchase_city_development"):
		_check(false, "city development API is available")
		_finish()
		return
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_fixture()
	_host = _make_host()
	_host.call("_spawn_augment_select")
	await _frames(4)
	var first := _host.get("augment_select") as CanvasLayer
	_check(first != null and Global.pending_augment_pick and get_tree().paused, "the first actual Binding opens with the world paused")
	if first == null:
		_finish()
		return
	var first_id := first.get_instance_id()
	var paused_ticks := _witness.ticks
	var paused_inputs := _witness.inputs
	await _click_normal_card(first)
	await _frames(5)
	var second := _host.get("augment_select") as CanvasLayer
	_check(Global.pending_augment_pick and int(Global.get("attempt_binding_rewards_remaining")) == 1, "the first normal selection keeps exactly one earned Echo choice pending")
	_check(second != null and second.get_instance_id() != first_id and second.visible, "Game presents a fresh second normal Binding after the first closes")
	_check(get_tree().paused and _witness.ticks == paused_ticks and _witness.inputs == paused_inputs, "world processing and gameplay input never resume between the two choices")
	if second == null:
		_finish()
		return
	var remaining := int(Global.get("attempt_binding_rewards_remaining"))
	# A delayed signal from the old popup must not consume the current reward.
	_host.call("_on_augment_chosen", null, first_id, 1)
	_check(int(Global.get("attempt_binding_rewards_remaining")) == remaining and _host.get("augment_select") == second, "a stale first-popup callback cannot consume or close the second reward")
	Global.save_current_profile()
	var loaded := SaveManager.load_slot(1)
	_check(loaded != null, "the between-choices save is readable")
	_host.queue_free()
	await _frames()
	get_tree().paused = false
	if loaded != null:
		SaveManager.current_save = loaded
		Global.apply_save(loaded)
		_check(Global.pending_augment_pick and int(Global.get("attempt_binding_rewards_remaining")) == 1, "save/reload preserves exactly the remaining reward")
	_host = _make_host()
	_host.call("_spawn_augment_select")
	await _frames(4)
	second = _host.get("augment_select") as CanvasLayer
	_check(second != null and second.visible and get_tree().paused, "Continue presents the remaining actual Binding before world processing")
	if second != null:
		await _click_normal_card(second)
		await _frames(5)
	_check(not Global.pending_augment_pick and int(Global.get("attempt_binding_rewards_remaining")) == 0 and not get_tree().paused, "the second normal choice finishes the earned queue and restores play")
	_check(_host.get("augment_select") == null, "the final popup is removed")
	_host.queue_free()
	await _frames()
	await _test_late_purchase()
	await _test_prior_pause()
	await _test_dev_start_with_pending_choice()
	_finish()

func _fixture() -> void:
	var profile := SaveData.new()
	profile.slot_index = 1
	profile.profile_name = "Binding Echo UI"
	SaveManager.current_save = profile
	SaveManager.current_slot = 1
	Global.apply_save(profile)
	Global.owned_augment_ids = [MISSILE, TESLA]
	Global.permanent_augment_ids = [MISSILE, TESLA, StringName()]
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.begin_segment_completion(1)
	Global.finish_segment_completion(1)
	_check(bool(Global.call("purchase_city_development", &"binding_echo", StringName())), "one earned Research chooses conditional Binding Echo")
	Global.start_new_attempt()
	Global.attempt_segment = 5
	Global.begin_segment_completion(5)
	Global.finish_segment_completion(5)
	Global.pending_big_choice = false
	_check(int(Global.get("attempt_binding_rewards_remaining")) == 2, "reaching the fifth Rite with the snapshotted perk earns two choices")

func _make_host() -> Node2D:
	var host := BindingHost.new()
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.augment_select_scene = SELECT
	var player := Node.new()
	player.name = "Player"
	host.add_child(player)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	host.add_child(ui)
	var hud := Control.new()
	hud.name = "HUD"
	ui.add_child(hud)
	_witness = WorldWitness.new()
	host.add_child(_witness)
	add_child(host)
	return host

func _click_normal_card(screen: CanvasLayer) -> void:
	var cards := screen.get_node("Center/VBox/CardsPanel/CardsMargin/Cards")
	var pick: Button = null
	for node: Node in cards.get_children():
		var card := node as Button
		var entry: Dictionary = card.get("card_entry") if card != null else {}
		if card != null and not AugmentBinding.needs_slot_choice(entry) and not AugmentBinding.needs_facet_choice(entry):
			pick = card
			break
	_check(pick != null, "the actual offer has a normal native card to select")
	if pick == null:
		return
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pick.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(1)

func _test_late_purchase() -> void:
	get_tree().paused = false
	var profile := SaveData.new()
	profile.slot_index = 2
	SaveManager.current_save = profile
	SaveManager.current_slot = 2
	Global.apply_save(profile)
	Global.start_new_attempt()
	Global.attempt_segment = 5
	Global.begin_segment_completion(5)
	Global.finish_segment_completion(5)
	_check(int(Global.get("attempt_binding_rewards_remaining")) == 1, "without a starting Echo the fifth Rite grants one normal Binding")
	_check(bool(Global.call("purchase_city_development", &"binding_echo", StringName())), "the first S5 clear can buy Echo for a later attempt")
	_check(int(Global.get("attempt_binding_rewards_remaining")) == 1, "buying Echo after S5 cannot retroactively double the active reward")

func _finish() -> void:
	get_tree().paused = false
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	print("CityDevelopmentBindingUiTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _test_prior_pause() -> void:
	_fixture()
	_host = _make_host()
	get_tree().paused = true
	_host.call("_spawn_augment_select")
	await _frames(4)
	var first := _host.get("augment_select") as CanvasLayer
	if first != null:
		await _click_normal_card(first)
		await _frames(5)
	var second := _host.get("augment_select") as CanvasLayer
	var had_second := second != null
	if second != null:
		await _click_normal_card(second)
		await _frames(5)
	_check(had_second and not Global.pending_augment_pick and get_tree().paused, "both choices preserve a genuine prior pause after the queue finishes")
	_host.queue_free()
	await _frames()
	get_tree().paused = false

func _test_dev_start_with_pending_choice() -> void:
	# The existing isolated Dev Segment route strips chunks, nav and spawners
	# before ready. Its entry sequence intentionally suppresses Binding UI.
	get_tree().paused = false
	Global.start_new_attempt()
	Global.debug_dev_segment = true
	Global.debug_dev_mode = true
	Global.attempt_segment = 2
	Global.pending_augment_pick = true
	var scene := load("res://scenes/game.tscn") as PackedScene
	_check(scene != null, "the production Game scene loads for developer-start coverage")
	if scene != null:
		var game := scene.instantiate()
		game.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(game)
		await _frames(4)
		_check(game.get_node_or_null("DevSegment") != null and game.get_node_or_null("Spawner") == null, "developer-start coverage uses the existing isolated production route")
		_check(not get_tree().paused and game.get("augment_select") == null, "a later developer segment stays playable when a fresh library or Force Augment leaves a pending choice")
		game.queue_free()
		await _frames()
	get_tree().paused = false
	Global.debug_dev_segment = false
	Global.debug_dev_mode = false
	Global.pending_augment_pick = false
