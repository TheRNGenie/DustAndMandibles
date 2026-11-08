class_name UniKit
extends RefCounted
## Shared pieces for the universal crop-fed turrets (gen/universal_*.gd), built
## in code as placeholders split into the parts the handoff asks for, so each can
## move. Everything is written into SurfaceTools with vertex colours (MeshKit);
## UniRig turns a builder's part list into nodes.
##
## Conventions (every builder follows them):
##   - Turret space: +Y up, the gun points down -Z (towards the canyon). The
##     base platform's top is at y = PLATFORM_TOP.
##   - Parts hang off "base" (doesn't move), "head" (yaws: the turret body) or
##     "gun" (pitches: the barrels), or off another part by name (its pivot).
##   - A part's mesh is built round its own pivot (its origin is the hinge or
##     axle it turns on); "pos" places that pivot in its parent's space.
##   - "glow": true parts light up in the loaded crop's colour (barrel glow,
##     gauges, capacitors; vertex colour GLOW_WHITE). "crop": true parts are the
##     crop you can see (hopper fill, drum slots): shown only while loaded, tinted.

const IRON := Color("#4A4E58")
const IRON_DK := Color("#30333B")
const IRON_LT := Color("#6A707C")
const BRASS := Color("#D6A74A")
const BRASS_DK := Color("#9C7430")
const COPPER := Color("#C46A3A")
const WOOD := Color("#8A5A34")
const WOOD_DK := Color("#5E3B22")
const LEATHER := Color("#6B4126")
const ROPE := Color("#C8A878")
const GLASS := Color("#9FC8D0")
const BOLT := Color("#7C828E")
## Vertex colour for glow parts and crop fill (the material sets the colour).
const GLOW_WHITE := Color(1, 1, 1)

## Top of the shared base platform (cliff turrets).
const PLATFORM_TOP := 0.18
## Rest pitch of an unloaded turret's barrel (45 degrees up).
const REST_UP := PI / 4.0

## Along -Z: a basis that turns a MeshKit cylinder (built along +Y) to lie along Z.
const ALONG_Z := Basis(Vector3.RIGHT, PI * 0.5)
## Along X.
const ALONG_X := Basis(Vector3.BACK, PI * 0.5)


## A cylinder from z0 to z1 (z1 further out along -Z), radius r, centred on (x, y).
static func barrel(st: SurfaceTool, x: float, y: float, z0: float, z1: float, r: float, color: Color, segments: int = 12, r_end: float = -1.0) -> void:
	var len := absf(z1 - z0)
	var rb := r
	var rt := r if r_end < 0.0 else r_end
	# MeshKit cylinders run along +Y; ALONG_Z maps +Y to +Z... so flip so r_end sits at z1.
	var mid := Vector3(x, y, (z0 + z1) * 0.5)
	var b := ALONG_Z if z1 > z0 else Basis(Vector3.RIGHT, -PI * 0.5)
	MeshKit.add_cylinder(st, Transform3D(b, mid), rb, rt, len, segments, color)


## A ring band round a barrel at z (along Z).
static func band(st: SurfaceTool, x: float, y: float, z: float, r: float, width: float, color: Color = BRASS) -> void:
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(x, y, z)), r, r, width, 14, color)


## A ring of rivet heads round a circle of radius r at height y (on a horizontal face).
static func rivet_ring(st: SurfaceTool, c: Vector3, r: float, n: int, size: float = 0.022, color: Color = BOLT) -> void:
	for i in n:
		var a := TAU * i / float(n)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + Vector3(cos(a) * r, 0, sin(a) * r)), Vector3(size, size * 0.6, size), 2, 6, color)


## A row of rivets from a to b.
static func rivet_row(st: SurfaceTool, a: Vector3, b: Vector3, n: int, size: float = 0.018, color: Color = BOLT) -> void:
	for i in n:
		var p := a.lerp(b, (i + 0.5) / float(n))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * size, 2, 6, color)


