class_name StoryChapter
extends RefCounted
## One Story mode chapter, read from data/story/<id>.json (pure data plus the
## rules that read it; unit-tested). A chapter runs on top of a normal run
## (StoryDirector): it starts at `first_wave`, wins when `last_wave` is cleared
## and its objective is done, and says its radio lines at each wave's build
## phase, wave start and "held".
##
## JSON fields: id, number, title, map, first_wave, last_wave, blurb,
## start_bonus {resource: amount}, objective {kind: hold | fetch | protect, text,
## ...kind fields}, bosses {"wave": bug id}, extra_bugs {"wave": [[bug id, count]]},
## weather {"wave": weather name}, telegram {title, body}, radio {"wave": {build,
## wave, held: [[speaker, line]]}}, events {key: [[speaker, line]]}, journal
## {title, body}, rewards {notches, unlock {kind, id, name}}, headline_win,
## headline_loss.
##
## `objective` is the one field a later Canyon Expedition replaces: the plateau
## stand-ins (an airship drop, a boss drop) are "fetch" objectives.

const DIR := "res://data/story/"
## The chapters that can be played, in order.
const IDS: Array[String] = ["ch1", "ch2", "ch3", "ch4"]
## The rest of the story, shown locked on the chapter screen.
const PLANNED: Array = [
	[5, "The Railroad's Secret"], [6, "Dust and Thunder"], [7, "Down the Hole"], [8, "The Queen"]]
const SPEAKERS: Array[String] = ["stroud", "kettle", "pearl", "doc"]
const KINDS: Array[String] = ["hold", "fetch", "protect"]
const WHENS: Array[String] = ["build", "wave", "held"]
## A radio line should fit the card at a glance.
const MAX_WORDS := 20

var id := ""
var number := 0
var title := ""
var map: StringName = &"canyon"
var first_wave := 1
var last_wave := 1
var blurb := ""
var start_bonus: Dictionary = {}
var objective: Dictionary = {}
var bosses: Dictionary = {}
var extra_bugs: Dictionary = {}
var weather: Dictionary = {}
var telegram: Dictionary = {}
var radio: Dictionary = {}
var events: Dictionary = {}
var journal: Dictionary = {}
var rewards: Dictionary = {}
var headline_win := ""
var headline_loss := ""

static var _cache: Dictionary = {}


