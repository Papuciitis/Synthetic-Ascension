extends Node
class_name HudManifestationController

## Drives the HUD's Manifestation counter - the "one more item would turn this
## on" readout.
##
## Two of a noun is what makes two unrelated items combine, so the state that
## matters most is 1/2, not 2/2: a dim MOMENTUM ◆◇ is the whole reason this row
## exists. Without it the density work is invisible and the player cannot form
## the intent the drop weighting is nudging them toward.
##
## Shape copied from HudThreatController: NodePath exports with hardcoded
## fallbacks resolved in _resolve_nodes(), bound in _ready, released in
## _exit_tree, registered as a direct child of the HUD.
##
## STRUCTURE (which nouns exist, how many rules feed each) is rebuilt only on
## `manifestations_changed`. VALUES run on this node's own 10 Hz accumulator and
## are written only when the number the player can actually see has moved -
## get_meters() formats a String per meter per call, which at 10 Hz would be
## fifty dicts and fifty Strings a second, forever, for a readout that mostly
## does not change. Deliberately NOT hung off the Run Sheet's refresh, which
## early-returns while the panel is hidden - and the panel is hidden exactly
## when this row is load-bearing.

const TICK_INTERVAL: float = 0.1
## A noun reaching two claimers is the quiet announcement; the loud one is a
## pair activating, which ManifestationPairNotifier owns.
const FLASH_TIME: float = 0.9
## Spending or filling a noun. Taken as a max rather than restarted, so a rule
## that spends every attack reads as sustained brightness instead of a strobe.
const PULSE_TIME: float = 0.35
const FONT_SIZE: int = 11
const DIM_ALPHA: float = 0.55

const INTRO_CARD: StringName = &"intro"

@export var row_path: NodePath
@export var bag_controller_path: NodePath

var _row: HFlowContainer = null
var _runner: Node = null
var _state: Node = null
var _bag_controller: Node = null

## noun -> { label: Label, count: int, key: int, channel: StringName,
##           flash: float, pulse: float, brightness: float }. Created once,
##   mutated in place: after _ready this controller allocates nothing per tick.
var _entries: Dictionary = {}
var _accum: float = 0.0
var _intro_pending: bool = false


func _ready() -> void:
	_resolve_nodes()
	if _row == null:
		# No row means nothing to drive; stay asleep rather than ticking against
		# a half-resolved HUD.
		set_process(false)
		return
	_build_entries()
	_bind_bag_controller()
	_bind_runner()
	set_process(true)


func _exit_tree() -> void:
	_release_runner()
	if _bag_controller != null and is_instance_valid(_bag_controller):
		var cb := Callable(self, "_on_management_mode_changed")
		if _bag_controller.has_signal("management_mode_changed") and _bag_controller.is_connected("management_mode_changed", cb):
			_bag_controller.disconnect("management_mode_changed", cb)


func _resolve_nodes() -> void:
	var rp: NodePath = row_path
	if rp == NodePath():
		rp = NodePath("../TopLeft/Margin/VBox/ManifestationRow")
	_row = get_node_or_null(rp) as HFlowContainer
	if _row == null:
		push_warning("[HudManifestation] ManifestationRow not found at %s" % String(rp))
		return
	_row.visible = false


func _bind_bag_controller() -> void:
	var bp: NodePath = bag_controller_path
	if bp == NodePath():
		bp = NodePath("../BagController")
	_bag_controller = get_node_or_null(bp)
	if _bag_controller == null or not _bag_controller.has_signal("management_mode_changed"):
		return
	var cb := Callable(self, "_on_management_mode_changed")
	if not _bag_controller.is_connected("management_mode_changed", cb):
		_bag_controller.connect("management_mode_changed", cb)


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

## One Label per noun, created once in authored order and toggled by visibility.
## Building on demand would reorder the row every time an unrelated item was
## equipped, and the point of a counter is that the player's eye learns where
## each noun lives.
##
## No ProgressBar per noun, unlike ThreatRow: five bars do not fit a 302 px
## panel, and the number the player acts on is the value text, not the fill.
func _build_entries() -> void:
	if _row == null:
		return
	for noun in ManifestationNouns.ORDER:
		var label := Label.new()
		label.name = "Noun_%s" % String(noun)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_color", ManifestationNouns.colour(noun))
		label.visible = false
		_row.add_child(label)
		_entries[noun] = {
			"label": label,
			"count": 0,
			"key": -2147483648,
			"channel": &"",
			"flash": 0.0,
			"pulse": 0.0,
			"brightness": -1.0,
		}


