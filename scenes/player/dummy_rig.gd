class_name DummyRig
extends Node3D
## The player's body: a crash-test dummy dressed for the frontier. Bright test-lab
## paint, black rubber joints, quartered target markers on the head, chest and
## thighs, a ribbed neck and mitten hands, topped with a cowboy hat. The rest is
## up to you (DummyLook): hair poking out from the hat, a moustache, an outfit,
## something round the neck, boots and spurs. Built from rounded primitives and
## animated procedurally: legs walk with your speed, the gun arm follows your aim,
## coat tails flap, the body crouches when sliding, and it can be knocked about.
## In first person you see your own legs; the upper body only casts a shadow.

const JOINT := Color("#26262C")
const MARK_DARK := Color("#1E1E22")
const MARK_LIGHT := Color("#F2C230")
const HAT := Color("#6B4A2E")
const HAT_DARK := Color("#4E3420")
const VEST := Color("#4A2E20")
const COAT := Color("#8A6C4A")
const COAT_DARK := Color("#6E5438")
const SHIRT := Color("#D8C8A2")
const BOOT := Color("#4A2C1C")
const BELT := Color("#3A2416")
const BRASS := Color("#D6A74A")
const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.28

static var _meshes: Dictionary = {}

var first_person := false
var look: Dictionary = DummyLook.default_look()
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
## Ragdoll-ish wobble from being hit (rocks): a tilt that springs back.
var _wobble := Vector3.ZERO
var _wobble_vel := Vector3.ZERO


func build(team: Color, is_first_person: bool, dummy_look: Dictionary = {}) -> void:
	first_person = is_first_person
	_team = team
	look = DummyLook.clean(dummy_look if not dummy_look.is_empty() else look)
	for c in get_children():
		c.queue_free()
	_thighs.clear()
	_shins.clear()
	_shoulders.clear()
	_elbows.clear()
	_mat = Materials.toon_unique(0.022)
	_hips = _pivot(self, Vector3(0, 0.95, 0))
	var pelvis := _part(_hips, "pelvis")
	_tails = _pivot(_hips, Vector3(0, 0.02, 0.06))
	var tails := _part(_tails, "tails")
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	var torso := _part(_torso, "torso")
	_head = _pivot(_torso, Vector3(0, 0.6, 0))
	var head_mi := _part(_head, "head")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var thigh := _pivot(_hips, Vector3(side * 0.11, -0.05, 0))
		_part(thigh, "thigh_l" if i == 0 else "thigh_r")
		var shin := _pivot(thigh, Vector3(0, -THIGH, 0))
		_part(shin, "shin")
		_thighs.append(thigh)
		_shins.append(shin)
		var shoulder := _pivot(_torso, Vector3(side * 0.25, 0.46, 0))
		var upper := _part(shoulder, "upper_arm")
		var elbow := _pivot(shoulder, Vector3(0, -UPPER_ARM, 0))
		var fore := _part(elbow, "forearm")
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		if first_person:
			upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			fore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The right hand holds whatever gun you have out (third person only).
	_hand = _pivot(_elbows[1], Vector3(0, -FOREARM - 0.05, 0))
	_gun_mi = MeshInstance3D.new()
	_gun_mi.material_override = Materials.toon(0.008)
	_gun_mi.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.0, -0.01))
	_hand.add_child(_gun_mi)
	if first_person:
		_gun_mi.visible = false
		for mi: MeshInstance3D in [head_mi, torso, pelvis, tails]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		position.z = 0.06
	var w := _weapon
	_weapon = &"-"
	set_weapon(w if w != &"-" else &"revolver")


## Re-dresses the dummy (keeps team and first-person setting).
func apply_look(new_look: Dictionary) -> void:
	var cleaned := DummyLook.clean(new_look)
	if DummyLook.key(cleaned) == DummyLook.key(look) and _hips != null:
		return
	build(_team, first_person, cleaned)


## Shows gun `id` in the right hand ("" = empty hand).
func set_weapon(id: StringName) -> void:
	if id == _weapon:
		return
	_weapon = id
	_gun_mi.mesh = WeaponBuilder.gun(id) if id != &"" else null


## A shove (rock hit, explosion): the body tips away from `dir` and springs back.
func knock(dir: Vector3, strength: float) -> void:
	var local := global_transform.basis.inverse() * dir
	_wobble_vel += Vector3(local.z, 0.0, -local.x).normalized() * strength * 9.0 + Vector3(0, randf_range(-1, 1), 0) * strength * 4.0


