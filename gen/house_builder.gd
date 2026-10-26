class_name HouseBuilder
extends RefCounted
## The enterable Homestead cabin: log walls with real door and window openings,
## plank floors, a ramp staircase along the back wall, simple furniture, and a
## roof. Upgrades change the mesh: boarded-up windows, iron-banded and
## stone-skirted walls (reinforced), a second storey with a front balcony, and a
## third "lookout" storey with a flat, railed roof deck.
## Local space: origin on the ground at the cabin centre, front (door) faces -Z.

const W := 7.0
const D := 5.5
const H := 3.2
const T := 0.3
const LOG := 0.4
const PORCH_DEPTH := 2.2
## Stair ramp along the back wall: rises from x = STAIR_LOW_X up to the left wall.
const STAIR_LOW_X := 2.4
const STAIR_Z0 := 1.35
## House turret mounts, two per storey: porch corners, balcony corners, roof deck.
const MOUNTS: Array[Vector3] = [
	Vector3(-2.3, 0.3, -D * 0.5 - 1.3), Vector3(2.3, 0.3, -D * 0.5 - 1.3),
	Vector3(-2.6, H + 0.1, -D * 0.5 - 1.2), Vector3(2.6, H + 0.1, -D * 0.5 - 1.2),
	Vector3(-2.3, H * 3.0 + 0.15, -1.2), Vector3(2.3, H * 3.0 + 0.15, -1.2),
]


static func mount_count(floors: int) -> int:
	return clampi(floors, 1, 3) * 2


## Where the ledger desk stands (ground floor, front right corner, facing the room).
static func ledger_position() -> Vector3:
	return Vector3(2.5, 0.1, -1.7)


## collision_only skips purely visual bits (tread lines) that would snag a walking player.
static func build(seed_value: int, team: Color, floors: int, boarded: bool, reinforced: bool, collision_only: bool = false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	floors = clampi(floors, 1, 3)
	var hw := W * 0.5
	var hd := D * 0.5
	for f in floors:
		var y0 := H * f
		var top := f == floors - 1
		# Front wall: door below, balcony door on storey 2, lookout slits on 3.
		var front: Array = []
		if f == 0:
			front = [[-0.7, 0.7, 0.0, 2.4], [-2.7, -1.7, 1.2, 2.4], [1.7, 2.7, 1.2, 2.4]]
		elif f == 1:
			front = [[-0.7, 0.7, 0.0, 2.4], [-2.7, -1.7, 1.2, 2.4], [1.7, 2.7, 1.2, 2.4]]
		else:
			front = [[-2.6, -0.6, 1.2, 2.4], [0.6, 2.6, 1.2, 2.4]]
		var side: Array = [[-0.6, 0.6, 1.2, 2.4]]
		var back: Array = [] if f < floors - 1 or floors == 3 else [[-0.6, 0.6, 1.2, 2.4]]
		_wall(st, rng, Vector3.RIGHT, -hd, -hw - T * 0.5, hw + T * 0.5, y0, front)
		_wall(st, rng, Vector3.RIGHT, hd, -hw - T * 0.5, hw + T * 0.5, y0, back)
		_wall(st, rng, Vector3.BACK, -hw, -hd, hd, y0, side)
		_wall(st, rng, Vector3.BACK, hw, -hd, hd, y0, side)
		# Floor of this storey.
		if f == 0:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(W - T, 0.1, D - T), Palette.WOOD_DARK, 0.02, rng)
		else:
			_floor_with_hole(st, rng, y0)
		# Stairs up to the next storey (or the roof deck on a 3-storey house).
		if not top or floors == 3:
			_stairs(st, rng, y0, not collision_only)
		if boarded:
			for o: Array in front:
				if float(o[2]) > 0.5:
					_boards(st, rng, Vector3.RIGHT, -hd - T * 0.5 - 0.06, o, y0, -1.0)
			for o: Array in side:
				_boards(st, rng, Vector3.BACK, -hw - T * 0.5 - 0.06, o, y0, -1.0)
				_boards(st, rng, Vector3.BACK, hw + T * 0.5 + 0.06, o, y0, 1.0)
			for o: Array in back:
				_boards(st, rng, Vector3.RIGHT, hd + T * 0.5 + 0.06, o, y0, 1.0)
		if reinforced:
			for cx: float in [-hw, hw]:
				for cz: float in [-hd, hd]:
					MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx, y0 + H * 0.5, cz)),
							Vector3(T + 0.12, H, T + 0.12), Palette.METAL.darkened(0.1), 0.0, null)
			for band_y: float in [y0 + 0.6, y0 + H - 0.5]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, band_y, hd + T * 0.5 + 0.03)), Vector3(W + T, 0.14, 0.04), Palette.METAL)
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(-hw - T * 0.5 - 0.03, band_y, 0)), Vector3(0.04, 0.14, D), Palette.METAL)
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(hw + T * 0.5 + 0.03, band_y, 0)), Vector3(0.04, 0.14, D), Palette.METAL)
	if reinforced:
		# Stone skirt on the sides and back (the porch covers the front).
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.3, hd + 0.3)), Vector3(W + 1.0, 0.6, 0.5), Palette.ROCK_B, 0.05, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-hw - 0.3, 0.3, 0)), Vector3(0.5, 0.6, D + 0.6), Palette.ROCK_B, 0.05, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(hw + 0.3, 0.3, 0)), Vector3(0.5, 0.6, D + 0.6), Palette.ROCK_B, 0.05, rng)
	var roof_y := H * floors
	if floors == 3:
		_roof_deck(st, rng, roof_y)
	else:
		_pitched_roof(st, rng, roof_y)
	_porch(st, rng, floors >= 2)
	_furniture(st, rng, floors)
	# Flag pole with team colour.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-hw - 0.8, 3.0, -hd - 1.8)), 0.06, 0.05, 6.0, 6, Palette.METAL)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-hw - 0.8, 6.05, -hd - 1.8)), Vector3.ONE * 0.09, 3, 8, Color("#D6A74A"))
	if not collision_only:
		_window_dressing(st, rng, floors, boarded)
		_yard_details(st, rng)
	return MeshKit.finish(st)


