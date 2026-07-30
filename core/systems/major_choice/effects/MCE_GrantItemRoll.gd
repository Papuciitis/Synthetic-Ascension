extends MajorChoiceEffect
class_name MCE_GrantItemRoll

@export var item_id: String = ""
@export var rarity: int = 4
@export var polarity: int = 1 # ItemInstance.Polarity.POS / NEG
@export var roll_pct: float = 0.45
@export var prefer_equip: bool = true

func can_apply(g: Node) -> bool:
	return g != null and item_id != "" and g.get("item_db") != null

func apply(g: Node) -> void:
	var db: Dictionary = g.get("item_db")
	var d: ItemData = db.get(item_id, null) as ItemData
	if d == null:
		push_warning("MCE_GrantItemRoll: item_id not found: " + item_id)
		return

	var inst := ItemInstance.from_roll(d, rarity, polarity, roll_pct)
	if not g.has_method("deliver_guaranteed_item") or not bool(g.call("deliver_guaranteed_item", inst, prefer_equip)):
		push_error("MCE_GrantItemRoll: no safe destination for reward " + item_id)

func get_preview_lines(g: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if item_id == "":
		return out
	var nm := item_id
	if g != null and g.get("item_db") != null:
		var db: Dictionary = g.get("item_db")
		var d: ItemData = db.get(item_id, null) as ItemData
		if d != null and String(d.display_name) != "":
			nm = d.display_name
	var pol := ("POS" if polarity >= 0 else "NEG")
	out.append("• Gain: %s  (R%d %s)" % [nm, int(rarity), pol])
	return out
