class_name WavePlanner
extends RefCounted
## Turns a wave number into a list of spawn groups: spends the threat budget on
## the bugs unlocked so far, splits it between the cliffs and assigns lanes and
## pulses. Pure logic (seeded), so it can be unit-tested.

var config: WaveConfig
var bug_defs: Array[BugDef] = []
var rng := RandomNumberGenerator.new()


func _init(cfg: WaveConfig, defs: Array[BugDef], seed_value: int = 0) -> void:
	config = cfg
	bug_defs = defs
	rng.seed = seed_value


## Bugs that may appear in wave w.
func unlocked(w: int) -> Array[BugDef]:
	var out: Array[BugDef] = []
	for d in bug_defs:
		if d.first_wave <= w:
			out.append(d)
	return out


## Returns {"groups": Array of {"bug": StringName, "count": int, "cliff": int, "lane": int, "pulse": int},
##          "pulses": int, "west_share": float, "spent": [west, east]}
func plan(w: int) -> Dictionary:
	var budget := config.budget(w)
	var west_share := config.west_share_for(w, rng.randf())
	var pools := [budget * west_share, budget * (1.0 - west_share)]
	var spent := [0.0, 0.0]
	var pulses := rng.randi_range(config.pulses_min, config.pulses_max)
	var groups: Array = []
	var options := unlocked(w)
	# Make sure every bug introduced this wave shows up on both cliffs.
	for newest in _newest(options, w):
		for cid in 2:
			var c := float(newest.cost * newest.group_size)
			if pools[cid] - spent[cid] >= c:
				groups.append(_group(newest, cid, pulses))
				spent[cid] += c
	for cid in 2:
		var guard := 0
		while guard < 500:
			guard += 1
			var left: float = pools[cid] - spent[cid]
			var affordable := options.filter(func(d: BugDef) -> bool: return d.cost * d.group_size <= left)
			if affordable.is_empty():
				break
			var pick := affordable[rng.randi_range(0, affordable.size() - 1)] as BugDef
			groups.append(_group(pick, cid, pulses))
			spent[cid] += float(pick.cost * pick.group_size)
	return {"groups": groups, "pulses": pulses, "west_share": west_share, "spent": spent}


func _group(d: BugDef, cliff: int, pulses: int) -> Dictionary:
	return {
		"bug": d.id,
		"count": d.group_size,
		"cliff": cliff,
		"lane": rng.randi_range(0, WorldLayout.LANE_Z.size() - 1),
		"pulse": rng.randi_range(0, pulses - 1),
	}


func _newest(options: Array[BugDef], w: int) -> Array[BugDef]:
	var out: Array[BugDef] = []
	for d in options:
		if d.first_wave == w:
			out.append(d)
	return out


## Which cliff gets the larger share (for the warning HUD). -1 if even.
static func heavier_cliff(west_share: float) -> int:
	if absf(west_share - 0.5) < 0.01:
		return -1
	return WorldLayout.WEST if west_share > 0.5 else WorldLayout.EAST
