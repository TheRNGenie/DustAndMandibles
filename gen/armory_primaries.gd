class_name ArmoryPrimaries
extends RefCounted
## The Weapon Slots primaries that are sold (Weapon Slots Redesign, section 7
## prompts), built in code. The four never sold (Coach Gun, Lever-Action Rifle,
## Bolt-Action Long Rifle, Gatling Pistol) are archived in
## D:/DustAndMandibles-archive/retired/weapons/gen/armory_primaries.gd. See ArmoryGuns for the conventions; helpers and colours are
## FrontierGuns' (F) and WeaponBuilder's (W).

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")

const NAMES: Dictionary = {
	&"volcanic_repeater": "Volcanic Repeater", &"mares_leg": "Mare's Leg",
	&"double_rifle": "Double Rifle",
	&"trench_broom": "Trench Broom", &"ricochet_rifle": "Ricochet Rifle", &"howdah_pistol": "Howdah Pistol",
	&"sharps_carbine": "Sharps Carbine", &"trapdoor_springfield": "Trapdoor Springfield",
	# Nov 10 primary weapons evaluation (code-built for now: Logan, Nov 11).
	&"concussion_mortar": "Concussion Mortar", &"repeating_crossbow": "Repeating Crossbow",
}
const PIVOTS: Dictionary = {
	"volcanic_repeater_lever": Vector3(0.0, -0.02, -0.04),
	"mares_leg_lever": Vector3(0.0, -0.02, -0.04),
	"double_rifle_barrels": Vector3(0.0, -0.01, -0.056),
	"trench_broom_pump": Vector3(0.0, -0.012, -0.2),
	"ricochet_rifle_lever": Vector3(0.0, -0.02, -0.04),
	"howdah_pistol_barrels": Vector3(0.0, -0.006, -0.03),
	"sharps_carbine_lever": Vector3(0.0, -0.026, -0.03),
	"trapdoor_springfield_trapdoor": Vector3(0.0, 0.04, -0.05),
	"concussion_mortar_shell": Vector3(0.0, 0.135, -0.44),
	"repeating_crossbow_lever": Vector3(0.0, 0.035, 0.02),
	"repeating_crossbow_limb_l": Vector3(-0.03, 0.03, -0.4),
	"repeating_crossbow_limb_r": Vector3(0.03, 0.03, -0.4),
	"repeating_crossbow_string": Vector3(0.0, 0.03, -0.38),
	"repeating_crossbow_bolt": Vector3(0.0, 0.042, -0.2),
}
const MUZZLE: Dictionary = {
	&"volcanic_repeater": Vector3(0.0, 0.028, -0.53),
	&"mares_leg": Vector3(0.0, 0.028, -0.4),
	&"double_rifle": Vector3(0.0, 0.024, -0.66),
	&"trench_broom": Vector3(0.0, 0.022, -0.55),
	&"ricochet_rifle": Vector3(0.0, 0.028, -0.68),
	&"howdah_pistol": Vector3(0.0, 0.02, -0.26),
	&"sharps_carbine": Vector3(0.0, 0.026, -0.56),
	&"trapdoor_springfield": Vector3(0.0, 0.024, -0.9),
	&"concussion_mortar": Vector3(0.0, 0.135, -0.44),
	&"repeating_crossbow": Vector3(0.0, 0.042, -0.43),
}
## [right fist centre, right grip axis, left support fist centre] (gun space).
const HANDS: Dictionary = {
	&"volcanic_repeater": [Vector3(0.0, -0.035, 0.1), Vector3(0, 0.55, -0.83), Vector3(0.0, 0.0, -0.2)],
	&"mares_leg": [Vector3(0.0, -0.05, 0.075), Vector3(0, 0.8, -0.6), Vector3(0.0, -0.005, -0.17)],
	&"double_rifle": [Vector3(0.0, -0.045, 0.09), Vector3(0, 0.75, -0.66), Vector3(0.0, -0.014, -0.17)],
	&"trench_broom": [Vector3(0.0, -0.04, 0.09), Vector3(0, 0.6, -0.8), Vector3(0.0, -0.02, -0.2)],
	&"ricochet_rifle": [Vector3(0.0, -0.035, 0.1), Vector3(0, 0.55, -0.83), Vector3(0.0, -0.008, -0.2)],
	&"howdah_pistol": [Vector3(0.0, -0.05, 0.04), Vector3(0, 0.92, -0.39), Vector3(-0.03, -0.06, 0.04)],
	&"sharps_carbine": [Vector3(0.0, -0.035, 0.09), Vector3(0, 0.55, -0.83), Vector3(0.0, -0.008, -0.17)],
	&"trapdoor_springfield": [Vector3(0.0, -0.035, 0.1), Vector3(0, 0.55, -0.83), Vector3(0.0, -0.01, -0.26)],
	&"concussion_mortar": [Vector3(0.0, -0.05, 0.075), Vector3(0, 0.85, -0.52), Vector3(0.0, -0.02, -0.2)],
	&"repeating_crossbow": [Vector3(0.0, -0.05, 0.075), Vector3(0, 0.85, -0.52), Vector3(0.0, 0.0, -0.22)],
}

## Case-hardened steel: mottled blue, straw and brown.
const CASE := [Color("#5E6670"), Color("#7B6A55"), Color("#4F5E7A"), Color("#8A7A5E"), Color("#6A6E78")]
const PARKERIZED := Color("#5B5F55")
const CANVAS := Color("#A79A74")
const RUBBER_RED := Color("#7A2620")
## Billiard balls: 1 yellow, 2 blue, 3 red, 8 black.
const POOL := [Color("#E8B82A"), Color("#2A4FA8"), Color("#C0302A"), Color("#1A1A1A")]


static func build(id: StringName) -> Dictionary:
	match id:
		&"volcanic_repeater":
			return _volcanic_repeater()
		&"mares_leg":
			return _mares_leg()
		&"double_rifle":
			return _double_rifle()
		&"trench_broom":
			return _trench_broom()
		&"ricochet_rifle":
			return _ricochet_rifle()
		&"howdah_pistol":
			return _howdah_pistol()
		&"sharps_carbine":
			return _sharps_carbine()
		&"trapdoor_springfield":
			return _trapdoor_springfield()
		&"concussion_mortar":
			return _concussion_mortar()
		&"repeating_crossbow":
			return _repeating_crossbow()
	return {}


# ------------------------------------------------------------------ shared bits

## A receiver block with case-hardening colours washed over its sides: each
## side face is a fine grid coloured per corner from two soft noise fields
## (blue, straw and brown), so the colours swirl into each other.
static func case_block(k: F.Kit, c: Vector3, size: Vector3, seed_value: int) -> void:
	F.box(k.m(), c, size, CASE[0])
	var n1 := FastNoiseLite.new()
	n1.seed = seed_value
	n1.frequency = 38.0
	n1.fractal_octaves = 3
	var n2 := FastNoiseLite.new()
	n2.seed = seed_value + 7
	n2.frequency = 52.0
	var blue := Color("#3F5683")
	var straw := Color("#A38A5A")
	var brown := Color("#6A5240")
	var nz := 26
	var ny := 12
	for side: float in [-1.0, 1.0]:
		var x := c.x + side * (size.x * 0.5 + 0.0002)
		var nrm := Vector3(side, 0, 0)
		var grid: Array = []
		var cols: Array = []
		for iy in ny + 1:
			for iz in nz + 1:
				var y := c.y - size.y * 0.5 + size.y * float(iy) / ny
				var z := c.z - size.z * 0.5 + size.z * float(iz) / nz
				grid.append(Vector3(x, y, z))
				var w1 := smoothstep(-0.05, 0.55, n1.get_noise_2d(z + side, y))
				var w2 := smoothstep(-0.2, 0.5, n2.get_noise_2d(z, y - side))
				var col: Color = CASE[0].lerp(blue, w1 * 0.75).lerp(straw if w2 > 0.45 else brown, w2 * 0.5)
				cols.append(MeshKit.vcol(col))
		for iy in ny:
			for iz in nz:
				var i00 := iy * (nz + 1) + iz
				var q := [i00, i00 + nz + 1, i00 + nz + 2, i00 + 1]
				for t: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
					var a0: Vector3 = grid[t[0]]
					var a1: Vector3 = grid[t[1]]
					var a2: Vector3 = grid[t[2]]
					var order: Array = [t[0], t[1], t[2]] if (a1 - a0).cross(a2 - a0).dot(nrm) <= 0.0 else [t[0], t[2], t[1]]
					for vi: int in order:
						k.m().set_color(cols[vi])
						k.m().set_normal(nrm)
						k.m().add_vertex(grid[vi])


