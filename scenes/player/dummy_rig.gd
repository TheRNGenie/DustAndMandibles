class_name DummyRig
extends Node3D
## The player's body: a cowpoke in a wide-brimmed hat, team-colour bandana pulled
## up over the face, a long duster coat with swinging tails over a leather vest,
## gun belt with a holster, jeans, and boots with spurs. Built from rounded
## primitives and animated procedurally: legs walk with your speed, the gun arm
## follows your aim, coat tails sway, the body crouches when sliding.
## In first person you see your own legs and boots; the upper body only casts a
## shadow (the viewmodel shows your hands on the gun).

const SKIN := Color("#D9A27A")
const HAT := Color("#6B4A2E")
const HAT_DARK := Color("#4E3420")
const SHIRT := Color("#D8C8A2")
const VEST := Color("#4A2E20")
const COAT := Color("#8A6C4A")
const COAT_DARK := Color("#6E5438")
const JEANS := Color("#4A5C7E")
const JEANS_DARK := Color("#3A4A68")
const BOOT := Color("#4A2C1C")
const BELT := Color("#3A2416")
const BRASS := Color("#D6A74A")
const GLOVE := Color("#8A5A34")
const EYE := Color("#1E1612")
const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.28

static var _meshes: Dictionary = {}

var first_person := false
var _mat: ShaderMaterial
var _team: Color
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _tails: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hand: Node3D
var _gun_mi: MeshInstance3D
var _weapon: StringName = &"-"
var _phase := 0.0
var _slide := 0.0
var _tail_swing := 0.0


func build(team: Color, is_first_person: bool) -> void:
	first_person = is_first_person
	_team = team
	_mat = Materials.toon_unique(0.02)
	_hips = _pivot(self, Vector3(0, 0.95, 0))
	var pelvis := _part(_hips, _mesh("pelvis", team))
	_tails = _pivot(_hips, Vector3(0, 0.02, 0.06))
	var tails := _part(_tails, _mesh("tails", team))
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	var torso := _part(_torso, _mesh("torso", team))
	_head = _pivot(_torso, Vector3(0, 0.6, 0))
	var head_mi := _part(_head, _mesh("head", team))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var thigh := _pivot(_hips, Vector3(side * 0.11, -0.05, 0))
		_part(thigh, _mesh("thigh", team))
		var shin := _pivot(thigh, Vector3(0, -THIGH, 0))
		_part(shin, _mesh("shin", team))
		_thighs.append(thigh)
		_shins.append(shin)
		var shoulder := _pivot(_torso, Vector3(side * 0.25, 0.46, 0))
		var upper := _part(shoulder, _mesh("upper_arm", team))
		var elbow := _pivot(shoulder, Vector3(0, -UPPER_ARM, 0))
		var fore := _part(elbow, _mesh("forearm", team))
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		if first_person:
			upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			fore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The right hand holds whatever gun you have out (third person only).
	_hand = _pivot(_elbows[1], Vector3(0, -FOREARM - 0.05, 0))
	_gun_mi = MeshInstance3D.new()
	_gun_mi.material_override = Materials.toon(0.008)
	# Gun barrel (-Z) along the forearm (-Y), sights toward the back of the hand.
	_gun_mi.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.0, -0.01))
	_hand.add_child(_gun_mi)
	if first_person:
		_gun_mi.visible = false
		for mi: MeshInstance3D in [head_mi, torso, pelvis, tails]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		position.z = 0.06
	set_weapon(&"revolver")


## Shows gun `id` in the right hand ("" = empty hand).
func set_weapon(id: StringName) -> void:
	if id == _weapon:
		return
	_weapon = id
	_gun_mi.mesh = WeaponBuilder.gun(id) if id != &"" else null


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
	# Right arm (index 1) aims the gun; the left arm swings.
	_shoulders[1].rotation.x = -1.35 - pitch * 0.9
	_elbows[1].rotation.x = -0.15
	_shoulders[0].rotation.x = lerpf(-sin(_phase) * 0.45 * k, -0.6, _slide)
	_elbows[0].rotation.x = -0.35
	_hips.position.y = lerpf(0.95 + absf(sin(_phase)) * 0.03 * k, 0.48, _slide)
	_torso.rotation.x = lerpf(-0.06 * k, 0.45, _slide)
	_head.rotation.x = clampf(pitch, -0.7, 0.7) - _torso.rotation.x
	# Coat tails flare out behind you as you run and flap with your stride.
	var want := 0.25 * k + sin(_phase * 2.0) * 0.06 * k
	_tail_swing = lerpf(_tail_swing, want, clampf(delta * 6.0, 0.0, 1.0))
	_tails.rotation.x = lerpf(_tail_swing, 0.9, _slide)


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


func _part(parent: Node3D, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	parent.add_child(mi)
	return mi


## A tapered limb from a to b, rounded at both ends.
static func _taper(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs: int = 12) -> void:
	WeaponBuilder.rod(st, a, b, r0, r1, segs, col)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), a), Vector3.ONE * r0, 5, segs, col)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), b), Vector3.ONE * r1, 5, segs, col)


