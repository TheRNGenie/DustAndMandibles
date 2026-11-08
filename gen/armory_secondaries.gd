class_name ArmorySecondaries
extends RefCounted
## The ten new secondaries (Weapon Slots Redesign, section 7 prompts), built in
## code. See ArmoryGuns for the conventions; helpers and colours are
## FrontierGuns' (F) and WeaponBuilder's (W).
##
## Moving parts (each hung on its pivot in PIVOTS, built where it sits at rest):
##   screamer_pistol, flashbang_pistol, pepper_bomb_pistol, caltrops_launcher:
##                        "barrels" tip down about the hinge under the breech
##   tar_sprayer:         "pump" (plunger and T-handle) slides along Z
##   concussion_pistol:   "hammer" turns about X
##   chain_binder:        "drum" (with its coiled chain) spins about X, "anchor" flies out
##   rust_duster:         "bellows" (top board) and "pleats" (leather) hinge about X;
##                        they are built OPEN by DUSTER_OPEN, so squeezing turns them +X
##   glow_worm_launcher:  "cork" pops out of the muzzle
##   phosphor_grenade:    "shell" sits in the can's mouth and leaves along -Z

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")
const AP := preload("res://gen/armory_primaries.gd")

const NAMES: Dictionary = {
	&"screamer_pistol": "Screamer Pistol", &"tar_sprayer": "Tar Sprayer", &"flashbang_pistol": "Flashbang Pistol",
	&"pepper_bomb_pistol": "Pepper-Bomb Pistol", &"concussion_pistol": "Concussion Pistol", &"chain_binder": "Chain Binder",
	&"rust_duster": "Rust Duster", &"glow_worm_launcher": "Glow-Worm Launcher", &"caltrops_launcher": "Caltrops Launcher",
	&"phosphor_grenade": "Phosphor Grenade",
}
const PIVOTS: Dictionary = {
	"screamer_pistol_barrels": Vector3(0.0, 0.0, -0.036),
	"tar_sprayer_pump": Vector3(0.0, -0.07, -0.252),
	"flashbang_pistol_barrels": Vector3(0.0, 0.0, -0.036),
	"pepper_bomb_pistol_barrels": Vector3(0.0, -0.002, -0.036),
	"concussion_pistol_hammer": Vector3(0.0, 0.042, 0.03),
	"chain_binder_drum": Vector3(0.0, -0.05, -0.115),
	"chain_binder_anchor": Vector3(0.0, 0.04, -0.3),
	"rust_duster_bellows": Vector3(0.0, 0.012, -0.058),
	"rust_duster_pleats": Vector3(0.0, 0.012, -0.058),
	"glow_worm_launcher_cork": Vector3(0.0, 0.038, -0.378),
	"caltrops_launcher_barrels": Vector3(0.0, -0.004, -0.04),
	"phosphor_grenade_shell": Vector3(0.0, 0.034, -0.16),
}
## The duster's top board and pleats rest open by this much (radians about -X).
const DUSTER_OPEN := 0.27
const MUZZLE: Dictionary = {
	&"screamer_pistol": Vector3(0.0, 0.026, -0.222),
	&"tar_sprayer": Vector3(0.0, 0.018, -0.374),
	&"flashbang_pistol": Vector3(0.0, 0.028, -0.21),
	&"pepper_bomb_pistol": Vector3(0.0, 0.026, -0.174),
	&"concussion_pistol": Vector3(0.0, 0.03, -0.166),
	&"chain_binder": Vector3(0.0, 0.04, -0.305),
	&"rust_duster": Vector3(0.0, -0.007, -0.338),
	&"glow_worm_launcher": Vector3(0.0, 0.038, -0.4),
	&"caltrops_launcher": Vector3(0.0, 0.03, -0.182),
	&"phosphor_grenade": Vector3(0.0, 0.034, -0.226),
}
## [right fist centre, right grip axis (bottom of the grip toward its top), left fist centre].
const HANDS: Dictionary = {
	&"screamer_pistol": [Vector3(0.0, -0.052, 0.068), Vector3(0, 0.917, -0.4), Vector3(-0.018, -0.082, 0.05)],
	&"tar_sprayer": [Vector3(0.0, -0.05, 0.054), Vector3(0, 0.917, -0.4), Vector3(0.0, -0.07, -0.298)],
	&"flashbang_pistol": [Vector3(0.0, -0.05, 0.056), Vector3(0, 0.95, -0.31), Vector3(-0.018, -0.08, 0.04)],
	&"pepper_bomb_pistol": [Vector3(0.0, -0.052, 0.068), Vector3(0, 0.917, -0.4), Vector3(-0.018, -0.082, 0.05)],
	&"concussion_pistol": [Vector3(0.0, -0.038, 0.094), Vector3(0, 0.95, -0.31), Vector3(-0.016, -0.078, 0.08)],
	&"chain_binder": [Vector3(0.0, -0.052, 0.055), Vector3(0, 0.917, -0.4), Vector3(0.0, -0.035, -0.228)],
	&"rust_duster": [Vector3(0.0, -0.048, 0.072), Vector3(0, 0.96, -0.27), Vector3(0.0, 0.07, 0.088)],
	&"glow_worm_launcher": [Vector3(0.0, -0.05, 0.064), Vector3(0, 0.917, -0.4), Vector3(0.0, 0.0, -0.27)],
	&"caltrops_launcher": [Vector3(0.0, -0.052, 0.068), Vector3(0, 0.917, -0.4), Vector3(0.0, -0.012, -0.11)],
	&"phosphor_grenade": [Vector3(0.0, -0.052, 0.066), Vector3(0, 0.917, -0.4), Vector3(0.0, -0.022, -0.1)],
}

const TAR := Color("#15100B")
const RUBBER := Color("#3A2A22")
const VERDIGRIS := Color("#4E9C86")
const VERDIGRIS_DARK := Color("#357564")
const VERDIGRIS_PALE := Color("#7DBFA8")
const CORK := Color("#B98A58")
const RUST_POWDER := Color("#D9752A")
const CHILI := Color("#7E1810")
const SHELL_RED := Color("#B8261B")
const GRUB := Color("#C9F27A")
const GRUB_DIM := Color("#8FD86A")
const HAZARD := Color("#E2B21E")
const HICKORY := Color("#B4834E")
const OLIVE := Color("#56603B")
const MG_SILVER := Color("#E2E5EA")
const RED_GLASS := Color("#FF3A26")
const VASCULUM := Color("#3D5A3A")

## Lathe / turned shapes whose profile y runs toward -Z (the muzzle).
const FWD := Basis(Vector3.RIGHT, -PI * 0.5)


static func build(id: StringName) -> Dictionary:
	match id:
		&"screamer_pistol":
			return _screamer()
		&"tar_sprayer":
			return _tar_sprayer()
		&"flashbang_pistol":
			return _flashbang()
		&"pepper_bomb_pistol":
			return _pepper()
		&"concussion_pistol":
			return _concussion()
		&"chain_binder":
			return _chain_binder()
		&"rust_duster":
			return _rust_duster()
		&"glow_worm_launcher":
			return _glow_worm()
		&"caltrops_launcher":
			return _caltrops()
		&"phosphor_grenade":
			return _phosphor()
	return {}


# ------------------------------------------------------------------ shared bits

static func _turn(st: SurfaceTool, c: Vector3, profile: Array, col: Color, segs: int = 18) -> void:
	MeshKit.lathe(st, Transform3D(FWD, c), profile, segs, col)


## The dark disc inside a muzzle.
static func _bore(st: SurfaceTool, c: Vector3, r: float, segs: int = 14) -> void:
	F.cz(st, c, r, r, 0.0012, F.BORE, segs)


## A basis with Y along the surface normal `n` and X along `along` (flush decals, dials).
static func _flat(n: Vector3, along: Vector3) -> Basis:
	var y := n.normalized()
	var x := (along - y * along.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


## A thin flush blotch laid on a surface (patina, soot, decals).
static func _patch(st: SurfaceTool, p: Vector3, n: Vector3, along: Vector3, size: Vector2, col: Color) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(_flat(n, along), p), Vector3(size.x, 0.0006, size.y), 3, 10, col)


## A short pipe stub from a to b, its end lipped and dark (steam vents, ports).
static func _vent(k: F.Kit, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := (b - a).normalized()
	W.rod(k.m(), a, b, r, r, 8, col)
	W.rod(k.m(), b - d * 0.002, b + d * 0.0005, r * 1.3, r * 1.3, 8, col.lightened(0.15))
	W.rod(k.x(), b + d * 0.0004, b + d * 0.0009, r * 0.75, r * 0.75, 8, F.BORE)


## A coil spring from a to b.
static func _coil(st: SurfaceTool, a: Vector3, b: Vector3, r: float, turns: float, wire: float, col: Color) -> void:
	var ax := (b - a).normalized()
	var u := (Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).cross(ax).normalized()
	var v := ax.cross(u)
	var n := int(turns * 12.0)
	var pts: Array = []
	var radii: Array = []
	for i in n + 1:
		var t := float(i) / n
		var ang := t * turns * TAU
		pts.append(a.lerp(b, t) + (u * cos(ang) + v * sin(ang)) * r)
		radii.append(wire)
	MeshKit.tube(st, pts, radii, 6, col)


## One chain link: a stadium loop centred on c, long along t, in the plane of t and n.
static func _link(st: SurfaceTool, c: Vector3, t: Vector3, n: Vector3, col: Color, half: float = 0.0042, e: float = 0.0033, wire: float = 0.0019) -> void:
	var pts: Array = []
	var radii: Array = []
	for j in 5:
		var ang := -PI * 0.5 + PI * float(j) / 4.0
		pts.append(c + t * (half + e * cos(ang)) + n * (e * sin(ang)))
	for j in 5:
		var ang := PI * 0.5 + PI * float(j) / 4.0
		pts.append(c + t * (-half + e * cos(ang)) + n * (e * sin(ang)))
	pts.append(pts[0])
	for i in pts.size():
		radii.append(wire)
	MeshKit.tube(st, pts, radii, 4, col)


## Checker band round a Z-axis cylinder: rows offset so the squares run in diagonals.
static func _hazard(st: SurfaceTool, c: Vector3, r: float, z0: float, z1: float, n: int, rows: int, ca: Color, cb: Color) -> void:
	for j in rows:
		var za := lerpf(z0, z1, float(j) / rows)
		var zb := lerpf(z0, z1, float(j + 1) / rows)
		for i in n:
			var a0 := TAU * float(i) / n
			var a1 := TAU * float(i + 1) / n
			var d0 := Vector3(cos(a0), sin(a0), 0)
			var d1 := Vector3(cos(a1), sin(a1), 0)
			var col := MeshKit.vcol(ca if (i + j) % 2 == 0 else cb)
			var p00 := c + d0 * r + Vector3(0, 0, za)
			var p10 := c + d1 * r + Vector3(0, 0, za)
			var p01 := c + d0 * r + Vector3(0, 0, zb)
			var p11 := c + d1 * r + Vector3(0, 0, zb)
			var o := (d0 + d1).normalized()
			MeshKit.tri(st, p00, p10, p11, d0, d1, d1, col, o)
			MeshKit.tri(st, p00, p11, p01, d0, d1, d0, col, o)


## A parabolic dish round the Z axis (vertex ring r0 at c, rim r1 `depth` ahead).
## `front`: the concave mirror face, facing the muzzle; otherwise its convex back.
static func _dish(st: SurfaceTool, c: Vector3, r0: float, r1: float, depth: float, col: Color, front: bool, segs: int = 24, rings: int = 5) -> void:
	var kk := depth / (r1 * r1 - r0 * r0)
	var vc := MeshKit.vcol(col)
	var grid: Array = []
	var norms: Array = []
	for j in rings + 1:
		var r := lerpf(r0, r1, float(j) / rings)
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		for i in segs:
			var a := TAU * float(i) / segs
			var x := cos(a) * r
			var y := sin(a) * r
			row.append(c + Vector3(x, y, -kk * (r * r - r0 * r0)))
			var g := Vector3(2.0 * kk * x, 2.0 * kk * y, 1.0).normalized()
			nrow.append(-g if front else g)
		grid.append(row)
		norms.append(nrow)
	for j in rings:
		for i in segs:
			var i1 := (i + 1) % segs
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i1]
			var cc: Vector3 = grid[j + 1][i1]
			var d: Vector3 = grid[j + 1][i]
			var na: Vector3 = norms[j][i]
			var nb: Vector3 = norms[j][i1]
			var nc: Vector3 = norms[j + 1][i1]
			var nd: Vector3 = norms[j + 1][i]
			MeshKit.tri(st, a, b, cc, na, nb, nc, vc, (na + nc).normalized())
			MeshKit.tri(st, a, cc, d, na, nc, nd, vc, (na + nc).normalized())


## Fine diamond chequering down both sides of a grip running top -> bottom.
static func _chequer(k: F.Kit, top: Vector3, bottom: Vector3, half_w: float, col: Color) -> void:
	var ax := (bottom - top).normalized()
	var fwd := Vector3(0, ax.z, -ax.y).normalized() * -1.0
	for side: float in [-1.0, 1.0]:
		for i in 6:
			for j in 3:
				var t := 0.22 + float(i) * 0.1
				var p := top.lerp(bottom, t) + fwd * (float(j) - 1.0) * 0.0062 + fwd * (0.003 if i % 2 == 0 else 0.0)
				F.box(k.w(), p + Vector3(side * half_w, 0, 0), Vector3(0.0008, 0.003, 0.003), col, Basis(Vector3.RIGHT, 0.785))


