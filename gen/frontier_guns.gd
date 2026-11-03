class_name FrontierGuns
extends RefCounted
## The eight frontier guns, built from primitives at real size in gun space
## (barrel along -Z, +Y up, origin in the frame just above the trigger), like
## WeaponBuilder's. Unlike the toon-shaded props they come out in four
## surfaces with real materials (polished metal, varnished wood, matte
## leather/paper/rope, and glowing bits), so brass shines and walnut has a
## clear coat next to the Meshy guns. Every moving part is its own mesh, built
## in gun space and hung on a pivot (PIVOTS) by ViewModel:
##   derringer_pair:  "barrels" tip up to load (one pistol; the pair is two)
##   pepperbox:       "drum" (six barrels) turns a sixth per shot
##   harpoon_pistol:  "reel" spins, "dart" is the loaded harpoon
##   flare_gun:       "barrels" drop open
##   salt_shotgun:    "pump" racks back after each shot
##   punt_gun:        "barrels" drop open
##   bee_smoker:      "bellows" squeeze, "pleats" (leather) fan with them
##   telescope_rifle: "bolt" lifts, draws back and closes

const IDS: Array[StringName] = [&"derringer_pair", &"pepperbox", &"salt_shotgun", &"harpoon_pistol",
	&"bee_smoker", &"flare_gun", &"punt_gun", &"telescope_rifle"]

const PIVOTS: Dictionary = {
	"derringer_pair_barrels": Vector3(0.0, 0.034, -0.016),
	"pepperbox_drum": Vector3(0.0, 0.021, 0.0),
	"harpoon_pistol_reel": Vector3(0.0, -0.026, -0.088),
	"harpoon_pistol_dart": Vector3(0.0, 0.026, -0.24),
	"flare_gun_barrels": Vector3(0.0, -0.004, -0.022),
	"salt_shotgun_pump": Vector3(0.0, -0.014, -0.2),
	"punt_gun_barrels": Vector3(0.0, -0.034, -0.085),
	"bee_smoker_bellows": Vector3(0.0, -0.079, -0.014),
	"bee_smoker_pleats": Vector3(0.0, -0.079, -0.014),
	"telescope_rifle_bolt": Vector3(0.0, 0.017, 0.03),
}
## Rest angle of hinged parts (radians about X): the smoker's bellows sit open.
const BELLOWS_OPEN := 0.32
## Where the shot leaves each gun (gun space): flash, smoke, tracers.
const MUZZLE: Dictionary = {
	&"derringer_pair": Vector3(0.0, 0.026, -0.125), &"pepperbox": Vector3(0.0, 0.021, -0.135),
	&"harpoon_pistol": Vector3(0.0, 0.026, -0.25), &"flare_gun": Vector3(0.0, 0.026, -0.195),
	&"salt_shotgun": Vector3(0.0, 0.018, -0.645), &"punt_gun": Vector3(0.0, 0.03, -0.64),
	&"bee_smoker": Vector3(0.0, 0.186, -0.19), &"telescope_rifle": Vector3(0.0, 0.016, -0.715),
}
## Each gun's reload foley borrows an old gun's (Gun._foley).
const FOLEY: Dictionary = {&"derringer_pair": &"revolver", &"pepperbox": &"revolver", &"harpoon_pistol": &"lever_rifle",
	&"flare_gun": &"coach_shotgun", &"salt_shotgun": &"lever_rifle", &"punt_gun": &"coach_shotgun",
	&"telescope_rifle": &"lever_rifle", &"bee_smoker": &"crank_gatling"}

const BRASS := Color("#D9A845")
const BRASS_DARK := Color("#A47830")
const BRASS_LIGHT := Color("#F0CC72")
const NICKEL := Color("#C9CED4")
const IRON := Color("#4C525A")
const IRON_DARK := Color("#2D3137")
const BLUED := Color("#3E4A57")
const STEEL := Color("#9AA4AD")
const WALNUT := Color("#7A4A2A")
const WALNUT_DARK := Color("#55311B")
const WALNUT_LIGHT := Color("#9C6638")
const IVORY := Color("#EDE3CA")
const LEATHER := Color("#6B4426")
const ROPE := Color("#C8A46A")
const TIN := Color("#BDB9AF")
const COPPER := Color("#C2703C")
const SOOT := Color("#221E1C")
const BORE := Color("#0E0C0B")
const SIGNAL_RED := Color("#C4302A")
const SALT_BLUE := Color("#2F5E9E")

const Z := Basis(Vector3.RIGHT, PI * 0.5)
## Cylinders along X (axis = gun's side-to-side).
const X := Basis(Vector3.BACK, PI * 0.5)


static func has(id: StringName) -> bool:
	return IDS.has(id)


# ------------------------------------------------------------------ materials

static var _mats: Array[Material] = []


## 0 metal, 1 varnished wood / ivory, 2 matte (leather, paper, rope, soot), 3 glow.
static func material(i: int) -> Material:
	if _mats.is_empty():
		var metal := StandardMaterial3D.new()
		metal.vertex_color_use_as_albedo = true
		metal.metallic = 0.62
		metal.roughness = 0.32
		metal.metallic_specular = 0.65
		var wood := StandardMaterial3D.new()
		wood.vertex_color_use_as_albedo = true
		wood.roughness = 0.5
		wood.clearcoat_enabled = true
		wood.clearcoat = 0.35
		wood.clearcoat_roughness = 0.25
		var matte := StandardMaterial3D.new()
		matte.vertex_color_use_as_albedo = true
		matte.roughness = 0.92
		var glow := StandardMaterial3D.new()
		glow.vertex_color_use_as_albedo = true
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats = [metal, wood, matte, glow]
	return _mats[i]


## Four SurfaceTools, one per material, committed into one mesh.
class Kit:
	extends RefCounted
	var _st: Array[SurfaceTool] = []
	var _used: Array[bool] = [false, false, false, false]

	func _init() -> void:
		for i in 4:
			_st.append(MeshKit.begin())

	func m() -> SurfaceTool:
		_used[0] = true
		return _st[0]

	func w() -> SurfaceTool:
		_used[1] = true
		return _st[1]

	func x() -> SurfaceTool:
		_used[2] = true
		return _st[2]

	func g() -> SurfaceTool:
		_used[3] = true
		return _st[3]

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for i in 4:
			if not _used[i]:
				continue
			_st[i].index()
			var arrays := _st[i].commit_to_arrays()
			if i == 1:
				FrontierGuns.grain(arrays)
			elif i == 0:
				FrontierGuns.wear(arrays)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, FrontierGuns.material(i))
		return mesh


## Wood grain painted into the vertex colours: long dark streaks running down
## the length of the gun that wander a little, and a slow light/dark figure.
static func grain(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in verts.size():
		var p := verts[i]
		var wander := sin(p.z * 23.0 + p.x * 9.0) * 1.6 + sin(p.z * 61.0) * 0.5
		var streak := 0.5 + 0.5 * sin(p.y * 420.0 + p.x * 260.0 + wander)
		var figure := 0.5 + 0.5 * sin(p.z * 11.0 + p.y * 37.0)
		var k := lerpf(0.8, 1.06, 1.0 - pow(streak, 6.0)) * lerpf(0.94, 1.05, figure)
		var c := cols[i]
		cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)
	arrays[Mesh.ARRAY_COLOR] = cols


