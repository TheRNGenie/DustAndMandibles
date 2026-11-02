extends TestCase
## WavePlanner.plan(): totals, determinism, bounds, the boss wave and disabled bugs.


func _active_defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		out.append(Defs.bug(id))
	return out


func _total(plan: Dictionary) -> int:
	var n := 0
	for g: Dictionary in plan["groups"]:
		n += int(g["count"])
	return n


func test_total_matches_bug_count_every_wave() -> void:
	var cfg := Defs.WAVE_CONFIG
	for seed_value: int in [1, 2, 3, 99, 12345]:
		var p := WavePlanner.new(cfg, _active_defs(), seed_value)
		for w in range(1, 16):
			var plan := p.plan(w)
			assert_eq(_total(plan), cfg.bug_count(w), "wave %d seed %d" % [w, seed_value])


func test_same_seed_same_plan() -> void:
	var a := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 777).plan(6)
	var b := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 777).plan(6)
	assert_eq(str(a), str(b))


func test_groups_are_in_bounds() -> void:
	var cfg := Defs.WAVE_CONFIG
	var p := WavePlanner.new(cfg, _active_defs(), 5)
	for w in range(1, 13):
		var plan := p.plan(w)
		var pulses := int(plan["pulses"])
		# Each wave shape has its own pulse schedule (steady = many, rush = a few close together).
		assert_true(pulses >= 1 and pulses == (plan["pulse_times"] as Array).size(), "pulses %d wave %d" % [pulses, w])
		for g: Dictionary in plan["groups"]:
			assert_true(int(g["count"]) >= 1, "count >= 1 wave %d" % w)
			assert_true(int(g["cliff"]) == WorldLayout.WEST or int(g["cliff"]) == WorldLayout.EAST, "cliff wave %d" % w)
			assert_true(int(g["lane"]) >= 0 and int(g["lane"]) < WorldLayout.LANE_Z.size(), "lane wave %d" % w)
			assert_true(int(g["pulse"]) >= 0 and int(g["pulse"]) < pulses, "pulse wave %d" % w)
			var d := Defs.bug(StringName(g["bug"]))
			assert_true(d != null, "known bug %s" % g["bug"])
			if d != null:
				assert_true(d.first_wave <= w, "%s not unlocked in wave %d" % [d.id, w])


func test_disabled_bugs_never_planned() -> void:
	var p := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 11)
	for w in range(1, 15):
		for g: Dictionary in p.plan(w)["groups"]:
			assert_false(Defs.DISABLED_BUGS.has(StringName(g["bug"])), "wave %d planned %s" % [w, g["bug"]])


func test_boss_wave_has_exactly_one_boss() -> void:
	for seed_value: int in [1, 2, 3]:
		var p := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), seed_value)
		for w in range(1, 13):
			var bosses := 0
			for g: Dictionary in p.plan(w)["groups"]:
				if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS:
					bosses += int(g["count"])
			var boss_wave := false
			for d: BugDef in _active_defs():
				# The boss comes the wave it unlocks, and on every boss wave after that.
				if d.behavior == BugDef.Behavior.BOSS and (d.first_wave == w or (p.shape_for(w) == WavePlanner.BOSS and d.first_wave <= w)):
					boss_wave = true
			assert_eq(bosses, 1 if boss_wave else 0, "wave %d seed %d" % [w, seed_value])


func test_spiderlings_are_never_planned() -> void:
	# Spiderlings hatch from brood mothers (first_wave 99, cost 0): never in a plan.
	var p := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 4)
	for w in range(1, 15):
		for g: Dictionary in p.plan(w)["groups"]:
			assert_true(StringName(g["bug"]) != &"spiderling", "wave %d" % w)


func test_heavier_cliff() -> void:
	assert_eq(WavePlanner.heavier_cliff(0.5), -1)
	assert_eq(WavePlanner.heavier_cliff(0.6), WorldLayout.WEST)
	assert_eq(WavePlanner.heavier_cliff(0.35), WorldLayout.EAST)
