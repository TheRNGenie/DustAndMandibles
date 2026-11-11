class_name AmmoStore
extends RefCounted
## Turret ammo: how many ammo sacks (turret loads, CropDef.load_item) a cliff
## can keep of each kind. Every house has its root cellar from the start
## (RootCellar, Logan Nov 11), a bin for every kind holding CELLAR_CAP.

const CARRY_CAP := 4
const CELLAR_CAP := 500


## Every crop that fills ammo sacks, in seed order.
static func crops() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CropPlot.SEEDS:
		var c := Defs.crop(id)
		if c != null and c.load_item != &"":
			out.append(id)
	return out


static func has_cellar(_cliff_id: int) -> bool:
	return true # (every house has its cellar from the start now)


static func cap(cliff_id: int) -> int:
	return CELLAR_CAP if has_cellar(cliff_id) else CARRY_CAP


## Sacks of `item` the cliff still has room for.
static func room(cliff_id: int, item: StringName) -> int:
	return maxi(cap(cliff_id) - Economy.amount(cliff_id, item), 0)


## Host: a harvest's yield with its sacks cut down to the room left (the rest of
## the yield, the side crop, is untouched). Tells `peer_id` when sacks didn't fit.
static func fit(cliff_id: int, crop: CropDef, got: Dictionary, peer_id: int) -> Dictionary:
	var item := crop.load_item
	if item == &"" or not got.has(item):
		return got
	var out := got.duplicate()
	var r := room(cliff_id, item)
	var n := int(got[item])
	if n > r:
		out[item] = r
		if peer_id > 0:
			Economy.notify(peer_id, "Only room for %d of %d %s ammo sacks. %s" % [r, n, crop.display_name.to_lower(), _hint(cliff_id)])
	return out


static func _hint(cliff_id: int) -> String:
	return "Load some turrets."


## Host: may this cliff harvest `crop` now (any room for its sacks)? Tells `peer_id` why not.
static func can_harvest(cliff_id: int, crop: CropDef, peer_id: int) -> bool:
	if crop == null or crop.load_item == &"" or room(cliff_id, crop.load_item) > 0:
		return true
	if peer_id > 0:
		Economy.notify(peer_id, "Your %s ammo sacks are full (%d/%d). %s" % [crop.display_name.to_lower(), cap(cliff_id), cap(cliff_id), _hint(cliff_id)])
	return false
