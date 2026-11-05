class_name WaterworksBuilder
extends RefCounted
## Meshes for the homestead waterworks (Waterworks): a water tower in four
## designs (one per cliff, so every yard looks like its own), the generator with
## its circuit-breaker lever, and the pipe and cable runs between them. The well
## is a pump jack the generator drives (WellJackBuilder). Local space: +Z is the
## front (it faces the yard), y = 0 is the ground.
##
## The four designs:
##   timber   a stave barrel on four timber legs under a round shingled cone
##   steel    a riveted "tin man" tank (domed top, bowl bottom, painted name band)
##            on a steel lattice with a railed balcony
##   adobe    a square, battered adobe tower carrying a wooden tank under a
##            terracotta hip roof on posts
##   trestle  a railroad tank lying on two timber bents with a swing spout and a
##            catwalk

## Where the tap (spigot) sits on every tower, and how far out it reaches.
const TAP_POS := Vector3(0.0, 1.15, 2.05)

const STEEL := Color("#8E4A36") # oxide-red paint
const GALV := Color("#A9B2B5") # galvanised sheet
const ADOBE := Color("#C98E5C")
const STONE := Color("#9C8F80")
const IRON := Color("#3E3B3A")
const ENGINE := Color("#4F7A4A") # old green engine paint
const WATER := Color("#3E8FB8")
const BRASS := Color("#B8913A")
const PLASTER := Color("#E6CFA8")
const TERRACOTTA := Color("#B5532E")
const TILE_BLUE := Color("#2F5E9E")
const CONCRETE := Color("#B4AA9A")
const ROPE := Color("#C9A86A")
const SHINGLE := Color("#7C5236")


## A water tower in one of the designs. Returns {"mesh", "shapes": [[Shape3D, Transform3D], ...],
## "tank_bottom", "tank_top", "glass_z" (front of the tank, for the sight glass)}.
static func tower(style: StringName, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var shapes: Array = []
	var dims: Array
	match style:
		&"steel":
			dims = _tower_steel(st, rng, shapes)
		&"adobe":
			dims = _tower_adobe(st, rng, shapes)
		&"trestle":
			dims = _tower_trestle(st, rng, shapes)
		_:
			dims = _tower_timber(st, rng, shapes)
	var bottom: float = dims[0]
	var top: float = dims[1]
	var glass_z: float = dims[2]
	var surface_z: float = dims[3] # where the tank's skin is behind the sight glass (top and bottom)
	# Every design: brackets holding the sight glass (WaterTower puts it at x 0.45, glass_z + 0.09).
	for y: float in [bottom + 0.2, top - 0.2]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.45, y, (surface_z + glass_z + 0.1) * 0.5)), Vector3(0.22, 0.05, glass_z + 0.1 - surface_z + 0.04), IRON)
	# A down-pipe from the tank to the tap at the front: out, down and into the tap's backplate.
	var z_out := TAP_POS.z - 0.27
	var y_tap := TAP_POS.y + 0.15
	var pipe := [Vector3(0.0, bottom + 0.1, glass_z - 0.3), Vector3(0.0, bottom - 0.12, z_out - 0.08),
			Vector3(0.0, bottom - 0.3, z_out), Vector3(0.0, y_tap + 0.2, z_out), Vector3(0.0, y_tap, z_out + 0.05)]
	MeshKit.tube(st, pipe, [0.07], 6, IRON)
	# Flanges and a shut-off valve wheel on the down-pipe.
	for y: float in [bottom - 0.45, y_tap + 0.7]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, y, z_out)), 0.11, 0.11, 0.06, 8, IRON.lightened(0.1))
	MeshKit.add_limb(st, Vector3(0, y_tap + 1.0, z_out), Vector3(0, y_tap + 1.0, z_out + 0.16), 0.025, IRON, 4)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y_tap + 1.0, z_out + 0.17)), 0.12, 0.12, 0.03, 10, Palette.TEAM_WEST)
	_ladder(st, Vector3(1.0, 0, 1.45) if style != &"adobe" else Vector3(1.1, 0, 1.75), top - 0.2)
	if style == &"steel" or style == &"timber":
		shapes.append([_cyl(1.6, top - bottom), Transform3D(Basis(), Vector3(0, (bottom + top) * 0.5, 0))])
	elif style == &"adobe":
		shapes.append([_cyl(1.6, top - bottom + 0.4), Transform3D(Basis(), Vector3(0, (bottom + top) * 0.5, 0))])
	return {"mesh": MeshKit.finish(st), "shapes": shapes, "tank_bottom": bottom, "tank_top": top, "glass_z": glass_z}


