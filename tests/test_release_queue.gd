extends TestCase
## A pulse comes out in small mixed chunks, not one huge column of one kind.


func test_big_groups_split_across_lanes() -> void:
	var c := ReleaseQueue.chunks(&"dust_mite", 30, 1, 2, 0)
	var total := 0
	var lanes := {}
	for x: Array in c:
		assert_true(int(x[1]) <= ReleaseQueue.CHUNK)
		total += int(x[1])
		lanes[int(x[3])] = true
	assert_eq(total, 30)
	assert_true(lanes.size() >= 4, "spread over the lanes")


func test_kinds_are_dealt_in_turn() -> void:
	var a := ReleaseQueue.chunks(&"dust_mite", 24, 0, 0, 0)
	var b := ReleaseQueue.chunks(&"dragonfly_bandit", 16, 0, 0, 0)
	var out := ReleaseQueue.interleave([a, b])
	assert_eq(out.size(), a.size() + b.size())
	assert_eq(StringName(out[0][0]), &"dust_mite")
	assert_eq(StringName(out[1][0]), &"dragonfly_bandit")
	assert_eq(StringName(out[2][0]), &"dust_mite")
