class_name LegRig
extends Node3D
## Procedural bug legs, every one in one piece: a short coxa from inside the body
## to the hip ball, a thigh, a knee ball, a shin and a pointed claw. Knees come
## from analytic 2-bone IK. With IK on, each foot stays planted on the surface
## until the body moves too far, then steps in alternating groups with an eased
## arc to a spot found by a raycast. With IK off (small bugs) the feet trace a
## smooth walking loop instead (no raycasts), still through the same IK knees.

const STEP_TIME := 0.2

static var _segment_meshes: Dictionary = {}
static var _ball_meshes: Dictionary = {}
static var _claw_meshes: Dictionary = {}

var spec: Dictionary
var _feet: Array[Vector3] = []
var _step_from: Array[Vector3] = []
var _step_to: Array[Vector3] = []
var _step_t: Array[float] = []
var _coxa: Array[MeshInstance3D] = []
var _upper: Array[MeshInstance3D] = []
var _lower: Array[MeshInstance3D] = []
var _hip_ball: Array[MeshInstance3D] = []
var _knee_ball: Array[MeshInstance3D] = []
var _claw: Array[MeshInstance3D] = []
var _phase := 0.0
var _initialized := false


func setup(leg_spec: Dictionary) -> void:
	spec = leg_spec
	var color: Color = spec["leg_color"]
	var seg := _segment_mesh(color)
	var ball := _ball_mesh(color.darkened(0.2))
	var claw := _claw_mesh(color.darkened(0.45))
	var mat := Materials.toon(0.015)
	for i in (spec["legs"] as Array).size():
		for arr: Array in [_coxa, _upper, _lower]:
			arr.append(_mi(seg, mat))
		for arr: Array in [_hip_ball, _knee_ball]:
			arr.append(_mi(ball, mat))
		_claw.append(_mi(claw, mat))
		_feet.append(Vector3.ZERO)
		_step_from.append(Vector3.ZERO)
		_step_to.append(Vector3.ZERO)
		_step_t.append(1.0)


func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


## Unit tapered cylinder (radius 1 at the base, along Y), per leg colour.
static func _segment_mesh(color: Color) -> ArrayMesh:
	var key := color.to_html()
	if not _segment_meshes.has(key):
		var st := MeshKit.begin()
		MeshKit.add_cylinder(st, Transform3D(), 1.0, 0.8, 1.0, 8, color)
		_segment_meshes[key] = MeshKit.finish(st)
	return _segment_meshes[key]


static func _ball_mesh(color: Color) -> ArrayMesh:
	var key := color.to_html()
	if not _ball_meshes.has(key):
		var st := MeshKit.begin()
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 4, 8, color)
		_ball_meshes[key] = MeshKit.finish(st)
	return _ball_meshes[key]


## A pointed claw along -Y (unit length).
static func _claw_mesh(color: Color) -> ArrayMesh:
	var key := color.to_html()
	if not _claw_meshes.has(key):
		var st := MeshKit.begin()
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.5, 0)), 0.0, 1.0, 1.0, 6, color)
		_claw_meshes[key] = MeshKit.finish(st)
	return _claw_meshes[key]