## Where the flag cloth hangs from (house space), and the chimney top (smoke).
static func flag_anchor() -> Vector3:
	return Vector3(-W * 0.5 - 0.8, 5.75, -D * 0.5 - 1.8)


## Rocking chair on the porch: origin at the rocker's contact point.
static func chair_spot() -> Vector3:
	return Vector3(-W * 0.5 + 1.0, 0.3, -D * 0.5 - 1.0)


static func rocking_chair() -> ArrayMesh:
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	for s: float in [-1.0, 1.0]:
		# Curved rocker made of short limbs.
		var prev := Vector3(s * 0.26, 0.12, -0.45)
		for i in 9:
			var t := float(i + 1) / 9.0
			var z := lerpf(-0.45, 0.5, t)
			var p := Vector3(s * 0.26, 0.04 + pow(z * 1.6, 2.0) * 0.12, z)
			MeshKit.add_limb(st, prev, p, 0.03, Palette.WOOD_DARK, 5)
			prev = p
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * 0.26, 0.28, -0.15)), Vector3(0.05, 0.4, 0.05), wood)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * 0.26, 0.28, 0.2)), Vector3(0.05, 0.4, 0.05), wood)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(s * 0.26, 0.85, 0.3)), Vector3(0.05, 0.9, 0.05), wood)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * 0.26, 0.68, 0.0)), Vector3(0.07, 0.04, 0.55), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.48, 0.02)), Vector3(0.6, 0.06, 0.55), wood)
	for i in 5:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(-0.2 + i * 0.1, 0.85, 0.3)), Vector3(0.05, 0.7, 0.03), wood.lightened(0.08))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.25, 0.4)), Vector3(0.6, 0.07, 0.05), Palette.WOOD_DARK)
	# A folded red blanket over the arm, and a cushion.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.52, 0.02)), Vector3(0.5, 0.04, 0.45), Color("#B8352A"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.28, 0.6, -0.05)), Vector3(0.1, 0.22, 0.3), Color("#E0C890"))
	return MeshKit.finish(st)


