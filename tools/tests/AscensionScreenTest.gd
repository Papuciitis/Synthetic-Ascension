extends Node

# The radial map places every V4 node: Core anchors around the centre with
# Ascendant in the middle, locals on their discipline's wedge at their ring,
# mutations orbiting their Active, Fusions on the border between the two
# territories they join, nothing overlapping its ring neighbours. The screen
# instantiates, reflects ownership, buys through the ledger with the run's
# Followers, offers a Core choice for a Gate, and closes.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionScreenTest.tscn

const SCREEN = preload("res://ui/screens/AscensionScreen.tscn")

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
	var db := AscensionTreeDB.shared()
	var layout := AscensionTreeLayout.new()
	layout.compute(db)
	_check(layout.positions.size() == db.nodes.size(), "every node has a position (%d of %d)" % [layout.positions.size(), db.nodes.size()])
	_check(layout.position_of("ASC") == Vector2.ZERO, "Ascendant sits in the middle")
	_check(is_equal_approx(layout.position_of("core.melee").length(), AscensionTreeLayout.CORE_ANCHOR_RADIUS) and layout.position_of("core.melee").y < 0.0, "the Melee anchor sits above the centre")
	_check(is_equal_approx(layout.position_of("EX01").length(), AscensionTreeLayout.RING_RADIUS[1]), "Finish sits on ring 1")
	_check(layout.position_of("EX01").y < 0.0 and layout.position_of("BR01").x > 0.0 and layout.position_of("DT01").x < 0.0, "locals sit in their Core's territory")
	var q := layout.position_of("EXQ")
	var mutation := layout.position_of("EXQ1")
	_check(mutation.length() > q.length() and mutation.distance_to(q) < 220.0, "a mutation orbits just outside its Active (%.0f px)" % mutation.distance_to(q))
	var kill_feed := layout.position_of("MR2")
	_check(kill_feed.length() > AscensionTreeLayout.RING_RADIUS[4] and kill_feed.length() < AscensionTreeLayout.RING_RADIUS[5] and absf(rad_to_deg(kill_feed.angle()) - (-30.0)) < 30.0, "Kill Feed sits on the Melee-Ranged border beyond ring 4 (%.0f deg)" % rad_to_deg(kill_feed.angle()))
	var death_debt := layout.position_of("MM2")
	_check(absf(fmod(rad_to_deg(death_debt.angle()) + 360.0, 360.0) - 210.0) < 30.0, "Death Debt sits on the Melee-Magic border")
	var _placed := 0
	var overlaps := 0
	var ids := layout.positions.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a := String(ids[i])
			var b := String(ids[j])
			if db.kind(a) == "core" or db.kind(b) == "core":
				continue
			var gap := layout.position_of(a).distance_to(layout.position_of(b))
			if gap < (layout.radius_of(a) + layout.radius_of(b)) * 0.9:
				overlaps += 1
				print("OVERLAP ", a, " ", b, " gap=", gap, " at ", layout.position_of(a), " / ", layout.position_of(b))
		_placed += 1
	_check(overlaps == 0, "no two nodes overlap (%d overlaps)" % overlaps)
	_check(layout.hit(layout.position_of("EXQ") + Vector2(3, 0)) == "EXQ", "hit testing finds the node under a point")

	# --- the screen on a live ledger
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var ledger := Global.ascension_ledger()
	var was_followers: int = Global.followers
	Global.transaction_followers(5000 - Global.followers, &"dev_grant", {}, false, false)
	var screen := SCREEN.instantiate() as AscensionScreen
	add_child(screen)
	screen.open(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(screen.view != null and screen.view.state_of("EX01") == "buyable" and screen.view.state_of("EX10") == "locked", "the view marks the free starter buyable and a far node locked")
	var verdict := Global.ascension_buy("EX01")
	_check(bool(verdict["ok"]) and ledger.owns("EX01"), "buying through Global records the starter for free")
	screen._refresh_all()
	_check(screen.view.state_of("EX01") == "owned" and screen.view.state_of("EX03") == "buyable", "the view follows ownership: Spillover opens beside Finish")
	verdict = Global.ascension_buy("EX03")
	_check(bool(verdict["ok"]) and Global.followers == 4600, "Spillover costs 400 from the run's Followers (%d)" % Global.followers)
	for id in ["EX02", "EX04", "EXQ"]:
		Global.ascension_buy(id)
	screen._show("G1")
	await get_tree().process_frame
	_check(screen._gate_row.get_child_count() == 2, "a Gate offers the two unopened Cores (%d)" % screen._gate_row.get_child_count())
	# A Gate double-click carries the same Core choice into the confirmation.
	screen._on_activated("G1")
	_check(screen._pending_purchase == "G1" and screen._confirm_core.visible and screen._confirm_core.item_count == 2, "a Gate confirmation offers the unopened Cores (%d)" % screen._confirm_core.item_count)
	screen._pending_purchase = ""
	screen._show("EXQ")
	var labels := PackedStringArray()
	for child in screen._buttons.get_children():
		labels.append(String(child.text))
	var has_refund := false
	for label in labels:
		if label.begins_with("Refund"):
			has_refund = true
	_check(labels.has("Unequip") and not has_refund, "mid-run, an owned, equipped Q offers Unequip and no Refund (%s)" % str(labels))
	Global.ascension_refund_context_hub = true
	screen._show("EXQ")
	has_refund = false
	for child in screen._buttons.get_children():
		if String(child.text).begins_with("Refund"):
			has_refund = true
	Global.ascension_refund_context_hub = false
	_check(has_refund, "from the Hub the same node offers a Refund button with its share")
	_check(Global.ascension_refund("EX02") == 0 and ledger.owns("EX02"), "the mid-run screen cannot refund (Hub only)")
	Global.ascension_refund_context_hub = true
	var expected_back := int(round(200.0 * AscensionLedger.refund_share(Global.attempt_segment)))
	var back: int = Global.ascension_refund("EX02")
	Global.ascension_refund_context_hub = false
	_check(back == expected_back and not ledger.owns("EX02") and Global.followers == 4600 - 200 - 400 - 800 + expected_back, "a Hub refund returns the segment's share of the price to the wallet (%d of 200)" % back)
	# --- Double-click purchase: name/rank/exact cost, and eligibility
	# rechecked at the moment of confirmation (playtest review).
	screen._on_activated("EX05")
	_check(screen._pending_purchase == "EX05" if ledger.can_buy("EX05", Global.followers)["ok"] else screen._pending_purchase.is_empty(), "activation opens a confirmation only when the node is eligible")
	if not screen._pending_purchase.is_empty():
		_check(screen._confirm_text.text.contains("Exact cost"), "the confirmation names the exact cost")
		screen._confirm_pending_purchase()
		_check(ledger.owns("EX05"), "confirming buys through the ordinary transaction")
	# The recheck: the wallet drains while the dialog stands open.
	screen._on_activated("EX06")
	if not screen._pending_purchase.is_empty():
		var drained: int = Global.followers
		Global.transaction_followers(-drained, &"dev_drain", {}, false, false)
		screen._confirm_pending_purchase()
		_check(not ledger.owns("EX06"), "a stale confirmation cannot buy what the wallet no longer affords")
		_check(not screen._status.text.is_empty(), "the refusal names the ledger's reason")
		Global.transaction_followers(drained, &"dev_grant", {}, false, false)
	# --- Refunds ask first (review 2026-10-04): a right-click (or a short
	# right-drag pan released over a node) and the Refund button open one
	# confirmation naming the return and the forfeit; nothing leaves before.
	Global.ascension_refund_context_hub = true
	var target := "EX04"
	var share := AscensionLedger.refund_share(Global.attempt_segment)
	var quote: Dictionary = ledger.refund_quote(target, share)
	var wallet_before: int = Global.followers
	screen._on_clicked(target, MOUSE_BUTTON_RIGHT)
	_check(screen._pending_refund == target and screen._pending_purchase.is_empty() and ledger.owns(target) and Global.followers == wallet_before, "a right-click asks before refunding: nothing leaves yet")
	_check(screen._confirm.title == "Confirm refund" and screen._confirm_text.text.contains("Returns %d of the %d paid" % [int(quote["refund"]), int(quote["paid"])]) and screen._confirm_text.text.contains("%d is forfeited" % int(quote["forfeit"])), "the confirmation names the return and the forfeit (%s)" % screen._confirm_text.text.replace("\n", " | "))
	screen._confirm.hide()
	# A double-click afterwards asks about a purchase again, not the refund
	# (EX02 was refunded above and is buyable again).
	screen._on_activated("EX02")
	_check(screen._pending_refund.is_empty() and screen._pending_purchase == "EX02" and screen._confirm.title == "Confirm purchase", "a purchase question replaces a refund left standing")
	screen._confirm.hide()
	screen._pending_purchase = ""
	screen._show(target)
	var refund_button: Button = null
	for child in screen._buttons.get_children():
		if String(child.text).begins_with("Refund"):
			refund_button = child as Button
	_check(refund_button != null, "fixture: the Hub shows a Refund button for %s" % target)
	if refund_button != null:
		refund_button.emit_signal("pressed")
	_check(screen._pending_refund == target and ledger.owns(target), "the Refund button asks the same question")
	screen._on_confirm_accepted()
	_check(not ledger.owns(target) and Global.followers == wallet_before + int(quote["refund"]), "accepting refunds exactly the quoted share (%d of %d)" % [Global.followers - wallet_before, int(quote["refund"])])
	screen._confirm.hide()
	Global.ascension_refund_context_hub = false
	screen._on_clicked("EX03", MOUSE_BUTTON_RIGHT)
	_check(screen._pending_refund.is_empty() and ledger.owns("EX03"), "mid-run a right-click asks nothing and refunds nothing")
	Global.ascension_refund_context_hub = true
	var saved_rules: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	Global.set_doctrine_rule(&"ascension_refund_mul", 0.0)
	screen._on_clicked("EX03", MOUSE_BUTTON_RIGHT)
	_check(screen._pending_refund.is_empty() and ledger.owns("EX03") and screen._status.text.begins_with("Tithe Ledger"), "under the Tithe Ledger no confirmation opens: nothing refunds")
	Global.attempt_doctrine_rules = saved_rules
	Global.ascension_refund_context_hub = false
	# --- Overview declutter: at fit zoom only focus, cores, the equipped
	# loadout and what is buyable NOW carry labels; hover always reads.
	screen.view.zoom = 0.3
	screen.view.hovered = ""
	screen.view.selected = ""
	_check(screen.view._label_visible("core.melee", "core", "owned"), "cores stay named on the overview")
	_check(not screen.view._label_visible("EX10", "local", "locked"), "a locked far local is silent on the overview")
	_check(screen.view._label_visible("EX10", "local", "buyable"), "anything buyable NOW is named")
	# And the renderer draws what that rule promises: after a real draw at the
	# overview zoom the Cores and every buyable node own a placed name.
	# The opening unfurls in real time (~1.4 s); names are placed once it lands.
	for _w in range(40):
		if screen.view._intro_done:
			break
		await get_tree().create_timer(0.1).timeout
	screen.view._view_dirty = true
	screen.view._static_dirty = true
	for _f in range(4):
		await get_tree().process_frame
	var spots: Dictionary = screen.view._label_spots
	_check(spots.has(int(screen.view._index["core.melee"])), "the drawn overview names the Melee Core")
	var unnamed_buyable := 0
	for i in range(screen.view._ids.size()):
		var kind: String = screen.view._kinds[i]
		# Mutations orbit their Active and are read on hover only, by design.
		if kind == "mutation" or kind == "revelation_mutation":
			continue
		if screen.view._state.size() > i and screen.view._state[i] == screen.view.ST_BUYABLE and screen.view._alpha[i] > 0.05 and not spots.has(i):
			unnamed_buyable += 1
	_check(unnamed_buyable == 0, "the drawn overview names everything buyable now (%d unnamed)" % unnamed_buyable)
	screen.view.hovered = "EX10"
	_check(screen.view._label_visible("EX10", "local", "locked"), "hover always reads, whatever the state")
	screen.view.zoom = 1.0
	_check(screen.view._label_visible("EX09", "local", "locked"), "close zoom names everything again")

	var closed: Array[bool] = []
	screen.closed.connect(func() -> void: closed.append(true))
	screen.close()
	_check(closed.size() == 1, "closing emits closed")
	Global.transaction_followers(was_followers - Global.followers, &"dev_grant", {}, false, false)
	Global.attempt_ascension = {}
	_finish()


func _finish() -> void:
	print("AscensionScreenTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
