extends Node2D

## Tithe Bones - a curse shaped like a CURRENCY TAX.
##
## It never threatens your life. It bills your loot loop instead: taking a hit
## costs Followers, and Followers are simultaneously money, lives and Power in
## this game. So a curse that touches none of your combat stats still reaches
## every one of them, and it punishes a careless run rather than a weak one.
##
## The shape matters because it is orthogonal to every other curse: a wounded
## build barely notices -60% Max HP, but it notices this constantly.

## Followers billed per full max-HP-worth of damage taken.
const FOLLOWERS_PER_HEALTH_BAR: float = 22.0
## Never bills you into being unable to reconstruct - the curse takes your
## purse, never your last life. That refusal is what keeps it a tax rather than
## a death sentence.
const SAFETY_MARGIN: int = 0

var player: Node = null
var item: ItemInstance = null
var slot_index: int = -1

var _owed: float = 0.0
var _damage_cb: Callable = Callable()


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Taking damage costs Followers: about %d per health bar lost." % int(round(rate(inst))))
	out.append("Never spends below your reconstruction cost. It takes your purse, not your last life.")
	return out


func rate(inst: ItemInstance) -> float:
	var severity: float = absf(inst.active_pct()) if inst != null else 0.5
	return FOLLOWERS_PER_HEALTH_BAR * (0.5 + severity)


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null:
		_damage_cb = Callable(self, "_on_damage_taken")
		if not RunEvents.player_damage_taken.is_connected(_damage_cb):
			RunEvents.player_damage_taken.connect(_damage_cb)


func _exit_tree() -> void:
	if _damage_cb.is_valid() and RunEvents != null and RunEvents.player_damage_taken.is_connected(_damage_cb):
		RunEvents.player_damage_taken.disconnect(_damage_cb)


func _on_damage_taken(hurt: Node, amount: float, at: Vector2) -> void:
	if hurt != player or amount <= 0.0 or Global == null:
		return
	var max_hp: Variant = player.get("max_hp") if player != null and is_instance_valid(player) else null
	var bar: float = float(max_hp) if (max_hp is float or max_hp is int) and float(max_hp) > 0.0 else 100.0

	# Billed in fractions and settled in whole Followers, so small chip damage
	# accumulates honestly instead of rounding away to free.
	_owed += (amount / bar) * rate(item)
	var due: int = int(floor(_owed))
	if due <= 0:
		return

	var floor_followers: int = Global.compute_respawn_cost() + SAFETY_MARGIN
	var spendable: int = maxi(0, Global.followers - floor_followers)
	var taken: int = mini(due, spendable)
	_owed -= float(due)
	if taken <= 0:
		return

	Global.transaction_followers(
		-taken, &"curse_tithe_bones",
		{"item": String(item.data.id) if item != null and item.data != null else "", "slot": slot_index},
		true, true
	)
	if BattleText != null:
		BattleText.popup(at, "-%d BELIEF" % taken, Color(0.85, 0.45, 0.95, 1.0), 1.05)
