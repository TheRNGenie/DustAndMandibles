class_name TierBuilder
extends RefCounted
## Tiers: meshes for the Mid and Late turrets (Twin Gatling, Hornet's Nest,
## Elephant Battery, Rail Spike Driver, Gatling Porch Turret, Big Fifty, Brimstone
## Bellows, Cotton Bale Cannon), in the same parts
## as TurretBuilder: base (static), head (yaws), gun (pitches, barrels along -Z),
## optional spin / spin_b (barrel clusters that whirl about their own axes, in
## gun space at spin_at / spin_b_at), muzzle and an optional muzzle_b that shots
## alternate with. Built from turned (lathe) shapes, tubes and rods rather than
## plain boxes, with the frontier detail of gen/craft_builder.gd.

const ALONG := Basis(Vector3.RIGHT, PI * 0.5) # local Y -> +Z (lathe profiles in y run along z)
const ACROSS := Basis(Vector3.BACK, PI * 0.5) # local Y -> X
const BRASS := Color("#D6A74A")
const IRON := Color("#4A4E58")
const DARK_IRON := Color("#34373E")
const GUNMETAL := Color("#5C646C")
const GREASE := Color("#22201E")
const STONE := Color("#A39686")
const RUBBER := Color("#4A2A24")
const HORNET := Color("#E8B12E")
const COAL := Color("#26221F")
const STEAM_RED := Color("#8E2F22")

const IDS: Array[StringName] = [&"twin_gatling", &"hornets_nest", &"elephant_battery", &"rail_spike_driver", &"gatling_porch",
	&"big_fifty", &"brimstone_bellows", &"cotton_bale_cannon"] # (the last three close the Buffalo, sulfur and cotton lines)
const SULFUR := Color("#D9C23A")
const COTTON := Color("#EFE8D6")
const BRICK := Color("#8C4A36")
const LEATHER := Color("#6B4528")
const ROPE := Color("#B8955A")


static func has(id: StringName) -> bool:
	return IDS.has(id)


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"hornets_nest":
			return _hornets_nest(team)
		&"elephant_battery":
			return _elephant_battery(team)
		&"rail_spike_driver":
			return _rail_spike_driver(team)
		&"gatling_porch":
			return _gatling_porch(team)
		&"big_fifty":
			return _big_fifty(team)
		&"brimstone_bellows":
			return _brimstone_bellows(team)
		&"cotton_bale_cannon":
			return _cotton_bale_cannon(team)
	return _twin_gatling(team)


# ------------------------------------------------------------------ shared pieces

static func _t(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: Vector2, color: Color, rng: RandomNumberGenerator = null) -> void:
	CraftBuilder._beam(st, a, b, w, color, rng)


static func _rod(st: SurfaceTool, a: Vector3, b: Vector3, r: float, color: Color, segs: int = 5) -> void:
	CraftBuilder._rod(st, a, b, r, color, segs)


static func _hoop(st: SurfaceTool, c: Vector3, axis: Vector3, r: float, thick: float, color: Color, segs: int = 12) -> void:
	CraftBuilder._hoop(st, c, axis, r, thick, color, segs)


## A ring of brass rivet heads round `c` in the plane normal to `axis`.
static func _rivet_ring(st: SurfaceTool, c: Vector3, axis: Vector3, r: float, n: int, size: float = 0.02) -> void:
	var bas := MeshKit.basis_from_y(axis)
	for i in n:
		var a := TAU * float(i) / n
		MeshKit.add_ellipsoid(st, _t(c + bas * (Vector3(cos(a), 0, sin(a)) * r)), Vector3.ONE * size, 2, 5, BRASS)


## A plank deck of `n` boards across X, with two iron straps and nail heads.
static func _deck(st: SurfaceTool, rng: RandomNumberGenerator, size: Vector3, n: int, y: float = 0.0) -> void:
	var w := size.x / n
	for i in n:
		MeshKit.add_box(st, _t(Vector3(-size.x * 0.5 + w * (i + 0.5), y + size.y * 0.5, 0)),
				Vector3(w * 0.93, size.y * (0.9 + rng.randf() * 0.2), size.z * (0.96 + rng.randf() * 0.06)),
				Palette.WOOD.darkened(rng.randf() * 0.16), 0.015, rng)
	for z: float in [-size.z * 0.36, size.z * 0.36]:
		MeshKit.add_box(st, _t(Vector3(0, y + size.y + 0.006, z)), Vector3(size.x * 0.98, 0.012, 0.07), IRON)
		for i in n:
			MeshKit.add_ellipsoid(st, _t(Vector3(-size.x * 0.5 + w * (i + 0.5), y + size.y + 0.014, z)), Vector3(0.016, 0.01, 0.016), 2, 5, BRASS)


## A burlap sandbag lying round the base (yaw `a`, at `p`).
static func _sandbag(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3, a: float, s: float = 1.0) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.17, 0.13, 0.28) * s, 4, 8,
			Palette.SAND.darkened(0.14 + rng.randf() * 0.12), 0.08, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, -a), p + Basis(Vector3.UP, -a) * Vector3(0, 0.02, 0.27 * s)), Vector3(0.06, 0.05, 0.05) * s, 3, 6, Palette.SAND.darkened(0.3))


## A cast-iron pedestal (turned), its base flange bolted down, and a greased race on top at `top`.
static func _pedestal(st: SurfaceTool, top: float, r: float) -> void:
	MeshKit.lathe(st, _t(Vector3.ZERO), [Vector2(r * 1.7, 0.0), Vector2(r * 1.7, 0.05), Vector2(r * 1.3, 0.08),
			Vector2(r, top * 0.25), Vector2(r * 0.86, top * 0.6), Vector2(r * 0.95, top * 0.85), Vector2(r * 1.5, top * 0.94),
			Vector2(r * 1.6, top)], 14, DARK_IRON)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.26
		var p := Vector3(cos(a), 0.0, sin(a)) * r * 1.48
		MeshKit.add_cylinder(st, _t(p + Vector3(0, 0.07, 0)), 0.03, 0.03, 0.05, 6, IRON.lightened(0.15))
		MeshKit.add_cylinder(st, _t(p + Vector3(0, 0.1, 0)), 0.014, 0.014, 0.04, 5, BRASS)
	MeshKit.add_cylinder(st, _t(Vector3(0, top + 0.012, 0)), r * 1.62, r * 1.62, 0.024, 16, GREASE)


## A wooden ammo box with rope handles, a stencilled band and a brass hasp.
static func _ammo_box(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, size: Vector3, turn: float, band: Color) -> void:
	var b := Basis(Vector3.UP, turn)
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, size.y * 0.5, 0)), size, Palette.WOOD, 0.012, rng)
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, size.y + 0.015, 0)), Vector3(size.x * 1.04, 0.03, size.z * 1.04), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(b, at + b * Vector3(0, size.y * 0.5, -size.z * 0.505)), Vector3(size.x * 0.6, size.y * 0.32, 0.008), band)
	MeshKit.add_box(st, Transform3D(b, at + b * Vector3(0, size.y * 0.9, -size.z * 0.51)), Vector3(0.04, 0.06, 0.012), BRASS)
	for s: float in [-1.0, 1.0]:
		var c := at + b * Vector3(s * size.x * 0.52, size.y * 0.62, 0)
		_hoop(st, c, b * Vector3.RIGHT, 0.045, 0.01, Color("#B8955A"), 8)
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(b, at + b * Vector3(s * size.x * 0.5, size.y * 0.5, e * size.z * 0.5)), Vector3(0.03, size.y * 1.01, 0.03), IRON)


## A belt of brass cartridges hanging along `pts` (a sagging feed belt).
static func _belt(st: SurfaceTool, pts: Array, n: int) -> void:
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var seg := t * (pts.size() - 1)
		var k := mini(int(seg), pts.size() - 2)
		var p := (pts[k] as Vector3).lerp(pts[k + 1] as Vector3, seg - k)
		var dir := ((pts[k + 1] as Vector3) - (pts[k] as Vector3)).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
		MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(side), p), Vector3(0.045, 0.1, 0.03), Color("#5A4632"))
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(side), p + side * 0.03), 0.014, 0.012, 0.09, 5, BRASS)


