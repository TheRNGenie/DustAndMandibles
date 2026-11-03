class_name CraftBuilder
extends RefCounted
## Crafted turrets (CraftTable designs): modular meshes made from the three parts.
## The MOUNT is the base and the yawing head, the BARREL is the pitching gun, and
## the LOAD is an ammo/feed piece on a shelf off the head, with a feed line to the
## gun's breech and a small accent on the gun in the load's colour.
## Same parts and keys as TurretBuilder.build: base / head / gun (+ spin), head_y,
## gun_y, muzzle (gun space, barrels along -Z), recoil.

const ALONG := Basis(Vector3.RIGHT, PI * 0.5) # local Y -> +Z (profiles in y map to z)
const ACROSS := Basis(Vector3.BACK, PI * 0.5) # local Y -> X
const BRASS := Color("#D6A74A")
const IRON := Color("#4A4E58")
const DARK_IRON := Color("#34373E")
const STONE := Color("#A39686")
const RUBBER := Color("#4A2A24")
const GREASE := Color("#22201E")
const RED_STICK := Color("#C8352A")

## Per mount: head height, gun pivot above the head, and where the load sits (head space).
const MOUNT_SPECS := {
	&"post": {"head_y": 1.36, "gun_y": 0.3, "slot": Vector3(0.46, 0.0, 0.2)},
	&"swivel": {"head_y": 0.82, "gun_y": 0.44, "slot": Vector3(0.5, 0.08, 0.2)},
	&"tripod": {"head_y": 1.16, "gun_y": 0.27, "slot": Vector3(0.44, -0.02, 0.22)},
}
## The gun's cheek plates sit at +-CHEEK (x); trunnions reach them.
const CHEEK := 0.3


static func build(id: StringName, team: Color) -> Dictionary:
	var p := CraftTable.parse(id)
	if p.is_empty():
		return TurretBuilder.build(&"gatling_post", team)
	var mount: StringName = p[0]
	var barrel: StringName = p[1]
	var load: StringName = p[2]
	var spec: Dictionary = MOUNT_SPECS[mount]
	var gun_y: float = spec["gun_y"]
	var slot: Vector3 = spec["slot"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	var base := MeshKit.begin()
	var head := MeshKit.begin()
	var gun := MeshKit.begin()
	_mount(base, head, mount, gun_y, slot, rng, team)
	var b := _barrel(gun, barrel, rng)
	var tint: Color = CraftTable.LOADS[load]["color"]
	_load_piece(head, load, slot, tint, rng)
	_load_feed(head, gun, load, slot, gun_y, b["breech"], tint)
	_load_accent(gun, load, b["muzzle"], float(b["muzzle_r"]), tint)
	var out := {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": float(spec["head_y"]), "gun_y": gun_y, "muzzle": b["muzzle"], "recoil": float(b["recoil"])}
	if b.has("spin"):
		out["spin"] = b["spin"]
		out["spin_at"] = b["spin_at"]
	return out


## A single part on its own, for menu icons: a mount (base with its head on top),
## a barrel (the gun) or a load (the ammo piece). Key is a part key or bare id.
## Returns [[mesh, Transform3D], ...] as IconStudio renders them.
static func part_meshes(key: StringName) -> Array:
	var id := StringName(String(key).trim_prefix(CraftTable.PART_PREFIX))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	var st := MeshKit.begin()
	if CraftTable.MOUNTS.has(id):
		var spec: Dictionary = MOUNT_SPECS[id]
		var head := MeshKit.begin()
		_mount(st, head, id, spec["gun_y"], spec["slot"], rng, Palette.TEAM_WEST, false)
		return [[MeshKit.finish(st), Transform3D()], [MeshKit.finish(head), _t(Vector3(0, spec["head_y"], 0))]]
	if CraftTable.BARRELS.has(id):
		var b := _barrel(st, id, rng)
		var out: Array = [[MeshKit.finish(st), Transform3D()]]
		if b.has("spin"):
			out.append([b["spin"], _t(b["spin_at"])])
		return out
	if CraftTable.LOADS.has(id):
		_load_piece(st, id, Vector3.ZERO, CraftTable.LOADS[id]["color"], rng)
	else:
		MeshKit.add_box(st, Transform3D(), Vector3.ONE * 0.3, Palette.WOOD)
	return [[MeshKit.finish(st), Transform3D()]]


static func _t(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


## A box stretched between two points (a strut, a brace, a leg).
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: Vector2, color: Color, rng: RandomNumberGenerator = null) -> void:
	var d := b - a
	MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(d), (a + b) * 0.5), Vector3(w.x, d.length(), w.y), color, 0.01 if rng != null else 0.0, rng)


## A ring of thin rod (hand wheels, valve wheels, hoops) in the plane normal to `axis`.
static func _hoop(st: SurfaceTool, c: Vector3, axis: Vector3, r: float, thick: float, color: Color, segs: int = 10) -> void:
	var bas := MeshKit.basis_from_y(axis)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var p0 := c + bas * (Vector3(cos(a0), 0, sin(a0)) * r)
		var p1 := c + bas * (Vector3(cos(a1), 0, sin(a1)) * r)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(p1 - p0), (p0 + p1) * 0.5), thick, thick, p0.distance_to(p1) * 1.08, 4, color, false)


## A plain rod between two points (no end balls, lighter than MeshKit.add_limb).
static func _rod(st: SurfaceTool, a: Vector3, b: Vector3, r: float, color: Color, segs: int = 5) -> void:
	var d := b - a
	if d.length() < 0.0001:
		return
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(d), (a + b) * 0.5), r, r, d.length(), segs, color, false)


