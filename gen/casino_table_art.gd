extends RefCounted
## The airship casino's tables, built from code (Logan, Nov 2026: "the tables
## could be better, especially baccarat"):
##   - a shaped felt bed (racetrack for baccarat, half-moon for blackjack,
##     rounded for the rest) printed with the game's layout
##     (assets/airship/casino/felt_<kind>.png, tools/props/make_felts.py)
##   - a padded leather armrest round it, tufted with buttons
##   - a brass band and a mahogany apron with a cove
##   - turned pedestals with brass collars
##   - the dealer's kit: chip tray, card shoe, discard rack, baccarat paddle
##   - an arched sign on brass posts with the game's name in gold
## The felt stays at TOP (the games' cups, beetles and wheel sit on it). Wood
## and brass use the shared toon material, so the deck painting reaches them;
## leather, felt and chips keep their own materials.
## Local axes as the games use them: players stand on -Z, the dealer on +Z.

const TOP := 0.975
const FELT := "res://assets/airship/casino/felt_%s.png"
const TOON_TEX: Shader = preload("res://shaders/toon_tex.gdshader")

const KINDS := {
	"baccarat": {"shape": "stadium", "w": 2.4, "d": 1.24, "rail": "#2E1A12", "wood": "#5B2C1A", "board": "#4A1016",
		"legs": [-0.7, 0.7], "tray": true, "shoe": true, "paddle": true},
	"blackjack": {"shape": "halfmoon", "w": 2.1, "d": 1.1, "rail": "#3E2416", "wood": "#5B2C1A", "board": "#1F3A2A",
		"legs": [-0.55, 0.55], "tray": true, "shoe": true},
	"roulette": {"shape": "rounded", "w": 2.6, "d": 1.1, "radius": 0.16, "rail": "#3E2416", "wood": "#5B2C1A", "board": "#1F3A2A",
		"legs": [-0.85, 0.85], "tray": true},
	"shell": {"shape": "rounded", "w": 1.8, "d": 1.0, "radius": 0.3, "rail": "#3E2416", "wood": "#5B2C1A", "board": "#1F3A2A",
		"legs": [0.0]},
	"race": {"shape": "rounded", "w": 2.1, "d": 1.3, "radius": 0.18, "rail": "#3E2416", "wood": "#5B2C1A", "board": "#1F3A2A",
		"legs": [-0.6, 0.6]},
}
const BRASS := Color("#C9A048")
const BRASS_DK := Color("#8A6526")