## Metal wear: edges and high spots a touch brighter (handled), the undersides
## a touch darker, as if grimy, so flat plates don't read as one colour.
static func wear(arrays: Array) -> void:
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in cols.size():
		var k := lerpf(0.8, 1.08, 0.5 + 0.5 * norms[i].y)
		var c := cols[i]
		cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)
	arrays[Mesh.ARRAY_COLOR] = cols


# ------------------------------------------------------------------ shape helpers

## Cylinder along Z centred at c (r_front at the muzzle end).
static func cz(st: SurfaceTool, c: Vector3, r_front: float, r_back: float, length: float, col: Color, segs: int = 16) -> void:
	MeshKit.add_cylinder(st, Transform3D(Z, c), r_front, r_back, length, segs, col)


static func cx(st: SurfaceTool, c: Vector3, r: float, length: float, col: Color, segs: int = 14) -> void:
	MeshKit.add_cylinder(st, Transform3D(X, c), r, r, length, segs, col)


static func box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, rot: Basis = Basis()) -> void:
	MeshKit.add_box(st, Transform3D(rot, c), size, col)


static func ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rings: int = 5, segs: int = 10) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), c), r, rings, segs, col)


## A closed ring (torus) of `r` round centre c, in the plane facing `n`.
static func hoop(st: SurfaceTool, c: Vector3, n: Vector3, r: float, thick: float, col: Color, steps: int = 16) -> void:
	var nn := n.normalized()
	var u := (Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).cross(nn).normalized()
	var v := nn.cross(u)
	var pts: Array = []
	var radii: Array = []
	for i in steps + 1:
		var a := TAU * float(i) / steps
		pts.append(c + (u * cos(a) + v * sin(a)) * r)
		radii.append(thick)
	MeshKit.tube(st, pts, radii, 6, col)


## Little brass screw heads on a flat side.
static func screw(st: SurfaceTool, p: Vector3, side: float, col: Color = BRASS) -> void:
	MeshKit.add_cylinder(st, Transform3D(X, p + Vector3(side * 0.001, 0, 0)), 0.0032, 0.0032, 0.003, 8, col)


## A revolver-style plow-handle grip between `top` and `bottom` (walnut or
## ivory panels, brass back strap and butt cap), as on the starter revolver.
static func pistol_grip(k: Kit, top: Vector3, bottom: Vector3, panel: Color, strap: Color, fat: float = 1.0) -> void:
	var mid := (top + bottom) * 0.5
	var stations := [[top, 0.015 * fat, 0.0115 * fat], [mid + Vector3(0, 0, -0.003), 0.0165 * fat, 0.0122 * fat],
		[bottom + Vector3(0, 0.008, -0.002), 0.019 * fat, 0.0135 * fat], [bottom, 0.016 * fat, 0.012 * fat]]
	WeaponBuilder.loft(k.w(), stations, panel, 14)
	WeaponBuilder.bent(k.m(), [top + Vector3(0, 0.008, 0.016 * fat), mid + Vector3(0, 0, 0.017 * fat),
			bottom + Vector3(0, 0.006, 0.018 * fat)], 0.0042, strap)
	MeshKit.add_ellipsoid(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.4), bottom + Vector3(0, -0.006, 0.003)),
			Vector3(0.0205, 0.009, 0.025) * fat, 4, 10, strap)
	for side: float in [-1.0, 1.0]:
		screw(k.m(), mid + Vector3(side * 0.0125 * fat, 0, 0), side, strap)


static func trigger_and_guard(k: Kit, c: Vector3, r: float, guard: Color, trig: Color = STEEL) -> void:
	WeaponBuilder.bent(k.m(), [c + Vector3(0, 0.012, -0.01), c + Vector3(0, -0.004, -0.006), c + Vector3(0, -0.012, 0.002)], 0.0028, trig)
	WeaponBuilder.bent(k.m(), WeaponBuilder.arc(c + Vector3(0, 0.005, 0.0), r, -0.35 * PI, -1.15 * PI, 10), 0.0034, guard)


# ------------------------------------------------------------------ public

static var _cache: Dictionary = {}