## Timber: the classic stave barrel on four braced legs under a round shingled cone.
static func _tower_timber(st: SurfaceTool, rng: RandomNumberGenerator, shapes: Array) -> Array:
	var leg_h := 5.0
	var foot := 1.5
	var head := 1.2
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(lx * foot, 0.12, lz * foot)), Vector3(0.45, 0.24, 0.45), STONE, 0.03, rng)
			MeshKit.add_limb(st, Vector3(lx * foot, 0.2, lz * foot), Vector3(lx * head, leg_h, lz * head), 0.15, Palette.WOOD, 6)
	# Girts round the legs and X-braces on every face, two tiers.
	for tier: Array in [[0.9, 2.9], [2.9, 4.8]]:
		var y0: float = tier[0]
		var y1: float = tier[1]
		var r0 := lerpf(foot, head, y0 / leg_h)
		var r1 := lerpf(foot, head, y1 / leg_h)
		for face in 4:
			var b := Basis(Vector3.UP, face * PI * 0.5)
			MeshKit.add_limb(st, b * Vector3(-r0, y0, r0), b * Vector3(r1, y1, r1), 0.06, Palette.WOOD_DARK, 4)
			MeshKit.add_limb(st, b * Vector3(r0, y0, r0), b * Vector3(-r1, y1, r1), 0.06, Palette.WOOD_DARK, 4)
			MeshKit.add_box(st, Transform3D(b, b * Vector3(0, y0, r0 + 0.02) - Vector3.ZERO), Vector3(r0 * 2.0 + 0.2, 0.14, 0.1), Palette.WOOD)
	# Deck: planks with joist ends.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, leg_h - 0.05, 0)), Vector3(3.3, 0.14, 3.3), Palette.WOOD_DARK, 0.02, rng)
	for k in 6:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-1.4 + k * 0.56, leg_h + 0.04, 0)), Vector3(0.5, 0.06, 3.4), Palette.WOOD.darkened(rng.randf() * 0.15), 0.01, rng)
	var bottom := leg_h + 0.1
	var top := bottom + 2.8
	# The barrel: staves (alternating shades), iron hoops.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, (bottom + top) * 0.5, 0)), 1.5, 1.42, top - bottom, 16, Palette.WOOD)
	for i in 16:
		var a := TAU * (float(i) + 0.5) / 16.0
		var r := 1.47
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * r, (bottom + top) * 0.5, sin(a) * r)),
				Vector3(0.045, top - bottom, 0.06), Palette.WOOD_DARK)
	for band_y: float in [0.25, 1.0, 1.8, 2.55]:
		var rr := lerpf(1.5, 1.42, band_y / 2.8) + 0.035
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, bottom + band_y, 0)), rr, rr, 0.1, 16, IRON, false)
	# Round shingled cone with a drip lip, a vent and a finial.
	var roof_y := top + 0.05
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, roof_y, 0)), 1.85, 1.85, 0.1, 16, SHINGLE.darkened(0.2))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, roof_y + 0.95, 0)), 1.85, 0.0, 1.8, 16, SHINGLE)
	# Shingle courses: darker rings stepping up the cone.
	for k in 3:
		var f := 0.2 + k * 0.22
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, roof_y + 0.05 + 1.8 * f, 0)), 1.85 * (1.0 - f) + 0.03, 1.85 * (1.0 - f) - 0.05, 0.1, 16, SHINGLE.darkened(0.18), false)
	MeshKit.add_limb(st, Vector3(0, roof_y + 1.7, 0), Vector3(0, roof_y + 2.2, 0), 0.04, IRON, 5)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, roof_y + 2.25, 0)), Vector3.ONE * 0.1, 3, 8, BRASS)
	shapes.append([_box(Vector3(3.0, leg_h, 3.0)), Transform3D(Basis(), Vector3(0, leg_h * 0.5, 0))])
	return [bottom, top, 1.53, 1.42]