## An exposed side hammer: a curved neck from the lock up to a chequered spur.
static func side_hammer(k: F.Kit, base: Vector3, side: float, col: Color) -> void:
	F.box(k.m(), base + Vector3(0, 0.004, 0.0), Vector3(0.006, 0.012, 0.012), col)
	W.bent(k.m(), [base + Vector3(0, 0.006, 0.002), base + Vector3(side * 0.001, 0.014, 0.008), base + Vector3(side * 0.002, 0.018, 0.018)], 0.0034, col)
	F.box(k.m(), base + Vector3(side * 0.002, 0.0195, 0.024), Vector3(0.0075, 0.004, 0.013), col.lightened(0.12), Basis(Vector3.RIGHT, -0.25))
	for i in 3:
		F.box(k.m(), base + Vector3(side * 0.002, 0.0218, 0.02 + i * 0.004), Vector3(0.008, 0.0008, 0.0011), col.darkened(0.35), Basis(Vector3.RIGHT, -0.25))


## Leather laced round a stretch of stock: a sleeve a little proud of the wood
## (stations as for W.loft), tied off with a rawhide band at each end and a
## stitched seam along the belly.
static func leather_sleeve(k: F.Kit, stations: Array) -> void:
	var proud: Array = []
	for s: Array in stations:
		proud.append([s[0], float(s[1]) + 0.0018, float(s[2]) + 0.0018])
	W.loft(k.x(), proud, F.LEATHER.darkened(0.32), 16)
	for s: Array in [proud[0], proud[proud.size() - 1]]:
		W.loft(k.x(), [[(s[0] as Vector3) + Vector3(0, 0, -0.003), float(s[1]) + 0.001, float(s[2]) + 0.001],
				[(s[0] as Vector3) + Vector3(0, 0, 0.003), float(s[1]) + 0.001, float(s[2]) + 0.001]], F.ROPE.darkened(0.1), 16)
	for i in proud.size() - 1:
		var a: Array = proud[i]
		var b: Array = proud[i + 1]
		for j in 6:
			var t := (float(j) + 0.5) / 6.0
			var c := (a[0] as Vector3).lerp(b[0], t) + Vector3(0, -lerpf(float(a[1]), float(b[1]), t) - 0.0006, 0)
			F.box(k.x(), c, Vector3(0.004, 0.0012, 0.0018), F.ROPE.lightened(0.2))


## Leather wrapped round a loft between two stations: overlapping bands with a
## stitched seam down the inside.
static func leather_wrap(k: F.Kit, a: Vector3, b: Vector3, ha: float, wa: float, hb: float, wb: float, bands: int) -> void:
	var ay := (b - a).normalized()
	var ax := (Vector3.RIGHT - ay * ay.dot(Vector3.RIGHT)).normalized()
	var az := ax.cross(ay)
	var seg := (b - a).length() / bands * 1.08
	for i in bands:
		var t := (float(i) + 0.5) / bands
		var c := a.lerp(b, t)
		var h := lerpf(ha, hb, t) + 0.0016
		var w := lerpf(wa, wb, t) + 0.0016
		MeshKit.add_ellipsoid(k.x(), Transform3D(Basis(ax * w, ay * seg * 0.5, az * h), c), Vector3.ONE, 3, 12, F.LEATHER.darkened(0.06 * (i % 2)))
	for i in bands * 3:
		var t := (float(i) + 0.5) / (bands * 3)
		var c := a.lerp(b, t)
		F.box(k.x(), c + Vector3(0, -lerpf(ha, hb, t) - 0.0018, 0), Vector3(0.0035, 0.0012, 0.0016), F.ROPE.lightened(0.15))


# ------------------------------------------------------------------ more shared bits

## An octagonal barrel along Z (a flat on top), centred at c.
static func octagon(st: SurfaceTool, c: Vector3, r_front: float, r_back: float, length: float, col: Color) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI / 8.0) * F.Z, c), r_front, r_back, length, 8, col)


## A muzzle at `c` (pointing -Z): a bright crowned rim and the dark bore.
static func muzzle(k: F.Kit, c: Vector3, r_out: float, r_in: float, col: Color, segs: int = 16) -> void:
	F.cz(k.m(), c, r_out, r_out, 0.002, col.lightened(0.18), segs)
	F.cz(k.x(), c + Vector3(0, 0, -0.0012), r_in, r_in, 0.0008, F.BORE, 12)


## A front blade sight on a ramp at p (p on the barrel's top).
static func blade(st: SurfaceTool, p: Vector3, col: Color, tip: Color = F.BRASS_LIGHT) -> void:
	F.box(st, p + Vector3(0, 0.0025, 0), Vector3(0.008, 0.005, 0.016), col.darkened(0.2))
	F.box(st, p + Vector3(0, 0.007, 0.001), Vector3(0.0018, 0.006, 0.009), tip)


## A buckhorn rear sight standing on the barrel at p.
static func buckhorn(st: SurfaceTool, p: Vector3, col: Color) -> void:
	F.box(st, p + Vector3(0, 0.002, 0), Vector3(0.016, 0.004, 0.02), col)
	F.box(st, p + Vector3(0, 0.006, 0), Vector3(0.02, 0.006, 0.003), col)
	for side: float in [-1.0, 1.0]:
		F.box(st, p + Vector3(side * 0.0085, 0.0105, 0), Vector3(0.005, 0.007, 0.003), col, Basis(Vector3.BACK, side * 0.45))


## A ladder rear sight folded down along the barrel at p: base, two rails,
## cross bars and the sliding peep.
static func ladder(st: SurfaceTool, p: Vector3, col: Color, length: float = 0.06) -> void:
	F.box(st, p + Vector3(0, 0.002, 0), Vector3(0.02, 0.004, length * 0.7), col)
	for side: float in [-1.0, 1.0]:
		F.box(st, p + Vector3(side * 0.0072, 0.0055, -length * 0.1), Vector3(0.0024, 0.003, length), col.lightened(0.08))
	for i in 4:
		F.box(st, p + Vector3(0, 0.0058, -length * 0.55 + i * length * 0.3), Vector3(0.016, 0.0022, 0.0022), col.lightened(0.08))
	F.box(st, p + Vector3(0, 0.0075, -length * 0.3), Vector3(0.019, 0.004, 0.008), F.STEEL)
	F.cx(st, p + Vector3(0, 0.0035, length * 0.32), 0.0028, 0.022, col.darkened(0.2), 8)


## A chequered panel on a stock's side: a dark oval inset with a fine
## diamond hatch, centred at c on the side facing `side`, `w` long and `h` tall.
static func chequer(k: F.Kit, c: Vector3, side: float, w: float, h: float) -> void:
	F.ball(k.w(), c, Vector3(0.0006, h * 0.5, w * 0.5), F.WALNUT_DARK, 3, 16)
	for i in 7:
		var t := (float(i) + 0.5) / 7.0 - 0.5
		var span := sqrt(maxf(1.0 - 4.0 * t * t, 0.0))
		for d: float in [-1.0, 1.0]:
			F.box(k.w(), c + Vector3(side * 0.0005, 0, t * w * 0.9), Vector3(0.0006, h * 0.85 * span, 0.0009), F.WALNUT_DARK.darkened(0.35), Basis(Vector3.RIGHT, d * 0.55))


## A lever-gun hammer at the back of the receiver: a curved neck rising from
## the frame and a chequered spur leaning back.
static func rifle_hammer(st: SurfaceTool, base: Vector3, col: Color) -> void:
	F.box(st, base + Vector3(0, 0.002, 0.0), Vector3(0.0075, 0.012, 0.014), col)
	W.bent(st, [base + Vector3(0, 0.004, 0.0), base + Vector3(0, 0.014, 0.004), base + Vector3(0, 0.02, 0.014)], 0.0036, col)
	F.box(st, base + Vector3(0, 0.0215, 0.021), Vector3(0.0085, 0.0045, 0.014), col.lightened(0.12), Basis(Vector3.RIGHT, -0.3))
	for i in 3:
		F.box(st, base + Vector3(0, 0.0242, 0.017 + i * 0.004), Vector3(0.009, 0.0008, 0.0011), col.darkened(0.4), Basis(Vector3.RIGHT, -0.3))


## A lever loop hanging from its pivot `piv` (it swings down to cycle), `s` its size.
static func lever_loop(st: SurfaceTool, piv: Vector3, col: Color, s: float = 1.0) -> void:
	var pts: Array = []
	for p: Vector3 in [Vector3(0, 0, 0), Vector3(0, -0.02, 0.02), Vector3(0, -0.03, 0.058), Vector3(0, -0.026, 0.094), Vector3(0, -0.012, 0.108), Vector3(0, 0.003, 0.094)]:
		pts.append(piv + p * s)
	W.bent(st, pts, 0.0045 * s, col)
	var loop: Array = []
	for p: Vector3 in W.arc(Vector3(0, -0.032, 0.08), 0.022, 0.12 * PI, 1.12 * PI, 8):
		loop.append(piv + p * s)
	W.bent(st, loop, 0.0045 * s, col)
	F.cx(st, piv, 0.0055 * s, 0.03, col.darkened(0.2), 10)


