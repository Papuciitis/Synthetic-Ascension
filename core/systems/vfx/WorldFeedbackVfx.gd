extends Node

## World feedback bursts on run events (autoload): an enemy death puff, a
## bigger elite death, a dash wisp, a Q / V cast flash. Item pickups call
## VfxBursts directly from the pickup. Capped per frame so a chain kill
## reads as a shower, not a frame.

const DEATHS_PER_FRAME := 10

var enabled := true
var _deaths_this_frame := 0


func _ready() -> void:
	if RunEvents == null:
		return
	RunEvents.enemy_defeated.connect(_on_enemy_defeated)
	RunEvents.player_dashed.connect(_on_player_dashed)
	RunEvents.player_ability_activated.connect(_on_ability_activated)
	VfxBursts.warm()


func _process(_delta: float) -> void:
	_deaths_this_frame = 0


func _on_enemy_defeated(context: RefCounted) -> void:
	if not enabled or context == null or _deaths_this_frame >= DEATHS_PER_FRAME:
		return
	_deaths_this_frame += 1
	var flags := int(context.get("flags"))
	var elite := (flags & EnemyWorldTypes.Flags.ELITE) != 0
	var position: Vector2 = context.get("position")
	VfxBursts.play(&"elite_death" if elite else &"death", position, 1.15 if elite else 1.0)


func _on_player_dashed(_player: Node, from: Vector2, direction: Vector2) -> void:
	if not enabled:
		return
	VfxBursts.play(&"dash", from, 1.0, Color.WHITE, -direction)


func _on_ability_activated(player: Node, slot: StringName, _id: String, _cooldown: float) -> void:
	if not enabled or not (player is Node2D):
		return
	VfxBursts.play(&"cast", (player as Node2D).global_position, 1.6 if slot == &"v" else 1.0)
