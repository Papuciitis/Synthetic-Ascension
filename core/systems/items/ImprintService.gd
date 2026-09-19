extends RefCounted
class_name ImprintService

## The Hub's imprinter: a held Manifestation imprint (a rule a merge
## dissolved) onto a worn or bagged item of a slot the rule allows, for
## Followers. The rule the item carried goes back into the pouch, so a
## build can change its mind at the Hub without ever losing a rule; between
## Hubs the copy you wear is the one you committed to.
## Precedent: Diablo IV's Codex of Power (a legendary power extracted from
## the item and imprinted at a station) and Risk of Rain 2's scrap (the
## player chooses what is sacrificed).

const PRICE_SHARE := 0.25
const PRICE_MIN := 20


static func price(inst: ItemInstance) -> int:
	if inst == null or Global == null:
		return PRICE_MIN
	return maxi(PRICE_MIN, int(round(float(Global.compute_item_value(inst)) * PRICE_SHARE)))


static func can_apply(imprint_id: StringName, inst: ItemInstance) -> Dictionary:
	if Global == null:
		return {"ok": false, "reason": "no run"}
	var def := ManifestationCatalog.get_def(imprint_id)
	if def == null:
		return {"ok": false, "reason": "unknown rule"}
	if not Global.attempt_imprints.has(imprint_id):
		return {"ok": false, "reason": "not held"}
	if inst == null or inst.data == null:
		return {"ok": false, "reason": "no item"}
	if inst.locked:
		return {"ok": false, "reason": "item locked"}
	if not def.allows_slot(int(inst.data.equip_slot)):
		return {"ok": false, "reason": "wrong slot"}
	if inst.manifestation_id == imprint_id:
		return {"ok": false, "reason": "already carries it"}
	var cost := price(inst)
	if int(Global.followers) < cost:
		return {"ok": false, "reason": "%d Followers needed" % cost}
	return {"ok": true, "reason": "", "price": cost}


## Applies the imprint. Returns {ok, reason, replaced, price}.
static func apply(imprint_id: StringName, inst: ItemInstance) -> Dictionary:
	var verdict := can_apply(imprint_id, inst)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "reason": String(verdict.get("reason", "")), "replaced": &"", "price": 0}
	var cost := int(verdict.get("price", 0))
	var replaced: StringName = inst.manifestation_id
	Global.transaction_followers(-cost, &"imprint", {"item_id": String(inst.data.id), "imprint": String(imprint_id), "replaced": String(replaced)}, true, false)
	Global.take_imprint(imprint_id)
	inst.manifestation_id = imprint_id
	if replaced != &"":
		Global.store_imprint(replaced)
	if RunEvents != null:
		RunEvents.imprint_applied.emit(inst, imprint_id, replaced)
		RunEvents.item_operation.emit(&"imprinted", inst, {"imprint": String(imprint_id), "replaced": String(replaced), "price": cost, "source": "hub"})
	Global.request_autosave()
	return {"ok": true, "reason": "", "replaced": replaced, "price": cost}


static func discard(imprint_id: StringName) -> bool:
	return Global != null and Global.take_imprint(imprint_id)


## Every item the player carries that the imprint could go onto, with the
## verdict for each: [{inst, where, slot, ok, reason, price}].
static func candidates(imprint_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Global == null:
		return out
	if Global.run_inventory != null:
		for slot in range(Inventory.SLOT_COUNT):
			var worn: ItemInstance = Global.run_inventory.get_at(slot)
			if worn != null and worn.data != null:
				out.append(_candidate(imprint_id, worn, "worn", slot))
	if Global.run_bag != null:
		for slot in range(Global.run_bag.get_slot_count()):
			var bagged: ItemInstance = Global.run_bag.get_at(slot)
			if bagged != null and bagged.data != null:
				out.append(_candidate(imprint_id, bagged, "bag", slot))
	return out


static func _candidate(imprint_id: StringName, inst: ItemInstance, where: String, slot: int) -> Dictionary:
	var verdict := can_apply(imprint_id, inst)
	return {"inst": inst, "where": where, "slot": slot, "ok": bool(verdict.get("ok", false)), "reason": String(verdict.get("reason", "")), "price": price(inst)}
