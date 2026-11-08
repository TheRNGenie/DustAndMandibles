extends RefCounted
## Detailed models for the airship's slot machines, prize wheel and vendor booths
## (Logan: "a thematically accurate and far more detailed booth to suit their
## vending"). Built from MeshKit primitives like the casino tables
## (gen/casino_table_art.gd). Wood and brass go on the shared toon material, which
## the deck repaints as planks and brass (Airship._richer_deck); lacquer, glass,
## paint, produce and bulbs go on a private toon material so they keep their
## colours. Local space: origin on the deck, customers on the -Z side.

const BRASS := Color("#C9A048")
const BRASS_DK := Color("#8A6526")
const MAHOGANY := Color("#5C2A1C")
const OAK := Color("#8A5A32")
const IRON := Color("#2E2A28")
const IVORY := Color("#F1E6CC")
const BULB := Color("#FFE7A0")
const RYE := "res://assets/fonts/Rye-Regular.ttf"
## The reel symbols' colours, in CasinoRules.SLOT_SYMBOLS order: bug, cactus,
## chili, horseshoe, star.
const SYMBOL_COLORS: Array[Color] = [Color("#3B2A4E"), Color("#3E8A3A"), Color("#C9302C"), Color("#7E8C99"), Color("#E8B21E")]


# ------------------------------------------------------------------ shared bits

## Three surface tools: "wood" (deck-painted), "paint" (kept), "glow" (bulbs).
static func parts() -> Dictionary:
	return {"wood": MeshKit.begin(), "paint": MeshKit.begin(), "glow": MeshKit.begin()}


## Adds the parts to `parent` as meshes (each its own node so the deck can repaint
## the wood without touching the paint).
static func finish(parent: Node3D, p: Dictionary, outline: float = 0.015) -> void:
	for k: String in p:
		var mi := MeshInstance3D.new()
		mi.name = "Art_" + k
		mi.mesh = MeshKit.finish(p[k])
		mi.material_override = Materials.toon(outline) if k == "wood" else Materials.toon_unique(0.0 if k == "glow" else outline)
		parent.add_child(mi)


static func box(st: SurfaceTool, at: Vector3, size: Vector3, c: Color, b: Basis = Basis(), glow: float = 0.0) -> void:
	MeshKit.add_box(st, Transform3D(b, at), size, c, 0.0, null, glow)


## A rectangular frame of four bars in the XY plane (a moulding round a panel).
static func frame(st: SurfaceTool, at: Vector3, size: Vector2, bar: float, depth: float, c: Color) -> void:
	box(st, at + Vector3(0, size.y * 0.5 - bar * 0.5, 0), Vector3(size.x, bar, depth), c)
	box(st, at - Vector3(0, size.y * 0.5 - bar * 0.5, 0), Vector3(size.x, bar, depth), c)
	box(st, at + Vector3(size.x * 0.5 - bar * 0.5, 0, 0), Vector3(bar, size.y - bar * 2.0, depth), c)
	box(st, at - Vector3(size.x * 0.5 - bar * 0.5, 0, 0), Vector3(bar, size.y - bar * 2.0, depth), c)


## A bulb: a small glowing ball on a brass socket.
static func bulb(p: Dictionary, at: Vector3, r: float = 0.028) -> void:
	MeshKit.add_ellipsoid(p["glow"], Transform3D(Basis(), at), Vector3.ONE * r, 3, 8, BULB, 0.0, null, 0.85)
	MeshKit.add_cylinder(p["wood"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, r * 0.9)), r * 0.7, r * 0.7, r * 0.8, 8, BRASS_DK)


## A sign's lettering (faces -Z unless yaw says otherwise), in Rye like the tables.
static func label(parent: Node3D, text: String, at: Vector3, px: float, color: Color, yaw: float = PI, size: int = 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load(RYE) as Font
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.55)
	l.modulate = color
	l.position = at
	l.rotation.y = yaw
	l.double_sided = false
	parent.add_child(l)
	return l


## A small warm light (a lamp, a lantern, a marquee's glow).
static func lamp(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = color
	o.light_energy = energy
	o.omni_range = reach
	o.position = at
	o.shadow_enabled = false
	parent.add_child(o)
	return o


# ------------------------------------------------------------------ slot machine

## A Gold Rush era one-armed bandit: an oak plinth, a lacquered cabinet with brass
## mouldings, a paytable, a coin tray, a reel window with three real reels
## (returned so the machine can spin them), a sunburst crest ringed with bulbs
## and the title, and a brass boss where the lever goes in (-X: the player's right).
static func slot_cabinet(parent: Node3D, lacquer: Color, title: String) -> Array[Node3D]:
	var p := parts()
	var wood: SurfaceTool = p["wood"]
	var paint: SurfaceTool = p["paint"]
	var dark := lacquer.darkened(0.35)
	# Plinth: a stepped oak base with a brass kick strip.
	box(wood, Vector3(0, 0.05, 0), Vector3(0.96, 0.1, 0.76), OAK.darkened(0.3))
	box(wood, Vector3(0, 0.13, 0), Vector3(0.9, 0.06, 0.7), OAK.darkened(0.1))
	box(wood, Vector3(0, 0.12, -0.355), Vector3(0.88, 0.025, 0.012), BRASS)
	# Lower cabinet: a raised, framed panel with a horseshoe on it.
	box(paint, Vector3(0, 0.53, 0), Vector3(0.84, 0.74, 0.64), lacquer)
	box(paint, Vector3(0, 0.52, -0.322), Vector3(0.62, 0.5, 0.012), dark)
	frame(wood, Vector3(0, 0.52, -0.33), Vector2(0.66, 0.54), 0.024, 0.016, BRASS)
	MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.55, -0.336)), 0.085, 0.06, 0.012, 16, BRASS)
	box(paint, Vector3(0, 0.47, -0.338), Vector3(0.05, 0.05, 0.012), dark) # (the horseshoe's open end)
	for k in 6:
		var a := PI * 0.25 + PI * 1.5 * k / 5.0
		MeshKit.add_ellipsoid(wood, Transform3D(Basis(), Vector3(cos(a + PI * 0.5) * 0.072, 0.55 + sin(a + PI * 0.5) * 0.072, -0.344)), Vector3.ONE * 0.007, 2, 6, IVORY)
	# Brass corner posts and the waist moulding.
	for sx: float in [-0.42, 0.42]:
		for sz: float in [-0.32, 0.32]:
			MeshKit.add_cylinder(wood, Transform3D(Basis(), Vector3(sx, 0.53, sz)), 0.018, 0.018, 0.74, 8, BRASS_DK)
	box(wood, Vector3(0, 0.915, 0), Vector3(0.9, 0.05, 0.7), BRASS)
	# The coin tray: a brass scoop on the waist, a few coins in it.
	box(wood, Vector3(0, 0.95, -0.4), Vector3(0.44, 0.02, 0.14), BRASS_DK)
	box(wood, Vector3(0, 0.98, -0.47), Vector3(0.46, 0.08, 0.016), BRASS)
	for sx: float in [-0.225, 0.225]:
		box(wood, Vector3(sx, 0.98, -0.4), Vector3(0.016, 0.08, 0.14), BRASS)
	for c: Vector3 in [Vector3(-0.1, 0.965, -0.41), Vector3(0.05, 0.965, -0.39), Vector3(0.12, 0.97, -0.43)]:
		MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, 0.2), c), 0.025, 0.025, 0.008, 10, Color("#E8C04A"))
	# Upper cabinet: the reel housing, open round the window so the reels show.
	box(paint, Vector3(0, 1.54, 0.02), Vector3(0.8, 0.18, 0.6), lacquer)
	box(paint, Vector3(0, 1.045, 0.02), Vector3(0.8, 0.23, 0.6), lacquer)
	for sx: float in [-0.35, 0.35]:
		box(paint, Vector3(sx, 1.305, 0.02), Vector3(0.1, 0.29, 0.6), lacquer)
	box(paint, Vector3(0, 1.305, 0.28), Vector3(0.6, 0.29, 0.06), Color("#140C08"))
	# Paytable: an ivory card with the five symbols and their pays.
	box(paint, Vector3(0, 1.04, -0.285), Vector3(0.6, 0.15, 0.012), IVORY)
	frame(wood, Vector3(0, 1.04, -0.29), Vector2(0.64, 0.19), 0.018, 0.014, BRASS)
	for i in 5:
		var x := -0.24 + i * 0.12
		for k in 3:
			box(paint, Vector3(x - 0.026 + k * 0.026, 1.065, -0.293), Vector3(0.02, 0.026, 0.006), SYMBOL_COLORS[i])
		box(paint, Vector3(x, 1.02, -0.293), Vector3(0.07, 0.012, 0.006), Color("#5A4A3A"))
	# The reel window: a brass bezel round the opening, a red payline across it.
	frame(wood, Vector3(0, 1.305, -0.295), Vector2(0.66, 0.33), 0.03, 0.03, BRASS)
	for sx: float in [-0.29, 0.29]:
		box(paint, Vector3(sx, 1.3, -0.17), Vector3(0.02, 0.24, 0.24), Color("#140C08"))
	box(p["glow"], Vector3(0, 1.305, -0.312), Vector3(0.58, 0.006, 0.004), Color("#FF4030"), Basis(), 0.6)
	# Coin slot and a "1 BIT" plate.
	box(wood, Vector3(0.26, 1.54, -0.29), Vector3(0.12, 0.06, 0.02), BRASS)
	box(paint, Vector3(0.26, 1.545, -0.302), Vector3(0.06, 0.008, 0.004), Color("#140C08"))
	# Crest: a half disc of lacquer behind a brass rim, gold sunburst rays,
	# a ring of bulbs, a star on top.
	var crest := Vector3(0, 1.63, 0.0)
	MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), crest), 0.4, 0.4, 0.07, 28, dark)
	MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), crest), 0.43, 0.39, 0.09, 28, BRASS)
	for k in 9:
		var a := PI * (0.1 + 0.8 * k / 8.0)
		var dir := Vector3(cos(a), sin(a), 0)
		box(paint, crest + dir * 0.22 + Vector3(0, 0, -0.04), Vector3(0.24, 0.018, 0.008), Color("#E8C04A").darkened(0.1 * (k % 2)), Basis(Vector3.BACK, a))
		bulb(p, crest + dir * 0.41 + Vector3(0, 0, -0.05), 0.024)
	MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), crest + Vector3(0, 0, -0.045)), 0.07, 0.07, 0.02, 16, BRASS)
	MeshKit.add_ellipsoid(wood, Transform3D(Basis(), crest + Vector3(0, 0.46, 0)), Vector3(0.04, 0.05, 0.04), 3, 8, BRASS)
	box(wood, Vector3(0, 1.64, 0.02), Vector3(0.84, 0.03, 0.64), BRASS)
	# The lever's boss on the right-hand side (as you face the machine: -X).
	MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.425, 1.12, 0.0)), 0.085, 0.07, 0.04, 14, BRASS)
	MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.45, 1.12, 0.0)), 0.04, 0.04, 0.04, 12, BRASS_DK)
	finish(parent, p)
	label(parent, title, crest + Vector3(0, 0.13, -0.075), 0.0016, Color("#FFE08A"), PI, 72)
	lamp(parent, Vector3(0, 1.85, -0.35), Color("#FFC870"), 0.5, 1.8)
	# The reels: drums of 20 painted stops (STRIPS), turned by the machine.
	var reels: Array[Node3D] = []
	for i in 3:
		var r := MeshInstance3D.new()
		r.name = "Reel%d" % i
		r.mesh = reel_mesh(SlotMachine.STRIPS[i])
		r.material_override = Materials.toon_unique(0.0)
		r.position = Vector3(0.19 - i * 0.19, 1.305, -0.02) # (reel 0 on the left as you face it)
		parent.add_child(r)
		reels.append(r)
	return reels