## Called every frame. speed = horizontal speed (m/s); pitch = aim pitch (radians).
func animate(delta: float, speed: float, sliding: bool, pitch: float) -> void:
	if _hips == null:
		return
	_slide = move_toward(_slide, 1.0 if sliding else 0.0, delta * 6.0)
	var k := clampf(speed / 6.0, 0.0, 1.6)
	if speed > 0.3:
		_phase += delta * (4.0 + speed * 0.9)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(delta * 6.0, 0.0, 1.0))
	for i in 2:
		var s := sin(_phase + float(i) * PI)
		_thighs[i].rotation.x = lerpf(s * 0.55 * k, -1.35, _slide)
		_shins[i].rotation.x = lerpf(maxf(-cos(_phase + float(i) * PI), 0.0) * 0.9 * k, 0.1, _slide)
	# Right arm (index 1) aims the gun; the left arm swings.
	_shoulders[1].rotation.x = -1.35 - pitch * 0.9
	_elbows[1].rotation.x = -0.15
	_shoulders[0].rotation.x = lerpf(-sin(_phase) * 0.45 * k, -0.6, _slide)
	_elbows[0].rotation.x = -0.35
	_hips.position.y = lerpf(0.95 + absf(sin(_phase)) * 0.03 * k, 0.48, _slide)
	_torso.rotation.x = lerpf(-0.06 * k, 0.45, _slide)
	_head.rotation.x = clampf(pitch, -0.7, 0.7) - _torso.rotation.x
	var want := 0.25 * k + sin(_phase * 2.0) * 0.06 * k
	_tail_swing = lerpf(_tail_swing, want, clampf(delta * 6.0, 0.0, 1.0))
	_tails.rotation.x = lerpf(_tail_swing, 0.9, _slide)
	# Wobble spring (damped): floppy dummy reaction to hits.
	_wobble_vel += (-_wobble * 60.0 - _wobble_vel * 7.0) * delta
	_wobble += _wobble_vel * delta
	_hips.rotation = Vector3(_wobble.x, _wobble.y, _wobble.z)
	_head.rotation.z = -_wobble.z * 1.4
	_shoulders[0].rotation.z = -absf(_wobble.z) * 2.0 - 0.05
	_shoulders[1].rotation.z = absf(_wobble.x) * 1.5


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


func _part(parent: Node3D, part: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(part, _team, look)
	mi.material_override = _mat
	parent.add_child(mi)
	return mi


static func _taper(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs: int = 12) -> void:
	WeaponBuilder.rod(st, a, b, r0, r1, segs, col)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), a), Vector3.ONE * r0, 5, segs, col)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), b), Vector3.ONE * r1, 5, segs, col)


## The crash-test marker: a disc quartered dark and light, facing +Y of xf.
static func marker(st: SurfaceTool, xf: Transform3D, r: float) -> void:
	var n := (xf.basis * Vector3.UP).normalized()
	var c := xf.origin
	var segs := 16
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var col := MeshKit.vcol(MARK_DARK if (i * 4 / segs) % 2 == 0 else MARK_LIGHT)
		MeshKit.tri(st, c, xf * (Vector3(cos(a0), 0.0, sin(a0)) * r), xf * (Vector3(cos(a1), 0.0, sin(a1)) * r), n, n, n, col, n)
	MeshKit.add_cylinder(st, Transform3D(xf.basis, c - n * 0.002), r + 0.006, r + 0.006, 0.004, 16, MARK_DARK)


