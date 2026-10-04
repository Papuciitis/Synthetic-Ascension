extends RefCounted
class_name StoryLines

## Every line of the story layer past the opening (the 2026-10-04 story
## audit): district arrivals and departures, the Registry's bulletins, the
## Chronicler and the square's staff, the crowd, Bren's dispatches, the
## epitaphs and reconstruction cards, the Follower milestones, the records
## and the close of Area I. Presentation scripts never embed story text;
## StoryDirector picks from these pools.
##
## One line is a Dictionary:
##   id    stable; also the once-flag unless `key` names a shared one
##   text  may carry {tokens} (StoryDirector.tokens)
##   p     priority. BEAT (50) and above wins outright, highest first;
##         below it, eligible lines mix by weight `w` (default 1)
##   once  "" repeatable | "profile" | "attempt" | "account" (once per
##         closed account: relayed after a death, then spent)
##   when  conditions on StoryDirector.facts(): `k` equals (an Array means
##         one of), `k_min` / `k_max` bound a number
##
## Two voices, as in Segment 1: the institution (passive, procedural, polite
## menace) and the witnesses (plain, warm, concrete). No exclamation marks,
## no heroics, British spelling, curly quotes for quoted speech. Beka never
## appears in these pools; her one line stays with HubCrowd.

const BEAT := 50

# ------------------------------------------------------------------ districts

## Keyed by SegmentThemeData.id, plus "institution" (Segment 1) and "beyond"
## (past Segment 10, until the wall has themes of its own). `at` reads after
## "The account ends ...". `first` plays once per profile on arrival, then the
## `repeat` lines rotate. `departure` is the square's arrival notice after the
## district is cleared.
const DISTRICTS: Dictionary = {
	"institution": {
		"name": "The Institution", "at": "inside the institution", "chapter": "UNAUTHORISED",
		"first": "", "repeat": [],
		"departure_first": "They cleared a square for you. Nobody asked them to.",
		"departure": ["The movement holds this square tonight."],
	},
	"service_courtyards": {
		"name": "Service Courtyards", "at": "in the Service Courtyards", "chapter": "THE MORNING AFTER",
		"first": "By morning the report has been copied eleven times. The Registry has read none of them.",
		"repeat": [
			"Kitchens, coal stores, laundries. The institution's back rooms, still warm.",
			"The warrant is on every service door. Underneath it, someone has drawn the tree.",
		],
		"departure": ["The service yards fall quiet behind you. The copies do not."],
	},
	"checkpoint_lanes": {
		"name": "Checkpoint Lanes", "at": "in the Checkpoint Lanes", "chapter": "PRESENT YOUR DISCIPLINE",
		"first": "Every lane in this quarter asks the same question. You have no registered answer.",
		"repeat": ["The checkpoints sort the licensed from the unlicensed. They were never built to sort you."],
		"departure": ["The checkpoints still stand. They have stopped asking."],
	},
	"collapsed_ward": {
		"name": "Collapsed Ward", "at": "in the Collapsed Ward", "chapter": "THE WARDS FAIL IN PUBLIC",
		"first": "The wards here were built to recognise every discipline. No one told them what to do about yours.",
		"repeat": ["Half the wards in this quarter are dark. The Registry calls it maintenance."],
		"departure": ["Behind you, people stand in the street and look up at the broken wards."],
	},
	"civilian_cutthrough": {
		"name": "Civilian Cut-through", "at": "in the Civilian Cut-through", "chapter": "ORDINARY STREETS",
		"first": "Ordinary streets. Ordinary people at the windows, deciding what they saw.",
		"repeat": ["Doors close as you pass. Not all of them stay closed."],
		"departure": ["Someone has chalked the tree on the last door you passed."],
	},
	"inner_district_gate": {
		"name": "Inner District Gate", "at": "at the Inner District Gate", "chapter": "THE FIRST GATE",
		"first": "The inner district has one gate and one keeper. Both have been told about you.",
		"repeat": ["The inner gate has admitted registered disciplines only, for as long as anyone remembers."],
		"departure": ["The inner gate stands open. A great many people saw who opened it."],
	},
	"industrial_cutthrough": {
		"name": "Industrial Cut-through", "at": "in the Industrial Cut-through", "chapter": "THE WORKS STOP",
		"first": "The works make whatever the city asks for. Today they stopped to watch you pass.",
		"repeat": ["Someone in the foundries has been stamping the tree into every ingot."],
		"departure": ["Behind you, a foundry bell rings for a shift no one is working."],
	},
	"ruined_services": {
		"name": "Ruined Service District", "at": "in the Ruined Service District", "chapter": "WHAT THE CITY LEFT",
		"first": "Half this district was abandoned before you arrived. The other half is leaving with you.",
		"repeat": ["The Registry stopped maintaining these wards years ago. They still recognise everyone but you."],
		"departure": ["The empty district fills in behind you, with people who had nowhere else to go."],
	},
	"underpass_veins": {
		"name": "Underpass Veins", "at": "in the Underpass Veins", "chapter": "THE MOVEMENT'S MAP",
		"first": "Below the streets, the movement keeps its own map. Your name is on every page.",
		"repeat": ["The Registry's maps stop at street level. Theirs do not."],
		"departure": ["You surface. The routes close behind you, as they were built to."],
	},
	"canal_services": {
		"name": "Canal Service Routes", "at": "on the Canal Service Routes", "chapter": "THE LOCKS OPEN",
		"first": "The lock-keepers have been opening the gates for the tree sign since dawn.",
		"repeat": ["Canal water carries copies faster than couriers. The Registry has started dredging."],
		"departure": ["The locks close behind you. The copies are already downstream."],
	},
	"rail_yard": {
		"name": "Rail Yard Expanse", "at": "in the Rail Yard Expanse", "chapter": "THE GARRISON",
		"first": "The rail yard was built to move the city's goods. Today it moves soldiers.",
		"repeat": ["Containment has been relieved of the matter. You will notice the difference."],
		"departure": ["The trains have stopped. Nobody in the yard will say why."],
	},
	"military_staging": {
		"name": "Military Staging Ground", "at": "on the Military Staging Ground", "chapter": "THE GARRISON",
		"first": "Containment asked you to comply. The Garrison will not ask.",
		"repeat": ["Tents, drill lines, and a quartermaster's ledger with your description in it."],
		"departure": ["The staging ground empties behind you. Its orders did not anticipate this."],
	},
	"outer_wall": {
		"name": "Outer Wall Approaches", "at": "on the Outer Wall Approaches", "chapter": "THE WALL",
		"first": "The city's oldest ward is its wall. It was never built to hold against one person.",
		"repeat": ["From here the wall is the whole horizon. It has been for as long as the Registry has kept records."],
		"departure": ["The wall is close now. Past it, for the first time, there is sky."],
	},
	"siege_services": {
		"name": "Siege Service District", "at": "in the Siege Service District", "chapter": "THE SIEGE QUARTER",
		"first": "The siege quarter was built for an enemy outside the wall. Not for one inside it.",
		"repeat": ["Every store here was laid in for a war. The war arrived from the wrong side."],
		"departure": ["The siege stores burn behind you. No one is putting them out."],
	},
	"gate_district": {
		"name": "Gate District", "at": "in the Gate District", "chapter": "THE LAST GATE",
		"first": "One gate remains. Behind it, the Registry keeps the only signed copy of the official report.",
		"repeat": ["The last gate. Every record this city keeps has passed through it. Yours will not."],
		"departure": ["The last gate stands open behind you. It will not be closing again."],
	},
	"beyond": {
		"name": "Beyond the Wall", "at": "beyond the wall", "chapter": "BEYOND THE WALL",
		"first": "Past the wall, the Registry keeps no records. The accounts disagree from here.",
		"repeat": [
			"The road does not end. The accounts do.",
			"Every account that reaches this far tells it differently.",
			"Out here, the tree is carved on milestones nobody remembers setting.",
		],
		"departure": ["Another district behind you. No one out here has a name for it yet."],
	},
}