# ---------------------------------------------------------------------------
# Runner binding
# ---------------------------------------------------------------------------

func _bind_runner() -> bool:
	if _runner != null and is_instance_valid(_runner):
		return true
	var player: Node = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if player == null:
		return false
	var runner: Node = player.get_node_or_null("ManifestationRunner")
	if runner == null or not runner.has_method("get_noun_counts"):
		return false
	_runner = runner
	_state = runner.get("state") as Node

	if runner.has_signal("manifestations_changed"):
		var cb := Callable(self, "_on_manifestations_changed")
		if not runner.is_connected("manifestations_changed", cb):
			runner.connect("manifestations_changed", cb)
	# The runner dies with the player. Without this the controller would sit at
	# set_process(false) holding a freed reference and never notice a respawn.
	var lost := Callable(self, "_on_runner_lost")
	if not runner.tree_exiting.is_connected(lost):
		runner.tree_exiting.connect(lost)

	# F6: the row must show FIRED as well as FULL. It is a Control, so it is the
	# one Manifestation channel the callout setting cannot switch off, which
	# makes it the load-bearing one.
	if _state != null and is_instance_valid(_state):
		if _state.has_signal("resource_spent"):
			var spent := Callable(self, "_on_resource_spent")
			if not _state.is_connected("resource_spent", spent):
				_state.connect("resource_spent", spent)
		if _state.has_signal("resource_filled"):
			var filled := Callable(self, "_on_resource_filled")
			if not _state.is_connected("resource_filled", filled):
				_state.connect("resource_filled", filled)

	_on_manifestations_changed()
	return true


func _release_runner() -> void:
	if _runner != null and is_instance_valid(_runner):
		var cb := Callable(self, "_on_manifestations_changed")
		if _runner.has_signal("manifestations_changed") and _runner.is_connected("manifestations_changed", cb):
			_runner.disconnect("manifestations_changed", cb)
		var lost := Callable(self, "_on_runner_lost")
		if _runner.tree_exiting.is_connected(lost):
			_runner.tree_exiting.disconnect(lost)
	if _state != null and is_instance_valid(_state):
		var spent := Callable(self, "_on_resource_spent")
		if _state.has_signal("resource_spent") and _state.is_connected("resource_spent", spent):
			_state.disconnect("resource_spent", spent)
		var filled := Callable(self, "_on_resource_filled")
		if _state.has_signal("resource_filled") and _state.is_connected("resource_filled", filled):
			_state.disconnect("resource_filled", filled)
	_runner = null
	_state = null


func _on_runner_lost() -> void:
	_release_runner()
	_clear_row()
	set_process(true)


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

func _on_manifestations_changed() -> void:
	if _row == null or _runner == null or not is_instance_valid(_runner):
		return
	var counts: Dictionary = _runner.call("get_noun_counts")
	var any := false
	for noun in ManifestationNouns.ORDER:
		var entry: Dictionary = _entries[noun]
		var was: int = int(entry["count"])
		var now: int = int(counts.get(noun, 0))
		entry["count"] = now
		(entry["label"] as Label).visible = now > 0
		if now > 0:
			any = true
		if now != was:
			# Force the text to be rebuilt on the next tick even if the number
			# behind it did not move - the pips changed.
			entry["key"] = -2147483648
		# Crossing to two is the quiet announcement: a colour flash here, and a
		# one-off tip the first time this profile ever lights this noun.
		if now >= 2 and was < 2:
			entry["flash"] = FLASH_TIME
			_announce_noun(noun)
	_row.visible = any
	_refresh_values(true)
	# Paint the dim/full state now rather than on the next frame, or a noun that
	# just appeared at 1/2 flashes at full brightness for one frame first.
	_tick_highlights(0.0)
	# Nothing live means nothing to tick. manifestations_changed and the
	# runner's tree_exiting are what wake it back up.
	set_process(any or int(_runner.call("active_count")) > 0)


