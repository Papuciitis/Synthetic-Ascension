@tool
extends Resource
class_name EnemySpec

# IMPORTANT: add new AI values only at the END to avoid breaking existing saved ints.
enum AI {
	CHASE = 0,
	ORBIT = 1,
	RANGED = 2,
	CHARGE = 3,
	BOMBER = 4,
	SUMMONER = 5,
	SPLITTER = 6,
	TACTICAL = 7,
	LEECH = 8,
	HERALD = 9,
	SNIPER = 10,
}

@export var id: StringName = &"enemy_grunt"
@export var display_name: String = "Grunt"

@export_group("Core Stats")
@export var ai: AI = AI.CHASE
@export var max_hp: float = 10.0
@export var speed: float = 75.0
@export var knockback_decay: float = 2200.0

@export_group("Followers Reward")
@export var follower_reward_min: int = 1
@export var follower_reward_max: int = 1
@export var elite_follower_bonus: int = 3

@export_group("Orbit AI")
@export var orbit_radius: float = 150.0
@export var orbit_turn_speed: float = 2.0

@export_group("Ranged / Tactical Shooting")
@export var preferred_range: float = 240.0
@export var range_tolerance: float = 60.0
@export var shoot_every: float = 1.6
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 320.0
@export var projectile_damage: float = 5.0
@export var projectile_lifetime: float = 3.0
@export var strafe_strength: float = 0.8

@export_group("Charge AI")
@export var charge_trigger_range: float = 260.0
@export var charge_windup: float = 0.5
@export var charge_speed: float = 520.0
@export var charge_duration: float = 0.25
@export var charge_cooldown: float = 2.8

@export_group("Bomber AI")
@export var explode_trigger_distance: float = 70.0
@export var explode_radius: float = 100.0
@export var explode_damage: float = 12.0
@export var explode_on_death: bool = false

@export_group("Summoner AI")
@export var summon_every: float = 4.5
@export var summon_count_min: int = 1
@export var summon_count_max: int = 2
@export var summon_radius: float = 160.0
@export var summon_scene: PackedScene

@export_group("Splitter AI")
@export var split_scene: PackedScene
@export var split_count_min: int = 2
@export var split_count_max: int = 3
@export var split_inherit_elite: bool = false
@export var split_max_generation: int = 2
@export var split_second_count_min: int = 4
@export var split_second_count_max: int = 4
@export var split_base_scale: float = 2.0
@export var split_scale_per_generation: float = 0.5
@export var split_hp_per_generation: float = 0.45
@export var split_speed_per_generation: float = 1.55
@export var split_elite_extra_generations: int = 1
@export var split_elite_scale_mult: float = 2.0

@export_group("LEECH (Follower Sucker)")
@export var leech_every: float = 0.75
@export var leech_amount: int = 1

@export_group("TACTICAL (SWIT)")
@export_range(0.0, 1.0, 0.01) var retreat_hp_ratio: float = 0.35
@export var cover_seek_radius: float = 220.0
@export var cover_sample_points: int = 10
@export var cover_refresh: float = 0.6
@export var tactical_cover_mask: int = 0

@export_group("HERALD (Fear Beacon)")
@export var herald_pulse_every: float = 2.8
@export var herald_pulse_radius: float = 220.0
@export var herald_ally_speed_mult: float = 1.35
@export var herald_ally_speed_duration: float = 1.8
@export var herald_player_drain_followers: bool = true
@export var herald_player_drain_amount: int = 1

@export_group("Sniper (Line Shot)")
@export var sniper_range: float = 900.0
@export var sniper_windup: float = 0.9
@export var sniper_cooldown: float = 3.0
@export var sniper_damage: float = 14.0
@export var sniper_beam_length: float = 2200.0
@export var sniper_beam_width: float = 26.0
@export var sniper_move_mul_during_windup: float = 0.15

# Elite-only: how fast it can rotate while tracking during windup (radians/sec)
@export var sniper_track_turn_speed: float = 2.4


@export_group("Drops")
@export var item_pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.25
@export var drop_pool_prefixes: PackedStringArray = ["conduit_","lattice_","gravemarch_","acc_","ring_"]
@export var drop_fallback_to_all: bool = false
@export var drop_amount_min: int = 1
@export var drop_amount_max: int = 1
@export var drop_instance_roll: bool = true
@export var drop_rarity_min: int = 0
@export var drop_rarity_max: int = 0
@export var elite_rarity_bonus: int = 1
@export var drop_force_polarity: int = 0
@export var pickup_delay: float = 0.25
@export var drop_spawn_radius: float = 18.0

@export_group("Elite Upgrade")
@export var elite_hp_mult: float = 1.6
@export var elite_speed_mult: float = 1.15
@export var elite_tint: Color = Color(1.0, 0.85, 0.25, 1.0)
@export_range(0.0, 1.0, 0.001) var elite_spawn_chance_cap: float = 1.0
@export_enum(
	"Keep:-1",
	"CHASE:0",
	"ORBIT:1",
	"RANGED:2",
	"CHARGE:3",
	"BOMBER:4",
	"SUMMONER:5",
	"SPLITTER:6",
	"TACTICAL:7",
	"LEECH:8",
	"HERALD:9",
	"SNIPER:10"
) var elite_ai_override: int = -1

@export_group("Elite Modifiers")
# Roadmap §9: which EliteModifiers ids an elite of this archetype may carry,
# whether picked by phase or requested by a beat. Empty allow-list = all five;
# the deny-list wins. A splitting archetype never receives SPLITTING.
@export var elite_modifiers_allowed: Array[StringName] = []
@export var elite_modifiers_denied: Array[StringName] = []

@export_group("Visuals")
@export var sprite_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2.ONE
@export var sprite_modulate: Color = Color.WHITE
## Baked stride/idle frames from tools/bake_character_atlases.gd. When set the
## sprite shows one atlas region at a time and animates; sprite_texture should
## be that same atlas so anything reading the texture before init sees it.
@export var visual_frames: CharacterFrameSet
@export var animation_fps: float = 10.0