## The meshes of gun `id`: {"body": mesh, part name: mesh, ...}, all in gun space.
static func parts(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out: Dictionary = {}
	match id:
		&"derringer_pair":
			out = _derringer()
		&"pepperbox":
			out = _pepperbox()
		&"harpoon_pistol":
			out = _harpoon()
		&"flare_gun":
			out = _flare()
		&"salt_shotgun":
			out = _salt()
		&"punt_gun":
			out = _punt()
		&"bee_smoker":
			out = _smoker()
		&"telescope_rifle":
			out = _telescope()
	_cache[id] = out
	return out


static func pivot(id: StringName, part: String) -> Vector3:
	return PIVOTS.get("%s_%s" % [id, part], Vector3.ZERO)


## A part mesh hung on a pivot node at its hinge (so turning the node turns it right).
static func part_node(id: StringName, part: String, shadows: bool = false) -> Node3D:
	var mesh: ArrayMesh = parts(id).get(part)
	if mesh == null:
		return null
	var piv := Node3D.new()
	piv.name = part.capitalize()
	piv.position = pivot(id, part)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -piv.position
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piv.add_child(mi)
	return piv


## The whole gun at rest in one node (hands, the ground, icons). `pair`: the
## derringers come as two pistols (one for the field and icons, one per hand).
static func whole(id: StringName, shadows: bool = true, pair: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
	var p := parts(id)
	if p.is_empty():
		return null
	for part: String in p:
		if part == "body":
			var mi := MeshInstance3D.new()
			mi.mesh = p[part]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		else:
			var n := part_node(id, part, shadows)
			if id == &"bee_smoker":
				n.rotation.x = BELLOWS_OPEN * (0.6 if part == "pleats" else 1.0)
			root.add_child(n)
	if id == &"derringer_pair" and pair:
		# The second pistol rides alongside, a touch higher and turned out.
		var twin := whole(id, shadows, false)
		twin.position = Vector3(-0.034, 0.05, 0.03)
		twin.rotation = Vector3(0.18, 0.12, -0.1)
		root.add_child(twin)
	return root


# ------------------------------------------------------------------ derringer pair

## One Remington-style over-under derringer: nickel frame with gold scroll,
## ivory bird's-head grip, spur trigger, barrels that tip up on a top hinge.
## Drawn a quarter oversize so it reads in a fist.
static func _derringer() -> Dictionary:
	var k := Kit.new()
	var b := Kit.new()
	# --- barrels (tip up about the hinge at their top rear)
	for y: float in [0.026, 0.0035]:
		cz(b.m(), Vector3(0, y, -0.069), 0.0112, 0.0118, 0.106, NICKEL, 16)
		cz(b.m(), Vector3(0, y, -0.1235), 0.0121, 0.0121, 0.005, NICKEL.lightened(0.15), 16)
		cz(b.m(), Vector3(0, y, -0.1263), 0.0068, 0.0068, 0.0012, BORE, 12)
	box(b.m(), Vector3(0, 0.0148, -0.069), Vector3(0.0142, 0.019, 0.104), NICKEL.darkened(0.06))
	box(b.m(), Vector3(0, 0.0385, -0.068), Vector3(0.0072, 0.0042, 0.1), NICKEL.lightened(0.12))
	box(b.m(), Vector3(0, 0.0428, -0.117), Vector3(0.0026, 0.0055, 0.009), NICKEL)
	cx(b.m(), Vector3(0, 0.034, -0.016), 0.0068, 0.026, NICKEL.darkened(0.12), 12)
	# Gold scroll down each barrel flat.
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.scroll(b.m(), Vector3(side * 0.0119, 0.0148, -0.06), Vector3(side, 0, 0), 0.024, BRASS)
	# --- frame
	box(k.m(), Vector3(0, 0.0165, 0.006), Vector3(0.0225, 0.05, 0.044), NICKEL)
	box(k.m(), Vector3(0, 0.0395, 0.012), Vector3(0.016, 0.006, 0.034), NICKEL.lightened(0.1))
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.scroll(k.m(), Vector3(side * 0.0114, 0.016, 0.008), Vector3(side, 0, 0), 0.03, BRASS)
		screw(k.m(), Vector3(side * 0.0113, 0.03, 0.022), side, BRASS_LIGHT)
		screw(k.m(), Vector3(side * 0.0113, 0.0, -0.006), side, BRASS_LIGHT)
	# Hammer with a knurled spur, cocked back.
	box(k.m(), Vector3(0, 0.046, 0.031), Vector3(0.0085, 0.024, 0.012), IRON, Basis(Vector3.RIGHT, -0.45))
	box(k.m(), Vector3(0, 0.0585, 0.041), Vector3(0.0125, 0.0055, 0.016), IRON_DARK, Basis(Vector3.RIGHT, -0.95))
	# Spur trigger in its sheath (no guard).
	box(k.m(), Vector3(0, -0.011, 0.004), Vector3(0.009, 0.01, 0.018), NICKEL.darkened(0.08))
	WeaponBuilder.bent(k.m(), [Vector3(0, -0.014, 0.0), Vector3(0, -0.025, 0.002), Vector3(0, -0.032, 0.009)], 0.003, BRASS)
	# Bird's-head grip: ivory panels on a nickel strap, a lanyard ring at the head.
	var grip := [[Vector3(0, 0.006, 0.026), 0.015, 0.0112], [Vector3(0, -0.02, 0.034), 0.0165, 0.0118],
		[Vector3(0, -0.045, 0.045), 0.0165, 0.012], [Vector3(0, -0.063, 0.045), 0.0135, 0.0112], [Vector3(0, -0.073, 0.035), 0.0085, 0.0092]]
	WeaponBuilder.loft(k.w(), grip, IVORY, 14)
	WeaponBuilder.bent(k.m(), [Vector3(0, 0.014, 0.03), Vector3(0, -0.018, 0.0495), Vector3(0, -0.046, 0.0605),
			Vector3(0, -0.066, 0.056), Vector3(0, -0.078, 0.04)], 0.0042, NICKEL)
	WeaponBuilder.bent(k.m(), [Vector3(0, -0.004, 0.012), Vector3(0, -0.03, 0.02), Vector3(0, -0.056, 0.03), Vector3(0, -0.075, 0.03)], 0.0035, NICKEL)
	for side: float in [-1.0, 1.0]:
		screw(k.m(), Vector3(side * 0.0122, -0.038, 0.042), side, NICKEL.lightened(0.2))
	hoop(k.m(), Vector3(0, -0.084, 0.04), Vector3(1, 0, 0), 0.0065, 0.0016, BRASS, 12)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ pepperbox

## Six barrels bored into one block that turns round a pin, an engraved nickel
## frame, the bar hammer lying along the top, a ring trigger and a bag grip.
static func _pepperbox() -> Dictionary:
	var k := Kit.new()
	var d := Kit.new()
	var axis := Vector3(0, 0.021, 0.0)
	# --- the barrel cluster (turns about Z through `axis`)
	cz(d.m(), axis + Vector3(0, 0, -0.066), 0.013, 0.013, 0.124, IRON_DARK, 12)
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		var p := Vector3(cos(a), sin(a), 0.0) * 0.0168
		cz(d.m(), axis + p + Vector3(0, 0, -0.066), 0.0079, 0.0084, 0.124, IRON, 12)
		cz(d.m(), axis + p + Vector3(0, 0, -0.1285), 0.0083, 0.0083, 0.003, STEEL, 12)
		cz(d.m(), axis + p + Vector3(0, 0, -0.1302), 0.0047, 0.0047, 0.001, BORE, 10)
		# Percussion nipples with copper caps at the back.
		cz(d.m(), axis + p * 0.85 + Vector3(0, 0, 0.004), 0.0025, 0.0032, 0.007, IRON_DARK, 8)
		cz(d.m(), axis + p * 0.85 + Vector3(0, 0, 0.0085), 0.0036, 0.0036, 0.004, COPPER, 8)
	for z: float in [-0.022, -0.112]:
		cz(d.m(), axis + Vector3(0, 0, z), 0.0256, 0.0256, 0.005, BRASS, 18)
	cz(d.m(), axis + Vector3(0, 0, -0.067), 0.0254, 0.0254, 0.003, NICKEL, 18)
	# --- frame: an engraved nickel box with a round recoil shield behind the cluster.
	box(k.m(), Vector3(0, 0.014, 0.03), Vector3(0.027, 0.042, 0.04), NICKEL)
	cz(k.m(), axis + Vector3(0, 0, 0.0145), 0.021, 0.021, 0.006, NICKEL.darkened(0.08), 18)
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.scroll(k.m(), Vector3(side * 0.0137, 0.014, 0.03), Vector3(side, 0, 0), 0.032, BRASS)
		screw(k.m(), Vector3(side * 0.0136, 0.026, 0.044), side, BRASS_LIGHT)
	# The bar hammer: a long flat arm over the frame, its nose on the top nipple.
	box(k.m(), Vector3(0, 0.044, 0.026), Vector3(0.0075, 0.0075, 0.056), IRON, Basis(Vector3.RIGHT, 0.08))
	box(k.m(), Vector3(0, 0.044, 0.0), Vector3(0.0095, 0.012, 0.01), IRON_DARK)
	box(k.m(), Vector3(0, 0.051, 0.058), Vector3(0.011, 0.005, 0.016), IRON_DARK, Basis(Vector3.RIGHT, -0.5))
	# Ring trigger hanging under the frame.
	WeaponBuilder.bent(k.m(), [Vector3(0, -0.006, 0.022), Vector3(0, -0.014, 0.022)], 0.0026, STEEL)
	hoop(k.m(), Vector3(0, -0.026, 0.022), Vector3(1, 0, 0), 0.0115, 0.0028, BRASS, 16)
	# Bag grip, flaring at the butt, brass cap.
	var stations := [[Vector3(0, 0.0, 0.046), 0.014, 0.0118], [Vector3(0, -0.03, 0.058), 0.0158, 0.0125],
		[Vector3(0, -0.064, 0.074), 0.0195, 0.0142], [Vector3(0, -0.092, 0.086), 0.0205, 0.0148], [Vector3(0, -0.1, 0.088), 0.013, 0.011]]
	WeaponBuilder.loft(k.w(), stations, WALNUT, 14)
	MeshKit.add_ellipsoid(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, -0.1, 0.088)), Vector3(0.016, 0.006, 0.02), 4, 10, BRASS)
	WeaponBuilder.bent(k.m(), [Vector3(0, 0.008, 0.06), Vector3(0, -0.03, 0.072), Vector3(0, -0.07, 0.092), Vector3(0, -0.096, 0.104)], 0.0038, BRASS)
	for side: float in [-1.0, 1.0]:
		screw(k.m(), Vector3(side * 0.015, -0.05, 0.068), side)
	return {"body": k.commit(), "drum": d.commit()}