static func _rivet_ring(st: SurfaceTool, c: Vector3, r: float, n: int, size: float = 0.02) -> void:
	for i in n:
		var a := TAU * float(i) / n
		MeshKit.add_ellipsoid(st, _t(c + Vector3(cos(a), 0, sin(a)) * r), Vector3(size, size * 0.7, size), 2, 5, BRASS)


# ------------------------------------------------------------------ mounts

static func _mount(base: SurfaceTool, head: SurfaceTool, mount: StringName, gun_y: float, slot: Vector3,
		rng: RandomNumberGenerator, team: Color, flag: bool = true) -> void:
	match mount:
		&"swivel":
			_swivel(base, head, gun_y, rng, team, flag)
		&"tripod":
			_tripod(base, head, gun_y, rng, team, flag)
		_:
			_post(base, head, gun_y, rng, team, flag)
	_cheeks(head, gun_y, mount)
	_shelf(head, slot, mount)


## Post: a squared timber post on a mortared stone footing, braced at the corners.
static func _post(base: SurfaceTool, head: SurfaceTool, gun_y: float, rng: RandomNumberGenerator, team: Color, flag: bool) -> void:
	# Footing: a mortar bed, a course of rough stones round a core, a cap stone.
	MeshKit.add_box(base, _t(Vector3(0, 0.05, 0)), Vector3(1.0, 0.1, 1.0), STONE.darkened(0.35), 0.02, rng)
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var p := Vector3(cos(a) * 0.36, 0.2, sin(a) * 0.36)
		MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.3, 0.24, 0.36), STONE.darkened(rng.randf() * 0.22), 0.035, rng)
	MeshKit.add_box(base, _t(Vector3(0, 0.38, 0)), Vector3(0.66, 0.14, 0.66), STONE.lightened(0.06), 0.03, rng)
	for i in 5:
		var a := rng.randf() * TAU
		MeshKit.add_ellipsoid(base, _t(Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.55, 0.7) + Vector3(0, 0.04, 0)),
				Vector3(0.1, 0.06, 0.08) * rng.randf_range(0.8, 1.3), 3, 6, STONE.darkened(0.15), 0.15, rng)
	# The post, its iron bands and bolts, and four corner braces.
	MeshKit.add_box(base, _t(Vector3(0, 0.88, 0)), Vector3(0.26, 0.92, 0.26), Palette.WOOD, 0.012, rng)
	for s: float in [-1.0, 1.0]: # grain checks on the faces
		MeshKit.add_box(base, _t(Vector3(s * 0.131, 0.9, 0.04)), Vector3(0.005, 0.5, 0.015), Palette.WOOD_DARK)
		MeshKit.add_box(base, _t(Vector3(-0.03, 0.8, s * 0.131)), Vector3(0.015, 0.45, 0.005), Palette.WOOD_DARK)
	for y: float in [0.6, 1.22]:
		MeshKit.add_box(base, _t(Vector3(0, y, 0)), Vector3(0.29, 0.05, 0.29), IRON)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(base, _t(Vector3(s * 0.15, y, 0)), Vector3(0.012, 0.025, 0.025), 2, 5, BRASS)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * 0.4, 0.45, sin(a) * 0.4)
		var top := Vector3(cos(a) * 0.13, 0.85, sin(a) * 0.13)
		_beam(base, foot, top, Vector2(0.08, 0.07), Palette.WOOD_DARK, rng)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.33, 0)), 0.2, 0.2, 0.05, 12, IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.355, 0)), 0.17, 0.17, 0.02, 12, GREASE)
	if flag:
		TurretBuilder._pennant(base, Vector3(-0.42, 0.1, 0.42), 1.55, team)
	# Head: an iron turn plate and a timber saddle with a team stripe.
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.02, 0)), 0.22, 0.22, 0.05, 12, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.1, 0.02)), Vector3(0.64, 0.12, 0.38), Palette.WOOD, 0.01, rng)
	MeshKit.add_box(head, _t(Vector3(0, 0.1, -0.175)), Vector3(0.5, 0.05, 0.02), team)
	TurretBuilder._rivets(head, Vector3(0, 0.1, 0.215), Vector3.RIGHT, 4, 0.15)


