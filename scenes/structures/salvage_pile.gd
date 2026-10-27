class_name SalvagePile
extends StaticBody3D
## A big heap of frontier junk on a plateau. Press E on it during the build phase for scrap;
## it refills at every new build phase.

const SCRAP := 15

var cliff_id: int = 0
var available := true
var _mesh: MeshInstance3D
var _top: MeshInstance3D


## `big` makes the heap behind the house: twice the size and twice the scrap.
var scrap := SCRAP


func setup(cid: int, seed_value: int, big: bool = false) -> void:
	cliff_id = cid
	collision_layer = WorldLayout.LAYER_WORLD
	scrap = SCRAP * (2 if big else 1)
	var k := 1.25 if big else 0.45
	_mesh = MeshInstance3D.new()
	_mesh.mesh = heap_mesh(seed_value)
	_mesh.material_override = Materials.toon(0.025)
	_mesh.scale = Vector3.ONE * k
	add_child(_mesh)
	# Loose pickings on top: these are what you haul off; they reappear each daybreak.
	_top = MeshInstance3D.new()
	_top.mesh = top_mesh(seed_value + 1)
	_top.material_override = Materials.toon(0.02)
	_top.scale = Vector3.ONE * k
	add_child(_top)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.3 * k
	shape.height = 1.8 * k
	col.shape = shape
	col.position.y = 0.9 * k
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
	_top.visible = value