const REEL_R := 0.22
const REEL_W := 0.16


## One reel drum: 20 ivory stops round the X axis, each with its symbol painted
## on. Stop q faces -Z when the drum's rotation.x is -q * TAU / 20.
static func reel_mesh(strip: Array) -> ArrayMesh:
	var st := MeshKit.begin()
	var n := strip.size()
	var step := TAU / n
	var hw := REEL_W * 0.5
	for q in n:
		var a0 := (q - 0.5) * step
		var a1 := (q + 0.5) * step
		var p0 := Vector3(0, sin(a0), -cos(a0)) * REEL_R
		var p1 := Vector3(0, sin(a1), -cos(a1)) * REEL_R
		var nrm := Vector3(0, sin(q * step), -cos(q * step))
		var bg := IVORY if q % 2 == 0 else IVORY.darkened(0.04)
		MeshKit.quad(st, p0 + Vector3(-hw, 0, 0), p0 + Vector3(hw, 0, 0), p1 + Vector3(hw, 0, 0), p1 + Vector3(-hw, 0, 0), nrm, MeshKit.vcol(bg))
		_glyph(st, int(strip[q]), nrm * (REEL_R + 0.002), Vector3(0, cos(q * step), sin(q * step)), nrm)
	# Brass end rims.
	for sx: float in [-hw, hw]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0, 0)), REEL_R + 0.008, REEL_R + 0.008, 0.012, n, BRASS)
	return MeshKit.finish(st)


## A symbol painted on a reel stop: small flat shapes in the stop's plane.
static func _glyph(st: SurfaceTool, kind: int, c: Vector3, up: Vector3, nrm: Vector3) -> void:
	var col := MeshKit.vcol(SYMBOL_COLORS[kind])
	var rt := Vector3(1, 0, 0)
	var s := 0.026
	var poly := func(pts: Array) -> void:
		for i in range(1, pts.size() - 1):
			var a: Vector3 = c + rt * pts[0].x + up * pts[0].y
			var b: Vector3 = c + rt * pts[i].x + up * pts[i].y
			var d: Vector3 = c + rt * pts[i + 1].x + up * pts[i + 1].y
			MeshKit.tri(st, a, b, d, nrm, nrm, nrm, col, nrm)
	match kind:
		0: # bug: a round body and a head
			var body: Array = []
			for k in 10:
				var a := TAU * k / 10.0
				body.append(Vector2(cos(a) * s * 0.75, sin(a) * s - s * 0.15))
			poly.call(body)
			poly.call([Vector2(-s * 0.35, s * 0.75), Vector2(s * 0.35, s * 0.75), Vector2(s * 0.25, s * 1.05), Vector2(-s * 0.25, s * 1.05)])
		1: # cactus: a trunk and two arms
			poly.call([Vector2(-s * 0.22, -s), Vector2(s * 0.22, -s), Vector2(s * 0.22, s), Vector2(-s * 0.22, s)])
			poly.call([Vector2(-s * 0.75, 0), Vector2(-s * 0.22, 0), Vector2(-s * 0.22, s * 0.2), Vector2(-s * 0.75, s * 0.2)])
			poly.call([Vector2(-s * 0.75, 0), Vector2(-s * 0.55, 0), Vector2(-s * 0.55, s * 0.7), Vector2(-s * 0.75, s * 0.7)])
			poly.call([Vector2(s * 0.22, -s * 0.3), Vector2(s * 0.75, -s * 0.3), Vector2(s * 0.75, -s * 0.1), Vector2(s * 0.22, -s * 0.1)])
			poly.call([Vector2(s * 0.55, -s * 0.3), Vector2(s * 0.75, -s * 0.3), Vector2(s * 0.75, s * 0.45), Vector2(s * 0.55, s * 0.45)])
		2: # chili: a curved pod
			poly.call([Vector2(-s * 0.2, s), Vector2(s * 0.25, s * 0.85), Vector2(s * 0.35, 0), Vector2(s * 0.1, -s * 0.7), Vector2(-s * 0.5, -s), Vector2(-s * 0.1, -s * 0.4), Vector2(-s * 0.1, s * 0.4)])
		3: # horseshoe: a U of three bars
			poly.call([Vector2(-s * 0.8, -s * 0.2), Vector2(-s * 0.45, -s * 0.2), Vector2(-s * 0.45, s), Vector2(-s * 0.8, s)])
			poly.call([Vector2(s * 0.45, -s * 0.2), Vector2(s * 0.8, -s * 0.2), Vector2(s * 0.8, s), Vector2(s * 0.45, s)])
			poly.call([Vector2(-s * 0.8, -s * 0.2), Vector2(-s * 0.5, -s * 0.85), Vector2(s * 0.5, -s * 0.85), Vector2(s * 0.8, -s * 0.2), Vector2(s * 0.45, -s * 0.2), Vector2(s * 0.3, -s * 0.5), Vector2(-s * 0.3, -s * 0.5), Vector2(-s * 0.45, -s * 0.2)])
		_: # star: five points
			var star: Array = []
			for k in 10:
				var a := PI * 0.5 + PI * k / 5.0
				var rr := s * (1.05 if k % 2 == 0 else 0.45)
				star.append(Vector2(cos(a) * rr, sin(a) * rr))
			poly.call(star)


## The lever: a nickel shaft through a brass collar, a red ball on the end
## (pivots at its base; the machine swings it about X).
static func slot_arm() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.04, 0)), 0.045, 0.045, 0.06, 12, BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.34, 0)), 0.022, 0.017, 0.6, 10, Color("#C8CDD2"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.6, 0)), 0.028, 0.028, 0.04, 10, BRASS)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.67, 0)), Vector3.ONE * 0.065, 5, 10, Color("#C9302C"))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ prize wheel