# ------------------------------------------------------------------ Registry

## The Registry stops printing the name as the movement starts saying it:
## the identity curve told backwards. Indexed by StoryDirector.registry_name.
const REGISTRY_NAME_FORMS: Array[String] = [
	"Researcher %s",                    # Segment 1
	"Researcher %s, unregistered",      # 2-3
	"the unregistered practitioner",    # 4-5
	"the synthetic event",              # 6-7
	"the event",                        # 8-9
	"[NAME WITHHELD]",                  # 10
]

## Keyed "seg<N>", or by district id where a segment has two faces. The first
## sighting on a profile is a card; later accounts read the `tip` line.
const BULLETINS: Dictionary = {
	"seg2": {"title": "REGISTRY BULLETIN",
		"body": "Subject: {registry_name}.\nTo be detained on sight.\nThe laboratory incident involved no recognised discipline.\nUnauthorised copies of the report are to be surrendered.",
		"tip": "To be detained on sight. Copies of the report are to be surrendered."},
	"seg3": {"title": "CHECKPOINT ORDER 12",
		"body": "Subject: {registry_name}.\nAll lanes are closed to unregistered practice.\nPresent your discipline at every checkpoint.\nThe subject has none to present.",
		"tip": "All lanes are closed to unregistered practice."},
	"collapsed_ward": {"title": "PUBLIC NOTICE",
		"body": "Subject: {registry_name}.\nWard failures in this district are scheduled maintenance.\nDisregard irregularities.\nDo not assemble beneath failed wards.",
		"tip": "Ward failures in this district are scheduled maintenance."},
	"civilian_cutthrough": {"title": "PUBLIC NOTICE",
		"body": "Subject: {registry_name}.\nResidents will remain indoors.\nThe branching-tree mark is not a recognised symbol.\nIt is to be removed where found.",
		"tip": "Residents will remain indoors. The tree mark is to be removed where found."},
	"seg5": {"title": "INNER GATE SEALED",
		"body": "Subject: {registry_name}.\nThe inner district is closed to unregistered practice.\nIts keeper has been informed.\nThe subject will be received at the gate.",
		"tip": "The inner district is closed. The subject will be received at the gate."},
	"seg6": {"title": "NOTICE OF PROHIBITION",
		"body": "Subject: {registry_name}.\nAssembly of more than three persons is prohibited.\nThe works will remain open.\nAttendance will be documented.",
		"tip": "Assembly of more than three persons is prohibited."},
	"seg7": {"title": "CORRESPONDENCE ORDER",
		"body": "Subject: {registry_name}.\nThe subject is not to be named in correspondence.\nLetters that name it will not be delivered.\nCouriers will be searched at every lock and stair.",
		"tip": "The subject is not to be named in correspondence."},
	"seg8": {"title": "MOBILISATION ORDER",
		"body": "Subject: {registry_name}.\nContainment is relieved of the matter.\nThe Garrison assumes authority.\nThe subject is to be ended, not detained.",
		"tip": "Containment is relieved of the matter. The Garrison assumes authority."},
	"seg9": {"title": "WALL ORDER",
		"body": "Subject: {registry_name}.\nThe outer wall has never been breached.\nIts record is not to be revised.",
		"tip": "The outer wall has never been breached. Its record is not to be revised."},
	"seg10": {"title": "FINAL NOTICE",
		"body": "Subject: {registry_name}.\nAll gates are sealed.\nThe record will be closed at the last gate.",
		"tip": "All gates are sealed. The record will be closed at the last gate."},
}
const BULLETIN_EYEBROW := "REGISTRY BULLETIN"
const BULLETIN_TIP_PREFIX := "REGISTRY BULLETIN • "
## Once per profile, the first time a run goes past Segment 10.
const BULLETIN_BEYOND := "No bulletin reaches past the wall."

