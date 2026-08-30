extends RefCounted
class_name BurdenSnapshot

## One authoritative reading of what the player's curses currently mean.
##
## Several NEG archetypes value the same cursed loot for opposite reasons -
## concentrated severity, sheer count, exact parity, one suppressed horror - and
## each computing its own totals is how they quietly disagree about the same
## item. They all read this instead.
##
## Three distinct questions live here, and they must not be confused:
##
##   POLARITY CENSUS - how many equipped items are intrinsically POS or NEG.
##   Counts EVERY slot, accessories included, ignores suppression. This is
##   what the Run Sheet's BURDEN block and the BuildIdentity sentence read
##   (neg_count / pos_count); the item tooltip names it for an accessory or
##   a suppressed curse. Nothing else consumes it yet.
##
##   ACTIVE STAT BURDEN - how much statistical curse is presently weighing on
##   the player. Reasons about the statistical slots only (HP, Armour, Move,
##   Power, Haste, Luck); accessories whose roll drives scripted behaviour
##   never enter this arithmetic by accident. Corruption Engine, the Doctrine
##   and the Lens read this.
##
##   An Inversion Lens suppresses one statistical item's burden to zero without
##   making it any less NEG - so it still counts for the census while feeding
##   nothing that eats severity.

## A curse qualifies for count-based builds when it uses at least this
## fraction of its item's AUTHORED negative range. Relative, not absolute: a
## -2.1% roll on a 0..-20% item is a real burden, a -9% roll on a 0..-100%
## item is a scratch of what that item can do. Without a floor, a -0.4% roll
## would qualify a count-based build for free.
const QUALIFYING_BURDEN_RATIO: float = 0.10

## statistical slot -> { item, severity, ratio, active, suppressed, qualifies }
var entries: Dictionary = {}

## Statistical slot whose burden is suppressed, or -1.
var suppressed_slot: int = -1

## What the suppressed item's severity was before it was suppressed.
var suppressed_severity: float = 0.0

## Polarity census over every equipped slot, ignoring suppression entirely.
var neg_count: int = 0
var pos_count: int = 0

## Curses actually weighing on the player right now (statistical slots).
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


## Fraction of the item's authored negative range the curse uses (0..1).
func burden_ratio_at(slot: int) -> float:
	var entry: Variant = entries.get(slot, null)
	return float((entry as Dictionary)["ratio"]) if entry is Dictionary else 0.0


## Whether the slot's curse counts for the Doctrine: active AND meaningful
## relative to its own range. A suppressed curse never qualifies.
func qualifies(slot: int) -> bool:
	var entry: Variant = entries.get(slot, null)
	return bool((entry as Dictionary)["qualifies"]) if entry is Dictionary else false


## Exact POS/NEG parity, for archetypes that reward balance.
func is_balanced() -> bool:
	return neg_count > 0 and neg_count == pos_count
