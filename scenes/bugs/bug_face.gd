class_name BugFace
extends Node3D
## A bug's personality, layered on its body mesh:
##   pupils that follow the nearest player, and blinks;
##   chunky black eyebrows that frown harder as you get close (and scowl when shot);
##   mandibles that chatter (faster when angry), antennae that twitch and sway;
##   buzzing wings for fliers; and, for the rare smoker, a cigarette.

const BROW := Color("#1A1412")
const PUPIL := Color("#120C0A")
const NEAR := 25.0

var _brows: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _eye_pos: Array[Vector3] = []
var _eye_r: Array[float] = []
var _lids: Array[Node3D] = []
var _mandibles: Array[Node3D] = []
var _antennae: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _cig: Node3D
var _ember: OmniLight3D
var _bug: Node3D
var _frown := 0.4
var _wince := 0.0
var _r := 0.05
var _t := 0.0
var _puff_t := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _anger := 0.0
var _seed := 0.0


func setup(bug: Node3D, spec: Dictionary, smoker: bool) -> void:
	_bug = bug
	_seed = randf() * 100.0
	_blink_t = randf_range(1.0, 4.0)
	var eyes: Dictionary = spec.get("eyes", {})
	var face: Dictionary = spec.get("face", {})
	var lid_color: Color = (face.get("color", Color("#3A2A22")) as Color).lightened(0.15)
	var mat := Materials.toon(0.012)
	if not eyes.is_empty():
		var center: Vector3 = eyes["center"]
		var spread: float = eyes["spread"]
		_r = float(eyes["r"])
		var count := int(eyes.get("count", 2))
		# Pupils and lids for every eye.
		var pupil_mesh := _ball(PUPIL)
		var shine_mesh := _ball(Color(1, 1, 1), 0.9)
		var lid_mesh := _ball(lid_color)
		for i in count:
			var side := -1.0 if i % 2 == 0 else 1.0
			var row := float(i / 2)
			var p := center + Vector3(side * spread * (1.0 + row * 0.6), row * _r * 1.5, row * _r * 0.4)
			var rr := _r * (1.0 - row * 0.35)
			_eye_pos.append(p)
			_eye_r.append(rr)
			var pupil := Node3D.new()
			add_child(pupil)
			_mi(pupil, pupil_mesh, mat).scale = Vector3.ONE * rr * 0.5
			var shine := _mi(pupil, shine_mesh, mat)
			shine.scale = Vector3.ONE * rr * 0.16
			shine.position = Vector3(rr * 0.18, rr * 0.2, -rr * 0.25)
			_pupils.append(pupil)
			var lid := Node3D.new()
			lid.position = p
			add_child(lid)
			_mi(lid, lid_mesh, mat).scale = Vector3(rr * 1.1, rr * 1.12, rr * 1.1)
			lid.visible = false
			_lids.append(lid)
		# Eyebrows over the front pair.
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = center + Vector3(side * maxf(spread - _r * 0.9, _r * 0.3), _r * 1.45, -_r * 0.55)
			add_child(pivot)
			var st := MeshKit.begin()
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * _r * 1.35, 0, 0)), Vector3(_r * 3.0, _r * 0.8, _r * 0.9), BROW)
			_mi(pivot, MeshKit.finish(st), mat)
			pivot.set_meta("side", side)
			_brows.append(pivot)
	if not face.is_empty():
		_build_mandibles(face, mat)
		_build_antennae(face, mat)
		if bool(face.get("wings", false)):
			_build_wings()
	if smoker and not eyes.is_empty():
		var mouth: Vector3 = face.get("mouth", eyes["center"] + Vector3(0, -_r * 1.9, -_r * 0.6))
		_add_cigarette(mouth + Vector3(float(eyes["spread"]) * 0.5, 0, -_r * 0.2))


static func _ball(col: Color, glow: float = 0.0) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 4, 8, col, 0.0, null, glow)
	return MeshKit.finish(st)


