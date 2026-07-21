extends RefCounted
class_name EnemyDossierCatalog

## Central copy for first-encounter teaching. Stable EnemySpec IDs are the keys;
## spawners and scenes never own dossier prose.
const DATA: Dictionary = {
	&"enemy_grunt": {"name": "Containment Officer", "quote": "Drop the conduit. This does not need to become an execution.", "role": "Melee pursuer", "behaviour": "Closes distance and deals repeated contact damage.", "expect": "Dangerous when several surround you.", "counter": "Keep moving and use doors or cover to split the group."},
	&"enemy_runner": {"quote": "You cannot outrun containment.", "role": "Fast interceptor", "behaviour": "Rushes ahead of slower officers to cut off escape lines.", "expect": "Low durability, high closing speed.", "counter": "Remove it early and avoid retreating in a straight line."},
	&"enemy_orbiter": {"quote": "Hold the perimeter.", "role": "Mobile flanker", "behaviour": "Circles at short range instead of joining the central crowd.", "expect": "Attacks from angles that punish tunnel vision.", "counter": "Change direction and break its orbit against cover."},
	&"enemy_spitter": {"quote": "The specimen is still moving.", "role": "Ranged specialist", "behaviour": "Keeps distance and fires bright containment bolts.", "expect": "Projectiles make open lanes unsafe.", "counter": "Use cover, close the gap, or sidestep after the firing tell."},
	&"enemy_charger": {"quote": "Brace the corridor.", "role": "Shock attacker", "behaviour": "Telegraphs a fast committed charge.", "expect": "A clean hit can force you into the surrounding crowd.", "counter": "Move sideways during the wind-up and punish the recovery."},
	&"enemy_bomber": {"quote": "Seal it, whatever the cost.", "role": "Area denial", "behaviour": "Approaches aggressively and detonates at close range.", "expect": "The blast punishes standing inside a dense pack.", "counter": "Focus it at range and keep an exit lane open."},
	&"enemy_summoner": {"quote": "Containment has reserves.", "role": "Reinforcement specialist", "behaviour": "Creates additional bodies while left undisturbed.", "expect": "A manageable fight grows rapidly around it.", "counter": "Break through the screen and eliminate the summoner first."},
	&"enemy_leech": {"quote": "Belief is only another resource to drain.", "role": "Follower disruptor", "behaviour": "Clings close enough to erode the movement's support.", "expect": "Follower loss while its link remains active.", "counter": "Disengage immediately or focus it before other targets."},
	&"enemy_herald": {"quote": "The institution still speaks with one voice.", "role": "Enemy support", "behaviour": "Strengthens nearby forces and disrupts your Followers.", "expect": "Ordinary enemies become much harder to control nearby.", "counter": "Treat the Herald as the priority target."},
	&"enemy_sniper": {"quote": "Trajectory confirmed.", "role": "Long-range specialist", "behaviour": "Telegraphs a powerful line shot from far beyond normal range.", "expect": "Open sightlines become lethal after the wind-up.", "counter": "Cross the line, use hard cover, then close distance."},
	&"enemy_brute": {"quote": "The outer line will hold.", "role": "Heavy blocker", "behaviour": "Advances slowly with high durability and controls space by contact.", "expect": "Difficult to remove while specialists attack behind it.", "counter": "Kite it away from support and avoid being pinned against geometry."},
}

static func get_entry(enemy_id: StringName) -> Dictionary:
	return DATA.get(enemy_id, {}) as Dictionary

static func ratings(spec: EnemySpec) -> String:
	if spec == null:
		return "Health: Unknown  •  Speed: Unknown  •  Range: Unknown  •  Threat: Unknown"
	var health := "Low" if spec.max_hp <= 14.0 else ("High" if spec.max_hp >= 35.0 else "Medium")
	var speed := "Slow" if spec.speed <= 72.0 else ("Fast" if spec.speed >= 115.0 else "Medium")
	var attack_range := "Contact"
	if spec.ai == EnemySpec.AI.RANGED or spec.ai == EnemySpec.AI.TACTICAL:
		attack_range = "Medium"
	elif spec.ai == EnemySpec.AI.SNIPER:
		attack_range = "Long"
	var threat := "Basic" if spec.ai == EnemySpec.AI.CHASE else "Specialist"
	return "Health: %s  •  Speed: %s  •  Range: %s  •  Threat: %s" % [health, speed, attack_range, threat]
