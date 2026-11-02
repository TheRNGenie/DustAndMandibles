class_name BreachRules
extends RefCounted
## Breach thieves (pure rules, unit-tested): a bug that survives a few seconds up
## on the plateau grabs loot from that cliff's stockpile and runs for the lip.
## Kill it on the way out and the loot drops where it dies.

## Seconds a bug survives on the plateau before it grabs loot and runs.
const STEAL_AFTER := 5.0
## Retreating thieves scurry a bit faster than they walk in.
const RETREAT_SPEED := 1.35


## Small and mid bugs grab loot; brutes, bosses and the specialists just keep chewing.
static func is_thief(d: BugDef) -> bool:
	match d.behavior:
		BugDef.Behavior.TANK, BugDef.Behavior.BROOD, BugDef.Behavior.BOSS, BugDef.Behavior.FLIER, BugDef.Behavior.CROP_EATER:
			return false
	return true


## What one thief tries to carry off.
static func steal_amounts(d: BugDef) -> Dictionary:
	return {&"scrap": 4 + int(round(3.0 * d.size)), &"chitin": 1}


## "12 scrap and 2 chitin" for messages.
static func describe(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r: StringName in amounts:
		parts.append("%d %s" % [int(amounts[r]), String(r)])
	return " and ".join(parts)