## A carbine saddle ring on its bar on the gun's left side at p.
static func saddle_ring(k: F.Kit, p: Vector3, col: Color) -> void:
	F.box(k.m(), p, Vector3(0.003, 0.006, 0.05), col)
	for z: float in [-0.02, 0.02]:
		F.ball(k.m(), p + Vector3(-0.0015, 0, z), Vector3(0.002, 0.0035, 0.0035), col.lightened(0.1), 3, 8)
	F.hoop(k.m(), p + Vector3(-0.004, -0.022, 0.0), Vector3(1, 0, 0), 0.018, 0.0022, col.lightened(0.15), 18)


## A crescent buttplate on the last loft station: a curved steel plate with
## horns at the heel and toe.
static func crescent(k: F.Kit, last: Array, col: Color) -> void:
	var c: Vector3 = last[0]
	var hh: float = last[1]
	var hw: float = last[2]
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(hh * 1.04, -hh * 1.04, t)
		var dz := 0.004 - 0.016 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		F.box(k.m(), c + Vector3(0, y, dz + 0.003), Vector3(hw * 2.06, hh * 2.1 / 8.0 + 0.002, 0.005), col)
	F.box(k.m(), c + Vector3(0, hh * 1.02, -0.012), Vector3(hw * 1.7, 0.004, 0.03), col)
	F.box(k.m(), c + Vector3(0, -hh * 1.0, -0.006), Vector3(hw * 1.8, 0.004, 0.022), col)


## A canvas sling from swivel `a` to swivel `b`, hanging `sag` below, with
## leather ends and a brass buckle.
static func sling(k: F.Kit, a: Vector3, b: Vector3, sag: float, col: Color) -> void:
	var n := 14
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3(0, -sag * sin(PI * t), 0))
	for i in n:
		var d := pts[i + 1] - pts[i]
		var end := i == 0 or i == n - 1
		F.box(k.x(), (pts[i] + pts[i + 1]) * 0.5, Vector3(0.0022, d.length() * 1.04, 0.026), F.LEATHER if end else col,
				MeshKit.basis_from_y(d.normalized()))
	var third := int(n / 3.0)
	var mid := pts[third]
	F.box(k.m(), mid, Vector3(0.0042, 0.006, 0.03), F.BRASS, MeshKit.basis_from_y((pts[third + 1] - pts[third]).normalized()))
	for p: Vector3 in [a, b]:
		F.hoop(k.m(), p, Vector3(1, 0, 0), 0.007, 0.0016, F.STEEL, 10)


## A rifle buttstock (and wrist) running back from z0, `drop` how far the butt falls.
static func rifle_stock(z0: float, y0: float, length: float, drop: float, butt_h: float, pistol: bool = false) -> Array:
	var out: Array = [[Vector3(0, y0, z0), 0.024, 0.0175], [Vector3(0, y0 - 0.012, z0 + 0.05), 0.0175, 0.0158]]
	if pistol:
		out.append([Vector3(0, y0 - 0.022, z0 + 0.09), 0.026, 0.0165])
	out.append_array([[Vector3(0, y0 - drop * 0.45, z0 + length * 0.42), butt_h * 0.6, 0.018],
		[Vector3(0, y0 - drop * 0.8, z0 + length * 0.75), butt_h * 0.86, 0.0195], [Vector3(0, y0 - drop, z0 + length), butt_h, 0.0205]])
	return out


# ------------------------------------------------------------------ repeater carbine

## A Henry-style repeating carbine: a polished brass receiver engraved with
## scrollwork, an octagonal barrel with the tubular magazine under it the whole
## way (no forend: the slot and follower show), a saddle ring on the left, a
## blued lever and hammer, and a straight walnut stock with a brass crescent butt.
static func _volcanic_repeater() -> Dictionary:
	var k := F.Kit.new()
	var lv := F.Kit.new()
	var by := 0.028
	# Receiver: brass with engraved panels both sides and a rounded front.
	F.box(k.m(), Vector3(0, 0.012, -0.012), Vector3(0.034, 0.058, 0.122), F.BRASS)
	F.cz(k.m(), Vector3(0, 0.012, -0.075), 0.0172, 0.0172, 0.006, F.BRASS_DARK, 16)
	F.box(k.m(), Vector3(0, 0.044, -0.004), Vector3(0.024, 0.008, 0.09), F.BRASS_LIGHT)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0175, 0.013, -0.012), Vector3(0.0012, 0.044, 0.104), F.BRASS_DARK)
		F.box(k.m(), Vector3(side * 0.0182, 0.013, -0.012), Vector3(0.0008, 0.04, 0.098), F.BRASS_LIGHT)
		W.scroll(k.m(), Vector3(side * 0.019, 0.016, -0.03), Vector3(side, 0, 0), 0.034, F.BRASS_DARK)
		W.scroll(k.m(), Vector3(side * 0.019, 0.012, 0.018), Vector3(side, 0, 0), 0.026, F.BRASS_DARK)
		F.screw(k.m(), Vector3(side * 0.018, -0.008, -0.055), side, F.STEEL)
		F.screw(k.m(), Vector3(side * 0.018, -0.008, 0.035), side, F.STEEL)
	saddle_ring(k, Vector3(-0.0195, 0.004, 0.015), F.BLUED)
	# Hammer and trigger.
	rifle_hammer(k.m(), Vector3(0, 0.04, 0.05), F.BLUED.darkened(0.2))
	W.bent(k.m(), [Vector3(0, -0.017, 0.01), Vector3(0, -0.03, 0.016), Vector3(0, -0.036, 0.024)], 0.0026, F.STEEL)
	# Barrel and magazine in one: the barrel on top, the magazine tube under it,
	# the follower's slot down the right, the brass follower knob near the front.
	octagon(k.m(), Vector3(0, by, -0.3), 0.0128, 0.0132, 0.45, F.BLUED)
	F.cz(k.m(), Vector3(0, 0.004, -0.3), 0.0118, 0.0118, 0.45, F.BLUED.darkened(0.1), 16)
	F.box(k.x(), Vector3(0.0115, 0.004, -0.31), Vector3(0.0018, 0.0035, 0.4), F.BORE)
	F.ball(k.m(), Vector3(0.0125, 0.004, -0.46), Vector3(0.004, 0.004, 0.006), F.BRASS_LIGHT, 4, 8)
	F.cz(k.m(), Vector3(0, 0.004, -0.523), 0.0122, 0.0122, 0.008, F.BRASS, 16)
	muzzle(k, Vector3(0, by, -0.526), 0.0128, 0.0058, F.BLUED, 8)
	blade(k.m(), Vector3(0, by + 0.0125, -0.505), F.BLUED)
	buckhorn(k.m(), Vector3(0, by + 0.0125, -0.17), F.BLUED)
	# Straight stock, brass crescent butt; a brass sling swivel.
	var stock := rifle_stock(0.052, 0.006, 0.36, 0.044, 0.054)
	W.loft(k.w(), stock, F.WALNUT, 16)
	crescent(k, stock[stock.size() - 1], F.BRASS)
	F.hoop(k.m(), Vector3(0, -0.07, 0.34), Vector3(1, 0, 0), 0.007, 0.0016, F.BRASS, 10)
	# --- lever
	lever_loop(lv.m(), PIVOTS["volcanic_repeater_lever"], F.BLUED)
	return {"body": k.commit(), "lever": lv.commit()}


# ------------------------------------------------------------------ double rifle

