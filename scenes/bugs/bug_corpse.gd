class_name BugCorpse
extends Node3D
## Cosmetic death: a copy of the bug's body flips onto its back with a little
## hop, its legs curl up and twitch, then it drops away and shrinks out.
## Local only; every peer makes its own from the bug before it is freed.

const LIFE := 1.7

var _legs: Array[Node3D] = []
var _t := 0.0
var _b0 := Basis()
## Bugs killed on a cliff face fall away; ones on flat ground stay put and shrink.
var _drops := true
## How far to lift the body so it lands on its back rather than inside the ground.
var _lift := 0.0
var _p0 := Vector3.ZERO


static func from_bug(bug: Bug) -> BugCorpse:
	var c := BugCorpse.new()
	bug.get_parent().add_child(c)
	c.global_transform = bug.global_transform
	c._drops = bug.global_basis.y.normalized().y < 0.7
	c._lift = float(bug.spec["body_radius"]) * 0.7
	var body := MeshInstance3D.new()
	body.mesh = bug.spec["body"]
	body.material_override = Materials.toon(0.03)
	body.scale = Vector3.ONE * float(bug.spec["scale"])
	c.add_child(body)
	var mat := Materials.toon(0.015)
	var col: Color = bug.spec["leg_color"]
	var len := (float(bug.spec["upper"]) + float(bug.spec["lower"])) * 0.6
	var thick := float(bug.spec["thick"])
	var st := MeshKit.begin()
	# One curled leg: up from the hip, bent back in at the knee.
	MeshKit.add_limb(st, Vector3.ZERO, Vector3(0, len * 0.55, 0), thick, col, 6)
	MeshKit.add_limb(st, Vector3(0, len * 0.55, 0), Vector3(0, len * 0.75, len * 0.3), thick * 0.8, col.darkened(0.2), 6)
	var leg_mesh := MeshKit.finish(st)
	for leg: Dictionary in bug.spec["legs"]:
		var pivot := Node3D.new()
		var hip: Vector3 = leg["hip"]
		pivot.position = hip
		pivot.rotation.z = -signf(hip.x) * 0.5 - PI
		c.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = leg_mesh
		mi.material_override = mat
		pivot.add_child(mi)
		c._legs.append(pivot)
	return c


func _process(delta: float) -> void:
	if _t == 0.0:
		_b0 = transform.basis
		_p0 = position
	_t += delta
	# Flip onto the back over the first 0.25 s with a little hop, then drop away.
	var flip := clampf(_t / 0.25, 0.0, 1.0)
	var hop := sin(minf(_t / 0.45, 1.0) * PI) * 0.3
	var drop := 0.5 * 25.0 * pow(maxf(_t - 0.9, 0.0), 2.0) if _drops else 0.0
	transform.basis = _b0 * Basis(Vector3.BACK, PI * flip * flip * (3.0 - 2.0 * flip))
	position = _p0 + _b0.y.normalized() * _lift * flip + Vector3.UP * (hop - drop)
	# Legs twitch, fast at first, then give out.
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * 30.0 + i * 1.7) * 0.35 * maxf(1.0 - _t / 1.2, 0.0)
	if _t > LIFE - 0.4:
		transform.basis = transform.basis.scaled(Vector3.ONE * maxf((LIFE - _t) / 0.4, 0.01))
	if _t >= LIFE:
		queue_free()
