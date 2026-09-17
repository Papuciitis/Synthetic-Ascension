extends Resource
class_name Inventory

# Core "attribute" slots (these 6 map to player stat multipliers)
const STAT_SLOT_COUNT := 6

# Extra equipment slots
const SLOT_OFFHAND := STAT_SLOT_COUNT      # 6
const SLOT_RING := STAT_SLOT_COUNT + 1     # 7

# Total equipped slots
const SLOT_COUNT := STAT_SLOT_COUNT + 2

const SLOT_DEFINITIONS: Array[Dictionary] = [
	{"id": &"hp", "label": "Health", "hint": "HP"},
	{"id": &"armor", "label": "Armor", "hint": "ARM"},
	{"id": &"move", "label": "Movement", "hint": "MOV"},
	{"id": &"power", "label": "Power", "hint": "PWR"},
	{"id": &"haste", "label": "Haste", "hint": "HST"},
	{"id": &"luck", "label": "Luck", "hint": "LCK"},
	{"id": &"offhand", "label": "Offhand", "hint": "OFF"},
	{"id": &"ring", "label": "Ring", "hint": "RING"},
]

static func slot_definition(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_DEFINITIONS.size():
		return {"id": &"unknown", "label": "Equipment", "hint": ""}
	return SLOT_DEFINITIONS[index]

static func slot_hint(index: int) -> String:
	return String(slot_definition(index).get("hint", ""))

static func slot_label(index: int) -> String:
	return String(slot_definition(index).get("label", "Equipment"))

# Always length SLOT_COUNT; null means empty slot

signal slot_set(slot: int, inst: ItemInstance, prev: ItemInstance, origin: Dictionary)
signal slot_fed(slot: int, inst: ItemInstance, upgraded: bool, old_rarity: int, origin: Dictionary)
signal equipment_changed(slot: int, inst: ItemInstance, prev: ItemInstance, player_driven: bool)


@export var items: Array[ItemInstance] = []

enum UIOriginType { NONE = 0, SCREEN = 1 }

var _pending_ui_origin_type: int = UIOriginType.NONE
var _pending_ui_origin_pos: Vector2 = Vector2.ZERO

func set_pending_ui_origin_ui(screen_pos: Vector2) -> void:
	_pending_ui_origin_type = UIOriginType.SCREEN
	_pending_ui_origin_pos = screen_pos

func consume_pending_ui_origin() -> Dictionary:
	var d: Dictionary = {
		"type": _pending_ui_origin_type,
		"pos": _pending_ui_origin_pos,
	}
	_pending_ui_origin_type = UIOriginType.NONE
	_pending_ui_origin_pos = Vector2.ZERO
	return d



func _init() -> void:
	_ensure_size()

func _ensure_size() -> void:
	if items.size() != SLOT_COUNT:
		items.resize(SLOT_COUNT)

func clear() -> void:
	_ensure_size()
	for i in range(SLOT_COUNT):
		items[i] = null
	emit_changed()

func clear_pending_ui_origin() -> void:
	_pending_ui_origin_type = int(UIOriginType.NONE)
	_pending_ui_origin_pos = Vector2.ZERO


func is_slot_empty(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	return items[slot] == null

func is_full() -> bool:
	_ensure_size()
	for i in range(SLOT_COUNT):
		if items[i] == null:
			return false
	return true

func first_empty_slot() -> int:
	_ensure_size()
	for i in range(SLOT_COUNT):
		if items[i] == null:
			return i
	return -1

# Add an item to its fixed equipment slot.
func add_item(inst: ItemInstance, origin: Variant = null) -> bool:
	if inst == null or inst.data == null:
		return false
	_ensure_size()

	var idx: int = int(inst.data.equip_slot)
	if idx < 0 or idx >= SLOT_COUNT or not is_slot_empty(idx):
		return false

	# IMPORTANT: route through set_item so slot_set can fire (and VFX works)
	set_item(idx, inst, origin)
	return items[idx] == inst
	
# "Equip add": force into a specific slot (0..7)
# Returns previous item (can be null)
func set_item(slot: int, inst: ItemInstance, origin: Variant = null) -> ItemInstance:
	_ensure_size()
	if slot < 0 or slot >= SLOT_COUNT:
		return null

	# Safety: strict equipped slots (prevents invalid items living in wrong slots).
	if inst != null and inst.data != null:
		var es: int = int(inst.data.equip_slot)
		if es != int(slot):
			push_warning("Inventory.set_item: rejected mismatched equip slot (want %d got %d) for %s" % [slot, es, String(inst.data.id)])
			return items[slot]


	var prev: ItemInstance = items[slot]
	items[slot] = inst
	emit_changed()
	var player_driven: bool = origin is Dictionary and bool((origin as Dictionary).get("player_driven", false))
	player_driven = player_driven or origin is Vector2
	equipment_changed.emit(slot, inst, prev, player_driven)

	var o := _normalize_origin(origin)
	if not o.is_empty():
		slot_set.emit(slot, inst, prev, o)

	# clear pending after use (prevents stale)
	_pending_ui_origin_type = UIOriginType.NONE
	_pending_ui_origin_pos = Vector2.ZERO

	return prev

func remove_at(index: int, origin: Variant = null) -> void:
	_ensure_size()
	if index < 0 or index >= SLOT_COUNT:
		return
	var prev: ItemInstance = items[index]
	items[index] = null
	emit_changed()
	var player_driven: bool = origin is Dictionary and bool((origin as Dictionary).get("player_driven", false))
	player_driven = player_driven or origin is Vector2
	equipment_changed.emit(index, null, prev, player_driven)

func get_at(index: int) -> ItemInstance:
	_ensure_size()
	if index < 0 or index >= SLOT_COUNT:
		return null
	return items[index]

func sum_mods() -> StatDelta:
	_ensure_size()
	var s := StatDelta.new()

	for i in range(items.size()):
		var it: ItemInstance = items[i]
		if it == null or it.data == null:
			continue
		# Safety: ignore corrupted entries that are in the wrong equipped slot.
		if int(it.data.equip_slot) != int(i):
			continue
		if it.rolled_mods == null:
			continue

		var m := it.rolled_mods
		s.max_hp += m.max_hp
		s.armor += m.armor
		s.move_speed += m.move_speed
		s.power += m.power
		s.haste += m.haste
		s.luck += m.luck

	return s


func get_negative_item_count() -> int:
	var total := 0
	for item in items:
		if item != null and int(item.polarity) == int(ItemInstance.Polarity.NEG):
			total += 1
	return total


func get_negative_rarity_total() -> int:
	var total := 0
	for item in items:
		if item != null and int(item.polarity) == int(ItemInstance.Polarity.NEG):
			total += maxi(0, int(item.rarity))
	return total


func get_negative_magnitude_total() -> float:
	var total := 0.0
	for item in items:
		if item != null and int(item.polarity) == int(ItemInstance.Polarity.NEG):
			total += absf(float(item.active_pct()))
	return total


func get_set_polarity_composition(set_id: StringName) -> Dictionary:
	var result := {"pos": 0, "neg": 0}
	for item in items:
		if item == null or item.data == null or StringName(item.data.set_id) != set_id:
			continue
		var key := "neg" if int(item.polarity) == int(ItemInstance.Polarity.NEG) else "pos"
		result[key] = int(result[key]) + 1
	return result

func _merge_into(dest: ItemInstance, src: ItemInstance) -> bool:
	if dest == null:
		return false
	return dest.merge_from(src)

func add_or_feed(inst: ItemInstance, origin: Variant = null, allow_rule_loss: bool = false) -> bool:
	if inst == null or inst.data == null:
		return false

	_ensure_size()

	# 1) Feed/merge if same item already equipped (same id + same polarity)
	for i in range(SLOT_COUNT):
		var it: ItemInstance = items[i]
		if it == null or it.locked or inst.locked:
			continue
		if it.data != null and it.data.id == inst.data.id and int(it.polarity) == int(inst.polarity):
			# Automatic routing must not dissolve a Manifestation the player
			# has never seen. Decline instead and let the caller bag it, so
			# choosing between two rules stays a decision rather than an
			# accident. Player-driven merges pass allow_rule_loss.
			if not allow_rule_loss and not it.can_absorb_manifestation_of(inst):
				continue

			var old_r: int = int(it.rarity)

			# Merge the whole incoming instance (progress + meters) into the equipped one.
			# A refused merge must NOT be reported as consumed - the caller
			# would drop the item on the floor.
			if not _merge_into(it, inst):
				continue

			emit_changed()

			var upgraded := int(it.rarity) != old_r
			var o := _normalize_origin(origin)
			if not o.is_empty():
				slot_fed.emit(i, it, upgraded, old_r, o)

			_pending_ui_origin_type = UIOriginType.NONE
			_pending_ui_origin_pos = Vector2.ZERO
			return true

	# 2) Otherwise place into first empty slot (and fire slot_set)
	return add_item(inst, origin)
	
func feed_roll_into(slot: int, roll_pct: float, origin: Variant = null) -> bool:
	_ensure_size()
	if slot < 0 or slot >= SLOT_COUNT:
		return false

	var it: ItemInstance = items[slot]
	if it == null or it.data == null or it.locked:
		return false

	var old_r: int = int(it.rarity)
	it.feed_roll(roll_pct)
	emit_changed()

	var upgraded: bool = int(it.rarity) != old_r
	var o := _normalize_origin(origin)
	if not o.is_empty():
		slot_fed.emit(slot, it, upgraded, old_r, o)

	_pending_ui_origin_type = UIOriginType.NONE
	_pending_ui_origin_pos = Vector2.ZERO

	return true


func get_set_counts() -> Dictionary:
	_ensure_size()
	var counts: Dictionary = {} # StringName -> int

	# Sets are built ONLY from the 6 core "attribute" slots (0..5).
	# Offhand + Ring slots intentionally do NOT contribute.
	for i in range(STAT_SLOT_COUNT):
		var it: ItemInstance = items[i]
		if it == null or it.data == null:
			continue

		# supports ItemData.set_id being String or StringName
		var sid := StringName(str(it.data.set_id))
		if sid == StringName() or str(sid) == "":
			continue

		counts[sid] = int(counts.get(sid, 0)) + 1

	return counts


# Average ItemInstance.rarity among equipped set pieces (slots 0..5) for this set.
# 0.0 means either "no pieces" or "all rarity 0".
func get_set_rarity_average(set_id: StringName) -> float:
	_ensure_size()
	var sum_r := 0.0
	var n := 0
	for i in range(STAT_SLOT_COUNT):
		var it: ItemInstance = items[i]
		if it == null or it.data == null:
			continue
		if StringName(str(it.data.set_id)) != set_id:
			continue
		sum_r += float(it.rarity)
		n += 1
	return (sum_r / float(n)) if n > 0 else 0.0

# Converts average rarity into an infinite but diminishing strength scalar.
func get_set_strength(set_id: StringName) -> float:
	var avg_r := get_set_rarity_average(set_id)
	return RarityMath.potency(avg_r)

func swap(a: int, b: int) -> void:
	_ensure_size()
	if a < 0 or a >= SLOT_COUNT:
		return
	if b < 0 or b >= SLOT_COUNT:
		return
	if a == b:
		return

	var ia := items[a]
	items[a] = items[b]
	items[b] = ia
	emit_changed()
	
func move_to(other: Object, from_i: int, to_i: int) -> bool:
	if other == null: return false
	if not other.has_method("get_at"): return false
	if not other.has_method("set_item"): return false
	if not other.has_method("remove_at"): return false

	var it: ItemInstance = get_at(from_i)
	if it == null:
		return false

	var dst: ItemInstance = other.call("get_at", to_i) as ItemInstance

	other.call("set_item", to_i, it)
	remove_at(from_i)

	# swap back if occupied
	if dst != null:
		set_item(from_i, dst)

	return true

func _normalize_origin(origin: Variant) -> Dictionary:
	# Accept {"type": int, "pos": Vector2}
	if origin is Dictionary:
		var d: Dictionary = origin
		if d.has("pos") and d["pos"] is Vector2:
			return {"type": int(d.get("type", UIOriginType.SCREEN)), "pos": d["pos"]}

	# Accept Vector2 (screen pos)
	if origin is Vector2:
		return {"type": UIOriginType.SCREEN, "pos": origin}

	# Fall back to pending origin
	if _pending_ui_origin_type != UIOriginType.NONE:
		return {"type": _pending_ui_origin_type, "pos": _pending_ui_origin_pos}

	return {} # no origin
