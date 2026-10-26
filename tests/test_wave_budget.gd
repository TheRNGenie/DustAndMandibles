extends TestCase
## Wave budget math and the planner's split between cliffs.


func _defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for d: BugDef in Defs.BUGS.values():
		out.append(d)
	return out


func test_budget_formula() -> void:
	var cfg := Defs.WAVE_CONFIG
	assert_almost(cfg.budget(1), 33.5)
	assert_almost(cfg.budget(5), 117.5)
	assert_almost(cfg.budget(10), 290.0)


func test_build_time_is_five_minutes() -> void:
	# Logan's call: 5 minutes between waves (both players readying up skips it).
	var cfg := Defs.WAVE_CONFIG
	assert_almost(cfg.build_time(1), 300.0)
	assert_almost(cfg.build_time(10), 300.0)


func test_scripted_splits() -> void:
	var cfg := Defs.WAVE_CONFIG
	assert_almost(cfg.west_share_for(1, 0.0), 0.5)
	assert_almost(cfg.west_share_for(3, 0.0), 0.4)
	assert_almost(cfg.west_share_for(9, 0.0), 0.7)


func test_unscripted_split_stays_in_range() -> void:
	var cfg := Defs.WAVE_CONFIG
	for roll: float in [0.0, 0.5, 1.0]:
		var s := cfg.west_share_for(10, roll)
		assert_true(s >= 0.3 - 0.001 and s <= 0.7 + 0.001, "share %f" % s)


func test_wave1_is_mites_only_and_within_budget() -> void:
	var planner := WavePlanner.new(Defs.WAVE_CONFIG, _defs(), 42)
	var plan := planner.plan(1)
	var total := 0
	for g: Dictionary in plan["groups"]:
		assert_eq(g["bug"], &"dust_mite")
		total += int(g["count"]) * Defs.bug(g["bug"]).cost
	assert_true(total <= 34, "spent %d" % total)
	assert_true(total > 0)


func test_new_bug_appears_on_both_cliffs() -> void:
	var planner := WavePlanner.new(Defs.WAVE_CONFIG, _defs(), 7)
	var plan := planner.plan(3) # Rattler Beetle unlocks in wave 3
	var cliffs := {}
	for g: Dictionary in plan["groups"]:
		if g["bug"] == &"rattler_beetle":
			cliffs[g["cliff"]] = true
	assert_eq(cliffs.size(), 2)


func test_split_matches_share() -> void:
	var planner := WavePlanner.new(Defs.WAVE_CONFIG, _defs(), 3)
	var plan := planner.plan(9)
	var spent: Array = plan["spent"]
	assert_true(float(spent[0]) > float(spent[1]), "wave 9 is west-heavy")
