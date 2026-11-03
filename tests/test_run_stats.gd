extends TestCase
## End-of-run newspaper numbers.


func test_counts_and_tops() -> void:
	RunStats.reset()
	RunStats.note_kill("Dust Mite", "Logan", 2)
	RunStats.note_kill("Dust Mite", "Logan's Gatling Post", 2)
	RunStats.note_kill("Brood Mother", "Logan's Gatling Post", 9)
	assert_eq(RunStats.kills, 3)
	assert_eq(RunStats.scrap, 13)
	assert_eq(str(RunStats.top_source()[0]), "Logan's Gatling Post")
	assert_eq(int(RunStats.top_bug()[1]), 2)
	RunStats.reset()
	assert_eq(RunStats.kills, 0)


func test_headlines() -> void:
	assert_eq(RunStats.headline(true, 20, "Canyon"), "RANCHERS HOLD CANYON THROUGH 20 WAVES")
	assert_eq(RunStats.headline(false, 1, "Mesa"), "MESA FALLS ON THE FIRST NIGHT")
	assert_eq(RunStats.count_of(1, "kill"), "1 kill")
	assert_eq(RunStats.count_of(4, "kill"), "4 kills")
