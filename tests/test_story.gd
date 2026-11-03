extends TestCase
## Story mode: every chapter's data is sound, the plan edits (bosses, extra
## bugs), weather and maps follow the data, and progress books wins, unlocks,
## journal pages and replays, and survives a save.


func _plan(w: int, cliffs: int = 2) -> Dictionary:
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	var planner := WavePlanner.new(Defs.WAVE_CONFIG, defs, 42)
	planner.cliff_count = cliffs
	var weights: Array[float] = []
	for c in cliffs:
		weights.append(1.0 / cliffs)
	planner.weights = weights
	return planner.plan(w)


func _count(plan: Dictionary, bug: StringName) -> int:
	var n := 0
	for g: Dictionary in plan["groups"]:
		if StringName(str(g["bug"])) == bug:
			n += int(g["count"])
	return n


func _bosses(plan: Dictionary) -> Array:
	var out: Array = []
	for g: Dictionary in plan["groups"]:
		if Defs.bug(StringName(str(g["bug"]))).behavior == BugDef.Behavior.BOSS:
			out.append(StringName(str(g["bug"])))
	return out


func test_every_chapter_loads_and_is_sound() -> void:
	assert_eq(StoryChapter.all().size(), 10, "ten playable chapters")
	assert_eq(StoryChapter.PLANNED.size(), 0, "nothing left Coming Later")
	var prev := 0
	for ch in StoryChapter.all():
		assert_eq(ch.problems(), [] as Array[String], ch.id)
		assert_eq(ch.id, "ch%d" % ch.number, "ids match numbers")
		assert_true(ch.number > prev, "play order follows the numbers")
		prev = ch.number


func test_chapters_follow_on_and_rotate_maps() -> void:
	var prev_last := 0
	var maps := {}
	for ch in StoryChapter.all():
		assert_eq(ch.first_wave, prev_last + 1, "%s picks up where the last left off" % ch.id)
		prev_last = ch.last_wave
		maps[ch.map] = true
	assert_eq(maps.size(), 3, "Canyon, Mesa and Buttes all used")
	assert_eq(StoryChapter.load_id("ch1").last_wave, 5)
	assert_eq(StoryChapter.load_id("ch4").last_wave, 13)


func test_every_wave_has_build_and_wave_lines() -> void:
	for ch in StoryChapter.all():
		for w in range(ch.first_wave, ch.last_wave + 1):
			assert_false(ch.lines(w, "build").is_empty(), "%s wave %d build" % [ch.id, w])
			assert_false(ch.lines(w, "wave").is_empty(), "%s wave %d wave" % [ch.id, w])
		assert_false(ch.event_lines("win").is_empty(), "%s win line" % ch.id)
		assert_false(ch.event_lines("lost").is_empty(), "%s lost line" % ch.id)


func test_fetch_chapters_have_their_event_lines() -> void:
	for ch in StoryChapter.all():
		if ch.kind() == "fetch":
			for key: String in ["drop", "pickup", "delivered", "hold"]:
				assert_false(ch.event_lines(key).is_empty(), "%s %s" % [ch.id, key])


func test_problems_catch_bad_data() -> void:
	var ch := StoryChapter.from_dict({"id": "x", "number": 1, "title": "X", "map": "moon", "first_wave": 4, "last_wave": 2,
		"objective": {"kind": "fetch", "spawn": "teleport"}, "bosses": {"3": "dust_mite"},
		"radio": {"9": {"build": [["sheriff", "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twentyone"]]}}})
	var p := ch.problems()
	var text := "\n".join(p)
	for bit: String in ["unknown map", "out of order", "telegram", "journal", "Notches", "outside the chapter", "unknown speaker",
			"over 20 words", "isn't a boss", "fetch needs spawn", "deliver_to"]:
		assert_true(text.contains(bit), "flags: " + bit)


func test_plan_boss_is_the_chapters() -> void:
	var ch1 := StoryChapter.load_id("ch1")
	var plan := ch1.apply_to_plan(_plan(5), 5)
	assert_eq(_bosses(plan), [&"hive_wagon"], "wave 5 brings the Hive Wagon, nothing else")
	var ch3 := StoryChapter.load_id("ch3")
	var p10 := ch3.apply_to_plan(_plan(10, 4), 10)
	assert_eq(_bosses(p10), [], "chapter 3 keeps wave 10 boss-free")
	var p11 := ch3.apply_to_plan(_plan(11, 4), 11)
	assert_eq(_bosses(p11), [&"queen_spider"], "the Queen Spider on wave 11")


