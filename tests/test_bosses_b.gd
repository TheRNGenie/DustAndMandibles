extends TestCase
## Pure rules of bosses 6-10 (Hive Wagon drone cap, Stilt Strider knee turns,
## Thunder Cicada cluster pick, Bone Collector growth).

const Rules := preload("res://scenes/bugs/bosses/_rules_b.gd")


func test_wagon_burst_respects_cap() -> void:
	assert_eq(Rules.burst_size(0, 3, 36), 3)
	assert_eq(Rules.burst_size(34, 3, 36), 2)
	assert_eq(Rules.burst_size(36, 6, 36), 0)
	assert_eq(Rules.burst_size(40, 6, 36), 0)
	assert_eq(Rules.burst_size(10, 6, 36), 6)


func test_strider_knee_turns_split_turrets() -> void:
	# Over a long stretch every turret aims at a knee about half the time.
	var from := Vector3(-30.0, 60.0, 4.0)
	var knee := 0
	for i in 100:
		if Rules.knee_turn(from, float(i) * 0.5):
			knee += 1
	assert_true(knee >= 40 and knee <= 60, "knee share %d%%" % knee)
	# And at one moment, turrets in a row don't all pick the same.
	var on := 0
	for z in 10:
		if Rules.knee_turn(Vector3(-30.0, 60.0, float(z) * 2.3), 1.0):
			on += 1
	assert_true(on > 0 and on < 10, "turrets split %d/10" % on)


func test_cicada_picks_densest_cluster() -> void:
	var pts: Array[Vector3] = [Vector3(0, 0, -15), Vector3(0, 0, 10), Vector3(2, 0, 11), Vector3(1, 0, 13), Vector3(0, 0, 30)]
	var c := Rules.densest(pts, 8.0)
	assert_true(c.distance_to(Vector3(1, 0, 11.333)) < 0.05, "centre %s" % c)
	var lone: Array[Vector3] = [Vector3(5, 0, 5)]
	assert_eq(Rules.densest(lone, 8.0), Vector3(5, 0, 5))
	assert_eq(Rules.densest([] as Array[Vector3], 8.0), Vector3.ZERO)


func test_collector_growth_caps() -> void:
	var g := 1.0
	for i in 100:
		g = Rules.grown(g)
	assert_almost(g, Rules.COLLECTOR_MAX_GROW)
	assert_almost(Rules.grown(1.0), 1.0 + Rules.COLLECTOR_GROW_STEP)
