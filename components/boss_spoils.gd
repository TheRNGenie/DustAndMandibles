class_name BossSpoils
extends RefCounted
## Boss spoils (Nov 11 playtest fixes): a boss's Meteor Iron and turret parts,
## and a heavy bug's rare drop, no longer go to whichever cliff it climbed. They
## wait for the wave's end, and then every cliff gets its own copy
## (BugManager._on_phase_spoils), listed in the wave summary.

## Parts a boss leaves (CraftTable).
const BOSS_PARTS := 2


## What one kill leaves ({item: n}): a boss always Meteor Iron and BOSS_PARTS
## parts; a heavy bug Meteor Iron at GunRarity.HEAVY_CHANCE and a part at
## BugManager.PART_CHANCE_HEAVY (`r_iron`, `r_part`: 0-1 rolls).
static func roll(boss: bool, heavy: bool, r_iron: float, r_part: float) -> Dictionary:
	var out := {}
	var parts := 0
	if boss:
		out[GunRarity.ITEM] = 1
		parts = BOSS_PARTS
	elif heavy:
		if r_iron < GunRarity.HEAVY_CHANCE:
			out[GunRarity.ITEM] = 1
		if r_part < BugManager.PART_CHANCE_HEAVY:
			parts = 1
	for i in parts:
		add(out, {CraftTable.random_part(): 1})
	return out


static func add(into: Dictionary, got: Dictionary) -> void:
	for k: Variant in got:
		into[k] = int(into.get(k, 0)) + int(got[k])
