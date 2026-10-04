extends RefCounted
class_name StoryDirector

## The story layer's picker and memory (the 2026-10-04 story audit; the
## pools are Hades-style). Every line in StoryLines carries an id, a priority,
## an optional once-scope and conditions on facts. pick() keeps the lines
## whose conditions hold and whose once-flag is unspent. A beat (priority at
## or above StoryLines.BEAT) wins outright, the highest first; otherwise the
## eligible lines are drawn by weight, never one of the pool's recent lines.
## Deterministic for a given rng: rng_for() seeds from the attempt's world
## seed and counts its draws in the attempt, so a run tells the same story
## when it is replayed, Continue included.
##
## Memory is one Dictionary, saved whole as SaveData.meta_story (wired beside
## meta_grimoire in Global.apply_save / write_save):
##   flags      profile once-flags ("seen:<key>") and marks ("area:1")
##   acc_flags  once-per-account flags, cleared when an account closes
##   accounts   accounts closed (attempts that ended in death)
##   best       the most segments any attempt has completed
##   best_known false on a profile older than the story until its first
##              account closes: its old depth was never recorded
##   last       the last closed account (close_account)
##   attempt    this attempt: flags, peak (of the Congregation: the
##              witnesses), recon, best_at_start, milestone, first_hub,
##              death {cause, rite, boss}, draws (rng_for's count per salt)
##              and recent (the reconstruction card's last lines)
## StoryLedger keeps it current from the run's signals, so nothing has to be
## caught at the moment Global.on_attempt_failed_die_die() wipes the attempt.

const STATE_VERSION := 1
## How many of a pool's last lines a repeatable draw avoids.
const RECENT := 3
const LEDGER_PATH := "res://core/systems/narrative/StoryLedger.gd"
const SEGMENT_PRESENTER_PATH := "res://core/systems/narrative/StorySegmentPresenter.gd"
const HUB_PRESENTER_PATH := "res://core/systems/narrative/StoryHubPresenter.gd"
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
## The first-time beats a profile with closed accounts has already lived
## (the first epitaph, meeting the Chronicler, the first reconstruction, the
## first square), spent when its history seeds the story (_seed_from_history).
const HISTORY_SPENT_FLAGS: Array[String] = ["seen:ep_first", "seen:chr_first", "seen:rc_first", "departure:institution"]

static var state: Dictionary = {}
static var _ledger: RefCounted = null
## Staff key -> the ids it said last (in memory only, forgotten with the
## attempt and the profile). The reconstruction card's live in the attempt.
static var _recent: Dictionary = {}
## Lines waiting for a presenter: {"kind", "text"}.
static var _pending: Array = []
## An account closed and no new attempt has begun: the Game Over may read it.
static var _just_closed: bool = false
## The state has every key (set by _normalise, cleared when it is replaced),
## so the hot paths (a kill moves the Followers) skip the check.
static var _whole: bool = false
## Tests pin whether story cards may block: -1 decides (cards_allowed), 1
## forces them on, 0 off.
static var cards_override: int = -1


# ---------------------------------------------------------------- memory

## Starts listening (once per session) and fills in any missing state.
static func ensure() -> void:
	_normalise()
	if _ledger == null:
		var script := load(LEDGER_PATH) as Script
		if script != null:
			_ledger = script.new()
			_ledger.call("bind")


## Adopts a profile's saved story (Global.apply_save). `history` is what the
## save itself knows ({"runs": total_runs, "active": attempt_active}); a
## story saved before the layer existed (no "v") is seeded from it.
static func load_state(meta: Dictionary, history: Dictionary = {}) -> void:
	state = meta.duplicate(true) if meta != null else {}
	if not state.has("v"):
		_seed_from_history(history)
	_whole = false
	_just_closed = false
	_pending.clear()
	_recent.clear()
	ensure()


## A profile older than the story layer loaded with an empty story, so its
## next death was "ACCOUNT I... The first account ends." whatever its Archives
## card said (story review 2026-10-04). Every attempt it started ended in
## death (there is no abandon path), so its closed accounts are its runs,
## less the one still under way. The beats that would deny that history are
## spent; the Chronicler relays nothing until an account closes under the
## ledger, since none of the old ones was written down; and no line claims a
## new best until then, since the old depth was never recorded either. A
## first run still under way is left as it is: its death is the first.
static func _seed_from_history(history: Dictionary) -> void:
	var closed := int(history.get("runs", 0)) - (1 if bool(history.get("active", false)) else 0)
	if closed <= 0:
		return
	state["accounts"] = closed
	var flags: Array = state.get("flags") if state.get("flags") is Array else []
	for flag in HISTORY_SPENT_FLAGS:
		if not flags.has(flag):
			flags.append(flag)
	var acc_flags: Array = []
	for entry in StoryLines.CHRONICLER:
		var line: Dictionary = entry
		var when: Dictionary = line.get("when", {})
		var once := String(line.get("once", ""))
		# A count already passed ("Three accounts of the same night").
		if once == "profile" and when.size() == 1 and when.has("accounts_min") and int(when["accounts_min"]) <= closed and not flags.has("seen:" + once_key(line)):
			flags.append("seen:" + once_key(line))
		elif once == "account" and not acc_flags.has(once_key(line)):
			acc_flags.append(once_key(line))
	state["flags"] = flags
	state["acc_flags"] = acc_flags
	state["best_known"] = false


