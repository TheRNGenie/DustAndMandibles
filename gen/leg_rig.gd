class_name LegRig
extends Node
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
## Slots in the shared leg batches (see LegBatch): one draw per mesh for all bugs.
var _coxa: Array[int] = []
var _upper: Array[int] = []
var _lower: Array[int] = []
var _hip_ball: Array[int] = []
var _knee_ball: Array[int] = []
var _claw: Array[int] = []
var _seg_b: LegBatch
var _ball_b: LegBatch
var _claw_b: LegBatch
var _shown := true
## Far away: just thigh, shin and claw (no coxa or joint balls), half the work.
var _lite := false


func set_lite(on: bool) -> void:
	if on == _lite or _coxa.is_empty():
		return
	_lite = on
	if on:
		for i in _coxa.size():
			_seg_b.hide(_coxa[i])
			_ball_b.hide(_hip_ball[i])
			_ball_b.hide(_knee_ball[i])
var _phase := 0.0
var _initialized := false
## Boss: knee positions from the last pose (the Stilt Strider's leg hitboxes follow
## them), and legs that were shot off (not drawn).
var knees := PackedVector3Array()
var _broken: Dictionary = {}


func setup(leg_spec: Dictionary) -> void:
	spec = leg_spec
	var color: Color = spec["leg_color"]
	var seg := _segment_mesh(color)
	var ball := _ball_mesh(color.darkened(0.2))
	var claw := _claw_mesh(color.darkened(0.45))
	_seg_mesh = seg
	_ball_mesh_r = ball
	_claw_mesh_r = claw
	# Read the spec once: the per-tick update below runs for hundreds of bugs.
	_a = float(spec["upper"])
	_b = float(spec["lower"])
	_thick = float(spec["thick"])
	_ik = bool(spec["ik"])
	for leg: Dictionary in spec["legs"]:
		_hips.append(leg["hip"])
		_rests.append(leg["rest"])
	for i in (spec["legs"] as Array).size():
		knees.append(Vector3.ZERO)
		_feet.append(Vector3.ZERO)
		_step_from.append(Vector3.ZERO)
		_step_to.append(Vector3.ZERO)
		_step_t.append(1.0)


var _a := 0.0
var _b := 0.0
var _thick := 0.0
var _ik := false
var _hips := PackedVector3Array()
var _rests := PackedVector3Array()
var _seg_mesh: Mesh
var _ball_mesh_r: Mesh
var _claw_mesh_r: Mesh


func _enter_tree() -> void:
	if not _coxa.is_empty() or spec.is_empty():
		return
	var mat := Materials.toon(0.015)
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_seg_b = LegBatch.of(_seg_mesh, mat, root)
	_ball_b = LegBatch.of(_ball_mesh_r, mat, root)
	_claw_b = LegBatch.of(_claw_mesh_r, mat, root)
	for i in (spec["legs"] as Array).size():
		for arr: Array in [_coxa, _upper, _lower]:
			arr.append(_seg_b.take())
		for arr: Array in [_hip_ball, _knee_ball]:
			arr.append(_ball_b.take())
		_claw.append(_claw_b.take())


func _exit_tree() -> void:
	for arr: Array in [_coxa, _upper, _lower]:
		for s: int in arr:
			_seg_b.give_back(s)
	for arr: Array in [_hip_ball, _knee_ball]:
		for s: int in arr:
			_ball_b.give_back(s)
	for s: int in _claw:
		_claw_b.give_back(s)
	for arr: Array in [_coxa, _upper, _lower, _hip_ball, _knee_ball, _claw]:
		arr.clear()


## Shows or hides every leg (a plain Node: the bug calls this, e.g. when it burrows).
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if is_inside_tree() and not _coxa.is_empty():
		if not _shown:
			for arr: Array in [_coxa, _upper, _lower]:
				for s: int in arr:
					_seg_b.hide(s)
			for arr: Array in [_hip_ball, _knee_ball]:
				for s: int in arr:
					_ball_b.hide(s)
			for s: int in _claw:
				_claw_b.hide(s)


## Boss: leg i's hip, knee and foot in world space (from the last update).
func leg_points(i: int, body: Transform3D) -> Array[Vector3]:
	return [body * _hips[i], knees[i], _feet[i]]


func leg_count() -> int:
	return _hips.size()


## Boss: leg i was shot off: it stops being drawn.
func break_leg(i: int) -> void:
	if _broken.has(i) or i < 0 or i >= _hips.size():
		return
	_broken[i] = true
	if not _coxa.is_empty():
		for arr: Array in [_coxa, _upper, _lower]:
			_seg_b.hide(arr[i])
		_ball_b.hide(_hip_ball[i])
		_ball_b.hide(_knee_ball[i])
		_claw_b.hide(_claw[i])


func is_broken(i: int) -> bool:
	return _broken.has(i)


## Unit tapered cylinder (radius 1 at the base, along Y), per leg colour.
static func _segment_mesh(color: Color) -> ArrayMesh:
	var key := color.to_html()
	if not _segment_meshes.has(key):
		# Tapered, with a darker band at each end and a lighter stripe in the middle,
		# so legs read as jointed armour rather than pipes.
		var st := MeshKit.begin()
		MeshKit.add_cylinder(st, Transform3D(), 1.0, 0.78, 1.0, 10, color)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.44, 0)), 1.06, 1.04, 0.1, 10, color.darkened(0.35))
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.44, 0)), 0.84, 0.82, 0.1, 10, color.darkened(0.35))
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.93, 0.91, 0.12, 10, color.lightened(0.18))
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


