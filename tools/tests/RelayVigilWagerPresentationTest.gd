extends Node
## Presentation observes real holds and purchases; it never owns their clocks.
const RELAY := preload("res://core/systems/world/objectives/DistrictRelayObjective.gd")
const VIGIL := preload("res://core/systems/world/objectives/WardVigilObjective.gd")
const WAGER := preload("res://core/systems/world/objectives/WagerShrineObjective.gd")
var _passes := 0
var _failures := 0

class TestPlayer extends Node2D:
	var is_dead := false

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _install(script: Script) -> Node2D:
	var instance := script.new() as Node2D
	add_child(instance)
	instance.set_process(false)
	return instance

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	var writes_before := int(SaveManager.debug_save_writes)
	await _test_relay()
	await _test_vigil()
	await _test_wager()
	_check(int(SaveManager.debug_save_writes) == writes_before, "presentation and purchase fixtures write no saves")
	print("RelayVigilWagerPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)

func _test_relay() -> void:
	var relay := _install(RELAY) as DistrictRelayObjective
	_check(relay.objective_art == null and relay.get_node_or_null("ObjectiveArt") == null, "Relay has no fourth actionable-looking center receiver")
	var sites: Array = relay.get("_site_art")
	var positions: Array = relay.get("_component_positions")
	_check(sites.size() == 3 and positions.size() == 3, "exactly three default Relay receivers remain at the real sites")
	_check(is_equal_approx(relay.attune_radius_px, 96.0) and is_equal_approx(relay.attune_time_sec, 1.1), "Relay retains its exact radius and dwell")
	var player := TestPlayer.new()
	add_child(player)
	relay.player = player
	player.global_position = relay.global_position + positions[0]
	relay.tick_active(0.55)
	var before: PackedFloat32Array = relay.get("_component_progress").duplicate()
	player.global_position = relay.global_position
	relay.tick_active(3.0)
	relay.update_presentation()
	_check(relay.get("_component_progress") == before, "leaving a Relay node banks exactly the earned hold")
	_check(sites[0].get("_state") == "dormant", "banked Relay hold is steady instead of an active working glow")
	player.global_position = relay.global_position + positions[0]
	relay.tick_active(0.6)
	relay.update_presentation()
	_check(sites[0].get("_state") == "complete", "silenced receiver changes its physical art state")
	var shutter := relay.get_node_or_null("RelayShutter0")
	_check(shutter != null and bool(shutter.get("closed")), "silenced receiver closes a static mechanical shutter")
	for _index in range(4):
		relay.update_presentation()
	_check(relay.get("_component_progress")[1] == 0.0 and relay.steps_done() == 1, "Relay presentation cannot advance another site")
	relay.finish()
	_check(sites.all(func(site: Sprite2D) -> bool: return site.get("_state") == "complete"), "restored Relay completion immediately shutters every real receiver")
	_check(shutter != null and not shutter.z_as_relative and shutter.z_index < 0, "receiver ground shutter stays below actor bodies")
	relay.queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_vigil() -> void:
	var vigil := _install(VIGIL) as WardVigilObjective
	var player := TestPlayer.new()
	add_child(player)
	vigil.player = player
	_check(is_equal_approx(vigil.vigil_radius_px, 190.0) and is_equal_approx(vigil.vigil_seconds, 26.0), "Vigil retains its true 190 px area and 26 second hold")
	player.global_position = vigil.global_position
	vigil.tick_active(4.0)
	vigil.update_presentation()
	var braces := vigil.get_node_or_null("VigilBraces")
	_check(braces != null, "Vigil has a physical brace assembly")
	if braces != null:
		_check(braces.get("phase") == "holding", "holding engages static inward braces")
	player.global_position = vigil.global_position + Vector2(191.0, 0.0)
	vigil.tick_active(0.6)
	vigil.update_presentation()
	if braces != null:
		_check(braces.get("phase") == "grace", "brief exit has an open grace shape before decay")
	_check(is_equal_approx(float(vigil.get("_held")), 4.0), "Vigil grace does not drain hold")
	vigil.tick_active(0.7)
	vigil.update_presentation()
	if braces != null:
		_check(braces.get("phase") == "draining", "actual decay drops and separates the braces")
	_check(is_equal_approx(float(vigil.get("_held")), 3.65), "Vigil drains at the existing half-second rate after grace")
	var held_before := float(vigil.get("_held"))
	var wave_before := int(vigil.get("_wave"))
	for _index in range(4):
		vigil.update_presentation()
	_check(is_equal_approx(float(vigil.get("_held")), held_before) and int(vigil.get("_wave")) == wave_before, "Vigil presentation cannot advance hold or waves")
	player.global_position = vigil.global_position
	vigil.tick_active(0.1)
	player.is_dead = true
	vigil.on_player_dead(0.4)
	vigil.update_presentation()
	if braces != null:
		_check(braces.get("phase") == "draining", "corpse decay shows draining without waiting for the living exit-grace clock")
	_check(vigil.objective_art.get("_state") == "draining", "corpse decay cannot look like stored grace")
	vigil.finish()
	if braces != null:
		_check(braces.get("phase") == "complete", "completion immediately engages the cap without another tick")
	_check(vigil.objective_art.get("_state") == "complete", "Vigil completion immediately changes its art")
	_check(braces != null and not braces.z_as_relative and braces.z_index < 0, "Vigil ground braces stay below actor bodies")
	vigil.queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_wager() -> void:
	var old_followers := int(Global.followers)
	var old_segment := int(Global.attempt_segment)
	var old_luck := float(Global.run_luck)
	Global.attempt_segment = 10
	Global.run_luck = 40.0
	Global.followers = 100000
	var wager := _install(WAGER) as WagerShrineObjective
	var player := TestPlayer.new()
	add_child(player)
	wager.set("_player", player)
	player.global_position = wager.global_position
	_check(is_equal_approx(wager.radius_px, 118.0) and is_equal_approx(wager.seconds_per_tier, 2.2), "Wager retains its exact radius and purchase interval")
	if not wager.has_method("presentation_lines") or not wager.has_method("purchase_fraction"):
		_check(false, "Wager exposes pure truthful tier/cost/dwell presentation")
	else:
		var lines: PackedStringArray = wager.call("presentation_lines")
		_check("\n".join(lines).contains(str(WAGER.tier_stake(0))), "first price uses the current segment scale")
		Global.followers = 0
		var unavailable := "\n".join(wager.call("presentation_lines"))
		_check(unavailable.contains("unavailable") and not unavailable.contains("Stand to pay"), "unaffordable approach cannot invite a ready purchase")
		Global.followers = 100000
		wager._process(1.1)
		_check(is_equal_approx(float(wager.call("purchase_fraction")), 0.5), "purchase indicator measures the next dwell, separately from paid tiers")
		var before := int(Global.followers)
		for _index in range(8):
			wager.call("presentation_lines")
			wager.call("update_presentation")
		_check(int(Global.followers) == before and int(wager.get("_tier")) == -1, "price display never buys a tier or spends Followers")
		wager._process(1.11)
		_check(int(wager.get("_tier")) == 0 and int(Global.followers) == before - WAGER.tier_stake(0), "real hold still buys exactly one scaled tier")
		lines = wager.call("presentation_lines")
		var joined := "\n".join(lines)
		_check(joined.contains("1/3") and joined.contains("%d%%" % int(round(wager.odds_for(0) * 100.0))), "display reports the paid tier and real Luck-adjusted odds")
		_check(joined.contains(str(WAGER.tier_stake(1))) and joined.contains("Step out to settle"), "next scaled price and exit-to-settle action are explicit")
		Global.followers = 0
		wager._process(2.2)
		joined = "\n".join(wager.call("presentation_lines"))
		_check(joined.contains("refused") and joined.contains("reconstruction"), "actual unaffordable tier explicitly explains reserve refusal")
		_check(int(wager.get("_tier")) == 0 and int(Global.followers) == 0, "refused tier cannot spend currency")
		# Settlement seed is selected to lose, so this exact gameplay path needs
		# no fake reward nodes and does not modify the real inventory.
		var paid := int(wager.get("_spent"))
		var losing_seed_found := false
		for objective_id in range(1, 1000):
			var rng := RandomNumberGenerator.new()
			rng.seed = int(hash("wager:%d:0:%d" % [objective_id, paid]))
			if rng.randf() > wager.odds_for(0):
				wager.configure(objective_id)
				losing_seed_found = true
				break
		_check(losing_seed_found, "real losing settlement seed exists without fake reward staging")
		if losing_seed_found:
			player.global_position += Vector2(119.0, 0.0)
			wager._process(0.01)
			_check(bool(wager.get("_finished")), "crossing the real 118 px edge settles the paid stake")
			_check(wager.objective_art.get("_state") == "spent", "settlement immediately selects physical spent art")
			var fixture := wager.get_node_or_null("WagerLock")
			_check(fixture != null and bool(fixture.get("closed")), "settled scales acquire a static locked tray")
			_check(fixture != null and not fixture.z_as_relative and fixture.z_index < 0, "settled tray stays below actor bodies")
	wager.queue_free()
	player.queue_free()
	await get_tree().process_frame
	Global.followers = old_followers
	Global.attempt_segment = old_segment
	Global.run_luck = old_luck
