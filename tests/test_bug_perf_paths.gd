extends TestCase
## The fast paths that let 750 bugs run: the gridded cliff-face frame must match
## the exact one, the batched state sync must round-trip, and one hitbox body
## must still tell weak-spot hits from shell hits.


func _exact_frame(c: CliffBuilder, cid: int, y: float, z: float, clear: float) -> Transform3D:
	var n := c.face_normal(cid, y, z)
	var p := c.face_point(cid, y, z)
	var up := (c.face_point(cid, y + 0.5, z) - c.face_point(cid, y - 0.5, z)).normalized()
	var z_axis := -(up - n * up.dot(n)).normalized()
	return Transform3D(Basis(n.cross(z_axis).normalized(), n, z_axis), p + n * clear)


func test_face_frame_matches_exact_surface() -> void:
	var c := CliffBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst_pos := 0.0
	var worst_dot := 1.0
	for i in 300:
		var cid := i % 2
		var y := rng.randf_range(0.0, WorldLayout.CLIFF_HEIGHT - 0.1)
		var z := rng.randf_range(-19.0, 19.0)
		var fast := c.face_frame(cid, y, z, 0.4)
		var exact := _exact_frame(c, cid, y, z, 0.4)
		worst_pos = maxf(worst_pos, fast.origin.distance_to(exact.origin))
		worst_dot = minf(worst_dot, fast.basis.y.dot(exact.basis.y))
	# The face mesh itself is built on a 0.6 m x 1.0 m grid, so a 0.25 m grid
	# (a few cm off the exact noise) keeps bugs on the rock as drawn.
	assert_true(worst_pos < 0.15, "face position off by %.3f m" % worst_pos)
	assert_true(worst_dot > 0.99, "face normal off (dot %.4f)" % worst_dot)


func test_face_frame_outside_grid_falls_back() -> void:
	var c := CliffBuilder.new()
	var fast := c.face_frame(1, 10.0, 60.0, 0.3)
	var exact := _exact_frame(c, 1, 10.0, 60.0, 0.3)
	assert_true(fast.origin.distance_to(exact.origin) < 0.08)


func test_ground_height_grid_matches_exact() -> void:
	var c := CliffBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst := 0.0
	for i in 300:
		var cid := i % 2
		var p := c.plateau_point(cid, rng.randf_range(0.0, 40.0), rng.randf_range(-30.0, 30.0))
		worst = maxf(worst, absf(c.ground_height_fast(cid, p) - c.ground_height_at(cid, p)))
	assert_true(worst < 0.1, "ground height off by %.3f m" % worst)


## (States are Bug.State values: 0 climbing, 1 cresting, 2 breaching, 5 flying.)
func test_state_sync_round_trip() -> void:
	var buf := PackedByteArray()
	buf.append_array(BugSync.pack_state(17, 0, 1, 0.5, 0.25, 123.5, 33.3, -12.7, 0.0, Vector3.ZERO))
	buf.append_array(BugSync.pack_state(70000, 2, 0, 0.0, 0.0, 4.0, 0.0, 3.0, 0.0, Vector3(-40.5, 61.2, 8.25)))
	buf.append_array(BugSync.pack_state(5, 1, 0, 1.0, 1.5, 0.0, 59.6, 2.0, 0.42, Vector3.ZERO))
	var out := BugSync.unpack_states(buf)
	assert_eq(out.size(), 3)
	var a: Dictionary = out[0]
	assert_eq(int(a["id"]), 17)
	assert_eq(int(a["state"]), 0)
	assert_eq(int(a["cliff"]), 1)
	assert_almost(float(a["crouch"]), 0.5, 0.01)
	assert_almost(float(a["ride"]), 0.25, 0.01)
	assert_almost(float(a["hp"]), 123.5, 0.001)
	assert_almost(float(a["climb_y"]), 33.3, 0.05)
	assert_almost(float(a["lane_z"]), -12.7, 0.02)
	var b: Dictionary = out[1]
	assert_eq(int(b["id"]), 70000)
	assert_true((b["ground_pos"] as Vector3).is_equal_approx(Vector3(-40.5, 61.2, 8.25)))
	assert_false(b.has("climb_y"))
	var c: Dictionary = out[2]
	assert_almost(float(c["crest_t"]), 0.42, 0.001)
	assert_almost(float(c["crouch"]), 1.0, 0.001)


func test_truncated_sync_packet_is_ignored_safely() -> void:
	var buf := BugSync.pack_state(3, 5, 0, 0.0, 0.0, 9.0, 0.0, 0.0, 0.0, Vector3(1, 2, 3))
	buf.resize(buf.size() - 4)
	assert_eq(BugSync.unpack_states(buf).size(), 0)


func test_one_hitbox_tells_weak_spot_from_shell() -> void:
	var owner := Node3D.new()
	var hb := Hitbox.make_bug(owner, 1.0, Vector3(0, 0.3, 0), 0.25, Vector3(0, 0.6, -0.9))
	assert_eq(hb.get_child_count(), 2, "shell + weak spot shapes on one body")
	owner.add_child(hb)
	# Out of the tree the hitbox reads points in its owner's space.
	assert_almost(hb.multiplier_at(Vector3(0, 0.6, -1.15)), WeakSpot.MULTIPLIER, 0.001, "on the weak spot")
	assert_almost(hb.multiplier_at(Vector3(0, 0.3, 1.0)), 1.0, 0.001, "on the shell's far side")
	owner.free()
