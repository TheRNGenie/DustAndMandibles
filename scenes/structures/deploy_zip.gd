class_name DeployZip
extends ZipLine
## A deployed zipline (ZipRules): a taut rope from where the rider stood to the
## anchor bitten into the rock. It snaps after ZipRules.LIFE seconds (or when
## its rider sets a fourth). Not one of the house towers' lines: it stays out
## of the "zip_lines" group so ZipLine.refresh never touches it.

var rider := 0 ## peer id that set it
var born := 0.0
var _left := ZipRules.LIFE


func setup(from: Vector3, to: Vector3) -> void:
	add_to_group("deploy_zips")
	a = from
	b = to
	born = Time.get_ticks_msec() / 1000.0
	var st := MeshKit.begin()
	MeshKit.add_limb(st, a, b, 0.03, Color("#B8955A"), 5)
	# The anchor spike, and a stake where it was fired from.
	MeshKit.add_limb(st, b, b + (a - b).normalized() * 0.6, 0.08, Color("#6A6E78"), 6)
	MeshKit.add_limb(st, a + Vector3.DOWN * 1.2, a, 0.06, Palette.WOOD, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.0)
	add_child(mi)
	Audio.play_at(&"hook_bite", b, -2.0)


## Taut, no sag (it's short and freshly strung).
func point(t: float) -> Vector3:
	return a.lerp(b, t)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		Audio.play_at(&"hook_bite", b, -6.0, 0.6)
		queue_free()


static func of_rider(tree: SceneTree, peer: int) -> Array[DeployZip]:
	var out: Array[DeployZip] = []
	for n: Node in tree.get_nodes_in_group("deploy_zips"):
		var z := n as DeployZip
		if z != null and not z.is_queued_for_deletion() and z.rider == peer:
			out.append(z)
	out.sort_custom(func(x: DeployZip, y: DeployZip) -> bool: return x.born < y.born)
	return out
