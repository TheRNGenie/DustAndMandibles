extends TestCase
## Story chapters 9 and 10: The Dry Gulch Families (the homesteads, the papers
## and the board's ledger) and The Reckoning (the Iron Mandible, its amber
## furnace, the Hive Mother and Silas's charge): their data, their pure rules,
## the Hive Mother's body and rules, and the amber hooks left for the merge.

const Mother := preload("res://scenes/bugs/bosses/_rules_mother.gd")


func test_the_last_two_chapters_follow_the_queen() -> void:
	var ch9 := StoryChapter.load_id("ch9")
	var ch10 := StoryChapter.load_id("ch10")
	assert_true(ch9 != null and ch10 != null)
	assert_eq(ch9.required(), "ch8")
	assert_eq(ch10.required(), "ch9")
	assert_eq([ch9.first_wave, ch9.last_wave, ch10.first_wave, ch10.last_wave], [22, 23, 24, 25])
	assert_eq(ch9.kind(), "salvage")
	assert_eq(ch10.kind(), "reckoning")
	assert_true(ch9.floor_job() and ch10.floor_job(), "both hold the last build phase for an unfinished job")
	assert_true(ch9.sealed_tunnel and ch10.sealed_tunnel, "the main tunnel stays blown after Down the Hole")
	assert_eq(ch10.boss_for(25), &"hive_mother")
	var p := StoryProgress.new()
	for cid in ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8"]:
		p.win(StoryChapter.load_id(cid))
	assert_true(p.is_unlocked("ch9"))
	assert_false(p.is_unlocked("ch10"))
	p.win(ch9)
	assert_true(p.is_unlocked("ch10"))
	assert_eq(p.amber_blueprints.has("queens_bell") and not p.blueprints.has("queens_bell"), true, "the ledger's amber blueprint is booked")


func test_the_board_speaks() -> void:
	var ch9 := StoryChapter.load_id("ch9")
	var ch10 := StoryChapter.load_id("ch10")
	assert_true(ch9.speakers().has("lucky"), "Lucky Moreau on an intercepted wire")
	for who in ["vane", "ezra"]:
		assert_true(ch10.speakers().has(who), who)
	for who in ["vane", "crane", "ezra", "lucky"]:
		assert_true(StoryChapter.SPEAKERS.has(who))
		assert_true(StoryChapter.speaker_role(who) != "", who + " has a role")
		assert_true(StoryPortrait.STRANGERS.has(who), who + " has a fallback bust")


func test_every_family_has_a_letter_and_the_ledger_names_ezra() -> void:
	var ch9 := StoryChapter.load_id("ch9")
	assert_eq(int(ch9.objective["families"]), HomesteadRules.FAMILIES.size())
	for i in HomesteadRules.FAMILIES.size():
		var lines := ch9.event_lines("letter_" + HomesteadRules.family_id(i))
		assert_false(lines.is_empty(), HomesteadRules.family_id(i))
		assert_eq(str(lines[0][0]), "pearl", "Pearl reads the letters")
	var said := ""
	for l: Array in ch9.event_lines("ledger"):
		said += str(l[1]) + " "
	assert_true(said.contains("Ezra Kettle") and said.contains("Cornelius Vane"), "the signatures")
	for key in ["down", "papers", "camp", "ledger_taken", "hold", "win", "lost"]:
		assert_false(ch9.event_lines(key).is_empty(), key)


func test_the_reckoning_beats_and_epilogue() -> void:
	var ch10 := StoryChapter.load_id("ch10")
	for key in ["train", "furnace_hit", "furnace_half", "furnace_down", "vane", "crane", "second", "ezra",
			"mother_half", "mother_set", "mother_seal", "sealed", "hold", "win", "lost"]:
		assert_false(ch10.event_lines(key).is_empty(), key)
	assert_eq(str(ch10.event_lines("mother_seal")[0][1]), "Tell 'em a Kettle finally blew the right tunnel.")
	assert_eq(str(ch10.event_lines("mother_seal")[0][0]), "kettle")
	assert_eq(ch10.epilogue.size(), 4, "Vane, Ezra, Crane, the railroad")
	assert_true(str(ch10.epilogue[3]["body"]).ends_with("Dry Gulch has no railroad."))
	assert_true(str(ch10.epilogue[1]["body"]).contains("Hanged"))
	assert_true(str(ch10.epilogue[2]["body"]).contains("hatched"))
	assert_eq(ch10.closing, ["stroud", "Nobody gets this canyon back. But the men who took it are under it."])
	assert_true(StoryChapter.load_id("ch9").epilogue.is_empty())


