class_name LegBatch
extends RefCounted
## Every bug piece of one mesh (leg segments, bodies, wings) drawn as one
## MultiMesh, so hundreds of bugs cost a handful of draw calls instead of ~30
## each. LegRig and Bug ask for slots and write world transforms into them; a
## freed or hidden slot is scaled to zero.
## Glide: bugs that update only a few times a second (BugManager turns) would
## step. Each slot also carries custom data (the bug's world velocity in m per
## physics tick, and the glide clock tick its glide ends at), and the batch
## shaders (shaders/bug_glide.gdshaderinc) draw it that far back along its
## motion, so between updates it slides at render frame rate from where it was
## drawn to where it is. Costs nothing per frame on the CPU (one global shader
## parameter, set by BugManager); hit tests stay on the real positions.

const START := 512

## mesh -> batch (one per mesh, and the meshes are shared per leg colour).
static var _batches: Dictionary = {}

var mm: MultiMesh
var node: MultiMeshInstance3D
var _free: Array[int] = []
var _used := 0

static var _zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -10000, 0))
## The glide of the bug whose pieces are being written now (Bug sets it around
## its writes; Color() = drawn where written).
static var motion := Color()
## The glide clock's zero (physics frames), so the shader's float32 clock stays precise.
static var glide_base := -1


static func of(mesh: Mesh, mat: Material, tree_root: Node, shadows: bool = false) -> LegBatch:
	var b: LegBatch = _batches.get(mesh)
	if b == null or not is_instance_valid(b.node) or not b.node.is_inside_tree():
		b = LegBatch.new()
		b.mm = MultiMesh.new()
		b.mm.transform_format = MultiMesh.TRANSFORM_3D
		b.mm.use_custom_data = true
		b.mm.mesh = mesh
		b.mm.instance_count = START
		b.mm.visible_instance_count = 0
		b.node = MultiMeshInstance3D.new()
		b.node.name = "LegBatch"
		b.node.multimesh = b.mm
		b.node.material_override = mat
		b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Bugs roam the whole canyon: never cull the batch as a whole.
		b.node.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1500, 4000))
		tree_root.add_child(b.node)
		_batches[mesh] = b
	return b


## The glide clock (physics ticks since glide_base): `now` at the tick being
## run; render_now() between ticks (what the shader is given each frame).
static func glide_tick() -> int:
	if glide_base < 0:
		glide_base = Engine.get_physics_frames()
	return Engine.get_physics_frames() - glide_base


static func render_now() -> float:
	return float(glide_tick()) + Engine.get_physics_interpolation_fraction()


## Sets the clock the batch shaders glide by (once a frame, BugManager).
static func publish_clock() -> void:
	RenderingServer.global_shader_parameter_set(&"bug_glide_now", render_now())


## The glide for a piece now (tick `now`) at `to` that was drawn at `drawn`,
## arriving `ticks` ticks from now (the gap since its last update).
static func glide_from(drawn: Vector3, to: Vector3, now: int, ticks: int) -> Color:
	var v := (to - drawn) / float(maxi(ticks, 1))
	return Color(v.x, v.y, v.z, float(now + maxi(ticks, 1)))


## The glide length (ticks) to use next, from the last estimate and the gap
## just seen: smoothed, so one early turn after a late one doesn't make the bug
## dash to catch up (the turn scheduler's gaps are steady per detail level).
static func next_gap(est: float, ticks: int) -> float:
	return lerpf(est, float(ticks), 0.5)


## The world offset a slot with this custom data is drawn at now (the shader's
## sum, for debugging, and for things that must match the drawn body).
static func glide_offset(c: Color, now: float = NAN) -> Vector3:
	var t := render_now() if is_nan(now) else now
	if c.a <= t:
		return Vector3.ZERO
	return -Vector3(c.r, c.g, c.b) * (c.a - t)


func take() -> int:
	var i: int
	if not _free.is_empty():
		i = _free.pop_back()
	else:
		if _used >= mm.instance_count:
			# Resizing a MultiMesh clears it: keep what's drawn.
			var keep := mm.buffer
			mm.instance_count = mm.instance_count * 2
			keep.resize(mm.instance_count * 16) # 12 transform + 4 custom floats
			mm.buffer = keep
		i = _used
		_used += 1
		mm.visible_instance_count = _used
	hide(i)
	return i


func give_back(i: int) -> void:
	if not is_instance_valid(node):
		return
	hide(i)
	_free.append(i)


## Written straight to the MultiMesh (several times cheaper from script than
## filling a float buffer by hand); the renderer uploads only what changed.
func put(i: int, t: Transform3D) -> void:
	mm.set_instance_transform(i, t)
	mm.set_instance_custom_data(i, motion)


func hide(i: int) -> void:
	mm.set_instance_transform(i, _zero)
	mm.set_instance_custom_data(i, Color())