# ------------------------------------------------------------------ harpoon pistol

## A brass spring pistol with a thick barrel, a line spool under it and a
## barbed whaling dart in the muzzle.
static func _harpoon() -> Dictionary:
	var k := Kit.new()
	var reel := Kit.new()
	var dart := Kit.new()
	var bore_y := 0.026
	# Frame and barrel.
	box(k.m(), Vector3(0, 0.012, 0.018), Vector3(0.03, 0.05, 0.074), BRASS)
	cz(k.m(), Vector3(0, bore_y, -0.13), 0.0172, 0.0178, 0.22, IRON, 16)
	cz(k.m(), Vector3(0, bore_y, -0.2425), 0.0225, 0.019, 0.013, BRASS, 18)
	cz(k.m(), Vector3(0, bore_y, -0.2495), 0.0125, 0.0125, 0.0012, BORE, 12)
	for z: float in [-0.035, -0.14, -0.215]:
		cz(k.m(), Vector3(0, bore_y, z), 0.0192, 0.0192, 0.007, BRASS_DARK, 16)
	# The spring housing along the top, clamped to the barrel; a ladder sight on it.
	cz(k.m(), Vector3(0, 0.0505, -0.08), 0.0082, 0.0082, 0.15, BRASS, 12)
	cz(k.m(), Vector3(0, 0.0505, -0.157), 0.0095, 0.0082, 0.006, BRASS_LIGHT, 12)
	for z: float in [-0.03, -0.13]:
		box(k.m(), Vector3(0, 0.04, z), Vector3(0.006, 0.014, 0.008), IRON_DARK)
	box(k.m(), Vector3(0, 0.063, -0.01), Vector3(0.012, 0.008, 0.006), IRON_DARK)
	box(k.m(), Vector3(0, 0.0605, -0.15), Vector3(0.0025, 0.007, 0.008), IRON_DARK)
	# Spool brackets under the barrel, and the line running from the spool up to the muzzle.
	for side: float in [-1.0, 1.0]:
		box(k.m(), Vector3(side * 0.02, -0.006, -0.088), Vector3(0.004, 0.044, 0.03), BRASS_DARK)
		screw(k.m(), Vector3(side * 0.022, -0.026, -0.088), side, IRON)
	WeaponBuilder.rod(k.x(), Vector3(0, -0.006, -0.1), Vector3(0, bore_y - 0.014, -0.25), 0.0017, 0.0017, 5, ROPE)
	# Hammer, trigger and guard, walnut grip (the revolver's hand fits it).
	box(k.m(), Vector3(0, 0.046, 0.05), Vector3(0.011, 0.03, 0.014), IRON_DARK, Basis(Vector3.RIGHT, -0.35))
	box(k.m(), Vector3(0, 0.063, 0.063), Vector3(0.016, 0.006, 0.02), STEEL, Basis(Vector3.RIGHT, -0.9))
	trigger_and_guard(k, Vector3(0, -0.017, 0.022), 0.024, BRASS)
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.scroll(k.m(), Vector3(side * 0.0152, 0.012, 0.02), Vector3(side, 0, 0), 0.03, BRASS_DARK)
	pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.098, 0.088), WALNUT, BRASS)
	# --- the spool (turns about X)
	var c: Vector3 = PIVOTS["harpoon_pistol_reel"]
	for side: float in [-1.0, 1.0]:
		cx(reel.m(), c + Vector3(side * 0.0155, 0, 0), 0.026, 0.003, BRASS, 18)
	cx(reel.m(), c, 0.0095, 0.03, IRON_DARK, 10)
	cx(reel.x(), c, 0.0205, 0.028, ROPE, 18)
	for i in 4:
		cx(reel.x(), c + Vector3(-0.0105 + i * 0.007, 0, 0), 0.0212, 0.0018, ROPE.darkened(0.25), 18)
	WeaponBuilder.rod(reel.m(), c + Vector3(0.018, 0, 0), c + Vector3(0.018, -0.024, -0.006), 0.0032, 0.0032, 6, IRON)
	cx(reel.w(), c + Vector3(0.026, -0.024, -0.006), 0.005, 0.014, WALNUT_DARK, 10)
	# --- the dart, nose out of the muzzle
	var tip := Vector3(0, bore_y, -0.33)
	WeaponBuilder.rod(dart.m(), Vector3(0, bore_y, -0.12), tip + Vector3(0, 0, 0.012), 0.0042, 0.0042, 8, STEEL)
	cz(dart.m(), tip + Vector3(0, 0, -0.012), 0.0, 0.0115, 0.04, STEEL.lightened(0.15), 12)
	cz(dart.m(), tip + Vector3(0, 0, 0.011), 0.0115, 0.006, 0.008, IRON, 12)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var out := Vector3(cos(a), sin(a), 0.0)
		WeaponBuilder.rod(dart.m(), tip + out * 0.006 + Vector3(0, 0, 0.004), tip + out * 0.021 + Vector3(0, 0, 0.03), 0.0034, 0.0008, 6, STEEL)
	hoop(dart.m(), Vector3(0, bore_y, -0.258), Vector3(0, 0, 1), 0.0062, 0.0015, BRASS, 12)
	return {"body": k.commit(), "reel": reel.commit(), "dart": dart.commit()}


# ------------------------------------------------------------------ signal flare gun