## Swivel: a cast-iron pedestal with a greased turntable; the head is a toothed
## turning disc carrying a tall U yoke with a hand wheel.
static func _swivel(base: SurfaceTool, head: SurfaceTool, gun_y: float, rng: RandomNumberGenerator, team: Color, flag: bool) -> void:
	for i in 4: # plank pad
		MeshKit.add_box(base, _t(Vector3(-0.45 + i * 0.3, 0.04, 0)), Vector3(0.28, 0.08, 1.2), Palette.WOOD.darkened(rng.randf() * 0.15), 0.015, rng)
	for z: float in [-0.45, 0.45]:
		MeshKit.add_box(base, _t(Vector3(0, 0.09, z)), Vector3(1.15, 0.03, 0.08), IRON)
	MeshKit.lathe(base, _t(Vector3(0, 0.08, 0)), [Vector2(0.4, 0.0), Vector2(0.4, 0.06), Vector2(0.3, 0.1), Vector2(0.17, 0.2),
			Vector2(0.13, 0.4), Vector2(0.15, 0.55), Vector2(0.28, 0.62), Vector2(0.32, 0.66)], 14, DARK_IRON)
	_rivet_ring(base, Vector3(0, 0.14, 0), 0.36, 8, 0.025)
	# The turntable race: iron ring, a black ring of grease, ball bearings peeking out.
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.76, 0)), 0.42, 0.42, 0.06, 18, IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 0.795, 0)), 0.43, 0.43, 0.015, 18, GREASE)
	for i in 8:
		var a := TAU * float(i) / 8.0
		MeshKit.add_ellipsoid(base, _t(Vector3(cos(a) * 0.43, 0.79, sin(a) * 0.43)), Vector3.ONE * 0.022, 2, 5, Palette.METAL.lightened(0.3))
	for i in 4: # grease runs down the pedestal
		var a := TAU * float(i) / 4.0 + 0.5
		var r := 0.17 + rng.randf() * 0.02
		MeshKit.add_ellipsoid(base, _t(Vector3(cos(a) * r, 0.62 - rng.randf() * 0.1, sin(a) * r)), Vector3(0.025, 0.07 + rng.randf() * 0.05, 0.025), 3, 5, GREASE)
	# A grease pail with its paddle beside the pad.
	MeshKit.lathe(base, _t(Vector3(0.48, 0.08, 0.42)), [Vector2(0.09, 0.0), Vector2(0.11, 0.18)], 10, IRON.lightened(0.1))
	MeshKit.add_cylinder(base, _t(Vector3(0.48, 0.25, 0.42)), 0.1, 0.1, 0.01, 10, GREASE)
	_beam(base, Vector3(0.48, 0.2, 0.42), Vector3(0.56, 0.42, 0.38), Vector2(0.03, 0.015), Palette.WOOD)
	if flag:
		TurretBuilder._pennant(base, Vector3(-0.5, 0.08, 0.5), 1.4, team)
	# Head: toothed disc, a yoke crossbar, and the left-hand traverse wheel.
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.03, 0)), 0.4, 0.4, 0.06, 18, IRON.lightened(0.12))
	for i in 12:
		var a := TAU * float(i) / 12.0
		MeshKit.add_box(head, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.41, 0.03, sin(a) * 0.41)), Vector3(0.04, 0.05, 0.04), IRON)
	MeshKit.add_box(head, _t(Vector3(0, 0.11, 0)), Vector3(0.68, 0.1, 0.22), DARK_IRON)
	MeshKit.add_box(head, _t(Vector3(0, 0.11, -0.115)), Vector3(0.5, 0.05, 0.015), team)
	var hw := Vector3(-CHEEK - 0.1, gun_y - 0.12, 0.05)
	MeshKit.add_cylinder(head, Transform3D(ACROSS, hw + Vector3(0.05, 0, 0)), 0.025, 0.025, 0.12, 6, IRON)
	_hoop(head, hw, Vector3.RIGHT, 0.12, 0.016, BRASS.darkened(0.1), 12)
	for i in 4:
		var a := TAU * float(i) / 4.0
		_rod(head, hw, hw + Vector3(0, cos(a), sin(a)) * 0.11, 0.01, IRON, 4)
	MeshKit.add_cylinder(head, Transform3D(ACROSS, hw + Vector3(-0.05, 0.1, 0.0)), 0.018, 0.018, 0.1, 6, Palette.WOOD)


## Tripod: three splayed iron legs on a hub, pad feet, spreader chains and a
## hanging sandbag; the head is a pintle collar with a traverse bar out back.
static func _tripod(base: SurfaceTool, head: SurfaceTool, gun_y: float, rng: RandomNumberGenerator, team: Color, flag: bool) -> void:
	var hub := Vector3(0, 1.0, 0)
	var feet: Array[Vector3] = []
	for i in 3:
		var a := TAU * float(i) / 3.0 + PI * 0.5
		feet.append(Vector3(cos(a) * 0.82, 0.05, sin(a) * 0.82))
	for f: Vector3 in feet:
		var top := hub + (f - hub).normalized() * 0.12
		var knee := hub.lerp(f, 0.42)
		_rod(base, top, knee, 0.055, IRON, 7) # upper sleeve
		_rod(base, knee, f + Vector3(0, 0.05, 0), 0.04, Palette.METAL.darkened(0.15), 7) # sliding leg
		MeshKit.add_cylinder(base, Transform3D(MeshKit.basis_from_y(f - hub), knee), 0.068, 0.068, 0.07, 8, BRASS) # clamp
		MeshKit.add_cylinder(base, _t(f + Vector3(0, -0.01, 0)), 0.11, 0.13, 0.05, 10, DARK_IRON) # pad foot
		MeshKit.add_cylinder(base, _t(f + Vector3(0, 0.04, 0)), 0.05, 0.03, 0.06, 8, IRON)
	for i in 3: # spreader chains, sagging a little
		var a := hub.lerp(feet[i], 0.62)
		var b := hub.lerp(feet[(i + 1) % 3], 0.62)
		var mid := (a + b) * 0.5 + Vector3(0, -0.08, 0)
		for k in 6:
			var t0 := float(k) / 6.0
			var t1 := float(k + 1) / 6.0
			var p0 := a.lerp(mid, t0 * 2.0) if t0 < 0.5 else mid.lerp(b, t0 * 2.0 - 1.0)
			var p1 := a.lerp(mid, t1 * 2.0) if t1 < 0.5 else mid.lerp(b, t1 * 2.0 - 1.0)
			_rod(base, p0, p1, 0.014, IRON.lightened(0.2), 4)
	# Hub casting, the pintle column, a clamp screw with a T handle.
	MeshKit.add_ellipsoid(base, _t(hub), Vector3(0.14, 0.1, 0.14), 4, 10, DARK_IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.1, 0)), 0.08, 0.08, 0.16, 10, IRON)
	MeshKit.add_cylinder(base, _t(Vector3(0, 1.0, 0)), 0.16, 0.16, 0.04, 12, BRASS.darkened(0.1))
	MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.18, 1.08, 0)), 0.018, 0.018, 0.16, 6, IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.26, 1.08, 0)), 0.014, 0.014, 0.14, 6, IRON)
	# A sandbag hung from the hub to steady it.
	_rod(base, Vector3(0, 0.92, 0), Vector3(0, 0.5, 0), 0.012, IRON.lightened(0.2), 4)
	MeshKit.add_ellipsoid(base, _t(Vector3(0, 0.38, 0)), Vector3(0.17, 0.15, 0.15), 4, 9, Palette.SAND.darkened(0.2), 0.08, rng)
	MeshKit.add_box(base, _t(Vector3(0, 0.5, 0)), Vector3(0.1, 0.03, 0.1), Palette.WOOD_DARK)
	if flag:
		TurretBuilder._pennant(base, feet[1] + Vector3(0.05, 0.04, 0.0), 1.3, team)
	# Head: pintle collar, a cradle plate and the traverse bar with a wooden grip.
	MeshKit.add_cylinder(head, _t(Vector3(0, 0.0, 0)), 0.11, 0.11, 0.1, 10, IRON.lightened(0.1))
	MeshKit.add_box(head, _t(Vector3(0, 0.07, 0.02)), Vector3(0.66, 0.06, 0.26), DARK_IRON)
	MeshKit.add_box(head, _t(Vector3(0, 0.07, -0.135)), Vector3(0.48, 0.04, 0.012), team)
	_beam(head, Vector3(0, 0.05, 0.12), Vector3(0, -0.12, 0.62), Vector2(0.04, 0.04), IRON)
	MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(0, -0.13, 0.64)), 0.03, 0.03, 0.3, 8, Palette.WOOD)