## body: the bug's current global transform. project: Callable(point, up) -> surface
## point, or an invalid Callable when the bug is on its cliff face (then a foot
## target is just dropped onto the plane under the body, without a call).
func update(delta: float, body: Transform3D, speed: float, project: Callable) -> void:
	var n := _hips.size()
	if n == 0 or _coxa.is_empty() or not _shown:
		return
	var up := body.basis.y.normalized()
	var a := _a
	var b := _b
	var thick := _thick
	if not _ik:
		# Small bugs: feet trace a walking loop (lift, sweep forward, plant, push back).
		_phase += delta * (5.0 + speed * 7.0)
		var fwd := -body.basis.z.normalized()
		var sweep_k := a * 0.45 * clampf(speed + 0.3, 0.3, 1.0)
		for i in n:
			var p := _phase + float((i + (i / 2)) % 2) * PI
			_feet[i] = body * _rests[i] + fwd * (cos(p) * sweep_k) + up * (maxf(sin(p), 0.0) * a * 0.5)
			_pose(i, body, a, b, thick, up)
		return
	var stride := (a + b) * 0.45
	var flat := not project.is_valid()
	# On the face, feet land on the plane under the body.
	var base := body.origin - up * _clearance
	if not _initialized:
		for i in n:
			var r := body * _rests[i]
			_feet[i] = r - up * (r - base).dot(up) if flat else project.call(r, up)
		_initialized = true
	var stepping0 := false
	var stepping1 := false
	for i in n:
		if _step_t[i] < 1.0:
			if (i + (i / 2)) % 2 == 0:
				stepping0 = true
			else:
				stepping1 = true
	for i in n:
		var g := (i + (i / 2)) % 2
		var r := body * _rests[i]
		var desired: Vector3 = r - up * (r - base).dot(up) if flat else project.call(r, up)
		if _step_t[i] < 1.0:
			_step_t[i] = minf(_step_t[i] + delta / STEP_TIME, 1.0)
			var t := _step_t[i]
			var e := t * t * (3.0 - 2.0 * t) # ease in and out
			_feet[i] = _step_from[i].lerp(_step_to[i], e) + up * sin(t * PI) * stride * 0.4
		elif _feet[i].distance_to(desired) > stride and not (stepping0 if g == 1 else stepping1):
			_step_from[i] = _feet[i]
			_step_to[i] = _refine(desired, up) + (desired - _feet[i]).normalized() * stride * 0.3
			_step_t[i] = 0.0
			if g == 0:
				stepping0 = true
			else:
				stepping1 = true
		elif _feet[i].distance_to(body * _hips[i]) > (a + b) * 1.4:
			_feet[i] = desired # teleported or fell behind: snap
		_pose(i, body, a, b, thick, up)


## How far the body rides above the surface (for flat foot placement).
var _clearance := 0.0


func set_clearance(c: float) -> void:
	_clearance = c


## Places every piece of leg i so it's one continuous limb from body to claw.
func _pose(i: int, body: Transform3D, a: float, b: float, thick: float, up: Vector3) -> void:
	if not _broken.is_empty() and _broken.has(i):
		return
	var hip_local := _hips[i]
	var hip := body * hip_local
	var foot := _feet[i]
	# Keep the foot within reach so the leg never comes apart.
	var to := foot - hip
	var reach := (a + b) * 0.98
	if to.length_squared() > reach * reach:
		foot = hip + to.normalized() * reach
	var knee := _knee(hip, foot, a, b, up, body.basis * (_rests[i] - hip_local))
	knees[i] = knee
	_place(_seg_b, _upper[i], hip, knee, thick)
	_place(_seg_b, _lower[i], knee, foot, thick * 0.8)
	if not _lite:
		# The coxa starts inside the body (toward the centre line), so the leg is attached.
		var inner := body * Vector3(hip_local.x * 0.35, hip_local.y + thick * 0.5, hip_local.z)
		_place(_seg_b, _coxa[i], inner, hip, thick * 1.3)
		_ball_b.put(_hip_ball[i], Transform3D(Basis.from_scale(Vector3.ONE * (thick * 1.45)), hip))
		_ball_b.put(_knee_ball[i], Transform3D(Basis.from_scale(Vector3.ONE * (thick * 1.15)), knee))
	var dir := (foot - knee).normalized()
	_claw_b.put(_claw[i], Transform3D(_basis_y(-dir, Vector3(thick * 0.8, thick * 2.2, thick * 0.8)), foot + dir * thick * 1.1))


## MeshKit.basis_from_y(y) scaled by s, inline (y must be unit length).
static func _basis_y(y: Vector3, s: Vector3) -> Basis:
	var ref := Vector3.FORWARD if absf(y.y) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x * s.x, y * s.y, z * s.z)


static func _group(i: int) -> int:
	# Alternate tripods: left/right of each pair in opposite groups, alternating per pair.
	return (i + (i / 2)) % 2


## Snaps a foot target onto real geometry with a short raycast along -up.
func _refine(p: Vector3, up: Vector3) -> Vector3:
	var space := (get_parent() as Node3D).get_world_3d().direct_space_state
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
static func _place(batch: LegBatch, slot: int, a: Vector3, b: Vector3, radius: float) -> void:
	var v := b - a
	var length := v.length()
	if length < 0.001:
		return
	batch.put(slot, Transform3D(_basis_y(v / length, Vector3(radius, length, radius)), (a + b) * 0.5))


static func _ball(batch: LegBatch, slot: int, at: Vector3, radius: float) -> void:
	batch.put(slot, Transform3D(Basis.from_scale(Vector3.ONE * radius), at))
