extends RefCounted
class_name OpeningSequenceData

## Single source of truth for the playable Segment 1 prologue. Presentation
## scripts receive copy from here and never embed story dialogue.

const HISTORICAL_EYEBROW := "ARCHIVAL RECORD — FIRST STABLE SYNTHESIS"
const HISTORICAL_LINES: Array[String] = [
	"Magic may be inherited.",
	"Magic may be granted.",
	"Magic may be borrowed.",
	"It may not be manufactured.",
]

const BREN_ROLE := "LATTICE SPECIALIST"
const BREN_OPENING := "The ward lattice changed when you connected the third sequence."
const BREN_BEFORE_SYNTHESIS := "Three alignments. Keep the intervals clean. Do not improvise until the array answers."
const BREN_AFTER_SYNTHESIS := "It worked."
const BREN_BARRIER_1 := "That barrier recognises every registered discipline."
const BREN_BARRIER_2 := "Or it did."
const BREN_PROPAGATION := "It propagated into the ward network."
const BREN_CONSTRUCT := "The lattice made something. Controlled first—then we learn what control means."
const BREN_OFFICER := "If they take it, they will erase everything."
const BREN_WAIT := "They are closing the array. Decide before they decide for us."
const BREN_AFTER_DEATH := "We cannot undo that."
const BREN_SEPARATION_1 := "I'll take the original sequences through the records conduit."
const BREN_SEPARATION_2 := "You draw containment toward the outer wing."
const BREN_SHORT := "Same interval. Less ceremony. I kept the array ready."

const SYNTHESIS_TITLE := "FIRST STABLE SYNTHESIS"
const SYNTHESIS_BODY := "No patron answered.\nNo bloodline awakened.\nThe spell worked anyway."
const DETECTION_TITLE := "UNCLASSIFIED THAUMATURGICAL EVENT DETECTED"
const DETECTION_BODY := "Unclassified thaumaturgical event detected.\nLaboratory containment initiated."
const ARREST_TITLE := "CONTAINMENT ORDER 7-C"
const ARREST_BODY := "Disengage from the apparatus. Surrender all records. Compliance will be documented."
const OFFICER_SECOND := "This is an arrest, not an execution. Do not make it one."
const ESCALATION_BODY := "Noncompliance recorded. Research seizure authorised."
const LETHAL_TITLE := "CONTAINMENT OFFICER DECEASED"
const LETHAL_BODY := "LETHAL RESPONSE AUTHORISED"
const FOLLOWER_TITLE := "FIRST FOLLOWER"
const FOLLOWER_BODY := "One person has chosen the Pattern over the institution.\n\nFollowers: 1\n\nFollowers are people committed to preserving and spreading the Pattern. Their belief, resources and memory keep the work alive."

const CALIBRATION_PROMPT := "Aim at the calibration target and attack."
const CONSTRUCT_PROMPT := "Contain the lattice construct."
const OFFICER_PROMPT := "The officer will seize the research. Attack to resist."
const INTERACT_PROMPT := "Move to the highlighted node • Space / Enter to align"
const SHORT_SYNTHESIS_BODY := "KNOWN PATTERN\nSTABILITY: REPRODUCIBLE"
const ALIGNMENT_STATUS: Array[String] = [
	"First interval stable • ward correction detected • Space / Enter at next node",
	"Second interval stable • lattice drift increasing • Space / Enter at next node",
	"Third interval stable • complete the sequence",
]

const RESPONSE_CHOICES: Array[Dictionary] = [
	{"id": &"analytical", "label": "It didn't recognise it.", "reaction": "Then recognition was never a requirement. Good. I can work with that."},
	{"id": &"decisive", "label": "Then we do this quickly.", "reaction": "Agreed. Clean intervals, no second attempt."},
	{"id": &"protective", "label": "You can still leave.", "reaction": "So can you. Neither of us has moved."},
	{"id": &"withdrawn", "label": "Remain silent.", "reaction": "All right. I will read the lattice, not you."},
]

static func safe_name(value: String) -> String:
	var cleaned := value.strip_edges()
	return cleaned if cleaned != "" else "the Arcanist"

static func historical_body(mortal_name: String) -> String:
	var lines := PackedStringArray(HISTORICAL_LINES)
	return "%s\n\nOn this night, %s intended to prove otherwise." % ["\n".join(lines), safe_name(mortal_name)]

static func officer_arrest(mortal_name: String) -> String:
	return "Researcher %s. Place the conduit on the floor and step away from the apparatus." % safe_name(mortal_name)

static func bren_final(mortal_name: String) -> String:
	return "I am not following you, %s.\n\nI am following the work." % safe_name(mortal_name)

static func choice_index_for_id(id: StringName) -> int:
	for index in range(RESPONSE_CHOICES.size()):
		if StringName(RESPONSE_CHOICES[index].get("id", &"")) == id:
			return index
	return -1

static func choice_id(index: int) -> StringName:
	if index < 0 or index >= RESPONSE_CHOICES.size():
		return &"withdrawn"
	return StringName(RESPONSE_CHOICES[index].get("id", &"withdrawn"))

static func choice_reaction(id: StringName) -> String:
	var index := choice_index_for_id(id)
	if index < 0:
		index = RESPONSE_CHOICES.size() - 1
	return String(RESPONSE_CHOICES[index].get("reaction", ""))
