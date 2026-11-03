extends TestCase
## Story chapter 7, Down the Hole: the dynamite job's rules (BlastRules), the
## main tunnel pick, sealed tunnels, and the chapter flow's pure bits.


func test_crates_scale_with_the_posse() -> void:
	assert_eq(BlastRules.crates_needed(1), 3)
	assert_eq(BlastRules.crates_needed(2), 4)
	assert_eq(BlastRules.crates_needed(3), 5)
	assert_eq(BlastRules.crates_needed(4), 6)
	assert_eq(BlastRules.crates_needed(9), 6, "never past four riders")
	assert_eq(BlastRules.crates_needed(0), 3, "at least one rider")


func test_crates_on_the_pile() -> void:
	assert_eq(BlastRules.on_pile(4, 0, 0, 0), 4)
	assert_eq(BlastRules.on_pile(4, 1, 2, 0), 1, "set and carried ones are out")
	assert_eq(BlastRules.on_pile(4, 1, 1, 1), 1, "a dropped crate isn't back on the pile")
	assert_eq(BlastRules.on_pile(4, 3, 2, 0), 0, "never negative")


func test_hunters_come_faster_as_the_job_goes_on() -> void:
	var g0 := BlastRules.hunt_gap(0, false)
	var g3 := BlastRules.hunt_gap(3, false)
	assert_true(g3 < g0, "each charge set riles them")
	assert_eq(BlastRules.hunt_gap(20, false), BlastRules.HUNT_GAP_MIN, "floor on the gap")
	assert_eq(BlastRules.hunt_gap(0, true), BlastRules.HUNT_GAP_LIT, "a lit fuse brings them fastest")
	assert_eq(BlastRules.hunt_pack(1, false), 1)
	assert_eq(BlastRules.hunt_pack(4, true), 3)
	assert_eq(BlastRules.max_hunters(1), 6)
	assert_eq(BlastRules.max_hunters(4), 12)


func test_the_blast() -> void:
	assert_true(BlastRules.blast_damage(80.0, true) > 1000.0, "inside the tunnel: buried")
	assert_true(BlastRules.blast_damage(10.0, false) > 1000.0, "at the mouth: buried")
	assert_eq(BlastRules.blast_damage(40.0, false), BlastRules.HURT_DAMAGE, "further out: knocked about")
	assert_eq(BlastRules.blast_damage(200.0, false), 0.0, "far off: untouched")
	assert_true(BlastRules.blast_shake(0.0) > BlastRules.blast_shake(100.0))
	assert_true(BlastRules.blast_shake(1000.0) > 0.0, "everyone feels it")
	assert_eq(BlastRules.fuse_text(45.0), "0:45")
	assert_eq(BlastRules.fuse_text(4.2), "0:05")
	assert_eq(BlastRules.fuse_text(-1.0), "0:00")


func test_charge_spots_spread_down_both_walls() -> void:
	var spots := BlastRules.charge_spots(4, 9.0, 39.0)
	assert_eq(spots.size(), 4)
	assert_eq(float(spots[0][0]), 9.0, "first one near the mouth")
	assert_eq(float(spots[3][0]), 39.0, "last one at the back of the chamber")
	assert_true(float(spots[0][1]) != float(spots[1][1]), "alternating walls")
	for i in 3:
		assert_true(float(spots[i + 1][0]) > float(spots[i][0]), "deeper each time")
	assert_eq(BlastRules.charge_spots(1, 9.0, 39.0).size(), 1)
	for s: Array in BlastRules.charge_spots(6, 9.0, 39.0):
		assert_true(float(s[0]) <= 39.0 and float(s[0]) >= 9.0, "every spot inside the set")


func test_main_tunnel_is_nearest_a_rope_foot() -> void:
	var mouths: Array[Vector3] = [Vector3(-22, 0, -62), Vector3(22, 0, -58), Vector3(-22, 0, 60)]
	var feet: Array[Vector3] = [Vector3(-20, 0, -19), Vector3(20, 0, -19)]
	assert_eq(BlastRules.pick_main(mouths, feet), 1)
	var canyon := CliffBuilder.new(1234, MapDef.canyon())
	var m := canyon.main_tunnel()
	assert_true(m >= 0 and m < canyon.tunnel_count(), "a real tunnel")


func test_sealed_tunnels_are_skipped() -> void:
	var cb := CliffBuilder.new(1234, MapDef.canyon())
	var n := cb.tunnel_count()
	cb.sealed.append(2)
	assert_eq(cb.open_tunnel_index(2), 3, "the next one along")
	assert_eq(cb.open_tunnel_index(2 + n), 3, "wraps")
	assert_eq(cb.open_tunnel_index(1), 1, "open ones are untouched")
	for i in n:
		if i != 2:
			cb.sealed.append(i)
	assert_eq(cb.open_tunnel_index(5), posmod(5, n), "all sealed: no crash, falls back")


func test_the_set_sits_far_under_the_map() -> void:
	# Bug.UNDERGROUND_Y is -40: everything in the set must be well below it.
	assert_true(BlastRules.SET_DROP > 100.0)


func test_story_hold_has_no_wave() -> void:
	# A chapter whose floor job is still open waits in a build phase.
	assert_true(StoryChapter.load_id("ch3").floor_job())
	assert_true(StoryChapter.load_id("ch7").floor_job())
	assert_false(StoryChapter.load_id("ch1").floor_job(), "plain chapters don't")
	assert_false(StoryChapter.load_id("ch6").floor_job())
