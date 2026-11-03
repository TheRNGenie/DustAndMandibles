class_name StoryStrongbox
extends StaticBody3D
## Bandits in the Bargain: a railroad payroll strongbox beside a house, full of
## sacks of silver. Dragonfly Bandits go for these first (Flier); each theft
## takes a sack (StoryDirector books it). The sacks show on the lid, so you can
## see how much is left from across the canyon.

const SACK_SPOTS: Array[Vector3] = [Vector3(-0.32, 0.86, -0.12), Vector3(0.0, 0.88, 0.1), Vector3(0.3, 0.86, -0.1),
	Vector3(-0.16, 0.86, 0.2), Vector3(0.18, 0.86, 0.22), Vector3(0.0, 1.08, -0.02),
	Vector3(-0.3, 1.04, 0.08), Vector3(0.3, 1.04, 0.1)]

var cliff_id := 0
var loot := 6
var director: StoryDirector
var _sacks: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("story_strongboxes")
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh()
	mi.material_override = Materials.toon(0.02)
	add_child(mi)
	var sack := sack_mesh()
	for i in SACK_SPOTS.size():
		var s := MeshInstance3D.new()
		s.mesh = sack
		s.material_override = Materials.toon(0.012)
		s.position = SACK_SPOTS[i]
		s.rotation.y = float(i) * 1.3
		add_child(s)
		_sacks.append(s)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.85, 0.9)
	col.shape = shape
	col.position.y = 0.42
	add_child(col)
	set_loot(loot)


func set_loot(n: int) -> void:
	loot = maxi(n, 0)
	for i in _sacks.size():
		_sacks[i].visible = i < loot


func has_loot() -> bool:
	return loot > 0


## Host (Flier): a bandit grabs a sack.
func bandit_steal(bug: Bug) -> void:
	if director != null:
		director.bandit_took(director.boxes.find(self), bug)


func interact_prompt() -> String:
	return "Payroll Strongbox: %d sack%s of railroad silver\nShoot any bandit carrying one" % [loot, "" if loot == 1 else "s"]


func local_interact(_holding: bool) -> void:
	pass


static func box_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var green := Color("#3E5A44")
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(1.2, 0.72, 0.8), green)
	for x: float in [-0.55, 0.0, 0.55]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.36, 0)), Vector3(0.07, 0.74, 0.82), Palette.METAL.darkened(0.2))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.74, 0)), Vector3(1.24, 0.06, 0.84), Palette.METAL.darkened(0.3))
	# Lock plate and a gold railroad emblem on the front.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.52, -0.41)), Vector3(0.2, 0.22, 0.03), Color("#D9A83A"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.25, -0.41)), Vector3(0.7, 0.07, 0.02), Color("#D9A83A"))
	# The lid, propped open behind.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -1.25), Vector3(0, 1.02, 0.5)), Vector3(1.2, 0.62, 0.06), green.darkened(0.15))
	return MeshKit.finish(st)


static func sack_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var cloth := Color("#C9B48A")
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(0.17, 0.15, 0.15), 6, 8, cloth)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.29, 0)), 0.06, 0.09, 0.08, 8, cloth.darkened(0.15))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.13, -0.15)), Vector3(0.12, 0.06, 0.01), Palette.OUTLINE) # the $ stencil, near enough
	return MeshKit.finish(st)
