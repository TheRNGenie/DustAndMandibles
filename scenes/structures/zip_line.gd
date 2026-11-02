class_name ZipLine
extends Node3D
## The cable between the two houses' towers. It exists only while both houses
## have built their zip-line tower. Riders hang under it and slide across the
## canyon (see Player.start_zip); the cable sags a little in the middle.

const SAG := 0.05 # of the span
const SEGMENTS := 24

var a := Vector3.ZERO
var b := Vector3.ZERO


## Creates or removes the line to match the two houses.
static func refresh(tree: SceneTree) -> void:
	var w := Homestead.of(WorldLayout.WEST)
	var e := Homestead.of(WorldLayout.EAST)
	var existing: ZipLine = null
	for n: Node in tree.get_nodes_in_group("zip_lines"):
		existing = n as ZipLine
	var want := w != null and e != null and w.tower and e.tower
	if not want:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var line := ZipLine.new()
	line.name = "ZipLine"
	w.get_parent().add_child(line)
	line.setup(w.zip_anchor_global(), e.zip_anchor_global())


static func current(tree: SceneTree) -> ZipLine:
	for n: Node in tree.get_nodes_in_group("zip_lines"):
		if not (n as Node).is_queued_for_deletion():
			return n as ZipLine
	return null


## A point on the cable, t from 0 (west) to 1 (east).
func point(t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * a.distance_to(b) * SAG * 4.0 * t * (1.0 - t)


func setup(from: Vector3, to: Vector3) -> void:
	add_to_group("zip_lines")
	a = from
	b = to
	var st := MeshKit.begin()
	var prev := point(0.0)
	for i in SEGMENTS:
		var p := point(float(i + 1) / SEGMENTS)
		MeshKit.add_limb(st, prev, p, 0.035, Color("#4A4E58"), 5)
		prev = p
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.0)
	add_child(mi)
	Audio.play_at(&"build", a)