## A bolt head (hex-ish cylinder) standing on a face, pointing along `up`.
static func bolt(st: SurfaceTool, at: Vector3, up: Vector3 = Vector3.UP, r: float = 0.035, h: float = 0.03) -> void:
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(up), at + up * h * 0.5), r, r, h, 6, BOLT)


## The shared cliff turret base: a flat iron mounting plate with bolts, a brass
## lip and a bearing ring the head turns on. Top at PLATFORM_TOP. Radius ~0.8.
static func platform(st: SurfaceTool, r: float = 0.8) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), r, r, 0.12, 8, IRON_DK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.145, 0)), r * 0.86, r * 0.86, 0.07, 8, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.125, 0)), r * 0.98, r * 0.98, 0.02, 8, BRASS_DK)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		bolt(st, Vector3(cos(a) * r * 0.72, PLATFORM_TOP, sin(a) * r * 0.72), Vector3.UP, 0.04, 0.035)
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, PLATFORM_TOP + 0.015, 0)), 0.36, 0.28, 0.03, 18, BRASS)


## An angled roof / clifftop bracket for the air-defense guns: a squat iron
## pedestal on a square foot. Top at `top`.
static func roof_mount(st: SurfaceTool, top: float = 0.55) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(1.2, 0.1, 1.2), IRON_DK)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			bolt(st, Vector3(sx * 0.48, 0.1, sz * 0.48))
			MeshKit.add_limb(st, Vector3(sx * 0.42, 0.1, sz * 0.42), Vector3(sx * 0.12, top - 0.08, sz * 0.12), 0.03, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, top * 0.5 + 0.05, 0)), 0.2, 0.16, top - 0.1, 10, IRON)
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, top - 0.02, 0)), 0.3, 0.2, 0.04, 16, BRASS)


## A porch-rail / wall bracket for the house guns: an iron plate with a swivel
## stub. Top of the swivel at `top`.
static func porch_mount(st: SurfaceTool, top: float = 0.45) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.04, 0)), Vector3(0.7, 0.08, 0.7), IRON_DK)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			bolt(st, Vector3(sx * 0.27, 0.08, sz * 0.27), Vector3.UP, 0.03, 0.025)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, top * 0.5 + 0.04, 0)), 0.11, 0.09, top - 0.08, 10, IRON)
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, top - 0.02, 0)), 0.18, 0.11, 0.04, 14, BRASS)


## The crewed guns' bigger platform: a timber deck on iron skids, ~2.4 m square,
## with a step at the back. Deck top at `top`.
static func heavy_platform(st: SurfaceTool, top: float = 0.35, half: float = 1.2) -> void:
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (half - 0.15), 0.08, 0)), Vector3(0.22, 0.16, half * 2.0), IRON_DK)
	for i in 8:
		var x := -half + (i + 0.5) * half * 2.0 / 8.0
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, top - 0.05, 0)), Vector3(half * 2.0 / 8.0 - 0.02, 0.1, half * 2.0), WOOD if i % 2 == 0 else WOOD_DK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, top * 0.35, half + 0.18)), Vector3(0.9, top * 0.7, 0.36), WOOD_DK)
	rivet_row(st, Vector3(-half, top, -half + 0.06), Vector3(half, top, -half + 0.06), 10)
	rivet_row(st, Vector3(-half, top, half - 0.06), Vector3(half, top, half - 0.06), 10)


## A simple pressure gauge face (a disc and a rim) facing +`face`, at `at`;
## the needle is its own part (see needle()).
static func gauge(st: SurfaceTool, at: Vector3, face: Vector3, r: float = 0.07) -> void:
	var b := MeshKit.basis_from_y(face)
	MeshKit.add_cylinder(st, Transform3D(b, at), r, r, 0.03, 14, Color("#EDE3C8"))
	MeshKit.add_rim(st, Transform3D(b, at + face * 0.012), r + 0.012, r, 0.035, 14, BRASS)


## A gauge needle along +Y from its pivot (turn it about the gauge's face axis).
static func needle(st: SurfaceTool, length: float = 0.055) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, length * 0.5, 0)), Vector3(0.008, length, 0.006), Color("#B8352A"))