## Steel: a riveted tank with a domed top and a bowl bottom on a steel lattice with a railed balcony.
static func _tower_steel(st: SurfaceTool, _rng: RandomNumberGenerator, shapes: Array) -> Array:
	var leg_h := 5.4
	var foot := 1.55
	var head := 1.05
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(lx * foot, 0.15, lz * foot)), 0.32, 0.26, 0.3, 6, CONCRETE)
			MeshKit.add_limb(st, Vector3(lx * foot, 0.25, lz * foot), Vector3(lx * head, leg_h, lz * head), 0.1, IRON, 6)
	# Struts and tie-rod X's on every face, three tiers.
	var tiers: Array[float] = [0.6, 2.2, 3.8, 5.3]
	for t in 3:
		var y0 := tiers[t]
		var y1 := tiers[t + 1]
		var r0 := lerpf(foot, head, y0 / leg_h)
		var r1 := lerpf(foot, head, y1 / leg_h)
		for face in 4:
			var b := Basis(Vector3.UP, face * PI * 0.5)
			MeshKit.add_limb(st, b * Vector3(-r0, y0, r0), b * Vector3(r1, y1, r1), 0.025, IRON, 4)
			MeshKit.add_limb(st, b * Vector3(r0, y0, r0), b * Vector3(-r1, y1, r1), 0.025, IRON, 4)
			if t > 0:
				MeshKit.add_box(st, Transform3D(b, b * Vector3(0, y0, r0)), Vector3(r0 * 2.0, 0.09, 0.07), IRON.lightened(0.08))
	# Riser pipe up the middle into the bowl.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h * 0.5 - 0.2, 0)), 0.2, 0.2, leg_h - 0.4, 8, STEEL.darkened(0.15))
	# Balcony: a grated ring with a railing.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h + 0.05, 0)), 1.9, 1.9, 0.1, 18, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h - 0.05, 0)), 1.9, 1.5, 0.12, 18, IRON.darkened(0.2), false)
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 1.86, leg_h + 0.45, sin(a) * 1.86)), Vector3(0.05, 0.75, 0.05), IRON)
	_ring(st, leg_h + 0.82, 1.86, 0.035, IRON, 18)
	_ring(st, leg_h + 0.48, 1.86, 0.02, IRON, 18)
	var bottom := leg_h + 0.1
	var top := bottom + 2.6
	var mid := (bottom + top) * 0.5
	# The tank: bowl, shell, painted name band, rivet seams, dome and finial.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, bottom + 0.05, 0)), Vector3(1.45, 0.65, 1.45), 6, 18, STEEL.darkened(0.08))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, mid, 0)), 1.45, 1.45, top - bottom, 18, STEEL)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, mid + 0.25, 0)), 1.47, 1.47, 0.55, 18, PLASTER, false)
	for band_y: float in [0.1, 0.9, 1.9, 2.5]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, bottom + band_y, 0)), 1.48, 1.48, 0.06, 18, STEEL.darkened(0.35), false)
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.17
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 1.465, mid, sin(a) * 1.465)), Vector3(0.03, top - bottom - 0.1, 0.05), STEEL.darkened(0.25))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, top, 0)), Vector3(1.47, 0.75, 1.47), 5, 18, STEEL.lightened(0.06))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, top + 0.02, 0)), 1.5, 1.5, 0.08, 18, STEEL.darkened(0.3), false)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, top + 0.78, 0)), 0.22, 0.16, 0.16, 8, IRON)
	MeshKit.add_limb(st, Vector3(0, top + 0.8, 0), Vector3(0, top + 1.3, 0), 0.04, IRON, 5)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, top + 1.35, 0)), Vector3.ONE * 0.13, 3, 8, Palette.GLOW_YELLOW.darkened(0.2))
	shapes.append([_box(Vector3(3.2, leg_h, 3.2)), Transform3D(Basis(), Vector3(0, leg_h * 0.5, 0))])
	return [bottom, top, 1.49, 1.45]


