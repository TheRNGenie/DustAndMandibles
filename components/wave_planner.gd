class_name WavePlanner
extends RefCounted
## Turns a wave number into a list of spawn groups: spends the threat budget on
## the bugs unlocked so far, splits it between the cliffs and assigns lanes and
## pulses. Each wave also gets a shape (how it arrives: a steady stream, one big
## rush, two pushes, a flier-heavy wave, or a boss wave every few waves) and
## mixes in any kill-method variants the players have unlocked.
## Pure logic (seeded), so it can be unit-tested.

const STEADY := &"steady"
const RUSH := &"rush"
const TWO_PUSHES := &"two_pushes"
const FLIERS := &"fliers"
const BOSS := &"boss"
## What each shape is called on the HUD.
const SHAPE_NAMES := {STEADY: "A steady stream", RUSH: "One big rush", TWO_PUSHES: "Two pushes",
	FLIERS: "Fliers overhead", BOSS: "Boss wave"}

var config: WaveConfig
var bug_defs: Array[BugDef] = []
var rng := RandomNumberGenerator.new()
## Kill-method variant ids the players have unlocked (mixed in by plan()).
var variants: Array[StringName] = []
## Boss ids already met this run, oldest first (BossRotation never repeats one
## until every unlocked boss has come).
var boss_seen: Array = []
# Maps: how many cliffs the map has, and how likely bugs are to pick each (MapDef).
var cliff_count := 2
var weights: Array[float] = [0.5, 0.5]
var _map: MapDef = null
var _seed := 0


func _init(cfg: WaveConfig, defs: Array[BugDef], seed_value: int = 0, map: MapDef = null) -> void:
	config = cfg
	bug_defs = defs
	_seed = seed_value
	rng.seed = seed_value
	var m := map if map != null else MapDef.get_current() # Maps:
	_map = m
	cliff_count = m.count()
	weights = m.spawn_weights()


## Bugs that may appear in wave w.
func unlocked(w: int) -> Array[BugDef]:
	var out: Array[BugDef] = []
	for d in bug_defs:
		if d.first_wave <= w and not d.is_variant():
			out.append(d)
	return out


static func is_brute(d: BugDef) -> bool:
	return d.behavior in [BugDef.Behavior.TANK, BugDef.Behavior.BROOD, BugDef.Behavior.BOSS]


## How wave w arrives. Depends only on the seed and the wave, never on what was
## planned before, and the same shape never comes twice in a row.
func shape_for(w: int) -> StringName:
	if w <= 1:
		return STEADY
	if config.boss_every > 0 and w % config.boss_every == 0:
		return BOSS
	var pool: Array[StringName] = [STEADY, RUSH, TWO_PUSHES]
	for d in unlocked(w):
		if d.behavior == BugDef.Behavior.FLIER and d.cost > 0:
			pool.append(FLIERS)
			break
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, w, "shape"])
	var pick := pool[r.randi_range(0, pool.size() - 1)]
	if pick == shape_for(w - 1):
		pick = pool[(pool.find(pick) + 1) % pool.size()]
	return pick


## Seconds after the wave starts that each pulse leaves the tunnels.
func pulse_times(shape: StringName, w: int = 0) -> Array[float]:
	var times: Array[float] = []
	match shape:
		STEADY:
			for i in config.steady_pulses:
				times.append(i * config.steady_interval)
		RUSH:
			for i in config.rush_pulses:
				times.append(i * config.rush_interval)
		TWO_PUSHES:
			times.assign([0.0, 2.0, config.push_gap, config.push_gap + 2.0])
		_:
			# Early waves come in quicker pulses (Logan, Nov 11: more action in waves 1-5).
			var gap := config.early_pulse_interval if w > 0 and w <= config.early_waves else config.pulse_interval
			for i in rng.randi_range(config.pulses_min, config.pulses_max):
				times.append(i * gap)
	return times


