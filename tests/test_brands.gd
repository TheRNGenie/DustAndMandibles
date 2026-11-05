extends TestCase
## Brands (BrandTable): the numbers each brand changes, the Snake Eyes cheat
## odds and bans, the secret-code hashing, run-save round trip of brands, and
## the UI's Title Case helper.


func test_ids_and_themes() -> void:
	assert_eq(BrandTable.IDS.size(), 4, "three brands and No Brand")
	assert_eq(BrandTable.valid("sheaf"), BrandTable.SHEAF)
	assert_eq(BrandTable.valid("nonsense"), BrandTable.NONE, "unknown ids ride unbranded")
	assert_eq(BrandTable.theme_of(BrandTable.NONE), &"base", "No Brand keeps the Frontier look")
	for id: StringName in [BrandTable.SHEAF, BrandTable.IRONS, BrandTable.SNAKE]:
		assert_eq(BrandTable.theme_of(id), id)
		assert_true(UiStyle.SETS.has(BrandTable.theme_of(id)), "every brand has a UI set")
	assert_true(UiStyle.SETS.has(&"base"))


func test_sheaf_farming() -> void:
	assert_almost(BrandTable.growth_mult(BrandTable.SHEAF), 1.15)
	assert_almost(BrandTable.growth_mult(BrandTable.IRONS), 1.0)
	# 5 corn +20% = 6 exactly; 3 corn +20% = 3.6: the 0.6 pays on a low roll.
	assert_eq(BrandTable.scale_yield({&"corn": 5}, BrandTable.SHEAF, 0.99), {&"corn": 6})
	assert_eq(BrandTable.scale_yield({&"corn": 3}, BrandTable.SHEAF, 0.1), {&"corn": 4})
	assert_eq(BrandTable.scale_yield({&"corn": 3}, BrandTable.SHEAF, 0.9), {&"corn": 3})
	assert_eq(BrandTable.scale_yield({&"corn": 3}, BrandTable.SNAKE, 0.0), {&"corn": 3}, "other brands: no change")
	assert_eq(BrandTable.water_bonus(4, BrandTable.SHEAF), 1)
	assert_eq(BrandTable.water_bonus(8, BrandTable.SHEAF), 2)
	assert_eq(BrandTable.water_bonus(4, BrandTable.NONE), 0)
	assert_eq(BrandTable.seed_cost(10, BrandTable.SHEAF), 8)
	assert_eq(BrandTable.seed_cost(1, BrandTable.SHEAF), 1, "never free")
	assert_eq(BrandTable.seed_cost(10, BrandTable.IRONS), 10)


func test_irons_combat() -> void:
	assert_almost(BrandTable.reload_mult(BrandTable.IRONS), 0.85)
	assert_almost(BrandTable.reload_mult(BrandTable.SHEAF), 1.0)
	var loot := BrandTable.kill_loot({&"scrap": 5, &"chitin": 2.0}, BrandTable.IRONS)
	assert_eq(loot[&"scrap"], 6)
	assert_almost(loot[&"chitin"], 2.4)
	assert_eq(BrandTable.kill_loot({&"scrap": 5}, BrandTable.SNAKE), {&"scrap": 5})
	# Shell heaps pay the team pot (DECISIONS 162).
	assert_eq(BrandTable.heap_loot(4, BrandTable.IRONS), {&"scrap": 5 + BrandTable.HEAP_SCRAP})
	assert_eq(BrandTable.heap_loot(4, BrandTable.NONE), {&"scrap": 4})


func test_snake_bosses_and_cheats() -> void:
	assert_almost(BrandTable.boss_mult(BrandTable.SNAKE), 1.2)
	assert_almost(BrandTable.boss_mult(BrandTable.IRONS), 1.0)
	assert_true(BrandTable.can_cheat(BrandTable.SNAKE))
	assert_false(BrandTable.can_cheat(BrandTable.SHEAF))
	assert_almost(BrandTable.catch_chance("shell", 0), 0.18)
	assert_almost(BrandTable.catch_chance("shell", 2), 0.38, 0.001, "each cheat this wave adds heat")
	assert_almost(BrandTable.catch_chance("roulette", 50), BrandTable.MAX_RISK, 0.001, "capped")
	assert_eq(BrandTable.ban_until(4), 6, "barred through the next wave")
	# Every number stays modest (10-25%).
	for v: float in [BrandTable.CROP_YIELD, BrandTable.CROP_GROWTH, BrandTable.WATER_FILL, BrandTable.SEED_DISCOUNT,
			BrandTable.RELOAD, BrandTable.KILL_LOOT, BrandTable.HEAP_LOOT, BrandTable.BOSS_DAMAGE]:
		assert_true(v >= 0.1 and v <= 0.25, "modest number %f" % v)


