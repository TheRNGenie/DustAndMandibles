class_name Breacher
extends RefCounted
## Host-side brain for a bug that crested onto a plateau: walk to the nearest
## structure (or a nearby player), then chew on it; the Homestead is the fallback
## target. Turrets can't touch breachers; players and traps must deal with them.
## Movement is simple steering over the open plateau (no navmesh yet).

const RETARGET_TIME := 0.5
const PLAYER_AGGRO := 7.0

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
	if target == null:
		return
	var to := target.global_position - bug.ground_pos
	to.y = 0.0
	var reach := _radius(target) + float(bug.spec["body_radius"]) + 0.4
	if to.length() > reach:
		var step := to.normalized() * bug.def.walk_speed * bug.speed_mult * delta
		bug.ground_pos += step
		bug.ground_pos.y = Bug.cliffs.ground_height_at(bug.cliff_id, bug.ground_pos)
	else:
		_attack(delta)


func _attack(delta: float) -> void:
	var dmg := bug.def.breach_dps * delta
	if target.has_method("structure_damage"):
		target.call("structure_damage", dmg, bug.def.display_name)
	elif target is Player:
		(target as Player).net.server_damage(dmg)


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	# Nearby players draw aggro first.
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
	for s: Node in bug.get_tree().get_nodes_in_group("structures"):
		var n := s as Node3D
		if int(n.get("cliff_id")) != bug.cliff_id:
			continue
		var d := n.global_position.distance_to(bug.ground_pos)
		if d < best_d:
			best = n
			best_d = d
	return best


static func _radius(n: Node3D) -> float:
	var r: Variant = n.get("radius")
	return float(r) if r != null else 0.6
