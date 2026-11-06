extends TestCase
## The style combo: grades, pay, the still-standing grace and the slingshot hit.


func test_grades_follow_the_plan() -> void:
	assert_eq(ComboRules.grade(0), "")
	assert_eq(ComboRules.grade(1), "C")
	assert_eq(ComboRules.grade(4), "C")
	assert_eq(ComboRules.grade(5), "B")
	assert_eq(ComboRules.grade(10), "A")
	assert_eq(ComboRules.grade(19), "A")
	assert_eq(ComboRules.grade(20), "S")
	assert_eq(ComboRules.grade(30), "S+")


func test_pay_is_five_percent_a_point_capped() -> void:
	assert_almost(ComboRules.mult(0), 1.0)
	assert_almost(ComboRules.mult(10), 1.5)
	assert_almost(ComboRules.mult(30), 2.5)
	assert_almost(ComboRules.mult(99), 2.5)


func test_grace_shrinks_with_waves() -> void:
	assert_almost(ComboRules.still_secs(1), 2.0)
	assert_almost(ComboRules.still_secs(25), 1.5)
	assert_almost(ComboRules.still_secs(50), 1.0)
	assert_almost(ComboRules.still_secs(200), 1.0)


func test_slingshot_damage_scales() -> void:
	assert_almost(ComboRules.sling_damage(0), 80.0)
	assert_almost(ComboRules.sling_damage(15), 140.0)
	assert_almost(ComboRules.sling_damage(30), 200.0)



func test_hot_streak_cuts() -> void:
	assert_almost(ComboRules.streak_cut(14), 0.0)
	assert_almost(ComboRules.streak_cut(15), 0.10)
	assert_almost(ComboRules.streak_cut(25), 0.15)
	assert_eq(ComboRules.cut_price(100, 0.15), 85)
	assert_eq(ComboRules.cut_price(7, 0.10), 7)
	assert_eq(ComboRules.cut_price(1, 0.15), 1)
	assert_eq(ComboRules.cut_price(40, 0.0), 40)
