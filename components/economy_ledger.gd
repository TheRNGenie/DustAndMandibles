class_name EconomyLedger
extends RefCounted
## Pure resource bookkeeping per cliff (one player per cliff), with no networking,
## so it can be unit-tested. The Economy autoload wraps it and syncs it.

const RESOURCES: Array[StringName] = [&"scrap", &"chitin", &"water", &"corn", &"prickly_pear", &"chili", &"herbs",
	&"seed_corn", &"seed_prickly_pear", &"seed_chili", &"seed_herbs", &"upgrade_token"]

## cliff_id -> {resource: int}
var stock: Dictionary = {}

## Town bounty for holding a wave: base scrap plus a little more each wave.
const WAVE_PAY_BASE := 30
const WAVE_PAY_PER_WAVE := 5


## Scrap each player gets for holding wave `held` (paid as the next build phase starts).
static func wave_pay(held: int) -> int:
	return WAVE_PAY_BASE + WAVE_PAY_PER_WAVE * maxi(held, 0) if held >= 1 else 0


func reset(start: Dictionary, cliffs: int = 2) -> void:
	stock.clear()
	for cid in cliffs:
		var s: Dictionary = {}
		for r in RESOURCES:
			s[r] = int(start.get(r, 0))
		stock[cid] = s


func amount(cliff_id: int, res: StringName) -> int:
	if not stock.has(cliff_id):
		return 0
	return int((stock[cliff_id] as Dictionary).get(res, 0))


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
	var s: Dictionary = stock[cliff_id]
	for r: StringName in cost:
		s[r] = int(s[r]) - int(cost[r])
	return true


func earn(cliff_id: int, amounts: Dictionary) -> void:
	if not stock.has(cliff_id):
		return
	var s: Dictionary = stock[cliff_id]
	for r: StringName in amounts:
		s[r] = maxi(int(s.get(r, 0)) + int(amounts[r]), 0)


## Moves resources from one cliff's stockpile to the other's (the bridge crate).
func transfer(from_cliff: int, to_cliff: int, amounts: Dictionary) -> bool:
	if not spend(from_cliff, amounts):
		return false
	earn(to_cliff, amounts)
	return true
