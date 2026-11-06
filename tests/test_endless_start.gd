extends TestCase
## Endless from a later wave: the riders start with what a team would have
## earned by then, and a quarter more.


func test_wave_one_is_a_normal_start() -> void:
	var r := EndlessStart.resources(1, 2)
	assert_eq(int(r["team"]), Defs.WAVE_CONFIG.start_scrap)
	assert_eq(int(r["personal"]), 0)


func test_later_waves_start_richer() -> void:
	var prev := EndlessStart.resources(1, 2)
	for w: int in [2, 5, 10, 25, 50]:
		var r := EndlessStart.resources(w, 2)
		assert_true(int(r["team"]) > int(prev["team"]), "wave %d team pot grows" % w)
		assert_true(int(r["personal"]) > int(prev["personal"]), "wave %d own stock grows" % w)
		prev = r


func test_bonus_is_a_quarter_over_the_bounty_and_heaps() -> void:
	# Wave 2: one held wave's bounty per cliff and one junk heap, plus wave 1's kills.
	var r := EndlessStart.resources(2, 2)
	var heap := EconomyLedger.heap_pay(0, Defs.WAVE_CONFIG)
	assert_eq(int(r["personal"]), roundi(heap * EndlessStart.BONUS))
	var floor_team := (Defs.WAVE_CONFIG.start_scrap + EconomyLedger.wave_pay(1) * 2) * EndlessStart.BONUS
	assert_true(int(r["team"]) > floor_team, "kills pay on top of the bounty")
