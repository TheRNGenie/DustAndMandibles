class_name WellJackBuilder
extends RefCounted
## Meshes for the homestead's mechanical well (MechWell): a walking-beam pump
## jack of about 1900, belted to the yard's generator. The engine turns a short
## drive pulley; a flat belt runs from it to the bull wheel on the jack's crank
## shaft; the cranks (with their counterweights) heave two pitman arms that rock
## the walking beam on its Samson post; the horsehead on the beam's far end lifts
## the sucker rod out of the well casing, and every up-stroke spills a gush from
## the spout into the trough.
##
## Local space: +Z runs along the beam toward the generator (the crank end), -Z
## is the well end; y = 0 is the ground. The moving parts are separate meshes:
##   beam    pivots round local X at PIVOT (style height, see pivot_y)
##   crank   turns round local X at CRANK (cranks, counterweights, bull wheel)
##   pitman  a unit-length pair of arms along +Y (posed and stretched each frame)
##   rod     the carrier bar, bridle and polished rod (hangs at z = -ARM)
##   drive   the small drive pulley at the generator (turns round local X)
##   tumbler a unit-length tumbling rod along +Y from the drive to the engine
##
## One design per cliff (Waterworks.style_of), matching the towers:
##   timber   heavy squared timbers, iron straps, a wooden horsehead, plank trough
##   steel    riveted oxide-red I-beam and lattice post on a concrete pad, galvanised round tank
##   adobe    painted beam on posts set in a plastered adobe plinth, tiled adobe trough
##   trestle  a tall X-braced timber trestle, grey weathered wood, a hollowed-log trough

## The horsehead's radius from the pivot (the rod hangs this far toward -Z).
const ARM := 1.7
## Where the pitman arms grab the beam (beam-local, from the pivot).
const BEAM_GRAB := Vector3(0.0, -0.17, 1.3)
## The crank shaft (jack-local) and the crank radius.
const CRANK := Vector3(0.0, 0.95, 1.45)
const CRANK_R := 0.3
## The bull wheel on the crank shaft (x offset, radius), and the drive pulley's radius.
const BULL_X := 0.7
const BULL_R := 0.5
const DRIVE_R := 0.24
## Where the trough sits, and the spout over it.
const TROUGH_Z := -2.75
const SPOUT := Vector3(0.0, 1.0, -2.45)
## Trough water heights (empty .. full).
const WATER_LOW := 0.22
const WATER_HIGH := 0.56

const IRON := WaterworksBuilder.IRON
const STEEL := WaterworksBuilder.STEEL
const GALV := WaterworksBuilder.GALV
const ADOBE := WaterworksBuilder.ADOBE
const PLASTER := WaterworksBuilder.PLASTER
const CONCRETE := WaterworksBuilder.CONCRETE
const BRASS := WaterworksBuilder.BRASS
const TILE_BLUE := WaterworksBuilder.TILE_BLUE
const BEAM_BLUE := Color("#3F6E8C")
const GREY_WOOD := Color("#8D8476")
const BELT := Color("#5A3A2A")


static func pivot_y(style: StringName) -> float:
	return {&"steel": 2.45, &"adobe": 2.55, &"trestle": 2.75}.get(style, 2.4)


static func _wood(style: StringName) -> Color:
	return GREY_WOOD if style == &"trestle" else Palette.WOOD


static func _beam_col(style: StringName) -> Color:
	return {&"steel": STEEL, &"adobe": BEAM_BLUE, &"trestle": GREY_WOOD.darkened(0.1)}.get(style, Palette.WOOD_DARK)


## A box from a to b (its long axis), `w` x `t` across.
static func _strut(st: SurfaceTool, a: Vector3, b: Vector3, w: float, t: float, col: Color, rng: RandomNumberGenerator = null, jitter := 0.0) -> void:
	if a.distance_to(b) < 0.01:
		return
	var y := (b - a).normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	MeshKit.add_box(st, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, a.distance_to(b), t), col, jitter, rng)


static func _axle_cyl(st: SurfaceTool, at: Vector3, r: float, w: float, col: Color, segs := 10, caps := true) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), at), r, r, w, segs, col, caps)


# ------------------------------------------------------------------ the frame