## Returns {"groups": Array of {"bug": StringName, "count": int, "cliff": int, "lane": int, "pulse": int,
##          "tier": int (canyon: 0 near, 1 mid, 2 deep tunnels)},
##          "pulses": int, "pulse_times": Array[float], "shape": StringName,
##          "west_share": float, "shares": [one per cliff], "spent": [one per cliff]}
func plan(w: int) -> Dictionary:
	var budget := config.budget(w)
	var west_share := config.west_share_for(w, rng.randf())
	# Maps: one pool per cliff (the canyon's two from the west share).
	var shares := split(west_share)
	var pools := []
	var spent := []
	for cid in cliff_count:
		pools.append(budget * shares[cid])
		spent.append(0.0)
	var shape := shape_for(w)
	var times := pulse_times(shape, w)
	var pulses := times.size()
	var groups: Array = []
	var options := unlocked(w)
	# Boss waves: the boss climbs the heaviest cliff's centre lane in the first
	# pulse (BossRotation picks which); the finale's second boss takes another
	# cliff (Maps: the one the map puts farthest from the first).
	var bosses := BossRotation.pick(_seed, w, bug_defs, boss_seen, config.boss_every, config.last_wave)
	var boss_at := boss_cliffs(shares, bosses.size())
	for i in bosses.size():
		groups.append({"bug": bosses[i], "count": 1, "cliff": boss_at[i], "lane": 2, "pulse": 0})
	# Make sure every bug introduced this wave shows up on both cliffs.
	for newest in _newest(options, w):
		for cid in cliff_count:
			var c := float(newest.cost * newest.group_size)
			if pools[cid] - spent[cid] >= c:
				groups.append(_group(newest, cid, pulses))
				spent[cid] += c
	# Shaped waves spend part of each cliff's budget on their kind of bug first.
	if shape == FLIERS:
		_spend(groups, spent, pools, options.filter(func(d: BugDef) -> bool: return d.behavior == BugDef.Behavior.FLIER), config.flier_share, pulses, false)
	elif shape == BOSS:
		_spend(groups, spent, pools, options.filter(func(d: BugDef) -> bool: return is_brute(d)), config.brute_share, pulses, true)
	for cid in cliff_count:
		_fill(groups, spent, cid, pools[cid], options, pulses)
	_mix_variants(groups)
	_scale_counts(groups, config.bug_count(w))
	assign_tiers(groups, tier_shares(w, config.last_wave) if _is_canyon() else [1.0, 0.0, 0.0])
	return {"groups": groups, "pulses": pulses, "pulse_times": times, "shape": shape,
			"west_share": west_share, "shares": shares, "spent": spent}


func _is_canyon() -> bool:
	return (_map if _map != null else MapDef.get_current()).is_canyon()


## Canyon Extension: each tunnel tier's share (near, mid, deep) of wave w's bugs.
## The mid tunnels open at WorldLayout.MID_WAVE, the deep ones at DEEP_WAVE,
## and the deep ones take more of each wave from then on.
static func tier_shares(w: int, last_wave: int = 20) -> Array[float]:
	var out: Array[float] = []
	if w < WorldLayout.MID_WAVE:
		out.assign([1.0, 0.0, 0.0])
	elif w < WorldLayout.DEEP_WAVE:
		out.assign([0.6, 0.4, 0.0])
	elif w <= 15:
		out.assign([0.3, 0.4, 0.3])
	elif w <= last_wave:
		out.assign([0.2, 0.3, 0.5])
	else:
		out.assign([0.15, 0.25, 0.6])
	return out


## Gives each group a tunnel tier so the bugs split by `shares` (biggest groups
## first, each to the tier furthest below its share). Bosses keep the near tier.
static func assign_tiers(groups: Array, shares: Array) -> void:
	var order := range(groups.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := int(groups[a]["count"])
		var cb := int(groups[b]["count"])
		return ca > cb or (ca == cb and a < b))
	var got: Array[float] = [0.0, 0.0, 0.0]
	var total := 0.0
	for i: int in order:
		var g: Dictionary = groups[i]
		var d := Defs.bug(StringName(g["bug"]))
		if d != null and d.behavior == BugDef.Behavior.BOSS:
			g["tier"] = 0
			continue
		var c := float(g["count"])
		total += c
		var best := 0
		var best_gap := -INF
		for t in 3:
			if float(shares[t]) <= 0.0:
				continue
			var gap := float(shares[t]) * total - got[t]
			if gap > best_gap:
				best_gap = gap
				best = t
		g["tier"] = best
		got[best] += c


## Wave 15 on (canyon): the deep tunnels' bugs come as a steady trickle instead
## of with the pulses. Splits the deep groups into [bug, count, cliff, lane]
## chunks, one every `gap` seconds across `span` seconds (at least one chunk per group).
static func trickle_chunks(groups: Array, span: float, gap: float = 2.5) -> Array:
	var deep: Array = groups.filter(func(g: Dictionary) -> bool: return int(g.get("tier", 0)) == 2)
	var total := 0
	for g: Dictionary in deep:
		total += int(g["count"])
	if total <= 0:
		return []
	var slots := maxi(int(span / gap), 1)
	var per := maxi(ceili(float(total) / slots), 1)
	# Round the groups in turn, so both cliffs' deep bugs keep coming.
	var left: Array[int] = []
	for g: Dictionary in deep:
		left.append(int(g["count"]))
	var out: Array = []
	var more := true
	while more:
		more = false
		for i in deep.size():
			if left[i] <= 0:
				continue
			var n := mini(per, left[i])
			out.append([StringName(deep[i]["bug"]), n, int(deep[i]["cliff"]), int(deep[i]["lane"])])
			left[i] -= n
			more = true
	return out