## What Global.write_save stores in SaveData.meta_story.
static func state_for_save() -> Dictionary:
	_normalise()
	return state.duplicate(true)


static func _normalise() -> void:
	if _whole and state.has("attempt"):
		return
	if not state.has("v"):
		state["v"] = STATE_VERSION
	for key in ["flags", "acc_flags"]:
		if not (state.get(key) is Array):
			state[key] = []
	for key in ["accounts", "best"]:
		state[key] = maxi(0, int(state.get(key, 0)))
	if not (state.get("best_known") is bool):
		state["best_known"] = true
	if not (state.get("last") is Dictionary):
		state["last"] = {}
	if not (state.get("attempt") is Dictionary):
		state["attempt"] = _fresh_attempt()
	var a: Dictionary = state["attempt"]
	var fresh := _fresh_attempt()
	for key in fresh.keys():
		if not a.has(key):
			a[key] = fresh[key]
	_whole = true


static func _fresh_attempt() -> Dictionary:
	return {"flags": [], "peak": 0, "recon": 0, "best_at_start": int(state.get("best", 0)), "milestone": 0,
		"first_hub": 0, "death": {"cause": "", "rite": false, "boss": -1}, "draws": {}, "recent": {}}


static func attempt() -> Dictionary:
	_normalise()
	return state["attempt"]


static func has_flag(flag: String) -> bool:
	_normalise()
	return (state["flags"] as Array).has(flag)


static func add_flag(flag: String) -> bool:
	_normalise()
	if (state["flags"] as Array).has(flag):
		return false
	(state["flags"] as Array).append(flag)
	_mark_for_save()
	return true


static func _attempt_flag(flag: String) -> bool:
	return (attempt()["flags"] as Array).has(flag)


static func _add_attempt_flag(flag: String) -> void:
	var flags: Array = attempt()["flags"]
	if not flags.has(flag):
		flags.append(flag)
		_mark_for_save()


## A new flag is a line said or a beat spent, often in the square after
## HubWorld has saved: nothing else need dirty the profile before the window
## closes, and Continue then replayed the Chronicler's relay or the first
## square's line (story review 2026-10-04). Only marks the profile dirty;
## the write waits for a safe point (Global.request_autosave).
static func _mark_for_save() -> void:
	if Global != null:
		Global.request_autosave()


## Lines a presenter shows when it next can (Follower milestones).
static func take_pending() -> Array:
	var out := _pending.duplicate()
	_pending.clear()
	return out


static func push_pending(kind: String, text: String) -> void:
	_pending.append({"kind": kind, "text": text})


# ---------------------------------------------------------------- the attempt

## A new attempt begins (Global.balance_attempt_boundary "restarted").
static func begin_attempt() -> void:
	_normalise()
	state["attempt"] = _fresh_attempt()
	_just_closed = false
	_pending.clear()
	_recent.clear()