func _mi(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Two curved hooks either side of the mouth that open and close.
func _build_mandibles(face: Dictionary, mat: Material) -> void:
	var m := float(face.get("mandible", 0.0))
	if m <= 0.0:
		return
	var mouth: Vector3 = face["mouth"]
	var col: Color = face["color"]
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = mouth + Vector3(side * m * 0.55, 0, 0)
		add_child(pivot)
		var st := MeshKit.begin()
		var a := Vector3.ZERO
		var b := Vector3(side * m * 0.15, -m * 0.1, -m * 0.75)
		var c := Vector3(-side * m * 0.45, -m * 0.15, -m * 1.15)
		MeshKit.add_limb(st, a, b, m * 0.2, col, 6)
		MeshKit.add_limb(st, b, c, m * 0.13, col.lightened(0.1), 6)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y((c - b).normalized()), c + (c - b).normalized() * m * 0.12), m * 0.1, 0.0, m * 0.25, 5, Palette.BONE)
		_mi(pivot, MeshKit.finish(st), mat)
		pivot.set_meta("side", side)
		_mandibles.append(pivot)


## Two jointed feelers from the top of the head.
func _build_antennae(face: Dictionary, mat: Material) -> void:
	var length := float(face.get("antenna", 0.0))
	if length <= 0.0:
		return
	var at: Vector3 = face.get("antenna_at", face["mouth"])
	var col: Color = (face["color"] as Color).darkened(0.1)
	for side: float in [-1.0, 1.0]:
		var base := Node3D.new()
		base.position = at + Vector3(side * length * 0.25, 0, 0)
		add_child(base)
		var st := MeshKit.begin()
		var elbow := Vector3(side * length * 0.35, length * 0.5, -length * 0.3)
		var tip := elbow + Vector3(side * length * 0.15, length * 0.2, -length * 0.55)
		MeshKit.add_limb(st, Vector3.ZERO, elbow, length * 0.05, col, 5)
		MeshKit.add_limb(st, elbow, tip, length * 0.035, col, 5)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), tip), Vector3.ONE * length * 0.08, 3, 6, col.lightened(0.2))
		_mi(base, MeshKit.finish(st), mat)
		base.set_meta("side", side)
		_antennae.append(base)


## Four see-through wings that buzz (dragonfly bandits).
func _build_wings() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.7, 0, 0)), Vector3(0.7, 0.012, 0.16), 3, 10, Color(1, 1, 1))
	for k in 4:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.35 + k * 0.25, 0.013, 0)), Vector3(0.01, 0.004, 0.24 - k * 0.04), Color(0.4, 0.5, 0.6))
	var wing := MeshKit.finish(st)
	var scale_k := (_bug as Bug).spec.get("scale", 1.0) as float if _bug is Bug else 1.0
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.25, 0.1]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.08, 0.12, z) * scale_k
			add_child(pivot)
			var mi := MeshInstance3D.new()
			mi.mesh = wing
			mi.material_override = mat
			mi.scale = Vector3(side, 1.0, 1.0) * scale_k
			pivot.add_child(mi)
			pivot.set_meta("side", side)
			pivot.set_meta("phase", 0.0 if z < 0 else 1.4)
			_wings.append(pivot)