## Builds a part's mesh with a callable that writes into a fresh SurfaceTool.
static func mesh(fill: Callable) -> ArrayMesh:
	var st := MeshKit.begin()
	fill.call(st)
	return MeshKit.finish(st)


## A part entry for a builder's "parts" list.
static func part(name: String, parent: String, m: ArrayMesh, pos: Vector3 = Vector3.ZERO, basis: Basis = Basis(), extra: Dictionary = {}) -> Dictionary:
	var d := {"name": name, "parent": parent, "mesh": m, "pos": pos, "basis": basis}
	d.merge(extra)
	return d


## A bare pivot (no mesh) other parts can hang off.
static func pivot(name: String, parent: String, pos: Vector3 = Vector3.ZERO, basis: Basis = Basis()) -> Dictionary:
	return {"name": name, "parent": parent, "mesh": null, "pos": pos, "basis": basis}


# ------------------------------------------------------------------ tier trims

## Tier 2 (index 1): brass trim bands round a body part; Tier 3 (index 2): dark
## armour plates on its sides and thin glowing trim lines. `trim` (a part's
## "trim" entry, in the part's own space) is either round {"c": centre, "r":
## radius, "h": height} (an upright drum) or a box {"c": centre, "size": Vector3}.
## Returns [trim mesh, glow mesh] (either may be null).
static func tier_trim(trim: Dictionary, tier: int) -> Array:
	if tier <= 0 or trim.is_empty():
		return [null, null]
	var st := MeshKit.begin()
	var c: Vector3 = trim.get("c", Vector3.ZERO)
	if trim.has("r"):
		var r := float(trim["r"])
		var h := float(trim.get("h", 0.4))
		for f: float in [-0.35, 0.35]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), c + Vector3(0, h * f, 0)), r + 0.018, r + 0.018, 0.04, 18, BRASS)
		var gst2: SurfaceTool = null
		if tier >= 2:
			for i in 6:
				var a := TAU * (i + 0.5) / 6.0
				var n := Vector3(cos(a), 0, sin(a))
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), c + n * (r + 0.025)), Vector3(0.025, h * 0.55, r * 0.75), IRON_DK)
				bolt(st, c + n * (r + 0.04) + Vector3(0, h * 0.18, 0), n, 0.016, 0.015)
			gst2 = MeshKit.begin()
			MeshKit.add_cylinder(gst2, Transform3D(Basis(), c + Vector3(0, -h * 0.5 + 0.02, 0)), r + 0.03, r + 0.03, 0.02, 18, GLOW_WHITE)
		return [MeshKit.finish(st), MeshKit.finish(gst2) if gst2 != null else null]
	var s: Vector3 = trim.get("size", Vector3(0.4, 0.4, 0.4))
	var box := AABB(c - s * 0.5, s)
	for f: float in [0.2, 0.8]:
		var y := box.position.y + s.y * f
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(c.x, y, c.z)), Vector3(s.x + 0.03, 0.035, s.z + 0.03), BRASS)
	var gst: SurfaceTool = null
	if tier >= 2:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(c.x + sx * (s.x * 0.5 + 0.02), c.y, c.z)), Vector3(0.03, s.y * 0.7, s.z * 0.8), IRON_DK)
			rivet_row(st, Vector3(c.x + sx * (s.x * 0.5 + 0.04), c.y + s.y * 0.3, c.z - s.z * 0.35), Vector3(c.x + sx * (s.x * 0.5 + 0.04), c.y + s.y * 0.3, c.z + s.z * 0.35), 4, 0.016)
		gst = MeshKit.begin()
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(gst, Transform3D(Basis(), Vector3(c.x + sx * (s.x * 0.5 + 0.04), c.y - s.y * 0.1, c.z)), Vector3(0.012, 0.02, s.z * 0.75), GLOW_WHITE, 0.0, null, 0.9)
	return [MeshKit.finish(st), MeshKit.finish(gst) if gst != null else null]
