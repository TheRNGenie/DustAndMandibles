class_name LegBatch
extends RefCounted
## Every bug leg piece of one mesh drawn as one MultiMesh, so hundreds of bugs
## cost a handful of draw calls instead of ~30 each. LegRig asks for slots and
## writes world transforms into them; a freed or hidden slot is scaled to zero.

const START := 512

## mesh -> batch (one per mesh, and the meshes are shared per leg colour).
static var _batches: Dictionary = {}

var mm: MultiMesh
var node: MultiMeshInstance3D
var _free: Array[int] = []
## A CPU copy of the instance transforms, sent to the GPU once per frame.
var _buf := PackedFloat32Array()
var _dirty := false
var _used := 0

static var _zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -10000, 0))


static func of(mesh: Mesh, mat: Material, tree_root: Node) -> LegBatch:
	var b: LegBatch = _batches.get(mesh)
	if b == null or not is_instance_valid(b.node) or not b.node.is_inside_tree():
		b = LegBatch.new()
		b.mm = MultiMesh.new()
		b.mm.transform_format = MultiMesh.TRANSFORM_3D
		b.mm.mesh = mesh
		b.mm.instance_count = START
		b._buf.resize(START * 12)
		b.mm.visible_instance_count = 0
		b.node = MultiMeshInstance3D.new()
		b.node.name = "LegBatch"
		b.node.multimesh = b.mm
		b.node.material_override = mat
		b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Bugs roam the whole canyon: never cull the batch as a whole.
		b.node.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1500, 4000))
		tree_root.add_child(b.node)
		b.node.get_tree().process_frame.connect(b._flush)
		_batches[mesh] = b
	return b


func take() -> int:
	var i: int
	if not _free.is_empty():
		i = _free.pop_back()
	else:
		if _used >= mm.instance_count:
			mm.instance_count = mm.instance_count * 2
			_buf.resize(mm.instance_count * 12)
			_dirty = true
		i = _used
		_used += 1
	put(i, _zero)
	return i


func give_back(i: int) -> void:
	if not is_instance_valid(node):
		return
	put(i, _zero)
	_free.append(i)


func put(i: int, t: Transform3D) -> void:
	var o := i * 12
	var bs := t.basis
	_buf[o] = bs.x.x
	_buf[o + 1] = bs.y.x
	_buf[o + 2] = bs.z.x
	_buf[o + 3] = t.origin.x
	_buf[o + 4] = bs.x.y
	_buf[o + 5] = bs.y.y
	_buf[o + 6] = bs.z.y
	_buf[o + 7] = t.origin.y
	_buf[o + 8] = bs.x.z
	_buf[o + 9] = bs.y.z
	_buf[o + 10] = bs.z.z
	_buf[o + 11] = t.origin.z
	_dirty = true


func hide(i: int) -> void:
	put(i, _zero)


func _flush() -> void:
	if not _dirty or not is_instance_valid(node):
		return
	_dirty = false
	mm.buffer = _buf
	mm.visible_instance_count = _used