## Builds the table under `parent` (the CasinoTable node) and returns its size
## (felt width and depth) for the collision box.
static func build(parent: Node3D, kind: String, title: String) -> Vector2:
	var k: Dictionary = KINDS.get(kind, KINDS["shell"])
	var w: float = k["w"]
	var d: float = k["d"]
	var outline := _outline(k)
	var normals := _normals(outline)
	# Wood and brass (deck-painted), and the leather and chips (kept as they are).
	var wood := MeshKit.begin()
	var leather := MeshKit.begin()
	var wood_col := Color(str(k["wood"]))
	var rail_col := Color(str(k["rail"]))
	# The padded armrest, the brass band under it, and the apron down to a cove.
	_sweep(leather, outline, normals, [Vector2(-0.006, TOP - 0.004), Vector2(0.0, TOP + 0.03), Vector2(0.02, TOP + 0.066),
			Vector2(0.062, TOP + 0.086), Vector2(0.102, TOP + 0.07), Vector2(0.126, TOP + 0.034), Vector2(0.132, TOP - 0.006)], rail_col)
	_sweep(wood, outline, normals, [Vector2(0.132, TOP - 0.006), Vector2(0.14, TOP - 0.012), Vector2(0.14, TOP - 0.036), Vector2(0.132, TOP - 0.042)], BRASS)
	_sweep(wood, outline, normals, [Vector2(0.132, TOP - 0.042), Vector2(0.128, TOP - 0.058), Vector2(0.124, TOP - 0.13),
			Vector2(0.112, TOP - 0.152), Vector2(0.09, TOP - 0.162), Vector2(0.084, TOP - 0.172)], wood_col)
	_sweep(wood, outline, normals, [Vector2(0.084, TOP - 0.172), Vector2(0.086, TOP - 0.178), Vector2(0.06, TOP - 0.184)], BRASS_DK)
	_cap(wood, outline, normals, 0.06, TOP - 0.184, wood_col.darkened(0.35), false)
	# Tufting: a button every 16 cm along the armrest's crown.
	var buttons := _along(outline, 0.16)
	for b: Array in buttons:
		var p: Vector2 = b[0]
		var n: Vector2 = b[1]
		var at := Vector3(p.x + n.x * 0.06, TOP + 0.084, p.y + n.y * 0.06)
		MeshKit.add_ellipsoid(leather, Transform3D(Basis(), at), Vector3(0.011, 0.005, 0.011), 3, 6, rail_col.darkened(0.45))
	# Pedestals: a turned column on a flared foot, with a brass collar.
	for lx: float in k["legs"]:
		var xf := Transform3D(Basis(), Vector3(lx, 0.0, 0.0 if k["shape"] != "halfmoon" else 0.08))
		MeshKit.lathe(wood, xf, [Vector2(0.21, 0.0), Vector2(0.21, 0.025), Vector2(0.17, 0.045), Vector2(0.09, 0.08), Vector2(0.06, 0.15),
				Vector2(0.055, 0.3), Vector2(0.08, 0.4), Vector2(0.06, 0.5), Vector2(0.05, 0.6), Vector2(0.065, TOP - 0.26),
				Vector2(0.13, TOP - 0.215), Vector2(0.16, TOP - 0.184)], 20, wood_col)
		MeshKit.add_cylinder(wood, xf * Transform3D(Basis(), Vector3(0, 0.395, 0)), 0.085, 0.085, 0.028, 20, BRASS)
		MeshKit.add_cylinder(wood, xf * Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.215, 0.215, 0.012, 24, BRASS_DK)
	# The dealer's kit on the +Z side.
	var chips := MeshKit.begin()
	if bool(k.get("tray", false)):
		_chip_tray(wood, chips, Vector3(0.0, TOP, d * 0.5 - 0.13), wood_col)
	if bool(k.get("shoe", false)):
		_shoe(wood, chips, Vector3(-0.55 if kind != "blackjack" else -0.6, TOP, d * 0.5 - 0.2), wood_col)
		_discard(wood, chips, Vector3(0.55 if kind != "blackjack" else 0.6, TOP, d * 0.5 - 0.18), wood_col)
	if bool(k.get("paddle", false)):
		_paddle(wood, Vector3(0.62, TOP, -0.02), wood_col)
	# The sign: an arched board on two brass posts behind the dealer.
	var board_col := Color(str(k["board"]))
	_sign(wood, leather, Vector3(0.0, TOP, d * 0.5 + 0.1), board_col)
	for part: Array in [[wood, Materials.toon(0.015)], [leather, Materials.toon_unique(0.015)], [chips, Materials.toon_unique(0.01)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(part[0])
		mi.material_override = part[1]
		parent.add_child(mi)
	parent.add_child(_felt_mesh(outline, kind, w, d))
	var label := Label3D.new()
	label.text = title.to_upper()
	label.font = load("res://assets/fonts/Rye-Regular.ttf") as Font
	label.font_size = 60
	label.width = 1.25 / 0.0026 # (long names wrap rather than run off the board)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.55)
	label.modulate = Color("#F0C860")
	label.pixel_size = 0.0034 if title.length() <= 9 else 0.0034 * 9.0 / title.length()
	label.position = Vector3(0, TOP + 0.36, d * 0.5 + 0.075)
	label.rotation.y = PI
	label.double_sided = false
	parent.add_child(label)
	return Vector2(w, d)


# ------------------------------------------------------------------ outlines

static func _outline(k: Dictionary) -> PackedVector2Array:
	var w: float = k["w"]
	var d: float = k["d"]
	var pts := PackedVector2Array()
	match str(k["shape"]):
		"stadium":
			var r := d * 0.5
			var cx := w * 0.5 - r
			for i in 25:
				var a := -PI * 0.5 + PI * i / 24.0
				pts.append(Vector2(cx + cos(a) * r, sin(a) * r))
			for i in 25:
				var a := PI * 0.5 + PI * i / 24.0
				pts.append(Vector2(-cx + cos(a) * r, sin(a) * r))
		"halfmoon":
			# The dealer's straight edge along +Z, the players' half ellipse toward -Z.
			for i in 41:
				var a := PI * i / 40.0
				pts.append(Vector2(cos(a) * w * 0.5, d * 0.5 - sin(a) * d))
			for i in range(1, 8):
				pts.append(Vector2(-w * 0.5 + w * i / 8.0, d * 0.5))
		_:
			var rr: float = k.get("radius", 0.15)
			var corners := [Vector2(w * 0.5 - rr, d * 0.5 - rr), Vector2(-w * 0.5 + rr, d * 0.5 - rr), Vector2(-w * 0.5 + rr, -d * 0.5 + rr), Vector2(w * 0.5 - rr, -d * 0.5 + rr)]
			var starts := [0.0, PI * 0.5, PI, PI * 1.5]
			for c in 4:
				for i in 9:
					var a: float = starts[c] + PI * 0.5 * i / 8.0
					pts.append((corners[c] as Vector2) + Vector2(cos(a), sin(a)) * rr)
	return pts


## Outward normals of a closed outline (x, z).
static func _normals(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ctr := Vector2.ZERO
	for p in pts:
		ctr += p
	ctr /= pts.size()
	for i in pts.size():
		var t := pts[(i + 1) % pts.size()] - pts[(i - 1 + pts.size()) % pts.size()]
		var n := Vector2(t.y, -t.x).normalized()
		if n.dot(pts[i] - ctr) < 0.0:
			n = -n
		out.append(n)
	return out


## Points every `step` metres round the outline, with their normals.
static func _along(pts: PackedVector2Array, step: float) -> Array:
	var normals := _normals(pts)
	var out: Array = []
	var carry := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var len := a.distance_to(b)
		var t := carry
		while t < len:
			var f := t / len
			out.append([a.lerp(b, f), normals[i].lerp(normals[(i + 1) % pts.size()], f).normalized()])
			t += step
		carry = t - len
	return out


# ------------------------------------------------------------------ sweeps

## Sweeps a profile (offset out from the felt's edge, height) round the outline,
## smooth-shaded from the profile's own curve.
static func _sweep(st: SurfaceTool, pts: PackedVector2Array, normals: PackedVector2Array, profile: Array, color: Color) -> void:
	var col := MeshKit.vcol(color)
	var n := pts.size()
	var m := profile.size()
	var pn: Array = []
	for j in m:
		var prev: Vector2 = profile[maxi(j - 1, 0)]
		var next: Vector2 = profile[mini(j + 1, m - 1)]
		var t := next - prev
		pn.append(Vector2(-t.y, t.x).normalized()) # (the profile runs inside to outside, over the top)
	for i in n:
		var i1 := (i + 1) % n
		for j in m - 1:
			var corners: Array = []
			var nors: Array = []
			for c: Array in [[i, j], [i1, j], [i1, j + 1], [i, j + 1]]:
				var p := pts[c[0]]
				var o := normals[c[0]]
				var pr: Vector2 = profile[c[1]]
				corners.append(Vector3(p.x + o.x * pr.x, pr.y, p.y + o.y * pr.x))
				var q: Vector2 = pn[c[1]]
				nors.append(Vector3(o.x * q.x, q.y, o.y * q.x).normalized())
			var face := (nors[0] + nors[1] + nors[2] + nors[3]) as Vector3
			MeshKit.tri(st, corners[0], corners[1], corners[2], nors[0], nors[1], nors[2], col, face.normalized())
			MeshKit.tri(st, corners[0], corners[2], corners[3], nors[0], nors[2], nors[3], col, face.normalized())


## A flat cap inside the outline (offset `inset` out), at height y.
static func _cap(st: SurfaceTool, pts: PackedVector2Array, normals: PackedVector2Array, inset: float, y: float, color: Color, up: bool) -> void:
	var col := MeshKit.vcol(color)
	var poly := PackedVector2Array()
	for i in pts.size():
		poly.append(pts[i] + normals[i] * inset)
	var idx := Geometry2D.triangulate_polygon(poly)
	var nrm := Vector3.UP if up else Vector3.DOWN
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var c := poly[idx[t + 2]]
		MeshKit.tri(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), nrm, nrm, nrm, col, nrm)


## The printed felt bed: the outline's polygon at TOP, its layout image mapped
## so the image's top is the dealer's (+Z) edge and its left the players' left.
static func _felt_mesh(pts: PackedVector2Array, kind: String, w: float, d: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	for t in range(0, idx.size(), 3):
		var tri := [pts[idx[t]], pts[idx[t + 1]], pts[idx[t + 2]]]
		# Up-facing (Godot's front faces wind clockwise seen from the front).
		var a: Vector2 = tri[0]
		var b: Vector2 = tri[1]
		var c: Vector2 = tri[2]
		if (Vector3(b.x - a.x, 0, b.y - a.y)).cross(Vector3(c.x - a.x, 0, c.y - a.y)).y > 0.0:
			tri = [a, c, b]
		for p: Vector2 in tri:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((w * 0.5 - p.x) / w, (d * 0.5 - p.y) / d))
			st.add_vertex(Vector3(p.x, TOP, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = TOON_TEX
	var path := FELT % kind
	if ResourceLoader.exists(path):
		mat.set_shader_parameter("albedo_tex", load(path))
	mat.set_shader_parameter("saturation", 1.1)
	mat.set_shader_parameter("brightness", 1.35) # (flat to the sky, the felt reads dim under the toon ramp)
	mi.material_override = mat
	return mi


# ------------------------------------------------------------------ the dealer's kit

static func _chip_tray(wood: SurfaceTool, chips: SurfaceTool, at: Vector3, wood_col: Color) -> void:
	var w := 0.66
	var dd := 0.15
	MeshKit.add_box(wood, Transform3D(Basis(), at + Vector3(0, 0.012, 0)), Vector3(w, 0.024, dd), wood_col.darkened(0.15), 0.0)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(wood, Transform3D(Basis(), at + Vector3(0, 0.03, side * (dd * 0.5 - 0.008))), Vector3(w, 0.036, 0.016), wood_col, 0.0)
		MeshKit.add_box(wood, Transform3D(Basis(), at + Vector3(side * (w * 0.5 - 0.008), 0.03, 0)), Vector3(0.016, 0.036, dd), wood_col, 0.0)
	var cols := [Color("#C9302C"), Color("#2E6FA8"), Color("#2E7D32"), Color("#1E1A18"), Color("#EDE3CF"), Color("#C9A048")]
	for c in 6:
		var x := -w * 0.5 + 0.06 + c * (w - 0.12) / 5.0
		for row in 2:
			var z := (row - 0.5) * 0.06
			var h := 0.03 + 0.012 * ((c + row) % 3)
			MeshKit.add_cylinder(chips, Transform3D(Basis(), at + Vector3(x, 0.024 + h * 0.5, z)), 0.021, 0.021, h, 12, cols[c])
			MeshKit.add_cylinder(chips, Transform3D(Basis(), at + Vector3(x, 0.024 + h + 0.0015, z)), 0.016, 0.016, 0.003, 12, Color("#F4ECDA"))


static func _shoe(wood: SurfaceTool, chips: SurfaceTool, at: Vector3, wood_col: Color) -> void:
	# A wooden card shoe, nose toward the players, with a brass face plate and the deck showing.
	var b := Basis(Vector3.UP, 0.25)
	var xf := Transform3D(b, at)
	MeshKit.add_box(wood, xf * Transform3D(Basis(), Vector3(0, 0.045, 0)), Vector3(0.14, 0.09, 0.26), wood_col.darkened(0.1), 0.0)
	MeshKit.add_box(wood, xf * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.085, -0.12)), Vector3(0.142, 0.06, 0.012), BRASS, 0.0)
	for i in 6:
		MeshKit.add_box(chips, xf * Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, 0.07 + i * 0.002, -0.06 + i * 0.012)), Vector3(0.1, 0.002, 0.14), Color("#F4ECDA"), 0.0)
	MeshKit.add_box(chips, xf * Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, 0.084, 0.012)), Vector3(0.1, 0.002, 0.14), Color("#8E2A24"), 0.0)


