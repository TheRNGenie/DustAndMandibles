extends TestCase
## CPU teammates never spend more than their share of the shared pool.


func test_share_is_one_slice_of_the_team() -> void:
	assert_almost(CpuBudget.share(1, 4), 0.25)
	assert_almost(CpuBudget.share(1, 2), 0.5)
	assert_almost(CpuBudget.share(0, 2), 0.0)


func test_cpu_stops_at_its_share() -> void:
	# Team has had 400 scrap; a CPU in a team of 4 may spend 100 in all.
	var s := CpuBudget.share(1, 4)
	assert_true(CpuBudget.may_spend(0, 100, 400, s))
	assert_true(not CpuBudget.may_spend(60, 50, 400, s))
	assert_true(CpuBudget.may_spend(60, 40, 400, s))


func test_all_resources_must_fit() -> void:
	var s := CpuBudget.share(1, 2)
	var spent := {&"scrap": 90, &"water": 0}
	var gained := {&"scrap": 200, &"water": 10}
	assert_true(CpuBudget.may_spend_all(spent, {&"scrap": 10, &"water": 5}, gained, s))
	assert_true(not CpuBudget.may_spend_all(spent, {&"scrap": 11}, gained, s))
	assert_true(not CpuBudget.may_spend_all(spent, {&"water": 6}, gained, s))