# ------------------------------------------------------------------ the square

## The Chronicler is the only one who knows other accounts exist. Every
## account line shares one once-flag, so each closed account is relayed once,
## in its most telling form.
const CHRONICLER: Array[Dictionary] = [
	{"id": "chr_first", "p": 100, "once": "profile", "text": "I keep the witness accounts. Yours is still being written."},
	{"id": "chr_acc_seg1", "key": "chr_account", "p": 95, "once": "account", "when": {"accounts_min": 1, "last_seg": 1},
		"text": "The last account never left the institution. I kept it anyway."},
	{"id": "chr_acc_rite", "key": "chr_account", "p": 94, "once": "account", "when": {"accounts_min": 1, "last_rite": true},
		"text": "The last account ends inside the Rite. One breath from the road."},
	{"id": "chr_acc_boss", "key": "chr_account", "p": 94, "once": "account", "when": {"accounts_min": 1, "last_boss": 1},
		"text": "The last account ends at the last gate. Few accounts get that far."},
	{"id": "chr_acc_mini", "key": "chr_account", "p": 93, "once": "account", "when": {"accounts_min": 1, "last_boss": 0},
		"text": "The last account ends at the inner gate. Its keeper kept it."},
	{"id": "chr_acc_beyond", "key": "chr_account", "p": 93, "once": "account", "when": {"accounts_min": 1, "last_seg_min": 11},
		"text": "The last account went past the wall. I had to invent new margins."},
	{"id": "chr_acc_peak", "key": "chr_account", "p": 92, "once": "account", "when": {"accounts_min": 1, "last_peak_min": 1000},
		"text": "{last_witnesses} people signed the last account. I ran out of pages."},
	{"id": "chr_acc_recon", "key": "chr_account", "p": 91, "once": "account", "when": {"accounts_min": 1, "last_recon_min": 5},
		"text": "They rebuilt you {last_recon} times in the last account. I wrote down every one."},
	{"id": "chr_acc_cause", "key": "chr_account", "p": 90, "once": "account", "when": {"accounts_min": 1, "last_cause_known": true},
		"text": "The last account ends {last_cause_at}. The witnesses agree on that much."},
	{"id": "chr_acc_generic", "key": "chr_account", "p": 85, "once": "account", "when": {"accounts_min": 1},
		"text": "The last account ended {last_district_at}. I filed it with the others."},
	{"id": "chr_new_best", "p": 84, "once": "attempt", "when": {"accounts_min": 1, "new_best": true},
		"text": "No account I keep has come this far."},
	{"id": "chr_accounts_3", "p": 80, "once": "profile", "when": {"accounts_min": 3},
		"text": "Three accounts of the same night. They agree on the synthesis. Little else."},
	{"id": "chr_accounts_10", "p": 80, "once": "profile", "when": {"accounts_min": 10},
		"text": "Ten accounts now. The Registry still has only the one."},
	{"id": "chr_accounts_25", "p": 80, "once": "profile", "when": {"accounts_min": 25},
		"text": "Twenty-five accounts. One of them is true. I have stopped asking which."},
	{"id": "chr_area", "p": 78, "once": "profile", "when": {"area": true},
		"text": "One account reached the last gate and kept going. I read it twice."},
	{"id": "chr_race_human", "p": 70, "once": "profile", "when": {"race": "human"},
		"text": "No lineage, no patron, no pact. The Registry never had a box for you."},
	{"id": "chr_race_elf", "p": 70, "once": "profile", "when": {"race": "elf"},
		"text": "The Registry filed you under ‘inherited’ at birth. It has opened a new file."},
	{"id": "chr_race_dragonborn", "p": 70, "once": "profile", "when": {"race": "dragonborn"},
		"text": "Draconic lineage, registered. They expected fire. Not this."},
	{"id": "chr_race_warforged", "p": 70, "once": "profile", "when": {"race": "warforged"},
		"text": "The Registry's file on you says ‘not applicable’. I have crossed it out."},
	{"id": "chr_style_melee", "p": 20, "when": {"style": "melee"},
		"text": "The witnesses describe you up close. Closer than they wanted to be."},
	{"id": "chr_style_ranged", "p": 20, "when": {"style": "ranged"},
		"text": "The witnesses say they heard you before they saw you."},
	{"id": "chr_style_magic", "p": 20, "when": {"style": "magic"},
		"text": "Every witness describes the light differently."},
	{"id": "chr_sit", "p": 10, "text": "Sit. Nothing is asked here."},
	{"id": "chr_keep", "p": 10, "text": "I keep the witness accounts."},
	{"id": "chr_ink", "p": 10, "text": "Ink is cheap. Witnesses are not."},
	{"id": "chr_copies", "p": 10, "text": "The Registry burns its copies. We make more."},
	{"id": "chr_night", "p": 10, "text": "Every account begins on the same night."},
]

