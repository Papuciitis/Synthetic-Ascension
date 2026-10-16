extends RefCounted
## City-terminal dialogue. PeeP's creator, mechanism and physical form remain open.

const FIRST_SEEN_FLAG := "seen:peep_first_conversation"
const GREETING := "Ah. There you are."
const FIRST_BODY := "You wanted to get out.\n\nThat doesn't have to be the end.\n\nWhat you learnt is still yours. The people who helped you belong in the account.\n\nDo you give up?\n\nYou don't have to answer now."
const FIRST_CONVERSATION := GREETING + "\n\n" + FIRST_BODY
const REPEAT_BODY := "Another account. Do you want another beginning?"

const FINALITY := "This attempt has ended. Ordinary reconstruction can no longer continue it. Beginning another city attempt starts again at Segment 1."
const RETAINED := "You keep: discoveries and Library pages; story history; owned augments and equipped preferences; equipment in the Stash; committed Method, Doctrine and Apotheosis choices; lasting development and unspent Research."
const RESET := "You start again with: carried gear and bag cleared; Followers and Congregation reset; purchased tree powers reset; temporary augment upgrades restart from your prepared foundation; mutations, Transcendence, Duos, Facets and corruptions reset; a fresh world, checkpoints and pressure."
const MILESTONES := "Your committed choices remain, but their effects return only after completing Segments 3, 6 and 9 respectively."
const BREAK_HINT := "Take a break if you like. This decision will be here when you return."