## Six barrels round an axis (a Gatling cluster), banded, for a spin mesh centred on (cx, cy).
static func _barrel_cluster(st: SurfaceTool, cx: float, cy: float, n: int, ring: float, r: float, length: float, z0: float) -> void:
	var zc := z0 - length * 0.5
	MeshKit.add_cylinder(st, Transform3D(ALONG, Vector3(cx, cy, zc)), ring * 0.45, ring * 0.45, length * 0.98, 8, DARK_IRON) # centre rod
	for i in n:
		var a := TAU * float(i) / n
		var o := Vector3(cx + cos(a) * ring, cy + sin(a) * ring, 0)
		MeshKit.add_cylinder(st, Transform3D(ALONG, o + Vector3(0, 0, zc)), r, r, length, 7, GUNMETAL.lightened(0.08), false)
		MeshKit.add_cylinder(st, Transform3D(ALONG, o + Vector3(0, 0, z0 - length - 0.005)), r * 0.55, r * 0.55, 0.006, 6, Palette.OUTLINE) # bore
	for f: float in [0.1, 0.55, 0.96]:
		MeshKit.add_cylinder(st, Transform3D(ALONG, Vector3(cx, cy, z0 - length * f)), ring + r + 0.012, ring + r + 0.012, 0.045, 12, BRASS if f < 0.9 else IRON)


## A team pennant (shared with the other turrets).
static func _pennant(st: SurfaceTool, at: Vector3, h: float, team: Color) -> void:
	TurretBuilder._pennant(st, at, h, team)


static func _rivets(st: SurfaceTool, c: Vector3, along: Vector3, n: int, step: float, r: float = 0.022) -> void:
	TurretBuilder._rivets(st, c, along, n, step, r)


# ------------------------------------------------------------------ Twin Gatling

## Twin Gatling: two crank Gatlings yoked side by side on a cast-iron pedestal,
## one crank turning both through a linking rod, a Broadwell drum between them,
## a two-wing riveted shield, belts hanging to ammo boxes on a sandbagged deck.
static func _twin_gatling(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	var base := MeshKit.begin()
	_deck(base, rng, Vector3(1.5, 0.1, 1.5), 6)
	for i in 7: # sandbags round the back half
		var a := PI * 0.15 + PI * 0.7 * float(i) / 6.0
		_sandbag(base, rng, Vector3(cos(a) * 0.62, 0.22, sin(a) * 0.62), a + PI * 0.5, 0.9)
	_pedestal(base, 1.05, 0.13)
	_ammo_box(base, rng, Vector3(0.5, 0.1, 0.4), Vector3(0.36, 0.24, 0.26), 0.35, BRASS)
	_ammo_box(base, rng, Vector3(-0.48, 0.1, 0.42), Vector3(0.34, 0.22, 0.26), -0.25, team)
	_belt(base, [Vector3(0.48, 0.38, 0.32), Vector3(0.3, 0.3, 0.18), Vector3(0.18, 0.52, 0.08)], 7)
	_pennant(base, Vector3(-0.66, 0.1, -0.5), 1.7, team)
	var head := MeshKit.begin()
	# Turntable, a broad yoke with cheek arms, and the split shield.
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.26, 0.26, 0.05, 16, IRON.lightened(0.1))
	_rivet_ring(head, Vector3(0, 0.05, 0), Vector3.UP, 0.22, 10, 0.016)
	MeshKit.add_box(head, _t(Vector3(0, 0.1, 0.02)), Vector3(0.82, 0.08, 0.24), DARK_IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, _t(Vector3(s * 0.43, 0.17, 0.02)), Vector3(0.05, 0.22, 0.18), DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.46, 0.2, 0.02)), 0.05, 0.05, 0.03, 10, BRASS)
	# The shield: one riveted plate with a port for each barrel cluster, its
	# outer leaves bent back, a team band across the top; braced to the yoke.
	var plate := Palette.METAL.darkened(0.2)
	var sz := -0.2
	MeshKit.add_box(head, _t(Vector3(0, 0.47, sz)), Vector3(0.74, 0.24, 0.04), plate) # over the ports
	MeshKit.add_box(head, _t(Vector3(0, 0.07, sz)), Vector3(0.74, 0.06, 0.04), plate) # under them
	MeshKit.add_box(head, _t(Vector3(0, 0.22, sz)), Vector3(0.1, 0.26, 0.04), plate) # the bar between
	MeshKit.add_box(head, _t(Vector3(0, 0.52, sz - 0.025)), Vector3(0.74, 0.07, 0.01), team)
	for s: float in [-1.0, 1.0]:
		var leaf := Basis(Vector3.UP, s * 0.5)
		var c := Vector3(s * 0.37, 0.0, sz) + leaf * Vector3(s * 0.12, 0.0, 0.0)
		MeshKit.add_box(head, Transform3D(leaf, c + Vector3(0, 0.3, 0)), Vector3(0.24, 0.6, 0.04), plate)
		for y: float in [0.08, 0.3, 0.52]:
			MeshKit.add_ellipsoid(head, _t(c + Vector3(0, y, 0) + leaf * Vector3(0, 0, -0.025)), Vector3.ONE * 0.016, 2, 5, BRASS)
		# Port rims round the barrels.
		_hoop(head, Vector3(s * 0.22, 0.2, sz - 0.025), Vector3.BACK, 0.14, 0.014, IRON.lightened(0.15), 14)
		_beam(head, Vector3(s * 0.43, 0.12, 0.0), Vector3(s * 0.43, 0.42, sz + 0.03), Vector2(0.03, 0.03), IRON)
	for k in 7:
		MeshKit.add_ellipsoid(head, _t(Vector3(-0.33 + k * 0.11, 0.41, sz - 0.025)), Vector3.ONE * 0.015, 2, 5, BRASS)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.035, 0.035, 0.9, 8, IRON) # trunnion bar
	for s: float in [-1.0, 1.0]:
		var x := s * 0.22
		# Breech housing (turned), brass front ring, rear knob.
		MeshKit.lathe(gun, Transform3D(ALONG, Vector3(x, 0, 0)), [Vector2(0.0, 0.36), Vector2(0.06, 0.35), Vector2(0.12, 0.3),
				Vector2(0.13, 0.12), Vector2(0.13, -0.08), Vector2(0.15, -0.1)], 12, GUNMETAL.darkened(0.15))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, -0.1)), 0.15, 0.15, 0.04, 12, BRASS)
		MeshKit.add_ellipsoid(gun, _t(Vector3(x, 0, 0.38)), Vector3.ONE * 0.035, 3, 6, BRASS)
		# Feed slot on top, from the shared drum.
		MeshKit.add_box(gun, _t(Vector3(x * 0.6, 0.15, 0.08)), Vector3(0.12, 0.06, 0.12), DARK_IRON)
	# The Broadwell drum between them, ribbed.
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.22, 0.08)), 0.2, 0.2, 0.1, 18, BRASS.darkened(0.2))
	for k in 10:
		var a := TAU * float(k) / 10.0
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.2, 0.22, 0.08 + sin(a) * 0.2)), Vector3(0.02, 0.1, 0.03), IRON)
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.285, 0.08)), 0.05, 0.05, 0.03, 10, IRON)
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.31, 0.08)), 0.015, 0.015, 0.04, 5, BRASS)
	# One crank on the right, a linking rod across the backs so both turn together.
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.4, 0, 0.18)), 0.03, 0.03, 0.14, 6, IRON)
	_rod(gun, Vector3(0.47, 0, 0.18), Vector3(0.47, -0.16, 0.22), 0.018, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.53, -0.16, 0.22)), 0.03, 0.03, 0.1, 6, Palette.WOOD)
	_rod(gun, Vector3(-0.22, 0.1, 0.2), Vector3(0.22, 0.1, 0.2), 0.016, BRASS, 5)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(s * 0.22, 0.1, 0.2)), 0.035, 0.035, 0.03, 8, IRON)
	# Spade grips out back.
	for s: float in [-1.0, 1.0]:
		_rod(gun, Vector3(s * 0.08, -0.02, 0.36), Vector3(s * 0.12, -0.06, 0.52), 0.018, IRON, 4)
		MeshKit.add_cylinder(gun, _t(Vector3(s * 0.12, -0.06, 0.54)), 0.028, 0.028, 0.13, 6, Palette.WOOD_DARK)
	var spin := MeshKit.begin()
	_barrel_cluster(spin, 0.0, 0.0, 6, 0.08, 0.026, 0.85, 0.0)
	var spin_b := MeshKit.begin()
	_barrel_cluster(spin_b, 0.0, 0.0, 6, 0.08, 0.026, 0.85, 0.0)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(-0.22, 0, -0.12),
			"spin_b": MeshKit.finish(spin_b), "spin_b_at": Vector3(0.22, 0, -0.12), "recoil": 0.03,
			"head_y": 1.08, "gun_y": 0.2, "muzzle": Vector3(-0.22, 0, -0.98), "muzzle_b": Vector3(0.22, 0, -0.98)}


# ------------------------------------------------------------------ Hornet's Nest

