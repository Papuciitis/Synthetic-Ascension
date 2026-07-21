extends Resource
class_name BagInventory

signal stack_added(slot: int, inst: ItemInstance)
signal stack_fed(slot: int, inst: ItemInstance, roll_pct: float, upgraded: bool, old_rarity: int)
signal stack_merged(from_slot: int, to_slot: int, src: ItemInstance)

const SLOT_COUNT: int = 16

# Fixed-size slots. Each slot holds one "stack project" (ItemInstance) or null.
@export var slots: Array[ItemInstance] = []
@export var debug_bag: bool = true
# Extra slots granted by attempt modifiers / upgrades (persists in SaveData attempt snapshot)
@export var extra_slots: int = 0

# key -> slot index (rebuilt as needed; keep internal)
var _index: Dictionary = {} # String -> int

# --- UI origin for VFX (set by gameplay, consumed by BagUI) ---
enum UIOriginType {
	NONE   = 0,
	SCREEN = 1, # screen/canvas coordinates (UI space)
	WORLD  = 2, # world coordinates (Node2D global_position)
	UI     = 3, # global UI coords (Control.get_global_rect center, etc.)
}

var _pending_ui_origin_type: int = UIOriginType.NONE
var _pending_ui_origin_pos: Vector2 = Vector2.ZERO

# ----------------------------
# UI origin (for BagUI VFX)
# Stored as: {"type": int, "screen_pos": Vector2}
# ----------------------------

func set_pending_ui_origin(origin: Variant) -> void:
	# Accept Dictionary {"type": int, "pos": Vector2}
	if origin is Dictionary:
		var d: Dictionary = origin
		var pv: Variant = d.get("pos", null)
		if pv is Vector2:
			_pending_ui_origin_type = int(d.get("type", int(UIOriginType.SCREEN)))
			_pending_ui_origin_pos = pv as Vector2
			return

	# Accept plain Vector2 (treat as SCREEN pos)
	if origin is Vector2:
		_pending_ui_origin_type = int(UIOriginType.SCREEN)
		_pending_ui_origin_pos = origin as Vector2
		return

	# Otherwise: clear
	_pending_ui_origin_type = int(UIOriginType.NONE)
	_pending_ui_origin_pos = Vector2.ZERO


# Backward compatible wrappers (so ItemPickup calling these won’t break)
func set_pending_ui_origin_world(screen_pos: Vector2) -> void:
	_pending_ui_origin_type = int(UIOriginType.SCREEN)
	_pending_ui_origin_pos = screen_pos

func set_pending_ui_origin_ui(screen_pos: Vector2) -> void:
	_pending_ui_origin_type = int(UIOriginType.SCREEN)
	_pending_ui_origin_pos = screen_pos


func consume_pending_ui_origin() -> Dictionary:
	var d: Dictionary = {
		"type": _pending_ui_origin_type,
		"pos": _pending_ui_origin_pos,
	}
	_pending_ui_origin_type = int(UIOriginType.NONE)
	_pending_ui_origin_pos = Vector2.ZERO
	return d


func _dbg_dump(tag: String) -> void:
	if not debug_bag:
		return
	print("[BAG]", tag)
	for i in range(slots.size()):
		var s: ItemInstance = slots[i]
		if s == null or s.data == null:
			continue
		var meter := 0.0
		var mv: Variant = s.get("upgrade_meter")
		if mv is float or mv is int:
			meter = float(mv)
		print("  slot", i, " key=", _key(s.data.id, s.rarity, s.polarity),
			" inst_id=", s.get_instance_id(),
			" r=", s.rarity, " prog=", s.progress, " meter=", String.num(meter, 3))


func _init() -> void:
	_ensure_size()
	_rebuild_index()


func _ensure_size() -> void:
	var want: int = SLOT_COUNT + maxi(0, extra_slots)
	if slots.size() != want:
		slots.resize(want)


func get_slot_count() -> int:
	_ensure_size()
	return slots.size()


func clear() -> void:
	_ensure_size()
	for i in range(slots.size()):
		slots[i] = null
	_index.clear()
	emit_changed()


func first_empty_slot() -> int:
	_ensure_size()
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1


func get_at(slot: int) -> ItemInstance:
	_ensure_size()
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]

func clear_pending_ui_origin() -> void:
	_pending_ui_origin_type = int(UIOriginType.NONE)
	_pending_ui_origin_pos = Vector2.ZERO


