class_name CellarDoor
extends StaticBody3D
## The root cellar's slanted double doors in their stone surround, beside the
## house. E: go down into the cellar (RootCellar), your own house only.

var cellar: RootCellar


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = _doors_mesh()
	mi.material_override = Materials.toon_house(0.02)
	add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.5, 1.8)
	col.shape = box
	col.position = Vector3(0, 0.25, 0)
	add_child(col)


func interact_prompt() -> String:
	if cellar == null or not cellar.may_use(multiplayer.get_unique_id()):
		return "Your partner's root cellar"
	return "Root Cellar (ammo storage)\nE: go down"


func local_interact(holding: bool) -> void:
	if holding or cellar == null or not cellar.may_use(multiplayer.get_unique_id()):
		return
	Audio.play_at(&"chest_open", global_position, -3.0)
	cellar.move_player(cellar.bottom(), cellar.facing_bins_yaw())


## Slanted double doors on a low stone surround.
static func _doors_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 10:
		var a := float(i) / 10.0 * TAU
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.85, 0.12, sin(a) * 0.95)), Vector3(0.22, 0.16, 0.2), 3, 6, Color("#9A8A78"), 0.02, rng)
	var tilt := Basis(Vector3.BACK, 0.42)
	for s: float in [-1.0, 1.0]:
		var at := Vector3(0, 0.33, s * 0.38)
		MeshKit.add_box(st, Transform3D(tilt, at), Vector3(1.5, 0.06, 0.72), Palette.WOOD)
		for k in 3:
			MeshKit.add_box(st, Transform3D(tilt, at + tilt * Vector3(-0.5 + k * 0.5, 0.04, 0)), Vector3(0.08, 0.03, 0.7), Palette.WOOD_DARK)
		MeshKit.add_ellipsoid(st, Transform3D(tilt, at + tilt * Vector3(0.45, 0.06, -s * 0.28)), Vector3(0.05, 0.03, 0.05), 3, 6, Color("#4A4E58"))
	return MeshKit.finish(st)
