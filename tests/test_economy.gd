extends TestCase
## Economy spend / earn / transfer: scrap is one shared team pot, chitin (and
## everything else) is each cliff's own.


func _ledger(cliffs: int = 2) -> EconomyLedger:
	var l := EconomyLedger.new()
	l.reset({&"scrap": 100, &"water": 6}, cliffs)
	return l


func test_start_amounts() -> void:
	var l := _ledger()
	assert_eq(l.team_amount(&"scrap"), 200, "every player's start scrap goes in the pot")
	assert_eq(l.amount(0, &"scrap"), 200, "both cliffs read the same pot")
	assert_eq(l.amount(1, &"scrap"), 200)
	assert_eq(l.amount(0, &"chitin"), 0)
	assert_eq(l.amount(1, &"water"), 6, "personal resources start per cliff")


func test_spend_scrap_comes_out_of_the_shared_pot() -> void:
	var l := _ledger()
	assert_true(l.spend(0, {&"scrap": 40}))
	assert_eq(l.amount(0, &"scrap"), 160)
	assert_eq(l.amount(1, &"scrap"), 160, "the partner sees the same pot")


func test_chitin_is_personal() -> void:
	var l := _ledger()
	l.earn(0, {&"chitin": 12})
	assert_eq(l.amount(0, &"chitin"), 12)
	assert_eq(l.amount(1, &"chitin"), 0, "the partner's chitin is untouched")
	assert_false(l.spend(1, {&"chitin": 5}), "can't spend your partner's chitin")
	assert_true(l.spend(0, {&"chitin": 5}))
	assert_eq(l.amount(0, &"chitin"), 7)


func test_mixed_cost_checks_each_pile() -> void:
	var l := _ledger()
	l.earn(1, {&"chitin": 10})
	assert_false(l.spend(0, {&"scrap": 50, &"chitin": 10}), "cliff 0 has no chitin")
	assert_eq(l.amount(0, &"scrap"), 200, "nothing taken on failure")
	assert_true(l.spend(1, {&"scrap": 50, &"chitin": 10}))
	assert_eq(l.team_amount(&"scrap"), 150)
	assert_eq(l.amount(1, &"chitin"), 0)


func test_spend_fails_without_change_when_too_poor() -> void:
	var l := _ledger()
	assert_false(l.spend(0, {&"scrap": 60, &"chitin": 1}))
	assert_eq(l.amount(0, &"scrap"), 200)


func test_earn_adds() -> void:
	var l := _ledger()
	l.earn(1, {&"scrap": 5, &"chitin": 2})
	assert_eq(l.amount(0, &"scrap"), 205, "scrap earned by anyone lands in the pot")
	assert_eq(l.amount(1, &"chitin"), 2)
	assert_eq(l.amount(0, &"chitin"), 0)


func test_transfer_moves_chitin_but_never_scrap() -> void:
	var l := _ledger()
	l.earn(0, {&"chitin": 20})
	assert_true(l.transfer(0, 1, {&"chitin": 8}))
	assert_eq(l.amount(0, &"chitin"), 12)
	assert_eq(l.amount(1, &"chitin"), 8)
	assert_false(l.transfer(0, 1, {&"chitin": 500}))
	assert_false(l.transfer(0, 1, {&"scrap": 30}), "scrap is already shared")
	assert_eq(l.team_amount(&"scrap"), 200)


func test_wave_pay_grows_and_skips_the_start() -> void:
	assert_eq(EconomyLedger.wave_pay(0), 0, "nothing before the first wave")
	assert_eq(EconomyLedger.wave_pay(1), 35)
	assert_true(EconomyLedger.wave_pay(5) > EconomyLedger.wave_pay(1))


func test_negative_spend_and_transfer_rejected() -> void:
	var l := _ledger()
	l.earn(0, {&"chitin": 10})
	assert_false(l.spend(0, {&"scrap": -50}))
	assert_eq(l.amount(0, &"scrap"), 200)
	assert_false(l.transfer(0, 1, {&"chitin": -20}))
	assert_eq(l.amount(1, &"chitin"), 0)


func test_four_cliff_map_pot_and_personal_piles() -> void:
	var l := _ledger(4)
	assert_eq(l.team_amount(&"scrap"), 400)
	assert_eq(l.cliff_ids(), [0, 1, 2, 3] as Array[int], "the team pot is not a cliff")
	l.earn(3, {&"chitin": 4, &"scrap": 10})
	assert_eq(l.amount(2, &"scrap"), 410)
	assert_eq(l.amount(3, &"chitin"), 4)
	assert_eq(l.amount(2, &"chitin"), 0)


func test_solo_one_cliff_pot() -> void:
	var l := _ledger(1)
	assert_eq(l.team_amount(&"scrap"), 100)
	assert_true(l.spend(0, {&"scrap": 100}))
	assert_eq(l.amount(0, &"scrap"), 0)


func test_pool_shared_sums_old_per_cliff_scrap() -> void:
	var pooled := EconomyLedger.pool_shared({0: {&"scrap": 30, &"chitin": 2}, 1: {&"scrap": 45}})
	assert_eq(pooled[EconomyLedger.TEAM][&"scrap"], 75)
	assert_false((pooled[0] as Dictionary).has(&"scrap"))
	assert_eq(pooled[0][&"chitin"], 2)
	var again := EconomyLedger.pool_shared(pooled)
	assert_eq(again[EconomyLedger.TEAM][&"scrap"], 75, "pooling twice changes nothing")