## The wheel's stand: a stepped plinth, a column and braces, and a red marquee
## board behind the wheel ringed with bulbs, a brass crown and the title on top.
## The wheel itself is wheel_face(); the flapper is flapper().
static func wheel_stand(parent: Node3D, hub: Vector3) -> void:
	var p := parts()
	var wood: SurfaceTool = p["wood"]
	var paint: SurfaceTool = p["paint"]
	box(wood, Vector3(0, 0.07, 0.05), Vector3(1.9, 0.14, 1.0), OAK.darkened(0.3))
	box(wood, Vector3(0, 0.18, 0.05), Vector3(1.7, 0.08, 0.86), OAK)
	box(wood, Vector3(0, 0.07, -0.55), Vector3(1.2, 0.1, 0.2), OAK.darkened(0.1)) # a step up for the punters
	box(wood, Vector3(0, 0.225, -0.375), Vector3(1.7, 0.02, 0.012), BRASS)
	# The column and two raking braces behind the board.
	MeshKit.lathe(wood, Transform3D(Basis(), Vector3(0, 0.22, 0.3)), [Vector2(0.16, 0.0), Vector2(0.16, 0.04), Vector2(0.1, 0.1),
			Vector2(0.075, 0.3), Vector2(0.09, 0.5), Vector2(0.07, 0.7), Vector2(0.065, hub.y - 0.4), Vector2(0.09, hub.y - 0.3)], 14, MAHOGANY)
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_limb(wood, Vector3(sx * 0.7, 0.22, 0.32), Vector3(sx * 0.22, hub.y - 0.3, 0.28), 0.045, MAHOGANY, 8)
	# The marquee board: a red disc with a gold band, 24 bulbs round it.
	var board := hub + Vector3(0, 0, 0.12)
	MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), board), 1.05, 1.05, 0.06, 40, Color("#8A1E1A"))
	MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), board + Vector3(0, 0, -0.01)), 1.08, 1.0, 0.09, 40, BRASS)
	MeshKit.add_rim(paint, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), board + Vector3(0, 0, -0.035)), 0.93, 0.88, 0.02, 40, Color("#E8C04A"))
	for k in 24:
		var a := TAU * k / 24.0
		bulb(p, board + Vector3(sin(a) * 0.97, cos(a) * 0.97, -0.05), 0.03)
	# A crown on top: a fan of gold rays and a star.
	for k in 7:
		var a := PI * (0.25 + 0.5 * k / 6.0)
		box(paint, board + Vector3(cos(a), sin(a), 0) * 1.17 + Vector3(0, 0, 0.0), Vector3(0.22, 0.05, 0.03), Color("#E8C04A").darkened(0.12 * (k % 2)), Basis(Vector3.BACK, a))
	MeshKit.add_ellipsoid(wood, Transform3D(Basis(), board + Vector3(0, 1.32, 0)), Vector3(0.07, 0.08, 0.05), 3, 8, BRASS)
	# The flapper's brass housing at twelve o'clock.
	box(wood, hub + Vector3(0, 0.93, -0.06), Vector3(0.12, 0.1, 0.1), BRASS)
	finish(parent, p)
	label(parent, "WHEEL O' FORTUNE", board + Vector3(0, 1.17, -0.06), 0.0026, Color("#FFE08A"), PI, 72)
	lamp(parent, board + Vector3(0, 0, -0.9), Color("#FFC870"), 0.8, 3.0)


## The wheel's turning face (built on the wheel node, centre at its origin):
## the painted wedges (same layout as before, wedge i from TAU*i/n clockwise
## from the top), brass spokes between them, pegs on the rim, a brass hub, and
## each wedge's prize printed along its radius.
static func wheel_face(wheel: Node3D, wedges: Array) -> void:
	var p := parts()
	var paint: SurfaceTool = p["paint"]
	var wood: SurfaceTool = p["wood"]
	var n := wedges.size()
	var colors: Array[Color] = [Color("#C9302C"), Color("#F1E6CC"), Color("#2E6FA8"), Color("#E3A82A"), Color("#3E7A3A")]
	var r := 0.82
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var lab := String(wedges[i][0])
		var c: Color = Color("#1E1614") if lab == "BUST" else (Color("#E8B21E") if lab.begins_with("JACKPOT") else colors[i % colors.size()])
		var nrm := Vector3(0, 0, -1)
		var seg := 6
		for s in seg:
			var b0 := lerpf(a0, a1, float(s) / seg)
			var b1 := lerpf(a0, a1, float(s + 1) / seg)
			var q1 := Vector3(sin(b0), cos(b0), 0) * r
			var q2 := Vector3(sin(b1), cos(b1), 0) * r
			MeshKit.tri(paint, Vector3.ZERO, q2, q1, nrm, nrm, nrm, MeshKit.vcol(c), nrm)
			MeshKit.tri(paint, Vector3(0, 0, 0.02), q1 + Vector3(0, 0, 0.02), q2 + Vector3(0, 0, 0.02), -nrm, -nrm, -nrm, MeshKit.vcol(c.darkened(0.4)), -nrm)
		# A darker band near the rim for depth.
		var band := c.darkened(0.18)
		for s in seg:
			var b0 := lerpf(a0, a1, float(s) / seg)
			var b1 := lerpf(a0, a1, float(s + 1) / seg)
			var o0 := Vector3(sin(b0), cos(b0), -0.002) * 1.0
			var o1 := Vector3(sin(b1), cos(b1), -0.002) * 1.0
			MeshKit.quad(paint, Vector3(o1.x * 0.72, o1.y * 0.72, -0.003), Vector3(o0.x * 0.72, o0.y * 0.72, -0.003), Vector3(o0.x * 0.79, o0.y * 0.79, -0.003),
					Vector3(o1.x * 0.79, o1.y * 0.79, -0.003), nrm, MeshKit.vcol(band))
		# Spoke and peg at the wedge's leading edge.
		var dir := Vector3(sin(a0), cos(a0), 0)
		box(wood, dir * r * 0.55 + Vector3(0, 0, -0.012), Vector3(0.016, r * 0.9, 0.012), BRASS, Basis(Vector3.BACK, -a0))
		MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), dir * (r - 0.03) + Vector3(0, 0, -0.04)), 0.013, 0.013, 0.07, 8, BRASS)
		# The prize, reading out along the wedge's middle.
		var mid := (a0 + a1) * 0.5
		var text := _wedge_text(lab)
		var l := Label3D.new()
		l.text = text
		l.font = load(RYE) as Font
		l.font_size = 56
		l.pixel_size = 0.0021 if text.length() <= 6 else 0.0021 * 6.0 / text.length() * 1.15
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.6)
		l.modulate = Color("#FFF4DA") if lab == "BUST" or c.get_luminance() < 0.5 else Color("#2A1A10")
		l.double_sided = false
		var at := Vector3(sin(mid), cos(mid), 0) * r * 0.52 + Vector3(0, 0, -0.008)
		var theta := atan2(-cos(mid), -sin(mid))
		l.transform = Transform3D(Basis(Vector3.BACK, theta) * Basis(Vector3.UP, PI), at)
		wheel.add_child(l)
	# Rim and hub.
	MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.005)), r + 0.04, r - 0.005, 0.05, 44, BRASS)
	MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.03)), 0.15, 0.13, 0.06, 20, BRASS)
	MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.063)), 0.1, 0.1, 0.01, 20, Color("#8A1E1A"))
	var star: Array = []
	for k in 10:
		var a := PI * 0.5 + PI * k / 5.0
		var rr := 0.085 if k % 2 == 0 else 0.038
		star.append(Vector3(cos(a) * rr, sin(a) * rr, -0.07))
	var sn := Vector3(0, 0, -1)
	for i in range(1, star.size() - 1):
		MeshKit.tri(paint, Vector3(0, 0, -0.07), star[i + 1], star[i], sn, sn, sn, MeshKit.vcol(Color("#E8C04A")), sn)
	MeshKit.tri(paint, Vector3(0, 0, -0.07), star[0], star[star.size() - 1], sn, sn, sn, MeshKit.vcol(Color("#E8C04A")), sn)
	finish(wheel, p, 0.01)


static func _wedge_text(lab: String) -> String:
	match lab:
		"UPGRADE TOKEN": return "TOKEN"
		"3 CHILI SEEDS": return "3 SEEDS"
		"JACKPOT 25 SCRAP": return "JACKPOT"
		"TURRET PART": return "PART"
		"50 CHITIN": return "50"
		"120 CHITIN": return "120"
		"30 CHITIN": return "30"
	return lab