## Everything that stands still: the base, the Samson post, the crank bearings,
## the well casing and spout, and the trough. Returns {"mesh", "shapes", "water"}
## where water = {"round": bool, "size": Vector3 (x, unused, z) or radius in x}.
static func frame(style: StringName, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var h := pivot_y(style)
	var wood := _wood(style)
	var base_y := 0.0
	match style:
		&"steel":
			# A poured concrete pad with a chamfered edge and anchor bolts.
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, 0.3)), Vector3(1.5, 0.2, 3.4), CONCRETE, 0.02, rng)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, 0.3)), Vector3(1.62, 0.06, 3.52), CONCRETE.darkened(0.15))
			base_y = 0.2
		&"adobe":
			# A plastered adobe plinth the posts are set into, with a darker footing.
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.22, 0.3)), Vector3(1.4, 0.44, 3.3), ADOBE, 0.05, rng)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.46, 0.3)), Vector3(1.48, 0.07, 3.38), PLASTER, 0.02, rng)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0.3)), Vector3(1.52, 0.1, 3.42), ADOBE.darkened(0.25))
			for k in 6:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.705, 0.3, -1.0 + k * 0.52)), Vector3(0.02, 0.12, 0.22), TILE_BLUE if k % 2 == 0 else Palette.BONE)
			base_y = 0.5
		_:
			# Two long sills on the ground with cross ties (timber, trestle).
			for sx: float in [-0.5, 0.5]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.11, 0.35)), Vector3(0.22, 0.22, 3.4), wood.darkened(0.15), 0.02, rng)
			for cz: float in [-1.15, -0.2, 0.75, 1.75]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.26, cz)), Vector3(1.3, 0.1, 0.2), wood.darkened(rng.randf() * 0.15), 0.02, rng)
			# Iron dogs where the ties cross the sills.
			for sx: float in [-0.5, 0.5]:
				for cz: float in [-1.15, 1.75]:
					MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.31, cz)), Vector3(0.24, 0.02, 0.06), IRON)
			base_y = 0.31
	_samson(st, rng, style, h, base_y)
	_crank_bearings(st, rng, style, base_y)
	_casing(st, style, base_y)
	var water := _trough(st, rng, style)
	var shapes: Array = []
	shapes.append([WaterworksBuilder._box(Vector3(1.2, h + 0.2, 2.0)), Transform3D(Basis(), Vector3(0, (h + 0.2) * 0.5, 0.0))])
	shapes.append([WaterworksBuilder._box(Vector3(1.9, 1.5, 1.2)), Transform3D(Basis(), Vector3(0.1, 0.75, CRANK.z + 0.1))])
	shapes.append([WaterworksBuilder._box(Vector3(0.6, 1.1, 0.6)), Transform3D(Basis(), Vector3(0, 0.55, -ARM))])
	var ts: Vector3 = water["shape"]
	shapes.append([WaterworksBuilder._box(ts), Transform3D(Basis(), Vector3(0, ts.y * 0.5, TROUGH_Z))])
	return {"mesh": MeshKit.finish(st), "shapes": shapes, "water": water}


