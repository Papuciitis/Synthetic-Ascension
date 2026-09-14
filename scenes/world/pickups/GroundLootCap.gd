extends RefCounted
class_name GroundLootCap
## Keeps the number of ordinary drops on the ground bounded.
##
## A kill chain drops an item for a share of its victims, every pickup is a
## small node cluster with its own _process, and item drops live two
## minutes: a long segment with chains ended with hundreds of pickups and
## the 2026-09-15 capture at 5,400 nodes with 24 enemies. When a new drop
## arrives past the cap, the least valuable of the oldest ordinary drops
## leaves; exploration loot and things the player put down never do.

const ITEM_GROUP: StringName = &"ground_item_pickups"
const HEALTH_GROUP: StringName = &"ground_health_pickups"
const ITEM_CAP := 48
const HEALTH_CAP := 20

static var _serial: int = 0


static func next_serial() -> int:
	_serial += 1
	return _serial


## Frees the surplus so that at most `cap` members of `group` remain,
## counting `newcomer` (which is never removed). Returns how many left.
static func enforce(tree: SceneTree, group: StringName, cap: int, newcomer: Node) -> int:
	if tree == null:
		return 0
	var live := 0
	var candidates: Array = []
	for member in tree.get_nodes_in_group(group):
		# Nodes culled a moment ago are still in the group until the frame
		# ends; counting them would cull again for every newcomer.
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		live += 1
		if member == newcomer:
			continue
		if _flag(member, "is_exploration_loot") or _flag(member, "persistent_world_drop") or _flag(member, "_picked"):
			continue
		candidates.append(member)
	var surplus := live - cap
	if surplus <= 0 or candidates.is_empty():
		return 0
	# Lowest rarity first, then oldest first.
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		var ra := _rarity_of(a)
		var rb := _rarity_of(b)
		if ra != rb:
			return ra < rb
		return int(a.get("ground_serial")) < int(b.get("ground_serial")))
	var removed := 0
	for candidate in candidates:
		if removed >= surplus:
			break
		candidate.queue_free()
		removed += 1
	return removed


## A property that may not exist on every pickup kind reads as false.
static func _flag(node: Node, property: String) -> bool:
	var value: Variant = node.get(property)
	return value != null and bool(value)


static func _rarity_of(node: Node) -> int:
	var instance: Variant = node.get("item_instance")
	if instance != null and instance is Object and (instance as Object).get("rarity") != null:
		return int((instance as Object).get("rarity"))
	return 0