## The run ended in death (balance_attempt_boundary "failed"), emitted before
## Global wipes the attempt: the segment, the seed and the Doctrine are all
## still there. Writes the account, its epitaph, and starts the next record.
static func close_account() -> Dictionary:
	_normalise()
	var a := attempt()
	var seg := 1
	var world_seed := 0
	var race := ""
	var style := ""
	var response := ""
	if Global != null:
		seg = maxi(1, Global.attempt_segment)
		world_seed = Global.attempt_world_seed
		race = String(Global.selected_race_id)
		style = String(Global.selected_style_id)
		response = String(Global.opening_response_id)
	var death: Dictionary = a.get("death", {})
	var accounts := int(state["accounts"])
	var account := {
		"n": accounts + 1,
		"segment": seg,
		"district": district_id(seg, world_seed),
		"cause": String(death.get("cause", "")),
		"rite": bool(death.get("rite", false)),
		"boss": int(death.get("boss", -1)),
		# Read before on_attempt_failed_die_die() zeroes the Congregation.
		"peak": witnesses(),
		"recon": int(a.get("recon", 0)),
		"race": race,
		"style": style,
		"response": response,
		"family": dominant_family(),
		"new_best": _is_new_best(seg, a),
		"unix": int(Time.get_unix_time_from_system()),
	}
	account["seed"] = int(hash([world_seed, accounts, seg]))
	state["accounts"] = accounts + 1
	state["acc_flags"] = []
	state["last"] = account
	# The account's own depth: on a profile older than the story the segments
	# its run cleared before the update were never noted, and from here on
	# the best is known.
	state["best"] = maxi(int(state["best"]), seg - 1)
	state["best_known"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(account["seed"])
	account["epitaph"] = say(StoryLines.EPITAPHS, facts(), rng)
	state["attempt"] = _fresh_attempt()
	_just_closed = true
	_pending.clear()
	note_record("accounts")
	return account


static func last_account() -> Dictionary:
	_normalise()
	return state["last"]


## Whether an attempt in `seg` has come further than any account before it:
## never on the first account, nor while the profile's best is unknown.
static func _is_new_best(seg: int, a: Dictionary) -> bool:
	return int(state["accounts"]) > 0 and bool(state["best_known"]) and seg - 1 > int(a.get("best_at_start", 0))


## A segment was completed (Global.balance_segment_completed).
static func note_segment_completed(completed: int) -> void:
	_normalise()
	state["best"] = maxi(int(state["best"]), completed)
	note_record("rite")
	if completed == 1:
		note_record("report")
	if completed >= _final_segment():
		add_flag("area:1")
		if completed == _final_segment():
			note_record("last_gate")


## The player died (RunEvents.player_life_event "death"): what did it, and
## whether it happened in the Rite or a set-piece fight.
static func note_death(cause: String, rite: bool, boss: int) -> void:
	attempt()["death"] = {"cause": cause, "rite": rite, "boss": boss}


## The witnesses of this attempt: the Congregation, every Follower it
## recruited, which spending never lowers (Global.attempt_congregation). The
## peak noted here keeps a run saved before the Congregation existed whole.
static func witnesses() -> int:
	var recruited := Global.attempt_congregation if Global != null else 0
	return maxi(int(attempt().get("peak", 0)), recruited)


## The player was rebuilt (a death the Followers paid for and survived;
## StoryLedger skips the charge that ends the run).
static func note_reconstruction() -> void:
	var a := attempt()
	a["recon"] = int(a.get("recon", 0)) + 1
	note_record("reconstruction")


## Recruits moved the Congregation from `old` to `now` (StoryLedger): the
## peak of witnesses, and the first upward crossing of a milestone in this
## attempt is a witness line (the highest one, when a gain crosses several
## at once).
static func note_recruits(old: int, now: int) -> void:
	var a := attempt()
	a["peak"] = maxi(int(a.get("peak", 0)), now)
	var reached := int(a.get("milestone", 0))
	for i in range(StoryLines.MILESTONES.size() - 1, -1, -1):
		var row: Array = StoryLines.MILESTONES[i]
		var threshold := int(row[0])
		if old < threshold and now >= threshold and threshold > reached:
			a["milestone"] = threshold
			push_pending("milestone", StoryLines.MILESTONE_PREFIX + String(row[1]))
			if threshold >= 100:
				note_record("tree")
			break


## First hub of the attempt: which completed segment it followed.
static func note_hub_arrival() -> void:
	var a := attempt()
	if int(a.get("first_hub", 0)) <= 0:
		a["first_hub"] = completed_segment()


## Records that progress reached (polled by the presenters; cheap).
## `segment` is the one being played (StorySegmentPresenter): the depth
## records ("reach Segment VIII") wait for it. The square passes none, since
## there Global.attempt_segment already names a segment not yet played, and
## those records unlocked one hub early (story review 2026-10-04).
static func note_progress(segment: int = 0) -> void:
	if Global == null:
		return
	var milestones := {"admitted": ["registry"], "synthesis": ["synthesis"], "first_confrontation": ["containment"],
		"assistant_commitment": ["bren", "pattern"], "wardstone_1": ["wardstones"]}
	for milestone in milestones.keys():
		if Global.has_segment1_milestone(StringName(milestone)):
			for id in milestones[milestone]:
				note_record(id)
	for stage in ["method", "doctrine", "apotheosis"]:
		if Global.attempt_doctrine_stage_ids.has(stage) or Global.attempt_doctrine_stage_ids.has(StringName(stage)):
			note_record(stage)
	if segment >= 8:
		note_record("garrison")
	if segment >= 9:
		note_record("wall")
	if segment > _final_segment():
		note_record("beyond")


static func note_record(id: String) -> void:
	if Global != null and Global.has_method("grimoire_note"):
		Global.grimoire_note("record:%s" % id)


## The Grimoire's RECORDS entries, in its catalogue shape.
static func record_catalogue() -> Array:
	var out: Array = []
	for record in StoryLines.RECORDS:
		out.append({"key": "record:%s" % String(record["id"]), "section": "RECORDS",
			"name": String(record["name"]), "rule": String(record["rule"]), "hint": String(record["hint"])})
	return out


# ---------------------------------------------------------------- places

static func district_id(segment: int, world_seed: int) -> String:
	if segment <= 1:
		return "institution"
	if segment > _final_segment():
		return "beyond"
	var theme := SegmentThemePicker.get_theme(segment, world_seed)
	return String(theme.id) if theme != null else "service_courtyards"


static func district_name(id: String) -> String:
	return String((StoryLines.DISTRICTS.get(id, {}) as Dictionary).get("name", ""))


## "in the Checkpoint Lanes", "beyond the wall": reads after "ends".
static func district_at(id: String) -> String:
	return String((StoryLines.DISTRICTS.get(id, {}) as Dictionary).get("at", ""))


## The segment just completed: in the square, Global.attempt_segment has
## already moved on to the next one.
static func completed_segment() -> int:
	return maxi(0, Global.attempt_segment - 1) if Global != null else 0


## The save card's route line ("Area 1 · Segment 4"); past the last gate the
## city is behind the run.
static func route_label(segment: int) -> String:
	if segment > _final_segment():
		return "Beyond the Wall · Segment %d" % segment
	return "Area 1 · Segment %d" % segment


static func registry_name(segment: int, mortal: String) -> String:
	var forms := StoryLines.REGISTRY_NAME_FORMS
	var index := 0
	if segment >= _final_segment():
		index = 5
	elif segment >= 8:
		index = 4
	elif segment >= 6:
		index = 3
	elif segment >= 4:
		index = 2
	elif segment >= 2:
		index = 1
	var form := forms[index]
	return form % mortal if form.contains("%s") else form


static func _final_segment() -> int:
	return Global.FINAL_SEGMENT if Global != null else 10


# ---------------------------------------------------------------- facts

## Everything a line can be conditioned on, flat. `extra` overrides.
static func facts(extra: Dictionary = {}) -> Dictionary:
	_normalise()
	var f := {}
	var seg := 1
	var world_seed := 0
	var followers := 0
	if Global != null:
		seg = maxi(1, Global.attempt_segment)
		world_seed = Global.attempt_world_seed
		followers = Global.followers
		f["deaths"] = Global.attempt_deaths_this_segment
		f["race"] = String(Global.selected_race_id)
		f["style"] = String(Global.selected_style_id)
		f["response"] = String(Global.opening_response_id)
		f["pending"] = Global.pending_big_choice
		f["unsafe"] = not Global.reconstruction_survivable(followers)
		f["transcended"] = Global.attempt_augment_transcended.size()
		_doctrine_facts(f)
	f["seg"] = seg
	f["done"] = seg - 1
	f["district"] = district_id(seg, world_seed)
	f["district_done"] = district_id(seg - 1, world_seed) if seg > 1 else ""
	f["followers"] = followers
	var a := attempt()
	f["peak"] = witnesses()
	f["recon"] = int(a.get("recon", 0))
	f["death_rite"] = bool((a.get("death", {}) as Dictionary).get("rite", false))
	var accounts := int(state["accounts"])
	f["accounts"] = accounts
	f["area"] = has_flag("area:1")
	f["first_hub"] = seg > 1 and int(a.get("first_hub", 0)) == seg - 1
	f["new_best"] = _is_new_best(seg, a)
	var last: Dictionary = state["last"]
	f["acc_n"] = int(last.get("n", 0))
	f["acc_new_best"] = bool(last.get("new_best", false))
	f["last_seg"] = int(last.get("segment", 0))
	f["last_district"] = String(last.get("district", ""))
	f["last_cause"] = String(last.get("cause", ""))
	f["last_cause_known"] = StoryLines.CAUSES.has(String(last.get("cause", "")))
	f["last_rite"] = bool(last.get("rite", false))
	f["last_boss"] = int(last.get("boss", -1)) if not last.is_empty() else -1
	f["last_peak"] = int(last.get("peak", 0))
	f["last_recon"] = int(last.get("recon", 0))
	f["last_race"] = String(last.get("race", ""))
	f.merge(extra, true)
	return f


static func _doctrine_facts(f: Dictionary) -> void:
	var stages: Array = []
	var ids: Dictionary = Global.attempt_doctrine_stage_ids
	for stage in ids.keys():
		var stage_id := String(stage)
		stages.append("apocrypha" if stage_id.begins_with(Global.APOCRYPHA_PREFIX) else stage_id)
		if stage_id in ["method", "doctrine", "apotheosis"] and Global.major_choice_db != null:
			var definition := Global.major_choice_db.get_def(StringName(str(ids[stage])))
			if definition != null:
				f[stage_id + "_family"] = String(definition.family_id)
	f["stages"] = stages
	var counts := Global.doctrine_family_counts()
	var top := 0
	for value in counts.values():
		top = maxi(top, int(value))
	f["thesis"] = top >= 2
	f["canon"] = top >= 3
	f["family"] = _dominant(counts)


## The Doctrine family with the most plates this attempt; "" on a tie or none.
static func dominant_family() -> String:
	if Global == null:
		return ""
	return _dominant(Global.doctrine_family_counts())


static func _dominant(counts: Dictionary) -> String:
	var best := ""
	var best_n := 0
	var tied := false
	for family in counts.keys():
		var n := int(counts[family])
		if n > best_n:
			best = String(family)
			best_n = n
			tied = false
		elif n == best_n and n > 0:
			tied = true
	return "" if tied else best


## The words a line's {tokens} become.
static func tokens(f: Dictionary) -> Dictionary:
	var mortal := OpeningSequenceData.safe_name(Global.mortal_name if Global != null else "")
	var seg := int(f.get("seg", 1))
	var cause: Dictionary = StoryLines.CAUSES.get(String(f.get("last_cause", "")), {})
	return {
		"name": mortal,
		"segment": roman(seg),
		"district": district_name(String(f.get("district", ""))),
		"district_at": district_at(String(f.get("district", ""))),
		"witnesses": grouped(int(f.get("peak", 0))),
		"followers": grouped(int(f.get("followers", 0))),
		"registry_name": registry_name(seg, mortal),
		"last_district": district_name(String(f.get("last_district", ""))),
		"last_district_at": district_at(String(f.get("last_district", ""))),
		"last_witnesses": grouped(int(f.get("last_peak", 0))),
		"last_recon": str(int(f.get("last_recon", 0))),
		"last_cause_at": String(cause.get("at", "")),
		"last_cause_epitaph": String(cause.get("epitaph", "")),
		"rebuild_at": String(f.get("rebuild_at", "")),
	}


static func format(text: String, words: Dictionary) -> String:
	return text.format(words)


# ---------------------------------------------------------------- picking

## Whether every condition in `when` holds for `f`.
static func matches(when: Dictionary, f: Dictionary) -> bool:
	for raw_key in when.keys():
		var key := String(raw_key)
		var want: Variant = when[raw_key]
		if key.ends_with("_min"):
			if float(f.get(key.trim_suffix("_min"), 0)) < float(want):
				return false
		elif key.ends_with("_max"):
			if float(f.get(key.trim_suffix("_max"), 0)) > float(want):
				return false
		elif key == "flag":
			if not has_flag(String(want)):
				return false
		elif key == "not_flag":
			if has_flag(String(want)):
				return false
		else:
			var have: Variant = f.get(key, null)
			if have is Array:
				var wanted: Array = want if want is Array else [want]
				var any := false
				for item in wanted:
					if (have as Array).has(String(item)):
						any = true
				if not any:
					return false
			elif want is Array:
				if not (want as Array).has(have):
					return false
			elif typeof(want) == TYPE_BOOL:
				if (have != null and bool(have)) != bool(want):
					return false
			elif typeof(want) == TYPE_INT or typeof(want) == TYPE_FLOAT:
				if have == null or float(have) != float(want):
					return false
			elif String(have if have != null else "") != String(want):
				return false
	return true


static func priority(line: Dictionary) -> int:
	return int(line.get("p", 10))


static func once_key(line: Dictionary) -> String:
	return String(line.get("key", line.get("id", "")))


static func is_spent(line: Dictionary) -> bool:
	var key := once_key(line)
	match String(line.get("once", "")):
		"profile":
			return has_flag("seen:" + key)
		"attempt":
			return _attempt_flag(key)
		"account":
			return (state.get("acc_flags", []) as Array).has(key)
	return false


static func spend(line: Dictionary) -> void:
	var key := once_key(line)
	match String(line.get("once", "")):
		"profile":
			add_flag("seen:" + key)
		"attempt":
			_add_attempt_flag(key)
		"account":
			_normalise()
			if not (state["acc_flags"] as Array).has(key):
				(state["acc_flags"] as Array).append(key)
				_mark_for_save()


## The line to say from `pool`, or {} when nothing fits. A beat wins by
## priority (ties drawn by weight); below BEAT everything eligible is drawn
## by weight, skipping `recent` ids while anything else is left. `do_spend`
## false only peeks.
static func pick(pool: Array, f: Dictionary, rng: RandomNumberGenerator, recent: Array = [], do_spend: bool = true) -> Dictionary:
	_normalise()
	var eligible: Array = []
	var top := -1
	for entry in pool:
		var line: Dictionary = entry
		if not matches(line.get("when", {}) as Dictionary, f) or is_spent(line):
			continue
		eligible.append(line)
		top = maxi(top, priority(line))
	if eligible.is_empty():
		return {}
	var candidates: Array = []
	if top >= StoryLines.BEAT:
		for line in eligible:
			if priority(line) == top:
				candidates.append(line)
	else:
		for line in eligible:
			if not recent.has(String(line.get("id", ""))):
				candidates.append(line)
		if candidates.is_empty():
			candidates = eligible
	var total := 0.0
	for line in candidates:
		total += maxf(0.0, float(line.get("w", 1.0)))
	var chosen: Dictionary = candidates[0]
	if total > 0.0:
		var roll := rng.randf() * total
		for line in candidates:
			roll -= maxf(0.0, float(line.get("w", 1.0)))
			if roll <= 0.0:
				chosen = line
				break
	if do_spend:
		spend(chosen)
	return chosen


## pick() and its text with the tokens filled in ("" when nothing fits).
static func say(pool: Array, f: Dictionary, rng: RandomNumberGenerator, recent: Array = []) -> String:
	var line := pick(pool, f, rng, recent)
	return format(String(line.get("text", "")), tokens(f)) if not line.is_empty() else ""


## A fresh rng for `salt`, seeded from the attempt's world seed and how many
## draws the salt has taken in this attempt. The count is saved with the
## attempt, so a Continue draws what the unbroken run would have, and a new
## attempt or another profile counts afresh (story review 2026-10-04: the
## count was per process, so it leaked across both and restarted from zero
## on a relaunch).
static func rng_for(salt: String) -> RandomNumberGenerator:
	var draws: Dictionary = attempt()["draws"]
	var n := int(draws.get(salt, 0))
	draws[salt] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash([Global.attempt_world_seed if Global != null else 0, salt, n]))
	return rng


