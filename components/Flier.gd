class_name Flier
extends RefCounted
## Host-side brain for a Dragonfly Bandit: skips the cliff entirely, flies to a
## crop field or water source on its target cliff, steals from the stockpile,
## then flies off with the loot. Turrets can't aim up at it; players must shoot it.

const CRUISE_HEIGHT := 9.0
const STEAL := 3

var bug: Bug
var _target: Node3D
var _escaping := false
var _escape_point := Vector3.ZERO


func _init(b: Bug) -> void:
	bug = b


func update(delta: float) -> void:
	# Bee Smoker: drowsy fliers sink toward the ground (and fly on slowly).
	if bug.status.is_drowsy() and bug.boss == null:
		bug.ground_pos.y = maxf(bug.ground_pos.y - GunRules.DROWSY_SINK * delta, WorldLayout.CLIFF_HEIGHT + 1.2)
	if _escaping:
		_fly_to(_escape_point, delta)
		if bug.ground_pos.distance_to(_escape_point) < 2.0:
			bug.escaped()
		return
	if _target == null or not is_instance_valid(_target):
		_target = _pick_target()
		if _target == null:
			_start_escape()
			return
	var goal := _target.global_position + Vector3.UP * 1.5
	var horizontal := Vector2(goal.x - bug.ground_pos.x, goal.z - bug.ground_pos.z).length()
	if horizontal > 6.0:
		goal.y = maxf(goal.y, WorldLayout.CLIFF_HEIGHT + CRUISE_HEIGHT)
	# Down in the canyon: fly up the canyon into the play area, rising as it
	# goes, before heading over the lip (so it doesn't hit the walls).
	if bug.ground_pos.y < WorldLayout.CLIFF_HEIGHT + 2.0:
		var m := WorldLayout.map()
		if m.is_canyon():
			var into := clampf(bug.ground_pos.z, -WorldLayout.PLATEAU_WIDTH * 0.4, WorldLayout.PLATEAU_WIDTH * 0.4)
			var climb := WorldLayout.CLIFF_HEIGHT + CRUISE_HEIGHT if absf(bug.ground_pos.z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 6.0 else bug.ground_pos.y + 6.0
			goal = Vector3(0.0, climb, into)
		else:
			# Maps: rise over the gap in front of the target cliff first.
			goal = m.rise_point(bug.cliff_id, bug.ground_pos, WorldLayout.CLIFF_HEIGHT + CRUISE_HEIGHT)
	_fly_to(goal, delta)
	if bug.ground_pos.distance_to(_target.global_position + Vector3.UP * 1.5) < 1.5:
		_steal()


func _fly_to(goal: Vector3, delta: float) -> void:
	var to := goal - bug.ground_pos
	var step := bug.def.walk_speed * bug.speed() * delta
	bug.ground_pos += to.normalized() * minf(step, to.length())
	# A little bob so it reads as flying.
	bug.ground_pos.y += sin(Time.get_ticks_msec() * 0.006 + float(bug.name.hash() % 7)) * 0.02


func _steal() -> void:
	# Boss: the Swarm Lord's locusts are small and take a bite each (a bandit takes 3).
	var amount := maxi(1, roundi(bug.def.size * 2.7))
	if _target is WaterSource:
		(_target as WaterSource).steal(amount)
	Economy.steal(bug.cliff_id, &"water" if _target is WaterSource else &"corn", amount)
	Economy.notify_cliff(bug.cliff_id, "A %s is stealing from your %s!" % [bug.def.display_name, "water" if _target is WaterSource else "crops"])
	_start_escape()


func _start_escape() -> void:
	_escaping = true
	_escape_point = Vector3(0.0, WorldLayout.CLIFF_HEIGHT + 25.0, bug.ground_pos.z + randf_range(-30.0, 30.0))
	if not WorldLayout.map().is_canyon(): # Maps: off over the middle of the map
		var c := WorldLayout.map().center
		_escape_point = Vector3(c.x + randf_range(-25.0, 25.0), WorldLayout.CLIFF_HEIGHT + 25.0, c.z + randf_range(-25.0, 25.0))


func _pick_target() -> Node3D:
	var options: Array[Node3D] = []
	for g: String in ["crops", "water_sources"]:
		for n: Node in bug.get_tree().get_nodes_in_group(g):
			var node := n as Node3D
			if int(node.get("cliff_id")) == bug.cliff_id:
				options.append(node)
	if options.is_empty():
		return null
	return options[randi() % options.size()]