# Optional but makes routing more universal (Inventory has set_item)
func set_item(slot: int, inst: ItemInstance, _origin: Variant = null) -> ItemInstance:
	_ensure_size()
	if slot < 0 or slot >= slots.size():
		return null
	var prev: ItemInstance = slots[slot]
	slots[slot] = inst
	_after_stack_changed()
	return prev


func remove_at(slot: int) -> void:
	_ensure_size()
	if slot < 0 or slot >= slots.size():
		return
	slots[slot] = null
	_after_stack_changed()


func add_pickup(item_data: ItemData, copies: int = 1, rarity: int = 0) -> bool:
	# Compatibility wrapper for old callers.
	# Rolls per copy -> polarity comes from roll sign -> routes into add_roll().
	if item_data == null:
		return false

	copies = maxi(1, copies)

	for i in range(copies):
		var roll_pct: float = Global.roll_percent(Global.run_luck, item_data.pct_min, item_data.pct_max)
		var pol: int = (ItemInstance.Polarity.POS if roll_pct >= 0.0 else ItemInstance.Polarity.NEG)

		if not add_roll(item_data, rarity, pol, roll_pct):
			return false
		print("[BAG ROLL] ", item_data.id, " r=", rarity, " roll=", String.num(roll_pct, 3), " pol=", pol)

	return true


func set_at(slot: int, inst: ItemInstance) -> void:
	_ensure_size()
	if slot < 0 or slot >= slots.size():
		return
	slots[slot] = inst
	_after_stack_changed()


func get_best(n: int) -> Array[ItemInstance]:
	_ensure_size()
	var arr: Array[ItemInstance] = []
	for s in slots:
		if s != null and s.data != null:
			arr.append(s)

	arr.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return _score(a) > _score(b)
	)

	if arr.size() > n:
		arr.resize(n)
	return arr


func _after_stack_changed() -> void:
	# Merge any same-key stacks (eg r0 upgrading into existing r1)
	_consolidate_duplicates()
	_rebuild_index()
	emit_changed()
	_dbg_dump("after _after_stack_changed")


func _rebuild_index() -> void:
	_index.clear()
	_ensure_size()

	for i in range(slots.size()):
		var s: ItemInstance = slots[i]
		if s == null or s.data == null:
			continue
		var k := _key(s.data.id, s.rarity, s.polarity)
		if not _index.has(k):
			_index[k] = i


func _consolidate_duplicates() -> void:
	# Because merges/upgrades can change rarity (thus key), we repeat until stable.
	var did_merge := true
	while did_merge:
		did_merge = false

		var seen: Dictionary = {} # key -> slot index

		for i in range(slots.size()):
			var s: ItemInstance = slots[i]
			if s == null or s.data == null:
				continue

			var k := _key(s.data.id, s.rarity, s.polarity)

			if not seen.has(k):
				seen[k] = i
				continue

			var keep_i: int = int(seen[k])
			var keep: ItemInstance = slots[keep_i]

			# Safety
			if keep == null or keep == s:
				continue

			if debug_bag:
				print("[BAG] CONSOLIDATE key=", k, " merge slot", i, " -> ", keep_i)

			print("[BagInventory] EMIT stack_merged ", i, " -> ", keep_i, " bag_id=", get_instance_id())
			stack_merged.emit(i, keep_i, s) # UI ghost feedback

			_merge_into(keep, s)
			slots[i] = null

			did_merge = true
			break # restart pass (key/rarity might have changed)


func _key(item_id: String, _rarity: int, polarity: int) -> String:
	# NOTE: We intentionally IGNORE rarity in the key.
	# This makes stacks continue feeding even after they upgrade rarity.
	# Polarity stays part of the key so POS/NEG remain separate.
	var p := ("pos" if polarity >= 0 else "neg")
	return "%s|%s" % [item_id, p]

func _score(s: ItemInstance) -> float:
	if s == null:
		return -INF

	var meter: float = float(s.upgrade_meter)
	var best: float = absf(float(s.best_pct)) # strength regardless of polarity
	return float(s.rarity) * 100000.0 + meter * 1000.0 + best * 10.0


