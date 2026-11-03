class_name StoryAmber
extends RefCounted
## Story chapters 9 and 10 and hive amber: the one place the story touches the
## amber system (item `amber`, a personal resource, and the three amber turret
## blueprints), which is built on another branch.
##
## >>> WIRE TO AMBER AT MERGE <<<
## Every function here is a guarded stub so this branch compiles and plays
## without amber. It already calls main's real API by name, looked up at run
## time: Story.unlock_amber_blueprint(id) (ids queens_bell, mandible_lance) and
## Amber.grant(peer_id, units, why) (host). Without them (this branch) the
## blueprint is only kept in StoryProgress.blueprints and no amber is packed.
## At merge: if main's Story.record already unlocks "amber_blueprint" rewards
## itself, drop the grant_blueprint call in Story.record.

## The amber blueprints the story grants (id -> where it comes from).
const BLUEPRINTS: Dictionary = {
	"queens_bell": "ch9, the board's harvest ledger",
	"mandible_lance": "ch10, the Iron Mandible's wreck",
}
## The amber item's backpack / stockpile key (the amber branch's id).
const ITEM := &"amber"


## Is hive amber in this build? (The Amber autoload, from the amber branch.)
static func available() -> bool:
	return _autoload("Amber") != null


## Is `id` one of the story's amber blueprints (for the chapter data checks)?
static func is_blueprint(id: String) -> bool:
	return BLUEPRINTS.has(id)


## Every peer, when a chapter is won for the first time with an amber
## blueprint unlock: hand the blueprint to the amber system. Returns true when
## the amber system took it (false on this branch: only StoryProgress keeps it).
static func grant_blueprint(id: String) -> bool:
	if not is_blueprint(id):
		return false
	# WIRE TO AMBER AT MERGE: main's real call is Story.unlock_amber_blueprint(id).
	# (If main's Story.record already handles "amber_blueprint" unlocks itself, drop this call.)
	var story := _autoload("Story")
	if story != null and story.has_method("unlock_amber_blueprint"):
		story.call("unlock_amber_blueprint", id)
		return true
	print("[story] amber blueprint %s booked (amber system not in this build)" % id)
	return false


## Host: `units` of hive amber into `peer`'s backpack (the board's crates in the
## amber crew's camp, the Iron Mandible's wreck). Returns the units packed (0
## when amber isn't in this build).
static func pack(peer: int, units: int, why: String = "") -> int:
	if units <= 0:
		return 0
	# WIRE TO AMBER AT MERGE: main's real call is Amber.grant(peer_id, units, why) (host only).
	var amber := _autoload("Amber")
	if amber != null and amber.has_method("grant"):
		amber.call("grant", peer, units, why)
		return units
	return 0


## An autoload by name (looked up at run time, so the unit tests can load this file).
static func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(node_name) if tree != null else null


## Every peer, after The Reckoning is won: the bounty board is gone and the
## canyon's amber is the ranchers' to take. Nothing to do on this branch.
static func after_reckoning() -> void:
	# WIRE TO AMBER AT MERGE: open free amber harvesting / retire the bounty board if the amber branch has one.
	pass