## Keeps `line` among the last RECENT ids `pool_name` said, in `memory`
## (_recent for the staff, the attempt's "recent" for the card).
static func _remember(memory: Dictionary, pool_name: String, line: Dictionary) -> void:
	var recent: Array = memory.get(pool_name, [])
	recent.append(String(line.get("id", "")))
	while recent.size() > RECENT:
		recent.pop_front()
	memory[pool_name] = recent


# ---------------------------------------------------------------- surfaces

## Whether the story may stop the game for a card (a first bulletin, Bren's
## dispatch). Never headless (no one there to dismiss it: the suites and
## benchmarks run the real scenes) and never on a developer run; the same
## words then arrive as tips and notices, or wait for a real session.
static func cards_allowed() -> bool:
	if cards_override >= 0:
		return cards_override == 1
	if DisplayServer.get_name() == "headless":
		return false
	return Global == null or not Global.debug_dev_mode


## The loading card's second line: the district a segment card leads into.
static func loading_subtitle(title: String) -> String:
	if Global == null or title.is_empty() or title != Global._scene_title(Global.PATH_GAME):
		return ""
	return district_name(district_id(Global.attempt_segment, Global.attempt_world_seed))


## What a segment says as the run becomes playable, once per attempt:
## {"tip": arrival line, "bulletin": {title, body} the first time on the
## profile, "bulletin_tip": the repeat form}. {} for Segment 1 (the opening
## is its arrival) and when this attempt already arrived here. Without
## `cards` the bulletin is always the tip, and its first card is kept.
static func arrival(segment: int, cards: bool = true) -> Dictionary:
	if segment <= 1 or Global == null:
		return {}
	var mark := "arrival:%d" % segment
	if _attempt_flag(mark):
		return {}
	_add_attempt_flag(mark)
	var id := district_id(segment, Global.attempt_world_seed)
	var district: Dictionary = StoryLines.DISTRICTS.get(id, {})
	var out := {"tip": "", "bulletin": {}, "bulletin_tip": ""}
	var first := String(district.get("first", ""))
	var repeat: Array = district.get("repeat", [])
	if first != "" and add_flag("arrive:" + id):
		out["tip"] = first
	elif not repeat.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(hash([Global.attempt_world_seed, "arrival", segment]))
		out["tip"] = String(repeat[rng.randi() % repeat.size()])
	else:
		out["tip"] = first
	if segment > _final_segment():
		if add_flag("bulletin:beyond"):
			out["bulletin_tip"] = StoryLines.BULLETIN_TIP_PREFIX + StoryLines.BULLETIN_BEYOND
		return out
	var key := "seg%d" % segment
	if not StoryLines.BULLETINS.has(key):
		key = id
	var bulletin: Dictionary = StoryLines.BULLETINS.get(key, {})
	if bulletin.is_empty():
		return out
	var words := tokens(facts())
	if cards and add_flag("bulletin:" + key):
		out["bulletin"] = {"title": String(bulletin["title"]), "body": format(String(bulletin["body"]), words)}
	else:
		out["bulletin_tip"] = StoryLines.BULLETIN_TIP_PREFIX + format(String(bulletin["tip"]), words)
	return out