## Hornet's Nest: a fat drum of a dozen short barrels painted in hornet bands,
## spun by a clockwork mainspring housing and fed from a shot hopper full of
## lead balls, on a log-crib tower with a turntable.
static func _hornets_nest(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1102
	var base := MeshKit.begin()
	# Log crib: courses of round logs crossing each other, notched at the corners.
	for course in 5:
		var y := 0.1 + course * 0.17
		var across := course % 2 == 0
		for s: float in [-1.0, 1.0]:
			var p := Vector3(0, y, s * 0.5) if across else Vector3(s * 0.5, y, 0)
			var bas := ACROSS if across else ALONG
			MeshKit.add_cylinder(base, Transform3D(bas, p), 0.095, 0.09, 1.3 + rng.randf() * 0.08, 9, Palette.WOOD.darkened(0.05 + rng.randf() * 0.15))
			var end := Vector3(0.66, y, s * 0.5) if across else Vector3(s * 0.5, y, 0.66)
			MeshKit.add_cylinder(base, Transform3D(bas, end), 0.08, 0.08, 0.01, 9, Palette.SAND.darkened(0.1)) # cut end
	MeshKit.add_box(base, _t(Vector3(0, 0.92, 0)), Vector3(1.1, 0.06, 1.1), Palette.WOOD_DARK, 0.015, rng)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.98, 0)), 0.42, 0.44, 0.06, 18, IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.015, 0)), 0.43, 0.43, 0.012, 18, GREASE)
	_rivet_ring(base, Vector3(0, 0.98, 0), Vector3.UP, 0.4, 12, 0.018)
	# A keg of shot and a scoop at the foot.
	MeshKit.lathe(base, _t(Vector3(0.62, 0.0, -0.55)), [Vector2(0.15, 0.0), Vector2(0.19, 0.18), Vector2(0.15, 0.36)], 12, Palette.WOOD)
	for y: float in [0.06, 0.3]:
		MeshKit.add_cylinder(base, _t(Vector3(0.62, y, -0.55)), 0.175, 0.175, 0.03, 12, IRON)
	for i in 7:
		var a := rng.randf() * TAU
		MeshKit.add_ellipsoid(base, _t(Vector3(0.62 + cos(a) * rng.randf() * 0.09, 0.37, -0.55 + sin(a) * rng.randf() * 0.09)), Vector3.ONE * 0.035, 3, 6, IRON.darkened(0.3))
	_pennant(base, Vector3(-0.62, 1.0, 0.45), 1.3, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.03, 0)), 0.38, 0.38, 0.06, 18, IRON.lightened(0.1))
	for i in 14:
		var a := TAU * float(i) / 14.0
		MeshKit.add_box(head, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.39, 0.03, sin(a) * 0.39)), Vector3(0.035, 0.05, 0.035), IRON)
	# Two curved cast cheeks (A-frames) carrying the drum's trunnions.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.42
		MeshKit.lathe(head, Transform3D(Basis(Vector3.BACK, 0.0), Vector3(x, 0.06, 0)), [Vector2(0.16, 0.0), Vector2(0.11, 0.12), Vector2(0.07, 0.32), Vector2(0.09, 0.4)], 8, DARK_IRON, Vector2(0.4, 1.0))
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x, 0.46, 0)), 0.1, 0.1, 0.06, 12, DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x + s * 0.035, 0.46, 0)), 0.05, 0.05, 0.03, 10, BRASS)
	MeshKit.add_box(head, _t(Vector3(0, 0.12, 0.3)), Vector3(0.5, 0.06, 0.02), team)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.045, 0.045, 0.84, 8, IRON)
	# Clockwork housing behind the drum: a domed mainspring case with a key.
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, 0, 0.0)), [Vector2(0.0, 0.42), Vector2(0.1, 0.41), Vector2(0.2, 0.36),
			Vector2(0.25, 0.26), Vector2(0.26, 0.1), Vector2(0.28, 0.06), Vector2(0.28, 0.02)], 16, GUNMETAL.darkened(0.2))
	_hoop(gun, Vector3(0, 0, 0.18), Vector3.BACK, 0.262, 0.014, BRASS, 16)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.46)), 0.025, 0.025, 0.1, 6, IRON) # winding key
	MeshKit.add_box(gun, _t(Vector3(0, 0, 0.52)), Vector3(0.2, 0.05, 0.02), BRASS)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(gun, _t(Vector3(s * 0.11, 0, 0.52)), Vector3(0.05, 0.035, 0.015), 3, 8, BRASS)
	# The shot hopper: a riveted funnel on top, heaped with lead balls.
	MeshKit.lathe(gun, _t(Vector3(0, 0.22, 0.1)), [Vector2(0.06, 0.0), Vector2(0.08, 0.06), Vector2(0.2, 0.22), Vector2(0.22, 0.26)], 12, IRON.lightened(0.05))
	_hoop(gun, Vector3(0, 0.48, 0.1), Vector3.UP, 0.22, 0.014, BRASS, 14)
	for i in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.17
		MeshKit.add_ellipsoid(gun, _t(Vector3(cos(a) * r, 0.47 + (0.17 - r) * 0.25 + rng.randf() * 0.02, 0.1 + sin(a) * r)), Vector3.ONE * 0.034, 3, 6, Color("#55575C"))
	# A side crank wheel for winding.
	var hw := Vector3(-0.32, 0.0, 0.14)
	_hoop(gun, hw, Vector3.RIGHT, 0.13, 0.016, BRASS.darkened(0.1), 14)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_rod(gun, hw, hw + Vector3(0, cos(a), sin(a)) * 0.12, 0.01, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, hw + Vector3(-0.05, 0.1, 0)), 0.018, 0.018, 0.1, 6, Palette.WOOD)
	# The drum spins: a banded hornet-striped barrel drum and a dozen short barrels.
	var spin := MeshKit.begin()
	MeshKit.lathe(spin, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.06, 0.0), Vector2(0.27, -0.01), Vector2(0.3, -0.06),
			Vector2(0.31, -0.3), Vector2(0.29, -0.5), Vector2(0.22, -0.54), Vector2(0.08, -0.55)], 18, COAL)
	for k in 4:
		var z := -0.1 - k * 0.11
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, z)), 0.312, 0.31 - (0.02 if k == 3 else 0.0), 0.055, 18, HORNET)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var o := Vector3(cos(a) * 0.21, sin(a) * 0.21, 0)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, o + Vector3(0, 0, -0.68)), 0.034, 0.03, 0.32, 7, GUNMETAL.lightened(0.1), false)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, o + Vector3(0, 0, -0.83)), 0.042, 0.042, 0.03, 7, BRASS)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, o + Vector3(0, 0, -0.847)), 0.018, 0.018, 0.004, 6, Palette.OUTLINE)
	MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, -0.6)), 0.08, 0.08, 0.14, 12, IRON)
	MeshKit.add_ellipsoid(spin, _t(Vector3(0, 0, -0.68)), Vector3(0.06, 0.06, 0.06), 4, 10, BRASS)
	# A stinger spike at the hub.
	MeshKit.add_cylinder(spin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.78)), 0.04, 0.0, 0.16, 8, COAL)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0, -0.02), "recoil": 0.02,
			"head_y": 1.02, "gun_y": 0.46, "muzzle": Vector3(0, 0, -0.9)}


# ------------------------------------------------------------------ Elephant Battery