## The Acolyte answers the Doctrine plates. "A decision waits before the
## road." stays where it was (HubCrowd), ahead of everything here.
const ACOLYTE: Array[Dictionary] = [
	{"id": "aco_unsafe", "p": 85, "once": "attempt", "when": {"unsafe": true},
		"text": "There are few of them left. Spend them on staying alive."},
	{"id": "aco_canon", "p": 76, "once": "attempt", "when": {"canon": true},
		"text": "A canon. They have stopped arguing."},
	{"id": "aco_apotheosis", "p": 75, "once": "attempt", "when": {"stages": "apotheosis"},
		"text": "Divinity, made repeatable. They want to know if it repeats for them."},
	{"id": "aco_thesis", "p": 74, "once": "attempt", "when": {"thesis": true},
		"text": "Two plates of one family. They call it a thesis, and argue at the hearth."},
	{"id": "aco_doctrine", "p": 73, "once": "attempt", "when": {"stages": "doctrine"},
		"text": "The litany is three lines long. They have learned all three."},
	{"id": "aco_method_circuit", "p": 72, "once": "attempt", "when": {"method_family": "circuit"},
		"text": "You chose the instrument. They are already polishing it."},
	{"id": "aco_method_vessel", "p": 72, "once": "attempt", "when": {"method_family": "vessel"},
		"text": "You chose the body as the instrument. They worry about you."},
	{"id": "aco_method_archive", "p": 72, "once": "attempt", "when": {"method_family": "archive"},
		"text": "You chose the record. Every name in the square is written down."},
	{"id": "aco_apocrypha", "p": 71, "once": "attempt", "when": {"stages": "apocrypha"},
		"text": "What the first pass refused, the second will not."},
	{"id": "aco_transcend", "p": 65, "once": "attempt", "when": {"transcended_min": 1},
		"text": "Something you carry has become something else. They felt it from here."},
	{"id": "aco_believe", "p": 10, "text": "They believe. Spend it well."},
	{"id": "aco_outward", "p": 10, "text": "The Pattern grows outward from you."},
	{"id": "aco_count", "p": 10, "text": "Belief is not a debt. They still keep count."},
]

const EXCHANGER: Array[Dictionary] = [
	{"id": "ex_recovered", "p": 10, "text": "Recovered stock. Every piece cost someone."},
	{"id": "ex_routes", "p": 10, "text": "The routes held. Balance the exchange."},
	{"id": "ex_spare", "p": 10, "text": "Trade what the work can spare."},
	{"id": "ex_inner", "p": 10, "when": {"done_min": 5}, "text": "The inner routes are open. Different hands, different stock."},
	{"id": "ex_garrison", "p": 10, "when": {"done_min": 8}, "text": "Garrison stock. Do not ask how."},
	{"id": "ex_beyond", "p": 10, "when": {"done_min": 11}, "text": "Nothing out here carries a Registry stamp. Price accordingly."},
]

const QUARTERMASTER: Array[Dictionary] = [
	{"id": "qm_counted", "p": 10, "text": "Your kit. Counted, nothing added."},
	{"id": "qm_carry", "p": 10, "text": "Only what you carry leaves here."},
	{"id": "qm_straps", "p": 10, "text": "Check the straps. Then the road."},
	{"id": "qm_dust", "p": 10, "w": 2.0, "when": {"done_min": 4, "done_max": 5}, "text": "Ward-dust in every seam. Shake it out before the next lane."},
	{"id": "qm_canal", "p": 10, "w": 2.0, "when": {"district_done": "canal_services"}, "text": "Canal water ruins leather. I have done what I can."},
	{"id": "qm_wall", "p": 10, "w": 2.0, "when": {"done": 9}, "text": "Wall-mud. You are nearly out of the city."},
	{"id": "qm_beyond", "p": 10, "w": 2.0, "when": {"done_min": 11}, "text": "No more city on your boots. Something else."},
]

const SMITH: Array[Dictionary] = [
	{"id": "sm_hearth", "p": 10, "text": "Just the hearth tonight. Walk on."},
	{"id": "sm_holds", "p": 10, "text": "The hearth holds. So do we."},
	{"id": "sm_tree", "p": 10, "when": {"stages": "doctrine"}, "text": "They want the tree stamped on everything now. I stamp it."},
	{"id": "sm_garrison", "p": 10, "when": {"done_min": 8}, "text": "Garrison blades. Thinner than they look."},
	{"id": "sm_first_night", "p": 10, "when": {"done_min": 6}, "text": "The hearth has not gone out since the first night."},
]