func test_problems_catch_bad_finale_data() -> void:
	var ch := StoryChapter.from_dict({"id": "x", "number": 1, "title": "X", "first_wave": 3, "last_wave": 3,
		"objective": {"kind": "reckoning", "boss": "hive_mother"}, "epilogue": [{"title": "", "body": "x"}],
		"rewards": {"notches": 5, "unlock": {"kind": "amber_blueprint", "id": "amber_nonsense"}}})
	var text := "\n".join(ch.problems())
	for bit: String in ["reckoning needs the boss", "train night", "epilogue card", "unknown amber blueprint"]:
		assert_true(text.contains(bit), "flags: " + bit)
	var sal := StoryChapter.from_dict({"id": "y", "number": 1, "title": "Y", "first_wave": 3, "last_wave": 4, "objective": {"kind": "salvage"}})
	var t2 := "\n".join(sal.problems())
	assert_true(t2.contains("salvage needs families") and t2.contains("ledger_wave"))


# ------------------------------------------------------------------ homesteads

func test_homestead_spots_keep_away_from_the_ropes_and_each_other() -> void:
	var feet: Array[Vector3] = [Vector3(-22, 0, -19), Vector3(22, 0, -19)]
	var cands := HomesteadRules.canyon_candidates()
	assert_true(cands.size() > 50)
	var blocked := func(p: Vector3) -> bool: return p.x > 8.0 and p.z > 60.0 # a raid site's ground
	var got := HomesteadRules.pick_spots(cands, feet, 5, HomesteadRules.MIN_SEP, [], blocked)
	assert_eq(got.size(), 5)
	for i in got.size():
		assert_false(blocked.call(got[i]), "clear of the raid site")
		for f in feet:
			assert_true(Vector2(got[i].x - f.x, got[i].z - f.z).length() >= HomesteadRules.MIN_FROM_FEET)
		for j in i:
			assert_true(Vector2(got[i].x - got[j].x, got[i].z - got[j].z).length() >= HomesteadRules.MIN_SEP)
	assert_true(got[0].z > 70.0, "the furthest floor first")
	var avoid: Array[Vector3] = [got[0]]
	var more := HomesteadRules.pick_spots(cands, feet, 3, HomesteadRules.MIN_SEP, avoid)
	for q in more:
		assert_true(Vector2(q.x - got[0].x, q.z - got[0].z).length() >= HomesteadRules.MIN_SEP, "kept off the camp")
	assert_eq(HomesteadRules.ring_candidates(Vector3.ZERO, 30.0).size(), 120)


## A crowded ring floor (the Buttes: the lakebed cracks' raid-site zones cover
## the middle): the spots ease off the zones rather than piling up.
func test_homestead_spots_ease_off_on_a_crowded_floor() -> void:
	var feet: Array[Vector3] = [Vector3(19, 60, -34.5), Vector3(34.5, 60, 19), Vector3(-19, 60, 34.5), Vector3(-34.5, 60, -19)]
	var cands := HomesteadRules.ring_candidates(Vector3.ZERO, 30.0)
	var everywhere := func(_p: Vector3) -> bool: return true
	var near_middle := func(p: Vector3) -> bool: return Vector2(p.x, p.z).length() < 15.0
	assert_eq(HomesteadRules.pick_spots(cands, feet, 4, HomesteadRules.MIN_SEP, [], everywhere).size(), 0, "the strict pick finds nothing")
	var got := HomesteadRules.pick_spots_eased(cands, feet, 4, [], everywhere, near_middle)
	assert_eq(got.size(), 4)
	for i in got.size():
		assert_false(near_middle.call(got[i]), "clear of the tunnel mouths")
		for j in i:
			assert_true(Vector2(got[i].x - got[j].x, got[i].z - got[j].z).length() >= HomesteadRules.SEP_FLOOR)


func test_papers_bookkeeping() -> void:
	var P := HomesteadRules.Papers
	var states := [P.UP, P.PACKED, P.PACKED, P.HOME]
	var holders := [0, 7, 9, 0]
	assert_eq(HomesteadRules.papers_up(states), 1)
	assert_eq(HomesteadRules.carried_by(states, holders, 7), [1] as Array[int])
	assert_eq(HomesteadRules.carried_by(states, holders, 9), [2] as Array[int])
	assert_false(HomesteadRules.done(states, P.UP))
	assert_false(HomesteadRules.done([P.UP, P.UP, P.UP, P.UP], P.PACKED), "the ledger too")
	assert_true(HomesteadRules.done([P.UP, P.UP, P.UP, P.UP], P.UP))
	assert_false(HomesteadRules.done([], P.UP))