## The heap itself: a dirt mound buried in junk. Origin on the ground, about
## 4.6 m across and 2.6 m tall.
static func heap_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var rust := Color("#9A4E2A")
	var iron := Palette.METAL
	var tin := Palette.METAL.lightened(0.25)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(2.3, 1.5, 2.1), 6, 14, Palette.DIRT_DARK, 0.12, rng)
	# Bury the mound: plates, boards, cans and bits all over its surface.
	for i in 70:
		var u := rng.randf() * TAU
		var v := rng.randf_range(0.1, 1.35)
		var n := Vector3(cos(u) * sin(v), cos(v), sin(u) * sin(v))
		var p := Vector3(n.x * 2.3, n.y * 1.5, n.z * 2.1) * 0.97
		var b := MeshKit.basis_from_y(n) * Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
		var c := [rust, iron, tin, Palette.WOOD, Palette.WOOD_DARK, Palette.ROOF.darkened(0.2), iron.darkened(0.3)][rng.randi() % 7] as Color
		match i % 4:
			0, 1:
				MeshKit.add_box(st, Transform3D(b, p), Vector3(rng.randf_range(0.4, 0.9), 0.06, rng.randf_range(0.25, 0.6)), c, 0.02, rng)
			2:
				MeshKit.add_box(st, Transform3D(b, p), Vector3(rng.randf_range(0.8, 1.4), 0.08, 0.16), Palette.WOOD.darkened(rng.randf() * 0.2), 0.02, rng)
			3:
				MeshKit.add_cylinder(st, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), p), 0.08, 0.08, rng.randf_range(0.2, 0.5), 8, c)
	# Corrugated sheets leaning into the heap all the way round.
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, rng.randf_range(0.5, 0.9))
		var c := [rust, iron, tin, Palette.ROOF.darkened(0.2)][rng.randi() % 4] as Color
		var at := out * rng.randf_range(1.3, 1.8) + Vector3(0, 0.55, 0)
		for k in 5:
			MeshKit.add_box(st, Transform3D(b, at + b.x * (-0.4 + k * 0.2)), Vector3(0.12, 1.2, 0.05), c.darkened(0.08 * (k % 2)), 0.02, rng)
	# A half-buried steam boiler, a bathtub and an old stove.
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.25), Vector3(-0.5, 1.15, 0.3)), 0.55, 0.55, 2.0, 12, rust)
	for x: float in [-1.2, -0.5, 0.2]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 1.15, 0.3)), 0.58, 0.58, 0.08, 12, iron.darkened(0.2))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.45, 1.75, 0.3)), 0.12, 0.15, 0.6, 8, iron.darkened(0.3))
	var tub := Transform3D(Basis(Vector3.BACK, -0.35) * Basis(Vector3.UP, 0.6), Vector3(1.0, 1.0, -0.8))
	MeshKit.add_box(st, tub, Vector3(1.3, 0.45, 0.65), Palette.BONE.darkened(0.1), 0.02, rng)
	MeshKit.add_box(st, tub.translated_local(Vector3(0, 0.2, 0)), Vector3(1.15, 0.1, 0.5), Palette.METAL.darkened(0.4))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, tub.translated_local(Vector3(s * 0.5, -0.3, 0.25)), Vector3.ONE * 0.08, 3, 6, Color("#D6A74A"))
	var stove := Transform3D(Basis(Vector3.BACK, 0.4), Vector3(-1.4, 0.7, -0.9))
	MeshKit.add_box(st, stove, Vector3(0.7, 0.8, 0.6), iron.darkened(0.35), 0.02, rng)
	MeshKit.add_cylinder(st, Transform3D(stove.basis, stove * Vector3(0.1, 0.65, 0)), 0.09, 0.09, 0.6, 6, iron.darkened(0.2))
	# Barrels: one upright, one on its side, one tipped in.
	for spec: Array in [[Vector3(1.7, 0.45, 0.9), Basis()], [Vector3(-1.5, 0.4, 1.1), Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 0.3)],
			[Vector3(0.3, 1.6, -0.6), Basis(Vector3.BACK, 0.9)]]:
		var bx := Transform3D(spec[1] as Basis, spec[0] as Vector3)
		MeshKit.add_cylinder(st, bx, 0.33, 0.36, 0.9, 12, Palette.WOOD.darkened(rng.randf() * 0.2))
		for y: float in [-0.3, 0.3]:
			MeshKit.add_cylinder(st, bx.translated_local(Vector3(0, y, 0)), 0.37, 0.37, 0.05, 12, iron.darkened(0.2))
	# Wagon wheels, one stuck upright on top.
	for spec: Array in [[Vector3(0.0, 2.05, 0.6), Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, 0.1)], [Vector3(-2.0, 0.35, -0.2), Basis(Vector3.RIGHT, 1.2)]]:
		_wheel(st, Transform3D(spec[1] as Basis, spec[0] as Vector3), 0.6, Palette.WOOD_DARK, iron)
	# Pipes, rails and planks sticking out at angles.
	for i in 10:
		var a := rng.randf() * TAU
		var from := Vector3(cos(a) * rng.randf_range(0.3, 1.2), rng.randf_range(0.8, 1.6), sin(a) * rng.randf_range(0.3, 1.2))
		var to := from + Vector3(cos(a), rng.randf_range(0.2, 1.0), sin(a)).normalized() * rng.randf_range(0.9, 1.7)
		if i % 3 == 0:
			MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((to - from).normalized()), (from + to) * 0.5), Vector3(0.22, from.distance_to(to), 0.05), Palette.WOOD.lightened(rng.randf() * 0.15), 0.02, rng)
		else:
			MeshKit.add_limb(st, from, to, rng.randf_range(0.04, 0.08), [iron, rust, tin][rng.randi() % 3] as Color, 6)
	# Gears and cogs.
	for i in 4:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 1.4, 0.9 + rng.randf() * 0.5, sin(a) * 1.3)
		_gear(st, Transform3D(MeshKit.basis_from_y(Vector3(cos(a), 0.6, sin(a)).normalized()), p), rng.randf_range(0.2, 0.35), Color("#B98A3A") if i % 2 == 0 else iron)
	# A broken windmill blade and a bent street lamp on top for silhouette.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.5) * Basis(Vector3.UP, 0.8), Vector3(-0.9, 2.2, -0.2)), Vector3(0.35, 1.5, 0.05), Palette.BONE.darkened(0.2), 0.02, rng)
	MeshKit.add_limb(st, Vector3(0.9, 1.4, 0.1), Vector3(1.1, 2.7, 0.2), 0.05, iron.darkened(0.3), 6)
	MeshKit.add_limb(st, Vector3(1.1, 2.7, 0.2), Vector3(1.45, 2.6, 0.2), 0.04, iron.darkened(0.3), 6)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(1.45, 2.45, 0.2)), 0.05, 0.15, 0.25, 8, iron)
	# Tin cans and horseshoes scattered round the foot.
	for i in 16:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 2.8) + Vector3(0, 0.08, 0)
		if i % 2 == 0:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * float(rng.randi() % 2)) * Basis(Vector3.UP, a), p), 0.06, 0.06, 0.14, 8, tin)
		else:
			_horseshoe(st, Transform3D(Basis(Vector3.UP, a), p - Vector3(0, 0.06, 0)), iron.lightened(0.1))
	# A hand-painted sign on a post.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.06), Vector3(-2.4, 0.7, 1.4)), Vector3(0.08, 1.4, 0.08), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.08) * Basis(Vector3.UP, 0.5), Vector3(-2.4, 1.3, 1.4)), Vector3(0.9, 0.4, 0.05), Palette.BONE)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.08) * Basis(Vector3.UP, 0.5), Vector3(-2.39, 1.3, 1.37)), Vector3(0.7, 0.12, 0.02), Color("#B8352A"))
	return MeshKit.finish(st)