func test_plan_extra_bugs_added_and_spread() -> void:
	var ch4 := StoryChapter.load_id("ch4")
	var base := _plan(12)
	var before := _count(base, &"dragonfly_bandit")
	var plan := ch4.apply_to_plan(base, 12)
	assert_eq(_count(plan, &"dragonfly_bandit") - before, 6, "six extra bandits")
	var cliffs := {}
	for g: Dictionary in plan["groups"]:
		if StringName(str(g["bug"])) == &"dragonfly_bandit":
			cliffs[int(g["cliff"])] = true
			assert_true(int(g["pulse"]) < int(plan["pulses"]), "a real pulse")
			assert_true(int(g["lane"]) >= 0 and int(g["lane"]) < 5, "a real lane")
	assert_eq(cliffs.size(), 2, "both cliffs get bandits")
	assert_eq(_count(base, &"dragonfly_bandit"), before, "the original plan is untouched")


func test_plan_untouched_without_chapter_bits() -> void:
	var ch2 := StoryChapter.load_id("ch2")
	var base := _plan(6, 3)
	var plan := ch2.apply_to_plan(base, 6)
	assert_eq((plan["groups"] as Array).size(), (base["groups"] as Array).size(), "wave 6 of Dry Season is a plain wave")


func test_weather_and_maps() -> void:
	var ch2 := StoryChapter.load_id("ch2")
	assert_eq(ch2.weather_for(6), -1)
	assert_eq(ch2.weather_for(7), Weather.Kind.HEAT_WAVE)
	var ch1 := StoryChapter.load_id("ch1")
	assert_eq(ch1.map_for_players(1), MapDef.CANYON)
	assert_eq(ch1.map_for_players(2), MapDef.CANYON)
	assert_eq(ch1.map_for_players(3), MapDef.MESA, "a third rider moves the chapter to the Mesa")
	assert_eq(ch1.map_for_players(4), MapDef.BUTTES)
	assert_eq(StoryChapter.load_id("ch3").map_for_players(2), MapDef.BUTTES)


func test_next_chapter() -> void:
	assert_eq(StoryChapter.next_id("ch1"), "ch2")
	assert_eq(StoryChapter.next_id("ch4"), "ch5")
	assert_eq(StoryChapter.next_id("ch6"), "ch7", "Down the Hole follows the storm")
	assert_eq(StoryChapter.next_id("ch7"), "ch8")
	assert_eq(StoryChapter.next_id("ch8"), "ch9", "the families follow the Queen")
	assert_eq(StoryChapter.next_id("ch9"), "ch10")
	assert_eq(StoryChapter.next_id("ch10"), "", "the Reckoning is the last")


func test_progress_unlocks_in_order() -> void:
	var p := StoryProgress.new()
	assert_true(p.is_unlocked("ch1"))
	assert_false(p.is_unlocked("ch2"))
	assert_eq(p.next_up(), "ch1")
	var res := p.win(StoryChapter.load_id("ch1"))
	assert_true(bool(res["first"]))
	assert_eq(int(res["notches"]), 30)
	assert_eq(str((res["unlock"] as Dictionary)["id"]), "hat:ten_gallon")
	assert_true(bool(res["journal"]))
	assert_true(p.is_unlocked("ch2"))
	assert_false(p.is_unlocked("ch3"))
	assert_eq(p.next_up(), "ch2")


func test_progress_replays_pay_a_tip_and_no_unlock() -> void:
	var p := StoryProgress.new()
	var ch := StoryChapter.load_id("ch2")
	p.win(ch)
	assert_eq(p.blueprints, ["craft_tripod_nozzle_lead"] as Array[String], "blueprint booked")
	var again := p.win(ch)
	assert_false(bool(again["first"]))
	assert_eq(int(again["notches"]), StoryProgress.replay_tip(ch))
	assert_true((again["unlock"] as Dictionary).is_empty())
	assert_false(bool(again["journal"]), "one journal page per chapter")
	assert_eq(int(p.done["ch2"]["wins"]), 2)
	assert_eq(p.blueprints.size(), 1, "no duplicate blueprints")