## The gun's cheek plates (left and right of the gun) with brass bearing caps at the pivot.
static func _cheeks(head: SurfaceTool, gun_y: float, mount: StringName) -> void:
	var bottom := 0.08 if mount != &"tripod" else 0.06
	var thick := 0.06 if mount == &"swivel" else 0.045
	var col := DARK_IRON if mount != &"post" else IRON
	for s: float in [-1.0, 1.0]:
		var h := gun_y + 0.05 - bottom
		MeshKit.add_box(head, _t(Vector3(s * (CHEEK + thick * 0.5), bottom + h * 0.5, 0)), Vector3(thick, h, 0.2 if mount == &"swivel" else 0.16), col)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * (CHEEK + thick * 0.5), gun_y, 0)), 0.1, 0.1, thick + 0.002, 12, col)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * (CHEEK + thick + 0.012), gun_y, 0)), 0.05, 0.05, 0.03, 10, BRASS)
		if mount == &"swivel": # gusset where the yoke arm meets the crossbar
			_beam(head, Vector3(s * (CHEEK + 0.03), 0.12, -0.08), Vector3(s * (CHEEK + 0.03), 0.3, -0.0), Vector2(0.03, 0.04), col)


## A little shelf bracket on the right of the head for the load piece.
static func _shelf(head: SurfaceTool, slot: Vector3, mount: StringName) -> void:
	var top := slot.y
	MeshKit.add_box(head, _t(Vector3(slot.x, top - 0.02, slot.z)), Vector3(0.36, 0.04, 0.32), Palette.WOOD_DARK)
	var inner := CHEEK
	_beam(head, Vector3(inner, top - 0.03, slot.z), Vector3(slot.x + 0.15, top - 0.03, slot.z), Vector2(0.04, 0.04), IRON)
	_beam(head, Vector3(inner, top - 0.2 if mount != &"swivel" else top - 0.06, slot.z), Vector3(slot.x + 0.08, top - 0.04, slot.z), Vector2(0.03, 0.03), IRON)


# ------------------------------------------------------------------ barrels

## Builds the gun into `gun`. Returns {"muzzle", "muzzle_r", "recoil", "breech" (where
## the feed goes in, gun space), optional "spin", "spin_at"}.
static func _barrel(gun: SurfaceTool, barrel: StringName, rng: RandomNumberGenerator) -> Dictionary:
	# Trunnion pins out to the cheeks.
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.04, 0.04, CHEEK * 2.0, 8, IRON)
	match barrel:
		&"scatter":
			return _scatter(gun)
		&"cannon":
			return _cannon(gun)
		&"nozzle":
			return _nozzle(gun)
	return _rifle(gun)


## Rifle: a long octagonal barrel on a receiver with a wooden stock, brass bands
## and a long brass telescope sight.
static func _rifle(gun: SurfaceTool) -> Dictionary:
	MeshKit.add_box(gun, _t(Vector3(0, 0.0, 0.06)), Vector3(0.13, 0.14, 0.42), DARK_IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, _t(Vector3(s * 0.067, 0.0, 0.08)), Vector3(0.006, 0.1, 0.28), BRASS)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.06, -0.14), Vector2(0.055, -0.3), Vector2(0.046, -1.0),
			Vector2(0.042, -1.55), Vector2(0.048, -1.58), Vector2(0.048, -1.66)], 8, Palette.METAL.darkened(0.2))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -1.665)), 0.026, 0.026, 0.004, 8, Palette.OUTLINE) # bore
	for z: float in [-0.5, -1.1]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.056, 0.056, 0.05, 8, BRASS)
	MeshKit.add_box(gun, _t(Vector3(0, -0.06, -0.48)), Vector3(0.1, 0.07, 0.62), Palette.WOOD) # forestock
	MeshKit.add_box(gun, _t(Vector3(0, -0.045, 0.36)), Vector3(0.08, 0.1, 0.24), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0, -0.1, 0.6)), Vector3(0.1, 0.22, 0.32), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0, -0.13, 0.765)), Vector3(0.105, 0.23, 0.02), BRASS)
	_rod(gun, Vector3(0, -0.07, 0.18), Vector3(0, -0.15, 0.26), 0.012, BRASS, 4) # lever loop
	_rod(gun, Vector3(0, -0.15, 0.26), Vector3(0, -0.07, 0.34), 0.012, BRASS, 4)
	# Front blade sight and a long brass telescope on two rings.
	MeshKit.add_box(gun, _t(Vector3(0, 0.07, -1.56)), Vector3(0.012, 0.05, 0.05), BRASS)
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3(0, 0.13, 0)), [Vector2(0.03, 0.3), Vector2(0.038, 0.26), Vector2(0.03, 0.22),
			Vector2(0.026, 0.0), Vector2(0.026, -0.4), Vector2(0.04, -0.46), Vector2(0.04, -0.52)], 10, BRASS)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.13, -0.522)), 0.032, 0.032, 0.006, 10, Color("#2E4A5A"), false, 0.3)
	for z: float in [-0.05, -0.35]:
		MeshKit.add_box(gun, _t(Vector3(0, 0.095, z)), Vector3(0.03, 0.06, 0.03), DARK_IRON)
	return {"muzzle": Vector3(0, 0, -1.7), "muzzle_r": 0.05, "recoil": 0.12, "breech": Vector3(0.07, -0.02, 0.12)}


