class_name BugCorpse
extends Node3D
## Cosmetic death: a copy of the bug's body flips onto its back with a little
## hop, its legs curl up and twitch, then it drops away and its shell cracks
## into tumbling shards. Every death splats ichor on the rock. Small bugs (and
## any death past MAX_CORPSES at once) skip the corpse and just pop.
## Local only; every peer makes its own from the bug before it is freed.

const LIFE := 1.7
## When the shell cracks apart (seconds after death).
const CRACK_AT := 1.35
## Flipping corpses alive at once; past this, deaths just pop (750-bug waves).
const MAX_CORPSES := 24
## Bugs smaller than this just pop.
const POP_SIZE := 0.9

static var _live := 0
static var _leg_meshes: Dictionary = {}

var _color := Color.WHITE
var _size := 1.0
var _cracked := false

var _legs: Array[Node3D] = []
var _t := 0.0
var _b0 := Basis()
## Bugs killed on a cliff face fall away; ones on flat ground stay put and shrink.
var _drops := true
## How far to lift the body so it lands on its back rather than inside the ground.
var _lift := 0.0
var _p0 := Vector3.ZERO


static func from_bug(bug: Bug) -> BugCorpse:
	var up := bug.global_basis.y.normalized()
	var vfx := VfxPool.instance if is_instance_valid(VfxPool.instance) else null
	if vfx != null:
		# Ichor on the rock (or floor) under it.
		var under := bug.global_position - up * float(bug.spec["clearance"]) * 0.9
		vfx.ichor_splat(under, up, ichor_color(bug.def.shell_color), float(bug.spec["body_radius"]) * 1.3)
	if bug.def.size < POP_SIZE or _live >= MAX_CORPSES:
		return null
	var c := BugCorpse.new()
	_live += 1
	c._color = bug.def.shell_color
	c._size = float(bug.spec["scale"])
	bug.get_parent().add_child(c)
	c.global_transform = bug.global_transform
	c.global_position += bug.glide_offset() # where its body was drawn (it glides between updates)
	c._drops = bug.global_basis.y.normalized().y < 0.7
	c._lift = float(bug.spec["body_radius"]) * 0.7
	var body := MeshInstance3D.new()
	body.mesh = bug.spec["body"]
	body.material_override = Materials.toon(0.03)
	body.layers = VfxPool.CORPSE_LAYER
	body.scale = Vector3.ONE * float(bug.spec["scale"])
	c.add_child(body)
	var mat := Materials.toon(0.015)
	var leg_mesh := _leg_mesh(bug)
	for leg: Dictionary in bug.spec["legs"]:
		var pivot := Node3D.new()
		var hip: Vector3 = leg["hip"]
		pivot.position = hip
		pivot.rotation.z = -signf(hip.x) * 0.5 - PI
		c.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = leg_mesh
		mi.material_override = mat
		mi.layers = VfxPool.CORPSE_LAYER
		pivot.add_child(mi)
		c._legs.append(pivot)
	return c


## The curled leg mesh, built once per bug type.
static func _leg_mesh(bug: Bug) -> ArrayMesh:
	var key := bug.def.id
	if _leg_meshes.has(key):
		return _leg_meshes[key]
	var col: Color = bug.spec["leg_color"]
	var len := (float(bug.spec["upper"]) + float(bug.spec["lower"])) * 0.6
	var thick := float(bug.spec["thick"])
	var st := MeshKit.begin()
	# One curled leg: up from the hip, bent back in at the knee.
	MeshKit.add_limb(st, Vector3.ZERO, Vector3(0, len * 0.55, 0), thick, col, 6)
	MeshKit.add_limb(st, Vector3(0, len * 0.55, 0), Vector3(0, len * 0.75, len * 0.3), thick * 0.8, col.darkened(0.2), 6)
	var mesh := MeshKit.finish(st)
	_leg_meshes[key] = mesh
	return mesh


## Bug blood: acid green, leaning a little toward the shell colour.
static func ichor_color(shell: Color) -> Color:
	return Palette.ACID_GREEN.lerp(shell, 0.15).lightened(0.1)


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)


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
	# The shell cracks: shards tumble off and the body shrinks away under them.
	if _t >= CRACK_AT and not _cracked:
		_cracked = true
		if is_instance_valid(VfxPool.instance):
			VfxPool.instance.shell_crack(global_position, _color, _size)
	if _t > CRACK_AT:
		transform.basis = transform.basis.scaled(Vector3.ONE * maxf(1.0 - (_t - CRACK_AT) / 0.12, 0.01))
	if _t >= LIFE:
		queue_free()