## The square's arrival notice: the district just left behind.
static func departure_line() -> String:
	var done := completed_segment()
	if done < 1 or Global == null:
		return ""
	var id := district_id(done, Global.attempt_world_seed)
	var district: Dictionary = StoryLines.DISTRICTS.get(id, {})
	var first := String(district.get("departure_first", ""))
	if first != "" and add_flag("departure:" + id):
		return first
	var lines: Array = district.get("departure", [])
	if lines.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash([Global.attempt_world_seed, "departure", done]))
	return String(lines[rng.randi() % lines.size()])


## Bren's dispatch after `completed` (1, 3, 5, 9, 10), once per attempt:
## {"speaker", "role", "text"} or {}. The first account on the profile reads
## the full letter, keyed to the opening's response; later ones read short.
static func bren_dispatch(completed: int) -> Dictionary:
	if not StoryLines.BREN_DISPATCHES.has(completed):
		return {}
	var mark := "bren:%d" % completed
	if _attempt_flag(mark):
		return {}
	_add_attempt_flag(mark)
	var entry: Dictionary = StoryLines.BREN_DISPATCHES[completed]
	var text := String(entry.get("repeat", entry["base"]))
	if add_flag("bren_full:%d" % completed):
		text = String(entry["base"])
		var response := String(Global.opening_response_id) if Global != null else ""
		var answer := String(entry.get("all", entry.get(response, ""))) if response != "" or entry.has("all") else ""
		if answer != "":
			text += "\n\n" + answer
	return {"speaker": StoryLines.BREN_SPEAKER, "role": StoryLines.BREN_ROLE, "text": text}


