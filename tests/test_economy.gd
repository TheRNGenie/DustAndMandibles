extends TestCase
## Economy spend / earn / transfer.


func _ledger() -> EconomyLedger:
	var l := EconomyLedger.new()
	l.reset({&"scrap": 100})
	return l


func test_start_amounts() -> void:
	var l := _ledger()
	assert_eq(l.amount(0, &"scrap"), 100)
	assert_eq(l.amount(1, &"scrap"), 100)
	assert_eq(l.amount(0, &"chitin"), 0)


func test_spend_deducts_when_affordable() -> void:
	var l := _ledger()
	assert_true(l.spend(0, {&"scrap": 40}))
	assert_eq(l.amount(0, &"scrap"), 60)
	assert_eq(l.amount(1, &"scrap"), 100, "other cliff untouched")


func test_spend_fails_without_change_when_too_poor() -> void:
	var l := _ledger()
	assert_false(l.spend(0, {&"scrap": 60, &"chitin": 1}))
	assert_eq(l.amount(0, &"scrap"), 100)


func test_earn_adds() -> void:
	var l := _ledger()
	l.earn(1, {&"scrap": 5, &"chitin": 2})
	assert_eq(l.amount(1, &"scrap"), 105)
	assert_eq(l.amount(1, &"chitin"), 2)


func test_transfer_moves_between_cliffs() -> void:
	var l := _ledger()
	assert_true(l.transfer(0, 1, {&"scrap": 30}))
	assert_eq(l.amount(0, &"scrap"), 70)
	assert_eq(l.amount(1, &"scrap"), 130)
	assert_false(l.transfer(0, 1, {&"scrap": 500}))


func test_wave_pay_grows_and_skips_the_start() -> void:
	assert_eq(EconomyLedger.wave_pay(0), 0, "nothing before the first wave")
	assert_eq(EconomyLedger.wave_pay(1), 35)
	assert_true(EconomyLedger.wave_pay(5) > EconomyLedger.wave_pay(1))


func test_negative_spend_and_transfer_rejected() -> void:
	var l := _ledger()
	assert_false(l.spend(0, {&"scrap": -50}))
	assert_eq(l.amount(0, &"scrap"), 100)
	assert_false(l.transfer(0, 1, {&"scrap": -20}))
	assert_eq(l.amount(1, &"scrap"), 100)