## A fat-bored bronze flare pistol: a short wide barrel with a red signal band
## that drops open on a hinge, a big spur hammer and a lanyard ring.
static func _flare() -> Dictionary:
	var k := Kit.new()
	var b := Kit.new()
	var bore_y := 0.026
	# --- barrel (drops open)
	cz(b.m(), Vector3(0, bore_y, -0.1), 0.0218, 0.0245, 0.158, BRASS, 20)
	cz(b.m(), Vector3(0, bore_y, -0.1825), 0.0262, 0.0228, 0.01, BRASS_LIGHT, 20)
	cz(b.m(), Vector3(0, bore_y, -0.1879), 0.0172, 0.0172, 0.0012, BORE, 16)
	cz(b.x(), Vector3(0, bore_y, -0.055), 0.0248, 0.0248, 0.014, SIGNAL_RED, 20)
	for z: float in [-0.044, -0.066]:
		cz(b.m(), Vector3(0, bore_y, z), 0.025, 0.025, 0.0025, BRASS_DARK, 20)
	box(b.m(), Vector3(0, 0.003, -0.03), Vector3(0.016, 0.016, 0.022), BRASS_DARK)
	box(b.m(), Vector3(0, 0.051, -0.026), Vector3(0.012, 0.006, 0.014), BRASS_DARK)
	box(b.m(), Vector3(0, 0.0495, -0.17), Vector3(0.004, 0.006, 0.012), BRASS_DARK)
	# The flare cartridge's rim, seen when it's broken open.
	cz(b.m(), Vector3(0, bore_y, -0.0205), 0.0185, 0.0185, 0.003, BRASS_LIGHT, 16)
	cz(b.x(), Vector3(0, bore_y, -0.0185), 0.008, 0.008, 0.0012, SIGNAL_RED, 10)
	# --- frame: a heavy bronze casting with a round standing breech.
	box(k.m(), Vector3(0, 0.012, 0.014), Vector3(0.034, 0.054, 0.056), BRASS_DARK)
	cz(k.m(), Vector3(0, bore_y, -0.002), 0.0255, 0.0255, 0.032, BRASS_DARK, 20)
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.scroll(k.m(), Vector3(side * 0.0172, 0.01, 0.016), Vector3(side, 0, 0), 0.032, BRASS_LIGHT)
		screw(k.m(), Vector3(side * 0.0171, 0.03, 0.03), side, IRON)
	# Barrel latch on the left, big spur hammer.
	box(k.m(), Vector3(-0.018, 0.04, 0.0), Vector3(0.004, 0.008, 0.026), IRON_DARK)
	box(k.m(), Vector3(0, 0.05, 0.044), Vector3(0.012, 0.032, 0.016), IRON_DARK, Basis(Vector3.RIGHT, -0.4))
	box(k.m(), Vector3(0, 0.07, 0.062), Vector3(0.022, 0.007, 0.024), IRON, Basis(Vector3.RIGHT, -0.95))
	# Big trigger guard (room for a glove) and the grip, with a lanyard ring.
	trigger_and_guard(k, Vector3(0, -0.019, 0.02), 0.03, BRASS)
	pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.1, 0.09), WALNUT_DARK, BRASS_DARK, 1.12)
	hoop(k.m(), Vector3(0, -0.118, 0.094), Vector3(1, 0, 0), 0.009, 0.0022, BRASS, 14)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ salt shotgun

## A pump gun: blued receiver with a white enamel salt-crystal medallion, a long
## barrel over a magazine tube, a grooved walnut pump and a red rubber butt pad.
static func _salt() -> Dictionary:
	var k := Kit.new()
	var p := Kit.new()
	# Receiver.
	box(k.m(), Vector3(0, 0.008, -0.004), Vector3(0.032, 0.052, 0.15), BLUED)
	cz(k.m(), Vector3(0, 0.028, -0.004), 0.0158, 0.0158, 0.15, BLUED, 16)
	box(k.x(), Vector3(0.0163, 0.02, -0.02), Vector3(0.0012, 0.016, 0.044), BORE)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(k.w(), Transform3D(Basis(), Vector3(side * 0.0163, 0.004, 0.025)), Vector3(0.0015, 0.013, 0.02), 4, 12, Color("#F4F1EA"))
		# Rock-salt crystals on the medallion, picked out in blue.
		for c: Vector3 in [Vector3(0, 0.004, 0.02), Vector3(0, -0.003, 0.03), Vector3(0, 0.009, 0.031)]:
			box(k.w(), Vector3(side * 0.0174, 0, 0) + c, Vector3(0.0012, 0.0048, 0.0048), SALT_BLUE, Basis(Vector3.RIGHT, 0.78))
		screw(k.m(), Vector3(side * 0.0162, -0.01, -0.05), side)
		screw(k.m(), Vector3(side * 0.0162, -0.01, 0.06), side)
	# Barrel and magazine tube.
	cz(k.m(), Vector3(0, 0.02, -0.36), 0.0122, 0.0128, 0.56, BLUED, 16)
	cz(k.m(), Vector3(0, 0.02, -0.641), 0.0132, 0.0132, 0.004, STEEL, 16)
	cz(k.m(), Vector3(0, 0.02, -0.6432), 0.0085, 0.0085, 0.001, BORE, 12)
	ball(k.m(), Vector3(0, 0.0345, -0.628), Vector3.ONE * 0.0028, BRASS_LIGHT, 4, 8)
	box(k.m(), Vector3(0, 0.034, -0.36), Vector3(0.006, 0.003, 0.52), BLUED.lightened(0.12))
	cz(k.m(), Vector3(0, -0.012, -0.3), 0.0102, 0.0102, 0.44, BLUED.darkened(0.15), 14)
	cz(k.m(), Vector3(0, -0.012, -0.522), 0.0108, 0.0108, 0.006, STEEL, 14)
	box(k.m(), Vector3(0, 0.004, -0.53), Vector3(0.026, 0.044, 0.012), BLUED.darkened(0.1))
	# Trigger guard and loading port underneath.
	trigger_and_guard(k, Vector3(0, -0.028, 0.05), 0.022, BLUED.darkened(0.2))
	box(k.x(), Vector3(0, -0.0175, -0.03), Vector3(0.014, 0.0012, 0.05), BORE)
	# Stock with a pistol-grip wrist and a red rubber pad.
	var stock := [[Vector3(0, 0.004, 0.07), 0.025, 0.016], [Vector3(0, -0.012, 0.11), 0.021, 0.0152],
		[Vector3(0, -0.03, 0.2), 0.034, 0.018], [Vector3(0, -0.048, 0.32), 0.049, 0.0198], [Vector3(0, -0.056, 0.4), 0.057, 0.021],
		[Vector3(0, -0.058, 0.415), 0.058, 0.0212]]
	WeaponBuilder.loft(k.w(), stock, WALNUT, 16)
	WeaponBuilder.buttplate(k.x(), stock, Color("#7A2620"))
	# --- the pump: a grooved walnut forend on two action bars
	var forend := [[Vector3(0, -0.015, -0.13), 0.017, 0.0165], [Vector3(0, -0.017, -0.15), 0.0205, 0.019],
		[Vector3(0, -0.017, -0.255), 0.0205, 0.019], [Vector3(0, -0.015, -0.275), 0.016, 0.016]]
	WeaponBuilder.loft(p.w(), forend, WALNUT_LIGHT, 16)
	for i in 7:
		var z := -0.16 - i * 0.014
		box(p.w(), Vector3(0, -0.0372, z), Vector3(0.03, 0.0022, 0.0035), WALNUT_DARK)
		for side: float in [-1.0, 1.0]:
			box(p.w(), Vector3(side * 0.0192, -0.02, z), Vector3(0.0022, 0.022, 0.0035), WALNUT_DARK)
	for side: float in [-1.0, 1.0]:
		WeaponBuilder.rod(p.m(), Vector3(side * 0.011, -0.004, -0.14), Vector3(side * 0.011, -0.004, -0.07), 0.0022, 0.0022, 6, STEEL)
	return {"body": k.commit(), "pump": p.commit()}


