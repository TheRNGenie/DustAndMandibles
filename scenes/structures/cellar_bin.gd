class_name CellarBin
extends StaticBody3D
## One bin in the root cellar's rack: holds one kind of ammo sack. Shows a sack
## for every few it holds, the crop's sack on the front and a count. Look at it
## for the count and what it loads. (The sacks themselves are in the cliff's
## stockpile; turrets take them from there.)

var crop_id: StringName = &""
var cliff_id: int = 0
var _sacks: Node3D
var _label: Label3D
var _shown := -1


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var crate := MeshInstance3D.new()
	crate.mesh = _crate_mesh()
	crate.material_override = Materials.toon_house(0.015)
	add_child(crate)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.5, 0.6)
	col.shape = box
	col.position = Vector3(0, 0.25, 0)
	add_child(col)
	_sacks = Node3D.new()
	add_child(_sacks)
	_label = Label3D.new()
	_label.font_size = 36
	_label.pixel_size = 0.0032
	_label.outline_size = 10
	_label.outline_modulate = Palette.OUTLINE
	# Painted on the crate's front board (the rack's open side is -X).
	_label.rotation.y = -PI * 0.5
	_label.position = Vector3(-0.305, 0.12, -0.07)
	add_child(_label)
	# The crop's square patch on the crate front, like the one on its sacks.
	var sign := MeshInstance3D.new()
	sign.mesh = _sign_mesh(crop_id)
	sign.material_override = Materials.toon(0.006)
	sign.rotation.y = PI * 0.5
	sign.position = Vector3(-0.3, 0.12, 0.19)
	add_child(sign)
	Economy.resources_changed.connect(_on_resources)
	_refresh()


func _exit_tree() -> void:
	if Economy.resources_changed.is_connected(_on_resources):
		Economy.resources_changed.disconnect(_on_resources)


func _on_resources(c: int) -> void:
	if c == cliff_id or c == EconomyLedger.TEAM:
		_refresh()


func _count() -> int:
	var crop := Defs.crop(crop_id)
	return Economy.amount(cliff_id, crop.load_item) if crop != null else 0


func _refresh() -> void:
	var n := _count()
	if n == _shown:
		return
	_shown = n
	var crop := Defs.crop(crop_id)
	_label.text = "%d/%d" % [n, AmmoStore.cap(cliff_id)]
	_label.modulate = crop.color.lightened(0.3) if crop != null else Color.WHITE
	for c in _sacks.get_children():
		c.queue_free()
	# One sack shows always (the bin's label, patch out); more pile in as it fills.
	var show := clampi(int(ceil(n / 4.0)), 1, 5)
	for i in show:
		var mi := MeshInstance3D.new()
		mi.mesh = AmmoSackBuilder.sack(crop_id)
		mi.material_override = Materials.toon(0.01)
		mi.scale = Vector3.ONE * 0.75
		var spots: Array[Vector3] = [Vector3(-0.08, 0.04, 0), Vector3(0.1, 0.04, 0.14), Vector3(0.1, 0.04, -0.14), Vector3(0.0, 0.22, 0.07), Vector3(0.0, 0.22, -0.08)]
		mi.position = spots[i]
		mi.rotation.y = PI * 0.5 + (0.3 if i % 2 else -0.2) # patch faces out of the rack (-X)
		mi.visible = n > 0 or i == 0
		if n == 0:
			mi.transparency = 0.6
		_sacks.add_child(mi)


func interact_prompt() -> String:
	var crop := Defs.crop(crop_id)
	if crop == null:
		return ""
	var text := "%s ammo sacks: %d / %d" % [crop.display_name, _count(), AmmoStore.cap(cliff_id)]
	if crop.turret_family != "":
		text += "\nLoads the %s" % crop.turret_family
	text += "\nHarvest %s to fill it; E on a turret loads one" % crop.display_name.to_lower()
	return text


func local_interact(_holding: bool) -> void:
	pass


## A square cloth patch (about 15 cm) edged in the crop's colour with its picture, facing -Z.
static func _sign_mesh(crop_id: StringName) -> ArrayMesh:
	var crop := Defs.crop(crop_id)
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.004)), Vector3(0.16, 0.16, 0.006), crop.color if crop != null else Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.0)), Vector3(0.13, 0.13, 0.004), AmmoSackBuilder.PATCH)
	var mesh := MeshKit.finish(st)
	var pic := CropBuilder.picture(crop_id)
	if pic != null and pic.get_surface_count() > 0:
		var st2 := SurfaceTool.new()
		st2.append_from(mesh, 0, Transform3D())
		st2.append_from(pic, 0, Transform3D(Basis().scaled(Vector3.ONE * 2.4), Vector3(0, 0, -0.004)))
		mesh = st2.commit()
	return mesh


## An open-topped crate.
static func _crate_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.58, 0.04, 0.58), Palette.WOOD_DARK)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * 0.28, 0.12, 0)), Vector3(0.03, 0.22, 0.58), Palette.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.12, s * 0.28)), Vector3(0.58, 0.22, 0.03), Palette.WOOD)
	return MeshKit.finish(st)
