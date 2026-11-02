class_name CorpsePile
extends Node3D
## Carnage at the foot of the cliffs: every bug shot off a cliff wall (or killed
## crossing the canyon floor) leaves a husk lying on its back at the base, so the
## piles grow through a wave. One MultiMesh per cliff, capped: past the cap the
## oldest husks are reused. The host batches deaths and sends them twice a
## second; every peer draws the same piles.

const CAP_PER_CLIFF := 220
const SEND_EVERY := 0.5

var cliffs: CliffBuilder
var _mm: Array[MultiMesh] = []
var _next: Array[int] = [0, 0]
var _count: Array[int] = [0, 0]
## Host: deaths waiting to go out, 6 floats each (cliff, x, y, z, scale, colour as rgba8).
var _pending := PackedFloat32Array()
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var mesh := husk_mesh()
	var mat := Materials.toon(0.02)
	for cid in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = CAP_PER_CLIFF
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Pile%d" % cid
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm.append(mm)
	_hook.call_deferred()


func _hook() -> void:
	if BugManager.instance != null and multiplayer.is_server():
		BugManager.instance.child_entered_tree.connect(func(n: Node) -> void:
			var b := n as Bug
			if b != null:
				b.died.connect(_on_died.bind(b), CONNECT_ONE_SHOT))
	if GameState.has_flag("--corpses") or GameState.flag_value("--corpses") != "":
		# Debug: a pile already there (screenshots).
		for i in 160:
			var cid := i % 2
			var ids: Array = [&"dust_mite", &"wolf_spider", &"rattler_beetle", &"spitter_scorpion", &"burrow_tick"]
			var d := Defs.bug(ids[i % ids.size()])
			_add(cid, randf_range(-18.0, 18.0), 0.6 + randf() * 1.4, d.shell_color if d != null else Color.SADDLE_BROWN)
		if GameState.flag_value("--corpses") == "view" and cliffs != null:
			# Down on the canyon floor, looking at the foot of the west wall.
			var cam := Camera3D.new()
			add_child(cam)
			var base := cliffs.face_point(0, 0.0, 0.0)
			var eye := base + Vector3(14.0, 0.0, -6.0)
			eye.y = cliffs.floor_height(eye.x, eye.z) + 3.5
			cam.global_position = eye
			cam.look_at(base + Vector3(2.0, 1.0, 2.0))
			cam.current = true


func _on_died(_bug: Bug, _source: String, _source_cliff: int, b: Bug) -> void:
	if cliffs == null or not is_instance_valid(b):
		return
	var was := b.died_in
	if was != Bug.State.CLIMBING and was != Bug.State.CROSSING:
		return
	var z := clampf(b.lane_z if was == Bug.State.CLIMBING else b.global_position.z, -WorldLayout.WORLD_HALF_Z + 4.0, WorldLayout.WORLD_HALF_Z - 4.0)
	var s := clampf(float(b.spec.get("scale", 1.0)), 0.4, 3.0)
	_pending.append_array([float(b.cliff_id), z, s, b.def.shell_color.r, b.def.shell_color.g, b.def.shell_color.b])


func _process(delta: float) -> void:
	if _pending.is_empty():
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = SEND_EVERY
	_land.rpc(_pending)
	_pending = PackedFloat32Array()


@rpc("authority", "call_local", "reliable")
func _land(batch: PackedFloat32Array) -> void:
	var i := 0
	while i + 5 < batch.size():
		_add(int(batch[i]), batch[i + 1], batch[i + 2], Color(batch[i + 3], batch[i + 4], batch[i + 5]))
		i += 6


## A husk at the foot of cliff `cid` near z: tumbled out a little from the wall.
func _add(cid: int, z: float, scale_v: float, shell: Color) -> void:
	if cid < 0 or cid > 1 or cliffs == null:
		return
	z += _rng.randf_range(-1.2, 1.2)
	var base := cliffs.face_point(cid, 0.0, z)
	var out := Vector3(-WorldLayout.side_sign(cid), 0.0, 0.0)
	var p := base + out * _rng.randf_range(0.8, 4.5)
	p.y = cliffs.floor_height(p.x, p.z) - 0.08 * scale_v
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	basis = basis * Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.3, 0.3))
	var mm := _mm[cid]
	var k := _next[cid]
	mm.set_instance_transform(k, Transform3D(basis.scaled(Vector3.ONE * scale_v), p))
	mm.set_instance_color(k, shell.darkened(_rng.randf_range(0.05, 0.25)))
	_next[cid] = (k + 1) % CAP_PER_CLIFF
	_count[cid] = mini(_count[cid] + 1, CAP_PER_CLIFF)
	mm.visible_instance_count = _count[cid]


func husks(cid: int) -> int:
	return _count[cid]


## One husk: a shell on its back with six legs curled up. White, tinted per
## instance (shell colour, darkened as it dries out).
static func husk_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var shell := Color(1, 1, 1)
	var belly := Color(0.82, 0.78, 0.7)
	var leg := Color(0.45, 0.42, 0.4)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.16, 0)), Vector3(0.48, 0.26, 0.7), 5, 9, shell)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.3, 0.02)), Vector3(0.32, 0.08, 0.5), 4, 8, belly)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.17, -0.62)), Vector3(0.2, 0.15, 0.18), 4, 6, shell)
	for i in 3:
		for s: float in [-1.0, 1.0]:
			var hip := Vector3(s * 0.22, 0.32, -0.25 + i * 0.25)
			var knee := hip + Vector3(s * 0.22, 0.28, (i - 1) * 0.08)
			var foot := knee + Vector3(-s * 0.1, 0.12, (i - 1) * 0.06)
			MeshKit.add_limb(st, hip, knee, 0.06, leg, 5)
			MeshKit.add_limb(st, knee, foot, 0.045, leg, 5)
	return MeshKit.finish(st)