## Adobe: a square, battered adobe tower (vigas, an arched door) carrying a
## wooden tank under a terracotta hip roof on four posts.
static func _tower_adobe(st: SurfaceTool, rng: RandomNumberGenerator, shapes: Array) -> Array:
	var base_h := 4.4
	var hw0 := 1.72 # half-width at the ground
	var hw1 := 1.45 # and at the top
	var square := Basis(Vector3.UP, PI * 0.25)
	MeshKit.add_cylinder(st, Transform3D(square, Vector3(0, base_h * 0.5, 0)), hw0 * sqrt(2.0), hw1 * sqrt(2.0), base_h, 4, ADOBE)
	# A darker plinth, plaster patches and a lighter coping.
	MeshKit.add_cylinder(st, Transform3D(square, Vector3(0, 0.2, 0)), (hw0 + 0.06) * sqrt(2.0), (hw0 + 0.04) * sqrt(2.0), 0.4, 4, ADOBE.darkened(0.2))
	var tilt := atan2(hw0 - hw1, base_h)
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		for k in 3:
			var y := rng.randf_range(0.8, base_h - 0.6)
			var hw := lerpf(hw0, hw1, y / base_h)
			var x := rng.randf_range(-0.9, 0.9)
			var col := PLASTER.darkened(0.12) if k % 2 == 0 else ADOBE.darkened(0.12)
			MeshKit.add_box(st, Transform3D(b * Basis(Vector3.RIGHT, -tilt), b * Vector3(x, y, hw + 0.015)), Vector3(rng.randf_range(0.3, 0.7), rng.randf_range(0.2, 0.45), 0.04), col, 0.02, rng)
	MeshKit.add_cylinder(st, Transform3D(square, Vector3(0, base_h + 0.08, 0)), (hw1 + 0.15) * sqrt(2.0), (hw1 + 0.15) * sqrt(2.0), 0.22, 4, PLASTER)
	# Vigas poking out under the coping on the two sides.
	for k in 5:
		var z := -1.2 + k * 0.6
		MeshKit.add_limb(st, Vector3(-hw1 - 0.4, base_h - 0.22, z), Vector3(hw1 + 0.4, base_h - 0.22, z), 0.08, Palette.WOOD, 6)
	# An arched wooden door on the west side, a little window on the east.
	var dx := -lerpf(hw0, hw1, 1.0 / base_h) - 0.02
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(dx, 0.95, 0)), Vector3(0.12, 1.7, 0.9), Palette.WOOD_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(dx - 0.01, 1.8, 0)), 0.45, 0.45, 0.12, 10, Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(dx - 0.03, 1.0, 0.22)), Vector3(0.04, 0.08, 0.08), IRON)
	var wx := lerpf(hw0, hw1, 3.2 / base_h) + 0.01
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(wx, 3.2, 0)), Vector3(0.06, 0.55, 0.45), Color("#3A2A22"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(wx + 0.03, 2.9, 0)), Vector3(0.12, 0.07, 0.6), Palette.WOOD)
	# The wooden tank on its deck.
	var bottom := base_h + 0.2
	var top := bottom + 2.3
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, (bottom + top) * 0.5, 0)), 1.55, 1.5, top - bottom, 14, Palette.WOOD.lightened(0.08))
	for band_y: float in [0.3, 1.15, 2.0]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, bottom + band_y, 0)), 1.585, 1.585, 0.1, 14, IRON, false)
	# Four corner posts and a terracotta hip roof with ridge tiles.
	var post := hw1 + 0.02
	for px: float in [-1.0, 1.0]:
		for pz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(px * post, (base_h + 0.2 + top + 0.35) * 0.5, pz * post)), Vector3(0.16, top + 0.35 - base_h - 0.2, 0.16), Palette.WOOD_DARK)
	var eave := top + 0.35
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, eave, 0)), Vector3(post * 2.0 + 0.3, 0.14, post * 2.0 + 0.3), Palette.WOOD)
	var roof_hw := post + 0.55
	MeshKit.add_cylinder(st, Transform3D(square, Vector3(0, eave + 0.7, 0)), roof_hw * sqrt(2.0), 0.0, 1.3, 4, TERRACOTTA)
	for corner in 4:
		var a := PI * 0.25 + corner * PI * 0.5
		MeshKit.add_limb(st, Vector3(cos(a) * roof_hw * sqrt(2.0) * 0.98, eave + 0.05, sin(a) * roof_hw * sqrt(2.0) * 0.98), Vector3(0, eave + 1.33, 0), 0.07, TERRACOTTA.darkened(0.25), 5)
	# Tile courses (a darker line across each roof face).
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		for k in 2:
			var f := 0.33 + k * 0.33
			var hy := eave + 0.05 + 1.3 * f
			var hz := roof_hw * (1.0 - f)
			MeshKit.add_box(st, Transform3D(b * Basis(Vector3.RIGHT, atan2(1.3, roof_hw)), b * Vector3(0, hy, hz + 0.02)), Vector3(hz * 2.0, 0.05, 0.08), TERRACOTTA.darkened(0.18))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, eave + 1.38, 0)), Vector3(0.14, 0.12, 0.14), 3, 8, TERRACOTTA.darkened(0.3))
	shapes.append([_cyl(1.75, base_h), Transform3D(Basis(), Vector3(0, base_h * 0.5, 0))])
	return [bottom, top, 1.58, 1.5]


