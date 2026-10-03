extends Node
## Renders the Binding and the Doctrine plates to PNGs (needs a display, not
## --headless): graded cards with a Transcend card, the Recast / Abstain
## footer, an armed Abstain, the SWAP slot chooser, the hover dossier, the
## Doctrine plates with their family lines, and an Apocrypha stage. A
## throwaway attempt with no current save, so nothing reaches the player's
## slots (docs/design/2026-10-03-bindings-and-theses.md).
## Run: <godot> --path . res://tools/dev/BindingShotProbe.tscn -- --out=/abs/dir

var _out := "/tmp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.attempt_world_seed = 8128
	Global.transaction_followers(1400 - Global.followers, &"dev_grant", {}, false, false)
	await _wait(0.3)
	await _binding_open_slot()
	await _binding_full_slots()
	await _doctrine()
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


func _backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	return bg


func _set_binding(equipped: Array, levels: Dictionary, segment: int) -> void:
	var typed: Array[StringName] = []
	typed.assign(equipped)
	Global.permanent_augment_ids = typed
	Global.init_owned_augments()
	Global.augment_slot_locks = [false, false, false]
	Global.attempt_augment_levels = levels
	Global.attempt_augment_transcended = {}
	Global.attempt_segment = segment
	Global.pending_augment_pick = true
	Global.attempt_binding_offer = []
	Global.attempt_binding_recasts = 0


func _open_select() -> CanvasLayer:
	var screen := (load("res://ui/augments/AugmentSelect.tscn") as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	await get_tree().process_frame
	screen.call("open_choose_3")
	await _wait(1.4)
	return screen


func _cards(screen: Node) -> Array:
	return screen.find_children("*", "Button", true, false).filter(func(c: Node) -> bool: return c.has_signal("picked"))


## One free slot, Tesla Aura ready to Transcend beside Sprint Servos.
func _binding_open_slot() -> void:
	var bg := _backdrop()
	_set_binding([&"augment_tesla_aura", &"augment_sprint_servos", StringName()], {"augment_tesla_aura": 5, "augment_sprint_servos": 3}, 6)
	var screen := await _open_select()
	await _shot("binding_open")
	var cards := _cards(screen)
	if cards.size() > 0:
		var rect := (cards[0] as Control).get_global_rect()
		get_viewport().warp_mouse(rect.get_center())
		await _wait(0.7)
		await _shot("binding_hover_transcend")
	if cards.size() > 1:
		var rect2 := (cards[1] as Control).get_global_rect()
		get_viewport().warp_mouse(rect2.get_center())
		await _wait(0.7)
		await _shot("binding_hover_new")
	get_viewport().warp_mouse(Vector2(20, 20))
	screen.call("_on_abstain_pressed")
	await _wait(0.3)
	await _shot("binding_abstain_armed")
	screen.queue_free()
	bg.queue_free()
	await _wait(0.2)


## All three slots full under the Circuit Thesis: rank-ups, a swap, four cards.
func _binding_full_slots() -> void:
	var bg := _backdrop()
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_liturgy_of_overclock"}
	_set_binding([&"augment_tesla_aura", &"augment_magic_missile", &"augment_spirit_slash"], {"augment_tesla_aura": 7, "augment_magic_missile": 3, "augment_spirit_slash": 2}, 8)
	Global.attempt_augment_transcended = {"augment_tesla_aura": true}
	var screen := await _open_select()
	await _shot("binding_full")
	for card in _cards(screen):
		var entry: Variant = card.get("card_entry")
		if entry is Dictionary and String((entry as Dictionary).get("kind", "")) == "swap":
			screen.call("_on_card_picked", card.get("data"), card)
			await _wait(0.4)
			await _shot("binding_swap_chooser")
			break
	screen.queue_free()
	bg.queue_free()
	Global.attempt_doctrine_stage_ids = {}
	await _wait(0.2)


func _doctrine() -> void:
	var bg := _backdrop()
	Global.pending_augment_pick = false
	Global.attempt_major_choice_taken_ids.clear()
	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit"}
	Global.attempt_major_choice_taken_ids.append(&"doctrine_method_open_circuit")
	Global.pending_big_choice = true
	Global.attempt_pending_doctrine_stage = &"doctrine"
	Global.attempt_big_choice_source_segment = 6
	Global.attempt_major_choice_offer_ids.clear()
	var screen := (load("res://ui/screens/MajorChoice.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.call("open")
	await _wait(1.6)
	await _shot("doctrine_plates")
	screen.queue_free()
	await _wait(0.3)

	Global.attempt_doctrine_stage_ids = {"method": "doctrine_method_open_circuit", "doctrine": "doctrine_iron_liturgy", "apotheosis": "doctrine_apotheosis_mass_conversion"}
	for value in Global.attempt_doctrine_stage_ids.values():
		Global.attempt_major_choice_taken_ids.append(StringName(value))
	Global.attempt_pending_doctrine_stage = &"apocrypha_12"
	Global.attempt_big_choice_source_segment = 12
	Global.attempt_major_choice_offer_ids.clear()
	var apocrypha := (load("res://ui/screens/MajorChoice.tscn") as PackedScene).instantiate()
	add_child(apocrypha)
	await get_tree().process_frame
	apocrypha.call("open")
	await _wait(1.6)
	await _shot("doctrine_apocrypha")
	apocrypha.queue_free()
	bg.queue_free()
	Global.pending_big_choice = false
	await _wait(0.2)
