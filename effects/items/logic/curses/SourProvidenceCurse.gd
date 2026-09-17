extends Node2D

## Sour Providence - a curse shaped like a LOOT-TABLE TAX.
##
## It does nothing to you at all. It curses the world's generosity instead:
## while it is worn, items you find are far likelier to come out cursed.
##
## This is the one curse that is openly a blessing to somebody. To an ordinary
## build it poisons the drop table; to a Corruption or Doctrine build it is a
## supply line, because cursed items are the resource those archetypes eat. A
## NEG pool where every entry is bad for everyone teaches the player to ignore
## the pool - one entry that is a prize recalibrates how they read all of it.

## How far the polarity coin is pushed toward NEG, before the item's own
## severity scales it.
const BIAS_STRENGTH: float = 0.55

var player: Node = null
var item: ItemInstance = null
var slot_index: int = -1

var _applied: float = 0.0


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Items you find are far likelier to be cursed (bias %d%%)." % int(round(bias(inst) * 100.0)))
	out.append("Ruins an ordinary run's loot. Feeds a curse build.")
	return out


func bias(inst: ItemInstance) -> float:
	var severity: float = absf(inst.active_pct()) if inst != null else 0.5
	return BIAS_STRENGTH * (0.5 + severity)


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p
	item = inst
	slot_index = slot
	_publish()


func set_item_instance(inst: ItemInstance) -> void:
	item = inst
	_publish()


func _publish() -> void:
	if Global == null:
		return
	# Additive and self-unwinding, so two of these stack and either can be
	# removed first without stranding the other's contribution.
	var wanted := bias(item)
	Global.curse_drop_bias += wanted - _applied
	_applied = wanted


func _exit_tree() -> void:
	if Global != null:
		Global.curse_drop_bias -= _applied
	_applied = 0.0