## Elephant Battery: a side-by-side double rifle of enormous bore (two octagonal
## barrels on a rib, exposed hammers, express sights) on a timber sledge with
## iron-shod runners, a box of fat brass cartridges and a curved gun shield.
static func _elephant_battery(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1103
	var base := MeshKit.begin()
	# Sledge: two runners curling up at the front, cross-ties, and a plank bed.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.52
		MeshKit.tube(base, [Vector3(x, 0.07, 0.7), Vector3(x, 0.06, 0.1), Vector3(x, 0.07, -0.45), Vector3(x, 0.15, -0.68), Vector3(x, 0.3, -0.74)],
				[0.07, 0.07, 0.07, 0.065, 0.06], 7, Palette.WOOD_DARK)
		MeshKit.tube(base, [Vector3(x, 0.0, 0.7), Vector3(x, -0.005, 0.1), Vector3(x, 0.0, -0.45), Vector3(x, 0.08, -0.7)], [0.035], 5, IRON)
	for z: float in [-0.4, 0.0, 0.4]:
		MeshKit.add_box(base, _t(Vector3(0, 0.15, z)), Vector3(1.2, 0.08, 0.12), Palette.WOOD.darkened(0.1), 0.012, rng)
	for i in 5:
		MeshKit.add_box(base, _t(Vector3(-0.4 + i * 0.2, 0.22, 0.05)), Vector3(0.18, 0.05, 1.1), Palette.WOOD.darkened(rng.randf() * 0.14), 0.012, rng)
	# Timber gun bed: squared beams cribbed crosswise, iron dogs at the corners,
	# the pivot cup on top.
	for course in 4:
		var y := 0.31 + course * 0.115
		for s: float in [-1.0, 1.0]:
			var along_x := course % 2 == 0
			var p := Vector3(0, y, s * 0.23) if along_x else Vector3(s * 0.23, y, 0)
			var size := Vector3(0.7, 0.11, 0.15) if along_x else Vector3(0.15, 0.11, 0.7)
			MeshKit.add_box(base, _t(p), size, Palette.WOOD.darkened(0.04 + rng.randf() * 0.14), 0.01, rng)
			var end := p + (Vector3(0.351, 0, 0) if along_x else Vector3(0, 0, 0.351))
			MeshKit.add_box(base, _t(end), Vector3(0.004, 0.09, 0.12) if along_x else Vector3(0.12, 0.09, 0.004), Palette.SAND.darkened(0.15))
	for x: float in [-0.23, 0.23]:
		for z: float in [-0.23, 0.23]:
			_beam(base, Vector3(x * 1.05, 0.32, z * 1.05), Vector3(x * 1.05, 0.66, z * 1.05), Vector2(0.03, 0.03), IRON)
	MeshKit.add_box(base, _t(Vector3(0, 0.73, 0)), Vector3(0.6, 0.04, 0.6), Palette.WOOD_DARK, 0.01, rng)
	MeshKit.lathe(base, _t(Vector3(0, 0.75, 0)), [Vector2(0.26, 0.0), Vector2(0.24, 0.12), Vector2(0.28, 0.16)], 14, DARK_IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.92, 0)), 0.27, 0.27, 0.012, 14, GREASE)
	# Cartridge box with fat brass rounds stood up in it.
	_ammo_box(base, rng, Vector3(0.38, 0.25, 0.48), Vector3(0.36, 0.16, 0.24), 0.0, Color("#B8352A"))
	for i in 6:
		var p := Vector3(0.26 + (i % 3) * 0.12, 0.47, 0.42 + (i / 3) * 0.11)
		MeshKit.add_cylinder(base, _t(p), 0.03, 0.028, 0.16, 8, BRASS)
		MeshKit.add_cylinder(base, _t(p + Vector3(0, 0.1, 0)), 0.026, 0.0, 0.06, 8, Color("#8A8F96"))
	_pennant(base, Vector3(-0.5, 0.25, 0.6), 1.5, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.26, 0.26, 0.05, 14, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.08, 0.05)), Vector3(0.56, 0.08, 0.36), Palette.WOOD_DARK, 0.01, rng)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, _t(Vector3(s * 0.25, 0.17, 0.0)), Vector3(0.05, 0.2, 0.16), DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.28, 0.2, 0)), 0.045, 0.045, 0.03, 10, BRASS)
	# A curved shield bent round the front: a low apron under the barrels and two
	# tall ears either side, so the barrels ride in the slot between.
	for k in 5:
		var a := (float(k) - 2.0) * 0.36
		var ear := k == 0 or k == 4
		var h := 0.5 if ear else 0.13
		var p := Vector3(sin(a) * 0.5, h * 0.5 + 0.02, -cos(a) * 0.5 + 0.22)
		var bas := Basis(Vector3.UP, -a)
		MeshKit.add_box(head, Transform3D(bas, p), Vector3(0.19, h, 0.04), Palette.METAL.darkened(0.22))
		MeshKit.add_ellipsoid(head, _t(p + bas * Vector3(0, -h * 0.35, -0.025)), Vector3.ONE * 0.015, 2, 5, BRASS)
		if ear:
			MeshKit.add_box(head, Transform3D(bas, p + bas * Vector3(0, h * 0.36, -0.024)), Vector3(0.19, 0.06, 0.01), team)
			MeshKit.add_ellipsoid(head, _t(p + bas * Vector3(0, h * 0.1, -0.025)), Vector3.ONE * 0.015, 2, 5, BRASS)
		else:
			MeshKit.add_box(head, Transform3D(bas, p + bas * Vector3(0, h * 0.5 + 0.01, 0)), Vector3(0.2, 0.025, 0.06), IRON) # rolled lip
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.04, 0.04, 0.5, 8, IRON)
	# Action body, side plates with brass scroll, two exposed hammers.
	MeshKit.add_box(gun, _t(Vector3(0, 0.0, 0.12)), Vector3(0.26, 0.16, 0.34), DARK_IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, _t(Vector3(s * 0.131, 0.0, 0.16)), Vector3(0.006, 0.12, 0.24), BRASS.darkened(0.1))
		MeshKit.add_ellipsoid(gun, _t(Vector3(s * 0.134, 0.0, 0.16)), Vector3(0.006, 0.04, 0.06), 3, 6, BRASS)
		MeshKit.tube(gun, [Vector3(s * 0.07, 0.07, 0.26), Vector3(s * 0.07, 0.15, 0.24), Vector3(s * 0.07, 0.17, 0.17)], [0.022, 0.018, 0.026], 5, IRON.lightened(0.2))
	# Wrist and a big stock with a brass butt plate and a recoil pad.
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, -0.04, 0)), [Vector2(0.07, 0.29), Vector2(0.06, 0.38), Vector2(0.08, 0.5),
			Vector2(0.11, 0.66), Vector2(0.12, 0.72)], 8, Palette.WOOD, Vector2(0.75, 1.15))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, -0.04, 0.74)), 0.122, 0.122, 0.04, 8, RUBBER)
	_rod(gun, Vector3(0, -0.08, 0.22), Vector3(0, -0.17, 0.3), 0.012, BRASS, 4) # trigger guard
	_rod(gun, Vector3(0, -0.17, 0.3), Vector3(0, -0.09, 0.4), 0.012, BRASS, 4)
	# Two octagonal barrels, a rib between, express sights.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.075
		MeshKit.lathe(gun, Transform3D(ALONG, Vector3(x, 0.01, 0)), [Vector2(0.075, -0.04), Vector2(0.072, -0.3), Vector2(0.06, -1.1),
				Vector2(0.056, -1.5), Vector2(0.064, -1.53), Vector2(0.064, -1.6)], 8, Palette.METAL.darkened(0.25))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0.01, -1.605)), 0.036, 0.036, 0.004, 8, Palette.OUTLINE)
	MeshKit.add_box(gun, _t(Vector3(0, 0.07, -0.78)), Vector3(0.05, 0.03, 1.5), DARK_IRON)
	for z: float in [-0.45, -1.15]:
		for s: float in [-1.0, 1.0]: # barrel bands
			MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(s * 0.075, 0.01, z)), 0.08, 0.08, 0.04, 10, BRASS.darkened(0.15))
	MeshKit.add_box(gun, _t(Vector3(0, 0.1, -1.52)), Vector3(0.016, 0.05, 0.04), BRASS) # front bead
	for k in 3: # express leaf sights
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, -0.3 * float(k)), Vector3(0, 0.1, -0.12 - k * 0.03)), Vector3(0.07, 0.05, 0.008), IRON.lightened(0.15))
	# Forend under the barrels.
	MeshKit.add_box(gun, _t(Vector3(0, -0.08, -0.45)), Vector3(0.18, 0.07, 0.5), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.16, "head_y": 0.94, "gun_y": 0.22, "muzzle": Vector3(-0.075, 0.01, -1.62), "muzzle_b": Vector3(0.075, 0.01, -1.62)}


# ------------------------------------------------------------------ Rail Spike Driver

## A railroad spike: square shank, chisel point, a hooked head. Pointing -Z,
## its head at z = +len * 0.5. Also left sticking out of pinned bugs.
static func _spike(st: SurfaceTool, at: Vector3, length: float, w: float, color: Color) -> void:
	var half := length * 0.5
	MeshKit.add_box(st, _t(at + Vector3(0, 0, 0.05 * length)), Vector3(w, w, length * 0.82), color)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI * 0.25), at + Vector3(0, 0, -half + length * 0.08)), w * 0.7, 0.0, length * 0.16, 4, color.lightened(0.15))
	MeshKit.add_box(st, _t(at + Vector3(0, w * 0.35, half - w * 0.4)), Vector3(w * 1.6, w * 1.7, w * 0.8), color.darkened(0.1))
	MeshKit.add_box(st, _t(at + Vector3(0, w * 1.1, half - w * 0.9)), Vector3(w * 1.6, w * 0.6, w * 1.2), color.darkened(0.1)) # the hook


