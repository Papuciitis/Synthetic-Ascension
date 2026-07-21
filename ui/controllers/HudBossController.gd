extends Node
class_name HudBossController

@export var boss_bar_path: NodePath

var _boss_bar: BossBarHUD
var _boss: Enemy = null
var _tier: int = -1

func _ready() -> void:
	_boss_bar = get_node_or_null(boss_bar_path) as BossBarHUD
	if _boss_bar != null:
		_boss_bar.hide_boss()

	if RunEvents != null:
		if RunEvents.has_signal("boss_spawned"):
			var cb1 := Callable(self, "_on_boss_spawned")
			if not RunEvents.boss_spawned.is_connected(cb1):
				RunEvents.boss_spawned.connect(cb1)

		if RunEvents.has_signal("boss_cleared"):
			var cb2 := Callable(self, "_on_boss_cleared")
			if not RunEvents.boss_cleared.is_connected(cb2):
				RunEvents.boss_cleared.connect(cb2)

		# Failsafe: if anything kills the boss without emitting boss_cleared.
		if RunEvents.has_signal("enemy_killed"):
			var cb3 := Callable(self, "_on_enemy_killed")
			if not RunEvents.enemy_killed.is_connected(cb3):
				RunEvents.enemy_killed.connect(cb3)

	set_process(false)

func _process(_delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.dead:
		_clear()
		return

	if _boss_bar != null:
		_boss_bar.update_hp(_boss.hp, _boss.max_hp)

func _on_boss_spawned(boss: Node, tier: int, portrait: Texture2D, title: String) -> void:
	if boss is not Enemy:
		return

	_boss = boss as Enemy
	_tier = tier

	if _boss_bar != null:
		_boss_bar.show_boss(title, portrait, _boss.hp, _boss.max_hp)

	set_process(true)

func _on_boss_cleared(boss: Node, tier: int) -> void:
	if boss == null:
		return
	if _boss == null:
		return
	if boss != _boss:
		return
	if tier != _tier:
		# Same boss anyway — clear.
		pass
	_clear()

func _on_enemy_killed(_who: Node, enemy: Node, _pos: Vector2) -> void:
	if enemy == null or _boss == null:
		return
	if enemy != _boss:
		return
	_clear()

func _clear() -> void:
	set_process(false)
	_boss = null
	_tier = -1
	if _boss_bar != null:
		_boss_bar.hide_boss()