## A side-by-side express rifle with elephant-gun proportions: two heavy
## barrels on a solid rib with folding express leaves, a hammerless action with
## long engraved sidelock plates, a top lever and safety, a pistol-grip stock
## with a cheekpiece, and a thick red recoil pad.
static func _double_rifle() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var hinge: Vector3 = PIVOTS["double_rifle_barrels"]
	case_block(k, Vector3(0, 0.012, -0.008), Vector3(0.056, 0.054, 0.1), 31)
	F.box(k.m(), Vector3(0, 0.012, -0.06), Vector3(0.056, 0.054, 0.004), F.IRON_DARK)
	# Sidelock plates running back into the wood, bordered and engraved.
	for side: float in [-1.0, 1.0]:
		var sx := side * 0.0292
		F.box(k.m(), Vector3(sx, 0.008, 0.035), Vector3(0.0022, 0.034, 0.1), F.STEEL.lightened(0.08))
		F.box(k.m(), Vector3(sx + side * 0.0012, 0.008, 0.035), Vector3(0.0006, 0.028, 0.092), F.STEEL.darkened(0.15))
		W.scroll(k.m(), Vector3(sx + side * 0.0016, 0.012, 0.015), Vector3(side, 0, 0), 0.03, F.BRASS)
		W.scroll(k.m(), Vector3(sx + side * 0.0016, 0.006, 0.058), Vector3(side, 0, 0), 0.026, F.BRASS)
		for z: float in [0.0, 0.07]:
			F.screw(k.m(), Vector3(sx, 0.0, z), side, F.STEEL)
	# Top lever and the sliding safety on the tang.
	F.box(k.m(), Vector3(0, 0.0405, 0.03), Vector3(0.012, 0.005, 0.05), CASE[2])
	F.box(k.m(), Vector3(0.009, 0.0412, 0.054), Vector3(0.026, 0.005, 0.01), CASE[2], Basis(Vector3.UP, -0.35))
	F.box(k.m(), Vector3(0, 0.0405, 0.075), Vector3(0.008, 0.004, 0.012), F.BRASS_LIGHT)
	for z: float in [0.006, 0.026]:
		W.bent(k.m(), [Vector3(0, -0.014, z), Vector3(0, -0.025, z + 0.003), Vector3(0, -0.033, z + 0.009)], 0.0026, F.STEEL)
	W.bent(k.m(), W.arc(Vector3(0, -0.017, 0.02), 0.026, -0.28 * PI, -1.12 * PI, 10), 0.0036, F.STEEL.darkened(0.2))
	# Pistol-grip stock with a cheekpiece and a red recoil pad.
	var stock := [[Vector3(0, 0.012, 0.06), 0.027, 0.026], [Vector3(0, 0.0, 0.105), 0.021, 0.0185], [Vector3(0, -0.02, 0.14), 0.03, 0.018],
		[Vector3(0, -0.032, 0.22), 0.042, 0.021], [Vector3(0, -0.046, 0.33), 0.055, 0.0225], [Vector3(0, -0.052, 0.39), 0.06, 0.023]]
	W.loft(k.w(), stock, F.WALNUT, 16)
	var pad := [[Vector3(0, -0.052, 0.392), 0.0605, 0.0232], [Vector3(0, -0.053, 0.418), 0.0612, 0.0236]]
	W.loft(k.x(), pad, RUBBER_RED, 16)
	MeshKit.add_ellipsoid(k.w(), Transform3D(Basis(), Vector3(-0.019, -0.016, 0.3)), Vector3(0.008, 0.024, 0.07), 5, 12, F.WALNUT_LIGHT)
	F.ball(k.m(), Vector3(0, -0.062, 0.15), Vector3(0.012, 0.004, 0.012), F.STEEL, 3, 10) # grip cap
	for side: float in [-1.0, 1.0]:
		chequer(k, Vector3(side * 0.0186, -0.016, 0.13), side, 0.045, 0.026)
	F.hoop(k.m(), Vector3(0, -0.098, 0.33), Vector3(1, 0, 0), 0.008, 0.0018, F.STEEL, 10)
	# --- barrels, rib, express sights, forend
	for side: float in [-1.0, 1.0]:
		F.cz(b.m(), Vector3(side * 0.0205, 0.024, -0.36), 0.017, 0.0205, 0.6, F.BLUED, 18)
		muzzle(b, Vector3(side * 0.0205, 0.024, -0.661), 0.017, 0.0105, F.BLUED, 18)
		F.cz(b.m(), Vector3(side * 0.0205, 0.024, -0.061), 0.0205, 0.0205, 0.006, F.BLUED.darkened(0.25), 18)
		F.cz(b.m(), Vector3(side * 0.0205, 0.024, -0.0575), 0.0152, 0.0152, 0.002, F.BRASS_LIGHT, 14)
	F.box(b.m(), Vector3(0, 0.044, -0.36), Vector3(0.014, 0.006, 0.6), F.BLUED.darkened(0.2))
	for i in 3:
		F.box(b.m(), Vector3(0, 0.0475 + (0.004 if i == 0 else 0.0), -0.13 - i * 0.012), Vector3(0.018, 0.0012 + (0.008 if i == 0 else 0.0), 0.004), F.BLUED.darkened(0.3) if i > 0 else F.STEEL)
	F.box(b.m(), Vector3(0, 0.0515, -0.13), Vector3(0.004, 0.0035, 0.0045), F.IVORY)
	blade(b.m(), Vector3(0, 0.047, -0.645), F.BLUED, F.IVORY)
	F.box(b.m(), Vector3(0, -0.002, -0.09), Vector3(0.024, 0.02, 0.06), F.BLUED.darkened(0.3))
	F.cx(b.m(), hinge, 0.006, 0.034, F.STEEL, 10)
	var forend := [[Vector3(0, -0.002, -0.11), 0.019, 0.032], [Vector3(0, -0.006, -0.14), 0.022, 0.035],
		[Vector3(0, -0.005, -0.27), 0.02, 0.033], [Vector3(0, 0.0, -0.295), 0.014, 0.027]]
	W.loft(b.w(), forend, F.WALNUT, 16)
	for side: float in [-1.0, 1.0]:
		chequer(b, Vector3(side * 0.0345, -0.007, -0.2), side, 0.09, 0.024)
	F.hoop(b.m(), Vector3(0, -0.006, -0.52), Vector3(1, 0, 0), 0.008, 0.0018, F.STEEL, 10)
	F.box(b.m(), Vector3(0, 0.0, -0.52), Vector3(0.006, 0.012, 0.016), F.BLUED.darkened(0.2))
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ trench broom

## A military pump shotgun: a dull parkerized receiver, the barrel inside a
## perforated heat shield, a magazine tube run out nearly to the muzzle, a
## bayonet lug under the muzzle, a ribbed wooden pump, sling swivels, and a
## plain oiled stock.
static func _trench_broom() -> Dictionary:
	var k := F.Kit.new()
	var p := F.Kit.new()
	var by := 0.022
	var steel := PARKERIZED
	F.box(k.m(), Vector3(0, 0.01, -0.004), Vector3(0.034, 0.056, 0.15), steel)
	F.cz(k.m(), Vector3(0, 0.03, -0.004), 0.0162, 0.0162, 0.15, steel, 16)
	F.box(k.x(), Vector3(0.0172, 0.022, -0.02), Vector3(0.0012, 0.016, 0.05), F.BORE)
	F.box(k.m(), Vector3(0, 0.038, 0.065), Vector3(0.008, 0.026, 0.012), steel.darkened(0.2), Basis(Vector3.RIGHT, -0.7))
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.055, 0.055]:
			F.screw(k.m(), Vector3(side * 0.0172, -0.008, z), side, steel.lightened(0.2))
		F.box(k.m(), Vector3(side * 0.0172, 0.008, 0.0), Vector3(0.0008, 0.026, 0.1), steel.darkened(0.12))
	F.trigger_and_guard(k, Vector3(0, -0.028, 0.05), 0.022, steel.darkened(0.2))
	# Barrel and the heat shield over it: a sheet-steel sleeve with rows of holes.
	F.cz(k.m(), Vector3(0, by, -0.32), 0.012, 0.0126, 0.48, F.BLUED.darkened(0.1), 16)
	muzzle(k, Vector3(0, by, -0.561), 0.012, 0.0085, F.BLUED, 16)
	F.cz(k.m(), Vector3(0, by + 0.002, -0.27), 0.0185, 0.0185, 0.32, steel.lightened(0.05), 20)
	for z: float in [-0.432, -0.108]:
		F.cz(k.m(), Vector3(0, by + 0.002, z), 0.0198, 0.0198, 0.012, steel.darkened(0.1), 20)
	for row in 13:
		for j in 5:
			var a := lerpf(0.2 * PI, 0.8 * PI, float(j) / 4.0) + (0.06 if row % 2 == 0 else -0.06)
			var n := Vector3(cos(a), sin(a), 0)
			F.ball(k.x(), Vector3(0, by + 0.002, -0.13 - row * 0.023) + n * 0.0186, Vector3(0.0034, 0.0034, 0.0034) * Vector3(1.0 - absf(n.x) * 0.7, 1.0 - absf(n.y) * 0.7, 1.0), F.BORE, 3, 8)
	F.box(k.m(), Vector3(0, by + 0.022, -0.54), Vector3(0.003, 0.008, 0.006), F.BRASS_LIGHT)
	# Magazine tube nearly to the muzzle, its cap, and the bayonet lug.
	F.cz(k.m(), Vector3(0, -0.012, -0.28), 0.0105, 0.0105, 0.52, steel.darkened(0.1), 14)
	F.cz(k.m(), Vector3(0, -0.012, -0.545), 0.0112, 0.0112, 0.012, steel.lightened(0.15), 14)
	F.box(k.m(), Vector3(0, 0.004, -0.535), Vector3(0.03, 0.05, 0.016), steel.darkened(0.15))
	F.box(k.m(), Vector3(0, -0.026, -0.53), Vector3(0.008, 0.012, 0.034), steel.darkened(0.25))
	F.cx(k.m(), Vector3(0, -0.03, -0.518), 0.0035, 0.014, F.STEEL, 8)
	F.hoop(k.m(), Vector3(0, -0.03, -0.5), Vector3(1, 0, 0), 0.007, 0.0016, F.STEEL, 10)
	# Plain oiled stock and a steel buttplate; a sling swivel.
	var stock := rifle_stock(0.072, 0.004, 0.36, 0.05, 0.056)
	W.loft(k.w(), stock, F.WALNUT_LIGHT.darkened(0.08), 16)
	W.buttplate(k.m(), stock, steel)
	F.hoop(k.m(), Vector3(0, -0.07, 0.36), Vector3(1, 0, 0), 0.007, 0.0016, F.STEEL, 10)
	# --- the pump: deep-grooved wood on two action bars
	var forend := [[Vector3(0, -0.012, -0.135), 0.017, 0.0175], [Vector3(0, -0.014, -0.15), 0.021, 0.021],
		[Vector3(0, -0.014, -0.265), 0.021, 0.021], [Vector3(0, -0.012, -0.28), 0.017, 0.0175]]
	W.loft(p.w(), forend, F.WALNUT, 16)
	for i in 9:
		var z := -0.158 - i * 0.012
		F.cz(p.w(), Vector3(0, -0.014, z), 0.0216, 0.0216, 0.004, F.WALNUT_DARK, 16)
	for side: float in [-1.0, 1.0]:
		W.rod(p.m(), Vector3(side * 0.011, -0.002, -0.14), Vector3(side * 0.011, -0.002, -0.07), 0.0022, 0.0022, 6, F.STEEL)
	return {"body": k.commit(), "pump": p.commit()}