## Where a player stands after a canyon fall: on the porch, right of the door,
## clear of the rocking chair (house space, feet on the boards).
static func porch_spawn() -> Vector3:
	return Vector3(1.9, 0.32, -D * 0.5 - PORCH_DEPTH * 0.5 - 0.1)


static func chimney_top(floors: int) -> Vector3:
	return Vector3(W * 0.3, H * clampi(floors, 1, 3) + 2.95, D * 0.15)


## Shutters beside the front windows and a flower box under each.
static func _window_dressing(st: SurfaceTool, rng: RandomNumberGenerator, floors: int, boarded: bool) -> void:
	var hd := D * 0.5
	for f in mini(floors, 2):
		var y0 := H * f
		for wx: float in [-2.2, 2.2]:
			for s: float in [-1.0, 1.0]:
				var x := wx + s * 0.68
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.25), Vector3(x, y0 + 1.8, -hd - 0.2)), Vector3(0.36, 1.25, 0.05), Color("#3E6A5A") if f == 0 else Color("#5A4A7A"))
				for k in 4:
					MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.25), Vector3(x, y0 + 1.35 + k * 0.3, -hd - 0.23)), Vector3(0.3, 0.04, 0.02), Color("#2E5246"))
			if f == 0 and not boarded:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(wx, y0 + 1.12, -hd - 0.3)), Vector3(1.0, 0.18, 0.22), Palette.WOOD_DARK)
				for k in 5:
					var c: Color = [Color("#E0483C"), Color("#FFD23F"), Color("#F2E3C2"), Color("#C97ABF")][rng.randi() % 4]
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(wx - 0.4 + k * 0.2, y0 + 1.27, -hd - 0.3)), Vector3(0.08, 0.06, 0.08), 3, 6, Palette.CACTUS)
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(wx - 0.4 + k * 0.2, y0 + 1.33, -hd - 0.33)), Vector3.ONE * 0.04, 3, 6, c)


## A horseshoe over the door, a welcome mat, a washtub and a woodpile.
static func _yard_details(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var hd := D * 0.5
	for k in 7:
		var a := PI * (0.15 + 0.7 * k / 6.0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.14, 2.62 + sin(a) * 0.14 - 0.14, -hd - 0.2)), Vector3.ONE * 0.035, 3, 6, Palette.METAL.lightened(0.15))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.31, -hd - 0.7)), Vector3(1.0, 0.02, 0.55), Color("#B8352A"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.32, -hd - 0.7)), Vector3(0.8, 0.02, 0.06), Color("#F2E3C2"))
	# Washtub by the porch steps.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(W * 0.5 + 0.7, 0.25, -hd + 0.6)), 0.4, 0.32, 0.5, 14, Palette.METAL.lightened(0.1))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(W * 0.5 + 0.7, 0.46, -hd + 0.6)), 0.36, 0.36, 0.02, 14, Palette.SKY_TOP, false, 0.3)
	# Woodpile against the side wall.
	for r in 3:
		for k in 5 - r:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-W * 0.5 - 0.35, 0.15 + r * 0.26, -1.2 + k * 0.28 + r * 0.14)), 0.13, 0.13, 0.9, 7,
					Palette.WOOD.lightened(rng.randf() * 0.1))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-W * 0.5 - 0.35, 0.15 + r * 0.26, -1.2 + k * 0.28 + r * 0.14 - 0.0) + Vector3(0, 0, 0)), 0.1, 0.1, 0.92, 7, Color("#D9B27A"), false)


