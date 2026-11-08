class_name HeavyAmmo
extends RefCounted
## Host: what's in every universal heavy (HeavyRules): peer id -> {gun id: [crop,
## shots left]}. The host takes the sack, counts every confirmed shot down and
## refuses a shot from an empty gun, so a dropped gun, a saved run and the ring
## other riders see all agree with the owner's own counter (Gun.ammo).

static var loads: Dictionary = {}


static func reset() -> void:
	loads.clear()


## [crop, shots] in peer's gun `id` ([&"", 0] when empty or unknown).
static func of(peer_id: int, id: StringName) -> Array:
	var guns: Dictionary = loads.get(peer_id, {})
	var e: Variant = guns.get(id)
	return (e as Array).duplicate() if e is Array else [&"", 0]


static func put(peer_id: int, id: StringName, crop: StringName, shots: int) -> void:
	if not loads.has(peer_id):
		loads[peer_id] = {}
	if crop == &"" or shots <= 0:
		(loads[peer_id] as Dictionary)[id] = [&"" if shots <= 0 else crop, maxi(shots, 0)]
	else:
		(loads[peer_id] as Dictionary)[id] = [crop, shots]


static func forget(peer_id: int, id: StringName) -> void:
	if loads.has(peer_id):
		(loads[peer_id] as Dictionary).erase(id)


## Host: one shot from peer's `id`. Returns the crop it carries, or &"" if the
## gun is empty (no shot). `ran_out` is set true when this was the last one.
static func take_shot(peer_id: int, id: StringName) -> Dictionary:
	var e := of(peer_id, id)
	var crop: StringName = e[0]
	var left := int(e[1])
	if crop == &"" or left <= 0:
		return {"crop": &"", "ran_out": false}
	left -= 1
	put(peer_id, id, crop if left > 0 else &"", left)
	return {"crop": crop, "ran_out": left <= 0}


## For the run save: one cliff's guns, {gun id: [crop, shots]} with only loaded ones.
static func save_of(peer_id: int) -> Dictionary:
	var out: Dictionary = {}
	var guns: Dictionary = loads.get(peer_id, {})
	for id: StringName in guns:
		var e: Array = guns[id]
		if StringName(e[0]) != &"" and int(e[1]) > 0:
			out[String(id)] = [String(e[0]), int(e[1])]
	return out


## A saved cliff's guns back (from save_of, through JSON) as {id: [crop, shots]}.
static func from_save(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k: Variant in raw:
		var e: Variant = raw[k]
		if e is Array and (e as Array).size() >= 2 and CropEffects.is_crop(StringName(str(e[0]))):
			out[StringName(str(k))] = [StringName(str(e[0])), maxi(int(e[1]), 0)]
	return out