## Just the well casing with its spout and the trough (frame() without the
## sills and Samson post): what stays when an AI-made jack stands in.
static func trough_casing(style: StringName, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var base_y: float = {&"steel": 0.2, &"adobe": 0.5}.get(style, 0.31)
	_casing(st, style, base_y)
	_trough(st, rng, style)
	return MeshKit.finish(st)


## The Samson post: an A-frame each side of the beam carrying the saddle bearings.
static func _samson(st: SurfaceTool, rng: RandomNumberGenerator, style: StringName, h: float, base_y: float) -> void:
	var wood := _wood(style)
	var top := h - 0.13
	if style == &"steel":
		# Lattice legs of angle iron, laced with flat bar, riveted gussets at the feet.
		for sx: float in [-1.0, 1.0]:
			var head := Vector3(sx * 0.2, top, 0)
			var feet: Array[Vector3] = [Vector3(sx * 0.5, base_y, -0.85), Vector3(sx * 0.5, base_y, 0.85)]
			for f in feet:
				_strut(st, f, head, 0.08, 0.08, STEEL, rng, 0.0)
				MeshKit.add_box(st, Transform3D(Basis(), f + Vector3(0, 0.03, 0)), Vector3(0.22, 0.06, 0.22), STEEL.darkened(0.2))
				for bx: float in [-0.07, 0.07]:
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), f + Vector3(bx, 0.07, bx)), Vector3.ONE * 0.025, 2, 5, IRON)
			# Lacing: a zig-zag up between the two legs, and horizontal ties.
			var n := 5
			for k in n:
				var t0 := float(k) / float(n)
				var t1 := float(k + 1) / float(n)
				var a := feet[0].lerp(head, t0)
				var b := feet[1].lerp(head, t1)
				var c := feet[0].lerp(head, t1)
				_strut(st, a, b, 0.035, 0.012, STEEL.darkened(0.1))
				_strut(st, b, c, 0.035, 0.012, STEEL.darkened(0.1))
			_strut(st, feet[0].lerp(head, 0.35), feet[1].lerp(head, 0.35), 0.06, 0.06, STEEL)
		# Cross ties between the two frames.
		for y: float in [base_y + 0.9, top - 0.45]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(0.85 - (y - base_y) * 0.12, 0.06, 0.06), STEEL)
	else:
		var leg := 0.17 if style != &"trestle" else 0.14
		for sx: float in [-1.0, 1.0]:
			var head := Vector3(sx * 0.21, top, 0)
			var spread := 0.95 if style != &"trestle" else 1.05
			var feet: Array[Vector3] = [Vector3(sx * 0.5, base_y, -spread), Vector3(sx * 0.5, base_y, spread)]
			for f in feet:
				_strut(st, f, head, leg, leg, wood.darkened(rng.randf() * 0.12), rng, 0.01)
				if style == &"adobe":
					# The post is set in a plastered collar on the plinth.
					MeshKit.add_box(st, Transform3D(Basis(), f + Vector3(0, 0.06, 0)), Vector3(0.3, 0.12, 0.3), PLASTER.darkened(0.06), 0.02, rng)
				else:
					# Iron shoe on the sill.
					MeshKit.add_box(st, Transform3D(Basis(), f + Vector3(0, 0.05, 0)), Vector3(leg + 0.05, 0.1, leg + 0.05), IRON)
			# A collar tie and braces.
			var tie_t := 0.45
			_strut(st, feet[0].lerp(head, tie_t), feet[1].lerp(head, tie_t), 0.12, 0.08, wood.darkened(0.08), rng, 0.01)
			if style == &"trestle":
				# The trestle: full X-bracing and a second tie.
				_strut(st, feet[0], feet[1].lerp(head, tie_t), 0.1, 0.05, wood.darkened(0.15))
				_strut(st, feet[1], feet[0].lerp(head, tie_t), 0.1, 0.05, wood.darkened(0.15))
				_strut(st, feet[0].lerp(head, 0.78), feet[1].lerp(head, 0.78), 0.1, 0.07, wood.darkened(0.08))
				_strut(st, feet[0].lerp(head, tie_t), feet[1].lerp(head, 0.78), 0.08, 0.05, wood.darkened(0.18))
				_strut(st, feet[1].lerp(head, tie_t), feet[0].lerp(head, 0.78), 0.08, 0.05, wood.darkened(0.18))
			else:
				_strut(st, feet[0].lerp(head, tie_t), head + Vector3(0, -0.35, 0), 0.08, 0.07, wood.darkened(0.12))
				_strut(st, feet[1].lerp(head, tie_t), head + Vector3(0, -0.35, 0), 0.08, 0.07, wood.darkened(0.12))
			# Iron strap plates over the joints at the head.
			MeshKit.add_box(st, Transform3D(Basis(), head + Vector3(sx * 0.09, -0.2, 0)), Vector3(0.02, 0.35, 0.3), IRON)
		# Spreaders between the two A-frames.
		for t: float in [0.2, 0.62]:
			var y := lerpf(base_y, top, t)
			var half := lerpf(0.5, 0.21, t)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(half * 2.0 + 0.1, 0.1, 0.1), wood.darkened(0.1), 0.01, rng)
	# Saddle bearings on top: iron blocks with a cap and two bolts, an oil cup.
	for sx: float in [-0.2, 0.2]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, h - 0.06, 0)), Vector3(0.12, 0.16, 0.3), IRON.lightened(0.05))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, h + 0.06, 0)), Vector3(0.13, 0.06, 0.22), IRON)
		for bz: float in [-0.08, 0.08]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(sx, h + 0.11, bz)), 0.02, 0.02, 0.06, 5, BRASS.darkened(0.3))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.2, h + 0.17, 0)), 0.025, 0.035, 0.08, 6, BRASS)


