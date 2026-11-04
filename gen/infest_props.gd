class_name InfestProps
extends RefCounted
## The bug infestation as props (AI-made, see AiModels): egg clusters, resin
## stalactites, shed chitin husks and silk cocoons stuck to the canyon walls,
## burrow mounds, bone piles, eggs and husks on the floor. Like the rock shader's
## infestation they thicken with depth and round the tunnel mouths. Visual only
## (no collision), kept off the raid-site ground, the story ground and the rope
## foot, and drawn as MultiMeshes in chunks along the canyon (so each chunk culls
## and picks its mesh detail on its own); Low effects draws fewer of them.

const DIR := "res://assets/props/"
## name: [where (wall, floor, both), share of picks, scale range]
const KINDS := {
	&"egg_cluster": [&"both", 1.0, Vector2(1.2, 2.4)],
	&"resin_stalactite": [&"wall", 1.1, Vector2(1.3, 2.8)],
	&"chitin_husk": [&"both", 0.8, Vector2(1.3, 2.3)],
	&"silk_cocoon": [&"wall", 0.8, Vector2(1.2, 2.4)],
	&"burrow_mound": [&"floor", 1.0, Vector2(1.0, 2.0)],
	&"bone_pile": [&"floor", 0.9, Vector2(1.0, 1.6)],
}
const CHUNK := 40.0
## Share of the props drawn per effects level (Low, Medium, High).
const SHARE: Array[float] = [0.45, 0.75, 1.0]

static var _batches: Array[MultiMeshInstance3D] = []
static var _counts: Array[int] = []


static func build(parent: Node3D, cliffs: CliffBuilder, seed_value: int) -> void:
	_batches.clear()
	_counts.clear()
	for k: StringName in KINDS:
		if not ResourceLoader.exists(DIR + String(k) + ".glb"):
			return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := WorldLayout.map()
	var canyon := m.is_canyon()
	var top := WorldLayout.CLIFF_HEIGHT
	var mouths: Array[Vector3] = []
	var main := cliffs.main_tunnel()
	for i in cliffs.tunnel_count():
		mouths.append(cliffs.tunnel(i)[0])
	# kind -> chunk key -> Array[Transform3D]
	var placed: Dictionary = {}
	for k: StringName in KINDS:
		placed[k] = {}
	var wall_kinds: Array[StringName] = []
	var floor_kinds: Array[StringName] = []
	var wall_w: Array[float] = []
	var floor_w: Array[float] = []
	for k: StringName in KINDS:
		var spec: Array = KINDS[k]
		if spec[0] != &"floor":
			wall_kinds.append(k)
			wall_w.append(spec[1])
		if spec[0] != &"wall":
			floor_kinds.append(k)
			floor_w.append(spec[1])
	var hive_at := func(p: Vector3) -> float:
		var h := 0.0
		for i in mouths.size():
			var r := 22.0 if i == main else 15.0
			h = maxf(h, 1.0 - clampf(p.distance_to(mouths[i]) / r, 0.0, 1.0))
		return h
	# The tunnel mouths themselves stay clear (bugs pour out of them).
	var by_mouth := func(p: Vector3, r: float) -> bool:
		for mo in mouths:
			if Vector2(p.x - mo.x, p.z - mo.z).length() < r and p.y < mo.y + 9.0:
				return true
		return false
	var span := m.span_v - 3.0 if not canyon else WorldLayout.WORLD_HALF_Z - 2.0
	for cid in m.count():
		# Walls: more tries than props; each is kept with a chance that grows
		# with depth and near the tunnels.
		for i in (520 if canyon else 260):
			var z := rng.randf_range(-span, span)
			if canyon and rng.randf() < 0.25:
				z = rng.randf_range(WorldLayout.WORLD_HALF_Z, 220.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var y := pow(rng.randf(), 1.6) * (top - 8.0) + 0.6
			var p := cliffs.face_point(cid, y, z)
			if by_mouth.call(p, 6.5):
				continue
			var depth := clampf((top - y) / top, 0.0, 1.0)
			var keep: float = pow(depth, 2.2) * 0.32 + hive_at.call(p) * 0.75
			if rng.randf() > keep:
				continue
			var k := wall_kinds[_pick(rng, wall_w)]
			var n := cliffs.face_normal(cid, y, z)
			var spec: Array = KINDS[k]
			var s: float = rng.randf_range(spec[2].x, spec[2].y) * (1.0 + float(hive_at.call(p)) * 0.4)
			var b: Basis
			if k == &"resin_stalactite":
				# Hangs from the wall: up stays up, its back against the rock.
				b = Basis(Vector3.UP, atan2(n.x, n.z) + rng.randf_range(-0.4, 0.4))
				p += n * 0.55 * s
			else:
				# Stuck on: its up is the wall's normal, turned at random about it.
				var up := (n + Vector3.UP * 0.25).normalized()
				var side := up.cross(Vector3.UP).normalized()
				if side.length() < 0.1:
					side = Vector3.RIGHT
				b = Basis(side, up, side.cross(up)).orthonormalized() * Basis(Vector3.UP, rng.randf() * TAU)
				p -= n * 0.15 * s
			_add(placed[k], Transform3D(b.scaled(Vector3.ONE * s), p))
		# Floor: along the foot of this cliff's wall and round its tunnels.
		for i in (260 if canyon else 140):
			var z := rng.randf_range(-span, span)
			var out := rng.randf_range(1.0, 14.0 if canyon else 18.0)
			var base := cliffs.face_point(cid, 0.0, z)
			var n0 := cliffs.face_normal(cid, 1.0, z)
			n0.y = 0.0
			var p := base + n0.normalized() * out
			p.y = cliffs.floor_height(p.x, p.z)
			if canyon and absf(p.x) > WorldLayout.HALF_GAP - 1.0:
				continue
			if by_mouth.call(p, 8.0) or SitePlan.in_site_zone(p, 2.5) or (canyon and absf(z - Buildable.ROPE_ANCHOR_Z) < 6.0 and out < 9.0):
				continue
			if canyon and absf(z) > WorldLayout.WORLD_HALF_Z - 4.0:
				continue
			var keep: float = 0.4 + hive_at.call(p) * 0.8 - out * 0.015
			if rng.randf() > keep:
				continue
			var k := floor_kinds[_pick(rng, floor_w)]
			var spec: Array = KINDS[k]
			var s: float = rng.randf_range(spec[2].x, spec[2].y)
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			_add(placed[k], Transform3D(b.scaled(Vector3.ONE * s), p + Vector3(0, -0.08 * s, 0)))
	# The open canyon floor between the walls: thinner, but everywhere.
	if canyon and m.count() >= 2:
		var foot := [cliffs.face_point(0, 0.0, Buildable.ROPE_ANCHOR_Z), cliffs.face_point(1, 0.0, Buildable.ROPE_ANCHOR_Z)]
		for i in 320:
			var z := rng.randf_range(-span, span)
			var t := rng.randf_range(0.15, 0.85)
			var p := cliffs.face_point(0, 0.0, z).lerp(cliffs.face_point(1, 0.0, z), t)
			p.y = cliffs.floor_height(p.x, p.z)
			if by_mouth.call(p, 8.0) or SitePlan.in_site_zone(p, 2.5) or absf(z) > WorldLayout.WORLD_HALF_Z - 4.0:
				continue
			var near_rope := false
			for f: Vector3 in foot:
				near_rope = near_rope or Vector2(p.x - f.x, p.z - f.z).length() < 9.0
			if near_rope or rng.randf() > 0.3 + float(hive_at.call(p)) * 0.4:
				continue
			var k := floor_kinds[_pick(rng, floor_w)]
			var spec: Array = KINDS[k]
			var s: float = rng.randf_range(spec[2].x, spec[2].y)
			_add(placed[k], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p + Vector3(0, -0.08 * s, 0)))
	var level := GraphicsQuality.level(Settings.effects)
	for k: StringName in KINDS:
		var path := DIR + String(k) + ".glb"
		var mesh := AiModels.mesh(path)
		var mat := AiModels.material(path, 0.012)
		var chunks: Dictionary = placed[k]
		for key: int in chunks:
			var xs: Array = chunks[key]
			if xs.is_empty():
				continue
			xs.shuffle() # so a shorter visible count still spreads out
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Infest_%s_%d" % [k, key]
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
			_batches.append(mmi)
			_counts.append(xs.size())
	set_detail(level)
	_drips(parent, mouths)


