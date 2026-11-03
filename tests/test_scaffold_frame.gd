extends TestCase
## Scaffolds go up round a turret, not under it: the first turret stands on the
## low deck inside the bottom storey, later ones on the floors above, and the
## frame always rises a full storey above the top turret. Also the grapple's
## reach across the widest gaps.


func test_first_turret_stands_inside_the_frame() -> void:
	assert_eq(ScaffoldNode.turret_height(0), 0.0, "bare ground: no frame")
	assert_eq(ScaffoldNode.turret_height(1), ScaffoldNode.DECK, "level 1: the low deck inside the frame")
	assert_true(ScaffoldNode.turret_height(1) < 1.5, "no tower under the first turret")
	assert_eq(ScaffoldNode.turret_height(2) - ScaffoldNode.turret_height(1), ScaffoldNode.LEVEL_HEIGHT, "one storey per level")
	assert_eq(ScaffoldNode.turret_height(3) - ScaffoldNode.turret_height(2), ScaffoldNode.LEVEL_HEIGHT)


func test_frame_rises_a_storey_above_its_top_turret() -> void:
	for n in range(1, BuildManager.MAX_SCAFFOLD + 1):
		var top := ScaffoldNode.frame_height(n)
		assert_eq(top - ScaffoldNode.turret_height(n), ScaffoldNode.LEVEL_HEIGHT, "%d storeys: a full storey round the top gun" % n)
		var aabb := ScaffoldNode.mesh_for(n).get_aabb()
		assert_true(absf(aabb.end.y - top) < 0.15, "%d storeys: mesh top %.2f matches the frame %.2f" % [n, aabb.end.y, top])
		assert_true(aabb.position.y > -0.1, "sits on the ground")
		assert_true(aabb.size.x <= ScaffoldNode.SIZE + 0.4, "fits its cell")


func test_grapple_reaches_the_far_walls() -> void:
	# The Mesa and Buttes put the facing wall up to ~80 m from your lip.
	assert_true(Grapple.RANGE >= 85.0)
	assert_eq(Grapple.MASK & WorldLayout.LAYER_BUG, 0, "never hooks bugs")
	assert_true((Grapple.MASK & WorldLayout.LAYER_WORLD) != 0, "hooks the canyon walls")
