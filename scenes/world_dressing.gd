class_name WorldDressing
extends RefCounted
## Places homesteads, props, fences, nests and invisible boundary walls on the
## generated canyon. All placement is seeded so the world is the same every run.

var cliffs: CliffBuilder
var parent: Node3D
var _rng := RandomNumberGenerator.new()


func _init(cliff_builder: CliffBuilder, parent_node: Node3D, seed_value: int = 99) -> void:
	cliffs = cliff_builder
	parent = parent_node
	_rng.seed = seed_value


func build() -> void:
	for cid in 2:
		_build_homestead_area(cid)
		_scatter_props(cid)
		_build_boundary(cid)
	_build_nests()


## Ground position on a plateau.
func ground(cid: int, d: float, z: float) -> Vector3:
	return cliffs.plateau_point(cid, d, z)


func add_mesh(mesh: ArrayMesh, pos: Vector3, yaw: float, node_name: String = "",
		collide: bool = false, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat != null else Materials.toon()
	if node_name != "":
		mi.name = node_name
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = yaw
		parent.add_child(body)
		body.add_child(mi)
		var col := CollisionShape3D.new()
		col.shape = mesh.create_convex_shape()
		body.add_child(col)
	else:
		mi.position = pos
		mi.rotation.y = yaw
		parent.add_child(mi)
	return mi


func _build_homestead_area(cid: int) -> void:
	var yaw := WorldLayout.facing_canyon_yaw(cid)
	var team := Palette.team_color(cid)
	# Homestead: its own trimesh collision so players can walk on the porch.
	var home_mesh := BuildingBuilder.homestead(100 + cid, team)
	var home := Homestead.new()
	home.cliff_id = cid
	home.name = "Homestead%d" % cid
	home.position = ground(cid, 23.0, 0.0)
	home.rotation.y = yaw
	parent.add_child(home)
	var home_mi := MeshInstance3D.new()
	home_mi.mesh = home_mesh
	home_mi.material_override = Materials.toon()
	home.add_child(home_mi)
	var home_col := CollisionShape3D.new()
	home_col.shape = home_mesh.create_trimesh_shape()
	home.add_child(home_col)

	add_mesh(BuildingBuilder.water_tower(200 + cid), ground(cid, 20.0, 13.0), yaw, "WaterTower%d" % cid, true)
	var tower_pos := ground(cid, 20.0, -13.0)
	add_mesh(BuildingBuilder.windmill_tower(300 + cid), tower_pos, yaw, "Windmill%d" % cid, true)
	var fan := Spinner.new()
	fan.mesh = BuildingBuilder.windmill_fan()
	fan.material_override = Materials.toon()
	fan.speed = 1.2 + 0.3 * float(cid)
	# The fan faces the canyon, in front of the tower head.
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	fan.position = tower_pos + Vector3(0, 8.3, 0) - forward * 0.6
	fan.rotation.y = yaw
	parent.add_child(fan)

	# Salvage piles (scrap each build phase).
	for i in 2:
		var pile := SalvagePile.new()
		pile.name = "Salvage%d_%d" % [cid, i]
		pile.setup(cid, 800 + cid * 10 + i)
		pile.position = ground(cid, 14.0 + float(i) * 6.0, -9.0 + float(i) * 18.0)
		parent.add_child(pile)

	# Barrels and crates around the homestead, plus tin cans on a crate for target practice.
	for i in 4:
		var p := ground(cid, 19.0 + _rng.randf_range(-1.0, 1.0), -5.0 - float(i) * 0.9)
		add_mesh(PropBuilder.barrel(400 + i + cid * 10), p, _rng.randf() * TAU, "", true)
	var crate_pos := ground(cid, 10.0, 6.0)
	add_mesh(PropBuilder.crate(500 + cid), crate_pos, yaw + 0.2, "TargetCrate%d" % cid, true)
	for i in 3:
		var can := TinCan.new()
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		can.position = crate_pos + Vector3(0, 0.99, 0) + side * (float(i) - 1.0) * 0.25
		parent.add_child(can)


func _scatter_props(cid: int) -> void:
	# Cacti and rocks outside the build area, a few small rocks inside it.
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 200:
		tries += 1
		var d := _rng.randf_range(4.0, 55.0)
		var z := _rng.randf_range(-70.0, 70.0)
		var in_build_area := d < WorldLayout.PLATEAU_DEPTH + 2.0 and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 2.0
		if in_build_area:
			continue
		add_mesh(PropBuilder.cactus(_rng.randi()), ground(cid, d, z), _rng.randf() * TAU, "", true)
		placed += 1
	for i in 26:
		var d := _rng.randf_range(2.0, 58.0)
		var z := _rng.randf_range(-80.0, 80.0)
		var size := _rng.randf_range(0.5, 2.6)
		if d < WorldLayout.PLATEAU_DEPTH and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5:
			size = _rng.randf_range(0.3, 0.7)
			if d < 4.0:
				continue # keep the turret line clear
		add_mesh(PropBuilder.rock(_rng.randi(), size), ground(cid, d, z) + Vector3(0, -0.2 * size, 0),
				_rng.randf() * TAU, "", size > 0.8)
	# Rocks and cacti on the canyon floor.
	if cid == 0:
		for i in 30:
			var x := _rng.randf_range(-18.0, 18.0)
			var z := _rng.randf_range(-85.0, 85.0)
			var size := _rng.randf_range(0.6, 2.4)
			add_mesh(PropBuilder.rock(_rng.randi(), size), Vector3(x, cliffs.floor_height(x, z) - 0.2, z), _rng.randf() * TAU)
		for i in 8:
			var x := _rng.randf_range(-16.0, 16.0)
			var z := _rng.randf_range(-80.0, 80.0)
			add_mesh(PropBuilder.cactus(_rng.randi()), Vector3(x, cliffs.floor_height(x, z), z), _rng.randf() * TAU)


## Fence along the playable boundary (back and sides) plus invisible walls.
## The canyon side stays open so players can lean over (and fall off) the lip.
func _build_boundary(cid: int) -> void:
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	var depth := WorldLayout.PLATEAU_DEPTH
	var pts: Array[Vector3] = []
	var d := 1.0
	while d < depth:
		pts.append(ground(cid, d, -half_w))
		d += 2.5
	var z := -half_w
	while z <= half_w + 0.01:
		pts.append(ground(cid, depth, z))
		z += 2.5
	d = depth - 2.5
	while d >= 1.0:
		pts.append(ground(cid, d, half_w))
		d -= 2.5
	add_mesh(BuildingBuilder.fence(pts, 600 + cid), Vector3.ZERO, 0.0, "Fence%d" % cid)

	var s := WorldLayout.side_sign(cid)
	var wall_h := 8.0
	var y := WorldLayout.CLIFF_HEIGHT + wall_h * 0.5 - 1.0
	var mid_d := WorldLayout.HALF_GAP + depth * 0.5
	_add_wall(Vector3(s * (WorldLayout.HALF_GAP + depth + 0.5), y, 0), Vector3(1, wall_h, WorldLayout.PLATEAU_WIDTH + 2.0))
	_add_wall(Vector3(s * mid_d, y, -half_w - 0.5), Vector3(depth + 4.0, wall_h, 1))
	_add_wall(Vector3(s * mid_d, y, half_w + 0.5), Vector3(depth + 4.0, wall_h, 1))


func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryWall"
	body.position = pos
	# Only players collide with boundary walls; bullets and bugs pass through.
	body.collision_layer = WorldLayout.LAYER_PLAYER_BLOCKER
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


## Bug nests on the canyon floor (spawn points from M2 on).
func _build_nests() -> void:
	var nest_z: Array[float] = [-28.0, 4.0, 32.0]
	for i in nest_z.size():
		var z := nest_z[i]
		var x := 6.0 * sin(z * 0.035) + _rng.randf_range(-2.0, 2.0)
		add_mesh(PropBuilder.nest_mound(700 + i), Vector3(x, cliffs.floor_height(x, z) - 0.4, z), _rng.randf() * TAU, "Nest%d" % i)


## A mesh that spins around its local Z axis (windmill fan).
class Spinner extends MeshInstance3D:
	var speed: float = 1.0

	func _process(delta: float) -> void:
		rotate_object_local(Vector3.FORWARD, speed * delta)
