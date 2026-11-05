extends TestCase
## Tutorial: the slow practice mite and the scripted first wave stay small and gentle.


func test_slow_mite_is_a_gentler_dust_mite() -> void:
	var base := Defs.bug(&"dust_mite")
	var slow := Defs.bug(TutorialPlan.SLOW_MITE)
	assert_true(slow != null)
	assert_eq(slow.display_name, base.display_name)
	assert_almost(slow.climb_speed, base.climb_speed * 0.6)
	assert_almost(slow.walk_speed, base.walk_speed * 0.6)
	assert_eq(slow.base_id(), &"dust_mite")
	assert_true(Defs.bug(TutorialPlan.SLOW_MITE) == slow) # made once


func test_wave_plan_is_a_covered_swarm_on_the_partner_wall() -> void:
	var plan := TutorialPlan.wave(WorldLayout.EAST)
	var total := 0
	for g: Dictionary in plan["groups"]:
		total += int(g["count"])
		assert_eq(int(g["cliff"]), WorldLayout.EAST)
		assert_eq(StringName(g["bug"]), TutorialPlan.SLOW_MITE)
		assert_true(int(g["pulse"]) < int(plan["pulses"]))
	assert_true(total >= 20 and total <= 50, "a swarm, up to 50 (Logan)")
	assert_eq(total, int(plan["spent"]))
	for g: Dictionary in plan["groups"]:
		assert_true([1, 2].has(int(g["lane"])), "only the lanes the turret covers")
	assert_eq((plan["pulse_times"] as Array).size(), int(plan["pulses"]))


## Every step's card is well formed, and reading cards have nothing to tick.
func test_steps_are_well_formed() -> void:
	assert_eq(TutorialPlan.STEPS.size(), TutorialPlan.Step.DONE)
	for d: Dictionary in TutorialPlan.STEPS:
		assert_true(str(d.get("title", "")) != "", "a step has no title")
		assert_true(d.has("tasks") and d.has("keys"), str(d["title"]))
		if d.get("read", false):
			assert_eq((d["tasks"] as Array).size(), 0, str(d["title"]))
		else:
			assert_true((d["tasks"] as Array).size() > 0, "hands-on step without tasks: %s" % d["title"])
		# Short cards: the tutorial stays quick.
		assert_true(str(d["body"]).length() <= 330, "card too long: %s" % d["title"])


## The look step can't finish the moment it appears: the card must be up a
## while AND the wall held in the sights; Continue alone doesn't do it.
func test_look_step_needs_time_and_a_held_look() -> void:
	var look: Dictionary = TutorialPlan.STEPS[TutorialPlan.Step.IDEA]
	assert_true(look.get("look", false))
	assert_false(look.get("read", false))
	assert_false(TutorialPlan.look_done(10.0, 0.5)) # staring at it from the start: too soon
	assert_false(TutorialPlan.look_done(0.5, 20.0)) # a glance isn't a look
	assert_true(TutorialPlan.look_done(TutorialPlan.DWELL, TutorialPlan.LOOK_MIN))
	assert_true(TutorialPlan.LOOK_MIN >= 5.0)


## The last step asks for the Workshop at the ledger, a craft and a placement:
## all hands-on, none of it a reading card.
func test_last_step_is_hands_on() -> void:
	var last: Dictionary = TutorialPlan.STEPS[TutorialPlan.STEPS.size() - 1]
	assert_eq(str(last["title"]), "Craft a Turret")
	assert_false(last.get("read", false))
	assert_false(last.get("look", false))
	assert_eq((last["tasks"] as Array).size(), 3)


