class_name TutorialPickup
extends StaticBody3D
## Tutorial (Logan): a piece of your gear lying on a surface in the house (the
## revolver beside the ledger, the crop bag and grapple on the table). E takes it;
## TutorialRun hands it over and moves on.

signal taken(kind: StringName)

var kind: StringName = &""
var label := ""


static func make(what: StringName, caption: String, at: Vector3, yaw: float = 0.0) -> TutorialPickup:
	var p := TutorialPickup.new()
	p.kind = what
	p.label = caption
	p.position = at
	p.rotation.y = yaw
	return p


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_TRAP
	collision_mask = 0
	var holder := Node3D.new()
	add_child(holder)
	var model: Node3D = null
	match kind:
		&"revolver":
			model = GunModels.whole(&"revolver", 0.006)
			holder.rotation = Vector3(0.0, 0.0, PI * 0.5) # lying on its side
			holder.scale = Vector3.ONE * 1.5
		&"crop_bag":
			var mi := MeshInstance3D.new()
			mi.mesh = AmmoSackBuilder.sack(&"")
			mi.material_override = Materials.toon(0.006)
			model = mi
			holder.scale = Vector3.ONE * 0.6
		&"grapple":
			model = GunModels.make(&"grapple")
			holder.rotation = Vector3(0.0, 0.0, PI * 0.5)
			holder.scale = Vector3.ONE * 1.5
	if model != null:
		holder.add_child(model)
	# A small warm glint so it reads as something to take.
	var glow := OmniLight3D.new()
	glow.light_color = Palette.GLOW_YELLOW
	glow.light_energy = 0.35
	glow.omni_range = 1.2
	glow.position.y = 0.3
	add_child(glow)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.35, 0.6)
	col.shape = shape
	col.position.y = 0.12
	add_child(col)


func interact_prompt() -> String:
	return "E: take the %s" % label


func local_interact(holding: bool) -> void:
	if holding:
		return
	taken.emit(kind)
	queue_free()
