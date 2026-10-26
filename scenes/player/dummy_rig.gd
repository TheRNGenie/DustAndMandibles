class_name DummyRig
extends Node3D
## Placeholder player body: a crash test dummy in a cowboy hat (team-colour hat band
## and bandana), built from primitives and animated procedurally: legs walk with
## your speed, the gun arm follows your aim, the body crouches when sliding.
## In first person you see your own legs and feet; the head and arms only cast
## shadows (the viewmodel shows your hand on the revolver).

const DUMMY := Color("#E8C547")
const JOINT := Color("#3A3A40")
const MARK_DARK := Color("#1E1E22")
const HAT := Color("#7A5232")
const THIGH := 0.42
const SHIN := 0.42
const UPPER_ARM := 0.3
const FOREARM := 0.28

static var _meshes: Dictionary = {}

var first_person := false
var _mat: ShaderMaterial
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase := 0.0
var _slide := 0.0


func build(team: Color, is_first_person: bool) -> void:
	first_person = is_first_person
	_mat = Materials.toon_unique(0.02)
	_hips = _pivot(self, Vector3(0, 0.92, 0))
	_part(_hips, _mesh("pelvis", team), Vector3.ZERO)
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	_part(_torso, _mesh("torso", team), Vector3.ZERO)
	_head = _pivot(_torso, Vector3(0, 0.58, 0))
	var head_mi := _part(_head, _mesh("head", team), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var thigh := _pivot(_hips, Vector3(side * 0.12, -0.04, 0))
		_part(thigh, _mesh("thigh", team), Vector3.ZERO)
		var shin := _pivot(thigh, Vector3(0, -THIGH, 0))
		_part(shin, _mesh("shin", team), Vector3.ZERO)
		_thighs.append(thigh)
		_shins.append(shin)
		var shoulder := _pivot(_torso, Vector3(side * 0.24, 0.44, 0))
		var upper := _part(shoulder, _mesh("upper_arm", team), Vector3.ZERO)
		var elbow := _pivot(shoulder, Vector3(0, -UPPER_ARM, 0))
		var fore := _part(elbow, _mesh("forearm", team), Vector3.ZERO)
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		if first_person:
			upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			fore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if first_person:
		head_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		# Keep the torso out of the camera when you look down.
		position.z = 0.18


## Called every frame. speed = horizontal speed (m/s); pitch = aim pitch (radians).
func animate(delta: float, speed: float, sliding: bool, pitch: float) -> void:
	_slide = move_toward(_slide, 1.0 if sliding else 0.0, delta * 6.0)
	var k := clampf(speed / 6.0, 0.0, 1.6)
	if speed > 0.3:
		_phase += delta * (4.0 + speed * 0.9)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(delta * 6.0, 0.0, 1.0))
	for i in 2:
		var s := sin(_phase + float(i) * PI)
		var walk_thigh := s * 0.55 * k
		var walk_shin := maxf(-cos(_phase + float(i) * PI), 0.0) * 0.9 * k
		_thighs[i].rotation.x = lerpf(walk_thigh, -1.35, _slide)
		_shins[i].rotation.x = lerpf(walk_shin, 0.1, _slide)
	# Right arm (index 1) aims the revolver; the left arm swings.
	_shoulders[1].rotation.x = -1.35 - pitch * 0.9
	_elbows[1].rotation.x = -0.15
	_shoulders[0].rotation.x = lerpf(-sin(_phase) * 0.45 * k, -0.6, _slide)
	_elbows[0].rotation.x = -0.35
	_hips.position.y = lerpf(0.92 + absf(sin(_phase)) * 0.03 * k, 0.45, _slide)
	_torso.rotation.x = lerpf(-0.06 * k, 0.45, _slide)
	_head.rotation.x = clampf(pitch, -0.7, 0.7) - _torso.rotation.x


## A quick bright flash (firing).
func flash() -> void:
	_mat.set_shader_parameter("flash_color", Palette.GLOW_YELLOW)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("flash_amount", v), 0.6, 0.0, 0.15)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: ArrayMesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Builds (and caches per team colour) each body part. Parts hang down from their pivot.
static func _mesh(part: String, team: Color) -> ArrayMesh:
	var key := part + team.to_html()
	if _meshes.has(key):
		return _meshes[key]
	var st := MeshKit.begin()
	match part:
		"pelvis":
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.34, 0.16, 0.2), DUMMY)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.17, 0.17, 0.05, 10, MARK_DARK)
		"torso":
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(0.36, 0.42, 0.22), DUMMY)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.3, 0.06, 0.2), JOINT)
			_marker(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.26, -0.115)), 0.075)
			# Team bandana around the neck.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.47, 0)), 0.1, 0.09, 0.08, 10, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.5, 0)), 0.05, 0.05, 0.08, 8, JOINT)
		"head":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.12, 0.14, 0.13), 6, 12, DUMMY)
			for side: float in [-1.0, 1.0]:
				_marker(st, Transform3D(Basis(Vector3.BACK, side * PI * 0.5), Vector3(side * 0.121, 0.03, 0)), 0.05)
			# Cowboy hat: wide brim, crown, team-colour band.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.3, 0.28, 0.025, 16, HAT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.22, 0)), 0.14, 0.12, 0.18, 12, HAT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.155, 0)), 0.142, 0.142, 0.04, 12, team)
		"thigh":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.08, 4, 8, JOINT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -THIGH * 0.5, 0)), 0.085, 0.075, THIGH - 0.06, 8, DUMMY)
		"shin":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.072, 4, 8, JOINT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -SHIN * 0.5, 0)), 0.07, 0.06, SHIN - 0.06, 8, DUMMY)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.02, -0.06)), Vector3(0.11, 0.08, 0.26), JOINT)
		"upper_arm":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.065, 4, 8, JOINT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -UPPER_ARM * 0.5, 0)), 0.06, 0.055, UPPER_ARM - 0.05, 8, DUMMY)
		"forearm":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.055, 4, 8, JOINT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -FOREARM * 0.5, 0)), 0.052, 0.045, FOREARM - 0.04, 8, DUMMY)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.04, 0)), Vector3(0.08, 0.1, 0.05), DUMMY.darkened(0.1))
	var mesh := MeshKit.finish(st)
	_meshes[key] = mesh
	return mesh


## The classic crash-test marker: a disc quartered in yellow and black, facing +Y of xf.
static func _marker(st: SurfaceTool, xf: Transform3D, r: float) -> void:
	var n := (xf.basis * Vector3.UP).normalized()
	var c := xf.origin
	var segs := 16
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var col := MeshKit.vcol(MARK_DARK if (i * 4 / segs) % 2 == 0 else Palette.GLOW_YELLOW)
		var p0 := xf * (Vector3(cos(a0), 0.0, sin(a0)) * r)
		var p1 := xf * (Vector3(cos(a1), 0.0, sin(a1)) * r)
		MeshKit.tri(st, c, p0, p1, n, n, n, col, n)