## A loose spike for the pin effect (Turret._leave_spike): about a metre long.
static var _loose: ArrayMesh
static func loose_spike() -> ArrayMesh:
	if _loose == null:
		var st := MeshKit.begin()
		_spike(st, Vector3.ZERO, 1.1, 0.09, Color("#6F747C"))
		_loose = MeshKit.finish(st)
	return _loose


## A length of railroad rail along Z (head, web and foot), centred on `c`, rotated `roll` about Z.
static func _rail(st: SurfaceTool, c: Vector3, length: float, roll: float, color: Color) -> void:
	var b := Basis(Vector3.BACK, roll)
	MeshKit.add_box(st, Transform3D(b, c + b * Vector3(0, 0.055, 0)), Vector3(0.07, 0.04, length), color.lightened(0.12)) # head
	MeshKit.add_box(st, Transform3D(b, c), Vector3(0.022, 0.08, length), color) # web
	MeshKit.add_box(st, Transform3D(b, c + b * Vector3(0, -0.05, 0)), Vector3(0.12, 0.02, length), color) # foot


## Rail Spike Driver: a steam pile-driver turned on its side. Two lengths of rail
## make the barrel, a spike lies loaded between them, a big steam ram behind; the
## boiler that feeds it sits on railroad ties with a coal heap and a keg of spikes.
static func _rail_spike_driver(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1104
	var base := MeshKit.begin()
	# Ties (sleepers) and two short rails across them.
	for i in 5:
		MeshKit.add_box(base, _t(Vector3(0, 0.06, -0.62 + i * 0.31)), Vector3(1.5, 0.12, 0.2), Palette.WOOD_DARK.darkened(rng.randf() * 0.15), 0.02, rng)
	for s: float in [-1.0, 1.0]:
		_rail(base, Vector3(s * 0.45, 0.2, 0.0), 1.5, 0.0, IRON)
		for i in 5:
			for e: float in [-1.0, 1.0]:
				_spike(base, Vector3(s * 0.45 + e * 0.08, 0.17, -0.62 + i * 0.31), 0.1, 0.018, IRON.darkened(0.2))
	# Boiler: a riveted upright drum with a firebox door, gauge and a smokestack.
	var bc := Vector3(0.42, 0.25, 0.45)
	MeshKit.lathe(base, _t(bc), [Vector2(0.24, 0.0), Vector2(0.25, 0.06), Vector2(0.25, 0.7), Vector2(0.21, 0.8), Vector2(0.08, 0.84)], 14, STEAM_RED)
	for y: float in [0.12, 0.4, 0.66]:
		_rivet_ring(base, bc + Vector3(0, y, 0), Vector3.UP, 0.255, 12, 0.014)
		MeshKit.add_cylinder(base, _t(bc + Vector3(0, y, 0)), 0.256, 0.256, 0.025, 14, DARK_IRON)
	MeshKit.add_box(base, _t(bc + Vector3(0, 0.2, -0.24)), Vector3(0.18, 0.16, 0.03), DARK_IRON) # firebox door
	MeshKit.add_box(base, _t(bc + Vector3(0, 0.2, -0.255)), Vector3(0.12, 0.03, 0.01), Color("#FF8A3A"), 0.0, null, 0.6) # glow
	MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), bc + Vector3(-0.2, 0.55, -0.12)), 0.05, 0.05, 0.02, 10, BRASS)
	MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), bc + Vector3(-0.2, 0.55, -0.132)), 0.04, 0.04, 0.004, 10, Palette.BONE)
	MeshKit.lathe(base, _t(bc + Vector3(0, 0.82, 0)), [Vector2(0.06, 0.0), Vector2(0.06, 0.45), Vector2(0.11, 0.55), Vector2(0.12, 0.62), Vector2(0.09, 0.64)], 10, DARK_IRON)
	# Steam pipe from the boiler up into the turntable column.
	MeshKit.tube(base, [bc + Vector3(-0.18, 0.62, -0.1), Vector3(0.12, 0.85, 0.2), Vector3(0.08, 0.95, 0.06)], [0.03], 6, BRASS.darkened(0.25))
	# Turntable column: a stack of iron and a greased race.
	MeshKit.lathe(base, _t(Vector3(0, 0.22, 0)), [Vector2(0.3, 0.0), Vector2(0.18, 0.12), Vector2(0.14, 0.6), Vector2(0.24, 0.76), Vector2(0.3, 0.8)], 14, DARK_IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.03, 0)), 0.3, 0.3, 0.012, 14, GREASE)
	# Coal heap and a keg of spikes.
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.18
		MeshKit.add_ellipsoid(base, _t(Vector3(-0.48 + cos(a) * r, 0.16 + (0.18 - r) * 0.5, 0.48 + sin(a) * r)), Vector3(0.07, 0.05, 0.06) * rng.randf_range(0.8, 1.3), 3, 6, COAL, 0.2, rng)
	MeshKit.lathe(base, _t(Vector3(-0.5, 0.12, -0.45)), [Vector2(0.13, 0.0), Vector2(0.16, 0.16), Vector2(0.13, 0.32)], 12, Palette.WOOD)
	for y: float in [0.05, 0.27]:
		MeshKit.add_cylinder(base, _t(Vector3(-0.5, 0.12 + y, -0.45)), 0.15, 0.15, 0.025, 12, IRON)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var p := Vector3(-0.5 + cos(a) * 0.06, 0.5, -0.45 + sin(a) * 0.06)
		MeshKit.add_box(base, Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.15), p), Vector3(0.025, 0.24, 0.025), IRON.lightened(0.1))
		MeshKit.add_box(base, Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.15), p + Vector3(0, 0.12, 0)), Vector3(0.05, 0.03, 0.04), IRON)
	_pennant(base, Vector3(0.68, 0.12, -0.6), 1.6, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.03, 0)), 0.32, 0.32, 0.06, 16, IRON.lightened(0.1))
	_rivet_ring(head, Vector3(0, 0.065, 0), Vector3.UP, 0.27, 10, 0.016)
	# Heavy A-frame cheeks of riveted plate.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.3
		_beam(head, Vector3(x, 0.06, 0.24), Vector3(x, 0.4, 0.0), Vector2(0.05, 0.08), DARK_IRON)
		_beam(head, Vector3(x, 0.06, -0.24), Vector3(x, 0.4, 0.0), Vector2(0.05, 0.08), DARK_IRON)
		_beam(head, Vector3(x, 0.14, -0.18), Vector3(x, 0.14, 0.18), Vector2(0.045, 0.05), DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x, 0.4, 0)), 0.08, 0.08, 0.07, 12, DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x + s * 0.04, 0.4, 0)), 0.045, 0.045, 0.03, 10, BRASS)
	MeshKit.add_box(head, _t(Vector3(0, 0.12, 0.26)), Vector3(0.5, 0.05, 0.02), team)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.05, 0.05, 0.6, 8, IRON)
	# Two rails make the barrel: heads facing in, a spike between them.
	for s: float in [-1.0, 1.0]:
		_rail(gun, Vector3(s * 0.1, 0.0, -0.85), 2.0, s * PI * 0.5, GUNMETAL)
	for z: float in [-0.15, -0.8, -1.5, -1.82]: # clamps round both rails
		MeshKit.add_box(gun, _t(Vector3(0, 0.1, z)), Vector3(0.36, 0.035, 0.08), DARK_IRON)
		MeshKit.add_box(gun, _t(Vector3(0, -0.1, z)), Vector3(0.36, 0.035, 0.08), DARK_IRON)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_box(gun, _t(Vector3(s * 0.17, 0.0, z)), Vector3(0.03, 0.22, 0.08), DARK_IRON)
			MeshKit.add_ellipsoid(gun, _t(Vector3(s * 0.188, 0.07, z)), Vector3.ONE * 0.018, 2, 5, BRASS)
	_spike(gun, Vector3(0, 0.0, -0.95), 1.1, 0.08, Color("#7A8088"))
	# The steam ram: a big cylinder behind, its piston rod into the rails, valves and pipes.
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, 0, 0.0)), [Vector2(0.06, -0.1), Vector2(0.17, -0.06), Vector2(0.19, 0.0),
			Vector2(0.19, 0.6), Vector2(0.21, 0.62), Vector2(0.21, 0.68), Vector2(0.12, 0.72)], 14, STEAM_RED.darkened(0.1))
	for z: float in [0.04, 0.32, 0.58]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.2, 0.2, 0.03, 14, DARK_IRON)
	_rivet_ring(gun, Vector3(0, 0, 0.66), Vector3.BACK, 0.17, 10, 0.016)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.2)), 0.035, 0.035, 0.22, 8, Palette.METAL.lightened(0.25))
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.23, 0.36)), 0.045, 0.045, 0.08, 8, BRASS) # valve
	_hoop(gun, Vector3(0, 0.28, 0.36), Vector3.UP, 0.07, 0.01, STEAM_RED, 10)
	MeshKit.tube(gun, [Vector3(0.0, 0.2, 0.2), Vector3(0.12, 0.24, 0.3), Vector3(0.24, 0.12, 0.42), Vector3(0.2, -0.05, 0.5)], [0.025], 6, BRASS.darkened(0.25))
	# A sighting post on the rails.
	MeshKit.add_box(gun, _t(Vector3(0, 0.16, -1.82)), Vector3(0.02, 0.08, 0.02), BRASS)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.22, "head_y": 1.04, "gun_y": 0.4, "muzzle": Vector3(0, 0, -1.9)}