func test_progress_round_trip_and_bad_data() -> void:
	var p := StoryProgress.new()
	p.win(StoryChapter.load_id("ch1"))
	p.win(StoryChapter.load_id("ch2"))
	p.note_tried("ch3")
	var q := StoryProgress.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_true(q.is_done("ch1") and q.is_done("ch2"))
	assert_eq(q.journal, ["ch1", "ch2"] as Array[String])
	assert_eq(q.tried, p.tried)
	assert_eq(q.blueprints, p.blueprints)
	var junk := StoryProgress.from_dict({"done": {"ch99": {}, "ch1": "x"}, "journal": "nope"})
	assert_true(junk.done.is_empty(), "unknown and broken chapters dropped")
	assert_true(StoryProgress.from_dict(null).done.is_empty())


func test_progress_saves_to_disk() -> void:
	var path := "user://story_test.json"
	var p := StoryProgress.new()
	p.win(StoryChapter.load_id("ch1"))
	assert_true(p.write(path))
	var q := StoryProgress.read(path)
	assert_true(q.is_done("ch1"))
	DirAccess.remove_absolute(path)
	assert_false(StoryProgress.read("user://nope_story.json").is_done("ch1"))


func test_blueprint_rewards_are_real_turrets() -> void:
	for ch in StoryChapter.all():
		var u := ch.unlock()
		match str(u.get("kind", "")):
			"blueprint":
				assert_true(Defs.turret(StringName(str(u["id"]))) != null, "%s blueprint %s" % [ch.id, u["id"]])
			"amber_blueprint":
				# Hive amber is another branch's: StoryAmber names the ids it will wire up.
				assert_true(StoryAmber.is_blueprint(str(u["id"])), "%s amber blueprint %s" % [ch.id, u["id"]])
			"cosmetic":
				var parts := str(u["id"]).split(":")
				assert_true(PerkTable.cosmetic_price(parts[0], parts[1]) > 0, "%s cosmetic %s is a bought one" % [ch.id, u["id"]])
			_:
				assert_true(false, "%s has a known unlock" % ch.id)


func test_every_speaker_has_a_portrait_look() -> void:
	for who in StoryChapter.SPEAKERS:
		assert_true(StoryPortrait.CAST.has(who), who)
		assert_true(StoryChapter.speaker_name(who) != who, who + " has a name")


func test_director_objective_rules() -> void:
	var d := StoryDirector.new()
	d.chapter = StoryChapter.load_id("ch1")
	assert_true(d.objective_done(), "hold: done once the waves are")
	d.chapter = StoryChapter.load_id("ch2")
	assert_false(d.objective_done(), "fetch: not until delivered")
	d.cargo_state = StoryDirector.Cargo.CARRIED
	assert_false(d.objective_done())
	d.cargo_state = StoryDirector.Cargo.DELIVERED
	assert_true(d.objective_done())
	d.chapter = StoryChapter.load_id("ch4")
	var box := StoryStrongbox.new()
	box.loot = 0
	d.boxes.append(box)
	d.in_flight = 1
	assert_true(d.objective_done(), "protect: a sack still in the air can be shot back")
	d.in_flight = 0
	assert_false(d.objective_done(), "protect: every sack gone")
	box.loot = 3
	assert_eq(d.loot_left(), 3)
	assert_eq(d.loot_total(), 10)
	assert_true(d.objective_done())
	box.free()
	d.free()


func test_the_queen_needs_down_the_hole() -> void:
	var ch8 := StoryChapter.load_id("ch8")
	assert_eq(ch8.required(), "ch7", "the Queen comes after the tunnel's blown")
	assert_eq(StoryChapter.load_id("ch7").required(), "ch6", "the rest follow play order")
	assert_eq(StoryChapter.load_id("ch1").required(), "")
	var p := StoryProgress.new()
	for cid in ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6"]:
		p.win(StoryChapter.load_id(cid))
	assert_true(p.is_unlocked("ch7"))
	assert_false(p.is_unlocked("ch8"))
	p.win(StoryChapter.load_id("ch7"))
	assert_true(p.is_unlocked("ch8"))
	assert_eq(p.next_up(), "ch8")
	var bad := StoryChapter.from_dict({"id": "ch8", "requires": "ch99"})
	assert_true(bad.problems().has("requires unknown chapter ch99"))