# ------------------------------------------------------------------ ricochet rifle

## A showman's trick-shot rifle: polished nickel all over with gold trim, a
## barrel ending in an angled, faceted tip ringed by swept ricochet guide vanes,
## billiard balls (1, 2, 3 and the 8) inlaid in the receiver and stock, a red
## and gold painted band on the wood, and an oversized lever loop.
static func _ricochet_rifle() -> Dictionary:
	var k := F.Kit.new()
	var lv := F.Kit.new()
	var by := 0.028
	F.box(k.m(), Vector3(0, 0.012, -0.012), Vector3(0.034, 0.058, 0.13), F.NICKEL)
	F.box(k.m(), Vector3(0, 0.044, -0.012), Vector3(0.026, 0.006, 0.11), F.NICKEL.lightened(0.1))
	# Billiard-ball inlays on the receiver: a racked triangle each side.
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0174, 0.012, -0.012), Vector3(0.0008, 0.046, 0.112), F.BRASS)
		F.box(k.m(), Vector3(side * 0.0178, 0.012, -0.012), Vector3(0.0008, 0.042, 0.108), F.NICKEL)
		var rack := [Vector3(0, 0.0, -0.03), Vector3(0, 0.008, -0.016), Vector3(0, -0.008, -0.016), Vector3(0, 0.0, 0.0)]
		for i in rack.size():
			var c: Vector3 = Vector3(side * 0.0186, 0.014, -0.004) + (rack[i] as Vector3)
			F.cx(k.m(), c, 0.0068, 0.0012, POOL[i], 20)
			F.cx(k.m(), c + Vector3(side * 0.0006, 0, 0), 0.0029, 0.0008, Color("#F4F1EA"), 14)
		W.scroll(k.m(), Vector3(side * 0.0186, 0.014, 0.032), Vector3(side, 0, 0), 0.022, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.018, -0.01, 0.04), side, F.BRASS)
	rifle_hammer(k.m(), Vector3(0, 0.04, 0.05), F.NICKEL.darkened(0.15))
	W.bent(k.m(), [Vector3(0, -0.017, 0.01), Vector3(0, -0.03, 0.016), Vector3(0, -0.036, 0.024)], 0.0026, F.BRASS_LIGHT)
	# Barrel with a gold band, magazine, forend.
	octagon(k.m(), Vector3(0, by, -0.34), 0.0122, 0.0134, 0.53, F.NICKEL)
	for z: float in [-0.09, -0.3, -0.52]:
		octagon(k.m(), Vector3(0, by, z), 0.0138, 0.0138, 0.008, F.BRASS)
	F.cz(k.m(), Vector3(0, 0.003, -0.32), 0.0098, 0.0098, 0.48, F.NICKEL.darkened(0.15), 14)
	F.cz(k.m(), Vector3(0, 0.003, -0.562), 0.0108, 0.0108, 0.008, F.BRASS, 14)
	var forend := [[Vector3(0, 0.006, -0.078), 0.019, 0.0172], [Vector3(0, 0.004, -0.12), 0.022, 0.0188],
		[Vector3(0, 0.004, -0.26), 0.021, 0.018], [Vector3(0, 0.006, -0.29), 0.0175, 0.016]]
	W.loft(k.w(), forend, F.WALNUT_LIGHT, 14)
	F.cz(k.m(), Vector3(0, 0.008, -0.295), 0.0172, 0.0172, 0.01, F.BRASS, 14)
	# The trick tip: a tapered hexagonal shroud ending in an angled deflector
	# lip, four swept guide vanes along it, gold rings at either end.
	var tip := Vector3(0, by, -0.635)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.BACK, PI / 6.0) * F.Z, tip), 0.0125, 0.0172, 0.07, 6, F.NICKEL.lightened(0.05))
	for z: float in [0.034, -0.034]:
		MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.BACK, PI / 6.0) * F.Z, tip + Vector3(0, 0, z)), 0.0176 if z > 0.0 else 0.0132, 0.0176 if z > 0.0 else 0.0132, 0.004, 6, F.BRASS)
	F.box(k.m(), tip + Vector3(0, 0.011, -0.04), Vector3(0.022, 0.003, 0.02), F.NICKEL.darkened(0.08), Basis(Vector3.RIGHT, 0.6))
	F.cz(k.x(), tip + Vector3(0, 0.0, -0.0365), 0.006, 0.006, 0.002, F.BORE, 10)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var n := Vector3(cos(a), sin(a), 0)
		# A fin in the plane of the barrel axis, its leading edge swept back.
		var fin := Basis(Vector3.BACK, a - PI * 0.5) * Basis(Vector3.RIGHT, -0.1)
		F.box(k.m(), tip + n * 0.0205, Vector3(0.0014, 0.008, 0.044), F.NICKEL.darkened(0.05), fin)
		F.box(k.m(), tip + n * 0.0248, Vector3(0.0018, 0.0016, 0.044), F.BRASS, fin)
	blade(k.m(), Vector3(0, by + 0.012, -0.58), F.NICKEL, F.BRASS_LIGHT)
	buckhorn(k.m(), Vector3(0, by + 0.0128, -0.22), F.BRASS)
	# Stock: light walnut with a red and gold painted band and inlaid balls.
	var stock := rifle_stock(0.055, 0.006, 0.38, 0.046, 0.056)
	W.loft(k.w(), stock, F.WALNUT_LIGHT, 16)
	crescent(k, stock[stock.size() - 1], F.NICKEL)
	var band := [[Vector3(0, -0.018, 0.19), 0.0335, 0.0192], [Vector3(0, -0.02, 0.21), 0.0365, 0.0196]]
	W.loft(k.x(), band, POOL[2], 16)
	for z: float in [0.186, 0.214]:
		W.loft(k.m(), [[Vector3(0, -0.019 - (z - 0.186) * 0.07, z - 0.002), 0.035 + (z - 0.186) * 0.1, 0.0198], [Vector3(0, -0.019 - (z - 0.186) * 0.07, z + 0.002), 0.035 + (z - 0.186) * 0.1, 0.0198]], F.BRASS, 16)
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var c := Vector3(side * 0.02, -0.04 + (i % 2) * 0.012, 0.27 + i * 0.022)
			F.cx(k.m(), c, 0.0064, 0.0016, POOL[i], 20)
			F.cx(k.m(), c + Vector3(side * 0.0008, 0, 0), 0.0027, 0.0008, Color("#F4F1EA"), 14)
	# --- an oversized showman's lever
	lever_loop(lv.m(), PIVOTS["ricochet_rifle_lever"], F.BRASS, 1.15)
	return {"body": k.commit(), "lever": lv.commit()}


# ------------------------------------------------------------------ howdah pistol