# ------------------------------------------------------------------ Gatling Porch Turret

## Gatling Porch Turret: a crank Gatling bolted to the house on an iron deck
## plate, a hooded shield and a long belt to a box; squat enough for the porch.
static func _gatling_porch(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1105
	var base := MeshKit.begin()
	# Iron deck plate with lag bolts, a turned pedestal, a gusset ring.
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.03, 0)), 0.5, 0.5, 0.06, 8, DARK_IRON)
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.42
		MeshKit.add_cylinder(base, _t(p + Vector3(0, 0.07, 0)), 0.032, 0.032, 0.03, 6, IRON.lightened(0.2))
		MeshKit.add_cylinder(base, _t(p + Vector3(0, 0.09, 0)), 0.012, 0.012, 0.02, 5, BRASS)
	MeshKit.lathe(base, _t(Vector3(0, 0.06, 0)), [Vector2(0.26, 0.0), Vector2(0.15, 0.08), Vector2(0.1, 0.35), Vector2(0.12, 0.55), Vector2(0.2, 0.62), Vector2(0.22, 0.66)], 14, GUNMETAL.darkened(0.2))
	for i in 4:
		var a := TAU * float(i) / 4.0
		_beam(base, Vector3(cos(a) * 0.24, 0.08, sin(a) * 0.24), Vector3(cos(a) * 0.1, 0.36, sin(a) * 0.1), Vector2(0.025, 0.06), DARK_IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.73, 0)), 0.22, 0.22, 0.01, 14, GREASE)
	_ammo_box(base, rng, Vector3(0.36, 0.06, 0.3), Vector3(0.3, 0.2, 0.22), 0.4, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.22, 0.22, 0.05, 14, IRON.lightened(0.1))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, _t(Vector3(s * 0.23, 0.13, 0.0)), Vector3(0.04, 0.22, 0.16), DARK_IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.255, 0.18, 0)), 0.04, 0.04, 0.025, 10, BRASS)
	# Hooded shield: a bent front plate and a short roof plate, riveted, team band.
	for k in 3:
		var a := (float(k) - 1.0) * 0.45
		var bas := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.08)
		var p := Vector3(sin(a) * 0.36, 0.26, -cos(a) * 0.36 + 0.06)
		MeshKit.add_box(head, Transform3D(bas, p), Vector3(0.3, 0.36 if k != 1 else 0.26, 0.035), Palette.METAL.darkened(0.2))
		MeshKit.add_box(head, Transform3D(bas, p + bas * Vector3(0, 0.15 if k != 1 else 0.1, -0.02)), Vector3(0.3, 0.05, 0.01), team)
		for e: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(head, _t(p + bas * Vector3(e * 0.12, -0.14 if k != 1 else -0.09, -0.02)), Vector3.ONE * 0.013, 2, 5, BRASS)
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.46, -0.18)), Vector3(0.62, 0.03, 0.3), Palette.METAL.darkened(0.25))
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.03, 0.03, 0.5, 8, IRON)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.0, 0.32), Vector2(0.06, 0.31), Vector2(0.11, 0.26),
			Vector2(0.12, 0.08), Vector2(0.12, -0.08), Vector2(0.14, -0.1)], 12, GUNMETAL.darkened(0.15))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.1)), 0.14, 0.14, 0.035, 12, BRASS)
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0, 0.34)), Vector3.ONE * 0.03, 3, 6, BRASS)
	# Side feed from the belt, a crank, spade grips.
	MeshKit.add_box(gun, _t(Vector3(-0.15, 0.04, 0.06)), Vector3(0.08, 0.08, 0.1), DARK_IRON)
	_belt(gun, [Vector3(-0.19, 0.04, 0.06), Vector3(-0.3, -0.12, 0.12), Vector3(-0.25, -0.35, 0.2)], 6)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.18, 0, 0.14)), 0.026, 0.026, 0.1, 6, IRON)
	_rod(gun, Vector3(0.23, 0, 0.14), Vector3(0.23, -0.12, 0.18), 0.016, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.28, -0.12, 0.18)), 0.026, 0.026, 0.08, 6, Palette.WOOD)
	for s: float in [-1.0, 1.0]:
		_rod(gun, Vector3(s * 0.06, -0.02, 0.3), Vector3(s * 0.1, -0.05, 0.44), 0.016, IRON, 4)
		MeshKit.add_cylinder(gun, _t(Vector3(s * 0.1, -0.05, 0.46)), 0.024, 0.024, 0.11, 6, Palette.WOOD_DARK)
	var spin := MeshKit.begin()
	_barrel_cluster(spin, 0.0, 0.0, 6, 0.075, 0.024, 0.7, 0.0)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0, -0.12), "recoil": 0.03,
			"head_y": 0.78, "gun_y": 0.18, "muzzle": Vector3(0, 0, -0.84)}


# ------------------------------------------------------------------ Big Fifty

