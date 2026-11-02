class_name Shopkeeper
extends Node3D
## A crash-test-dummy shopkeeper behind a stall. Purely cosmetic and local: it
## breathes and glances about, turns to face the nearest player within reach,
## and waves when someone walks up. Between customers it keeps itself busy:
## stretching, folding its arms, wiping the counter, checking a pocket watch,
## scratching its head, looking around, shifting its weight.

const NOTICE_RANGE := 9.0
const WAVE_RANGE := 5.0

var rig: DummyRig
var _base_yaw := 0.0
var _yaw := 0.0
var _greeted := false
var _wave_t := 0.0
var _idle_wait := randf_range(1.5, 5.0)
var _drift := 0.0
var _drift_t := 0.0


func setup(look: Dictionary, team: Color, held: StringName = &"") -> void:
	rig = DummyRig.new()
	add_child(rig)
	rig.build(team, false, look)
	rig.relaxed = held == &""
	rig.set_weapon(held)
	_base_yaw = rotation.y


func _process(delta: float) -> void:
	if rig == null:
		return
	var near: Node3D = null
	var best := NOTICE_RANGE
	for p: Node in get_tree().get_nodes_in_group("players"):
		var d := (p as Node3D).global_position.distance_to(global_position)
		if d < best:
			best = d
			near = p as Node3D
	# Alone: turn this way and that now and then.
	_drift_t -= delta
	if _drift_t <= 0.0:
		_drift_t = randf_range(4.0, 9.0)
		_drift = randf_range(-0.6, 0.6) if randf() < 0.6 else 0.0
	var target := _base_yaw + (_drift if near == null else 0.0)
	if near != null:
		var to := near.global_position - global_position
		target = atan2(-to.x, -to.z) - (get_parent() as Node3D).global_rotation.y
	_yaw = lerp_angle(_yaw, target - _base_yaw, clampf(delta * 3.0, 0.0, 1.0))
	rotation.y = _base_yaw + _yaw
	# Wave once when someone first walks up, then again after they leave and return.
	if near != null and best < WAVE_RANGE and not _greeted:
		_greeted = true
		_wave_t = 1.6
	elif near == null:
		_greeted = false
	_wave_t = maxf(_wave_t - delta, 0.0)
	rig.wave = move_toward(rig.wave, 1.0 if _wave_t > 0.2 else 0.0, delta * 5.0)
	# Idle business: something every few seconds (less often with a customer there).
	if rig.action == &"" and _wave_t <= 0.0:
		_idle_wait -= delta * (0.4 if near != null and best < WAVE_RANGE else 1.0)
		if _idle_wait <= 0.0:
			_idle_wait = randf_range(3.0, 8.0)
			rig.play_action(DummyActions.IDLES[randi() % DummyActions.IDLES.size()])
	rig.animate(delta, 0.0, false, 0.0)