func _clear_row() -> void:
	if _row == null:
		return
	for noun in ManifestationNouns.ORDER:
		var entry: Dictionary = _entries[noun]
		entry["count"] = 0
		entry["flash"] = 0.0
		entry["pulse"] = 0.0
		(entry["label"] as Label).visible = false
	_row.visible = false


# ---------------------------------------------------------------------------
# Values
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _runner == null or not is_instance_valid(_runner):
		_accum += delta
		if _accum < TICK_INTERVAL:
			return
		_accum = 0.0
		_bind_runner()
		return

	_tick_highlights(delta)

	_accum += delta
	if _accum < TICK_INTERVAL:
		return
	_accum = 0.0
	_refresh_values(false)


func _refresh_values(force: bool) -> void:
	if _state == null or not is_instance_valid(_state):
		return
	for noun in ManifestationNouns.ORDER:
		var entry: Dictionary = _entries[noun]
		if int(entry["count"]) <= 0:
			continue
		var channel: StringName = _display_channel(noun)
		if channel == &"":
			continue
		var key := _display_key(channel, float(_state.call("noun_value", channel)))
		if not force and key == int(entry["key"]) and channel == StringName(entry["channel"]):
			continue
		entry["key"] = key
		entry["channel"] = channel
		var label := entry["label"] as Label
		# The noun's own name while its headline channel is shown; the channel's
		# name when a sibling channel won, so "STABILITY 100%" is what a planted
		# Anchor Rite reads rather than a MOMENTUM that says 0%.
		var shown: String = ManifestationNouns.label(noun) if channel == ManifestationState.headline_channel(noun) else String((ManifestationState.CHANNELS[channel] as Dictionary)["label"])
		label.text = "%s %s %s" % [
			shown,
			_pips(int(entry["count"])),
			_state.call("channel_text", channel),
		]


## The channel this row shows for a noun: the headline channel, unless a
## sibling channel of the same noun is fuller. Momentum owns two poles - Anchor
## Rite fills Stability while Momentum sits at 0% - and a row that only ever
## showed the headline read "MOMENTUM 0%" on a fully planted player, which
## looks like a rule that is not working. Fullness is value over the channel's
## declared full mark, so only channels with one compete; the headline keeps
## ties.
func _display_channel(noun: StringName) -> StringName:
	var headline: StringName = ManifestationState.headline_channel(noun)
	if headline == &"" or _state == null or not is_instance_valid(_state):
		return headline
	var channels: Variant = ManifestationState.NOUNS.get(noun, null)
	if not (channels is Array):
		return headline
	var best: StringName = headline
	var best_fill: float = _fill_of(headline)
	for channel in (channels as Array):
		if channel == headline:
			continue
		var descriptor: Variant = ManifestationState.CHANNELS.get(channel, null)
		if not (descriptor is Dictionary) or not bool((descriptor as Dictionary).get("meter", true)):
			continue
		var fill := _fill_of(channel)
		if fill > best_fill:
			best = channel
			best_fill = fill
	return best


## Value as a fraction of the channel's full mark; 0 for a channel that has
## none, so it can never displace the headline.
func _fill_of(channel: StringName) -> float:
	var descriptor: Variant = ManifestationState.CHANNELS.get(channel, null)
	if not (descriptor is Dictionary):
		return 0.0
	var full_at := float((descriptor as Dictionary).get("full_at", 0.0))
	if full_at <= 0.0:
		return 0.0
	return float(_state.call("noun_value", channel)) / full_at


## The value at the precision the player can actually READ, so a clock ticking
## in the seventh decimal does not rewrite a Label ten times a second.
func _display_key(channel: StringName, value: float) -> int:
	var descriptor: Variant = ManifestationState.CHANNELS.get(channel, null)
	var kind: int = int((descriptor as Dictionary).get("kind", ManifestationState.KIND_COUNT)) if descriptor is Dictionary else ManifestationState.KIND_COUNT
	match kind:
		ManifestationState.KIND_FRACTION:
			return int(round(value * 100.0))
		ManifestationState.KIND_SECONDS:
			return int(round(value * 10.0))
		_:
			return int(round(value))


## ◆◇ at one claimer, ◆◆ at two, ◆◆+n beyond - the same pip vocabulary the item
## tooltip uses for set breakpoints, because it means the same thing.
func _pips(count: int) -> String:
	if count <= 1:
		return "◆◇"
	if count == 2:
		return "◆◆"
	return "◆◆+%d" % (count - 2)


