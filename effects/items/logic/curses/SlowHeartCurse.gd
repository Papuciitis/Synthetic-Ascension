extends Node2D

## Slow Heart - a curse shaped like a RATE CAP rather than a subtraction.
##
## It takes nothing away while you are healing slowly. It only bites once you
## are strong enough to heal in bursts, which is the opposite of a stat penalty:
## the curse grows teeth exactly as the build does. That shape is why it belongs
## to a different archetype than a flat -60% Max HP - a wounded build barely
## feels it, a lifesteal build is ruined by it.

## Fraction of an incoming heal that is intercepted rather than applied.
const INTERCEPT: float = 0.85
## Ceiling on how fast the banked pool is allowed to return, as a fraction of
## max HP per second. This is the cap that does the work.
const RELEASE_PER_SEC: float = 0.035
## Banking beyond this is thrown away - an uncapped pool would make the curse a
## pure delay rather than a real loss.
const BANK_CAP_FRACTION: float = 0.60

var player: Node = null
var item: ItemInstance = null
var slot_index: int = -1

var _bank: float = 0.0
var _healed_cb: Callable = Callable()


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	var severity: float = absf(inst.active_pct()) if inst != null else 0.0
	out.append("Healing is intercepted and returned slowly, at most %.1f%% max HP per second." % (release_rate(severity) * 100.0))
	out.append("Costs nothing if you heal slowly. Ruinous if you heal in bursts.")
	return out


func release_rate(severity: float) -> float:
	# A worse roll means a tighter cap, so severity means something even though
	# the curse subtracts nothing.
	return RELEASE_PER_SEC * (1.0 - 0.5 * clampf(severity, 0.0, 1.0))


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	set_process(true)
	if RunEvents != null:
		_healed_cb = Callable(self, "_on_player_healed")
		if not RunEvents.player_healed.is_connected(_healed_cb):
			RunEvents.player_healed.connect(_healed_cb)


func _exit_tree() -> void:
	if _healed_cb.is_valid() and RunEvents != null and RunEvents.player_healed.is_connected(_healed_cb):
		RunEvents.player_healed.disconnect(_healed_cb)


func _on_player_healed(healed_player: Node, amount: float) -> void:
	if healed_player != player or amount <= 0.0 or player == null or not is_instance_valid(player):
		return
	# The heal has already landed, so the interception is taken back off rather
	# than prevented - which keeps this rule out of the player's healing path
	# and means it composes with any other healing source.
	var taken := amount * INTERCEPT
	var hp: Variant = player.get("hp")
	if not (hp is float or hp is int):
		return
	player.set("hp", maxf(1.0, float(hp) - taken))
	var cap := _max_hp() * BANK_CAP_FRACTION
	_bank = minf(cap, _bank + taken)


func _process(delta: float) -> void:
	if _bank <= 0.0 or player == null or not is_instance_valid(player):
		return
	if not player.has_method("heal"):
		return
	var severity: float = absf(item.active_pct()) if item != null else 0.0
	var step := minf(_bank, _max_hp() * release_rate(severity) * delta)
	if step <= 0.0:
		return
	_bank -= step
	# Re-entrancy: heal() emits player_healed, which this node listens to. The
	# guard is the flag rather than disconnecting, so another heal arriving in
	# the same frame is still intercepted correctly.
	_releasing = true
	player.call("heal", step)
	_releasing = false


var _releasing: bool = false


func _max_hp() -> float:
	if player == null or not is_instance_valid(player):
		return 100.0
	var m: Variant = player.get("max_hp")
	return float(m) if (m is float or m is int) else 100.0