## Builds (and caches per team colour and look) each body part. Front is -Z.
static func _mesh(part: String, team: Color, look: Dictionary) -> ArrayMesh:
	var key := "%s|%s|%s" % [part, team.to_html(), DummyLook.key(look)]
	if _meshes.has(key):
		return _meshes[key]
	var paint := DummyLook.paint(look)
	var hair := DummyLook.hair_color(look)
	var outfit := str(look.get("outfit"))
	var st := MeshKit.begin()
	match part:
		"pelvis":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.02, 0)), Vector3(0.18, 0.11, 0.12), 6, 14, paint)
			for side: float in [-1.0, 1.0]:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(side * 0.12, -0.05, 0)), 0.065, 0.065, 0.05, 12, JOINT)
			# Gun belt with buckle, cartridge loops and a holster.
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 0.06), Vector3(0, 0.03, 0)), 0.185, 0.195, 0.055, 16, BELT)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, -0.19)), Vector3(0.07, 0.05, 0.015), BRASS)
			for i in 6:
				var a := PI * 0.15 + i * 0.22
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.195, 0.03, sin(a) * 0.195)), Vector3(0.012, 0.018, 0.012), 3, 6, BRASS)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.2, -0.1, -0.02)), Vector3(0.05, 0.17, 0.08), BELT)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.205, 0.01, -0.03)), Vector3(0.03, 0.06, 0.05), WeaponBuilder.WALNUT)
		"tails":
			if outfit == "duster":
				for side: float in [-1.0, 1.0]:
					var b := Basis(Vector3.UP, side * 0.35).rotated(Vector3.RIGHT, 0.12)
					MeshKit.add_box(st, Transform3D(b, Vector3(side * 0.12, -0.3, 0.05)), Vector3(0.22, 0.6, 0.025), COAT)
					MeshKit.add_box(st, Transform3D(b, Vector3(side * 0.12, -0.59, 0.085)), Vector3(0.225, 0.04, 0.03), COAT_DARK)
			elif outfit == "poncho":
				MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, -0.12, 0.08)), Vector3(0.36, 0.2, 0.02), team.darkened(0.2))
		"torso":
			# Dummy chest: rounded ribcage, black rib bands, sternum plate with a marker.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.26, 0)), Vector3(0.2, 0.29, 0.13), 7, 16, paint)
			for i in 3:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.12 + i * 0.07, 0)), 0.198 - i * 0.004, 0.198 - i * 0.004, 0.018, 16, JOINT)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.3, -0.12)), Vector3(0.14, 0.2, 0.03), paint.lightened(0.08))
			marker(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3, -0.137)), 0.05)
			# Shoulder caps and a ribbed rubber neck.
			for side: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.2, 0.46, 0)), Vector3(0.075, 0.06, 0.08), 5, 10, JOINT)
			for i in 4:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.53 + i * 0.022, 0)), 0.055 - (i % 2) * 0.008, 0.055 - (i % 2) * 0.008, 0.02, 12, JOINT)
			_torso_outfit(st, outfit, team, look)
		"head":
			# Dummy head: smooth, faceless, black seam lines, quartered markers on the temples.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(0.105, 0.128, 0.116), 8, 16, paint)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.0, -0.06)), Vector3(0.07, 0.05, 0.065), 5, 12, paint)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.07, -0.112)), Vector3(0.016, 0.022, 0.014), 4, 8, paint.darkened(0.06))
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.07, 0.0)), Vector3(0.006, 0.006, 0.236), JOINT)
			for side: float in [-1.0, 1.0]:
				marker(st, Transform3D(Basis(Vector3.BACK, side * PI * 0.5), Vector3(side * 0.104, 0.075, 0.0)), 0.04)
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.04, 0.1, -0.104)), Vector3(0.017, 0.006, 0.006), 3, 6, JOINT)
			_head_extras(st, look, team, hair)
		"thigh_l", "thigh_r":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.075, 5, 10, JOINT)
			_taper(st, Vector3(0, -0.04, 0), Vector3(0, -THIGH + 0.05, 0), 0.08, 0.068, paint)
			var side := -1.0 if part == "thigh_l" else 1.0
			marker(st, Transform3D(Basis(Vector3.BACK, side * PI * 0.5), Vector3(side * 0.077, -0.2, 0.0)), 0.035)
		"shin":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.07, 5, 10, JOINT)
			_taper(st, Vector3(0, -0.04, 0), Vector3(0, -SHIN + 0.06, 0), 0.064, 0.056, paint)
			if DummyLook.has_boots(look):
				_taper(st, Vector3(0, -SHIN * 0.45, 0), Vector3(0, -SHIN + 0.02, 0), 0.07, 0.065, BOOT)
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.01, -0.09)), Vector3(0.06, 0.045, 0.13), 5, 10, BOOT)
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.03, 0.035)), Vector3(0.07, 0.06, 0.06), BELT)
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, -SHIN, 0.075)), 0.022, 0.022, 0.006, 8, Palette.METAL)
				for s2: float in [-1.0, 1.0]:
					MeshKit.add_limb(st, Vector3(s2 * 0.06, -SHIN + 0.005, 0.03), Vector3(0, -SHIN, 0.07), 0.006, Palette.METAL, 5)
			else:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -SHIN + 0.035, 0)), 0.05, 0.05, 0.03, 10, JOINT)
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.01, -0.04)), Vector3(0.1, 0.07, 0.22), paint)
		"upper_arm":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.06, 5, 10, JOINT)
			if outfit == "duster":
				_taper(st, Vector3(0, -0.02, 0), Vector3(0, -UPPER_ARM + 0.02, 0), 0.075, 0.065, COAT)
			else:
				_taper(st, Vector3(0, -0.04, 0), Vector3(0, -UPPER_ARM + 0.04, 0), 0.058, 0.05, paint)
		"forearm":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.055, 5, 10, JOINT)
			if outfit == "duster":
				_taper(st, Vector3(0, -0.02, 0), Vector3(0, -FOREARM + 0.04, 0), 0.062, 0.058, COAT)
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -FOREARM + 0.03, 0)), 0.066, 0.066, 0.04, 12, COAT_DARK)
			else:
				_taper(st, Vector3(0, -0.04, 0), Vector3(0, -FOREARM + 0.02, 0), 0.05, 0.044, paint)
			# Black wrist joint and a mitten hand with a thumb.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.005, 0)), Vector3.ONE * 0.04, 4, 8, JOINT)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.06, -0.005)), Vector3(0.042, 0.055, 0.035), 5, 10, paint)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.035, -FOREARM - 0.04, -0.03)), Vector3(0.016, 0.03, 0.016), 3, 6, paint)
	var mesh := MeshKit.finish(st)
	_meshes[key] = mesh
	return mesh