func _add_cigarette(mouth: Vector3) -> void:
	var len := maxf(_r * 3.2, 0.12)
	var rad := len * 0.09
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 0.5)), rad, rad, len, 8, Palette.BONE)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 0.1)), rad * 1.05, rad * 1.05, len * 0.22, 8, Color("#C98A3A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 1.0)), rad, rad, len * 0.07, 8, Color("#FF6A1A"), true, 0.9)
	_cig = MeshInstance3D.new()
	(_cig as MeshInstance3D).mesh = MeshKit.finish(st)
	(_cig as MeshInstance3D).material_override = Materials.toon(0.006)
	_cig.position = mouth
	_cig.rotation = Vector3(-0.35, -0.5, 0.0)
	add_child(_cig)
	_ember = OmniLight3D.new()
	_ember.light_color = Color("#FF7A2A")
	_ember.omni_range = len * 1.5
	_ember.light_energy = 0.4
	_ember.position = mouth + _cig.basis * Vector3(0, 0, -len)
	add_child(_ember)


## Got shot: brows jump into a deep scowl, eyes squeeze, mandibles snap.
func wince() -> void:
	_wince = 1.0
	_blink = 0.6


func _process(delta: float) -> void:
	_t += delta
	_wince = maxf(_wince - delta * 2.5, 0.0)
	# Who's the nearest player, and how close?
	var near := INF
	var target := Vector3.ZERO
	for n: Node in get_tree().get_nodes_in_group("players"):
		var d := (n as Node3D).global_position.distance_to(global_position)
		if d < near:
			near = d
			target = (n as Node3D).global_position + Vector3.UP * 1.5
	_anger = lerpf(_anger, clampf(1.0 - near / NEAR, 0.0, 1.0), clampf(delta * 3.0, 0.0, 1.0))
	# Brows.
	var want := 0.35 + 0.35 * _anger + sin(_t * 7.0 + _seed) * 0.03
	_frown = lerpf(_frown, want, clampf(delta * 4.0, 0.0, 1.0))
	for b in _brows:
		var side: float = b.get_meta("side")
		b.rotation.z = side * (_frown + _wince * 0.4)
	# Pupils look at you (or wander when nobody's around).
	var local_target := to_local(target) if near < 80.0 else Vector3(sin(_t * 0.7 + _seed) * 2.0, 0.3, -3.0)
	for i in _pupils.size():
		var dir := (local_target - _eye_pos[i]).normalized()
		if dir.z > -0.2:
			dir.z = -0.2
		dir = dir.normalized()
		_pupils[i].position = _eye_pos[i] + dir * _eye_r[i] * 0.72
		_pupils[i].basis = Basis.looking_at(dir, Vector3.UP) if absf(dir.dot(Vector3.UP)) < 0.98 else Basis()
	# Blinks.
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 5.0)
		_blink = 0.14
	_blink = maxf(_blink - delta, 0.0)
	for lid in _lids:
		lid.visible = _blink > 0.0
	# Mandibles: a slow idle chew that turns into furious chattering up close.
	var speed := lerpf(4.0, 22.0, _anger) + _wince * 20.0
	var open := (0.15 + 0.25 * _anger + _wince * 0.3) * (0.5 + 0.5 * sin(_t * speed + _seed))
	for m in _mandibles:
		m.rotation.y = -float(m.get_meta("side")) * open
	# Antennae: lazy sway, plus nervous twitches.
	var twitch := pow(maxf(sin(_t * 1.7 + _seed * 3.0), 0.0), 18.0) * 0.6
	for a in _antennae:
		var side: float = a.get_meta("side")
		a.rotation = Vector3(sin(_t * 2.1 + side + _seed) * 0.18 - twitch, side * sin(_t * 1.3 + _seed) * 0.15, side * twitch * 0.5)
	# Wings buzz.
	for w in _wings:
		var side: float = w.get_meta("side")
		w.rotation.z = side * sin(_t * 55.0 + float(w.get_meta("phase"))) * 0.55
	if _cig != null:
		_ember.light_energy = 0.35 + sin(_t * 5.0) * 0.15
		_puff_t -= delta
		if _puff_t <= 0.0:
			_puff_t = 1.2
			_puff()


func _puff() -> void:
	var p := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _r * 0.6
	sphere.height = _r * 1.2
	sphere.radial_segments = 8
	sphere.rings = 4
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.94, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	get_tree().current_scene.add_child(p)
	p.global_position = _ember.global_position
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "global_position", p.global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3)), 2.0)
	tw.tween_property(p, "scale", Vector3.ONE * 3.5, 2.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.chain().tween_callback(p.queue_free)