## A howdah pistol: an elephant gun cut down to a handgun. Two short, fat
## barrels with gaping bores on a break-action, two side hammers, double
## triggers in a steel guard, dark walnut grip panels, a brass tiger's head for
## a grip cap with the holster ring through its jaws.
static func _howdah_pistol() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var hinge: Vector3 = PIVOTS["howdah_pistol_barrels"]
	case_block(k, Vector3(0, 0.008, 0.0), Vector3(0.046, 0.046, 0.06), 47)
	F.box(k.m(), Vector3(0, 0.008, -0.031), Vector3(0.046, 0.046, 0.004), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0236, 0.006, 0.006), Vector3(0.0018, 0.03, 0.044), F.BLUED)
		W.scroll(k.m(), Vector3(side * 0.0246, 0.006, 0.006), Vector3(side, 0, 0), 0.026, F.BRASS)
		side_hammer(k, Vector3(side * 0.0175, 0.026, 0.02), side, F.IRON)
	F.box(k.m(), Vector3(0, 0.033, 0.03), Vector3(0.01, 0.005, 0.03), CASE[2])
	for z: float in [-0.006, 0.01]:
		W.bent(k.m(), [Vector3(0, -0.013, z), Vector3(0, -0.022, z + 0.003), Vector3(0, -0.029, z + 0.008)], 0.0024, F.STEEL)
	W.bent(k.m(), W.arc(Vector3(0, -0.015, 0.006), 0.022, -0.25 * PI, -1.15 * PI, 10), 0.0032, F.STEEL.darkened(0.2))
	# Grip: dark walnut panels on a steel strap, swept down and back.
	var grip := [[Vector3(0, -0.002, 0.03), 0.02, 0.019], [Vector3(0, -0.03, 0.05), 0.019, 0.0165],
		[Vector3(0, -0.07, 0.07), 0.021, 0.017], [Vector3(0, -0.098, 0.082), 0.02, 0.0165]]
	W.loft(k.w(), grip, F.WALNUT_DARK, 16)
	for i in 6:
		for side: float in [-1.0, 1.0]:
			F.box(k.w(), Vector3(side * 0.0168, -0.04 - i * 0.008, 0.056 + i * 0.004), Vector3(0.001, 0.0016, 0.024), F.WALNUT_DARK.darkened(0.25), Basis(Vector3.RIGHT, 0.45))
	# The tiger's head: a brass cap with ears, brow, snout, eyes and a ring in its jaws.
	var tg := Vector3(0, -0.112, 0.088)
	F.ball(k.m(), tg, Vector3(0.0185, 0.016, 0.019), F.BRASS, 6, 14)
	for side: float in [-1.0, 1.0]:
		F.ball(k.m(), tg + Vector3(side * 0.013, 0.008, 0.008), Vector3(0.006, 0.006, 0.004), F.BRASS_DARK, 4, 8)
		F.ball(k.m(), tg + Vector3(side * 0.0075, -0.002, -0.014), Vector3(0.0032, 0.0022, 0.002), Color("#2A1A0C"), 3, 8)
		F.box(k.m(), tg + Vector3(side * 0.011, -0.004, -0.008), Vector3(0.006, 0.0012, 0.0012), F.BRASS_DARK, Basis(Vector3.UP, side * 0.4))
	F.ball(k.m(), tg + Vector3(0, -0.008, -0.016), Vector3(0.0085, 0.0068, 0.0065), F.BRASS_LIGHT, 4, 10)
	F.ball(k.m(), tg + Vector3(0, -0.006, -0.0215), Vector3(0.003, 0.0022, 0.0015), Color("#2A1A0C"), 3, 8)
	F.box(k.m(), tg + Vector3(0, 0.003, -0.016), Vector3(0.016, 0.0028, 0.006), F.BRASS_DARK)
	F.hoop(k.m(), tg + Vector3(0, -0.026, -0.004), Vector3(1, 0, 0), 0.011, 0.0022, F.BRASS_LIGHT, 18)
	# --- barrels: short and fat, oversized bores, a rib with a bead
	for side: float in [-1.0, 1.0]:
		F.cz(b.m(), Vector3(side * 0.0122, 0.02, -0.145), 0.0118, 0.0136, 0.23, F.BLUED, 18)
		muzzle(b, Vector3(side * 0.0122, 0.02, -0.261), 0.0118, 0.0085, F.BLUED, 18)
		F.cz(b.m(), Vector3(side * 0.0122, 0.02, -0.25), 0.0128, 0.0128, 0.014, F.BLUED.darkened(0.2), 18)
		F.cz(b.m(), Vector3(side * 0.0122, 0.02, -0.0315), 0.0105, 0.0105, 0.002, F.BRASS_LIGHT, 14)
	F.box(b.m(), Vector3(0, 0.034, -0.145), Vector3(0.008, 0.005, 0.22), F.BLUED.darkened(0.2))
	F.ball(b.m(), Vector3(0, 0.0375, -0.25), Vector3.ONE * 0.0024, F.BRASS_LIGHT, 4, 8)
	F.box(b.m(), Vector3(0, 0.002, -0.055), Vector3(0.016, 0.016, 0.05), F.BLUED.darkened(0.3))
	F.cx(b.m(), hinge, 0.0045, 0.026, F.STEEL, 10)
	var forend := [[Vector3(0, 0.002, -0.07), 0.012, 0.02], [Vector3(0, 0.0, -0.09), 0.014, 0.022], [Vector3(0, 0.002, -0.14), 0.011, 0.019]]
	W.loft(b.w(), forend, F.WALNUT_DARK, 14)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ sharps carbine

## A cavalry Sharps: a tall case-hardened falling-block action with a big side
## hammer on its lock plate, the lever that doubles as the trigger guard, a
## saddle ring bar on the left, a short round barrel with one band and a short
## forend, a ladder rear sight, and a field-worn straight stock and iron butt.
static func _sharps_carbine() -> Dictionary:
	var k := F.Kit.new()
	var lv := F.Kit.new()
	var by := 0.026
	case_block(k, Vector3(0, 0.008, -0.014), Vector3(0.036, 0.07, 0.11), 53)
	F.box(k.m(), Vector3(0, 0.044, -0.03), Vector3(0.022, 0.006, 0.05), CASE[0].darkened(0.1))
	# Lock plate and the big side hammer on the right.
	F.box(k.m(), Vector3(0.019, 0.006, 0.04), Vector3(0.0022, 0.034, 0.08), CASE[1])
	W.scroll(k.m(), Vector3(0.0204, 0.006, 0.05), Vector3(1, 0, 0), 0.024, CASE[0].darkened(0.3))
	F.box(k.m(), Vector3(0.022, 0.018, 0.03), Vector3(0.006, 0.014, 0.016), F.IRON)
	W.bent(k.m(), [Vector3(0.022, 0.022, 0.03), Vector3(0.023, 0.036, 0.036), Vector3(0.023, 0.046, 0.05)], 0.0042, F.IRON)
	F.box(k.m(), Vector3(0.023, 0.048, 0.058), Vector3(0.009, 0.005, 0.016), F.IRON.lightened(0.1), Basis(Vector3.RIGHT, -0.25))
	F.screw(k.m(), Vector3(0.0198, -0.004, 0.012), 1.0, F.STEEL)
	F.screw(k.m(), Vector3(0.0198, 0.012, 0.072), 1.0, F.STEEL)
	saddle_ring(k, Vector3(-0.0195, 0.006, 0.02), F.IRON)
	W.bent(k.m(), [Vector3(0, -0.024, 0.006), Vector3(0, -0.034, 0.012), Vector3(0, -0.04, 0.02)], 0.0026, F.STEEL)
	# Short round barrel, its band, short forend, sights.
	F.cz(k.m(), Vector3(0, by, -0.31), 0.0128, 0.0142, 0.5, F.BLUED, 16)
	muzzle(k, Vector3(0, by, -0.561), 0.0128, 0.0058, F.BLUED, 16)
	blade(k.m(), Vector3(0, by + 0.0128, -0.545), F.BLUED)
	ladder(k.m(), Vector3(0, by + 0.0138, -0.13), F.BLUED, 0.05)
	var forend := [[Vector3(0, 0.008, -0.072), 0.02, 0.0175], [Vector3(0, 0.006, -0.1), 0.022, 0.0185],
		[Vector3(0, 0.008, -0.22), 0.02, 0.0175], [Vector3(0, 0.012, -0.24), 0.016, 0.015]]
	W.loft(k.w(), forend, F.WALNUT.darkened(0.08), 14)
	MeshKit.add_rim(k.m(), Transform3D(F.Z, Vector3(0, 0.017, -0.215)), 0.0222, 0.0, 0.012, 18, F.BLUED)
	# Field-worn straight stock: scuffs and a dented iron buttplate.
	var stock := rifle_stock(0.044, 0.004, 0.34, 0.042, 0.054)
	W.loft(k.w(), stock, F.WALNUT.darkened(0.08), 16)
	W.buttplate(k.m(), stock, F.IRON)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var z := rng.randf_range(0.14, 0.36)
		var side := -1.0 if i % 2 == 0 else 1.0
		F.box(k.w(), Vector3(side * 0.0196, rng.randf_range(-0.04, -0.01), z), Vector3(0.001, 0.002, rng.randf_range(0.008, 0.02)), F.WALNUT_LIGHT, Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)))
	# --- the lever (it is the trigger guard), dropping the breech block with it
	var piv: Vector3 = PIVOTS["sharps_carbine_lever"]
	F.box(lv.m(), Vector3(0, -0.018, -0.024), Vector3(0.02, 0.022, 0.03), CASE[0])
	F.cx(lv.m(), piv, 0.005, 0.026, CASE[2], 10)
	var guard: Array = [piv, piv + Vector3(0, -0.01, 0.02)]
	guard.append_array(W.arc(Vector3(0, -0.038, 0.012), 0.016, -0.5 * PI, -1.25 * PI, 6))
	guard.append_array([Vector3(0, -0.035, 0.05), Vector3(0, -0.046, 0.068), Vector3(0, -0.058, 0.07), Vector3(0, -0.06, 0.06)])
	W.bent(lv.m(), guard, 0.0042, CASE[0])
	return {"body": k.commit(), "lever": lv.commit()}