## Scatter: a pepperbox, seven short barrels round a fluted cylinder that spins,
## on a breech housing with a crank.
static func _scatter(gun: SurfaceTool) -> Dictionary:
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.0, 0.42), Vector2(0.06, 0.41), Vector2(0.13, 0.36),
			Vector2(0.16, 0.28), Vector2(0.16, -0.04), Vector2(0.12, -0.06)], 12, DARK_IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.2)), 0.168, 0.168, 0.04, 12, BRASS)
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0, 0.45)), Vector3.ONE * 0.04, 3, 6, BRASS) # rear knob
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(-0.2, 0, 0.14)), 0.025, 0.025, 0.1, 6, IRON) # crank
	_rod(gun, Vector3(-0.25, 0, 0.14), Vector3(-0.25, -0.14, 0.14), 0.018, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(-0.3, -0.14, 0.14)), 0.03, 0.03, 0.09, 6, Palette.WOOD)
	MeshKit.add_box(gun, _t(Vector3(0, 0.17, 0.12)), Vector3(0.04, 0.03, 0.2), IRON) # sight rib
	var spin := MeshKit.begin()
	MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, -0.12)), 0.165, 0.165, 0.22, 14, Palette.METAL.darkened(0.1))
	for i in 7: # flutes between the chambers
		var a := TAU * (float(i) + 0.5) / 7.0
		MeshKit.add_box(spin, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.16 + Vector3(0, 0, -0.12)), Vector3(0.02, 0.04, 0.18), DARK_IRON)
	var tubes: Array[Vector2] = [Vector2.ZERO]
	for i in 6:
		var a := TAU * float(i) / 6.0
		tubes.append(Vector2(cos(a), sin(a)) * 0.105)
	for t: Vector2 in tubes:
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(t.x, t.y, -0.5)), 0.042, 0.04, 0.56, 7, Palette.METAL.lightened(0.05), false)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(t.x, t.y, -0.79)), 0.05, 0.05, 0.04, 7, DARK_IRON)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(t.x, t.y, -0.812)), 0.024, 0.024, 0.004, 5, Palette.OUTLINE)
	for z: float in [-0.32, -0.68]:
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, z)), 0.16, 0.16, 0.05, 14, BRASS)
	return {"muzzle": Vector3(0, 0, -0.86), "muzzle_r": 0.16, "recoil": 0.04, "breech": Vector3(0.16, 0.0, 0.2),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0, -0.04)}


## Cannon: a fat, short mortar tube with a cascabel knob, reinforce rings,
## lifting dolphins and a touch-hole pan.
static func _cannon(gun: SurfaceTool) -> Dictionary:
	var bronze := Color("#3E3A38")
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.0, 0.38), Vector2(0.045, 0.37), Vector2(0.04, 0.33),
			Vector2(0.03, 0.31), Vector2(0.12, 0.3), Vector2(0.21, 0.26), Vector2(0.25, 0.14), Vector2(0.25, 0.02),
			Vector2(0.23, -0.12), Vector2(0.21, -0.38), Vector2(0.22, -0.46), Vector2(0.27, -0.52), Vector2(0.27, -0.6),
			Vector2(0.22, -0.62), Vector2(0.17, -0.6), Vector2(0.16, -0.42)], 16, bronze)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.43)), 0.16, 0.16, 0.01, 12, Palette.OUTLINE) # bore
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0, 0.4)), Vector3.ONE * 0.06, 4, 8, BRASS) # cascabel
	for z: float in [0.12, -0.08, -0.4]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.255 if z > 0.0 else 0.235, 0.255 if z > 0.0 else 0.235, 0.04, 16, BRASS if z != -0.08 else IRON)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.065, 0.065, CHEEK * 2.0, 10, bronze.lightened(0.1))
	for s: float in [-1.0, 1.0]: # lifting dolphins
		var a := Vector3(s * 0.07, 0.23, 0.08)
		var b := Vector3(s * 0.07, 0.23, -0.14)
		_rod(gun, a, a + Vector3(0, 0.08, -0.04), 0.02, BRASS, 5)
		_rod(gun, a + Vector3(0, 0.08, -0.04), b + Vector3(0, 0.08, 0.04), 0.02, BRASS, 5)
		_rod(gun, b + Vector3(0, 0.08, 0.04), b, 0.02, BRASS, 5)
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.235, 0.22)), 0.04, 0.05, 0.03, 8, BRASS) # touch-hole pan
	return {"muzzle": Vector3(0, 0, -0.66), "muzzle_r": 0.27, "recoil": 0.14, "breech": Vector3(0.06, 0.235, 0.22)}


