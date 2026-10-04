extends Node

# The story layer (core/systems/narrative, data/narrative/StoryLines.gd):
# the picker's priorities, once-scopes, conditions and determinism; an
# account recorded across a simulated death BEFORE Global wipes the attempt
# (the reset-order trap), with its epitaph and the Chronicler's relay; the
# save round trip in memory; the square keyed on the COMPLETED segment;
# arrivals, bulletins and the Registry's name ladder; Bren's dispatches;
# reconstruction cards; Follower milestones; the Area I card; the loading
# card, Game Over and square wiring; and the copy rules (the name only on
# that card's last line, Beka in no pool, hub lines that fit their bubbles).
# Never writes a save slot: SaveManager.current_save stays null.
#
# Run: <godot> --headless --path . res://tools/tests/StoryDirectorTest.tscn

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const GAME_OVER := preload("res://ui/screens/GameOverUI.tscn")
const HubText := preload("res://scenes/hub/ui/HubText.gd")
const RUNNER_SPEC := preload("res://core/actors/enemy/EnemySpec_Runner.tres")


class FakeEnemy:
	extends Node
	var spec: EnemySpec = null


class FakeProjectile:
	extends Node
	var shooter: Node = null


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


func _run() -> void:
	SaveManager.current_save = null
	var saved_story := StoryDirector.state_for_save()
	var saved_grimoire: Array[String] = Global.grimoire_entries.duplicate()
	var saved_name: String = Global.mortal_name
	var saved_response: StringName = Global.opening_response_id
	var saved_race: String = Global.selected_race_id
	var saved_style: String = Global.selected_style_id
	Global.selected_race_id = "human"
	Global.selected_style_id = "ranged"

	_test_picker()
	_test_conditions()
	_test_account()
	_test_fatal_death()
	_test_save_round_trip()
	_test_completed_segment_keys()
	_test_arrivals()
	_test_bren()
	_test_reconstruction()
	_test_milestones()
	_test_chapter_card()
	_test_crowd_and_staff()
	_test_copy_rules()
	_test_copy_fit()
	await _test_surfaces()
	await _test_square()

	Global.mortal_name = saved_name
	Global.opening_response_id = saved_response
	Global.selected_race_id = saved_race
	Global.selected_style_id = saved_style
	Global.grimoire_entries = saved_grimoire
	StoryDirector.load_state(saved_story)
	SaveManager.current_save = null
	print("StoryDirectorTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _fresh(segment: int, world_seed: int = 4242) -> void:
	Global.start_new_attempt()
	Global.attempt_world_seed = world_seed
	Global.attempt_segment = segment
	StoryDirector.take_pending()


# ---------------------------------------------------------------- picker

func _test_picker() -> void:
	StoryDirector.load_state({})
	_fresh(1)
	var pool: Array = [
		{"id": "flavour_a", "p": 10, "text": "a"},
		{"id": "flavour_b", "p": 10, "text": "b"},
		{"id": "beat", "p": 80, "once": "profile", "text": "beat"},
		{"id": "late", "p": 90, "once": "attempt", "when": {"seg_min": 3}, "text": "late"},
		{"id": "relay", "p": 85, "once": "account", "text": "relay"},
		{"id": "never", "p": 99, "when": {"seg_max": 0}, "text": "never"},
	]
	var rng := _rng(1)
	var f := {"seg": 1}
	_check(String(StoryDirector.pick(pool, f, rng)["id"]) == "relay", "the highest eligible beat wins first (85 over 80; 90 and 99 fail their conditions)")
	_check(String(StoryDirector.pick(pool, f, rng)["id"]) == "beat", "a spent beat steps aside for the next")
	var third := String(StoryDirector.pick(pool, f, rng)["id"])
	_check(third == "flavour_a" or third == "flavour_b", "with the beats spent, the flavour lines are drawn (%s)" % third)
	f["seg"] = 3
	_check(String(StoryDirector.pick(pool, f, rng)["id"]) == "late", "a condition coming true makes its beat eligible")
	_check(int(StoryDirector.pick(pool, f, rng)["p"]) == 10, "an attempt-once beat stays spent within the attempt")
	StoryDirector.begin_attempt()
	_check(String(StoryDirector.pick(pool, f, rng)["id"]) == "late", "a new attempt resets the attempt-once flags")
	var peek := StoryDirector.pick(pool, f, rng, [], false)
	_check(int(peek.get("p", 0)) == 10, "the profile and account beats stay spent across attempts (%s)" % String(peek.get("id", "")))
	StoryDirector.close_account()
	_check(String(StoryDirector.pick(pool, {"seg": 1}, rng)["id"]) == "relay", "closing an account frees the once-per-account line")
	var avoided := true
	for i in range(20):
		if String(StoryDirector.pick(pool, {"seg": 1}, rng, ["flavour_a"])["id"]) == "flavour_a":
			avoided = false
	_check(avoided, "a recent flavour line is skipped while another is left")
	var seq_a: Array = []
	var seq_b: Array = []
	var rng_a := _rng(77)
	var rng_b := _rng(77)
	for i in range(12):
		seq_a.append(StoryDirector.pick(pool, {"seg": 1}, rng_a)["id"])
		seq_b.append(StoryDirector.pick(pool, {"seg": 1}, rng_b)["id"])
	_check(seq_a == seq_b, "the same seed draws the same lines")
	var weighted: Array = [{"id": "heavy", "w": 9.0, "text": "h"}, {"id": "light", "w": 1.0, "text": "l"}]
	var heavy := 0
	var rng_w := _rng(5)
	for i in range(400):
		if String(StoryDirector.pick(weighted, {}, rng_w)["id"]) == "heavy":
			heavy += 1
	_check(heavy > 320 and heavy < 395, "flavour is drawn by weight (%d of 400 heavy at 9:1)" % heavy)
	_check(StoryDirector.pick(pool, {"seg": 1}, rng, [], false).size() > 0 and StoryDirector.pick([], {}, rng).is_empty(), "an empty pool says nothing")


func _test_conditions() -> void:
	StoryDirector.load_state({})
	_check(StoryDirector.matches({"x_min": 3}, {"x": 3}) and not StoryDirector.matches({"x_min": 4}, {"x": 3}), "_min bounds from below")
	_check(StoryDirector.matches({"x_max": 3}, {"x": 3}) and not StoryDirector.matches({"x_max": 2}, {"x": 3}), "_max bounds from above")
	_check(StoryDirector.matches({"kind": "clerk"}, {"kind": "clerk"}) and not StoryDirector.matches({"kind": "clerk"}, {"kind": "baker"}), "a string must match")
	_check(StoryDirector.matches({"race": ["elf", "human"]}, {"race": "human"}) and not StoryDirector.matches({"race": ["elf"]}, {"race": "human"}), "an Array condition means one of")
	_check(StoryDirector.matches({"stages": "doctrine"}, {"stages": ["method", "doctrine"]}) and not StoryDirector.matches({"stages": "apotheosis"}, {"stages": ["method"]}), "an Array fact must contain the condition")
	_check(StoryDirector.matches({"last_rite": true}, {"last_rite": true}) and not StoryDirector.matches({"last_rite": true}, {}), "a bool must match, absent reads false")
	_check(StoryDirector.matches({"last_boss": 0}, {"last_boss": 0}) and not StoryDirector.matches({"last_boss": 0}, {"last_boss": -1}), "a number must match exactly")
	_check(not StoryDirector.matches({"flag": "area:1"}, {}) and StoryDirector.matches({"not_flag": "area:1"}, {}), "flags read the profile")
	StoryDirector.add_flag("area:1")
	_check(StoryDirector.matches({"flag": "area:1"}, {}) and not StoryDirector.matches({"not_flag": "area:1"}, {}), "a set flag satisfies flag and fails not_flag")


# ---------------------------------------------------------------- accounts

func _test_account() -> void:
	StoryDirector.load_state({"accounts": 2, "best": 6, "flags": ["seen:chr_first"]})
	_fresh(4, 424242)
	_check(int(StoryDirector.attempt()["best_at_start"]) == 6, "an attempt remembers the profile's best at its start")
	Global.transaction_followers(250, &"combat_influence", {}, false, false)
	var pending := StoryDirector.take_pending()
	_check(pending.size() == 1 and String(pending[0]["text"]).ends_with(String(StoryLines.MILESTONES[1][1])), "a gain across 10 and 100 says only the higher milestone (%s)" % str(pending))
	Global.transaction_followers(-150, &"trade", {}, false, false)
	var runner := FakeEnemy.new()
	runner.spec = RUNNER_SPEC
	add_child(runner)
	var bolt := FakeProjectile.new()
	bolt.shooter = runner
	add_child(bolt)
	_check(StoryDirector.cause_id(bolt, &"unknown") == "enemy_runner", "a projectile's damage is put down to its shooter")
	_check(StoryDirector.cause_id(null, &"self_damage") == "self", "health spent on purpose is the player's own work")
	RunEvents.player_damage_resolved.emit(self, 12.0, 12.0, 0.0, runner, &"unknown", &"absorbed")
	RunEvents.player_damage_resolved.emit(self, 12.0, 12.0, 12.0, runner, &"unknown", &"hit")
	RunEvents.player_life_event.emit(self, &"death")
	var death: Dictionary = StoryDirector.attempt()["death"]
	_check(String(death["cause"]) == "enemy_runner" and not bool(death["rite"]) and int(death["boss"]) == -1, "the death is put down to the last hit (%s)" % str(death))
	Global.transaction_followers(-60, &"reconstruction", {}, false, false)
	_check(int(StoryDirector.attempt()["recon"]) == 1 and Global.grimoire_has("record:reconstruction"), "a reconstruction is counted and its record noted")
	runner.queue_free()
	bolt.queue_free()
	# The run ends the way player.die() ends it: a trade leaves 10 Followers,
	# the death charges its cost (16 at Segment 4) and nothing is left.
	Global.transaction_followers(-30, &"trade", {}, false, false)
	Global.consume_respawn_cost()
	_check(Global.followers == 0 and int(StoryDirector.attempt()["recon"]) == 1, "the charge that ends the run is no reconstruction (%d)" % int(StoryDirector.attempt()["recon"]))
	Global.on_attempt_failed_die_die()
	var last := StoryDirector.last_account()
	var theme := SegmentThemePicker.get_theme(4, 424242)
	_check(Global.attempt_segment == 1 and not Global.attempt_active, "Global wiped the attempt afterwards")
	_check(int(last.get("segment", 0)) == 4, "the account kept the segment from before the wipe (%d)" % int(last.get("segment", 0)))
	_check(String(last.get("district", "")) == String(theme.id), "its district is the segment's theme (%s)" % String(last.get("district", "")))
	_check(String(last.get("cause", "")) == "enemy_runner" and int(last.get("peak", 0)) == 250 and int(last.get("recon", 0)) == 1, "cause, peak and reconstructions are kept (%s)" % str(last))
	_check(int(last.get("n", 0)) == 3 and int(StoryDirector.state["accounts"]) == 3, "it is the third account")
	_check(String(last.get("epitaph", "")) == "‘You cannot outrun containment.’ This time, it was true.", "its epitaph was written before the wipe, from the facts (%s)" % String(last.get("epitaph", "")))
	_check(Global.grimoire_has("record:accounts"), "the ACCOUNTS record is noted")
	var closing := StoryDirector.closing_epitaph()
	_check(String(closing["text"]) == String(last["epitaph"]), "the Game Over reads the closed account's epitaph")
	_check(String(closing["caption"]) == "ACCOUNT III · %s · 250 WITNESSES" % StoryDirector.district_name(String(theme.id)).to_upper(), "and a caption: which account, where, how many (%s)" % String(closing["caption"]))
	# The next attempt's Chronicler relays it, once, then moves on.
	_fresh(2, 99)
	_check(String(StoryDirector.closing_epitaph()["text"]) == "", "a new attempt retires the epitaph")
	var rng := _rng(3)
	var relay := StoryDirector.staff_line("chronicler", rng)
	_check(relay == "The last account ends where a runner cut you off. The witnesses agree on that much.", "the Chronicler relays how the last account ended (%s)" % relay)
	var next := StoryDirector.staff_line("chronicler", rng)
	_check(next == "Three accounts of the same night. They agree on the synthesis. Little else.", "then the count of accounts (%s)" % next)
	var third := StoryDirector.staff_line("chronicler", rng)
	_check(third == "No lineage, no patron, no pact. The Registry never had a box for you.", "then the race line, once (%s)" % third)
	var flavour := StoryDirector.staff_line("chronicler", rng)
	var plain := false
	for line in StoryLines.CHRONICLER:
		if String(line["text"]) == flavour and StoryDirector.priority(line) < StoryLines.BEAT:
			plain = true
	_check(plain, "and everyday talk after that (%s)" % flavour)
	var aside_seen := false
	for i in range(30):
		if StoryDirector.staff_line("chronicler", rng, "ASIDE") == "ASIDE":
			aside_seen = true
	_check(aside_seen, "the square's own aside keeps its share of the everyday talk")


## A profile's first death, fatal: player.die() charges the cost before it
## decides, so a balance below the cost pays a reconstruction that never
## happens. The account must not count it, nor the Grimoire note it.
func _test_fatal_death() -> void:
	StoryDirector.load_state({})
	Global.grimoire_entries.erase("record:reconstruction")
	_fresh(2, 31)
	Global.transaction_followers(8, &"combat_influence", {}, false, false)
	var cost := Global.compute_respawn_cost()
	Global.consume_respawn_cost()
	_check(cost > 8 and Global.followers == 0, "8 Followers cannot pay a Segment 2 reconstruction (%d)" % cost)
	_check(int(StoryDirector.attempt()["recon"]) == 0 and not Global.grimoire_has("record:reconstruction"), "a death that rebuilds no one is no reconstruction, and RECONSTRUCTION stays unknown")
	Global.on_attempt_failed_die_die()
	var last := StoryDirector.last_account()
	_check(int(last.get("n", 0)) == 1 and int(last.get("recon", -1)) == 0, "the account closes with no reconstruction (%s)" % str(last.get("recon", -1)))


func _test_save_round_trip() -> void:
	StoryDirector.load_state({"accounts": 5, "best": 9, "flags": ["seen:chr_first", "area:1"],
		"last": {"n": 5, "segment": 7, "district": "canal_services", "peak": 1200}})
	var save := SaveData.new()
	Global.write_save(save)
	_check(int(save.meta_story.get("accounts", 0)) == 5 and String((save.meta_story.get("last", {}) as Dictionary).get("district", "")) == "canal_services", "write_save stores the story in meta_story")
	_check((save.meta_story.get("flags", []) as Array).has("area:1"), "with its profile flags")
	StoryDirector.load_state({})
	_check(int(StoryDirector.state["accounts"]) == 0, "(memory cleared)")
	Global.apply_save(save)
	_check(int(StoryDirector.state["accounts"]) == 5 and StoryDirector.has_flag("area:1") and int(StoryDirector.state["best"]) == 9, "apply_save brings it back")
	_check(StoryDirector.save_card_status(save.meta_story) == "Last account ended on the Canal Service Routes", "the Archives card reads the last account (%s)" % StoryDirector.save_card_status(save.meta_story))
	var old := SaveData.new()
	_check(old.meta_story.is_empty() and StoryDirector.save_card_status(old.meta_story) == "", "an older save has no story and the card keeps its own line")
	Global.apply_save(old)
	_check(int(StoryDirector.state["accounts"]) == 0 and (StoryDirector.state["flags"] as Array).is_empty() and StoryDirector.state.has("attempt"), "an empty story loads as a fresh one")
	_check(StoryDirector.route_label(4) == "Area 1 · Segment 4" and StoryDirector.route_label(12) == "Beyond the Wall · Segment 12", "the route label leaves Area 1 past the last gate")


# ---------------------------------------------------------------- places

func _test_completed_segment_keys() -> void:
	StoryDirector.load_state({})
	_fresh(4, 1234)
	# In the square the counter has already moved on: segment 3 is done.
	_check(StoryDirector.completed_segment() == 3, "in the square the completed segment is attempt_segment - 1")
	var f := StoryDirector.facts()
	_check(int(f["done"]) == 3 and String(f["district_done"]) == "checkpoint_lanes", "facts key the square on the completed segment (%s)" % String(f["district_done"]))
	var departures: Array = StoryLines.DISTRICTS["checkpoint_lanes"]["departure"]
	_check(departures.has(StoryDirector.departure_line()), "the arrival notice is the Checkpoint Lanes' departure")
	_fresh(2, 1234)
	var first := StoryDirector.departure_line()
	_check(first == "They cleared a square for you. Nobody asked them to.", "the first square ever says so once (%s)" % first)
	_check(StoryDirector.departure_line() == "The movement holds this square tonight.", "and after that it holds the square")
	_fresh(1, 1234)
	_check(StoryDirector.departure_line() == "", "nothing was left behind before Segment 1 is done")
	_check(StoryDirector.district_id(1, 5) == "institution" and StoryDirector.district_id(11, 5) == "beyond" and StoryDirector.district_id(10, 5) == "gate_district", "Segment 1 is the institution, 10 the Gate District, past it beyond the wall")
	for seg in range(2, 11):
		for world_seed in [1, 2, 3, 99, 4242]:
			var id := StoryDirector.district_id(seg, world_seed)
			if not StoryLines.DISTRICTS.has(id):
				_check(false, "every district has lines (%s at segment %d)" % [id, seg])
				return
	_check(true, "every district a segment can roll has lines")


func _test_arrivals() -> void:
	StoryDirector.load_state({})
	Global.mortal_name = "Vey"
	_fresh(3, 99)
	var a := StoryDirector.arrival(3)
	_check(String(a["tip"]) == String(StoryLines.DISTRICTS["checkpoint_lanes"]["first"]), "the first arrival in a district reads its first line")
	var card: Dictionary = a["bulletin"]
	_check(String(card.get("title", "")) == "CHECKPOINT ORDER 12" and String(card.get("body", "")).begins_with("Subject: Researcher Vey, unregistered."), "the first bulletin is a card with the name ladder (%s)" % String(card.get("body", "")).get_slice("\n", 0))
	_check(StoryDirector.arrival(3).is_empty(), "an attempt arrives in a segment once (Continue does not replay it)")
	_check(StoryDirector.arrival(1).is_empty(), "Segment 1's arrival is the opening")
	_fresh(3, 99)
	var again := StoryDirector.arrival(3)
	_check((StoryLines.DISTRICTS["checkpoint_lanes"]["repeat"] as Array).has(String(again["tip"])), "a later account reads a repeat line")
	_check((again["bulletin"] as Dictionary).is_empty() and String(again["bulletin_tip"]) == "REGISTRY BULLETIN • All lanes are closed to unregistered practice.", "and the bulletin as a tip (%s)" % String(again["bulletin_tip"]))
	_fresh(4, 99)
	var four := StoryDirector.arrival(4)
	_check(String((four["bulletin"] as Dictionary).get("title", "")) == "PUBLIC NOTICE" and String((four["bulletin"] as Dictionary).get("body", "")).begins_with("Subject: the unregistered practitioner."), "Segment 4's notice follows its district, and the name is gone")
	_fresh(11, 99)
	var beyond := StoryDirector.arrival(11)
	_check(String(beyond["tip"]) == String(StoryLines.DISTRICTS["beyond"]["first"]) and String(beyond["bulletin_tip"]).ends_with(StoryLines.BULLETIN_BEYOND), "past the wall: its own arrival, and no bulletin reaches it")
	_fresh(11, 99)
	_check(String(StoryDirector.arrival(11)["bulletin_tip"]) == "", "that is said once")
	_check(StoryDirector.registry_name(1, "Vey") == "Researcher Vey" and StoryDirector.registry_name(3, "Vey") == "Researcher Vey, unregistered", "the Registry names the researcher, then marks them unregistered")
	_check(StoryDirector.registry_name(5, "Vey") == "the unregistered practitioner" and StoryDirector.registry_name(7, "Vey") == "the synthetic event" and StoryDirector.registry_name(9, "Vey") == "the event" and StoryDirector.registry_name(10, "Vey") == "[NAME WITHHELD]", "then stops printing the name")
	Global.attempt_segment = 3
	var subtitle := StoryDirector.loading_subtitle(Global._scene_title(Global.PATH_GAME))
	_check(subtitle == "Checkpoint Lanes" and StoryDirector.loading_subtitle("THE HUB") == "", "the loading card names a segment's district only (%s)" % subtitle)


func _test_bren() -> void:
	StoryDirector.load_state({})
	_fresh(2)
	Global.opening_response_id = &"protective"
	var d := StoryDirector.bren_dispatch(1)
	var entry: Dictionary = StoryLines.BREN_DISPATCHES[1]
	_check(String(d.get("speaker", "")) == "BREN" and String(d.get("role", "")) == StoryLines.BREN_ROLE, "Bren writes by courier")
	_check(String(d.get("text", "")) == "%s\n\n%s" % [entry["base"], entry["protective"]], "the first letter answers the opening's response (%s)" % String(d.get("text", "")))
	_check(StoryDirector.bren_dispatch(1).is_empty() and StoryDirector.bren_dispatch(2).is_empty(), "once per attempt, and only after 1, 3, 5, 9 and 10")
	_fresh(2)
	_check(String(StoryDirector.bren_dispatch(1).get("text", "")) == String(entry["repeat"]), "later accounts read the short letter")
	var three := StoryDirector.bren_dispatch(3)
	_check(String(three.get("text", "")).ends_with(String(StoryLines.BREN_DISPATCHES[3]["all"])), "the third answers every response alike")
	Global.opening_response_id = &""
	var five := String(StoryDirector.bren_dispatch(5).get("text", ""))
	_check(five == String(StoryLines.BREN_DISPATCHES[5]["base"]), "an opening skipped leaves no answer to quote (%s)" % five)


func _test_reconstruction() -> void:
	StoryDirector.load_state({})
	_fresh(2)
	var first := StoryDirector.reconstruction_body(12, 300)
	_check(first.begins_with("Your followers preserve the sequence.") and first.contains("at the last Wardstone that recognised you, or where the district began"), "the first reconstruction explains itself, and Wardstones that were attuned count (%s)" % first.get_slice("\n", 2))
	_check(not first.contains("rewritten") and first.ends_with("Followers lost: 12\nFollowers remaining: 300"), "with the numbers kept as they were")
	var second := StoryDirector.reconstruction_body(12, 300)
	_check(second != first and second.ends_with("Followers lost: 12\nFollowers remaining: 300"), "later ones vary (%s)" % second.get_slice("\n", 0))
	var unsafe := StoryDirector.reconstruction_body(12, 1)
	_check(unsafe.begins_with("This is the last reconstruction the movement can pay for."), "the last one the movement can afford says so")
	StoryDirector.note_death("", true, -1)
	_check(StoryDirector.reconstruction_body(10, 500).begins_with("The Rite keeps most of what you wrote into it."), "a death in the Rite is named")
	_fresh(1)
	StoryDirector.load_state({})
	_check(StoryDirector.reconstruction_body(5, 40).contains("or where the night began"), "Segment 1 begins with the night")


func _test_milestones() -> void:
	StoryDirector.load_state({})
	_fresh(3)
	Global.transaction_followers(15, &"combat_influence", {}, false, false)
	var lines := StoryDirector.take_pending()
	_check(lines.size() == 1 and String(lines[0]["text"]) == StoryLines.MILESTONE_PREFIX + String(StoryLines.MILESTONES[0][1]), "ten Followers is a witness line")
	Global.transaction_followers(-10, &"trade", {}, false, false)
	Global.transaction_followers(10, &"combat_influence", {}, false, false)
	_check(StoryDirector.take_pending().is_empty(), "crossing it again in the same attempt says nothing")
	Global.set_followers(5000)
	_check(StoryDirector.take_pending().is_empty(), "a load or reset is never a milestone")
	Global.transaction_followers(20000, &"trade", {}, false, false)
	lines = StoryDirector.take_pending()
	_check(lines.size() == 1 and String(lines[0]["text"]).ends_with(String(StoryLines.MILESTONES[3][1])), "ten thousand is the next (%s)" % str(lines))
	_check(int(StoryDirector.attempt()["peak"]) == 25000, "the peak follows the Followers")


func _test_chapter_card() -> void:
	StoryDirector.load_state({})
	_fresh(10)
	_check(StoryDirector.chapter_close_card(9).is_empty() and StoryDirector.chapter_close_card(5).is_empty() and StoryDirector.chapter_close_card(11).is_empty(), "only Segment 10 closes the chapter")
	Global.set_followers(4321)
	var card := StoryDirector.chapter_close_card(10, false)
	var body := String(card.get("body", ""))
	var lines := body.split("\n")
	_check(String(card.get("title", "")) == "UNCONTAINED" and String(card.get("button", "")) == "Beyond the wall" and String(card.get("eyebrow", "")) == "AREA I — THE CITY COMPLETE", "the card's shape: {eyebrow, title, body, button}")
	_check(lines[lines.size() - 1] == "Syn'Tek." and body.count("Syn'Tek") == 1, "its last line, and only it, names Syn'Tek")
	_check(body.contains("4,321 people carried the other account to the wall.") and body.contains(String(StoryLines.CHAPTER_FAMILY[""])), "witnesses and a family line (none taken)")
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_choir_of_recurrence"}
	_check(String(StoryDirector.chapter_close_card(10, false)["body"]).contains(String(StoryLines.CHAPTER_FAMILY["circuit"])), "the dominant Doctrine family picks the line")
	Global.attempt_doctrine_stage_ids = {}
	StoryDirector.chapter_close_card(10)
	var repeat := String(StoryDirector.chapter_close_card(10, false)["body"])
	_check(repeat.begins_with("The last gate is open again.") and repeat.ends_with("Syn'Tek."), "later closes are shorter and end on the name")


func _test_crowd_and_staff() -> void:
	StoryDirector.load_state({})
	_fresh(3)
	var clerk := StoryDirector.crowd_pool("clerk", 500)
	_check(clerk.has("I filed the report. I kept a copy.") and clerk.has("The square is filling.") and clerk.has("No patron answered. You did."), "a clerk in a square of hundreds: their own lines, the crowd's size, the common ones")
	_check(not clerk.has("Soldiers now. Not officers.") and clerk.has("Containment is still counting heads."), "early on, no soldiers yet")
	_check(not clerk.has("I bake the tree into the crust. They never check."), "nobody speaks another archetype's lines")
	_fresh(10)
	var late := StoryDirector.crowd_pool("", 50000)
	_check(late.has("Soldiers now. Not officers.") and late.has("One gate left.") and late.has("The Garrison counts differently.") and not late.has("Containment is still counting heads."), "after Segment 9 the square has heard of the Garrison and the last gate")
	Global.set_followers(5000)
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit"}
	_check(StoryDirector.staff_line("acolyte", _rng(2)) == "You chose the instrument. They are already polishing it.", "the Acolyte answers the Method plate's family")
	Global.attempt_doctrine_stage_ids = {}
	_check(StoryDirector.crowd_tier(5) == "few" and StoryDirector.crowd_tier(50) == "dozens" and StoryDirector.crowd_tier(5000) == "thousands" and StoryDirector.crowd_tier(20000) == "quarter", "crowd tiers")


# ---------------------------------------------------------------- copy

func _strings_of(value: Variant, out: Array) -> void:
	if value is String or value is StringName:
		out.append(String(value))
	elif value is Array:
		for item in value:
			_strings_of(item, out)
	elif value is Dictionary:
		for key in value.keys():
			_strings_of(value[key], out)


func _test_copy_rules() -> void:
	var constants: Dictionary = (load("res://data/narrative/StoryLines.gd") as Script).get_script_constant_map()
	var named: Array = []
	var bad_beka: Array = []
	var bad_bang: Array = []
	var bad_he: Array = []
	var he := RegEx.new()
	he.compile("(?i)\\b(he|him|his)\\b")
	for name in constants.keys():
		var texts: Array = []
		_strings_of(constants[name], texts)
		for text in texts:
			if String(text).contains("Syn'Tek") and not named.has(String(name)):
				named.append(String(name))
			if String(text).contains("Beka"):
				bad_beka.append(text)
			if String(text).contains("!"):
				bad_bang.append(text)
			if he.search(String(text)) != null:
				bad_he.append(text)
	named.sort()
	_check(named == ["CHAPTER_FIRST", "CHAPTER_REPEAT"], "Syn'Tek is said only by the Area I card (%s)" % str(named))
	for key in ["CHAPTER_FIRST", "CHAPTER_REPEAT"]:
		var parts := String(constants[key]).split("\n")
		_check(parts[parts.size() - 1] == "Syn'Tek.", "%s ends on the name" % key)
	_check(bad_beka.is_empty(), "Beka is in no story pool (%s)" % str(bad_beka))
	_check(bad_bang.is_empty(), "no exclamation marks (%s)" % str(bad_bang))
	_check(bad_he.is_empty(), "nobody calls the protagonist he or him (%s)" % str(bad_he))
	var ids := {}
	var dupes: Array = []
	for pool_name in ["CHRONICLER", "ACOLYTE", "EXCHANGER", "QUARTERMASTER", "SMITH", "CROWD", "EPITAPHS", "RECONSTRUCTION"]:
		for line in constants[pool_name]:
			var id := String(line["id"])
			if ids.has(id):
				dupes.append(id)
			ids[id] = true
	_check(dupes.is_empty(), "line ids are unique across pools (%s)" % str(dupes))


func _test_copy_fit() -> void:
	StoryDirector.load_state({"accounts": 12, "last": {"n": 12, "segment": 9, "district": "siege_services", "peak": 1234567, "recon": 14, "cause": "enemy_herald"}})
	_fresh(9)
	var words := StoryDirector.tokens(StoryDirector.facts())
	var too_wide: Array = []
	for pool_name in ["CHRONICLER", "ACOLYTE", "EXCHANGER", "QUARTERMASTER", "SMITH", "CROWD"]:
		for line in (load("res://data/narrative/StoryLines.gd") as Script).get_script_constant_map()[pool_name]:
			var text := StoryDirector.format(String(line["text"]), words)
			var layout := HubText.bubble_layout(text, "The Quartermaster")
			var rows: PackedStringArray = layout["lines"]
			for row in rows:
				if HubText.text_width(HubText.italic(), row, HubText.SPEECH_SIZE) > HubText.SPEECH_WRAP + 30.0:
					too_wide.append(text)
					break
	_check(too_wide.is_empty(), "every square line fits two bubble lines (%s)" % str(too_wide))
	var long_notices: Array = []
	for id in StoryLines.DISTRICTS.keys():
		var district: Dictionary = StoryLines.DISTRICTS[id]
		var notices: Array = (district["departure"] as Array).duplicate()
		if String(district.get("departure_first", "")) != "":
			notices.append(district["departure_first"])
		for text in notices:
			if HubText.text_width(HubText.italic(), String(text), HubText.NOTICE_SIZE) > 760.0:
				long_notices.append(text)
	_check(long_notices.is_empty(), "every arrival notice fits one line over the square (%s)" % str(long_notices))


# ---------------------------------------------------------------- surfaces

func _test_surfaces() -> void:
	# Game Over: the closed account's epitaph and caption.
	StoryDirector.load_state({})
	_fresh(5, 7)
	Global.set_followers(0)
	Global.on_attempt_failed_die_die()
	var screen := GAME_OVER.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var hint := screen.get_node("CenterContainer/Panel/Margin/VBox/Hint") as Label
	var account := screen.get_node_or_null("CenterContainer/Panel/Margin/VBox/Account") as Label
	_check(hint.text == String(StoryDirector.last_account()["epitaph"]) and hint.text != "", "the Game Over hint is the epitaph (%s)" % hint.text)
	_check(account != null and account.text.begins_with("ACCOUNT I · INNER DISTRICT GATE"), "with the account's caption under it (%s)" % (account.text if account != null else "missing"))
	_check(hint.text == "The first account ends. What you bound to the Pattern remains.", "the profile's first account is called the first")
	screen.queue_free()
	_fresh(2, 7)
	var plain := GAME_OVER.instantiate()
	add_child(plain)
	await get_tree().process_frame
	var plain_hint := plain.get_node("CenterContainer/Panel/Margin/VBox/Hint") as Label
	_check(plain_hint.text == "What you bound to the Pattern remains." and plain.get_node_or_null("CenterContainer/Panel/Margin/VBox/Account") == null, "with no account just closed the screen reads as before")
	plain.queue_free()
	# The loading card's district line.
	Global.attempt_segment = 3
	var scrim := Global.loading_scrim()
	scrim.show_for(Global._scene_title(Global.PATH_GAME), get_tree().current_scene)
	_check(scrim._subtitle.visible and scrim._subtitle.text == "Checkpoint Lanes", "the loading card names the district (%s)" % scrim._subtitle.text)
	scrim.show_for("THE HUB", get_tree().current_scene)
	_check(not scrim._subtitle.visible, "and nothing under the hub")
	scrim.visible = false
	scrim.set_process(false)


func _test_square() -> void:
	# Headless runs (every suite and benchmark that boots a real scene) never
	# get a blocking story card; the bulletin falls back to its tip.
	_check(not StoryDirector.cards_allowed(), "no story card may block a headless run")
	StoryDirector.load_state({})
	_fresh(3, 99)
	var quiet := StoryDirector.arrival(3, StoryDirector.cards_allowed())
	_check((quiet["bulletin"] as Dictionary).is_empty() and String(quiet["bulletin_tip"]).begins_with(StoryLines.BULLETIN_TIP_PREFIX), "headless, the first bulletin is a tip")
	_check(not StoryDirector.has_flag("bulletin:seg3"), "and the card is kept for a real session")
	StoryDirector.cards_override = 1
	# A new attempt's first square after an account closed in Segment 1.
	StoryDirector.load_state({"accounts": 1, "flags": ["seen:chr_first"],
		"last": {"n": 1, "segment": 1, "district": "institution", "peak": 3, "cause": "", "boss": -1}})
	_fresh(2, 55)
	Global.opening_response_id = &"analytical"
	Global.followers = 4000
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 5
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var crowd: Node = hub.crowd
	var kinds_ok: bool = not crowd.believers.is_empty()
	var painted := []
	for key in crowd.CROWD_ART:
		painted.append(String(key).trim_prefix("hub_crowd_"))
	for b in crowd.believers:
		var kind := String(b.get("kind", "?"))
		if kind != "" and not painted.has(kind):
			kinds_ok = false
	_check(kinds_ok, "every believer carries the archetype of the sheet they wear")
	var chronicler: Dictionary = {}
	for s in crowd.service:
		if s["key"] == "chronicler":
			chronicler = s
	var relay: String = crowd._service_line(chronicler)
	_check(relay == "The last account never left the institution. I kept it anyway.", "the Chronicler relays the last account in the first square (%s)" % relay)
	var presenter := hub.get_node_or_null("StoryPresenter")
	_check(presenter != null, "the square has its story presenter")
	_check(int(StoryDirector.attempt()["first_hub"]) == 1, "the first square of the attempt is noted")
	presenter.call("_process", 0.7)
	var notice_texts: Array = []
	for entry in hub._notice.notices:
		notice_texts.append(String(entry["text"]))
	_check(notice_texts.has("They cleared a square for you. Nobody asked them to."), "the arrival notice is the first square's line (%s)" % str(notice_texts))
	presenter.call("_process", 2.0)
	await get_tree().process_frame
	var card: OpeningPresentation = null
	for child in hub.get_children():
		if child is OpeningPresentation:
			card = child
	_check(card != null and get_tree().paused, "Bren's dispatch opens as a card over a paused square")
	if card != null:
		_check(card._title.text == "BREN" and card._body.text.ends_with(String(StoryLines.BREN_DISPATCHES[1]["analytical"])), "it is Bren's first letter, answering the opening (%s)" % card._body.text.get_slice("\n", 0))
		card.advance()
		card.advance()
		await get_tree().process_frame
		await get_tree().process_frame
	_check(not get_tree().paused and hub._interact_enabled, "dismissed, the square runs again with its stations")
	hub.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	StoryDirector.cards_override = -1
