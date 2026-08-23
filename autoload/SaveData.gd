extends Resource
class_name SaveData

@export var slot_index: int = 0
@export var profile_name: String = "New Profile"
@export var mortal_name: String = "The Arcanist"

# Meta/progression (keep it minimal for now)
# Reserved for future progression. Keep for existing-save compatibility.
@export var unlocked_spell_ids: Array[String] = ["spell_magic_missile"]
@export var unlocked_race_ids: Array[String] = ["human", "elf", "dragonborn", "warforged"]

# Last chosen setup (so Continue makes sense)
@export var last_race_id: String = "human"
@export var last_style_id: String = "ranged"
@export var last_spell_ids: Array = ["spell_magic_missile", null, null]

@export var total_runs: int = 0
@export var best_followers: int = 0

@export var updated_unix: int = 0

# ============================================================
# Meta progression (persists even after die-die)
# ============================================================

# 3 permanent augment slots stored as String IDs ("" = empty)
@export var meta_permanent_augment_ids: Array[String] = ["", "", ""]
@export var meta_owned_augment_ids: Array[String] = [] # owned augment library (persist forever)
@export var meta_augment_slot_locks: Array[bool] = [false, false, false]
# Reserved id:String -> int upgrade levels; retained for save compatibility.
@export var meta_augment_levels: Dictionary = {}
@export var meta_stash: StashInventory = null
@export var meta_discovered_enemy_ids: Array[String] = []
# Manifestation explainer cards already shown, as PREFIXED ids - "intro",
# "noun:momentum", "pair:slipstream_foundry". One field rather than one per
# card kind, so the next card to earn an explainer is a new string and not a
# new save migration.
@export var meta_seen_manifestation_cards: Array[String] = []

# Opening Chronicle state (profile-wide). Missing fields on older .tres saves
# receive these defaults when Godot loads the updated SaveData script.
@export var opening_full_intro_seen: bool = false
@export var opening_response_id: String = ""
@export var opening_follower_explanation_seen: bool = false
@export var opening_replay_full_next_run: bool = false

# ============================================================
# Campaign attempt snapshot (for Continue)
# Resets ONLY on die-die.
# ============================================================

@export var attempt_active: bool = false
@export var attempt_segment: int = 1
@export var attempt_followers: int = 0

# Seed used to generate procedural segments consistently for this attempt (Continue-safe).
@export var attempt_world_seed: int = 0
@export var attempt_deaths_this_segment: int = 0

# res:// path to resume from (usually Game or HubShop)
@export var attempt_resume_scene: String = ""

# Between-segment rewards / gates
@export var attempt_pending_augment_pick: bool = false
@export var attempt_pending_big_choice: bool = false

# Exploration loot (prevents infinite respawn when chunks stream)
@export var attempt_claimed_loot_ids: PackedInt32Array = PackedInt32Array()
@export var attempt_big_choice_source_segment: int = 0 # Segment index that granted the pending big choice (usually 5)

# Attempt modifiers (run-shaping choices; persists for this attempt only)
@export var attempt_major_choice_id: String = ""
@export var attempt_mod_wardstone_radius_mul: float = 1.0
@export var attempt_mod_wardstone_slow_mul: float = 1.0
@export var attempt_mod_exit_hold_mul: float = 1.0


@export var attempt_major_choice_offer_ids: Array[String] = []  # Persist offered cards (anti-reroll)
@export var attempt_major_choice_taken_ids: Array[String] = []  # Track uniques per attempt
@export var attempt_augment_levels: Dictionary = {}             # String -> int (resets on die-die)
@export var attempt_mod_mutations: Dictionary = {}              # String -> Variant (run rules)
@export var attempt_mod_stat_delta: StatDelta = null            # Additive stats for this attempt
# Attempt setup (so Continue keeps your run identity)
@export var attempt_race_id: String = "human"
@export var attempt_style_id: String = "ranged"
@export var attempt_weapon_id: String = "ranged"

# Last wardstone checkpoint (Vector2.INF = unset)
@export var attempt_checkpoint_pos: Vector2 = Vector2.INF

# Handcrafted Segment 1 state. Layout version protects old checkpoint coordinates.
@export var attempt_segment1_layout_version: int = 0
@export var attempt_segment1_resonance: float = 0.0
@export var attempt_segment1_milestones: Array[String] = []

# Playable Segment 1 opening state. This is attempt-scoped so a scene reload or
# reconstruction can resume after the historical framing instead of replaying it.
@export var attempt_opening_version: int = 0
@export var attempt_opening_mode: String = ""
@export var attempt_opening_phase: int = 0
@export var attempt_opening_completed: bool = false
@export var attempt_opening_officer_completed: bool = false
@export var attempt_opening_bren_committed: bool = false

# Attempt inventories (Resources)
@export var attempt_inventory: Inventory = null
@export var attempt_bag: BagInventory = null

# Vendor stock snapshot (prevents reroll exploit in HubShop)
@export var attempt_vendor_segment: int = 0
@export var attempt_vendor_refreshes: int = 0
@export var attempt_vendor_seed: int = 0
@export var attempt_vendor_bag: BagInventory = null