# ------------------------------------------------------------------ punt gun

## A punt gun's breech end with the barrel sawn off short: a massive iron tube
## with brass reinforcing rings and a raw filed muzzle, a forward handle, a
## riveted breech block with a side hammer, and a stubby leather-wrapped stock.
static func _punt() -> Dictionary:
	var k := Kit.new()
	var b := Kit.new()
	var bore_y := 0.03
	# --- barrel (drops open about the hinge under the breech)
	cz(b.m(), Vector3(0, bore_y, -0.355), 0.046, 0.055, 0.54, IRON, 22)
	for r: Array in [[-0.112, 0.061, 0.03, BRASS], [-0.24, 0.0575, 0.02, BRASS_DARK], [-0.42, 0.0525, 0.016, IRON_DARK], [-0.6, 0.05, 0.026, BRASS]]:
		cz(b.m(), Vector3(0, bore_y, float(r[0])), float(r[1]), float(r[1]), float(r[2]), r[3], 22)
		for i in 8:
			var a := TAU * float(i) / 8.0
			ball(b.m(), Vector3(cos(a) * float(r[1]), bore_y + sin(a) * float(r[1]), float(r[0])), Vector3.ONE * 0.0034, BRASS_LIGHT, 3, 6)
	# The sawn muzzle: bright filed metal, a dark gaping bore, a few burrs.
	cz(b.m(), Vector3(0, bore_y, -0.627), 0.0462, 0.0462, 0.004, IRON.lightened(0.35), 22)
	cz(b.m(), Vector3(0, bore_y, -0.6295), 0.033, 0.033, 0.0015, BORE, 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 7:
		var a := rng.randf() * TAU
		box(b.m(), Vector3(cos(a) * 0.043, bore_y + sin(a) * 0.043, -0.628), Vector3(0.006, 0.004, 0.004), IRON.lightened(0.2), Basis(Vector3.BACK, a))
	# Rope wrap near the muzzle, a rib and bead on top.
	for i in 5:
		cz(b.x(), Vector3(0, bore_y, -0.53 - i * 0.009), 0.0485, 0.0485, 0.007, ROPE.darkened(0.06 * (i % 2)), 20)
	box(b.m(), Vector3(0, bore_y + 0.052, -0.33), Vector3(0.01, 0.006, 0.46), IRON_DARK)
	ball(b.m(), Vector3(0, bore_y + 0.058, -0.59), Vector3.ONE * 0.005, BRASS_LIGHT, 4, 8)
	# Hinge lug, and the forward handle on a brass strap.
	box(b.m(), Vector3(0, -0.026, -0.105), Vector3(0.04, 0.03, 0.05), IRON_DARK)
	cz(b.m(), Vector3(0, bore_y, -0.33), 0.0575, 0.0575, 0.024, BRASS, 22)
	box(b.m(), Vector3(0, -0.035, -0.33), Vector3(0.016, 0.022, 0.024), BRASS)
	WeaponBuilder.rod(b.w(), Vector3(0, -0.04, -0.33), Vector3(0, -0.125, -0.312), 0.0165, 0.0175, 12, WALNUT)
	ball(b.w(), Vector3(0, -0.128, -0.311), Vector3(0.019, 0.01, 0.019), WALNUT_DARK, 4, 12)
	# --- breech block: riveted iron, a side lever and a big side hammer.
	box(k.m(), Vector3(0, 0.022, -0.035), Vector3(0.1, 0.1, 0.092), IRON_DARK)
	box(k.m(), Vector3(0, 0.075, -0.035), Vector3(0.07, 0.008, 0.08), IRON)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				ball(k.m(), Vector3(sx * 0.0505, 0.022 + sy * 0.038, -0.035 + sz * 0.034), Vector3.ONE * 0.0045, BRASS, 3, 6)
		WeaponBuilder.scroll(k.m(), Vector3(sx * 0.0505, 0.022, -0.035), Vector3(sx, 0, 0), 0.05, BRASS)
	WeaponBuilder.rod(k.m(), Vector3(0.052, -0.005, -0.06), Vector3(0.056, 0.05, -0.0), 0.005, 0.004, 8, BRASS_DARK)
	box(k.m(), Vector3(0.056, 0.066, 0.005), Vector3(0.012, 0.03, 0.018), IRON, Basis(Vector3.RIGHT, -0.5))
	box(k.m(), Vector3(0.056, 0.082, 0.022), Vector3(0.016, 0.008, 0.026), IRON_DARK, Basis(Vector3.RIGHT, -1.0))
	trigger_and_guard(k, Vector3(0, -0.04, 0.012), 0.026, IRON)
	# Stubby stock: a pistol grip wrapped in leather, an iron butt cap.
	var stock := [[Vector3(0, 0.02, 0.008), 0.046, 0.042], [Vector3(0, 0.0, 0.05), 0.032, 0.03],
		[Vector3(0, -0.035, 0.1), 0.031, 0.025], [Vector3(0, -0.058, 0.17), 0.046, 0.029], [Vector3(0, -0.068, 0.235), 0.056, 0.031],
		[Vector3(0, -0.07, 0.25), 0.057, 0.0315]]
	WeaponBuilder.loft(k.w(), stock, WALNUT_DARK, 16)
	for i in 6:
		var t := float(i) / 5.0
		var c := Vector3(0, 0.0, 0.05).lerp(Vector3(0, -0.04, 0.11), t)
		MeshKit.add_cylinder(k.x(), Transform3D(MeshKit.basis_from_y(Vector3(0, -0.6, 0.8)), c), 0.0335, 0.0335, 0.009, 16, LEATHER.darkened(0.08 * (i % 2)))
	WeaponBuilder.buttplate(k.m(), stock, IRON)
	return {"body": k.commit(), "barrels": b.commit()}


# ------------------------------------------------------------------ bee smoker

## A beekeeper's smoker: a tin fire can with a soot-blackened foot, a copper
## heat guard, a domed lid with a bent spout (embers glowing in its mouth), and
## leather bellows between two wooden boards behind it.
static func _smoker() -> Dictionary:
	var k := Kit.new()
	var bel := Kit.new()
	var ple := Kit.new()
	var can := Vector3(0, 0.0, -0.09)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), can), 0.05, 0.05, 0.16, 22, TIN)
	MeshKit.add_cylinder(k.x(), Transform3D(Basis(), can + Vector3(0, -0.066, 0)), 0.0505, 0.0505, 0.03, 22, SOOT)
	for y: float in [-0.08, -0.03, 0.035, 0.076]:
		MeshKit.add_cylinder(k.m(), Transform3D(Basis(), can + Vector3(0, y, 0)), 0.0518, 0.0518, 0.006, 22, TIN.darkened(0.18))
	# Riveted seam down the side.
	for i in 6:
		ball(k.m(), can + Vector3(-0.0505, -0.06 + i * 0.024, 0.0), Vector3.ONE * 0.0028, TIN.lightened(0.2), 3, 6)
	# Copper heat guard: bars round the front half, two hoops.
	for i in 9:
		var a := lerpf(0.15 * PI, 0.85 * PI, float(i) / 8.0)
		var p := Vector3(cos(a), 0, -sin(a)) * 0.061
		WeaponBuilder.rod(k.m(), can + p + Vector3(0, -0.06, 0), can + p + Vector3(0, 0.062, 0), 0.0022, 0.0022, 6, COPPER)
	for y: float in [-0.058, 0.06]:
		var pts: Array = []
		var radii: Array = []
		for i in 13:
			var a := lerpf(0.13 * PI, 0.87 * PI, float(i) / 12.0)
			pts.append(can + Vector3(cos(a) * 0.061, y, -sin(a) * 0.061))
			radii.append(0.0026)
		MeshKit.tube(k.m(), pts, radii, 6, COPPER.darkened(0.1))
	# Domed lid and the bent spout.
	MeshKit.lathe(k.m(), Transform3D(Basis(), can + Vector3(0, 0.08, 0)), [Vector2(0.0525, 0.0), Vector2(0.051, 0.012),
			Vector2(0.042, 0.036), Vector2(0.026, 0.054), Vector2(0.019, 0.06)], 22, TIN.lightened(0.06))
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), can + Vector3(0, 0.08, 0)), 0.054, 0.054, 0.006, 22, TIN.darkened(0.2))
	var spout := [can + Vector3(0, 0.136, 0.0), can + Vector3(0, 0.16, -0.012), can + Vector3(0, 0.178, -0.045), can + Vector3(0, 0.186, -0.085), can + Vector3(0, 0.186, -0.1)]
	MeshKit.tube(k.m(), spout, [0.021, 0.019, 0.016, 0.0135, 0.0135], 16, TIN)
	cz(k.m(), can + Vector3(0, 0.186, -0.101), 0.0148, 0.0148, 0.004, TIN.darkened(0.22), 16)
	cz(k.x(), can + Vector3(0, 0.186, -0.1032), 0.0105, 0.0105, 0.0012, SOOT, 12)
	ball(k.g(), can + Vector3(0, 0.186, -0.098), Vector3(0.0085, 0.0085, 0.004), Color("#FF8A2A"), 3, 8)
	ball(k.g(), can + Vector3(0.003, 0.188, -0.0985), Vector3(0.004, 0.004, 0.002), Color("#FFE07A"), 3, 6)
	# Lid hinge and latch at the back.
	cx(k.m(), can + Vector3(0, 0.084, 0.052), 0.004, 0.02, TIN.darkened(0.3), 8)
	# Front bellows board (fixed to the can by a short air pipe), hinge at the foot.
	box(k.w(), Vector3(0, -0.003, -0.022), Vector3(0.076, 0.152, 0.009), WALNUT_LIGHT)
	cz(k.m(), Vector3(0, -0.06, -0.033), 0.008, 0.008, 0.016, TIN.darkened(0.15), 10)
	cx(k.m(), Vector3(0, -0.079, -0.014), 0.0045, 0.08, IRON_DARK, 8)
	for side: float in [-1.0, 1.0]:
		ball(k.m(), Vector3(side * 0.03, 0.06, -0.0172), Vector3(0.004, 0.004, 0.0015), BRASS, 3, 6)
		ball(k.m(), Vector3(side * 0.03, -0.06, -0.0172), Vector3(0.004, 0.004, 0.0015), BRASS, 3, 6)
	# --- back board (swings on the foot hinge): a brass leaf spring and a thumb plate
	var hinge: Vector3 = PIVOTS["bee_smoker_bellows"]
	box(bel.w(), hinge + Vector3(0, 0.078, 0.008), Vector3(0.076, 0.152, 0.009), WALNUT_LIGHT)
	box(bel.m(), hinge + Vector3(0, 0.13, 0.0135), Vector3(0.05, 0.03, 0.002), BRASS)
	WeaponBuilder.scroll(bel.m(), hinge + Vector3(0, 0.07, 0.0136), Vector3(0, 0, 1), 0.04, BRASS_DARK)
	WeaponBuilder.bent(bel.m(), [hinge + Vector3(0, 0.12, 0.002), hinge + Vector3(0, 0.1, -0.012), hinge + Vector3(0, 0.12, -0.028)], 0.0025, BRASS)
	# --- the leather between (fans with the board)
	for i in 3:
		box(ple.x(), hinge + Vector3(0, 0.074, 0.0), Vector3(0.08, 0.146, 0.003), LEATHER.darkened(0.08 * i), Basis(Vector3.RIGHT, -BELLOWS_OPEN * 0.6 * float(i) / 3.0))
	return {"body": k.commit(), "bellows": bel.commit(), "pleats": ple.commit()}