static func _discard(wood: SurfaceTool, chips: SurfaceTool, at: Vector3, wood_col: Color) -> void:
	MeshKit.add_box(wood, Transform3D(Basis(), at + Vector3(0, 0.006, 0)), Vector3(0.12, 0.012, 0.16), wood_col.darkened(0.15), 0.0)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(wood, Transform3D(Basis(), at + Vector3(side * 0.055, 0.04, 0)), Vector3(0.01, 0.07, 0.16), BRASS, 0.0)
	for i in 8:
		MeshKit.add_box(chips, Transform3D(Basis(Vector3.UP, (i % 3 - 1) * 0.04), at + Vector3(0, 0.014 + i * 0.003, 0)), Vector3(0.09, 0.0025, 0.13), Color("#F4ECDA") if i < 7 else Color("#8E2A24"), 0.0)


static func _paddle(wood: SurfaceTool, at: Vector3, wood_col: Color) -> void:
	# The croupier's long paddle lying across the felt.
	var b := Basis(Vector3.UP, 0.35)
	var xf := Transform3D(b, at + Vector3(0, 0.006, 0))
	MeshKit.add_box(wood, xf, Vector3(0.016, 0.012, 0.9), wood_col.lightened(0.15), 0.0)
	MeshKit.add_box(wood, xf * Transform3D(Basis(), Vector3(0, 0.0, -0.48)), Vector3(0.11, 0.008, 0.07), wood_col.lightened(0.2), 0.0)
	MeshKit.add_box(wood, xf * Transform3D(Basis(), Vector3(0, 0.0, 0.43)), Vector3(0.024, 0.016, 0.06), BRASS, 0.0)