## A big spur hammer standing cocked behind the frame.
static func _spur_hammer(st: SurfaceTool, base: Vector3, col: Color, scale: float = 1.0) -> void:
	F.box(st, base + Vector3(0, 0.002, -0.002) * scale, Vector3(0.0095, 0.014, 0.013) * scale, col.darkened(0.15))
	W.bent(st, [base + Vector3(0, 0.004, 0.0) * scale, base + Vector3(0, 0.015, 0.004) * scale, base + Vector3(0, 0.024, 0.012) * scale,
			base + Vector3(0, 0.028, 0.021) * scale], 0.0042 * scale, col)
	F.box(st, base + Vector3(0, 0.029, 0.024) * scale, Vector3(0.013, 0.0045, 0.014) * scale, col.lightened(0.06), Basis(Vector3.RIGHT, -0.55))
	for i in 4:
		F.box(st, base + Vector3(0, 0.0315, 0.019 + i * 0.0032) * scale, Vector3(0.0135, 0.0008, 0.001) * scale, col.darkened(0.4), Basis(Vector3.RIGHT, -0.55))


# ------------------------------------------------------------------ screamer pistol

## A flare pistol rebored huge and fitted to howl: a blued barrel ending in a
## flared brass resonating bell with vanes in its throat, a brass whistle riding
## the barrel on two saddles fed by a pipe from the vent band, steam vent stubs
## and louvres down the sides, on a case-hardened frame with a chequered grip.
static func _screamer() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var by := 0.026
	var hinge: Vector3 = PIVOTS["screamer_pistol_barrels"]
	# --- barrel (tips down about the hinge)
	F.cz(b.m(), Vector3(0, by, -0.1), 0.0205, 0.0225, 0.14, F.BLUED, 18)
	F.cz(b.m(), Vector3(0, by, -0.042), 0.026, 0.026, 0.024, F.BLUED.darkened(0.18), 18)
	F.cz(b.m(), Vector3(0, by, -0.0545), 0.0268, 0.0268, 0.003, F.BRASS_DARK, 18)
	F.cz(b.m(), Vector3(0, by, -0.0295), 0.0175, 0.0175, 0.002, F.BRASS_LIGHT, 16)
	F.cz(b.x(), Vector3(0, by, -0.0285), 0.007, 0.007, 0.001, F.SIGNAL_RED, 10)
	F.box(b.m(), Vector3(0, 0.003, -0.042), Vector3(0.018, 0.02, 0.028), F.BLUED.darkened(0.25))
	F.cx(b.m(), hinge, 0.0055, 0.03, F.STEEL, 10)
	# Steam vent band: brass collar with three angled stubs a side.
	F.cz(b.m(), Vector3(0, by, -0.07), 0.0242, 0.0242, 0.018, F.BRASS, 18)
	for side: float in [-1.0, 1.0]:
		for i in 3:
			var z := -0.0635 - i * 0.0065
			_vent(b, Vector3(side * 0.018, by + 0.012, z), Vector3(side * 0.03, by + 0.025, z + 0.004), 0.0028, F.BRASS_LIGHT)
		# Louvred slots down the barrel side, each with a little brass eyebrow.
		for i in 4:
			var z := -0.096 - i * 0.014
			F.box(b.x(), Vector3(side * 0.0212, by + 0.004, z), Vector3(0.0016, 0.004, 0.009), F.BORE)
			F.box(b.m(), Vector3(side * 0.0214, by + 0.0072, z), Vector3(0.002, 0.0014, 0.0105), F.BRASS_DARK)
	# The whistle: a brass pipe on two saddles, a fipple window and labium on top.
	var wy := by + 0.032
	F.cz(b.m(), Vector3(0, wy, -0.116), 0.0078, 0.0078, 0.07, F.BRASS_LIGHT, 14)
	F.cz(b.m(), Vector3(0, wy, -0.1525), 0.0086, 0.0086, 0.004, F.BRASS_DARK, 14)
	F.cz(b.m(), Vector3(0, wy, -0.077), 0.0058, 0.0074, 0.009, F.BRASS, 12)
	for z: float in [-0.108, -0.135]:
		F.cz(b.m(), Vector3(0, wy, z), 0.0086, 0.0086, 0.003, F.BRASS_DARK, 14)
	for z: float in [-0.095, -0.14]:
		F.box(b.m(), Vector3(0, by + 0.0235, z), Vector3(0.007, 0.007, 0.007), F.BRASS_DARK)
	F.box(b.x(), Vector3(0, wy + 0.0072, -0.0885), Vector3(0.0055, 0.0016, 0.007), F.BORE)
	F.box(b.m(), Vector3(0, wy + 0.0074, -0.0935), Vector3(0.0062, 0.0014, 0.004), F.BRASS_LIGHT.lightened(0.15), Basis(Vector3.RIGHT, 0.35))
	W.bent(b.m(), [Vector3(0, wy, -0.073), Vector3(0, wy - 0.002, -0.068), Vector3(0, by + 0.022, -0.066)], 0.0026, F.BRASS)
	# The bell: flared brass, a rolled lip, vanes across its throat.
	var bell := Vector3(0, by, -0.165)
	_turn(b.m(), bell, [Vector2(0.021, 0.0), Vector2(0.022, 0.012), Vector2(0.025, 0.024), Vector2(0.031, 0.036),
			Vector2(0.04, 0.046), Vector2(0.046, 0.052), Vector2(0.0472, 0.0552), Vector2(0.0445, 0.0565),
			Vector2(0.038, 0.051), Vector2(0.029, 0.04), Vector2(0.021, 0.027), Vector2(0.0165, 0.012), Vector2(0.0165, 0.004)], F.BRASS, 22)
	F.hoop(b.m(), bell + Vector3(0, 0, -0.055), Vector3(0, 0, 1), 0.0462, 0.0022, F.BRASS_LIGHT, 22)
	F.hoop(b.m(), bell + Vector3(0, 0, -0.018), Vector3(0, 0, 1), 0.0236, 0.0018, F.BRASS_DARK, 18)
	F.hoop(b.m(), bell + Vector3(0, 0, -0.034), Vector3(0, 0, 1), 0.0298, 0.0016, F.BRASS_DARK, 18)
	_bore(b.x(), bell + Vector3(0, 0, -0.004), 0.0166)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		F.box(b.m(), bell + Vector3(cos(a) * 0.016, sin(a) * 0.016, -0.026), Vector3(0.016, 0.0013, 0.03), F.BRASS_DARK, Basis(Vector3.BACK, a))
	F.cz(b.m(), bell + Vector3(0, 0, -0.026), 0.0045, 0.0045, 0.032, F.BRASS_LIGHT, 10)
	F.ball(b.m(), bell + Vector3(0, 0, -0.043), Vector3.ONE * 0.005, F.BRASS_LIGHT, 4, 10)
	F.box(b.m(), Vector3(0, by + 0.0225, -0.158), Vector3(0.003, 0.006, 0.01), F.BLUED.darkened(0.2))
	# --- frame: case-hardened, round standing breech, hinge fork, top latch.
	AP.case_block(k, Vector3(0, 0.014, 0.012), Vector3(0.034, 0.054, 0.05), 21)
	F.cz(k.m(), Vector3(0, by, -0.021), 0.0262, 0.0262, 0.018, AP.CASE[0], 18)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0125, 0.0, -0.034), Vector3(0.007, 0.018, 0.024), AP.CASE[2])
		F.screw(k.m(), Vector3(side * 0.016, 0.0, -0.034), side, F.STEEL)
		W.scroll(k.m(), Vector3(side * 0.0172, 0.008, 0.014), Vector3(side, 0, 0), 0.03, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.0171, 0.03, 0.03), side, F.BRASS_LIGHT)
	F.box(k.m(), Vector3(0, 0.0425, 0.004), Vector3(0.012, 0.005, 0.034), AP.CASE[1])
	F.box(k.m(), Vector3(-0.009, 0.0445, 0.022), Vector3(0.02, 0.005, 0.008), F.IRON_DARK, Basis(Vector3.UP, 0.3))
	_spur_hammer(k.m(), Vector3(0, 0.036, 0.034), F.IRON)
	F.trigger_and_guard(k, Vector3(0, -0.019, 0.02), 0.028, F.BRASS)
	var gt := Vector3(0, -0.008, 0.048)
	var gb := Vector3(0, -0.1, 0.088)
	F.pistol_grip(k, gt, gb, F.WALNUT, F.IRON_DARK, 1.08)
	_chequer(k, gt, gb, 0.0136, F.WALNUT.darkened(0.2))
	F.hoop(k.m(), Vector3(0, -0.117, 0.093), Vector3(1, 0, 0), 0.008, 0.002, F.BRASS, 12)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ tar sprayer

