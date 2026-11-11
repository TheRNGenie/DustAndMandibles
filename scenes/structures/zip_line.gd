class_name ZipLine
extends Node3D
## The cable between the two houses' towers. It exists only while both houses
## have built their zip-line tower. Riders hang under it and slide across the
## canyon (see Player.start_zip); the cable sags a little in the middle.

const SAG := 0.05 # of the span
const SEGMENTS := 24

## The title backdrop raises and drops lines between shots without the build thunk.
static var quiet := false

var a := Vector3.ZERO
var b := Vector3.ZERO
## The houses at either end (a = cliff_a's tower).
var cliff_a := 0
var cliff_b := 1


## Which houses get a line between them: the canyon's two; on bigger maps each
## house and its neighbours round the ring.
static func pairs() -> Array:
	var n := WorldLayout.cliff_count()
	if n <= 2:
		return [[0, 1]]
	var out: Array = []
	for i in n:
		out.append([i, (i + 1) % n])
	return out


## Creates or removes the lines to match the houses' towers.
static func refresh(tree: SceneTree) -> void:
	var existing := {}
	for n: Node in tree.get_nodes_in_group("zip_lines"):
		var z := n as ZipLine
		if not z.is_queued_for_deletion():
			existing["%d_%d" % [z.cliff_a, z.cliff_b]] = z
	for pr: Array in pairs():
		var ha := Homestead.of(int(pr[0]))
		var hb := Homestead.of(int(pr[1]))
		var key := "%d_%d" % [int(pr[0]), int(pr[1])]
		var want := ha != null and hb != null and ha.tower and hb.tower
		if not want:
			if existing.has(key):
				(existing[key] as ZipLine).queue_free()
			continue
		if existing.has(key):
			continue
		var line := ZipLine.new()
		line.name = "ZipLine" if WorldLayout.cliff_count() <= 2 else "ZipLine%s" % key
		line.cliff_a = int(pr[0])
		line.cliff_b = int(pr[1])
		ha.get_parent().add_child(line)
		line.setup(ha.zip_anchor_global(), hb.zip_anchor_global())


static func current(tree: SceneTree) -> ZipLine:
	for n: Node in tree.get_nodes_in_group("zip_lines"):
		if not (n as Node).is_queued_for_deletion():
			return n as ZipLine
	return null


## Every standing line that ends at cliff `cid`'s house.
static func lines_from(tree: SceneTree, cid: int) -> Array[ZipLine]:
	var out: Array[ZipLine] = []
	for n: Node in tree.get_nodes_in_group("zip_lines"):
		var z := n as ZipLine
		if not z.is_queued_for_deletion() and (z.cliff_a == cid or z.cliff_b == cid):
			out.append(z)
	return out


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
	if not quiet:
		Audio.play_at(&"build", a)
