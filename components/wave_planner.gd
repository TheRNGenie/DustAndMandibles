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
	# The boss wave: the Iron Tumbleweed climbs the heavier cliff's centre lane in the first pulse.
	for d in options:
		if d.behavior == BugDef.Behavior.BOSS and d.first_wave == w:
			var boss_cliff := WorldLayout.WEST if west_share >= 0.5 else WorldLayout.EAST
			groups.append({"bug": d.id, "count": 1, "cliff": boss_cliff, "lane": 2, "pulse": 0})
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
			var affordable := options.filter(func(d: BugDef) -> bool: return d.cost > 0 and d.cost * d.group_size <= left)
			if affordable.is_empty():
				break
			var pick := affordable[rng.randi_range(0, affordable.size() - 1)] as BugDef
			groups.append(_group(pick, cid, pulses))
			spent[cid] += float(pick.cost * pick.group_size)
	# The budget sets the mix of bugs; the count is scaled to the wave's target
	# (45 in wave 1, +25% each wave). Bosses stay one of a kind.
	var planned := 0
	for g: Dictionary in groups:
		planned += int(g["count"])
	var target := config.bug_count(w)
	if planned > 0 and target > 0:
		var k := float(target) / float(planned)
		var total := 0
		for g: Dictionary in groups:
			if Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS:
				g["count"] = maxi(int(round(float(g["count"]) * k)), 1)
			total += int(g["count"])
		# Trim or pad the dust-mite-ish filler so the total lands on the target.
		var i := 0
		while total != target and i < groups.size() * 4:
			var g: Dictionary = groups[i % groups.size()]
			if Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS:
				var step := 1 if total < target else -1
				if int(g["count"]) + step >= 1:
					g["count"] = int(g["count"]) + step
					total += step
			i += 1
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
		if d.first_wave == w and d.cost > 0:
			out.append(d)
	return out


## Which cliff gets the larger share (for the warning HUD). -1 if even.
static func heavier_cliff(west_share: float) -> int:
	if absf(west_share - 0.5) < 0.01:
		return -1
	return WorldLayout.WEST if west_share > 0.5 else WorldLayout.EAST