## A pest-control pump sprayer that holds like a gun: a brass valve body with a
## handwheel and a pistol grip, a copper wand ending in a tar-fouled fan
## nozzle, and slung under it a riveted copper canister with a pressure gauge,
## a T-handled pump plunger at its front and a rubber hose looping back up.
static func _tar_sprayer() -> Dictionary:
	var k := F.Kit.new()
	var p := F.Kit.new()
	var wy := 0.018
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# --- valve body, handwheel, grip and squeeze trigger
	F.box(k.m(), Vector3(0, 0.008, 0.005), Vector3(0.026, 0.03, 0.07), F.BRASS_DARK)
	F.cz(k.m(), Vector3(0, wy, -0.012), 0.016, 0.016, 0.05, F.BRASS, 16)
	F.cz(k.m(), Vector3(0, wy, -0.038), 0.0175, 0.0175, 0.004, F.BRASS_LIGHT, 16)
	F.cz(k.m(), Vector3(0, wy, 0.0145), 0.0172, 0.0172, 0.004, F.BRASS_LIGHT, 16)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, 0.038, -0.014)), 0.0095, 0.008, 0.014, 12, F.BRASS_DARK)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, 0.049, -0.014)), 0.0026, 0.0026, 0.012, 8, F.STEEL)
	F.hoop(k.m(), Vector3(0, 0.054, -0.014), Vector3.UP, 0.0135, 0.0022, F.IRON_DARK, 16)
	for i in 4:
		var a := TAU * float(i) / 4.0
		W.rod(k.m(), Vector3(0, 0.054, -0.014), Vector3(cos(a) * 0.0135, 0.054, -0.014 + sin(a) * 0.0135), 0.0016, 0.0016, 5, F.IRON_DARK)
	F.ball(k.m(), Vector3(0, 0.056, -0.014), Vector3(0.004, 0.003, 0.004), F.BRASS_LIGHT, 3, 8)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.0132, 0.004, 0.028), side, F.BRASS_LIGHT)
		W.scroll(k.m(), Vector3(side * 0.0132, 0.006, 0.006), Vector3(side, 0, 0), 0.02, F.BRASS_LIGHT)
	F.trigger_and_guard(k, Vector3(0, -0.017, 0.012), 0.025, F.BRASS)
	W.bent(k.m(), [Vector3(0, -0.006, 0.0), Vector3(0, -0.02, -0.002), Vector3(0, -0.032, 0.004)], 0.0032, F.STEEL)
	F.pistol_grip(k, Vector3(0, -0.006, 0.034), Vector3(0, -0.098, 0.074), F.WALNUT, F.BRASS_DARK)
	# --- the wand: copper pipe, hex couplings, a tar-fouled fan nozzle
	F.cz(k.m(), Vector3(0, wy, -0.19), 0.0072, 0.0072, 0.3, F.COPPER, 12)
	for z: float in [-0.044, -0.334]:
		F.cz(k.m(), Vector3(0, wy, z), 0.0108, 0.0108, 0.012, F.BRASS, 6)
	F.cz(k.m(), Vector3(0, wy, -0.352), 0.0048, 0.0102, 0.024, F.BRASS, 12)
	F.box(k.m(), Vector3(0, wy, -0.368), Vector3(0.017, 0.0048, 0.009), F.BRASS_DARK)
	F.box(k.x(), Vector3(0, wy, -0.3728), Vector3(0.013, 0.0013, 0.001), F.BORE)
	for i in 14:
		var z := rng.randf_range(-0.362, -0.336)
		var a := rng.randf_range(0.85 * PI, 2.15 * PI)
		var rc := lerpf(0.0048, 0.0102, (z + 0.364) / 0.024)
		var nrm := Vector3(cos(a), sin(a), 0.25).normalized()
		MeshKit.add_ellipsoid(k.m(), Transform3D(_flat(nrm, Vector3(0, 0, 1)), Vector3(cos(a) * rc, wy + sin(a) * rc, z)),
				Vector3(rng.randf_range(0.0025, 0.0045), 0.0013, rng.randf_range(0.004, 0.007)), 3, 8, TAR)
	F.box(k.m(), Vector3(0.0015, wy - 0.0006, -0.3682), Vector3(0.0135, 0.0058, 0.0072), TAR)
	F.ball(k.m(), Vector3(-0.002, wy - 0.006, -0.369), Vector3(0.0022, 0.0042, 0.0022), TAR, 4, 8)
	F.ball(k.m(), Vector3(-0.002, wy - 0.0098, -0.369), Vector3(0.0027, 0.0027, 0.0027), TAR, 3, 8)
	F.ball(k.m(), Vector3(0.001, wy - 0.0095, -0.35), Vector3(0.002, 0.0034, 0.002), TAR, 4, 8)
	for i in 8:
		var a := rng.randf_range(0.8 * PI, 2.2 * PI)
		var z := rng.randf_range(-0.33, -0.296)
		var nrm := Vector3(cos(a), sin(a), 0)
		MeshKit.add_ellipsoid(k.m(), Transform3D(_flat(nrm, Vector3(0, 0, 1)), Vector3(cos(a) * 0.0072, wy + sin(a) * 0.0072, z)),
				Vector3(rng.randf_range(0.002, 0.004), 0.0011, rng.randf_range(0.004, 0.01)), 3, 8, TAR)
	# --- canister: riveted copper, domed ends, brass bands, gauge, fill cap
	var c := Vector3(0, -0.07, -0.16)
	F.cz(k.m(), c, 0.04, 0.04, 0.16, F.COPPER, 20)
	F.ball(k.m(), c + Vector3(0, 0, 0.08), Vector3(0.04, 0.04, 0.018), F.COPPER.darkened(0.08), 5, 20)
	F.ball(k.m(), c + Vector3(0, 0, -0.08), Vector3(0.04, 0.04, 0.018), F.COPPER.darkened(0.08), 5, 20)
	for z: float in [0.074, -0.074]:
		F.cz(k.m(), c + Vector3(0, 0, z), 0.0414, 0.0414, 0.008, F.BRASS, 20)
	F.cz(k.m(), c, 0.0412, 0.0412, 0.006, F.BRASS_DARK, 20)
	for i in 10:
		var a := TAU * float(i) / 10.0
		for z: float in [0.074, -0.074]:
			F.ball(k.m(), c + Vector3(cos(a) * 0.0418, sin(a) * 0.0418, z), Vector3.ONE * 0.0021, F.BRASS_LIGHT, 3, 6)
	for i in 7:
		F.ball(k.m(), c + Vector3(-0.0402, -0.012, -0.06 + i * 0.02), Vector3.ONE * 0.0022, F.COPPER.lightened(0.2), 3, 6)
	F.box(k.m(), c + Vector3(-0.0398, -0.012, 0.0), Vector3(0.0012, 0.0024, 0.13), F.COPPER.darkened(0.2))
	# Old tar splashes down the canister front.
	for i in 5:
		var a := rng.randf_range(0.6, 2.6)
		_patch(k.m(), c + Vector3(cos(a) * 0.0402, sin(a) * 0.0402, rng.randf_range(-0.07, -0.03)), Vector3(cos(a), sin(a), 0), Vector3(0, 0, 1),
				Vector2(rng.randf_range(0.003, 0.006), rng.randf_range(0.004, 0.009)), TAR)
	# Fill cap on top, knurled.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), c + Vector3(0.0, 0.041, -0.055)), 0.011, 0.011, 0.008, 14, F.BRASS)
	for i in 8:
		var a := TAU * float(i) / 8.0
		F.box(k.m(), c + Vector3(cos(a) * 0.011, 0.041, -0.055 + sin(a) * 0.011), Vector3(0.0018, 0.0075, 0.0018), F.BRASS_DARK, Basis(Vector3.UP, -a))
	# The pressure gauge on a stem, facing up and back to the left.
	var base := c + Vector3(-0.025, 0.031, 0.045)
	var g := base + Vector3(-0.63, 0.78, 0.0) * 0.016
	var n := Vector3(-0.55, 0.62, 0.56).normalized()
	var gb := _flat(n, Vector3(0, 1, 0))
	W.rod(k.m(), base, g - n * 0.003, 0.0032, 0.0032, 8, F.BRASS_DARK)
	MeshKit.add_cylinder(k.m(), Transform3D(gb, g), 0.0182, 0.0182, 0.008, 20, F.BRASS)
	MeshKit.add_cylinder(k.x(), Transform3D(gb, g + n * 0.0041), 0.0152, 0.0152, 0.0008, 20, F.IVORY)
	F.hoop(k.m(), g + n * 0.0045, n, 0.0162, 0.0016, F.BRASS_LIGHT, 20)
	for i in 9:
		var a := lerpf(-0.75 * PI, 0.75 * PI, float(i) / 8.0) + PI * 0.5
		var dir := gb.x * cos(a) + gb.z * sin(a)
		var red := i >= 7
		MeshKit.add_ellipsoid(k.x(), Transform3D(_flat(n, dir), g + n * 0.0047 + dir * 0.0118), Vector3(0.0024 if red else 0.0016, 0.0004, 0.0007),
				2, 4, F.SIGNAL_RED if red else F.BORE)
	var needle := gb.x * cos(PI * 0.2) + gb.z * sin(PI * 0.2)
	W.rod(k.m(), g + n * 0.0052, g + n * 0.0052 + needle * 0.0115, 0.0009, 0.0004, 4, F.BORE)
	F.ball(k.m(), g + n * 0.0052, Vector3.ONE * 0.0016, F.BRASS_DARK, 3, 6)
	# Straps clamping canister to wand.
	for z: float in [-0.112, -0.208]:
		F.hoop(k.m(), Vector3(c.x, c.y, z), Vector3(0, 0, 1), 0.0418, 0.0024, F.IRON_DARK, 22)
		F.box(k.m(), Vector3(0, -0.006, z), Vector3(0.007, 0.05, 0.009), F.IRON_DARK)
		F.hoop(k.m(), Vector3(0, wy, z), Vector3(0, 0, 1), 0.0085, 0.0022, F.IRON_DARK, 12)
		F.screw(k.m(), Vector3(0.0035, -0.02, z), 1.0, F.STEEL)
	# Hose: an elbow from the canister's back, a rubber loop down the left, into the valve.
	var outlet := c + Vector3(-0.018, -0.014, 0.094)
	W.bent(k.m(), [c + Vector3(-0.018, -0.014, 0.08), outlet], 0.0055, F.BRASS)
	var hose := [outlet + Vector3(0, 0, 0.004), outlet + Vector3(-0.006, -0.008, 0.02), Vector3(-0.036, -0.094, -0.024),
		Vector3(-0.046, -0.074, -0.008), Vector3(-0.047, -0.044, -0.004), Vector3(-0.039, -0.014, -0.01), Vector3(-0.028, 0.004, -0.016),
		Vector3(-0.02, 0.013, -0.02)]
	var hr: Array = []
	for i in hose.size():
		hr.append(0.0062)
	MeshKit.tube(k.x(), hose, hr, 10, RUBBER)
	for e: Vector3 in [hose[0] as Vector3, hose[hose.size() - 1] as Vector3]:
		F.ball(k.m(), e, Vector3.ONE * 0.0078, F.BRASS_DARK, 4, 10)
	F.hoop(k.m(), (hose[1] as Vector3), Vector3(-0.3, -0.5, 0.8), 0.0068, 0.0016, F.STEEL, 10)
	F.hoop(k.m(), (hose[6] as Vector3), Vector3(0.6, 0.8, -0.3), 0.0068, 0.0016, F.STEEL, 10)
	F.cx(k.m(), Vector3(-0.0175, 0.013, -0.02), 0.006, 0.006, F.BRASS, 10)
	# Packing nut on the canister front.
	F.cz(k.m(), c + Vector3(0, 0, -0.094), 0.011, 0.013, 0.012, F.BRASS, 6)
	# --- the pump: plunger rod and a walnut T-handle (slides along Z)
	F.cz(p.m(), c + Vector3(0, 0, -0.123), 0.0042, 0.0042, 0.05, F.STEEL, 10)
	F.cz(p.m(), c + Vector3(0, 0, -0.146), 0.008, 0.006, 0.006, F.BRASS, 12)
	F.cx(p.w(), c + Vector3(0, 0, -0.138), 0.0085, 0.074, F.WALNUT_LIGHT, 12)
	for side: float in [-1.0, 1.0]:
		F.cx(p.m(), c + Vector3(side * 0.0385, 0, -0.138), 0.0094, 0.004, F.BRASS, 12)
	return {"body": k.commit(), "pump": p.commit()}


# ------------------------------------------------------------------ flashbang pistol

## A wide-bore brass break-action: a bulging chamber for magnesium shells (one
## seated, its silver head showing at the breech), a short fat barrel, and a
## polished parabolic reflector round it near the muzzle, ribbed and riveted
## behind; a tall brass frame with nickel side plates and a bone bird's-head grip.
static func _flashbang() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var by := 0.028
	var hinge: Vector3 = PIVOTS["flashbang_pistol_barrels"]
	# --- barrel group (tips down)
	_turn(b.m(), Vector3(0, by, -0.03), [Vector2(0.026, 0.0), Vector2(0.0305, 0.006), Vector2(0.032, 0.016), Vector2(0.032, 0.034),
			Vector2(0.0295, 0.044), Vector2(0.024, 0.052)], F.BRASS, 20)
	F.cz(b.m(), Vector3(0, by, -0.0315), 0.0262, 0.0262, 0.003, F.BRASS_DARK, 20)
	F.cz(b.m(), Vector3(0, by, -0.137), 0.0235, 0.0242, 0.11, F.BRASS, 20)
	F.cz(b.m(), Vector3(0, by, -0.205), 0.0262, 0.0252, 0.008, F.BRASS_LIGHT, 20)
	_bore(b.x(), Vector3(0, by, -0.2092), 0.0195, 16)
	for z: float in [-0.04, -0.064]:
		F.cz(b.m(), Vector3(0, by, z), 0.0328, 0.0328, 0.004, F.BRASS_DARK, 20)
	for i in 8:
		var a := TAU * float(i) / 8.0
		F.ball(b.m(), Vector3(cos(a) * 0.0332, by + sin(a) * 0.0332, -0.052), Vector3.ONE * 0.0022, F.NICKEL, 3, 6)
	# Magnesium shell head at the breech: silver rim, primer, a stamped ring.
	F.cz(b.m(), Vector3(0, by, -0.0295), 0.021, 0.021, 0.002, MG_SILVER, 18)
	F.cz(b.m(), Vector3(0, by, -0.0284), 0.0055, 0.0055, 0.001, F.COPPER, 10)
	F.hoop(b.m(), Vector3(0, by, -0.0284), Vector3(0, 0, 1), 0.013, 0.0009, MG_SILVER.darkened(0.3), 16)
	F.box(b.m(), Vector3(0, 0.004, -0.044), Vector3(0.02, 0.022, 0.028), F.BRASS_DARK)
	F.cx(b.m(), hinge, 0.0055, 0.032, F.NICKEL, 10)
	# The reflector: polished concave face forward, brass back with ribs and rivets.
	var dc := Vector3(0, by, -0.15)
	_dish(b.m(), dc, 0.0245, 0.062, 0.03, F.BRASS_DARK, false)
	_dish(b.m(), dc + Vector3(0, 0, -0.0018), 0.0245, 0.062, 0.03, Color("#F2F4F6"), true)
	F.hoop(b.m(), dc + Vector3(0, 0, -0.0312), Vector3(0, 0, 1), 0.0622, 0.0022, F.BRASS_LIGHT, 24)
	F.cz(b.m(), dc + Vector3(0, 0, 0.004), 0.027, 0.027, 0.012, F.BRASS_DARK, 20)
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		var d := Vector3(cos(a), sin(a), 0)
		W.rod(b.m(), dc + d * 0.026 + Vector3(0, 0, 0.002), dc + d * 0.06 + Vector3(0, 0, -0.026), 0.0018, 0.0014, 5, F.BRASS)
		F.ball(b.m(), dc + d * 0.0605 + Vector3(0, 0, -0.0296), Vector3.ONE * 0.0018, F.NICKEL, 3, 6)
	# A glint on the mirror.
	F.ball(b.g(), dc + Vector3(-0.03, 0.022, -0.0145), Vector3(0.006, 0.0035, 0.0008), Color("#FFFFFF"), 3, 8)
	F.box(b.m(), Vector3(0, by + 0.0255, -0.19), Vector3(0.003, 0.006, 0.012), F.NICKEL)
	# --- frame: tall brass casting, nickel side plates, standing breech
	F.box(k.m(), Vector3(0, 0.014, 0.01), Vector3(0.036, 0.058, 0.05), F.BRASS_DARK)
	F.cz(k.m(), Vector3(0, by, -0.022), 0.0268, 0.0268, 0.016, F.BRASS_DARK, 20)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0185, 0.014, 0.012), Vector3(0.0018, 0.04, 0.036), F.NICKEL)
		W.scroll(k.m(), Vector3(side * 0.0196, 0.014, 0.012), Vector3(side, 0, 0), 0.028, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.0194, 0.03, 0.026), side, F.BRASS_LIGHT)
		F.screw(k.m(), Vector3(side * 0.0194, -0.002, -0.002), side, F.BRASS_LIGHT)
		F.box(k.m(), Vector3(side * 0.0128, 0.0, -0.034), Vector3(0.007, 0.018, 0.024), F.BRASS_DARK)
	# Side latch, a broad flat hammer.
	F.box(k.m(), Vector3(-0.0195, 0.04, -0.008), Vector3(0.004, 0.009, 0.024), F.NICKEL)
	_spur_hammer(k.m(), Vector3(0, 0.038, 0.034), F.NICKEL.darkened(0.15), 1.1)
	F.trigger_and_guard(k, Vector3(0, -0.02, 0.016), 0.027, F.BRASS)
	# Bird's-head grip: bone panels on a brass strap, a lanyard ring at the head.
	var grip := [[Vector3(0, 0.0, 0.034), 0.017, 0.013], [Vector3(0, -0.03, 0.044), 0.019, 0.0136],
		[Vector3(0, -0.06, 0.058), 0.0196, 0.014], [Vector3(0, -0.084, 0.062), 0.017, 0.0132], [Vector3(0, -0.099, 0.052), 0.011, 0.0105]]
	W.loft(k.w(), grip, F.IVORY.darkened(0.06), 14)
	W.bent(k.m(), [Vector3(0, 0.012, 0.046), Vector3(0, -0.026, 0.063), Vector3(0, -0.06, 0.078), Vector3(0, -0.088, 0.076), Vector3(0, -0.104, 0.056)], 0.0046, F.BRASS)
	W.bent(k.m(), [Vector3(0, -0.012, 0.026), Vector3(0, -0.04, 0.03), Vector3(0, -0.07, 0.042), Vector3(0, -0.098, 0.046)], 0.004, F.BRASS)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.0142, -0.05, 0.052), side, F.BRASS_LIGHT)
	F.hoop(k.m(), Vector3(0, -0.11, 0.052), Vector3(1, 0, 0), 0.0075, 0.002, F.BRASS, 12)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ pepper-bomb pistol

