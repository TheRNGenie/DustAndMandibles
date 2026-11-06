class_name WorldDressing
extends RefCounted
## Places homesteads, props, fences, nests and invisible boundary walls on the
## generated canyon. All placement is seeded so the world is the same every run.

var cliffs: CliffBuilder
var parent: Node3D
var _rng := RandomNumberGenerator.new()

## Width of the lip walkway from the plateau to the Oasis drawbridge.
const WALKWAY_D := 4.5

## Load times: the seeded props (cactus and rock meshes with their collision
## hulls) and the web mesh come out the same every build of a map, so the menu's
## canyon film and every later game reuse the first build's (see _memo_prop).
## key -> [mesh, convex shape or null]
static var _props: Dictionary = {}
static var _webs: Dictionary = {}


func _init(cliff_builder: CliffBuilder, parent_node: Node3D, seed_value: int = 99) -> void:
	cliffs = cliff_builder
	parent = parent_node
	_rng.seed = seed_value


func build() -> void:
	for step in build_steps():
		step.call()


## The build in pieces, one per frame for the title screen's canyon film
## (build() runs them all at once). Same order, same seeded results.
func build_steps() -> Array[Callable]:
	var steps: Array[Callable] = []
	steps.append(func() -> void:
		# Canyon Expeditions: keep the floor clear wherever a raid site could go.
		var tunnels: Array = []
		for i in cliffs.tunnel_count():
			tunnels.append(cliffs.tunnel(i))
		SitePlan.reserve_zones(tunnels)
		LoadTimes.mark("  dress: site zones"))
	for cid in WorldLayout.cliff_count():
		steps.append(func() -> void:
			_build_homestead_area(cid)
			LoadTimes.mark("  dress: homestead area %d" % cid))
		steps.append(func() -> void:
			_scatter_props(cid)
			_build_boundary(cid)
			LoadTimes.mark("  dress: props, boundary %d" % cid))
	steps.append(func() -> void:
		_build_nests()
		_build_webs()
		LoadTimes.mark("  dress: nests, webs"))
	steps.append(func() -> void:
		InfestProps.build(parent, cliffs, 9191) # eggs, resin, husks, cocoons, burrows, bones
		LoadTimes.mark("  dress: infest props"))
	if WorldLayout.map().is_canyon():
		steps.append(func() -> void:
			CanyonDressing.build(parent, cliffs, 5151)
			_build_floor_ends()
			LoadTimes.mark("  dress: canyon dressing"))
	return steps


