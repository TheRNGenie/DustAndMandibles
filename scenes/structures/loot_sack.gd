class_name LootSack
extends StaticBody3D
## Canyon Expeditions: a dropped backpack's contents, a lumpy burlap sack tied
## at the neck, lying where its owner went down on the canyon floor. Anyone can
## E it to take what fits in their own backpack; it stays until the next wave
## ends. Spawned on every peer by the Expedition autoload, which owns the loot.

var sack_id := 0
var items: Dictionary = {}:
	set(v):
		items = v
		if is_inside_tree():
			_size_to_load()
var owner_name := ""
var _mi: MeshInstance3D
var _t := randf() * 10.0
static var _mesh: ArrayMesh


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_TRAP # walked over, still aimed at for E
	collision_mask = 0
	add_to_group("loot_sacks")
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	col.position.y = 0.4
	add_child(col)
	if _mesh == null:
		_mesh = sack_mesh()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.material_override = Materials.toon(0.02)
	add_child(_mi)
	_size_to_load()
	# A little marker flag on a stick so you can find it from up top.
	var flag := MeshInstance3D.new()
	flag.mesh = _flag_mesh()
	flag.material_override = Materials.toon(0.0)
	flag.position = Vector3(0.35, 0, 0.1)
	add_child(flag)


func _size_to_load() -> void:
	if _mi != null:
		var w := Backpack.weigh(items)
		_mi.scale = Vector3.ONE * lerpf(0.75, 1.25, clampf(float(w) / float(Backpack.CAPACITY), 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _mi != null:
		_mi.rotation.y = sin(_t * 0.7) * 0.05


func interact_prompt() -> String:
	var whose := "%s's Sack" % owner_name if owner_name != "" else "Dropped Sack"
	return "%s  -  %s\nE: take what fits in your backpack" % [whose, ExpeditionRules.describe(items)]


func local_interact(holding: bool) -> void:
	if holding:
		return
	Expedition.request_sack(sack_id)
	Audio.play_at(&"rustle", global_position, -4.0)


## A burlap sack: a squashed lumpy body, a cinched neck and a tied-off tuft.
static func sack_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := MeshKit.begin()
	var burlap := Color("#B08850")
	var dark := Color("#7A5A32")
	MeshKit.add_ellipsoid(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.32, 0)), Vector3(0.48, 0.34, 0.4), 6, 10, burlap, 0.12, rng)
	# Lumps of whatever's inside pushing at the cloth.
	for i in 5:
		var a := rng.randf() * TAU
		MeshKit.add_ellipsoid(st, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.28, 0.3 + rng.randf() * 0.12, sin(a) * 0.24)),
				Vector3(0.18, 0.16, 0.18), 4, 6, burlap.darkened(rng.randf() * 0.15), 0.2, rng)
	MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0)), 0.09, 0.12, 0.14, 8, dark, false, 0.0)
	MeshKit.add_ellipsoid(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), Vector3(0.14, 0.1, 0.14), 4, 8, burlap.lightened(0.05), 0.25, rng)
	# The rope tie.
	MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0)), 0.125, 0.125, 0.04, 10, Color("#D8C08A"), false, 0.0)
	return MeshKit.finish(st)


static func _flag_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), 0.02, 0.02, 1.5, 5, Color("#6B4A2A"), false, 0.0)
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0.22, 1.33, 0)), Vector3(0.42, 0.24, 0.02), Color("#E0483C"))
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 1.33, 0.22)), Vector3(0.02, 0.24, 0.42), Color("#E0483C"))
	return MeshKit.finish(st)
