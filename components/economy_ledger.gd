class_name EconomyLedger
extends RefCounted
## Pure resource bookkeeping, with no networking, so it can be unit-tested. The
## Economy autoload wraps it and syncs it.
##
## Scrap is one shared team pot (kept under the TEAM key): everyone builds from
## it and every kill, bounty and sale pays into it. Everything else (chitin,
## water, crops, seeds, parts, crafted turrets) is personal: one stockpile per
## cliff (one player per cliff). Callers never need to know which is which:
## amount / spend / earn on a cliff read and write the right pile.

const RESOURCES: Array[StringName] = [&"scrap", &"chitin", &"water", &"corn", &"prickly_pear", &"chili", &"herbs",
	&"seed_corn", &"seed_prickly_pear", &"seed_chili", &"seed_herbs", &"upgrade_token", &"sarsaparilla", &"seed_sarsaparilla"]

## The team pot's key in `stock`.
const TEAM := -1
## Resources the whole team shares (everything else is per cliff).
const SHARED: Array[StringName] = [&"scrap"]

## cliff_id -> {resource: int}, plus TEAM -> {shared resource: int}
var stock: Dictionary = {}

## Town bounty for holding a wave: base scrap plus a little more each wave.
const WAVE_PAY_BASE := 30
const WAVE_PAY_PER_WAVE := 5


## Scrap each cliff earns the team for holding wave `held` (paid as the next build phase starts).
static func wave_pay(held: int) -> int:
	return WAVE_PAY_BASE + WAVE_PAY_PER_WAVE * maxi(held, 0) if held >= 1 else 0


static func is_shared(res: StringName) -> bool:
	return SHARED.has(res)


## The pile `res` lives in when `cliff_id` reads or pays it.
static func pool_of(cliff_id: int, res: StringName) -> int:
	return TEAM if is_shared(res) else cliff_id


## `start` is per player: the team pot starts with every cliff's share of the
## shared resources (so the team's total is what separate piles used to hold).
func reset(start: Dictionary, cliffs: int = 2) -> void:
	stock.clear()
	var team: Dictionary = {}
	for r in SHARED:
		team[r] = int(start.get(r, 0)) * cliffs
	stock[TEAM] = team
	for cid in cliffs:
		var s: Dictionary = {}
		for r in RESOURCES:
			if not is_shared(r):
				s[r] = int(start.get(r, 0))
		stock[cid] = s


## The cliff ids that have a stockpile (0, 1, ... without the team pot).
func cliff_ids() -> Array[int]:
	var out: Array[int] = []
	for k: Variant in stock:
		if int(k) != TEAM:
			out.append(int(k))
	out.sort()
	return out


func amount(cliff_id: int, res: StringName) -> int:
	var pool := pool_of(cliff_id, res)
	if not stock.has(pool):
		return 0
	return int((stock[pool] as Dictionary).get(res, 0))


## The team pot's amount of a shared resource.
func team_amount(res: StringName) -> int:
	return amount(TEAM, res)


## Negative amounts are never affordable (so spend / transfer can't be used to mint resources).
func can_afford(cliff_id: int, cost: Dictionary) -> bool:
	for r: StringName in cost:
		if int(cost[r]) < 0 or amount(cliff_id, r) < int(cost[r]):
			return false
	return true


## Deducts the cost if affordable. Returns false (and changes nothing) otherwise.
func spend(cliff_id: int, cost: Dictionary) -> bool:
	if not can_afford(cliff_id, cost):
		return false
	for r: StringName in cost:
		var s: Dictionary = stock[pool_of(cliff_id, r)]
		s[r] = int(s.get(r, 0)) - int(cost[r])
	return true


func earn(cliff_id: int, amounts: Dictionary) -> void:
	if not stock.has(cliff_id):
		return
	for r: StringName in amounts:
		var pool := pool_of(cliff_id, r)
		if not stock.has(pool):
			stock[pool] = {}
		var s: Dictionary = stock[pool]
		s[r] = maxi(int(s.get(r, 0)) + int(amounts[r]), 0)


## Moves personal resources from one cliff's stockpile to another's (F7 gives).
## Shared ones (scrap) are already everyone's: refused.
func transfer(from_cliff: int, to_cliff: int, amounts: Dictionary) -> bool:
	for r: StringName in amounts:
		if is_shared(r):
			return false
	if not stock.has(to_cliff) or not spend(from_cliff, amounts):
		return false
	earn(to_cliff, amounts)
	return true


## A stockpile from before the split (an older save): every cliff kept its own
## scrap. Returns a copy with the cliffs' shared resources summed into the team pot.
static func pool_shared(raw: Dictionary) -> Dictionary:
	var out := {}
	var team: Dictionary = (raw[TEAM] as Dictionary).duplicate() if raw.get(TEAM) is Dictionary else {}
	for k: Variant in raw:
		if int(k) == TEAM:
			continue
		var s: Dictionary = (raw[k] as Dictionary).duplicate()
		for r in SHARED:
			if s.has(r):
				team[r] = int(team.get(r, 0)) + int(s[r])
				s.erase(r)
		out[int(k)] = s
	for r in SHARED:
		if not team.has(r):
			team[r] = 0
	out[TEAM] = team
	return out