# ------------------------------------------------------------------ trapdoor springfield

## The infantry trapdoor rifle: a long barrel in a full-length walnut stock
## held by three barrel bands, a ramrod in its channel, a bayonet stud, a lock
## plate and side hammer, a brass buttplate, a leather sling, and on top the
## trapdoor breechblock hinged at its front with the thumb latch at the back.
static func _trapdoor_springfield() -> Dictionary:
	var k := F.Kit.new()
	var td := F.Kit.new()
	var by := 0.024
	# Receiver and barrel.
	F.box(k.m(), Vector3(0, 0.018, -0.02), Vector3(0.03, 0.036, 0.09), F.BLUED)
	F.cz(k.m(), Vector3(0, by, -0.47), 0.0118, 0.0155, 0.83, F.BLUED, 16)
	muzzle(k, Vector3(0, by, -0.886), 0.0118, 0.0058, F.BLUED, 16)
	blade(k.m(), Vector3(0, by + 0.0118, -0.86), F.BLUED)
	F.box(k.m(), Vector3(0, by - 0.012, -0.85), Vector3(0.006, 0.006, 0.01), F.STEEL)
	ladder(k.m(), Vector3(0, by + 0.0152, -0.12), F.BLUED, 0.06)
	# Lock plate and side hammer (right side).
	F.box(k.m(), Vector3(0.0175, 0.0, 0.035), Vector3(0.0022, 0.03, 0.12), F.BLUED.lightened(0.05))
	F.screw(k.m(), Vector3(0.0188, -0.004, 0.0), 1.0, F.STEEL)
	F.screw(k.m(), Vector3(0.0188, -0.004, 0.07), 1.0, F.STEEL)
	F.box(k.m(), Vector3(0.0195, 0.012, 0.02), Vector3(0.006, 0.014, 0.016), F.BLUED.darkened(0.2))
	W.bent(k.m(), [Vector3(0.0195, 0.016, 0.022), Vector3(0.0198, 0.03, 0.026), Vector3(0.0198, 0.04, 0.038)], 0.0042, F.BLUED.darkened(0.2))
	F.box(k.m(), Vector3(0.0198, 0.042, 0.046), Vector3(0.008, 0.004, 0.014), F.STEEL, Basis(Vector3.RIGHT, -0.2))
	F.trigger_and_guard(k, Vector3(0, -0.026, 0.05), 0.022, F.BLUED.darkened(0.2))
	# Full-length stock: butt, wrist, forestock up to the last band.
	var stock := rifle_stock(0.07, 0.004, 0.4, 0.046, 0.056)
	W.loft(k.w(), stock, F.WALNUT, 16)
	W.buttplate(k.m(), stock, F.BRASS)
	var fore := [[Vector3(0, 0.004, 0.072), 0.028, 0.0175], [Vector3(0, 0.006, -0.08), 0.024, 0.017], [Vector3(0, 0.012, -0.4), 0.019, 0.0158],
		[Vector3(0, 0.016, -0.77), 0.015, 0.0145], [Vector3(0, 0.018, -0.79), 0.0135, 0.0135]]
	W.loft(k.w(), fore, F.WALNUT, 16)
	for z: float in [-0.3, -0.56, -0.765]:
		MeshKit.add_rim(k.m(), Transform3D(F.Z, Vector3(0, 0.016, z)), 0.021, 0.0, 0.012 if z > -0.7 else 0.022, 18, F.BLUED)
		F.box(k.m(), Vector3(0.019, 0.016, z), Vector3(0.003, 0.006, 0.006), F.STEEL)
	# Ramrod in its channel under the barrel, its cupped head at the muzzle.
	W.rod(k.m(), Vector3(0, -0.01, -0.86), Vector3(0, -0.012, -0.2), 0.0032, 0.0032, 8, F.STEEL)
	F.cz(k.m(), Vector3(0, -0.01, -0.865), 0.0045, 0.0045, 0.012, F.STEEL.lightened(0.1), 10)
	# Leather sling.
	sling(k, Vector3(-0.001, -0.004, -0.56), Vector3(-0.001, -0.07, 0.35), 0.075, F.LEATHER)
	# --- the trapdoor: breechblock hinged at its front, thumb latch at the back
	var piv: Vector3 = PIVOTS["trapdoor_springfield_trapdoor"]
	F.box(td.m(), piv + Vector3(0, 0.0, 0.035), Vector3(0.026, 0.014, 0.07), F.BLUED.lightened(0.04))
	F.cx(td.m(), piv, 0.0055, 0.03, F.BLUED.darkened(0.2), 10)
	F.box(td.m(), piv + Vector3(0, 0.006, 0.074), Vector3(0.016, 0.006, 0.012), F.STEEL)
	F.box(td.m(), piv + Vector3(0, 0.0102, 0.078), Vector3(0.016, 0.0012, 0.004), F.STEEL.darkened(0.3))
	for i in 3:
		F.box(td.m(), piv + Vector3(0, 0.0074, 0.012 + i * 0.016), Vector3(0.018, 0.0008, 0.0016), F.BLUED.darkened(0.2))
	return {"body": k.commit(), "trapdoor": td.commit()}


# ------------------------------------------------------------------ mare's leg

## A lever rifle sawn down: a short octagonal barrel over a short magazine and
## a stub of forend, a case-hardened receiver, an oversized loop lever, and the
## stock cut back to a curved pistol grip with a steel cap.
static func _mares_leg() -> Dictionary:
	var k := F.Kit.new()
	var lv := F.Kit.new()
	var by := 0.028
	case_block(k, Vector3(0, 0.012, -0.012), Vector3(0.034, 0.058, 0.13), 61)
	F.box(k.m(), Vector3(0, 0.0435, -0.02), Vector3(0.022, 0.006, 0.07), F.BLUED)
	F.box(k.x(), Vector3(0.0174, -0.001, -0.035), Vector3(0.0014, 0.016, 0.036), F.BORE)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.018, 0.026, -0.06), side, F.STEEL)
		F.screw(k.m(), Vector3(side * 0.018, -0.008, 0.02), side, F.STEEL)
	rifle_hammer(k.m(), Vector3(0, 0.04, 0.05), F.BLUED.darkened(0.2))
	W.bent(k.m(), [Vector3(0, -0.017, 0.01), Vector3(0, -0.03, 0.016), Vector3(0, -0.036, 0.024)], 0.0026, F.STEEL)
	# Short barrel and magazine, the sawn muzzle filed bright.
	octagon(k.m(), Vector3(0, by, -0.24), 0.0128, 0.0136, 0.33, F.BLUED)
	F.cz(k.m(), Vector3(0, 0.003, -0.22), 0.0102, 0.0102, 0.29, F.BLUED.darkened(0.12), 14)
	F.cz(k.m(), Vector3(0, 0.003, -0.368), 0.0112, 0.0112, 0.008, F.STEEL, 14)
	F.box(k.m(), Vector3(0, 0.016, -0.36), Vector3(0.012, 0.024, 0.01), F.BLUED.darkened(0.2))
	muzzle(k, Vector3(0, by, -0.406), 0.0128, 0.0058, F.STEEL, 8)
	blade(k.m(), Vector3(0, by + 0.0124, -0.39), F.BLUED)
	buckhorn(k.m(), Vector3(0, by + 0.013, -0.16), F.BLUED)
	var forend := [[Vector3(0, 0.006, -0.078), 0.019, 0.0172], [Vector3(0, 0.004, -0.11), 0.022, 0.0188],
		[Vector3(0, 0.004, -0.2), 0.021, 0.018], [Vector3(0, 0.006, -0.22), 0.0175, 0.016]]
	W.loft(k.w(), forend, F.WALNUT, 14)
	F.cz(k.m(), Vector3(0, 0.008, -0.226), 0.0172, 0.0172, 0.008, F.BLUED.darkened(0.25), 14)
	# The cut-down grip: wrist curving down into a rounded, capped butt.
	var grip := [[Vector3(0, 0.006, 0.055), 0.024, 0.0175], [Vector3(0, -0.008, 0.095), 0.019, 0.0162],
		[Vector3(0, -0.04, 0.13), 0.022, 0.0168], [Vector3(0, -0.075, 0.15), 0.026, 0.0175], [Vector3(0, -0.092, 0.155), 0.022, 0.017]]
	W.loft(k.w(), grip, F.WALNUT, 16)
	F.ball(k.m(), Vector3(0, -0.098, 0.156), Vector3(0.018, 0.006, 0.026), F.STEEL, 4, 12)
	for side: float in [-1.0, 1.0]:
		chequer(k, Vector3(side * 0.0172, -0.04, 0.125), side, 0.04, 0.03)
	# A big loop lever for spinning.
	lever_loop(lv.m(), PIVOTS["mares_leg_lever"], CASE[0], 1.2)
	return {"body": k.commit(), "lever": lv.commit()}