## Nozzle: a big brass fire-hose nozzle with a lever valve, fed by a hose from a
## pressure tank slung underneath (with a gauge and a pump handle).
static func _nozzle(gun: SurfaceTool) -> Dictionary:
	MeshKit.lathe(gun, Transform3D(ALONG, Vector3.ZERO), [Vector2(0.09, 0.2), Vector2(0.11, 0.17), Vector2(0.11, 0.0),
			Vector2(0.095, -0.12), Vector2(0.07, -0.5), Vector2(0.05, -0.76), Vector2(0.06, -0.79), Vector2(0.06, -0.86),
			Vector2(0.03, -0.87)], 12, BRASS)
	for z: float in [0.08, -0.06, -0.3]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.112 if z > -0.1 else 0.088, 0.112 if z > -0.1 else 0.088, 0.035, 12, Color("#6B3A22") if z > -0.1 else BRASS.darkened(0.3))
	MeshKit.add_cylinder(gun, _t(Vector3(0, 0.12, -0.02)), 0.02, 0.02, 0.06, 6, IRON) # valve lever
	_beam(gun, Vector3(0, 0.15, -0.02), Vector3(0, 0.19, 0.22), Vector2(0.03, 0.015), IRON)
	MeshKit.add_ellipsoid(gun, _t(Vector3(0, 0.19, 0.23)), Vector3(0.025, 0.025, 0.03), 3, 6, RED_STICK)
	# Pressure tank underneath, strapped on, with domed ends.
	var tc := Color("#7A3B2E")
	var tz := 0.3
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, -0.2, tz)), 0.12, 0.12, 0.42, 12, tc, false)
	for z: float in [tz - 0.21, tz + 0.21]:
		MeshKit.add_ellipsoid(gun, _t(Vector3(0, -0.2, z)), Vector3(0.12, 0.12, 0.07), 4, 12, tc)
	for z: float in [tz - 0.12, tz + 0.12]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, -0.2, z)), 0.125, 0.125, 0.03, 12, IRON)
		_beam(gun, Vector3(0, -0.08, z), Vector3(0, 0.02, z), Vector2(0.03, 0.02), IRON)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.12, -0.17, tz)), 0.045, 0.045, 0.03, 10, BRASS) # gauge
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.137, -0.17, tz)), 0.035, 0.035, 0.004, 10, Palette.BONE)
	_beam(gun, Vector3(0.14, -0.17, tz), Vector3(0.14, -0.145, tz - 0.015), Vector2(0.006, 0.004), RED_STICK)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, -0.2, tz + 0.32)), 0.015, 0.015, 0.2, 6, IRON) # pump rod
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0, -0.2, tz + 0.42)), 0.022, 0.022, 0.16, 6, Palette.WOOD)
	# Hose from the tank's front, looping up into the nozzle's tail.
	MeshKit.tube(gun, [Vector3(0, -0.2, tz - 0.27), Vector3(0, -0.24, 0.0), Vector3(0, -0.18, -0.12),
			Vector3(0, -0.06, -0.12), Vector3(0, -0.03, -0.05)], [0.035], 7, RUBBER)
	return {"muzzle": Vector3(0, 0, -0.9), "muzzle_r": 0.07, "recoil": 0.05, "breech": Vector3(0.1, -0.2, tz)}


# ------------------------------------------------------------------ loads

## The load's ammo piece standing on the shelf at `at` (its base centre).
static func _load_piece(st: SurfaceTool, load: StringName, at: Vector3, tint: Color, rng: RandomNumberGenerator) -> void:
	match load:
		&"explosive":
			_dynamite_crate(st, at, tint, rng)
		&"fire":
			_fuel_tank(st, at, tint)
		&"acid":
			_acid_jugs(st, at, tint)
		_:
			_ammo_box(st, at, tint)


## Lead: a steel ammo box with a hinged lid, latch and handle, a lead-grey band.
static func _ammo_box(st: SurfaceTool, at: Vector3, tint: Color) -> void:
	var green := Color("#5E6640")
	MeshKit.add_box(st, _t(at + Vector3(0, 0.1, 0)), Vector3(0.24, 0.2, 0.3), green)
	MeshKit.add_box(st, _t(at + Vector3(0, 0.205, 0)), Vector3(0.25, 0.03, 0.31), green.darkened(0.25))
	MeshKit.add_box(st, _t(at + Vector3(0, 0.1, 0)), Vector3(0.245, 0.05, 0.305), tint)
	MeshKit.add_box(st, _t(at + Vector3(0.123, 0.17, 0)), Vector3(0.012, 0.06, 0.05), BRASS) # latch
	_rod(st, at + Vector3(0, 0.22, -0.08), at + Vector3(0, 0.27, -0.04), 0.012, IRON, 4)
	_rod(st, at + Vector3(0, 0.27, -0.04), at + Vector3(0, 0.27, 0.04), 0.012, IRON, 4)
	_rod(st, at + Vector3(0, 0.27, 0.04), at + Vector3(0, 0.22, 0.08), 0.012, IRON, 4)


## Explosive: a wooden crate, red label, a bundle of red sticks with white fuses.
static func _dynamite_crate(st: SurfaceTool, at: Vector3, tint: Color, rng: RandomNumberGenerator) -> void:
	MeshKit.add_box(st, _t(at + Vector3(0, 0.09, 0)), Vector3(0.28, 0.18, 0.3), Palette.WOOD, 0.01, rng)
	for y: float in [0.025, 0.165]:
		MeshKit.add_box(st, _t(at + Vector3(0, y, 0)), Vector3(0.29, 0.03, 0.31), Palette.WOOD_DARK)
	MeshKit.add_box(st, _t(at + Vector3(0.142, 0.095, 0)), Vector3(0.01, 0.09, 0.18), tint)
	MeshKit.add_box(st, _t(at + Vector3(0.148, 0.095, 0)), Vector3(0.004, 0.05, 0.05), Palette.OUTLINE) # the skull-ish mark
	for i in 7:
		var p := at + Vector3(-0.07 + (i % 3) * 0.07, 0.24, -0.08 + floori(i / 3.0) * 0.08)
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.18))
		MeshKit.add_cylinder(st, Transform3D(lean, p), 0.03, 0.03, 0.26, 7, RED_STICK)
		var tip := p + lean * Vector3(0, 0.13, 0)
		_rod(st, tip, tip + Vector3(rng.randf_range(-0.04, 0.04), 0.07, rng.randf_range(-0.04, 0.04)), 0.006, Palette.BONE, 3)