## The flapper: a leather tongue hanging from the housing at twelve o'clock (its
## pivot at the top); the wheel kicks it aside as each peg goes by.
static func flapper() -> MeshInstance3D:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.02, 0.02, 0.08, 10, BRASS_DK)
	var pts := [Vector3(-0.035, -0.01, -0.03), Vector3(0.035, -0.01, -0.03), Vector3(0.0, -0.15, -0.03)]
	var nrm := Vector3(0, 0, -1)
	MeshKit.tri(st, pts[0], pts[2], pts[1], nrm, nrm, nrm, MeshKit.vcol(Color("#5A2E1A")), nrm)
	MeshKit.tri(st, pts[0], pts[1], pts[2], -nrm, -nrm, -nrm, MeshKit.vcol(Color("#5A2E1A")), -nrm)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon_unique(0.01)
	return mi


# ------------------------------------------------------------------ Pearl's cashier cage

## A bank teller's cage in mahogany and brass: a dais, a panelled counter with a
## marble top, a brass grille with an arched teller's window, frosted side panes,
## chip racks and a clock on the back wall, a safe, a brass cash register, a
## ledger, a banker's lamp, a cornice with dentils and a pediment board for the
## sign, and a velvet rope out front for the queue. Pearl stands at (0, 0, 0.2).
static func cashier_booth(parent: Node3D) -> void:
	var p := parts()
	var wood: SurfaceTool = p["wood"]
	var paint: SurfaceTool = p["paint"]
	var marble := Color("#E8DECB")
	# Dais and the panelled counter.
	box(wood, Vector3(0, 0.04, 0.05), Vector3(2.8, 0.08, 1.75), MAHOGANY.darkened(0.3))
	box(wood, Vector3(0, 0.6, -0.5), Vector3(2.5, 1.04, 0.42), MAHOGANY)
	for i in 3:
		var x := -0.82 + i * 0.82
		box(wood, Vector3(x, 0.6, -0.715), Vector3(0.62, 0.62, 0.02), MAHOGANY.lightened(0.1))
		frame(wood, Vector3(x, 0.6, -0.726), Vector2(0.68, 0.68), 0.024, 0.016, BRASS_DK)
		box(wood, Vector3(x, 0.6, -0.73), Vector3(0.12, 0.12, 0.01), BRASS, Basis(Vector3.BACK, PI * 0.25))
	box(wood, Vector3(0, 0.13, -0.718), Vector3(2.5, 0.07, 0.02), BRASS)
	# Marble top with a rounded front edge and a few grey veins.
	box(paint, Vector3(0, 1.1, -0.52), Vector3(2.6, 0.05, 0.55), marble)
	MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 1.1, -0.795)), 0.025, 0.025, 2.6, 10, marble)
	for v: Array in [[Vector3(-0.9, 1.126, -0.55), 0.4], [Vector3(-0.2, 1.126, -0.45), -0.3], [Vector3(0.95, 1.126, -0.6), 0.6]]:
		box(paint, v[0], Vector3(0.42, 0.002, 0.008), Color("#B8AE9E"), Basis(Vector3.UP, float(v[1])))
	# The brass grille: posts, rails and bars, an arched window in the middle.
	for x: float in [-1.25, -0.42, 0.42, 1.25]:
		box(wood, Vector3(x, 1.78, -0.62), Vector3(0.05, 1.3, 0.05), BRASS)
	box(wood, Vector3(0, 2.43, -0.62), Vector3(2.56, 0.06, 0.06), BRASS)
	box(wood, Vector3(0, 1.15, -0.62), Vector3(2.56, 0.03, 0.05), BRASS)
	for side: float in [-1.0, 1.0]:
		var x0 := side * 0.42
		var x1 := side * 1.25
		box(wood, Vector3((x0 + x1) * 0.5, 1.95, -0.62), Vector3(0.83, 0.025, 0.03), BRASS)
		for k in 11:
			var x := lerpf(x0, x1, (k + 0.5) / 11.0)
			MeshKit.add_cylinder(wood, Transform3D(Basis(), Vector3(x, 1.79, -0.62)), 0.009, 0.009, 1.28, 6, BRASS)
		# A row of little brass rings under the top rail.
		for k in 5:
			var x := lerpf(x0, x1, (k + 0.5) / 5.0)
			MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 2.31, -0.62)), 0.06, 0.045, 0.012, 14, BRASS)
	# The arch over the teller's window, and bars above it.
	for k in 13:
		var a0 := PI * k / 13.0
		var a1 := PI * (k + 1) / 13.0
		var q0 := Vector3(cos(a0) * 0.42, 1.88 + sin(a0) * 0.3, -0.62)
		var q1 := Vector3(cos(a1) * 0.42, 1.88 + sin(a1) * 0.3, -0.62)
		var mid := (q0 + q1) * 0.5
		box(wood, mid, Vector3(q0.distance_to(q1) + 0.01, 0.03, 0.035), BRASS, Basis(Vector3.BACK, atan2(q1.y - q0.y, q1.x - q0.x)))
	for k in 9:
		var x := -0.36 + k * 0.09
		var top := 1.88 + sqrt(maxf(1.0 - pow(x / 0.42, 2.0), 0.0)) * 0.3
		MeshKit.add_cylinder(wood, Transform3D(Basis(), Vector3(x, (top + 2.43) * 0.5, -0.62)), 0.008, 0.008, 2.43 - top, 6, BRASS)
	# The teller's dip in the counter under the window.
	box(wood, Vector3(0, 1.128, -0.62), Vector3(0.38, 0.012, 0.22), BRASS_DK)
	# Side walls with frosted panes edged in brass.
	for sx: float in [-1.32, 1.32]:
		box(wood, Vector3(sx, 1.4, 0.05), Vector3(0.08, 2.72, 1.62), MAHOGANY)
		var ox := sx + signf(sx) * 0.045
		box(paint, Vector3(ox, 1.95, -0.05), Vector3(0.008, 0.78, 0.9), Color("#D8C08A")) # amber frosted glass
		box(wood, Vector3(ox, 2.35, -0.05), Vector3(0.012, 0.025, 0.94), BRASS)
		box(wood, Vector3(ox, 1.55, -0.05), Vector3(0.012, 0.025, 0.94), BRASS)
		for z: float in [-0.5, 0.4]:
			box(wood, Vector3(ox, 1.95, z), Vector3(0.012, 0.8, 0.025), BRASS)
	# The back wall: a shelf of chip racks, a clock above.
	box(wood, Vector3(0, 1.4, 0.82), Vector3(2.6, 2.72, 0.08), MAHOGANY.darkened(0.12))
	box(wood, Vector3(0, 1.42, 0.68), Vector3(2.3, 0.04, 0.24), MAHOGANY.lightened(0.06))
	for r in 3:
		var cx := -0.78 + r * 0.78
		box(paint, Vector3(cx, 1.46, 0.68), Vector3(0.62, 0.04, 0.2), Color("#2A1A12"))
		for i in ChipRules.DENOMS.size():
			var v: int = ChipRules.DENOMS[i]
			var x := cx - 0.24 + i * (0.48 / maxf(ChipRules.DENOMS.size() - 1, 1))
			for zz: float in [0.62, 0.72]:
				var h := 0.06 + 0.03 * ((i + r + int(zz * 10.0)) % 3)
				MeshKit.add_cylinder(paint, Transform3D(Basis(), Vector3(x, 1.48 + h * 0.5, zz)), 0.028, 0.028, h, 12, CasinoBoard.chip_color(v))
	var clock := Vector3(0, 2.2, 0.77)
	MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), clock), 0.16, 0.16, 0.02, 24, IVORY)
	MeshKit.add_rim(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), clock), 0.185, 0.155, 0.04, 24, BRASS)
	box(paint, clock + Vector3(0.0, 0.05, -0.014), Vector3(0.012, 0.1, 0.004), IRON)
	box(paint, clock + Vector3(0.045, 0.0, -0.014), Vector3(0.09, 0.01, 0.004), IRON, Basis(Vector3.BACK, 0.3))
	# A safe in the back corner: black iron, gold lines, a dial and a handle.
	var safe := Vector3(0.88, 0.4, 0.45)
	box(paint, safe, Vector3(0.55, 0.64, 0.46), Color("#1E1C1E"))
	frame(paint, safe + Vector3(0, 0, -0.235), Vector2(0.46, 0.54), 0.012, 0.006, Color("#C9A048"))
	MeshKit.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), safe + Vector3(-0.08, 0.06, -0.245)), 0.06, 0.06, 0.025, 16, BRASS)
	box(wood, safe + Vector3(0.12, -0.05, -0.25), Vector3(0.12, 0.02, 0.02), BRASS)
	# A brass cash register on the counter's left, a ledger on the right.
	var reg := Vector3(-0.85, 1.125, -0.46)
	box(wood, reg + Vector3(0, 0.08, 0), Vector3(0.36, 0.16, 0.28), BRASS)
	box(wood, reg + Vector3(0, 0.2, 0.04), Vector3(0.34, 0.1, 0.18), BRASS_DK, Basis(Vector3.RIGHT, -0.5))
	box(paint, reg + Vector3(0, 0.3, 0.1), Vector3(0.22, 0.09, 0.02), IVORY)
	for kx in 4:
		for kz in 3:
			MeshKit.add_cylinder(paint, Transform3D(Basis(), reg + Vector3(-0.1 + kx * 0.067, 0.24 + kz * 0.02, -0.02 + kz * 0.04)), 0.012, 0.012, 0.015, 8, IVORY)
	box(paint, Vector3(0.82, 1.135, -0.5), Vector3(0.22, 0.02, 0.3), Color("#7A1E1A"), Basis(Vector3.UP, 0.25))
	box(paint, Vector3(0.82, 1.148, -0.5), Vector3(0.2, 0.012, 0.28), IVORY, Basis(Vector3.UP, 0.25))
	box(paint, Vector3(0.82, 1.152, -0.5), Vector3(0.006, 0.006, 0.28), Color("#7A1E1A"), Basis(Vector3.UP, 0.25))
	# Chips stacked by the window, ready to push through.
	for i in ChipRules.DENOMS.size():
		var v: int = ChipRules.DENOMS[i]
		var h := 0.04 + 0.02 * (ChipRules.DENOMS.size() - i)
		MeshKit.add_cylinder(paint, Transform3D(Basis(), Vector3(-0.32 + i * 0.16, 1.125 + h * 0.5, -0.42)), 0.032, 0.032, h, 12, CasinoBoard.chip_color(v))
	# A banker's lamp: brass stand, green glass shade.
	var bl := Vector3(0.45, 1.125, -0.38)
	MeshKit.add_cylinder(wood, Transform3D(Basis(), bl + Vector3(0, 0.015, 0)), 0.07, 0.08, 0.03, 14, BRASS)
	MeshKit.add_cylinder(wood, Transform3D(Basis(), bl + Vector3(0, 0.15, 0)), 0.01, 0.01, 0.26, 8, BRASS)
	MeshKit.add_ellipsoid(p["glow"], Transform3D(Basis(), bl + Vector3(0, 0.29, 0)), Vector3(0.13, 0.045, 0.06), 3, 12, Color("#3E9A5A"), 0.0, null, 0.35)
	# Cornice with dentils, and the pediment board the sign hangs on.
	box(wood, Vector3(0, 2.8, 0.03), Vector3(2.9, 0.14, 1.8), MAHOGANY.darkened(0.15))
	box(wood, Vector3(0, 2.72, -0.87), Vector3(2.9, 0.035, 0.035), BRASS)
	for k in 24:
		box(wood, Vector3(-1.38 + k * 0.12, 2.69, -0.86), Vector3(0.06, 0.06, 0.05), MAHOGANY.lightened(0.1))
	box(paint, Vector3(0, 3.06, -0.8), Vector3(1.7, 0.42, 0.05), Color("#1E3A2A"))
	frame(wood, Vector3(0, 3.06, -0.83), Vector2(1.76, 0.48), 0.035, 0.02, BRASS)
	MeshKit.add_ellipsoid(wood, Transform3D(Basis(), Vector3(0, 3.36, -0.8)), Vector3(0.06, 0.07, 0.04), 3, 8, BRASS)
	for sx: float in [-0.95, 0.95]:
		MeshKit.add_ellipsoid(wood, Transform3D(Basis(), Vector3(sx, 2.95, -0.8)), Vector3(0.05, 0.05, 0.04), 3, 8, BRASS)
	# The velvet rope out front.
	for sx: float in [-0.9, 0.9]:
		stanchion(wood, Vector3(sx, 0.0, -1.35))
	var rope: Array = []
	var rr: Array = []
	for k in 9:
		var u := k / 8.0
		rope.append(Vector3(lerpf(-0.9, 0.9, u), 0.86 - sin(u * PI) * 0.16, -1.35))
		rr.append(0.022)
	MeshKit.tube(paint, rope, rr, 8, Color("#8A1426"))
	finish(parent, p)
	lamp(parent, bl + Vector3(0, 0.25, -0.1), Color("#FFE2A8"), 0.9, 3.2)


