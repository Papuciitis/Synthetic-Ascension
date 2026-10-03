extends RefCounted
class_name DoctrineFamilies

## The three Doctrine families and what holding several of one inscribes
## (docs/design/2026-10-03-bindings-and-theses.md §6). Two plates of a
## family grant its Thesis, three its Canon. The rules themselves live where
## they act (Global's Binding and stat helpers); this is the one place their
## words are written, so the plate, the Run Sheet and the tests agree.

const THESIS_AT := 2
const CANON_AT := 3

const THESIS := {
	&"circuit": "+1 Binding card; augment damage +20%",
	&"vessel": "+15% Power",
	&"archive": "Binding grades x1.5; one free Recast per Binding",
}

const CANON := {
	&"circuit": "every Transcendence catalyst holds; augment damage +50%",
	&"vessel": "every Max HP price moves halfway back to 1; +25% Power",
	&"archive": "every Binding card is Gilded or better; Abstain pays double",
}


static func bonus_text(family: StringName, held: int) -> String:
	if held >= CANON_AT:
		return String(CANON.get(family, ""))
	if held >= THESIS_AT:
		return String(THESIS.get(family, ""))
	return ""


## The plate's one family line: how many are held and what comes next.
## Kept to one line - the plate is a fixed face - and the bonus itself is
## told by awakening_line where there is room for it.
static func plate_line(family: StringName, held: int) -> String:
	var name := String(family).to_upper()
	if held >= CANON_AT:
		return "%s  ·  %d HELD  ·  CANON INSCRIBED" % [name, held]
	if held + 1 >= CANON_AT:
		return "%s  ·  %d HELD  ·  CANON NEXT" % [name, held]
	if held + 1 >= THESIS_AT:
		return "%s  ·  %d HELD  ·  THESIS NEXT" % [name, held]
	return "%s  ·  %d HELD  ·  THESIS AT %d" % [name, held, THESIS_AT]


## What inscribing a plate of `family` would awaken, or "" when nothing new.
static func awakening_line(family: StringName, held: int) -> String:
	var name := String(family).to_upper()
	if held + 1 == CANON_AT:
		return "INSCRIBING THIS AWAKENS THE %s CANON: %s" % [name, String(CANON.get(family, ""))]
	if held + 1 == THESIS_AT:
		return "INSCRIBING THIS AWAKENS THE %s THESIS: %s" % [name, String(THESIS.get(family, ""))]
	return ""
