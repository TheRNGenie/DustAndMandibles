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


func _init(b: Bug) -> void:
	bug = b


func update(delta: float) -> void:
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
	elif bug.state == Bug.State.BREACHING:
		_attack(delta)


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
	var dmg := bug.def.breach_dps * delta
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
