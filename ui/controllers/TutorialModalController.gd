extends Node
class_name TutorialModalController

const OVERLAY_SCENE := preload("res://ui/screens/TutorialCardOverlay.tscn")

# Minimum unpaused play between enemy dossier cards. A horde that
# introduces several new archetypes at once otherwise fires N pause
# interruptions back to back; the first card is immediate, the rest
# wait for a breather. Non-enemy cards are never delayed.
const ENEMY_CARD_SPACING_SEC := 6.0

var _queue: Array[Dictionary] = []
var _active: bool = false
var _session_enemy_ids: Dictionary = {}
var _completed_tokens: Dictionary = {}
var _next_token: int = 1
var _unpaused_since_enemy_card: float = 1.0e9

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RunEvents != null:
		RunEvents.blocking_info_requested.connect(_on_blocking_info_requested)
		RunEvents.enemy_archetype_encountered.connect(_on_enemy_encountered)

func _process(delta: float) -> void:
	if not get_tree().paused:
		_unpaused_since_enemy_card += delta

func _exit_tree() -> void:
	if RunEvents == null:
		return
	if RunEvents.blocking_info_requested.is_connected(_on_blocking_info_requested):
		RunEvents.blocking_info_requested.disconnect(_on_blocking_info_requested)
	if RunEvents.enemy_archetype_encountered.is_connected(_on_enemy_encountered):
		RunEvents.enemy_archetype_encountered.disconnect(_on_enemy_encountered)

func present_card_and_wait(title: String, body: String, eyebrow: String = "PATTERN RECORD") -> void:
	var token := _next_token
	_next_token += 1
	_enqueue({"token": token, "title": title, "body": body, "eyebrow": eyebrow, "texture": null, "enemy_id": &""})
	while not _completed_tokens.has(token):
		await get_tree().process_frame
	_completed_tokens.erase(token)

func _on_blocking_info_requested(_card_id: StringName, title: String, body: String) -> void:
	_enqueue({"token": 0, "title": title, "body": body, "eyebrow": "PATTERN RECORD", "texture": null, "enemy_id": &""})

func _on_enemy_encountered(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var spec: EnemySpec = enemy.get("spec") as EnemySpec
	if spec == null:
		return
	var enemy_id := spec.id
	var entry := EnemyDossierCatalog.get_entry(enemy_id)
	if entry.is_empty() or _session_enemy_ids.has(enemy_id):
		return
	if Global != null and Global.is_enemy_discovered(enemy_id) and not Global.debug_force_enemy_introductions:
		return
	_session_enemy_ids[enemy_id] = true
	var lore := "“%s”" % String(entry.get("quote", ""))
	var body := "%s\n\nRole: %s\nBehaviour: %s\nExpect: %s\nCounter: %s\n\n%s" % [
		lore, String(entry.get("role", "")), String(entry.get("behaviour", "")),
		String(entry.get("expect", "")), String(entry.get("counter", "")), EnemyDossierCatalog.ratings(spec)
	]
	var texture := spec.sprite_texture
	if texture == null:
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			texture = sprite.texture
	var dossier_name := String(entry.get("name", spec.display_name))
	_enqueue({"token": 0, "title": dossier_name.to_upper(), "body": body, "eyebrow": "FIRST ENCOUNTER", "texture": texture, "enemy_id": enemy_id, "typewriter_character_limit": lore.length()})

func _enqueue(card: Dictionary) -> void:
	_queue.append(card)
	if not _active:
		_drain_queue()

func _drain_queue() -> void:
	_active = true
	while not _queue.is_empty():
		# Present the first card that is safe to show. Non-enemy cards are
		# always safe, so a scripted card awaited by gameplay code is never
		# stalled behind an enemy dossier waiting out its spacing cooldown.
		var index := _first_presentable_index()
		if index == -1:
			await get_tree().process_frame
			continue
		var card: Dictionary = _queue.pop_at(index) as Dictionary
		var was_paused := get_tree().paused
		get_tree().paused = true
		if RunEvents != null:
			RunEvents.tutorial_modal_state_changed.emit(true)
		var overlay := OVERLAY_SCENE.instantiate() as TutorialCardOverlay
		get_tree().current_scene.add_child(overlay)
		overlay.present(String(card.get("title", "")), String(card.get("body", "")), String(card.get("eyebrow", "")), card.get("texture", null) as Texture2D, int(card.get("typewriter_character_limit", -1)))
		await overlay.dismissed
		var enemy_id: StringName = card.get("enemy_id", &"") as StringName
		if enemy_id != &"":
			_unpaused_since_enemy_card = 0.0
			if Global != null:
				Global.mark_enemy_discovered(enemy_id)
		overlay.queue_free()
		if RunEvents != null:
			RunEvents.tutorial_modal_state_changed.emit(false)
		get_tree().paused = was_paused
		_reset_spawners_after_pause()
		var token := int(card.get("token", 0))
		if token > 0:
			_completed_tokens[token] = true
	_active = false

func _first_presentable_index() -> int:
	for i in range(_queue.size()):
		if not _unsafe_for_enemy_card(_queue[i]):
			return i
	return -1

func _unsafe_for_enemy_card(card: Dictionary) -> bool:
	if StringName(card.get("enemy_id", &"")) == &"":
		return false
	if _unpaused_since_enemy_card < ENEMY_CARD_SPACING_SEC:
		return true
	return not get_tree().get_nodes_in_group(&"boss_like").is_empty() or not get_tree().get_nodes_in_group(&"exit_rite_channeling").is_empty()

func _reset_spawners_after_pause() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy_spawner"):
		if node.has_method("reset_spawn_clock"):
			node.call("reset_spawn_clock")
