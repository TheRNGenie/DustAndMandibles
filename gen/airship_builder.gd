class_name AirshipBuilder
extends RefCounted
## "The Lucky Mandible": a patched canvas airship with an open-sided casino
## gondola, a big lit CASINO sign, fins, and side propellers. Local space: the
## gondola deck surface is at y = 0, the ship's long axis runs along Z, and the
## ladder hangs from the +Z end of the deck.

const DECK_W := 9.0
const DECK_L := 13.0
const ENVELOPE_Y := 10.5
const ENVELOPE := Vector3(6.5, 5.5, 17.0)


static func hull() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var st := MeshKit.begin()
	# Envelope: a long ellipsoid of faded canvas, with darker patch panels.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, ENVELOPE_Y, 0)), ENVELOPE, 10, 18, Color("#D9C7A0"), 0.04, rng)
	for k in 7:
		var z := lerpf(-12.0, 12.0, float(k) / 6.0)
		var r := ENVELOPE.x * sqrt(maxf(1.0 - pow(z / ENVELOPE.z, 2.0), 0.05))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, ENVELOPE_Y, z)), r + 0.05, r + 0.05, 0.35, 18,
				Color("#B8452E") if k % 2 == 0 else Color("#8A6A3A"))
	# Tail fins.
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var b := Basis(Vector3.BACK, a)
		MeshKit.add_box(st, Transform3D(b, Vector3(0, ENVELOPE_Y, 0) + b * Vector3(0, ENVELOPE.y * 0.85, -14.5)), Vector3(0.25, 4.0, 5.0), Color("#B8452E"), 0.03, rng)
	# Rigging ropes from the envelope down to the gondola corners.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, -0.33, 0.33, 1.0]:
			var a := Vector3(sx * DECK_W * 0.45, 2.6, sz * DECK_L * 0.45)
			var b := Vector3(sx * ENVELOPE.x * 0.6, ENVELOPE_Y - ENVELOPE.y * 0.75, sz * DECK_L * 0.6)
			MeshKit.add_limb(st, a, b, 0.04, Palette.WOOD_DARK, 4)
	# Gondola: plank deck, a skirt below, and a canopy roof on posts (open sides).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(DECK_W, 0.3, DECK_L), Palette.WOOD_DARK, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.9, 0)), Vector3(DECK_W - 0.6, 1.2, DECK_L - 0.6), Color("#7A2E22"), 0.02, rng)
	for i in 12:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(lerpf(-DECK_W * 0.42, DECK_W * 0.42, float(i) / 11.0), -0.9, -DECK_L * 0.5 + 0.29)),
				Vector3(0.18, 0.18, 0.05), Palette.GLOW_YELLOW, 0.0, null, 0.8)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 - 0.2), 1.4, sz * (DECK_L * 0.5 - 0.2))), Vector3(0.16, 2.8, 0.16), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 2.85, 0)), Vector3(DECK_W + 0.6, 0.15, DECK_L + 0.6), Color("#B8452E"), 0.03, rng)
	# Bulb lights along the canopy edge.
	for i in 14:
		var z := lerpf(-DECK_L * 0.5, DECK_L * 0.5, float(i) / 13.0)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 + 0.3), 2.7, z)), Vector3.ONE * 0.1, 3, 6, Palette.GLOW_YELLOW, 0.0, null, 0.9)
	# Engine pods on outriggers.
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * (DECK_W * 0.5 + 1.4), 2.2, 2.0)), Vector3(2.8, 0.2, 0.25), Palette.METAL)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * (DECK_W * 0.5 + 2.8), 2.2, 2.0)), 0.5, 0.4, 1.6, 10, Palette.METAL.darkened(0.2))
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