## A brass queue post: a weighted foot, a turned pole and a ball on top.
static func stanchion(st: SurfaceTool, at: Vector3) -> void:
	MeshKit.lathe(st, Transform3D(Basis(), at), [Vector2(0.15, 0.0), Vector2(0.15, 0.02), Vector2(0.11, 0.05), Vector2(0.03, 0.08),
			Vector2(0.025, 0.85), Vector2(0.04, 0.88), Vector2(0.0, 0.9)], 14, BRASS)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, 0.93, 0)), Vector3.ONE * 0.045, 4, 10, BRASS)


# ------------------------------------------------------------------ the produce stand

## A farmer's market stand: a striped canvas awning with a scalloped valance and
## a painted name board, chili ristras hanging from the front posts, two tiers of
## crates tilted to the buyers (corn, chilies, prickly pears, sage on the front
## tier; eggs, bug specimens in jars and a brass scale on the back), seed sacks on
## the deck, a chalkboard out front and a wagon wheel leaning on the side.
## The keeper stands behind the crates at about (0.2, 0, 0.5).
static func produce_stall(parent: Node3D, canvas: Color) -> void:
	var p := parts()
	var wood: SurfaceTool = p["wood"]
	var paint: SurfaceTool = p["paint"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var cream := Color("#F1E6CC")
	# A pallet floor.
	box(wood, Vector3(0, 0.05, 0.05), Vector3(2.8, 0.1, 1.75), OAK.darkened(0.35))
	for k in 7:
		box(wood, Vector3(-1.2 + k * 0.4, 0.105, 0.05), Vector3(0.36, 0.012, 1.7), OAK.darkened(0.2 + 0.06 * (k % 2)))
	# Trestle stands for the two tiers.
	for x: float in [-1.25, -0.42, 0.42, 1.25]:
		box(wood, Vector3(x, 0.4, -0.55), Vector3(0.06, 0.62, 0.06), OAK.darkened(0.15))
		box(wood, Vector3(x, 0.6, -0.05), Vector3(0.06, 1.0, 0.06), OAK.darkened(0.15))
		box(wood, Vector3(x, 0.32, -0.3), Vector3(0.04, 0.04, 0.56), OAK.darkened(0.25))
	box(wood, Vector3(0, 0.7, -0.55), Vector3(2.6, 0.05, 0.5), OAK)
	box(wood, Vector3(0, 1.1, -0.05), Vector3(2.6, 0.05, 0.42), OAK)
	# The crates and what's in them (front tier: corn, chili, prickly pear, sage).
	var front: Array[String] = ["corn", "chili", "pear", "herbs"]
	for i in 4:
		var c := Vector3(-0.93 + i * 0.62, 0.84, -0.56)
		var b := Basis(Vector3.RIGHT, 0.32)
		_crate(wood, c, b, Vector2(0.58, 0.42))
		_produce(paint, front[i], c, b, rng)
	# Back tier: eggs in a basket, bug specimens in jars, (the seed rack goes here), a scale.
	var back := Vector3(0, 1.13, -0.05)
	MeshKit.add_cylinder(wood, Transform3D(Basis(), back + Vector3(-0.95, 0.08, 0)), 0.2, 0.16, 0.16, 16, Color("#A07A4A"))
	MeshKit.add_rim(wood, Transform3D(Basis(), back + Vector3(-0.95, 0.16, 0)), 0.21, 0.18, 0.03, 16, Color("#8A6A3A"))
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf() * 0.4
		var rr := 0.06 + 0.07 * float(k % 2)
		MeshKit.add_ellipsoid(paint, Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), back + Vector3(-0.95 + cos(a) * rr, 0.17, sin(a) * rr)),
				Vector3(0.028, 0.036, 0.028), 3, 8, Color("#F4EEDF") if k % 3 != 0 else Color("#D9B48A"))
	for k in 4:
		var j := back + Vector3(-0.42 + k * 0.17, 0.0, 0.02 * (k % 2))
		MeshKit.add_cylinder(paint, Transform3D(Basis(), j + Vector3(0, 0.1, 0)), 0.055, 0.055, 0.2, 12, Color("#9FC7B8"))
		MeshKit.add_cylinder(wood, Transform3D(Basis(), j + Vector3(0, 0.215, 0)), 0.058, 0.058, 0.03, 12, BRASS_DK)
		MeshKit.add_ellipsoid(paint, Transform3D(Basis(Vector3.UP, k * 1.3), j + Vector3(0, 0.08, 0)), Vector3(0.035, 0.02, 0.025), 3, 8, Color("#3B2A4E").lightened(0.1 * k))
		box(paint, j + Vector3(0, 0.12, -0.056), Vector3(0.06, 0.05, 0.004), cream)
	var sc := back + Vector3(0.45, 0.0, 0.0)
	box(wood, sc + Vector3(0, 0.02, 0), Vector3(0.3, 0.04, 0.16), BRASS_DK)
	MeshKit.add_cylinder(wood, Transform3D(Basis(), sc + Vector3(0, 0.14, 0)), 0.012, 0.012, 0.22, 8, BRASS)
	box(wood, sc + Vector3(0, 0.25, 0), Vector3(0.34, 0.015, 0.02), BRASS)
	for sx: float in [-0.15, 0.15]:
		MeshKit.add_cylinder(wood, Transform3D(Basis(), sc + Vector3(sx, 0.2 if sx < 0.0 else 0.22, 0)), 0.07, 0.06, 0.02, 14, BRASS)
	MeshKit.add_ellipsoid(paint, Transform3D(Basis(), sc + Vector3(-0.15, 0.235, 0)), Vector3(0.05, 0.03, 0.05), 3, 8, Color("#E3361F"))
	# Awning posts, beams and the striped canvas (high at the back, out over the buyers).
	for x: float in [-1.35, 1.35]:
		box(wood, Vector3(x, 1.12, -0.85), Vector3(0.07, 2.24, 0.07), OAK.darkened(0.2))
		box(wood, Vector3(x, 1.32, 0.8), Vector3(0.07, 2.64, 0.07), OAK.darkened(0.2))
	box(wood, Vector3(0, 2.22, -0.85), Vector3(2.8, 0.08, 0.08), OAK.darkened(0.2))
	box(wood, Vector3(0, 2.62, 0.8), Vector3(2.8, 0.08, 0.08), OAK.darkened(0.2))
	var slope := atan2(0.42, 1.85)
	var mid := Vector3(0, 2.45, -0.12)
	for k in 8:
		var x := -1.4 + 0.35 * (k + 0.5)
		box(paint, mid + Vector3(x, 0, 0), Vector3(0.35, 0.025, 2.0), canvas if k % 2 == 0 else cream, Basis(Vector3.RIGHT, -slope))
	# Scalloped valance along the front edge.
	var edge_y := 2.45 - sin(slope) * 1.0
	var edge_z := -0.12 - cos(slope) * 1.0
	for k in 16:
		var x := -1.4 + 0.175 * (k + 0.5)
		var c := canvas if (k / 2) % 2 == 0 else cream
		var pts := [Vector3(x - 0.0875, edge_y, edge_z), Vector3(x + 0.0875, edge_y, edge_z), Vector3(x, edge_y - 0.13, edge_z)]
		var nrm := Vector3(0, 0, -1)
		MeshKit.tri(paint, pts[0], pts[1], pts[2], nrm, nrm, nrm, MeshKit.vcol(c), nrm)
		MeshKit.tri(paint, pts[0], pts[2], pts[1], -nrm, -nrm, -nrm, MeshKit.vcol(c.darkened(0.2)), -nrm)
	# The name board on the awning's front.
	box(paint, Vector3(0, edge_y + 0.2, edge_z - 0.03), Vector3(1.5, 0.3, 0.04), cream)
	frame(wood, Vector3(0, edge_y + 0.2, edge_z - 0.055), Vector2(1.56, 0.36), 0.03, 0.02, OAK.darkened(0.3))
	# Chili ristras down the front posts.
	for x: float in [-1.28, 1.28]:
		_ristra(paint, Vector3(x, 2.12, -0.95), 0.75, rng)
	# Seed sacks on the deck by the buyers.
	_sack(paint, Vector3(-1.55, 0.0, -0.95), Color("#C8A878"), "corn", rng)
	_sack(paint, Vector3(-1.62, 0.0, -0.45), Color("#B89868"), "chili", rng)
	_sack(paint, Vector3(1.6, 0.0, -0.9), Color("#C8A878"), "pear", rng)
	# A chalkboard on an easel out front.
	var cb := Vector3(-0.75, 0.0, -1.45)
	for sx: float in [-0.26, 0.26]:
		MeshKit.add_limb(wood, cb + Vector3(sx, 0.0, -0.12), cb + Vector3(sx * 0.9, 1.0, 0.02), 0.022, OAK.darkened(0.3), 6)
	MeshKit.add_limb(wood, cb + Vector3(0, 0.0, 0.3), cb + Vector3(0, 0.95, 0.04), 0.02, OAK.darkened(0.3), 6)
	box(paint, cb + Vector3(0, 0.66, -0.04), Vector3(0.5, 0.56, 0.025), Color("#2A302C"), Basis(Vector3.RIGHT, -0.12))
	box(wood, cb + Vector3(0, 0.37, -0.0), Vector3(0.56, 0.03, 0.06), OAK.darkened(0.2), Basis(Vector3.RIGHT, -0.12))
	# A wagon wheel leaning on the stand's side.
	var ww := Vector3(1.46, 0.5, 0.25)
	var wb := Basis(Vector3.BACK, 0.12) * Basis(Vector3.UP, PI * 0.5)
	MeshKit.add_rim(wood, Transform3D(wb * Basis(Vector3.RIGHT, PI * 0.5), ww), 0.48, 0.42, 0.06, 20, OAK.darkened(0.25))
	MeshKit.add_cylinder(wood, Transform3D(wb * Basis(Vector3.RIGHT, PI * 0.5), ww), 0.08, 0.08, 0.1, 12, OAK.darkened(0.35))
	for k in 8:
		var a := TAU * k / 8.0
		box(wood, ww + wb * Vector3(cos(a) * 0.25, sin(a) * 0.25, 0), Vector3(0.36, 0.03, 0.03), OAK.darkened(0.2), wb * Basis(Vector3.BACK, a))
	finish(parent, p)
	label(parent, "FRESH PRODUCE", Vector3(0, edge_y + 0.21, edge_z - 0.08), 0.0028, canvas.darkened(0.25), PI, 72)
	var chalk := label(parent, "FRESH\nTODAY", cb + Vector3(0, 0.68, -0.07), 0.0024, Color("#EDEBE2"), PI, 60)
	chalk.rotation.x = 0.12
	chalk.outline_size = 0