# ------------------------------------------------------------------ telescope rifle

## A bolt-action target rifle: octagonal blued barrel, walnut stock with a
## cheek piece and an ebony forend tip, and a long brass spyglass on two
## rings (draw tubes, a leather wrap, a sunshade and a glinting lens).
static func _telescope() -> Dictionary:
	var k := Kit.new()
	var bo := Kit.new()
	# Receiver and barrel.
	cz(k.m(), Vector3(0, 0.017, -0.01), 0.0168, 0.0168, 0.16, BLUED, 18)
	box(k.x(), Vector3(0.0158, 0.022, 0.005), Vector3(0.0015, 0.014, 0.05), BORE)
	cz(k.m(), Vector3(0, 0.017, -0.4), 0.0108, 0.0138, 0.62, BLUED, 8)
	cz(k.m(), Vector3(0, 0.017, -0.7115), 0.0112, 0.0112, 0.003, STEEL, 12)
	cz(k.m(), Vector3(0, 0.017, -0.7133), 0.0048, 0.0048, 0.001, BORE, 10)
	box(k.m(), Vector3(0, 0.031, -0.695), Vector3(0.008, 0.01, 0.014), BLUED.darkened(0.2))
	# Stock: wrist, cheek piece, brass butt plate; forend with an ebony tip.
	var stock := [[Vector3(0, 0.002, 0.07), 0.025, 0.017], [Vector3(0, -0.02, 0.12), 0.021, 0.0158],
		[Vector3(0, -0.038, 0.2), 0.035, 0.0185], [Vector3(0, -0.05, 0.33), 0.049, 0.0205], [Vector3(0, -0.057, 0.42), 0.057, 0.0215],
		[Vector3(0, -0.058, 0.435), 0.058, 0.0218]]
	WeaponBuilder.loft(k.w(), stock, WALNUT, 16)
	WeaponBuilder.buttplate(k.m(), stock, BRASS_DARK)
	MeshKit.add_ellipsoid(k.w(), Transform3D(Basis(), Vector3(-0.0175, -0.02, 0.3)), Vector3(0.007, 0.022, 0.065), 5, 12, WALNUT_LIGHT)
	var forend := [[Vector3(0, -0.006, -0.09), 0.021, 0.0172], [Vector3(0, -0.009, -0.2), 0.02, 0.0165],
		[Vector3(0, -0.006, -0.42), 0.016, 0.0148], [Vector3(0, -0.003, -0.445), 0.0135, 0.013]]
	WeaponBuilder.loft(k.w(), forend, WALNUT, 16)
	cz(k.w(), Vector3(0, -0.003, -0.455), 0.011, 0.0132, 0.02, Color("#1E1714"), 14)
	# Chequering panels on the wrist (fine dark diamonds).
	for side: float in [-1.0, 1.0]:
		for i in 4:
			for j in 3:
				box(k.w(), Vector3(side * 0.0152, -0.014 - j * 0.008 - i * 0.004, 0.105 + i * 0.012), Vector3(0.001, 0.005, 0.005), WALNUT_DARK, Basis(Vector3.RIGHT, 0.78))
	trigger_and_guard(k, Vector3(0, -0.026, 0.05), 0.023, BLUED.darkened(0.25))
	box(k.m(), Vector3(0, -0.0215, -0.02), Vector3(0.018, 0.004, 0.07), BLUED.darkened(0.25))
	# Sling swivels.
	hoop(k.m(), Vector3(0, -0.032, -0.33), Vector3(1, 0, 0), 0.008, 0.0016, STEEL, 10)
	hoop(k.m(), Vector3(0, -0.09, 0.36), Vector3(1, 0, 0), 0.008, 0.0016, STEEL, 10)
	# --- the spyglass: two mounts and rings, then the tube from eyepiece to sunshade
	var sy := 0.068
	for z: float in [0.035, -0.175]:
		box(k.m(), Vector3(0, 0.04, z), Vector3(0.012, 0.026, 0.016), BLUED)
		cz(k.m(), Vector3(0, sy, z), 0.0178, 0.0178, 0.012, BRASS_DARK, 18)
		screw(k.m(), Vector3(0.018, sy, z), 1.0, STEEL)
	cz(k.x(), Vector3(0, sy, 0.174), 0.0152, 0.0152, 0.008, Color("#2A1E16"), 18)
	cz(k.m(), Vector3(0, sy, 0.15), 0.0132, 0.0148, 0.04, BRASS, 18)
	cz(k.m(), Vector3(0, sy, 0.1), 0.0124, 0.0124, 0.06, BRASS_LIGHT, 18)
	cz(k.m(), Vector3(0, sy, 0.068), 0.0148, 0.0148, 0.006, BRASS_DARK, 18)
	cz(k.m(), Vector3(0, sy, -0.07), 0.0146, 0.0146, 0.27, BRASS, 18)
	cz(k.x(), Vector3(0, sy, -0.072), 0.0156, 0.0156, 0.072, LEATHER, 18)
	for z: float in [-0.04, -0.104]:
		cz(k.x(), Vector3(0, sy, z), 0.0158, 0.0158, 0.003, LEATHER.lightened(0.25), 18)
	for i in 6:
		cz(k.m(), Vector3(0, sy, 0.02 - i * 0.003), 0.0152, 0.0152, 0.0016, BRASS_DARK, 18)
	cz(k.m(), Vector3(0, sy, -0.234), 0.0212, 0.0146, 0.058, BRASS, 18)
	cz(k.m(), Vector3(0, sy, -0.284), 0.0218, 0.0218, 0.042, BRASS_DARK, 18)
	cz(k.m(), Vector3(0, sy, -0.3052), 0.0226, 0.0226, 0.0016, BRASS_LIGHT, 18)
	cz(k.g(), Vector3(0, sy, -0.2635), 0.0182, 0.0182, 0.001, Color("#8FC8E8"), 18)
	ball(k.g(), Vector3(0.006, sy + 0.006, -0.2645), Vector3(0.004, 0.003, 0.0008), Color("#F4FBFF"), 3, 8)
	cz(k.m(), Vector3(0, sy, 0.1702), 0.0102, 0.0102, 0.001, Color("#1A2630"), 14)
	# --- the bolt: body, shroud and a turned-down handle with a pear knob
	var piv: Vector3 = PIVOTS["telescope_rifle_bolt"]
	cz(bo.m(), piv + Vector3(0, 0, 0.0), 0.0092, 0.0092, 0.08, STEEL, 14)
	cz(bo.m(), piv + Vector3(0, 0, 0.046), 0.0112, 0.0102, 0.014, BLUED, 14)
	WeaponBuilder.rod(bo.m(), piv + Vector3(0.007, 0, 0.022), piv + Vector3(0.04, -0.024, 0.03), 0.0034, 0.0034, 8, STEEL)
	MeshKit.add_ellipsoid(bo.m(), Transform3D(Basis(), piv + Vector3(0.043, -0.027, 0.031)), Vector3(0.0078, 0.0086, 0.0078), 5, 10, STEEL.lightened(0.1))
	return {"body": k.commit(), "bolt": bo.commit()}