# ------------------------------------------------------------------ concussion mortar

## A hand-held bronze mortar (Nov 10 primary weapons evaluation): a short, wide
## bronze tube tipped up on iron trunnion cheeks over a walnut stock with a
## pistol grip and a leather-padded butt, a brass blast ring at the mouth, a
## fuse touch-hole on top. The "shell" is the powder charge sitting in the mouth
## while loaded.
static func _concussion_mortar() -> Dictionary:
	var k := F.Kit.new()
	var sh := F.Kit.new()
	var back := Vector3(0.0, 0.075, -0.1)
	var mouth: Vector3 = MUZZLE[&"concussion_mortar"]
	var axis := (mouth - back).normalized()
	# The tube: bronze, wide at the mouth, a band at the breech and a blast ring.
	MeshKit.tube(k.m(), [back, back.lerp(mouth, 0.5), mouth], [0.05, 0.046, 0.05], 20, F.BRASS_DARK)
	MeshKit.tube(k.m(), [back + axis * 0.02, back + axis * 0.05], [0.056, 0.056], 20, F.BRASS)
	MeshKit.tube(k.m(), [mouth - axis * 0.03, mouth], [0.058, 0.06], 20, F.BRASS_LIGHT)
	MeshKit.tube(k.x(), [mouth - axis * 0.002, mouth - axis * 0.12], [0.04, 0.04], 18, F.BORE) # the dark bore
	F.ball(k.m(), back - axis * 0.012, Vector3(0.05, 0.05, 0.03), F.BRASS_DARK, 6, 14) # rounded breech
	F.cz(k.m(), back + axis * 0.06 + Vector3(0, 0.05, 0), 0.006, 0.006, 0.012, F.IRON_DARK, 8) # touch-hole boss
	# Iron trunnion cheeks holding the tube on the stock.
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.05, 0.035, -0.16), Vector3(0.008, 0.07, 0.09), F.IRON)
		F.cx(k.m(), Vector3(side * 0.052, 0.07, -0.16), 0.012, 0.012, F.IRON_DARK, 10)
	F.box(k.m(), Vector3(0, 0.0, -0.13), Vector3(0.1, 0.012, 0.16), F.IRON_DARK)
	# Walnut fore-stock under the tube, pistol grip, trigger and a padded butt.
	F.box(k.w(), Vector3(0, -0.012, -0.12), Vector3(0.05, 0.03, 0.26), F.WALNUT)
	F.trigger_and_guard(k, Vector3(0, -0.018, 0.022), 0.027, F.BRASS_DARK)
	F.pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.105, 0.092), F.WALNUT, F.BRASS, 1.1)
	var stock := rifle_stock(0.06, 0.0, 0.2, 0.03, 0.05)
	W.loft(k.w(), stock, F.WALNUT_DARK, 14)
	F.box(k.x(), Vector3(0, -0.03, 0.27), Vector3(0.045, 0.06, 0.02), F.LEATHER)
	# --- the powder charge in the mouth (shown while loaded)
	F.ball(sh.x(), mouth - axis * 0.01, Vector3(0.036, 0.036, 0.036), Color("#3A3330"), 6, 12)
	F.cz(sh.m(), mouth + Vector3(0, 0.03, 0.0), 0.004, 0.004, 0.02, F.ROPE, 6) # its fuse
	return {"body": k.commit(), "shell": sh.commit()}


# ------------------------------------------------------------------ repeating crossbow

const FLETCH := Color("#C4302A")


## A lever-cocked repeating crossbow (Nov 10): a walnut tiller with a pistol
## grip, a brass gravity magazine of bolts on top, a steel prod (two limbs) at
## the front with a stirrup, the string, and the cocking lever over the
## magazine. Near silent. "bolt" is the bolt in the groove while loaded.
static func _repeating_crossbow() -> Dictionary:
	var k := F.Kit.new()
	var lv := F.Kit.new()
	var ll := F.Kit.new()
	var lr := F.Kit.new()
	var sg := F.Kit.new()
	var bl := F.Kit.new()
	# Tiller: a long walnut stock with the bolt groove on top.
	F.box(k.w(), Vector3(0, 0.012, -0.17), Vector3(0.04, 0.04, 0.5), F.WALNUT)
	F.box(k.x(), Vector3(0, 0.033, -0.2), Vector3(0.008, 0.004, 0.42), F.BORE)
	F.box(k.m(), Vector3(0, 0.03, -0.41), Vector3(0.05, 0.03, 0.03), F.STEEL) # the prod's iron
	# Gravity magazine: a brass box of bolts over the action, fletching showing.
	F.box(k.m(), Vector3(0, 0.075, -0.06), Vector3(0.03, 0.06, 0.16), F.BRASS)
	F.box(k.m(), Vector3(0, 0.106, -0.06), Vector3(0.034, 0.006, 0.17), F.BRASS_DARK)
	for i in 4:
		F.box(k.x(), Vector3(0, 0.111, -0.12 + i * 0.04), Vector3(0.012, 0.006, 0.006), FLETCH)
	# Stirrup at the nose, pistol grip and trigger, a short butt.
	F.hoop(k.m(), Vector3(0, -0.01, -0.45), Vector3(0, 0, 1), 0.03, 0.004, F.STEEL, 14)
	F.trigger_and_guard(k, Vector3(0, -0.018, 0.022), 0.027, F.BRASS_DARK)
	F.pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.105, 0.092), F.WALNUT, F.BRASS, 1.0)
	var stock := rifle_stock(0.07, 0.006, 0.22, 0.036, 0.05)
	W.loft(k.w(), stock, F.WALNUT_DARK, 14)
	# --- the prod's two limbs (they flex with the shot)
	for pair: Array in [[ll, -1.0, "limb_l"], [lr, 1.0, "limb_r"]]:
		var kit: F.Kit = pair[0]
		var side: float = pair[1]
		var piv: Vector3 = PIVOTS["repeating_crossbow_" + String(pair[2])]
		W.bent(kit.m(), [piv, piv + Vector3(side * 0.11, 0.0, -0.012), piv + Vector3(side * 0.22, 0.0, 0.02)], 0.0055, F.STEEL)
		F.ball(kit.m(), piv + Vector3(side * 0.22, 0.0, 0.02), Vector3.ONE * 0.006, F.BRASS, 4, 8)
	# --- the string, limb tip to limb tip round the nut
	W.bent(sg.x(), [Vector3(-0.25, 0.03, -0.38), Vector3(0, 0.04, -0.3), Vector3(0.25, 0.03, -0.38)], 0.0015, F.ROPE)
	# --- the cocking lever over the magazine
	W.bent(lv.m(), [PIVOTS["repeating_crossbow_lever"], Vector3(0, 0.07, 0.0), Vector3(0, 0.12, -0.04)], 0.0045, F.BLUED)
	F.ball(lv.w(), Vector3(0, 0.125, -0.045), Vector3(0.012, 0.012, 0.016), F.WALNUT_LIGHT, 4, 8)
	# --- the bolt in the groove
	F.cz(bl.w(), Vector3(0, 0.042, -0.28), 0.004, 0.004, 0.26, F.WALNUT_LIGHT, 8)
	F.cz(bl.m(), Vector3(0, 0.042, -0.415), 0.0, 0.007, 0.02, F.STEEL, 8)
	F.box(bl.x(), Vector3(0, 0.048, -0.16), Vector3(0.002, 0.012, 0.03), FLETCH)
	return {"body": k.commit(), "lever": lv.commit(), "limb_l": ll.commit(), "limb_r": lr.commit(),
		"string": sg.commit(), "bolt": bl.commit()}