## Trestle: a railroad tank lying on two braced timber bents, a catwalk on top
## and a swing spout off one end.
static func _tower_trestle(st: SurfaceTool, rng: RandomNumberGenerator, shapes: Array) -> Array:
	var y_c := 5.4
	var r := 1.15
	var cap := y_c - 1.05
	for x: float in [-1.4, 1.4]:
		# Mud sill, splayed posts, cap beam and X-bracing.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.1, 0)), Vector3(0.35, 0.2, 3.4), Palette.WOOD_DARK, 0.02, rng)
		for z: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(x, 0.1, z * 1.5), Vector3(x, cap, z * 0.8), 0.14, Palette.WOOD, 6)
		MeshKit.add_limb(st, Vector3(x, 0.6, -1.4), Vector3(x, cap - 0.4, 0.85), 0.07, Palette.WOOD_DARK, 4)
		MeshKit.add_limb(st, Vector3(x, 0.6, 1.4), Vector3(x, cap - 0.4, -0.85), 0.07, Palette.WOOD_DARK, 4)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 2.4, 0)), Vector3(0.2, 0.16, 2.6), Palette.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, cap, 0)), Vector3(0.4, 0.22, 2.3), Palette.WOOD_DARK)
		# Saddle blocks cradling the tank.
		for z: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, z * 0.55), Vector3(x, cap + 0.25, z * 0.62)), Vector3(0.38, 0.35, 0.5), Palette.WOOD)
	# Stringers and a diagonal between the bents (both sides).
	for z: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 2.4, z * 1.22)), Vector3(3.0, 0.14, 0.12), Palette.WOOD)
		MeshKit.add_limb(st, Vector3(-1.4, 0.7, z * 1.38), Vector3(1.4, 2.35, z * 1.22), 0.06, Palette.WOOD_DARK, 4)
	var along := Basis(Vector3.BACK, PI * 0.5)
	MeshKit.add_cylinder(st, Transform3D(along, Vector3(0, y_c, 0)), r, r, 4.6, 16, Palette.WOOD.lightened(0.05))
	# Staves (lines along the tank), dark heads at the ends, iron hoops.
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -a), Vector3(0, y_c, 0) + Vector3(0, sin(a), cos(a)) * (r - 0.005)), Vector3(4.55, 0.06, 0.04), Palette.WOOD_DARK)
	for ex: float in [-2.31, 2.31]:
		MeshKit.add_cylinder(st, Transform3D(along, Vector3(ex, y_c, 0)), r - 0.06, r - 0.06, 0.06, 16, Palette.WOOD_DARK.darkened(0.15))
	for bx: float in [-2.05, -0.7, 0.7, 2.05]:
		MeshKit.add_cylinder(st, Transform3D(along, Vector3(bx, y_c, 0)), r + 0.04, r + 0.04, 0.12, 16, IRON, false)
	# Catwalk planks along the top with a hatch and a hand rail.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y_c + r + 0.04, 0)), Vector3(4.2, 0.07, 0.6), Palette.WOOD_DARK, 0.01, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.9, y_c + r + 0.12, 0)), Vector3(0.55, 0.1, 0.5), IRON.lightened(0.1))
	for px: float in [-1.9, 0.0, 1.9]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(px, y_c + r + 0.42, -0.28)), Vector3(0.05, 0.75, 0.05), IRON)
	MeshKit.add_limb(st, Vector3(-1.9, y_c + r + 0.78, -0.28), Vector3(1.9, y_c + r + 0.78, -0.28), 0.03, IRON, 4)
	# Swing spout off the east end: an iron elbow, a hinged canvas-and-iron pipe,
	# and its counterweight hanging off a mast.
	MeshKit.add_cylinder(st, Transform3D(along, Vector3(2.45, y_c - 0.6, 0)), 0.22, 0.22, 0.3, 10, IRON)
	MeshKit.tube(st, [Vector3(2.55, y_c - 0.6, 0), Vector3(3.0, y_c - 0.9, 0), Vector3(3.4, y_c - 1.5, 0)], [0.18, 0.16, 0.15], 8, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(3.4, y_c - 1.55, 0)), 0.17, 0.2, 0.12, 8, IRON.lightened(0.1))
	MeshKit.add_limb(st, Vector3(2.35, y_c + 0.2, 0), Vector3(2.35, y_c + 1.6, 0), 0.05, IRON, 5)
	MeshKit.add_limb(st, Vector3(2.35, y_c + 1.6, 0), Vector3(3.25, y_c - 1.45, 0), 0.015, IRON, 4)
	MeshKit.add_limb(st, Vector3(2.35, y_c + 1.6, 0), Vector3(1.95, y_c + 0.8, 0.0), 0.015, IRON, 4)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(1.95, y_c + 0.7, 0)), Vector3(0.18, 0.25, 0.18), IRON)
	shapes.append([_box(Vector3(3.3, y_c - 1.0, 3.2)), Transform3D(Basis(), Vector3(0, (y_c - 1.0) * 0.5, 0))])
	shapes.append([_box(Vector3(4.6, 2.3, 2.3)), Transform3D(Basis(), Vector3(0, y_c, 0))])
	# The glass sits in front of the tank's belly; its brackets reach back to the
	# curve (about 0.8 out from the axis at the top and bottom of the glass).
	return [y_c - r, y_c + r, 1.17, 0.75]


## The spigot at the tower's front: a brass tap on a bolted backplate.
static func tap() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, -0.25)), Vector3(0.22, 0.34, 0.08), Palette.WOOD_DARK)
	for by: float in [0.02, 0.28]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, by, -0.2)), Vector3.ONE * 0.025, 2, 6, IRON)
	MeshKit.tube(st, [Vector3(0, 0.15, -0.25), Vector3(0, 0.15, 0.02), Vector3(0, 0.12, 0.1), Vector3(0, -0.04, 0.14)], [0.055, 0.055, 0.05, 0.045], 8, BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.06, 0.14)), 0.06, 0.055, 0.05, 8, BRASS.darkened(0.15))
	# The tap's handle: a red spoked wheel on a stem.
	MeshKit.add_limb(st, Vector3(0, 0.15, 0.02), Vector3(0, 0.31, 0.02), 0.02, BRASS, 4)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.31, 0.02)), 0.12, 0.12, 0.035, 10, Palette.TEAM_WEST)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.33, 0.02)), 0.04, 0.04, 0.03, 6, BRASS)
	# A bucket hook under it.
	MeshKit.add_limb(st, Vector3(0, -0.08, 0.14), Vector3(0, -0.24, 0.14), 0.015, IRON, 4)
	MeshKit.add_limb(st, Vector3(0, -0.24, 0.14), Vector3(0, -0.2, 0.2), 0.015, IRON, 4)
	return MeshKit.finish(st)


