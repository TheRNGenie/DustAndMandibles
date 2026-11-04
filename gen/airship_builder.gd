class_name AirshipBuilder
extends RefCounted
## "The Lucky Mandible": a big patched canvas airship carrying a casino and the
## market (the vendor cart and the gunsmith). Open-sided gondola with a canopy,
## a lit CASINO sign, fins and side propellers. Local space: the gondola deck
## surface is at y = 0, the long axis runs along Z; the boarding ring is at the
## +Z end (the market end), the casino fills the -Z half.

const DECK_W := 16.0
const DECK_L := 34.0
const ENVELOPE_Y := 15.0
const ENVELOPE := Vector3(11.0, 8.5, 30.0)
## Canopy height over the deck (tall enough for the gunsmith's stall).
const ROOF_Y := 4.6


## `ai_exterior`: the AI-made keel and engines (Airship) replace the skirt under
## the deck and the engine pods, so they are left out here.
static func hull(ai_exterior: bool = false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var st := MeshKit.begin()
	# Rigging ropes from the envelope down to the gondola corners.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, -0.33, 0.33, 1.0]:
			var a := Vector3(sx * DECK_W * 0.45, ROOF_Y - 0.2, sz * DECK_L * 0.45)
			var b := Vector3(sx * ENVELOPE.x * 0.6, ENVELOPE_Y - ENVELOPE.y * 0.75, sz * DECK_L * 0.6)
			MeshKit.add_limb(st, a, b, 0.04, Palette.WOOD_DARK, 4)
	# Gondola: plank deck, a skirt below, and a canopy roof on posts (open sides).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(DECK_W, 0.3, DECK_L), Palette.WOOD_DARK, 0.02, rng)
	if not ai_exterior:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.9, 0)), Vector3(DECK_W - 0.6, 1.2, DECK_L - 0.6), Color("#7A2E22"), 0.02, rng)
	for sx: float in [-1.0, 1.0]:
		for k in 7:
			var z := lerpf(-1.0, 1.0, float(k) / 6.0) * (DECK_L * 0.5 - 0.2)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 - 0.2), ROOF_Y * 0.5, z)), Vector3(0.2, ROOF_Y, 0.2), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, ROOF_Y + 0.05, 0)), Vector3(DECK_W + 0.6, 0.15, DECK_L + 0.6), Color("#B8452E"), 0.03, rng)
	# A painted divider beam between the casino (bow) and the market (stern).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, ROOF_Y - 0.3, 2.0)), Vector3(DECK_W - 0.4, 0.4, 0.3), Palette.WOOD_DARK)
	# Engine pods on outriggers.
	for sx: float in [-1.0, 1.0]:
		for pz: float in [-8.0, 8.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 + 1.4), ROOF_Y - 0.6, pz)), Vector3(2.8, 0.2, 0.25), Palette.METAL)
			if not ai_exterior:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * (DECK_W * 0.5 + 2.8), ROOF_Y - 0.6, pz)), 0.7, 0.55, 2.2, 10, Palette.METAL.darkened(0.2))
	return MeshKit.finish(st)


## The gas envelope and its fins (separate so it can sway on its rigging).
static func envelope() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var st := MeshKit.begin()
	# Envelope: a long ellipsoid of faded canvas, with darker patch panels.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, ENVELOPE_Y, 0)), ENVELOPE, 10, 18, Color("#D9C7A0"), 0.04, rng)
	for k in 11:
		var z := lerpf(-ENVELOPE.z * 0.72, ENVELOPE.z * 0.72, float(k) / 10.0)
		var r := ENVELOPE.x * sqrt(maxf(1.0 - pow(z / ENVELOPE.z, 2.0), 0.05))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, ENVELOPE_Y, z)), r + 0.05, r + 0.05, 0.35, 18,
				Color("#B8452E") if k % 2 == 0 else Color("#8A6A3A"))
	# Tail fins.
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var b := Basis(Vector3.BACK, a)
		MeshKit.add_box(st, Transform3D(b, Vector3(0, ENVELOPE_Y, 0) + b * Vector3(0, ENVELOPE.y * 0.85, -ENVELOPE.z * 0.85)), Vector3(0.4, 7.0, 9.0), Color("#B8452E"), 0.03, rng)
	return MeshKit.finish(st)