## Bearing pedestals for the crank shaft, each side.
static func _crank_bearings(st: SurfaceTool, rng: RandomNumberGenerator, style: StringName, base_y: float) -> void:
	var c := CRANK
	for sx: float in [-0.52, 0.52]:
		var top := c.y - 0.06
		if style == &"steel":
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(sx, (base_y + top) * 0.5, c.z)), 0.14, 0.09, top - base_y, 8, IRON.lightened(0.08))
		else:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, (base_y + top) * 0.5, c.z)), Vector3(0.2, top - base_y, 0.42), _wood(style).darkened(0.18), 0.015, rng)
			# A raking brace back toward the post.
			_strut(st, Vector3(sx, base_y, c.z - 0.75), Vector3(sx, top - 0.1, c.z - 0.12), 0.1, 0.08, _wood(style).darkened(0.1))
		# Pillow block: base, cap, bolts.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, c.y - 0.04, c.z)), Vector3(0.14, 0.08, 0.34), IRON)
		_axle_cyl(st, Vector3(sx, c.y, c.z), 0.085, 0.12, IRON.lightened(0.1), 8)
		for bz: float in [-0.12, 0.12]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(sx, c.y + 0.02, c.z + bz)), 0.022, 0.022, 0.1, 5, BRASS.darkened(0.3))


## The well casing, its stuffing box, the tee and flow line out to the spout.
static func _casing(st: SurfaceTool, style: StringName, base_y: float) -> void:
	var w := Vector3(0, 0, -ARM)
	# A curb round the casing.
	match style:
		&"adobe":
			MeshKit.add_cylinder(st, Transform3D(Basis(), w + Vector3(0, base_y + 0.04, 0)), 0.32, 0.3, 0.08, 10, PLASTER.darkened(0.05))
		&"steel":
			pass
		_:
			MeshKit.add_box(st, Transform3D(Basis(), w + Vector3(0, base_y - 0.02, 0)), Vector3(0.7, 0.06, 0.7), Palette.WOOD_DARK)
	var col := IRON.lightened(0.05)
	MeshKit.add_cylinder(st, Transform3D(Basis(), w + Vector3(0, 0.5, 0)), 0.11, 0.11, 1.0, 10, col)
	for y: float in [base_y + 0.06, 0.55]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), w + Vector3(0, y, 0)), 0.15, 0.15, 0.06, 10, col.darkened(0.15))
	# Stuffing box: a brass gland on top that the polished rod slides through.
	MeshKit.add_cylinder(st, Transform3D(Basis(), w + Vector3(0, 1.04, 0)), 0.13, 0.13, 0.08, 10, col.darkened(0.1))
	MeshKit.add_cylinder(st, Transform3D(Basis(), w + Vector3(0, 1.12, 0)), 0.07, 0.09, 0.1, 10, BRASS)
	for k in 3:
		var a := TAU * k / 3.0
		MeshKit.add_limb(st, w + Vector3(cos(a) * 0.1, 1.02, sin(a) * 0.1), w + Vector3(cos(a) * 0.075, 1.2, sin(a) * 0.075), 0.012, IRON, 4)
	# Tee and flow line to the spout, with a check valve and a gooseneck.
	var tee := w + Vector3(0, 0.8, 0)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), tee + Vector3(0, 0, -0.14)), 0.07, 0.07, 0.2, 8, col)
	MeshKit.tube(st, [tee + Vector3(0, 0, -0.2), Vector3(0, 0.8, -2.15), Vector3(0, 0.96, -2.3), SPOUT + Vector3(0, 0.0, -0.02)], [0.05], 6, col)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.8, -1.95)), 0.08, 0.08, 0.14, 8, BRASS.darkened(0.15))
	MeshKit.add_cylinder(st, Transform3D(Basis(), SPOUT + Vector3(0, -0.04, -0.02)), 0.06, 0.065, 0.06, 8, col.darkened(0.1))
	# A prop under the flow line.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.38, -2.05)), Vector3(0.08, 0.76, 0.08), Palette.WOOD_DARK)
	# The line out to the tower leaves the casing low down.
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), w + Vector3(0.18, 0.2, 0)), 0.065, 0.065, 0.2, 8, col)