## The chapter `chapter_id` (cached), or null if there's no such file.
static func load_id(chapter_id: String) -> StoryChapter:
	if _cache.has(chapter_id):
		return _cache[chapter_id]
	var f := FileAccess.open(DIR + chapter_id + ".json", FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("[story] %s.json doesn't parse" % chapter_id)
		return null
	var ch := from_dict(parsed)
	_cache[chapter_id] = ch
	return ch


static func from_dict(d: Dictionary) -> StoryChapter:
	var ch := StoryChapter.new()
	ch.id = str(d.get("id", ""))
	ch.number = int(d.get("number", 0))
	ch.title = str(d.get("title", ""))
	ch.map = StringName(str(d.get("map", "canyon")))
	ch.first_wave = int(d.get("first_wave", 1))
	ch.last_wave = int(d.get("last_wave", ch.first_wave))
	ch.blurb = str(d.get("blurb", ""))
	ch.start_bonus = d.get("start_bonus", {})
	ch.objective = d.get("objective", {"kind": "hold"})
	ch.bosses = d.get("bosses", {})
	ch.extra_bugs = d.get("extra_bugs", {})
	ch.weather = d.get("weather", {})
	ch.telegram = d.get("telegram", {})
	ch.radio = d.get("radio", {})
	ch.events = d.get("events", {})
	ch.journal = d.get("journal", {})
	ch.rewards = d.get("rewards", {})
	ch.headline_win = str(d.get("headline_win", ""))
	ch.headline_loss = str(d.get("headline_loss", ""))
	return ch


## Every playable chapter, in order.
static func all() -> Array[StoryChapter]:
	var out: Array[StoryChapter] = []
	for cid in IDS:
		var ch := load_id(cid)
		if ch != null:
			out.append(ch)
	return out


## The chapter after `chapter_id` ("" if it's the last playable one).
static func next_id(chapter_id: String) -> String:
	var i := IDS.find(chapter_id)
	return IDS[i + 1] if i >= 0 and i + 1 < IDS.size() else ""


static func speaker_name(who: String) -> String:
	return {"stroud": "Capt. Ada Stroud", "kettle": "Silas Kettle", "pearl": "Pearl \"Snake Eyes\" Doyle",
			"doc": "Doc Whitlow"}.get(who, who.capitalize())


static func speaker_role(who: String) -> String:
	return {"stroud": "Lucky Mandible, Bridge", "kettle": "Gunsmith, Lower Deck", "pearl": "Casino Deck",
			"doc": "Rail Car 9, Canyon Floor"}.get(who, "")


# ------------------------------------------------------------------ reading it

func wave_count() -> int:
	return last_wave - first_wave + 1


func kind() -> String:
	return str(objective.get("kind", "hold"))


func objective_text() -> String:
	return str(objective.get("text", "Hold Out Through Wave %d" % last_wave))


## [[speaker, line], ...] for wave `w` at `when` ("build", "wave" or "held").
func lines(w: int, when: String) -> Array:
	var per: Dictionary = radio.get(str(w), {})
	return per.get(when, [])


## [[speaker, line], ...] for a story event ("drop", "win", "lost"...).
func event_lines(key: String) -> Array:
	return events.get(key, [])


## The boss chapter data puts on wave `w` (&"" for none).
func boss_for(w: int) -> StringName:
	return StringName(str(bosses.get(str(w), "")))


## The weather this chapter forces on wave `w` (Weather.Kind), or -1 to roll it.
func weather_for(w: int) -> int:
	var wname := str(weather.get(str(w), "")).to_upper()
	if wname == "":
		return -1
	return int(Weather.Kind.get(wname, -1))


## The map this chapter plays on for `players` riders: its own map when it has
## the room, else the smallest map that does (a bigger posse moves out to the
## Mesa or the Buttes).
func map_for_players(players: int) -> StringName:
	if MapDef.players_of(map) >= players:
		return map
	for m: StringName in MapDef.IDS:
		if MapDef.players_of(m) >= players:
			return m
	return MapDef.IDS[MapDef.IDS.size() - 1]


func notches() -> int:
	return int(rewards.get("notches", 0))


func unlock() -> Dictionary:
	return rewards.get("unlock", {})


## Edits a WaveDirector plan for wave `w`: the run's own boss pick is replaced by
## the chapter's boss (if it names one for this wave; chapters with bosses keep
## the rest of their waves boss-free), and the chapter's extra bugs are added,
## spread over the cliffs the plan uses and over its pulses. Pure.
func apply_to_plan(plan: Dictionary, w: int) -> Dictionary:
	var groups: Array = (plan.get("groups", []) as Array).duplicate()
	var pulses := maxi(int(plan.get("pulses", 1)), 1)
	var shares: Array = plan.get("shares", [])
	var cliffs: Array[int] = []
	for cid in shares.size():
		if float(shares[cid]) > 0.0:
			cliffs.append(cid)
	if cliffs.is_empty():
		cliffs = [0]
	var boss := boss_for(w)
	if not bosses.is_empty():
		var at := -1
		var kept: Array = []
		for g: Dictionary in groups:
			var d := Defs.bug(StringName(str(g["bug"])))
			if d != null and d.behavior == BugDef.Behavior.BOSS:
				if at < 0:
					at = int(g["cliff"])
				continue
			kept.append(g)
		groups = kept
		if boss != &"":
			if at < 0:
				at = cliffs[w % cliffs.size()]
			groups.append({"bug": boss, "count": 1, "cliff": at, "lane": 2, "pulse": 0})
	var extras: Array = extra_bugs.get(str(w), [])
	var k := 0
	for e: Array in extras:
		var bug := StringName(str(e[0]))
		var count := int(e[1])
		# One small group per cliff and pulse, round the cliffs.
		var per := maxi(1, ceili(float(count) / float(cliffs.size() * mini(pulses, 3))))
		var left := count
		while left > 0:
			var n := mini(per, left)
			groups.append({"bug": bug, "count": n, "cliff": cliffs[k % cliffs.size()], "lane": (k * 2 + 1) % 5,
					"pulse": (k / cliffs.size()) % pulses})
			left -= n
			k += 1
	var out := plan.duplicate()
	out["groups"] = groups
	return out


## Problems with this chapter's data ([] when it's sound): fields present, waves
## in order, speakers known, lines short, bosses and bugs real, weather named.
func problems() -> Array[String]:
	var out: Array[String] = []
	if id == "" or title == "" or number <= 0:
		out.append("missing id, title or number")
	if not MapDef.IDS.has(map):
		out.append("unknown map %s" % map)
	if first_wave < 1 or last_wave < first_wave:
		out.append("waves %d-%d out of order" % [first_wave, last_wave])
	if not KINDS.has(kind()):
		out.append("unknown objective kind %s" % kind())
	if str(telegram.get("title", "")) == "" or str(telegram.get("body", "")) == "":
		out.append("telegram needs a title and body")
	if str(journal.get("title", "")) == "" or str(journal.get("body", "")) == "":
		out.append("journal page needs a title and body")
	if notches() <= 0:
		out.append("no Notches reward")
	if headline_win == "" or headline_loss == "":
		out.append("missing a headline")
	var all_lines: Array = []
	for wk: String in radio:
		if int(wk) < first_wave or int(wk) > last_wave:
			out.append("radio for wave %s outside the chapter" % wk)
		for when: String in (radio[wk] as Dictionary):
			if not WHENS.has(when):
				out.append("radio wave %s has unknown slot %s" % [wk, when])
			all_lines.append_array(radio[wk][when])
	for key: String in events:
		all_lines.append_array(events[key])
	for l: Variant in all_lines:
		if not l is Array or (l as Array).size() != 2:
			out.append("a line isn't [speaker, text]: %s" % str(l))
			continue
		if not SPEAKERS.has(str(l[0])):
			out.append("unknown speaker %s" % str(l[0]))
		var words := str(l[1]).split(" ", false).size()
		if words > MAX_WORDS:
			out.append("line over %d words (%d): %s" % [MAX_WORDS, words, str(l[1])])
	for wk: String in bosses:
		var d := Defs.bug(StringName(str(bosses[wk])))
		if d == null or d.behavior != BugDef.Behavior.BOSS:
			out.append("boss %s on wave %s isn't a boss" % [str(bosses[wk]), wk])
	for wk: String in extra_bugs:
		for e: Variant in extra_bugs[wk]:
			if not e is Array or Defs.bug(StringName(str(e[0]))) == null:
				out.append("extra bug %s on wave %s unknown" % [str(e), wk])
	for wk: String in weather:
		if weather_for(int(wk)) < 0:
			out.append("weather %s on wave %s unknown" % [str(weather[wk]), wk])
	if kind() == "fetch":
		if not ["airship_drop", "boss_drop"].has(str(objective.get("spawn", ""))):
			out.append("fetch needs spawn airship_drop or boss_drop")
		if not ["well", "board"].has(str(objective.get("deliver_to", ""))):
			out.append("fetch needs deliver_to well or board")
		if str(objective.get("spawn", "")) == "boss_drop" and not bosses.values().has(str(objective.get("boss", ""))):
			out.append("boss_drop names a boss the chapter never brings")
	return out
