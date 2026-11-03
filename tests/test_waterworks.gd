extends TestCase
## Waterworks: tower filling, the tap, when the pumps run, the levers (ready-up),
## the per-cliff designs, the layout on the build grid and the save data.


func test_tower_fills_five_a_minute_while_pumping() -> void:
	assert_almost(Waterworks.fill(0.0, 60.0, true), Waterworks.FILL_PER_MIN)
	assert_almost(Waterworks.fill(0.0, 60.0, true), 5.0)
	assert_almost(Waterworks.fill(10.0, 30.0, true), 12.5)
	# Ten minutes of a running pump.
	var level := 0.0
	for i in 600:
		level = Waterworks.fill(level, 1.0, true)
	assert_almost(level, 50.0, 0.01)


func test_tower_does_not_fill_with_the_pump_off() -> void:
	assert_almost(Waterworks.fill(12.0, 300.0, false), 12.0)


func test_tower_caps_at_one_hundred() -> void:
	assert_almost(Waterworks.TANK_MAX, 100.0)
	assert_almost(Waterworks.fill(99.0, 600.0, true), 100.0)
	assert_almost(Waterworks.fill(100.0, 60.0, true), 100.0)


func test_test_runs_scale_the_fill() -> void:
	assert_almost(Waterworks.fill(0.0, 60.0, true, 2.0), 10.0)


func test_tap_fills_a_bucket_from_whats_stored() -> void:
	assert_eq(Waterworks.tap_amount(37.4), Waterworks.TAP)
	assert_eq(Waterworks.tap_amount(3.9), 3)
	assert_eq(Waterworks.tap_amount(0.99), 0)
	assert_eq(Waterworks.tap_amount(0.0), 0)
	assert_eq(Waterworks.tap_amount(5.0), 5)


func test_pumps_run_from_the_countdown_until_the_wave_ends() -> void:
	assert_false(Waterworks.pumps_on(Waterworks.PHASE_BUILD, -1.0), "build phase, nobody ready")
	assert_true(Waterworks.pumps_on(Waterworks.PHASE_BUILD, 3.0), "countdown: the engines crank up")
	assert_true(Waterworks.pumps_on(Waterworks.PHASE_WARNING, -1.0))
	assert_true(Waterworks.pumps_on(Waterworks.PHASE_WAVE, -1.0))
	assert_false(Waterworks.pumps_on(0, -1.0), "lobby")
	assert_false(Waterworks.pumps_on(4, -1.0), "game over")


func test_every_human_must_throw_their_lever() -> void:
	assert_false(Waterworks.all_thrown([1, 42], {1: true}))
	assert_true(Waterworks.all_thrown([1, 42], {1: true, 42: true}))
	assert_false(Waterworks.all_thrown([], {}), "no humans, no wave")


func test_levers_follow_each_cliffs_player() -> void:
	var cliff_of := {1: 0, 42: 2}
	var held := {0: true, 2: true, 1: true} # cliff 1 is a CPU's
	# Nobody ready: every lever up.
	var l := Waterworks.levers(4, [], cliff_of, {}, false, held)
	assert_eq(l, [false, false, false, false] as Array[bool])
	# The player on cliff 2 throws theirs.
	l = Waterworks.levers(4, [42], cliff_of, {}, false, held)
	assert_eq(l, [false, false, true, false] as Array[bool])
	# The CPU on cliff 1 throws its own.
	l = Waterworks.levers(4, [42], cliff_of, {1: true}, false, held)
	assert_eq(l, [false, true, true, false] as Array[bool])
	# Everyone in: the empty cliff's lever drops with them.
	l = Waterworks.levers(4, [1, 42], cliff_of, {1: true}, true, held)
	assert_eq(l, [true, true, true, true] as Array[bool])


func test_each_cliff_gets_its_own_design() -> void:
	var seen := {}
	for cid in 4:
		seen[Waterworks.style_of(cid)] = true
	assert_eq(seen.size(), 4, "four cliffs, four different wells and towers")
	assert_eq(Waterworks.style_of(0), Waterworks.style_of(4))