## The trough under the spout. Returns {"round", "size" (x, z or radius in x), "shape"}.
static func _trough(st: SurfaceTool, rng: RandomNumberGenerator, style: StringName) -> Dictionary:
	var t := Vector3(0, 0, TROUGH_Z)
	match style:
		&"steel":
			# A galvanised round stock tank with rolled rims.
			MeshKit.add_cylinder(st, Transform3D(Basis(), t + Vector3(0, 0.31, 0)), 0.72, 0.72, 0.62, 18, GALV)
			for y: float in [0.12, 0.3, 0.48]:
				MeshKit.add_cylinder(st, Transform3D(Basis(), t + Vector3(0, y, 0)), 0.735, 0.735, 0.04, 18, GALV.darkened(0.2), false)
			var pts: Array = []
			for i in 19:
				var a := TAU * float(i) / 18.0
				pts.append(t + Vector3(cos(a) * 0.72, 0.62, sin(a) * 0.72))
			MeshKit.tube(st, pts, [0.035], 4, GALV.lightened(0.1))
			MeshKit.add_cylinder(st, Transform3D(Basis(), t + Vector3(0, WATER_LOW - 0.02, 0)), 0.68, 0.68, 0.04, 18, WaterworksBuilder.WATER.darkened(0.45))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), t + Vector3(0.4, 0.1, 0.72)), 0.06, 0.06, 0.06, 6, BRASS)
			return {"round": true, "size": Vector3(0.69, 0, 0.69), "shape": Vector3(1.45, 0.64, 1.45)}
		&"adobe":
			# A plastered adobe trough with a blue and white tiled band.
			var sz := Vector3(1.9, 0.62, 0.95)
			# Hollow: a floor and four walls, so the water shows inside.
			MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, 0.08, 0)), Vector3(sz.x, 0.16, sz.z), ADOBE, 0.03, rng)
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, 0.28, side * (sz.z * 0.5 - 0.08))), Vector3(sz.x, 0.56, 0.16), ADOBE, 0.03, rng)
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * (sz.x * 0.5 - 0.08), 0.28, 0)), Vector3(0.16, 0.56, sz.z), ADOBE, 0.03, rng)
			for face in 4:
				var b := Basis(Vector3.UP, face * PI * 0.5)
				var along := sz.x if face % 2 == 0 else sz.z
				var out := sz.z * 0.5 if face % 2 == 0 else sz.x * 0.5
				MeshKit.add_box(st, Transform3D(b, t + b * Vector3(0, 0.59, out - 0.08)), Vector3(along + 0.04, 0.08, 0.18), PLASTER, 0.01, rng)
			for side: float in [-1.0, 1.0]:
				for k in 7:
					MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(-0.78 + k * 0.26, 0.38, side * (sz.z * 0.5 + 0.005))), Vector3(0.2, 0.18, 0.02), TILE_BLUE if k % 2 == 0 else Palette.BONE)
			MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, WATER_LOW - 0.02, 0)), Vector3(1.6, 0.04, 0.66), WaterworksBuilder.WATER.darkened(0.45))
			return {"round": false, "size": Vector3(1.62, 0, 0.66), "shape": Vector3(sz.x, 0.64, sz.z)}
		&"trestle":
			# A hollowed log on two cradles, its ends capped with boards.
			var log_col := Color("#7A6A58")
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * 0.7, 0.12, 0)), Vector3(0.14, 0.24, 0.8), GREY_WOOD.darkened(0.2), 0.02, rng)
			var sides := 9
			for i in sides:
				var a0 := PI * float(i) / float(sides)
				var a1 := PI * float(i + 1) / float(sides)
				var am := (a0 + a1) * 0.5
				var r := 0.4
				var p := Vector3(0, 0.62 - sin(am) * r, cos(am) * r)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, am + PI * 0.5), t + p), Vector3(1.9, 0.09, r * (a1 - a0) + 0.02), log_col.darkened(rng.randf() * 0.15), 0.01, rng)
			for side: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * 0.93, 0.42, 0)), Vector3(0.05, 0.42, 0.8), GREY_WOOD.darkened(0.25))
			# Bark rings and iron hoops.
			for x: float in [-0.55, 0.55]:
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(x, 0.34, 0)), Vector3(0.05, 0.56, 0.86), IRON)
			MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, WATER_LOW + 0.02, 0)), Vector3(1.8, 0.03, 0.3), WaterworksBuilder.WATER.darkened(0.45))
			return {"round": false, "size": Vector3(1.8, 0, 0.6), "shape": Vector3(1.9, 0.64, 0.85)}
		_:
			# A plank trough on feet, iron corner straps.
			var sz := Vector3(1.9, 0.6, 0.8)
			MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, 0.15, 0)), Vector3(sz.x, 0.06, sz.z), Palette.WOOD_DARK)
			for side: float in [-1.0, 1.0]:
				for k in 3:
					MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, 0.22 + k * 0.14, side * (sz.z * 0.5 - 0.03))), Vector3(sz.x, 0.13, 0.05), Palette.WOOD.darkened(rng.randf() * 0.18), 0.01, rng)
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * (sz.x * 0.5 - 0.03), 0.38, 0)), Vector3(0.05, 0.46, sz.z), Palette.WOOD.darkened(0.1), 0.01, rng)
				for cz: float in [-1.0, 1.0]:
					MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * sz.x * 0.5, 0.38, cz * sz.z * 0.5)), Vector3(0.06, 0.5, 0.06), IRON)
				MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(side * 0.7, 0.06, 0)), Vector3(0.14, 0.12, sz.z + 0.2), Palette.WOOD_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), t + Vector3(0, WATER_LOW - 0.02, 0)), Vector3(1.78, 0.04, 0.68), WaterworksBuilder.WATER.darkened(0.45))
			return {"round": false, "size": Vector3(1.78, 0, 0.68), "shape": Vector3(sz.x, 0.64, sz.z)}