func test_papers_and_ledger_ride_in_the_pack_not_the_stockpile() -> void:
	var pack := Backpack.make()
	assert_eq(pack.add({HomesteadRules.PAPERS: 4, HomesteadRules.LEDGER: 1}), 5, "a solo rider can carry the lot")
	assert_true(Backpack.weight_of(HomesteadRules.LEDGER) > Backpack.weight_of(HomesteadRules.PAPERS))
	var split := ExpeditionRules.split_story({&"scrap": 5, HomesteadRules.PAPERS: 2}, [HomesteadRules.PAPERS, HomesteadRules.LEDGER])
	assert_eq(split[0], {&"scrap": 5})
	assert_eq(split[1], {HomesteadRules.PAPERS: 2})


# ------------------------------------------------------------------ the Iron Mandible

func test_furnace_numbers() -> void:
	assert_almost(ReckoningRules.furnace_hp(1), ReckoningRules.FURNACE_HP)
	assert_true(ReckoningRules.furnace_hp(4) > ReckoningRules.furnace_hp(2), "tougher for a bigger posse")
	assert_eq(ReckoningRules.frenzy(10.0, true), ReckoningRules.FRENZY_SPEED)
	assert_eq(ReckoningRules.frenzy(10.0, false), 1.0, "only while it burns")
	assert_eq(ReckoningRules.frenzy(ReckoningRules.FRENZY_RADIUS + 1.0, true), 1.0)


func test_route_and_pace() -> void:
	var cx := func(_z: float) -> float: return 0.0
	var fy := func(_x: float, _z: float) -> float: return 0.0
	var r := ReckoningRules.line_route(100.0, -50.0, 2.0, cx, fy)
	assert_almost(ReckoningRules.length_of(r), 150.0, 0.01)
	assert_true(ReckoningRules.point_at(r, 0.0).is_equal_approx(Vector3(0, 0, 100)))
	assert_true(ReckoningRules.point_at(r, 50.0).is_equal_approx(Vector3(0, 0, 50)))
	assert_true(ReckoningRules.point_at(r, 999.0).is_equal_approx(Vector3(0, 0, -50)), "clamped at the stop")
	assert_true(ReckoningRules.dir_at(r, 20.0).is_equal_approx(Vector3(0, 0, -1)))
	assert_almost(ReckoningRules.s_nearest(r, Vector3(3, 0, 0)), 100.0, 2.01)
	# Rolls in to the hold point in the build phase, crawls on to the stop in the wave.
	assert_almost(ReckoningRules.advance(0.0, 1.0, false, 60.0, 150.0), ReckoningRules.ARRIVE_SPEED)
	assert_almost(ReckoningRules.advance(59.0, 5.0, false, 60.0, 150.0), 60.0)
	assert_almost(ReckoningRules.advance(60.0, 2.0, true, 60.0, 150.0), 60.0 + ReckoningRules.CRAWL_SPEED * 2.0)
	assert_almost(ReckoningRules.advance(149.5, 5.0, true, 60.0, 150.0), 150.0)
	assert_almost(ReckoningRules.advance(150.0, 5.0, false, 60.0, 150.0), 150.0, 0.001, "never backwards")
	# A wave that starts before the train is in: it rolls in at full speed, then crawls.
	assert_almost(ReckoningRules.advance(20.0, 1.0, true, 60.0, 150.0), 20.0 + ReckoningRules.ARRIVE_SPEED, 0.001, "still rolling in")
	assert_almost(ReckoningRules.advance(58.0, 1.0, true, 60.0, 150.0), 60.0 + ReckoningRules.CRAWL_SPEED * (1.0 - 2.0 / ReckoningRules.ARRIVE_SPEED), 0.001, "in, then the crawl")
	var arc := ReckoningRules.arc_route(Vector3.ZERO, 10.0, 0.0, PI, 1.0, fy)
	assert_almost(ReckoningRules.length_of(arc), PI * 10.0, 0.2)
	assert_true(ReckoningRules.point_at(arc, 999.0).is_equal_approx(Vector3(10, 0, 0)), "ends at a_end")


func test_silas_beats_land_on_the_mother() -> void:
	assert_eq(ReckoningRules.mother_beat(0.8, 0.55), "")
	assert_eq(ReckoningRules.mother_beat(0.55, 0.45), "mother_half")
	assert_eq(ReckoningRules.mother_beat(0.3, 0.2), "mother_set")
	assert_eq(ReckoningRules.mother_beat(0.6, 0.2), "mother_set", "a big hit past both: the later beat")
	assert_false(ReckoningRules.seal_due(0.11))
	assert_true(ReckoningRules.seal_due(ReckoningRules.SEAL_AT))
	assert_true(ReckoningRules.SEAL_FUSE < 6.0, "his fuse is short: the near-kill and the blast land together")


