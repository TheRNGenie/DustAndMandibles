extends TestCase
## Wave shapes, kill methods, kill tallies and kill-method variants.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
const KillTally := preload("res://scenes/bugs/kill_tally.gd")
const Variants := preload("res://scenes/bugs/bug_variants.gd")


func _defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		out.append(Defs.bug(id))
	return out


func _planner(seed_value: int) -> WavePlanner:
	return WavePlanner.new(Defs.WAVE_CONFIG, _defs(), seed_value)


func _count(plan: Dictionary, accept: Callable) -> int:
	var n := 0
	for g: Dictionary in plan["groups"]:
		if accept.call(Defs.bug(StringName(g["bug"]))):
			n += int(g["count"])
	return n


func test_shapes_are_deterministic_per_seed() -> void:
	for s: int in [1, 42, 9001]:
		var a := _planner(s)
		var b := _planner(s)
		b.plan(3) # planning other waves first must not change a wave's shape
		for w in range(1, 11):
			assert_eq(a.shape_for(w), b.shape_for(w), "seed %d wave %d" % [s, w])


func test_boss_wave_every_five() -> void:
	var p := _planner(5)
	assert_eq(p.shape_for(5), WavePlanner.BOSS)
	assert_eq(p.shape_for(10), WavePlanner.BOSS)
	assert_eq(p.shape_for(1), WavePlanner.STEADY)


func test_shape_never_repeats_back_to_back() -> void:
	for s in 20:
		var p := _planner(s)
		for w in range(2, 15):
			assert_true(p.shape_for(w) != p.shape_for(w - 1), "seed %d wave %d" % [s, w])


func test_all_shapes_show_up() -> void:
	var seen := {}
	for s in 30:
		var p := _planner(s)
		for w in range(1, 11):
			seen[p.shape_for(w)] = true
	for shape: StringName in WavePlanner.SHAPE_NAMES:
		assert_true(seen.has(shape), "never saw %s" % shape)


func test_fliers_only_once_fliers_unlock() -> void:
	for s in 30:
		var p := _planner(s)
		for w in range(1, 8): # Dragonfly Bandits arrive in wave 8
			assert_true(p.shape_for(w) != WavePlanner.FLIERS, "seed %d wave %d" % [s, w])


func test_pulse_timing_by_shape() -> void:
	var cfg := Defs.WAVE_CONFIG
	var p := _planner(1)
	var rush := p.pulse_times(WavePlanner.RUSH)
	assert_true(rush[rush.size() - 1] <= 5.0, "a rush arrives within seconds")
	var two := p.pulse_times(WavePlanner.TWO_PUSHES)
	assert_almost(two[2] - two[1], cfg.push_gap - 2.0)
	var steady := p.pulse_times(WavePlanner.STEADY)
	assert_eq(steady.size(), cfg.steady_pulses)


func test_plan_pulses_match_times_and_counts_hold() -> void:
	for s in 10:
		var p := _planner(s)
		for w in range(1, 11):
			var plan := p.plan(w)
			assert_eq(int(plan["pulses"]), (plan["pulse_times"] as Array).size())
			var total := 0
			for g: Dictionary in plan["groups"]:
				assert_true(int(g["pulse"]) < int(plan["pulses"]), "pulse in range")
				total += int(g["count"])
			assert_eq(total, Defs.WAVE_CONFIG.bug_count(w), "seed %d wave %d" % [s, w])


func test_flier_wave_has_more_fliers() -> void:
	var is_flier := func(d: BugDef) -> bool: return d.behavior == BugDef.Behavior.FLIER
	var shaped := 0
	var plain := 0
	for s in 40:
		var p := _planner(s)
		for w in range(8, 10):
			var plan := p.plan(w)
			var share := float(_count(plan, is_flier)) / float(Defs.WAVE_CONFIG.bug_count(w))
			if plan["shape"] == WavePlanner.FLIERS:
				shaped += 1
				assert_true(share >= 0.2, "flier wave share %.2f" % share)
			else:
				plain += 1
	assert_true(shaped > 0 and plain > 0, "both kinds sampled")


