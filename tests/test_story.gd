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
	assert_eq(StoryChapter.all().size(), 4, "four playable chapters")
	for ch in StoryChapter.all():
		assert_eq(ch.problems(), [] as Array[String], ch.id)
		assert_eq(ch.id, StoryChapter.IDS[ch.number - 1], "ids in order")


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
	assert_eq(_count(plan, &"dragonfly_bandit") - before, 10, "ten extra bandits")
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
	assert_eq(StoryChapter.next_id("ch4"), "", "chapter 5 isn't built yet")


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
	var junk := StoryProgress.from_dict({"done": {"ch9": {}, "ch1": "x"}, "journal": "nope"})
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
			"cosmetic":
				var parts := str(u["id"]).split(":")
				assert_true(PerkTable.cosmetic_price(parts[0], parts[1]) > 0, "%s cosmetic %s is a bought one" % [ch.id, u["id"]])
			_:
				assert_true(false, "%s has a known unlock" % ch.id)


func test_every_speaker_has_a_portrait_look() -> void:
	for who in StoryChapter.SPEAKERS:
		assert_true(StoryPortrait.CAST.has(who), who)
		assert_true(StoryChapter.speaker_name(who) != who, who + " has a name")