# ------------------------------------------------------------------ the Hive Mother

func test_the_hive_mother_is_the_finale_boss() -> void:
	var d := Defs.bug(&"hive_mother")
	var q := Defs.bug(&"hive_queen")
	assert_true(d != null)
	assert_eq(d.behavior, BugDef.Behavior.BOSS)
	assert_true(d.story_only)
	assert_true(d.max_hp > q.max_hp and d.size > q.size, "bigger and tougher than her daughter")
	assert_true(d.front_armor > 0.0)
	assert_true(d.counter.contains("geode"))
	assert_true(d.boss_tip.begins_with("THE HIVE MOTHER"))
	assert_true(RunStats.is_boss(d.display_name))
	assert_true(ResourceLoader.exists("res://scenes/bugs/bosses/hive_mother.gd"))
	assert_false(FieldGuide.entry("bugs", &"hive_mother").is_empty())
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	for seed_value in 30:
		for w in [5, 10, 15, 20]:
			assert_false(BossRotation.pick(seed_value, w, defs, [], Defs.WAVE_CONFIG.boss_every, Defs.WAVE_CONFIG.last_wave).has(&"hive_mother"))


func test_her_body_is_not_her_daughters() -> void:
	var spec := BugBuilder.build(Defs.bug(&"hive_mother"))
	var queen := BugBuilder.build(Defs.bug(&"hive_queen"))
	assert_true((spec["body"] as ArrayMesh).get_surface_count() > 0)
	assert_eq((spec["legs"] as Array).size(), 6)
	assert_true(spec.has("crown") and spec.has("belly") and spec.has("mouth_at"))
	assert_true((spec["eyes"] as Dictionary).is_empty(), "blind: no pupils")
	assert_true(float(spec["body_radius"]) > float(queen["body_radius"]))
	assert_true((spec["weak_spot"] as Vector3).is_equal_approx((spec["crown"] as Vector3) * float(spec["scale"])), "the geode is her weak spot")


func test_her_rules() -> void:
	assert_eq(Mother.phase(1.0), 1)
	assert_eq(Mother.phase(0.5), 2)
	assert_eq(Mother.phase(0.2), 3)
	assert_eq(Mother.hum_every(1), 0.0, "no hum till she's hurt")
	assert_true(Mother.hum_every(3) < Mother.hum_every(2))
	assert_eq(Mother.shriek_every(2), 0.0)
	assert_true(Mother.shriek_every(3) > 0.0, "the Queen's shriek at the end")
	assert_true(Mother.hail_targets(3) > Mother.hail_targets(1))
	assert_true(Mother.hail_every(3) < Mother.hail_every(1))
	assert_eq(Mother.room(Mother.BROOD_CAP - 2, 5), 2)
	assert_eq(Mother.room(Mother.BROOD_CAP + 3, 5), 0)
	assert_true(Mother.speed(3) > 1.0 and Mother.damage_taken(3) > 1.0)
	for p in [1, 2, 3]:
		for e: Array in Mother.brood(p):
			assert_true(Defs.bug(e[0]) != null, "%s is a real bug" % e[0])


# ------------------------------------------------------------------ amber, wired at merge

func test_amber_hooks() -> void:
	assert_true(StoryAmber.is_blueprint("queens_bell"))
	assert_true(StoryAmber.is_blueprint("mandible_lance"))
	assert_false(StoryAmber.is_blueprint("craft_post_cannon_explosive"))
	assert_eq(StoryChapter.load_id("ch9").unlock()["id"], "queens_bell")
	assert_eq(StoryChapter.load_id("ch10").unlock()["id"], "mandible_lance")


func test_late_waves_are_thinned_not_tripled() -> void:
	var g := [{"bug": &"dust_mite", "count": 600, "cliff": 0, "lane": 0, "pulse": 0}, {"bug": &"wolf_spider", "count": 400, "cliff": 1, "lane": 1, "pulse": 0},
		{"bug": &"hive_mother", "count": 1, "cliff": 0, "lane": 2, "pulse": 0}]
	var t := StoryChapter.thin(g, 500)
	assert_eq(int(t[0]["count"]), 300)
	assert_eq(int(t[1]["count"]), 200)
	assert_eq(int(t[2]["count"]), 1, "the boss stays")
	assert_eq(int(g[0]["count"]), 600, "the plan itself untouched")
	assert_eq(StoryChapter.thin(g, 5000), g)
	assert_eq(StoryChapter.load_id("ch10").max_bugs, 4000)
