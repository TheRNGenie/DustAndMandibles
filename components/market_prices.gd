class_name MarketPrices
extends RefCounted
## Vendor prices. Every crop sells at the produce vendor for team chitin (internal
## &"scrap"); only sarsaparilla pays your own scrap (internal &"chitin") (Logan, Nov 11). Each vegetable has a base price (in its own currency) and a multiplier from
## 0.5 to 1.5: selling pushes it down, and it drifts back up (to +50%) while you
## don't sell that vegetable. Pure logic so it can be unit-tested.

## (Canyon Expeditions: nest eggs and Doc's specimen jars, brought up from the floor, sell here too.)
const BASE: Dictionary = {&"corn": 10.0, &"prickly_pear": 16.0, &"chili": 14.0, &"herbs": 22.0,
	&"cotton": 10.0, &"sulfur_root": 16.0, &"barrel_cactus": 20.0, &"tumbleweed_vine": 10.0, &"sarsaparilla": 3.0,
	&"egg": 18.0, &"specimen": 14.0}
## What each vegetable is paid in.
const CURRENCY: Dictionary = {&"corn": &"scrap", &"prickly_pear": &"scrap", &"chili": &"scrap", &"herbs": &"scrap",
	&"cotton": &"scrap", &"sulfur_root": &"scrap", &"barrel_cactus": &"scrap", &"tumbleweed_vine": &"scrap",
	&"sarsaparilla": &"chitin", &"egg": &"scrap", &"specimen": &"chitin"}
## Fixed seed prices (scrap) that override the one-third rule.
## Corn is the cheap, quick crop: its seeds are a bargain.
## Sarsaparilla is mostly grown for your partner's tonic, so its seed has a set price.
## Turret ammo: harvests now give turret loads (never sold), so every seed has a set price
## (pear and herbs kept at what their old harvests made them).
const SEED_OVERRIDE: Dictionary = {&"firecracker_chili": 20, &"corn": 8, &"sarsaparilla": 18, &"prickly_pear": 11, &"herbs": 15,
	&"cotton": 10, &"sulfur_root": 18, &"barrel_cactus": 24, &"tumbleweed_vine": 10}
const MIN_MULT := 0.5
const MAX_MULT := 1.5
## Each unit sold lowers that vegetable's price by this much (fraction of base).
const DROP_PER_SALE := 0.05
## Recovery per second while not selling (0.5 -> 1.5 in about four minutes).
const RECOVERY_PER_SEC := 0.0042
## Converts chitin to scrap for seed prices of crops that sell for chitin.
const SCRAP_PER_CHITIN := 10.0
## A seed costs this fraction of what its harvest returns at the base price.
const SEED_FRACTION := 1.0 / 3.0


## Scrap price of one seed: a third of the crop's average return (harvest yield x
## base price), in scrap. Herbs: 2 herbs x 22 scrap = 44 scrap -> 15.
static func seed_price(crop: CropDef) -> int:
	if SEED_OVERRIDE.has(crop.id):
		return int(SEED_OVERRIDE[crop.id])
	var value := 0.0
	for item: StringName in crop.harvest:
		var rate := SCRAP_PER_CHITIN if currency(item) == &"chitin" else 1.0
		value += float(BASE.get(item, 0.0)) * rate * int(crop.harvest[item])
	return maxi(int(roundf(value * SEED_FRACTION)), 1)


static func currency(item: StringName) -> StringName:
	return CURRENCY.get(item, &"scrap")

var mult: Dictionary = {}


func _init() -> void:
	for k: StringName in BASE:
		mult[k] = 1.0


func price(item: StringName) -> float:
	return float(BASE.get(item, 0.0)) * float(mult.get(item, 1.0))


## Sells `count` units; returns the total earned in that item's currency (fractional).
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