## Big Fifty (Mid, Buffalo line): a heavy .50 buffalo gun laid on a timber
## crutch. Base: a split-log platform on sandbags with a cartridge belt and a
## folded buffalo robe. Head: a forked iron rest on a swivel post. Gun: a long
## octagonal barrel, a case-hardened action with a side hammer, double set
## triggers, a buckhorn rear sight and a tall tang peep sight.
static func _big_fifty(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	var base := MeshKit.begin()
	# Split-log deck on two sleepers, iron dogs pinning the ends.
	for z: float in [-0.36, 0.36]:
		MeshKit.add_box(base, _t(Vector3(0, 0.06, z)), Vector3(1.15, 0.12, 0.16), Palette.WOOD_DARK.darkened(rng.randf() * 0.12), 0.015, rng)
	for i in 5:
		var x := -0.44 + i * 0.22
		MeshKit.add_cylinder(base, Transform3D(ALONG, Vector3(x, 0.19, 0)), 0.1, 0.1, 1.0, 7, Palette.WOOD.darkened(rng.randf() * 0.15))
		for z: float in [-0.36, 0.36]:
			MeshKit.add_box(base, _t(Vector3(x, 0.29, z)), Vector3(0.03, 0.02, 0.09), IRON)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		_sandbag(base, rng, Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), a + PI * 0.5, 0.9)
	# Swivel post: a turned oak post in an iron collar.
	MeshKit.lathe(base, _t(Vector3(0, 0.29, 0)), [Vector2(0.17, 0.0), Vector2(0.15, 0.05), Vector2(0.1, 0.1),
			Vector2(0.09, 0.5), Vector2(0.12, 0.56), Vector2(0.13, 0.62)], 12, Palette.WOOD)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.36, 0)), 0.165, 0.165, 0.06, 12, IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.92, 0)), 0.14, 0.14, 0.02, 12, GREASE)
	_rivet_ring(base, Vector3(0, 0.36, 0), Vector3.UP, 0.165, 8)
	# A cartridge belt over the logs and a folded buffalo robe at the back.
	_belt(base, [Vector3(-0.5, 0.3, 0.2), Vector3(-0.2, 0.31, 0.32), Vector3(0.1, 0.3, 0.4), Vector3(0.45, 0.29, 0.3)], 12)
	MeshKit.add_ellipsoid(base, _t(Vector3(0.28, 0.36, 0.3)), Vector3(0.26, 0.08, 0.17), 4, 9, Color("#4E3524"), 0.05, rng)
	MeshKit.add_ellipsoid(base, _t(Vector3(0.28, 0.42, 0.3)), Vector3(0.2, 0.05, 0.13), 3, 8, Color("#5E4330"), 0.05, rng)
	_ammo_box(base, rng, Vector3(-0.4, 0.29, 0.3), Vector3(0.26, 0.13, 0.18), 0.3, Color("#2F4A6B"))
	_pennant(base, Vector3(-0.52, 0.29, -0.3), 1.3, team)
	# Head: the forked rest, its jaws lined with rawhide.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.15, 0.15, 0.05, 12, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.07, 0)), Vector3(0.36, 0.06, 0.2), DARK_IRON)
	for sx: float in [-1.0, 1.0]:
		MeshKit.tube(head, [Vector3(sx * 0.16, 0.07, 0), Vector3(sx * 0.17, 0.16, 0), Vector3(sx * 0.13, 0.24, 0)], [0.03, 0.028, 0.025], 6, IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(sx * 0.14, 0.2, 0)), 0.04, 0.04, 0.03, 10, BRASS)
	MeshKit.add_box(head, _t(Vector3(0, 0.1, 0.1)), Vector3(0.08, 0.04, 0.12), LEATHER)
	# Gun: the rifle, pivoting on the trunnion between the forks.
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.03, 0.03, 0.3, 8, IRON)
	# Receiver: case-hardened (mottled), a side hammer and a lever under it.
	MeshKit.add_box(gun, _t(Vector3(0, 0.0, 0.14)), Vector3(0.11, 0.12, 0.28), GUNMETAL.darkened(0.15))
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			MeshKit.add_ellipsoid(gun, _t(Vector3(sx * 0.056, -0.02 + k * 0.03, 0.08 + k * 0.05)), Vector3(0.004, 0.02, 0.03), 2, 5, Color("#6F5A7A").lerp(BRASS, 0.3 * k))
	MeshKit.tube(gun, [Vector3(0.05, 0.05, 0.25), Vector3(0.05, 0.11, 0.23), Vector3(0.05, 0.13, 0.17)], [0.016, 0.014, 0.02], 5, IRON.lightened(0.2))
	_rod(gun, Vector3(0, -0.07, 0.2), Vector3(0, -0.15, 0.3), 0.011, IRON, 4)
	_rod(gun, Vector3(0, -0.15, 0.3), Vector3(0, -0.08, 0.38), 0.011, IRON, 4)
	for k in 2: # double set triggers
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, -0.09, 0.26 + k * 0.04)), Vector3(0.012, 0.05, 0.008), BRASS)
	# Stock: a long walnut buttstock with a crescent butt plate and patch box.
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, -0.03, 0)), [Vector2(0.05, 0.28), Vector2(0.045, 0.36), Vector2(0.07, 0.5),
			Vector2(0.095, 0.66), Vector2(0.1, 0.72)], 8, Palette.WOOD.darkened(0.12), Vector2(0.7, 1.2))
	MeshKit.add_box(gun, _t(Vector3(0, -0.03, 0.735)), Vector3(0.075, 0.24, 0.025), BRASS.darkened(0.1))
	MeshKit.add_box(gun, _t(Vector3(0.05, -0.03, 0.58)), Vector3(0.006, 0.06, 0.12), BRASS)
	# Barrel: heavy octagonal, a little taper, the bore dark at the mouth.
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, 0.02, 0)), [Vector2(0.058, -0.0), Vector2(0.056, -0.3), Vector2(0.05, -1.2),
			Vector2(0.047, -1.66), Vector2(0.052, -1.69), Vector2(0.052, -1.74)], 8, Palette.METAL.darkened(0.3))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.02, -1.745)), 0.026, 0.026, 0.004, 8, Palette.OUTLINE)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.02, -0.62)), 0.06, 0.06, 0.04, 10, BRASS.darkened(0.2))
	# Forend and the ramrod under the barrel.
	MeshKit.add_box(gun, _t(Vector3(0, -0.045, -0.3)), Vector3(0.1, 0.06, 0.48), Palette.WOOD.darkened(0.1))
	_rod(gun, Vector3(0, -0.07, -0.05), Vector3(0, -0.06, -1.3), 0.01, Palette.WOOD_DARK, 4)
	# Sights: buckhorn rear, a tall tang peep folded up, a blade at the muzzle.
	MeshKit.add_box(gun, _t(Vector3(0, 0.085, -0.32)), Vector3(0.07, 0.035, 0.012), IRON.lightened(0.1))
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.BACK, sx * 0.5), Vector3(sx * 0.035, 0.11, -0.32)), Vector3(0.012, 0.04, 0.01), IRON.lightened(0.1))
	MeshKit.add_box(gun, _t(Vector3(0, 0.12, 0.3)), Vector3(0.012, 0.13, 0.012), BRASS)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.19, 0.3)), 0.02, 0.02, 0.008, 8, BRASS)
	MeshKit.add_box(gun, _t(Vector3(0, 0.09, -1.7)), Vector3(0.008, 0.04, 0.03), BRASS)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.14, "head_y": 0.94, "gun_y": 0.2, "muzzle": Vector3(0, 0.02, -1.76)}


# ------------------------------------------------------------------ Brimstone Bellows

## Brimstone Bellows (Late, sulfur line): a squat brick firebox with an iron
## door glowing behind its grate, a coal scuttle and sulfur sacks; the head
## carries a great leather bellows and a stovepipe; the gun is a long iron
## nozzle with a brass flare, crusted yellow where the fumes come out.
static func _brimstone_bellows(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1202
	var base := MeshKit.begin()
	# Stone footing and the brick firebox (courses offset like real bond).
	MeshKit.add_box(base, _t(Vector3(0, 0.05, 0)), Vector3(1.3, 0.1, 1.3), STONE.darkened(0.1), 0.02, rng)
	for course in 6:
		var y := 0.13 + course * 0.1
		var shift := 0.06 if course % 2 == 0 else -0.06
		for side in 4:
			var b := Basis(Vector3.UP, side * PI * 0.5)
			for k in 4:
				var x := -0.39 + k * 0.26 + shift
				if absf(x) > 0.46:
					continue
				MeshKit.add_box(base, Transform3D(b, b * Vector3(x, y, 0.47)), Vector3(0.24, 0.085, 0.12),
						BRICK.darkened(rng.randf() * 0.2).lerp(Color("#5A3A2C"), rng.randf() * 0.2), 0.008, rng)
	MeshKit.add_box(base, _t(Vector3(0, 0.42, 0)), Vector3(0.86, 0.6, 0.86), BRICK.darkened(0.35)) # (mortar fill behind the bricks)
	# Iron fire door with a grate and the glow behind it.
	MeshKit.add_box(base, _t(Vector3(0, 0.34, 0.545)), Vector3(0.34, 0.26, 0.03), DARK_IRON)
	for k in 4:
		MeshKit.add_box(base, _t(Vector3(-0.12 + k * 0.08, 0.34, 0.565)), Vector3(0.025, 0.2, 0.012), IRON)
	MeshKit.add_box(base, _t(Vector3(0, 0.34, 0.552)), Vector3(0.28, 0.18, 0.01), Color("#FF8A2A"), 0.0, null, 1.6)
	MeshKit.add_ellipsoid(base, _t(Vector3(0.12, 0.34, 0.58)), Vector3(0.02, 0.02, 0.02), 2, 5, BRASS)
	# Top slab and the greased turntable.
	MeshKit.add_box(base, _t(Vector3(0, 0.78, 0)), Vector3(1.04, 0.07, 1.04), STONE, 0.01, rng)
	MeshKit.lathe(base, _t(Vector3(0, 0.81, 0)), [Vector2(0.3, 0.0), Vector2(0.28, 0.06), Vector2(0.31, 0.09)], 14, DARK_IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.91, 0)), 0.3, 0.3, 0.012, 14, GREASE)
	# Sulfur sacks and a coal scuttle beside it.
	for k in 2:
		var p := Vector3(0.62 + k * 0.05, 0.2, -0.3 + k * 0.32)
		MeshKit.add_ellipsoid(base, _t(p), Vector3(0.16, 0.2, 0.15), 4, 8, Palette.SAND.darkened(0.2), 0.06, rng)
		MeshKit.add_ellipsoid(base, _t(p + Vector3(0, 0.17, 0)), Vector3(0.1, 0.05, 0.09), 3, 6, SULFUR)
		MeshKit.add_box(base, _t(p + Vector3(0, 0.02, -0.15)), Vector3(0.12, 0.09, 0.01), SULFUR.darkened(0.3))
	MeshKit.lathe(base, _t(Vector3(-0.62, 0.0, 0.42)), [Vector2(0.12, 0.0), Vector2(0.15, 0.18), Vector2(0.16, 0.2)], 10, IRON)
	MeshKit.add_ellipsoid(base, _t(Vector3(-0.62, 0.2, 0.42)), Vector3(0.13, 0.05, 0.13), 3, 8, COAL, 0.1, rng)
	_pennant(base, Vector3(-0.58, 0.1, -0.5), 1.5, team)
	# Head: the bellows (two boards, a pleated leather bag) and a stovepipe.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.3, 0.3, 0.05, 14, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.1, 0.05)), Vector3(0.5, 0.1, 0.5), DARK_IRON)
	for k in 5:
		var z := 0.4 - k * 0.07
		var r := 0.2 + 0.03 * sin(float(k) * 1.6)
		MeshKit.add_box(head, _t(Vector3(0, 0.26, z)), Vector3(r * 2.0, 0.17, 0.06), LEATHER.darkened(0.05 * (k % 2)))
	for z: float in [0.45, 0.1]:
		MeshKit.add_box(head, _t(Vector3(0, 0.26, z)), Vector3(0.46, 0.2, 0.03), Palette.WOOD_DARK, 0.01, rng)
	_rivets(head, Vector3(0, 0.36, 0.45), Vector3.RIGHT, 5, 0.09)
	_rod(head, Vector3(0, 0.38, 0.45), Vector3(0, 0.5, 0.62), 0.02, Palette.WOOD, 5) # pump handle
	MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(0, 0.5, 0.62)), 0.03, 0.03, 0.2, 6, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, _t(Vector3(0.22, 0.5, 0.25)), 0.07, 0.07, 0.8, 10, DARK_IRON) # stovepipe
	MeshKit.add_cylinder(head, _t(Vector3(0.22, 0.93, 0.25)), 0.11, 0.0, 0.1, 10, IRON) # rain cap
	MeshKit.add_cylinder(head, _t(Vector3(0.22, 0.88, 0.25)), 0.012, 0.012, 0.06, 4, IRON)
	# Gun: the nozzle (it pitches about the swivel at the front of the bellows).
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.05, 0.05, 0.36, 8, IRON)
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0.0, 0.0)), Vector3(0.13, 0.12, 0.13), 4, 10, DARK_IRON)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.09, -0.08), Vector2(0.07, -0.25), Vector2(0.06, -0.9),
			Vector2(0.07, -1.15), Vector2(0.12, -1.3), Vector2(0.15, -1.36)], 10, IRON)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.155, -1.36), Vector2(0.16, -1.38)], 12, BRASS)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -1.385)), 0.12, 0.12, 0.006, 12, COAL)
	for z: float in [-0.35, -0.7]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.075, 0.075, 0.04, 10, BRASS.darkened(0.15))
	for k in 6: # the sulfur crust round the mouth
		var a := TAU * float(k) / 6.0 + rng.randf() * 0.4
		MeshKit.add_ellipsoid(gun, _t(Vector3(cos(a) * 0.14, sin(a) * 0.14, -1.33)), Vector3(0.03, 0.03, 0.05), 2, 5, SULFUR.darkened(rng.randf() * 0.2))
	_rod(gun, Vector3(0.0, 0.08, -0.05), Vector3(0.0, 0.08, -0.85), 0.012, BRASS, 4) # igniter line
	MeshKit.add_ellipsoid(gun, _t(Vector3(0.0, 0.09, -0.88)), Vector3(0.025, 0.025, 0.025), 2, 6, Color("#FF9A3A"), 0.0, null, 1.4)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.04, "head_y": 0.92, "gun_y": 0.26, "muzzle": Vector3(0, 0, -1.4)}


