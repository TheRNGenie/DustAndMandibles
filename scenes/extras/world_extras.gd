class_name WorldExtras
extends Node3D
## Holds the smaller world features that sit beside the main systems: the
## turret coverage table (heat map + weak-spot bias), wanted posters on the
## houses, the corpse piles at the cliff bases and a campfire by each house.
## Created by the world on every peer with a fixed name, so RPCs line up.

var cliffs: CliffBuilder
var coverage: CoverageMap
var posters: WantedPosters
var corpses: CorpsePile


func _ready() -> void:
	if GameState.has_flag("--noextras"):
		return # debug: run without these features (A/B checks)
	coverage = CoverageMap.new()
	coverage.name = "Coverage"
	coverage.cliffs = cliffs
	add_child(coverage)
	posters = WantedPosters.new()
	posters.name = "Posters"
	add_child(posters)
	corpses = CorpsePile.new()
	corpses.name = "Corpses"
	corpses.cliffs = cliffs
	add_child(corpses)
	# The houses are built by the world dressing before this; give it a frame anyway.
	_add_campfires.call_deferred()


func _add_campfires() -> void:
	for cid in 2:
		var fire := Campfire.new()
		fire.name = "Campfire%d" % cid
		fire.cliff_id = cid
		fire.position = Campfire.spot(cliffs, cid)
		fire.rotation.y = WorldLayout.facing_canyon_yaw(cid)
		add_child(fire)
