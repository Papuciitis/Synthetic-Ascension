extends Node

# The Binding's rule cards and the Reliquary's marks on the text surfaces
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §1-6): the DUO and
# FACET cards and their NEW marker, the Facet chooser, BURDEN, the Run
# Sheet's record and the augment tooltip. Drives the real AugmentSelect with
# a pending Binding in Global and reads its nodes, as a player would see them.
#
# Run: <godot> --headless --path . res://tools/tests/BindingRitesUiTest.tscn

const SELECT_SCENE := preload("res://ui/augments/AugmentSelect.tscn")
const CARD_SCENE := preload("res://ui/augments/AugmentCard.tscn")
const CARD_SCRIPT := preload("res://ui/augments/AugmentCard.gd")
const RUN_SHEET_SCENE := preload("res://ui/widgets/RunSheetHUD.tscn")
const TOOLTIP_SCENE := preload("res://ui/widgets/AugmentTooltip.tscn")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

const MISSILE := &"augment_magic_missile"
const TESLA := &"augment_tesla_aura"
const CHARM := &"augment_lucky_charm"
## The badge's room on the 250 px card face (ChoiceCopyFitTest).
const BADGE_ROOM := 222.0

var _passes := 0
var _failures := 0
var _saved_grimoire: Array[String] = []
var _saved_autosave := false


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
	# The Grimoire is profile-wide: never let this test write the profile.
	_saved_autosave = Global.debug_disable_autosave
	Global.debug_disable_autosave = true
	_saved_grimoire = Global.grimoire_entries.duplicate()
	await _test_rule_cards_and_facet_pick()
	await _test_duo_pick()
	await _test_preview_applies_directly()
	await _test_burden()
	await _test_intro_has_no_burden()
	await _test_new_marker()
	await _test_badges_fit()
	_test_run_sheet()
	_test_tooltip()
	await _test_chooser_hygiene()
	Global.grimoire_entries = _saved_grimoire
	Global.debug_disable_autosave = _saved_autosave
	print("BindingRitesUiTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- fixtures

func _duo_card() -> Dictionary:
	return {"kind": "duo", "id": String(AugmentDuos.LIGHTNING_RODS), "grade": -1}


func _facet_card() -> Dictionary:
	return {"kind": "facet", "id": String(MISSILE), "grade": -1}


## A Binding pending in segment 5 (it trades) with Magic Missile and Tesla
## Aura at Lv.3 and Lucky Charm at Lv.2, holding exactly `offer`.
func _pending_binding(offer: Array, segment: int = 5) -> void:
	Global.start_new_attempt()
	Global.attempt_world_seed = 515151
	Global.run_luck = 0.0
	Global.attempt_segment = segment
	Global.permanent_augment_ids = [MISSILE, TESLA, CHARM]
	Global.init_owned_augments()
	Global.augment_slot_locks = [false, false, false]
	Global.attempt_augment_levels = {String(MISSILE): 3, String(TESLA): 3, String(CHARM): 2}
	Global.set_followers(0)
	Global.grimoire_entries = []
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = offer.duplicate(true)


func _open_select() -> CanvasLayer:
	var select := SELECT_SCENE.instantiate() as CanvasLayer
	add_child(select)
	select.call("open_choose_3")
	await get_tree().process_frame
	return select


func _cards(select: CanvasLayer) -> Array[Node]:
	return select.get_node("Center/VBox/CardsPanel/CardsMargin/Cards").get_children()


func _card_of(select: CanvasLayer, kind: String, id: String = "") -> Node:
	for card in _cards(select):
		var entry: Dictionary = card.get("card_entry")
		if String(entry.get("kind", "")) == kind and (id == "" or String(entry.get("id", "")) == id):
			return card
	return null


func _badge(card: Node) -> String:
	return (card.get_node("FaceViewport/Face/Badge") as Label).text


func _face_name(card: Node) -> String:
	return (card.get_node("FaceViewport/Face/Name") as Label).text


func _desc(card: Node) -> String:
	return (card.get_node("FaceViewport/Face/Desc") as Label).text


func _button(select: CanvasLayer, button_name: String) -> Button:
	return select.get_node_or_null("Center/VBox/BindingFooter/%s" % button_name) as Button


func _facet_buttons(select: CanvasLayer) -> Array[Button]:
	var out: Array[Button] = []
	var chooser := select.get_node_or_null("Center/VBox/FacetChooser")
	if chooser == null:
		return out
	for row in chooser.get_children():
		for child in row.get_children():
			if child is Button and (child as Button).has_meta(&"facet_id"):
				out.append(child as Button)
	return out


func _facet_back(select: CanvasLayer) -> Button:
	var chooser := select.get_node_or_null("Center/VBox/FacetChooser")
	if chooser == null:
		return null
	for row in chooser.get_children():
		var back := row.get_node_or_null("Back") as Button
		if back != null:
			return back
	return null


# ---------------------------------------------------------------- the cards

func _test_rule_cards_and_facet_pick() -> void:
	_pending_binding([_duo_card(), _facet_card(), {"kind": "rank", "id": String(CHARM), "grade": 0}])
	var select := await _open_select()
	var chosen: Array = []
	select.connect(&"augment_chosen", func(a: AugmentData) -> void: chosen.append(a))
	_check(_cards(select).size() == 3, "a Duo, a Facet and a rank card are all dealt (%d)" % _cards(select).size())

	var duo := _card_of(select, "duo")
	_check(duo != null, "the DUO card is spawned although its id is no augment id")
	if duo != null:
		_check(_badge(duo) == "◆  DUO  ·  NEW  ◆", "the Duo badge, NEW for an empty Grimoire (%s)" % _badge(duo))
		_check(_face_name(duo) == "Lightning Rods", "the Duo card is named for the Duo (%s)" % _face_name(duo))
		_check(_desc(duo) == AugmentDuos.rule(AugmentDuos.LIGHTNING_RODS), "its blurb is the Duo's rule (%s)" % _desc(duo))
		_check((duo.get("data") as AugmentData).id == MISSILE, "it wears its first member's art")
		_check(duo.call("grade_colour") == OverlayKit.TEAL, "a Duo card is teal")
		var duo_text := str(select.call("_build_numbers_text", duo.get("data"), duo.get("card_entry")))
		_check(duo_text.contains("Magic Missile + Tesla Aura") and duo_text.contains(AugmentDuos.rule(AugmentDuos.LIGHTNING_RODS)), "the Duo hover names the pair and the rule (%s)" % duo_text)
		_check(not duo_text.contains("Stats at Lv."), "and no level-scaled numbers")

	var facet := _card_of(select, "facet")
	_check(facet != null, "the FACET card is spawned")
	if facet == null:
		select.queue_free()
		return
	_check(_badge(facet) == "◆  FACET  ·  NEW  ◆", "the Facet badge (%s)" % _badge(facet))
	_check(_face_name(facet) == "Magic Missile", "the Facet card is named for its augment")
	_check(_desc(facet).contains("Salvo or Lance"), "its blurb offers the two Facets (%s)" % _desc(facet))
	_check(facet.call("grade_colour") == CARD_SCRIPT.FACET_COLOUR, "a Facet card is quicksilver")
	for grade in range(AugmentScaling.GRADE_COUNT):
		_check(facet.call("grade_colour") != OverlayKit.rarity_colour(AugmentScaling.grade_rarity_index(grade)), "and never a grade's colour (grade %d)" % grade)
	var facet_text := str(select.call("_build_numbers_text", facet.get("data"), facet.get("card_entry")))
	_check(facet_text.contains("Salvo: " + AugmentFacets.rule(MISSILE, &"salvo")) and facet_text.contains("Lance: " + AugmentFacets.rule(MISSILE, &"lance")), "the Facet hover lists both Facets with their rules (%s)" % facet_text)
	var rank := _card_of(select, "rank")
	_check(rank != null and _badge(rank).contains("Lv.2 → 3"), "the rank card is unchanged (%s)" % (_badge(rank) if rank != null else "missing"))

	# Picking the FACET card asks which; BACK takes the question away.
	facet.emit_signal("pressed")
	await get_tree().process_frame
	var buttons := _facet_buttons(select)
	_check(buttons.size() == 2, "the chooser offers both Facets (%d)" % buttons.size())
	_check(Global.pending_augment_pick and Global.augment_facet(MISSILE) == StringName(), "and nothing is applied yet")
	if buttons.size() == 2:
		_check(buttons[0].text.begins_with("SALVO") and buttons[0].text.contains(AugmentFacets.rule(MISSILE, &"salvo")), "the first button is Salvo and its rule (%s)" % buttons[0].text)
		_check(buttons[1].text.begins_with("LANCE") and buttons[1].text.contains(AugmentFacets.rule(MISSILE, &"lance")), "the second is Lance (%s)" % buttons[1].text)
	var back := _facet_back(select)
	_check(back != null, "the chooser has a BACK")
	if back != null:
		back.emit_signal("pressed")
		await get_tree().process_frame
		_check(_facet_buttons(select).is_empty() and Global.pending_augment_pick, "BACK closes the chooser and the Binding waits")
		_check(not bool(facet.get("_picked")), "and the card lets go of its picked look")

	facet.emit_signal("pressed")
	await get_tree().process_frame
	buttons = _facet_buttons(select)
	if buttons.size() == 2:
		buttons[1].emit_signal("pressed")
		await get_tree().process_frame
	_check(Global.augment_facet(MISSILE) == &"lance", "choosing Lance gives Magic Missile the Lance Facet (%s)" % Global.augment_facet(MISSILE))
	_check(not Global.pending_augment_pick, "and closes the Binding")
	_check(not select.visible and chosen.size() == 1, "the screen closes and reports the pick (%d)" % chosen.size())
	_check(Global.get_augment_level(MISSILE) == 3, "a Facet adds no level")
	_check(Global.grimoire_has(Grimoire.facet_key(MISSILE, &"lance")), "the Grimoire records the Facet")
	select.queue_free()


func _test_duo_pick() -> void:
	_pending_binding([_duo_card(), {"kind": "rank", "id": String(CHARM), "grade": 0}, {"kind": "rank", "id": String(TESLA), "grade": 0}])
	var select := await _open_select()
	var duo := _card_of(select, "duo")
	if duo != null:
		duo.emit_signal("pressed")
		await get_tree().process_frame
	_check(Global.augment_duo_active(AugmentDuos.LIGHTNING_RODS), "picking the DUO card activates Lightning Rods")
	_check(not Global.pending_augment_pick and not select.visible, "and closes the Binding")
	_check(Global.get_augment_level(MISSILE) == 3 and Global.get_augment_level(TESLA) == 3, "a Duo adds no level to either member")
	select.queue_free()


## Opened with nothing pending (probes), a rule card still lands: the Facet
## and the Duo are recorded as the Binding would, a second Facet is refused.
func _test_preview_applies_directly() -> void:
	_pending_binding([])
	Global.pending_augment_pick = false
	var select := await _open_select()
	var missile := Global.augment_db[MISSILE] as AugmentData
	await select.call("_commit", missile, null, _facet_card(), -1, &"salvo")
	_check(Global.augment_facet(MISSILE) == &"salvo", "a preview Facet pick sets the Facet directly")
	await select.call("_commit", missile, null, _facet_card(), -1, &"lance")
	_check(Global.augment_facet(MISSILE) == &"salvo", "one Facet per augment per run, in the preview too")
	await select.call("_commit", missile, null, _duo_card(), -1)
	_check(Global.attempt_augment_duos.has(String(AugmentDuos.LIGHTNING_RODS)), "a preview Duo pick records the Duo")
	_check(Global.get_augment_level(MISSILE) == 3, "neither adds a level")
	select.queue_free()


# ---------------------------------------------------------------- Burden

func _test_burden() -> void:
	_pending_binding([_facet_card(), {"kind": "rank", "id": String(TESLA), "grade": 0}, {"kind": "rank", "id": String(CHARM), "grade": 3}])
	var threat_before := Global.attempt_doctrine_threat_debt
	var select := await _open_select()
	var burden := _button(select, "Burden")
	var abstain := _button(select, "Abstain")
	_check(burden != null and burden.visible and not burden.disabled, "BURDEN is offered on a trading Binding")
	if burden == null or abstain == null:
		select.queue_free()
		return
	_check(burden.text == "BURDEN  ·  RAISE EVERY GRADE", "it says what it does (%s)" % burden.text)

	abstain.emit_signal("pressed")
	burden.emit_signal("pressed")
	_check(burden.text == "CONFIRM  ·  A CURSE AND +20 THREAT", "the first press arms it and names the price (%s)" % burden.text)
	_check(abstain.text.begins_with("ABSTAIN"), "arming Burden disarms Abstain (%s)" % abstain.text)
	abstain.emit_signal("pressed")
	_check(burden.text.begins_with("BURDEN") and abstain.text.begins_with("CONFIRM"), "and arming Abstain disarms Burden")
	_check(not Global.attempt_binding_burdened and Global.pending_augment_pick, "arming alone binds nothing")

	burden.emit_signal("pressed")
	burden.emit_signal("pressed")
	await get_tree().process_frame
	_check(Global.attempt_binding_burdened and Global.pending_augment_pick, "the second press burdens the Binding and keeps it open")
	var tesla := _card_of(select, "rank", String(TESLA))
	var charm := _card_of(select, "rank", String(CHARM))
	_check(tesla != null and int((tesla.get("card_entry") as Dictionary)["grade"]) == 1, "the re-dealt Tesla card is one grade up")
	_check(tesla != null and _badge(tesla).begins_with(AugmentScaling.grade_name(1)), "and its badge shows the new grade (%s)" % (_badge(tesla) if tesla != null else "missing"))
	_check(charm != null and int((charm.get("card_entry") as Dictionary)["grade"]) == 3, "Apocryphal stays Apocryphal")
	_check(_card_of(select, "facet") != null and _cards(select).size() == 3, "the Facet card stays on the table")
	_check(is_equal_approx(Global.attempt_doctrine_threat_debt - threat_before, AugmentRites.BURDEN_THREAT), "the district hunts you: +20 Threat debt")
	_check(burden.disabled and burden.text.begins_with("BURDEN"), "BURDEN disables itself: once per Binding")
	var status := select.get_node_or_null("Center/VBox/BindingStatus") as Label
	_check(status != null and status.visible and status.text.begins_with("BURDENED") and status.text.contains("+20 THREAT"), "the status line says what was bound (%s)" % (status.text if status != null else "missing"))
	select.queue_free()

	# The Burden Writ waives the Threat, and the confirm says so.
	_pending_binding([{"kind": "rank", "id": String(TESLA), "grade": 0}, {"kind": "rank", "id": String(CHARM), "grade": 1}, {"kind": "rank", "id": String(MISSILE), "grade": 0}])
	Global.attempt_vouchers = [String(Vouchers.BURDEN_WRIT)]
	select = await _open_select()
	burden = _button(select, "Burden")
	burden.emit_signal("pressed")
	_check(burden.text == "CONFIRM  ·  A CURSE", "with the Burden Writ the price is only the curse (%s)" % burden.text)
	select.queue_free()

	# Nothing left to raise: every card Apocryphal.
	_pending_binding([{"kind": "rank", "id": String(TESLA), "grade": 3}, {"kind": "rank", "id": String(CHARM), "grade": 3}, _facet_card()])
	select = await _open_select()
	burden = _button(select, "Burden")
	_check(burden.visible and burden.disabled, "BURDEN is disabled when no card can rise")
	select.queue_free()


func _test_intro_has_no_burden() -> void:
	_pending_binding([{"kind": "new", "id": "augment_sprint_servos", "grade": 0}], 1)
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	var select := await _open_select()
	var burden := _button(select, "Burden")
	_check(burden != null and not burden.visible, "the intro pick shows no BURDEN")
	select.queue_free()


# ---------------------------------------------------------------- NEW

func _test_new_marker() -> void:
	var offer := [{"kind": "transcend", "id": String(TESLA), "grade": -1}, _duo_card(), _facet_card()]
	_pending_binding(offer)
	var select := await _open_select()
	for kind in ["transcend", "duo", "facet"]:
		var card := _card_of(select, kind)
		_check(card != null and _badge(card).contains("NEW"), "an empty Grimoire marks the %s card NEW (%s)" % [kind, _badge(card) if card != null else "missing"])
	select.queue_free()

	# One Facet known: the other is still a discovery, on the card and in the
	# chooser.
	_pending_binding(offer)
	Global.grimoire_entries = [Grimoire.facet_key(MISSILE, &"salvo")]
	select = await _open_select()
	var facet := _card_of(select, "facet")
	_check(facet != null and _badge(facet).contains("NEW"), "a Facet card stays NEW while one Facet is unknown")
	if facet != null:
		facet.emit_signal("pressed")
		await get_tree().process_frame
		var buttons := _facet_buttons(select)
		_check(buttons.size() == 2 and not buttons[0].text.contains("NEW") and buttons[1].text.contains("NEW"), "the chooser marks only the unknown Facet NEW")
	select.queue_free()

	_pending_binding(offer)
	Global.grimoire_entries = [
		Grimoire.transcend_key(TESLA), Grimoire.duo_key(AugmentDuos.LIGHTNING_RODS),
		Grimoire.facet_key(MISSILE, &"salvo"), Grimoire.facet_key(MISSILE, &"lance"),
	]
	select = await _open_select()
	for kind in ["transcend", "duo", "facet"]:
		var card := _card_of(select, kind)
		_check(card != null and not _badge(card).contains("NEW"), "a known %s card is not marked NEW (%s)" % [kind, _badge(card) if card != null else "missing"])
	select.queue_free()


## Every new badge, at its widest (NEW, Lv.17 into a Transcendence), on one
## line of the card; every Duo's rule within the blurb's three lines.
func _test_badges_fit() -> void:
	_pending_binding([])
	Global.grimoire_entries = []
	var entries: Array = []
	for duo_id in AugmentDuos.ids():
		entries.append({"kind": "duo", "id": String(duo_id), "grade": -1})
	for aug_id in AugmentFacets.FACETS.keys():
		entries.append({"kind": "facet", "id": String(aug_id), "grade": -1})
	for aug_id in AugmentScaling.TRANSCENDENCE.keys():
		entries.append({"kind": "transcend", "id": String(aug_id), "grade": -1})
	for entry in entries:
		var data := Global.augment_db.get(AugmentBinding.display_augment_id(entry), null) as AugmentData
		if data == null:
			_check(false, "%s resolves to an augment" % entry["id"])
			continue
		Global.attempt_augment_levels = {String(data.id): 17}
		var card := CARD_SCENE.instantiate()
		add_child(card)
		card.call("set_offer", data, entry)
		await get_tree().process_frame
		var badge := card.get_node("FaceViewport/Face/Badge") as Label
		var desc := card.get_node("FaceViewport/Face/Desc") as Label
		var width := badge.get_theme_font("font").get_string_size(badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge.get_theme_font_size("font_size")).x
		_check(badge.text.contains("NEW") and width <= BADGE_ROOM, "%s %s badge fits one line (%.0f of %.0f px: %s)" % [entry["id"], entry["kind"], width, BADGE_ROOM, badge.text])
		if String(entry["kind"]) == "duo":
			_check(desc.get_line_count() <= desc.max_lines_visible, "%s's rule fits the blurb (%d lines)" % [entry["id"], desc.get_line_count()])
		card.queue_free()
	Global.attempt_augment_levels = {}


# ---------------------------------------------------------------- Run Sheet

func _sheet_text(sheet: Control) -> String:
	return _collect_label_text(sheet.get_node_or_null("Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox"))


func _collect_label_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _test_run_sheet() -> void:
	_pending_binding([])
	Global.pending_augment_pick = false
	Global.attempt_doctrine_stage_ids = {}
	Global.attempt_doctrine_events = []
	var sheet := RUN_SHEET_SCENE.instantiate() as Control
	add_child(sheet)
	sheet.visible = true
	sheet.call("select_page", RunSheetHUD.ArchivePage.MANIFESTATIONS)
	var player := Node.new()
	add_child(player)

	sheet.call("_refresh_manifestations", player)
	_check(not _sheet_text(sheet).contains("DOCTRINE RECORD"), "no record while the run holds nothing to record")

	Global.attempt_augment_duos = {String(AugmentDuos.LIGHTNING_RODS): true}
	Global.attempt_augment_facets = {String(MISSILE): "lance"}
	Global.attempt_augment_corruptions = {String(TESLA): String(AugmentRites.SCARRED)}
	Global.attempt_vouchers = [String(Vouchers.GILDED_INK)]
	sheet.call("_refresh_manifestations", player)
	var text := _sheet_text(sheet)
	_check(text.contains("DOCTRINE RECORD"), "Duos, Facets, Corruptions and Vouchers alone open the record")
	_check(text.contains("DUO // LIGHTNING RODS: " + AugmentDuos.rule(AugmentDuos.LIGHTNING_RODS)), "the active Duo and its rule")
	_check(text.contains("FACET // MAGIC MISSILE: LANCE"), "the chosen Facet")
	_check(text.contains("CORRUPTED // TESLA AURA: SCARRED"), "the Corruption's outcome")
	_check(text.contains("VOUCHER // GILDED INK"), "the bought Voucher")

	# Each of the four is in the sheet's signature: a change rebuilds it.
	Global.attempt_vouchers = [String(Vouchers.GILDED_INK), String(Vouchers.TITHE_SERMON)]
	sheet.call("_refresh_manifestations", player)
	_check(_sheet_text(sheet).contains("VOUCHER // TITHE SERMON"), "a new Voucher rebuilds the sheet")
	Global.attempt_augment_corruptions[String(MISSILE)] = String(AugmentRites.EXALTED)
	sheet.call("_refresh_manifestations", player)
	_check(_sheet_text(sheet).contains("CORRUPTED // MAGIC MISSILE: EXALTED"), "a new Corruption rebuilds it")
	Global.attempt_augment_facets[String(TESLA)] = "overcharge"
	sheet.call("_refresh_manifestations", player)
	_check(_sheet_text(sheet).contains("FACET // TESLA AURA: OVERCHARGE"), "a new Facet rebuilds it")
	Global.attempt_augment_duos[String(AugmentDuos.LOADED_DICE)] = true
	sheet.call("_refresh_manifestations", player)
	_check(_sheet_text(sheet).contains("DUO // LOADED DICE: dormant"), "a new Duo rebuilds it; missing Gambler's Rite it is dormant")

	sheet.queue_free()
	player.queue_free()
	Global.attempt_augment_duos = {}
	Global.attempt_augment_facets = {}
	Global.attempt_augment_corruptions = {}
	Global.attempt_vouchers = []


# ---------------------------------------------------------------- tooltip

func _test_tooltip() -> void:
	_pending_binding([])
	Global.pending_augment_pick = false
	var tooltip := TOOLTIP_SCENE.instantiate() as AugmentTooltip
	add_child(tooltip)
	var missile := Global.augment_db[MISSILE] as AugmentData
	var tesla := Global.augment_db[TESLA] as AugmentData

	tooltip.show_augment(missile, 3)
	var body: String = tooltip.body_label.text
	_check(not body.contains("FACET:") and not body.contains("CORRUPTED:"), "no Facet or Corruption line before either")
	_check(body.contains("Pairs with Tesla Aura for an undiscovered Duo."), "an undiscovered Duo names the partner, not the Duo (%s)" % body)
	Global.grimoire_entries = [Grimoire.duo_key(AugmentDuos.LIGHTNING_RODS), Grimoire.duo_key(AugmentDuos.STATIC_BROOD), Grimoire.duo_key(AugmentDuos.SLIPSTREAM_COIL)]
	tooltip.show_augment(missile, 3)
	body = tooltip.body_label.text
	_check(body.contains("Pairs with Tesla Aura for Lightning Rods."), "a discovered one names both (%s)" % body)

	Global.attempt_augment_facets = {String(MISSILE): "lance"}
	Global.attempt_augment_corruptions = {String(MISSILE): String(AugmentRites.EXALTED)}
	Global.attempt_augment_duos = {String(AugmentDuos.LIGHTNING_RODS): true}
	tooltip.show_augment(missile, 3)
	body = tooltip.body_label.text
	_check(body.contains("FACET: Lance: " + AugmentFacets.rule(MISSILE, &"lance")), "the chosen Facet and its rule (%s)" % body)
	_check(body.contains("CORRUPTED: EXALTED"), "the Corruption")
	_check(body.contains("DUO ACTIVE: Lightning Rods: " + AugmentDuos.rule(AugmentDuos.LIGHTNING_RODS)), "the active Duo and its rule")
	_check(not body.contains("Pairs with Tesla Aura"), "and no partner hint for it")

	tooltip.show_augment(tesla, 3)
	body = tooltip.body_label.text
	_check(body.contains("DUO ACTIVE: Lightning Rods"), "Tesla Aura shares the active Duo")
	_check(body.contains("Pairs with %s for Static Brood." % Global.augment_display_name(&"augment_summon_spiderlings")), "and names its other partners (%s)" % body)
	_check(body.contains("Pairs with %s for Slipstream Coil." % Global.augment_display_name(&"augment_sprint_servos")), "every one of them")

	# Unequip a member: the Duo sleeps and the hint comes back.
	Global.permanent_augment_ids = [MISSILE, CHARM, StringName()]
	tooltip.show_augment(missile, 3)
	body = tooltip.body_label.text
	_check(not body.contains("DUO ACTIVE") and body.contains("Pairs with Tesla Aura for Lightning Rods."), "a Duo missing a member reads as a pairing again")
	tooltip.queue_free()
	Global.attempt_augment_duos = {}
	Global.attempt_augment_facets = {}
	Global.attempt_augment_corruptions = {}


## Cross-cutting review: an armed Abstain stands down when a card is taken,
## and a card that opened one chooser lets go when another card opens the
## other.
func _test_chooser_hygiene() -> void:
	_pending_binding([_facet_card(), {"kind": "swap", "id": "augment_sprint_servos", "grade": 0}, {"kind": "rank", "id": String(TESLA), "grade": 0}])
	var select := await _open_select()
	var abstain := _button(select, "Abstain")
	var facet := _card_of(select, "facet")
	var swap := _card_of(select, "swap")
	if abstain == null or facet == null or swap == null:
		_check(false, "the hygiene Binding deals its cards and footer")
		select.queue_free()
		return
	abstain.emit_signal("pressed")
	_check(abstain.text.begins_with("CONFIRM"), "Abstain is armed")
	facet.emit_signal("pressed")
	await get_tree().process_frame
	_check(abstain.text.begins_with("ABSTAIN"), "taking a card disarms it, so a stray click cannot throw the pick away")
	_check(bool(facet.get("_picked")), "the FACET card stands lit while its chooser is open")
	swap.emit_signal("pressed")
	await get_tree().process_frame
	_check(not bool(facet.get("_picked")), "opening the SWAP chooser lets the FACET card go")
	_check(bool(swap.get("_picked")), "and lights the SWAP card")
	select.queue_free()
	await get_tree().process_frame