## A slatted crate (open top) centred at `c`, turned by `b`.
static func _crate(st: SurfaceTool, c: Vector3, b: Basis, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	var col := OAK.lightened(0.05)
	box(st, c + b * Vector3(0, -0.07, 0), Vector3(w, 0.02, d), col.darkened(0.2), b)
	for sx: float in [-1.0, 1.0]:
		box(st, c + b * Vector3(sx * w * 0.5, 0.0, 0), Vector3(0.02, 0.16, d), col, b)
	for sz: float in [-1.0, 1.0]:
		for y: float in [-0.04, 0.04]:
			box(st, c + b * Vector3(0, y, sz * d * 0.5), Vector3(w, 0.06, 0.02), col.darkened(0.08 if y > 0.0 else 0.0), b)


## A heap of one crop in a crate (in the crate's own tilted frame).
static func _produce(st: SurfaceTool, kind: String, c: Vector3, b: Basis, rng: RandomNumberGenerator) -> void:
	match kind:
		"corn":
			for k in 12:
				var at := c + b * Vector3(rng.randf_range(-0.2, 0.2), 0.03 + 0.035 * (k % 3), rng.randf_range(-0.13, 0.13))
				var r := b * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.2, 0.2))
				MeshKit.add_ellipsoid(st, Transform3D(r, at), Vector3(0.032, 0.11, 0.032), 4, 8, Color("#F2C83A"))
				MeshKit.add_ellipsoid(st, Transform3D(r * Basis(Vector3.BACK, 0.4), at + r * Vector3(0.015, -0.08, 0)), Vector3(0.014, 0.08, 0.03), 3, 6, Color("#7FA84A"))
		"chili":
			for k in 34:
				var at := c + b * Vector3(rng.randf_range(-0.24, 0.24), 0.04 + rng.randf() * 0.06, rng.randf_range(-0.16, 0.16))
				var r := b * Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 0.4)
				MeshKit.add_ellipsoid(st, Transform3D(r, at), Vector3(0.016, 0.055, 0.016), 3, 6, Color("#D8281C") if k % 5 != 0 else Color("#3E8A2A"))
		"pear":
			for k in 14:
				var at := c + b * Vector3(rng.randf_range(-0.21, 0.21), 0.04 + 0.04 * (k % 2), rng.randf_range(-0.13, 0.13))
				MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(0.045, 0.038, 0.04), 4, 8, Color("#C2306E"))
				MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0.0, 0.038, 0.0)), Vector3.ONE * 0.008, 2, 5, Color("#F2D45A"))
		_:
			for k in 5:
				var at := c + b * Vector3(-0.2 + k * 0.1, 0.07, rng.randf_range(-0.08, 0.08))
				MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), at), Vector3(0.045, 0.13, 0.04), 4, 8, Color("#7C9A6A").darkened(0.08 * (k % 2)))
				MeshKit.add_cylinder(st, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), at + b * Vector3(0, 0, 0.06)), 0.03, 0.03, 0.02, 8, Color("#C8A878"))