## One log wall. `along` is the wall direction (RIGHT for front/back, BACK for the
## sides), `fixed` its position on the other axis, a0..a1 its extent. Openings are
## [along_from, along_to, y_from, y_to] relative to the storey floor.
static func _wall(st: SurfaceTool, rng: RandomNumberGenerator, along: Vector3, fixed: float,
		a0: float, a1: float, y0: float, openings: Array) -> void:
	var rows := int(round(H / LOG))
	for r in rows:
		var ry := r * LOG + LOG * 0.5
		var pieces: Array = [[a0, a1]]
		for o: Array in openings:
			if ry > float(o[2]) and ry < float(o[3]):
				var next: Array = []
				for p: Array in pieces:
					if float(o[1]) <= float(p[0]) or float(o[0]) >= float(p[1]):
						next.append(p)
						continue
					if float(o[0]) > float(p[0]):
						next.append([p[0], o[0]])
					if float(o[1]) < float(p[1]):
						next.append([o[1], p[1]])
				pieces = next
		var shade := Palette.WOOD if r % 2 == 0 else Palette.WOOD.darkened(0.08)
		for p: Array in pieces:
			var len := float(p[1]) - float(p[0])
			if len < 0.05:
				continue
			var mid := (float(p[0]) + float(p[1])) * 0.5
			var pos := Vector3(mid, y0 + ry, fixed) if along == Vector3.RIGHT else Vector3(fixed, y0 + ry, mid)
			var size := Vector3(len, LOG, T) if along == Vector3.RIGHT else Vector3(T, LOG, len)
			MeshKit.add_box(st, Transform3D(Basis(), pos), size, shade, 0.02, rng)
	# Frames around the openings.
	for o: Array in openings:
		var mid := (float(o[0]) + float(o[1])) * 0.5
		var top_y := y0 + float(o[3])
		var lintel_pos := Vector3(mid, top_y + 0.06, fixed) if along == Vector3.RIGHT else Vector3(fixed, top_y + 0.06, mid)
		var lintel := Vector3(float(o[1]) - float(o[0]) + 0.2, 0.12, T + 0.08) if along == Vector3.RIGHT \
				else Vector3(T + 0.08, 0.12, float(o[1]) - float(o[0]) + 0.2)
		MeshKit.add_box(st, Transform3D(Basis(), lintel_pos), lintel, Palette.WOOD_DARK)


static func _floor_with_hole(st: SurfaceTool, rng: RandomNumberGenerator, y: float) -> void:
	var hw := W * 0.5 - T * 0.5
	var hd := D * 0.5 - T * 0.5
	var c := Palette.WOOD_DARK
	# Front part, full width.
	var front_len := STAIR_Z0 + hd
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, -hd + front_len * 0.5)), Vector3(W - T, 0.2, front_len), c, 0.02, rng)
	# Back strip beside the stair hole.
	var hole_end := 1.0
	MeshKit.add_box(st, Transform3D(Basis(), Vector3((hole_end + hw) * 0.5, y, (STAIR_Z0 + hd) * 0.5)),
			Vector3(hw - hole_end, 0.2, hd - STAIR_Z0), c, 0.02, rng)
	# Railing along the hole edge.
	# (leaves a gap at the top of the stairs, by the left wall)
	var rail_from := -hw + 1.5
	MeshKit.add_box(st, Transform3D(Basis(), Vector3((rail_from + hole_end) * 0.5, y + 0.9, STAIR_Z0 - 0.05)),
			Vector3(hole_end - rail_from, 0.08, 0.08), Palette.WOOD)
	for px: float in [rail_from, -0.5, hole_end]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(px, y + 0.45, STAIR_Z0 - 0.05)), Vector3(0.08, 0.9, 0.08), Palette.WOOD)


## A plank ramp with cleats, from (STAIR_LOW_X, y0) up to the left wall at y0 + H.
static func _stairs(st: SurfaceTool, rng: RandomNumberGenerator, y0: float, treads: bool) -> void:
	var hw := W * 0.5 - T * 0.5
	var hd := D * 0.5 - T * 0.5
	var land := 0.9 # top landing by the left wall, so you step off level with the floor
	var run := STAIR_LOW_X + hw - land
	var angle := atan2(H, run)
	var len := sqrt(run * run + H * H)
	var z := (STAIR_Z0 + hd) * 0.5 + 0.05
	var width := hd - STAIR_Z0 - 0.05
	# Floors are 0.1 above their storey line, so the ramp runs floor top to floor top.
	var center := Vector3((STAIR_LOW_X - hw + land) * 0.5, y0 + 0.1 + H * 0.5, z)
	var b := Basis(Vector3.BACK, -angle) # high end toward -X (the left wall)
	MeshKit.add_box(st, Transform3D(b, center - b.y * 0.06), Vector3(len, 0.12, width), Palette.WOOD, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-hw + land * 0.5, y0 + H, z)), Vector3(land, 0.2, width), Palette.WOOD_DARK, 0.02, rng)
	var steps := 9 if treads else 0
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var p := Vector3(lerpf(STAIR_LOW_X, -hw + land, t), y0 + 0.1 + H * t, z)
		# Painted-on tread lines (nearly flush, so the ramp stays smooth to walk on).
		MeshKit.add_box(st, Transform3D(b, p - b.y * 0.008), Vector3(0.1, 0.02, width + 0.01), Palette.WOOD_DARK)


