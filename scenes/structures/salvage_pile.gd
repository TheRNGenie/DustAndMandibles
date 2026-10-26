class_name SalvagePile
extends StaticBody3D
## A heap of wreckage on a plateau. Press E on it during the build phase for scrap;
## it refills at every new build phase.

const SCRAP := 15

var cliff_id: int = 0
var available := true
var _mesh: MeshInstance3D


## `big` makes the heap behind the house: twice the size and twice the scrap.
var scrap := SCRAP


func setup(cid: int, seed_value: int, big: bool = false) -> void:
	cliff_id = cid
	collision_layer = WorldLayout.LAYER_WORLD
	var k := 1.8 if big else 1.0
	scrap = SCRAP * (2 if big else 1)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _pile_mesh(seed_value)
	_mesh.material_override = Materials.toon()
	_mesh.scale = Vector3(k * 1.4, k, k) if big else Vector3.ONE
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8 * k * (1.4 if big else 1.0), 0.8 * k, 1.8 * k)
	col.shape = shape
	col.position.y = 0.4 * k
	add_child(col)


func _ready() -> void:
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		if p == GameState.Phase.BUILD and multiplayer.is_server():
			_set_available.rpc(true))


func interact_prompt() -> String:
	if not available:
		return "Picked clean. Comes back next daybreak."
	if GameState.phase != GameState.Phase.BUILD:
		return "Salvage only during the build phase"
	return "E: Salvage (+%d scrap)" % scrap


func local_interact(_holding: bool) -> void:
	if multiplayer.is_server():
		_collect(multiplayer.get_unique_id())
	else:
		_request_collect.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_collect() -> void:
	if multiplayer.is_server():
		_collect(multiplayer.get_remote_sender_id())


func _collect(peer_id: int) -> void:
	if not available or GameState.phase != GameState.Phase.BUILD:
		return
	var payer := cliff_id if GameState.is_solo() else NetworkManager.cliff_of(peer_id)
	Economy.earn(payer, {&"scrap": scrap})
	_set_available.rpc(false)


@rpc("authority", "call_local", "reliable")
func _set_available(value: bool) -> void:
	if available and not value:
		Audio.play_at(&"coin", global_position)
	available = value
	_mesh.scale = Vector3.ONE if value else Vector3(1.0, 0.25, 1.0)


static func _pile_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	for i in 9:
		var p := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.1, 0.5), rng.randf_range(-0.6, 0.6))
		var b := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6))
		var color := [Palette.METAL, Palette.WOOD, Palette.METAL.darkened(0.3), Palette.ROOF][rng.randi_range(0, 3)] as Color
		MeshKit.add_box(st, Transform3D(b, p), Vector3(rng.randf_range(0.3, 0.8), 0.12, rng.randf_range(0.2, 0.5)), color, 0.03, rng)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 1.3), Vector3(0.1, 0.35, 0.1)), 0.25, 0.25, 0.6, 8, Palette.METAL)
	return MeshKit.finish(st)
