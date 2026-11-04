class_name FloorHunter
extends RefCounted
## Host-side brain for a bug sleeping at a canyon-floor raid site (Canyon
## Expeditions). SLEEPING: curled up where it lies until a player on the floor
## comes within its wake range, a shot hits it, or a noise reaches it
## (SiteManager wakes it). HUNTING: runs down the nearest player on the floor
## and bites; it never climbs, and it won't stray more than LEASH metres from
## home. With nobody on the floor to chase it wanders back and goes to sleep.

const LEASH := 34.0
const RETARGET := 0.4
const WAKE_CHECK := 0.3
## Seconds without anyone to chase before it settles back down at home.
const GIVE_UP := 5.0

var bug: Bug
var home := Vector3.ZERO
var target: Node3D
var _retarget := 0.0
var _check := 0.0
var _lost := 0.0


func _init(b: Bug) -> void:
	bug = b
	home = b.ground_pos


## Host: up and hunting (a noise, a hit, someone close).
func wake() -> void:
	if bug.state != Bug.State.SLEEPING:
		return
	bug.state = Bug.State.HUNTING
	_lost = 0.0
	_retarget = 0.0


## Host: a big noise (the grapple's dynamite) at `pos`: with nobody to chase it
## goes to look there for `seconds` (still on its leash).
func lure(pos: Vector3, seconds: float) -> void:
	_lure = pos
	_lure_t = maxf(_lure_t, seconds)
	_lost = 0.0


var _lure := Vector3.ZERO
var _lure_t := 0.0


func hunt_speed() -> float:
	return (bug.def.walk_speed * 1.6 + 1.0) * bug.speed()


func update(delta: float) -> void:
	if bug.state == Bug.State.SLEEPING:
		_check -= delta
		if _check <= 0.0:
			_check = WAKE_CHECK
			var r := SitePlan.wake_range(bug.def.id)
			for p: Node in bug.get_tree().get_nodes_in_group("players"):
				var pl := p as Node3D
				if _flat_dist(pl.global_position, bug.ground_pos) < r and _huntable(pl):
					wake()
					break
		return
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(target):
		_retarget = RETARGET
		target = _pick_target()
	_lure_t = maxf(_lure_t - delta, 0.0)
	if target == null and _lure_t > 0.0:
		_walk_to(_lure, delta) # off to see what blew up
		return
	if target == null:
		_lost += delta
		_walk_to(home, delta * 0.6)
		if _lost >= GIVE_UP and _flat_dist(bug.ground_pos, home) < 0.8:
			bug.state = Bug.State.SLEEPING
		return
	_lost = 0.0
	var reach := 0.8 + float(bug.spec["body_radius"])
	if _flat_dist(target.global_position, bug.ground_pos) > reach:
		_walk_to(target.global_position, delta)
	else:
		var dmg := bug.def.breach_dps * 1.4 * delta * Defs.WAVE_CONFIG.damage_scale(GameState.wave)
		if target is Player:
			(target as Player).net.server_damage(dmg)


func _walk_to(goal: Vector3, delta: float) -> void:
	var to := Vector3(goal.x - bug.ground_pos.x, 0.0, goal.z - bug.ground_pos.z)
	var step := hunt_speed() * delta
	if to.length() <= step:
		bug.ground_pos.x = goal.x
		bug.ground_pos.z = goal.z
	else:
		bug.ground_pos += to.normalized() * step
	# On its leash: never more than LEASH from home.
	var off := Vector3(bug.ground_pos.x - home.x, 0.0, bug.ground_pos.z - home.z)
	if off.length() > LEASH:
		off = off.normalized() * LEASH
		bug.ground_pos = Vector3(home.x + off.x, bug.ground_pos.y, home.z + off.z)
	if Bug.cliffs != null:
		bug.ground_pos.y = Bug.cliffs.floor_height(bug.ground_pos.x, bug.ground_pos.z)


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p: Node in bug.get_tree().get_nodes_in_group("players"):
		var pl := p as Node3D
		if not _huntable(pl):
			continue
		if _flat_dist(pl.global_position, home) > LEASH + 6.0:
			continue
		var d := _flat_dist(pl.global_position, bug.ground_pos)
		if d < best_d:
			best = pl
			best_d = d
	return best


static func _huntable(pl: Node3D) -> bool:
	if pl == null or not pl.is_inside_tree():
		return false
	if pl.has_method("is_downed") and bool(pl.call("is_downed")):
		return false
	if pl.global_position.y < Bug.UNDERGROUND_Y:
		return false # Story: inside Down the Hole's tunnel set, far under the floor
	return ExpeditionApi.is_down(pl.get_multiplayer_authority())


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