## A stubby break-action grenade pistol: an open-sided chamber cage showing the
## red capsaicin shell inside, a fat short barrel with a red enamel band, a
## red glass sight on the frame, and a string of dried chillies off the butt.
static func _pepper() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var by := 0.026
	var hinge: Vector3 = PIVOTS["pepper_bomb_pistol_barrels"]
	# --- barrel group: chamber cage, shell, stubby barrel
	F.cz(b.m(), Vector3(0, by, -0.034), 0.0275, 0.0275, 0.008, F.BLUED.darkened(0.15), 20)
	F.cz(b.m(), Vector3(0, by, -0.078), 0.0285, 0.0285, 0.008, F.BLUED.darkened(0.15), 20)
	for a: float in [PI * 0.5, -PI * 0.5]:
		F.box(b.m(), Vector3(0, by + sin(a) * 0.0248, -0.056), Vector3(0.014, 0.006, 0.046), F.BLUED)
	F.cz(b.x(), Vector3(0, by, -0.055), 0.0212, 0.0212, 0.046, SHELL_RED, 18)
	F.cz(b.m(), Vector3(0, by, -0.0305), 0.0225, 0.0225, 0.004, F.BRASS, 18)
	F.cz(b.x(), Vector3(0, by, -0.058), 0.0216, 0.0216, 0.008, F.IVORY.darkened(0.05), 18)
	for i in 3:
		var a := PI + (float(i) - 1.0) * 0.5
		F.ball(b.x(), Vector3(cos(a) * 0.0218, by + sin(a) * 0.0218, -0.058), Vector3(0.0008, 0.0035, 0.0022), CHILI, 3, 6)
	F.cz(b.m(), Vector3(0, by, -0.126), 0.0272, 0.0285, 0.088, F.BLUED, 20)
	F.cz(b.x(), Vector3(0, by, -0.11), 0.0292, 0.0292, 0.012, SHELL_RED.darkened(0.1), 20)
	for z: float in [-0.103, -0.117]:
		F.cz(b.m(), Vector3(0, by, z), 0.0296, 0.0296, 0.0025, F.BRASS, 20)
	F.cz(b.m(), Vector3(0, by, -0.1715), 0.0296, 0.0275, 0.006, F.BLUED.lightened(0.15), 20)
	_bore(b.x(), Vector3(0, by, -0.1752), 0.0215, 16)
	F.ball(b.m(), Vector3(0, by + 0.03, -0.162), Vector3.ONE * 0.0028, F.BRASS_LIGHT, 4, 8)
	F.box(b.m(), Vector3(0, 0.002, -0.046), Vector3(0.02, 0.02, 0.026), F.BLUED.darkened(0.25))
	F.cx(b.m(), hinge, 0.0055, 0.03, F.STEEL, 10)
	# --- frame
	F.box(k.m(), Vector3(0, 0.013, 0.012), Vector3(0.034, 0.052, 0.05), F.BLUED)
	F.cz(k.m(), Vector3(0, by, -0.021), 0.0275, 0.0275, 0.018, F.BLUED.darkened(0.1), 20)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0125, -0.002, -0.034), Vector3(0.007, 0.018, 0.024), F.BLUED.darkened(0.1))
		W.scroll(k.m(), Vector3(side * 0.0172, 0.01, 0.014), Vector3(side, 0, 0), 0.03, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.0171, 0.028, 0.03), side)
	# The red glass sight: a brass tube on a post, lit red lenses at each end.
	F.box(k.m(), Vector3(0, 0.044, 0.008), Vector3(0.008, 0.012, 0.014), F.BRASS_DARK)
	F.cz(k.m(), Vector3(0, 0.058, 0.008), 0.0098, 0.0098, 0.024, F.BRASS, 16)
	for z: float in [-0.0045, 0.0205]:
		F.cz(k.m(), Vector3(0, 0.058, z), 0.0108, 0.0108, 0.003, F.BRASS_LIGHT, 16)
	F.cz(k.g(), Vector3(0, 0.058, -0.0062), 0.0078, 0.0078, 0.001, RED_GLASS, 14)
	F.cz(k.g(), Vector3(0, 0.058, 0.0222), 0.0078, 0.0078, 0.001, RED_GLASS.darkened(0.25), 14)
	F.ball(k.g(), Vector3(0.0025, 0.0605, 0.023), Vector3(0.0022, 0.0016, 0.0006), Color("#FFD0C0"), 3, 6)
	F.screw(k.m(), Vector3(0.005, 0.044, 0.008), 1.0, F.BRASS_LIGHT)
	_spur_hammer(k.m(), Vector3(0, 0.032, 0.034), F.IRON)
	F.trigger_and_guard(k, Vector3(0, -0.019, 0.02), 0.028, F.BRASS)
	F.pistol_grip(k, Vector3(0, -0.008, 0.048), Vector3(0, -0.1, 0.088), F.WALNUT_LIGHT, F.BRASS, 1.06)
	F.hoop(k.m(), Vector3(0, -0.116, 0.093), Vector3(1, 0, 0), 0.0075, 0.002, F.BRASS, 12)
	# --- dried chillies on a string off the lanyard ring
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var top := Vector3(0, -0.123, 0.093)
	var string_pts := [top, Vector3(-0.002, -0.14, 0.097), Vector3(-0.004, -0.16, 0.1), Vector3(-0.005, -0.178, 0.101)]
	MeshKit.tube(k.x(), string_pts, [0.0011, 0.0011, 0.0011, 0.0011], 5, F.ROPE)
	F.ball(k.x(), top + Vector3(0, -0.003, 0), Vector3.ONE * 0.0026, F.ROPE.darkened(0.1), 3, 6)
	for i in 5:
		var t := 0.12 + float(i) * 0.2
		var at: Vector3 = (string_pts[0] as Vector3).lerp(string_pts[3], t)
		var ang := float(i) * 2.2 + 0.4
		var out := Vector3(cos(ang) * 0.7, -0.55, sin(ang) * 0.7).normalized()
		var curl := Vector3(-sin(ang), 0.0, cos(ang)) * 0.006
		var ln := rng.randf_range(0.034, 0.046)
		var pts: Array = []
		var radii: Array = []
		for j in 7:
			var f := float(j) / 6.0
			pts.append(at + out * (0.004 + f * ln) + Vector3(0, -f * f * 0.012, 0) + curl * sin(f * 2.4))
			radii.append(lerpf(0.0064, 0.0011, pow(f, 1.6)) * (1.0 if j > 0 else 0.8))
		var shade := CHILI.lightened(rng.randf_range(-0.05, 0.18))
		MeshKit.tube(k.w(), pts, radii, 8, shade)
		F.ball(k.x(), at + out * 0.0025, Vector3(0.0042, 0.0024, 0.0042), Color("#5A5A22"), 3, 6)
		W.rod(k.x(), at, at + out * 0.003, 0.0011, 0.0011, 4, Color("#6B6A2A"))
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ concussion pistol

## A blank-charge thumper: a sawn-off brass barrel with a huge bore and a
## slotted iron muzzle brake clamped on, a fat riveted charge chamber with a
## loading gate showing the wax-sealed blank and a relief valve on top, and a
## grip slung on a coil-spring shock absorber with iron straps and a rubber pad.
static func _concussion() -> Dictionary:
	var k := F.Kit.new()
	var h := F.Kit.new()
	var by := 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# --- the sawn barrel
	F.cz(k.m(), Vector3(0, by, -0.106), 0.0312, 0.0322, 0.108, F.BRASS, 22)
	F.cz(k.m(), Vector3(0, by, -0.1612), 0.0312, 0.0312, 0.0024, F.BRASS_LIGHT.lightened(0.15), 22)
	_bore(k.x(), Vector3(0, by, -0.1628), 0.0245, 18)
	for i in 6:
		var a := rng.randf() * TAU
		F.box(k.m(), Vector3(cos(a) * 0.029, by + sin(a) * 0.029, -0.162), Vector3(0.005, 0.0035, 0.003), F.BRASS_LIGHT, Basis(Vector3.BACK, a))
	# Muzzle brake: a slotted iron collar, three rows of ports round its top half.
	F.cz(k.m(), Vector3(0, by, -0.137), 0.0362, 0.0362, 0.036, F.IRON_DARK, 22)
	for z: float in [-0.12, -0.154]:
		F.cz(k.m(), Vector3(0, by, z), 0.0372, 0.0372, 0.004, F.IRON, 22)
	for row in 3:
		var z := -0.127 - row * 0.0105
		for i in 6:
			var a := -0.15 * PI + float(i) * 0.26 * PI
			F.box(k.x(), Vector3(cos(a) * 0.0358, by + sin(a) * 0.0358, z), Vector3(0.0018, 0.012, 0.0055), F.BORE, Basis(Vector3.BACK, a))
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.008, by - 0.038, -0.137), Vector3(0.008, 0.006, 0.01), F.IRON)
		F.cz(k.m(), Vector3(side * 0.008, by - 0.042, -0.137), 0.003, 0.003, 0.008, F.STEEL, 6)
	F.box(k.m(), Vector3(0, by + 0.0375, -0.15), Vector3(0.003, 0.005, 0.01), F.IRON)
	# Charge chamber: fat iron housing, brass end bands, bolts.
	F.cz(k.m(), Vector3(0, by, -0.031), 0.039, 0.039, 0.04, F.IRON, 22)
	for z: float in [-0.0115, -0.0505]:
		F.cz(k.m(), Vector3(0, by, z), 0.041, 0.041, 0.005, F.BRASS_DARK, 22)
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		F.cz(k.m(), Vector3(cos(a) * 0.0335, by + sin(a) * 0.0335, -0.0545), 0.0034, 0.0034, 0.004, F.STEEL, 6)
	F.cz(k.m(), Vector3(0, by, -0.0545), 0.033, 0.033, 0.003, F.IRON_DARK, 22)
	# Loading gate on the left: hinged plate swung open, the blank's sealed end inside.
	F.box(k.x(), Vector3(-0.0392, by + 0.002, -0.031), Vector3(0.002, 0.022, 0.026), F.BORE)
	F.cx(k.m(), Vector3(-0.0396, by + 0.002, -0.031), 0.0094, 0.0016, F.BRASS, 16)
	F.cx(k.m(), Vector3(-0.0404, by + 0.002, -0.031), 0.005, 0.0012, SHELL_RED.darkened(0.2), 12)
	for i in 6:
		var a := TAU * float(i) / 6.0
		F.box(k.m(), Vector3(-0.0405, by + 0.002 + sin(a) * 0.0068, -0.031 + cos(a) * 0.0068), Vector3(0.0008, 0.0022, 0.0022), F.BRASS_DARK, Basis(Vector3.RIGHT, a))
	F.box(k.m(), Vector3(-0.0425, by + 0.002, -0.004), Vector3(0.002, 0.022, 0.024), F.IRON_DARK, Basis(Vector3.UP, 0.5))
	F.cz(k.m(), Vector3(-0.0404, by + 0.002, -0.0175), 0.0026, 0.0026, 0.026, F.STEEL, 8)
	# Pressure relief valve on top of the chamber.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, by + 0.043, -0.034)), 0.0055, 0.0065, 0.012, 10, F.BRASS)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, by + 0.051, -0.034)), 0.0082, 0.0082, 0.004, 12, F.BRASS_LIGHT)
	_vent(k, Vector3(0, by + 0.046, -0.034), Vector3(-0.012, by + 0.048, -0.034), 0.0022, F.BRASS)
	# --- frame behind the chamber
	F.box(k.m(), Vector3(0, 0.016, 0.014), Vector3(0.032, 0.054, 0.052), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0165, 0.014, 0.014), Vector3(0.0016, 0.036, 0.04), F.IRON)
		for sy: float in [-0.004, 0.034]:
			for sz: float in [-0.002, 0.03]:
				F.ball(k.m(), Vector3(side * 0.017, sy, sz), Vector3.ONE * 0.0026, F.BRASS, 3, 6)
	F.trigger_and_guard(k, Vector3(0, -0.02, 0.032), 0.026, F.IRON)
	W.bent(k.m(), W.arc(Vector3(0, -0.015, 0.032), 0.0262, -0.35 * PI, -1.15 * PI, 10), 0.0034, F.IRON_DARK)
	# The shock absorber: a plunger and coil spring from the frame into the grip's head.
	var sa := Vector3(0, 0.026, 0.04)
	var sb := Vector3(0, 0.026, 0.078)
	F.cz(k.m(), sa + Vector3(0, 0, 0.003), 0.0118, 0.0118, 0.006, F.BRASS, 14)
	F.cz(k.m(), (sa + sb) * 0.5, 0.0042, 0.0042, 0.04, F.STEEL, 10)
	_coil(k.m(), sa + Vector3(0, 0, 0.006), sb - Vector3(0, 0, 0.005), 0.0088, 5.0, 0.0017, F.STEEL.lightened(0.1))
	F.cz(k.m(), sb, 0.0125, 0.0125, 0.01, F.BRASS, 14)
	# Lower link: a slotted bar from the frame foot to the grip, with pins.
	for side: float in [-1.0, 1.0]:
		W.rod(k.m(), Vector3(side * 0.008, -0.006, 0.036), Vector3(side * 0.008, -0.014, 0.074), 0.0026, 0.0026, 6, F.IRON)
		F.cx(k.m(), Vector3(side * 0.008, -0.014, 0.074), 0.004, 0.004, F.STEEL, 8)
	_coil(k.m(), Vector3(0, -0.008, 0.042), Vector3(0, -0.013, 0.068), 0.0045, 4.0, 0.0012, F.STEEL)
	# The reinforced grip: walnut, iron side straps and rivets, a rubber pad.
	var grip := [[Vector3(0, 0.014, 0.084), 0.019, 0.0142], [Vector3(0, -0.025, 0.093), 0.0195, 0.0148],
		[Vector3(0, -0.06, 0.104), 0.021, 0.0156], [Vector3(0, -0.084, 0.111), 0.0205, 0.0152]]
	W.loft(k.w(), grip, F.WALNUT_DARK, 14)
	W.buttplate(k.x(), grip, RUBBER.darkened(0.2))
	for side: float in [-1.0, 1.0]:
		W.bent(k.m(), [Vector3(side * 0.0152, 0.012, 0.084), Vector3(side * 0.0158, -0.025, 0.093), Vector3(side * 0.0164, -0.075, 0.108)], 0.0022, F.IRON)
		for t: float in [0.15, 0.5, 0.85]:
			F.ball(k.m(), Vector3(side * 0.0172, lerpf(0.012, -0.075, t), lerpf(0.084, 0.108, t)), Vector3.ONE * 0.0024, F.BRASS_LIGHT, 3, 6)
	W.bent(k.m(), [Vector3(0, 0.018, 0.102), Vector3(0, -0.024, 0.113), Vector3(0, -0.07, 0.126), Vector3(0, -0.09, 0.13)], 0.0045, F.IRON_DARK)
	_chequer(k, Vector3(0, 0.014, 0.084), Vector3(0, -0.084, 0.111), 0.0152, F.WALNUT.darkened(0.3))
	# --- the hammer (turns about X), big and stubby
	var hp: Vector3 = PIVOTS["concussion_pistol_hammer"]
	F.cx(h.m(), hp, 0.005, 0.014, F.STEEL, 10)
	_spur_hammer(h.m(), hp + Vector3(0, -0.004, 0.002), F.IRON, 1.1)
	return {"body": k.commit(), "hammer": h.commit()}