## The generator: a hit-and-miss farm engine on a timber skid (crankcase, a
## horizontal cylinder with its water hopper, fuel tank, exhaust stack with a
## muffler) belted to a dynamo. The flywheel is separate (it spins), on the
## crankshaft at (0.56, 0.55, 0.25); the stack tops out at about (-0.35, 2.1, -0.45).
static func generator_body(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var crank := Vector3(0, 0.55, 0.25)
	# Skid: two runners with upturned noses and three cross boards.
	for sx: float in [-0.42, 0.42]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.08, 0)), Vector3(0.16, 0.16, 1.8), Palette.WOOD_DARK, 0.02, rng)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sx, 0.13, 0.95)), Vector3(0.16, 0.12, 0.25), Palette.WOOD_DARK)
	for cz: float in [-0.7, 0.0, 0.7]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.18, cz)), Vector3(1.0, 0.06, 0.3), Palette.WOOD.darkened(rng.randf() * 0.15), 0.01, rng)
	# Crankcase (rounded top) with bearing caps and the crankshaft through to the flywheel.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.38, crank.z)), Vector3(0.62, 0.36, 0.62), ENGINE, 0.01, rng)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), crank), 0.31, 0.31, 0.6, 12, ENGINE)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.23, crank.z)), Vector3(0.78, 0.1, 0.72), ENGINE.darkened(0.25))
	MeshKit.add_limb(st, Vector3(-0.5, crank.y, crank.z), Vector3(0.6, crank.y, crank.z), 0.05, Palette.METAL, 6)
	for bx: float in [-0.33, 0.33]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(bx, crank.y, crank.z)), 0.11, 0.11, 0.08, 8, ENGINE.darkened(0.2))
	# Brass maker's plate on the crankcase side.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.31, 0.38, crank.z + 0.05)), Vector3(0.02, 0.14, 0.3), BRASS)
	# The cylinder runs back from the crankcase: a fat barrel with a head and an igniter.
	var cyl_b := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(st, Transform3D(cyl_b, Vector3(0, 0.5, -0.25)), 0.22, 0.22, 0.6, 12, ENGINE)
	MeshKit.add_cylinder(st, Transform3D(cyl_b, Vector3(0, 0.5, -0.59)), 0.25, 0.25, 0.1, 12, ENGINE.darkened(0.2))
	MeshKit.add_cylinder(st, Transform3D(cyl_b, Vector3(0, 0.5, -0.66)), 0.15, 0.15, 0.06, 8, IRON)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.22, 0.6, -0.52)), Vector3(0.1, 0.12, 0.1), IRON)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.22, 0.7, -0.52)), Vector3.ONE * 0.04, 2, 6, Palette.BONE)
	# The water hopper on top of the cylinder (it cools the engine): flared, with a dark water line.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.93, -0.25)), 0.25, 0.3, 0.56, 10, ENGINE)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.22, -0.25)), 0.32, 0.32, 0.04, 10, ENGINE.darkened(0.25), false)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.19, -0.25)), 0.27, 0.27, 0.02, 10, WATER.darkened(0.3))
	# Fuel tank: a red drum on brackets on the right side, a line to the mixer.
	MeshKit.add_cylinder(st, Transform3D(cyl_b, Vector3(0.38, 0.86, -0.42)), 0.13, 0.13, 0.42, 10, Palette.TEAM_WEST.darkened(0.1))
	for bz: float in [-0.55, -0.3]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.3, 0.72, bz)), Vector3(0.2, 0.04, 0.05), IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.38, 1.01, -0.5)), 0.04, 0.04, 0.05, 6, BRASS)
	MeshKit.tube(st, [Vector3(0.36, 0.74, -0.25), Vector3(0.3, 0.6, -0.15), Vector3(0.2, 0.52, -0.12)], [0.015], 4, BRASS)
	# Exhaust: elbow off the head, a muffler drum, then the stack with a rain cap.
	MeshKit.tube(st, [Vector3(-0.15, 0.5, -0.55), Vector3(-0.35, 0.55, -0.5), Vector3(-0.35, 0.8, -0.45)], [0.05], 6, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.35, 1.0, -0.45)), 0.11, 0.11, 0.4, 8, IRON.lightened(0.05))
	MeshKit.add_limb(st, Vector3(-0.35, 1.2, -0.45), Vector3(-0.35, 1.98, -0.45), 0.045, IRON, 6)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.35, 2.06, -0.45)), 0.07, 0.05, 0.12, 6, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.35, 2.17, -0.45)), 0.13, 0.0, 0.08, 6, IRON)
	MeshKit.add_limb(st, Vector3(-0.35, 2.06, -0.45), Vector3(-0.35, 2.14, -0.45), 0.012, IRON, 3)
	# The dynamo up front, belted to a pulley on the left of the crankshaft.
	var dyn := Vector3(-0.1, 0.45, 0.78)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.1, 0.24, 0.78)), Vector3(0.5, 0.08, 0.32), IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), dyn), 0.17, 0.17, 0.42, 12, Color("#2C2A2E"))
	for ex: float in [-0.22, 0.22]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), dyn + Vector3(ex, 0, 0)), 0.18, 0.18, 0.05, 12, BRASS.darkened(0.1), false)
	MeshKit.add_box(st, Transform3D(Basis(), dyn + Vector3(0.05, 0.2, 0)), Vector3(0.14, 0.1, 0.12), Color("#2C2A2E"))
	var p_eng := Vector3(-0.52, crank.y, crank.z)
	var p_dyn := Vector3(-0.52, dyn.y, dyn.z)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), p_eng), 0.13, 0.13, 0.08, 10, Palette.METAL)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), p_dyn), 0.07, 0.07, 0.08, 8, Palette.METAL)
	MeshKit.add_limb(st, Vector3(-0.32, dyn.y, dyn.z), p_dyn, 0.025, Palette.METAL, 4)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _belt_xf(p_eng + Vector3(0, side * 0.13, 0), p_dyn + Vector3(0, side * 0.07, 0)), Vector3(0.06, 0.02, (p_eng - p_dyn).length()), Color("#5A3A2A"))
	# Terminal box and conduit at the back right (the cables run out from here).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.48, 0.42, -0.5)), Vector3(0.2, 0.26, 0.2), IRON.lightened(0.1))
	MeshKit.add_limb(st, Vector3(0.58, 0.4, -0.5), Vector3(0.62, 0.1, -0.5), 0.035, IRON, 5)
	MeshKit.tube(st, [Vector3(0.1, 0.6, 0.78), Vector3(0.3, 0.6, 0.6), Vector3(0.46, 0.5, -0.1), Vector3(0.48, 0.5, -0.4)], [0.02], 4, Color("#1E1C1C"))
	return MeshKit.finish(st)


