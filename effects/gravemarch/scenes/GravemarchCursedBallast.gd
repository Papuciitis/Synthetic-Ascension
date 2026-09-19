extends SetEffectBase
class_name GravemarchCursedBallast

## Cursed Ballast Frame (NEG archetype A6): with three or more equipped
## Gravemarch pieces NEG, the two-piece armour grant is replaced by this
## life-drain aura. Its radius grows with the combined active severity of
## those cursed pieces (a secondary characteristic, never raw damage);
## the drain is a share of the player's max HP per second, spread over
## every enemy in reach, and a share of what it takes comes back as
## healing. SetRunner adds and removes it with the census.

@export var tick_seconds: float = 0.5
@export var drain_share_of_max_hp_per_second: float = 0.02
@export var heal_share: float = 0.30
@export var base_radius: float = 120.0
@export var radius_per_severity: float = 160.0
@export var radius_cap: float = 400.0
## The drain is per enemy, so a crowd would make it a heal engine: at
## most this many enemies' worth of drain per tick, and the healing never
## exceeds this share of max HP per second.
@export var drain_targets_cap: int = 8
@export var heal_cap_share_of_max_hp_per_second: float = 0.04

var _tick: float = 0.0
var _handles: Array[int] = []


func _init() -> void:
	effect_id = &"gravemarch_2_cursed_ballast"


func severity_sum() -> float:
	if Global == null or Global.run_inventory == null:
		return 0.0
	var burden: BurdenSnapshot = (player.get("last_burden") as BurdenSnapshot) if player != null else null
	var total := 0.0
	for slot in range(Inventory.STAT_SLOT_COUNT):
		var it: ItemInstance = Global.run_inventory.get_at(slot)
		if it == null or it.data == null or StringName(it.data.set_id) != &"gravemarch" or int(it.polarity) != ItemInstance.Polarity.NEG:
			continue
		total += burden.active_at(slot) if burden != null and burden.entries.has(slot) else absf(it.active_pct())
	return total


func radius() -> float:
	return clampf(base_radius + radius_per_severity * severity_sum() / float(BurdenResolver.GRAVEMARCH_CURSE_MIN_PIECES), base_radius, radius_cap)


func _process(dt: float) -> void:
	_tick += dt
	while _tick >= tick_seconds:
		_tick -= tick_seconds
		pulse(tick_seconds)


func pulse(seconds: float) -> float:
	var p2 := player as Node2D
	if p2 == null:
		return 0.0
	var max_hp: float = float(player.get("max_hp"))
	if max_hp <= 0.0:
		max_hp = 100.0
	var drain := drain_share_of_max_hp_per_second * max_hp * seconds
	EnemyCombat.gather_in_radius(p2.global_position, radius(), _handles)
	var dealt := 0.0
	var drained := 0
	for handle in _handles:
		if drained >= drain_targets_cap:
			break
		dealt += float(EnemyCombat.apply_damage(handle, drain, 1, player, balance_provenance("cursed_ballast")))
		drained += 1
	if dealt > 0.0 and player.has_method("heal"):
		player.call("heal", minf(dealt * heal_share, heal_cap_share_of_max_hp_per_second * max_hp * seconds), &"cursed_ballast")
	return dealt