## A staff member's line as the player comes near (HubCrowd). `aside` is a
## line the square supplies itself; it keeps its old one-in-three share of
## the everyday talk and never interrupts a beat.
static func staff_line(key: String, rng: RandomNumberGenerator, aside: String = "") -> String:
	var pool := _staff_pool(key)
	if pool.is_empty():
		return aside
	var f := facts()
	var line := pick(pool, f, rng, _recent.get(key, []) as Array, false)
	if line.is_empty():
		return aside
	if priority(line) < StoryLines.BEAT and aside != "" and rng.randi() % 3 == 0:
		return aside
	spend(line)
	_remember(_recent, key, line)
	return format(String(line["text"]), tokens(f))


static func _staff_pool(key: String) -> Array:
	match key:
		"chronicler":
			return StoryLines.CHRONICLER
		"acolyte":
			return StoryLines.ACOLYTE
		"exchanger":
			return StoryLines.EXCHANGER
		"quartermaster":
			return StoryLines.QUARTERMASTER
		"smith":
			return StoryLines.SMITH
	return []


## The crowd's size band for a visit's Followers.
static func crowd_tier(level: int) -> String:
	if level >= 10000:
		return "quarter"
	if level >= 1000:
		return "thousands"
	if level >= 100:
		return "hundreds"
	if level >= 10:
		return "dozens"
	return "few" if level > 0 else ""


