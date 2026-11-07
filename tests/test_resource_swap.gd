extends TestCase
## DECISIONS 162: players see the team pot (&"scrap") as CHITIN and their own
## stock (&"chitin") as SCRAP. Bugs pay the team pot; the junk heap pays you.


func test_names_and_icons_are_swapped() -> void:
	assert_eq(ResNames.team(), "chitin")
	assert_eq(ResNames.personal(), "scrap")
	assert_eq(ResNames.of(&"scrap"), "chitin")
	assert_eq(ResNames.of(&"chitin"), "scrap")
	assert_eq(ResNames.of(&"seed_corn"), "seed corn")
	assert_eq(ResNames.icon_key(&"scrap"), &"chitin", "the team pot wears the chitin icon")
	assert_eq(ResNames.icon_key(&"chitin"), &"scrap", "your own stock wears the scrap icon")
	assert_eq(ResNames.icon_key(&"water"), &"water")
	assert_eq(UiStyle.cost(60, "scrap"), "60 Chitin")
	assert_eq(UiStyle.cost(5, "chitin"), "5 Scrap")
	assert_eq(UiStyle.cost(150, "team scrap"), "150 Team Chitin")
	assert_eq(UiStyle.resource_color(&"scrap"), Palette.BEETLE_TEAL.lightened(0.15))


func test_shown_words_parse_back_to_ids() -> void:
	assert_eq(ResNames.id_of("Chitin"), &"scrap")
	assert_eq(ResNames.id_of("scrap"), &"chitin")
	assert_eq(ResNames.id_of("Seed Corn"), &"seed_corn")
	# A price as the shops print it comes back as the same cost.
	var cost := {&"scrap": 80, &"chitin": 10}
	var parts := (UiStyle.cost(80, "scrap") + " + " + UiStyle.cost(10, "chitin")).split("+") # as Homestead.cost_text prints it
	var back := {}
	for p in parts:
		var bits := p.strip_edges().split(" ", false)
		back[ResNames.id_of(bits[1])] = int(bits[0])
	assert_eq(back, cost)


func test_every_bug_pays_the_team_pot() -> void:
	# A big bug's shell bonus (old personal chitin) goes into the pot with its drop.
	assert_eq(EconomyLedger.kill_pay(150, 40), {&"scrap": 190})
	assert_eq(EconomyLedger.kill_pay(6, 2, 2.0), {&"scrap": 10}, "blood moon doubles the shell part")
	assert_eq(EconomyLedger.kill_pay(1, 0), {&"scrap": 1})
	assert_false(EconomyLedger.kill_pay(150, 40).has(&"chitin"), "no personal stock from kills")
	assert_true(EconomyLedger.is_shared(&"scrap"))
	# Shells left on the plateau, and the brand bonus on them, are team pot too.
	assert_eq(EconomyLedger.shell_pay(2, 1.0), 3)
	assert_eq(EconomyLedger.shell_pay(0, 0.5), 1, "always something")
	assert_eq(BrandTable.heap_loot(3, BrandTable.NONE), {&"scrap": 3})
	assert_false(BrandTable.heap_loot(3, BrandTable.IRONS).has(&"chitin"))
	assert_false(AmberRules.shatter_loot(1.0).has(&"chitin"))


func test_junk_heap_pays_personal_and_grows() -> void:
	var cfg := Defs.WAVE_CONFIG
	assert_eq(EconomyLedger.heap_pay(0, cfg), EconomyLedger.HEAP_MIN, "before the first wave")
	var last := 0
	for w in range(1, 21):
		var p := EconomyLedger.heap_pay(w, cfg)
		assert_true(p >= last and p >= EconomyLedger.HEAP_MIN, "wave %d: %d" % [w, p])
		last = p
	# Measured: a cliff's bug shells used to pay it ~5,000 personal over 20 waves;
	# the balance pass flattened the bug curve after wave 8, and the heap with it.
	var total := 0
	for w in range(0, 20):
		total += EconomyLedger.heap_pay(w, cfg)
	assert_true(total > 2500 and total < 4200, "20 heaps pay %d" % total)
	# Into your own stock, never the pot.
	var l := EconomyLedger.new()
	l.reset({&"scrap": 100}, 2)
	l.earn(0, {ResNames.PERSONAL_ID: EconomyLedger.heap_pay(3, cfg)})
	assert_eq(l.amount(0, &"chitin"), EconomyLedger.heap_pay(3, cfg))
	assert_eq(l.amount(1, &"chitin"), 0)
	assert_eq(l.team_amount(&"scrap"), 200)


func test_chili_still_sells_for_your_own_stock() -> void:
	assert_eq(MarketPrices.currency(&"chili"), ResNames.PERSONAL_ID)
	assert_eq(MarketPrices.currency(&"corn"), ResNames.TEAM_ID)
