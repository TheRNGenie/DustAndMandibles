class_name CoveragePreview
extends Node3D
## While placing a cliff turret: a see-through cone from where its gun will sit
## to the patch of the far cliff it can cover, with that patch painted on the
## wall. The patch is every point of the far face inside the turret's range and
## look-down limit (scaffold levels let it see further down), so you can see at
## a glance which lanes and how far down it reaches. Plateau guards and air
## defence get a ring for their range instead. Rebuilt only when the ghost
## moves to a new cell or level.

const STEP := 2.0
const FACE_OFFSET := 1.6

var cliffs: CliffBuilder
var _key := ""
var _patch: MeshInstance3D
var _cone: MeshInstance3D
var _mat_patch: StandardMaterial3D
var _mat_cone: StandardMaterial3D
var _head_y: Dictionary = {}


func _ready() -> void:
	top_level = true
	_mat_patch = _mat(0.32)
	_mat_cone = _mat(0.1)
	_patch = MeshInstance3D.new()
	_patch.material_override = _mat_patch
	_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_patch)
	_cone = MeshInstance3D.new()
	_cone.material_override = _mat_cone
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cone)
	visible = false


static func _mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, alpha)
	return m


func hide_preview() -> void:
	visible = false
	_key = ""


## Show coverage for turret `id` standing at `base` on cliff `cid`, raised by
## `level` scaffold levels. `ok` tints it green (placeable) or red.
func show_for(id: StringName, cid: int, base: Vector3, level: int, ok: bool) -> void:
	visible = true
	var tint := Color(0.45, 1.0, 0.5) if ok else Color(1.0, 0.4, 0.3)
	_mat_patch.albedo_color = Color(tint.r, tint.g, tint.b, 0.4)
	_mat_cone.albedo_color = Color(tint.r, tint.g, tint.b, 0.1)
	var key := "%s|%d|%s|%d" % [id, cid, str(base.snapped(Vector3.ONE * 0.5)), level]
	if key == _key:
		return
	_key = key
	var def := Defs.turret(id)
	if def.guards_plateau or def.anti_air:
		_ring(base, def.range if not def.anti_air else minf(def.range, 60.0))
		return
	if not _head_y.has(id):
		_head_y[id] = float(TurretBuilder.build(id, Color.WHITE)["head_y"])
	var muzzle := base + Vector3(0, float(_head_y[id]), 0)
	var pitch := def.pitch_limit_deg + Turret.look_down_bonus(level)
	_far_patch(cid, muzzle, pitch, def.range_at(0, level))
	if GameState.has_flag("--coverlog"):
		print("[cover] %s cliff %d muzzle %s pitch %.0f -> patch %s" % [id, cid, str(muzzle.snapped(Vector3.ONE * 0.1)), pitch, str(_patch.mesh.get_aabb() if _patch.mesh else null)])


## The covered patch of the far wall, and the cone from the muzzle to its edge.
func _far_patch(cid: int, muzzle: Vector3, pitch: float, rng: float) -> void:
	var m := WorldLayout.map()
	var other := m.main_target(cid)
	var cell := Buildable.world_to_cell(cliffs, cid, muzzle)
	if cell.y >= 0:
		other = m.covered_cliff(cid, cell.y) # bigger maps: the spot decides which neighbour
	var zs: Array[float] = []
	# Only the far wall inside the play area (the wild canyon beyond bends away).
	var z_lo := maxf(muzzle.z - rng, -WorldLayout.PLAY_HALF_Z + 2.0)
	var z_hi := minf(muzzle.z + rng, WorldLayout.PLAY_HALF_Z - 2.0)
	if not m.is_canyon():
		z_lo = -m.span_v + 2.0
		z_hi = m.span_v - 2.0
	var z := z_lo
	while z <= z_hi:
		zs.append(z)
		z += STEP
	var ys: Array[float] = []
	var y := 0.0
	while y <= WorldLayout.CLIFF_HEIGHT:
		ys.append(y)
		y += STEP
	# Which grid points of the far face are covered?
	var pts: Array = []
	var inside: Array = []
	for yy in ys:
		var prow: Array[Vector3] = []
		var irow: Array[bool] = []
		for zz in zs:
			var p := cliffs.face_point(other, yy, zz)
			prow.append(p + cliffs.face_normal(other, yy, zz) * FACE_OFFSET)
			irow.append(Targeting.in_arc(muzzle, p, pitch, rng))
		pts.append(prow)
		inside.append(irow)
	var st := MeshKit.begin()
	var edge: Array[Vector3] = [] # lowest covered point per column, then the lip back
	var col := Color(1, 1, 1, 1)
	for r in ys.size() - 1:
		for c in zs.size() - 1:
			if inside[r][c] and inside[r][c + 1] and inside[r + 1][c] and inside[r + 1][c + 1]:
				var a: Vector3 = pts[r][c]
				var b: Vector3 = pts[r][c + 1]
				var cc: Vector3 = pts[r + 1][c + 1]
				var d: Vector3 = pts[r + 1][c]
				var n := (b - a).cross(d - a).normalized()
				MeshKit.tri(st, a, b, cc, n, n, n, col, n)
				MeshKit.tri(st, a, cc, d, n, n, n, col, n)
	_patch.mesh = MeshKit.finish(st)
	# Cone outline: bottom edge left to right, then the top edge right to left.
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for c in zs.size():
		var lo := -1
		var hi := -1
		for r in ys.size():
			if inside[r][c]:
				if lo < 0:
					lo = r
				hi = r
		if lo >= 0:
			bottom.append(pts[lo][c])
			top.append(pts[hi][c])
	var cone := MeshKit.begin()
	top.reverse()
	edge.append_array(bottom)
	edge.append_array(top)
	for i in edge.size():
		var p0 := edge[i]
		var p1 := edge[(i + 1) % edge.size()]
		var n := (p0 - muzzle).cross(p1 - muzzle).normalized()
		MeshKit.tri(cone, muzzle, p0, p1, n, n, n, col, n)
	_cone.mesh = MeshKit.finish(cone) if edge.size() > 2 else null


## Plateau guards and air defence: a ring on the ground showing their reach.
func _ring(center: Vector3, radius: float) -> void:
	var st := MeshKit.begin()
	var col := Color(1, 1, 1, 1)
	var segs := 64
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := center + o0 * radius + Vector3.UP * 0.3
		var p1 := center + o1 * radius + Vector3.UP * 0.3
		var q0 := center + o0 * (radius - 0.6) + Vector3.UP * 0.3
		var q1 := center + o1 * (radius - 0.6) + Vector3.UP * 0.3
		MeshKit.tri(st, p0, p1, q1, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)
		MeshKit.tri(st, p0, q1, q0, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)
	_patch.mesh = MeshKit.finish(st)
	_cone.mesh = null
