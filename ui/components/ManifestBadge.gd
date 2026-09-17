extends Label
class_name ManifestBadge

## The ◆ that marks an item as carrying a Manifestation.
##
## Three slot widgets - InventorySlotView, BagSlot and HubItemSlot - each built
## this same Label with their own copy of the font size, the mouse filter, the
## z_index and the colour. Now that the colour is per-NOUN rather than one
## constant, a fourth copy would be a fourth place for the palette to drift, so
## the widget owns it and the call sites only say where it goes.

const GLYPH: String = "◆"
const FONT_SIZE: int = 12


## Creates the badge under `host` (or reuses one already there) at `rect`,
## measured from `preset`'s anchor. The three call sites differ only in that
## geometry: the inventory and bag slots hang it under the set emblem at the top
## right, the hub slot sits it in the bottom-left corner of the tile.
static func attach(host: Control, preset: int, rect: Rect2, z: int = 25) -> ManifestBadge:
	if host == null:
		return null
	var existing := host.get_node_or_null("ManifestBadge")
	if existing is ManifestBadge:
		return existing as ManifestBadge
	if existing != null:
		# A stale plain Label from an older scene would otherwise leave two
		# badges fighting over the same corner, one of them never updated.
		existing.free()
	var badge := ManifestBadge.new()
	badge.name = "ManifestBadge"
	badge.text = GLYPH
	badge.add_theme_font_size_override("font_size", FONT_SIZE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = z
	badge.visible = false
	host.add_child(badge)
	badge.set_anchors_preset(preset as Control.LayoutPreset, true)
	badge.position = rect.position
	badge.size = rect.size
	badge.set_for_manifestation(&"")
	return badge


## Shows the badge in the noun's colour, or hides it when the item carries no
## rule. Colour is the cheapest place the player learns the vocabulary: the same
## orange on the bar, in the tooltip and on the HUD counter.
func show_for_item(inst: ItemInstance) -> void:
	if inst == null or not inst.has_manifestation():
		visible = false
		return
	set_for_manifestation(inst.manifestation_id)
	visible = true


func set_for_manifestation(manifestation_id: StringName) -> void:
	var noun := ManifestationNouns.primary_of(manifestation_id)
	add_theme_color_override(
		"font_color",
		ManifestationNouns.colour(noun) if noun != &"" else ManifestationNouns.LAYER
	)
