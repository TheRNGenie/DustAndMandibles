class_name Backpack
extends RefCounted
## Canyon Expeditions: one player's backpack, pure bookkeeping (no networking,
## so it can be unit-tested). The Expedition autoload keeps one per player on
## the host and syncs its contents. Separate from the cliff stockpile
## (EconomyLedger): what's in here is only yours once you carry it home.
##
## Capacity is in weight units. Every item has a weight per unit (WEIGHTS;
## anything unlisted weighs DEFAULT_WEIGHT), so a pack holds lots of light
## scrap or a few heavy relics. The fuller it is the slower you walk.

const CAPACITY := 80 # about 2-3 raid sites a trip (a scrap pile is ~20 units)
const DEFAULT_WEIGHT := 1
## Weight of one unit of each item (unlisted items weigh DEFAULT_WEIGHT).
const WEIGHTS: Dictionary = {
	&"scrap": 1,
	&"chitin": 2,
	&"water": 2,
	&"corn": 1,
	&"prickly_pear": 1,
	&"chili": 1,
	&"herbs": 1,
	&"sarsaparilla": 1,
	&"upgrade_token": 1,
	&"bone": 3,
	&"relic": 4,
	&"ore": 3,
	&"rail_iron": 4,
	&"egg": 2,
	# Story items (a chapter's job, never unpacked onto the stockpile).
	&"dynamite": 35,
	&"pump_valve": 10,
	&"queen_gland": 8,
	&"family_papers": 6, # The Dry Gulch Families: a homestead's deed and letters in a tin box
	&"harvest_ledger": 10, # ...and the board's harvest ledger from the amber crew's camp
}
## Walking speed at a full pack (straight line from 1.0 at empty).
const FULL_SPEED := 0.62
## Pick-ups listed here weigh nothing (seeds, tokens' paperwork and such ride in a pocket).
const POCKET: Array[StringName] = [&"seed_corn", &"seed_prickly_pear", &"seed_chili", &"seed_herbs", &"seed_sarsaparilla"]

var capacity := CAPACITY
## {item: units}
var items: Dictionary = {}
## What the last add() couldn't fit ({item: units}).
var leftover: Dictionary = {}


static func make(contents: Dictionary = {}, cap: int = CAPACITY) -> Backpack:
	var b := Backpack.new()
	b.capacity = cap
	for k: Variant in contents:
		var n := int(contents[k])
		if n > 0:
			b.items[StringName(k)] = n
	return b


static func weight_of(item: StringName) -> int:
	if POCKET.has(item):
		return 0
	return int(WEIGHTS.get(item, DEFAULT_WEIGHT))


## Total weight of a set of items.
static func weigh(contents: Dictionary) -> int:
	var w := 0
	for k: Variant in contents:
		w += weight_of(StringName(k)) * maxi(int(contents[k]), 0)
	return w


func weight() -> int:
	return weigh(items)


func room() -> int:
	return maxi(capacity - weight(), 0)


func is_empty() -> bool:
	return items.is_empty()


func units() -> int:
	var n := 0
	for k: Variant in items:
		n += int(items[k])
	return n


## Adds as much of `offer` as fits, item by item in the order given (a partial
## stack goes in if only some of it fits). Returns how many units went in;
## what didn't fit is left in `leftover`.
func add(offer: Dictionary) -> int:
	leftover = {}
	var fitted := 0
	for k: Variant in offer:
		var item := StringName(k)
		var want := int(offer[k])
		if want <= 0:
			continue
		var w := weight_of(item)
		var n := want if w == 0 else mini(want, room() / w)
		if n > 0:
			items[item] = int(items.get(item, 0)) + n
			fitted += n
		if n < want:
			leftover[item] = want - n
	return fitted


## Empties the pack and returns what was in it.
func take_all() -> Dictionary:
	var out := items
	items = {}
	return out


## 0..1 how full by weight.
func load_fraction() -> float:
	return clampf(float(weight()) / float(maxi(capacity, 1)), 0.0, 1.0)


## Walking speed multiplier: 1.0 empty, FULL_SPEED full.
func speed_mult() -> float:
	return speed_for(weight(), capacity)


static func speed_for(w: int, cap: int = CAPACITY) -> float:
	return lerpf(1.0, FULL_SPEED, clampf(float(w) / float(maxi(cap, 1)), 0.0, 1.0))
