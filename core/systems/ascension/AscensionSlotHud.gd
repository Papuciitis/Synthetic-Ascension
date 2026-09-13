extends Node
class_name AscensionSlotHud
## The HUD face of one equipped tree slot (Q active or V revelation).
##
## ActiveAbilityHUD binds to any child of a listed runner that has
## active_cd_changed; this node is that child. It exists only while something
## is equipped in its slot, so the widget hides itself when the slot empties.

signal active_cd_changed(time_left: float, max_cd: float)
signal active_failed(message: String)

var slot: String = "q"
var node_id: String = ""
var hud_priority: int = 5
var hud_key_text: String = "Q"
var hud_title_text: String = "Active"
var hud_icon: Texture2D = null


func configure(slot_name: String, id: String, title: String) -> void:
	slot = slot_name
	node_id = id
	hud_key_text = "Q" if slot_name == "q" else "V"
	hud_title_text = title
	name = "QSlot" if slot_name == "q" else "VSlot"


func get_active_state() -> Dictionary:
	var runner := get_parent()
	if runner == null or not runner.has_method("slot_state"):
		return {"ready": false, "status_text": "LOCKED"}
	return runner.call("slot_state", slot)


func announce(time_left: float, max_cd: float) -> void:
	active_cd_changed.emit(time_left, max_cd)


func fail(message: String) -> void:
	active_failed.emit(message)
