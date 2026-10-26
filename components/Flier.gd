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
	if _target is WaterSource:
		(_target as WaterSource).steal(STEAL)
	Economy.steal(bug.cliff_id, &"water" if _target is WaterSource else &"food", STEAL)
	Economy.notify_cliff(bug.cliff_id, "A Dragonfly Bandit is stealing from your %s!" % ("water" if _target is WaterSource else "crops"))
	_start_escape()


func _start_escape() -> void:
	_escaping = true
	_escape_point = Vector3(0.0, WorldLayout.CLIFF_HEIGHT + 25.0, bug.ground_pos.z + randf_range(-30.0, 30.0))


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
