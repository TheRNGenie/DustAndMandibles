extends RefCounted
## Host: counts kills per (bug type, kill method) this run, and says when a type
## has died the same way often enough that its variant starts showing up.
## Load with preload("res://scenes/bugs/kill_tally.gd").

const Variants := preload("res://scenes/bugs/bug_variants.gd")

## Kills of one type by one method before its variant appears (swarm bugs that
## come in big groups need proportionally more; see needed()).
var threshold := 60
## Variant ids unlocked so far, in the order they appeared.
var unlocked: Array[StringName] = []
var _kills: Dictionary = {} # "base|method" -> int


func reset() -> void:
	_kills.clear()
	unlocked.clear()


## Kills it takes for this bug type's variant (more for bugs that come in packs).
func needed(base: BugDef) -> int:
	return threshold * maxi(1, base.group_size / 2)


func count(base: StringName, method: StringName) -> int:
	return int(_kills.get("%s|%s" % [base, method], 0))


## Counts one kill. Returns the variant id it unlocked, or &"".
func note(def: BugDef, method: StringName) -> StringName:
	var base := def.base_id()
	var key := "%s|%s" % [base, method]
	var n := int(_kills.get(key, 0)) + 1
	_kills[key] = n
	if not Variants.can_vary(base, method):
		return &""
	var vid := Variants.id_for(base, method)
	if unlocked.has(vid) or n < needed(Defs.bug(base)):
		return &""
	unlocked.append(vid)
	return vid
