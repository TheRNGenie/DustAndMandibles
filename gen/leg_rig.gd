class_name LegRig
extends Node3D
## Procedural legs. With IK on, each foot stays planted on the surface until the
## body moves too far, then steps (alternating groups) to a new spot found by a
## raycast onto the cliff; knees come from analytic 2-bone IK. With IK off (tiny
## bugs) legs just swing in a sine cycle, which is much cheaper.

const STEP_TIME := 0.14

static var _segment_meshes: Dictionary = {}

var spec: Dictionary
var _feet: Array[Vector3] = []
var _step_from: Array[Vector3] = []
var _step_to: Array[Vector3] = []
var _step_t: Array[float] = []
var _upper: Array[MeshInstance3D] = []
var _lower: Array[MeshInstance3D] = []
var _phase := 0.0
var _initialized := false


func setup(leg_spec: Dictionary) -> void:
	spec = leg_spec
	var mesh := _segment_mesh(spec["leg_color"])
	var mat := Materials.toon(0.015)
	for i in (spec["legs"] as Array).size():
		var u := MeshInstance3D.new()
		u.mesh = mesh
		u.material_override = mat
		add_child(u)
		_upper.append(u)
		if spec["ik"]:
			var l := MeshInstance3D.new()
			l.mesh = mesh
			l.material_override = mat
			add_child(l)
			_lower.append(l)
		_feet.append(Vector3.ZERO)
		_step_from.append(Vector3.ZERO)
		_step_to.append(Vector3.ZERO)
		_step_t.append(1.0)


## Unit cylinder (radius 1, height 1, along Y) per leg colour, shared by all bugs.
static func _segment_mesh(color: Color) -> ArrayMesh:
	var key := color.to_html()
	if not _segment_meshes.has(key):
		var st := MeshKit.begin()
		MeshKit.add_cylinder(st, Transform3D(), 1.0, 0.7, 1.0, 6, color)
		_segment_meshes[key] = MeshKit.finish(st)
	return _segment_meshes[key]


## body: the bug's current global transform. project: Callable(point, up) -> surface point.
func update(delta: float, body: Transform3D, speed: float, project: Callable) -> void:
	var legs: Array = spec["legs"]
	var up := body.basis.y.normalized()
	if not spec["ik"]:
		_phase += delta * (4.0 + speed * 6.0)
		for i in legs.size():
			var leg: Dictionary = legs[i]
			var hip := body * (leg["hip"] as Vector3)
			var lift := maxf(sin(_phase + float(i) * PI), 0.0) * float(spec["upper"]) * 0.6
			var swing := cos(_phase + float(i) * PI) * float(spec["upper"]) * 0.4
			var foot := body * ((leg["rest"] as Vector3) + Vector3(0, 0, swing)) + up * lift
			_place(_upper[i], hip, foot, float(spec["thick"]))
		return
	var stride := (float(spec["upper"]) + float(spec["lower"])) * 0.45
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
			_feet[i] = _step_from[i].lerp(_step_to[i], t) + up * sin(t * PI) * stride * 0.35
		elif _feet[i].distance_to(desired) > stride and not group_stepping[1 - _group(i)]:
			_step_from[i] = _feet[i]
			_step_to[i] = _refine(desired, up) + (desired - _feet[i]).normalized() * stride * 0.3
			_step_t[i] = 0.0
			group_stepping[_group(i)] = true
		elif _feet[i].distance_to(hip) > (float(spec["upper"]) + float(spec["lower"])) * 1.4:
			_feet[i] = desired # teleported or fell behind: snap
		var rest_local: Vector3 = leg["rest"]
		var hip_local: Vector3 = leg["hip"]
		var knee := _knee(hip, _feet[i], float(spec["upper"]), float(spec["lower"]), up, body.basis * (rest_local - hip_local))
		_place(_upper[i], hip, knee, float(spec["thick"]))
		_place(_lower[i], knee, _feet[i], float(spec["thick"]) * 0.8)


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
