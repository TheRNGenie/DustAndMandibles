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