static func _sign(wood: SurfaceTool, paint: SurfaceTool, at: Vector3, board: Color) -> void:
	# Two brass posts with ball finials, and an arched board between them.
	for sx: float in [-1.0, 1.0]:
		var px := at + Vector3(sx * 0.72, 0, 0)
		MeshKit.add_cylinder(wood, Transform3D(Basis(), px + Vector3(0, 0.28, 0)), 0.018, 0.018, 0.56, 10, BRASS)
		MeshKit.add_ellipsoid(wood, Transform3D(Basis(), px + Vector3(0, 0.58, 0)), Vector3(0.032, 0.032, 0.032), 4, 8, BRASS)
	var w := 1.4
	var h := 0.3
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		pts.append(Vector2(cos(a) * w * 0.5, h * 0.6 + sin(a) * h * 0.32))
	pts.append(Vector2(-w * 0.5, 0.0))
	pts.append(Vector2(w * 0.5, 0.0))
	var y0 := 0.2
	var thick := 0.035
	var frame := PackedVector2Array()
	var ctr := Vector2(0, h * 0.4)
	for p in pts:
		frame.append(ctr + (p - ctr) * 1.0)
	# The board (front face toward the players, -Z), a gold frame round it.
	_slab(paint, pts, at + Vector3(0, y0, 0), thick, board)
	var rim := PackedVector2Array()
	for p in pts:
		rim.append(ctr + (p - ctr) * 1.06 + Vector2(0, -0.012))
	_slab(wood, rim, at + Vector3(0, y0, 0.012), thick * 0.6, BRASS)