# ------------------------------------------------------------------ chain binder

## A logging-chain launcher: a riveted iron barrel with a barbed four-fluke
## anchor in its muzzle, an open-sided spoked drum under it with logging chain
## coiled inside, a ratchet on the receiver, a hickory grip and an axe-handle
## foregrip.
static func _chain_binder() -> Dictionary:
	var k := F.Kit.new()
	var d := F.Kit.new()
	var an := F.Kit.new()
	var by := 0.04
	var dc: Vector3 = PIVOTS["chain_binder_drum"]
	# --- barrel
	F.cz(k.m(), Vector3(0, by, -0.165), 0.0268, 0.0285, 0.27, F.IRON, 18)
	F.cz(k.m(), Vector3(0, by, -0.29), 0.0325, 0.0325, 0.022, F.IRON_DARK, 18)
	F.cz(k.m(), Vector3(0, by, -0.3015), 0.0315, 0.0315, 0.002, F.IRON.lightened(0.3), 18)
	_bore(k.x(), Vector3(0, by, -0.3025), 0.02, 16)
	for z: float in [-0.06, -0.19]:
		F.cz(k.m(), Vector3(0, by, z), 0.031, 0.031, 0.012, F.IRON_DARK, 18)
		for i in 8:
			var a := TAU * float(i) / 8.0
			F.ball(k.m(), Vector3(cos(a) * 0.0312, by + sin(a) * 0.0312, z), Vector3.ONE * 0.0028, F.IRON.lightened(0.2), 3, 6)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0285, by - 0.002, -0.125), Vector3(0.004, 0.012, 0.13), F.IRON_DARK)
		for i in 5:
			F.ball(k.m(), Vector3(side * 0.031, by - 0.002, -0.07 - i * 0.027), Vector3.ONE * 0.0024, F.BRASS_DARK, 3, 6)
	F.box(k.m(), Vector3(0, by + 0.031, -0.28), Vector3(0.004, 0.008, 0.012), F.IRON_DARK)
	F.box(k.x(), Vector3(0, by - 0.0285, -0.11), Vector3(0.014, 0.002, 0.06), F.BORE)
	# --- receiver: iron box, ratchet wheel and pawl on the left, a brass maker's plate
	F.box(k.m(), Vector3(0, 0.024, 0.0), Vector3(0.042, 0.056, 0.07), F.IRON_DARK)
	F.box(k.m(), Vector3(0, 0.053, 0.0), Vector3(0.03, 0.004, 0.06), F.IRON)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [0.002, 0.046]:
			for sz: float in [-0.03, 0.03]:
				F.ball(k.m(), Vector3(sx * 0.0212, sy, sz), Vector3.ONE * 0.003, F.IRON.lightened(0.25), 3, 6)
	var rw := Vector3(-0.0225, 0.024, -0.006)
	F.cx(k.m(), rw, 0.016, 0.004, F.STEEL.darkened(0.1), 16)
	for i in 12:
		var a := TAU * float(i) / 12.0
		F.box(k.m(), rw + Vector3(-0.0, sin(a) * 0.0172, cos(a) * 0.0172), Vector3(0.004, 0.004, 0.003), F.STEEL.darkened(0.1), Basis(Vector3.RIGHT, -a + 0.4))
	F.cx(k.m(), rw + Vector3(-0.003, 0, 0), 0.005, 0.004, F.BRASS, 10)
	W.rod(k.m(), Vector3(-0.0235, 0.046, 0.022), Vector3(-0.0235, 0.04, 0.008), 0.0024, 0.0016, 6, F.IRON)
	F.box(k.m(), Vector3(0.0215, 0.026, 0.004), Vector3(0.0012, 0.02, 0.034), F.BRASS)
	W.scroll(k.m(), Vector3(0.0222, 0.026, 0.004), Vector3(1, 0, 0), 0.022, F.BRASS_DARK)
	# A cocking lever on top, and a hammer.
	F.box(k.m(), Vector3(0, 0.06, 0.03), Vector3(0.012, 0.022, 0.012), F.IRON, Basis(Vector3.RIGHT, -0.4))
	F.box(k.m(), Vector3(0, 0.072, 0.042), Vector3(0.02, 0.006, 0.02), F.IRON_DARK, Basis(Vector3.RIGHT, -0.9))
	# Drum axle brackets.
	F.box(k.m(), Vector3(0.031, dc.y + 0.03, dc.z + 0.012), Vector3(0.005, 0.074, 0.016), F.IRON_DARK, Basis(Vector3.RIGHT, 0.35))
	W.bent(k.m(), [dc + Vector3(-0.031, 0, 0), dc + Vector3(-0.031, 0.04, 0.02), Vector3(-0.024, by - 0.018, dc.z + 0.04)], 0.0026, F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.cx(k.m(), dc + Vector3(side * 0.031, 0, 0), 0.008, 0.007, F.IRON, 12)
	# A few links climbing from the drum into the feed slot.
	for i in 3:
		var c := Vector3(0, dc.y + 0.055 + i * 0.0105, -0.098 - i * 0.004)
		_link(k.m(), c, Vector3(0, 0.93, -0.36).normalized(), Vector3(1, 0, 0) if i % 2 == 0 else Vector3(0, 0.36, 0.93), F.STEEL.darkened(0.25))
	F.trigger_and_guard(k, Vector3(0, -0.022, 0.014), 0.026, F.IRON)
	F.pistol_grip(k, Vector3(0, -0.006, 0.04), Vector3(0, -0.1, 0.08), HICKORY, F.IRON_DARK, 1.14)
	# Axe-handle foregrip under the barrel, ahead of the drum.
	F.box(k.m(), Vector3(0, by - 0.032, -0.228), Vector3(0.022, 0.012, 0.03), F.IRON_DARK)
	var fg := [[Vector3(0, by - 0.036, -0.226), 0.014, 0.012], [Vector3(0, by - 0.07, -0.232), 0.015, 0.0125],
		[Vector3(0, by - 0.11, -0.24), 0.0165, 0.0135], [Vector3(0, by - 0.124, -0.242), 0.0185, 0.015], [Vector3(0, by - 0.13, -0.242), 0.013, 0.011]]
	W.loft(k.w(), fg, HICKORY.darkened(0.06), 14)
	for i in 3:
		MeshKit.add_cylinder(k.x(), Transform3D(MeshKit.basis_from_y(Vector3(0, 1, 0.15)), Vector3(0, by - 0.046 - i * 0.005, -0.2275)), 0.0152, 0.0152, 0.004, 12, F.ROPE.darkened(0.12 * (i % 2)))
	# --- the drum: rim, solid right plate, spoked open left side, chain coil
	MeshKit.add_rim(d.m(), Transform3D(F.X, dc), 0.064, 0.058, 0.05, 26, F.IRON)
	F.cx(d.m(), dc + Vector3(0.0235, 0, 0), 0.0605, 0.003, F.IRON_DARK, 26)
	F.hoop(d.m(), dc + Vector3(-0.0245, 0, 0), Vector3(1, 0, 0), 0.06, 0.0028, F.IRON_DARK, 26)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		F.box(d.m(), dc + Vector3(-0.0245, sin(a) * 0.035, cos(a) * 0.035), Vector3(0.004, 0.046, 0.005), F.IRON_DARK, Basis(Vector3.RIGHT, PI * 0.5 - a))
	F.cx(d.m(), dc, 0.012, 0.054, F.STEEL, 14)
	F.cx(d.m(), dc + Vector3(-0.028, 0, 0), 0.0085, 0.004, F.BRASS, 12)
	for i in 12:
		var a := TAU * float(i) / 12.0
		for side: float in [-1.0, 1.0]:
			F.ball(d.m(), dc + Vector3(side * 0.02, sin(a) * 0.0645, cos(a) * 0.0645), Vector3.ONE * 0.0022, F.IRON.lightened(0.25), 3, 6)
	# Chain wound in a spiral (two layers), links alternating flat and on edge.
	for layer in 2:
		var x := -0.011 + layer * 0.016
		var ang := 0.3 + layer * 0.7
		var i := 0
		var turns := 1.6 if layer == 0 else 0.7
		while ang < 0.3 + layer * 0.7 + TAU * turns:
			var f := (ang - 0.3 - layer * 0.7) / (TAU * 1.6)
			var r := lerpf(0.051, 0.025, f)
			var radial := Vector3(0, sin(ang), cos(ang))
			var tang := Vector3(0, cos(ang), -sin(ang))
			var c := dc + Vector3(x, 0, 0) + radial * r
			_link(d.m(), c, tang, Vector3(1, 0, 0) if i % 2 == 0 else radial, F.STEEL.darkened(0.2 + 0.08 * float(i % 3)))
			ang += 0.0118 / r
			i += 1
	# --- the anchor: barbed four-fluke head in the muzzle, a shackle and two links
	var tip := Vector3(0, by, -0.375)
	W.rod(an.m(), Vector3(0, by, -0.27), Vector3(0, by, -0.345), 0.0062, 0.0062, 10, F.IRON)
	F.cz(an.m(), Vector3(0, by, -0.352), 0.0115, 0.0098, 0.014, F.IRON_DARK, 12)
	F.cz(an.m(), tip + Vector3(0, 0, 0.007), 0.0, 0.0112, 0.028, F.STEEL.lightened(0.1), 12)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var out := Vector3(cos(a), sin(a), 0)
		var pts := [Vector3(0, by, -0.352) + out * 0.008, Vector3(0, by, -0.344) + out * 0.02, Vector3(0, by, -0.326) + out * 0.03,
			Vector3(0, by, -0.312) + out * 0.033]
		MeshKit.tube(an.m(), pts, [0.0048, 0.0042, 0.0034, 0.0014], 6, F.IRON)
		W.rod(an.m(), Vector3(0, by, -0.314) + out * 0.032, Vector3(0, by, -0.322) + out * 0.024, 0.0022, 0.0006, 5, F.STEEL)
		W.rod(an.m(), Vector3(0, by, -0.362) + out * 0.006, Vector3(0, by, -0.352) + out * 0.013, 0.0024, 0.0005, 5, F.STEEL)
	F.hoop(an.m(), Vector3(0, by, -0.27), Vector3(1, 0, 0), 0.007, 0.0022, F.IRON_DARK, 12)
	_link(an.m(), Vector3(0, by, -0.258), Vector3(0, 0, 1), Vector3(0, 1, 0), F.STEEL.darkened(0.25))
	return {"body": k.commit(), "drum": d.commit(), "anchor": an.commit()}


# ------------------------------------------------------------------ rust duster

## A hand-pump powder bellows held like a pistol: two teardrop walnut boards
## hinged at the nose with pleated leather between, a leather-wrapped grip
## under the bottom board, and in front a copper reservoir gone green with
## verdigris, feeding a long fine nozzle that puffs orange rust powder.
static func _rust_duster() -> Dictionary:
	var k := F.Kit.new()
	var bel := F.Kit.new()
	var ple := F.Kit.new()
	var hinge: Vector3 = PIVOTS["rust_duster_bellows"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var board := func(y: float) -> Array:
		return [[Vector3(0, y, -0.06), 0.0042, 0.016], [Vector3(0, y, -0.035), 0.0046, 0.03], [Vector3(0, y, 0.01), 0.0048, 0.04],
			[Vector3(0, y, 0.06), 0.0048, 0.038], [Vector3(0, y, 0.09), 0.0046, 0.028], [Vector3(0, y, 0.104), 0.0042, 0.014]]
	# --- bottom board (fixed), nose block, grip
	W.loft(k.w(), board.call(0.0), F.WALNUT_LIGHT, 16)
	F.box(k.m(), Vector3(0, 0.008, -0.064), Vector3(0.026, 0.02, 0.014), F.BRASS_DARK)
	F.cx(k.m(), hinge, 0.0042, 0.036, F.STEEL, 10)
	for i in 9:
		var z := -0.04 + i * 0.016
		var hw := 0.03 if absf(z - 0.02) < 0.05 else 0.022
		for side: float in [-1.0, 1.0]:
			F.ball(k.m(), Vector3(side * (hw + 0.004), 0.0045, z), Vector3(0.0024, 0.0014, 0.0024), F.BRASS, 3, 6)
	var gt := Vector3(0, -0.006, 0.058)
	var gb := Vector3(0, -0.092, 0.082)
	var grip := [[gt, 0.016, 0.0125], [gt.lerp(gb, 0.5), 0.0172, 0.013], [gb + Vector3(0, 0.008, -0.002), 0.019, 0.0138], [gb, 0.016, 0.0124]]
	W.loft(k.w(), grip, F.WALNUT_DARK, 14)
	AP.leather_wrap(k, gt + Vector3(0, -0.008, 0.002), gb + Vector3(0, 0.012, -0.003), 0.0185, 0.0142, 0.0205, 0.015, 7)
	MeshKit.add_ellipsoid(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.3), gb + Vector3(0, -0.004, 0.002)), Vector3(0.016, 0.006, 0.02), 4, 10, F.BRASS)
	F.box(k.m(), Vector3(0, -0.007, 0.06), Vector3(0.022, 0.004, 0.03), F.BRASS_DARK)
	# Brass leaf spring between the boards at the back.
	W.bent(k.m(), [Vector3(0, 0.004, 0.02), Vector3(0, 0.012, 0.05), Vector3(0, 0.03, 0.07), Vector3(0, 0.044, 0.068)], 0.002, F.BRASS)
	# --- top board (hinged at the nose, built open)
	var ro := Basis(Vector3.RIGHT, -DUSTER_OPEN)
	var top_st: Array = []
	for s: Array in board.call(0.0):
		top_st.append([hinge + ro * ((s[0] as Vector3) - Vector3(0, 0, hinge.z) + Vector3(0, 0.008, 0)), s[1], s[2]])
	W.loft(bel.w(), top_st, F.WALNUT_LIGHT, 16)
	var knob := hinge + ro * Vector3(0, 0.016, 0.142)
	MeshKit.add_ellipsoid(bel.w(), Transform3D(ro, knob), Vector3(0.014, 0.008, 0.012), 5, 12, F.WALNUT_DARK)
	MeshKit.add_ellipsoid(bel.m(), Transform3D(ro, hinge + ro * Vector3(0, 0.0135, 0.07)), Vector3(0.02, 0.0012, 0.03), 3, 12, F.BRASS)
	W.scroll(bel.m(), hinge + ro * Vector3(0, 0.0145, 0.07), ro * Vector3.UP, 0.03, F.BRASS_DARK)
	for i in 9:
		var z := 0.02 + i * 0.016
		var hw := 0.03 if absf(z - 0.08) < 0.05 else 0.022
		for side: float in [-1.0, 1.0]:
			F.ball(bel.m(), hinge + ro * Vector3(side * (hw + 0.004), 0.0035, z), Vector3(0.0024, 0.0014, 0.0024), F.BRASS, 3, 6)
	# --- leather pleats between (fan with the board): zigzag gussets down each side
	var widths := [[-0.06, 0.016], [-0.035, 0.03], [0.01, 0.04], [0.06, 0.038], [0.09, 0.028], [0.104, 0.014]]
	var layers := 6
	for side: float in [-1.0, 1.0]:
		var lines: Array = []
		for li in layers + 1:
			var f := float(li) / layers
			var rb := Basis(Vector3.RIGHT, -DUSTER_OPEN * f)
			var inset := 0.86 if li % 2 == 0 else 0.68
			var line: Array[Vector3] = []
			for ti in 9:
				var z := lerpf(-0.052, 0.1, float(ti) / 8.0)
				var w := 0.0
				for wi in widths.size() - 1:
					var wa: Array = widths[wi]
					var wb: Array = widths[wi + 1]
					if z >= float(wa[0]) and z <= float(wb[0]):
						w = lerpf(float(wa[1]), float(wb[1]), (z - float(wa[0])) / (float(wb[0]) - float(wa[0])))
				line.append(hinge + rb * Vector3(side * w * inset, 0.004 + 0.008 * f, z - hinge.z))
			lines.append(line)
		for li in layers:
			var col := MeshKit.vcol(F.LEATHER.darkened(0.3 + 0.18 * float(li % 2)))
			var la: Array[Vector3] = lines[li]
			var lb: Array[Vector3] = lines[li + 1]
			for ti in 8:
				var a := la[ti]
				var b2 := la[ti + 1]
				var c2 := lb[ti + 1]
				var d := lb[ti]
				var nrm := (b2 - a).cross(d - a).normalized()
				if nrm.x * side < 0.0:
					nrm = -nrm
				MeshKit.tri(ple.x(), a, b2, c2, nrm, nrm, nrm, col, nrm)
				MeshKit.tri(ple.x(), a, c2, d, nrm, nrm, nrm, col, nrm)
				MeshKit.tri(ple.x(), a, c2, b2, -nrm, -nrm, -nrm, col, -nrm)
				MeshKit.tri(ple.x(), a, d, c2, -nrm, -nrm, -nrm, col, -nrm)
	# --- copper reservoir with verdigris
	var rc := Vector3(0, 0.008, -0.062)
	_turn(k.m(), rc, [Vector2(0.013, 0.0), Vector2(0.024, 0.006), Vector2(0.032, 0.018), Vector2(0.035, 0.034),
			Vector2(0.035, 0.074), Vector2(0.032, 0.09), Vector2(0.024, 0.102), Vector2(0.012, 0.109), Vector2(0.0, 0.111)], F.COPPER, 20)
	for z: float in [-0.096, -0.136]:
		F.hoop(k.m(), Vector3(0, rc.y, z), Vector3(0, 0, 1), 0.0352, 0.0024, F.BRASS, 20)
		for i in 8:
			var a := TAU * float(i) / 8.0
			F.ball(k.m(), Vector3(cos(a) * 0.0372, rc.y + sin(a) * 0.0372, z), Vector3.ONE * 0.0019, F.BRASS_LIGHT, 3, 6)
	for i in 22:
		var a := rng.randf_range(0.0, TAU)
		var z := rng.randf_range(-0.09, -0.15)
		var nrm := Vector3(cos(a), sin(a), 0)
		var col := [VERDIGRIS, VERDIGRIS_DARK, VERDIGRIS_PALE, F.COPPER.darkened(0.35)][rng.randi_range(0, 3)] as Color
		_patch(k.x(), Vector3(0, rc.y, z) + nrm * 0.0352, nrm, Vector3(0, 0, 1), Vector2(rng.randf_range(0.003, 0.009), rng.randf_range(0.004, 0.013)), col)
	for i in 6:
		var a := rng.randf_range(0.0, TAU)
		var nrm := Vector3(cos(a) * 0.6, sin(a) * 0.6, -0.8).normalized()
		_patch(k.x(), Vector3(0, rc.y, -0.162) + Vector3(cos(a), sin(a), 0) * 0.024 + Vector3(0, 0, -0.003), nrm, Vector3(0, 1, 0), Vector2(0.004, 0.006), VERDIGRIS)
	# Fill cap and a little chain to the band.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, rc.y + 0.038, -0.117)), 0.0095, 0.0095, 0.008, 14, F.BRASS)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, rc.y + 0.043, -0.117)), 0.004, 0.004, 0.004, 8, F.BRASS_LIGHT)
	_patch(k.x(), Vector3(0.006, rc.y + 0.0421, -0.114), Vector3.UP, Vector3(0, 0, 1), Vector2(0.003, 0.004), VERDIGRIS_PALE)
	for i in 3:
		F.hoop(k.m(), Vector3(-0.008 - i * 0.003, rc.y + 0.038 - i * 0.002, -0.107 + i * 0.004), Vector3(1, 0, 0) if i % 2 == 0 else Vector3(0, 0, 1), 0.0022, 0.0006, F.BRASS_DARK, 8)
	# --- the fine nozzle, caked with powder, a puff of orange coming off it
	F.cz(k.m(), Vector3(0, rc.y, -0.175), 0.0075, 0.0085, 0.01, F.BRASS, 6)
	var noz := [Vector3(0, rc.y, -0.178), Vector3(0, rc.y - 0.001, -0.22), Vector3(0, rc.y - 0.006, -0.27), Vector3(0, rc.y - 0.012, -0.31), Vector3(0, rc.y - 0.014, -0.33)]
	MeshKit.tube(k.m(), noz, [0.0055, 0.0042, 0.0032, 0.0026, 0.0026], 10, F.BRASS)
	F.hoop(k.m(), (noz[1] as Vector3), Vector3(0, 0.02, 1), 0.0046, 0.0012, F.BRASS_DARK, 10)
	W.rod(k.m(), Vector3(0, rc.y - 0.0135, -0.327), Vector3(0, rc.y - 0.015, -0.337), 0.0034, 0.0022, 10, F.BRASS_LIGHT)
	W.rod(k.x(), Vector3(0, rc.y - 0.015, -0.3365), Vector3(0, rc.y - 0.0151, -0.3375), 0.0014, 0.0014, 8, F.BORE)
	_patch(k.x(), Vector3(0, rc.y - 0.012, -0.2) + Vector3(-0.0042, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector2(0.002, 0.008), VERDIGRIS)
	for i in 10:
		var z := rng.randf_range(-0.336, -0.31)
		var a := rng.randf() * TAU
		F.ball(k.x(), Vector3(cos(a) * 0.0028, rc.y - 0.013 + sin(a) * 0.0028 - (z + 0.31) * 0.08, z), Vector3.ONE * rng.randf_range(0.0012, 0.0022), RUST_POWDER.darkened(0.2), 2, 6)
	var tip := Vector3(0, rc.y - 0.015, -0.34)
	for i in 16:
		var f := rng.randf()
		var spread := 0.003 + f * 0.016
		var a := rng.randf() * TAU
		F.ball(k.x(), tip + Vector3(cos(a) * spread, sin(a) * spread * 0.8 - f * 0.004, -0.003 - f * 0.05), Vector3.ONE * lerpf(0.0014, 0.0034, f),
				RUST_POWDER.lightened(rng.randf_range(0.0, 0.25)), 3, 6)
	# Orange dust settled on the reservoir's nose.
	for i in 5:
		var a := rng.randf_range(0.2, 2.9)
		var nrm := Vector3(cos(a), sin(a), -0.6).normalized()
		_patch(k.x(), Vector3(0, rc.y, -0.158) + Vector3(cos(a), sin(a), 0) * 0.027, nrm, Vector3(0, 0, -1), Vector2(0.003, 0.006), RUST_POWDER.darkened(0.1))
	return {"body": k.commit(), "bellows": bel.commit(), "pleats": ple.commit()}


# ------------------------------------------------------------------ glow-worm launcher

## A naturalist's specimen tube that fires grubs: a green-painted vasculum tube
## with brass fittings, a glass observation section caged in brass bars with
## glowing grubs crawling inside, a cork plug in the flared muzzle tied with
## twine, a knurled breech cap with a paper specimen tag, and a walnut grip.
static func _glow_worm() -> Dictionary:
	var k := F.Kit.new()
	var ck := F.Kit.new()
	var by := 0.038
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# --- tube sections
	F.cz(k.x(), Vector3(0, by, 0.01), 0.03, 0.03, 0.14, VASCULUM, 20)
	F.cz(k.x(), Vector3(0, by, -0.282), 0.03, 0.03, 0.16, VASCULUM, 20)
	F.cz(k.m(), Vector3(0, by, 0.09), 0.0325, 0.0325, 0.02, F.BRASS, 20)
	for i in 10:
		var a := TAU * float(i) / 10.0
		F.box(k.m(), Vector3(cos(a) * 0.0328, by + sin(a) * 0.0328, 0.09), Vector3(0.002, 0.002, 0.018), F.BRASS_DARK, Basis(Vector3.BACK, a))
	F.cz(k.m(), Vector3(0, by, 0.1015), 0.012, 0.014, 0.004, F.BRASS_LIGHT, 14)
	for z: float in [0.07, -0.02, -0.25, -0.33]:
		F.cz(k.m(), Vector3(0, by, z), 0.0318, 0.0318, 0.006, F.BRASS, 20)
	# The window: brass collars, a lit core, grubs on it, three cage bars, glass glints.
	for z: float in [-0.064, -0.196]:
		F.cz(k.m(), Vector3(0, by, z), 0.034, 0.034, 0.012, F.BRASS, 20)
		F.cz(k.m(), Vector3(0, by, z + (0.007 if z > -0.1 else -0.007)), 0.031, 0.031, 0.003, F.BRASS_LIGHT, 20)
	F.cz(k.g(), Vector3(0, by, -0.13), 0.0215, 0.0215, 0.122, Color("#0E2219"), 18)
	for i in 3:
		var a := PI * 0.5 + TAU * float(i) / 3.0 + PI / 3.0
		F.box(k.m(), Vector3(cos(a) * 0.029, by + sin(a) * 0.029, -0.13), Vector3(0.004, 0.004, 0.124), F.BRASS_DARK, Basis(Vector3.BACK, a))
	for i in 11:
		var a := rng.randf_range(0.35 * PI, 1.45 * PI)
		var z0 := rng.randf_range(-0.18, -0.08)
		var dz := rng.randf_range(-1.0, 1.0)
		var da := rng.randf_range(-1.0, 1.0) * 0.9
		var segs := rng.randi_range(4, 6)
		for j in segs:
			var f := float(j) / float(segs - 1)
			var aa := a + da * f * 0.35
			var zz := z0 + dz * f * 0.022
			var rr := 0.0215 + 0.0035
			var s := 0.0042 * (1.0 - absf(f - 0.4) * 0.7)
			F.ball(k.g(), Vector3(cos(aa) * rr, by + sin(aa) * rr, zz), Vector3(s, s, s * 1.15), GRUB if j % 2 == 0 else GRUB_DIM, 3, 8)
		F.ball(k.g(), Vector3(cos(a) * 0.025, by + sin(a) * 0.025, z0), Vector3.ONE * 0.0022, Color("#F4FFB8"), 3, 6)
	for a: float in [0.62 * PI, 0.82 * PI]:
		F.box(k.g(), Vector3(cos(a) * 0.0296, by + sin(a) * 0.0296, -0.13), Vector3(0.0008, 0.0016, 0.1), Color("#BFE6D2"), Basis(Vector3.BACK, a))
	# Muzzle: flared brass ring.
	_turn(k.m(), Vector3(0, by, -0.36), [Vector2(0.0305, 0.0), Vector2(0.032, 0.008), Vector2(0.0345, 0.016), Vector2(0.036, 0.02),
			Vector2(0.032, 0.021), Vector2(0.027, 0.018)], F.BRASS, 20)
	F.cz(k.x(), Vector3(0, by, -0.37), 0.027, 0.027, 0.02, F.BORE, 16)
	# Leather hand guard round the fore tube, a front bead, a folding leaf sight.
	F.cz(k.x(), Vector3(0, by, -0.27), 0.0318, 0.0318, 0.05, F.LEATHER, 20)
	for z: float in [-0.247, -0.293]:
		F.cz(k.x(), Vector3(0, by, z), 0.0325, 0.0325, 0.004, F.LEATHER.darkened(0.3), 20)
	F.ball(k.m(), Vector3(0, by + 0.0335, -0.33), Vector3.ONE * 0.003, F.BRASS_LIGHT, 4, 8)
	F.box(k.m(), Vector3(0, by + 0.032, 0.03), Vector3(0.012, 0.004, 0.016), F.BRASS_DARK)
	F.box(k.m(), Vector3(0, by + 0.04, 0.026), Vector3(0.01, 0.012, 0.0016), F.BRASS, Basis(Vector3.RIGHT, 0.25))
	F.box(k.x(), Vector3(0, by + 0.0445, 0.0248), Vector3(0.002, 0.003, 0.002), F.BORE)
	# Brass plaque on the left with a beetle scroll; sling swivels.
	MeshKit.add_ellipsoid(k.m(), Transform3D(Basis(), Vector3(-0.0302, by, 0.012)), Vector3(0.0012, 0.012, 0.022), 3, 12, F.BRASS)
	W.scroll(k.m(), Vector3(-0.0316, by, 0.012), Vector3(-1, 0, 0), 0.022, F.BRASS_DARK)
	F.hoop(k.m(), Vector3(0, by - 0.036, -0.33), Vector3(1, 0, 0), 0.006, 0.0014, F.BRASS, 10)
	F.hoop(k.m(), Vector3(0, by - 0.036, 0.075), Vector3(1, 0, 0), 0.006, 0.0014, F.BRASS, 10)
	# Paper specimen tag on twine off the breech band.
	W.bent(k.x(), [Vector3(-0.025, by - 0.018, 0.07), Vector3(-0.033, by - 0.032, 0.073), Vector3(-0.036, by - 0.046, 0.076)], 0.0008, F.ROPE)
	F.box(k.x(), Vector3(-0.037, by - 0.058, 0.077), Vector3(0.0008, 0.022, 0.014), F.IVORY, Basis(Vector3.BACK, 0.12))
	F.box(k.x(), Vector3(-0.0376, by - 0.056, 0.077), Vector3(0.0006, 0.0012, 0.009), F.WALNUT_DARK, Basis(Vector3.BACK, 0.12))
	F.box(k.x(), Vector3(-0.0376, by - 0.061, 0.077), Vector3(0.0006, 0.0012, 0.007), F.WALNUT_DARK, Basis(Vector3.BACK, 0.12))
	# --- receiver block under the tube, trigger, grip
	F.box(k.m(), Vector3(0, 0.003, 0.018), Vector3(0.024, 0.022, 0.07), F.BRASS_DARK)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.012, 0.003, 0.0), side, F.BRASS_LIGHT)
		F.screw(k.m(), Vector3(side * 0.012, 0.003, 0.04), side, F.BRASS_LIGHT)
	F.trigger_and_guard(k, Vector3(0, -0.016, 0.016), 0.025, F.BRASS)
	F.pistol_grip(k, Vector3(0, -0.006, 0.044), Vector3(0, -0.098, 0.084), F.WALNUT, F.BRASS)
	# --- the cork (pops out of the muzzle)
	var cp: Vector3 = PIVOTS["glow_worm_launcher_cork"]
	F.cz(ck.x(), cp + Vector3(0, 0, -0.006), 0.0285, 0.0262, 0.026, CORK, 18)
	F.cz(ck.x(), cp + Vector3(0, 0, -0.0195), 0.0285, 0.0285, 0.001, CORK.lightened(0.08), 18)
	for i in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.025)
		F.ball(ck.x(), cp + Vector3(cos(a) * r, sin(a) * r, -0.0198), Vector3(0.0012, 0.0012, 0.0004), CORK.darkened(0.35), 2, 5)
	for i in 10:
		var a := rng.randf() * TAU
		var z := rng.randf_range(-0.018, -0.002)
		_patch(ck.x(), cp + Vector3(cos(a) * 0.0283, sin(a) * 0.0283, z), Vector3(cos(a), sin(a), 0), Vector3(0, 0, 1), Vector2(0.0012, 0.0015), CORK.darkened(0.4))
	# Twine round its neck and a pull loop off the face.
	F.hoop(ck.x(), cp + Vector3(0, 0, -0.016), Vector3(0, 0, 1), 0.0287, 0.0012, F.ROPE, 18)
	W.bent(ck.x(), [cp + Vector3(0.006, 0.0, -0.02), cp + Vector3(0.008, -0.004, -0.028), cp + Vector3(0.0, -0.01, -0.031), cp + Vector3(-0.008, -0.004, -0.028), cp + Vector3(-0.006, 0.0, -0.02)], 0.0011, F.ROPE)
	return {"body": k.commit(), "cork": ck.commit()}