## Clothes over the chest: vest, duster, poncho, lawman; then the neck and bandolier.
static func _torso_outfit(st: SurfaceTool, outfit: String, team: Color, look: Dictionary) -> void:
	match outfit:
		"vest", "lawman":
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, side * 0.25), Vector3(side * 0.1, 0.26, -0.06)), Vector3(0.13, 0.36, 0.16), VEST)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.26, 0.07)), Vector3(0.36, 0.38, 0.08), VEST)
			for i in 3:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.05, 0.16 + i * 0.08, -0.14)), Vector3.ONE * 0.009, 3, 6, BRASS)
			if outfit == "lawman":
				# Six-point star on the chest.
				for k in 2:
					var star := Basis(Vector3.BACK, k * PI / 3.0) * Basis(Vector3.RIGHT, PI * 0.5)
					MeshKit.add_cylinder(st, Transform3D(star, Vector3(0.09, 0.34, -0.15)), 0.045, 0.045, 0.008, 3, Palette.METAL.lightened(0.3))
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.09, 0.34, -0.155)), Vector3.ONE * 0.012, 3, 6, BRASS)
		"duster":
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, side * 0.2), Vector3(side * 0.15, 0.24, 0.02)), Vector3(0.12, 0.5, 0.25), COAT)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, side * 0.35).rotated(Vector3.UP, side * 0.25), Vector3(side * 0.12, 0.42, -0.11)), Vector3(0.06, 0.2, 0.02), COAT_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.24, 0.11)), Vector3(0.38, 0.5, 0.04), COAT)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.46, 0.02)), Vector3(0.27, 0.07, 0.15), 5, 14, COAT)
		"poncho":
			# A wool poncho draped over the shoulders, striped in team colour.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.36, 0)), 0.1, 0.3, 0.32, 16, Color("#C8A878"))
			for i in 3:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.24 + i * 0.05, 0)), 0.275 - i * 0.04, 0.267 - i * 0.04, 0.02, 16, team if i % 2 == 0 else Color("#3A2416"))
	match str(look.get("neck")):
		"bandana":
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.53, 0)), 0.075, 0.07, 0.05, 12, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.48, -0.08)), 0.05, 0.0, 0.08, 4, team.darkened(0.1))
		"bolo":
			MeshKit.add_limb(st, Vector3(-0.02, 0.53, -0.06), Vector3(0, 0.4, -0.13), 0.004, BELT, 4)
			MeshKit.add_limb(st, Vector3(0.02, 0.53, -0.06), Vector3(0, 0.4, -0.13), 0.004, BELT, 4)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.44, -0.135)), Vector3(0.022, 0.026, 0.008), 4, 8, Color("#3FA8A0"))
	if DummyLook.has_bandolier(look):
		var b := Basis(Vector3.FORWARD, 0.6)
		MeshKit.add_box(st, Transform3D(b, Vector3(0, 0.27, -0.13)), Vector3(0.06, 0.62, 0.02), BELT)
		MeshKit.add_box(st, Transform3D(b, Vector3(0, 0.27, 0.13)), Vector3(0.06, 0.62, 0.02), BELT)
		for i in 7:
			MeshKit.add_ellipsoid(st, Transform3D(b, Vector3(0, 0.27, -0.14) + b * Vector3(0, -0.24 + i * 0.08, 0)), Vector3(0.012, 0.02, 0.012), 3, 6, BRASS)


