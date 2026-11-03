class_name BossRotation
extends RefCounted
## Which boss (or bosses) come on a boss wave. Every 5th wave is a boss wave;
## each picks a boss this run hasn't seen yet, preferring the ones that unlock
## that wave (so wave 5, 10 and 15 each bring a boss of their tier), and only
## repeats once every unlocked boss has been seen. The last wave of the run is a
## double-boss finale. Story-only bosses (the Hive Queen) are never picked. The Mirage Mantis only hunts in dust storms: when she is
## picked and the wave's weather isn't a dust storm, another boss stands in for
## her (substitute()), and a boss wave that does roll a dust storm brings her.
## Pure logic (seeded), unit-tested.

const MANTIS := &"mirage_mantis"
## Chance the weather roll is forced to a dust storm on a wave the Mantis is due.
const MANTIS_DUST_CHANCE := 0.5


## Bosses (ids) for wave w. `defs`: every bug that may be planned; `seen`: boss
## ids already met this run (oldest first); `finale`: the double-boss wave.
static func pick(seed_value: int, w: int, defs: Array[BugDef], seen: Array, every: int, finale: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if every <= 0 or w <= 0 or w % every != 0:
		return out
	var count := 2 if w == finale else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, w, "boss"])
	var taken: Array = seen.duplicate()
	for i in count:
		var id := _one(rng, w, defs, taken, out)
		if id == &"":
			break
		out.append(id)
		taken.append(id)
	return out


static func _one(rng: RandomNumberGenerator, w: int, defs: Array[BugDef], seen: Array, this_wave: Array[StringName]) -> StringName:
	var eligible: Array[StringName] = []
	for d in defs:
		if d.behavior == BugDef.Behavior.BOSS and d.first_wave <= w and not d.is_variant() and not d.story_only and not this_wave.has(d.id):
			eligible.append(d.id)
	if eligible.is_empty():
		return &""
	var fresh := eligible.filter(func(id: StringName) -> bool: return not seen.has(id))
	if fresh.is_empty():
		# Everyone's been met: start the round again, but never the last one met.
		fresh = eligible.filter(func(id: StringName) -> bool: return seen.is_empty() or id != seen[seen.size() - 1])
		if fresh.is_empty():
			fresh = eligible
	# Prefer the bosses that unlock this very wave.
	var newest := fresh.filter(func(id: StringName) -> bool: return _first_wave(defs, id) == w)
	var pool: Array = newest if not newest.is_empty() else fresh
	pool.sort()
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _first_wave(defs: Array[BugDef], id: StringName) -> int:
	for d in defs:
		if d.id == id:
			return d.first_wave
	return 0


## A boss to stand in for `missing` (the Mantis out of a dust storm): one not
## seen yet and not already in this wave if possible.
static func substitute(seed_value: int, w: int, defs: Array[BugDef], seen: Array, this_wave: Array[StringName], missing: StringName) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, w, "stand-in"])
	var skip: Array[StringName] = this_wave.duplicate()
	skip.append(missing)
	var taken: Array = seen.duplicate()
	taken.append(missing)
	var id := _one(rng, w, defs, taken, skip)
	return id if id != &"" else missing


## The weather decides whether the Mantis hunts: she swaps out for a stand-in when
## the wave isn't a dust storm; a dust-storm boss wave without her brings her
## in place of its first boss (once a run, while she's unseen). Returns the
## wave's bosses after the swap.
static func apply_weather(seed_value: int, w: int, defs: Array[BugDef], seen: Array, bosses: Array[StringName], dust_storm: bool) -> Array[StringName]:
	var out: Array[StringName] = bosses.duplicate()
	var mantis_ok := false
	for d in defs:
		if d.id == MANTIS and d.first_wave <= w:
			mantis_ok = true
	for i in out.size():
		if out[i] == MANTIS and not dust_storm:
			out[i] = substitute(seed_value, w, defs, seen, out, MANTIS)
	if dust_storm and mantis_ok and not out.is_empty() and not out.has(MANTIS) and not seen.has(MANTIS):
		out[0] = MANTIS
	return out
