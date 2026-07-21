extends RefCounted
class_name HitLedger

## One target's compatible hits for one physics frame. Chance-based effects and
## criticals are resolved before they enter the ledger; this object aggregates
## their resolved outcomes rather than rerolling them.

var target: Node = null
var source: Node = null
var total_raw_damage: float = 0.0
var hit_count: int = 0
var critical_hits: int = 0
var knockback: Vector2 = Vector2.ZERO
var burn_stacks: int = 0
var burn_duration: float = 0.0
var burn_tick: float = 0.5
var burn_damage_per_tick_per_stack: float = 0.0
var tags: PackedStringArray = PackedStringArray()

func add_resolved_hit(damage: float, source_node: Node, knockback_force: Vector2, was_critical: bool, burn_stack_count: int, burn_time: float, burn_interval: float, burn_damage: float) -> void:
	total_raw_damage += maxf(0.0, damage)
	hit_count += 1
	if was_critical:
		critical_hits += 1
	if source == null and source_node != null and is_instance_valid(source_node):
		source = source_node
	knockback += knockback_force
	# BurnDot already uses max-stack + duration refresh semantics. Same-frame
	# batching deliberately preserves that instead of multiplying stacks/pellet.
	burn_stacks = maxi(burn_stacks, burn_stack_count)
	burn_duration = maxf(burn_duration, burn_time)
	if burn_interval > 0.0:
		burn_tick = minf(burn_tick, burn_interval)
	burn_damage_per_tick_per_stack = maxf(burn_damage_per_tick_per_stack, burn_damage)

func clamped_knockback(max_force: float = 900.0) -> Vector2:
	return knockback.limit_length(maxf(0.0, max_force))