## Hat, hair, facial hair and a bandana mask, on the head.
static func _head_extras(st: SurfaceTool, look: Dictionary, team: Color, hair: Color) -> void:
	match str(look.get("hair")):
		"mullet":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.0, 0.1)), Vector3(0.1, 0.12, 0.05), 5, 10, hair)
		"ponytail":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, 0.08)), Vector3(0.1, 0.06, 0.06), 4, 8, hair)
			_taper(st, Vector3(0, 0.1, 0.12), Vector3(0, -0.08, 0.17), 0.028, 0.018, hair, 8)
		"long":
			for i in 7:
				var a := -1.1 + i * 0.37
				_taper(st, Vector3(sin(a) * 0.1, 0.12, cos(a) * 0.09 + 0.02), Vector3(sin(a) * 0.13, -0.1, cos(a) * 0.12 + 0.03), 0.03, 0.02, hair, 8)
		"mohawk":
			for i in 6:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.3 + i * 0.12), Vector3(0, 0.2, -0.08 + i * 0.035)), 0.016, 0.0, 0.11, 5, hair)
	var lip := Vector3(0, 0.035, -0.115)
	match str(look.get("facial")):
		"handlebar":
			for s: float in [-1.0, 1.0]:
				_taper(st, lip, lip + Vector3(s * 0.05, -0.006, 0.01), 0.013, 0.01, hair, 8)
				_taper(st, lip + Vector3(s * 0.05, -0.006, 0.01), lip + Vector3(s * 0.075, 0.02, 0.02), 0.009, 0.004, hair, 6)
		"horseshoe":
			for s: float in [-1.0, 1.0]:
				_taper(st, lip + Vector3(s * 0.015, 0, 0), lip + Vector3(s * 0.04, -0.005, 0.01), 0.011, 0.01, hair, 8)
				_taper(st, lip + Vector3(s * 0.04, -0.005, 0.01), lip + Vector3(s * 0.045, -0.07, 0.02), 0.01, 0.008, hair, 8)
		"walrus":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), lip + Vector3(0, -0.01, 0.003)), Vector3(0.06, 0.025, 0.02), 4, 10, hair)
		"pencil":
			MeshKit.add_box(st, Transform3D(Basis(), lip + Vector3(0, 0.002, 0.004)), Vector3(0.06, 0.006, 0.01), hair)
		"goatee":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.035, -0.105)), Vector3(0.03, 0.04, 0.025), 4, 8, hair)
			MeshKit.add_box(st, Transform3D(Basis(), lip), Vector3(0.05, 0.01, 0.012), hair)
		"beard":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.02, -0.06)), Vector3(0.1, 0.08, 0.08), 5, 12, hair)
			MeshKit.add_box(st, Transform3D(Basis(), lip), Vector3(0.07, 0.014, 0.016), hair)
		"chops":
			for s: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(s * 0.085, 0.02, -0.04)), Vector3(0.025, 0.06, 0.04), 4, 8, hair)
	if str(look.get("neck")) == "mask":
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.02, -0.01)), Vector3(0.113, 0.068, 0.12), 6, 14, team)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.05, -0.085)), 0.055, 0.0, 0.07, 4, team.darkened(0.1))
	match str(look.get("hat")):
		"cattleman":
			_hat(st, team, 0.13, 0.115, 0.27, 0.55, true)
		"ten_gallon":
			_hat(st, team, 0.2, 0.12, 0.31, 0.45, true)
		"gambler":
			_hat(st, team, 0.1, 0.12, 0.25, 0.0, false)
		"bowler":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(0.115, 0.1, 0.125), 6, 14, Color("#2A2422"))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.17, 0)), 0.122, 0.122, 0.025, 14, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.155, 0)), 0.165, 0.16, 0.014, 16, Color("#2A2422"))
		"sombrero":
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.27, 0)), 0.11, 0.07, 0.17, 14, Color("#D8B46A"))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.115, 0.115, 0.03, 14, team)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.18, 0)), 0.45, 0.4, 0.02, 20, Color("#D8B46A"))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.46, 0.46, 0.02, 20, Color("#B8944A"))


## A cowboy hat: crown height, crown radius, brim radius, brim curl, pinched top.
static func _hat(st: SurfaceTool, team: Color, crown_h: float, crown_r: float, brim_r: float, curl: float, pinch: bool) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.19 + crown_h * 0.5, 0)), crown_r, crown_r * 0.86, crown_h, 14, HAT)
	if pinch:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.19 + crown_h - 0.006, 0.005)), Vector3(0.05, 0.03, crown_r * 1.5), HAT_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.205, 0)), crown_r + 0.003, crown_r + 0.003, 0.03, 14, team)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.188, 0)), brim_r, brim_r - 0.02, 0.018, 18, HAT)
	if curl > 0.0:
		for side: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, side * curl), Vector3(side * (brim_r - 0.035), 0.215, 0)), Vector3(0.08, 0.016, brim_r * 1.1), HAT)
