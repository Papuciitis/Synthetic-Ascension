extends Node

## Transformation previews are explicit: an offer may show a form the run
## does not own, while a base library illustration stays base. Texture
## fallback uses tiny procedural resources, independent of generated art.
const ART_SCRIPT := "res://core/systems/augments/AugmentArt.gd"
const MISSILE := &"augment_magic_missile"
const FIXTURE_A := "user://augment_art_test_first.tres"
const FIXTURE_B := "user://augment_art_test_second.tres"
const MISSING := "user://augment_art_test_missing.tres"
var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _texture(color: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 2
	texture.height = 2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, color])
	texture.gradient = gradient
	return texture


func _available_or_base(path: String, base: Texture2D) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else base


func _entry(entries: Array, key: String) -> Dictionary:
	for row: Dictionary in entries:
		if String(row.get("key", "")) == key:
			return row
	return {}


func _test_consumers(a: AugmentData, facet_path: String, transcend_path: String) -> void:
	var base: Texture2D = a.icon
	var facet := _available_or_base(facet_path, base)
	var current := _available_or_base(transcend_path, facet)
	var slot_scene: PackedScene = load("res://ui/widgets/AugmentEquipSlot.tscn")
	var slot: Variant = slot_scene.instantiate()
	add_child(slot)
	slot.set_data(a)
	_check(slot.icon_rect.texture == current, "the equipped slot shows the actual evolved form")
	var library_scene: PackedScene = load("res://ui/widgets/AugmentLibraryEntry.tscn")
	var base_entry: Variant = library_scene.instantiate()
	add_child(base_entry)
	base_entry.set_data(a)
	_check(base_entry.icon_rect.texture == base, "the owned library's base entry keeps its base illustration")
	var tip_scene: PackedScene = load("res://ui/widgets/AugmentTooltip.tscn")
	var tip: Variant = tip_scene.instantiate()
	add_child(tip)
	# The live run has become Choir/Lance; these previews ask for something
	# else and must use that explicit form for prose as well as artwork.
	Global.attempt_augment_facets = {String(MISSILE): "lance"}
	tip.show_augment(a, 3, {"facet": &"salvo", "transcended": false})
	_check(tip.icon.texture == facet, "an explicit Facet tooltip ignores the run's later Transcendence")
	_check(tip.name_label.text == "Magic Missile  Lv.3", "an explicit nontranscended preview uses the base ability name")
	_check("FACET: Salvo:" in tip.body_label.text and "+2 missiles" in tip.body_label.text and not "FACET: Lance:" in tip.body_label.text, "an explicit Salvo preview describes Salvo rather than the run's Lance")
	_check(not "TRANSCENDED (" in tip.body_label.text, "a nontranscended preview does not claim the run's evolved form")
	tip.show_augment(a, 3, {"facet": &"", "transcended": false})
	_check(tip.icon.texture == base, "an explicit base tooltip stays base")
	_check(tip.name_label.text == "Magic Missile  Lv.3" and not "FACET:" in tip.body_label.text and not "TRANSCENDED (" in tip.body_label.text, "a base library preview does not claim either owned transformation")
	tip.show_augment(a, 3, {"transcended": false})
	_check(tip.icon.texture == base and not "FACET:" in tip.body_label.text, "an undefined preview Facet means base rather than the current-run Facet")
	tip.show_augment(a, 3, {"facet": &"not_a_branch", "transcended": false})
	_check(tip.name_label.text == "Magic Missile  Lv.3" and tip.icon.texture == base and not "FACET:" in tip.body_label.text, "an unknown preview Facet safely describes the base form")
	tip.show_augment(a, 3)
	_check(tip.name_label.text == "Choir of Needles  Lv.3" and "TRANSCENDED (" in tip.body_label.text and "FACET: Lance:" in tip.body_label.text, "an ordinary tooltip still follows the current Choir/Lance run")
	Global.attempt_augment_transcended = {}
	tip.show_augment(a, 3, {"transcended": true})
	_check(tip.name_label.text == "Choir of Needles  Lv.3" and "TRANSCENDED (" in tip.body_label.text and not "FACET: Lance:" in tip.body_label.text, "an explicit future Transcendence describes its form before ownership")
	var card_scene: PackedScene = load("res://ui/augments/AugmentCard.tscn")
	var card: Variant = card_scene.instantiate()
	add_child(card)
	Global.attempt_augment_facets = {}
	Global.attempt_augment_transcended = {}
	card.set_offer(a, {"kind": "transcend", "id": MISSILE, "grade": 0})
	_check(card.icon_rect.texture == _available_or_base(transcend_path, base), "the actual offer card previews an unowned Transcendence")
	var chooser_scene: PackedScene = load("res://ui/augments/AugmentSelect.tscn")
	var chooser: CanvasLayer = chooser_scene.instantiate()
	add_child(chooser)
	chooser.call("_open_facet_chooser", a, null, {"kind": "facet", "id": MISSILE})
	var button := chooser.get_node_or_null("Center/VBox/FacetChooser").find_child("Facet_salvo", true, false)
	var preview := button.get_node_or_null("FacetArt") as TextureRect if button != null else null
	_check(preview != null and preview.texture == facet, "the branch chooser previews each ability before a branch is selected")

	var saved_database: Dictionary = Global.augment_db.duplicate()
	var saved_discoveries: Array[String] = Global.library_discoveries.duplicate()
	var saved_grimoire: Array[String] = Global.grimoire_entries.duplicate()
	Global.augment_db[MISSILE] = a
	if not Global.library_discoveries.has("augment:augment_magic_missile"):
		Global.library_discoveries.append("augment:augment_magic_missile")
	Global.grimoire_entries = []
	var catalogue: Variant = load("res://ui/screens/HubLibraryData.gd")
	var entries: Array = catalogue.build_entries()
	_check(_entry(entries, "augment:augment_magic_missile")["icon"] == base, "the Hub base augment account uses base art")
	var key := "transcend:augment_magic_missile"
	_check(_entry(entries, key)["icon"] == null, "an undiscovered transformed recipe reveals no illustration")
	Global.grimoire_entries = [key]
	entries = catalogue.build_entries()
	_check(_entry(entries, key)["icon"] == _available_or_base(transcend_path, base), "a discovered transformed recipe shows its explicit future form")
	Global.augment_db = saved_database
	Global.library_discoveries.assign(saved_discoveries)
	Global.grimoire_entries = saved_grimoire
	for node in [slot, base_entry, tip, card, chooser]:
		node.queue_free()
	await get_tree().process_frame