## Builds (and caches per team colour) each body part. Front is -Z; parts hang
## down from their pivot.
static func _mesh(part: String, team: Color) -> ArrayMesh:
	var key := part + team.to_html()
	if _meshes.has(key):
		return _meshes[key]
	var st := MeshKit.begin()
	match part:
		"pelvis":
			# Jeans seat, gun belt with a buckle, holster on the right hip.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.02, 0)), Vector3(0.19, 0.12, 0.13), 6, 14, JEANS)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 0.06), Vector3(0, 0.03, 0)), 0.19, 0.2, 0.06, 16, BELT)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, -0.195)), Vector3(0.07, 0.05, 0.015), BRASS)
			for i in 6:
				var a := PI * 0.15 + i * 0.22
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.2)), Vector3(0.012, 0.018, 0.012), 3, 6, BRASS)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.2, -0.1, -0.02)), Vector3(0.05, 0.17, 0.08), BELT)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.205, 0.01, -0.03)), Vector3(0.03, 0.06, 0.05), WeaponBuilder.WALNUT)
		"tails":
			# Two duster tails hanging from the waist to the knees, split at the back.
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, side * 0.35).rotated(Vector3.RIGHT, 0.12), Vector3(side * 0.12, -0.3, 0.05)),
						Vector3(0.22, 0.6, 0.025), COAT)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, side * 0.35).rotated(Vector3.RIGHT, 0.12), Vector3(side * 0.12, -0.59, 0.085)),
						Vector3(0.225, 0.04, 0.03), COAT_DARK)
		"torso":
			# Shirt, leather vest, open duster coat with lapels, bandana knot.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.2, 0.3, 0.13), 7, 16, SHIRT)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.22, 0.004)), Vector3(0.203, 0.25, 0.132), 7, 16, VEST)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.3, -0.128)), Vector3(0.05, 0.36, 0.01), SHIRT)
			for i in 3:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.034, 0.16 + i * 0.08, -0.131)), Vector3.ONE * 0.008, 3, 6, BRASS)
			# Coat: shoulders and back, open at the front.
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, side * 0.2), Vector3(side * 0.15, 0.24, 0.02)), Vector3(0.12, 0.5, 0.25), COAT)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, side * 0.35).rotated(Vector3.UP, side * 0.25), Vector3(side * 0.12, 0.42, -0.11)), Vector3(0.06, 0.2, 0.02), COAT_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.24, 0.11)), Vector3(0.38, 0.5, 0.04), COAT)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.46, 0.02)), Vector3(0.27, 0.07, 0.15), 5, 14, COAT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.53, 0.02)), 0.085, 0.075, 0.05, 12, COAT_DARK)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.555, 0)), 0.055, 0.05, 0.08, 10, SKIN)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.49, -0.1)), Vector3(0.09, 0.07, 0.03), 4, 8, team)
		"head":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(0.105, 0.125, 0.115), 7, 14, SKIN)
			for side: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.105, 0.07, 0.01)), Vector3(0.015, 0.03, 0.02), 3, 6, SKIN.darkened(0.08))
				# Eyes in the shade of the brim, and heavy brows.
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.04, 0.1, -0.1)), Vector3(0.016, 0.012, 0.008), 3, 6, EYE)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, side * 0.2), Vector3(side * 0.042, 0.123, -0.103)), Vector3(0.042, 0.012, 0.012), HAT_DARK)
			# Bandana pulled up over nose and mouth, a point hanging at the chin.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.025, -0.01)), Vector3(0.112, 0.07, 0.118), 6, 14, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.045, -0.085)), 0.055, 0.0, 0.07, 4, team.darkened(0.1))
			# Hat: pinched crown, band, wide brim curled up at the sides.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.255, 0)), 0.115, 0.1, 0.13, 14, HAT)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.322, 0.005)), Vector3(0.05, 0.03, 0.17), HAT_DARK)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.205, 0)), 0.118, 0.118, 0.03, 14, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.188, 0)), 0.27, 0.25, 0.018, 18, HAT)
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, side * 0.55), Vector3(side * 0.235, 0.215, 0)), Vector3(0.08, 0.016, 0.3), HAT)
		"thigh":
			_taper(st, Vector3.ZERO, Vector3(0, -THIGH + 0.03, 0), 0.085, 0.07, JEANS)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.06, -0.075)), Vector3(0.08, 0.06, 0.01), JEANS_DARK)
		"shin":
			_taper(st, Vector3.ZERO, Vector3(0, -SHIN * 0.45, 0), 0.068, 0.065, JEANS)
			# Tall boot, heel, pointed toe, spur.
			_taper(st, Vector3(0, -SHIN * 0.42, 0), Vector3(0, -SHIN + 0.02, 0), 0.07, 0.065, BOOT)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.01, -0.09)), Vector3(0.06, 0.045, 0.13), 5, 10, BOOT)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.03, 0.035)), Vector3(0.07, 0.06, 0.06), BELT)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, -SHIN, 0.075)), 0.022, 0.022, 0.006, 8, Palette.METAL)
			MeshKit.add_limb(st, Vector3(-0.06, -SHIN + 0.005, 0.03), Vector3(0, -SHIN, 0.07), 0.006, Palette.METAL, 5)
			MeshKit.add_limb(st, Vector3(0.06, -SHIN + 0.005, 0.03), Vector3(0, -SHIN, 0.07), 0.006, Palette.METAL, 5)
		"upper_arm":
			_taper(st, Vector3.ZERO, Vector3(0, -UPPER_ARM + 0.02, 0), 0.075, 0.065, COAT)
		"forearm":
			_taper(st, Vector3.ZERO, Vector3(0, -FOREARM + 0.04, 0), 0.062, 0.058, COAT)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -FOREARM + 0.03, 0)), 0.066, 0.066, 0.04, 12, COAT_DARK)
			# Leather glove and gauntlet.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.0, 0)), 0.05, 0.042, 0.05, 10, GLOVE.darkened(0.15))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.06, -0.005)), Vector3(0.045, 0.055, 0.04), 5, 10, GLOVE)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.035, -FOREARM - 0.04, -0.03)), Vector3(0.016, 0.03, 0.016), 3, 6, GLOVE)
	var mesh := MeshKit.finish(st)
	_meshes[key] = mesh
	return mesh