func test_slot_nudge_only_helps() -> void:
	var value := func(r: Array) -> int: return CasinoRules.slot_payout(r)
	# Cactus, cactus, chili: nudge the chili down a step into a third cactus.
	var nudged := BrandTable.nudge_reels([1, 1, 2], CasinoRules.SLOT_SYMBOLS.size(), value)
	assert_eq(nudged, [1, 1, 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var reels := [rng.randi_range(0, 4), rng.randi_range(0, 4), rng.randi_range(0, 4)]
		var n := BrandTable.nudge_reels(reels, 5, value)
		assert_true(CasinoRules.slot_payout(n) >= CasinoRules.slot_payout(reels))
		var moved := 0
		for k in 3:
			if n[k] != reels[k]:
				moved += 1
		assert_true(moved <= 1, "a nudge moves one reel")


func test_cpu_gets_a_real_brand() -> void:
	for s in 10:
		assert_true(BrandTable.cpu_pick(s) in [BrandTable.SHEAF, BrandTable.IRONS, BrandTable.SNAKE])


func test_secret_codes_hash() -> void:
	assert_eq(SecretCodes.normalize(" gold-rush 77! "), "GOLDRUSH77")
	# Same digest tools/ui/secret_hash.py prints for "test".
	assert_eq(SecretCodes.hash_of("test"), "23f7fd2c9dfec7a4b0dd74bef3b3b03b0a5a3c06b2e6acc246d04c0cffdf66ae")
	var table := {SecretCodes.hash_of("Open Sesame"): [{"kind": "cosmetic", "id": "hat:demo_hat"},
			{"kind": "weapon", "id": "demo_gun"}, {"kind": "bogus", "id": "x"}]}
	var got := SecretCodes.rewards("open-sesame", table)
	assert_eq(got, [{"kind": "cosmetic", "id": "hat:demo_hat"}, {"kind": "weapon", "id": "demo_gun"}], "unknown kinds dropped")
	assert_eq(SecretCodes.rewards("nope", table), [])
	assert_eq(SecretCodes.rewards("", table), [])
	assert_true(SecretCodes.is_secret_look("hat", "demo_hat", table))
	assert_true(SecretCodes.is_secret("weapon", "demo_gun", table))
	assert_false(SecretCodes.is_secret_look("hat", "ten_gallon", table))
	for v: Variant in SecretCodes.TABLE.values():
		for e: Variant in v:
			assert_true(SecretCodes.KINDS.has(str(e["kind"])), "every shipped code unlocks a known kind")
	var p := PerkProfile.new()
	assert_eq(p.unlock_secret(got).size(), 2)
	assert_eq(p.unlock_secret(got), [], "already unlocked")
	assert_true(p.cosmetics.has("hat:demo_hat"), "looks become owned cosmetics")
	assert_true(p.has_secret("weapon", "demo_gun"))
	var q := PerkProfile.from_dict(p.to_dict())
	assert_true(q.has_secret("weapon", "demo_gun"), "secrets survive save/load")


func test_run_save_keeps_brands() -> void:
	var data := RunSave.normalize({"wave": 3, "brands": {0: "snake", 1: "sheaf"}})
	assert_eq(data["brands"], {0: "snake", 1: "sheaf"})
	var round := RunSave.decode(RunSave.encode(data))
	assert_eq(round["brands"], {0: "snake", 1: "sheaf"})
	assert_eq(RunSave.normalize({"wave": 3})["brands"], {}, "older saves: no brands")
	assert_eq(RunSave.normalize({"brands": {0: "bogus"}})["brands"], {0: "none"})


func test_title_case() -> void:
	assert_eq(UiStyle.tc("start with CPU partner"), "Start With CPU Partner")
	assert_eq(UiStyle.tc("rancher's ledger"), "Rancher's Ledger")
	assert_eq(UiStyle.tc("pull the lever"), "Pull the Lever")
	assert_eq(UiStyle.tc("host game (west cliff)"), "Host Game (West Cliff)")
	assert_eq(UiStyle.tc("rank up 50"), "Rank Up 50")
	assert_eq(UiStyle.tc("the end of the line"), "The End of the Line")


func test_notches_secret_repeats() -> void:
	var prof := PerkProfile.new()
	var before := prof.brands
	var gift := [{"kind": "notches", "id": "120"}]
	assert_eq(prof.unlock_secret(gift).size(), 1)
	assert_eq(prof.brands, before + 120)
	assert_eq(prof.unlock_secret(gift).size(), 1)
	assert_eq(prof.brands, before + 240)