## An extruded flat shape in the XY plane (front face toward -Z).
static func _slab(st: SurfaceTool, pts: PackedVector2Array, at: Vector3, thick: float, color: Color) -> void:
	var col := MeshKit.vcol(color)
	var idx := Geometry2D.triangulate_polygon(pts)
	for face: float in [-1.0, 1.0]:
		var nrm := Vector3(0, 0, face)
		var z := at.z + face * thick * 0.5
		for t in range(0, idx.size(), 3):
			var a := pts[idx[t]]
			var b := pts[idx[t + 1]]
			var c := pts[idx[t + 2]]
			MeshKit.tri(st, Vector3(at.x + a.x, at.y + a.y, z), Vector3(at.x + b.x, at.y + b.y, z), Vector3(at.x + c.x, at.y + c.y, z), nrm, nrm, nrm, col, nrm)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var e := b - a
		var nrm := Vector3(e.y, -e.x, 0).normalized()
		var ctr := Vector2.ZERO
		for p in pts:
			ctr += p
		ctr /= pts.size()
		if Vector2(nrm.x, nrm.y).dot((a + b) * 0.5 - ctr) < 0.0:
			nrm = -nrm
		MeshKit.quad(st, Vector3(at.x + a.x, at.y + a.y, at.z - thick * 0.5), Vector3(at.x + b.x, at.y + b.y, at.z - thick * 0.5),
				Vector3(at.x + b.x, at.y + b.y, at.z + thick * 0.5), Vector3(at.x + a.x, at.y + a.y, at.z + thick * 0.5), nrm, col)
