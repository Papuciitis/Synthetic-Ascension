extends Resource
class_name AugmentData

@export var id: StringName

@export var display_name: String = "Augment"
@export_multiline var description: String = ""

# Short text used on the selection card (the gray box).
# Keep it ~1–2 lines. Full explanation + numbers go in `description` + `details`.
@export_multiline var card_blurb: String = ""
@export_multiline var details: String = ""
@export var icon: Texture2D

# Optional stat changes (uses your existing StatDelta)
@export var mods: StatDelta = null

# If > 0, the StatDelta `mods` scales by (1 + mods_scale_per_level * (level-1)).
@export var mods_scale_per_level: float = 0.0

# Optional: grants a spell into a spell slot
@export var grant_spell_id: StringName = &""

@export var effect_scenes: Array[PackedScene] = []

func apply_to_stats(s: Stats) -> void:
	if mods != null:
		mods.apply_to(s)

func apply_to_stats_at_level(s: Stats, level: int) -> void:
	if mods == null:
		return
	var lvl: int = maxi(1, level)
	if mods_scale_per_level <= 0.0 or lvl <= 1:
		mods.apply_to(s)
		return

	var mul: float = 1.0 + (mods_scale_per_level * float(lvl - 1))
	var m: StatDelta = mods.copy()
	m.max_hp *= mul
	m.armor *= mul
	m.move_speed *= mul
	m.power *= mul
	m.haste *= mul
	m.luck *= mul
	m.apply_to(s)
