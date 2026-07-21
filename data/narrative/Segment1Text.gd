extends RefCounted
class_name Segment1Text

# All authored Segment 1 copy lives here so tone and wording can be revised
# without hunting through world-generation or UI scripts.

const AREA_TITLE := "AREA I — THE CITY"
const SEGMENT_TITLE := "SEGMENT I — UNAUTHORISED"

const OBJECTIVE_SYNTHESIS_TITLE := "COMPLETE THE SYNTHESIS"
const OBJECTIVE_SYNTHESIS_DETAIL := "Reach the synthesis array in the experimental laboratory."
const OBJECTIVE_ESCAPE_TITLE := "ESCAPE THE SEALED INSTITUTION"
const OBJECTIVE_ESCAPE_DETAIL := "Reach the archive wing before containment secures the research."
const OBJECTIVE_COURTYARD_TITLE := "REACH THE CONTAINMENT COURTYARD"
const OBJECTIVE_COURTYARD_DETAIL := "Rewrite the first Wardstone, then find the northern courtyard."
const OBJECTIVE_SERVICE_TITLE := "BREAK THE SERVICE CHECKPOINT"
const OBJECTIVE_SERVICE_DETAIL := "The assistant has the copied Pattern. Clear a route into the service district."
const OBJECTIVE_SECURITY_TITLE := "SURVIVE THE CONTAINMENT SQUAD"
const OBJECTIVE_WARDSTONE_2_TITLE := "REWRITE THE SECOND WARDSTONE"
const OBJECTIVE_WARDSTONE_2_DETAIL := "Find the service-district Wardstone before approaching the outer checkpoint."
const OBJECTIVE_CHECKPOINT_TITLE := "DISABLE THE OUTER CHECKPOINT"
const OBJECTIVE_CHECKPOINT_DETAIL := "Both rewritten Wardstones can now interrupt the final security seal."
const OBJECTIVE_GATE_TITLE := "REACH THE OUTER RITE"
const OBJECTIVE_GATE_DETAIL := "Follow the outer wall around the warehouse. The Rite lies beyond its blind side."
const OBJECTIVE_RITE_TITLE := "REWRITE THE RITE"
const OBJECTIVE_RITE_DETAIL := "Remain within the sigil while the Pattern alters it."

const SYNTHESIS_STABLE := "SYNTHESIS STABLE"
const SYNTHESIS_RESULT := "No patron answered. No bloodline awakened. The spell worked anyway."
const CONTAINMENT_NOTICE := "Unclassified thaumaturgical event detected.\nLaboratory containment initiated."
const FIRST_LETHAL := "Containment officer deceased.\nLethal force authorised."
const WARDSTONE_1 := "WARDSTONE REWRITTEN\nIts restoration sequence now recognises your synthetic signature."
const ASSISTANT_COMMITMENT := "ASSISTANT: ‘I am not following you. I am following the work.’\nThe copied Pattern disappears into the city. Followers: 1"
const RESONANCE_INTRO := "RESONANCE DETECTED\nSynthetic discharge—and one person's belief in the work—is interfering with the institution's wards."
const SECURITY_START := "Security checkpoint sealed. Containment squad inbound."
const SECURITY_CLEAR := "Containment squad broken. The service seal is losing coherence."
const WARDSTONE_2 := "WARDSTONE REWRITTEN\nThe Pattern accepts the alteration more easily this time."
const CHECKPOINT_DISABLED := "FINAL SECURITY CHECKPOINT DISABLED\nThe outer approach is open."
const RITE_LOGIC := "The Rite prohibits every recognised school of magic.\nSynthetic magic was never included."
const GATE_UNSEALED := "OUTER RITE DESTABILISED\nRewrite the Rite."

static func opening_body(mortal_name: String) -> String:
	var name := safe_name(mortal_name)
	return "Magic may be inherited.\nMagic may be granted.\nMagic may be borrowed.\n\nIt may not be manufactured.\n\nTonight, %s intends to prove otherwise." % name

static func completion_body(mortal_name: String) -> String:
	var name := safe_name(mortal_name)
	return "The laboratory is under lockdown.\nOne containment officer is dead.\nThe original research escaped institutional custody.\nThe city has issued a warrant for %s.\n\nNo public reference to synthetic magic appears in the official report.\n\nBy morning, copies of the report will begin circulating without authorisation." % name

static func safe_name(value: String) -> String:
	var cleaned := value.strip_edges()
	return cleaned if cleaned != "" else "the Arcanist"