# ------------------------------------------------------------------ moving parts

## The walking beam, horsehead and equalizer, centred on the pivot.
static func beam(style: StringName, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var col := _beam_col(style)
	var back := BEAM_GRAB.z + 0.18
	var front := -(ARM - 0.35)
	if style == &"steel":
		# A riveted I-beam: web and two flanges, rivet rows.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, (front + back) * 0.5)), Vector3(0.05, 0.3, back - front), col)
		for y: float in [-0.15, 0.15]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, (front + back) * 0.5)), Vector3(0.22, 0.035, back - front), col.darkened(0.08))
		var n := 14
		for k in n:
			var z := lerpf(front + 0.1, back - 0.1, float(k) / float(n - 1))
			for y: float in [-0.12, 0.12]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.03, y, z)), Vector3.ONE * 0.018, 2, 5, col.darkened(0.3))
		# Stiffener plates at the pivot.
		for z: float in [-0.12, 0.12]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, z)), Vector3(0.2, 0.27, 0.025), col.darkened(0.15))
	else:
		# A squared timber with iron straps, and a king-post truss under it.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, (front + back) * 0.5)), Vector3(0.22, 0.3, back - front), col, 0.012, rng)
		for z: float in [front + 0.15, -0.55, 0.55, back - 0.12]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, z)), Vector3(0.235, 0.315, 0.06), IRON)
		# Truss rod: a strut down at the pivot and an iron rod end to end.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.33, 0)), Vector3(0.1, 0.36, 0.1), col.darkened(0.1))
		MeshKit.add_limb(st, Vector3(0, 0.12, front + 0.2), Vector3(0, 0.52, 0), 0.018, IRON, 4)
		MeshKit.add_limb(st, Vector3(0, 0.52, 0), Vector3(0, 0.12, back - 0.15), 0.018, IRON, 4)
	# The pivot pin and its stirrup.
	_axle_cyl(st, Vector3.ZERO, 0.05, 0.52, Palette.METAL, 8)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.28, 0.38, 0.22), IRON.lightened(0.04))
	# The horsehead: a curved face centred on the pivot so the bridle hangs plumb.
	var hc := col if style != &"timber" else Palette.WOOD_DARK.darkened(0.05)
	var segs := 9
	var b0 := -0.3
	var b1 := 0.52
	for i in segs:
		var a0 := lerpf(b0, b1, float(i) / segs)
		var a1 := lerpf(b0, b1, float(i + 1) / segs)
		var am := (a0 + a1) * 0.5
		var dir := Vector3(0, -sin(am), -cos(am))
		var b := Basis(Vector3.RIGHT, -am)
		var depth := 0.5
		# The body between the beam and the face.
		MeshKit.add_box(st, Transform3D(b, dir * (ARM - depth * 0.5)), Vector3(0.2 if style != &"steel" else 0.06, ARM * (a1 - a0) + 0.01, depth), hc, 0.0)
		# The face: a wider band (the bridle seat) with lips each side.
		MeshKit.add_box(st, Transform3D(b, dir * (ARM - 0.03)), Vector3(0.28, ARM * (a1 - a0) + 0.012, 0.06), hc.darkened(0.15))
		for sx: float in [-0.15, 0.15]:
			MeshKit.add_box(st, Transform3D(b, dir * (ARM - 0.0) + Vector3(sx, 0, 0)), Vector3(0.03, ARM * (a1 - a0) + 0.012, 0.1), IRON)
	# Back plate where the head bolts to the beam.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.1, front + 0.1)), Vector3(0.26, 0.55, 0.06), IRON)
	if style == &"steel":
		for i in 4:
			var a := lerpf(b0 + 0.1, b1 - 0.1, i / 3.0)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.04, -sin(a), -cos(a)) * Vector3(1, ARM - 0.25, ARM - 0.25) + Vector3(0.0, 0, 0)), Vector3.ONE * 0.025, 2, 5, IRON)
	# The equalizer at the crank end: a cross bar under the beam with the wrist-pin ears.
	var g := BEAM_GRAB
	MeshKit.add_box(st, Transform3D(Basis(), g + Vector3(0, 0.05, 0)), Vector3(0.12, 0.12, 0.22), IRON)
	MeshKit.add_box(st, Transform3D(Basis(), g), Vector3(0.78, 0.08, 0.14), IRON.lightened(0.06))
	_axle_cyl(st, g + Vector3(0, -0.02, 0), 0.04, 0.84, Palette.METAL, 6)
	return MeshKit.finish(st)


