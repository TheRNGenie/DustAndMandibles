class_name MarketPrices
extends RefCounted
## Vendor prices in chitin. Each vegetable has a base price and a multiplier from
## 0.5 to 1.5: selling pushes it down, and it drifts back up (to +50%) while you
## don't sell that vegetable. Pure logic so it can be unit-tested.

const BASE: Dictionary = {&"corn": 1.0, &"prickly_pear": 1.6, &"chili": 1.2, &"herbs": 2.2}
const MIN_MULT := 0.5
const MAX_MULT := 1.5
## Each unit sold lowers that vegetable's price by this much (fraction of base).
const DROP_PER_SALE := 0.05
## Recovery per second while not selling (0.5 -> 1.5 in about four minutes).
const RECOVERY_PER_SEC := 0.0042

var mult: Dictionary = {}


func _init() -> void:
	for k: StringName in BASE:
		mult[k] = 1.0


func price(item: StringName) -> float:
	return float(BASE.get(item, 0.0)) * float(mult.get(item, 1.0))


## Sells `count` units; returns the total chitin earned (fractional).
func sell(item: StringName, count: int = 1) -> float:
	if not BASE.has(item):
		return 0.0
	var total := 0.0
	for i in count:
		total += price(item)
		mult[item] = maxf(float(mult[item]) - DROP_PER_SALE, MIN_MULT)
	return total


func tick(seconds: float) -> void:
	for k: StringName in mult:
		mult[k] = minf(float(mult[k]) + RECOVERY_PER_SEC * seconds, MAX_MULT)