# ------------------------------------------------------------------ caltrops launcher

## A frontier-army break-action: a short wide blued barrel with a flared scatter
## muzzle (seven-hole cap), an inspection window on the chamber showing the
## brass caltrop canister with points poking through, a ladder sight, brass
## furniture, a walnut forend, and a leather-wrapped grip with a sling ring.
static func _caltrops() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var by := 0.03
	var hinge: Vector3 = PIVOTS["caltrops_launcher_barrels"]
	# --- barrel group (tips down)
	F.cz(b.m(), Vector3(0, by, -0.095), 0.0338, 0.0348, 0.12, F.BLUED, 20)
	F.cz(b.m(), Vector3(0, by, -0.0375), 0.0358, 0.0358, 0.005, F.BLUED.darkened(0.2), 20)
	# Canister rim at the breech face.
	F.cz(b.m(), Vector3(0, by, -0.0345), 0.0285, 0.0285, 0.002, F.BRASS_LIGHT, 18)
	F.hoop(b.m(), Vector3(0, by, -0.0335), Vector3(0, 0, 1), 0.02, 0.001, F.BRASS_DARK, 16)
	F.cz(b.m(), Vector3(0, by, -0.0335), 0.006, 0.006, 0.001, F.COPPER, 10)
	# Inspection window on the left of the chamber, the canister and its points inside.
	var wc := Vector3(-0.0342, by + 0.003, -0.066)
	F.box(b.x(), wc, Vector3(0.002, 0.026, 0.036), F.BORE)
	F.box(b.m(), wc + Vector3(-0.0006, 0, 0), Vector3(0.0012, 0.02, 0.03), F.BRASS)
	for c: Vector3 in [Vector3(0, 0.005, -0.008), Vector3(0, -0.005, 0.0), Vector3(0, 0.005, 0.008)]:
		F.cx(b.x(), wc + c + Vector3(-0.0014, 0, 0), 0.0024, 0.0008, F.BORE, 8)
		var cc := wc + c + Vector3(-0.0035, 0, 0)
		for sd: Vector3 in [Vector3(-1, 0, 0), Vector3(0.45, 0.85, 0.3), Vector3(0.45, -0.6, 0.66), Vector3(0.45, -0.25, -0.86)]:
			W.rod(b.m(), cc, cc + sd.normalized() * 0.0052, 0.0013, 0.0002, 5, F.STEEL.darkened(0.15))
	F.box(b.m(), wc + Vector3(-0.0008, 0.0098, 0), Vector3(0.0014, 0.0016, 0.03), F.BRASS_DARK)
	for e: Array in [[Vector3(0, 0.0145, 0), Vector3(0.0028, 0.003, 0.04)], [Vector3(0, -0.0145, 0), Vector3(0.0028, 0.003, 0.04)],
			[Vector3(0, 0, 0.0195), Vector3(0.0028, 0.032, 0.003)], [Vector3(0, 0, -0.0195), Vector3(0.0028, 0.032, 0.003)]]:
		F.box(b.m(), wc + (e[0] as Vector3), e[1] as Vector3, F.BRASS)
	for c: Vector3 in [Vector3(0, 0.0145, 0.0195), Vector3(0, 0.0145, -0.0195), Vector3(0, -0.0145, 0.0195), Vector3(0, -0.0145, -0.0195)]:
		F.screw(b.m(), wc + c + Vector3(-0.001, 0, 0), -1.0, F.BRASS_LIGHT)
	# Scatter muzzle: flared mouth, a seven-hole cap, bolts round its rim.
	_turn(b.m(), Vector3(0, by, -0.155), [Vector2(0.034, 0.0), Vector2(0.0365, 0.008), Vector2(0.043, 0.016), Vector2(0.0505, 0.022), Vector2(0.0505, 0.025)], F.BLUED.lightened(0.06), 20)
	F.cz(b.m(), Vector3(0, by, -0.1805), 0.0505, 0.0505, 0.004, F.IRON_DARK, 20)
	_bore(b.x(), Vector3(0, by, -0.1828), 0.0068, 10)
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		_bore(b.x(), Vector3(cos(a) * 0.027, by + sin(a) * 0.024, -0.1828), 0.0064, 10)
		var a2 := a + PI / 6.0
		F.cz(b.m(), Vector3(cos(a2) * 0.043, by + sin(a2) * 0.043, -0.1832), 0.0026, 0.0026, 0.002, F.STEEL, 6)
	F.hoop(b.m(), Vector3(0, by, -0.1828), Vector3(0, 0, 1), 0.0155, 0.0011, F.IRON, 16)
	F.box(b.m(), Vector3(0, by + 0.053, -0.172), Vector3(0.003, 0.008, 0.01), F.BLUED.darkened(0.2))
	# Hinge lug, and a short walnut forend with a brass tip under the barrel.
	F.box(b.m(), Vector3(0, 0.001, -0.05), Vector3(0.02, 0.024, 0.03), F.BLUED.darkened(0.25))
	F.cx(b.m(), hinge, 0.0055, 0.03, F.STEEL, 10)
	var fe := [[Vector3(0, by - 0.034, -0.07), 0.009, 0.02], [Vector3(0, by - 0.038, -0.09), 0.011, 0.023], [Vector3(0, by - 0.038, -0.13), 0.011, 0.022],
		[Vector3(0, by - 0.034, -0.142), 0.008, 0.019]]
	W.loft(b.w(), fe, F.WALNUT, 14)
	F.cz(b.m(), Vector3(0, by - 0.035, -0.145), 0.0085, 0.0085, 0.006, F.BRASS, 12)
	# --- frame: blued with a brass trigger plate, a big military hammer, ladder sight
	F.box(k.m(), Vector3(0, 0.014, 0.01), Vector3(0.036, 0.054, 0.052), F.BLUED.darkened(0.08))
	F.cz(k.m(), Vector3(0, by, -0.0245), 0.0358, 0.0358, 0.016, F.BLUED.darkened(0.12), 20)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0128, -0.002, -0.04), Vector3(0.007, 0.02, 0.026), F.BLUED.darkened(0.12))
		F.screw(k.m(), Vector3(side * 0.0185, 0.0, 0.026), side, F.STEEL)
		F.screw(k.m(), Vector3(side * 0.0185, 0.03, 0.0), side, F.STEEL)
	MeshKit.add_ellipsoid(k.m(), Transform3D(Basis(), Vector3(-0.0182, 0.016, 0.012)), Vector3(0.0012, 0.012, 0.016), 3, 12, F.BRASS)
	W.scroll(k.m(), Vector3(-0.0194, 0.016, 0.012), Vector3(-1, 0, 0), 0.02, F.BRASS_DARK)
	F.box(k.m(), Vector3(0, -0.014, 0.02), Vector3(0.014, 0.004, 0.06), F.BRASS)
	_spur_hammer(k.m(), Vector3(0, 0.034, 0.034), F.BLUED.darkened(0.1), 1.05)
	# Ladder sight flipped up on the top strap.
	F.box(k.m(), Vector3(0, 0.0435, -0.004), Vector3(0.014, 0.004, 0.022), F.BLUED)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0055, 0.056, -0.008), Vector3(0.0022, 0.026, 0.0022), F.BLUED.lightened(0.1), Basis(Vector3.RIGHT, 0.2))
	for i in 4:
		F.box(k.m(), Vector3(0, 0.048 + i * 0.006, -0.0065 - i * 0.0012), Vector3(0.011, 0.0008, 0.0016), F.STEEL)
	F.box(k.m(), Vector3(0, 0.06, -0.009), Vector3(0.013, 0.004, 0.004), F.BRASS)
	F.box(k.x(), Vector3(0, 0.0622, -0.009), Vector3(0.002, 0.0015, 0.0045), F.BORE)
	F.trigger_and_guard(k, Vector3(0, -0.02, 0.02), 0.028, F.BRASS)
	var gt := Vector3(0, -0.008, 0.048)
	var gb := Vector3(0, -0.1, 0.088)
	F.pistol_grip(k, gt, gb, F.WALNUT, F.BRASS, 1.08)
	AP.leather_wrap(k, Vector3(0, -0.018, 0.053), Vector3(0, -0.086, 0.083), 0.019, 0.0145, 0.0215, 0.0155, 8)
	# Inspector's cartouche on the right grip, a big cavalry sling ring at the butt.
	MeshKit.add_ellipsoid(k.x(), Transform3D(Basis(), Vector3(0.0157, -0.094, 0.086)), Vector3(0.0006, 0.004, 0.006), 3, 10, F.WALNUT_DARK)
	F.box(k.m(), Vector3(0, -0.114, 0.094), Vector3(0.008, 0.006, 0.008), F.BRASS)
	F.hoop(k.m(), Vector3(0, -0.126, 0.096), Vector3(1, 0, 0), 0.011, 0.0024, F.BRASS, 14)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ phosphor grenade

