extends TestCase
## The Hive Queen (Story, chapter 8): she is a real boss with a body, words and
## a field guide entry, she never turns up on a run's boss wave, and her
## phases, brood calls and enraged numbers follow her rules.

const Rules := preload("res://scenes/bugs/bosses/_rules_queen.gd")


func _defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		out.append(Defs.bug(id))
	return out


func test_she_is_a_story_only_boss() -> void:
	var d := Defs.bug(&"hive_queen")
	assert_true(d != null)
	assert_eq(d.behavior, BugDef.Behavior.BOSS)
	assert_true(d.story_only)
	assert_true(d.front_armor > 0.0, "a plated abdomen")
	assert_true(d.max_hp >= Defs.bug(&"thunder_cicada").max_hp, "the toughest boss")
	assert_true(RunStats.is_boss(d.display_name), "her kill is booked as a boss")
	assert_true(ResourceLoader.exists("res://scenes/bugs/bosses/hive_queen.gd"), "she has a brain")


func test_never_picked_for_a_run() -> void:
	var defs := _defs()
	var last := Defs.WAVE_CONFIG.last_wave
	for seed_value in 60:
		for w in [5, 10, 15, 20, last]:
			var picked := BossRotation.pick(seed_value, w, defs, [], Defs.WAVE_CONFIG.boss_every, last)
			assert_false(picked.has(&"hive_queen"), "seed %d wave %d" % [seed_value, w])
		var sub := BossRotation.substitute(seed_value, 20, defs, [], [] as Array[StringName], &"mirage_mantis")
		assert_true(sub != &"hive_queen")


func test_her_body() -> void:
	var spec := BugBuilder.build(Defs.bug(&"hive_queen"))
	assert_true(spec["body"] is ArrayMesh)
	assert_true((spec["body"] as ArrayMesh).get_surface_count() > 0)
	assert_eq((spec["legs"] as Array).size(), 6, "six legs")
	assert_true(spec.has("crown") and spec.has("belly") and spec.has("mouth_at"), "glow points for her telegraphs")
	var queen := BugBuilder.build(Defs.bug(&"queen_spider"))
	assert_true(float(spec["body_radius"]) > float(queen["body_radius"]), "bigger than the Queen Spider")
	assert_true((spec["weak_spot"] as Vector3).is_equal_approx((spec["crown"] as Vector3) * float(spec["scale"])), "the crown jewel is her weak spot")


func test_field_guide_and_words() -> void:
	var e := FieldGuide.entry("bugs", &"hive_queen")
	assert_false(e.is_empty())
	assert_true((e.get("tips", []) as Array).size() >= 4)
	var d := Defs.bug(&"hive_queen")
	assert_true(d.counter.contains("crown"))
	assert_true(d.boss_tip.begins_with("THE HIVE QUEEN"))
	assert_true(d.wanted_for != "")


func test_phases() -> void:
	assert_eq(Rules.phase(1.0), 1)
	assert_eq(Rules.phase(0.61), 1)
	assert_eq(Rules.phase(0.6), 2)
	assert_eq(Rules.phase(0.31), 2)
	assert_eq(Rules.phase(0.3), 3)
	assert_eq(Rules.phase(0.0), 3)
	assert_eq(Rules.shriek_every(1), 0.0, "no shriek until she's hurt")
	assert_true(Rules.shriek_every(3) < Rules.shriek_every(2))
	assert_true(Rules.brood_every(3) < Rules.brood_every(2) and Rules.brood_every(2) < Rules.brood_every(1), "broods come faster")
	assert_true(Rules.spit_every(3) < Rules.spit_every(1))
	assert_eq(Rules.speed(2), 1.0)
	assert_true(Rules.speed(3) > 1.0, "enraged: climbs faster")
	assert_eq(Rules.damage_taken(1), 1.0)
	assert_true(Rules.damage_taken(3) > 1.0, "plates shed: takes more damage")


func test_brood_calls_and_cap() -> void:
	for p in [1, 2, 3]:
		var b := Rules.brood(p)
		assert_false(b.is_empty())
		for e: Array in b:
			assert_true(Defs.bug(e[0]) != null, "%s is a real bug" % e[0])
			assert_true(Defs.bug(e[0]).behavior != BugDef.Behavior.BOSS)
	assert_true(Rules.brood(3).any(func(e: Array) -> bool: return e[0] == &"hive_drone"), "drones in the last phase")
	assert_eq(Rules.room(0, 4), 4)
	assert_eq(Rules.room(Rules.BROOD_CAP - 2, 4), 2, "never past the cap")
	assert_eq(Rules.room(Rules.BROOD_CAP + 5, 4), 0)