## Maps: each cliff's share of the wave's budget. Two cliffs: the configured
## west share. More: the map's spawn weights, with one cliff (picked per wave)
## leaned on as hard as the configured split is lopsided.
func split(west_share: float) -> Array[float]:
	var out: Array[float] = []
	if cliff_count == 2:
		out.assign([west_share, 1.0 - west_share])
		return out
	var heavy := rng.randi_range(0, cliff_count - 1)
	var lean := absf(west_share - 0.5) * 3.0
	var total := 0.0
	for cid in cliff_count:
		var s := weights[cid] * (1.0 + (lean if cid == heavy else 0.0))
		out.append(s)
		total += s
	for cid in cliff_count:
		out[cid] /= maxf(total, 0.0001)
	return out


## Maps: which cliff each of `n` bosses climbs. The first takes the heaviest
## cliff; the next the cliff farthest from it on this map (across the canyon or
## the lake; on the mesa, where every rim is as far, the heavier of the rest).
func boss_cliffs(shares: Array, n: int) -> Array[int]:
	var out: Array[int] = []
	if n <= 0:
		return out
	var first := heaviest(shares, true)
	out.append(first)
	var m := _map if _map != null else MapDef.get_current()
	while out.size() < n:
		var best := -1
		var best_score := -INF
		for cid in cliff_count:
			if out.has(cid) and out.size() < cliff_count:
				continue
			var dist := 0.0
			if cid < m.count() and first < m.count():
				dist = m.cliff(cid).origin.distance_to(m.cliff(first).origin)
			# Distance first (rounded so near-ties fall to the share), then the share.
			var score := roundf(dist) * 10.0 + float(shares[cid] if cid < shares.size() else 0.0)
			if score > best_score:
				best_score = score
				best = cid
		out.append(best if best >= 0 else first)
	return out


## Spends `share` of each cliff's pool on `kinds` (brutes come in the first pulses).
func _spend(groups: Array, spent: Array, pools: Array, kinds: Array, share: float, pulses: int, up_front: bool) -> void:
	if kinds.is_empty():
		return
	for cid in spent.size():
		_fill(groups, spent, cid, float(spent[cid]) + float(pools[cid]) * share, kinds, pulses)
	if up_front:
		for g: Dictionary in groups:
			if kinds.any(func(d: BugDef) -> bool: return d.id == g["bug"]):
				g["pulse"] = mini(int(g["pulse"]), mini(1, pulses - 1))


## Buys random affordable groups from `kinds` until cliff `cid` has spent `limit`.
func _fill(groups: Array, spent: Array, cid: int, limit: float, kinds: Array, pulses: int) -> void:
	var guard := 0
	while guard < 500:
		guard += 1
		var left: float = limit - float(spent[cid])
		var affordable := kinds.filter(func(d: BugDef) -> bool: return d.cost > 0 and d.cost * d.group_size <= left)
		if affordable.is_empty():
			break
		var pick := affordable[rng.randi_range(0, affordable.size() - 1)] as BugDef
		groups.append(_group(pick, cid, pulses))
		spent[cid] += float(pick.cost * pick.group_size)


## Swaps a share of each type's groups for its unlocked variants (at least one
## group each, so a new variant always shows up in the next wave's preview).
func _mix_variants(groups: Array) -> void:
	if variants.is_empty():
		return
	var shown: Dictionary = {}
	for g: Dictionary in groups:
		var options := _variants_of(StringName(g["bug"]))
		if not options.is_empty() and rng.randf() < config.variant_share:
			var v := options[rng.randi_range(0, options.size() - 1)]
			g["bug"] = v
			shown[v] = true
	for v in variants:
		if shown.has(v):
			continue
		var base := Defs.bug(v).variant_of if Defs.bug(v) != null else &""
		for g: Dictionary in groups:
			if StringName(g["bug"]) == base:
				g["bug"] = v
				break


func _variants_of(base: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in variants:
		var d := Defs.bug(v)
		if d != null and d.variant_of == base:
			out.append(v)
	return out


## The budget sets the mix of bugs; the count is scaled to the wave's target
## (45 in wave 1, +25% each wave). Bosses stay one of a kind.
func _scale_counts(groups: Array, target: int) -> void:
	var planned := 0
	for g: Dictionary in groups:
		planned += int(g["count"])
	if planned <= 0 or target <= 0:
		return
	var k := float(target) / float(planned)
	var total := 0
	for g: Dictionary in groups:
		if Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS:
			g["count"] = maxi(int(round(float(g["count"]) * k)), 1)
		total += int(g["count"])
	# Trim or pad the groups so the total lands on the target.
	var i := 0
	while total != target and i < groups.size() * 4:
		var g: Dictionary = groups[i % groups.size()]
		if Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS:
			var step := 1 if total < target else -1
			if int(g["count"]) + step >= 1:
				g["count"] = int(g["count"]) + step
				total += step
		i += 1


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


## Maps: the cliff with the biggest share (ties go to the lowest id). Without
## `always`, -1 when every cliff gets about the same.
static func heaviest(shares: Array, always: bool = false) -> int:
	var best := 0
	var lo := INF
	for cid in shares.size():
		lo = minf(lo, float(shares[cid]))
		if float(shares[cid]) > float(shares[best]):
			best = cid
	if not always and float(shares[best]) - lo < 0.02:
		return -1
	return best
