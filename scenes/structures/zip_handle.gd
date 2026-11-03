class_name ZipHandle
extends StaticBody3D
## The trolley handle on a house's tower platform. E: ride the zip line to the
## other house's tower (once both towers stand).

var home: Homestead
## Bigger maps: a house can have a line to each neighbour; E takes them in turn.
var _turn := 0


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	col.shape = shape
	add_child(col)
	var mi := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(0.08, 1.2, 0.08), Palette.METAL)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.6, 0.08, 0.08), Palette.WOOD_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 1.2, 0)), 0.1, 0.1, 0.12, 10, Color("#D6A74A"))
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.01)
	add_child(mi)


func interact_prompt() -> String:
	var lines := ZipLine.lines_from(get_tree(), home.cliff_id)
	if lines.is_empty():
		return "Zip line: your partner needs a tower too" if WorldLayout.cliff_count() <= 2 else "Zip line: a neighbour needs a tower too"
	if lines.size() == 1:
		var z := lines[0]
		var to := z.cliff_b if z.cliff_a == home.cliff_id else z.cliff_a
		return "E: Ride the zip line across" if WorldLayout.cliff_count() <= 2 else "E: Ride the zip line to %s" % WorldLayout.map().name_of(to)
	return "E: Ride a zip line (%d lines)" % lines.size()


func local_interact(holding: bool) -> void:
	if holding:
		return
	var lines := ZipLine.lines_from(get_tree(), home.cliff_id)
	if lines.is_empty():
		Economy.notice.emit("The zip line goes up once both houses have a tower.")
		return
	var line := lines[_turn % lines.size()]
	_turn += 1
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p.is_multiplayer_authority():
			var from_a := line.cliff_a == home.cliff_id
			var other := Homestead.of(line.cliff_b if from_a else line.cliff_a)
			p.start_zip(line, from_a, other.zip_arrival_global())
			return