## Fresh junk on top of the heap, taken when someone salvages.
static func top_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	for i in 7:
		var p := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(1.6, 2.0), rng.randf_range(-0.8, 0.8))
		var b := Basis.from_euler(Vector3(rng.randf() * 0.8, rng.randf() * TAU, rng.randf() * 0.8))
		MeshKit.add_box(st, Transform3D(b, p), Vector3(rng.randf_range(0.3, 0.6), 0.06, rng.randf_range(0.2, 0.4)),
				[Palette.METAL, Palette.METAL.lightened(0.25), Color("#9A4E2A")][rng.randi() % 3] as Color, 0.02, rng)
	_gear(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0.5, 1.95, 0.2)), 0.22, Color("#D6A74A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 1.4), Vector3(-0.3, 1.9, -0.3)), 0.06, 0.06, 0.16, 8, Palette.METAL.lightened(0.3))
	return MeshKit.finish(st)


static func _wheel(st: SurfaceTool, xf: Transform3D, r: float, wood: Color, iron: Color) -> void:
	var prev := xf * Vector3(r, 0, 0)
	for i in 16:
		var a := TAU * float(i + 1) / 16.0
		var p := xf * Vector3(cos(a) * r, sin(a) * r, 0)
		MeshKit.add_limb(st, prev, p, 0.05, iron, 5)
		prev = p
	for i in 8:
		var a := TAU * i / 8.0
		MeshKit.add_limb(st, xf.origin, xf * Vector3(cos(a) * r, sin(a) * r, 0), 0.03, wood, 4)
	MeshKit.add_cylinder(st, Transform3D(xf.basis * Basis(Vector3.RIGHT, PI * 0.5), xf.origin), 0.1, 0.1, 0.2, 8, wood.darkened(0.2))


static func _gear(st: SurfaceTool, xf: Transform3D, r: float, col: Color) -> void:
	MeshKit.add_cylinder(st, xf, r, r, 0.06, 14, col)
	for i in 10:
		var a := TAU * i / 10.0
		MeshKit.add_box(st, Transform3D(xf.basis * Basis(Vector3.UP, -a), xf * Vector3(cos(a) * r * 1.1, 0, sin(a) * r * 1.1)), Vector3(r * 0.25, 0.06, r * 0.22), col)
	MeshKit.add_cylinder(st, xf, r * 0.25, r * 0.25, 0.08, 8, col.darkened(0.4))


static func _horseshoe(st: SurfaceTool, xf: Transform3D, col: Color) -> void:
	var prev := xf * Vector3(0.09, 0.03, 0.06)
	for i in 8:
		var a := PI * (0.15 + 1.7 * float(i + 1) / 8.0) - PI * 0.5
		var p := xf * Vector3(cos(a) * 0.09, 0.03, sin(a) * 0.09)
		MeshKit.add_limb(st, prev, p, 0.018, col, 4)
		prev = p