## The crank shaft: two crank arms with counterweights, the pins, the bull wheel.
static func crank(style: StringName) -> ArrayMesh:
	var st := MeshKit.begin()
	var weight := IRON if style != &"steel" else STEEL.darkened(0.2)
	MeshKit.add_limb(st, Vector3(-0.62, 0, 0), Vector3(BULL_X + 0.1, 0, 0), 0.05, Palette.METAL, 8)
	for sx: float in [-0.42, 0.42]:
		# Arm out to the pin, and a heavy counterweight wedge the other way.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, CRANK_R * 0.5, 0)), Vector3(0.06, CRANK_R + 0.12, 0.14), IRON.lightened(0.06))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, -0.16, 0)), Vector3(0.08, 0.26, 0.3), weight)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, -0.31, 0)), Vector3(0.08, 0.1, 0.42), weight.darkened(0.12))
		_axle_cyl(st, Vector3(sx, 0, 0), 0.08, 0.08, IRON, 8)
		# The crank pin reaching in to the pitman.
		MeshKit.add_limb(st, Vector3(sx, CRANK_R, 0), Vector3(sx * 0.7, CRANK_R, 0), 0.035, Palette.METAL, 6)
	# The bull wheel: a crowned rim the belt rides on, painted spokes, a hub.
	var bx := BULL_X
	# A solid rim (walls and faces), with a darker web inside it.
	MeshKit.add_rim(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(bx, 0, 0)), BULL_R, BULL_R - 0.07, 0.16, 22, IRON.lightened(0.04))
	MeshKit.add_rim(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(bx, 0, 0)), BULL_R - 0.07, 0.14, 0.03, 22, IRON.darkened(0.2))
	var paint: Color = {&"timber": Palette.TEAM_WEST, &"steel": Color("#D9B23A"), &"adobe": TILE_BLUE, &"trestle": WaterworksBuilder.ENGINE}.get(style, Palette.TEAM_WEST)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var d := Vector3(0, cos(a), sin(a))
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, a), Vector3(bx, 0, 0) + d * (BULL_R * 0.5)), Vector3(0.04, BULL_R - 0.06, 0.07), paint if i % 3 == 0 else paint.darkened(0.3))
	_axle_cyl(st, Vector3(bx, 0, 0), 0.11, 0.2, IRON, 8)
	return MeshKit.finish(st)


## A pair of pitman arms, unit length along +Y (posed and stretched by MechWell).
static func pitman(style: StringName) -> ArrayMesh:
	var st := MeshKit.begin()
	for sx: float in [-0.3, 0.3]:
		if style == &"steel":
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.5, 0)), Vector3(0.04, 1.0, 0.08), STEEL)
		else:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.5, 0)), Vector3(0.07, 1.0, 0.1), _wood(style).darkened(0.1))
			for y: float in [0.12, 0.88]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, y, 0)), Vector3(0.085, 0.16, 0.115), IRON)
		for y: float in [0.0, 1.0]:
			_axle_cyl(st, Vector3(sx, y, 0), 0.06, 0.1, IRON.lightened(0.08), 8)
	return MeshKit.finish(st)


## The rod string at the horsehead: carrier bar, two bridle wires up the face,
## the polished rod down into the stuffing box (origin at the carrier bar).
static func rod() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.32, 0.06, 0.09), IRON.lightened(0.08))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), Vector3(0.08, 0.08, 0.08), IRON)
	for sx: float in [-0.12, 0.12]:
		MeshKit.add_limb(st, Vector3(sx, 0.0, 0), Vector3(sx, 1.0, 0), 0.014, IRON.darkened(0.1), 4)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sx, 0.0, 0)), Vector3.ONE * 0.03, 2, 5, IRON)
	MeshKit.add_limb(st, Vector3(0, 0.0, 0), Vector3(0, -1.9, 0), 0.026, Palette.METAL.lightened(0.25), 6)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.1, 0)), 0.045, 0.045, 0.08, 6, IRON)
	return MeshKit.finish(st)