func _tick_highlights(delta: float) -> void:
	for noun in ManifestationNouns.ORDER:
		var entry: Dictionary = _entries[noun]
		if int(entry["count"]) <= 0:
			continue
		var flash := maxf(0.0, float(entry["flash"]) - delta)
		var pulse := maxf(0.0, float(entry["pulse"]) - delta)
		entry["flash"] = flash
		entry["pulse"] = pulse
		var brightness := 1.0 + 1.2 * (flash / FLASH_TIME) + 0.8 * (pulse / PULSE_TIME)
		if absf(brightness - float(entry["brightness"])) < 0.01:
			continue
		entry["brightness"] = brightness
		# One claimer is dimmed rather than recoloured: it has to read as "this
		# is half of something", not as a different noun.
		var alpha := 1.0 if int(entry["count"]) >= 2 else DIM_ALPHA
		(entry["label"] as Label).modulate = Color(brightness, brightness, brightness, alpha)


func _on_resource_spent(noun: StringName, _amount: float) -> void:
	_pulse_noun(noun)


func _on_resource_filled(noun: StringName) -> void:
	_pulse_noun(noun)


func _pulse_noun(noun: StringName) -> void:
	var entry: Variant = _entries.get(noun, null)
	if entry is Dictionary:
		(entry as Dictionary)["pulse"] = PULSE_TIME


# ---------------------------------------------------------------------------
# Announcements and the first-Manifestation explainer
# ---------------------------------------------------------------------------

## Tips play serially at ~2.8 s, so three nouns lighting at once would queue
## nine seconds of banner. First time ever per noun per profile, and never
## again - after that the row's flash is the whole announcement.
func _announce_noun(noun: StringName) -> void:
	if Global == null or RunEvents == null:
		return
	var card_id := StringName("noun:%s" % String(noun))
	if Global.is_manifestation_card_seen(card_id):
		return
	Global.mark_manifestation_card_seen(card_id)
	RunEvents.tutorial_tip.emit(
		"%s ×2 — two of your Manifestations now feed the same %s. That is one engine, not two rules." % [
			ManifestationNouns.label(noun), ManifestationNouns.label(noun),
		],
		4.0
	)


## Fired on a SAFE BOUNDARY - the first time the player opens the bag while
## actually carrying a live rule - and never from the equip path. A non-enemy
## card skips the dossier spacing and pauses unconditionally, so firing one on
## equip would pause a boss fight the moment a drop was slotted.
func _on_management_mode_changed(is_open: bool) -> void:
	if is_open:
		_maybe_present_intro()


func _maybe_present_intro() -> void:
	if _intro_pending or Global == null:
		return
	if Global.is_manifestation_card_seen(INTRO_CARD):
		return
	if _runner == null or not is_instance_valid(_runner) or int(_runner.call("active_count")) <= 0:
		return
	var modal: Node = get_tree().get_first_node_in_group(&"tutorial_modal_controller")
	if modal == null or not modal.has_method("present_card_and_wait"):
		return
	_intro_pending = true
	# present_card_and_wait, NOT RunEvents.blocking_info_requested: the
	# fire-and-forget path discards the card id, so a card aborted by a scene
	# change would be marked seen and never shown again.
	await modal.call("present_card_and_wait", "MANIFESTATIONS", _intro_body(), "PATTERN RECORD", true)
	_intro_pending = false
	if not is_inside_tree() or Global == null:
		return
	Global.mark_manifestation_card_seen(INTRO_CARD)


func _intro_body() -> String:
	var nouns: PackedStringArray = PackedStringArray()
	for noun in ManifestationNouns.ORDER:
		nouns.append("%s %s" % [ManifestationNouns.glyph(noun), ManifestationNouns.label(noun)])
	return "\n".join(PackedStringArray([
		"One of your items carries a Manifestation — a rule that fires on its own, for the life of that item. It survives every merge and it never rerolls.",
		"",
		"Every rule speaks about one or two shared nouns:",
		"  " + "   ".join(nouns),
		"",
		"Two rules that name the SAME noun share one resource. That is when the layer stops being a proc and starts being an engine.",
		"",
		"The counter above your health bar reads ◆◇ while one rule feeds a noun, and ◆◆ once two do. A dim ◆◇ is the game telling you which item to look for.",
	]))
