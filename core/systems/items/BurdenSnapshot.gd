extends RefCounted
class_name BurdenSnapshot

## One authoritative reading of what the player's curses currently mean.
##
## Several NEG archetypes value the same cursed loot for opposite reasons -
## concentrated severity, sheer count, exact parity, one suppressed horror - and
## each computing its own totals is how they quietly disagree about the same
## item. They all read this instead.
##
## The distinction that makes the ecosystem work:
##
##   POLARITY is what an item intrinsically IS. It never changes, and it is what
##   parity, sets and acquisition rewards count.
##
##   ACTIVE BURDEN is how much curse is presently affecting the player. An
##   Inversion Lens suppresses one item's burden to zero without making it any
##   less NEG - so the item still counts for parity while feeding nothing that
##   eats severity.

## A curse milder than this is flavour, not a burden. Without a floor, an item
## that rolled -0.4% would qualify a count-based build for free.
const QUALIFYING_BURDEN: float = 0.10

## slot -> { item, severity, active, suppressed }
var entries: Dictionary = {}

## Equipped slot whose burden is suppressed, or -1.
var suppressed_slot: int = -1

## What the suppressed item's severity was before it was suppressed.
var suppressed_severity: float = 0.0

## Items by polarity, ignoring suppression entirely - this is the parity and
## acquisition reading.
var neg_count: int = 0
var pos_count: int = 0

## Curses actually weighing on the player right now.
var active_count: int = 0
var qualifying_count: int = 0
var total_active: float = 0.0

## Descending active severities, so an archetype that wants the worst N can just
## take the first N.
var severities: Array[float] = []


func heaviest(count: int = 1) -> float:
	var total := 0.0
	for i in range(mini(count, severities.size())):
		total += severities[i]
	return total


func is_suppressed(slot: int) -> bool:
	return slot == suppressed_slot


func severity_at(slot: int) -> float:
	var entry: Variant = entries.get(slot, null)
	return float((entry as Dictionary)["severity"]) if entry is Dictionary else 0.0


func active_at(slot: int) -> float:
	var entry: Variant = entries.get(slot, null)
	return float((entry as Dictionary)["active"]) if entry is Dictionary else 0.0


## Exact POS/NEG parity, for archetypes that reward balance.
func is_balanced() -> bool:
	return neg_count > 0 and neg_count == pos_count