# ------------------------------------------------------------------ Cotton Bale Cannon

## Cotton Bale Cannon (Late, cotton line): a stubby wide-mouthed iron cannon on
## a wheeled field carriage, a roped cotton bale showing at the muzzle, more
## bales and a coil of rope on the trail, a pressing screw on the breech.
static func _cotton_bale_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1203
	var base := MeshKit.begin()
	# Carriage: two cheeks, an axle and spoked wheels, the trail running back.
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.36
		MeshKit.add_box(base, _t(Vector3(x, 0.38, 0.05)), Vector3(0.08, 0.3, 0.75), Palette.WOOD.darkened(0.05), 0.012, rng)
		var hub := Vector3(sx * 0.52, 0.34, -0.05)
		MeshKit.add_rim(base, Transform3D(ACROSS, hub), 0.34, 0.29, 0.06, 18, Palette.WOOD_DARK)
		MeshKit.add_rim(base, Transform3D(ACROSS, hub), 0.345, 0.335, 0.065, 18, IRON)
		MeshKit.add_cylinder(base, Transform3D(ACROSS, hub), 0.06, 0.06, 0.12, 10, IRON)
		for k in 10:
			var a := TAU * float(k) / 10.0
			_beam(base, hub, hub + Vector3(0, sin(a), cos(a)) * 0.3, Vector2(0.025, 0.025), Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(ACROSS, Vector3(0, 0.34, -0.05)), 0.04, 0.04, 1.1, 8, IRON)
	MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, 0.2, 0.62)), Vector3(0.28, 0.1, 0.7), Palette.WOOD.darkened(0.08), 0.012, rng)
	MeshKit.add_box(base, _t(Vector3(0, 0.04, 0.95)), Vector3(0.32, 0.08, 0.12), IRON) # trail shoe
	# Spare bales on the trail and a coil of rope.
	for k in 2:
		var p := Vector3(-0.12 + k * 0.26, 0.24 + k * 0.03, 0.5 + k * 0.16)
		_bale(base, rng, p, 0.2 * k, 0.75)
	for k in 4:
		_hoop(base, Vector3(0.36, 0.06 + k * 0.03, 0.72), Vector3.UP, 0.13 - k * 0.006, 0.02, ROPE, 12)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.6, 0.0)), 0.24, 0.24, 0.08, 12, DARK_IRON) # pivot plate
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.65, 0.0)), 0.22, 0.22, 0.012, 12, GREASE)
	_pennant(base, Vector3(0.34, 0.53, 0.38), 1.2, team)
	# Head: a yoke with trunnion caps.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.22, 0.22, 0.05, 12, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.07, 0)), Vector3(0.62, 0.06, 0.3), Palette.WOOD_DARK, 0.01, rng)
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(head, _t(Vector3(sx * 0.28, 0.2, 0)), Vector3(0.06, 0.24, 0.22), Palette.WOOD, 0.01, rng)
		MeshKit.add_box(head, _t(Vector3(sx * 0.28, 0.3, 0)), Vector3(0.075, 0.04, 0.16), IRON)
		_rivets(head, Vector3(sx * 0.312, 0.16, 0), Vector3.BACK, 3, 0.06)
	# Gun: the stubby barrel, its muzzle swell, the bale loaded in the mouth.
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.05, 0.05, 0.52, 8, IRON)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.0, 0.42), Vector2(0.12, 0.4), Vector2(0.2, 0.3),
			Vector2(0.23, 0.12), Vector2(0.24, 0.0), Vector2(0.22, -0.3), Vector2(0.21, -0.7), Vector2(0.26, -0.78),
			Vector2(0.27, -0.86), Vector2(0.24, -0.88)], 14, DARK_IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.885)), 0.2, 0.2, 0.006, 14, Palette.OUTLINE)
	for z: float in [0.12, -0.34]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.25, 0.25, 0.05, 14, IRON.lightened(0.1))
	# The breech's pressing screw and handwheel (it packs the bale tight).
	_rod(gun, Vector3(0, 0, 0.42), Vector3(0, 0, 0.62), 0.025, IRON, 6)
	MeshKit.add_rim(gun, Transform3D(ALONG, Vector3(0, 0, 0.64)), 0.14, 0.11, 0.025, 14, BRASS)
	for k in 4:
		var a := TAU * float(k) / 4.0
		_rod(gun, Vector3(0, 0, 0.64), Vector3(cos(a), sin(a), 0) * 0.12 + Vector3(0, 0, 0.64), 0.012, BRASS, 4)
	# The bale in the mouth: lumpy cotton bound with rope.
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0, -0.86)), Vector3(0.18, 0.18, 0.12), 5, 10, COTTON, 0.12, rng)
	for k in 2:
		_hoop(gun, Vector3(0, 0, -0.83 - k * 0.06), Vector3.BACK, 0.175, 0.015, ROPE, 12)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.12, "head_y": 0.66, "gun_y": 0.3, "muzzle": Vector3(0, 0, -0.95)}


## A pressed cotton bale: a lumpy block bound with three ropes.
static func _bale(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, turn: float, s: float) -> void:
	var b := Basis(Vector3.UP, turn)
	MeshKit.add_box(st, Transform3D(b, at), Vector3(0.36, 0.26, 0.24) * s, COTTON.darkened(0.04 + rng.randf() * 0.06), 0.02, rng)
	for k in 3:
		MeshKit.add_box(st, Transform3D(b, at + b * Vector3((-0.12 + k * 0.12) * s, 0, 0)), Vector3(0.025, 0.27, 0.25) * s, ROPE)