## Resin drips (assets/fx/drip.png) falling slowly from the rock over each tunnel
## mouth: a few cheap CPU particles each, none on Low.
static func _drips(parent: Node3D, mouths: Array[Vector3]) -> void:
	if not ResourceLoader.exists("res://assets/fx/drip.png") or GraphicsQuality.level(Settings.effects) == 0:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.albedo_texture = load("res://assets/fx/drip.png")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.5)
	quad.material = mat
	for m in mouths:
		var p := CPUParticles3D.new()
		p.name = "ResinDrips"
		p.mesh = quad
		p.amount = 6
		p.lifetime = 2.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(2.2, 0.2, 2.2)
		p.direction = Vector3.DOWN
		p.spread = 2.0
		p.gravity = Vector3(0, -2.2, 0)
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.3
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		p.local_coords = false
		parent.add_child(p)
		p.global_position = m + Vector3(0, 6.0, 0)


static func _pick(rng: RandomNumberGenerator, w: Array[float]) -> int:
	var total := 0.0
	for x in w:
		total += x
	var r := rng.randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return w.size() - 1


static func _add(by_chunk: Dictionary, t: Transform3D) -> void:
	var key := int(floor(t.origin.z / CHUNK)) * 1000 + int(floor(t.origin.x / CHUNK))
	if not by_chunk.has(key):
		by_chunk[key] = []
	(by_chunk[key] as Array).append(t)


## Effects level (GraphicsQuality): Low draws under half of them.
static func set_detail(level: int) -> void:
	var share := SHARE[GraphicsQuality.level(level)]
	for i in _batches.size():
		if is_instance_valid(_batches[i]):
			_batches[i].multimesh.visible_instance_count = maxi(1, int(ceil(_counts[i] * share)))