## A field-made demolitions launcher: a tin can for a barrel (rolled ribs, a
## soldered seam, an olive stencilled band) strapped to an iron frame, scorched
## black round its mouth, with a phosphorus shell sitting in it, nose out:
## hazard stripes, a skull and a faintly glowing fuse. Safety pin and ring on
## the frame, a nailed plank grip.
static func _phosphor() -> Dictionary:
	var k := F.Kit.new()
	var s := F.Kit.new()
	var by := 0.034
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	# --- the can
	F.cz(k.m(), Vector3(0, by, -0.0925), 0.04, 0.04, 0.135, F.TIN, 22)
	for z: float in [-0.026, -0.159]:
		F.hoop(k.m(), Vector3(0, by, z), Vector3(0, 0, 1), 0.0402, 0.0026, F.TIN.lightened(0.12), 22)
	for z: float in [-0.042, -0.05, -0.135, -0.143]:
		F.hoop(k.m(), Vector3(0, by, z), Vector3(0, 0, 1), 0.0402, 0.0012, F.TIN.darkened(0.15), 22)
	F.cz(k.x(), Vector3(0, by, -0.092), 0.0408, 0.0408, 0.05, OLIVE, 22)
	for z: float in [-0.069, -0.115]:
		F.cz(k.x(), Vector3(0, by, z), 0.041, 0.041, 0.003, HAZARD, 22)
	# Stencil marks on the band (left side): three blocky dashes.
	for i in 3:
		F.box(k.x(), Vector3(-0.041, by + 0.006, -0.08 - i * 0.012), Vector3(0.0008, 0.007, 0.008), HAZARD.lightened(0.1))
	F.box(k.x(), Vector3(-0.041, by - 0.006, -0.092), Vector3(0.0008, 0.003, 0.03), HAZARD.lightened(0.1))
	F.box(k.m(), Vector3(0.0256, by - 0.031, -0.0925), Vector3(0.0018, 0.0018, 0.132), F.TIN.darkened(0.3), Basis(Vector3.BACK, 0.68))
	# Heat-tinted rim and scorch round the mouth, the dark mouth itself.
	F.cz(k.m(), Vector3(0, by, -0.152), 0.0404, 0.0404, 0.012, Color("#8A7556"), 22)
	F.hoop(k.x(), Vector3(0, by, -0.1595), Vector3(0, 0, 1), 0.0396, 0.0024, F.SOOT, 22)
	_bore(k.x(), Vector3(0, by, -0.1605), 0.0372, 20)
	for i in 18:
		var a := rng.randf() * TAU
		var z := rng.randf_range(-0.158, -0.128)
		var nrm := Vector3(cos(a), sin(a), 0)
		var big := 1.0 - (z + 0.158) / 0.03
		_patch(k.x(), Vector3(0, by, z) + nrm * 0.0406, nrm, Vector3(0, 0, 1),
				Vector2(rng.randf_range(0.004, 0.012), rng.randf_range(0.005, 0.016) * (0.5 + big)), F.SOOT.lightened(rng.randf_range(0.0, 0.15)))
	# Two hose clamps with bolt lugs, a bar under the can to the frame.
	for z: float in [-0.06, -0.124]:
		F.hoop(k.m(), Vector3(0, by, z), Vector3(0, 0, 1), 0.0414, 0.0022, F.IRON_DARK, 22)
		F.box(k.m(), Vector3(0, by - 0.044, z), Vector3(0.012, 0.008, 0.008), F.IRON_DARK)
		F.cx(k.m(), Vector3(0, by - 0.045, z), 0.0026, 0.02, F.STEEL, 6)
	F.box(k.m(), Vector3(0, by - 0.05, -0.07), Vector3(0.012, 0.006, 0.12), F.IRON)
	for i in 4:
		F.ball(k.m(), Vector3(0, by - 0.053, -0.02 - i * 0.034), Vector3.ONE * 0.0026, F.IRON.lightened(0.25), 3, 6)
	# --- iron frame, riveted end plate, hammer, wire guard, safety pin
	F.cz(k.m(), Vector3(0, by, -0.022), 0.043, 0.043, 0.008, F.IRON, 22)
	for i in 8:
		var a := TAU * float(i) / 8.0
		F.ball(k.m(), Vector3(cos(a) * 0.0385, by + sin(a) * 0.0385, -0.027), Vector3.ONE * 0.0026, F.IRON.lightened(0.25), 3, 6)
	F.box(k.m(), Vector3(0, 0.014, 0.012), Vector3(0.03, 0.052, 0.05), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		for sy: float in [-0.006, 0.032]:
			for sz: float in [-0.006, 0.03]:
				F.ball(k.m(), Vector3(side * 0.0155, sy, sz), Vector3.ONE * 0.0026, F.IRON.lightened(0.2), 3, 6)
	_spur_hammer(k.m(), Vector3(0, 0.034, 0.032), F.IRON)
	W.bent(k.m(), [Vector3(0, -0.012, 0.0), Vector3(0, -0.024, 0.004), Vector3(0, -0.032, 0.012)], 0.003, F.STEEL)
	W.bent(k.m(), [Vector3(0, -0.012, -0.012), Vector3(0, -0.038, -0.006), Vector3(0, -0.046, 0.016), Vector3(0, -0.036, 0.04), Vector3(0, -0.014, 0.046)], 0.0024, F.IRON)
	F.cx(k.m(), Vector3(0, 0.022, 0.0), 0.0022, 0.044, F.STEEL, 6)
	F.hoop(k.m(), Vector3(-0.024, 0.012, 0.0), Vector3(0, 0, 1), 0.009, 0.0018, F.BRASS, 14)
	F.box(k.x(), Vector3(-0.026, 0.0, 0.0), Vector3(0.0008, 0.006, 0.014), F.SIGNAL_RED, Basis(Vector3.BACK, 0.1))
	# Plank grip, square cut, nailed, twine round the top.
	var grip := [[Vector3(0, -0.008, 0.047), 0.016, 0.012], [Vector3(0, -0.05, 0.066), 0.0175, 0.0128], [Vector3(0, -0.092, 0.084), 0.019, 0.0135],
		[Vector3(0, -0.102, 0.087), 0.018, 0.013]]
	W.loft(k.w(), grip, F.WALNUT_LIGHT.darkened(0.05), 8)
	for side: float in [-1.0, 1.0]:
		for t: float in [0.25, 0.75]:
			var p := Vector3(0, -0.008, 0.047).lerp(Vector3(0, -0.092, 0.084), t)
			F.cx(k.m(), p + Vector3(side * 0.0138, 0, 0), 0.0022, 0.0016, F.IRON_DARK, 6)
	for i in 4:
		var c := Vector3(0, -0.012 - i * 0.004, 0.049 + i * 0.0017)
		MeshKit.add_cylinder(k.x(), Transform3D(MeshKit.basis_from_y(Vector3(0, 0.92, -0.4)), c), 0.0172, 0.0172, 0.0032, 10, F.ROPE.darkened(0.08 * float(i % 2)))
	# --- the shell (sits in the can mouth, leaves along -Z)
	var sp: Vector3 = PIVOTS["phosphor_grenade_shell"]
	F.cz(s.m(), sp + Vector3(0, 0, -0.008), 0.0302, 0.0302, 0.036, Color("#8C9172"), 20)
	_hazard(s.m(), Vector3(0, by, 0), 0.0306, sp.z - 0.004, sp.z - 0.024, 16, 3, HAZARD, Color("#1A1814"))
	F.cz(s.m(), sp + Vector3(0, 0, -0.0255), 0.031, 0.031, 0.003, F.BRASS_DARK, 20)
	var nose := sp + Vector3(0, 0, -0.026)
	_turn(s.m(), nose, [Vector2(0.0302, 0.0), Vector2(0.029, 0.01), Vector2(0.025, 0.019), Vector2(0.018, 0.027), Vector2(0.009, 0.033), Vector2(0.004, 0.035)], Color("#8C9172"), 20)
	F.cz(s.m(), nose + Vector3(0, 0, -0.037), 0.0045, 0.0062, 0.006, F.BRASS, 12)
	F.ball(s.g(), nose + Vector3(0, 0, -0.0405), Vector3(0.0042, 0.0042, 0.0026), Color("#E6FFB2"), 4, 10)
	F.hoop(s.g(), nose + Vector3(0, 0, -0.034), Vector3(0, 0, 1), 0.0068, 0.0011, Color("#B8FF8A"), 12)
	# Skull on the upper left of the nose: a bone-white face, dark eyes, crossbones.
	var sa := PI * 0.78
	var sn := Vector3(cos(sa) * 0.88, sin(sa) * 0.88, -0.48).normalized()
	var sk := nose + Vector3(cos(sa), sin(sa), 0) * 0.0262 + Vector3(0, 0, -0.012)
	var up := Vector3(0, 0, -1)
	var sb := _flat(sn, up)
	MeshKit.add_ellipsoid(s.x(), Transform3D(sb, sk + sn * 0.0006), Vector3(0.0078, 0.0006, 0.007), 3, 12, F.IVORY)
	MeshKit.add_ellipsoid(s.x(), Transform3D(sb, sk + sn * 0.0006 - sb.x * 0.0052), Vector3(0.0032, 0.0006, 0.0034), 3, 8, F.IVORY)
	for e: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(s.x(), Transform3D(sb, sk + sn * 0.0012 + sb.x * 0.0012 + sb.z * e * 0.0022), Vector3(0.0016, 0.0005, 0.0014), 2, 6, F.BORE)
		F.box(s.x(), sk + sn * 0.0006 - sb.x * 0.004, Vector3(0.0012, 0.0012, 0.017), F.IVORY, Basis(sb.x, sn, sb.z) * Basis(Vector3.UP, e * 0.7))
	F.box(s.x(), sk + sn * 0.0012 - sb.x * 0.0035, Vector3(0.0008, 0.0005, 0.004), F.BORE, sb)
	return {"body": k.commit(), "shell": s.commit()}
