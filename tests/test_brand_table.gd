extends TestCase
## BrandTable: the per-run brand buffs (Sheaf, Crossed Irons, Snake Eyes, No Brand)
## and the Snake Eyes cheat odds. Checks the rules against the table's own
## constants, so retuning a number doesn't break the test.


func test_every_id_has_a_brand_and_junk_is_no_brand() -> void:
	for id in BrandTable.IDS:
		assert_true(BrandTable.BRANDS.has(id), "missing %s" % id)
		assert_true(BrandTable.name_of(id) != "", "name of %s" % id)
		assert_true(BrandTable.short_of(id) != "", "short of %s" % id)
	assert_eq(BrandTable.valid("sheaf"), BrandTable.SHEAF, "a saved String still reads")
	assert_eq(BrandTable.valid(&"nonsense"), BrandTable.NONE)
	assert_eq(BrandTable.valid(null), BrandTable.NONE)
	assert_eq(BrandTable.valid(3), BrandTable.NONE)
	assert_eq(BrandTable.IDS.size(), BrandTable.BRANDS.size() - 1, "pick screen shows every brand but No Brand (an unpicked rider)")
	assert_false(BrandTable.IDS.has(BrandTable.NONE))


func test_theme_of() -> void:
	assert_eq(BrandTable.theme_of(BrandTable.NONE), &"base")
	assert_eq(BrandTable.theme_of(&"junk"), &"base")
	assert_eq(BrandTable.theme_of(BrandTable.SHEAF), BrandTable.SHEAF)


func test_buffs_only_for_their_own_brand() -> void:
	for id in BrandTable.IDS:
		assert_almost(BrandTable.growth_mult(id), 1.0 + BrandTable.CROP_GROWTH if id == BrandTable.SHEAF else 1.0)
		assert_almost(BrandTable.reload_mult(id), 1.0 - BrandTable.RELOAD if id == BrandTable.IRONS else 1.0)
		assert_almost(BrandTable.boss_mult(id), 1.0 + BrandTable.BOSS_DAMAGE if id == BrandTable.SNAKE else 1.0)
		assert_eq(BrandTable.can_cheat(id), id == BrandTable.SNAKE)
		if id != BrandTable.SHEAF:
			assert_eq(BrandTable.water_bonus(4, id), 0)
			assert_eq(BrandTable.seed_cost(10, id), 10)
			assert_eq(BrandTable.scale_yield({&"corn": 5}, id, 0.0), {&"corn": 5})
		if id != BrandTable.IRONS:
			assert_eq(BrandTable.kill_loot({&"scrap": 5, &"chitin": 2}, id), {&"scrap": 5, &"chitin": 2})
			assert_eq(BrandTable.heap_loot(4, id), {&"scrap": 4})


func test_buffs_stay_modest() -> void:
	for k: float in [BrandTable.CROP_YIELD, BrandTable.CROP_GROWTH, BrandTable.WATER_FILL, BrandTable.SEED_DISCOUNT,
			BrandTable.RELOAD, BrandTable.KILL_LOOT, BrandTable.HEAP_LOOT, BrandTable.BOSS_DAMAGE]:
		assert_true(k > 0.0 and k <= 0.25, "buff %.2f outside 0..25%%" % k)


func test_sheaf_yield_rounds_by_chance_and_only_main_crop() -> void:
	var h := {&"corn": 7, &"seed_corn": 1}
	var extra := 7.0 * BrandTable.CROP_YIELD
	var low := BrandTable.scale_yield(h, BrandTable.SHEAF, 0.999)
	var high := BrandTable.scale_yield(h, BrandTable.SHEAF, 0.0)
	assert_eq(int(low[&"corn"]), 7 + int(floor(extra)), "roll over the fraction: no extra")
	assert_eq(int(high[&"corn"]), 7 + int(floor(extra)) + (1 if extra > floor(extra) else 0), "roll under: one more")
	assert_eq(int(high[&"seed_corn"]), 1, "seed bonus untouched")
	assert_eq(int(h[&"corn"]), 7, "input not changed")
	assert_eq(BrandTable.scale_yield({}, BrandTable.SHEAF, 0.0), {})
	# The average over rolls is +CROP_YIELD.
	var total := 0
	for i in 1000:
		total += int(BrandTable.scale_yield({&"corn": 3}, BrandTable.SHEAF, (float(i) + 0.5) / 1000.0)[&"corn"])
	assert_almost(total / 1000.0, 3.0 * (1.0 + BrandTable.CROP_YIELD), 0.01)


