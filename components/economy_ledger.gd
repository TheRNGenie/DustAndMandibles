class_name EconomyLedger
extends RefCounted
## Pure resource bookkeeping per cliff (one player per cliff), with no networking,
## so it can be unit-tested. The Economy autoload wraps it and syncs it.

const RESOURCES: Array[StringName] = [&"scrap", &"chitin", &"water", &"corn", &"prickly_pear", &"chili", &"herbs",
	&"seed_corn", &"seed_prickly_pear", &"seed_chili", &"seed_herbs"]

## cliff_id -> {resource: int}
var stock: Dictionary = {}


func reset(start: Dictionary) -> void:
	stock.clear()
	for cid in 2:
		var s: Dictionary = {}
		for r in RESOURCES:
			s[r] = int(start.get(r, 0))
		stock[cid] = s


func amount(cliff_id: int, res: StringName) -> int:
	if not stock.has(cliff_id):
		return 0
	return int((stock[cliff_id] as Dictionary).get(res, 0))


func can_afford(cliff_id: int, cost: Dictionary) -> bool:
	for r: StringName in cost:
		if amount(cliff_id, r) < int(cost[r]):
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
