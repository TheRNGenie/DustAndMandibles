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
## Seeds cost scrap, harvests sell for chitin; this rate converts between them.
const SCRAP_PER_CHITIN := 10.0
## A seed costs this fraction of what its harvest returns at the base price.
const SEED_FRACTION := 1.0 / 3.0


## Scrap price of one seed: a third of the crop's average return (harvest yield x
## base price), converted to scrap. Corn: 3 corn x 1.0 chitin = 3 -> 30 scrap -> 10.
static func seed_price(crop: CropDef) -> int:
	var value := 0.0
	for item: StringName in crop.harvest:
		value += float(BASE.get(item, 0.0)) * int(crop.harvest[item])
	return maxi(int(roundf(value * SCRAP_PER_CHITIN * SEED_FRACTION)), 1)

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