## The big flywheel on the engine's side, centred on its axle (spins round local X):
## a heavy rim, six red spokes and a hub.
static func flywheel() -> ArrayMesh:
	var st := MeshKit.begin()
	var pts: Array = []
	for i in 19:
		var a := TAU * float(i) / 18.0
		pts.append(Vector3(0, cos(a), sin(a)) * 0.37)
	MeshKit.tube(st, pts, [0.055], 6, IRON)
	MeshKit.add_rim(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 0.38, 0.31, 0.09, 18, IRON.lightened(0.05)) # solid from the side
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 0.09, 0.09, 0.16, 8, Palette.METAL)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.09, 0, 0)), 0.05, 0.05, 0.04, 6, BRASS)
	# Spokes (painted, so the spin reads).
	for i in 6:
		var a := TAU * float(i) / 6.0
		var d := Vector3(0, cos(a), sin(a))
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, a), d * 0.22), Vector3(0.035, 0.3, 0.06), Palette.TEAM_WEST if i % 3 == 0 else Palette.TEAM_WEST.darkened(0.25))
	return MeshKit.finish(st)


## The circuit-breaker box on its post (the lever handle is separate). The lever
## pivots at (0.2, 1.3, 0.24) between two cheek plates on the box's right side;
## the lamp sits on top at about (-0.15, 1.82, 0.08).
static func breaker_box(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var bx := -0.13 # the box sits left of the lever so the handle swings clear past it
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, 0.08, 0)), Vector3(0.34, 0.16, 0.34), CONCRETE, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, 0.6, -0.08)), Vector3(0.15, 1.2, 0.15), Palette.WOOD, 0.02, rng)
	# The box: steel case, a raised door with hinges and a latch, a little rain hood.
	var case_col := Color("#56636B")
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, 1.3, 0.02)), Vector3(0.56, 0.74, 0.24), case_col, 0.01, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, 1.28, 0.15)), Vector3(0.48, 0.62, 0.03), case_col.lightened(0.12))
	for hy: float in [1.08, 1.48]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx - 0.25, hy, 0.16)), Vector3(0.04, 0.1, 0.04), IRON)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx + 0.2, 1.28, 0.17)), Vector3(0.03, 0.12, 0.03), BRASS)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(bx - 0.02, 1.71, 0.05)), Vector3(0.58, 0.05, 0.34), case_col.darkened(0.2))
	# Hazard stripes (yellow and black) across the door, and the ON / OFF plates by the lever.
	for k in 5:
		var c := Palette.GLOW_YELLOW.darkened(0.1) if k % 2 == 0 else IRON
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(bx - 0.18 + k * 0.09, 1.5, 0.17)), Vector3(0.05, 0.16, 0.01), c)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, 1.5, 0.165)), Vector3(0.46, 0.14, 0.01), Palette.GLOW_YELLOW.darkened(0.35))
	# Lever mount: a bracket out of the box's right side, two cheek plates round the pivot.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.21, 1.3, 0.04)), Vector3(0.14, 0.2, 0.17), case_col.darkened(0.25))
	for cx: float in [0.115, 0.285]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx, 1.3, 0.2)), Vector3(0.03, 0.24, 0.3), IRON)
	# OFF (red, lever up and back) and ON (green, lever down and out) plates on the outer cheek.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.305, 1.4, 0.13)), Vector3(0.012, 0.06, 0.09), Palette.TEAM_WEST)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.305, 1.2, 0.3)), Vector3(0.012, 0.06, 0.09), Palette.ACID_GREEN.darkened(0.2))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.2, 1.3, 0.24)), 0.035, 0.035, 0.24, 8, Palette.METAL)
	for cx: float in [0.095, 0.305]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(cx, 1.3, 0.24)), 0.05, 0.05, 0.02, 6, BRASS)
	# Lamp collar on top, conduit down the post to the ground.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.15, 1.76, 0.08)), 0.08, 0.06, 0.06, 8, IRON)
	MeshKit.tube(st, [Vector3(bx + 0.18, 0.94, -0.05), Vector3(bx + 0.18, 0.8, -0.12), Vector3(bx + 0.18, 0.08, -0.12), Vector3(bx + 0.18, 0.0, -0.2)], [0.035], 5, IRON)
	return MeshKit.finish(st)


