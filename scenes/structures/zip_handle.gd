class_name ZipHandle
extends StaticBody3D
## The trolley handle on a house's tower platform. E: ride the zip line to the
## other house's tower (once both towers stand).

var home: Homestead


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
	if ZipLine.current(get_tree()) == null:
		return "Zip line: your partner needs a tower too"
	return "E: Ride the zip line across"


func local_interact(holding: bool) -> void:
	if holding:
		return
	var line := ZipLine.current(get_tree())
	if line == null:
		Economy.notice.emit("The zip line goes up once both houses have a tower.")
		return
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p.is_multiplayer_authority():
			var other := Homestead.of(WorldLayout.other_cliff(home.cliff_id))
			p.start_zip(line, home.cliff_id == WorldLayout.WEST, other.zip_arrival_global())
			return
