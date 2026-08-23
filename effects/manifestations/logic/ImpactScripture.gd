extends ManifestationEffect

## Impact Scripture - the defensive CONSUMER of the shared `momentum` resource.
##
## Sunder Wake spends Momentum where your attack lands; this spends it where you
## are standing, when something connects with you. Rolled together they fight
## over the same pool, and that friction is the point.

const VFX_TEAR := preload("res://assets/vfx/world/manifestations/VFX_SunderTear.gd")

# The world is authored on a 32 px grid (VisionRig.cell_size_px).
const PIXELS_PER_METRE: float = 32.0

const MOMENTUM_FLOOR: float = 0.20

## Contact damage arrives on a per-frame loop, so without a floor this rule
## would detonate every frame a body is touching the player. Its own floor is
## longer than the shared ward gate because a Momentum-fuelled blast is a much
## bigger event than an evade nova.
const COOLDOWN: float = 0.35

# Wider and far pushier than Sunder Wake, weaker per target: this is armour
# buying the player space to leave, not a ranged burst.
const RADIUS_MIN: float = 84.0
const RADIUS_MAX: float = 204.0
const DAMAGE_MULT: float = 1.15
const KNOCKBACK: float = 640.0
const RADIUS_POTENCY_SHARE: float = 0.5

const BLAST_TINT := Color(0.72, 0.42, 1.0, 1.0)

var _cd: float = 0.0


func _on_manifestation_ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)


func on_damage_taken(_amount: float, _position: Vector2) -> void:
	if _cd > 0.0:
		return
	if state == null or not is_instance_valid(state):
		return
	# Shared ward gate first: one hit gets one answer across every ward rule.
	if not state.try_retaliate():
		return
	if state.momentum < MOMENTUM_FLOOR:
		return

	_cd = COOLDOWN
	var spent: float = state.consume_momentum()
	# Centred on the player, not on where the hit landed: the promise is "the
	# space around me clears", which has to be true for a hit from any angle.
	var center: Vector2 = player_position()
	var radius: float = lerpf(RADIUS_MIN, RADIUS_MAX, spent) * _radius_potency()
	damage_radius(center, radius, attack_damage(DAMAGE_MULT * spent * potency()), KNOCKBACK * spent)
	_spawn_blast(center, radius, spent)
	popup("SCRIPTURE", Color(0.80, 0.55, 1.0, 1.0), 1.2)


func _radius_potency() -> float:
	return 1.0 + (potency() - 1.0) * RADIUS_POTENCY_SHARE


func _spawn_blast(center: Vector2, radius: float, spent: float) -> void:
	var blast := VFX_TEAR.new() as Node2D
	if blast == null:
		return
	blast.call(&"setup", radius, spent, BLAST_TINT)
	spawn_world_node(blast, center)


func describe() -> String:
	return "Taking a hit spends all Momentum (needs %d%%) and detonates it around you: up to a %.1f m blast for %d%% weapon damage, scaled by the Momentum spent. At most once every %.2fs." % [
		int(round(MOMENTUM_FLOOR * 100.0)),
		(RADIUS_MAX * _radius_potency()) / PIXELS_PER_METRE,
		int(round(DAMAGE_MULT * potency() * 100.0)),
		COOLDOWN,
	]