## Fire: a riveted fuel tank with a domed top, valve wheel and a gauge, in the load colour.
static func _fuel_tank(st: SurfaceTool, at: Vector3, tint: Color) -> void:
	var c := tint.darkened(0.15)
	MeshKit.add_cylinder(st, _t(at + Vector3(0, 0.15, 0)), 0.125, 0.125, 0.3, 12, c, false)
	MeshKit.add_ellipsoid(st, _t(at + Vector3(0, 0.3, 0)), Vector3(0.125, 0.07, 0.125), 4, 12, c)
	MeshKit.add_cylinder(st, _t(at + Vector3(0, 0.01, 0)), 0.13, 0.13, 0.02, 12, IRON)
	for y: float in [0.06, 0.24]:
		MeshKit.add_cylinder(st, _t(at + Vector3(0, y, 0)), 0.13, 0.13, 0.025, 12, IRON)
	MeshKit.add_box(st, _t(at + Vector3(0, 0.15, -0.126)), Vector3(0.12, 0.07, 0.01), Palette.BONE) # FUEL plate
	MeshKit.add_box(st, _t(at + Vector3(0, 0.15, -0.13)), Vector3(0.08, 0.02, 0.006), Palette.OUTLINE)
	MeshKit.add_cylinder(st, _t(at + Vector3(0, 0.39, 0)), 0.015, 0.015, 0.06, 6, BRASS)
	_hoop(st, at + Vector3(0, 0.42, 0), Vector3.UP, 0.055, 0.009, RED_STICK, 8)
	for i in 2:
		_rod(st, at + Vector3(0, 0.42, 0), at + Vector3(0, 0.42, 0) + Vector3(cos(i * PI * 0.5), 0, sin(i * PI * 0.5)) * 0.05, 0.006, RED_STICK, 3)
		_rod(st, at + Vector3(0, 0.42, 0), at + Vector3(0, 0.42, 0) - Vector3(cos(i * PI * 0.5), 0, sin(i * PI * 0.5)) * 0.05, 0.006, RED_STICK, 3)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(0.13, 0.2, 0.0)), 0.035, 0.035, 0.02, 8, BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(0.141, 0.2, 0.0)), 0.027, 0.027, 0.003, 8, Palette.BONE)


## Acid: two green glass jugs with corks in a wire rack.
static func _acid_jugs(st: SurfaceTool, at: Vector3, tint: Color) -> void:
	var glass := tint.lightened(0.05)
	for k in 2:
		var p := at + Vector3(0.0, 0.0, -0.075 + k * 0.15)
		var s := 1.0 if k == 0 else 0.85
		MeshKit.lathe(st, _t(p), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.075, 0.03), Vector2(0.075, 0.12),
				Vector2(0.06, 0.17), Vector2(0.025, 0.21), Vector2(0.022, 0.24)].map(func(v: Vector2) -> Vector2: return v * s), 10, glass, Vector2.ONE, 0.35)
		MeshKit.add_cylinder(st, _t(p + Vector3(0, 0.25 * s, 0)), 0.02 * s, 0.024 * s, 0.035, 6, Palette.WOOD) # cork
		var h0 := p + Vector3(0.05, 0.17, 0) * s
		_rod(st, h0, h0 + Vector3(0.04, -0.02, 0) * s, 0.01, glass.darkened(0.2), 4) # jug handle
		_rod(st, h0 + Vector3(0.04, -0.02, 0) * s, p + Vector3(0.075, 0.11, 0) * s, 0.01, glass.darkened(0.2), 4)
		MeshKit.add_cylinder(st, _t(p + Vector3(0, 0.08 * s, 0)), 0.077 * s, 0.077 * s, 0.03, 10, Color("#C8A878")) # wicker band
	for x: float in [-0.09, 0.09]: # wire rack
		for z: float in [-0.16, 0.16]:
			MeshKit.add_cylinder(st, _t(at + Vector3(x, 0.07, z)), 0.008, 0.008, 0.14, 4, IRON)
	for z: float in [-0.16, 0.16]:
		_rod(st, at + Vector3(-0.09, 0.14, z), at + Vector3(0.09, 0.14, z), 0.008, IRON, 4)
	for x: float in [-0.09, 0.09]:
		_rod(st, at + Vector3(x, 0.14, -0.16), at + Vector3(x, 0.14, 0.16), 0.008, IRON, 4)