## Crowd archetypes come from the painted sheet a believer wears
## (HubCrowd.CROWD_ART, "hub_crowd_<kind>"); `kind` is empty for the rig
## stand-ins. `tier` is the crowd's size band (StoryDirector.crowd_tier).
## Lines with `w` 2 are personal and come up more often. The first square
## is the night of the synthesis itself (done 1), so "this morning" waits
## for the square after the morning after (story review 2026-10-04).
const CROWD: Array[Dictionary] = [
	{"id": "cr_patron", "text": "No patron answered. You did."},
	{"id": "cr_held", "text": "The Pattern held. We saw it."},
	{"id": "cr_twice", "text": "I read the report. Twice."},
	{"id": "cr_work", "text": "We are following the work."},
	{"id": "cr_wards", "text": "The wards don't know us."},
	{"id": "cr_made", "text": "They said it couldn't be made."},
	{"id": "cr_heads", "when": {"done_max": 7}, "text": "Containment is still counting heads."},
	{"id": "cr_garrison_counts", "when": {"done_min": 8}, "text": "The Garrison counts differently."},
	{"id": "cr_sister", "text": "My sister ran supplies tonight."},
	{"id": "cr_listens", "text": "Quietly. The Registry still listens."},

	{"id": "cr_pilgrim_1", "w": 2.0, "when": {"kind": "pilgrim"}, "text": "I prayed for years. Nothing answered."},
	{"id": "cr_pilgrim_2", "w": 2.0, "when": {"kind": "pilgrim"}, "text": "I came looking for a patron. I stayed for the work."},
	{"id": "cr_pilgrim_3", "w": 2.0, "when": {"kind": "pilgrim"}, "text": "Every shrine I passed was locked."},
	{"id": "cr_labourer_1", "w": 2.0, "when": {"kind": "labourer"}, "text": "I carried the copies in a coal sack."},
	{"id": "cr_labourer_2", "w": 2.0, "when": {"kind": "labourer", "done_min": 5}, "text": "The works stopped at noon. We walked out."},
	{"id": "cr_labourer_3", "w": 2.0, "when": {"kind": "labourer"}, "text": "Heavy day. Good day."},
	{"id": "cr_washer_1", "w": 2.0, "when": {"kind": "washer"}, "text": "Everyone on my street has read it."},
	{"id": "cr_washer_2", "w": 2.0, "when": {"kind": "washer"}, "text": "They hang the bulletins. We take them down."},
	{"id": "cr_washer_3", "w": 2.0, "when": {"kind": "washer", "done_min": 8}, "text": "The Garrison's laundry talks, if you listen."},
	{"id": "cr_elder_1", "w": 2.0, "when": {"kind": "elder"}, "text": "My grandmother's magic was inherited. Mine was refused."},
	{"id": "cr_elder_2", "w": 2.0, "when": {"kind": "elder"}, "text": "I remember when the Registry was a single room."},
	{"id": "cr_elder_3", "w": 2.0, "when": {"kind": "elder"}, "text": "They told us it couldn't be made. They told us a lot."},
	{"id": "cr_courier_1", "w": 2.0, "when": {"kind": "courier", "done_min": 2}, "text": "Eleven routes this morning. Nine still open."},
	{"id": "cr_courier_2", "w": 2.0, "when": {"kind": "courier", "done_min": 7}, "text": "The canal locks open for the tree sign now."},
	{"id": "cr_courier_3", "w": 2.0, "when": {"kind": "courier"}, "text": "I don't read the letters. I just carry them."},
	{"id": "cr_clerk_1", "w": 2.0, "when": {"kind": "clerk"}, "text": "I filed the report. I kept a copy."},
	{"id": "cr_clerk_2", "w": 2.0, "when": {"kind": "clerk"}, "text": "I stamped refusals for twelve years."},
	{"id": "cr_clerk_3", "w": 2.0, "when": {"kind": "clerk"}, "text": "The badge came off easier than I thought."},
	{"id": "cr_baker_1", "w": 2.0, "when": {"kind": "baker"}, "text": "Bread for the square. Ask, if you are hungry."},
	{"id": "cr_baker_2", "w": 2.0, "when": {"kind": "baker"}, "text": "They count my flour now."},
	{"id": "cr_baker_3", "w": 2.0, "when": {"kind": "baker"}, "text": "I bake the tree into the crust. They never check."},
	{"id": "cr_mender_1", "w": 2.0, "when": {"kind": "mender", "done_min": 2}, "text": "The wards on my street failed this morning. Good."},
	{"id": "cr_mender_2", "w": 2.0, "when": {"kind": "mender"}, "text": "I mend lamps. Today I mended a ward to look broken."},
	{"id": "cr_mender_3", "w": 2.0, "when": {"kind": "mender"}, "text": "What the Registry built can be mended. Or not."},

	{"id": "cr_few_1", "when": {"tier": "few"}, "text": "There are not many of us. There are enough."},
	{"id": "cr_few_2", "when": {"tier": "few"}, "text": "I know every face here."},
	{"id": "cr_dozens", "when": {"tier": "dozens"}, "text": "New faces every hour."},
	{"id": "cr_hundreds_1", "when": {"tier": "hundreds"}, "text": "The square is filling."},
	{"id": "cr_hundreds_2", "when": {"tier": "hundreds"}, "text": "Whole families now, not just the brave ones."},
	{"id": "cr_thousands_1", "when": {"tier": "thousands"}, "text": "Whole streets came with us."},
	{"id": "cr_thousands_2", "when": {"tier": "thousands"}, "text": "They stopped counting us. We didn't."},
	{"id": "cr_quarter", "when": {"tier": "quarter"}, "text": "The square is the smallest part of us now."},

	{"id": "cr_name", "w": 1.5, "when": {"done_min": 4}, "text": "They have stopped printing your name. We have not stopped saying it."},
	{"id": "cr_instrument", "w": 1.5, "when": {"stages": "method"}, "text": "They say you chose an instrument."},
	{"id": "cr_prayers", "w": 1.5, "when": {"stages": "doctrine"}, "text": "My son asked if you hear prayers."},
	{"id": "cr_litany", "w": 1.5, "when": {"stages": "doctrine"}, "text": "We say the litany at the hearth now."},
	{"id": "cr_unspoken", "w": 1.5, "when": {"stages": "apotheosis"}, "text": "They have a name for you in the canal quarter. Not one they say here."},
	{"id": "cr_repeat", "w": 1.5, "when": {"stages": "apotheosis"}, "text": "Divinity, made repeatable. I would like to see it repeat."},
	{"id": "cr_inner_gate", "w": 1.5, "when": {"done_min": 5}, "text": "The inner gate is open. My street saw it."},
	{"id": "cr_soldiers", "w": 1.5, "when": {"done_min": 8}, "text": "Soldiers now. Not officers."},
	{"id": "cr_one_gate", "w": 2.0, "when": {"done": 9}, "text": "One gate left."},
	{"id": "cr_walked_out", "w": 1.5, "when": {"done_min": 10}, "text": "We walked out through the gate behind you. All of us."},
	{"id": "cr_beyond", "w": 1.5, "when": {"done_min": 11}, "text": "No one out here has heard of the Registry. Imagine that."},
]