## What a believer of `kind` might say tonight, weighted by repetition
## (HubCrowd draws from it and keeps its own recent lines out).
static func crowd_pool(kind: String, level: int) -> Array[String]:
	var f := facts({"kind": kind, "tier": crowd_tier(level)})
	var out: Array[String] = []
	for entry in StoryLines.CROWD:
		var line: Dictionary = entry
		if not matches(line.get("when", {}) as Dictionary, f):
			continue
		for i in range(maxi(1, roundi(float(line.get("w", 1.0)) * 2.0))):
			out.append(String(line["text"]))
	return out


## The reconstruction card's body; the "Followers lost / remaining" lines
## are kept as they always were.
static func reconstruction_body(cost: int, remaining: int) -> String:
	var seg := Global.attempt_segment if Global != null else 1
	var at := "at the last Wardstone that recognised you, or where %s began" % ("the night" if seg <= 1 else "the district")
	var f := facts({
		"unsafe": Global != null and not Global.reconstruction_survivable(remaining),
		"rebuild_at": at,
	})
	var memory: Dictionary = attempt()["recent"]
	var line := pick(StoryLines.RECONSTRUCTION, f, rng_for("reconstruction"), memory.get("reconstruction", []) as Array)
	if not line.is_empty():
		_remember(memory, "reconstruction", line)
	var text := format(String(line.get("text", "Your followers preserve the sequence.")), tokens(f))
	return "%s\n\nFollowers lost: %d\nFollowers remaining: %d" % [text, cost, remaining]


