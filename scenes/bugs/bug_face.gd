class_name BugFace
extends Node3D
## A bug's personality, layered on its body mesh:
##   pupils that follow the nearest player, and blinks;
##   chunky black eyebrows that frown harder as you get close (and scowl when shot);
##   mandibles that chatter (faster when angry), antennae that twitch and sway;
##   and, for the rare smoker, a cigarette. (Fliers' wings are batched by Bug.)
## Only the nearest few bugs wear a face (BugManager.assign_detail hands them
## out); faces go back to a pool per bug kind when a bug walks away or dies.

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


## Face part meshes by bug kind and part, built once (a new face is then just nodes).
static var _meshes: Dictionary = {}
var _kind := ""


## The cached mesh for `part`, or null (then build it and pass it to _keep).
func _cached(part: String) -> Mesh:
	return _meshes.get(_kind + "|" + part) if _kind != "" else null


func _keep(part: String, mesh: Mesh) -> Mesh:
	if _kind != "":
		_meshes[_kind + "|" + part] = mesh
	return mesh


func setup(bug: Node3D, spec: Dictionary, smoker: bool) -> void:
	_bug = bug
	_kind = String((bug as Bug).def.id) if bug is Bug and (bug as Bug).def != null else ""
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
			var brow := _cached("brow%d" % side)
			if brow == null:
				var st := MeshKit.begin()
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * _r * 1.35, 0, 0)), Vector3(_r * 3.0, _r * 0.8, _r * 0.9), BROW)
				brow = _keep("brow%d" % side, MeshKit.finish(st))
			_mi(pivot, brow, mat)
			pivot.set_meta("side", side)
			_brows.append(pivot)
	if not face.is_empty():
		_build_mandibles(face, mat)
		_build_antennae(face, mat)
	if smoker and not eyes.is_empty():
		var mouth: Vector3 = face.get("mouth", eyes["center"] + Vector3(0, -_r * 1.9, -_r * 0.6))
		_add_cigarette(mouth + Vector3(float(eyes["spread"]) * 0.5, 0, -_r * 0.2))


static func _ball(col: Color, glow: float = 0.0) -> ArrayMesh:
	var key := "ball|%s|%.2f" % [col.to_html(), glow]
	if _meshes.has(key):
		return _meshes[key]
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 4, 8, col, 0.0, null, glow)
	_meshes[key] = MeshKit.finish(st)
	return _meshes[key]


func _mi(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# Eyes and mandibles are tiny: no shadows, and not drawn past 14 m.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 14.0
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
		var mesh := _cached("mandible%d" % side)
		if mesh == null:
			var st := MeshKit.begin()
			var a := Vector3.ZERO
			var b := Vector3(side * m * 0.15, -m * 0.1, -m * 0.75)
			var c := Vector3(-side * m * 0.45, -m * 0.15, -m * 1.15)
			MeshKit.add_limb(st, a, b, m * 0.2, col, 6)
			MeshKit.add_limb(st, b, c, m * 0.13, col.lightened(0.1), 6)
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y((c - b).normalized()), c + (c - b).normalized() * m * 0.12), m * 0.1, 0.0, m * 0.25, 5, Palette.BONE)
			mesh = _keep("mandible%d" % side, MeshKit.finish(st))
		_mi(pivot, mesh, mat)
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
		var mesh := _cached("antenna%d" % side)
		if mesh == null:
			var st := MeshKit.begin()
			var elbow := Vector3(side * length * 0.35, length * 0.5, -length * 0.3)
			var tip := elbow + Vector3(side * length * 0.15, length * 0.2, -length * 0.55)
			MeshKit.add_limb(st, Vector3.ZERO, elbow, length * 0.05, col, 5)
			MeshKit.add_limb(st, elbow, tip, length * 0.035, col, 5)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), tip), Vector3.ONE * length * 0.08, 3, 6, col.lightened(0.2))
			mesh = _keep("antenna%d" % side, MeshKit.finish(st))
		_mi(base, mesh, mat)
		base.set_meta("side", side)
		_antennae.append(base)


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
	_cig.visibility_range_end = 14.0
	add_child(_cig)
	_ember = OmniLight3D.new()
	_ember.light_color = Color("#FF7A2A")
	_ember.omni_range = len * 1.5
	_ember.light_energy = 0.4
	_ember.distance_fade_enabled = true
	_ember.distance_fade_begin = 12.0
	_ember.distance_fade_length = 4.0
	_ember.position = mouth + _cig.basis * Vector3(0, 0, -len)
	add_child(_ember)


# ------------------------------------------------------------------ pool

## Spare faces by bug kind (and smoker), out of the tree. Spares are orphan
## nodes (~20 each), so the pool is capped per kind and in total: the oldest
## spare goes first, so kinds from earlier waves don't sit there all run.
static var _pool: Dictionary = {}
static var _spares: Array = [] # every pooled face, oldest first
const POOL_PER_KIND := 4
const POOL_TOTAL := 16


## A face for `bug` (from the pool when one is spare). Not yet in the tree.
static func acquire(bug: Bug) -> BugFace:
	var key := "%s|%d" % [bug.def.id, int(bug.smoker)]
	var spare: Array = _pool.get(key, [])
	var f: BugFace
	while not spare.is_empty() and f == null:
		var c: Object = spare.pop_back()
		if is_instance_valid(c):
			f = c as BugFace
			_spares.erase(f)
	if f == null:
		f = BugFace.new()
		f.setup(bug, bug.spec, bug.smoker)
		f.set_meta("pool_key", key)
	f._bug = bug
	f._anger = 0.0
	f._wince = 0.0
	f._acc = 0.0
	f.name = "Face"
	return f


## Takes the face off its bug and keeps it for the next bug of that kind.
static func release(f: BugFace) -> void:
	if f == null or not is_instance_valid(f):
		return
	if f.get_parent() != null:
		f.get_parent().remove_child(f)
	f._bug = null
	var key: String = f.get_meta("pool_key", "")
	var spare: Array = _pool.get(key, [])
	if key == "" or spare.size() >= POOL_PER_KIND:
		f.free()
		return
	spare.append(f)
	_pool[key] = spare
	_spares.append(f)
	while _spares.size() > POOL_TOTAL:
		var old: Object = _spares.pop_front()
		if is_instance_valid(old):
			(_pool.get(old.get_meta("pool_key", ""), []) as Array).erase(old)
			old.free()


## Frees every pooled face (the world is going away).
static func clear_pool() -> void:
	for key: String in _pool:
		for f: Object in _pool[key]:
			if is_instance_valid(f):
				f.free()
	_pool.clear()
	_spares.clear()


## Got shot: brows jump into a deep scowl, eyes squeeze, mandibles snap.
func wince() -> void:
	_wince = 1.0
	_blink = 0.6


var _skip := 0
var _acc := 0.0


func _process(frame_delta: float) -> void:
	# Follows the bug's level of detail: every frame close up, every third
	# frame far away, paused off-screen.
	_acc += frame_delta
	_skip += 1
	var lod: int = (_bug as Bug).detail if _bug is Bug else 0
	# Faces aren't drawn past 14 m, so they don't animate there either.
	var unseen := _bug is Bug and (_bug as Bug).cam_dist > 15.0
	if lod >= 2 or unseen or (lod == 1 and _skip < 3):
		return
	_skip = 0
	var delta := _acc
	_acc = 0.0
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
