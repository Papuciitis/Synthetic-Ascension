extends Node2D
class_name PlotArmorEffect
## Plot Armor (handoff §14.3, assistant-proposed mechanic now made concrete):
## survive one lethal hit at 1 HP and mark its source as your RIVAL. The
## protection rearms only when the rival dies — with hard safeguards so it
## can never become permanent invulnerability: a brief post-trigger grace,
## one charge at a time, and a fallback rearm when the rival despawns,
## becomes untrackable or a segment ends.

const GRACE_SECONDS := 1.0        # post-trigger invulnerability, once
const FALLBACK_REARM_SECONDS := 45.0
const RIVAL_MARK_COLOR := Color(1.0, 0.45, 0.4, 1.0)

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var armed: bool = true
var rival: Node = null            # the actor that "killed" you, when known
var rival_handle: int = 0
var _fallback_left: float = 0.0
var telemetry: Dictionary = {"saves": 0, "rival_revenges": 0, "fallback_rearms": 0}


func get_effects_short(_inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"Survive a lethal hit at 1 HP; whoever dealt it becomes your rival.",
		"Rearms when the rival dies (or after %.0f s if fate loses track of them)." % FALLBACK_REARM_SECONDS,
		"The narrative only protects its protagonist so often.",
	])


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null:
		if not RunEvents.enemy_defeated.is_connected(_on_enemy_defeated):
			RunEvents.enemy_defeated.connect(_on_enemy_defeated)
		if not RunEvents.enemy_killed.is_connected(_on_enemy_killed):
			RunEvents.enemy_killed.connect(_on_enemy_killed)
	if Global != null and Global.has_signal("balance_segment_completed"):
		if not Global.balance_segment_completed.is_connected(_on_segment_completed):
			Global.balance_segment_completed.connect(_on_segment_completed)


func _exit_tree() -> void:
	if RunEvents != null:
		if RunEvents.enemy_defeated.is_connected(_on_enemy_defeated):
			RunEvents.enemy_defeated.disconnect(_on_enemy_defeated)
		if RunEvents.enemy_killed.is_connected(_on_enemy_killed):
			RunEvents.enemy_killed.disconnect(_on_enemy_killed)
	if Global != null and Global.has_signal("balance_segment_completed"):
		if Global.balance_segment_completed.is_connected(_on_segment_completed):
			Global.balance_segment_completed.disconnect(_on_segment_completed)


## Player._take_damage consults this after the tree's own interceptors.
func intercept_lethal_damage(_amount: float, source: Node) -> bool:
	if not armed:
		return false
	armed = false
	telemetry["saves"] = int(telemetry["saves"]) + 1
	_mark_rival(source)
	if player != null and player.has_method("grant_invulnerability"):
		player.call("grant_invulnerability", GRACE_SECONDS)
	if BattleText != null and player != null:
		BattleText.popup(player.global_position, "PLOT ARMOR", Color(0.95, 0.85, 0.5, 1.0), 1.6)
	return true


func _mark_rival(source: Node) -> void:
	rival = null
	rival_handle = 0
	_fallback_left = FALLBACK_REARM_SECONDS
	if source == null or not is_instance_valid(source):
		return  # an untrackable killer: the fallback timer carries the rearm
	rival = source
	# A projectile's shooter is the real rival when the node exposes one.
	var shooter: Variant = source.get("source") if "source" in source else null
	if shooter is Node and is_instance_valid(shooter):
		rival = shooter
	if BattleText != null and rival is Node2D:
		BattleText.popup((rival as Node2D).global_position, "RIVAL", RIVAL_MARK_COLOR, 1.4)


func _rearm(reason: String) -> void:
	if armed:
		return
	armed = true
	rival = null
	rival_handle = 0
	_fallback_left = 0.0
	if reason == "revenge":
		telemetry["rival_revenges"] = int(telemetry["rival_revenges"]) + 1
	else:
		telemetry["fallback_rearms"] = int(telemetry["fallback_rearms"]) + 1
	if BattleText != null and player != null:
		BattleText.popup(player.global_position, "THE PLOT THICKENS", Color(0.95, 0.85, 0.5, 1.0), 1.2)


func _on_enemy_killed(_who: Node, enemy: Node, _pos: Vector2) -> void:
	if not armed and rival != null and enemy == rival:
		_rearm("revenge")


func _on_enemy_defeated(context: RefCounted) -> void:
	if armed or rival == null:
		return
	var handle := int(context.get("handle"))
	var actor := EnemyWorld.actor_for_handle(handle) if EnemyWorld != null else null
	if actor != null and actor == rival:
		_rearm("revenge")


func _on_segment_completed(_segment: int) -> void:
	# A rival left behind in a finished segment cannot gate the protection.
	if not armed:
		_rearm("segment")


func _process(delta: float) -> void:
	if armed:
		return
	# The rival vanished (despawn, culling): fate loses track, timer rearms.
	if rival != null and not is_instance_valid(rival):
		rival = null
	if _fallback_left > 0.0:
		_fallback_left -= delta
		if _fallback_left <= 0.0:
			_rearm("fallback")
	queue_redraw()


func _draw() -> void:
	if armed or not (rival is Node2D) or not is_instance_valid(rival):
		return
	# The rival mark: a small hostile chevron above them.
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var at := (rival as Node2D).global_position + Vector2(0, -34)
	draw_line(at + Vector2(-6, -5), at, RIVAL_MARK_COLOR, 2.0, true)
	draw_line(at + Vector2(6, -5), at, RIVAL_MARK_COLOR, 2.0, true)


func describe() -> Dictionary:
	return {"armed": armed, "rival_tracked": rival != null, "fallback_left": _fallback_left, "telemetry": telemetry.duplicate()}
