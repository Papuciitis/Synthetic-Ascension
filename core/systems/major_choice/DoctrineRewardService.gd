extends RefCounted
class_name DoctrineRewardService


static func grant_secondary_roll(g: Node, source_key: StringName, roll_index: int) -> bool:
	if g == null or source_key == StringName():
		return false
	var item_db: Dictionary = g.get("item_db")
	var item_ids: Array = item_db.keys()
	item_ids.sort()
	if item_ids.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	var world_seed := int(g.get("attempt_world_seed"))
	var segment := maxi(1, int(g.get("attempt_segment")))
	rng.seed = world_seed ^ int(String(source_key).hash()) ^ (roll_index * 0x9E3779B9)
	var item_id := str(item_ids[rng.randi_range(0, item_ids.size() - 1)])
	var data := item_db.get(item_id, null) as ItemData
	if data == null:
		return false
	var rarity := clampi(floori(float(segment) / 2.0), 1, 5)
	var instance := ItemInstance.from_roll(
		data,
		rarity,
		ItemInstance.Polarity.POS,
		0.35,
		false
	)
	return g.has_method("deliver_guaranteed_item") and bool(g.call("deliver_guaranteed_item", instance, false))
