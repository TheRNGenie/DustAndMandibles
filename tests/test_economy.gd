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