## The stand at the generator: a timber trestle (or iron pedestal) holding the
## drive shaft's bearing. `at` is the pulley centre, jack-local.
static func drive_stand(style: StringName, at: Vector3, ground_y: float, dir: float = 1.0) -> ArrayMesh:
	var st := MeshKit.begin()
	var bx := at.x + 0.24 * dir
	var foot := Vector3(bx, ground_y, at.z)
	if style == &"steel":
		MeshKit.add_box(st, Transform3D(Basis(), foot + Vector3(0, 0.06, 0)), Vector3(0.4, 0.12, 0.5), CONCRETE)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(bx, (ground_y + at.y) * 0.5, at.z)), 0.12, 0.07, at.y - ground_y, 8, IRON.lightened(0.08))
	else:
		var wood := _wood(style)
		for sz: float in [-0.22, 0.22]:
			_strut(st, foot + Vector3(0, 0, sz * 1.4), Vector3(bx, at.y - 0.06, at.z + sz * 0.3), 0.1, 0.1, wood.darkened(0.12))
		MeshKit.add_box(st, Transform3D(Basis(), foot + Vector3(0, 0.05, 0)), Vector3(0.16, 0.1, 0.8), wood.darkened(0.2))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, at.y - 0.08, at.z)), Vector3(0.16, 0.06, 0.4), wood.darkened(0.05))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(bx, at.y - 0.03, at.z)), Vector3(0.12, 0.07, 0.26), IRON)
	_axle_cyl(st, Vector3(bx, at.y, at.z), 0.075, 0.12, IRON.lightened(0.1), 8)
	return MeshKit.finish(st)


## The drive pulley and its short shaft, centred on the axle (turns round local X);
## the shaft and its knuckle stick out toward `dir` (the engine's side).
static func drive_pulley(dir: float = 1.0) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_limb(st, Vector3(-0.1 * dir, 0, 0), Vector3(0.42 * dir, 0, 0), 0.04, Palette.METAL, 6)
	_axle_cyl(st, Vector3.ZERO, DRIVE_R, 0.16, IRON.lightened(0.04), 16, true)
	for i in 4:
		var a := TAU * float(i) / 4.0
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.085, 0, 0) + Vector3(0, cos(a), sin(a)) * DRIVE_R * 0.5), Vector3(0.012, DRIVE_R * 0.7, 0.05), Palette.TEAM_WEST)
	# A knuckle for the tumbling rod.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.44 * dir, 0, 0)), Vector3.ONE * 0.06, 3, 6, IRON)
	return MeshKit.finish(st)


## The tumbling rod from the drive shaft to the engine's crankshaft: a square
## iron rod with a knuckle joint each end, unit length along +Y.
static func tumbler() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.04, 0.9, 0.04), IRON.lightened(0.1))
	for y: float in [0.05, 0.95]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(0.09, 0.1, 0.05), IRON)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.07, 0.06, 0.07), BRASS.darkened(0.2))
	return MeshKit.finish(st)


## The flat belt from the drive pulley to the bull wheel (jack-local, static).
static func belt(drive_at: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var bull := Vector3(BULL_X, CRANK.y, CRANK.z)
	var d := drive_at
	d.x = BULL_X
	var along := (d - bull).normalized()
	var n := Vector3(0, along.z, -along.y) # perpendicular in the YZ plane
	if n.y < 0.0:
		n = -n
	for side: float in [1.0, -1.0]:
		var a := bull + n * side * (BULL_R + 0.012)
		var b := d + n * side * (DRIVE_R + 0.012)
		MeshKit.add_box(st, WaterworksBuilder._belt_xf(a, b), Vector3(0.13, 0.014, a.distance_to(b)), BELT)
	# Where it wraps the wheels: arcs of short segments on the far sides.
	for w: Array in [[bull, BULL_R, -along], [d, DRIVE_R, along]]:
		var c: Vector3 = w[0]
		var r: float = w[1] + 0.012
		var away: Vector3 = w[2]
		var pts: Array[Vector3] = []
		for k in 13:
			var t := float(k) / 12.0
			var a := lerpf(-PI * 0.5, PI * 0.5, t)
			pts.append(c + (n * sin(a) + away * cos(a)) * r)
		for k in 12:
			MeshKit.add_box(st, WaterworksBuilder._belt_xf(pts[k], pts[k + 1]), Vector3(0.13, 0.014, pts[k].distance_to(pts[k + 1]) + 0.01), BELT)
	return MeshKit.finish(st)
