extends RefCounted
class_name ManifestationNouns

## Display identity for the five nouns: label, colour, hex and glyph.
##
## Not on ManifestationDef. A rule carries one or two tags, so the thing being
## coloured is the NOUN, never the rule; `primary_tag()` resolves which of a
## rule's nouns it displays as. One registry means the tooltip, the three item
## badges, the Run Sheet, the HUD counter and fourteen hand-drawn overlays
## cannot disagree about what Momentum looks like.
##
## PALETTE CONSTRAINT - the reason these particular five values.
##
## Every rule overlay, and ManifestationState itself, paints through
## BLEND_MODE_ADD. Additive blending washes toward white, so two nouns that
## differ only in LIGHTNESS become the same colour the instant they overlap each
## other or a lit sprite. The five therefore separate on hue and saturation:
##
##   ward     ~  2 deg   S .70   near-pure red
##   momentum ~ 31 deg   S .78   the most saturated of the warm three
##   fortune  ~ 48 deg   S .68   pale gold
##   shard    ~192 deg   S .28   cyan-white, the palest
##   cadence  ~264 deg   S .39   violet
##
## Four of the five were already the de-facto colour of their rules' overlays
## before this registry existed, which is independent evidence that the noun
## split matches how the art already reads. Cadence is the exception: its rules
## painted gold, colliding with fortune, so it takes the layer's own identity
## violet instead - the colour the Run Sheet and the item tooltip already use
## for the whole Manifestation layer.

## The layer's identity colour, for chrome that speaks about Manifestations in
## general rather than about one noun. Cadence inherits it; see above.
const LAYER: Color = Color(0.78, 0.61, 1.00, 1.0)
const LAYER_HEX: String = "#C79BFF"

## Shown when a noun is unknown or a rule is rendering detached with no
## definition. Deliberately colourless, so a missing tag reads as missing rather
## than as some fifth noun.
const FALLBACK: Color = Color(0.82, 0.84, 0.88, 1.0)

const ENTRIES: Dictionary = {
	&"momentum": {"label": "MOMENTUM", "colour": Color(1.00, 0.62, 0.22, 1.0), "glyph": "➶"},
	&"cadence": {"label": "CADENCE", "colour": LAYER, "glyph": "⚔"},
	&"shard": {"label": "SHARDS", "colour": Color(0.72, 0.95, 1.00, 1.0), "glyph": "✦"},
	&"ward": {"label": "WARD", "colour": Color(1.00, 0.32, 0.30, 1.0), "glyph": "⬡"},
	&"fortune": {"label": "FORTUNE", "colour": Color(1.00, 0.84, 0.32, 1.0), "glyph": "✺"},
}

## Authored display order, so the HUD counter does not reshuffle its columns
## when an unrelated item is equipped. Warm to cool.
const ORDER: Array[StringName] = [&"ward", &"momentum", &"fortune", &"cadence", &"shard"]


static func known(noun: StringName) -> bool:
	return ENTRIES.has(noun)


static func colour(noun: StringName) -> Color:
	var entry: Variant = ENTRIES.get(noun, null)
	return (entry as Dictionary)["colour"] if entry is Dictionary else FALLBACK


## BBCode-ready hex, DERIVED from the colour rather than authored beside it -
## the tooltip and the overlays would otherwise be free to drift apart by one
## edit, which is exactly the class of bug this registry exists to remove.
static func hex(noun: StringName) -> String:
	return "#" + colour(noun).to_html(false)


static func label(noun: StringName) -> String:
	var entry: Variant = ENTRIES.get(noun, null)
	return String((entry as Dictionary)["label"]) if entry is Dictionary else String(noun).to_upper()


## Small identity mark for chrome too narrow to spell the noun out. Every glyph
## here is one the project's UI font already renders elsewhere.
static func glyph(noun: StringName) -> String:
	var entry: Variant = ENTRIES.get(noun, null)
	return String((entry as Dictionary)["glyph"]) if entry is Dictionary else "◆"


## The noun an item's Manifestation displays as, or &"" if it carries none.
## Reads the catalog rather than a live effect, so item chrome works on items
## that are sitting in the bag with nothing instantiated.
static func primary_of(manifestation_id: StringName) -> StringName:
	if manifestation_id == &"":
		return &""
	var tags: Array[StringName] = ManifestationCatalog.tags_of(manifestation_id)
	return tags[0] if not tags.is_empty() else &""