## A ristra: a string of red chilies spiralling down a twine, hung from `top`.
static func _ristra(st: SurfaceTool, top: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), top - Vector3(0, length * 0.5, 0)), 0.006, 0.006, length, 6, Color("#C8A878"))
	var n := int(length / 0.025)
	for k in n:
		var a := k * 1.9
		var y := -k * 0.025
		var dir := Vector3(cos(a), 0, sin(a))
		var r := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -1.1)
		MeshKit.add_ellipsoid(st, Transform3D(r, top + Vector3(0, y, 0) + dir * 0.05), Vector3(0.017, 0.016, 0.06), 3, 6,
				Color("#B81E18").lerp(Color("#E3361F"), rng.randf()))


## A burlap sack of seed, its neck rolled down, a few seeds showing.
static func _sack(st: SurfaceTool, at: Vector3, col: Color, seed_kind: String, rng: RandomNumberGenerator) -> void:
	# A slumped sack: broad at the foot, pinched at a tied neck, the mouth rolled open.
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08)), at)
	MeshKit.lathe(st, xf, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.25, 0.08), Vector2(0.25, 0.2), Vector2(0.21, 0.34),
			Vector2(0.14, 0.42), Vector2(0.11, 0.45), Vector2(0.13, 0.48), Vector2(0.17, 0.53), Vector2(0.16, 0.55)], 12, col, Vector2(1.0, 0.82))
	MeshKit.add_cylinder(st, xf * Transform3D(Basis(), Vector3(0, 0.445, 0)), 0.115, 0.115, 0.03, 12, Color("#7A5A3A"))
	for k in 3:
		MeshKit.add_limb(st, at + Vector3(-0.16 + k * 0.12, 0.05, -0.17), at + Vector3(-0.12 + k * 0.1, 0.32, -0.15), 0.008, col.darkened(0.25), 4)
	var seeds: Dictionary = {"corn": Color("#F2C83A"), "chili": Color("#E8D8A0"), "pear": Color("#5A3A2A")}
	var seedc: Color = seeds.get(seed_kind, Color("#D9C08A"))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, 0.52, 0)), Vector3(0.13, 0.03, 0.11), 3, 10, seedc)
	box(st, at + Vector3(0, 0.24, -0.205), Vector3(0.14, 0.1, 0.01), Color("#F1E6CC"))


# ------------------------------------------------------------------ the gunsmith

## The gunsmith's timber shop (one mesh, deck-painted: ShopBuilder.gun_stall):
## a dais, plank walls, a stepped false front over the counter, a shingled roof,
## a glass-topped display case, a rifle rack on the back wall, shelves, a
## workbench with a vice, and powder kegs by the door. The paint, the guns, the
## sign and the lantern are gunsmith_dress(). The keeper stands at (0.5, 0, 0.15).
static func gunsmith_wood() -> ArrayMesh:
	var st := MeshKit.begin()
	var plank := Color("#7A5232")
	# Dais and the plank walls (back and sides), boards picked out.
	box(st, Vector3(0, 0.05, 0.05), Vector3(3.1, 0.1, 1.8), OAK.darkened(0.35))
	box(st, Vector3(0, 1.4, 0.84), Vector3(3.0, 2.7, 0.08), plank)
	for k in 9:
		box(st, Vector3(-1.33 + k * 0.333, 1.4, 0.795), Vector3(0.012, 2.6, 0.012), plank.darkened(0.35))
	for sx: float in [-1.48, 1.48]:
		box(st, Vector3(sx, 1.4, 0.0), Vector3(0.08, 2.7, 1.7), plank)
		for k in 5:
			box(st, Vector3(sx + signf(sx) * 0.045, 0.3 + k * 0.5, 0.0), Vector3(0.012, 0.012, 1.68), plank.darkened(0.35))
	# Corner posts and the header over the counter.
	for sx: float in [-1.5, 1.5]:
		box(st, Vector3(sx, 1.4, -0.84), Vector3(0.14, 2.8, 0.14), OAK.darkened(0.3))
	box(st, Vector3(0, 2.62, -0.84), Vector3(3.1, 0.2, 0.16), OAK.darkened(0.25))
	# The false front: a tall board with a stepped top, framed and capped.
	box(st, Vector3(0, 3.0, -0.92), Vector3(3.2, 0.6, 0.06), plank.darkened(0.1))
	box(st, Vector3(0, 3.42, -0.92), Vector3(1.6, 0.26, 0.06), plank.darkened(0.1))
	box(st, Vector3(0, 3.31, -0.94), Vector3(3.3, 0.05, 0.1), OAK.darkened(0.35))
	box(st, Vector3(0, 3.57, -0.94), Vector3(1.7, 0.05, 0.1), OAK.darkened(0.35))
	for sx: float in [-0.8, 0.8]:
		box(st, Vector3(sx, 3.44, -0.94), Vector3(0.05, 0.28, 0.08), OAK.darkened(0.35))
	# A shingled lean-to roof behind the false front.
	var slope := atan2(0.25, 1.7)
	for k in 6:
		var z := -0.75 + k * 0.3
		var y := 2.78 + (z + 0.75) / 1.7 * 0.25
		box(st, Vector3(0, y, z), Vector3(3.2, 0.04, 0.36), Color("#6A3A2A").darkened(0.08 * (k % 2)), Basis(Vector3.RIGHT, slope))
	# The display case: a panelled base, a top frame round the glass, corner posts.
	box(st, Vector3(0, 0.5, -0.58), Vector3(2.7, 0.8, 0.5), OAK)
	for i in 3:
		frame(st, Vector3(-0.9 + i * 0.9, 0.5, -0.836), Vector2(0.78, 0.6), 0.03, 0.015, OAK.darkened(0.3))
	for sx: float in [-1.0, 1.0]:
		box(st, Vector3(sx * 1.33, 1.0, -0.58), Vector3(0.04, 0.2, 0.5), OAK.darkened(0.2))
	box(st, Vector3(0, 1.1, -0.82), Vector3(2.7, 0.03, 0.03), OAK.darkened(0.2))
	box(st, Vector3(0, 1.1, -0.34), Vector3(2.7, 0.03, 0.03), OAK.darkened(0.2))
	box(st, Vector3(0, 0.92, -0.82), Vector3(2.7, 0.04, 0.03), OAK.darkened(0.2))
	# Rifle rack on the back wall: a notched butt rail low and a hook rail high.
	box(st, Vector3(-0.2, 0.32, 0.72), Vector3(2.0, 0.08, 0.16), OAK.darkened(0.15))
	box(st, Vector3(-0.2, 1.95, 0.77), Vector3(2.0, 0.08, 0.06), OAK.darkened(0.15))
	# Shelves up the back wall for ammunition, and a pegboard on the left wall.
	for y: float in [2.2, 2.5]:
		box(st, Vector3(0.75, y, 0.68), Vector3(1.1, 0.03, 0.24), OAK)
	box(st, Vector3(-1.4, 1.65, 0.1), Vector3(0.03, 0.9, 1.1), OAK.lightened(0.1))
	# A workbench along the right wall with a vice.
	box(st, Vector3(1.15, 0.85, 0.25), Vector3(0.5, 0.06, 1.0), OAK)
	for sz: float in [-0.2, 0.68]:
		box(st, Vector3(1.15, 0.42, sz), Vector3(0.44, 0.84, 0.05), OAK.darkened(0.2))
	box(st, Vector3(1.0, 0.94, -0.05), Vector3(0.12, 0.12, 0.14), IRON)
	box(st, Vector3(1.0, 1.02, -0.05), Vector3(0.18, 0.04, 0.05), IRON)
	# Two powder kegs by the door.
	for k: Array in [[Vector3(-1.35, 0.0, -1.18), 0.25], [Vector3(-1.02, 0.0, -1.26), 0.21]]:
		var at: Vector3 = k[0]
		var r: float = k[1]
		MeshKit.lathe(st, Transform3D(Basis(), at), [Vector2(r * 0.86, 0.0), Vector2(r, r * 0.9), Vector2(r * 0.86, r * 1.8), Vector2(0.0, r * 1.8)], 14, OAK.lightened(0.05))
		for y: float in [0.2, 0.9, 1.6]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, r * y, 0)), r * (0.88 + 0.12 * sin(y / 1.8 * PI)) + 0.006, r * (0.88 + 0.12 * sin(y / 1.8 * PI)) + 0.006, 0.03, 14, IRON)
	return MeshKit.finish(st)