## body: the bug's current global transform. project: Callable(point, up) -> surface point.
func update(delta: float, body: Transform3D, speed: float, project: Callable) -> void:
	var legs: Array = spec["legs"]
	if legs.is_empty():
		return
	var up := body.basis.y.normalized()
	var a := float(spec["upper"])
	var b := float(spec["lower"])
	var thick := float(spec["thick"])
	if not spec["ik"]:
		# Small bugs: feet trace a walking loop (lift, sweep forward, plant, push back).
		_phase += delta * (5.0 + speed * 7.0)
		var fwd := -body.basis.z.normalized()
		for i in legs.size():
			var leg: Dictionary = legs[i]
			var p := _phase + float(_group(i)) * PI
			var lift := maxf(sin(p), 0.0) * a * 0.5
			var sweep := cos(p) * a * 0.45 * clampf(speed + 0.3, 0.3, 1.0)
			_feet[i] = body * (leg["rest"] as Vector3) + fwd * sweep + up * lift
			_pose(i, body, leg, a, b, thick, up)
		return
	var stride := (a + b) * 0.45
	if not _initialized:
		for i in legs.size():
			_feet[i] = project.call(body * ((legs[i] as Dictionary)["rest"] as Vector3), up)
		_initialized = true
	var group_stepping := [false, false]
	for i in legs.size():
		if _step_t[i] < 1.0:
			group_stepping[_group(i)] = true
	for i in legs.size():
		var leg: Dictionary = legs[i]
		var hip := body * (leg["hip"] as Vector3)
		var desired: Vector3 = project.call(body * (leg["rest"] as Vector3), up)
		if _step_t[i] < 1.0:
			_step_t[i] = minf(_step_t[i] + delta / STEP_TIME, 1.0)
			var t := _step_t[i]
			var e := t * t * (3.0 - 2.0 * t) # ease in and out
			_feet[i] = _step_from[i].lerp(_step_to[i], e) + up * sin(t * PI) * stride * 0.4
		elif _feet[i].distance_to(desired) > stride and not group_stepping[1 - _group(i)]:
			_step_from[i] = _feet[i]
			_step_to[i] = _refine(desired, up) + (desired - _feet[i]).normalized() * stride * 0.3
			_step_t[i] = 0.0
			group_stepping[_group(i)] = true
		elif _feet[i].distance_to(hip) > (a + b) * 1.4:
			_feet[i] = desired # teleported or fell behind: snap
		_pose(i, body, leg, a, b, thick, up)


## Places every piece of leg i so it's one continuous limb from body to claw.
func _pose(i: int, body: Transform3D, leg: Dictionary, a: float, b: float, thick: float, up: Vector3) -> void:
	var hip_local: Vector3 = leg["hip"]
	var hip := body * hip_local
	# The coxa starts inside the body (toward the centre line), so the leg is attached.
	var inner := body * Vector3(hip_local.x * 0.35, hip_local.y + thick * 0.5, hip_local.z)
	var rest_local: Vector3 = leg["rest"]
	var foot := _feet[i]
	# Keep the foot within reach so the leg never comes apart.
	var to := foot - hip
	if to.length() > (a + b) * 0.98:
		foot = hip + to.normalized() * (a + b) * 0.98
	var knee := _knee(hip, foot, a, b, up, body.basis * (rest_local - hip_local))
	_place(_coxa[i], inner, hip, thick * 1.3)
	_place(_upper[i], hip, knee, thick)
	_place(_lower[i], knee, foot, thick * 0.8)
	_ball(_hip_ball[i], hip, thick * 1.45)
	_ball(_knee_ball[i], knee, thick * 1.15)
	var dir := (foot - knee).normalized()
	_claw[i].global_transform = Transform3D(MeshKit.basis_from_y(-dir) * Basis.from_scale(Vector3(thick * 0.8, thick * 2.2, thick * 0.8)), foot + dir * thick * 1.1)


static func _group(i: int) -> int:
	# Alternate tripods: left/right of each pair in opposite groups, alternating per pair.
	return (i + (i / 2)) % 2


## Snaps a foot target onto real geometry with a short raycast along -up.
func _refine(p: Vector3, up: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + up * 0.8, p - up * 1.2, WorldLayout.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## Analytic 2-bone IK: the knee bends away from the surface and outward.
static func _knee(hip: Vector3, foot: Vector3, a: float, b: float, up: Vector3, outward: Vector3) -> Vector3:
	var to := foot - hip
	var d := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to.normalized() if to.length() > 0.0001 else -up
	var bend := (up * 1.5 + outward.normalized()).normalized()
	bend = (bend - dir * bend.dot(dir)).normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	return hip + dir * x + bend * h


## Stretches a unit segment mesh from a to b.
static func _place(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var v := b - a
	var length := v.length()
	if length < 0.001:
		return
	var basis := MeshKit.basis_from_y(v / length) * Basis.from_scale(Vector3(radius, length, radius))
	mi.global_transform = Transform3D(basis, (a + b) * 0.5)


static func _ball(mi: MeshInstance3D, at: Vector3, radius: float) -> void:
	mi.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * radius), at)
