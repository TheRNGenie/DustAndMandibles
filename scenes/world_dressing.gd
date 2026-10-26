class_name WorldDressing
extends RefCounted
## Places homesteads, props, fences, nests and invisible boundary walls on the
## generated canyon. All placement is seeded so the world is the same every run.

var cliffs: CliffBuilder
var parent: Node3D
var _rng := RandomNumberGenerator.new()

## Width of the lip walkway from the plateau to the Oasis drawbridge.
const WALKWAY_D := 4.5


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
	_build_webs()
	CanyonDressing.build(parent, cliffs, 5151)
	OasisBuilder.build(parent, 4242)


## A heavy spider infestation: orb webs all over both canyon walls (thicker low
## down), sheet webs and egg sacs on the floor, and silk strung across the gap.
func _build_webs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var st := MeshKit.begin()
	for cid in 2:
		for i in 200:
			var far := i >= 160
			var z := rng.randf_range(-88.0, 88.0) if not far else rng.randf_range(92.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var y := 2.5 + pow(rng.randf(), 1.7) * 50.0
			var n := cliffs.face_normal(cid, y, z)
			var c := cliffs.face_point(cid, y, z) + n * 0.12
			WebBuilder.orb(st, rng, c, n, rng.randf_range(1.2, 4.5), rng.randf_range(0.1, 0.5))
	var floor_h := func(x: float, z: float) -> float: return cliffs.floor_height(x, z)
	for i in 130:
		var x := rng.randf_range(-17.0, 17.0)
		var z := rng.randf_range(-88.0, 88.0)
		WebBuilder.sheet(st, rng, Vector3(x, 0.0, z), rng.randf_range(1.5, 4.0), floor_h)
		if rng.randf() < 0.35:
			WebBuilder.egg_sacs(st, rng, Vector3(x, cliffs.floor_height(x, z), z))
	# Long strands slung across the canyon, sagging in the middle.
	for i in 30:
		var y := rng.randf_range(3.0, 18.0)
		var z1 := rng.randf_range(-85.0, 85.0)
		var z2 := z1 + rng.randf_range(-6.0, 6.0)
		var a := cliffs.face_point(WorldLayout.WEST, y, z1)
		var b := cliffs.face_point(WorldLayout.EAST, y + rng.randf_range(-2.0, 2.0), z2)
		var sag := rng.randf_range(2.0, 5.0)
		var prev := a
		for k in range(1, 9):
			var t := float(k) / 8.0
			var p := a.lerp(b, t) + Vector3.DOWN * sag * sin(t * PI)
			WebBuilder.strand(st, prev, p, Vector3(0, 0, 1), 0.05, Color(1, 1, 1, 0.55))
			WebBuilder.strand(st, prev, p, Vector3(0, 1, 0), 0.05, Color(1, 1, 1, 0.55))
			prev = p
	var mi := MeshInstance3D.new()
	mi.name = "SpiderWebs"
	mi.mesh = MeshKit.finish(st)
	mi.material_override = WebBuilder.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


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
	# Homestead: an enterable cabin (HouseBuilder) that builds its own mesh and collision.
	var home := Homestead.new()
	home.cliff_id = cid
	home.name = "Homestead%d" % cid
	home.position = ground(cid, Buildable.HOUSE_D, Buildable.HOUSE_Z)
	home.rotation.y = yaw
	parent.add_child(home)

	add_mesh(BuildingBuilder.water_tower(200 + cid), ground(cid, Buildable.WATER_TOWER.x, Buildable.WATER_TOWER.y), yaw, "WaterTower%d" % cid, true)
	var tower_pos := ground(cid, Buildable.WINDMILL.x, Buildable.WINDMILL.y)
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

	# The windmill's well: broken until someone pays to fix it.
	var well := WaterSource.new()
	well.name = "Well%d" % cid
	well.cliff_id = cid
	well.display_name = "Windmill well"
	well.fix_cost = 80
	well.working = false
	well.rates = Vector2(8.0, 8.0)
	well.capacity = 10
	well.collision_layer = WorldLayout.LAYER_WORLD
	var trough_col := CollisionShape3D.new()
	var trough_shape := BoxShape3D.new()
	trough_shape.size = Vector3(1.2, 0.9, 2.6)
	trough_col.shape = trough_shape
	trough_col.position.y = 0.45
	well.add_child(trough_col)
	well.position = tower_pos + Basis(Vector3.UP, yaw) * Vector3(2.0, 0.0, 0.0)
	well.rotation.y = yaw
	parent.add_child(well)

	# Starter farm field beside the house: 3 x 4 plots on the grid (2 x 2 cells each),
	# the 3-plot side along the house front, rows running toward the canyon.
	for r in Buildable.FIELD_ROWS.size():
		for c in Buildable.FIELD_COLS.size():
			var anchor := Vector2i(Buildable.FIELD_ROWS[r], Buildable.FIELD_COLS[c])
			var plot := CropPlot.new()
			plot.name = "Plot%d_%d_%d" % [cid, r, c]
			plot.setup(cid)
			plot.position = Buildable.footprint_center(cliffs, cid, &"farm_plot", anchor)
			plot.rotation.y = yaw
			parent.add_child(plot)

	# One big salvage heap against the back of the house (scrap each build phase).
	var pile := SalvagePile.new()
	pile.name = "Salvage%d" % cid
	pile.setup(cid, 800 + cid * 10, true)
	pile.position = ground(cid, Buildable.SALVAGE.x, Buildable.SALVAGE.y)
	pile.rotation.y = yaw
	parent.add_child(pile)

	_build_paths(cid)


## Packed-dirt paths on the grid's path cells: around the house and from the
## front door to the bridge walkway.
func _build_paths(cid: int) -> void:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + cid
	var half := WorldLayout.CELL * 0.5
	for row in Buildable.ROWS:
		for col in Buildable.COLS:
			var cell := Vector2i(row, col)
			if Buildable.zone(cell) != Buildable.Zone.PATH:
				continue
			# Corners follow the ground so the trail never sinks into a bump.
			var d := Buildable.LIP_MARGIN + (float(row) + 0.5) * WorldLayout.CELL
			var z := -WorldLayout.PLATEAU_WIDTH * 0.5 + (float(col) + 0.5) * WorldLayout.CELL
			var corners: Array[Vector3] = []
			for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(ground(cid, d + k.x * half, z + k.y * half) + Vector3.UP * 0.06)
			var shade := Color("#B07A4C").lerp(Color("#A5704A"), rng.randf() * 0.5)
			MeshKit.quad(st, corners[0], corners[1], corners[2], corners[3], Vector3.UP, MeshKit.vcol(shade))
			MeshKit.quad(st, corners[0], corners[3], corners[2], corners[1], Vector3.UP, MeshKit.vcol(shade))
	var mi := MeshInstance3D.new()
	mi.name = "Paths%d" % cid
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _scatter_props(cid: int) -> void:
	# Cacti and rocks outside the build area, a few small rocks inside it.
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 200:
		tries += 1
		var d := _rng.randf_range(4.0, 55.0)
		var z := _rng.randf_range(-70.0, 70.0)
		var in_build_area := d < WorldLayout.PLATEAU_DEPTH + 2.0 and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 2.0
		if in_build_area or _in_walkway(d, z):
			continue
		add_mesh(PropBuilder.cactus(_rng.randi()), ground(cid, d, z), _rng.randf() * TAU, "", true)
		placed += 1
	for i in 26:
		var d := _rng.randf_range(2.0, 58.0)
		var z := _rng.randf_range(-80.0, 80.0)
		var size := _rng.randf_range(0.5, 2.6)
		if d < WorldLayout.PLATEAU_DEPTH + 1.0 and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 1.0:
			continue # the build area stays clear
		if _in_walkway(d, z):
			continue
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
## Fence along the playable boundary plus invisible walls. The canyon side stays
## open so players can lean over (and fall off) the lip, and a walkway along the
## lip leads south to the drawbridge over to the Oasis.
func _build_boundary(cid: int) -> void:
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	var depth := WorldLayout.PLATEAU_DEPTH
	var walk_end := OasisBuilder.CENTER_Z - 3.5
	var pts: Array[Vector3] = []
	pts.append(ground(cid, 0.6, walk_end))
	pts.append(ground(cid, WALKWAY_D, walk_end))
	var z := walk_end + 2.5
	while z < -half_w:
		pts.append(ground(cid, WALKWAY_D, z))
		z += 2.5
	var d := WALKWAY_D
	while d < depth:
		pts.append(ground(cid, d, -half_w))
		d += 2.5
	z = -half_w
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
	var gap := WorldLayout.HALF_GAP
	_add_wall(Vector3(s * (gap + depth + 0.5), y, 0), Vector3(1, wall_h, WorldLayout.PLATEAU_WIDTH + 2.0))
	_add_wall(Vector3(s * (gap + (WALKWAY_D + depth + 2.0) * 0.5), y, -half_w - 0.5), Vector3(depth + 2.0 - WALKWAY_D, wall_h, 1))
	_add_wall(Vector3(s * (gap + (depth + 2.0) * 0.5 - 1.0), y, half_w + 0.5), Vector3(depth + 4.0, wall_h, 1))
	# Walkway: inner wall along it and a cap at its far end.
	var walk_len := -half_w - walk_end
	_add_wall(Vector3(s * (gap + WALKWAY_D + 0.5), y, (-half_w + walk_end) * 0.5), Vector3(1, wall_h, walk_len + 1.0))
	_add_wall(Vector3(s * (gap + WALKWAY_D * 0.5 - 1.0), y, walk_end - 0.5), Vector3(WALKWAY_D + 2.0, wall_h, 1))


static func _in_walkway(d: float, z: float) -> bool:
	return d < WALKWAY_D + 2.0 and z < -WorldLayout.PLATEAU_WIDTH * 0.5 + 1.0 and z > OasisBuilder.CENTER_Z - 6.0


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