## Planks nailed over a window opening.
static func _boards(st: SurfaceTool, rng: RandomNumberGenerator, along: Vector3, fixed: float, o: Array, y0: float, _out: float) -> void:
	var a0 := float(o[0]) - 0.15
	var a1 := float(o[1]) + 0.15
	var mid := (a0 + a1) * 0.5
	var y_from := y0 + float(o[2])
	var y_to := y0 + float(o[3])
	var n := 3
	for i in n:
		var yy := lerpf(y_from + 0.2, y_to - 0.2, float(i) / float(n - 1))
		var tilt := rng.randf_range(-0.12, 0.12)
		var basis := Basis()
		if along == Vector3.RIGHT:
			basis = Basis(Vector3.BACK, tilt)
			MeshKit.add_box(st, Transform3D(basis, Vector3(mid, yy, fixed)), Vector3(a1 - a0, 0.22, 0.06), Palette.WOOD.lightened(0.08), 0.02, rng)
		else:
			basis = Basis(Vector3.RIGHT, tilt)
			MeshKit.add_box(st, Transform3D(basis, Vector3(fixed, yy, mid)), Vector3(0.06, 0.22, a1 - a0), Palette.WOOD.lightened(0.08), 0.02, rng)


static func _pitched_roof(st: SurfaceTool, rng: RandomNumberGenerator, h: float) -> void:
	# Ceiling so the inside has a lid.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h + 0.05, 0)), Vector3(W + T, 0.1, D + T), Palette.WOOD_DARK, 0.02, rng)
	var roof_angle := deg_to_rad(28.0)
	var half_span := W * 0.5 + 0.6
	var slab_len := half_span / cos(roof_angle)
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -side * roof_angle)
		var center := Vector3(side * half_span * 0.5, h + tan(roof_angle) * half_span * 0.5 + 0.1, 0)
		MeshKit.add_box(st, Transform3D(b, center), Vector3(slab_len, 0.2, D + 1.6), Palette.ROOF.darkened(0.15), 0.02, rng)
		var rows := 7
		for r in rows:
			var t := (float(r) + 0.5) / rows
			var along := Vector3(side * half_span * (1.0 - t), h + tan(roof_angle) * half_span * t + 0.22, 0)
			var shade := Palette.ROOF.darkened(0.05 * (r % 2)).lerp(Palette.ROOF.lightened(0.08), rng.randf() * 0.4)
			MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, side * 0.05), along), Vector3(slab_len / rows * 1.2, 0.06, D + 1.6), shade, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h + tan(roof_angle) * half_span + 0.15, 0)), Vector3(0.3, 0.16, D + 1.7), Palette.WOOD_DARK)
	for gz: float in [-D * 0.5, D * 0.5]:
		var peak := Vector3(0, h + tan(roof_angle) * (W * 0.5), gz)
		var n := Vector3(0, 0, signf(gz))
		MeshKit.tri(st, Vector3(-W * 0.5, h, gz), Vector3(W * 0.5, h, gz), peak, n, n, n,
				MeshKit.vcol(Palette.WOOD.lightened(0.05)), n)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(W * 0.3, h + 1.8, D * 0.15)), Vector3(0.7, 2.2, 0.7), Palette.ROCK_B, 0.04, rng)


## Flat lookout deck with a railing and the stair hatch at the back.
static func _roof_deck(st: SurfaceTool, rng: RandomNumberGenerator, h: float) -> void:
	_floor_with_hole(st, rng, h)
	var hw := W * 0.5 + T * 0.5
	var hd := D * 0.5 + T * 0.5
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * hw, h + 0.55, 0)), Vector3(0.15, 1.1, D + T), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h + 0.55, -hd)), Vector3(W + T, 1.1, 0.15), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h + 0.55, hd)), Vector3(W + T, 1.1, 0.15), Palette.WOOD)
	# Little canopy posts and a lantern glow on the corners.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * hw, h + 1.3, sz * hd)), Vector3(0.22, 0.4, 0.22), Palette.GLOW_YELLOW, 0.0, null, 0.6)


