extends TestCase
## BossRotation: which bosses come on boss waves, the finale, the Mirage Mantis's
## dust-storm rule, and the boss data every boss needs.


func _defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		out.append(Defs.bug(id))
	return out


func _bosses() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _defs():
		if d.behavior == BugDef.Behavior.BOSS:
			out.append(d.id)
	return out


func test_only_boss_waves_bring_bosses() -> void:
	var cfg := Defs.WAVE_CONFIG
	for w in range(1, 31):
		var picks := BossRotation.pick(7, w, _defs(), [], cfg.boss_every, cfg.last_wave)
		if w % cfg.boss_every != 0:
			assert_eq(picks.size(), 0, "wave %d" % w)
		else:
			assert_eq(picks.size(), 2 if w == cfg.last_wave else 1, "wave %d" % w)


func test_picks_are_unlocked_and_deterministic() -> void:
	for seed_value: int in [1, 2, 3, 99]:
		for w: int in [5, 10, 15, 20, 25]:
			var a := BossRotation.pick(seed_value, w, _defs(), [], 5, 20)
			var b := BossRotation.pick(seed_value, w, _defs(), [], 5, 20)
			assert_eq(a, b, "same seed, same boss")
			for id in a:
				assert_true(Defs.bug(id).first_wave <= w, "%s unlocked by wave %d" % [id, w])
				assert_eq(Defs.bug(id).behavior, BugDef.Behavior.BOSS)


func test_each_boss_wave_brings_its_new_tier() -> void:
	# Wave 5, 10, 15 each bring a boss that unlocks on that very wave.
	for seed_value: int in [4, 5, 6]:
		var seen: Array = []
		for w: int in [5, 10, 15]:
			var p := BossRotation.pick(seed_value, w, _defs(), seen, 5, 20)
			assert_eq(Defs.bug(p[0]).first_wave, w, "seed %d wave %d" % [seed_value, w])
			seen.append(p[0])


func test_no_repeats_until_every_boss_is_seen() -> void:
	var all := _bosses()
	for seed_value: int in [11, 12, 13]:
		var seen: Array = []
		var w := 5
		# Endless runs: keep going until every boss has come once.
		while seen.size() < all.size() and w <= 200:
			for id in BossRotation.pick(seed_value, w, _defs(), seen, 5, 20):
				assert_false(seen.has(id), "seed %d wave %d repeats %s" % [seed_value, w, id])
				seen.append(id)
			w += 5
		assert_eq(seen.size(), all.size(), "every boss shows up (seed %d)" % seed_value)
		# Then the round starts again, never with the last one met.
		var next := BossRotation.pick(seed_value, w, _defs(), seen, 5, 20)
		assert_true(next[0] != seen[seen.size() - 1], "no back-to-back repeat")


func test_finale_brings_two_different_bosses() -> void:
	for seed_value in 20:
		var p := BossRotation.pick(seed_value, 20, _defs(), [], 5, 20)
		assert_eq(p.size(), 2)
		assert_true(p[0] != p[1], "two different bosses")


func test_mantis_only_in_dust_storms() -> void:
	var defs := _defs()
	var planned: Array[StringName] = [BossRotation.MANTIS]
	var calm := BossRotation.apply_weather(3, 10, defs, [], planned, false)
	assert_false(calm.has(BossRotation.MANTIS), "a stand-in comes without the dust")
	assert_eq(Defs.bug(calm[0]).behavior, BugDef.Behavior.BOSS)
	var dusty := BossRotation.apply_weather(3, 10, defs, [], planned, true)
	assert_eq(dusty[0], BossRotation.MANTIS)
	# A dust-storm boss wave brings her in, once a run.
	var other: Array[StringName] = [&"queen_spider"]
	assert_eq(BossRotation.apply_weather(3, 10, defs, [], other, true)[0], BossRotation.MANTIS)
	assert_eq(BossRotation.apply_weather(3, 10, defs, [BossRotation.MANTIS], other, true)[0], &"queen_spider")
	# The finale's two stay different after the swap.
	var two: Array[StringName] = [BossRotation.MANTIS, &"queen_spider"]
	var swapped := BossRotation.apply_weather(5, 20, defs, [], two, false)
	assert_true(swapped[0] != swapped[1] and not swapped.has(BossRotation.MANTIS))


func test_planner_puts_one_boss_per_cliff_in_the_finale() -> void:
	var p := WavePlanner.new(Defs.WAVE_CONFIG, _defs(), 8)
	var plan := p.plan(Defs.WAVE_CONFIG.last_wave)
	var cliffs: Array = []
	for g: Dictionary in plan["groups"]:
		if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS:
			cliffs.append(int(g["cliff"]))
			assert_eq(int(g["count"]), 1)
	assert_eq(cliffs.size(), 2)
	assert_true(cliffs[0] != cliffs[1], "one boss on each cliff")


func test_every_boss_has_its_words_and_body() -> void:
	for id in _bosses():
		var d := Defs.bug(id)
		assert_true(d.counter.length() > 20, "%s counter" % id)
		assert_true(d.boss_tip != "", "%s boss tip" % id)
		assert_true(d.wanted_for != "", "%s wanted poster line" % id)
		assert_true(d.max_hp >= 1000.0 and d.max_hp <= 4000.0, "%s HP %d" % [id, int(d.max_hp)])
		assert_eq(d.cost, 0, "%s is never bought by the budget" % id)
		assert_true(d.first_wave % Defs.WAVE_CONFIG.boss_every == 0, "%s comes on a boss wave" % id)
		var spec := BugBuilder.build(d)
		assert_true(spec.has("body") and spec["body"] is ArrayMesh, "%s has a body" % id)
		assert_true(float(spec["body_radius"]) > 1.0, "%s is big" % id)
		assert_false(FieldGuide.entry("bugs", id).is_empty(), "%s field guide entry" % id)