func add_instance(inst: ItemInstance) -> bool:
	if inst == null or inst.data == null:
		return false

	_ensure_size()
	_rebuild_index()

	# If this exact instance is already in slots, do nothing (prevents self-merge bugs)
	for i in range(slots.size()):
		if slots[i] == inst:
			_dbg_dump("after add_instance (already in slots)")
			return true

	var key: String = _key(inst.data.id, inst.rarity, inst.polarity)

	# Merge into existing stack (THIS is the case that "looks like it disappears")
	if _index.has(key):
		var idx: int = int(_index[key])
		var dest: ItemInstance = slots[idx]

		if dest == inst:
			_dbg_dump("after add_instance (dest==inst)")
			return true

		if dest != null:
			var old_rarity: int = int(dest.rarity)

			_merge_into(dest, inst) # consumes inst into dest
			_after_stack_changed()

			var upgraded: bool = (int(dest.rarity) != old_rarity)

			# This is just a hint value for UI/debug (not a real single roll)
			var roll_hint: float = float(inst.active_pct() if inst != null else 0.0)

			print("[BagInventory] stack_fed slot=", idx, " id=", dest.data.id, " upgraded=", upgraded)
			stack_fed.emit(idx, dest, roll_hint, upgraded, old_rarity)

			_dbg_dump("after add_instance (merged into existing)")
			return true

	# Need new slot
	var empty: int = first_empty_slot()
	if empty == -1:
		return false

	slots[empty] = inst
	_after_stack_changed()

	print("[BagInventory] stack_added slot=", empty, " id=", inst.data.id)
	stack_added.emit(empty, inst)

	_dbg_dump("after add_instance (placed in empty)")
	return true


func _merge_into(dest: ItemInstance, src: ItemInstance) -> void:
	if dest == null or src == null:
		return
	if dest == src:
		return # IMPORTANT: prevent doubling meter/progress by self-merge


	# Carry over higher rarity (so merging two stacks never "loses" tier).
	if int(src.rarity) > int(dest.rarity):
		dest.rarity = int(src.rarity)
		dest._recompute_flat_mods()
	# Merge state (preserve the best values + meters)
	dest.progress += src.progress

	dest.upgrade_meter += src.upgrade_meter
	while dest.upgrade_meter >= 1.0:
		dest.upgrade_meter -= 1.0
		dest._upgrade()

	# polarity is part of the key, so dest/src should match polarity
	if dest.polarity == ItemInstance.Polarity.POS:
		dest.best_pct = maxf(dest.best_pct, src.best_pct)
	else:
		dest.best_pct = minf(dest.best_pct, src.best_pct)

	# Safety: if someone stored upgrade_meter in properties, normalize it
	var dmv2: Variant = dest.get("upgrade_meter")
	if (dmv2 is float or dmv2 is int):
		var m: float = float(dmv2)
		while m >= 1.0:
			m -= 1.0
			dest._upgrade()
		dest.set("upgrade_meter", m)


func add_roll(item_data: ItemData, rarity: int, polarity: int, roll_pct: float) -> bool:
	if item_data == null:
		return false

	_ensure_size()
	_rebuild_index()

	var key := _key(item_data.id, rarity, polarity)

	# Existing stack? -> FEED
	if _index.has(key):
		var idx: int = int(_index[key])
		var stack: ItemInstance = slots[idx]
		if stack != null:
			var old_r: int = int(stack.rarity)

			# If future systems pass a higher rarity roll, carry it into the existing stack.
			if int(rarity) > int(stack.rarity):
				stack.rarity = int(rarity)
				stack._recompute_flat_mods()
			if debug_bag:
				print("[BagInventory] FEED roll into slot=", idx, " id=", item_data.id, " r=", rarity, " pol=", polarity, " roll=", roll_pct)

			stack.feed_roll(roll_pct)
			var upgraded: bool = int(stack.rarity) > old_r

			_after_stack_changed()

			# Tell UI to play “feed” VFX
			stack_fed.emit(idx, stack, roll_pct, upgraded, old_r)
			return true

	# Need new slot -> ADD
	var empty: int = first_empty_slot()
	if empty == -1:
		return false

	var inst: ItemInstance = ItemInstance.from_roll(item_data, rarity, polarity, roll_pct)
	slots[empty] = inst

	_after_stack_changed()

	if debug_bag:
		print("[BagInventory] ADD new stack slot=", empty, " id=", item_data.id, " r=", rarity, " pol=", polarity)

	# Tell UI to play “added” VFX
	stack_added.emit(empty, inst)
	return true


func find_best_slot_for_equip_slot(equip_slot: int) -> int:
	_ensure_size()

	var best_i := -1
	var best_score := -INF

	for i in range(slots.size()):
		var s: ItemInstance = slots[i]
		if s == null or s.data == null:
			continue
		if s.data.equip_slot != equip_slot:
			continue

		var sc := _score(s)
		if sc > best_score:
			best_score = sc
			best_i = i

	return best_i