func test_the_story_bosses() -> void:
	assert_eq(StoryChapter.load_id("ch5").boss_for(15), &"burrow_beetle")
	assert_eq(StoryChapter.load_id("ch6").bosses_for(18), [&"thunder_cicada", &"mirage_mantis"] as Array[StringName])
	assert_eq(StoryChapter.load_id("ch6").weather_for(17), Weather.Kind.DUST_STORM)
	assert_eq(StoryChapter.load_id("ch6").weather_for(18), Weather.Kind.DUST_STORM)
	assert_eq(StoryChapter.load_id("ch8").boss_for(21), &"hive_queen")
	assert_eq(StoryChapter.load_id("ch8").boss_for(20), &"acid_matriarch")


func test_two_bosses_on_one_wave_take_different_cliffs() -> void:
	var ch := StoryChapter.load_id("ch6")
	var plan := ch.apply_to_plan(_plan(18), 18)
	var cliffs: Array = []
	for g: Dictionary in plan["groups"]:
		if Defs.bug(StringName(str(g["bug"]))).behavior == BugDef.Behavior.BOSS:
			cliffs.append(int(g["cliff"]))
	assert_eq(_bosses(plan).size(), 2)
	assert_true(_bosses(plan).has(&"thunder_cicada") and _bosses(plan).has(&"mirage_mantis"))
	assert_true(cliffs[0] != cliffs[1], "one on each cliff")
	var solo := ch.apply_to_plan(_plan(17, 1), 17)
	assert_eq(_bosses(solo), [&"mirage_mantis"], "one held cliff: one boss on a non-double wave")


func test_keep_objective_rules() -> void:
	var ch5 := StoryChapter.load_id("ch5")
	assert_eq(ch5.kind(), "keep")
	assert_eq(ch5.keep_thing(), "storeys")
	assert_eq(ch5.keep_need(1), 5)
	assert_eq(ch5.keep_need(2), 10, "per held cliff")
	assert_true(ch5.keep_ok(10, 2))
	assert_false(ch5.keep_ok(9, 2))
	var ch6 := StoryChapter.load_id("ch6")
	assert_eq(ch6.keep_thing(), "lanterns")
	assert_eq(ch6.keep_need(3), 12)
	assert_true(bool(ch6.objective.get("screech_breaks_lanterns", false)), "the Cicada breaks lanterns in chapter 6")
	assert_false(ch6.event_lines("short").is_empty())
	assert_false(ch5.event_lines("short").is_empty())
	var bad := StoryChapter.from_dict({"id": "x", "objective": {"kind": "keep", "thing": "cows"}})
	assert_true(bad.problems().has("keep needs thing storeys or lanterns"))
	assert_true(bad.problems().has("keep needs per_cliff"))


func test_keep_counts_storeys_and_lanterns() -> void:
	var a := ScaffoldNode.new()
	a.cliff_id = 0
	a.levels = 3
	var b := ScaffoldNode.new()
	b.cliff_id = 1
	b.levels = 2
	var c := ScaffoldNode.new()
	c.cliff_id = 2
	c.levels = 3
	assert_eq(StoryDirector.count_storeys([a, b, c, null], [0, 1] as Array[int]), 5, "only held cliffs")
	assert_eq(StoryDirector.count_storeys([a, b, c], [2] as Array[int]), 3)
	var l1 := StructureNode.new()
	l1.cliff_id = 0
	var l2 := StructureNode.new()
	l2.cliff_id = 0
	l2.health = Health.new()
	l2.health.dead = true
	var l3 := StructureNode.new()
	l3.cliff_id = 1
	assert_eq(StoryDirector.count_lanterns([l1, l2, l3], [0] as Array[int]), 1, "a broken lantern doesn't count")
	assert_eq(StoryDirector.count_lanterns([l1, l2, l3], [0, 1] as Array[int]), 2)
	var d := StoryDirector.new()
	d.chapter = StoryChapter.load_id("ch5")
	d.keep_have = 4
	assert_false(d.objective_done(), "keep: 4 of 5 storeys")
	d.keep_have = 5
	assert_true(d.objective_done())
	assert_eq(d.keep_noun(1), "scaffold storey")
	d.chapter = StoryChapter.load_id("ch6")
	assert_eq(d.keep_noun(2), "lantern posts")
	for n: Node in [a, b, c, l1, l3, d]:
		n.free()
	l2.health.free()
	l2.free()