func test_waterworks_are_grouped_and_off_the_build_grid() -> void:
	var spots: Array[Vector2] = [Buildable.WELL, Buildable.PUMP, Buildable.GENERATOR, Buildable.WATER_TOWER, Buildable.WINDMILL]
	# All on the same side of the yard as each other (the far side from the field and the scrap heap).
	for p in spots:
		assert_true(p.y < Buildable.HOUSE_Z - Buildable.HOUSE_HALF_W, "%s is left of the house" % str(p))
		assert_true(p.distance_to(Buildable.GENERATOR) < 8.0, "%s is near the generator" % str(p))
	# Nobody can build on top of the generator.
	var g := Buildable.cell_of(Buildable.GENERATOR.x, Buildable.GENERATOR.y)
	assert_eq(Buildable.zone(g), Buildable.Zone.LANDMARK)
	assert_false(Buildable.zone_ok(&"gatling_post", g))


func test_saved_waterworks_round_trip() -> void:
	var raw := {"waterworks": {"0": {"tank": 37.5, "lever": true}, "1": {"tank": 250.0}}, "map": "canyon"}
	var d := RunSave.decode(JSON.stringify(raw))
	var w: Dictionary = d["waterworks"]
	assert_eq(w.size(), 2)
	assert_almost(float(w[0]["tank"]), 37.5)
	assert_true(bool(w[0]["lever"]))
	assert_almost(float(w[1]["tank"]), 100.0, 0.001, "clamped to the tank")
	assert_false(bool(w[1]["lever"]))
	# Older saves: empty towers, levers up, one entry per cliff of the map.
	var old := RunSave.decode(JSON.stringify({"map": "buttes"}))
	assert_eq((old["waterworks"] as Dictionary).size(), 4)
	assert_almost(float(old["waterworks"][3]["tank"]), 0.0)


func test_saved_builds_keep_their_cliff_on_big_maps() -> void:
	var raw := {"map": "buttes", "builds": [{"type": "gatling_post", "cliff": 3, "row": 0, "col": 5}]}
	var d := RunSave.decode(JSON.stringify(raw))
	assert_eq(int((d["builds"] as Array)[0]["cliff"]), 3)


func test_rumble_then_bugs_a_few_seconds_later() -> void:
	# The ground rumbles 3-4 s once the pumps run, and the bugs come out 2-3 s after it.
	assert_true(Waterworks.RUMBLE_TIME >= 3.0 and Waterworks.RUMBLE_TIME <= 4.0)
	assert_true(Waterworks.EMERGE_DELAY >= 2.0 and Waterworks.EMERGE_DELAY <= 3.0)
	assert_almost(Waterworks.warning_time(1.0), Waterworks.RUMBLE_TIME + Waterworks.EMERGE_DELAY)
	# --fast test runs shorten it (never below half).
	assert_almost(Waterworks.warning_time(0.15), (Waterworks.RUMBLE_TIME + Waterworks.EMERGE_DELAY) * 0.5)
	assert_almost(Waterworks.rumble_time(0.15), Waterworks.RUMBLE_TIME * 0.5)


func test_rumble_shake_is_light_and_ramps() -> void:
	var s := 3.5
	assert_almost(Waterworks.rumble_shake(0.0, s), 0.0)
	assert_almost(Waterworks.rumble_shake(s, s), 0.0)
	assert_almost(Waterworks.rumble_shake(-1.0, s), 0.0)
	assert_almost(Waterworks.rumble_shake(s + 1.0, s), 0.0)
	var mid := Waterworks.rumble_shake(s * 0.5, s)
	assert_true(mid > 0.2 and mid <= 0.35, "light: %.2f" % mid)
	assert_true(Waterworks.rumble_shake(0.3, s) < mid, "ramps in")