## A heavy spider infestation: orb webs all over both canyon walls (thicker low
## down), sheet webs and egg sacs on the floor, and silk strung across the gap.
func _build_webs() -> void:
	# The same map, terrain and kept-clear ground always weave the same webs.
	var key := "%s_%d_%d" % [WorldLayout.map().id, cliffs._seed, hash([SitePlan._zones, SitePlan.story_zones])]
	var mesh: ArrayMesh = _webs.get(key)
	if mesh == null:
		mesh = _weave_webs()
		_webs[key] = mesh
	var mi := MeshInstance3D.new()
	mi.name = "SpiderWebs"
	mi.mesh = mesh
	mi.material_override = WebBuilder.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _weave_webs() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var st := MeshKit.begin()
	var m := WorldLayout.map()
	var canyon := m.is_canyon()
	for cid in m.count():
		for i in (200 if canyon else 110):
			var far := i >= 160
			var z := rng.randf_range(-88.0, 88.0) if not far else rng.randf_range(92.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			if not canyon:
				z = rng.randf_range(-m.span_v + 4.0, m.span_v - 4.0)
			var y := 2.5 + pow(rng.randf(), 1.7) * 50.0
			var n := cliffs.face_normal(cid, y, z)
			var c := cliffs.face_point(cid, y, z) + n * 0.12
			WebBuilder.orb(st, rng, c, n, rng.randf_range(1.2, 4.5), rng.randf_range(0.1, 0.5))
	var floor_h := func(x: float, z: float) -> float: return cliffs.floor_height(x, z)
	for i in 130:
		var x := rng.randf_range(-17.0, 17.0)
		var z := rng.randf_range(-88.0, 88.0)
		if not canyon:
			# Round the foot of a random wall.
			var fc := rng.randi() % m.count()
			var fp := cliffs.face_point(fc, 0.0, rng.randf_range(-m.span_v + 4.0, m.span_v - 4.0)) + m.cliff(fc).inward * rng.randf_range(2.0, 9.0)
			x = fp.x
			z = fp.z
		# (Expeditions: webs in a raid site's spot go to a scrap mesh, so the rest stay put.)
		var wst := st if not SitePlan.in_site_zone(Vector3(x, 0.0, z), 2.0) else MeshKit.begin()
		WebBuilder.sheet(wst, rng, Vector3(x, 0.0, z), rng.randf_range(1.5, 4.0), floor_h)
		if rng.randf() < 0.35:
			WebBuilder.egg_sacs(wst, rng, Vector3(x, cliffs.floor_height(x, z), z))
	# Long strands slung across the canyon, sagging in the middle.
	for i in (30 if canyon else 0):
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
	return MeshKit.finish(st)


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
		col.shape = _hull_of(mesh)
		body.add_child(col)
	else:
		mi.position = pos
		mi.rotation.y = yaw
		parent.add_child(mi)
	return mi


## A seeded prop mesh (PropBuilder), built once per key.
static func _memo_prop(key: String, make: Callable) -> ArrayMesh:
	var hit: Array = _props.get(key, [])
	if hit.is_empty():
		hit = [make.call(), null]
		_props[key] = hit
	return hit[0]


## The convex collision hull of `mesh` (kept with a memoised prop's mesh).
static func _hull_of(mesh: ArrayMesh) -> Shape3D:
	var key := str(mesh.get_meta(&"prop_key", ""))
	if key == "" or not _props.has(key):
		return mesh.create_convex_shape()
	var hit: Array = _props[key]
	if hit[1] == null:
		hit[1] = mesh.create_convex_shape()
	return hit[1]


static func _cactus(seed_value: int) -> ArrayMesh:
	var key := "cactus_%d" % seed_value
	var m := _memo_prop(key, PropBuilder.cactus.bind(seed_value))
	m.set_meta(&"prop_key", key)
	return m


static func _rock(seed_value: int, size: float) -> ArrayMesh:
	var key := "rock_%d_%s" % [seed_value, var_to_str(size)]
	var m := _memo_prop(key, PropBuilder.rock.bind(seed_value, size))
	m.set_meta(&"prop_key", key)
	return m


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

	_build_waterworks(cid)
	if ExpeditionApi.floor_open():
		_build_rope_anchor(cid) # no winch where there is no floor to go down to

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

	# One big scrap heap beside the house (scrap each build phase).
	var pile := SalvagePile.new()
	pile.name = "Salvage%d" % cid
	pile.setup(cid, 800 + cid * 10, true)
	pile.position = ground(cid, Buildable.SALVAGE.x, Buildable.SALVAGE.y)
	pile.rotation.y = yaw
	parent.add_child(pile)

	_build_paths(cid)


## Waterworks: the well (a pump jack the generator drives through a belt and a
## tumbling rod), the generator with its breaker lever and the water tower,
## grouped on one side of the yard. Each cliff's well and tower are their own
## design (Waterworks.style_of). The well works from the start.
func _build_waterworks(cid: int) -> void:
	var style := Waterworks.style_of(cid)
	var face := Buildable.WATERWORKS_FACE
	# The generator and its lever.
	var gen := Generator.new()
	gen.name = "Generator%d" % cid
	gen.cliff_id = cid
	gen.style = style
	gen.position = ground(cid, Buildable.GENERATOR.x, Buildable.GENERATOR.y)
	gen.rotation.y = _yaw_toward(cid, Buildable.GENERATOR, face)
	parent.add_child(gen)
	# The well: its beam points at the generator (crank end toward the engine).
	var well := MechWell.new()
	well.name = "Well%d" % cid # saves find it by this path
	well.cliff_id = cid
	well.style = style
	well.position = ground(cid, Buildable.WELL.x, Buildable.WELL.y)
	well.rotation.y = _yaw_toward(cid, Buildable.WELL, Buildable.GENERATOR)
	var to_local := Transform3D(Basis(Vector3.UP, well.rotation.y), well.position).affine_inverse()
	var gen_local := to_local * gen.position
	var drive := Vector3(WellJackBuilder.BULL_X, 0.75, gen_local.z - 1.3)
	well.drive_at = drive
	var drive_pc := cliffs.plateau_coords(cid, Basis(Vector3.UP, well.rotation.y) * drive + well.position)
	well.drive_ground = (to_local * ground(cid, drive_pc.x, drive_pc.y)).y
	# The tumbling rod reaches whichever end of the engine's crankshaft is nearer.
	var best := Vector3.ZERO
	for ex: float in [Generator.SHAFT_END, -Generator.SHAFT_END]: # the crankshaft's stub ends, clear of the flywheel
		var p := to_local * (gen.transform * Vector3(ex, 0.55, 0.25))
		if best == Vector3.ZERO or p.distance_to(drive) < best.distance_to(drive):
			best = p
	well.engine_at = best
	parent.add_child(well)
	# The water tower (its tap faces the yard).
	var tower := WaterTower.new()
	tower.name = "WaterTower%d" % cid
	tower.cliff_id = cid
	tower.style = style
	tower.position = ground(cid, Buildable.WATER_TOWER.x, Buildable.WATER_TOWER.y)
	tower.rotation.y = _yaw_toward(cid, Buildable.WATER_TOWER, face)
	parent.add_child(tower)
	# The pipe from the well casing out to the side and over to the tower.
	var on_ground := func(p: Vector3) -> float: return cliffs.plateau_point(cid, cliffs.plateau_coords(cid, p).x, cliffs.plateau_coords(cid, p).y).y
	var wb := Basis(Vector3.UP, well.rotation.y)
	var side := 1.0 if (to_local * tower.position).x >= 0.0 else -1.0
	var out0 := well.position + wb * Vector3(0.28 * side, 0.2, -WellJackBuilder.ARM)
	var out1 := well.position + wb * Vector3(1.05 * side, 0.1, -WellJackBuilder.ARM)
	var runs: Array = [[out0, out1], [out1, tower.position + Vector3(0, 0.1, 0)]]
	for i in runs.size():
		var r: Array = runs[i]
		var mi := MeshInstance3D.new()
		mi.name = "WaterworksLine%d_%d" % [cid, i]
		mi.mesh = WaterworksBuilder.cable(r[0], r[1], on_ground, 0.06, Palette.METAL, false)
		mi.material_override = Materials.toon(0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Canyon Expeditions: the rope winch at the yard's south corner on the lip.
func _build_rope_anchor(cid: int) -> void:
	var a := RopeAnchor.new()
	a.name = "RopeAnchor%d" % cid
	a.setup(cliffs, cid, Buildable.ROPE_ANCHOR_Z)
	parent.add_child(a)


## Canyon Expeditions: invisible walls across the canyon floor past the
## tunnels, so nobody on an expedition walks off the end of the world.
func _build_floor_ends() -> void:
	for sgn: float in [-1.0, 1.0]:
		_add_wall(Vector3(0, 10.0, sgn * (WorldLayout.PLAY_HALF_Z - 3.0)), Vector3(80.0, 24.0, 1.0))


## Yaw that turns a node's +Z from plateau spot `from` toward `to` (d, z).
func _yaw_toward(cid: int, from: Vector2, to: Vector2) -> float:
	var dir := ground(cid, to.x, to.y) - ground(cid, from.x, from.y)
	return atan2(dir.x, dir.z)


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
	# Bigger maps: only on this cliff's own top (its plateau ends sooner).
	var m := WorldLayout.map()
	var max_d := 55.0 if m.is_canyon() else 38.0
	var max_z := 70.0 if m.is_canyon() else m.span_v - 5.0
	while placed < 14 and tries < 200:
		tries += 1
		var d := _rng.randf_range(4.0, max_d)
		var z := _rng.randf_range(-max_z, max_z)
		var in_build_area := d < WorldLayout.PLATEAU_DEPTH + 2.0 and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 2.0
		if in_build_area or _in_walkway(d, z):
			continue
		add_mesh(_cactus(_rng.randi()), ground(cid, d, z), _rng.randf() * TAU, "", true)
		placed += 1
	for i in 26:
		var d := _rng.randf_range(2.0, max_d + 3.0)
		var z := _rng.randf_range(-80.0, 80.0) if m.is_canyon() else _rng.randf_range(-max_z, max_z)
		var size := _rng.randf_range(0.5, 2.6)
		if d < WorldLayout.PLATEAU_DEPTH + 1.0 and absf(z) < WorldLayout.PLATEAU_WIDTH * 0.5 + 1.0:
			continue # the build area stays clear
		if _in_walkway(d, z):
			continue
		add_mesh(_rock(_rng.randi(), size), ground(cid, d, z) + Vector3(0, -0.2 * size, 0),
				_rng.randf() * TAU, "", size > 0.8)
	# Rocks and cacti on the canyon floor.
	if cid == 0 and m.is_canyon():
		for i in 30:
			var x := _rng.randf_range(-18.0, 18.0)
			var z := _rng.randf_range(-85.0, 85.0)
			var size := _rng.randf_range(0.6, 2.4)
			var rseed := _rng.randi()
			var ryaw := _rng.randf() * TAU
			if not SitePlan.in_site_zone(Vector3(x, 0, z), size + 1.5): # Expeditions: not in a raid site
				if not _ai_scatter("rock_a" if rseed % 2 == 0 else "rock_b", Vector3(x, cliffs.floor_height(x, z) - 0.12 * size, z), ryaw, size * 1.5):
					add_mesh(_rock(rseed, size), Vector3(x, cliffs.floor_height(x, z) - 0.2, z), ryaw)
		for i in 8:
			var x := _rng.randf_range(-16.0, 16.0)
			var z := _rng.randf_range(-80.0, 80.0)
			var cseed := _rng.randi()
			var cyaw := _rng.randf() * TAU
			if not SitePlan.in_site_zone(Vector3(x, 0, z), 2.0):
				if not _ai_scatter("saguaro" if cseed % 3 != 0 else "prickly_pear", Vector3(x, cliffs.floor_height(x, z) - 0.1, z), cyaw, 0.8 + float(cseed % 7) * 0.07):
					add_mesh(_cactus(cseed), Vector3(x, cliffs.floor_height(x, z), z), cyaw)


## An AI-made canyon-floor piece (assets/scatter: rocks, cacti), visual only.
## False when the model is missing (then the old procedural one is placed).
func _ai_scatter(model: String, pos: Vector3, yaw: float, s: float) -> bool:
	var path := "res://assets/scatter/%s.glb" % model
	if not AiModels.exists(path):
		return false
	var mi := AiModels.instance(path, 0.012)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * s
	parent.add_child(mi)
	return true


## Fence along the playable boundary (back and sides) plus invisible walls.
## The canyon side stays open so players can lean over (and fall off) the lip.
## Fence along the playable boundary plus invisible walls. The canyon side stays
## open so players can lean over (and fall off) the lip.
func _build_boundary(cid: int) -> void:
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	var depth := WorldLayout.PLATEAU_DEPTH
	var pts: Array[Vector3] = []
	var z := -half_w
	var d := 0.6
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
	var fence := BuildingBuilder.fence_node(pts, cid, 600 + cid)
	if fence != null:
		fence.name = "Fence%d" % cid
		parent.add_child(fence)
	else:
		add_mesh(BuildingBuilder.fence(pts, 600 + cid), Vector3.ZERO, 0.0, "Fence%d" % cid)

	var wall_h := 8.0
	var y := WorldLayout.CLIFF_HEIGHT + wall_h * 0.5 - 1.0
	var m := WorldLayout.map()
	if m.is_canyon():
		var s := WorldLayout.side_sign(cid)
		var gap := WorldLayout.HALF_GAP
		_add_wall(Vector3(s * (gap + depth + 0.5), y, 0), Vector3(1, wall_h, WorldLayout.PLATEAU_WIDTH + 2.0))
		_add_wall(Vector3(s * (gap + (depth + 2.0) * 0.5 - 1.0), y, -half_w - 0.5), Vector3(depth + 4.0, wall_h, 1))
		_add_wall(Vector3(s * (gap + (depth + 2.0) * 0.5 - 1.0), y, half_w + 0.5), Vector3(depth + 4.0, wall_h, 1))
		return
	# Other maps: the same three walls in the cliff's own frame (the side walls
	# follow a butte's slanted edge faces).
	var c := m.cliff(cid)
	var yaw := atan2(c.along.x, c.along.z)
	var back := WorldLayout.plateau_to_world(cid, depth + 0.5, 0.0, y)
	_add_wall(back, Vector3(1, wall_h, WorldLayout.PLATEAU_WIDTH + 2.0), yaw)
	for sgn: float in [-1.0, 1.0]:
		var zz := sgn * (half_w + 0.5)
		var a := WorldLayout.plateau_to_world(cid, -1.0, zz, y)
		var b := WorldLayout.plateau_to_world(cid, depth + 3.0, zz, y)
		_add_wall((a + b) * 0.5, Vector3(1, wall_h, a.distance_to(b)), atan2(b.x - a.x, b.z - a.z))


static func _in_walkway(_d: float, _z: float) -> bool:
	return false


func _add_wall(pos: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryWall"
	body.position = pos
	body.rotation.y = yaw
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
	if not WorldLayout.map().is_canyon():
		# Bigger maps: a mound beside every other tunnel.
		for i in range(0, cliffs.tunnel_count(), 2):
			var t := cliffs.tunnel(i)
			var at: Vector3 = t[0] + (t[1] as Vector3).cross(Vector3.UP) * 6.0
			add_mesh(PropBuilder.nest_mound(700 + i), Vector3(at.x, cliffs.floor_height(at.x, at.z) - 0.4, at.z), _rng.randf() * TAU, "Nest%d" % i)
		return
	var nest_z: Array[float] = [-28.0, 4.0, 32.0]
	for i in nest_z.size():
		var z := nest_z[i]
		var x := 6.0 * sin(z * 0.035) + _rng.randf_range(-2.0, 2.0)
		add_mesh(PropBuilder.nest_mound(700 + i), Vector3(x, cliffs.floor_height(x, z) - 0.4, z), _rng.randf() * TAU, "Nest%d" % i)

