extends Node2D
class_name ManifestationEffect

## Base class for one curated Manifestation rule.
##
## ManifestationRunner owns the signal wiring: it connects to each shared
## gameplay hook exactly once and dispatches to whichever effects implement
## the matching `on_*` method. Subclasses therefore never touch RunEvents;
## they just implement the hooks they care about.
##
## Optional hooks a subclass may implement:
##   on_attack(style_id: StringName, origin: Vector2, target: Vector2,
##             power_mul: float, haste_mul: float) -> void
##   on_lucky_crit(at: Vector2) -> void
##   on_lucky_crit_failed() -> void
##   on_hit(handle: int, at: Vector2, amount: float,
##          is_crit: bool, is_elite: bool) -> void
##   on_kill(context: EnemyDeathContext) -> void
##   on_damage_taken(amount: float, at: Vector2) -> void
##   on_evaded(at: Vector2) -> void
##   on_dash(from: Vector2, direction: Vector2) -> void
##   on_healed(amount: float) -> void
##   on_building_entered(first_visit: bool) -> void
##   on_secondary_completed(objective_id: int) -> void
##   on_followers_changed(change: int, reason: StringName) -> void
##   on_gate_ready() -> void
##
## Optional passive contributions polled by the runner:
##   get_power_multiplier() / get_haste_multiplier()
##   get_move_speed_multiplier() / get_damage_taken_multiplier()
##   get_bonus_evasion_chance() -> float
##   apply_to_stats(s: Stats) -> void
##   consume_attack_bonus() -> float   (one-shot, consumed by the next attack)

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1
var state: ManifestationState = null
var definition: ManifestationDef = null


func setup_manifestation(
	p: Node,
	inst: ItemInstance,
	slot: int,
	shared: ManifestationState,
	def: ManifestationDef
) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot
	state = shared
	definition = def
	_on_manifestation_ready()


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


## Override for setup that needs `player`/`state`, which are null in _ready().
func _on_manifestation_ready() -> void:
	pass


# ---------------------------------------------------------------------------
# Scaling
#
# Design rule: rarity GROWS the item, not the rule. Getting the Manifestation
# is the reward; an R20 proc must never become the whole build by itself. So
# potency is a shallow, hard-capped curve and requirements ease only slightly.
# ---------------------------------------------------------------------------

const POTENCY_PER_RANK: float = 0.045
const POTENCY_CAP: float = 1.60
const THRESHOLD_EASE_PER_RANK: float = 0.020
const THRESHOLD_FLOOR: float = 0.78


func effective_rarity() -> float:
	if item == null:
		return 0.0
	return float(item.rarity) + clampf(item.upgrade_meter, 0.0, 0.999999)


func potency() -> float:
	return clampf(1.0 + POTENCY_PER_RANK * effective_rarity(), 1.0, POTENCY_CAP)


func threshold_scale() -> float:
	return clampf(1.0 - THRESHOLD_EASE_PER_RANK * effective_rarity(), THRESHOLD_FLOOR, 1.0)


## Human-readable rule with this instance's real numbers in it. Subclasses
## should override; the default falls back to the catalog's authored line.
func describe() -> String:
	return definition.rule if definition != null else ""


func manifestation_id() -> StringName:
	return definition.id if definition != null else &""


## Identity for the shared-number ledger. Slot-suffixed, because two items can
## legitimately carry the same rule and each must contribute independently.
func contribution_key() -> StringName:
	return StringName("%s#%d" % [String(manifestation_id()), slot_index])


func tags() -> Array[StringName]:
	return definition.tags if definition != null else ([] as Array[StringName])


## The noun this rule displays as, when only one can be shown.
func primary_tag() -> StringName:
	return definition.primary_tag() if definition != null else &""


## Identity colour for this rule's noun, from ManifestationNouns.
##
## Overlays paint their DOMINANT hue with this so a glow on the player reads as
## "that is a shard thing" without the player having to open a panel. Only the
## dominant hue: the accents, the payout flashes and the hot cores stay
## authored, because recolouring every draw call would flatten fourteen
## hand-drawn overlays into one.
##
## `noun` is optional so a two-tag rule whose overlay depicts its SECOND noun
## can name it rather than lying about which one it is painting.
func noun_colour(noun: StringName = &"") -> Color:
	return ManifestationNouns.colour(noun if noun != &"" else primary_tag())


# ---------------------------------------------------------------------------
# Shared conveniences
# ---------------------------------------------------------------------------

func player_position() -> Vector2:
	if player != null and is_instance_valid(player):
		return player.global_position
	return global_position


func player_hp_fraction() -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var hp: Variant = player.get("hp")
	var max_hp: Variant = player.get("max_hp")
	if (hp is float or hp is int) and (max_hp is float or max_hp is int) and float(max_hp) > 0.0:
		return clampf(float(hp) / float(max_hp), 0.0, 1.0)
	return 1.0


func attack_damage(multiplier: float) -> float:
	if state != null:
		return state.scaled_attack_damage(multiplier)
	return 12.0 * multiplier


func damage_radius(center: Vector2, radius: float, damage: float, knockback: float = 0.0) -> int:
	if state == null:
		return 0
	return state.damage_radius(center, radius, damage, knockback)


func aim_direction() -> Vector2:
	if state != null:
		return state.aim_direction()
	return Vector2.RIGHT


## Fire the player's own attack again at `target`. Used by rules that say
## "your next attack fires twice" / "echoes"; mirrors how the Lattice set
## re-enters the player's spawn helpers.
func repeat_player_attack(style_id: StringName, target: Vector2, damage_multiplier: float = 1.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	var damage := attack_damage(damage_multiplier)
	# An echo is a real attack for rhythm purposes. This one line is what makes
	# cadence a shared WRITE rather than a shared read: Martyr Circuit's
	# death-door echoes carry Third Litany's litany forward.
	if state != null and is_instance_valid(state):
		state.note_attack()
	match style_id:
		&"melee":
			if player.has_method("_spawn_melee"):
				player.call("_spawn_melee", target, damage * 1.25)
		&"magic":
			if player.has_method("_spawn_magic"):
				player.call("_spawn_magic", target, damage * 1.15)
		_:
			if player.has_method("_spawn_ranged"):
				player.call("_spawn_ranged", target, damage)


func spawn_world_node(node: Node2D, world_position: Vector2) -> Node2D:
	if node == null:
		return null
	# The state outlives any individual rule, so it owns the spawn. Rules that
	# run detached (the tooltip path) fall through to the local version.
	if state != null and is_instance_valid(state):
		return state.spawn_world_node(node, world_position)
	var host: Node = get_tree().current_scene if get_tree() != null else null
	if host == null:
		node.queue_free()
		return null
	host.add_child(node)
	node.global_position = world_position
	return node


## `merge_key` is opt-in, for a rule that can fire the SAME line several times a
## second: passing `int(get_instance_id())` makes it replace its own line rather
## than stack. Leave it at 0 when a rule's lines say different things, or the
## payout would swallow the callout that announced it.
func popup(text: String, color: Color, scale_in: float = 1.15, merge_key: int = 0) -> void:
	if BattleText == null:
		return
	# Staggered, so a kill that trips four rules at once reads as four lines
	# rather than one blur. Deliberately NOT a merge: the lines are different
	# rules saying different things and all four are worth reading.
	var at := player_position()
	if state != null and is_instance_valid(state):
		at += state.next_popup_offset()
	BattleText.popup(at, text, color, scale_in, merge_key)