func _run() -> void:
	if not ResourceLoader.exists(ART_SCRIPT):
		_check(false, "transformed augment offers have an art resolver")
		get_tree().quit(1)
		return
	var art: Variant = load(ART_SCRIPT)
	var saved_facets: Dictionary = Global.attempt_augment_facets.duplicate(true)
	var saved_transcended: Dictionary = Global.attempt_augment_transcended.duplicate(true)
	Global.attempt_augment_facets = {}
	Global.attempt_augment_transcended = {}
	var facet_path := "res://assets/ui/augments/cards/facets/magic_missile_salvo.png"
	var transcend_path := "res://assets/ui/augments/cards/transcend/magic_missile.png"
	_check(art.candidate_paths(MISSILE, &"salvo", false) == [facet_path], "a selected Facet shows its changed ability before Transcendence")
	_check(art.candidate_paths(MISSILE, &"salvo", true) == [transcend_path, facet_path], "Transcendence takes priority while the Facet remains a safe fallback")
	_check(art.candidate_paths(MISSILE, &"not_a_branch", false).is_empty(), "an unknown Facet cannot manufacture an illustration path")
	_check(art.candidate_paths(&"unknown_augment", &"salvo", true).is_empty(), "an unknown augment safely retains its authored base icon")
	var preview: Dictionary = {"kind": "transcend", "id": MISSILE}
	_check(art.offer_paths(MISSILE, preview, &"", false) == [transcend_path], "a Transcend offer previews the future form before it is owned")
	var duo: Dictionary = {"kind": "duo", "id": &"duo_lightning_rods"}
	_check(art.offer_paths(MISSILE, duo, &"salvo", true) == ["res://assets/ui/augments/cards/duos/lightning_rods.png"], "a Duo offer shows the combined ability instead of a member's current form")
	_check(art.offer_paths(MISSILE, {"kind": "rank", "id": MISSILE}, &"salvo", true) == [transcend_path, facet_path], "a rank offer shows the form the augment already has")
	_check(art.offer_paths(MISSILE, {"kind": "facet", "id": MISSILE}, &"", false).is_empty(), "a Facet offer stays base until its two branches are previewed separately")
	_check(art.grimoire_paths("facet:augment_magic_missile:salvo") == [facet_path], "a catalogue Facet selects its own illustration regardless of run ownership")
	_check(art.grimoire_paths("transcend:augment_magic_missile") == [transcend_path], "a catalogue Transcendence selects its explicit future form")
	_check(art.grimoire_paths("thesis:circuit").is_empty(), "non-augment discoveries do not borrow unrelated augment art")

	var base := _texture(Color.RED)
	var a := AugmentData.new()
	a.id = MISSILE
	a.display_name = "Magic Missile"
	a.icon = base
	Global.attempt_augment_facets = {String(MISSILE): "salvo"}
	Global.attempt_augment_transcended = {String(MISSILE): true}
	_check(art.texture_for(a) == base, "explicit base presentation ignores a Transcended run state")
	_check(art.resolve_texture([MISSING], base) == base, "missing upgrade art falls back without removing the base illustration")
	var first := _texture(Color.BLUE)
	var second := _texture(Color.GREEN)
	_check(ResourceSaver.save(first, FIXTURE_A) == OK and ResourceSaver.save(second, FIXTURE_B) == OK, "procedural illustrations are available for fallback checks")
	var selected: Texture2D = art.resolve_texture([MISSING, FIXTURE_A, FIXTURE_B], base)
	_check(selected != null and selected.resource_path == FIXTURE_A, "the first available transformed illustration wins after a missing higher-priority form")
	selected = art.resolve_texture([FIXTURE_B, FIXTURE_A], base)
	_check(selected != null and selected.resource_path == FIXTURE_B, "available illustrations respect semantic priority rather than file order")
	await _test_consumers(a, facet_path, transcend_path)

	Global.attempt_augment_facets = saved_facets
	Global.attempt_augment_transcended = saved_transcended
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_A))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_B))
	print("AugmentArtTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