## The gunsmith's paint and wares: the false front painted with GUNSMITH and
## the small print, a velvet case of revolvers, long guns in the rack, irons on
## the pegboard, a bandolier, boxes of cartridges, the kegs' marks, a target on
## the outside wall, a giant revolver on the roof, and a lantern under the header.
static func gunsmith_dress(parent: Node3D) -> void:
	var p := parts()
	var paint: SurfaceTool = p["paint"]
	var green := Color("#24402E")
	var gold := Color("#E0B048")
	# The false front's paint and border.
	box(paint, Vector3(0, 3.0, -0.955), Vector3(3.0, 0.5, 0.01), green)
	box(paint, Vector3(0, 3.42, -0.955), Vector3(1.5, 0.2, 0.01), green)
	frame(paint, Vector3(0, 3.0, -0.962), Vector2(3.0, 0.5), 0.02, 0.004, gold)
	# The case: red velvet, three revolvers and a few cartridges on it.
	box(paint, Vector3(0, 0.93, -0.58), Vector3(2.6, 0.02, 0.44), Color("#6A1420"))
	for i in 3:
		_revolver(paint, Vector3(-0.85 + i * 0.85, 0.955, -0.6), Basis(Vector3.UP, 0.3 - i * 0.3) * Basis(Vector3.RIGHT, -PI * 0.5), 0.8)
	for k in 6:
		MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.35 + k * 0.035, 0.95, -0.42)), 0.007, 0.007, 0.05, 6, gold)
	# Glass: a few pale glints across the case top.
	for k in 3:
		box(p["glow"], Vector3(-0.9 + k * 0.9, 1.115, -0.58), Vector3(0.5, 0.004, 0.012), Color("#DDEFFF"), Basis(Vector3.UP, 0.6), 0.25)
	# Long guns standing in the rack.
	for i in 7:
		var x := -1.0 + i * 0.27
		_long_gun(paint, Vector3(x, 0.36, 0.73), i % 3 == 1)
	# Irons and a bandolier on the pegboard (left wall).
	for i in 3:
		_revolver(paint, Vector3(-1.37, 1.95 - i * 0.28, -0.25 + (i % 2) * 0.2), Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, -0.3), 1.0)
	var band: Array = []
	var br: Array = []
	for k in 9:
		var u := k / 8.0
		band.append(Vector3(-1.37, 1.95 - sin(u * PI) * 0.35, 0.15 + u * 0.4))
		br.append(0.018)
	MeshKit.tube(paint, band, br, 6, Color("#5A3A22"))
	for k in 8:
		var u := (k + 0.5) / 8.0
		MeshKit.add_cylinder(paint, Transform3D(Basis(), Vector3(-1.355, 1.97 - sin(u * PI) * 0.35, 0.15 + u * 0.4)), 0.007, 0.007, 0.05, 6, gold)
	# Boxes of cartridges on the shelves.
	var labels: Array[Color] = [Color("#B8452E"), Color("#3E6A8A"), Color("#D9A030"), Color("#3E7A3A")]
	for s in 2:
		for k in 6:
			var c := labels[(k + s) % labels.size()]
			var at := Vector3(0.3 + k * 0.17, 2.23 + s * 0.3 + 0.05, 0.66)
			box(paint, at, Vector3(0.14, 0.1, 0.12), c)
			box(paint, at + Vector3(0, 0, -0.061), Vector3(0.1, 0.05, 0.002), IVORY)
	# The kegs' painted X and POWDER bands.
	for k: Array in [[Vector3(-1.35, 0.0, -1.18), 0.25], [Vector3(-1.02, 0.0, -1.26), 0.21]]:
		var at: Vector3 = k[0]
		var r: float = k[1]
		var face := at + Vector3(0, r * 0.95, -r * 0.99)
		box(paint, face, Vector3(r * 0.9, 0.025, 0.006), Color("#1E1614"), Basis(Vector3.BACK, 0.7))
		box(paint, face, Vector3(r * 0.9, 0.025, 0.006), Color("#1E1614"), Basis(Vector3.BACK, -0.7))
	# A shooting target on the outside of the right wall, a few holes in it.
	var tg := Vector3(1.535, 1.5, -0.25)
	for k in 5:
		var rr := 0.3 - k * 0.06
		MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.BACK, PI * 0.5), tg + Vector3(0.004 * k, 0, 0)), rr, rr, 0.008, 24, Color("#F1E6CC") if k % 2 == 0 else Color("#B8281C"))
	for h: Vector2 in [Vector2(0.05, 0.03), Vector2(-0.08, 0.11), Vector2(0.14, -0.12), Vector2(-0.02, -0.05)]:
		MeshKit.add_cylinder(paint, Transform3D(Basis(Vector3.BACK, PI * 0.5), tg + Vector3(0.026, h.y, h.x)), 0.012, 0.012, 0.004, 8, Color("#1E1614"))
	# The giant revolver on the roof: a wooden cut-out painted steel and walnut.
	var g := Vector3(0, 3.98, -0.9)
	_revolver(paint, g, Basis(), 6.0)
	finish(parent, p)
	label(parent, "GUNSMITH", Vector3(0, 2.86, -0.97), 0.0062, gold, PI, 72) # (no tagline under it: Logan)
	# A lantern hanging under the header.
	var lt := MeshKit.begin()
	MeshKit.add_cylinder(lt, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.004, 0.004, 0.24, 4, IRON)
	MeshKit.add_cylinder(lt, Transform3D(Basis(), Vector3(0, -0.03, 0)), 0.07, 0.08, 0.04, 10, IRON)
	MeshKit.add_cylinder(lt, Transform3D(Basis(), Vector3(0, -0.13, 0)), 0.065, 0.065, 0.16, 10, Color("#FFD27A"), true, 0.85)
	MeshKit.add_cylinder(lt, Transform3D(Basis(), Vector3(0, -0.23, 0)), 0.08, 0.07, 0.04, 10, IRON)
	var lmi := MeshInstance3D.new()
	lmi.mesh = MeshKit.finish(lt)
	lmi.material_override = Materials.toon_unique(0.01)
	lmi.position = Vector3(0.0, 2.24, -0.7)
	parent.add_child(lmi)
	lamp(parent, Vector3(0.0, 2.05, -0.75), Color("#FFC870"), 1.2, 4.0)


## A revolver lying with its barrel along +X (its own frame: barrel +X, grip -Y),
## `s` times life size.
static func _revolver(st: SurfaceTool, at: Vector3, b: Basis, s: float) -> void:
	var steel := Color("#5E6670")
	var dark := Color("#30343A")
	var walnut := Color("#6A3A1E")
	box(st, at + b * (Vector3(0.1, 0.01, 0) * s), Vector3(0.16, 0.022, 0.022) * s, steel, b)
	box(st, at + b * (Vector3(0.1, -0.008, 0) * s), Vector3(0.15, 0.012, 0.016) * s, dark, b)
	MeshKit.add_cylinder(st, Transform3D(b * Basis(Vector3.BACK, PI * 0.5), at + b * (Vector3(0.0, 0.0, 0) * s)), 0.03 * s, 0.03 * s, 0.05 * s, 8, steel)
	box(st, at + b * (Vector3(-0.03, -0.005, 0) * s), Vector3(0.07, 0.05, 0.024) * s, dark, b)
	box(st, at + b * (Vector3(-0.075, -0.05, 0) * s), Vector3(0.04, 0.085, 0.03) * s, walnut, b * Basis(Vector3.BACK, -0.35))
	box(st, at + b * (Vector3(-0.055, 0.03, 0) * s), Vector3(0.025, 0.012, 0.012) * s, dark, b * Basis(Vector3.BACK, 0.6))
	MeshKit.add_rim(st, Transform3D(b, at + b * (Vector3(-0.015, -0.04, 0) * s)), 0.02 * s, 0.014 * s, 0.008 * s, 10, dark)


## A long gun standing on its butt: a walnut stock and a dark barrel (a double
## barrel when `shotgun`).
static func _long_gun(st: SurfaceTool, at: Vector3, shotgun: bool) -> void:
	var walnut := Color("#6A3A1E").lightened(0.05 * (int(at.x * 10.0) % 3))
	box(st, at + Vector3(0, 0.2, 0), Vector3(0.05, 0.4, 0.035), walnut, Basis(Vector3.BACK, 0.06))
	box(st, at + Vector3(0, 0.46, 0), Vector3(0.035, 0.14, 0.03), Color("#30343A"))
	box(st, at + Vector3(0, 0.72, -0.01), Vector3(0.03, 0.3, 0.035), walnut)
	for k in (2 if shotgun else 1):
		MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(-0.009 + 0.018 * k if shotgun else 0.0, 1.18, 0.0)), 0.009, 0.009, 0.95, 6, Color("#3A3E44"))
