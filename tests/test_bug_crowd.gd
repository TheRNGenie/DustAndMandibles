extends TestCase
## Bugs can't overlap, and heavier bugs push lighter ones out of the way.


func test_overlapping_equal_bugs_split_evenly() -> void:
	var p := BugCrowd.pushes([Vector2(0, 0), Vector2(1, 0)] as Array[Vector2], [1.0, 1.0] as Array[float], [1.0, 1.0] as Array[float])
	assert_true(p[0].x < 0.0 and p[1].x > 0.0)
	assert_almost(-p[0].x, p[1].x)


func test_heavy_bug_shoves_light_bug() -> void:
	var w_big := BugCrowd.weight(3.0)
	var w_small := BugCrowd.weight(1.0)
	var p := BugCrowd.pushes([Vector2(0, 0), Vector2(1, 0)] as Array[Vector2], [1.5, 0.5] as Array[float], [w_big, w_small] as Array[float])
	assert_true(absf(p[1].x) > absf(p[0].x) * 20.0)


func test_apart_bugs_are_left_alone() -> void:
	var p := BugCrowd.pushes([Vector2(0, 0), Vector2(5, 0)] as Array[Vector2], [1.0, 1.0] as Array[float], [1.0, 1.0] as Array[float])
	assert_eq(p[0], Vector2.ZERO)
	assert_eq(p[1], Vector2.ZERO)


func test_stacked_bugs_still_separate() -> void:
	var p := BugCrowd.pushes([Vector2(2, 2), Vector2(2, 2)] as Array[Vector2], [1.0, 1.0] as Array[float], [1.0, 1.0] as Array[float])
	assert_true(p[0].length() > 0.1 and p[1].length() > 0.1)


func test_much_bigger_bug_crawls_over() -> void:
	var w_big := BugCrowd.weight(3.0)
	var w_small := BugCrowd.weight(1.0)
	var r := BugCrowd.resolve([Vector2(0, 0), Vector2(0.4, 0)] as Array[Vector2], [1.5, 0.5] as Array[float], [w_big, w_small] as Array[float])
	assert_true(float(r["crouch"][1]) > 0.5)
	assert_true(float(r["ride"][0]) > 0.2)
	assert_true((r["push"][0] as Vector2).length() < 0.001)


func test_similar_bugs_still_shove() -> void:
	var r := BugCrowd.resolve([Vector2(0, 0), Vector2(1, 0)] as Array[Vector2], [1.0, 0.9] as Array[float], [BugCrowd.weight(1.2), BugCrowd.weight(1.0)] as Array[float])
	assert_true(float(r["crouch"][1]) == 0.0)
	assert_true((r["push"][1] as Vector2).length() > 0.1)


## The gridded resolve finds every overlapping pair exactly once: a random crowd
## (negative coordinates, cell edges) matches checking every pair by hand.
func test_grid_matches_every_pair() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	var wt := PackedFloat32Array()
	for i in 300:
		pos.append(Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-6.0, 40.0)))
		var size := rng.randf_range(0.4, 3.0)
		rad.append(size * 0.6)
		wt.append(BugCrowd.weight(size))
	var got := BugCrowd.resolve_packed(pos, rad, wt)
	var push := PackedVector2Array()
	push.resize(pos.size())
	push.fill(Vector2.ZERO)
	var crouch := PackedFloat32Array()
	crouch.resize(pos.size())
	crouch.fill(0.0)
	var ride := PackedFloat32Array()
	ride.resize(pos.size())
	ride.fill(0.0)
	var pairs := 0
	for i in pos.size():
		for j in range(i + 1, pos.size()):
			var r := rad[i] + rad[j]
			if pos[i].distance_squared_to(pos[j]) < r * r:
				pairs += 1
				BugCrowd._pair_packed(i, j, pos, rad, wt, push, crouch, ride)
	assert_true(pairs > 50, "crowd too sparse to test (%d pairs)" % pairs)
	for i in pos.size():
		assert_true((got["push"] as PackedVector2Array)[i].distance_to(push[i]) < 0.0001, "push %d differs" % i)
		assert_almost((got["crouch"] as PackedFloat32Array)[i], crouch[i])
		assert_almost((got["ride"] as PackedFloat32Array)[i], ride[i])