# ------------------------------------------------------------------ Bren

## Dispatches after the segments where the work changed hands: the base line,
## then the sentence for the opening's response (Global.opening_response_id;
## "all" answers every response). The first account on a profile reads the
## full form; later accounts read `repeat`. Bren never knows other accounts.
const BREN_SPEAKER := "BREN"
const BREN_ROLE := "LATTICE SPECIALIST · BY COURIER"
const BREN_DISPATCHES: Dictionary = {
	1: {
		"base": "The sequences are out. Eleven copies by dawn, and the Registry has none of them.",
		"analytical": "Recognition was never a requirement. I keep writing that in the margins.",
		"decisive": "You wanted it quick. It was. Keep it that way.",
		"protective": "You told me I could still leave. I haven't. Neither have they.",
		"withdrawn": "You said nothing tonight. The copies are saying it for you.",
		"repeat": "Copies out. Routes open. Keep moving.",
	},
	3: {
		"base": "They are teaching the intervals in cellars. Badly. It still works.",
		"all": "Whatever instrument you chose, they are already copying it.",
		"repeat": "Cellars, attics, a bakery oven. The intervals hold everywhere.",
	},
	5: {
		"base": "The inner gate fell where half the district could see it. I could not have planned that. I did not plan it at all.",
		"analytical": "Witnesses are a better proof than any array.",
		"decisive": "Good. Faster now.",
		"protective": "Be careful at the next one. Please.",
		"withdrawn": "You still say nothing. The district is saying plenty.",
		"repeat": "Another gate. More witnesses than copies, now.",
	},
	9: {
		"base": "They have a name for you now. I will not use it. I knew you before it.",
		"analytical": "A god is a method with a congregation. I checked the arithmetic twice.",
		"decisive": "Finish it. Whatever it is.",
		"protective": "You can still leave. I know you won't. I wanted it written down that I said so.",
		"withdrawn": "You never said what you wanted. I think this was it.",
		"repeat": "They have a name for you. I still don't use it.",
	},
	10: {
		"base": "I am still not following you. The work simply went where you went.",
		"repeat": "Still not following you. Still following the work.",
	},
}

# ------------------------------------------------------------------ death

## The Game Over hint, written when the account closes (StoryDirector
## close_account). Ties at one priority are drawn by the account's seed, so
## the same death does not always read the same way.
const EPITAPHS: Array[Dictionary] = [
	{"id": "ep_first", "p": 100, "once": "profile", "when": {"acc_n": 1},
		"text": "The first account ends. What you bound to the Pattern remains."},
	{"id": "ep_best", "p": 95, "when": {"acc_new_best": true},
		"text": "No account has come further. The Chronicler will want every word."},
	{"id": "ep_tenth", "p": 94, "once": "profile", "when": {"acc_n": 10},
		"text": "The tenth account ends. The witnesses will not agree on how."},
	{"id": "ep_rite", "p": 90, "when": {"last_rite": true},
		"text": "It ends inside the Rite, one breath from the road."},
	{"id": "ep_boss", "p": 90, "when": {"last_boss": 1},
		"text": "It ends at the last gate. In this account, the gate held."},
	{"id": "ep_mini", "p": 90, "when": {"last_boss": 0},
		"text": "It ends at the inner gate. Its keeper keeps it, in this account."},
	{"id": "ep_seg1", "p": 90, "when": {"last_seg": 1},
		"text": "It ends inside the institution. The official report will call it an incident."},
	{"id": "ep_beyond", "p": 90, "when": {"last_seg_min": 11},
		"text": "It ends past the wall, in country the Registry never mapped."},
	{"id": "ep_recon", "p": 90, "when": {"last_recon_min": 5},
		"text": "They rebuilt you {last_recon} times. In the end, no one was left to remember the shape."},
	{"id": "ep_cause", "p": 90, "when": {"last_cause_known": true}, "text": "{last_cause_epitaph}"},
	{"id": "ep_peak", "p": 90, "when": {"last_peak_min": 10000},
		"text": "At its height, {last_witnesses} people believed this account. Belief was spent, not lost."},
	{"id": "ep_warforged", "p": 90, "once": "profile", "when": {"last_race": "warforged"},
		"text": "The Registry will file it under ‘not applicable’. The Chronicler will not."},
	{"id": "ep_generic", "p": 50, "when": {"last_peak_min": 2},
		"text": "The account ends {last_district_at}. {last_witnesses} witnesses carried it that far."},
	{"id": "ep_alone", "p": 50, "when": {"last_peak_max": 1},
		"text": "The account ends {last_district_at}, before many could carry it."},
	{"id": "ep_fallback", "p": 10, "text": "What you bound to the Pattern remains."},
]

