extends RefCounted
class_name EnemyInit

var _owner: Enemy = null

var _drops: EnemyDrops = null
var _senses: EnemySenses = null
var _leech: EnemyLeech = null
var _herald: EnemyHerald = null
var _tactical: EnemyTactical = null
var _charge: EnemyCharge = null
var _shooter: EnemyShooter = null
var _life: EnemyLifecycle = null

func setup(
	owner: Enemy,
	drops: EnemyDrops,
	senses: EnemySenses,
	leech: EnemyLeech,
	herald: EnemyHerald,
	tactical: EnemyTactical,
	charge: EnemyCharge,
	shooter: EnemyShooter,
	life: EnemyLifecycle
) -> void:
	_owner = owner
	_drops = drops
	_senses = senses
	_leech = leech
	_herald = herald
	_tactical = tactical
	_charge = charge
	_shooter = shooter
	_life = life


func boot() -> void:
	if _owner == null:
		return

	_apply_spec_if_any()
	_apply_threat_scaling()

	_owner.hp = _owner.max_hp
	_owner.add_to_group("enemies")

	_owner.player = _owner.get_tree().get_first_node_in_group("player") as Node2D

	_apply_visuals()
	_wire_hitbox()

	# Modules
	if _drops != null:
		_drops.setup(_owner)
		_drops.build_drop_pool()

	if _senses != null:
		_senses.setup(_owner)

	if _leech != null:
		_leech.setup(_owner)

	if _herald != null:
		_herald.setup(_owner)

	if _tactical != null:
		_tactical.setup(_owner)

	if _charge != null:
		_charge.setup(_owner)

	if _shooter != null:
		_shooter.setup(_owner)

	# Lifecycle (bomber/splitter are optional in your lifecycle, so null is fine)
	if _life != null:
		_life.setup(_owner, _drops, null, null)

	# seeds / baseline
	_owner._base_speed = _owner.speed
	_owner._orbit_angle = Global._rng.randf() * TAU


func _apply_spec_if_any() -> void:
	if _owner.spec == null:
		return

	var s := _owner.spec
	_owner.speed = s.speed
	_owner.max_hp = s.max_hp
	_owner.knockback_decay = s.knockback_decay

	_owner.item_pickup_scene = s.item_pickup_scene
	_owner.drop_chance = s.drop_chance
	_owner.drop_pool_prefixes = s.drop_pool_prefixes
	_owner.drop_fallback_to_all = s.drop_fallback_to_all
	_owner.drop_amount_min = s.drop_amount_min
	_owner.drop_amount_max = s.drop_amount_max
	_owner.drop_instance_roll = s.drop_instance_roll
	_owner.drop_rarity_min = s.drop_rarity_min
	_owner.drop_rarity_max = s.drop_rarity_max
	_owner.drop_force_polarity = s.drop_force_polarity
	_owner.pickup_delay = s.pickup_delay
	_owner.drop_spawn_radius = s.drop_spawn_radius


func _apply_visuals() -> void:
	if _owner.spec == null:
		return

	var spr: Sprite2D = _owner.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var s := _owner.spec
	if s.sprite_texture != null:
		spr.texture = s.sprite_texture
	spr.scale = s.sprite_scale
	spr.modulate = s.sprite_modulate


func _wire_hitbox() -> void:
	var hb: Area2D = _owner.get_node_or_null("Hitbox") as Area2D
	if hb == null:
		return

	hb.add_to_group("enemy_hitbox")

	if not hb.area_entered.is_connected(_owner._on_hitbox_area_entered):
		hb.area_entered.connect(_owner._on_hitbox_area_entered)
	if not hb.area_exited.is_connected(_owner._on_hitbox_area_exited):
		hb.area_exited.connect(_owner._on_hitbox_area_exited)

func _apply_threat_scaling() -> void:
	if _owner == null or not is_instance_valid(_owner):
		return
	if _owner.has_meta("_threat_scaled") and bool(_owner.get_meta("_threat_scaled")):
		return
	var td := _owner.get_node_or_null("/root/ThreatDirector") as ThreatDirectorSingleton
	if td == null:
		return
	_owner.max_hp *= td.enemy_hp_mul
	_owner.speed *= td.enemy_speed_mul
	_owner.set_meta("_threat_scaled", true)
