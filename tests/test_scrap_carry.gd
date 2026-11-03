extends TestCase
## Perk: Scrap Scavenger: the multiplier pays out fairly on 1-3 scrap kills.


func test_small_kills_add_up() -> void:
	var c := ScrapCarry.new()
	var got := 0
	for i in 100:
		got += c.scale(0, 1, 1.25)
	assert_eq(got, 125, "100 one-scrap kills at x1.25")
	var c2 := ScrapCarry.new()
	got = 0
	for i in 10:
		got += c2.scale(1, 3, 1.5)
	assert_eq(got, 45, "10 three-scrap kills at x1.5")


func test_bonus_shows_up_soon() -> void:
	var c := ScrapCarry.new()
	var got: Array[int] = []
	for i in 4:
		got.append(c.scale(0, 1, 1.25))
	assert_eq(got, [1, 1, 1, 2] as Array[int], "the 4th one-scrap kill pays the carried quarters")


func test_cliffs_carry_separately_and_x1_untouched() -> void:
	var c := ScrapCarry.new()
	assert_eq(c.scale(0, 1, 1.5), 1)
	assert_eq(c.scale(1, 1, 1.5), 1, "cliff 1 doesn't get cliff 0's half")
	assert_eq(c.scale(0, 1, 1.5), 2)
	assert_eq(c.scale(2, 7, 1.0), 7)
	assert_eq(c.scale(2, 0, 1.0), 0)