## What ended an account, by the killer's EnemySpec id ("self" for health
## spent on purpose). `at` completes "The last account ends ..."; `epitaph`
## turns the archetype's own dossier quote back on it.
const CAUSES: Dictionary = {
	"enemy_grunt": {"at": "among the officers", "epitaph": "‘Drop the conduit.’ In this account, you never did."},
	"enemy_opening_officer": {"at": "among the officers", "epitaph": "‘Drop the conduit.’ In this account, you never did."},
	"enemy_runner": {"at": "where a runner cut you off", "epitaph": "‘You cannot outrun containment.’ This time, it was true."},
	"enemy_orbiter": {"at": "inside a closing perimeter", "epitaph": "‘Hold the perimeter.’ The perimeter held."},
	"enemy_spitter": {"at": "under containment bolts", "epitaph": "‘The specimen is still moving.’ The report will say it stopped."},
	"enemy_splitter": {"at": "in a crowd of fragments", "epitaph": "‘Every fragment still wants out.’ So did you."},
	"enemy_charger": {"at": "at the end of a charge", "epitaph": "‘Brace the corridor.’ The corridor held."},
	"enemy_bomber": {"at": "in a containment blast", "epitaph": "‘Seal it, whatever the cost.’ They paid it. So did you."},
	"enemy_summoner": {"at": "against their reserves", "epitaph": "‘Containment has reserves.’ This time, it had enough."},
	"enemy_summoned_minion": {"at": "against their reserves", "epitaph": "‘Containment has reserves.’ This time, it had enough."},
	"enemy_leech": {"at": "with the belief drained", "epitaph": "‘Belief is only another resource to drain.’ It drained enough."},
	"enemy_herald": {"at": "beneath a Herald's voice", "epitaph": "‘The institution still speaks with one voice.’ It had the last word, this time."},
	"enemy_chanter": {"at": "against the chant", "epitaph": "‘Hold the line; the line will be mended.’ It was. You were not."},
	"enemy_lurker": {"at": "the moment you stopped", "epitaph": "‘It waits for the moment you stop.’ You stopped."},
	"enemy_warden": {"at": "against a Warden's shield", "epitaph": "‘Nothing passes the line.’ Nothing did, this time."},
	"enemy_siphon": {"at": "with nothing in reserve", "epitaph": "‘It drinks what you were saving.’ You were saving yourself."},
	"enemy_sniper": {"at": "at the end of a long shot", "epitaph": "‘Trajectory confirmed.’ The report will call it a clean shot."},
	"enemy_brute": {"at": "against the outer line", "epitaph": "‘The outer line will hold.’ It held."},
	"enemy_containment_construct": {"at": "with the first construct", "epitaph": "The lattice made something. In this account, it outlived its maker."},
	"self": {"at": "by your own work", "epitaph": "Your own work, in the end. The report will not know what to call it."},
}

## The reconstruction card's body above "Followers lost / remaining", which
## StoryDirector appends unchanged.
const RECONSTRUCTION: Array[Dictionary] = [
	{"id": "rc_first", "p": 100, "once": "profile",
		"text": "Your followers preserve the sequence.\n\nTheir belief reconstructs {name} {rebuild_at}."},
	{"id": "rc_unsafe", "p": 95, "when": {"unsafe": true},
		"text": "This is the last reconstruction the movement can pay for.\n\nThe next collapse will find no one left to answer it."},
	{"id": "rc_rite", "p": 90, "when": {"death_rite": true},
		"text": "The Rite keeps most of what you wrote into it. Not all.\n\nTheir belief reconstructs {name} {rebuild_at}."},
	{"id": "rc_again", "p": 88, "when": {"deaths_min": 3},
		"text": "The sequence holds. Fewer people are holding it."},
	{"id": "rc_shape", "p": 10, "text": "They remember the shape of you. It is enough, this time."},
	{"id": "rc_witnesses", "p": 10, "text": "The witnesses hold the sequence while you are rebuilt."},
	{"id": "rc_pay", "p": 10, "text": "The movement pays for you again. It does not ask why."},
]

# ------------------------------------------------------------------ milestones

## The first upward crossing of each in an attempt, in the witness voice.
const MILESTONE_PREFIX := "WITNESS ACCOUNT • "
const MILESTONES: Array = [
	[10, "Ten people know your name, and say it anyway."],
	[100, "The tree sign appears on a wall in the service district. No one admits to painting it."],
	[1000, "The Registry prints a denial. It is read more widely than the report."],
	[10000, "Whole streets keep their lamps lit until you have passed."],
	[100000, "The city has stopped asking whether it can be made."],
	[1000000, "There are more witnesses than Registry clerks. There have been for some time."],
]

# ------------------------------------------------------------------ Area I close

## Segment 10's chapter card (StoryDirector.chapter_close_card). It bookends
## Segment I's UNAUTHORISED; its last line is the only place the name is said.
const CHAPTER_EYEBROW := "AREA I — THE CITY COMPLETE"
const CHAPTER_TITLE := "UNCONTAINED"
const CHAPTER_BUTTON := "Beyond the wall"
const CHAPTER_FIRST := "The last gate is open.\nNo record in the city will say how.\n{witnesses_line}\n\n{family_line}\n\nPast the gate, the Registry keeps no records.\nThe faithful already have a name for you.\n\nSyn'Tek."
const CHAPTER_REPEAT := "The last gate is open again.\n{witnesses_line}\n\n{family_line}\n\nPast the gate, the accounts disagree.\nThey agree on the name.\n\nSyn'Tek."
const CHAPTER_WITNESSES_FIRST := "%s people carried the other account to the wall."
const CHAPTER_WITNESSES_REPEAT := "%s people carried this account to the wall."
const CHAPTER_WITNESS_ONE := "One person carried the other account to the wall."
## By the Doctrine family with the most plates; "" on a tie or none.
const CHAPTER_FAMILY: Dictionary = {
	"circuit": "They say you built a god out of instruments, then taught the instruments to pray.",
	"vessel": "They say the body was only ever the first apparatus.",
	"archive": "They say you are the one account the Registry could not close.",
	"": "They say a great many things. The Chronicler is writing all of them down.",
}

