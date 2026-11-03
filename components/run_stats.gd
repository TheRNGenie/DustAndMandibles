class_name RunStats
extends RefCounted
## What happened this run, for the end-of-run newspaper (NewspaperFront). Every
## peer counts the same kills: BugManager announces each one to everyone, and
## HudFeed passes them here. Cleared when a run starts.

static var kills := 0
static var scrap := 0
## Damage source ("Logan", "Logan's Gatling Post") -> kills.
static var by_source: Dictionary = {}
## Bug name -> kills.
static var by_bug: Dictionary = {}
## Boss names killed, in order.
static var bosses: Array[String] = []
## Boss name -> who landed the killing blow (the first time it fell).
static var boss_by: Dictionary = {}
static var _boss_names: Dictionary = {}


static func reset() -> void:
	kills = 0
	scrap = 0
	by_source = {}
	by_bug = {}
	bosses = []
	boss_by = {}


static func note_kill(bug_name: String, source: String, scrap_drop: int) -> void:
	kills += 1
	scrap += maxi(scrap_drop, 0)
	if source != "":
		by_source[source] = int(by_source.get(source, 0)) + 1
	by_bug[bug_name] = int(by_bug.get(bug_name, 0)) + 1
	if is_boss(bug_name) and not bosses.has(bug_name):
		bosses.append(bug_name)
		if source != "":
			boss_by[bug_name] = source


static func is_boss(bug_name: String) -> bool:
	if _boss_names.is_empty():
		for id: StringName in Defs.BUGS:
			var d := Defs.bug(id)
			if d != null and d.boss_tip != "":
				_boss_names[d.display_name] = true
	return _boss_names.has(bug_name)


## [name, kills] of the deadliest source, or ["", 0].
static func top_source() -> Array:
	return _top(by_source)


## [name, kills] of the bug killed most, or ["", 0].
static func top_bug() -> Array:
	return _top(by_bug)


static func _top(d: Dictionary) -> Array:
	var best := ""
	var n := 0
	for k: Variant in d:
		if int(d[k]) > n:
			n = int(d[k])
			best = str(k)
	return [best, n]


## The front-page headline for a run that ended on `wave`.
static func headline(won: bool, wave: int, map_name: String) -> String:
	if won:
		return "RANCHERS HOLD %s THROUGH %d WAVE%s" % [map_name.to_upper(), wave, "" if wave == 1 else "S"]
	if wave <= 1:
		return "%s FALLS ON THE FIRST NIGHT" % map_name.to_upper()
	return "%s FALLS AFTER %d WAVES" % [map_name.to_upper(), wave]


## Plural helper: "1 beetle" / "3 beetles" style counts.
static func count_of(n: int, word: String) -> String:
	return "%d %s" % [n, word if n == 1 else word + "s"]