## The house step gets enough to buy every upgrade it asks for, once.
func test_house_step_costs_everything_once() -> void:
	var ups: Array = [
		{"id": &"patch", "cost": {&"scrap": 25}},
		{"id": &"board", "cost": {&"scrap": 40}},
		{"id": &"reinforce", "cost": {&"scrap": 80, &"chitin": 10}},
		{"id": &"workshop", "cost": {&"scrap": 100, &"chitin": 12}},
		{"id": &"tower", "cost": {&"scrap": 220, &"chitin": 40}}]
	var none: Array[StringName] = []
	var all := TutorialPlan.house_cost(ups, none)
	assert_eq(int(all[&"scrap"]), 340) # not the patch, not the Workshop (its own step)
	assert_eq(int(all[&"chitin"]), 50)
	var some: Array[StringName] = [&"board", &"tower"]
	assert_eq(int(TutorialPlan.house_cost(ups, some)[&"scrap"]), 80)
	assert_eq(TutorialPlan.HOUSE_UPGRADES.size(), (TutorialPlan.STEPS[TutorialPlan.Step.HOUSE]["tasks"] as Array).size())
	var owned: Array[StringName] = [&"board", &"reinforce", &"porch", &"floor2", &"floor3", &"tower"]
	assert_true(TutorialPlan.house_cost(ups, owned).is_empty())


## The Workshop step's parts are one of each kind, so they make a design.
func test_workshop_parts_make_a_design() -> void:
	var id := CraftTable.design_id(&"swivel", &"scatter", &"fire")
	var recipe := CraftTable.recipe(id)
	for p: StringName in TutorialPlan.PARTS:
		assert_true(recipe.has(p), String(p))
	assert_eq(recipe.size(), TutorialPlan.PARTS.size())


## Voice gating: unvoiced lines hold their step for a reading-time stand-in
## that grows with the words; each step names a speaker and a line.
func test_voice_line_stand_in() -> void:
	var short := TutorialPlan.line_time("stroud", "Walk about.")
	var long := TutorialPlan.line_time("stroud", "one two three four five six seven eight nine ten eleven twelve")
	assert_true(short >= TutorialPlan.LINE_BASE)
	assert_true(long > short)
	assert_eq(TutorialPlan.line_time("", ""), 0.0) # read silently
	var cast := {"stroud": 0, "kettle": 0, "pearl": 0, "": 0}
	for d: Dictionary in TutorialPlan.STEPS:
		var said := TutorialPlan.line_of(d)
		assert_true(cast.has(said[0]), "uncast speaker %s" % said[0])
		cast[said[0]] += 1
		assert_eq(said[0] == "", said[1] == "", str(d["title"])) # a speaker always has a line
	assert_eq(int(cast[""]), 1) # just the newspaper
	assert_eq(str(TutorialPlan.line_of(TutorialPlan.STEPS[TutorialPlan.Step.GUNS])[0]), "kettle")
	assert_eq(str(TutorialPlan.line_of(TutorialPlan.STEPS[TutorialPlan.Step.UPGRADES])[0]), "kettle")
	assert_eq(str(TutorialPlan.line_of(TutorialPlan.STEPS[TutorialPlan.Step.WORKSHOP])[0]), "kettle")
	assert_eq(str(TutorialPlan.line_of(TutorialPlan.STEPS[TutorialPlan.Step.AIRSHIP])[0]), "pearl")


## --tutorialstep takes a number or a step's name.
func test_step_flag() -> void:
	assert_eq(TutorialPlan.step_from_flag(""), 0)
	assert_eq(TutorialPlan.step_from_flag("3"), 3)
	assert_eq(TutorialPlan.step_from_flag("house"), TutorialPlan.Step.HOUSE)
	assert_eq(TutorialPlan.step_from_flag("nonsense"), 0)


## No spoilers, and no nagging about the partner's wall beyond the one card.
func test_cards_keep_their_secrets() -> void:
	var partner := 0
	var re := RegEx.new()
	re.compile("\\b(amber|strongroom|chapter|boss|bosses|queen|lie|lied)\\b")
	for d: Dictionary in TutorialPlan.STEPS:
		var text := (str(d["title"]) + " " + str(d["body"]) + " " + str(d.get("line", ""))).to_lower()
		var hit := re.search(text)
		assert_true(hit == null, "'%s' in %s" % [hit.get_string() if hit != null else "", d["title"]])
		assert_false(text.contains("guard your partner"), str(d["title"]))
		if text.contains("in their hands"):
			partner += 1
	assert_eq(partner, 1)