# ------------------------------------------------------------------ Canyon Expedition chapters

func test_down_the_hole_data() -> void:
	var ch7 := StoryChapter.load_id("ch7")
	assert_eq(ch7.kind(), "blast")
	assert_true(ch7.floor_job(), "the job's on the canyon floor")
	assert_eq(ch7.map, &"canyon")
	assert_eq(ch7.crates_for(1), 3, "solo carries three crates")
	assert_eq(ch7.crates_for(2), 4)
	assert_eq(ch7.crates_for(4), 6, "a posse of four carries six")
	assert_true(ch7.fuse() >= 30.0, "long enough to reach a rope")
	for key: String in ["down", "crate", "inside", "hunters", "charge", "armed", "lit", "blast", "buried", "reminder", "hold", "win", "lost"]:
		assert_false(ch7.event_lines(key).is_empty(), "ch7 " + key)
	assert_true(StoryChapter.load_id("ch8").sealed_tunnel, "the tunnel stays blown for the Queen")
	assert_false(ch7.sealed_tunnel, "it's open until you blow it")
	assert_true(Defs.turret(StringName(str(ch7.unlock()["id"]))) != null, "the blueprint is a real turret")


func test_floor_fetches() -> void:
	var ch2 := StoryChapter.load_id("ch2")
	assert_eq(str(ch2.objective["spawn"]), "floor_wagon", "the valve's in the wrecked wagon")
	assert_eq(ch2.pack_item(), &"pump_valve")
	assert_true(ch2.floor_job())
	var ch3 := StoryChapter.load_id("ch3")
	assert_eq(str(ch3.objective["spawn"]), "boss_carcass", "the gland's in her carcass on the floor")
	assert_eq(ch3.pack_item(), &"queen_gland")
	for ch in [ch2, ch3]:
		assert_true(Backpack.weight_of(ch.pack_item()) > 1, "%s's item weighs something" % ch.id)
		assert_false(ch.event_lines("up").is_empty(), "%s says when it's out of the canyon" % ch.id)
	# The old plateau stand-ins still pass the validator.
	var old := StoryChapter.from_dict({"id": "ch2", "number": 2, "title": "X", "objective": {"kind": "fetch", "spawn": "airship_drop", "deliver_to": "well"}})
	assert_false(old.floor_job())
	assert_eq(old.pack_item(), &"")
	assert_false("
".join(old.problems()).contains("fetch needs spawn"), "airship_drop still a spawn")
	var bad := StoryChapter.from_dict({"id": "x", "number": 1, "title": "X", "objective": {"kind": "fetch", "spawn": "floor_wagon", "deliver_to": "well"}})
	assert_true("
".join(bad.problems()).contains("pack_item"), "a floor fetch needs a pack item")
	var blast := StoryChapter.from_dict({"id": "x", "number": 1, "title": "X", "objective": {"kind": "blast", "fuse": 5}})
	var bp := "
".join(blast.problems())
	assert_true(bp.contains("blast needs crates") and bp.contains("fuse"), "blast data checked")


func test_story_items_stay_out_of_the_stockpile() -> void:
	var split := ExpeditionRules.split_story({&"scrap": 12, &"pump_valve": 1, &"dynamite": 2}, [&"pump_valve", &"dynamite"])
	assert_eq(split[0], {&"scrap": 12}, "loot unpacks as usual")
	assert_eq(split[1], {&"pump_valve": 1, &"dynamite": 2}, "the chapter keeps its items")
	var pack := Backpack.make()
	assert_eq(pack.add({BlastRules.ITEM: 3}), 2, "two dynamite crates to a pack")
	assert_true(pack.speed_mult() < 0.75, "and you walk slow with them")