## The feed from the load piece to the gun's breech: the head part runs to a
## point on the pitch axis (which never moves) and the gun part from there, so
## the line stays joined at any pitch.
static func _load_feed(head: SurfaceTool, gun: SurfaceTool, load: StringName, slot: Vector3, gun_y: float, breech: Vector3, tint: Color) -> void:
	var hub_g := Vector3(CHEEK + 0.1, 0, 0) # on the pitch axis, just outside the right cheek
	var hub_h := hub_g + Vector3(0, gun_y, 0)
	var top := slot + Vector3(0, 0.24, 0)
	match load:
		&"lead":
			top = slot + Vector3(-0.02, 0.21, -0.06)
		&"explosive":
			top = slot + Vector3(-0.05, 0.36, 0.0)
		&"fire":
			top = slot + Vector3(0, 0.42, 0)
		&"acid":
			top = slot + Vector3(0, 0.25, -0.075)
	var mid_h := (top + hub_h) * 0.5 + Vector3(0.06, 0.12, 0)
	var mid_g := hub_g + Vector3(0, 0.1, 0.24) # round behind the cheek
	match load:
		&"lead": # a cloth belt of brass cartridges
			_belt(head, [top, mid_h, hub_h])
			_belt(gun, [hub_g, mid_g, breech])
			MeshKit.add_cylinder(gun, Transform3D(ACROSS, hub_g), 0.035, 0.035, 0.05, 8, BRASS)
		&"explosive": # a white fuse cord, and a stick clipped at the breech
			MeshKit.tube(head, [top, mid_h, hub_h], [0.012], 5, Palette.BONE)
			MeshKit.tube(gun, [hub_g, mid_g, breech], [0.012], 5, Palette.BONE)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, breech + Vector3(0.035, 0.0, 0.02)), 0.03, 0.03, 0.2, 7, RED_STICK)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, breech + Vector3(0.035, 0.0, 0.02)), 0.033, 0.033, 0.03, 7, IRON)
			MeshKit.add_cylinder(gun, Transform3D(ACROSS, hub_g), 0.025, 0.025, 0.04, 8, BRASS)
		&"fire": # a rubber fuel hose
			MeshKit.tube(head, [top, top + Vector3(0, 0.08, 0), mid_h, hub_h], [0.028], 6, RUBBER)
			MeshKit.tube(gun, [hub_g, mid_g, breech], [0.028], 6, RUBBER)
			MeshKit.add_cylinder(gun, Transform3D(ACROSS, hub_g), 0.04, 0.04, 0.05, 8, BRASS)
		&"acid": # a green glass drip line
			MeshKit.tube(head, [top, top + Vector3(0, 0.06, 0), mid_h, hub_h], [0.016], 6, tint.lightened(0.2), 0.3)
			MeshKit.tube(gun, [hub_g, mid_g, breech], [0.016], 6, tint.lightened(0.2), 0.3)
			MeshKit.add_cylinder(gun, Transform3D(ACROSS, hub_g), 0.03, 0.03, 0.05, 8, BRASS)


## Brass cartridges on a canvas belt along a curve through `pts`.
static func _belt(st: SurfaceTool, pts: Array) -> void:
	MeshKit.tube(st, pts, [0.012], 4, Color("#A89670"))
	var n := 4
	for i in n + 1:
		var t := float(i) / n
		var p := _bez(pts, t)
		var d := (_bez(pts, minf(t + 0.05, 1.0)) - _bez(pts, maxf(t - 0.05, 0.0))).normalized()
		var side := d.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.FORWARD
		var b := MeshKit.basis_from_y(side)
		MeshKit.add_cylinder(st, Transform3D(b, p), 0.016, 0.016, 0.07, 5, BRASS, false)
		MeshKit.add_cylinder(st, Transform3D(b, p + side * 0.05), 0.015, 0.0, 0.03, 5, Color("#8A8F96"), false)


static func _bez(pts: Array, t: float) -> Vector3:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[1]
	var c: Vector3 = pts[2]
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## A touch of the load on the gun itself, near the muzzle.
static func _load_accent(gun: SurfaceTool, load: StringName, muzzle: Vector3, mr: float, tint: Color) -> void:
	match load:
		&"lead": # a lead-grey band behind the muzzle
			MeshKit.add_cylinder(gun, Transform3D(ALONG, muzzle + Vector3(0, 0, 0.16)), mr + 0.012, mr + 0.012, 0.035, 10, tint)
		&"explosive": # a red warning band and a little brass blast cap
			MeshKit.add_cylinder(gun, Transform3D(ALONG, muzzle + Vector3(0, 0, 0.16)), mr + 0.012, mr + 0.012, 0.05, 10, tint)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, muzzle + Vector3(0, 0, 0.215)), mr + 0.016, mr + 0.016, 0.015, 10, BRASS)
		&"fire": # a pilot burner under the muzzle with its little flame
			var burner := muzzle + Vector3(0, -mr - 0.05, 0.12)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, burner), 0.018, 0.018, 0.22, 6, IRON)
			_beam(gun, burner + Vector3(0, 0, 0.08), burner + Vector3(0, mr + 0.03, 0.08), Vector2(0.02, 0.02), IRON)
			MeshKit.add_ellipsoid(gun, _t(burner + Vector3(0, 0.0, -0.15)), Vector3(0.03, 0.03, 0.06), 3, 6, tint, 0.0, null, 0.9)
			MeshKit.add_ellipsoid(gun, _t(burner + Vector3(0, 0.0, -0.13)), Vector3(0.016, 0.016, 0.035), 3, 6, Palette.GLOW_YELLOW, 0.0, null, 1.0)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, muzzle + Vector3(0, 0, 0.16)), mr + 0.012, mr + 0.012, 0.035, 10, tint)
		&"acid": # a glass drip tube along the top ending in a glowing drop
			var top := muzzle + Vector3(0, mr + 0.025, 0.0)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, top + Vector3(0, 0, 0.25)), 0.014, 0.014, 0.5, 6, tint.lightened(0.2), false, 0.3)
			MeshKit.add_ellipsoid(gun, _t(top + Vector3(0, -0.015, -0.01)), Vector3(0.02, 0.03, 0.02), 3, 6, Palette.ACID_GREEN, 0.0, null, 0.8)
			MeshKit.add_cylinder(gun, Transform3D(ALONG, muzzle + Vector3(0, 0, 0.16)), mr + 0.012, mr + 0.012, 0.035, 10, tint.darkened(0.2))