## Bulb lights along the canopy edge and the glow strip round the skirt
## (separate so they can light up at night).
static func bulbs() -> ArrayMesh:
	var st := MeshKit.begin()
	for end: float in [-1.0, 1.0]:
		for i in 20:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(lerpf(-DECK_W * 0.42, DECK_W * 0.42, float(i) / 19.0), -0.9, end * (DECK_L * 0.5 - 0.29))),
					Vector3(0.18, 0.18, 0.05), Palette.GLOW_YELLOW, 0.0, null, 0.8)
	# Festoons of casino bulbs: drooping in swags between the canopy posts down
	# both sides, and strung up the rigging ropes to the envelope.
	var hues: Array[Color] = [Palette.GLOW_YELLOW, Color("#FF6A3A"), Color("#FFF0C8"), Color("#FF4A6A")]
	for sx: float in [-1.0, 1.0]:
		for k in 6:
			var z0 := lerpf(-1.0, 1.0, float(k) / 6.0) * (DECK_L * 0.5 - 0.2)
			var z1 := lerpf(-1.0, 1.0, float(k + 1) / 6.0) * (DECK_L * 0.5 - 0.2)
			for j in 7:
				var f := (float(j) + 0.5) / 7.0
				var y := ROOF_Y - 0.35 - sin(f * PI) * 0.75
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 - 0.05), y, lerpf(z0, z1, f))), Vector3.ONE * 0.085, 3, 6,
						hues[(j + k) % hues.size()], 0.0, null, 0.95)
		for sz: float in [-1.0, -0.33, 0.33, 1.0]:
			var a := Vector3(sx * DECK_W * 0.45, ROOF_Y - 0.2, sz * DECK_L * 0.45)
			var b := Vector3(sx * ENVELOPE.x * 0.6, ENVELOPE_Y - ENVELOPE.y * 0.75, sz * DECK_L * 0.6)
			for j in 9:
				var p := a.lerp(b, (float(j) + 1.0) / 10.0)
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * 0.11, 3, 6, hues[j % hues.size()], 0.0, null, 0.95)
	# Bulb lights along the canopy edge.
	for i in 30:
		var z := lerpf(-DECK_L * 0.5, DECK_L * 0.5, float(i) / 29.0)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 + 0.3), ROOF_Y - 0.15, z)), Vector3.ONE * 0.1, 3, 6, Palette.GLOW_YELLOW, 0.0, null, 0.9)
	return MeshKit.finish(st)


## Railings with a gap at the +Z end for the ladder (separate so it can collide).
static func railing() -> ArrayMesh:
	var st := MeshKit.begin()
	var hw := DECK_W * 0.5 - 0.1
	var hl := DECK_L * 0.5 - 0.1
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-hw, 0.55, 0)), Vector3(0.1, 1.1, DECK_L - 0.2), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(hw, 0.55, 0)), Vector3(0.1, 1.1, DECK_L - 0.2), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.55, -hl)), Vector3(DECK_W - 0.2, 1.1, 0.1), Palette.WOOD)
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (hw * 0.5 + 0.7), 0.55, hl)), Vector3(hw - 1.4, 1.1, 0.1), Palette.WOOD)
	return MeshKit.finish(st)


static func propeller() -> ArrayMesh:
	var st := MeshKit.begin()
	for k in 3:
		var b := Basis(Vector3.BACK, TAU * float(k) / 3.0)
		MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 0.75, 0)), Vector3(0.25, 1.5, 0.06), Palette.WOOD)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.15, 0.15, 0.2, 8, Palette.METAL)
	return MeshKit.finish(st)


## A rope ladder `length` long hanging down from its top (origin).
static func ladder(length: float) -> ArrayMesh:
	var st := MeshKit.begin()
	for sx: float in [-0.35, 0.35]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(sx, -length * 0.5, 0)), 0.04, 0.04, length, 5, Palette.WOOD_DARK)
	var rungs := int(length / 0.4)
	for i in rungs:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.2 - i * 0.4, 0)), Vector3(0.75, 0.06, 0.08), Palette.WOOD)
	return MeshKit.finish(st)