func test_sheaf_water_and_seeds() -> void:
	assert_eq(BrandTable.water_bonus(0, BrandTable.SHEAF), 0)
	assert_eq(BrandTable.water_bonus(1, BrandTable.SHEAF), 1, "at least +1")
	assert_eq(BrandTable.water_bonus(8, BrandTable.SHEAF), roundi(8 * BrandTable.WATER_FILL))
	assert_eq(BrandTable.seed_cost(1, BrandTable.SHEAF), 1, "never free")
	assert_eq(BrandTable.seed_cost(10, BrandTable.SHEAF), roundi(10 * (1.0 - BrandTable.SEED_DISCOUNT)))
	assert_true(BrandTable.seed_cost(50, BrandTable.SHEAF) < 50)


func test_irons_loot() -> void:
	var l := BrandTable.kill_loot({&"scrap": 10, &"chitin": 5, &"mult": 1.0}, BrandTable.IRONS)
	assert_eq(l[&"scrap"], roundi(10 * (1.0 + BrandTable.KILL_LOOT)))
	assert_eq(l[&"chitin"], roundi(5 * (1.0 + BrandTable.KILL_LOOT)))
	assert_almost(float(l[&"mult"]), 1.0 + BrandTable.KILL_LOOT)
	for n in 20:
		assert_true(int(BrandTable.kill_loot({&"scrap": n}, BrandTable.IRONS)[&"scrap"]) >= n, "never less loot")
	var heap := BrandTable.heap_loot(4, BrandTable.IRONS)
	assert_eq(heap, {&"scrap": int(ceil(4 * (1.0 + BrandTable.HEAP_LOOT))) + BrandTable.HEAP_SCRAP})
	assert_true(int(BrandTable.heap_loot(1, BrandTable.IRONS)[&"scrap"]) >= 2 + BrandTable.HEAP_SCRAP, "a 1-shell heap still pays extra (ceil)")


func test_cheat_odds() -> void:
	# Logan: 70% at first, +5% per cheat that gets past him, up to certain.
	for game: String in ["shell", "slots", "roulette", "blackjack", "race"]:
		assert_almost(BrandTable.catch_chance(game, 0), 0.70, 0.0001, game)
		var prev := 0.70
		for heat in range(1, 15):
			var c := BrandTable.catch_chance(game, heat)
			assert_true(c >= prev, "heat never lowers the risk")
			assert_true(c <= 1.0001, "capped")
			prev = c
	assert_almost(BrandTable.catch_chance("shell", 1), 0.75)
	assert_almost(BrandTable.catch_chance("shell", 6), 1.0)
	assert_almost(BrandTable.catch_chance("shell", 100), 1.0)
	assert_almost(BrandTable.catch_chance("shell", -3), 0.70, 0.0001, "negative heat is no heat")


func test_ban_covers_the_next_wave() -> void:
	var until := BrandTable.ban_until(6)
	assert_true(7 < until, "barred on the next wave")
	assert_eq(until, 6 + BrandTable.BAN_WAVES + 1)


func test_nudge_moves_one_reel_one_step_to_the_best() -> void:
	# Score: three of a kind of symbol 2 pays 10, two 2s pay 3.
	var value := func(r: Array) -> int:
		var twos := r.count(2)
		return 10 if twos == 3 else (3 if twos == 2 else 0)
	assert_eq(BrandTable.nudge_reels([2, 2, 1], 5, value), [2, 2, 2])
	assert_eq(BrandTable.nudge_reels([2, 2, 3], 5, value), [2, 2, 2])
	assert_eq(BrandTable.nudge_reels([2, 2, 0], 5, value), [2, 2, 0], "two steps away: no nudge helps")
	assert_eq(BrandTable.nudge_reels([4, 2, 2], 5, value), [4, 2, 2])
	# Wraps round the strip.
	var top := func(r: Array) -> int: return 5 if r[0] == 0 else 0
	assert_eq(BrandTable.nudge_reels([4, 1, 1], 5, top), [0, 1, 1])
	var src := [2, 2, 1]
	BrandTable.nudge_reels(src, 5, value)
	assert_eq(src, [2, 2, 1], "input reels not changed")


func test_cpu_pick_is_a_real_brand() -> void:
	var got := {}
	for s in range(-5, 30):
		var b := BrandTable.cpu_pick(s)
		assert_true(b != BrandTable.NONE and BrandTable.BRANDS.has(b))
		got[b] = true
	assert_eq(got.size(), 3, "all three brands come up")


func test_attack_on_mandibles() -> void:
	for id in BrandTable.IDS:
		var m := id == BrandTable.MANDIBLES
		assert_almost(BrandTable.combo_gain(id), 1.25 if m else 1.0)
		assert_almost(BrandTable.sling_mult(id), 1.2 if m else 1.0)
		assert_almost(BrandTable.grapple_speed(id), 1.15 if m else 1.0)
		assert_almost(BrandTable.zip_cost_mult(id), 0.8 if m else 1.0)
	assert_eq(BrandTable.theme_of(BrandTable.MANDIBLES), BrandTable.MANDIBLES)
	assert_eq(int(ZipRules.recipe(BrandTable.zip_cost_mult(BrandTable.MANDIBLES))[ResNames.PERSONAL_ID]), 12)
