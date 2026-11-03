extends TestCase
## Waterworks meshes (WaterworksBuilder): every design builds, the tower hands
## back what WaterTower needs, the moving parts sit where Generator expects them,
## and nothing blows the vertex budget (many yards on 4-player maps).


func _verts(m: Mesh) -> int:
	if m == null or m.get_surface_count() == 0:
		return 0
	return (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func test_every_style_builds_a_tower_with_its_keys() -> void:
	for style: StringName in Waterworks.STYLES:
		var info := WaterworksBuilder.tower(style, 200)
		for key: String in ["mesh", "shapes", "tank_bottom", "tank_top", "glass_z"]:
			assert_true(info.has(key), "%s tower has %s" % [style, key])
		assert_true(info["mesh"] is ArrayMesh, "%s tower mesh" % style)
		assert_true(_verts(info["mesh"]) > 100, "%s tower mesh is not empty" % style)
		var bottom: float = info["tank_bottom"]
		var top: float = info["tank_top"]
		assert_true(top - bottom > 1.5, "%s tank is tall enough for the sight glass" % style)
		assert_true(bottom > 2.5, "%s tank is up off the ground" % style)
		var gz: float = info["glass_z"]
		assert_true(gz > 0.8 and gz < WaterworksBuilder.TAP_POS.z, "%s glass is on the front, behind the tap" % style)


func test_tower_shapes_are_shape_and_transform_pairs() -> void:
	for style: StringName in Waterworks.STYLES:
		var shapes: Array = WaterworksBuilder.tower(style, 7)["shapes"]
		assert_true(shapes.size() >= 1, "%s has collision" % style)
		for s: Array in shapes:
			assert_true(s[0] is Shape3D, "%s shape" % style)
			assert_true(s[1] is Transform3D, "%s shape transform" % style)
			# Footprint stays about a 3-4 m square (placement on the yard depends on it).
			var o: Vector3 = (s[1] as Transform3D).origin
			assert_true(absf(o.x) < 0.5 and absf(o.z) < 0.5, "%s shape is centred" % style)


func test_tower_mesh_reaches_the_tap() -> void:
	# The down-pipe runs to the tap, so the mesh reaches out to it at the front.
	for style: StringName in Waterworks.STYLES:
		var aabb := (WaterworksBuilder.tower(style, 1)["mesh"] as ArrayMesh).get_aabb()
		assert_true(aabb.end.z >= WaterworksBuilder.TAP_POS.z - 0.3, "%s pipe reaches the tap" % style)
		assert_true(aabb.position.y >= -0.05, "%s sits on the ground" % style)


func test_every_style_builds_a_pump_jack() -> void:
	for style: StringName in Waterworks.STYLES:
		var f := WellJackBuilder.frame(style, 400)
		assert_true(_verts(f["mesh"]) > 300, "%s frame" % style)
		assert_true((f["shapes"] as Array).size() >= 3, "%s collision" % style)
		assert_true(_verts(WellJackBuilder.beam(style, 410)) > 100, "%s beam" % style)
		assert_true(_verts(WellJackBuilder.crank(style)) > 100, "%s crank" % style)
		assert_true(_verts(WellJackBuilder.pitman(style)) > 20, "%s pitman" % style)
		assert_true(_verts(WellJackBuilder.drive_stand(style, Vector3(0.7, 0.75, 2.6), 0.0)) > 20, "%s drive stand" % style)
	assert_true(_verts(WellJackBuilder.rod()) > 20)
	assert_true(_verts(WellJackBuilder.drive_pulley()) > 20)
	assert_true(_verts(WellJackBuilder.tumbler()) > 20)
	assert_true(_verts(WellJackBuilder.belt(Vector3(0.7, 0.75, 2.6))) > 20)


func test_jack_parts_meet() -> void:
	# The horsehead's face sits ARM from the pivot (the rod hangs plumb there),
	# the crank turns about its origin, the frame reaches the trough and the bearings.
	for style: StringName in Waterworks.STYLES:
		var b := WellJackBuilder.beam(style, 1).get_aabb()
		assert_almost(b.position.z, -WellJackBuilder.ARM, 0.12, "%s horsehead reach" % style)
		assert_true(b.end.z >= WellJackBuilder.BEAM_GRAB.z, "%s beam reaches the pitman" % style)
		var f: ArrayMesh = WellJackBuilder.frame(style, 1)["mesh"]
		var fa := f.get_aabb().grow(0.05)
		assert_true(fa.has_point(Vector3(0, WellJackBuilder.pivot_y(style), 0)), "%s saddle at the pivot" % style)
		assert_true(fa.position.z <= WellJackBuilder.TROUGH_Z - 0.3, "%s trough" % style)
		assert_true(f.get_aabb().position.y >= -0.05, "%s sits on the ground" % style)
	var c := WellJackBuilder.crank(&"timber").get_aabb()
	assert_almost(c.get_center().y, 0.0, 0.1, "crank turns about its shaft")


func test_the_four_designs_are_different() -> void:
	var towers := {}
	var wells := {}
	for style: StringName in Waterworks.STYLES:
		towers[_verts(WaterworksBuilder.tower(style, 3)["mesh"])] = true
		wells[_verts(WellJackBuilder.frame(style, 3)["mesh"])] = true
	assert_eq(towers.size(), 4, "four different towers")
	assert_eq(wells.size(), 4, "four different wells")


func test_unknown_style_falls_back_to_timber() -> void:
	assert_eq(_verts(WaterworksBuilder.tower(&"nonsense", 5)["mesh"]), _verts(WaterworksBuilder.tower(&"timber", 5)["mesh"]))
	assert_eq(_verts(WellJackBuilder.frame(&"nonsense", 5)["mesh"]), _verts(WellJackBuilder.frame(&"timber", 5)["mesh"]))


func test_meshes_stay_inside_the_vertex_budget() -> void:
	for style: StringName in Waterworks.STYLES:
		var t := _verts(WaterworksBuilder.tower(style, 11)["mesh"])
		var w := _verts(WellJackBuilder.frame(style, 11)["mesh"]) + _verts(WellJackBuilder.beam(style, 11)) + _verts(WellJackBuilder.crank(style))
		assert_true(t < 5000, "%s tower has %d vertices" % [style, t])
		assert_true(w < 6000, "%s well has %d vertices" % [style, w])
	assert_true(_verts(WaterworksBuilder.generator_body(1)) < 2500, "generator")
	assert_true(_verts(WaterworksBuilder.breaker_box(1)) < 1200, "breaker box")


func test_generator_parts_build() -> void:
	assert_true(_verts(WaterworksBuilder.generator_body(700)) > 100)
	assert_true(_verts(WaterworksBuilder.flywheel()) > 50)
	assert_true(_verts(WaterworksBuilder.breaker_box(710)) > 50)
	assert_true(_verts(WaterworksBuilder.lever_handle()) > 20)
	assert_true(_verts(WaterworksBuilder.tap()) > 20)


func test_flywheel_spins_round_its_centre() -> void:
	# It turns round local X, so it is a disc in the YZ plane centred on the origin.
	var a := WaterworksBuilder.flywheel().get_aabb()
	assert_almost(a.get_center().y, 0.0, 0.03)
	assert_almost(a.get_center().z, 0.0, 0.03)
	assert_true(a.size.x < 0.3, "thin along its axle")
	assert_true(a.size.y > 0.7, "a big wheel")


func test_lever_pivots_at_its_origin_and_points_up() -> void:
	var a := WaterworksBuilder.lever_handle().get_aabb()
	assert_true(a.has_point(Vector3.ZERO), "the pivot is in the handle")
	assert_true(a.end.y > 0.55, "the handle runs up +Y")
	assert_true(a.position.y > -0.1, "nothing hangs below the pivot")


func test_breaker_box_holds_the_lever_pivot() -> void:
	# Generator puts the lever at the box + (0.2, 1.3, 0.24): the mount must be there.
	var a := WaterworksBuilder.breaker_box(1).get_aabb().grow(0.02)
	assert_true(a.has_point(Vector3(0.2, 1.3, 0.24)), "lever slot on the box")
	assert_true(a.end.y > 1.7, "lamp sits on top")


func test_generator_stack_tops_out_where_the_smoke_comes_from() -> void:
	var a := WaterworksBuilder.generator_body(1).get_aabb()
	assert_almost(a.end.y, 2.2, 0.15, "stack top")
	# The engine fits its collision box (1.15 x 1.25 x 1.95), give or take the stack.
	assert_true(a.size.x < 1.3 and a.size.z < 2.1, "engine footprint")


func test_cable_runs_between_its_ends() -> void:
	var flat := func(_p: Vector3) -> float: return 0.0
	var a := Vector3(0, 0.1, 0)
	var b := Vector3(6, 0.1, -3)
	var aabb := WaterworksBuilder.cable(a, b, flat).get_aabb().grow(0.05)
	assert_true(aabb.has_point(a) and aabb.has_point(b))
	assert_true(_verts(WaterworksBuilder.cable(a, b, flat, 0.06, Palette.METAL, false)) > 20, "pipe run")


func test_same_seed_same_mesh() -> void:
	for style: StringName in Waterworks.STYLES:
		assert_eq(_verts(WaterworksBuilder.tower(style, 42)["mesh"]), _verts(WaterworksBuilder.tower(style, 42)["mesh"]))