func test_boss_wave_brings_brutes_and_boss() -> void:
	var p := _planner(3)
	var five := p.plan(5)
	assert_eq(five["shape"], WavePlanner.BOSS)
	assert_true(_count(five, func(d: BugDef) -> bool: return d.behavior == BugDef.Behavior.TANK) >= 6, "a beetle stampede")
	var ten := p.plan(10)
	assert_eq(_count(ten, func(d: BugDef) -> bool: return d.behavior == BugDef.Behavior.BOSS), 1)


func test_kill_methods() -> void:
	assert_eq(KillMethod.classify("Logan's Gatling Post"), KillMethod.BULLET)
	assert_eq(KillMethod.classify("Logan's Chili Mortar"), KillMethod.FIRE)
	assert_eq(KillMethod.classify("Sam's Dynamite Lobber"), KillMethod.BLAST)
	assert_eq(KillMethod.classify("Sam's dynamite crate"), KillMethod.BLAST)
	assert_eq(KillMethod.classify("Sam's bear trap"), KillMethod.TRAP)
	assert_eq(KillMethod.classify("Logan"), KillMethod.BULLET) # a player's gun
	assert_eq(KillMethod.classify("Lightning"), KillMethod.OTHER)
	assert_eq(KillMethod.classify("Logan's Water Cannon"), KillMethod.OTHER)


func test_variant_defs() -> void:
	var v := Defs.bug(&"rattler_beetle@bullet")
	assert_true(v != null, "variant found through Defs")
	assert_eq(v.display_name, "Ironback Rattler Beetle")
	assert_eq(v.base_id(), &"rattler_beetle")
	assert_true(v.damage_mult(KillMethod.BULLET) < 1.0, "tougher to bullets")
	assert_true(v.damage_mult(KillMethod.FIRE) > 1.0, "weak to fire")
	assert_true(v.shell_color != Defs.bug(&"rattler_beetle").shell_color, "tinted")
	assert_eq(Defs.bug(&"rattler_beetle").damage_mult(KillMethod.BULLET), 1.0)
	assert_true(Defs.bug(&"iron_tumble@bullet") == null, "no boss variants")
	assert_true(Defs.bug(&"dust_mite@trap") == null, "no variant for traps")
	# Every variant resists the method that made it and has some other weakness.
	for m: StringName in Variants.KINDS:
		var d := Defs.bug(Variants.id_for(&"wolf_spider", m))
		assert_true(d.damage_mult(m) < 1.0, "%s resists %s" % [d.display_name, m])
		var weak := false
		for other: StringName in Variants.KINDS:
			weak = weak or d.damage_mult(other) > 1.0
		assert_true(weak, "%s has a weakness" % d.display_name)


func test_tally_unlocks_after_threshold() -> void:
	var t := KillTally.new()
	t.threshold = 60
	var spider := Defs.bug(&"wolf_spider")
	for i in 59:
		assert_eq(t.note(spider, KillMethod.BULLET), &"")
	assert_eq(t.note(spider, KillMethod.BULLET), &"wolf_spider@bullet")
	assert_eq(t.note(spider, KillMethod.BULLET), &"", "unlocks once")
	# Swarm bugs that come in packs of 8 need more kills.
	var mite := Defs.bug(&"dust_mite")
	for i in 60:
		t.note(mite, KillMethod.FIRE)
	assert_false(t.unlocked.has(&"dust_mite@fire"))
	# Variant kills count for the base type.
	t.note(Defs.bug(&"wolf_spider@bullet"), KillMethod.FIRE)
	assert_eq(t.count(&"wolf_spider", KillMethod.FIRE), 1)
	t.reset()
	assert_true(t.unlocked.is_empty())


func test_planner_mixes_unlocked_variants() -> void:
	var p := _planner(11)
	p.variants = [&"dust_mite@bullet"]
	var plan := p.plan(4)
	var variants := _count(plan, func(d: BugDef) -> bool: return d.id == &"dust_mite@bullet")
	var mites := _count(plan, func(d: BugDef) -> bool: return d.id == &"dust_mite")
	assert_true(variants > 0, "variant appears")
	assert_true(mites > 0, "plain ones still come")
	var plain := _planner(11).plan(4)
	assert_eq(_count(plain, func(d: BugDef) -> bool: return d.is_variant()), 0)