## Porch along the front; with 2+ storeys its roof becomes a railed balcony.
static func _porch(st: SurfaceTool, rng: RandomNumberGenerator, balcony: bool) -> void:
	var hd := D * 0.5
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, -hd - PORCH_DEPTH * 0.5 - 0.1)), Vector3(W, 0.3, PORCH_DEPTH), Palette.WOOD_DARK, 0.03, rng)
	var post_h := H if balcony else 2.3
	for px: float in [-W * 0.5 + 0.2, -1.0, 1.0, W * 0.5 - 0.2]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(px, 0.3 + post_h * 0.5 - 0.15, -hd - PORCH_DEPTH + 0.1)),
				Vector3(0.18, post_h - 0.3, 0.18), Palette.WOOD, 0.02, rng)
	if balcony:
		var bz := -hd - PORCH_DEPTH * 0.5 - 0.1
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, H, bz)), Vector3(W, 0.2, PORCH_DEPTH + 0.2), Palette.WOOD_DARK, 0.03, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, H + 0.9, -hd - PORCH_DEPTH)), Vector3(W, 0.1, 0.1), Palette.WOOD)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * W * 0.5, H + 0.9, bz)), Vector3(0.1, 0.1, PORCH_DEPTH), Palette.WOOD)
		for i in 9:
			var x := lerpf(-W * 0.5 + 0.1, W * 0.5 - 0.1, float(i) / 8.0)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, H + 0.5, -hd - PORCH_DEPTH)), Vector3(0.07, 0.8, 0.07), Palette.WOOD)
	else:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0, 2.55, -hd - 1.2)),
				Vector3(W + 0.4, 0.15, 2.6), Palette.ROOF.darkened(0.1), 0.03, rng)


static func _furniture(st: SurfaceTool, rng: RandomNumberGenerator, floors: int) -> void:
	# Ground floor: table and stools, stove in the back corner, a rug.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-1.6, 0.11, -0.6)), Vector3(2.0, 0.02, 1.4), Palette.TEAM_WEST.darkened(0.3))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-1.6, 0.8, -0.6)), Vector3(1.4, 0.08, 0.8), Palette.WOOD, 0.02, rng)
	for lx: float in [-2.2, -1.0]:
		for lz: float in [-0.95, -0.25]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(lx, 0.45, lz)), Vector3(0.08, 0.7, 0.08), Palette.WOOD_DARK)
	for sx: float in [-2.6, -0.6]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(sx, 0.32, -0.6)), 0.2, 0.2, 0.45, 8, Palette.WOOD_DARK)
	# Stove against the right wall (clear of the stair foot).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.85, 0.55, 0.1)), Vector3(0.8, 0.9, 0.9), Palette.METAL.darkened(0.3), 0.02, rng)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(3.0, 1.9, 0.1)), 0.12, 0.12, 1.4, 6, Palette.METAL.darkened(0.2))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.44, 0.75, 0.1)), Vector3(0.05, 0.2, 0.3), Color("#FF7A2E"), 0.0, null, 0.7)
	if floors >= 2:
		# Bed and a chest on the second floor.
		var y := H + 0.1
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.2, y + 0.3, -1.2)), Vector3(1.6, 0.4, 2.0), Palette.WOOD_DARK, 0.02, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.2, y + 0.55, -1.0)), Vector3(1.4, 0.15, 1.6), Palette.BONE)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.2, y + 0.6, -1.95)), Vector3(1.2, 0.2, 0.4), Color("#E8E2D0"))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-2.4, y + 0.35, -1.6)), Vector3(1.0, 0.6, 0.6), Palette.WOOD, 0.02, rng)
	if floors >= 3:
		var y3 := H * 2.0 + 0.1
		for c in 3:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(1.8 + c * 0.6, y3 + 0.35, -1.5 + (c % 2) * 0.7)),
					Vector3(0.7, 0.7, 0.7), Palette.WOOD, 0.03, rng)
