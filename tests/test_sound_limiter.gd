extends TestCase
## SoundLimiter: the cap on bug death crunches (at most 4 per 100 ms, nearest first).


func test_caps_sounds_per_window() -> void:
	var l := SoundLimiter.new(6, 4, 100)
	var played := 0
	for i in 50: # a wave's worth of deaths in one frame, all the same distance
		if l.admit(1000, 10.0) >= 0:
			played += 1
	assert_eq(played, 4, "only four start inside the window")
	assert_true(l.admit(1050, 10.0) < 0, "still inside the window")
	assert_true(l.admit(1101, 10.0) >= 0, "window passed, plays again")


func test_nearer_death_bumps_the_farthest() -> void:
	var l := SoundLimiter.new(6, 4, 100)
	var slots := {}
	for d in [30.0, 12.0, 20.0, 25.0]:
		slots[d] = l.admit(0, d)
	assert_true(l.admit(10, 35.0) < 0, "farther than all playing: skipped")
	var s := l.admit(10, 5.0)
	assert_eq(s, slots[30.0], "takes the farthest one's player")
	var s2 := l.admit(20, 8.0)
	assert_eq(s2, slots[25.0], "then the next farthest")


func test_uses_free_slots_round_robin() -> void:
	var l := SoundLimiter.new(6, 4, 100)
	var used := {}
	for t in 6:
		used[l.admit(t * 200, 1.0)] = true
	assert_eq(used.size(), 6, "spaced-out sounds rotate through every player")
