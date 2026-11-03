class_name StoryAmber
extends RefCounted
## Story chapters 9 and 10 and hive amber: the one place the story touches the
## amber system (item `amber`, a personal resource, and the three amber turret
## blueprints), which is built on another branch.
##
## >>> WIRE TO AMBER AT MERGE <<<
## Every function here is a guarded stub so this branch compiles and plays
## without amber: available() is false until the amber item exists, so the
## chapters simply skip their amber bits; grant_blueprint() only remembers the
## id (StoryProgress.blueprints) and reports it. At merge, point these at the
## amber helper's real calls (its blueprint unlock, its pack / stockpile item).

## The amber blueprints the story grants (id -> where it comes from).
const BLUEPRINTS: Dictionary = {
	"amber_queens_bell": "ch9, the board's harvest ledger",
	"amber_mandible_lance": "ch10, the Iron Mandible's wreck",
}
## The amber item's backpack / stockpile key (the amber branch's id).
const ITEM := &"amber"


## Is hive amber in this build? (False on the story branch: the amber item and
## its weight live on the amber branch.)
static func available() -> bool:
	# WIRE TO AMBER AT MERGE: true once Backpack.WEIGHTS / Economy know &"amber".
	return Backpack.WEIGHTS.has(ITEM)


## Is `id` one of the story's amber blueprints (for the chapter data checks)?
static func is_blueprint(id: String) -> bool:
	return BLUEPRINTS.has(id)


## Every peer, when a chapter is won for the first time with an amber
## blueprint unlock: hand the blueprint to the amber system. Returns true when
## the amber system took it (false on this branch: only StoryProgress keeps it).
static func grant_blueprint(id: String) -> bool:
	if not is_blueprint(id):
		return false
	# WIRE TO AMBER AT MERGE: e.g. Amber.unlock_blueprint(id) / Perks.profile.amber_blueprints.
	var amber := _autoload("Amber")
	if amber != null and amber.has_method("unlock_blueprint"):
		amber.call("unlock_blueprint", id)
		return true
	print("[story] amber blueprint %s booked (amber system not in this build)" % id)
	return false


## Host: `units` of hive amber into `peer`'s backpack (the board's crates in the
## amber crew's camp, the Iron Mandible's wreck). Returns the units packed (0
## when amber isn't in this build).
static func pack(peer: int, units: int) -> int:
	if not available() or units <= 0:
		return 0
	# WIRE TO AMBER AT MERGE: amber is a normal (unpacked) item, so it goes in like loot.
	var xp := _autoload("Expedition")
	return int(xp.call("add_to_backpack", peer, {ITEM: units})) if xp != null else 0


## An autoload by name (looked up at run time, so the unit tests can load this file).
static func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(node_name) if tree != null else null


## Every peer, after The Reckoning is won: the bounty board is gone and the
## canyon's amber is the ranchers' to take. Nothing to do on this branch.
static func after_reckoning() -> void:
	# WIRE TO AMBER AT MERGE: open free amber harvesting / retire the bounty board if the amber branch has one.
	pass
