class_name LegBatch
extends RefCounted
## Every bug piece of one mesh (leg segments, bodies, wings) drawn as one
## MultiMesh, so hundreds of bugs cost a handful of draw calls instead of ~30
## each. LegRig and Bug ask for slots and write world transforms into them; a
## freed or hidden slot is scaled to zero.

const START := 512

## mesh -> batch (one per mesh, and the meshes are shared per leg colour).
static var _batches: Dictionary = {}

var mm: MultiMesh
var node: MultiMeshInstance3D
var _free: Array[int] = []
var _used := 0

static var _zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -10000, 0))


static func of(mesh: Mesh, mat: Material, tree_root: Node, shadows: bool = false) -> LegBatch:
	var b: LegBatch = _batches.get(mesh)
	if b == null or not is_instance_valid(b.node) or not b.node.is_inside_tree():
		b = LegBatch.new()
		b.mm = MultiMesh.new()
		b.mm.transform_format = MultiMesh.TRANSFORM_3D
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


func take() -> int:
	var i: int
	if not _free.is_empty():
		i = _free.pop_back()
	else:
		if _used >= mm.instance_count:
			# Resizing a MultiMesh clears it: keep what's drawn.
			var keep := mm.buffer
			mm.instance_count = mm.instance_count * 2
			keep.resize(mm.instance_count * 12)
			mm.buffer = keep
		i = _used
		_used += 1
		mm.visible_instance_count = _used
	put(i, _zero)
	return i


func give_back(i: int) -> void:
	if not is_instance_valid(node):
		return
	put(i, _zero)
	_free.append(i)


## Written straight to the MultiMesh (several times cheaper from script than
## filling a float buffer by hand); the renderer uploads only what changed.
func put(i: int, t: Transform3D) -> void:
	mm.set_instance_transform(i, t)


func hide(i: int) -> void:
	mm.set_instance_transform(i, _zero)
