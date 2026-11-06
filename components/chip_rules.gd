class_name ChipRules
extends RefCounted
## Casino chips (Logan): Pearl sells them at her cage on the airship for team
## chitin; the tables take them as stakes and pay winnings in your own scrap.
## Chips aren't carried items: each cliff holds a count of each colour in its
## Economy stockpile (&"chip_10" ...), shown on the HUD under the currencies.
## Pure rules, no autoloads (unit tested).

## Face values, smallest first. Every bet is a multiple of the smallest.
const DENOMS: Array[int] = [10, 20, 50, 100]
const NAMES: Dictionary = {10: "Red", 20: "Green", 50: "Blue", 100: "Black"}
## Team chitin per point of face value.
const PRICE_PER := 1


static func id_of(v: int) -> StringName:
	return StringName("chip_%d" % v)


static func is_chip(id: StringName) -> bool:
	return String(id).begins_with("chip_") and DENOMS.has(int(String(id).substr(5)))


static func value_of(id: StringName) -> int:
	return int(String(id).substr(5)) if is_chip(id) else 0


static func price(v: int) -> int:
	return v * PRICE_PER


## Every chip id, smallest first.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for v in DENOMS:
		out.append(id_of(v))
	return out


## Face value of a holding {chip id: count}.
static func total(held: Dictionary) -> int:
	var t := 0
	for id: StringName in held:
		t += value_of(id) * int(held[id])
	return t


## Pays `amount` out of `held` {chip id: count}: biggest chips first, and when
## nothing adds up exactly the house breaks a bigger chip into reds and keeps
## the change on your stack. Returns {"spend": {id: n}, "add": {id: n}} (apply
## spend, then add), or {} when the chips don't cover it.
static func pay(held: Dictionary, amount: int) -> Dictionary:
	if amount <= 0 or total(held) < amount or amount % DENOMS[0] != 0:
		return {}
	var left := {}
	for v in DENOMS:
		left[v] = int(held.get(id_of(v), 0))
	var spend := {}
	var add := {}
	var rest := amount
	for i in range(DENOMS.size() - 1, -1, -1):
		var v := DENOMS[i]
		var k := mini(int(left[v]), rest / v)
		if k > 0:
			left[v] = int(left[v]) - k
			spend[id_of(v)] = int(spend.get(id_of(v), 0)) + k
			rest -= k * v
	if rest > 0:
		# Change: the smallest chip still on the stack (it's bigger than what's owed).
		var small := DENOMS[0]
		for v in DENOMS:
			if int(left[v]) > 0:
				left[v] = int(left[v]) - 1
				spend[id_of(v)] = int(spend.get(id_of(v), 0)) + 1
				var reds := (v - rest) / small
				if reds > 0:
					add[id_of(small)] = reds
				rest = 0
				break
	if rest > 0:
		return {}
	return {"spend": spend, "add": add}