# ------------------------------------------------------------------ rounds in the hand

## What the support hand carries to the gun on a reload (null: nothing).
static func held_round(id: StringName) -> ArrayMesh:
	var k := Kit.new()
	match id:
		&"flare_gun":
			cz(k.x(), Vector3(0, 0, -0.008), 0.0172, 0.0172, 0.05, SIGNAL_RED, 14)
			cz(k.m(), Vector3(0, 0, 0.021), 0.0185, 0.0185, 0.01, BRASS, 14)
			cz(k.x(), Vector3(0, 0, -0.0335), 0.012, 0.012, 0.001, Color("#F2E6C8"), 12)
		&"salt_shotgun":
			cz(k.x(), Vector3(0, 0, -0.012), 0.0115, 0.0115, 0.05, SALT_BLUE, 12)
			cz(k.m(), Vector3(0, 0, 0.018), 0.0125, 0.0125, 0.014, BRASS, 12)
			cz(k.x(), Vector3(0, 0, -0.0375), 0.0105, 0.0105, 0.001, Color("#F4F1EA"), 10)
		&"punt_gun":
			cz(k.m(), Vector3(0, 0, -0.01), 0.031, 0.031, 0.11, BRASS, 18)
			cz(k.m(), Vector3(0, 0, 0.05), 0.034, 0.034, 0.01, BRASS_DARK, 18)
			cz(k.x(), Vector3(0, 0, -0.0655), 0.029, 0.029, 0.001, Color("#6B4426"), 14)
		&"harpoon_pistol":
			WeaponBuilder.rod(k.m(), Vector3(0, 0, 0.06), Vector3(0, 0, -0.08), 0.0042, 0.0042, 8, STEEL)
			cz(k.m(), Vector3(0, 0, -0.1), 0.0, 0.011, 0.04, STEEL.lightened(0.15), 12)
		&"telescope_rifle":
			MeshKit.add_cylinder(k.m(), Transform3D(Z, Vector3(0, 0, 0)), 0.0055, 0.0065, 0.045, 10, BRASS)
			MeshKit.add_cylinder(k.m(), Transform3D(Z, Vector3(0, 0, -0.03)), 0.0, 0.0055, 0.018, 10, Color("#B8743A"))
		_:
			MeshKit.add_cylinder(k.m(), Transform3D(Z, Vector3(0, 0, 0)), 0.0065, 0.0065, 0.03, 8, BRASS)
			MeshKit.add_cylinder(k.m(), Transform3D(Z, Vector3(0, 0, -0.02)), 0.006, 0.003, 0.012, 8, Color("#8A8A90"))
	return k.commit()
