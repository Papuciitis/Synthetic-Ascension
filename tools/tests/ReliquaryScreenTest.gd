extends Node

# The Reliquary screen (docs/design/2026-10-03-duos-facets-and-the-reliquary.md
# §4), driven through its own buttons: the two-press Corruption, a
# Transfusion's choice and price, a Voucher bought and greyed, the
# Grimoire's count and its hidden entries, the panel holding its width, and
# the Hub's Reliquary button opening one screen at a time.
#
# Run: <godot> --headless --path . res://tools/tests/ReliquaryScreenTest.tscn

const RELIQUARY := preload("res://ui/screens/ReliquaryScreen.gd")
const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")
const TESLA := &"augment_tesla_aura"
const MISSILE := &"augment_magic_missile"
const LUCKY := &"augment_lucky_charm"
const SLASH := &"augment_spirit_slash"

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
	var saved_grimoire: Array[String] = Global.grimoire_entries.duplicate()
	var saved_autosave: bool = Global.debug_disable_autosave
	Global.debug_disable_autosave = true
	_fresh()
	var screen := RELIQUARY.new() as CanvasLayer
	add_child(screen)
	await _frames(2)
	await _test_corruption(screen)
	await _test_transfusion(screen)
	await _test_vouchers(screen)
	await _test_grimoire(screen)
	await _test_close(screen)
	await _test_hub_shop()
	Global.grimoire_entries = saved_grimoire
	Global.debug_disable_autosave = saved_autosave
	print("ReliquaryScreenTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	Global.start_new_attempt()
	Global.attempt_world_seed = 777
	var equipped: Array[StringName] = [TESLA, MISSILE, StringName()]
	Global.permanent_augment_ids = equipped
	Global.init_owned_augments()
	# A Lv.1 donor ahead of the Lv.5 one: the screen must pass over the one
	# with nothing to give.
	for id in [SLASH, LUCKY]:
		if not Global.owned_augment_ids.has(id):
			Global.owned_augment_ids.append(id)
	Global.augment_slot_locks = [false, false, false]
	Global.attempt_augment_levels = {String(TESLA): 4, String(MISSILE): 3, String(LUCKY): 5, String(SLASH): 1}
	Global.attempt_segment = 5
	Global.run_luck = 0.0
	Global.set_followers(1000)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _node(screen: Node, node_name: String) -> Node:
	return screen.find_child(node_name, true, false)


func _button(screen: Node, node_name: String) -> Button:
	return _node(screen, node_name) as Button


func _label_text(screen: Node, node_name: String) -> String:
	var label := _node(screen, node_name) as Label
	return label.text if label != null else ""


func _press(screen: Node, node_name: String) -> void:
	var button := _button(screen, node_name)
	if button == null:
		_check(false, "%s exists to press" % node_name)
		return
	button.pressed.emit()
	await _frames(1)


func _panel_width(screen: Node) -> float:
	var panel := _node(screen, "Panel") as Control
	return panel.size.x if panel != null else -1.0


func _test_corruption(screen: CanvasLayer) -> void:
	for tab in ["CORRUPTION", "TRANSFUSION", "VOUCHERS", "GRIMOIRE"]:
		_check(_button(screen, "Tab_%s" % tab) != null, "a %s tab" % tab)
	_check(screen.layer == 140, "the screen sits on layer 140 like the imprinter")
	var odds := _label_text(screen, "Odds")
	_check(odds.contains("EXALTED  45%") and odds.contains("SCARRED  35%") and odds.contains("SUNDERED  20%"), "the odds are shown once at the top (%s)" % odds.replace("\n", " | "))
	var corrupt := "CorruptButton_%s" % String(TESLA)
	_check(_button(screen, corrupt) != null and _button(screen, corrupt).text == "CORRUPT", "an uncorrupted augment offers CORRUPT")
	await _press(screen, corrupt)
	_check(Global.augment_corruption(TESLA) == StringName(), "one press does not corrupt")
	_check(_button(screen, corrupt) != null and _button(screen, corrupt).text == "CONFIRM · IRREVERSIBLE", "the first press arms CONFIRM · IRREVERSIBLE")
	var status := _node(screen, "Status") as Label
	_check(status.text.contains("press again"), "and the status asks for the second press")
	await _press(screen, corrupt)
	var outcome := Global.augment_corruption(TESLA)
	_check(AugmentRites.OUTCOMES.has(outcome), "the second press corrupts (%s)" % outcome)
	var after := AugmentRites.corrupted_level(outcome, 4)
	_check(Global.get_augment_level(TESLA) == after, "and moves the level by the outcome")
	_check(status.text.contains(String(AugmentRites.OUTCOME_NAMES.get(outcome, "?"))) and status.text.contains("Lv.4 → Lv.%d" % after) and status.text.contains(String(AugmentRites.OUTCOME_TEXT.get(outcome, "?"))), "the status names the outcome and the level change (%s)" % status.text)
	await _frames(1)
	_check(is_equal_approx(_panel_width(screen), 1100.0) and _unwrapped_long_labels(screen).is_empty(), "the long status and the odds wrap inside the panel (width %.0f; %s)" % [_panel_width(screen), ", ".join(_unwrapped_long_labels(screen))])
	_check(_button(screen, corrupt) == null and _label_text(screen, "Corruption_%s" % String(TESLA)) == String(AugmentRites.OUTCOME_NAMES.get(outcome, "?")), "a corrupted augment shows its Corruption, not the button")
	# An armed row is disarmed by leaving the tab: one stray press later must
	# not corrupt.
	var other := "CorruptButton_%s" % String(MISSILE)
	await _press(screen, other)
	await _press(screen, "Tab_VOUCHERS")
	await _press(screen, "Tab_CORRUPTION")
	_check(_button(screen, other) != null and _button(screen, other).text == "CORRUPT", "leaving the tab disarms the confirm")
	_check(not (screen.get("_status") as Label).text.contains("press again"), "and the line asking for the second press goes with it")
	await _press(screen, other)
	_check(Global.augment_corruption(MISSILE) == StringName(), "so the next press only arms again")


func _test_transfusion(screen: CanvasLayer) -> void:
	await _press(screen, "Tab_TRANSFUSION")
	var donor_lucky := "Donor_%s" % String(LUCKY)
	var donor_slash := "Donor_%s" % String(SLASH)
	_check(_button(screen, donor_slash) != null and _button(screen, donor_lucky) != null, "the unequipped owned augments are offered as donors")
	_check(_button(screen, "Donor_%s" % String(TESLA)) == null, "an equipped augment is no donor")
	_check(_button(screen, donor_lucky).text.contains("Lv.5"), "a donor shows its run level")
	_check(_button(screen, "TransfuseButton") != null and not _button(screen, "TransfuseButton").disabled, "the Lv.5 donor is chosen over the Lv.1 one, so TRANSFUSE is ready")
	await _press(screen, donor_slash)
	_check(_button(screen, "TransfuseButton").disabled, "a Lv.1 donor leaves TRANSFUSE disabled")
	_check(_label_text(screen, "TransfusionPreview").contains("Cannot transfuse") and _label_text(screen, "TransfusionPreview").contains("Lv.%d" % AugmentRites.TRANSFUSION_MIN_DONOR), "and the preview says why (%s)" % _label_text(screen, "TransfusionPreview"))
	await _press(screen, donor_lucky)
	await _press(screen, "Recipient_%s" % String(MISSILE))
	var preview := _label_text(screen, "TransfusionPreview")
	_check(preview.contains("Lv.3 → Lv.5") and preview.contains("80 Followers"), "the preview shows the gain and the cost (%s)" % preview)
	var tesla_level := Global.get_augment_level(TESLA)
	var before := int(Global.followers)
	await _press(screen, "TransfuseButton")
	_check(Global.get_augment_level(MISSILE) == 5 and Global.get_augment_level(LUCKY) == 1, "TRANSFUSE pours into the chosen recipient: Missile 3 -> 5, the donor back to Lv.1")
	_check(Global.get_augment_level(TESLA) == tesla_level, "the other augment is untouched")
	_check(int(Global.followers) == before - 80, "and it cost 80 Followers")
	_check(_label_text(screen, "Wallet") == "%d Followers" % int(Global.followers), "the wallet follows")


func _test_vouchers(screen: CanvasLayer) -> void:
	await _press(screen, "Tab_VOUCHERS")
	var offer := Global.voucher_offer()
	var price := Global.voucher_price()
	_check(offer.size() == 2, "two Vouchers are offered")
	var first := "VoucherBuy_%s" % String(offer[0])
	var second := "VoucherBuy_%s" % String(offer[1])
	_check(_button(screen, first) != null and not _button(screen, first).disabled and _button(screen, first).text.contains(str(price)), "BUY shows the price (%d)" % price)
	var row := _node(screen, "Voucher_%s" % String(offer[0]))
	var shows_words := false
	if row != null:
		for label in row.find_children("*", "Label", true, false):
			if (label as Label).text == Vouchers.text(StringName(offer[0])):
				shows_words = true
	_check(shows_words, "an offered Voucher shows what it does")
	var held := _node(screen, "HeldVouchers")
	_check(held != null and held.find_children("*", "Label", true, false).size() == 1 and (held.find_children("*", "Label", true, false)[0] as Label).text == "None yet.", "nothing is held before buying")
	var before := int(Global.followers)
	await _press(screen, first)
	_check(Global.has_voucher(StringName(offer[0])), "BUY buys the Voucher")
	_check(int(Global.followers) == before - price, "for its price (%d)" % price)
	_check(_button(screen, first) != null and _button(screen, first).disabled and _button(screen, first).text == "BOUGHT", "a bought Voucher's button disables")
	await _frames(1)
	var holder := get_viewport().gui_get_focus_owner()
	_check(holder != null and is_instance_valid(holder) and holder.is_inside_tree() and screen.is_ancestor_of(holder), "a pad or keyboard user keeps a focused control after buying")
	held = _node(screen, "HeldVouchers")
	var held_text := ""
	for label in held.find_children("*", "Label", true, false):
		held_text += (label as Label).text
	_check(held_text.contains(Vouchers.display_name(StringName(offer[0]))), "and it is listed as held this run")
	_check(_button(screen, second) != null and not _button(screen, second).disabled, "the other is still affordable")
	Global.set_followers(price - 1)
	await _press(screen, "Tab_VOUCHERS")
	_check(_button(screen, second) != null and _button(screen, second).disabled, "an unaffordable Voucher's button disables")
	_check(is_equal_approx(_panel_width(screen), 1100.0), "the Vouchers' text wraps inside the panel (width %.0f)" % _panel_width(screen))
	_check(_unwrapped_long_labels(screen).is_empty(), "every long Voucher line wraps (%s)" % ", ".join(_unwrapped_long_labels(screen)))
	Global.set_followers(1000)


func _test_grimoire(screen: CanvasLayer) -> void:
	var known: Array[String] = [Grimoire.transcend_key(TESLA), Grimoire.duo_key(AugmentDuos.LIGHTNING_RODS)]
	Global.grimoire_entries = known
	await _press(screen, "Tab_GRIMOIRE")
	await _frames(2)
	var total := Grimoire.catalogue(Global.augment_db).size()
	_check(_label_text(screen, "GrimoireCount") == "DISCOVERED 2 / %d" % total, "the Grimoire counts what is known (%s)" % _label_text(screen, "GrimoireCount"))
	for section in Grimoire.SECTIONS:
		_check(_node(screen, "Section_%s" % section) != null, "a %s heading" % section)
	var found := _node(screen, "Entry_%s" % Grimoire.duo_key(AugmentDuos.LIGHTNING_RODS).replace(":", "_")) as Control
	var hidden := _node(screen, "Entry_%s" % Grimoire.duo_key(AugmentDuos.PHANTOM_STEP).replace(":", "_")) as Control
	_check(found != null and _texts(found).contains(AugmentDuos.display_name(AugmentDuos.LIGHTNING_RODS)) and _texts(found).contains(AugmentDuos.rule(AugmentDuos.LIGHTNING_RODS)), "a discovered entry shows its name and rule")
	_check(hidden != null and not _texts(hidden).contains(AugmentDuos.display_name(AugmentDuos.PHANTOM_STEP)) and not _texts(hidden).contains(AugmentDuos.rule(AugmentDuos.PHANTOM_STEP)), "an undiscovered entry hides its name and rule")
	var hint := ""
	for entry in Grimoire.catalogue(Global.augment_db):
		if String(entry["key"]) == Grimoire.duo_key(AugmentDuos.PHANTOM_STEP):
			hint = String(entry["hint"])
	_check(hidden != null and _texts(hidden).contains("???") and hint != "" and _texts(hidden).contains(hint), "and shows ??? and its hint (%s)" % hint)
	_check(found != null and hidden != null and hidden.modulate.a < found.modulate.a, "an undiscovered entry is visibly dimmer")
	var scroll := _node(screen, "PageScroll") as ScrollContainer
	var page := scroll.get_child(scroll.get_child_count() - 1) as Control if scroll != null else null
	_check(scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and page != null and page.get_combined_minimum_size().y > scroll.size.y, "the Grimoire runs longer than the page and scrolls")
	_check(is_equal_approx(_panel_width(screen), 1100.0), "the Grimoire's rules wrap inside the panel (width %.0f)" % _panel_width(screen))
	_check(_unwrapped_long_labels(screen).is_empty(), "every long line wraps (%s)" % ", ".join(_unwrapped_long_labels(screen)))
	# A pad or keyboard user can page the Grimoire: it has nothing else to
	# focus, so the scroll takes focus and the pad moves it.
	var pad_scroll := _node(screen, "PageScroll") as ScrollContainer
	_check(pad_scroll != null and pad_scroll.follow_focus, "the page follows focus, so rows below the fold come into view")
	if pad_scroll != null:
		_check(pad_scroll.focus_mode == Control.FOCUS_ALL, "on the Grimoire the scroll itself can hold focus")
		pad_scroll.grab_focus()
		var down := InputEventAction.new()
		down.action = &"ui_down"
		down.pressed = true
		pad_scroll.gui_input.emit(down)
		await _frames(1)
		_check(pad_scroll.scroll_vertical > 0, "and a pad press pages down (%d px)" % pad_scroll.scroll_vertical)
		await _press(screen, "Tab_VOUCHERS")
		var vouchers_scroll := _node(screen, "PageScroll") as ScrollContainer
		_check(vouchers_scroll != null and vouchers_scroll.focus_mode == Control.FOCUS_NONE, "elsewhere focus walks the rows instead")


## Labels longer than a short heading that would widen the panel instead
## of wrapping: whether today's texts happen to fit is not the rule.
func _unwrapped_long_labels(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.length() > 48 and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			out.append(label.text.left(40))
	return out


func _texts(root: Node) -> String:
	var out := ""
	for label in root.find_children("*", "Label", true, false):
		out += (label as Label).text + "\n"
	return out


func _test_close(screen: CanvasLayer) -> void:
	var heard := [false]
	screen.connect(&"closed", func() -> void: heard[0] = true)
	await _press(screen, "Close")
	_check(bool(heard[0]), "Close emits closed")
	await _frames(1)
	_check(not is_instance_valid(screen), "and frees the screen")


func _test_hub_shop() -> void:
	_fresh()
	var shop := HUB_SHOP.instantiate() as Control
	add_child(shop)
	await _frames(3)
	var reliquary := shop.find_child("Reliquary", true, false) as Button
	var imprints := shop.find_child("Imprints", true, false) as Button
	_check(reliquary != null, "the Hub has a Reliquary button")
	if reliquary == null:
		shop.queue_free()
		return
	_check(imprints != null and reliquary.get_parent() == imprints.get_parent() and reliquary.get_index() == imprints.get_index() + 1, "beside Imprints")
	_check(reliquary.tooltip_text == "Corrupt, transfuse, buy Vouchers, read the Grimoire.", "with its tooltip")
	reliquary.pressed.emit()
	await _frames(1)
	var opened := _reliquaries(shop)
	_check(opened.size() == 1 and reliquary.disabled, "pressing it opens the Reliquary and disables the button")
	reliquary.pressed.emit()
	await _frames(1)
	_check(_reliquaries(shop).size() == 1, "once at a time")
	# A stand-in for a trade made before the visit. A visit that spends
	# nothing (reading the Grimoire, a Corruption) leaves the undo standing;
	# one that spends Followers (Transfusion, a Voucher) clears it, or the
	# undo would restore a wallet that no longer matches.
	shop.set(&"_undo_trade", {"followers": int(Global.followers)})
	if not opened.is_empty():
		opened[0].call(&"close")
		await _frames(1)
	_check(not reliquary.disabled and _reliquaries(shop).is_empty(), "closing it re-enables the button")
	_check(not (shop.get(&"_undo_trade") as Dictionary).is_empty(), "a visit that spent nothing keeps the last trade's undo")
	reliquary.pressed.emit()
	await _frames(1)
	opened = _reliquaries(shop)
	Global.set_followers(int(Global.followers) - 1)
	if not opened.is_empty():
		opened[0].call(&"close")
		await _frames(1)
	_check((shop.get(&"_undo_trade") as Dictionary).is_empty(), "a visit that spent Followers clears it")
	shop.queue_free()
	await _frames(1)


func _reliquaries(shop: Node) -> Array:
	var out: Array = []
	for child in shop.get_children():
		if child.get_script() == RELIQUARY and not child.is_queued_for_deletion():
			out.append(child)
	return out
