class_name HarvestRules
extends RefCounted
## Where a harvest goes (playtest fixes, Nov 2026): the crops into the
## harvester's carry (PlayerCarry, 25 of each; what won't fit drops at the plot
## for anyone to pick up), anything else (the pear's water) into the cliff's
## stock. The ammo workbench in the root cellar (CropWorkbench) turns carried
## crops into turret sacks at SACKS_PER_CROP each.

## Sacks the workbench makes from one crop (AmmoBenchMenu.PER_CROP shows it).
const SACKS_PER_CROP := 3


## Host: hand out one harvest `got` ({item: n}) of `crop`, picked by `peer_id`.
static func deliver(tree: SceneTree, payer_cliff: int, peer_id: int, crop: CropDef, got: Dictionary, spill_at: Vector3) -> void:
	var carry := PlayerCarry.of(tree, peer_id)
	var stock := {}
	for item: StringName in got:
		var n := int(got[item])
		var c := PlayerCarry.crop_of_item(item)
		if c == &"" or carry == null:
			stock[item] = int(stock.get(item, 0)) + n # water, or nobody to carry it
			continue
		var fit := carry.add(c, n)
		for k in n - fit: # (arms full: the rest drops where it grew)
			if PickupManager.instance != null:
				PickupManager.instance.spawn_item(item, spill_at + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)))
		if fit > 0 and peer_id > 0:
			Economy.notify(peer_id, "+%d %s (%d/%d carried). The cellar's workbench makes %d sacks from each." % [fit,
					Defs.crop(c).display_name.to_lower() if Defs.crop(c) != null else String(item), carry.amount(c), PlayerCarry.CAP,
					SACKS_PER_CROP])
	if not stock.is_empty():
		Economy.earn(payer_cliff, stock)


## How many of `n` crops the bench turns into sacks: no more than you carry, and
## no more than the bin has room for (SACKS_PER_CROP a crop).
static func convertible(n: int, carried: int, room: int) -> int:
	return maxi(mini(mini(n, carried), room / SACKS_PER_CROP), 0)
