class_name Breacher
extends RefCounted
## Host-side brain for a bug on a plateau: walk to the nearest structure (or a
## nearby player), then chew on it; the Homestead is the fallback target.
## Crop Weevils go for growing crops instead. Burrow Ticks travel underground and
## only surface next to their target or inside a lantern's light.
## Turrets can't touch any of these; players and traps must deal with them.
## Movement is simple steering over the open plateau (no navmesh yet).

const RETARGET_TIME := 0.5
const PLAYER_AGGRO := 7.0
const SURFACE_DISTANCE := 3.0

var bug: Bug
var target: Node3D
var _retarget := 0.0
var _up_t := 0.0
var _tried_steal := false
## Grabbed loot and heading back over the lip (killing it drops the loot).
var retreating := false
static var _last_notice: Dictionary = {}


func _init(b: Bug) -> void:
	bug = b


func update(delta: float) -> void:
	if retreating:
		_retreat(delta)
		return
	if bug.state == Bug.State.BREACHING and not _tried_steal and BreachRules.is_thief(bug.def):
		_up_t += delta
		if _up_t >= BreachRules.STEAL_AFTER:
			_steal()
			if retreating:
				return
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(target):
		_retarget = RETARGET_TIME
		target = _pick_target()
	if bug.state == Bug.State.BURROWED and _should_surface():
		bug.state = Bug.State.BREACHING
	if target == null:
		return
	var to := target.global_position - bug.ground_pos
	to.y = 0.0
	var reach := _radius(target) + float(bug.spec["body_radius"]) + 0.4
	if to.length() > reach:
		var step := to.normalized() * bug.def.walk_speed * bug.speed() * delta
		bug.ground_pos += step
		bug.ground_pos.y = Bug.cliffs.ground_height_at(bug.cliff_id, bug.ground_pos)
	elif bug.state == Bug.State.BREACHING and not bug.status.is_stunned(): # (a Flashbang's daze stops the chewing)
		_attack(delta)


func _steal() -> void:
	_tried_steal = true
	if GameState.phase != GameState.Phase.WAVE:
		return
	var got := Economy.breach_steal(bug.cliff_id, BreachRules.steal_amounts(bug.def))
	if got.is_empty():
		return # nothing left to take: it stays and fights
	bug.stolen = got
	retreating = true
	target = null
	# One feed line every few seconds per cliff, so a big breach doesn't flood the feed.
	var now := Time.get_ticks_msec()
	if now - int(_last_notice.get(bug.cliff_id, -99999)) < 4000:
		return
	_last_notice[bug.cliff_id] = now
	Economy.notify_cliff(bug.cliff_id, "A %s grabbed %s and is running for the lip! Shoot it to get it back." % [bug.def.display_name, Economy.describe(got)])


func _retreat(delta: float) -> void:
	if bug.state != Bug.State.BREACHING:
		return
	# Maps: the nearest bit of its own lip (along the lip, in that cliff's frame).
	var lip := Bug.cliffs.plateau_point(bug.cliff_id, 0.2, Bug.cliffs.plateau_coords(bug.cliff_id, bug.ground_pos).y)
	var to := lip - bug.ground_pos
	to.y = 0.0
	var step := bug.def.walk_speed * bug.speed() * BreachRules.RETREAT_SPEED * delta
	if to.length() <= step + 0.3:
		bug.escaped() # over the edge with the goods
		return
	bug.ground_pos += to.normalized() * step
	bug.ground_pos.y = Bug.cliffs.ground_height_at(bug.cliff_id, bug.ground_pos)


func _should_surface() -> bool:
	if target != null and target.global_position.distance_to(bug.ground_pos) < SURFACE_DISTANCE + _radius(target):
		return true
	for l: Node in bug.get_tree().get_nodes_in_group("lanterns"):
		var lantern := l as Node3D
		if lantern.global_position.distance_to(bug.ground_pos) < float(lantern.call("reveal_radius")):
			return true
	return false


func _attack(delta: float) -> void:
	if target is CropPlot:
		(target as CropPlot).eaten()
		target = null
		return
	var dmg := bug.def.breach_dps * delta * Defs.WAVE_CONFIG.damage_scale(GameState.wave)
	if target.has_method("structure_damage"):
		target.call("structure_damage", dmg, bug.def.display_name)
	elif target is Player:
		(target as Player).net.server_damage(dmg)


func _pick_target() -> Node3D:
	if bug.def.behavior == BugDef.Behavior.CROP_EATER:
		var crop := _nearest_in_group("crops", func(n: Node3D) -> bool: return (n as CropPlot).has_crop())
		if crop != null:
			return crop
	var best: Node3D = null
	var best_d := INF
	# Nearby players draw aggro first (not for bugs still underground).
	if bug.state == Bug.State.BREACHING:
		for p: Node in bug.get_tree().get_nodes_in_group("players"):
			var pl := p as Player
			if pl.cliff_id != bug.cliff_id or pl.is_downed():
				continue
			var d := pl.global_position.distance_to(bug.ground_pos)
			if d < PLAYER_AGGRO and d < best_d:
				best = pl
				best_d = d
	if best != null:
		return best
	return _nearest_in_group("structures", func(_n: Node3D) -> bool: return true)


func _nearest_in_group(group: String, accept: Callable) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for s: Node in bug.get_tree().get_nodes_in_group(group):
		var n := s as Node3D
		if int(n.get("cliff_id")) != bug.cliff_id or not accept.call(n):
			continue
		var d := n.global_position.distance_to(bug.ground_pos)
		if d < best_d:
			best = n
			best_d = d
	return best


static func _radius(n: Node3D) -> float:
	var r: Variant = n.get("radius")
	return float(r) if r != null else 0.6
