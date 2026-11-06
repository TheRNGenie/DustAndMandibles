extends TestCase
## Casino chips: paying a stake out of a stack, with the house making change.


func _apply(held: Dictionary, plan: Dictionary) -> Dictionary:
	var out := held.duplicate()
	for id: StringName in plan["spend"]:
		out[id] = int(out.get(id, 0)) - int(plan["spend"][id])
	for id: StringName in plan["add"]:
		out[id] = int(out.get(id, 0)) + int(plan["add"][id])
	return out


func test_exact_stake_uses_biggest_chips_first() -> void:
	var held := {&"chip_10": 3, &"chip_50": 1}
	var plan := ChipRules.pay(held, 60)
	assert_eq(plan["spend"], {&"chip_50": 1, &"chip_10": 1})
	assert_true((plan["add"] as Dictionary).is_empty())


func test_house_breaks_a_big_chip_for_change() -> void:
	var held := {&"chip_50": 1}
	var plan := ChipRules.pay(held, 20)
	var after := _apply(held, plan)
	assert_eq(int(after[&"chip_50"]), 0)
	assert_eq(int(after[&"chip_10"]), 3)
	assert_eq(ChipRules.total(after), 30)


func test_every_payable_stake_keeps_the_value() -> void:
	var held := {&"chip_10": 1, &"chip_20": 2, &"chip_50": 1, &"chip_100": 1}
	var start := ChipRules.total(held)
	for amount in range(10, start + 1, 10):
		var plan := ChipRules.pay(held, amount)
		assert_false(plan.is_empty())
		var after := _apply(held, plan)
		assert_eq(ChipRules.total(after), start - amount)
		for id: StringName in after:
			assert_true(int(after[id]) >= 0)


func test_not_enough_chips_pays_nothing() -> void:
	assert_true(ChipRules.pay({&"chip_10": 1}, 20).is_empty())
	assert_true(ChipRules.pay({}, 10).is_empty())
	assert_true(ChipRules.pay({&"chip_100": 1}, 15).is_empty())


func test_chip_ids_round_trip() -> void:
	for v in ChipRules.DENOMS:
		assert_true(ChipRules.is_chip(ChipRules.id_of(v)))
		assert_eq(ChipRules.value_of(ChipRules.id_of(v)), v)
	assert_false(ChipRules.is_chip(&"chitin"))