## The Game Over's epitaph and caption for the account that just closed
## ({"text": "", ...} when none did, so the screen keeps its own line).
static func closing_epitaph() -> Dictionary:
	_normalise()
	var account: Dictionary = state["last"]
	if not _just_closed or account.is_empty():
		return {"text": "", "caption": ""}
	var caption := "ACCOUNT %s · %s · %s" % [roman(int(account.get("n", 1))), district_name(String(account.get("district", ""))).to_upper(), witnesses_caption(int(account.get("peak", 0)))]
	return {"text": String(account.get("epitaph", "")), "caption": caption}


static func witnesses_caption(peak: int) -> String:
	if peak <= 0:
		return "NO WITNESSES"
	if peak == 1:
		return "ONE WITNESS"
	return "%s WITNESSES" % grouped(peak)


## The Archives card's line between attempts ("" when no account closed).
static func save_card_status(meta: Dictionary) -> String:
	if meta == null:
		return ""
	var account: Variant = meta.get("last", {})
	if not (account is Dictionary) or (account as Dictionary).is_empty():
		return ""
	var at := district_at(String((account as Dictionary).get("district", "")))
	return "Last account ended %s" % at if at != "" else ""


## Segment 10's chapter card for the caller to present:
## {"eyebrow", "title", "body", "button"}, or {} for any other segment. The
## first close on a profile reads in full; later ones are shorter. Its last
## line is the only place the name is said. `mark` records that it was seen.
static func chapter_close_card(completed: int, mark: bool = true) -> Dictionary:
	if completed != _final_segment():
		return {}
	var first := not has_flag("chapter:1")
	if mark:
		add_flag("chapter:1")
	var peak := witnesses()
	var witnesses := StoryLines.CHAPTER_WITNESS_ONE if peak <= 1 else (StoryLines.CHAPTER_WITNESSES_FIRST if first else StoryLines.CHAPTER_WITNESSES_REPEAT) % grouped(peak)
	var family := String(StoryLines.CHAPTER_FAMILY.get(dominant_family(), StoryLines.CHAPTER_FAMILY[""]))
	var body := (StoryLines.CHAPTER_FIRST if first else StoryLines.CHAPTER_REPEAT).format({"witnesses_line": witnesses, "family_line": family})
	return {"eyebrow": StoryLines.CHAPTER_EYEBROW, "title": StoryLines.CHAPTER_TITLE, "body": body, "button": StoryLines.CHAPTER_BUTTON}


# ---------------------------------------------------------------- scenes

## Puts the story's presenter into a segment (game.gd _begin_entry_sequence).
static func attach_segment(game: Node, segment: int) -> Node:
	ensure()
	var script := load(SEGMENT_PRESENTER_PATH) as Script
	if game == null or script == null:
		return null
	var presenter: Node = script.new()
	presenter.name = "StoryPresenter"
	game.add_child(presenter)
	presenter.call("setup", game, segment)
	return presenter


## Puts the story's presenter into the square (HubWorld._ready).
static func attach_hub(hub: Node) -> Node:
	ensure()
	var script := load(HUB_PRESENTER_PATH) as Script
	if hub == null or script == null:
		return null
	var presenter: Node = script.new()
	presenter.name = "StoryPresenter"
	hub.add_child(presenter)
	presenter.call("setup", hub)
	return presenter


# ---------------------------------------------------------------- words

static func roman(n: int) -> String:
	return ROMAN[n] if n >= 1 and n < ROMAN.size() else str(n)


static func grouped(value: int) -> String:
	var digits := str(maxi(0, value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out


## Which archetype a damage source is: its EnemySpec id, resolved the way
## BalanceRecorder._source_id does (a projectile's shooter, an actor bound
## to an EnemyWorld handle), "self" for the player's own costs, "" unknown.
static func cause_id(source: Node, kind: StringName) -> String:
	if kind == &"self_damage":
		return "self"
	if not is_instance_valid(source):
		return ""
	var node: Node = source
	if "shooter" in node:
		var shooter: Variant = node.get("shooter")
		if is_instance_valid(shooter) and shooter is Node:
			node = shooter
	if "spec" in node:
		var spec: Variant = node.get("spec")
		if spec != null and "id" in spec:
			return String(spec.get("id"))
	if EnemyCombat != null and EnemyCombat.has_method("handle_for_actor"):
		var handle := int(EnemyCombat.handle_for_actor(node))
		if handle != 0 and EnemyWorld.is_valid_handle(handle):
			return String(EnemyWorld.get_spec_id(handle))
	return ""
