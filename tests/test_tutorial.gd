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


func test_wave_plan_is_a_handful_on_the_partner_wall() -> void:
	var plan := TutorialPlan.wave(WorldLayout.EAST)
	var total := 0
	for g: Dictionary in plan["groups"]:
		total += int(g["count"])
		assert_eq(int(g["cliff"]), WorldLayout.EAST)
		assert_eq(StringName(g["bug"]), TutorialPlan.SLOW_MITE)
		assert_true(int(g["pulse"]) < int(plan["pulses"]))
	assert_true(total <= 8)
	assert_eq((plan["pulse_times"] as Array).size(), int(plan["pulses"]))