# ------------------------------------------------------------------ identity

## The admission desk files the researcher (OpeningSequenceData). The opening's
## thesis is inherited, granted, borrowed, manufactured; ancestry is filed by
## the same rule.
const RACE_CLASSIFICATION: Dictionary = {
	"human": "Lineage: none recorded. Registered discipline: none (research staff).",
	"elf": "Lineage: sylvan, registered at birth. Registered discipline: none (research staff).",
	"dragonborn": "Lineage: draconic, registered at birth. Registered discipline: none (research staff).",
	"warforged": "Classification: constructed. Registered discipline: not applicable.",
}

# ------------------------------------------------------------------ records

## The Grimoire's RECORDS section (keys "record:<id>", Global.grimoire_note):
## a short codex reached by play. `hint` shows while a record is unknown.
const RECORDS: Array[Dictionary] = [
	{"id": "accounts", "name": "ACCOUNTS", "hint": "the first account closes",
		"rule": "Every attempt is an account of the same night: the first stable synthesis and what followed. Accounts end. The Chronicler files them. What was bound to the Pattern carries from one account to the next. Everything else is testimony."},
	{"id": "registry", "name": "THE REGISTRY", "hint": "pass the night admission desk",
		"rule": "The institution that records every recognised discipline and licenses the rest out of existence. Its wards recognise what it has registered. Its reports describe what it can explain."},
	{"id": "synthesis", "name": "THE FIRST STABLE SYNTHESIS", "hint": "complete the synthesis",
		"rule": "No patron answered. No bloodline awakened. The spell worked anyway. Every recognised school of magic is inherited, granted or borrowed. This one was made."},
	{"id": "containment", "name": "CONTAINMENT", "hint": "resist the arrest",
		"rule": "The Registry's enforcement arm. Its officers are trained to arrest. Since the night of the synthesis, they have been authorised to do more."},
	{"id": "bren", "name": "BREN", "hint": "Bren commits to the work",
		"rule": "Lattice Specialist. Carried the original sequences out through the records conduit on the night of the synthesis. Has not been seen since. The copies have been seen everywhere."},
	{"id": "pattern", "name": "THE PATTERN", "hint": "the first Follower",
		"rule": "What the movement calls synthetic magic, and what it calls itself. Followers preserve and spread it. Their belief keeps the work alive, and, when needed, its author."},
	{"id": "reconstruction", "name": "RECONSTRUCTION", "hint": "be reconstructed",
		"rule": "When the Pattern collapses, the people who remember it can rebuild its author where a Wardstone last recognised them. Each reconstruction costs belief. The movement can afford many. Not infinitely many."},
	{"id": "wardstones", "name": "WARDSTONES", "hint": "rewrite or attune a Wardstone",
		"rule": "The institution's wards were built to recognise every registered discipline. Rewritten, they recognise one more."},
	{"id": "report", "name": "THE OFFICIAL REPORT", "hint": "complete Segment I",
		"rule": "Lists one containment officer dead and an unclassified event. Makes no reference to synthetic magic. Has been read by fewer people than any of its unauthorised copies."},
	{"id": "rite", "name": "THE EXIT RITE", "hint": "clear a Rite",
		"rule": "Every district's last ward. It prohibits every recognised school of magic. Synthetic magic was never included, which is why it can be rewritten, and why the district notices."},
	{"id": "tree", "name": "THE TREE SIGN", "hint": "reach 100 Followers",
		"rule": "A small branching tree, stitched or pinned. The movement's only shared sign. The Registry has declared it unrecognised. It is recognised everywhere."},
	{"id": "method", "name": "METHOD", "hint": "inscribe a Method plate",
		"rule": "THE INSTRUMENT IS CHOSEN. The first inscription: how the work will be done, and by what."},
	{"id": "doctrine", "name": "DOCTRINE", "hint": "inscribe a Doctrine plate",
		"rule": "THE SYSTEM LEARNS TO WORSHIP. The second inscription. Here the following becomes a faith."},
	{"id": "apotheosis", "name": "APOTHEOSIS", "hint": "inscribe an Apotheosis plate",
		"rule": "DIVINITY IS MADE REPEATABLE. A miracle that can be repeated is no longer a miracle. It is a method with a congregation."},
	{"id": "inner_ward", "name": "THE INNER WARD", "hint": "open the inner gate",
		"rule": "For as long as anyone remembers, the inner gate admitted registered disciplines only. It stands open now."},
	{"id": "garrison", "name": "THE GARRISON", "hint": "reach Segment VIII",
		"rule": "When Containment failed, the city sent soldiers. Soldiers are not asked to detain."},
	{"id": "wall", "name": "THE OUTER WALL", "hint": "reach Segment IX",
		"rule": "The city's oldest ward. It has kept the city in for longer than it has kept anything out."},
	{"id": "last_gate", "name": "THE LAST GATE", "hint": "clear Segment X",
		"rule": "Where the Registry kept the only signed copy of the official report. Neither the gate's keeper nor the copy survived the account."},
	{"id": "beyond", "name": "BEYOND THE WALL", "hint": "reach Segment XI",
		"rule": "The Registry keeps no records past the wall. The accounts disagree from here."},
]