## The big breaker lever, pivoting at its origin round local X: the handle runs
## up (+Y) to a fat red grip.
static func lever_handle() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 0.065, 0.065, 0.1, 10, IRON)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.27, 0)), Vector3(0.055, 0.5, 0.035), Palette.METAL)
	MeshKit.add_limb(st, Vector3(0, 0.5, 0), Vector3(0, 0.6, 0), 0.03, Palette.METAL, 6)
	# The grip: a fat red T-handle with black end caps.
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.63, 0)), 0.065, 0.065, 0.22, 10, Palette.TEAM_WEST)
	for ex: float in [-0.12, 0.12]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(ex, 0.63, 0)), Vector3(0.035, 0.07, 0.07), 3, 8, IRON)
	return MeshKit.finish(st)


## A sagging run of cable from a to b (local), staked down along the way.
static func cable(a: Vector3, b: Vector3, ground: Callable, radius: float = 0.03, color: Color = IRON, stakes: bool = true) -> ArrayMesh:
	var st := MeshKit.begin()
	var steps := maxi(int(a.distance_to(b) / 0.6), 2)
	var pts: Array = [a]
	for k in range(1, steps + 1):
		var t := float(k) / float(steps)
		var p := a.lerp(b, t)
		p.y = float(ground.call(p)) + radius + 0.03 + 0.04 * sin(t * PI * 3.0)
		if k == steps:
			p = b
		pts.append(p)
		if stakes and k % 3 == 0 and k < steps:
			# A wooden stake with a little cleat over the cable.
			MeshKit.add_box(st, Transform3D(Basis(), p + Vector3(0, 0.07, 0)), Vector3(0.06, 0.24, 0.06), Palette.WOOD_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), p + Vector3(0, radius + 0.02, 0)), Vector3(0.1, 0.03, 0.1), IRON)
		elif not stakes and k % 4 == 0 and k < steps:
			# Pipe: a coupling now and then.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * radius * 1.35, 3, 6, color.darkened(0.15))
	MeshKit.tube(st, pts, [radius], 5 if radius < 0.05 else 6, color)
	return MeshKit.finish(st)


## A thin round rail (a closed tube) at height y.
static func _ring(st: SurfaceTool, y: float, radius: float, thickness: float, color: Color, segments: int) -> void:
	var pts: Array = []
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector3(cos(a) * radius, y, sin(a) * radius))
	MeshKit.tube(st, pts, [thickness], 4, color)


## A transform for a flat belt run from a to b (its local Z along the run).
static func _belt_xf(a: Vector3, b: Vector3) -> Transform3D:
	var d := (b - a).normalized()
	var x := Vector3.RIGHT
	var y := d.cross(x).normalized()
	return Transform3D(Basis(x, y, d), (a + b) * 0.5)


static func _ladder(st: SurfaceTool, at: Vector3, height: float) -> void:
	for sx: float in [-0.22, 0.22]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.1 / height), at + Vector3(sx, height * 0.5, -0.05)), Vector3(0.06, height, 0.08), Palette.WOOD_DARK)
	var rungs := int(height / 0.4)
	for k in range(1, rungs):
		var y := float(k) * 0.4
		MeshKit.add_limb(st, at + Vector3(-0.22, y, -0.1 * y / height), at + Vector3(0.22, y, -0.1 * y / height), 0.02, Palette.WOOD_DARK, 4)


static func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _cyl(radius: float, height: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	return c
