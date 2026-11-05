class_name ExpeditionApi
extends RefCounted
## Canyon Expeditions: the one door the expedition SITES (scenes/expedition/)
## use into the expedition CORE (the `Expedition` autoload: rope anchors, the
## lever lock, the backpack, noise). Every call looks the autoload up by name at
## run time and forwards to it; when it isn't there (a build without the core,
## unit tests) each call falls back to something sensible:
##   add_to_backpack -> straight into the player's cliff stockpile (Economy.earn)
##   is_down         -> the player's node is below FLOOR_Y
##   make_noise      -> emitted on a local relay signal (connect_noise listens to it)
##   floor_time      -> seconds the player has been below FLOOR_Y (SiteManager ticks it)
## Site code never touches the autoload directly: only this class.

## Below this height a player counts as down on the canyon floor (fallback).
const FLOOR_Y := WorldLayout.CLIFF_HEIGHT * 0.33

## --floor=N (debug): players may stand on the floor without the fall-and-respawn.
static var debug_floor := false
## Fallback floor clocks: peer id -> seconds below FLOOR_Y (ticked by SiteManager).
static var _floor_t: Dictionary = {}
static var _relay: NoiseRelay


## Holds the fallback `noise` signal (a static class can't own one).
class NoiseRelay:
	extends RefCounted
	signal noise(pos: Vector3, radius: float)


## Rule (Logan): only a Story chapter opens the canyon floor. Endless and the
## Tutorial have no rope winch, no raid sites, no floor loot and no floor bugs.
static func floor_open_for(story_active: bool, tutorial: bool) -> bool:
	return story_active and not tutorial


## The rule for this run, read from the Story and GameState autoloads by name
## (closed when they aren't there, e.g. unit tests).
static func floor_open() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return false
	var story := loop.root.get_node_or_null("Story")
	var gs := loop.root.get_node_or_null("GameState")
	var active := story != null and bool(story.call("active"))
	var tut := gs != null and bool(gs.get("tutorial"))
	return floor_open_for(active, tut)


static func core() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null("Expedition")


static func _relay_obj() -> NoiseRelay:
	if _relay == null:
		_relay = NoiseRelay.new()
	return _relay


## Host: puts `items` ({key: units}) in the player's backpack. Returns how many
## units fit (the rest stays on the ground). Fallback: all of it, into the
## player's cliff stockpile.
static func add_to_backpack(peer_id: int, items: Dictionary) -> int:
	var c := core()
	if c != null and c.has_method("add_to_backpack"):
		return int(c.call("add_to_backpack", peer_id, items))
	var total := 0
	for k: Variant in items:
		total += maxi(int(items[k]), 0)
	if total <= 0:
		return 0
	var econ := _economy()
	if econ != null:
		var cliff := cliff_of(peer_id)
		econ.call("earn", int(econ.call("payer_cliff", peer_id, cliff)), items)
	return total


## Is this player down on the canyon floor?
static func is_down(peer_id: int) -> bool:
	var c := core()
	if c != null and c.has_method("is_down"):
		return bool(c.call("is_down", peer_id))
	var p := player_node(peer_id)
	return p != null and p.global_position.y < FLOOR_Y


## Something loud happened on the floor (a gunshot, a trap, a cave-in).
static func make_noise(pos: Vector3, radius: float) -> void:
	var c := core()
	if c != null and c.has_method("make_noise"):
		c.call("make_noise", pos, radius)
		return
	_relay_obj().noise.emit(pos, radius)


## Seconds this player has spent on the floor this trip.
static func floor_time(peer_id: int) -> float:
	var c := core()
	if c != null and c.has_method("floor_time"):
		return float(c.call("floor_time", peer_id))
	return float(_floor_t.get(peer_id, 0.0))


## Listens to noise: the core's signal when it's there, else the local relay.
static func connect_noise(cb: Callable) -> void:
	var c := core()
	if c != null and c.has_signal("noise"):
		if not c.is_connected("noise", cb):
			c.connect("noise", cb)
		return
	if not _relay_obj().noise.is_connected(cb):
		_relay_obj().noise.connect(cb)


static func disconnect_noise(cb: Callable) -> void:
	var c := core()
	if c != null and c.has_signal("noise") and c.is_connected("noise", cb):
		c.disconnect("noise", cb)
	if _relay != null and _relay.noise.is_connected(cb):
		_relay.noise.disconnect(cb)


## Fallback floor clock: called by SiteManager every frame with every player.
static func tick_floor_clock(peer_id: int, down: bool, delta: float) -> void:
	if down:
		_floor_t[peer_id] = float(_floor_t.get(peer_id, 0.0)) + delta
	else:
		_floor_t.erase(peer_id)


# ------------------------------------------------------------------ helpers

static func player_node(peer_id: int) -> Node3D:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	for n: Node in loop.get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			return n as Node3D
	return null


static func cliff_of(peer_id: int) -> int:
	var p := player_node(peer_id)
	if p != null and p.get("cliff_id") != null:
		return int(p.get("cliff_id"))
	var nm := _autoload("NetworkManager")
	return int(nm.call("cliff_of", peer_id)) if nm != null else 0


static func _economy() -> Node:
	return _autoload("Economy")


static func _autoload(n: String) -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null(n)
